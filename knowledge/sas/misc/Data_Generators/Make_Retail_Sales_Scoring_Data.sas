/* -- Template zum Erstellen eines Data Mining Datensatzes  für Scoring-Modelle -- */

/* -- Größe des ARRAYS --*/
%let NOBS=500000;
%let NVARS=20;


/* -- Erzeuge Zufallszahlen -- */
data tmp1; 
length x01 - x&NVARS 8;
array x(&NVARS) x01-x&NVARS;
do i=1 to &NOBS;
  do j=1 to &NVARS;
   x(j)=ranuni(123454);
  end;
output;
end;
drop i j;
run;


data tmp2;
 set tmp1;
 length y01 - y&NVARS 8;
 array x1(&NVARS) x01-x&NVARS;
 array x2(&NVARS) y01-y&NVARS;

 do i=1 to 20;
   do j=1 to 20;
    x2(j)=x1(j)+rannor(321)*0.2;
  end;
  end;
  drop i j;
  output;
run;

data tmp3;
 set tmp2;
 if x01 > 0.6 or x02 > 0.6 or x03 > 0.7 then z01=0.6+rannor(4324)*0.2; else z01=0.1+rannor(312)*0.1;
 if x08 > 0.6 or x11 > 0.6 or x13 > 0.7 then z02=0.6+rannor(422)*0.2; else z02=0.1+rannor(4324)*0.1;
 z03=z01+rannor(666)*0.3;
 z04=z01+rannor(444)*0.3;
 z05=z02+rannor(55)*0.3;
 z06=z02+rannor(453)*0.3;
 z07=ranuni(11);
 z08=ranuni(14);
 z09=ranuni(32);
 z10=z09+rannor(32)*0.1;
 z11=z06+rannor(333)*0.02;
 z12=z07+rannor(333)*0.02;
 z13=z04+rannor(4324)*0.02;
 z14=z05+rannor(3423)*0.02;
 z15=z08+rannor(323)*0.05;

run;


proc stdize data=tmp3 out=tmp4 method=RANGE; 
         var _NUMERIC_; 
run; 

