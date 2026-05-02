all: pdf html

pdf:
	quarto render --to beamer

html:
	quarto render --to revealjs

clean:
	rm -rf _output

cleanall: clean
	rm -rf .quarto

.PHONY: all pdf html clean cleanall
