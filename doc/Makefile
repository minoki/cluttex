all: manual.pdf manual-ja.pdf

manual.pdf: manual.tex
	cluttex -e pdflatex -o $@ $<

manual-ja.pdf: manual-ja.tex
	cluttex -e lualatex -o $@ $<

.PHONY: all
