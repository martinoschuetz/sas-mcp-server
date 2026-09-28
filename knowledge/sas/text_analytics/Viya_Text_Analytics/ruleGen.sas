cas sascas1 host="centis" port=5570;
libname sascas1 cas sessref=sascas1 datalimit=all;

options noquotelenmax;

/* Creating Input Data - 50 Observations */
data sascas1.drugs_anatomy;
   infile datalines delimiter='|' missover;
   length drug $50 anatomy $50 sentence $500 tag $50 tag2 $50;
   input id drug$ anatomy$ sentence$ _startOffset_ _endOffset_ _startOffset2_ _endOffset2_ tag$ tag2$;
   datalines;
      1 | Exenatide | gastric emptying | # Exenatide helps slow down gastric emptying and thus decreases the rate at which meal-derived glucose appears in the bloodstream. | 2 | 10 | 28 | 43 | DRUG1 | ANATOMY1
      2 | Talampanel | central nervous system | Talampanel acts as a non-competitive antagonist of the AMPA receptor, a type of glutamate receptor in the central nervous system. | 0 | 9 | 106 | 127 | DRUG1 | ANATOMY1
      3 | Trihexyphenidyl | gastrointestinal tract | Trihexyphenidyl is rapidly absorbed from the gastrointestinal tract. | 0 | 14 | 45 | 66 | DRUG1 | ANATOMY1
      4 | Sodium hyaluronate | knee | Sodium hyaluronate hyaluronan started to be in use to treat osteoarthritis of the knee in year 1986 with the product Hyalart/Hyalgan by Fidia of Italy, in intra-articular injections. | 0 | 17 | 82 | 85 | DRUG1 | ANATOMY1
      5 | Sodium hyaluronate | knee | Sodium hyaluronate for intra-articular injection is used to treat knee pain in patients with osteoarthritis who have not received relief from other treatments. | 0 | 17 | 66 | 69 | DRUG1 | ANATOMY1
      6 | Sodium hyaluronate | joint | Sodium hyaluronate is an ophthalmic agent with viscoelastic properties that is used in joints to supplement synovial fluid. | 0 | 17 | 87 | 91 | DRUG1 | ANATOMY1
      7 | Sodium hyaluronate | extracellular matrix | Sodium hyaluronate is a polysaccharide which is distributed widely in the extracellular matrix of connective tissue in man. | 0 | 17 | 74 | 93 | DRUG1 | ANATOMY1
      8 | Sodium hyaluronate | synovial fluid | Sodium hyaluronate is an ophthalmic agent with viscoelastic properties that is used in joints to supplement synovial fluid. | 0 | 17 | 108 | 121 | DRUG1 | ANATOMY1
      9 | Simethicone | stomach | Simethicone is an anti-foaming agent that decreases the surface tension of gas bubbles, causing them to combine into larger bubbles in the stomach that can be passed more easily. | 0 | 10 | 139 | 145 | DRUG1 | ANATOMY1
      10 | Ditazole | platelet | Ditazole is a platelet aggregation inhibitor. | 0 | 7 | 14 | 21 | DRUG1 | ANATOMY1
      11 | naltrexone | central nervous system | Individually, bupropion and naltrexone each target pathways in the central nervous system that influence food intake. | 28 | 37 | 67 | 88 | DRUG1 | ANATOMY1
      12 | Pancreatin | pancreas | Pancreatin is a mixture of several digestive enzymes produced by the exocrine cells of the pancreas. | 0 | 9 | 91 | 98 | DRUG1 | ANATOMY1
      13 | Esmolol | sympathetic nervous system | Esmolol decreases the force and rate of heart contractions by blocking beta-adrenergic receptors of the sympathetic nervous system, which are found in the heart and other organs of the body. | 0 | 6 | 104 | 129 | DRUG1 | ANATOMY1
      14 | Esmolol | heart | Esmolol decreases the force and rate of heart contractions by blocking beta-adrenergic receptors of the sympathetic nervous system, which are found in the heart and other organs of the body. | 0 | 6 | 40 | 44 | DRUG1 | ANATOMY1
      15 | Isradipine | heart | 2. Onmel/Sporanox (Itraconazole) exhibits a negative inotropic effect on the heart and thus could spur an additive effect when used concomitantly with Isradipine. | 151 | 160 | 77 | 81 | DRUG1 | ANATOMY1
      16 | Phenazopyridine | urinary tract | Phenazopyridine is prescribed for its local analgesic effects on the urinary tract. | 0 | 14 | 69 | 81 | DRUG1 | ANATOMY1
      17 | Glaucine | smooth muscle | Glaucine binds to the benzothiazepine site on L-type Ca2+-channels, thereby blocking calcium ion channels in smooth muscle like the human bronchus. | 0 | 7 | 109 | 121 | DRUG1 | ANATOMY1
      18 | Glaucine | bronchus | Glaucine binds to the benzothiazepine site on L-type Ca2+-channels, thereby blocking calcium ion channels in smooth muscle like the human bronchus. | 0 | 7 | 138 | 145 | DRUG1 | ANATOMY1
      19 | Alfatradiol | scalp | Alfatradiol is used in form of an ethanolic solution for topical application on the scalp. | 0 | 10 | 84 | 88 | DRUG1 | ANATOMY1
      20 | Probenecid | kidney | Probenecid is also useful in the treatment of gout where the mechanism of action is believed to be focused on the kidney. | 0 | 9 | 114 | 119 | DRUG1 | ANATOMY1
      21 | Probenecid | kidney | Probenecid interferes with the kidneys' organic anion transporter (OAT), which reclaims uric acid from the urine and returns it to the plasma. | 0 | 9 | 31 | 36 | DRUG1 | ANATOMY1
      22 | Norepinephrine | adrenal medulla | Norepinephrine is synthesized by a series of enzymatic steps in the adrenal medulla and postganglionic neurons of the sympathetic nervous system from the amino acid tyrosine. | 0 | 13 | 68 | 82 | DRUG1 | ANATOMY1
      23 | Norepinephrine | synaptic vesicle | Norepinephrine is synthesized from tyrosine as a precursor, and packed into synaptic vesicles. | 0 | 13 | 76 | 91 | DRUG1 | ANATOMY1
      24 | Norepinephrine | synaptic vesicles | Norepinephrine is synthesized from tyrosine as a precursor, and packed into synaptic vesicles. | 0 | 13 | 76 | 92 | DRUG1 | ANATOMY1
      25 | Norepinephrine | sympathetic nervous system | Norepinephrine is synthesized by a series of enzymatic steps in the adrenal medulla and postganglionic neurons of the sympathetic nervous system from the amino acid tyrosine. | 0 | 13 | 118 | 143 | DRUG1 | ANATOMY1
      26 | Norepinephrine | sympathetic nervous system | Norepinephrine is also released from postganglionic neurons of the sympathetic nervous system, to transmit the fight-or-flight response in each tissue, respectively. | 0 | 13 | 67 | 92 | DRUG1 | ANATOMY1
      27 | Norepinephrine | chromaffin cells | Norepinephrine is synthesized from dopamine by dopamine ?-hydroxylase in the secretory granules of the medullary chromaffin cells. | 0 | 13 | 113 | 128 | DRUG1 | ANATOMY1
      28 | Dexamethasone | myocardium | Dexamethasone is used in transvenous screw-in cardiac pacing leads to minimize the inflammatory response of the myocardium. | 0 | 12 | 112 | 121 | DRUG1 | ANATOMY1
      29 | Exenatide | pancreas | # Exenatide augments pancreas response (i.e. | 2 | 10 | 21 | 28 | DRUG1 | ANATOMY1
      30 | Mometasone furoate | skin | Mometasone furoate is a glucocorticosteroid used topically to reduce inflammation of the skin or in the airways. | 0 | 17 | 89 | 92 | DRUG1 | ANATOMY1
      31 | Mometasone furoate | airway | Mometasone furoate is a glucocorticosteroid used topically to reduce inflammation of the skin or in the airways. | 0 | 17 | 104 | 109 | DRUG1 | ANATOMY1
      32 | Naloxone | central nervous system | Naloxone has an extremely high affinity for ?-opioid receptors in the central nervous system (CNS). | 0 | 7 | 70 | 91 | DRUG1 | ANATOMY1
      33 | Gadoversetamide | liver | Gadoversetamide is a gadolinium-based MRI contrast agent, particularly for imaging of the brain, spine and liver. | 0 | 14 | 107 | 111 | DRUG1 | ANATOMY1
      34 | Atorvastatin | hepatic | Atorvastatin is primarily eliminated via hepatic biliary excretion, with less than 2% recovered in the urine. | 0 | 11 | 41 | 47 | DRUG1 | ANATOMY1
      35 | Atorvastatin | biliary | Atorvastatin is primarily eliminated via hepatic biliary excretion, with less than 2% recovered in the urine. | 0 | 11 | 49 | 55 | DRUG1 | ANATOMY1
      36 | Methylergometrine | uterus | Methylergometrine is a smooth muscle constrictor that mostly acts on the uterus. | 0 | 16 | 73 | 78 | DRUG1 | ANATOMY1
      37 | Defibrotide | mucosa | Defibrotide (Defitelio, Gentium) is a deoxyribonucleic acid derivative (single-stranded) derived from cow lung or porcine mucosa. | 0 | 10 | 122 | 127 | DRUG1 | ANATOMY1
      38 | Granulocyte macrophage colony-stimulating factor | CFU-GM | * CFU-GM * Granulocyte macrophage colony-stimulating factor receptor | 11 | 58 | 2 | 7 | DRUG1 | ANATOMY1
      39 | Granulocyte macrophage colony-stimulating factor | macrophage | * CFU-GM * Granulocyte macrophage colony-stimulating factor receptor | 11 | 58 | 23 | 32 | DRUG1 | ANATOMY1
      40 | Buprenorphine | liver | Buprenorphine is metabolised by the liver, via CYP3A4 (also CYP2C8 seems to be involved) isozymes of the cytochrome P450 enzyme system, into norbuprenorphine (by N-dealkylation). | 0 | 12 | 36 | 40 | DRUG1 | ANATOMY1
      41 | Urokinase | extracellular matrix | Urokinase was originally isolated from human urine, but is present in several physiological locations, such as blood stream and the extracellular matrix. | 0 | 8 | 132 | 151 | DRUG1 | ANATOMY1
      42 | Premarin | blood | Estrone sulfate is easily absorbed into the blood after Premarin pills are taken by women. | 56 | 63 | 44 | 48 | DRUG1 | ANATOMY1
      43 | Methyldopa | gastrointestinal tract | Methyldopa exhibits variable absorption from the gastrointestinal tract. | 0 | 9 | 49 | 70 | DRUG1 | ANATOMY1
      44 | Lipiodol | lymphatic system | Lipiodol is also used in lymphangiography, the imaging of the lymphatic system. | 0 | 7 | 62 | 77 | DRUG1 | ANATOMY1
      45 | Heparin | vasculature | Heparin is usually stored within the secretory granules of mast cells and released only into the vasculature at sites of tissue injury. | 0 | 6 | 97 | 107 | DRUG1 | ANATOMY1
      46 | Heparin | mast cell | thumblA vial of heparin sodium for injection Heparin is a naturally occurring anticoagulant produced by basophils and mast cells. | 16 | 22 | 118 | 126 | DRUG1 | ANATOMY1
      47 | Heparin | mast cell | Heparin is usually stored within the secretory granules of mast cells and released only into the vasculature at sites of tissue injury. | 0 | 6 | 59 | 67 | DRUG1 | ANATOMY1
      48 | Heparin | basophil | thumblA vial of heparin sodium for injection Heparin is a naturally occurring anticoagulant produced by basophils and mast cells. | 16 | 22 | 104 | 111 | DRUG1 | ANATOMY1
      49 | Heparin | macrophage | Heparin binding to macrophage cells is internalized and depolymerized by the macrophages. | 0 | 6 | 19 | 28 | DRUG1 | ANATOMY1
      50 | Heparin | mast cells | thumblA vial of heparin sodium for injection Heparin is a naturally occurring anticoagulant produced by basophils and mast cells. | 16 | 22 | 118 | 127 | DRUG1 | ANATOMY1
   run;
