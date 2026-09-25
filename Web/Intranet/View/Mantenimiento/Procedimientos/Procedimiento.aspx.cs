using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/* El paso en edicion vive en SitioBase.Model y no aca: el controlador de
   la carga masiva devuelve listas de el, y App_Code se compila antes que
   las paginas, asi que no podria ver un tipo declarado en este archivo.
   El alias es para no escribir el nombre largo en cada linea. */
using PasoEd = SitioBase.Model.ProcedimientoPasoEdicion;

/// <summary>
/// Un procedimiento y sus pasos, en una sola pantalla (HU-061 + HU-062).
///
/// ANTES ERAN DOS MENUS
///   "Procedimientos" y "Pasos de procedimiento". Escribir una receta de ocho
///   pasos costaba abrir el segundo menu, elegir el procedimiento en un combo y
///   repetir nueve veces el ciclo nuevo-guardar-cerrar. El orden se escribia a
///   mano y el par (procedimiento, orden) es unico, asi que intercalar un paso
///   obligaba a renumerar los de abajo uno por uno.
///
/// LOS PASOS SE EDITAN EN MEMORIA
///   La lista vive en el ViewState y se escribe recien al guardar. No es por
///   ahorrar viajes: es que el orden final tiene que aplicarse de una sola
///   pasada (UPD_PROCEDIMIENTO_PASO_ORDEN). Guardando paso por paso, mover el
///   quinto al segundo lugar choca con el indice unico a la mitad del camino,
///   y lo que queda es media receta renumerada.
///
/// LO QUE NO SE HIZO, A PROPOSITO
///   El diseño mostraba "dictar por voz" y "adjuntar una referencia" en el
///   paso, y tipos de evidencia aceptada (foto, firma). Procedimiento_Paso no
///   tiene donde guardar nada de eso —ni archivo, ni referencia, ni tipo de
///   evidencia, solo el si/no de ppa_requiere_evidencia—, y un control que se
///   pinta pero no persiste es peor que no tenerlo.
///
/// La escritura la habilita Token.Puede("CREAR EDITAR PROCEDIMIENTOS"); un
/// procedimiento global del sistema se muestra en solo lectura.
/// </summary>
public partial class View_Mantenimiento_Procedimientos_Procedimiento : System.Web.UI.Page
{
    #region Estado de la pantalla

    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    // Un procedimiento global (prc_cliente NULL) no lo edita el cliente.
    public bool EsGlobal
    {
        get { return ViewState["EsGlobal"] != null && (bool)ViewState["EsGlobal"]; }
        set { ViewState["EsGlobal"] = value; }
    }

    /// <summary>Indice del paso que se esta editando; -1 si ninguno.</summary>
    public int Elegido
    {
        get { return ViewState["Elegido"] != null ? (int)ViewState["Elegido"] : -1; }
        set { ViewState["Elegido"] = value; }
    }

    public bool Sucio
    {
        get { return ViewState["Sucio"] != null && (bool)ViewState["Sucio"]; }
        set { ViewState["Sucio"] = value; }
    }

    /// <summary>El formulario de la cabecera esta desplegado.</summary>
    public bool DatosAbiertos
    {
        get { return ViewState["DatosAbiertos"] != null && (bool)ViewState["DatosAbiertos"]; }
        set { ViewState["DatosAbiertos"] = value; }
    }

    /// <summary>Los pasos en pantalla, en su orden actual.</summary>
    public List<PasoEd> Pasos
    {
        get
        {
            List<PasoEd> l = ViewState["Pasos"] as List<PasoEd>;
            if (l == null) { l = new List<PasoEd>(); ViewState["Pasos"] = l; }
            return l;
        }
        set { ViewState["Pasos"] = value; }
    }

    /// <summary>
    /// Pasos que ya existian y se quitaron de la lista. No se borran: el DEL
    /// es una baja logica y rechaza los que ya se usaron en una orden, asi que
    /// hay que conservar su id para pedirla al guardar.
    /// </summary>
    public List<int> Bajas
    {
        get
        {
            List<int> l = ViewState["Bajas"] as List<int>;
            if (l == null) { l = new List<int>(); ViewState["Bajas"] = l; }
            return l;
        }
    }

    /// <summary>Lo que trajo la planilla, a la espera de importarse.</summary>
    public List<PasoEd> Importados
    {
        get { return ViewState["Importados"] as List<PasoEd>; }
        set { ViewState["Importados"] = value; }
    }

    #endregion

