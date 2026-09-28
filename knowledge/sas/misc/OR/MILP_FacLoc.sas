/* ============================================================ */                                                                      
/* ======== Example - Facility Location    ==================== */                                                                      
/* ============================================================ */                                                                      
    %let NumCustomers  = 50;                                                                                                            
    %let NumSites      = 10;                                                                                                            
    %let SiteCapacity  = 35;                                                                                                            
    %let MaxDemand     = 10;                                                                                                            
    %let xmax          = 200;                                                                                                           
    %let ymax          = 100;                                                                                                           
    %let seed          = 45678;                                                                                                             
                                                                                                                                        
   /* generate random customer locations */                                                                                             
   data cdata(drop=i);                                                                                                                  
      length name $8;                                                                                                                   
      do i = 1 to &NumCustomers;                                                                                                        
         name = compress('C'||put(i,best.));                                                                                            
         x = ranuni(&seed) * &xmax;                                                                                                     
         y = ranuni(&seed) * &ymax;                                                                                                     
         demand = ranuni(&seed) * &MaxDemand;                                                                                           
         output;                                                                                                                        
      end;                                                                                                                              
   run;                                                                                                                                 
                                                                                                                                        
   /* generate random site locations and fixed charges */                                                                                
   data sdata(drop=i);                                                                                                                  
      length name $8;                                                                                                                   
      do i = 1 to &NumSites;                                                                                                            
         name = compress('SITE'||put(i,best.));                                                                                         
         x = ranuni(&seed) * &xmax;                                                                                                     
         y = ranuni(&seed) * &ymax;                                                                                                     
         fixed_charge = (abs(&xmax/2-x) + abs(&ymax/2-y)) / 2;                                                                
         output;                                                                                                                        
      end;                                                                                                                              
   run;                                                                                                                                 
                                                                                                                                        
   cas sascas1;

   proc cas; setsessopt/metrics=true; run; quit;

   libname mycaslib cas sessref=sascas1;

   proc optmodel sessref=sascas1 presolver=none;                                                                                                                       
      set <str> CUSTOMERS;                                                                                                              
      set <str> SITES;                                                                                                                  
                                                                                                                                        
      /* x and y coordinates of CUSTOMERS and SITES */                                                                                  
      num x {CUSTOMERS union SITES};                                                                                                    
      num y {CUSTOMERS union SITES};                                                                                                    
      num demand{CUSTOMERS};                                                                                                            
      num fixed_charge {SITES};                                                                                                         
                                                                                                                                        
      /* distance from customer i to site j */                                                                                          
      num dist {i in CUSTOMERS, j in SITES}                                                                                             
          = sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2);                                                                                    
                                                                                                                                        
      read data cdata into CUSTOMERS=[name] demand;
	  read data sdata into SITES=[name] fixed_charge;
      read data cdata into [name] x y;                                                                                 
      read data sdata into [name] x y;                                                                               
                                                                                                                                        
      var Assign {CUSTOMERS, SITES} binary;                                                                                             
      var Build {SITES} binary;                                                                                                         
                                                                                                                                        
      min CostNoFixedCharge                                                                                                             
          = sum {i in CUSTOMERS, j in SITES} dist[i,j] * Assign[i,j];                                                                   
      min CostFixedCharge                                                                                                               
          = CostNoFixedCharge + sum {j in SITES} fixed_charge[j] * Build[j];                                                            
                                                                                                                                        
      /* each customer assigned to exactly one site */                                                                                  
      con assign_def {i in CUSTOMERS}:                                                                                                  
         sum {j in SITES} Assign[i,j] = 1;                                                                                              
                                                                                                                                        
      /* if customer i assigned to site j, then facility must be built at j */                                                          
      con link {i in CUSTOMERS, j in SITES}:                                                                                            
          Assign[i,j] <= Build[j];                                                                                                      
                                                                                                                                        
      /* each site can handle at most &SiteCapacity demand */                                                                           
      con capacity {j in SITES}:                                                                                                        
          sum {i in CUSTOMERS} demand[i] * Assign[i,j] <= &SiteCapacity * Build[j];                                                     

