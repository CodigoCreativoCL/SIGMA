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
/// Bandeja de pagos (ANEXO F §5.3 y §5.4).
///
/// Acá conviven dos oficios opuestos y por eso están detrás de dos permisos
/// distintos: el cliente DECLARA lo que transfirió y SIGMA VERIFICA contra
/// la cartola. Con un permiso solo, el cliente se verificaría a sí mismo y
/// la verificación dejaría de significar algo.
///
/// No hay Eliminar. Un pago mal declarado se rechaza con su motivo, y eso
/// queda a la vista de quien lo declaró. Borrarlo dejaría a esa persona
/// declarando lo mismo otra vez sin saber por qué se cayó la primera.
/// </summary>
public partial class View_Comercial_Suscripciones_Pagos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("SPA_ID", "", Width: "3%");
            Grid.AddColumn("SPA_FECHA_TRANSFERENCIA", "TRANSFERIDO EL", Width: "12%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddColumn("SPA_BANCO", "BANCO", Width: "14%");
            Grid.AddColumn("SPA_NUMERO_OPERACION", "N° OPERACIÓN", Width: "14%");
            Grid.AddColumn("SPA_MONTO_DECLARADO_CLP", "DECLARADO", Width: "13%", DataFormat: "{0:C0}");
            Grid.AddColumn("SPA_MONTO_VERIFICADO_CLP", "VERIFICADO", Width: "13%", DataFormat: "{0:C0}");
            Grid.AddColumn("SPE_FECHA_INICIO", "PERÍODO DESDE", Width: "12%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddColumn("VERIFICADO_POR", "VERIFICÓ", Width: "12%");
            Grid.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "12%", ItemPosition: HorizontalAlign.Center);
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        if (!Token.PuedeFuncion("Declarar pago"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        SuscripcionPagoController controller = new SuscripcionPagoController();

        SuscripcionPago filtro = new SuscripcionPago();
        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboPendientes = (RadComboBox2)wucFiltro.FindControl("cboPendientes");

        if (cboPendientes != null && cboPendientes.SelectedValue == "1")
            filtro.filtro_solo_pendientes = true;

        List<SuscripcionPago> lista = controller.GetPagos(filtro);

        Grid.DataSource = lista;

        CargarAviso(lista);
    }

    /// <summary>
    /// Cuántos esperan revisión y por cuánta plata.
    ///
    /// Es lo que hace que esta pantalla sirva como bandeja de trabajo y no
    /// solo como historial: quien verifica entra a ver si tiene algo
    /// pendiente, no a leer lo que ya resolvió.
    /// </summary>
    protected void CargarAviso(List<SuscripcionPago> lista)
    {
        IAlmacenamiento almacenamiento = Almacenamiento.Actual();

        // El aviso del almacenamiento manda: sin él no se puede declarar
        // nada, y decirlo acá evita que alguien llene el formulario para
        // enterarse al final.
        if (!almacenamiento.Disponible)
        {
            litAviso.Text = "<span class=\"grid-estado-chip is-alerta\">No se pueden declarar pagos</span> " +
                            Server.HtmlEncode(almacenamiento.Motivo) +
                            " El comprobante es obligatorio, así que hasta entonces solo se puede consultar.";
            pnlAviso.Visible = true;
            return;
        }

        if (lista == null || lista.Count == 0)
        {
            litAviso.Text = "<span class=\"grid-estado-chip is-neutro\">Sin pagos</span> " +
                            "Este cliente no ha declarado ninguna transferencia.";
            pnlAviso.Visible = true;
            return;
        }

        decimal monto = 0;
        int pendientes = 0;

        foreach (SuscripcionPago p in lista)
        {
            // 1 DECLARADO y 2 EN REVISION son los que esperan a alguien.
            if (p.spa_estado == 1 || p.spa_estado == 2)
            {
                pendientes++;
                monto += p.spa_monto_declarado_clp;
            }
        }

        if (pendientes == 0)
        {
            litAviso.Text = "<span class=\"grid-estado-chip is-exito\">Nada pendiente</span> " +
                            "Todos los pagos declarados ya fueron revisados.";
        }
        else
        {
            litAviso.Text = "<span class=\"grid-estado-chip is-info\">" +
                            pendientes + (pendientes == 1 ? " pago espera verificación" : " pagos esperan verificación") +
                            "</span> Por <strong>" +
                            monto.ToString("C0", CultureInfo.GetCultureInfo("es-CL")) + "</strong> declarados.";
        }

        pnlAviso.Visible = true;
    }

    protected void rgrPagos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("spa_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Ver = new HyperLink();
                Ver.ID = "lnkVer" + id;
                Ver.CssClass = "icono_Editar";
                Ver.NavigateUrl = "javascript:void(0)";
                Ver.Attributes.Add("onclick", "abrirPago('" + query + "')");

                item["spa_id"].Controls.Add(Ver);

                string nombre = DataBinder.Eval(item.DataItem, "spo_nombre") != null
                    ? DataBinder.Eval(item.DataItem, "spo_nombre").ToString()
                    : "";

                // El color se decide por el CÓDIGO y el texto se muestra con
                // el NOMBRE: el código es estable, el nombre es redactable.
                string codigo = DataBinder.Eval(item.DataItem, "spo_codigo") != null
                    ? DataBinder.Eval(item.DataItem, "spo_codigo").ToString()
                    : "";

                Label lblEstado = new Label();
                lblEstado.Text = nombre;
                lblEstado.CssClass = "grid-estado-chip " + ChipDeEstado(codigo);
                item["estadoChip"].Controls.Add(lblEstado);
            }
        }
    }

    private string ChipDeEstado(string codigo)
    {
        switch ((codigo ?? "").Trim().ToUpper())
        {
            case "VERIFICADO": return "is-exito";
            case "RECHAZADO": return "is-alerta";
            case "EN REVISION": return "is-info";
            // DECLARADO: todavía no lo miró nadie. Neutro y no de alerta:
            // que exista es lo esperado, no un problema.
            default: return "is-neutro";
        }
    }
}
