# Rendimiento (octubre 2026)
BD remota ≈ 215–250 ms por consulta → reducir viajes.
- `SitioBase.Paralelo.Pedir/Todos`: solo lecturas independientes; los permisos se resuelven en el hilo de la petición.
- `SitioBase.CacheSesion.Sesion/Global` sobre `HttpRuntime.Cache` (no Session). Las escrituras llaman `BorrarSesion(clave)`.
- `SitioBase.Medida` → cabecera Server-Timing.
- `Min Pool Size=20` en las cadenas de conexión (Web y API); ThreadPool min 64; ETag/304 en imágenes (VerArchivo).
- Resultados: inicio 4,7→1,2 s; ficha de activo ~17→~3,7 s; master 2,1→0,45 s.

Ver [[Base de datos y entornos]].
