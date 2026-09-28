/********************************************************************************/ 
/*  This program will execute a proc netflow to solve a minimum cost network    */
/*  routing problem. The parameters for the input (costs, capacity, network     */                                                                          */
/*  structure are all taken from an Excel sheet (as a first draft solution).    */ 
/*  For the summary output, I prefer HTML to listing. That's whay I specify the */
/*  HTML output destination here. Furthermore, I assign a library reference to  */
/*  the folder C:\ORDEMO on my local hard drive.                                */
/********************************************************************************/
ods listing close;
ods html file='L:\Tcc\SASsoftware\OR\Demo-Ideas\Aktuell\ORdemo.html';

libname ordemo "L:\Tcc\SASsoftware\OR\Demo-Ideas\Aktuell";




/*******************************************************************************/
/* This part only specifies some European formats for currency, percentage and */
/* months to be used later for report display purposes. This was only done to  */
/* make it easier for me to interpret the results.                             */
/*******************************************************************************/

proc format;
  picture euros 0.0000001-high='0.000.000.000,00' (prefix='€' decsep=',' dig3sep='.')
                0.0000000='€0,00' (noedit);
  picture prozent 0.000001-high='0000000000000,00%' (mult=10000 decsep=',')
                  0.000000='0,00%' (noedit);				  
  value monate 1="Januar"
  			   2="Februar"
			   3="März"
			   4="April"
			   5="Mai"
			   6="Juni"
			   7="Juli"
			   8="August"
			   9="September"
			   10="Oktober"
			   11="November"
			   12="Dezember";
run;

/*******************************************************************************/
/* In the following section I use several proc import steps to get the relevant*/
/* input data from the various sheets of the Excel file parameter.xls. The     */
/* parameter overview sheet in that file lists the individual parameters.      */
/*******************************************************************************/

proc import out=ordemo.network
            datafile= "L:\Tcc\SASsoftware\OR\Demo-Ideas\Aktuell\parameter.xls" 
            dbms=EXCEL2000 replace;
			sheet='Network';
     		getnames=yes;
run;

proc import out=ordemo.locations
            datafile="L:\Tcc\SASsoftware\OR\Demo-Ideas\Aktuell\parameter.xls"
            dbms=EXCEL2000 replace;
            sheet='Locations';
     		getnames=yes;
run;

proc import out=ordemo.production
            datafile="L:\Tcc\SASsoftware\OR\Demo-Ideas\Aktuell\parameter.xls"
            dbms=EXCEL2000 replace;
            sheet='Production';
     		getnames=yes;
run;

proc import out=ordemo.storage
            datafile="L:\Tcc\SASsoftware\OR\Demo-Ideas\Aktuell\parameter.xls"
            dbms=EXCEL2000 replace;
            sheet='Storage';
     		getnames=yes;
run;


proc import out=ordemo.demand
            datafile="L:\Tcc\SASsoftware\OR\Demo-Ideas\Aktuell\parameter.xls"
            dbms=EXCEL2000 replace;
            sheet='Demand';
     		getnames=yes;
run;


/*******************************************************************************/
/* Here, I define macro variables for referencing the location names of        */
/* factories, warehouses, and shops for later use in some selected output      */
/* tables.                                                                     */
/*******************************************************************************/

data _null_;
  set ordemo.locations;
  if node='Factory1' then call symput("Factory1",location_name);
  else if node='Factory2' then call symput("Factory2",location_name);
  else if node='Factory3' then call symput("Factory3",location_name);
  else if node='Warehouse1' then call symput("Warehouse1",location_name);
  else if node='Warehouse2' then call symput("Warehouse2",location_name);
  else if node='Warehouse3' then call symput("Warehouse3",location_name);
  else if node='Shop1' then call symput("Shop1",location_name);
  else if node='Shop2' then call symput("Shop2",location_name);
  else if node='Shop3' then call symput("Shop3",location_name);
  run;


/*******************************************************************************/
/* As a preliminary step for building the final nodes data set I use the       */
/* following steps to compute total demand across all twelve months, rearrange */
/* the data, and process them, so that they can be used as input for the nodes */
/* data set. Note that I also compute supply nodes so that it matches the total*/
/* demand.                                                                     */
/*******************************************************************************/

