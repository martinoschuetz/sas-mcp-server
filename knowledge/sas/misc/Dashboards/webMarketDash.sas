/* This example uses SAS/GRAPH software to generate a version of the marketing
analysis dashboard described on p. 201 of  "Information Dashboard Design"
(Few, Stephen. 2006. Sebastopol, CA. O'Reilly Media, Inc.).  */

/* Specify the name for the output file. */
%let name=webMarketDash;
filename odsout '.';

/* Set the background color for the dashboard. */
%let backcolor=cxFFFFEb;

/* Set the colors for the background ranges in the bullet graphs. */
%let bullet1=gray99;
%let bullet2=graycc;
%let bullet3=grayef;

/* Set the color for bars and legend in plot7 and plot12. */
%let revenue_color=graybb;

/* Set the color for major titles and lines to split the dashboard into sections. */
%let majorcolor=cx50A6C2; 

/* Set the color for dark text and graphics and light text and graphics. */
%let black=black;
%let lighttext=gray88;

/* Define fonts for indicator and dashboard text. */
%let ftext='swiss';

/* Define the location of the HTML page that supplies drill-down details 
   for the indicator.  If you don't have Internet access, you must put
   the target HTML file where your browser can access it, then change the 
   following URL to point to your location. */
%let hardcoded_drilldown=http://support.sas.com/rnd/datavisualization/dashboards/generic_drilldown.htm;       

/***************************************************************************/
/* Create sample data sources for the dashboard indicators. */

/* Data for plot1 (MTD Compared to Target) */
data data1;
   format value percentn6.0;
   input barname $ 1-10 value target;
   datalines;
Visitors   0.90 0.75
Orders     1.60 0.60
;
run;

/* Data for plot2 (Percent of Total Visitors Today) */
data data2;
   format value percentn6.0;
   input barname $ 1-10 value target target2;
   datalines;
Registered 0.55 0.30 0.50
Repeat     0.90 0.60 0.80
;
run;

/* Data for plot3 (Visitors - Last 12 months) */
data data3;
   format visitor_deviation percentn6.0;
   input year month visitor_deviation;
   datalines;
2004  4 .30
2004  5 .27
2004  6 .34
2004  7 .36
2004  8 .32
2004  9 .08
2004 10 0
2004 11 .09
2004 12 .02
2005  1 .05
2005  2 .02
2005  3 -.04
;
run;

/* Data for plot4 (Visitors - This month) */
data data4;
   format visitor_deviation percentn6.0;
   input days visitor_deviation;
   datalines;
 1  .08
 2 -.02
 3 -.02
 4  .10
 5  .02
 6  .03
 7  .06
 8 -.20
 9 -.27
10 -.30
11  .06
12  .02
;
run;

/* Data for plot5 (Visitors - Today) */
data data5;
   format visitor_deviation percentn6.0;
   input hours visitor_deviation;
   datalines;
 1  .08
 2 -.01
 3  .04
 4 -.04
 5  .15
 6  .03
 7  .10
 8  .04
 9 -.05
10 -.08
11 -.05
12 -.02
13 -.09
14  .02
;
run;

/* Data for plot6 (Products - Sparklines) */
/* This sample uses full product names for simplicity. In a production 
   environment, these would probably be stored by a product code number 
   rather than having the full text of the product name with each line 
   of data. */
data data6;
   input product $ 1-40 timestamp percent_of_target;
   datalines;
