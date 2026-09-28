/**
 * Functionality: compute statistics using fcmp functions
 * 
   @email yue.li@sas.com
 */

/***************************************************************************************************************/

%let cmp_lib = work.ciFunc;
proc lua restart;
    submit;
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.fcmp_functions"]   = nil
        local func =require('fscb.customInterval.fcmp_functions')
        local cmpLib=sas.symget("cmp_lib")
        func.fcmp_functions(cmpLib)
    endsubmit;
run;

/**
 * scenario 1: ci_split_series_by_period ci_combine_two_series_by_period
*/

options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar1 outarray=outarray1;
    id date interval=month;
    var air;
    outarrays in1 off1 c1 in2 off2 c2 in3 off3 c3;
    outscalars ic11 oc11 ic12 oc12 cc1 ic21 oc21 ic22 oc22 cc2 ic31 oc31 ic32 oc32 cc3;
    size=20;
    array series[1] / nosymbols;
    array tmp_st[1] / nosymbols;
    array tmp_end[1] / nosymbols;
    call dynamic_array(series, size);
    call dynamic_array(tmp_st, size);
    call dynamic_array(tmp_end, size);
    tmpCount=0;
    do i=1 to size;
        series[i]=i;
        tmp_st[i]=.;
        tmp_end[i]=.;
    end;
    tmpCount=2;
    tmp_st[1]=1; tmp_end[1]=5; tmp_st[2]=17; tmp_end[2]=20;
    call ci_split_series_by_period(series, size, tmp_st, tmp_end, tmpCount,
                                   in1, off1, ic11, oc11);
    call ci_combine_two_series_by_period(in1, off1, size, tmp_st, tmp_end, tmpCount,
                                         c1, ic12, oc12, cc1);

    tmpCount=3;
    tmp_st[1]=1; tmp_end[1]=5; tmp_st[2]=10; tmp_end[2]=10; tmp_st[3]=15; tmp_end[3]=17;
    call ci_split_series_by_period(series, size, tmp_st, tmp_end, tmpCount,
                                   in2, off2, ic21, oc21);
    call ci_combine_two_series_by_period(in2, off2, size, tmp_st, tmp_end, tmpCount,
                                     c2, ic22, oc22, cc2);    
    tmpCount=3;
    tmp_st[1]=3; tmp_end[1]=5; tmp_st[2]=10; tmp_end[2]=10; tmp_st[3]=15; tmp_end[3]=17;
    call ci_split_series_by_period(series, size, tmp_st, tmp_end, tmpCount,
                                   in3, off3, ic31, oc31);
    call ci_combine_two_series_by_period(in3, off3, size, tmp_st, tmp_end, tmpCount,
                                         c3, ic32, oc32, cc3);    
run;
data outarray1_trim;
    set outarray1;
    if _N_<=20;
run;
%tst_log(indent=%str(    ),table=outscalar1);
%tst_log(indent=%str(    ),table=outarray1_trim);

/**
 * scenario 2: ci_compute_profile
*/

options cmplib = &cmp_lib;
proc timedata data=sashelp.air outarray=outarray2;
    id date interval=month;
    var air;
    outarrays p1 p2 p3 p4;
    size=20;
    array series[1] / nosymbols;
    array tmp_st[1] / nosymbols;
    array tmp_end[1] / nosymbols;
    call dynamic_array(series, size);
    call dynamic_array(tmp_st, size);
    call dynamic_array(tmp_end, size);
    tmpCount=0;
    do i=1 to size;
        series[i]=i;
        tmp_st[i]=.;
        tmp_end[i]=.;
    end;
    tmpCount=0;
    call ci_compute_profile(series, tmp_st, tmp_end, tmpCount, 5, p1);
    tmpCount=1;
    tmp_st[1]=1; tmp_end[1]=6;
    call ci_compute_profile(series, tmp_st, tmp_end, tmpCount, 5, p2);
    tmpCount=2;
    tmp_st[1]=1; tmp_end[1]=7; tmp_st[2]=17; tmp_end[2]=20;
    call ci_compute_profile(series, tmp_st, tmp_end, tmpCount, 5, p3);

    tmpCount=3;
    tmp_st[1]=1; tmp_end[1]=5; tmp_st[2]=10; tmp_end[2]=10; tmp_st[3]=15; tmp_end[3]=17;
    call ci_compute_profile(series, tmp_st, tmp_end, tmpCount, 5, p4);
 
