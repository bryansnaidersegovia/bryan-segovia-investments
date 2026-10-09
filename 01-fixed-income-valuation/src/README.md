# 01 - Fixed Income Valuation & Risk Modeling

## Objective
Develop a quantitative framework to price fixed income instruments, measure interest rate risk (Duration and Convexity), and simulate portfolio sensitivity to yield curve shifts.

## Methodology
- **Bond Pricing:** Discounted Cash Flow (DCF) model adjusting for coupon frequency.
- **Risk Metrics:** Analytical calculation of Macaulay Duration, Modified Duration, and Convexity.
- **Sensitivity Analysis:** Taylor series expansion (up to the second order) to estimate price changes under parallel yield shifts (+100 bps, -50 bps).
- **Visualization:** Price-Yield curve comparing exact pricing against linear (Duration) and convex (Duration + Convexity) approximations.

## Key Findings
- Convexity provides a critical positive adjustment for long-dated bonds (e.g., 30Y), underestimating price appreciation when rates fall and overestimating depreciation when rates rise.
- A 100 bps parallel shift impacts the 30Y bond portfolio value by approximately -11.5%, compared to -1.8% for the 2Y bond, highlighting duration risk in long-end allocations.

## Project Structure
- `src/bond_models.py`: Core Python module containing the `BondAnalyzer` class, portfolio analysis functions, and unit tests.

## How to Run
```bash
pip install numpy pandas matplotlib
python src/bond_models.py
