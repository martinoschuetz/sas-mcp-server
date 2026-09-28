/*
How run actions in several sessions?
Especially useful, when your model is a Python model and MAS is used under the hood!
*/
proc cas;
	session casauto;
	sccasl.runCasl / code="

       names = ${a b c d e f g h i j};

       intables = ${HMEQ_SCORE_1 HMEQ_SCORE_2 HMEQ_SCORE_3 HMEQ_SCORE_4 HMEQ_SCORE_5 HMEQ_SCORE_6 HMEQ_SCORE_7 HMEQ_SCORE_8 HMEQ_SCORE_9 HMEQ_SCORE_10 };

       outtables = ${HMEQ_SCORED_1 HMEQ_SCORED_2 HMEQ_SCORED_3 HMEQ_SCORED_4 HMEQ_SCORED_5 HMEQ_SCORED_6 HMEQ_SCORED_7 HMEQ_SCORED_8 HMEQ_SCORED_9 HMEQ_SCORED_10 };

       do i = 1 to  10;

           session[i] = create_parallel_session(1);

           loadactionset  session=session[i]/ actionset='modelPublishing';

           loadactionset  session=session[i]/ actionset='table';

           loadactionset  session=session[i]/ actionset='dataStep';

           loadactionset  session=session[i]/ actionset='ds2';

		   verifysession session=session[i] async=names[i] / timeout=5 verbose=1; 

           sessionProp.setSessOpt session=session[i] async=names[i] / caslib='Public'; 

           ds2.runModel session=session[i] async=names[i] /

   				modelName='QS_Reg_PyModel',

   				table=intables[i],

   				modelTable={caslib='Public', name='sas_model_table'},

   				casOut=outtables[i];

 

			table.promote session=session[i] async=names[i] /

   			caslib='Public'

   			name=outtables[i];

 

      end; 

    job = wait_for_next_action(0);

    do while(job); 

       print job;

       job = wait_for_next_action(0);

    end;

       

       ";
	run;