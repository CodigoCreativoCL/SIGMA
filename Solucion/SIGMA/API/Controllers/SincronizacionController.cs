using API.Utils;
using System;
using System.Collections.Generic;
using System.Data;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// La sábana de datos de la app (HU-150).
    ///
    /// POR QUE NO SE ARMA CON LOS ENDPOINTS QUE YA HAY
    ///   Se podría: la API tiene /repuestos, /bodegas, /existencias… Pero son
    ///   por recurso y paginados de a 50, así que el paquete completo son
    ///   decenas de viajes y la app queda sincronizando cinco minutos en la
    ///   puerta de la planta, con los datos del teléfono del técnico.
    ///
    /// UN BLOQUE POR LLAMADA, NO TODO DE UNA
    ///   Si el bloque 5 falla, los cuatro primeros ya están en el disco del
    ///   teléfono y la persona puede trabajar. Un único JSON gigante es todo
    ///   o nada, y en una planta "nada" es lo que pasa seguido.
    ///
    /// EL MANIFIESTO VA APARTE
    ///   `GET /sincronizacion` sin tipo devuelve cuántas filas tiene cada
    ///   bloque. Con eso la app dibuja una barra de progreso real en vez de
    ///   una animación indefinida, que es la diferencia entre "está
    ///   trabajando" y "se colgó".
    ///
    /// EL USUARIO Y EL CLIENTE SALEN DEL TOKEN
    ///   Nunca de un parámetro. Aceptar ?usuario=7 permitiría que cualquiera
    ///   con un token válido se bajara el paquete de trabajo de otro.
    /// </summary>
    [RoutePrefix("sincronizacion")]
    public class SincronizacionController : ApiBase
    {
        private const string SP = "API_SEL_APP_SABANA_DATOS";

        /// <summary>
        /// GET /sincronizacion — el manifiesto: qué bloques hay y cuántas
        /// filas trae cada uno.                                      HU-150
        ///
        /// Devuelve además `servidor_fecha_utc`, que la app guarda como
        /// `desde` de la próxima sincronización. **Nunca usa su propio reloj
        /// para eso**: un teléfono desajustado se saltaría registros para
        /// siempre.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Manifiesto()
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                DataSet ds = Datos.Conjunto(SP, Parametros(0, null, null));

                return Ok(new
                {
                    bloques = Datos.Filas(ds, 0),
                    servidor_fecha_utc = Datos.Escalar(ds, 1, "SERVIDOR_FECHA_UTC")
                });
            });
        }

        /// <summary>
        /// GET /sincronizacion/{tipo} — un bloque del paquete.        HU-150
        ///
        /// `?desde=` trae solo lo que cambió: las tablas tienen auditoría, y
        /// bajar tres mil activos en cada apertura de la app es gastar el
        /// plan de datos del técnico.
        ///
        /// Un bloque puede traer **varios resultados** —el 5 trae medidores y
        /// variables; el 6, repuestos, bodegas, ubicaciones y tipos de
        /// movimiento— porque van juntos o la app tiene que cruzarlos sola.
        /// </summary>
        [HttpGet]
        [Route("{tipo:int}")]
        public IHttpActionResult Bloque(int tipo, DateTime? desde = null,
                                        int? instalacion = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                if (tipo < 1 || tipo > 8)
                    return Error(System.Net.HttpStatusCode.BadRequest,
                        "El bloque pedido no existe. Consulta GET /sincronizacion.");

                DataSet ds = Datos.Conjunto(SP, Parametros(tipo, desde, instalacion));

                List<List<Dictionary<string, object>>> resultados =
                    new List<List<Dictionary<string, object>>>();

                for (int i = 0; i < ds.Tables.Count; i++)
                    resultados.Add(Datos.Filas(ds, i));

                return Ok(new
                {
                    tipo = tipo,
                    desde = desde,
                    servidor_fecha_utc = DateTime.UtcNow,
                    resultados = resultados
                });
            });
        }

        private static Dictionary<string, object> Parametros(int tipo, DateTime? desde,
                                                             int? instalacion)
        {
            return new Dictionary<string, object>
            {
                { "@USUARIO", SesionApi.UsuarioId() },
                { "@CLIENTE", SesionApi.ClienteId() },
                { "@TIPO", tipo },
                { "@DESDE", desde },
                { "@INSTALACION", instalacion }
            };
        }
    }
}
