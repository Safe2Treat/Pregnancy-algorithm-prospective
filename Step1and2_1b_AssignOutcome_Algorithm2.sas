/******************************************************************************

Program: chase_Step1b_AssignOutcome_Algorithm1.sas

Programmer: Sharon 

Purpose: Assigns pregnancy outcomes to pregnancy outcome groups using the 
proposed methodology in Algorithm 1.

Modifications:
	- 04-29-24: Chase (CDL) added comments throughout and modified appearance.
		Suggested changes to how we are collecting the codetype information 
		for outcome1.
	- 05.2024 - CDL conducted QC. SPH and CDL discussed. All modifications were
		reviewed and agreed upon by both.

*******************************************************************************/




data &NewDsn._Alg2 ; *outcome solely based on hierarchy;
set &concdsn (in=a)
     &discdsn (in=b);

 *summarize approach: ;
 * For concordant groups just use outcome from concordant datastep;
 * But if discordant assign based on stepwise approach: ;
 *  if an outcome in group is defined by procedure then assign that outcome based on the priority of 1b.3 hier#2;
 *  if no outcome defined by proc but defined by diagnosis then assign that outcome again using same hier#2;
 *  if no outcome defined by proc or diag then using Rx again by hier#2;

	 /*Create discordance flag*/
	 *if a then discordant2=0;
	 Discordant2 = b;

	 *check for presence of each code type (alg2 hierarchy 1);
	 if put(delivery,$outcd.) = 'PR' or put(abortion,$outcd.)='PR' or put(ectopic,$outcd.)='PR'
	    	then Hier2_1 = 'PR'; 
	   	else if put(delivery,$outcd.) = 'DX' or put(abortion,$outcd.)='DX' or put(ectopic,$outcd.)='DX'
	    	then Hier2_1 = 'DX' ;
	   	else Hier2_1 = 'RX';

	 *using hierarchy order same as in Alg 1 (step 1b.3 was3b.3);
	 array hier(*) LBM LBS MLS SB UDL SAB IAB UAB EM AEM; *labeled as hierarchy2 in 1b.3;

	 OutAssgn_pt1='unk'; *Initiate variable;
	 if concordant then OutAssgn_pt1=outcome_concordant;
	 else do;

	 	*First assigned highest level procedure code - this is what will be assigned
	 	even if there is more than 1 procedure code;
	     if hier2_1 = 'PR' then do i=1 to 10 until (OutAssgn_pt1 ne 'unk');
	       if hier(i) in ( '010','011' ,'110', '111' '012','112', '013','113' ) then do; 
	         OutAssgn_pt1 = vname(hier(i)); *3b.2;
	       end;
	     end;

		 *If no procedure, then assigned the highest level dx code - this is what
		 will be assigned even if there is more than 1 dx code;
	     else if Hier2_1='DX' then do i=1 to 10 until (OutAssgn_pt1 ne 'unk');
	       if hier(i) in ('100','110','101','111' '102','112', '103','113') then do; 
	         OutAssgn_pt1 = vname(hier(i));
	       end;
	     end;

		 *If they only have RXs left, then it should be a UAB.;
	     else if Hier2_1='RX' then OutAssgn_pt1 = 'UAB';
	 end;


	 *Data cleaning steps 1b.3-1b.4;
	 *Concordant pregnancy outcomes assigned their concordant pregnancy outcome;
	 if concordant = 1 then OutAssgn_pt2=OutAssgn_pt1;

	 *If you have a delivery outcome but concordant codes once you limit
	 to deliveries, then implement concordance with the delivery outcomes;
	 *Delivery codes would inherently be concordant;
		 else if OutAssgn_pt1 in ('LBM','LBS','MLS','SB','UDL') then do;
		         if lbm NE ('000') and SB='000' And LBS='000' and MLS='000' 
		         then do; OutAssgn_pt2='LBM';end;  
		    		else if lbs NE ('000')  And SB='000' And LBM='000' and MLS='000' 
		        		then do; OutAssgn_pt2='LBS';end;
		    		else if mls NE ('000')  And SB='000' And LBM='000' and LBS='000'
		        		 then do; OutAssgn_pt2='MLS';end;
				    else if sb NE ('000')  And MLS='000' And LBM='000' and LBS='000' 
				        then do; OutAssgn_pt2='SB';end;
				    else OutAssgn_pt2='UDL'; *mix of single, multi, mixed OR just UDL;
		 end;

		 *Step 1b.5 - if abortion again use table 1 for concordant outcomes ignoring AEM/EM  ;
		 else if OutAssgn_pt1 in ('SAB' 'IAB' 'UAB') then do; *follow 3b. table 1;
		    if sab NE ('000') And IAB='000' then OutAssgn_pt2='SAB'; *3b.5.1;
		    	else if iab NE ('000') And SAB='000' then OutAssgn_pt2='IAB';
		    	else if SAB='000' And IAB='000' then OutAssgn_pt2='UAB';  
		    	else if SAB NE ('000') and IAB NE ('000') then OutAssgn_pt2='UAB'; *3b.5.2 discordant;
		 end;

		 else OutAssgn_pt2 = OutAssgn_pt1; 

	 *step 6 - outcome code type added here for assigned2_clean (already done for assigned2 above);
	 Outcome_Assigned2 = outAssgn_pt2;

	 *Return the code types concordant with the pregnancy outcome class of the final pregnancy outcome;
	 IF Outcome_Assigned2 in ('LBM' 'LBS' 'UDL' 'SB' 'MLS') then Outcome_Assigned_Codetype2= Delivery;
	      ELSE IF Outcome_Assigned2 in ('SAB' 'IAB' 'UAB') then Outcome_Assigned_Codetype2= Abortion;
	      ELSE IF Outcome_Assigned2 in ('EM' 'AEM') then Outcome_Assigned_Codetype2= Ectopic;

	  Outcome_Class_Assigned2 = put(outcome_assigned2,$outclass.);*09.07;

	  drop i;
	  label
	   outcome_assigned2 = "Outcome Assigned (Algorithm2)"
	   outcome_assigned_codetype2="Outcome codetype (100=dx, 010=pr, 001=miso, 002=mife, 003=miso+mife)"
	   discordant2 = "Discordant outcome (algorithm2)"
	   outcome_class_assigned2="Class of outcome (deliv/abort/ectopic)"
	  ;

