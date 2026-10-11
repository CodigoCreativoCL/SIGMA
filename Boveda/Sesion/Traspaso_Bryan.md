# Traspaso de Bryan Chávez — 11-10-2026 (para que Emilio y Catalina no tengan conflictos)
Rama: `BryanChavez` (= `master` al momento de escribir, commit `13273f18`). Todo lo de abajo ya está en `master`.

## 1. Qué hizo Bryan (ya integrado)
- **Mantenimiento:** HU-117 (servicios contratados en OT), HU-125 (imprimir OT), «Quién la ejecuta» en Nueva OT, ficha de OT v8, calendarios por medidor editables, plan anual de sopladores Hamburgo por horómetro (cargas en `BD/Carga masiva/`).
- **Evidencias/galería:** HU-142 pasos 1–4 (BD 433–436, `GET /api/archivo-vinculos`).
- **Rendimiento:** `Paralelo`, `CacheSesion`, `Medida` (Server-Timing), `Min Pool Size=20`, ETag/304 en `VerArchivo`; inicio 4,7→1,2 s, ficha de activo ~17→~3,7 s.
- **Orden del repo y cerebro compartido:** bóveda, skills, Docker, Diseño, BD por contexto (ver `Boveda/Sesion/LEEME.md`).

## 2. Archivos «calientes» (si los tocas, avisa antes o haz merge de master primero)
`App_Code/WebService/WsOrdenes.cs`, `Js/sigma-mant-ordenes.js`, `Js/sigma-mant-recursos.js`, `Js/sigma-centro-planificacion.js`, `Master/Default.master(.cs)`, `View/Activos/Ficha/ActivoFicha.aspx.cs`, `App_Code/SitioBase/Token.cs`, `Web.config`, `MD/SIGMA_ESTADO_DESARROLLO.md`. Bryan sigue en Mantenimiento/OT/Activos; Terceros (Proveedores, Permisos de trabajo) es de Emilio.

## 3. Archivos que dan conflicto siempre y cómo resolverlos
- **`Boveda/Estado automatico.md` y `Boveda/Base de datos/*.md`** son **generados**: ante conflicto, toma cualquier lado y corre `python -I Dev/actualizar_boveda.py`; nunca los edites a mano.
- **`MD/SIGMA_ESTADO_DESARROLLO.md`** (bitácora §9): conserva ambos lados; añade tu línea al final de la tabla con tu fecha.
- Marcadores `<<<<<<<` históricos dentro del MD: no son conflictos nuevos; ancla tus ediciones por línea.
- CRLF/BOM: usa `Dev/bom.py` en archivos de texto nuevos o editados; los avisos «LF will be replaced by CRLF» de git son normales.

## 4. Numeración y estado de la base
- Migraciones hasta la **438**; siguiente libre → `python -I Dev/siguiente_migracion.py` (revisa todas las ramas).
- **En producción faltan** las migraciones 429–438, `Min Pool Size=20` e `IdFirma`; la publicación la hace Bryan (Web Deploy). No apliques migraciones en producción por tu cuenta.
- `data.config` y `azure.config` no se versionan ni se comparten por chat.

## 5. Acuerdos de trabajo
- Tu rama personal + `git fetch && git merge origin/master` cada día; `master` solo avanza por fast-forward desde una rama ya integrada (avisa a Bryan antes de subir a master).
- Una persona hace la historia completa (código, pruebas, validación). Pruebas con empresa **Hamburgo**.
- Rama `PRODUCCION` (22 commits sin integrar): no la toques sin hablar con Bryan.

## Registro
<!-- Quien lea esto añade: «Leído — <nombre> — AAAA-MM-DD» -->
