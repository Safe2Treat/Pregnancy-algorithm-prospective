/******************************************************************************

Program: chase_step2_OutcomeDatesAssignedMacro.sas

Programmer: Sharon 

Purpose: This program creates a macro that assigned pregnancy outcome dates
to the pregnancy outcome groups (i.e., Step 2 of the cohort derivation).

Modifications:
	- 04-29-24: CDL made comments and applied standardized set up.
	- 05.2025: CDL conducted QC. SPH and CDL reviewed. All modifications were
		agreed upon by both.
    - 08.05.24: sph - turn on adjustment for alg4 abortions dt (cdl added line)
*******************************************************************************/



/*CDL: REVISED 11.24.2024 because original code was giving wrong dates for some rows.*/

%macro outdts(gap);

/*%let i=1;*/

	proc sql stimer;
		
		%do i=1 %to 4;

			/*Create a variable for how the outcome dates are assigned*/
			create table getdate0_&gap._&i. as
			select *,  case 

							   /**DELIVERY outcome dates**/

		              		   /*delivery assigned - pick encounter inpt proc [DelivPR_Inp], then any proc (conc pair), then diag-cd(pair)*/
					  		   /*If inpatient delivery w procedure code, then outcome date is the first encounter date - determined by min function*/
		                       when outcome_class_assigned&i ='Delivery' and DelivPR_Inp=1 then 1 /*"INPT-PR"*/

							   /*Grab the first concordant procedure code -- deliveries (order doesnt matter from abortions since based on outcome_assigned*/
		                       when Outcome_Assigned&i. in ("LBM") And outcome in ("LBM" "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/
		                       when Outcome_Assigned&i. in ("LBS") And outcome in ("LBS" "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/
		                       when Outcome_Assigned&i. in ("MLS") And outcome in ("MLS" "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/
		                       when Outcome_Assigned&i. in ("SB")  And outcome in ("SB" "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/
		                       when Outcome_Assigned&i. in ("UDL") And outcome in ( "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/

							   /*Prioritize non-UDL delivery pr codes over UDL dx codes*/
							   /*NOTE: Some UDLs dont have any UDL pr codes because they had discordant delivery codes. Deal with that here.
		                       If assigned outcome is UDL then pick earliest delivery proc code in outcome group*/
		                       when Outcome_Assigned&i. in ("UDL") And put(outcome,$outclass.)='Delivery' and put(dxprrx ,$outcdpr.)='1' then 3 /*UDL-PR*/
		                      
							   /*For those deliveries not yet assigned, output the date of the first concordant delivery diagnosis code.*/
		                       when Outcome_Assigned&i. in ("LBM") And outcome in ("LBM" "UDL") and put(dxprrx ,$outcddx.)='1' then 4 /*"DEL-DX"*/
		                       when Outcome_Assigned&i. in ("LBS") And outcome in ("LBS" "UDL") and put(dxprrx ,$outcddx.)='1' then 4 /*"DEL-DX"*/
		                       when Outcome_Assigned&i. in ("MLS") And outcome in ("MLS" "UDL") and put(dxprrx ,$outcddx.)='1' then 4 /*"DEL-DX"*/
		                       when Outcome_Assigned&i. in ("SB") And outcome in ("SB" "UDL") and put(dxprrx ,$outcddx.)='1' then 4 /*"DEL-DX"*/
		                       when Outcome_Assigned&i. in ("UDL") And outcome in ( "UDL") and put(dxprrx ,$outcddx.)='1' then 4 /*"DEL-DX"*/

							   /*NOTE: Some UDLs dont have any UDL dx codes because they had discordant delivery codes. Deal with that here.
		                       If assigned outcome is UDL then pick earliest delivery dx code in outcome group*/
		                       when Outcome_Assigned&i. in ("UDL") And put(outcome,$outclass.)='Delivery' and put(dxprrx ,$outcddx.)='1' then 5 /*"UDL-DX"*/


							   /**ABORTION outcome dates**/
		              		   /*abortion assigned - pic encounter any [conc] proc, mife/miso, diag*/

							   /*proc codes*/
		                       when Outcome_Assigned&i. in ("SAB") And outcome in ("SAB" "UAB") and put(dxprrx ,$outcdpr.)='1' then 6 /*"AB-PR"*/
		                       when Outcome_Assigned&i. in ("IAB") And outcome in ("IAB" "UAB") and put(dxprrx ,$outcdpr.)='1' then 6 /*"AB-PR"*/
		                       when Outcome_Assigned&i. in ("UAB") And outcome in ("UAB") and put(dxprrx ,$outcdpr.)='1' then 6 /*"AB-PR"*/

							   /*NOTE: Some UABs dont have UAB procedure codes but may have procedure codes for a SAB or IAB. We deal with those 
							   UABs here. If a UAB doesnt have concordant proc codes, then first abortion proc code*/
							   when Outcome_Assigned&i. in ("UAB") And put(outcome,$outclass.)='Abortion' and put(dxprrx ,$outcdpr.)='1' then 7 /*"UAB-PR"*/

							   /*CDL: ADDED for logical consistency -- SABs assigned via algortihm 4 but have a IAB pr code that was missed above*/
							   when Outcome_Assigned&i. in ("SAB") And put(outcome,$outclass.)='Abortion' and put(dxprrx ,$outcdpr.)='1' and &i = 4 then 8 /*SAB-PR*/

							   /*med orders*/
		                       when Outcome_Assigned&i. in ("SAB" "IAB" "UAB") And outcome in ("SAB" "IAB" "UAB") And substr(dxprrx,3) in ('2','3') then 9 /*AB-MIFE*/
		                       when Outcome_Assigned&i. in ("SAB" "IAB" "UAB") And outcome in ("SAB" "IAB" "UAB") And substr(dxprrx,3) in ('1') then 10 /*AB-MISO*/

							   /*dx codes*/
		                       when Outcome_Assigned&i. in ("SAB") And outcome in ("SAB" "UAB") and put(dxprrx ,$outcddx.)='1' then 11 /*AB-DX*/
		                       when Outcome_Assigned&i. in ("IAB") And outcome in ("IAB" "UAB") and put(dxprrx ,$outcddx.)='1' then 11 /*AB-DX*/
		                       when Outcome_Assigned&i. in ("UAB") And outcome in ("UAB") and put(dxprrx ,$outcddx.)='1' then 11 /*AB-DX*/

		                       /*if assigned outcome is UAB then pick earliest abortion dx date if no other information*/
		                       when Outcome_Assigned&i. in ("UAB") And put(outcome,$outclass.)='Abortion' and put(dxprrx ,$outcddx.)='1' then 12 /*UAB-DX*/

							   /**ECTOPIC/MOLAR OUTCOMES**/

		              		   /*Ectopic - pick encounter any [conc] proc, diag*/
		                       when Outcome_Assigned&i. in ("EM", "AEM") And outcome in ("EM" "AEM") and put(dxprrx ,$outcdpr.)='1' then 13 /*EM-PR*/
		                       when Outcome_Assigned&i. in ("EM", "AEM") And outcome in ("EM" "AEM") and put(dxprrx ,$outcddx.)='1' then 14 /*EM-DX*/

		                   End as OutcomeDateAssigned&i. 
			from  /*create dataset with all the outcome encounter information merged back onto the outcome group information*/
				(select distinct a.patient_deid, a.dt_outcomegroup_start, a.dt_outcomegroup_end, a.outcomegrp,
							a.outcome_assigned&i., a.outcome_assigned_codetype&i., a.outcome_class_assigned&i, 
							b.enc_date, b.outcome, b.dxprrx, b.delivpr_inp
					from outcomegroups_&gap._alg&i as a
					left join (select *
						from encoutcomecleanrows
						where DxPrRx ne '000') as b
					on a.patient_deid=b.patient_deid
					where b.enc_date between a.dt_outcomegroup_start and a.dt_outcomegroup_end
				)
			group by patient_deid, outcome_class_assigned&i, dt_outcomegroup_start, dt_outcomegroup_end
			having OutcomeDateAssigned&i. = min(OutcomeDateAssigned&i.)
			order by patient_deid, outcomegrp, enc_date
			; 

		%end;

		quit;

		/*Output the first row and rename enc_date as the outcome date*/

		%do j=1 %to 4;
			
			data getdate_&gap._&j.;
			set getdate0_&gap._&j.;
			format OutcomeDateAssigned&j. outdtasgn.;
				by patient_deid outcomegrp enc_date;

				*Revise the OutcomeDateAssigned variable to match SPH original coding;
				if OutcomeDateAssigned&j. = 1 then OutcomeDateAssigned&j. = 1;
					else if OutcomeDateAssigned&j. in (2,3,6,7,8,13) then OutcomeDateAssigned&j. = 2;
					else if OutcomeDateAssigned&j. in (4,5,11,12,14) then OutcomeDateAssigned&j. = 3;
					else if OutcomeDateAssigned&j. = 9 then OutcomeDateAssigned&j. = 4;
					else if OutcomeDateAssigned&j. = 10 then OutcomeDateAssigned&j. = 5;

				/*Output the date of the first encounter that met the hierarchy criteria for outcome date assignment*/
				if first.outcomegrp then output;
				rename  enc_date = Dt_Outcome_Assigned&j.;
				drop OUTCOME dxprrx delivpr_inp;
			run;

		%end;


%mend;





/*Old code -- CDL: MODIFIED based off of revisions in above macro. 11.24.2024*/
/*proc format;*/
/* 	*outcome assigned date assignment;*/
/* 	value outdtasgn 1='INPT-PR' 2='PR' 3='DX' 4='MIFE' 5='MISO';*/
/*run;*/







/*Sharon Original macro
- CDL -- recoded on 11.24.2024 because the dates were not being assigned in the way that they were supposed to.
Specifically, it was picking the minimum date without properly conducting the ordering specified in the protocol.*/
/*%macro outdts_orig(gap);*/
/**/
/*	/**/*/
/**/
/* 	proc sql stimer;  */
/**/
/*		%do i=1 %to 4; /*Do this once for each algorithm*/*/
/**/
/*		/*Create an initial dataset with the pregnancy outcome dates*/*/
/*      	create table getdate0_&gap._&i._orig as*/
/*       	select distinct a.patient_deid, dt_outcomegroup_start, dt_outcomegroup_end, outcomegrp, */
/*              a.outcome_assigned&i., outcome_assigned_codetype&i., outcome_class_assigned&i,*/
/*              min(case*/
/**/
/*					   /**DELIVERY outcome dates**/*/
/**/
/*              		   /*delivery assigned - pick encounter inpt proc [DelivPR_Inp], then any proc (conc pair), then diag-cd(pair)*/*/
/*			  		   /*If inpatient delivery w procedure code, then outcome date is the first encounter date - determined by min function*/*/
/*                       when outcome_class_assigned&i ='Delivery' and DelivPR_Inp=1 then Enc_Date*/
/**/
/*					   /*Grab the first concordant procedure code -- deliveries (order doesnt matter from abortions since based on outcome_assigned*/*/
/*                       when Outcome_Assigned&i. in ("LBM") And b.outcome in ("LBM" "UDL") and put(dxprrx ,$outcdpr.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("LBS") And b.outcome in ("LBS" "UDL") and put(dxprrx ,$outcdpr.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("MLS") And b.outcome in ("MLS" "UDL") and put(dxprrx ,$outcdpr.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("SB")  And b.outcome in ("SB" "UDL") and put(dxprrx ,$outcdpr.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("UDL") And b.outcome in ( "UDL") and put(dxprrx ,$outcdpr.)='1' then Enc_Date*/
/**/
/*					   /*Prioritize non-UDL delivery pr codes over UDL dx codes*/*/
/*					   /*NOTE: Some UDLs dont have any UDL pr codes because they had discordant delivery codes. Deal with that here.*/
/*                       If assigned outcome is UDL then pick earliest delivery proc code in outcome group*/*/
/*                       when Outcome_Assigned&i. in ("UDL") And put(b.outcome,$outclass.)='Delivery' and put(dxprrx ,$outcdpr.)='1' then Enc_Date*/
/*                      */
/*					   /*For those deliveries not yet assigned, output the date of the first concordant delivery diagnosis code.*/*/
/*                       when Outcome_Assigned&i. in ("LBM") And b.outcome in ("LBM" "UDL") and put(dxprrx ,$outcddx.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("LBS") And b.outcome in ("LBS" "UDL") and put(dxprrx ,$outcddx.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("MLS") And b.outcome in ("MLS" "UDL") and put(dxprrx ,$outcddx.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("SB") And b.outcome in ("SB" "UDL") and put(dxprrx ,$outcddx.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("UDL") And b.outcome in ( "UDL") and put(dxprrx ,$outcddx.)='1' then Enc_Date*/
/**/
/*					   /*NOTE: Some UDLs dont have any UDL dx codes because they had discordant delivery codes. Deal with that here.*/
/*                       If assigned outcome is UDL then pick earliest delivery dx code in outcome group*/*/
/*                       when Outcome_Assigned&i. in ("UDL") And put(b.outcome,$outclass.)='Delivery' and put(dxprrx ,$outcddx.)='1' then Enc_Date*/
/**/
/**/
/*					   /**ABORTION outcome dates**/*/
/*              		   /*abortion assigned - pic encounter any [conc] proc, mife/miso, diag*/*/
/**/
/*					   /*proc codes*/*/
/*                       when Outcome_Assigned&i. in ("SAB") And b.outcome in ("SAB" "UAB") and put(b.dxprrx ,$outcdpr.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("IAB") And b.outcome in ("IAB" "UAB") and put(b.dxprrx ,$outcdpr.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("UAB") And b.outcome in ("UAB") and put(b.dxprrx ,$outcdpr.)='1' then Enc_Date*/
/**/
/*					   /*NOTE: Some UABs dont have UAB procedure codes but may have procedure codes for a SAB or IAB. We deal with those */
/*					   UABs here. If a UAB doesnt have concordant proc codes, then first abortion proc code*/*/
/*					   when Outcome_Assigned&i. in ("UAB") And put(b.outcome,$outclass.)='Abortion' and put(dxprrx ,$outcdpr.)='1' then Enc_Date*/
/**/
/*					   /*CDL: ADDED for logical consistency -- SABs assigned via algortihm 4 but have a IAB pr code that was missed above*/*/
/*					   when Outcome_Assigned&i. in ("SAB") And put(b.outcome,$outclass.)='Abortion' and put(dxprrx ,$outcdpr.)='1' and &i = 4 then Enc_Date*/
/**/
/*					   /*med orders*/*/
/*                       when Outcome_Assigned&i. in ("SAB" "IAB" "UAB") And b.outcome in ("SAB" "IAB" "UAB") And substr(b.dxprrx,3) in ('2','3') then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("SAB" "IAB" "UAB") And b.outcome in ("SAB" "IAB" "UAB") And substr(b.dxprrx,3) in ('1') then Enc_Date*/
/**/
/*					   /*dx codes*/*/
/*                       when Outcome_Assigned&i. in ("SAB") And b.outcome in ("SAB" "UAB") and put(b.dxprrx ,$outcddx.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("IAB") And b.outcome in ("IAB" "UAB") and put(b.dxprrx ,$outcddx.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("UAB") And b.outcome in ("UAB") and put(b.dxprrx ,$outcddx.)='1' then Enc_Date*/
/**/
/*                       /*if assigned outcome is UAB then pick earliest abortion dx date if no other information*/*/
/*                       when Outcome_Assigned&i. in ("UAB") And put(b.outcome,$outclass.)='Abortion' and put(dxprrx ,$outcddx.)='1' then Enc_Date*/
/**/
/*					   /**ECTOPIC/MOLAR OUTCOMES**/*/
/**/
/*              		   /*Ectopic - pick encounter any [conc] proc, diag*/*/
/*                       when Outcome_Assigned&i. in ("EM", "AEM") And b.outcome in ("EM" "AEM") and put(b.dxprrx ,$outcdpr.)='1' then Enc_Date*/
/*                       when Outcome_Assigned&i. in ("EM", "AEM") And b.outcome in ("EM" "AEM") and put(b.dxprrx ,$outcddx.)='1' then Enc_Date*/
/**/
/*                   End) as Dt_Outcome_Assigned&i.  format=mmddyy10.,*/
/*				   1 as eof*/
/*       from outcomegroups_&gap._alg&i a /*Outcome groups with assigned outcomes based upon algorithm i*/*/
/*	   left join (select * from encoutcomecleanrows Where DxPrRx ne '000') B /*Encoutcomecleanrows is a dataset where each row is a possible outcome, even if dxprrx is 000*/*/
/*	   on a.patient_deid=b.patient_deid*/
/*       where enc_date between dt_outcomegroup_start and dt_outcomegroup_end  */
/*       group by a.patient_deid, outcome_class_assigned&i, dt_outcomegroup_start, dt_outcomegroup_end;*/
/*	   ;*/
/**/
/*		/*Create an indicator variable for how the pregnancy outcome dates were assigned*/*/
/* 		create table  getdate_&gap._&i._orig as*/
/*  		select distinct a.*, */
/*        	min( Case  */
/*              		   /*DELIVERY assigned - pick encounter inpt proc [DelivPR_Inp], then any proc (conc pair), then diag-cd(pair)*/*/
/*                       when outcome_class_assigned&i ='Delivery'  and DelivPR_Inp>0 then 1 /*"INPT-PR"*/*/
/**/
/*                       when Outcome_Assigned&i. in ("LBM") And b.outcome in ("LBM" "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/*/
/*                       when Outcome_Assigned&i. in ("LBS") And b.outcome in ("LBS" "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/*/
/*                       when Outcome_Assigned&i. in ("MLS") And b.outcome in ("MLS" "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/*/
/*                       when Outcome_Assigned&i. in ("SB")  And b.outcome in ("SB" "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/*/
/*                       when Outcome_Assigned&i. in ("UDL") And b.outcome in ( "UDL") and put(dxprrx ,$outcdpr.)='1' then 2 /*"DEL-PR"*/*/
/**/
/*					   /*Deal with those UDLs that did not have a non-UDL code*/*/
/*					   when Outcome_Assigned&i. in ("UDL") And put(b.outcome,$outclass.)='Delivery' and put(dxprrx ,$outcddx.)='1' then 2 /*"DEL-PR"*/*/
/*                      */
/*                       when Outcome_Assigned&i. in ("LBM") And b.outcome in ("LBM" "UDL") and put(dxprrx ,$outcddx.)='1' then 3 /*"DEL-DX"*/*/
/*                       when Outcome_Assigned&i. in ("LBS") And b.outcome in ("LBS" "UDL") and put(dxprrx ,$outcddx.)='1' then 3 /*"DEL-DX"*/*/
/*                       when Outcome_Assigned&i. in ("MLS") And b.outcome in ("MLS" "UDL") and put(dxprrx ,$outcddx.)='1' then 3 /*"DEL-DX"*/*/
/*                       when Outcome_Assigned&i. in ("SB") And b.outcome in ("SB" "UDL") and put(dxprrx ,$outcddx.)='1' then 3 /*"DEL-DX"*/*/
/*                       when Outcome_Assigned&i. in ("UDL") And b.outcome in ("UDL") and put(dxprrx ,$outcddx.)='1' then 3 /*"DEL-DX"*/*/
/**/
/*					   /*Same as above*/*/
/*					   when Outcome_Assigned&i. in ("UDL") And put(b.outcome,$outclass.)='Delivery' and put(dxprrx ,$outcddx.)='1' then 3 /*"DEL-DX"*/*/
/**/
/*             		   /*ABORTION assigned - pic encounter any [conc] proc, mife/miso, diag*/*/
/*                       when Outcome_Assigned&i. in ("SAB") And b.outcome in ("SAB" "UAB") and put(b.dxprrx ,$outcdpr.)='1' then 2 /*"AB-PR"*/*/
/*                       when Outcome_Assigned&i. in ("IAB") And b.outcome in ("IAB" "UAB") and put(b.dxprrx ,$outcdpr.)='1' then 2 /*"AB-PR"*/*/
/*                       when Outcome_Assigned&i. in ("UAB") And b.outcome in ("UAB") and put(b.dxprrx ,$outcdpr.)='1' then 2 /*"AB-PR"*/*/
/**/
/**/
/*					   /*Same as above.*/*/
/*					   when Outcome_Assigned&i. in ("UAB") And put(b.outcome,$outclass.)='Abortion' and put(dxprrx ,$outcdpr.)='1' then 2 /*"AB-PR"*/*/
/**/
/*					   /*CDL: ADDED for logical consistency -- SABs assigned via algortihm 4 but have a IAB pr code that was missed above*/*/
/*					   when Outcome_Assigned&i. in ("SAB") And put(b.outcome,$outclass.)='Abortion' and put(dxprrx ,$outcdpr.)='1' and &i = 4 then 2 /*2.1*/*/
/**/
/**/
/*                       when Outcome_Assigned&i. in ("SAB" "IAB" "UAB") And b.outcome in ("SAB" "IAB" "UAB") And substr(b.dxprrx,3) in ('2','3') then 4 /*"AB-MIFE"*/*/
/*                       when Outcome_Assigned&i. in ("SAB" "IAB" "UAB") And b.outcome in ("SAB" "IAB" "UAB") And substr(b.dxprrx,3) in ('1') then 5 /* "AB-MISO"*/*/
/**/
/*                       when Outcome_Assigned&i. in ("SAB") And b.outcome in ("SAB" "UAB") and put(b.dxprrx ,$outcddx.)='1' then 3 /*"AB-DX"*/*/
/*                       when Outcome_Assigned&i. in ("IAB") And b.outcome in ("IAB" "UAB") and put(b.dxprrx ,$outcddx.)='1' then 3 /*"AB-DX"*/*/
/*                       when Outcome_Assigned&i. in ("UAB") And b.outcome in ("UAB") and put(b.dxprrx ,$outcddx.)='1' then 3 /*"AB-DX"*/*/
/**/
/*					   /*Same as above*/*/
/*					   when Outcome_Assigned&i. in ("UAB") And put(b.outcome,$outclass.)='Abortion' and put(dxprrx ,$outcddx.)='1' then 3 /*"AB-DX"*/*/
/**/
/*                       when Outcome_Assigned&i. in ("EM", "AEM") And b.outcome in ("EM" "AEM") and put(b.dxprrx ,$outcdpr.)='1' then 2 /*"EM-PR"*/*/
/*                       when Outcome_Assigned&i. in ("EM", "AEM") And b.outcome in ("EM" "AEM") and put(b.dxprrx ,$outcddx.)='1' then 3 /*"EM-DX"*/*/
/**/
/*                   End ) as OutcomeDateAssigned&i. ,*/
/*				   1 as eof2*/
/*        from  getdate0_&gap._&i._orig A */
/*		left join (select * from encoutcomecleanrows Where DxPrRx ne '000') B */
/*		on a.patient_deid=b.patient_deid And Dt_Outcome_Assigned&i.=b.Enc_Date*/
/*        group by a.patient_deid,outcome_class_assigned&i,dt_outcomegroup_start,dt_outcomegroup_end  ;*/
/*        ;*/
/**/
/*		/*Check: Output data with groups not assigned a final pregnancy outcome date.*/*/
/*		create table nodt_&gap.&i. as  */
/*		select a.patient_deid, a.dt_outcomegroup_start, a.dt_outcomegroup_end, a.outcomegrp,  */
/*               a.outcome_assigned&i., a.outcome_assigned_codetype&i., a.outcome_class_assigned&i, b.*       */
/* 		from outcomegroups_&gap._alg&i a */
/*		left join getdate0_&gap._&i._orig x */
/*		on a.patient_deid=x.patient_deid and a.outcomegrp=x.outcomegrp*/
/*      	left join (select * from encoutcomecleanrows Where DxPrRx ne '000') B */
/*		on a.patient_deid=b.patient_deid*/
/*       	where x.dt_outcome_assigned&i=. and b.enc_date between a.dt_outcomegroup_start and a.dt_outcomegroup_end*/
/* 		;*/
/* */
/*    	select outcome_assigned&i., count(distinct cat(patient_deid,outcomegrp)) as NoDt_Alg&i._&gap.days */
/*		from nodt_&gap.&i. group by outcome_assigned&i*/
/* 		;*/
/**/
/*  	%end;*/
/*  	; */
/* 	quit;*/
/**/
/*%mend; */
;;;



/*Testing*/

/*%outdts(30);*/
/*%outdts_orig(30);*/
/**/
/*proc compare base=getdate_30_1_orig compare=getdate_30_1 nosummary;*/
/*   var Dt_Outcome_Assigned1;*/
/*   with Dt_Outcome_Assigned1;*/
/*   title 'Comparison of Variables in Different Data Sets';*/
/*run;*/

*Investigated, and these were returning unequal results for some rows.
Manually investigated those and revised code was correct;

*Code to get the dates underlying the outcome date assignments;

*%let i=1;
/*proc sql;*/
/*	create table dates_only as*/
/*	select distinct a.patient_deid, a.dt_outcomegroup_start, a.dt_outcomegroup_end, a.outcomegrp,*/
/*							a.outcome_assigned&i., a.outcome_assigned_codetype&i., a.outcome_class_assigned&i, */
/*							b.enc_date, b.outcome, b.dxprrx, b.delivpr_inp*/
/*	from outcomegroups_&gap._alg&i as a*/
/*	left join (select **/
/*				from encoutcomecleanrows*/
/*				where DxPrRx ne '000') as b*/
/*	on a.patient_deid=b.patient_deid*/
/*	where b.enc_date between a.dt_outcomegroup_start and a.dt_outcomegroup_end*/
/*	;*/
/*	quit;*/


/*proc sql;*/
/*	select sum(Dt_Outcome_Assigned1 = .) as missing_count from getdate_30_1*/
/*	; quit;*/
/*	*None missing dates in revised code;*/

/*Get expected number of rows for gap=30*/
/*%let gap=30;*/
/*proc sql;*/
/*	select count(*) as rowcount_1 from outcomegroups_&gap._alg1;*/
/*	select count(*) as rowcount_2 from outcomegroups_&gap._alg2;*/
/*	select count(*) as rowcount_3 from outcomegroups_&gap._alg3;*/
/*	select count(*) as rowcount_4 from outcomegroups_&gap._alg4;*/
/*	quit; */
*All have 151,991 rows.;