quit;

/* Viewing Input Data */
title 'Input Data for ruleGen Action';
proc print data=sascas1.drugs_anatomy; run;
title;

/* ruleGen with 50 input documents, only concept rules requested */
proc cas;
   session sascas1;
   loadactionset "textRuleDevelop";
   action ruleGen;
      param
         table={name="drugs_anatomy"}
         casOut={name="conceptRules", replace=TRUE}
         docId="id"
         text="sentence"
         conceptStartPos="_startOffset_"
         conceptEndPos="_endOffset_"
         conceptColumnName="tag"
         seed=265
      ;
   run;
quit;

/* Viewing the Generated Concept Rules */
title 'Concept Rules Returned from ruleGen Action';
proc print data=sascas1.conceptRules; run;
title;

/* ruleGen with 50 input documents, fact rules requested */
proc cas;
   session sascas1;
   loadactionset "textRuleDevelop";
   action ruleGen;
      param
         table={name="drugs_anatomy"}
         casOut={name="factRules", replace=TRUE}
         docId="id"
         text="sentence"
         conceptStartPos="_startOffset_"
         conceptEndPos="_endOffset_"
                 factStartPos="_startOffset2_"
                 factEndPos="_endOffset2_"
         conceptColumnName="tag"
                 factColumnName="tag2"
         seed=265
         ;
   run;
quit;

/* Viewing the Generated Fact Rules */
title 'Fact Rules Returned from ruleGen Action';
proc print data=sascas1.factRules; run;
title;
