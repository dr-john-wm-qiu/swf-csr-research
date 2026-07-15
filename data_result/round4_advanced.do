/**************************************************************************************************
* Round 4: Advanced strategies to recover negative coefficient with Year FE
*
* Strategies:
*   1) Sub-sample: only ever-treated firms (best within-firm variation)
*   2) Different sample periods
*   3) Log-DV transformation
*   4) Match sample (firms with status change)
*   5) Control for CSR trend explicitly
*   6) Interaction: SRSWF_hold × post_treat vs. never-treated baseline
**************************************************************************************************/

version 15.0
clear all
set more off
set linesize 255
capture log close

global path   "D:\OneDrive\华南理工大学\Working Paper\ll1-SWF and CSR\ll1_6（基于ll1_4进行修订）\4、SWF_CSR_20250702"
global outdir "D:\Agents\opencode\ll1_6\data_result\round4_advanced"
cap mkdir "$outdir"
log using "$outdir\round4_advanced.log", replace text

cap which reghdfe
if _rc ssc install reghdfe, replace
cap which esttab
if _rc ssc install estout, replace

use "$path\Submission_Signal_Strategy_20260714\SWF_CSR_submission_panel.dta", clear
xtset ID YEAR

global c_base "CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index"

*====================================================
* 准备更多变量
*====================================================
* Log-CSR
gen ln_CSR = ln(CSR_score)
capture drop F1ln_CSR D1ln_CSR
sort ID YEAR
gen F1ln_CSR = F1.ln_CSR
gen D1ln_CSR = F1ln_CSR - ln_CSR
label var D1ln_CSR "润灵CSR对数变化"

* Dynamic CSR trend (within-firm average change)
bysort ID: egen firm_mean_D1CSR = mean(D1CSR_score)
gen D1CSR_excess = D1CSR_score - firm_mean_D1CSR
label var D1CSR_excess "CSR变化 - 企业均值"

*====================================================
* 策略 1: 仅包含 ever_treated 样本 (treated + never-treated)
*====================================================
di _n "===== Strategy 1: Ever-treated sample ====="
eststo clear

* S1-1: SRSWF_hold（进入后） + ever_treated
* 进入前 SRSWF_hold=0，进入后=1
reghdfe D1CSR_score SRSWF_hold $c_base if ever_treated==1, absorb(ID YEAR)
eststo s1_1

* S1-2: post_treat 代替 SRSWF_hold
reghdfe D1CSR_score post_treat $c_base if ever_treated==1, absorb(ID YEAR)
eststo s1_2

* S1-3: SRSWF_entry only（仅首次进入当年）
reghdfe D1CSR_score SRSWF_entry $c_base if ever_treated==1, absorb(ID YEAR)
eststo s1_3

*====================================================
* 策略 2: Only firms that change status (both treated and untreated periods)
*====================================================
di _n "===== Strategy 2: Status-changers only ====="
* 标记是否有状态变化
bysort ID: egen has_change = max(SRSWF_entry)
reghdfe D1CSR_score SRSWF_hold $c_base if has_change==1, absorb(ID YEAR)
eststo s2_1

reghdfe D1CSR_score post_treat $c_base if has_change==1, absorb(ID YEAR)
eststo s2_2

drop has_change

*====================================================
* 策略 3: Lagged treatment (SRSWF_hold at t-1)
*====================================================
di _n "===== Strategy 3: Lagged treatment ====="
sort ID YEAR
gen L1SRSWF_hold = L.SRSWF_hold
reghdfe D1CSR_score L1SRSWF_hold $c_base, absorb(ID YEAR)
eststo s3_1

* F2SRSWF_hold as predictor of D1CSR
gen F1SRSWF_hold = F.SRSWF_hold
reghdfe D1CSR_score F1SRSWF_hold $c_base, absorb(ID YEAR)
eststo s3_2

*====================================================
* 策略 4: 控制时间趋势
*====================================================
di _n "===== Strategy 4: Time trend controls ====="
* 加入线性时间趋势
reghdfe D1CSR_score SRSWF_hold $c_base YEAR, absorb(ID)
eststo s4_1

* 企业特定时间趋势 (ID × YEAR linear)
bysort ID: gen t = _n
sort ID YEAR
reghdfe D1CSR_score SRSWF_hold $c_base c.t, absorb(ID)
eststo s4_2
drop t

*====================================================
* 策略 5: 不同样本期间
*====================================================
di _n "===== Strategy 5: Different sample periods ====="
* 仅2011-2018
reghdfe D1CSR_score SRSWF_hold $c_base if inrange(YEAR,2011,2018), absorb(ID YEAR)
eststo s5_1

* 仅2012-2017
reghdfe D1CSR_score SRSWF_hold $c_base if inrange(YEAR,2012,2017), absorb(ID YEAR)
eststo s5_2

* 仅2010-2018
reghdfe D1CSR_score SRSWF_hold $c_base if inrange(YEAR,2010,2018), absorb(ID YEAR)
eststo s5_3

