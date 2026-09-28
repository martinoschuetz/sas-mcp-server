/* 
 * crop_lines.sas fuer UNIX Umgebungen
*
* Dieses SAS Programm liest alle Dateien eines Verzeichnisses ein, die
* dem gewaehlten Suchmuster entsprechen und ueberprueft sie zeilenweise.
* Falls eine Zeile laenger als das gewaehlte Maximum ist, wird die
* Zeile auf mehrere Zeilen umgebrochen.
* Achtung: das Programm kann einzeilige Kommentare der Form
*   <Sternchen>Text<Strichpunkt>
* nicht erkennen. Sollten solche Zeilen wegen ihrer Laenge umgebrochen werden,
* ergeben sich syntaktische Fehler.
*
* Das Suchmuster kann entweder in der Form
*   %let DIR     =/tmp/test/;
*   %let FILE    =*.sas;
* angegeben werden (damit werden alle SAS Dateien in /tmp/test verarbeitet)
* oder in dieser Form
*   %let DIR     =/tmp/test/;
*   %let FILE    =einedatei.sas;
* Damit wird lediglich die Datei einedatei.sas verarbeitet.
*
* Durch Anpassung der Zeile 51 kann das Programm so geaendert werden, dass
* die ueberarbeiteten Dateien die Originaldateien entweder ueberschreiben
* oder als Kopie abgespeichert werden:
*   newfile = trim(left(filename))||'_new.sas';
* legt eine Kopie der Eingabedatei unter dem Namen <DATEINAME>_new.sas an 
 *   newfile = filename;
* ueberschreibt die Eingabedatei.
*/

/* Define the directory to be scanned for SAS files */
%let DIR     =/tmp/test/;
/* Define the file search pattern to be processed   */
%let FILE    =*.sas;
/* Define the maximum number of characters per line */
%let MAXCHARS=80;

/* ---------------------------------------------------------------------------------------- */
/* LS UNIX command: "ell ess minus one" */
%let LS=ls -1;

/* ---------------------------------------------------------------------------------------- */
%macro scanDirectory;
      filename indir pipe "&LS. &DIR.&FILE.";
      /* read in SAS filenames */
      data files(keep= idx orgfile newfile);
            retain idx;
            infile indir truncover;
            input filename $ 1-255;
            orgfile = filename;
            newfile = trim(left(filename))||'_new.sas';
            if(idx = .) then idx = 0;
            idx = idx + 1;
      run;
%mend;
/* ---------------------------------------------------------------------------------------- */
%scanDirectory;

/* ---------------------------------------------------------------------------------------- */
%macro cropFile(i);
      proc sql noprint;
            select trim(left(orgfile)), trim(left(newfile)) into :orgfile, :newfile 
                  from work.files
                  where idx=&i;
      quit;

      %let newfile = %trim(&newfile.);
      %let orgfile = %trim(&orgfile.);

      %put Scanning &orgfile;

      filename in  "&orgfile.";
      filename out "&newfile.";

      data tmp1;
            infile in dlm='FF'x lrecl=32000;
            length line $ 32000;
            input line $;
      run;

      data new1(keep=text attn);
          retain startpos endpos;
          length text $ &MAXCHARS.;
          set tmp1(rename=(line=inline));

          rec_len     = length(inline);
            if rec_len < &MAXCHARS. then do;               /* line is below max, simply output           */
                  text = inline;
                  attn = "";
                  output;
            end; else do;
                  startpos = 1;
                  endpos   = &MAXCHARS.;
                  do until(startpos > rec_len);
                        if(startpos > 1) then attn = "!";
                        else attn = "";
                        cutchar = substr(inline,endpos,1);
                        if cutchar in (" ") then do;       /* we can cut here, it's a blank              */
                             cutlen = endpos - startpos;
                        end; else do;                                  /* scan previous chars until a blank is found */
                             endpos2 = endpos - 1 ;
                             do i = endpos2 to startpos by -1 until (cutchar in (" "));
                                   cutchar = substr(inline,i,1);
                             end;
                             if(i = 0) then do;                       /* if we can't find a blank, return */
                                   put "Aborting, because there are no blank characters in the next &MAXCHARS. characters.";
                                   put "Either modify this file manually or increase the MAXCHARS value.";
                                   text = substr(inline,startpos,&MAXCHARS.);
                                   put text=;
                                   abort;
                             end;
                             endpos = i;
                             cutlen = i - startpos;
                        end;
                        text = substr(inline,startpos,cutlen);
                        output;
                        startpos = endpos;
                        endpos   = endpos + &MAXCHARS.;
                  end;
            end;
      run;

      data _null_;
            set new1;
            file out;
            if attn EQ "!" then put @ 2 text;
            else                put @ 1 text;
      run;

%mend;

/* ---------------------------------------------------------------------------------------- */
%macro startCropLines;
      %let numrec = 0;
      proc sql noprint;
            select count(*) into: numrec from work.files;
      quit;
      %if &numrec. ^= 0 %then %do;
            %do i=1 %to &numrec.;
                  %cropFile(&i.);
            %end;
      %end;
%mend;
/* ---------------------------------------------------------------------------------------- */
%startCropLines;


