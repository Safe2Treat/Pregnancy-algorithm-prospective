options obs=100;

/*--------------------------------------------------------------------
  Mock pregnancy-outcome groups for the concordance macro. The
  SplitConcordant macro reads, per group: a 3-digit DX/PR/RX indicator
  string for each outcome type (LBM..AEM), Delivery/Abortion/Ectopic
  code-type rollups, outcomegroup_OutcomesNORX_N (count of non-Rx
  outcome types present), and pr_n/dx_n/rx_n. Values are illustrative,
  not real claims.
--------------------------------------------------------------------*/
data OutcomeGroups_30;
  length LBM LBS MLS SB UDL SAB IAB UAB EM AEM $3
         Delivery Abortion Ectopic $3 outcomegrp $4;
  /* single live-birth-singleton outcome -> concordant (1 outcome) */
  patient_deid='P0001'; outcomegrp='G001';
  LBM='000'; LBS='100'; MLS='000'; SB='000'; UDL='000';
  SAB='000'; IAB='000'; UAB='000'; EM='000'; AEM='000';
  Delivery='100'; Abortion='000'; Ectopic='000';
  outcomegroup_OutcomesNORX_N=1; pr_n=0; dx_n=1; rx_n=0; output;
  /* live-birth-singleton + uncategorized delivery -> table-1 concordant pair */
  patient_deid='P0002'; outcomegrp='G002';
  LBM='000'; LBS='100'; MLS='000'; SB='000'; UDL='010';
  SAB='000'; IAB='000'; UAB='000'; EM='000'; AEM='000';
  Delivery='110'; Abortion='000'; Ectopic='000';
  outcomegroup_OutcomesNORX_N=2; pr_n=1; dx_n=1; rx_n=0; output;
  /* spontaneous abortion + unspecified abortion -> SAB/UAB concordant pair */
  patient_deid='P0003'; outcomegrp='G003';
  LBM='000'; LBS='000'; MLS='000'; SB='000'; UDL='000';
  SAB='100'; IAB='000'; UAB='001'; EM='000'; AEM='000';
  Delivery='000'; Abortion='101'; Ectopic='000';
  outcomegroup_OutcomesNORX_N=2; pr_n=0; dx_n=1; rx_n=1; output;
  /* live-birth + stillbirth (both deliveries) -> discordant */
  patient_deid='P0004'; outcomegrp='G004';
  LBM='000'; LBS='100'; MLS='000'; SB='010'; UDL='000';
  SAB='000'; IAB='000'; UAB='000'; EM='000'; AEM='000';
  Delivery='110'; Abortion='000'; Ectopic='000';
  outcomegroup_OutcomesNORX_N=2; pr_n=1; dx_n=1; rx_n=0; output;
run;