data tmp5;
 set tmp4;

 KUNDEN_ID=100000+_N_*10000+int(ranuni(432)*321);

 if 0<x01<1 then UMSATZ_WG01_AJ=gaminv(x01,3)*140;
 if 0<x02<1 then UMSATZ_WG02_AJ=gaminv(x02,2)*100;
 if 0<x03<1 then UMSATZ_WG03_AJ=gaminv(x03,2)*34;
 if 0<x04<1 then UMSATZ_WG04_AJ=gaminv(x04,0.92)*20;
 if 0<x05<1 then UMSATZ_WG05_AJ=gaminv(x05,0.91)*12;
 if 0<x06<1 then UMSATZ_WG06_AJ=gaminv(x06,0.8)*32;
 if 0<x07<1 then UMSATZ_WG07_AJ=gaminv(x07,3)*78;
 if 0<x08<1 then UMSATZ_WG08_AJ=gaminv(x08,2)*78;
 if 0<x09<1 then UMSATZ_WG09_AJ=gaminv(x09,2)*34;
 if 0<x10<1 then UMSATZ_WG10_AJ=gaminv(x10,0.92)*40;
 if 0<x11<1 then UMSATZ_WG11_AJ=gaminv(x11,0.91)*62;
 if 0<x12<1 then UMSATZ_WG12_AJ=gaminv(x12,0.8)*132;
 if 0<x13<1 then UMSATZ_WG13_AJ=gaminv(x13,3)*40;
 if 0<x14<1 then UMSATZ_WG14_AJ=gaminv(x14,2)*20;
 if 0<x15<1 then UMSATZ_WG15_AJ=gaminv(x15,2)*34;
 if 0<x16<1 then UMSATZ_WG16_AJ=gaminv(x16,0.92)*7;
 if 0<x17<1 then UMSATZ_WG17_AJ=gaminv(x17,0.91)*8;
 if 0<x18<1 then UMSATZ_WG18_AJ=gaminv(x18,0.8)*12;
 if 0<x19<1 then UMSATZ_WG19_AJ=gaminv(x19,0.8)*32;
 if 0<x20<1 then UMSATZ_WG20_AJ=gaminv(x20,0.4)*12;

 if 0<y01<1 then UMSATZ_WG01_VJ=gaminv(y01,3)*140;
 if 0<y02<1 then UMSATZ_WG02_VJ=gaminv(y02,2)*100;
 if 0<y03<1 then UMSATZ_WG03_VJ=gaminv(y03,2)*34;
 if 0<y04<1 then UMSATZ_WG04_VJ=gaminv(y04,0.92)*20;
 if 0<y05<1 then UMSATZ_WG05_VJ=gaminv(y05,0.91)*12;
 if 0<y06<1 then UMSATZ_WG06_VJ=gaminv(y06,0.8)*32;
 if 0<y07<1 then UMSATZ_WG07_VJ=gaminv(y07,3)*78;
 if 0<y08<1 then UMSATZ_WG08_VJ=gaminv(y08,2)*78;
 if 0<y09<1 then UMSATZ_WG09_VJ=gaminv(y09,2)*34;
 if 0<y10<1 then UMSATZ_WG10_VJ=gaminv(y10,0.92)*40;
 if 0<y11<1 then UMSATZ_WG11_VJ=gaminv(y11,0.91)*62;
 if 0<y12<1 then UMSATZ_WG12_VJ=gaminv(y12,0.8)*132;
 if 0<y13<1 then UMSATZ_WG13_VJ=gaminv(y13,3)*40;
 if 0<y14<1 then UMSATZ_WG14_VJ=gaminv(y14,2)*20;
 if 0<y15<1 then UMSATZ_WG15_VJ=gaminv(y15,2)*34;
 if 0<y16<1 then UMSATZ_WG16_VJ=gaminv(y16,0.92)*7;
 if 0<y17<1 then UMSATZ_WG17_VJ=gaminv(y17,0.91)*8;
 if 0<y18<1 then UMSATZ_WG18_VJ=gaminv(y18,0.8)*12;
 if 0<y19<1 then UMSATZ_WG19_VJ=gaminv(y19,0.8)*32;
 if 0<y20<1 then UMSATZ_WG20_VJ=gaminv(y20,0.4)*12;


 format UMSATZ_WG01_AJ--UMSATZ_WG20_AJ UMSATZ_WG01_VJ--UMSATZ_WG20_VJ 8.2;

 if 0<z01<1 then LK_DAUER=int(gaminv(z01,0.5)*120);
 if 0<z02<1 then KUNDENBEZIEHUNGSDAUER=int(gaminv(z02,0.4)*43);
 if z03<0.4 then GESCHLECHT='M';
 else if z03<0.9 then GESCHLECHT='F';

 
 if 0<z04<1 then ANZ_ART_WARENKORB_AJ=gaminv(z04,1.0)*4+1;
 if 0<z05<1 then ANZ_ART_WARENKORB_VJ=gaminv(z05,1.0)*3+1;

 if 0<z06<1 then ANT_HANDELSM_WK_AJ=gaminv(z06,0.3)/3;
 if 0<z07<1 then ANT_HANDELSM_WK_VJ=gaminv(z07,0.3)/3;
 
 if 0<z08<1 then ANZ_BESUCHE_AJ=int(gaminv(z08,7.3))+7;
 if 0<z09<1 then ANZ_BESUCHE_VJ=int(gaminv(z09,8.3))+8;

 if z10>0.2 then NEWSLETTER='NEIN'; else NEWSLETTER='JA';
 
 if 0<z11<1 then ANT_SONDERANG_WK_AJ=gaminv(z11,0.3)/3;
 if 0<z12<1 then ANT_SONDERANG_WK_VJ=gaminv(z12,0.3)/3;
 
 if 0<z13<1 then INTVL_BESUCHE_AJ=gaminv(z13,0.82)*15;
 if 0<z14<1 then INTVL_BESUCHE_VJ=gaminv(z14,0.82)*15;

 if z15<0.1 then STATUS='PREMIUM';
 else if z15<0.19 then STATUS='FAMILY';
 else STATUS='BASIS';



 

 UMSATZ_TOTAL_AJ=sum(of UMSATZ_WG01_AJ -- UMSATZ_WG20_AJ);
 UMSATZ_TOTAL_VJ=sum(of UMSATZ_WG01_VJ -- UMSATZ_WG20_VJ);


 format UMSATZ_WG01_AJ--UMSATZ_WG20_AJ UMSATZ_WG01_VJ--UMSATZ_WG20_VJ UMSATZ_TOTAL_AJ UMSATZ_TOTAL_VJ 8.2;

 format ANZ_ART_WARENKORB_AJ ANZ_ART_WARENKORB_VJ 
        ANT_HANDELSM_WK_AJ ANT_HANDELSM_WK_VJ 
        ANT_SONDERANG_WK_AJ ANT_SONDERANG_WK_VJ 
        INTVL_BESUCHE_AJ INTVL_BESUCHE_VJ
        8.2;
 
 
 target=0.43*(sum (of x01--x20))**2+0.1*(sum (of y01--y20))**2
        + 200*(z15<0.14) + 50*z08+ 40*z09 - 8*z01**2
        + 20*z02;
