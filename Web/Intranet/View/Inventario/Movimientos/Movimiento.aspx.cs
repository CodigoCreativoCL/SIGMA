using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Registro de un movimiento de inventario
/// (HU-054 ingreso · HU-055 entrega y devolución · HU-057 ajuste).
///
/// UNA SOLA PANTALLA PARA LAS TRES HISTORIAS
///   Del lado de la base son el mismo procedimiento con distinto tipo.
///   Tres pantallas casi iguales serían tres sitios donde arreglar el mismo
///   error, y el bodeguero tendría que saber de antemano en cuál entra.
///
/// LA PANTALLA MENTIA SOBRE LA EXISTENCIA (corregido, bloque 87)
///   Mostraba "Existencia actual: 340,00 L" —el total de la BODEGA— y
///   después INS_INVENTARIO_MOVIMIENTO validaba contra el CUBO
///   (bodega, ubicación, lote), que tenía 0. Las dos cifras eran ciertas y
///   se contradecían, así que el rechazo parecía un error del sistema.
///
///   Ahora en una salida no se eligen ubicación y lote por separado: se
///   elige EL CUBO, de una lista que solo trae los que tienen existencia,
///   con la cantidad al lado. Es la misma llave contra la que el SP valida,
///   así que lo que se ve y lo que se comprueba son lo mismo.
///
/// EL FORMULARIO SIGUE UN ORDEN
///   Qué se hace → qué repuesto → de dónde sale → cuánto → contra qué
///   orden → por qué. Cada paso decide qué muestra el siguiente.
///
/// CON Id > 0 ES SOLO LECTURA
///   Un movimiento no se edita: es el registro de algo que pasó.
/// </summary>
public partial class View_Inventario_Movimientos_Movimiento : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        /* Querystring.Entero recibe el valor TAL COMO VIENE de la URL:
           descifra por dentro. Pasarle el resultado de Descifrar lo hace
           descifrar dos veces, la segunda falla, y como el helper no lanza
           devuelve 0 en silencio: la ficha se abre en blanco como si fuera
           un registro nuevo. */
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");

        /* El puente del escaneo: la cámara escribe el código leído en el
           campo oculto y dispara el botón oculto. Es el mismo mecanismo de
           Escanear.aspx, y se registra en cada carga porque el UpdatePanel
           regenera el script del cliente. */
        string enlace = "sigmaEscaneo.idCampo = '" + hdnLeido.ClientID + "';" +
                        "sigmaEscaneo.idBoton = '" + btnLeido.ClientID + "';";

        ScriptManager.RegisterStartupScript(this, GetType(), "escaneo-enlace", enlace, true);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            switch (ctrl.ID)
            {
                case "cboTipo":

                    /* Solo los tipos que la persona puede registrar. El
                       traslado de ingreso (7) no aparece nunca: lo genera el
                       traslado de salida, no se pide suelto. */
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));

                    if (Token.Puede("REGISTRAR INGRESO REPUESTO"))
                        ctrl.Items.Add(new RadComboBoxItem("Ingreso por compra", "1"));

                    if (Token.Puede("ENTREGAR REPUESTO"))
                    {
                        ctrl.Items.Add(new RadComboBoxItem("Entrega (salida por consumo)", "2"));
                        ctrl.Items.Add(new RadComboBoxItem("Devolución", "3"));
                    }

                    if (Token.Puede("AJUSTAR INVENTARIO"))
                    {
                        ctrl.Items.Add(new RadComboBoxItem("Ajuste positivo (sobra en el conteo)", "4"));
                        ctrl.Items.Add(new RadComboBoxItem("Ajuste negativo (falta en el conteo)", "5"));
                        ctrl.Items.Add(new RadComboBoxItem("Traslado a otra bodega", "6"));

                        /* La reubicacion existia en la base desde el bloque 71
                           y no estaba en esta lista: el tipo 9 era inalcanzable
                           desde la web, asi que mover una pieza de estante solo
                           se podia hacer entrando por SQL. */
                        ctrl.Items.Add(new RadComboBoxItem("Cambio de ubicación (mismo depósito)", "9"));

                        ctrl.Items.Add(new RadComboBoxItem("Merma", "8"));
                    }

                    break;

                case "cboRepuesto":

                    RepuestoController ctrlRep = new RepuestoController();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlRep.GetRepuestos(new Repuesto { filtro_habilitado = true });
                    ctrl.DataValueField = "rep_id";
                    ctrl.DataTextField = "rep_codigo";
                    ctrl.DataBind();
                    break;

                case "cboBodega":
                case "cboDestino":

                    BodegaController ctrlBod = new BodegaController();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlBod.GetBodegas(new Bodega { filtro_habilitado = true });
                    ctrl.DataValueField = "bod_id";
                    ctrl.DataTextField = "bod_nombre";
                    ctrl.DataBind();
                    break;
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (Id > 0) CargarDetalle();
        else CargarAlta();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnRegistrar);
        udPanel.Update();
    }

    protected void CargarAlta()
    {
        pnlAlta.Visible = true;
        pnlDetalle.Visible = false;

        AjustarSegunTipo();
    }

    private int TipoElegido()
    {
        int tipo;
        return int.TryParse(cboTipo.SelectedValue, out tipo) ? tipo : 0;
    }

    private int RepuestoElegido()
    {
        int rep;
        return int.TryParse(cboRepuesto.SelectedValue, out rep) ? rep : 0;
    }

    private int BodegaElegida()
    {
        int bod;
        return int.TryParse(cboBodega.SelectedValue, out bod) ? bod : 0;
    }

    /// <summary>
    /// Sale mercadería: el saldo tiene que alcanzar y hay que decir de qué
    /// cubo se saca.
    /// </summary>
    private bool EsSalida(int tipo)
    {
        return tipo == InventarioController.SALIDA_CONSUMO
            || tipo == InventarioController.AJUSTE_NEGATIVO
            || tipo == InventarioController.TRASLADO_SALIDA
            || tipo == InventarioController.MERMA;
    }

    private bool EsEntrada(int tipo)
    {
        return tipo == InventarioController.INGRESO_COMPRA
            || tipo == InventarioController.DEVOLUCION
            || tipo == InventarioController.AJUSTE_POSITIVO;
    }

    /// <summary>
    /// Cambio de estante dentro del mismo depósito (tipo 9).
    ///
    /// No entra ni sale nada: el total de la bodega queda igual y lo único
    /// que cambia es de qué cubo a qué cubo. Por eso pide las dos cosas —de
    /// dónde sale y a dónde va— y no pide costo ni orden.
    ///
    /// El origen PUEDE no tener estante: es justamente lo que hay que poder
    /// reparar cuando queda existencia suelta —un traslado que llegó sin
    /// ubicación, o el resto de la reconstrucción de saldos del bloque 71—.
    /// </summary>
    private bool EsReubicacion(int tipo)
    {
        return tipo == 9;
    }

    /// <summary>
    /// Muestra solo los campos que el tipo elegido necesita, y arma el
    /// recorrido del formulario.
    ///
    /// Pedirlos todos siempre obligaría al bodeguero a decidir cuáles
    /// ignorar, y ese es justo el momento en que se llena el que no
    /// correspondía.
    /// </summary>
    protected void AjustarSegunTipo()
    {
        int tipo = TipoElegido();

        bool esEntrada = EsEntrada(tipo);
        bool esSalida = EsSalida(tipo);
        bool esReubicacion = EsReubicacion(tipo);

        bool esAjuste = (tipo == InventarioController.AJUSTE_POSITIVO
                         || tipo == InventarioController.AJUSTE_NEGATIVO
                         || tipo == InventarioController.MERMA);

        /* Mientras no se elija el tipo no se muestra nada más: los campos
           que aparecerían no se sabe todavía cuáles son. */
        pnlPaso2.Visible = (tipo > 0);
        pnlPaso3.Visible = (tipo > 0);
        pnlPaso4.Visible = (tipo > 0);
        pnlPaso6.Visible = (tipo > 0);

        litAyudaTipo.Text = AyudaDelTipo(tipo);

        pnlDestino.Visible = (tipo == InventarioController.TRASLADO_SALIDA);

        pnlOrden.Visible = (tipo == InventarioController.SALIDA_CONSUMO
                            || tipo == InventarioController.DEVOLUCION);

        // El costo solo tiene sentido cuando entra mercadería.
        pnlCosto.Visible = esEntrada;

        /* SALIDA: se elige el cubo de origen, que ya trae el lote adentro.
           ENTRADA: se elige el estante libremente, porque el punto es dejar
           la mercadería donde todavía no hay nada.
           REUBICACION: las dos cosas, porque mueve de un cubo a otro. */
        pnlOrigen.Visible = esSalida || esReubicacion;
        pnlUbicacion.Visible = esEntrada || esReubicacion;

        litRotuloLugar.Text = esReubicacion ? "De qué estante a cuál"
                            : esSalida ? "De dónde sale"
                            : esEntrada ? "Dónde queda" : "Dónde";

        litRotuloUbicacion.Text = (tipo == InventarioController.TRASLADO_SALIDA || esReubicacion)
                                ? "Ubicación de destino" : "Ubicación";

        /* El lote se pide en TODA entrada de un repuesto que lo controla, no
           solo en el ingreso por compra: INS_INVENTARIO_MOVIMIENTO lo exige
           con el error 7 para cualquier entrada. Antes solo se ofrecía en el
           ingreso, así que una devolución de un repuesto con lote no tenía
           forma de completarse. */
        pnlLote.Visible = esEntrada && RepuestoControlaLote();

        /* El lote NUEVO solo al comprar: una devolución devuelve algo que ya
           salió, y un ajuste positivo corrige una cuenta de algo que ya
           estaba. En los dos casos el lote existe. */
        bool loteNuevo = (tipo == InventarioController.INGRESO_COMPRA);

        txtLoteNuevo.Visible = loteNuevo;
        txtLoteVence.Visible = loteNuevo;

        if (esAjuste)
        {
            litRotuloMotivo.Text = "Motivo (*)";
            litAyudaMotivo.Text = "Obligatorio. Un ajuste sin motivo es una diferencia " +
                                  "que después nadie va a poder explicar.";
        }
        else
        {
            litRotuloMotivo.Text = "Observación";
            litAyudaMotivo.Text = "Opcional.";
        }

        // El último paso lleva el número que le toca según haya orden o no.
        litNumeroMotivo.Text = pnlOrden.Visible ? "6" : "5";

        MostrarSaldo();
    }

    /// <summary>
    /// Qué significa cada tipo, junto al combo.
    ///
    /// "Merma" y "Ajuste negativo" descuentan los dos, y cuál corresponde no
    /// se deduce del nombre: la merma es pérdida física conocida, el ajuste
    /// es una diferencia de conteo que nadie sabe explicar.
    /// </summary>
    private string AyudaDelTipo(int tipo)
    {
        switch (tipo)
        {
            case InventarioController.INGRESO_COMPRA:
                return "Llegó mercadería del proveedor.";
            case InventarioController.SALIDA_CONSUMO:
                return "Se entregó a un técnico para consumirla.";
            case InventarioController.DEVOLUCION:
                return "Vuelve a bodega lo que se entregó y no se usó.";
            case InventarioController.AJUSTE_POSITIVO:
                return "El conteo físico encontró más de lo que decía el sistema.";
            case InventarioController.AJUSTE_NEGATIVO:
                return "El conteo físico encontró menos, y no se sabe por qué.";
            case InventarioController.TRASLADO_SALIDA:
                return "Se mueve a otra bodega. Genera solo la entrada del otro lado.";
            case InventarioController.MERMA:
                return "Se perdió y se sabe cómo: se rompió, se venció, se derramó.";
            case 9:
                return "Se cambia de estante dentro del mismo depósito. No entra ni sale nada: " +
                       "el total de la bodega queda igual. Sirve además para guardar en su " +
                       "sitio lo que quedó suelto, sin estante.";
            default:
                return "Elija qué pasó y la pantalla pide solo lo que ese caso necesita.";
        }
    }

    private bool RepuestoControlaLote()
    {
        int rep = RepuestoElegido();

        if (rep == 0) return false;

        RepuestoController controller = new RepuestoController();
        return controller.GetRepuesto(rep).rep_controla_lote;
    }

    protected void cboTipo_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        AjustarSegunTipo();
        CargarLotes();
        CargarOrigenes();
        CargarOrdenes();

        /* Otra vez y al final: AjustarSegunTipo ya lo llamo, pero en ese
           momento el combo de origen todavia tenia los cubos del tipo
           anterior. La cifra del saldo tiene que salir de la lista recien
           armada, no de la que se acaba de reemplazar. */
        MostrarSaldo();
    }

    protected void cboRepuesto_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        AjustarSegunTipo();
        CargarLotes();
        CargarOrigenes();
        MostrarSaldo();
    }

    protected void cboBodega_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        CargarUbicaciones();
        CargarOrigenes();
        MostrarSaldo();
    }

    protected void cboOrigen_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        MostrarSaldo();
    }

    protected void CargarLotes()
    {
        if (!pnlLote.Visible) return;

        int rep = RepuestoElegido();

        if (rep == 0) return;

        RepuestoController controller = new RepuestoController();

        cboLote.Items.Clear();

        /* Al comprar puede no haber lote todavía; en el resto de las
           entradas el lote existe sí o sí, así que no se ofrece la salida
           de "escríbalo abajo" que ahí no lleva a ninguna parte. */
        cboLote.Items.Add(new RadComboBoxItem(
            txtLoteNuevo.Visible ? "Lote nuevo (escríbalo al lado)" : "Seleccione...", ""));

        cboLote.AppendDataBoundItems = true;

        /* Se listan TODOS, no solo los vigentes. Un lote vencido que sigue en
           la estantería hay que poder moverlo —para darlo de baja por merma,
           por ejemplo— y esconderlo del combo obliga a inventar otro lote
           para poder sacarlo. La etiqueta ya dice "(VENCIDO)". */
        cboLote.DataSource = controller.GetLotes(new RepuestoLote { rlo_repuesto = rep });
        cboLote.DataValueField = "rlo_id";
        cboLote.DataTextField = "etiqueta";
        cboLote.DataBind();
    }

    protected void CargarUbicaciones()
    {
        int bod = BodegaElegida();

        cboUbicacion.Items.Clear();

        /* En una reubicación el destino es obligatorio —es lo único que el
           movimiento hace—, así que no se ofrece "sin ubicación": sería
           ofrecer dejar la pieza exactamente igual de suelta que antes. */
        cboUbicacion.Items.Add(new RadComboBoxItem(
            EsReubicacion(TipoElegido()) ? "Seleccione..." : "Sin ubicación", ""));

        if (bod == 0) return;

        BodegaController controller = new BodegaController();

        cboUbicacion.AppendDataBoundItems = true;
        cboUbicacion.DataSource = controller.GetUbicaciones(
            new BodegaUbicacion { bub_bodega = bod, filtro_habilitado = true });
        cboUbicacion.DataValueField = "bub_id";
        cboUbicacion.DataTextField = "bub_codigo";
        cboUbicacion.DataBind();
    }

    /// <summary>
    /// Los cubos con existencia, para una salida (bloque 87).
    ///
    /// Es la corrección del defecto: antes se ofrecían las seis ubicaciones
    /// de la bodega, la mercadería estaba en una sola, y el bodeguero se
    /// enteraba recién al registrar.
    /// </summary>
    protected void CargarOrigenes()
    {
        if (!pnlOrigen.Visible) return;

        cboOrigen.Items.Clear();

        int rep = RepuestoElegido();
        int bod = BodegaElegida();

        if (rep == 0 || bod == 0)
        {
            cboOrigen.Items.Add(new RadComboBoxItem("Elija primero el repuesto y la bodega", ""));
            return;
        }

        InventarioController controller = new InventarioController();
        List<InventarioOrigen> origenes = controller.GetOrigenes(rep, bod);

        if (origenes == null || origenes.Count == 0)
        {
            cboOrigen.Items.Add(new RadComboBoxItem("No hay existencia de este repuesto en esta bodega", ""));
            return;
        }

        /* Un solo origen se elige solo. Obligar a abrir un desplegable con
           una sola opción es pedir un clic que no decide nada. */
        if (origenes.Count > 1)
            cboOrigen.Items.Add(new RadComboBoxItem("Seleccione...", ""));

        foreach (InventarioOrigen o in origenes)
            cboOrigen.Items.Add(new RadComboBoxItem(o.etiqueta, o.clave));

        cboOrigen.SelectedIndex = 0;
    }

    /// <summary>
    /// Las órdenes de trabajo abiertas (bloque 87).
    ///
    /// Mientras el módulo de órdenes no exista la lista viene vacía, y eso
    /// se dice con todas sus letras. Un combo vacío sin explicación se lee
    /// como que la pantalla se rompió.
    /// </summary>
    protected void CargarOrdenes()
    {
        if (!pnlOrden.Visible) return;

        InventarioController controller = new InventarioController();
        List<OrdenTrabajoCombo> ordenes = controller.GetOrdenesAbiertas();

        cboOrden.Items.Clear();

        if (ordenes == null || ordenes.Count == 0)
        {
            cboOrden.Items.Add(new RadComboBoxItem("No hay órdenes de trabajo abiertas", ""));
            cboOrden.Enabled = false;

            litAyudaOrden.Text = "El movimiento se registra igual, sin asociar a ninguna orden. " +
                                 "Cuando existan órdenes abiertas aparecerán acá.";
            return;
        }

        cboOrden.Enabled = true;
        cboOrden.Items.Add(new RadComboBoxItem("Sin orden", ""));

        foreach (OrdenTrabajoCombo o in ordenes)
            cboOrden.Items.Add(new RadComboBoxItem(o.etiqueta, o.orden_id.ToString()));

        litAyudaOrden.Text = "El consumo queda registrado en la orden con su costo. " +
                             "Devolver reduce lo consumido.";
    }

    /// <summary>
    /// LO QUE HAY, DICHO SIN CONTRADECIRSE.
    ///
    /// Dos cifras y no una, porque son dos preguntas distintas y confundirlas
    /// fue el defecto: el total de la bodega es lo que hay en total, y el
    /// saldo del cubo es contra lo que el SP realmente valida.
    /// </summary>
    protected void MostrarSaldo()
    {
        litSaldo.Text = "";

        int rep = RepuestoElegido();
        int bod = BodegaElegida();

        if (rep == 0 || bod == 0) return;

        InventarioController controller = new InventarioController();

        List<InventarioSaldo> saldos = controller.GetSaldos(
            new InventarioSaldo { isa_repuesto = rep, isa_bodega = bod });

        if (saldos == null || saldos.Count == 0)
        {
            litSaldo.Text = "<i class=\"mdi mdi-information-outline\"></i> " +
                            "Sin existencia registrada en esta bodega.";
            return;
        }

        InventarioSaldo s = saldos[0];

        string texto = "<i class=\"mdi mdi-warehouse\"></i> En toda la bodega: <strong>" +
                       s.isa_cantidad.ToString("N2") + " " +
                       Server.HtmlEncode(s.unidad_simbolo) + "</strong>" +
                       (s.bajo_minimo ? " · bajo el mínimo" : "");

        /* En una salida lo que decide es el cubo elegido, no el total. Se
           dice cuánto hay AHI, que es la cifra contra la que el SP va a
           comparar la cantidad. */
        if (pnlOrigen.Visible)
        {
            InventarioOrigen o = OrigenElegido();

            if (o != null)
            {
                texto += "<span class=\"sep\">·</span><i class=\"mdi mdi-map-marker\"></i> " +
                         "De donde va a salir: <strong>" + o.cantidad.ToString("N2") + " " +
                         Server.HtmlEncode(o.unidad) + "</strong> en " +
                         Server.HtmlEncode(string.IsNullOrEmpty(o.ubicacion_codigo)
                                           ? "sin ubicación" : o.ubicacion_codigo) +
                         (string.IsNullOrEmpty(o.lote_codigo)
                          ? "" : ", lote " + Server.HtmlEncode(o.lote_codigo));
            }
        }

        litSaldo.Text = texto;
    }

    /// <summary>
    /// El cubo elegido en el combo de origen, releído de la base.
    ///
    /// Se relee en vez de guardarlo en ViewState porque entre que se abrió
    /// el combo y se aprieta Registrar alguien pudo sacar mercadería, y
    /// mostrar la cifra de hace un minuto sería volver al mismo problema.
    /// </summary>
    private InventarioOrigen OrigenElegido()
    {
        string clave = cboOrigen.SelectedValue;

        if (string.IsNullOrEmpty(clave) || clave.IndexOf('|') < 0) return null;

        InventarioController controller = new InventarioController();
        List<InventarioOrigen> origenes = controller.GetOrigenes(RepuestoElegido(), BodegaElegida());

        if (origenes == null) return null;

        foreach (InventarioOrigen o in origenes)
            if (o.clave == clave) return o;

        return null;
    }

    /// <summary>
    /// Llegó una lectura de la cámara.
    ///
    /// Se aceptan las tres etiquetas que tienen sentido acá:
    ///   REP-  el repuesto
    ///   UBI-  el estante, que además resuelve la bodega
    ///   BOD-  la bodega
    ///
    /// La de un activo (ACT-) no se rechaza en silencio: se explica que esa
    /// etiqueta es de una máquina y no de un lugar de bodega.
    /// </summary>
    protected void btnLeido_Click(object sender, EventArgs e)
    {
        try
        {
            string leido = hdnLeido.Value;
            hdnLeido.Value = "";

            if (string.IsNullOrEmpty(leido) || leido.Trim().Length == 0) return;

            EtiquetaController lector = new EtiquetaController();

            string tipo;
            int id;

            if (!lector.Interpretar(leido, out tipo, out id))
                throw new Exception("No se reconoce «" + leido.Trim() +
                                    "». Escanee la etiqueta de un repuesto (REP-), " +
                                    "de un estante (UBI-) o de una bodega (BOD-).");

            if (tipo == "ACT")
                throw new Exception("Esa es la etiqueta de un activo. Acá se espera la de " +
                                    "un repuesto, un estante o una bodega.");

            if (tipo == "REP") SeleccionarRepuesto(id);
            else if (tipo == "BOD") SeleccionarBodega(id, 0);
            else SeleccionarUbicacion(id);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
        finally
        {
            /* Se olvida el último código para que volver a escanear la misma
               etiqueta funcione: si alguien reintenta es porque quiere que
               vuelva a pasar algo. */
            ScriptManager.RegisterStartupScript(this, GetType(), "escaneo-olvidar",
                                                "if(window.sigmaEscaneo) sigmaEscaneo.olvidar();", true);
        }
    }

    private void SeleccionarRepuesto(int id)
    {
        RadComboBoxItem item = cboRepuesto.FindItemByValue(id.ToString());

        if (item == null)
            throw new Exception("Ese repuesto no está habilitado o no es de su empresa.");

        item.Selected = true;

        AjustarSegunTipo();
        CargarLotes();
        CargarOrigenes();
        MostrarSaldo();
    }

    private void SeleccionarBodega(int id, int ubicacion)
    {
        RadComboBoxItem item = cboBodega.FindItemByValue(id.ToString());

        if (item == null)
            throw new Exception("Esa bodega no está habilitada o no es de su empresa.");

        item.Selected = true;

        CargarUbicaciones();
        CargarOrigenes();

        if (ubicacion > 0)
        {
            RadComboBoxItem ubi = cboUbicacion.FindItemByValue(ubicacion.ToString());
            if (ubi != null) ubi.Selected = true;

            /* En una salida el combo no lista ubicaciones sino cubos, y en
               el mismo estante puede haber dos lotes. Se elige el primero
               que corresponda a esa ubicación —el que vence antes, porque
               así viene ordenado— y si hay otro el bodeguero lo cambia. */
            foreach (RadComboBoxItem c in cboOrigen.Items)
            {
                if (c.Value.StartsWith(ubicacion.ToString() + "|"))
                {
                    c.Selected = true;
                    break;
                }
            }
        }

        MostrarSaldo();
    }

    private void SeleccionarUbicacion(int id)
    {
        BodegaController controller = new BodegaController();

        List<BodegaUbicacion> lista = controller.GetUbicaciones(new BodegaUbicacion { bub_id = id });

        if (lista == null || lista.Count == 0)
            throw new Exception("Ese estante no existe o no es de su empresa.");

        SeleccionarBodega(lista[0].bub_bodega, id);
    }

    private decimal? LeerDecimal(string texto, string campo)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim())) return null;

        decimal valor;
        string limpio = texto.Trim().Replace(",", ".");

        if (!decimal.TryParse(limpio, NumberStyles.Any, CultureInfo.InvariantCulture, out valor))
            throw new Exception("El campo '" + campo + "' no es un número válido.");

        return valor;
    }

    protected void btnRegistrar_Click(object sender, EventArgs e)
    {
        try
        {
            int tipo = TipoElegido();

            if (tipo == 0) throw new Exception("Indique qué movimiento va a registrar.");

            int repuesto = RepuestoElegido();
            int bodega = BodegaElegida();
            int aux;

            if (repuesto == 0) throw new Exception("Indique el repuesto.");
            if (bodega == 0) throw new Exception("Indique la bodega.");

            decimal? cantidad = LeerDecimal(txtCantidad.Text, "cantidad");

            if (cantidad == null || cantidad <= 0)
                throw new Exception("La cantidad debe ser mayor que cero.");

            InventarioMovimiento entidad = new InventarioMovimiento();
            entidad.imo_repuesto = repuesto;
            entidad.imo_bodega = bodega;
            entidad.imo_inventario_movimiento_tipo = tipo;
            entidad.imo_cantidad = cantidad.Value;
            entidad.imo_observacion = txtObservacion.Text.Trim();
            entidad.imo_costo_unitario = pnlCosto.Visible ? LeerDecimal(txtCosto.Text, "costo unitario") : null;

            /* SALIDA: la ubicación y el lote salen los dos del cubo elegido.
               Mandarlos por separado fue lo que produjo el rechazo con "hay
               340" en pantalla: se combinaba un estante con un lote que en
               ese estante no estaba. */
            if (pnlOrigen.Visible)
            {
                InventarioOrigen origen = OrigenElegido();

                if (origen == null)
                    throw new Exception("Indique de dónde sale. Si la lista está vacía, " +
                                        "este repuesto no tiene existencia en esta bodega.");

                if (origen.cantidad < cantidad.Value)
                    throw new Exception("Ahí hay " + origen.cantidad.ToString("N2") + " " +
                                        origen.unidad + " y se intenta sacar " +
                                        cantidad.Value.ToString("N2") + ". " +
                                        "Elija otro origen o baje la cantidad.");

                entidad.imo_bodega_ubicacion = origen.ubicacion_id;
                entidad.imo_repuesto_lote = origen.lote_id;

                /* REUBICACION: el origen ya está resuelto arriba y acá se
                   agrega a dónde va. Es el único tipo que usa los dos
                   campos de ubicación a la vez. */
                if (EsReubicacion(tipo))
                {
                    if (!int.TryParse(cboUbicacion.SelectedValue, out aux) || aux == 0)
                        throw new Exception("Indique a qué ubicación se cambia.");

                    if (origen.ubicacion_id.HasValue && origen.ubicacion_id.Value == aux)
                        throw new Exception("La ubicación de destino es la misma de origen.");

                    entidad.imo_bodega_ubicacion_destino = aux;
                }
            }
            else if (int.TryParse(cboUbicacion.SelectedValue, out aux) && aux > 0)
            {
                entidad.imo_bodega_ubicacion = aux;
            }

            if (pnlDestino.Visible)
            {
                if (!int.TryParse(cboDestino.SelectedValue, out aux) || aux == 0)
                    throw new Exception("Indique la bodega de destino del traslado.");

                entidad.imo_bodega_destino = aux;
            }

            if (pnlOrden.Visible && int.TryParse(cboOrden.SelectedValue, out aux) && aux > 0)
                entidad.imo_orden_trabajo = aux;

            /* El lote de una ENTRADA: si eligió uno existente va ese; si
               escribió un código nuevo se crea antes del movimiento. Crearlo
               después dejaría un movimiento apuntando a un lote que todavía
               no existe. */
            if (pnlLote.Visible)
            {
                if (int.TryParse(cboLote.SelectedValue, out aux) && aux > 0)
                {
                    entidad.imo_repuesto_lote = aux;
                }
                else if (txtLoteNuevo.Visible && !string.IsNullOrEmpty(txtLoteNuevo.Text.Trim()))
                {
                    RepuestoController ctrlRep = new RepuestoController();

                    /* El vencimiento se pide ACA porque es el unico momento en
                       que alguien lo tiene delante: esta leyendo el envase.
                       Sin fecha el lote se crea igual —hay repuestos que no
                       vencen— pero entonces no hay forma de avisar despues, y
                       avisar es justamente para lo que este repuesto controla
                       lote. */
                    RepuestoLote nuevo = new RepuestoLote();
                    nuevo.rlo_repuesto = repuesto;
                    nuevo.rlo_codigo = txtLoteNuevo.Text.Trim();
                    nuevo.rlo_fecha_ingreso = DateTime.Today;
                    /* El calendario ya entrega la fecha validada: interpretarla
                       de nuevo desde su texto seria volver a hacer -peor- lo
                       que el control acaba de hacer bien. */
                    nuevo.rlo_fecha_vencimiento = txtLoteVence.Value;

                    Respuesta lote = ctrlRep.InsertLote(nuevo);

                    if (lote.error)
                        throw new Exception("No se pudo crear el lote: " + lote.detalle);

                    entidad.imo_repuesto_lote = lote.codigo;
                }
                else if (txtLoteNuevo.Visible)
                {
                    throw new Exception("Este repuesto controla lote: elija uno o escriba el código del lote nuevo.");
                }
                else
                {
                    throw new Exception("Este repuesto controla lote: elija a qué lote entra.");
                }
            }

            InventarioController controller = new InventarioController();
            Respuesta respuesta = controller.RegistrarMovimiento(entidad);

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void CargarDetalle()
    {
        pnlAlta.Visible = false;
        pnlDetalle.Visible = true;

        if (IsPostBack) return;

        InventarioController controller = new InventarioController();
        InventarioMovimiento m = controller.GetMovimiento(Id);

        litDetTitulo.Text = (m.signo > 0 ? "+" : "−") + m.imo_cantidad.ToString("N2") + " " +
                            Server.HtmlEncode(m.unidad_simbolo) + " · " + Server.HtmlEncode(m.tipo_nombre);

        litDetDetalle.Text = m.imo_fecha_movimiento_utc.ToString("dd-MM-yyyy HH:mm") + " UTC";

        /* Mismo codigo de color que el listado: verde entra, rojo sale,
           ambar se corrigio, azul se movio de sitio. Que la ficha pinte
           distinto que la grilla obliga a reaprender el color al entrar. */
        string chip = (m.familia == "AJUSTE") ? "is-advertencia"
                    : (m.familia == "TRASLADO") ? "is-info"
                    : (m.familia == "CONSUMO") ? "is-alerta" : "is-exito";

        litDetChip.Text = "<span class=\"sigma-modal-chip " + chip + "\">" +
                          Server.HtmlEncode(m.familia) + "</span>";

        lblDetRepuesto.Text = m.repuesto_codigo + " · " + m.repuesto_nombre;
        lblDetBodega.Text = m.bodega_nombre +
                            (string.IsNullOrEmpty(m.bodega_destino_nombre)
                             ? "" : "  →  " + m.bodega_destino_nombre);

        lblDetUbicacion.Text = string.IsNullOrEmpty(m.ubicacion_codigo) ? "—" : m.ubicacion_codigo;
        lblDetLote.Text = string.IsNullOrEmpty(m.lote_codigo) ? "—" : m.lote_codigo;
        lblDetOrden.Text = (m.imo_orden_trabajo == null) ? "—" : m.imo_orden_trabajo.Value.ToString();
        lblDetUsuario.Text = m.usuario_nombre;
        lblDetObservacion.Text = string.IsNullOrEmpty(m.imo_observacion) ? "—" : m.imo_observacion;

        /* Un movimiento no se edita nunca, así que no hay fecha de
           actualización que mostrar: se pasa null y el control escribe
           "Todavía no se ha editado", que en este caso es literal y para
           siempre. */
        wucAuditoria.Mostrar(m.usuario_nombre, m.imo_fecha_movimiento_utc, null, null);
    }
}
