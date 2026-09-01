using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Escanear una etiqueta y ver qué hay en ese lugar.
    ///
    /// ESTA ES LA PANTALLA DE LA APP, NO DE LA WEB
    ///   El bodeguero está de pie frente al estante con el teléfono en la
    ///   mano: apunta la cámara al QR y la app pregunta acá. En la web la
    ///   misma función existe solo para teclear un código cuando la etiqueta
    ///   está rayada, porque un navegador de escritorio no tiene cámara útil.
    ///
    /// UN SOLO ENDPOINT PARA LOS TRES TIPOS
    ///   El QR trae UBI-17, BOD-9 o REP-24 y la app no tiene por qué saber
    ///   cuál de los tres le tocó: manda lo que leyó y recibe siempre la
    ///   misma forma —tipo, cabecera, líneas—. Tres endpoints obligarían a
    ///   la app a interpretar el token antes de preguntar, que es
    ///   exactamente la lógica que no debe estar duplicada en el teléfono.
    ///
    /// EL TOKEN VIENE EN CLARO, Y ES DELIBERADO
    ///   Una etiqueta pegada dura años; un cifrado depende de una clave que
    ///   algún día cambia, y ese día habría que reimprimir la bodega entera.
    ///   Lo que protege el dato es el permiso y el @CLIENTE de la sesión: un
    ///   token de otra empresa no devuelve nada.
    /// </summary>
    [RoutePrefix("escaneo")]
    public class EscaneoController : ApiBase
    {
        /// <summary>
        /// GET /escaneo?c=UBI-17 — qué hay en lo que se acaba de escanear.
        ///
        /// Acepta el token pelado y también la URL completa que trae el QR,
        /// porque un lector puede entregar cualquiera de las dos y hacer que
        /// la app las distinga sería pedirle que repita esta lógica.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Resolver(string c = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER EXISTENCIAS");
                ExigirCliente();

                string tipo;
                int id;

                if (!Interpretar(c, out tipo, out id))
                    return BadRequest("No se reconoce «" + (c ?? "") + "». " +
                                      "Escanee la etiqueta otra vez, o escriba el código " +
                                      "impreso, por ejemplo UBI-17.");

                string sp;
                string parametro;

                if (tipo == "UBI") { sp = "SEL_UBICACION_DESGLOSE"; parametro = "@UBICACION"; }
                else if (tipo == "BOD") { sp = "SEL_BODEGA_DESGLOSE"; parametro = "@BODEGA"; }
                else { sp = "SEL_REPUESTO_DESGLOSE"; parametro = "@REPUESTO"; }

                DesgloseCabeceraDto cabecera;
                List<DesgloseLineaDto> lineas;

                Datos.ListarDos<DesgloseCabeceraDto, DesgloseLineaDto>(sp,
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { parametro, id }
                    },
                    out cabecera, out lineas);

                /* Nulo significa que el id no es de este cliente, no que algo
                   fallara. Se contesta 404 con el motivo en castellano: la app
                   lo muestra tal cual y no tiene que inventar un mensaje. */
                if (cabecera == null)
                    return Content(System.Net.HttpStatusCode.NotFound,
                                   new { mensaje = "Esa etiqueta no corresponde a " +
                                                   Articulo(tipo) + " de su empresa." });

                return Ok(new EscaneoDto
                {
                    tipo = tipo,
                    id = id,
                    token = tipo + "-" + id,
                    cabecera = cabecera,
                    lineas = lineas
                });
            });
        }

        /// <summary>
        /// Saca el tipo y el id de lo leído.
        ///
        /// Acepta la URL completa —lo que devuelve la cámara nativa del
        /// teléfono al leer el QR— y el token pelado, que es lo que llega
        /// cuando alguien lo teclea porque la etiqueta está rayada.
        /// </summary>
        private bool Interpretar(string leido, out string tipo, out int id)
        {
            tipo = "";
            id = 0;

            if (string.IsNullOrEmpty(leido)) return false;

            string texto = leido.Trim();

            int corte = texto.LastIndexOf("c=", StringComparison.OrdinalIgnoreCase);
            if (corte >= 0) texto = texto.Substring(corte + 2);

            int fin = texto.IndexOfAny(new char[] { '&', '?', ' ', '\r', '\n' });
            if (fin >= 0) texto = texto.Substring(0, fin);

            texto = texto.Trim().ToUpper();

            int guion = texto.IndexOf('-');
            if (guion <= 0) return false;

            tipo = texto.Substring(0, guion);

            if (!int.TryParse(texto.Substring(guion + 1), out id) || id <= 0)
            {
                tipo = "";
                return false;
            }

            /* ACT no entra: un activo no es un lugar con existencia adentro, y
               su ficha la sirve el módulo de activos. Devolver acá una
               pantalla vacía sería peor que decir que no. */
            return (tipo == "UBI" || tipo == "BOD" || tipo == "REP");
        }

        private string Articulo(string tipo)
        {
            if (tipo == "UBI") return "ninguna ubicación";
            if (tipo == "BOD") return "ninguna bodega";
            return "ningún repuesto";
        }
    }
}
