cas sascas4 nworkers=4;

proc cas; setsessopt/metrics=true; run; quit;

libname mycaslib cas sessref=sascas4;

proc optmodel sessref=sascas4;
   set ASSETS;
   num return {ASSETS};
   num cov {ASSETS, ASSETS} init 0;
   read data mycaslib.pf_means into ASSETS=[_n_] return;
   read data mycaslib.pf_cov into [asset1 asset2] cov cov[asset2,asset1]=cov;
   num riskLimit init 0.00025;
   num minThreshold init 0.1;
   num numTrials = 10;

   /* declare NLP problem for fixed set of assets */
   set ASSETS_THIS;
   var AssetPropVar {ASSETS_THIS} >= minThreshold <= 1; 
   max ExpectedReturn = 
      sum {i in ASSETS_THIS} return[i] * AssetPropVar[i]; 
   con RiskBound:
      sum {i in ASSETS_THIS, j in ASSETS_THIS} cov[i,j] * AssetPropVar[i] * AssetPropVar[j] <= riskLimit;
   con TotalPortfolio:
      sum {asset in ASSETS_THIS} AssetPropVar[asset] = 1;

   num infinity = constant('BIG');
   num best_objective init -infinity;
   set INCUMBENT;
   num sol {INCUMBENT};

   num overall_start;
   overall_start = time();
   set TRIALS = 1..numTrials;
   num start  {TRIALS};
   num finish {TRIALS};
   call streaminit(1);
   cofor {trial in TRIALS} do;
      start[trial] = time() - overall_start;
      put;
      put trial=;
      ASSETS_THIS = {i in ASSETS: rand('UNIFORM') < 0.5};
      put ASSETS_THIS=;
      solve with NLP / logfreq=0;
      put ASSETS_THIS=;
      put _solution_status_=;
      if _solution_status_ in {'OPTIMAL','BEST_FEASIBLE'} then do;
			put ExpectedReturn= ASSETS_THIS=;
			if best_objective < ExpectedReturn then do;
				best_objective = ExpectedReturn;
				INCUMBENT = ASSETS_THIS;
				put best_objective= INCUMBENT=;
				put RiskBound.body= RiskBound.ub=;
				put TotalPortfolio.body= TotalPortfolio.ub=;
				for {i in INCUMBENT} sol[i] = AssetPropVar[i];
			end;
      end;
      finish[trial] = time() - overall_start;
   end;
   put best_objective= INCUMBENT=;
   for {i in INCUMBENT} put i sol[i];
   create data solution from [Asset]=INCUMBENT Investment=sol;
quit;

proc contents data=solution; run;

proc print data=solution; run;



