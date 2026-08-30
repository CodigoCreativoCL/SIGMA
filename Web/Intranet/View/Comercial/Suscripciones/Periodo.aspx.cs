using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Emisión y detalle de un período (ANEXO F §4.3).
///
/// DOS PANELES Y UNA SOLA PÁGINA
///   Con Id = 0 es el formulario de emisión; con Id > 0 es el detalle de
///   algo que ya se emitió y no se puede editar. No son la misma pantalla
///   con campos bloqueados: son dos cosas distintas, y mostrar el
///   formulario en gris invitaría a intentar corregir un cobro ya emitido.
///
/// EL DETALLE EXPLICA EL NÚMERO
///   No basta con mostrar el monto: hay que mostrar de dónde salió. UF del
///   plan por valor de la UF de ese día. Son los tres números congelados
///   (§4.3), y están guardados justamente para que ese recuadro diga la
///   verdad dentro de dos años.
/// </summary>
public partial class View_Comercial_Suscripciones_Periodo : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            /* Querystring.Entero y no Crypto.Decrypt directo: el listado
               abre esta ficha con abrirPeriodo(0) para emitir uno nuevo,
               asi que llega literalmente ?query=0, que no es texto cifrado
               valido. Descifrarlo sin red lanzaba y la pagina respondia
               500. */
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");

            Grid.AddColumn("SPA_FECHA_TRANSFERENCIA", "TRANSFERIDO EL", Width: "18%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddColumn("SPA_BANCO", "BANCO", Width: "20%");
            Grid.AddColumn("SPA_NUMERO_OPERACION", "N° OPERACIÓN", Width: "20%");
            Grid.AddColumn("SPA_MONTO_DECLARADO_CLP", "DECLARADO", Width: "16%", DataFormat: "{0:C0}");
            Grid.AddColumn("SPA_MONTO_VERIFICADO_CLP", "VERIFICADO", Width: "16%", DataFormat: "{0:C0}");
            Grid.AddColumn("SPO_NOMBRE", "ESTADO", Width: "10%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                if (ctrl.ID == "cboPeriodicidad")
                {
                    CatalogoController controller = new CatalogoController();

                    ctrl.DataSource = controller.GetValoresPorCodigo("PERIODICIDAD_COBRO", SitioBase.Session.ClienteId());
                    ctrl.DataValueField = "valor_id";
                    ctrl.DataTextField = "valor_nombre";
                    ctrl.DataBind();
                }

                if (ctrl.ID == "cboPlan")
                {
                    PlanComercialController controller = new PlanComercialController();

                    ctrl.Items.Add(new RadComboBoxItem("El plan contratado", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetPlanesDistintos();
                    ctrl.DataValueField = "plc_id";
                    ctrl.DataTextField = "plc_nombre";
                    ctrl.DataBind();
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        pnlEmitir.Visible = (Id == 0);
        pnlDetalle.Visible = (Id > 0);

        litCliente.Text = Server.HtmlEncode(SitioBase.Session.ClienteNombre());

        if (Id == 0)
        {
            litTitulo.Text = "Emitir un período";
            litChipEstado.Text = "<span class=\"sigma-modal-chip is-neutro\">Sin emitir</span>";
            litHeroTitulo.Text = Server.HtmlEncode(SitioBase.Session.ClienteNombre());
            litHeroDetalle.Text = "El período se cobra en pesos, calculados con el valor de la UF del " +
                                  "día de emisión. Ese número queda congelado.";

            // Codigo y no funcion: esta ficha es otra pagina que el listado.
            btnEmitir.Visible = Token.Puede("EMITIR PERIODOS SUSCRIPCION");
        }
        else
        {
            CargarDetalle();
            CargarPagos();
            Grid.DataBind();
        }

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnEmitir);
        udPanel.Update();
    }

    protected void CargarDetalle()
    {
        SuscripcionPeriodoController controller = new SuscripcionPeriodoController();
        SuscripcionPeriodo p = controller.GetPeriodo(new SuscripcionPeriodo { spe_id = Id });

        if (p == null || p.spe_id == 0) return;

        CultureInfo cl = CultureInfo.GetCultureInfo("es-CL");

        lblPlan.Text = p.plc_nombre;
        lblPeriodicidad.Text = p.pcb_nombre;
        lblDesde.Text = p.spe_fecha_inicio.ToString("dd-MM-yyyy");
        lblHasta.Text = p.spe_fecha_fin.ToString("dd-MM-yyyy");
        lblObservacion.Text = p.spe_observacion;

        litTitulo.Text = "Período " + p.spe_fecha_inicio.ToString("dd-MM-yyyy") +
                         " al " + p.spe_fecha_fin.ToString("dd-MM-yyyy");

        string chip = (p.saldo_clp <= 0) ? "is-exito" : (p.spe_monto_pagado_clp > 0 ? "is-info" : "is-alerta");

        litChipEstado.Text = "<span class=\"sigma-modal-chip " + chip + "\">" +
                             Server.HtmlEncode(p.spd_nombre) + "</span>";

        litHeroTitulo.Text = p.spe_monto_clp.ToString("C0", cl) +
                             (p.spe_es_implantacion ? " &middot; implantación" : "");

        litHeroDetalle.Text =
            Server.HtmlEncode(p.cli_nombre) + " &middot; pagado " +
            p.spe_monto_pagado_clp.ToString("C0", cl) + " &middot; saldo <strong>" +
            p.saldo_clp.ToString("C0", cl) + "</strong>";

        litCalculo.Text =
            "<strong>" + p.spe_valor_uf_plan.ToString("N2", cl) + " UF</strong> del plan &times; " +
            "<strong>" + p.spe_valor_uf_dia.ToString("C2", cl) + "</strong> que valía la UF el " +
            (p.spe_fecha_valor_uf != null ? p.spe_fecha_valor_uf.Value.ToString("dd-MM-yyyy") : "día de emisión") +
            " = <strong>" + p.spe_monto_clp.ToString("C0", cl) + "</strong>.<br />" +
            "Estos tres números quedaron congelados al emitir. No se recalculan con la UF de hoy: " +
            "un comprobante tiene que mostrar lo que se cobró.";
    }

    protected void CargarPagos()
    {
        SuscripcionPagoController controller = new SuscripcionPagoController();

        Grid.DataSource = controller.GetPagos(new SuscripcionPago { filtro_periodo = Id });
    }

    protected void btnEmitir_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboPeriodicidad.SelectedValue))
                throw new Exception("Debe elegir la periodicidad.");

            SuscripcionController suscripciones = new SuscripcionController();
            Suscripcion suscripcion = suscripciones.GetSuscripcion(
                new Suscripcion { sus_cliente = SitioBase.Session.ClienteId() });

            if (suscripcion == null || suscripcion.sus_id == 0)
                throw new Exception("Este cliente no tiene suscripción. Créela antes de emitir un período.");

            SuscripcionPeriodo entidad = new SuscripcionPeriodo();

            entidad.spe_suscripcion = suscripcion.sus_id;
            entidad.spe_periodicidad_cobro = int.Parse(cboPeriodicidad.SelectedValue);
            entidad.spe_es_implantacion = chkImplantacion.Checked;
            entidad.spe_observacion = txtObservacionNueva.Text.Trim();

            if (!string.IsNullOrEmpty(cboPlan.SelectedValue))
                entidad.spe_plan_comercial = int.Parse(cboPlan.SelectedValue);

            entidad.valor_uf_manual = LeerUf(txtValorUf.Text);

            SuscripcionPeriodoController controller = new SuscripcionPeriodoController();
            Respuesta respuesta = controller.EmitirPeriodo(entidad);

            if (!respuesta.error)
            {
                Id = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Lee un monto en UF aceptando punto o coma. Quien lo escriba en un
    /// teclado es-CL va a poner coma; quien lo copie de una planilla, punto.
    /// Rechazar uno de los dos haría fallar la emisión por una diferencia
    /// que no le importa a nadie.
    /// </summary>
    private decimal? LeerUf(string texto)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim())) return null;

        decimal valor;
        string normalizado = texto.Trim().Replace(",", ".");

        if (!decimal.TryParse(normalizado, NumberStyles.Float, CultureInfo.InvariantCulture, out valor))
            throw new Exception("El monto en UF no es un número válido.");

        if (valor < 0)
            throw new Exception("El monto en UF no puede ser negativo.");

        return valor;
    }
}
