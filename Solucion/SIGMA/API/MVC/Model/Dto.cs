using System;
using System.Collections.Generic;

namespace API.MVC.Model
{
    /* =====================================================================
       DTOs de la API.

       POR QUE NO SE DEVUELVE LA FILA COMPLETA
         Los SEL_ del proyecto traen todo lo que la web necesita para
         pintar sus grillas, y eso incluye columnas que fuera del servidor
         no le sirven a nadie y sí ayudan a quien quiera atacar: hashes de
         contraseña, sales, ids de auditoría, banderas internas.

         Un DTO por recurso es la lista explícita de lo que sale. Lo que no
         está declarado no viaja, y agregar una columna al SP no la publica
         por accidente.

       LOS NOMBRES SE MANTIENEN IGUALES A LA COLUMNA
         cin_id, no Id. Es la convención del grupo para los Model, es lo que
         permite que el mapeador por reflexión funcione sin configuración, y
         hace que un problema se pueda rastrear del JSON al SP sin traducir
         nombres por el camino.
       ===================================================================== */


    /// <summary>Lo que devuelve un login correcto (HU-001).</summary>
    [Serializable]
    public class SesionDto
    {
        public int usuario { get; set; }
        public string login { get; set; }
        public string nombre { get; set; }
        public int cliente { get; set; }
        public string cliente_nombre { get; set; }
        public string token { get; set; }
        public int expira_minutos { get; set; }

        /// <summary>
        /// True cuando la persona pertenece a más de un cliente y todavía
        /// no eligió (HU-002). La app tiene que mandarla a elegir antes de
        /// dejarla operar.
        /// </summary>
        public bool debe_elegir_cliente { get; set; }
    }

    /// <summary>Credenciales de entrada.</summary>
    public class LoginDto
    {
        public string login { get; set; }
        public string password { get; set; }
    }

    /// <summary>Lo que devuelve SEL_LOGIN.</summary>
    public class LoginResultado
    {
        public int ID { get; set; }
        public string CODE { get; set; }
        public string MENSAJE { get; set; }
    }

    /// <summary>Un cliente al que pertenece la persona (HU-002).</summary>
    public class ClienteElegibleDto
    {
        public int cli_id { get; set; }
        public string cli_nombre { get; set; }
    }

    public class SeleccionarClienteDto
    {
        public int cliente { get; set; }
    }


    /// <summary>Un permiso del usuario en el cliente en contexto (HU-006).</summary>
    public class PermisoDto
    {
        public string prm_codigo { get; set; }
    }


    /// <summary>Planta del cliente (HU-011).</summary>
    public class ClienteInstalacionDto
    {
        public int cin_id { get; set; }
        public int cin_cliente { get; set; }
        public string cin_codigo { get; set; }
        public string cin_nombre { get; set; }
        public string cin_descripcion { get; set; }
        public string cin_direccion { get; set; }
        public int? cin_zona_horaria { get; set; }
        public decimal? cin_latitud { get; set; }
        public decimal? cin_longitud { get; set; }
        public bool cin_habilitado { get; set; }
    }

    public class ClienteInstalacionAltaDto
    {
        public string codigo { get; set; }
        public string nombre { get; set; }
        public string descripcion { get; set; }
        public string direccion { get; set; }
        public int? zona_horaria { get; set; }
        public decimal? latitud { get; set; }
        public decimal? longitud { get; set; }
        public bool habilitado { get; set; }
    }


    /// <summary>Área de una planta (HU-012).</summary>
    public class InstalacionAreaDto
    {
        public int iar_id { get; set; }
        public int iar_cliente { get; set; }
        public int iar_cliente_instalacion { get; set; }
        public int? iar_area_padre { get; set; }
        public string iar_codigo { get; set; }
        public string iar_nombre { get; set; }
        public string iar_descripcion { get; set; }
        public bool iar_habilitado { get; set; }
        public string PADRE_NOMBRE { get; set; }
        public int NIVEL { get; set; }
        public string RUTA { get; set; }
    }


