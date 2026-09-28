/*======================================================================*/
/*	VERSION2: 	-put the source path of the macro before each macro		*/
/*				-checks if macro excists more than ones					*/
/*======================================================================*/
/*	This program distil all the SAS macro's that are in *.sas file in 	*/
/*	the &source= directory and the directories under this dir(recursion)*/
/*----------------------------------------------------------------------*/
/*	Meaning of:															*/
/*		source 	= 	path of the source directory 						*/
/*		olib 	=	library to where the macro's needs to be stored		*/
/*		opath	=	location of the &olib								*/
/*======================================================================*/

%let source=c:\sas_programs; /* blanks in the path should be properly escaped */
%let olib = source;
%let opath = c:\sas_programs\macro;

/* windows OS */
filename allpaths pipe "attrib /S /D &source.\*.sas";

data work.allpaths (keep=path);
	length path $200.;
	infile 	allpaths 
			length=l;
	input 	line 
			$varying350. 
			l; 
	if scan(upcase(line),-1,'.') eq "SAS" then do;
		path=substr(line,12);
		*last=scan(path,-1,'.');
		output;
	end;
run;

filename tt catalog "work.t.t.source";

data  control(keep=name);
	length path myinfile $ 300 name $30;
   set allpaths;
   infile a filevar=path filename=myinfile length=l end=done; 
   do while(not done);
		input line $varying350. l;
		file tt;
		retain start;
		if find(line,'%macro','i') then do;
			start+1;
			name=strip(scan(line,2," (;"));
			output control;
			put "/*PATH: " path "*/";
		end;
		if start then put line;
		if find(line,'%mend','i') then do;
			put ;
			start+(-1); 
		end;
   end;
run;

proc sort data=control;
	by name;
run;

data report;
	set control;
	by name;
	count+1;
	if last.name then do;
		output;
		count=0;
	end;
proc print;
	where count > 1;
run;

libname &olib "&opath";
options sasmstore=&olib mstored ;

%include tt;