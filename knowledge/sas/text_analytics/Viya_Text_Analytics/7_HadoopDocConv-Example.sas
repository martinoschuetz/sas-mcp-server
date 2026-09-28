/* Connect to CAS */
options casuser=ssethi;
options cashost='crankslesgrd015.CRANK.sashq-r.openstack.sas.com';
options casport=5570;

cas mysess; 

/* Set Hadoop JAR paths */
options set=SAS_HADOOP_CONFIG_PATH="/sasusr/u/fedadmin/viya/hadoopcfg/hdp26d2/prod";
options set=SAS_HADOOP_JAR_PATH="/sasusr/u/fedadmin/viya/hadoopjars/hdp26/prod"; 

/* Create a libname to HDFS folder with documents
 *  -- data: Folder which has all the documents
 *  -- meta, temp: Intermediate folders required for document conversion 
 */
libname hdfs3 hadoop server="hdp26d2" user=ssethi
                    HDFS_DATADIR="/user/ssethi/data"
                    HDFS_METADIR="/user/ssethi/meta"
                    HDFS_TEMPDIR="/user/ssethi/temp";

proc delete data=hdfs3.output20; 
run;

proc hdmd name=hdfs3.output20
          data_file='demoDocs'
          file_format=DELIMITED
          sep=^A
          file_type=CUSTOM
          input_class='com.sas.text.docconv.DocConvRecursiveInputFormat'
          ;

     COLUMN fileName varchar(256);
     COLUMN content  varchar(60000);
run;

proc cas;
   session mysess;
   action addCaslib lib="hdmd3"
          datasource={srctype="hadoop",
                      hadoopJarPath="/sasusr/u/fedadmin/viya/hadoopjars/hdp26/prod",
                      hadoopConfigDir="/sasusr/u/fedadmin/viya/hadoopcfg/hdp26d2/prod", 
                      hdfsMetadir="/user/ssethi/meta",
                      hdfsdatadir="/user/ssethi/data",
                      hdfstempdir="/user/ssethi/temp",
                      username="ssethi",
                      server="hdp26d2",
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