libname ins "C:\DATEN\VERS";

data ins.dummy;
  infile "C:\daten\vers\motorins.dat" DLM='09'X Firstobs=2;
  input km0 zone0 bonus make0 insured claims payment;
run;

data ins.motorins (drop=km0 zone0 make0);
  set ins.dummy;
  length km $ 20;
  length zone $ 40;
  length make $ 12;
  label km ="Kilometer-Klasse"
        zone = "Geographische Zone"
		bonus = "Bonus für Schadensfreiheit"
		Make = "Automobil-Hersteller"
		Insured = "Anzahl Versicherungen (Policen-Jahre)"
		claims = "Anzahl Schadensfälle"
		payment ="Zahlungen in SKr";
  if km0 = 1 then km='weniger als 1.000';
  else if km0=2 then km='1.000 bis 15.000';
  else if km0=3 then km='15.000 bis 20.000';
  else if km0=4 then km='20.000 bis 25.000';
  else if km0=5 then km='mehr als 25.000';
  if zone0=1 then zone='Stockholm, Göteborg, Malmö';
  else if zone0=2 then zone='Mittelstädte';
  else if zone0=3 then zone='Kleinstädte Südschweden';
  else if zone0=4 then zone='Ländliche Region Südschweden';
  else if zone0=5 then zone='Kleinstädte Nordschweden';
  else if zone0=6 then zone='Ländliche Region Nordschweden';
  else if zone0=7 then zone='Gotland';
  if make0=1 then make='Hersteller 1';
  else if make0=2 then make='Hersteller 2';
  else if make0=3 then make='Hersteller 3';
  else if make0=4 then make='Hersteller 4';
  else if make0=5 then make='Hersteller 5';
  else if make0=6 then make='Hersteller 6';
  else if make0=7 then make='Hersteller 7';
  else if make0=8 then make='Hersteller 8';
  else if make0=9 then make='Sonstige';
run;
