/*
	Erinnerst Du dich an Dein komisches Problem mit der INTHPA4, die keine Daten enthielt (Otto Vorbereitung).
	Ich weiss jetzt eventuell warum: die Anzahl der Blöcke war wahrscheinlich zu niedrig,
	d.h. bereits in Hive gab es auf einem Knoten keine Daten (wenn die Blöckgrösse z.B. 64 ob 128 MB ist,
	kann das passieren, sofern Deine Tabelle kleiner ist).
	Es gibt ein Papier von Rob Collum, in dem er beschreibt, wie man das in LASR ausgleichen kann.
	Vielleicht war es das wirklich?

	http://support.sas.com/resources/papers/proceedings15/SAS1760-2015.pdf#
*/

proc imstat immediate; 
/* Specify the unbalanced table */ 
table example.the_table; 
/* Print out the distribution stats so we can see */ 
/* how bad it really is */ 
distributioninfo; 
/* Perform the balance - each node will be +/- 1 row */ 
/* A new temporary table (balanced!) is created */ 
balance; 
/* Drop the original unbalanced table */ 
droptable;
/* Now reference the newly balanced temporary table */ 
table example.&_templast_; 
/* Promote the temporary table to active status with the */ 
/* original table's name */ 
promote the_table; 
/* Now reference the new table by its permanent name */ 
table example.the_table; 
/* Print out the distribution stats for confirmation */ 
/* of balance */ 
distributioninfo; 
/* Save the LASR table back down to SASHDAT on HDFS */ 
/* and replace the old, unbalanced table there */ 
save path="/path/in/hdfs" replace; 
quit;
