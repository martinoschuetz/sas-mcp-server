/* ------------------------------------------------------------------------------ */
LIBNAME data BASE "d:\projekte\itergo\data";
LIBNAME dwork BASE "d:\projekte\itergo\work";
libname fmt "d:\projekte\itergo\data";


/* ------------------------------------------------------------------------------ */
%let inlib=data;
%let inds=miso_base_gesamt_utf8;
%let docdir=d:\projekte\itergo\doc;


/* ------------------------------------------------------------------------------ */
/* Size of sample */
%let numrecs=500000;
%let total=;

data dwork.random;
	drop i;
	do i=1 to &numrecs;
		select=round(ranuni(1022)*total,1);
		call symput('total',total);
		set &inlib..&inds. point=select nobs=total;
		if mod(i,10000)=0 then put i "/ &numrecs.";
		output;
	end;
	stop;
run;

data dwork.minisamp;
	set dwork.random(obs=1000);
run;


/* ------------------------------------------------------------------------------ */
/* separate char and num variables */
proc datasets library=&inlib. nolist;
	contents data=&inds. out=dwork..grpout;
run; quit;
data dwork.char(keep=name type length label format) dwork.num(keep=name type length label format);
	set dwork.grpout;
	if type=2 then output char;
	else output num;
run;

ods html body="&docdir.\varlist.html" style=statistical;
title "CHAR variables in &inlib..&inds. (&total. obs)";
proc print data=dwork.char noobs label; run;
title "NUM variables in &inlib..&inds. (&total. obs)";
proc print data=dwork.num noobs label; run;
ods html close;


/* ------------------------------------------------------------------------------ */
data dwork.results;
	attrib n 	label="# Values" format=commax12. 
		pct 	label="Spread in sample" format=percent9.2
		est 	label="Est. # Values in Total" format=commax12.
		name 	label="Value" length=$20
		type 	label="Value type" length=$20;
	stop;
run;


proc sql noprint;
	create table dwork.tmp as select name from dwork.num;
	select trim(name) into :num1-:num&sqlobs. from dwork.tmp;
quit;

%let N = &sqlobs;
%macro m;
proc sql noprint;
	%do i=1 %to &n.;
	select count(distinct &&num&i.) as n1,
		calculated n1 / &numrecs. as n2,
		(&total. / &numrecs.) * (calculated n1) into :n1, :n2, :n3 from dwork.random;
	insert into dwork.results values(&n1.,&n2.,&n3.,"&&num&i.","num");
	%end;
quit;
%mend;
%m;

proc sql noprint;
	create table dwork.tmp as select name from dwork.char;
	select trim(name) into :char1-:char&sqlobs. from dwork.tmp;
quit;

%let N = &sqlobs;
%macro m;
proc sql noprint;
	%do i=1 %to &n.;
	select count(distinct &&char&i.) as n1, 
		calculated n1 / &numrecs. as n2,
		(&total. / &numrecs.) * (calculated n1) into :n1, :n2, :n3 from dwork.random;
	insert into dwork.results values(&n1.,&n2.,&n3.,"&&char&i.","char");
	%end;
quit;
%mend;
%m;


/* ------------------------------------------------------------------------------ */
proc sort data=dwork.results;
	by descending pct;
run;

ods html body="&docdir.\sample.html" style=statistical;
title "Variable evaluation of &inlib..&inds. (&total. obs / &numrecs. obs in sample)";
proc print data=dwork.results label noobs;run;
ods html close;


/* ------------------------------------------------------------------------------ */
%macro mf(src,ds,fmtname);

data tmp;
	set &src.(keep=&ds.);
run;
proc sort data=tmp nodupkey out=dwork.&ds.(rename=(&ds.=label));
	by &ds.;
run;

data dwork.&ds.;
	set dwork.&ds.;
	attrib fmtname length=$10;
	start   = _n_;
	fmtname = strip("&fmtname.");
	type    = "n";
run;

data dwork.r_&ds.;
	set dwork.&ds.(rename=(start=label label=start));
	attrib fmtname length=$10;
	fmtname = strip("r&fmtname.");
	type    = "c";
run;

proc format lib=fmt cntlin=dwork.&ds.;
run;
proc format lib=fmt cntlin=dwork.r_&ds.;
run;

%mend mf;


/* ------------------------------------------------------------------------------ */
/* generate list of CHAR vars to transform into formats */
proc sql noprint;
	create table dwork.tmp as select * from dwork.results
		where pct < .1;
	create table dwork.char_tmp as
		select c.*, r.n, r.pct from
			dwork.char c, dwork.tmp r where c.name=r.name;
	select trim(name) into :charx1-:charx&sqlobs. from dwork.char_tmp;
