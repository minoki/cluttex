ClutTeX: Process LaTeX document without cluttering your directory
=====

ClutTeX is a program to automatically process your LaTeX document.
If necessary, it re-runs (La)TeX program to resolve cross-references and everything.

One of its main feature is that, it does not clutter your working directory (but the final `.pdf` file is still brought for you).

Blog:

* [TeX 実行の自動化ツールを作った (ClutTeX)](https://blog.miz-ar.info/2016/12/cluttex/)
* [LaTeX処理自動化ツール ClutTeX をリリースした](https://blog.miz-ar.info/2018/10/cluttex-release/)

Features
-----

* Does not clutter your working directory with `.aux`, `.log`, etc. files.
* Does not prompt for input when there is a (La)TeX error.
* With pTeX-like engines, automatically run dvipdfmx to produce PDF file.
* Automatically re-run (La)TeX to resolve cross-references and other things.
* Watch input files for change (requires an external program). \[`--watch` option\]
* Support for MakeIndex, BibTeX, Biber, makeglossaries commands. \[`--makeindex`, `--bibtex`, `--biber`, `--makeglossaries` options\]

Usage
-----

`$ cluttex -e pdflatex file.tex`

More general form:

`$ cluttex [OPTIONS] [--] INPUT.tex`

See [example/](example/) for some examples.

Install
-----

Click \[Clone or download\] button on GitHub and \[Download ZIP\].
Unpack `cluttex-master.zip` and copy `bin/cluttex` (or `bin/cluttex.bat` on Windows) to somewhere in PATH.

Command-line Options
-----

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
  The name of output file.  \[default: `JOBNAME.FORMAT`\]
* `--fresh`
  Clean intermediate files before running TeX.
  Cannot be used with `--output-directory`.
* `--max-iterations=N`
  Maximum number of running TeX to resolve cross-references.
  \[default: 3\]
* `--[no-]change-directory`
  Change the current working directory to the output directory when running TeX.
* `--watch`
  Watch input files for change.
  Requires [fswatch](http://emcrisostomo.github.io/fswatch/) program or `inotifywait` program to be installed on Unix systems.
* `--color[=WHEN]`
  Make ClutTeX's message colorful.
  `WHEN` is one of `always`, `auto`, or `never`.
  \[default: `auto` if `--color` is omitted, `always` if `=WHEN` is omitted\]
* `--includeonly=NAMEs`
  Insert `\includeonly{NAMEs}`.
* `--make-depends=FILE`
  Write dependencies as a Makefile rule.
* `--tex-option=OPTION`
  Pass `OPTION` to TeX as a single option.
* `--tex-options=OPTIONs`
  Pass `OPTIONs` to TeX as multiple options.
* `--dvipdfmx-option[s]=OPTION[s]`
  Same for dvipdfmx.
* `-h`, `--help`
  Print this message and exit.
* `-v`, `--version`
  Print version information and exit.
* `-V`, `--verbose`
  Be more verbose.
* `--print-output-directory`
  Print the output directory and exit.
* `--package-support=PKG1[,PKG2,...,PKGn]`
  Enable special support for shell-escaping packages.
  Currently supported packages are `minted` and `epstopdf`.

Options to run auxiliary programs:

* `--makeindex=COMMAND`
  Use MakeIndex program to process `.idx` files.
  (e.g. `--makeindex=makeindex`, or `--makeindex=mendex`)
* `--bibtex=COMMAND`
  Use BibTeX program to produce `.bbl` file from `.aux` files.
  (e.g. `--bibtex=bibtex`, or `--bibtex=upbibtex`)
* `--biber[=COMMAND]`
  Use Biber program to produce `.bbl` file from `.bcf` file.
* `--makeglossaries[=COMMAND]`
  Use makeglossaries program to produce `.gls` file from `.glo` file.

TeX-compatible options:

* `--[no-]shell-escape`
* `--shell-restricted`
* `--synctex=NUMBER`
* `--[no-]file-line-error`
  \[default: yes\]
* `--[no-]halt-on-error`
  \[default: yes\]
* `--interaction=STRING`
  (`STRING`=`batchmode`/`nonstopmode`/`scrollmode`/`errorstopmode`)
  \[default: `nonstopmode`\]
* `--jobname=STRING`
* `--fmt=FORMAT`
* `--output-directory=DIR`
  \[default: somewhere in the temporary directory\]
* `--output-format=FORMAT`
  Set output format (`pdf` or `dvi`).
  \[default: `pdf`\]

For TeX-compatible options, single-hypen forms are allowed (e.g. `-synctex=1` in addition to `--synctex=1`).

If run as `cllualatex` or `clxelatex`, then the default engine is `lualatex` or `xelatex`, accordingly.

License
-----

This program is distributed under GNU General Public License, version 3.
