/* macro to generate XML code */
%macro genXML(inputTable, XMLFileRef,type);
	libname  &XMLFileRef XML tagset=tagsets.sasxmog xmldataform=ATTRIBUTE xmlencoding="UTF-8";

	data &XMLFileRef..&type.;
		set &inputTable;
		output;
		;
	run;

	libname &XMLFileRef clear;
%mend genXML;

/* Create input variable information */
proc contents data=data.hmeq(drop=BAD) out=work.input(keep=name type label length);
run;

data inputc(drop=type length rename=(ctype=TYPE clength=LENGTH));
	length ctype $1;
	length clength $3;
	set input;

	if type=1 then
		ctype="N";

	if type=2 then
		ctype="C";
	clength=trim(left(put(length,3.)));
run;

/* write to XML */
filename inXML "&path./input.xml";

%genXML(work.inputc, inXML,INPUT);

/* write JSON */
filename fileMeta "&path./fileMetadata.json";

proc json out=fileMeta pretty;
	write open array;
	write open object;
	write values "role" "score";
	write values "name" "scorecode_tree.sas";
	write close;
	write close;
run;

/* Package all files */
filename trCode "&path./procedure_datastep_programFile.sas";
filename scCode "&path./scorecode_tree.sas";
ods package(newzip) open nopf;
ods package(newzip) add file=trCode;
ods package(newzip) add file=scCode;
ods package(newzip) add file=inXML;
ods package(newzip) add file=outXML;
ods package(newzip) add file=tarXML;
ods package(newzip) add file=modProp;
ods package(newzip) add file=fileMeta;
ods package(newzip) publish archive 
	properties(
	archive_name="tree_model.zip" 
	archive_path="&path."
	);
ods package(newzip) close;