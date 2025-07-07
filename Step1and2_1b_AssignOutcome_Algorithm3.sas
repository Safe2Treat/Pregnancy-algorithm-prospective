/******************************************************************************

Program: chase_Step1b_AssignOutcome_Algorithm3.sas

Programmer: Sharon (SPH)

Purpose: Assigns pregnancy outcomes to pregnancy outcome groups using the 
proposed methodology in Algorithm 3.

Modifications:
	- 04-29-24: Chase (CDL) added comments throughout and modified appearance.
		Suggested changes to how we are collecting the codetype information 
		for outcome1.
	- 05.2024: Chase conducted QC. SPH and CDL reviewed. All modifications were
		reviewed and agreed upon.

*******************************************************************************/




*First, deal with the pregnancy outcome groups with discordant outcomes.;
data &discdsn._int_Alg3 ;
set &discdsn (in=b);

	*Create discordance flag;
	 Discordant3=0; *Start with 0. All of these are discordant, so, as a check, none should have 0 in the end;

  	**summarize: ;
  	** outcomes are delivery procedures or not;
  	**  if there is a delivery procedure then check for delivery concordance using 1b table1 (ignoring non-delivery outcomes);
  	**  if no delivery procedure flag as such and stop;

	*Check: Any delivery procedure codes? If so, check for concordant combos of delivery codes;
  	length Disc_OutPot3 $8.; 

	*First, if there is a delivery procedure code present...;
  	if put(delivery,$outcdpr.) = 1 then do;*;

		**step 1b1 part 2;
	    *1 - ...and concordant delivery codes (redo table 1 check);
		if lbm NE ('000') And SB='000' And LBS='000' and MLS='000' 
	         then do; discordant3=1; Disc_OutPot3='PRD-LBM';end;
		else if lbs NE ('000') And SB='000' And LBM='000' and MLS='000' 
	         then do; discordant3=1; Disc_OutPot3='PRD-LBS';end;
		else if mls NE ('000') And SB='000' And LBM='000' and LBS='000'
	         then do; discordant3=1; Disc_OutPot3='PRD-MLS';end;
	    else if sb NE ('000') And MLS='000' And LBM='000' and LBS='000' 
	        then do; discordant3=1; Disc_OutPot3='PRD-SB';end;
		else if UDL NE ('000') and SB='000' And MLS='000' And LBM='000' and LBS='000' 
	        then do; discordant3=1; Disc_OutPot3='PRD-UDL';end;

	    *2 - ...and discordant delivery codes;
	    else do;
	      Discordant3=2; Disc_OutPot3="PRD-Dsc"; *has deliv proc but combo of outcomes discordant;
	    end;
  end;

   *3 no delivery procedure;
  else if put(delivery,$outcdpr.) = 0 then do;
    Discordant3=3;  Disc_OutPot3 = "PRD-Not";
  end;
  *PRD-LBM thru PRD_UDL are Delivery procedure, Delivery outcome concordant;
  *PRD-Dsc - Delivery procedure, Delivery outcome discordant;
  *PRD-Not - Delivery procedure not found;

run;

*Same number of rows. Manual review of a few rows looked as expected;
*Check discordant3 distribution. None should be 0;
/*proc freq data=&discdsn._int_Alg3;*/
/*	table discordant3 / missing;*/
/*run;*/
/*
Discordant3 Frequency Percent CumulativeFrequency CumulativePercent 
1 1744 36.20 1744 36.20 
2 989 20.53 2733 56.72 
3 2085 43.28 4818 100.00 
*/

*Check counts;
/*proc sql;*/
/*	select sum(delivery not in ('010','011','012','013','110','111','112','113')) as no_del_procedure*/
/*	from &discdsn;*/
/*	quit;*/
/**/
/*proc sql;*/
/*	select sum(delivery not in ('010','011','012','013','110','111','112','113')) as discordant3,	*/
/*		sum(delivery in ('010','011','012','013','110','111','112','113') and LBM ne '000' and SB = '000' and MLS = '000' and LBS = '000') as LBM_sum,*/
/*		sum(delivery in ('010','011','012','013','110','111','112','113') and LBS ne '000' and SB = '000' and MLS = '000' and LBM = '000') as LBS_sum,*/
/*		sum(delivery in ('010','011','012','013','110','111','112','113') and SB ne '000' and LBM = '000' and MLS = '000' and LBS = '000') as SB_sum,*/
/*		sum(delivery in ('010','011','012','013','110','111','112','113') and MLS ne '000' and SB = '000' and LBM = '000' and LBS = '000') as MLS_sum,*/
/*		sum(delivery in ('010','011','012','013','110','111','112','113') and UDL ne '000' and SB = '000' and LBM = '000' and LBS = '000' and MLS = '000') as UDL_sum,*/
/*		sum(calculated LBM_sum, calculated LBS_sum, calculated SB_sum, calculated MLS_sum, calculated UDL_sum) as discordant1*/
/*		from &discdsn;*/
/*		quit;*/





