libname myhive HADOOP port=10000 schema=default subprotocol=Hive2
	transcode_fail=warning host="192.168.253.131" user=sasdemo;

proc ds2 bypartition=yes ds2accel=yes;
	
	thread t_pgm / overwrite=yes;
		dcl double patternID;

		retain patternID;

		method init();
			/* RegEx pattern to detect MSIE version string */
			patternID = PRXPARSE('/(MSIE\+\d+\.\d)/');
		end;
		
		method run();
			set myhive.weblogs201503;

			/* get MSIE version */
			if (PRXMATCH(patternID,cs_user_agent_)) then 
				msie_version = prxposn(patternID, 1, cs_user_agent_);
			num_requests = 1;
			
			output;
		end;

	endthread;

	data myhive.weblogs201503_tmp(overwrite=yes drop=(patternID));
		declare thread t_pgm t;

		method run();
			set from t;      
		end;
		
	enddata;
	
run; quit;

libname myhive clear;
