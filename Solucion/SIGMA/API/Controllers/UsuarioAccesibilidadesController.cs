using API.MVC.Model;
using API.Utils;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Las opciones de accesibilidad de la PERSONA.                    HU-162
    ///
    /// CADA UNO LAS SUYAS
    ///   La preferencia es de quien entra, no de un administrador: hay una fila
    ///   por usuario (índice único UX_UAC_USUARIO). Por eso estos endpoints
    ///   trabajan siempre contra el usuario del token —`SesionApi.UsuarioId()`—
    ///   y nunca reciben un id de usuario por parámetro: nadie lee ni cambia las
    ///   opciones de otro. Eso ocupa el lugar del «filtro por cliente» del resto
    ///   de la API: acá el dueño es la persona.
    /// </summary>
    [RoutePrefix("usuario-accesibilidades")]
    public class UsuarioAccesibilidadesController : ApiBase
    {
        /// <summary>
        /// GET /usuario-accesibilidades — las opciones de quien llama.
        ///
        /// Devuelve la fila de la persona (0 o 1; el índice único garantiza que
        /// no hay más). Se expone un DTO sin las columnas internas (quién creó,
        /// fechas de auditoría de escritura).
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Mias(bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                List<UsuarioAccesibilidadDto> lista = Datos.Listar<UsuarioAccesibilidadDto>(
                    "SEL_USUARIO_ACCESIBILIDAD",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@HABILITADO", habilitado }
                    });

                return Ok(lista);
            });
        }

        /// <summary>
        /// GET /usuario-accesibilidades/{id} — una fila por su id.
        ///
        /// Sólo si es de quien llama: pedir el id de otro responde 404, no se
        /// revela que existe ni qué tiene.
        /// </summary>
        /// <response code="404">No existe, o no es tuya.</response>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                List<UsuarioAccesibilidadDto> lista = Datos.Listar<UsuarioAccesibilidadDto>(
                    "SEL_USUARIO_ACCESIBILIDAD",
                    new Dictionary<string, object> { { "@ID", id } });

                if (lista.Count == 0 || lista[0].uac_usuario != SesionApi.UsuarioId())
                    return NoEncontrado("Las opciones de accesibilidad");

                return Ok(lista[0]);
            });
        }

        /// <summary>
        /// POST /usuario-accesibilidades — crea las opciones de quien llama.
        ///
        /// Son del usuario del token, no de un id del cuerpo. Si ya tiene una
        /// fila, el SP lo rechaza y se corrige con PUT. El cuerpo se valida acá
        /// antes de la base; el RAISERROR del SP sale como 400 legible.
        /// </summary>
        /// <response code="201">Creadas.</response>
        /// <response code="400">Valores fuera de rango, o ya existían (usa PUT).</response>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(UsuarioAccesibilidadAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("CONFIGURAR ACCESIBILIDAD");
                ExigirCuerpo(dto);

                if (dto.volumen < 0 || dto.volumen > 1)
                    throw new System.ArgumentException("El volumen va de 0 a 1.");
                if (dto.velocidad_voz <= 0 || dto.velocidad_voz > 3)
                    throw new System.ArgumentException("La velocidad de voz va de 0 a 3.");

                int id = Datos.Ejecutar("INS_USUARIO_ACCESIBILIDAD",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@ENTRADA_VOZ", dto.entrada_voz },
                        { "@LECTURA_VOZ", dto.lectura_voz },
                        { "@CONFIRMACION_HABLADA", dto.confirmacion_hablada },
                        { "@VELOCIDAD_VOZ", dto.velocidad_voz },
                        { "@TEXTO_GRANDE", dto.texto_grande },
                        { "@ALTO_CONTRASTE", dto.alto_contraste },
                        { "@ICONOS_GRANDES", dto.iconos_grandes },
                        { "@IDIOMA", dto.idioma },
                        { "@VOLUMEN", dto.volumen },
                        { "@SILENCIAR_ALERTAS", dto.silenciar_alertas },
                        { "@USUARIO_CREACION", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// PUT /usuario-accesibilidades/{id} — cambia las opciones.
        ///
        /// Sólo las propias (si el id no es tuyo, 404). Lo que no venga en el
        /// cuerpo no se toca (ISNULL en el SP): una pantalla parcial no borra lo
        /// que no muestra.
        /// </summary>
        /// <response code="200">Actualizadas.</response>
        /// <response code="404">No existe, o no es tuya.</response>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, UsuarioAccesibilidadEdicionDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("CONFIGURAR ACCESIBILIDAD");
                ExigirCuerpo(dto);

                if (!EsMia(id)) return NoEncontrado("Las opciones de accesibilidad");

                if (dto.volumen.HasValue && (dto.volumen < 0 || dto.volumen > 1))
                    throw new System.ArgumentException("El volumen va de 0 a 1.");
                if (dto.velocidad_voz.HasValue && (dto.velocidad_voz <= 0 || dto.velocidad_voz > 3))
                    throw new System.ArgumentException("La velocidad de voz va de 0 a 3.");

                Datos.Ejecutar("UPD_USUARIO_ACCESIBILIDAD",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@ENTRADA_VOZ", dto.entrada_voz },
                        { "@LECTURA_VOZ", dto.lectura_voz },
                        { "@CONFIRMACION_HABLADA", dto.confirmacion_hablada },
                        { "@VELOCIDAD_VOZ", dto.velocidad_voz },
                        { "@TEXTO_GRANDE", dto.texto_grande },
                        { "@ALTO_CONTRASTE", dto.alto_contraste },
                        { "@ICONOS_GRANDES", dto.iconos_grandes },
                        { "@IDIOMA", dto.idioma },
                        { "@VOLUMEN", dto.volumen },
                        { "@SILENCIAR_ALERTAS", dto.silenciar_alertas },
                        { "@USUARIO_ACTUALIZACION", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id });
            });
        }

        /// <summary>
        /// DELETE /usuario-accesibilidades/{id} — baja lógica.
        ///
        /// No borra la fila: la deshabilita (uac_habilitado = 0) y la interfaz
        /// vuelve a sus valores por defecto. Sólo las propias.
        /// </summary>
        /// <response code="200">Deshabilitadas.</response>
        /// <response code="404">No existe, o no es tuya.</response>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("CONFIGURAR ACCESIBILIDAD");

                if (!EsMia(id)) return NoEncontrado("Las opciones de accesibilidad");

                Datos.Ejecutar("DEL_USUARIO_ACCESIBILIDAD",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@USUARIO_ACTUALIZACION", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id });
            });
        }

        // ------------------------------------------------------------------

        /// <summary>True si esa fila es de quien llama. Evita tocar lo de otro.</summary>
        private bool EsMia(int id)
        {
            List<UsuarioAccesibilidadDto> lista = Datos.Listar<UsuarioAccesibilidadDto>(
                "SEL_USUARIO_ACCESIBILIDAD",
                new Dictionary<string, object> { { "@ID", id } });

            return lista.Count > 0 && lista[0].uac_usuario == SesionApi.UsuarioId();
        }
    }
}
