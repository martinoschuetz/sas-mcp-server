data sascas1.HMEQ(promote="YES"); /* Promote to make available to other sessions */
	set sampsio.HMEQ;
run;

proc cas;
	source casl_code;

		/*
		     Mini-Reference:
		     1. create_parallel_session()      - function to start a parallel session,
		                                         returns session name as string
		     2. term_parallel_session(session) - function to end a parallel session,
		                                         accepts session name as string
		     3. wait_for_next_action()         - waits for action to complete in a parallel session,
		                                         returns dictionary with results, status, session, and job information
		     4. action session="" option       - specifies which session will run action.
		     5. action async="" option         - gives a job name to an asynchronous action,
		                                      returns as part of the return from wait_for_next_action()
		*/

		/* Load Actionset, Save Forest Parameters */
		loadActionset "decisionTree";
		forest_parameters = {
			table = "HMEQ"
			target="BAD",
			inputs={
			"CLAGE", "CLNO", "DEBTINC", "LOAN", "MORTDUE", "VALUE","YOJ", "DELINQ", "DEROG", "JOB", "NINQ"
			},
			nominals={"DELINQ", "DEROG", "JOB", "NINQ", "BAD"},
			nTrees = 1000
			};

		/* Call Actions Sequentially */
		start_time = datetime();
		decisionTree.forestTrain result=forest_res status=forest_st / forest_parameters;
		decisionTree.forestTrain result=forest_res2 status=forest_st2 / forest_parameters;
		sequential_time = datetime() - start_time;

		/* Inspect Results */
		print "Duration of sequential calls: " sequential_time;
		title "First Forest Model Results";
		print forest_res;
		title "Second Forest Model Results";
		print forest_res2;
		title;

		/* Call Actions in Parallel */
		start_time = datetime();

		/* Start Parallel Sessions */
		num_sessions = 2;
		sessions = {};
		results = {};

		do i = 1 to 2;
			sessions[i] = create_parallel_session();
		end;

		/* Submit Sessions */
		decisionTree.forestTrain session = sessions[1] async = "first_forest" / forest_parameters;
		decisionTree.forestTrain session = sessions[2] async = "second_forest" / forest_parameters;

		/* Wait for Sessions to return */
		job = wait_for_next_action();

		do while(job);
			results[job["job"]] = job;
			job = wait_for_next_action();
		end;

		/* Terminate Sessions */
		do session over sessions;
			term_parallel_session(session);
		end;

		parallel_time = datetime() - start_time;

		/* Inspect Results */
		print "Duration of parallel calls: " parallel_time;
		title "First Forest Model Results, Parallel Call";
		print results["first_forest"]["result"];
		title "Second Forest Model Results, Parallel Call";
		print results["second_forest"]["result"];
		title;

		/* Print Results */
		print "Speed Increase from Parallel Sessions: " sequential_time / parallel_time;
	endsource;
	loadActionset "sccasl";
	sccasl.runCasl / code = casl_code;
quit;