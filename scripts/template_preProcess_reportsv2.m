%Geoinfo for CONUS grid
mapinfo1km = geotiffinfo('../auxiliary/flash_conus_mask1km.tif');
regions_grid = imread('../auxiliary/corrected_conus_regions_mask50km.tif');

fid = fopen('../source_data/events_A4875356EB81004A1C6C9C960CF48888.csv', 'r');
reports = textscan(fid, '%q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q', 'Delimiter', ',', 'HeaderLines', 1);
fclose(fid);

%Index of fields with lat/lons in the file
lat_idxs = 28:3:49;
lon_idxs = 29:3:50;

%Time Zone field
tz_idx = 11;

%Reports are in local time, need to convert to UTC
%reports{6} - Time Zone
reports_date_i = datenum(reports{5}, 'mm/dd/yyyy HH:MM:SS');
reports_date_f = datenum(reports{6}, 'mm/dd/yyyy HH:MM:SS');

%Convert local time to UTC
%Time zones in Continental United States
time_zones = {'PST' -8; 'PDT' -7; 'MST' -7; 'MDT' -6; 'CST' -6; 'CDT' -5; 'EST' -5; 'EDT' -4};
timeZtable = cell2table(time_zones, 'VariableNames', {'ZONE', 'UTCoffset'});
for tz = 1:8
	reports_date_i(strcmp(reports{tz_idx}, timeZtable.ZONE{tz})==1) = reports_date_i(strcmp(reports{tz_idx}, timeZtable.ZONE{tz})==1) - timeZtable.UTCoffset(tz)/24;
	reports_date_f(strcmp(reports{tz_idx}, timeZtable.ZONE{tz})==1) = reports_date_f(strcmp(reports{tz_idx}, timeZtable.ZONE{tz})==1) - timeZtable.UTCoffset(tz)/24;
end

mapinfo50km = geotiffinfo('../auxiliary/flash_conus_mask50km.tif');
nrows50 = mapinfo50km.Height;
ncols50 = mapinfo50km.Width;

%Period configuration
tstep = 1/24;
start_date = '{STARTDATE}';
end_date = '{ENDDATE}';

%20170514.1200,20170521.1200
period = datenum(start_date, 'yyyymmdd.HHMM'):tstep:datenum(end_date, 'yyyymmdd.HHMM');
period_24h = period(1):1:period(end);

%Initialization of output variable
time_agg = 24;
n_steps = numel(period(1):time_agg/24:period(end));                
all_reports_events = cell(n_steps,1);
poly_all_reports_events = cell(n_steps,1);
                
for t_i = 1:n_steps                       
	all_reports_events{t_i} = [];
	poly_all_reports_events{t_i} = [];
end

%Loop through period of study
n_steps24h = round(1/tstep); elem_24h = 1;

for t = period_24h
	%Reports within 1-day time frame
        sel_reports = find(reports_date_i >= t & reports_date_i < t+1);
	if (isempty(sel_reports) == 1)
		pixels50km = [];
		poly_pixels50km = [];
	else
		%Compute both centroids and whole polygon
		all_rep_lat = zeros(1,numel(sel_reports));
		all_rep_lon = zeros(1,numel(sel_reports));
	
		%Keep report polygons
		poly_rep_lat = [];
		poly_rep_lon = [];
		for rep_i = 1:numel(sel_reports)
			this_rep_lats = [];
			this_rep_lons = [];
			for coord_i = 1:8
				this_rep_lats = [this_rep_lats; str2double(reports{lat_idxs(coord_i)}(sel_reports(rep_i)))]; 
				this_rep_lons = [this_rep_lons; str2double(reports{lon_idxs(coord_i)}(sel_reports(rep_i)))];
			end

			this_coord_idx = find(isnan(this_rep_lats) == 0 & isnan(this_rep_lons) == 0);
			this_rep_lats = this_rep_lats(this_coord_idx);
			this_rep_lons = this_rep_lons(this_coord_idx);

			%Compute centroid
	        	all_rep_lat(rep_i) = mean(this_rep_lats); 
        		all_rep_lon(rep_i) = mean(this_rep_lons);

			%Get this report's polygon
			[row,col] = latlon2pix(mapinfo1km.RefMatrix, this_rep_lats, this_rep_lons);
			row = round(row); col = round(col);
			
			%Create a mask with the polygon coordinates making sure it closes with the first coordinate
			curr_mask = poly2mask([col; col(1)],[row; row(1)], mapinfo1km.Height,mapinfo1km.Width);
			[row,col] = find(curr_mask == 1);
			[this_rep_lats, this_rep_lons] = pix2latlon(mapinfo1km.RefMatrix, row,col);

			poly_rep_lat = [poly_rep_lat; this_rep_lats];
			poly_rep_lon = [poly_rep_lon; this_rep_lons]; 
		end

		%Convert to lat/lon
        	%50-km
        	[pix_rows,pix_cols] = latlon2pix(mapinfo50km.RefMatrix,all_rep_lat,all_rep_lon);
		pix_rows = round(pix_rows);
        	pix_cols = round(pix_cols);
		in_pix = find(pix_rows >= 1 & pix_rows <= nrows50 & pix_cols >= 1 & pix_cols <= ncols50);
        	pix_rows = pix_rows(in_pix);
        	pix_cols = pix_cols(in_pix);
        	pixels50km = sub2ind([nrows50 ncols50],pix_rows,pix_cols);

		%polygon
		[pix_rows,pix_cols] = latlon2pix(mapinfo50km.RefMatrix,poly_rep_lat,poly_rep_lon);
                pix_rows = round(pix_rows);
                pix_cols = round(pix_cols);
                in_pix = find(pix_rows >= 1 & pix_rows <= nrows50 & pix_cols >= 1 & pix_cols <= ncols50);
                pix_rows = pix_rows(in_pix);
                pix_cols = pix_cols(in_pix);
                poly_pixels50km = sub2ind([nrows50 ncols50],pix_rows,pix_cols);
	end

	%Save exceedances at different time aggregations
	%24-hour
        all_reports_events{elem_24h} = unique(pixels50km);
	poly_all_reports_events{elem_24h} = unique(poly_pixels50km);

        elem_24h = elem_24h + 1;
end

%Save once the run is complete
save(['../outputs/general/reports/Reports_MultiThreshold_', datestr(period(1), 'yyyymmddHHMM'), '-', datestr(period(end), 'yyyymmddHHMM'), '.mat'], 'all_reports_events', 'poly_all_reports_events');

exit;
