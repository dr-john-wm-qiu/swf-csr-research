/**************************************************************************************************
* 项目：SWF × CSR（社会责任型主权财富基金的“认证—压力释放”机制）
* 版本：Stata 15.0
* 用途：在你现有的基础数据结构与原始 do 文件逻辑之上，重写为：
*       1) 以 CSR“下一期增量/升级幅度”为核心因变量；
*       2) 以 GPFG / NZSF / ISIF 的持股认证为核心解释变量；
*       3) 同时实现：基准 FE、首次进入 DID、动态事件研究、机制检验、异质性检验、稳健性检验。
*
* 重要识别说明：
*   - 基准回归使用“当前是否被持有” (SRSWF_hold)。
*   - DID / CSDID 事件研究把“首次进入”解释为“首次公开认证(first endorsement)”；
*     自首次进入起，认证地位被视为持续存在。因此，post_treat 与 first_treat 采用吸收式定义。
*   - 这样做是为了适配 staggered adoption 的识别框架，并与“认证导致感知充分性(perceived adequacy)”的理论一致。
*
* 运行前请检查：
*   - 所有 using 数据路径是否仍与你本机一致；
*   - 原始数据文件命名是否发生变化；
*   - 如果你的结果目录不同，请修改下方 global 宏。
**************************************************************************************************/

version 15.0
clear all
set more off
set linesize 255
capture log close

*----------------------------------*
* 0. 路径设置
*----------------------------------*
global path "D:\OneDrive\华南理工大学\Working Paper\ll1-SWF and CSR\ll1_6（基于ll1_4进行修订）\4、SWF_CSR_20250702"
global outdir "$path\Submission_Signal_Strategy_20260714"
cap mkdir "$outdir"
cd "$path"
log using "$outdir\SWF_CSR_submission_signal_strategy.log", replace text

*----------------------------------*
* 1. 安装所需外部命令（Stata 15.0 可用）
*----------------------------------*
cap which ftools
if _rc ssc install ftools, replace

cap which reghdfe
if _rc ssc install reghdfe, replace

cap which winsor2
if _rc ssc install winsor2, replace

cap which esttab
if _rc ssc install estout, replace

cap which coefplot
if _rc ssc install coefplot, replace

cap which drdid
if _rc ssc install drdid, all replace

cap which csdid
if _rc ssc install csdid, all replace

cap which event_plot
if _rc ssc install event_plot, replace

cap which ivreg2
if _rc ssc install ivreg2, replace

cap which ivreghdfe
if _rc ssc install ivreghdfe, replace

*----------------------------------*
* 2. 读入基础面板并设置 panel
*----------------------------------*
use "$path\Sample_20240925.dta", clear
sort ID YEAR
xtset ID YEAR

*----------------------------------*
* 3. 合并 CSR / ESG 指标
*----------------------------------*

* 3.1 和讯 CSR 评分（主稳健性之一）
merge 1:1 ID YEAR using "$path\Data_warehouse\和讯网社会责任评分\CSR_final_20211008.dta", ///
    keepusing(industryreate stockNumber lootingchips Scramble rscrabmle Strongstock)
drop if _merge==2
drop _merge
sort ID YEAR
xtset ID YEAR

gen F1HXCSR_score = F1.industryreate
gen D1HXCSR_score = F1.industryreate - industryreate
rename industryreate HXCSR_score
label var HXCSR_score   "[CSR] 和讯当期 CSR 评分"
label var F1HXCSR_score "[CSR] 和讯下一期 CSR 评分"
label var D1HXCSR_score "[CSR] 和讯下一期 CSR 增量"

gen F1HXCSR_holder   = F1.stockNumber
gen F1HXCSR_staff    = F1.lootingchips
gen F1HXCSR_external = F1.Scramble
gen F1HXCSR_env      = F1.rscrabmle
gen F1HXCSR_soc      = F1.Strongstock

drop stockNumber lootingchips Scramble rscrabmle Strongstock
bysort IndustryCode YEAR: egen mean_HXCSR = mean(F1HXCSR_score)
gen F1HXCSR_adj = F1HXCSR_score - mean_HXCSR
drop mean_HXCSR

* 3.2 润灵 CSR 评分（主因变量）
merge 1:1 ID YEAR using "$path\Data_warehouse\润灵环球CSR_2009_2019.dta", keepusing(CSR_score M C T)
drop if _merge==2
drop _merge
sort ID YEAR
xtset ID YEAR

gen F1CSR_score = F1.CSR_score
gen D1CSR_score = F1.CSR_score - CSR_score
label var CSR_score   "[CSR] 润灵当期 CSR 评分"
label var F1CSR_score "[CSR] 润灵下一期 CSR 评分"
label var D1CSR_score "[CSR] 润灵下一期 CSR 增量"

* 3.3 Bloomberg ESG 评分（另一稳健性）
gen stkcd = ID
gen year  = YEAR
merge 1:1 stkcd year using "$path\Data_warehouse\2011-2021彭博ESG.dta", keepusing(ESG)
drop if _merge==2
drop _merge stkcd year
sort ID YEAR
xtset ID YEAR

gen F1ESG_blomscore = F1.ESG
gen D1ESG_blomscore = F1.ESG - ESG
rename ESG ESG_blomscore
label var ESG_blomscore   "[ESG] Bloomberg 当期 ESG 评分"
label var F1ESG_blomscore "[ESG] Bloomberg 下一期 ESG 评分"
label var D1ESG_blomscore "[ESG] Bloomberg 下一期 ESG 增量"

* 3.4 华证 ESG 评分（另一稳健性；同时保留 E/S/G 分项以支持剔除 G 的调节变量稳健性）
gen year  = YEAR
merge 1:1 ID year using "$path\Data_warehouse\华证ESG.dta", keepusing(综合得分 E得分 S得分 G得分 e_j s_j g_j)
drop if _merge==2
drop _merge year
sort ID YEAR
xtset ID YEAR

capture confirm variable E得分
if _rc==0 rename E得分 HZ_E_score
capture confirm variable S得分
if _rc==0 rename S得分 HZ_S_score
capture confirm variable G得分
if _rc==0 rename G得分 HZ_G_score
capture confirm variable e_j
if _rc==0 rename e_j HZ_E_z_raw
capture confirm variable s_j
if _rc==0 rename s_j HZ_S_z_raw
capture confirm variable g_j
if _rc==0 rename g_j HZ_G_z_raw

capture confirm variable HZ_E_score
if _rc!=0 gen HZ_E_score = .
capture confirm variable HZ_S_score
if _rc!=0 gen HZ_S_score = .
capture confirm variable HZ_G_score
if _rc!=0 gen HZ_G_score = .

gen F1ESG_huascore = F1.综合得分
gen D1ESG_huascore = F1.综合得分 - 综合得分
rename 综合得分 ESG_huascore
label var ESG_huascore   "[ESG] 华证当期 ESG 综合评分"
label var F1ESG_huascore "[ESG] 华证下一期 ESG 综合评分"
label var D1ESG_huascore "[ESG] 华证下一期 ESG 综合增量"

