all: cluttex.pdf cluttex-ja.pdf lint-manual

cluttex.pdf: cluttex.tex
	cluttex -e pdflatex -o $@ --make-depends=cluttex.pdf.dep $<

cluttex-ja.pdf: cluttex-ja.tex
	cluttex -e lualatex -o $@ --make-depends=cluttex-ja.pdf.dep $<

clean-outdir:
	-rm -rf $(shell cluttex -e pdflatex --print-output-directory cluttex.tex)
	-rm -rf $(shell cluttex -e lualatex --print-output-directory cluttex-ja.tex)

lint-manual:
	mandoc -Tlint cluttex.1

.PHONY: all clean-outdir lint-manual

-include cluttex.pdf.dep
-include cluttex-ja.pdf.dep
