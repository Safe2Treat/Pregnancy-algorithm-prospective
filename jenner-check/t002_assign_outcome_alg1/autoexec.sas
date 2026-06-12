options obs=100;

/*--------------------------------------------------------------------
  Formats consumed by the Algorithm-1 step ($outclass), taken verbatim
  from the repo's FormatStatements.sas.
--------------------------------------------------------------------*/
proc format;
  value $outclass
   'LBM','LBS','MLS','SB','UDL' = 'Delivery'
   'SAB', 'IAB' , 'UAB' = 'Abortion'
   'EM','AEM' = 'Ectopic'
  ;
run;

/*--------------------------------------------------------------------
  Macro variables the algorithm program expects (set by the driver,
  Step1and2___PregnancyOutcomeGroups.sas, before %inc of this step).
--------------------------------------------------------------------*/
%let NewDsn  = OutcomeGroups_30;
%let concdsn = Conc_OutcomeGroups_30;
%let discdsn = Disc_OutcomeGroups_30;

/*--------------------------------------------------------------------
  Mock pregnancy-outcome groups standing in for the licensed MarketScan
  derivation. Column shape matches what the algorithm reads: one 3-digit
  DX/PR/RX indicator string per outcome type (LBM..AEM), Delivery/Abortion/
  Ectopic code-type rollups, and the concordance fields. Values are
  illustrative, not real claims.
--------------------------------------------------------------------*/
data Conc_OutcomeGroups_30;
  length LBM LBS MLS SB UDL SAB IAB UAB EM AEM $3
         Delivery Abortion Ectopic $3
         outcome_concordant $3;
  /* a clean live-birth-singleton group */
  patient_deid='P0001'; idxpren=1;
  LBM='000'; LBS='100'; MLS='000'; SB='000'; UDL='000';
  SAB='000'; IAB='000'; UAB='000'; EM='000'; AEM='000';
  Delivery='100'; Abortion='000'; Ectopic='000';
  concordant=1; outcome_concordant='LBS'; output;
  /* a clean spontaneous-abortion group */
  patient_deid='P0002'; idxpren=1;
  LBM='000'; LBS='000'; MLS='000'; SB='000'; UDL='000';
  SAB='101'; IAB='000'; UAB='000'; EM='000'; AEM='000';
  Delivery='000'; Abortion='101'; Ectopic='000';
  concordant=1; outcome_concordant='SAB'; output;
run;

data Disc_OutcomeGroups_30;
  length LBM LBS MLS SB UDL SAB IAB UAB EM AEM $3
         Delivery Abortion Ectopic $3
         outcome_concordant $3;
  /* discordant: live-birth + stillbirth codes present */
  patient_deid='P0003'; idxpren=1;
  LBM='000'; LBS='100'; MLS='000'; SB='010'; UDL='000';
  SAB='000'; IAB='000'; UAB='000'; EM='000'; AEM='000';
  Delivery='110'; Abortion='000'; Ectopic='000';
  concordant=0; outcome_concordant='not'; output;
  /* discordant: ectopic/molar + abortion codes present */
  patient_deid='P0004'; idxpren=1;
  LBM='000'; LBS='000'; MLS='000'; SB='000'; UDL='000';
  SAB='100'; IAB='000'; UAB='000'; EM='010'; AEM='000';
  Delivery='000'; Abortion='100'; Ectopic='010';
  concordant=0; outcome_concordant='not'; output;
run;
