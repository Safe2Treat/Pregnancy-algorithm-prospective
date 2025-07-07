
/*******************************************************
modified April 12 2022 to change directory paths
pending new macro from Virginia
need to verify!
*******************************************************/





/*****************************************************************************************************/
/* Program: /mnt/files/datasources/medicare/macros/setup.sas                                         */
/* Purpose: Macro for assigning libnames, titles and footnotes for project run, allowing for easy    */
/*          change from sample to full data                                                          */
/*                                                                                                   */
/* Created: June 15, 2011                                                                            */
/* Author: Virginia Pate                                                                             */
/*                                                                                                   */
/* Macro Inputs:                                                                                     */
/*   SAMP: SAMPLE OF DATA ON WHICH TO RUN PROGRAM                                                    */
/*         Accepted values are: 1pct and full                                                        */
/*                                                                                                   */
/*   PROGNAME: PROGRAM NAME                                                                          */
/*            Name of the program being run.  This value is used in the footnote of any output that  */
/*            is produced with this program and is also used when saving the log                     */
/*                                                                                                   */
/*   SAVELOG: Y/N FLAG INDICATING WHETHER LOG FILE SHOULD BE SAVED TO A PERMANENT FILE               */
/*            If Y, log file is saved to .../programs/logs/random1pct or .../programs/logs/full      */
/*            with a file name YYYYMMDD_&PROGNAME..LOG, using the system date and the specified      */
/*            PROGNAME macro parameter to name the file                                              */
/*****************************************************************************************************/

%macro setup(sample, ProgramName, saveLog=N, serverSpace=local);

   /* DEFINE PROJECT SPECIFIC DATABASE AND PROJECT NAME */
     %LET db = marketscan_preg; 
     %LET proj = raw_data;

   /* DEFINE PROJECT SPECIFIC FILE PATHS, DEPENDENT ON SAMPLE */
      %LET sample = %SYSFUNC(lowcase(&sample));
      %IF &sample = 1pct %THEN %LET sample = random1pct;

      %GLOBAL ProjDir LogPath LogDate; 
      %LET ProjDir = /local/projects/&db./&proj.;
      
      %LET ProgPath = &ProjDir./programs; 
      %LET LogPath = &ProgPath./logs/&sample;

   /* IF SAVELOG IS SPECIFIED, START LOG FILE AND SET REQUIRED OPTIONS */
      %LET LogDate = %sysfunc(date(),yymmddn8.);
      %IF &saveLog = Y %THEN %DO;
         %LET programNameP = %SYSFUNC(translate(&programName,_,/));
         proc printto new log="&LogPath./&logDate._&programNameP..log"; run;
         options fullstimer mprint;
      %END;
          
   /* INCLUDE FORMATS NEEDED FOR PROJECT */
      proc format;
         value mo  1='Jan' 2='Feb' 3='Mar' 4='Apr' 5='May' 6='Jun' 
                   7='Jul' 8='Aug' 9='Sep' 10='Oct' 11='Nov' 12='Dec';
         value any 0='0' 1-high='1+';
         value two 0-1='0-1' 2-high='2+';
      run;

   /* DEFINE LIBNAMES */
      /* Raw and Derived Datasets */

         libname red "/local/data/master/marketscanccae/redbook" access=readonly;
         %IF &sample = random1pct %THEN %DO;
            libname raw "/local/data/master/marketscanccae/random1pct/ccae" access=readonly;
            libname der "/local/data/master/marketscanccae/random1pct/ccae/derivedDatasets" access=readonly;

            libname mdcr "/local/data/master/marketscanccae/random1pct/mdcr" access=readonly;
            libname mdcrder "/local/data/master/marketscanccae/random1pct/mdcr/derivedDatasets" access=readonly;
         %END;
         %ELSE %IF &sample = full %THEN %DO;
            libname raw "/local/data/master/marketscanccae/full/ccae" access=readonly;

            libname der "/local/data/master/marketscanccae/full/ccae/derivedDatasets" access=readonly;

            libname mdcr "/local/data/master/marketscanccae/full/mdcr" access=readonly;
            libname mdcrder "/local/data/master/marketscanccae/full/mdcr/derivedDatasets" access=readonly;
         %END;

      %IF &sample ^= random1pct %THEN %DO; %IF &sample ^= full %THEN %DO;
         %PUT ABORT: INVALID VALUE FOR SAMPLE PARAMETER;
         %PUT SAMPLE PARAMETER MUST TAKE ON A VALUE OF random1pct, 1pct OR full (CASE SENSITIVE);
         %ABORT;
      %END; %END;

      %IF &db = medicare %THEN %DO;
         options nosource2;
         %include "/nearline/files/datasources/medicare/views/check_expiration_date.sas";
         %check_expiration_date(&DUA);
         options source2;
      %END;


      /* Output Datasets */
      libname out "&ProjDir./data/&sample" %IF &sysuserid ^= vpate & sample = full %THEN access=readonly;;
      libname temp "&ProjDir./data/&sample./temp"; 
      libname ana "&ProjDir./data/&sample./analysis";

      /* Reference Files */
      %GLOBAL OutPath RefPath;
      %LET RefPath = &ProjDir./documentation/definitions; 
      libname expref "&RefPath./exposure";
      libname covref "&RefPath./covariates";
      libname outref "&RefPath./outcomes";
      libname rxcov  "&RefPath./covariates/rxcovar";

      /* Output Paths */
      %LET OutPath = &ProjDir./output/&sample; 
      ods listing gpath= "&OutPath./graphics";

      /* Formats */
      %LET codePath = /nearline/files/datasources/references/Code Reference Sets;
      libname codes "&codePath.";
      libname dx "&codePath./ICD9DX";
      libname icdp "&codePath./ICD9Proc";
      libname dx10 "&codePath./ICD10DX";
      libname icdp10 "&codePath./ICD10Proc";
      libname cpt "&codePath./CPT_HCPCS";
      libname atc "&codePath./Drugs";
      libname fmt "/nearline/files/datasources/&db./formats";

      options fmtsearch= (dx.dxfmts icdp.formats cpt dx10.dxfmts icdp10.formats
         %IF &db = medicare %THEN fmt.formats fmt.partdfmts06 fmt.partdfmts07 fmt.partdfmts08 fmt.plancharfmts ;
         %IF &db = marketscanccae %THEN fmt.formats ;);

   /* DEFINE FOOTNOTES AND TITLES */
      %GLOBAL footnote1 footnote2;
      %LET footnote1 = %STR(j=l "Program: &ProgPath./&programName..sas");
      %LET footnote2 = %STR(j=l "Run on the &sample. dataset by &SYSUSERID. on &SYSDATE. ");

      footnote1 &footnote1;
      footnote2 &footnote2;

%mend setup;
