local M = {}

-- Get the filetype that should be set for the buffer after loading ipynb file
function M.get_filetype(ipynb_file, format, metadata)
  if format == 'markdown' then
    return format
  elseif format == 'ipynb' then
    return 'json'
  elseif format:sub(1, 2) == 'md' then
    return 'markdown'
  elseif format:sub(1, 3) == 'Rmd' then
    return 'markdown'
  else
    return metadata.kernelspec.language
  end
end

-- Plugin options
M.opts = {
  jupytext = 'jupytext',
  format = 'markdown',
  update = true,
  filetype = M.get_filetype,
  sync_patterns = { '*.md', '*.py', '*.jl', '*.R', '*.Rmd', '*.qmd' },
  autosync = true,
  async_write = true, -- undocumented (for testing)
}

M.setup = function(opts)
  for key, value in pairs(opts) do
    M.opts[key] = value
  end

  local augroup = vim.api.nvim_create_augroup('JupytextPlugin', { clear = true })

  vim.api.nvim_create_autocmd('BufReadCmd', {

    pattern = '*.ipynb',
    group = augroup,

    callback = function(args)
      local ipynb_file = args.file -- may be relative path
      local bufnr = args.buf
      local metadata = M.open_notebook(ipynb_file, bufnr)
      vim.b.mtime = vim.uv.fs_stat(ipynb_file).mtime
      -- Local autocommands to handle two-way sync
      local buf_augroup = 'JupytextPlugin' .. bufnr
      vim.api.nvim_create_augroup(buf_augroup, { clear = true })

      vim.api.nvim_create_autocmd('BufWriteCmd', {
        buffer = bufnr,
        group = buf_augroup,
        callback = function(bufargs)
          local format = M.get_option('format')
          if (format ~= 'ipynb') and (bufargs.file:sub(-6) == '.ipynb') then
            M.write_notebook(bufargs.file, metadata, bufnr)
          else -- write without conversion
            local success = M.write_buffer(bufargs.file, bufnr)
            if success and (vim.o.cpoptions:find('%+') ~= nil) then
              vim.api.nvim_set_option_value('modified', false, { buf = bufnr })
            end
          end
        end,
      })

      if M.get_option('autosync') and M.is_paired(metadata) then
        vim.api.nvim_buf_set_option(bufnr, 'autoread', true)
        -- We need autoread to be true, because every save will trigger an
        -- update event from the `.ipynb` file being rewritten in the
        -- background.
        vim.api.nvim_create_autocmd('CursorHold', {
          buffer = bufnr,
          group = buf_augroup,
          callback = function()
            vim.api.nvim_command('checktime')
          end,
        })
      end
    end,
  })

  -- autocommands for plain text files
  if M.get_option('autosync') and (#M.opts.sync_patterns > 0) then
    vim.api.nvim_create_autocmd('CursorHold', {
      pattern = M.opts.sync_patterns,
      group = augroup,
      callback = function()
        vim.api.nvim_command('checktime')
      end,
    })

    vim.api.nvim_create_autocmd('BufReadPre', {

      pattern = M.opts.sync_patterns,
      group = augroup,

      callback = function(args)
        local ipynb_file = args.file:match('^(.+)%.%w+$') .. '.ipynb'
        if M._file_exists(ipynb_file) then
          M.sync(ipynb_file)
          print('Synced with "' .. ipynb_file .. '" via jupytext')
        end
      end,
    })

    vim.api.nvim_create_autocmd('BufWritePost', {

      pattern = M.opts.sync_patterns,
      group = augroup,

      callback = function(args)
        local ipynb_file = args.file:match('^(.+)%.%w+$') .. '.ipynb'
        if M._file_exists(ipynb_file) then
          M.sync(ipynb_file, true) -- asynchronous
        end
      end,
    })
  end
end

function M.get_option(name)
  local var_name = 'jupytext_' .. name
  if vim.b[var_name] ~= nil then
    return vim.b[var_name]
  elseif vim.g[name] ~= nil then
    return vim.g[var_name]
  else
    return M.opts[name]
  end
end

function M.schedule(async, f)
  if async then
    vim.schedule(f)
  else
    f()
  end
end

-- Load ipynb file into the buffer via jupytext conversion
function M.open_notebook(ipynb_file, bufnr)
  local source_file = vim.fn.fnamemodify(ipynb_file, ':p') -- absolute path
  bufnr = bufnr or 0 -- current buffer, by default
  print('Loading via jupytext…')
  local metadata = M.get_metadata(source_file)
  local autosync = M.get_option('autosync')
  if autosync and M.is_paired(metadata) then
    M.sync(source_file)
  end
  local format = M.get_option('format')
  local jupytext = M.get_option('jupytext')
  if type(format) == 'function' then
    format = format(source_file, metadata)
  end
  if format == 'ipynb' then
    local lines = M.read_file(ipynb_file, true)
    vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, lines)
  else
    local cmd = { jupytext, '--from', 'ipynb', '--to', format, '--output', '-', source_file }
    local proc = vim.system(cmd, { text = true }):wait()
    if proc.code == 0 then
      local text = proc.stdout:gsub('\n$', '') -- strip trailing newline
      vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, vim.split(text, '\n'))
    else
      vim.notify(proc.stderr, vim.log.levels.ERROR)
    end
  end
  local filetype = M.get_option('filetype')
  if type(filetype) == 'function' then
    filetype = filetype(source_file, format, metadata)
  end
  vim.api.nvim_set_option_value('filetype', filetype, { buf = bufnr })
  vim.api.nvim_set_option_value('modified', false, { buf = bufnr })
  print('"' .. ipynb_file .. '" via jupytext with format: ' .. format)
  vim.cmd('redraw')
  return metadata
