# Load functions
source("edit_param_functions.R")

# Example of an output directory on the Compute Canada server
#  Note: SORTIE needs absolute rather than relative paths for the output directory
out_dir <- "/project/6017193/sortie/Output"
templ_file <- "F1847T10050_no_epi.xml"
timesteps <- 100

# Create one parameter file for a specific plot from FERLD transects data
plot_id <- "1823-T1-0050"
create_param_file(plot_id, timesteps, templ_file, out_dir) 
# note: the function outputs "NULL", that is normal

# Create parameter files for all plots in a given fire year
transects <- read.csv("transect_meas.csv")
transects1823 <- filter(transects, str_detect(plot_id, "1823"))
plots1823 <- unique(transects1823$plot_id)

map(plots1823, create_param_file, timesteps = timesteps, 
    templ_file = templ_file, out_dir = out_dir)