Skirt - Business Casual - Black          1 .60    
Skirt - Business Casual - Black          2 .60    
Skirt - Business Casual - Black          3 .50    
Skirt - Business Casual - Black          4 .50    
Skirt - Business Casual - Black          5 .50     
Skirt - Business Casual - Black          6 .50    
Skirt - Business Casual - Black          7 .50    
Skirt - Business Casual - Black          8 .50    
Skirt - Business Casual - Black          9 .40    
Skirt - Business Casual - Black         10 .40    
Skirt - Business Casual - Black         11 .40    
Skirt - Business Casual - Black         12 .50    
Skirt - Business Casual - Black         13 .50    
Skirt - Business Casual - Black         14 .55    
Skirt - Business Casual - Black         15 .55    
Skirt - Business Casual - Black         16 .55    
Skirt - Business Casual - Black         17 .55    
Skirt - Business Casual - Black         18 .90    
Skirt - Business Casual - Black         19 .65    
Skirt - Business Casual - Black         20 .65    
Skirt - Business Casual - Black         21 .70    
Skirt - Business Casual - Black         22 .70    
Skirt - Business Casual - Black         23 .80    
Skirt - Business Casual - Black         24 1.00   
Skirt - Business Casual - Black         25 1.03   
Skirt - Business Casual - Black         26 1.10   
Skirt - Business Casual - Black         27 1.25   
Skirt - Business Casual - Black         28 1.30   
Skirt - Business Casual - Black         29 1.40   
Skirt - Business Casual - Black         30 1.50   
Shirt - Oxford - White                   1 1.10   
Shirt - Oxford - White                   2 1.10   
Shirt - Oxford - White                   3 1.10   
Shirt - Oxford - White                   4 1.10   
Shirt - Oxford - White                   5 1.00    
Shirt - Oxford - White                   6 1.00   
Shirt - Oxford - White                   7 1.00   
Shirt - Oxford - White                   8 1.00   
Shirt - Oxford - White                   9 .90    
Shirt - Oxford - White                  10 .90    
Shirt - Oxford - White                  11 .90    
Shirt - Oxford - White                  12 .80    
Shirt - Oxford - White                  13 .80    
Shirt - Oxford - White                  14 .80    
Shirt - Oxford - White                  15 .80    
Shirt - Oxford - White                  16 .80    
Shirt - Oxford - White                  17 .70    
Shirt - Oxford - White                  18 .70    
Shirt - Oxford - White                  19 .70    
Shirt - Oxford - White                  20 .70    
Shirt - Oxford - White                  21 .70    
Shirt - Oxford - White                  22 .70    
Shirt - Oxford - White                  23 .80    
Shirt - Oxford - White                  24 .80    
Shirt - Oxford - White                  25 .80    
Shirt - Oxford - White                  26 .80    
Shirt - Oxford - White                  27 .85    
Shirt - Oxford - White                  28 .85    
Shirt - Oxford - White                  29 .90   
Shirt - Oxford - White                  30 .90   
Shirt - Oxford - Blue                    1 1.00   
Shirt - Oxford - Blue                    2 1.00   
Shirt - Oxford - Blue                    3 1.00   
Shirt - Oxford - Blue                    4 1.00   
Shirt - Oxford - Blue                    5 1.00    
Shirt - Oxford - Blue                    6 1.20   
Shirt - Oxford - Blue                    7 1.20   
Shirt - Oxford - Blue                    8 1.20   
Shirt - Oxford - Blue                    9 1.20   
Shirt - Oxford - Blue                   10 1.20   
Shirt - Oxford - Blue                   11 1.20   
Shirt - Oxford - Blue                   12 1.20   
Shirt - Oxford - Blue                   13 1.20   
Shirt - Oxford - Blue                   14 1.20   
Shirt - Oxford - Blue                   15 1.20   
Shirt - Oxford - Blue                   16 1.20   
Shirt - Oxford - Blue                   17 1.20   
Shirt - Oxford - Blue                   18 1.20   
Shirt - Oxford - Blue                   19 1.20   
Shirt - Oxford - Blue                   20 .70    
Shirt - Oxford - Blue                   21 .70    
Shirt - Oxford - Blue                   22 .70    
Shirt - Oxford - Blue                   23 1.30   
Shirt - Oxford - Blue                   24 1.30   
Shirt - Oxford - Blue                   25 1.20   
Shirt - Oxford - Blue                   26 1.10   
Shirt - Oxford - Blue                   27 1.10   
Shirt - Oxford - Blue                   28 .95    
Shirt - Oxford - Blue                   29 .80   
Shirt - Oxford - Blue                   30 .70   
Men's Pants - Chino - Beige              1 1.00   
Men's Pants - Chino - Beige              2 1.00   
Men's Pants - Chino - Beige              3 1.00   
Men's Pants - Chino - Beige              4 1.00   
Men's Pants - Chino - Beige              5 1.00    
Men's Pants - Chino - Beige              6 1.00   
Men's Pants - Chino - Beige              7 1.00   
Men's Pants - Chino - Beige              8 1.00   
Men's Pants - Chino - Beige              9 1.00   
Men's Pants - Chino - Beige             10 1.10   
Men's Pants - Chino - Beige             11 1.10   
Men's Pants - Chino - Beige             12 1.10   
Men's Pants - Chino - Beige             13 1.10   
Men's Pants - Chino - Beige             14 1.10   
Men's Pants - Chino - Beige             15 1.10   
Men's Pants - Chino - Beige             16 1.10   
Men's Pants - Chino - Beige             17 1.10   
Men's Pants - Chino - Beige             18 1.10   
Men's Pants - Chino - Beige             19 1.10   
Men's Pants - Chino - Beige             20 1.20   
Men's Pants - Chino - Beige             21 1.20   
Men's Pants - Chino - Beige             22 1.20   
Men's Pants - Chino - Beige             23 1.20   
Men's Pants - Chino - Beige             24 1.20   
Men's Pants - Chino - Beige             25 1.30   
Men's Pants - Chino - Beige             26 1.30   
Men's Pants - Chino - Beige             27 1.30   
Men's Pants - Chino - Beige             28 1.30   
Men's Pants - Chino - Beige             29 1.30  
Men's Pants - Chino - Beige             30 1.30  
Blouse - Business Dress - White          1 0.90   
Blouse - Business Dress - White          2 0.90   
Blouse - Business Dress - White          3 0.90   
Blouse - Business Dress - White          4 0.80   
Blouse - Business Dress - White          5 0.80    
Blouse - Business Dress - White          6 0.90   
Blouse - Business Dress - White          7 0.90   
Blouse - Business Dress - White          8 0.90   
Blouse - Business Dress - White          9 0.95   
Blouse - Business Dress - White         10 1.00   
Blouse - Business Dress - White         11 1.00   
Blouse - Business Dress - White         12 1.05   
Blouse - Business Dress - White         13 1.05   
Blouse - Business Dress - White         14 1.10   
Blouse - Business Dress - White         15 1.20   
Blouse - Business Dress - White         16 1.30   
Blouse - Business Dress - White         17 1.40   
Blouse - Business Dress - White         18 1.50   
Blouse - Business Dress - White         19 1.60   
Blouse - Business Dress - White         20 1.40   
Blouse - Business Dress - White         21 1.20   
Blouse - Business Dress - White         22 1.00   
Blouse - Business Dress - White         23 0.95   
Blouse - Business Dress - White         24 0.90   
Blouse - Business Dress - White         25 0.85   
Blouse - Business Dress - White         26 0.80   
Blouse - Business Dress - White         27 0.80   
Blouse - Business Dress - White         28 0.75   
Blouse - Business Dress - White         29 0.75  
Blouse - Business Dress - White         30 0.75  
Shirt - Fitted Dress - White             1 0.40   
Shirt - Fitted Dress - White             2 0.50   
Shirt - Fitted Dress - White             3 0.50   
Shirt - Fitted Dress - White             4 0.60   
Shirt - Fitted Dress - White             5 0.70    
Shirt - Fitted Dress - White             6 0.80   
Shirt - Fitted Dress - White             7 0.90   
Shirt - Fitted Dress - White             8 0.90   
Shirt - Fitted Dress - White             9 0.95   
Shirt - Fitted Dress - White            10 1.00   
Shirt - Fitted Dress - White            11 1.00   
Shirt - Fitted Dress - White            12 1.05   
Shirt - Fitted Dress - White            13 1.05   
Shirt - Fitted Dress - White            14 1.10   
Shirt - Fitted Dress - White            15 1.20   
Shirt - Fitted Dress - White            16 1.30   
Shirt - Fitted Dress - White            17 1.40   
Shirt - Fitted Dress - White            18 1.40   
Shirt - Fitted Dress - White            19 1.30   
Shirt - Fitted Dress - White            20 1.30   
Shirt - Fitted Dress - White            21 1.20   
Shirt - Fitted Dress - White            22 1.20   
Shirt - Fitted Dress - White            23 1.25   
Shirt - Fitted Dress - White            24 1.30   
Shirt - Fitted Dress - White            25 1.30   
Shirt - Fitted Dress - White            26 1.35  
Shirt - Fitted Dress - White            27 1.35  
Shirt - Fitted Dress - White            28 1.40   
Shirt - Fitted Dress - White            29 1.40  
Shirt - Fitted Dress - White            30 1.45  
Men's Pants - Dress Cuffs -Black         1 1.10   
Men's Pants - Dress Cuffs -Black         2 1.08   
Men's Pants - Dress Cuffs -Black         3 1.05   
Men's Pants - Dress Cuffs -Black         4 1.02   
Men's Pants - Dress Cuffs -Black         5 1.01    
Men's Pants - Dress Cuffs -Black         6 1.00   
Men's Pants - Dress Cuffs -Black         7 0.95   
Men's Pants - Dress Cuffs -Black         8 0.95   
Men's Pants - Dress Cuffs -Black         9 0.90   
Men's Pants - Dress Cuffs -Black        10 0.80   
Men's Pants - Dress Cuffs -Black        11 0.60   
Men's Pants - Dress Cuffs -Black        12 0.65   
Men's Pants - Dress Cuffs -Black        13 0.55   
Men's Pants - Dress Cuffs -Black        14 0.50   
Men's Pants - Dress Cuffs -Black        15 0.40   
Men's Pants - Dress Cuffs -Black        16 0.40   
Men's Pants - Dress Cuffs -Black        17 0.30   
Men's Pants - Dress Cuffs -Black        18 0.30   
Men's Pants - Dress Cuffs -Black        19 0.20   
Men's Pants - Dress Cuffs -Black        20 0.20   
Men's Pants - Dress Cuffs -Black        21 0.30   
Men's Pants - Dress Cuffs -Black        22 0.30   
Men's Pants - Dress Cuffs -Black        23 0.45   
Men's Pants - Dress Cuffs -Black        24 0.40   
Men's Pants - Dress Cuffs -Black        25 0.50   
Men's Pants - Dress Cuffs -Black        26 0.55  
Men's Pants - Dress Cuffs -Black        27 0.65  
Men's Pants - Dress Cuffs -Black        28 0.70   
Men's Pants - Dress Cuffs -Black        29 0.80  
Men's Pants - Dress Cuffs -Black        30 0.90  
Women's Pants - Chino - Beige            1 0.60   
Women's Pants - Chino - Beige            2 0.58   
Women's Pants - Chino - Beige            3 0.65   
Women's Pants - Chino - Beige            4 0.52   
Women's Pants - Chino - Beige            5 0.61    
Women's Pants - Chino - Beige            6 0.60   
Women's Pants - Chino - Beige            7 0.65   
Women's Pants - Chino - Beige            8 0.65   
Women's Pants - Chino - Beige            9 0.60   
Women's Pants - Chino - Beige           10 0.60   
Women's Pants - Chino - Beige           11 0.70   
Women's Pants - Chino - Beige           12 0.75   
Women's Pants - Chino - Beige           13 0.85   
Women's Pants - Chino - Beige           14 0.80   
Women's Pants - Chino - Beige           15 0.90   
Women's Pants - Chino - Beige           16 1.00   
Women's Pants - Chino - Beige           17 1.20   
Women's Pants - Chino - Beige           18 1.20   
Women's Pants - Chino - Beige           19 1.10   
Women's Pants - Chino - Beige           20 1.10   
Women's Pants - Chino - Beige           21 1.05   
Women's Pants - Chino - Beige           22 1.05   
Women's Pants - Chino - Beige           23 1.00   
Women's Pants - Chino - Beige           24 1.00   
Women's Pants - Chino - Beige           25 0.90   
Women's Pants - Chino - Beige           26 0.85  
Women's Pants - Chino - Beige           27 0.75  
Women's Pants - Chino - Beige           28 0.70   
Women's Pants - Chino - Beige           29 0.60  
Women's Pants - Chino - Beige           30 0.60  
Skirt - Pleated - Beige                  1 .30    
Skirt - Pleated - Beige                  2 .30    
Skirt - Pleated - Beige                  3 .30    
Skirt - Pleated - Beige                  4 .35    
Skirt - Pleated - Beige                  5 .40     
Skirt - Pleated - Beige                  6 .40    
Skirt - Pleated - Beige                  7 .40    
Skirt - Pleated - Beige                  8 .40    
Skirt - Pleated - Beige                  9 .40    
Skirt - Pleated - Beige                 10 .40    
Skirt - Pleated - Beige                 11 .45    
Skirt - Pleated - Beige                 12 .50    
Skirt - Pleated - Beige                 13 .50    
Skirt - Pleated - Beige                 14 .55    
Skirt - Pleated - Beige                 15 .55    
Skirt - Pleated - Beige                 16 .50    
Skirt - Pleated - Beige                 17 .50    
Skirt - Pleated - Beige                 18 .60    
Skirt - Pleated - Beige                 19 .60    
Skirt - Pleated - Beige                 20 .65    
Skirt - Pleated - Beige                 21 .70    
Skirt - Pleated - Beige                 22 .70    
Skirt - Pleated - Beige                 23 .85    
Skirt - Pleated - Beige                 24 1.00   
Skirt - Pleated - Beige                 25 1.05   
Skirt - Pleated - Beige                 26 1.10   
Skirt - Pleated - Beige                 27 1.20   
Skirt - Pleated - Beige                 28 1.30   
Skirt - Pleated - Beige                 29 1.30   
Skirt - Pleated - Beige                 30 1.40   
Dress - Summer Casual - White            1 .30    
Dress - Summer Casual - White            2 .30    
Dress - Summer Casual - White            3 .30    
Dress - Summer Casual - White            4 .35    
Dress - Summer Casual - White            5 .40     
Dress - Summer Casual - White            6 .40    
Dress - Summer Casual - White            7 .40    
Dress - Summer Casual - White            8 .40    
Dress - Summer Casual - White            9 .40    
Dress - Summer Casual - White           10 .45    
Dress - Summer Casual - White           11 .50    
Dress - Summer Casual - White           12 .50    
Dress - Summer Casual - White           13 .50    
Dress - Summer Casual - White           14 .55    
Dress - Summer Casual - White           15 .55    
Dress - Summer Casual - White           16 .55    
Dress - Summer Casual - White           17 .55    
Dress - Summer Casual - White           18 .60    
Dress - Summer Casual - White           19 .65    
Dress - Summer Casual - White           20 .65    
Dress - Summer Casual - White           21 .70    
Dress - Summer Casual - White           22 .80    
Dress - Summer Casual - White           23 .90    
Dress - Summer Casual - White           24 1.00   
Dress - Summer Casual - White           25 1.03   
Dress - Summer Casual - White           26 1.10   
Dress - Summer Casual - White           27 1.25   
Dress - Summer Casual - White           28 1.30   
Dress - Summer Casual - White           29 1.35   
Dress - Summer Casual - White           30 1.40   
;
run;

