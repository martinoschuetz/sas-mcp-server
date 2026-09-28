options metaserver="myserver" metaport=8561 metauser="sasadm@saspw" metapass="SASpw1" metarepository="Foundation" metaprotocol=BRIDGE;

proc metalib;
	omr (library="Visual Analytics LASR"); /* Logical name for your lasr library */
	update_rule=(noadd);
	report(type=summary);
	folder="/Shared Data/LasrTables"; /* A metadata folder to contain lasr table definition */
run;