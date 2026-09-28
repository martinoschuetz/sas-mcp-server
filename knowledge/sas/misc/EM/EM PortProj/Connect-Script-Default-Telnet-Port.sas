%let server=gertest008; /* Default Port (23) wird benutzt */
filename rlink "!SASROOT\connect\saslink\tcpwin.scr";

options source source2 comamid=tcp;
options remote=server;
 
SIGNON;
Rsubmit;

/* your SAS code */

EndRsubmit;
Signoff;

filename rlink clear;