capture drop HZ_ES_score F1HZ_ES_score D1HZ_ES_score
capture confirm variable HZ_E_score
if _rc==0 {
    egen HZ_ES_score = rowmean(HZ_E_score HZ_S_score)
    gen F1HZ_ES_score = F1.HZ_ES_score
    gen D1HZ_ES_score = F1.HZ_ES_score - HZ_ES_score
}
else {
    gen HZ_ES_score = .
    gen F1HZ_ES_score = .
    gen D1HZ_ES_score = .
}
label var HZ_ES_score   "[ESG] 华证 E/S 均值评分（剔除 G）"
label var F1HZ_ES_score "[ESG] 华证下一期 E/S 均值评分（剔除 G）"
label var D1HZ_ES_score "[ESG] 华证下一期 E/S 均值增量（剔除 G）"

*----------------------------------*
* 4. 合并两只社会责任型 SWF 持股信息
*----------------------------------*

* 4.1 GPFG（挪威）
merge 1:1 ID YEAR using "$path\Data_warehouse\挪威国家主权财富基金_A股_1998_2022_Equity(Voting Ownership).dta", keepusing(Voting Ownership)
drop if _merge==2
drop _merge
rename Voting    GPFG_vote
rename Ownership GPFG_owns
replace GPFG_vote = 0   if GPFG_vote < 0  & GPFG_vote < .
replace GPFG_vote = 100 if GPFG_vote > 100 & GPFG_vote < .
replace GPFG_owns = 0   if GPFG_owns < 0  & GPFG_owns < .
replace GPFG_owns = 100 if GPFG_owns > 100 & GPFG_owns < .
replace GPFG_vote = 0 if missing(GPFG_vote) & inrange(YEAR,2004,2022)
replace GPFG_owns = 0 if missing(GPFG_owns) & inrange(YEAR,2004,2022)
gen SWF_GPFG = (GPFG_owns>0) if inrange(YEAR,2004,2022)
replace SWF_GPFG = 0 if missing(SWF_GPFG) & inrange(YEAR,2004,2022)
label var GPFG_vote "[GPFG] 投票权(%)"
label var GPFG_owns "[GPFG] 持股比例(%)"
label var SWF_GPFG "[GPFG] 是否持股"

* 4.2 NZSF（新西兰）
merge 1:1 ID YEAR using "$path\Data_warehouse\SWF Global-sovereign wealth fund\SWF_NZSF.dta", keepusing(SWF_NZSF VALUE_NZD)
drop if _merge==2
drop _merge
replace SWF_NZSF = 0 if missing(SWF_NZSF) & inrange(YEAR,2004,2022)
replace VALUE_NZD = 0 if missing(VALUE_NZD) & inrange(YEAR,2004,2022)

gen CountryName = "新西兰" if SWF_NZSF==1
merge m:1 CountryName YEAR using "D:\OneDrive\华南理工大学\Data\CSMAR\source\汇率(CountryName EXG_RATE).dta", keepusing(EXG_RATE)
drop if _merge==2
drop _merge

gen VALUE_CNY = VALUE_NZD * EXG_RATE

merge 1:1 ID YEAR using "D:\OneDrive\华南理工大学\Data\CSMAR\source\股本结构文件\总股数(Nshrttl).dta", keepusing(Nshrttl)
drop if _merge==2
drop _merge

merge 1:1 ID YEAR using "D:\OneDrive\华南理工大学\Data\CSMAR\processed\公司年平均每股股价(PRC_YEAR).dta", keepusing(PRC_YEAR)
drop if _merge==2
drop _merge

gen FirmMV_CNY = PRC_YEAR * Nshrttl

* 重要修正：原 do 文件先计算 VALUE_CNY，但后续用 VALUE_NZD / SharePrice。
* 如果汇率 EXG_RATE 是 NZD→CNY，则应使用 VALUE_CNY / FirmMV_CNY。
gen NZSF_owns = VALUE_CNY / FirmMV_CNY
replace NZSF_owns = 0 if NZSF_owns < 0 & NZSF_owns < .
replace NZSF_owns = 1 if NZSF_owns > 1 & NZSF_owns < .
replace NZSF_owns = 0 if missing(NZSF_owns) & inrange(YEAR,2004,2022)
replace NZSF_owns = NZSF_owns * 100
label var SWF_NZSF "[NZSF] 是否持股"
label var NZSF_owns "[NZSF] 持股比例(%)"

drop CountryName EXG_RATE VALUE_NZD VALUE_CNY PRC_YEAR FirmMV_CNY

* 4.3 ISIF（爱尔兰）【备用】
merge 1:1 ID YEAR using "$path\Data_warehouse\SWF Global-sovereign wealth fund\SWF_ISIF.dta", keepusing(SWF_ISIF Holding)
drop if _merge==2
drop _merge
replace SWF_ISIF = 0 if missing(SWF_ISIF) & inrange(YEAR,2004,2022)

gen ISIF_owns = Holding / Nshrttl
replace ISIF_owns = 0 if ISIF_owns < 0 & ISIF_owns < .
replace ISIF_owns = 1 if ISIF_owns > 1 & ISIF_owns < .
replace ISIF_owns = 0 if missing(ISIF_owns) & inrange(YEAR,2004,2022)
replace ISIF_owns = ISIF_owns * 100
label var SWF_ISIF "[ISIF] 是否持股"
label var ISIF_owns "[ISIF] 持股比例(%)"

drop Holding

* 4.4 合并三只基金为“社会责任型 SWF”认证变量
gen SRSWF_hold = 0
replace SRSWF_hold = 1 if SWF_GPFG==1 | SWF_NZSF==1
replace SRSWF_hold = 0 if missing(SRSWF_hold)

gen SRSWF_count = SWF_GPFG + SWF_NZSF
gen SRSWF_owns  = GPFG_owns + NZSF_owns
label var SRSWF_hold  "[SRSWF] 是否被 GPFG/NZSF/ISIF 持有"
label var SRSWF_count "[SRSWF] 同时持有的基金数量"
label var SRSWF_owns  "[SRSWF] 三只基金合计持股比例(%)"

sort ID YEAR
xtset ID YEAR

gen SRSWF_entry = (SRSWF_hold==1 & L.SRSWF_hold==0) if !missing(SRSWF_hold, L.SRSWF_hold)
replace SRSWF_entry = 0 if missing(SRSWF_entry)
label var SRSWF_entry "[SRSWF] 首次/再次进入当年"

bysort ID: egen first_treat = min(cond(SRSWF_entry==1, YEAR, .))
gen ever_treated = (first_treat<.)
replace first_treat = 0 if !ever_treated
label var first_treat "首次被社会责任型 SWF 持有的年份(未处理=0)"

gen post_treat = (YEAR>=first_treat & first_treat>0)
replace post_treat = 0 if missing(post_treat)
label var post_treat "首次认证后的持续期(吸收式)"

gen rel_time = YEAR - first_treat if first_treat>0
label var rel_time "相对首次认证年份"

* 连续持有时长（当前持有状态下）
gen SRSWF_dura = 0
bysort ID (YEAR): replace SRSWF_dura = cond(_n==1, SRSWF_hold, cond(SRSWF_hold==1, L.SRSWF_dura + 1, 0))
label var SRSWF_dura "[SRSWF] 当前连续持有年数"

*----------------------------------*
* 5. 合并外部关注、违规与机制变量
*----------------------------------*

