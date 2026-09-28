libname corresp "C:\Temp";

data corresp.analysis_data (keep=hauptwarengruppe kundentyp value;
  set corresp.querschnitt_kundentyp;
  if value=. then delete;
run; 
 


proc corresp all data=corresp.analysis_data outc=corresp.coordinates; 
      tables Kundentyp, Hauptwarengruppe; 
	  weight value;
      run; 
 

%plotit(data=corresp.coordinates, datatype=corresp) 
