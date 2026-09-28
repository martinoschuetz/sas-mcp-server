/***********************************************************************************************
/*              Projekt Inventory Optimization for Bayer Business Services                     *
/***********************************************************************************************/

/* Set macro variable for file location */
%let path=D:\DATEN\BBS_SPO\IO_Projekt\;

/* set macro variables for controlling the optimization procedure */

/*
%let demandmodel=DISCRETE;
%let objective=OPTPOLICY;
%let policyparm=INTEGER;
%let servicetype=FR;
%let policytype=BS;
 */

options symbolgen mprint;


/* libref for results */
libname bbs "D:\Daten\BBS_SPO\IO_Projekt";

/* Create working copy of Excel file (so you can look at data in Excel at same time without touching the copy) */
data _null_;
         x "COPY &path.Data_Sample.xls &path.Kopie.xls";
run;


/* Read in the demand data from the respective Excel worksheet*/
PROC IMPORT OUT=bbs.DEMAND
            FILE="&path.Kopie.xls"
			DBMS=EXCEL REPLACE;
			SHEET="MIRP_NACHFRAGE";
            GETNAMES=YES;
RUN;

/* Read the node data from the respective Excel worksheet */
PROC IMPORT OUT=bbs.NODES
            FILE="&path.Kopie.xls"
			DBMS=EXCEL REPLACE;
			SHEET="MIRP_NETZKNOTEN";
            GETNAMES=YES;
RUN;

/* Read the arcs data from the respective Excel worksheet */
PROC IMPORT OUT=bbs.ARCS
            FILE="&path.Kopie.xls"
			DBMS=EXCEL REPLACE;
			SHEET="MIRP_VERBINDUNGEN";
            GETNAMES=YES;
run;

/* Make Character variable for location ID from original */
data bbs.NODES;
 set bbs.NODES;
 length C_LOCATION_ID $20.;
 C_LOCATION_ID=input(LOCATION_ID,$20.);
 drop location_id;
 servicetype="&servicetype";
 policytype="&policytype";
run;


/* Make Character variable for location ID (head and tail) */
data bbs.ARCS;
 set bbs.ARCS;
 length C_HEAD $20.;
 length C_TAIL $20.;
 /* Attention: Switch role for HEAD and TAIL - Demand data were given for nodes that have HEAD role */
 C_HEAD=input(TAIL,$20.);
 C_TAIL=input(HEAD,$20.);
 drop head tail;
run;

/* Make Character variable for location ID*/
data bbs.DEMAND;
 set bbs.DEMAND;
 length C_LOCATION_ID $20.;
 C_LOCATION_ID=input(LOCATION_ID,$20.);
 drop location_id;
run;


/* We need to add the EXTERNAL Supplier node info for each network as this was not provided by the customer. External
nodes are those that are listed in the nodes data set but where no entry can be found in the Tails column of the Arcs 
data set. Note that we also add "EXTERNAL" keyword, BOM_QTY and network_id to the table */
proc sql; create table external as 
select  distinct C_LOCATION_ID as C_TAIL, network_id, "EXTERNAL" as C_HEAD, 1 as BOM_QTY
from bbs.nodes
where C_LOCATION_ID not in (SELECT distinct C_TAIL from bbs.arcs)
order by C_Location_ID;
quit;


/* Append additional information about EXTERNAL suppliers to ARCS data set */
data bbs.ARCS;
 set bbs.ARCS EXTERNAL;
run;
/* ... and sort by net id */
proc sort data=bbs.ARCS;
 by network_id;
run;

proc sort data=bbs.NODES;
 by network_id;
run;

proc sort data=bbs.DEMAND;
 by network_id;
run;




/* Run the optimization */
proc mirp nodedata=bbs.NODES arcdata=bbs.ARCS demanddata=bbs.DEMAND 
		  out=OPTIMAL_RESULTS
		  horizon=1
          demandmodel=&demandmodel
		  objective=&objective
		  policyparm=&policyparm

;

    NODE / Networkid=network_id 
		   SKULOC=c_location_id
		   LEADTIME=leadtime
		   ServiceLevel=Servicelevel
		   HoldingCost=HoldingCost;

    ARC / Networkid=network_id
          Predecessor=c_head
          Successor=c_tail
          Quantity=BOM_Qty;

    DEMAND / Networkid=network_id
             SKULOC=c_location_id
			 MEAN=DEMAND_MEAN
			 VARIANCE=DEMAND_VAR;
     
run;


proc print data=OPTIMAL_RESULTS;
run;