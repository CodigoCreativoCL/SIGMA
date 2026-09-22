# SIGMA — Traspaso al equipo

**Fecha:** 22-09-2026 · **Rama:** `BryanChavez` (sin push a `master`, `EmilioFuentes` ni `CatalinaPescio`) ·
**API compila:** 0 errores · **Web precompila:** sin errores · **Último commit:** ver `git log --oneline -1` en `BryanChavez`

Este documento es el punto de entrada para retomar el trabajo **como equipo** después de
la Investigación Azure Machine Learning. Es corto a propósito: dice dónde está cada cosa,
en qué estado van los sprints y qué toca a cada uno. El detalle vive en los documentos
que enlaza.

---

## 1. Dónde está todo

| Cosa | Ruta / referencia |
|---|---|
| Web (intranet, WebForms) | `Web/Intranet` · precompilar con `aspnet_compiler -v /Check -p C:\Capstone\SIGMA\Web\Intranet C:\temp\salida -f` |
| API (ASP.NET 4.8) | `Solucion/SIGMA/API` · MSBuild tras **cada** cambio en C# (0 errores) |
| App Flutter | `App/sigma_app` · **MVP de Bryan**, no oficial hasta el Sprint 6 (no se marca como realizado) |
| Base de datos | `sql5112.site4now.net` · `db_acd593_sigma` · scripts numerados en `BD/` (último: **248**) · clave solo en `API/Web.config` |
| Entrenadores SIGMA AI | `ML/` (`sigma_ml.py`, `entrenar_falla.py`, `entrenar_rul.py`, `entrenar_vision.py`, `.env.ejemplo`) |
| Gestión Scrum | `Fase 2/`: Product Backlog por Sprint, Sprint Backlogs S1–S6, Burndown, Bitácora Daily, Ceremonias, Pruebas |
| Estado técnico e historia | `MD/SIGMA_ESTADO_DESARROLLO.md` (bitácora §9) · `MD/SIGMA_CHECKLIST_PENDIENTES.md` (§10.x por bloque) |
| Investigación Azure ML | `Fase 2/SIGMA_Investigacion_Azure_ML.docx` (informe) · `MD/SIGMA_INVESTIGACION_AZURE_ML.md` (detalle técnico y guía) |
| Evidencia de pruebas | `Fase 2/Pruebas/SIGMA_Informe_Pruebas_Sprint_N.docx` + `Fase 2/Pruebas/capturas/S1..S6, AzureML` |

**Reglas que no se negocian:** leer `MD/PATRONES` antes de escribir SQL o C#; archivos UTF-8 con BOM y CRLF;
la seguridad de pantallas es un INSERT en `Menus`, no código; las claves nunca viajan por chat ni por
correo (van a `Web.config` o a `ML/.env`, que está en `.gitignore`); lo móvil no se marca como
entregado antes del Sprint 6.

---

## 2. Calendario y estado real de los sprints (22-09-2026)

Plan (`Product Backlog › Plan de Sprints`): S1 02–15/09 · **S2 16–29/09 (en curso)** · S3 30/09–13/10 ·
S4 14–27/10 · S5 28/10–10/11 · S6 11–24/11 (app móvil, SIGMA AI, dashboard, suscripción, importación) ·
Cierre 25/11–01/12.

Estado según los Sprint Backlogs (tareas) y las pruebas con evidencia (criterios verificados):

| Sprint | Tareas | Terminadas | En revisión | Por hacer | Movidas a S6 | Historias | Criterios verificados | Informe de pruebas |
|---|---|---|---|---|---|---|---|---|
| S1 Fundaciones | 251 | 131 | 38 | 41 | 7 | 17 en revisión | 20 / 46 | 26 casos, 22 ✓ (9 HU) |
| **S2 Activos (en curso)** | 252 | 164 | — | 34 | 54 | 14 en revisión · 3 en curso · 1 terminada · 4 movidas | 53 / 56 | 52 casos, 49 ✓ (18 HU) |
| S3 Recursos y recurrencia | 336 | 270 | 3 | 32 | 21 | 22 en revisión · 6 en curso · 1 movida | 54 / 58 | 64 casos, 63 ✓ (23 HU) |
| S4 Trabajo planificado | 274 | 75 | — | 120 | 69 | 8 en revisión · 11 por hacer · 5 movidas | 32 / 74 | 23 casos, 20 ✓ (8 HU) |
| S5 Ejecución | 313 | 89 | — | 71 | 153 | 8 en revisión · 6 por hacer · 12 movidas | 43 / 83 | 48 casos, 48 ✓ (14 HU) |
| S6 App, IA y cierre | 508 | — | 7 (investigación) | 501 | — | 67 por hacer | — | 16 casos app (MVP), 16 ✓ |

Lectura honesta:

- **El equipo va adelantado respecto del calendario**: S2 está en curso y S3 tiene 270 de 336 tareas
  terminadas y 63 de 64 casos probados. Bryan construyó y probó la mayor parte de S3 (224 tareas) y una
  parte de S4/S5 (65 + 89).
- **S1 tiene 26 criterios sin verificar** (HU-002/003/005/006/011/016/017/021 de Emilio; HU-004 y HU-014
  de Bryan): las pantallas existen, falta correr la evidencia. Es la deuda más antigua.
- **S4 y S5 dependen de Emilio y Catalina**: 120 y 71 tareas «Por hacer», y 10 bloqueadas en S4 porque
  HU-082/091/093/097 (actividades, umbrales, publicar plantilla, historial de pauta) aún no están en el
  repositorio. Sin eso no hay prueba posible.
