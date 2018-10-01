Example documents and How to process them
=====

* `simple`

```sh
$ cd simple
$ cluttex -e pdflatex main.tex
```

* `simple-ja`

```sh
$ cd simple-ja
$ cluttex -e platex main-platex.tex
$ cluttex -e lualatex main-luatexja.tex
```

* `include`

```sh
$ cd include
$ cluttex -e pdflatex main.tex
```

* `makeindex`

```sh
$ cd makeindex
$ cluttex -e pdflatex --makeindex=makeindex main.tex
```

* `bibtex`

```sh
$ cd bibtex
$ cluttex -e pdflatex --bibtex=bibtex main.tex
```

* `biblatex`

```sh
$ cd biblatex
$ cluttex -e pdflatex --biber main.tex
```

* `empty`

```sh
$ cd empty
$ cluttex -e pdflatex main.tex
```

Should print `[WARN] No pages of output.`

* `minted`

```sh
$ cd minted
$ cluttex -e pdflatex --shell-escape main.tex
```

* `epstopdf`

```sh
$ cd epstopdf
$ cluttex -e pdflatex --change-directory main.tex
```
