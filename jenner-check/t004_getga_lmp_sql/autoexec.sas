options obs=100;

/*--------------------------------------------------------------------
  Mock pregnancies and their gestational-age (GA) encounters, standing
  in for the licensed MarketScan derivation that getga.sas consumes.
  pregs: one row per pregnancy with its outcome date and cleaned outcome
  type; ga_enc: GA-coded encounters with an estimated gestational age in
  days. Values are illustrative, not real claims.
--------------------------------------------------------------------*/
data pregs;
  length patient_deid $6 preg_outcome_clean $3;
  patient_deid='P0001'; idxpren=1; dt_gapreg='15JUN2023'd;
  preg_outcome_clean='LBS'; output;
  patient_deid='P0002'; idxpren=1; dt_gapreg='10MAR2023'd;
  preg_outcome_clean='SAB'; output;
run;

data ga_enc;
  length patient_deid $6;
  patient_deid='P0001'; idxpren=1; enc_date='01JUN2023'd; gest_age_days=270; output;
  patient_deid='P0001'; idxpren=1; enc_date='20JUN2023'd; gest_age_days=275; output;
  patient_deid='P0002'; idxpren=1; enc_date='05MAR2023'd; gest_age_days=66;  output;
run;
