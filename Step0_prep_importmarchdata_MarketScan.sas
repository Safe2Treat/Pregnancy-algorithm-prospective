/*************************************************************************************
PROGRAM: Step0_prep_import_data.sas
PROGRAMMER: Sharon, Chase
DATE: 05-2024

PURPOSE: Create code reference files and attach relevant codes 
to encounters and medication orders.

NOTES: This program can be run with a batch submit once the random1pct versus full 
MarketScan sample is specified in the setup macro.

MODIFICATIONS:
	- 05.2024 - Chase added additional comments and formatting.
    - 08.2024 - sph - add correction to capture all Med orders, create additional 
                datasets used in applying algorithm (e.g gestational age )
**************************************************************************************/












/*************************************************************************************

TABLE OF CONTENTS:

	- 00 - SET UP LIBRARIES, ETC.
	- 01 - MAKE CODE LEVEL DATASETS
	- 02 - CREATE SUBSEQUENT NECESSARY DATASETS FOR THE ALGORITHM

**************************************************************************************/






/*************************************************************************************

							00 - SET UP LIBRARIES, ETC.

This will need to be modified if implemented in a different folder.

**************************************************************************************/

/*run this locally if you need to log onto the N2 server.*/
/*SIGNOFF;*/
/*%LET server=n2.schsr.unc.edu 1234; */
/*options comamid=tcp remote=server; */
/*signon username=_prompt_;*/

*Run setup macro and define libnames;
options sasautos=(SASAUTOS "/local/projects/marketscan_preg/raw_data/programs/macros");
/*change "saveLog=" to "Y" when program is closer to complete*/
%setup(sample= random1pct, programname=Step0_prep_importmarchdata_MarketScan, savelog=Y);

options mprint;

/*Point to location of algorithm program files;*/
%let algpath=/local/projects/marketscan_preg/raw_data/programs/cdwh_algorithm;

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







/*************************************************************************************

					01 - ADDITIONAL CLEANING OF THE TEMP DATASETS

**************************************************************************************/


****dx-9;
*We want to grab Diagnosis codes and dates from inpatient services and inpatient 
admissions files. In particular, we aim to gather all distinct diagnosis and service 
date combinations from the inpatient service files. If the admission record provides 
additional unique combinations of codes and service dates, those were retained as well.
;

*Identify the distinct codes from Inptient admission and inpatient service files;
proc sql;
	
	*Clean up the inpatient admission files. Specifically, we want to output
	the record with the same svcdate and the last tsvcdat.;
	create table temp_dx9_inptadm as
	select enrolid, caseid, svcdate, max(tsvcdat) as tsvcdat format DATE9., claimLocation,
		code, code_type, description
	from temp.dx9 (where = (claimLocation = "InptAdm"))
	group by enrolid, caseid, svcdate, claimLocation, code, code_type, description
	;

	*Same clean up with the inpatient services. Of note, we are only using the first svcdate 
	for the algorithm;
	create table temp_dx9_inptserv as 
	select enrolid, caseid, svcdate, max(tsvcdat) as tsvcdat format DATE9., claimLocation,
		code, code_type, description
	from temp.dx9 (where = (claimLocation ="InptServ"))
	group by enrolid, caseid, svcdate, claimLocation, code, code_type, description
	;

	quit;


*Now we want to full join the inpatient records, prioritizing the inpatient service 
	record information;
proc sql;
	create table inpatient as
	select coalesce(a.enrolid, b.enrolid) as enrolid format BEST12.,
		coalesce(a.caseid, b.caseid) as caseid format BEST12.,
		coalesce(a.svcdate, b.svcdate) as svcdate format DATE9.,
		case when missing(a.svcdate) then b.tsvcdat else a.tsvcdat end as tsvcdat format DATE9.,
		case when missing(a.svcdate) then b.claimLocation else a.claimLocation end as claimLocation format $9.,
		coalesce(a.code, b.code) as code format $8.,
		coalesce(a.code_type, b.code_type) as code_type format $9.,
		coalesce(a.description, b.description) as description format $258.
	from temp_dx9_inptserv as a
	full join temp_dx9_inptadm as b
	on a.enrolid = b.enrolid and a.caseid = b.caseid and a.svcdate = b.svcdate and a.code = b.code
	;
	quit;

