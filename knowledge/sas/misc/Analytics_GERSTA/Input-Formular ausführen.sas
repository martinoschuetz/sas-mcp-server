/*   This stored process creates a custom HTML FORM that is      */
/*   used to execute another stored process.                     */
/*                                                               */
/*   Insert your HTML statements after the CARDS4 statement.     */
/*   Modify the "%let stpname" statement to specify the name     */
/*   of the next stored process that is to be executed.          */
/*   Any macro variables in the INPUT cards will be resolved     */
/*   if the values are known.                                    */

/* stpname is the name of the next stored process to be executed */

%let stpname=/Shared Data/My Stored Processes/STP_InputHTML.sas;

data _null_; 
  format infile $char256.; 
  input;
  infile = resolve(_infile_);
  file _webout;
  put infile;
cards4;
<HTML>
<BODY> 
<H1>Sample: Frequency Analysis of Municipalities</H1>
Beispiel
<FORM ACTION="&_URL">
<INPUT TYPE="HIDDEN" NAME="_program" VALUE="&stpname">
<HR>
Choose a table to display:<BR>
<INPUT TYPE=RADIO NAME="table" value="city*dept" CHECKED>City by Dept<BR>
<INPUT TYPE=RADIO NAME="table" value="city*week">City by Week<BR>
<INPUT TYPE=RADIO NAME="table" value="dept*week">Dept by Week<BR>
<HR>
<INPUT TYPE="SUBMIT" VALUE="Run Procedure">
<INPUT TYPE="CHECKBOX" NAME="_debug" VALUE="log">Show SAS Log
</FORM>
</BODY>
</HTML>
;;;;
run;