/* Copyright (c) 2025 by SAS Institute Inc., Cary, NC USA 27513 */

/*
options mprint mprintnest mlogic spool;
*/
/*
This macro takes a flat hierachy file (dsin=) showing one complete branch of a hierachy per line, e.g. Level0, Level1, Level2, ..., LeafName
and transforms this information into
an asset hierarchy file (dsout) with columns Node and Parent, i.e. the edges in the tree.
This version assumes that the hierarchy columns follow the naming Level0, ..., Leveln.
dsin:		Flat hierarchy input file.
dsout: 		Transactional hierarchy output file which edges of the hierachy.
LeafName:	Name of the leaf column in the flat hierachy file
duplicates:	'YES' allows for duplicates in the edges list, 'NO' filters duplicates out.
keys:		'YES' eliminates special characters from names of edges. 'NO': Omits this step
*/
%macro create_node_parent_list(dsin=, dsout=, LeafName=, duplicates=, keys=);

	/* Special characters to be exchanged by a matching list of replace characters used in the translate function.
	Some special characters are quoted with a %. */
	%local special_chars replace_chars;
	%let special_chars=%str(!%"#$&%'()*+,-./:;<=>?@[]^_`{|}~% );
	%let replace_chars=%sysfunc(repeat(_, %length(&special_chars.)));

	data &dsout. (keep=Node Parent);
		/* 	Define a sufficient length for Node and Parent.
		ToDo: Refine length in post processing. */
		length Node Parent last_valid_parent_value $100;
		set &dsin.;

		/* 	Create an array containing all level columns.
		WARNING: 'Level:' takes ALL variables that begin with 'Level'.
		Ensure that no other variables (e.g., 'LevelTotal') follow this pattern.
		An explicit list or range is safer if known:
		array level_cols[*] Level1 Level2 Level3 Level4 Level5; */
		array level_cols[*] Level:;

		/* Variable for the value of the last valid parent in the level hierarchy */
		last_valid_parent_value='';

		/* ----- Create level-to-level relationships ----- */
		/* Iterates through the level columns pairwise: (Level1, Level2), (Level2, Level3), etc. */
		do i=1 to dim(level_cols) - 1;

			/* Check if the current and next level are not missing */
			if not missing(level_cols[i]) and not missing(level_cols[i+1]) then do;
				Parent=level_cols[i];
				Node=level_cols[i+1];
				output;

				/* 	Write the parent-child relationship
				Remember the value of this node as a potential parent for the leaf */
				last_valid_parent_value=Node;
			end;

			/* 	If the current level exists but the next one is missing,
			then the current level is the last parent in the level list. */
			else if not missing(level_cols[i]) and missing(level_cols[i+1]) then do;
				last_valid_parent_value=level_cols[i];
				leave;

				/* Break the loop, lower levels are irrelevant */
			end;

			/* If the current level is already missing, no further relationships can follow */
			else if missing(level_cols[i]) then do;

				/* If i=1 and Level1 is missing, there is no parent from the levels */
				if i=1 then last_valid_parent_value='';
				leave;
			end;
		end;

		/* 	Handle special case: When there is only ONE level column in the array
		The above loop never ran. If this column isn't missing, it is the parent for the leaf. */
		if dim(level_cols)=1 and not missing(level_cols[1]) then do;
			last_valid_parent_value=level_cols[1];
		end;

		/* 	----- Create leaf relationship -----
		Check if a leaf name exists AND we have found a parent from the levels */
		if not missing(&LeafName.) and last_valid_parent_value ne '' then do;
			Parent=last_valid_parent_value;
			Node=&LeafName.;
			output;

			/* Write the relationship last level -> leaf */
		end;

		/* Clean up for the next iteration (although SAS does this automatically) */
		/* call missing(Node, Parent, last_valid_parent_value); */
	run;

	/* Optional: Rename nodes that they can be used as keys of column names in SAS. */
	%if &keys.=YES %then %do;
		%put Eliminating special characters from node names.;
		data &dsout.;
			set &dsout.;
			node	= translate(strip(node), "&replace_chars.", "&special_chars.");
			parent	= translate(strip(parent), "&replace_chars.", "&special_chars.");
		run;
	%end;

	* --- Optional: Remove duplicates (if desired) --- *;
	%if &duplicates.=NO %then %do;
		%put Filtering duplicate edges!;

		proc sort data=&dsout. nodupkey;
			by Node Parent;
		run;
	%end;

	proc print data=&dsout. noobs;
		title 'Transformed hierarchy (node, parent) - variable depth';
	run;

%mend;

/* MISSOVER is important for missing values ​​at the end of the line */
/*
data have;
infile datalines delimiter=',' missover;
informat Level1-Level5 $30. LeafName $30.;
input Level1 $ Level2 $ Level3 $ Level4 $ Level5 $ LeafName $;
datalines;
World,Europe,Germany,Baden-Württemberg,,Stuttgart
World,Europe,Germany,Bavaria,,Munich
World,Europe,France,,,Paris
World,North America,USA,California,,Los Angeles
World,North America,USA,New York,,New York City
World,Asia,,,,Tokyo
World,Australia,,,Sydney,
World,,,,,,
;
run;

%create_node_parent_list(dsin=have, dsout=want, LeafName=LeafName, duplicates=NO, keys=YES);
*/