cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US");

caslib demodata datasource=(srctype="path") path="/opt/data/demodata" global sessref=mySession;
caslib winedata datasource=(srctype="path") path="/opt/data/wine" global sessref=mySession;
caslib rawdata datasource=(srctype="path") path="/opt/data/raw" global sessref=mySession;
caslib casdata datasource=(srctype="path") path="/opt/data/sashdat" global sessref=mySession;
caslib projdata datasource=(srctype="path") path="/opt/data/projects" global sessref=mySession;


caslib _all_ assign;
caslib _all_ list;

proc casutil sessref=mysession;
	list files incaslib=demodata;
	list files incaslib=winedata;
	list files incaslib=rawdata;
	list files incaslib=casdata;
	list files incaslib=projdata;
run;

quit;
