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


    /// <summary>
    /// Lo que devuelve un login correcto (HU-001).
    ///
    /// SIN [Serializable], y no es un olvido. Con ese atributo, Json.NET
    /// serializa los *backing fields* de las propiedades automáticas y la
    /// respuesta sale con claves como "&lt;token&gt;k__BackingField" en vez de
    /// "token": el cliente no puede leer el token por su nombre y el login
    /// queda inutilizable pese al 200. Se detectó probando HU-001 el
    /// 01-09-2026 y se corrigió el 04-09-2026.
    ///
    /// Ningún otro DTO de este archivo lo lleva. No agregarlo.
    /// </summary>
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

        /// <summary>
        /// La ruta de blob del logo de la empresa, para la pantalla de
        /// contexto. Viaja en la misma consulta y no en una aparte: pedirlo
        /// despues haria que los logos aparecieran saltando sobre unas
        /// tarjetas ya dibujadas.
        /// </summary>
        public string LOGO_RUTA { get; set; }
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


    /// <summary>
    /// La cabecera de un activo (HU-037).
    ///
    /// Existe porque `/activos/{id}/ficha` devuelve los EVENTOS, no el activo:
    /// la app llegaba a la pantalla de ficha sin nombre, tipo ni criticidad y
    /// tenia que recibirlos por parametro desde donde la abrieron. Detectado
    /// al conectar la app el 04-09-2026.
    /// </summary>
    public class ActivoDto
    {
        public int act_id { get; set; }
        public string act_codigo { get; set; }
        public string act_nombre { get; set; }
        public string act_numero_serie { get; set; }
        public string act_fabricante { get; set; }
        public int? act_anio_fabricacion { get; set; }
        public DateTime? act_fecha_puesta_marcha { get; set; }
        public string act_descripcion { get; set; }
        public bool act_habilitado { get; set; }

        public int act_cliente_instalacion { get; set; }
        public int? act_instalacion_area { get; set; }
        public int act_activo_tipo { get; set; }
        public int? act_activo_modelo { get; set; }
        public int act_activo_estado { get; set; }
        public int act_criticidad_nivel { get; set; }

        /* Resueltos por el SP. La app los muestra tal cual: hacer que el
           telefono cruce cinco catalogos para pintar una pantalla es trabajo
           que el servidor ya hizo. */
        public string PLANTA_NOMBRE { get; set; }
        public string AREA_NOMBRE { get; set; }
        public string TIPO_NOMBRE { get; set; }
        public string ESTADO_NOMBRE { get; set; }
        public string CRITICIDAD_NOMBRE { get; set; }
        public string CENTRO_COSTO_NOMBRE { get; set; }
        public string PADRE_CODIGO { get; set; }
        public string PADRE_NOMBRE { get; set; }

        /* LAS FOTOS VAN COMO RUTA DE BLOB, NO COMO ID NI COMO BYTES

           La web resuelve un archivo por su id contra VerArchivo.aspx; la app
           no tiene esa pagina y pide el binario por ruta
           (GET /archivo/ver?ruta=). Sin estos dos campos el telefono no sabia
           donde estaba la foto y dibujaba el marcador de "sin imagen" en
           activos que si la tienen.

           Y van rutas y no bytes: una ficha con la foto incrustada en base64
           pesa lo mismo con o sin senal, y en una planta se abre la ficha
           mucho mas seguido de lo que cambia la foto. */
        public string FOTO_RUTA { get; set; }
        public List<string> FOTOS { get; set; }
    }

    /// <summary>
    /// El token FCM de un dispositivo (HU-077).
    ///
    /// `token` identifica al TELEFONO, no a la persona. Si el tecnico y el
    /// supervisor usan el mismo aparato, el token pasa del uno al otro — por
    /// eso el UPS reasigna en vez de duplicar. Sin eso, el segundo en entrar
    /// recibiria las alertas del primero.
    /// </summary>
    public class DispositivoDto
    {
        public string token { get; set; }
        public string dispositivo { get; set; }
        public string app_version { get; set; }
        public string plataforma { get; set; }
    }

    /// <summary>
    /// Una foto de un activo, tal como la devuelve `API_SEL_ACTIVO_FOTO`.
    ///
    /// Es interno del controller: lo que sale al cliente son las rutas dentro
    /// de `ActivoDto`. Publicar el mime y el nombre original del archivo no le
    /// sirve a la app —que solo va a pedir el binario— y expone como se llama
    /// el archivo que subió alguien.
    /// </summary>
    public class ActivoFotoDto
    {
        public string ARC_RUTA { get; set; }
        public string ARC_MIME { get; set; }
        public string ARC_NOMBRE { get; set; }
        public bool ES_PORTADA { get; set; }
    }

    /// <summary>Un tramo de trabajo. Append-only: la tabla no tiene baja logica.</summary>
    public class ManoObraDto
    {
        public int omo_id { get; set; }
        public int? USUARIO_ID { get; set; }
        public string USUARIO_NOMBRE { get; set; }
        public string ESPECIALIDAD_NOMBRE { get; set; }
        public string PROVEEDOR_NOMBRE { get; set; }
        public DateTime omo_fecha_inicio_utc { get; set; }
        public DateTime? omo_fecha_fin_utc { get; set; }
        public int omo_minuto { get; set; }
        public bool omo_es_hora_extra { get; set; }
        public string omo_observacion { get; set; }

        /// <summary>INTERNA o EXTERNA. Lo decide de donde viene la persona.</summary>
        public string ORIGEN { get; set; }
    }

    public class ManoObraAltaDto
    {
        public DateTime fecha_inicio_utc { get; set; }
        public DateTime? fecha_fin_utc { get; set; }

        /// <summary>Alternativa a la hora de termino, para registrar a mano.</summary>
        public int? minutos { get; set; }

        public int? especialidad { get; set; }
        public bool es_hora_extra { get; set; }
        public string observacion { get; set; }

        /// <summary>De quien es el tramo. Nulo = de quien lo registra.</summary>
        public int? usuario_tramo { get; set; }
    }

    public class OrdenTrabajoRepuestoDto
    {
        public int ore_id { get; set; }
        public int REPUESTO_ID { get; set; }
        public string REPUESTO_CODIGO { get; set; }
        public string REPUESTO_NOMBRE { get; set; }
        public string UNIDAD_SIMBOLO { get; set; }
        public string LOTE_CODIGO { get; set; }
        public decimal? ore_cantidad_planificada { get; set; }
        public decimal? ore_cantidad_reservada { get; set; }
        public decimal? ore_cantidad_consumida { get; set; }
        public decimal? ore_cantidad_devuelta { get; set; }
        public decimal? ore_costo_unitario { get; set; }
        public string ore_observacion { get; set; }
    }

    public class OrdenTrabajoRepuestoAltaDto
    {
        public int repuesto { get; set; }
        public int bodega { get; set; }
        public decimal cantidad { get; set; }

        /// <summary>
        /// Obligatoria cuando la bodega tiene ubicaciones: sin decir de que
        /// estante sale, el saldo por ubicacion queda sin dueno y nadie puede
        /// ir a buscar el repuesto.
        /// </summary>
        public int? ubicacion { get; set; }

        public int? lote { get; set; }

        /// <summary>Invierte el gesto: lo que sobro vuelve al estante.</summary>
        public bool es_devolucion { get; set; }

        public string observacion { get; set; }
        public Guid? uuid { get; set; }
    }

    /// <summary>Mano de obra y repuestos juntos: en la ficha se miran juntos.</summary>
    public class RecursosDto
    {
        public List<ManoObraDto> mano_obra { get; set; }
        public List<OrdenTrabajoRepuestoDto> repuestos { get; set; }
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


    /// <summary>Solicitud de cambio de estado de un activo (HU-038).</summary>
    public class ActivoEstadoAltaDto
    {
        public int activo { get; set; }
        public int estado { get; set; }
        public string motivo { get; set; }
        public int? orden_trabajo { get; set; }
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
    /// <summary>
    /// La lectura de un medidor tomada en terreno (HU-043).
    ///
    /// `fecha_lectura_utc` la manda la app y es la de CAPTURA, no la del
    /// envio: una lectura tomada a las 09:00 y enviada a las 18:00 es de las
    /// 09:00. Sin ella, todo lo capturado sin señal quedaria fechado en el
    /// momento en que volvio la cobertura.
    ///
    /// `uuid` lo genera el telefono AL ENCOLAR. Es lo que hace que un
    /// reintento por timeout no grabe la lectura dos veces.
    /// </summary>
    public class LecturaAltaDto
    {
        public int activo_medidor { get; set; }
        public decimal valor { get; set; }
        public DateTime? fecha_lectura_utc { get; set; }

        /// <summary>
        /// El medidor se puso en cero. Hay que declararlo: sin esta marca, un
        /// valor menor que el anterior se rechaza — o el medidor se reinicio,
        /// o alguien tecleo mal, y el servidor no puede adivinar cual.
        /// </summary>
        public bool es_reinicio { get; set; }

        public int? orden_trabajo { get; set; }
        public string observacion { get; set; }

        /// <summary>Teclado, voz, escaneo. Por omision, teclado.</summary>
        public int? entrada_modo { get; set; }

        public Guid? uuid { get; set; }
    }

    /// <summary>Una medicion de condicion tomada en terreno (HU-044).</summary>
    public class MedicionAltaDto
    {
        public int activo_variable { get; set; }
        public decimal valor { get; set; }
        public DateTime? fecha_medicion_utc { get; set; }

        /// <summary>
        /// En que unidad se midio. Si no viene, es la de la variable: la que
        /// la pantalla mostro al lado del campo. El SP guarda ademas el valor
        /// convertido a la unidad base, para poder comparar series donde
        /// alguien midio en °C y otro en K.
        /// </summary>
        public int? unidad_medida { get; set; }

        public int? activo_componente { get; set; }
        public int? orden_trabajo { get; set; }
        public string observacion { get; set; }
        public int? entrada_modo { get; set; }
        public Guid? uuid { get; set; }
    }

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


    /* ================================================================
       PERMISOS DE TRABAJO                                      HU-063

       El papel que habilita una faena de riesgo. Se registra EN
       TERRENO, desde el teléfono, con la red de una planta.
       ================================================================ */

    /// <summary>
    /// Un permiso tal como lo lee la app.
    ///
    /// Los nombres coinciden con las columnas de SEL_PERMISO_TRABAJO:
    /// Datos.Listar mapea por nombre y una propiedad que no coincida
    /// queda en su valor por omisión, sin error.
    /// </summary>
    public class PermisoTrabajoDto
    {
        public int ptr_id { get; set; }
        public Guid? ptr_uuid { get; set; }
        public int? ptr_orden_trabajo { get; set; }
        public int ptr_permiso_trabajo_tipo { get; set; }
        public int ptr_permiso_trabajo_estado { get; set; }
        public string ptr_numero { get; set; }
        public int? ptr_usuario_solicitante { get; set; }
        public DateTime? ptr_fecha_solicitud_utc { get; set; }
        public DateTime? ptr_fecha_vigencia_inicio_utc { get; set; }
        public DateTime? ptr_fecha_vigencia_fin_utc { get; set; }
        public string ptr_observacion { get; set; }
        public int? ptr_archivo { get; set; }
        public bool ptr_habilitado { get; set; }

        public string TIPO_NOMBRE { get; set; }
        public string TIPO_CODIGO { get; set; }
        public string ESTADO_NOMBRE { get; set; }
        public string ESTADO_CODIGO { get; set; }
        public string SOLICITANTE_NOMBRE { get; set; }
        public string ORDEN_CORRELATIVO { get; set; }
        public string ORDEN_TITULO { get; set; }
        public string ARCHIVO_NOMBRE { get; set; }
        public long ARCHIVO_BYTE { get; set; }

        /// <summary>Negativo = ya venció. Null = sin fin declarado.</summary>
        public int? DIAS_RESTANTES { get; set; }

        /// <summary>
        /// VIGENTE · POR VENCER · VENCIDO · CERRADO · SIN VIGENCIA.
        ///
        /// La calcula el SP contra la fecha de hoy y NO se guarda: un
        /// estado guardado envejece solo, y un permiso que venció
        /// anoche seguiría diciendo AUTORIZADO hasta que alguien
        /// corriera un proceso.
        /// </summary>
        public string SITUACION { get; set; }
    }


    /// <summary>
    /// Lo que la app manda para registrar un permiso.
    ///
    /// EL uuid LO GENERA EL TELEFONO, NO EL SERVIDOR
    ///   Es lo que hace idempotente el alta: la app manda, se corta la
    ///   red, no sabe si llegó, y reintenta con el MISMO uuid. El SP
    ///   devuelve el id que ya existía en vez de crear un segundo
    ///   permiso para la misma faena.
    /// </summary>
    public class PermisoTrabajoAltaDto
    {
        public int tipo { get; set; }
        public int? estado { get; set; }
        public string numero { get; set; }
        public int? orden_trabajo { get; set; }
        public int? solicitante { get; set; }
        public DateTime? vigencia_inicio { get; set; }
        public DateTime? vigencia_fin { get; set; }
        public string observacion { get; set; }
        public int? archivo { get; set; }
        public Guid? uuid { get; set; }
    }


    /// <summary>
    /// Un tipo de permiso, para el formulario de la app.
    ///
    /// Los nombres son los de SEL_PERMISO_TRABAJO_TIPO: Datos.Listar mapea
    /// por nombre de columna, y una propiedad que no coincida queda en su
    /// valor por omisión SIN dar error. Renombrarlos a algo más bonito
    /// dejaría una lista de ceros y cadenas vacías que parece un problema
    /// de datos.
    /// </summary>
    public class PermisoTrabajoTipoDto
    {
        public int PTT_ID { get; set; }
        public string PTT_CODIGO { get; set; }
        public string PTT_NOMBRE { get; set; }
        public int PTT_ORDEN { get; set; }
    }


    /// <summary>Un estado de permiso, para el formulario de la app.</summary>
    public class PermisoTrabajoEstadoDto
    {
        public int PTE_ID { get; set; }
        public string PTE_CODIGO { get; set; }
        public string PTE_NOMBRE { get; set; }
        public int PTE_ORDEN { get; set; }
    }


    /// <summary>
    /// Un permiso en la pantalla de alerta: lo que está vigente y lo que
    /// está por vencer.                                            HU-064
    ///
    /// TRAE MENOS QUE EL DETALLE, A PROPOSITO
    ///   Esta consulta es para mirar de un vistazo antes de empezar a
    ///   trabajar, no para abrir cada fila. Traer las 32 columnas del
    ///   detalle para pintar seis es pagar el viaje completo por cada
    ///   permiso de la planta, en un teléfono y con la red de una faena.
    /// </summary>
    public class PermisoVigenteDto
    {
        public int ptr_id { get; set; }
        public int ptr_permiso_trabajo_tipo { get; set; }
        public string ptr_numero { get; set; }
        public DateTime? ptr_fecha_vigencia_inicio_utc { get; set; }
        public DateTime? ptr_fecha_vigencia_fin_utc { get; set; }
        public int? ptr_archivo { get; set; }

        public string TIPO_NOMBRE { get; set; }
        public string ESTADO_NOMBRE { get; set; }
        public string ESTADO_CODIGO { get; set; }
        public string SOLICITANTE_NOMBRE { get; set; }
        public string ORDEN_CORRELATIVO { get; set; }

        /// <summary>
        /// Si tiene el documento firmado. Un permiso vigente SIN documento
        /// no acredita nada, y en terreno eso importa tanto como la fecha.
        /// </summary>
        public bool TIENE_DOCUMENTO { get; set; }

        /// <summary>Negativo = ya venció. Null = sin fin declarado.</summary>
        public int? DIAS_RESTANTES { get; set; }

        /// <summary>VIGENTE · POR VENCER · VENCIDO.</summary>
        public string SITUACION { get; set; }
    }

    /// <summary>
    /// Una alerta que el sistema detecto solo (HU-077).
    ///
    /// LA APP RECIBE LO MISMO QUE LA WEB
    ///   Es el mismo SEL_ALERTA. Un SP aparte "para movil" seria el lugar
    ///   donde algun dia una alerta aparece en un lado y en el otro no.
    ///
    /// LEIDA VIENE COMO INT DEL SP
    ///   El SP la calcula con un COUNT y no con un BIT. Se expone como bool
    ///   porque para quien consume la API es un si o un no, pero la
    ///   conversion se hace explicita: un bool.Parse sobre "0" revienta.
    /// </summary>
    public class AlertaDto
    {
        public int ale_id { get; set; }
        public string ale_titulo { get; set; }
        public string ale_descripcion { get; set; }
        public DateTime ale_fecha_deteccion_utc { get; set; }

        public string alt_codigo { get; set; }
        public string alt_nombre { get; set; }
        public string alt_icono { get; set; }

        /// <summary>A donde lleva el toque en la app.</summary>
        public string FICHA_LINK { get; set; }
        public int FICHA_ID { get; set; }

        public string aet_codigo { get; set; }
        public string aet_nombre { get; set; }
        public string sev_codigo { get; set; }
        public string sev_nombre { get; set; }

        public int? ale_repuesto { get; set; }
        public int? ale_bodega { get; set; }
        public int? ale_repuesto_lote { get; set; }
        public decimal? ale_valor_observado { get; set; }
        public decimal? ale_valor_umbral { get; set; }

        public int LEIDA { get; set; }

        /// <summary>Cuanto lleva abierta. La app la ordena por esto.</summary>
        public int MINUTOS { get; set; }
    }

    /// <summary>
    /// El contador de la campanita (HU-077). Dos numeros y nada mas: la app
    /// lo pide seguido y traer la lista completa para contar seria gastar
    /// datos del telefono en cada refresco.
    /// </summary>
    public class AlertaResumenDto
    {
        public int ABIERTAS { get; set; }
        public int NO_LEIDAS { get; set; }
    }


    // =======================================================================
    //  BITACORA DE PLANTA                                  HU-130 y HU-131
    // =======================================================================

    /// <summary>
    /// Una entrada en la linea de tiempo.
    ///
    /// Trae `bit_texto` -lo que se escribio- y `TEXTO_VIGENTE` -lo que vale
    /// hoy, si hubo rectificaciones-. Los dos, siempre: el original no se pisa
    /// nunca y la pantalla tiene que poder mostrarlo.
    /// </summary>
    public class BitacoraEntradaDto
    {
        public int bit_id { get; set; }
        public Guid bit_uuid { get; set; }
        public string bit_titulo { get; set; }

        /// <summary>Lo que se escribio la primera vez. No cambia jamas.</summary>
        public string bit_texto { get; set; }

        /// <summary>Lo que vale hoy: la ultima rectificacion, o el original.</summary>
        public string TEXTO_VIGENTE { get; set; }

        public DateTime bit_fecha_evento_utc { get; set; }
        public string bit_turno { get; set; }
        public bool bit_requiere_atencion { get; set; }
        public bool bit_offline_creado { get; set; }
        public int TIPO_ID { get; set; }
        public string TIPO_CODIGO { get; set; }
        public string TIPO_NOMBRE { get; set; }
        public int? SEVERIDAD_ID { get; set; }
        public string SEVERIDAD_CODIGO { get; set; }
        public string SEVERIDAD_NOMBRE { get; set; }
        public int? ACTIVO_ID { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public string AREA_NOMBRE { get; set; }
        public string INSTALACION_NOMBRE { get; set; }
        public int? ORDEN_TRABAJO_ID { get; set; }
        public int? ORDEN_CORRELATIVO { get; set; }
        public int USUARIO_ID { get; set; }
        public string USUARIO_NOMBRE { get; set; }
        public DateTime bit_fecha_creacion { get; set; }
        public bool POR_VOZ { get; set; }
        public int COMENTARIOS { get; set; }

        /// <summary>Cuantas veces se corrigio. La pantalla lo usa para marcar
        /// «rectificada» sin pedir la lista completa.</summary>
        public int RECTIFICACIONES { get; set; }

        public int EVIDENCIAS { get; set; }

        /// <summary>Del `COUNT(*) OVER ()` del SP: el total sin paginar.</summary>
        public int TOTAL { get; set; }
    }

    public class BitacoraFichaDto
    {
        public int bit_id { get; set; }
        public Guid bit_uuid { get; set; }
        public string bit_titulo { get; set; }

        /// <summary>Lo que se escribio la primera vez. La pantalla lo muestra
        /// siempre, aunque haya rectificaciones encima.</summary>
        public string TEXTO_ORIGINAL { get; set; }

        public string TEXTO_VIGENTE { get; set; }
        public DateTime bit_fecha_evento_utc { get; set; }
        public string bit_turno { get; set; }
        public bool bit_requiere_atencion { get; set; }
        public bool bit_offline_creado { get; set; }
        public DateTime? bit_fecha_sincronizacion_utc { get; set; }
        public int TIPO_ID { get; set; }
        public string TIPO_CODIGO { get; set; }
        public string TIPO_NOMBRE { get; set; }
        public int? SEVERIDAD_ID { get; set; }
        public string SEVERIDAD_NOMBRE { get; set; }
        public int? ACTIVO_ID { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public string AREA_NOMBRE { get; set; }
        public string INSTALACION_NOMBRE { get; set; }
        public int? ORDEN_TRABAJO_ID { get; set; }
        public int? ORDEN_CORRELATIVO { get; set; }
        public int? ALERTA_ID { get; set; }
        public int USUARIO_ID { get; set; }
        public string USUARIO_NOMBRE { get; set; }
        public DateTime bit_fecha_creacion { get; set; }

        public bool POR_VOZ { get; set; }
        public string TEXTO_DICTADO { get; set; }
        public decimal? DICTADO_CONFIANZA { get; set; }
        public bool DICTADO_CORREGIDO { get; set; }
        public int EVIDENCIAS { get; set; }

        public List<BitacoraComentarioDto> comentarios { get; set; }
        public List<BitacoraRectificacionDto> rectificaciones { get; set; }
    }

    /// <summary>
    /// Una correccion. NO reemplaza al original: se apila encima.
    /// `bre_motivo` es obligatorio y por eso viene siempre.
    /// </summary>
    public class BitacoraRectificacionDto
    {
        public int bre_id { get; set; }
        public string bre_texto_rectificado { get; set; }
        public string bre_motivo { get; set; }
        public int USUARIO_ID { get; set; }
        public string USUARIO_NOMBRE { get; set; }
        public DateTime bre_fecha_creacion { get; set; }
    }

    public class BitacoraComentarioDto
    {
        public int bco_id { get; set; }
        public int? PADRE_ID { get; set; }
        public string bco_texto { get; set; }
        public bool POR_VOZ { get; set; }
        public string TEXTO_DICTADO { get; set; }
        public bool DICTADO_CORREGIDO { get; set; }
        public int USUARIO_ID { get; set; }
        public string USUARIO_NOMBRE { get; set; }
        public DateTime bco_fecha_creacion { get; set; }
    }

    public class BitacoraTipoDto
    {
        public int bti_id { get; set; }
        public string bti_codigo { get; set; }
        public string bti_nombre { get; set; }
        public string bti_icono { get; set; }
        public int? bti_orden { get; set; }
    }

    public class BitacoraAltaDto
    {
        /// <summary>Generado al **empezar a escribir**, no al enviar: un
        /// reintento de la cola no puede dejar el turno contado dos veces.</summary>
        public Guid uuid { get; set; }

        public int instalacion { get; set; }
        public int tipo { get; set; }
        public string texto { get; set; }
        public string titulo { get; set; }
        public int? area { get; set; }
        public int? activo { get; set; }
        public int? componente { get; set; }
        public int? orden_trabajo { get; set; }

        /// <summary>Cuando paso, no cuando se envio. Una entrada escrita sin
        /// senal a las tres de la manana pertenece a la noche.</summary>
        public DateTime? fecha_evento { get; set; }

        public string turno { get; set; }
        public bool requiere_atencion { get; set; }

        /// <summary>Obligatoria si el tipo es INCIDENTE: sin ella el turno
        /// siguiente no puede saber que mirar primero.</summary>
        public int? severidad { get; set; }

        public decimal? latitud { get; set; }
        public decimal? longitud { get; set; }
        public bool offline { get; set; }

        public Guid? dictado_uuid { get; set; }
        public string texto_dictado { get; set; }
        public decimal? dictado_confianza { get; set; }
        public int? dictado_segundos { get; set; }
        public Guid? dispositivo { get; set; }
    }

    public class BitacoraRectificacionAltaDto
    {
        public string texto { get; set; }

        /// <summary>Obligatorio. Sin el, nadie puede saber despues si el texto
        /// cambio porque estaba mal escrito, porque se supo algo nuevo, o
        /// porque a alguien no le gusto como sonaba.</summary>
        public string motivo { get; set; }
    }

    public class BitacoraComentarioAltaDto
    {
        public string texto { get; set; }
        public int? padre { get; set; }
        public Guid? dictado_uuid { get; set; }
        public string texto_dictado { get; set; }
        public decimal? dictado_confianza { get; set; }
        public int? dictado_segundos { get; set; }
        public Guid? dispositivo { get; set; }
    }

    // =====================================================================
    // ORDENES DE TRABAJO (HU-110, HU-113, HU-114, HU-119, HU-121)
    // =====================================================================

    /// <summary>
    /// Una orden en la bandeja o en la ficha.
    ///
    /// SITUACION Y PASOS VIENEN CALCULADOS
    ///   El SP resuelve VENCIDA / VENCE HOY / EN PLAZO y cuenta los pasos
    ///   listos. El telefono no resta fechas ni cuenta filas: si lo hiciera,
    ///   dos aparatos con distinta hora darian veredictos distintos sobre la
    ///   misma orden.
    /// </summary>
    public class OrdenTrabajoDto
    {
        public int otr_id { get; set; }
        public Guid otr_uuid { get; set; }
        public int otr_correlativo { get; set; }

        /// <summary>"OT-1176". Lo arma el SP para que web y app lo escriban igual.</summary>
        public string OT_NUMERO { get; set; }

        public string otr_titulo { get; set; }
        public string otr_descripcion { get; set; }
        public string otr_notas { get; set; }
        public string otr_resultado { get; set; }

        public DateTime? otr_fecha_evento_utc { get; set; }
        public DateTime? otr_fecha_programada_utc { get; set; }
        public DateTime? otr_fecha_inicio_real_utc { get; set; }
        public DateTime? otr_fecha_fin_real_utc { get; set; }
        public int? otr_duracion_estimada_minuto { get; set; }
        public int? otr_duracion_real_minuto { get; set; }
        public bool otr_requiere_permiso { get; set; }

        public int ESTADO_ID { get; set; }
        public string ESTADO_CODIGO { get; set; }
        public string ESTADO_NOMBRE { get; set; }
        public int PRIORIDAD_ID { get; set; }
        public string PRIORIDAD_CODIGO { get; set; }
        public string PRIORIDAD_NOMBRE { get; set; }
        public string TIPO_NOMBRE { get; set; }
        public string ESTRATEGIA_NOMBRE { get; set; }

        public int? ACTIVO_ID { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public string PLANTA_NOMBRE { get; set; }
        public string AREA_NOMBRE { get; set; }

        public int? RESPONSABLE_ID { get; set; }
        public string RESPONSABLE_NOMBRE { get; set; }

        public int PASOS_TOTAL { get; set; }
        public int PASOS_LISTOS { get; set; }

        /// <summary>VENCIDA, VENCE HOY, EN PLAZO o SIN PLAZO. Lo decide el SP.</summary>
        public string SITUACION { get; set; }
        public int? DIAS_RESTANTES { get; set; }

        public bool ES_MIA { get; set; }
        public string PERMISO_NUMERO { get; set; }
        public DateTime? otr_fecha_actualizacion { get; set; }
    }

    /// <summary>Un paso de la orden. El resultado sale del catalogo Resultado_Paso.</summary>
    public class OrdenTrabajoPasoDto
    {
        public int otp_id { get; set; }
        public int otp_orden_trabajo { get; set; }
        public int otp_orden { get; set; }
        public string otp_nombre { get; set; }
        public string otp_descripcion { get; set; }
        public bool otp_obligatorio { get; set; }

        /// <summary>1 CONFORME, 2 NO CONFORME, 3 NO APLICA, 4 PENDIENTE.</summary>
        public int RESULTADO_ID { get; set; }
        public string RESULTADO_CODIGO { get; set; }
        public string RESULTADO_NOMBRE { get; set; }

        public string OBSERVACION { get; set; }
        public int? EJECUTOR_ID { get; set; }
        public string EJECUTOR_NOMBRE { get; set; }
        public DateTime? otp_fecha_ejecucion_utc { get; set; }
    }

    public class OrdenTrabajoAsignadoDto
    {
        public int ota_id { get; set; }
        public int? USUARIO_ID { get; set; }
        public string USUARIO_NOMBRE { get; set; }
        public bool ota_es_responsable { get; set; }
        public string ROL_NOMBRE { get; set; }
        public DateTime? ota_fecha_asignacion_utc { get; set; }
        public DateTime? ota_fecha_aceptacion_utc { get; set; }
    }

    /// <summary>
    /// La ficha completa en UNA respuesta.
    ///
    /// Cabecera, pasos y asignados juntos: son tres consultas para el servidor
    /// y un solo viaje de red para el telefono, que es lo que importa con
    /// senal de bodega.
    /// </summary>
    public class OrdenTrabajoFichaDto
    {
        public OrdenTrabajoDto orden { get; set; }
        public List<OrdenTrabajoPasoDto> pasos { get; set; }
        public List<OrdenTrabajoAsignadoDto> asignados { get; set; }
    }

    /// <summary>El alta desde terreno. Idempotente por uuid.</summary>
    public class OrdenTrabajoAltaDto
    {
        /// <summary>
        /// Lo genera el telefono AL ENCOLAR, no al enviar. Generado al enviar,
        /// cada reintento traeria uno nuevo y la idempotencia no serviria.
        /// </summary>
        public Guid uuid { get; set; }

        public int instalacion { get; set; }
        public string titulo { get; set; }
        public string descripcion { get; set; }
        public int? activo { get; set; }
        public int? area { get; set; }

        /// <summary>1 PREVENTIVA, 2 CORRECTIVA, 3 PREDICTIVA.</summary>
        public int? tipo { get; set; }
        public int? estrategia { get; set; }

        /// <summary>1 BAJA, 2 MEDIA, 3 ALTA, 4 CRITICA.</summary>
        public int? prioridad { get; set; }

        /// <summary>
        /// Cuando ocurrio de verdad, no cuando se registro. Una OT abierta
        /// tres horas despues de la falla no puede mentir sobre cuando paro
        /// la maquina.
        /// </summary>
        public DateTime? fecha_evento_utc { get; set; }

        public bool requiere_permiso { get; set; }

        /// <summary>Un paso por linea. Entran en la misma transaccion que la OT.</summary>
        public string pasos { get; set; }

        public int? entrada_modo { get; set; }
    }

    /// <summary>El resultado de un paso.</summary>
    public class PasoResultadoDto
    {
        /// <summary>1 CONFORME, 2 NO CONFORME, 3 NO APLICA.</summary>
        public int resultado { get; set; }

        public string observacion { get; set; }
        public int? entrada_modo { get; set; }
    }

    public class OrdenTrabajoFinDto
    {
        public string resultado { get; set; }
    }

    // =====================================================================
    // CHECKLIST EN TERRENO (HU-095)
    // =====================================================================

    /// <summary>Una pauta pendiente en la bandeja del tecnico.</summary>
    public class ChecklistPendienteDto
    {
        public int coc_id { get; set; }
        public Guid coc_uuid { get; set; }
        public int VERSION_ID { get; set; }
        public int VERSION_NUMERO { get; set; }
        public string PLANTILLA_CODIGO { get; set; }
        public string PLANTILLA_NOMBRE { get; set; }
        public string PLANTILLA_DESCRIPCION { get; set; }
        public int? ACTIVO_ID { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public string AREA_NOMBRE { get; set; }
        public int ESTADO_ID { get; set; }
        public string ESTADO_NOMBRE { get; set; }
        public DateTime? coc_fecha_programada_utc { get; set; }
        public DateTime? coc_fecha_limite_utc { get; set; }

        /// <summary>VENCIDA, VENCE HOY, EN PLAZO o SIN PLAZO. Lo decide el SP.</summary>
        public string SITUACION { get; set; }

        public int ITEM_TOTAL { get; set; }

        /// <summary>
        /// Si ya hay un borrador de esta persona, la app lo RETOMA en vez de
        /// empezar otro: una pauta a medias que se rehace pierde lo caminado.
        /// </summary>
        public int? EJECUCION_BORRADOR { get; set; }
    }

    public class ChecklistItemDto
    {
        public int cpi_id { get; set; }
        public string cpi_codigo { get; set; }
        public string cpi_texto { get; set; }
        public string cpi_ayuda { get; set; }
        public int cpi_orden { get; set; }
        public bool cpi_obligatorio { get; set; }
        public bool cpi_permite_comentario { get; set; }
        public bool cpi_requiere_evidencia { get; set; }
        public bool cpi_genera_medicion { get; set; }

        /// <summary>Como se lee la pregunta en voz alta (seccion 2 del kit).</summary>
        public string cpi_pregunta_voz { get; set; }

        public int TIPO_ID { get; set; }
        public string TIPO_CODIGO { get; set; }
        public string TIPO_NOMBRE { get; set; }
        public string UNIDAD_SIMBOLO { get; set; }
        public int? SECCION_ID { get; set; }
        public string SECCION_NOMBRE { get; set; }
        public int? SECCION_ORDEN { get; set; }

        /// <summary>
        /// El rango viaja con el item para que la app avise EN EL MOMENTO,
        /// aunque el veredicto que queda grabado lo ponga el servidor.
        /// </summary>
        public decimal? civ_valor_minimo { get; set; }
        public decimal? civ_valor_maximo { get; set; }
        public string civ_mensaje { get; set; }
        public bool? civ_requiere_comentario_fuera_rango { get; set; }
        public bool? civ_genera_hallazgo { get; set; }
    }

    public class ChecklistOpcionDto
    {
        public int cio_id { get; set; }
        public int ITEM_ID { get; set; }
        public string cio_codigo { get; set; }
        public string cio_texto { get; set; }
        public decimal? cio_valor { get; set; }
        public int cio_orden { get; set; }

        /// <summary>
        /// Aqui vive el significado: a «¿Hay fugas?» la conforme es NO, a
        /// «¿Opera sin ruidos?» es SI. No se puede adivinar del valor.
        /// </summary>
        public bool cio_es_conforme { get; set; }

        public bool cio_requiere_comentario { get; set; }
    }

    public class ChecklistPlantillaDto
    {
        public List<ChecklistItemDto> items { get; set; }
        public List<ChecklistOpcionDto> opciones { get; set; }
    }

    public class ChecklistEjecucionDto
    {
        public int cej_id { get; set; }
        public Guid cej_uuid { get; set; }
        public int? OCURRENCIA_ID { get; set; }
        public int VERSION_ID { get; set; }
        public string PLANTILLA_NOMBRE { get; set; }
        public int? ACTIVO_ID { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public int ESTADO_ID { get; set; }
        public string ESTADO_NOMBRE { get; set; }
        public DateTime cej_fecha_inicio_utc { get; set; }
        public DateTime? cej_fecha_fin_utc { get; set; }
        public int? cej_duracion_minuto { get; set; }
        public int? cej_item_total { get; set; }
        public int? cej_item_respondido { get; set; }
        public int? cej_item_no_conforme { get; set; }
        public string cej_observacion { get; set; }
        public bool cej_offline_creado { get; set; }

        public List<ChecklistRespuestaDto> respuestas { get; set; }
    }

    public class ChecklistRespuestaDto
    {
        public int cer_id { get; set; }
        public int ITEM_ID { get; set; }
        public string cer_valor_texto { get; set; }
        public decimal? cer_valor_numero { get; set; }
        public bool? cer_valor_booleano { get; set; }
        public DateTime? cer_valor_fecha { get; set; }
        public bool cer_fuera_rango { get; set; }
        public bool cer_no_aplica { get; set; }
        public string cer_comentario { get; set; }
        public int? cer_entrada_modo { get; set; }
        public DateTime cer_fecha_respuesta_utc { get; set; }
    }

    public class ChecklistEjecucionAltaDto
    {
        /// <summary>Lo genera el telefono AL ENCOLAR, no al enviar.</summary>
        public Guid uuid { get; set; }

        public int? ocurrencia { get; set; }
        public int? version { get; set; }
        public int? activo { get; set; }
        public string dispositivo { get; set; }

        /// <summary>Si se abrio sin senal. Queda en cej_offline_creado.</summary>
        public bool offline { get; set; }
    }

    public class ChecklistRespuestaAltaDto
    {
        public int item { get; set; }
        public string valor_texto { get; set; }
        public decimal? valor_numero { get; set; }
        public bool? valor_booleano { get; set; }
        public DateTime? valor_fecha { get; set; }

        /// <summary>
        /// Cuenta como respuesta para poder cerrar: no todo item corresponde a
        /// todo equipo, y obligar a inventar un valor es peor.
        /// </summary>
        public bool no_aplica { get; set; }

        public string comentario { get; set; }
        public int? entrada_modo { get; set; }
    }

    public class ChecklistRespuestaResultadoDto
    {
        public int cer_id { get; set; }
        public bool fuera_rango { get; set; }
        public string mensaje { get; set; }
    }

    public class ChecklistCierreDto
    {
        public string observacion { get; set; }
    }


    // =======================================================================
    //  TAREAS EN TERRENO                                    HU-103 y HU-104
    // =======================================================================

    public class TareaPendienteDto
    {
        public int toc_id { get; set; }
        public Guid toc_uuid { get; set; }
        public int TAREA_ID { get; set; }
        public string TAREA_CODIGO { get; set; }
        public string tar_titulo { get; set; }
        public string tar_descripcion { get; set; }
        public int? tar_duracion_estimada_minuto { get; set; }
        public bool tar_requiere_evidencia { get; set; }
        public string PRIORIDAD_CODIGO { get; set; }
        public string PRIORIDAD_NOMBRE { get; set; }
        public int PRIORIDAD_ID { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public string AREA_NOMBRE { get; set; }
        public int ESTADO_ID { get; set; }
        public string ESTADO_CODIGO { get; set; }
        public string ESTADO_NOMBRE { get; set; }
        public DateTime? toc_fecha_programada_utc { get; set; }
        public DateTime? toc_fecha_limite_utc { get; set; }
        public int? ORDEN_TRABAJO_ID { get; set; }

        /// <summary>VENCIDA, VENCE HOY, EN PLAZO o SIN PLAZO. Lo decide el SP.</summary>
        public string SITUACION { get; set; }

        public int COMENTARIOS { get; set; }

        /// <summary>
        /// Si viene, esta persona dejo una ejecucion a medio hacer y hay que
        /// retomar **esa**, no abrir otra.
        /// </summary>
        public int? EJECUCION_ABIERTA { get; set; }
    }

    public class TareaDto
    {
        public int toc_id { get; set; }
        public string TAREA_CODIGO { get; set; }
        public string tar_titulo { get; set; }
        public string tar_descripcion { get; set; }
        public bool tar_requiere_evidencia { get; set; }
        public int? tar_duracion_estimada_minuto { get; set; }
        public string PRIORIDAD_NOMBRE { get; set; }
        public int PRIORIDAD_ID { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public string AREA_NOMBRE { get; set; }
        public int ESTADO_ID { get; set; }
        public string ESTADO_NOMBRE { get; set; }
        public DateTime? toc_fecha_limite_utc { get; set; }
        public string toc_observacion { get; set; }
        public int? EJECUCION_ID { get; set; }
        public DateTime? tej_fecha_inicio_utc { get; set; }
        public DateTime? tej_fecha_fin_utc { get; set; }
        public int? tej_duracion_minuto { get; set; }
        public string tej_resultado { get; set; }
        public bool? tej_conforme { get; set; }

        /// <summary>Cuantas fotos lleva. La app lo necesita para saber si
        /// puede ofrecer «Listo» o si todavia falta la evidencia.</summary>
        public int EVIDENCIAS { get; set; }

        public List<TareaComentarioDto> comentarios { get; set; }
    }

    /// <summary>
    /// Empezar y cerrar viajan en el mismo cuerpo. Son un solo acto en
    /// terreno: si fueran dos envios, la cola podria entregar el cierre antes
    /// que su apertura y eso no tiene arreglo.
    /// </summary>
    public class TareaEjecucionDto
    {
        public Guid uuid { get; set; }
        public int ocurrencia { get; set; }
        public bool finalizar { get; set; }

        /// <summary>Si es false, `resultado` es obligatorio: una tarea que no
        /// se hizo y no dice por que es indistinguible de una olvidada.</summary>
        public bool? conforme { get; set; }

        public string resultado { get; set; }
        public int? minutos { get; set; }
        public string dispositivo { get; set; }
        public bool offline { get; set; }
    }

    public class TareaEjecucionResultadoDto
    {
        public int tej_id { get; set; }

        /// <summary>El envio ya habia llegado. No es un error: es la cola
        /// reintentando, y la respuesta correcta es la misma de la vez que
        /// si llego.</summary>
        public bool YA_ESTABA { get; set; }
    }

    public class TareaComentarioDto
    {
        public int tco_id { get; set; }
        public int? PADRE_ID { get; set; }
        public string tco_texto { get; set; }
        public bool POR_VOZ { get; set; }

        /// <summary>Lo que entendio el telefono, antes de que la persona lo
        /// corrigiera. Vale la pena guardarlo: es la unica forma de saber si
        /// dictar sirve en una sala de maquinas.</summary>
        public string TEXTO_DICTADO { get; set; }

        public decimal? DICTADO_CONFIANZA { get; set; }
        public bool DICTADO_CORREGIDO { get; set; }
        public int USUARIO_ID { get; set; }
        public string USUARIO_NOMBRE { get; set; }
        public DateTime tco_fecha_creacion { get; set; }
    }

    public class TareaComentarioAltaDto
    {
        /// <summary>Lo que la persona dio por bueno.</summary>
        public string texto { get; set; }

        public int? padre { get; set; }

        /// <summary>Si vino de un dictado: el uuid lo genera el telefono al
        /// terminar de hablar, no al enviar.</summary>
        public Guid? dictado_uuid { get; set; }

        /// <summary>Lo crudo. Cuando no se corrigio nada es igual a `texto`, y
        /// esta bien que lo sea: importa poder ver cuando **no** lo fue.</summary>
        public string texto_dictado { get; set; }

        public decimal? dictado_confianza { get; set; }
        public int? dictado_segundos { get; set; }
        public int? dictado_intentos { get; set; }
        public Guid? dispositivo { get; set; }
    }


    // =======================================================================
    //  EVIDENCIA FOTOGRAFICA
    // =======================================================================

    /// <summary>
    /// Lo que manda el telefono al subir una foto.
    ///
    /// El `uuid` se genera al **sacar** la foto, no al enviarla: una foto
    /// tomada sin senal se reintenta varias veces, y sin esto la tarea
    /// quedaria con la misma foto cuatro veces.
    /// </summary>
    public class EvidenciaAltaDto
    {
        public Guid uuid { get; set; }

        /// <summary>TAREA · ORDEN · PASO · RESPUESTA · FALLA · HALLAZGO · ACTIVO</summary>
        public string destino { get; set; }

        public int destino_id { get; set; }

        /// <summary>De `Archivo_Categoria`. 5 = DURANTE, que es lo que saca
        /// alguien parado frente a la maquina.</summary>
        public int categoria { get; set; }

        public string nombre { get; set; }
        public string mime { get; set; }
        public string contenido_base64 { get; set; }
        public int? ancho { get; set; }
        public int? alto { get; set; }
        public decimal? latitud { get; set; }
        public decimal? longitud { get; set; }
        public DateTime? captura_utc { get; set; }
        public string dispositivo { get; set; }
        public string titulo { get; set; }
        public string descripcion { get; set; }
    }

    public class EvidenciaDto
    {
        public int arc_id { get; set; }
        public Guid arc_uuid { get; set; }

        /// <summary>La ruta del blob, no los bytes: el telefono pide cada
        /// imagen por `/archivo/ver` y la cachea.</summary>
        public string arc_ruta { get; set; }

        public string arc_nombre_original { get; set; }
        public string arc_mime { get; set; }
        public long arc_byte { get; set; }
        public int? arc_ancho_pixel { get; set; }
        public int? arc_alto_pixel { get; set; }
        public DateTime? arc_fecha_captura_utc { get; set; }
        public string CATEGORIA_CODIGO { get; set; }
        public string CATEGORIA_NOMBRE { get; set; }
        public int? avi_orden { get; set; }
        public string avi_titulo { get; set; }
        public string avi_descripcion { get; set; }
        public string USUARIO_NOMBRE { get; set; }
        public DateTime arc_fecha_creacion { get; set; }
    }


    // =======================================================================
    //  SIGMA AI                                            HU-173 y HU-175
    // =======================================================================

    /// <summary>
    /// Una prediccion vigente, como se ve en el panel.
    ///
    /// `pre_probabilidad` NO es «probabilidad de falla»: es la parte del
    /// intervalo de cruce que cae dentro del horizonte del modelo. El modelo no
    /// ha visto ninguna falla y no puede afirmar nada sobre fallas; lo que si
    /// puede es decir cuando una variable medida cruza un limite declarado, y
    /// con cuanta incertidumbre.
    /// </summary>
    public class PrediccionDto
    {
        public int pre_id { get; set; }
        public Guid pre_uuid { get; set; }
        public int ACTIVO_ID { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public string AREA_NOMBRE { get; set; }
        public string INSTALACION_NOMBRE { get; set; }

        /// <summary>Ruta del blob. La app la pide por `/archivo/ver` y la cachea.</summary>
        public string ACTIVO_FOTO { get; set; }

        public string VARIABLE_NOMBRE { get; set; }
        public string UNIDAD { get; set; }
        public decimal? VALOR_ACTUAL { get; set; }
        public decimal? VALOR_CRITICO { get; set; }
        public decimal? VALOR_ADVERTENCIA { get; set; }

        public int? pre_dia_restante { get; set; }
        public DateTime? pre_fecha_evento_estimada_utc { get; set; }
        public decimal? pre_probabilidad { get; set; }

        /// <summary>El R2 del ajuste. Que tan bien la recta describe las lecturas.</summary>
        public decimal? pre_confianza { get; set; }

        public decimal? DIA_MINIMO { get; set; }
        public decimal? DIA_MAXIMO { get; set; }
        public int? SEVERIDAD_ID { get; set; }
        public string SEVERIDAD_CODIGO { get; set; }
        public string SEVERIDAD_NOMBRE { get; set; }
        public int ESTADO_ID { get; set; }
        public string ESTADO_NOMBRE { get; set; }
        public DateTime pre_fecha_calculo_utc { get; set; }
        public string MODELO_NOMBRE { get; set; }
        public int? MODELO_VERSION { get; set; }

        /// <summary>Sin alerta la prediccion no se puede convertir en orden: no
        /// llego al umbral en que el modelo pide que se le crea.</summary>
        public int? ALERTA_ID { get; set; }

        public int? ORDEN_TRABAJO_ID { get; set; }
        public int? ORDEN_CORRELATIVO { get; set; }
    }

    public class PrediccionFichaDto : PrediccionDto
    {
        public string MODELO_DESCRIPCION { get; set; }
        public string MODELO_ALGORITMO { get; set; }
        public string MODELO_FORMATO { get; set; }
        public string MODELO_OBJETIVO { get; set; }
        public int? MODELO_HORIZONTE { get; set; }
        public DateTime? pre_fecha_vigencia_hasta_utc { get; set; }
        public string pre_motivo_descarte { get; set; }
        public string REVISADA_POR { get; set; }
        public DateTime? pre_fecha_revision_utc { get; set; }
        public int EVIDENCIAS { get; set; }

        public List<PrediccionRazonDto> razones { get; set; }
        public List<PrediccionDatoDto> datos { get; set; }
        public List<PrediccionPuntoDto> serie { get; set; }
    }

    /// <summary>
    /// Una de las tres razones. Cada una nombra el numero del que sale: una
    /// razon que no se puede verificar no ayuda a decidir si desarmar una
    /// maquina.
    /// </summary>
    public class PrediccionRazonDto
    {
        public int pex_orden { get; set; }
        public string pex_texto { get; set; }

        /// <summary>AUMENTA o DISMINUYE, cuando corresponde.</summary>
        public string pex_direccion { get; set; }

        public decimal? pex_valor_observado { get; set; }
        public decimal? pex_valor_referencia { get; set; }
        public string CARACTERISTICA { get; set; }
    }

    public class PrediccionDatoDto
    {
        public string cmo_codigo { get; set; }
        public string cmo_etiqueta { get; set; }
        public string cmo_descripcion { get; set; }
        public decimal? pcr_valor { get; set; }
        public string pcr_valor_texto { get; set; }

        /// <summary>El dato no se midio: se relleno. Se muestra distinto,
        /// porque una prediccion sobre datos imputados vale menos.</summary>
        public bool pcr_imputado { get; set; }
    }

    public class PrediccionPuntoDto
    {
        public DateTime FECHA { get; set; }
        public decimal VALOR { get; set; }
    }

    /// <summary>
    /// Un equipo vigilado que no produjo prediccion, y por que.
    ///
    /// SIN LECTURAS · FALTAN LECTURAS · SIN SENALES. El vacio es informacion:
    /// un panel sin nada no distingue «nadie mide este equipo» de «se mide y
    /// esta tranquilo», y son cosas muy distintas.
    /// </summary>
    public class VigiladoDto
    {
        public int ava_id { get; set; }
        public int ACTIVO_ID { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public string AREA_NOMBRE { get; set; }
        public string VARIABLE_NOMBRE { get; set; }
        public string UNIDAD { get; set; }
        public decimal? VALOR_ADVERTENCIA { get; set; }
        public decimal? VALOR_CRITICO { get; set; }
        public int? CADA_HORAS { get; set; }
        public int LECTURAS { get; set; }
        public DateTime? ULTIMA_UTC { get; set; }
        public decimal? ULTIMO_VALOR { get; set; }
        public int? HORAS_SIN_LECTURA { get; set; }

        /// <summary>Lleva mas tiempo sin medirse del que declara su frecuencia
        /// esperada. No esta vigilado: esta abandonado.</summary>
        public bool ATRASADA { get; set; }

        public string MOTIVO { get; set; }
    }

    public class PrediccionRevisionDto
    {
        public bool aceptar { get; set; }

        /// <summary>Obligatorio al descartar. Sin el, nadie puede aprender
        /// despues si el modelo se equivoco o si la decision fue otra.</summary>
        public string motivo { get; set; }
    }

    public class PrediccionRevisionResultadoDto
    {
        public int pre_id { get; set; }
        public bool YA_ESTABA { get; set; }
    }

}
