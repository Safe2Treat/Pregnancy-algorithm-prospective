/******************************************************************************

Program: chase_Step1b_AssignOutcome_Algorithm4.sas

Programmer: Sharon 

Purpose: Assigns pregnancy outcomes to pregnancy outcome groups using the 
proposed methodology in Algorithm 4.

Modifications:
	- 04-29-24: Chase (CDL) added comments throughout and modified appearance.
		Suggested changes to how we are collecting the codetype information 
		for outcome1.
	- 05.2024: CDL conducted QC. SPH and CDL reviewed. All modifications were
		agreed upon by both.

*******************************************************************************/



*algorithm4 (complex) - checkng for delivery procedure (copied alg3) then non-delivery procedure;
*set outcomes to PRD - Procedure, delivery -- PRO - Procedure, Other  ;

*First create the discordance flags and assign outcomes for some -- Subset to only those pregnancy
outcome groups with discordant pregnancy outcomes;
data &discdsn._int_Alg4 ;
set &discdsn (in=b);
	
	*Create the discordance flag and set the length of an outcome indicator;
  	Discordant4=0;
  	length Disc_OutPot4 $8.;
  
	*First, determine if there is a delivery procedure code present;
  	if put(delivery,$outcdpr.) = 1 then do; *check for concordant combos;

		**step 1b1 part 2;
	    *1 - ...and concordant delivery codes (redo table 1 check);
		if lbm NE ('000') And SB='000' And LBS='000' and MLS='000' 
	         then do; discordant4=1; Disc_OutPot4='PRD-LBM';end;
		else if lbs NE ('000') And SB='000' And LBM='000' and MLS='000' 
	         then do; discordant4=1; Disc_OutPot4='PRD-LBS';end;
		else if mls NE ('000')  And SB='000' And LBM='000' and LBS='000'
	         then do; discordant4=1; Disc_OutPot4='PRD-MLS';end;
	    else if sb NE ('000') And MLS='000' And LBM='000' and LBS='000' 
	        then do; discordant4=1; Disc_OutPot4='PRD-SB';end;
		else if UDL NE ('000') and SB In ('000') And MLS='000' And LBM='000' and LBS='000' 
	        then do; discordant4=1; Disc_OutPot4='PRD-UDL';end;

  	*2 - ...and discordant delivery codes;
   		else do;
     		Discordant4=2; Disc_OutPot4="PRD-Dsc"; *has deliv proc but combo of outcomes discordant;
   		end;

  	end;
  
  	*now for those without a delivery procedure code ;
  	Else if put(delivery,$outcdpr.) = 0 then do; *redundant line but easier to read pgm;

		*3 - ...but non-delivery (abortion/ectopic) procedures;
   		if put(abortion,$outcdpr.) = 1 Or put(ectopic,$outcdpr.) = 1 then do; *non-delivey procedures;
    		Discordant4=3;  Disc_OutPot4 = "PRO-Any";  *procedure-other--any;
   		end;

		*4 - no procedures;
   		else do; 
    		Discordant4=4; Disc_OutPot4="PRO-None"; *no procedure code for outcome group;
   		end;
  	End;

run;

