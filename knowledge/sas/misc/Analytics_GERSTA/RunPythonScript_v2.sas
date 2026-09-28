/* Put name of image file and path where file is located here */
%let picname=bild.jpg;
%let pathname=C:\TEMP;





/* Convert path*/
%let p2 = %sysfunc(tranwrd(&pathname,\,//));
%put p2=&p2;


/* Create python script */
filename abc "&pathname.\pixelator.py";
data _null_;
file abc;
put "from PIL import Image";
put "import csv";
put "from itertools import izip";
put "image_file = '&p2//&picname'";
put "image = Image.open(image_file)";
put "mc_im = image.convert('L')";
put "size=image.size";
put "max_x=size[0]";
put "max_y=size[1]";
put "xpixel=[]";
put "ypixel=[]";
put "mcvalue=[]";
put "for i in range(max_x):";
put "    for j in range(max_y):";
put "       mc = mc_im.getpixel((i, j))";
put "       xpixel.append(i+1)";
put "       ypixel.append(j+1)";
put "       mcvalue.append(mc)";
put "coordinates=zip(xpixel,ypixel, mcvalue)";
put "with open('&p2//output.csv', 'wb') as myfile:";
put "    wr = csv.writer(myfile, delimiter=';', quoting=csv.QUOTE_MINIMAL)";
put "    wr.writerows(coordinates)";
run;

data _null_;
 call sleep(2,1);
run;

/* Sample Program to embed python script into SAS */
data _null_;
x "C:\Python\python.exe &pathname\pixelator.py";
run;

/* Import generated csv file */
proc import datafile="&pathname\output.csv" dbms=csv replace out=tmp;
delimiter=';';
getnames=NO;
guessingrows=300;
run;

proc sql noprint; select max(var2) into:maxy from tmp; quit;

/* Convert y coordinate values and rename variables */
data tmp2;
 set tmp;
 Var2=abs(var2-&maxy);
 rename VAR1=X_Coordinate VAR2=Y_Coordinate VAR3=Monochrome;
run;



ODS GRAPHICS ON;
TITLE;
TITLE1 "Histograms of Monochrome values";
PROC UNIVARIATE DATA=tmp2 NOPRINT	;
	VAR Monochrome;
		HISTOGRAM ;

RUN; 

/* Delete temp files */
data _null_;
x "del C:\TEMP\*.csv";
x "del C:\TEMP\*.py";
run;
