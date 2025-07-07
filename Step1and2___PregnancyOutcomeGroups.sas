/******************************************************************************

Program: chase_Step1and2_PregnancyOutcomeGroups.sas
    (used chase_1a_ConcordanceAndSharedFormatStatements.sas as base and added
     call to chase_1a_createoutcomegroups, kept calls to separate algorithms);

Programmer: Sharon 

Purpose: Program pregnancy outcomes table steps 1a-1b8 of pregnancy algorithm, 
         calling programs that apply different steps
         Formats shared by all outcome algorithms and macros for shared
         datasteps, including Concordant Outcomes

NOTE: Prior to running this code, be sure that you have commented in or out 
the algorithm version that you would like to implement.

MODIFICATIONS:
	-	05.2025 - CDL reformatted and annotated. Conducted QC and reviewed
		with SPH. All modifications were approved by both.

    - 08.5.24 sph point to library setup file;
*******************************************************************************/





/*****************************************************************************

TABLE OF CONTENTS:

	- 00 - SPECIFY OPTIONS, ETC.
	- 01 - CALL FORMATS
	- 02 - GET THE OUTCOMES SOURCE DATAFILES
	- 03 - STEP 1a - Group outcome encounters w/in +/- [EncGap] days
	- 04 - STEP 1b.1 - Assigns concordant outcomes per table 1
	- 05 - RUN PREG OUTCOME ALGORITHMS 1-4
	- 06 - ASSIGN OUTCOME DATES BASED ON FINDINGS OF ALGORITHMS
	- 07 - COMBINE THE RESULTS FROM STEPS 1 AND 2 INTO THE SAME DATASET

******************************************************************************/










/*****************************************************************************

						00 - SPECIFY OPTIONS, ETC.

This will need to be changed if implemented in a different folder.

******************************************************************************/

/*run this locally if you need to log onto the N2 server.*/
/*SIGNOFF;*/
/*%LET server=n2.schsr.unc.edu 1234; */
/*options comamid=tcp remote=server; */
/*signon username=_prompt_;*/

*Run setup macro and define libnames;
options sasautos=(SASAUTOS "/local/projects/marketscan_preg/raw_data/programs/macros");
/*change "saveLog=" to "Y" when program is closer to complete*/
%setup(sample= full, programname=Step1and2___PregnancyOutcomeGroups, savelog=Y);

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

%put &algpath.;

%inc "&algpath./FormatStatements.sas";

*If you want to see the datasets on the local instance of SAS, you must run this
format file locally, not on the remote submit.;









/*****************************************************************************

							01 - CALL FORMATS

******************************************************************************/

*** Call formats needed for algorithm ***;
%inc "&algpath./FormatStatements.sas";













/*****************************************************************************

					02 - GET THE OUTCOMES SOURCE DATAFILES

******************************************************************************/



*** Get the outcomes source datafile(s) ***;
*NOTE: Both codes and medication orders were used to determine if an outcome occurred.
Both int.codeoutcome and int.codemed are code/order level datasets with relevant
encounter information;
data codeoutcome;
	length code $12.;
 	set int.codeoutcome int.codemed (in=a);
  	if a then codetype='med';
run;
*
Dataset info:
- codeoutcome is a code-level dataset that has encounter information for
encounters with a pregnancy outcome code.
- codemed is an order-level dataset that has encounter information for
encounters linked to medication orders for misoprostol or mifepristone
;














/*****************************************************************************

		03 - STEP 1a - Group outcome encounters w/in +/- [EncGap] days

******************************************************************************/

%inc "&algpath./Step1and2_1a_OutcomeGroupsUsingCleanedEncounters.sas";
   *preps the input file (codeoutcome to outcomesbytype);
   *and loads macro OutcGrp to create outcome groups;
   *final dsn OutcomeGroups_&EncGap (work);

/*Delete unnecessary work datasets to keep memory clean*/
proc datasets library=work memtype=data nolist;
	delete encout encoutcome encoutcomeclean outcome:;
run;


***NOTE save encoutcomecleanrows;
data out.EncOutcomeCleanRows;
set encoutcomecleanrows;
run; quit;

*Run the macros;
%OutcGrp(EncGap =  7); *Allows 7-day gap between pregnancy outcome claims to define pregnancy outcome groups;
%OutcGrp(EncGap = 30); *Allows 30-day gap between pregnancy outcome claims to define pregnancy outcome groups;



