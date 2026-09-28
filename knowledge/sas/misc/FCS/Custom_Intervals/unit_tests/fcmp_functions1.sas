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
 * scenario 1: ci_find_active_period_range
*/
options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar1 outarray=outarray1;
    id date interval=month;
    var air;
    outarrays ps11 pe11 ps12 pe12 ps13 pe13 ps14 pe14
              ps21 pe21 ps22 pe22 ps23 pe23 ps24 pe24
              ps31 pe31 ps32 pe32 ps33 pe33 ps34 pe34
              ps41 pe41 ps42 pe42 ps43 pe43 ps44 pe44
              ps51 pe51 ps52 pe52 ps53 pe53 ps54 pe54
              ps61 pe61 ps62 pe62 ps63 pe63 ps64 pe64;
    outscalars pc11 pc12 pc13 pc14
               pc21 pc22 pc23 pc24
               pc31 pc32 pc33 pc34
               pc41 pc42 pc43 pc44
               pc51 pc52 pc53 pc54
               pc61 pc62 pc63 pc64;
    size=dim(air);
    array tmp[1] / nosymbols;
    call dynamic_array(tmp, size);
    do i=1 to size;
        tmp[i]=air[i];
    end;
    tmp[1]=.;
    tmp[size]=.;
    call ci_find_active_period_range(tmp, 1, 1, ps11, pe11, pc11, rc11);
    call ci_find_active_period_range(tmp, 1, 0, ps12, pe12, pc12, rc12);
    call ci_find_active_period_range(tmp, 0, 1, ps13, pe13, pc13, rc13);
    call ci_find_active_period_range(tmp, 0, 0, ps14, pe14, pc14, rc14);
    do i=1 to size;
        tmp[i]=air[i];
    end;
    tmp[4]=.;
    call ci_find_active_period_range(tmp, 1, 1, ps21, pe21, pc21, rc21);
    call ci_find_active_period_range(tmp, 1, 0, ps22, pe22, pc22, rc22);
    call ci_find_active_period_range(tmp, 0, 1, ps23, pe23, pc23, rc23);
    call ci_find_active_period_range(tmp, 0, 0, ps24, pe24, pc24, rc24);
    do i=1 to size;
        tmp[i]=air[i];
    end;
    tmp[4]=.;
    tmp[10]=.;tmp[11]=.;tmp[12]=.;
    tmp[size]=.;
    call ci_find_active_period_range(tmp, 1, 1, ps31, pe31, pc31, rc31);
    call ci_find_active_period_range(tmp, 1, 0, ps32, pe32, pc32, rc32);
    call ci_find_active_period_range(tmp, 0, 1, ps33, pe33, pc33, rc33);
    call ci_find_active_period_range(tmp, 0, 0, ps34, pe34, pc34, rc34);
    do i=1 to size;
        tmp[i]=.;
    end;
    call ci_find_active_period_range(tmp, 1, 1, ps41, pe41, pc41, rc41);
    call ci_find_active_period_range(tmp, 1, 0, ps42, pe42, pc42, rc42);
    call ci_find_active_period_range(tmp, 0, 1, ps43, pe43, pc43, rc43);
    call ci_find_active_period_range(tmp, 0, 0, ps44, pe44, pc44, rc44); 
    tmp[1]=air[1];
    call ci_find_active_period_range(tmp, 1, 1, ps51, pe51, pc51, rc51);
    call ci_find_active_period_range(tmp, 1, 0, ps52, pe52, pc52, rc52);
    call ci_find_active_period_range(tmp, 0, 1, ps53, pe53, pc53, rc53);
    call ci_find_active_period_range(tmp, 0, 0, ps54, pe54, pc54, rc54);  
    tmp[1]=.;
    tmp[size]=air[size];
    call ci_find_active_period_range(tmp, 1, 1, ps61, pe61, pc61, rc61);
    call ci_find_active_period_range(tmp, 1, 0, ps62, pe62, pc62, rc62);
    call ci_find_active_period_range(tmp, 0, 1, ps63, pe63, pc63, rc63);
    call ci_find_active_period_range(tmp, 0, 0, ps64, pe64, pc64, rc64);   
