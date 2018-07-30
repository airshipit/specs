# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line.
# TODO: Incorporate these vars into tox file
SPHINXOPTS    = -a -E -W
SPHINXBUILD   = sphinx-build
SPHINXPROJ    = airship-specs
SOURCEDIR     = doc/source
BUILDDIR      = doc/build

docs:
	tox

%: docs
