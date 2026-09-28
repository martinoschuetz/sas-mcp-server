/* Fake-Clusteranalyse (ORION-ähnliche Daten) */

/* Makro-Variablen zur Steuerung */
%let n_cases=10000;
%let path=C:\DATEN;




/* Ableiten relevanter Makro-Variablen */

libname demo "C:\DATEN";
%let cut1=%sysevalf(&n_cases/5.0);
%let cut2=%sysevalf(&n_cases/2.5);
%let rec_id=%sysevalf(&n_cases*100);

%put n_cases=&n_cases;
%put cut1=&cut1;
%put cut2=&cut2;
%put rec_id=&rec_id;






/* Erzeugen der Rohdaten */
data temp (drop=i j);
   array array1(15) wg01-wg15; 
	 do i=1 to &n_cases;
        bon_id=&rec_id+i;
		if i <&cut1 then gruppe=1;
        else if i < &cut2 then gruppe=2;
        else gruppe=3;
		do j=1 to 15;
	   		array1(j)=0+ranuni(1)*5;
	 	end;
		output;
	end;
run;



/* Anreichern der Rohdaten */
data temp2;
  format wg01 - wg15 8.2;
  set temp;
  label wg01 ='Freizeit-Oberbekleidung'
        wg02 ='Kinder-Sportkleidung' 
        wg03 ='Freizeit-Schuhe'
        wg04 ='Laufkleidung'
        wg05 ='Fitness + Gymnastik'
        wg06 ='Fußball'
        wg07 ='Tennis, Squash, Badminton'
        wg08 ='Schwimmen'
        wg09 ='US-Sport'
        wg10='Wintersport'
        wg11='Golf'
        wg12='Surfen'
        wg13='Outdoor, Trekking, Wandern'
        wg14='Camping'
        wg15='Motorsport-Kleidung'
		artpos='Anzahl Artikelpositionen'
		total='Totalbetrag'
		aktionen='Anteil Aktionsware'
		premium='Anteil Premium-Preislage'
		billig='Anteil niedrige Preislage'
		handelsmarken='Anteil Handelsmarken';

		/* SEgment: Premium-Käufer*/
  if gruppe = 1 then do;
  wg01 = wg01 + 150+ranuni(1)*300;
  wg02 = wg02 + 100+ranuni(1)*200;
  wg03 = wg03 + 200+ ranuni(1)*100;
  wg04 = wg04 + 300+ranuni(1)*200;
  wg05 = wg05 + 200+ranuni(1)*100;
  wg14 = wg14 + 500+ ranuni(1)*100;
  artpos=ranpoi(123,4);
  total=280+abs(rannor(23423)*15);
  aktionen=abs(0.2+rannor(432)/10);
  pr1=70+rannor(234)*5;
  pr2=30-rannor(434)*6;
  pr3=10+rannor(234)*5;
  prsum=pr1+pr2+pr3;
  premium=pr1/prsum;
  billig=pr3/prsum;

  handelsmarken=min(abs(0.9*billig+rannor(234)/10),1);
  end;
  if artpos<=2 then do;
  aktionen=0;
  premium=1;
  billig=0;
  handelsmarken=0;
  end;

  if gruppe= 2 then do;
  wg06 = wg06 + 300+ranuni(1)*200;
  wg07 = wg07 + 300+ranuni(1)*100;
  wg08 = wg08 + 300+ranuni(1)*150;
  wg09 = wg09 + 300+ranuni(1)*200;
  wg10 = wg10 + 300+ ranuni(1)*150;
  artpos=ranpoi(126,1);
  total=50+abs(rannor(223)*17);
  aktionen=0.6+rannor(432)/10;
  pr1=15+rannor(234)*5;
  pr2=50-rannor(434)*6;
  pr3=80+rannor(234)*5;
  prsum=pr1+pr2+pr3;
  premium=pr1/prsum;
  billig=pr3/prsum;
  handelsmarken=min(abs(0.2*billig+rannor(21134)/10),1);
  end;
  if artpos<=2 then do;
  aktionen=1;
  premium=0;
  billig=1;
  handelsmarken=1;
  end;


  if gruppe= 3 then do;
  wg01 = wg01 + 150+ranuni(1)*300;
  wg02 = wg02 + 100+ranuni(1)*200;
  wg03 = wg03 + 200+ ranuni(1)*100;
  wg04 = wg04 + 300+ranuni(1)*200;
  wg05 = wg05 + 200+ranuni(1)*100;
  wg06 = wg06 + 300+ranuni(1)*200;
  wg07 = wg07 + 300+ranuni(1)*100;
  wg08 = wg08 + 300+ranuni(1)*150;
  wg09 = wg09 + 300+ranuni(1)*200;
  wg10 = wg10 + 300+ ranuni(1)*150;
  wg14 = wg14 + 500+ ranuni(1)*100;
  wg11 = wg11 + 300+ranuni(1)*100;
  wg12 = wg12 + 240+ranuni(1)*100;
  wg13 = wg13 + 300+ranuni(1)*100;
  wg15 = wg15 + 230+ranuni(1)*100;
  artpos=ranpoi(156,7);
  total=130+abs(rannor(23423)*15);
  aktionen=0.6+rannor(432)/10;
  pr1=20+rannor(234)*5;
  pr2=30-rannor(434)*6;
  pr3=50+rannor(234)*5;
  prsum=pr1+pr2+pr3;
  premium=pr1/prsum;
  billig=pr3/prsum;
  handelsmarken=min(abs(0.9*billig+rannor(234)/10),1);
  end;
  if artpos<=2 then do;
  aktionen=1;
  premium=0;
  billig=1;
  handelsmarken=1;
  end;



  if aktionen<0 then aktionen=0;
  else if aktionen>1 then aktionen=1;

  if premium<0 then premium=0;
  else if premium>1 then premium=1;

  
  if billig<0 then billig=0;
  else if billig>1 then billig=1;
   
  if handelsmarken<0 then handelsmarken=0;
  else if handelsmarken>1 then handelsmarken=1;
  randomsort=ranuni(2);
  summe=sum(wg01, wg02,wg03,wg04,wg05,wg06,wg07,wg08,wg09,wg10,wg11,wg12,wg13,wg14,wg15);
  array array1(15) wg01-wg15; 
  do i=1 to 15;
  array1(i)=array1(i)/summe;
  end;
  if artpos=0 then artpos=1+int(ranuni(432)*10);
  drop summe i pr1 pr2 pr3 prsum;
