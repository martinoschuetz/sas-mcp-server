/* Telnet läuft auf Port 2923 */
%let server=gertest008 2923;
filename rlink "!SASROOT\connect\saslink\tcpwin.scr";

options source source2 comamid=tcp;
options remote=server;
 
SIGNON;
Rsubmit;

/* your SAS code */

EndRsubmit;
Signoff;

filename rlink clear;
