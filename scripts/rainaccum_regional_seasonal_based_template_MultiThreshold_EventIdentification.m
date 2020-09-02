product_name = [{'01H.ACC.'}, {'03H.ACC.'}, {'06H.ACC.'}, {'24H.ACC.'}];
all_product_folder = [{'01HACC/'}, {'03HACC/'}, {'06HACC/'}, {'24HACC/'}];
product_interval = [1,3,6,24];

product_res = [1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30)]; 

prod_i = {PRODi};

convertMRMS = '/hydros/humberva/EF5/EF5/bin/MRMSConvert';

% Thresholds in inches as H&S2018
all_prod_ths(1,:) = [1, 1.5, 2, 2.5, 3, 3.5 , 4];
all_prod_ths(2,:) = [1.5, 2, 2.5, 3, 3.5, 4, 5];
all_prod_ths(3,:) = [1.5, 2, 2.5, 3, 3.5, 4, 5];
all_prod_ths(4,:) = [2, 2.5, 3, 3.5, 4, 5, 6];

all_prod_th = all_prod_ths(prod_i,:).*25.4; %Convert to mm

root_product_folder = '/hydros/humberva/CONUS_Datasets/MRMS_2015_Present/V12/q3evap/';
product = product_name{prod_i};
outFile_product = product;

product_folder = all_product_folder{prod_i};

mapinfo50km = geotiffinfo('HS2018_Analysis/flash_conus_mask50km.tif');
mapinfo1km = geotiffinfo('HS2018_Analysis/flash_conus_mask1km.tif');

mask = imread('HS2018_Analysis/flash_conus_mask50km.tif');
regions_grid = imread('HS2018_Regional_Seasonal_Analysis/corrected_conus_regions_mask50km.tif');

total_pixels = numel(mask(mask==1));
%clear mask;

nrows50 = mapinfo50km.Height;
ncols50 = mapinfo50km.Width;

%Period configuration
tstep = product_res(prod_i);
start_date = '{STARTDATE}';
end_date = '{ENDDATE}';

%Create folder to temporarily store rain files
mkdir([start_date, '_', product_folder]);
%Rename inputFolder
product_folder = [start_date, '_', product_folder];

%20170514.1200,20170521.1200 - Build X amount of prior hours to accumulate up to start of actual period
period = datenum(start_date, 'yyyymmdd.HHMM'):tstep:datenum(end_date, 'yyyymmdd.HHMM');
real_period = datenum(start_date, 'yyyymmdd.HHMM')-product_interval(prod_i)/24:tstep:datenum(end_date, 'yyyymmdd.HHMM');
period_24h = period(1):1:period(end);

%load reports
load(['HS2018_Regional_Seasonal_Analysis/Completed/Reports_MultiThreshold_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat']); 

%---Initialize Variables---
pixel_sizes = 50;
pixels_nrows = nrows50;
pixels_ncols = ncols50;
region_ids = unique(regions_grid(regions_grid>0));
n_regions = numel(region_ids);
region_total_pixels = zeros(1,n_regions);

for reg_i = 1:n_regions
	region_total_pixels(reg_i) = numel(find(regions_grid == region_ids(reg_i)));

	fprintf('There are %.f pixels in region %.f\n', region_total_pixels(reg_i), region_ids(reg_i));
end

%Initialization of output variable
cont_th = 0;
for prod_th = 1:numel(all_prod_th)
	cont_th = cont_th + 1;
	all_thresholds_events{cont_th} = [];
	all_hits{cont_th} = 0;
	all_misses{cont_th} = 0;
	all_false_alarms{cont_th} = 0;
	all_correct_negatives{cont_th} = 0;
end

%Arrays for region-based contingency counts
hits_map = zeros(numel(all_prod_th),n_regions);        
misses_map = zeros(numel(all_prod_th),n_regions);        
false_alarms_map = zeros(numel(all_prod_th),n_regions);        
correct_negatives_map = zeros(numel(all_prod_th),n_regions);

%***Accumulate rainfall upto the start of this period
%Variable that accumulates rainfall with a sliding window
accumXh = zeros([mapinfo1km.Height mapinfo1km.Width], 'single');
accum_cont = 0;
X = product_interval(prod_i); %X number of hours of accumulation interval

fprintf('Working on interval %.f\n', X);

