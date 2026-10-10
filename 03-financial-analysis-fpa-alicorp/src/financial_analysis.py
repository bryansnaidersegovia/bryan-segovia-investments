"""
Análisis Financiero y Proyección del Estado de Resultados - Alicorp S.A.A.
Autor: Bryan Segovia
Fecha: 2026

Este script extrae datos financieros, calcula ratios contables clave 
y proyecta el Estado de Resultados (Ventas, Utilidad Bruta, Operativa y Neta) 
a 3 años bajo diferentes escenarios, utilizando el CAGR histórico como base.
"""

import yfinance as yf
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from typing import Tuple

sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 6)

BASE_DIR = Path(__file__).parent
OUTPUT_DIR = BASE_DIR / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

def fetch_data(ticker: str) -> Tuple[pd.DataFrame, bool, str]:
    """Extrae datos financieros. Retorna (DataFrame, es_real, moneda)."""
    print(f"[INFO] Intentando extraer datos de {ticker}...")
    try:
        empresa = yf.Ticker(ticker)
        er = empresa.financials
        
        if er is None or er.empty:
            raise ValueError("No se encontraron estados financieros.")
            
        # Obtener moneda de forma segura
        try:
            moneda = empresa.info.get('financialCurrency') or 'PEN'
        except Exception:
            moneda = 'PEN'
            
        df_er = er.T
        df_er.index = pd.to_datetime(df_er.index).year
        df_er = df_er.sort_index()
        
        cols_requeridas = ['Total Revenue', 'Gross Profit', 'Operating Income', 'Net Income']
        for col in cols_requeridas:
            if col not in df_er.columns:
                raise KeyError(f"Columna faltante en los datos: {col}")
                
        df_er = df_er.dropna(subset=['Total Revenue'])
        print(f"[OK] Datos obtenidos exitosamente. Moneda reportada: {moneda}")
        return df_er, True, moneda
        
    except Exception as e:
        print(f"[AVISO] Yahoo Finance falló o datos incompletos ({e}).")
        print("[AVISO] USANDO DATOS DE DEMOSTRACION (DEMO). Los resultados no son reales.")
        
        df_demo = pd.DataFrame({
            'Total Revenue': [9200e6, 9500e6, 9800e6, 10100e6],
            'Gross Profit': [2300e6, 2450e6, 2500e6, 2600e6],
            'Operating Income': [900e6, 980e6, 1020e6, 1080e6],
            'Net Income': [650e6, 710e6, 740e6, 790e6]
        }, index=[2022, 2023, 2024, 2025])
        
        return df_demo, False, 'PEN'

def calculate_ratios(df_er: pd.DataFrame) -> pd.DataFrame:
    """Calcula ratios financieros clave (sin redondear para mantener precisión en proyecciones)."""
    df_ratios = pd.DataFrame()
    df_ratios['Margen Bruto'] = df_er['Gross Profit'] / df_er['Total Revenue']
    df_ratios['Margen Operativo'] = df_er['Operating Income'] / df_er['Total Revenue']
    df_ratios['Margen Neto'] = df_er['Net Income'] / df_er['Total Revenue']
    df_ratios['Crecimiento Ventas (%)'] = df_er['Total Revenue'].pct_change() * 100
    return df_ratios

def project_financials(df_er: pd.DataFrame, df_ratios: pd.DataFrame) -> Tuple[pd.DataFrame, int]:
    """Proyecta el Estado de Resultados a 3 años usando CAGR histórico como base."""
    ultimo_anio = int(df_er.index[-1])
    anios_proy = [ultimo_anio + i for i in range(1, 4)]
    
    ultima_venta = float(df_er['Total Revenue'].iloc[-1])
    primera_venta = float(df_er['Total Revenue'].iloc[0])
    num_years = len(df_er) - 1
    
    # Calcular CAGR histórico para sustentar el caso base
    if num_years > 0 and primera_venta > 0:
        cagr = (ultima_venta / primera_venta) ** (1 / num_years) - 1
    else:
        cagr = 0.05  # Fallback conservador
        
    avg_margen_bruto = float(df_ratios['Margen Bruto'].mean())
    avg_margen_operativo = float(df_ratios['Margen Operativo'].mean())
    
    escenarios = {
        'Pesimista': {'crecimiento': max(0.0, cagr - 0.03), 'margen_neto': float(df_ratios['Margen Neto'].min())},
        'Base': {'crecimiento': cagr, 'margen_neto': float(df_ratios['Margen Neto'].mean())},
        'Optimista': {'crecimiento': cagr + 0.03, 'margen_neto': float(df_ratios['Margen Neto'].max())}
    }
    
    filas = []
    for nombre, p in escenarios.items():
        venta = ultima_venta
        for anio in anios_proy:
            venta *= (1 + p['crecimiento'])
            utilidad_bruta = venta * avg_margen_bruto
            utilidad_operativa = venta * avg_margen_operativo
            utilidad_neta = venta * p['margen_neto']
            
            filas.append({
                'Escenario': nombre, 
                'Año': anio,
                'Ventas': round(venta / 1e6, 1),
                'Utilidad Bruta': round(utilidad_bruta / 1e6, 1),
                'Utilidad Operativa': round(utilidad_operativa / 1e6, 1),
                'Utilidad Neta': round(utilidad_neta / 1e6, 1),
            })
            
    return pd.DataFrame(filas), ultimo_anio

