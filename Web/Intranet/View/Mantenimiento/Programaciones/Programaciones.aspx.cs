using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de programaciones (HU-070 a HU-075, bloques 103-107).
///
/// EL CLIENTE SALE DE LA SESION, NUNCA DE LA PANTALLA
///   El controlador pasa Session.ClienteId() a SEL_PROGRAMACION y ese
///   parametro no es opcional. Los SPs de detalle lo vuelven a exigir, asi
///   que un id escrito a mano en la URL no alcanza para ver la programacion
///   de otra empresa.
///
/// ELIMINAR NO BORRA
///   Deshabilita. Es literalmente el criterio HU-076 #4: "deja de generar
///   ocurrencias nuevas Y las ya generadas se conservan". Un DELETE fisico
///   se llevaria por delante el historial del trabajo hecho.
///
/// LA COLUMNA "PROXIMA"
///   Sale de FNC_PROGRAMACION_FECHAS, que es un calculo y no una tabla. Se
///   pide UNA fecha por fila —no doce— porque el listado solo necesita saber
///   si la regla esta produciendo algo. Medidor y condicion no proyectan:
///   dependen de una lectura que todavia no ocurrio, y ahi la celda lo dice
///   en vez de quedar vacia como si estuviera rota.
/// </summary>
public partial class View_Mantenimiento_Programaciones_Programaciones : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("PRO_ID", "", Width: "3%");
            Grid.AddTemplateColumn("NOMBRE", "", "PROGRAMACIÓN", Width: "30%");
            Grid.AddTemplateColumn("REGLA", "", "REGLA", Width: "22%");
            Grid.AddTemplateColumn("VIGENCIA", "", "VIGENCIA", Width: "20%");
            Grid.AddTemplateColumn("PROXIMA", "", "PRÓXIMA", Width: "15%",
                                   ItemPosition: HorizontalAlign.Center,
                                   HederPosition: HorizontalAlign.Center);
            Grid.AddCheckboxColumn("PRO_HABILITADO", "HABILITADO");

            CargarCombos();
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* El boton se esconde a quien no puede, pero eso es cortesia, no
           seguridad: la potestad la valida el servidor en cada accion. */
        lnkNuevo.Visible = Token.PuedeFuncion("Crear y editar");
        lnkEliminar.Visible = Token.PuedeFuncion("Eliminar");

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    /// <summary>
    /// El combo de tipo se llena del catalogo y no se escribe en el markup:
    /// los seis valores viven en Programacion_Tipo y una lista fija en el
    /// .aspx queda vieja el dia que se agregue uno.
    /// </summary>
    protected void CargarCombos()
    {
        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");

        if (cboTipo == null) return;

        ProgramacionController controller = new ProgramacionController();
        List<CatalogoItem> tipos = controller.GetCatalogo("PROGRAMACION_TIPO");

        cboTipo.Items.Clear();
        cboTipo.Items.Add(new RadComboBoxItem("Todos", ""));

        if (tipos != null)
            foreach (CatalogoItem t in tipos)
                cboTipo.Items.Add(new RadComboBoxItem(t.nombre, t.id.ToString()));
    }

    protected void CargarGrid()
    {
        Programacion filtro = new Programacion();
        ProgramacionController controller = new ProgramacionController();

        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboTipo != null && !string.IsNullOrEmpty(cboTipo.SelectedValue))
        {
            int tipo;
            if (int.TryParse(cboTipo.SelectedValue, out tipo)) filtro.filtro_tipo = tipo;
        }

        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetProgramaciones(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        Programacion p = item.DataItem as Programacion;

        if (p == null) return;

        // ---- Enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.pro_id));

        HyperLink editar = new HyperLink();
        editar.ID = "lnkEditar" + item.ItemIndex;
        editar.CssClass = "icono_Editar";
        editar.NavigateUrl = "javascript:void(0)";
        editar.Attributes.Add("onclick", "abrirProgramacion('" + query + "')");

        item["PRO_ID"].Controls.Add(editar);

        // ---- Qué se programa ----
        string nombre = "<strong>" + Server.HtmlEncode(p.pro_nombre) + "</strong>";

        nombre += "<br /><span class=\"grid-estado-chip is-info\">" +
                  Server.HtmlEncode(p.tipo_nombre) + "</span>";

        if (p.ocurrencias > 0)
            nombre += " <span style=\"color:#777;font-size:11px;\">" + p.ocurrencias +
                      (p.ocurrencias == 1 ? " ocurrencia" : " ocurrencias") + "</span>";

        item["NOMBRE"].Text = nombre;

        // ---- La regla, en una línea ----
        string regla = string.IsNullOrEmpty(p.detalle)
                     ? "<span style=\"color:#c0392b;\">sin definir</span>"
                     : Server.HtmlEncode(p.detalle);

        if (p.exclusiones > 0)
            regla += "<br /><span style=\"color:#777;font-size:11px;\">" + p.exclusiones +
                     (p.exclusiones == 1 ? " exclusión" : " exclusiones") + "</span>";

        item["REGLA"].Text = regla;

        // ---- Desde cuándo hasta cuándo ----
        string vigencia = p.pro_fecha_inicio != null
                        ? p.pro_fecha_inicio.Value.ToString("dd-MM-yyyy") : "—";

        vigencia += p.pro_fecha_fin != null
                  ? " al " + p.pro_fecha_fin.Value.ToString("dd-MM-yyyy")
                  : " <span style=\"color:#777;\">en adelante</span>";

        if (!p.vigente)
            vigencia += "<br /><span class=\"grid-estado-chip is-alerta\">Fuera de vigencia</span>";

        item["VIGENCIA"].Text = vigencia;

        /* ---- La próxima fecha ----
           Es un cálculo, no un dato guardado. Se pide una sola por fila. */
        string proxima;

        if (p.tipo_codigo == "MEDIDOR" || p.tipo_codigo == "CONDICION")
        {
            /* No tienen fecha hasta que llegue la lectura. Decirlo es mejor
               que dejar la celda vacía, que se lee como "está rota". */
            proxima = "<span style=\"color:#777;font-size:11px;\">según medición</span>";
        }
        else if (!p.pro_habilitado)
        {
            proxima = "<span style=\"color:#aaa;\">—</span>";
        }
        else
        {
            ProgramacionController controller = new ProgramacionController();
            List<ProgramacionProyeccion> fechas = controller.GetProyeccion(p.pro_id, 1);

            if (fechas != null && fechas.Count > 0)
            {
                proxima = fechas[0].fecha.ToString("dd-MM-yyyy");

                if (fechas[0].desplazada)
                    proxima += "<br /><span style=\"color:#777;font-size:11px;\" title=\"" +
                               Server.HtmlEncode(fechas[0].motivo ?? "") + "\">desplazada</span>";
            }
            else
            {
                proxima = "<span style=\"color:#c0392b;font-size:11px;\">no produce fechas</span>";
            }
        }

        item["PROXIMA"].Text = proxima;
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se comprueba en el SERVIDOR, no confiando en que el botón
               estaba escondido: quien manda el postback a mano se lo salta. */
            if (!Token.PuedeFuncion("Eliminar"))
                throw new Exception("No tiene permiso para eliminar programaciones.");

            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            ProgramacionController controller = new ProgramacionController();

            List<string> fallidos = new List<string>();
            int borrados = 0;

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(indice)];

                int id = int.Parse(value["pro_id"].ToString());

                Respuesta respuesta = controller.DeleteProgramacion(id);

                if (respuesta.error) fallidos.Add(respuesta.detalle);
                else borrados++;
            }

            /* Se informa lo que pasó con CADA una. Mostrar solo el último
               resultado diría "eliminada con éxito" cuando se seleccionaron
               tres y dos fueron rechazadas. */
            if (fallidos.Count == 0)
            {
                Tools.tools.ClientAlert(
                    borrados == 1 ? "Programación eliminada con éxito."
                                  : borrados + " programaciones eliminadas con éxito.", "ok", true);
            }
            else
            {
                string detalle = (borrados > 0 ? borrados + " eliminada(s). " : "") +
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
