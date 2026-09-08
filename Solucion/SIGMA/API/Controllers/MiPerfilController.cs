using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Mi perfil y mi contraseña (HU-005).
    ///
    /// SIEMPRE SOBRE QUIEN LLAMA
    ///   Ningún endpoint de acá recibe un id de usuario. Es "mi" perfil: el
    ///   del token. Un endpoint que edita el perfil de quien se le indique
    ///   deja que cualquiera con un token cambie el teléfono —o la
    ///   contraseña— de otra persona.
    ///
    ///   Administrar a OTROS es /cliente-usuarios, que sí exige permiso.
    ///
    /// EL CAMBIO DE CONTRASEÑA VA APARTE
    ///   No es un campo más de la ficha. Exige la contraseña actual, y esa
    ///   comprobación la hace el SP con @EXIGE_ACTUAL = 1. Meterla en el
    ///   mismo PUT que el teléfono llevaría a que un formulario que solo
    ///   quería corregir un número tuviera que mandar la contraseña.
    /// </summary>
    [RoutePrefix("mi-perfil")]
    public class MiPerfilController : ApiBase
    {
        /// <summary>GET /mi-perfil — mis datos.                     HU-005</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Detalle()
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                List<MiPerfilDto> r = Datos.Listar<MiPerfilDto>("SEL_CLIENTE_USUARIO",
                    new Dictionary<string, object>
                    {
                        { "@ID", SesionApi.UsuarioId() },
                        { "@DEVUELVE_FOTO", false }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El usuario");

                MiPerfilDto perfil = r[0];

                /* LA FOTO SE PEGA ACA, Y COMO RUTA

                   SEL_CLIENTE_USUARIO tiene @DEVUELVE_FOTO, pero eso devuelve
                   el BINARIO: cientos de kilobytes dentro del JSON en cada
                   arranque de la app. La app quiere la ruta del blob y la baja
                   por /archivo/ver, que ya cachea y deduplica.

                   Sin esto el avatar del telefono no podia mostrar la foto de
                   nadie, ni la de uno mismo, y siempre pintaba las iniciales.

                   Se ignora si falla: quedarse sin avatar es un detalle, y
                   tumbar la pantalla de perfil por eso no. */
                if (SesionApi.ClienteId() > 0)
                {
                    List<UsuarioFotoDto> foto = Datos.Listar<UsuarioFotoDto>(
                        "API_SEL_APP_USUARIO_FOTO",
                        new Dictionary<string, object>
                        {
                            { "@USUARIO", SesionApi.UsuarioId() },
                            { "@CLIENTE", SesionApi.ClienteId() }
                        });

                    if (foto != null && foto.Count > 0)
                        perfil.FOTO_RUTA = foto[0].FOTO_RUTA;
                }

                return Ok(perfil);
            });
        }

        /// <summary>
        /// PUT /mi-perfil — editar mis datos.                       HU-005
        ///
        /// Solo teléfono e idioma. El nombre, el correo y el login NO se
        /// editan desde acá: identifican a la persona dentro del cliente y
        /// cambiarlos es una operación administrativa, no una preferencia.
        /// </summary>
        [HttpPut]
        [Route("")]
        public IHttpActionResult Editar(MiPerfilEdicionDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCuerpo(dto);

                Datos.Ejecutar("UPD_USUARIO_MI_PERFIL",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@TELEFONO", dto.telefono },
                        { "@IDIOMA", dto.idioma },
                        // Sin esta bandera el SP leería la foto nula como
                        // "bórrala", y cambiar el teléfono borraría la foto.
                        { "@CAMBIA_FOTO", false }
                    });

                return Ok(new { usuario = SesionApi.UsuarioId() });
            });
        }

        /// <summary>
        /// POST /mi-perfil/password — cambiar mi contraseña.        HU-005
        ///
        /// Las reglas —largo mínimo, y que no repita ninguna de las tres
        /// anteriores— las hace cumplir UPD_USUARIO_PASSWORD. No se copian
        /// acá: si estuvieran en dos lugares, el día que cambie la política
        /// habría que acordarse de los dos, y el que se olvide será el que
        /// menos se prueba.
        /// </summary>
        [HttpPost]
        [Route("password")]
        public IHttpActionResult CambiarPassword(CambioPasswordDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCuerpo(dto);
                ExigirTexto(dto.password_actual, "password_actual");
                ExigirTexto(dto.password_nuevo, "password_nuevo");

                Datos.Ejecutar("UPD_USUARIO_PASSWORD",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@PASSWORD_ACTUAL", dto.password_actual },
                        { "@PASSWORD_NUEVO", dto.password_nuevo },
                        // 1 = está dentro y tiene que escribir la vigente.
                        { "@EXIGE_ACTUAL", true }
                    });

                return Ok(new
                {
                    mensaje = "Contraseña actualizada. El token actual sigue siendo válido; " +
                              "vuelva a iniciar sesión en sus otros dispositivos."
                });
            });
        }
    }
}
