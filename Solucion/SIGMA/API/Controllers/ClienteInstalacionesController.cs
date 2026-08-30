using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Plantas del cliente (HU-011).
    ///
    /// NO HAY BORRADO FISICO. Una planta con áreas, activos, órdenes o
    /// usuarios asociados no se borra: se deshabilita. La baja lógica
    /// conserva el histórico, que es lo que pide el negocio y lo que
    /// exige el estándar del grupo para tablas maestro.
    /// </summary>
    [RoutePrefix("cliente-instalaciones")]
    public class ClienteInstalacionesController : ApiBase
    {
        /// <summary>GET /cliente-instalaciones — listado.        HU-011</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<ClienteInstalacionDto> todo = Datos.Listar<ClienteInstalacionDto>("SEL_CLIENTE_INSTALACION",
                    new Dictionary<string, object>
                    {
                        // El SP lo declara varchar: recibe el id como texto.
                        { "@CLIENTE", SesionApi.ClienteId().ToString() },
                        { "@FILTRO", p.filtro },
                        { "@HABILITADO", habilitado }
                    });

                return Ok(Paginado<ClienteInstalacionDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /cliente-instalaciones/{id} — detalle.   HU-011</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                List<ClienteInstalacionDto> r = Datos.Listar<ClienteInstalacionDto>("SEL_CLIENTE_INSTALACION",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId().ToString() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("La planta");

                return Ok(r[0]);
            });
        }

        /// <summary>POST /cliente-instalaciones — alta.          HU-011</summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(ClienteInstalacionAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.codigo, "codigo");
                ExigirTexto(dto.nombre, "nombre");

                ValidarCoordenadas(dto);

                int id = Datos.Ejecutar("INS_CLIENTE_INSTALACION",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CODIGO", dto.codigo.Trim().ToUpperInvariant() },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@DIRECCION", dto.direccion },
                        { "@ZONA_HORARIA", dto.zona_horaria },
                        { "@LATITUD", dto.latitud },
                        { "@LONGITUD", dto.longitud },
                        { "@HABILITADO", dto.habilitado },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>PUT /cliente-instalaciones/{id} — edición.   HU-011</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, ClienteInstalacionAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.codigo, "codigo");
                ExigirTexto(dto.nombre, "nombre");

                ValidarCoordenadas(dto);

                Datos.Ejecutar("UPD_CLIENTE_INSTALACION",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CODIGO", dto.codigo.Trim().ToUpperInvariant() },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@DIRECCION", dto.direccion },
                        { "@ZONA_HORARIA", dto.zona_horaria },
                        { "@LATITUD", dto.latitud },
                        { "@LONGITUD", dto.longitud },
                        { "@HABILITADO", dto.habilitado },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id });
            });
        }

        /// <summary>
        /// DELETE /cliente-instalaciones/{id} — baja lógica.     HU-011
        /// </summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Datos.Ejecutar("DEL_CLIENTE_INSTALACION",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id, mensaje = "Planta deshabilitada." });
            });
        }

        /// <summary>
        /// Las coordenadas son opcionales, pero si vienen tienen que ser
        /// coordenadas. Un error de tipeo que ponga la planta en mitad del
        /// océano no lo detecta nadie hasta que un mapa se ve raro.
        /// </summary>
        private static void ValidarCoordenadas(ClienteInstalacionAltaDto dto)
        {
            if (dto.latitud.HasValue && (dto.latitud < -90 || dto.latitud > 90))
                throw new ArgumentException("La latitud debe estar entre -90 y 90.");

            if (dto.longitud.HasValue && (dto.longitud < -180 || dto.longitud > 180))
                throw new ArgumentException("La longitud debe estar entre -180 y 180.");
        }
    }
}
