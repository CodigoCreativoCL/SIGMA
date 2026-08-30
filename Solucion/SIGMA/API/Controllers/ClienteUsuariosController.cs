using API.MVC.Model;
using API.Utils;
using Controllers;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Usuarios del cliente (HU-014) y selección de cliente (HU-002).
    ///
    /// POR QUE LAS DOS COSAS EN EL MISMO RECURSO
    ///   Porque las dos son sobre la relación usuario–cliente, que es lo
    ///   que representa Cliente_Usuario. Elegir con qué cliente trabajar es
    ///   escoger una de esas filas, no una entidad aparte.
    /// </summary>
    [RoutePrefix("cliente-usuarios")]
    public class ClienteUsuariosController : ApiBase
    {
        /// <summary>
        /// GET /cliente-usuarios — listado con filtros y paginación.
        ///                                                          HU-014
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<ClienteUsuarioDto> todo = Datos.Listar<ClienteUsuarioDto>("SEL_CLIENTE_USUARIO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@FILTRO", p.filtro },
                        { "@HABILITADO", habilitado },
                        // La foto es un binario grande y ningún listado la
                        // usa: pedirla multiplicaría el peso de la respuesta
                        // por nada.
                        { "@DEVUELVE_FOTO", false }
                    });

                return Ok(Paginado<ClienteUsuarioDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /cliente-usuarios/{id} — detalle.        HU-014</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                List<ClienteUsuarioDto> r = Datos.Listar<ClienteUsuarioDto>("SEL_CLIENTE_USUARIO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@DEVUELVE_FOTO", false }
                    });

                /* El @CLIENTE va aunque se pida por id: sin él, cambiar el
                   número de la URL devolvería usuarios de otro cliente. En
                   un multicliente esa es la fuga más fácil de cometer. */
                if (r == null || r.Count == 0) return NoEncontrado("El usuario");

                return Ok(r[0]);
            });
        }

        /// <summary>
        /// POST /cliente-usuarios — alta.                        HU-014
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(ClienteUsuarioAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.login, "login");
                ExigirTexto(dto.nombres, "nombres");
                ExigirTexto(dto.correo, "correo");

                int id = Datos.Ejecutar("INS_CLIENTE_USUARIO",
                    new Dictionary<string, object>
                    {
                        { "@IDENTIFICADOR", dto.identificador },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@LOGIN", dto.login.Trim() },
                        { "@PASSWORD", dto.password },
                        { "@NOMBRES", dto.nombres.Trim() },
                        { "@APELLIDO_PATERNO", dto.apellido_paterno },
                        { "@APELLIDO_MATERNO", dto.apellido_materno },
                        { "@FONO1", dto.telefono },
                        { "@CORREO", dto.correo.Trim() },
                        { "@PERFILES", dto.perfiles },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>PUT /cliente-usuarios/{id} — edición.        HU-014</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, ClienteUsuarioAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.login, "login");

                Datos.Ejecutar("UPD_CLIENTE_USUARIO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@IDENTIFICADOR", dto.identificador },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@LOGIN", dto.login.Trim() },
                        { "@PASSWORD", dto.password },
                        { "@NOMBRES", dto.nombres },
                        { "@APELLIDO_PATERNO", dto.apellido_paterno },
                        { "@APELLIDO_MATERNO", dto.apellido_materno },
                        { "@FONO1", dto.telefono },
                        { "@CORREO", dto.correo },
                        { "@PERFILES", dto.perfiles },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id });
            });
        }

        /// <summary>
        /// DELETE /cliente-usuarios/{id} — baja LOGICA.          HU-014
        ///
        /// Desafilia del cliente, no borra la persona. Un usuario con
        /// historial de órdenes o de marcaciones no se puede borrar sin
        /// dejar ese historial apuntando a nadie.
        /// </summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Datos.Ejecutar("DEL_CLIENTE_USUARIO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id, mensaje = "Usuario dado de baja del cliente." });
            });
        }


        /* ================================================================
           HU-002 — SELECCIONAR CLIENTE
           ================================================================ */

        /// <summary>
        /// GET /cliente-usuarios/mis-clientes — a cuáles pertenezco.
        ///                                                          HU-002
        /// </summary>
        [HttpGet]
        [Route("mis-clientes")]
        public IHttpActionResult MisClientes()
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                return Ok(SesionController.ClientesDe(SesionApi.UsuarioId()));
            });
        }

        /// <summary>
        /// POST /cliente-usuarios/seleccionar — elegir cliente.  HU-002
        ///
        /// Devuelve un TOKEN NUEVO con el cliente adentro. No basta con
        /// anotarlo en algún lado: el cliente en contexto acota todas las
        /// consultas, así que tiene que viajar firmado. Si se aceptara por
        /// parámetro, cualquiera pediría datos de un cliente al que no
        /// pertenece cambiando un número.
        ///
        /// La pertenencia se vuelve a comprobar acá contra la base, sin
        /// confiar en el id que llega del cliente.
        /// </summary>
        [HttpPost]
        [Route("seleccionar")]
        public IHttpActionResult Seleccionar(SeleccionarClienteDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCuerpo(dto);

                if (dto.cliente <= 0)
                    throw new ArgumentException("Indique el cliente.");

                List<ClienteElegibleDto> mios = SesionController.ClientesDe(SesionApi.UsuarioId());

                ClienteElegibleDto elegido = null;
                foreach (ClienteElegibleDto c in mios)
                    if (c.cli_id == dto.cliente) { elegido = c; break; }

                if (elegido == null)
                    return Error(System.Net.HttpStatusCode.Forbidden,
                                 "No pertenece a ese cliente.");

                SesionDto sesion = new SesionDto();
                sesion.usuario = SesionApi.UsuarioId();
                sesion.login = SesionApi.Login();
                sesion.cliente = elegido.cli_id;
                sesion.cliente_nombre = elegido.cli_nombre;
                sesion.token = TokenGenerator.GenerarTokenUsuario(
                    sesion.usuario, sesion.login, sesion.cliente);

                /* El cambio de cliente cambia los permisos. La caché se bota
                   para las dos combinaciones -la vieja y la nueva- porque si
                   no, el primer minuto en el cliente nuevo respondería con
                   los permisos del anterior. */
                CacheCorta.Botar("permisos", sesion.usuario, 0);
                CacheCorta.Botar("permisos", sesion.usuario, sesion.cliente);

                return Ok(sesion);
            });
        }
    }
}
