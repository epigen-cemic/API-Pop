# API-POP – Herramienta de filtrado de casos sospechosos y salidas poblacionales

**Versión:** `v2.0`

API-POP es una aplicación R/Shiny para filtrar registros de casos sospechosos y generar salidas compatibles con análisis epidemiológicos y herramientas RAP como CUSUM RAP, Geospatial RAP y el Digital Dashboard.

## Novedades de la versión 2.0

- Revisión de múltiples archivos cargados.
- Estado de archivos permitidos/no permitidos antes de anexar registros.
- Tabla de revisión de archivos movida a una ventana emergente.
- Flujo de datos cargados localmente sin exponer detalles internos de base de datos al usuario.
- Soporte para conexión a base de datos externa.
- Las cargas de archivos pueden seguir habilitadas aunque exista una base externa configurada.
- Nombres de niveles geográficos controlados por configuración.
- Soporte para `level3_norm` en filtros de tercer nivel.
- La salida semanal usa `n_cases`.
- Nombres de descarga con fecha y hora.
- Estilo visual alineado con el Digital Dashboard.
- Estructura de funciones compartidas en `R/shared/`.

## Funcionalidades

- Filtros dinámicos por país y niveles geográficos.
- Filtros demográficos según los campos disponibles, como sexo y fecha de nacimiento.
- Filtro por fecha de inicio de síntomas.
- Filtros por diagnóstico sospechado y descripción de síntomas.
- Descarga de lista detallada de casos filtrados.
- Descarga de resumen semanal de casos y población.
- Fuente de datos local o externa configurable.
- Soporte para los formatos de carga ya existentes, incluyendo CSV, Excel, XML y archivos de base local cuando estén habilitados.

## Requisitos

Recomendado:

- R >= 4.2
- RStudio u otro IDE de R
- Paquetes principales:

```r
install.packages(c(
  "shiny",
  "shinyjs",
  "DT",
  "dplyr",
  "DBI",
  "RSQLite",
  "pool",
  "config",
  "yaml",
  "jsonlite",
  "readr",
  "readxl",
  "xml2",
  "here",
  "uuid"
))
```

Los despliegues con base de datos externa pueden requerir paquetes o drivers adicionales, como `odbc`.

## Ejecutar localmente

```r
setwd("ruta/a/API-Pop")
shiny::runApp()
```

O desde una terminal:

```bash
Rscript --vanilla -e "shiny::runApp('.', host = '127.0.0.1', port = 3838)"
```

## Modos de fuente de datos

API-POP v2.0 permite:

| Modo | Descripción |
|---|---|
| Datos cargados localmente | El usuario carga archivos y los registros válidos se anexan al almacenamiento local de la app. |
| Base de datos externa | Un administrador configura la conexión en `config.yaml`. |
| Flujo mixto | La base externa está configurada, pero la carga de archivos sigue habilitada. |

La base local interna no debería presentarse al usuario final como una base de datos. En textos de usuario, usar términos como datos locales de la app o datos cargados.

## Configuración

Archivos principales:

| Archivo | Propósito |
|---|---|
| `config.yaml` | Perfil de ejecución, fuente de datos, conexión/ruta de datos y rutas de la app. |
| `config.json` | Mapeos de país, niveles geográficos y nombres visibles. |
| `WWW/config.css` | Tema y estilo visual. |
| `.Renviron` | Variables locales, perfiles o secretos. No debe subirse al repositorio. |

## Salidas estándar

### Lista de casos filtrados

Contiene los registros detallados que coinciden con los filtros seleccionados. Ver `Data_Dictionary_API-Pop_cases.md`.

### Resumen semanal

Salida agregada para herramientas RAP. Ver `Data_Dictionary_API-Pop_weekly_pop.md`.

La columna de conteo en v2.0 es:

```text
n_cases
```

## Scripts de preparación de datos

| Script | Propósito |
|---|---|
| `data_prep/merge_layers.R` | Preparar archivos `.gpkg` por país para los filtros geográficos. |
| `data_prep/connect_database_example.R` | Ejemplo para probar una conexión a fuente de datos externa. |
| `data_prep/prepare_api_pop_database.R` | Preparar o reiniciar los datos locales de la app para pruebas. |

## Lista de control antes de publicar

Antes de desplegar:

- Confirmar que la app inicia correctamente.
- Probar carga de archivo válido.
- Probar carga de archivo inválido.
- Confirmar que la revisión de archivos se abre en una ventana emergente.
- Confirmar que los filtros cargan sin errores de `level3_norm`.
- Confirmar la descarga de casos filtrados.
- Confirmar que el resumen semanal contiene `n_cases`.
- Confirmar nombres de descarga con fecha y hora.
- Confirmar que no se suben credenciales.
- Confirmar que no se suben datos de prueba o datos reales dentro de archivos locales.

## Contacto

**Proyecto:** PPT-UK – Argentina Work Package WS5
**Institución / Delivery Partner:** CEMIC
