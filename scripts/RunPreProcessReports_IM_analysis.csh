#!/bin/csh

set classes="1 2 3"

foreach week (`seq 2 1 54`)
	set startdate=`sed -n "$week"p Selected_Days.csv | cut -d"," -f1`
	set enddate=`sed -n "$week"p Selected_Days.csv | cut -d"," -f2`

	foreach class ($classes)
        	sed -e s/'{CLASS}'/"$class"/g -e s/'{STARTDATE}'/"$startdate"/g -e s/'{ENDDATE}'/"$enddate"/g < template_preProcess_reports_imAnalysis.m > week"$week"_"$class"_preProcess_reports.m

		sed -e s/'{CLASS}'/"$class"/g -e s/'{WEEK}'/"$week"/g -e s/'{MATLAB_SCRIPT}'/week"$week"_"$class"_preProcess_reports/g < rep_matlab_nodes_multirun_template.bsub > Job_prod_"$class"_"$week".bsub

                bsub < Job_prod_"$class"_"$week".bsub
	end
end
