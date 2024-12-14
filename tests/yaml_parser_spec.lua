describe('the yaml parser', function()
  it('can parse typical jupytext yaml header', function()
    local data = [[
    jupyter:
      jupytext:
        notebook_metadata_filter: all
        text_representation:
          extension: .jl
          format_name: light
          format_version: '1.5'
          jupytext_version: 1.16.4
      kernelspec:
        display_name: Julia 1.10.4
        language: julia
        name: julia-1.10
      language_info:
        file_extension: .jl
        mimetype: application/julia
        name: julia
        version: 1.10.4
    ]]
    local lines = {}
    for line in data:gmatch('([^\n]*)\n?') do
      table.insert(lines, line:sub(5, -1))
    end
    local parsed_data = require('jupytext').parse_yaml(lines)
    assert.is_truthy(parsed_data.jupyter)
  end)
end)