* 分析师与研报关注度
merge 1:1 Stkcd Accper using "$path\Data_warehouse\上市公司基本情况-上市公司基本信息特色指标表-20210409\上市公司基本情况-上市公司基本信息特色指标表-20210409.dta", keepusing(AnaAttention ReportAttention)
drop if _merge==2
drop _merge
bysort IndustryCode YEAR: egen mean_Ana = mean(AnaAttention)
replace AnaAttention = AnaAttention - mean_Ana if AnaAttention < .
drop mean_Ana
bysort IndustryCode YEAR: egen mean_Rep = mean(ReportAttention)
replace ReportAttention = ReportAttention - mean_Rep if ReportAttention < .
drop mean_Rep
label var AnaAttention    "[关注度] 分析师关注（行业-年调整后）"
label var ReportAttention "[关注度] 研报关注（行业-年调整后）"

* 媒体关注度
merge 1:1 ID YEAR using "$path\Data_warehouse\报刊媒体关注度(Newsnum_Cont_year).dta", keepusing(Newsnum_Cont_year)
drop if _merge==2
drop _merge
rename Newsnum_Cont_year News_print

merge 1:1 ID YEAR using "$path\Data_warehouse\网络媒体关注度(Newsnum_Cont_year).dta", keepusing(Newsnum_Cont_year)
drop if _merge==2
drop _merge
rename Newsnum_Cont_year News_web

gen NewAttention = ln(News_print + News_web + 1)
label var NewAttention "[关注度] 总媒体关注 ln(1+print+web)"

* 违规信息
merge 1:1 ID YEAR using "$path\Data_warehouse\违规信息统计(Violation).dta", keepusing(Violation)
drop if _merge==2
drop _merge
replace Violation = 0 if missing(Violation)
gen LNViolation = ln(Violation + 1)
label var LNViolation "[违规] ln(1+违规次数)"

* 内部控制（可选稳健性）
merge 1:1 ID YEAR using "$path\Data_warehouse\内部控制(IsValid IsDeficiency).dta", keepusing(IsValid IsDeficiency)
drop if _merge==2
drop _merge

*----------------------------------*
* 5.1 工具变量候选变量：参照原始 SWF_CSR_20260424.do
*----------------------------------*
* 说明：以下变量只作为 IV / first-stage 诊断使用，不进入主效应控制项。
* FOREIGN_REGISTER 沿用原 do 文件的构造：省份-年份外商投资企业登记数的一期滞后值 / 100000。
* TRADE_NOR 与 IFDI_TRADE 作为备选 IV / 外向开放环境稳健性工具。

sort ID YEAR
xtset ID YEAR

capture confirm variable Insti_envir
if _rc==0 {
    capture drop L1Insti_envir
    gen L1Insti_envir = L.Insti_envir
}
else {
    gen Insti_envir = .
    gen L1Insti_envir = .
}
label var L1Insti_envir "IV候选：滞后制度环境"

capture confirm variable ProvinceFullName
if _rc==0 {
    capture noisily merge m:1 ProvinceFullName YEAR using "$path\Data_warehouse\国家统计局数据\processed\各地区预估与挪威的进出口总额(TRADE_NOR1 TRADE_NOR2 TRADE_NOR3).dta", keepusing(TRADE_NOR TRADE_NOR1 TRADE_NOR2 TRADE_NOR3)
    if _rc==0 {
        drop if _merge==2
        drop _merge
        sort ID YEAR
        xtset ID YEAR
        capture drop L1TRADE_NOR_raw
        gen L1TRADE_NOR_raw = L.TRADE_NOR
        replace TRADE_NOR = ln(L1TRADE_NOR_raw) if L1TRADE_NOR_raw>0
        replace TRADE_NOR1 = ln(TRADE_NOR1) if TRADE_NOR1>0
        replace TRADE_NOR2 = ln(TRADE_NOR2) if TRADE_NOR2>0
        replace TRADE_NOR3 = ln(TRADE_NOR3) if TRADE_NOR3>0
    }
    else {
        capture drop TRADE_NOR TRADE_NOR1 TRADE_NOR2 TRADE_NOR3
        gen TRADE_NOR  = .
        gen TRADE_NOR1 = .
        gen TRADE_NOR2 = .
        gen TRADE_NOR3 = .
    }
}
else {
    gen TRADE_NOR  = .
    gen TRADE_NOR1 = .
    gen TRADE_NOR2 = .
    gen TRADE_NOR3 = .
}
label var TRADE_NOR "IV候选：省份-年份与挪威贸易额滞后对数"

capture confirm variable ProvinceFullName
if _rc==0 {
    capture noisily merge m:1 ProvinceFullName YEAR using "$path\Data_warehouse\国家统计局数据\source\对外贸易数据\外商投资企业年底注册登记情况-分省年度数据.dta", keepusing(登记情况)
    if _rc==0 {
        drop if _merge==2
        drop _merge
        capture drop FOREIGN_REGISTER
        rename 登记情况 FOREIGN_REGISTER_raw
        sort ID YEAR
        xtset ID YEAR
        capture drop L1FOREIGN_REGISTER_raw FOREIGN_REGISTER
        gen L1FOREIGN_REGISTER_raw = L.FOREIGN_REGISTER_raw
        gen FOREIGN_REGISTER = L1FOREIGN_REGISTER_raw/100000
    }
    else {
        capture drop FOREIGN_REGISTER
        gen FOREIGN_REGISTER = .
    }
}
else {
    gen FOREIGN_REGISTER = .
}
label var FOREIGN_REGISTER "IV主工具：省份外商投资企业登记数滞后值/100000"

capture confirm variable ProvinceFullName
if _rc==0 {
    capture noisily merge m:1 ProvinceFullName YEAR using "$path\Data_warehouse\国家统计局数据\source\对外贸易数据\外商投资企业货物进出口总额-分省年度数据.dta", keepusing(进出口总额)
    if _rc==0 {
        drop if _merge==2
        drop _merge
        capture drop IFDI_TRADE_raw IFDI_TRADE L1IFDI_TRADE_raw
        rename 进出口总额 IFDI_TRADE_raw
        sort ID YEAR
        xtset ID YEAR
        gen L1IFDI_TRADE_raw = L.IFDI_TRADE_raw
        gen IFDI_TRADE = ln(L1IFDI_TRADE_raw) if L1IFDI_TRADE_raw>0
    }
    else {
        capture drop IFDI_TRADE
        gen IFDI_TRADE = .
    }
}
else {
    gen IFDI_TRADE = .
}
label var IFDI_TRADE "IV候选：省份外资企业进出口额滞后对数"

sort ID YEAR
xtset ID YEAR

*----------------------------------*
* 6. 样本筛选
*----------------------------------*

* 高科技行业变量（暂不限制，但保留）
merge m:1 IndustryCode using "$path\Data_warehouse\高科技行业(High_tech).dta", keepusing(High_tech_1234 High_tech_01)
drop if _merge==2
drop _merge

* 删除金融业
drop if IndCode_1=="J"

* 保留 CSR 主样本可用年份（润灵为主）
keep if inrange(YEAR, 2009, 2019)

sort ID YEAR
xtset ID YEAR

