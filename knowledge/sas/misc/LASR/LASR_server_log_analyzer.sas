/*********************************************************************************
 * LASR log analyzer
 *
 * Written by: Eyal Gonen 
 * Date Last Modified: 30DEC2014
 * Version: 1.0
 *
 * History of Changes:
 * -------------------
 *
 ********************************************************************************/

%let LASRLogfile=C:\temp\lasr_log_29dec2014.log;

data lasrlog;
	infile "&LASRLogfile" length=len truncover encoding="utf8";
	length line $ 2000
           ID 8
		   User $ 50
		   Action $ 50
		   TableName $ 100
		   RunTime 8
		   sTime eTime 8
	;
	retain ID 
	       User
		   Action
		   TableName
           eTime
           prxNewActionID
		   prxendActionRT
		   prxNewActionTime
		   prxNewActionUser
		   prxNewActionActionDetails
	;
	label ID = "LASR action ID"
	      actionLines = "Number of LASR action lines generated"
		  RunTime = "LASR action run time (sec)"
		  sTime = "LASR action start time (calculated)"
		  eTime = "LASR action end time"
	; 

	input line $varying. len;

	if substr(line,1,3) = 'ID=' then newAction = 1; else newAction = 0;
	if find(line,'RunTime=') > 0 then endAction = 1; else endAction = 0;

	/* setup PERL regex expressions */
	if _n_ = 1 then do;
		prxNewActionID = prxparse('/^ID=(\d+)/');
		prxNewActionTime = prxparse('/SASTime=([\d+|\.]+)/');
		prxNewActionUser = prxparse('/comment=([^"]+)/');
		prxNewActionActionDetails = prxparse('/RawCmd=action=(\w+) name=([^"]+)/');
		prxEndActionRT = prxparse('/RunTime=\s*([\d|\.]+)/');
	end;

	/* If start of a new action */
	if (newAction) then do;
		actionLines = 0;
		posID = prxmatch(prxNewActionID, line);
		if posID > 0 then call prxposn(prxNewActionID, 1, sId, eID);
		if sId > 0 then ID = input(substr(line, sID, eID),best.);
		posTime = prxmatch(prxNewActionTime, line);
		if posTime > 0 then call prxposn(prxNewActionTime, 1, sT, eT);
		if sT > 0 then eTime = input(substr(line, sT, eT),best.);
		posUser = prxmatch(prxNewActionUser, line);
		if posUser > 0 then call prxposn(prxNewActionUser, 1, sUID, eUID);
		if sUID > 0 then User = substr(line, sUID, eUID);
		posAction = prxmatch(prxNewActionActionDetails, line);
		if posAction > 0 then do;
			call prxposn(prxNewActionActionDetails, 1, sAction, eAction);
			if sAction > 0 then Action = substr(line, sAction, eAction);
			call prxposn(prxNewActionActionDetails, 2, sTable, eTable);
			if sTable > 0 then TableName = substr(line, sTable, eTable);
		end;
	end;

	actionLines + 1;

	/* If end of an action */
	if (endAction) then do;
		posRT = prxmatch(prxEndActionRT, line);
		if posRT > 0 then call prxposn(prxEndActionRT, 1, sRT, eRT);
		if sRT > 0 then RunTime = input(substr(line, sRT, eRT),best.);
		sTime = eTime - RunTime;
		output;
	end;

	format sTime eTime datetime23.3;
	keep line id actionLines runtime sTime eTime user Action TableName;

	*output;
	*if _n_ > 20 then stop;
run;

proc sort data=lasrlog out=lasrlog_s;
	by id sTime;
run;
