#  Análisis Financiero y Proyección FP&A - Alicorp S.A.A. (R)

## La idea detrás de este proyecto
En el día a día de las áreas financieras, gran parte del tiempo se pierde consolidando datos y proyectando escenarios a mano en Excel, lo que suele derivar en errores de fórmulas o de transcripción. 

Construí este pipeline en R para automatizar ese flujo: ingesta los estados financieros, calcula los ratios de rentabilidad y proyecta el Estado de Resultados a 3 años bajo distintos escenarios de estrés. El entregable final es un Excel estructurado, listo para que un gerente o comité financiero lo revise sin tener que limpiar nada.

## ️ Qué hace el script (paso a paso)
1. **Ingesta y valida:** Lee un CSV con el histórico de la empresa. Si faltan columnas clave o hay duplicados, el script se detiene y avisa en lugar de generar un reporte con números erróneos.
2. **Calcula ratios:** Obtiene márgenes (bruto, operativo y neto) y el crecimiento interanual, manteniendo la precisión de los decimales para no acumular errores de redondeo.
3. **Proyecta a 3 años:** En lugar de inventar tasas de crecimiento, ancla el "Caso Base" al CAGR histórico real de la empresa. Los escenarios de estrés (Pesimista y Optimista) ajustan ese CAGR en -3pp y +3pp, aplicando los márgenes mínimos y máximos históricos respectivamente.
4. **Visualiza y exporta:** Genera gráficos de tendencia con `ggplot2` y arma un Excel con 4 hojas separadas (Metadatos, Histórico, Ratios y Proyección).

##  Stack Tecnológico
- **Lenguaje:** R (4.0+)
- **Librerías:** `dplyr` y `tidyr` (manipulación de datos), `ggplot2` (visualización), `openxlsx` (reportes Excel sin dependencias de Java), `readr` (lectura de CSV) y `here` (para que las rutas funcionen sin importar desde dónde se ejecute el script).
- **Conceptos financieros:** CAGR, márgenes de rentabilidad, proyección Top-Down y escenarios de estrés.

## 📊 Nota importante sobre los datos
**Los datos incluidos en la carpeta `data/` son una SIMULACIÓN** basada en tendencias históricas del sector consumo masivo. Los incluí para que el pipeline pueda probarse y ejecutarse de inmediato sin depender de archivos externos. 

En un entorno real, el script está diseñado para leer directamente el CSV con los Estados Financieros auditados que se descargan del portal de la SMV o del sitio de Relaciones con Inversionistas de la empresa.

## 🚀 Cómo ejecutarlo
Si quieres probarlo en tu máquina, solo necesitas tener R instalado:

```bash
# 1. Instalar las dependencias (solo la primera vez)
Rscript requirements.R

# 2. Correr el análisis
Rscript R/financial_analysis.R