data ordemo.tempdem_v0 (keep=d_total);
   set ordemo.demand;
   d_total=sum(d_jan,d_feb,d_mar,d_apr,d_may,d_jun,d_jul,d_aug,d_sep,d_oct,d_nov,d_dec);
run;
proc transpose data=ordemo.demand out=ordemo.tempdem_v1;
run;
data ordemo.tempdem_v2 (keep=col1);
   set ordemo.tempdem_v1;
run;
data ordemo.tempdem_v3 (keep=col2);
   set ordemo.tempdem_v1;
run;
data ordemo.tempdem_v4 (keep=col3);
   set ordemo.tempdem_v1;
run;
data ordemo.tempdem_v5 (drop=col1 col2 col3);
   set ordemo.tempdem_v2 ordemo.tempdem_v3 ordemo.tempdem_v4;
   if _N_<=12 then _supdem_=-1*col1;
   else if _N_>12 and _N_<=24 then _supdem_=-1*col2;
   else if _N_>24 then _supdem_=-1*col3;
run;
data ordemo.tempcap_v0;
   set ordemo.production ordemo.storage;
run;
data ordemo.supply (keep=_supdem_);
   set ordemo.production ordemo.tempdem_v0;
   _supdem_= d_total;
   if _N_ >3;
run;
data ordemo.tempdem_v6 (drop=I);
   do I=1 to 7;
   _supdem_=I;
   output;
   end;
run;


/*******************************************************************************/
/* Here I build the final nodes data set to be used by proc netflow. The names */
/* of the nodes are also specified. Originally, I intended to use nodes 40 to  */
/* 45 as artificial exit demand nodes, but now I ignore them. Just in case,    */
/* they will be used again, I still left them in.                              */
/*******************************************************************************/

data ordemo.nodes;
   missing D;
   set ordemo.supply ordemo.tempdem_v5 ordemo.tempdem_v6;
   length _node_ $7;
   if _N_ in (40,41,42,43,44,45,46) then _supdem_='D';
   if _N_ = 1 then _node_='f1st';
   else if _N_=2 then _node_='f2st';
   else if _N_=3 then _node_='f3st';
   else if _N_=4 then _node_='s1m1';
   else if _N_=5 then _node_='s1m2';
   else if _N_=6 then _node_='s1m3';
   else if _N_=7 then _node_='s1m4';
   else if _N_=8 then _node_='s1m5';
   else if _N_=9 then _node_='s1m6';
   else if _N_=10 then _node_='s1m7';
   else if _N_=11 then _node_='s1m8';
   else if _N_=12 then _node_='s1m9';
   else if _N_=13 then _node_='s1m10';
   else if _N_=14 then _node_='s1m11';
   else if _N_=15 then _node_='s1m12';
   else if _N_=16 then _node_='s2m1';
   else if _N_=17 then _node_='s2m2';
   else if _N_=18 then _node_='s2m3';
   else if _N_=19 then _node_='s2m4';
   else if _N_=20 then _node_='s2m5';
   else if _N_=21 then _node_='s2m6';
   else if _N_=22 then _node_='s2m7';
   else if _N_=23 then _node_='s2m8';
   else if _N_=24 then _node_='s2m9';
   else if _N_=25 then _node_='s2m10';
   else if _N_=26 then _node_='s2m11';
   else if _N_=27 then _node_='s2m12';
   else if _N_=28 then _node_='s3m1';
   else if _N_=29 then _node_='s3m2';
   else if _N_=30 then _node_='s3m3';
   else if _N_=31 then _node_='s3m4';
   else if _N_=32 then _node_='s3m5';
   else if _N_=33 then _node_='s3m6';
   else if _N_=34 then _node_='s3m7';
   else if _N_=35 then _node_='s3m8';
   else if _N_=36 then _node_='s3m9';
   else if _N_=37 then _node_='s3m10';
   else if _N_=38 then _node_='s3m11';
   else if _N_=39 then _node_='s3m12';
   else if _N_=40 then _node_='f1te';
   else if _N_=41 then _node_='f2te';
   else if _N_=42 then _node_='f3te';
   else if _N_=43 then _node_='w1te';
   else if _N_=44 then _node_='w2te';
   else if _N_=45 then _node_='w3te';
   else if _N_=46 then _node_='term';
   if _N_ <=39 OR _N_=46;