run;
data outarray2_trim;
    set outarray2;
    if _N_<=5;
run;
%tst_log(indent=%str(    ),table=outarray2_trim);
/**
 * scenario 3: ci_compute_profile
*/

options cmplib = &cmp_lib;
proc timedata data=sashelp.air outarray=outarray3 outscalar=outscalar3;
    id date interval=month;
    var air;
    outarrays o11 o12 o13 o14 o21 o22 o23 o24;
    outscalars os11 os12 os13 os14 os21 os22 os23 os24;
    array comb[20] / nosymbols;
    array profile[5] / nosymbols;
    array combCount[20] / nosymbols;
    profile[1]=5; profile[2]=2; profile[3]=2; profile[4]=3; profile[5]=6;
    combSize=15;
    do i=1 to 5;
        comb[i]=.;
    end;
    do i=6 to 15;
        comb[i]=i;
    end;
    do i=1 to 15;
        combCount[i]=1;
    end;
    combCount[10]=3; combCount[15]=4;
    call ci_recover_combine_series(comb, combCount, combSize, "TOTAL", profile, o11, os11, rc11);
    call ci_recover_combine_series(comb, combCount, combSize, "AVG", profile, o12, os12, rc12);
    call ci_recover_combine_series(comb, combCount, combSize, "MED", profile, o13, os13, rc13);
    call ci_recover_combine_series(comb, combCount, combSize, "MIN", profile, o14, os14, rc14);
    
    combCount[10]=2; combCount[11]=5; combCount[15]=1;
    call ci_recover_combine_series(comb, combCount, combSize, "FIRST", profile, o21, os21, rc21);
    call ci_recover_combine_series(comb, combCount, combSize, "MAX", profile, o22, os22, rc22);
    call ci_recover_combine_series(comb, combCount, combSize, "MODE", profile, o23, os23, rc23);
    call ci_recover_combine_series(comb, combCount, combSize, "LAST", profile, o24, os24, rc24);
 
run;
data outarray3_trim;
    set outarray3;
    if _N_<=20;
run;
%tst_log(indent=%str(    ),table=outscalar3);
%tst_log(indent=%str(    ),table=outarray3_trim);

/**
 * scenario 4: ci_find_season_series_seasons
*/

options cmplib = &cmp_lib;
proc timedata data=sashelp.air outarray=outarray4 outscalar=outscalar4;
    id date interval=month;
    var air;
    outarrays s1 s21 s22 s23 s24 s25 s26 s31 s32 s33 s34 s35;
    outscalar rc1 rc21 rc22 rc23 rc24 rc25 rc26 rc31 rc32 rc33 rc34 rc35;
    size=20;
    array tmp_st[1] / nosymbols;
    array tmp_end[1] / nosymbols;
    call dynamic_array(tmp_st, size);
    call dynamic_array(tmp_end, size);
    tmpCount=0;
    do i=1 to size;
        tmp_st[i]=.;
        tmp_end[i]=.;
    end;
    tmpCount=0;
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 1, s1, rc1);
    tmpCount=2;
    tmp_st[1]=1; tmp_end[1]=6; tmp_st[2]=18; tmp_end[2]=20;
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 1, s21, rc21);
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 2, s22, rc22);
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 3, s23, rc23);
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 4, s24, rc24);
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 5, s25, rc25);
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 6, s26, rc26);

    tmpCount=3;
    tmp_st[1]=1; tmp_end[1]=4; tmp_st[2]=8; tmp_end[2]=12; tmp_st[3]=14; tmp_end[3]=17;
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 1, s31, rc31);
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 2, s32, rc32);
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 3, s33, rc33);
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 4, s34, rc34);
    call ci_find_season_series_seasons(tmp_st, tmp_end, tmpCount, size, 5, 5, s35, rc35);
 
run;
data outarray4_trim;
    set outarray4;
    if _N_<=20;
run;
%tst_log(indent=%str(    ),table=outarray4_trim);
%tst_log(indent=%str(    ),table=outscalar4);

/**
 * scenario 5: ci_find_season_start_index
*/

