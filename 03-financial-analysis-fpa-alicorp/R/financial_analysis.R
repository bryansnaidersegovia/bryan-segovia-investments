# ============================================================================
# Análisis Financiero y Proyección FP&A - Alicorp S.A.A.
# Autor: Bryan Segovia
# Fecha: 2026
#
# Este script automatiza el flujo de trabajo de un analista de FP&A:
# ingesta datos históricos, calcula ratios de rentabilidad y proyecta el 
# Estado de Resultados a 3 años bajo distintos escenarios de estrés.
#
# NOTA: Los datos de este repositorio son una SIMULACIÓN basada en tendencias 
# históricas del sector consumo masivo. Para un entorno de producción, 
# reemplazar el CSV con los EEFF auditados de la SMV.
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)      # Manipulación de datos (el estándar de la industria)
  library(ggplot2)    # Visualización (gramática de gráficos)
  library(openxlsx)   # Exportación a Excel (más rápido que xlsx, sin Java)
  library(readr)      # Lectura de CSVs
  library(scales)     # Formateo de ejes en ggplot
  library(tidyr)      # Pivotado de datos
  library(here)       # Rutas relativas robustas
})

theme_set(theme_minimal(base_size = 12))
options(scipen = 999) # Evitar notación científica en reportes financieros

# Rutas: here() busca la raíz del proyecto, así no importa desde dónde corras el script
DATA_DIR <- here("data")
OUTPUT_DIR <- here("output")

if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR)

# ============================================================================
# 1. INGESTA Y VALIDACIÓN DE DATOS
# ============================================================================

load_financial_data <- function() {
  # Buscamos el CSV con los EEFF. Si no existe, cargamos un escenario de 
  # simulación para que el pipeline no se rompa y podamos probar el código.
  
  csv_path <- file.path(DATA_DIR, "alicorp_eeff.csv")
  cat("[INFO] Buscando fuente de datos en:", csv_path, "\n")
  
  if (!file.exists(csv_path)) {
    cat("[INFO] CSV no encontrado. Cargando escenario de SIMULACION para pruebas.\n")
    df <- data.frame(
      Anio = 2020:2024,
      Ventas = c(8350, 9200, 10500, 11200, 11800),
      Utilidad_Bruta = c(2050, 2300, 2650, 2800, 2950),
      Utilidad_Operativa = c(750, 900, 1100, 1180, 1250),
      Utilidad_Neta = c(480, 650, 780, 820, 880)
    )
    # Trabajamos todo en millones de soles para mantener los números limpios
    return(list(data = df, es_simulacion = TRUE, moneda = "PEN"))
  }
  
  df <- read_csv(csv_path, show_col_types = FALSE)
  
  # Validación estricta: si faltan columnas clave, mejor fallar ahora que 
  # entregar un reporte con números erróneos al comité financiero.
  cols_requeridas <- c("Anio", "Ventas", "Utilidad_Bruta", "Utilidad_Operativa", "Utilidad_Neta")
  if (!all(cols_requeridas %in% names(df))) {
    stop("ERROR: El CSV no tiene las columnas requeridas. Revisa el formato.")
  }
  
  # Aseguramos tipos numéricos y limpiamos duplicados de año
  df <- df %>% 
    mutate(Anio = as.integer(Anio)) %>%
    filter(!duplicated(Anio)) %>%
    arrange(Anio)
  
  cat("[OK] Datos cargados exitosamente. Moneda: PEN (Millones de soles)\n")
  return(list(data = df, es_simulacion = FALSE, moneda = "PEN"))
}

# ============================================================================
# 2. CÁLCULO DE RATIOS DE RENTABILIDAD
# ============================================================================

calculate_ratios <- function(df) {
  # No redondeamos los márgenes en esta etapa. Si lo hiciéramos, el error de 
  # redondeo se acumularía en la proyección a 3 años. Lo dejamos en punto 
  # flotante y solo redondeamos al exportar a Excel para lectura humana.
  
  df %>%
    mutate(
      Margen_Bruto = Utilidad_Bruta / Ventas,
      Margen_Operativo = Utilidad_Operativa / Ventas,
      Margen_Neto = Utilidad_Neta / Ventas,
      Crecimiento_Ventas = (Ventas / lag(Ventas) - 1) * 100
    )
}

# ============================================================================
# 3. PROYECCIÓN DEL ESTADO DE RESULTADOS (FP&A)
# ============================================================================

