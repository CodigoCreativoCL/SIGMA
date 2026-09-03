using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Text;
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
            cmd.Parameters.AddWithValue("@GRUPO_TRABAJO", Id);

            List<GrupoTrabajoUsuario> personas = new List<GrupoTrabajoUsuario>();

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    /* El perfil y no el correo: armar un grupo de trabajo es
                       decidir quién sabe hacer qué, y eso lo dice el perfil.
                       El correo solo permitía comprobar que la persona
                       existe, que no es lo que hay que decidir acá. */
                    string especialidades = dr["ESPECIALIDADES"].ToString();
                    string identificador = dr["USU_IDENTIFICADOR"].ToString();

                    GrupoTrabajoUsuario p = new GrupoTrabajoUsuario();
                    p.gtu_usuario = int.Parse(dr["USU_ID"].ToString());
                    p.usu_nombre = dr["USU_NOMBRE"].ToString() +
                                   (string.IsNullOrEmpty(identificador) ? "" : " · " + identificador) + " · " +
                                   (string.IsNullOrEmpty(especialidades) ? "sin especialidad" : especialidades);
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

        /* La pestaña de integrantes existe siempre, pero mientras el grupo no
           esté guardado muestra por qué no se puede usar todavía en vez de
           quedar vacía. Una pestaña en blanco se lee como una pantalla rota. */
        pnlIntegrantes.Visible = Id > 0;
        pnlSinGrupo.Visible = Id == 0;

        if (Id > 0)
        {
            CargarUsuarios();
            CargarIntegrantes();
            CargarResumenEquipo();
        }
        else
        {
            CargarResumenEquipo();
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
        GrupoTrabajoUsuario filtro = new GrupoTrabajoUsuario { gtu_grupo_trabajo = Id };

        bool buscando = !string.IsNullOrEmpty(txtBuscarIntegrante.Text);

        if (buscando) filtro.filtro = txtBuscarIntegrante.Text.Trim();

        List<GrupoTrabajoUsuario> lista = controller.GetIntegrantes(filtro) ??
                                          new List<GrupoTrabajoUsuario>();

        rptIntegrantes.DataSource = lista;
        rptIntegrantes.DataBind();

        /* El vacio de "todavia no hay nadie" y el de "la busqueda no
           encontro" son dos situaciones distintas y se responden distinto:
           una invita a agregar, la otra a cambiar lo que se escribio. Un
           unico mensaje generico dejaria a alguien buscando un problema
           donde solo hay un filtro puesto. */
        pnlSinIntegrantes.Visible = lista.Count == 0;

        if (lista.Count == 0)
        {
            litVacioTitulo.Text = buscando
                ? "Nadie coincide con la búsqueda"
                : "Todavía no hay nadie en el grupo";

            litVacioTexto.Text = buscando
                ? "Pruebe con otro nombre o con una especialidad."
                : "Agregue la primera persona con el buscador de arriba.";
        }
    }

    protected void CargarResumenEquipo()
    {
        if (Id <= 0)
        {
            litTituloGrupo.Text = "Nuevo grupo de trabajo";
            litCodigoGrupo.Text = "<span><i class=\"mdi mdi-auto-fix\"></i>Código automático</span>";
            litEstadoGrupo.Text = "<span class=\"is-active\">Habilitado</span>";
            tabIntegrantes.Text = "Integrantes · después de guardar";
            litEspecialidadPredominante.Text = "Sin calcular";
            litEspecialidadDetalle.Text = "Se calculará cuando agregue integrantes con especialidades.";
            litComposicion.Text = "";
            return;
        }

        GrupoTrabajoController controller = new GrupoTrabajoController();
        GrupoTrabajo grupo = controller.GetGrupoTrabajo(new GrupoTrabajo { gtr_id = Id });
        List<GrupoTrabajoUsuario> vigentes = controller.GetIntegrantes(new GrupoTrabajoUsuario
        {
            gtu_grupo_trabajo = Id,
            filtro_solo_vigentes = true
        }) ?? new List<GrupoTrabajoUsuario>();
        List<GrupoEspecialidadResumen> resumen = controller.GetResumenEspecialidades(Id);

        litTituloGrupo.Text = Server.HtmlEncode(string.IsNullOrEmpty(grupo.gtr_nombre) ? "Grupo de trabajo" : grupo.gtr_nombre);
        litCodigoGrupo.Text = "<span><i class=\"mdi mdi-identifier\"></i>" +
                              Server.HtmlEncode(grupo.gtr_codigo) + " · ID " + Id + "</span>";
        litEstadoGrupo.Text = grupo.gtr_habilitado
            ? "<span class=\"is-active\"><i class=\"mdi mdi-check-circle-outline\"></i>Habilitado</span>"
            : "<span class=\"is-inactive\"><i class=\"mdi mdi-pause-circle-outline\"></i>Deshabilitado</span>";

        int lideres = 0;
        string lider = "Sin líder vigente";
        foreach (GrupoTrabajoUsuario integrante in vigentes)
        {
            if (!integrante.gtu_es_lider) continue;
            lideres++;
            lider = integrante.usu_nombre;
        }

        tabIntegrantes.Text = vigentes.Count == 1 ? "Integrantes · 1 vigente" : "Integrantes · " + vigentes.Count + " vigentes";
        litResumenIntegrantes.Text = vigentes.Count == 1 ? "1 persona" : vigentes.Count + " personas";
        litResumenLider.Text = Server.HtmlEncode(lider);

        string predominante = "Sin especialidad predominante";
        string detalle = "Los integrantes vigentes no tienen especialidades registradas.";
        StringBuilder composicion = new StringBuilder();
        List<string> empates = new List<string>();

        foreach (GrupoEspecialidadResumen item in resumen)
        {
            if (item.es_predominante)
            {
                predominante = item.esp_nombre;
                detalle = item.cantidad == 1
                    ? "1 integrante vigente tiene esta especialidad."
                    : item.cantidad + " integrantes vigentes tienen esta especialidad.";
            }
            if (item.es_empate) empates.Add(item.esp_nombre);

            string clase = item.es_predominante ? " is-top" : (item.es_empate ? " is-tie" : "");
            composicion.Append("<span class=\"sg-grupo-specialty-chip" + clase + "\">" +
                               Server.HtmlEncode(item.esp_nombre) + " <b>" + item.cantidad + "</b></span>");
        }

        if (empates.Count > 1)
        {
            predominante = "Sin predominante por empate";
            detalle = "Empatan con la mayor cantidad: " + string.Join(", ", empates.ToArray()) + ".";
        }

        litEspecialidadPredominante.Text = Server.HtmlEncode(predominante);
        litEspecialidadDetalle.Text = Server.HtmlEncode(detalle);
        litComposicion.Text = composicion.ToString();
        litResumenPredominante.Text = Server.HtmlEncode(predominante);
    }

    protected void txtBuscarIntegrante_TextChanged(object sender, EventArgs e)
    {
        tabFicha.SelectedIndex = 1;
        mpFicha.SelectedIndex = 1;
    }

    protected void lnkLimpiarIntegrantes_Click(object sender, EventArgs e)
    {
        txtBuscarIntegrante.Text = "";
        tabFicha.SelectedIndex = 1;
        mpFicha.SelectedIndex = 1;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR GRUPOS TRABAJO");

        /* Nunca se escribe a mano: lo genera el SP al crear, y despues
               identifica el registro. */
            txtCodigo.ReadOnly = true;
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;

        cboUsuario.Enabled = puedeEditar;
        calDesde.Enabled = puedeEditar;
        calHasta.Enabled = puedeEditar;
        chkEsLider.Enabled = puedeEditar;
        btnAgregar.Visible = puedeEditar;
        txtBuscarIntegrante.Enabled = true;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR GRUPOS TRABAJO"))
            {
                Tools.tools.ClientAlert("No tiene permisos para guardar grupos de trabajo.", "alerta");
                return;
            }

            Page.Validate("Grupo");
            if (!Page.IsValid || string.IsNullOrWhiteSpace(txtNombre.Text))
            {
                Tools.tools.ClientAlert("Indique el nombre del grupo.", "alerta");
                return;
            }

            GrupoTrabajo entidad = new GrupoTrabajo();
            GrupoTrabajoController controller = new GrupoTrabajoController();

            entidad.gtr_id = Id;
            entidad.gtr_cliente = SitioBase.Session.ClienteId();
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como GRU-<id>: el
               codigo depende del ID, y el ID no existe hasta despues del
               INSERT, asi que no hay forma de calcularlo antes.

               AUTO y no vacio: el SP valida que el codigo venga ANTES de
               insertar, asi que un vacio se rechaza con "indique el codigo".
               AUTO pasa esa validacion, nunca queda guardado, y el SP lo
               reemplaza en cuanto conoce el ID.

               Al editar viaja el que ya tiene. No se regenera nunca: el
               codigo esta impreso en su etiqueta, y cambiarlo dejaria la
               etiqueta pegada apuntando a algo que no existe. */
            entidad.gtr_codigo = (Id > 0) ? txtCodigo.Text.Trim() : "AUTO";
            entidad.gtr_nombre = txtNombre.Text.Trim();
            entidad.gtr_descripcion = txtDescripcion.Text.Trim();
            entidad.gtr_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboPlanta.SelectedValue))
                entidad.gtr_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            else
                // Combo vacío significa "hazlo transversal", no "déjalo como
                // estaba". Sin la bandera el SP conservaría la planta actual.
                entidad.quita_planta = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateGrupoTrabajo(entidad)
                : controller.InsertGrupoTrabajo(entidad);

            if (!respuesta.error)
            {
                bool esNuevo = Id == 0;
                if (esNuevo) Id = respuesta.codigo;

                if (esNuevo)
                {
                    tabFicha.SelectedIndex = 1;
                    mpFicha.SelectedIndex = 1;
                }

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
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    protected void btnAgregar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR GRUPOS TRABAJO"))
            {
                Tools.tools.ClientAlert("No tiene permisos para modificar integrantes.", "alerta");
                return;
            }

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

            if (integrante.gtu_fecha_inicio != null && integrante.gtu_fecha_fin != null &&
                integrante.gtu_fecha_fin.Value.Date < integrante.gtu_fecha_inicio.Value.Date)
            {
                Tools.tools.ClientAlert("La fecha de término no puede ser anterior a la fecha de inicio.", "alerta");
                return;
            }

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
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    /* ========================================================================
       CADA PERSONA, DIBUJADA

       El HTML se arma aca y no en el markup con `Eval()` por una razon
       concreta de este proyecto: es un Website Project, donde los tipos
       anonimos son internos y `Eval()` sobre ellos falla en tiempo de
       ejecucion. Y ademas el avatar sale de `SitioBase.Avatar`, que es el
       mismo que usan las demas pantallas: asi una persona tiene su color en
       todo el producto y se la reconoce de un vistazo.
       ======================================================================== */
    protected void rptIntegrantes_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item &&
            e.Item.ItemType != ListItemType.AlternatingItem) return;

        GrupoTrabajoUsuario g = e.Item.DataItem as GrupoTrabajoUsuario;

        if (g == null) return;

        Literal lit = (Literal)e.Item.FindControl("litPersona");
        LinkButton quitar = (LinkButton)e.Item.FindControl("lnkQuitar");

        if (quitar != null)
        {
            quitar.CommandArgument = g.gtu_id.ToString();
            quitar.Visible = Token.Puede("CREAR EDITAR GRUPOS TRABAJO");
            /* El nombre viaja dentro de una cadena de JavaScript entre
               comillas simples. Un apellido con apostrofe -O'Higgins, muy
               chileno- cerraria la cadena y rompería el onclick, asi que se
               escapa antes. */
            quitar.OnClientClick = "return ConfirSweetAlert(this, '', '¿Quitar a " +
                                   EscapaJs(g.usu_nombre) +
                                   " del grupo?');";

            ScriptManager.GetCurrent(Page).RegisterPostBackControl(quitar);
        }

        if (lit == null) return;

        StringBuilder b = new StringBuilder();

        b.Append(SitioBase.Avatar.Persona(g.gtu_usuario, g.usu_nombre, g.usu_archivo_foto));

        b.Append("<div class=\"sg-persona-datos\">");

        // ---- Nombre y rol ----
        b.Append("<div class=\"sg-persona-nombre\">");
        b.Append("<strong>" + Server.HtmlEncode(g.usu_nombre) + "</strong>");

        if (g.gtu_es_lider)
            b.Append("<span class=\"sg-persona-lider\" title=\"Lidera el grupo\">" +
                     "<i class=\"mdi mdi-star\"></i>Líder</span>");

        b.Append("<span class=\"grid-estado-chip " + ChipDeEstado(g.estado) + "\">" +
                 Server.HtmlEncode(g.estado ?? "") + "</span>");

        b.Append("</div>");

        /* Las especialidades como pastillas y no como un texto separado por
           comas: son una lista, y una lista leida de corrido obliga a buscar
           las comas para separarla. */
        if (!string.IsNullOrEmpty(g.especialidades))
        {
            b.Append("<div class=\"sg-persona-esp\">");

            foreach (string esp in g.especialidades.Split(new string[] { ", " }, StringSplitOptions.RemoveEmptyEntries))
                b.Append("<span>" + Server.HtmlEncode(esp.Trim()) + "</span>");

            b.Append("</div>");
        }
        else
        {
            b.Append("<div class=\"sg-persona-esp is-vacia\"><span>Sin especialidades registradas</span></div>");
        }

        // ---- Hasta cuando ----
        b.Append("<div class=\"sg-persona-pie\"><i class=\"mdi mdi-calendar-range\"></i>" +
                 Server.HtmlEncode(Vigencia(g)) + "</div>");

        b.Append("</div>");

        lit.Text = b.ToString();
    }

    /// <summary>
    /// El nombre, listo para viajar dentro de una cadena de JavaScript.
    ///
    /// La confirmación arma su mensaje entre comillas simples. Un apellido con
    /// apóstrofe —O'Higgins, muy chileno— cerraría la cadena antes de tiempo y
    /// el botón dejaría de funcionar para esa persona y solo para esa.
    /// </summary>
    private static string EscapaJs(string valor)
    {
        return (valor ?? "")
               .Replace("\\", "\\\\")
               .Replace("'", "\\'");
    }

    /// <summary>
    /// La vigencia en palabras.
    ///
    /// "01-09-2026 - " deja a quien lee completando la frase. Con "Desde el
    /// 01-09-2026, sin termino" no hay nada que interpretar, y el caso mas
    /// comun -sin fechas- se dice entero en tres palabras.
    /// </summary>
    private static string Vigencia(GrupoTrabajoUsuario g)
    {
        bool hayInicio = g.gtu_fecha_inicio != null;
        bool hayFin = g.gtu_fecha_fin != null;

        if (!hayInicio && !hayFin) return "Sin fechas: vigente mientras esté en el grupo";

        if (hayInicio && !hayFin)
            return "Desde el " + g.gtu_fecha_inicio.Value.ToString("dd-MM-yyyy") + ", sin término";

        if (!hayInicio)
            return "Hasta el " + g.gtu_fecha_fin.Value.ToString("dd-MM-yyyy");

        return "Del " + g.gtu_fecha_inicio.Value.ToString("dd-MM-yyyy") +
               " al " + g.gtu_fecha_fin.Value.ToString("dd-MM-yyyy");
    }

    protected void rptIntegrantes_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "quitar") return;

        try
        {
            if (!Token.Puede("CREAR EDITAR GRUPOS TRABAJO"))
            {
                Tools.tools.ClientAlert("No tiene permisos para modificar integrantes.", "alerta");
                return;
            }

            int id;

            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;

            GrupoTrabajoController controller = new GrupoTrabajoController();
            Respuesta respuesta = controller.DeleteIntegrante(new GrupoTrabajoUsuario { gtu_id = id });

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");

            tabFicha.SelectedIndex = 1;
            mpFicha.SelectedIndex = 1;
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
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

}