/* Data for plot7 (Products - Revenue and Viewed) */
data data7;
   format revenue viewed percent5.0;
   input product $ 1-40 revenue viewed;
   datalines;
Skirt - Business Casual - Black          .113 .090
Shirt - Oxford - White                   .100 .020
Shirt - Oxford - Blue                    .091 .060
Men's Pants - Chino - Beige              .090 .080
Blouse - Business Dress - White          .078 .055
Shirt - Fitted Dress - White             .075 .018
Men's Pants - Dress Cuffs -Black         .072 .050
Women's Pants - Chino - Beige            .070 .075
Skirt - Pleated - Beige                  .060 .140
Dress - Summer Casual - White            .055 .020
;
run;

/* Data for plot8 (Top 10 - purchased together, but not displayed together) */
data data8;
   input product1 $ 1-40 product2 $ 41-80 value;
   datalines;
Shirt - Oxford - White                  Men's Pants - Chino - Tan                .27
Skirt - Pleated - Beige                 Blouse - Business Dress - White          .24
Skirt - Business Casual - Black         Blouse - Business Dress - White          .22
Men's Pants - Dress - Black             Shirt - Fitted Dress - White             .17
Men's Pants - Chino - Beige             Shirt - Oxford - Blue                    .14
Men's Pants - Dress w/ Cuffs - Blue     Shirt - Fitted Dress - White             .13
Women's Pants - Dress - Black           Blouse - Business Casual - White         .12
Dress - Summer Casual - White           Shoes - Sandals - White                  .11
Women's Pants - Chino - White           Blouse - Business Casual - Blue          .10
Men's Pants - Outdoors - Brown          Shirt - Outdoors - Beige                 .10
run;

/* Data for plot9 (Referral Sites - sparklines) */
data data9;
   input product $ 1-40 timestamp percent_of_target;
   datalines;
www.clothingconnection.com               1 .60    
www.clothingconnection.com               2 .80    
www.clothingconnection.com               3 1.10    
www.clothingconnection.com               4 1.10   
www.clothingconnection.com               5 1.00     
www.clothingconnection.com               6 .90    
www.clothingconnection.com               7 1.00    
www.clothingconnection.com               8 1.40   
www.clothingconnection.com               9 1.35    
www.clothingconnection.com              10 1.45   
www.clothingconnection.com              11 1.60    
www.clothingconnection.com              12 1.70   
www.getithere.com                        1 1.70   
www.getithere.com                        2 1.65   
www.getithere.com                        3 1.40   
www.getithere.com                        4 1.30   
www.getithere.com                        5 1.20    
www.getithere.com                        6 1.00   
www.getithere.com                        7 1.00   
www.getithere.com                        8 1.00   
www.getithere.com                        9 .70    
www.getithere.com                       10 .70    
www.getithere.com                       11 .60    
www.getithere.com                       12 .60    
www.ellingswear.com                      1 0.90   
www.ellingswear.com                      2 0.90   
www.ellingswear.com                      3 1.10   
www.ellingswear.com                      4 1.10   
www.ellingswear.com                      5 1.10    
www.ellingswear.com                      6 1.10   
www.ellingswear.com                      7 1.10   
www.ellingswear.com                      8 1.00   
www.ellingswear.com                      9 0.90   
www.ellingswear.com                     10 0.90   
www.ellingswear.com                     11 1.10   
www.ellingswear.com                     12 0.80   
www.trimthebill.com                      1 0.60   
www.trimthebill.com                      2 0.60   
www.trimthebill.com                      3 1.40   
www.trimthebill.com                      4 1.30   
www.trimthebill.com                      5 1.10    
www.trimthebill.com                      6 0.90   
www.trimthebill.com                      7 1.30   
www.trimthebill.com                      8 1.00   
www.trimthebill.com                      9 1.10   
www.trimthebill.com                     10 1.10   
www.trimthebill.com                     11 1.00   
www.trimthebill.com                     12 0.90   
www.looknofurther.com                    1 0.80   
www.looknofurther.com                    2 0.85   
www.looknofurther.com                    3 0.90   
www.looknofurther.com                    4 1.00   
www.looknofurther.com                    5 1.20    
www.looknofurther.com                    6 1.40   
www.looknofurther.com                    7 1.60   
www.looknofurther.com                    8 1.50   
www.looknofurther.com                    9 1.35   
www.looknofurther.com                   10 1.10   
www.looknofurther.com                   11 0.90   
www.looknofurther.com                   12 0.85   
www.cheapstuff.com                       1 1.00   
www.cheapstuff.com                       2 0.95   
www.cheapstuff.com                       3 1.00   
www.cheapstuff.com                       4 1.10   
www.cheapstuff.com                       5 1.00    
www.cheapstuff.com                       6 1.20   
www.cheapstuff.com                       7 1.00   
www.cheapstuff.com                       8 1.10   
www.cheapstuff.com                       9 1.15   
www.cheapstuff.com                      10 1.10   
www.cheapstuff.com                      11 1.15   
www.cheapstuff.com                      12 1.10   
www.bargainbasement.com                  1 1.60   
www.bargainbasement.com                  2 1.30   
www.bargainbasement.com                  3 1.00   
www.bargainbasement.com                  4 0.90   
www.bargainbasement.com                  5 0.80    
www.bargainbasement.com                  6 0.80   
www.bargainbasement.com                  7 0.90   
www.bargainbasement.com                  8 1.00   
www.bargainbasement.com                  9 1.00   
www.bargainbasement.com                 10 1.10   
www.bargainbasement.com                 11 1.15   
www.bargainbasement.com                 12 1.20   
www.dressforsuccess.com                  1 1.20   
www.dressforsuccess.com                  2 1.30   
www.dressforsuccess.com                  3 1.50   
www.dressforsuccess.com                  4 1.55   
www.dressforsuccess.com                  5 1.50    
www.dressforsuccess.com                  6 1.40   
www.dressforsuccess.com                  7 0.60   
www.dressforsuccess.com                  8 0.65   
www.dressforsuccess.com                  9 0.60   
www.dressforsuccess.com                 10 0.60   
www.dressforsuccess.com                 11 0.60   
www.dressforsuccess.com                 12 0.60   
www.relaxwear.com                        1 .30    
www.relaxwear.com                        2 .20    
www.relaxwear.com                        3 .30    
www.relaxwear.com                        4 .45    
www.relaxwear.com                        5 .50     
www.relaxwear.com                        6 .60    
www.relaxwear.com                        7 .60    
www.relaxwear.com                        8 .70    
www.relaxwear.com                        9 .80    
www.relaxwear.com                       10 .90    
www.relaxwear.com                       11 1.00   
www.relaxwear.com                       12 1.10   
www.nobrainer.com                        1 .90    
www.nobrainer.com                        2 .80    
www.nobrainer.com                        3 1.10    
www.nobrainer.com                        4 .60    
www.nobrainer.com                        5 1.00     
www.nobrainer.com                        6 .60    
www.nobrainer.com                        7 1.10    
www.nobrainer.com                        8 .50    
www.nobrainer.com                        9 1.00    
www.nobrainer.com                       10 .60    
www.nobrainer.com                       11 1.20    
www.nobrainer.com                       12 .70    
;
run;

