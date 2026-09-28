/*
	Ausgangsbasis ist ein reguläres Apache httpd Logfile, das ich als externe Hive Tabelle einlese.
	Im nächsten Schritt gehe ich unter anderem auf das Feld „request“, in dem die URL steht und zerteile
	den String entlang der „/“ bis zu einer Tiefe von 10 Levels. 

	Nebenbei leite ich noch ein paar interessante Felder ab – war der Besucher mit dem Internet Explorer unterwegs, 
	war es ein Bot oder ein Mensch, aus welchen Land kam er (die ersten beiden Tupel der IP Adresse), welche Art von Datei hat er angefragt.

	Interessant (auf Programmierersicht) ist die Nutzung der unterschiedlichen Techniken wie z.B. dynamische Arrays, Schleifen usw. Damit kann man die Leistungsfähigkeit des DS2 in Hadoop zeigen.
*/

proc ds2 indb=yes;
*    ds2_options trace;

     thread compute / overwrite=yes;
          dcl char(7)   classb;
          dcl char(3)   content_type;
          dcl char(255) y tupel1 tupel2 tmp request_file;
          dcl int       i flag_bot;

          vararray char(100) navpath[10] nav1-nav10;

          method run();
              set myhive.demo_stage1;

              request = trim(request);
              host    = trim(host);

              /* ------------------------------------------------ */
              /* extract class b subnet: 192.168.1.1 -> 192.168   */
              tupel1 = substr(host,1,index(host,'.')-1);
              tmp    = substr(host,index(host,'.')+1);
              tupel2 = substr(tmp,1,index(tmp,'.')-1);
              classb = cats(tupel1,'.',tupel2);

              /* ------------------------------------------------ */
              /* split request path into max 10 levels */
              tmp = request;
              do i = 1 to 10;
                   if index(tmp,'/') >= 1 then do;
                        y = substr(tmp,1,index(tmp,'/'));
                        y = tranwrd(y,'/','');
                        navpath[i]=cats('/',y);
                        tmp = substr(tmp,index(tmp,'/')+1);
                    end;
              end;

              /* ------------------------------------------------ */
              /* get requested file */
              tmp=reverse(request);
              request_file = reverse(trim(substr(tmp,1,index(tmp,'/')-1)));
              if index(request_file,'?') >= 1 then 
                   request_file = substr(request_file,1,index(request_file,'?')-1);

              /* ------------------------------------------------ */
              /* set flag if visit is from bot/spider */
              if   index(upcase(agent),'BOT') >= 1 or
                   index(upcase(agent),'SPIDER') >= 1 
              then flag_bot=1;
              else flag_bot=0;

              /* ------------------------------------------------ */
              /* extract requested file type */
              tmp = reverse(request);
              if index(tmp,'.') >= 1 then do;
                   y    = substr(tmp,1,index(tmp,'.')-1);
                   content_type = upcase(reverse(trim(y)));
              end;
          end;
     endthread;

     data myhive.demo_stage2 (drop=(tmp tupel1 tupel2 y i));
          dcl thread compute t;
          method run();
              set from t;
          end;
     enddata;

run; quit;
