using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// La existencia de los repuestos (HU-056).
    ///
    /// LA CONSULTA MAS LLAMADA DEL MODULO
    ///   "Cuantas hay y donde estan", desde el pasillo y antes de bajar a
    ///   buscar la pieza. El criterio de la historia lo dice sin rodeos:
    ///   para no detener un trabajo por ir a buscar algo que no esta.
    ///
    /// SIN CONEXION (criterio 2)
    ///   La app guarda la ultima respuesta y la muestra marcada como
    ///   posiblemente desactualizada. Eso se resuelve en Flutter, no aca;
    ///   lo unico que la API aporta es
    ///   isa_fecha_ultimo_movimiento, que es con lo que la app puede decir
    ///   DE CUANDO es el dato que esta mostrando. Un "puede estar
    ///   desactualizado" sin fecha no le sirve a nadie.
    /// </summary>
    [RoutePrefix("existencias")]
    public class ExistenciasController : ApiBase
    {
        /// <summary>
        /// GET /existencias — existencia por repuesto y bodega.     HU-056
        ///
        /// ?alerta=true devuelve solo lo que esta fuera de sus umbrales, que
        /// es la vista con la que el bodeguero empieza el dia.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? repuesto = null,
                                        int? bodega = null, int? instalacion = null,
                                        bool alerta = false)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER EXISTENCIAS");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<InventarioSaldoDto> todo = Datos.Listar<InventarioSaldoDto>("SEL_INVENTARIO_SALDO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@REPUESTO", repuesto },
                        { "@BODEGA", bodega },
                        { "@INSTALACION", instalacion },
                        { "@FILTRO", p.filtro },
                        { "@SOLO_ALERTA", alerta ? 1 : 0 }
                    });

                return Ok(Paginado<InventarioSaldoDto>.Armar(todo, p));
            });
        }

        /// <summary>
        /// GET /existencias/repuesto/{id} — todas las bodegas donde esta.
        ///                                                          HU-056
        ///
        /// Es la pantalla de la ficha: un repuesto, sus bodegas, su
        /// ubicacion en cada una y sus umbrales. Sin paginar a proposito —
        /// un repuesto no vive en doscientas bodegas, y paginar esto
        /// obligaria a la app a juntar paginas para mostrar una sola ficha.
        /// </summary>
        [HttpGet]
        [Route("repuesto/{id:int}")]
        public IHttpActionResult PorRepuesto(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER EXISTENCIAS");
                ExigirCliente();

                List<InventarioSaldoDto> r = Datos.Listar<InventarioSaldoDto>("SEL_INVENTARIO_SALDO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@REPUESTO", id },
                        { "@BODEGA", null },
                        { "@INSTALACION", null },
                        { "@FILTRO", null },
                        { "@SOLO_ALERTA", 0 }
                    });

                /* Lista vacia y no 404: que un repuesto no tenga existencia
                   en ninguna bodega es una respuesta valida —significa que
                   no queda ninguno—, no que el repuesto no exista. */
                return Ok(r ?? new List<InventarioSaldoDto>());
            });
        }
    }
}