project_financials <- function(df_ratios) {
  # Proyectamos a 3 años. En lugar de inventar tasas de crecimiento, anclamos 
  # el "Caso Base" al CAGR histórico real de la empresa. Los escenarios de 
  # estrés (Pesimista/Optimista) ajustan el CAGR en -3pp y +3pp.
  
  ultimo_anio <- max(df_ratios$Anio)
  anios_proy <- (ultimo_anio + 1):(ultimo_anio + 3)
  
  ultima_venta <- df_ratios$Ventas[nrow(df_ratios)]
  primera_venta <- df_ratios$Ventas[1]
  num_years <- nrow(df_ratios) - 1
  
  # Cálculo del CAGR (Tasa de Crecimiento Anual Compuesta)
  cagr <- if (num_years > 0 && primera_venta > 0) {
    (ultima_venta / primera_venta) ^ (1 / num_years) - 1
  } else {
    0.05 # Fallback conservador si no hay historial suficiente
  }
  
  cat("[INFO] CAGR histórico calculado:", round(cagr * 100, 2), "%\n")
  
  # Definimos los supuestos para los 3 escenarios. 
  # Nota: El escenario optimista apila crecimiento máximo con márgenes máximos.
  escenarios <- data.frame(
    Escenario = c("Pesimista", "Base", "Optimista"),
    crecimiento = c(max(0, cagr - 0.03), cagr, cagr + 0.03),
    Margen_Bruto = c(min(df_ratios$Margen_Bruto), mean(df_ratios$Margen_Bruto), max(df_ratios$Margen_Bruto)),
    Margen_Operativo = c(min(df_ratios$Margen_Operativo), mean(df_ratios$Margen_Operativo), max(df_ratios$Margen_Operativo)),
    Margen_Neto = c(min(df_ratios$Margen_Neto), mean(df_ratios$Margen_Neto), max(df_ratios$Margen_Neto))
  )
  
  proyecciones <- list()
  
  for (i in 1:nrow(escenarios)) {
    esc <- escenarios[i, ]
    venta <- ultima_venta
    filas_esc <- data.frame()
    
    for (anio in anios_proy) {
      venta <- venta * (1 + esc$crecimiento)
      
      fila <- data.frame(
        Escenario = esc$Escenario,
        Anio = anio,
        Ventas = venta,
        Utilidad_Bruta = venta * esc$Margen_Bruto,
        Utilidad_Operativa = venta * esc$Margen_Operativo,
        Utilidad_Neta = venta * esc$Margen_Neto
      )
      filas_esc <- rbind(filas_esc, fila)
    }
    proyecciones[[esc$Escenario]] <- filas_esc
  }
  
  df_proy <- bind_rows(proyecciones)
  return(list(data = df_proy, ultimo_anio = ultimo_anio, cagr = cagr))
}

# ============================================================================
# 4. VISUALIZACIÓN (ggplot2)
# ============================================================================

generate_plots <- function(df_ratios, df_proy, ultimo_anio, es_simulacion, moneda) {
  sufijo <- if (es_simulacion) "_SIMULACION" else ""
  
  # Gráfico 1: Evolución de márgenes históricos
  df_ratios_long <- df_ratios %>%
    select(Anio, Margen_Bruto, Margen_Operativo, Margen_Neto) %>%
    tidyr::pivot_longer(cols = -Anio, names_to = "Margen", values_to = "Valor") %>%
    mutate(Valor = Valor * 100)
  
  p1 <- ggplot(df_ratios_long, aes(x = Anio, y = Valor, color = Margen)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = scales::breaks_width(1)) +
    labs(
      title = paste0("Evolución de Márgenes", sufijo),
      subtitle = "Alicorp S.A.A. (Millones de soles)",
      x = "Año",
      y = "Porcentaje (%)",
      color = "Margen"
    ) +
    theme(plot.title = element_text(face = "bold", size = 14))
  
  ggsave(file.path(OUTPUT_DIR, paste0("01_margenes_historicos", sufijo, ".png")), 
         p1, width = 10, height = 6, dpi = 150)
  cat("[OK] Gráfico de márgenes guardado\n")
  
  # Gráfico 2: Proyección de ventas con línea de corte histórico vs futuro
  p2 <- ggplot() +
    geom_line(data = df_proy, aes(x = Anio, y = Ventas, color = Escenario, group = Escenario), linewidth = 1) +
    geom_point(data = df_proy, aes(x = Anio, y = Ventas, color = Escenario), size = 2) +
    geom_vline(xintercept = ultimo_anio, linetype = "dashed", color = "gray") +
    annotate("text", x = ultimo_anio + 0.1, y = max(df_proy$Ventas) * 0.95,
             label = paste0(ultimo_anio, " (Histórico)"), color = "gray", hjust = 0) +
    scale_x_continuous(breaks = scales::breaks_width(1)) +
    labs(
      title = paste0("Proyección de Ventas por Escenario", sufijo),
      subtitle = paste0("En ", moneda, " millones"),
      x = "Año",
      y = paste0("Ventas (", moneda, " millones)"),
      color = "Escenario"
    ) +
    theme(plot.title = element_text(face = "bold", size = 14))
  
  ggsave(file.path(OUTPUT_DIR, paste0("02_proyeccion_escenarios", sufijo, ".png")), 
         p2, width = 10, height = 6, dpi = 150)
  cat("[OK] Gráfico de proyección guardado\n")
}

