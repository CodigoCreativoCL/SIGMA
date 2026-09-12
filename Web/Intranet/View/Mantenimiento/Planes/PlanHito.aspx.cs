using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un hito de plan (HU-081).
///
/// SOLO SE ESCRIBE SOBRE UN BORRADOR
///   El SP lo rechaza de todos modos, pero la pantalla lo dice ARRIBA y
///   bloquea los campos: enterarse al apretar Guardar, con todo ya escrito,
///   es la peor forma de enterarse.
///
/// EL PLAN, NO LA VERSION
///   Se elige el plan y el SP le cuelga el hito a su version en borrador.
///   El combo solo ofrece planes que tengan una, para no ofrecer una opcion
///   que el SP va a rechazar.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanHito : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>Al editar, la version ya no esta en borrador: solo lectura.</summary>
    private bool VersionCerrada
    {
        get { return ViewState["VersionCerrada"] != null && (bool)ViewState["VersionCerrada"]; }
        set { ViewState["VersionCerrada"] = value; }
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

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack) return;
        if (!(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboPlan":
                {
                    List<PlanMantenimiento> planes = new PlanMantenimientoController().GetPlanesMantenimiento(
                        new PlanMantenimiento { pma_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));

                    if (planes != null)
                    {
                        foreach (PlanMantenimiento p in planes)
                        {
                            /* Al crear, solo los planes cuya version que manda
                               es un borrador: los demas no tienen donde recibir
                               el hito y el SP los rechazaria. Al editar se
                               muestra el plan que tenga, sea cual sea. */
                            bool enBorrador = string.Equals(p.version_estado_codigo, "BORRADOR", StringComparison.OrdinalIgnoreCase);
                            if (Id == 0 && !enBorrador) continue;

                            ctrl.Items.Add(new RadComboBoxItem(p.pma_codigo + " — " + p.pma_nombre, p.pma_id.ToString()));
                        }
                    }
                    break;
                }

            case "cboProgramacion":
                {
                    List<Programacion> lista = new ProgramacionController().GetProgramaciones(
                        new Programacion { filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));

                    if (lista != null)
                        foreach (Programacion p in lista)
                        {
                            // El tipo junto al nombre: «Trimestral L1 · Calendario»
                            // dice de un vistazo si esto dispara por fecha o por horas.
                            string texto = p.pro_nombre;
                            if (!string.IsNullOrEmpty(p.tipo_nombre)) texto += "  ·  " + p.tipo_nombre;
                            ctrl.Items.Add(new RadComboBoxItem(texto, p.pro_id.ToString()));
                        }
                    break;
                }

            case "cboUnidad":
                {
                    List<UnidadMedida> lista = new UnidadMedidaController().GetUnidades(
                        new UnidadMedida { filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Sin unidad", ""));

                    if (lista != null)
                        foreach (UnidadMedida u in lista)
                            ctrl.Items.Add(new RadComboBoxItem(u.ume_nombre + " (" + u.ume_simbolo + ")", u.ume_id.ToString()));
                    break;
                }

            case "cboOtTipo":
                CargarCatalogo(ctrl, "ORDEN_TRABAJO_TIPO", "Sin definir", cliente);
                break;

            case "cboOtPrioridad":
                CargarCatalogo(ctrl, "ORDEN_TRABAJO_PRIORIDAD", "Sin definir", cliente);
                break;
        }
    }

    /// <summary>
    /// Los catalogos chicos se leen por su codigo con SEL_CATALOGO_VALOR:
    /// evita un Model y un Controller por cada uno, y no se escriben a mano
    /// en el markup, que es el catalogo que nadie actualiza.
    /// </summary>
    private static void CargarCatalogo(RadComboBox2 ctrl, string codigo, string vacio, int cliente)
    {
        List<CatalogoValor> valores = new CatalogoController().GetValoresPorCodigo(codigo, cliente);

        ctrl.Items.Add(new RadComboBoxItem(vacio, ""));

        if (valores != null)
            foreach (CatalogoValor v in valores)
                ctrl.Items.Add(new RadComboBoxItem(v.valor_nombre, v.valor_id.ToString()));
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
            PlanHito h = new PlanHitoController().GetPlanHito(new PlanHito { pmh_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = h.pmh_codigo;
            txtNombre.Text = h.pmh_nombre;
            txtOrden.Text = h.pmh_orden.ToString();
            txtDescripcion.Text = h.pmh_descripcion;
            txtValorMedidor.Text = h.pmh_valor_medidor == null ? "" : h.pmh_valor_medidor.Value.ToString("0.####", CultureInfo.InvariantCulture);
            txtDuracion.Text = h.pmh_duracion_estimada_minuto == null ? "" : h.pmh_duracion_estimada_minuto.ToString();

            Seleccionar(cboPlan, h.plan_id.ToString());
            Seleccionar(cboProgramacion, h.pmh_programacion.ToString());
            if (h.pmh_unidad_medida != null) Seleccionar(cboUnidad, h.pmh_unidad_medida.Value.ToString());
            if (h.pmh_orden_trabajo_tipo != null) Seleccionar(cboOtTipo, h.pmh_orden_trabajo_tipo.Value.ToString());
            if (h.pmh_orden_trabajo_prioridad != null) Seleccionar(cboOtPrioridad, h.pmh_orden_trabajo_prioridad.Value.ToString());

            rdbParadaSi.Checked = h.pmh_requiere_parada;
            rdbParadaNo.Checked = !h.pmh_requiere_parada;
            rdbOverhaulSi.Checked = h.pmh_es_overhaul;
            rdbOverhaulNo.Checked = !h.pmh_es_overhaul;
            rdbSi.Checked = h.pmh_habilitado;
            rdbNo.Checked = !h.pmh_habilitado;

            VersionCerrada = !h.version_editable;
            litEstadoVersion.Text = "v" + h.version_numero + " " + Server.HtmlEncode((h.version_estado_nombre ?? "").ToLower());

            wucAuditoria.Mostrar(h.usuario_creacion_nombre, h.pmh_fecha_creacion,
                                 h.usuario_actualizacion_nombre, h.pmh_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        // La accion se valida en el servidor; esconder el boton solo evita
        // ofrecer un guardar que el SP va a rechazar.
        bool puedeEditar = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO") && !VersionCerrada;

        pnlBloqueado.Visible = VersionCerrada;

        // El plan no se cambia al editar: mover un hito de plan es borrarlo
        // de uno y crearlo en otro, y eso se hace asi, a la vista.
        cboPlan.ReadOnly = Id > 0 || !puedeEditar;
        txtCodigo.ReadOnly = !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtOrden.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboProgramacion.ReadOnly = !puedeEditar;
        txtValorMedidor.ReadOnly = !puedeEditar;
        cboUnidad.ReadOnly = !puedeEditar;
        cboOtTipo.ReadOnly = !puedeEditar;
        cboOtPrioridad.ReadOnly = !puedeEditar;
        txtDuracion.ReadOnly = !puedeEditar;
        rdbParadaSi.Enabled = puedeEditar;
        rdbParadaNo.Enabled = puedeEditar;
        rdbOverhaulSi.Enabled = puedeEditar;
        rdbOverhaulNo.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            PlanHito entidad = new PlanHito();
            PlanHitoController controller = new PlanHitoController();

            entidad.pmh_id = Id;
            entidad.plan_id = string.IsNullOrEmpty(cboPlan.SelectedValue) ? 0 : int.Parse(cboPlan.SelectedValue);
            entidad.pmh_programacion = string.IsNullOrEmpty(cboProgramacion.SelectedValue) ? 0 : int.Parse(cboProgramacion.SelectedValue);
            entidad.pmh_codigo = txtCodigo.Text.Trim().ToUpper();
            entidad.pmh_nombre = txtNombre.Text.Trim();
            entidad.pmh_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            entidad.pmh_requiere_parada = rdbParadaSi.Checked;
            entidad.pmh_es_overhaul = rdbOverhaulSi.Checked;
            entidad.pmh_habilitado = rdbSi.Checked;

            int orden;
            if (int.TryParse(txtOrden.Text.Trim(), out orden) && orden > 0) entidad.pmh_orden = orden;

            /* Los numeros se validan ACA con un mensaje entendible y no se
               dejan caer al SP: «abc» en la duracion no es una regla de
               negocio, es un tipeo, y el mensaje de conversion de SQL no lo
               explica. */
            if (!string.IsNullOrEmpty(txtDuracion.Text.Trim()))
            {
                int duracion;
                if (!int.TryParse(txtDuracion.Text.Trim(), out duracion) || duracion <= 0)
                {
                    Tools.tools.ClientAlert("La duración estimada debe ser un número de minutos mayor que cero.", "alerta");
                    return;
                }
                entidad.pmh_duracion_estimada_minuto = duracion;
            }
            else entidad.quita_duracion = true;

            if (!string.IsNullOrEmpty(txtValorMedidor.Text.Trim()))
            {
                decimal valor;
                string texto = txtValorMedidor.Text.Trim().Replace(',', '.');
                if (!decimal.TryParse(texto, NumberStyles.Number, CultureInfo.InvariantCulture, out valor) || valor <= 0)
                {
                    Tools.tools.ClientAlert("El valor del medidor debe ser un número mayor que cero.", "alerta");
                    return;
                }
                entidad.pmh_valor_medidor = valor;
                if (!string.IsNullOrEmpty(cboUnidad.SelectedValue))
                    entidad.pmh_unidad_medida = int.Parse(cboUnidad.SelectedValue);
            }
            else entidad.quita_medidor = true;

            if (!string.IsNullOrEmpty(cboOtTipo.SelectedValue))
                entidad.pmh_orden_trabajo_tipo = int.Parse(cboOtTipo.SelectedValue);
            else entidad.quita_ot_tipo = true;

            if (!string.IsNullOrEmpty(cboOtPrioridad.SelectedValue))
                entidad.pmh_orden_trabajo_prioridad = int.Parse(cboOtPrioridad.SelectedValue);
            else entidad.quita_ot_prioridad = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdatePlanHito(entidad)
                : controller.InsertPlanHito(entidad);

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
