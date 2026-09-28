/*
Implementing Stack and Queue Data Structures with SAS® Hash Objects
Contents [hide] 
1 Abstract
2 Online Materials
3 Contact Info
4 References
5 Example Code
Abstract

The SAS hash object is a convenient tool for implementing two common data structures, the stack and the queue. While either of these may be implemented with arrays, the hash object implementation offers the advantage of dynamic memory management – a maximum memory size does not need to be specified in advance. This paper includes a set of SAS macros that can be used in a DATA step to create and delete stacks or queues and to enter or remove data from those data structures.
This paper also contains code for computing the Betweenness Centrality statistic for large social networks.
Online Materials

View the pdf for Implementing Stack and Queue Data Structures with SAS® Hash Objects.
You can also see the PowerPoint Presentation.
Files for this and a related paper are available at: http://www.ipsr.ku.edu/ksdata/sashttp/SGF2009/

Contact Info

User:LarryHoyle
References

Brandes, Ulrik A Faster Algorithm for Betweenness Centrality Journal of Mathematical Sociology 25(2):163-177, (2001)
Hoyle, Larry Visualizing Two Social Networks Across Time with SAS®: Collaborators on a Research Grant vs. Those Posting on SAS-L. SAS Global Forum 2009 paper 229-2009, Washington D.C., 2009
Knuth, Donald E. The Art of Computer Programming, Volume 1: Fundamental Algorithms, Third Edition (Reading, Massachusetts: Addison-Wesley, 1997), xx+650pp. ISBN 0-201-89683-4

Example Code

A complete example of using these macros to compute Betweenness Centrality appears below:
*/

/* Betweenness.sas - compute betweenness as per  Ulrik Brandes's algorithm    */
/*    see:  Brandes, Ulrik  A Faster Algorithm for Betweenness Centrality */
/*          Journal of Mathematical Sociology  25(2):163-177, (2001)  */
/*       Larry Hoyle   October 2008 */
/* ------------------------------------------------------------------------------------ */
/*                    SAMPLE DATA                                                       */
/*                    change the libname statement below as to an empty folder          */
/* ------------------------------------------------------------------------------------ */
libname sgf2009 'C:\SASWork';
options fmtsearch = (SGF2009);

/* For testing */
/* Padgett's graph from Borgatti, Stephen P. */
/* Centrality and network flow. Social Networks 27 (2005) p65  */
data testPadgett;
	length VertexFrom VertexTo $ 9;
	input VertexFrom $ VertexTo $ common;
	keep VertexFrom  VertexTo  common;
	output;

	/*  include reverse links */
	temp = VertexFrom;
	VertexFrom=VertexTo;
	VertexTo=temp;
	output;
	datalines;
Pazzi Salviati      1
Salviati Medici     1
Medici Acciaiuol    1
Medici Barbadori    1
Medici Ridolfi      1
Medici Tornabuon    1
Medici Albizzi      1
Albizzi Ginori      1
Ridolfi Tornabuon   1
Tornabuon Guadagni  1
Albizzi Guadagni    1
Ridolfi Strozzi     1
Barbadori Castellan 1
Castellan Strozzi   1
Strozzi Bischeri    1
Guadagni Bischeri   1
Guadagni Lambertes  1
Castellan Peruzzi   1
Peruzzi Bischeri    1
Peruzzi Strozzi     1
;
run;

proc sql;
	create table unweightedDyads as
		select VertexFrom as VertexFrom, VertexTo as VertexTo, 1 as similarity
			from testPadgett;
quit;

/*  outlib is the library to which the betweenness figures will be output */
%let outlib=SGF2009;
%let outdata=betweennessPadgett;

