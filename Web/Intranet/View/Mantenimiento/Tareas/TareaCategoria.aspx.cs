using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;

/// <summary>
/// Ficha de una categoría de tarea (HU-100). Alta y edición. La escritura la
/// habilita Token.Puede("CREAR EDITAR TAREAS") en el servidor (no se esconde el
/// botón por CSS) y el cliente sale de la sesión.
/// </summary>
public partial class View_Mantenimiento_Tareas_TareaCategoria : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
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
            TareaCategoria x = new TareaCategoriaController().GetTareaCategoria(Id);
            lblId.Text = Id.ToString();
            txtCodigo.Text = x.tca_codigo;
            txtNombre.Text = x.tca_nombre;
            txtColor.Text = x.tca_color;
            txtOrden.Text = x.tca_orden != null ? x.tca_orden.ToString() : "";
            rdbSi.Checked = x.tca_habilitado;
            rdbNo.Checked = !x.tca_habilitado;
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR TAREAS");

        // El código no se cambia al editar: identifica la categoría.
        txtCodigo.ReadOnly = Id > 0 || !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtColor.ReadOnly = !puedeEditar;
        txtOrden.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            // El servidor decide, no el botón.
            if (!Token.Puede("CREAR EDITAR TAREAS"))
            {
                Tools.tools.ClientAlert("No tiene permiso para administrar categorías de tarea.", "alerta");
                return;
            }

            TareaCategoria x = new TareaCategoria();
            TareaCategoriaController c = new TareaCategoriaController();

            x.tca_id = Id;
            x.tca_cliente = SitioBase.Session.ClienteId();
            x.tca_codigo = txtCodigo.Text.Trim();
            x.tca_nombre = txtNombre.Text.Trim();
            x.tca_color = string.IsNullOrEmpty(txtColor.Text.Trim()) ? null : txtColor.Text.Trim();
            int orden;
            x.tca_orden = int.TryParse(txtOrden.Text.Trim(), out orden) ? (int?)orden : null;
            x.tca_habilitado = rdbSi.Checked;

            Respuesta r = (Id > 0) ? c.UpdateTareaCategoria(x) : c.InsertTareaCategoria(x);

            if (!r.error)
            {
                Id = r.codigo;
                Tools.tools.ClientAlert(r.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(r.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
