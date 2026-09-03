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
        LeerEstadoDelCliente();
        PintarPaneles();

        /* El stepper y el resumen se pintan DESPUÉS de los paneles: los dos
           leen el estado ya resuelto del formulario, y hacerlo antes los
           dejaría mostrando lo de la petición anterior. */
        PintarPasos();
        PintarChips();
        PintarResumen();

        Bloqueo();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    #region Combos

    protected void CargarCombos()
    {
        CargarHoras();
        CargarHoras(cboNuevaHora);
        CargarAlcance();

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
            Seleccionar(cboHora, "08:00");

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

        /* ---- Alcance ----

           La instalación primero y las dependientes después: las áreas y los
           activos que se cargan son los de ESA instalación, así que pedirlos
           antes traería la lista de otra planta —o ninguna. */
        Seleccionar(cboInstalacion, p.pro_cliente_instalacion != null
            ? p.pro_cliente_instalacion.ToString() : "");

        CargarDependientes();

        Seleccionar(cboArea, p.pro_instalacion_area != null ? p.pro_instalacion_area.ToString() : "");
        Seleccionar(cboActivo, p.pro_activo != null ? p.pro_activo.ToString() : "");

        /* ---- Asignación ----

           El modo sale del dato, no de un valor por omisión: si la
           programación tenía un grupo, se abre en "grupo". */
        if (!string.IsNullOrEmpty(p.RESPONSABLES_IDS))
        {
            ModoAsignacion = "persona";
            MarcarResponsables(p.RESPONSABLES_IDS);
        }
        else if (p.pro_grupo_trabajo != null)
        {
            ModoAsignacion = "grupo";
            Seleccionar(cboGrupo, p.pro_grupo_trabajo.ToString());
        }
        else
            ModoAsignacion = "nadie";

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
                SeleccionarHora(p.calendario.pca_hora_local.Value);

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

        /* Se ESCONDEN, no se quitan.

           Un control con Visible=false no llega al HTML, y entonces el
           navegador no tiene qué mostrar cuando la persona cambia de
           frecuencia: el campo simplemente no aparecería hasta recargar. */
        Esconder(pnlDias, !AplicaCampo("DIAS"));
        Esconder(pnlDiaMes, !AplicaCampo("DIAMES"));
        Esconder(pnlOrdinal, !AplicaCampo("ORDINAL"));
        Esconder(pnlMes, !AplicaCampo("MES"));

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
        cboHora.Enabled = puedeEditar;

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

            /* ---- Alcance ----

               Un área o un activo sin instalación dejan un alcance que nadie
               sabe leer, y la base lo rechaza con CK_PRO_ALCANCE_JERARQUIA.
               Se avisa acá para que el mensaje diga qué falta y no un error
               de constraint. */
            if (!string.IsNullOrEmpty(cboInstalacion.SelectedValue))
            {
                entidad.pro_cliente_instalacion = int.Parse(cboInstalacion.SelectedValue);

                if (!string.IsNullOrEmpty(cboArea.SelectedValue))
                    entidad.pro_instalacion_area = int.Parse(cboArea.SelectedValue);

                if (!string.IsNullOrEmpty(cboActivo.SelectedValue))
                    entidad.pro_activo = int.Parse(cboActivo.SelectedValue);
            }
            else if (!string.IsNullOrEmpty(cboArea.SelectedValue) ||
                     !string.IsNullOrEmpty(cboActivo.SelectedValue))
            {
                throw new Exception("Alcance: indique la instalación antes del área o del activo.");
            }

            /* ---- Asignación ----

               Solo se manda la del modo elegido. Mandar las dos hace que la
               base rechace la fila entera, y con razón: persona y grupo a la
               vez es como no asignar a nadie. */
            /* Las personas NO viajan en la cabecera: son varias y viven en su
               propia tabla. Se guardan después de tener el id, más abajo. */
            if (ModoAsignacion == "grupo" && !string.IsNullOrEmpty(cboGrupo.SelectedValue))
                entidad.pro_grupo_trabajo = int.Parse(cboGrupo.SelectedValue);

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

            /* Los responsables se guardan DESPUÉS de la cabecera porque
               necesitan el id: en un alta, hasta acá no existía. Van a su
               propia tabla —son varias personas— y el SP valida que no haya
               personas y grupo a la vez. */
            if (ModoAsignacion == "persona")
            {
                Respuesta rp = controller.GuardarResponsables(Id, ResponsablesMarcados());

                if (rp.error)
                {
                    Tools.tools.ClientAlert(
                        "La programación se guardó, pero los responsables no: " + rp.detalle, "alerta");
                    return;
                }
            }
            else
            {
                /* Con grupo o sin asignar, la lista de personas queda vacía:
                   dejarla cargada haría que la programación tuviera dos
                   responsables distintos según dónde se mire. */
                controller.GuardarResponsables(Id, "");
            }

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

            /* Los combos se vuelven a llenar, no solo los datos.

               CargarCombos() corría únicamente en el primer GET. Al volver de
               un guardado, los ítems del combo se restauran desde el
               ViewState pero SUS ATRIBUTOS NO —la foto, las iniciales, el
               nombre corto— y los chips se dibujan justamente con eso: se
               quedaban sin nada que mostrar. Rellenarlos acá los devuelve
               completos, y CargarDatos() vuelve a marcar los que quedaron
               guardados leyéndolos de la base. */
            CargarCombos();
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

                    /* Antes esto era un texto libre con TimeSpan.TryParse, que
                       convierte "8" en OCHO DÍAS: aceptaba un valor imposible
                       como hora del día y lo guardaba. Ahora la hora sale de
                       una lista, así que lo único que queda por comprobar es
                       que se haya elegido una. */
                    if (!TimeSpan.TryParse(cboHora.SelectedValue, out hora) ||
                        hora < TimeSpan.Zero || hora >= TimeSpan.FromDays(1))
                        throw new Exception("Seleccione la hora de ejecución.");

                    ProgramacionCalendario c = new ProgramacionCalendario();
                    c.pca_programacion = Id;
                    c.pca_frecuencia_tipo = int.Parse(cboFrecuencia.SelectedValue);
                    c.pca_intervalo = Math.Max(1, Entero(txtIntervalo.Value));
                    c.pca_hora_local = hora;

                    if (AplicaCampo("DIAMES") && !string.IsNullOrEmpty(cboDiaMes.SelectedValue))
                        c.pca_dia_mes = int.Parse(cboDiaMes.SelectedValue);

                    if (AplicaCampo("ORDINAL") && !string.IsNullOrEmpty(cboOrdinal.SelectedValue))
                        c.pca_semana_ordinal = int.Parse(cboOrdinal.SelectedValue);

                    if (AplicaCampo("MES") && !string.IsNullOrEmpty(cboMes.SelectedValue))
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
        /* La tabla que se ve es el Repeater; la grilla sigue viva y oculta.
           Se llenan las dos desde el mismo punto para que no puedan quedar
           diciendo cosas distintas. */
        BindExclusionesRepeater(lista);

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

    #region Pasos, chips y resumen

    /// <summary>
    /// En qué paso está. Vive en ViewState y no en el cliente porque el
    /// servidor es quien sabe si un paso quedó completo: un stepper pintado
    /// solo con JavaScript no puede saber que al paso 4 le falta la hora.
    /// </summary>
    protected int Paso
    {
        get { return ViewState["Paso"] != null ? (int)ViewState["Paso"] : 1; }
        set { ViewState["Paso"] = value < 1 ? 1 : (value > 6 ? 6 : value); }
    }

    /// <summary>persona | grupo | nadie.</summary>
    protected string ModoAsignacion
    {
        get { return ViewState["ModoAsig"] != null ? (string)ViewState["ModoAsig"] : "nadie"; }
        set { ViewState["ModoAsig"] = value; }
    }

    /// <summary>Una casilla del stepper. Pública: Eval() no ve tipos internos.</summary>
    public class PasoItem
    {
        public int Numero { get; set; }
        public string Titulo { get; set; }
        public string Ayuda { get; set; }
        public string Clase { get; set; }
        public string Bolita { get; set; }
    }

    /// <summary>Un chip de día o de frecuencia.</summary>
    public class ChipItem
    {
        public string Valor { get; set; }
        public string Texto { get; set; }
        public string Clase { get; set; }
        public string Marcado { get; set; }
        public string Id { get; set; }
        public string Nombre { get; set; }
    }

    /// <summary>Una fila de la tabla de exclusiones.</summary>
    public class ExclusionFila
    {
        public int Id { get; set; }
        public string Desde { get; set; }
        public string Hasta { get; set; }
        public string Motivo { get; set; }
        public string Efecto { get; set; }
        public string EfectoClase { get; set; }
    }

    private static readonly string[] TITULOS_PASO = {
        "Información general", "Alcance", "Asignación",
        "Frecuencia", "Exclusiones", "Revisar"
    };

    /// <summary>
    /// Qué le falta a cada paso. Devuelve vacío si está completo.
    ///
    /// Es lo que permite que el error diga QUÉ SECCIÓN hay que corregir en
    /// vez de un "faltan datos" que obliga a recorrer las seis.
    /// </summary>
    protected string FaltaEnPaso(int numero)
    {
        switch (numero)
        {
            case 1:
                if (string.IsNullOrEmpty(txtNombre.Text.Trim())) return "Falta el nombre.";
                if (string.IsNullOrEmpty(cboTipo.SelectedValue)) return "Falta el tipo.";
                if (calInicio.Value == null) return "Falta la fecha de inicio.";

                if (calFin.Value != null && calInicio.Value != null &&
                    calFin.Value.Value < calInicio.Value.Value)
                    return "El término es anterior al inicio.";

                return "";

            case 2:
                /* El alcance es opcional: una programación puede aplicar a
                   toda la empresa. Lo que no se acepta es a medias. */
                if (string.IsNullOrEmpty(cboInstalacion.SelectedValue) &&
                    (!string.IsNullOrEmpty(cboArea.SelectedValue) ||
                     !string.IsNullOrEmpty(cboActivo.SelectedValue)))
                    return "Indique la instalación.";

                return "";

            case 3:
                if (ModoAsignacion == "persona" && ResponsablesMarcados() == "")
                    return "Elija al menos una persona.";

                if (ModoAsignacion == "grupo" && string.IsNullOrEmpty(cboGrupo.SelectedValue))
                    return "Falta el grupo de trabajo.";

                return "";

            case 4:
                if (TipoCodigo == "CALENDARIO")
                {
                    if (string.IsNullOrEmpty(cboFrecuencia.SelectedValue)) return "Falta la frecuencia.";
                    if (string.IsNullOrEmpty(cboHora.SelectedValue)) return "Falta la hora.";

                    string f = FrecuenciaCodigo();

                    if (f == "SEMANAL" && DiasMarcados().Count == 0)
                        return "Elija al menos un día.";
                }

                if (TipoCodigo == "INTERVALO TIEMPO")
                {
                    if (txtCantidad.Value == null || txtCantidad.Value <= 0) return "Falta el intervalo.";
                    if (string.IsNullOrEmpty(cboUnidadTiempo.SelectedValue)) return "Falta la unidad.";
                }

                if (TipoCodigo == "MEDIDOR")
                {
                    if (string.IsNullOrEmpty(cboMedidor.SelectedValue)) return "Falta el medidor.";
                    if (txtCadaCantidad.Value == null || txtCadaCantidad.Value <= 0) return "Falta cada cuánto.";
                }

                return "";
        }

        return "";
    }

    protected void PintarPasos()
    {
        List<PasoItem> lista = new List<PasoItem>();

        for (int n = 1; n <= 6; n++)
        {
            PasoItem it = new PasoItem();
            it.Numero = n;
            it.Titulo = TITULOS_PASO[n - 1];

            string falta = FaltaEnPaso(n);
            bool actual = (n == Paso);

            /* Un paso se marca completo solo si YA SE PASÓ POR ÉL. Poner el
               visto en el paso 5 cuando nadie lo ha abierto diría que está
               revisado, y no lo está: está vacío. */
            bool visitado = n < Paso;

            it.Clase = "sg-paso" + (actual ? " is-activo" : "") +
                       (visitado && falta == "" ? " is-listo" : "") +
                       (falta != "" && (visitado || actual) ? " is-pendiente" : "");

            it.Bolita = (visitado && falta == "") ? "✓" : n.ToString();
            it.Ayuda = falta != "" ? falta : it.Titulo;

            lista.Add(it);
        }

        rptPasos.DataSource = lista;
        rptPasos.DataBind();

        pnlPaso1.CssClass = "sg-paso-panel" + (Paso == 1 ? " is-activo" : "");
        pnlPaso2.CssClass = "sg-paso-panel" + (Paso == 2 ? " is-activo" : "");
        pnlPaso3.CssClass = "sg-paso-panel" + (Paso == 3 ? " is-activo" : "");
        pnlPaso4.CssClass = "sg-paso-panel" + (Paso == 4 ? " is-activo" : "");
        pnlPaso5.CssClass = "sg-paso-panel" + (Paso == 5 ? " is-activo" : "");
        pnlPaso6.CssClass = "sg-paso-panel" + (Paso == 6 ? " is-activo" : "");

        /* Los botones se ESCONDEN CON CSS y no con Visible: el JS los
           necesita en el DOM para poder mostrarlos de nuevo sin postback. */
        btnAnterior.Style["visibility"] = Paso > 1 ? "visible" : "hidden";
        btnSiguiente.Style["visibility"] = Paso < 6 ? "visible" : "hidden";

        /* Que el navegador arranque donde está el servidor. */
        hfPaso.Value = Paso.ToString();
        hfModo.Value = ModoAsignacion;
        hfFrecuencia.Value = cboFrecuencia.SelectedValue ?? "";

        litModo.Text = Id > 0 ? "Editar programación" : "Nueva programación";
        litTitulo.Text = string.IsNullOrEmpty(txtNombre.Text.Trim())
            ? "Programación" : Server.HtmlEncode(txtNombre.Text.Trim());

        lblId.Visible = Id > 0;
        litEstado.Text = Id > 0
            ? (rdbSi.Checked
               ? "<span class=\"sg-etiqueta is-ok\">Habilitada</span>"
               : "<span class=\"sg-etiqueta is-off\">Deshabilitada</span>")
            : "";

        // Los pasos 2 y 3 dependen de columnas que solo existen desde el bloque 118.
        /* Mismo motivo: si no se renderizan, elegir "Una persona" no puede
           hacer aparecer el combo sin volver al servidor. */
        Esconder(pnlPersona, ModoAsignacion != "persona");
        Esconder(pnlGrupo, ModoAsignacion != "grupo");

        btnModoPersona.CssClass = "sg-opcion" + (ModoAsignacion == "persona" ? " is-elegida" : "");
        btnModoGrupo.CssClass = "sg-opcion" + (ModoAsignacion == "grupo" ? " is-elegida" : "");
        btnModoNadie.CssClass = "sg-opcion" + (ModoAsignacion == "nadie" ? " is-elegida" : "");

        pnlExclusionesBloqueadas.Visible = Id <= 0;
    }

    /// <summary>
    /// Trae lo que el navegador dejó en los campos ocultos.
    ///
    /// La navegación entre pasos, el modo de asignación y la frecuencia se
    /// mueven sin postback, así que en un guardado el ViewState del servidor
    /// está desactualizado respecto de lo que la persona ve. Estos tres
    /// campos son el puente; sin leerlos, guardar devolvería la ficha en el
    /// paso 1 y con la frecuencia anterior.
    /// </summary>
    protected void LeerEstadoDelCliente()
    {
        /* SOLO EN POSTBACK.

           Estos tres campos son lo que el NAVEGADOR movió sin volver al
           servidor. En la primera carga todavía no movió nada: traen el valor
           por omisión del markup, y "nadie" pisaba el "persona" que
           CargarDatos() acababa de deducir de la base.

           El síntoma era exacto: una programación con gente asignada abría en
           "Sin asignar", y recién al hacer clic en Personas aparecían los
           responsables. En la primera carga manda el servidor; desde el
           primer postback en adelante, manda el navegador. */
        if (!IsPostBack) return;

        int n;
        if (int.TryParse(hfPaso.Value, out n) && n >= 1 && n <= 6) Paso = n;

        string modo = (hfModo.Value ?? "").Trim();
        if (modo == "persona" || modo == "grupo" || modo == "nadie") ModoAsignacion = modo;

        /* La frecuencia manda sobre el combo: es lo que la persona tocó. */
        if (!string.IsNullOrEmpty(hfFrecuencia.Value) &&
            hfFrecuencia.Value != cboFrecuencia.SelectedValue)
            Seleccionar(cboFrecuencia, hfFrecuencia.Value);
    }

    /// <summary>
    /// Esconde sin sacar del HTML.
    ///
    /// Visible=false no renderiza: el control desaparece del DOM y además
    /// deja de postear su valor. Para todo lo que el navegador tiene que
    /// poder mostrar u ocultar por su cuenta, la diferencia importa.
    /// </summary>
    private static void Esconder(System.Web.UI.WebControls.WebControl panel, bool esconder)
    {
        panel.Visible = true;
        panel.Style["display"] = esconder ? "none" : "";
    }

    /// <summary>
    /// Si la frecuencia elegida usa ese campo.
    ///
    /// Es la REGLA, no la pantalla. Antes el guardado preguntaba si el div
    /// se veía, y eso solo funcionaba mientras esconder significara no
    /// renderizar.
    /// </summary>
    protected bool AplicaCampo(string campo)
    {
        string f = FrecuenciaCodigo();

        switch (campo)
        {
            case "DIAS":    return f == "SEMANAL" || f == "MENSUAL" || f == "ANUAL";
            case "DIAMES":  return f == "MENSUAL" || f == "ANUAL";
            case "ORDINAL": return f == "MENSUAL" || f == "ANUAL";
            case "MES":     return f == "ANUAL";
        }

        return false;
    }

    /// <summary>
    /// El id de la programación, cifrado, para que el JS se lo devuelva al
    /// web service.
    ///
    /// Cifrado y no en claro por lo mismo que los querystring del sitio: un
    /// id de fila a la vista dentro de un POST invita a probar el de al lado.
    /// El servicio igual comprueba que la fila sea del cliente de la sesión,
    /// pero eso es la segunda barrera, no la primera.
    /// </summary>
    protected string IdCifrado()
    {
        return Id > 0 ? Tools.Crypto.Encrypt("Id=" + Id) : "";
    }

    protected void rptPasos_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "ir") return;

        int n;
        if (int.TryParse(e.CommandArgument.ToString(), out n)) Paso = n;
    }

    protected void btnAnterior_Click(object sender, EventArgs e) { Paso = Paso - 1; }
    protected void btnSiguiente_Click(object sender, EventArgs e) { Paso = Paso + 1; }
    protected void btnRevisar_Click(object sender, EventArgs e) { Paso = 6; }

    #endregion

    #region Chips

    /// <summary>Los días marcados, por valor.</summary>
    protected List<string> DiasMarcados()
    {
        List<string> l = new List<string>();

        foreach (ListItem it in chkDias.Items)
            if (it.Selected) l.Add(it.Value);

        return l;
    }

    protected void PintarChips()
    {
        // ---- frecuencia ----
        List<ChipItem> fs = new List<ChipItem>();

        foreach (RadComboBoxItem it in cboFrecuencia.Items)
        {
            if (string.IsNullOrEmpty(it.Value)) continue;

            ChipItem c = new ChipItem();
            c.Id = it.Value;
            c.Nombre = it.Text;
            c.Clase = "sg-seg" + (it.Value == cboFrecuencia.SelectedValue ? " is-activa" : "");
            fs.Add(c);
        }

        rptFrecuencias.DataSource = fs;
        rptFrecuencias.DataBind();

        // ---- días ----
        List<ChipItem> ds = new List<ChipItem>();

        foreach (ListItem it in chkDias.Items)
        {
            ChipItem c = new ChipItem();
            c.Valor = it.Value;

            /* Tres letras: "Lun" se reconoce de un vistazo y "Lunes" hace
               que siete chips no quepan en una línea. */
            c.Texto = it.Text.Length > 3 ? it.Text.Substring(0, 3) : it.Text;
            c.Marcado = it.Selected ? "true" : "false";
            c.Clase = "sg-chip" + (it.Selected ? " is-marcado" : "");
            ds.Add(c);
        }

        rptDias.DataSource = ds;
        rptDias.DataBind();

        string frec = FrecuenciaCodigo();

        litUnidadFrecuencia.Text =
            frec == "DIARIA" ? "día(s)" :
            frec == "SEMANAL" ? "semana(s)" :
            frec == "MENSUAL" ? "mes(es)" :
            frec == "ANUAL" ? "año(s)" : "";

        /* Cuando los días no aplican se dice, en vez de dejar siete chips
           que no hacen nada y parecen rotos. */
        litDiasAyuda.Text = (frec == "MENSUAL" || frec == "ANUAL")
            ? "<span class=\"sg-ayuda\">Opcional: combinado con la semana del mes.</span>"
            : "";

        Esconder(pnlDias, !AplicaCampo("DIAS"));

        litReglaFrase.Text = Server.HtmlEncode(FraseRecurrencia());
    }

    protected void rptFrecuencias_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "frec") return;

        Seleccionar(cboFrecuencia, e.CommandArgument.ToString());

        /* Se llama al mismo manejador del combo y no se duplica su cuerpo:
           el chip es otra forma de tocar el combo, no otra regla. */
        cboFrecuencia_SelectedIndexChanged(cboFrecuencia, null);
    }

    protected void rptDias_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "dia") return;

        string valor = e.CommandArgument.ToString();

        foreach (ListItem it in chkDias.Items)
            if (it.Value == valor) it.Selected = !it.Selected;
    }

    /// <summary>
    /// La recurrencia en una frase legible: "Todos los lunes y miércoles a
    /// las 09:00, excepto feriados".
    ///
    /// Se arma con lo que hay cargado. Si falta un dato, se omite esa parte
    /// en vez de inventarla: media frase verdadera es útil, una frase
    /// completa a medias inventar no lo es.
    /// </summary>
    protected string FraseRecurrencia()
    {
        string tipo = TipoCodigo;

        if (tipo == "FECHA UNICA") return "En las fechas indicadas.";

        if (tipo == "INTERVALO TIEMPO")
        {
            if (txtCantidad.Value == null || string.IsNullOrEmpty(cboUnidadTiempo.SelectedValue))
                return "";

            return "Cada " + ((int)txtCantidad.Value.Value) + " " +
                   cboUnidadTiempo.Text.ToLower() + ".";
        }

        if (tipo == "MEDIDOR")
        {
            if (txtCadaCantidad.Value == null) return "";
            return "Cada " + txtCadaCantidad.Value.Value.ToString("0.##") +
                   " de " + cboMedidor.Text + ".";
        }

        if (tipo == "CONDICION") return "Cuando se cumplan las condiciones definidas.";

        if (tipo != "CALENDARIO") return "";

        string frec = FrecuenciaCodigo();
        if (frec == "") return "";

        int cada = txtIntervalo.Value != null ? (int)txtIntervalo.Value.Value : 1;
        if (cada < 1) cada = 1;

        StringBuilder b = new StringBuilder();

        if (frec == "DIARIA")
            b.Append(cada == 1 ? "Todos los días" : "Cada " + cada + " días");

        else if (frec == "SEMANAL")
        {
            List<string> nombres = new List<string>();

            foreach (ListItem it in chkDias.Items)
                if (it.Selected) nombres.Add(it.Text.ToLower());

            if (nombres.Count == 0) return "";

            b.Append(cada == 1 ? "Todos los " : "Cada " + cada + " semanas los ");
            b.Append(Unir(nombres));
        }

        else if (frec == "MENSUAL")
        {
            b.Append(cada == 1 ? "Cada mes" : "Cada " + cada + " meses");

            if (!string.IsNullOrEmpty(cboDiaMes.SelectedValue))
                b.Append(", el " + cboDiaMes.Text.ToLower());
        }

        else if (frec == "ANUAL")
        {
            b.Append(cada == 1 ? "Cada año" : "Cada " + cada + " años");

            if (!string.IsNullOrEmpty(cboMes.SelectedValue))
                b.Append(", en " + cboMes.Text.ToLower());

            if (!string.IsNullOrEmpty(cboDiaMes.SelectedValue))
                b.Append(" el " + cboDiaMes.Text.ToLower());
        }

        if (!string.IsNullOrEmpty(cboHora.SelectedValue))
            b.Append(" a las " + cboHora.SelectedValue);

        /* Las exclusiones solo se nombran si de verdad existen: decir
           "excepto feriados" sin ninguna cargada sería una promesa falsa. */
        if (_exclusiones > 0)
            b.Append(", excepto " + _exclusiones +
                     (_exclusiones == 1 ? " período excluido" : " períodos excluidos"));

        b.Append('.');
        return b.ToString();
    }

    private static string Unir(List<string> l)
    {
        if (l.Count == 0) return "";
        if (l.Count == 1) return l[0];

        return string.Join(", ", l.GetRange(0, l.Count - 1).ToArray()) + " y " + l[l.Count - 1];
    }

    #endregion

    #region Horas y alcance

    /// <summary>
    /// La lista de horas, cada 15 minutos.
    ///
    /// El campo era un texto libre validado con TimeSpan.TryParse, que
    /// convierte "8" en 8 DÍAS: aceptaba como hora del día algo que no lo es.
    /// Una lista cerrada resuelve eso sin pedirle nada al usuario.
    /// </summary>
    protected void CargarHoras()
    {
        CargarHoras(cboHora);
    }

    /// <summary>La misma lista, para cualquier combo de hora de la ficha.</summary>
    protected void CargarHoras(RadComboBox2 combo)
    {
        combo.Items.Clear();

        /* La primera vacía: la hora de una fecha suelta es opcional, y sin
           esta opción el combo obligaría a elegir una que nadie pidió. */
        combo.Items.Add(new RadComboBoxItem("(sin hora)", ""));

        for (int h = 0; h < 24; h++)
            for (int m = 0; m < 60; m += 15)
            {
                string v = h.ToString("00") + ":" + m.ToString("00");
                combo.Items.Add(new RadComboBoxItem(v, v));
            }
    }

    /// <summary>
    /// Deja seleccionada una hora guardada aunque no caiga en el cuarto de
    /// hora: si un registro tiene 07:23 se agrega esa opción en vez de
    /// reescribirle el dato a alguien que no pidió cambiarlo.
    /// </summary>
    protected void SeleccionarHora(TimeSpan hora)
    {
        string v = hora.ToString(@"hh\:mm");

        if (cboHora.Items.FindItemByValue(v) == null)
            cboHora.Items.Insert(0, new RadComboBoxItem(v, v));

        Seleccionar(cboHora, v);
    }

    protected void CargarAlcance()
    {
        ProgramacionController c = new ProgramacionController();

        Llenar(cboInstalacion, c.GetCatalogoAlcance("INSTALACION"), true);
        LlenarPersonas(c.GetCatalogoAlcance("RESPONSABLE"));
        

        CargarDependientes();
    }

    /// <summary>Áreas y activos de la instalación elegida.</summary>
    protected void CargarDependientes()
    {
        ProgramacionController c = new ProgramacionController();

        int? inst = null;
        int v;

        if (int.TryParse(cboInstalacion.SelectedValue, out v)) inst = v;

        Llenar(cboArea, c.GetCatalogoAlcance("AREA", inst), true);
        Llenar(cboActivo, c.GetCatalogoAlcance("ACTIVO", inst), true);

        /* Los grupos también dependen de la instalación: una cuadrilla de
           otra planta es gente que no puede ir. */
        Llenar(cboGrupo, c.GetGrupos(inst), true);
    }

    /// <summary>
    /// El combo de personas, con su avatar.
    ///
    /// Cada opción lleva la foto y las iniciales como atributos. El navegador
    /// los usa para dibujar el chip de quien se va marcando: sin eso, "2
    /// seleccionados" no dice QUIÉNES, que es justo lo que hay que poder
    /// revisar antes de guardar.
    ///
    /// No lleva la opción vacía: son casillas, y "(sin definir)" marcable no
    /// significa nada.
    /// </summary>
    protected void LlenarPersonas(List<CatalogoItem> items)
    {
        cboResponsable.Items.Clear();

        if (items == null) return;

        foreach (CatalogoItem i in items)
        {
            RadComboBoxItem it = new RadComboBoxItem(i.nombre, i.id.ToString());

            /* El código viene como "archivoFoto|INICIALES" desde el SP. */
            string[] partes = (i.codigo ?? "").Split('|');

            string foto = partes.Length > 0 ? partes[0] : "0";
            string iniciales = partes.Length > 1 ? partes[1] : "";

            int idFoto;

            it.Attributes["data-foto"] =
                (int.TryParse(foto, out idFoto) && idFoto > 0)
                    ? SitioBase.UrlArchivo.Ver(idFoto)
                    : "";

            it.Attributes["data-ini"] = iniciales;

            /* El nombre sin el perfil, para el chip: en un chip de 200px
               "Marcela Aravena · Técnico de Mantenimiento" no cabe. */
            int corte = i.nombre.IndexOf("  ·  ", StringComparison.Ordinal);
            it.Attributes["data-nombre"] = corte > 0 ? i.nombre.Substring(0, corte) : i.nombre;

            cboResponsable.Items.Add(it);
        }
    }

    protected void cboInstalacion_SelectedIndexChanged(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        /* Cambiar de planta invalida el área y el equipo elegidos: no se
           conservan "por si acaso", porque pertenecen a otra instalación. */
        CargarDependientes();
    }

    /// <summary>Los ids marcados, separados por coma. Vacío si no hay ninguno.</summary>
    protected string ResponsablesMarcados()
    {
        StringBuilder b = new StringBuilder();

        foreach (RadComboBoxItem it in cboResponsable.Items)
        {
            if (!it.Checked || string.IsNullOrEmpty(it.Value)) continue;

            if (b.Length > 0) b.Append(',');
            b.Append(it.Value);
        }

        return b.ToString();
    }

    /// <summary>Los nombres marcados, para el resumen.</summary>
    protected string NombresMarcados()
    {
        StringBuilder b = new StringBuilder();

        foreach (RadComboBoxItem it in cboResponsable.Items)
        {
            if (!it.Checked || string.IsNullOrEmpty(it.Value)) continue;

            if (b.Length > 0) b.Append(", ");
            b.Append(it.Text);
        }

        return b.ToString();
    }

    protected void MarcarResponsables(string ids)
    {
        DesmarcarResponsables();

        if (string.IsNullOrEmpty(ids)) return;

        foreach (string id in ids.Split(','))
        {
            string v = id.Trim();
            if (v == "") continue;

            RadComboBoxItem it = cboResponsable.Items.FindItemByValue(v);
            if (it != null) it.Checked = true;
        }
    }

    protected void DesmarcarResponsables()
    {
        foreach (RadComboBoxItem it in cboResponsable.Items) it.Checked = false;
    }

    protected void ModoAsignacion_Click(object sender, EventArgs e)
    {
        LinkButton b = sender as LinkButton;
        if (b == null) return;

        ModoAsignacion = b.CommandName;

        /* Al cambiar de modo se limpia el otro: la base rechaza tener los dos
           y dejarlo cargado en silencio haría fallar el guardado sin que se
           vea por qué. */
        if (ModoAsignacion != "persona") DesmarcarResponsables();
        if (ModoAsignacion != "grupo") Seleccionar(cboGrupo, "");
    }

    #endregion

    #region Exclusiones

    private int _exclusiones;

    /// <summary>
    /// La tabla como Repeater.
    ///
    /// Mismos comandos, mismo evento y mismo permiso que la RadGrid: lo que
    /// cambia es que ahora se lee. La grilla sigue existiendo oculta para no
    /// perder lo que ya sabía hacer.
    /// </summary>
    protected void BindExclusionesRepeater(List<ProgramacionExclusion> lista)
    {
        List<ExclusionFila> filas = new List<ExclusionFila>();

        if (lista != null)
            foreach (ProgramacionExclusion x in lista)
            {
                ExclusionFila f = new ExclusionFila();
                f.Id = x.pxc_id;
                f.Desde = x.pxc_fecha_inicio_utc.ToString("dd-MM-yyyy");
                f.Hasta = x.pxc_fecha_fin_utc.ToString("dd-MM-yyyy");
                f.Motivo = x.pxc_motivo ?? "";
                f.Efecto = x.pxc_desplaza ? "Correr al siguiente hábil" : "No generar nada";
                f.EfectoClase = x.pxc_desplaza ? "is-info" : "is-alerta";
                filas.Add(f);
            }

        _exclusiones = filas.Count;

        rptExclusiones.DataSource = filas;
        rptExclusiones.DataBind();

        rptExclusiones.Visible = filas.Count > 0;
        pnlSinExclusiones.Visible = filas.Count == 0;
    }

    protected void rptExclusiones_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        LinkButton borrar = e.Item.FindControl("btnEliminar") as LinkButton;
        if (borrar == null) return;

        /* El permiso se aplica acá y no solo al pintar la sección: esconder
           el botón no es seguridad, pero mostrarlo a quien no puede es
           prometerle algo que el servidor le va a negar. */
        borrar.Visible = Token.PuedeFuncion("Crear y editar");

        /* Una exclusión borrada por error no avisa: la programación vuelve a
           generar trabajo el feriado y nadie se entera hasta que alguien
           llega a la planta un 18 de septiembre. */
        borrar.OnClientClick = "return confirmarBorrado('¿Eliminar esta exclusión? " +
                               "La programación volverá a generar actividades en esas fechas.');";
    }

    protected void rptExclusiones_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "Eliminar") return;

        if (!Token.PuedeFuncion("Crear y editar")) return;

        int id;
        if (!int.TryParse(e.CommandArgument.ToString(), out id)) return;

        ProgramacionController c = new ProgramacionController();
        Respuesta r = c.DeleteExclusion(id);

        Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");

        if (!r.error) BindExclusionesRepeater(c.GetExclusiones(Id));
    }

    #endregion

    #region Resumen

    /// <summary>
    /// El panel lateral. Todo lo que muestra sale de lo que hay cargado en el
    /// formulario; ninguna línea está escrita a mano.
    ///
    /// Existe porque en el paso 5 ya nadie recuerda qué puso en el 1.
    /// </summary>
    protected void PintarResumen()
    {
        litResumenFrase.Text = Server.HtmlEncode(FraseRecurrencia());

        StringBuilder b = new StringBuilder();

        Dato(b, "mdi-tag-outline", cboTipo.Text);
        Dato(b, "mdi-earth", cboZonaHoraria.Text);

        if (calInicio.Value != null)
            Dato(b, "mdi-calendar-start", "Desde " + calInicio.Value.Value.ToString("dd-MM-yyyy"));

        Dato(b, "mdi-calendar-end", calFin.Value != null
            ? "Hasta " + calFin.Value.Value.ToString("dd-MM-yyyy")
            : "Sin fecha de término");

        // Alcance y asignación: solo si se declararon.
        if (!string.IsNullOrEmpty(cboInstalacion.SelectedValue))
        {
            string alcance = cboInstalacion.Text;

            if (!string.IsNullOrEmpty(cboArea.SelectedValue)) alcance += "  ·  " + cboArea.Text;
            if (!string.IsNullOrEmpty(cboActivo.SelectedValue)) alcance += "  ·  " + cboActivo.Text;

            Dato(b, "mdi-map-marker-outline", alcance);
        }

        if (ModoAsignacion == "persona" && ResponsablesMarcados() != "")
            Dato(b, "mdi-account-outline", NombresMarcados());
        else if (ModoAsignacion == "grupo" && !string.IsNullOrEmpty(cboGrupo.SelectedValue))
            Dato(b, "mdi-account-group-outline", cboGrupo.Text);

        Dato(b, "mdi-robot-outline", rdbGeneraSi.Checked
            ? "Generación automática" : "Generación manual");

        if (_exclusiones > 0)
            Dato(b, "mdi-calendar-remove", _exclusiones +
                 (_exclusiones == 1 ? " exclusión configurada" : " exclusiones configuradas"));

        litResumenDatos.Text = b.ToString();

        PintarProximas();

        // ---- el estado ----
        List<string> faltas = new List<string>();

        for (int n = 1; n <= 5; n++)
        {
            string f = FaltaEnPaso(n);
            if (f != "") faltas.Add(TITULOS_PASO[n - 1] + ": " + f);
        }

        if (faltas.Count == 0)
        {
            litResumenEstado.Text =
                "<div class=\"sg-resumen-estado is-ok\">" +
                "<i class=\"mdi mdi-check-circle\"></i><span>Configuración válida</span></div>";
        }
        else
        {
            StringBuilder e = new StringBuilder();
            e.Append("<div class=\"sg-resumen-estado is-falta\">");
            e.Append("<i class=\"mdi mdi-alert-circle-outline\"></i>");
            e.Append("<div><strong>Falta completar</strong><ul>");

            foreach (string f in faltas)
                e.Append("<li>" + Server.HtmlEncode(f) + "</li>");

            e.Append("</ul></div></div>");
            litResumenEstado.Text = e.ToString();
        }

        PintarRevision(faltas);
    }

    /// <summary>
    /// Las próximas ejecuciones, en el resumen lateral.
    ///
    /// NO SON OCURRENCIAS: es el cálculo de FNC_PROGRAMACION_FECHAS. Sirve
    /// para ver si la regla dice lo que uno cree que dice ANTES de que
    /// empiece a generar trabajo de verdad.
    ///
    /// Solo existe sobre una programación guardada: el cálculo se hace en la
    /// base, sobre la regla que ya está escrita, no sobre lo que hay en el
    /// formulario sin confirmar.
    /// </summary>
    private void PintarProximas()
    {
        pnlResumenProximas.Visible = false;
        litResumenProximas.Text = "";

        if (Id <= 0) return;

        List<ProgramacionProyeccion> fechas = new ProgramacionController().GetProyeccion(Id, 5);

        if (fechas == null || fechas.Count == 0)
        {
            /* Una programación guardada que no proyecta ninguna fecha es un
               dato, no un vacío: casi siempre significa que la vigencia ya
               terminó o que la regla quedó incompleta. Decirlo evita que
               alguien la dé por buena. */
            pnlResumenProximas.Visible = true;
            litResumenProximas.Text =
                "<div class=\"sg-resumen-dato is-tenue\">" +
                "<i class=\"mdi mdi-calendar-remove-outline\"></i>" +
                "<span>Sin fechas próximas con esta regla.</span></div>";
            return;
        }

        StringBuilder b = new StringBuilder();

        foreach (ProgramacionProyeccion f in fechas)
        {
            b.Append("<div class=\"sg-proxima" + (f.es_pasada ? " is-pasada" : "") + "\">");
            b.Append("<span class=\"sg-proxima-punto\"></span>");
            b.Append("<span class=\"sg-proxima-fecha\">" + f.fecha.ToString("dd MMM yyyy") + "</span>");

            if (f.fecha.TimeOfDay != TimeSpan.Zero)
                b.Append("<span class=\"sg-proxima-hora\">" + f.fecha.ToString("HH:mm") + "</span>");

            b.Append("</div>");

            /* Si la fecha se corrió por una exclusión se dice por qué: una
               fecha que no calza con la regla y no explica el motivo hace
               dudar del cálculo entero. */
            if (f.desplazada)
            {
                string desde = f.fecha_original != null
                    ? f.fecha_original.Value.ToString("dd-MM") : "";

                b.Append("<div class=\"sg-proxima-nota\">Corrida" +
                         (desde != "" ? " desde el " + desde : "") +
                         (string.IsNullOrEmpty(f.motivo) ? "" : ": " + Server.HtmlEncode(f.motivo)) +
                         "</div>");
            }
        }

        pnlResumenProximas.Visible = true;
        litResumenProximas.Text = b.ToString();
    }

    private void Dato(StringBuilder b, string icono, string texto)
    {
        if (string.IsNullOrEmpty(texto)) return;

        b.Append("<div class=\"sg-resumen-dato\"><i class=\"mdi " + icono + "\"></i>");
        b.Append("<span>" + Server.HtmlEncode(texto) + "</span></div>");
    }

    /// <summary>El paso 6: esto es lo que se va a guardar.</summary>
    private void PintarRevision(List<string> faltas)
    {
        StringBuilder b = new StringBuilder();

        b.Append("<dl class=\"sg-revision\">");
        Revision(b, "Nombre", txtNombre.Text.Trim());
        Revision(b, "Tipo", cboTipo.Text);
        Revision(b, "Recurrencia", FraseRecurrencia());
        Revision(b, "Vigencia", (calInicio.Value != null ? calInicio.Value.Value.ToString("dd-MM-yyyy") : "—") +
                                " → " + (calFin.Value != null ? calFin.Value.Value.ToString("dd-MM-yyyy") : "sin término"));
        Revision(b, "Zona horaria", cboZonaHoraria.Text);

        Revision(b, "Alcance", string.IsNullOrEmpty(cboInstalacion.SelectedValue)
            ? "Sin alcance declarado"
            : cboInstalacion.Text +
              (string.IsNullOrEmpty(cboArea.SelectedValue) ? "" : "  ·  " + cboArea.Text) +
              (string.IsNullOrEmpty(cboActivo.SelectedValue) ? "" : "  ·  " + cboActivo.Text));

        Revision(b, "Responsable",
            ModoAsignacion == "persona" ? NombresMarcados() :
            ModoAsignacion == "grupo" ? cboGrupo.Text : "Sin asignar");

        Revision(b, "Ventana",
            "Antes " + (txtToleranciaAntes.Value != null ? ((int)txtToleranciaAntes.Value.Value).ToString() : "0") +
            " min  ·  después " + (txtToleranciaDespues.Value != null ? ((int)txtToleranciaDespues.Value.Value).ToString() : "0") + " min");

        Revision(b, "Exclusiones", _exclusiones == 0 ? "Ninguna" : _exclusiones.ToString());
        b.Append("</dl>");

        if (faltas.Count > 0)
        {
            b.Append("<div class=\"sg-nota is-aviso\"><i class=\"mdi mdi-alert-outline\"></i><div>");
            b.Append("<strong>Hay pasos incompletos.</strong> Se puede guardar igual si el tipo lo permite, ");
            b.Append("pero conviene revisar: ");
            b.Append(Server.HtmlEncode(string.Join("  ·  ", faltas.ToArray())));
            b.Append("</div></div>");
        }

        litRevision.Text = b.ToString();
    }

    private void Revision(StringBuilder b, string rotulo, string valor)
    {
        b.Append("<dt>" + Server.HtmlEncode(rotulo) + "</dt>");
        b.Append("<dd>" + Server.HtmlEncode(string.IsNullOrEmpty(valor) ? "No disponible" : valor) + "</dd>");
    }

    #endregion
}
