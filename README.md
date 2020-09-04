# Flash Floods (FF) Products Thresholds

This repository hosts analysis data and programming scripts supporting the study by Gourley and Vergara (2020) on the definition of threshold levels for products used in US NOAA NWS warning operations for flash floods. The analysis data were derived from archived raster data from the Multi-Radar Multi-Sensor (MRMS) – Flooded Locations And Simulated Hydrographs (FLASH) system. The study period was June 2018 through May 2019. The flash flood products considered were:

* Rainfall Accumulations for 30-min, 1-hr, 3-hr, 6-hr, 12-hr and 24-hr accumulation intervals
* Unit Streamflow from the three water balance models in FLASH: CREST, SAC-SMA, HP Unit 
* Quantitative Precipitation Estimates (QPE)-to-Flash Flood Guidance (FFG) Ratio for 30-min, 1-hr, 3-hr, 6-hr, 12-hr and 24-hr accumulation intervals
* Rainfall Annual Recurrence Intervals (ARIs) for 30-min, 1-hr, 3-hr, 6-hr, 12-hr and 24-hr accumulation intervals

## Source (Raw) Data

The data used for this study comes from archived MRMS and FLASH outputs. They are not included in this repository since they can be readily accessed at https://flash.ou.edu/new.

StormData reports for the period of study were obtained as a single CSV file, which can be found in the "source_data/" folder. The file name is "events_A4875356EB81004A1C6C9C960CF48888.csv".

The scripts in this repository point to the folder "source_data/" to read the above datasets where applies.

## Auxiliary data

Some auxiliary files defining the Conterminous United States (CONUS) geospatial domains at different resolutions and used by the various scripts are in "auxiliary/"

* corrected_conus_regions_mask50km.tif - A raster mask of the regions over CONUS domain at 50-km pixel resolution
* flash_conus_mask1km.tif - A raster mask of the CONUS FLASH domain at 1-km pixel resolution
* flash_conus_mask50km.tif - A raster mask of the CONUS FLASH domain at 50-km pixel resolution
* max_1km_BasinImperviousness_50km.tif - A raster containing maximum values of basin percent of impervious surfaces resampled to 50-km pixel resolution

## Scripts

Most of the scripts used to process the data for the study are MATLAB scripts. These scripts were written as templates with "wildcard text" that is substituted by a C-Shell script to be run in parallel in a cluster. The tasks were subsetted by weeks within the 1-year period. The file "scripts/Selected_Days.csv" contain the list of individual weeks for which the scripts are used.

There are two sets of scripts corresponding to:

* *General* - For all products, all seasons and all regions.
  - **createHeatMap_ARIexceedances.m** - Creates a heat map of rainfall ARIs exceedances for the period of study

  - **RunPreProcessReports.csh** - Runs pre-processing of StormData reports using MATLAB script template below:
    - template_preProcess_reportsv2.m

  - **RainAccum_SubmitJobs.csh** - Runs processing to identify exceedances for rainfall acumulation products for various thresholds using MATLAB script template below:
    - rainaccum_regional_seasonal_based_template_MultiThreshold_EventIdentification.m

      - Note: The script above uses a tool invoked as **MRMSConvert**. This is a tool part of the EF5 toolset, another publicly available repository at https://github.com/HyDROSLab/EF5/blob/master/compile_trmm_tools.csh. This tool is necessary to use the "rainaccum_regional_seasonal_based_template_MultiThreshold_EventIdentification.m" script that accumulates MRMS precipitation rates on MRMS binary format.

* *Imperviousness analysis* - For Unit Streamflow products only, all seasons, all regions and looking at different ranges of basin percent of impervious surfaces.
  - **RunPreProcessReports_IM_analysis.csh** - Runs pre-processing of StormData reports using MATLAB script template below:
    - template_preProcess_reports_imAnalysis.m 

## Outputs

Pre-computed outputs from the scripts in this repository are also included here for convenience. Some of these files are of MATLAB's binary format ('.mat') and some other are simple CSV format. These pre-computed outputs have been organized by the two sets of scripts mentioned above (General and Imperviousness Analysis), for which corresponding sub-folders exist. Sub-folders were also organized for each individual product to store weekly .mat files.

CSV files within the outputs/general/ and outputs/imperviousness_analysis/ contain the contingency tables statistics used for the analysis described in Gourley and Vergara (2020). Two sets of each of these files were derived: one containing all weeks within the 1-year period, and a second one excluding several weeks between late December of 2018 and mid February of 2019. The latter set was produced to account for the impacts of the blackout experienced during the government shutdown of December 2018-January 2019. A couple of sample file names corresponding to these two sets are provided below:

* outputs/general/hs18_noShutDown_regional_and_seasonal_All_weeks_contingency_stats_24H.ARI.csv - Excludes weeks impacted by shutdown
* outputs/general/hs18_regional_and_seasonal_All_weeks_contingency_stats_24H.ARI.csv - Based on the entire `-year period of study
