libname a "D:\TEMP\SFD2006";

data a.temp;
  length product $ 20;
  do i=1 to 20;
    product='Product '||put(i,$2.);
    output;
  end;
  drop i;
run;

data a.temp2;
  length seg $ 20;
  do i=1 to 15;
     seg='Seg '||put(i,$2.);
	output;
	end;
   drop i;
run;


proc sql;
 create table a.temp3 as select
   temp.product,
   temp2.seg 
from a.temp, a.temp2
 order by product, seg;
 quit;
  
data a.temp3;
  set a.temp3;
  n=_N_;
  x=ranuni(1)*100;
  if mod(n,4)=3 then absatz=int(x+rannor(1)*50); else absatz=int(x+rannor(2)*3);
  drop x n;
  label seg='Segment' product='Produkt' absatz='Umsatz';
run;

  ods html; 
   ods graphics on; 

/*
data a.temp4;
   do i=1 to 6;
     x=ranuni(1);
	 y=ranuni(2);
     product='Product '||put(i,$2.);
	 segment1=int(x*100);
	 segment2=segment1*200+int(rannor(1)*30);
     segment3=segment1*200+int(rannor(2)*30);
	 segment4=int((x+y)*300)+int(rannor(1)*13);
     segment5=int(y*330)+int(rannor(1)*12);
	 segment6=int((rannor(1)*40);
	 output;
	end;
	drop x y i;
run;*/

data a.temp4;
do i=1 to 6;
     x=ranuni(1);
	 y=ranuni(2);
     product='Product '||put(i,$2.);
	 segment1=int(ranuni(12345)*230);
	 segment2=int(ranuni(23456)*100);
     segment3=int(ranuni(12345)*120);
	 segment4=segment3+int(ranuni(12345)*20);
     segment5=int(ranuni(34567)*330);
	 segment6=int(ranuni(12345)*210);
	 output;
	end;
	drop x y i;
run;
data a.temp4_1;
  set a.temp4;
  segment='Segment 1';
  absatz=segment1;
  keep product segment absatz;
run;

data a.temp4_2;
  set a.temp4;
  segment='Segment 2';
  absatz=segment2;
  keep product segment absatz; 
run;

data a.temp4_3;
  set a.temp4;
  segment='Segment 3';
  absatz=segment3;
  keep product segment absatz;
run;

data a.temp4_4;
  set a.temp4;
  segment='Segment 4';
  absatz=segment4;
  keep product segment absatz;
run;

data a.temp4_5;
  set a.temp4;
  segment='Segment 5';
  absatz=segment5;
  keep product segment absatz;
run;

data a.temp4_6;
  set a.temp4;
  segment='Segment 6';
  absatz=segment6;
  keep product segment absatz;
run;

data a.temp5;
  set a.temp4_1 a.temp4_2 a.temp4_3 a.temp4_4 a.temp4_5 a.temp4_6;
run;
proc corresp data=a.temp5 out=Results short profile=both ; 
      tables segment, product; 
      
	  weight absatz; 
   run; 
     ods graphics off; 
   ods html close;