quit;


/* generate datastep statements */
%macro m;

/* extract from base table */
%put data dwork.random2(keep=;

	%do i=1 %to &sqlobs.;
		%put &&charx&i.; 
	%end;

%put )%str(;);
%put set  dwork.random%str(;);
%put run%str(;);

%put;
%put;

/* macro statements */
	%do i=1 %to &sqlobs.;
		%put %NRBQUOTE(%)mf( dwork.random2, &&charx&i.,a&i.x )%str(;); 
	%end;

%put;
%put;

/* datastep */
%put data dwork.random3(drop=;
	%do i=1 %to &sqlobs.;
		%put   &&charx&i..N; 
	%end;
%put )%str(;);

%put set dwork.random(rename=(;
	%do i=1 %to &sqlobs.;
		%put   &&charx&i. = &&charx&i..N; 
	%end;
%put ))%str(;);

%put attrib;
	%do i=1 %to &sqlobs.;
		%put &&charx&i. length=8 format=a&i.x.;  
	%end;
%put %str(;);

	%do i=1 %to &sqlobs.;
		%put &&charx&i. = input(put(&&charx&i..N,ra&i.x.),best.)%str(;);
	%end;

%put run%str(;);
%mend;
%m;


/* ------------------------------------------------------------------------------ */
options fmtsearch=(fmt);


data dwork.random2(keep=
AUSG_OE_Ebene_1
AUSG_OE_Ebene_2
AUSG_OE_Ebene_3
AUSG_OE_Ebene_4
AUSG_OE_Ebene_5
AUSG_OE_Ebene_6
AUSG_OE_NR
AUSLOE_SL
DT_VERW_SYS_SL
EANTR_SL
EINGM_EBENE_2
EINGM_EBENE_3
EINGM_EBENE_6
EINGM_EBENE_4A
EINGM_EBENE_4B
EINGM_ID
EING_OE_Ebene_1
EING_OE_Ebene_2
EING_OE_Ebene_3
EING_OE_Ebene_4
EING_OE_Ebene_5
EING_OE_Ebene_6
EING_OE_NR
EINZ_OE_Ebene_1
EINZ_OE_Ebene_2
EINZ_OE_Ebene_3
EINZ_OE_Ebene_4
EINZ_OE_Ebene_5
EINZ_OE_Ebene_6
EINZ_OE_NR
ENTST_OE_Ebene_1
ENTST_OE_Ebene_2
ENTST_OE_Ebene_3
ENTST_OE_Ebene_4
ENTST_OE_Ebene_5
ENTST_OE_Ebene_6
ENTST_OE_NR
ERSTRKT_ART_SL
ERSTRKT_FINAL_KZ
ESIGN_SL
GEVO_EOM_AUSG
GEVO_EOM_EING
GEVO_EOM_Gruppe_AUSG
GEVO_EOM_Gruppe_EING
GT_VERW_SYS_SL
Hauptprozess_AUSG
Hauptprozess_EING
INDZ_KZ
INDZ_OE_Ebene_1
INDZ_OE_Ebene_2
INDZ_OE_Ebene_3
INDZ_OE_Ebene_4
INDZ_OE_Ebene_5
INDZ_OE_Ebene_6
INDZ_OE_NR
INVIT_MOD_SL
KS_OE
KU_BEITR_STS_SL
Kundengeschaeftsart
MASCH_INDZ_SL
NEU_ERS_GESCH_SL
OPAG_MASCH_AUSF_KZ
OPAG_SOFAUSF_KZ
POST_ART_EBENE_2
POST_ART_EBENE_3
POST_ART_SL
SCAN_OE_Ebene_1
SCAN_OE_Ebene_2
SCAN_OE_Ebene_3
SCAN_OE_Ebene_4
SCAN_OE_Ebene_5
SCAN_OE_Ebene_6
SCAN_OE_NR
Segment
Sparte
Spartendiff
Spartengruppe_1
Spartengruppe_2
Spartengruppe_3
Unterprozess_AUSG
Unterprozess_EING
VT_NAME
V_STS_SL
V_VERW_SYS_SL
);
set  dwork.random;
run;