;

 label 
ANT_HANDELSM_WK_VJ = "Anteil Handelsmarken pro Warenkorb Vorjahr"
ANT_SONDERANG_WK_AJ = "Anteil Sonderangebote pro Warenkorb Aktuell"
ANT_SONDERANG_WK_VJ = "Anteil Sonderangebote pro Warenkorb Vorjahr"
ANZ_ART_WARENKORB_AJ = "Anzahl Artikel Warenkorb Aktuell"
ANZ_ART_WARENKORB_VJ = "Anzahl Artikel Warenkorb Vorjahr"
ANZ_BESUCHE_AJ = "Anzahl Besuche Aktuell"
ANZ_BESUCHE_VJ = "Anzahl Besuche Vorjahr"
GESCHLECHT = "Geschlecht"
INTVL_BESUCHE_AJ = "Mittleres Besuchsintervall in Tagen Aktuell"
INTVL_BESUCHE_VJ = "Mittleres Besuchsintervall in Tagen Vorjahr"
KUNDENBEZIEHUNGSDAUER = "Kundenbeziehungsdauer in Monaten"
KUNDEN_ID = "Kunden-ID"
LK_DAUER = "Letztkauf-Dauer in Tagen"
NEWSLETTER = "Newsletter-Abonnement"
STATUS = "Mitgliedstatus im Programm"
UMSATZ_TOTAL_AJ = "Umsatz gesamt Aktuell"
UMSATZ_TOTAL_VJ = "Umsatz gesamt Vorjahr"
UMSATZ_WG01_AJ = "Umsatz WG01 Aktuell"
UMSATZ_WG01_VJ = "Umsatz WG01 Vorjahr"
UMSATZ_WG02_AJ = "Umsatz WG02 Aktuell"
UMSATZ_WG02_VJ = "Umsatz WG02 Vorjahr"
UMSATZ_WG03_AJ = "Umsatz WG03 Aktuell"
UMSATZ_WG03_VJ = "Umsatz WG03 Vorjahr"
UMSATZ_WG04_AJ = "Umsatz WG04 Aktuell"
UMSATZ_WG04_VJ = "Umsatz WG04 Vorjahr"
UMSATZ_WG05_AJ = "Umsatz WG05 Aktuell"
UMSATZ_WG05_VJ = "Umsatz WG05 Vorjahr"
UMSATZ_WG06_AJ = "Umsatz WG06 Aktuell"
UMSATZ_WG06_VJ = "Umsatz WG06 Vorjahr"
UMSATZ_WG07_AJ = "Umsatz WG07 Aktuell"
UMSATZ_WG07_VJ = "Umsatz WG07 Vorjahr"
UMSATZ_WG08_AJ = "Umsatz WG08 Aktuell"
UMSATZ_WG08_VJ = "Umsatz WG08 Vorjahr"
UMSATZ_WG09_AJ = "Umsatz WG09 Aktuell"
UMSATZ_WG09_VJ = "Umsatz WG09 Vorjahr"
UMSATZ_WG10_AJ = "Umsatz WG10 Aktuell"
UMSATZ_WG10_VJ = "Umsatz WG10 Vorjahr"
UMSATZ_WG11_AJ = "Umsatz WG11 Aktuell"
UMSATZ_WG11_VJ = "Umsatz WG11 Vorjahr"
UMSATZ_WG12_AJ = "Umsatz WG12 Aktuell"
UMSATZ_WG12_VJ = "Umsatz WG12 Vorjahr"
UMSATZ_WG13_AJ = "Umsatz WG13 Aktuell"
UMSATZ_WG13_VJ = "Umsatz WG13 Vorjahr"
UMSATZ_WG14_AJ = "Umsatz WG14 Aktuell"
UMSATZ_WG14_VJ = "Umsatz WG14 Vorjahr"
UMSATZ_WG15_AJ = "Umsatz WG15 Aktuell"
UMSATZ_WG15_VJ = "Umsatz WG15 Vorjahr"
UMSATZ_WG16_AJ = "Umsatz WG16 Aktuell"
UMSATZ_WG16_VJ = "Umsatz WG16 Vorjahr"
UMSATZ_WG17_AJ = "Umsatz WG17 Aktuell"
UMSATZ_WG17_VJ = "Umsatz WG17 Vorjahr"
UMSATZ_WG18_AJ = "Umsatz WG18 Aktuell"
UMSATZ_WG18_VJ = "Umsatz WG18 Vorjahr"
UMSATZ_WG19_AJ = "Umsatz WG19 Aktuell"
UMSATZ_WG19_VJ = "Umsatz WG19 Vorjahr"
UMSATZ_WG20_AJ = "Umsatz WG20 Aktuell"
UMSATZ_WG20_VJ = "Umsatz WG20 Vorjahr"
;

