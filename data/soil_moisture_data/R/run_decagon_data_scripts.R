###############################################################################
# 
# Run all scripts related to decagon data processing 
# 
###############################################################################


##  Set working directory to source file location
setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) # only for RStudio
setwd("../")

if(!dir.exists('data/processed_data/')){ dir.create('data/processed_data/')}

source('R/import_and_format_decagon_data.R')

source('R/correct_decagon_dates.R')

source('R/correct_decagon_readings.R')

source('R/merge_decagon_with_climate_station_data.R')

source('R/export_daily_soil_moisture_for_SOILWAT.R')

