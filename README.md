ClutTeX: Convenient Little Utility for Tidying TeX execution
=====

ClutTeX is a utility that lets you process your (La)TeX document without cluttering your working directory.

It automatically re-runs (La)TeX program to resolve cross-references and everything.

Usage
-----

`$ cluttex -e pdflatex file.tex`

More general form:

`$ cluttex [OPTIONS] [--] INPUT.tex`

Options:

* `-e`, `--engine=ENGINE`
  Specify which TeX engine/format to use.
  `ENGINE` is one of the following:
    `pdflatex`, `pdftex`,
    `lualatex`, `luatex`, `luajittex`,
    `xelatex`, `xetex`,
    `latex`, `etex`, `tex`,
    `platex`, `eptex`, `ptex`,
    `uplatex`, `euptex`, `uptex`.
* `-o`, `--output=FILE`
  The name of output file.  [default: `JOBNAME.FORMAT`]
* `--fresh`
  Clean intermediate files before running TeX.
  Cannot be used with `--output-directory`.
* `--max-iterations=N`
  Maximum number of running TeX to resolve cross-references.
  [default: 3]
* `--[no-]change-directory`
  Change the current working directory to the output directory when running TeX.
* `--watch`
  Watch input files for change.
  Requires [fswatch](http://emcrisostomo.github.io/fswatch/) program to be installed.
* `-h`, `--help`
  Print this message and exit.
* `-v`, `--version`
  Print version information and exit.
* `-V`, `--verbose`
  Be more verbose.
* `--tex-option=OPTION`
  Pass `OPTION` to TeX as a single option.
* `--tex-options=OPTIONs`
  Pass `OPTIONs` to TeX as multiple options.
* `--dvipdfmx-option[s]=OPTION[s]`
  Same for dvipdfmx.
* `--[no-]shell-escape`
* `--shell-restricted`
* `--synctex=NUMBER`
* `--[no-]file-line-error`
  [default: yes]
* `--[no-]halt-on-error`
  [default: yes]
* `--interaction=STRING`
  (`STRING`=`batchmode`/`nonstopmode`/`scrollmode`/`errorstopmode`)
  [default: `nonstopmode`]
* `--jobname=STRING`
* `--fmt=FORMAT`
* `--output-directory=DIR`
  [default: somewhere in the temporary directory]
* `--output-format=FORMAT`
  Set output format (`pdf` or `dvi`).
  [default: `pdf`]
* `--makeindex=COMMAND`
  Use MakeIndex program to process `.idx` files.
  (e.g. `--makeindex=makeindex`, or `--makeindex=mendex`)

If run as `cllualatex` or `clxelatex`, then the default engine is `lualatex` or `xelatex`, accordingly.
