using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de actividades de un hito de plan (HU-082).
///
/// El acceso a la pantalla lo resuelve el master con Token.ExigirPagina():
/// acá no hay bloque de seguridad porque en SIGMA los permisos son datos, no
/// código. Lo único que se pregunta es la función de escritura.
///
/// SE ENTRA DESDE UN HITO
///   Se llega desde el centro del plan, apretando las actividades de un
///   hito, y ese hito viene cifrado en el query. El combo de hitos queda
///   fijado en él, pero se puede cambiar: el planificador que compara dos
///   hitos no tiene que volver al plan para hacerlo.
///
/// EL CLIENTE VIAJA SIEMPRE EN EL FILTRO
///   Session.ClienteId() va en cada consulta. Una actividad de otra empresa
///   no aparece aunque se conozca su id, porque el SP la filtra cruzando el
///   plan y el listado nunca se pide sin cliente.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanActividades : System.Web.UI.Page
{
    /// <summary>El hito con el que se entró, si se entró desde uno.</summary>
    public int Hito
    {
        get { return ViewState["Hito"] != null ? (int)ViewState["Hito"] : 0; }
        set { ViewState["Hito"] = value; }
    }

    /// <summary>
    /// El query cifrado con el que el modal nace vacío, apuntando al hito
    /// que está mirando la grilla. Lo arma el servidor: el id no viaja a la
    /// vista ni en claro ni a medias.
    /// </summary>
    public string QueryNueva
    {
        get { return Server.UrlEncode(Tools.Crypto.Encrypt("Hito=" + HitoEnPantalla())); }
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
                    if (array[0].ToString() == "Hito") Hito = Int32.Parse(array[1].ToString());
                }
            }

            Grid.AddSelectColumn();
            Grid.AddColumn("PAA_ID", "", Width: "3%");
            Grid.AddColumn("PAA_ORDEN", "N°", Width: "4%");
            Grid.AddColumn("PAA_CODIGO", "CÓDIGO", Width: "8%");
            Grid.AddColumn("PAA_NOMBRE", "ACTIVIDAD", Width: "28%");
            /* El hito se muestra solo cuando la grilla trae varios; con un
               hito elegido, la columna repite el mismo texto en cada fila y le
               quita ancho a lo que sí cambia. Lo decide Columnas(). */
            Grid.AddColumn("HITO_CODIGO", "HITO", Width: "10%");
            /* Field vacío: el contenido lo arma ItemDataBound. Es como lo
               hacen el listado de planes y Existencias. */
            Grid.AddTemplateColumn("PROCEDIMIENTO", "", "PROCEDIMIENTO", Width: "18%");
            Grid.AddTemplateColumn("DURACION", "", "DURACIÓN", Width: "8%", ItemPosition: HorizontalAlign.Right);
            Grid.AddTemplateColumn("EXIGE", "", "EXIGE", Width: "16%", Wrap: true);
            Grid.AddCheckboxColumn("PAA_HABILITADO", "HABILITADO", Width: "7%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        // Sin cliente en sesión no hay nada que listar: los planes son de un
        // cliente, no de la plataforma.
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        ConfigurarHitos();

        Columnas();
        CargarGrid();
        BarraComandos();
        Grid.DataBind();
        Contexto();
        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    /// <summary>
    /// Con un hito elegido, la columna HITO dice lo mismo en todas las filas:
    /// se esconde y su ancho se lo queda la actividad, que es lo que hay que
    /// leer. Se esconde y no se saca porque al soltar el filtro vuelve a
    /// hacer falta, y reconstruir las columnas en cada carga pierde el orden
    /// y el ancho que el usuario haya movido.
    /// </summary>
    private void Columnas()
    {
        GridColumn hito = Grid.MasterTableView.GetColumn("HITO_CODIGO");
        if (hito != null) hito.Display = HitoEnPantalla() == 0;
    }

    /// <summary>
    /// El hito que la grilla está mostrando: el del filtro si el usuario lo
    /// cambió, y si no el que vino en el query. Lo usan el botón «Nueva» y la
    /// línea de contexto, que tienen que hablar del mismo hito que la grilla.
    /// </summary>
    private int HitoEnPantalla()
    {
        RadComboBox2 cbo = Cbo("cboHitoFiltro");

        if (cbo != null && !string.IsNullOrEmpty(cbo.SelectedValue))
            return int.Parse(cbo.SelectedValue);

        return Hito;
    }

    /// <summary>
    /// El combo de hitos se llena desde la base y no desde el markup: un
    /// catálogo copiado en un .aspx es el que nadie actualiza el día que
    /// cambia. Se reconstruye en cada carga preservando lo elegido.
    /// </summary>
    private void ConfigurarHitos()
    {
        RadComboBox2 cbo = Cbo("cboHitoFiltro");
        if (cbo == null) return;

        // Lo elegido manda; la primera vez manda el hito del query.
        string seleccion = !string.IsNullOrEmpty(cbo.SelectedValue)
                         ? cbo.SelectedValue
                         : (Hito > 0 ? Hito.ToString() : "");

        List<PlanHito> hitos = new PlanHitoController().GetPlanHitos(
            new PlanHito { filtro_cliente = SitioBase.Session.ClienteId() })
            ?? new List<PlanHito>();

        cbo.Items.Clear();
        cbo.Items.Add(new RadComboBoxItem("Todos los hitos", ""));
        foreach (PlanHito h in hitos)
            cbo.Items.Add(new RadComboBoxItem(
                h.plan_codigo + " · " + h.pmh_codigo + " — " + h.pmh_nombre, h.pmh_id.ToString()));

        RadComboBoxItem item = cbo.FindItemByValue(seleccion ?? "");
        if (item != null) item.Selected = true;
    }

    protected void CargarGrid()
    {
        PlanActividad filtro = new PlanActividad();
        PlanActividadController controller = new PlanActividadController();

        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        int hito = HitoEnPantalla();
        if (hito > 0) filtro.filtro_hito = hito;

        RadComboBox2 cboHabilitado = Cbo("cboHabilitado");

        // wucFiltro.Filtro() va al @FILTRO parametrizado del SEL_. Nunca
        // concatenado: en el buscador eso era inyección SQL (bloque 49).
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetPlanActividades(filtro);
    }

    /// <summary>
    /// Cuándo se ofrece crear y eliminar.
    ///
    /// Dos condiciones, y las dos tienen que darse: la función de escritura
    /// del usuario, y que la versión esté en borrador. Esconder la barra no
    /// autoriza nada —el SP y la ficha vuelven a exigir el permiso—, pero
    /// ofrecer «Nueva» sobre una versión publicada es invitar a llenar un
    /// formulario que va a terminar rechazado, dos líneas más abajo del
    /// aviso que dice que esa versión ya no se edita.
    /// </summary>
    private void BarraComandos()
    {
        bool puedeEscribir = Token.PuedeFuncion("Crear y editar") && VersionEditable();

        if (!puedeEscribir)
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;
    }

    /// <summary>
    /// Si lo que se está mirando se puede escribir. Se resuelve con las
    /// filas que ya se leyeron; sin filas, se pregunta por el hito, que es
    /// una consulta y no una por fila.
    /// </summary>
    private bool VersionEditable()
    {
        List<PlanActividad> lista = Grid.DataSource as List<PlanActividad>;

        if (lista != null && lista.Count > 0) return lista[0].version_editable;

        int hito = HitoEnPantalla();

        // Sin hito elegido la grilla mezcla versiones: se ofrece escribir y
        // cada fila responde por la suya, que es lo que hace el SP.
        if (hito == 0) return true;

        PlanHito h = new PlanHitoController().GetPlanHito(new PlanHito { pmh_id = hito });
        return h.pmh_id == 0 || h.version_editable;
    }

    /// <summary>
    /// De qué hito son estas actividades y cómo se vuelve a su plan.
    ///
    /// Se arma con la primera fila y no con una consulta aparte: el SEL ya
    /// trae el plan, la versión y el hito resueltos, y pedirlos otra vez
    /// sería un viaje para un dato que está en la mano.
    /// </summary>
    private void Contexto()
    {
        List<PlanActividad> lista = Grid.DataSource as List<PlanActividad>;
        int hito = HitoEnPantalla();

        if (hito == 0)
        {
            pnlContexto.Visible = true;
            litContexto.Text = "<i class=\"mdi mdi-information-outline\"></i> "
                             + "Actividades de todos los hitos del cliente. Elija un hito en el filtro para trabajar sobre uno.";
            return;
        }

        if (lista == null || lista.Count == 0)
        {
            // El hito existe pero todavía no tiene actividades: no hay fila
            // de dónde sacar su nombre, así que se pide el hito.
            PlanHito h = new PlanHitoController().GetPlanHito(new PlanHito { pmh_id = hito });

            pnlContexto.Visible = h.pmh_id > 0;
            if (h.pmh_id > 0)
                litContexto.Text = Linea(h.plan_id, h.plan_codigo, h.plan_nombre,
                                         h.pmh_codigo, h.pmh_nombre, h.version_numero, h.version_estado_codigo);
            return;
        }

        PlanActividad a = lista[0];
        pnlContexto.Visible = true;
        litContexto.Text = Linea(a.plan_id, a.plan_codigo, a.plan_nombre,
                                 a.hito_codigo, a.hito_nombre, a.version_numero, a.version_estado_codigo);
    }

    private string Linea(int planId, string planCodigo, string planNombre,
                         string hitoCodigo, string hitoNombre, int? versionNumero, string versionEstado)
    {
        string url = ResolveUrl("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx")
                   + "?query=" + Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + planId));

        string chip = string.Equals(versionEstado, "BORRADOR", StringComparison.OrdinalIgnoreCase)
            ? "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-pencil-outline\"></i>v" + versionNumero + " borrador</span>"
            : "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-lock-outline\"></i>v" + versionNumero + " " + Server.HtmlEncode((versionEstado ?? "").ToLower()) + "</span>";

        string texto = "<a href=\"" + url + "\"><i class=\"mdi mdi-arrow-left\"></i> "
                     + Server.HtmlEncode(planCodigo) + " — " + Server.HtmlEncode(planNombre) + "</a>"
                     + " &nbsp;/&nbsp; <strong>" + Server.HtmlEncode(hitoCodigo) + "</strong> "
                     + Server.HtmlEncode(hitoNombre) + " &nbsp; " + chip;

        // Una versión que no es borrador no se edita: se dice acá, porque es
        // antes de abrir la ficha y descubrirlo con todo escrito.
        if (!string.Equals(versionEstado, "BORRADOR", StringComparison.OrdinalIgnoreCase))
            texto += "<div class=\"sigma-modal-ayuda\" style=\"margin-top:6px;\">"
                   + "<i class=\"mdi mdi-lock-outline\"></i> Esta versión ya no está en borrador: sus actividades se leen, no se editan. "
                   + "Para cambiarlas, abra una versión nueva del plan.</div>";

        return texto;
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        PlanActividad a = item.DataItem as PlanActividad;
        if (a == null) return;

        string id = item.GetDataKeyValue("paa_id").ToString();
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditar" + id;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirPlanActividad('" + query + "')");
        item["paa_id"].Controls.Add(Editar);

        item["PROCEDIMIENTO"].Controls.Add(new Literal { Text = CeldaProcedimiento(a) });
        item["DURACION"].Controls.Add(new Literal { Text = CeldaDuracion(a) });
        item["EXIGE"].Controls.Add(new Literal { Text = CeldaExige(a) });
    }

    /// <summary>
    /// El procedimiento con sus pasos. Uno enganchado pero SIN pasos no
    /// aporta nada a la orden que se genere, y eso hay que verlo en la
    /// grilla y no descubrirlo cuando la orden sale vacía.
    /// </summary>
    private string CeldaProcedimiento(PlanActividad a)
    {
        if (a.paa_procedimiento == null)
            return "<span class=\"sigma-inv-vacio\">sin procedimiento</span>";

        string texto = Server.HtmlEncode(a.procedimiento_nombre);

        if (a.procedimiento_pasos == 0)
            return texto + " <span class=\"grid-estado-chip is-advertencia\">"
                 + "<i class=\"mdi mdi-alert-outline\"></i>sin pasos</span>";

        return texto + " <span class=\"sigma-inv-vacio\">· "
             + (a.procedimiento_pasos == 1 ? "1 paso" : a.procedimiento_pasos + " pasos") + "</span>";
    }

    private string CeldaDuracion(PlanActividad a)
    {
        if (a.paa_duracion_estimada_minuto == null)
            return "<span class=\"sigma-inv-vacio\">—</span>";

        int minutos = a.paa_duracion_estimada_minuto.Value;

        // Sobre una hora se lee mejor en horas: «3 h 30 min» y no «210 min».
        if (minutos < 60) return minutos + " min";

        int horas = minutos / 60, resto = minutos % 60;
        return resto == 0 ? horas + " h" : horas + " h " + resto + " min";
    }

    /// <summary>
    /// Lo que la actividad exige para poder hacerse. Son los tres datos que
    /// cambian la planificación: si no se puede saltar, si hay que parar el
    /// equipo y si hay que emitir un permiso antes.
    /// </summary>
    private string CeldaExige(PlanActividad a)
    {
        string chips = "";

        if (a.paa_obligatoria)
            chips += "<span class=\"grid-estado-chip is-neutro\" title=\"No deja cerrar la orden sin resultado\">"
                   + "<i class=\"mdi mdi-asterisk\"></i>obligatoria</span> ";

        if (a.paa_requiere_parada)
            chips += "<span class=\"grid-estado-chip is-advertencia\" title=\"Exige el equipo detenido\">"
                   + "<i class=\"mdi mdi-stop-circle-outline\"></i>parada</span> ";

        if (a.paa_requiere_permiso)
            chips += "<span class=\"grid-estado-chip is-error\" title=\""
                   + Server.HtmlEncode(string.IsNullOrEmpty(a.permiso_tipo_nombre) ? "Sin tipo de permiso definido" : a.permiso_tipo_nombre)
                   + "\"><i class=\"mdi mdi-shield-alert-outline\"></i>"
                   + (string.IsNullOrEmpty(a.permiso_tipo_nombre) ? "permiso" : Server.HtmlEncode(a.permiso_tipo_nombre))
                   + "</span> ";

        return chips == "" ? "<span class=\"sigma-inv-vacio\">nada especial</span>" : chips;
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            /* La guarda de verdad, en el servidor: esconder la barra de
               comandos solo evita ofrecerla. Un postback armado a mano llega
               igual acá, y acá se corta. */
            if (!Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"))
            {
                Tools.tools.ClientAlert("No tiene permiso para eliminar actividades de un plan.", "alerta");
                return;
            }

            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            Respuesta respuesta = new Respuesta();
            PlanActividadController controller = new PlanActividadController();

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                PlanActividad entidad = new PlanActividad();
                entidad.paa_id = Int32.Parse(value["paa_id"].ToString());

                respuesta = controller.DeletePlanActividad(entidad);

                // El primero que rebota corta: el mensaje del SP dice cuál y
                // por qué, y seguir con el resto lo taparía.
                if (respuesta.error) break;
            }

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
