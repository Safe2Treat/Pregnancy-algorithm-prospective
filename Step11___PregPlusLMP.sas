/*
************************************************************************************************;          
**** program: Chase_PregnancyPlusLMPs.sas                                                   ****;
**** purpose: Apply gestational age / LMP algorithm steps 1-3 from                             *;
***                                                                                            *;
***     Note: single macro that will pull pregnancy dataset of interest (outcgrp, outc alg)    *;
***           that will run all linked gestational encounters through the algorithm to select  *;
***           ^best^ LMP estimate for those that have eligible GA encounters based on the preg *;
***           outcome and GA encounter timing or table-based timing for outcome (step3)        *;

/*
NOTE: Be sure to comment in or out the versions of the algorithms that you want to run.
*/

***	MODIFICATIONS:
	- 	05.2024 - CDL reformatted and added annotation. Conducted QC. SPH and CDL agreed on
		any changes added to the program.
    - 	07.21.2024 - (SPH) modify for simple/complex prenatal-only pregnancy datasets by 
        placing GetGA macro calls and final Pregnancy_LMP_all dataset in new macro GetLMP
        (adds macvar PODS - needs values SIMP (for simple) and COMP (for complex)) 
    -   08.05.24 - sph change library setup to point to libname setup file and remove gestage dsn
	- 	10.18.24 - CDL added code to derive information on the number of prenatal encounters between
		the pregnancy LMP and the outcome or LTFU date. 

************************************************************************************************;          
*/run;;;;


/***********************************************************************************************

TABLE OF CONTENTS:
	- 00 - SET LIBRARIES, ETC.
	- 01 - PULL IN REFERENCE FILES
	- 02 - CALL GESTATIONAL AGE MACRO
	- 03 - RUN GESTATIONAL AGE MACRO
	- 04 - CREATE FINAL STACKED PREGNANCY DATASETS

***********************************************************************************************/









/***********************************************************************************************

									00 - SET LIBRARIES, ETC.

***********************************************************************************************/

/*run this locally if you need to log onto the N2 server.*/
/*SIGNOFF;*/
/*%LET server=n2.schsr.unc.edu 1234; */
/*options comamid=tcp remote=server; */
/*signon username=_prompt_;*/

*Run setup macro and define libnames;
options sasautos=(SASAUTOS "/local/projects/marketscan_preg/raw_data/programs/macros");
/*change "saveLog=" to "Y" when program is closer to complete*/
%setup(sample= random1pct, programname=Step11___PregPlusLMP, savelog=N);

options mprint;

/*Point to location of algorithm program files;*/
%let algpath=/local/projects/marketscan_preg/raw_data/programs/cdwh_algorithm;
%let xdr=/local/projects/marketscan_preg/raw_data/programs/cdwh_algorithm;

/*Library where raw data files are stored*/
libname raw(temp);
libname x(temp); /*Alternative library name used in the programs for the same source data.*/
libname base(raw);

/*Libraries for outputting - previously their own folder on the CDW-H server*/
libname int(out);

libname outd(out);
libname po(outd);
libname toutp(out);

/*Create local mirrors of the server libraries*/
/*libname lout slibref=out server=server;*/
/*libname lwork slibref = work server = server;*/
/*libname lcovref slibref = covref server = server;*/
/*libname lder slibref = der server=server;*/
/*libname lraw slibref = raw server=server;*/
/*libname ltemp slibref = temp server=server;*/



%inc "&algpath./FormatStatements.sas";

*If you want to see the datasets on the local instance of SAS, you must run this
format file locally, not on the remote submit.;








/***********************************************************************************************

								01 - PULL IN REFERENCE FILES

***********************************************************************************************/

** creates gestage dsn - adding prenatal encounter flag to those with gestational age codes;
**(formerly chase_gestagedsn.sas);
/*proc sql;*/
/* 	create table gestage as*/
/* 	select * from int.gestage*/
/*	;*/
/*	quit;*/












