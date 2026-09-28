%macro trans(inds,outds);

* CODE TO CREATE A WLT-1 DATASET FROM A UTF-8 DATASET IN A WLT-1 SAS SESSION;
* All characters, which are not defined in WLT-1, are replaced by blanks.;
data &outds.;
  set &inds. (encoding='wlatin1');
  array transcode (*) _character_;
  do i = 1 to dim(transcode);
    transcode(i) = kcvt(transcode(i), 'utf-8', 'wlatin1'); * transcode all character variables;
  end;  
run;

%mend;

%trans(IN.SMA31_EXPORT_TABLE_DE_REL,EG.POSTS_WLT1)