%mf( dwork.random2, AUSG_OE_Ebene_1,a1x );
%mf( dwork.random2, AUSG_OE_Ebene_2,a2x );
%mf( dwork.random2, AUSG_OE_Ebene_3,a3x );
%mf( dwork.random2, AUSG_OE_Ebene_4,a4x );
%mf( dwork.random2, AUSG_OE_Ebene_5,a5x );
%mf( dwork.random2, AUSG_OE_Ebene_6,a6x );
%mf( dwork.random2, AUSG_OE_NR,a7x );
%mf( dwork.random2, AUSLOE_SL,a8x );
%mf( dwork.random2, DT_VERW_SYS_SL,a9x );
%mf( dwork.random2, EANTR_SL,a10x );
%mf( dwork.random2, EINGM_EBENE_2,a11x );
%mf( dwork.random2, EINGM_EBENE_3,a12x );
%mf( dwork.random2, EINGM_EBENE_6,a13x );
%mf( dwork.random2, EINGM_EBENE_4A,a14x );
%mf( dwork.random2, EINGM_EBENE_4B,a15x );
%mf( dwork.random2, EINGM_ID,a16x );
%mf( dwork.random2, EING_OE_Ebene_1,a17x );
%mf( dwork.random2, EING_OE_Ebene_2,a18x );
%mf( dwork.random2, EING_OE_Ebene_3,a19x );
%mf( dwork.random2, EING_OE_Ebene_4,a20x );
%mf( dwork.random2, EING_OE_Ebene_5,a21x );
%mf( dwork.random2, EING_OE_Ebene_6,a22x );
%mf( dwork.random2, EING_OE_NR,a23x );
%mf( dwork.random2, EINZ_OE_Ebene_1,a24x );
%mf( dwork.random2, EINZ_OE_Ebene_2,a25x );
%mf( dwork.random2, EINZ_OE_Ebene_3,a26x );
%mf( dwork.random2, EINZ_OE_Ebene_4,a27x );
%mf( dwork.random2, EINZ_OE_Ebene_5,a28x );
%mf( dwork.random2, EINZ_OE_Ebene_6,a29x );
%mf( dwork.random2, EINZ_OE_NR,a30x );
%mf( dwork.random2, ENTST_OE_Ebene_1,a31x );
%mf( dwork.random2, ENTST_OE_Ebene_2,a32x );
%mf( dwork.random2, ENTST_OE_Ebene_3,a33x );
%mf( dwork.random2, ENTST_OE_Ebene_4,a34x );
%mf( dwork.random2, ENTST_OE_Ebene_5,a35x );
%mf( dwork.random2, ENTST_OE_Ebene_6,a36x );
%mf( dwork.random2, ENTST_OE_NR,a37x );
%mf( dwork.random2, ERSTRKT_ART_SL,a38x );
%mf( dwork.random2, ERSTRKT_FINAL_KZ,a39x );
%mf( dwork.random2, ESIGN_SL,a40x );
%mf( dwork.random2, GEVO_EOM_AUSG,a41x );
%mf( dwork.random2, GEVO_EOM_EING,a42x );
%mf( dwork.random2, GEVO_EOM_Gruppe_AUSG,a43x );
%mf( dwork.random2, GEVO_EOM_Gruppe_EING,a44x );
%mf( dwork.random2, GT_VERW_SYS_SL,a45x );
%mf( dwork.random2, Hauptprozess_AUSG,a46x );
%mf( dwork.random2, Hauptprozess_EING,a47x );
%mf( dwork.random2, INDZ_KZ,a48x );
%mf( dwork.random2, INDZ_OE_Ebene_1,a49x );
%mf( dwork.random2, INDZ_OE_Ebene_2,a50x );
%mf( dwork.random2, INDZ_OE_Ebene_3,a51x );
%mf( dwork.random2, INDZ_OE_Ebene_4,a52x );
%mf( dwork.random2, INDZ_OE_Ebene_5,a53x );
%mf( dwork.random2, INDZ_OE_Ebene_6,a54x );
%mf( dwork.random2, INDZ_OE_NR,a55x );
%mf( dwork.random2, INVIT_MOD_SL,a56x );
%mf( dwork.random2, KS_OE,a57x );
%mf( dwork.random2, KU_BEITR_STS_SL,a58x );
%mf( dwork.random2, Kundengeschaeftsart,a59x );
%mf( dwork.random2, MASCH_INDZ_SL,a60x );
%mf( dwork.random2, NEU_ERS_GESCH_SL,a61x );
%mf( dwork.random2, OPAG_MASCH_AUSF_KZ,a62x );
%mf( dwork.random2, OPAG_SOFAUSF_KZ,a63x );
%mf( dwork.random2, POST_ART_EBENE_2,a64x );
%mf( dwork.random2, POST_ART_EBENE_3,a65x );
%mf( dwork.random2, POST_ART_SL,a66x );
%mf( dwork.random2, SCAN_OE_Ebene_1,a67x );
%mf( dwork.random2, SCAN_OE_Ebene_2,a68x );
%mf( dwork.random2, SCAN_OE_Ebene_3,a69x );
%mf( dwork.random2, SCAN_OE_Ebene_4,a70x );
%mf( dwork.random2, SCAN_OE_Ebene_5,a71x );
%mf( dwork.random2, SCAN_OE_Ebene_6,a72x );
%mf( dwork.random2, SCAN_OE_NR,a73x );
%mf( dwork.random2, Segment,a74x );
%mf( dwork.random2, Sparte,a75x );
%mf( dwork.random2, Spartendiff,a76x );
%mf( dwork.random2, Spartengruppe_1,a77x );
%mf( dwork.random2, Spartengruppe_2,a78x );
%mf( dwork.random2, Spartengruppe_3,a79x );
%mf( dwork.random2, Unterprozess_AUSG,a80x );
%mf( dwork.random2, Unterprozess_EING,a81x );
%mf( dwork.random2, VT_NAME,a82x );
%mf( dwork.random2, V_STS_SL,a83x );
%mf( dwork.random2, V_VERW_SYS_SL,a84x );