*----------------------------------*
* 7. 生成机制变量、异质性变量与前瞻变化变量
*----------------------------------*

* 关注度的下一期变化：检验“认证是否降低外部压力”
gen D1AnaAttention    = F1.AnaAttention    - AnaAttention
gen D1ReportAttention = F1.ReportAttention - ReportAttention
gen D1NewAttention    = F1.NewAttention    - NewAttention
label var D1AnaAttention    "下一期分析师关注变化"
label var D1ReportAttention "下一期研报关注变化"
label var D1NewAttention    "下一期媒体关注变化"

* “认证大于治理” 的代理变量
* (1) 小持股：更接近认证而非强治理

gen SRSWF_owns_pos = SRSWF_owns if SRSWF_owns>0
bys YEAR: egen med_stake_y = median(SRSWF_owns_pos)
gen LowStewardship = (SRSWF_owns>0 & SRSWF_owns<=med_stake_y)
replace LowStewardship = 0 if SRSWF_hold==0
label var LowStewardship "低治理强度(小持股)"

* (2) 高基准 CSR：更容易形成“已足够”的感知
bys YEAR: egen med_csr_y = median(CSR_score)
gen HighPriorCSR = (CSR_score>=med_csr_y) if CSR_score<.
label var HighPriorCSR "高基准 CSR"

* (3) 低外部监控：认证更容易替代外部压力
bys YEAR: egen med_ana_y = median(AnaAttention)
gen LowExternalMonitor = (AnaAttention<=med_ana_y) if AnaAttention<.
label var LowExternalMonitor "低外部监控"

* (4) 组合代理：认证主导区间

gen CertDominates = (LowStewardship==1 & HighPriorCSR==1 & LowExternalMonitor==1) if !missing(LowStewardship, HighPriorCSR, LowExternalMonitor)
label var CertDominates "认证主导(小持股×高基准CSR×低外部监控)"

drop SRSWF_owns_pos med_stake_y med_csr_y med_ana_y

*----------------------------------*
* 8. 变量列表与缩尾
*----------------------------------*

global y_main   "D1CSR_score"
global y_alt1   "D1HXCSR_score"
global y_alt2   "D1ESG_blomscore"
global treat1   "SRSWF_hold"
global treat2   "SRSWF_entry"
global treat3   "post_treat"

global controls "CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index SRSWF_dura"
global controls_nocsr "HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index"
* global controls_dur "$controls SRSWF_dura"
* 注意：SRSWF_dura 是处理派生变量。主效应模型不把它放入默认控制项；它在 stewardship 边界条件中使用。
* 如需加入 Political_Ties，请先确认 2018-2019 年不因缺失而被整段删去。

* 连续变量缩尾
winsor2 D1CSR_score D1HXCSR_score D1ESG_blomscore CSR_score HXCSR_score ESG_blomscore ///
        AnaAttention ReportAttention NewAttention D1AnaAttention D1ReportAttention D1NewAttention ///
        HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth ///
        Product_div_EI RD_intensity AD_intensity Export_intensity LNViolation Board_independent ///
        SRSWF_owns SRSWF_dura Market_index FOREIGN_REGISTER TRADE_NOR IFDI_TRADE L1Insti_envir, replace cuts(1 99)

*----------------------------------*
* 9. 构造回归样本与固定效应组
*----------------------------------*

egen miss_main = rowmiss($y_main $treat1 $controls YEAR ID ProvinceCode)
drop if miss_main>0
drop miss_main

egen indyear  = group(IndustryCode YEAR)
egen provyear = group(ProvinceCode YEAR)

save "$outdir\SWF_CSR_panel_for_endorsement_analysis.dta", replace

*----------------------------------*

/**************************************************************************************************
* 投稿导向新策略：两阶段信号模型
* 核心故事：
*   Stage 1: Selection / pre-entry signaling race
*            社会责任型 SWF 更可能纳入已完成 CSR 预升级、且信号可见性较高的企业。
*   Stage 2: Post-entry certification plateau
*            公开背书以后，企业并不降低 CSR 水平，但后续 CSR 的边际升级速度放缓。
*            这种放缓更像“认证后的充分性感知”，而非强治理干预。
**************************************************************************************************/

*----------------------------------*
* 10. 投稿版变量构造：CSR 升级、斜率变化、frontier gap
*----------------------------------*

sort ID YEAR
xtset ID YEAR

capture drop CSR_pre_upgrade CSR_slope_change CSR_frontier_p90 CSR_frontier_gap F1CSR_frontier_gap CSR_gap_closing
capture drop FirstEntry_event F1FirstEntry_event HighVisibility NearFrontier med_gap_y med_vis_y
capture drop CSR_upgrade_high med_d1csr_y

gen CSR_pre_upgrade = CSR_score - L.CSR_score
label var CSR_pre_upgrade "当期相对上一期 CSR 升级"

gen CSR_slope_change = D1CSR_score - CSR_pre_upgrade
label var CSR_slope_change "CSR 升级斜率变化：下一期升级 - 上一期升级"

bysort IndustryCode YEAR: egen CSR_frontier_p90 = pctile(CSR_score), p(90)
gen CSR_frontier_gap = CSR_frontier_p90 - CSR_score
sort ID YEAR
gen F1CSR_frontier_gap = F.CSR_frontier_gap
gen CSR_gap_closing = CSR_frontier_gap - F1CSR_frontier_gap
label var CSR_frontier_gap "相对行业-年 CSR p90 前沿的差距"
label var CSR_gap_closing "下一期 CSR gap-closing；越大代表越接近前沿"

bysort IndustryCode YEAR: egen med_d1csr_y = median(D1CSR_score)
gen CSR_upgrade_high = (D1CSR_score>=med_d1csr_y) if !missing(D1CSR_score, med_d1csr_y)
label var CSR_upgrade_high "是否高于行业-年中位数 CSR 升级"

gen FirstEntry_event = (YEAR==first_treat & ever_treated==1)
sort ID YEAR
gen F1FirstEntry_event = F.FirstEntry_event
label var FirstEntry_event "首次被社会责任型 SWF 纳入当年"
label var F1FirstEntry_event "下一年是否首次被纳入"

bysort YEAR: egen med_vis_y = median(NewAttention)
gen HighVisibility = (NewAttention>=med_vis_y) if !missing(NewAttention, med_vis_y)
label var HighVisibility "高媒体可见性"

bysort YEAR: egen med_gap_y = median(CSR_frontier_gap)
gen NearFrontier = (CSR_frontier_gap<=med_gap_y) if !missing(CSR_frontier_gap, med_gap_y)
label var NearFrontier "接近 CSR 前沿"

*----------------------------------*
* 10.1 CSR / ESG 评价模糊性（ambiguity / rating disagreement）
*----------------------------------*
* 理论含义：当润灵 CSR、和讯 CSR、华证 ESG 对同一企业给出不一致评价时，
* 外部评价环境更模糊，SRSWF endorsement 的认证信号更可能改变外部判断与企业后续 CSR 改善激励。
* 构造方式：先在年度内标准化不同评分，再计算评分之间的离散度。
* 主口径：润灵 CSR、和讯 CSR、华证 ESG 综合评分的标准差。
* 稳健口径：极差、平均成对绝对差异，以及以华证 E/S 均值替代华证综合 ESG 以剔除 G 维度。