*****************************************************;

      /* solve the milp with no fixed charges */                                                                                        
      solve obj CostNoFixedCharge;                                                                                                      
                                                                                                                                        
      /* clean up the solution */                                                                                                       
      for {i in CUSTOMERS, j in SITES} Assign[i,j] = round(Assign[i,j],1E-4);                                                                
      for {j in SITES} Build[j] = round(Build[j],1E-6);                                                                                      
      
      num varcost = sum {i in CUSTOMERS, j in SITES} dist[i,j] * Assign[i,j].sol;      
      call symput('varcostNo',compress(put(CostNoFixedCharge,12.1)));                                                                   
                                                                                                                                        
      /* create a data set for use by gplot */                                                                                          
      create data CostNoFixedCharge_Data from                                                                                           
          [customer site]={i in CUSTOMERS, j in SITES: Assign[i,j] = 1}                                                                 
          xi=x[i] yi=y[i] xj=x[j] yj=y[j];                                                                                              

*****************************************************; 
 
      /* solve the milp with fixed charges */                                                                                           
      solve obj CostFixedCharge;     
      	 
      /* clean up the solution */                                                                                                                              
      for {i in CUSTOMERS, j in SITES} Assign[i,j] = round(Assign[i,j],1E-4);                                                                
      for {j in SITES} Build[j] = round(Build[j],1E-6);                                                                                                                                                                                                                     
                                                        
      num fixcost = sum {j in SITES} fixed_charge[j] * Build[j].sol;                                                                    
      call symput('varcost',compress(put(varcost,12.1)));                                                                               
          call symput('fixcost',compress(put(fixcost,12.1)));                                                                           
          call symput('totalcost',compress(put(CostFixedCharge,12.1)));                                                                 
                                                                                                                                        
      /* create a data set for use by gplot */                                                                                          
      create data CostFixedCharge_Data from                                                                                             
          [customer site]={i in CUSTOMERS, j in SITES: Assign[i,j] = 1}                                                                 
          xi=x[i] yi=y[i] xj=x[j] yj=y[j];   
                                                                                                                                    
      quit; 

/* prepare customer and site location data for plotting */                                                     
data csdata;                                                                                                                        
    set cdata(rename=(y=cy)) sdata(rename=(y=sy));                                                                                  
run;                                                                                                                                
  
/* plot customer and candidate site locations */
title1 "Facility Location Problem";                                                                                                 
title2 "Customer Locations and Candidate Sites";            
proc sgplot data=csdata noautolegend; 
   xaxis display=(nolabel); 
   yaxis display=(nolabel); 
   scatter y=cy x=x / datalabel=name;
   scatter y=sy x=x / datalabel=name;
run;

/* plot optimal solution (no fixed site costs)*/                                                                                                                             
title1 "Facility Location Problem";                                                                                                 
title2 "TotalCost = &varcostNo (Variable = &varcostNo, Fixed = 0)";                                                                 

/* create annotate data set to draw line between customer and assigned site */                                                                                                                                                                        
data sganno;
   retain drawspace "datavalue" linethickness 1 function 'line';
   set CostNoFixedCharge_Data(rename=(xi=x1 yi=y1 xj=x2 yj=y2));
run;
proc sgplot data=csdata noautolegend sganno=sganno;
   xaxis display=(nolabel); 
   yaxis display=(nolabel); 
   scatter y=cy x=x / datalabel=name;
   scatter y=sy x=x / datalabel=name;
run;
                                                                                                                                
/* plot optimal solution (include fixed site costs)*/                                                                                                                                        
title1 "Facility Location Problem";                                                                                                 
title2 "TotalCost = &totalcost (Variable = &varcost, Fixed = &fixcost)";
                                                            
/* create annotate data set to draw line between customer and assigned site */                                                      
data sganno;
   retain drawspace "datavalue" linethickness 1 function 'line';
   set CostFixedCharge_Data(rename=(xi=x1 yi=y1 xj=x2 yj=y2));
run;
proc sgplot data=csdata noautolegend sganno=sganno;
   xaxis display=(nolabel);
   yaxis display=(nolabel);
   scatter y=cy x=x / datalabel=name;
   scatter y=sy x=x / datalabel=name;
run;                                                                                                                              
                                       
title;
