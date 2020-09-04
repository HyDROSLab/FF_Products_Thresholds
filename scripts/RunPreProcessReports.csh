#!/bin/csh

foreach week (`seq 2 1 54`)
	set startdate=`sed -n "$week"p Selected_Days.csv | cut -d"," -f1`
	set enddate=`sed -n "$week"p Selected_Days.csv | cut -d"," -f2`

	sed -e s/'{STARTDATE}'/"$startdate"/g -e s/'{ENDDATE}'/"$enddate"/g < template_preProcess_reportsv2.m > week"$week"_preProcess_reports.m

	matlab -nodisplay -r week"$week"_preProcess_reports
end