run;


/*******************************************************************************/
/* As a preliminary step for building the final arcs data set I need to merge  */
/* a raw structure of the network arcs with information about capacities and   */
/* costs supplied in other data sets that were imported from the Excel sheets. */
/* I use the variable key for that purpose. The second key variable (key2) is  */
/* used later on to merge locations. I also create two identifier variables for*/
/* an arc's function in the network and time period, respectively.             */
/*******************************************************************************/

data ordemo.temparcs_v0;
   set ordemo.network;
   if substr(tail,1,2)='f1' then key=1;
   else if substr(tail,1,2)='f2' then key=2;
   else if substr(tail,1,2)='f3' then key=3;
   else if substr(tail,1,2)='w1' then key=4;
   else if substr(tail,1,2)='w2' then key=5;
   else if substr(tail,1,2)='w3' then key=6;
   if substr(head,1,2)='w1' then key2=1;
   else if substr(head,1,2)='w2' then key2=2;
   else if substr(head,1,2)='w3' then key2=3;
   else if substr(head,1,2)='s1' then key2=4;
   else if substr(head,1,2)='s2' then key2=5;
   else if substr(head,1,2)='s3' then key2=6;
   else key2=0;
   if node_id <=36 then function='Production';
   else if node_id <=72 then function='Storage1';
   else if node_id <=180 then function='Flow1';
   else if node_id <=216 then function='Storage2';
   else if node_id <= 324 then function='Flow2';
   period = mod(_N_,12);
   if period =0 then period=12;
   if _N_ in (325,326,327,328,329,330) then 
   do;
      key=0;
	  key2=0;
	  period=.;
	  function='Exit';
	end;
run;
data ordemo.tempcap_v1;
    set ordemo.tempcap_v0;
	key=_N_;
	if key <=6;
run;
data ordemo.temploc_v0;
   set ordemo.locations;
   key=_N_;
   if key <=6;
run;

proc sort data=ordemo.temparcs_v0;
  by key;
run;
proc sort data=ordemo.tempcap_v1;
  by key;
run;
proc sort data=ordemo.temploc_v0;
  by key;
run;
data ordemo.temparcs_v1;
    merge ordemo.temparcs_v0 ordemo.tempcap_v1 ordemo.temploc_v0;
	by key;
run;

/*******************************************************************************/
/* In the following section, I create variable route that contains a string    */
/* consisting of the names of start and end nodes. This will be only used for  */
/* labeling some of the outputs. I use the key2 variable to merge this data set*/
/* back to the preliminary arcs data set. (I guess I could've done the same    */
/* thing a lot easier with macros.)                                            */
/*******************************************************************************/

data ordemo.temploc_v1 (rename=(location_name=destination_name));
   set ordemo.locations;
   key2=_N_-3;
   label location_name='Destination name';
   if key2 >0;
run;
proc sort data=ordemo.temparcs_v1;
   by key2;
run;
proc sort data=ordemo.temploc_v1;
   by key2;
run;
data ordemo.temparcs_v2; 
    merge ordemo.temparcs_v1 ordemo.temploc_v1;
	by key2;
	length route $25;
    startnodename=location_name;
    if function in ('Flow1','Flow2') then 
    do;
       endnodename = destination_name; 
       route=trim(startnodename)||' - '||trim(endnodename);
    end;
   
run;


/*******************************************************************************/
/* Here, I create the final arcs data sets. I get rid of temporary variables.  */
/* Also I initialize the cost and capacity variables with values from the      */
/* variables that have been merged to the temporary arcs data set and was      */
/* imported from the various sheets of the Excel parameter file. I also specify*/
/* lower and upper bounds as well as costs of artifical exit flow nodes.       */
/* Finally, I also specify that there should be no storage left after the      */
/* twelve month period. I do this, by specifying that the storage capacity for */
/* the last arc (leading from December node to terminal month node) is set to  */
/* zero.                                                                       */
/*******************************************************************************/

