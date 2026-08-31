using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Los movimientos de inventario: ingreso, entrega, devolucion y ajuste
    /// (HU-054, HU-055, HU-057).
    ///
    /// UN SOLO POST PARA LAS TRES HISTORIAS
    ///   Podrian ser /ingresos, /entregas y /ajustes. No lo son porque del
    ///   lado de la base son el MISMO procedimiento con distinto tipo, y
    ///   partirlo aca crearia tres caminos que pueden divergir contra uno
    ///   solo que no puede. El tipo decide el signo y las validaciones; la
    ///   API no repite ninguna de las dos cosas.
    ///
    /// EL PERMISO SI DEPENDE DEL TIPO
    ///   Entregar no es ajustar. El bodeguero entrega todos los dias;
    ///   ajustar es corregir el conteo y no todos los que entregan deberian
    ///   poder hacerlo. Por eso el permiso se resuelve por tipo antes de
    ///   llamar al SP.
    /// </summary>
    [RoutePrefix("inventario-movimientos")]
    public class InventarioMovimientosController : ApiBase
    {
        // Los ids de Inventario_Movimiento_Tipo, con nombre para que el
        // codigo no se lea como una lista de numeros magicos.
        private const int INGRESO_COMPRA   = 1;
        private const int SALIDA_CONSUMO   = 2;
        private const int DEVOLUCION       = 3;
        private const int AJUSTE_POSITIVO  = 4;
        private const int AJUSTE_NEGATIVO  = 5;
        private const int TRASLADO_SALIDA  = 6;
        private const int MERMA            = 8;

        /// <summary>
        /// GET /inventario-movimientos — el historial.   HU-057 criterio 2
        ///
        /// Cada fila trae FAMILIA (INGRESO / CONSUMO / AJUSTE / TRASLADO)
        /// para que la app distinga los ajustes sin interpretar el nombre
        /// del tipo, que es texto y puede cambiar.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? repuesto = null,
                                        int? bodega = null, int? tipo = null,
                                        DateTime? desde = null, DateTime? hasta = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER EXISTENCIAS");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<InventarioMovimientoDto> todo = Datos.Listar<InventarioMovimientoDto>(
                    "SEL_INVENTARIO_MOVIMIENTO",
                    new Dictionary<string, object>
                    {
                        { "@ID", null },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@REPUESTO", repuesto },
                        { "@BODEGA", bodega },
                        { "@TIPO", tipo },
                        { "@DESDE", desde },
                        { "@HASTA", hasta },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<InventarioMovimientoDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /inventario-movimientos/{id} — el detalle.</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER EXISTENCIAS");
                ExigirCliente();

                List<InventarioMovimientoDto> r = Datos.Listar<InventarioMovimientoDto>(
                    "SEL_INVENTARIO_MOVIMIENTO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@REPUESTO", null }, { "@BODEGA", null }, { "@TIPO", null },
                        { "@DESDE", null }, { "@HASTA", null }, { "@FILTRO", null }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El movimiento");

                return Ok(r[0]);
            });
        }

        /// <summary>
        /// POST /inventario-movimientos — registra el movimiento.
        ///                                    HU-054 · HU-055 · HU-057
        ///
        /// Devuelve 201 con el id. Si el uuid ya habia pasado, el SP
        /// devuelve el id que ya existia sin volver a mover el saldo: para
        /// la app el resultado es el mismo y no hay nada que reintentar.
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(MovimientoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirCuerpo(dto);
                ExigirCliente();
                ExigirPermisoDelTipo(dto.tipo);

                if (dto.repuesto <= 0) throw new ArgumentException("Indique el repuesto.");
                if (dto.bodega <= 0) throw new ArgumentException("Indique la bodega.");
                if (dto.cantidad <= 0) throw new ArgumentException("La cantidad debe ser mayor que cero.");

                int id = Datos.Ejecutar("INS_INVENTARIO_MOVIMIENTO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@REPUESTO", dto.repuesto },
                        { "@BODEGA", dto.bodega },
                        { "@TIPO", dto.tipo },
                        { "@CANTIDAD", dto.cantidad },
                        { "@UBICACION", dto.ubicacion },
                        { "@LOTE", dto.lote },
                        { "@COSTO_UNITARIO", dto.costo_unitario },
                        { "@MONEDA", dto.moneda },
                        { "@ORDEN_TRABAJO", dto.orden_trabajo },
                        { "@BODEGA_DESTINO", dto.bodega_destino },
                        { "@OBSERVACION", dto.observacion },
                        { "@UUID", dto.uuid },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// Que permiso hace falta para cada tipo de movimiento.
        ///
        /// El traslado y la merma se agrupan con el ajuste porque las tres
        /// cambian la existencia sin que haya entrado ni salido nada por la
        /// puerta: son correcciones o movimientos internos, y quien pueda
        /// hacer una deberia poder explicar las tres.
        /// </summary>
        private void ExigirPermisoDelTipo(int tipo)
        {
            switch (tipo)
            {
                case INGRESO_COMPRA:
                    ExigirPermiso("REGISTRAR INGRESO REPUESTO");
                    break;

                case SALIDA_CONSUMO:
                case DEVOLUCION:
                    ExigirPermiso("ENTREGAR REPUESTO");
                    break;

                case AJUSTE_POSITIVO:
                case AJUSTE_NEGATIVO:
                case TRASLADO_SALIDA:
                case MERMA:
                    ExigirPermiso("AJUSTAR INVENTARIO");
                    break;

                default:
                    /* Un tipo desconocido se rechaza ACA y no llega al SP.
                       No es por eficiencia: es que sin tipo valido no hay
                       permiso que exigir, y dejarlo pasar significaria
                       llamar al procedimiento sin haber comprobado nada. */
                    throw new ArgumentException(
                        "El tipo de movimiento no es válido. " +
                        "Use 1 ingreso, 2 consumo, 3 devolución, 4 y 5 ajuste, 6 traslado, 8 merma.");
            }
        }
    }
}
