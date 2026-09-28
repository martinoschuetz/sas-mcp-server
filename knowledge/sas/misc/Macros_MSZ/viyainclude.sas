%macro viyainclude(folder=, sasfile=);
	%let fileref = _%substr(&sasfile.,1,7);
	filename &fileref. filesrvc folderpath="&folder." filename="&sasfile.";

	%include &fileref.;
%mend viyainclude;

*%viyainclude(folder=&root.,sasfile=01_setup.sas);