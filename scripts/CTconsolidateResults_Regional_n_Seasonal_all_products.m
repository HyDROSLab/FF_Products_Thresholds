product_name = [{'maxunitq.'}, {'30U.ARI.'}, {'01H.ARI.'}, {'03H.ARI.'}, {'06H.ARI.'}, {'12H.ARI.'}, {'24H.ARI.'}, {'MAX.ARI.'}, {'01H.RAT.'}, {'03H.RAT.'}, {'06H.RAT.'}, {'MAX.RAT.'}, {'maxunitq.'}, {'maxunitq.'}, {'01H.ACC.'}, {'03H.ACC.'}, {'06H.ACC.'}, {'24H.ACC.'}];

all_product_folder = [{'maxunitq/'}, {'preciprp_30m/'}, {'preciprp_1h/'}, {'preciprp_3h/'}, {'preciprp_6h/'}, {'preciprp_12h/'}, {'preciprp_24h/'}, {'preciprp_max/'}, {'ratio_1h/'}, {'ratio_3h/'}, {'ratio_6h/'}, {'ratio_max/'}, {'maxunitq_sac/'},{'maxunitq_hp/'}, {'01HACC/'}, {'03HACC/'}, {'06HACC/'}, {'24HACC/'}];

fid = fopen('Selected_Days.csv', 'r');
selected_dates = textscan(fid, '%s %s', 'Delimiter', ',', 'HeaderLines', 1);
fclose(fid);

%Initialization of output variable
mask = imread('../auxiliary/flash_conus_mask50km.tif');
regions_grid = imread('../auxiliary/corrected_conus_regions_mask50km.tif');
region_name = [{'MidWest'}, {'Pacific'}, {'Rockies'}, {'SouthGreatPlains'}, {'NorthEast'}, {'NorthGreatPlains'},{'SouthWest'},{'SouthEast'},{'All'}];

mapinfo50km = geotiffinfo('../auxiliary/flash_conus_mask50km.tif'); 

nrows50 = mapinfo50km.Height;
ncols50 = mapinfo50km.Width;

pixel_sizes = 50;
pixels_nrows = nrows50;
pixels_ncols = ncols50;
region_ids = unique(regions_grid(regions_grid>0));
n_regions = numel(region_ids);
%region_total_pixels = zeros(1,n_regions);

%Period configuration
dates_i = selected_dates{1}(1:53);
dates_f = selected_dates{2}(1:53);

%Season codes
season_name = [{'JJA'}, {'SON'}, {'DJF'}, {'MAM'}, {'All'}];
season_id = 1:4;
season_start_date = datenum([{'20180531.1200'},{'20180830.1200'},{'20181129.1200'},{'20190228.1200'}], 'yyyymmdd.HHMM');
%season_start_date = [{'20180531.1200'},{'20180830.1200'},{'20181129.1200'},{'20190228.1200'}];
%JJA,SON,DJF,MAM - Used to count reports per season and regions in plotStormDataReports.m 
%seasons = [datenum('31-May-2018 12:00'), datenum('31-Aug-2018 12:00'); datenum('31-Aug-2018 12:00'), datenum('30-Nov-2018 12:00'); datenum('30-Nov-2018 12:00'), datenum('28-Feb-2019 12:00'); datenum('28-Feb-2019 12:00'), datenum('31-May-2019 12:00')];

%Main loop through each product
for prod_i = 1:18

product = product_name{prod_i};
product_folder = all_product_folder{prod_i};

all_prod_ths = [1,1.5,2,2.5,5,7.5,10,15,25,30,40,50,75,100];
rat_all_prod_ths = [25,50,75,100,150,200,250,300,350,400,450,500,600,700];
q_prod_ths = 0.5:0.5:12;

if (prod_i == 1 || prod_i == 13 || prod_i == 14)
        all_prod_th = q_prod_ths;
end

if (prod_i > 1 && prod_i < 9)
        all_prod_th = all_prod_ths;
end

if (prod_i > 8 && prod_i < 13)
        all_prod_th = rat_all_prod_ths;
end

if (prod_i > 14)
	clear all_prod_ths;
	% Thresholds in inches as H&S2018
	all_prod_ths(1,:) = [1, 1.5, 2, 2.5, 3, 3.5 , 4];
	all_prod_ths(2,:) = [1.5, 2, 2.5, 3, 3.5, 4, 5];
	all_prod_ths(3,:) = [1.5, 2, 2.5, 3, 3.5, 4, 5];
	all_prod_ths(4,:) = [2, 2.5, 3, 3.5, 4, 5, 6];

	all_prod_th = all_prod_ths(prod_i-14,:).*25.4; %Convert to mm
end

if (prod_i == 13)
        product = ['sac_', product];
end

if (prod_i == 14)
        product = ['hp_', product];
end

%From processing
%cont_th = 0;
%for prod_th = 1:numel(all_prod_th)
%        cont_th = cont_th + 1;
%        all_thresholds_events{cont_th} = [];
%        all_hits{cont_th} = 0;
%        all_misses{cont_th} = 0;
%        all_false_alarms{cont_th} = 0;
%        all_correct_negatives{cont_th} = 0;
%end
%
%Arrays for region-based contingency counts
%hits_map = zeros(numel(all_prod_th),n_regions);
%misses_map = zeros(numel(all_prod_th),n_regions);
%false_alarms_map = zeros(numel(all_prod_th),n_regions);
%correct_negatives_map = zeros(numel(all_prod_th),n_regions);
%From processing