run;
data outarray1_trim;
    set outarray1;
    keep ps11 pe11 ps12 pe12 ps13 pe13 ps14 pe14
          ps21 pe21 ps22 pe22 ps23 pe23 ps24 pe24
          ps31 pe31 ps32 pe32 ps33 pe33 ps34 pe34
          ps41 pe41 ps42 pe42 ps43 pe43 ps44 pe44
          ps51 pe51 ps52 pe52 ps53 pe53 ps54 pe54
          ps61 pe61 ps62 pe62 ps63 pe63 ps64 pe64;
    if _N_<4;
run;
%tst_log(indent=%str(    ),table=outscalar1);
%tst_log(indent=%str(    ),table=outarray1_trim);

/**
 * scenario 2: ci_find_offseason_period_range
*/
options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar2 outarray=outarray2;
    id date interval=month;
    var air;
    outarrays ps11 pe11 ps12 pe12 ps13 pe13 ps14 pe14
              ps21 pe21 ps22 pe22 ps23 pe23 ps24 pe24
              ps31 pe31 ps32 pe32 ps33 pe33 ps34 pe34
              ps41 pe41 ps42 pe42 ps43 pe43 ps44 pe44
              ps51 pe51 ps52 pe52 ps53 pe53 ps54 pe54
              ps61 pe61 ps62 pe62 ps63 pe63 ps64 pe64;
    outscalars pc11 pc12 pc13 pc14
               pc21 pc22 pc23 pc24
               pc31 pc32 pc33 pc34
               pc41 pc42 pc43 pc44
               pc51 pc52 pc53 pc54
               pc61 pc62 pc63 pc64;
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
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 1, ps11, pe11, pc11, rc11);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 0, ps12, pe12, pc12, rc12);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 1, ps13, pe13, pc13, rc13);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 0, ps14, pe14, pc14, rc14);
    tmp_st[1]=1;
    tmp_end[1]=size;
    tmpCount=1;
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 1, ps21, pe21, pc21, rc21);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 0, ps22, pe22, pc22, rc22);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 1, ps23, pe23, pc23, rc23);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 0, ps24, pe24, pc24, rc24);
    tmp_st[1]=15;    
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 1, ps31, pe31, pc31, rc31);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 0, ps32, pe32, pc32, rc32);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 1, ps33, pe33, pc33, rc33);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 0, ps34, pe34, pc34, rc34);
    tmp_st[1]=1;
    tmp_end[1]=5;
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 1, ps41, pe41, pc41, rc41);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 0, ps42, pe42, pc42, rc42);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 1, ps43, pe43, pc43, rc43);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 0, ps44, pe44, pc44, rc44); 
    tmp_st[2]=10;
    tmp_end[2]=15;
    tmpCount=2;
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 1, ps51, pe51, pc51, rc51);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 0, ps52, pe52, pc52, rc52);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 1, ps53, pe53, pc53, rc53);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 0, ps54, pe54, pc54, rc54);  
    tmp_end[2]=size;
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 1, ps61, pe61, pc61, rc61);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 1, 0, ps62, pe62, pc62, rc62);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 1, ps63, pe63, pc63, rc63);
    call ci_find_offseason_period_range(tmp_st, tmp_end, tmpCount, size, 0, 0, ps64, pe64, pc64, rc64);   
run;
data outarray2_trim;
    set outarray2;
    keep ps11 pe11 ps12 pe12 ps13 pe13 ps14 pe14
          ps21 pe21 ps22 pe22 ps23 pe23 ps24 pe24
          ps31 pe31 ps32 pe32 ps33 pe33 ps34 pe34
          ps41 pe41 ps42 pe42 ps43 pe43 ps44 pe44
          ps51 pe51 ps52 pe52 ps53 pe53 ps54 pe54
          ps61 pe61 ps62 pe62 ps63 pe63 ps64 pe64;
    if _N_<3;
