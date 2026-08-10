/*--------------------------------------------------------------------
  LMP-estimation query adapted from getga.sas (%getga, GA STEP 0-3).
  For each GA encounter:
    - days_pregtogaenc  = days between pregnancy outcome and the encounter
    - dt_lmp            = estimated last menstrual period, adjusting for
                          whether the encounter falls after the outcome
                          (follow-up) or before it (CASE on the day gap)
    - gest_age_table    = the outcome-type gestational-age lookup
    - dt_lmp_table      = LMP implied by that table value
  The CASE expressions, calculated-column references, date arithmetic and
  the outcome-keyed gestational-age table are taken from getga.sas. Display
  labels on the computed columns are omitted here; FORMAT= is retained.
--------------------------------------------------------------------*/
proc sql;
  create table anyga_estlmps as
  select
      a.patient_deid,
      a.idxpren,
      a.dt_gapreg format=date.,
      a.preg_outcome_clean,
      b.enc_date as dt_gaenc format=date.,
      b.gest_age_days as gestational_age_days,
      a.dt_gapreg - b.enc_date as days_pregtogaenc,
      case
        when calculated days_pregtogaenc < 0
             then a.dt_gapreg - b.gest_age_days
        else a.dt_gapreg - (b.gest_age_days + calculated days_pregtogaenc)
      end as dt_lmp format=date.,
      case a.preg_outcome_clean
        when 'LBS' then 273
        when 'LBM' then 252
        when 'SB'  then 196
        when 'MLS' then 273
        when 'EM'  then 56
        when 'SAB' then 70
        when 'IAB' then 70
        when 'UAB' then 70
        when 'UNK' then 140
        when 'UDL' then 273
      end as gest_age_table,
      a.dt_gapreg - (calculated gest_age_table) as dt_lmp_table format=date.
  from pregs a
  left join ga_enc b
    on a.patient_deid = b.patient_deid and a.idxpren = b.idxpren
  order by a.patient_deid, b.enc_date
  ;
quit;

proc print data=anyga_estlmps noobs;
  var patient_deid preg_outcome_clean dt_gaenc days_pregtogaenc
      dt_lmp gest_age_table dt_lmp_table;
run;
