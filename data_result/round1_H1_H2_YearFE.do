/**************************************************************************************************
* Round 1: H1 + H2 核心检验（带 Year FE）
* 关键修改：
*   - 加入 Year FE (absorb ID YEAR)
*   - 移除 slope change / gap closing 主表
*   - 仅保留 D1CSR_score 作为主因变量
*   - 尝试多种 FE 组合
**************************************************************************************************/

version 15.0
clear all
set more off
set linesize 255
capture log close

* 路径设置
global path    "D:\OneDrive\华南理工大学\Working Paper\ll1-SWF and CSR\ll1_6（基于ll1_4进行修订）\4、SWF_CSR_20250702"
global outdir  "D:\Agents\opencode\ll1_6\data_result\round1_ID_YEAR"
cap mkdir "$outdir"
log using "$outdir\round1_H1_H2_with_YearFE.log", replace text

* 安装包（如需要）
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

* 读入已构造好的面板
use "$path\Submission_Signal_Strategy_20260714\SWF_CSR_submission_panel.dta", clear
xtset ID YEAR

*====================================================
* 重新构造样本：仅保留关键变量非缺失
*====================================================
* 核心 DV 与 Treatment
global y_main   "D1CSR_score"
global treat1   "SRSWF_hold"

* 控制变量（初始使用原始控制变量组合）
global controls "CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index"

* 替代因变量
global y_hx     "D1HXCSR_score"
global y_esg_b  "D1ESG_blomscore"
global y_esg_hz "D1ESG_huascore"
global y_es_hz  "D1HZ_ES_score"

*====================================================
* 描述性统计
*====================================================
di _n "*********************************************"
di "*** 描述性统计"
di "*********************************************"
sum D1CSR_score D1HXCSR_score D1ESG_blomscore D1ESG_huascore SRSWF_hold SRSWF_count ///
    CSR_ambig_sd L1CSR_ambig_sd $controls, detail

tab SRSWF_hold

*====================================================
* Round 1 核心：H1 检验 + 多种 FE 规格
*====================================================
di _n "*********************************************"
di "*** Round 1: H1 -- ID + YEAR FE(基准)"
di "*********************************************"

eststo clear

* Model 1: ID + YEAR (最核心要求)
reghdfe D1CSR_score SRSWF_hold $controls, absorb(ID YEAR)
eststo m1_idyear

* Model 2: ID + IndustryCode + YEAR (加入行业 FE)
reghdfe D1CSR_score SRSWF_hold $controls, absorb(ID IndustryCode YEAR)
eststo m2_id_ind_year

* Model 3: ID + ProvinceCode + YEAR (加入省份 FE)
reghdfe D1CSR_score SRSWF_hold $controls, absorb(ID ProvinceCode YEAR)
eststo m3_id_prov_year

* Model 4: ID + IndustryCode + ProvinceCode + YEAR (最全 FE)
reghdfe D1CSR_score SRSWF_hold $controls, absorb(ID IndustryCode ProvinceCode YEAR)
eststo m4_id_ind_prov_year

* Model 5: IndustryCode + YEAR (不吸 ID，作为参照)
reghdfe D1CSR_score SRSWF_hold $controls, absorb(IndustryCode YEAR)
eststo m5_ind_year

esttab m1_idyear m2_id_ind_year m3_id_prov_year m4_id_ind_prov_year m5_ind_year ///
    using "$outdir\Table_H1_FE_Specifications.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold CSR_score) ///
    title("H1: SRSWF_hold -> D1CSR_score, 不同 FE 规格")

*====================================================
* Round 1: H2 检验 -- 评价模糊性调节效应
*====================================================
di _n "*********************************************"
di "*** Round 1: H2 -- 评价模糊性调节 (ID+YEAR FE)"
di "*********************************************"
eststo clear

* Model H2-1: 主调节变量 (标准差, lagged)
reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_sd $controls, absorb(ID YEAR)
eststo h2_1

* Model H2-2: 调节变量 (极差, lagged)
reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_range $controls, absorb(ID YEAR)
eststo h2_2

* Model H2-3: 调节变量 (平均成对差异, lagged)
reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_apd $controls, absorb(ID YEAR)
eststo h2_3

* Model H2-4: 调节变量 (剔除G的标准差, lagged)
reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_ES_sd $controls, absorb(ID YEAR)
eststo h2_4

esttab h2_1 h2_2 h2_3 h2_4 ///
    using "$outdir\Table_H2_Moderation_Ambiguity.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold c.SRSWF_hold#c.L1CSR_ambig_sd c.SRSWF_hold#c.L1CSR_ambig_range c.SRSWF_hold#c.L1CSR_ambig_apd c.SRSWF_hold#c.L1CSR_ambig_ES_sd) ///
    title("H2: 评价模糊性的调节效应 (ID+YEAR FE)")

*====================================================
* 稳健性：替代因变量
*====================================================
di _n "*********************************************"
di "*** 稳健性：替代因变量 (ID+YEAR FE)"
di "*********************************************"
eststo clear

* R1: 和讯 CSR 增量
reghdfe D1HXCSR_score SRSWF_hold $controls, absorb(ID YEAR)
eststo r_dv1

* R2: Bloomberg ESG 增量
reghdfe D1ESG_blomscore SRSWF_hold $controls, absorb(ID YEAR)
eststo r_dv2

* R3: 华证 ESG 增量
reghdfe D1ESG_huascore SRSWF_hold $controls, absorb(ID YEAR)
eststo r_dv3

* R4: 华证 E/S 均值增量（剔除G）
reghdfe D1HZ_ES_score SRSWF_hold $controls, absorb(ID YEAR)
eststo r_dv4

