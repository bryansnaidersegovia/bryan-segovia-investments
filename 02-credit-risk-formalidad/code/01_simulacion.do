* ============================================================================
* 01_simulacion.do - DGP con endogeneidad real (Potential Outcomes Framework)
* Author: Bryan Segovia
* ============================================================================
clear all
set more off
set seed 12345
capture mkdir data
capture mkdir outputs

set obs 35000

* Variables exógenas
gen id = _n
gen age_head = int(runiform()*50) + 18
gen education_years = int(runiform()*16)
gen ln_income = rnormal(7.5, 1.2)
gen urban = rbinomial(1, 0.75)
gen region = int(runiform()*25) + 1

* Instrumento (fuerte y válido)
gen sunafil_intensity = rnormal(0.5, 0.2) + 0.15*urban

* Errores correlacionados (rho = 0.6)
drawnorm u1 u2, corr(1 0.6 \ 0.6 1)

* Tratamiento
gen formal_latent = -0.5 + 0.02*education_years - 0.01*age_head ///
                    + 0.1*urban + 1.0*sunafil_intensity + u1
gen formal_labor = (formal_latent > 0)

* Resultados potenciales
gen a0 = -0.5 + 0.1*ln_income + 0.05*education_years - 0.02*age_head + u2
gen a1 = a0 + 0.8
gen y0 = (a0 > 0)
gen y1 = (a1 > 0)
gen financial_access = cond(formal_labor==1, y1, y0)

* Efectos verdaderos
gen te = y1 - y0
quietly summarize te if formal_labor == 1
scalar att_true = r(mean)
quietly summarize te
scalar ate_true = r(mean)

* GUARDAR VALORES VERDADEROS EN ARCHIVO SEPARADO (Corrección crítica)
preserve
clear
set obs 1
gen double att = scalar(att_true)
gen double ate = scalar(ate_true)
save "data/truth.dta", replace
restore

* Eliminar variables latentes
drop a0 a1 y0 y1 te formal_latent u1 u2   

label variable formal_labor      "Labor formality (1=formal, 0=informal)"
label variable financial_access  "Access to financial system (1=yes, 0=no)"
label variable ln_income         "Log monthly household income"
label variable education_years   "Years of education"
label variable age_head          "Age of household head"
label variable urban             "Urban area (1=yes)"
label variable sunafil_intensity "SUNAFIL inspection intensity (instrument)"

tab formal_labor
summarize financial_access
display "Latent coef formal_labor = 0.8 | rho = 0.6"
display "True ATT = " att_true "  | True ATE = " ate_true

save "data/simulated_data.dta", replace