/**Same number of rows input and output;*/
/*proc freq data=disc_outcomegroups_30_int_alg4;*/
/*	table discordant4;*/
/*run;*/
/**re-code myself and make sure get same numbers;*/
/*data test;*/
/*set disc_outcomegroups_30_int_alg4;*/
/*	if delivery in ('010','011','012','013','110','111','112','113') then test_discord = 1;*/
/*		else if abortion in ('010','011','012','013','110','111','112','113') or ectopic in ('010','011','012','013','110','111','112','113') then test_discord=3;*/
/*		else test_discord=4;*/
/*run;*/
/*proc freq data=test;*/
/*	table test_discord;*/
/*run;*/
*Confirm that get the same count when split up test_discord = 1;
/*data test;*/
/*set test;*/
/*	if test_discord = 1 then do;*/
/*		if (LBM ne '000' and LBS = '000' and SB = '000' and MLS = '000') or*/
/*			(LBS ne '000' and LBM = '000' and SB = '000' and MLS = '000') or*/
/*			(SB ne '000' and LBM = '000' and LBS = '000' and MLS = '000') or*/
/*			(MLS ne '000' and LBM = '000' and LBS = '000' and SB = '000') or*/
/*			(UDL ne '000' and LBM = '000' and LBS = '000' and SB = '000' and MLS = '000') then test_discord = 1;*/
/*		else test_discord = 2;*/
/*	end;*/
/*run;*/
/*proc freq data=test;*/
/*	table test_discord;*/
/*run;*/
*Same answer;

 
**steps 4-8 for algorithm 4;run;
data &NewDsn._alg4;
set &ConcDsn. (in=a) 
    &DiscDsn._int_Alg4 (in=b) ;

	*Create concordant value;
 	if a then discordant4 = 0;
		else discordant4=discordant4;

 	array hier(*) EM SAB IAB UAB AEM ; *step 1b.5 hierarchy;
 	array hier6(*) SAB IAB UAB SB LBM LBS MLS UDL EM AEM ; *hierarchy for pt2 step 1b.6 (same as alg3);

	*Assign outcomes;
 	outassgn_pt1 ='unk';

	*Concordant outcomes;
 	if discordant4 = 0 then outassgn_pt1 = outcome_concordant; 

	 	else if discordant4 ne 0 then do; 

	    	*step 1b.3 discordant but with concordant delivery procedure using table 1 (Disc_OutPot3= PRD-[x])
			-- This was determined in the step above in the last 3 characters of the value disc_outpot4;
	    	if discordant4=1 then outassgn_pt1 = substr(disc_outpot4,5); 

	    	*step 1b.4 discordant with delivery procedure but discordant delivery codes;
	    	else if discordant4=2 then outassgn_pt1 = 'UDL' ;*substr(disc_outpot4,5);

	    	*step 1b.5 discordant, no delivery procedures but procedure codes for other outcomes;
	    	else if discordant4=3 then do i=1 to 10 until (outassgn_pt1 ne 'unk');
	        	if put(hier(i),$outcd.)='PR' then outassgn_pt1 = vname(hier(i));
	    	end;

	    	*step 1b.6 discordant, other - 1st check code type (dx then rx);
			*CDL: MODIFIED 11.22.2024 to match what we did in Algorithm 3;
			if discordant4 = 4 then do;
	        	if dx_n>=1 then do i=1 to 10 until (outassgn_pt1 ne 'unk'); *1proc just use that one;
	            	if hier6(i) in ('100','101','110','111','102','112','103','113') then do;  *CDL: Added missing comma;
	                 	outassgn_pt1= vname(hier6(i));
	            	end;
				end;
	            	else if rx_n>=1 then do; 
	             		outassgn_pt1  = 'UAB';
	            	end; 
	    	end; 

	/*    	if discordant4 = 4 then do i=1 to 10 until (outassgn_pt1 ne 'unk');*/
	/**/
	/*        	if dx_n>=1 then do i=1 to 10 until (outassgn_pt1 ne 'unk'); *1proc just use that one;*/
	/**/
	/*            	if hier6(i) in ('100','101','110','111'  '102','112','103','113') then do; */
	/*                 	outassgn_pt1= vname(hier6(i));*/
	/*            	end;*/
	/**/
	/*            	else if rx_n>=1 then do; */
	/*             		outassgn_pt1  = 'UAB';*/
	/*            	end; */
	/**/
	/*        	end;*/
	/*    	end; */

		end;


  	*next step7- 1b.7 - discordant abortion clean up;
 	If outassgn_pt1  in ('SAB' 'IAB' 'UAB' ) then do; 
		if SAB ne ('000') and IAB ne ('000') then outassgn_pt2='SAB'; *Deal w discordant abortion outcomes first;
				else if SAB ne ('000') then outassgn_pt2='SAB'; *CDL: MODFIFIED 11.22.2024. Previously outassign_pt2 but led to two columns. ;
				else if IAB ne ('000') then outassgn_pt2 ='IAB';
				else outassgn_pt2='UAB'; *CDL: ADDED 11.22.2024 - Unnecessary but explicit;
		*NOTE: Some may have meds for IAB or SAB because they had concordant codes on an encounter which were 
				rolled up to the group level;
 	end;

 	*1b8 - final outcome assignment;
 	If outassgn_pt2 ne '' then Outcome_Assigned4 = outassgn_pt2;
 		else outcome_assigned4 = outassgn_pt1;

	*Assign code type according to the pregnancy outcome class.;
    IF Outcome_Assigned4 in ('LBM' 'LBS' 'UDL' 'SB' 'MLS') then Outcome_Assigned_Codetype4= Delivery;
      ELSE IF Outcome_Assigned4 in ('SAB' 'IAB' 'UAB') then Outcome_Assigned_Codetype4= Abortion;
      ELSE IF Outcome_Assigned4 in ('EM' 'AEM') then Outcome_Assigned_Codetype4= Ectopic;

      Outcome_Class_Assigned4 = put(outcome_assigned4,$outclass.);

 	drop i;
   	label
   		outcome_assigned4 = "Outcome Assigned (Algorithm4)"
   		outcome_assigned_codetype4="Outcome codetype (100=dx, 010=pr, 0001=rx)"
   		discordant4 = "Discordant outcome (algorithm4)"
   		outcome_class_assigned4="Class of outcome (deliv/abort/ectopic)"
  	;