data dwork.random3(drop=
AUSG_OE_Ebene_1N
AUSG_OE_Ebene_2N
AUSG_OE_Ebene_3N
AUSG_OE_Ebene_4N
AUSG_OE_Ebene_5N
AUSG_OE_Ebene_6N
AUSG_OE_NRN
AUSLOE_SLN
DT_VERW_SYS_SLN
EANTR_SLN
EINGM_EBENE_2N
EINGM_EBENE_3N
EINGM_EBENE_6N
EINGM_EBENE_4AN
EINGM_EBENE_4BN
EINGM_IDN
EING_OE_Ebene_1N
EING_OE_Ebene_2N
EING_OE_Ebene_3N
EING_OE_Ebene_4N
EING_OE_Ebene_5N
EING_OE_Ebene_6N
EING_OE_NRN
EINZ_OE_Ebene_1N
EINZ_OE_Ebene_2N
EINZ_OE_Ebene_3N
EINZ_OE_Ebene_4N
EINZ_OE_Ebene_5N
EINZ_OE_Ebene_6N
EINZ_OE_NRN
ENTST_OE_Ebene_1N
ENTST_OE_Ebene_2N
ENTST_OE_Ebene_3N
ENTST_OE_Ebene_4N
ENTST_OE_Ebene_5N
ENTST_OE_Ebene_6N
ENTST_OE_NRN
ERSTRKT_ART_SLN
ERSTRKT_FINAL_KZN
ESIGN_SLN
GEVO_EOM_AUSGN
GEVO_EOM_EINGN
GEVO_EOM_Gruppe_AUSGN
GEVO_EOM_Gruppe_EINGN
GT_VERW_SYS_SLN
Hauptprozess_AUSGN
Hauptprozess_EINGN
INDZ_KZN
INDZ_OE_Ebene_1N
INDZ_OE_Ebene_2N
INDZ_OE_Ebene_3N
INDZ_OE_Ebene_4N
INDZ_OE_Ebene_5N
INDZ_OE_Ebene_6N
INDZ_OE_NRN
INVIT_MOD_SLN
KS_OEN
KU_BEITR_STS_SLN
KundengeschaeftsartN
MASCH_INDZ_SLN
NEU_ERS_GESCH_SLN
OPAG_MASCH_AUSF_KZN
OPAG_SOFAUSF_KZN
POST_ART_EBENE_2N
POST_ART_EBENE_3N
POST_ART_SLN
SCAN_OE_Ebene_1N
SCAN_OE_Ebene_2N
SCAN_OE_Ebene_3N
SCAN_OE_Ebene_4N
SCAN_OE_Ebene_5N
SCAN_OE_Ebene_6N
SCAN_OE_NRN
SegmentN
SparteN
SpartendiffN
Spartengruppe_1N
Spartengruppe_2N
Spartengruppe_3N
Unterprozess_AUSGN
Unterprozess_EINGN
VT_NAMEN
V_STS_SLN
V_VERW_SYS_SLN
);
set dwork.random(rename=(
AUSG_OE_Ebene_1 = AUSG_OE_Ebene_1N
AUSG_OE_Ebene_2 = AUSG_OE_Ebene_2N
AUSG_OE_Ebene_3 = AUSG_OE_Ebene_3N
AUSG_OE_Ebene_4 = AUSG_OE_Ebene_4N
AUSG_OE_Ebene_5 = AUSG_OE_Ebene_5N
AUSG_OE_Ebene_6 = AUSG_OE_Ebene_6N
AUSG_OE_NR = AUSG_OE_NRN
AUSLOE_SL = AUSLOE_SLN
DT_VERW_SYS_SL = DT_VERW_SYS_SLN
EANTR_SL = EANTR_SLN
EINGM_EBENE_2 = EINGM_EBENE_2N
EINGM_EBENE_3 = EINGM_EBENE_3N
EINGM_EBENE_6 = EINGM_EBENE_6N
EINGM_EBENE_4A = EINGM_EBENE_4AN
EINGM_EBENE_4B = EINGM_EBENE_4BN
EINGM_ID = EINGM_IDN
EING_OE_Ebene_1 = EING_OE_Ebene_1N
EING_OE_Ebene_2 = EING_OE_Ebene_2N
EING_OE_Ebene_3 = EING_OE_Ebene_3N
EING_OE_Ebene_4 = EING_OE_Ebene_4N
EING_OE_Ebene_5 = EING_OE_Ebene_5N
EING_OE_Ebene_6 = EING_OE_Ebene_6N
EING_OE_NR = EING_OE_NRN
EINZ_OE_Ebene_1 = EINZ_OE_Ebene_1N
EINZ_OE_Ebene_2 = EINZ_OE_Ebene_2N
EINZ_OE_Ebene_3 = EINZ_OE_Ebene_3N
EINZ_OE_Ebene_4 = EINZ_OE_Ebene_4N
EINZ_OE_Ebene_5 = EINZ_OE_Ebene_5N
EINZ_OE_Ebene_6 = EINZ_OE_Ebene_6N
EINZ_OE_NR = EINZ_OE_NRN
ENTST_OE_Ebene_1 = ENTST_OE_Ebene_1N
ENTST_OE_Ebene_2 = ENTST_OE_Ebene_2N
ENTST_OE_Ebene_3 = ENTST_OE_Ebene_3N
ENTST_OE_Ebene_4 = ENTST_OE_Ebene_4N
ENTST_OE_Ebene_5 = ENTST_OE_Ebene_5N
ENTST_OE_Ebene_6 = ENTST_OE_Ebene_6N
ENTST_OE_NR = ENTST_OE_NRN
ERSTRKT_ART_SL = ERSTRKT_ART_SLN
ERSTRKT_FINAL_KZ = ERSTRKT_FINAL_KZN
ESIGN_SL = ESIGN_SLN
GEVO_EOM_AUSG = GEVO_EOM_AUSGN
GEVO_EOM_EING = GEVO_EOM_EINGN
GEVO_EOM_Gruppe_AUSG = GEVO_EOM_Gruppe_AUSGN
GEVO_EOM_Gruppe_EING = GEVO_EOM_Gruppe_EINGN
GT_VERW_SYS_SL = GT_VERW_SYS_SLN
Hauptprozess_AUSG = Hauptprozess_AUSGN
Hauptprozess_EING = Hauptprozess_EINGN
INDZ_KZ = INDZ_KZN
INDZ_OE_Ebene_1 = INDZ_OE_Ebene_1N
INDZ_OE_Ebene_2 = INDZ_OE_Ebene_2N
INDZ_OE_Ebene_3 = INDZ_OE_Ebene_3N
INDZ_OE_Ebene_4 = INDZ_OE_Ebene_4N
INDZ_OE_Ebene_5 = INDZ_OE_Ebene_5N
INDZ_OE_Ebene_6 = INDZ_OE_Ebene_6N
INDZ_OE_NR = INDZ_OE_NRN
INVIT_MOD_SL = INVIT_MOD_SLN
KS_OE = KS_OEN
KU_BEITR_STS_SL = KU_BEITR_STS_SLN
Kundengeschaeftsart = KundengeschaeftsartN
MASCH_INDZ_SL = MASCH_INDZ_SLN
NEU_ERS_GESCH_SL = NEU_ERS_GESCH_SLN
OPAG_MASCH_AUSF_KZ = OPAG_MASCH_AUSF_KZN
OPAG_SOFAUSF_KZ = OPAG_SOFAUSF_KZN
POST_ART_EBENE_2 = POST_ART_EBENE_2N
POST_ART_EBENE_3 = POST_ART_EBENE_3N
POST_ART_SL = POST_ART_SLN
SCAN_OE_Ebene_1 = SCAN_OE_Ebene_1N
SCAN_OE_Ebene_2 = SCAN_OE_Ebene_2N
SCAN_OE_Ebene_3 = SCAN_OE_Ebene_3N
SCAN_OE_Ebene_4 = SCAN_OE_Ebene_4N
SCAN_OE_Ebene_5 = SCAN_OE_Ebene_5N
SCAN_OE_Ebene_6 = SCAN_OE_Ebene_6N
SCAN_OE_NR = SCAN_OE_NRN
Segment = SegmentN
Sparte = SparteN
Spartendiff = SpartendiffN
Spartengruppe_1 = Spartengruppe_1N
Spartengruppe_2 = Spartengruppe_2N
Spartengruppe_3 = Spartengruppe_3N
Unterprozess_AUSG = Unterprozess_AUSGN
Unterprozess_EING = Unterprozess_EINGN
VT_NAME = VT_NAMEN
V_STS_SL = V_STS_SLN
V_VERW_SYS_SL = V_VERW_SYS_SLN
));
attrib
AUSG_OE_Ebene_1 length=8 format=a1x.
AUSG_OE_Ebene_2 length=8 format=a2x.
AUSG_OE_Ebene_3 length=8 format=a3x.
AUSG_OE_Ebene_4 length=8 format=a4x.
AUSG_OE_Ebene_5 length=8 format=a5x.
AUSG_OE_Ebene_6 length=8 format=a6x.
AUSG_OE_NR length=8 format=a7x.
AUSLOE_SL length=8 format=a8x.
DT_VERW_SYS_SL length=8 format=a9x.
EANTR_SL length=8 format=a10x.
EINGM_EBENE_2 length=8 format=a11x.
EINGM_EBENE_3 length=8 format=a12x.
EINGM_EBENE_6 length=8 format=a13x.
EINGM_EBENE_4A length=8 format=a14x.
EINGM_EBENE_4B length=8 format=a15x.
EINGM_ID length=8 format=a16x.
EING_OE_Ebene_1 length=8 format=a17x.
EING_OE_Ebene_2 length=8 format=a18x.
EING_OE_Ebene_3 length=8 format=a19x.
EING_OE_Ebene_4 length=8 format=a20x.
EING_OE_Ebene_5 length=8 format=a21x.
EING_OE_Ebene_6 length=8 format=a22x.
EING_OE_NR length=8 format=a23x.
EINZ_OE_Ebene_1 length=8 format=a24x.
EINZ_OE_Ebene_2 length=8 format=a25x.
EINZ_OE_Ebene_3 length=8 format=a26x.
EINZ_OE_Ebene_4 length=8 format=a27x.
EINZ_OE_Ebene_5 length=8 format=a28x.
EINZ_OE_Ebene_6 length=8 format=a29x.
EINZ_OE_NR length=8 format=a30x.
ENTST_OE_Ebene_1 length=8 format=a31x.
ENTST_OE_Ebene_2 length=8 format=a32x.
ENTST_OE_Ebene_3 length=8 format=a33x.
ENTST_OE_Ebene_4 length=8 format=a34x.
ENTST_OE_Ebene_5 length=8 format=a35x.
ENTST_OE_Ebene_6 length=8 format=a36x.
ENTST_OE_NR length=8 format=a37x.
ERSTRKT_ART_SL length=8 format=a38x.
ERSTRKT_FINAL_KZ length=8 format=a39x.
ESIGN_SL length=8 format=a40x.
GEVO_EOM_AUSG length=8 format=a41x.
GEVO_EOM_EING length=8 format=a42x.
GEVO_EOM_Gruppe_AUSG length=8 format=a43x.
GEVO_EOM_Gruppe_EING length=8 format=a44x.
GT_VERW_SYS_SL length=8 format=a45x.
Hauptprozess_AUSG length=8 format=a46x.
Hauptprozess_EING length=8 format=a47x.
INDZ_KZ length=8 format=a48x.
INDZ_OE_Ebene_1 length=8 format=a49x.
INDZ_OE_Ebene_2 length=8 format=a50x.
INDZ_OE_Ebene_3 length=8 format=a51x.
INDZ_OE_Ebene_4 length=8 format=a52x.
INDZ_OE_Ebene_5 length=8 format=a53x.
INDZ_OE_Ebene_6 length=8 format=a54x.
INDZ_OE_NR length=8 format=a55x.
INVIT_MOD_SL length=8 format=a56x.
KS_OE length=8 format=a57x.
KU_BEITR_STS_SL length=8 format=a58x.
Kundengeschaeftsart length=8 format=a59x.
MASCH_INDZ_SL length=8 format=a60x.
NEU_ERS_GESCH_SL length=8 format=a61x.
OPAG_MASCH_AUSF_KZ length=8 format=a62x.
OPAG_SOFAUSF_KZ length=8 format=a63x.
POST_ART_EBENE_2 length=8 format=a64x.
POST_ART_EBENE_3 length=8 format=a65x.
POST_ART_SL length=8 format=a66x.
SCAN_OE_Ebene_1 length=8 format=a67x.
SCAN_OE_Ebene_2 length=8 format=a68x.
SCAN_OE_Ebene_3 length=8 format=a69x.
SCAN_OE_Ebene_4 length=8 format=a70x.
SCAN_OE_Ebene_5 length=8 format=a71x.
SCAN_OE_Ebene_6 length=8 format=a72x.
SCAN_OE_NR length=8 format=a73x.
Segment length=8 format=a74x.
Sparte length=8 format=a75x.
Spartendiff length=8 format=a76x.
Spartengruppe_1 length=8 format=a77x.
Spartengruppe_2 length=8 format=a78x.
Spartengruppe_3 length=8 format=a79x.
Unterprozess_AUSG length=8 format=a80x.
Unterprozess_EING length=8 format=a81x.
VT_NAME length=8 format=a82x.
V_STS_SL length=8 format=a83x.
V_VERW_SYS_SL length=8 format=a84x.
;
AUSG_OE_Ebene_1 = input(put(AUSG_OE_Ebene_1N,ra1x.),best.);
AUSG_OE_Ebene_2 = input(put(AUSG_OE_Ebene_2N,ra2x.),best.);
AUSG_OE_Ebene_3 = input(put(AUSG_OE_Ebene_3N,ra3x.),best.);
AUSG_OE_Ebene_4 = input(put(AUSG_OE_Ebene_4N,ra4x.),best.);
AUSG_OE_Ebene_5 = input(put(AUSG_OE_Ebene_5N,ra5x.),best.);
AUSG_OE_Ebene_6 = input(put(AUSG_OE_Ebene_6N,ra6x.),best.);
AUSG_OE_NR = input(put(AUSG_OE_NRN,ra7x.),best.);
AUSLOE_SL = input(put(AUSLOE_SLN,ra8x.),best.);
DT_VERW_SYS_SL = input(put(DT_VERW_SYS_SLN,ra9x.),best.);
EANTR_SL = input(put(EANTR_SLN,ra10x.),best.);
EINGM_EBENE_2 = input(put(EINGM_EBENE_2N,ra11x.),best.);
EINGM_EBENE_3 = input(put(EINGM_EBENE_3N,ra12x.),best.);
EINGM_EBENE_6 = input(put(EINGM_EBENE_6N,ra13x.),best.);
EINGM_EBENE_4A = input(put(EINGM_EBENE_4AN,ra14x.),best.);
EINGM_EBENE_4B = input(put(EINGM_EBENE_4BN,ra15x.),best.);
EINGM_ID = input(put(EINGM_IDN,ra16x.),best.);
EING_OE_Ebene_1 = input(put(EING_OE_Ebene_1N,ra17x.),best.);
EING_OE_Ebene_2 = input(put(EING_OE_Ebene_2N,ra18x.),best.);
EING_OE_Ebene_3 = input(put(EING_OE_Ebene_3N,ra19x.),best.);
EING_OE_Ebene_4 = input(put(EING_OE_Ebene_4N,ra20x.),best.);
EING_OE_Ebene_5 = input(put(EING_OE_Ebene_5N,ra21x.),best.);
EING_OE_Ebene_6 = input(put(EING_OE_Ebene_6N,ra22x.),best.);
EING_OE_NR = input(put(EING_OE_NRN,ra23x.),best.);
EINZ_OE_Ebene_1 = input(put(EINZ_OE_Ebene_1N,ra24x.),best.);
EINZ_OE_Ebene_2 = input(put(EINZ_OE_Ebene_2N,ra25x.),best.);
EINZ_OE_Ebene_3 = input(put(EINZ_OE_Ebene_3N,ra26x.),best.);
EINZ_OE_Ebene_4 = input(put(EINZ_OE_Ebene_4N,ra27x.),best.);
EINZ_OE_Ebene_5 = input(put(EINZ_OE_Ebene_5N,ra28x.),best.);
EINZ_OE_Ebene_6 = input(put(EINZ_OE_Ebene_6N,ra29x.),best.);
EINZ_OE_NR = input(put(EINZ_OE_NRN,ra30x.),best.);
ENTST_OE_Ebene_1 = input(put(ENTST_OE_Ebene_1N,ra31x.),best.);
ENTST_OE_Ebene_2 = input(put(ENTST_OE_Ebene_2N,ra32x.),best.);
ENTST_OE_Ebene_3 = input(put(ENTST_OE_Ebene_3N,ra33x.),best.);
ENTST_OE_Ebene_4 = input(put(ENTST_OE_Ebene_4N,ra34x.),best.);
ENTST_OE_Ebene_5 = input(put(ENTST_OE_Ebene_5N,ra35x.),best.);
ENTST_OE_Ebene_6 = input(put(ENTST_OE_Ebene_6N,ra36x.),best.);
ENTST_OE_NR = input(put(ENTST_OE_NRN,ra37x.),best.);
ERSTRKT_ART_SL = input(put(ERSTRKT_ART_SLN,ra38x.),best.);
ERSTRKT_FINAL_KZ = input(put(ERSTRKT_FINAL_KZN,ra39x.),best.);
ESIGN_SL = input(put(ESIGN_SLN,ra40x.),best.);
GEVO_EOM_AUSG = input(put(GEVO_EOM_AUSGN,ra41x.),best.);
GEVO_EOM_EING = input(put(GEVO_EOM_EINGN,ra42x.),best.);
GEVO_EOM_Gruppe_AUSG = input(put(GEVO_EOM_Gruppe_AUSGN,ra43x.),best.);
GEVO_EOM_Gruppe_EING = input(put(GEVO_EOM_Gruppe_EINGN,ra44x.),best.);
GT_VERW_SYS_SL = input(put(GT_VERW_SYS_SLN,ra45x.),best.);
Hauptprozess_AUSG = input(put(Hauptprozess_AUSGN,ra46x.),best.);
Hauptprozess_EING = input(put(Hauptprozess_EINGN,ra47x.),best.);
INDZ_KZ = input(put(INDZ_KZN,ra48x.),best.);
INDZ_OE_Ebene_1 = input(put(INDZ_OE_Ebene_1N,ra49x.),best.);
INDZ_OE_Ebene_2 = input(put(INDZ_OE_Ebene_2N,ra50x.),best.);
INDZ_OE_Ebene_3 = input(put(INDZ_OE_Ebene_3N,ra51x.),best.);
INDZ_OE_Ebene_4 = input(put(INDZ_OE_Ebene_4N,ra52x.),best.);
INDZ_OE_Ebene_5 = input(put(INDZ_OE_Ebene_5N,ra53x.),best.);
INDZ_OE_Ebene_6 = input(put(INDZ_OE_Ebene_6N,ra54x.),best.);
INDZ_OE_NR = input(put(INDZ_OE_NRN,ra55x.),best.);
INVIT_MOD_SL = input(put(INVIT_MOD_SLN,ra56x.),best.);
KS_OE = input(put(KS_OEN,ra57x.),best.);
KU_BEITR_STS_SL = input(put(KU_BEITR_STS_SLN,ra58x.),best.);
Kundengeschaeftsart = input(put(KundengeschaeftsartN,ra59x.),best.);
MASCH_INDZ_SL = input(put(MASCH_INDZ_SLN,ra60x.),best.);
NEU_ERS_GESCH_SL = input(put(NEU_ERS_GESCH_SLN,ra61x.),best.);
OPAG_MASCH_AUSF_KZ = input(put(OPAG_MASCH_AUSF_KZN,ra62x.),best.);
OPAG_SOFAUSF_KZ = input(put(OPAG_SOFAUSF_KZN,ra63x.),best.);
POST_ART_EBENE_2 = input(put(POST_ART_EBENE_2N,ra64x.),best.);
POST_ART_EBENE_3 = input(put(POST_ART_EBENE_3N,ra65x.),best.);
POST_ART_SL = input(put(POST_ART_SLN,ra66x.),best.);
SCAN_OE_Ebene_1 = input(put(SCAN_OE_Ebene_1N,ra67x.),best.);
SCAN_OE_Ebene_2 = input(put(SCAN_OE_Ebene_2N,ra68x.),best.);
SCAN_OE_Ebene_3 = input(put(SCAN_OE_Ebene_3N,ra69x.),best.);
SCAN_OE_Ebene_4 = input(put(SCAN_OE_Ebene_4N,ra70x.),best.);
SCAN_OE_Ebene_5 = input(put(SCAN_OE_Ebene_5N,ra71x.),best.);
SCAN_OE_Ebene_6 = input(put(SCAN_OE_Ebene_6N,ra72x.),best.);
SCAN_OE_NR = input(put(SCAN_OE_NRN,ra73x.),best.);
Segment = input(put(SegmentN,ra74x.),best.);
Sparte = input(put(SparteN,ra75x.),best.);
Spartendiff = input(put(SpartendiffN,ra76x.),best.);
Spartengruppe_1 = input(put(Spartengruppe_1N,ra77x.),best.);
Spartengruppe_2 = input(put(Spartengruppe_2N,ra78x.),best.);
Spartengruppe_3 = input(put(Spartengruppe_3N,ra79x.),best.);
Unterprozess_AUSG = input(put(Unterprozess_AUSGN,ra80x.),best.);
Unterprozess_EING = input(put(Unterprozess_EINGN,ra81x.),best.);
VT_NAME = input(put(VT_NAMEN,ra82x.),best.);
V_STS_SL = input(put(V_STS_SLN,ra83x.),best.);
V_VERW_SYS_SL = input(put(V_VERW_SYS_SLN,ra84x.),best.);
run;

