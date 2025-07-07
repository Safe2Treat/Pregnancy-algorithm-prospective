/***********************************************************************************************     
PROGRAM: Step00_create_data_files.sas 
PROGRAMMER: Chase Latour

PURPOSE: Create SAS data files from the raw and derived MarketScan data that contain all of the
encounter-level datasets required for running the analysis.

***                                                                           
NOTES: To run, be sure that
(1) the reference datasets are up to date (see Step00_create_reference_files.sas) and
(2) you have specified the correct years of MarketScan data that you are interested in (see the
years and years_icd10 macro variables below).

Once completed, the program can be run via batch submit without interaction (assuming libraries
are specified correctly).

MODIFICATIONS:
*************************************************************************************************/







/************************************************************************************************

TABLE OF CONTENTS:
	- 00 - SET LIBRARIES
	- 01 - CREATE DATASET OF ALL FEMALES AGED 12-55
	- 02 - GET ALL ICD-9 DIAGNOSIS CODES
	- 03 - GET ALL ICD-10 DIAGNOSIS CODES
	- 04 - GET ALL PROCEDURE CODES
	- 05 - GET ALL MIFEPRISTONE AND MISOPROSTOL FILLS
	- 06 - CREATE ENC_KEY VARIABLE

************************************************************************************************/








/***************************************************************************************************************

											00 - SET LIBRARIES

****************************************************************************************************************/


/*run this locally if you need to log onto the N2 server.*/
/*SIGNOFF;*/
/*%LET server=n2.schsr.unc.edu 1234; */
/*options comamid=tcp remote=server; */
/*signon username=_prompt_;*/


*Run setup macro and define libnames;
options sasautos=(SASAUTOS "/local/projects/marketscan_preg/raw_data/programs/macros");
/*change "saveLog=" to "Y" when program is closer to complete*/
%setup(sample= random1pct, programname=Step00_create_data_files, savelog=N);

options mprint;

/*Create local mirrors of the server libraries*/
/*libname lout slibref=out server=server;*/
/*libname lwork slibref = work server = server;*/
/*libname lcovref slibref = covref server = server;*/
/*libname lder slibref = der server=server;*/
/*libname lraw slibref = raw server=server;*/
/*libname ltemp slibref = temp server=server;*/

*Specify all of the years that we want to get raw claim data from;
%let years = 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2023;
%let years_icd10 = 2015 2016 2017 2018 2019 2020 2021 2022 2023 2023; *Specify only those years in the ICD-10 era;










/***************************************************************************************************************

								01 - CREATE DATASET OF ALL FEMALES AGED 12-55

****************************************************************************************************************/


*Go through all monthly enrollment files and grab all periods of continuous enrollment where individuals were
identified as female between the age of 12 and 55;

*Create a table to append to;
proc sql;
	create table female
		(enrolid num format=best12.,
		dtstart num format=MMDDYY10.,
		dtend num format=MMDDYY10.);
		quit;

%macro get_enrl();

	%let numYr = %sysfunc(countw(&years));
	
	%*Apply this loop for each year-s file;
	%do d=1 %to &numYr;

		%let loop&d = %scan(&years, &d);

		%*Grab all monthly enrollment files that meet eligibility criteria.;
		proc sql;
			create table female_sub as
			select distinct enrolid, DTSTART, DTEND
			from raw.enrdet&&loop&d
			where sex = '2' and 12 <= age <= 55
			;
			quit;

		proc append base=female data=female_sub; run;
	%end;
		

%mend;

%get_enrl;



*Now derive the start and end dates of continuous enrollment windows so
that the dataset is smaller.;
proc sort data=female;
	by enrolid dtstart;
run;
*First carry down information from the last month of continuous enrollment;
data female_enrl;
set female;
	format last_dt MMDDYY10.;
	last_id = lag1(enrolid);
	last_dt = lag1(dtend);

	days_elapsed = dtstart - last_dt;
run;

*Create a variable - cnt_per - that represents a continuous enrollment period;
data female_enrl2; 
set female_enrl;
	by enrolid dtstart;
	retain cnt_per;

	if first.enrolid then cnt_per = 1;

	if enrolid = last_id and days_elapsed ne 1 then cnt_per = cnt_per + 1;
