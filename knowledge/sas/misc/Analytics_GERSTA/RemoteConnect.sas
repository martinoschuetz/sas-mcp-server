/* Lade SAS data sets für PRI von Windows nach Germanix hoch */
libname lokal "C:\pridaten";
%let sashost=germanix 2323;

options comamid=tcp;

filename script1 "C:\SAS\V8\connect\saslink\germanix.scr";
signon sashost script=script1;

  	rsubmit;
	libname fern "/sasdata/sas/8.2/pridata";
	proc upload
  		data=lokal.subgroup2_genealogy_node_idf 
  		out=fern.subgroup2_genealogy_node_idf;
	run;

	proc upload
  		data=lokal.subgroup2_genealogy_line_idf 
  		out=fern.subgroup2_genealogy_line_idf;
	run;

	proc upload
  		data=lokal.detail_cat_idf
  		out=fern.detail_cat_idf;
	run;

	proc upload
  		data=lokal.detail_cnt_idf_350
  		out=fern.detail_cnt_idf_350;
	run;

	proc upload
  		data=lokal.detail_cnt_idf_400
  		out=fern.detail_cnt_idf_400;
	run;

	proc upload
  		data=lokal.detail_cnt_idf_600
  		out=fern.detail_cnt_idf_600;
	run;

	proc upload
  		data=lokal.detail_cnt_idf_700
  		out=fern.detail_cnt_idf_700;
	run;


endrsubmit;
signoff;

/* Führe IDFs für kontinuierliche Daten zusammen */


libname lokal "C:\pridaten";
%let sashost=germanix 2323;

options comamid=tcp;

filename script1 "C:\SAS\V8\connect\saslink\germanix.scr";
signon sashost script=script1;

  	rsubmit;
	libname fern "/sasdata/sas/8.2/pridata";
    data fern.detail_cnt_idf;
	    set fern.detail_cnt_idf_350
		fern.detail_cnt_idf_400
		fern.detail_cnt_idf_600
		fern.detail_cnt_idf_700;
	run;

	
endrsubmit;
signoff;
