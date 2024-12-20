local util = require('tests.test_util')
local get_metadata = require('jupytext').get_metadata
local read_file = require('jupytext').read_file

describe('an unpaired .ipynb file', function()
  local notebooks = util.notebooks()
  print(notebooks)
  local ipynb_file = notebooks .. 'unpaired.ipynb'

  it('does not have jupytext metadata', function()
    local metadata = get_metadata(read_file(ipynb_file, true))
    assert.is_nil(metadata.jupytext)
  end)

  it('can be loaded', function()
    require('jupytext').setup({ format = 'markdown' })
    vim.cmd('edit ' .. ipynb_file)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same(lines[1], '---') -- YAML header, not JSON
  end)

  it('can be edited and retain outputs and pairings', function()
    require('jupytext').setup({ format = 'markdown', async_write = false })
    vim.cmd('edit ' .. ipynb_file)
    vim.cmd('%s/World//g')
    vim.cmd.write()
    local json = require('jupytext').get_json(ipynb_file)
    assert.is_nil(json.metadata.jupytext)
    assert.is_truthy(json.cells[4].source[1]:find('Hello'))
    assert.is_nil(json.cells[4].source[1]:find('World'))
    assert.is_true(#json.cells[4].outputs > 0)
  end)
end)
