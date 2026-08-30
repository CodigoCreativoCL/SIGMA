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
/// Los planes comerciales y sus precios (ANEXO F §3).
///
/// Una fila por plan Y periodicidad: el mismo plan aparece varias veces
/// porque el precio es lo que cambia entre mensual, trimestral y anual. El
/// enlace de cada fila abre el PLAN, no el precio.
///
/// No hay Eliminar. Un plan con suscripciones o períodos emitidos es
/// historia de cobranza: se deshabilita desde su ficha, y deshabilitado
/// significa "no se vende más", no "no existió nunca".
/// </summary>
public partial class View_Comercial_Suscripciones_Planes : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("PLC_ID", "", Width: "3%");
            Grid.AddColumn("PLC_CODIGO", "PLAN", Width: "12%");
            Grid.AddColumn("PLC_NOMBRE", "NOMBRE", Width: "22%");
            Grid.AddColumn("PCB_NOMBRE", "PERIODICIDAD", Width: "14%");
            Grid.AddColumn("PCP_VALOR_UF", "UF", Width: "10%", DataFormat: "{0:N2}");
            Grid.AddColumn("MONTO_CLP_REFERENCIAL", "REFERENCIAL HOY", Width: "16%", DataFormat: "{0:C0}");
            Grid.AddColumn("PCP_DESCUENTO_PORCENTAJE", "DESCUENTO", Width: "12%", DataFormat: "{0:N1} %");
            Grid.AddColumn("PLC_DIAS_GRACIA", "DÍAS DE GRACIA", Width: "14%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarUf();
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    /// <summary>
    /// El enlace de cada fila lleva al PLAN, no al precio: los precios se
    /// mantienen dentro de la ficha del plan, que es donde se ve su
    /// historial completo.
    /// </summary>
    protected void rgrPlanes_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("plc_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + item.ItemIndex;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirPlan('" + query + "')");

                item["plc_id"].Controls.Add(Editar);
            }
        }
    }

    protected void CargarGrid()
    {
        PlanComercialController controller = new PlanComercialController();

        PlanComercial filtro = new PlanComercial();
        filtro.filtro_habilitado = true;

        Grid.DataSource = controller.GetPlanesComerciales(filtro);
    }

    /// <summary>
    /// El valor de UF con el que se están calculando los montos de arriba.
    ///
    /// Se muestra a propósito: sin él, un monto referencial es un número
    /// sin origen, y la primera pregunta de quien lo mire va a ser con qué
    /// UF salió. Si no hay valor cargado hay que decirlo, porque en ese
    /// caso tampoco se puede emitir un período.
    /// </summary>
    protected void CargarUf()
    {
        PlanComercialController controller = new PlanComercialController();

        List<PlanComercial> lista = controller.GetPlanesComerciales(new PlanComercial { filtro_habilitado = true });

        decimal? uf = null;

        if (lista != null && lista.Count > 0) uf = lista[0].valor_uf_dia;

        if (uf == null || uf <= 0)
        {
            litUf.Text = "<span class=\"grid-estado-chip is-alerta\">Sin valor de UF cargado para hoy</span> " +
                         "Mientras no lo haya, los montos no se pueden calcular y tampoco se puede emitir un período.";
            return;
        }

        litUf.Text = "UF de hoy: <strong>" +
                     uf.Value.ToString("C2", CultureInfo.GetCultureInfo("es-CL")) +
                     "</strong> &middot; " + DateTime.Today.ToString("dd-MM-yyyy");
    }
}
