/*
Copyright (c) 2006 by SAS Institute Inc., Cary, NC 27513.  All Rights Reserved.

copyToWebDAV

This macro takes a directory and then publishes all the files in it to a WebDAV server. 

Parameters:
dirname - name of the directory on the local filesystem, e.g. 'c:\myfiles'
davloc - URL to publish to, e.g. 'http://domain.com/sasdav/public/myfiles'
		each directory to be published should go to a unique directory on 
		the DAV server. If the directory already exists on the DAV server, 
		IT WILL BE OVERWRITTEN. This macro only copies the files in the 
                directory; it will ignore any subdirectories.
userid - userid to authenticate to the WebDAV server, e.g. 'domain\sasdemo'
                Make sure this user has permission to write to davloc.
passwd - password to authenticate to the WebDAV server, preferably encoded and
		not clear text.

Example usage:

%include "copyToWebDAV.sas";

%copyToWebDAV('c:\myfiles', 'http://localhost:8300/sasdav/myfiles', 'domain\userid', 'Password');

*/

%macro copyToWebDAV(dirname, davloc, userid, passwd);

%let delim='/';
%if &sysscp=WIN %then %let delim='\';

data _null_;
   rc    = 0;
   pid   = 0;

   desc = "WebDAVContent Portlet data";
   nameValue = "";

   Call package_begin(pid, desc, nameValue, rc);
   if rc ne 0 then do
      msg = sysmsg();
      put msg;
      ABORT;
   end;
   put 'Package init successful.';

   rc = filename('mypak', &dirname);
   if rc ne 0 then  do;
      msg = sysmsg();
      put msg;
      ABORT;
   end;

   dirid = dopen('mypak');
   memcount = dnum(dirid);
   do i = 1 to memcount;
      currentfile = dread(dirid, i);
      fileToPublish = &dirname || &delim || trim(currentfile);
      /* skip over subdirectories */
      rc = filename('mytmp', fileToPublish);
      if rc ne 0 then  do;
         msg = sysmsg();
         put msg;
         ABORT;
      end;
      d = dopen('mytmp');
      if d = 0 then do;
         /* must be a file (not dir), so publish it */
         put fileToPublish;
         fileType ="binary";
         userString = "";

         CALL INSERT_FILE(pid, "filename:" || fileToPublish, fileType, userString, desc, nameValue, rc);

         if rc ne 0 then do;
            msg = sysmsg();
            put msg;
            ABORT;
         end;
      end;
      did = dclose(d);
   end;
   rc = dclose(dirid);

   pubType = "TO_WEBDAV";
   properties="COLLECTION_URL, HTTP_USER, HTTP_PASSWORD";

   call package_publish(pid, pubType, rc, properties, &davloc, &userid, &passwd);
   if rc ne 0 then  do;
      msg = sysmsg();
      put msg;
      ABORT;
   end;
   put 'Publish successful';

   Call package_end(pid, rc);
   if rc ne 0 then  do;
      msg = sysmsg();
      put msg;
      ABORT;
   end;
   put 'Package term successful';

run;

%mend copyToWebDAV;
