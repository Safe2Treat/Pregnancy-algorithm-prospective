# Prospective_pregnancy_marketscan

The code provided in this repository was constructed to identify a cohort of pregnancies prospectively from MarketScan claims data. **Go to the Wiki page for detailed documentation for implementing this algorithm.**

All of the SAS files are extensively commented to facilitate use, but we provide a description below for getting started. This project was conducted on a remote server through a local interface. Some lines of coded were included to create the connection between the local SAS session and remote server. This led to some lines that needed to be run locally, though the majority were run directly to the server. This should be indicated in the files. These programs assume that all SAS files are saved in the same location.

Documentation on the algorithm, its assumptions, and details on the functionality intended by the programs is provided on the Wiki page.
1. `Algorithm Documentation - User Guide.docx` - This file provides a detailed overview of the algorithm, the program files, inputs and outputs, and what the programs are doing. The end result of this file is a pregnancy cohort that may have pregnancies that are too long, have unreasonable indexing prenatal claims, or overlap with other pregnancies.
2. `Cleaning Derived Pregnancies.docx` - This file provides an overview of our logic in cleaning the pregnancies, including references. This was implemented after the rest of the algorithm.

Files that must be downloaded but do not need to be manually run:
- `Variable Identification.xlsx` -- This file contains all the reference code lists for prenatal claims, pregnancy outcome codes, and gestational age codes. These code lists are called in via the `Step00_create_reference_files.sas` program.
- `All_LibrariesAndOptions_MarketScan.sas` -- This file specifies the necessary SAS libraries, options, etc. This is called in with %include statements in relevant files.
- `FormatStatements.sas` -- Aptly named, this file contains a series of format statements. This is called in with %include statements in relevant files.

To get started, run two programs to get the necessary data files for the rest of the algorithm:
- `Step00_create_reference_files.sas` -- This pulls in the code lists from the `Variable Identification.xlsx` file and saves the code lists as SAS files to the relevant library.
- `Step00_create_data_files.sas` -- This pulls in all of the inpatient admission/service claims, outpatient service claims, and medication fill claims that have any information that may be used throughout the algorithm. This was a separate step that was required because of how MarketScan claims access is managed at UNC. Ideally, we should only touch the raw data once, in which we pull in all the necessary data, and then we ran based upon the saved data. This file is the code that touched the raw file.

Run the Algorithm:
- `Step0_prep_importmarchdata_MarketScan.sas` -- This file preps all of the data imported by `Step00_create_data_files.sas` so that it can be used in later parts of the algorithm. There are a series of renaming steps here that were required because the code was developed in a different data source with different variable names.
- `Step1and2___PregnancyOutcomeGroups.sas` -- This file implements all of the steps to identify pregnancy outcome groups via 4 different algorithms. This code calls in the following files via an %include statement: `Step1and2_1a_OutcomeGroupsUsingCleanedEncounters.sas`, `Step1and2_1b_AssignAllConcordanceFlagMacro.sas`, `Step1and2_1b_AssignOutcome_Algorithm#.sas`, `Step1and2_2_OutcomeDatesAssignedMacro.sas`
- `Steps3thru10___PregnancyOUtcomes_ComplexorSimple.sas` -- This code connects prenatal encounters with pregnancy outcome groups where possible. Otherwise, it identifies groups of pregnancies based upon prenatal encounters alone and then based upon outcome groups alone. This calls in the following files: `Steps3thru10_Macros_file1.sas`, `Steps3thru10_Macros_file2_Step5abc.sas`, and `Steps3thru10_Macros_file3_Step8Complex.sas`.
- `Step11___PregPlusLMP.sas` -- This file assigns estimated last menstrual periods (LMPs) to the identified pregnancies. This calls in the file `Step11_GestationalAge_macro.sas`
- `Step12___clean_pregnancies.sas` -- This implements a series of data cleaning steps for pregnancies that are too long, have theri indexing prenatal encounter too close to their LMP, or that overlap with other pregnancies. This requires the getGA macro encoded in the SAS file getga.sas. This is MODIFIED from the version of this macro encoded in `Step11_GestationalAge_macro.sas`.

Data are accessible after payment to Merative with an appropriate data use agreement. All analyses were approved by UNC's Institutional Review Board. No data are uploaded to this repository.

Given the important shifts in legislation and policy surrounding induced abortion and reproductive freedom/autonomy in the U.S., we have modified this code such that it does not uniquely identify induced abortions. Instead, they are identified as "Unspecified Abortions". As such, this category can include induced abortionsn as well as spontaneous abortions where the coding documentation did not clearly indicate that it was spontaneous. To identify induced abortions, users must modify the pregnancy outcome codelist to determine which codes they believe identify an induced abortion specifically.