options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar5;
    id date interval=month;
    var air;
    outscalar ss1 ss21 ss22 ss23 ss24 ss25 ss26
                  ss31 ss32 ss33 ss34 ss35 ss36
                  ss41 ss42 ss43 ss44 ss45 ss46;
    size=144;
    array tmp_st[1] / nosymbols;
    array tmp_si[1] / nosymbols;
    call dynamic_array(tmp_st, size);
    call dynamic_array(tmp_si, size);
    tmpCount=0;
    do i=1 to 40;
        tmp_si[i]=i+12;
    end;
    do i=41 to 93;
        tmp_si[i]=i-40;
    end;
    do i=94 to size;
        tmp_si[i]=i-93;
    end;
    do i=1 to size;
        tmp_st[i]=.;
    end;
    tmpCount=0;
    ss1=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "LAST");
    tmpCount=1;
    tmp_st[1]=40;
    ss21=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MIN");
    ss22=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MAX");
    ss23=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MEAN");
    ss24=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MODE");
    ss25=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MED");
    ss26=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "LAST");
    tmpCount=3;
    tmp_st[1]=40; tmp_st[2]=90; tmp_st[3]=size;
    ss31=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MIN");
    ss32=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MAX");
    ss33=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MEAN");
    ss34=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MODE");
    ss35=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MED");
    ss36=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "LAST");
    tmpCount=6;
    tmp_st[1]=40;tmp_st[2]=45; tmp_st[3]=90; tmp_st[4]= 93; 
    tmp_st[5]=95; tmp_st[6]=size-1;
    ss41=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MIN");
    ss42=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MAX");
    ss43=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MEAN");
    ss44=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MODE");
    ss45=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "MED");
    ss46=ci_find_season_start_index(tmp_st, tmpCount, tmp_si, "LAST");    
 
run;

%tst_log(indent=%str(    ),table=outscalar5);

/**
 * scenario 6: ci_find_off_periods_by_code, ci_find_inseason_periods_by_code
*/