end

-- Call `jupytext --sync` or `jupytext --set-formats` for the given ipynb file
function M.sync(ipynb_file, asynchronous, formats)
  local jupytext = M.get_option('jupytext')
  local cmd
  if formats then
    cmd = { jupytext, '--set-formats', formats, ipynb_file }
  else
    cmd = { jupytext, '--sync', ipynb_file }
  end
  local function on_exit(proc)
    if proc.code ~= 0 then
      vim.schedule(function()
        vim.notify(proc.stderr, vim.log.levels.ERROR)
      end)
    end
  end
  if asynchronous then
    vim.system(cmd, { text = true }, on_exit)
  else
    local proc = vim.system(cmd, { text = true }):wait()
    on_exit(proc)
  end
end

-- Write buffer to .ipynb file via jupytext conversion
function M.write_notebook(ipynb_file, metadata, bufnr)
  local buf_file = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(bufnr))
  local write_in_place = (vim.uv.fs_realpath(ipynb_file) == buf_file)
  local buf_mtime = vim.b.mtime
  local stat = vim.uv.fs_stat(ipynb_file)
  if write_in_place then
    if stat and stat.mtime.sec ~= buf_mtime.sec then
      vim.notify('WARNING: The file has been changed since reading it!!!', vim.log.levels.WARN)
      vim.notify('Do you really want to write to it (y/n)? ', vim.log.levels.INFO)
      local input = vim.fn.getchar()
      local key = vim.fn.nr2char(input)
      if key ~= 'y' then
        vim.notify('Aborted', vim.log.levels.INFO)
        return
      end
    end
  end
  local target_is_new = not (stat and stat.type == 'file')
  local has_cpo_plus = vim.o.cpoptions:find('%+') ~= nil
  metadata = metadata or {}
  bufnr = bufnr or 0 -- current buffer, by default
  local update = M.get_option('update')
  local via_tempfile = update
  local autosync = M.get_option('autosync')
  local jupytext = M.get_option('jupytext')
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cmd = { jupytext, '--to', 'ipynb', '--output', ipynb_file }
  if update then
    table.insert(cmd, '--update')
  end
  local formats = M.is_paired(metadata)
  local cmd_opts = {}
  local tempdir = nil
  if via_tempfile then
    tempdir = vim.fn.tempname()
    vim.fn.mkdir(tempdir)
    local yaml_lines = M.get_yaml_lines(lines)
    local yaml_data = M.parse_yaml(yaml_lines)
    local extension = yaml_data.jupyter.jupytext.text_representation.extension
    local basename = ipynb_file:match('([^/]+)%.%w+$')
    local tempfile = tempdir .. '/' .. basename .. extension
    M.write_buffer(tempfile, bufnr)
    table.insert(cmd, tempfile)
  else
    cmd_opts.stdin = lines
  end
  local async_write = M.get_option('async_write')
  local on_convert = function(proc)
    if proc.code == 0 then
      local msg = '"' .. ipynb_file .. '"'
      if target_is_new then
        msg = msg .. ' [New]'
      end
      msg = msg .. ' ' .. #lines .. 'L via jupytext [w]'
      print(msg)
      if write_in_place or has_cpo_plus then
        M.schedule(async_write, function()
          vim.api.nvim_set_option_value('modified', false, { buf = bufnr })
          if write_in_place then
            vim.b.mtime = vim.uv.fs_stat(ipynb_file).mtime
          end
        end)
      end
      if autosync and write_in_place and formats then
        M.sync(ipynb_file, async_write, formats)
        -- without autosync, the written file will be unpaired
      end
    else
      M.schedule(async_write, function()
        vim.notify(proc.stderr, vim.log.levels.ERROR)
      end)
    end
    if tempdir then
      M.schedule(async_write, function()
        vim.fn.delete(tempdir, 'rf')
      end)
    end
  end
  if async_write then
    vim.system(cmd, cmd_opts, on_convert)
  else
    local proc = vim.system(cmd, cmd_opts):wait()
    on_convert(proc)
  end
