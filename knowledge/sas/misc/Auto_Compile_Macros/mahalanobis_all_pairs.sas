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

/* 3.) Compute distance between all possible pairs. 
		Depending on the number of observations this might produce a huge output file
		and consume extrem computation time. */
%macro mahalanobis_all_pairs(input_ds=,id=,output_ds=);

	ods graphics on;
	ods output Eigenvalues=Eigenvalues;
	ods exclude Corr Eigenvectors;
	proc hpprincomp data=&input_ds. std out=princomps_by_obs(keep=&id. prin:) outstat=princomp_outstat;
		id &id.;
	run;

	title 'Eigenvalues of Principle Component Decomposition'; 
	proc sgplot data=Eigenvalues;
		series x=Number y=Eigenvalue /  markers;
		series x=Number y=Proportion /  y2axis markers;
		xaxis label='Number of Eigenvalue';
		yaxis label='Value of Eigenvalue';
		y2axis label='Proportion of Variance Explained';

	proc distance data=princomps_by_obs out=princomps_by_obs_distances method=euclid;
		var interval(_numeric_);
		id &id.;
	run;

	proc sort data=princomps_by_obs_distances; by &id.; run;
	proc transpose data=princomps_by_obs_distances out=&output_ds.(rename=(_NAME_=&id.2 COL1=mahalanobis_dist)
		where=((&id. ne &id.2) and (mahalanobis_dist ne .)));
		by &id.;
		var _numeric_;
	run;

	data &output_ds.;
		set &output_ds.;
		id_pair = catx(':', &id., &id.2);
	run;

	title 'Distribution of all pairwise Mahalanobis distances'; 
	proc sgplot data=&output_ds.;
	  	histogram mahalanobis_dist;
  		density mahalanobis_dist;
  		density mahalanobis_dist / type=kernel;
	run;
	
	title 'Boxplot of all pairwise Mahalanobis distances with marked outliers'; 
	proc sgplot data=&output_ds.;
  		vbox mahalanobis_dist / notches datalabel=id_pair;
	run;	

	title;
	ods graphics off;
%mend;

/*%mahalanobis_all_pairs(input_ds=mydata.baseball,id=Name,output_ds=tmp1);*/