libname TMLIB 'C:\Projekte\Daten\TMLIB';

proc tmspell
    DIFFROLE
	data=tmp.key1
	out=tmp.TMSPELL
	dict=TMLIB.TM_dict_OO_Thesaurus
	DICTPEN=1
	maxchildren=10
	minparents=3
	maxspedis=15
;
run;

/*

Schreibweise Normierung und Reduktion;

Optional Arguments 
	DICT=data-set-name
		This argument specifies the data set to use as a dictionary. The TMSPELL procedure 
		assumes that all terms in data-set-name are spelled correctly. This data set must contain 
		the variable term. The number of false positives can be significantly reduced when a dictionary data set is used.
	DICTPEN=number
		This argument specifies the penalty that is applied when a child term is found in 
		the dictionary data set. The default value is 2.
	DIFFERENTROLE | DIFFERENT ROLE | DIFFROLE
		By default, terms are compared only if they have the same part of speech. If this option 
		is specified, then terms with different parts of speech will be compared.
		Consider the term “left,” which can be a noun, adjective, or verb. If the adjective “left” 
		and the noun “left” appear in fewer than MAXCHILDREN= documents and the verb “left” appears 
		in more than MINPARENTS= documents, then the TMSPELL procedure will identify all instances of 
		“left” as a verb. This specific example is covered in “Example 3: Specifying Other Options” on page 395 .
	MAXCHILDREN=number
		This argument specifies the maximum number of documents that a term can appear in to be considered 
		a child. The default value is 6.
	MAXSPEDIS=number
		This argument specifies the maximum allowable distance between a parent and a child. Because the 
		proprietary distance is asymmetric, both distances are calculated and the shorter of the two is 
		returned. The default value is 15.
	MINPARENTS=number
		This argument specifies the minimum number of documents that a term must appear in to be considered 
		as a parent. The default value is 3.
	MULTIPEN=number
		This argument specifies the penalty that is applied when either a child or a parent is a 
		multi-word term. The value of number is multiplied by the value that was returned by the 
		proprietary distance function. The default value is 2.


The TMSPELL procedure divides the term bank into two sets in order
to identify misspellings in the document collection. First, the 
list of candidate children is created from all terms that appear in 
less than MAXCHILDREN= documents. Then, the list of possible parents
is created from all the terms that appear in more than 
MINPARENTS= documents. If a dictionary is specified, then all of the 
terms in the dictionary are added to the list of possible parents. Next, 
the TMSPELL procedure finds the minimum distance from each candidate 
child c to every parent p that starts with the same letter as c. 
Because the proprietary distance function is not symmetric, the distance 
is computed in both directions and then divided by the length of the 
shorter of the two terms. If either the parent or child is a multi-word 
term, then the distance is multiplied by MULTIPEN=. Likewise, if the child 
is found in the dictionary, then the distance is multiplied by DICTPEN=. 
Finally, if the distance between the child and parent is less than MAXSPEDIS=, 
then the two terms are identified as synonyms.
*/