run;
  
data temp3;
 set temp2;

 LENGTH payment $12.;
 LENGTH filialtyp $20.;
 LENGTH wochentag $20.;
 LENGTH tageszeit $20.;




 if gruppe=1 and ranuni(4324)>0.5 then payment='Kreditkarte'; 
 else if gruppe=2 and ranuni(4324)<0.6 then payment='Bar';
 else if gruppe=3 and ranuni(111)>0.9 then payment='Kreditkarte';
 else payment='EC-Karte';

 if gruppe=1 and ranuni(12)<0.2 then filialtyp='Typ 1: Standard'; 
 else if gruppe=1 and ranuni(32)<0.5 then filialtyp='Typ 2: Quickshop';
 else if gruppe=1 and ranuni(32)>=0.5 then filialtyp='Typ 3: Megastore';

 if gruppe=2 and ranuni(142)<0.43 then filialtyp='Typ 1: Standard'; 
 else if gruppe=2 and ranuni(3242)<0.78 then filialtyp='Typ 2: Quickshop';
 else if gruppe=2 and ranuni(32342)>=0.78 then filialtyp='Typ 3: Megastore';

 if gruppe=3 and ranuni(142)<0.03 then filialtyp='Standard'; 
 else if gruppe=3 and ranuni(3242)<0.45 then filialtyp='Quickshop';
 else if gruppe=3 and ranuni(32342)>=0.45 then filialtyp='Megastore';
 
 else if ranuni(432)>0.5 then filialtyp='Standard';
 else filialtyp='Megastore';
 
 if gruppe=1 and ranuni(12)>0.2 then wochentag='1: Mo-Do';
 else if gruppe=1 and ranuni(12)<0.5 then wochentag='2: Fr';
 else if gruppe=1  then wochentag='3: Sa';

 if gruppe=2 and ranuni(234)<0.3 then wochentag='1: Mo-Do';
 else if gruppe=2 and ranuni(234)<0.9 then wochentag='2: Fr';
 else if gruppe=2 then wochentag='3: Sa';

 if gruppe=3 and ranuni(234)<0.1 then wochentag='1: Mo-Do';
 else if gruppe=3 and ranuni(234)<0.4 then wochentag='2: Fr';
 else if gruppe=3 then wochentag='3: Sa';



 if gruppe=1 and ranuni(56)<0.5 then tageszeit='1: 09:00-14:00';
 else if gruppe=1 and ranuni(56)<0.8 then tageszeit='2: 14:00-17:00';
 else if gruppe=1  then tageszeit='3: 17:00-20:00';

 if gruppe=2 and ranuni(234)<0.2 then tageszeit='1: 09:00-14:00';
 else if gruppe=2 and ranuni(234)<0.7 then tageszeit='2: 14:00-17:00';
 else if gruppe=2 then tageszeit='3: 17:00-20:00';

 if gruppe=3 and ranuni(234)<0.8 then tageszeit='1: 09:00-14:00';
 else if gruppe=3 and ranuni(234)<0.9 then tageszeit='2: 14:00-17:00';
 else if gruppe=3 then tageszeit='3: 17:00-20:00';

 label tageszeit='Tageszeit'
       filialtyp='Filialtyp'
	   wochentag='Wochentag'
	   payment='Zahlungsart';
  format aktionen premium billig handelsmarken total 8.2;

run;


/* Randomisieren der Reihenfolge */
proc sort data=temp3 out=temp4;
  by randomsort;
run;

data demo.retail_bondata(drop=randomsort);
 set temp4;
run;



/* K-Means Cluster Analysis */
proc fastclus data=demo.retail_bondata maxc=3 maxiter=20 out=demo.Clusters;
   var wg01 -- wg15;
   id bon_id;
run;
