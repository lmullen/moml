#!/usr/bin/env Rscript
#
# Extract the paragraph level text from a Making of Modern Law XML file

suppressPackageStartupMessages(library(docopt))
suppressPackageStartupMessages(library(magrittr))
suppressPackageStartupMessages(library(xml2))
suppressPackageStartupMessages(library(tibble))
suppressPackageStartupMessages(library(loggr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(readr))

"Extract the text from an XML record from the Making of Modern Law

Usage: extract-metadata.R INPUT [--page_metadata=<page_metadata>] [--page_text=<page_text>] [--logfile=<logfile>]

Options:
  <INPUT>                             Path to XML record from MoML.
     --page_metadata=<page_metadata>  Path to CSV file to append page metadata.
     --page_text=<page_text>          Path to CSV file to append page texts.
  -l --logfile=<logfile>              Path to file for logging.
  -h --help                           Show this message.
" -> doc

opt <- docopt(doc)
# opt <- docopt(doc, args = "test/19007815300/xml/19007815300.xml")

# Default locations for exporting data
if (is.null(opt$page_metadata)) opt$page_metadata <- "data/us-page-metadata.csv"
if (is.null(opt$page_text)) opt$page_text <- "data/us-page-text.csv"
if (is.null(opt$logfile)) opt$logfile <- "logs/extract-texts.log"

# Logging
dir.create(dirname(opt$logfile), showWarnings = FALSE)
log_formatter <- function(event) {
  paste(c(format(event$time, "%Y-%m-%d %H:%M:%OS3"), event$level, opt$INPUT,
          event$message), collapse = " - ")
}
log_file(opt$logfile, .formatter = log_formatter, overwrite = FALSE)

# Check inputs for errors
stopifnot(file.exists(opt$INPUT))
stopifnot(dir.exists(dirname(opt$page_metadata)))
stopifnot(dir.exists(dirname(opt$page_text)))
stopifnot(dir.exists(dirname(opt$logfile)))

# Read XML
xml <- read_xml(opt$INPUT)

# We will need the document ID as the key in the tables
document_id <- xml_find_first(xml, "./bookInfo/documentID") %>% xml_text()

# Get the page nodes and extract the relevant metadata
pages       <- xml_find_all(xml, "./text/page")
page_info   <- xml_find_all(xml, "./text/page/pageInfo")
type        <- pages %>% xml_attr("type")
page_id     <- pages %>% xml_find_all("./pageInfo/pageID") %>% xml_text()
record_id   <- pages %>% xml_find_all("./pageInfo/recordID") %>% xml_text()
source_page <- page_info %>% xml_child("sourcePage") %>% xml_text()
ocr         <- pages %>% xml_find_all("./pageInfo/ocr") %>% xml_double()

page_metadata <- data_frame(
  document_id = document_id,
  type = type,
  page_id = page_id,
  record_id = record_id,
  source_page = source_page,
  ocr = ocr
)

# Turn a paragraph node into a character vector of length 1
para_to_char <- function(x) {
  x %>%
    xml_find_all("./wd") %>%
    xml_text() %>%
    str_c(collapse = " ")
}

# Turn a page node into a list of character vectors for each paragraph
get_paras <- function(x) {
  x %>%
    xml_find_all("./pageContent/p") %>%
    map_chr(para_to_char)
}

page_text <- data_frame(document_id = document_id,
                        page_id = page_id,
                        text = map(pages, get_paras)) %>%
  unnest(text)

# Write to files, appending if they already exist
write_csv(page_text, path = opt$page_text,
          append = file.exists(opt$page_text))
write_csv(page_metadata, path = opt$page_metadata,
          append = file.exists(opt$page_metadata))

log_info(str_c("Wrote ", nrow(page_text), " paragraphs from ",
               nrow(page_metadata), " pages for document ID ",
               document_id, "."))
