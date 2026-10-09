* ============================================================================
* Master Do-File: Credit Risk Analysis - Labor Formality & Financial Access
* Author: Bryan Segovia
* Project: Quantitative Finance Portfolio
* ============================================================================

clear all
set more off
set linesize 120
set seed 12345

* Create directories
capture mkdir data
capture mkdir outputs

* Run analysis in sequence
do "code/01_simulacion.do"
do "code/02_modelos.do"
do "code/03_robustez.do"

display ""
display "================================================================"
display "Analysis complete. All results saved to outputs/ folder."
display "================================================================"