options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar6 outarray=outarray6;
    id date interval=month;
    var air;
    outscalar oc11 oc12 oc13 oc14 pc11 pc12 pc13 pc14
              oc21 oc22 oc23 oc24 pc21 pc22 pc23 pc24
              oc31 oc32 oc33 oc34 pc31 pc32 pc33 pc34
              oc41 oc42 oc43 oc44 pc41 pc42 pc43 pc44
              oc51 oc52 oc53 oc54 pc51 pc52 pc53 pc54
              oc61 oc62 oc63 oc64 pc61 pc62 pc63 pc64
              ;
    outarray os11 oe11 os12 oe12 os13 oe13 os14 oe14 ps11 pe11 ps12 pe12 ps13 pe13 ps14 pe14
             os21 oe21 os22 oe22 os23 oe23 os24 oe24 ps21 pe21 ps22 pe22 ps23 pe23 ps24 pe24
             os31 oe31 os32 oe32 os33 oe33 os34 oe34 ps31 pe31 ps32 pe32 ps33 pe33 ps34 pe34
             os41 oe41 os42 oe42 os43 oe43 os44 oe44 ps41 pe41 ps42 pe42 ps43 pe43 ps44 pe44
             os51 oe51 os52 oe52 os53 oe53 os54 oe54 ps51 pe51 ps52 pe52 ps53 pe53 ps54 pe54
             os61 oe61 os62 oe62 os63 oe63 os64 oe64 ps61 pe61 ps62 pe62 ps63 pe63 ps64 pe64
             ;
    array code[40];
    do i=1 to 40;
        code[i]=0;
    end;
    call ci_find_off_periods_by_code(code, 0, 0,os11, oe11, oc11);
    call ci_find_off_periods_by_code(code, 0, 1,os12, oe12, oc12);
    call ci_find_off_periods_by_code(code, 1, 0,os13, oe13, oc13);
    call ci_find_off_periods_by_code(code, 1, 1,os14, oe14, oc14);
    call ci_find_inseason_periods_by_code(code, 0, 0, ps11, pe11, pc11);
    call ci_find_inseason_periods_by_code(code, 0, 0, ps12, pe12, pc12);
    call ci_find_inseason_periods_by_code(code, 0, 0, ps13, pe13, pc13);
    call ci_find_inseason_periods_by_code(code, 0, 0, ps14, pe14, pc14);
    do i=1 to 40;
      code[i]=mod(i,10);
      if code[i] eq 0 then code[i]=10;
    end;
    call ci_find_off_periods_by_code(code, 0, 0,os21, oe21, oc21);
    call ci_find_off_periods_by_code(code, 0, 1,os22, oe22, oc22);
    call ci_find_off_periods_by_code(code, 1, 0,os23, oe23, oc23);
    call ci_find_off_periods_by_code(code, 1, 1,os24, oe24, oc24);
    call ci_find_inseason_periods_by_code(code, 0, 0, ps21, pe21, pc21);
    call ci_find_inseason_periods_by_code(code, 0, 1, ps22, pe22, pc22);
    call ci_find_inseason_periods_by_code(code, 1, 0, ps23, pe23, pc23);
    call ci_find_inseason_periods_by_code(code, 1, 1, ps24, pe24, pc24);

    do i=1 to 40;
        code[i]=0;
    end;
    do i=1 to 5; code[i]=i+5; end;
    do i=16 to 25; code[i]=i-15; end;
    do i=36 to 40; code[i]=i-35; end;
    call ci_find_off_periods_by_code(code, 0, 0,os31, oe31, oc31);
    call ci_find_off_periods_by_code(code, 0, 1,os32, oe32, oc32);
    call ci_find_off_periods_by_code(code, 1, 0,os33, oe33, oc33);
    call ci_find_off_periods_by_code(code, 1, 1,os34, oe34, oc34);
    call ci_find_inseason_periods_by_code(code, 0, 0, ps31, pe31, pc31);
    call ci_find_inseason_periods_by_code(code, 0, 1, ps32, pe32, pc32);
    call ci_find_inseason_periods_by_code(code, 1, 0, ps33, pe33, pc33);
    call ci_find_inseason_periods_by_code(code, 1, 1, ps34, pe34, pc34);
    
    do i=1 to 40;
        code[i]=0;
    end;
    do i=1 to 10; code[i]=i; end;
    do i=21 to 30; code[i]=i-20; end;
    call ci_find_off_periods_by_code(code, 0, 0,os41, oe41, oc41);
    call ci_find_off_periods_by_code(code, 0, 1,os42, oe42, oc42);
    call ci_find_off_periods_by_code(code, 1, 0,os43, oe43, oc43);
    call ci_find_off_periods_by_code(code, 1, 1,os44, oe44, oc44);
    call ci_find_inseason_periods_by_code(code, 0, 0, ps41, pe41, pc41);
    call ci_find_inseason_periods_by_code(code, 0, 1, ps42, pe42, pc42);
    call ci_find_inseason_periods_by_code(code, 1, 0, ps43, pe43, pc43);
    call ci_find_inseason_periods_by_code(code, 1, 1, ps44, pe44, pc44);  
    
    do i=1 to 40;
        code[i]=0;
    end;
    do i=6 to 15; code[i]=i-5; end;
    do i=26 to 35; code[i]=i-25; end;
    call ci_find_off_periods_by_code(code, 0, 0,os51, oe51, oc51);
    call ci_find_off_periods_by_code(code, 0, 1,os52, oe52, oc52);
    call ci_find_off_periods_by_code(code, 1, 0,os53, oe53, oc53);
    call ci_find_off_periods_by_code(code, 1, 1,os54, oe54, oc54);
    call ci_find_inseason_periods_by_code(code, 0, 0, ps51, pe51, pc51);
    call ci_find_inseason_periods_by_code(code, 0, 1, ps52, pe52, pc52);
    call ci_find_inseason_periods_by_code(code, 1, 0, ps53, pe53, pc53);
    call ci_find_inseason_periods_by_code(code, 1, 1, ps54, pe54, pc54);    
    
    do i=1 to 40;
        code[i]=0;
    end;
    do i=6 to 15; code[i]=i-5; end;
    do i=31 to 40; code[i]=i-30; end;
    call ci_find_off_periods_by_code(code, 0, 0,os61, oe61, oc61);
    call ci_find_off_periods_by_code(code, 0, 1,os62, oe62, oc62);
    call ci_find_off_periods_by_code(code, 1, 0,os63, oe63, oc63);
    call ci_find_off_periods_by_code(code, 1, 1,os64, oe64, oc64);
    call ci_find_inseason_periods_by_code(code, 0, 0, ps61, pe61, pc61);
    call ci_find_inseason_periods_by_code(code, 0, 1, ps62, pe62, pc62);
    call ci_find_inseason_periods_by_code(code, 1, 0, ps63, pe63, pc63);
    call ci_find_inseason_periods_by_code(code, 1, 1, ps64, pe64, pc64);    
run;
data outarray6_trim;
    set outarray6;
    if _N_<=4;
run;
%tst_log(indent=%str(    ),table=outarray6_trim);
%tst_log(indent=%str(    ),table=outscalar6);

