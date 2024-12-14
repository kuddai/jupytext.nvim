#!/usr/bin/env bash

set -euo pipefail

# Paths are from the perspective of the Makefile
PROJECT_NAME="jupytext"
INPUT_FILE="README.md"
DESCRIPTION="Edit .ipynb files"
SCRIPTS_DIR=".panvimdoc/scripts"
DOC_MAPPING=true


# Define arguments in an array
ARGS=(
    "--shift-heading-level-by=${SHIFT_HEADING_LEVEL_BY:-0}"
    "--metadata=project:$PROJECT_NAME"
    "--metadata=vimversion:${VIM_VERSION:-""}"
    "--metadata=toc:${TOC:-true}"
    "--metadata=description:${DESCRIPTION:-""}"
    "--metadata=titledatepattern:${TITLE_DATE_PATTERN:-"%Y %B %d"}"
    "--metadata=dedupsubheadings:${DEDUP_SUBHEADINGS:-true}"
    "--metadata=ignorerawblocks:${IGNORE_RAWBLOCKS:-true}"
    "--metadata=docmapping:${DOC_MAPPING:-false}"
    "--metadata=docmappingproject:${DOC_MAPPING_PROJECT_NAME:-true}"
    "--metadata=treesitter:${TREESITTER:-true}"
    "--metadata=incrementheadinglevelby:${INCREMENT_HEADING_LEVEL_BY:-0}"
    "--lua-filter=$SCRIPTS_DIR/include-files.lua"
    "--lua-filter=$SCRIPTS_DIR/skip-blocks.lua"
)

ARGS+=("-t" "$SCRIPTS_DIR/panvimdoc.lua")

# Print and execute the command
printf "%s\n" "pandoc --citeproc ${ARGS[*]} $INPUT_FILE -o doc/$PROJECT_NAME.txt"
pandoc "${ARGS[@]}" "$INPUT_FILE" -o "doc/$PROJECT_NAME.txt"