/*Now deal with concordant and discordant pregnancy outcome groups*/
data &NewDSn._alg3;
 set &ConcDsn (in=a) 
     &discdsn._int_alg3 (in=b);
	 format outcome_class_assigned3 $8.; /*CDL: ADDED 11.22.2024 so that the variables match across datasets*/

	length outcome_assigned3 $3. outcome_assigned_codetype3 $3. outcome_class_assigned3 $3.;

 	if a then discordant3 = 0;
		else discordant3=discordant3;

 	outassgn_pt1='unk';

 	array hier(*) SAB IAB UAB SB LBM LBS MLS UDL EM AEM ; *hierarchy used to assign outcomes when no delivery procedure codes;

	**Check for code type (proc/diag/rx) and assign outcome based on Hierarchy for algorithm hier(*);

	*Assign outcomes;
	*Concordant pregnancy outcome groups receive the concordant outcome;
 	if concordant then outassgn_pt1= outcome_concordant; *3b.2;

 	else do;

  		*step 1b.3 discordant but with concordant delivery procedure using table 1 (Disc_OutPot3= PRD-[x]);
  		if discordant3=1 then outassgn_pt1= substr(disc_outpot3,5); 

  		*step 1b.4 discordant codes, delivery pr code, but discordant delivery codes -- UDL;
  		if discordant3=2 then outassgn_pt1= 'UDL'; 

  		*step 1b.5 discordant, no delivery;
  		if discordant3=3 then do ;

     		*using hierarchy for 1b.5 - first prioritize procedure codes;
     		if pr_n>=1 then do i=1 to 10 until (outassgn_pt1 ne 'unk'); 
       			if hier(i) in ('010','011','110','111' '012','112' '013','113') then do; *Only want to grab those with procedure codes;
         			Outassgn_pt1= vname(hier(i));
       			end;
     		end;

			else if dx_n >=1 then do i=1 to 10 until (outassgn_pt1 ne 'unk');
				*CDL: MODIFIED -- None should have procedure codes at this point, so a good check that working right;
	       		*if hier(i) in ('100','110','101','111', '102','112', '103','113') then do;  
				if hier(i) in ('100','101','102','103') then do;
	         		outassgn_pt1= vname(hier(i));
	       		end;
	     	end;

	     	else if rx_n>=1 then do; *no need to loop since only uab has rx only;
	         	outassgn_pt1= 'UAB';
	     	end;
	  	end;

	 end;

  	 *now step6 - 3b.6 - discordant abortion clean up;
 	 If outassgn_pt1 in ('SAB' 'IAB' 'UAB' ) then do;
		if SAB ne ('000') and IAB ne ('000') then outassgn_pt2='UAB'; *Deal w discordant abortion outcomes first;
				else if SAB ne ('000') then outassgn_pt2='SAB'; /*CDL: MODIFIED 11.22.2024 was previously outassgn_pt2, leading to 8 rows with wrong values*/
				else if IAB ne ('000') then outassgn_pt2 = 'IAB'; /*CDL: MODIFIED 11.22.2024 was previously outassgn_pt2, leading to 8 rows with wrong values*/
		*NOTE: Some may have meds for IAB or SAB because they had concordant codes on an encounter whihc were 
				rolled up to the group level;
 	 end;

 	 *step 1b.7 assign final outcome (clean if present else 1st pass which includes concordant);
 	 If outassgn_pt2 ne '' then Outcome_Assigned3 = outassgn_pt2;
 	 	else outcome_assigned3 = outassgn_pt1;

	 *Assign code type according to the pregnancy outcome class.;
     IF Outcome_Assigned3 in ('LBM' 'LBS' 'UDL' 'SB' 'MLS') then Outcome_Assigned_Codetype3= Delivery;
      	ELSE IF Outcome_Assigned3 in ('SAB' 'IAB' 'UAB') then Outcome_Assigned_Codetype3= Abortion;
      	ELSE IF Outcome_Assigned3 in ('EM' 'AEM') then Outcome_Assigned_Codetype3= Ectopic;

	 *Get the pregnancy outcome class;
     Outcome_Class_Assigned3 = put(outcome_assigned3,$outclass.);*09.07;

	 drop i;

  	 label
   		outcome_assigned3 = "Outcome Assigned (Algorithm3)"
   		outcome_assigned_codetype3="Outcome codetype (100=dx, 010=pr, 0001=rx)"
   		discordant3 = "Discordant outcome (algorithm3)"
      	outcome_class_assigned3="Class of outcome (deliv/abort/ectopic)"
  	 ;
