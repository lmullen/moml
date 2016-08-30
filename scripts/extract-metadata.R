#!/usr/bin/env Rscript
#
# Extract document-level metadata from a Making of Modern Law XML file

suppressPackageStartupMessages(library(docopt))
suppressPackageStartupMessages(library(magrittr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(xml2))
suppressPackageStartupMessages(library(tibble))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(loggr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(dplyr))

"Extract metadata from an XML record from the Making of Modern Law

Usage: extract-metadata.R INPUT --outdir=<outdir> [--logfile=<logfile>]

Options:
  <INPUT>                    Path to XML record from MoML.
  -o --outdir=<outdir>       Directory in which output files will be created.
  -l --logfile=<logfile>     Path to file for logging.
  -h --help                  Show this message.
" -> doc

opt <- docopt(doc)
# opt <- docopt(doc, args = "test/20003495100.xml -o temp")

# Check inputs for errors
stopifnot(file.exists(opt$INPUT))
stopifnot(dir.exists(opt$outdir))

# Locations for exporting data
opt$file_id <- opt$INPUT %>% basename() %>% tools::file_path_sans_ext()
opt$authors  <- str_c(opt$outdir, "/", opt$file_id, "-authors.csv")
opt$subjects <- str_c(opt$outdir, "/", opt$file_id, "-subjects.csv")
opt$items    <- str_c(opt$outdir, "/", opt$file_id, "-items.csv")
opt$pages    <- str_c(opt$outdir, "/", opt$file_id, "-pages.csv")
if (is.null(opt$logfile)) opt$logfile <- "log/metadata-export.log"

# Logging
dir.create(dirname(opt$logfile), showWarnings = FALSE)
log_formatter <- function(event) {
  paste(c(format(event$time, "%Y-%m-%d %H:%M:%OS3"), event$level, opt$INPUT,
          event$message), collapse = " - ")
}
log_file(opt$logfile, .formatter = log_formatter, overwrite = FALSE)

# Read XML and get the relevant metadata portions
xml <- read_xml(opt$INPUT)
book_info <- xml %>% xml_find_first("bookInfo")
citation <- xml %>% xml_find_first("citation")
title_group <- citation %>% xml_find_first("titleGroup")
volume_group <- citation %>% xml_find_first("volumeGroup")
imprint <- citation %>% xml_find_first("imprint")

extract_tag <- function(xml, tag) {
  out <- xml %>% xml_child(tag) %>% xml_text()
  if (length(out) == 0) out <- NA_character_
  out
}

# We will need the document ID as the key in the tables
document_id <- book_info %>% extract_tag("documentID")

# Extract the metadata into the three tables
items <- tibble(
  document_id = document_id,
  title_full = extract_tag(title_group, "fullTitle"),
  title_display = extract_tag(title_group, "displayTitle"),
  title_variant = extract_tag(title_group, "variantTitle"),
  publication_date = extract_tag(book_info, "pubDate") %>% ymd(),
  language = extract_tag(book_info, "language"),
  collection_id = extract_tag(book_info, "collectionId"),
  release_date = extract_tag(book_info, "releaseDate") %>% ymd(),
  source_bib_citation = extract_tag(book_info, "sourceBibCitation"),
  source_library = extract_tag(book_info, "sourceLibrary"),
  notes = extract_tag(book_info, "notes"),
  comments = extract_tag(book_info, "comments"),
  category_code = extract_tag(book_info, "categoryCode"),
  volume_current = extract_tag(volume_group, "currentVolume"),
  volume_total = extract_tag(volume_group, "totalVolumes"),
  imprint_full = extract_tag(imprint, "imprintFull"),
  imprint_city = extract_tag(imprint, "imprintCity"),
  imprint_publisher = extract_tag(imprint, "imprintPublisher"),
  imprint_year = extract_tag(imprint, "imprintYear"),
  edition = extract_tag(citation, "edition"),
  collation = extract_tag(citation, "collation"),
  publication_place = extract_tag(citation, "publicationPlace"),
  page_count = extract_tag(citation, "totalPages"),
  page_count_type = citation %>% xml_find_first("totalPages") %>% xml_attr("type")
)
stopifnot(nrow(items) == 1)

moml_subject_sources <- rep("MOML", 3)
moml_subject_types <- c("subject1", "subject2", "subject3")
moml_subjects <- map_chr(moml_subject_types,
                         function(x) extract_tag(book_info, x))

moml_subjects_df <- tibble(
  document_id = document_id,
  subject_source = moml_subject_sources,
  subject_type = moml_subject_types,
  subject = moml_subjects
)

extract_loc_subject <- function(subject) {
  source <- "LOC"
  type <- subject %>% xml_attr("type")
  parts <- map_chr(xml_children(subject),
                   function(x) x %>% xml_contents() %>% as.character())
  subject <- paste(parts, collapse = " -- ")
  tibble(document_id = document_id,
         subject_source = source,
         subject_type = type,
         subject = subject
         )
}

loc_subjects_df <- book_info %>%
  xml_find_all("locSubjectHead") %>%
  map_df(extract_loc_subject)

subjects <- bind_rows(moml_subjects_df, loc_subjects_df)

extract_author <- function(ag) {
  author <- ag %>% xml_child() %>% extract_tag("marcName")
  birth_year <- ag %>% xml_child() %>% extract_tag("birthDate")
  death_year <- ag %>% xml_child() %>% extract_tag("deathDate")
  marc_dates <- ag %>% xml_child() %>% extract_tag("marcDate")
  byline <- ag %>% extract_tag("byline")
  tibble(document_id = document_id,
         author = author,
         birth_year = birth_year,
         death_year = death_year,
         marc_dates = marc_dates,
         byline = byline)
}

authors <- citation %>%
  xml_find_all("authorGroup") %>%
  map_df(extract_author)

# Get the page nodes and extract the relevant metadata
pages       <- xml_find_all(xml, "./text/page")
page_info   <- xml_find_all(xml, "./text/page/pageInfo")
type        <- pages %>% xml_attr("type")
page_id     <- pages %>% xml_find_all("./pageInfo/pageID") %>% xml_text()
record_id   <- pages %>% xml_find_all("./pageInfo/recordID") %>% xml_text()
source_page <- page_info %>% xml_child("sourcePage") %>% xml_text()
ocr         <- pages %>% xml_find_all("./pageInfo/ocr") %>% xml_double()

pages <- data_frame(
  document_id = document_id,
  type = type,
  page_id = page_id,
  record_id = record_id,
  source_page = source_page,
  ocr = ocr
)

# Write to files and log success
write_csv(items, path = opt$items, col_names = FALSE)
log_info(str_c("Wrote item metadata for ", nrow(items), " items."))
write_csv(authors, path = opt$authors, col_names = FALSE)
log_info(str_c("Wrote author metadata for ", nrow(authors), " authors."))
write_csv(subjects, path = opt$subjects, col_names = FALSE)
log_info(str_c("Wrote subject metadata for ", nrow(subjects), " subjects."))
write_csv(pages, path = opt$pages, col_names = FALSE)
log_info(str_c("Wrote page metadata for ", nrow(pages), " pages."))
