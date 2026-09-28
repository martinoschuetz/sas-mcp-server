option cashost="rdcgrd001" casinstall="/opt/vbviya/laxnd/TKGrid" casuserid=saswtj casport=45026;
proc casoperate host="rdcgrd001.unx.sas.com"
     setupfile="/u/saswtj/v930nopp/smpnodbgnd.cfg" start start=(term=yes);
quit;

cas  mysess sessopts=(nworkers=3);
libname mylib cas sessref=mysess;
run;

data sales(keep=Country StoreNum StoreType DATE sales);
     length Country StoreType $32;
     format DATE DATE.;
     Country = "UK";
     set sashelp.air(obs=31);
     DATE = INTNX('DAY','01DEC2018'D,_n_-1);
     sales = air;
     do StoreNum = 1 to 3;
        StoreType = "Express";
        if ( MOD(StoreNum,3) EQ 0 ) then StoreType = "Super";
        output;
     end;
     Country = "US";
     do StoreNum = StoreNum to 10;
        StoreType = "Express";
        if ( MOD(StoreNum,3) EQ 0 ) then StoreType = "Super";
        output;
     end;
run;


proc sort data=sales out=sales;
by Country StoreNum DATE;
run;
proc print; run;

data schooldata(keep=Country StoreNum StoreType schoolclosure);
     length Country StoreType $32;
     format schoolclosure DATE.;
     Country = "UK";
     schoolclosure = '10DEC2018'D;
     do StoreNum = 1 to 3;
        StoreType = "Express";
        if ( MOD(StoreNum,3) EQ 0 ) then StoreType = "Super";
        schoolclosure = schoolclosure + StoreNum;
        output;
     end;
     Country = "US";
     schoolclosure = schoolclosure + 1;
     do StoreNum = StoreNum to 10;
        StoreType = "Express";
        if ( MOD(StoreNum,3) EQ 0 ) then StoreType = "Super";
        schoolclosure = schoolclosure + StoreNum;
        output;
     end;
run;

data mylib.schooldata;
     set schooldata;
run;

data mylib.sales;
     set sales;
run;


proc tsmodel data      = mylib.sales  
             inscalar=mylib.schooldata 
             LOGCONTROL= (ERROR = KEEP WARNING = KEEP NOTE=KEEP)
             outlog    = mylib.OUTLOG_ind (replace = YES)
             outobj     = (
                              outEVENT     = mylib.outevent (replace = YES)
                              outEVDUM     = mylib.evdum    (replace = YES)
                          ) 
                  errorstop = YES
               ;
    
     by Country StoreNum ;
     id date interval=day trimid=left;
     var sales/ accumulate=total;
     inscalar schoolclosure;

     require atsm;

     submit;

         declare object outEVENT(outevent);  

         declare object dataFrame(tsdf);

         declare object eventDB(event);
         rc = eventDB.Initialize();

         rc = eventDB.EventDef("SchoolClosing",
                               "startdate",schoolclosure,
                               "enddate",schoolclosure+30,
                               'pulse','day');

         if  Country EQ "UK" then do;
             rc = eventDB.EventKey("Boxing");
         end;
         rc = eventDB.EventKey("Christmas");

         if  StoreType EQ "Super" then do;
             rc = eventDB.EventKey("Christmas","SHIFT",-1);
         end;
         rc = outEVENT.collect(eventDB); 

         rc = dataFrame.Initialize(); if rc < 0 then do; stop; end;
         rc = dataFrame.AddEvent(eventDB, '_all_'); 
         

         declare object outEvDum(outEventDummy);
         rc = outEvDum.collect(dataFrame);

     endsubmit;
run;
quit;

title "TSMODEL - definitions";
proc print data=mylib.outevent; 
format _STARTDATE_ _ENDDATE_ DATE.;
run;
        
proc sort data=mylib.evdum out=EventsInTSDF;                           
     by date;                                                         
run;                                                                  
proc transpose data=EventsInTSDF  
               out=evdumtsm(drop= _label_ _NAME_);  
var X;                                                                
id _XVAR_;                                                            
by date;                                                              
run; 

proc print data=EventsInTSDF; run;