capture drop z_CSR_RKS z_CSR_HX z_ESG_HZ z_ESG_HZ_ES
capture drop mean_CSR_score_y sd_CSR_score_y mean_HXCSR_score_y sd_HXCSR_score_y
capture drop mean_ESG_huascore_y sd_ESG_huascore_y mean_HZ_ES_score_y sd_HZ_ES_score_y

bysort YEAR: egen mean_CSR_score_y = mean(CSR_score)
bysort YEAR: egen sd_CSR_score_y   = sd(CSR_score)
gen z_CSR_RKS = (CSR_score - mean_CSR_score_y)/sd_CSR_score_y if sd_CSR_score_y>0 & !missing(CSR_score)
label var z_CSR_RKS "年度标准化润灵 CSR"

bysort YEAR: egen mean_HXCSR_score_y = mean(HXCSR_score)
bysort YEAR: egen sd_HXCSR_score_y   = sd(HXCSR_score)
gen z_CSR_HX = (HXCSR_score - mean_HXCSR_score_y)/sd_HXCSR_score_y if sd_HXCSR_score_y>0 & !missing(HXCSR_score)
label var z_CSR_HX "年度标准化和讯 CSR"

bysort YEAR: egen mean_ESG_huascore_y = mean(ESG_huascore)
bysort YEAR: egen sd_ESG_huascore_y   = sd(ESG_huascore)
gen z_ESG_HZ = (ESG_huascore - mean_ESG_huascore_y)/sd_ESG_huascore_y if sd_ESG_huascore_y>0 & !missing(ESG_huascore)
label var z_ESG_HZ "年度标准化华证 ESG 综合"

bysort YEAR: egen mean_HZ_ES_score_y = mean(HZ_ES_score)
bysort YEAR: egen sd_HZ_ES_score_y   = sd(HZ_ES_score)
gen z_ESG_HZ_ES = (HZ_ES_score - mean_HZ_ES_score_y)/sd_HZ_ES_score_y if sd_HZ_ES_score_y>0 & !missing(HZ_ES_score)
label var z_ESG_HZ_ES "年度标准化华证 E/S 均值（剔除 G）"

capture drop CSR_ambig_n CSR_ambig_sd CSR_ambig_range CSR_ambig_apd CSR_ambig_p12 CSR_ambig_p13 CSR_ambig_p23 CSR_ambig_pair_n CSR_ambig_max CSR_ambig_min
capture drop CSR_ambig_ES_n CSR_ambig_ES_sd CSR_ambig_ES_range CSR_ambig_ES_apd CSR_ambig_ES_p12 CSR_ambig_ES_p13 CSR_ambig_ES_p23 CSR_ambig_ES_pair_n CSR_ambig_ES_max CSR_ambig_ES_min

egen CSR_ambig_n = rownonmiss(z_CSR_RKS z_CSR_HX z_ESG_HZ)
egen CSR_ambig_sd = rowsd(z_CSR_RKS z_CSR_HX z_ESG_HZ)
replace CSR_ambig_sd = . if CSR_ambig_n<2
label var CSR_ambig_sd "评价模糊性：润灵CSR/和讯CSR/华证ESG标准化评分的标准差"

egen CSR_ambig_max = rowmax(z_CSR_RKS z_CSR_HX z_ESG_HZ)
egen CSR_ambig_min = rowmin(z_CSR_RKS z_CSR_HX z_ESG_HZ)
gen CSR_ambig_range = CSR_ambig_max - CSR_ambig_min if CSR_ambig_n>=2
label var CSR_ambig_range "评价模糊性：润灵CSR/和讯CSR/华证ESG标准化评分极差"

gen CSR_ambig_p12 = abs(z_CSR_RKS - z_CSR_HX) if !missing(z_CSR_RKS, z_CSR_HX)
gen CSR_ambig_p13 = abs(z_CSR_RKS - z_ESG_HZ) if !missing(z_CSR_RKS, z_ESG_HZ)
gen CSR_ambig_p23 = abs(z_CSR_HX - z_ESG_HZ) if !missing(z_CSR_HX, z_ESG_HZ)
egen CSR_ambig_pair_n = rownonmiss(CSR_ambig_p12 CSR_ambig_p13 CSR_ambig_p23)
egen CSR_ambig_apd = rowmean(CSR_ambig_p12 CSR_ambig_p13 CSR_ambig_p23)
replace CSR_ambig_apd = . if CSR_ambig_pair_n<1
label var CSR_ambig_apd "评价模糊性：润灵CSR/和讯CSR/华证ESG平均成对绝对差异"

* 剔除 G 后的调节变量稳健性：华证 E/S 均值替代华证 ESG 综合评分。
egen CSR_ambig_ES_n = rownonmiss(z_CSR_RKS z_CSR_HX z_ESG_HZ_ES)
egen CSR_ambig_ES_sd = rowsd(z_CSR_RKS z_CSR_HX z_ESG_HZ_ES)
replace CSR_ambig_ES_sd = . if CSR_ambig_ES_n<2
label var CSR_ambig_ES_sd "评价模糊性稳健：润灵CSR/和讯CSR/华证E-S标准化评分的标准差"

egen CSR_ambig_ES_max = rowmax(z_CSR_RKS z_CSR_HX z_ESG_HZ_ES)
egen CSR_ambig_ES_min = rowmin(z_CSR_RKS z_CSR_HX z_ESG_HZ_ES)
gen CSR_ambig_ES_range = CSR_ambig_ES_max - CSR_ambig_ES_min if CSR_ambig_ES_n>=2
label var CSR_ambig_ES_range "评价模糊性稳健：剔除G后的标准化评分极差"

gen CSR_ambig_ES_p12 = abs(z_CSR_RKS - z_CSR_HX) if !missing(z_CSR_RKS, z_CSR_HX)
gen CSR_ambig_ES_p13 = abs(z_CSR_RKS - z_ESG_HZ_ES) if !missing(z_CSR_RKS, z_ESG_HZ_ES)
gen CSR_ambig_ES_p23 = abs(z_CSR_HX - z_ESG_HZ_ES) if !missing(z_CSR_HX, z_ESG_HZ_ES)
egen CSR_ambig_ES_pair_n = rownonmiss(CSR_ambig_ES_p12 CSR_ambig_ES_p13 CSR_ambig_ES_p23)
egen CSR_ambig_ES_apd = rowmean(CSR_ambig_ES_p12 CSR_ambig_ES_p13 CSR_ambig_ES_p23)
replace CSR_ambig_ES_apd = . if CSR_ambig_ES_pair_n<1
label var CSR_ambig_ES_apd "评价模糊性稳健：剔除G后的平均成对绝对差异"