%First X hours
for t = 2:1:X*30
    try
	system([convertMRMS, ' ', root_product_folder, 'PRECIPRATE.EVAP.', datestr(real_period(t), 'yyyymmdd.HHMM00'), '.gz ', product_folder, 'PRECIPRATE.EVAP.', datestr(real_period(t), 'yyyymmdd_HHMM'), '.tif']);

        precip = imread([product_folder, 'PRECIPRATE.EVAP.', datestr(real_period(t), 'yyyymmdd_HHMM'), '.tif']);
        precip(precip<0) = 0;

	%Round off
	precip = round(precip.*((2/60)*100))./100; %From mm/hr to mm

	%Delete temporary file
	system(['rm ', product_folder, 'PRECIPRATE.EVAP.', datestr(real_period(t), 'yyyymmdd_HHMM'), '.tif']);
    catch ME
	fprintf('Missing precip file %s .... assuming zeros...\n', [product_folder, 'PRECIPRATE.EVAP.', datestr(real_period(t), 'yyyymmdd_HHMM'), '.tif']);
	precip = zeros([mapinfo1km.Height mapinfo1km.Width], 'single');
    end

    accumXh = accumXh + precip;
    accum_cont = accum_cont + 1;
end

fprintf('Accumulated rainfall from %s through %s\n', datestr(real_period(2), 'yyyymmdd_HHMM'), datestr(real_period(X*30), 'yyyymmdd_HHMM'));
n_bad = numel(accumXh(accumXh<0));
fprintf('N of bad data is %.f\n', n_bad);
%***End of Accumulate rainfall upto the start of this period

%Loop through period of study
counters = 0;
n_steps = round(1/tstep);
day_counter = 0;