/**Double check that there are only unique combinations of service date and code;*/
/*proc sql;*/
/*	create table test as*/
/*	select count(*) as unique_count*/
/*	from inpatient*/
/*	group by enrolid, caseid, svcdate, code*/
/*	;*/
/*	quit;*/
/*proc freq data=test;*/
/*	table unique_count / missing;*/
/*run;*/
/*	*Looks good;*/


*Now we want to stack the revised inpatient dx9 dataset with the outpatient;
proc sql;
	create table temp.dx9_rev as
	select *
	from inpatient
	union corr
	select *
	from temp.dx9 (where = (claimLocation = "OutptServ"))
	;
	quit;
 
/**See if there are less rows;*/
/*proc sql;*/
/*	select count(*) as orig_count from temp.dx9;*/
/*	select count(*) as rev_count from temp.dx9_rev;*/
/*	quit;*/
/*	*Yes, fewer;*/

proc datasets gennum = all;
	delete temp_dx9: inpatient;
run; quit; run;

/**Test: Confirm that we have the same number of distinct enrolid caseid svcdate and code combinations from */
/*the two files. None of that should have been lost;*/
/*proc sql;*/
/*	select count(*) as orig_dist from (select distinct enrolid, caseid, svcdate, code from temp.dx9);*/
/*	select count(*) as rev_dist from (select distinct enrolid, caseid, svcdate, code from temp.dx9_rev);*/
/*	quit;*/
/*	*Looks good;*/





****dx-10;

*Now do the same thing with the ICD-10 dx dataset;

*Identify the distinct codes from Inptient admission and inpatient service files;
proc sql;
	
	*Clean up the inpatient admission files. Specifically, we want to output
	the record with the same svcdate and the last tsvcdat.;
	create table temp_dx10_inptadm as
	select enrolid, caseid, svcdate, max(tsvcdat) as tsvcdat format DATE9., claimLocation,
		code, code_type, description
	from temp.dx10 (where = (claimLocation = "InptAdm"))
	group by enrolid, caseid, svcdate, claimLocation, code, code_type, description
	;

	*Same clean up with the inpatient services. Of note, we are only using the first svcdate 
	for the algorithm;
	create table temp_dx10_inptserv as 
	select enrolid, caseid, svcdate, max(tsvcdat) as tsvcdat format DATE9., claimLocation,
		code, code_type, description
	from temp.dx10 (where = (claimLocation ="InptServ"))
	group by enrolid, caseid, svcdate, claimLocation, code, code_type, description
	;

	quit;


*Now we want to full join the inpatient records, prioritizing the inpatient service 
	record information;
proc sql;
	create table inpatient as
	select coalesce(a.enrolid, b.enrolid) as enrolid format BEST12.,
		coalesce(a.caseid, b.caseid) as caseid format BEST12.,
		coalesce(a.svcdate, b.svcdate) as svcdate format DATE9.,
		case when missing(a.svcdate) then b.tsvcdat else a.tsvcdat end as tsvcdat format DATE9.,
		case when missing(a.svcdate) then b.claimLocation else a.claimLocation end as claimLocation format $9.,
		coalesce(a.code, b.code) as code format $8.,
		coalesce(a.code_type, b.code_type) as code_type format $9.,
		coalesce(a.description, b.description) as description format $258.
	from temp_dx10_inptserv as a
	full join temp_dx10_inptadm as b
	on a.enrolid = b.enrolid and a.caseid = b.caseid and a.svcdate = b.svcdate and a.code = b.code
	;
	quit;

/**Double check that there are only unique combinations of service date and code;*/
/*proc sql;*/
/*	create table test as*/
/*	select count(*) as unique_count*/
/*	from inpatient*/
/*	group by enrolid, caseid, svcdate, code*/
/*	;*/
/*	quit;*/
/*proc freq data=test;*/
/*	table unique_count / missing;*/
/*run;*/
/*	*Looks good;*/


*Now we want to stack the revised inpatient dx9 dataset with the outpatient;
proc sql;
	create table temp.dx10_rev as
	select *
	from inpatient
	union corr
	select *
	from temp.dx10 (where = (claimLocation = "OutptServ"))
	;
	quit;
 
/**See if there are less rows;*/
/*proc sql;*/
/*	select count(*) as orig_count from temp.dx10;*/
/*	select count(*) as rev_count from temp.dx10_rev;*/
/*	quit;*/
/*	*Yes, fewer;*/

proc datasets gennum = all;
	delete temp_dx10: inpatient;
run; quit; run;