    /// <summary>Un evento de la línea de tiempo de un activo (HU-037).</summary>
    public class ActivoFichaEventoDto
    {
        public DateTime? FECHA { get; set; }
        public string TIPO_EVENTO { get; set; }
        public string TITULO { get; set; }
        public string DETALLE { get; set; }
        public string USUARIO_NOMBRE { get; set; }
    }


    /// <summary>Solicitud de recuperación de contraseña (HU-004).</summary>
    public class RecuperacionDto
    {
        public string correo { get; set; }
    }

    public class RestablecerDto
    {
        public string token { get; set; }
        public string password_nuevo { get; set; }
    }


    /// <summary>Catálogo del sistema (HU-020).</summary>
    public class CatalogoDto
    {
        public int ctl_id { get; set; }
        public string ctl_codigo { get; set; }
        public string ctl_nombre { get; set; }
        public string ctl_descripcion { get; set; }
        public string ctl_modulo { get; set; }
        public bool ctl_ampliable { get; set; }
        public bool ctl_habilitado { get; set; }
    }

    /// <summary>Valor de un catálogo (HU-021).</summary>
    public class CatalogoValorDto
    {
        public int valor_id { get; set; }
        public string valor_codigo { get; set; }
        public string valor_nombre { get; set; }
        public string valor_descripcion { get; set; }
        public int? valor_orden { get; set; }
        public int? valor_cliente { get; set; }
        public bool valor_habilitado { get; set; }
    }


    /// <summary>Mi perfil (HU-005).</summary>
    public class MiPerfilDto
    {
        public int usu_id { get; set; }
        public string usu_login { get; set; }
        public string usu_nombre { get; set; }
        public string usu_apellido_paterno { get; set; }
        public string usu_apellido_materno { get; set; }
        public string usu_correo { get; set; }
        public string usu_telefono { get; set; }
        public string PERFILES { get; set; }
    }

    public class MiPerfilEdicionDto
    {
        public string telefono { get; set; }
        public int? idioma { get; set; }
    }

    public class CambioPasswordDto
    {
        public string password_actual { get; set; }
        public string password_nuevo { get; set; }
    }


    /// <summary>
    /// Una fila del árbol de la app, tal como sale de SEL_MENU_APP
    /// (HU-006, bloque 58).
    ///
    /// Los nombres son los de la columna porque así mapea Datos.Listar. Se
    /// convierten a algo legible en MenuAppNodo antes de salir al JSON: la
    /// app no tiene por qué conocer el prefijo mnu_.
    /// </summary>
    public class MenuAppFila
    {
        public int mnu_id { get; set; }
        public string mnu_nombre { get; set; }
        public string mnu_descripcion { get; set; }
        public int mnu_nivel { get; set; }
        public int? mnu_padre { get; set; }
        public int mnu_orden { get; set; }
        public string mnu_link { get; set; }
        public string mnu_icon { get; set; }
        public string mnu_ambito { get; set; }
    }


    /// <summary>
    /// El árbol que consume Flutter para armar su navegación.
    ///
    /// Va anidado y no plano a propósito: plano obliga a cada consumidor a
    /// reconstruir la jerarquía por su cuenta, y el día que haya dos
    /// consumidores habrá dos reconstrucciones distintas.
    /// </summary>
    public class MenuAppNodo
    {
        public int id { get; set; }
        public string nombre { get; set; }
        public string descripcion { get; set; }
        public int orden { get; set; }

        /// <summary>Nombre de la ruta en Flutter (app://...). Null en un grupo.</summary>
        public string ruta { get; set; }

        public string icono { get; set; }
        public List<MenuAppNodo> hijos { get; set; }
    }


    /* =====================================================================
       INVENTARIO — el modulo del bodeguero (Sprint 3).

       Solo lo que la app usa. HU-050 (maestro de repuestos), HU-052
       (bodegas) y HU-053 (umbrales) son historias solo web y no tienen
       endpoint: la web llama a los SP directo. Lo que si viaja es la
       LECTURA de repuestos y bodegas, porque sin ella la app no puede
       ofrecer que mover ni a donde.
       ===================================================================== */

