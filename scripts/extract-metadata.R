#!/usr/bin/env Rscript
#
# Extract metadata from Making of Modern Law XML files

suppressPackageStartupMessages(library(docopt))
suppressPackageStartupMessages(library(magrittr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(xml2))

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

document_id <- book_info %>% xml_child("documentID") %>% xml_contents() %>% as.character()
