#!/usr/bin/env Rscript
#
# Extract the paragraph level text from a Making of Modern Law XML file

suppressPackageStartupMessages(library(docopt))
suppressPackageStartupMessages(library(magrittr))
suppressPackageStartupMessages(library(xml2))
suppressPackageStartupMessages(library(tibble))
suppressPackageStartupMessages(library(loggr))
suppressPackageStartupMessages(library(purrr))
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
# opt <- docopt(doc, args = "test/20004432800/xml/20004432800.xml")

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

# Read XML
xml <- read_xml(opt$INPUT)

# We will need the document ID as the key in the tables
document_id <- xml %>%
  xml_find_first("bookInfo") %>%
  xml_child("documentID") %>%
  xml_contents() %>%
  as.character()

# Helper for getting contents of tag
extract_tag <- function(xml, tag) {
  out <- xml %>% xml_child(tag) %>% xml_contents() %>% as.character()
  if (length(out) == 0) out <- NA_character_
  out
}

# Get the page nodes
pages <- xml %>%
  xml_child("text") %>%
  xml_find_all("page")

# Extract the page level metadata into a data frame
get_page_metadata <- function(x) {
  type <- x %>% xml_attr("type")
  first_page <- x %>% xml_attr("firstPage")
  page_info <- x %>% xml_child("pageInfo")
  page_id <- page_info %>% extract_tag("pageID")
  record_id <- page_info %>% extract_tag("recordID")
  source_page <- page_info %>% extract_tag("sourcePage")
  ocr <- page_info %>% extract_tag("ocr") %>% as.numeric()

  data_frame(document_id = document_id,
             type = type,
             first_page = first_page,
             page_id = page_id,
             record_id = record_id,
             source_page = source_page,
             ocr = ocr)
}

page_metadata <- pages %>% map_df(get_page_metadata)

# Extract the paragraphs in each page
# Get a character vector of the text from a paragraph node
get_para <- function(x) {
  x %>% xml_find_all("wd") %>% xml_text() %>% str_c(collapse = " ")
}

# Get a data frame of the paragraphs on a page
get_page_text <- function(x) {
  page_id <- x %>% xml_child("pageInfo") %>% extract_tag("pageID")
  paragraphs <- x %>% xml_child("pageContent") %>% xml_find_all("p")
  paragraph_text <- paragraphs %>% map_chr(get_para)
  paragraph_number <- seq_along(paragraph_text)
  data_frame(document_id = document_id,
             page_id = page_id,
             text = paragraph_text,
             paragraph_number = paragraph_number)
}

page_text <- pages %>% map_df(get_page_text)

# Write to files, appending if they already exist
write_csv(page_text, path = opt$page_text,
          append = file.exists(opt$page_text))
write_csv(page_metadata, path = opt$page_metadata,
          append = file.exists(opt$page_metadata))

log_info(str_c("Wrote ", nrow(page_text), " paragraphs from ",
               nrow(page_metadata), " pages for document ID ",
               document_id, "."))
