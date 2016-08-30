DATA_DIR := data
# DATA_DIR := /media/data/moml/us-export
US_DIR := test
# US_DIR := /media/data/moml/MOML_US
TEMP_DIR := temp
JOBS := 8

XML_FILES := $(wildcard $(US_DIR)/*.xml)
TEXT_CSV := $(patsubst %.xml, $(TEMP_DIR)/%.csv, $(notdir $(XML_FILES)))

.PHONY : all clobber clean

.INTERMEDIATE: $(TEXT_CSV)

all : $(DATA_DIR)/us-text.csv

$(TEMP_DIR)/%.csv : $(US_DIR)/%.xml
	saxonb-xslt -dtd:off -expand:off -s:$^ -xsl:scripts/export-text.xslt -o:$@

$(DATA_DIR)/us-text.csv : $(TEXT_CSV)
	echo "document_id,page_id,para_num,text" > $@
	cat $^ >> $@
	touch $@

# $(DATA_DIR)/us-items.csv :
# 	find $(US_DIR) -type f -name *.xml | \
# 		parallel --jobs $(JOBS) -n 1 --halt now,fail=1 \
# 		./scripts/extract-metadata.R {} \
# 		--items=$(DATA_DIR)/us-items.csv \
# 		--authors=$(DATA_DIR)/us-authors.csv \
# 		--subjects=$(DATA_DIR)/us-subjects.csv

# $(DATA_DIR)/us-page-text.csv :
# 	find $(US_DIR) -type f -name *.xml | \
# 		parallel --jobs $(JOBS) -n 1 --halt now,fail=1 \
# 		./scripts/extract-text.R {} \
# 		--page_metadata=$(DATA_DIR)/us-page-metadata.csv \
# 		--page_text=$(DATA_DIR)/us-page-text.csv

clean :
	rm -rf logs/*
	rm -rf $(TEMP_DIR)/*

clobber : clean
	rm -f $(DATA_DIR)/us-items.csv
	rm -f $(DATA_DIR)/us-authors.csv
	rm -f $(DATA_DIR)/us-subjects.csv
	rm -f $(DATA_DIR)/us-text.csv
	rm -f $(DATA_DIR)/us-page-metadata.csv


