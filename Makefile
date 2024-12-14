.PHONY: help codestyle doc test clean

.DEFAULT_GOAL := help

help:   ## Show this help
	@grep -E '^([a-zA-Z_-]+):.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "%-20s %s\n", $$1, $$2}'


codestyle:  ## Apply code formatting
	stylua lua/*.lua lua/jupytext/*.lua tests/*.lua


doc: doc/jupytext.txt  ## Generate documentation from README

test:  ## Run the test suite
	./run_tests.sh

clean:  ## Remove generated files
	rm -rf .testenv
	rm -rf tests/notebooks/.ipynb_checkpoints/
	rm -rf tests/notebooks/.virtual_documents/

doc/jupytext.txt: README.md
	./.panvimdoc/panvimdoc.sh

