************************************************************;
* THE OPTIONS STATEMENTS SHOULD ONLY BE EXECUTED ONCE !!! 	;
*															;
* Create a library on Hadoop for HDFS data and metadata.	;
* The Scoring Accelerator will not work with hdat files.  	;
************************************************************;
options set=SAS_HADOOP_JAR_PATH="/aft/sfw/sas/hadoop_cdh/lib";    
options set=SAS_HADOOP_CONFIG_PATH="/aft/sfw/sas/hadoop_cdh/conf";  

************************************************************************;
* THE SCORING ACCELERATOR FOR HADOOP WILL NOT WORK WITH HDAT FILES      ;
************************************************************************;
* If your input data is HDAT or SAS7BDAT you need to create a HDFS      ;
* version of the data for the purpose of scoring.   					;
*																		;
* Create a library on Hadoop for the HDFS data and metadata.  This 		;
* examples uses a libname statement and data step to create the HDFS    ;
* data, you could also use PROC HDMD to accomplish the same thing		;
************************************************************************;
* The file folders must be created BEFORE you run this libname. 		;
* You must have permissions to write to each of the directories below 	;
************************************************************************;
libname hdlib hadoop
		server="cdhn01.aft.sas.com"
	    user=sasdemo
        HDFS_METADIR="/user/sasdemo/metadata"   		
        HDFS_TEMPDIR="/user/sasdemo/tempdir"            
        HDFS_DATADIR="/user/sasdemo/tables"           
		HDFS_PERMDIR="/user/sasdemo/tables"           
		;


libname scorein base '/aft/data/demodata/';		* use this if input data=sas  ;
libname scorein hdat 'hdat directory';	 		* use this if input data=hdat ;

************************************************************************;
* Create a copy of the input data in the HDFS format for scoring		;
************************************************************************;
data hdlib.file_to_be_Scored;
set scorein.file_to_be_scored;
run;

****************************************************************************;
* Provide credentials necessary to connect to the Hadoop HDFS and MapReduce ;							
****************************************************************************;
%let INDCONN=%str(USER=sasdemo);

*****************************************************;
* local directory -- where the score code is located ;
*****************************************************;
%let SCRPATH = /aft/data/demodata/scoring/export;

*******************;
* Publish the model;
*******************;
%indhd_publish_model(
		dir=&SCRPATH,						/* specifies the local directory where the scoring inputs are located.  		*/
											/* This includes the model score code, the XML properties file, the format  	*/
											/* catalog(optional) and the analytic store file (if the model is a random 		*/
											/* forest or SVM)																*/
		datastep=score.sas,                 /* the model scoring program, always use score.sas, even for ASTORE models 		*/
		xml=score.xml,						/* XML properties file								 							*/ 															*/	
		modeldir=/user/sasdemo/perm,		/* HADOOP destination path for the output file, this dir must exist in advance	*/
		modelname=jklModel,                 /* the model name, you make this up, so make it descriptive, the publish macro  */
											/* creates a sub-directory with this name under the modeldir					*/
		action=replace,                      					
		trace=yes );

****************************************;
* Delete any old scoring output tables *;
* HADOOP cannot overwrite tables       *;
****************************************;
proc delete data=hdlib.abt_output;
run;

***************************************;
* Run the model and score the dataset  ;
* Print 100 output file obs as a test  ;
***************************************;
%indhd_run_model(
		inmetaname=/user/sasdemo/metadata/file_to_be_scored.sashdmd,/* the HDFS path for the inpput table metadata			*/
		outdatadir=/user/sasdemo/tables/scored_output,			  	/* the HDFS path for the output table 					*/
		outmetadir=/user/sasdemo/metadata/scored_output.sashdmd,	/* the HDFS path for the metadata for the output table 	*/

																	/* if the model is a random forest or SVM, the publish	*/
																	/* macro creates an *.is file based on the ASTORE file	*/
																	/* if the model is not a random forest or SVM,  the 	*/
																	/* publish macro creates a *ds2 file based on the score */
																	/* code,  only point to the relevant file(*.ds2 or *.is)*/
																	/* the ds2/is file will be in a HADOOP directory path,	*/
																	/* created by the publish macro above					*/
		*scorepgm=/user/sasdemo/perm/jklModel/jklModel.ds2,		  	/* the <model>.ds2 code created by the publish function */
		*store = /user/sasdemo/perm/jklModel/jklModel.is,			/* the <model>.is file created by the publish function	*/
	
		forceoverwrite=true,									  	/* overwrite the table if it exists, invalid for HADOOP */
		INPUTFILE=/user/sasdemo/tables/file_to_be_scored,			/* the input data set, the file to be scored			*/
		trace=yes );
proc print 
    data=hdlib.scored_output(obs=100);
run;
