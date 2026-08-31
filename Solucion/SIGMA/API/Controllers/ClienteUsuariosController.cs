using API.MVC.Model;
using API.Utils;
using Controllers;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Selección de cliente al iniciar sesión (HU-002).
    ///
    /// QUE PASO CON EL CRUD DE USUARIOS DEL CLIENTE
    ///   Estaba acá y se retiró el 31-08-2026. Dar de alta usuarios,
    ///   asignarles perfil, plantas y especialidades es HU-014, y esa
    ///   historia es del Administrador del Cliente, que trabaja desde la
    ///   web. La web llama a los SP directo, así que esos cinco endpoints
    ///   no los consumía nadie.
    ///
    ///   Quedó en _RETIRADO/API/ con el resto. Ver MD/SIGMA_ALCANCE_APP.md.
    ///
    /// POR QUE LA RUTA SIGUE SIENDO cliente-usuarios
    ///   Porque elegir con qué cliente trabajar es escoger una fila de
    ///   Cliente_Usuario: la afiliación de la persona a la empresa. El
    ///   recurso es correcto aunque ahora solo tenga dos operaciones.
    /// </summary>
    [RoutePrefix("cliente-usuarios")]
    public class ClienteUsuariosController : ApiBase
    {
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
