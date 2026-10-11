# Traspaso para Emilio Fuentes — 11-10-2026
Rama: `EmilioFuentes`. Tu trabajo (Terceros en una vista con pestañas + scroll del sidebar) **ya está integrado en `master`** (commit `f39504f3`).

## 1. Qué hacer en tu rama (en este orden)
1. `git fetch && git merge origin/master` — ya no habrá conflictos con tu trabajo; si el MD de estado o la bóveda chocan, conserva ambos lados.
2. Tus migraciones se **renumeraron**: `429_MENU_TERCEROS_PROVEEDORES_UNA_VISTA.sql` → `437_...` y `430_MENU_TERCEROS_PERMISOS_UNA_VISTA.sql` → `438_...` (429 y 430 ya estaban usados por calendarios de medidor y HU-117). Si ya las aplicaste en la base, **no las repitas** (son menús, mismo contenido).
3. Siguiente número libre: `python -I Dev/siguiente_migracion.py` (mira master y todas las ramas). Úsalo antes de crear cada migración.
4. Abre `Boveda/` en Obsidian (opcional) y lee `Boveda/00 Inicio.md`.

## 2. Qué cambió en el repo (para no buscar donde ya no está)
- `PATRONES/ASP` → `Boveda/Patrones/`. `ENTRENAMIENTO`, `SIGMA-Pautas-360`, `INFRAESTRUCTURA`, `docs/` y `Fase 2/Diseno/capturas` ya no existen.
- Docker → `Docker/` (`cd Docker && docker compose up -d --build`).
- Diseño → `Fase 2/Diseno/{1_Esquema_BD,2_Diseno_Web,3_Diseno_App}`; prompts y referencias visuales de cada rediseño en `2_Diseno_Web/Redisenos/<módulo>/`.
- BD: las migraciones siguen en `BD/NNN_*.sql`; el índice por tema está en `Boveda/Base de datos/Indice de base de datos.md`. Semillas → `BD/Semillas/`, respaldos → `BD/Respaldos/`.
- Herramientas compartidas en `Dev/`: `bom.py`, `sql_aplicar.py`, `siguiente_migracion.py`, `actualizar_boveda.py`.
- `C:\Capstone` debe contener solo `SIGMA`; borradores y evidencia personal van fuera (p. ej. `C:\Capstone_Archivo`).

## 3. Memoria local de Claude a guardar (créala en tu memoria; no la copies al repo)
- **cerebro-boveda-compartida** (project): el conocimiento de SIGMA vive en `Boveda/` del repo; al iniciar usar la skill `sigma-cerebro` (leer `Boveda/00 Inicio.md` y solo la nota que aplique); al terminar un bloque, `sigma-cerrar-bloque`. El MD de estado (1300+ líneas) no se lee entero: grep puntual. Objetivo: ahorrar tokens y trabajar con el mismo estándar los tres.
- **reglas-equipo-sigma** (feedback): resumen de `Boveda/Reglas del equipo.md` (solo drawer sin modales, SigmaCalendario, perfiles dinámicos sin «supervisor/técnico», pruebas con Hamburgo, historia completa por persona, validaciones PO = Terminadas, retro con feedback del cliente, app móvil = Sprint 6).
- **rutas-nuevas-repo** (reference): las rutas del punto 2 de este documento.
- Si tu memoria cita `PATRONES\ASP`, `C:\Capstone\MD\...` o `_scratch/bom.py`, corrígelas a `Boveda/Patrones`, `C:\Capstone\SIGMA\MD\...` y `Dev/bom.py`.

## Registro
<!-- Añade una línea al terminar: «Leído y memoria actualizada — Emilio — AAAA-MM-DD» -->
