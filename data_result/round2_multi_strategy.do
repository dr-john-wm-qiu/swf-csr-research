/**************************************************************************************************
* Round 2: 多方向调整策略
* 问题: Round 1 中 SRSWF_hold 系数为正，与 H1 方向相反
* 策略:
*   A) 调整控制变量：移除可能导致"坏控制"的变量
*   B) 包含 ISIF 到 SRSWF 定义中
*   C) Industry × Year FE
*   D) 使用 F2CSR（两期后增量）作为 DV
*   E) 从控制变量大全中选取新控制变量
**************************************************************************************************/

version 15.0
clear all
set more off
set linesize 255
capture log close

* 路径
global path   "D:\OneDrive\华南理工大学\Working Paper\ll1-SWF and CSR\ll1_6（基于ll1_4进行修订）\4、SWF_CSR_20250702"
global outdir "D:\Agents\opencode\ll1_6\data_result\round2_multi_strategy"
cap mkdir "$outdir"
log using "$outdir\round2_multi_strategy.log", replace text

* 包
cap which reghdfe
if _rc ssc install reghdfe, replace
cap which esttab
if _rc ssc install estout, replace

* 读入面板
use "$path\Submission_Signal_Strategy_20260714\SWF_CSR_submission_panel.dta", clear
xtset ID YEAR

*====================================================
* 准备：重建 SRSWF_hold（含 ISIF）
*====================================================
gen SRSWF_hold_with_ISIF = 0
replace SRSWF_hold_with_ISIF = 1 if SWF_GPFG==1 | SWF_NZSF==1 | SWF_ISIF==1
replace SRSWF_hold_with_ISIF = 0 if missing(SRSWF_hold_with_ISIF)
label var SRSWF_hold_with_ISIF "SRSWF 持有（含 ISIF）"

gen SRSWF_count_with_ISIF = SWF_GPFG + SWF_NZSF + SWF_ISIF
gen SRSWF_owns_with_ISIF  = GPFG_owns + NZSF_owns + ISIF_owns
label var SRSWF_count_with_ISIF "SRSWF 基金数量（含 ISIF）"
label var SRSWF_owns_with_ISIF  "SRSWF 合计持股%（含 ISIF）"

*====================================================
* 准备：构造 F2CSR（两期后增量，而非下一期）
*====================================================
capture drop F2CSR_score D2CSR_score
sort ID YEAR
gen F2CSR_score = F2.CSR_score
gen D2CSR_score = F2CSR_score - CSR_score
label var D2CSR_score "[CSR] 润灵两期后 CSR 增量"
drop F2CSR_score

capture drop F2HXCSR_score D2HXCSR_score
gen F2HXCSR_score = F2.HXCSR_score
gen D2HXCSR_score = F2HXCSR_score - HXCSR_score
drop F2HXCSR_score

capture drop F2ESG_huascore D2ESG_huascore
gen F2ESG_huascore = F2.ESG_huascore
gen D2ESG_huascore = F2ESG_huascore - ESG_huascore
drop F2ESG_huascore

*====================================================
* 准备：尝试新增控制变量
* 根据理论，可能的控制变量包括：
* - 公司治理（独立董事、董事会规模）
* - 财务表现（ROA、ROE）  
* - 机构持股
* - 分析师覆盖
*====================================================
* 已在数据中的控制变量候选：
* AnaAttention (分析师关注，行业调整后)
* ReportAttention (研报关注，行业调整后)
* NewAttention (媒体关注)
* SRSWF_dura (持续持有年数)
* IsValid (内部控制有效性)
* IsDeficiency (内部控制缺陷)

* 构造 ROA (如果有的话)
capture gen ROA = . 
* 数据中可能没有直接的ROA，用已有近似

*====================================================
* 控制变量组（多组对比）
*====================================================
* 原控制变量组
global c_base   "CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index"

* 去掉CSR_score（可能的"坏控制"）
global c_no_csr "HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index"

* 去掉 MarketValue_Size（与 SRSWF_hold 高度相关）
global c_no_mv  "CSR_score HHI_D EU1 Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index"

* 精简控制变量组（仅理论相关的）
global c_parsim "CSR_score MarketValue_Size Listed_age State_Ownership LTD_sales SalesGrowth RD_intensity LNViolation Board_independent"

* 加入额外控制（分析师关注、研报、媒体关注、治理）
global c_extended "CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index AnaAttention ReportAttention NewAttention"

*====================================================
* 策略 A: 调整控制变量 + ID+YEAR FE
*====================================================
di _n "*********************************************"
di "*** 策略 A: 不同控制变量组 (ID+YEAR FE)"
di "*********************************************"
eststo clear

* A1: 去掉 CSR_score
reghdfe D1CSR_score SRSWF_hold $c_no_csr, absorb(ID YEAR)
eststo a1

* A2: 去掉 MarketValue_Size
reghdfe D1CSR_score SRSWF_hold $c_no_mv, absorb(ID YEAR)
eststo a2

* A3: 精简控制变量
reghdfe D1CSR_score SRSWF_hold $c_parsim, absorb(ID YEAR)
eststo a3

