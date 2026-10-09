* ============================================================================
* 02_modelos.do - Estimación y Comparación con Ground Truth
* Author: Bryan Segovia
* ============================================================================

use "data/simulated_data.dta", clear

display "================================================================"
display "SECTION 2: ESTIMATION MODELS"
display "================================================================"

* ----------------------------------------------------------------------------
* 2.1 Naive Probit (ignora endogeneidad - sesgado)
* ----------------------------------------------------------------------------
display ""
display "--- Naive Probit (biased) ---"
probit financial_access i.formal_labor ln_income education_years age_head i.urban
estimates store naive_probit

* Marginal effects
margins, dydx(i.formal_labor ln_income education_years age_head i.urban) predict(pr) post
estimates store naive_probit_me

* ----------------------------------------------------------------------------
* 2.2 Bivariate Probit (corrige sesgo de selección)
* ----------------------------------------------------------------------------
display ""
display "--- Bivariate Probit (corrects selection bias) ---"
biprobit (financial_access = i.formal_labor ln_income education_years age_head i.urban) ///
         (formal_labor = sunafil_intensity ln_income education_years age_head i.urban)
estimates store biprobit

* Test de endogeneidad (H0: rho = 0)
display ""
display "Endogeneity Test (H0: rho = 0):"
display "Wald chi2 = " e(chi2_c)
display "p-value = " e(p_c)
display "If p < 0.05, selection bias is present and Biprobit is preferred"

* Marginal effects (pmarg1 para ecuación de resultado)
margins, dydx(i.formal_labor ln_income education_years age_head i.urban) predict(pmarg1) post
estimates store biprobit_me

* ----------------------------------------------------------------------------
* 2.3 Propensity Score Matching (PSM) - Estimación no paramétrica
* ----------------------------------------------------------------------------
display ""
display "--- Propensity Score Matching (PSM) ---"

* Propensity score
logit formal_labor ln_income education_years age_head i.urban i.region
predict pscore, pr

* Gráfico de soporte común
kdensity pscore if formal_labor == 1, addplot(kdensity pscore if formal_labor == 0) ///
    legend(label(1 "Formal") label(2 "Informal")) ///
    title("Propensity Score Distribution") ///
    xtitle("Propensity Score") ytitle("Density")
graph export "outputs/pscore_distribution.png", replace

* PSM con teffects (errores estándar válidos)
teffects psmatch (financial_access) (formal_labor ln_income education_years age_head i.urban i.region), atet
estimates store psm_att

* Balance de covariables
tebalance summarize

* ----------------------------------------------------------------------------
* 2.4 COMPARACIÓN CON GROUND TRUTH
* ----------------------------------------------------------------------------
display ""
display "================================================================"
display "VALIDATION: Estimated vs True Effects"
display "================================================================"
display ""
display "True ATT from DGP: " att_true
display "True ATE from DGP: " ate_true
display ""
display "PSM ATT estimate: " _b[ATE]
display ""
display "Biprobit recovers the latent coefficient (0.8)"
display "PSM ATT should be close to true ATT (~0.14)"
display "Naive Probit will be biased upward"

* ----------------------------------------------------------------------------
* 2.5 Exportar tablas
* ----------------------------------------------------------------------------
display ""
display "--- Exporting Results Tables ---"

* Tabla de coeficientes
esttab naive_probit biprobit using "outputs/regression_table.tex", ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    b(%9.3f) se(%9.3f) ///
    title("Table 1: Probit Models - Financial Access") ///
    label varlabels(1.formal_labor "Formal employment" ln_income "Log income" education_years "Education" age_head "Age" 1.urban "Urban") ///
    replace

* Tabla de efectos marginales
esttab naive_probit_me biprobit_me using "outputs/marginal_effects.tex", ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    b(%9.3f) se(%9.3f) ///
    title("Table 2: Marginal Effects") ///
    label varlabels(1.formal_labor "Formal employment" ln_income "Log income" education_years "Education" age_head "Age" 1.urban "Urban") ///
    replace

display "Tables exported to outputs/"
