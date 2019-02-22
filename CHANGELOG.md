Version 0.2 (2019-02-22)
-----

Changes:

* Added manual.
* Added `--make-depends` option.
* Better support for older Windows; don't emit ANSI escape sequences on older Command Prompts.

Version 0.1 (2018-10-10)
-----

Initial release.

Basic features:

* Does not clutter your working directory with `.aux`, `.log`, etc. files.
* Does not prompt for input when there is a (La)TeX error.
* With pTeX-like engines, automatically run dvipdfmx to produce PDF file.
* Automatically re-run (La)TeX to resolve cross-references and other things.
* Watch input files for change (requires an external program). [`--watch` option]
* Support for MakeIndex, BibTeX, Biber, makeglossaries commands. [`--makeindex`, `--bibtex`, `--biber`, `--makeglossaries` options]