run;

*Output one row per continuous enrollment period;
data temp.female_enrl;
set female_enrl2;
	format cont_start MMDDYY10. cont_end MMDDYY10.;
	by enrolid cnt_per dtstart ;
	retain cont_start;

	if first.cnt_per then cont_start = dtstart;

	if last.cnt_per then do;
		cont_end = dtend;
		output; *Only output the last row of the continuous enrollment period that carried down start date to.;
	end;

	keep enrolid cont_start cont_end;
run;

*Delete dataset to minimize working memory usage;
proc datasets gennum=all;
	delete female:;
run; 
quit; 
run;	

	


	











/***************************************************************************************************************

									02 - GET ALL ICD-9 DIAGNOSIS CODES

Get all instances of ICD-9 diagnosis codes where the code is contained in our prenatal, outcome, or gestational
age code list.

****************************************************************************************************************/

*****
Get all of the relevant diagnosis codes for icd-9 era;

*Stack all of the ICD-9 diagnosis codes;
proc sql;
	create table all_dx9 as
	select code, code_typeb as Code_Type, description
	from covref.prenatal_cdwh
	where code_typeb = "dx9" /*"ICD-9 DX"*/
	union corr
	select code, code_typeb as code_type, description
	from covref.preg_outcomes_cdwh
	where code_typeb = "dx9" /*"ICD-9 DX"*/
	union corr
	select code, code_typeb as code_type, description
	from covref.gestage_cdwh
	where code_typeb = "dx9" /*"ICD-9 DX"*/
	;
	quit;
*Remove the . from the code variable;
data all_dx9;
set all_dx9;
	code = compress(code, '.');
run;
	



%macro get_dx9();

	/*Calculate the number of years*/
	%let numYr = %sysfunc(countw(&years));
	
	/*Apply this loop for each year-s file*/
	%do d=1 %to &numYr;

		%let loop&d = %scan(&years, &d);

		proc sql;
			%if &d = 1 %then %do;
				create table temp.dx9 as 
			%end;
			%else %do;
				insert into temp.dx9
			%end;
			select distinct ENROLID, CASEID, svcdate, tsvcdat, dxLoc as claimLocation, code, code_type, description
			from 
				%if %eval(&&loop&d > 2014 and &&loop&d < 2023) %then %do; /*For those after ICD 9 to 10 transition*/
	                (select aa.*
					from der.alldx9&&loop&d as aa
					right join temp.female_enrl as bb
					on aa.enrolid = bb.enrolid and bb.cont_start <= aa.svcdate <= bb.cont_end) /*Only want those codes in qualifying cont enrollment period*/
	            %end;
	            %else %do;
	                (select aa.*
					from der.alldx&&loop&d as aa
					right join temp.female_enrl as bb
					on aa.enrolid = bb.enrolid and bb.cont_start <= aa.svcdate <= bb.cont_end)
	            %end;
				 as a
			inner join all_dx9 as b
			on upcase(a.dx&&loop&d) = upcase(b.code)
			;
			quit;

		
	%end;

%mend;

%get_dx9();
















/***************************************************************************************************************

									03 - GET ALL ICD-10 DIAGNOSIS CODES

Get all instances of ICD-10 diagnosis codes where the code is contained in our prenatal, outcome, or gestational
age code list.

****************************************************************************************************************/

*****
Get all of the relevant diagnosis codes for icd-10 era;

*Stack all of the ICD-10 diagnosis codes and remove the .;
proc sql;
	create table all_dx10 as
	select code, code_typeb as code_type, description
	from covref.prenatal_cdwh
	where code_typeb = "dx10" /*"ICD-10 DX"*/
	union
	select code, code_typeb as code_type, description
	from covref.preg_outcomes_cdwh
	where code_typeb = "dx10" /*"ICD-10 DX"*/
	union
	select code, code_typeb as code_type, description
	from covref.gestage_cdwh
	where code_typeb = "dx10" /*"ICD-10 DX"*/
	;
	quit;
*Remove the . from the code variable;
data all_dx10;
set all_dx10;
	code = compress(code, '.');
run;