# ============================================================================
# 5. EXPORTACIÓN A EXCEL (Entregable para el negocio)
# ============================================================================

export_to_excel <- function(df_er, df_ratios, df_proy, es_simulacion, moneda, cagr) {
  sufijo <- if (es_simulacion) "_SIMULACION" else ""
  output_file <- file.path(OUTPUT_DIR, paste0("Informe_Financiero", sufijo, ".xlsx"))
  
  # Preparamos la hoja de ratios redondeada para lectura humana
  df_ratios_display <- df_ratios %>%
    mutate(across(starts_with("Margen"), ~ round(. * 100, 2)),
           Crecimiento_Ventas = round(Crecimiento_Ventas, 2))
  
  # Movemos la columna Año al inicio (mejor UX para el usuario final)
  df_er <- df_er %>% relocate(Anio)
  df_ratios_display <- df_ratios_display %>% relocate(Anio)
  
  wb <- createWorkbook()
  
  # Hoja 1: Metadatos del reporte
  df_info <- data.frame(
    Parametro = c("Fuente de Datos", "Moneda", "Fecha de Generacion", 
                  "Tipo de Datos", "Ticker", "CAGR Historico", "Unidad"),
    Valor = c("CSV local / SMV", moneda, as.character(Sys.Date()),
              if (es_simulacion) "SIMULACION" else "REAL", "ALICORC1",
              paste0(round(cagr * 100, 2), "%"), "Millones de soles")
  )
  addWorksheet(wb, "Info")
  writeData(wb, "Info", df_info)
  
  # Hojas de datos
  addWorksheet(wb, "EEFF_Historico")
  writeData(wb, "EEFF_Historico", df_er)
  
  addWorksheet(wb, "Ratios")
  writeData(wb, "Ratios", df_ratios_display)
  
  addWorksheet(wb, "Proyeccion_ER")
  writeData(wb, "Proyeccion_ER", df_proy)
  
  saveWorkbook(wb, output_file, overwrite = TRUE)
  cat("[OK] Excel generado:", output_file, "\n")
}

# ============================================================================
# 6. EJECUCIÓN PRINCIPAL
# ============================================================================

main <- function() {
  cat("============================================================\n")
  cat("ANÁLISIS FINANCIERO Y PROYECCIÓN FP&A (ALICORP)\n")
  cat("============================================================\n\n")
  
  # 1. Ingesta
  res_data <- load_financial_data()
  df_er <- res_data$data
  es_simulacion <- res_data$es_simulacion
  moneda <- res_data$moneda
  
  # 2. Ratios
  cat("\nCalculando ratios de rentabilidad...\n")
  df_ratios <- calculate_ratios(df_er)
  print(df_ratios %>% select(Anio, starts_with("Margen")) %>% 
          mutate(across(-Anio, ~ round(. * 100, 2))))
  
  # 3. Proyección
  cat("\nGenerando proyección a 3 años (Escenarios de estrés)...\n")
  res_proy <- project_financials(df_ratios)
  df_proy <- res_proy$data
  ultimo_anio <- res_proy$ultimo_anio
  cagr <- res_proy$cagr
  
  # 4. Gráficos
  cat("\nRenderizando visualizaciones...\n")
  generate_plots(df_ratios, df_proy, ultimo_anio, es_simulacion, moneda)
  
  # 5. Excel
  cat("\nExportando entregable a Excel...\n")
  export_to_excel(df_er, df_ratios, df_proy, es_simulacion, moneda, cagr)
  
  cat("\n============================================================\n")
  cat("[EXITO] PIPELINE COMPLETADO SIN ERRORES\n")
  cat("============================================================\n")
}

# Correr el pipeline
main()
