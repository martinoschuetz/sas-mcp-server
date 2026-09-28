%let remhost=GERTEST008.GER.SAS.COM;
%let userid=sasdemo;                /* UserId für Host          */
%let passwort=SASpw1;               /* Passwort                 */
%let Port=7551;                     /* Workspace Server V9.1.3  */

/* SAS Optionen setzen */
%let HOST=&remhost &Port;
options source source2 comamid=tcp;

SIGNON HOST user=&UserID password=&Passwort;
Rsubmit;

/* your SAS progam */

endRsubmit;
SIGNOFF;

/* Das geht auch */
%let TEST008=gertest008.ger.sas.com 7551;
signon TEST008 user=_prompt_;
Rsubmit;

/* your SAS progam */

endRsubmit;

Signoff;