%macro get_dx10();

	/*Calculate the number of years*/
	%let numYr = %sysfunc(countw(&years_icd10));
	
	/*Apply this loop for each year-s file*/
	%do d=1 %to &numYr;

		%let loop&d = %scan(&years_icd10, &d);

		proc sql;
			%if &d = 1 %then %do;
				create table temp.dx10 as 
			%end;
			%else %do;
				insert into temp.dx10
			%end;
			select distinct ENROLID, CASEID, svcdate, tsvcdat, dxLoc as claimLocation, code, code_type, description
			from 
				%if %eval(&&loop&d = 2015 or &&loop&d = 2016) %then %do;
	                (select aa.*
					from der.alldx10&&loop&d as aa
					right join temp.female_enrl as bb
					on aa.enrolid = bb.enrolid and bb.cont_start <= aa.svcdate <= bb.cont_end)
	            %end;
	            %else %do;
	                (select aa.*
					from der.alldx&&loop&d as aa
					right join temp.female_enrl as bb
					on aa.enrolid = bb.enrolid and bb.cont_start <= aa.svcdate <= bb.cont_end)
	            %end;
				 as a
			inner join all_dx10 as b
			on upcase(a.dx&&loop&d) = upcase(b.code)
			;
			quit;
	%end;

%mend;

%get_dx10();











/***************************************************************************************************************

										04 - GET ALL PROCEDURE CODES

****************************************************************************************************************/

*****
Create a reference file for all the procedure codes;

proc sql;
	create table all_proc as
	select code, code_typeb as Code_Type, description
	from covref.prenatal_cdwh
/*	where Code_Type in ("CPT", "HCPCS", "ICD-10 PX", "ICD-9 PX")*/
	where code_typeb in ("cpt" "pr9" "pr10")
	union corr
	select code, code_typeb as code_type, description
	from covref.preg_outcomes_cdwh
/*	where Code_Type in ("CPT", "HCPCS", "ICD-10 PX", "ICD-9 PX")*/
	where code_typeb in ("cpt" "pr9" "pr10")	
	union corr
	select code, code_typeb as code_type, description
	from covref.gestage_cdwh
/*	where Code_Type in ("CPT", "HCPCS", "ICD-10 PX", "ICD-9 PX")*/
	where code_typeb in ("cpt" "pr9" "pr10")
	;
	quit;
*Remove the . from the code variable;
data all_proc;
set all_proc;
	code = compress(code, '.');
run;



%macro get_proc();

	/*Calculate the number of years*/
	%let numYr = %sysfunc(countw(&years));
	
	/*Apply this loop for each year-s file*/
	%do d=1 %to &numYr;

		%let loop&d = %scan(&years, &d);

		proc sql;
			%if &d = 1 %then %do;
				create table temp.proc as 
			%end;
			%else %do;
				insert into temp.proc
			%end;
			select distinct ENROLID, CASEID, svcdate, tsvcdat, procLoc as claimLocation, code, code_type, description
			from (select aa.*
					from der.allproc&&loop&d as aa 
					right join temp.female_enrl as bb
					on aa.enrolid = bb.enrolid and bb.cont_start <= aa.svcdate <= bb.cont_end) as a
			inner join all_proc as b
			on upcase(a.proc&&loop&d) = upcase(b.code)
			;
			quit;
	%end;

%mend;

%get_proc();

/*proc freq data=temp.proc;*/
/*	table claimLocation / missing;*/
/*run;*/











/***************************************************************************************************************

								05 - GET ALL MIFEPRISTONE AND MISOPROSTOL FILLS

****************************************************************************************************************/

*Put all of the mifepristone and misoprostol NDCs together.;
data meds;
set covref.mifepristone_ndc covref.misoprostol_ndc;
	outcome = "Unspecified Abortion";
run;


*Now, grab all the claims with one of those NDCs;

%macro get_med();

	%*Calculate the number of years;
	%let numYr = %sysfunc(countw(&years));
	
	%*Apply this loop for each year-s file;
	%do d=1 %to &numYr;

		%let loop&d = %scan(&years, &d);

		proc sql;
			%if &d = 1 %then %do;
				create table temp.med as 
			%end;
			%else %do;
				insert into temp.med
			%end;
			select distinct a.ENROLID, a.svcdate, a.pddate, a.ndcnum9,
						a.daysupp, a.metqty, a.refill, b.*
			from (select aa.*, substr(aa.ndcnum, 1, 9) as ndcnum9
				  	from raw.outptdrug&&loop&d as aa
					right join temp.female_enrl as bb
					on aa.enrolid = bb.enrolid and bb.cont_start <= aa.svcdate <= bb.cont_end) as a
			inner join meds as b
			on a.ndcnum9 = substr(b.ndcnum, 1, 9)
			;
			quit;
			%*Match on NDC-9 not -11. Ensures that we capture any different packagings;
	%end;

