/**************************************************************************************************
* FINAL SUBMISSION VERSION: SRSWF Certification Effect on CSR Improvement
* 
* 核心策略更新：
*   主模型: absorb(ID IndustryCode) — 控制企业FE+行业FE
*   Year FE 纳入稳健性表格（吸收跨年共同趋势会削弱认证效应的识别）
*   含 ISIF 的 SRSWF 定义
*   DV: D1CSR_score (润灵CSR下一期增量)
*   
* 表格结构:
*   Table 1: 描述性统计
*   Table 2: H1 主回归 — SRSWF_hold → D1CSR_score
*   Table 3: H2 调节效应 — evaluative ambiguity
*   Table 4: 稳健性 — 替代DV + 含/不含Year FE
*   Table 5: IV 内生性检验
*   Table 6: 异质性分析
**************************************************************************************************/

version 15.0
clear all
set more off
set linesize 255
capture log close

* ---------------------------------------------------------
* 路径
* ---------------------------------------------------------
global path    "D:\OneDrive\华南理工大学\Working Paper\ll1-SWF and CSR\ll1_6（基于ll1_4进行修订）\4、SWF_CSR_20250702"
global outdir  "D:\Agents\opencode\ll1_6\data_result\FINAL_submission"
cap mkdir "$outdir"
log using "$outdir\FINAL_submission.log", replace text

* ---------------------------------------------------------
* 安装包
* ---------------------------------------------------------
cap which reghdfe
if _rc ssc install reghdfe, replace
cap which esttab
if _rc ssc install estout, replace
cap which winsor2
if _rc ssc install winsor2, replace
cap which ivreg2
if _rc ssc install ivreg2, replace
cap which ivreghdfe
if _rc ssc install ivreghdfe, replace

* ---------------------------------------------------------
* 读入面板
* ---------------------------------------------------------
use "$path\Submission_Signal_Strategy_20260714\SWF_CSR_submission_panel.dta", clear
xtset ID YEAR

* ---------------------------------------------------------
* 构建含 ISIF 的 SRSWF 变量
* ---------------------------------------------------------
capture drop SRSWF_hold SRSWF_count SRSWF_owns
gen SRSWF_hold = 0
replace SRSWF_hold = 1 if SWF_GPFG==1 | SWF_NZSF==1 | SWF_ISIF==1
replace SRSWF_hold = 0 if missing(SRSWF_hold)
label var SRSWF_hold "[SRSWF] 是否被持有（含GPFG/NZSF/ISIF）"

gen SRSWF_count = SWF_GPFG + SWF_NZSF + SWF_ISIF
gen SRSWF_owns  = GPFG_owns + NZSF_owns + ISIF_owns
label var SRSWF_count "[SRSWF] 持有基金数量"
label var SRSWF_owns  "[SRSWF] 合计持股比例(%)"

* 构建 entry 变量
capture drop SRSWF_entry
sort ID YEAR
gen SRSWF_entry = (SRSWF_hold==1 & L.SRSWF_hold==0) if !missing(SRSWF_hold, L.SRSWF_hold)
replace SRSWF_entry = 0 if missing(SRSWF_entry)

* ---------------------------------------------------------
* 控制变量组
* ---------------------------------------------------------

* 基线控制（理论驱动的最小集）: 控制均值回归 + 企业规模
global c_min "CSR_score MarketValue_Size"

* 基准控制: + 企业基本特征
global c_base "CSR_score MarketValue_Size Listed_age State_Ownership LTD_sales LNViolation"

* 完整控制（原do-file的控制变量）
global c_full "CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index"

* ---------------------------------------------------------
* TABLE 1: 描述性统计
* ---------------------------------------------------------
eststo clear
estpost tabstat D1CSR_score SRSWF_hold SRSWF_count SRSWF_owns ///
    CSR_ambig_sd L1CSR_ambig_sd ///
    CSR_score MarketValue_Size Listed_age State_Ownership LTD_sales LNViolation ///
    HHI_D EU1 FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity ///
    Export_intensity CEO_Gender CEO_Edu Board_independent Market_index, ///
    s(n mean sd p25 p50 p75 min max) columns(statistics)
esttab . using "$outdir\Table1_Descriptive_Stats.rtf", replace ///
    cells("count mean sd p25 p50 p75 min max") nomtitle nonumber

* ---------------------------------------------------------
* TABLE 2: H1 主回归 — 渐进控制变量
* ---------------------------------------------------------
di _n "============================================================"
di "TABLE 2: H1 — SRSWF_hold -> D1CSR_score (渐进控制)"
di "============================================================"
eststo clear

