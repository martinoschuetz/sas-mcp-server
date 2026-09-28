*Kan ej vara preassigned;
libname intabs "/sasdata/loadtova";


*Skapa testdata;
data intab.testdata;
	format day date10.;
	do i=10 to 100;
		day=date()-i;
		sasday=date()-i;
		if i=10 then put "first " day=;
		if i=100 then put "last " day=;
		output;
	end;
run;

data intabs.testdata2;
	format day date10.;
	do i=0 to 9;
		day=date()-i;
		sasday=date()-i;
		if i=0 then put "first " day=;
		if i=9 then put "last " day=;
		output;
	end;
run;

*Tom tabell;
data intabs.testdata3;
	set intabs.testdata2(obs=0);
run;



LIBNAME VALIBLB SASIOLA PORT=10010 HOST="aa278sas001.han.telia.se" TAG=intabs;


proc lasr add PORT=10010
          data=intabs.testdata
          noclass;
proc lasr add PORT=10010
          data=intabs.testdata2 
          noclass;
run;

proc datasets lib=VALIBLB;
quit;


proc imstat; 
	table VALIBLB.testdata;
	set testdata2 / drop; 
/*	set testdata3 / drop; */
run;
proc contents data=VALIBLB.testdata;
run;



proc metalib;
	omr (library="/Products/SAS Visual Analytics Administrator/Visual Analytics LASR load");
	folder="/Telia VA/CRA/LASR Data"; 
	select=("testdata");  
run;


*Delete nr of days;
proc imstat data=VALIBLB.testdata;
	where day<19936; 
	deleterows /purge;
run;




*Save to HDFS;
LIBNAME hps SASHDAT  PATH="/hps"  SERVER="aa278sas001.han.telia.se"  INSTALL="/opt/TKGrid" ;
proc lasr port=10010;
    save VALIBLB.testdata / fullpath path="/hps/HDFS Tables/testdata" copies=1 replace;
run;

/*Try 2 save to HDFS:*/
/*proc imstat data=VALIBLB.testdata;*/
/*    save path="/hps/HDFS Tables/testdata" copies=1 fullpath replace; */
/*run;*/


/**Delete table from LASR;*/
/*proc lasr port=10010 SIGNER="http://aa278sas001.han.telia.se:7980/SASLASRAuthorization";*/
/*    remove VALIBLA.testdata;*/
/*run;*/

/**/
/**Delete metadata;*/
/*proc metalib;*/
/*	omr (library="/Products/SAS Visual Analytics Administrator/Visual Analytics LASR");*/
/*	folder="/Telia VA/CRA/LASR Data"; */
/*	select=("sbxsoe_testdata");  */
/*	update_rule=(delete);*/
/*run;*/



/*option set=GRIDHOST="aa278sas001.han.telia.se";*/
/*option set=GRIDINSTALLLOC="/opt/TKGrid";*/