/* Data for plot10 (Referral Sites - table) */
data data10;
   input product $ 1-40 referral_count referral_pct since_year_ago average_revenue;
   datalines;
www.clothingconnection.com               1103 .19 .57 72 
www.getithere.com                        782 .15 -.43 61 
www.ellingswear.com                      688 .13 -.02 90 
www.trimthebill.com                      413 .08 0 32 
www.looknofurther.com                    330 .06 -.03 52 
www.cheapstuff.com                       301 .06 .26 19 
www.bargainbasement.com                  297 .06 -.06 29 
www.dressforsuccess.com                  239 .05 -.25 42 
www.relaxwear.com                        174 .03 .13 22 
www.nobrainer.com                        168 .03 -.05 10 
;
run;

/* Data for plot11 (Top 10 - displayed together, but rarely purchased together) */
data data11;
   input product1 $ 1-40 product2 $ 41-80 value;
   datalines;
Men's Pants - Dress - Blue              Shirt - Sport Tee - Black                .000
Skirt - Pleated - White                 Women's Sweater - Casual - Brown         .001
Dress - Business Casual - Beige         Blouse - Business Dress - Black          .010
Women's Pants - Dress - Brown           Blouse - Business Casual - Black         .011
Dress - Summer Casual - White           Shoes - Pumps - Blue                     .012
Men's Pants - Dress w/ Cuffs - Tan      Shirt - Fitted Dress - Blue              .013
Skirt - Dress - Black                   Blouse - Business Casual - Black         .020
Dress - Formal - Blue                   Shoes - Pumps - White                    .021
Shirt - Fitted Dress - Blue             Men's Pants - Jeans - Blue               .030
Shirt - Sport Tee - Brown               Men's Pants - Jeans - Brown              .031
run;

/* Note: There is no data for plot12 or plot13.  
   Those elements are generated with annotated text. */

/***************************************************************************/

goptions device=gif;
goptions cback=&backcolor;
goptions noborder;

/* Delete all GRSEGs in the current session to ensure that indicators use
the expected names.  If a name is already in use, then an attempt to create
a new GRSEG using that name it will add a number to the name.  In that case, 
the subsequent GREPLAY will be placing the wrong GRSEGs into the dashboard.

Note: The macro code just checks whether there are any gsegs to delete.  If 
it tried to delete specific entries and none existed, then you would get an
error message: "ERROR: Member-name GSEG is unknown." */

%macro delcat(catname);
 %if %sysfunc(cexist(&catname)) %then %do;
  proc greplay nofs igout=&catname;
  delete _all_;
  run;
 %end;
 quit;
%mend delcat;
%delcat(work.gseg);

/**************************************************************************/
/* Create the individual indicators. */

/* Set the NODISPLAY option to save the plots as GRSEGS 
   without writing them to the output. */
goptions nodisplay;


/* plot1 (MTD Compared to Target) -----------------------------------------*/
/* Set up the 'chart tip' and drill-down using the variable named HTML so that it can
   also be used as the chart tip and drill-down for the annotate as well. (The variable
   could be named anything for use in the chart, but it must be named HTML to use it 
   in annotate.) */
data data1; set data1;
   length  html $400;
   html=
    'title='||quote( trim(left(barname))||': '||trim(left(put(value,percentn6.0))) )
     ||' '||
    'href="'||"&hardcoded_drilldown"||'"';        
run;

/* Annotating the bullet graph shading behind the bars. */
data plot1_anno; set data1;
   length function $8 color $12 style $20;
   
   /* Annotate the shading 'behind/before' the black bars. */
   when='b';
   
   /* First, draw the left-most shaded area behind the bullet graph. 
     Draw a bar/box from the beginning/zero of the bar, to the target
     value for the bar (the top/right corner of this bar/box will be
     30% up in the y-direction - this is 2*15%).  Move to the middle 
     of the beginning of each bar. */
   function='move';
   xsys='2'; x=0;
   ysys='2'; midpoint=barname;
   output;
   /* Move in y-direction 15% below bar center, drawing out a box/bar */
   ysys='7'; y=-15;
   output;
   function='bar'; style='solid'; line=0; color="&bullet1"; y=+30; x=target;
   output;
   
   /* Next, draw the right-most shaded area behind the bullet graph. 
      Move to the middle of the target value of each bar */
   function='move';
   xsys='2'; x=target;
   ysys='2'; midpoint=barname;
   output;

   /* Move in y-direction 15% below bar center, drawing out a box/bar */
   ysys='7'; y=-15;
   output;
   function='bar'; style='solid'; line=0; color="&bullet2"; y=+30; xsys='1'; x=100;
   output;
run;

goptions xpixels=275 ypixels=100; 
goptions gunit=pct htitle=15 htext=13 ftitle=&ftext ftext=&ftext ctext=&lighttext;

axis1 color=&lighttext label=none value=(justify=right) offset=(16,16) style=0;
axis2 color=&lighttext order=(0 to 2.00 by .50) minor=none label=none offset=(0,0);

title1 j=l c=&lighttext "    MTD Compared to Target";

pattern1 v=s color=&black;

/* Draw the horizontal bar chart, and annotate the bullet background shading */
proc gchart data=data1 anno=plot1_anno;
   hbar barname / ascending
      type=sum sumvar=value
      ref=1.00 cref=&black
      maxis=axis1
      raxis=axis2
      space=7
      width=3
      nostats
      noframe
      html=html
      name="plot1"; 
run;

/* plot2 (Percent of Total Visitors Today) */
/* Set up the 'chart tip' and drill-down using the variable named HTML so that it can
   also be used as the chart tip and drill-down for the annotate as well. (The variable
   could be named anything for use in the chart, but it must be named HTML to use it 
   in annotate.) */
data data2; set data2;
   length  html $400;
   html='title='||quote( trim(left(barname))||': '||trim(left(put(value,percentn6.0))) )
      ||' '|| 'href="'||"&hardcoded_drilldown"||'"';        
