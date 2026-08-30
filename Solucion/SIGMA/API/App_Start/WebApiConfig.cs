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
            config.MessageHandlers.Add(new WebApiCustomMessageHandler());

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
