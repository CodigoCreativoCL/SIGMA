using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Especialidades y certificaciones del personal (HU-017).
    ///
    /// LO QUE HACE UTIL A ESTE RECURSO NO ES EL CRUD
    ///   Es saber qué certificación vence pronto. Una certificación vencida
    ///   no es un dato administrativo: es alguien haciendo un trabajo para
    ///   el que ya no está acreditado. Por eso los filtros de vencidas y
    ///   por vencer viven en el SP y se exponen tal cual.
    /// </summary>
    [RoutePrefix("usuario-especialidades")]
    public class UsuarioEspecialidadesController : ApiBase
    {
        /// <summary>GET /usuario-especialidades — listado.          HU-017</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? usuario = null,
                                        int? especialidad = null, bool vencidas = false,
                                        bool porVencer = false, bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<UsuarioEspecialidadDto> todo = Datos.Listar<UsuarioEspecialidadDto>("SEL_USUARIO_ESPECIALIDAD",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO_DESTINO", usuario },
                        { "@ESPECIALIDAD", especialidad },
                        { "@SOLO_VENCIDAS", vencidas ? (object)true : null },
                        { "@SOLO_POR_VENCER", porVencer ? (object)true : null },
                        { "@HABILITADO", habilitado },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<UsuarioEspecialidadDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /usuario-especialidades/{id} — detalle.     HU-017</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                List<UsuarioEspecialidadDto> r = Datos.Listar<UsuarioEspecialidadDto>("SEL_USUARIO_ESPECIALIDAD",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("La especialidad");

                return Ok(r[0]);
            });
        }

        /// <summary>POST /usuario-especialidades — alta.            HU-017</summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(UsuarioEspecialidadAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);

                if (dto.usuario_destino <= 0)
                    throw new ArgumentException("Indique a qué persona se le registra la especialidad.");

                if (dto.especialidad <= 0)
                    throw new ArgumentException("Indique la especialidad.");

                /* @USUARIO_DESTINO es a QUIEN se le registra; @USUARIO es
                   QUIEN lo registra. Confundirlos deja la auditoría
                   apuntando a la persona equivocada, y son dos parámetros
                   con nombres parecidos en el mismo SP. */
                int id = Datos.Ejecutar("INS_USUARIO_ESPECIALIDAD",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO_DESTINO", dto.usuario_destino },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ESPECIALIDAD", dto.especialidad },
                        { "@ESPECIALIDAD_NIVEL", dto.nivel },
                        { "@CERTIFICACION", dto.certificacion },
                        { "@FECHA_VENCIMIENTO", dto.fecha_vencimiento },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>PUT /usuario-especialidades/{id} — edición.     HU-017</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, UsuarioEspecialidadAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);

                Datos.Ejecutar("UPD_USUARIO_ESPECIALIDAD",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@ESPECIALIDAD_NIVEL", dto.nivel },
                        { "@CERTIFICACION", dto.certificacion },
                        { "@FECHA_VENCIMIENTO", dto.fecha_vencimiento },
                        { "@HABILITADO", dto.habilitado },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id });
            });
        }

        /// <summary>DELETE /usuario-especialidades/{id} — baja.     HU-017</summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Datos.Ejecutar("DEL_USUARIO_ESPECIALIDAD",
                    new Dictionary<string, object> { { "@ID", id } });

                return Ok(new { id = id, mensaje = "Especialidad dada de baja." });
            });
        }
    }
}
