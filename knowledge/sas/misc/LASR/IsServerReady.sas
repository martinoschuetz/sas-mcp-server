%macro IsServerReady(
  URL=
 );
  %global ServerStatus;
  /* PROC HTTP */
  filename hout temp;
  proc http
     headerout=hout
     url="&URL."
     method="GET"
     CT="Text/HTML; charset=ISO-8859-4"
     ;
  run; 
  %let ServerStatus=Not_Ready;
  data _null_;
    length Status $5 Message $500;
    infile hout;
    input;
    if scan(_infile_,1,'/') = 'HTTP' then do;
      Status = scan(_infile_,2,' ');
      Message = substr(_infile_,indexw(_infile_,Status)+length(Status));
  /*    put _infile_;*/
  /*    put Status= Message=;*/
      if Status = '200' then call symput('ServerStatus','OK');
    end;
  run;
  filename hout clear;
  %put &URL.: &ServerStatus;
%mend;