run;

/* Annotate the bullet graph shading behind the bars. */
data plot2_anno; set data2;
   length function $8 color $12 style $20;

   /* Annotate the shading behind the black bars. */
   when='b';
   
   /* First, draw the left-most shaded area behind the bullet graph. 
      Draw a bar/box from the beginning/zero of the bar, to the target
      value for the bar (the top/right corner of this bar/box will be
      30% up in the y-direction - this is 2*15%). */
   function='move';
   xsys='2'; x=0;
   ysys='2'; midpoint=barname;
   output;

   /* Move in y-direction 15% below bar center */
   ysys='7'; y=-15;
   output;
   function='bar'; style='solid'; line=0; color="&bullet1"; y=+30; x=target;
   output;
   
   /* Similarly, draw the 2nd 1/3 of the bullet shading from the target
      value to the extreme 100% right side of the graph. */
   function='move';
   xsys='2'; x=target;
   ysys='2'; midpoint=barname;
   output;
   ysys='7'; y=-15;
   output;
   function='bar'; style='solid'; line=0; color="&bullet2"; y=+30; x=target2;
   output;
   
   /* Similarly, draw the last 1/3 of the bullet shading from the target
      value to the extreme 100% right side of the graph. */
   function='move';
   xsys='2'; x=target2;
   ysys='2'; midpoint=barname;
   output;
   ysys='7'; y=-15;
   output;
   function='bar'; style='solid'; line=0; color="&bullet3"; y=+30; xsys='1'; x=100;
   output;
run;

goptions xpixels=275 ypixels=100; 
goptions gunit=pct htitle=15 htext=13 ftitle=&ftext ftext=&ftext ctext=&lighttext;

axis1 color=&lighttext label=none value=(justify=right) offset=(16,16) style=0;
axis2 color=&lighttext order=(0 to 1.00 by .25) minor=none label=none offset=(0,0);

title1 j=l c=&lighttext "    Percent of Total Visitors Today";

pattern1 v=s color=&black;

proc gchart data=data2 anno=plot2_anno;
   hbar barname / ascending
      type=sum sumvar=value
      maxis=axis1
      raxis=axis2
      space=7
      width=3
      nostats
      noframe
      html=html
      name='plot2'; 
run;

/* plot3 (Visitors - Last 12 months) */
/* This sample uses numeric month to get the desired order, but a 
   user-defined format is provided to get them to print as a two-character 
   month abbreviation.  (In this plot, there is not room for a longer 
   month abbreviation.) */
proc format;
   value month_fmt
   1='Ja'
   2='Fe'
   3='Ma'
   4='Ap'
   5='My'
   6='Jn'
   7='Jl'
   8='Au'
   9='Se'
  10='Oc'
  11='No'
  12='De'
  ;
run;

/* Use the whole month name in the HTML chart tip, because there's room there. */
proc format;
   value month_name
   1='January'
   2='February'
   3='March'
   4='April'
   5='May'
   6='June'
   7='July'
   8='August'
   9='September'
  10='October'
  11='November'
  12='December'
  ;
run;

/* Becayse the GPLOT procedure in SAS/GRAPH software doesn't do 
   grouped plots, results cannot be grouped by year without annotation. 
   The year and month into are combined into a single variable, which is 
   then used to annotate the axis tick mark labels.  Also, by annotating 
   the tick mark labels, chart tips can be added to them, which would not 
   have been possible with regular tick mark values. */
data data3; set data3;
   year_mon=trim(left(year))||'_'||trim(left(put(month,z2.)));
run;

data data3; set data3;
   length  html $400;
   html= 'title='||quote( trim(left(put(month,month_name.)))||', '||trim(left(year))||
      '  value='||trim(left(put(visitor_deviation,percentn6.0))) )
      ||' '|| 'href="'||"&hardcoded_drilldown"||'"';        
run;

/* Annotate gray area from bottom of graph to the zero line. */
data plot3_anno1;
   length function $8 style $20;
   when='b';
   xsys='1'; ysys='1'; 
   x=0; y=0;
   function='move';
   output;
   xsys='1'; ysys='2'; 
   x=100; y=0;
   function='bar'; style='solid'; color="grayf5";
   output;
run;

/* Annotate the month and year labels along the axis. */
data plot3_anno2;
   length function $8 style $20;
   length text $20;
   set data3; by year;
   when='a';
   color="&lighttext";
   position='5';
   xsys='2'; ysys='3';
   xc=year_mon; y=15;
   text=put(month,month_fmt.);
   output;
/* For the first/lowest month of each year, put an extra label along 
 the axis to show the year. Suppress the chart tip on the label. */
   if first.year then do;
      html='';
      text='   '||trim(left(year));
      y=8;
      output;
   end;
run;

goptions xpixels=300 ypixels=200; 
goptions gunit=pct htitle=9 htext=5 ftitle=&ftext ftext=&ftext ctext=&lighttext;

axis1 color=&lighttext order=(-.1 to .4 by .1) minor=none label=none offset=(0,0);
axis2 color=&lighttext minor=none major=none value=none label=none offset=(2,2) style=0;

symbol v=dot h=3 i=join c=&black w=.1;

title1 j=l c=&majorcolor "Visitors";
title2 j=l "Last 12 months' average daily visitors deviation";
title3 j=l "relative to same month in the prior year";
title4 a=-90 h=11 " ";

footnote1 h=10 " ";

proc gplot data=data3 anno=plot3_anno2;
   plot visitor_deviation*year_mon /
      vaxis=axis1
      haxis=axis2
      vref=0
      noframe
      anno=plot3_anno1
      html=html
      name='plot3'; 
run;

/* plot4 (Visitors - This month) */

/* Add a chart tip and drill-down to each plot marker. This serves double-duty 
   and becomes the chart tip and drill-down for the annotated axis tick mark 
   labels below each plot marker.  Because this chart tip/drill-down is used 
   in annotate, the variable must be named HTML. */
data data4; set data4;
   length  html $400;
   html=
      'title='||quote( trim(left(days))||' days into month:  value='||trim(left(put(visitor_deviation,percentn6.0))) )
      ||' '|| 'href="'||"&hardcoded_drilldown"||'"';        
run;

/* Annotate gray area from bottom of graph, to the zero line. */
data plot4_anno1;
   length function $8 style $20;
   when='b';
   xsys='1'; ysys='1'; 
   x=0; y=0;
   function='move';
   output;
   xsys='1'; ysys='2'; 
   x=100; y=0;
   function='bar'; style='solid'; color="grayf5";
   output;
   /* Annotate a custom footnote. */
   when='a'; style="&ftext"; color="&lighttext"; hsys='3'; size=5;
   function='label'; xsys='1'; x=50; ysys='3'; y=8; position='5'; text='Days so far this month';
   output;
run;

/* Annotate the days labels along the axis. */
data plot4_anno2;
   length function $8 style $20;
   length text $20;
   set data4; 
   when='a';
   color="&lighttext";
   position='5';
   xsys='2'; ysys='3';
   x=days; y=15;
   text=trim(left(days));
   output;
run;

goptions xpixels=300 ypixels=200; 
goptions gunit=pct htitle=9 htext=5 ftitle=&ftext ftext=&ftext ctext=&lighttext;

axis1 color=&lighttext order=(-.4 to .2 by .1) minor=none label=none offset=(0,0) 
   value=(t=5 '0%');
axis2 color=&lighttext minor=none major=none value=none label=none offset=(2,2) style=0;

symbol v=dot h=3 i=join c=&black w=.1;

title1 j=l c=&majorcolor " ";
title2 j=l "This month's daily visitors deviation relative to";
title3 j=l "13-week running average for the same weekday";
title4 a=-90 h=11 " ";

footnote1 h=10 " ";

proc gplot data=data4 anno=plot4_anno2;
   plot visitor_deviation*days /
      vaxis=axis1
      haxis=axis2
      vref=0
      noframe
      anno=plot4_anno1
      html=html
      name='plot4'; 
run;


/* plot5 (Visitors - Today)*/