/**Test: Confirm that we have the same number of distinct enrolid caseid svcdate and code combinations from */
/*the two files. None of that should have been lost;*/
/*proc sql;*/
/*	select count(*) as orig_dist from (select distinct enrolid, caseid, svcdate, code from temp.dx10);*/
/*	select count(*) as rev_dist from (select distinct enrolid, caseid, svcdate, code from temp.dx10_rev);*/
/*	quit;*/
/*	*Looks good;*/






****Procedure codes;

*Finally, we must clean up the procedure codes in order to make sure that there are not
unnecessary duplicate codes on the inpatient record. We approach the procedure codes
slightly differently than the outpatient codes.

In particular, we prioritize procedure codes identified from the inpatient service record.
If a procedure code exists on an inpatient service record for the same admission, we only
retain that code. However, if a procedure code only exists on the inpatient admission record
for that CASEID (should not happen but does), then we will retain that row.;

proc sql;
	create table inpatient as
	select coalesce(a.enrolid, b.enrolid) as enrolid format BEST12.,
		coalesce(a.caseid, b.caseid) as caseid format BEST12.,
		case when missing(a.code) then b.svcdate else a.svcdate end as svcdate format DATE9.,
		case when missing(a.code) then b.tsvcdat else a.tsvcdat end as tsvcdat format DATE9.,
		case when missing(a.code) then b.claimLocation else a.claimLocation end as claimLocation format $9.,
		coalesce(a.code, b.code) as code format $8.,
		coalesce(a.code_type, b.code_type) as code_type format $9.,
		coalesce(a.description, b.description) as description format $258.
	from temp.proc (where = (claimLocation = "InptServ")) as a /*inpatient service files*/
	full join temp.proc (where = (claimLocation = "InptAdm")) as b /*inpatient admissions*/
	on a.enrolid=b.enrolid and a.caseid=b.caseid and a.code=b.code
	;
	quit;

*Union the outpatient procedures onto the inpatient;
proc sql;
	create table temp.proc_rev as
	select *
	from inpatient
	union corr
	select *
	from temp.proc (where = (claimLocation = "OutptServ"))
	;
	quit;

/**Test: Confirm that we have the same number of distinct enrolid caseid and code combinations from */
/*the two files. None of that should have been lost;*/
/*proc sql;*/
/*	select count(*) as orig_dist from (select distinct enrolid, caseid, code from temp.proc);*/
/*	select count(*) as rev_dist  from (select distinct enrolid, caseid, code from temp.proc_rev);*/
/*	quit;*/
/*	*Looks good;*/

proc datasets gennum = all;
	delete inpatient;
run;



*******Medications;

*Finally, we want to subset the medication records to those that could plausibly be used to identify our
outcomes - abortion, specifically.;

*In the US, there are two primary uses for mifepristone: pregnancy termination and hyperglycemia in
patients with Cushing syndrome. The regimen for medication-induced abortion with mifepristone includes 
1 200mg dose taken by mouth followed, 24-48 hours later, by 800 mcg of misoprostol. As such, we limited
to 200 mg doses of mifepristone with 1-2 pills dispensed.

b.	There are a few accepted regimens for termination of pregnancy with single-agent misoprostol. The 
Society for Family Planning recommends 800 mcg every 3 hours for 3-4 doses until expulsion at <=12 weeks gestation, 
400 mcg every 3 hours until expulsion for 140-236 weeks’ gestation, and 200 mcg every 3 hours until expulsion for 
24w0d to 27w6d weeks’ gestation. 

As such, we’re going to limit to those claims with a total dose of misoprostol between 
800 mcg and 3,200 mcg. Further, the total dose must be evenly divisible by 200.

Finally, I removed rows where the quantity dispensed was negative or 0;

data temp_med;
set temp.med;

	*Create a strength variable that is numeric and can be used to calculate total_dose;
	strength_rev = scan(STRNGTH, 1, ' ');
	strength = input(strength_rev, best32.);

	total_dose = metqty * strength;

	if upcase(THRDTDS) = "MIFEPRISTONE" and (STRENGTH ne 200 or 1 <= METQTY <= 2) then delete;

	if upcase(THRDTDS) = "MISOPROSTOL" and (total_dose < 800 or total_dose > 3200 or mod(total_dose, 200) ne 0 or DAYSUPP < 1 or DAYSUPP > 2) then delete;

	if metqty <= 0 then delete;
	drop strength_rev;
run;

