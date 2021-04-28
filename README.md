# Tools to work with the SORTIE-ND model and the FERLD data

The R code in this project aims to simplify the editing of parameter files for input to the [SORTIE-ND](http://www.sortie-nd.org/) forest simulator, especially using plot composition data from the Lake Duparquet Research and Teaching Forest (FERLD / LDRTF), and to process the simulation output files.

## Contents

### Data file

*transect_meas.csv*

Plot composition data in transects along the 249-year mixed boreal forest chronosequence at the FERLD. The complete dataset, of which this is one table, is described in [this data paper](https://doi.org/10.1002/ecy.3306). The data are comprised of 6 columns:

- *plot_id*: 12-character plot ID formed by year of last fire, transect number and distance along transect
- *year*: Year of plot census (1991 or 2009)
- *species_id*: Species ID (see full dataset for species codes)
- *status_id*:	Whether stem is alive (A) or dead (D)
- *dbh_class*: Diameter at breast height (DBH) class, denoted by midpoint of class (in cm), i.e. 0.5 for seedlings (DBH <1cm), 2.5 for saplings (DBH <5cm), 7.5 for trees 5-10cm, and so on by 5-cm increments
- *count*: Number of stems with this species, status and DBH class in plot for the given year

### SORTIE-ND parameter files

*F1847T10050.xml* and *F1847T10050_no_epi.xml*

The latest version of the SORTIE-ND boreal model parametrized using data from the FERLD, as used in the following article by Maleki et al.

- Maleki, K., Gueye, M.A., Lafleur, B., Leduc, A. and Bergeron, Y. 2020. Modelling post-disturbance successional dynamics of the Canadian boreal mixedwoods. Forests 11:3. [https://doi.org/10.3390/f1101000](https://doi.org/10.3390/f1101000).  

These particular files uses an initial stand composition (stems / ha) based on the 1847-T1-0050 plot in 1991, which can be changed using the R code included.

The difference between the two files is that the first one includes an episodic mortality behavior to simulate fir and spruce mortality from the spruce budworm on year 30 of the simulation, whereas the other (*no_epi*) does not include this behavior.

### R code files

*edit_param_functions.R* 

The functions in this file allow the user to create a new SORTIE-ND parameter file by changing specific fields in a template parameter file, such as the number of timesteps, the output folder and the initial tree density for each species. The latter is a complex data structure in the XML parameter files, so there is a separate function to format the initial density specification based on the composition of an empirical plot in the `transect_meas.csv` file.

*edit_param_file_example.R*

This file contains examples on how to use the functions in the previous file.

*process_output_functions.R*

This file contains two main functions to: (1) convert the summary output of a SORTIE-ND simulation to a standard data frame form in R; (2) extract a tree map from a detailed output file and convert it to a list of data frames (with one data frame by life stage, e.g. seedling, sapling, adult, snag).

Note that SORTIE-ND detailed output files are .xml files in each time step that are compressed into a .tar.gz archive. The function in this script is to process a single .xml files.