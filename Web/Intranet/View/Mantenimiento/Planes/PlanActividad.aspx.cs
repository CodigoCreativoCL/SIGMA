using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una actividad de un hito de plan (HU-082).
///
/// EL HITO DICE CADA CUÁNTO, LA ACTIVIDAD DICE QUÉ
///   El hito ya resolvió la frecuencia. Acá se describe el trabajo: el paso
///   concreto, con qué procedimiento, cuánto demora y qué seguridad exige.
///
/// SOLO SE ESCRIBE SOBRE UN BORRADOR
///   El SP lo rechaza de todos modos, pero la pantalla lo dice ARRIBA y
///   bloquea los campos: enterarse al apretar Guardar, con todo ya escrito,
///   es la peor forma de enterarse.
///
/// EL HITO VIENE EN EL QUERY
///   Se entra desde las actividades de un hito, así que el combo llega fijo
///   en él. Ofrecer elegir un hito que ya se eligió al entrar es pedir dos
///   veces el mismo dato, y deja abierta la puerta a que no coincidan.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanActividad : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>El hito desde el que se abrió este modal, cifrado en el query.</summary>
    public int Hito
    {
        get { return ViewState["Hito"] != null ? (int)ViewState["Hito"] : 0; }
        set { ViewState["Hito"] = value; }
    }

    /// <summary>Al editar, si la versión ya no está en borrador: solo lectura.</summary>
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
                    case "Hito":
                        Hito = Int32.Parse(array[1].ToString());
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
            case "cboHito":
                {
                    List<PlanHito> hitos = new PlanHitoController().GetPlanHitos(
                        new PlanHito { filtro_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));

                    if (hitos != null)
                    {
                        foreach (PlanHito h in hitos)
                        {
                            /* Al crear, solo hitos de una versión en borrador:
                               los demás no tienen dónde recibir la actividad y
                               el SP los rechazaría. Al editar se muestra el
                               hito que tenga, sea cual sea. */
                            if (Id == 0 && !h.version_editable) continue;

                            ctrl.Items.Add(new RadComboBoxItem(
                                h.plan_codigo + " · " + h.pmh_codigo + " — " + h.pmh_nombre,
                                h.pmh_id.ToString()));
                        }
                    }
                    break;
                }

            case "cboProcedimiento":
                {
                    /* Solo la última versión de cada procedimiento: enganchar
                       una actividad a una versión vieja es planificar con una
                       instrucción que ya se corrigió. */
                    List<Procedimiento> lista = new ProcedimientoController().GetProcedimientos(
                        new Procedimiento { filtro_cliente = cliente, filtro_habilitado = true, filtro_solo_ultima = true });

                    ctrl.Items.Add(new RadComboBoxItem("Sin procedimiento", ""));

                    if (lista != null)
                        foreach (Procedimiento p in lista)
                        {
                            // Los pasos junto al nombre: un procedimiento sin
                            // pasos no aporta nada a la orden, y se ve acá.
                            string texto = p.prc_codigo + " — " + p.prc_nombre;
                            texto += p.pasos == 1 ? "  ·  1 paso" : "  ·  " + p.pasos + " pasos";
                            ctrl.Items.Add(new RadComboBoxItem(texto, p.prc_id.ToString()));
                        }
                    break;
                }

            case "cboRepuesto":
                {
                    /* Los repuestos del cliente, habilitados. El codigo va
                       delante porque es lo que el planificador tiene en la
                       mano cuando viene de la lista de materiales. */
                    List<Repuesto> lista = new RepuestoController().GetRepuestos(
                        new Repuesto { filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));

                    if (lista != null)
                        foreach (Repuesto r in lista)
                            ctrl.Items.Add(new RadComboBoxItem(r.rep_codigo + " — " + r.rep_nombre, r.rep_id.ToString()));
                    break;
                }

            case "cboPermisoTipo":
                {
                    List<PermisoTrabajoTipo> tipos = new PermisoTrabajoController().GetTipos();

                    ctrl.Items.Add(new RadComboBoxItem("Sin definir", ""));

                    if (tipos != null)
                        foreach (PermisoTrabajoTipo t in tipos)
                            ctrl.Items.Add(new RadComboBoxItem(t.ptt_nombre, t.ptt_id.ToString()));
                    break;
                }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Repuestos();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            PlanActividad a = new PlanActividadController().GetPlanActividad(new PlanActividad { paa_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = a.paa_codigo;
            txtNombre.Text = a.paa_nombre;
            txtOrden.Text = a.paa_orden.ToString();
            txtDescripcion.Text = a.paa_descripcion;
            txtDuracion.Text = a.paa_duracion_estimada_minuto == null ? "" : a.paa_duracion_estimada_minuto.ToString();

            Hito = a.paa_plan_mantenimiento_hito;
            Seleccionar(cboHito, a.paa_plan_mantenimiento_hito.ToString());
            if (a.paa_procedimiento != null) Seleccionar(cboProcedimiento, a.paa_procedimiento.Value.ToString());
            if (a.paa_permiso_trabajo_tipo != null) Seleccionar(cboPermisoTipo, a.paa_permiso_trabajo_tipo.Value.ToString());

            rdbObligatoriaSi.Checked = a.paa_obligatoria;
            rdbObligatoriaNo.Checked = !a.paa_obligatoria;
            rdbParadaSi.Checked = a.paa_requiere_parada;
            rdbParadaNo.Checked = !a.paa_requiere_parada;
            rdbPermisoSi.Checked = a.paa_requiere_permiso;
            rdbPermisoNo.Checked = !a.paa_requiere_permiso;
            rdbSi.Checked = a.paa_habilitado;
            rdbNo.Checked = !a.paa_habilitado;

            VersionCerrada = !a.version_editable;
            litEstadoVersion.Text = "v" + a.version_numero + " " + Server.HtmlEncode((a.version_estado_nombre ?? "").ToLower());

            wucAuditoria.Mostrar(a.usuario_creacion_nombre, a.paa_fecha_creacion,
                                 a.usuario_actualizacion_nombre, a.paa_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
            if (Hito > 0) Seleccionar(cboHito, Hito.ToString());
        }
    }

    /// <summary>
    /// La lista de repuestos planificados de la actividad.
    ///
    /// Se repinta en cada carga -tambien en los postbacks de agregar y
    /// quitar-, asi que no hace falta acordarse de refrescarla: lo que se ve
    /// es lo que hay en la base.
    ///
    /// Solo aparece al editar: al crear, la actividad todavia no tiene id del
    /// cual colgar los repuestos. Se guarda primero y se agregan despues, el
    /// mismo orden que sigue la imagen del componente.
    /// </summary>
    protected void Repuestos()
    {
        pnlRepuestos.Visible = Id > 0;
        if (Id == 0) return;

        List<PlanActividadRepuesto> lista = new PlanActividadController().GetRepuestos(
            new PlanActividadRepuesto { filtro_cliente = SitioBase.Session.ClienteId(), filtro_actividad = Id })
            ?? new List<PlanActividadRepuesto>();

        bool puedeEditar = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO") && !VersionCerrada;
        pnlAgregarRepuesto.Visible = puedeEditar;

        if (lista.Count == 0)
        {
            litRepuestos.Text = "<span class=\"sigma-modal-ayuda\">"
                              + "<i class=\"mdi mdi-information-outline\"></i> Sin repuestos planificados. "
                              + "La orden que genere el hito va a salir sin materiales pedidos.</span>";
            return;
        }

        StringBuilder s = new StringBuilder();

        s.Append("<table class=\"sigma-tabla-simple\" style=\"width:100%; font-size:13px;\">")
         .Append("<thead><tr>")
         .Append("<th style=\"text-align:left;\">Repuesto</th>")
         .Append("<th style=\"text-align:right;\">Cantidad</th>")
         .Append("<th style=\"text-align:right;\">En bodega</th>")
         .Append("<th style=\"text-align:left;\">Obligatorio</th>")
         .Append("<th style=\"text-align:left;\">Observación</th>")
         .Append("<th></th>")
         .Append("</tr></thead><tbody>");

        foreach (PlanActividadRepuesto r in lista)
        {
            s.Append("<tr><td><strong>").Append(Server.HtmlEncode(r.repuesto_codigo)).Append("</strong> ")
             .Append(Server.HtmlEncode(r.repuesto_nombre)).Append("</td>");

            s.Append("<td style=\"text-align:right;\">").Append(Cantidad(r.pra_cantidad))
             .Append(" ").Append(Server.HtmlEncode(r.unidad_simbolo)).Append("</td>");

            /* Planificar mas de lo que hay no se prohibe -el repuesto se
               compra-, pero se avisa: enterarse en el pañol, con la maquina
               parada, es la peor forma de enterarse. */
            s.Append("<td style=\"text-align:right;\">");
            if (r.existencia < r.pra_cantidad)
                s.Append("<span class=\"grid-estado-chip is-advertencia\" title=\"Hay menos en bodega que lo planificado\">")
                 .Append("<i class=\"mdi mdi-alert-outline\"></i>").Append(Cantidad(r.existencia)).Append("</span>");
            else
                s.Append(Cantidad(r.existencia));
            s.Append("</td>");

            s.Append("<td>").Append(r.pra_obligatorio
                    ? "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-asterisk\"></i>sí</span>"
                    : "<span class=\"sigma-inv-vacio\">no</span>").Append("</td>");

            s.Append("<td>").Append(string.IsNullOrEmpty(r.pra_observacion)
                    ? "<span class=\"sigma-inv-vacio\">—</span>"
                    : Server.HtmlEncode(r.pra_observacion)).Append("</td>");

            s.Append("<td style=\"text-align:right;\">");
            if (puedeEditar)
                s.Append("<a href=\"javascript:void(0)\" class=\"icono_eliminar\" title=\"Quitar\" onclick=\"")
                 .Append(Page.ClientScript.GetPostBackClientHyperlink(lnkQuitarRepuesto, r.pra_id.ToString()))
                 .Append("\">Quitar</a>");
            s.Append("</td></tr>");
        }

        s.Append("</tbody></table>");
        litRepuestos.Text = s.ToString();
    }

    /// <summary>
    /// Cantidades sin ceros de relleno: «3» y no «3,0000», que es como las
    /// guarda un DECIMAL(18,4) y como nadie las escribe.
    /// </summary>
    private static string Cantidad(decimal valor)
    {
        return valor.ToString("0.####", CultureInfo.InvariantCulture).Replace('.', ',');
    }

    protected void btnAgregarRepuesto_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"))
            {
                Tools.tools.ClientAlert("No tiene permiso para modificar los repuestos del plan.", "alerta");
                return;
            }

            if (string.IsNullOrEmpty(cboRepuesto.SelectedValue))
            {
                Tools.tools.ClientAlert("Elija el repuesto que va a planificar.", "alerta");
                return;
            }

            decimal cantidad;
            string texto = txtCantidad.Text.Trim().Replace(',', '.');
            if (!decimal.TryParse(texto, NumberStyles.Number, CultureInfo.InvariantCulture, out cantidad) || cantidad <= 0)
            {
                Tools.tools.ClientAlert("La cantidad planificada debe ser un número mayor que cero.", "alerta");
                return;
            }

            PlanActividadRepuesto entidad = new PlanActividadRepuesto();
            entidad.pra_plan_mantenimiento_actividad = Id;
            entidad.pra_repuesto = int.Parse(cboRepuesto.SelectedValue);
            entidad.pra_cantidad = cantidad;
            entidad.pra_obligatorio = rdbRepObligatorioSi.Checked;
            entidad.pra_observacion = string.IsNullOrEmpty(txtRepObservacion.Text.Trim()) ? null : txtRepObservacion.Text.Trim();

            Respuesta r = new PlanActividadController().InsertRepuesto(entidad);

            if (!r.error)
            {
                // El formulario queda limpio para la linea siguiente: casi
                // siempre se agregan varios repuestos de corrido.
                txtCantidad.Text = "";
                txtRepObservacion.Text = "";
                RadComboBoxItem vacio = cboRepuesto.FindItemByValue("");
                if (vacio != null) vacio.Selected = true;

                Tools.tools.ClientAlert(r.detalle, "ok");
            }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void lnkQuitarRepuesto_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"))
            {
                Tools.tools.ClientAlert("No tiene permiso para modificar los repuestos del plan.", "alerta");
                return;
            }

            int id;
            if (!int.TryParse(Request.Form["__EVENTARGUMENT"], out id) || id <= 0) return;

            Respuesta r = new PlanActividadController().DeleteRepuesto(
                new PlanActividadRepuesto { pra_id = id });

            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        // La acción se valida en el servidor; esconder el botón solo evita
        // ofrecer un guardar que el SP va a rechazar.
        bool puedeEditar = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO") && !VersionCerrada;

        pnlBloqueado.Visible = VersionCerrada;

        // El hito no se cambia al editar: mover una actividad de hito es
        // borrarla de uno y crearla en otro, y eso se hace así, a la vista.
        // Fijo con Enabled y no con ReadOnly: un RadComboBox ReadOnly no
        // renderiza sus items y validaControl se cae al recorrerlos.
        cboHito.Enabled = !(Id > 0 || Hito > 0);
        cboHito.ReadOnly = !puedeEditar;
        txtCodigo.ReadOnly = !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtOrden.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboProcedimiento.ReadOnly = !puedeEditar;
        txtDuracion.ReadOnly = !puedeEditar;
        cboPermisoTipo.ReadOnly = !puedeEditar;
        cboRepuesto.ReadOnly = !puedeEditar;
        txtCantidad.ReadOnly = !puedeEditar;
        txtRepObservacion.ReadOnly = !puedeEditar;
        rdbRepObligatorioSi.Enabled = puedeEditar;
        rdbRepObligatorioNo.Enabled = puedeEditar;
        btnAgregarRepuesto.Visible = puedeEditar;
        rdbObligatoriaSi.Enabled = puedeEditar;
        rdbObligatoriaNo.Enabled = puedeEditar;
        rdbParadaSi.Enabled = puedeEditar;
        rdbParadaNo.Enabled = puedeEditar;
        rdbPermisoSi.Enabled = puedeEditar;
        rdbPermisoNo.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            /* La guarda de verdad, en el servidor: el botón escondido de
               Bloqueo() solo evita ofrecerlo. Un postback armado a mano llega
               igual acá, y acá se corta. */
            if (!Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"))
            {
                Tools.tools.ClientAlert("No tiene permiso para crear o editar actividades de un plan.", "alerta");
                return;
            }

            PlanActividad entidad = new PlanActividad();
            PlanActividadController controller = new PlanActividadController();

            entidad.paa_id = Id;
            entidad.paa_plan_mantenimiento_hito = string.IsNullOrEmpty(cboHito.SelectedValue) ? 0 : int.Parse(cboHito.SelectedValue);
            entidad.paa_codigo = txtCodigo.Text.Trim().ToUpper();
            entidad.paa_nombre = txtNombre.Text.Trim();
            entidad.paa_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            entidad.paa_obligatoria = rdbObligatoriaSi.Checked;
            entidad.paa_requiere_parada = rdbParadaSi.Checked;
            entidad.paa_requiere_permiso = rdbPermisoSi.Checked;
            entidad.paa_habilitado = rdbSi.Checked;

            int orden;
            if (int.TryParse(txtOrden.Text.Trim(), out orden) && orden > 0) entidad.paa_orden = orden;

            /* Los números se validan ACÁ con un mensaje entendible y no se
               dejan caer al SP: «abc» en la duración no es una regla de
               negocio, es un tipeo, y el mensaje de conversión de SQL no lo
               explica. */
            if (!string.IsNullOrEmpty(txtDuracion.Text.Trim()))
            {
                int duracion;
                if (!int.TryParse(txtDuracion.Text.Trim(), out duracion) || duracion <= 0)
                {
                    Tools.tools.ClientAlert("La duración estimada debe ser un número de minutos mayor que cero.", "alerta");
                    return;
                }
                entidad.paa_duracion_estimada_minuto = duracion;
            }
            else entidad.quita_duracion = true;

            if (!string.IsNullOrEmpty(cboProcedimiento.SelectedValue))
                entidad.paa_procedimiento = int.Parse(cboProcedimiento.SelectedValue);
            else entidad.quita_procedimiento = true;

            /* «Requiere permiso» sin decir de qué tipo no sirve para emitir
               nada, y el SP lo rechaza. Se dice acá, apuntando al campo, en
               vez de dejar que vuelva el número de regla del SP. */
            if (entidad.paa_requiere_permiso && string.IsNullOrEmpty(cboPermisoTipo.SelectedValue))
            {
                Tools.tools.ClientAlert("Si la actividad requiere permiso de trabajo, indique de qué tipo.", "alerta");
                return;
            }

            if (!string.IsNullOrEmpty(cboPermisoTipo.SelectedValue))
                entidad.paa_permiso_trabajo_tipo = int.Parse(cboPermisoTipo.SelectedValue);
            else entidad.quita_permiso_tipo = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdatePlanActividad(entidad)
                : controller.InsertPlanActividad(entidad);

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
