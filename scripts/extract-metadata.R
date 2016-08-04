#!/usr/bin/env Rscript
#
# Extract metadata from Making of Modern Law XML files

suppressPackageStartupMessages(library(docopt))
suppressPackageStartupMessages(library(magrittr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(xml2))
suppressPackageStartupMessages(library(tibble))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(loggr))
suppressPackageStartupMessages(library(purrr))

"Extract metadata from XML record from the Making of Modern Law

Usage: extract-metadata.R INPUT [--authors=<authors>] [--subjects=<subjects>] [--titles=<titles>]

Options:
  <INPUT>                   Path to XML record from MoML.
     --authors=<authors>     Path to CSV file to append author metadata.
     --subjects=<subjects>   Path to CSV file to append subject metadata.
     --titles=<titles>        Path to CSV file to append title information.
  -h --help                 Show this message.
" -> doc

opt <- docopt(doc)

# Logging
dir.create("logs", showWarnings = FALSE)
log_formatter <- function(event) {
  paste(c(format(event$time, "%Y-%m-%d %H:%M:%OS3"), event$level, opt$INPUT,
          event$message), collapse = " - ")
}
log_file("logs/extract-metadata.log", INFO, WARN, ERROR, .formatter = log_formatter)

# Default locations for exporting data
if (is.null(opt$authors)) opt$authors <- "data/authors.csv"
if (is.null(opt$subjects)) opt$subjects <- "data/subjects.csv"
if (is.null(opt$titles)) opt$titles <- "data/titles.csv"

# Check inputs for errors
stopifnot(file.exists(opt$INPUT))
stopifnot(dir.exists(dirname(opt$authors)))
stopifnot(dir.exists(dirname(opt$subjects)))
stopifnot(dir.exists(dirname(opt$titles)))

xml <- read_xml(opt$INPUT)
book_info <- xml %>% xml_find_first("bookInfo")

extract_tag <- function(xml, tag) {
  out <- xml %>% xml_child(tag) %>% xml_contents() %>% as.character()
  if (length(out) == 0) out <- NA_character_
  out
}

# We will need the document ID as the key in the tables
document_id <- book_info %>% extract_tag("documentID")

# Extract the metadata into the three tables
titles <- tibble(
  document_id = document_id,
  publication_date = extract_tag(book_info, "pubDate") %>% ymd(),
  language = extract_tag(book_info, "language"),
  collection_id = extract_tag(book_info, "collectionId"),
  release_date = extract_tag(book_info, "releaseDate") %>% ymd(),
  source_bib_citation = extract_tag(book_info, "sourceBibCitation"),
  source_library = extract_tag(book_info, "sourceLibrary"),
  notes = extract_tag(book_info, "notes"),
  comments = extract_tag(book_info, "comments"),
  category_code = extract_tag(book_info, "categoryCode")
)
stopifnot(nrow(titles) == 1)

authors <- tibble(
  document_id = document_id
)

moml_subject_sources <- rep("MOML", 3)
moml_subject_types <- c("subject1", "subject2", "subject3")
moml_subjects <- map_chr(moml_subject_types,
                         function(x) extract_tag(book_info, x))
moml_subject_parts <- rep(NA_character_, 3)

subjects <- tibble(
  document_id = document_id,
  subject_source = c(moml_subject_sources),
  subject_type = c(moml_subject_types),
  subject = c(moml_subjects),
  subject_part_1 = c(moml_subject_parts),
  subject_part_2 = c(moml_subject_parts)
)

# Write to files, appending if the file already exists
write_csv(titles, path = opt$titles, append = file.exists(opt$titles))
write_csv(authors, path = opt$authors, append = file.exists(opt$authors))
write_csv(subjects, path = opt$subjects, append = file.exists(opt$subjects))
