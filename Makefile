# DATA_DIR := data
DATA_DIR := /media/data/moml/us-tables
# US_DIR := test
US_DIR := /media/data/moml/MOML_US
# TEMP_DIR := temp
TEMP_DIR := /media/data/moml/temp

XML_FILES := $(wildcard $(US_DIR)/*.xml)
TEXT_CSV := $(patsubst %.xml, $(TEMP_DIR)/%-text.csv, $(notdir $(XML_FILES)))
ITEMS_CSV := $(patsubst %.xml, $(TEMP_DIR)/%-items.csv, $(notdir $(XML_FILES)))
PAGES_CSV := $(patsubst %.xml, $(TEMP_DIR)/%-pages.csv, $(notdir $(XML_FILES)))
AUTHORS_CSV := $(patsubst %.xml, $(TEMP_DIR)/%-authors.csv, $(notdir $(XML_FILES)))
SUBJECTS_CSV := $(patsubst %.xml, $(TEMP_DIR)/%-subjects.csv, $(notdir $(XML_FILES)))

.PHONY : all clobber clean metadata text

.SECONDARY : $(DATA_DIR)/us-pages.csv $(DATA_DIR)/us-authors.csv $(DATA_DIR)/us-subjects.csv $(TEXT_CSV) $(ITEMS_CSV) $(PAGES_CSV) $(AUTHORS_CSV) $(SUBJECTS_CSV)

all :
	@echo At the moment there is no all task.

metadata : $(DATA_DIR)/us-items.csv

text : $(DATA_DIR)/us-text.csv

$(TEMP_DIR)/%-text.csv : $(US_DIR)/%.xml
	@echo "`date` - Exporting text from $^" >> logs/text-export.log
	saxonb-xslt -dtd:off -expand:off -s:$^ -xsl:scripts/export-text.xslt -o:$@

$(DATA_DIR)/us-text.csv : $(TEXT_CSV)
	echo "document_id,page_id,para_num,text" > $@
	cat $^ >> $@

$(TEMP_DIR)/%-items.csv : $(US_DIR)/%.xml
	Rscript --vanilla scripts/extract-metadata.R $^ -o $(TEMP_DIR) \
	-l logs/metadata-export.log

$(DATA_DIR)/us-items.csv : $(ITEMS_CSV)
	echo "document_id, title_full, title_display, title_variant, publication_date, language, collection_id, release_date, source_bib_citation, source_library, notes, comments, category_code, volume_current, volume_total, imprint_full, imprint_city, imprint_publisher, imprint_year, edition, collation, publication_place, page_count, page_count_type" > $(DATA_DIR)/us-items.csv
	cat $(TEMP_DIR)/*-items.csv >> $(DATA_DIR)/us-items.csv
	echo "document_id, author, birth_year, death_year, marc_dates, byline" > $(DATA_DIR)/us-authors.csv
	cat $(TEMP_DIR)/*-authors.csv >> $(DATA_DIR)/us-authors.csv
	echo "document_id, subject_source, subject_type, subject" > $(DATA_DIR)/us-subjects.csv
	cat $(TEMP_DIR)/*-subjects.csv >> $(DATA_DIR)/us-subjects.csv
	echo "document_id, type, page_id, record_id, source_page, ocr" > $(DATA_DIR)/us-pages.csv
	cat $(TEMP_DIR)/*-pages.csv >> $(DATA_DIR)/us-pages.csv

clean :
	rm -rf logs/*
	rm -rf $(TEMP_DIR)/*

clobber : clean
	rm -f $(DATA_DIR)/us-items.csv
	rm -f $(DATA_DIR)/us-authors.csv
	rm -f $(DATA_DIR)/us-subjects.csv
	rm -f $(DATA_DIR)/us-text.csv
	rm -f $(DATA_DIR)/us-pages.csv
