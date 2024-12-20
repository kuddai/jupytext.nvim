local M = {}

M.check = function()
  vim.health.start('jupytext.nvim')
  local proc = vim.system({ 'jupytext', '--version' }):wait()
  if proc.code == 0 then
    vim.health.ok('jupytext is available')
  else
    vim.health.error('Jupytext is not available', 'Install jupytext via `pip install jupytext`')
  end
end

return M
