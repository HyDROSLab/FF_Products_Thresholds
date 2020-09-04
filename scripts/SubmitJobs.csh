#!/bin/csh

foreach week (`seq 2 1 54`)
	set startdate=`sed -n "$week"p Selected_Days.csv | cut -d"," -f1`
	set enddate=`sed -n "$week"p Selected_Days.csv | cut -d"," -f2`
	foreach prod_i (`seq 1 1 14`)
		sed -e s/'{STARTDATE}'/"$startdate"/g -e s/'{ENDDATE}'/"$enddate"/g -e s/'{PRODi}'/"$prod_i"/g < regional_seasonal_based_template_hs2018_MultiThreshold_EventIdentification.m > prod"$prod_i"_"$week"_hs2018_MultiThreshold_EventIdentification.m 

		sed -e s/'{PRODi}'/"$prod_i"/g -e s/'{WEEK}'/"$week"/g -e s/'{MATLAB_SCRIPT}'/prod"$prod_i"_"$week"_hs2018_MultiThreshold_EventIdentification/g < matlab_nodes_multirun_template.bsub > Job_prod"$prod_i"_"$startdate"-"$enddate".bsub

		bsub < Job_prod"$prod_i"_"$startdate"-"$enddate".bsub
	end
end

