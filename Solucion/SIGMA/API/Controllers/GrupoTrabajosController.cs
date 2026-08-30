using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Grupos de trabajo, o cuadrillas (HU-016).
    ///
    /// UN SOLO LIDER VIGENTE. Lo garantiza el SP, no esta capa: es una
    /// regla sobre las filas de integrantes y comprobarla acá exigiría
    /// leerlas todas, y aun así dos peticiones simultáneas podrían dejar
    /// dos líderes. Dentro de la transacción del SP eso no puede pasar.
    /// </summary>
    [RoutePrefix("grupo-trabajos")]
    public class GrupoTrabajosController : ApiBase
    {
        /// <summary>GET /grupo-trabajos — listado.                  HU-016</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? instalacion = null,
                                        int? especialidad = null, bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<GrupoTrabajoDto> todo = Datos.Listar<GrupoTrabajoDto>("SEL_GRUPO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CLIENTE_INSTALACION", instalacion },
                        { "@ESPECIALIDAD", especialidad },
                        { "@HABILITADO", habilitado },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<GrupoTrabajoDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /grupo-trabajos/{id} — detalle.             HU-016</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                List<GrupoTrabajoDto> r = Datos.Listar<GrupoTrabajoDto>("SEL_GRUPO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El grupo de trabajo");

                return Ok(r[0]);
            });
        }

        /// <summary>POST /grupo-trabajos — alta.                    HU-016</summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(GrupoTrabajoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.codigo, "codigo");
                ExigirTexto(dto.nombre, "nombre");

                int id = Datos.Ejecutar("INS_GRUPO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CLIENTE_INSTALACION", dto.cliente_instalacion },
                        { "@CODIGO", dto.codigo.Trim() },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@ESPECIALIDAD", dto.especialidad },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// PUT /grupo-trabajos/{id} — edición.                      HU-016
        ///
        /// quita_planta: un grupo puede ser transversal a todas las plantas
        /// del cliente. Sin la bandera no habría forma de sacarle la planta
        /// a uno que ya la tiene, porque el SP conserva con ISNULL lo que no
        /// viene.
        /// </summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, GrupoTrabajoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.codigo, "codigo");
                ExigirTexto(dto.nombre, "nombre");

                Datos.Ejecutar("UPD_GRUPO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE_INSTALACION", dto.cliente_instalacion },
                        { "@CODIGO", dto.codigo.Trim() },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@ESPECIALIDAD", dto.especialidad },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@HABILITADO", dto.habilitado },
                        { "@QUITA_PLANTA", dto.quita_planta },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id });
            });
        }

        /// <summary>
        /// DELETE /grupo-trabajos/{id} — baja lógica.               HU-016
        ///
        /// NO HAY DEL_GRUPO_TRABAJO en la base, y no hace falta: la baja de
        /// un grupo es dejarlo deshabilitado, y eso ya lo hace el UPD_. Un
        /// grupo con historial de órdenes no se borra.
        /// </summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                List<GrupoTrabajoDto> r = Datos.Listar<GrupoTrabajoDto>("SEL_GRUPO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El grupo de trabajo");

                GrupoTrabajoDto g = r[0];

                /* Se reenvían los campos que el UPD_ no conserva por sí
                   solo. Mandarlos nulos sería borrarlos de paso, y dar de
                   baja un grupo no debería vaciarle el nombre. */
                Datos.Ejecutar("UPD_GRUPO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE_INSTALACION", g.gtr_cliente_instalacion },
                        { "@CODIGO", g.gtr_codigo },
                        { "@NOMBRE", g.gtr_nombre },
                        { "@ESPECIALIDAD", g.gtr_especialidad },
                        { "@DESCRIPCION", g.gtr_descripcion },
                        { "@HABILITADO", false },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id, mensaje = "Grupo de trabajo deshabilitado." });
            });
        }
    }
}
