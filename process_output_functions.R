library(readr)
library(tidyr)
library(dplyr)
library(stringr)
library(purrr)
library(xml2)


# Read summary output file ------------------------------------------------

# The summary output file (.out) from a SORTIE-ND has separate columns for each
# combination of a lifestage, variable and species (e.g. "Sdl Abs Den: Balsam_Fir" 
# for the absolute density of balsam fir seedlings). It would be more convenient
# to have columns for Stage, Species, and then variables like "Abs Den", which is
# the format output by this function.
#
# This function assumes there are no subplots (only 1 table for the whole plot).
# Note that there will be NA values when a variable doesn't exist for a certain
# stage (e.g. seedlings don't have basal area).
read_summary_output <- function(file) {
    # "skip" removes a few non-table rows at the beginning of the file
    # it may not always be 5
    read_tsv(file, skip = 5) %>%
        # remove columns that represent totals across species
        select(!ends_with("Total:")) %>%
        # This transforms all columns except Step and Subplot to 4 columns:
        # Stage, Variable, Species and Value. The "names_pattern" argument
        # is a regular expression that is used to extract the Stage, 
        # Variable and Species names from the original column names
        pivot_longer(cols = -c(Step, Subplot),
                     names_to = c("Stage", "Variable", "Species"),
                     names_pattern = c("([[:alpha:]]*) (.*): (.*)"),
                     values_to = "Value") %>%
        # Finally, this pivots in the other direction to get a separate column 
        # for each variable (e.g. Absolute Density, Absolute Basal Area, etc.)
        pivot_wider(names_from = Variable, values_from = Value)
}


# Helper functions for treemap_from_file ----------------------------------

# See below for the main function that calls each of these helper functions.

# This data frame matches the "tp" attribute in the detailed output file
# to the name of the corresponding life stage. The correspondance was determined
# based on a specific parameter file and we are not sure it is always the same.
stages_df <- data.frame(
    tp = c("1", "2", "3", "5"),
    stage = c("seedling", "sapling", "adult", "snag")
)

# The "tm_treeSettings" elements of a detailed output treemap contain typically
# two codelists (one for integer and one for float variables) that associates the
# numeric codes with the variable labels. 
# Given one codelist, this function extracts the variable types 
# (either "tm_intCode" or "tm_floatCode"), numeric code (stored as character)
# and label (variable name) in a data frame.
codelist_to_df <- function(codelist) {
    data.frame(type = names(codelist),
               code = map_chr(codelist, 1),
               label = map_chr(codelist, ~ attr(., "label")))
}

# This function first applies the function above to each codelist in a 
# "tm_treeSettings" element to produce a single data frame, then it adds the 
# species and life stage ("tp" code) corresponding to the settings element
# as separate columns in the data frame. Finally, it transforms the type column
# to values "int" and "fl" to match the type names in the main treemap data frame.
setting_to_df <- function(setting) {
    map_dfr(setting, codelist_to_df) %>%
        mutate(species = attr(setting, "sp"),
               tp = attr(setting, "tp"),
               type = ifelse(str_detect(type, "int"), "int", "fl"))
}

# In a detailed output file, the data for each tree is contained in a "tree" 
# element, which is a list of values with attributes giving the variable
# code and names indicating the variable type ("int" = integer, "fl" = float).
#
# This function takes a single tree element and converts the list to a data frame
# with columns for type, code and value, and adds columns indicating the species
# and life stage code ("tp") based on the tree element's attributes.
tree_to_df <- function(tree_element) {
    data.frame(sp_code = attr(tree_element, "sp"), 
               tp = attr(tree_element, "tp"), 
               type = names(tree_element),
               code = map_chr(tree_element, ~ attr(., "c")),
               # map_chr(.., 1) takes the first (and only) value in each data element
               value = map_chr(tree_element, 1)) 
}


# Get treemap from detailed output file -----------------------------------

# Given a .xml filename from the SORTIE-ND detailed output (i.e. the output 
# for one time step), this function generates a list of data frames with the
# coordinates, species and variables corresponding to each tree (i.e. a tree map).
# The list contains one data frame by life stage (seedling, sapling, adult 
# and snag) since different variables are saved at each stage.

treemap_from_file <- function(file) {
    # Read XML file and convert to a list, then select "tr_treemap" element
    dout <- read_xml(file)
    dout <- as_list(dout)
    tm <- dout$timestepRundata$tr_treemap
    # The "tr_treemap" element a list that contains:
    # - one "tm_speciesList" element associating the species names to indices;
    # - multiple "tm_treeSettings" elements (for each species and lifestage) 
    #   matching variable codes to names;
    # - "tree" elements containing the data for each tree.
    
    # First extract the species list and covert to a data frame with species
    # codes and species names (species codes run from 0 to N_species - 1)
    num_sp <-  length(tm$tm_speciesList)
    species_df <- data.frame(
        sp_code = as.character(0:(num_sp - 1)),
        species = map_chr(tm$tm_speciesList, ~ attr(., "speciesName"))
    )
    # Extract all "tm_treeSettings" elements and apply the function setting_to_df
    # to each of them to produce a data frame with 5 columns:
    # species name, life stage code, variable type, variable code and variable name
    settings <- tm[names(tm) == "tm_treeSettings"]
    settings_df <- map_dfr(settings, setting_to_df)
    # Extract all tree elements
    trees <- tm[names(tm) == "tree"]
    # Remove element names (all "tree") so that their numeric index becomes the ID
    names(trees) <- NULL
    # Apply the tree_to_df function to each of them, and add an ID column when combining,
    # to produce a data frame with the following columns:
    # tree id, species code, life stage code, variable type, variable code, value 
    tree_df <- map_dfr(trees, tree_to_df, .id = "id")
    tree_df$id <- as.numeric(tree_df$id)
    # Join with the species, life stages and settings data frames produced above
    # to get the species names, life stage names and variable names (labels)
    # associated with each value.
    tree_df <- inner_join(tree_df, species_df) %>%
        inner_join(stages_df) %>%
        inner_join(settings_df)
    # Keep only the tree id, species name, life stage name, variable label and value
    # and "nest" to produce a "stage" column and "data" column, the latter being
    # a list of data frames, one by lifestage
    tree_df <- select(tree_df, id, species, stage, label, value) %>%
        mutate(value = as.numeric(value)) %>% # convert values from text to numeric
        nest_by(stage)
    # "pivot" the data frame from each lifestage so instead of "label" and "value"
    # columns, there is one column per variable with the labels as column names
    tree_list <- map(tree_df$data, pivot_wider, names_from = label, values_from = value)
    # use the life stage names to name each data frame in the resulting list
    names(tree_list) <- tree_df$stage
    tree_list # output the list of data frames
}
