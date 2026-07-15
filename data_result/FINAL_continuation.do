/**************************************************************************************************
* FINAL Continuation: Tables 4-7 (fixed)
**************************************************************************************************/

version 15.0
clear all
set more off
set linesize 255
capture log close

global path    "D:\OneDrive\华南理工大学\Working Paper\ll1-SWF and CSR\ll1_6（基于ll1_4进行修订）\4、SWF_CSR_20250702"
global outdir  "D:\Agents\opencode\ll1_6\data_result\FINAL_submission"
log using "$outdir\FINAL_continuation.log", replace text

cap which reghdfe
if _rc ssc install reghdfe, replace
cap which esttab
if _rc ssc install estout, replace
cap which ivreg2
if _rc ssc install ivreg2, replace
cap which ivreghdfe
if _rc ssc install ivreghdfe, replace

* 读入
use "$path\Submission_Signal_Strategy_20260714\SWF_CSR_submission_panel.dta", clear
xtset ID YEAR

* 重建 SRSWF 变量 (含 ISIF)
capture drop SRSWF_hold SRSWF_count SRSWF_owns
gen SRSWF_hold = 0
replace SRSWF_hold = 1 if SWF_GPFG==1 | SWF_NZSF==1 | SWF_ISIF==1
replace SRSWF_hold = 0 if missing(SRSWF_hold)
gen SRSWF_count = SWF_GPFG + SWF_NZSF + SWF_ISIF
gen SRSWF_owns  = GPFG_owns + NZSF_owns + ISIF_owns

* 控制变量
global c_min "CSR_score MarketValue_Size"
global c_base "CSR_score MarketValue_Size Listed_age State_Ownership LTD_sales LNViolation"
global c_full "CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index"

* 构造 D2CSR
capture drop D2CSR_score F2CSR_score
sort ID YEAR
gen F2CSR_score = F2.CSR_score
gen D2CSR_score = F2CSR_score - CSR_score
drop F2CSR_score

di _n "============================================================"
di "TABLE 4 (continued): Robustness"
di "============================================================"

* R5: 润灵 D2CSR (两期增量)
reghdfe D2CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode)

di _n "============================================================"
di "TABLE 4B: Year FE Sensitivity"
di "============================================================"
eststo clear

* FE1: ID only
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID)
eststo fe1

* FE2: ID + Ind (preferred)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode)
eststo fe2

* FE3: ID + Year
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID YEAR)
eststo fe3

* FE4: ID + Ind + Year
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode YEAR)
eststo fe4

* FE5: ID + Ind + Province
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode ProvinceCode)
eststo fe5

* FE6: ID + Ind + Province + Year (original do-file)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode ProvinceCode YEAR)
eststo fe6

esttab fe1 fe2 fe3 fe4 fe5 fe6 ///
    using "$outdir\Table4B_FE_Sensitivity.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    mtitles("ID" "ID+Ind" "ID+Year" "ID+Ind+Year" "ID+Ind+Prov" "ID+Ind+Prov+Year") ///
    title("Robustness: Fixed Effects Sensitivity Analysis")

di _n "============================================================"
di "TABLE 5: IV Endogeneity"
di "============================================================"
eststo clear

* IV-1: FOREIGN_REGISTER
capture noisily ivreghdfe D1CSR_score $c_base (SRSWF_hold = FOREIGN_REGISTER), absorb(ID IndustryCode) first
if _rc==0 {
    eststo iv1
    di "IV-1: FOREIGN_REGISTER - SUCCESS"
}
else {
    di "IV-1: FAILED"
}

* IV-2: FOREIGN_REGISTER + IFDI_TRADE
capture noisily ivreghdfe D1CSR_score $c_base (SRSWF_hold = FOREIGN_REGISTER IFDI_TRADE), absorb(ID IndustryCode) first
if _rc==0 {
    eststo iv2
    di "IV-2: FOREIGN_REGISTER + IFDI_TRADE - SUCCESS"
}
else {
    di "IV-2: FAILED"
}

* IV-3: TRADE_NOR + FOREIGN_REGISTER  
capture noisily ivreghdfe D1CSR_score $c_base (SRSWF_hold = TRADE_NOR FOREIGN_REGISTER), absorb(ID IndustryCode) first
if _rc==0 {
    eststo iv3
    di "IV-3: TRADE_NOR + FOREIGN_REGISTER - SUCCESS"
}
else {
    di "IV-3: FAILED"
}

capture esttab iv1 iv2 iv3 ///
    using "$outdir\Table5_IV_Endogeneity.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a widstat jp) ///
    order(SRSWF_hold) ///
    title("IV: Instrumental Variable Estimation")

di _n "============================================================"
di "TABLE 6: Heterogeneity"
di "============================================================"
eststo clear

* 6-1: SOE
gen SOE_dummy = State_Ownership > 0 if !missing(State_Ownership)
reghdfe D1CSR_score c.SRSWF_hold##i.SOE_dummy $c_min, absorb(ID IndustryCode)
eststo het1

* 6-2: Large firm
sum MarketValue_Size, detail
gen LargeFirm = MarketValue_Size >= r(p50) if !missing(MarketValue_Size)
reghdfe D1CSR_score c.SRSWF_hold##i.LargeFirm $c_min, absorb(ID IndustryCode)
eststo het2

* 6-3: High-tech
reghdfe D1CSR_score c.SRSWF_hold##i.High_tech_01 $c_min, absorb(ID IndustryCode)
eststo het3

* 6-4: High prior CSR
reghdfe D1CSR_score c.SRSWF_hold##i.HighPriorCSR $c_min, absorb(ID IndustryCode)
eststo het4

esttab het1 het2 het3 het4 ///
    using "$outdir\Table6_Heterogeneity.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold 1.SOE_dummy c.SRSWF_hold#1.SOE_dummy 1.LargeFirm c.SRSWF_hold#1.LargeFirm 1.High_tech_01 c.SRSWF_hold#1.High_tech_01 1.HighPriorCSR c.SRSWF_hold#1.HighPriorCSR) ///
    title("Heterogeneity: Subsample Analysis")

di _n "============================================================"
di "TABLE 7: Alternative Treatment"
di "============================================================"
eststo clear

reghdfe D1CSR_score SRSWF_count $c_base, absorb(ID IndustryCode)
eststo ta1

reghdfe D1CSR_score SRSWF_count SRSWF_owns $c_base, absorb(ID IndustryCode)
eststo ta2

reghdfe D1CSR_score SRSWF_owns $c_base if SRSWF_hold==1, absorb(ID IndustryCode)
eststo ta3

esttab ta1 ta2 ta3 ///
    using "$outdir\Table7_Alternative_Treatment.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_count SRSWF_owns) ///
    mtitles("Count only" "Count+Owns" "Owns(held only)") ///
    title("Robustness: Alternative Treatment Variables")

save "$outdir\FINAL_panel.dta", replace

di _n "============================================================"
di "*** FINAL SUBMISSION COMPLETE ***"
di "============================================================"

log close
exit