    #region Ciclo de vida

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        if (ctrl.ID == "cboTipo")
        {
            ActivoTipoController c = new ActivoTipoController();
            ctrl.Items.Add(new RadComboBoxItem("Cualquier tipo", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = c.GetActivoTipos(new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });
            ctrl.DataValueField = "ati_id"; ctrl.DataTextField = "ati_nombre"; ctrl.DataBind();
        }
        else if (ctrl.ID == "cboPermisoTipo")
        {
            PermisoTrabajoController c = new PermisoTrabajoController();
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = c.GetTipos();
            ctrl.DataValueField = "ptt_id"; ctrl.DataTextField = "ptt_nombre"; ctrl.DataBind();
        }
        else if (ctrl.ID == "cboVariable")
        {
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            VariableMedicionController c = new VariableMedicionController();
            List<VariableMedicion> lista = c.GetVariables(cliente);
            if (lista != null)
                foreach (VariableMedicion v in lista)
                    ctrl.Items.Add(new RadComboBoxItem(v.etiqueta, v.vme_id.ToString()));
        }
    }

    protected void rdbPermiso_CheckedChanged(object sender, EventArgs e)
    {
        // El postback recarga; Bloqueo() ajusta el combo segun el radio.
        Sucio = true;
    }

    protected void chkMedicion_CheckedChanged(object sender, EventArgs e)
    {
        // Capturar ANTES: el postback del toggle trae lo que se escribio en el
        // editor y si no se guarda aca se pierde al repintar.
        CapturarEditor();
        Sucio = true;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Pintar();
        Bloqueo();

        /* Los tres escriben o leen el disco -dos descargas y un FileUpload- y
           eso no sobrevive a un postback asincrono: el UpdatePanel espera un
           fragmento de HTML y recibe un binario. */
        btnCerrar.OnClientClick = "return sgProcVolver('" +
            ResolveUrl("~/View/Mantenimiento/Procedimientos/Procedimientos.aspx") + "');";

        /* SOLO EL ARCHIVO RECARGA

           Los tres botones del asistente escriben o leen el disco -dos
           descargas y un FileUpload- y eso no sobrevive a un postback
           asincrono. Guardar, en cambio, no tiene por que recargar la
           pantalla entera, y hacerlo con la receta a medio escribir es justo
           lo que mas molesta.

           Los demas se registran como asincronos a proposito: un LinkButton
           sin id -y los de un repeater no lo tienen si no se les pone-
           postea con __doPostBack sin que el PageRequestManager pueda ubicar
           su UpdatePanel, y sale completo. */
        ScriptManager sm = ScriptManager.GetCurrent(Page);

        sm.RegisterPostBackControl(btnPlantilla);
        sm.RegisterPostBackControl(btnRevisar);
        sm.RegisterPostBackControl(btnCargaErrores);

        sm.RegisterAsyncPostBackControl(btnGuardar);
        sm.RegisterAsyncPostBackControl(rptPasos);
        sm.RegisterAsyncPostBackControl(lnkAgregarPaso);
        sm.RegisterAsyncPostBackControl(lnkCargaMasiva);
        sm.RegisterAsyncPostBackControl(lnkEditarDatos);

        udPanel.Update();
    }

