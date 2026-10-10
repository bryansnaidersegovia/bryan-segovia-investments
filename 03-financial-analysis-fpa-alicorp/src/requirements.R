# ============================================================================
# Instalación de dependencias para el Proyecto 03: Análisis Financiero FP&A
# Ejecutar en la terminal: Rscript requirements.R
# ============================================================================

paquetes_necesarios <- c(
  "dplyr",      # Manipulación de datos
  "ggplot2",    # Visualización profesional
  "openxlsx",   # Exportación a Excel (rápido, sin dependencias de Java)
  "readr",      # Lectura eficiente de CSV
  "scales",     # Formateo de ejes en ggplot2
  "tidyr",      # Pivotado y remodelado de datos
  "here"        # Manejo robusto de rutas relativas
)

# Verificar cuáles faltan e instalarlos
paquetes_faltantes <- paquetes_necesarios[!(paquetes_necesarios %in% installed.packages()[, "Package"])]

if (length(paquetes_faltantes) > 0) {
  cat("Instalando paquetes faltantes:", paste(paquetes_faltantes, collapse = ", "), "\n")
  install.packages(paquetes_faltantes, dependencies = TRUE, repos = "https://cloud.r-project.org")
  cat("✅ Instalación completada.\n")
} else {
  cat("✅ Todos los paquetes necesarios ya están instalados y listos.\n")
}

cat("\nPara ejecutar el análisis, corre el siguiente comando en tu terminal:\n")
cat("Rscript R/financial_analysis.R\n")