/*proc freq data=temp_med;*/
/*	table DAYSUPP / missing;*/
/*run;*/
/*proc freq data=temp_med;*/
/*	table THRDTDS / missing;*/
/*run;*/









/*************************************************************************************

				02 - CREATE SUBSEQUENT NECESSARY DATASETS FOR THE ALGORITHM

**************************************************************************************/

*CREATE ENC_KEY VARIABLE

The CDW-H electronic health care data came with an enc_key variable, which uniquely identified each encounter.
This variable is not present in the same way in MarketScan claims data. While the variable CASEID can be used to 
link inpatient claims, it is missing for outpatient encounters. Further, we have identified different
dates for the same inpatient encounters because we used inpatient service records to define dates. As such,
we are going to completely abandon caseid and instead make our own encounter key by combining enrolid with 
a count based on ordered svcdate

We create a simple proxy here that is unique for outpatient claims (dx, pr, and meds).
;
proc sql;
	create table enc_key as
	select distinct enrolid, /*caseid,*/ svcdate
	from temp.dx10_rev
	union 
	select distinct enrolid, /*caseid,*/ svcdate
	from temp.dx9_rev
	union
	select distinct enrolid, /*caseid,*/ svcdate
	from temp.proc_rev
	union
	select distinct enrolid, /*. as caseid,*/ svcdate
	from temp_med
	;
	quit;

*Here, we will distinguish enc_key according to svcdate and enrolid. For those encounters with non-missing caseid, 
	we will retain caseid;
proc sort data=enc_key;
	by enrolid svcdate;
run;
data enc_key2;
set enc_key;
	by enrolid svcdate;
	retain enc_cnt;

	if first.enrolid then enc_cnt = 0;

	if first.svcdate then enc_cnt = enc_cnt + 1;
		else enc_cnt = enc_cnt;
run;

data enc_key3;
length enc_key $18. enc_deid $18.;
set enc_key2;

	enc_key = catx('_', enrolid, enc_cnt);
	enc_deid = enc_key; *Both variables were recorded in CDW-H data and so both are reflected here.;

run;

proc sort data=enc_key3 out=temp.enc_key nodup;
	by enrolid svcdate;
run;

proc datasets gennum=all;
	delete enc_key:;
run; quit; run;







/*Create a dataset of all of the enrolids for individuals in the dataset*/
proc sql;

	create table x.women_ids (label="unique patient_deid") as
	select distinct enrolid as patient_deid
	from temp.dx10_rev
	union
	select distinct enrolid as patient_deid
	from temp.dx9_rev
	union
	select distinct enrolid as patient_deid
	from temp_med
	union
	select distinct enrolid as patient_deid
	from temp.proc_rev
	;

	/*Get a count of all the distinct IDs in the pregnant person dataset*/
 	select count(distinct patient_deid) as PatientIDs into :womencnt from x.women_ids;
	; 
	quit; 

	%put &womencnt;


/*proc sql;	*/
/*	*Make a dataset with all the diagnosis and procedure codes - each code is a row;*/
/*	create table x.women_diag_proc (label="All encounters, 1 obs per Diag/Proc code") as*/
/* 	select * */
/*	from allicd (drop=mom_age_at_Enc mom_marital_status mom_race mom_raceth insurance);*/
/**/
/*	quit;*/



/***now apply codes from reference files;*/


/*Grab all encounters with gestational age codes - this will provide info
on which encounters have a gestational age code, though an encounter may appear more
than once if more than one gestational age code is recorded at that encounter.*/
proc sql stimer noerrorstop;
	create table codeage as
	select distinct a.svcdate as enc_date, case when a.claimLocation in ("Inpt", "InptServ", "InptAdm") then "Inpatient"
												when a.claimLocation = "OutptServ" then "Outpatient"
												else ""
												end as enc_base_class, 
			a.enrolid, b.code, b.code_type, b.description,
			b.parent_code, b.preg_outcome, b.code_hierarchy, b.gest_age_wks,
			b.gestational_age_days, b.min_gest_age, b.max_gest_age, b.latest_preg_outcome, b.usage_unclr,
			case
				when b.code_type = "ICD-10 Dx" then "dx10"
				when b.code_type = "ICD-9 Dx" then "dx9"
				when b.code_type in ("CPT", "HCPCS") then "cpt"
				when b.code_type = "ICD-10 Px" then "pr10"
				when b.code_type = "ICD-9 Px" then "pr9"
				else "" end as codetype,
			calculated codetype as code_typeb, b.zhu_test, b.zhu_hierarchy,
			c.enc_key, c.enc_deid
	from (select *  /*Create a dataset with all dx and pr codes.*/
			from temp.dx10_rev 
			union corr 
			select * 
			from temp.dx9_rev
			union corr
			select *
			from temp.proc_rev) as a
	join covref.gestage_cdwh as b
	on a.code=b.code
	left join temp.enc_key as c
	on a.enrolid = c.enrolid and /*a.caseid = c.caseid and*/ a.svcdate = c.svcdate
	;
	quit;

