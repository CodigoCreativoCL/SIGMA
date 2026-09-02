using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de proveedores y contratistas (HU-060, bloque 91).
///
/// EL CLIENTE SALE DE LA SESION, NUNCA DE LA PANTALLA
///   El controlador pasa Session.ClienteId() a SEL_PROVEEDOR y ese parametro
///   no es opcional. Un id escrito a mano en la URL no alcanza para ver el
///   proveedor de otra empresa, porque la ficha lo vuelve a pedir por el
///   mismo camino.
///
/// ELIMINAR NO BORRA
///   Deshabilita. Un proveedor con lotes recibidos o servicios contratados
///   aparece en el historial de compra y en el gasto del año: su nombre
///   tiene que seguir estando. El SP rechaza el borrado y dice cuantos
///   registros dependen de el.
/// </summary>
public partial class View_Terceros_Proveedores_Proveedores : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("PRV_ID", "", Width: "3%");
            Grid.AddColumn("PRV_RUT", "RUT", Width: "13%");
            Grid.AddTemplateColumn("EMPRESA", "", "EMPRESA", Width: "30%");
            Grid.AddTemplateColumn("CONTACTO", "", "CONTACTO", Width: "24%");
            Grid.AddTemplateColumn("TIPO", "", "TIPO", Width: "16%");
            Grid.AddTemplateColumn("MOVIMIENTO", "", "SE LE HA COMPRADO", Width: "14%",
                                   ItemPosition: HorizontalAlign.Center,
                                   HederPosition: HorizontalAlign.Center);
            Grid.AddCheckboxColumn("PRV_HABILITADO", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* El boton se esconde a quien no puede, pero eso es cortesia, no
           seguridad: la potestad la valida el servidor en cada accion. */
        bool puedeEditar = Token.PuedeFuncion("Crear y editar");

        lnkNuevo.Visible = puedeEditar;
        lnkEliminar.Visible = Token.PuedeFuncion("Eliminar");

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        Proveedor filtro = new Proveedor();
        ProveedorController controller = new ProveedorController();

        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboTipo != null)
        {
            if (cboTipo.SelectedValue == "C") filtro.filtro_es_contratista = true;
            else if (cboTipo.SelectedValue == "R") filtro.filtro_es_proveedor_repuesto = true;
        }

        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetProveedores(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        Proveedor p = item.DataItem as Proveedor;

        if (p == null) return;

        // ---- Enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.prv_id));

        HyperLink editar = new HyperLink();
        editar.ID = "lnkEditar" + item.ItemIndex;
        editar.CssClass = "icono_Editar";
        editar.NavigateUrl = "javascript:void(0)";
        editar.Attributes.Add("onclick", "abrirProveedor('" + query + "')");

        item["PRV_ID"].Controls.Add(editar);

        /* ---- La empresa ----
           El nombre de fantasía arriba, que es como la gente la llama, y la
           razón social debajo. Al revés obligaría a leer "Servicios
           Industriales Antuco SpA" para reconocer a "Antuco". */
        string nombre = string.IsNullOrEmpty(p.prv_nombre_fantasia)
                      ? p.prv_razon_social : p.prv_nombre_fantasia;

        string empresa = "<strong>" + Server.HtmlEncode(nombre) + "</strong>";

        if (!string.IsNullOrEmpty(p.prv_nombre_fantasia))
            empresa += "<br /><span style=\"color:#777;font-size:11px;\">" +
                       Server.HtmlEncode(p.prv_razon_social) + "</span>";

        if (!string.IsNullOrEmpty(p.prv_giro))
            empresa += "<br /><span style=\"color:#999;font-size:11px;\">" +
                       Server.HtmlEncode(p.prv_giro) + "</span>";

        item["EMPRESA"].Text = empresa;

        // ---- Con quién se habla ----
        string contacto = "";

        if (!string.IsNullOrEmpty(p.prv_contacto))
            contacto += Server.HtmlEncode(p.prv_contacto);

        if (!string.IsNullOrEmpty(p.prv_email))
            contacto += (contacto.Length > 0 ? "<br />" : "") +
                        "<span style=\"color:#777;font-size:11px;\">" +
                        Server.HtmlEncode(p.prv_email) + "</span>";

        if (!string.IsNullOrEmpty(p.prv_telefono))
            contacto += (contacto.Length > 0 ? "<br />" : "") +
                        "<span style=\"color:#777;font-size:11px;\">" +
                        Server.HtmlEncode(p.prv_telefono) + "</span>";

        item["CONTACTO"].Text = contacto.Length > 0 ? contacto : "—";

        // ---- Qué es ----
        string tipo = "";

        if (p.prv_es_contratista)
            tipo += "<span class=\"grid-estado-chip is-info\">" +
                    "<i class=\"mdi mdi-hard-hat\"></i>Contratista</span>";

        if (p.prv_es_proveedor_repuesto)
            tipo += "<span class=\"grid-estado-chip is-acento\">" +
                    "<i class=\"mdi mdi-package-variant\"></i>Repuestos</span>";

        item["TIPO"].Text = tipo;

        /* ---- Cuánto se le ha comprado ----
           Dice de un vistazo si el proveedor está en uso, que es lo que
           determina si se puede eliminar. Enterarse recién al apretar el
           botón obliga a un viaje para nada. */
        string mov = "";

        if (p.lotes > 0)
            mov += p.lotes + (p.lotes == 1 ? " lote" : " lotes");

        if (p.servicios > 0)
            mov += (mov.Length > 0 ? "<br />" : "") +
                   p.servicios + (p.servicios == 1 ? " servicio" : " servicios");

        item["MOVIMIENTO"].Text = mov.Length > 0
            ? mov
            : "<span style=\"color:#aaa;\">sin uso</span>";
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se comprueba en el SERVIDOR, no confiando en que el botón
               estaba escondido: quien manda el postback a mano se salta el
               esconderlo. */
            if (!Token.PuedeFuncion("Eliminar"))
                throw new Exception("No tiene permiso para eliminar proveedores.");

            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            ProveedorController controller = new ProveedorController();

            List<string> fallidos = new List<string>();
            int borrados = 0;

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(indice)];

                int id = int.Parse(value["prv_id"].ToString());

                Respuesta respuesta = controller.DeleteProveedor(id);

                if (respuesta.error) fallidos.Add(respuesta.detalle);
                else borrados++;
            }

            /* Se informa lo que pasó con CADA uno. Mostrar solo el último
               resultado —como hacía el patrón heredado— dice "eliminado con
               éxito" cuando se seleccionaron tres y dos fueron rechazados. */
            if (fallidos.Count == 0)
            {
                Tools.tools.ClientAlert(
                    borrados == 1 ? "Proveedor eliminado con éxito."
                                  : borrados + " proveedores eliminados con éxito.", "ok", true);
            }
            else
            {
                string detalle = (borrados > 0 ? borrados + " eliminado(s). " : "") +
                                 string.Join(" ", fallidos.ToArray());

                Tools.tools.ClientAlert(detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
