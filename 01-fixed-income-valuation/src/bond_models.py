"""
Bond Valuation and Risk Modeling Module
Author: Bryan Segovia
Project: Fixed Income Valuation for Investment Analysis
Tools: Python, NumPy, Pandas, Matplotlib

Disclaimer: All bond parameters are simulated for educational purposes.
They do not represent live market quotes from MEF or Bloomberg Terminal.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


class BondAnalyzer:
    """Bond pricing and risk metrics calculator"""
    
    def __init__(self, face_value, coupon_rate, maturity, ytm, frequency=2):
        self.face_value = face_value
        self.coupon_rate = coupon_rate
        self.maturity = maturity
        self.ytm = ytm
        self.frequency = frequency
        self.coupon_payment = face_value * coupon_rate / frequency
    
    def _cashflows(self):
        """Helper method to calculate periods, cash flows, and discount factors"""
        n_periods = int(self.maturity * self.frequency)
        periods = np.arange(1, n_periods + 1)
        cash_flows = np.full(n_periods, self.coupon_payment)
        cash_flows[-1] += self.face_value
        discount_rate = self.ytm / self.frequency
        discount_factors = (1 + discount_rate) ** periods
        return periods, cash_flows, discount_factors

    def bond_price(self):
        """Calculate bond price using present value of cash flows"""
        _, cash_flows, discount_factors = self._cashflows()
        return np.sum(cash_flows / discount_factors)
    
    def macaulay_duration(self):
        """Calculate Macaulay Duration (in years)"""
        periods, cash_flows, discount_factors = self._cashflows()
        pv_cash_flows = cash_flows / discount_factors
        price = np.sum(pv_cash_flows)
        weighted_time = np.sum(periods * pv_cash_flows) / price
        return weighted_time / self.frequency
    
    def modified_duration(self):
        """Calculate Modified Duration"""
        return self.macaulay_duration() / (1 + self.ytm / self.frequency)
    
    def convexity(self):
        """Calculate Convexity (annualized)"""
        periods, cash_flows, discount_factors = self._cashflows()
        pv_cash_flows = cash_flows / discount_factors
        price = np.sum(pv_cash_flows)
        discount_rate = self.ytm / self.frequency
        
        convexity_sum = np.sum(periods * (periods + 1) * pv_cash_flows)
        return (convexity_sum / (price * (1 + discount_rate) ** 2)) / (self.frequency ** 2)
    
    def price_sensitivity(self, yield_change_bps):
        """Estimate price change percentage for a given yield shift in basis points"""
        mod_dur = self.modified_duration()
        conv = self.convexity()
        dy = yield_change_bps / 10000
        pct_change = -mod_dur * dy + 0.5 * conv * (dy ** 2)
        return pct_change * 100  # Return as percentage

    def summary(self):
        """Returns a dictionary with all key metrics"""
        return {
            'Price': round(self.bond_price(), 2),
            'Macaulay Duration': round(self.macaulay_duration(), 2),
            'Modified Duration': round(self.modified_duration(), 2),
            'Convexity': round(self.convexity(), 2),
            'Sensitivity +100bps': round(self.price_sensitivity(100), 2),
            'Sensitivity -50bps': round(self.price_sensitivity(-50), 2)
        }

    def plot_price_yield_curve(self, yield_range_bps=200):
        """Plot exact price vs yield, and approximations using duration/convexity"""
        base_ytm = self.ytm
        yields = np.linspace(base_ytm - yield_range_bps/10000, base_ytm + yield_range_bps/10000, 100)
        
        exact_prices = []
        approx_prices_dur = []
        approx_prices_dur_conv = []
        base_price = self.bond_price()
        
        for y in yields:
            self.ytm = y
            exact_prices.append(self.bond_price())
            
            # Reset ytm for approximation formulas
            self.ytm = base_ytm
            dy = y - base_ytm
            mod_dur = self.modified_duration()
            conv = self.convexity()
            
            approx_dur = base_price * (1 - mod_dur * dy)
            approx_dur_conv = base_price * (1 - mod_dur * dy + 0.5 * conv * dy**2)
            
            approx_prices_dur.append(approx_dur)
            approx_prices_dur_conv.append(approx_dur_conv)
            
        self.ytm = base_ytm  # Reset to original
        
        plt.figure(figsize=(10, 6))
        plt.plot(yields * 100, exact_prices, label='Exact Price', linewidth=2, color='blue')
        plt.plot(yields * 100, approx_prices_dur, label='Duration Approx (Linear)', linestyle='--', color='red')
        plt.plot(yields * 100, approx_prices_dur_conv, label='Duration + Convexity Approx', linestyle='-.', color='green')
        
        plt.axvline(x=base_ytm * 100, color='gray', linestyle=':', label='Current YTM')
        plt.title('Bond Price Sensitivity to Yield Changes')
        plt.xlabel('Yield to Maturity (%)')
        plt.ylabel('Bond Price')
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig('price_yield_curve.png', dpi=300)
        plt.show()


def analyze_bond_portfolio(bonds_df):
    """Analyze a portfolio of bonds and return metrics DataFrame"""
    results = []
    for _, row in bonds_df.iterrows():
        bond = BondAnalyzer(
            face_value=row['face_value'],
            coupon_rate=row['coupon_rate'],
            maturity=row['maturity'],
            ytm=row['ytm'],
            frequency=row.get('frequency', 2)
        )
        metrics = bond.summary()
        metrics['name'] = row['name']
        results.append(metrics)
    return pd.DataFrame(results)


if __name__ == "__main__":
    # 1. Unit Test: If Coupon == YTM, Price must equal Face Value (Par)
    test_bond = BondAnalyzer(face_value=1000, coupon_rate=0.05, maturity=5, ytm=0.05)
    assert abs(test_bond.bond_price() - 1000) < 0.01, "Unit Test Failed: Par bond price mismatch"
    print("✅ Unit Test Passed: Par bond priced correctly at 1000.00\n")

    # 2. Portfolio Analysis (Simulated Peruvian Sovereign Bonds, Base Year: 2026)
    bonds = pd.DataFrame([
        {'name': 'Bono Soberano 2028 (2Y)', 'face_value': 1000, 'coupon_rate': 0.055, 'maturity': 2, 'ytm': 0.062},
        {'name': 'Bono Soberano 2031 (5Y)', 'face_value': 1000, 'coupon_rate': 0.060, 'maturity': 5, 'ytm': 0.065},
        {'name': 'Bono Soberano 2036 (10Y)', 'face_value': 1000, 'coupon_rate': 0.068, 'maturity': 10, 'ytm': 0.072},
        {'name': 'Bono Soberano 2056 (30Y)', 'face_value': 1000, 'coupon_rate': 0.075, 'maturity': 30, 'ytm': 0.080}
    ])
    
    print("Portfolio Risk Metrics:")
    portfolio = analyze_bond_portfolio(bonds)
    print(portfolio[['name', 'Price', 'Modified Duration', 'Convexity', 'Sensitivity +100bps']].to_string(index=False))
    
    # 3. Generate Plot for the 10Y Bond
    print("\nGenerating Price vs Yield curve for 10Y Bond...")
    bond_10y = BondAnalyzer(face_value=1000, coupon_rate=0.068, maturity=10, ytm=0.072)
    bond_10y.plot_price_yield_curve()
