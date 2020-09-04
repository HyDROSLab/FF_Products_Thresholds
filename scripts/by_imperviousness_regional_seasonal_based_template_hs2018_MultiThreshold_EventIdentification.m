product_name = [{'maxunitq.'}, {'30U.ARI.'}, {'01H.ARI.'}, {'03H.ARI.'}, {'06H.ARI.'}, {'12H.ARI.'}, {'24H.ARI.'}, {'MAX.ARI.'}, {'01H.RAT.'}, {'03H.RAT.'}, {'06H.RAT.'}, {'MAX.RAT.'}, {'maxunitq.'}, {'maxunitq.'}];
all_product_folder = [{'maxunitq/'}, {'preciprp_30m/'}, {'preciprp_1h/'}, {'preciprp_3h/'}, {'preciprp_6h/'}, {'preciprp_12h/'}, {'preciprp_24h/'}, {'preciprp_max/'}, {'ratio_1h/'}, {'ratio_3h/'}, {'ratio_6h/'}, {'ratio_max/'}, {'maxunitq_sac/'},{'maxunitq_hp/'}];
product_res = [1/(24*6), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*6), 1/(24*6)];

prod_i = {PRODi};

all_prod_ths = [1,1.5,2,2.5,5,7.5,10,15,25,30,40,50,75,100]; 
rat_all_prod_ths = [25,50,75,100,150,200,250,300,350,400,450,500,600,700]; 
q_prod_ths = 0.5:0.5:12; 

if (prod_i == 1 || prod_i > 12)
	all_prod_th = q_prod_ths;
end

if (prod_i > 1 && prod_i < 9)
	all_prod_th = all_prod_ths;
end

if (prod_i > 8 && prod_i < 13)
        all_prod_th = rat_all_prod_ths;
end

root_product_folder = '../source_data/';
product = product_name{prod_i};
outFile_product = product;
if (prod_i == 13)
	outFile_product = ['sac_', product];
end

if (prod_i == 14)
        outFile_product = ['hp_', product];
end

product_folder = all_product_folder{prod_i};

mapinfo50km = geotiffinfo('../auxiliary/flash_conus_mask50km.tif');
mapinfo1km = geotiffinfo('../auxiliary/flash_conus_mask1km.tif');

mask = imread('../auxiliary/flash_conus_mask50km.tif');
regions_grid = imread('../auxiliary/corrected_conus_regions_mask50km.tif');

imperviousness = imread('../auxiliary/max_1km_BasinImperviousness_50km.tif');
class_lo = [0, 6, 50];
class_hi = [6, 50, 101];

class = {CLASS};

total_pixels = numel(imperviousness(imperviousness >= class_lo(class) & imperviousness < class_hi(class)));
%clear mask;

nrows50 = mapinfo50km.Height;
ncols50 = mapinfo50km.Width;

%Period configuration
tstep = product_res(prod_i);
start_date = '{STARTDATE}';
end_date = '{ENDDATE}';

%20170514.1200,20170521.1200
period = datenum(start_date, 'yyyymmdd.HHMM'):tstep:datenum(end_date, 'yyyymmdd.HHMM');
period_24h = period(1):1:period(end);

%load reports - Reports_IM_6-50_MultiThreshold_201806141200-201806211200.mat
load(['../outputs/imperviousness_analysis/reports/Reports_IM_', num2str(class_lo(class)), '-', num2str(class_hi(class)), '_MultiThreshold_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat']); 

%---Initialize Variables---
pixel_sizes = 50;
pixels_nrows = nrows50;
pixels_ncols = ncols50;
region_ids = unique(regions_grid(regions_grid>0));
n_regions = numel(region_ids);
region_total_pixels = zeros(1,n_regions);

for reg_i = 1:n_regions
	region_total_pixels(reg_i) = numel(find(regions_grid == region_ids(reg_i) & imperviousness >= class_lo(class) & imperviousness < class_hi(class)));

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

%Loop through period of study
counters = 0;
n_steps = round(1/tstep);
day_counter = 0;

%Loop through main period of data
for t = period
    %Counter that controls number of steps that make a full day
    counters = counters + 1;

    %Try reading in new file
    try
	c_file = imread([root_product_folder, product_folder, product, datestr(t, 'yyyymmdd.HHMM'), '00.tif']);
	c_file(c_file<0) = 0;
    catch ME %If rading file fails, then...
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
        	save(['../outputs/imperviousness_analysis/', product_folder, 'Partial_IM_', num2str(class_lo(class)), '-', num2str(class_hi(class)), '_MultiThreshold_Run', outFile_product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'all_hits', 'all_misses', 'all_false_alarms', 'all_correct_negatives', 'hits_map', 'false_alarms_map', 'misses_map', 'correct_negatives_map', 'day_counter', '-v7.3');

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

	%Only keep pixels in the same imperviouness class
        pixels50km = pixels50km(imperviousness(pixels50km) >= class_lo(class) & imperviousness(pixels50km) < class_hi(class));

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
	save(['../outputs/imperviousness_analysis/', product_folder, 'Partial_IM_', num2str(class_lo(class)), '-', num2str(class_hi(class)), '_MultiThreshold_Run', outFile_product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'all_hits', 'all_misses', 'all_false_alarms', 'all_correct_negatives', 'hits_map', 'false_alarms_map', 'misses_map', 'correct_negatives_map', 'day_counter', '-v7.3');

    end
    %END If total number of products make a full day

end
%END Loop through main period of data

%Save once the run is complete
save(['../outputs/imperviousness_analysis/', product_folder, 'CT_stats_IM_', num2str(class_lo(class)), '-', num2str(class_hi(class)), '_MultiThreshold_Run', outFile_product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'all_hits', 'all_misses', 'all_false_alarms', 'all_correct_negatives', 'hits_map', 'false_alarms_map', 'misses_map', 'correct_negatives_map', 'day_counter', '-v7.3');

exit;
