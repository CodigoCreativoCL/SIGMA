using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// La orden de trabajo como centro (HU-110, HU-112, HU-120, HU-124): Ficha,
/// Asignacion, Pasos (lectura), Indisponibilidad y Cierre. Mismo esquema
/// que el plan: Default.master, pestañas, ids cifrados, modales para lo
/// chico. Las reglas -jerarquia del cierre, un solo responsable, registro
/// posterior con dos fechas- las decide el SP; aqui se traduce el tipeo y
/// se esconde lo que no aplica.
/// </summary>
public partial class View_Mantenimiento_Ordenes_OrdenTrabajo : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    private string _activoEditar = null, _areaEditar = null;
    private OrdenTrabajo _orden = null;

    protected string QueryNuevaAsignacion { get { return Id > 0 ? Cifrar("Id=0&Orden=" + Id) : "0"; } }
    protected string QueryNuevaIndisponibilidad
    {
        get
        {
            if (Id == 0) return "0";
            OrdenTrabajo o = Orden();
            return Cifrar("Id=0&Orden=" + Id + "&Activo=" + (o.otr_activo ?? 0));
        }
    }

    private string Cifrar(string texto) { return Server.UrlEncode(Tools.Crypto.Encrypt(texto)); }

    private OrdenTrabajo Orden()
    {
        if (_orden == null) _orden = new OrdenTrabajoController().GetOrden(Id);
        return _orden;
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");

            GridAsignaciones.AddSelectColumn();
            GridAsignaciones.AddTemplateColumn("QUIEN", "", "QUIÉN", Width: "30%");
            GridAsignaciones.AddTemplateColumn("ROL", "", "ROL", Width: "16%");
            GridAsignaciones.AddColumn("GRUPO_NOMBRE", "GRUPO", Width: "16%");
            GridAsignaciones.AddTemplateColumn("CUANDO", "", "ASIGNADA", Width: "18%");
            GridAsignaciones.AddColumn("OTA_OBSERVACION", "OBSERVACIÓN", Width: "20%");

            GridIndisponibilidad.AddTemplateColumn("PERIODO", "", "PERÍODO", Width: "34%");
            GridIndisponibilidad.AddTemplateColumn("MINUTOS", "", "MINUTOS", Width: "12%");
            GridIndisponibilidad.AddTemplateColumn("TIPO", "", "TIPO", Width: "18%");
            GridIndisponibilidad.AddColumn("MOTIVO_NOMBRE", "MOTIVO", Width: "16%");
            GridIndisponibilidad.AddColumn("AIN_MOTIVO", "DETALLE", Width: "20%");
        }
        Tools.tools.RegisterPostBackScript(GridAsignaciones);
        Tools.tools.RegisterPostBackScript(GridIndisponibilidad);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;
        RadComboBox2 ctrl = (RadComboBox2)sender;
        if (ctrl.ID == "cboPlanta")
        {
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = new ClienteInstalacionController().GetClienteInstalaciones(
                new ClienteInstalacion { filtro_cliente = SitioBase.Session.ClienteId().ToString(), filtro_habilitado = "1" });
            ctrl.DataValueField = "cin_id";
            ctrl.DataTextField = "cin_nombre";
            ctrl.DataBind();
        }
    }

    protected void cboPlanta_SelectedIndexChanged(object sender, EventArgs e) { }

    private void CargarDependientes()
    {
        string selA = string.IsNullOrEmpty(_activoEditar) ? cboActivo.SelectedValue : _activoEditar;
        string selR = string.IsNullOrEmpty(_areaEditar) ? cboArea.SelectedValue : _areaEditar;
        int cliente = SitioBase.Session.ClienteId(), planta;
        int.TryParse(cboPlanta.SelectedValue, out planta);

        cboActivo.Items.Clear();
        cboActivo.Items.Add(new RadComboBoxItem("Sin equipo (orden sobre un área)", ""));
        Activo fa = new Activo { act_cliente = cliente, filtro_habilitado = true };
        if (planta > 0) fa.filtro_cliente_instalacion = planta;
        List<Activo> activos = new ActivoController().GetActivos(fa);
        if (activos != null) foreach (Activo a in activos) cboActivo.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));

        cboArea.Items.Clear();
        cboArea.Items.Add(new RadComboBoxItem("Sin área", ""));
        if (planta > 0)
        {
            List<InstalacionArea> areas = new InstalacionAreaController().GetInstalacionAreas(new InstalacionArea { iar_cliente = cliente, iar_cliente_instalacion = planta, filtro_habilitado = true });
            if (areas != null) foreach (InstalacionArea a in areas) cboArea.Items.Add(new RadComboBoxItem(string.IsNullOrEmpty(a.ruta) ? a.iar_nombre : a.ruta, a.iar_id.ToString()));
        }

        RadComboBoxItem ia = cboActivo.FindItemByValue(selA ?? ""); if (ia != null) ia.Selected = true;
        RadComboBoxItem ir = cboArea.FindItemByValue(selR ?? ""); if (ir != null) ir.Selected = true;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarDependientes();
        Bloqueo();

        bool con = Id > 0;
        tabAsignacion.Visible = tabPasos.Visible = tabIndisponibilidad.Visible = tabCierre.Visible = con;

        if (con)
        {
            OrdenTrabajo o = Orden();
            bool puedeEscribir = Token.PuedeFuncion("Crear y editar") && o.otr_orden_trabajo_estado != 4;

            GridAsignaciones.DataSource = new OrdenTrabajoController().GetAsignaciones(Id) ?? new List<OrdenTrabajoAsignacion>();
            GridAsignaciones.DataBind();
            if (!puedeEscribir || o.otr_orden_trabajo_estado == 3) GridAsignaciones.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

            GridIndisponibilidad.DataSource = new IndisponibilidadController().Get(new ActivoIndisponibilidad { filtro_orden = Id }) ?? new List<ActivoIndisponibilidad>();
            GridIndisponibilidad.DataBind();
            if (!Token.Puede("REGISTRAR FALLA") || o.otr_activo == null) GridIndisponibilidad.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

            CargarPasos();
            CargarCierre(o);
        }

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnVolver);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnCerrarOT);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            OrdenTrabajo o = Orden();
            lblId.Text = "OT-" + o.otr_correlativo;
            txtTitulo.Text = o.otr_titulo;
            txtDescripcion.Text = o.otr_descripcion;
            txtNotas.Text = o.otr_notas;
            Seleccionar(cboTipo, o.otr_orden_trabajo_tipo.ToString());
            Seleccionar(cboEstrategia, o.otr_orden_trabajo_estrategia.ToString());
            Seleccionar(cboPrioridad, o.otr_orden_trabajo_prioridad.ToString());
            Seleccionar(cboPlanta, o.otr_cliente_instalacion.ToString());
            if (o.otr_activo != null) _activoEditar = o.otr_activo.Value.ToString();
            if (o.otr_instalacion_area != null) _areaEditar = o.otr_instalacion_area.Value.ToString();
            txtFechaProgramada.Text = o.otr_fecha_programada_utc == null ? "" : o.otr_fecha_programada_utc.Value.ToString("dd-MM-yyyy HH:mm");
            txtDuracion.Text = o.otr_duracion_estimada_minuto == null ? "" : o.otr_duracion_estimada_minuto.ToString();
            rdbPermisoSi.Checked = o.otr_requiere_permiso; rdbPermisoNo.Checked = !o.otr_requiere_permiso;
            rdbPosteriorSi.Checked = o.otr_registro_posterior; rdbPosteriorNo.Checked = !o.otr_registro_posterior;
            txtFechaOcurrencia.Text = o.otr_fecha_ocurrencia == null ? "" : o.otr_fecha_ocurrencia.Value.ToString("dd-MM-yyyy HH:mm");
            Cabecera(o);
            wucAuditoria.Mostrar(o.usuario_creacion_nombre, o.otr_fecha_creacion, o.usuario_actualizacion_nombre, o.otr_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nueva";
            litTitulo.Text = "Nueva orden de trabajo";
            litSubtitulo.Text = "Guarde la ficha y aparecerán asignación, pasos, indisponibilidad y cierre.";
        }
    }

    private void Cabecera(OrdenTrabajo o)
    {
        litTitulo.Text = Server.HtmlEncode("OT-" + o.otr_correlativo + " · " + o.otr_titulo);
        List<string> p = new List<string>();
        p.Add(o.estado_nombre);
        p.Add(o.tipo_nombre + " / " + o.estrategia_nombre);
        p.Add("origen " + (o.origen_nombre ?? "").ToLower());
        p.Add(string.IsNullOrEmpty(o.activo_codigo) ? "sin equipo · " + (o.area_nombre ?? "") : o.activo_codigo + " " + o.activo_nombre);
        if (!string.IsNullOrEmpty(o.responsable_nombre)) p.Add("responsable " + o.responsable_nombre);
        else if (!string.IsNullOrEmpty(o.responsable_proveedor)) p.Add("contratista " + o.responsable_proveedor);
        if (o.otr_registro_posterior && o.otr_fecha_ocurrencia != null) p.Add("ocurrió el " + o.otr_fecha_ocurrencia.Value.ToString("dd-MM-yyyy HH:mm") + ", registrada el " + (o.otr_fecha_creacion ?? DateTime.MinValue).ToString("dd-MM-yyyy HH:mm"));
        litSubtitulo.Text = Server.HtmlEncode(string.Join(" · ", p.ToArray()));

        pnlCerrada.Visible = o.otr_orden_trabajo_estado == 4;
        if (pnlCerrada.Visible)
            litCerrada.Text = "<strong>Cerrada</strong> el " + (o.otr_fecha_cierre ?? DateTime.MinValue).ToString("dd-MM-yyyy HH:mm") + " por " + Server.HtmlEncode(o.cierre_usuario_nombre)
                            + " · " + Server.HtmlEncode(o.cierre_motivo_nombre) + (string.IsNullOrEmpty(o.otr_resultado) ? "" : "<br/>" + Server.HtmlEncode(o.otr_resultado));
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool cerrada = Id > 0 && Orden().otr_orden_trabajo_estado == 4;
        bool puede = Token.Puede("CREAR ORDEN TRABAJO") && !cerrada;

        txtTitulo.ReadOnly = txtDescripcion.ReadOnly = txtNotas.ReadOnly = txtFechaProgramada.ReadOnly = txtDuracion.ReadOnly = txtFechaOcurrencia.ReadOnly = !puede;
        cboTipo.ReadOnly = cboEstrategia.ReadOnly = cboPrioridad.ReadOnly = !puede;
        // Donde y el registro posterior se fijan al crear: despues la orden ya tiene historia.
        cboPlanta.Enabled = cboActivo.Enabled = cboArea.Enabled = Id == 0;
        cboTipo.Enabled = Id == 0;
        rdbPosteriorSi.Enabled = rdbPosteriorNo.Enabled = Id == 0;
        txtFechaOcurrencia.ReadOnly = Id > 0;
        rdbPermisoSi.Enabled = rdbPermisoNo.Enabled = puede;
        btnGuardar.Visible = puede;
    }

    private static DateTime? Fecha(string texto, string campo)
    {
        string t = (texto ?? "").Trim();
        if (t.Length == 0) return null;
        DateTime d;
        string[] formatos = { "dd-MM-yyyy HH:mm", "dd-MM-yyyy", "dd/MM/yyyy HH:mm", "dd/MM/yyyy" };
        if (DateTime.TryParseExact(t, formatos, CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) return d;
        throw new Exception("\"" + t + "\" no es una fecha válida en " + campo + " (dd-mm-aaaa hh:mm).");
    }

    protected void btnVolver_Click(object sender, EventArgs e)
    {
        Response.Redirect("~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx");
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            OrdenTrabajo o = new OrdenTrabajo();
            o.otr_id = Id;
            o.otr_titulo = txtTitulo.Text.Trim();
            o.otr_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            o.otr_notas = string.IsNullOrEmpty(txtNotas.Text.Trim()) ? null : txtNotas.Text.Trim();
            o.otr_orden_trabajo_tipo = int.Parse(cboTipo.SelectedValue);
            o.otr_orden_trabajo_estrategia = int.Parse(cboEstrategia.SelectedValue);
            o.otr_orden_trabajo_prioridad = int.Parse(cboPrioridad.SelectedValue);
            if (!string.IsNullOrEmpty(cboPlanta.SelectedValue)) o.otr_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            if (!string.IsNullOrEmpty(cboActivo.SelectedValue)) o.otr_activo = int.Parse(cboActivo.SelectedValue);
            if (!string.IsNullOrEmpty(cboArea.SelectedValue)) o.otr_instalacion_area = int.Parse(cboArea.SelectedValue);
            o.otr_fecha_programada_utc = Fecha(txtFechaProgramada.Text, "Fecha programada");
            o.quita_fecha = o.otr_fecha_programada_utc == null;
            if (!string.IsNullOrEmpty(txtDuracion.Text.Trim()))
            {
                int d;
                if (!int.TryParse(txtDuracion.Text.Trim(), out d) || d <= 0) throw new Exception("La duración estimada tiene que ser un entero de minutos mayor que cero.");
                o.otr_duracion_estimada_minuto = d;
            }
            else o.quita_duracion = true;
            o.otr_requiere_permiso = rdbPermisoSi.Checked;
            o.otr_registro_posterior = rdbPosteriorSi.Checked;
            o.otr_fecha_ocurrencia = Fecha(txtFechaOcurrencia.Text, "Cuándo ocurrió");

            OrdenTrabajoController c = new OrdenTrabajoController();
            bool nueva = Id == 0;
            Respuesta r = nueva ? c.Insert(o) : c.Update(o);
            if (!r.error)
            {
                if (nueva) Response.Redirect("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx?query=" + Cifrar("Id=" + r.codigo));
                _orden = null;
                Cabecera(Orden());
                Tools.tools.ClientAlert(r.detalle, "ok");
            }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #region Asignacion (HU-112)

    protected void GridAsignaciones_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;
        GridDataItem item = e.Item as GridDataItem;
        OrdenTrabajoAsignacion a = item.DataItem as OrdenTrabajoAsignacion;
        if (a == null) return;

        string quien = a.ota_usuario != null
            ? Server.HtmlEncode(a.usuario_nombre) + (string.IsNullOrEmpty(a.especialidades) ? "" : "<br/><span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(a.especialidades) + "</span>")
            : "<i class=\"mdi mdi-domain\"></i> " + Server.HtmlEncode(a.proveedor_nombre) + "<br/><span class=\"sigma-inv-vacio\">empresa externa</span>";
        item["QUIEN"].Controls.Add(new Literal { Text = quien });
        item["ROL"].Controls.Add(new Literal
        {
            Text = a.ota_es_responsable ? "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-account-star\"></i>Responsable</span>"
                                        : "<span class=\"grid-estado-chip is-neutro\">" + Server.HtmlEncode(a.rol_nombre ?? "Apoyo") + "</span>"
        });
        item["CUANDO"].Controls.Add(new Literal
        {
            Text = (a.ota_fecha_asignacion_utc == null ? "" : a.ota_fecha_asignacion_utc.Value.ToString("dd-MM-yyyy HH:mm"))
                 + "<br/><span class=\"sigma-inv-vacio\">por " + Server.HtmlEncode(a.asignado_por_nombre) + "</span>"
        });
        if (string.IsNullOrEmpty(a.grupo_nombre)) item["GRUPO_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">—</span>";
        if (!string.IsNullOrEmpty(a.ota_observacion) && a.ota_observacion.Contains("especialidad"))
            item["OTA_OBSERVACION"].Text = "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-alert-outline\"></i>advertencia</span> " + Server.HtmlEncode(a.ota_observacion);
    }

    protected void lnkQuitarAsignacion_Click(object sender, EventArgs e)
    {
        Pestana(tabAsignacion, pvAsignacion);
        try
        {
            if (GridAsignaciones.SelectedIndexes.Count == 0) { Tools.tools.ClientAlert("Seleccione al menos una asignación."); return; }
            Respuesta r = new Respuesta();
            foreach (string i in GridAsignaciones.SelectedIndexes)
            {
                r = new OrdenTrabajoController().QuitarAsignacion(Int32.Parse(GridAsignaciones.MasterTableView.DataKeyValues[Int32.Parse(i)]["ota_id"].ToString()));
                if (r.error) break;
            }
            _orden = null; Cabecera(Orden());
            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message); }
    }

    #endregion

    #region Pasos e indisponibilidad

    private void CargarPasos()
    {
        List<Dictionary<string, object>> pasos = LeerPasos();
        if (pasos.Count == 0) { litPasos.Text = "<span class=\"sigma-inv-vacio\">Esta orden no tiene pasos todavía.</span>"; return; }

        StringBuilder sb = new StringBuilder("<div class=\"sigma-lista\">");
        foreach (Dictionary<string, object> p in pasos)
        {
            string cod = (p["RESULTADO_CODIGO"] ?? "").ToString();
            string chip = cod == "CONFORME" ? "is-exito" : cod == "NO CONFORME" ? "is-alerta" : cod == "NO APLICA" ? "is-neutro" : "is-advertencia";
            sb.Append("<div class=\"sigma-lista-fila\" style=\"padding:8px 0; border-bottom:1px solid #eee;\">")
              .Append("<strong>").Append(p["otp_orden"]).Append(". ").Append(Server.HtmlEncode((p["otp_nombre"] ?? "").ToString())).Append("</strong> ")
              .Append("<span class=\"grid-estado-chip ").Append(chip).Append("\">").Append(Server.HtmlEncode((p["RESULTADO_NOMBRE"] ?? "").ToString())).Append("</span>")
              .Append(Convert.ToBoolean(p["otp_obligatorio"]) ? "" : " <span class=\"sigma-inv-vacio\">opcional</span>");
            if (!string.IsNullOrEmpty((p["otp_descripcion"] ?? "").ToString())) sb.Append("<div class=\"sigma-inv-vacio\">").Append(Server.HtmlEncode(p["otp_descripcion"].ToString())).Append("</div>");
            if (!string.IsNullOrEmpty((p["EJECUTOR_NOMBRE"] ?? "").ToString()))
                sb.Append("<div class=\"sigma-inv-vacio\">").Append(Server.HtmlEncode(p["EJECUTOR_NOMBRE"].ToString()))
                  .Append(p["otp_fecha_ejecucion_utc"] == null ? "" : " · " + ((DateTime)p["otp_fecha_ejecucion_utc"]).ToString("dd-MM-yyyy HH:mm"))
                  .Append(string.IsNullOrEmpty((p["otp_resultado"] ?? "").ToString()) ? "" : " · " + Server.HtmlEncode(p["otp_resultado"].ToString())).Append("</div>");
            sb.Append("</div>");
        }
        litPasos.Text = sb.Append("</div>").ToString();
    }

    private List<Dictionary<string, object>> LeerPasos()
    {
        List<Dictionary<string, object>> lista = new List<Dictionary<string, object>>();
        System.Data.SqlClient.SqlCommand cmd = new System.Data.SqlClient.SqlCommand();
        try
        {
            cmd.CommandText = "SEL_ORDEN_TRABAJO_PASO";
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());
            cmd.Parameters.AddWithValue("@ORDEN", Id);
            using (System.Data.SqlClient.SqlDataReader dr = Conexion.GetDataReader(cmd))
                while (dr.Read())
                {
                    Dictionary<string, object> f = new Dictionary<string, object>();
                    for (int i = 0; i < dr.FieldCount; i++) f[dr.GetName(i)] = dr.IsDBNull(i) ? null : dr.GetValue(i);
                    lista.Add(f);
                }
            cmd.Connection.Close(); cmd.Dispose();
        }
        catch (Exception) { if (cmd.Connection != null) cmd.Connection.Close(); }
        return lista;
    }

    protected void GridIndisponibilidad_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;
        GridDataItem item = e.Item as GridDataItem;
        ActivoIndisponibilidad i = item.DataItem as ActivoIndisponibilidad;
        if (i == null) return;
        item["PERIODO"].Controls.Add(new Literal { Text = i.ain_fecha_inicio_utc.ToString("dd-MM-yyyy HH:mm") + " → " + (i.ain_fecha_fin_utc == null ? "<span class=\"grid-estado-chip is-alerta\">abierta</span>" : i.ain_fecha_fin_utc.Value.ToString("dd-MM-yyyy HH:mm")) });
        item["MINUTOS"].Controls.Add(new Literal { Text = "<strong>" + i.minutos_acumulados + "</strong>" });
        item["TIPO"].Controls.Add(new Literal
        {
            Text = (i.ain_planificada ? "<span class=\"grid-estado-chip is-neutro\">planificada</span>" : "<span class=\"grid-estado-chip is-alerta\">no planificada</span>")
                 + (i.ain_detuvo_produccion ? " <span class=\"grid-estado-chip is-advertencia\">detuvo producción</span>" : "")
        });
    }

    #endregion

    #region Cierre (HU-120)

    private void CargarCierre(OrdenTrabajo o)
    {
        bool puedeCerrar = Token.PuedeFuncion("Cerrar");
        pnlFormCierre.Visible = puedeCerrar && o.otr_orden_trabajo_estado != 4;

        if (o.otr_orden_trabajo_estado == 4)
            litEstadoCierre.Text = "<div class=\"sigma-form-seccion\"><div class=\"titulo\"><i class=\"mdi mdi-check-circle\"></i>Cerrada</div><div>"
                + (o.otr_fecha_cierre ?? DateTime.MinValue).ToString("dd-MM-yyyy HH:mm") + " · " + Server.HtmlEncode(o.cierre_usuario_nombre) + " · <strong>" + Server.HtmlEncode(o.cierre_motivo_nombre) + "</strong>"
                + (string.IsNullOrEmpty(o.otr_resultado) ? "" : "<br/>" + Server.HtmlEncode(o.otr_resultado)) + "</div></div>";
        else
        {
            string s = "<div style=\"margin:0 0 10px;\">" + View_Mantenimiento_Ordenes_OrdenTrabajos.ChipEstado(o.estado_codigo, o.estado_nombre);
            s += " · " + (o.pasos - o.pasos_pendientes) + "/" + o.pasos + " pasos resueltos";
            if (o.permisos_pendientes > 0) s += " · <span class=\"grid-estado-chip is-alerta\">" + o.permisos_pendientes + " permiso(s) sin autorizar</span>";
            if (!puedeCerrar) s += "<br/><span class=\"sigma-inv-vacio\">Su perfil no tiene la facultad de cerrar órdenes de trabajo.</span>";
            litEstadoCierre.Text = s + "</div>";
        }
    }

    protected void btnCerrarOT_Click(object sender, EventArgs e)
    {
        Pestana(tabCierre, pvCierre);
        try
        {
            if (!Token.PuedeFuncion("Cerrar")) throw new Exception("Su perfil no tiene la facultad de cerrar órdenes de trabajo.");
            Respuesta r = new OrdenTrabajoController().Cerrar(Id, int.Parse(cboMotivoCierre.SelectedValue), txtResultadoCierre.Text.Trim());
            if (!r.error) { _orden = null; Cabecera(Orden()); }
            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion

    private void Pestana(RadTab tab, RadPageView vista) { tab.Selected = true; vista.Selected = true; }
}
