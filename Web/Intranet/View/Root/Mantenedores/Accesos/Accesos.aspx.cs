using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web.Script.Services;
using System.Web.Services;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;
using SitioBase;

public partial class View_Mantenedores_Accesos_Accesos : System.Web.UI.Page
{
    private AccesoController controller = new AccesoController();
    private DataTable dt = new DataTable();

    public int idMenu
    {
        get { return Convert.ToInt32(ViewState["idMenu"]); }
        set { ViewState.Add("idMenu", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {

        if (!IsPostBack)
            CargarTreview();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        Seguridad();
    }

    protected void Seguridad()
    {
        MenuPerfil ver = new MenuPerfil();

        //ver.mpe_menu = (int)Inspect.Urls.AccesoPerfiles.Ver;
        //Inspect.Token.SecurityManagerVer(ver);
    }

    protected void CargarTreview()
    {
        trvPaginas.Nodes.Clear();

        List<Menus> menus = controller.GetMenusAdministracion();

        int count = 1;
        foreach (Menus item in menus.Where(x => x.mnu_nivel == 1))
        {
            RadTreeNode node = new RadTreeNode();

            node.Text = item.mnu_nombre;
            node.Value = item.mnu_id.ToString();
            node.Expanded = true;

            if (count == 1)
            {
                node.Selected = true;
                lblMenus.Text = node.Text;
                CargarGrid(int.Parse(node.Value));
            }

            count++;
            addNodes(node, menus, item.mnu_id);

            trvPaginas.Nodes.Add(node);
        }

        trvPaginas.CollapseAllNodes();
    }

    protected void addNodes(RadTreeNode node, List<Menus> menus, int idNode)
    {
        foreach (Menus item in menus.Where(x => x.mnu_padre == idNode))
        {
            RadTreeNode nNode = new RadTreeNode();
            nNode.Text = item.mnu_nombre;
            nNode.Value = item.mnu_id.ToString();
            nNode.Expanded = true;

            addNodes(nNode, menus, item.mnu_id);

            node.Nodes.Add(nNode);
        }
    }

    protected void trvProductos_OnNodeClick(object sender, RadTreeNodeEventArgs e)
    {
        e.Node.Selected = true;
        lblMenus.Text = e.Node.Text;
        CargarGrid(int.Parse(e.Node.Value));
    }

    protected void CargarGrid(int id)
    {
        idMenu = id;
        rgrPermisos.Columns.Clear();

        Menus menu = new Menus();
        menu.mnu_id = id;

        rgrPermisos.AddColumn("PERFIL", "PERFIL", Wrap: true, Width: "37%");
        rgrPermisos.AllowSorting = false;
        rgrPermisos.ClientSettings.AllowColumnsReorder = false;
        rgrPermisos.ClientSettings.AllowDragToGroup = false;

        dt = controller.GetMenusFuncionesPerfiles(menu);

        string dataKeyNames = "per_id,";
        foreach (DataColumn column in dt.Columns)
        {
            if (column.ColumnName != "PER_ID" & column.ColumnName != "PERFIL")
            {
                string uniqueName = column.ColumnName.Replace(' ', '_');
                //string columnName = column.ColumnName.Split('_')[0];

                string columnName = column.ColumnName;

                rgrPermisos.AddTemplateColumn(uniqueName, "", columnName, Width: "7%", ItemPosition: System.Web.UI.WebControls.HorizontalAlign.Center);

                dataKeyNames += column.ColumnName + ",";
            }
        }

        dataKeyNames = dataKeyNames.Remove(dataKeyNames.Length - 1, 1);

        rgrPermisos.MasterTableView.DataKeyNames = dataKeyNames.Split(',');
        rgrPermisos.DataSource = dt;
        rgrPermisos.DataBind();
    }

    protected void rgrPermisos_OnItemCreated(object sender, GridItemEventArgs e)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = (e.Item as GridDataItem);

            foreach (DataColumn column in dt.Columns)
            {
                if (column.ColumnName != "PER_ID" & column.ColumnName != "PERFIL")
                {
                    string uniqueName = column.ColumnName.Replace(' ', '_');

                    CheckBox chk = new CheckBox();
                    chk.ID = "chk" + uniqueName;

                    item[uniqueName].Controls.Add(chk);
                }
            }

        }

        if (e.Item is GridHeaderItem)
        {
            GridHeaderItem item = (e.Item as GridHeaderItem);

            foreach (DataColumn column in dt.Columns)
            {
                if (column.ColumnName != "PER_ID" & column.ColumnName != "PERFIL")
                {
                    string uniqueName = column.ColumnName.Replace(' ', '_');
                    string nombre = column.ColumnName.Split('_')[0];

                    if (nombre == "Ver")
                    {
                        Label tooltip = new Label();
                        tooltip.Text = nombre;
                        tooltip.ToolTip = "Permite el acceso al módulo seleccionado";
                        item[uniqueName].Text = "";
                        item[uniqueName].Controls.Add(tooltip);
                    }

                    
                }
            }
        }
    }

    protected void rgrPermisos_ItemDataBound(object sender, GridItemEventArgs e)
    {

        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;

                string idPerfil = item.GetDataKeyValue("per_id").ToString();

                foreach (DataColumn column in dt.Columns)
                {
                    if (column.ColumnName != "PER_ID" & column.ColumnName != "PERFIL")
                    {
                        string uniqueName = column.ColumnName.Replace(' ', '_');
                        string idFuncion = column.ColumnName.Split('_')[1];

                        //CheckBox2 chk = (CheckBox2)item[uniqueName].FindControl("chk" + uniqueName);
                        CheckBox chk = (CheckBox)item[uniqueName].FindControl("chk" + uniqueName);

                        string cadena = Tools.Crypto.Encrypt("idPerfil=" + idPerfil + ";idFuncion=" + idFuncion + ";idMenu=" + idMenu);

                        chk.Attributes.Add("onclick", "GuardaPermisos('" + cadena + "','" + item.ItemIndex + "','" + chk.ID + "')");

                        bool checked1 = false;

                        if (item.GetDataKeyValue(column.ColumnName).ToString() == "1" || item.GetDataKeyValue(column.ColumnName).ToString() == "True")
                            checked1 = true;

                        chk.Checked = checked1; //bool.Parse(item.GetDataKeyValue(column.ColumnName).ToString());
                    }
                }

            }
        }
    }

    //GuardaPermiso
    [WebMethod]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public static string GuardaPermiso(string cadena, string val)
    {
        try
        {
            string[] query = Tools.Crypto.Decrypt(cadena).Split(';');

            int idPerfil = 0;
            int idFuncion = 0;
            int idMenu = 0;
            bool habilitado = bool.Parse(val);

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "idPerfil":
                        idPerfil = int.Parse(array[1].ToString());
                        break;

                    case "idFuncion":
                        idFuncion = int.Parse(array[1].ToString());
                        break;

                    case "idMenu":
                        idMenu = int.Parse(array[1].ToString());
                        break;

                }
            }

            string mensaje = string.Empty;
            Respuesta respuesta;
            AccesoController controller = new AccesoController();

            if (idFuncion == 0)
            {
                MenuPerfil menuPerfil = new MenuPerfil();
                menuPerfil.mpe_perfil = idPerfil;
                menuPerfil.mpe_menu = idMenu;
                menuPerfil.mpe_habilitado = habilitado;

                respuesta = controller.InsertMenuPerfil(menuPerfil);
                mensaje = respuesta.detalle;
            }
            else
            {
                MenuFuncionPerfil menuFuncionPerfil = new MenuFuncionPerfil();
                menuFuncionPerfil.mfp_perfil = idPerfil;
                menuFuncionPerfil.mfp_menu_funcion = idFuncion;
                menuFuncionPerfil.mfp_habilitado = habilitado;

                respuesta = controller.InsertMenuFuncionPerfil(menuFuncionPerfil);
                mensaje = respuesta.detalle;
            }

            return mensaje;


        }
        catch (Exception ex)
        {
            return "Error: " + ex.Message;
        }
    }
}