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
///   Lo que cambia según el tipo son los campos que se piden: el lote solo
///   al ingresar, la orden solo al consumir o devolver, la bodega de
///   destino solo al trasladar, y el motivo obligatorio solo al ajustar.
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

    /// <summary>
    /// Muestra solo los campos que el tipo elegido necesita.
    ///
    /// Pedirlos todos siempre obligaría al bodeguero a decidir cuáles
    /// ignorar, y ese es justo el momento en que se llena el que no
    /// correspondía.
    /// </summary>
    protected void AjustarSegunTipo()
    {
        int tipo = TipoElegido();

        bool esEntrada = (tipo == InventarioController.INGRESO_COMPRA
                          || tipo == InventarioController.DEVOLUCION);

        bool esAjuste = (tipo == InventarioController.AJUSTE_POSITIVO
                         || tipo == InventarioController.AJUSTE_NEGATIVO
                         || tipo == InventarioController.MERMA);

        pnlDestino.Visible = (tipo == InventarioController.TRASLADO_SALIDA);

        pnlOrden.Visible = (tipo == InventarioController.SALIDA_CONSUMO
                            || tipo == InventarioController.DEVOLUCION);

        // El costo solo tiene sentido cuando entra mercadería.
        pnlCosto.Visible = esEntrada;

        // El lote se exige al ingresar un repuesto que lo controla.
        pnlLote.Visible = (tipo == InventarioController.INGRESO_COMPRA) && RepuestoControlaLote();

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
    }

    private bool RepuestoControlaLote()
    {
        int rep;

        if (!int.TryParse(cboRepuesto.SelectedValue, out rep) || rep == 0) return false;

        RepuestoController controller = new RepuestoController();
        return controller.GetRepuesto(rep).rep_controla_lote;
    }

    protected void cboTipo_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        AjustarSegunTipo();
    }

    protected void cboRepuesto_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        AjustarSegunTipo();
        CargarLotes();
        MostrarSaldo();
    }

    protected void cboBodega_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        CargarUbicaciones();
        MostrarSaldo();
    }

    protected void CargarLotes()
    {
        if (!pnlLote.Visible) return;

        int rep;

        if (!int.TryParse(cboRepuesto.SelectedValue, out rep) || rep == 0) return;

        RepuestoController controller = new RepuestoController();

        cboLote.Items.Clear();
        cboLote.Items.Add(new RadComboBoxItem("Lote nuevo (escríbalo abajo)", ""));
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
        int bod;

        cboUbicacion.Items.Clear();
        cboUbicacion.Items.Add(new RadComboBoxItem("Sin ubicación", ""));

        if (!int.TryParse(cboBodega.SelectedValue, out bod) || bod == 0) return;

        BodegaController controller = new BodegaController();

        cboUbicacion.AppendDataBoundItems = true;
        cboUbicacion.DataSource = controller.GetUbicaciones(
            new BodegaUbicacion { bub_bodega = bod, filtro_habilitado = true });
        cboUbicacion.DataValueField = "bub_id";
        cboUbicacion.DataTextField = "bub_codigo";
        cboUbicacion.DataBind();
    }

    /// <summary>
    /// Muestra la existencia actual junto a la bodega.
    ///
    /// Es lo que evita el rechazo por saldo insuficiente antes de que
    /// ocurra: el SP lo va a rechazar igual, pero enterarse después de
    /// llenar el formulario completo es peor.
    /// </summary>
    protected void MostrarSaldo()
    {
        int rep, bod;

        if (!int.TryParse(cboRepuesto.SelectedValue, out rep) || rep == 0) return;
        if (!int.TryParse(cboBodega.SelectedValue, out bod) || bod == 0) return;

        InventarioController controller = new InventarioController();

        List<InventarioSaldo> saldos = controller.GetSaldos(
            new InventarioSaldo { isa_repuesto = rep, isa_bodega = bod });

        if (saldos == null || saldos.Count == 0)
        {
            litSaldo.Text = "Sin existencia registrada en esta bodega.";
            return;
        }

        InventarioSaldo s = saldos[0];

        litSaldo.Text = "Existencia actual: <strong>" + s.isa_cantidad.ToString("N2") + " " +
                        Server.HtmlEncode(s.unidad_simbolo) + "</strong>" +
                        (s.bajo_minimo ? " · bajo el mínimo" : "");
    }

    /// <summary>
    /// La fecha de vencimiento del lote nuevo. Opcional: hay repuestos que
    /// no vencen.
    ///
    /// Mismos formatos que el resto del sitio. NO se rechaza una fecha
    /// pasada: recibir un lote ya vencido pasa —llega tarde, o el proveedor
    /// mandó lo que le quedaba— y el sistema tiene que poder registrarlo
    /// para que alguien lo vea, no negarlo.

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

            int repuesto, bodega;

            if (!int.TryParse(cboRepuesto.SelectedValue, out repuesto) || repuesto == 0)
                throw new Exception("Indique el repuesto.");

            if (!int.TryParse(cboBodega.SelectedValue, out bodega) || bodega == 0)
                throw new Exception("Indique la bodega.");

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

            int aux;

            if (int.TryParse(cboUbicacion.SelectedValue, out aux) && aux > 0)
                entidad.imo_bodega_ubicacion = aux;

            if (pnlDestino.Visible)
            {
                if (!int.TryParse(cboDestino.SelectedValue, out aux) || aux == 0)
                    throw new Exception("Indique la bodega de destino del traslado.");

                entidad.imo_bodega_destino = aux;
            }

            if (pnlOrden.Visible && !string.IsNullOrEmpty(txtOrden.Text.Trim()))
            {
                if (!int.TryParse(txtOrden.Text.Trim(), out aux))
                    throw new Exception("La orden de trabajo debe ser un número.");

                entidad.imo_orden_trabajo = aux;
            }

            /* El lote: si eligió uno existente va ese; si escribió un código
               nuevo se crea antes del movimiento. Crearlo después dejaría un
               movimiento apuntando a un lote que todavía no existe. */
            if (pnlLote.Visible)
            {
                if (int.TryParse(cboLote.SelectedValue, out aux) && aux > 0)
                {
                    entidad.imo_repuesto_lote = aux;
                }
                else if (!string.IsNullOrEmpty(txtLoteNuevo.Text.Trim()))
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
                else
                {
                    throw new Exception("Este repuesto controla lote: elija uno o escriba el código del lote nuevo.");
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
