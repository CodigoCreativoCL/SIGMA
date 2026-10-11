# Arquitectura
- **Intranet**: `Web/Intranet` — ASP.NET WebForms (Web Site Project) .NET 4.8. Vistas en `View/<Modulo>/<Pantalla>/`, JS en `Js/`, CSS en `Css/LookAndFeel/`, master en `Master/Default.master`.
- **Lógica**: `App_Code/MVC` (controllers/modelos), `App_Code/SitioBase` (Token, Paralelo, CacheSesion, Medida, AzureCupo), `App_Code/WebService` (ASMX `Ws*.cs`).
- **API móvil**: `Solucion/SIGMA/API` — Web API 2 + JWT (`/SIGMA/Servicio/API`). App Flutter en `App/` (entrega Sprint 6). Ver `MD/SIGMA_ESTADO_DESARROLLO_API.md`.
- **BD**: SQL Server, scripts numerados en `BD/` (SP-first). Cargas en `BD/Carga masiva/`.
- **Session** en StateServer: no guardar modelos no serializables (usar HttpRuntime.Cache vía [[Rendimiento]]).
- Config sensible: `Web/Intranet/data.config` y `azure.config` (nunca se piden claves por chat).

Ver [[Seguridad por datos]], [[Modulos/Indice de modulos]].
- **Docker**: `Docker/` (compose, Dockerfiles de Intranet y API, `.env.example`, README). Se ejecuta con `cd Docker && docker compose up -d --build`; el contexto es la raíz del repo. Hay que dockerizar web y app (requisito del cliente).
- Infra del servidor Hyper-V: `INFRAESTRUCTURA/`.
