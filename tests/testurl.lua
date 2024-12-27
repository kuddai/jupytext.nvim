-- Auxiliary module for testing BufReadPost, BufWritePre, BufWritePost on URLs

local M = {}

M.setup = function()
  local augroup = vim.api.nvim_create_augroup('JupytextPluginTesting', { clear = true })

  vim.api.nvim_create_autocmd('BufReadCmd', {
    pattern = 'jupytext-test://*',
    desc = 'Load a file from the jupytext.nvim test suite',
    group = augroup,
    callback = function(args)
      vim.cmd.doautocmd({ args = { 'BufReadPre', args.file }, mods = { emsg_silent = true } })
      local bufnr = args.buf
      local script_path = debug.getinfo(1, 'S').source:sub(2)
      local script_dir = vim.fn.fnamemodify(script_path, ':h')
      local nb_dir = vim.uv.fs_realpath(script_dir .. '/notebooks')
      local filename = args.file:match('([^/]+%.%w+)$')
      local file = nb_dir .. '/' .. filename
      local lines = require('jupytext').read_file(file, true)
      local write_buffer = require('jupytext').write_buffer
      vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, lines)
      vim.api.nvim_set_option_value('modified', false, { buf = bufnr })
      local buf_augroup = 'JupytextPluginTesting' .. bufnr
      vim.api.nvim_create_augroup(buf_augroup, { clear = true })
      local tempdir = vim.fn.tempname()
      vim.fn.mkdir(tempdir)
      vim.api.nvim_create_autocmd('BufWriteCmd', {
        buffer = bufnr,
        desc = 'Write a jupytext-test://* file',
        group = buf_augroup,
        callback = function(bufargs)
          vim.cmd.doautocmd({
            args = { 'BufWritePre', bufargs.file },
            mods = { emsg_silent = true },
          })
          local tempfile = tempdir .. '/' .. filename
          local success = write_buffer(tempfile, bufnr)
          if success then
            if vim.o.cpoptions:find('%+') ~= nil then
              vim.api.nvim_set_option_value('modified', false, { buf = bufnr })
            end
            vim.b.jupytest_test_tempfile = tempfile
          else
            vim.notify('Failed to write ' .. tempfile, vim.log.levels.ERROR)
          end
          vim.cmd.doautocmd({
            args = { 'BufWritePost', bufargs.file },
            mods = { emsg_silent = true },
          })
        end,
      })
      vim.cmd.doautocmd({ args = { 'BufReadPost', args.file }, mods = { emsg_silent = true } })
    end,
  })
end

return M