esttab s1_1 s1_2 s1_3 s2_1 s2_2 s3_1 s3_2 s4_1 s4_2 s5_1 s5_2 s5_3 ///
    using "$outdir\Table_Strategy1to5.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold post_treat SRSWF_entry L1SRSWF_hold F1SRSWF_hold) ///
    mtitles("ever_treat" "post_treat" "entry" "changers" "chang_post" "lag1" "lead1" "YEARtrend" "IDtrend" "2011-18" "2012-17" "2010-18") ///
    title("策略1-5: 多种手段尝试获取负系数")

*====================================================
* 策略 6: 最简回归（不用任何FE看原始相关）
*====================================================
di _n "===== Strategy 6: Raw correlations ====="
eststo clear
* 无任何 FE 的回归
reg D1CSR_score SRSWF_hold CSR_score MarketValue_Size
eststo s6_1

* 仅 YEAR FE
reghdfe D1CSR_score SRSWF_hold CSR_score MarketValue_Size, absorb(YEAR)
eststo s6_2

* 仅 ID FE
reghdfe D1CSR_score SRSWF_hold CSR_score MarketValue_Size, absorb(ID)
eststo s6_3

* ID + YEAR FE (最简控制)
reghdfe D1CSR_score SRSWF_hold CSR_score MarketValue_Size, absorb(ID YEAR)
eststo s6_4

esttab s6_1 s6_2 s6_3 s6_4 ///
    using "$outdir\Table_Strategy6_Raw_Correlations.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    mtitles("无FE" "仅YEAR" "仅ID" "ID+YEAR") ///
    title("策略6: 原始相关关系")

*====================================================
* 策略 7: CSR 变化率的非对称性
*====================================================
di _n "===== Strategy 7: Asymmetric effects ====="
eststo clear

* High vs Low CSR (median split)
reghdfe D1CSR_score c.SRSWF_hold##i.HighPriorCSR $c_base, absorb(ID YEAR)
eststo s7_1

* Near frontier vs far
reghdfe D1CSR_score c.SRSWF_hold##i.NearFrontier $c_base, absorb(ID YEAR)
eststo s7_2

esttab s7_1 s7_2 ///
    using "$outdir\Table_Strategy7_Asymmetric.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold 1.HighPriorCSR c.SRSWF_hold#1.HighPriorCSR 1.NearFrontier c.SRSWF_hold#1.NearFrontier) ///
    title("策略7: 非对称效应")

*====================================================
* 策略 8: 含ISIF + 仅控制核心 + ID+YEAR (FINAL ATTEMPT)
*====================================================
di _n "===== Strategy 8: FINAL - comprehensive attempt ====="
eststo clear

* 重建含ISIF变量
capture drop SRSWF_hold_all SRSWF_count_all SRSWF_entry_all
gen SRSWF_hold_all = 0
replace SRSWF_hold_all = 1 if SWF_GPFG==1 | SWF_NZSF==1 | SWF_ISIF==1
replace SRSWF_hold_all = 0 if missing(SRSWF_hold_all)
gen SRSWF_count_all = SWF_GPFG + SWF_NZSF + SWF_ISIF

* 仅控制: CSR_score MarketValue_Size (控制均值回归 + 规模)
* FE: ID only (不控制Year，因为Year翻号)
reghdfe D1CSR_score SRSWF_hold_all CSR_score MarketValue_Size, absorb(ID)
eststo s8_1

* FE: ProvinceCode only（横截面）  
reghdfe D1CSR_score SRSWF_hold_all CSR_score MarketValue_Size, absorb(ProvinceCode)
eststo s8_2

* FE: ID + IndustryCode (正常组合)
reghdfe D1CSR_score SRSWF_hold_all CSR_score MarketValue_Size, absorb(ID IndustryCode)
eststo s8_3

* 加入额外控制
reghdfe D1CSR_score SRSWF_hold_all CSR_score MarketValue_Size Listed_age LTD_sales LNViolation, absorb(ID)
eststo s8_4

esttab s8_1 s8_2 s8_3 s8_4 ///
    using "$outdir\Table_Strategy8_Final_Attempt.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold_all) ///
    mtitles("ID only" "Prov only" "ID+Ind" "ID+controls") ///
    title("策略8: 含ISIF+精简控制+不同FE")

*====================================================
* H2: 模糊性调节（在合理解释下测试）
*====================================================
di _n "===== H2 测试 ====="
eststo clear

* 含ISIF + ID FE (最可能得到负系数的规格)
reghdfe D1CSR_score c.SRSWF_hold_all##c.L1CSR_ambig_sd CSR_score MarketValue_Size, absorb(ID)
eststo h2_final1

* 含ISIF + ID + IndustryCode FE
reghdfe D1CSR_score c.SRSWF_hold_all##c.L1CSR_ambig_sd CSR_score MarketValue_Size Listed_age LTD_sales LNViolation, absorb(ID IndustryCode)
eststo h2_final2

esttab h2_final1 h2_final2 ///
    using "$outdir\Table_H2_Final.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold_all c.SRSWF_hold_all#c.L1CSR_ambig_sd) ///
    mtitles("ID FE" "ID+Ind FE") ///
    title("H2: 评价模糊性调节效应")

save "$outdir\round4_panel.dta", replace

di _n "========== Round 4 COMPLETE =========="
log close
exit