end

-- Write buffer to file "as-is"
function M.write_buffer(file, bufnr)
  bufnr = bufnr or 0 -- current buffer, by default
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local fh = io.open(file, 'w')
  if fh then
    for _, line in ipairs(lines) do
      fh:write(line, '\n')
    end
    fh:close()
    return true
  else
    error('Failed to open file for writing')
    return false
  end
end

function M._file_exists(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == 'file'
end

-- Read the metadata from the given ipynb file
function M.get_metadata(ipynb_file)
  local success, metadata = pcall(function()
    local cmd = { 'jq', '--compact-output', '--monochrome-output', '.metadata', ipynb_file }
    local proc = vim.system(cmd, { text = true }):wait()
    if proc.code == 0 then
      return vim.json.decode(proc.stdout)
    else
      error('Command exited with non-zero code: ' .. proc.code)
    end
  end)
  if not success then
    metadata = M.get_json(ipynb_file).metadata
  end
  return metadata
end

-- Get the content of the file as a multiline string or an array of lines
function M.read_file(file, as_lines)
  if as_lines then
    local lines = {}
    for line in io.lines(file) do
      table.insert(lines, line)
    end
    return lines
  else
    local fh = io.open(file, 'r')
    if not fh then
      error('Could not open file: ' .. file)
    end
    local content = fh:read('*all')
    fh:close()
    return content
  end
end

-- Get the json in the file as a Lua table
function M.get_json(ipynb_file)
  local content = M.read_file(ipynb_file)
  return vim.json.decode(content)
end

-- Does metadata indicate that underlying notebook is paired?
-- In non-boolean context, get the paired formats spec
function M.is_paired(metadata)
  if metadata.jupytext then
    return metadata.jupytext.formats
  end
  return false
end

function M.get_yaml_lines(lines)
  if type(lines) == 'number' then
    local bufnr = lines -- get_yaml_lines(0) does the current buffer
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
  local yaml_lines = {}
  local line_nr = 1
  local first_line = lines[line_nr]
  local delimiters = {
    ['# ---'] = { '# ', '' },
    ['---'] = { '', '' },
    ['// ---'] = { '// ', '' },
    [';; ---'] = { ';; ', '' },
    ['% ---'] = { '% ', '' },
    ['/ ---'] = { '/ ', '' },
    ['-- ---'] = { '-- ', '' },
    ['(* ---'] = { '(* ', ' *)' },
    ['/* ---'] = { '/* ', ' */' },
  }
  local prefix = nil
  local suffix = nil
  for yaml_start, delims in pairs(delimiters) do
    if first_line:sub(1, #yaml_start) == yaml_start then
      prefix = delims[1]
      suffix = delims[2]
      break
    end
  end
  if prefix == nil or suffix == nil then
    error('Invalid YAML block')
    return {}
  end
  while line_nr < #lines do
    line_nr = line_nr + 1
    local line = lines[line_nr]:sub(#prefix + 1)
    if suffix ~= '' then
      line = line:sub(1, -#suffix)
    end
    if line == '---' then
      break
    else
      table.insert(yaml_lines, line)
    end
  end
  return yaml_lines
end

-- limited YAML parser for the subset of YAML that will appear in the metadata
-- YAML header generated by jupytext
function M.parse_yaml(lines)
  local result_table = {}
  local stack = {}
  local current_indent = ''

  for _, line in ipairs(lines) do
    local leading_spaces = line:match('^(%s*)')
    local trimmed_line = line:match('^%s*(.-)%s*$')

    if #leading_spaces < #current_indent then
      table.remove(stack)
    end
    current_indent = leading_spaces
    if #trimmed_line > 0 then
      if trimmed_line:sub(-1) == ':' then
        local sub_table_name = trimmed_line:sub(1, -2)
        table.insert(stack, sub_table_name)
      else
        local key, value = trimmed_line:match('^(%S+):%s*(.+)$')
        if value:sub(1, 1) == "'" and value:sub(-1) == "'" then
          value = value:sub(2, -2)
        end
        local current_subtable = result_table
        for _, k in ipairs(stack) do
          current_subtable[k] = current_subtable[k] or {}
          current_subtable = current_subtable[k]
        end
        current_subtable[key] = value
      end
    end
  end

  return result_table
end

function M.get_yamldata(bufnr)
  bufnr = bufnr or 0 -- current buffer, by default
  local lines = M.get_yaml_lines(bufnr)
  return M.parse_yaml(lines)
end

return M
