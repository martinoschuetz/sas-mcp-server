/* Simulate logistic regression */
data tmp1;
 do i =1 to 1000;
   x1=rannor(1234);
   x2=rannor(1235);
   x3=rannor(23546);
   if ranuni(1234)<0.5 then x4=1; else x4=0;
   output;

 end;
drop i;
run;

data tmp2;
  set tmp1;
  t=_n_;
  py=1/(1+exp(1+0.5*x1+0.1*x2+0.7*(x4=1)+rannor(222)/10));
  * call streaminit(1234);
  y1=rand("Bernoulli",py);
  if py<0.5 then y2=0; else y2=1;
  y3=rand("Bernoulli", 0.5);
run;

data mydata.sim_logistic;
 set tmp2;
run;


/* Fake Panel Data regression */

data TID;
 do TID =1 to 10;
    Z=round(5*rannor(333),1);
 output;
 end;
run;


data CID;
 do CID =1 to 12;
   Alpha2=round(3*rannor(123),0.5);
  
 output;
 end;
run;

proc sql;
 create table input  as select
  a.*,
  b.*
  from tid as a, cid as b
  order by b.cid, a.tid;
  quit;

data input; 
set input;
Alpha1=100;
if tid>5 and cid in (1,3,5) then Effect=30; else Effect=0;
Response=Alpha1+3*Alpha2+Z+Effect+rannor(35);
run;


proc panel data=input plots=none;
id cid tid;
model response=Effect / Fixtwo ;
run;
