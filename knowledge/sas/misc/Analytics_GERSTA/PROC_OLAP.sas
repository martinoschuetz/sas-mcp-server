LIBNAME Orstar BASE "C:\Daten\Orion\orstar2" ;



 PROC OLAP
           Data=Orstar.FINALMART
           cube=Merchandise_Cube
           Path="C:\DATEN\Orion\Orstar2\OLAP"
          Workpath="C:\DATEN\Orion\Orstar2\OLAP\temp"
           Description="OLAP Cube für Merchandise Manager"
          ;
 
 METASVR host="gersta.ger.sas.com" port=8561 protocol=bridge userid="gersta\sasdemo"
    pw="{sas001}U0FTcHcx"
    repository="Foundation"
    olap_schema="SASMain - OLAP Schema";

 DIMENSION Dim_Time hierarchies=(Dim_Time ) 
          CAPTION='Zeitdimension'
          DESC='Zeitachse'
          TYPE=TIME SORT_ORDER=ASCENDING ;

          HIERARCHY Dim_Time ALL_MEMBER='Gesamt' 
          levels=( Year_ID Quarter Month_Name ) 
          CAPTION='Zeithierarchie'
          DESC='Zeitraum'
                    DEFAULT
          ;

          LEVEL Month_Name TYPE=MONTHS 
          CAPTION='Monat' 
          DESC='Monat' 
          SORT_ORDER=ASCENDING
          ;

          LEVEL Quarter TYPE=QUARTERS 
          CAPTION='Quartal' 
          DESC='Quartal' 
          SORT_ORDER=ASCENDING
          ;

          LEVEL Year_ID TYPE=YEAR 
          CAPTION='Jahr' 
          DESC='Jahr' 
          SORT_ORDER=ASCENDING
          ;


 DIMENSION Dim_Merchandise hierarchies=(Dim_Merchandise ) 
          CAPTION='Sortimentsdimension'
          DESC='Alle Warenklassifikationen'
          SORT_ORDER=ASCENDING ;

          HIERARCHY Dim_Merchandise ALL_MEMBER='Gesamt' 
          levels=( Product_Line Product_Category Product_Group Product_Name ) 
          CAPTION='Sortimentshierarchie'
          DESC='Sortimentshierarchie'
                    DEFAULT
          ;

          LEVEL Product_Name 
          CAPTION='Artikel' 
          DESC='Artikel' 
          SORT_ORDER=ASCENDING
          ;

          LEVEL Product_Group 
          CAPTION='Artikelgruppe' 
          DESC='Artikelgruppe' 
          SORT_ORDER=ASCENDING
          ;

          LEVEL Product_Category 
          CAPTION='Warengruppe' 
          DESC='Warengruppe' 
          SORT_ORDER=ASCENDING
          ;

          LEVEL Product_Line 
          CAPTION='Produktkategorie' 
          DESC='Produktkategorie' 
          SORT_ORDER=ASCENDING
          ;


 DIMENSION Dim_Cust hierarchies=(Hier_Region Hier_Gender Hier_Age ) 
          CAPTION='Kundendimension'
          DESC='Kundendimension'
          SORT_ORDER=ASCENDING ;

          HIERARCHY Hier_Region ALL_MEMBER='Gesamt' 
          levels=( State City Postal_Code ) 
          CAPTION='Region'
          DESC='Region'
                    DEFAULT
          ;
HIERARCHY Hier_Gender ALL_MEMBER='Gesamt' 
          levels=( Customer_Gender ) 
          CAPTION='Geschlecht'
          DESC='Geschlecht'
                    ;
HIERARCHY Hier_Age ALL_MEMBER='Gesamt' 
          levels=( Customer_Age_Group ) 
          CAPTION='Alter'
          DESC='Alter	'
                    ;

          LEVEL Postal_Code 
          CAPTION='PLZ-Zone' 
          DESC='PLZ-Zone' 
          SORT_ORDER=ASCENDING
          ;

          LEVEL City 
          CAPTION='Stadt oder Gemeinde' 
          DESC='Stadt' 
          SORT_ORDER=ASCENDING
          ;

          LEVEL State 
          CAPTION='Bundesland' 
          DESC='Bundesland' 
          SORT_ORDER=ASCENDING
          ;

          LEVEL Customer_Age_Group 
          CAPTION='Altersgruppe' 
          DESC='Alter' 
          SORT_ORDER=ASCENDING
          ;

          LEVEL Customer_Gender 
          CAPTION='Geschlecht' 
          DESC='Geschlecht' 
          SORT_ORDER=ASCENDING
          ;


 DIMENSION Dim_Seg hierarchies=(Dim_Seg ) 
          CAPTION='Segmentdimension'
          DESC='Segmente	'
          SORT_ORDER=ASCENDING ;

          HIERARCHY Dim_Seg ALL_MEMBER='Segmente' 
          levels=( segment ) 
          CAPTION='Segmentierun'
          DESC='Segmentieung'
                    DEFAULT
          ;

          LEVEL segment 
          CAPTION='Verhaltensbasiertes Kundensegment' 
          DESC='Segmente' 
          SORT_ORDER=ASCENDING
          ;

 MEASURE Umsatz
          STAT=SUM
          COLUMN=Sales
          CAPTION='Umsatz total'
          UNITS='Euro'
          FORMAT=EUROX13.2
          DEFAULT
          ;

 MEASURE Absatzmenge
          STAT=SUM
          COLUMN=Quantity
          CAPTION='Absatzmenge total'
          DESC='Absatz'
          UNITS='Artikeleinheiten'
          FORMAT=12.
          ;

 AGGREGATION Year_ID
             Quarter
             Month_Name
             Product_Line
             Product_Category
             Product_Group
             Product_Name
             Customer_Gender
             Customer_Age_Group
             State
             City
             Postal_Code
             segment
             / NAME='Default'
             ;



 

 FORMAT Product_Category $CAT_DE22.;
 FORMAT Product_Line $PROD_DE19.;
 FORMAT Customer_Age_Group $AGE_DE11.;
 FORMAT Customer_Gender $SEX_DE9.;

 RUN;