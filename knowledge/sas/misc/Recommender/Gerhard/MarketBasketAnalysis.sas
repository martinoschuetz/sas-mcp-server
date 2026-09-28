/****************************************************
 *** Dr. Gerhard Svolba, SAS Austria, 2012-03-28
 ***
 *** Macro to test the performance of market basket analysis
 ***       with different numbers of customer and items
 ****************************************************/
libname mba 'C:\Technology\Analytics\MBA';
options fullstimer;

%macro create_mba(nbon,nprod,wksize);
	*** NBON:   number of customers or number of market baskets (distinct IDs);

	*** NPROD:  number of possible items in the baskets (cardinality of the problem)
	           for example number of distinct product-IDs
	*** WKSIZE: average size of market basket, how many products do customers usually have in their basket (on average).;
	%put +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
	%put +++ started with nbon = &nbon nprod = &nprod wksize = &wksize;
	%put +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;

	*** Part 1 - Create MarketBasket Data;
	data work.mba_data;
		do BonID = 1 to &nbon;
			do ProdID = 1 to &nprod;
				if uniform(-434) le &wksize/&nprod then
					output;
			end;
		end;
	run;

	*** 2. Prepare Data for PROC ASSOC;
	proc dmdb batch data=WORK.mba_data
		dmdbcat=WORK.EM_DMDB
		maxlevel = 100001
		normlen= 256
		out=WORK.EM_DMDB;
		id BonID;
		class ProdID(desc);
		target ProdID;
	run;

	quit;

	*** 3. Run Market Basket Analysis with PROC ASSOC;
	proc options option = memsize;
	run;

	options nocleanup;

	proc assoc dmdb data=WORK.EM_DMDB dmdbcat=WORK.EM_DMDB out=mba.Assoc_&nbon._&nprod._&wksize.
		pctsup = 1
		items=2;
/*		support=5;*/
		customer BONID;
		target PRODID;
	run;

	quit;

%mend;

%create_mba(10,75,8);
*%create_mba(100000,16000,8);

/* PROCEDURE ASSOC used (Total process time):
      real time           14:51:05.04
      user cpu time       7:19.96
      system cpu time     10:16.11
      memory              8064759.87k
      OS Memory           8077716.00k
      Timestamp           06/20/2012 02:45:00 AM 
   Computer: germsz-2, 4 Core, 8 Threads, 8 GB Memory, Windows 7 Enterprise SP 1*/

