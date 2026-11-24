# API-POP | Descripción de la aplicación

**Versión de referencia:** familia v2.x de API-POP. **Revisión documental:** 23 de noviembre de 2026.

API-POP permite consultar registros de casos sospechosos, aplicar filtros demográficos, temporales y geográficos, revisar archivos antes de agregarlos a la fuente de datos configurada y descargar resultados de casos o resúmenes semanales. El resumen incluye `n_cases` y, cuando existe una asociación válida con la capa geográfica, `population`.

## Documentación disponible

- **Manual de usuario (inglés):** [USER_GUIDE.md](USER_GUIDE.md)
- **Instalación institucional y configuración de países (inglés):** [INSTITUTIONAL_SETUP_GUIDE.md](INSTITUTIONAL_SETUP_GUIDE.md)
- **Guía para desarrolladores (inglés):** [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)
- **Diccionarios de datos:** [Data_Dictionary_API-Pop.md](Data_Dictionary_API-Pop.md), [Data_Dictionary_API-Pop_cases.md](Data_Dictionary_API-Pop_cases.md), [Data_Dictionary_API-Pop_weekly_pop.md](Data_Dictionary_API-Pop_weekly_pop.md)

**Advertencias:** agregar archivos modifica la tabla configurada; el inicio puede añadir columnas de normalización. El soporte de conexión ODBC no equivale a compatibilidad automática con cualquier base de datos. La aplicación actual no incluye adaptación automática a esquemas de bases de datos arbitrarios ni conmutación automática de almacenamiento. No se deben usar datos reales sin controles institucionales, copias de seguridad y pruebas previas.

Esta página es una orientación en español. Las guías técnicas detalladas de la presente distribución están en inglés; no se presenta esta página como una traducción integral de dichos manuales.