/* ------------------------------------------------------------------------------------ */
/* StackAndQueue.sas    Macros to implement stacks and queues using the SAS hash object */
/*                       Larry Hoyle - October 2008  */
/* ------------------------------------------------------------------------------------ */
/*  ------------   */
/*  Stack Macros   */
/*  ------------   */
%macro StackDefine(stackName = Stack1,         /*  Name of the stack -                                  */
			/*       use the name in push and pop of this stack      */
			dataType = n,               /*  Datatype n - numeric                                 */
			/*           c - character                               */
			dataLength = 8,             /*  Length of data iitems                                */
			hashexp = 8,                /*  Hashexp for the hash - see the documentation for the */
			/*    hash object. You may want to increase this for     */
			/*    a stack that will get really large                 */
			keyLength = 8,              /*  Length of key  */
			rc = Stack1_rc              /*  return code for stack operations                     */
			);
	/*  the macro will create the following data objects and variables */
	/* &StackName._Hash,        the hash object used for the stack     */
	/* &StackName._key,         the hash object used for the stack     */
	/* &StackName._data,        the hash object used for the stack     */
	/* &StackName._end,         variable to hold the number of objects */
	/*                          in the stack                           */
	retain &StackName._end  0;                        /*  empty stack has 0 items  */
	length &StackName._key &KeyLength;                /*  key is numeric count of items in the stack */
	call missing(&StackName._key);                    /* explicit assignment so SAS does not complain  */

	%IF &dataType EQ n %THEN
		%DO;
			length &StackName._data &datalength;
			retain &StackName._data 0;
		%END;
	%ELSE
		%DO;
			length &StackName._data  $ &datalength;
			retain &StackName._data ' ';
		%END;

	declare hash &StackName._Hash(hashexp: &hashexp);
	&rc = &StackName._Hash.defineKey("&StackName._key");
	&rc = &StackName._Hash.defineData("&StackName._data");
	&rc = &StackName._Hash.defineDone();

	/*  ITEM_SIZE attribute available in SAS 9.2  
	itemSize = &StackName._Hash.ITEM_SIZE;
	*/
	itemSize = 8 + &datalength;

	*put "Stack  &StackName. Created. Each Item will take " ItemSize " bytes.";
%mend StackDefine;

%macro StackPush(stackName = Stack1,          /*  Name of the stack -                                    */
			InputData = Stack1_data,     /*  Variable containing value to be pushed onto the stack  */
			StackLength = Stack1_length, /*  Returns the length of the stack                        */
			rc = Stack1_rc               /*  return code for stack operations                       */
			);
	&StackName._end+1 ;                        /*  new item will go in new location in the hash  */
	&StackLength = &StackName._end;
	&StackName._key = &StackName._end;         /* new value goes at the end */
	&StackName._data = &InputData;             /* value from &InputData  */
	&rc = &StackName._Hash.add();

	if &rc ne 0 then
		put "NOTE: PUSH to stack &stackName failed " &InputData= &StackName._end=;
%mend StackPush;

%macro StackPop(stackName = Stack1,           /*  Name of the stack -                                    */
			OutputData = Stack1_data,     /*  Variable containing value to be pushed onto the stack  */
			StackLength = Stack1_length, /*  Returns the length of the stack                        */
			rc = Stack1_rc               /*  return code for stack operations                       */
			);
	if &StackName._end > 0 then
		do;
			&StackName._key = &StackName._end;          /* return value comes off of the end */
			&rc = &StackName._Hash.find();

			if &rc ne 0 then
				put "NOTE: POP from stack &stackName could not find " &StackName._end=;
			&OutputData = &StackName._data;              /* value into &InputData  */

			/*  remove the item from the hash */
			&rc = &StackName._Hash.remove();

			if &rc ne 0 then
				put "NOTE: POP from stack &stackName could not remove " &StackName._end=;
			&StackName._end = &StackName._end - 1 ;      /*  stack now has 1 fewer item  */
			&StackLength = &StackName._end;
		end;
	else
		do;
			&rc = 999999;
			put "NOTE: Cannot pop empty stack  &StackName into &OutputData ";
		end;
%mend StackPop;

%macro StackLength(stackName = Stack1,          /*  Name of the stack -                                    */
			StackLength = Stack1_length, /*  Returns the length of the stack                        */
			rc = Stack1_rc               /*  return code for stack operations                       */
			);
	&StackLength = &StackName._end;
%mend StackLength;

%macro StackDelete(stackName = Stack1,          /*  Name of the stack -                                    */
			rc = Stack1_rc               /*  return code for stack operations                       */
			);
	&rc = &StackName._Hash.delete();

	if &rc ne 0 then
		put "NOTE: Cannot delete stack  &StackName ";
%mend StackDelete;