run;   

*Confirmed that we have the correct number of rows for encgap=30: 151,991.; 

*Check - Originally, data step was not assigning concordant outcomes explicitly and they were going through data cleaning
Revealed bug in concordant code. That bug is fixed and concordant outcome retained here.;
/*proc sql;*/
/*	select sum(Outcome_Assigned2=outcome_concordant) as eq_concordant, count(*) as n_concordant*/
/*	from outcomegroups_30_alg2*/
/*	where concordant=1*/
/*	;*/
/*	quit;*/
	*Same! - concordant bug fixed.;

/*proc sql;*/
/*	select sum(Mifepristone = 1 and misoprostol = 1 and */
/*		Outcome_Class_Assigned2 = "Abortion" and Outcome_Assigned_Codetype2 not in ('003','103','013','113')) as n_meds_wrong,*/
/*		sum(Mifepristone = 1 and misoprostol = 1 and Outcome_Class_Assigned2 = "Abortion") as meds_count,*/
/*		sum(Outcome_Class_Assigned2 = "Abortion" and Outcome_Assigned_Codetype2 in ('003','103','013','113')) as abortion_count*/
/*	from outcomegroups_30_alg2;*/
/*quit;	*/




/*/*Output some descriptives of the dataset*/*/
/**/
/*ods rtf file = "&outpath.\Step1b_ReviewAlgorithm2_&Newdsn._%sysfunc(date(),yymmddn8.).rtf" style=minimal;*/
/**/
/*        title1 "Step 1b - Algorithm 2 outcomes" ;*/
/*        proc freq data= &newdsn._alg2 ;*/
/*         table concordant discordant2 OutAssgn_pt1 * OutAssgn_pt2 *outcome_assigned2 /list missing;*/
/*        run;*/
/**/
/**/
/*        title3 ' review discordant';*/
/*        proc sql;*/
/*         	select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned2,Outcome_Assigned_Codetype2, count(*)*/
/*         	from &newdsn._Alg2 where discordant2 And OutAssgn_pt2 in ('LBM', 'LBS', 'MLS', 'SB', 'UDL')*/
/*          	group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned2,Outcome_Assigned_Codetype2 ;*/
/**/
/*         	select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned2,Outcome_Assigned_Codetype2, count(*)*/
/*         	from &newdsn._Alg2 where discordant2 And OutAssgn_pt2 in ('SAB','IAB','UAB')*/
/*          	group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned2 ,Outcome_Assigned_Codetype2;*/
/**/
/*         	select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned2,Outcome_Assigned_Codetype2, count(*)*/
/*         	from &newdsn._Alg2 where discordant2 And OutAssgn_pt2 in ('EM','AEM')*/
/*          	group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, outcome_assigned2 ,Outcome_Assigned_Codetype2;*/
/**/
/*			quit;*/
/**/
/*        proc sql;*/
/*         	select LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, OutAssgn_pt1, OutAssgn_pt2, count(*)*/
/*         	from &newdsn._Alg2 where discordant2 And AEM ne '000'*/
/*          	group by LBM, LBS, MLS, SB, UDL, SAB, IAB, UAB, EM, AEM, OutAssgn_pt1, OutAssgn_pt2;*/
/*        	quit;*/
/**/
/*ods rtf close;*/