/***********************************************************************************************

								02 - CALL GESTATIONAL AGE MACRO

***********************************************************************************************/


**********************************************************************************************************;
**********************************************************************************************************;
*** Summary of steps from pregnancy algorithm:
*** GA-STEP 0 - to prepare, get GA code encounters and pregnancy data of interest (outcgrp window and alg)
*** GA-STEP 1 - link all pregnancies to GA codes then estimate date of LMP using Gestational Days value
***             find the ^best^ LMP using dates based on GA-codes that are good fits for the pregnancy
***             i.e. GA codes for pregnancy outcome (GAMatchOutc) and w/in 7d of outcome date (GADaysMatch)
*** GA-Step 2 - for those w/o LMP in step 1, use GA codes on prenatal encounters between 1st prenatal and
***             date LTFU (dt_gapreg) to find ^best^ guess LMP or use Zhu
*** GA-Step 3 - for all pregnancies use table to calculate LMP from pregnancy outcome (technically this
***             is applied when creating AnyGAEnc dataset
**********************************************************************************************************;
**********************************************************************************************************;

*** call macro that processes pregnancy+GA data to find LMP estimate;
%inc "&Xdr./Step11_GestationalAge_macro.sas"; *07.24 revisions;















/***********************************************************************************************

								03 - RUN GESTATIONAL AGE MACRO

***********************************************************************************************/




*>>>> GA STEP 0 <<<<*;

*** Note: this rolls up info at the GA code and Encounter date. If the GA code is on multiple encounters;
***       on the same date, it is possible that only 1 of those encounters (enc_key) also had a prenatal;
***       encounter code. use MAX fn to indicate any prenatal enc on same date as GA code;
proc sql;
	create table gestagepren as
	select distinct patient_deid, enc_date, parent_code, code, max(prenatal_enc) as Pren_GA_enc,
             preg_outcome, code_hierarchy, gestational_age_days, gest_age_wks,min_gest_age, max_gest_age,
             zhu_test, zhu_hierarchy
    from int.gestage
    group by patient_deid, parent_code, enc_date, code, preg_outcome, code_hierarchy, 
               gestational_age_days, min_gest_age, max_gest_age 
	;
    quit;


/*Create a macro that deletes the gestational age datasets that do not need anymore*/
%macro delete_ga_dsns;
	proc datasets library=work memtype=data nolist;
		delete anyga: gaenc: pregnancy_comp_: pregnancy_simp_:
			pregs: x;
	run; quit;
%mend;



%Macro GetLMP(pods);


			%*Algorithms 1-4, assuming a 7-day gap between pregnancy outcome claims to define pregnancy outcome groups;

            %GetGA(7, 1);;
				%delete_ga_dsns;
            %GetGA(7, 2);;
				%delete_ga_dsns;
            %GetGA(7, 3);; 
				%delete_ga_dsns;
            %GetGA(7, 4);; 
				%delete_ga_dsns;


			%*Algorithms 1-4, assuming a 30-day gap between pregnancy outcome claims to define pregnancy outcome groups;
            %GetGA(30, 1);; 
				%delete_ga_dsns;
            %GetGA(30, 2);; 
				%delete_ga_dsns;
            %GetGA(30, 3);; 
				%delete_ga_dsns;
            %GetGA(30, 4);; 
				%delete_ga_dsns;

        /***********************************************************************************************

        						04 - CREATE FINAL STACKED PREGNANCY DATASETS

        ***********************************************************************************************/


        /*create stacked dataset with all pregnancies and LMPs*/
        /* 06.12.24 - select LMP date (and add label):
            1.	If only one LMP assigned to the pregnancy via gestational age codes, use that LMP. [dt_lmp_alg]
            2.	If more than one LMP assigned to the pregnancy via gestational age codes (>1 code at the same 
                level of a hierarchy), use the earliest LMP estimate. [dt_lmp_min/max/wtavg]
            3.	If no LMP assigned via codes, use the LMP determined via the outcome. [dt_lmp_table]
        */
        data Pregnancy_LMP_&pods._All ;
        length Pregnancy_ID $15. Algorithm $4.;
        set
        	Pregnancy_LMP_&pods._7_1
           	Pregnancy_LMP_&pods._7_2
            Pregnancy_LMP_&pods._7_3 
            Pregnancy_LMP_&pods._7_4 


            Pregnancy_LMP_&pods._30_1 
            Pregnancy_LMP_&pods._30_2 
            Pregnancy_LMP_&pods._30_3 
            Pregnancy_LMP_&pods._30_4 
            ;

            Pregnancy_ID = compress(Algorithm||'-'||idxpren);

             if missing(dt_lmp_alg) =0 then Dt_LMP = dt_lmp_alg;
             	else if missing(dt_lmp_min)=0 then Dt_LMP = dt_lmp_min; *same as min(dt_lmp_min,dt_lmp_max,dt_lmp_wtavg,dt_lmp_complex);
             	else dt_lmp = dt_lmp_table;

             label dt_lmp = "Final LMP estiamte"
                   pregnancy_id="Pregnancy identifier (algorithm-idxpren)"
             ;

        run;

%Mend GetLMP ;

    
option mprint;

       %GetLMP(pods=SIMP); 

/*        %GetLMP(pods=COMP); */





/***********************************************************************************************

							05 - ADD INFORMATION ON PRENATAL ENCOUNTERS

Added 10.18.2024 by CDL per conversations with MEW on variables needed for stratification.

***********************************************************************************************/


*The dataset with all the prenatal encounter dates according to primary prenatl codes 
		is: int.codeprenatal_meg1_dts;
*Join the prenatal encounter dates onto the pregnancy cohort according to person ID and pregnancy dates;


/***SIMPLE STEP 8 COHORT***/

proc sql;
	create table out.pregnancy_lmp_simp_all as
	select distinct a.*, b.num_pnc_start_end, input(a.patient_deid, best12.) as enrolid format=best12. /*This step removes duplicate pregnancies*/
	from pregnancy_lmp_simp_all as a
	left join (select patient_deid, Pregnancy_ID, sum(enc_date ne .) as num_pnc_start_end
			   from (select a.*, b.enc_date
			         from (select *, dt_lmp /*min(dt_lmp, dt_prenenc1st)*/ as preg_start format=MMDDYY10., 
						          dt_gapreg as preg_end
		  		           from pregnancy_lmp_simp_all) as a
		  	         left join int.codeprenatal_meg1_dts as b
		             on a.patient_deid = b.patient_deid and a.preg_start le b.enc_date le a.preg_end)
	                 group by patient_deid, Pregnancy_ID ) as b
	on a.patient_deid = b.patient_deid and a.pregnancy_ID = b.pregnancy_ID
	;
	quit;


/***COMPLEX STEP 8 COHORT***/

/*proc sql;*/
/*	create table out.pregnancy_lmp_comp_all as*/
/*	select distinct a.*, b.num_pnc_start_end /*This step removes duplicate pregnancies*/*/
/*	from pregnancy_lmp_comp_all as a*/
/*	left join (select patient_deid, Pregnancy_ID, sum(enc_date ne .) as num_pnc_start_end*/
/*			   from (select a.*, b.enc_date*/
/*			         from (select *, dt_lmp /*min(dt_lmp, dt_prenenc1st)*/ as preg_start format=MMDDYY10., */
/*						          dt_gapreg as preg_end*/
/*		  		           from pregnancy_lmp_comp_all) as a*/
/*		  	         left join int.codeprenatal_meg1_dts as b*/
/*		             on a.patient_deid = b.patient_deid and a.preg_start le b.enc_date le a.preg_end)*/
/*	                 group by patient_deid, Pregnancy_ID ) as b*/
/*	on a.patient_deid = b.patient_deid and a.pregnancy_ID = b.pregnancy_ID*/
/*	;*/
/*	quit;*/


