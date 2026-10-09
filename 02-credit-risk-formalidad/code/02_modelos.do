* ============================================================================
* 02_modelos.do - Estimación y Comparación con Ground Truth
* Author: Bryan Segovia
* ============================================================================
clear all
set more off
use "data/simulated_data.dta", clear

display "================================================================"
display "SECTION 2: ESTIMATION MODELS"
display "================================================================"

* ----------------------------------------------------------------------------
* 2.1 Naive Probit
* ----------------------------------------------------------------------------
probit financial_access i.formal_labor ln_income education_years age_head i.urban
estimates store naive_probit
margins, dydx(i.formal_labor) predict(pr) post
estimates store naive_probit_me
scalar me_naive = _b[1.formal_labor]

* ----------------------------------------------------------------------------
* 2.2 Bivariate Probit
* ----------------------------------------------------------------------------
biprobit (financial_access = i.formal_labor ln_income education_years age_head i.urban) ///
         (formal_labor = sunafil_intensity ln_income education_years age_head i.urban)
estimates store biprobit

display ""
display "Endogeneity Test (H0: rho = 0):"
display "Wald chi2 = " e(chi2_c)
display "p-value = " e(p_c)

margins, dydx(i.formal_labor) predict(pmarg1) post
estimates store biprobit_me
scalar me_biprobit = _b[1.formal_labor]

* ----------------------------------------------------------------------------
* 2.3 Propensity Score Matching (teffects para errores estándar válidos)
* ----------------------------------------------------------------------------
teffects psmatch (financial_access) (formal_labor ln_income education_years age_head i.urban i.region), atet
scalar att_psm_te = e(att)

tebalance summarize

* ----------------------------------------------------------------------------
* 2.4 Resumen comparativo (CALCULADO, NO ESCRITO A MANO)
* ----------------------------------------------------------------------------
display ""
display "================================================================"
display "RESUMEN COMPARATIVO: Efecto de la Formalidad en Acceso Financiero"
display "================================================================"
display "True ATT (DGP):     " %6.3f att_true
display "Naive Probit (ME):  " %6.3f me_naive
display "Biprobit (ME):      " %6.3f me_biprobit
display "PSM ATT (teffects): " %6.3f att_psm_te
display "================================================================"

* Exportar tablas
esttab naive_probit biprobit using "outputs/regression_table.tex", ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    title("Table 1: Probit Models") ///
    label varlabels(1.formal_labor "Formal employment" ln_income "Log income" education_years "Education" age_head "Age" 1.urban "Urban") ///
    replace

esttab naive_probit_me biprobit_me using "outputs/marginal_effects.tex", ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    title("Table 2: Marginal Effects") ///
    label varlabels(1.formal_labor "Formal employment" ln_income "Log income" education_years "Education" age_head "Age" 1.urban "Urban") ///
    replace

display "Tables exported to outputs/"