run;
%tst_log(indent=%str(    ),table=outscalar2);
%tst_log(indent=%str(    ),table=outarray2_trim);

/**
 * scenario 3: ci_find_active_event,  ci_find_active_period_range, ci_compute_event_distance ci_find_off_periods_length
*/

proc lua restart;
    submit;
      local rootpath=sas.symget("dc_playpen_path")
      package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
      package.loaded["fscb.common.util"] = nil
      local util = require('fscb.common.util')   
      
      local eventDefList="VALENTINES EASTER HALLOWEEN CHRISTMAS"
      local startDate='"01JAN1949"d'
      local endDate='"31DEC1960"d'
      local vlist = util.split_string(string.upper(eventDefList))
      local eventFile = "work.ciIdEventFile"
      local dataArg = ""
      for i = 1, #vlist do
        dataArg = dataArg.."do year=year1 to year2;".."event_idx="..i.."; event_name='"..vlist[i]
                         .."'; event_date=holiday('"..vlist[i].."', year); weight=1;output; end;"
      end
      rc = sas.submit([[
        data @eventData@;
          format event_idx 8. event_name $20. year 8. event_date date9. weight 8.;
          year1=YEAR(@startDate@)-1;
          year2=YEAR(@endDate@)+1;
          @dataArg@
          keep event_idx event_name year event_date weight;
        run;
      ]],{eventData=eventFile, startDate=startDate, endDate=endDate, dataArg=dataArg, numEvent=#vlist})
    endsubmit;
run;
%let eventFile="work.ciIdEventFile";
%let eventSize=56;
%let interval="MONTH";
options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar3 outarray=outarray3;
    id date interval=month;
    var air;
    outscalars ei1 rc1 ei2 rc2 ei3 rc3 ei4 rc4 ei5 rc5 ec1 drc1 ec2 drc2 ec3 drc3 ec4 drc4 ec5 drc5 nl1 nl2 nl3 nl4 nl5;
    outarray ed1 bd1 ad1 ed2 bd2 ad2 ed3 bd3 ad3 ed4 bd4 ad4 ed5 bd5 ad5;
    size=dim(air);
    array tmp[1] / nosymbols;
    call dynamic_array(tmp, size);
    array periodStart[1] / nosymbols;
    array periodEnd[1] / nosymbols;
    call dynamic_array(periodStart, size);
    call dynamic_array(periodEnd, size);
    do i=1 to size;
        tmp[i]=air[i];
    end;
    call ci_find_active_event(tmp, date, &eventFile, &eventSize, &interval, 0, ei1, rc1);
    call ci_find_active_period_range(tmp, 0, 0, periodStart, periodEnd, periodCount, tmp_rc);
    call ci_get_event_date(&eventFile, &eventSize, ei1, ed1, ec1, tmp_rc);
    call ci_compute_event_distance(periodStart, periodEnd, periodCount, date, size, 
                                   ed1, ec1, &interval, 0, ei1,
                                   bd1, ad1, drc1);
    nl1=ci_find_off_periods_length(periodStart, periodEnd, periodCount, "MIN", size);
    do i=1 to size;
        tmp[i]=.;
    end;
    call ci_find_active_event(tmp, date, &eventFile, &eventSize, &interval, 0, ei2, rc2);
    call ci_find_active_period_range(tmp, 0, 0, periodStart, periodEnd, periodCount, tmp_rc);
    call ci_get_event_date(&eventFile, &eventSize, ei2, ed2, ec2, tmp_rc);
    call ci_compute_event_distance(periodStart, periodEnd, periodCount, date, size, 
                                   ed2, ec2, &interval, 0, ei2,
                                   bd2, ad2, drc2);  
    nl2=ci_find_off_periods_length(periodStart, periodEnd, periodCount, "MODE", size);
    do i=1 to size;
        if month(date[i])=12 then tmp[i]=air[i];
        else tmp[i]=.;
    end;
    call ci_find_active_event(tmp, date, &eventFile, &eventSize, &interval, 0, ei3, rc3);
    call ci_find_active_period_range(tmp, 0, 0, periodStart, periodEnd, periodCount, tmp_rc);
    call ci_get_event_date(&eventFile, &eventSize, ei3, ed3, ec3, tmp_rc);
    call ci_compute_event_distance(periodStart, periodEnd, periodCount, date, size, 
                                   ed3, ec3, &interval, 0, ei3,
                                   bd3, ad3, drc3);
    do i=1 to 3;
        periodEnd[periodCount-i]=periodEnd[periodCount-i]+3;
    end;
    nl3=ci_find_off_periods_length(periodStart, periodEnd, periodCount, "MODE", size);
    do i=1 to size;
        if month(date[i])>9 and month(date[i])<=12 then tmp[i]=air[i];
        else tmp[i]=.;
    end;
    call ci_find_active_event(tmp, date, &eventFile, &eventSize, &interval, 0, ei4, rc4);
    call ci_find_active_period_range(tmp, 0, 0, periodStart, periodEnd, periodCount, tmp_rc);
    call ci_get_event_date(&eventFile, &eventSize, ei4, ed4, ec4, tmp_rc);
    call ci_compute_event_distance(periodStart, periodEnd, periodCount, date, size, 
                                   ed4, ec4, &interval, 0, ei4,
                                   bd4, ad4, drc4);
    do i=1 to 3;
        periodEnd[periodCount-i]=periodEnd[periodCount-i]+2;
    end;
    periodEnd[periodCount]=periodEnd[periodCount]+3;
    nl4=ci_find_off_periods_length(periodStart, periodEnd, periodCount, "LAST", size);
    do i=1 to size;
        if month(date[i])>5 and month(date[i])<10 then tmp[i]=air[i];
        else tmp[i]=.;
    end;
    call ci_find_active_event(tmp, date, &eventFile, &eventSize, &interval, 0, ei5, rc5);
    call ci_find_active_period_range(tmp, 0, 0, periodStart, periodEnd, periodCount, tmp_rc);
    call ci_get_event_date(&eventFile, &eventSize, ei5, ed5, ec5, tmp_rc);
    call ci_compute_event_distance(periodStart, periodEnd, periodCount, date, size, 
                                   ed5, ec5, &interval, 0, ei5,
                                   bd5, ad5, drc5);
    do i=1 to 3;
        periodEnd[periodCount-i]=periodEnd[periodCount-i]+2;
    end;
    periodEnd[periodCount]=periodEnd[periodCount]+3;
    nl5=ci_find_off_periods_length(periodStart, periodEnd, periodCount, "LAST", size);
run;

%tst_log(indent=%str(    ),table=outscalar3);

data work.ciIdEventFile2;
    set work.ciIdEventFile;
    if year(event_date) eq 1959 and event_name ne "CHRISTMAS" then delete;
run;
%let eventFile2="work.ciIdEventFile2";
%let eventSize2=53;
options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar32;
    id date interval=month;
    var air;
    outscalars ei1 rc1 ei2 rc2 ei3 rc3 ei4 rc4 ei5 rc5 ei6 rc6;
    size=dim(air);
    array tmp[1] / nosymbols;
    call dynamic_array(tmp, size);
    do i=1 to size;
        tmp[i]=air[i];
    end;
    call ci_find_active_event(tmp, date, &eventFile2, &eventSize2, &interval, 0, ei1, rc1);
    do i=1 to size;
        tmp[i]=.;
    end;
    call ci_find_active_event(tmp, date, &eventFile2, &eventSize2, &interval, 0, ei2, rc2);
    do i=1 to size;
        if month(date[i])=11 then tmp[i]=air[i];
        else tmp[i]=.;
    end;
    call ci_find_active_event(tmp, date, &eventFile2, &eventSize2, &interval, 0, ei3, rc3);
    do i=1 to size;
        if month(date[i])>9 and month(date[i])<=12 then tmp[i]=air[i];
        else tmp[i]=.;
    end;
    call ci_find_active_event(tmp, date, &eventFile2, &eventSize2, &interval, 0, ei4, rc4);
    do i=1 to size;
        if month(date[i])>5 and month(date[i])<10 then tmp[i]=air[i];
        else tmp[i]=.;
    end;
    call ci_find_active_event(tmp, date, &eventFile2, &eventSize2, &interval, 0, ei5, rc5);

    call ci_find_active_event(tmp, date, &eventFile, &eventSize, &interval, 2, ei6, rc6);    
run;
%tst_log(indent=%str(    ),table=outscalar32);

data outarray3_trim;
    set outarray3;
    if _N_<=6;
run;
%tst_log(indent=%str(    ),table=outarray3_trim);

/**
 * scenario 4: ci_run_forecast
*/
proc lua restart;
    submit;
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.forecast_macro"]   = nil
        local macro =require('fscb.customInterval.forecast_macro')
        local args={}
        args.repositoryNm="work.tmpRepo"
        macro.forecast_macro(args)
    endsubmit;
run;

%let interval="MONTH";
%let seasonality=12;
%let lead=7;
%let criterion="MAPE";
%let repositoryNm="work.tmpRepo";
%let diagEstNm="work.diagEst";
%let indataset="work.indataset";
%let outdataset="work.outdataset";
%let enddate="31DEC1960"d;
options cmplib = &cmp_lib;
proc timedata data=sashelp.air outarray=outarray4;
    id date interval=month;
    var air;
    outarray f11 f12 f2;
    size=dim(air);
    array forecast[1] / nosymbols;
    array fID[1] / nosymbols;
    call dynamic_array(fID, 2*size);
    call dynamic_array(forecast, 2*size);
    call ci_run_forecast(air, date, &interval, &seasonality, &lead, "MIXED", &criterion,
                         &repositoryNm, &diagEstNm, &indataset, &outdataset,
                         forecast, fID, rc);
    j=1;k=1;
    do i=1 to size;
       f11[i]=forecast[i+size];
       f12[i]=forecast[i];
    end;
    call ci_run_forecast(air, date, &interval, &seasonality, 0, "NONNEGATIVE", &criterion, 
                         &repositoryNm, &diagEstNm, &indataset, &outdataset,
                         forecast, fID, rc);
    do i=1 to size;
       f2[i]=forecast[i]; 
    end;
run;
data outarray4_trim;
    set outarray4;
    if _N_<=5 or _N_>=140;
run;
%tst_log(indent=%str(    ),table=outarray4_trim);

/**
 * scenario 5: ci_stretch_squeeze_series
*/
options cmplib = &cmp_lib;
proc timedata data=sashelp.air outarray=outarray5 outscalar=outscalar5;
    id date interval=month;
    var air;
    outarray nps1 npe1 ns1 nps2 npe2 ns2 nps3 npe3 ns3 nps4 npe4 ns4 nps5 npe5 ns5 nps6 npe6 ns6
             os1 os2 os3 os4 os5 os6 os7;
    outscalar nc1 nc2 nc3 nc4 nc5 nc6 oc1 oc2 oc3 oc4 oc5 oc6 oc7;
    size=dim(air);
    array orig[1] / nosymbols;
    array pstart[1] / nosymbols;
    array pend[1] / nosymbols;
    call dynamic_array(orig, 10);
    call dynamic_array(pstart, 10);
    call dynamic_array(pend, 10);
    do i=1 to 10;
        orig[i]=11-i;
    end;
    pstart[1]=1;
    pend[1]=10;
    pcount=1;
    newLen=10;
    call ci_stretch_squeeze_series(orig, pstart, pend, pcount, newLen, nps1, npe1, ns1, nc1, rc1);
    call ci_recover_stretch_squeeze_series(nps1, npe1, ns1, nc1,newLen,pstart, pend, pcount, os1, oc1, rc12);

    newLen=6;
    call ci_stretch_squeeze_series(orig, pstart, pend, pcount, newLen, nps2, npe2, ns2, nc2, rc2);
    call ci_recover_stretch_squeeze_series(nps2, npe2, ns2, nc2,newLen,pstart, pend, pcount, os2, oc2, rc22);
    pstart[1]=1;
    pend[1]=1;
    pcount=1;
    newLen=2;    
    call ci_stretch_squeeze_series(orig, pstart, pend, pcount, newLen, nps3, npe3, ns3, nc3, rc3);
    call ci_recover_stretch_squeeze_series(nps3, npe3, ns3, nc3,newLen,pstart, pend, pcount, os3, oc3, rc32);
    pstart[1]=2;
    pend[1]=10;
    pcount=1;
    newLen=10;   
    call ci_stretch_squeeze_series(orig, pstart, pend, pcount, newLen, nps4, npe4, ns4, nc4, rc4);
    call ci_recover_stretch_squeeze_series(nps4, npe4, ns4, nc4,newLen,pstart, pend, pcount, os4, oc4, rc42);
    pstart[1]=2;
    pend[1]=4;
    pstart[2]=5;
    pend[2]=8;
    pcount=2;
    newLen=2;  
    call ci_stretch_squeeze_series(orig, pstart, pend, pcount, newLen, nps5, npe5, ns5, nc5, rc5); 
    call ci_recover_stretch_squeeze_series(nps5, npe5, ns5, nc5,newLen,pstart, pend, pcount, os5, oc5, rc52);
    pstart[1]=2;
    pend[1]=4;
    pstart[2]=6;
    pend[2]=10;
    pcount=2;
    newLen=3;  
    call ci_stretch_squeeze_series(orig, pstart, pend, pcount, newLen, nps6, npe6, ns6, nc6, rc6); 
    call ci_recover_stretch_squeeze_series(nps6, npe6, ns6, nc6,newLen,pstart, pend, pcount, os6, oc6, rc62);
    nc7=10;
    array ns7[1] / nosymbols;
    call dynamic_array(ns7, nc7);
    do i=1 to nc6; ns7[i]=ns6[i]; end;
    do i=nc6+1 to nc7; ns7[i]=5; end;
    call ci_recover_stretch_squeeze_series(nps6, npe6, ns7, nc7,newLen,pstart, pend, pcount, os7, oc7, rc72);
run;
data outarray5_trim;
    set outarray5;
    if _N_<=11;
run;
%tst_log(indent=%str(    ),table=outarray5_trim);
%tst_log(indent=%str(    ),table=outscalar5);


/**
 * scenario 6: ci_run_forecast2 ci_compute_forecast_measure
*/
options cmplib = &cmp_lib;
proc timedata data=sashelp.air outarray=outarray6 outscalar=outscalar6;
    id date interval=month;
    var air;
    outarray f1 f2 f3 f4 f5;
    outscalar s11 s12 s13 s21 s22 s23 s31 s32 s33 s41 s42 s43 s51 s52 s53
              c11 c12 c13 c21 c22 c23 c31 c32 c33 c41 c42 c43 c51 c52 c53;
    size=dim(air);
    array orig[1] / nosymbols;
    call dynamic_array(orig, 10);
    do i=1 to 10;
        orig[i]=.;
    end;
    call ci_run_forecast2(orig, 5, 5, "MIXED", f1);
    call ci_compute_forecast_measure(orig, f1, 10, "MAPE", s11, c11);
    call ci_compute_forecast_measure(orig, f1, 10, "MAE", s12, c12);
    call ci_compute_forecast_measure(orig, f1, 10, "MSE", s13, c13);
    do i=1 to 4;
        orig[i]=11-i;
    end;
    call ci_run_forecast2(orig, 5, 5, "NONNEGATIVE", f2);
    call ci_compute_forecast_measure(orig, f2, 13, "MAPE", s21, c21);
    call ci_compute_forecast_measure(orig, f2, 10, "MAE", s22, c22);
    call ci_compute_forecast_measure(orig, f2, 10, "MSE", s23, c23);
    do i=1 to 5;
        orig[i]=11-i;
    end;
    call ci_run_forecast2(orig, 5, 5, "NONNEGATIVE", f3); 
    do i=1 to 7;
        orig[i]=11-i;
    end;
    call ci_run_forecast2(orig, 5, 5, "NONNEGATIVE", f4);  
    do i=1 to 10;
        orig[i]=11-i;
    end;
    call ci_run_forecast2(orig, 5, 5, "NONNEGATIVE", f5);  
    call ci_compute_forecast_measure(orig, f5, 10, "MAPE", s31, c31);
    call ci_compute_forecast_measure(orig, f5, 10, "MAE", s32, c32);
    call ci_compute_forecast_measure(orig, f5, 10, "MSE", s33, c33); 
    
    array fcst[1] / nosymbols;
    call dynamic_array(fcst, 10);
    do i=1 to 10;
        fcst[i]=orig[i];
    end;
    call ci_compute_forecast_measure(orig, fcst, 10, "MAPE", s41, c41);
    call ci_compute_forecast_measure(orig, fcst, 10, "MAE", s42, c42);
    call ci_compute_forecast_measure(orig, fcst, 10, "MSE", s43, c43);
    do i=1 to 5;
        orig[i]=0;
    end;
    do i=6 to 11;
        fcst[i]=0;
    end;
    call ci_compute_forecast_measure(orig, fcst, 10, "MAPE", s51, c51); 
    call ci_compute_forecast_measure(orig, fcst, 10, "MAE", s52, c52); 
    call ci_compute_forecast_measure(orig, fcst, 10, "MSE", s53, c53);   
run;
data outarray6_trim;
    set outarray6;
    if _N_<=15;
run;
%tst_log(indent=%str(    ),table=outarray6_trim);
%tst_log(indent=%str(    ),table=outscalar6);

/**
 * scenario 7: ci_find_event_series_seasons ci_combine_series_season ci_event_compute_next_period_distance ci_event_find_trim_info
*/
options cmplib = &cmp_lib;
proc timedata data=sashelp.air outarray=outarray7 outscalar=outscalar7;
    id date interval=month;
    var air;
    outarray ed sc1 sc2 sc3 sc4 sc5 sc6 sc7 sc8 sc9
             comb4 cc4 comb5 cc5 comb6 cc6 comb7 cc7 comb8 cc8 comb9 cc9;
    outscalar csize4 csize5 csize6 csize7 csize8 csize9
              rc41 rc51 rc61 rc71 rc81 rc91
              sl1 sl2 sl3 sl4 sl5 sl6 sl7 sl8 sl9
              nd1 nd2 nd3
              ll1 tl1 etl1 ll2 tl2 etl2 ll3 tl3 etl3;
    size=dim(air);
    array orig[1] / nosymbols;
    array id[1] / nosymbols;
    call dynamic_array(orig, 24);
    call dynamic_array(id, 24);
    do i=1 to 24;
        orig[i]=i;
        id[i]=date[i];
    end;
    call ci_get_event_date(&eventFile, &eventSize, 1, ed, ec, tmp_rc);
    call ci_find_event_series_seasons(id, ed, ec, &interval, 2, 3, sc1, sl1, rc1);
    call ci_find_event_series_seasons(id, ed, ec, &interval, -1, 3, sc2, sl2, rc2);
    call ci_find_event_series_seasons(id, ed, ec, &interval, 3, -1, sc3, sl3, rc3);
    nd1 = ci_event_compute_next_period_distance(ed, ec, &interval, id[1], 2);
    nd2 = ci_event_compute_next_period_distance(ed, ec, &interval, id[1], -1);
    nd3 = ci_event_compute_next_period_distance(ed, ec, &interval, id[1], 3);
    call ci_event_find_trim_info(id, sc1, ed, 24, ec, "MONTH", 2, ll1, tl1, etl1, rc);
    call ci_event_find_trim_info(id, sc2, ed, 24, ec, "MONTH", -1, ll2, tl2, etl2, rc);
    call ci_event_find_trim_info(id, sc3, ed, 24, ec, "MONTH", 3, ll3, tl3, etl3, rc);
    
    do i=1 to 24;
        id[i]=date[i+4];
    end;
    call ci_find_event_series_seasons(id, ed, ec, &interval, 2, 3, sc4, sl4, rc4);
    call ci_find_event_series_seasons(id, ed, ec, &interval, -1, 3, sc5, sl5, rc5);
    call ci_find_event_series_seasons(id, ed, ec, &interval, 3, -1, sc6, sl6, rc6);
    call ci_combine_series_season(orig, sc4, "TOTAL", comb4, cc4, csize4, rc41);
    call ci_combine_series_season(orig, sc5, "AVG", comb5, cc5, csize5, rc51);
    call ci_combine_series_season(orig, sc6, "MIN", comb6, cc6, csize6, rc61);

    do i=1 to 24;
        id[i]=date[i+12];
    end;
    call ci_get_event_date(&eventFile, &eventSize, 2, ed, ec, tmp_rc);
    call ci_find_event_series_seasons(id, ed, ec, &interval, 2, 3, sc7, sl7, rc7);
    call ci_find_event_series_seasons(id, ed, ec, &interval, -1, 3, sc8, sl8, rc8);
    call ci_find_event_series_seasons(id, ed, ec, &interval, 3, -1, sc9, sl9, rc9);
    call ci_combine_series_season(orig, sc7, "MAX", comb7, cc7, csize7, rc71);
    call ci_combine_series_season(orig, sc8, "FIRST", comb8, cc8, csize8, rc81);
    call ci_combine_series_season(orig, sc9, "LAST", comb9, cc9, csize9, rc91);
run;
data outarray7_trim;
   set outarray7;
   format ed MONYY7.;
   if _N_<=24;
run;
%tst_log(indent=%str(    ),table=outarray7_trim);
%tst_log(indent=%str(    ),table=outscalar7);


/**
 * scenario 8: ci_season_compute_option_count
*/

options cmplib = &cmp_lib;
proc timedata data=sashelp.air outscalar=outscalar8;
    id date interval=month;
    var air;
    outscalars oc11 oc12 oc21 oc22 oc23 oc31 oc32 oc33 oc34 oc41 oc42 oc43 oc44;
    size=5;
    array tmp_st[1] / nosymbols;
    array tmp_end[1] / nosymbols;
    call dynamic_array(tmp_st, size);
    call dynamic_array(tmp_end, size);
    tmpCount=0;
    do i=1 to size;
        tmp_st[i]=.;
        tmp_end[i]=.;
    end;
    tmpCount=2;
    tmp_st[1]=1; tmp_end[1]=5; tmp_st[2]=17; tmp_end[2]=20;
    oc11= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 20, 3, 1);
    oc12= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 20, 3, 2);

    tmpCount=3;
    tmp_st[1]=1; tmp_end[1]=5; tmp_st[2]=10; tmp_end[2]=10; tmp_st[3]=15; tmp_end[3]=17;
    oc21= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 20, 3, 1);
    oc22= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 20, 3, 2);
    oc23= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 20, 3, 3);
    tmpCount=4;
    tmp_st[1]=1; tmp_end[1]=2;  tmp_st[2]=32; tmp_end[2]=55; tmp_st[3]=85; tmp_end[3]=108; tmp_st[4]=137; tmp_end[4]=165;
    oc31= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 200, 25, 1);
    oc32= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 200, 25, 2);
    oc33= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 200, 25, 3);
    oc34= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 200, 25, 4);
    tmpCount=4;
    tmp_st[1]=32; tmp_end[1]=52;  tmp_st[2]=84; tmp_end[2]=108; tmp_st[3]=138; tmp_end[3]=162; tmp_st[4]=193; tmp_end[4]=200;
    oc41= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 200, 23, 1);
    oc42= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 200, 23, 2);
    oc43= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 200, 23, 3);
    oc44= ci_season_compute_option_count(tmp_st, tmp_end, tmpCount, 200, 23, 4);
run;

%tst_log(indent=%str(    ),table=outscalar8);
