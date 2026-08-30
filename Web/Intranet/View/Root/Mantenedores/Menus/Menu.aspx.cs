using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using Telerik.Web.UI;

public partial class View_Root_Mantenedores_Menu : System.Web.UI.Page
{
    private MantenedorMenusController controller = new MantenedorMenusController();

    public int Id
    {
        get { return Convert.ToInt32(ViewState["Id"]); }
        set { ViewState.Add("Id", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (Request.QueryString["query"] != null)
            {
                string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

                foreach (string arr in query)
                {
                    string[] array = arr.ToString().Split('=');
                    if (array[0].ToString() == "Id")
                        Id = Int32.Parse(array[1].ToString());
                }
            }

            CargarCombos();
            CargarDatos();
        }
    }

    protected void CargarCombos()
    {
        cboPadre.Items.Clear();
        cboPadre.Items.Add(new RadComboBoxItem("Raíz (sin padre)", "0"));

        foreach (Menus m in controller.GetMenus(null))
        {
            if (m.mnu_id == Id) continue;   // no puede ser padre de si mismo
            cboPadre.Items.Add(new RadComboBoxItem(m.mnu_nombre + "  [" + m.mnu_id + "]", m.mnu_id.ToString()));
        }

        cboPermiso.Items.Clear();
        cboPermiso.Items.Add(new RadComboBoxItem("Sin permiso (solo carpetas)", "0"));

        foreach (Permiso p in controller.GetPermisos(null))
            cboPermiso.Items.Add(new RadComboBoxItem(p.prm_modulo + " · " + p.prm_codigo, p.prm_id.ToString()));
    }

    protected void CargarDatos()
    {
        if (Id <= 0)
        {
            lblId.Text = "Nuevo";
            txtLink.Text = "#";
            txtNivel.Text = "4";
            txtOrden.Text = "1";
            return;
        }

        Menus menu = controller.GetMenu(Id);
        if (menu == null) return;

        lblId.Text = menu.mnu_id.ToString();
        txtNombre.Text = menu.mnu_nombre;
        txtDescripcion.Text = menu.mnu_descripcion;
        txtNivel.Text = menu.mnu_nivel.ToString();
        txtOrden.Text = menu.mnu_orden.ToString();
        txtLink.Text = menu.mnu_link;
        txtIcon.Text = menu.mnu_icon;

        Seleccionar(cboPadre, menu.mnu_padre.ToString());
        Seleccionar(cboPermiso, menu.mnu_permiso.ToString());

        rdbSi.Checked = menu.mnu_visible;
        rdbNo.Checked = !menu.mnu_visible;
    }

    private void Seleccionar(RadComboBox2 combo, string valor)
    {
        RadComboBoxItem item = combo.FindItemByValue(valor);
        if (item != null) item.Selected = true;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            Menus menu = new Menus();
            menu.mnu_id = Id;
            menu.mnu_nombre = txtNombre.Text;
            menu.mnu_descripcion = txtDescripcion.Text;
            menu.mnu_nivel = ParseInt(txtNivel.Text, 4);
            menu.mnu_padre = ParseInt(cboPadre.SelectedValue, 0);
            menu.mnu_orden = ParseInt(txtOrden.Text, 1);
            menu.mnu_link = string.IsNullOrEmpty(txtLink.Text) ? "#" : txtLink.Text.Trim();
            menu.mnu_icon = txtIcon.Text;
            menu.mnu_permiso = ParseInt(cboPermiso.SelectedValue, 0);
            menu.mnu_visible = rdbSi.Checked;

            // El SP tambien lo valida, pero avisar aca evita el viaje.
            if (menu.mnu_link != "#" && menu.mnu_permiso == 0)
            {
                Tools.tools.ClientAlert("Una página debe tener un permiso asociado. Sin él, solo la vería el perfil Root.", "alerta");
                return;
            }

            Respuesta respuesta;

            if (Id > 0)
            {
                respuesta = controller.UpdateMenu(menu);
            }
            else
            {
                respuesta = controller.InsertMenu(menu);
                if (!respuesta.error) Id = respuesta.codigo;
            }

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

    private int ParseInt(string valor, int porDefecto)
    {
        int n;
        return int.TryParse(valor, out n) ? n : porDefecto;
    }
}
