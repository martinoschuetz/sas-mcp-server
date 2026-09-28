/* start a CAS session and assign the libnames */
options cashost="172.28.235.22" casport=5570;

cas mysess;
caslib _all_ assign;

libname mypublic cas sessref=mysess caslib=public;

data mypublic.segmentwerte_germsz;
	set mypublic.segmentwerte_9826(
		rename=(BANDNR=BANDNR2 PRODDATUM=PRODDATUM2 MEZUST_ID_BBS=MEZUST_ID_BBS2
				TAGESDATUM_BBS=TAGESDATUM_BBS2 EXTMENR=EXTMENR2));
run;

proc fedsql sessref=mysess;
	create table public.join_test as
	select t1.*, t2.*
		from public.EINMALWERTE_9826 t1
			inner join public.segmentwerte_germsz t2 on (t1.BANDNR = t2.BANDNR2);
quit;

proc casutil;
/*	promote casdata="SEGMENTWERTE_GERMSZ" incaslib="PUBLIC" outcaslib=PUBLIC casout="SEGMENTWERTE_GERMSZ";*/
	promote casdata="JOIN_TEST" incaslib="PUBLIC" outcaslib=PUBLIC casout="JOIN_TEST";
run; quit;

/*
proc casutil;
	droptable incaslib="public" casdata="SEGMENTWERTE_GERMSZ";
	droptable incaslib="public" casdata="join_test";
run; quit;
*/

cas mysess terminate;