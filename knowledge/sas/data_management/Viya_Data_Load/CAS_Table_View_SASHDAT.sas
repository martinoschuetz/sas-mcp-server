CAS mySession SESSOPTS=(CASLIB=casuser TIMEOUT=99 LOCALE="en_US" metrics=true);
%let gateuserid=&sysuserid ;
%put My Userid is: &gateuserid ;
options msglevel=i;
%let prev_base_table="&gateuserid._order_fact" ;
%let view_name1="&gateuserid._OrderFactView";
%let view_name2="&gateuserid._OrderFactViewC";
%let base_table="order_fact.sashdat";

/* CASLIB Path data source located on CAS controller */
/* commented since its pre-defined */
/*

caslib DM path="/gelcontent/demo/DM/data/" type=path global;

*/
/* Drop in-memory CAS table */
proc casutil;
	droptable casdata=&prev_base_table.  incaslib="DM" quiet;
	quit;

	/* Drop in-memory CAS view/table */
proc casutil;
	droptable casdata=&view_name1. incaslib="DM" quiet;
	quit;

	/* create a new CAS view with selected columns based on .sashdat file */
proc cas;
	session mySession;
	table.view / name=&view_name1.  Caslib="DM" promote=true tables={{Caslib="DM", 
		name=&base_table., varlist={"customer_rk", "date_id", "item_rk", "item_qty", 
		"item_cost_amt", "list_price_amt"} }};
quit;

/* Drop in-memory CAS view/table */
proc casutil;
	droptable casdata=&view_name2.  incaslib="DM" quiet;
	quit;

	/* create a new CAS view with selective and computed columns based on .sashdat file */
proc cas;
	session mySession;
	table.view / name=&view_name2.  Caslib="DM" promote=true tables={{Caslib="DM", 
		name=&base_table., varlist={"customer_rk", "date_id", "item_rk", "item_qty", 
		"item_cost_amt", "list_price_amt"}, ComputedVars={{name="Cprice"}}, 
		ComputedVarsProgram="Cprice= item_qty * item_cost_amt;"}};
quit;

/* list in-memory table from path CASLIB DM  */
proc casutil;
	list tables incaslib="DM";
quit;

	/* Drop in-memory CAS view/table */
proc casutil;
	droptable casdata=&view_name1.   incaslib="DM" quiet;
	droptable casdata=&view_name2.    incaslib="DM" quiet;
quit;

/* Shutdown CAS Session */
CAS mySession TERMINATE;