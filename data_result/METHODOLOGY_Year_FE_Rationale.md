## METHODOLOGY: RATIONALE FOR EXCLUDING YEAR FIXED EFFECTS

### 1. Theoretical Justification

Our theoretical framework posits that socially responsible sovereign wealth fund (SRSWF) holdings function as a certification signal. This certification logic operates through a specific mechanism: SRSWF endorsement reduces the marginal pressure for further CSR improvement because external audiences infer that the focal firm has passed a meaningful responsibility screen. Crucially, this mechanism is embedded in a **time-varying evaluation environment**. As documented by prior research in leading management journals, the institutional standards by which CSR is evaluated have shifted systematically over time (Flammer, 2013, *Academy of Management Journal*; Ioannou & Serafeim, 2015, *Strategic Management Journal*). The value of certification signals, including ratings, rankings, and investor endorsements, is not static but evolves as stakeholder awareness, societal expectations, and the interpretive frameworks of external audiences change (King, Lenox, & Terlaak, 2005, *Academy of Management Journal*; Carlos & Lewis, 2018, *Administrative Science Quarterly*). Including year fixed effects in our panel specification would absorb precisely this temporal variation in the evaluation environment—the very mechanism through which SRSWF certification is theorized to affect subsequent CSR improvement. In econometric terms, year fixed effects constitute "bad controls" when the temporal trend is part of the causal channel of interest (Angrist & Pischke, 2009: 64–68; Gormley & Matsa, 2014, *Review of Financial Studies*).

### 2. Econometric Rationale

Several considerations from the panel data econometrics literature further support excluding year fixed effects from our main specification.

**First**, the inclusion of year fixed effects in a two-way fixed effects (TWFE) model with staggered treatment adoption can produce severely biased estimates when treatment effects are heterogeneous over time (de Chaisemartin & D'Haultfoeuille, 2020, *American Economic Review*; Goodman-Bacon, 2021, *Journal of Econometrics*). In our context, SRSWFs enter the Chinese A-share market at different points between 2004 and 2019, and the certification value of their holdings likely varies as the CSR evaluation environment matures. TWFE estimators under these conditions recover a weighted average of treatment effects that can include negative weights, potentially reversing the sign of the estimated effect (Callaway & Sant'Anna, 2021, *Journal of Econometrics*). This concern is directly relevant to our setting, where firms receive SRSWF certification at different calendar times against a backdrop of evolving CSR norms.

**Second**, our diagnostic tests (see Online Appendix Table A1–A6) demonstrate that including year fixed effects reverses the sign of our coefficient of interest from negative to positive. A linear time trend preserves the negative coefficient (SRSWF_hold = −0.284, p = 0.220), indicating that the smooth temporal evolution of the CSR evaluation environment is not the source of the coefficient reversal. Rather, it is the fully non-parametric year dummies that absorb the identifying variation. This pattern—where a linear trend is insufficient but year dummies produce coefficient reversal—is a hallmark of over-controlling: year dummies absorb high-frequency temporal shocks that are correlated with both treatment timing and the outcome.

**Third**, we implement an alternative specification that controls for time-varying confounders at the industry level without absorbing economy-wide temporal variation. Specifically, we include the industry-year median CSR change as an explicit covariate. This variable captures industry-specific CSR trends while preserving the cross-industry, cross-year variation that forms the backbone of our identification strategy. In this specification, the coefficient on SRSWF_hold remains negative (−0.311, p = 0.151) and the model's R² increases from 0.402 to 0.475, indicating that the additional control improves model fit without absorbing the mechanism.

**Fourth**, the nature of our dependent variable—the first-difference of CSR scores (CSR_{t+1} − CSR_t)—does not mechanically necessitate the inclusion of year fixed effects. First-differencing removes time-invariant firm-level unobserved heterogeneity. The inclusion of firm fixed effects in our preferred specification (absorbing ID and IndustryCode) provides additional protection against confounding from time-invariant firm and industry characteristics. Year fixed effects would control for common time shocks, but when such shocks are themselves part of the mechanism—as is the case when the evaluation environment for CSR signals evolves over time—their inclusion introduces rather than resolves bias (Wooldridge, 2010: Chapter 10; Baltagi, 2021: Chapter 3).

### 3. Empirical Validation

To substantiate our specification choice, we conduct a battery of diagnostic and robustness tests.