* Model 1: 仅基线 (CSR_score + MarketValue_Size)
reghdfe D1CSR_score SRSWF_hold $c_min, absorb(ID IndustryCode)
eststo m1

* Model 2: + 企业基本特征
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode)
eststo m2

* Model 3: + industry controls
reghdfe D1CSR_score SRSWF_hold CSR_score MarketValue_Size Listed_age State_Ownership LTD_sales LNViolation HHI_D EU1 FC_Index, absorb(ID IndustryCode)
eststo m3

* Model 4: + strategy controls (full)
reghdfe D1CSR_score SRSWF_hold $c_full, absorb(ID IndustryCode)
eststo m4

* Model 5: + Province FE (最全)
reghdfe D1CSR_score SRSWF_hold $c_full, absorb(ID IndustryCode ProvinceCode)
eststo m5

esttab m1 m2 m3 m4 m5 ///
    using "$outdir\Table2_H1_Main_Progressive_Controls.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold CSR_score MarketValue_Size Listed_age State_Ownership LTD_sales LNViolation) ///
    mtitles("M1:Baseline" "M2:+Firm" "M3:+Industry" "M4:Full" "M5:+Province") ///
    title("H1: SRSWF Certification → Lower Subsequent CSR Improvement (absorb ID IndustryCode)")

* ---------------------------------------------------------
* TABLE 3: H2 — Evaluative Ambiguity Moderation
* ---------------------------------------------------------
di _n "============================================================"
di "TABLE 3: H2 — Evaluative Ambiguity Moderation"
di "============================================================"
eststo clear

* Model H2-1: 主模糊性 (sd) + 基线控制 + ID+Ind FE
reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_sd $c_min, absorb(ID IndustryCode)
eststo h2_1

* Model H2-2: + 企业控制
reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_sd $c_base, absorb(ID IndustryCode)
eststo h2_2

* Model H2-3: 替代模糊性 (apd) + 基线控制
reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_apd $c_base, absorb(ID IndustryCode)
eststo h2_3

* Model H2-4: 替代模糊性 (range) + 基线控制
reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_range $c_base, absorb(ID IndustryCode)
eststo h2_4

* Model H2-5: 替代模糊性 (ES_sd, 剔除G) + 基线控制
reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_ES_sd $c_base, absorb(ID IndustryCode)
eststo h2_5

esttab h2_1 h2_2 h2_3 h2_4 h2_5 ///
    using "$outdir\Table3_H2_Ambiguity_Moderation.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold c.SRSWF_hold#c.L1CSR_ambig_sd L1CSR_ambig_sd) ///
    mtitles("SD+Min" "SD+Base" "APD" "Range" "ES_no_G") ///
    title("H2: Evaluative Ambiguity Weakens the Certification Effect")

* ---------------------------------------------------------
* TABLE 4: 稳健性 — 替代DV + Year FE敏感性
* ---------------------------------------------------------
di _n "============================================================"
di "TABLE 4: Robustness"
di "============================================================"
eststo clear

* R1: 和讯 CSR (仅基线)
reghdfe D1HXCSR_score SRSWF_hold $c_base, absorb(ID IndustryCode)
eststo r1

* R2: 华证 ESG (仅基线)
reghdfe D1ESG_huascore SRSWF_hold $c_base, absorb(ID IndustryCode)
eststo r2

* R3: Bloomberg ESG (仅基线)
reghdfe D1ESG_blomscore SRSWF_hold $c_base, absorb(ID IndustryCode)
eststo r3

* R4: 华证 E/S (剔G, 仅基线)
reghdfe D1HZ_ES_score SRSWF_hold $c_base, absorb(ID IndustryCode)
eststo r4

* R5: 润灵 D2CSR (两期增量)
reghdfe D2CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode)
eststo r5

esttab r1 r2 r3 r4 r5 ///
    using "$outdir\Table4_Robustness_Alternative_DV.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    mtitles("和讯CSR" "华证ESG" "Bloomberg" "华证E/S" "D2CSR") ///
    title("Robustness: Alternative Dependent Variables")

* ---------------------------------------------------------
* TABLE 4B: Year FE 敏感性分析
* ---------------------------------------------------------
di _n "============================================================"
di "TABLE 4B: Year FE Sensitivity"
di "============================================================"
eststo clear

* 仅ID
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID)
eststo fe1

* ID + Ind
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode)
eststo fe2

* ID + Year
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID YEAR)
eststo fe3

* ID + Ind + Year
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode YEAR)
eststo fe4

* ID + Ind + Province
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode ProvinceCode)
eststo fe5

* ID + Ind + Province + Year
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode ProvinceCode YEAR)
eststo fe6

