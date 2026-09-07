using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de pasos de procedimiento (HU-062), en ÁRBOL: cada procedimiento es
/// una fila "grupo" plegable y debajo cuelgan sus pasos EN ORDEN. El SEL trae
/// los pasos de los procedimientos del cliente MÁS los de los globales (estos se
/// ven pero no se editan aquí). La escritura la habilita la función
/// "Crear y editar" de la pantalla.
/// </summary>
public partial class View_Mantenimiento_Procedimientos_ProcedimientoPasos : System.Web.UI.Page
{
    /// <summary>El combo de procedimiento vive dentro del filtro (plantilla).</summary>
    private RadComboBox2 CboProc()
    {
        return (RadComboBox2)wucFiltro.FindControl("cboProcedimiento");
    }

    /// <summary>ClientID del combo de procedimiento, para el JS de "Nuevo".</summary>
    public string ProcCombo
    {
        get { RadComboBox2 c = CboProc(); return c != null ? c.ClientID : ""; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("ppa_id", "", Width: "4%");          // lupa (solo pasos)
            Grid.AddColumn("nivel", "", Width: "4%");           // chevron
            Grid.AddColumn("orden_txt", "ORDEN", Width: "6%");
            Grid.AddColumn("ppa_nombre", "PROCEDIMIENTO / PASO", Width: "30%"); // procedimiento (grupo) / paso (hijo)
            Grid.AddColumn("punto_txt", "PUNTO CONTROL", Width: "11%");
            Grid.AddColumn("medicion_txt", "MEDICIÓN", Width: "14%");
            Grid.AddColumn("min_txt", "MIN", Width: "5%");
            Grid.AddColumn("es_global", "ORIGEN", Width: "9%");
            Grid.AddCheckboxColumn("ppa_habilitado", "HABILITADO");
        }

        // Es un ÁRBOL ordenado por (procedimiento, orden): no se ordena por
        // columna para no romper esa lectura.
        Grid.AllowSorting = false;
        Grid.MasterTableView.AllowSorting = false;

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        if (!IsPostBack) CargarProcedimientos();

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    /// <summary>Combo de procedimientos DEL CLIENTE (a un global no se le agregan pasos).</summary>
    private void CargarProcedimientos()
    {
        RadComboBox2 cbo = CboProc();
        if (cbo == null) return;

        cbo.Items.Clear();
        cbo.Items.Add(new RadComboBoxItem("Todos los procedimientos", ""));
        cbo.AppendDataBoundItems = true;

        ProcedimientoController c = new ProcedimientoController();
        var lista = c.GetProcedimientos(new Procedimiento { filtro_cliente = SitioBase.Session.ClienteId() });
        if (lista != null)
            foreach (Procedimiento p in lista)
            {
                if (p.es_global) continue;   // a un procedimiento global no se le agregan pasos
                string txt = p.prc_codigo + " · " + p.prc_nombre + " (v" + p.prc_version + ")";
                cbo.Items.Add(new RadComboBoxItem(txt, p.prc_id.ToString()));
            }
    }

    protected void cboProcedimiento_SelectedIndexChanged(object sender, EventArgs e)
    {
        // El postback recarga la grilla con el procedimiento elegido.
    }

    protected void CargarGrid()
    {
        ProcedimientoPaso filtro = new ProcedimientoPaso();
        ProcedimientoPasoController controller = new ProcedimientoPasoController();

        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cbo = CboProc();
        if (cbo != null && cbo.SelectedValue != "")
            filtro.filtro_procedimiento = int.Parse(cbo.SelectedValue);

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        List<ProcedimientoPaso> lista = controller.GetPasos(filtro) ?? new List<ProcedimientoPaso>();
        Grid.DataSource = ConstruirArbol(lista);
    }

    /// <summary>
    /// Arma las filas del árbol: por cada procedimiento (ordenado) una fila
    /// "grupo" (nivel 1) y debajo sus pasos (nivel 2, en orden). Los grupos usan
    /// un ppa_id negativo para no colisionar con los reales ni permitir edición.
    /// </summary>
    private List<PasoFila> ConstruirArbol(List<ProcedimientoPaso> lista)
    {
        List<PasoFila> filas = new List<PasoFila>();
        int grupoId = 0;

        var grupos = lista
            .GroupBy(p => p.ppa_procedimiento)
            .OrderBy(g => g.First().procedimiento_codigo);

        foreach (var g in grupos)
        {
            grupoId++;
            ProcedimientoPaso cab = g.First();
            filas.Add(new PasoFila
            {
                ppa_id = -grupoId,          // negativo = fila grupo
                nivel = 1,
                es_grupo = true,
                procedimiento_codigo = cab.procedimiento_codigo,
                procedimiento_nombre = cab.procedimiento_nombre,
                es_global = cab.es_global,
                ppa_habilitado = true
            });

            foreach (ProcedimientoPaso p in g.OrderBy(x => x.ppa_orden))
            {
                filas.Add(new PasoFila
                {
                    ppa_id = p.ppa_id,
                    nivel = 2,
                    es_grupo = false,
                    ppa_nombre = p.ppa_nombre,
                    orden_txt = p.ppa_orden.ToString(),
                    punto_txt = p.ppa_es_punto_control ? "Sí" : "—",
                    medicion_txt = p.ppa_requiere_medicion
                        ? (string.IsNullOrEmpty(p.variable_nombre) ? "Sí" : p.variable_nombre) : "—",
                    min_txt = p.ppa_duracion_estimada_minuto != null ? p.ppa_duracion_estimada_minuto.ToString() : "",
                    es_global = p.es_global,
                    ppa_habilitado = p.ppa_habilitado
                });
            }
        }
        return filas;
    }

    protected void rgrPasos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (!(e.Item is GridDataItem)) return;
        GridDataItem item = (GridDataItem)e.Item;

        int nivel = 1;
        object valorNivel = DataBinder.Eval(item.DataItem, "nivel");
        if (valorNivel != null) int.TryParse(valorNivel.ToString(), out nivel);
        bool esGrupo = Convert.ToBoolean(DataBinder.Eval(item.DataItem, "es_grupo"));

        item.Attributes["data-nivel"] = nivel.ToString();

        // Chevron en su propia columna; el JS lo enciende solo si tiene hijos.
        TableCell celdaBtn = item["nivel"];
        celdaBtn.HorizontalAlign = HorizontalAlign.Center;
        celdaBtn.Text = "<span class=\"sigma-tree-btn\"></span>";

        // La columna PROCEDIMIENTO / PASO la comparten el grupo (procedimiento)
        // y el hijo (paso), indentando por nivel.
        TableCell celda = item["ppa_nombre"];
        celda.Style["padding-left"] = "0";
        int indent = (nivel - 1) * 28;

        if (esGrupo)
        {
            // Fila GRUPO (el procedimiento): su código y nombre; el resto en blanco.
            string cod = Convert.ToString(DataBinder.Eval(item.DataItem, "procedimiento_codigo"));
            string nom = Convert.ToString(DataBinder.Eval(item.DataItem, "procedimiento_nombre"));
            celda.Text =
                "<span class=\"sigma-tree-item\" style=\"padding-left:" + indent + "px\">" +
                    "<span class=\"sigma-tree-nom sigma-grp\">" + Server.HtmlEncode(cod) +
                        " · " + Server.HtmlEncode(nom) + "</span>" +
                "</span>";

            LimpiarCelda(item, "ppa_id");
            LimpiarCelda(item, "orden_txt");
            LimpiarCelda(item, "punto_txt");
            LimpiarCelda(item, "medicion_txt");
            LimpiarCelda(item, "min_txt");
            LimpiarCelda(item, "es_global");
            LimpiarCelda(item, "ppa_habilitado");
            if (item.Cells.Count > 0) item.Cells[0].Controls.Clear();  // sin checkbox de selección
            return;
        }

        // Fila HIJO (paso): nombre indentado con conector de rama.
        celda.Text =
            "<span class=\"sigma-tree-item\" style=\"padding-left:" + indent + "px\">" +
                "<span class=\"sigma-tree-elbow\"></span>" +
                "<span class=\"sigma-tree-nom\">" + celda.Text + "</span>" +
            "</span>";

        bool esGlobal = Convert.ToBoolean(DataBinder.Eval(item.DataItem, "es_global"));
        item["es_global"].Text = esGlobal ? "Global" : "Del cliente";

        // Los pasos de procedimientos globales no se editan aquí.
        if (esGlobal) return;

        string id = item.GetDataKeyValue("ppa_id").ToString();
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditar" + id;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirPaso('" + query + "')");
        item["ppa_id"].Controls.Add(Editar);
    }

    private void LimpiarCelda(GridDataItem item, string columna)
    {
        try
        {
            TableCell celda = item[columna];
            celda.Controls.Clear();
            celda.Text = "";
        }
        catch { }
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
            }
            else
            {
                Respuesta respuesta = new Respuesta();
                ProcedimientoPasoController controller = new ProcedimientoPasoController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                    int ppa = Int32.Parse(value["ppa_id"].ToString());
                    if (ppa <= 0) continue;   // fila grupo: no se elimina
                    ProcedimientoPaso entidad = new ProcedimientoPaso();
                    entidad.ppa_id = ppa;
                    respuesta = controller.DeletePaso(entidad);
                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}

/// <summary>Fila del árbol de pasos: grupo (procedimiento) o paso (hijo).</summary>
[Serializable]
public class PasoFila
{
    public int ppa_id { get; set; }
    public int nivel { get; set; }
    public bool es_grupo { get; set; }
    public string procedimiento_codigo { get; set; }
    public string procedimiento_nombre { get; set; }
    public string ppa_nombre { get; set; }
    public string orden_txt { get; set; }
    public string punto_txt { get; set; }
    public string medicion_txt { get; set; }
    public string min_txt { get; set; }
    public bool es_global { get; set; }
    public bool ppa_habilitado { get; set; }
}
