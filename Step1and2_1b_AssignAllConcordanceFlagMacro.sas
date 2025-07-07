/******************************************************************************

Program: chase_Step1b_AssignAllConcordanceFlagMacro.sas

Programmer: Sharon 

Purpose: This program contains necessary macros for identifying concordant 
pregnancy outcomes per the definitions in Table 1.

Modifications:
	- 04-29-24: CDL made comments and applied standardized set up.
	- 05.2024: CDL conducted QC and reviewed with SPH. All modifications were
		reveiwed and agreed upon by both.

*******************************************************************************/







/*****************************************************************************

TABLE OF CONTENTS:

	- 00 - CREATE MACRO TO IDENTIFY CONCORDANT OUTCOMES PER TABLE 1
	- 01 - SPLITCONCORDANT MACRO

******************************************************************************/













/*****************************************************************************

		00 - CREATE MACRO TO IDENTIFY CONCORDANT OUTCOMES PER TABLE 1

Table 1 concordance with step to assign codetype for the concordant pair

******************************************************************************/

*NOTE: We do not use medication information to identify concordant outcomes.
Only UABs should be identified by only the presence of a med;

**
INPUTS:
 - o1 -- The first outcome to compare. This will be the final outcome
	if the pairing is concordant.
 - o2 -- The second outcome to compare. This one will be over-written if
	concordant.
;

*Ignoring medication orders for concordance so using outcomecounts excl Rx;
%macro conctbl(o1,o2); *table 1 concordance when 2 outcome groups or 3 if 3rd is UAB-001;

	if (outcomegroup_OutcomesNORX_N = 2 
		and &o1 ne '000' 
		and &o2 ne '000' 
   		%IF &o2 = UAB %then %do; And UAB not in  ('001' '002' '003') %END;)
    then do;
      	Concordant=1; 
		Outcome_Concordant=upcase("&o1"); 
		/*CDL: Created the rx variable 11.22.2024 to deal with situations where have both across the two.*/
		if substr(&o1,3,1) = 1 and substr(&o2,3,1) = 2 then rx = 3;
			else if substr(&o1,3,1) = 2 and substr(&o2,3,1) = 1 then rx = 3;
			else rx = max(substr(&o1,3,1),substr(&o2,3,1));
      	Outcome_Concordant_CodeType = 
			cat(max(substr(&o1,1,1),substr(&o2,1,1)),max(substr(&o1,2,1),substr(&o2,2,1)), rx);
/*      	Outcome_Concordant_CodeType = */
/*        	cat(max(substr(&o1,1,1),substr(&o2,1,1)),max(substr(&o1,2,1),substr(&o2,2,1)),max(substr(&o1,3,1),substr(&o2,3,1)));*/
    end;

 %mend;













/*****************************************************************************

						 01 - SPLITCONCORDANT MACRO

******************************************************************************/


*macro to call in separate algorithm pgms to split data into outcome concordant and discordant;


***
INPUT:
- grpdsn -- Outcome group dataset that you want to split up.

OUTPUT:
- Conc_&GrpDsn. -- This dataset contains outcome groups with concordant outcomes
 	(i.e., these are now clean)
- Disc_&GrpDsn. -- This dataset contains the outcome groups that will need to 
 	be put through the algorithm to define a pregnancy outcome.
- Conc_&GrpDsn.disc -- This is a dataset with all the pregnancy outcome groups
 	after applying the concordance macro. This can be used for descriptive purposes.
- &outpath.\Step1b1_Concordance_&grpdsn._%sysfunc(date(),yymmddn8.).rtf
 	RTF file with some descriptives.
;

/*For testing
 %let grpdsn = OutcomeGroups_30;*/

%Macro SplitConcordant(grpdsn);

    data Conc_&GrpDsn. Disc_&GrpDsn.  
          Conc_&GrpDsn.disc (keep=patient_deid outcomegrp concordant delivery: abortion: ectopic: outcome_concordant: pr_n dx_n rx_n);
    set &grpdsn. ;

		/*Set the concordance flag to 0 for all pregnancy outcome groups*/
     	Concordant=0;  
     	Outcome_Concordant='not';

		/*Create an array of the outcomes to determine which ones are concordant*/
		array x2(*) LBM LBS MLS SB UDL SAB IAB EM AEM UAB; %*UAB last so that only picked when info beyond med order;
		if outcomegroup_OutcomesNORX_N in (0, 1) then do; /**1 outcome or 2 with uab=rx (0=> only outcome is Rx);*/
        	concordant=1; *only 1 outcome for group = cannot be discordant;
        	do i=1 to dim(x2) until (Outcome_Concordant ne 'not'); /*CDL: ADDED until statement 11.22.24. Was assigning SABs and IABs with UABs wrong*/
          		if x2(i) ne '000' then do;
           			Outcome_Concordant = vname(x2(i));  
/*           			Outcome_Concordant_Codetype= x2(i);*/
          		end;
        	end;
      	end;

		/*CDL: MODIFIED 11.22.2024 - Was not capturing medication orders from UABs*/
		if outcome_concordant in ('LBM','LBS','MLS','SB','UDL') then Outcome_Concordant_Codetype = Delivery;
			else if outcome_concordant in ('SAB','IAB','UAB') then Outcome_Concordant_Codetype = Abortion;
			else if outcome_concordant in ('EM','AEM') then outcome_concordant_codetype = Ectopic;

		*Macro applies if statement
		Output the concordant outcome type if the if conditions in the macro are satisfied.;
       	%conctbl(LBM, UDL)
        %ConcTbl(LBS, UDL)
        %ConcTbl(MLS, UDL)
        %ConcTbl(SB , UDL)
        %ConcTbl(SAB, UAB)
        %ConcTbl(IAB, UAB)
        %ConcTbl(EM , AEM)
        ;;;;
      
      	drop i rx;
 
      	if concordant=1 then output Conc_&GrpDsn.; /*Concordant outcome groups - these are done*/ 
			else output Disc_&GrpDsn.; /*will use for algorithms 1-4*/

		output Conc_&GrpDsn.disc; /*just for stats if needed*/

    run;
	/*For ENCGAP=30, you get 151,991 observations read in.
		Concordant dataset has 147,173
		Discordant dataset has 4,818
		Total: 151,991 -- Adds up to the number of original rows, as it should.
	Manual review of a few cases looked correct*/


/*    ods rtf file = "&outpath.\Step1b1_Concordance_&grpdsn._%sysfunc(date(),yymmddn8.).rtf" style=minimal;*/
/**/
/*        title1 "Step 1b1 - Concordant outcomes";*/
/*        proc freq data=conc_&grpdsn.disc ;*/
/*         	table concordant outcome_concordant outcome_concordant_codetype;*/
/*        run;*/
/**/
/*    ods rtf close;*/

%mend;
