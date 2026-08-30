using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Registro de una especialidad y su certificación (HU-017).
/// </summary>
public partial class View_Organizacion_Especialidades_UsuarioEspecialidad : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
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
                    switch (array[0].ToString())
                    {
                        case "Id":
                            Id = Int32.Parse(array[1].ToString());
                            break;
                    }
                }
            }

            CargarUsuarios();
        }
    }

    protected void CargarUsuarios()
    {
        cboUsuario.Items.Clear();
        cboUsuario.Items.Add(new RadComboBoxItem("Seleccione...", ""));
        cboUsuario.AppendDataBoundItems = true;

        SqlCommand cmd = new SqlCommand();

        try
        {
            cmd.CommandText = "SEL_USUARIO_CLIENTE_LISTA";
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    cboUsuario.Items.Add(new RadComboBoxItem(
                        dr["USU_NOMBRE"].ToString() + " · " + dr["USU_CORREO"].ToString(),
                        dr["USU_ID"].ToString()));
                }
            }

            cmd.Connection.Close();
            cmd.Dispose();
        }
        catch (Exception ex)
        {
            if (cmd.Connection != null) cmd.Connection.Close();
            cmd.Dispose();
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                switch (ctrl.ID)
                {
                    case "cboEspecialidad":

                        Especialidad filtro = new Especialidad();
                        filtro.esp_cliente = SitioBase.Session.ClienteId();
                        filtro.filtro_habilitado = true;

                        UsuarioEspecialidadController controller = new UsuarioEspecialidadController();

                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = controller.GetEspecialidades(filtro);
                        ctrl.DataValueField = "esp_id";
                        ctrl.DataTextField = "esp_nombre";
                        ctrl.DataBind();
                        break;

                    case "cboNivel":

                        // El nivel es un catálogo del sistema: se lee por el
                        // registro, igual que zonas horarias o tipos de área.
                        CatalogoController ctrlCatalogo = new CatalogoController();

                        ctrl.Items.Add(new RadComboBoxItem("Sin nivel", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = ctrlCatalogo.GetValoresPorCodigo("ESPECIALIDAD_NIVEL", SitioBase.Session.ClienteId());
                        ctrl.DataValueField = "valor_id";
                        ctrl.DataTextField = "valor_nombre";
                        ctrl.DataBind();
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
            UsuarioEspecialidadController controller = new UsuarioEspecialidadController();
            UsuarioEspecialidad entidad = controller.GetUsuarioEspecialidad(new UsuarioEspecialidad { ues_id = Id });

            cboUsuario.SelectedValue = entidad.ues_usuario.ToString();
            cboEspecialidad.SelectedValue = entidad.ues_especialidad.ToString();

            if (entidad.ues_especialidad_nivel != null)
                cboNivel.SelectedValue = entidad.ues_especialidad_nivel.ToString();

            txtCertificacion.Text = entidad.ues_certificacion;
            calVencimiento.Value = entidad.ues_fecha_vencimiento;

            rdbSi.Checked = entidad.ues_habilitado;
            rdbNo.Checked = !entidad.ues_habilitado;

            // Persona y especialidad no se cambian al editar: cambiarlas
            // sería otro registro. Se elimina y se crea de nuevo, que además
            // deja el rastro correcto.
            cboUsuario.Enabled = false;
            cboEspecialidad.Enabled = false;
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR ESPECIALIDADES USUARIO");

        txtCertificacion.ReadOnly = !puedeEditar;
        calVencimiento.Enabled = puedeEditar;
        cboNivel.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;

        if (Id == 0)
        {
            cboUsuario.Enabled = puedeEditar;
            cboEspecialidad.Enabled = puedeEditar;
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            UsuarioEspecialidad entidad = new UsuarioEspecialidad();
            UsuarioEspecialidadController controller = new UsuarioEspecialidadController();

            entidad.ues_id = Id;
            entidad.ues_cliente = SitioBase.Session.ClienteId();
            entidad.ues_certificacion = txtCertificacion.Text.Trim();
            entidad.ues_fecha_vencimiento = calVencimiento.Value;
            entidad.ues_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboNivel.SelectedValue))
                entidad.ues_especialidad_nivel = int.Parse(cboNivel.SelectedValue);

            Respuesta respuesta;

            if (Id > 0)
            {
                respuesta = controller.UpdateUsuarioEspecialidad(entidad);
            }
            else
            {
                if (string.IsNullOrEmpty(cboUsuario.SelectedValue) ||
                    string.IsNullOrEmpty(cboEspecialidad.SelectedValue))
                {
                    Tools.tools.ClientAlert("Indique la persona y la especialidad.", "alerta");
                    return;
                }

                entidad.ues_usuario = int.Parse(cboUsuario.SelectedValue);
                entidad.ues_especialidad = int.Parse(cboEspecialidad.SelectedValue);

                respuesta = controller.InsertUsuarioEspecialidad(entidad);
            }

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