def generate_plots(df_ratios: pd.DataFrame, df_proyeccion: pd.DataFrame, ultimo_anio: int, es_real: bool, moneda: str):
    """Genera y guarda visualizaciones."""
    sufijo = "" if es_real else " [DEMO]"
    
    # Gráfico 1: Márgenes
    fig, ax = plt.subplots()
    cols_margenes = ['Margen Bruto', 'Margen Operativo', 'Margen Neto']
    (df_ratios[cols_margenes] * 100).plot(marker='o', ax=ax, linewidth=2)
    ax.set_title(f'Evolucion de Margenes{sufijo}', fontsize=14, fontweight='bold')
    ax.set_ylabel('Porcentaje (%)')
    ax.set_xticks(df_ratios.index)
    ax.set_xticklabels(df_ratios.index.astype(str))
    ax.legend(loc='best')
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / f"01_margenes_historicos{'_DEMO' if not es_real else ''}.png", dpi=150, bbox_inches='tight')
    plt.close()
    
    # Gráfico 2: Proyección con línea de referencia del último año real
    fig, ax = plt.subplots()
    for esc in ['Pesimista', 'Base', 'Optimista']:
        datos = df_proyeccion[df_proyeccion['Escenario'] == esc]
        ax.plot(datos['Año'], datos['Ventas'], marker='o', label=f"{esc}", linewidth=2)
        
    ax.axvline(ultimo_anio, ls='--', color='gray', label=f'{ultimo_anio} (Ultimo real)')
    ax.set_title(f'Proyeccion de Ventas por Escenario ({moneda} millones){sufijo}', fontsize=14, fontweight='bold')
    ax.set_ylabel(f'Ventas ({moneda} millones)')
    ax.set_xticks(list(df_proyeccion['Año']) + [ultimo_anio])
    ax.legend()
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / f"02_proyeccion_escenarios{'_DEMO' if not es_real else ''}.png", dpi=150, bbox_inches='tight')
    plt.close()

def export_to_excel(df_er: pd.DataFrame, df_ratios: pd.DataFrame, df_proyeccion: pd.DataFrame, es_real: bool, moneda: str):
    """Exporta los resultados a un archivo Excel organizado con hoja de metadatos."""
    sufijo = "_DEMO" if not es_real else ""
    output_file = OUTPUT_DIR / f"Informe_Financiero{sufijo}.xlsx"
    
    df_er.index.name = 'Año'
    
    # Crear versión redondeada solo para visualización en Excel
    df_ratios_display = df_ratios.copy()
    for col in ['Margen Bruto', 'Margen Operativo', 'Margen Neto', 'Crecimiento Ventas (%)']:
        if col in df_ratios_display.columns:
            df_ratios_display[col] = (df_ratios_display[col] * 100).round(2)
            
    with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
        # Hoja de metadatos
        df_info = pd.DataFrame({
            'Parametro': ['Fuente de Datos', 'Moneda', 'Fecha de Extraccion', 'Tipo de Datos', 'Ticker'],
            'Valor': ['Yahoo Finance (SMV/BVL)', moneda, pd.Timestamp.now().strftime('%Y-%m-%d'), 'DEMO' if not es_real else 'REAL', 'ALICORC1.LM']
        })
        df_info.to_excel(writer, sheet_name='Info', index=False)
        
        df_er.to_excel(writer, sheet_name='ER_Historico')
        df_ratios_display.to_excel(writer, sheet_name='Ratios')
        df_proyeccion.to_excel(writer, sheet_name='Proyeccion_ER', index=False)
        
    print(f"[OK] Excel generado: {output_file.name}")

def main():
    print("=" * 60)
    print("ANALISIS FINANCIERO Y PROYECCION DEL ESTADO DE RESULTADOS")
    print("=" * 60)
    
    ticker = "ALICORC1.LM"
    df_er, es_real, moneda = fetch_data(ticker)
    
    print("\nCalculando ratios...")
    df_ratios = calculate_ratios(df_er)
    print((df_ratios * 100).round(2)) # Mostrar en porcentaje
    
    print("\nGenerando proyeccion a 3 años (usando CAGR historico como base)...")
    df_proyeccion, ultimo_anio = project_financials(df_er, df_ratios)
    print(df_proyeccion)
    
    print("\nGenerando visualizaciones...")
    generate_plots(df_ratios, df_proyeccion, ultimo_anio, es_real, moneda)
    
    print("\nExportando a Excel...")
    export_to_excel(df_er, df_ratios, df_proyeccion, es_real, moneda)
    
    print("\n" + "=" * 60)
    print("[EXITO] ANALISIS COMPLETADO EXITOSAMENTE")
    print("=" * 60)

if __name__ == "__main__":
    main()
