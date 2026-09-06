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
/// Listado de atributos técnicos (HU-032), en ÁRBOL: cada tipo de activo es
/// una fila "grupo" plegable y debajo cuelgan sus atributos. El SEL trae los
/// del cliente MÁS los globales de la plataforma (estos se ven pero no se
/// editan aquí). Filtra siempre por el cliente en sesión.
/// </summary>
public partial class View_Activos_Atributos_AtributoTecnicos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("ate_id", "", Width: "4%");         // lupa (editar)
            Grid.AddColumn("nivel", "", Width: "4%");          // chevron
            Grid.AddColumn("ATE_CODIGO", "CÓDIGO", Width: "16%");
            Grid.AddColumn("ATE_NOMBRE", "NOMBRE", Width: "30%"); // tipo (padre) / atributo (hijo)
            Grid.AddColumn("TIPO_DATO_NOMBRE", "TIPO DE DATO", Width: "22%");
            Grid.AddColumn("es_global", "ORIGEN", Width: "12%");
            Grid.AddCheckboxColumn("ATE_HABILITADO", "HABILITADO");
        }

        // Es un ÁRBOL: las filas deben quedar en su orden (grupo y luego sus
        // atributos). Lo que rompería el orden es ORDENAR por columna, así que
        // solo se desactiva el ordenamiento. El paginado se deja como los demás
        // listados (paginador visible, 25 por página por defecto).
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

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        AtributoTecnico filtro = new AtributoTecnico();
        AtributoTecnicoController controller = new AtributoTecnicoController();

        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        List<AtributoTecnico> lista = controller.GetAtributos(filtro) ?? new List<AtributoTecnico>();

        // Lookup id de tipo -> código/nombre del tipo de activo, para mostrar el
        // código real del tipo (ATI-…) en la fila-grupo, igual que en Tipos.
        Dictionary<int, ActivoTipo> tipos = new Dictionary<int, ActivoTipo>();
        List<ActivoTipo> lt = new ActivoTipoController().GetActivoTipos(
            new ActivoTipo { filtro_cliente = SitioBase.Session.ClienteId() }) ?? new List<ActivoTipo>();
        foreach (ActivoTipo t in lt) if (!tipos.ContainsKey(t.ati_id)) tipos[t.ati_id] = t;

        Grid.DataSource = ConstruirArbol(lista, tipos);
    }

    /// <summary>
    /// Arma las filas del árbol: por cada tipo de activo (ordenado) una fila
    /// "grupo" (nivel 1, con el código y nombre del tipo) y debajo sus atributos
    /// (nivel 2). Los grupos usan un ate_id negativo para no colisionar con los
    /// reales ni permitir edición.
    /// </summary>
    private List<AtributoFila> ConstruirArbol(List<AtributoTecnico> lista, Dictionary<int, ActivoTipo> tipos)
    {
        List<AtributoFila> filas = new List<AtributoFila>();
        int grupoId = 0;

        var grupos = lista
            .GroupBy(a => a.ate_activo_tipo ?? 0)
            .OrderBy(g => g.First().tipo_nombre);

        foreach (var g in grupos)
        {
            grupoId++;
            int tipoId = g.Key;
            string tipoNombre = tipos.ContainsKey(tipoId) ? tipos[tipoId].ati_nombre
                              : (string.IsNullOrEmpty(g.First().tipo_nombre) ? "General (todos los tipos)" : g.First().tipo_nombre);
            string tipoCodigo = tipos.ContainsKey(tipoId) ? tipos[tipoId].ati_codigo : "";

            filas.Add(new AtributoFila
            {
                ate_id = -grupoId,          // negativo = fila grupo
                nivel = 1,
                es_grupo = true,
                tipo_nombre = tipoNombre,
                ate_codigo = tipoCodigo,    // código del TIPO (ATI-…)
                ate_habilitado = true
            });

            foreach (AtributoTecnico a in g.OrderBy(x => x.ate_nombre))
            {
                filas.Add(new AtributoFila
                {
                    ate_id = a.ate_id,
                    nivel = 2,
                    es_grupo = false,
                    tipo_nombre = a.tipo_nombre,
                    ate_codigo = a.ate_codigo,
                    ate_nombre = a.ate_nombre,
                    tipo_dato_nombre = a.tipo_dato_nombre,
                    es_global = a.es_global,
                    ate_habilitado = a.ate_habilitado
                });
            }
        }
        return filas;
    }

    protected void rgrAtributos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (!(e.Item is GridDataItem)) return;
        GridDataItem item = (GridDataItem)e.Item;

        int nivel = 1;
        object valorNivel = DataBinder.Eval(item.DataItem, "nivel");
        if (valorNivel != null) int.TryParse(valorNivel.ToString(), out nivel);
        bool esGrupo = Convert.ToBoolean(DataBinder.Eval(item.DataItem, "es_grupo"));

        item.Attributes["data-nivel"] = nivel.ToString();

        // El chevron vive en su propia columna; el JS lo enciende solo si la
        // fila tiene hijos. (Mismo patrón que el árbol de Tipos de activo.)
        TableCell celdaBtn = item["nivel"];
        celdaBtn.HorizontalAlign = HorizontalAlign.Center;
        celdaBtn.Text = "<span class=\"sigma-tree-btn\"></span>";

        // La columna NOMBRE la comparten padre (tipo) e hijo (atributo),
        // indentando por nivel — igual que en Tipos de activo.
        TableCell celda = item["ATE_NOMBRE"];
        celda.Style["padding-left"] = "0";
        int indent = (nivel - 1) * 28;
        string elbow = nivel > 1 ? "<span class=\"sigma-tree-elbow\"></span>" : "";

        if (esGrupo)
        {
            // Fila GRUPO (el tipo): nombre en negrita en la columna NOMBRE; el
            // resto de columnas en blanco (un tipo no tiene código de atributo).
            string tipo = Convert.ToString(DataBinder.Eval(item.DataItem, "tipo_nombre"));
            celda.Text =
                "<span class=\"sigma-tree-item\" style=\"padding-left:" + indent + "px\">" +
                    "<span class=\"sigma-tree-nom sigma-grp\">" + Server.HtmlEncode(tipo) + "</span>" +
                "</span>";

            LimpiarCelda(item, "ate_id");
            LimpiarCelda(item, "TIPO_DATO_NOMBRE");
            LimpiarCelda(item, "es_global");
            LimpiarCelda(item, "ATE_HABILITADO");
            if (item.Cells.Count > 0) item.Cells[0].Controls.Clear();  // sin checkbox de selección
            return;
        }

        // Fila HIJO (atributo): nombre indentado con conector de rama, y la
        // lupa para editar si no es global.
        celda.Text =
            "<span class=\"sigma-tree-item\" style=\"padding-left:" + indent + "px\">" +
                elbow +
                "<span class=\"sigma-tree-nom\">" + celda.Text + "</span>" +
            "</span>";

        bool esGlobal = Convert.ToBoolean(DataBinder.Eval(item.DataItem, "es_global"));
        item["es_global"].Text = esGlobal ? "Global" : "Del cliente";

        // Los atributos globales de la plataforma no se editan aquí.
        if (esGlobal) return;

        string ateId = item.GetDataKeyValue("ate_id").ToString();
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + ateId));
        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditar" + ateId;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirAtributo('" + query + "')");
        item["ate_id"].Controls.Add(Editar);
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
                AtributoTecnicoController controller = new AtributoTecnicoController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                    int ate = Int32.Parse(value["ate_id"].ToString());
                    if (ate <= 0) continue;   // fila grupo: no se elimina
                    AtributoTecnico entidad = new AtributoTecnico();
                    entidad.ate_id = ate;
                    respuesta = controller.DeleteAtributo(entidad);
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

/// <summary>Fila del árbol de atributos: grupo (tipo) o atributo (hijo).</summary>
[Serializable]
public class AtributoFila
{
    public int ate_id { get; set; }
    public int nivel { get; set; }
    public bool es_grupo { get; set; }
    public int cantidad { get; set; }
    public string tipo_nombre { get; set; }
    public string ate_codigo { get; set; }
    public string ate_nombre { get; set; }
    public string tipo_dato_nombre { get; set; }
    public bool es_global { get; set; }
    public bool ate_habilitado { get; set; }
}
