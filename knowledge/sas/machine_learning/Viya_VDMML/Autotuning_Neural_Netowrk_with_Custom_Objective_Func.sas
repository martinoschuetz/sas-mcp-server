libname mycas cas;

proc cas;
   loadactionset 'image';
   loadactionset 'table';
   loadactionset 'deeplearn';

addCasLib / name='mydatlib', path=' user path here';
quit;

proc casutil;
	load data=sashelp.baseball outcaslib="mydatlib"
	casout="BASEBALL";
run;


proc cas;
 table.shuffle / table='BASEBALL' 
 			  	 casout={name='BASEBALL_shuffled', replace=1};
quit;


ODS EXCLUDE all;
Proc Cas;
/* Build a model shell		 */
BuildModel / modeltable={name='myNN', replace=1} type = 'CNN'; /*CNN should be used instead of DNN, even for tabular data*/
/* Add an input layer		 */
AddLayer / model='myNN' name='data' layer={type='input' std='std'}; 
/* Add several FC layers */
AddLayer / model='myNN' name='fc1' layer={type='fc' n=20 act='RELU'} srcLayers={'data'};
AddLayer / model='myNN' name='fc2' layer={type='fc' n=10 act='RELU'} srcLayers={'fc1'};
/* Add an output layer with softmax activation */
AddLayer / model='myNN' name='outlayer' layer={type='output' act='identity'} srcLayers={'fc2'};

quit;
ODS EXCLUDE None;
/**********************************************/
/* Fetch (print) the Model Architecture Table */
/**********************************************/
 proc cas;  
    table.fetch  /  
     table="myNN"  
    to=500;
quit;

/****************************************/
/* Train the NN model, myNN				*/
/****************************************/


ods output OptIterHistory=ObjectModeliter;
proc cas;
	dlTrain / table={name='BASEBALL_shuffled'} model='myNN' 
        modelWeights={name='NN_trainWeights', replace=1}
        bestweights={name='NN_BestWeights', replace=1}
		inputs={'CrAtBat',
        		'CrBB',
        		'CrHits',
        		'CrHome',
        		'CrRbi',
        		'CrRuns',
				'Position'}
		nominal='Position'
       	target='logSalary' 
        GPU=false
        optimizer={minibatchsize=10, 
	      			algorithm={method='ADAM', lrpolicy='Step', gamma=0.6, stepsize=3,
       							beta1=0.9, beta2=0.999, learningrate=.01}
   					seed=12345,
        			maxepochs=10} 
		seed=12345
		;
;

quit;


/****************************/
/*  Store minimum training  */
/*  and validation error in */
/*  macro variables. 	    */
/****************************/

proc sql noprint;
	select min(FitError)
	into :Train separated by ' '
	from ObjectModeliter;
quit;

title "Baseline Model";
/* Plot Performance */
proc sgplot data=ObjectModeliter;
yaxis label='Misclassification Rate' MAX=.9 min=0;
	series x=Epoch y=FitError / CURVELABEL="&Train" CURVELABELPOS=END;
 run;

/* Save data */
proc cas;
  table.save /
Caslib="mydatlib"
    table="BASEBALL_shuffled"
    name="BASEBALL_shuffled.sashdat"
    replace=True;
quit;



proc cas;
/* SolveBlackBox */

/* BEGIN INIT */
 source caslInit; 
   loadactionset 'image';
   loadactionset 'table';
   loadactionset 'deeplearn';

addCasLib / name='mydatlib', path=' user path here';

loadTable /caslib='mydatlib', path='BASEBALL_shuffled.sashdat' casout={name='BASEBALL_SHUFFLED', replace=1};
/* END INIT */
endsource;
run;

/* BEGIN EVALUATION */
source evalcode; 

/* Build a model shell		 */
BuildModel / modeltable={name='myNN', replace=1} type = 'CNN'; /*CNN should be used instead of DNN, even for tabular data*/
/* Add an input layer		 */
AddLayer / model='myNN' name='data' layer={type='input' std='std'}; 
/* Add several FC layers */
AddLayer / model='myNN' name='fc1' layer={type='fc' n=HU_count1 act=FC_activ_1} srcLayers={'data'};
AddLayer / model='myNN' name='fc2' layer={type='fc' n=HU_count2 act=FC_activ_2} srcLayers={'fc1'};
/* Add an output layer with softmax activation */
AddLayer / model='myNN' name='outlayer' layer={type='output' act='identity'} srcLayers={'fc2'};


/* ELU = 10 */
/* RELU = 8 */
/* Leaky = 12 */
/* Softplus = 9 */
/* Gaussian error linear unit = 13 */

FCact1=(string)FC_activ_1;
FCact2=(string)FC_activ_2;


mytbl.name  ="myNN"; 
mytbl.where = "_DLKey0_ = 'fc1' and  _DLKey1_ = 'fcopts.act'";
table.update /  table=mytbl  set = {{var="_DLNumVal_", value=FCact1}};
mytbl.name  ="myNN"; 
mytbl.where = "_DLKey0_ = 'fc2' and  _DLKey1_ = 'fcopts.act'";
table.update /  table=mytbl  set = {{var="_DLNumVal_", value=FCact2}};





	dlTrain / table={name='BASEBALL_shuffled'} model='myNN' 
        modelWeights={name='NN_trainWeights', replace=1}
        bestweights={name='NN_BestWeights', replace=1}
		inputs={'CrAtBat',
        		'CrBB',
        		'CrHits',
        		'CrHome',
        		'CrRbi',
        		'CrRuns',
				'Position'}
		nominal='Position'
       	target='logSalary' 
        GPU=false
        optimizer={minibatchsize=Min_Batch, 
	      			algorithm={method='ADAM', lrpolicy='Step', gamma=0.6, stepsize=3,
       							beta1=0.9, beta2=0.999, learningrate=L_rate}
   					seed=12345,
        			maxepochs=10} 
		seed=12345
		;
;

	dlScore result=s / table={name='BASEBALL_shuffled'} model='myNN' 
				initWeights='NN_BestWeights'
				gpu=false;

	Error=2*s['ScoreInfo'][3]['Value'];
	f['objVal']=Error; 

send_response(f);
run;
/* END EVALUATION */
endsource;


optimization.solveblackbox / 
decVars = {
	/* neuron count */
	{name='HU_count1', type="I", lb=1, ub=5}
	{name='HU_count2', type="I", lb=1, ub=5}
	/* Activation function types */
/* ELU = 10 */
/* RELU = 8 */
/* Softplus = 9 */
	{name='FC_activ_1', type="I", lb=8, ub=10}
	{name='FC_activ_2', type="I", lb=8, ub=10}
	/* Hyperparameter values */
	{name='Min_Batch', type="C", lb=5, ub=30}
	{name='L_rate', type="C", lb=.001, ub=.1}
},
obj = {{name='objVal', type='min'}},
outputTables={includeall=true}
display={excludeAll=FALSE} 

/* Data contining already sampled decision point combinations: */
/* 	CACHEIN={name='Already_sampled_input'} */
/* Data contining best performing decision point combinations: */
/* 	firstgen={name='best_input'}   */
/* Output data contining searched decision point combinations and corresponding performance */
	CACHEOUT={name="Mydemo", replace=true}

	func = {init=caslInit, eval=evalcode},
	  
	  nParallel=1,
      popsize=10,  
      nlocal=1,
      maxGen=5,
	  nabsfconv=1000000000,
	  maxtime=400

Seed=12345;
run;
quit;

proc cas;  
    table.fetch  /  
     table="Mydemo"  
    to=3500 sortby={
      {name="objVal", order="ascending"}};  
 quit; 

