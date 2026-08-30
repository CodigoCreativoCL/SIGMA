using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un grupo de trabajo con sus integrantes (HU-016).
/// </summary>
public partial class View_Organizacion_Grupos_Grupo : System.Web.UI.Page
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

            GridIntegrantes.AddColumn("USU_NOMBRE", "PERSONA", Width: "30%");
            GridIntegrantes.AddColumn("USU_CORREO", "CORREO", Width: "24%");
            GridIntegrantes.AddColumn("GTU_FECHA_INICIO", "DESDE", Width: "12%", DataFormat: "{0:dd-MM-yyyy}");
            GridIntegrantes.AddColumn("GTU_FECHA_FIN", "HASTA", Width: "12%", DataFormat: "{0:dd-MM-yyyy}");
            GridIntegrantes.AddTemplateColumn("liderChip", "", "LÍDER", Width: "10%", ItemPosition: HorizontalAlign.Center);
            GridIntegrantes.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "8%", ItemPosition: HorizontalAlign.Center);
            GridIntegrantes.AddTemplateColumn("quitar", "", "", Width: "4%", ItemPosition: HorizontalAlign.Center);
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
                    case "cboPlanta":

                        ClienteInstalacion filtroPlanta = new ClienteInstalacion();
                        filtroPlanta.filtro_cliente = SitioBase.Session.ClienteId().ToString();
                        filtroPlanta.filtro_habilitado = "1";

                        ClienteInstalacionController ctrlPlanta = new ClienteInstalacionController();

                        ctrl.Items.Add(new RadComboBoxItem("Transversal (todas las plantas)", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = ctrlPlanta.GetClienteInstalaciones(filtroPlanta);
                        ctrl.DataValueField = "cin_id";
                        ctrl.DataTextField = "cin_nombre";
                        ctrl.DataBind();
                        break;

                    case "cboEspecialidad":

                        Especialidad filtroEsp = new Especialidad();
                        filtroEsp.esp_cliente = SitioBase.Session.ClienteId();
                        filtroEsp.filtro_habilitado = true;

                        UsuarioEspecialidadController ctrlEsp = new UsuarioEspecialidadController();

                        ctrl.Items.Add(new RadComboBoxItem("Sin especialidad predominante", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = ctrlEsp.GetEspecialidades(filtroEsp);
                        ctrl.DataValueField = "esp_id";
                        ctrl.DataTextField = "esp_nombre";
                        ctrl.DataBind();
                        break;
                }
            }
        }
    }

    /// <summary>
    /// Personas del cliente, para el combo de integrantes.
    /// Se recarga en cada postback porque la lista depende del grupo ya
    /// guardado y del cliente en sesión.
    /// </summary>
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

            List<GrupoTrabajoUsuario> personas = new List<GrupoTrabajoUsuario>();

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    GrupoTrabajoUsuario p = new GrupoTrabajoUsuario();
                    p.gtu_usuario = int.Parse(dr["USU_ID"].ToString());
                    p.usu_nombre = dr["USU_NOMBRE"].ToString() + " · " + dr["USU_CORREO"].ToString();
                    personas.Add(p);
                }
            }

            cmd.Connection.Close();
            cmd.Dispose();

            cboUsuario.DataSource = personas;
            cboUsuario.DataValueField = "gtu_usuario";
            cboUsuario.DataTextField = "usu_nombre";
            cboUsuario.DataBind();
        }
        catch (Exception ex)
        {
            if (cmd.Connection != null) cmd.Connection.Close();
            cmd.Dispose();
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();

        pnlIntegrantes.Visible = Id > 0;

        if (Id > 0)
        {
            if (cboUsuario.Items.Count <= 1) CargarUsuarios();
            CargarIntegrantes();
            GridIntegrantes.DataBind();
        }

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnAgregar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            GrupoTrabajoController controller = new GrupoTrabajoController();
            GrupoTrabajo entidad = controller.GetGrupoTrabajo(new GrupoTrabajo { gtr_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = entidad.gtr_codigo;
            txtNombre.Text = entidad.gtr_nombre;
            txtDescripcion.Text = entidad.gtr_descripcion;

            if (entidad.gtr_cliente_instalacion != null)
                cboPlanta.SelectedValue = entidad.gtr_cliente_instalacion.ToString();

            if (entidad.gtr_especialidad != null)
                cboEspecialidad.SelectedValue = entidad.gtr_especialidad.ToString();

            rdbSi.Checked = entidad.gtr_habilitado;
            rdbNo.Checked = !entidad.gtr_habilitado;
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    protected void CargarIntegrantes()
    {
        GrupoTrabajoController controller = new GrupoTrabajoController();
        GridIntegrantes.DataSource = controller.GetIntegrantes(
            new GrupoTrabajoUsuario { gtu_grupo_trabajo = Id });
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR GRUPOS TRABAJO");

        txtCodigo.ReadOnly = !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        cboEspecialidad.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;

        cboUsuario.Enabled = puedeEditar;
        calDesde.Enabled = puedeEditar;
        calHasta.Enabled = puedeEditar;
        chkEsLider.Enabled = puedeEditar;
        btnAgregar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            GrupoTrabajo entidad = new GrupoTrabajo();
            GrupoTrabajoController controller = new GrupoTrabajoController();

            entidad.gtr_id = Id;
            entidad.gtr_cliente = SitioBase.Session.ClienteId();
            entidad.gtr_codigo = txtCodigo.Text.Trim();
            entidad.gtr_nombre = txtNombre.Text.Trim();
            entidad.gtr_descripcion = txtDescripcion.Text.Trim();
            entidad.gtr_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboPlanta.SelectedValue))
                entidad.gtr_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            else
                // Combo vacío significa "hazlo transversal", no "déjalo como
                // estaba". Sin la bandera el SP conservaría la planta actual.
                entidad.quita_planta = true;

            if (!string.IsNullOrEmpty(cboEspecialidad.SelectedValue))
                entidad.gtr_especialidad = int.Parse(cboEspecialidad.SelectedValue);

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateGrupoTrabajo(entidad)
                : controller.InsertGrupoTrabajo(entidad);

            if (!respuesta.error)
            {
                bool esNuevo = Id == 0;
                if (esNuevo) Id = respuesta.codigo;

                // Al crear NO se cierra la ventana: recién ahora aparece la
                // sección de integrantes, y cerrarla obligaría a volver a
                // abrir la ficha para agregar al primero.
                Tools.tools.ClientAlert(respuesta.detalle, "ok", !esNuevo);
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

    protected void btnAgregar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboUsuario.SelectedValue))
            {
                Tools.tools.ClientAlert("Elija a la persona que va a integrar el grupo.", "alerta");
                return;
            }

            GrupoTrabajoUsuario integrante = new GrupoTrabajoUsuario();
            integrante.gtu_grupo_trabajo = Id;
            integrante.gtu_usuario = int.Parse(cboUsuario.SelectedValue);
            integrante.gtu_es_lider = chkEsLider.Checked;
            integrante.gtu_fecha_inicio = calDesde.Value;
            integrante.gtu_fecha_fin = calHasta.Value;

            GrupoTrabajoController controller = new GrupoTrabajoController();
            Respuesta respuesta = controller.InsertIntegrante(integrante);

            if (!respuesta.error)
            {
                cboUsuario.SelectedValue = "";
                chkEsLider.Checked = false;
                calDesde.Value = null;
                calHasta.Value = null;

                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            }
            else
            {
                // El detalle viene del SP: líder duplicado, tramo solapado,
                // persona no autorizada en la planta. Son mensajes que hay
                // que mostrar tal cual para que se pueda corregir.
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

    protected void GridIntegrantes_ItemCreated(object sender, GridItemEventArgs e)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = (GridDataItem)e.Item;

            LinkButton lnkQuitar = new LinkButton();
            lnkQuitar.ID = "lnkQuitar";
            lnkQuitar.Text = "&nbsp";
            lnkQuitar.CssClass = "icono_eliminar";
            lnkQuitar.ToolTip = "Quitar del grupo";
            lnkQuitar.OnClientClick = "return ConfirSweetAlert(this, '', '¿Quitar a esta persona del grupo?');";
            lnkQuitar.Command += new CommandEventHandler(lnkQuitar_Command);

            item["quitar"].Controls.Add(lnkQuitar);

            ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkQuitar);
        }
    }

    protected void GridIntegrantes_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("gtu_id").ToString();

                LinkButton lnkQuitar = (LinkButton)item["quitar"].FindControl("lnkQuitar");
                if (lnkQuitar != null)
                {
                    lnkQuitar.CommandName = id;
                    lnkQuitar.Visible = Token.Puede("CREAR EDITAR GRUPOS TRABAJO");
                }

                bool esLider = Convert.ToBoolean(DataBinder.Eval(item.DataItem, "gtu_es_lider"));

                if (esLider)
                {
                    Label lblLider = new Label();
                    lblLider.Text = "Líder";
                    lblLider.CssClass = "grid-estado-chip is-acento";
                    item["liderChip"].Controls.Add(lblLider);
                }

                string estado = DataBinder.Eval(item.DataItem, "estado") != null
                    ? DataBinder.Eval(item.DataItem, "estado").ToString()
                    : "";

                Label lblEstado = new Label();
                lblEstado.Text = estado;
                lblEstado.CssClass = "grid-estado-chip " + ChipDeEstado(estado);
                item["estadoChip"].Controls.Add(lblEstado);
            }
        }
    }

    private string ChipDeEstado(string estado)
    {
        switch ((estado ?? "").Trim().ToUpper())
        {
            case "VIGENTE": return "is-exito";
            case "PENDIENTE": return "is-info";
            case "TERMINADO": return "is-neutro";
            default: return "is-neutro";
        }
    }

    protected void lnkQuitar_Command(object sender, CommandEventArgs e)
    {
        try
        {
            GrupoTrabajoUsuario integrante = new GrupoTrabajoUsuario();
            integrante.gtu_id = int.Parse(e.CommandName.ToString());

            GrupoTrabajoController controller = new GrupoTrabajoController();
            Respuesta respuesta = controller.DeleteIntegrante(integrante);

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }
}
