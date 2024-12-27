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
    assert.is_not_nil(parsed_data.jupyter)
  end)

  it('can parse a quarto yaml header', function()
    local data = [[
    author: Michael Goerz
    date: today
    date-format: long
    format:
      pdf:
        toc: false
        number-sections: false
        colorlinks: true
        monofont: JuliaMono
        fontsize: 10pt
        echo: false
        include-in-header:
          - file: packages.tex
    jupyter:
      jupytext:
        encoding: '# -*- coding: utf-8 -*-'
        text_representation:
          extension: .md
          format_name: markdown
          format_version: '1.3'
          jupytext_version: 1.16.4
      kernelspec:
        display_name: Julia 1.10.3
        language: julia
        name: julia-1.10
    ]]
    local lines = {}
    for line in data:gmatch('([^\n]*)\n?') do
      table.insert(lines, line:sub(5, -1))
    end
    local parsed_data = require('jupytext').parse_yaml(lines)
    assert.is_not_nil(parsed_data.jupyter)
  end)
end)
