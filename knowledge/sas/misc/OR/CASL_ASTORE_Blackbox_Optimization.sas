*------------------------------------------------------------------------------*
| Copyright  2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
| SPDX-License-Identifier: Apache-2.0
|
| Program: ADNOC_drilling_optimization.sas
|
| Description: This script will execute the optimization model and create the output
| tables.
|
|*-----------------------------------------------------------------------------*;



/******************************************************************************/
/******************Start a CAS session and assign libraries********************/
/******************************************************************************/

cas;
libname casuser cas caslib=casuser datalimit=all;
libname public cas caslib=public datalimit=all;

%let lower_bound_col=pct_10;
%let upper_bound_col=pct_95;


proc cas noqueue;
   source pgm; 

	set <str> VARS;
	num lowerBound {VARS};
	num upperBound {VARS};

	read data public.ADNOC_INPUT_BOUNDS into 
		VARS = [VariableName] 
		lowerBound=&lower_bound_col.
		upperBound=&upper_bound_col.
		;

	put VARS=;

	var OptSetPoint{i in VARS} >=lowerBound[i] <=upperBound[i];

      string evalCode;
      source evalCode end=endsrc;
         datastep.runcode/single='yes' code="
            data prodIn;
            DIFF_PRESS="||OptSetPoint['DIFF_PRESS']||";
            BIT_DEPTH=37.2524;
            TOP_DRIVE_TORQUE="||OptSetPoint['TOP_DRIVE_TORQUE']||";
            TOP_DRIVE_RPM="||OptSetPoint['TOP_DRIVE_RPM']||";
            HOLE_DEPTH="||OptSetPoint['HOLE_DEPTH']||";
            PUMP_PRESSURE="||OptSetPoint['PUMP_PRESSURE']||";
            HOOK_LOAD="||OptSetPoint['HOOK_LOAD']||";
            BIT_DIAMETER="||OptSetPoint['BIT_DIAMETER']||";
            MUD_VOLUME="||OptSetPoint['MUD_VOLUME']||";
            FLOW_IN="||OptSetPoint['FLOW_IN']||";
            WEIGHT_ON_BIT="||OptSetPoint['WEIGHT_ON_BIT']||";
            FLOW_RETURN="||OptSetPoint['FLOW_RETURN']||";
			BIT_TYPE='PDC';
         run;";

         astore.score/table='prodIn' 
                      rstore={name='_E8IP6P63ZQUP0FQI32AV0V6BZ_AST', caslib='public'}
                      out={name='PREDICTED_ROP', replace=true};

         fetch result=r/table='PREDICTED_ROP';run;
         f['P_ROP'] = r['Fetch'][1][2];

         send_response(f);
      endsrc;

		/**** TODO : Minimize deviation from target ROP ******/

      max maxROP = caslevaln(evalCode, 'P_ROP', OptSetPoint );
      solve with blackBox/ popsize=100 maxgen=20;


       create data ADNOC_Optimal_Setpoints from 
			[VariableName] = VARS 
			Optimal_Value = OptSetPoint
			Lower_Bound = lowerBound
			Upper_Bound = upperBound
		; 

       create data ADNOC_Objective from 
			maxROP=maxROP
		; 

   endsource;

   optimization.runOptmodel/code=pgm;run;


        datastep.runcode/single='yes' code="
            data ADNOC_Opt_Output;
			set ADNOC_Optimal_Setpoints ADNOC_Objective;
         run;";

		table.promote/
			caslib="casuser"
			name ="ADNOC_Opt_Output"
			target="ADNOC_Opt_Output"
			targetLib="public"
			;

		table.save/
			caslib="public"
			table={name="ADNOC_Opt_Output", caslib="public"}
			name="ADNOC_Opt_Output"
			replace=True
			;


quit;