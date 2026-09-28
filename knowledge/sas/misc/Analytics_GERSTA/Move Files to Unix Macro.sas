
 

%macro ftpfile(localfile,localdir,remotefile,remotedir,remotehost,ftpcommand);            

options comamid=tcp nosymbolgen;
filename sasparm "!mysasfiles\sasparm"; /*location of a file containing the username and password for access */

   %global rmtuser rmtpw rc;

   /* read in the username and password and create macrovars rmtuser rmtpw*/
   data _null_;
	   length rmtuser rmtpw $30.;
	   infile sasparm;
	   input rmtuser $
		 rmtpw $
		    ;
	call symput('rmtuser',trim(rmtuser));
	call symput('rmtpw',trim(rmtpw));
	run;
 
	/* Set a filename FTP statement to remote file */
    filename rmfile ftp "&remotefile" cd="&remotedir." host="&remotehost." user="&rmtuser." pass="&rmtpw.";          
 
   %if &ftpcommand = get %then      /*i.e. download remotefile to the Local file */                                
    %do; 
 
	    /* Check if the file exists */
		%let rc=%sysfunc(fexist(rmfile));
		%*****If unable to establish a filename, send error stop;
		%if (&rc eq 0)%then 
	        %do;
				%put ******Unable to establish FTP connection to file--&rc.;
				%put ******Problem with input file: &remotefile.;
				%let rc= -1;
			%end; 
        %else 
		    %do;
			    %put ******Establish FTP connection to file--&remotefile;		 
 
		        data _null_;                                                
			        infile rmfile;                                                
			        file "&localdir./&localfile.";                                 
			        input;                                                      
			        put _infile_;                                               
		        run;                                                        
 
				%let filrf=lclfile;
				%let rc=%sysfunc(filename(filrf,"&localdir./&localfile."));
			%end;
    %end;                                                           
   %else %if &ftpcommand = put %then                                
    %do;   
		/* Check if the file exists */
		%let filrf=lclfile;
		%let rc=%sysfunc(filename(filrf,"&localdir./&localfile."));
		%if &rc ne 0 %then 
		%do;
        	%put %sysfunc(sysmsg());
		%end;
		%else 
		%do;
	        data _null_;                                                
		        infile "&localdir./&localfile.";                                             
		        file rmfile;                                                  
		        input;                                                      
		        put _infile_;                                               
	        run;    
 
		    /* Check if the file exists */
			%let rc=%sysfunc(fexist(rmfile)); 
		 %end;
    %end;                                                           
 
%put ftp returncode:&rc;                                            
 
/* Abort the job with rc=16 for batch processes...
   Remove this line if you are using it in interactive sas..else your session will be ended 
*/  
%if &rc ne 0 %then %abort return 16; 
 
%mend ftpfile;                                                      
 
/* FTP test.sas from desktop to test1.sas on unix server */
 
%ftpfile(test.sas,C:\,test1.sas,/data/dev/sastechies/sas,server,put);
 
 
/* FTP test1.sas from Server to test1.sas on Desktop */
 
%ftpfile(test1.sas,C:\,test1.sas,/data/dev/sastechies/sas,server,get);


#