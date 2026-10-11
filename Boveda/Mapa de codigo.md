# Mapa de código (ir directo, sin explorar)
Rutas relativas a `Web/Intranet/`. Cada pantalla `X.aspx` trae su `X.aspx.cs`. Ver [[Arquitectura]] y [[Web services]].

| Flujo | Pantallas (`View/...`) | JS (`Js/`) | Web service (`App_Code/WebService/`) |
|---|---|---|---|
| Centro de Planificación 360 | `Mantenimiento/Planificacion.aspx` | `sigma-centro-planificacion.js`, `sigma-planificacion360.js` | `WsCentroPlanificacion`, `WsPlanificacion360` |
| Órdenes de trabajo | `Mantenimiento/Ordenes/` (Ordenes, OrdenTrabajo, OrdenTrabajos, OrdenTrabajoImprimir) | `sigma-mant-ordenes.js`, `sigma-orden.js` | `WsOrdenes` |
| Planes de mantenimiento | `Mantenimiento/Planes/` (PlanMantenimiento, PlanActividad(es), PlanActivo, PlanHito, CargaMasivaPlanes) | `sigma-mant-comun.js` | `WsPlanificacion360` |
| Programaciones / calendarios | `Mantenimiento/Programaciones/` | `sigma-programacion.js`, `sigma-programaciones.js`, `sigma-calendario.js` | `WsProgramacion` |
| Biblioteca de tareas | `Mantenimiento/Biblioteca/Biblioteca.aspx` | `sigma-mant-recursos.js` | `WsRecursos` |
| Avisos | `Mantenimiento/Avisos/Avisos.aspx` | `sigma-mant-avisos.js` | `WsAvisos` |
| Operación / ejecuciones | `Mantenimiento/Operacion/` | `sigma-mant-operacion.js`, `sigma-mant-ejecuciones.js` | `WsOperacion` |
| Procedimientos / Checklist | `Mantenimiento/Procedimientos/`, `Mantenimiento/Checklist/` | `sigma-mant-comun.js` | `WsRecursos` |
| Ficha de activo | `Activos/Ficha/ActivoFicha.aspx` (+ `ActivoForm.ascx` en `Activos/Activos/`) | `sigma-activo360.js` | `WsActivos`, `WsDetalle` |
| Medidores / lecturas | `Activos/Medidores/`, `Activos/Ficha/RegistrarLectura.aspx` | — | `WsActivos` |
| Repuestos / bodegas | `Inventario/Repuestos/`, `Inventario/Bodegas/` (BodegaMapa3D) | `sigma-repuesto-centro.js`, `sigma-bodega3d.js` | `WsRepuestoCentro`, `WsBodegaMapa` |
| Proveedores / permisos de trabajo | `Terceros/Proveedores/`, `Terceros/PermisosTrabajo/` | `sigma-permiso-trabajo.js` | — |
| Inicio y alertas | `Default.aspx`, `Master/Default.master` | `sigma-inicio.js`, `sigma-alertas.js` | `WsInicio`, `WsAlertas` |
| SIGMA AI | `SigmaAI/Centro.aspx`, `Experimentos.aspx` | `sigma-ai-centro.js`, `sigma-ai-planta3d.js` | `WsAiCentro`, `AiPlantas` |
| Carga masiva | `Comun/CargaDatos/` | `sigma-carga-datos.js`, `sigma-carga.js` | `WsCargaDatos` |
| Archivos / imágenes | `Comun/Archivos/VerArchivo.aspx` | — | — |
| Impresión | `Comun/Impresion/` | — | — |

## Piezas transversales
- **Seguridad / sesión:** `App_Code/SitioBase/Token.cs`, `Session.cs`, `SesionPersistente.cs`, `SuscripcionAcceso.cs` → [[Seguridad por datos]]
- **Rendimiento:** `SitioBase/Paralelo.cs`, `CacheSesion.cs`, `Medida.cs`, `AzureCupo.cs` → [[Rendimiento]]
- **Componentes UI:** `Js/sigma-combo.js` (SigmaCombo), `sigma-calendario.js` (SigmaCalendario), `sigma-dialog.js`, `sigma-popover.js`, `sigma-paginador.js`; estilos `Css/LookAndFeel/sigma-*.css` → [[Estandar UI]]
- **Controladores/modelos:** `App_Code/MVC/` (un `*Controller` por entidad)
- **Web.config / data.config:** raíz de `Web/Intranet` (cadenas con `Min Pool Size=20`)
- **API móvil:** `Solucion/SIGMA/API/` · **BD:** `BD/NNN_*.sql` → [[Base de datos y entornos]]

## Cómo encontrar algo que no está aquí
`grep -rn "NombreDelSP" BD/ Web/Intranet/App_Code` (SP) · `grep -rln "id_o_clase" Web/Intranet/Js` (JS). No abrir carpetas enteras.
