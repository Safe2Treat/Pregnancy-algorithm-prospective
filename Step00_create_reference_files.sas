/***********************************************************************************************     
PROGRAM: Step00_create_reference_files.sas 
PROGRAMMER: Chase Latour

PURPOSE: Create SAS data files with the necessary reference code lists
***                                                                           
NOTES:

MODIFICATIONS:
************************************************************************************************          
*/

/************************************************************************************************

TABLE OF CONTENTS:
	- 00 - SET LIBRARIES
	- 01 - IMPORT EXCEL SHEETS AND MAKE RELEVANT SAS DATASETS

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
%setup(sample= full, programname=/cdwh_algorithm/Step00_create_reference_files, savelog=Y);
libname atc '/nearline/files/datasources/references/Code Reference Sets/Drugs';


options mprint;

/*Create local mirrors of the server libraries*/
/*libname lout slibref=out server=server;*/
/*libname lwork slibref = work server = server;*/
/*libname lcovref slibref = covref server = server;*/
/*libname lder slibref = der server=server;*/
/*libname lraw slibref = raw server=server;*/
/*libname latc slibref = atc server=server;*/
/*libname lred slibref = red server=server;*/







/***************************************************************************************************************

							01 - IMPORT EXCEL SHEETS AND MAKE RELEVANT SAS DATASETS

***************************************************************************************************************/

*Prenatal encounter codes;
proc import datafile='/local/projects/marketscan_preg/raw_data/programs/cdwh_algorithm/Variable Identification.xlsx'
	dbms = xlsx
	out = covref.prenatal_cdwh
	replace;
	sheet = "PRENATAL";
run;
*Clean the dataset;
data covref.prenatal_cdwh;
set covref.prenatal_cdwh;
	where code ne "";
	if code_type in ('ICD-10 DX' 'ICD10 ZCode') then code_typeb='dx10';
     	else if code_type in ('ICD-9 DX') then code_typeb='dx9';
     	else if code_type in ('ICD-10 PX') then code_typeb='pr10';
     	else if code_type in ('ICD-9 PX') then code_typeb='pr9';
     	else if code_type in ('CPT' 'HCPCS' 'Proc CPT' 'Proc HCPCS') then code_typeb='cpt';
	code = compress(code, '.');

	*Remove any standard or non-breaking spaces from the codes - CDL: ADDED 3.25.2025;
	code = compress(code, cats(byte(32), byte(160)));
run;

/*Make sure all assigned*/
/*proc freq data=covref.prenatal_cdwh;*/
/*	table code_type*code_typeb / missing;*/
/*run;*/



*Pregnancy outcome codes;
proc import datafile='/local/projects/marketscan_preg/raw_data/programs/cdwh_algorithm/Variable Identification.xlsx'
	dbms = xlsx
	out = covref.preg_outcomes_cdwh
	replace;
	sheet = "PREG_OUTCOMES";
run;
*Clean the dataset;
data covref.preg_outcomes_cdwh;
set covref.preg_outcomes_cdwh;
	where code ne "";
	if code_type in ('ICD-10 DX' 'ICD10 ZCode') then code_typeb='dx10';
	     else if code_type in ('ICD-9 DX') then code_typeb='dx9';
	     else if code_type in ('ICD-10 PX') then code_typeb='pr10';
	     else if code_type in ('ICD-9 PX') then code_typeb='pr9';
	     else if code_type in ('CPT' 'HCPCS' 'Proc CPT' 'Proc HCPCS') then code_typeb='cpt';
	code = compress(code, '.');
	*Remove any standard or non-breaking spaces from the codes;
	code = compress(code, cats(byte(32), byte(160)));
run;

/*Make sure all assigned*/
/*proc freq data=covref.preg_outcomes_cdwh;*/
/*	table code_type*code_typeb / missing;*/
/*run;*/


*Gestational age codes;
proc import datafile='/local/projects/marketscan_preg/raw_data/programs/cdwh_algorithm/Variable Identification.xlsx'
	dbms = xlsx
	out = covref.gestage_cdwh
	replace;
	sheet = "GEST_AGE";