run;

*Expected number of rows. ;

*Compare against algorithm 3. Deliveries defined by procedure codes shoudl be the same number;
/*proc freq data= outcomegroups_30_alg3;*/
/*	where Outcome_Class_Assigned3 = "Delivery" and discordant3 in (1,2);*/
/*	table Outcome_Assigned3;*/
/*run;*/
/*proc freq data= outcomegroups_30_alg4;*/
/*	where Outcome_Class_Assigned4 = "Delivery" and discordant4 in (1,2);*/
/*	table Outcome_Assigned4;*/
/*run;*/

*Should be similar distributions across the two;
/*proc freq data= outcomegroups_30_alg3;*/
/*	table Outcome_Assigned3;*/
/*run;*/
/*proc freq data= outcomegroups_30_alg4;*/
/*	table Outcome_Assigned4;*/
/*run;*/
*Only difference are in abortion outcomes and EM. In expected directions:
- EM higher in Algorithm 4
- SAB more common in Algorithm 4
- UAB less common in Algorithm 4
- Very similar IAB;







/*Output a RTF file with descriptive information*/

/*ods rtf file = "&outpath.\Step1b_ReviewAlgorithm4_&Newdsn._%sysfunc(date(),yymmddn8.).rtf" style=minimal;*/
/**/
/*        title1 "Step 1b - Algorithm 4 outcomes" ;*/
/*        proc freq data= &newdsn._alg4 ;*/
/*         table concordant discordant4 OutAssgn_pt1 * OutAssgn_pt2 *outcome_assigned4 /list missing;*/
/*         format discordant4  discord4alg.;*/
/*        run;*/
/**/
/**/
/*        title3 ' review discordant';*/
/*        proc sql;*/
/*         select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned4,Outcome_Assigned_Codetype4, count(*) as cnt*/
/*         from &newdsn._Alg4 where discordant4>0 And Outcome_assigned4 in ('LBM', 'LBS', 'MLS', 'SB', 'UDL')*/
/*          group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned4,Outcome_Assigned_Codetype4 */
/*            order by calculated cnt desc;*/
/**/
/*         select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned4,Outcome_Assigned_Codetype4, count(*) as cnt*/
/*         from &newdsn._Alg4 where discordant4>0 And Outcome_assigned4 in ('SAB','IAB','UAB')*/
/*          group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned4 ,Outcome_Assigned_Codetype4 */
/*            order by calculated cnt desc;*/
/**/
/*         select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned4,Outcome_Assigned_Codetype4, count(*) as cnt*/
/*         from &newdsn._Alg4 where discordant4>0 And Outcome_assigned4 in ('EM','AEM')*/
/*          group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned4 ,Outcome_Assigned_Codetype4 */
/*            order by calculated cnt desc;*/
/*        quit;*/
/**/
/**/
/*ods rtf close;*/
