/* This code assumes that your target is binary coded */
/* ( 0 , 1 ) where 1 is the event and 0 the non-event */

/* The Area Under the ROC Curve can be determined     */
/* from the rank-sum in class 1 out of a              */
/* Wilcoxon-Mann-Whitney test statistic               */
/* See course notes                                   */
/* Predictive Modeling using Logistic Regression, p.132 */

ods output WilcoxonScores=work.WilcoxonScores;

filename tt catalog "work.t.t.source";

data _NULL_;
 file tt;
put 'proc npar1way data=&EM_IMPORT_VALIDATE EDF WILCOXON;';
put ' class '"%EM_TARGET"';';
put ' var P_'"%EM_TARGET"'1;';
put 'run;';
run;

%include tt;

filename tt clear;

data _NULL_;
 set work.WilcoxonScores end = last;
 file print; /* outputting to output window */ 
 retain n0;
 if (_N_=1 and Class='0') then n0=n; 
 if (last  and Class='1') then do;
  n1=n;
  c = ( (SumOfScores - 0.5*n1*(n1+1)) / (n1*n0) ); 
  Gini_coeff = (2 * c) - 1;
  round_c = round(c,.001);
  round_Gini_coeff = round(Gini_coeff,.001);
 end;

if last then do;
 put "Overall Predictive Power statistics";
 put "-----------------------------------";
 put "     ";
 put "c-stat (proc logistic) = " round_c;
 put "ROC index              = " round_c; 
 put "Area Under ROC Curve   = " round_c;
 put "AUC_ROC                = " round_c;
 put "     ";
 put "Gini coefficient = 2 * ROC index - 1 = ( ( ROC index - 0.5 ) / 0.5 )";
 put "     ";
 put "Gini coefficient       = " round_Gini_coeff; 
 put "Accuracy Ratio (AR)    = " round_Gini_coeff;
 put "     ";
 put "AR is defined in Basel II Committee on Banking Supervision Working Paper No. 14";
 put "Studies on the Validation of Internal Rating Systems (revised) - May 2005";
 put "     ";
 put "Geometrically this means:";
 put "     ";
 put "Area Under ROC curve : you divide area under ROC curve by the square";
 put "Gini : Do not consider lower triangular part of ROC chart,";
 put "then divide remaining area under ROC curve by the upper triangle";
 put "     ";
 put "Gini coefficient (Accuracy Ratio) =";
 put "(area below power curve for current model minus area below power curve for baseline model)";
 put "divided by";
 put "(area below power curve for perfect model minus area below power curve for baseline model)";
 put "     ";
 put "power curve = Cumulative % Captured Response curve";
 put "power curve = Lorenz curve = Cumulative Accuracy Profile (CAP) curve = concentration curve";
 put "     ";
 put "CAP is defined in Basel II Committee on Banking Supervision Working Paper No. 14";
 put "Studies on the Validation of Internal Rating Systems (revised) - May 2005";
 put "     ";
end;
run;
/* end of program */