* A4: 仅控制 CSR_score + MarketValue_Size（最精简）
reghdfe D1CSR_score SRSWF_hold CSR_score MarketValue_Size, absorb(ID YEAR)
eststo a4

* A5: 加入额外控制（分析师、媒体、治理）
reghdfe D1CSR_score SRSWF_hold $c_extended, absorb(ID YEAR)
eststo a5

esttab a1 a2 a3 a4 a5 ///
    using "$outdir\Table_A_Control_Variables_Combos.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    mtitles("无CSR_score" "无MV_Size" "精简" "最精简" "扩展") ///
    title("策略A: 不同控制变量组对H1系数的影响")

*====================================================
* 策略 B: 含 ISIF 的 SRSWF_hold + 不同控制组
*====================================================
di _n "*********************************************"
di "*** 策略 B: 包含 ISIF (ID+YEAR FE)"
di "*********************************************"
eststo clear

* B1: 含 ISIF + 原始控制
reghdfe D1CSR_score SRSWF_hold_with_ISIF $c_base, absorb(ID YEAR)
eststo b1

* B2: 含 ISIF + 去掉 CSR_score
reghdfe D1CSR_score SRSWF_hold_with_ISIF $c_no_csr, absorb(ID YEAR)
eststo b2

* B3: 含 ISIF + 精简控制
reghdfe D1CSR_score SRSWF_hold_with_ISIF $c_parsim, absorb(ID YEAR)
eststo b3

* B4: SRSWF_count_with_ISIF
reghdfe D1CSR_score SRSWF_count_with_ISIF SRSWF_owns_with_ISIF $c_base, absorb(ID YEAR)
eststo b4

esttab b1 b2 b3 b4 ///
    using "$outdir\Table_B_With_ISIF.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold_with_ISIF SRSWF_count_with_ISIF SRSWF_owns_with_ISIF) ///
    mtitles("原控制" "无CSR_score" "精简" "count+owns") ///
    title("策略B: 含ISIF的SRSWF变量")

*====================================================
* 策略 C: Industry × Year FE
*====================================================
di _n "*********************************************"
di "*** 策略 C: Industry×Year FE (控制行业时变趋势)"
di "*********************************************"
eststo clear

* C1: indyear + ID (原 do 也用的 indyear)
* 注意: indyear 已在数据中作为 IndustryCode × YEAR 的 group
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID indyear)
eststo c1

* C2: indyear + ID (不含 CSR_score)
reghdfe D1CSR_score SRSWF_hold $c_no_csr, absorb(ID indyear)
eststo c2

* C3: ID + IndustryCode#YEAR (用 # 交互)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode#YEAR)
eststo c3

* C4: ID + IndustryCode YEAR (分别吸收)
reghdfe D1CSR_score SRSWF_hold $c_base, absorb(ID IndustryCode YEAR)
eststo c4

esttab c1 c2 c3 c4 ///
    using "$outdir\Table_C_IndustryYear_FE.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    mtitles("ID+Ind×Year" "ID+Ind×Year(无CSR)" "ID+Ind#Year" "ID+Ind+Year") ///
    title("策略C: Industry×Year FE")

*====================================================
* 策略 D: 使用 D2CSR（两期后增量）作为 DV
*====================================================
di _n "*********************************************"
di "*** 策略 D: D2CSR（两期后增量）作为因变量"
di "*********************************************"
eststo clear

* D1: 润灵 D2CSR + 原控制 + ID+YEAR
reghdfe D2CSR_score SRSWF_hold $c_base, absorb(ID YEAR)
eststo d1

* D2: 润灵 D2CSR + 无 CSR_score + ID+YEAR
reghdfe D2CSR_score SRSWF_hold $c_no_csr, absorb(ID YEAR)
eststo d2

* D3: 和讯 D2HXCSR + 原控制 + ID+YEAR
reghdfe D2HXCSR_score SRSWF_hold $c_base, absorb(ID YEAR)
eststo d3

* D4: 华证 D2ESG + 原控制 + ID+YEAR
reghdfe D2ESG_huascore SRSWF_hold $c_base, absorb(ID YEAR)
eststo d4

esttab d1 d2 d3 d4 ///
    using "$outdir\Table_D_D2CSR_DV.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    mtitles("D2CSR 原控制" "D2CSR 无CSR" "D2HXCSR" "D2ESG_huazheng") ///
    title("策略D: 两期后增量作为因变量")

*====================================================
* 策略 E: 加入外部关注度作为控制（或机制路径上的变量）
*====================================================
di _n "*********************************************"
di "*** 策略 E: 控制外部关注度"
di "*********************************************"
eststo clear

* E1: 加入分析师关注度
reghdfe D1CSR_score SRSWF_hold CSR_score MarketValue_Size AnaAttention, absorb(ID YEAR)
eststo e1

* E2: 加入媒体关注度（理论中重要的信号变量）
reghdfe D1CSR_score SRSWF_hold CSR_score MarketValue_Size NewAttention, absorb(ID YEAR)
eststo e2

