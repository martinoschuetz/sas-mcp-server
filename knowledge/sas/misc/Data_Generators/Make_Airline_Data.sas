libname a "D:\DATEN\QUELLEN";

data tmp; 
set a.INSURANCE_VDD;

if bezirksdirektion eq 'Bayreuth';

NETINC_AFTR_TAX=deckungsbeitrag1;
PCT_NETSALES=deckungsbeitrag2;
EPS=gesamtvolumen;
NETINCOME=kosten_sparte;
SHARE_HLD_VAL=kosten_tariftyp;
YTD_CURR_SP=neuvertraege;
FIXED_OVRHD=schadenaufw;
AIRLINE=tariftyp;
MONTH2=zeitstempel;
VAR_OVRHD=zielerreichung;


drop
bezirksdirektion
deckungsbeitrag1
deckungsbeitrag2
gesamtvolumen
kosten_sparte
kosten_tariftyp
neuvertraege
region
schadenaufw
sparte
tariftyp
zeitstempel
zielbinaer
zielerreichung;

label NETINC_AFTR_TAX='Net Income After Taxes'
      PCT_NETSALES='Percent Of Net Sales'
	  EPS='Earnings Per Share'
	  NETINCOME='Net Income'
	  SHARE_HLD_VAL='Shareholder Value'
	  YTD_CURR_SP='YTD Current Spend'
	  FIXED_OVRHD='Fixed Overhead'
	  AIRLINE='Airline'
	  MONTH='Reporting Month'
	  VAR_OVRHD='Variable Overhead';


 if AIRLINE='Bauherrenhaftpflicht' then AIRLINE='Amanda Air';
 else if AIRLINE='Fahrrad' then AIRLINE='Fantasia';
else if AIRLINE='Gewässerschaden' then AIRLINE='Super Wings';
else if AIRLINE='Glasbruch' then AIRLINE='Phoenix';
else if AIRLINE='Hausrat' then AIRLINE='Karat';
else if AIRLINE='Hunde-Haftpflicht' then AIRLINE='1-2-3-Fly';
else if AIRLINE='Kfz-Schutzbrief' then AIRLINE='Canadian West';
else if AIRLINE='LKW' then AIRLINE='Helios';
else if AIRLINE='Motorrad' then AIRLINE='Air 24';
else if AIRLINE='PKW' then AIRLINE='Holiday Air';
else if AIRLINE='Privat-Haftpflicht' then AIRLINE='Captain Kirk';
else if AIRLINE='Roller/Moped' then AIRLINE='Eastern China';
else if AIRLINE='Anhänger' then AIRLINE='Leasure Lines';
else if AIRLINE='Verkehrs-Rechtschutz' then AIRLINE='Fox';
else if AIRLINE='Wohngebäude' then AIRLINE='Take-Off Air';

yy=year(MONTH2)-1;
mm=month(MONTH2);

MONTH=mdy(mm,1,yy);

if yy=2008 then delete;
drop mm yy month2;


format MONTH MONYY.;

NETINC_AFTR_TAX	=	NETINC_AFTR_TAX	*	54.2278377705274000	;
PCT_NETSALES	=	PCT_NETSALES	*	0.0000692035200786	;
EPS	=	EPS	*	0.0000937426294858	;
NETINCOME	=	NETINCOME	*	0.1575720939659200	;
SHARE_HLD_VAL	=	SHARE_HLD_VAL	*	0.0001960716179906	;
YTD_CURR_SP	=	YTD_CURR_SP	*	1.6783208148668900	;
FIXED_OVRHD	=	FIXED_OVRHD	*	2.2440301673642800	;
VAR_OVRHD	=	VAR_OVRHD	*	88454.9653253485000000	;



run;

data a.AIRLINE_VDD;
  set tmp;
run;

proc print data=tmp (where=(AIRLINE='Airline M' and MONTH='01DEC2007'D));
 var _ALL_;
 run;