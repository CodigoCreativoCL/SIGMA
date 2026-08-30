using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using Sigma.Model;
using Sigma.Controller;
using SitioBase;

/// <summary>
/// CODE-BEHIND DEL LISTADO DE PRODUCTO.
///
/// PATRON (ver PATRON_MVC.md seccion 4, PATRON_CONTROLES.md seccion 1,
/// PATRON_GRID_EVENTS.md secciones 2-4):
///  1. Clase partial que hereda de System.Web.UI.UserControl.
///     El nombre = ruta del archivo con "_".
///  2. Las propiedades publicas se guardan en ViewState, NO en campos privados.
///  3. Las columnas del grid se construyen por codigo en !IsPostBack.
///  4. La carga de datos va en Page_PreRender, no en Page_Load.
///  5. El code-behind NUNCA toca la base de datos: siempre pasa por el Controller.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class View_Inventario_Controls_Producto_Productos : System.Web.UI.UserControl
{
    #region PROPIEDADES (siempre en ViewState)

    /// <summary>Modo solo lectura: oculta la barra de comandos del grid.</summary>
    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    /// <summary>Ruta del formulario. La setea la pagina padre (.aspx).</summary>
    public string URLNuevoProducto
    {
        get { return ViewState["URLNuevoProducto"] == null ? "" : ViewState["URLNuevoProducto"].ToString(); }
        set { ViewState["URLNuevoProducto"] = value; }
    }

    // --- Propiedades de SEGURIDAD que setea la pagina padre desde SitioBase.Paginas ---

    /// <summary>Id de la funcion "Ver todo" del menu.</summary>
    public int Ver_Todo
    {
        get { return ViewState["Ver_Todo"] == null ? 0 : (int)ViewState["Ver_Todo"]; }
        set { ViewState["Ver_Todo"] = value; }
    }

    /// <summary>Id de la funcion "Crear/Editar": si no la tiene, el grid va en ReadOnly.</summary>
    public int Crear_Editar
    {
        get { return ViewState["Crear_Editar"] == null ? 0 : (int)ViewState["Crear_Editar"]; }
        set { ViewState["Crear_Editar"] = value; }
    }

    #endregion

    #region CICLO DE VIDA

    /// <summary>
    /// PreRender: ultimo evento antes de renderizar. Cargar aqui garantiza
    /// que el grid muestre el resultado de los clicks ya procesados.
    /// </summary>
    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            // --- Construccion de columnas. Solo la primera vez. ---

            Grid.AddSelectColumn();                         // checkbox de seleccion por fila
            Grid.AddColumn("pro_id", "", Width: "3%");      // celda donde se inyecta el link Editar
            Grid.AddColumn("pro_codigo", "CODIGO", Width: "10%");
            Grid.AddColumn("pro_nombre", "NOMBRE", Width: "23%");
            Grid.AddColumn("cat_nombre", "CATEGORIA", Width: "15%");
            Grid.AddColumn("prv_nombre", "PROVEEDOR", Width: "15%");
            Grid.AddColumn("pro_precio", "PRECIO", Width: "10%", Align: HorizontalAlign.Right);
            Grid.AddColumn("pro_stock", "STOCK", Width: "10%", Align: HorizontalAlign.Right);
            Grid.AddColumn("pro_vencimiento", "VENCIMIENTO", Width: "12%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddCheckboxColumn("pro_habilitado", "HABILITADO");
        }

        // En solo lectura se oculta toda la barra de comandos.
        if (ReadOnly)
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();

        // Registra el script que permite refresh() desde JS (__doPostBack).
        Tools.tools.RegisterPostBackScript(Grid);
    }

    #endregion

    #region CARGA DE DATOS

    /// <summary>
    /// Arma el Model de filtros y se lo entrega al Controller.
    /// Aqui NO hay SQL: solo se traducen los controles de pantalla a filtros.
    /// </summary>
    protected void CargarGrid()
    {
        ProductoController productoController = new ProductoController();
        Producto filtro = new Producto();

        // Texto libre de la barra de filtros comun.
        filtro.filtro = wucFiltro.Filtro();

        // Controles que viven dentro del UserControl de filtro:
        // se buscan con FindControl y se ignoran si no existen.
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (cboHabilitado != null && !string.IsNullOrEmpty(cboHabilitado.SelectedValue))
            filtro.filtro_habilitado = bool.Parse(cboHabilitado.SelectedValue);

        RadComboBox2 cboCategoria = (RadComboBox2)wucFiltro.FindControl("cboCategoria");
        if (cboCategoria != null && !string.IsNullOrEmpty(cboCategoria.SelectedValue))
            filtro.filtro_categoria = int.Parse(cboCategoria.SelectedValue);

        RadComboBox2 cboProveedor = (RadComboBox2)wucFiltro.FindControl("cboProveedor");
        if (cboProveedor != null && !string.IsNullOrEmpty(cboProveedor.SelectedValue))
            filtro.filtro_proveedor = int.Parse(cboProveedor.SelectedValue);

        // Unica llamada a datos de todo el archivo.
        Grid.DataSource = productoController.GetProductos(filtro);
    }

    #endregion

    #region EVENTOS DEL GRID

    /// <summary>
    /// Se ejecuta UNA VEZ POR FILA ya con datos.
    /// Aqui se inyecta el link "Editar" que abre el formulario.
    ///
    /// El id NO viaja en claro por la URL: se cifra con Tools.Crypto.Encrypt
    /// para que nadie pueda editar otro registro cambiando el numero a mano.
    /// </summary>
    protected void rgrProductos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        // Solo filas de datos: ni encabezado, ni footer, ni paginador.
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (e.Item is GridDataItem)
            {
                GridDataItem item = e.Item as GridDataItem;

                // La columna debe estar declarada en DataKeyNames del MasterTableView.
                string id = item.GetDataKeyValue("pro_id").ToString();

                string query = Server.UrlEncode(
                    Tools.Crypto.Encrypt("IdProducto=" + id + "&ReadOnly=" + ReadOnly));

                // Para NAVEGAR se usa HyperLink (sin postback), no LinkButton.
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirProducto('" + query + "')");

                item["pro_id"].Controls.Add(Editar);
            }
        }
    }

    /// <summary>
    /// Accion masiva sobre las filas seleccionadas.
    /// Patron: validar seleccion -> recorrer SelectedIndexes -> llamar al Controller
    /// -> avisar con Tools.tools.ClientAlert.
    /// </summary>
    protected void lnkDeshabilitar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            Respuesta respuesta = new Respuesta();
            ProductoController productoController = new ProductoController();

            foreach (string idx in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(idx)];
                int id = int.Parse(value["pro_id"].ToString());

                Producto producto = new Producto { pro_id = id };
                respuesta = productoController.DeshabilitarProducto(producto);
            }

            // El tercer parametro true cierra el modal / dispara refresh().
            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    #endregion
}
