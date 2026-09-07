using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Lo que la app escribe desde terreno: lecturas de medidor (HU-043) y
    /// mediciones de condición (HU-044).
    ///
    /// NO HAY SENSORES EN LOS ACTIVOS
    ///   Cada valor lo lee una persona en su ronda y lo escribe en el
    ///   teléfono. Por eso estos endpoints existen: son la única vía por la
    ///   que esos datos entran al sistema. El SP sella el origen como MANUAL
    ///   y guarda quién lo tomó — un número sin dueño no se puede auditar.
    ///
    /// SON IDEMPOTENTES POR uuid
    ///   El teléfono lo genera **al encolar**, no al enviar. Generado al
    ///   enviar, cada reintento traería uno nuevo y la idempotencia no
    ///   serviría de nada, que es justo el caso del timeout donde el servidor
    ///   sí grabó pero la respuesta no llegó.
    ///
    ///   Repetido devuelve el mismo id con 200, no un error: para la app,
    ///   "ya estaba" y "acabo de grabarlo" son el mismo resultado.
    ///
    /// LA FECHA ES LA DE CAPTURA
    ///   Una lectura tomada a las 09:00 y enviada a las 18:00 es de las
    ///   09:00. Por eso el cuerpo trae `fecha_lectura_utc`: sin ella, todo lo
    ///   que se capturó sin señal quedaría fechado en el momento en que
    ///   volvió la cobertura.
    /// </summary>
    [RoutePrefix("captura")]
    public class CapturaTerrenoController : ApiBase
    {
        /// <summary>
        /// POST /captura/lecturas — registra la lectura de un medidor. HU-043
        /// </summary>
        /// <response code="201">Registrada. Devuelve el id.</response>
        /// <response code="400">El SP rechazó el valor: menor que la anterior sin marcar reinicio, negativo, o fecha futura.</response>
        /// <response code="403">Sin el permiso, o el medidor no es de este cliente.</response>
        [HttpPost]
        [Route("lecturas")]
        public IHttpActionResult Lectura(LecturaAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR LECTURA");
                ExigirCliente();
                ExigirCuerpo(dto);

                int id = Datos.Ejecutar("API_INS_ACTIVO_MEDIDOR_LECTURA",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ACTIVO_MEDIDOR", dto.activo_medidor },
                        { "@VALOR_ACUMULADO", dto.valor },
                        { "@FECHA_LECTURA_UTC", dto.fecha_lectura_utc },
                        { "@ES_REINICIO", dto.es_reinicio },
                        { "@ORDEN_TRABAJO", dto.orden_trabajo },
                        { "@OBSERVACION", dto.observacion },
                        { "@ENTRADA_MODO", dto.entrada_modo },
                        { "@UUID", dto.uuid },
                        // Del token, nunca de un parámetro: si no, cualquiera
                        // con un token válido registraría lecturas a nombre de
                        // otro y la auditoría diría lo que el atacante quiso.
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// POST /captura/mediciones — registra una medición de condición. HU-044
        /// </summary>
        /// <response code="201">Registrada. Devuelve el id.</response>
        /// <response code="400">El SP rechazó el valor o la unidad.</response>
        /// <response code="403">Sin el permiso, o la variable no es de este cliente.</response>
        [HttpPost]
        [Route("mediciones")]
        public IHttpActionResult Medicion(MedicionAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR MEDICION");
                ExigirCliente();
                ExigirCuerpo(dto);

                int id = Datos.Ejecutar("API_INS_ACTIVO_MEDICION",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ACTIVO_VARIABLE", dto.activo_variable },
                        { "@VALOR", dto.valor },
                        { "@FECHA_MEDICION_UTC", dto.fecha_medicion_utc },
                        { "@UNIDAD_MEDIDA", dto.unidad_medida },
                        { "@ACTIVO_COMPONENTE", dto.activo_componente },
                        { "@ORDEN_TRABAJO", dto.orden_trabajo },
                        { "@OBSERVACION", dto.observacion },
                        { "@ENTRADA_MODO", dto.entrada_modo },
                        { "@UUID", dto.uuid },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }
    }
}
