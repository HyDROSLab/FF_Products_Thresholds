product_name = [{'maxunitq.'}, {'30U.ARI.'}, {'01H.ARI.'}, {'03H.ARI.'}, {'06H.ARI.'}, {'12H.ARI.'}, {'24H.ARI.'}, {'MAX.ARI.'}, {'01H.RAT.'}, {'03H.RAT.'}, {'06H.RAT.'}, {'MAX.RAT.'}, {'maxunitq.'}, {'maxunitq.'}];
all_product_folder = [{'maxunitq/'}, {'preciprp_30m/'}, {'preciprp_1h/'}, {'preciprp_3h/'}, {'preciprp_6h/'}, {'preciprp_12h/'}, {'preciprp_24h/'}, {'preciprp_max/'}, {'ratio_1h/'}, {'ratio_3h/'}, {'ratio_6h/'}, {'ratio_max/'}, {'maxunitq_sac/'},{'maxunitq_hp/'}];
product_res = [1/(24*6), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*30), 1/(24*6), 1/(24*6)];

prod_i = 4;

all_prod_ths = 1; 

if (prod_i > 1 && prod_i < 9)
	all_prod_th = all_prod_ths;
end

root_product_folder = '../source_data/'; 
product = product_name{prod_i};
outFile_product = product;

product_folder = all_product_folder{prod_i};

mapinfo50km = geotiffinfo('../auxiliary/flash_conus_mask50km.tif');
mapinfo1km = geotiffinfo('../auxiliary/flash_conus_mask1km.tif');

mask = imread('../auxiliary/flash_conus_mask50km.tif');

total_pixels = numel(mask(mask==1));
%clear mask;

nrows50 = mapinfo50km.Height;
ncols50 = mapinfo50km.Width;

%Period configuration
tstep = product_res(prod_i);
start_date = '20180531.1200';
end_date = '20190601.1200';

%20170514.1200,20170521.1200
period = datenum(start_date, 'yyyymmdd.HHMM'):tstep:datenum(end_date, 'yyyymmdd.HHMM');
period_24h = period(1):1:period(end);

%---Initialize Variables---
pixel_sizes = 50;
pixels_nrows = nrows50;
pixels_ncols = ncols50;

exceedances_map = zeros([pixels_nrows, pixels_ncols]);
all_excd_pixels = [];

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
        	exceedances_map(unique(all_excd_pixels)) = exceedances_map(unique(all_excd_pixels)) + 1;
        	%END Loop through all threshold values

		%Reset pixel array
        	all_excd_pixels = [];
     	
		%Reset counter
		counters = 0;

		%Save every 24-hr worth of data
        	save(['../outputs/general/Partial_ExcdHeatMap', outFile_product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'exceedances_map', 'day_counter', '-v7.3');

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
        all_excd_pixels = [all_excd_pixels; unique(pixels50km)];
    end
    %END For each threshold value, find exceedances

    %If total number of products make a full day
    if (counters == n_steps)
	day_counter = day_counter + 1;

	%Loop through all threshold values
	exceedances_map(unique(all_excd_pixels)) = exceedances_map(unique(all_excd_pixels)) + 1;
	%END Loop through all threshold values

	%Reset pixel array
	all_excd_pixels = [];

	%Reset counter
        counters = 0;

	%Save every 24-hr worth of data
	save(['../outputs/general/Partial_ExcdHeatMap', outFile_product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'exceedances_map', 'day_counter', '-v7.3'); 

    end
    %END If total number of products make a full day

end
%END Loop through main period of data

%Save once the run is complete
save(['../outputs/general/Complete_ExcdHeatMap', outFile_product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'exceedances_map', 'day_counter', '-v7.3'); 

exit;