%mend;


%get_med();



/**Confirm that get the same results but more rows with Redbook;*/
/**This macro was created when we used the ATC codes to define medications;*/
/*%macro get_med();*/
/**/
/*	/*Calculate the number of years*/*/
/*	%let numYr = %sysfunc(countw(&years));*/
/*	*/
/*	/*Apply this loop for each year-s file*/*/
/*	%do d=1 %to &numYr;*/
/**/
/*		%let loop&d = %scan(&years, &d);*/
/**/
/*		proc sql;*/
/*			%if &d = 1 %then %do;*/
/*				create table temp.med_atc as */
/*			%end;*/
/*			%else %do;*/
/*				insert into temp.med_atc*/
/*			%end;*/
/*			select distinct a.ENROLID, a.svcdate, a.pddate, a.ndcnum,*/
/*						a.daysupp, a.metqty, a.refill, b.**/
/*			from (select aa.*, substr(aa.ndcnum, 1, 9) as ndcnum9*/
/*				  	from raw.outptdrug&&loop&d as aa*/
/*					right join temp.female_enrl as bb*/
/*					on aa.enrolid = bb.enrolid and bb.cont_start <= aa.svcdate <= bb.cont_end) as a*/
/*			inner join meds as b*/
/*			on a.ndcnum9 = b.ndc9*/
/*			/*Match on NDC-9 not -11. Ensures that we capture any different packagings*/*/
/*			;*/
/*			quit;*/
/*	%end;*/
/**/
/*%mend;*/
/*;;*/
/**/
/*%get_med();*/

/*proc contents data=temp.med_atc;*/
/*run;*/
/*proc contents data=temp.med;*/
/*run;*/


/**General descriptives;*/
/**/
/**See what rows were missed by using the ATC values compared to the Redbook values;*/
/*proc sql;*/
/*	create table test_redbook as*/
/*	select a.*, missing(b.ndcnum) as atc_missing*/
/*	from temp.med as a*/
/*	left join temp.med_atc as b*/
/*	on a.enrolid = b.enrolid and a.svcdate = b.svcdate and a.ndcnum = b.ndcnum*/
/*	;*/
/*	quit;*/
/**/
/*proc freq data=test_redbook;*/
/*	table atc_missing / missing;*/
/*run; *7414 missing atc_missing;*/
/**/
/**See what rows were missing by using the Redbook values compared to teh ATC values;*/
/*proc sql;*/
/*	create table test_atc as*/
/*	select a.*, missing(b.ndcnum) as red_missing*/
/*	from temp.med_atc as a*/
/*	left join temp.med as b*/
/*	on a.enrolid = b.enrolid and a.svcdate = b.svcdate and a.ndcnum = b.ndcnum*/
/*	;*/
/*	quit;*/
/**/
/*proc freq data=test_atc;*/
/*	table red_missing / missing;*/
/*run; *None missing -- Stick with teh REdbook codes;*/






/*Some information to understand potential issues.*/

*How long are inpatient admissions? Are we causing potential issues by using the admission
start and end date for the DX codes?;
/*proc sql;*/
/*	create table dx10_dates as*/
/*	select distinct enrolid, svcdate, tsvcdat*/
/*	from temp.Dx10*/
/*	where claimLocation = "Inpt"*/
/*	;*/
/*	quit;*/

*Calculate the length of time between admission start and end dates;
/*data dx10_dates2;*/
/*set dx10_dates;*/
/*	if tsvcdat = . then tsvcdat = svcdate;*/
/*		else tsvcdat = tsvcdat;*/
/*	elapsed = tsvcdat - svcdate;*/
/*run;*/
/**/
/*proc means data=dx10_dates2 min p25 median p75 max nmiss;*/
/*	var elapsed;*/
/*run;*/
/**/
/*data dx10_dates_sub;*/
/*set dx10_dates2;*/
/*	where elapsed >4;*/
/*run;*/
/*proc freq data=dx10_dates_sub;*/
/*	table elapsed;*/
/*run;*/
/***85 percent have <= 10 day admission lengths. Maybe ask about;*/






