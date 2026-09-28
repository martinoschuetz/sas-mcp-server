proc fcmp outfile="./mypgm.sas";
  if __first_in_partition then do;
     total=0;
  end;
  total + sum__n_;
  if __last_in_partition then do;
     output;
  end;
run;

filename fref "./mypgm.sas";

libname dat '\\D75621\data';
libname lasr sasiola start;

data lasr.marketbasket;
  set dat.marketbasket(obs=50000);
run;

proc imstat;
   table lasr.marketbasket;
   compute joinkey "joinkey = user_id || artist_id;";
run;

   table lasr.marketbasket(tempnames=(t1));
   summary t1 / groupby=(user_id artist_id) temptable tn=t1 te="t1=1;"
                                            save=tab1;
   summary t1 / groupby=(user_id          ) temptable tn=t1 te="t1=1;" 
                                            save=tab2;
   store tab1(2,2) = freq_user_artist;
   store tab2(2,2) = freq_user;
run;

   table lasr.&freq_user_artist;
   schema &freq_user(user_id=user_id / name=UserTotal, _n_) / mode=table;
run;

   table lasr.&_templast_;
   compute joinkey "joinkey = user_id || artist_id;";
run;

   table lasr.marketbasket;
   schema &_templast_(joinkey=joinkey / name=r, _n_ UserTotal__N_);
run;

   table lasr.&_templast_;
   compute Rating  "Rating = Round((r__N_/r_UserTotal__n_)*10,2);";
   promote Ratings;
   purgeTempTables;
run;
   table lasr.Ratings;
   fetch;
run;

