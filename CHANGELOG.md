Version 0.4 (2019-08-21)
-----

Changes:

* New options: `--print-output-directory`, `--package-support`, and `--engine-executable`
* Spaces and special characters in the input file name are now appropriately escaped.  For example, `cluttex -e pdflatex file%1.tex` now typesets the file `file%1.tex`.
* Watch new input files in watch mode.

Version 0.3 (2019-04-30)
-----

Changes:

* Support other methods for watching file system: `inotifywait` for Linux and a built-in one for Windows.
* Fix `--no-*` options.

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
