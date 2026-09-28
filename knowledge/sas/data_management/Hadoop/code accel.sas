%LET _CLIENTTASKLABEL='code accel';
%LET _CLIENTPROJECTPATH='D:\Projekte\otto\demo_inthadoop1.egp';
%LET _CLIENTPROJECTNAME='demo_inthadoop1.egp';
%LET _SASPROGRAMFILE=;

/* ---------------------------------------------------- */
libname myhive hadoop subprotocol=hive2 port=10000
    host="inthadoop1.ger.sas.com" schema=gerhje;

proc sql;
	connect to hadoop(port=10000 server="inthadoop1.ger.sas.com" user="gerhje" 
		subprotocol=hive2 schema=gerhje);

	execute(DROP TABLE weblog_stage0) by hadoop;
	execute(DROP TABLE weblog_stage1) by hadoop;

	execute(
		CREATE EXTERNAL TABLE weblog_stage0 (
		  host     CHAR(100),
		  identity CHAR(100),
		  user     CHAR(100),
		  time     CHAR(25),
		  timezone CHAR(10),
		  method   CHAR(10),
		  request  CHAR(255),
		  protocol CHAR(10),
		  status   INT,
		  size     INT,
		  referer  CHAR(255),
		  agent    CHAR(255),
		  domain   CHAR(100)
		)
		ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
		WITH SERDEPROPERTIES (
		  "input.regex" = '([^ ]*) ([^ ]*) ([^ ]*) \\[([^ ]+) ([^ ]+)\\] "([^ ]*) ([^\\"]*) ([^ ]*)" ([^ ]*) ([^ ]*) "([^\\"]*)" "([^\\"]*)" "([^\\"]*)"'
		)
		LOCATION "/user/gerhje/weblogs/www.demo.com/logs"
	) by hadoop;

	execute(
		CREATE TABLE weblog_stage1 (
		  host     CHAR(100),
		  request_time TIMESTAMP,
		  request  CHAR(255),
		  protocol CHAR(10),
		  status   INT,
		  size     INT,
		  referer  CHAR(255),
		  agent    CHAR(255)
		)
		ROW FORMAT DELIMITED
		STORED AS TEXTFILE
	) by hadoop;

	execute(
		INSERT INTO TABLE weblog_stage1
		SELECT host, 
		  CAST(FROM_UNIXTIME(UNIX_TIMESTAMP(time, 'dd/MMM/yyyy:HH:mm:ss'),'yyyy-MM-dd HH:mm:ss') AS TIMESTAMP) AS request_time,
		  request,
		  protocol,
		  status,
		  size,
		  referer,
		  agent
        FROM weblog_stage0
		WHERE time != ""
	) by hadoop;

	disconnect from hadoop;
quit;


/* ---------------------------------------------------- */
proc delete data=myhive.weblog_stage2;run;

proc ds2 ds2accel=yes;

	thread compute / overwrite=yes;
		dcl char(7)   classb;
		dcl char(3)   content_type;
		dcl char(255) y tupel1 tupel2 tmp request_file;
		dcl int       i flag_bot;

		vararray char(100) navpath[10] nav1-nav10;

		method run();
			set myhive.weblog_stage1;

			request = trim(request);
			host    = trim(host);

			/* ------------------------------------------------ */
			/* extract class b subnet: 192.168.1.1 -> 192.168   */
			tupel1 = substr(host,1,index(host,'.')-1);
			tmp    = substr(host,index(host,'.')+1);
			tupel2 = substr(tmp,1,index(tmp,'.')-1);
			classb = cats(tupel1,'.',tupel2);

			/* ------------------------------------------------ */
			/* split request path into max 10 levels */
			tmp = request;
			do i = 1 to 10;
				if index(tmp,'/') >= 1 then do;
					y = substr(tmp,1,index(tmp,'/'));
					y = tranwrd(y,'/','');
					navpath[i]=cats('/',y);
					tmp = substr(tmp,index(tmp,'/')+1);
				end;
			end;

			/* ------------------------------------------------ */
			/* get requested file */
			tmp=reverse(request);
			request_file = reverse(trim(substr(tmp,1,index(tmp,'/')-1)));
			if index(request_file,'?') >= 1 then 
				request_file = substr(request_file,1,index(request_file,'?')-1);

			/* ------------------------------------------------ */
			/* set flag if visit is from bot/spider */
			if 	index(upcase(agent),'BOT') >= 1 or
				index(upcase(agent),'SPIDER') >= 1 
			then flag_bot=1;
			else flag_bot=0;

			/* ------------------------------------------------ */
			/* extract requested file type */
			tmp = reverse(request);
			if index(tmp,'.') >= 1 then do;
				y    = substr(tmp,1,index(tmp,'.')-1);
				content_type = upcase(reverse(trim(y)));
			end;
		end;
	endthread;

	data myhive.weblog_stage2 (drop=(tmp tupel1 tupel2 y i));
		dcl thread compute t;
		method run();
			set from t;
		end;
	enddata;

run; quit;

%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

