---
name: sigma-cerebro
description: Usar al INICIAR cualquier tarea de SIGMA (código, SQL, UI, git). Lee la bóveda Boveda/ en vez de explorar el repo, para gastar pocos tokens y trabajar con el mismo estándar que el resto del equipo.
---

# Cerebro de SIGMA (bóveda compartida por git)

1. `git pull` de la rama de trabajo (el cerebro y el estado llegan con los cambios de Bryan, Emilio y Catalina).
1b. Si existe `Boveda/Sesion/Traspaso_<tu nombre>.md` sin tu línea en «Registro», léelo primero y actualiza tu memoria local (`Boveda/Sesion/LEEME.md`).
2. Leer `Boveda/00 Inicio.md` y SOLO las notas que apliquen a la tarea (UI → `Estandar UI`; SQL/C# → `Patrones y convenciones`; pantallas nuevas → `Seguridad por datos`; lentitud → `Rendimiento`; estado actual → `Estado automatico`). No leer `MD/SIGMA_ESTADO_DESARROLLO.md` completo (1300+ líneas): buscar con grep la sección puntual.
3. Antes de escribir la primera línea, abrir el patrón de `Boveda/Patrones/` que corresponda y un archivo real del mismo tipo.
4. Si algo de la bóveda contradice el código, gana el código: corregir la nota.
5. Al terminar, aplicar la skill `sigma-cerrar-bloque`.

Prohibido: pedir o guardar claves/contraseñas en notas o chat.
