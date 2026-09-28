options cashost="dach-viya-smp.sas.com";
options CASPORT=5570;

cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US" metrics=true);

caslib _all_ assign;
caslib _all_ list;

data casuser.spiral;
	keep x1 x2 y id;
	nNow=200;
	sdNow=0.2;
	four_pi=4 * constant("pi");
	call streaminit(3331333);
	y=0;
	id=0;

	do theta=0 to 12;
		r=1.0 - theta / four_pi;
		mu1=cos(theta);
		mu2=sin(theta);
		ss=r*r / (mu1*mu1 + mu2*mu2);
		s=sqrt(ss);
		mu1=s*mu1;
		mu2=s*mu2;
		nNow=nNow * 0.7;
		sdNow=sdNow * 0.75;

		do i=1 to nNow;
			x1=rand('normal', mu1, sdNow);
			x2=rand('normal', mu2, sdNow);
			y=1 - y;
			id=id + 1;
			output;
		end;
	end;
run;

proc forest data=casuser.spiral isolation seed=12345;
	input x1 x2 /level=interval;
	target y /level=nominal;
	id id;
	output out=casuser.score copyvars=(_ALL_);
run;

/*
proc forest data=public.akd isolation seed=12345;
	input Zeit Strom Spannung Drahtvorschub /level=interval;
	target Zeit /level=interval;
	output out=casuser.score copyvars=(_ALL_);
run;

proc sgplot data=casuser.score;
  title "Anomaly Score over Time";
  scatter x=Zeit y=_Anomaly_;
run;
*/

proc sort data=casuser.score out=score;
	by id;
run;

proc template;
	define statgraph anomalyPlot;
		begingraph;
		layout overlay;
		scatterplot y=x2 x=x1 / name='color' markerattrs=(symbol=circlefilled) 
			colormodel=(cyan ligr red) colorresponse=_Anomaly_;
		continuouslegend 'color'/ title='_Anomaly_';
		endlayout;
		endgraph;
	end;
run;

proc sgrender data=score template=anomalyPlot;
run;

cas mySession terminate;