data ordemo.arcs (drop=production_capacity 
                       minimum_utilization
                       factory_storage_capacity
                       shipping_capacity_to_warehouse1
                       shipping_capacity_to_warehouse2
                       shipping_capacity_to_warehouse3
                       production_costs
                       factory_storage_costs
                       shipping_costs_to_warehouse1
                       shipping_costs_to_warehouse2
                       shipping_costs_to_warehouse3 
                       warehouse_storage_capacity
                       shipping_capacity_to_shop1
                       shipping_capacity_to_shop2
                       shipping_capacity_to_shop3
                       warehouse_storage_costs
                       shipping_costs_to_shop1
                       shipping_costs_to_shop2
                       shipping_costs_to_shop3 
                       location_name
                       destination_name
                       key
                       key2
                       node);
   set ordemo.temparcs_v2;
   length _from_ _to_ $7;
   _from_=tail;
   _to_=head;
   _capac_=.;
   _lo_=0;
   if function ='Production' then 
   do;
     _capac_=production_capacity;
     _lo_ =minimum_utilization*_capac_;
     _cost_=production_costs;
   end;
   else if function ='Storage1' then 
   do;
      _capac_=factory_storage_capacity;
	  _cost_=factory_storage_costs;
   end;
   else if function ='Storage2' then 
   do;
     _capac_=warehouse_storage_capacity;
     _cost_=warehouse_storage_costs;
   end;
   else if function ='Flow1' and substr(_to_,1,2)='w1' then 
   do;
     _capac_=shipping_capacity_to_warehouse1;
     _cost_=shipping_costs_to_warehouse1;
   end;
   else if function ='Flow1' and substr(_to_,1,2)='w2' then 
   do;
     _capac_=shipping_capacity_to_warehouse2;
	 _cost_=shipping_costs_to_warehouse2;
   end;
   else if function ='Flow1' and substr(_to_,1,2)='w3' then 
   do;
     _capac_=shipping_capacity_to_warehouse3;
     _cost_=shipping_costs_to_warehouse3;
	end;
   else if function ='Flow2' and substr(_to_,1,2)='s1' then
   do;
     _capac_=shipping_capacity_to_shop1;
	 _cost_=shipping_costs_to_shop1;
	end;
   else if function ='Flow2' and substr(_to_,1,2)='s2' then 
   do;
     _capac_=shipping_capacity_to_shop2;
	 _cost_=shipping_costs_to_shop2;
   end;
   else if function ='Flow2' and substr(_to_,1,2)='s3' then 
   do;
     _capac_=shipping_capacity_to_shop3;
	 _cost_=shipping_costs_to_shop3;
   end;
   if function='Exit' and substr(_from_,3,2)='st' then
   do;
     _capac_=99999;
     _cost_=99999;
     _lo_=-99999;
   end;
   if function='Exit' and substr(_from_,3,2)='te' then
   do;
     _capac_=0;
     _cost_=0;
     _lo_=0;
   end;
   if substr(_to_,3,2)='te' and function in ('Storage1','Storage2') then
   do;
     _capac_=0;
	 _lo_=0;
   end;
   if function='Flow2' and substr(head,1,2)='s1' then _cost_=_cost_-price_shop1;
   else if function='Flow2' and substr(head,1,2)='s2' then _cost_=_cost_-price_shop2;
   else if function='Flow2' and substr(head,1,2)='s3' then _cost_=_cost_-price_shop3;
run;
proc sort data=ordemo.arcs;
 by node_id;
run;

/*******************************************************************************/
/* This is the core part of the SAS program where the proc netflow is used. At */
/* this point, I haven't introduced any side constraints. That's why the       */
/* condata option is not used.                                                 */
/*******************************************************************************/

proc netflow thrunet
	arcdata=ordemo.arcs
    nodedata=ordemo.nodes
	arcout=ordemo.solution_arcs
    nodeout=ordemo.solution_nodes;
	set future1;
run;

/*******************************************************************************/
/* What follows are some example outputs that exploit the information in the   */
/* solution_arcs data set. Note that part is not really necessary for assessing*/
/* the solution, but helps interpret it as being suitable as a business case   */
/* scenario. For ease of orientation, the first part simply lists the names of */
/* the locations (in this case, some German cities).                           */
/*******************************************************************************/

