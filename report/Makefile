all: $(patsubst %.md,%.pdf,$(wildcard *.md))

%.pdf: %.md
	pandoc $< --pdf-engine=lualatex -V mainfont="FreeSerif" -o $@

clean:
	rm -f *.pdf

.PHONY: all clean
