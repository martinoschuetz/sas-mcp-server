
proc template;
  LINK styles.sasweb TO styles.paulaner / STORE=sasuser.templat; 
  define style styles.paulaner;
  style Body from Document / prehtml = "<table width=100%><td align=center>
	<img src=""C:\DATEN\PAUL\WORK\logo.jpg""></table>";
end;
run;
