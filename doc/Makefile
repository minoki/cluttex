all: manual.pdf manual-ja.pdf

manual.pdf: manual.tex
	cluttex -e pdflatex -o $@ --make-depends=manual.pdf.dep $<

manual-ja.pdf: manual-ja.tex
	cluttex -e lualatex -o $@ --make-depends=manual-ja.pdf.dep $<

.PHONY: all

-include manual.pdf.dep
-include manual-ja.pdf.dep