    /// <summary>Repuesto del maestro, en lectura (HU-050 · referencia para la app).</summary>
    public class RepuestoDto
    {
        public int rep_id { get; set; }
        public string rep_codigo { get; set; }
        public string rep_nombre { get; set; }
        public string rep_fabricante { get; set; }
        public string rep_modelo { get; set; }
        public bool rep_controla_lote { get; set; }
        public bool rep_es_consumible { get; set; }
        public string UNIDAD_SIMBOLO { get; set; }
        public decimal EXISTENCIA_TOTAL { get; set; }
        public bool rep_habilitado { get; set; }
    }

    /// <summary>Bodega, en lectura (HU-052 · referencia para la app).</summary>
    public class BodegaDto
    {
        public int bod_id { get; set; }
        public string bod_codigo { get; set; }
        public string bod_nombre { get; set; }
        public int bod_cliente_instalacion { get; set; }
        public string PLANTA_NOMBRE { get; set; }
        public bool bod_habilitado { get; set; }
    }

    /// <summary>Ubicacion dentro de una bodega (HU-052 CA2).</summary>
    public class BodegaUbicacionDto
    {
        public int bub_id { get; set; }
        public int bub_bodega { get; set; }
        public string bub_codigo { get; set; }
        public string bub_nombre { get; set; }
    }

    /// <summary>
    /// Un lote de un repuesto que los controla (HU-054 CA2).
    ///
    /// VENCIDO llega calculado por el SP: depende de la fecha de hoy, y una
    /// columna con esa marca estaria mal la mitad del tiempo.
    /// </summary>
    public class RepuestoLoteDto
    {
        public int rlo_id { get; set; }
        public int rlo_repuesto { get; set; }
        public string rlo_codigo { get; set; }
        public DateTime? rlo_fecha_ingreso { get; set; }
        public DateTime? rlo_fecha_vencimiento { get; set; }
        public string REPUESTO_CODIGO { get; set; }
        public int VENCIDO { get; set; }
    }


    /// <summary>
    /// La existencia de un repuesto en una bodega (HU-056).
    ///
    /// BAJO_MINIMO y SOBRE_MAXIMO llegan calculados por el SP. La app los
    /// pinta, no los deduce: si cada consumidor comparara la cantidad
    /// contra el umbral por su cuenta, el dia que la regla cambie -por
    /// ejemplo, avisar en el punto de reposicion y no en el minimo- habria
    /// que cambiarla en todos.
    /// </summary>
    public class InventarioSaldoDto
    {
        public int isa_id { get; set; }
        public int isa_repuesto { get; set; }
        public int isa_bodega { get; set; }
        public decimal isa_cantidad { get; set; }
        public decimal isa_cantidad_reservada { get; set; }
        public decimal CANTIDAD_DISPONIBLE { get; set; }
        public DateTime? isa_fecha_ultimo_movimiento { get; set; }
        public string REPUESTO_CODIGO { get; set; }
        public string REPUESTO_NOMBRE { get; set; }
        public bool rep_controla_lote { get; set; }
        public string UNIDAD_SIMBOLO { get; set; }
        public string BODEGA_CODIGO { get; set; }
        public string BODEGA_NOMBRE { get; set; }
        public string PLANTA_NOMBRE { get; set; }
        public decimal? rbs_stock_minimo { get; set; }
        public decimal? rbs_stock_maximo { get; set; }
        public int BAJO_MINIMO { get; set; }
        public int SOBRE_MAXIMO { get; set; }
        public string UBICACION_CODIGO { get; set; }
    }

    /// <summary>Un movimiento de inventario (HU-057 CA2).</summary>
    public class InventarioMovimientoDto
    {
        public int imo_id { get; set; }
        public Guid imo_uuid { get; set; }
        public int imo_repuesto { get; set; }
        public int imo_bodega { get; set; }
        public decimal imo_cantidad { get; set; }
        public decimal? imo_costo_unitario { get; set; }
        public DateTime imo_fecha_movimiento_utc { get; set; }
        public int? imo_orden_trabajo { get; set; }
        public string imo_observacion { get; set; }
        public string TIPO_CODIGO { get; set; }
        public string TIPO_NOMBRE { get; set; }
        public int SIGNO { get; set; }

