/*
************************************************************************************************;          
**** program: Quality Check.sas                                        			            ****;
**** purpose: Conduct quality control checks of the final pregnancy datasets                   *;
***                                                                                            *;
************************************************************************************************;          






/***********************************************************************************************

TABLE OF CONTENTS:
	00 - SET LIBRARIES, ETC.
	01 - DESCRIBE VARIABLES IN DATASET
	02 - INVESTIGATE PREGNANCY COUNTS ACROSS SIMPLE AND COMPLEX STEP 8

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
%setup(sample= full, programname=Step00_create_data_files, savelog=N);

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

								01 - DESCRIBE VARIABLES IN DATASET

***********************************************************************************************/




*SEE ALL THE VARIABLE NAMES;
proc contents data=out.pregnancy_lmp_simp_all;
run;

proc freq data=out.pregnancy_lmp_simp_all;
	table algorithm / missing;
run;
*No missing on algorithm - good. Going to subset to one to review.;


*Confirm if there is any weird missingness;
proc sql;
	select sum(Idxpren = .) as missing_preg_id
	from out.pregnancy_lmp_simp_all;
	quit;
	*None missing - good;

data test;
set out.pregnancy_lmp_simp_all;

	index_dt_missing = (DT_INDEXPRENATAL = .);
	outcome_dt_missing = (Dt_Preg_Outcome = .);
	first_pnc_equal = (DT_INDEXPRENATAL = Dt_PrenEnc1st);

run;
proc sort data=test;
	by preg_outcome_clean;
run;
proc freq data=test;
	tables index_dt_missing * outconly / missing;
	tables outcome_dt_missing * prenonly / missing;
	tables first_pnc_equal / missing;
run;
*All looks good;








/*Simple Algorithm*/


ods rtf file = "&algpath./Simple Pregnancies QC_%sysfunc(date(),yymmddn8.).rtf" style=minimal;

proc sort data=out.pregnancy_lmp_simp_all out=pregnancies;
	by algorithm;
run;

/*Create classes dataset*/
proc sql;
	create table classes as
	select distinct algorithm
	from pregnancies
	;
	quit;

title "Counts by Algorithm" ;
proc freq data=pregnancies;
	table algorithm / missing;
run;

title "Pregnancy Outcomes by Algorithm";
proc freq data=pregnancies;
	by algorithm;
	table PREG_OUTCOME_Clean / missing;
run;

title "Pregnancy Outcome/LTFU Date";
proc tabulate data=pregnancies classdata=classes exclusive;
	class algorithm;
	var DT_GAPreg;
	table algorithm*DT_GAPreg, n nmiss (min q1 median q3 max)*f=mmddyy10. range;
run;

title "Pregnancy LMP Date";
proc tabulate data=pregnancies classdata=classes exclusive;
	class algorithm;
	var Dt_LMP;
	table algorithm*Dt_LMP, n nmiss (min q1 median q3 max)*f=mmddyy10. range;
run;

title "Pregnancy Index Date";
proc tabulate data=pregnancies classdata=classes exclusive;
	class algorithm;
	var DT_INDEXPRENATAL;
	table algorithm*DT_INDEXPRENATAL, n nmiss (min q1 median q3 max)*f=mmddyy10. range;
run;

title "Indicator for a GA encounter within the pregnancy";
proc freq data=pregnancies;
	table Any_GA_PrenatalWindow / missing;
run;

title "Distribution of prenatal encounter dates";
proc tabulate data=pregnancies classdata=classes exclusive;
	class algorithm;
	var Dt_PrenEnc1st Dt_PrenEncLast;
	table algorithm*Dt_PrenEnc1st, n nmiss (min q1 median q3 max)*f=mmddyy10. range;
	table algorithm*Dt_PrenEncLast, n nmiss (min q1 median q3 max)*f=mmddyy10. range;
run;


title "Indicator for mife/miso being in the pregnancy outcome groups";
proc freq data=pregnancies;
	by  algorithm;
	table PREG_MIFE PREG_MISO / missing;
run;

title "Number of pregnancy outcome groups in pregnancy";
proc freq data=pregnancies;
	by algorithm;
	table PREG_OutcomeCount / missing;
run;

title "Number of pregnancies with missing IDs";
proc sql;
	select algorithm, sum(ind) as missing_preg_id
	from (select algorithm, case when Idxpren = . then 1 else 0 end as ind
			from pregnancies)
	group by algorithm
	;
	quit;

title "Number of outcome and prenatal only pregnancies";
proc sql;
	select algorithm, sum(outconly) as num_outcome_only_pregnancies,
			sum(prenonly) as num_prenatal_only_pregnancies
	from pregnancies
	group by algorithm
	;
	quit;

ods rtf close;


*No mife orders here. Look and see if that caused issues.;
proc freq data=pregnancies;
	where preg_outcome_clean ne 'UNK';
	table PREG_OutcomeCodetypesCompared / missing;
run;
*Do not see any weird values. Think that it is fine. Just led to missing values for preg_mife and preg_miso;




*identify the pregnancies from 30-day outcome window adn outcome algorithm 3;
data pregnancies;
set out.pregnancy_lmp_simp_all;
	where algorithm = '30-3';

	*Calculate gestational length;
	GA_length = dt_GApreg - dt_LMP;
run;
proc sort data=pregnancies;
	by preg_outcome_clean;
run;

ods rtf file = "&algpath./Simple Pregnancies QC_Algorithm 30-3_%sysfunc(date(),yymmddn8.).rtf" style=minimal;

title1 "Distribution of pregnancy outcomes";
proc freq data=pregnancies;
	table preg_outcome_clean / missing;
run;

*Look at proportion of outcomes among pregnancies with observed outcomes;
title1 "Distribution of pregnancy outcomes among pregnancies with observed outcomes";
proc freq data=pregnancies (where = (preg_outcome_clean ne "UNK"));
	table preg_outcome_clean / missing;
run;

*Look at proportion of outcomes among deliveries;
title1 "Distribution of delivery outcomes among pregnancies with delivery outcomes";
proc freq data=pregnancies (where = (preg_outcome_clean in ('SB' 'LBS' 'UDL' 'LBM')));
	table preg_outcome_clean / missing;
run;

title1 "Distribution of gestational length by pregnancy outcomes";
proc freq data=pregnancies;
	by preg_outcome_clean;
	table GA_length / missing;
run;

ods rtf close;

*Some weird outliers, but those can be dealt with in the study phase.;






