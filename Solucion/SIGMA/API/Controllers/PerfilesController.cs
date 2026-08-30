using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Perfiles y sus permisos (HU-015).
    ///
    /// UN PERFIL ES UN CONJUNTO DE PERMISOS CON NOMBRE
    ///   Los seis perfiles base salen de los documentos, no se inventaron:
    ///   Administrador del Cliente, Jefe de Mantenimiento, Planificador,
    ///   Supervisor, Técnico y Bodeguero.
    ///
    /// per_solo_ejecucion NO ES UN PERMISO MAS
    ///   Es la marca del Técnico: puede ejecutar una orden pero no cerrarla.
    ///   Se expone en el DTO porque cambia lo que la app puede ofrecer, y
    ///   quien administre perfiles tiene que poder verla.
    ///
    /// LOS SPs SE LLAMAN EN PLURAL
    ///   SEL_PERFILES y DEL_PERFILES, no SEL_PERFIL. Es una inconsistencia
    ///   heredada de la base: INS_ y UPD_ están en singular. Se respeta el
    ///   nombre real en vez de "corregirlo", que rompería la web.
    /// </summary>
    [RoutePrefix("perfiles")]
    public class PerfilesController : ApiBase
    {
        /// <summary>GET /perfiles — listado.                        HU-015</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, bool? habilitado = null,
                                        int? tipo = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<PerfilDto> todo = Datos.Listar<PerfilDto>("SEL_PERFILES",
                    new Dictionary<string, object>
                    {
                        { "@FILTRO", p.filtro },
                        { "@HABILITADO", habilitado },
                        { "@TIPO", tipo },
                        { "@CLIENTE", SesionApi.ClienteId() > 0 ? (object)SesionApi.ClienteId() : null }
                    });

                return Ok(Paginado<PerfilDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /perfiles/{id} — detalle.                   HU-015</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                List<PerfilDto> r = Datos.Listar<PerfilDto>("SEL_PERFILES",
                    new Dictionary<string, object> { { "@ID", id } });

                if (r == null || r.Count == 0) return NoEncontrado("El perfil");

                return Ok(r[0]);
            });
        }

        /// <summary>POST /perfiles — alta.                          HU-015</summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(PerfilAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCuerpo(dto);
                ExigirTexto(dto.nombre, "nombre");

                int id = Datos.Ejecutar("INS_PERFIL",
                    new Dictionary<string, object>
                    {
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@TIPO", dto.tipo > 0 ? (object)dto.tipo : null },
                        { "@CLIENTE", SesionApi.ClienteId() > 0 ? (object)SesionApi.ClienteId() : null },
                        { "@SOLO_EJECUCION", dto.solo_ejecucion },
                        { "@HABILITADO", dto.habilitado },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>PUT /perfiles/{id} — edición.                   HU-015</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, PerfilAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCuerpo(dto);
                ExigirTexto(dto.nombre, "nombre");

                Datos.Ejecutar("UPD_PERFIL",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@TIPO", dto.tipo > 0 ? (object)dto.tipo : null },
                        { "@CLIENTE", SesionApi.ClienteId() > 0 ? (object)SesionApi.ClienteId() : null },
                        { "@SOLO_EJECUCION", dto.solo_ejecucion },
                        { "@HABILITADO", dto.habilitado },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                /* Cambiar un perfil cambia los permisos de todos los que lo
                   tienen. La caché de un minuto haría que ese cambio no se
                   viera de inmediato para quien esté conectado; acá no se
                   puede botar la de otros usuarios, así que se acepta el
                   minuto y queda dicho: es el precio de la caché, y es el
                   motivo de que dure un minuto y no una hora. */

                return Ok(new { id = id });
            });
        }

        /// <summary>DELETE /perfiles/{id} — baja.                   HU-015</summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                Datos.Ejecutar("DEL_PERFILES",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id, mensaje = "Perfil dado de baja." });
            });
        }
    }
}
