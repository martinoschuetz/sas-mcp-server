*  Begin EG generated code (do not edit this line);
*
*  Stored process registered by
*  Enterprise Guide Stored Process Manager V7.1
*
*  ====================================================================
*  Stored process name: Stored Process for Tenary Plot
*  ====================================================================
*;


*ProcessBody;

%STPBEGIN;

*  End EG generated code (do not edit this line);


/* --- Start of code for "Tenary Plot". --- */
libname jmppkg "&_STPWORK";
filename stpwork "&_STPWORK";


* This SAS code is used to return the jmp script from the stored process;
data _null_;
   file stpwork(Plot.jsl) encoding="utf-16le" BOM;
*  Read JSL file from an embedded datalines4 section;  
   infile datalines4 length=len;
*  Set up a line variable that can contain 32K chars;  
   length line $32676;
*  Set up a continuedline variable that can contain 4000 chars;  
   length continuedline $4000;
*  Set up a one char cont (continuation) variable.
*  This will be used to determine if one of the embedded script
*  lines is a continuation of a previous line;
   length cont $1;
*  Start the input at the current file location.
*  This will set the 'len' variable to the lenght of the line to be read;
   input @;
*  Calculate the size of the JSL line (minus one for the continuation char);
   llen = len - 1;
*  Read the continuation character, then the JSL line;
   input @1 cont $1 @2 line $varying. llen;
*  If the '*' continuation character is found, then keep reading lines
*  until no more continuations around found.  Each continuation line 
*  will be appended to the current line (at least up to 32K chars)
*  lines are trimed, which theorically could cause a problem if a
*  continuation were encountered within a really long quoted 
*  whitespace, but since lines can be 4000 characters long this
*  is very unlikely.  Hopefully, ever JSL line will fit on 
*  one datalines4 line, without need of continuation;
   do while (cont = '*');
      input @1 cont $1 @2 continuedline $varying. llen;
      line = trim(line)||continuedline;
      end;
   line = trim(line);
*  Write the line into the output file (package);
   put line;
*  Start the dataline4 section
*  NOTE: Each line of the dataline4 section is formatted as follows:
*       Column 1: A one character continuation character.  If this character is
*                 '*' then this line is continued on the next line and the lines
*                 will be concatenated.  If it contains a character other than '*'
*                 it is assumed that the current line is not continued.  This
*                 might change in the future, if other uses are needed for this first
*                 column.  IN ALL CASES THE FIRST CHARACTER (COLUMN 1) IS DISCARDED.
*       Column 2-4001: The actual JSL script line
*  Why is this done?
*      In order to embed the JSL within the SAS language we must make sure that
*      the semantic nature of one doesn't interact with the other.  It would be 
*      'bad' if a line of semi-colon characters found in the middle of a JSL script 
*      were to be interpreted as a datalines4 termination.  By offseting the JSL 
*      script by one character (column) it is not possible for the contents of the 
*      JSL script to accidently terminate the datalines4 section.  This ensures that
*      the JSL script contents will not interact in an unintended way with the 
*      executing SAS code.  And also ensure that JSL with extremely long lines
*      will be handled in a reasonable and forgiving way;
   datalines4;
 Ternary Plot( Y( :Age, :Height, :Weight ), Color Theme( "" ) )
;;;;
run;


proc copy in=SASHELP out=jmppkg;
   select CLASS;
run;
proc datasets nodetails nolist library=jmppkg;
   change CLASS=Class;
run; quit;

/* --- End of code for "Tenary Plot". --- */

*  Begin EG generated code (do not edit this line);
;*';*";*/;quit;
%STPEND;

*  End EG generated code (do not edit this line);