cont_th = 0;
for prod_th = 1:numel(all_prod_th)
    cont_th = cont_th + 1;
    %Add additional element to season and region to count all seasons/regions combined
    for reg = 1:n_regions+1
        for seas = 1:5 
            master_hits{cont_th}{reg}{seas} = 0;
            master_misses{cont_th}{reg}{seas} = 0;
            master_false_alarms{cont_th}{reg}{seas} = 0;
            master_correct_negatives{cont_th}{reg}{seas} = 0;
        end
    end
end

fid = fopen(['../outputs/general/hs18_regional_and_seasonal_All_weeks_contingency_stats_', product, 'csv'], 'w');
fprintf(fid, 'Region Name,Region N,Season Name,Season N,TH,hits,misses,false alarms,correct negatives,POD,FAR,CSI,ETS\n');

%Loop through weekly files
for per_i = 1:numel(dates_i)
    start_date = dates_i{per_i};
    end_date = dates_f{per_i};

    curr_seas_idx = find(season_start_date-datenum(start_date, 'yyyymmdd.HHMM') > 0, 1, 'first')-1;
    if (isempty(curr_seas_idx) == 1)
	fprintf('Assuming last season. Dates is %s\n', start_date);
	curr_seas_idx = 4;
    end
    seas = season_id(curr_seas_idx);

    period = datenum(start_date, 'yyyymmdd.HHMM'):datenum(end_date, 'yyyymmdd.HHMM');
    load(['../outputs/general/', product_folder, 'CT_stats_MultiThreshold_Run', product, '_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat']);

    for reg = 1:n_regions
	for th = 1:numel(all_prod_th)
	    %Each region, each season
	    master_hits{th}{reg}{seas} = master_hits{th}{reg}{seas} + hits_map(th,reg);
            master_misses{th}{reg}{seas} = master_misses{th}{reg}{seas} + misses_map(th,reg);
            master_false_alarms{th}{reg}{seas} = master_false_alarms{th}{reg}{seas} + false_alarms_map(th,reg);
            master_correct_negatives{th}{reg}{seas} = master_correct_negatives{th}{reg}{seas} + correct_negatives_map(th,reg); 

	    %Each region, all seasons
	    master_hits{th}{reg}{numel(season_id) + 1} = master_hits{th}{reg}{numel(season_id) + 1} + hits_map(th,reg);
	    master_misses{th}{reg}{numel(season_id) + 1} = master_misses{th}{reg}{numel(season_id) + 1} + misses_map(th,reg);
	    master_false_alarms{th}{reg}{numel(season_id) + 1} = master_false_alarms{th}{reg}{numel(season_id) + 1} + false_alarms_map(th,reg);
	    master_correct_negatives{th}{reg}{numel(season_id) + 1} = master_correct_negatives{th}{reg}{numel(season_id) + 1} + correct_negatives_map(th,reg);
	end
    end

    %All regions/seasons combined
    reg = n_regions + 1;
    for th = 1:numel(all_prod_th)
	master_hits{th}{n_regions + 1}{seas} = master_hits{th}{n_regions + 1}{seas} + all_hits{th};	
	master_hits{th}{n_regions + 1}{numel(season_id) + 1} = master_hits{th}{n_regions + 1}{numel(season_id) + 1} + all_hits{th};

        master_misses{th}{n_regions + 1}{seas} = master_misses{th}{n_regions + 1}{seas} + all_misses{th};
	master_misses{th}{n_regions + 1}{numel(season_id) + 1} = master_misses{th}{n_regions + 1}{numel(season_id) + 1} + all_misses{th};

        master_false_alarms{th}{n_regions + 1}{seas} = master_false_alarms{th}{n_regions + 1}{seas} + all_false_alarms{th};
	master_false_alarms{th}{n_regions + 1}{numel(season_id) + 1} = master_false_alarms{th}{n_regions + 1}{numel(season_id) + 1} + all_false_alarms{th};

        master_correct_negatives{th}{n_regions + 1}{seas} = master_correct_negatives{th}{n_regions + 1}{seas} + all_correct_negatives{th};
	master_correct_negatives{th}{n_regions + 1}{numel(season_id) + 1} = master_correct_negatives{th}{n_regions + 1}{numel(season_id) + 1} + all_correct_negatives{th};
    end
end
%End loop through weekly files

%Loop to write to output file
for reg = 1:(n_regions + 1)
    for seas = 1:5
	for th = 1:numel(all_prod_th)
    	    total_hits = master_hits{th}{reg}{seas};	    
            total_misses = master_misses{th}{reg}{seas};
    	    total_false_alarms = master_false_alarms{th}{reg}{seas};
    	    total_correct_negatives = master_correct_negatives{th}{reg}{seas};

    	    POD = total_hits/(total_hits + total_misses);
    	    FAR = total_false_alarms/(total_hits + total_false_alarms);
    	    CSI = total_hits/(total_hits + total_misses + total_false_alarms);
    	    hits_rand = (total_hits+total_misses)*(total_hits + total_false_alarms)/(total_hits + total_misses + total_false_alarms + total_correct_negatives);
    	    ETS = (total_hits-hits_rand)/(total_hits + total_misses + total_false_alarms - hits_rand);
            
    	    fprintf(fid, '%s,%.f,%s,%.f,%f,%.f,%.f,%.f,%.f,%f,%f,%f,%f\n', region_name{reg},reg,season_name{seas},seas,all_prod_th(th),total_hits,total_misses,total_false_alarms,total_correct_negatives,POD,FAR,CSI,ETS);
	end
    end
end
%End of Loop to write to output file
fclose(fid);

end
%End of Main loop through each product
exit;