/*Delete unnecessary work datasets to keep memory clean*/
proc datasets library=work memtype=data nolist;
	delete outcomebytype outcomesbytype: outcomegroup_addl_: outcomegroupsrow_: outcomesbygroup:
		codeoutcome;
run; quit;



















/*****************************************************************************

			04 - STEP 1b.1 - Assigns concordant outcomes per table 1

******************************************************************************/

*Run the macros that going to use to identify concordant pregnancy outcomes
within one pregnancy outcomg group.

1. Macro conctbl takes the outcomegroups and identifies concordant outcomes
2. Macro SplitConcordant(GrpDsn) outputs 3 datasets, split according to concordance.
	- conc_grpdsn contains the pregnancy outcome groups only with concordant outcomes
	- disc_GrpDsn contains the pregnancy outcome groups only with discordant outcomes
	- Conc_&GrpDsn.disc contains all the pregnancy outcome groups with the
		concordance indicators. This dataset is used to output a descritpive RTF
		file: &outpath.\Step1b1_Concordance_&grpdsn._%sysfunc(date(),yymmddn8.).rtf;

%inc "&algpath./Step1and2_1b_AssignAllConcordanceFlagMacro.sas";  















/*****************************************************************************

					05 - RUN PREG OUTCOME ALGORITHMS 1-4

******************************************************************************/

*MACRO runalg runs the pregnancy outcome identification algorithms 1-4 for 
each specified gap between encounters to define a pregnancy outcome group;

*Testing;
/*%let gap=30;*/

%MACRO RUNALG(gap);

	/*First create the datasets with concordant and discordant outcomes*/
    %SplitConcordant(OutcomeGroups_&gap.);

	/*Apply algorithms 1-4 to deal with discordant outcomes.*/
       *each algorithm uses same concordant (concdsn) and discordant data;
       *and creates dataset newdsn with suffix alg1 - alg4;

	%let concdsn= CONC_OUTCOMEGROUPS_&gap. ;
    %let discdsn= DISC_OUTCOMEGROUPS_&gap. ;
    %let newdsn= %substr(&concdsn,6);

    **Outcome Algorithm 1 Applied**;
         *creates newdsn_alg1;
            %inc "&algpath./Step1and2_1b_AssignOutcome_Algorithm1.sas";

    **Outcome Algorithm 2 Applied**;
         *creates newdsn_alg2;
            %inc "&algpath./Step1and2_1b_AssignOutcome_Algorithm2.sas";

    **Outcome Algorithm 3 Applied**;
         *creates newdsn_alg3;
            %inc "&Algpath./Step1and2_1b_AssignOutcome_Algorithm3.sas";

    **Outcome Algorithm 4 Applied**;
         *creates newdsn_alg4;
            %inc "&Algpath./Step1and2_1b_AssignOutcome_Algorithm4.sas";
%mend;


*Run the algorithms;

**Gap = 7 days;
%Runalg(7);
/*Delete unnecessary work datasets to keep memory clean*/
proc datasets library=work memtype=data nolist;
	delete getdate: nodt: outcomegroupsrow_7 outcomegroups7 outcomegroup_addl_7 
			outcomesbygroup2_7 outcomesbygroup_7 conc_outcomegroups_7
			Conc_outcomegroups_7disc Disc_outcomegroups_7 Disc_outcomegroups_7_int_alg3
			Disc_outcomegroups_7_int_alg4;
run; quit;


%Runalg(30);
proc datasets library=work memtype=data nolist;
	delete getdate: nodt: outcomegroupsrow_30 outcomegroups30 outcomegroup_addl_30 
			outcomesbygroup2_30 outcomesbygroup_30 conc_outcomegroups_30
			Conc_outcomegroups_30disc Disc_outcomegroups_30 Disc_outcomegroups_30_int_alg3
			Disc_outcomegroups_30_int_alg4;
run; quit;














/*****************************************************************************

		06 - ASSIGN OUTCOME DATES BASED ON FINDINGS OF ALGORITHMS

******************************************************************************/


**** merge the outcome algorithms - process macro OutDts ****;
    %inc "&Algpath./Step1and2_2_OutcomeDatesAssignedMacro.sas";

    %outdts(7);
/*    %outdts(14);*/
    %outdts(30);


