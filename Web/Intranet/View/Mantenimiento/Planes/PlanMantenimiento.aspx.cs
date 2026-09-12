using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un plan de mantenimiento (HU-080).
///
/// LA VERSION SE LEE, NO SE EDITA
///   Un plan nace con su version 1 en borrador -la crea el SP de alta- y
///   desde aqui solo se ve en que va. Publicar y retirar son actos con sus
///   propias reglas (HU-084) y no un combo mas del formulario.
///
/// EL CLIENTE SALE DE LA SESION, NUNCA DEL QUERYSTRING
///   El querystring trae solo el id, cifrado. El cliente lo pone
///   Session.ClienteId() al guardar, y el SP ademas valida que la planta y
///   el modelo elegidos sean de ese cliente.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanMantenimiento : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>
    /// El modelo que traia el registro, para reseleccionarlo despues de que
    /// CargarModelos reconstruya el combo con los del tipo.
    /// </summary>
    private string _modeloEditar = null;

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
    /// Llena los combos. Todos filtrados por el cliente en sesion: un
    /// planificador de otra empresa no es una opcion.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack) return;
        if (!(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboPlanta":
                {
                    ClienteInstalacionController controller = new ClienteInstalacionController();

                    // Este modelo trae los filtros como string (convencion
                    // heredada de ClienteInstalacion); se respeta tal cual.
                    ClienteInstalacion filtro = new ClienteInstalacion();
                    filtro.filtro_cliente = cliente.ToString();
                    filtro.filtro_habilitado = "1";

                    ctrl.Items.Add(new RadComboBoxItem("Cualquier planta", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetClienteInstalaciones(filtro);
                    ctrl.DataValueField = "cin_id";
                    ctrl.DataTextField = "cin_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboPlanificador":
                {
                    ClienteUsuarioController controller = new ClienteUsuarioController();

                    ClienteUsuario filtro = new ClienteUsuario();
                    filtro.ucl_id_cliente = cliente;
                    filtro.usu_habilitado = true;
                    /* Cadenas vacias y no null: el controlador decide si manda
                       cada parametro con `if (campo != "")`, y un null pasa esa
                       prueba y termina enviando el filtro en nulo. */
                    filtro.id_perfiles = "";
                    filtro.filtro = "";

                    ctrl.Items.Add(new RadComboBoxItem("Sin planificador", ""));

                    List<ClienteUsuario> usuarios = controller.GetClienteUsuarios(filtro);
                    if (usuarios != null)
                    {
                        foreach (ClienteUsuario u in usuarios)
                        {
                            string nombre = !string.IsNullOrEmpty(u.nombre_completo)
                                          ? u.nombre_completo.Trim()
                                          : (u.usu_nombres + " " + u.usu_apellido_paterno).Trim();

                            // El perfil junto al nombre: en una planta hay dos
                            // Gonzalez, y lo que decide es si es planificador.
                            if (!string.IsNullOrEmpty(u.perfiles))
                                nombre += "  ·  " + u.perfiles;

                            ctrl.Items.Add(new RadComboBoxItem(nombre, u.usu_id.ToString()));
                        }
                    }
                    break;
                }

            case "cboTipo":
                {
                    ActivoTipoController controller = new ActivoTipoController();
                    List<ActivoTipo> lista = controller.GetActivoTipos(
                        new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Cualquier tipo", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "ati_id";
                    ctrl.DataTextField = "ati_nombre";
                    ctrl.DataBind();
                    break;
                }
        }
    }

    protected void cboTipo_SelectedIndexChanged(object sender, EventArgs e) { }

    /// <summary>
    /// Llena el combo de modelos con los del TIPO elegido, preservando la
    /// seleccion entre postbacks. Sin tipo, el combo va vacio: un modelo sin
    /// tipo no significa nada.
    /// </summary>
    protected void CargarModelos()
    {
        string sel = string.IsNullOrEmpty(_modeloEditar) ? cboModelo.SelectedValue : _modeloEditar;

        cboModelo.Items.Clear();
        cboModelo.Items.Add(new RadComboBoxItem("Cualquier modelo", ""));
        cboModelo.AppendDataBoundItems = true;

        int tipo;
        if (int.TryParse(cboTipo.SelectedValue, out tipo) && tipo > 0)
        {
            List<ActivoModelo> lista = new ActivoModeloController().GetModelos(new ActivoModelo
            {
                filtro_cliente = SitioBase.Session.ClienteId(),
                filtro_activo_tipo = tipo,
                filtro_habilitado = true
            });

            if (lista != null)
                foreach (ActivoModelo m in lista)
                    cboModelo.Items.Add(new RadComboBoxItem(m.etiqueta, m.amo_id.ToString()));
        }

        RadComboBoxItem it = cboModelo.FindItemByValue(sel ?? "");
        if (it != null) it.Selected = true;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarModelos();   // depende del tipo ya seleccionado por CargarDatos
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            PlanMantenimientoController controller = new PlanMantenimientoController();
            PlanMantenimiento entidad = controller.GetPlanMantenimiento(new PlanMantenimiento { pma_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Plan_Mantenimiento", entidad.pma_codigo);
            txtNombre.Text = entidad.pma_nombre;
            txtDescripcion.Text = entidad.pma_descripcion;

            if (entidad.pma_cliente_instalacion != null)
                Seleccionar(cboPlanta, entidad.pma_cliente_instalacion.Value.ToString());
            if (entidad.pma_usuario_planificador != null)
                Seleccionar(cboPlanificador, entidad.pma_usuario_planificador.Value.ToString());
            if (entidad.pma_activo_tipo != null)
                Seleccionar(cboTipo, entidad.pma_activo_tipo.Value.ToString());
            if (entidad.pma_activo_modelo != null)
                _modeloEditar = entidad.pma_activo_modelo.Value.ToString();

            rdbSi.Checked = entidad.pma_habilitado;
            rdbNo.Checked = !entidad.pma_habilitado;

            litVersion.Text = TextoVersion(entidad);

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.pma_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.pma_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
            litVersion.Text = "<span class=\"sigma-modal-ayuda\">Se crea la versión 1 en borrador al guardar.</span>";
        }
    }

    /// <summary>
    /// «v2 · Publicada · 5 hitos · 3 equipos». Lo que hay que saber del plan
    /// sin abrir otra pantalla.
    /// </summary>
    private string TextoVersion(PlanMantenimiento p)
    {
        if (p.version_numero == null) return "Sin versión";

        string estado = string.IsNullOrEmpty(p.version_estado_nombre) ? "Borrador" : p.version_estado_nombre;

        return "<strong>v" + p.version_numero + "</strong> · " + Server.HtmlEncode(estado)
             + " · " + p.hitos + (p.hitos == 1 ? " hito" : " hitos")
             + " · " + p.activos + (p.activos == 1 ? " equipo" : " equipos");
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        // La accion se valida en el servidor: esconder el boton no autoriza
        // nada, y el SP volveria a rechazar. Solo evita ofrecer un guardar
        // que terminaria en un rechazo.
        bool puedeEditar = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO");

        /* Nunca se escribe a mano: lo genera el SP al crear, y despues
           identifica el registro. */
        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Plan_Mantenimiento");
        txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta en los informes
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        cboPlanificador.ReadOnly = !puedeEditar;
        cboTipo.ReadOnly = !puedeEditar;
        cboModelo.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            PlanMantenimiento entidad = new PlanMantenimiento();
            PlanMantenimientoController controller = new PlanMantenimientoController();

            entidad.pma_id = Id;
            entidad.pma_cliente = SitioBase.Session.ClienteId();
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como PMA-<id>. Al
               editar viaja el que ya tiene y no se regenera nunca: esta en
               los informes y en las ordenes que el plan genero. */
            entidad.pma_codigo = SitioBase.CodigoModulo.Componer("Plan_Mantenimiento", txtCodigo.Text);
            entidad.pma_nombre = txtNombre.Text.Trim();
            entidad.pma_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            entidad.pma_habilitado = rdbSi.Checked;

            /* Combo vacio al editar significa "quitalo", no "no lo toques".
               Sin la bandera el SP conserva el valor viejo con ISNULL y el
               cambio se pierde en silencio. */
            if (!string.IsNullOrEmpty(cboPlanta.SelectedValue))
                entidad.pma_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            else
                entidad.quita_instalacion = true;

            if (!string.IsNullOrEmpty(cboPlanificador.SelectedValue))
                entidad.pma_usuario_planificador = int.Parse(cboPlanificador.SelectedValue);
            else
                entidad.quita_planificador = true;

            if (!string.IsNullOrEmpty(cboTipo.SelectedValue))
                entidad.pma_activo_tipo = int.Parse(cboTipo.SelectedValue);
            else
                entidad.quita_tipo = true;

            if (!string.IsNullOrEmpty(cboModelo.SelectedValue))
                entidad.pma_activo_modelo = int.Parse(cboModelo.SelectedValue);
            else
                entidad.quita_modelo = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdatePlanMantenimiento(entidad)
                : controller.InsertPlanMantenimiento(entidad);

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