data out.codeage;
set codeage;
	format patient_deid $12.;
	patient_deid = enrolid;
run;








/*proc sql;*/
/*	*Get counts;*/
/*	select count(distinct patient_deid) */
/*	as PatientIDs, count(distinct enc_deid) as Encounters, count(*) as rows  */
/*	from out.codeage*/
/*    ;*/
/*	quit;*/






/*Double check for any weird missingness. None of the variables below should have missing values*/
/*proc sql;*/
/*	select sum(patient_deid = "") as missing_id, sum(code = "") as missing_code,*/
/*			sum(enc_key = "") as missing_enc_key, sum(enc_key ne enc_deid) as enc_key_not_match,*/
/*			sum(enc_date = .) as missing_date*/
/*	from out.codeage*/
/*	;*/
/*	quit;*/
/*	*No missing for any;*/
/*proc freq data=out.codeage;*/
/*	table enc_base_class code_type code_typeb codetype preg_outcome code_hierarchy / missing;*/
/*run;*/
/*proc freq data=out.codeage;*/
/*	where preg_outcome = "";*/
/*	table code_hierarchy description;*/
/*run;*/
/**Confirmed that none missing preg_outcome;*/







/*Grab all prenatal codes from the allicd file -- Same set up as gestational age codes,
	just different code reference list.*/
proc sql stimer noerrorstop;

	create table codeprenatal as
	select distinct a.svcdate as enc_date, case when a.claimLocation in ("Inpt", "InptServ", "InptAdm") then "Inpatient"
												when a.claimLocation = "OutptServ" then "Outpatient"
												else ""
												end as enc_base_class, 
			a.enrolid, b.code, b.code_type, b.description,
			b.megan_primary_prenatal, b.code_typeb,
			case
				when b.code_type = "ICD-10 DX" then "dx10"
				when b.code_type = "ICD-9 DX" then "dx9"
				when b.code_type in ("CPT", "HCPCS") then "cpt"
				when b.code_type = "ICD-10 PX" then "pr10"
				when b.code_type = "ICD-9 PX" then "pr9"
				else "" end as codetype,
			c.enc_key, c.enc_deid
	from (select *  /*Create a dataset with all dx and pr codes.*/
			from temp.dx10_rev 
			union corr 
			select * 
			from temp.dx9_rev
			union corr
			select *
			from temp.proc_rev) as a
	join covref.prenatal_cdwh (where = (MEGAN_Primary_Prenatal = 1)) as b
	on a.code=b.code
	left join temp.enc_key as c
	on a.enrolid = c.enrolid and /*a.caseid = c.caseid and*/ a.svcdate = c.svcdate
	;
	quit;

data out.codeprenatal;
set codeprenatal;
	format patient_deid $12.;
	patient_deid = enrolid;
run;

/*proc sql;*/
/*	*Get counts to evaluate;*/
/*    select count(distinct patient_deid) as PatientIDs, count(distinct enc_deid) as Encounters, count(*) as rows */
/*	from out.codePrenatal*/
/*    ;*/
/*	quit;*/


/**Double check for any weird missingness. None of the variables below should have missing values;*/
/*proc sql;*/
/*	select sum(patient_deid = "") as missing_id, sum(code = "") as missing_code,*/
/*			sum(enc_key = "") as missing_enc_key, sum(enc_key ne enc_deid) as enc_key_not_match*/
/*	from out.codeprenatal*/
/*	;*/
/*	quit;*/
/*	*No missing for any;*/
/*proc freq data=out.codeprenatal;*/
/*	table enc_base_class code_type code_typeb codetype / missing;*/
/*run;*/






