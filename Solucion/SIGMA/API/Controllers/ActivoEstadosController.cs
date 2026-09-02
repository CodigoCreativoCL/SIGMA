using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Cambiar el estado de un activo desde la app (HU-038).
    ///
    /// El proceso vive en el SP ACTIVO_CAMBIAR_ESTADO —con sus reglas—, el
    /// mismo que usa la web: asi la app y el administrativo dan el MISMO
    /// resultado. El manejo de errores no se escribe aca: cada RAISERROR del
    /// SP lo traduce ErrorSql a su codigo HTTP (400/403/409…), no a un 500
    /// generico. El cliente sale del token, no del cuerpo.
    /// </summary>
    [RoutePrefix("activo-estados")]
    public class ActivoEstadosController : ApiBase
    {
        /// <summary>
        /// POST /activo-estados — cambia el estado de un activo. HU-038
        ///
        /// Cierra el tramo vigente, abre uno nuevo con el motivo y deja el
        /// activo con su estado actual. Devuelve 201 con el id del tramo.
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Cambiar(ActivoEstadoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirCuerpo(dto);
                ExigirCliente();
                ExigirPermiso("CAMBIAR ESTADO ACTIVO");

                if (dto.activo <= 0) throw new ArgumentException("Indique el activo.");
                if (dto.estado <= 0) throw new ArgumentException("Indique el nuevo estado.");

                int id = Datos.Ejecutar("ACTIVO_CAMBIAR_ESTADO",
                    new Dictionary<string, object>
                    {
                        { "@ACTIVO", dto.activo },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@NUEVO_ESTADO", dto.estado },
                        { "@MOTIVO", dto.motivo },
                        { "@ORDEN_TRABAJO", dto.orden_trabajo },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }
    }
}
