title "Consumer Segment Mapping of Image"; 
   data survey1; 
      input image $ 1-19 seg1-seg4; 
      label seg1 = 'Segment 1' 
            seg2 = 'Segment 2' 
            seg3 = 'Segment 3' 
            seg4 = 'Segment 4' 
            ; 
      datalines; 
   Image Item 1        4489 4303 4402 4350 
   Image Item 2        4101 3800 3749 3572 
   Image Item 3        3354 3286 3344 3278 
   Image Item 4        2444 2587 2749 2878 
   Image Item 5        3338 3144 2959 2791 
   Image Item 6        1222 1196 1149 1003 
   ; 
 
   proc corresp data=survey1 out=Results short; 
      var seg1-seg4; 
      id image; 
   run;