libname mafo "C:\DATEN\REWE\2015";
proc format lib=mafo.myformats ;
   value fbrand 1="Marke A"
                2="Marke B"
			    3="Marke C"
			    4="Marke D"
			    5="Marke E"
			    6="Marke F";
   value fimage 1="ja"
                0="nein";
   value fsex 1="Weiblich"
              2="Männlich";
   value fsat 1="Überhaupt nicht zufrieden"
                       2="Eher nicht zufrieden"
                       3="Weder noch"
                       4="Eher zufrieden"
                       5="Voll und ganz zufrieden";
   value fage 1="18-25 Jahre"
              2="26-35 Jahre"
			  3="36-45 Jahre"
			  4="46-65 Jahre";
   value fregion 1="Nielsen I"
                 2="Nielsen II"
				 3="Nielsen IIIa"
				 4="Nielsen IIIb"
				 5="Nielsen IV"
				 6="Nielsen V"
				 7="Nielsen VI"
				 8="Nielsen VII";
   value fgmb 1="ja"
              0="nein";
run;

options pagesize=600 fmtsearch=(mafo);


data mafo.temp1 (drop=i);
   brand=1;
   do i=1 to 300;
        respid=i;
		age=int(ranuni(1)*4)+1;
		sex=int(ranuni(1)+0.5)+1;
		region=int(ranuni(1)*7)+1;
		output;
	end;
run;

data mafo.temp2 (drop=i);
   brand=2;
   do i=1 to 300;
        respid=i;
		age=int(ranuni(1)*4)+1;
		sex=int(ranuni(1)+0.5)+1;
		region=int(ranuni(1)*7)+1;
		output;
	end;
	
run;

data mafo.temp3 (drop=i);
   brand=3;
   do i=1 to 300;
        respid=i;
		age=int(ranuni(1)*4)+1;
		sex=int(ranuni(1)+0.5)+1;
		region=int(ranuni(1)*7)+1;
		output;
	end;
	
run;

data mafo.temp4 (drop=i);
   brand=4;
   do i=1 to 300;
        respid=i;
		age=int(ranuni(1)*4)+1;
		sex=int(ranuni(1)+0.5)+1;
		region=int(ranuni(1)*7)+1;
		output;
	end;
	
run;

data mafo.temp5 (drop=i);
   brand=5;
   do i=1 to 300;
        respid=i;
		age=int(ranuni(1)*4)+1;
		sex=int(ranuni(1)+0.5)+1;
		region=int(ranuni(1)*7)+1;
		output;
	end;
	
run;

data mafo.temp6 (drop=i);
   brand=6;
   do i=1 to 300;
        respid=i;
		age=int(ranuni(1)*4)+1;
		sex=int(ranuni(1)+0.5)+1;
		region=int(ranuni(1)*7)+1;
		output;
	end;
	
run;


data mafo.summary (drop=j);
  set mafo.temp1 mafo.temp2 mafo.temp3 mafo.temp4 mafo.temp5 mafo.temp6;
  label im1="Image: Eine moderne Marke"
  		im2="Image: Eine Marke, die viel für ihr Geld bietet"
		im3="Image: Eine Marke mit langer Tradition"
		im4="Image: Eine Marke für Leute wie Du und ich"
		im5="Image: Eine exklusive, teuere Marke"
		im6="Image: Eine Marke, der ich vertraue"
		im7="Image: Eine Marke für jüngere Leute"
	    im8="Image: Eine Marke mit innovativen Leistungen/Produkten"
		im9="Image: Eine Marke, die mir sympathisch ist"
		im10="Image: Eine Marke, die man überall kennt"
        im11="Image: Eine Marke, die ich weiterempfehlen würde"
		im12="Image: Eine Marke, die viel Werbung macht"
		im13="Image: Eine Marke, die besonders auf meine Bedürfnisse und Wünsche eingeht"
		im14="Image: Eine Marke, die von Experten empfohlen wird"
		im15="Image: Eine Marke, mit der ich gute Erfahrungen/schöne Erinnerungen verbinde"
		im16="Image: Eine Marke, die in letzter Zeit immer beliebter wird"
		im17="Image: Eine Marke, von der man viel hört und sieht"
		im18="Image: Eine Marke, die sich von anderen deutlich unterscheidet"
		im19="Image: Eine Marke, die überall erhältlich ist"
		im20="Image: Eine Marke, die zu den größten gehört"
        respid="Respondent-ID"
        brand="Beurteilte Marke"
        age="Altersgruppe"
        sex="Geschlecht"
        region="Nielsen-Region"
        prompted_aw="Gestützte Markenbekanntheit"
        satisfaction="Zufriedenheit";
	run;
data mafo.summary_v2;
  set mafo.summary;
        format brand fbrand.;
		format im1 -- im20 fimage.;
		format sex fsex.;
		format age fage.;
		format region fregion.;
		format satisfaction fsat.;
		prompted_aw=int(ranuni(1)+0.8);
		satisfaction=int(ranuni(1)*5)+1;
		array array1(20) im1-im20; 
        do j=1 to 20;
	   		array1(j)=int(ranuni(1)+0.5);
	 	end;
		format prompted_aw fgmb.;
		if prompted_aw=0 then do;
        satisfaction=.;
        im1=.;
		im2=.;
		im3=.;
		im4=.;
		im5=.;
		im6=.;
		im7=.;
		im8=.;
		im9=.;
		im10=.;
		im11=.;
		im12=.;
		im13=.;
		im14=.;
		im15=.;
		im16=.;
		im17=.;
		im18=.;
		im19=.;
		im20=.;
		end;
run;

proc sort data=mafo.summary out=mafo.surveydata;
by respid brand;
run;

proc datasets library=mafo;
   delete summary temp1 temp2 temp3 temp4 temp5 temp6 /memtype=DATA;
quit;

libname DATEN "D:\DATEN\QUELLEN";
data daten.survey;
 set mafo.surveydata;
 run;
