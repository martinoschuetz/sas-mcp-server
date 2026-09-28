filename ip "D:\Projekte\samples\geoip\GeoLite2-Country-CSV_20150203\GeoLite2-Country-Blocks-IPv4.csv";
filename cn "D:\Projekte\samples\geoip\GeoLite2-Country-CSV_20150203\GeoLite2-Country-Locations-en.csv";

libname myhive "D:\Projekte\samples\geoip" compress=yes;

data ip;
	infile ip delimiter="," firstobs=2;
	attrib network registered_country_geoname_id represented_country_geoname_id is_anonymous_proxy is_satellite_provider length=$20
		geoname_id length=8;
	input network geoname_id registered_country_geoname_id represented_country_geoname_id is_anonymous_proxy is_satellite_provider;
run;

data ip (keep=geoname_id classb);
	set ip;
	length tmp tupel1 tupel2 classb $30;

	tupel1 = substr(network,1,index(network,'.')-1);
	tmp    = substr(network,index(network,'.')+1);
	tupel2 = substr(tmp,1,index(tmp,'.')-1);
	classb = cats(tupel1,'.',tupel2);
run;

data cn(drop=locale_code);
	infile cn delimiter="," firstobs=2;
	attrib locale_code continent_code continent_name country_iso_code country_name length=$50
		geoname_id length=8;
	input geoname_id locale_code continent_code continent_name country_iso_code country_name;
	country_name = strip(tranwrd(country_name,'"',""));
	continent_name = strip(tranwrd(continent_name,'"',""));
run;

proc sql;
	create table myhive.classb_net_country as 
		select classb, continent_code, continent_name, country_iso_code, country_name
			from ip inner join cn on ip.geoname_id=cn.geoname_id
			order by classb;
quit;