esttab r_dv1 r_dv2 r_dv3 r_dv4 ///
    using "$outdir\Table_Robustness_Alternative_DV.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    title("稳健性: 替代因变量 (ID+YEAR FE)")

*====================================================
* 稳健性：调节变量多口径（和讯 CSR 作为 DV）
*====================================================
di _n "*********************************************"
di "*** 稳健性: 和讯CSR作为DV时的调节效应"
di "*********************************************"
eststo clear

reghdfe D1HXCSR_score c.SRSWF_hold##c.L1CSR_ambig_sd $controls, absorb(ID YEAR)
eststo mod_hx1

reghdfe D1HXCSR_score c.SRSWF_hold##c.L1CSR_ambig_ES_sd $controls, absorb(ID YEAR)
eststo mod_hx2

esttab mod_hx1 mod_hx2 ///
    using "$outdir\Table_H2_Robustness_HXCSR_DV.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold c.SRSWF_hold#c.L1CSR_ambig_sd) ///
    title("H2 稳健性: 和讯CSR增量作为因变量")

*====================================================
* 尝试替代的模糊性构造（重新构造）
* 不把构造因变量的指数纳入调节变量
*====================================================
di _n "*********************************************"
di "*** 替代模糊性: 仅用两个非DV指数构造"
di "*********************************************"

* 为润灵CSR作为DV时，用和讯CSR+华证ESG构造模糊性
* 为和讯CSR作为DV时，用润灵CSR+华证ESG构造模糊性
* 或：全部三个指数都纳入（当前做法）

* 构造仅两个评分的模糊性（用于润灵CSR作为DV时）
* 当前主DV是润灵CSR，所以用和讯CSR + 华证ESG构造替代模糊性
capture drop CSR_ambig_HX_HZ_sd CSR_ambig_HX_HZ_n
capture drop L1CSR_ambig_HX_HZ_sd

* 标准化（已在数据中）
bysort YEAR: egen mean_HX_y = mean(HXCSR_score)
bysort YEAR: egen sd_HX_y = sd(HXCSR_score)
gen z_HX_temp = (HXCSR_score - mean_HX_y) / sd_HX_y if sd_HX_y > 0

bysort YEAR: egen mean_HZ_y = mean(ESG_huascore)
bysort YEAR: egen sd_HZ_y = sd(ESG_huascore)
gen z_HZ_temp = (ESG_huascore - mean_HZ_y) / sd_HZ_y if sd_HZ_y > 0

egen CSR_ambig_HX_HZ_n = rownonmiss(z_HX_temp z_HZ_temp)
egen CSR_ambig_HX_HZ_sd = rowsd(z_HX_temp z_HZ_temp)
replace CSR_ambig_HX_HZ_sd = . if CSR_ambig_HX_HZ_n < 2
label var CSR_ambig_HX_HZ_sd "仅和讯+华证(不含润灵)的模糊性标准差"

sort ID YEAR
gen L1CSR_ambig_HX_HZ_sd = L.CSR_ambig_HX_HZ_sd

drop mean_HX_y sd_HX_y z_HX_temp mean_HZ_y sd_HZ_y z_HZ_temp

di _n ">> H1 + 替代模糊性调节 (和讯+华证构造, 润灵CSR作为DV)"
eststo clear

reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_HX_HZ_sd $controls, absorb(ID YEAR)
eststo h2_alt1

reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_sd $controls, absorb(ID YEAR)
eststo h2_alt2

esttab h2_alt1 h2_alt2 ///
    using "$outdir\Table_H2_Alternative_Ambiguity_Construction.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold c.SRSWF_hold#c.L1CSR_ambig_HX_HZ_sd c.SRSWF_hold#c.L1CSR_ambig_sd) ///
    mtitles("仅和讯+华证" "三个指数全部") ///
    title("H2 稳健性: 替代模糊性构造方式对比")

*====================================================
* SRSWF_count 替代处理变量
*====================================================
di _n "*********************************************"
di "*** 替代处理: SRSWF_count 和 SRSWF_owns"
di "*********************************************"
eststo clear

reghdfe D1CSR_score SRSWF_count SRSWF_owns $controls, absorb(ID YEAR)
eststo treat_alt1

reghdfe D1CSR_score SRSWF_count $controls, absorb(ID YEAR)
eststo treat_alt2

reghdfe D1CSR_score SRSWF_owns $controls if SRSWF_hold==1, absorb(ID YEAR)
eststo treat_alt3

esttab treat_alt1 treat_alt2 treat_alt3 ///
    using "$outdir\Table_Treatment_Alternative_Measures.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_count SRSWF_owns) ///
    title("稳健性: 替代处理变量构造")

*====================================================
* IV 内生性检验（简化版，仅主模型）
*====================================================
di _n "*********************************************"
di "*** IV 内生性检验"
di "*********************************************"
eststo clear

* 使用 FOREIGN_REGISTER 作为主 IV
capture noisily ivreghdfe D1CSR_score $controls (SRSWF_hold = FOREIGN_REGISTER), ///
    absorb(ID YEAR) first
if _rc==0 {
    eststo iv_main
}

* 使用 IFDI_TRADE 作为备选 IV
capture noisily ivreghdfe D1CSR_score $controls (SRSWF_hold = IFDI_TRADE), ///
    absorb(ID YEAR) first
if _rc==0 {
    eststo iv_alt
}

capture esttab iv_main iv_alt ///
    using "$outdir\Table_IV_Endogeneity.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    title("IV: 内生性检验")

*====================================================
* 保存结果
*====================================================
save "$outdir\round1_panel.dta", replace

di _n "============================================="
di "*** Round 1 完成！"
di "*** 结果保存在: $outdir"
di "============================================="

log close
exit
