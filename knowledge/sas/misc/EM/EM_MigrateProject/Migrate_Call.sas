options mprint;
%PUT %SYSFUNC(getOption(ENCODING));

%include "D:\Codes\EM\EM_MigrateProject\EM_MigrateProject.sas";

%EM_MigrateProject(	Action=PREPARE,
					RootPath=D:\EM\aCRM Churn Insurance,
					VERBOSE=ON,
					CLEAN=ON,
					INCVIEWS=OFF);

libname emws1 'D:\EM_UTF8\aCRM Churn Bank\Workspaces\EMWS1';
libname emws2 'D:\EM_UTF8\aCRM Churn Bank\Workspaces\EMWS2';

%EM_MigrateProject(	Action=RESTORE,
					RootPath=D:\EM_UTF8\aCRM Churn Insurance,
					VERBOSE=ON,
					CLEAN=ON,
					INCVIEWS=OFF);
