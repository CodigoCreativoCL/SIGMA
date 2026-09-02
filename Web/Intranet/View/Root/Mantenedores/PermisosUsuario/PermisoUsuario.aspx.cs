using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Otorgar o modificar un permiso puntual (HU-007).
/// </summary>
public partial class View_Root_Mantenedores_PermisosUsuario_PermisoUsuario : System.Web.UI.Page
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
            CargarPermisos();
            CargarPlantas();
        }
    }

    protected void CargarUsuarios()
    {
        cboUsuario.Items.Clear();
        cboUsuario.Items.Add(new RadComboBoxItem("Seleccione...", ""));

        SqlCommand cmd = new SqlCommand();

        try
        {
            cmd.CommandText = "SEL_USUARIO_CLIENTE_LISTA";
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    /* EL PERFIL Y NO EL CORREO.

                       Acá se decide si a esta persona le corresponde un
                       permiso. El correo es un identificador: no dice nada
                       sobre eso. El perfil sí —"Bodeguero", "Técnico de
                       Mantenimiento"— y es exactamente el criterio con el
                       que se toma la decisión.

                       El correo no se pierde: queda en el tooltip del item,
                       que es donde sirve —desempatar dos personas con el
                       mismo nombre— y no estorba al leer la lista. */
                    string perfiles = dr["PERFILES"].ToString();

                    RadComboBoxItem item = new RadComboBoxItem(
                        dr["USU_NOMBRE"].ToString() + " · " +
                        (string.IsNullOrEmpty(perfiles) ? "sin perfil" : perfiles),
                        dr["USU_ID"].ToString());

                    item.ToolTip = dr["USU_CORREO"].ToString();

                    cboUsuario.Items.Add(item);
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

    /// <summary>
    /// Solo permisos marcados como asignables a una persona. Ofrecer los
    /// demás llevaría a crear excepciones que INS_CLIENTE_USUARIO_PERMISO
    /// va a rechazar por su validación 2.
    /// </summary>
    protected void CargarPermisos()
    {
        ClienteUsuarioPermisoController controller = new ClienteUsuarioPermisoController();
        List<Permiso> permisos = controller.GetPermisosAsignables();

        cboPermiso.Items.Clear();
        cboPermiso.Items.Add(new RadComboBoxItem("Seleccione...", ""));

        if (permisos != null)
        {
            // El módulo va en el texto: agrupa visualmente sin necesitar un
            // control de árbol para una lista corta.
            foreach (Permiso p in permisos)
                cboPermiso.Items.Add(new RadComboBoxItem(p.prm_modulo + " · " + p.prm_nombre, p.prm_id.ToString()));
        }
    }

    protected void CargarPlantas()
    {
        ClienteInstalacion filtro = new ClienteInstalacion();
        filtro.filtro_cliente = SitioBase.Session.ClienteId().ToString();
        filtro.filtro_habilitado = "1";

        ClienteInstalacionController controller = new ClienteInstalacionController();

        cboPlanta.Items.Clear();
        cboPlanta.Items.Add(new RadComboBoxItem("Seleccione...", ""));
        cboPlanta.AppendDataBoundItems = true;
        cboPlanta.DataSource = controller.GetClienteInstalaciones(filtro);
        cboPlanta.DataValueField = "cin_id";
        cboPlanta.DataTextField = "cin_nombre";
        cboPlanta.DataBind();
    }

    /// <summary>
    /// Las áreas dependen de la planta: un permiso de área tiene que caer
    /// dentro de la planta elegida, e INS_CLIENTE_USUARIO_PERMISO lo
    /// comprueba. Ofrecer áreas de otra planta sería ofrecer un error.
    /// </summary>
    protected void CargarAreas()
    {
        cboArea.Items.Clear();
        cboArea.Items.Add(new RadComboBoxItem("Seleccione...", ""));
        cboArea.AppendDataBoundItems = true;

        if (string.IsNullOrEmpty(cboPlanta.SelectedValue))
        {
            cboArea.DataSource = null;
            cboArea.DataBind();
            return;
        }

        InstalacionArea filtro = new InstalacionArea();
        filtro.iar_cliente = SitioBase.Session.ClienteId();
        filtro.iar_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
        filtro.filtro_habilitado = true;

        InstalacionAreaController controller = new InstalacionAreaController();

        cboArea.DataSource = controller.GetInstalacionAreas(filtro);
        cboArea.DataValueField = "iar_id";
        cboArea.DataTextField = "ruta";
        cboArea.DataBind();
    }

    protected void cboAmbito_SelectedIndexChanged(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        AplicarAmbito();
        udPanel.Update();
    }

    protected void cboPlanta_SelectedIndexChanged(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        CargarAreas();
        udPanel.Update();
    }

    /// <summary>
    /// Muestra los combos que el ámbito elegido necesita. Un permiso de
    /// área exige también su planta, porque el área cuelga de una.
    /// </summary>
    protected void AplicarAmbito()
    {
        string ambito = cboAmbito.SelectedValue;

        pnlPlanta.Visible = (ambito == "PLANTA" || ambito == "AREA");
        pnlArea.Visible = (ambito == "AREA");

        if (pnlArea.Visible && cboArea.Items.Count <= 1)
            CargarAreas();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        AplicarAmbito();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ClienteUsuarioPermisoController controller = new ClienteUsuarioPermisoController();
            ClienteUsuarioPermiso entidad = controller.GetPermiso(new ClienteUsuarioPermiso { cpm_id = Id });

            cboUsuario.SelectedValue = entidad.usu_id.ToString();
            cboPermiso.SelectedValue = entidad.cpm_permiso.ToString();

            rdbConcede.Checked = entidad.cpm_otorgado;
            rdbDeniega.Checked = !entidad.cpm_otorgado;

            if (entidad.cpm_instalacion_area != null)
            {
                cboAmbito.SelectedValue = "AREA";
                cboPlanta.SelectedValue = entidad.cpm_cliente_instalacion.ToString();
                CargarAreas();
                cboArea.SelectedValue = entidad.cpm_instalacion_area.ToString();
            }
            else if (entidad.cpm_cliente_instalacion != null)
            {
                cboAmbito.SelectedValue = "PLANTA";
                cboPlanta.SelectedValue = entidad.cpm_cliente_instalacion.ToString();
            }
            else
            {
                cboAmbito.SelectedValue = "CLIENTE";
            }

            calDesde.Value = entidad.cpm_fecha_inicio;
            calHasta.Value = entidad.cpm_fecha_fin;
            txtMotivo.Text = entidad.cpm_motivo;

            /* Al editar no se cambian ni la persona, ni el permiso, ni el
               ámbito: eso sería otra excepción distinta. Cambiarlos in situ
               dejaría el registro de "quién concedió qué" apuntando a algo
               que nunca se concedió. Para eso se revoca y se otorga de
               nuevo, que además deja las dos cosas registradas. */
            cboUsuario.Enabled = false;
            cboPermiso.Enabled = false;
            cboAmbito.Enabled = false;
            cboPlanta.Enabled = false;
            cboArea.Enabled = false;
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("ASIGNAR PERMISO TERRENO");

        txtMotivo.ReadOnly = !puedeEditar;
        calDesde.Enabled = puedeEditar;
        calHasta.Enabled = puedeEditar;
        rdbConcede.Enabled = puedeEditar;
        rdbDeniega.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;

        if (Id == 0)
        {
            cboUsuario.Enabled = puedeEditar;
            cboPermiso.Enabled = puedeEditar;
            cboAmbito.Enabled = puedeEditar;
            cboPlanta.Enabled = puedeEditar;
            cboArea.Enabled = puedeEditar;
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (txtMotivo.Text.Trim().Length < 10)
            {
                Tools.tools.ClientAlert("El motivo debe tener al menos 10 caracteres.", "alerta");
                return;
            }

            ClienteUsuarioPermisoController controller = new ClienteUsuarioPermisoController();

            ClienteUsuarioPermiso entidad = new ClienteUsuarioPermiso();
            entidad.cpm_id = Id;
            entidad.cliente = SitioBase.Session.ClienteId();
            entidad.cpm_otorgado = rdbConcede.Checked;
            entidad.cpm_fecha_inicio = calDesde.Value;
            entidad.cpm_fecha_fin = calHasta.Value;
            entidad.cpm_motivo = txtMotivo.Text.Trim();
            entidad.cpm_habilitado = true;

            Respuesta respuesta;

            if (Id > 0)
            {
                respuesta = controller.UpdatePermiso(entidad);
            }
            else
            {
                if (string.IsNullOrEmpty(cboUsuario.SelectedValue) || string.IsNullOrEmpty(cboPermiso.SelectedValue))
                {
                    Tools.tools.ClientAlert("Indique el usuario y el permiso.", "alerta");
                    return;
                }

                string ambito = cboAmbito.SelectedValue;

                if ((ambito == "PLANTA" || ambito == "AREA") && string.IsNullOrEmpty(cboPlanta.SelectedValue))
                {
                    Tools.tools.ClientAlert("Indique la planta.", "alerta");
                    return;
                }

                if (ambito == "AREA" && string.IsNullOrEmpty(cboArea.SelectedValue))
                {
                    Tools.tools.ClientAlert("Indique el área.", "alerta");
                    return;
                }

                // La tabla apunta a la AFILIACIÓN, no a la persona: la misma
                // persona puede estar en varios clientes y la excepción vale
                // sólo en uno.
                int idClienteUsuario = ResolverClienteUsuario(int.Parse(cboUsuario.SelectedValue));

                if (idClienteUsuario == 0)
                {
                    Tools.tools.ClientAlert("Esa persona no está afiliada al cliente en sesión.", "alerta");
                    return;
                }

                entidad.cpm_cliente_usuario = idClienteUsuario;
                entidad.cpm_permiso = int.Parse(cboPermiso.SelectedValue);

                if (ambito == "PLANTA" || ambito == "AREA")
                    entidad.cpm_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);

                if (ambito == "AREA")
                    entidad.cpm_instalacion_area = int.Parse(cboArea.SelectedValue);

                respuesta = controller.InsertPermiso(entidad);
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

    private int ResolverClienteUsuario(int idUsuario)
    {
        int id = 0;
        SqlCommand cmd = new SqlCommand();

        try
        {
            cmd.CommandText = "SEL_CLIENTE_USUARIO_ID";
            cmd.Parameters.AddWithValue("@USUARIO", idUsuario);
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                if (dr.Read()) id = int.Parse(dr["UCL_ID"].ToString());
            }

            cmd.Connection.Close();
            cmd.Dispose();
        }
        catch (Exception ex)
        {
            if (cmd.Connection != null) cmd.Connection.Close();
            cmd.Dispose();
        }

        return id;
    }
}