run;
*Clean the dataset;
data covref.gestage_cdwh;
set covref.gestage_cdwh;
	where code ne "";
	if code_type in ('ICD-10 Dx' 'ICD10 ZCode') then code_typeb='dx10';
	     else if code_type in ('ICD-9 Dx') then code_typeb='dx9';
	     else if code_type in ('CPT' 'HCPCS' 'Proc CPT' 'Proc HCPCS') then code_typeb='cpt';
		 else if code_type in ('ICD-10 Px') then code_typeb='pr10';
		 else if code_type in ('ICD-9 Px') then code_typeb='pr9';
	code = compress(code, '.');
	*Remove any standard or non-breaking spaces from the codes;
	code = compress(code, cats(byte(32), byte(160)));
run;

/*Make sure all assigned*/
/*proc freq data=covref.gestage_cdwh;*/
/*	table code_type*code_typeb / missing;*/
/*run;*/




*Mifepristone and misoprostol;

*Get NDC information from RedBook;

**Mifepristone;
data covref.mifepristone_ndc;
set red.redbook;
	if find(upcase(GENNME), 'MIFEPRISTONE', 'i') > 0;
run;

**Misoprostol;
data misoprostol;
set red.redbook;
	if find(upcase(GENNME), 'MISOPROSTOL', 'i') > 0; *Subset to those that contain misoprostol;
run;

*Modify to the list that we think we want;
data covref.misoprostol_ndc;
set misoprostol;
	if find(upcase(GENNME), 'DICLOFENAC','i') > 0 then delete;
	where MSTFMDS = "Tablet";
run;











/***********************************************************
Test which provides claims that we want ATC-based or Redbook-
based NDC code search. If similar results, will go with the
ATC-based.
************************************************************/

/**Code to get NDC codes from First Data Bank ATC to NDC mapping;*/
/**/
/*%macro getndc(class, atc);*/
/*   proc sort data=&class._name; by drugName; run;*/
/*   proc sql noprint; */
/*      select distinct drugName into :drug1-:drug100 from &class._name;*/
/*      %LET NumDrug = &SqlObs; */
/**/
/*      select distinct atc into :atc1-:atc100 from &class._name;*/
/*      %LET NumATC = &SqlObs;*/
/*   quit;*/
/**/
/*   proc sql;*/
/*      create table covref.&class._ndc(where=(ndc11 ne '')) as*/
/*      select case when a.drugName ne '' then a.drugName */
/*         %DO i=1 %TO &numDrug; */
/*            when index(upcase(drug_name),"&&drug&i") or index(upcase(atc_label),"&&drug&i") then "&&drug&i"*/
/*         %END; end as drug, b.**/
/*      from &class._name as a */
/*       full join atc.atc_ndc(where=(atc in: (&atc) or*/
/*           %DO i=1 %TO &numDrug; */
/*                index(upcase(drug_name),"&&drug&i") or index(upcase(atc_label),"&&drug&i") or %END;*/
/*           %IF &numATC > 0 %THEN %DO; %DO i=1 %TO &numATC;*/
/*                 atc=:"&&atc&i" %IF &i<&numATC %THEN or ; %END; %END;)) as b*/
/*       on a.atc = b.atc*/
/*       order by drug, ndc11;*/
/*   quit;*/
/*%mend;*/
/**/
/*data mifepristone_name;*/
/*length drugName $70 atc $7;*/
/*input drugName $ atc $;*/
/*	cards;*/
/*	MIFEPRISTONE G03XB01*/
/*	MIFEPRISTONE G03XB51*/
/*	;*/
/*run;*/
/**/
/*%getndc(class=mifepristone, atc=%STR('G03XB01','G03XB51'));*/
/**/
/**/
/*data misoprostol_name;*/
/*length drugName $70 atc $7;*/
/*input drugName $ atc $;*/
/*	cards;*/
/*	MISOPROSTOL A02BB01*/
/*	MISOPROSTOL G02AD06*/
/*;*/
/*run;*/
/**/
/*%getndc(class=misoprostol, atc=%STR('A02BB01','G02AD06'));*/
/**/
/**Subset to those that are tablet formulations (no dicloflenac);*/
/*data covref.misoprostol_ndc;*/
/*set covref.misoprostol_ndc;*/
/*	where form = "tablet";*/
/*run;*/
/**/



