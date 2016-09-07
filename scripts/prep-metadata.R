# Load in the tables of metadata and prep it for analysis

library(readr)
library(dplyr)
library(stringr)
library(purrr)
library(forcats)

us_authors <- read_csv("data/us-authors.csv",
                       col_types = cols(.default = col_character()))

# Extract the first year in a string
get_year <- function(x) { as.integer(str_extract(x, "\\d{4}")) }

# Given two parallel vectors, pick the first NA value
pick <- function(x, y) { ifelse(!is.na(x), x, y) }

# The `marc_dates` column seems to be reliable broken up into the `birth_year`
# and `death_year` columns.
#
# Create a single field `creator` with either the `author` or `byline`.
us_authors <- us_authors %>%
  mutate(birth_year = get_year(birth_year),
         death_year = get_year(death_year),
         creator = pick(author, byline))

us_subjects <- read_csv("data/us-subjects.csv", col_types = "cccc")

# The subjects that have their origin from MOML can be duplicated: i.e., there are always exactly three. So remove duplicates. And we don't care about subjects that are labeled "US"
us_subjects_moml <- us_subjects %>%
  filter(subject_source == "MOML",
         subject != "US") %>%
  distinct(document_id, subject)

us_subjects_loc <- us_subjects %>%
  filter(subject_source == "LOC")

rm(us_subjects)

us_items <- read_csv("data/us-items.csv",
                     col_types = cols(
                         .default = col_character(),
                         publication_date = col_date(format = ""),
                         release_date = col_date(format = ""),
                         volume_current = col_integer(),
                         volume_total = col_integer(),
                         page_count = col_integer()
                       ))

clean_place <- function(x) {
  str_split(x, ",", n = 2) %>%
    map_chr(1) %>%
    str_replace_all("[[:punct:]]", "")
}

# clean_place(c("New Haven", "New Haven, CT", "[New Haven, CT]"))

us_items <- us_items %>%
  mutate(city = clean_place(imprint_city),
         city = fct_recode(city,
                           "Unknown" = "Sl",
                           "Unknown" = "US",
                           "New York" = "NewYork",
                           "Boston" = "Boston New York",
                           "Cambridge" = "Cambridge Mass",
                           "New York" = "New York City",
                           "Washington" = "Washington DC"),
         publication_year = lubridate::year(publication_date)) %>%
  filter(publication_year > 1795,
         publication_year < 1925)

save(us_items, us_subjects_loc, us_subjects_moml, us_authors,
     file = "data/us-metadata.rda")
