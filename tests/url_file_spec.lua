describe('a URL-specced .ipynb file', function()
  local file = 'jupytext-test:///paired.ipynb'

  it('gets converted after loading', function()
    require('jupytext').setup({ format = 'markdown', handle_url_schemes = true })
    require('tests.testurl').setup()
    vim.cmd('edit ' .. file)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same(lines[1], '---') -- YAML header, not JSON
    assert.are.same(vim.bo.filetype, 'markdown')
  end)

  it('gets saved as json data', function()
    require('jupytext').setup({ format = 'markdown', handle_url_schemes = true })
    require('tests.testurl').setup()
    vim.cmd('edit ' .. file)
    vim.cmd.write()
    local json = require('jupytext').get_json(vim.b.jupytest_test_tempfile)
    assert.are.same(json.metadata.jupytext.formats, 'ipynb,py:light,md:myst')
  end)

  it('stays plain text after saving', function()
    require('jupytext').setup({ format = 'markdown', handle_url_schemes = true })
    require('tests.testurl').setup()
    vim.cmd('edit ' .. file)
    vim.cmd.write()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same(lines[1], '---')
  end)

  it('is not converted with handle_url_schemes = false', function()
    require('jupytext').setup({ format = 'markdown', handle_url_schemes = false })
    require('tests.testurl').setup()
    vim.cmd('edit ' .. file)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same(lines[1], '{') -- json data
  end)
end)