/*Are there any diagnosis codes from the admissions that are not showing up on the inpatient service claim?*/
/*proc sql;*/
/*	create table investigate_dx as*/
/*	select **/
/*	from der.alldx2018*/
/*	where dxLoc ne "OutptServ"*/
/*	;*/
/*	quit;*/
/**/
/**Create a datafile with all distinct inpt service codes and inpt dx codes;*/
/*proc sql;*/
/*	create table inpt_serv as*/
/*	select distinct enrolid, caseid, svcdate, tsvcdat, dx2018, dxLoc*/
/*	from investigate_dx*/
/*	where dxLoc = "InptServ"*/
/*	;*/
/**/
/*	create table inpt_adm as*/
/*	select distinct enrolid, caseid, svcdate, tsvcdat, dx2018, dxLoc*/
/*	from investigate_dx*/
/*	where dxLoc = "InptAdm"*/
/*	;*/
/*	quit;*/
/**/
/**/
/**Now, see if there are any inpatient admission codes not represented*/
/*	by the inpatient service claims;*/
/*proc sql;*/
/*	create table test as */
/*	select coalesce(a.enrolid, b.enrolid) as enrolid,*/
/*		coalesce(a.caseid, b.caseid) as caseid,*/
/*		coalesce(a.svcdate, b.svcdate) as svcdate,*/
/*		coalesce(a.tsvcdat, b.tsvcdat) as tsvcdat,*/
/*		coalesce(a.dx2018, b.dx2018) as dx2018,*/
/*		a.dxLoc, b.dxLoc as dxAdm*/
/*	from inpt_serv a*/
/*	full join inpt_adm b*/
/*	on a.enrolid = b.enrolid and a.caseid = b.caseid and a.dx2018 = b.dx2018*/
/*	;*/
/*	quit;*/
/*	*Some only have codes from inpatient admissions or inpatient services, not both;*/











/*Are there any procedure codes from the admissions that are not showing up on the inpatient service claim?*/
/*proc sql;*/
/*	create table investigate_pr as*/
/*	select **/
/*	from der.allproc2018*/
/*	where procLoc ne "OutptServ"*/
/*	;*/
/*	quit;*/
/**/
/**Create a datafile with all distinct inpt service codes and inpt dx codes;*/
/*proc sql;*/
/*	create table inpt_serv_pr as*/
/*	select distinct enrolid, caseid, svcdate, tsvcdat, proc2018, procLoc*/
/*	from investigate_pr*/
/*	where procLoc = "InptServ"*/
/*	;*/
/**/
/*	create table inpt_adm_pr as*/
/*	select distinct enrolid, caseid, svcdate, tsvcdat, proc2018, procLoc*/
/*	from investigate_pr*/
/*	where procLoc = "InptAdm"*/
/*	;*/
/*	quit;*/
/**/
/**/
/**Now, see if there are any inpatient admission codes not represented*/
/*	by the inpatient service claims;*/
/*proc sql;*/
/*	create table test_pr as */
/*	select coalesce(a.enrolid, b.enrolid) as enrolid,*/
/*		coalesce(a.caseid, b.caseid) as caseid,*/
/*		coalesce(a.svcdate, b.svcdate) as svcdate,*/
/*		coalesce(a.tsvcdat, b.tsvcdat) as tsvcdat,*/
/*		coalesce(a.proc2018, b.proc2018) as proc2018,*/
/*		a.procLoc, b.procLoc as procAdm*/
/*	from inpt_serv_pr a*/
/*	full join inpt_adm_pr b*/
/*	on a.enrolid = b.enrolid and a.caseid = b.caseid and a.proc2018 = b.proc2018*/
/*	;*/
/*	quit;*/
/**/
/*proc freq data=test_pr;*/
/*	table procLoc / missing;*/
/*run;*/
/*	*Some only have codes from inpatient admissions or inpatient services, not both;*/
;;;