sort ID YEAR
xtset ID YEAR
capture drop L1CSR_ambig_sd L1CSR_ambig_range L1CSR_ambig_apd L1CSR_ambig_ES_sd L1CSR_ambig_ES_range L1CSR_ambig_ES_apd
gen L1CSR_ambig_sd       = L.CSR_ambig_sd
gen L1CSR_ambig_range    = L.CSR_ambig_range
gen L1CSR_ambig_apd      = L.CSR_ambig_apd
gen L1CSR_ambig_ES_sd    = L.CSR_ambig_ES_sd
gen L1CSR_ambig_ES_range = L.CSR_ambig_ES_range
gen L1CSR_ambig_ES_apd   = L.CSR_ambig_ES_apd
label var L1CSR_ambig_sd "滞后一期评价模糊性：标准差"
label var L1CSR_ambig_range "滞后一期评价模糊性：极差"
label var L1CSR_ambig_apd "滞后一期评价模糊性：平均成对绝对差异"
label var L1CSR_ambig_ES_sd "滞后一期评价模糊性：标准差（剔除G）"
label var L1CSR_ambig_ES_range "滞后一期评价模糊性：极差（剔除G）"
label var L1CSR_ambig_ES_apd "滞后一期评价模糊性：平均成对绝对差异（剔除G）"

bysort YEAR: egen med_ambig_sd_y = median(CSR_ambig_sd)
gen HighAmbiguity = (CSR_ambig_sd>=med_ambig_sd_y) if !missing(CSR_ambig_sd, med_ambig_sd_y)
label var HighAmbiguity "高 CSR/ESG 评价模糊性"

drop med_d1csr_y med_vis_y med_gap_y mean_CSR_score_y sd_CSR_score_y mean_HXCSR_score_y sd_HXCSR_score_y mean_ESG_huascore_y sd_ESG_huascore_y mean_HZ_ES_score_y sd_HZ_ES_score_y med_ambig_sd_y

winsor2 CSR_slope_change CSR_gap_closing CSR_frontier_gap CSR_pre_upgrade ///
        CSR_ambig_sd CSR_ambig_range CSR_ambig_apd CSR_ambig_ES_sd CSR_ambig_ES_range CSR_ambig_ES_apd ///
        L1CSR_ambig_sd L1CSR_ambig_range L1CSR_ambig_apd L1CSR_ambig_ES_sd L1CSR_ambig_ES_range L1CSR_ambig_ES_apd, replace cuts(1 99)

capture drop miss_pub miss_supp
* 主样本 missing 约束只施加于 D1CSR_score、SRSWF_hold 与主控制变量，以保持与原始 do 文件筛选口径的一致性。
egen miss_pub = rowmiss(D1CSR_score SRSWF_hold CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index ID YEAR ProvinceCode)
drop if miss_pub>0
drop miss_pub
* 补充变量纳入 rmiss 诊断，但不据此删样本：slope change 与 gap closing 是补充检验，不应改变正文主样本。
egen miss_supp = rowmiss(CSR_slope_change CSR_gap_closing CSR_pre_upgrade D1HXCSR_score D1ESG_huascore D1HZ_ES_score CSR_ambig_sd CSR_ambig_ES_sd)
tab miss_supp

capture drop indyear provyear
egen indyear  = group(IndustryCode YEAR)
egen provyear = group(ProvinceCode YEAR)

compress
save "$outdir\SWF_CSR_submission_panel.dta", replace

*----------------------------------*
* 11. 描述性统计：新变量与核心处理变量
*----------------------------------*
eststo clear
estpost tabstat D1CSR_score CSR_slope_change CSR_gap_closing CSR_pre_upgrade ///
    SRSWF_hold SRSWF_count SRSWF_owns FirstEntry_event HighVisibility NearFrontier ///
    CSR_ambig_sd CSR_ambig_range CSR_ambig_apd L1CSR_ambig_sd L1CSR_ambig_range L1CSR_ambig_apd ///
    CSR_score HHI_D EU1 MarketValue_Size Listed_age State_Ownership LTD_sales FC_Index SalesGrowth ///
    Product_div_EI RD_intensity AD_intensity Export_intensity CEO_Gender CEO_Edu LNViolation Board_independent Market_index, ///
    s(n mean sd p25 p50 p75 min max) columns(statistics)
esttab . using "$outdir\Table_0_Descriptive_Stats.rtf", replace cells("count mean sd p25 p50 p75 min max") nomtitle nonumber

*----------------------------------*
* 12. Stage 1：选择模型 / 预升级模型
*----------------------------------*
eststo clear

reghdfe F1FirstEntry_event CSR_score CSR_pre_upgrade HighVisibility NewAttention AnaAttention ReportAttention ///
    $controls ///
    if post_treat==0, absorb(ID IndustryCode ProvinceCode)
eststo sel1

reghdfe F1FirstEntry_event CSR_score CSR_pre_upgrade HighVisibility NearFrontier ///
    $controls ///
    if post_treat==0, absorb(ID IndustryCode ProvinceCode)
eststo sel2

local selmods "sel1 sel2"
capture noisily logit F1FirstEntry_event CSR_score CSR_pre_upgrade HighVisibility NearFrontier ///
    $controls ///
    i.YEAR if post_treat==0
if _rc==0 {
    eststo sel3
    local selmods "`selmods' sel3"
}

