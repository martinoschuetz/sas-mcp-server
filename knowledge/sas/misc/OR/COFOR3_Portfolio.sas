data means;
   input return;
   datalines;
0.000065763 
0.002604107 
0.000753611 
0.000082178 
-.000380250 
0.000399003 
0.002421262 
0.002412429 
0.000773394 
0.000403047 
0.001361435 
;

data covdata;
   input cov asset1 asset2;
   datalines;
0.001353751 1 1 
0.000468578 1 2 
0.001280990 1 3 
-.000032003 1 4 
0.000731890 1 5 
0.000660113 1 6 
0.000641176 1 7 
0.000466734 1 8 
0.000683927 1 9 
0.000658789 1 10 
0.000606616 1 11 
0.000307035 2 2 
0.000534959 2 3 
-.000006434 2 4 
0.000310362 2 5 
0.000304408 2 6 
0.000348148 2 7 
0.000243561 2 8 
0.000311989 2 9 
0.000301229 2 10 
0.000282500 2 11 
0.001448759 3 3 
-.000031943 3 4 
0.000772008 3 5 
0.000745441 3 6 
0.000782744 3 7 
0.000554453 3 8 
0.000762838 3 9 
0.000745559 3 10 
0.000719599 3 11 
0.000026314 4 4 
-.000027629 4 5 
-.000025069 4 6 
-.000016775 4 7 
-.000016202 4 8 
-.000026060 4 9 
-.000026031 4 10 
-.000019917 4 11 
0.000510235 5 5 
0.000463580 5 6 
0.000471570 5 7 
0.000346507 5 8 
0.000479810 5 9 
0.000463526 5 10 
0.000424889 5 11 
0.000455959 6 6 
0.000471924 6 7 
0.000332697 6 8 
0.000462159 6 9 
0.000455080 6 10 
0.000421059 6 11 
0.000572171 7 7 
0.000371153 7 8 
0.000473532 7 9 
0.000470686 7 10 
0.000449428 7 11 
0.000316483 8 8 
0.000337295 8 9 
0.000331312 8 10 
0.000328404 8 11 
0.000482038 9 9 
0.000462024 9 10 
0.000429875 9 11 
0.000456097 10 10 
0.000420613 10 11 
0.000460050 11 11 
;

proc optmodel;
   set ASSETS;
   num return {ASSETS};
   num cov {ASSETS, ASSETS} init 0;
   read data means into ASSETS=[_n_] return;
   read data covdata into [asset1 asset2] cov cov[asset2,asset1]=cov;
   num riskLimit init 0.00025;
   num minThreshold init 0.1;
   num numTrials = 20;

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

proc print data=solution; run;
