library(dplyr)
library(purrr)
library(stringr)
library(xml2)

# This function extracts the tree density data 
# from the "transect_meas.csv" file for a certain plot and year, 
# then formats it as an initial tree density list for the SORTIE parameter file

get_transect_init_dens <- function(plot, yr) {
    # This data frame is to translate between the species_id in the transect data
    #  and the species_name in the SORTIE model
    sp_tab <- data.frame(
        species_name = c("White_Cedar", "Balsam_Fir", "Mountain_Maple", "White_Spruce",
                         "Jack_Pine", "Trembling_Aspen", "Paper_Birch"),
        species_id = c("TOC", "ABA", "ASP", "PGL", "PBA", "PTR", "BPA")
    )
    
    dens_df <- read.csv("transect_meas.csv") %>%
        # only keep alive trees (status "A") for the specified plot and year
        filter(plot_id == plot, year == yr, status_id == "A") %>%
        # join with sp_tab to get species names
        inner_join(sp_tab, by = "species_id") %>%
        mutate(
            # change species_name to factor to get same ordering of species 
            #  as sORTIE file (not sure if that's important)
            species_name = factor(species_name, levels = sp_tab$species_name),
            # convert DBH class to size classes written as in SORTIE file (e.g.: 7.5 becomes s10.0)
            size_class = ifelse(dbh_class == 0.5, "Seedling", 
                                paste0("s", dbh_class + 2.5, ".0")),
            # get appropriate plot size in ha (256 m2 = 0.0256 ha for adults, 
            #  0.0064 ha for saplings, 0.0012 ha for seedlings)
            plot_size = case_when(dbh_class == 0.5 ~ 0.0012,
                                  dbh_class == 2.5 ~ 0.0064,
                                  TRUE ~ 0.0256),
            # get density from counts and plot size
            density = paste0(round(count / plot_size), ".0")
        ) %>%
        # sort by species and dbh_class to get same ordering as original parameter file
        #  (maybe not needed)
        arrange(species_name, dbh_class) %>%
        select(species_name, size_class, density)
    
    # nest the data by species (so dens_nest has one row by species, 
    #  and the 2nd column contains one data frame by species)
    dens_nest <- nest_by(dens_df, species_name, .key = "size_density_data") %>%
        # retransform species name to character (not factor)
        mutate(species_name = as.character(species_name))
    
    # this creates the initial tree density list for one species (one row of dens_nest)
    create_init_dens_list <- function(species_name, size_density_data) {
        # for each row in size_density_data, produces a list of one element (the density)
        #  with one attribute (the size class)
        init_dens <- pmap(size_density_data,
                          function(size_class, density) structure(list(density), sizeClass = size_class))
        # set the name of every element of the list to "tr_initialDensity" to match SORTIE param file
        init_dens <- set_names(init_dens, rep("tr_initialDensity", length(init_dens)))
        # structure adds the whatSpecies attribute (species name) to the list
        structure(init_dens, whatSpecies = species_name)
    }
    
    # apply the function above to all species
    dens_nest_list <- pmap(dens_nest, create_init_dens_list)
    # name every element of list as "tr_idVals" to match SORTIE parameter file
    set_names(dens_nest_list, rep("tr_idVals", length(dens_nest_list)))
}

# This function creates a new SORTIE parameter file from the template templ_file
# with the tree initial density from a given plot_id, and sets the number of timesteps
# and the output filenames to be saved in the given output directory.
create_param_file <- function(plot_id, timesteps, templ_file, out_dir) {
    # Read template parameter file from XML and convert to R list
    par_xml <- read_xml(templ_file)
    par_list <- as_list(par_xml)
    
    # Produce new tree initial density info
    dens_new <- get_transect_init_dens(plot = plot_id, yr = 1991)
    
    # Replace density info in original list
    par_list$paramFile$trees$tr_initialDensities <- dens_new
    
    # Change number of timesteps
    par_list$paramFile$plot$timesteps[[1]] <- as.character(timesteps)
    
    # Change output filenames
    plot_id_alnum <- str_replace_all(plot_id, "[^[:alnum:]]", "")
    par_list$paramFile$Output$ou_filename[[1]] <- paste0(out_dir, "/F", plot_id_alnum, ".gz.tar")
    par_list$paramFile$ShortOutput$so_filename[[1]] <- paste0(out_dir, "/F", plot_id_alnum, ".out")
    
    # Convert back to XML format and save in new file
    par_xml_new <- as_xml_document(par_list)
    write_xml(par_xml_new, paste0("F", plot_id_alnum, "_no_epi.xml"))
}