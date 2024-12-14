local M = {}

M.notebooks = function(opts)
  local tempdir = vim.fn.tempname() .. '/'
  vim.fn.mkdir(tempdir, 'p')
  local current_dir = debug.getinfo(1, 'S').source:match('@(.*)'):match('(.*/)')
  local notebooks_dir = current_dir .. 'notebooks'
  for _, filename in ipairs(vim.fn.readdir(notebooks_dir)) do
    if (filename ~= '.ipynb_checkpoints') and (filename ~= '.virtual_documents') then
      local file = notebooks_dir .. '/' .. filename
      local cp_cmd = { 'cp', file, tempdir }
      local proc = vim.system(cp_cmd):wait()
      if proc.code ~= 0 then
        print('ERROR: ' .. proc.stderr)
      end
    end
  end
  if opts and opts.debug then
    proc = vim.system({ 'tree', '-a', tempdir }):wait()
    print(proc.stdout)
  end
  return tempdir
end

return M