/*Delete datasets that no longer need*/
proc datasets library=work memtype=data nolist;
	delete Encoutcomecleanrows getdate0:;
run; quit;
















/*****************************************************************************

	07 - COMBINE THE RESULTS FROM STEPS 1 AND 2 INTO THE SAME DATASET

******************************************************************************/


*Create a macro that saves the datasets for each gap value.;

*%let gap=30;

%MACRO SAVERPTIT(gap);

	/*Output the final dataset for the pregnancy outcome groups*/
	proc sql;
     	create table out.OutcomeAssigned_&gap. as
      	select a.* , /*Save all the original pregnancy outcome group information before applying algorithms*/
				/*Get data from Algorithm 1*/
				g1.outcome_concordant label="Concordant outcome (table1)",
             	g1.outcome_concordant_codetype label="Concordant outcome codetype (100=dx, 010=pr, 001=rx)", 
             	g1.discordant1, g1.outcome_assigned1, g1.outcome_assigned_codetype1, g1.outcome_class_assigned1,
               	gd1.Dt_Outcome_Assigned1, gd1.OutcomeDateAssigned1, 
				/*Get data from Algorithm 2*/
             	g2.discordant2, hier2_1, g2.outcome_assigned2, g2.outcome_assigned_codetype2, g2.outcome_class_assigned2,
               	gd2.Dt_Outcome_Assigned2,gd2.OutcomeDateAssigned2,
				/*Get data from Algorithm 3*/
             	g3.discordant3,  g3.outcome_assigned3, g3.outcome_assigned_codetype3, g3.outcome_class_assigned3,
                gd3.Dt_Outcome_Assigned3, gd3.OutcomeDateAssigned3 ,
				/*Get data from Algorithm 4*/
             	g4.discordant4,  g4.outcome_assigned4, g4.outcome_assigned_codetype4, g4.outcome_class_assigned4,
                gd4.Dt_Outcome_Assigned4, gd4.OutcomeDateAssigned4 
      	from outcomegroups_&gap. A /*Outcome groups prior to any cleaning*/
		/*Algorithm 1*/
       	left join OUTCOMEGROUPS_&gap._alg1 g1 on a.patient_deid = g1.patient_deid and a.outcomegrp= g1.outcomegrp
        left join getdate_&gap._1 gd1 on a.patient_deid= gd1.patient_deid and a.outcomegrp= gd1.outcomegrp
		/*Algorithm 2*/
       	left join OUTCOMEGROUPS_&gap._alg2 g2 on a.patient_deid = g2.patient_deid and a.outcomegrp= g2.outcomegrp
        left join getdate_&gap._2 gd2 on a.patient_deid= gd2.patient_deid and a.outcomegrp= gd2.outcomegrp
		/*Algorithm 3*/
       	left join OUTCOMEGROUPS_&gap._alg3 g3 on a.patient_deid = g3.patient_deid and a.outcomegrp= g3.outcomegrp
        left join getdate_&gap._3 gd3 on a.patient_deid= gd3.patient_deid and a.outcomegrp= gd3.outcomegrp
		/*Algorithm 4*/
       	left join OUTCOMEGROUPS_&gap._alg4 g4 on a.patient_deid = g4.patient_deid and a.outcomegrp= g4.outcomegrp
        left join getdate_&gap._4 gd4 on a.patient_deid= gd4.patient_deid and a.outcomegrp= gd4.outcomegrp
    ;
    quit;

	/*Output a descriptive RTF file with information to look at for each gap*/
