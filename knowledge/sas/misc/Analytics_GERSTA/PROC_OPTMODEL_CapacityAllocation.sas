
%let nsrv=4;
%let napps=10;

data input;
length SRV_NAME APP_NAME $12.;
Do server=1 to &nsrv;
 
Do app=1 to &napps;
cpu=ranuni(123)*10; format cpu commax10.2;
if server=1 then SRV_NAME='Server A';
else if server=2 then SRV_NAME='Server B';
else if server=3 then SRV_NAME='Server C';
else if server=4 then SRV_NAME='Server D';
else if server=5 then SRV_NAME='Server E';
else if server=6 then SRV_NAME='Server F';
else if server=3 then SRV_NAME='Server G';
else if server=3 then SRV_NAME='Server H';
else if server=3 then SRV_NAME='Server I';



if app=1 then App_name='Oracle';
else if app=2 then App_name='SAP FI';
else if app=3 then App_name='Siebel CRM';
else if app=4 then App_name='Billing';
else if app=5 then App_name='SAP BW';
else if app=6 then App_name='MS SQL';
else if app=7 then App_name='WFMgt';
else if app=8 then App_name='SAS';
else if app=9 then App_name='WebApp';
else if app=10 then App_name='Intranet';


output;
end;
end;

run;

data input;set input;
feasible=(ranuni(123) lt 0.75);
run;
Proc print; run;


data fc_demand;
 do i=1 to &napps;
 WL_FC=1+ranpoi(4321,1);
 app=i;
 output;
 end;
 drop i;
 run;
proc print; run;


data Capacity_SV;
 do i=1 to &nsrv;
 cap=max(0.95, 0.8+ranuni(4324)/50);
  server=i;
 output;
 end;
 drop i;
 run;
proc print; run;



PROC OPTMODEL;
SET <NUMBER> SERVER =1..&nsrv; 
set <NUMBER> APP=1..&napps;
num cpu{SERVER,APP},feasible{SERVER,APP}, wl_fc{APP}, cap{SERVER};
num P=7.5;

var x{SERVER,APP} >=0 <=1;

READ DATA input INTO [SERVER APP] cpu feasible;
READ DATA FC_Demand INTO [APP] WL_FC;
READ DATA Capacity_sv INTO [SERVER] cap;
min Total_Cost=SUM{i in SERVER,j in APP} x[i,j]*cpu[i,j]*P;
con load{j in APP}: SUM{i in SERVER} x[i,j]*cpu[i,j] >= wl_fc[j];
con srv_cap{i in SERVER}: SUM{j in APP} x[i,j] <=cap[i];
con feas{i in SERVER,j in APP}: x[i,j] <= feasible[i,j];
expand;
solve;
print load.dual;
create data sol from [SERVER APP]={i in SERVER,j in APP} 
										x[i,j].sol 
										cpu[i,j]
                                        wl_fc[j] 
                                          cap[i]
                                        feasible[i,j] 


                                       /*opp_load=load[j].dual opp_srv=SERVER[i].dual opp_feasible=feas[i,j].dual*/

; 


quit;

proc sql; create table report as select
a.srv_name,
a.app_name,
b.x,
b.cpu,
b.wl_fc,
b.cap,
b.feasible
from input as a left join sol as b on (a.Server=b.Server and a.App=b.App)
order by a.server, a.app;quit;






proc print data=report;run;

