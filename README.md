jupytext.nvim
=============

<!-- panvimdoc-ignore-start -->

[![CI](https://github.com/goerz/jupytext.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/goerz/jupytext.nvim/actions/workflows/ci.yml)

<!-- panvimdoc-ignore-end -->

The plugin enables editing [Jupyter notebook `.ipynb` files](https://jupyter.org) as plain text files by dynamically converting them through the [`jupytext` command line tool](https://github.com/mwouts/jupytext).

It is a rewrite for Neovim of the [`jupytext.vim` plugin](https://github.com/goerz/jupytext.vim). See [History](#history) for changes relative to the original vimscript version.


Prerequisites
=============

The [`jupytext` command line utility](https://github.com/mwouts/jupytext) must be installed.

It is recommended to also have [`jq`](https://jqlang.github.io/jq/) installed. This is used to obtain the metadata from the `.ipynb` file without having to fully load it into Neovim's memory.

After following the [installation](#installation) instructions, the `:checkhealth jupytext` command can be used inside Neovim to verify the prerequisites.


Installation
============

Load the plugin via your favorite package manager. [`Lazy.nvim`](https://lazy.folke.io) is recommended.

### Lazy.nvim

Use the following plugin specification:

```lua
{
    'goerz/jupytext.nvim',
    version = '0.1',
    opts = {},  -- see Options
}
```

### Manual setup

If you are not using a package manager, copy the `lua/jupytext.lua` file into your runtime folder (e.g., `~/.config/nvim/`). Then, in your `init.lua` file, call `require("jupytext").setup(opts)` where `opts` is a table that may contain any of the keys listed in [Options](#options).


Options
=======

The default options are:

```lua
opts = {
  jupytext = 'jupytext',
  format = "markdown",
  update = true,
  filetype = require("jupytext").get_filetype,
  sync_patterns = { '*.md', '*.py', '*.jl', '*.R', '*.Rmd', '*.qmd' },
  autosync = true,
  async_write = true,
}
```

#### `jupytext`

The `jupytext` command to use. If `jupytext` is not on your `PATH`, you could set an absolute path here. Can also be set via a `b:jupytext_jupytext` variable.

#### `format`

The plain text format to use. See the description of `OUTPUT_FORMAT` in `jupytext --help`: `'markdown'` or `'script'`, or a file extension: `'md'`, `'Rmd'`, `'jl'`, `'py'`, `'R'`, …, `'auto'` (script extension matching the notebook language), or a combination of an extension and a format name, e.g., `'md:myst'`, `'md:markdown'`, `'md:pandoc'`, or `'py:percent'`, `'py:light'`, `'py:sphinx'`, `'py:hydrogen'`.

Using `format='ipynb'` loads and writes the file in the original `json` format.

The `format` option may also be given as a function that calculates the `format` from two arguments:

- `path`: the absolute path to the `.ipynb` file being loaded
- `metadata`: a table with metadata information from the original JSON data in the `.ipynb` file. Of particular interest may be the field `metadata.jupytext.formats` if one wanted to implement something where paired notebooks would preferentially use the paired format instead of a common default value.

To set the `format` option temporarily on a per-buffer basis, set `b:jupytext_format` and reload the file.

#### `update`

Whether or not to use the `--update` flag to `jupytext`. If `true` (recommended), this preserves existing outputs in the edited `.ipynb` file. If `false`, every save clears all outputs from the underlying file.

This can be temporarily overridden with a `b:jupytext_update` variable.

#### `filetype`

The buffer `filetype` setting to use after loading the file, which determines syntax highlighting, etc. Can be given as a string, or more commonly as a function that returns a string after receiving three arguments:

- `path`: the absolute path to the `.ipynb` file being loaded
- `format`: the value of the `format` option
- `metadata`: a table with metadata information from the original JSON data in the `.ipynb` file. This should contain, e.g., the notebook language in `metadata.kernelspec.language`

The default function used for this setting uses `"markdown"` for markdown formats, and the value of `metadata.kernelspec.language` otherwise. Like the previous options, `b:jupytext_filetype` is available to temporarily override the choice of filetype.

#### `sync_pattern`

Patterns for plain text files that should be recognized as "syncable". If `autosync=true` (see below), and if, for a file matching the patterns, there also exists a file with an `.ipynb` extension, autocommands will be set up for `jupyter --sync` to be called before loading the file and after saving the file. This also periodically calls the `:checktime` function in the background to determine whether the file has changed on disk (by a running Jupyter server, presumably), and reloads it when appropriate.

Note that the `sync_pattern` only determines for which plain text files the appropriate autocommands will be set up in Neovim. The setting is independent of which Jupytext pairings are active, which is in the metadata for the `.ipynb` files. All linked files will automatically be kept in sync. Likewise, when editing `.ipynb` files directly, _all_ linked files will be kept in sync automatically if `autosync=true`, irrespective of `sync_pattern`.


#### `autosync`

If true (recommended), enable automatic synchronization for files paired via the Jupytext plugin (the plugin for Jupyter Lab). For `.ipynb` files, this checks if the notebook is paired to any plain text files. If so, it will call `jupytext --sync` before loading the file and after saving it, to ensure all files are being kept in sync. It will also periodically check whether the `.ipynb` file has changed on disk and reload it if necessary, setting the [`autoread`](https://neovim.io/doc/user/options.html#'autoread') option for the current buffer.


Usage
=====

When opening an `.ipynb` file, this plugin will inject itself into the loading process and convert the `json` data in the file to a plain text format by piping it through `jupytext` using the `format` set in [Options](#options).

On saving, the original `.ipynb` file will be updated by piping the content of the current buffer back into `jupytext`. With the default `update` setting, this will keep existing outputs and metadata in the notebook. When saving the buffer to a new file, it will be converted if the filename has an `.ipynb` extension. Otherwise, the buffer will be written unchanged.


Paired Files
============

While the Jupytext project provides the command line utility `jupytext` used by this plugin for on-the-fly conversion between `.ipynb` and plain text formats, its _primary_ purpose is to provide a plugin for Jupyter to _pair_ `.ipynb` files with one or more text files that are easier to manage in version control.

The intent of the original `jupytext.vim` plugin was to edit `.ipynb` files _not_ paired in such a way, and not loaded in an active Jupyter session. With this rewritten version of the plugin, `jupytext.nvim` now supports editing `.ipynb` files with Neovim if they are paired in Jupyter, and, at least in principle, even while the notebooks are actively loaded in a running Jupyter server. For this to work, the `autosync` option must be set to `true` (default, see [Options](#options)). This automatically handles the update of any paired files and watches for modifications of the file on disk while it is being edited. Saving a paired file while `autosync = false` will unpair it.


<!-- panvimdoc-ignore-start -->

Even though editing files that are also actively loaded in Jupyter _works_, it might still be preferable to close the file in Jupyter first. The support in Jupyter for detecting external changes is not quite as good. You will have to manually reload files after saving them in Neovim. In the future, it might be possible to [combine the Jupytext plugin for Jupyter with its real-time-collaboration plugin](https://github.com/jupyterlab/jupyter-collaboration/issues/214), which would alleviate this concern.


Development
===========

During development, `make` can be used locally to apply the Lua code style, generate the documentation, and run the tests. See `make help` for details.

Pushing commits to GitHub verifies the code formatting, the tests, and that the documentation is up-to-date via GitHub Actions.

### Documentation

The documentation for the plugin is maintained in this `README` file. This must be kept in sync with the [vim help format](doc/jupytext.txt). Running `make doc` locally regenerates the Vim help file from the current `README` to ensure this. The conversion relies on [`pandoc`](https://pandoc.org) and a number of [custom filters](.panvimdoc/scripts/) adapted from [`kdheepak/panvimdoc`](https://github.com/kdheepak/panvimdoc). See [its documentation](https://raw.githubusercontent.com/kdheepak/panvimdoc/refs/heads/main/doc/panvimdoc.md) for details on the recommended markdown syntax to use.

GitHub Actions will check that the `README` and the Vim help file are in sync.


### Testing

This plugin uses the [`plenary.nvim` test framework](https://github.com/nvim-lua/plenary.nvim/blob/master/TESTS_README.md). Tests are organized in `tests/*_spec.lua` files, and can be run by executing the `./run_tests.sh` script. This also happens automatically on GitHub Actions with each push.

<!-- panvimdoc-ignore-end -->


History
=======

### v0.1.0 (2024-12-18)

Initial release; Rewrite of [`jupytext.vim`](https://github.com/goerz/jupytext.vim). The new plugin targets Neovim and has been rewritten in Lua to avoid restrictions of the old plugin:

- Avoid the use of temporary files in the same folder as the `.ipynb` files potentially clashing with paired scripts.
- Added support for obtaining the notebook language from its metadata, enabling use of the "script" and "auto" format.
- Added support for automatic synchronization with paired files.
