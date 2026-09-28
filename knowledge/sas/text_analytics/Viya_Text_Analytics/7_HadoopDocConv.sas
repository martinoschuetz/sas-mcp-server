/* -- PREREQUISITES:
 *    Hadoop HDFS access: 
      + You will need a HDFS account
      + Your CAS server should be able to see the Hadoop cluster
      + The embedded process (EP) is delivered through 
        "SAS In-Database Technologies for Hadoop (on SAS VIYA)"
 */

/* Connect to CAS */
/* -- FILL YOUR 
      + CAS USER (e.g. sasdemo) 
      + CAS SERVER (e.g. pdcesx23001.exnet.sas.com) -- */
options casuser=<YOUR USER NAME>;
options cashost='<YOUR CAS SERVER>';
options casport=5570;

cas mysess; 

/* Set Hadoop JAR paths */
/* NOTE: Confirm the Hadoop JAR paths with your Hadoop admin */
options set=SAS_HADOOP_CONFIG_PATH="/sasusr/u/fedadmin/viya/hadoopcfg/hdp26d2/prod";
options set=SAS_HADOOP_JAR_PATH="/sasusr/u/fedadmin/viya/hadoopjars/hdp26/prod"; 

/* Create a libname to HDFS folder with documents
 *  -- data: Folder which has all the documents
 *  -- meta, temp: Intermediate folders required for document conversion 
 */
/* NOTE: Fill in:
   + your <HADOOP_SERVER>
   + your <HADOOP_USERNAME>
   + your <HADOOP_HOME_DIR>
   + this example assumes that your documents are under 'data'
   + 'meta' and 'temp' temporary folders in your Hadoop account
     required to run map-reduce job for Document Conversion */
libname hdfs3 hadoop server="HADOOP_SERVER" user=<HADOOP_USERNAME>
                    HDFS_DATADIR="<HADOOP_HOME_DIR>/data"
                    HDFS_METADIR="<HADOOP_HOME_DIR>/meta"
                    HDFS_TEMPDIR="<HADOOP_HOME_DIR>/temp";

proc delete data=hdfs3.output20; 
run;

/* NOTE: Fill in <HADOOP_SUBFOLDER> -- This is a folder under
         <HADOOP_HOME_DIR>/data
 */
proc hdmd name=hdfs3.output20
          data_file='<HADOOP_SUBFOLDER>' 
          file_format=DELIMITED
          sep=^A
          file_type=CUSTOM
          input_class='com.sas.text.docconv.DocConvRecursiveInputFormat'
          ;

     COLUMN fileName varchar(256);
     COLUMN content  varchar(60000);
run;

/* NOTE: Fill in:
 *		+ your HADOOP_HOME_DIR
 *		+ your HADOOP_USERNAME
 *		+ your HADOOP_SERVER
 */
proc cas;
   session mysess;
   action addCaslib lib="hdmd3"
          datasource={srctype="hadoop",
                      hadoopJarPath="/sasusr/u/fedadmin/viya/hadoopjars/hdp26/prod",
                      hadoopConfigDir="/sasusr/u/fedadmin/viya/hadoopcfg/hdp26d2/prod", 
                      hdfsMetadir="<HADOOP_HOME_DIR>/meta",
                      hdfsdatadir="<HADOOP_HOME_DIR>/data",
                      hdfstempdir="<HADOOP_HOME_DIR>/temp",
                      username="<HADOOP_USERNAME>",
                      server="<HADOOP_SERVER>",
                      dataTransferMode="parallel" } ;
   run; 
quit;

proc cas;
   session mysess;
   action droptable
          caslib="hdmd3"
          name="output20";
   run; 
quit;                                              

/********************************************************************/
proc cas;
   session mysess;
   action loadtable
      caslib="hdmd3"
      options={customjars="/opt/sas/viya/home/SASFoundation/lib/docconvjars", dfdebug="EPALL"}
      path="output20";
   run; 
quit;

proc cas;
   session mysess;
   action table.fetch /
          table={name="output20", caslib="hdmd3" }
          to=300;          
   run; 
quit;