        /// <summary>INGRESO · CONSUMO · AJUSTE · TRASLADO. HU-057 CA2.</summary>
        public string FAMILIA { get; set; }

        public string REPUESTO_CODIGO { get; set; }
        public string REPUESTO_NOMBRE { get; set; }
        public string UNIDAD_SIMBOLO { get; set; }
        public string BODEGA_CODIGO { get; set; }
        public string BODEGA_DESTINO_NOMBRE { get; set; }
        public string UBICACION_CODIGO { get; set; }
        public string LOTE_CODIGO { get; set; }
        public string USUARIO_NOMBRE { get; set; }
    }

    /// <summary>
    /// Lo que la app manda para registrar un movimiento
    /// (HU-054 ingreso · HU-055 entrega y devolucion · HU-057 ajuste).
    ///
    /// EL UUID LO PONE EL TELEFONO
    ///   Es lo que hace que un reintento no descuente dos veces. La app
    ///   genera el uuid al ENCOLAR el movimiento, no al enviarlo: si lo
    ///   generara al enviar, cada reintento traeria uno nuevo y la
    ///   idempotencia no serviria de nada.
    /// </summary>
    public class MovimientoAltaDto
    {
        public int repuesto { get; set; }
        public int bodega { get; set; }
        public int tipo { get; set; }
        public decimal cantidad { get; set; }
        public int? ubicacion { get; set; }
        public int? lote { get; set; }
        public decimal? costo_unitario { get; set; }
        public int? moneda { get; set; }
        public int? orden_trabajo { get; set; }
        public int? bodega_destino { get; set; }
        public string observacion { get; set; }
        public Guid? uuid { get; set; }
    }


    /* ================================================================
       ESCANEO DE UNA ETIQUETA
       ================================================================ */

    /// <summary>
    /// El lugar -o el repuesto- que se escaneo.
    ///
    /// Los tres SP de desglose devuelven la MISMA forma, asi que la app
    /// dibuja una sola pantalla para bodega, estante y repuesto en vez de
    /// tres. Las columnas que no aplican vienen nulas.
    /// </summary>
    public class DesgloseCabeceraDto
    {
        public int bub_id { get; set; }
        public int bod_id { get; set; }
        public int rep_id { get; set; }

        public string bub_codigo { get; set; }
        public string bub_nombre { get; set; }
        public string bod_codigo { get; set; }
        public string bod_nombre { get; set; }
        public string rep_codigo { get; set; }
        public string rep_nombre { get; set; }

        public string PLANTA { get; set; }
        public string UNIDAD { get; set; }
        public decimal? TOTAL { get; set; }

        public bool? bub_habilitado { get; set; }
        public bool? bod_habilitado { get; set; }
        public bool? rep_habilitado { get; set; }
        public bool? rep_controla_lote { get; set; }
    }

    /// <summary>Una linea del desglose: un repuesto, en un sitio, de un lote.</summary>
    public class DesgloseLineaDto
    {
        public int rep_id { get; set; }
        public string rep_codigo { get; set; }
        public string rep_nombre { get; set; }
        public string rep_fabricante { get; set; }
        public string rep_modelo { get; set; }

        public string BODEGA { get; set; }
        public string UBICACION { get; set; }
        public string UBICACION_NOMBRE { get; set; }

        public string UNIDAD { get; set; }
        public decimal CANTIDAD { get; set; }
        public decimal? COSTO_PROMEDIO { get; set; }

        public string LOTE_CODIGO { get; set; }
        public DateTime? LOTE_VENCE { get; set; }
        public int? DIAS_PARA_VENCER { get; set; }

        public DateTime? ULTIMO_MOVIMIENTO { get; set; }
        public string ULTIMO_USUARIO { get; set; }
    }

    /// <summary>Lo que la app recibe al escanear.</summary>
    public class EscaneoDto
    {
        /// <summary>UBI, BOD o REP: con esto la app rotula la pantalla.</summary>
        public string tipo { get; set; }

        public int id { get; set; }
        public string token { get; set; }

        public DesgloseCabeceraDto cabecera { get; set; }
        public List<DesgloseLineaDto> lineas { get; set; }
    }

}
