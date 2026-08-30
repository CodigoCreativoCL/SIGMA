using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un centro de costo (HU-013).
/// </summary>
public partial class View_Organizacion_CentrosCosto_CentroCosto : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack && Request.QueryString["query"] != null)
        {
            string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "Id":
                        Id = Int32.Parse(array[1].ToString());
                        break;
                }
            }
        }
    }

    /// <summary>
    /// Llena el combo de centro superior.
    ///
    /// Al editar se excluye el propio registro: un centro no puede ser su
    /// propio padre. Los descendientes tambien quedarian mal, pero de eso
    /// se encarga UPD_CENTRO_COSTO, que recorre el arbol completo. Aqui se
    /// quita solo el caso evidente para no ofrecer una opcion que la base
    /// va a rechazar.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                switch (ctrl.ID)
                {
                    case "cboPadre":

                        CentroCosto filtro = new CentroCosto();
                        filtro.cco_cliente = SitioBase.Session.ClienteId();
                        filtro.filtro_habilitado = true;

                        CentroCostoController controller = new CentroCostoController();
                        List<CentroCosto> lista = controller.GetCentrosCosto(filtro);

                        ctrl.Items.Add(new RadComboBoxItem("Sin centro superior", ""));
                        ctrl.AppendDataBoundItems = true;

                        if (lista != null)
                        {
                            if (Id > 0) lista.RemoveAll(x => x.cco_id == Id);

                            ctrl.DataSource = lista;
                            ctrl.DataValueField = "cco_id";
                            ctrl.DataTextField = "ruta";
                            ctrl.DataBind();
                        }

                        break;
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            CentroCostoController controller = new CentroCostoController();
            CentroCosto entidad = controller.GetCentroCosto(new CentroCosto { cco_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = entidad.cco_codigo;
            txtNombre.Text = entidad.cco_nombre;

            if (entidad.cco_centro_costo_padre != null)
                cboPadre.SelectedValue = entidad.cco_centro_costo_padre.ToString();

            rdbSi.Checked = entidad.cco_habilitado;
            rdbNo.Checked = !entidad.cco_habilitado;
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR CENTROS COSTO");

        txtCodigo.ReadOnly = !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        cboPadre.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            CentroCosto entidad = new CentroCosto();
            CentroCostoController controller = new CentroCostoController();

            entidad.cco_id = Id;
            entidad.cco_cliente = SitioBase.Session.ClienteId();
            entidad.cco_codigo = txtCodigo.Text.Trim();
            entidad.cco_nombre = txtNombre.Text.Trim();
            entidad.cco_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboPadre.SelectedValue))
                entidad.cco_centro_costo_padre = int.Parse(cboPadre.SelectedValue);
            else
                // Combo vacio al editar significa "subelo al primer nivel",
                // no "no toques el padre". Sin esta bandera el SP conserva
                // el que ya tenia y el cambio se pierde en silencio.
                entidad.quita_padre = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateCentroCosto(entidad)
                : controller.InsertCentroCosto(entidad);

            if (!respuesta.error)
            {
                Id = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}