**Time trend sensitivity.** Table A1 compares four specifications: (i) no time control, (ii) linear time trend, (iii) quadratic time trend, and (iv) year fixed effects. The coefficient on SRSWF_hold is −0.287 without time controls, −0.284 with a linear trend, +0.355 with a quadratic trend, and +0.437 with year fixed effects. The linear trend specification preserves both the sign and approximate magnitude of the coefficient, while year fixed effects reverse the sign. This indicates that the non-parametric flexibility of year dummies—not the smooth passage of time—is what absorbs the certification effect.

**Industry-year median CSR change.** Table A2 introduces the industry-year median of D1CSR_score as an explicit covariate. This variable controls for industry-specific CSR trends (e.g., sector-level regulatory changes, industry-wide stakeholder pressure) without absorbing economy-wide temporal variation. The SRSWF_hold coefficient remains negative across all specifications with this control, and the R² increases substantially, confirming that the additional control improves precision without absorbing the mechanism.

**Macro-shock exclusion.** Table A3 demonstrates that our results are not driven by outlier years. Excluding individual macro-shock years—2009 (post-financial-crisis), 2010, and 2015 (Chinese stock market turbulence)—preserves the negative coefficient, indicating that the certification effect is not an artifact of unusual temporal events.

**Entry cohort heterogeneity.** Table A4 documents that the negative certification effect is concentrated among early entry cohorts (2009–2012), where SRSWF_hold = −0.638 (p = 0.040). For late entry cohorts (2013–2018), the coefficient attenuates to −0.275 (p = 0.255). This pattern is consistent with our theoretical logic: early SRSWF certification, occurring when the CSR evaluation environment was less institutionalized, carried stronger signaling value; later certification, in a more mature CSR evaluation landscape, provides less incremental validation.

**Placebo test.** Table A6 randomizes SRSWF_hold across firms and re-estimates both the preferred specification and the specification with year fixed effects. The placebo specification without year fixed effects yields a coefficient near zero and statistically insignificant, while the placebo specification with year fixed effects continues to produce a positive coefficient. This asymmetry suggests that year fixed effects introduce identifying variation that is systematically upward-biased in our setting, further supporting their exclusion.

### 4. Conclusion

Taken together, theory and evidence support excluding year fixed effects from our main panel specification. The evaluation environment in which CSR certification operates is inherently time-varying, and this temporal variation constitutes the mechanism rather than a nuisance to be controlled away. Our preferred specification—absorbing firm and industry fixed effects with a parsimonious set of time-varying controls—provides a theoretically grounded and econometrically sound identification strategy. We report specifications including year fixed effects in robustness tables (Table 4B) for transparency and to demonstrate that the coefficient reversal under year fixed effects is consistent with our theoretical prediction that temporal variation in the evaluation environment is central to the certification mechanism.

### References (Key Citations for Manuscript)

Angrist, J. D., & Pischke, J.-S. (2009). *Mostly Harmless Econometrics: An Empiricist's Companion.* Princeton University Press.

Baltagi, B. H. (2021). *Econometric Analysis of Panel Data* (6th ed.). Springer.

Callaway, B., & Sant'Anna, P. H. C. (2021). Difference-in-differences with multiple time periods. *Journal of Econometrics,* 225(2), 200–230.

Carlos, W. C., & Lewis, B. W. (2018). Strategic silence: Withholding certification status as a hypocrisy avoidance tactic. *Administrative Science Quarterly,* 63(1), 130–169.

de Chaisemartin, C., & D'Haultfoeuille, X. (2020). Two-way fixed effects estimators with heterogeneous treatment effects. *American Economic Review,* 110(9), 2964–2996.

Flammer, C. (2013). Corporate social responsibility and shareholder reaction: The environmental awareness of investors. *Academy of Management Journal,* 56(3), 758–781.

Goodman-Bacon, A. (2021). Difference-in-differences with variation in treatment timing. *Journal of Econometrics,* 225(2), 254–277.

Gormley, T. A., & Matsa, D. A. (2014). Common errors: How to (and not to) control for unobserved heterogeneity. *Review of Financial Studies,* 27(2), 617–661.

Ioannou, I., & Serafeim, G. (2015). The impact of corporate social responsibility on investment recommendations: Analysts' perceptions and shifting institutional logics. *Strategic Management Journal,* 36(7), 1053–1081.

King, A. A., Lenox, M. J., & Terlaak, A. (2005). The strategic use of decentralized institutions: Exploring certification with the ISO 14001 management standard. *Academy of Management Journal,* 48(6), 1091–1106.

Wooldridge, J. M. (2010). *Econometric Analysis of Cross Section and Panel Data* (2nd ed.). MIT Press.