%macro StackDump(stackName = Stack1,          /*  Name of the stack -                                    */
			rc = Stack1_rc               /*  return code for stack operations                       */
			);
	if &StackName._end <= 0 then
		do;
			put // "Stack &Stackname is empty";
		end;    /*  &StackName._end <= 0 */
	else
		do;
			put // " Contents of Stack &Stackname:";

			do ixStack = 1 to &StackName._end;
				&StackName._key = ixStack;
				&rc = &StackName._Hash.find();
				put "item " ixStack  "value "  &StackName._data;
			end; /* do ixStack = 1 to &StackName._end  */
		end;  /* not &StackName._end <= 0     */
%mend StackDump;

/*  ------------   */
/*  Queue Macros   */
/*  ------------   */
%macro QueueDefine(QueueName = Queue1,         /*  Name of the Queue -                                  */
			/*       use the name in push and pop of this Queue      */
			dataType = n,               /*  Datatype n - numeric                                 */
			/*           c - character                               */
			dataLength = 8,             /*  Length of data iitems                                */
			hashexp = 8,                /*  Hashexp for the hash - see the documentation for the */
			/*    hash object. You may want to increase this for     */
			/*    a Queue that will get really large                 */
			keyLength = 8,              /*  Length of key  */
			rc = Queue1_rc              /*  return code for Queue operations                     */
			);
	/*  the macro will create the following data objects and variables */
	/* &QueueName._Hash,        the hash object used for the Queue     */
	/* &QueueName._key,         the hash object used for the Queue     */
	/* &QueueName._data,        the hash object used for the Queue     */
	/* &QueueName._old,         variable points to the first item put in the queue */
	/* &QueueName._new,         variable points to the last item put in the queue  */
	/* &QueueName._len,         number of items in the queue  */
	/*                          in the Queue                           */
	retain &QueueName._new  0;                        /*  empty Queue has 0 locations in the hash  */
	retain &QueueName._old  1;                        /*  old will be at location 1 when something is added  */
	retain &QueueName._len  0;                        /*  empty Queue has 0 items  */
	length &QueueName._key 8;                         /*  key is numeric count of items in the Queue */
	call missing(&QueueName._key);                    /* explicit assignment so SAS does not complain  */

	%IF &dataType EQ n %THEN
		%DO;
			length &QueueName._data &datalength;
			retain &QueueName._data 0;
		%END;
	%ELSE
		%DO;
			length &QueueName._data  $ &datalength;
			retain &QueueName._data ' ';
		%END;

	declare hash &QueueName._Hash(hashexp: &hashexp);
	&rc = &QueueName._Hash.defineKey("&QueueName._key");
	&rc = &QueueName._Hash.defineData("&QueueName._data");
	&rc = &QueueName._Hash.defineDone();

	/*  ITEM_SIZE attribute available in SAS 9.2  
	itemSize = &QueueName._Hash.ITEM_SIZE;
	*/
	itemSize = 8 + &datalength;

	* put "Queue  &QueueName. Created. Each Item will take " ItemSize " bytes.";
%mend QueueDefine;

%macro QueueEnqueue(QueueName = Queue1,          /*  Name of the Queue -                                    */
			InputData = Queue1_data,     /*  Variable containing value to be pushed onto the Queue  */
			QueueLength = Queue1_length, /*  Returns the length of the Queue                        */
			rc = Queue1_rc               /*  return code for Queue operations                       */
			);
	&QueueName._new+1 ;                        /*  item goes at new key in hash  */
	&QueueName._len+1 ;                        /*  Queue is 1 longer  */
	&QueueLength = &QueueName._len;
	&QueueName._key = &QueueName._new;         /* new value goes at the end */
	&QueueName._data = &InputData;             /* value from &InputData  */
	&rc = &QueueName._Hash.add();

	if &rc ne 0 then
		put "NOTE: Enqueue to Queue &QueueName failed " &InputData= &QueueName._new=;
%mend QueueEnqueue;

