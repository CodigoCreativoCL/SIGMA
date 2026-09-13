using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// La tarea recurrente como centro (HU-102, HU-104): Ficha (que es),
/// Programaciones (cada cuanto y quien) y Comentarios (lo que se dijo en
/// cada ejecucion). Mismo esquema que el plan de mantenimiento: en
/// Default.master, con pestañas, los ids cifrados y las fichas chicas en
/// modal.
/// </summary>
public partial class View_Mantenimiento_Tareas_Tarea : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    private string _areaEditar = null, _activoEditar = null;

    protected string QueryNuevaProgramacion { get { return Id > 0 ? Cifrar("Id=0&Tarea=" + Id) : "0"; } }

    private string Cifrar(string texto) { return Server.UrlEncode(Tools.Crypto.Encrypt(texto)); }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (Request.QueryString["query"] != null)
            {
                string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');
                foreach (string arr in query)
                {
                    string[] array = arr.Split('=');
                    if (array[0] == "Id") Id = Int32.Parse(array[1]);
                }
            }

            GridProgramaciones.AddSelectColumn();
            GridProgramaciones.AddColumn("TPR_ID", "", Width: "3%");
            GridProgramaciones.AddColumn("PROGRAMACION_NOMBRE", "CADA CUÁNTO", Width: "26%");
            GridProgramaciones.AddColumn("RESPONSABLE_NOMBRE", "RESPONSABLE", Width: "20%");
            GridProgramaciones.AddColumn("GRUPO_NOMBRE", "GRUPO", Width: "20%");
            GridProgramaciones.AddTemplateColumn("VIGENCIA", "", "VIGENCIA", Width: "16%");
            GridProgramaciones.AddColumn("OCURRENCIAS", "OCURR.", Width: "6%");
            GridProgramaciones.AddCheckboxColumn("TPR_HABILITADO", "HABILITADA");
        }

        Tools.tools.RegisterPostBackScript(GridProgramaciones);
    }

    #region Combos

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack) return;
        if (!(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;

        if (ctrl.ID == "cboPlanta")
        {
            ClienteInstalacion filtro = new ClienteInstalacion { filtro_cliente = SitioBase.Session.ClienteId().ToString(), filtro_habilitado = "1" };
            ctrl.Items.Add(new RadComboBoxItem("Cualquier planta", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = new ClienteInstalacionController().GetClienteInstalaciones(filtro);
            ctrl.DataValueField = "cin_id";
            ctrl.DataTextField = "cin_nombre";
            ctrl.DataBind();
        }
    }

    protected void cboPlanta_SelectedIndexChanged(object sender, EventArgs e) { }

    /// <summary>Area y equipo dependen de la planta; se rearman en cada postback conservando lo elegido.</summary>
    private void CargarDependientes()
    {
        string selA = string.IsNullOrEmpty(_areaEditar) ? cboArea.SelectedValue : _areaEditar;
        string selE = string.IsNullOrEmpty(_activoEditar) ? cboActivo.SelectedValue : _activoEditar;
        int cliente = SitioBase.Session.ClienteId();
        int planta;
        int.TryParse(cboPlanta.SelectedValue, out planta);

        cboArea.Items.Clear();
        cboArea.Items.Add(new RadComboBoxItem("Sin área", ""));
        if (planta > 0)
        {
            List<InstalacionArea> areas = new InstalacionAreaController().GetInstalacionAreas(
                new InstalacionArea { iar_cliente = cliente, iar_cliente_instalacion = planta, filtro_habilitado = true });
            if (areas != null)
                foreach (InstalacionArea a in areas)
                    cboArea.Items.Add(new RadComboBoxItem((string.IsNullOrEmpty(a.ruta) ? a.iar_nombre : a.ruta), a.iar_id.ToString()));
        }

        cboActivo.Items.Clear();
        cboActivo.Items.Add(new RadComboBoxItem("Sin equipo", ""));
        Activo fa = new Activo { act_cliente = cliente, filtro_habilitado = true };
        if (planta > 0) fa.filtro_cliente_instalacion = planta;
        List<Activo> activos = new ActivoController().GetActivos(fa);
        if (activos != null)
            foreach (Activo a in activos)
                cboActivo.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));

        RadComboBoxItem ia = cboArea.FindItemByValue(selA ?? ""); if (ia != null) ia.Selected = true;
        RadComboBoxItem ie = cboActivo.FindItemByValue(selE ?? ""); if (ie != null) ie.Selected = true;
    }

    private void ConfigurarPrioridades()
    {
        if (cboPrioridad.Items.Count > 0) return;
        // Tarea_Prioridad: catalogo fijo del bloque 159.
        cboPrioridad.Items.Add(new RadComboBoxItem("Baja", "1"));
        cboPrioridad.Items.Add(new RadComboBoxItem("Media", "2") { Selected = true });
        cboPrioridad.Items.Add(new RadComboBoxItem("Alta", "3"));
        cboPrioridad.Items.Add(new RadComboBoxItem("Crítica", "4"));
    }

    #endregion

    protected void Page_PreRender(object sender, EventArgs e)
    {
        ConfigurarPrioridades();
        CargarDatos();
        CargarDependientes();
        Bloqueo();

        bool conTarea = Id > 0;
        tabProgramaciones.Visible = conTarea;
        tabComentarios.Visible = conTarea;

        if (conTarea)
        {
            if (!Token.PuedeFuncion("Crear y editar"))
                GridProgramaciones.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

            GridProgramaciones.DataSource = new TareaController().GetTareaProgramaciones(
                new TareaProgramacion { filtro_cliente = SitioBase.Session.ClienteId(), filtro_tarea = Id });
            GridProgramaciones.DataBind();

            CargarComentarios();
        }

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnVolver);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Tarea");

        if (Id > 0)
        {
            Tarea t = new TareaController().GetTarea(new Tarea { tar_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Tarea", t.tar_codigo);
            txtTitulo.Text = t.tar_titulo;
            txtDescripcion.Text = t.tar_descripcion;
            txtDuracion.Text = t.tar_duracion_estimada_minuto == null ? "" : t.tar_duracion_estimada_minuto.ToString();
            Seleccionar(cboPrioridad, t.tar_tarea_prioridad.ToString());
            if (t.tar_cliente_instalacion != null) Seleccionar(cboPlanta, t.tar_cliente_instalacion.Value.ToString());
            if (t.tar_instalacion_area != null) _areaEditar = t.tar_instalacion_area.Value.ToString();
            if (t.tar_activo != null) _activoEditar = t.tar_activo.Value.ToString();
            rdbEvidenciaSi.Checked = t.tar_requiere_evidencia;
            rdbEvidenciaNo.Checked = !t.tar_requiere_evidencia;
            rdbSi.Checked = t.tar_habilitado;
            rdbNo.Checked = !t.tar_habilitado;

            litTitulo.Text = Server.HtmlEncode(t.tar_codigo + " · " + t.tar_titulo);
            List<string> partes = new List<string>();
            partes.Add("Prioridad " + (t.prioridad_nombre ?? "").ToLower());
            partes.Add(string.IsNullOrEmpty(t.planta_nombre) ? "cualquier planta" : t.planta_nombre);
            if (!string.IsNullOrEmpty(t.activo_nombre)) partes.Add(t.activo_codigo + " " + t.activo_nombre);
            partes.Add(t.programaciones + (t.programaciones == 1 ? " programación" : " programaciones"));
            if (t.pendientes > 0) partes.Add(t.pendientes + " pendientes");
            litSubtitulo.Text = Server.HtmlEncode(string.Join(" · ", partes.ToArray()));

            wucAuditoria.Mostrar(t.usuario_creacion_nombre, t.tar_fecha_creacion, t.usuario_actualizacion_nombre, t.tar_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nueva";
            litTitulo.Text = "Nueva tarea recurrente";
            litSubtitulo.Text = "Guarde la ficha y aparecerán las pestañas de programaciones y comentarios.";
        }
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR TAREAS");

        txtCodigo.ReadOnly = Id > 0;
        txtTitulo.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        txtDuracion.ReadOnly = !puedeEditar;
        cboPrioridad.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        cboArea.ReadOnly = !puedeEditar;
        cboActivo.ReadOnly = !puedeEditar;
        rdbEvidenciaSi.Enabled = rdbEvidenciaNo.Enabled = puedeEditar;
        rdbSi.Enabled = rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;

        pnlResponder.Visible = Token.Puede("COMENTAR TAREA");
    }

    protected void btnVolver_Click(object sender, EventArgs e)
    {
        Response.Redirect("~/View/Mantenimiento/Tareas/Tareas.aspx");
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            Tarea t = new Tarea();
            TareaController controller = new TareaController();

            t.tar_id = Id;
            t.tar_codigo = SitioBase.CodigoModulo.Componer("Tarea", txtCodigo.Text);
            t.tar_titulo = txtTitulo.Text.Trim();
            t.tar_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            if (t.tar_descripcion == null) t.quita_descripcion = true;
            t.tar_tarea_prioridad = int.Parse(cboPrioridad.SelectedValue);
            t.tar_requiere_evidencia = rdbEvidenciaSi.Checked;
            t.tar_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(txtDuracion.Text.Trim()))
            {
                int d;
                if (!int.TryParse(txtDuracion.Text.Trim(), out d) || d <= 0)
                    throw new Exception("La duración estimada tiene que ser un número entero de minutos mayor que cero.");
                t.tar_duracion_estimada_minuto = d;
            }
            else t.quita_duracion = true;

            if (!string.IsNullOrEmpty(cboPlanta.SelectedValue)) t.tar_cliente_instalacion = int.Parse(cboPlanta.SelectedValue); else t.quita_instalacion = true;
            if (!string.IsNullOrEmpty(cboArea.SelectedValue)) t.tar_instalacion_area = int.Parse(cboArea.SelectedValue); else t.quita_area = true;
            if (!string.IsNullOrEmpty(cboActivo.SelectedValue)) t.tar_activo = int.Parse(cboActivo.SelectedValue); else t.quita_activo = true;

            bool nueva = Id == 0;
            Respuesta r = nueva ? controller.InsertTarea(t) : controller.UpdateTarea(t);

            if (!r.error)
            {
                if (nueva)
                    Response.Redirect("~/View/Mantenimiento/Tareas/Tarea.aspx?query=" + Cifrar("Id=" + r.codigo));
                Tools.tools.ClientAlert(r.detalle, "ok");
            }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #region Programaciones

    protected void GridProgramaciones_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        TareaProgramacion p = item.DataItem as TareaProgramacion;
        if (p == null) return;

        string id = item.GetDataKeyValue("tpr_id").ToString();
        string query = Cifrar("Id=" + id + "&Tarea=" + Id);

        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditarProg" + id;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirTareaProgramacion('" + query + "')");
        item["tpr_id"].Controls.Add(Editar);

        item["PROGRAMACION_NOMBRE"].Text = Server.HtmlEncode(p.programacion_nombre)
            + (string.IsNullOrEmpty(p.programacion_tipo_nombre) ? "" : "<br/><span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(p.programacion_tipo_nombre) + "</span>");
        if (string.IsNullOrEmpty(p.responsable_nombre)) item["RESPONSABLE_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">sin responsable</span>";
        if (string.IsNullOrEmpty(p.grupo_nombre)) item["GRUPO_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">sin grupo</span>";

        string vig = p.programacion_fecha_inicio == null ? "" : "desde " + p.programacion_fecha_inicio.Value.ToString("dd-MM-yyyy");
        if (p.programacion_fecha_fin != null) vig += " hasta " + p.programacion_fecha_fin.Value.ToString("dd-MM-yyyy");
        if (!p.programacion_habilitado) vig += " <span class=\"grid-estado-chip is-alerta\">programación apagada</span>";
        item["VIGENCIA"].Controls.Add(new Literal { Text = vig });
    }

    protected void lnkQuitarProgramacion_Click(object sender, EventArgs e)
    {
        Pestana(tabProgramaciones, pvProgramaciones);
        try
        {
            if (GridProgramaciones.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            Respuesta r = new Respuesta();
            foreach (string indice in GridProgramaciones.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = GridProgramaciones.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                r = new TareaController().DeleteTareaProgramacion(new TareaProgramacion { tpr_id = Int32.Parse(value["tpr_id"].ToString()) });
                if (r.error) break;
            }

            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message); }
    }

    protected void lnkGenerarOcurrencias_Click(object sender, EventArgs e)
    {
        Pestana(tabProgramaciones, pvProgramaciones);
        try
        {
            if (!Token.Puede("CREAR EDITAR TAREAS"))
                throw new Exception("No tiene permiso para generar ocurrencias.");

            Respuesta r = new TareaController().GenerarOcurrencias(Id, 90);
            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion

    #region Comentarios (HU-104)

    /// <summary>
    /// El hilo se dibuja a mano: una tarjeta por ocurrencia, con sus
    /// comentarios y las respuestas con sangria. Una grilla plana perderia
    /// la conversacion, que es lo que importa leer.
    /// </summary>
    private void CargarComentarios()
    {
        List<TareaComentario> lista = new TareaController().GetTareaComentarios(
            new TareaComentario { filtro_cliente = SitioBase.Session.ClienteId(), filtro_tarea = Id }) ?? new List<TareaComentario>();

        litSinComentarios.Visible = lista.Count == 0;

        StringBuilder sb = new StringBuilder();
        int ocurrenciaActual = 0;
        bool puedeComentar = Token.Puede("COMENTAR TAREA");

        foreach (TareaComentario c in lista)
        {
            if (c.tco_tarea_ocurrencia != ocurrenciaActual)
            {
                if (ocurrenciaActual != 0) sb.Append("</div>");
                ocurrenciaActual = c.tco_tarea_ocurrencia;
                sb.Append("<div class=\"sg-hilo\"><div class=\"sg-hilo-cab\">")
                  .Append("<i class=\"mdi mdi-calendar-check-outline\"></i> Ocurrencia del ")
                  .Append(c.ocurrencia_fecha == null ? "" : c.ocurrencia_fecha.Value.ToString("dd-MM-yyyy HH:mm"))
                  .Append(" ").Append(ChipEstado(c.ocurrencia_estado_codigo, c.ocurrencia_estado_nombre));
                if (puedeComentar)
                    sb.Append(" <a href=\"javascript:void(0)\" onclick=\"return responder(").Append(c.tco_tarea_ocurrencia).Append(", '', '')\"><i class=\"mdi mdi-comment-plus-outline\"></i> Comentar</a>");
                sb.Append("</div>");
            }

            sb.Append("<div class=\"sg-com").Append(c.tco_comentario_padre != null ? " is-respuesta" : "").Append("\">")
              .Append("<div class=\"sg-com-meta\"><strong>").Append(Server.HtmlEncode(c.usuario_nombre)).Append("</strong> · ")
              .Append(c.tco_fecha_creacion == null ? "" : c.tco_fecha_creacion.Value.ToString("dd-MM-yyyy HH:mm"))
              .Append(c.tco_dictado_voz != null ? " · <i class=\"mdi mdi-microphone\" title=\"Dictado por voz\"></i>" : "")
              .Append("</div><div class=\"sg-com-texto\">").Append(Server.HtmlEncode(c.tco_texto)).Append("</div>");
            if (puedeComentar)
                sb.Append("<div class=\"sg-com-acciones\"><a href=\"javascript:void(0)\" onclick=\"return responder(")
                  .Append(c.tco_tarea_ocurrencia).Append(", ").Append(c.tco_id).Append(", '")
                  .Append(Server.HtmlEncode(c.usuario_nombre).Replace("'", "\\'")).Append("')\"><i class=\"mdi mdi-reply\"></i> Responder</a></div>");
            sb.Append("</div>");
        }
        if (ocurrenciaActual != 0) sb.Append("</div>");

        litHilos.Text = sb.ToString();
    }

    private static string ChipEstado(string codigo, string nombre)
    {
        switch ((codigo ?? "").ToUpperInvariant())
        {
            case "COMPLETADA":   return "<span class=\"grid-estado-chip is-exito\">" + nombre + "</span>";
            case "NO REALIZADA":
            case "CANCELADA":    return "<span class=\"grid-estado-chip is-alerta\">" + nombre + "</span>";
            case "EN EJECUCION": return "<span class=\"grid-estado-chip is-advertencia\">" + nombre + "</span>";
            default:             return "<span class=\"grid-estado-chip is-neutro\">" + nombre + "</span>";
        }
    }

    protected void btnComentar_Click(object sender, EventArgs e)
    {
        Pestana(tabComentarios, pvComentarios);
        try
        {
            if (!Token.Puede("COMENTAR TAREA"))
                throw new Exception("No tiene permiso para comentar tareas.");

            int ocurrencia, padre;
            if (!int.TryParse(hidOcurrencia.Value, out ocurrencia) || ocurrencia <= 0)
                throw new Exception("Elija en qué ocurrencia comentar: «Comentar» en la tarjeta o «Responder» en un comentario.");

            TareaComentario c = new TareaComentario { tco_tarea_ocurrencia = ocurrencia, tco_texto = txtComentario.Text.Trim() };
            if (int.TryParse(hidPadre.Value, out padre) && padre > 0) c.tco_comentario_padre = padre;

            Respuesta r = new TareaController().InsertTareaComentario(c);
            if (!r.error)
            {
                txtComentario.Text = "";
                hidPadre.Value = "";
                Tools.tools.ClientAlert(r.detalle, "ok");
            }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion

    private void Pestana(RadTab tab, RadPageView vista)
    {
        tab.Selected = true;
        vista.Selected = true;
    }
}
