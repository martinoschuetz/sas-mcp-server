/********************* CREATE RENAME STATEMENT TO RENAME  VARIABLES THAT WILL BE TRANSPOSED ******************************/
%macro rename;
  rename=(
 %do i=1 %to &varcnt;
    char_&i._sum=&&t_&i
 %end;
 )
%mend rename; 
/********************* CREATE ARRAY INIT STATEMENT TO SET VARIABLES THAT WILL BE TRANSPOSED ******************************/
%macro init_array(arrayName, initVal=0);
  &arrayName := (
    %do i=1 %to &varcnt; &initVal %end;
    );
%mend;

/*****************************************************************************************************/
/*************************** hptrans macro parameters  ***********************************************/
/*****************************************************************************************************/
/*  Hlib = Hadoop library where the table to be transposed is located.                               */
/*  Dlib= HDSF or LASR library where the intermediary tables will reside during the macro execution. */
/*  Filein = Table to be transposed                                                                  */
/*  Fileout = Name of the final transposed table                                                     */
/*  By = Variable that is the key by which the transposition will be done                            */
/*  Id = Variable which discrete values will become the columns names in the transposed table.       */
/*  var= Variable which values will become the columns values in the transposed table.               */
/*****************************************************************************************************/

%macro hptrans(hlib,dlib,filein,fileout,by,id,var,target);

data _null_; 
   call symput('start',put(datetime(),datetime.));
run;

%put "Start Time = " &start.;

proc sql noprint;
select COMPRESS(substr(path,1,8)) into: lsr
from sashelp.vslib
where upcase(libname)=upcase("&dlib.");
quit;

proc hpsummary data= &hlib..&filein. nway;
performance details;
class &id. ;
var &var. ;
output out=work.id_list(drop=_type_ rename=(_freq_=N)) sum=;
run;

/**********  BUILD ONE MACRO VARIABLE FOR EACH VALUE OF THE ID VARIABLE TO BE TRANSPOSED IN A NUMBERED LIST ************/
data _null_; 
   set id_list(keep=&id.) end=_eof_; 
   call symput(cat('t_',compress(put(_n_,8.))),compress(cat('Char_',&id.))); 
   if _eof_=1 then call symput('varcnt',compress(put(_n_,8.))); 
run;

%put &t_1. - &&t_&varcnt..; 
%put &varcnt.;

/********************* CREATE FORMATS THAT BECOME THE TRANSPOSED VARIABLES NAME ******************************/

libname myxml XML92 xmltype=sasfmt tagset=tagsets.XMLsuv;

data fmt; 
   set id_list; 
   start=&id.; 
   label=_n_; 
   fmtname='$tfmt'; 
run; 

proc format cntlin=fmt; 
run;

/*** Export format library to xml  ***/
proc format cntlout=myxml.allfmts;
  select $tfmt;
run;

%let hdsfops=%str(blocksize=64m copies=1 replace=yes logupdate);
%if &lsr=SASLASR %then %do;
	%let hdsfops=;
%end;

proc datasets lib=&dlib.;
   delete temp_;
   delete temp_trans;
run;

proc hpds2 data=&hlib..&filein.
            out=&dlib..temp(partition=(&BY.) &hdsfops.) fmtlibxml=myxml;
			performance details;
			data ds2gtf.out(drop=(&id. &var. j i));
				vararray double traits [*] char_1 - char_&varcnt;
				method run();
				set ds2gtf.in;
					%init_array(traits);    
					traits[put(&id.,$tfmt.)+0]=&var.;
				end;
			enddata;
run;
quit; 

proc hpsummary data=&dlib..temp nway;
class &by. ;
var char_: &target.;
output out=&dlib..temp_trans(&hdsfops.) sum(char_:)=  max(&target.)=Target / autoname;
run;

proc hpds2 data=&dlib..temp_trans
            out=&hlib..&fileout.;
			performance details;
			data ds2gtf.out(drop=(_TYPE_ _FREQ_) 
							%RENAME 
							);
			  method run();
			    set ds2gtf.in;
			  end;
			enddata;
run;
quit;


proc datasets lib=&dlib.;
   delete temp_;
   delete temp_trans;
run;
quit;


data _null_; 
   call symput('endtime',put(datetime(),datetime.));
run;

%put "Start Time  = &start.";
%put "  End Time  = &endtime.";

%mend;
