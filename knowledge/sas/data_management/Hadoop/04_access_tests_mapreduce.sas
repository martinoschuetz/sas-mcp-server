/* ------------------------------------------------------------------------- */
/* ( 1 ) Testing MapReduce                                                   */
/* ------------------------------------------------------------------------- */
*filename cfg "&SAS_HADOOP_CONFIG_XML.";

proc hadoop /*cfg=cfg*/ username="&USER." verbose;
	hdfs delete="/user/&USER./loremipsum.txt";
	hdfs delete="/user/&USER./wordcount";
run;

filename out hadoop "/user/&USER./loremipsum.txt" debug /*cfg=cfg*/ user="&USER.";
data _null_;
	file out;

	length long $1024;
	input;
	long = _infile_;
	long = trim(long);
	put long ' ';

cards4;
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt 
ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo 
dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit 
amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt 
ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores 
et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.
;;;;
run;


/* ------------------------------------------------------------------------- */
proc hadoop /*options=cfg*/ username="&USER." verbose;   
	mapreduce 
		input="/user/&USER./loremipsum.txt" output="/user/&USER./wordcount"
		jar="D:\HADOOP_Configs\inthadoop_hdp21\jars\hadoop-mapreduce-examples-2.4.0.2.1.7.0-784.jar" 
		outputkey="org.apache.hadoop.io.Text"
		outputvalue="org.apache.hadoop.io.IntWritable"
		reduce="org.apache.hadoop.examples.WordCount$IntSumReducer"
		combine="org.apache.hadoop.examples.WordCount$IntSumReducer"
		map="org.apache.hadoop.examples.WordCount$TokenizerMapper"
		reducetasks=0
		;
run;
