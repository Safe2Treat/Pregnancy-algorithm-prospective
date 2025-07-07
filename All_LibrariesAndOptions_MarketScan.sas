/**********************************************************************************************
PROGRAM: All_LibrariesAndOptions.sas
PURPOSE: Hold all the library paths that should be pasted at the top of each program that is
batch submitted to the server.
PROGRAMMER: Chase Latour

NOTE: When this code was run on electronic health record data from the Carolina Data Warehouse
for Health (CDW-H), programs on the entire dataset could be run in one sitting. The MarketScan
data is substantially larger and will require that programs be batch submitted to the server.
Further, the file path set-up is very different in the N2 server compared to the CDW-H server.

As a result, library paths will need to be changed from the application of this code in the
CDW-H data. However, the programs are currently in-progress. We want to be sure that these
file paths are retained in one program that will not be rewritten. 

I have provided library paths below that will need to be pasted at the top of each program
that will be batch submitted to the N2 server.

Libnames:
	- RAW - code- and medication-fill level datasets from which the cohorts will be derived
	- INT - files created from raw incorporating billing code reference files 
	- OUT - primary output datasets created when applying steps in the algorithm
	- OUTd - subdirectory under out for detail-level pren-outcome pregnancy (steps3-10)

**********************************************************************************************/

********************Paste at the top of each program that is batch submitted;

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

%inc "&algpath./FormatStatements.sas";

*If you want to see the datasets on the local instance of SAS, you must run this
format file locally, not on the remote submit.;






