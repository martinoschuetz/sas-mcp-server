/* ---------------------------------------------------- */
%put ****        OK ... HORTONWORKSHORTONWORKSHIVEODBCINI = %sysget(HORTONWORKSHORTONWORKSHIVEODBCINI);
%put ****        OK ... LD_LIBRARY_PATH = %sysget(LD_LIBRARY_PATH);
%put ****        OK ... ODBCSYSINI      = %sysget(ODBCSYSINI);
%put ****        OK ... ODBCINI         = %sysget(ODBCINI);

%let HIVE_SCHEMA=sas_managed;

/* ---------------------------------------------------- */
libname myodbc odbc dsn="Inthadoop1 Hive" user=gerhje schema="&HIVE_SCHEMA.";

