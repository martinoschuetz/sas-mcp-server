/* Demo data from Gerhard
For demo situations, I often use PROC SIMNORMAL form SAS/STAT to create my individual demo data.
1.	Either design your COV-matrix yourself or just run PROC CORR on an existing dataset.
*/
proc corr data=sampsio.hmeq out=hmeq_cov cov noprint nocorr;
	var BAD LOAN MORTDUE VALUE YOJ DEROG DELINQ CLAGE NINQ CLNO DEBTINC;
run;

/*
2.	Run PROC SIMNORMAL and specify the number of observations you want to have.
*/
proc simnormal data=hmeq_cov(type=cov)
	out = hpadata.hmeq_huge
	numreal= 1000000
	seed = 123456;
	var BAD LOAN MORTDUE VALUE YOJ DEROG DELINQ CLAGE NINQ CLNO DEBTINC;
run;

/*
3.	In the case of a binary target variable you may want to re-create the binary values.
Yes, you get some noise into the relationship target to Input, but it still works fine to train your models models.
*/
data hpadata.hmeq_huge;
	set hpadata.hmeq_huge;

	if bad > 0.5 then
		bad=1;
	else bad=0;
run;