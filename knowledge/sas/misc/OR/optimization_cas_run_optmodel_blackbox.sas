cas mysession;
caslib _all_ assign;

data public.cars(promote=yes);
   set sashelp.cars;
run;

proc cas;
   source pgm;
      /* original problem sets and parameters */
      set REGRESSORS = /Cylinders EngineSize HorsePower
                        Invoice Length MSRP Weight Wheelbase/;
      string evalCode;

      /* solve regression subproblem for selected regressors */
      source evalCode end=endsrc;
         /* convert Select array into list for glm */
         SELECTED = {};
         do name,val over Select;
            if val > 0.5 then SELECTED = SELECTED + name;
         end;
         action regression.glm result=r /
            table={caslib="Public", name="cars"},
            model={ target='MPG_Highway', effects=SELECTED };
         f['obj'] = r.anova[2,'SS'];
         send_response(f);
      endsrc;

      /* declare master MINLP problem with black-box objective function */
      var Select {REGRESSORS} binary;
      con CardinalityCon:
         sum {j in REGRESSORS} Select[j] <= 4;
      min MasterObjective = caslevaln(evalCode, 'obj', Select);

      /* call black-box solver */
      solve with blackbox;

      /* show the results */
      submit SELECTED=({j in REGRESSORS : Select[j] > 0.5});
         action regression.glm /
            table={caslib="public", name="cars"},
            model={target='MPG_Highway', effects=SELECTED };
      endsubmit;
   endsource;
   optimization.runOptmodel / code=pgm printlevel=2;
quit;

cas mysession terminate;