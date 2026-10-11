---
name: sigma-cerrar-bloque
description: Usar al terminar un bloque de trabajo en SIGMA, antes del commit/push. Sincroniza el estado con el equipo actualizando la bóveda y el MD de estado.
---

# Cerrar un bloque de SIGMA

1. Ejecutar `python -I Dev/actualizar_boveda.py` (regenera `Boveda/Estado automatico.md`, sin costo de tokens).
2. Si el bloque cambió una regla, patrón, trampa o decisión: editar SOLO la nota correspondiente de `Boveda/` (1–3 líneas, con enlace `[[nota]]`). Una idea por nota; no duplicar lo que ya está en el código.
3. Añadir una línea a la bitácora de `MD/SIGMA_ESTADO_DESARROLLO.md` §9 (anclar por línea; ojo con marcadores `<<<<<<<` históricos).
4. Compilar si se tocó C# (`MSYS_NO_PATHCONV=1` en Git Bash).
5. Commit (termina con la línea Co-Authored-By) y `git pull --rebase` + push a la rama propia; master avanza por fast-forward.
6. Avisar al equipo lo que deben traer (`git pull`) y migraciones SQL nuevas que deben aplicar.
