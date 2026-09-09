using API.MVC.Model;
using API.Utils;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Los componentes de un activo — vistas 8.1 a 8.4.
    ///
    /// SOLO LECTURA
    ///   Crear y editar componentes es trabajo administrativo de la web
    ///   (CREAR EDITAR COMPONENTES). Lo que la app necesita es LEERLOS:
    ///   antes de intervenir un equipo hay que saber que piezas tiene, en
    ///   que estado y que les paso antes.
    ///
    ///   El alta desde terreno existe pero es otra cosa —CREAR COMPONENTE
    ///   TERRENO, del flujo de descubrimiento— y va por CapturaTerreno.
    ///
    /// POR QUE NO HAY UN SP NUEVO PARA EL LISTADO
    ///   SEL_ACTIVO_COMPONENTE ya recibe @ACTIVO y @FILTRO y ya resuelve el
    ///   activo padre, el tipo, el estado, la criticidad y la posicion. Es
    ///   el mismo que usa la web. Escribir otro para la app seria mantener
    ///   dos consultas que dicen lo mismo hasta que una se quede atras.
    ///
    /// EL CLIENTE SALE DEL TOKEN, NO DE LA URL
    ///   Los SP reciben SesionApi.ClienteId() y filtran por el. Un id de
    ///   otra empresa devuelve 404, no la ficha ajena.
    /// </summary>
    [RoutePrefix("componentes")]
    public class ComponentesController : ApiBase
    {
        /// <summary>
        /// GET /componentes?activo={id} — el listado.               Vista 8.1
        ///
        /// `activo` es opcional a proposito: 8.1 pide llegar «desde el activo
        /// o desde busqueda global», y sin el parametro esto es la busqueda
        /// global sobre todos los componentes del cliente.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int? activo = null, string filtro = null,
                                        int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER COMPONENTES");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<ComponenteDto> todo = Datos.Listar<ComponenteDto>("SEL_ACTIVO_COMPONENTE",
                    new Dictionary<string, object>
                    {
                        { "@ID", null },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ACTIVO", activo.HasValue ? (object)activo.Value : null },
                        { "@HABILITADO", true },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<ComponenteDto>.Armar(todo, p));
            });
        }

        /// <summary>
        /// GET /componentes/{id} — la ficha.                        Vista 8.2
        ///
        /// Trae ademas las fotos y los medidores, que es lo que la vista pide
        /// como «horas o ciclos de uso». Van en la misma respuesta y no en
        /// tres llamadas: la ficha se abre en terreno, y tres viajes con
        /// señal de planta son tres oportunidades de que se caiga uno.
        /// </summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER COMPONENTES");
                ExigirCliente();

                List<ComponenteDto> r = Datos.Listar<ComponenteDto>("SEL_ACTIVO_COMPONENTE",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ACTIVO", null },
                        { "@HABILITADO", null },
                        { "@FILTRO", null }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El componente");

                ComponenteDto c = r[0];
                c.FOTOS = new List<string>();

                List<GaleriaFotoDto> fotos = Datos.Listar<GaleriaFotoDto>("API_SEL_COMPONENTE_FOTO",
                    new Dictionary<string, object>
                    {
                        { "@COMPONENTE", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (fotos != null)
                {
                    for (int i = 0; i < fotos.Count; i++)
                    {
                        if (string.IsNullOrEmpty(fotos[i].ARC_RUTA)) continue;
                        c.FOTOS.Add(fotos[i].ARC_RUTA);

                        /* El SP ya pone la portada primera. Si hay fotos pero
                           ninguna marcada, la primera hace de portada: mejor
                           una foto de la pieza que ninguna. */
                        if (c.FOTO_RUTA == null) c.FOTO_RUTA = fotos[i].ARC_RUTA;
                    }
                }

                /* LOS MEDIDORES SE FILTRAN ACA Y NO EN EL SP

                   SEL_ACTIVO_MEDIDOR filtra por activo, no por componente,
                   y lo usan las grillas de la web: agregarle un parametro
                   obligaria a tocar un SP compartido para un caso de la app.
                   Devuelve AME_ACTIVO_COMPONENTE, asi que quedarse con los
                   del componente es elegir filas, no reimplementar una regla. */
                List<MedidorDto> medidores = Datos.Listar<MedidorDto>("SEL_ACTIVO_MEDIDOR",
                    new Dictionary<string, object>
                    {
                        { "@ID", null },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ACTIVO", c.ACO_ACTIVO },
                        { "@HABILITADO", true },
                        { "@FILTRO", null }
                    });

                c.MEDIDORES = new List<MedidorDto>();

                if (medidores != null)
                {
                    for (int i = 0; i < medidores.Count; i++)
                    {
                        if (medidores[i].AME_ACTIVO_COMPONENTE == id)
                            c.MEDIDORES.Add(medidores[i]);
                    }
                }

                return Ok(c);
            });
        }

        /// <summary>
        /// GET /componentes/{id}/ficha — la linea de tiempo.        Vista 8.3
        ///
        /// Instalacion, lecturas, fallas, OT, repuestos, sustituciones y
        /// bitacora, en una sola lista y lo mas reciente primero. Los cambios
        /// de estado NO estan porque el componente no guarda historial de
        /// estado: eso es base que falta, no pantalla, y esta anotado.
        /// </summary>
        [HttpGet]
        [Route("{id:int}/ficha")]
        public IHttpActionResult Ficha(int id, string tipo = null,
                                       int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER COMPONENTES");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano };

                string extra = "id=" + id + ";t=" + (tipo ?? "");

                List<ComponenteFichaEventoDto> todo = CacheCorta.Obtener(
                    CacheCorta.Clave("compficha", SesionApi.UsuarioId(), SesionApi.ClienteId(), extra), () =>
                    {
                        /* @TOTAL es parametro de SALIDA obligatorio: omitirlo
                           hace que SQL Server rechace la llamada entera. Por
                           eso ListarConTotal y no Listar. Mismo caso que
                           SEL_ACTIVO_FICHA. */
                        int totalSql;
                        return Datos.ListarConTotal<ComponenteFichaEventoDto>("API_SEL_ACTIVO_COMPONENTE_FICHA",
                            new Dictionary<string, object>
                            {
                                { "@COMPONENTE", id },
                                { "@CLIENTE", SesionApi.ClienteId() },
                                { "@TIPO_EVENTO", tipo },
                                { "@PAGINA", 1 },
                                { "@TAMANO", 200 }
                            }, out totalSql);
                    });

                return Ok(Paginado<ComponenteFichaEventoDto>.Armar(todo, p));
            });
        }

        /// <summary>
        /// GET /componentes/{id}/galeria — las fotos con su ficha.  Vista 8.4
        ///
        /// Separado del detalle porque devuelve mas por foto —fecha, autor y
        /// observacion— y eso solo lo mira quien abre la galeria. Cargarlo
        /// siempre en la ficha seria bajar texto que casi nadie lee.
        /// </summary>
        [HttpGet]
        [Route("{id:int}/galeria")]
        public IHttpActionResult Galeria(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER COMPONENTES");
                ExigirCliente();

                List<GaleriaFotoDto> fotos = Datos.Listar<GaleriaFotoDto>("API_SEL_COMPONENTE_FOTO",
                    new Dictionary<string, object>
                    {
                        { "@COMPONENTE", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                return Ok(fotos ?? new List<GaleriaFotoDto>());
            });
        }
    }
}
