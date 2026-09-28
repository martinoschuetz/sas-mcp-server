/*
	scrds 	 - Input-Dataset
	outds 	 - Namen der Tabelle, die die optimalen Feldlängen enthält
	outsrcds - Name der neuen Ausgabetabelle
	dir		 - Verzeichnisname für den HTML-Output
	creatertf - Erzeugen von RTF = 1 an Stelle von HTML
	ignorefreqvar - Variablen, z.B. ID, die beim Frequency-Count zu ignorieren sind.

	Das Makro macht eine proc freq auf allen Spalten und generiert ein output dataset,
	in dem es die aktuellen Feldlängen auflistet und vorschläge macht,
	welche Feldlängen ausreichend wären.
	Das bekommst man auch als HTML report (dafür ist die verzeichnisangabe gedacht – dort liegt dann das html).
	Ich habe einen datastep eingebaut, der automatisch das input dataset in eine ausgabetabelle kopiert
	und dabei aber die optimalen feldlängen aller char variablen zugrundelegt.
	Test: sashelp.class und Vergleich der Feldlängen der SEX und der NAME variablen in CLASS und in NEWCLASS.
	Wegen dem proc freq solltest man ggf nur ein sample der inputdaten in das makro reingeben.

	numeric variable length and precision
	3     8192 
	4     2097152 
	5     536870912 
	6     137438953472 
	7     35184372088832 
	8     9007199254740992 

options mprint;
*/

%macro shorten_columns(srcds,outds,outsrcds,dir,creatertf,ignorefreqvar);
      %let numobs=1;
      %let i=1;

      ods listing close;
      proc contents data=&srcds. out=tmp noprint;
      run;

      proc sql noprint;
            select trim(left(input(put(count(*),3.),$3.))) into :numobs from tmp;
            select name, type, length into :var1 - :var&numobs., :type1 - :type&numobs.,
                  :length1 - :length&numobs. from tmp;
            drop table &outds.;
            create table &outds.(
                  alert char(1) label="Variable too small?",
                  name char(40) label="Variable Name",
                  type num(4)   label="Variable Type",
                  orgl num(4)   label="Defined Length",
                  propl num(4)  label="Proposed Length",
                  minl num(8)   label="Current Min Length/Value",
                  maxl num(8)   label="Current Max Length/Value"
            );
      quit;

      %do i=1 %to &numobs.;
            %if "&&type&i." = "1" %then %do;
                  %put Processing numerical variable &&var&i.;
                  proc sql noprint;
                        select min(&&var&i.), max(&&var&i.) into :minl, :maxl
                             from &srcds.;
                  quit;
                  %let propl = 8;
                  %if &maxl. < 35184372088832 %then %let propl = 7;
                  %if &maxl. < 137438953472 %then %let propl = 6;
                  %if &maxl. < 536870912 %then %let propl = 5;
                  %if &maxl. < 2097152 %then %let propl = 4;
                  %if &maxl. < 8192 %then %let propl = 3;

                  proc sql noprint;
                        insert into &outds.(name, type, orgl, propl, minl, maxl, alert)
                             values("&&var&i.",&&type&i.,&&length&i.,&propl., &minl.,&maxl.,"");
                  quit;
            %end; %else %do;
                  %put Processing character variable &&var&i.;
                  proc sql noprint;
                        select min(length(&&var&i.)), max(length(&&var&i.)) into :minl, :maxl
                             from &srcds.;
                        insert into &outds.(name, type, orgl, propl, minl, maxl, alert)
                              values("&&var&i.",&&type&i.,&&length&i.,&maxl.,&minl.,&maxl., "");
                        update &outds. set alert="#" where orgl=propl;
                  quit;
            %end;
      %end;

      %let hndDS=%sysfunc(open(&outds.,I));
      %syscall set(hndDS);

      data &outsrcds.;
      %do %while(%sysevalf(%sysfunc(fetch(&hndDS))=0));
            %let ctype=%sysfunc(getvarn(&hndDS,%sysfunc(varnum(&hndDS,type))));
            %if &ctype = 2 %then %do;
                  %let cname=%sysfunc(getvarc(&hndDS,%sysfunc(varnum(&hndDS,name))));
                  %let clen =%sysfunc(getvarn(&hndDS,%sysfunc(varnum(&hndDS,propl))));
                  attrib &cname. length=$&clen.;
            %end;
      %end;
            set &srcds.;
      run;

      %let rc=%sysfunc(close(&hndDS));


      %if &creatertf. = 1 %then %do;
      ods rtf file="&dir.\&srcds..rtf" style=journal;
      %end;
      ods html file="&dir.\&srcds..html" style=journal;

      title "Overall Description of &srcds.";
      proc contents data=&srcds.;
      run;

      title "Frequencies for &srcds.";
      proc freq data=&srcds.(drop=&ignorefreqvar.);
      run;

      title "Calculated Column sizes of &srcds.";
      proc print data=&outds. noobs label;
            var alert name type orgl propl minl maxl;
      run;

      ods _all_ close;
      ods listing;

%mend;

%shorten_columns(sashelp.class, work.results, work.newclass, c:\temp);

