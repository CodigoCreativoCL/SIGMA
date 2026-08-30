using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Permisos puntuales de una persona (HU-007, ANEXO D).
    ///
    /// LA EXCEPCION AL PERFIL
    ///   Un perfil da permisos a un grupo de gente. Esto se los da —o se
    ///   los quita— a UNA persona, y la excepción gana sobre el perfil.
    ///   Sirve para lo que en terreno siempre pasa: alguien que reemplaza
    ///   por dos semanas y necesita una facultad que su perfil no trae.
    ///
    /// SE OTORGA Y TAMBIEN SE REVOCA
    ///   cpm_otorgado en false NO es "sin permiso": es una NEGACION
    ///   explícita que le quita a esa persona algo que su perfil sí le da.
    ///   Son cosas distintas y por eso hay una columna en vez de borrar la
    ///   fila.
    ///
    /// EL AMBITO Y LA VIGENCIA
    ///   Un permiso puntual puede acotarse a una planta o a un área, y
    ///   puede tener fechas. Lo de la planta gana sobre lo global. Lo de
    ///   las fechas es lo que hace que un reemplazo se termine solo, sin
    ///   que nadie tenga que acordarse de revocarlo.
    /// </summary>
    [RoutePrefix("cliente-usuario-permisos")]
    public class ClienteUsuarioPermisosController : ApiBase
    {
        /// <summary>GET /cliente-usuario-permisos — listado.        HU-007</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? clienteUsuario = null,
                                        int? instalacion = null, bool soloVigentes = false,
                                        bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<ClienteUsuarioPermisoDto> todo = Datos.Listar<ClienteUsuarioPermisoDto>("SEL_CLIENTE_USUARIO_PERMISO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CLIENTE_USUARIO", clienteUsuario },
                        { "@CLIENTE_INSTALACION", instalacion },
                        { "@SOLO_VIGENTES", soloVigentes ? (object)true : null },
                        { "@HABILITADO", habilitado },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<ClienteUsuarioPermisoDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /cliente-usuario-permisos/{id} — detalle.   HU-007</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                List<ClienteUsuarioPermisoDto> r = Datos.Listar<ClienteUsuarioPermisoDto>("SEL_CLIENTE_USUARIO_PERMISO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El permiso puntual");

                return Ok(r[0]);
            });
        }

        /// <summary>POST /cliente-usuario-permisos — alta.          HU-007</summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(ClienteUsuarioPermisoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);

                if (dto.cliente_usuario <= 0)
                    throw new ArgumentException("Indique a qué persona se le otorga el permiso.");

                if (dto.permiso <= 0)
                    throw new ArgumentException("Indique el permiso.");

                if (dto.fecha_inicio.HasValue && dto.fecha_fin.HasValue &&
                    dto.fecha_fin.Value < dto.fecha_inicio.Value)
                    throw new ArgumentException("La fecha de término no puede ser anterior a la de inicio.");

                int id = Datos.Ejecutar("INS_CLIENTE_USUARIO_PERMISO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE_USUARIO", dto.cliente_usuario },
                        { "@PERMISO", dto.permiso },
                        { "@CLIENTE_INSTALACION", dto.cliente_instalacion },
                        { "@INSTALACION_AREA", dto.instalacion_area },
                        { "@OTORGADO", dto.otorgado },
                        { "@FECHA_INICIO", dto.fecha_inicio },
                        { "@FECHA_FIN", dto.fecha_fin },
                        { "@MOTIVO", dto.motivo },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>PUT /cliente-usuario-permisos/{id} — edición.   HU-007</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, ClienteUsuarioPermisoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);

                if (dto.fecha_inicio.HasValue && dto.fecha_fin.HasValue &&
                    dto.fecha_fin.Value < dto.fecha_inicio.Value)
                    throw new ArgumentException("La fecha de término no puede ser anterior a la de inicio.");

                Datos.Ejecutar("UPD_CLIENTE_USUARIO_PERMISO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@OTORGADO", dto.otorgado },
                        { "@FECHA_INICIO", dto.fecha_inicio },
                        { "@FECHA_FIN", dto.fecha_fin },
                        { "@MOTIVO", dto.motivo },
                        { "@HABILITADO", dto.habilitado },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id });
            });
        }

        /// <summary>
        /// DELETE /cliente-usuario-permisos/{id} — retirar.         HU-007
        ///
        /// Baja lógica por el UPD_: no hay DEL_ y no hace falta. Retirar la
        /// excepción devuelve a esa persona a lo que dice su perfil, que es
        /// exactamente lo que se quiere al terminar un reemplazo.
        /// </summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Datos.Ejecutar("UPD_CLIENTE_USUARIO_PERMISO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@HABILITADO", false },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id, mensaje = "Permiso puntual retirado. Vuelve a mandar el perfil." });
            });
        }
    }
}