/**
 * scenario 7: ci_season_compute_next_period_distance
*/

options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar7;
    id date interval=month;
    var air;
    outscalar d1 d2 d3 d4 d5 d6 d7 d8;

    d1=ci_season_compute_next_period_distance("WEEK", 20007, 41, 50, 52);
    d2=ci_season_compute_next_period_distance("WEEK", 20007, 41, 6, 52);
    d3=ci_season_compute_next_period_distance("WEEK", 20371, 40, 50, 52);
    d4=ci_season_compute_next_period_distance("WEEK", 20371, 40, 6, 52);
    d5=ci_season_compute_next_period_distance("MONTH", 20089, 1, 6, 12);
    d6=ci_season_compute_next_period_distance("MONTH", 20089, 1, 1, 12);
    
    d7=ci_season_compute_next_period_distance("", 20007, 41, 50, 52);
    d8=ci_season_compute_next_period_distance("MONTH", 20007, 41, 6, 52);
 
run;

%tst_log(indent=%str(    ),table=outscalar7);

/**
 * scenario 8: ci_season_find_trim_info, ci_generate_forecast_one
*/
%let repositoryNm = "work.TmpModRepCopy";
%let diagEstNm = "work.TmpDiagEst";
%let indataset = "work.TmpInDataSet";
%let outdataset = "work.TmpOutDataSet";
proc lua restart;
    submit;
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.forecast_macro"]   = nil
        local macro =require('fscb.customInterval.forecast_macro')
        local args={}
        args.repositoryNm="work.TmpModRepCopy"
        macro.forecast_macro(args)
    endsubmit;
