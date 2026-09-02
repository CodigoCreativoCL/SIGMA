using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Ficha de la programación (HU-070 a HU-075, bloques 103-107).
///
/// UNA FICHA CON CINCO VARIANTES, NO CINCO FICHAS
///   El combo de tipo intercambia un panel. Todo lo demás —vigencia,
///   tolerancias, zona horaria, exclusiones— es igual en los cinco tipos,
///   así que vive una sola vez.
///
/// EL DETALLE NECESITA QUE LA CABECERA EXISTA
///   Programacion_Calendario, _Intervalo, _Medidor, _Fecha y _Exclusion
///   tienen FK a Programacion. En un registro nuevo no hay id al que
///   colgarlas, así que esas secciones aparecen recién después de guardar.
///   Es la razón del panel "Guarde primero".
///
/// LAS PRÓXIMAS FECHAS NO SON OCURRENCIAS
///   Salen de FNC_PROGRAMACION_FECHAS, que calcula sin escribir nada. Sirven
///   para comprobar que la regla dice lo que uno cree ANTES de que empiece a
///   generar trabajo. Las ocurrencias reales las crea HU-076, que necesita el
///   plan de mantenimiento del Sprint 4.
/// </summary>
public partial class View_Mantenimiento_Programaciones_Programacion : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>
    /// El código del tipo elegido. Se guarda porque el panel que hay que
    /// mostrar depende de él en cada postback, y volver a consultarlo sería
    /// una ida a la base por cada click.
    /// </summary>
    public string TipoCodigo
    {
        get { return ViewState["TipoCodigo"] != null ? (string)ViewState["TipoCodigo"] : ""; }
        set { ViewState["TipoCodigo"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            /* Querystring.Entero recibe el valor TAL COMO VIENE de la URL:
               descifra por dentro. Pasarle el resultado de Descifrar lo hace
               descifrar dos veces, la segunda falla, y como el helper no
               lanza devuelve 0 en silencio: la ficha se abre en blanco como
               si fuera un registro nuevo. */
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");

            CargarCombos();
            CargarDatos();
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        PintarPaneles();
        Bloqueo();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    #region Combos

    protected void CargarCombos()
    {
        ProgramacionController controller = new ProgramacionController();

        Llenar(cboTipo, controller.GetCatalogo("PROGRAMACION_TIPO"), false);
        Llenar(cboZonaHoraria, controller.GetCatalogo("ZONA_HORARIA"), true);
        Llenar(cboFrecuencia, controller.GetCatalogo("FRECUENCIA_TIPO"), false);
        Llenar(cboUnidadTiempo, controller.GetCatalogo("UNIDAD_TIEMPO"), false);
        Llenar(cboPolitica, controller.GetCatalogo("CUMPLIMIENTO_POLITICA"), true);
        Llenar(cboOperador, controller.GetCatalogo("OPERADOR_COMPARACION"), false);
        Llenar(cboSeveridad, controller.GetCatalogo("SEVERIDAD"), false);

        // Los días como casillas: se eligen varios a la vez (HU-071 #1).
        List<CatalogoItem> dias = controller.GetCatalogo("DIA_SEMANA");

        chkDias.Items.Clear();

        if (dias != null)
            foreach (CatalogoItem d in dias)
                chkDias.Items.Add(new ListItem(d.nombre, d.id.ToString()));

        /* Día del mes: 1..31 más "último". El -1 es la convención del modelo
           y es lo que hace que febrero caiga 28 o 29 sin que nadie elija. */
        cboDiaMes.Items.Clear();
        cboDiaMes.Items.Add(new RadComboBoxItem("(no aplica)", ""));
        cboDiaMes.Items.Add(new RadComboBoxItem("Último día del mes", "-1"));

        for (int i = 1; i <= 31; i++)
            cboDiaMes.Items.Add(new RadComboBoxItem(i.ToString(), i.ToString()));

        cboOrdinal.Items.Clear();
        cboOrdinal.Items.Add(new RadComboBoxItem("(no aplica)", ""));
        cboOrdinal.Items.Add(new RadComboBoxItem("Primera", "1"));
        cboOrdinal.Items.Add(new RadComboBoxItem("Segunda", "2"));
        cboOrdinal.Items.Add(new RadComboBoxItem("Tercera", "3"));
        cboOrdinal.Items.Add(new RadComboBoxItem("Cuarta", "4"));
        cboOrdinal.Items.Add(new RadComboBoxItem("Última", "-1"));

        cboMes.Items.Clear();
        cboMes.Items.Add(new RadComboBoxItem("(elija)", ""));

        CultureInfo es = new CultureInfo("es-CL");

        for (int i = 1; i <= 12; i++)
            cboMes.Items.Add(new RadComboBoxItem(
                es.TextInfo.ToTitleCase(es.DateTimeFormat.GetMonthName(i)), i.ToString()));

        CargarMedidores();
        CargarVariables();
    }

    protected void CargarMedidores()
    {
        cboMedidor.Items.Clear();
        cboMedidor.Items.Add(new RadComboBoxItem("(elija)", ""));

        try
        {
            ActivoMedidorController controller = new ActivoMedidorController();
            List<ActivoMedidor> lista = controller.GetActivoMedidores(null);

            if (lista != null)
                foreach (ActivoMedidor m in lista)
                    cboMedidor.Items.Add(new RadComboBoxItem(
                        m.activo_nombre + " — " + m.ame_nombre, m.ame_id.ToString()));
        }
        catch (Exception)
        {
            /* Sin medidores el combo queda con "(elija)" y el SP rechaza el
               guardado con un mensaje claro. Reventar la ficha entera por un
               combo sería peor. */
        }
    }

    /// <summary>
    /// Las variables de condición son HU-041, del Sprint 2, y todavía está
    /// "Por hacer": hoy Activo_Variable no tiene filas. El combo se arma
    /// igual y avisa, en vez de aparecer vacío sin explicación.
    /// </summary>
    protected void CargarVariables()
    {
        cboVariable.Items.Clear();

        List<CatalogoItem> lista = null;

        try
        {
            System.Data.SqlClient.SqlCommand cmd = new System.Data.SqlClient.SqlCommand();
            cmd.CommandText = "SEL_ACTIVO_VARIABLE";
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());
            cmd.Parameters.AddWithValue("@HABILITADO", true);

            lista = new List<CatalogoItem>();

            using (System.Data.SqlClient.SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    CatalogoItem item = new CatalogoItem();
                    item.id = int.Parse(dr["ava_id"].ToString());
                    item.nombre = dr["ETIQUETA"].ToString();
                    lista.Add(item);
                }
            }

            cmd.Connection.Close();
            cmd.Dispose();
        }
        catch (Exception)
        {
            lista = null;
        }

        if (lista == null || lista.Count == 0)
        {
            cboVariable.Items.Add(new RadComboBoxItem(
                "(no hay variables definidas todavía)", ""));
            return;
        }

        cboVariable.Items.Add(new RadComboBoxItem("(elija)", ""));

        foreach (CatalogoItem v in lista)
            cboVariable.Items.Add(new RadComboBoxItem(v.nombre, v.id.ToString()));
    }

    private void Llenar(RadComboBox2 combo, List<CatalogoItem> items, bool conVacio)
    {
        combo.Items.Clear();

        if (conVacio) combo.Items.Add(new RadComboBoxItem("(sin definir)", ""));

        if (items == null) return;

        foreach (CatalogoItem i in items)
            combo.Items.Add(new RadComboBoxItem(i.nombre, i.id.ToString()));
    }

    #endregion

    #region Cargar

    protected void CargarDatos()
    {
        if (Id == 0)
        {
            lblId.Text = "Nuevo";
            calInicio.Value = DateTime.Today;
            txtIntervalo.Value = 1;
            txtToleranciaAntes.Value = 0;
            txtToleranciaDespues.Value = 0;
            chkPermiteAnticipada.Checked = true;
            chkPermiteAtrasada.Checked = true;
            txtHoraLocal.Text = "08:00";

            if (cboTipo.Items.Count > 0)
            {
                cboTipo.SelectedIndex = 0;
                TipoCodigo = CodigoTipoSeleccionado();
            }

            return;
        }

        ProgramacionController controller = new ProgramacionController();
        Programacion p = controller.GetProgramacion(Id);

        if (p == null || p.pro_id == 0)
        {
            /* No existe, o es de otro cliente y el SP no la devolvió. Se
               trata igual que un alta en vez de reventar. */
            Id = 0;
            lblId.Text = "Nuevo";
            return;
        }

        lblId.Text = p.pro_id.ToString();
        txtNombre.Text = p.pro_nombre;
        calInicio.Value = p.pro_fecha_inicio;
        calFin.Value = p.pro_fecha_fin;

        Seleccionar(cboTipo, p.pro_programacion_tipo.ToString());
        Seleccionar(cboZonaHoraria, p.pro_zona_horaria != null ? p.pro_zona_horaria.ToString() : "");
        Seleccionar(cboPolitica, p.pro_cumplimiento_politica != null ? p.pro_cumplimiento_politica.ToString() : "");

        TipoCodigo = p.tipo_codigo;

        txtToleranciaAntes.Value = p.pro_tolerancia_antes_minuto;
        txtToleranciaDespues.Value = p.pro_tolerancia_despues_minuto;
        chkPermiteAnticipada.Checked = p.pro_permite_anticipada;
        chkPermiteAtrasada.Checked = p.pro_permite_atrasada;

        rdbGeneraSi.Checked = p.pro_genera_automaticamente;
        rdbGeneraNo.Checked = !p.pro_genera_automaticamente;
        rdbSi.Checked = p.pro_habilitado;
        rdbNo.Checked = !p.pro_habilitado;

        // ---- El detalle de SU tipo ----
        if (p.calendario != null)
        {
            Seleccionar(cboFrecuencia, p.calendario.pca_frecuencia_tipo.ToString());
            txtIntervalo.Value = p.calendario.pca_intervalo;

            if (p.calendario.pca_hora_local != null)
                txtHoraLocal.Text = p.calendario.pca_hora_local.Value.ToString(@"hh\:mm");

            Seleccionar(cboDiaMes, p.calendario.pca_dia_mes != null ? p.calendario.pca_dia_mes.ToString() : "");
            Seleccionar(cboOrdinal, p.calendario.pca_semana_ordinal != null ? p.calendario.pca_semana_ordinal.ToString() : "");
            Seleccionar(cboMes, p.calendario.pca_mes != null ? p.calendario.pca_mes.ToString() : "");

            if (!string.IsNullOrEmpty(p.calendario.dias))
            {
                string[] dias = p.calendario.dias.Split(',');

                foreach (ListItem li in chkDias.Items)
                    li.Selected = Array.IndexOf(dias, li.Value) >= 0;
            }
        }

        if (p.intervalo != null)
        {
            txtCantidad.Value = p.intervalo.pin_cantidad;
            Seleccionar(cboUnidadTiempo, p.intervalo.pin_unidad_tiempo.ToString());
            calAncla.Value = p.intervalo.pin_fecha_ancla_utc;
            rdbDesdeEjecucion.Checked = p.intervalo.pin_desde_ejecucion;
            rdbDesdeProgramada.Checked = !p.intervalo.pin_desde_ejecucion;
        }

        if (p.medidor != null)
        {
            Seleccionar(cboMedidor, p.medidor.pme_activo_medidor.ToString());
            txtValorInicial.Value = (double)p.medidor.pme_valor_inicial;
            txtCadaCantidad.Value = (double)p.medidor.pme_cada_cantidad;

            if (p.medidor.pme_aviso_anticipacion != null)
                txtAviso.Value = (double)p.medidor.pme_aviso_anticipacion.Value;

            pnlMedidorEstado.Visible = true;
            litMedidorEstado.Text =
                "Lectura actual: <strong>" + p.medidor.medidor_valor_actual.ToString("N2") +
                "</strong>. El próximo disparo es en <strong>" +
                p.medidor.proximo_valor.ToString("N2") + "</strong>.";
        }

        if (p.fechas != null) BindFechas(p.fechas);
        if (p.condiciones != null) BindCondiciones(p.condiciones);
        if (p.lista_exclusiones != null) BindExclusiones(p.lista_exclusiones);

        wucAuditoria.Mostrar(p.usuario_creacion_nombre, p.pro_fecha_creacion,
                             p.usuario_actualizacion_nombre, p.pro_fecha_actualizacion);

        CargarProyeccion();
    }

    /// <summary>
    /// La vista previa. Medidor y condición no proyectan —dependen de una
    /// lectura que todavía no ocurrió— y ahí se dice en vez de mostrar una
    /// lista vacía que se lee como un error.
    /// </summary>
    protected void CargarProyeccion()
    {
        if (Id == 0) return;

        pnlProyeccion.Visible = true;

        if (TipoCodigo == "MEDIDOR" || TipoCodigo == "CONDICION")
        {
            litProyeccion.Text =
                "<div class=\"sigma-modal-note\"><i class=\"mdi mdi-information-outline\"></i><div>" +
                "Esta programación no tiene fechas por adelantado: dispara cuando la medición " +
                "llega al valor definido, no en el calendario.</div></div>";
            return;
        }

        ProgramacionController controller = new ProgramacionController();
        List<ProgramacionProyeccion> fechas = controller.GetProyeccion(Id, 12);

        if (fechas == null || fechas.Count == 0)
        {
            litProyeccion.Text =
                "<div class=\"sigma-modal-note\"><i class=\"mdi mdi-alert-outline\"></i><div>" +
                "Con la regla actual no se produce ninguna fecha. Revise la vigencia y los " +
                "datos de la regla.</div></div>";
            return;
        }

        System.Text.StringBuilder sb = new System.Text.StringBuilder();

        sb.Append("<div class=\"sigma-modal-grid\"><div class=\"sigma-modal-field is-ancho\">");
        sb.Append("<table class=\"table table-sm\" style=\"font-size:12px;\"><thead><tr>");
        sb.Append("<th style=\"width:20%;\">Fecha</th><th style=\"width:20%;\">Día</th>");
        sb.Append("<th>Observación</th></tr></thead><tbody>");

        CultureInfo es = new CultureInfo("es-CL");

        foreach (ProgramacionProyeccion f in fechas)
        {
            sb.Append("<tr><td><strong>");
            sb.Append(f.fecha.ToString("dd-MM-yyyy HH:mm"));
            sb.Append("</strong></td><td>");
            sb.Append(es.TextInfo.ToTitleCase(f.fecha.ToString("dddd", es)));
            sb.Append("</td><td>");

            if (f.desplazada && f.fecha_original != null)
            {
                sb.Append("<span class=\"grid-estado-chip is-alerta\">Desplazada</span> ");
                sb.Append("desde el " + f.fecha_original.Value.ToString("dd-MM-yyyy"));

                if (!string.IsNullOrEmpty(f.motivo))
                    sb.Append(" · " + Server.HtmlEncode(f.motivo));
            }
            else if (f.es_pasada)
            {
                sb.Append("<span style=\"color:#777;\">ya pasó</span>");
            }

            sb.Append("</td></tr>");
        }

        sb.Append("</tbody></table>");
        sb.Append("<span class=\"sigma-modal-ayuda\">Es un cálculo, no trabajo creado. ");
        sb.Append("Las órdenes las genera el plan de mantenimiento a partir de esta regla.</span>");
        sb.Append("</div></div>");

        litProyeccion.Text = sb.ToString();
    }

    private void Seleccionar(RadComboBox2 combo, string valor)
    {
        foreach (RadComboBoxItem i in combo.Items)
            i.Selected = (i.Value == (valor ?? ""));
    }

    private string CodigoTipoSeleccionado()
    {
        if (string.IsNullOrEmpty(cboTipo.SelectedValue)) return "";

        ProgramacionController controller = new ProgramacionController();
        List<CatalogoItem> tipos = controller.GetCatalogo("PROGRAMACION_TIPO");

        if (tipos == null) return "";

        foreach (CatalogoItem t in tipos)
            if (t.id.ToString() == cboTipo.SelectedValue) return t.codigo;

        return "";
    }

    #endregion

    #region Paneles y bloqueo

    /// <summary>
    /// Qué se ve según el tipo y según si la programación ya existe.
    /// </summary>
    protected void PintarPaneles()
    {
        bool existe = Id > 0;

        pnlFechaUnica.Visible = existe && TipoCodigo == "FECHA UNICA";
        pnlCalendario.Visible = TipoCodigo == "CALENDARIO";
        pnlIntervalo.Visible = TipoCodigo == "INTERVALO TIEMPO";
        pnlMedidor.Visible = TipoCodigo == "MEDIDOR";
        pnlCondicion.Visible = existe && TipoCodigo == "CONDICION";

        /* La política solo tiene sentido cuando hay varias condiciones que
           conciliar. En los otros tipos es un combo que no significa nada. */
        pnlPolitica.Visible = TipoCodigo == "CONDICION";

        pnlExclusiones.Visible = existe;
        pnlProyeccion.Visible = existe;

        /* Fecha única y condición son listas: necesitan el id de la cabecera
           para colgar sus filas. Calendario, intervalo y medidor se pueden
           llenar antes porque se guardan junto con el alta. */
        pnlGuardarPrimero.Visible = !existe &&
            (TipoCodigo == "FECHA UNICA" || TipoCodigo == "CONDICION");

        // Dentro de calendario, cada frecuencia pide cosas distintas.
        string frec = FrecuenciaCodigo();

        pnlDias.Visible = frec == "SEMANAL" || frec == "MENSUAL" || frec == "ANUAL";
        pnlDiaMes.Visible = frec == "MENSUAL" || frec == "ANUAL";
        pnlOrdinal.Visible = frec == "MENSUAL" || frec == "ANUAL";
        pnlMes.Visible = frec == "ANUAL";

        // El tipo no se cambia después de guardar: el detalle ya no calzaría.
        cboTipo.Enabled = !existe;
    }

    private string FrecuenciaCodigo()
    {
        if (cboFrecuencia.Items.Count == 0 || string.IsNullOrEmpty(cboFrecuencia.SelectedValue))
            return "";

        ProgramacionController controller = new ProgramacionController();
        List<CatalogoItem> lista = controller.GetCatalogo("FRECUENCIA_TIPO");

        if (lista == null) return "";

        foreach (CatalogoItem f in lista)
            if (f.id.ToString() == cboFrecuencia.SelectedValue) return f.codigo;

        return "";
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.PuedeFuncion("Crear y editar");

        txtNombre.ReadOnly = !puedeEditar;
        txtHoraLocal.ReadOnly = !puedeEditar;

        cboTipo.Enabled = cboTipo.Enabled && puedeEditar;
        cboZonaHoraria.Enabled = puedeEditar;
        cboFrecuencia.Enabled = puedeEditar;
        cboUnidadTiempo.Enabled = puedeEditar;
        cboPolitica.Enabled = puedeEditar;
        cboMedidor.Enabled = puedeEditar;
        cboVariable.Enabled = puedeEditar;
        cboOperador.Enabled = puedeEditar;
        cboSeveridad.Enabled = puedeEditar;
        cboDiaMes.Enabled = puedeEditar;
        cboOrdinal.Enabled = puedeEditar;
        cboMes.Enabled = puedeEditar;

        calInicio.Enabled = puedeEditar;
        calFin.Enabled = puedeEditar;
        calAncla.Enabled = puedeEditar;

        chkDias.Enabled = puedeEditar;
        chkPermiteAnticipada.Enabled = puedeEditar;
        chkPermiteAtrasada.Enabled = puedeEditar;

        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        rdbGeneraSi.Enabled = puedeEditar;
        rdbGeneraNo.Enabled = puedeEditar;
        rdbDesdeProgramada.Enabled = puedeEditar;
        rdbDesdeEjecucion.Enabled = puedeEditar;

        btnAgregarFecha.Visible = puedeEditar;
        btnAgregarCondicion.Visible = puedeEditar;
        btnAgregarExclusion.Visible = puedeEditar;

        if (!puedeEditar) btnGuardar.Visible = false;
    }

    protected void cboTipo_SelectedIndexChanged(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        TipoCodigo = CodigoTipoSeleccionado();
    }

    protected void cboFrecuencia_SelectedIndexChanged(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        // Solo redibuja: PintarPaneles() lo resuelve en el PreRender.
    }

    #endregion

    #region Guardar

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            /* SE VALIDA ACÁ, EN EL SERVIDOR.
               Esconder el botón en Bloqueo() no es seguridad: quien manda el
               postback a mano se lo salta. */
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para crear o editar programaciones.");

            if (string.IsNullOrEmpty(txtNombre.Text.Trim()))
                throw new Exception("Indique el nombre de la programación.");

            if (calInicio.Value == null)
                throw new Exception("Indique la fecha de inicio de vigencia.");

            if (string.IsNullOrEmpty(cboTipo.SelectedValue))
                throw new Exception("Indique el tipo de programación.");

            Programacion entidad = new Programacion();
            entidad.pro_id = Id;
            entidad.pro_nombre = txtNombre.Text.Trim();
            entidad.pro_programacion_tipo = int.Parse(cboTipo.SelectedValue);
            entidad.pro_fecha_inicio = calInicio.Value;
            entidad.pro_fecha_fin = calFin.Value;

            if (!string.IsNullOrEmpty(cboZonaHoraria.SelectedValue))
                entidad.pro_zona_horaria = int.Parse(cboZonaHoraria.SelectedValue);

            if (!string.IsNullOrEmpty(cboPolitica.SelectedValue))
                entidad.pro_cumplimiento_politica = int.Parse(cboPolitica.SelectedValue);

            entidad.pro_tolerancia_antes_minuto = Entero(txtToleranciaAntes.Value);
            entidad.pro_tolerancia_despues_minuto = Entero(txtToleranciaDespues.Value);
            entidad.pro_permite_anticipada = chkPermiteAnticipada.Checked;
            entidad.pro_permite_atrasada = chkPermiteAtrasada.Checked;
            entidad.pro_genera_automaticamente = rdbGeneraSi.Checked;
            entidad.pro_habilitado = rdbSi.Checked;

            ProgramacionController controller = new ProgramacionController();

            Respuesta respuesta = (Id > 0)
                                ? controller.UpdateProgramacion(entidad)
                                : controller.InsertProgramacion(entidad);

            if (respuesta.error)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                return;
            }

            Id = respuesta.codigo;

            /* El detalle se guarda DESPUÉS de la cabecera y solo el de su
               tipo. Si falla, se avisa pero la cabecera ya quedó: es mejor
               que perder también lo que sí se pudo guardar. */
            Respuesta detalle = GuardarDetalle(controller);

            if (detalle != null && detalle.error)
            {
                Tools.tools.ClientAlert(
                    "La programación se guardó, pero la regla no: " + detalle.detalle, "alerta");
                return;
            }

            CargarDatos();

            Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    private Respuesta GuardarDetalle(ProgramacionController controller)
    {
        switch (TipoCodigo)
        {
            case "CALENDARIO":
                {
                    if (string.IsNullOrEmpty(cboFrecuencia.SelectedValue))
                        throw new Exception("Indique la frecuencia.");

                    TimeSpan hora;

                    if (!TimeSpan.TryParse(txtHoraLocal.Text.Trim(), out hora))
                        throw new Exception("La hora debe tener el formato HH:MM.");

                    ProgramacionCalendario c = new ProgramacionCalendario();
                    c.pca_programacion = Id;
                    c.pca_frecuencia_tipo = int.Parse(cboFrecuencia.SelectedValue);
                    c.pca_intervalo = Math.Max(1, Entero(txtIntervalo.Value));
                    c.pca_hora_local = hora;

                    if (pnlDiaMes.Visible && !string.IsNullOrEmpty(cboDiaMes.SelectedValue))
                        c.pca_dia_mes = int.Parse(cboDiaMes.SelectedValue);

                    if (pnlOrdinal.Visible && !string.IsNullOrEmpty(cboOrdinal.SelectedValue))
                        c.pca_semana_ordinal = int.Parse(cboOrdinal.SelectedValue);

                    if (pnlMes.Visible && !string.IsNullOrEmpty(cboMes.SelectedValue))
                        c.pca_mes = int.Parse(cboMes.SelectedValue);

                    List<string> dias = new List<string>();

                    foreach (ListItem li in chkDias.Items)
                        if (li.Selected) dias.Add(li.Value);

                    c.dias = string.Join(",", dias.ToArray());

                    return controller.SaveCalendario(c);
                }

            case "INTERVALO TIEMPO":
                {
                    if (string.IsNullOrEmpty(cboUnidadTiempo.SelectedValue))
                        throw new Exception("Indique la unidad de tiempo.");

                    ProgramacionIntervalo i = new ProgramacionIntervalo();
                    i.pin_programacion = Id;
                    i.pin_unidad_tiempo = int.Parse(cboUnidadTiempo.SelectedValue);
                    i.pin_cantidad = Math.Max(1, Entero(txtCantidad.Value));
                    i.pin_fecha_ancla_utc = calAncla.Value;
                    i.pin_desde_ejecucion = rdbDesdeEjecucion.Checked;

                    return controller.SaveIntervalo(i);
                }

            case "MEDIDOR":
                {
                    if (string.IsNullOrEmpty(cboMedidor.SelectedValue))
                        throw new Exception("Indique el medidor.");

                    ProgramacionMedidor m = new ProgramacionMedidor();
                    m.pme_programacion = Id;
                    m.pme_activo_medidor = int.Parse(cboMedidor.SelectedValue);
                    m.pme_cada_cantidad = Decimal(txtCadaCantidad.Value);

                    if (txtValorInicial.Value != null)
                        m.pme_valor_inicial = Decimal(txtValorInicial.Value);

                    if (txtAviso.Value != null)
                        m.pme_aviso_anticipacion = Decimal(txtAviso.Value);

                    return controller.SaveMedidor(m);
                }
        }

        /* Fecha única y condición se guardan con sus propios botones: son
           listas y no un registro que viaje con la cabecera. */
        return null;
    }

    private int Entero(double? valor)
    {
        return valor == null ? 0 : (int)valor.Value;
    }

    private decimal Decimal(double? valor)
    {
        return valor == null ? 0m : (decimal)valor.Value;
    }

    #endregion

    #region Fechas puntuales (HU-070)

    protected void btnAgregarFecha_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para editar programaciones.");

            if (calNuevaFecha.Value == null)
                throw new Exception("Elija la fecha que quiere agregar.");

            ProgramacionFecha f = new ProgramacionFecha();
            f.pfe_programacion = Id;
            f.pfe_fecha = calNuevaFecha.Value.Value;
            f.pfe_incluida = true;

            ProgramacionController controller = new ProgramacionController();
            Respuesta respuesta = controller.InsertFecha(f);

            if (respuesta.error) { Tools.tools.ClientAlert(respuesta.detalle, "alerta"); return; }

            calNuevaFecha.Value = null;

            BindFechas(controller.GetFechas(Id));
            CargarProyeccion();

            Tools.tools.ClientAlert(respuesta.detalle, "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void BindFechas(List<ProgramacionFecha> lista)
    {
        if (grdFechas.Columns.Count == 0)
        {
            grdFechas.AddColumn("PFE_ID", "", Width: "5%");
            grdFechas.AddTemplateColumn("FECHA", "", "FECHA", Width: "45%");
            grdFechas.AddTemplateColumn("DIA", "", "DÍA", Width: "35%");
            grdFechas.AddTemplateColumn("ACCION", "", "", Width: "15%");
        }

        grdFechas.DataSource = lista;
        grdFechas.DataBind();
    }

    protected void grdFechas_ItemDataBound(object sender, GridItemEventArgs e)
    {
        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        ProgramacionFecha f = item.DataItem as ProgramacionFecha;

        if (f == null) return;

        CultureInfo es = new CultureInfo("es-CL");

        item["FECHA"].Text = f.pfe_fecha.ToString("dd-MM-yyyy");
        item["DIA"].Text = es.TextInfo.ToTitleCase(f.pfe_fecha.ToString("dddd", es));

        LinkButton quitar = new LinkButton();
        quitar.ID = "lnkQuitarFecha" + item.ItemIndex;
        quitar.CommandName = "QuitarFecha";
        quitar.CommandArgument = f.pfe_id.ToString();
        quitar.Text = "<i class=\"mdi mdi-trash-can-outline\"></i>";
        quitar.CssClass = "icono_Eliminar";
        quitar.OnClientClick = "return confirm('¿Quitar esta fecha?');";

        item["ACCION"].Controls.Add(quitar);
    }

    protected void grdFechas_ItemCommand(object sender, GridCommandEventArgs e)
    {
        if (e.CommandName != "QuitarFecha") return;

        try
        {
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para editar programaciones.");

            ProgramacionController controller = new ProgramacionController();
            Respuesta respuesta = controller.DeleteFecha(int.Parse(e.CommandArgument.ToString()));

            if (respuesta.error) { Tools.tools.ClientAlert(respuesta.detalle, "alerta"); return; }

            BindFechas(controller.GetFechas(Id));
            CargarProyeccion();

            Tools.tools.ClientAlert(respuesta.detalle, "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #endregion

    #region Condiciones (HU-074)

    protected void btnAgregarCondicion_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para editar programaciones.");

            if (string.IsNullOrEmpty(cboVariable.SelectedValue))
                throw new Exception("Elija la variable. Si el combo está vacío, todavía no hay variables de condición definidas.");

            if (string.IsNullOrEmpty(cboOperador.SelectedValue))
                throw new Exception("Elija el operador de comparación.");

            if (string.IsNullOrEmpty(cboSeveridad.SelectedValue))
                throw new Exception("Elija la severidad.");

            ProgramacionCondicion c = new ProgramacionCondicion();
            c.pco_programacion = Id;
            c.pco_activo_variable = int.Parse(cboVariable.SelectedValue);
            c.pco_operador_comparacion = int.Parse(cboOperador.SelectedValue);
            c.pco_umbral = Decimal(txtUmbral.Value);
            c.pco_severidad = int.Parse(cboSeveridad.SelectedValue);

            if (txtUmbralHasta.Value != null)
                c.pco_umbral_hasta = Decimal(txtUmbralHasta.Value);

            if (txtDuracionMinima.Value != null)
                c.pco_duracion_minima_minuto = Entero(txtDuracionMinima.Value);

            ProgramacionController controller = new ProgramacionController();
            Respuesta respuesta = controller.InsertCondicion(c);

            if (respuesta.error) { Tools.tools.ClientAlert(respuesta.detalle, "alerta"); return; }

            BindCondiciones(controller.GetCondiciones(Id));

            Tools.tools.ClientAlert(respuesta.detalle, "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void BindCondiciones(List<ProgramacionCondicion> lista)
    {
        if (grdCondiciones.Columns.Count == 0)
        {
            grdCondiciones.AddColumn("PCO_ID", "", Width: "5%");
            grdCondiciones.AddTemplateColumn("EQUIPO", "", "EQUIPO", Width: "30%");
            grdCondiciones.AddTemplateColumn("REGLA", "", "REGLA", Width: "40%");
            grdCondiciones.AddTemplateColumn("SEVERIDAD", "", "SEVERIDAD", Width: "15%");
            grdCondiciones.AddTemplateColumn("ACCION", "", "", Width: "10%");
        }

        grdCondiciones.DataSource = lista;
        grdCondiciones.DataBind();
    }

    protected void grdCondiciones_ItemDataBound(object sender, GridItemEventArgs e)
    {
        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        ProgramacionCondicion c = item.DataItem as ProgramacionCondicion;

        if (c == null) return;

        item["EQUIPO"].Text = Server.HtmlEncode(c.activo_nombre ?? "");
        item["REGLA"].Text = Server.HtmlEncode(c.regla ?? "");
        item["SEVERIDAD"].Text = Server.HtmlEncode(c.severidad_nombre ?? "");

        LinkButton quitar = new LinkButton();
        quitar.ID = "lnkQuitarCondicion" + item.ItemIndex;
        quitar.CommandName = "QuitarCondicion";
        quitar.CommandArgument = c.pco_id.ToString();
        quitar.Text = "<i class=\"mdi mdi-trash-can-outline\"></i>";
        quitar.CssClass = "icono_Eliminar";
        quitar.OnClientClick = "return confirm('¿Quitar esta condición?');";

        item["ACCION"].Controls.Add(quitar);
    }

    protected void grdCondiciones_ItemCommand(object sender, GridCommandEventArgs e)
    {
        if (e.CommandName != "QuitarCondicion") return;

        try
        {
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para editar programaciones.");

            ProgramacionController controller = new ProgramacionController();
            Respuesta respuesta = controller.DeleteCondicion(int.Parse(e.CommandArgument.ToString()));

            if (respuesta.error) { Tools.tools.ClientAlert(respuesta.detalle, "alerta"); return; }

            BindCondiciones(controller.GetCondiciones(Id));

            Tools.tools.ClientAlert(respuesta.detalle, "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #endregion

    #region Exclusiones (HU-075)

    protected void btnAgregarExclusion_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para editar programaciones.");

            if (calExclusionDesde.Value == null || calExclusionHasta.Value == null)
                throw new Exception("Indique el período completo de la exclusión.");

            if (string.IsNullOrEmpty(txtExclusionMotivo.Text.Trim()))
                throw new Exception("Indique el motivo de la exclusión.");

            ProgramacionExclusion x = new ProgramacionExclusion();
            x.pxc_programacion = Id;
            x.pxc_fecha_inicio_utc = calExclusionDesde.Value.Value.Date;

            /* Hasta el final del día: una exclusión "del 5 al 16" que
               terminara a las 00:00 del 16 dejaría fuera ese día entero. */
            x.pxc_fecha_fin_utc = calExclusionHasta.Value.Value.Date.AddDays(1).AddMinutes(-1);
            x.pxc_motivo = txtExclusionMotivo.Text.Trim();
            x.pxc_desplaza = rdbDesplaza.Checked;

            ProgramacionController controller = new ProgramacionController();
            Respuesta respuesta = controller.InsertExclusion(x);

            if (respuesta.error) { Tools.tools.ClientAlert(respuesta.detalle, "alerta"); return; }

            calExclusionDesde.Value = null;
            calExclusionHasta.Value = null;
            txtExclusionMotivo.Text = "";

            BindExclusiones(controller.GetExclusiones(Id));
            CargarProyeccion();

            Tools.tools.ClientAlert(respuesta.detalle, "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void BindExclusiones(List<ProgramacionExclusion> lista)
    {
        if (grdExclusiones.Columns.Count == 0)
        {
            grdExclusiones.AddColumn("PXC_ID", "", Width: "5%");
            grdExclusiones.AddTemplateColumn("PERIODO", "", "PERÍODO", Width: "30%");
            grdExclusiones.AddTemplateColumn("MOTIVO", "", "MOTIVO", Width: "30%");
            grdExclusiones.AddTemplateColumn("EFECTO", "", "EFECTO", Width: "25%");
            grdExclusiones.AddTemplateColumn("ACCION", "", "", Width: "10%");
        }

        grdExclusiones.DataSource = lista;
        grdExclusiones.DataBind();
    }

    protected void grdExclusiones_ItemDataBound(object sender, GridItemEventArgs e)
    {
        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        ProgramacionExclusion x = item.DataItem as ProgramacionExclusion;

        if (x == null) return;

        item["PERIODO"].Text = x.pxc_fecha_inicio_utc.ToString("dd-MM-yyyy") + " al " +
                               x.pxc_fecha_fin_utc.ToString("dd-MM-yyyy") +
                               "<br /><span style=\"color:#777;font-size:11px;\">" +
                               x.dias + (x.dias == 1 ? " día" : " días") + "</span>";

        item["MOTIVO"].Text = Server.HtmlEncode(x.pxc_motivo ?? "");

        item["EFECTO"].Text = x.pxc_desplaza
            ? "<span class=\"grid-estado-chip is-info\">Desplaza</span>"
            : "<span class=\"grid-estado-chip is-alerta\">No genera</span>";

        LinkButton quitar = new LinkButton();
        quitar.ID = "lnkQuitarExclusion" + item.ItemIndex;
        quitar.CommandName = "QuitarExclusion";
        quitar.CommandArgument = x.pxc_id.ToString();
        quitar.Text = "<i class=\"mdi mdi-trash-can-outline\"></i>";
        quitar.CssClass = "icono_Eliminar";
        quitar.OnClientClick = "return confirm('¿Quitar esta exclusión?');";

        item["ACCION"].Controls.Add(quitar);
    }

    protected void grdExclusiones_ItemCommand(object sender, GridCommandEventArgs e)
    {
        if (e.CommandName != "QuitarExclusion") return;

        try
        {
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para editar programaciones.");

            ProgramacionController controller = new ProgramacionController();
            Respuesta respuesta = controller.DeleteExclusion(int.Parse(e.CommandArgument.ToString()));

            if (respuesta.error) { Tools.tools.ClientAlert(respuesta.detalle, "alerta"); return; }

            BindExclusiones(controller.GetExclusiones(Id));
            CargarProyeccion();

            Tools.tools.ClientAlert(respuesta.detalle, "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #endregion
}
