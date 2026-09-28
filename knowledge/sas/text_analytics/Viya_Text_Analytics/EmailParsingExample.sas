/* Email Parsing Example */
/* Connect  */
cas ss;
caslib _all_ assign;

data public.emailsample 
	(keep = id content To From subject signOff);
	set public.emailsample;

	/* Define Variables */
	length pattern $50. From To varchar(4000) subject signOff varchar(10000);

	/* Create REgex Patterns */
	if _N_ = 0 then
		do;
			retain emHeaderToPatternID;

			/* The i option specifies a case insensitive search. */
			pattern = "/To\:/i";
			emHeaderToPatternID = prxparse(pattern);
			retain emHeaderFromPatternID;
			pattern = "/From\:/i";
			emHeaderFromPatternID = prxparse(pattern);
			retain subjectPatternID;
			pattern = "/Subject\:/i";
			subjectPatternID = prxparse(pattern);
			retain signOffPatternID;
			pattern = "/Thanks\,|Thank you\,/i";
			signOffPatternID = prxparse(pattern);
		end;

	/* Make calls to regex patterns */
	call prxsubstr(emHeaderToPatternID, content, emHeaderToPosition, emHeaderToLength);
	call prxsubstr(emHeaderFromPatternID, content, emHeaderFromPosition, emHeaderFromLength);
	call prxsubstr(subjectPatternID, content, subjectPosition, subjectLength);
	call prxsubstr(signOffPatternID, content, signOffPosition, signOffLength);

	/* Substring contents appropriately according to offsets */
	If emHeaderToPosition ne 0 then
		To = substr(content,emHeaderToPosition,emHeaderFromPosition- emHeaderToPosition);

	If emHeaderFromPosition ne 0 then
		From= substr(content,emHeaderFromPosition,subjectPosition- emHeaderFromPosition);

	If subjectPosition ne 0 then
		subject = substr(content,subjectPosition,signOffPosition - subjectPosition);

	If signOffPosition ne 0 then
		signOff = substr(content,signOffPosition,length(content) - signOffPosition);
run;

/* Clean up */
cas ss terminate;