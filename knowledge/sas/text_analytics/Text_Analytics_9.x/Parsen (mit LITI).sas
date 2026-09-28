/* Nur Tweets deutscher User (*/
proc tgparse
	data=DATA.tm_abt
	language='German'
	entities=yes
	stemming=no
	tagging=yes
	verbose
	ng=std
	key=data.terme
	out=data.doc_terme addterm addtag addparent addoffset;
	var text;

	*select 	"ID_NR_UNBEK" "ID_NR_EM" / keep;
	*LITILIST=('/data/Text_Analyse/CONCAT/20121211_STEUER_ID.li');
run;