/* Sample Script to start LASR and load data*/
libname lasr1 sasiola startserver=(path="c:\temp" keeplog=yes maxlogsize=20) 
tag='hps'
host="gersta-2"
port=10010
SIGNER="http://gersta-2:80/SASLASRAuthorization" 
;


/* Load data to lasr */
data lasr1.ecb_networks;  set mydata.ecb_networks;  run;

/* Register in Metadata */
proc metalib;
	omr ( library="Visual Analytics LASR" server="gersta-2" port="8561" );
	folder = "/User Folders/sasdemo/My Folder";
	select = ("ECB_NETWORKS");
	report(matching);
run;
/* get status */

proc imstat;
	serverinfo / port=10010 host="gersta-2";
	tableinfo  / port=10010 host="gersta-2";
run; quit;




/* Stop LASR and delete table */

proc delete data=lasr1.ecb_networks; run;

libname lasr1 clear;