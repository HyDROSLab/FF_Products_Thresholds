# Flash Floods (FF) Products Thresholds

This repository hosts analysis data and programming scripts supporting the study by Gourley and Vergara (2020) on the definition of threshold levels for products used in US NOAA NWS warning operations for flash floods. The analysis data were derived from archived raster data from the Multi-Radar Multi-Sensor (MRMS) – Flooded Locations And Simulated Hydrographs (FLASH) system. The study period was June 2018 through May 2019. The flash flood products considered were:

* Rainfall Accumulations for 30-min, 1-hr, 3-hr, 6-hr, 12-hr and 24-hr accumulation intervals
* Unit Streamflow from the three water balance models in FLASH: CREST, SAC-SMA, HP Unit 
* Quantitative Precipitation Estimates (QPE)-to-Flash Flood Guidance (FFG) Ratio for 30-min, 1-hr, 3-hr, 6-hr, 12-hr and 24-hr accumulation intervals
* Rainfall Annual Recurrence Intervals (ARIs) for 30-min, 1-hr, 3-hr, 6-hr, 12-hr and 24-hr accumulation intervals

## Source (Raw) Data

The data used for this study comes from archived MRMS and FLASH outputs. They are not included in this repository because they can be readily accessed at https://flash.ou.edu/new.

StormData reports for the period of study were obtained as a single CSV file, wchich can be found in the "source_data/" folder. The file name is "events_A4875356EB81004A1C6C9C960CF48888.csv".

The scripts in this repository point to the folder "source_data/" to read the above datasets where applies.

## Auxiliary data



## Scripts

Most of the scripts used to process the data for the study are MATLAB scripts.

## Outputs

Pre-computed outputs from the scripts in this repository are also included here for convenience. Some of these files are of MATLAB's binary format ('.mat') and some other are simple CSV format.