run;
proc format ;value onepl 1-high='1+';run;


*Row counts as expected for ENCGAP=30
	Input: 147173+4818 = 151,991
	Number of rows in final dataset: 151,991 -- Good, no new rows unexpectedly.;

*Additional checks;
/*proc sql;*/
/*	select sum(concordant = 1 and outcome_concordant ne outcome_assigned3) as num_concordant_wrong*/
/*	from &NewDSn._alg3;*/
/*	quit;*/
	*0 rows;
*Confirm no duplicate rows;
/*proc sort data=&NewDSn._alg3 out=test nodup;*/
/*	by patient_deid;*/
/*run;*/
*0 duplicates, good;
/*proc freq data=&NewDSn._alg3;*/
/*	table discordant3;*/
/*run; *Still correct;*/
*Confirm if all with delivery procedure codes are assigned as deliveries;
/*proc sql;*/
/*	select sum(discordant3 in (1,2) and outcome_class_assigned3 ne "Del") as num_wrong*/
/*	from  &NewDSn._alg3;*/
/*	quit;*/
	*0 rows, good;
*Subset to potentially weird cases;
/*data test;*/
/*set &NewDSn._alg3;*/
/*	where outcome_assigned3 ne outassign_pt2 and outassign_pt2 ne "";*/
/*run;*/
*Cross-tabs check on outcome and class;
/*proc freq data=&NewDSn._alg3;*/
/*	table outcome_assigned3*outcome_class_assigned3;*/
/*run;*/
*Everything looked at expected.;









/*Output a RTF file for easy reviewing*/

/*ods rtf file = "&outpath.\Step1b_ReviewAlgorithm3_Newds._%sysfunc(date(),yymmddn8.).rtf" style=minimal;*/
/**/
/*        title1 "Step 1b - Algorithm 3 outcomes" ;*/
/*        proc freq data= &newdsn._alg3 ;*/
/*         table concordant discordant3 OutAssgn_pt1 * OutAssgn_pt2 *outcome_assigned3 /list missing;*/
/*         format discordant3  discord3alg.;*/
/*        run;*/
/**/
/**/
/*        title3 ' review discordant';*/
/*        proc sql;*/
/*         select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned3,Outcome_Assigned_Codetype3, count(*) as cnt*/
/*         from &newdsn._Alg3 where discordant3>0 And Outcome_assigned3 in ('LBM', 'LBS', 'MLS', 'SB', 'UDL')*/
/*          group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned3,Outcome_Assigned_Codetype3 */
/*            order by calculated cnt desc;*/
/**/
/*         select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned3,Outcome_Assigned_Codetype3, count(*) as cnt*/
/*         from &newdsn._Alg3 where discordant3>0 And Outcome_assigned3 in ('SAB','IAB','UAB')*/
/*          group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned3 ,Outcome_Assigned_Codetype3 */
/*            order by calculated cnt desc;*/
/**/
/*         select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned3,Outcome_Assigned_Codetype3, count(*) as cnt*/
/*         from &newdsn._Alg3 where discordant3>0 And Outcome_assigned3 in ('EM','AEM')*/
/*          group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned3 ,Outcome_Assigned_Codetype3 */
/*            order by calculated cnt desc;*/
/*        quit;*/
/**/
/**/
/*ods rtf close;*/
