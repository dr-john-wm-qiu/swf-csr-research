version 15.0
clear all
set more off
capture log close

global path   "D:\OneDrive\华南理工大学\Working Paper\ll1-SWF and CSR\ll1_6（基于ll1_4进行修订）\4、SWF_CSR_20250702"
global outdir "D:\Agents\opencode\ll1_6\data_result\round3_diagnostic"
cap mkdir "$outdir"
log using "$outdir\round3_diagnostic.log", replace text

cap which reghdfe
if _rc ssc install reghdfe, replace
cap which esttab
if _rc ssc install estout, replace

use "$path\Submission_Signal_Strategy_20260714\SWF_CSR_submission_panel.dta", clear
xtset ID YEAR

global c_base "CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index"

* 创建 indyear 的数值版本用于 IndustryCode#YEAR
capture encode IndustryCode, gen(IndCode_num)

di _n "==================== DIAGNOSTIC ===================="
di "Comparing different FE specifications to understand"
di "why SRSWF_hold coefficient is positive instead of negative"
di "====================================================="

eststo clear

* D0: 原始 do-file 的 FE (无 Year)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode ProvinceCode)
eststo d0_orig

* D1: ID only (最简)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID)
eststo d1_id

* D2: ID + YEAR (Round 1 基准)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID YEAR)
eststo d2_id_year

* D3: ID + ProvinceCode (无 Year)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID ProvinceCode)
eststo d3_id_prov

* D4: IndustryCode + YEAR (无 ID，横截面)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(IndustryCode YEAR)
eststo d4_ind_year

* D5: ProvinceCode + YEAR (无 ID，横截面)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ProvinceCode YEAR)
eststo d5_prov_year

* D6: 仅 YEAR
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(YEAR)
eststo d6_year

esttab d0_orig d1_id d2_id_year d3_id_prov d4_ind_year d5_prov_year d6_year ///
    using "$outdir\Table_Diagnostic_FE_Comparison.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    mtitles("原FE(无Year)" "仅ID" "ID+YEAR" "ID+Prov" "Ind+YEAR" "Prov+YEAR" "仅YEAR") ///
    title("诊断: 不同FE组合下的SRSWF_hold系数")

*====================================================
* 进一步诊断：entry/exit 区分
*====================================================
di _n "==================== ENTRY vs HOLD ===================="
eststo clear

* 区分首次进入和持续持有
reghdfe D1CSR_score SRSWF_entry SRSWF_hold $c_base, absorb(ID YEAR)
eststo entry1

* 用 post_treat 代替 SRSWF_hold
reghdfe D1CSR_score post_treat $c_base, absorb(ID YEAR)
eststo entry2

* 交互：首次进入 vs 持续持有
gen SRSWF_ongoing = SRSWF_hold==1 & SRSWF_entry==0
reghdfe D1CSR_score SRSWF_entry SRSWF_ongoing $c_base, absorb(ID YEAR)
eststo entry3

esttab entry1 entry2 entry3 ///
    using "$outdir\Table_Diagnostic_Entry_vs_Ongoing.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_entry SRSWF_hold SRSWF_ongoing post_treat) ///
    title("诊断: 首次进入vs持续持有")

*====================================================
* Time-to-treatment 动态
*====================================================
di _n "==================== TIME-TO-TREATMENT ===================="
eststo clear

* 用相对年份看动态效应
reghdfe D1CSR_score EntryAge0 EntryAge1 EntryAge2 EntryAge3plus $c_base, absorb(ID YEAR)
eststo dtime1

* SRSWF_dura 线性
reghdfe D1CSR_score SRSWF_hold SRSWF_dura $c_base, absorb(ID YEAR)
eststo dtime2

* 交互: SRSWF_hold × SRSWF_dura
reghdfe D1CSR_score c.SRSWF_hold##c.SRSWF_dura $c_base, absorb(ID YEAR)
eststo dtime3

esttab dtime1 dtime2 dtime3 ///
    using "$outdir\Table_Diagnostic_Time_To_Treatment.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold SRSWF_dura EntryAge0 EntryAge1 EntryAge2 EntryAge3plus) ///
    title("诊断: 处理时长动态")

save "$outdir\round3_panel.dta", replace

di _n "==================== Round 3 DIAGNOSTIC COMPLETE ===================="
log close
exit