esttab `selmods' using "$outdir\Table_1_Selection_PreEntry_Signaling.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a)

*----------------------------------*
* 13. Stage 2：认证后的边际 CSR 升级放缓
*----------------------------------*
eststo clear

reghdfe D1CSR_score SRSWF_hold $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo b1

reghdfe CSR_slope_change SRSWF_hold $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo b2

reghdfe D1CSR_score SRSWF_count SRSWF_owns $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo b3

reghdfe CSR_gap_closing SRSWF_hold $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo b4

reghdfe CSR_gap_closing SRSWF_count SRSWF_owns $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo b5

esttab b1 b2 b3 b4 b5 using "$outdir\Table_2_PostEntry_Certification_Plateau.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold SRSWF_count SRSWF_owns CSR_score)

*----------------------------------*
* 14. 信号理论调节效应：评价模糊性与 stewardship intensity
*----------------------------------*
* H2：CSR/ESG 评价越模糊，外部观众越难形成稳定判断。
*     在这种情形下，SRSWF endorsement 的认证信号越难以可能诱发“已足够”的感知，
*     因而 SRSWF_hold 对 D1CSR_score 的负向作用应更弱。
* H3：stewardship intensity 越强，SWF 持股越接近治理监督而非单纯认证，
*     因而认证导致的 CSR 升级放缓效应越弱。

eststo clear

reghdfe CSR_slope_change c.SRSWF_hold##c.L1CSR_ambig_sd $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo h1

reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_sd $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo h2

reghdfe D1CSR_score c.SRSWF_count##c.SRSWF_dura $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo h3

reghdfe D1CSR_score c.SRSWF_count##c.SRSWF_owns $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo h4

esttab h1 h2 h3 h4 using "$outdir\Table_3_Moderation_Ambiguity_and_Stewardship.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold c.SRSWF_hold#c.L1CSR_ambig_sd SRSWF_count c.SRSWF_count#c.SRSWF_dura c.SRSWF_count#c.SRSWF_owns)

* 评价模糊性的多口径稳健性：标准差、极差、平均成对绝对差异。
eststo clear

reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_sd $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo a1

reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_range $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo a2

reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_apd $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo a3

reghdfe D1CSR_score c.SRSWF_hold##c.L1CSR_ambig_ES_sd $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo a4

esttab a1 a2 a3 a4 using "$outdir\Table_3A_Ambiguity_Measurement_Robustness.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold c.SRSWF_hold#c.L1CSR_ambig_sd c.SRSWF_hold#c.L1CSR_ambig_range c.SRSWF_hold#c.L1CSR_ambig_apd)

* treated-only 补充：在已获 endorsement 的样本中，区分认证来源数量与治理强度。
eststo clear

reghdfe CSR_slope_change c.SRSWF_count##c.SRSWF_dura $controls ///
    if SRSWF_hold==1, absorb(ID IndustryCode ProvinceCode)
eststo ts1

reghdfe CSR_slope_change c.SRSWF_count##c.SRSWF_owns $controls ///
    if SRSWF_hold==1, absorb(ID IndustryCode ProvinceCode)
eststo ts2

esttab ts1 ts2 using "$outdir\Table_3B_TreatedOnly_Signal_vs_Stewardship.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a)

*----------------------------------*
* 15. 短窗口 stacked event study：投稿版主动态设计
*----------------------------------*
preserve
    tempfile base stack
    save `base', replace

    quietly summarize YEAR if !missing(D1CSR_score)
    local ymin = r(min)
    local ymax = r(max)
    local prew  = 2
    local postw = 3
    local gmin = `ymin' + `prew'
    local gmax = `ymax' - `postw'

    levelsof first_treat if first_treat>0 & first_treat>=`gmin' & first_treat<=`gmax', local(cohorts)
    if "`cohorts'"=="" {
        di as error "No eligible treatment cohorts for the stacked event-study window. Check sample years or shorten prew/postw."
    }
    else {
        local firstloop = 1

        foreach g of local cohorts {
            use `base', clear
            keep if inrange(YEAR, `g'-`prew', `g'+`postw')
            gen stack_g = `g'
            gen treated_stack = (first_treat==`g')
            keep if treated_stack==1 | first_treat==0 | first_treat>`g'+`postw'
            gen rel_stack = YEAR - `g'
            if `firstloop'==1 {
                save `stack', replace
                local firstloop = 0
            }
            else {
                append using `stack'
                save `stack', replace
            }
        }

        use `stack', clear
        sort ID stack_g YEAR
    egen firm_stack = group(ID stack_g)
    egen year_stack = group(YEAR stack_g)
    egen indyear_stack = group(IndustryCode YEAR stack_g)
    egen provyear_stack = group(ProvinceCode YEAR stack_g)

    capture drop st_m2 st_0 st_p1 st_p2 st_p3
    gen st_m2 = (treated_stack==1 & rel_stack==-2)
    gen st_0  = (treated_stack==1 & rel_stack==0)
    gen st_p1 = (treated_stack==1 & rel_stack==1)
    gen st_p2 = (treated_stack==1 & rel_stack==2)
    gen st_p3 = (treated_stack==1 & rel_stack==3)

    eststo clear

    reghdfe D1CSR_score st_m2 st_0 st_p1 st_p2 st_p3 $controls, ///
        absorb(ID IndustryCode ProvinceCode)
    eststo st1

    reghdfe CSR_slope_change st_m2 st_0 st_p1 st_p2 st_p3 $controls, ///
        absorb(ID IndustryCode ProvinceCode)
    eststo st2

    reghdfe CSR_slope_change st_m2 st_0 st_p1 st_p2 st_p3 $controls, ///
        absorb(ID IndustryCode ProvinceCode)
    eststo st3

    esttab st1 st2 st3 using "$outdir\Table_4_Stacked_EventStudy_ShortWindow.rtf", replace ///
        b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
        order(st_m2 st_0 st_p1 st_p2 st_p3)

    coefplot st1, keep(st_m2 st_0 st_p1 st_p2 st_p3) vertical ///
        yline(0, lpattern(dash)) xline(1.5, lpattern(shortdash)) ///
        xlabel(1 "-2" 2 "0" 3 "+1" 4 "+2" 5 "+3") ///
        title("Stacked short-window event study: CSR slope change") ///
        note("Omitted period = -1; controls are not-yet-treated within the local window")
    graph export "$outdir\Figure_1_Stacked_EventStudy_CSR_SlopeChange.png", replace
    }
restore

*----------------------------------*
* 16. Entry-Exit 对称检验：状态型认证效应
*----------------------------------*
sort ID YEAR
xtset ID YEAR
capture drop SRSWF_exit EntryAge0 EntryAge1 EntryAge2 EntryAge3plus HoldDur1 HoldDur2 HoldDur3plus

gen SRSWF_exit = (SRSWF_hold==0 & L.SRSWF_hold==1) if !missing(SRSWF_hold, L.SRSWF_hold)
replace SRSWF_exit = 0 if missing(SRSWF_exit)
label var SRSWF_exit "[SRSWF] 退出当年"

* EntryAge 用吸收式 first_treat 定义回答：首次认证后第几年 D1CSR_score 开始显著为负。
gen EntryAge0 = (ever_treated==1 & rel_time==0)
gen EntryAge1 = (ever_treated==1 & rel_time==1)
gen EntryAge2 = (ever_treated==1 & rel_time==2)
gen EntryAge3plus = (ever_treated==1 & rel_time>=3 & post_treat==1)
label var EntryAge0 "首次认证当年"
label var EntryAge1 "首次认证后第1年"
label var EntryAge2 "首次认证后第2年"
label var EntryAge3plus "首次认证后第3年及以后"

* HoldDur 用当前连续持股时长定义，检验状态型持股效应是否需要累积到一定年限。
gen HoldDur1 = (SRSWF_hold==1 & SRSWF_dura==1)
gen HoldDur2 = (SRSWF_hold==1 & SRSWF_dura==2)
gen HoldDur3plus = (SRSWF_hold==1 & SRSWF_dura>=3)
label var HoldDur1 "当前连续持股第1年"
label var HoldDur2 "当前连续持股第2年"
label var HoldDur3plus "当前连续持股第3年及以后"

eststo clear
reghdfe D1CSR_score SRSWF_entry SRSWF_exit $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo ee1

reghdfe D1CSR_score SRSWF_hold SRSWF_entry SRSWF_exit $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo ee2

reghdfe D1CSR_score EntryAge0 EntryAge1 EntryAge2 EntryAge3plus SRSWF_exit $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo ee3

reghdfe D1CSR_score HoldDur1 HoldDur2 HoldDur3plus SRSWF_exit $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo ee4

esttab ee1 ee2 ee3 ee4 using "$outdir\Table_5_Entry_Exit_TimeToPlateau_D1CSR.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold SRSWF_entry SRSWF_exit EntryAge0 EntryAge1 EntryAge2 EntryAge3plus HoldDur1 HoldDur2 HoldDur3plus)

* 补充：用 slope change 与 gap closing 复查 entry/exit 对称性。
eststo clear
reghdfe CSR_slope_change SRSWF_entry SRSWF_exit $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo ees1

reghdfe CSR_gap_closing SRSWF_entry SRSWF_exit $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo ees2

esttab ees1 ees2 using "$outdir\Table_5S_Entry_Exit_Supplement_Slope_Gap.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_entry SRSWF_exit)

*----------------------------------*
* 17. 机制重写：充分性感知、评价模糊性与观众反应
*----------------------------------*
* 该部分不把“外部关注整体下降”作为唯一机制。
* 它区分专业资本市场中介（分析师/研报）与公共信息场域（媒体）。

eststo clear
reghdfe D1AnaAttention SRSWF_hold $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo m1

reghdfe D1ReportAttention SRSWF_hold $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo m2

reghdfe D1NewAttention SRSWF_hold $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo m3

reghdfe CSR_gap_closing SRSWF_count SRSWF_owns $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo m4

reghdfe CSR_slope_change c.SRSWF_hold##c.L1CSR_ambig_sd $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo m5

esttab m1 m2 m3 m4 m5 using "$outdir\Table_6_Mechanism_Reframed_Adequacy_Ambiguity_Visibility.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a)

*----------------------------------*
* 18. 稳健性：因变量、调节变量与指标口径
*----------------------------------*
eststo clear
reghdfe D1HXCSR_score SRSWF_hold $controls if !missing(D1HXCSR_score), ///
    absorb(ID IndustryCode ProvinceCode)
eststo r1

reghdfe D1ESG_huascore SRSWF_hold $controls if !missing(D1ESG_huascore), ///
    absorb(ID IndustryCode ProvinceCode)
eststo r2

reghdfe D1HZ_ES_score SRSWF_hold $controls if !missing(D1HZ_ES_score), ///
    absorb(ID IndustryCode ProvinceCode)
eststo r3

reghdfe D1CSR_score SRSWF_count SRSWF_owns $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo r4

esttab r1 r2 r3 r4 using "$outdir\Table_7_Robustness_DV_Construct_Sensitivity.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold SRSWF_count SRSWF_owns CSR_score)

* 进一步的调节变量稳健性集中在 Table_3A：range、APD、剔除 G 后的 E/S 口径。

*----------------------------------*
* 19. 工具变量法：参照原始 do 文件的省份外资开放工具变量构造
*----------------------------------*
* 说明：IV 不是主识别，而是缓解 SRSWF_hold 选择性进入的一组辅助检验。
* 主工具变量 FOREIGN_REGISTER 为省份层面的外商投资企业登记数滞后值。
* 备选工具变量 TRADE_NOR / IFDI_TRADE 捕捉省份外向开放与对挪威经贸暴露。

eststo clear

capture noisily ivreghdfe D1CSR_score $controls (SRSWF_hold = IFDI_TRADE), ///
    absorb(ID IndustryCode ProvinceCode) first
if _rc==0 {
    eststo iv1
}

capture noisily ivreghdfe CSR_slope_change $controls (SRSWF_hold = IFDI_TRADE), ///
    absorb(ID IndustryCode ProvinceCode) first
if _rc==0 {
    eststo iv2
}

capture noisily ivreghdfe CSR_gap_closing $controls (SRSWF_hold = IFDI_TRADE), ///
    absorb(ID IndustryCode ProvinceCode) first
if _rc==0 {
    eststo iv3
}

* IV for moderation: instrument SRSWF_hold and SRSWF_hold × ambiguity with IV and IV × ambiguity.
capture drop SRSWFxAmbig IVxAmbig
gen SRSWFxAmbig = SRSWF_hold * L1CSR_ambig_sd if !missing(SRSWF_hold, L1CSR_ambig_sd)
gen IV1xAmbig     = IFDI_TRADE * L1CSR_ambig_sd if !missing(IFDI_TRADE, L1CSR_ambig_sd)
gen IV2xAmbig     = FOREIGN_REGISTER * L1CSR_ambig_sd if !missing(FOREIGN_REGISTER, L1CSR_ambig_sd)
label var SRSWFxAmbig "SRSWF_hold × 滞后评价模糊性"
label var IV1xAmbig "FOREIGN_REGISTER × 滞后评价模糊性"
label var IV2xAmbig "IFDI_TRADE × 滞后评价模糊性"

capture noisily ivreghdfe CSR_slope_change L1CSR_ambig_sd $controls ///
    (SRSWF_hold SRSWFxAmbig = IFDI_TRADE IV2xAmbig), ///
    absorb(ID IndustryCode ProvinceCode) first
if _rc==0 {
    eststo iv4
}

* 备选 / 过度识别 IV：FOREIGN_REGISTER + TRADE_NOR + IFDI_TRADE。
capture noisily ivreghdfe CSR_slope_change $controls ///
    (SRSWF_hold = FOREIGN_REGISTER IFDI_TRADE), ///
    absorb(ID IndustryCode ProvinceCode) first
if _rc==0 {
    eststo iv5
}

capture noisily esttab iv1 iv2 iv3 iv4 iv5 using "$outdir\Table_8_IV_2SLS_Endogeneity_Robustness.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a widstat jp) ///
    order(SRSWF_hold SRSWFxAmbig L1CSR_ambig_sd)

capture noisily tabstat FOREIGN_REGISTER TRADE_NOR IFDI_TRADE L1Insti_envir, s(n mean sd p25 p50 p75 min max) c(s) f(%10.4f)

*----------------------------------*
* 21. 进一步分析：认证主导边界条件
*----------------------------------*
* 该部分放在主效应、调节效应、内生性与稳健性之后，用于强化理论故事：
* 如果 SRSWF 的作用主要是认证而非强治理，负向 D1CSR 效应应集中在“小持股、接近 CSR 前沿、低外部监控”的区间。

eststo clear
reghdfe D1CSR_score c.SRSWF_hold##i.NearFrontier $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo add1

reghdfe D1CSR_score c.SRSWF_hold##i.LowStewardship $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo add2

reghdfe D1CSR_score c.SRSWF_hold##i.LowExternalMonitor $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo add3

reghdfe D1CSR_score c.SRSWF_hold##i.CertDominates $controls, ///
    absorb(ID IndustryCode ProvinceCode)
eststo add4

esttab add1 add2 add3 add4 using "$outdir\Table_10_Additional_CertificationDominant_Boundaries.rtf", replace ///
    b(%9.3f) t(%9.3f) star(* 0.10 ** 0.05 *** 0.01) compress nogap scalars(N r2_a) ///
    order(SRSWF_hold 1.NearFrontier c.SRSWF_hold#1.NearFrontier 1.LowStewardship c.SRSWF_hold#1.LowStewardship 1.LowExternalMonitor c.SRSWF_hold#1.LowExternalMonitor 1.CertDominates c.SRSWF_hold#1.CertDominates)

*----------------------------------*
* 22. 附录诊断：CSDID 保留，但不作为主识别
*----------------------------------*
preserve
    sort ID YEAR
    xtset ID YEAR
    keep if !missing(D1CSR_score, ID, YEAR, first_treat)
    keep if YEAR>=2009 & YEAR<=2019
    capture noisily csdid D1CSR_score $controls, ///
        ivar(ID) time(YEAR) gvar(first_treat) notyet method(dripw)
    if _rc==0 {
        estimates store csdid_slope
        estat simple
        estat pretrend
        estat event
        csdid_plot, title("CSDID diagnostic: D1CSR_score")
        graph export "$outdir\Figure_2_CSDID_Diagnostic_D1CSR.png", replace
    }
restore


*----------------------------------*
* 23. 保存最终投稿版分析数据
*----------------------------------*
save "$outdir\SWF_CSR_submission_signal_strategy_final.dta", replace

log close
exit
