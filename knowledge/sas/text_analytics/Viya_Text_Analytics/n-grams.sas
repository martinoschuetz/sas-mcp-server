options cashost="sfr-plva-c2n1.sas.amsiohosting.net" casport=5570;

/*1*/
cas casauto;
libname mycas cas;
caslib _all_ assign;

data sample;
	set casuser.data1_jd(datalimit=all keep=id ERROR_DESCRIPTION 
		where=(find(error_description, 'gril', 'i')+find(error_description, 'haube', 
		'i') gt 0));
run;

*Parsing (1-gramme) normalization in lowcase;
data out(keep=id pos term);
	length Term $30.;
	set sample;
	n+1;

	do pos=1 to 1000;
		term=compress(lowcase(strip(scan(ERROR_DESCRIPTION, pos, ' ,.:;-'))), , 'Ka');
		call symputx("NumDocs", n);

		if term not in ('', ' ') and anydigit(term) eq 0 then
			output;
	end;
run;

%put &=NumDocs.;

*Doc Frequency;
proc sql;
	create table term1 as select distinct term, count(id) as NumDocs, 
		count(id)/&NumDocs.*100 as NumDocsPC from out group by term;
quit;

*Term Frequency;
proc freq noprint data=out;
	tables term/out=term2(rename=(count=Termfreq percent=TermPC));
run;

* %dqload(dqlocale=(DEDEU));
%dqload(dqlocale=(ENUSA));
%DQPUTLOC;

data term3;
	merge term1 term2;
	by term;
	Length=Length(Term);
	Soundex=Soundex(Term);
	MCT50=dqMatch(term, 'TEXT', 50, 'ENUSA');
	MCT60=dqMatch(term, 'TEXT', 60, 'ENUSA');
	MCT70=dqMatch(term, 'TEXT', 70, 'ENUSA');
	MCT80=dqMatch(term, 'TEXT', 80, 'ENUSA');
	MCT90=dqMatch(term, 'TEXT', 90, 'ENUSA');
run;

*Synonym_Candidates based on Spelling Distance SPEDIS;
proc sql;
	create table Synonym_Candidates as
		select l.*, r.*, 
			(SoundexL eq SoundexR) as Soundex,
			spedis(termL,termR)+spedis(termR,termL) as spedis,
			COMPLEV(termL,termR) as COMPLEV,
			COMPGED(termL,termR) as COMPGED
		from term3(rename=(Term=TermL Termfreq=TermfreqL TermPC=TermPCL NumDocs=NumDocsL NumDocsPC=NumDocsPCL Length=LengthL soundex=SoundexL MCT50=MCT50L MCT60=MCT60L MCT70=MCT70L MCT80=MCT80L MCT90=MCT90L)) as l, 
			term3(rename=(Term=TermR Termfreq=TermfreqR TermPC=TermPCR NumDocs=NumDocsR NumDocsPC=NumDocsPCR Length=LengthR soundex=SoundexR MCT50=MCT50R MCT60=MCT60R MCT70=MCT70R MCT80=MCT80R MCT90=MCT90R)) as r
		where (spedis(termL,termR)+spedis(termR,termL)) le 40 and MCT50L eq MCT50R
			and terml ne termr 
			and NumDocsL ge NumDocsR and TermfreqL ge TermfreqR
		order by l.termL, r.termR;
quit;

ods graphics /width=300 height=300;
ods layout gridded columns=2;
ods region column=1;

	proc sgplot data=Synonym_Candidates;
		histogram spedis;
	run;

ods region column=2;

	proc sgplot data=Synonym_Candidates;
		histogram soundex;
	run;

ods region column=1;

	proc sgplot data=Synonym_Candidates;
		histogram COMPLEV;
	run;

ods region column=2;

	proc sgplot data=Synonym_Candidates;
		histogram COMPGED;
	run;

ods layout end;

data candidates(keep=term);
	set Synonym_Candidates(rename=(termL=Term)) 
		Synonym_Candidates(rename=(termR=Term));
run;

proc sort nodupkey;
	by term;
run;

*Alle Terms mit allen Candidates subsetten;
proc sql;
	create table term4 as
		select l.*,r.*
			from term3 as l, Candidates as r
				where l.term eq r.Term
					order by MCT50,  NumDocs desc ,  TermFreq desc;
quit;

*Pragmatische Synonymerstellung nach MCT50 ,häuffigster Term wird Parent;
*Hier ist dringen Manueller Review der Synonyme erforderlich;
*"dirty" Shortcut für heute Parameter willkürlich gewählt;
data synonym;
	retain Parent Term NumDocs FermFreq Length Soundex MCT50 MCT60 MCT70 MCT80 MCT90;
	set term4;
	by mct50;

	if first.mct50 then
		Parent=term;

	if strip(term) ne strip(parent);