%macro QueueDequeue(QueueName = Queue1,           /*  Name of the Queue -                                    */
			OutputData = Queue1_data,     /*  Variable containing value to be pushed onto the Queue  */
			QueueLength = Queue1_length, /*  Returns the length of the Queue                        */
			rc = Queue1_rc               /*  return code for Queue operations                       */
			);
	if &QueueName._len > 0 then
		do;
			&QueueName._key = &QueueName._old;          /* return value comes from the  oldest location in the hash  */
			&rc = &QueueName._Hash.find();

			if &rc ne 0 then
				put "NOTE: Dequeue from Queue &QueueName could not find " &QueueName._new=;
			&OutputData = &QueueName._data;              /* value into &InputData  */

			/*  remove the item from the hash */
			&rc = &QueueName._Hash.remove();

			if &rc ne 0 then
				put "NOTE: Dequeue from Queue &QueueName could not remove " &QueueName._new=;
			&QueueName._old+1 ;                        /*  item comes from oldest location in the hash  */
			&QueueName._len+(-1) ;                     /*  Queue is 1 shorter  */
			&QueueLength = &QueueName._len;
		end;
	else
		do;
			&rc = 999999;
			put "NOTE: Cannot Dequeue empty Queue  &QueueName into &OutputData ";
		end;
%mend QueueDequeue;

%macro QueueLength(QueueName = Queue1,          /*  Name of the Queue -                                    */
			QueueLength = Queue1_length, /*  Returns the length of the Queue                        */
			rc = Queue1_rc               /*  return code for Queue operations                       */
			);
	&QueueLength = &QueueName._len;
%mend QueueLength;

%macro QueueDelete(QueueName = Queue1,          /*  Name of the Queue -                                    */
			rc = Queue1_rc               /*  return code for Queue operations                       */
			);
	&rc = &QueueName._Hash.delete();

	if &rc ne 0 then
		put "NOTE: Cannot delete Queue  &QueueName ";
%mend QueueDelete;

%macro QueueDump(QueueName = Queue1,          /*  Name of the Queue -                                    */
			rc = Queue1_rc               /*  return code for Queue operations                       */
			);
	if &QueueName._len <= 0 then
		do;
			put // "Queue &Queuename is empty";
		end;    /*  &QueueName._end <= 0 */
	else
		do;
			put // " Contents of Queue &Queuename:";

			do ixQueue = &QueueName._old to &QueueName._new;
				&QueueName._key = ixQueue;
				&rc = &QueueName._Hash.find();
				put "item " ixQueue  "value "  &QueueName._data;
			end; /* do ixQueue = QueueName._old to &QueueName._new   */
		end;  /* not &QueueName._end <= 0     */
%mend QueueDump;

/* ------------------------------------------------------------------------------------ */
/* ----------End of Stack and Queue Macro definitions                    -------------- */
/* ------------------------------------------------------------------------------------ */
/*  *********************************************************************** */
/*                                    FORMATS                               */
/*  *********************************************************************** */
/*  first build a sorted list of Vertex names                  */
/*  these will be used to create a format and informat for   */
/*   converting to and from a Vertex number                    */
proc sql noprint;
	create table Vertices as
		select distinct VertexFrom as Vertex from unweightedDyads
			union
		select distinct VertexTo as Vertex from unweightedDyads
			order by Vertex;
	select max(length(Vertex)) as maxVertexChars
		into :maxVertexChars
			from Vertices;
quit;

%put maximum characters in a vertex =  &maxVertexChars;
%let longestShortPath=300;

/*  make a numbered list of Vertices and formats to convert back and forth  */
data Vertices(keep=Vertex VertexID)  VertexFMTS(keep=fmtname start label type HLO);
	set Vertices nobs=n;
	length VertexID 4 start $ 40 label $ 40 fmtname $ 8;
	retain HLO   ' ';

	if _n_=1 then
		do;
			/* how many characters are needed to print VertexID ?  */
			maxIDchars = int(log10(n) ) + 1;
			call symput('maxIDchars', strip(put(  maxIDchars , 2.)  ));
			maxPathLen = maxIDchars  * min(n,&LongestShortPath);
			call symput('maxPathLen', strip(put(   maxPathLen  , 8.)  ));
			call symput('nVertices', strip(put(n,8.)));

			/*  the two n*n arrays are have cells of   */
			/*   maxPathLen and nVertices */
			call symput('arrayMemRequired',strip(put(   (maxpathLen + 8) * n  * n, comma16.)  ));
			call symput('hashMemRequired',strip(put(   (maxpathLen) * n  * n, comma16.)  ));
		end;

	VertexID=_n_;
	output Vertices;

	/*  informat from Vertex name to VertexID  */
	fmtname = 'VertID';
	type='I';
	start=Vertex;
	label=put(VertexID,8.);
	output VertexFMTS;

	/* format from VertexID to Vertex name  */
	fmtname = 'VertName';
	type='N';
	start=put(VertexID,8.);
	label=Vertex;
	output VertexFMTS;
	;