/* Add a chart tip and drill-down to each plot marker. This serves double-duty 
   and becomes the chart tip and drill-down for the annotated axis tick mark 
   labels below each plot marker.  Because this chart tip/drill-down is used 
   in annotate, the variable must be named HTML. */
data data5; set data5; 
   length  html $400;
   html=
      'title='||quote( trim(left(hours))||' hours into today:  value='||trim(left(put(visitor_deviation,percentn6.0))) )
      ||' '|| 'href="'||"&hardcoded_drilldown"||'"';        
run;

/* Annotate gray area from bottom of graph, to the zero line. */
data plot5_anno1;
   length function $8 style $20;
   when='b';
   xsys='1'; ysys='1'; 
   x=0; y=0;
   function='move';
   output;
   xsys='1'; ysys='2'; 
   x=100; y=0;
   function='bar'; style='solid'; color="grayf5";
   output;
   /* Annotate a custom footnote. */
   when='a'; style="&ftext"; color="&lighttext";
   function='label'; xsys='1'; x=50; ysys='3'; y=8; position='5'; text='Hours so far today';
   output;
run;

/* Annotate the hours labels along the axis */
data plot5_anno2;
   length function $8 style $20;
   length text $20;
   set data5; 
   when='a';
   color="&lighttext";
   position='5';
   xsys='2'; ysys='3';
   x=hours; y=15;
   text=trim(left(hours));
   output;
run;

goptions xpixels=300 ypixels=200; 
goptions gunit=pct htitle=9 htext=5 ftitle=&ftext ftext=&ftext ctext=&lighttext;

axis1 color=&lighttext order=(-.4 to .2 by .1) minor=none label=none offset=(0,0) 
   value=(t=5 '0%');
axis2 color=&lighttext minor=none major=none value=none label=none offset=(2,2) style=0;

symbol v=dot h=3 i=join c=&black w=.1;

title1 j=l c=&majorcolor " ";
title2 j=l "Today's hourly visitors deviation relative to";
title3 j=l "13-week running average for the same hour";
title4 a=-90 h=11 " ";

footnote1 h=10 " ";

proc gplot data=data5 anno=plot5_anno2;
   plot visitor_deviation*hours /
      vaxis=axis1
      haxis=axis2
      vref=0
      noframe
      anno=plot5_anno1
      html=html
      name='plot5'; 
run;

/* plot7 (Products - Revenue and Viewed) */

/* plot7 is created before plot6, because the transformed data7 
  is used to create plot6. */

data data7; set data7;
   length  myhtml $400;
   myhtml= 'title='||quote( trim(left(product))||'0D'x
      ||'Revenue='||trim(left(put(revenue,percentn6.0)))||'0D'x
      ||'Viewed='||trim(left(put(viewed,percentn6.0))) )
      ||' '|| 'href="'||"&hardcoded_drilldown"||'"';        
run;

proc sort data=data7 out=data7;
  by descending revenue product;
run;

data data7; set data7;
   sortorder=_n_;
run;

data plot7_anno;
   set data7;
   when='a';
   /* Move to the appropriate x-position in the middle of the bar. */
   function='move';
   xsys='2'; x=viewed;
   ysys='2'; midpoint=product;
   output;
   /* Move in y-direction 5% below bar center. */
   ysys='7'; y=-3;
   output;
   /* Draw a line in y-direction 5% above bar center. */
   function='draw'; line=1; size=6.0; color="&black"; y=+6;
   output;
run;

/* Note: Care is required to get the bar chart in the same order as the 
   sparklines.  The bar chart is in descending order, with the bars sorted 
   from highest-to-lowest by bar length (and, if there's a tie, it goes 
   alphabetical).  The bar chart does this automatically, but the data is
   also manually sorted to get the order to merge with the sparkline data 
   to achieve the same order.  If you don't do this carefully, you can get 
   sparklines lining up with the wrong bars. */
goptions xpixels=565 ypixels=300; 
goptions gunit=pct ftitle=&ftext ftext=&ftext htitle=9 htext=4.9 ctext=&black;

title1 j=l h=15 " ";

footnote h=3 " ";

axis1 color=&lighttext label=none value=(color=&black);
axis2 color=&lighttext order=(0 to .16 by .04) minor=none label=none;

pattern1 v=s c=&revenue_color;

proc gchart data=data7 anno=plot7_anno;
   hbar product / descending
      type=sum
      sumvar=revenue
      sumlabel=none  /* doesn't work? had to use label=none in axis stmt */
      nostats
      maxis=axis1
      raxis=axis2
      space=1.5
      noframe
      html=myhtml
      des=""
      name="plot7";
run;

/* plot6 (Products - Sparklines) */
/* These are the sparklines to the left of the bar chart. "Sparkline" 
   graphs are challenging to create with SAS/GRAPH software.  This example
   uses the GPLOT procedure, and for each line an offset is
   added so that the lines are plotted aboveor below each other, rather 
   than on top of each other. */

/* y-axis is done with 'vreverse', so the lowest number is at the top.
1 = Skirt - Business Casual - Black
...
10 = Dress - Summer Casual - White 
*/

/* Merge in the order from the bar chart data7.  It is important to get the same 
   order, so that the sparklines will line up with the bars. */
proc sql noprint;
   create table data6 as
   select data6.*, data7.sortorder
   from data6 left join data7
   on data6.product = data7.product
   order by product, timestamp;
quit;     

/* This plot uses vreverse, so this equation is the
   reverse of how you might perceive it at first glance. */
data data6; set data6;
   y=(2*(sortorder))+(1.00 - percent_of_target);
run;

/* Annotate invisible drill-down covering entire graph area (because
you can't do drill-downs on plot lines without markers. */
data plot6_anno;
   length function $8 color style $20;
   xsys='1'; ysys='1'; 
   x=0; y=0; function='move';
   output;
   html='title="drilldown"' ||' '|| 
    'href="'||"&hardcoded_drilldown"||'"';        
   x=100; y=100; function='bar'; style='empty'; when='b'; color="&backcolor";
   output;
run;


goptions xpixels=200 ypixels=300; 
goptions gunit=pct ftitle=&ftext ftext=&ftext htitle=9 htext=6.3;

axis1 label=none order=(0 to 22 by 2) value=none major=none minor=none style=0;
axis2 label=(' ') order=(1 to 30 by 2) value=none major=none minor=none style=0;

symbol v=none i=join width=.1 c=&black repeat=100;

title1 j=l c=&majorcolor "Products";
title2 h=2.0 " ";
title3 a=90 h=4 " ";
title4 a=-90 h=4 " ";

footnote;

proc gplot data=data6 anno=plot6_anno;
   plot y*timestamp=product / 
      noframe
      vaxis=axis1 vreverse
      haxis=axis2
      vref= 2 4 6 8 10 12 14 16 18 20
      cvref=&lighttext
      nolegend
      des=""
      name="plot6";
run;

/* plot8 (Top 10 - purchased together, but not displayed together) */

/* Note: This "Top 10" table is complex.  Because this sample uses the 
   GREPLAY procedure to place the indicator in the dashboard, typical
   reporting procedures like PRINT or TABLATE cannot be used because 
   they produce text output.  This sample uses the Annotate facility in 
   SAS/GRAPH software to create a graphical slide with the table text 
   in the desired positions. Using this approach, the spacing of the 
   table items must be adjusted manually.  If you change the number of
   items in the table, you must change the offsets or increments for the
   annotated positions of the text). */

proc sort data=data8 out=data8;
   by descending value;
run;

data data8; set data8;
   n=_n_;
run;

proc sql noprint;
   select unique count(*) format=comma2.0 into :count7 from data8;
quit;
run;

%let min_y=1;
%let max_y=76;

data plot8_anno;
   set data8;
   length style $20 color $ 12 function $ 8 text $ 100;
   xsys='3'; ysys='3'; hsys='3'; style="&ftext"; color="&black";
   y=&max_y-(n-1)*((&max_y-&min_y)/&count7);
   x=10; position='4'; text=trim(left(put(value,percentn6.0)));
   output;
   x=14; position='6'; text=trim(left(product1));
   output;
   x=58; position='6'; text=trim(left(product2));
   output;
run;