- **Por persona (S1–S5, tareas)**: Bryan 489 terminadas / 31 por hacer / 10 bloqueadas; Emilio 168
  terminadas / 89 por hacer / 22 en revisión; Catalina 72 terminadas / 178 por hacer.
- **S6** concentra todo lo móvil (304 tareas movidas), la infraestructura externa (SMTP, blob, Maps, push,
  HTTPS) y SIGMA AI (HU-170 a HU-178). La investigación dejó 7 tareas de Bryan «En revisión» y 8 de
  Emilio/Catalina anotadas como cubiertas, para resolver en el Sprint Planning 6.

---

## 3. Qué le toca a cada uno ahora

**Emilio**
- S1: evidencia de HU-002, 003, 005, 006, 011, 016, 017, 021 (criterios en «No»; pantallas construidas).
- S2: HU-036 tiene criterios en «No»; HU-037 y HU-038 «En curso».
- S4: HU-084, 086, 093 (publicar plantilla, sin merge), 094, 100 «Por hacer»; S4/S5: 55 + 22 tareas.
- Su rama `EmilioFuentes` ya está fusionada en `BryanChavez` (0 commits pendientes).

**Catalina**
- S4: HU-082 (actividades), 087, 091 (umbrales), 092, 097 (historial de pauta), 101 «Por hacer»; HU-082/091/097
  no están en el repo y bloquean 10 tareas de prueba de Bryan. Su rama `CatalinaPescio` tiene **10 commits
  sin fusionar** (API móvil, Bcl.Memory): revisar y fusionar en el Sprint Planning.
- S4/S5: 65 + 22 tareas «Por hacer».

**Bryan**
- Regenerar las claves de `SIGMAVISION` y `SIGMAVISIONMODEL-Prediction` (aparecieron en el chat) y pegar la
  nueva en `Web.config`; después decidir si `Web.config` se versiona con esa clave (hoy está fuera del commit).
- Cambiar la contraseña de la cuenta de Azure (también apareció en el chat).
- S1: HU-004 #2/#3 y HU-014 #2/#3 (criterios en «No»). S2: HU-193 (un criterio en «No», app) y HU-194 «En curso».
- S5: 27 tareas «Por hacer» (HU-117 ×4, 118 ×2, 125 ×2, 131 ×5, 142 ×3, 143 ×5, 162 ×6).
- S6: llevar al Sprint Planning 6 las 15 tareas anotadas por la investigación y la propuesta de producción
  (Container Apps Job + GHCR + identidad administrada).

**Los tres (Sprint Planning 6, antes del 11-11)**
- Cerrar las verificaciones pendientes de S1 (26 criterios) y S4/S5 (42 + 40).
- Confirmar el reparto de EP-17 con lo que la investigación dejó: HU-171/172 casi completas, HU-170 y
  HU-177 por construir, HU-178 depende de HU-177.
- Definir hosting de producción (site4now sigue para web/API; Python solo para reentrenar).

---

## 4. SIGMA AI: cómo se opera hoy

| Paso | Cómo |
|---|---|
| Ver estado | Web › **SIGMA AI › Experimentos** (selector FAILURE / RUL / VISION) |
| Registrar dataset | Tarjeta 1 · o `POST /sigma-ai/datasets?modelo=` |
| Entrenar | `cd ML` · `az login` una vez · `python entrenar_falla.py --usuario <login> --dataset <id>` (igual `entrenar_rul.py`; `entrenar_vision.py` necesita `ML/.env` con las claves de Custom Vision) |
| Publicar / verificar en Azure | Tarjeta 3 · «Publicar», «Verificar en Azure», «Tomar los pesos desde Azure ML» |
| Puntuar | Tarjeta 4 · `POST /sigma-ai/predecir?modelo=` (FAILURE y RUL) · `POST /sigma-ai/vision/clasificar` (VISION) |
| Confirmar una etiqueta (VISION) | `POST /sigma-ai/vision/confirmar` — alimenta el siguiente dataset |
| Registrado en Azure ML hoy | `SIGMA_FAILURE_30D` v1–v2 · `SIGMA_RUL` v1 · `SIGMA_VISION` v1 (área `SIGMA_AI`, East US 2) · sin cómputo, sin endpoints |

Versiones publicadas en SIGMA: FAILURE v2, RUL v1, VISION v1 — **entrenadas con datos sintéticos**
(marcado en la observación de cada versión). Sirven para demostrar el camino, no para decidir sobre
una máquina; el modelo de línea base (Tendencia de variable medida) sigue operando.

---

## 5. Datos de prueba que quedaron en la base

Cliente Hamburgo (1): programaciones «Evidencia S3 · …», tipo global «Equipo rotatorio», Blower ACT-55/56,
proveedor Montajes Andinos, procedimiento PRC-ACEITE-BLW v2, permisos PT-S3-*, horómetros MED-35/43/44-H,
hitos COND-TEMP y COND-VIB-CORR, OTs 56–58, datasets `FALLA30-20260918-0120` y `RUL-20260918-0449`,
predicciones de SIGMA FAILURE (22 equipos) y SIGMA RUL (1 instalación) con alertas #78–81, revisiones
visuales 1–2 (una confirmada como NORMAL). Nada de esto estorba a las pruebas; se identifica por nombre.

Usuarios de prueba: rodrigo (jefe), emilio (planificador), paula, cristian (técnico), marcela (admin
cliente), ximena (bodeguera), catalina/root (Root). Contraseña común de pruebas en `_scratch/evidencia.py`.