run;
options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar81 outarray=outarray81;
    id date interval=month;
    var air;
    outscalar ll1 tl1 etl1 ss1 os11 os12 os13 os14 ll2 tl2 etl2 ss2 os21 os22 os23 os24;
    outarray d1 sc1 f11 f12 f13 f14 d2 sc2 f21 f22 f23 f24;
    size=50;
    array si[50];
    do i=1 to 50;
      d1[i]=mod(i,10);
      if d1[i]>5 then d1[i]=0;
      sc1[i]=d1[i];
      si[i]=mod(i,10);
      if si[i]=0 then si[i]=10;
    end;
    array inPeriodStart[1]/NOSYMBOLS; call dynamic_array(inPeriodStart, size); 
    array inPeriodEnd[1]/NOSYMBOLS; call dynamic_array(inPeriodEnd, size);
    call ci_find_inseason_periods_by_code(sc1, 0, 1,inPeriodStart, inPeriodEnd, inPeriodCount);
    ss1=ci_find_season_start_index(inPeriodStart, inPeriodCount, si, "MODE");      
    call ci_season_find_trim_info(air, sc1, si, size, "MONTH", 10, ss1, 
                                  ll1, tl1, etl1, rc);
    call ci_generate_forecast_one(d1, sc1, size, ll1, tl1, etl1, 5, "MODE", "ACCUMULATE", "MODE", "ALL", "MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f11, os11, rc);
    call ci_generate_forecast_one(d1, sc1, size, ll1, tl1, etl1, 5, "MODE", "SEPARATE", "MODE", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f12, os12, rc);
    call ci_generate_forecast_one(d1, sc1, size, ll1, tl1, etl1, 5, "MODE", "ACCUMULATE", "MODE", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f13, os13, rc); 
    call ci_generate_forecast_one(d1, sc1, size, ll1, tl1, etl1, 5, "MODE", "SEPARATE", "MODE", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f14, os14, rc);
    do i=1 to 50;
      d2[i]=mod(i+8,10);
      if d2[i]>5 then d2[i]=0;
      sc2[i]=d2[i];
    end;  
    call ci_find_inseason_periods_by_code(sc2, 0, 1,inPeriodStart, inPeriodEnd, inPeriodCount);
    ss2=ci_find_season_start_index(inPeriodStart, inPeriodCount, si, "MODE");      
    call ci_season_find_trim_info(air, sc2, si, size, "MONTH", 10, ss2, 
                                  ll2, tl2, etl2, rc);                               
    call ci_generate_forecast_one(d2, sc2, size, ll2, tl2, etl2, 5, "MODE", "ACCUMULATE", "MODE", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f21, os21, rc);
    call ci_generate_forecast_one(d2, sc2, size, ll2, tl2, etl2, 5, "MODE", "SEPARATE", "MODE", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f22, os22, rc);
    call ci_generate_forecast_one(d2, sc2, size, ll2, tl2, etl2, 5, "MODE", "ACCUMULATE", "MODE", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f23, os23, rc); 
    call ci_generate_forecast_one(d2, sc2, size, ll2, tl2, etl2, 5, "MODE", "SEPARATE", "MODE", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f24, os24, rc);    
run;
data outarray81_trim;
    set outarray81;
    if _N_<=55;
run;
%tst_log(indent=%str(    ),table=outarray81_trim);
%tst_log(indent=%str(    ),table=outscalar81);

proc timedata data=sashelp.air outscalar=outscalar82 outarray=outarray82;
    id date interval=month;
    var air;
    outscalar tml3 os31 os32 os33 os34 tml4 os41 os42 os43 os44;
    outarray d3 sc3 f31 f32 f33 f34 d4 sc4 f41 f42 f43 f44;
    size=50;
    do i=1 to 50;
      d3[i]=mod(i+5,10);
      if d3[i]>5 then d3[i]=0;
      sc3[i]=d3[i];
      if i>38 then d3[i]=.;
    end;    
    tml3=ci_compute_trail_missing_length(d3, size); 
    call ci_generate_forecast_one(d3, sc3, size, 5, 0, 0, 5, "MODE", "ACCUMULATE", "MODE", "ALL","MIXED", "MAE",
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f31, os31, rc);
    call ci_generate_forecast_one(d3, sc3, size, 5, 0, 0, 5, "MODE", "SEPARATE", "MODE", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f32, os32, rc);
    call ci_generate_forecast_one(d3, sc3, size, 5, 0, 0, 5, "MODE", "ACCUMULATE", "MODE", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f33, os33, rc); 
    call ci_generate_forecast_one(d3, sc3, size, 5, 0, 0, 5, "MODE", "SEPARATE", "MODE", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f34, os34, rc);   
                                  
    do i=1 to 50;
      d4[i]=mod(i+8,10);
      if d4[i]>5 then d4[i]=0;
      sc4[i]=d4[i];
      if i>38 then d4[i]=.;
    end;    
    tml4=ci_compute_trail_missing_length(d4, size); 
    call ci_generate_forecast_one(d4, sc4, size, 2, 3, 5, 5, "MODE", "ACCUMULATE", "MODE", "ALL","MIXED", "MAE",
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f41, os41, rc);
    call ci_generate_forecast_one(d4, sc4, size, 2, 3, 5, 5, "MODE", "SEPARATE", "MODE", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f42, os42, rc);
    call ci_generate_forecast_one(d4, sc4, size, 2, 3, 5, 5, "MODE", "ACCUMULATE", "MODE", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f43, os43, rc); 
    call ci_generate_forecast_one(d4, sc4, size, 2, 3, 5, 5, "MODE", "SEPARATE", "MODE", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f44, os44, rc);                                     
run;
data outarray82_trim;
    set outarray82;
    if _N_<=55;
run;
%tst_log(indent=%str(    ),table=outarray82_trim);
%tst_log(indent=%str(    ),table=outscalar82);

proc timedata data=sashelp.air outscalar=outscalar83 outarray=outarray83;
    id date interval=month;
    var air;
    outscalar os11 os12 os13 os14 os21 os22 os23 os24;
    outarray d1 sc1 f11 f12 f13 f14 d2 sc2 f21 f22 f23 f24;
    size=30;
    do i=1 to 5; d1[i]=5-abs(i-3); sc1[i]=i; end; 
    do i=6 to 12; d1[i]=abs(i-9)*0.1; sc1[i]=0; end; 
    do i=13 to 17;  d1[i]=6-abs(i-15); sc1[i]=i-12; end;
    do i=18 to 20; d1[i]=abs(i-19)*0.3; sc1[i]=0;end;
    do i=21 to 25; d1[i]=7-abs(i-23); sc1[i]=i-20; end;
    do i=26 to 30; d1[i]=abs(i-28)*0.3; sc1[i]=0;end;
    call ci_generate_forecast_one(d1, sc1, size, 0, 5, 5, 5, "MEAN", "ACCUMULATE", "TOTAL", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f11, os11, rc);
    call ci_generate_forecast_one(d1, sc1, size, 0, 5, 5, 5, "MEAN", "SEPARATE", "TOTAL", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f12, os12, rc);
    call ci_generate_forecast_one(d1, sc1, size, 0, 5, 5, 5, "MEAN", "ACCUMULATE", "TOTAL", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f13, os13, rc); 
    call ci_generate_forecast_one(d1, sc1, size, 0, 5, 5, 5, "MEAN", "SEPARATE", "TOTAL", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f14, os14, rc);
    do i=1 to 2; d2[i]=0.1*i; sc2[i]=0; end;                              
    do i=3 to 30; d2[i]=d1[i-2]; sc2[i]=sc1[i-2]; end;
                                   
    call ci_generate_forecast_one(d2, sc2, size, 2, 3, 5, 5, "MEAN", "ACCUMULATE", "TOTAL", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f21, os21, rc);
    call ci_generate_forecast_one(d2, sc2, size, 2, 3, 5, 5, "MEAN", "SEPARATE", "TOTAL", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f22, os22, rc);
    call ci_generate_forecast_one(d2, sc2, size, 2, 3, 5, 5, "MEAN", "ACCUMULATE", "TOTAL", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f23, os23, rc); 
    call ci_generate_forecast_one(d2, sc2, size, 2, 3, 5, 5, "MEAN", "SEPARATE", "TOTAL", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f24, os24, rc);                                      
run;
data outarray83_trim;
    set outarray83;
    if _N_<=32;
run;
%tst_log(indent=%str(    ),table=outarray83_trim);
%tst_log(indent=%str(    ),table=outscalar83);

proc timedata data=sashelp.air outscalar=outscalar84 outarray=outarray84;
    id date interval=month;
    var air;
    outscalar os11 os12 os13 os14 os21 os22 os23 os24;
    outarray d1 sc1 f11 f12 f13 f14 d2 sc2 f21 f22 f23 f24;
    size=40;
    do i=1 to 5; d1[i]=5-abs(i-3); sc1[i]=i; end; 
    do i=6 to 12; d1[i]=abs(i-9)*0.1; sc1[i]=0; end; 
    do i=13 to 17;  d1[i]=6-abs(i-15); sc1[i]=i-12; end;
    do i=18 to 20; d1[i]=abs(i-19)*0.3; sc1[i]=0;end;
    do i=21 to 25; d1[i]=7-abs(i-23); sc1[i]=i-20; end;
    do i=26 to 30; d1[i]=abs(i-28)*0.3; sc1[i]=0;end;
    do i=31 to 35; d1[i]=.; sc1[i]=i-30; end;
    do i=36 to 40; d1[i]=.; sc1[i]=0; end;

    
    call ci_generate_forecast_one(d1, sc1, size, 0, 5, 5, 5, "MEAN", "ACCUMULATE", "TOTAL", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f11, os11, rc);
    call ci_generate_forecast_one(d1, sc1, size, 0, 5, 5, 5, "MEAN", "SEPARATE", "TOTAL", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f12, os12, rc);
    call ci_generate_forecast_one(d1, sc1, size, 0, 5, 5, 5, "MEAN", "ACCUMULATE", "TOTAL", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f13, os13, rc); 
    call ci_generate_forecast_one(d1, sc1, size, 0, 5, 5, 5, "MEAN", "SEPARATE", "TOTAL", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f14, os14, rc);
    do i=1 to 2; d2[i]=0.1*i; sc2[i]=0; end;                              
    do i=3 to 40; d2[i]=d1[i-2]; sc2[i]=sc1[i-2]; end;
                                   
    call ci_generate_forecast_one(d2, sc2, size, 2, 3, 6, 5, "MEAN", "ACCUMULATE", "TOTAL", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f21, os21, rc);
    call ci_generate_forecast_one(d2, sc2, size, 2, 3, 6, 5, "MEAN", "SEPARATE", "TOTAL", "ALL","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f22, os22, rc);
    call ci_generate_forecast_one(d2, sc2, size, 2, 3, 6, 5, "MEAN", "ACCUMULATE", "TOTAL", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f23, os23, rc); 
    call ci_generate_forecast_one(d2, sc2, size, 2, 3, 6, 5, "MEAN", "SEPARATE", "TOTAL", "AVG","MIXED", "MAE", 
                                  &repositoryNm, &diagEstNm, &indataset, &outdataset, f24, os24, rc);                                      
run;
data outarray84_trim;
    set outarray84;
    if _N_<=43;
run;
%tst_log(indent=%str(    ),table=outarray84_trim);
%tst_log(indent=%str(    ),table=outscalar84);