/*Get pregnancy outcome codes -- Same set up as the gestational age codes and prenatal codes*/
proc sql stimer noerrorstop;

	create table codeoutcome as
	select distinct a.svcdate as enc_date, case when a.claimLocation in ("Inpt", "InptServ", "InptAdm") then "Inpatient"
												when a.claimLocation = "OutptServ" then "Outpatient"
												else ""
												end as enc_base_class, 
			a.enrolid, b.code, b.code_type, b.description,
			b.outcome, b.usage_unclear, b.code_typeb,
			case
				when b.code_type = "ICD-10 DX" then "dx10"
				when b.code_type = "ICD-9 DX" then "dx9"
				when b.code_type in ("CPT", "HCPCS") then "cpt"
				when b.code_type = "ICD-10 PX" then "pr10"
				when b.code_type = "ICD-9 PX" then "pr9"
				else "" end as codetype,
			c.enc_key, c.enc_deid
	from (select *  /*Create a dataset with all dx and pr codes.*/
			from temp.dx10_rev 
			union corr 
			select * 
			from temp.dx9_rev
			union corr
			select *
			from temp.proc_rev) as a
	join covref.preg_outcomes_cdwh as b
	on a.code=b.code
	left join temp.enc_key as c
	on a.enrolid = c.enrolid and /*a.caseid = c.caseid and*/ a.svcdate = c.svcdate
	;
	quit;

data out.codeoutcome;
set codeoutcome;
	format patient_deid $12.;
	patient_deid = enrolid;
run;

/**Get counts to evaluate;*/
/*proc sql;*/
/*    select count(distinct patient_deid) as PatientIDs, count(distinct enc_deid) as Encounters, count(*) as rows */
/*	from out.codeoutcome*/
/*    ;*/
/*	quit;*/


/*proc sql;*/
/*	select sum(patient_deid = "") as missing_id, sum(code = "") as missing_code,*/
/*			sum(enc_key = "") as missing_enc_key, sum(enc_key ne enc_deid) as enc_key_not_match,*/
/*			sum(enc_date = .) as missing_date*/
/*	from out.codeoutcome*/
/*	;*/
/*	quit;*/
/*	*No missing for any;*/
/*proc freq data=out.codeoutcome;*/
/*	table enc_base_class code_type code_typeb codetype outcome / missing;*/
/*run;*/

/*proc freq data=int.codemed;*/
/*table code;*/
/*run;*/
/*proc contents data=temp_med; run;*/

/*Modify the final medication dataset to match what is needed for the CDW-H code algorithm*/
proc sql stimer noerrorstop;
	create table codemed as
	select distinct a.svcdate as enc_date, "Outpatient" as enc_base_class, /*Outpatient Fill*/
			a.enrolid, 
			case
				when upcase(a.THRDTDS) = "MIFEPRISTONE" then "mifep"
				when upcase(a.THRDTDS) = "MISOPROSTOL" then "misop"
				else ""
				end as code,
			"med" as code_type,
			"" as description, "Unspecified Abortion" as outcome, 0 as usage_unclear,
			"med" as code_typeb, "med" as codetype,
			c.enc_key, c.enc_deid
	from temp_med as a
	left join temp.enc_key as c
	on a.enrolid = c.enrolid and a.svcdate = c.svcdate
	;
	quit;
	*Decrease row number because more than one NDC may link from the Redbook file since we link on NDC-9.
	However, the only difference should be packaging, so do not anticipate needing additional cleaning from 
	the select distinct command here.;

data out.codemed;
set codemed;
	format patient_deid $12.;
	patient_deid = enrolid;
run;

/**Get counts to evaluate;*/
/*proc sql;*/
/*    select count(distinct patient_deid) as PatientIDs, count(distinct enc_deid) as Encounters, count(*) as rows */
/*	from out.codemed*/
/*    ;*/
/*	quit;*/

/**Check for any weird missingness;*/
/*proc sql;*/
/*	select sum(patient_deid = "") as missing_id, sum(code = "") as missing_code,*/
/*			sum(enc_key = "") as missing_enc_key, sum(enc_key ne enc_deid) as enc_key_not_match,*/
/*			sum(enc_date = .) as missing_date*/
/*	from out.codemed*/
/*	;*/
/*	quit;*/
/*	*No missing for any;*/
/*proc freq data=out.codemed;*/
/*	table enc_base_class code code_type code_typeb codetype outcome / missing;*/
/*run;*/







************************** add more datasets ************************;