proc print data=ordemo.locations noobs label;
   title1 "OR Demo: Locations";
   label location_name="Location";
run;


/*******************************************************************************/
/* This section prints out an overall cost summary table, broken down by       */
/* company function (i.e., layer of the company's value chain).                */
/*******************************************************************************/

data ordemo.results;
   set ordemo.solution_arcs;
   if function='Flow2' and substr(

run;

proc sort data=ordemo.results;
   by function;
run;
proc means noprint data=ordemo.results;
   var _fcost_;
   class function;
   output out=ordemo.tempcost sum (_fcost_)=total;
run;
data ordemo.cost_summary;
    set ordemo.tempcost;
	if _N_ > 2;
	if function='Production' then f_rang=1;
	else if function='Storage1' then f_rang=2;
	else if function='Flow1' then f_rang=3;
	else if function='Storage2' then f_rang=4;
	else if function='Flow2' then f_rang=5;
	length f_name $30.;
	if f_rang=1 then f_name='1. Production';
	else if f_rang=2 then f_name='2. Factory Storage';
	else if f_rang=3 then f_name='3. Factory Shipment';
	else if f_rang=4 then f_name='4. Warehouse Storage';
    else if f_rang=5 then f_name='5. Retail Distribution';
run;
proc sort data=ordemo.cost_summary;
   by f_rang;
run;
proc print data=ordemo.cost_summary label noobs;
     var f_name total;
	 sum total;
	 label f_name='Function area';
	 label total = 'Cost';
	 format total euros.;
	 title1 'OR Demo: Total Cost Summary';
run;


/*******************************************************************************/
/* This section prints out the production schedule. The schedule contains the  */
/* production capacities, utiliziation ratios, produced quantities and         */
/* associated costs, broken down by production site and month.                 */
/*******************************************************************************/

data ordemo.production_schedule;
    set ordemo.solution_arcs;
	utilization=_flow_/_capac_;
	where function='Production';
run;
proc sort data=ordemo.production_schedule;
   by startnodename period;
run;
proc print data=ordemo.production_schedule noobs label split='*';
   var period _capac_ utilization _cost_ _flow_ _fcost_;
   sum _fcost_ _flow_ _capac_;
   title1 'OR Demo: Production Schedule';
   by startnodename;
   id startnodename;
   format _cost_ _fcost_ euros.;
   format period monate.;
   format utilization prozent.;
   format _capac_ _flow_ commax10.;
   label _capac_="Production*capacity";
   label startnodename='Location';
   label utilization='Capacity*utilization';
   label _flow_='Production*quantity';
   label _cost_='Unit costs*for production';
   label _fcost_='Production*costs';
   label period='Month';
run;


/*******************************************************************************/
/* This section prints out the storage schedule. It is assumed, that goods can */
/* be stored temporarily at the production sites. The plan contains the        */
/* storage capacities, stored quantities and associated costs, broken down by  */
/* production site and month.                                                  */
/*******************************************************************************/

data ordemo.factory_storage;
    set ordemo.solution_arcs;
	where function = 'Storage1';
run;
proc sort data=ordemo.factory_storage;
   by startnodename period;
run;
proc print data=ordemo.factory_storage noobs label split='*';
  var period _capac_ _cost_ _flow_ _fcost_;
  sum _capac_ _flow_ _fcost_;
  format _capac_ _flow_ commax10.2;
  format period monate.;
  format _cost_ _fcost_ euros.;
  title1 'OR Demo: Factory Inventory Schedule';
  label startnodename='Location';
  label period='Month';
  label _capac_='Storage*Capacity';
  label _cost_='Unit Costs*for Storage';
  label _flow_='Stored*Quantity';
  label _fcost_='Storage*Costs';
  by startnodename;
  id startnodename;
run;


/*******************************************************************************/
/* This section prints out the shipping schedule for goods leaving the         */
/* factories for the warehouses. The schedule contains the transportation      */
/* capacities, shipped quantities and associated costs, broken down by shipping*/
/* route and month.                                                            */
/*******************************************************************************/

data ordemo.factory_shipment;
    set ordemo.solution_arcs;
	where function = 'Flow1';
run;
proc sort data=ordemo.factory_shipment;
   by route period;
run;
proc print data=ordemo.factory_shipment noobs label split='*';
  var period _capac_ _cost_ _flow_ _fcost_;
  sum _capac_ _flow_ _fcost_;
  format _capac_ _flow_ commax10.2;
  format period monate.;
  format _cost_ _fcost_ euros.;
  title1 'OR Demo: Factory Shipping Schedule';
  label route='Route';
  label period='Month';
  label _capac_='Shipping*Capacity';
  label _cost_='Unit Costs*for Shipping';
  label _flow_='Shipped*Quantity';
  label _fcost_='Shipping*Costs';
  by route;
  id route;
run;


/*******************************************************************************/
/* This section prints out the storage schedule for goods in the warehouses.   */
/* The schedule contains the storage capacities, stored quantities and         */
/* associated costs, broken down by warehouse location and month.              */
/*******************************************************************************/
 
data ordemo.warehousing;
    set ordemo.solution_arcs;
	where function = 'Storage2';
run;
proc sort data=ordemo.warehousing;
   by startnodename period;
run;
proc print data=ordemo.warehousing noobs label split='*';
  var period _capac_ _cost_ _flow_ _fcost_;
  sum _capac_ _flow_ _fcost_;
  format _capac_ _flow_ commax10.2;
  format period monate.;
  format _cost_ _fcost_ euros.;
  title1 'OR Demo: Warehouse Inventory Schedule';
  label startnodename='Location';
  label period='Month';
  label _capac_='Storage*Capacity';
  label _cost_='Unit Costs*for Storage';
  label _flow_='Stored*Quantity';
  label _fcost_='Storage*Costs';
  by startnodename;
  id startnodename;
run;

/*******************************************************************************/
/* This section prints out the retail distribution schedule for goods leaving  */
/* the warehouses for their final destinations (i.e., the retail outlets). The */
/* schedule contains the transportation capacities, shipped quantities and     */
/* associated costs, broken down by shipping route and month.                  */
/*******************************************************************************/

data ordemo.distribution;
    set ordemo.solution_arcs;
	where function = 'Flow2';
run;
proc sort data=ordemo.distribution;
   by route period;
run;
proc print data=ordemo.distribution noobs label split='*';
  var period _capac_ _cost_ _flow_ _fcost_;
  sum _capac_ _flow_ _fcost_;
  format _capac_ _flow_ commax10.2;
  format period monate.;
  format _cost_ _fcost_ euros.;
  title1 'OR Demo: Retail Outlet Distribution Schedule';
  label route='Route';
  label period='Month';
  label _capac_='Shipping*Capacity';
  label _cost_='Per Unit*Shipping Cost';
  label _flow_='Shipped*Quantity';
  label _fcost_='Shipping *Cost';
  by route;
  id route;
run;


/*******************************************************************************/
/* This section prints out a summary of outlet delivery (i.e., which outlets   */
/* are receiving which quantities from which warehouse locations). The summary */
/* contains demand quantities, delivered quantities (total and broken down by  */
/* warehouse location), broken down by month. Also, included is a variable for */
/* indicating service level (which in this simple example is just the ratio of */
/* demand and total delivery). In order to arrive at this table, I first need  */
/* to rearrange the demand figures and stack the delivery quantitites from the */
/* individual warehouses next to each other.                                   */
/*******************************************************************************/

data ordemo.tempdem_v7;
    set ordemo.nodes;
	if _N_ > 3 AND _N_<40;
	_supdem_=_supdem_*(-1);
run;
data ordemo.tempdem_v8 (Keep=endnodename period _flow_ _to_ rename=(_flow_=wh1 _to_=_node_));
     set ordemo.solution_arcs;
	 where function='Flow2' and substr(_from_,1,2)='w1';
	 length _node_ $9.;
run;
data ordemo.tempdem_v9 (Keep=_flow_ _to_ rename=(_flow_=wh2 _to_=_node_));
     set ordemo.solution_arcs;
	 where function='Flow2' and substr(_from_,1,2)='w2';
	 length _node_ $9.;
run;
data ordemo.tempdem_v10 (Keep=_flow_ _to_ rename=(_flow_=wh3 _to_=_node_));
     set ordemo.solution_arcs;
	 where function='Flow2' and substr(_from_,1,2)='w3';
	 length _node_ $9.;
run;
proc sort data=ordemo.tempdem_v7;
   by _node_;
run;
proc sort data=ordemo.tempdem_v8;
   by _node_;
run;
proc sort data=ordemo.tempdem_v9;
   by _node_;
run;
proc sort data=ordemo.tempdem_v10;
   by _node_;
run;
data ordemo.delivery_report;
  merge ordemo.tempdem_v8 ordemo.tempdem_v9 ordemo.tempdem_v10 ordemo.tempdem_v7;
  by _node_;
  total=sum(wh1,wh2,wh3);
  if _supdem_ ne 0 then service_level=total/_supdem_;
  else service_level=0;
  length shop $20.;
  if substr(_node_,1,2)='s1' then shop=endnodename;
  else if substr(_node_,1,2)='s2' then shop=endnodename;
  else if substr(_node_,1,2)='s3' then shop=endnodename;
run;
proc sort data=ordemo.delivery_report;
   by shop period;
run;
proc print data=ordemo.delivery_report label noobs split='*';
    var period _supdem_ total wh1 wh2 wh3 service_level;
	sum _supdem_ total wh1 wh2 wh3;
	format _supdem_ total wh1 wh2 wh3 commax10.;
	format period monate.;
	format service_level prozent.;
	title1 'OR Demo: Summary of Retail Outlet Delivery';
	id shop;
    by shop;
	label shop='Retail Outlet Store';
	label _supdem_='Demand';
	label total='Total Delivery Qty.';
	label wh1='Qty. from'*&Warehouse1;
	label wh2='Qty. from'*&Warehouse2;
	label wh3='Qty. from'*&Warehouse3;
	label period='Month';
	label service_level='Service*Level';
run;

/*******************************************************************************/
/* This part closes the "official" output section. I use listing from now on to*/
/* print some diagnostic stuff into the SAS output window.                     */
/*******************************************************************************/

ods html close;
ods listing;

/*******************************************************************************/
/* Here, I simply repeat the proc netflow, so that I get the results at the    */
/* end of the SAS log, rather than having to scroll through the log each and   */
/* every time I want to inspect the feasibility of the solution.               */
/*******************************************************************************/
proc netflow thrunet
	arcdata=ordemo.arcs
    nodedata=ordemo.nodes
	arcout=ordemo.solution_arcs 
    nodeout=ordemo.solution_nodes;
	set future1;
run;

/*******************************************************************************/
/* Here, I print out the macro variable to listing to see the status of the    */
/* solution. At a later point, I could exploit the information in this variable*/
/* to give the user some feedback as to whay a given transportation schedule   */
/* wouldn't work.                                                              */
/*******************************************************************************/
%put &_ORNETFL;

/*******************************************************************************/
/* Here I do some post-processing to inspect any flows to the artificial       */
/* exit nodes and the nodes that terminate the monthly storage schedule        */
/* (suffix 'te').                                                              */
/*******************************************************************************/
proc print data=ordemo.solution_arcs;
   var _from_ _to_ _flow_;
   where substr(_to_,3,2)='te' OR _to_='term';
run;

/*******************************************************************************/
/* Finally, I clean up temporary files that are no longer used                 */
/*******************************************************************************/

proc datasets library=ordemo;
   delete cost_summary
		  delivery_report
          demand
          distribution
          factory_shipment
          factory_storage
          locations
          network
          production
          production_schedule
          storage
          supply
          temparcs_v0
          temparcs_v1
          temparcs_v2
          tempcap_v0
          tempcap_v1
          tempcost
          tempdem_v0
          tempdem_v1
          tempdem_v10
          tempdem_v2
          tempdem_v3
          tempdem_v4
          tempdem_v5
          tempdem_v6
          tempdem_v7
          tempdem_v8
          tempdem_v9
          temploc_v0
          temploc_v1
          warehousing
/memtype=DATA
;

quit;