/*    ods rtf file = "&outpath.\Step1_AlgorithmAssignments._Gap&gap.d_%sysfunc(date(),yymmddn8.).rtf" style=minimal;*/
/**/
/*	    title1 "Step 1 - Algorithm Assignments";*/
/*	    proc tabulate data=out.outcomeassigned_&gap. missing format=8.1;*/
/*	     	class outcome_assigned:;*/
/*	      	table outcome_assigned1 all, n colpctn /nocellmerge;*/
/*	      	table outcome_assigned2 all, n colpctn/nocellmerge;;*/
/*	      	table outcome_assigned3 all, n colpctn/nocellmerge;;*/
/*	      	table outcome_assigned4 all, n colpctn/nocellmerge;;*/
/*	      */
/*	      	table outcome_assigned1*outcome_assigned_codetype1, n pctn<outcome_assigned_codetype1>/  nocellmerge;*/
/*	      	table outcome_assigned2*outcome_assigned_codetype2, n pctn<outcome_assigned_codetype2> / nocellmerge;*/
/*	      	table outcome_assigned3*outcome_assigned_codetype3, n pctn<outcome_assigned_codetype3> / nocellmerge;*/
/*	      	table outcome_assigned4*outcome_assigned_codetype4, n pctn<outcome_assigned_codetype4>/ nocellmerge;*/
/*	    	format outcome_assigned_codetype: $outcd.;*/
/*	    run;*/
/**/
/*	    proc sql;*/
/*	     	create table assignedcounts_&gap. as*/
/*	      	select outcome_assigned1 as outcome, 1 as algorithm,put(outcome_assigned_codetype1,$outcd.) as Codetype, count(*) as cnt*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned1,calculated codetype*/
/*	      	Union*/
/*	      	select outcome_assigned2 as outcome, 2 as algorithm,put(outcome_assigned_codetype2,$outcd.) as Codetype, count(*) as cnt*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned2,calculated codetype*/
/*	      	Union*/
/*	      	select outcome_assigned3 as outcome, 3 as algorithm,put(outcome_assigned_codetype3,$outcd.) as Codetype, count(*) as cnt*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned3,calculated codetype*/
/*	      	Union*/
/*	      	select outcome_assigned4 as outcome, 4 as algorithm,put(outcome_assigned_codetype4,$outcd.) as Codetype, count(*) as cnt*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned4,calculated codetype*/
/*	      	Union*/
/*	      	select outcome_assigned1 as outcome, 1 as algorithm,'all' as Codetype, count(*) as cnt*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned1,calculated codetype*/
/*	      	Union*/
/*	      	select outcome_assigned2 as outcome, 2 as algorithm,'all' as Codetype, count(*) as cnt*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned2,calculated codetype*/
/*	      	Union*/
/*	      	select outcome_assigned3 as outcome, 3 as algorithm,'all' as Codetype, count(*) as cnt*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned3,calculated codetype*/
/*	      	Union*/
/*	      	select outcome_assigned4 as outcome, 4 as algorithm,'all' as Codetype, count(*) as cnt*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned4,calculated codetype*/
/*	    	;*/
/**/
/*	    proc tabulate data=assignedcounts_&gap.;*/
/*	     	class outcome algorithm codetype;*/
/*	     	var cnt;*/
/*	      	table outcome*codetype , algorithm*cnt*(sum);*/
/*	    run;*/
/**/
/*	    proc sql;*/
/*	     	create table assignedcountpts_&gap. as*/
/*	      	select distinct outcomegrp,outcome_assigned1 as outcome, 1 as algorithm,put(outcome_assigned_codetype1,$outcd.) as Codetype, patient_deid*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned1,calculated codetype*/
/*	      	Union*/
/*	      	select outcomegrp,outcome_assigned2 as outcome, 2 as algorithm,put(outcome_assigned_codetype2,$outcd.) as Codetype, patient_deid*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned2,calculated codetype*/
/*	      	Union*/
/*	      	select outcomegrp,outcome_assigned3 as outcome, 3 as algorithm,put(outcome_assigned_codetype3,$outcd.) as Codetype, patient_deid*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned3,calculated codetype*/
/*	      	Union*/
/*	      	select outcomegrp,outcome_assigned4 as outcome, 4 as algorithm,put(outcome_assigned_codetype4,$outcd.) as Codetype, patient_deid*/
/*	      	from out.outcomeassigned_&gap. group by outcome_assigned4,calculated codetype*/
/*	    	;*/
/**/
/*	    proc tabulate missing;*/
/*	     	class outcome algorithm codetype;*/
/*	      	table outcome*codetype all, algorithm*(n colpctn);*/
/*	    run;*/
/**/
/*   ods rtf close;*/

%mend;

%macro delete_dates(gap);

	/*Delete datasets that no longer need*/
	proc datasets library=work memtype=data nolist;
		delete getdate_&gap.: outcomegroups_&gap.: ;
	run; quit;

%mend;


/*Now, save the files*/
%saveRptit(7);
	%delete_dates(7)
/*%saveRptit(14);*/
/*	%delete_dates(14)*/
%saveRptit(30);
	%delete_dates(30)




