PROC TMUTIL;
	CONTROL release memloc="Filter_1";
RUN;

PROC TMUTIL data=fallbsp.index_alle key=fallbsp.terme_alle;
	CONTROL init memloc="Filter_1";
	WEIGHT 	cellwgt=log termwgt=entropy;
	OUTPUT 	key=fallbsp.terme_gewichtet KEEPONLY;
RUN;

TITLE 'Gefilterte Terme und ihre Gewichte';

PROC MEANS data=fallbsp.terme_gewichtet;
	VAR WEIGHT;
RUN;

PROC TMUTIL;
	CONTROL memloc="Filter_1";
	SELECT 	REDUCEF=2; 		/* Term in mind. zwei Dokumenten */
	OUTPUT 	key=fallbsp.terme_gewichtet KEEPONLY;
RUN;

PROC MEANS data=fallbsp.terme_gewichtet;
	VAR WEIGHT;
RUN;

PROC TMUTIL;
	CONTROL	memloc="Filter_1";
	SELECT 	REDUCEW=0.5;		/* Terms mind. Gewicht von 0.5 */
	OUTPUT 	key=fallbsp.terme_gewichtet KEEPONLY;
RUN;

PROC MEANS data=fallbsp.terme_gewichtet;
	VAR WEIGHT;
RUN;