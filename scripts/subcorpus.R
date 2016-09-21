# Get a subcorpus of just the body text for some subject

library(dplyr)
library(readr)
library(stringr)
library(purrr)


load("data/us-metadata.rda")
pages <- read_csv("/media/data/moml/us-tables/us-pages.csv",
                  col_types = "cccdcd")
text <- read_csv("/media/data/moml/us-tables/us-text.csv",
                 col_types = "ccic")

SUBJECT <- "railroad"
OUT_DIR <- "/media/data/moml/subsets/railroads/"
SUBJECT_TYPE <- "loc"

if (SUBJECT_TYPE == "moml") {
  keeper_docs <- us_subjects_moml %>%
    filter(subject == SUBJECT)
} else {
  keeper_docs <- us_subjects_loc %>%
    filter(str_detect(subject, coll(SUBJECT, ignore_case = TRUE)))
}

keeper_pages <- pages %>%
  filter(document_id %in% keeper_docs$document_id) %>%
  filter(type == "bodyPage") %>%
  left_join(text, by = c("document_id", "page_id")) %>%
  group_by(document_id, page_id) %>%
  summarize(text = str_c(text, collapse = " "))

write_page <- function(df) {
  path <- str_c(OUT_DIR, df$document_id, "-", df$page_id, ".txt")
  write_lines(df$text, path)
}

dir.create(OUT_DIR, recursive = TRUE)
by_row(keeper_pages, write_page)
