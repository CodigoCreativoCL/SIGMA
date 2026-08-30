using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Los catálogos del sistema (HU-020).
    ///
    /// QUE ES UN CATALOGO ACA
    ///   Una de las 81 tablas de valores fijos del modelo: tipos de área,
    ///   niveles de especialidad, estados, periodicidades. La tabla
    ///   Catalogo es el REGISTRO de todas ellas, con su código, su módulo y
    ///   si el cliente puede agregarle valores propios.
    ///
    /// POR QUE UN SOLO ENDPOINT Y NO 81
    ///   Porque son 81 tablas de dos columnas. Un controller por cada una
    ///   serían 81 archivos idénticos, y el día que se agregue el catálogo
    ///   82 habría que escribir el 82. Con el registro, agregar un catálogo
    ///   es una fila, no un despliegue.
    /// </summary>
    [RoutePrefix("catalogos")]
    public class CatalogosController : ApiBase
    {
        /// <summary>
        /// GET /catalogos — el registro de catálogos, con caché corta.
        ///                                                          HU-020
        ///
        /// Se cachea porque cambia cuando alguien agrega un catálogo, o sea
        /// casi nunca, y la app lo pide para llenar combos en cada
        /// formulario que abre.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, string modulo = null,
                                        bool? ampliable = null, bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                string extra = "m=" + (modulo ?? "") + ";a=" + (ampliable.HasValue ? ampliable.ToString() : "") +
                               ";h=" + (habilitado.HasValue ? habilitado.ToString() : "") +
                               ";f=" + (p.filtro ?? "");

                List<CatalogoDto> todo = CacheCorta.Obtener(
                    CacheCorta.Clave("catalogos", SesionApi.UsuarioId(), SesionApi.ClienteId(), extra), () =>
                    Datos.Listar<CatalogoDto>("SEL_CATALOGO",
                        new Dictionary<string, object>
                        {
                            { "@MODULO", modulo },
                            { "@AMPLIABLE", ampliable },
                            { "@HABILITADO", habilitado },
                            { "@FILTRO", p.filtro }
                        }));

                return Ok(Paginado<CatalogoDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /catalogos/{codigo}/valores — los valores.  HU-020</summary>
        [HttpGet]
        [Route("{codigo}/valores")]
        public IHttpActionResult Valores(string codigo, int pagina = 1,
                                         int tamano = Pagina.TAMANO_DEFECTO,
                                         string filtro = null, bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirTexto(codigo, "codigo");

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                /* El cliente va SIEMPRE: los catálogos ampliables devuelven
                   los valores del sistema más los propios de ese cliente.
                   Sin él, un cliente vería los valores que otro agregó. */
                List<CatalogoValorDto> todo = CacheCorta.Obtener(
                    CacheCorta.Clave("catvalores", SesionApi.UsuarioId(), SesionApi.ClienteId(),
                                     codigo + ";f=" + (p.filtro ?? "")), () =>
                    Datos.Listar<CatalogoValorDto>("SEL_CATALOGO_VALOR",
                        new Dictionary<string, object>
                        {
                            { "@CODIGO", codigo.Trim() },
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@HABILITADO", habilitado },
                            { "@FILTRO", p.filtro }
                        }));

                return Ok(Paginado<CatalogoValorDto>.Armar(todo, p));
            });
        }
    }


    /// <summary>
    /// Valores propios de un catálogo ampliable (HU-021).
    ///
    /// SOLO 16 DE LOS 81 SON AMPLIABLES. El SP lo comprueba: intentar
    /// agregarle un valor a uno que no lo es se rechaza, y está bien que
    /// así sea. Un catálogo cerrado lo está porque su contenido es parte
    /// del modelo —los estados de una orden de trabajo, por ejemplo— y
    /// dejar que un cliente le agregue valores rompería la lógica que los
    /// interpreta.
    /// </summary>
    [RoutePrefix("catalogo-valores")]
    public class CatalogoValoresController : ApiBase
    {
        /// <summary>GET /catalogo-valores — listado.                HU-021</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int catalogo = 0, string codigo = null,
                                        int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                if (catalogo <= 0 && string.IsNullOrEmpty(codigo))
                    throw new ArgumentException("Indique el catálogo, por id o por código.");

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<CatalogoValorDto> todo = Datos.Listar<CatalogoValorDto>("SEL_CATALOGO_VALOR",
                    new Dictionary<string, object>
                    {
                        { "@CATALOGO", catalogo > 0 ? (object)catalogo : null },
                        { "@CODIGO", codigo },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@HABILITADO", habilitado },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<CatalogoValorDto>.Armar(todo, p));
            });
        }

        /// <summary>
        /// GET /catalogo-valores/{id} — detalle.                    HU-021
        ///
        /// El id de un valor es único DENTRO de su catálogo, no en toda la
        /// base: los valores viven en 81 tablas distintas. Por eso hay que
        /// decir de qué catálogo se trata.
        /// </summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id, int catalogo = 0, string codigo = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                if (catalogo <= 0 && string.IsNullOrEmpty(codigo))
                    throw new ArgumentException(
                        "Indique el catálogo (?catalogo= o ?codigo=): el id de un valor " +
                        "solo es único dentro de su catálogo.");

                List<CatalogoValorDto> r = Datos.Listar<CatalogoValorDto>("SEL_CATALOGO_VALOR",
                    new Dictionary<string, object>
                    {
                        { "@CATALOGO", catalogo > 0 ? (object)catalogo : null },
                        { "@CODIGO", codigo },
                        { "@VALOR_ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El valor del catálogo");

                return Ok(r[0]);
            });
        }

        /// <summary>POST /catalogo-valores — alta.                  HU-021</summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(CatalogoValorAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.nombre, "nombre");

                if (dto.catalogo <= 0)
                    throw new ArgumentException("Indique el catálogo al que se agrega el valor.");

                int id = Datos.Ejecutar("INS_CATALOGO_VALOR",
                    new Dictionary<string, object>
                    {
                        { "@CATALOGO", dto.catalogo },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CODIGO", dto.codigo },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@ORDEN", dto.orden },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                CacheCorta.Botar("catvalores", SesionApi.UsuarioId(), SesionApi.ClienteId());

                return Creado(id);
            });
        }

        /// <summary>PUT /catalogo-valores/{id} — edición.           HU-021</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, CatalogoValorAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.nombre, "nombre");

                if (dto.catalogo <= 0)
                    throw new ArgumentException("Indique el catálogo del valor.");

                Datos.Ejecutar("UPD_CATALOGO_VALOR",
                    new Dictionary<string, object>
                    {
                        { "@CATALOGO", dto.catalogo },
                        { "@VALOR_ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@ORDEN", dto.orden },
                        { "@HABILITADO", dto.habilitado },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                CacheCorta.Botar("catvalores", SesionApi.UsuarioId(), SesionApi.ClienteId());

                return Ok(new { id = id });
            });
        }

        /// <summary>
        /// DELETE /catalogo-valores/{id} — baja lógica.             HU-021
        ///
        /// No hay DEL_: la baja es el UPD_ con habilitado en false, que es
        /// lo correcto. Un valor de catálogo ya usado por registros
        /// existentes no se puede borrar sin dejarlos apuntando a nada;
        /// deshabilitado deja de ofrecerse en los combos y los registros
        /// viejos siguen mostrando lo que decían.
        /// </summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id, int catalogo = 0)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                if (catalogo <= 0)
                    throw new ArgumentException("Indique el catálogo (?catalogo=).");

                Datos.Ejecutar("UPD_CATALOGO_VALOR",
                    new Dictionary<string, object>
                    {
                        { "@CATALOGO", catalogo },
                        { "@VALOR_ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@HABILITADO", false },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                CacheCorta.Botar("catvalores", SesionApi.UsuarioId(), SesionApi.ClienteId());

                return Ok(new { id = id, mensaje = "Valor deshabilitado." });
            });
        }
    }
}