/*-- Missing-Kontamination --*/
if ranuni(434)<0.03 then ANT_HANDELSM_WK_VJ = .;
if ranuni(332)<0.11 then ANT_SONDERANG_WK_AJ = .;
if ranuni(422)<0.13 then ANT_SONDERANG_WK_VJ = .;
if ranuni(671)<0.02 then ANZ_ART_WARENKORB_AJ = .;
if ranuni(901)<0.03 then ANZ_ART_WARENKORB_VJ = .;
if ranuni(910)<0.03 then ANZ_BESUCHE_AJ = .;
if ranuni(999)<0.02 then ANZ_BESUCHE_VJ = .;
if ranuni(111)<0.18 then INTVL_BESUCHE_AJ = .;
if ranuni(112)<0.12 then INTVL_BESUCHE_VJ = .;
if ranuni(222)<0.02 then KUNDENBEZIEHUNGSDAUER = .;
if ranuni(333)<0.02 then LK_DAUER = .;
if ranuni(892)<0.08 then NEWSLETTER = "";
if ranuni(291)<0.08 then STATUS = "";
drop x01--x20 y01--y20 z01--z15;
run;



proc stdize data=tmp5 out=tmp5 method=RANGE; 
         var target; 
run; 

data tmp5;
 set tmp5;
 if target<0.13 then REAGIERT=1; else REAGIERT=0;
 label REAGIERT = "Kampagnenreaktion";
 drop target;

  if ranuni(3213) <0.1 then x=1; else x=2;
 
run;

libname fcslib "D:\DATEN\QUELLEN";
data fcslib.retail_train;
  set tmp5;
  where x=1;
  drop x;
run;

data fcslib.retail_score;
 set tmp5;
 where x=2;
 drop reagiert x;
run;
 


