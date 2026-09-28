/* Fake-Clusteranalyse (ORION-ähnliche Daten) */
libname demo "C:\DATEN\MCC";

data temp (drop=i j);
   array array1(15) wg_1-wg_15; 
	 do i=1 to 300;
        customer_id=14000+i;
		if i <120 then gruppe=1;
        else if i < 200 then gruppe=2;
        else gruppe=3;
		do j=1 to 15;
	   		array1(j)=10+ranuni(1)*20;
	 	end;
		output;
	end;
run;


data temp2;
  format wg_1 - wg_15 euro8.2;
  set temp;
  label wg_1 ='Freizeit-Oberbekleidung'
        wg_2 ='Kinder-Sportkleidung' 
        wg_3 ='Freizeit-Schuhe'
        wg_4 ='Laufkleidung'
        wg_5 ='Fitness + Gymnastik'
        wg_6 ='Fußball'
        wg_7 ='Tennis, Squash, Badminton'
        wg_8 ='Schwimmen'
        wg_9 ='US-Sport'
        wg_10='Wintersport'
        wg_11='Golf'
        wg_12='Surfen'
        wg_13='Outdoor, Trekking, Wandern'
        wg_14='Camping'
        wg_15='Motorsport-Kleidung';
  if gruppe = 1 then do;
  wg_1 = wg_1 + 300+ranuni(1)*300;
  wg_2 = wg_2 + 300+ranuni(1)*200;
  wg_3 = wg_3 + 200+ ranuni(1)*100;
  wg_4 = wg_4 + 300+ranuni(1)*200;
  wg_5 = wg_5 + 200+ranuni(1)*100;
  wg_14 = wg_14 + 500+ ranuni(1)*100;
  end;
  if gruppe= 2 then do;
  wg_6 = wg_6 + 300+ranuni(1)*200;
  wg_7 = wg_7 + 300+ranuni(1)*100;
  wg_8 = wg_8 + 300+ranuni(1)*150;
  wg_9 = wg_9 + 300+ranuni(1)*200;
  wg_10 = wg_10 + 300+ ranuni(1)*150;
  end;
  if gruppe= 3 then do;
  wg_11 = wg_11 + 300+ranuni(1)*100;
  wg_12 = wg_12 + 240+ranuni(1)*100;
  wg_13 = wg_13 + 300+ranuni(1)*100;
  wg_15 = wg_15 + 230+ranuni(1)*100;
  end;
  randomsort=ranuni(2);
run;
  
data temp4;
 set temp3;

 LENGTH GENDER $12.;
 LENGTH AGEGROUP $20.;

 if gruppe=1 and ranuni(4324)>0.5 then GENDER='Female'; 
 else if gruppe=2 and ranuni(4324)<0.2 then GENDER='Female';
 else if gruppe=3 and ranuni(111)>0.9 then GENDER='Female';
 else Gender='Male';

 if gruppe=1 and ranuni(12)<0.2 then AGEGROUP='<18 Yrs'; 
 else if gruppe=1 and ranuni(32)<0.5 then AGEGROUP='18 - 35';
 else if gruppe=1 and ranuni(32)>=0.5 then AGEGROUP='> 35 Yrs';

 if gruppe=2 and ranuni(142)<0.43 then AGEGROUP='<18 Yrs'; 
 else if gruppe=2 and ranuni(3242)<0.78 then AGEGROUP='18 - 35';
 else if gruppe=2 and ranuni(32342)>=0.78 then AGEGROUP='> 35 Yrs';

 if gruppe=3 and ranuni(142)<0.03 then AGEGROUP='<18 Yrs'; 
 else if gruppe=3 and ranuni(3242)<0.45 then AGEGROUP='18 - 35';
 else if gruppe=3 and ranuni(32342)>=0.45 then AGEGROUP='> 35 Yrs';
 
 else if ranuni(432)>0.5 then AGEGROUP='<18 Yrs';
else AGEGROUP='18 - 35';
 



run;

proc sort data=temp4 out=temp5;
  by randomsort;
run;

data demo.CUSTOMERDATA (drop=gruppe randomsort);
 set temp5;
run;