/**/

/**Instead, try getting the NDCs from Redbook;*/
/*data miso_red;*/
/*set red.redbook;*/
/*	if find(upcase(GENNME), 'MISOPROSTOL', 'i') > 0; *Subset to those that contain misoprostol;*/
/*run;*/
/**/
/**Modify to the list that we think we want;*/
/*data miso_red2;*/
/*set miso_red;*/
/*	where GENNME = "Misoprostol" and MSTFMDS = "Tablet";*/
/*run; */
/**/
/**Figure out which NDCs are not shared across the two;*/
/*proc sql;*/
/*	create table red_only as */
/*	select distinct missing(a.ndc11) as not_atc, b.ndcnum, b.STRNGTH, b.THRDTDS, b.MSTFMDS, b.PRODNME, b.GENNME, b.roads*/
/*	from covref.misoprostol_ndc as a*/
/*	right join miso_red as b*/
/*	on a.ndc11 = b.ndcnum*/
/*	having not_atc = 1*/
/*	;*/
/*	quit;*/
/**/
/*proc sort data=atc_ndc;	by ndc11; run;*/
/*proc sort data=red_ndc; by ndcnum; run;*/
/**/
/*proc compare base=atc_ndc compare=red_ndc;*/
/*run;*/
/**/
/**Now look at which claims you pull;*/
/**/
/**/
/*%let years = 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022;*/
/**/
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
/*				create table temp_med as */
/*			%end;*/
/*			%else %do;*/
/*				insert into temp_med*/
/*			%end;*/
/*			select distinct a.ENROLID, a.svcdate, a.pddate, a.ndcnum, a.daysupp, */
/*						a.metqty, a.refill, */
/*						coalesce(b.drug_name, c.GENNME) as drug_name,*/
/*						coalesce(b.STRENGTH, c.STRNGTH) as strength,*/
/*						missing(b.ndc9) as atc_missing,*/
/*						missing(c.ndcnum) as red_missing,*/
/*						b.ndc11 as atc_ndc,*/
/*						c.ndcnum as red_ndc*/
/*			from (select aa.*, substr(aa.ndcnum, 1, 9) as ndcnum9*/
/*				  	from raw.outptdrug&&loop&d as aa*/
/*					right join temp.female_enrl as bb*/
/*					on aa.enrolid = bb.enrolid and bb.cont_start <= aa.svcdate <= bb.cont_end) as a*/
/*			left join covref.misoprostol_ndc as b*/
/*			on a.ndcnum9 = b.ndc9 */
/*			left join miso_red2 as c*/
/*			on a.ndcnum9 = substr(c.NDCNUM,1,9)*/
/*			/*Match on NDC-9 not -11. Ensures that we capture any different packagings that were not on ATC from First Data Bank*/*/
/*			;*/
/*			quit;*/
/*	%end;*/
/**/
/*%mend;*/
/**/
/*%get_med();*/
/**/
/**/
/**Subset;*/
/*data one_miso;*/
/*set temp_med;*/
/*	where atc_ndc ne "" or red_ndc ne "";*/
/**/
/*	if atc_ndc = "" then atc_missing2 = 1;*/
/*		else atc_missing2 = 0;*/
/*	if red_ndc - "" then red_missign2 = 1;*/
/*		else red_missing2 = 0;*/
/*run;*/
/**/
/*proc freq data=one_miso;*/
/*	table red_missing2 * atc_missing2;*/
/*run;*/
/**/
/**Look at those where the atc is missing;*/
/*data test;*/
/*set one_miso;*/
/*	where atc_missing2 = 1;*/
/*run;*/
/**/
/**All First Data Bank codes plus some additional NDC codes are captured by Redbook. Using REdbook-derived NDC codes;*/