run;

*Korrigierte und ausführlich manuell reviewte und mit Kunden abgestimmte  Synonymliste anwenden;
proc sql;
	create table out_ as
		select l.*,r.*
			from out as l, synonym as r
				where l.Term eq r.Term
					order by id, pos;
Quit;

proc sort data= out;
	by id pos;
run;

*Out1 hat im Term schon die Parents überschrieben;
data out1(keep=term Parent id pos Original_term);
	merge  out_ out;
	by id pos;

	if parent ne '' then
		do;
			Original_term=Term;
			Term=Parent;
		end;
run;

********************************************


Ngramme on Parents;

*1-gramme;
proc summary  nway noprint data=out1;
	class Term:;
	var id;
	output out=NGramm1(rename=(term=Term1 ) drop=_type_ id) mean= n=;
run;
;
*2-gramme;
proc sql;
	create table out2 as
		select a.*, b.*
			from out1(rename=(term=term1)) as a,out1(rename=(term=term2 pos=pos2)) as b
				where a.id eq b.id and a.pos eq b.pos2-1
					order by id,pos;
quit;

proc summary  nway noprint data=out2;
	class Term:;
	var id;
	output out=NGramm2(drop=_type_ id) mean= n=;
run;

*3-gramme;
proc sql;
	create table out3 as
		select a.*, b.*,c.*
			from out1(rename=(term=term1)) as a,
				out1(rename=(term=term2 pos=pos2)) as b,
				out1(rename=(term=term3 pos=pos3)) as c
			where a.id eq b.id and b.id eq c.id 
				and a.pos eq b.pos2-1 and b.pos2 eq c.pos3-1
			order by id,pos;
quit;

proc summary  nway noprint data=out3;
	class Term:;
	var id;
	output out=NGramm3(drop=_type_ id) mean= n=;
run;

*4-gramme;
proc sql;
	create table out4 as
		select a.*, b.*,c.*,d.*
			from out1(rename=(term=term1)) as a,
				out1(rename=(term=term2 pos=pos2)) as b,
				out1(rename=(term=term3 pos=pos3)) as c,
				out1(rename=(term=term4 pos=pos4)) as d
			where a.id eq b.id and b.id eq c.id and c.id eq d.id  
				and a.pos eq b.pos2-1 and b.pos2 eq c.pos3-1 and c.pos3 eq d.pos4-1
			order by id,pos;
quit;

proc summary  nway noprint data=out4;
	class Term:;
	var id;
	output out=NGramm4(drop=_type_ id) mean= n=;
run;

*5-gramme;
proc sql;
	create table out5 as
		select a.*, b.*,c.*,d.*,e.*
			from out1(rename=(term=term1)) as a,
				out1(rename=(term=term2 pos=pos2)) as b,
				out1(rename=(term=term3 pos=pos3)) as c,
				out1(rename=(term=term4 pos=pos4)) as d,
				out1(rename=(term=term5 pos=pos5)) as e
			where a.id eq b.id and b.id eq c.id and c.id eq d.id and d.id eq e.id  
				and a.pos eq b.pos2-1 and b.pos2 eq c.pos3-1 and c.pos3 eq d.pos4-1 and d.pos4 eq e.pos5-1
			order by id,pos;
quit;

proc summary  nway noprint data=out5;
	class Term:;
	var id;
	output out=NGramm5(drop=_type_ id) mean= n=;
run;

data ngramme_stack(where=(_freq_ gt 1));
	set Ngramm1 Ngramm2 Ngramm3 Ngramm4 Ngramm5 indsname=name;
	dim=substr(reverse(strip(name)),1,1);
run;

proc sort;
	by term1 term2 term3 term4;
run;

data Ngramme_concat;
	merge Ngramm1(rename=(_freq_=Freq1)) Ngramm2(rename=(_freq_=Freq2));
	by Term1;
run;

data Ngramme_concat;
	merge Ngramme_concat Ngramm3(rename=(_freq_=Freq3));
	by Term1 Term2;
run;

data Ngramme_concat;
	merge Ngramme_concat Ngramm4(rename=(_freq_=Freq4));
	by Term1 Term2 Term3;
run;

data Ngramme_concat;
	merge Ngramme_concat Ngramm5(rename=(_freq_=Freq5));
	by Term1 Term2 Term3 Term4;
run;

proc casutil;
	load data=work.Ngramme_concat outcaslib="casuser"
		casout="Ngramme_concat" promote;
run;