libname samples "D:\Metadata\samples\data";

data samples.sample_orga;
	attrib 	ou_nr 			label="OU Nr" 			length=3
			parent_ou_nr 	label="Parent OU Nr" 	length=3
			ou_level 		label="OU Level" 		length=3
			ou_name 		label="OU Name" 		length=$35
			ou_type 		label="OU Type" 		length=$10
			ou_key 			label="OU Key" 			length=$15
	;

	ou_nr 		 = 0; parent_ou_nr = .; ou_level     = 0;
	ou_name		 = "0. Konzern";
	ou_type      = "total";
	ou_key		 = "0.$";
	output;

	ou_nr 		 = 1; parent_ou_nr = 0; ou_level     = 1;
	ou_name		 = "1. Region EMEA";
	ou_type      = "region";
	ou_key		 = "0.1.$";
	output;

	ou_nr 		 = 2; parent_ou_nr = 0; ou_level     = 1;
	ou_name		 = "2. Region Amerika";
	ou_type      = "region";
	ou_key		 = "0.2.$";
	output;

	ou_nr 		 = 3; parent_ou_nr = 0;
	ou_name		 = "3. Dienstleistungen";
	ou_level     = 1;
	ou_type      = "service";
	ou_key		 = "0.3.$";
	output;

	ou_nr 		 = 4; parent_ou_nr = 1;
	ou_name		 = "1.1. Unternehmen Deutschland";
	ou_level     = 2;
	ou_type      = "country";
	ou_key		 = "0.1.1.$";
	output;

	ou_nr 		 = 5; parent_ou_nr = 1;
	ou_name		 = "1.2. Unternehmen Frankreich";
	ou_level     = 2;
	ou_type      = "country";
	ou_key		 = "0.1.2.$";
	output;

	ou_nr 		 = 6; parent_ou_nr = 2;
	ou_name		 = "2.1. Unternehmen USA";
	ou_level     = 2;
	ou_type      = "country";
	ou_key		 = "0.2.1.$";
	output;

	ou_nr 		 = 7; parent_ou_nr = 4;
	ou_name		 = "1.1.1. Geschäftseinheit Vertrieb";
	ou_level     = 3;
	ou_type      = "division";
	ou_key		 = "0.1.1.1.$";
	output;

	ou_nr 		 = 8; parent_ou_nr = 4;
	ou_name		 = "1.1.2. Geschäftseinheit Marketing";
	ou_level     = 3;
	ou_type      = "division";
	ou_key		 = "0.1.1.2.$";
	output;

	ou_nr 		 = 9; parent_ou_nr = 5;
	ou_name		 = "1.2.1. Geschäftseinheit Vertrieb";
	ou_level     = 3;
	ou_type      = "division";
	ou_key		 = "0.1.2.1.$";
	output;

	ou_nr 		 = 10; parent_ou_nr = 5;
	ou_name		 = "1.2.2. Geschäftseinheit Marketing";
	ou_level     = 3;
	ou_type      = "division";
	ou_key		 = "0.1.2.2.$";
	output;

	ou_nr 		 = 11; parent_ou_nr = 6;
	ou_name		 = "2.1.1. Geschäftseinheit Vertrieb";
	ou_level     = 3;
	ou_type      = "division";
	ou_key		 = "0.2.1.1.$";
	output;

	ou_nr 		 = 12; parent_ou_nr = 6;
	ou_name		 = "2.1.2. Geschäftseinheit Marketing";
	ou_level     = 3;
	ou_type      = "division";
	ou_key		 = "0.2.1.2.$";
	output;

	ou_nr 		 = 13; parent_ou_nr = 3;
	ou_name		 = "3.1. Personalwesen";
	ou_level     = 2;
	ou_type      = "service";
	ou_key		 = "0.3.1.$";
	output;

	ou_nr 		 = 14; parent_ou_nr = 3;
	ou_name		 = "3.2. IT";
	ou_level     = 2;
	ou_type      = "service";
	ou_key		 = "0.3.2.$";
	output;

	ou_nr 		 = 15; parent_ou_nr = 7;
	ou_name		 = "1.1.1.1. Vertrieb Nord";
	ou_level     = 4;
	ou_type      = "region";
	ou_key		 = "0.1.1.1.1.$";
	output;

	ou_nr 		 = 16; parent_ou_nr = 7;
	ou_name		 = "1.1.1.2. Vertrieb Süd";
	ou_level     = 4;
	ou_type      = "region";
	ou_key		 = "0.1.1.1.2.$";
	output;

	ou_nr 		 = 17; parent_ou_nr = 11;
	ou_name		 = "2.1.1.1. Vertrieb Ost";
	ou_level     = 4;
	ou_type      = "region";
	ou_key		 = "0.2.1.1.1.$";
	output;

	ou_nr 		 = 18; parent_ou_nr = 11;
	ou_name		 = "2.1.1.2. Vertrieb West";
	ou_level     = 4;
	ou_type      = "region";
	ou_key		 = "0.2.1.1.2.$";
	output;
run;

data samples.sample_orga_sec;
	attrib 	ou_key 			label="OU Key" 			length=$15
			sas_personname	label="SAS PersonName"	length=$20
	;

	ou_key 			= "0.";
	sas_personname 	= "SAS Demo User";
	output;

	ou_key 			= "0.";
	sas_personname 	= "SAS Developer";
	output;

	ou_key 			= "0.2.1.1.";
	sas_personname 	= "SAS Web User";
	output;
	ou_key 			= "0.1.2.1.";
	sas_personname 	= "SAS Web User";
	output;
run;

/*
proc sql;
SELECT  DISTINCT 
	table0.ou_name AS DIR_4 LABEL='OU Name',
	table0.ou_key AS DIR_5 LABEL='OU Key',
	table1.sas_personname AS DIR_8 LABEL='SAS PersonName' ,
	table1.ou_Key AS DIR_8 LABEL='ID OU Key'
FROM
	samples.SAMPLE_ORGA table0 left join 
		samples.SAMPLE_ORGA_SEC table1 on  ( (table0.ou_key contains trim(table1.ou_key)) )  
WHERE
	table1.sas_personname = 'SAS Developer'
;
quit;
*/
