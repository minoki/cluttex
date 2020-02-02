all: cluttex.pdf cluttex-ja.pdf

cluttex.pdf: cluttex.tex
	cluttex -e pdflatex -o $@ --make-depends=cluttex.pdf.dep $<

cluttex-ja.pdf: cluttex-ja.tex
	cluttex -e lualatex -o $@ --make-depends=cluttex-ja.pdf.dep $<

clean-outdir:
	-rm -rf $(shell cluttex -e pdflatex --print-output-directory cluttex.tex)
	-rm -rf $(shell cluttex -e lualatex --print-output-directory cluttex-ja.tex)

.PHONY: all clean-outdir

-include cluttex.pdf.dep
-include cluttex-ja.pdf.dep
