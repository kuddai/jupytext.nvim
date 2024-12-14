local M = {}

M.check = function()
  vim.health.start('jupytext.nvim')
  local proc = vim.system({ 'jupytext', '--version' }):wait()
  if proc.code == 0 then
    vim.health.ok('jupytext is available')
  else
    vim.health.error('Jupytext is not available', 'Install jupytext via `pip install jupytext`')
  end
  proc = vim.system({ 'jq', '--version' }):wait()
  if proc.code == 0 then
    vim.health.ok('jq is available')
  else
    vim.health.info('jq is not available')
  end
end

return M