    /// <summary>Lo de la base, una sola vez: despues manda el ViewState.</summary>
    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id == 0)
        {
            lblId.Text = "Nuevo";
            txtVersion.Text = "1";
            DatosAbiertos = true;      // sin datos no hay nada que resumir
            return;
        }

        ProcedimientoController c = new ProcedimientoController();
        Procedimiento x = c.GetProcedimiento(Id);

        lblId.Text = Id.ToString();
        litModo.Text = "Editar procedimiento";
        if (!string.IsNullOrEmpty(x.prc_nombre)) litTitulo.Text = Server.HtmlEncode(x.prc_nombre);
        txtCodigo.Text = x.prc_codigo;
        txtVersion.Text = x.prc_version.ToString();
        txtNombre.Text = x.prc_nombre;
        txtDescripcion.Text = x.prc_descripcion;
        txtDuracion.Text = x.prc_duracion_estimada_minuto != null ? x.prc_duracion_estimada_minuto.ToString() : "";
        EsGlobal = x.es_global;

        if (x.prc_activo_tipo != null) SeleccionarCombo(cboTipo, x.prc_activo_tipo.Value);

        rdbPermisoSi.Checked = x.prc_requiere_permiso;
        rdbPermisoNo.Checked = !x.prc_requiere_permiso;
        if (x.prc_permiso_trabajo_tipo != null) SeleccionarCombo(cboPermisoTipo, x.prc_permiso_trabajo_tipo.Value);

        rdbSi.Checked = x.prc_habilitado;
        rdbNo.Checked = !x.prc_habilitado;

        wucAuditoria.Mostrar(x.usuario_creacion_nombre, x.prc_fecha_creacion,
                             x.usuario_actualizacion_nombre, x.prc_fecha_actualizacion);

        LeerPasos();
    }

    /// <summary>Trae los pasos del procedimiento a la lista de trabajo.</summary>
    private void LeerPasos()
    {
        Pasos = new List<PasoEd>();
        Bajas.Clear();
        Elegido = -1;

        if (Id == 0) return;

        ProcedimientoPasoController c = new ProcedimientoPasoController();
        List<ProcedimientoPaso> lista = c.GetPasos(new ProcedimientoPaso { filtro_procedimiento = Id });
        if (lista == null) return;

        foreach (ProcedimientoPaso p in lista.OrderBy(x => x.ppa_orden))
            Pasos.Add(new PasoEd
            {
                id = p.ppa_id,
                nombre = p.ppa_nombre,
                instruccion = p.ppa_instruccion,
                duracion = p.ppa_duracion_estimada_minuto,
                punto_control = p.ppa_es_punto_control,
                evidencia = p.ppa_requiere_evidencia,
                medicion = p.ppa_requiere_medicion,
                variable = p.ppa_variable_medicion,
                variable_nombre = p.variable_nombre,
                habilitado = p.ppa_habilitado
            });

        if (Pasos.Count > 0) Elegido = 0;
    }

    /// <summary>
    /// El texto del item elegido de un combo.
    ///
    /// No se usa combo.Text: cuando la seleccion se hizo en el servidor
    /// (FindItemByValue + Selected) el RadComboBox deja Text vacio, y el
    /// resumen de la cabecera salia con dos chips en blanco -"tipo de activo" y
    /// "permiso"- en una receta que si los tenia.
    /// </summary>
    private static string TextoCombo(RadComboBox2 combo)
    {
        if (combo.SelectedItem != null && !string.IsNullOrEmpty(combo.SelectedItem.Text)) return combo.SelectedItem.Text;
        if (!string.IsNullOrEmpty(combo.Text)) return combo.Text;

        RadComboBoxItem i = combo.FindItemByValue(combo.SelectedValue);
        return i != null ? i.Text : "";
    }

    private void SeleccionarCombo(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null) item.Selected = true;
    }

    #endregion

    #region Pintado

    /// <summary>
    /// El resumen, la lista y el editor. Se repinta completo en cada postback:
    /// el estado esta en el ViewState, asi que pintar es una funcion de eso y
    /// no hay que acordarse de actualizar tres cosas en cada comando.
    /// </summary>
    private void Pintar()
    {
        List<PasoEd> pasos = Pasos;

        // ---- resumen de la cabecera ----
        string codigo = txtCodigo.Text.Trim();
        litCodigo.Text = codigo.Length > 0
            ? Server.HtmlEncode(codigo) + " <span class=\"sg-pr-res-ver\">v" + Server.HtmlEncode(txtVersion.Text.Trim()) + "</span>"
            : "<span class=\"sg-pr-res-ver\">Sin código todavía</span>";

        litChipTipo.Text = Server.HtmlEncode(
            !string.IsNullOrEmpty(cboTipo.SelectedValue) ? TextoCombo(cboTipo) : "Cualquier tipo de activo");

        string estimacion = txtDuracion.Text.Trim();
        litChipEstimacion.Text = estimacion.Length > 0
            ? Server.HtmlEncode(estimacion) + " min estimados"
            : "Sin estimación";

        litChipPermiso.Text = rdbPermisoSi.Checked
            ? Server.HtmlEncode(!string.IsNullOrEmpty(cboPermisoTipo.SelectedValue) ? TextoCombo(cboPermisoTipo) : "Requiere permiso")
            : "Sin permiso especial";

        if (EsGlobal)
            litChipEstado.Text = "<span class=\"sg-proc-badge is-global\">Global</span>";
        else if (rdbSi.Checked)
            litChipEstado.Text = "<span class=\"sg-proc-badge is-si\">Habilitado</span>";
        else
            litChipEstado.Text = "<span class=\"sg-proc-badge is-no\">Deshabilitado</span>";

        pnlDatos.Visible = DatosAbiertos;
        litEditarDatos.Text = DatosAbiertos ? "Ocultar datos" : "Editar datos";

        // ---- lista de pasos ----
        litPasosN.Text = pasos.Count.ToString();

        int suma = pasos.Where(p => p.habilitado && p.duracion != null).Sum(p => p.duracion.Value);
        litPasosMin.Text = suma > 0 ? suma + " min en total" : "";

        AvisoMinutos(suma);

        List<PasoVista> vista = new List<PasoVista>();
        for (int i = 0; i < pasos.Count; i++)
            vista.Add(new PasoVista
            {
                indice = i,
                numero = (i + 1).ToString(),
                nombre = string.IsNullOrEmpty(pasos[i].nombre) ? "(paso sin nombre)" : pasos[i].nombre,
                meta = Meta(pasos[i]),
                elegido = (i == Elegido),
                primero = (i == 0),
                ultimo = (i == pasos.Count - 1),
                habilitado = pasos[i].habilitado
            });

        rptPasos.DataSource = vista;
        rptPasos.DataBind();

        pnlSinPasos.Visible = pasos.Count == 0;

        // ---- editor del paso elegido ----
        bool hay = Elegido >= 0 && Elegido < pasos.Count;
        pnlEditor.Visible = hay;
        pnlSinSeleccion.Visible = !hay && pasos.Count > 0;

        if (hay)
        {
            PasoEd p = pasos[Elegido];

            litPasoNum.Text = (Elegido + 1).ToString();
            litPasoDe.Text = (Elegido + 1) + " de " + pasos.Count;

            txtPasoNombre.Text = p.nombre;
            txtPasoInstruccion.Text = p.instruccion;
            txtPasoDuracion.Text = p.duracion != null ? p.duracion.ToString() : "";
            chkPuntoControl.Checked = p.punto_control;
            chkEvidencia.Checked = p.evidencia;
            chkMedicion.Checked = p.medicion;
            chkPasoHabilitado.Checked = p.habilitado;

            cboVariable.ClearSelection();
            if (p.variable != null) SeleccionarCombo(cboVariable, p.variable.Value);

            pnlVariable.CssClass = p.medicion ? "sg-pr-variable" : "sg-pr-variable es-oculta";
        }

        // ---- el aviso de cambios sin guardar ----
        pnlPie.CssClass = Sucio ? "sg-pr-pie sg-proc-footer es-sucio" : "sg-pr-pie sg-proc-footer";
    }

    /// <summary>La linea de marcas de un paso en la lista.</summary>
    private string Meta(PasoEd p)
    {
        List<string> partes = new List<string>();

        if (p.duracion != null) partes.Add("<span>" + p.duracion + " min</span>");
        if (p.punto_control) partes.Add("<span class=\"es-marca\"><i class=\"mdi mdi-check-decagram-outline\"></i>Control</span>");
        if (p.evidencia) partes.Add("<span class=\"es-marca\"><i class=\"mdi mdi-camera-outline\"></i>Evidencia</span>");
        if (p.medicion) partes.Add("<span class=\"es-marca\"><i class=\"mdi mdi-gauge\"></i>" +
                                   Server.HtmlEncode(string.IsNullOrEmpty(p.variable_nombre) ? "Medición" : p.variable_nombre) + "</span>");
        if (!p.habilitado) partes.Add("<span class=\"es-baja\">Deshabilitado</span>");

        return string.Join("", partes.ToArray());
    }

    /// <summary>
    /// La suma de los pasos contra la estimacion de la cabecera. No es un
    /// error -la estimacion puede incluir traslado y preparacion- pero una
    /// diferencia grande casi siempre es un numero que quedo viejo.
    /// </summary>
    private void AvisoMinutos(int suma)
    {
        pnlAvisoMinutos.Visible = false;

        int estimado;
        if (!int.TryParse(txtDuracion.Text.Trim(), out estimado) || estimado <= 0 || suma <= 0) return;

        if (suma > estimado)
        {
            litAvisoMinutos.Text = "Los pasos suman <strong>" + suma + " min</strong> y la estimación del procedimiento dice <strong>" +
                                   estimado + " min</strong>. Revise cuál de los dos está viejo.";
            pnlAvisoMinutos.Visible = true;
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR PROCEDIMIENTOS") && !EsGlobal;

        pnlGlobal.Visible = EsGlobal;

        if (Id > 0)
        {
            if (EsGlobal)
                litEstado.Text = "<span class=\"sg-proc-badge is-global\">Global</span>";
            else if (rdbSi.Checked)
                litEstado.Text = "<span class=\"sg-proc-badge is-si\">Habilitado</span>";
            else
                litEstado.Text = "<span class=\"sg-proc-badge is-no\">Deshabilitado</span>";
        }

        // Codigo y version son la llave: no se editan una vez creado.
        txtCodigo.ReadOnly = !puedeEditar || Id > 0;
        txtVersion.ReadOnly = !puedeEditar || Id > 0;
        txtNombre.ReadOnly = !puedeEditar;
        txtDuracion.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboTipo.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        rdbPermisoSi.Enabled = puedeEditar;
        rdbPermisoNo.Enabled = puedeEditar;
        // El tipo de permiso solo aplica si se exige permiso.
        cboPermisoTipo.ReadOnly = !puedeEditar || !rdbPermisoSi.Checked;

        // Los pasos: se ven siempre, se escriben solo con permiso.
        txtPasoNombre.ReadOnly = !puedeEditar;
        txtPasoInstruccion.ReadOnly = !puedeEditar;
        txtPasoDuracion.ReadOnly = !puedeEditar;
        chkPuntoControl.Enabled = puedeEditar;
        chkEvidencia.Enabled = puedeEditar;
        chkMedicion.Enabled = puedeEditar;
        chkPasoHabilitado.Enabled = puedeEditar;
        cboVariable.ReadOnly = !puedeEditar || !chkMedicion.Checked;

        lnkAgregarPaso.Visible = puedeEditar;
        lnkCargaMasiva.Visible = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    #endregion

    #region La cabecera y la lista de pasos

    protected void lnkEditarDatos_Click(object sender, EventArgs e)
    {
        CapturarEditor();
        DatosAbiertos = !DatosAbiertos;
    }

    /// <summary>
    /// Lo que esta escrito en el editor pasa al paso elegido.
    ///
    /// Se llama al principio de CADA comando. El editor es uno y los pasos son
    /// varios: si no se captura antes de repintar, elegir otro paso -o subir el
    /// actual- borra lo que se acababa de escribir sin avisar. Esa es tambien
    /// la razon de que no haya boton "aplicar": no hay nada que aplicar.
    /// </summary>
    private void CapturarEditor()
    {
        List<PasoEd> pasos = Pasos;
        if (Elegido < 0 || Elegido >= pasos.Count) return;
        if (EsGlobal || !Token.Puede("CREAR EDITAR PROCEDIMIENTOS")) return;

        PasoEd p = pasos[Elegido];

        p.nombre = txtPasoNombre.Text.Trim();
        p.instruccion = txtPasoInstruccion.Text.Trim();

        int min;
        p.duracion = int.TryParse(txtPasoDuracion.Text.Trim(), out min) && min > 0 ? (int?)min : null;

        p.punto_control = chkPuntoControl.Checked;
        p.evidencia = chkEvidencia.Checked;
        p.medicion = chkMedicion.Checked;
        p.habilitado = chkPasoHabilitado.Checked;

        if (p.medicion && !string.IsNullOrEmpty(cboVariable.SelectedValue))
        {
            p.variable = int.Parse(cboVariable.SelectedValue);
            p.variable_nombre = TextoCombo(cboVariable);
        }
        else
        {
            p.variable = null;
            p.variable_nombre = "";
        }

        Pasos = pasos;
    }

    protected void lnkAgregarPaso_Click(object sender, EventArgs e)
    {
        CapturarEditor();

        List<PasoEd> pasos = Pasos;
        pasos.Add(new PasoEd { id = 0, nombre = "Paso " + (pasos.Count + 1), habilitado = true });
        Pasos = pasos;

        Elegido = pasos.Count - 1;
        Sucio = true;
    }

    protected void rptPasos_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        CapturarEditor();

        int i;
        if (!int.TryParse(Convert.ToString(e.CommandArgument), out i)) return;

        List<PasoEd> pasos = Pasos;
        if (i < 0 || i >= pasos.Count) return;

        switch (e.CommandName)
        {
            case "sel":
                Elegido = i;
                break;

            case "sube":
                if (i == 0) return;
                Mover(pasos, i, i - 1);
                break;

            case "baja":
                if (i == pasos.Count - 1) return;
                Mover(pasos, i, i + 1);
                break;

            case "quita":
                /* Un paso que ya existe no se borra de la base aca: se anota
                   para pedir su baja al guardar. El DEL la rechaza si el paso
                   ya se ejecuto en una orden, y ese "no" tiene que llegar
                   junto con el resto del guardado, no despues. */
                if (pasos[i].id > 0) Bajas.Add(pasos[i].id);
                pasos.RemoveAt(i);
                Pasos = pasos;

                if (Elegido >= pasos.Count) Elegido = pasos.Count - 1;
                Sucio = true;
                break;
        }
    }

    private void Mover(List<PasoEd> pasos, int desde, int hasta)
    {
        PasoEd p = pasos[desde];
        pasos.RemoveAt(desde);
        pasos.Insert(hasta, p);
        Pasos = pasos;

        if (Elegido == desde) Elegido = hasta;
        else if (Elegido == hasta) Elegido = desde;

        Sucio = true;
    }

    #endregion

    #region Carga masiva (asistente en esta misma pantalla)

    protected void lnkCargaMasiva_Click(object sender, EventArgs e)
    {
        CapturarEditor();
        Importados = null;
        pnlCarga.Visible = true;
        pnlCarga1.Visible = true;
        pnlCarga2.Visible = false;
        pnlPasos.Visible = false;
        PintarStepper(1);
    }

    protected void lnkCargaCerrar_Click(object sender, EventArgs e)
    {
        Importados = null;
        pnlCarga.Visible = false;
        pnlPasos.Visible = true;
    }

    private void PintarStepper(int paso)
    {
        liPaso1.Attributes["class"] = paso == 1 ? "es-actual" : "es-hecho";
        liPaso2.Attributes["class"] = paso == 2 ? "es-actual" : (paso > 2 ? "es-hecho" : "");
        liPaso3.Attributes["class"] = paso == 3 ? "es-actual" : "";
    }

    protected void btnPlantilla_Click(object sender, EventArgs e)
    {
        try
        {
            new ProcedimientoPasoCargaController().Plantilla();
        }
        catch (System.Threading.ThreadAbortException)
        {
            /* Response.End() la lanza siempre: es como termina una descarga,
               no un fallo. Se deja pasar para que no la atrape el catch de
               abajo y avise de un error sobre un archivo que si se envio. */
            throw;
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void btnRevisar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!fldArchivo.HasFile) throw new Exception("Adjunte la planilla que quiere importar.");
            if (!fldArchivo.FileName.ToLower().EndsWith(".xlsx"))
                throw new Exception("El archivo tiene que ser .xlsx. Si lo guardó como .xls o .csv, vuelva a guardarlo como libro de Excel.");

            List<PasoEd> leidos = new ProcedimientoPasoCargaController().Analizar(fldArchivo.FileBytes);

            if (leidos.Count == 0)
                throw new Exception("La hoja PASOS está vacía o no existe en el libro. Descargue la plantilla y trabaje sobre ella.");

            Importados = leidos;

            litCargaArchivo.Text = Server.HtmlEncode(fldArchivo.FileName);
            litCargaOk.Text = leidos.Count(p => p.ok).ToString();
            litCargaMal.Text = leidos.Count(p => !p.ok).ToString();

            rptCarga.DataSource = leidos.Select((p, n) => new CargaVista
            {
                fila = p.fila.ToString(),
                nombre = string.IsNullOrEmpty(p.nombre) ? "(sin nombre)" : p.nombre,
                minutos = p.duracion != null ? p.duracion.ToString() : "—",
                marcas = Marcas(p),
                ok = p.ok,
                motivo = p.motivo
            }).ToList();
            rptCarga.DataBind();

            int buenos = leidos.Count(p => p.ok);
            btnImportar.Text = buenos == 1 ? "Importar 1 paso" : "Importar " + buenos + " pasos";
            btnImportar.Visible = buenos > 0;
            btnCargaErrores.Visible = buenos < leidos.Count;

            pnlCarga.Visible = true;
            pnlCarga1.Visible = false;
            pnlCarga2.Visible = true;
            pnlPasos.Visible = false;
            PintarStepper(2);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
            pnlCarga.Visible = true;
            pnlCarga1.Visible = true;
            pnlCarga2.Visible = false;
            pnlPasos.Visible = false;
            PintarStepper(1);
        }
    }

    private string Marcas(PasoEd p)
    {
        List<string> m = new List<string>();
        if (p.punto_control) m.Add("Control");
        if (p.evidencia) m.Add("Evidencia");
        if (p.medicion) m.Add(string.IsNullOrEmpty(p.variable_nombre) ? "Medición" : p.variable_nombre);
        return m.Count > 0 ? Server.HtmlEncode(string.Join(" · ", m.ToArray())) : "—";
    }

    protected void btnCargaErrores_Click(object sender, EventArgs e)
    {
        try
        {
            List<PasoEd> leidos = Importados;
            if (leidos == null) throw new Exception("Vuelva a revisar el archivo.");

            new ProcedimientoPasoCargaController().Errores(leidos.Where(p => !p.ok).ToList());
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Importar deja los pasos EN LA LISTA, no en la base: se revisan junto
    /// con los que ya estaban y se guardan todos con el mismo boton. Asi una
    /// planilla a medio armar no deja media receta escrita.
    /// </summary>
    protected void btnImportar_Click(object sender, EventArgs e)
    {
        try
        {
            List<PasoEd> leidos = Importados;
            if (leidos == null) throw new Exception("Vuelva a revisar el archivo.");

            List<PasoEd> buenos = leidos.Where(p => p.ok).ToList();
            if (buenos.Count == 0) throw new Exception("Ninguna fila de la planilla se puede importar.");

            List<PasoEd> pasos = Pasos;

            if (rdbModoReemplazar.Checked)
            {
                // Los que ya existian se van de baja al guardar; los que solo
                // estaban en pantalla desaparecen sin mas.
                foreach (PasoEd p in pasos)
                    if (p.id > 0) Bajas.Add(p.id);
                pasos = new List<PasoEd>();
            }

            pasos.AddRange(buenos);
            Pasos = pasos;

            Elegido = pasos.Count - buenos.Count;
            Sucio = true;
            Importados = null;

            pnlCarga.Visible = false;
            pnlPasos.Visible = true;

            Tools.tools.ClientAlert(
                buenos.Count + (buenos.Count == 1 ? " paso importado" : " pasos importados") +
                ". Revise la lista y guarde para escribirlos.", "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #endregion

    #region Guardar todo

    /// <summary>
    /// Guarda el procedimiento y sus pasos en un solo gesto.
    ///
    /// EL ORDEN VA AL FINAL Y DE UNA SOLA PASADA
    ///   Primero se escriben los pasos sin tocar su orden y despues se aplica
    ///   la lista completa con UPD_PROCEDIMIENTO_PASO_ORDEN. El par
    ///   (procedimiento, orden) es unico: asignando de a uno, mover el quinto
    ///   al segundo lugar choca con el tercero a mitad de camino.
    ///
    /// LAS BAJAS PUEDEN FALLAR Y ESO NO ANULA EL RESTO
    ///   El DEL rechaza un paso que ya se ejecuto en una orden. Ese "no" se
    ///   informa, pero lo demas queda guardado: obligar a deshacer todo por un
    ///   paso viejo seria peor.
    /// </summary>
    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            CapturarEditor();

            if (EsGlobal) throw new Exception("Este procedimiento es del sistema y no se edita desde aquí.");
            if (string.IsNullOrEmpty(txtCodigo.Text.Trim())) throw new Exception("Debe indicar el código.");
            if (string.IsNullOrEmpty(txtNombre.Text.Trim())) throw new Exception("Debe indicar el nombre.");

            bool requierePermiso = rdbPermisoSi.Checked;
            if (requierePermiso && string.IsNullOrEmpty(cboPermisoTipo.SelectedValue))
                throw new Exception("Si el procedimiento exige permiso de trabajo, indique de qué tipo.");

            List<PasoEd> pasos = Pasos;

            // Los pasos se validan ANTES de escribir nada: si el tercero no
            // tiene nombre, no se crea el procedimiento ni los dos primeros.
            for (int i = 0; i < pasos.Count; i++)
            {
                if (string.IsNullOrEmpty((pasos[i].nombre ?? "").Trim()))
                    throw new Exception("El paso " + (i + 1) + " no tiene nombre.");

                if (pasos[i].medicion && pasos[i].variable == null)
                    throw new Exception("El paso " + (i + 1) + " requiere medición: indique la variable.");
            }

            // ---- 1. el procedimiento ----
            Procedimiento x = new Procedimiento();
            ProcedimientoController c = new ProcedimientoController();

            x.prc_id = Id;
            x.prc_cliente = SitioBase.Session.ClienteId();
            x.prc_codigo = txtCodigo.Text.Trim();
            x.prc_nombre = txtNombre.Text.Trim();
            x.prc_habilitado = rdbSi.Checked;
            x.prc_requiere_permiso = requierePermiso;

            int version;
            x.prc_version = int.TryParse(txtVersion.Text.Trim(), out version) ? version : 1;

            int duracion;
            if (int.TryParse(txtDuracion.Text.Trim(), out duracion)) x.prc_duracion_estimada_minuto = duracion;

            if (!string.IsNullOrEmpty(cboTipo.SelectedValue))
                x.prc_activo_tipo = int.Parse(cboTipo.SelectedValue);
            else
                x.quita_tipo = true;   // al editar, dejarlo sin tipo

            if (requierePermiso && !string.IsNullOrEmpty(cboPermisoTipo.SelectedValue))
                x.prc_permiso_trabajo_tipo = int.Parse(cboPermisoTipo.SelectedValue);

            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim())) x.prc_descripcion = txtDescripcion.Text.Trim();

            Respuesta r = (Id > 0) ? c.UpdateProcedimiento(x) : c.InsertProcedimiento(x);

            if (r.error)
            {
                Tools.tools.ClientAlert(r.detalle, "alerta");
                return;
            }

            Id = r.codigo;

            // ---- 2. los pasos ----
            ProcedimientoPasoController cp = new ProcedimientoPasoController();
            List<string> problemas = new List<string>();

            // 2.a las bajas de los que se quitaron de la lista
            foreach (int idBaja in Bajas.Distinct().ToList())
            {
                Respuesta rb = cp.DeletePaso(new ProcedimientoPaso { ppa_id = idBaja });
                if (rb.error) problemas.Add(rb.detalle);
            }
            Bajas.Clear();

            // 2.b los que ya existian y los nuevos. El orden NO se toca aca:
            // lo aplica una sola pasada mas abajo.
            List<int> orden = new List<int>();

            foreach (PasoEd p in pasos)
            {
                ProcedimientoPaso e2 = new ProcedimientoPaso
                {
                    ppa_id = p.id,
                    ppa_procedimiento = Id,
                    ppa_nombre = (p.nombre ?? "").Trim(),
                    ppa_instruccion = string.IsNullOrEmpty(p.instruccion) ? null : p.instruccion,
                    ppa_es_punto_control = p.punto_control,
                    ppa_requiere_evidencia = p.evidencia,
                    ppa_requiere_medicion = p.medicion,
                    ppa_variable_medicion = p.medicion ? p.variable : null,
                    ppa_duracion_estimada_minuto = p.duracion,
                    ppa_habilitado = p.habilitado,
                    quita_variable = !p.medicion
                };

                Respuesta rp = (p.id > 0) ? cp.UpdatePaso(e2) : cp.InsertPaso(e2);

                if (rp.error)
                {
                    problemas.Add("Paso \"" + (p.nombre ?? "") + "\": " + rp.detalle);
                    continue;
                }

                p.id = rp.codigo;
                orden.Add(p.id);
            }

            // 2.c el orden final, de una sola vez
            if (orden.Count > 0)
            {
                Respuesta ro = cp.OrdenarPasos(Id, orden);
                if (ro.error) problemas.Add(ro.detalle);
            }

            // ---- 3. volver a leer: lo que quedo escrito es la verdad ----
            int eraElegido = Elegido;
            LeerPasos();
            if (eraElegido >= 0 && eraElegido < Pasos.Count) Elegido = eraElegido;

            Sucio = false;
            lblId.Text = Id.ToString();
            litModo.Text = "Editar procedimiento";

            if (problemas.Count > 0)
                Tools.tools.ClientAlert("Se guardó el procedimiento, pero: " + string.Join(" ", problemas.ToArray()), "alerta");
            else
                Tools.tools.ClientAlert("Procedimiento y pasos guardados con éxito.", "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #endregion
}

/// <summary>Una fila de la lista de pasos, como la pinta el repeater.</summary>
[Serializable]
public class PasoVista
{
    public int indice { get; set; }
    public string numero { get; set; }
    public string nombre { get; set; }
    public string meta { get; set; }
    public bool elegido { get; set; }
    public bool primero { get; set; }
    public bool ultimo { get; set; }
    public bool habilitado { get; set; }
}

/// <summary>Una fila de la revision de la planilla.</summary>
[Serializable]
public class CargaVista
{
    public string fila { get; set; }
    public string nombre { get; set; }
    public string minutos { get; set; }
    public string marcas { get; set; }
    public bool ok { get; set; }
    public string motivo { get; set; }
}
