# Seguridad por datos
No existe `Paginas.cs`. `Token.ExigirPagina()` (lo llama el master) resuelve la URL contra `Menus.mnu_link`.
- `Token.PuedePagina()`, `Token.PuedeFuncion()` (Menu_Funcion), `Token.Puede(codigo)` (Permiso.prm_codigo).
- **Pantalla nueva = INSERT en `Menus`**. Sin fila → denegada. Menús nunca se borran: `mnu_visible = 0`.
- Exentas (`Token.EXENTAS`): default, login, recuperarclave, restablecerclave, seleccionarcliente, Comun/Procesamiento, privacidad.
- TokenValidationHandler valida **antes de enrutar**: un token vencido en el header rompe hasta endpoints anónimos (POST /sesion). Nada anónimo lleva Authorization.
- Perfiles dinámicos: nunca «supervisor»/«técnico» en UI o código; hablar de la facultad o acción.

Relacionado: [[Patrones y convenciones]].