data plot8_annob; 
   length style $20 color $ 12 function $ 8 text $ 100;
   xsys='3'; ysys='3'; hsys='3'; style="&ftext"; color="&lighttext";
   function='move'; x=5; y=&max_y+5;
   output;
   function='draw'; x=100; size=.1;
   output;
   function='label'; size=.; 
   y=&max_y+10;
   color="&black";
   x=10; position='4'; text='%';
   output;
   x=14; position='6'; text='Product 1';
   output;
   x=58; position='6'; text='Product 2';
   output;
   y=&max_y+18; style="&ftext"; size=5.5; color="&lighttext";
   /* foofoo */
   x=5; position='6'; text="Top &count7 products purchased together but not displayed together";
   output;
run;

/* Annotate an invisible bar/box with drill-down link for the entire table. */
data plot8_annoc;
   length function $8 color style $20;
   xsys='3'; ysys='3'; 
   x=0; y=0; function='move';
   output;
   html='title="drilldown"' ||' '|| 
      'href="'||"&hardcoded_drilldown"||'"';        
   x=100; y=100; function='bar'; style='empty'; when='b'; color="&backcolor";
   output;
run;

data plot8_anno;
   set plot8_anno plot8_annob plot8_annoc;
run;

goptions gunit=pct htitle=10 htext=4.5 ftitle=&ftext ftext=&ftext ctext=&lighttext;
title; 
footnote;
goptions xpixels=1400 ypixels=700; 
proc gslide des="" name="plot8" anno=plot8_anno;
run;

/* plot10 (Referral Sites - table) */

proc sort data=data10 out=data10;
   by descending referral_count product;
run;

data data10; set data10;
   sortorder=_n_;
run;

data plot10_anno; set data10;
   length text $100 html $200;
   function='label'; when='a'; position='4';
   ysys='2'; midpoint=product;
   xsys='1'; 
   x=16; text=trim(left(put(referral_count,comma8.0)));
   output;
   x=42; text=trim(left(put(referral_pct,percentn7.0)));
   output;
   x=70; text=trim(left(put(since_year_ago,percentn7.0))); 
   if since_year_ago > 0 then text='+'||trim(left(text));
   output;
   x=95; text=trim(left(average_revenue));
   output;
   /* Annotate an invisible label behind the bar labels for drill-down. */
   xsys="3"; when="b"; style="swiss"; position="6"; color="&backcolor";
   html='title="'||trim(left(product))||'"'||' '||
    'href="http://'||trim(left(product))||'"';
   x=1; text="XXXXXXXXXXXXXXXXXX";
   output;
run;

/* Annotate an invisible drill-down covering entire graph area, just inside
   the axis area (where the annotated table is).  Note that the Web site
   names, which are outside the axis, have their own separate drill-downs to the 
   corresponding Web site. */
data plot10_anno2;
   length function $8 color style $20;
   xsys='1'; ysys='1'; 
   x=0; y=0; function='move';
   output;
   html='title="drilldown"' ||' '|| 
       'href="'||"&hardcoded_drilldown"||'"';        
   x=100; y=100; function='bar'; style='empty'; when='b'; color="&backcolor";
   output;
run;

/* Note: Care is required to get the bar chart in the same order as the 
   sparklines.  The bar chart is in descending order, with the bars sorted 
   from highest-to-lowest by bar length (and, if there's a tie, it goes 
   alphabetical).  The bar chart does this automatically, but the data is
   also manually sorted to get the order to merge with the sparkline data 
   to achieve the same order.  If you don't do this carefully, you can get 
   sparklines lining up with the wrong bars. */
goptions xpixels=565 ypixels=325; 
goptions gunit=pct ftitle=&ftext ftext=&ftext htitle=10 htext=4.9 ctext=&black;

title1 j=l h=15 " ";

footnote h=3 " ";

axis1 color=&lighttext label=none value=(color=&black) style=0;
axis2 color=&lighttext order=(0 to 2000 by 1000) major=none minor=none value=none label=none style=0;

/* Make the bars same color as background so they are invisible. */
pattern1 v=s c=&backcolor;

proc gchart data=data10 anno=plot10_anno;
   hbar product / descending
      type=sum
      sumvar=referral_count
      sumlabel=none
      nostats
      maxis=axis1
      raxis=axis2
      space=1.5
      noframe
      anno=plot10_anno2
      des=""
      name="plot10";
run;

/* plot9 (Referral Sites - sparklines) */

/* These are the sparklines to the left of the website names. 
  "Sparkline" graphs are challenging to create with SAS/GRAPH software.
   This example uses the GPLOT procedure, and for each line an offset is
   added so that the lines are plotted aboveor below each other, rather 
   than on top of each other. */

/* The y-axis is done with 'vreverse', so the lowest number is at the top.
1 = www.clothingconnection.com
...
10 = www.nobrainer.com
*/

/* Merge in the order from the bar chart data. It is important to get the 
   same order, so the sparklines will line up with the bars. */
proc sql noprint;
    create table data9 as
    select data9.*, data10.sortorder
    from data9 left join data10
    on data9.product = data10.product
    order by product, timestamp;
quit;
run;

/* Remember, the plot uses vreverse, so this equation is the
   reverse of how you might perceive it at first glance. */
data data9; set data9;
   y=(2*(sortorder))+(1.00 - percent_of_target);
run;

/* Annotate invisible drill-down covering entire graph area (because
   you can't do drill-downs on plot lines without markers). */
data plot9_anno;
   length function $8 color style $20;
   xsys='1'; ysys='1'; 
   x=0; y=0; function='move';
   output;
   html='title="drilldown"' ||' '|| 
    'href="'||"&hardcoded_drilldown"||'"';        
   x=100; y=100; function='bar'; style='empty'; when='b'; color="&backcolor";
   output;
run;

goptions xpixels=200 ypixels=300; 
goptions gunit=pct ftitle=&ftext ftext=&ftext htitle=9 htext=6.3;

axis1 label=none order=(0 to 22 by 2) value=none major=none minor=none style=0;
axis2 label=none order=(1 to 12 by 2) value=none major=none minor=none style=0;

symbol v=none i=join width=.1 c=&black repeat=100;

title1 j=l c=&majorcolor "Referral Sites";
title2 h=2 " ";
title3 a=90 h=4 " ";
title4 a=-90 h=4 " ";

footnote;

proc gplot data=data9 anno=plot9_anno;
   plot y*timestamp=product / 
      noframe
      vaxis=axis1 vreverse
      haxis=axis2
      vref= 2 4 6 8 10 12 14 16 18 20
      cvref=&lighttext
      nolegend
      des=""
      name="plot9";
run;

/* plot11 (Top 10 table - displayed together, but rarely purchased) */
/* Note: This "Top 10" table is complex.  Because this sample uses the 
   GREPLAY procedure to place the indicator in the dashboard, typical
   reporting procedures like PRINT or TABLATE cannot be used because 
   they produce text output.  This sample uses the Annotate facility in 
   SAS/GRAPH software to create a graphical slide with the table text 
   in the desired positions. Using this approach, the spacing of the 
   table items must be adjusted manually.  If you change the number of
   items in the table, you must change the offsets or increments for the
   annotated positions of the text). */
proc sort data=data11 out=data11;
   by /* ascending */ value;
run;

data data11; set data11;
   n=_n_;
run;

proc sql noprint;
   select unique count(*) format=comma2.0 into :count7 from data11;
quit;
run;

data plot11_anno; set data11;
   length style $20 color $ 12 function $ 8 text $ 100;
   xsys='3'; ysys='3'; hsys='3'; style="&ftext"; color="&black";
   y=&max_y-(n-1)*((&max_y-&min_y)/&count7);
   x=10; position='4'; text=trim(left(put(value,percentn6.0)));
   output;
   x=14; position='6'; text=trim(left(product1));
   output;
   x=58; position='6'; text=trim(left(product2));
   output;
run;

