# Traspaso para Catalina Pescio — 11-10-2026 (actualizado 12-10-2026)
Rama: `CatalinaPescio` (sin commits propios; al 12-10-2026 está 58 commits atrás de `master`).

## 1. Qué hacer en tu rama
1. `git fetch && git merge origin/master` — avance directo, sin conflictos.
2. Antes de crear una migración SQL: `python -I Dev/siguiente_migracion.py` (mira master y todas las ramas; hoy el siguiente libre es 453).
3. Abre `Boveda/` en Obsidian (opcional) y lee `Boveda/00 Inicio.md`.

## 2. Qué cambió en el repo (para no buscar donde ya no está)
- `PATRONES/ASP` → `Boveda/Patrones/`. `ENTRENAMIENTO`, `SIGMA-Pautas-360`, `INFRAESTRUCTURA`, `docs/` y `Fase 2/Diseno/capturas` ya no existen.
- Docker → `Docker/`. Diseño → `Fase 2/Diseno/{1_Esquema_BD,2_Diseno_Web,3_Diseno_App}` (rediseños en `2_Diseno_Web/Redisenos/<módulo>/`).
- BD: migraciones en `BD/NNN_*.sql`; índice por tema en `Boveda/Base de datos/Indice de base de datos.md`; semillas en `BD/Semillas/`, respaldos en `BD/Respaldos/`.
- Herramientas compartidas en `Dev/`: `bom.py`, `sql_aplicar.py`, `siguiente_migracion.py`, `actualizar_boveda.py`.
- Entran a tu rama: calendarios por medidor editables, HU-117/HU-125 (S5), ficha de OT v8, plan de sopladores Hamburgo, mejoras de rendimiento (`Min Pool Size=20`, caché por sesión, lecturas en paralelo) el trabajo de Terceros de Emilio (BD 437/438) y sus HU-131 (rectificación de bitácora) y HU-162 (Accesibilidad del usuario, BD 442–449).
- `C:\Capstone` debe contener solo `SIGMA`; borradores y evidencia personal fuera (p. ej. `C:\Capstone_Archivo`).

## 3. Memoria local de Claude a guardar (créala en tu memoria; no la copies al repo)
- **cerebro-boveda-compartida** (project): el conocimiento de SIGMA vive en `Boveda/` del repo; al iniciar usar la skill `sigma-cerebro`; al terminar un bloque, `sigma-cerrar-bloque`. El MD de estado no se lee entero: grep puntual. Objetivo: ahorrar tokens y trabajar con el mismo estándar los tres.
- **reglas-equipo-sigma** (feedback): resumen de `Boveda/Reglas del equipo.md`.
- **rutas-nuevas-repo** (reference): las rutas del punto 2.
- Si tu memoria cita `PATRONES\ASP`, `C:\Capstone\MD\...` o `_scratch/bom.py`, corrígelas a `Boveda/Patrones`, `C:\Capstone\SIGMA\MD\...` y `Dev/bom.py`.

## 4. Lee también `Boveda/Sesion/Traspaso_Bryan.md`
Zonas de trabajo de Bryan, archivos «calientes» y cómo resolver los conflictos frecuentes (MD de estado, archivos generados de la bóveda).

## Registro
<!-- Añade una línea al terminar: «Leído y memoria actualizada — Catalina — AAAA-MM-DD» -->