%Loop through main period of data
fprintf('Starting processing with rainfall on %s\n', datestr(period(1), 'yyyymmdd_HHMM'));
for t = period
    %Counter that controls number of steps that make a full day
    counters = counters + 1;

    %Try reading in new file
    try
	try
	    fprintf('Reading values from %s\n', [product_folder, 'PRECIPRATE.EVAP.', datestr(t, 'yyyymmdd_HHMM'), '.tif']);
	    system([convertMRMS, ' ', root_product_folder, 'PRECIPRATE.EVAP.', datestr(t, 'yyyymmdd.HHMM00'), '.gz ', product_folder, 'PRECIPRATE.EVAP.', datestr(t, 'yyyymmdd_HHMM'), '.tif']);

	    precip = imread([product_folder, 'PRECIPRATE.EVAP.', datestr(t, 'yyyymmdd_HHMM'), '.tif']); 
	    precip(precip<0) = 0;

	    %Round off
            precip = round(precip.*((2/60)*100))./100; %From mm/hr to mm

	    %Delete temporary file
            system(['rm ', product_folder, 'PRECIPRATE.EVAP.', datestr(t, 'yyyymmdd_HHMM'), '.tif']);
	catch MEint
	    %File is missing, assuming zeros
	    fprintf('Missing Precip File %s. Assuming zeros ...\n', [product_folder, 'PRECIPRATE.EVAP.', datestr(t, 'yyyymmdd_HHMM'), '.tif']);
	    precip = zeros([mapinfo1km.Height mapinfo1km.Width], 'single');
	end

	accumXh = round((accumXh + precip).*100)./100;
	accum_cont = accum_cont + 1;

	c_file = accumXh;

	%Update accumulation
	past_t = (t+tstep) - (X/24);
	fprintf('Removing values from %s\n', [product_folder, 'PRECIPRATE.EVAP.', datestr(past_t, 'yyyymmdd_HHMM'), '.tif']);
        try
            system([convertMRMS, ' ', root_product_folder, 'PRECIPRATE.EVAP.', datestr(past_t, 'yyyymmdd.HHMM00'), '.gz ', product_folder, 'PRECIPRATE.EVAP.', datestr(past_t, 'yyyymmdd_HHMM'), '.tif']);

            FirstPrecipXh = imread([product_folder, 'PRECIPRATE.EVAP.', datestr(past_t, 'yyyymmdd_HHMM'), '.tif']);
            FirstPrecipXh(FirstPrecipXh<0) = 0;

	    %Round off
            FirstPrecipXh = round(FirstPrecipXh.*((2/60)*100))./100; %From mm/hr to mm

	    %Delete temporary file
            system(['rm ', product_folder, 'PRECIPRATE.EVAP.', datestr(past_t, 'yyyymmdd_HHMM'), '.tif']);
        catch MEint2
	    fprintf('Missing First Precip File %s. Assuming zeros\n', [product_folder, 'PRECIPRATE.EVAP.', datestr(past_t, 'yyyymmdd_HHMM'), '.tif']);
            FirstPrecipXh = zeros([mapinfo1km.Height mapinfo1km.Width], 'single');
        end

	accumXh = round((accumXh - FirstPrecipXh).*100)./100;
	accum_cont = accum_cont - 1;
	%n_bad = numel(accumXh(accumXh<0));
	%min_bad = min(accumXh(accumXh<0));

	%fprintf('N of bad data is %.f and min val is %f\n', n_bad, min_bad);
    catch ME %If reading file fails, then...
	fprintf('Should I have entered here?\n')
	%If total number of products make a full day
	if (counters == n_steps)
		day_counter = day_counter + 1;

		%Loop through all threshold values
        	for prod_th_i = 1:numel(all_prod_th)
			all_thresholds_events{prod_th_i} = unique(all_thresholds_events{prod_th_i});

                	all_reports = zeros([pixels_nrows pixels_ncols]);
                	all_reports(all_reports_events{day_counter}) = 1;

                	all_predictions = zeros([pixels_nrows pixels_ncols]);
                	all_predictions(all_thresholds_events{prod_th_i}) = 1;

			%Compute overall CONUS-wide contingency stats
                	%Look at numbers for this day
                	this_hits = numel(find(all_reports == 1 & all_predictions == 1));
                	this_misses = numel(find(all_reports == 1 & all_predictions == 0));
                	this_false_alarms = numel(find(all_reports == 0 & all_predictions == 1));

			%Accumulate for this period
                	all_hits{prod_th_i} = all_hits{prod_th_i} + this_hits;
                	all_misses{prod_th_i} = all_misses{prod_th_i} + this_misses;
                	all_false_alarms{prod_th_i} = all_false_alarms{prod_th_i} + this_false_alarms;
                	all_correct_negatives{prod_th_i} = all_correct_negatives{prod_th_i} + (total_pixels - (this_hits+this_misses+this_false_alarms));

			%Compute contingency stats per region
                	for reg_i = 1:n_regions
                        	%Look at numbers for this day and this region
                        	this_hits = numel(find(all_reports == 1 & all_predictions == 1 & regions_grid == region_ids(reg_i)));
                        	this_misses = numel(find(all_reports == 1 & all_predictions == 0 & regions_grid == region_ids(reg_i)));
                        	this_false_alarms = numel(find(all_reports == 0 & all_predictions == 1 & regions_grid == region_ids(reg_i)));
                        	this_correct_negatives = region_total_pixels(reg_i) - (this_hits+this_misses+this_false_alarms);

                        	%Accumulate for this period and region
                        	hits_map(prod_th_i,reg_i) = hits_map(prod_th_i,reg_i) + this_hits;
                        	misses_map(prod_th_i,reg_i) = misses_map(prod_th_i,reg_i) + this_misses;
                        	false_alarms_map(prod_th_i,reg_i) = false_alarms_map(prod_th_i,reg_i) + this_false_alarms;
                        	correct_negatives_map = correct_negatives_map + this_correct_negatives;
                	end
                	%END Compute contingency stats per region

                	%Reset pixel array
                	all_thresholds_events{prod_th_i} = [];
		end
                %END Loop through all threshold values
     	
		clear all_reports all_predictions this_hits this_misses this_false_alarms;

		%Reset counter
		counters = 0;

		%Save every 24-hr worth of data
        	save(['HS2018_Regional_Seasonal_Analysis/Partial_MultiThreshold_Run', outFile_product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'all_hits', 'all_misses', 'all_false_alarms', 'all_correct_negatives', 'hits_map', 'false_alarms_map', 'misses_map', 'correct_negatives_map', 'day_counter', '-v7.3');

	end
	%END If total number of products make a full day

	%Go to next product time step 
   	continue;
    end
    %END Try reading in new file

    fprintf('Working on %s\n', [product_folder, product, datestr(t, 'yyyymmdd.HHMM'), '00.tif']);

    %For each threshold value, find exceedances
    for prod_th_i = 1:numel(all_prod_th)
	prod_th = all_prod_th(prod_th_i);

	%Binarize image
	BW = c_file > prod_th;

	%Find pixels where exceedance occurs
	[pix_rows,pix_cols] = find(BW > 0);

	%Convert to lat/lon
	[pix_lat, pix_lon] = pix2latlon(mapinfo1km.RefMatrix,pix_rows,pix_cols);

	%Find corresponding pixel on coarser grids
	%50-km
        [pix_rows,pix_cols] = latlon2pix(mapinfo50km.RefMatrix,pix_lat, pix_lon);
        pixels50km = sub2ind([nrows50 ncols50],round(pix_rows),round(pix_cols));

	%Save exceedances 
	%Add pixels and reduce at larger pixel scales
        all_thresholds_events{prod_th_i} = [all_thresholds_events{prod_th_i}; unique(pixels50km)];
    end
    %END For each threshold value, find exceedances

    %If total number of products make a full day
    if (counters == n_steps)
	day_counter = day_counter + 1;

	%Loop through all threshold values
    	for prod_th_i = 1:numel(all_prod_th)		
		all_thresholds_events{prod_th_i} = unique(all_thresholds_events{prod_th_i});

		all_reports = zeros([pixels_nrows pixels_ncols]);
		all_reports(all_reports_events{day_counter}) = 1;

                all_predictions = zeros([pixels_nrows pixels_ncols]);
		all_predictions(all_thresholds_events{prod_th_i}) = 1;

		%Compute overall CONUS-wide contingency stats
		%Look at numbers for this day
		this_hits = numel(find(all_reports == 1 & all_predictions == 1));
		this_misses = numel(find(all_reports == 1 & all_predictions == 0));
		this_false_alarms = numel(find(all_reports == 0 & all_predictions == 1));

		%Accumulate for this period
		all_hits{prod_th_i} = all_hits{prod_th_i} + this_hits;
		all_misses{prod_th_i} = all_misses{prod_th_i} + this_misses;
		all_false_alarms{prod_th_i} = all_false_alarms{prod_th_i} + this_false_alarms;
		all_correct_negatives{prod_th_i} = all_correct_negatives{prod_th_i} + (total_pixels - (this_hits+this_misses+this_false_alarms)); 

		%Compute contingency stats per region
		for reg_i = 1:n_regions
			%Look at numbers for this day and this region
			this_hits = numel(find(all_reports == 1 & all_predictions == 1 & regions_grid == region_ids(reg_i)));
			this_misses = numel(find(all_reports == 1 & all_predictions == 0 & regions_grid == region_ids(reg_i)));
			this_false_alarms = numel(find(all_reports == 0 & all_predictions == 1 & regions_grid == region_ids(reg_i)));
			this_correct_negatives = region_total_pixels(reg_i) - (this_hits+this_misses+this_false_alarms);

			%Accumulate for this period and region
			hits_map(prod_th_i,reg_i) = hits_map(prod_th_i,reg_i) + this_hits;
			misses_map(prod_th_i,reg_i) = misses_map(prod_th_i,reg_i) + this_misses;
			false_alarms_map(prod_th_i,reg_i) = false_alarms_map(prod_th_i,reg_i) + this_false_alarms;
			correct_negatives_map = correct_negatives_map + this_correct_negatives;
		end
		%END Compute contingency stats per region

		%Reset pixel array
                all_thresholds_events{prod_th_i} = [];
	end
	%END Loop through all threshold values
			
	clear all_reports all_predictions this_hits this_misses this_false_alarms;

	%Reset counter
        counters = 0;

	%Save every 24-hr worth of data
	save(['HS2018_Regional_Seasonal_Analysis/Partial_MultiThreshold_Run', outFile_product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'all_hits', 'all_misses', 'all_false_alarms', 'all_correct_negatives', 'hits_map', 'false_alarms_map', 'misses_map', 'correct_negatives_map', 'day_counter', '-v7.3');

    end
    %END If total number of products make a full day

end
%END Loop through main period of data

%Save once the run is complete
save(['HS2018_Regional_Seasonal_Analysis/CT_stats_MultiThreshold_Run', outFile_product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'all_hits', 'all_misses', 'all_false_alarms', 'all_correct_negatives', 'hits_map', 'false_alarms_map', 'misses_map', 'correct_negatives_map', 'day_counter', '-v7.3');

%Delete temporary folder
rmdir(product_folder, 's');

exit;
