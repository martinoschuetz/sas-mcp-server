* 1. Tabelle anschauen, Struktur verstehen;
proc print data=sampsio.assocs(obs=100); run;

* 2. Eindeutige Texte mit ihrer Länge bereitstellen;
proc sql;
	create table Text_nodup as
		select distinct(strip(product)) as product, length(strip(product)) as length from sampsio.assocs
			order by product;
quit;

* 3. Minimal notwendige Textlänge bestimmen;
proc sql noprint;
	select max(length) into : Length from text_nodup;
quit;

%put &=length.;

* 4. Minimal notwendige Textlänge anwenden, "start", "type" und "label" Variable für CNTLIN DS des Formats Text2Num bereitstellen für;
data Text2Num;
	Retain fmtname '$Text2Num' type 'c';
	Length start $&length. label 8;
	set Text_nodup(rename=(product=start));
	label+1;
run;

*Übersetzung mit Format: Text=>Zahl;
proc format cntlin=Text2Num; run;

* 5. "start", "type", "end" und "label" Variable für CNTLIN DS des Formats Num2Text bereitstellen;
data Num2Text(drop=v1 v2);
	set Text2Num(rename=(start=v2 label=v1) drop=type  );
	fmtname='Num2Text';
	start=v1;
	end=v1;
	label=v2;
	type='n';
run;

*Übersetzung mit Format: Zahl=>Text;
proc format cntlin=Num2Text; run;

* 6. Beide Formate auf den Daten anwenden, Übersetzung Text=>Zahl und Rückübersetzung Zahl=>Text;
data assocsfmt;
	length product Product_ $&length.;
	set sampsio.assocs;
	product_no=Product;
	format Product_no $Text2Num.;
	Product_no_Zahl=0;
	Product_no_Zahl=put(product,$Text2Num.);
	Product_=put(Product_no_Zahl,Num2Text.);
run;

proc print data=assocsfmt(obs=100); run;

* 7. Formatdefinitionen ausgeben und ansehen;
PROC FORMAT CNTLOUT=fmtout; RUN;

PROC PRINT DATA=fmtout; RUN;