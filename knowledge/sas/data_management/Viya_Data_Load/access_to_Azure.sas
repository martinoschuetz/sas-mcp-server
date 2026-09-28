/* 	Data Connections to
	- Azure SQL
	- Azure Data Lake Storage (ADLGen2)
	- Azure Synapse
	Based on the presentation "SAS better together with Data in Azure"
	https://sasoffice365.sharepoint.com/:p:/r/sites/GlobalTechnologyPracticeEMEAAMERICAS/DATADecOPS/Shared%20Documents/1%20-%20SAS%20and%20Azure%20data%20stores.pptx?d=w636579a12a264ca6b8448acb49c1f269&csf=1&web=1&e=NCybmX
*/

/* Using ADLS2 as a file share for SAS data sets */
libname azshrlib "/mnt/myazurevol/data";

data azshrlib.fish_sas;
	set sashelp.fish;
run;

proc sql;
	select * from azshrlib.fish_sas;
	run;
quit;

/* 	ADLS2 with ORC 
	The ORC engine is a Base SAS LIBNAME engine that is supported in the SAS Compute Server with Viya
	Pre-requisites
	- User access to Azure Storage Account with Storage Blob Data Contributor role
	- Azure application with permission to access Azure Data lake and Azure Storage
*/
%let MYSTRGACC="eurigmviya4a