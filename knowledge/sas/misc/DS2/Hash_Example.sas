data esp.in;
	set esp.abt(/*obs=20000*/ rename=(id_ip_flug=rls_id_ip_flug t=rls_t ip_att=ffl_ip_att));
run;

proc delete data=esp.out;
run;

proc ds2;

	data esp.out;
		dcl double 	_t;
		dcl double  _distrwy;
		dcl double  new_distrwy;
		dcl double 	_velocity_avg;
		dcl char(3)	_approach;
		dcl double 	position;
		dcl double 	rc1;
		dcl package hash h1([rls_id_ip_flug ],[_t _distrwy _velocity_avg _approach]);
		retain h1;
		dcl package hiter h1_it('h1');

		method run();
			set esp.in;

			position = 0;

			if _flags eq 4 then
				do;
					/* ignore rentention deletes in case some are received*/
					return;
				end;

			/* 	Checking if plane is landed or distrwy not computed or not fixed approach.
				The later two are essentially the same*/
			if (to_double(rls_t) > to_double(ffl_ip_att)) or (missing(rls_t)) or (missing(ffl_ip_att)) or (missing(distrwy)) or (missing(approach)) then
				do;
					if (to_double(rls_t) > to_double(ffl_ip_att)) then
						do;
							/*plane is landed so deleting occurence from hash */
							rc1 = h1.find();

							if rc1 eq 0 then
								do;
									h1.remove();
								end;
						end;
				end;
			else
				do;
					/* if not landed yet then processing the position  */
					rc1 = h1.find();

					if rc1 eq 0 then
						do;
							/* rls_id_ip_flug is existing into the Hash*/
							/*First update the distance in the hash table. */
							_t = to_double(rls_t);
							_distrwy = distrwy;
							_velocity_avg = velocity_avg;
							_approach = approach;
							h1.replace();
						 /* put 'Replace id_ip_flug:' rls_id_ip_flug ' distrwy:'  distrwy ' velocity_avg:'  velocity_avg '  t:' rls_t ' approach:' approach;*/
						end;
					else
						do;
							/* rls_id_ip_flug does not exist into the Hash so creating it*/
							_t = to_double(rls_t);
							_distrwy = distrwy;
							_velocity_avg = velocity_avg;
							_approach = approach;
							h1.add();
						/*	put 'Add  id_ip_flug:' rls_id_ip_flug ' distrwy:'  distrwy ' velocity_avg:'  velocity_avg '  t:' rls_t ' approach:' approach;*/
						end;

					/* then scanning the hash to get the position and updating position*/
					h1_it.first();

					/* Extrapolate flight distance since last flight observation */
					new_distrwy = _distrwy - _velocity_avg * (to_double(rls_t) - _t);
					/*put 'First id_ip_flug:' rls_id_ip_flug ' new_distrwy:' new_distrwy ' _distrwy:' _distrwy ' _velocity_avg:' _velocity_avg ' _t:' _t;
					put 'First                                 distrwy:'  distrwy '  velocity_avg:'  velocity_avg '  t:' rls_t ' approach:' approach;
*/
					if (new_distrwy < distrwy) and (_approach = approach) then
						do;
							position = position + 1;
						end;

					/*i = 1;*/

					do while (h1_it.next() = 0);
						new_distrwy = _distrwy - _velocity_avg * (to_double(rls_t) - _t);
/*						put 'Loop : ' i ' id_ip_flug:' rls_id_ip_flug ' new_distrwy:' new_distrwy ' _distrwy:' _distrwy ' _velocity_avg:' _velocity_avg ' _t:' _t;
						put 'First                                    distrwy:'  distrwy '  velocity_avg:'  velocity_avg '  t:' rls_t ' approach:' approach;
*/						if (new_distrwy < distrwy) and (_approach = approach) then
							do;
								position = position + 1;
							end;

						/*i = i+1;*/
					end;
				end; /*end of 'is landed' test*/
		end;

	enddata;
run;

quit;