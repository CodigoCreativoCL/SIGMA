using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Períodos de cobro del cliente (ANEXO F §4.3).
///
/// No hay Eliminar ni Editar en el listado. Un período emitido es un cobro
/// emitido: se paga, queda impago o se cierra por un cambio de plan, pero
/// no se borra ni se corrige. Lo que mueve su estado es la verificación de
/// un pago, que ocurre en la pantalla de Pagos.
///
/// La columna de UF no está de adorno: es la única forma de responder "¿por
/// qué este período costó más que el anterior si el plan es el mismo?".
/// </summary>
public partial class View_Comercial_Suscripciones_Periodos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("SPE_ID", "", Width: "3%");
            Grid.AddColumn("SPE_FECHA_INICIO", "DESDE", Width: "10%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddColumn("SPE_FECHA_FIN", "HASTA", Width: "10%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddColumn("PLC_NOMBRE", "PLAN", Width: "14%");
            Grid.AddColumn("PCB_NOMBRE", "PERIODICIDAD", Width: "11%");
            Grid.AddColumn("SPE_VALOR_UF_PLAN", "UF", Width: "8%", DataFormat: "{0:N2}");
            Grid.AddColumn("SPE_MONTO_CLP", "MONTO", Width: "12%", DataFormat: "{0:C0}");
            Grid.AddColumn("SPE_MONTO_PAGADO_CLP", "PAGADO", Width: "12%", DataFormat: "{0:C0}");
            Grid.AddColumn("SALDO_CLP", "SALDO", Width: "10%", DataFormat: "{0:C0}");
            Grid.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "10%", ItemPosition: HorizontalAlign.Center);
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        if (!Token.PuedeFuncion("Emitir período"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        SuscripcionPeriodoController controller = new SuscripcionPeriodoController();

        SuscripcionPeriodo filtro = new SuscripcionPeriodo();
        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboImpagos = (RadComboBox2)wucFiltro.FindControl("cboImpagos");

        if (cboImpagos != null && cboImpagos.SelectedValue == "1")
            filtro.filtro_solo_impagos = true;

        List<SuscripcionPeriodo> lista = controller.GetPeriodos(filtro);

        Grid.DataSource = lista;

        CargarAviso(lista);
    }

    /// <summary>
    /// La deuda total, arriba y de una vez.
    ///
    /// Alguien que entra a esta pantalla viene a responder una sola
    /// pregunta -¿este cliente debe algo?- y sumar diez filas a mano para
    /// contestarla es exactamente el trabajo que la pantalla debería
    /// ahorrarle.
    /// </summary>
    protected void CargarAviso(List<SuscripcionPeriodo> lista)
    {
        if (lista == null || lista.Count == 0)
        {
            litAviso.Text = "<span class=\"grid-estado-chip is-neutro\">Sin períodos</span> " +
                            "Todavía no se le ha emitido ningún período a este cliente, así que la " +
                            "suscripción existe pero no habilita nada: cobrar es lo que la pone en marcha.";
            pnlAviso.Visible = true;
            return;
        }

        decimal saldo = 0;
        int impagos = 0;

        foreach (SuscripcionPeriodo p in lista)
        {
            if (p.saldo_clp > 0) { saldo += p.saldo_clp; impagos++; }
        }

        if (impagos == 0)
        {
            litAviso.Text = "<span class=\"grid-estado-chip is-exito\">Sin saldo pendiente</span> " +
                            "Todos los períodos emitidos están cubiertos.";
        }
        else
        {
            litAviso.Text = "<span class=\"grid-estado-chip is-alerta\">" +
                            impagos + (impagos == 1 ? " período con saldo" : " períodos con saldo") +
                            "</span> Deuda total: <strong>" +
                            saldo.ToString("C0", CultureInfo.GetCultureInfo("es-CL")) + "</strong>";
        }

        pnlAviso.Visible = true;
    }

    protected void rgrPeriodos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("spe_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Ver = new HyperLink();
                Ver.ID = "lnkVer" + id;
                Ver.CssClass = "icono_Editar";
                Ver.NavigateUrl = "javascript:void(0)";
                Ver.Attributes.Add("onclick", "abrirPeriodo('" + query + "')");

                item["spe_id"].Controls.Add(Ver);

                string estado = DataBinder.Eval(item.DataItem, "spd_nombre") != null
                    ? DataBinder.Eval(item.DataItem, "spd_nombre").ToString()
                    : "";

                Label lblEstado = new Label();
                lblEstado.Text = estado;
                lblEstado.CssClass = "grid-estado-chip " + ChipDeEstado(estado);
                item["estadoChip"].Controls.Add(lblEstado);
            }
        }
    }

    /// <summary>
    /// SEL_SUSCRIPCION_PERIODO devuelve el NOMBRE del estado, no su código,
    /// así que la comparación va contra los nombres de
    /// Suscripcion_Periodo_Estado tal como están cargados.
    /// </summary>
    private string ChipDeEstado(string estado)
    {
        switch ((estado ?? "").Trim().ToUpper())
        {
            case "VIGENTE": return "is-exito";
            case "CON ABONO PARCIAL": return "is-info";
            case "PENDIENTE DE PAGO": return "is-alerta";
            case "CERRADO": return "is-neutro";
            case "ANULADO": return "is-neutro";
            default: return "is-neutro";
        }
    }
}