data plot11_annob; 
   length style $20 color $ 12 function $ 8 text $ 100;
   xsys='3'; ysys='3'; hsys='3'; style="&ftext"; color="&lighttext";
   function='move'; x=5; y=&max_y+5;
   output;
   function='draw'; x=100; size=.1;
   output;
   function='label'; size=.; 
   y=&max_y+10;
   color="&black";
   x=10; position='4'; text='%';
   output;
   x=14; position='6'; text='Product 1';
   output;
   x=58; position='6'; text='Product 2';
   output;
   y=&max_y+18; style="&ftext"; size=5.5; color="&lighttext";
   x=5; position='6'; text="Top &count7 products displayed together but rarely purchased together";
   output;
run;

/*  Annotate an invisible bar/box, which has an html drilldown for the entire table. */
data plot11_annoc;
   length function $8 color style $20;
   xsys='3'; ysys='3'; 
   x=0; y=0; function='move';
   output;
   html='title="drilldown"' ||' '|| 
    'href="'||"&hardcoded_drilldown"||'"';        
   x=100; y=100; function='bar'; style='empty'; when='b'; color="&backcolor";
   output;
run;

data plot11_anno; set plot11_anno plot11_annob plot11_annoc;
run;

goptions gunit=pct htitle=10 htext=4.5 ftitle=&ftext ftext=&ftext ctext=&lighttext;

title; 
footnote;
goptions xpixels=1400 ypixels=700; 
proc gslide des="" name="plot11" anno=plot11_anno;
run;

/* plot12 (Products - overall title) */
data plot12_anno;
   length function $8 color style $20 text $100;
   length html $ 250;
   xsys='3'; ysys='3'; hsys='3'; when='a';
   
   function='label'; position='6';
   color="&black";
   y=86;
   x=2; text="Last 30 Days";
   output; 
   x=27.5; text="Top 10 this Month by Revenue";
   output; 
   x=60; text="Revenue %";
   output; 
   x=80; text="Viewed %";
   output; 
   
   x=72.5; style="marker"; text="U"; color="&revenue_color";
   output; 
   x=91; y=y+1.8; style="swissb"; text="I"; size=7; color="&black";
   output; 
   
   line=1; size=.2; color="&lighttext";
   function='move'; x=2;  y=80;
   output;
   function='draw'; x=98;
   output;
run;

goptions xpixels=765 ypixels=300; 
goptions gunit=pct ftext=&ftext htext=5.25;

title; 
footnote;
proc gslide des="" name="plot12" anno=plot12_anno;
run;

/* plot13 (Referral Sites - overall title) */

data plot13_anno;
   length function $8 color style $20 text $100;
   length html $ 250;
   xsys='3'; ysys='3'; hsys='3'; when='a';
   
   function='label'; position='6';
   color="&black";
   y=84;
   x=2; text="Last 12 Months";
   output; 
   x=27.5; text="Top 10 Referrers this Month";
   output; 
   
   position='4';
   x=63; text="Count";
   output; 
   x=75; text="of Total";
   output; 
   x=85.5; text="Yr Ago";
   output; 
   x=98.5; text="Revenue $";
   output; 
   
   y=y+6;
   x=63; text="Referral";
   output; 
   x=75; text="Referral %";
   output; 
   x=85.5; text="Since";
   output; 
   x=98.5; text="Average";
   output; 
   
   line=1; size=.2; color="&lighttext";
   function='move'; x=2;  y=77;
   output;
   function='draw'; x=98;
   output;
run;

goptions xpixels=765 ypixels=300; 
goptions gunit=pct ftext=&ftext htext=5.5;

title; 
footnote;
proc gslide des="" name="plot13" anno=plot13_anno;
run;

/* Create the main title slide for dashboard */
data titlanno;
   length function $8 color style $20 text $100;
   length html $ 250;
   xsys='3'; ysys='3'; hsys='3'; when='a';
   
   /* Annotate the main title at the top center of the dashboard. */
   function='label'; position='5';
   x=50; y=99.5; size=3.5; style="&ftext"; color="&majorcolor"; text='Web Marketing Dashboard';
   output;
   y=95.8; size=1.8; style="&ftext"; color="&lighttext"; text="Data as of 2:00 PM (PST), April 13, 2005";
   output;
   
   /* Annotate the light green lines that group and separate the various parts of the dashboard. */
   line=1; size=.2; color="&majorcolor";
   function='move'; x=0; y=90;
   output;
   function='draw'; x=100;
   output;
   function='move'; x=0; y=60;
   output;
   function='draw'; x=100;
   output;
   function='move'; x=0; y=30;
   output;
   function='draw'; x=55;
   output;
   function='draw'; y=0;
   output;
   
   /* Annotate a Help button that links to a page with information about
      the dashboard. */
   html='title='||quote('Help')||' '||
      'href="'||"&hardcoded_drilldown"||'"';
   
   function='move'; x=48; y=91;
   output;
   function='bar'; line=0; size=.1; style='empty'; color="&lighttext"; x=x+5; y=y+2.5;
   output;
   html='';
   function='label'; color="&lighttext"; style="&ftext"; size=1.8; x=48+2.5; y=91+1.75; position='5'; text='Help';
   output;
   html='';
run;

goptions xpixels=875 ypixels=685; 

title; 
footnote;
proc gslide des="" name="titles" anno=titlanno;
run;

/***************************************************************************/
/* Replay the individual indicators to create the dashboard. */

GOPTIONS DEVICE=gif;
goptions xpixels=900 ypixels=700; 
goptions display;
goptions border;

ODS LISTING CLOSE;
ODS HTML path=odsout body="&name..htm" (title="Web Marketing Dashboard") 
 style=minimal gtitle gfootnote;

/* Create custom greplay template, with 13 areas for the plots (areas #1-#13),
   and one area for the title slide (area #0).
*/
proc greplay tc=tempcat nofs igout=work.gseg;
  tdef murder des='Murder'

   0/llx = 0   lly =  0
     ulx = 0   uly =100
     urx =100  ury =100
     lrx =100  lry =  0

   1/llx = 0   lly =90 
     ulx = 0   uly =100
     urx = 25  ury =100
     lrx = 25  lry =90 

   2/llx = 75  lly =90 
     ulx = 75  uly =100
     urx = 100 ury =100
     lrx = 100 lry =90 

   3/llx =  0  lly =60 
     ulx =  0  uly =90 
     urx = 33  ury =90 
     lrx = 33  lry =60 

   4/llx = 33  lly =60 
     ulx = 33  uly =90 
     urx = 67  ury =90 
     lrx = 67  lry =60 

   5/llx = 67  lly =60 
     ulx = 67  uly =90 
     urx = 100 ury =90 
     lrx = 100 lry =60 

   6/llx =  0  lly =30 
     ulx =  0  uly =60 
     urx = 15  ury =60 
     lrx = 15  lry =30 

   7/llx = 15  lly =30 
     ulx = 15  uly =60 
     urx = 55  ury =60 
     lrx = 55  lry =30 

   8/llx = 55  lly =30
     ulx = 55  uly =60
     urx = 100 ury =60
     lrx = 100 lry =30

   9/llx =  0  lly =0 
     ulx =  0  uly =30 
     urx = 15  ury =30 
     lrx = 15  lry =0 

  10/llx = 15  lly =0 
     ulx = 15  uly =30 
     urx = 55  ury =30 
     lrx = 55  lry =0 

  11/llx = 55  lly =0
     ulx = 55  uly =30
     urx = 100 ury =30
     lrx = 100 lry =0

/* area 12 encompases areas 6 and 7 */

  12/llx =  0  lly =30 
     ulx =  0  uly =60 
     urx = 55  ury =60 
     lrx = 55  lry =30 

/* area 13 encompases areas 9 and 10 */

  13/llx =  0  lly =0 
     ulx =  0  uly =30 
     urx = 55  ury =30 
     lrx = 55  lry =0 
;

   /* Replay the individual indicators and the title slide into the custom template. */
   template = murder;
   treplay
      0:titles
      1:plot1            2:plot2
      3:plot3  4:plot4   5:plot5
      6:plot6  7:plot7   8:plot8
      12:plot12
      9:plot9 10:plot10 11:plot11
      13:plot13
      des=""
      name="&name";
run;
quit;

ODS HTML CLOSE;
ODS LISTING;
