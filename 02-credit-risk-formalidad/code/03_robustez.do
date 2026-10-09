* ============================================================================
* 03_robustez.do - Rosenbaum Bounds y comparación con los valores verdaderos
* Author: Bryan Segovia
* ============================================================================
clear all
set more off
set seed 12345
capture mkdir outputs
capture log close
log using "outputs/03_robustez.log", replace text

* ssc install psmatch2, replace
* ssc install mhbounds, replace

use "data/simulated_data.dta", clear

* Valores verdaderos del DGP (Cargados desde archivo)
preserve
use "data/truth.dta", clear
scalar att_true = att[1]
scalar ate_true = ate[1]
restore

* ----------------------------------------------------------------------------
* 3.1 Propensity score y matching 1-a-1
* ----------------------------------------------------------------------------
logit formal_labor ln_income education_years age_head i.urban i.region
predict double pscore, pr

* Orden aleatorio para desempates reproducibles
gen double rnd = runiform()
sort rnd

psmatch2 formal_labor, pscore(pscore) outcome(financial_access) ///
    neighbor(1) common noreplacement
scalar att_psm = r(att)      // guardar de inmediato: mhbounds sobrescribe r()

* ----------------------------------------------------------------------------
* 3.2 Rosenbaum bounds (outcome binario)
* ----------------------------------------------------------------------------
mhbounds financial_access, gamma(1(0.1)2)
* Lectura: busca el primer gamma donde el p-valor de Q_mh- supere 0.05 (gamma crítico).

* ----------------------------------------------------------------------------
* 3.3 Comparación contra los valores verdaderos (calculada, no escrita)
* ----------------------------------------------------------------------------
display ""
display "================================================================"
display "VALIDACIÓN: estimadores vs. verdad del DGP"
display "================================================================"
display "True ATT (DGP):     " %6.3f att_true
display "True ATE (DGP):     " %6.3f ate_true
display "PSM ATT (1-a-1):    " %6.3f att_psm
display "Sesgo PSM:          " %6.3f (att_psm - att_true)
display ""
display "Latent coef verdadero (formal_labor): 0.8 | rho verdadero: 0.6"
display "Compara estos valores con la salida de 02_modelos.do (biprobit y probit naive)"
display "================================================================"

log close
