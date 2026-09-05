using Controllers;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Http;

namespace API
{
    public static class WebApiConfig
    {
        public static void Register(HttpConfiguration config)
        {
            // Configuración y servicios de Web API

            // Rutas de Web API
            config.MapHttpAttributeRoutes();

            //Api Token
            config.MessageHandlers.Add(new TokenValidationHandler());

            /* RETIRADO 04-09-2026: WebApiCustomMessageHandler.
               Venía de la plantilla y reemplazaba el CUERPO de 46 códigos de
               estado por la descripción canónica del código, en inglés. Es
               decir: se comía todo mensaje propio.

                 401 -> "Unauthorized indicates that the requested resource..."
                        en vez de "Correo o contraseña incorrectos."
                 201 -> se llevaba el { id } de toda creación
                 400/402/403/404/409 -> perdían la regla de negocio que el SP
                        comunica por RAISERROR y que ErrorSql traduce

               El 423 sobrevivía de casualidad, porque (HttpStatusCode)423 no
               está en el enum y el handler compara contra el enum. Eso explica
               por qué al probar HU-001 el 401 salía en inglés y el 423 no.

               No se conserva "por si acaso": cambiar un mensaje que dice qué
               pasó por uno que describe el código HTTP no aporta nada y rompe
               el contrato que la app necesita.
               El archivo queda en _RETIRADO/API/Utils/. */

            /* SIN el segmento "api/".
               La aplicacion esta publicada en http://localhost/SIGMA/Servicio/API,
               asi que la palabra API ya esta en la URL: dejar el prefijo aqui
               produciria .../API/api/clientes, con la palabra repetida.

               Los controllers usan RoutePrefix sin ese segmento —igual que el
               AuthController, que ya venia con [RoutePrefix("auth")]— y las
               rutas quedan .../SIGMA/Servicio/API/clientes.

               En el Sprint Backlog las tareas dicen "GET /api/clientes": eso
               nombra el recurso, no el segmento de la URL, y la ruta real es
               la de arriba. */
            config.Routes.MapHttpRoute(
                name: "DefaultApi",
                routeTemplate: "{controller}/{id}",
                defaults: new { id = RouteParameter.Optional }
            );
        }
    }
}
