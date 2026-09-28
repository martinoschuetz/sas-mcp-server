%macro read_attributes(ds=, fn=, shortfn=);

	data &ds.(drop=val F:);
		attrib id 		 length=$200  format=$CHAR200.  informat=$CHAR200.;
		attrib attr length=$256  format=$CHAR256.  informat=$CHAR256.;
		attrib val	 length=$1024 format=$CHAR1024. informat=$CHAR1024.;
		attrib F4	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F5	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F6	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F7	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F8	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F9	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F10	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F11	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F12	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F13	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F14	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F15	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		attrib F16	 	length=$200 format=$CHAR200. informat=$CHAR200.;
		infile "&fn."
		DLM=";" ENCODING="WLATIN1" MISSOVER DSD lrecl=32767 firstobs=1;
		input
			id	$ attr $ val $
			F4 $ F5 $ F6 $ F7 $ F8 $ F9 $ F10 $ F11 $ F12 $ F13 $ F14 $ F15 $ F16 $;
		id 		 = strip(id);
		attr	 = strip(attr);
		val		 = strip(val);
		value	 = catx(" ",val, strip(F4), strip(F5), strip(F6), strip(F7), strip(F8), strip(F9), strip(F10), strip(F11), strip(F12), strip(F13), strip(F14), strip(F15), strip(F16));
		SnapShot = substr("&shortfn.",1,10);
	run;
	
%mend;