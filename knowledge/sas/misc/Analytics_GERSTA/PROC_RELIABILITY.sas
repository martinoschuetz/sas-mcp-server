
ODS LISTING close;
ODS HTML;
goptions DEV=GIF ftext=SWISSB;
libname opel "C:\Opel";
	  proc reliability data=opel.weibulldata;
      distribution weibull;
      pplot time=voltage /  PINTERVALS=LIKELIHOOD;
   run;

ODS HTML close;
ODS LISTING;
