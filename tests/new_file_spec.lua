local util = require('tests.test_util')

describe('a new .ipynb file', function()
  it('uses the default template file', function()
    require('jupytext').setup({ format = 'markdown', async_write = false })
    local tempdir = vim.fn.tempname() .. '/'
    vim.fn.mkdir(tempdir, 'p')
    local ipynb_file = tempdir .. 'new.ipynb'
    vim.cmd('new ' .. ipynb_file)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.is_true(text:sub(1, 3) == '---')
    assert.is_truthy(text:find('# New Notebook file'))
  end)
end)
