# US_DIR := /media/data/moml/MOML_US
US_DIR := test/
JOBS := 8

all : data/us-items.csv data/us-page-text.csv

data/us-items.csv :
	find $(US_DIR) -type f -name *.xml | \
		parallel --jobs $(JOBS) -n 1 --halt now,fail=1 \
		./scripts/extract-metadata.R {} \
		--items=data/us-items.csv \
		--authors=data/us-authors.csv \
		--subjects=data/us-subjects.csv

data/us-page-text.csv :
	find $(US_DIR) -type f -name *.xml | \
		parallel --jobs $(JOBS) -n 1 --halt now,fail=1 \
		./scripts/extract-text.R {}

clean :
	rm -rf logs/*

clobber : clean
	rm -f data/us-items.csv
	rm -f data/us-authors.csv
	rm -f data/us-subjects.csv
	rm -f data/us-page-text.csv
	rm -f data/us-page-metadata.csv

.PHONY : all clobber clean