run;

%put maxIDchars=&maxIDchars   maxPathLen=&maxPathLen    nVertices=&nVertices;

/*  arrange each format or informat to be together  */
proc sort data=VertexFMTS;
	by fmtname start;
run;

/*  define the formats  */
proc format cntlin=VertexFMTS;
run;

/*  *********************************************************************** */
/*                                    NOW COMPUTE BETWEENNESS               */
/*  *********************************************************************** */
data &outlib..&outdata(keep = VertexNumber Vertex  CentralityBetween NumberOfNeighbors);
	set unweightedDyads end=last nobs=ndyads;
	length VertexID NeighborNumber NeighborID CentralityBetween 8;
	length Q_Queue_length Q_Queue_rc 8;
	length w_Neighbor 8;
	length Vertex Stext Vtext Wtext  $ &maxVertexChars;
	format CentralityBetween 10.1;
	array CB_Betweenness{&NVertices} 8 _temporary_ (&NVertices*0);         /*  >> C sub B  <-0 v element of V */

	/*  >> P    an array of lists     */
	array P_Via{&NVertices} $ &maxPathLen _temporary_;                     /*  stored as a hyphen separated list of */

	/*    vertex IDs                         */
	array Sigma_nShortest{&NVertices} 8 _temporary_ (&NVertices*0);        /*  << Sigma - number of shortest paths from s to t */
	array d_minimumPathLength{&NVertices} 8 _temporary_ (&NVertices*0); /*  << d - minimum Path Length from s to t */
	array delta_dependency{&NVertices} 8 _temporary_ (&NVertices*0);       /*  << delta - dependency of s on v  */

	/*  create a hash listing all the neighbors of a Vertex */
	array NeighborsPerVertex{&NVertices} 8 _temporary_ (&NVertices*0);    /* stores number of neighbors in hash  */

	/*  for each vertex                    */
	if _n_=1 then
		do;
			declare hash NeighborsHash(hashexp: 8);
			rc = NeighborsHash.defineKey("VertexID","NeighborNumber");       /* VertexID - Vertex for which neighbors are stored  */

			/* NeighborNumber - ordinal number of neighbor */
			rc = NeighborsHash.DefineData("NeighborID");                     /*  Vertex number of neighbor */
			rc = NeighborsHash.defineDone();
			call missing(VertexID, NeighborNumber, NeighborID);    /*  set these explicitly so SAS won;t complain */
			MemoryRequired =                      /*  compute the memory needed for these data */
			&nVertices *         
				( 8 + &Nvertices + 8 + 8 + 8 + 8 + 16 + 16) +          /* arrays cb + P + Sigma + d + delta + Neighbors + queue + Stack ) */
			nDyads * 16                                            /* dyads in the hash  */
			;
			put 'Memory required ' MemoryRequired  ' bytes';
			put 'Building table of neighbors...';
		end;

	/* load the Neighbors Hash  */
	VertexIDfrom = input(Vertexfrom,VertID.);
	VertexIDto =   input(VertexTo,VertID.);
	VertexID = VertexIDfrom;
	NeighborsPerVertex{VertexID}+1;                    /*  one more neighbor of vertex ID */
	NeighborNumber = NeighborsPerVertex{VertexID};     /*  neighbor number */
	NeighborID = VertexIDto;                            /*  to is a neighbor of from */
	neighborAdd_rc=NeighborsHash.add();

	*put / VertexFrom ' has neighbor ' NeighborNumber VertexTo '                      ' neighborAdd_rc=;
	/*  ---------------------  */
	/*  execute the algorithm  */
	/*  ---------------------  */
	if last then
		do;
			put 'Analyzing shortest paths...';

			do ixS = 1 to &NVertices;                                      /* >> for s element of V   */
				sText = put(ixS, vertName.);

				/* output a progress meter */
				if mod(ixs,10) = 0 then
					put '.';

				if mod(ixs,100) = 0 then
					put '----' stext ixs;

				%StackDefine(stackName = S_Stack,                       /* >> S <=== Empty Stack   */
					dataType = n, 
					dataLength = 8,
					hashexp = 8,
					keyLength = 8,
					rc = Stack_rc              
					);

				*put 'define stack returns: ' Stack_rc= @;
				numItems= S_Stack_HASH.NUM_ITEMS;

				*put numItems=;
				do ixW = 1 to &NVertices;                            /* P[w] <=== empty list w element of V */
					P_Via{ixW} = ' ';
				end;

				do ixT = 1 to &NVertices;                            /* sigma[t] <=== 0, t element of V, sigma[s] <=== 1 */
					if ixT ne ixS then
						Sigma_nShortest{ixT} = 0;
					else Sigma_nShortest{ixT} = 1;
				end;

				do ixT = 1 to &NVertices;                            /* d[t] <=== -1, t element of V, d[s] <=== 0 */
					if ixT ne ixS then
						d_minimumPathLength{ixT} = -1;
					else d_minimumPathLength{ixT} = 0;
				end;

				%QueueDefine(QueueName = Q_Queue,                    /* >> Q <=== Empty Queue   */
					dataType = n, 
					dataLength = 8,
					hashexp = 8,
					keyLength = 8,
					rc = Q_Queue_rc              
					);

				*put 'define queue returns: ' Q_Queue_rc= @;
				numItems= Q_Queue_HASH.NUM_ITEMS;

				*put numItems=;
				%QueueEnqueue(QueueName = Q_Queue,                  /*   << enqueue s ===> Q   */
					InputData = ixS,                       
					QueueLength = Q_Queue_length, /*  Note: used by while loop  */
					rc = Q_Queue_rc               
					);

				*put 'enqueue s ' sText;
				do while (Q_Queue_length > 0);                        /*   << while Q not empty do    */
					%QueueDequeue(QueueName = Q_Queue,                  /*   << dequeue v <=== Q  */
						OutputData = v,                       
						QueueLength = Q_Queue_length,  /*  Note: used by while loop  */
						rc = Q_Queue_rc                
						);
					vText = put(v,vertname.);

					*put '  dequeue as v ' vtext;
					%StackPush(stackName = S_Stack,          
						InputData = v,                            /*  <<  push v ===> S  */
						StackLength = S_Stack_length, 
						rc = S_Stack_rc               
						);

					*put / '  push v ' vtext;
					if NeighborsPerVertex{v} > 0 then                   /*   <<  foreach neighbor w of v do  */

						do ixN = 1 to NeighborsPerVertex{v};
							VertexID = v;
							NeighborNumber = ixN;
							neighborID = .;
							NeighborFind_rc = NeighborsHash.find();      /* The hash returns NeighborID  */
							w_Neighbor =  NeighborID;
							wText = put(w_Neighbor,vertName.);

							*put / '    for neighbor w ' ixN wText  'd minimum path w ' d_minimumPathLength{w_Neighbor};
							/*   <<  if d[w] < 0 then */
							if d_minimumPathLength{w_Neighbor} < 0 then
								do;
									%QueueEnqueue(QueueName = Q_Queue,             /*   << enqueue w ===> Q   */
										InputData = w_Neighbor,                       
										QueueLength = Q_Queue_length, /*  Note: used by while loop  */
										rc = Q_Queue_rc               
										);

									*put '    enqueue w ' wText;
									*put '    d[v] ' d_minimumPathLength{v};
									/*  <<  d[w] <=== d[v] +1 */
									d_minimumPathLength{w_Neighbor} = d_minimumPathLength{v} + 1;

									*put '      d[w]<0 minimum path w ' d_minimumPathLength{w_Neighbor};
								end;  /*  d_minimumPathLength{w_Neighbor} < 0  */

							*put '    d[w] ' d_minimumPathLength{w_Neighbor}  'd[v] ' d_minimumPathLength{v};
							/*  << if d[w] = d[v] +1 */
							if d_minimumPathLength{w_Neighbor} = d_minimumPathLength{v} + 1 then
								do;
									*put '      sigma[w] ' Sigma_nShortest{w_Neighbor} 'sigma[v] ' Sigma_nShortest{w_Neighbor};
									/*  << sigma[w] <=== sigma[w] + sigma[v] */
									Sigma_nShortest{w_Neighbor} = Sigma_nShortest{w_Neighbor} + Sigma_nShortest{v};

									*put '      new sigma[w] ' Sigma_nShortest{w_Neighbor};
									/*  <<  append v ===> P[w] */
									/* a hyphen separated string  */
									if P_Via{w_Neighbor} = ' ' then
										P_Via{w_Neighbor} = strip(put(v,8.));
									else P_Via{w_Neighbor} = catx('-', P_Via{w_Neighbor}, put(v,8.) );

									*put '      append v ' vtext ' P[w] ' P_Via{w_Neighbor};
								end;  /* d_minimumPathLength{w_Neighbor} = d_minimumPathLength{v} + 1 */
						end; /* do ixN = 1 to NeighborsPerVertex{v}  */
				end;    /*  while (Q_Queue_length > 0)   while Q not empty do  */

				do ixV = 1 to &NVertices;                              /*  <<  delta[v] <=== 0, v element of V  */
					delta_dependency{ixV} = 0;
				end;  /* ixV = 1 to &NVertices */

				*put / '  while S  not empty';
				/*  while S not empty  */
				do while (S_Stack_length > 0);
					%StackPop(stackName = S_Stack,                        /*  << pop w <=== S  */
						OutputData = w_Neighbor,                
						StackLength = S_Stack_length, /*  used by while loop  */
						rc = S_Stack_rc               
						);
					wText = put(w_Neighbor,vertName.);

					*put '    popped into w ' wText;
					/*  << for v element of P[w] */
					ixWN = 1;

					do while (scan(P_Via{w_Neighbor},ixWN,'-') ne ' ');
						v=input(scan(P_Via{w_Neighbor},ixWN,'-'),8.);
						vText = put(v,vertName.);

						*put '    v in P[w] ' ixWN vText;
						ixWN=ixWN+1;

						*put '    delta[v] ' delta_dependency(v) 
						        'sigma[v] ' sigma_nShortest(v)
						        'sigma[w] '  sigma_nShortest(w_Neighbor)
							 'delta[w] ' delta_dependency(w_Neighbor);

						/*  << delta[v] <=== delta[v] + sigma[v]/sigma[v]*(1+delta[w])  */
						delta_dependency[v] = delta_dependency(v) + 
							sigma_nShortest(v) / sigma_nShortest(w_Neighbor) *
							(1 + delta_dependency(w_Neighbor));

						*put '      new  delta[v] ' delta_dependency(v);
					end;   /*  while scan(P_Via{w_Neighbor},ixWN,'-') ne ' ' */

					/*  << CsubB[w] <=== CsubB[w] + delta[w] */
					if w_Neighbor ne ixS then
						do;
							*put '      Cb[w] ' CB_Betweenness{w_Neighbor} ' +  delta[w] '  delta_dependency(w_Neighbor);
							CB_Betweenness{w_Neighbor} = CB_Betweenness{w_Neighbor} + 
								delta_dependency(w_Neighbor);

							*put '        new Cb[w] ' CB_Betweenness{w_Neighbor};
						end;   /*  w_Neighbor ne ixS */
				end;  /* while S_Stack_length > 0  */

				/*  end of loop over s element of V - clear out stack and queue  */
				%StackDelete(stackName = S_Stack,          
					rc = Stack_rc               
					);
				%QueueDelete(QueueName = Q_Queue,          
					rc = Queue1_rc               
					);
			end;   /* ixS=1 to &NVertices for s element of V */

			/*    ---------------------------------  */
			/*    output the results to the dataset  */
			/*    ---------------------------------  */
			do vertexNumber = 1 to &NVertices;
				vertex = put(vertexNumber,vertName.);
				CentralityBetween = CB_Betweenness{vertexNumber} / 2;
				NumberOfNeighbors = NeighborsPerVertex{vertexNumber};
				sigma = sigma_nShortest(vertexNumber);
				delta = delta_dependency(vertexNumber);
				output;
			end;  /* ixV = 1 to &NVertices */
		end;  /* if last    execute the algorithm  */
run;

proc rank data=&outlib..&outdata out=&outlib..&outdata.R descending;
	var CentralityBetween NumberOfNeighbors;
	ranks Rank_CentralityBetween Rank_NumberOfNeighbors;
run;