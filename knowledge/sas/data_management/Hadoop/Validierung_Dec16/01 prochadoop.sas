/* ---------------------------------------------------- */
option sastrace=',,,d' sastraceloc=saslog nostsuffix msglevel=i ds2scond=note;

/* ---------------------------------------------------- */
%put ****    *** Checking if Hadoop environment variables have been set ***;
%put ****        OK ... SAS_HADOOP_JAR_PATH    = %sysget(SAS_HADOOP_JAR_PATH);
%put ****        OK ... SAS_HADOOP_CONFIG_PATH = %sysget(SAS_HADOOP_CONFIG_PATH);

/* ---------------------------------------------------- */
proc hadoop verbose;
   hdfs mkdir="/tmp/sastest";
run;

filename out "/tmp/prdsale.tsv";
data _null_;
        set sashelp.prdsale;
        file out;
        attrib row format=$256.;
        row = cats(actual, "09"x, predict, "09"x, country, "09"x, region, "09"x,
                division, "09"x, prodtype, "09"x, product, "09"x, quarter, "09"x,
                year, "09"x, month);
        put row;
run;

proc hadoop verbose;
   hdfs copyFromLocal="/tmp/prdsale.tsv" out="/tmp/sastest" overwrite;
run;

proc hadoop verbose;
   hdfs copyToLocal="/tmp/sastest/prdsale.tsv" out="/tmp/prdsale.tsv.2" overwrite;
run;

proc hadoop verbose;
   hdfs delete ="/tmp/sastest" recurse;
run;