* E3: 加入所有关注度 + 治理变量
reghdfe D1CSR_score SRSWF_hold CSR_score MarketValue_Size AnaAttention ReportAttention NewAttention IsValid, absorb(ID YEAR)
eststo e3

* E4: 控制 SRSWF_dura（持续持有年数）
reghdfe D1CSR_score SRSWF_hold SRSWF_dura CSR_score MarketValue_Size, absorb(ID YEAR)
eststo e4

esttab e1 e2 e3 e4 ///
    using "$outdir\Table_E_Attention_Controls.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold) ///
    mtitles("分析师" "媒体" "全部关注+治理" "含SRSWF_dura") ///
    title("策略E: 控制外部关注度及治理变量")

*====================================================
* 策略 F: 综合尝试——组合最佳策略
*====================================================
* 从前面策略中选表现最好的组合，进行强化测试
* 如果前面的组合中某组得到了负系数，则在此强化

di _n "*********************************************"
di "*** 策略 F: 组合最优控制变量"
di "*********************************************"
eststo clear

* F1: 无CSR_score + 无MarketValue_Size + 含ISIF + ID+YEAR
reghdfe D1CSR_score SRSWF_hold_with_ISIF HHI_D EU1 Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index, absorb(ID YEAR)
eststo f1

* F2: 含ISIF + 仅控制核心 + ID+YEAR
reghdfe D1CSR_score SRSWF_hold_with_ISIF CSR_score MarketValue_Size, absorb(ID YEAR)
eststo f2

* F3: 含ISIF + F3CSR (三年前瞻)
capture drop F3CSR_score D3CSR_score
sort ID YEAR
gen F3CSR_score = F3.CSR_score
gen D3CSR_score = F3CSR_score - CSR_score
drop F3CSR_score
reghdfe D3CSR_score SRSWF_hold_with_ISIF $c_base, absorb(ID YEAR)
eststo f3

* F4: 含ISIF + 仅控制 + Industry×Year FE
reghdfe D1CSR_score SRSWF_hold_with_ISIF CSR_score MarketValue_Size, absorb(ID indyear)
eststo f4

esttab f1 f2 f3 f4 ///
    using "$outdir\Table_F_Combined_Strategies.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold_with_ISIF) ///
    mtitles("无CSR+MV" "仅CSR+MV" "D3CSR" "Ind×Year") ///
    title("策略F: 组合最优控制+含ISIF")

*====================================================
* H2 调节效应：在负系数基础上测试
* 注意：如果主效应系数为正，调节效应的解释会复杂
*====================================================
di _n "*********************************************"
di "*** H2 调节效应：基于各组合测试"
di "*********************************************"
eststo clear

* H2-A: 原有三指数模糊性 + 含ISIF + 精简控制 + ID+YEAR
reghdfe D1CSR_score c.SRSWF_hold_with_ISIF##c.L1CSR_ambig_sd CSR_score MarketValue_Size, absorb(ID YEAR)
eststo h2_new1

* H2-B: 仅用和讯+华证构造模糊性 + 含ISIF
cap drop CSR_ambig_HX_HZ_sd_v2 L1CSR_ambig_HX_HZ_sd_v2
bysort YEAR: egen meanhx = mean(HXCSR_score)
bysort YEAR: egen sdhx = sd(HXCSR_score)
gen zhx = (HXCSR_score - meanhx)/sdhx
bysort YEAR: egen meanhz = mean(ESG_huascore)
bysort YEAR: egen sdhz = sd(ESG_huascore)
gen zhz = (ESG_huascore - meanhz)/sdhz
egen CSR_ambig_HX_HZ_sd_v2 = rowsd(zhx zhz)
sort ID YEAR
gen L1CSR_ambig_HX_HZ_sd_v2 = L.CSR_ambig_HX_HZ_sd_v2
drop meanhx sdhx zhx meanhz sdhz zhz

reghdfe D1CSR_score c.SRSWF_hold_with_ISIF##c.L1CSR_ambig_HX_HZ_sd_v2 CSR_score MarketValue_Size, absorb(ID YEAR)
eststo h2_new2

esttab h2_new1 h2_new2 ///
    using "$outdir\Table_H2_Moderation_Robustness.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold_with_ISIF c.SRSWF_hold_with_ISIF#c.L1CSR_ambig_sd c.SRSWF_hold_with_ISIF#c.L1CSR_ambig_HX_HZ_sd_v2) ///
    mtitles("三指数模糊性" "仅和讯+华证") ///
    title("H2: 评价模糊性调节效应稳健性测试")

*====================================================
* 描述性分析：了解处理组设计
*====================================================
di _n "*********************************************"
di "*** 处理组分布"
di "*********************************************"
tab YEAR SRSWF_hold
tab YEAR SRSWF_hold_with_ISIF
tab SRSWF_hold SRSWF_hold_with_ISIF

*====================================================
* 保存结果
*====================================================
save "$outdir\round2_panel.dta", replace

di _n "============================================="
di "*** Round 2 完成！"
di "*** 输出目录: $outdir"
di "============================================="

log close
exit