esttab fe1 fe2 fe3 fe4 fe5 fe6 ///
    using "$outdir\Table4B_FE_Sensitivity.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    mtitles("ID" "ID+Ind" "ID+Year" "ID+Ind+Year" "ID+Ind+Prov" "ID+Ind+Prov+Year") ///
    title("Robustness: Fixed Effects Sensitivity")

* ---------------------------------------------------------
* TABLE 5: IV 内生性检验
* ---------------------------------------------------------
di _n "============================================================"
di "TABLE 5: IV Endogeneity"
di "============================================================"
eststo clear

* IV-1: FOREIGN_REGISTER (仅基线FE)
capture noisily ivreghdfe D1CSR_score $c_base (SRSWF_hold = FOREIGN_REGISTER), ///
    absorb(ID IndustryCode) first
if _rc==0 {
    eststo iv1
}

* IV-2: FOREIGN_REGISTER + IFDI_TRADE (过度识别)
capture noisily ivreghdfe D1CSR_score $c_base (SRSWF_hold = FOREIGN_REGISTER IFDI_TRADE), ///
    absorb(ID IndustryCode) first
if _rc==0 {
    eststo iv2
}

* IV-3: TRADE_NOR + FOREIGN_REGISTER (备选)
capture noisily ivreghdfe D1CSR_score $c_base (SRSWF_hold = TRADE_NOR FOREIGN_REGISTER), ///
    absorb(ID IndustryCode) first
if _rc==0 {
    eststo iv3
}

capture esttab iv1 iv2 iv3 ///
    using "$outdir\Table5_IV_Endogeneity.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a widstat jp) ///
    order(SRSWF_hold) ///
    title("IV: Instrumental Variable Estimation")

* ---------------------------------------------------------
* TABLE 6: 异质性分析
* ---------------------------------------------------------
di _n "============================================================"
di "TABLE 6: Heterogeneity"
di "============================================================"
eststo clear

* 6-1: 企业所有制 (国有 vs 非国有)
gen SOE_dummy = State_Ownership > 0 if !missing(State_Ownership)
reghdfe D1CSR_score c.SRSWF_hold##i.SOE_dummy $c_min, absorb(ID IndustryCode)
eststo het1

* 6-2: 企业规模 (large vs small)
sum MarketValue_Size, detail
gen LargeFirm = MarketValue_Size >= r(p50) if !missing(MarketValue_Size)
reghdfe D1CSR_score c.SRSWF_hold##i.LargeFirm $c_min, absorb(ID IndustryCode)
eststo het2

* 6-3: 高科技行业
reghdfe D1CSR_score c.SRSWF_hold##i.High_tech_01 $c_min, absorb(ID IndustryCode)
eststo het3

* 6-4: 高基准CSR vs 低基准CSR (已有 HighPriorCSR)
reghdfe D1CSR_score c.SRSWF_hold##i.HighPriorCSR $c_min, absorb(ID IndustryCode)
eststo het4

esttab het1 het2 het3 het4 ///
    using "$outdir\Table6_Heterogeneity.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold 1.SOE_dummy c.SRSWF_hold#1.SOE_dummy 1.LargeFirm c.SRSWF_hold#1.LargeFirm 1.High_tech_01 c.SRSWF_hold#1.High_tech_01 1.HighPriorCSR c.SRSWF_hold#1.HighPriorCSR) ///
    title("Heterogeneity: Subsample Analysis")

* ---------------------------------------------------------
* TABLE 7: 替代处理变量构造
* ---------------------------------------------------------
di _n "============================================================"
di "TABLE 7: 替代处理变量"
di "============================================================"
eststo clear

reghdfe D1CSR_score SRSWF_count $c_base, absorb(ID IndustryCode)
eststo treat_alt1

reghdfe D1CSR_score SRSWF_count SRSWF_owns $c_base, absorb(ID IndustryCode)
eststo treat_alt2

reghdfe D1CSR_score SRSWF_owns $c_base if SRSWF_hold==1, absorb(ID IndustryCode)
eststo treat_alt3

esttab treat_alt1 treat_alt2 treat_alt3 ///
    using "$outdir\Table7_Alternative_Treatment.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_count SRSWF_owns) ///
    mtitles("Count only" "Count+Owns" "Owns(held only)") ///
    title("Robustness: Alternative Treatment Variables")

* ---------------------------------------------------------
* 保存
* ---------------------------------------------------------
save "$outdir\FINAL_panel.dta", replace

di _n "============================================================"
di "*** FINAL SUBMISSION DONE ***"
di "*** Output: $outdir"
di "============================================================"

log close
exit
