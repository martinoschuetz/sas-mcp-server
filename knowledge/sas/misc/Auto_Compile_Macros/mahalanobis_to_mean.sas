/*libname mydata "C:\Program Files\SASHome\SASFoundation\9.4\core\sashelp";*/

/*	
	http://support.sas.com/kb/30/662.html 	
	Compute Mahalanobis distance based on input table for the following scenarios: 
	1) 	To compute the Mahalanobis distance from each observation to the mean,
		first run PROC PRINCOMP with the STD option to produce principal component scores
		in the OUT= data set having an identity covariance matrix.
		The Mahalanobis distance and Euclidean distances are equivalent for these scores.
		Then use a DATA step with a statement such as: 
			mahalanobis_distance_to_mean = sqrt(uss(of prin:));
		to complete the required distance. 
	2) 	To compute the Mahalanobis distance from each observation to a specific point,
		compute the principal component score for that point using the original scoring coefficients.
		Then compute the Euclidean distance from each observation to the reference point.
		One easy way to do this is to use PROC FASTCLUS treating the reference point as the SEED. 
	3) 	To compute Mahalanobis distances between all possible pairs, run PROC DISTANCE on the OUT= data set
		as created by PRINCOMP in the steps above. PROC DISTANCE will automatically calculate all possible pairs. 
*/
/* 1.) Compute Distance to mean */
%macro mahalanobis_to_mean(input_ds=,id=,output_ds=);

	ods graphics on;
	ods output Eigenvalues=Eigenvalues;
	ods exclude Corr Eigenvectors;
	proc hpprincomp data=&input_ds. std out=princomps_by_obs(keep=&id. prin:) outstat=princomp_outstat;
		id &id.;
	run;

	title 'Eigenvalues of Principle Component Decomposition'; 
	proc sgplot data=Eigenvalues;
		series x=Number y=Eigenvalue /  markers;
		series x=Number y=Cumulative /  y2axis markers;
		xaxis label='Number of Eigenvalue';
		yaxis label='Value of Eigenvalue';
		y2axis label='Proportion of Variance Explained';

	data &output_ds.(keep=&id. mahalanobis_mean);
		attrib mahalanobis_mean label="Mahalanobis distance to mean";
		set princomps_by_obs;
		mahalanobis_mean = sqrt(uss(of prin:));
	run;

	title 'Distribution of Mahalanobis distance to the mean'; 
	proc sgplot data=&output_ds.;
	  	histogram mahalanobis_mean;
  		density mahalanobis_mean;
  		density mahalanobis_mean / type=kernel;
	run;

	title 'Boxplot of Mahalanobis distances to the mean with marked outliers'; 
	proc sgplot data=&output_ds.;
  		vbox mahalanobis_mean / notches datalabel=&id.;
	run;	

	title;
	ods graphics off;
%mend;

/*%mahalanobis_to_mean(input_ds=mydata.baseball,id=Name,output_ds=tmp);*/