/*Create a dataset _codepernatal_meg1 that contains each date that someone
has an encounter with at least one primary prenatal code*/
proc sql stimer; 
 	create table _codeprenatal_meg1 as 
  	select distinct patient_deid, enc_date, megan_primary_prenatal,
         	case enc_base_class when '' then "unknown" else enc_base_class end as BASE_CLASS
   	from out.codeprenatal 
	where megan_primary_prenatal 
	order by patient_deid, enc_date;
	quit;

/*Transpose the dataset so that we know the location of encounters on each 
encounter date with at least 1 prenatal code.*/
proc transpose data=_codeprenatal_meg1  prefix=pren_ out= out.codeprenatal_meg1_dts (drop = _name_ _label_);
 	by patient_deid enc_date; 
	id base_class; 
	var megan_primary_prenatal;
run; 
/*proc datasets nolist lib=work; change _codeprenatal_meg1_dts = codeprenatal_meg1_dts;*/
/*quit;*08.24 added rename to keep dsn name consistent w/ other datafiles in folder;*/


/*----------------------------------------------------------------------------------------------------*/
**Create the gestage dataset from codeage. The primary difference here is that gestage now
additionally has a flag (prenatal_enc) that indicates whether the encounter with at least 1 gestational
age code also contains a prenatal code;
proc sql;
 	create table out.gestage as
  	select distinct a.*, b.enc_key ne "" as prenatal_enc  
  	from out.codeage a 
	left join (select enc_key 
				from out.codeprenatal
				where megan_primary_prenatal) b 
	on a.enc_key=b.enc_key
	;
	quit;


/*----------------------------------------------------------------------------------------------------*/

/*08.2024  - and add alt gestage dsn needed for complex prenatal-only pregnancies (step8-complex)*/

 **(formerly chase_createGestAgePrenforStep8Complex.sas);
*** Note: this rolls up info at the GA code and Encounter date. If the GA code is on multiple encounters;
***       on the same date, it is possible that only 1 of those encounters (enc_key) also had a prenatal;
***       encounter code. use MAX fn to indicate any prenatal enc on same date as GA code;

*** Note: this rolls up info at the GA code and Encounter date. If the GA code is on multiple encounters;
***       on the same date, it is possible that only 1 of those encounters (enc_key) also had a prenatal;
***       encounter code. use MAX fn to indicate any prenatal enc on same date as any GA code;
*** Note: dont care about individual encounter billing code, just the age values assigned on that date;
***       so exclude GA enc billing code from output dsn;
***       06.18-move here limit to OK GA encounters (8a ignore prenatal care, weight only);
***             also limit to those GA encounters that are also prenatal encounters;
proc sql;
	create table gestageprenx as
    select *
    from (
		select distinct patient_deid, enc_date, enc_date as Dt_GAEnc, max(prenatal_enc) as Pren_GA_enc,
				code_hierarchy, gestational_age_days, gest_age_wks, min_gest_age, max_gest_age,
                max_gest_age - min_gest_age as MinMax_GA_Range, LATEST_PREG_OUTCOME,
                case code_hierarchy 
                       when "Specific gestational age" then 1
                       when "Extreme prematurity" then 2
                       when "Other preterm" then 3
                       when "Post-term" then 3
                       when "Missing" then 4
                       else 99 end as GAHier,
				zhu_test, zhu_hierarchy
		from out.gestage /*Each row is a gestational age code*/
		where lowcase(code_hierarchy) not in ("prenatal care" "weight only - preterm") /*These are not codes used for the primary gestational age assignment.*/
		group by patient_deid, parent_code, enc_date, code, preg_outcome, code_hierarchy, 
                 gestational_age_days, min_gest_age, max_gest_age 
           )
	where pren_ga_enc =1 /*Limit to those gestational age encounters that are also prenatal encounters*/
    ;
    quit;


*if date has different hierarchy but same age estimates then can keep the best hierarchy match row;
*now if mult rows for GA enc Date its because provisional age est for underlying GA-codes differ;
proc sql;
	create table out.gestagepren_step8 as 
	select DISTINCT patient_deid, dt_gaenc, pren_ga_enc, gestational_age_days, gest_age_wks, min_gest_age, max_gest_age,
            MinMax_GA_Range, latest_preg_outcome, gahier, zhu_test, zhu_hierarchy
	from gestageprenx 
	group by patient_deid, dt_gaenc, gestational_age_days, gest_age_wks, min_gest_age, max_gest_age 
	having gahier = min(gahier); /*Limit to the gestational age at the top of the hierarchy*/
	quit;


