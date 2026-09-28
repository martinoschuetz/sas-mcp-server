data test1; 
length var1 var2 8 var3 var4 $10;
run;

data test2; 
length var1 var2 8 var3 var4 $10;
run;

data test3; 
length var1 var2 8 var3 var4 $10;
run;

data labels;
	tabname="test1" ; varname="var1";  varlabel="Dies ist das schöne Label von Var1"; output;
	tabname="test1" ; varname="var2";  varlabel="Dies ist das schöne Label von Var2"; output;
	tabname="test1" ; varname="var3";  varlabel="Dies ist das schöne Label von Var3"; output;
	tabname="test1" ; varname="var4";  varlabel="Dies ist das schöne Label von Var4"; output;

	tabname="test2" ; varname="var1";  varlabel="Dies ist das tolle Label von Var1"; output;
	tabname="test2" ; varname="var2";  varlabel="Dies ist das tolle Label von Var2"; output;
	tabname="test2" ; varname="var3";  varlabel="Dies ist das tolle Label von Var3"; output;
	tabname="test2" ; varname="var4";  varlabel="Dies ist das tolle Label von Var4"; output;

	tabname="test3" ; varname="var1";  varlabel="Dies ist das coole Label von Var1"; output;
	tabname="test3" ; varname="var2";  varlabel="Dies ist das coole Label von Var2"; output;
	tabname="test3" ; varname="var3";  varlabel="Dies ist das coole Label von Var3"; output;
	tabname="test3" ; varname="var4";  varlabel="Dies ist das coole Label von Var4"; output;

run;

proc sql;
	create table tables as 
		select distinct tabname from labels;
	select count(*) into :imax from tables;
quit;

data tables2;
	set tables;
	retain i;
	i+1;
run;

%macro x;
	/* Schleife über alle Tabellen */
	%do i=1 %to &imax.;

		proc sql noprint;
			select tabname into :tabname from tables2 where i=&i.;
			create table varlabels as 
				select * from labels 
					where tabname ="&tabname.";
			select count(*) into :jmax from varlabels;
		quit;

		data varlabels2;
			set varlabels;
			retain j;
			j+1;
		run;

		/* Schleife über alle Variablen in der jeweiligen Tabelle */
		%do j=1 %to &jmax.;

			proc sql noprint;
				SELECT VARNAME, VARLABEL into :varname, :varlabel FROM VARLABELS2 
					where j=&j.;
				alter table &tabname. modify &varname. label="&varlabel.";
			quit;

		%end;
	%end;
%mend;

%x

proc sql;
describe table test1, test2, test3;
quit;