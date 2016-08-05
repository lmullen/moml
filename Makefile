US_DIR := /media/data/moml/MOML_US

all : data/us-items.csv

data/us-items.csv : 
	find $(US_DIR) -type f -name *.xml | \
		parallel -n 1 ./scripts/extract-metadata.R {} \
		--items=data/us-items.csv \
		--authors=data/us-authors.csv \
		--subjects=data/us-subjects.csv

clobber :
	rm -f data/us-items.csv
	rm -f data/us-authors.csv
	rm -f data/us-subjects.csv
	rm -rf logs/*

.PHONY : all clobber

