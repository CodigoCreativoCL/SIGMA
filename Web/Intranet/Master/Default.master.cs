using SitioBase.Controller;
using System;
using System.Web.UI.WebControls;
using System.Web.UI.HtmlControls;
using System.Web.UI;
using SitioBase.Model;
using System.Collections.Generic;
using System.Text;
using System.Web.Script.Serialization;

public partial class Master_Default : System.Web.UI.MasterPage
{
    protected void Page_Load(object sender, EventArgs e)
    {
        CargarAlertas();

        if (!SitioBase.Token.TokenSeguridad())
        {
            Response.Redirect("~/Login.aspx");
        }

        // El permiso de la pagina sale de su propia URL contra Menus.mnu_link.
        // Por eso ninguna pagina bajo este master declara su permiso.
        SitioBase.Token.ExigirPagina();

        /* Alimentador de la UF (ANEXO F §4).
           Se llama en cada visita pero solo trabaja una vez al dia, y nunca
           lanza: si la fuente esta caida, arrastra el ultimo valor conocido
           y sigue. Va aqui porque este hosting no da SQL Agent; el dia que
           lo haya, se programa el job y esta linea se retira. */
        UfController.AsegurarValorDeHoy();

        /* Compuerta de suscripcion (ANEXO F §6.6 · HU-193).
           Va DESPUES de ExigirPagina: primero se resuelve si la persona
           puede ver esta pantalla, y recien despues si su empresa esta al
           dia. Al reves, un cliente vencido veria la pagina de renovacion
           al pedir una pantalla que igual tenia prohibida.
           No aplica a las cuentas de plataforma, que no tienen cliente. */
        SitioBase.SuscripcionAcceso.Exigir();
    }

    /* ================= SOPORTE =================
       El modulo Soporte vive en todas las paginas: «Reportar problema»,
       «? Ayuda» y la entrega de campanas. El CSS va al <head> desde aca
       (con <head runat="server"> no se pueden usar bloques <%= %> ahi). */

    protected bool SoportePuede(string permiso)
    {
        return SitioBase.Token.TokenSeguridad() && SitioBase.Token.Puede(permiso);
    }

    /// <summary>Reportar problemas: permiso y, ademas, la ticketera en el plan del cliente.</summary>
    protected bool SoporteTickets()
    {
        return SoportePuede("SOPORTE REPORTAR") && SitioBase.Controller.SoportePlan.Incluido();
    }

    protected string SoporteAsset(string ruta)
    {
        string url = ResolveUrl(ruta);
        try
        {
            string fisica = Server.MapPath(ruta);
            if (System.IO.File.Exists(fisica)) return url + "?v=" + System.IO.File.GetLastWriteTimeUtc(fisica).Ticks;
        }
        catch (Exception) { }
        return url;
    }

    /// <summary>
    /// Lo que sigma-soporte.js necesita saber de la sesion y de la pantalla,
    /// sin una consulta extra por pagina: los permisos ya estan en cache y la
    /// ruta Modulo > Submodulo > Pantalla sale del mapa de Menus en memoria.
    /// </summary>
    protected string SoporteConfig()
    {
        Dictionary<string, object> c = new Dictionary<string, object>();
        int usuario;
        int.TryParse(SitioBase.Session.UsuarioId(), out usuario);
        c["raiz"] = ResolveUrl("~/");
        c["usuario"] = usuario;
        c["nombre"] = SitioBase.Session.UsuarioNombreCompleto();
        c["clienteId"] = SitioBase.Session.ClienteId();
        c["clienteNombre"] = SitioBase.Session.ClienteNombre();
        c["permisos"] = new Dictionary<string, bool>
        {
            { "reportar", SoporteTickets() },
            { "ayuda", SoportePuede("AYUDA VER") },
            { "gestionar", SoportePuede("SOPORTE GESTIONAR") },
            { "ayudaAdmin", SoportePuede("AYUDA ADMINISTRAR") },
            { "campanas", SoportePuede("CAMPANAS ADMINISTRAR") },
            { "analitica", SoportePuede("SOPORTE ANALITICA") }
        };
        Dictionary<string, object> plan = SitioBase.Controller.SoportePlan.Estado();
        c["tickets"] = new Dictionary<string, object>
        {
            { "incluido", plan.ContainsKey("INCLUIDO") && Convert.ToBoolean(plan["INCLUIDO"]) },
            { "disponible", plan.ContainsKey("DISPONIBLE") && Convert.ToBoolean(plan["DISPONIBLE"]) },
            { "limite", plan.ContainsKey("LIMITE") ? plan["LIMITE"] : null },
            { "consumo", plan.ContainsKey("CONSUMO") ? plan["CONSUMO"] : 0 }
        };
        string[] ctx = SitioBase.Controller.SoporteContexto.DePagina(SitioBase.Token.PaginaActual());
        c["contexto"] = ctx == null ? null : new Dictionary<string, string> { { "modulo", ctx[0] }, { "submodulo", ctx[1] }, { "pantalla", ctx[2] } };
        /* "</" cortaria el <script> si un nombre lo trajera. */
        return new JavaScriptSerializer().Serialize(c).Replace("</", "<\\/");
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (SitioBase.Token.TokenSeguridad() && Page.Header != null)
        {
            HtmlLink css = new HtmlLink();
            css.Href = SoporteAsset("~/Css/LookAndFeel/sigma-soporte.css");
            css.Attributes["rel"] = "stylesheet";
            Page.Header.Controls.Add(css);
        }

        if (SitioBase.Token.TokenSeguridad())
        {
            PintarClienteActual();
            PintarAvisoSuscripcion();

            /* LA FOTO VIENE POR URL, NO INCRUSTADA (bloque 100).

               Antes se emitia como data:image/jpeg;base64 dentro del HTML:
               la imagen entera viajaba en CADA pagina —el avatar esta en la
               cabecera de todas— y ningun navegador podia cachearla, porque
               no era un recurso sino texto dentro del documento.

               Con la URL el navegador la pide una vez. Se sigue aceptando la
               base64 por si quedara alguna en sesion, pero ya nadie la
               escribe. */
            int idFoto = SitioBase.Session.UsuarioArchivoFoto();

            if (idFoto > 0)
            {
                string url = SitioBase.UrlArchivo.Ver(idFoto);

                this.imgUsuario.ImageUrl = url;
                this.imgUsuarioLateral.ImageUrl = url;
            }
            else if (SitioBase.Session.UsuarioFoto() != null)
            {
                string base64String = SitioBase.Session.UsuarioFoto();

                this.imgUsuario.ImageUrl = "data:image/jpeg;base64," + base64String;

                this.imgUsuarioLateral.ImageUrl = "data:image/jpeg;base64," + base64String;

            }
            else
            {
                // El .png que se referenciaba aqui no existe en Imagen/: la
                // imagen salia rota para todo usuario sin foto. Se reemplaza
                // por un marcador SVG con los grises de la paleta.
                this.imgUsuario.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.svg");
                this.imgUsuarioLateral.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.svg");
            }

        }
    }

    /// <summary>
    /// Muestra el cliente con el que se esta trabajando (HU-002).
    ///
    /// Solo se ofrece cambiar cuando la persona pertenece a mas de uno: un
    /// enlace que lleva a una lista de un solo elemento es un paso de mas.
    /// Quien no pertenece a ninguno -la cuenta de plataforma- no ve nada.
    /// </summary>
    private void PintarClienteActual()
    {
        int idCliente = SitioBase.Session.ClienteId();

        ClienteSesionController controller = new ClienteSesionController();
        System.Collections.Generic.List<SitioBase.Model.Cliente> clientes =
            controller.GetClientesElegibles(int.Parse(SitioBase.Session.UsuarioId()));

        int cuantos = clientes != null ? clientes.Count : 0;

        PintarSelectorCliente(clientes);

        if (cuantos == 0)
        {
            phCliente.Controls.Clear();
            return;
        }

        string nombre = SitioBase.Session.ClienteNombre();
        if (string.IsNullOrEmpty(nombre)) nombre = "Sin cliente";

        string html;

        if (cuantos > 1)
        {
            /* El chip abre el desplegable de acá al lado en vez de llevar a
               SeleccionarCliente.aspx: cambiar de empresa no debería costar
               salir de la pantalla en la que uno está trabajando. */
            html = "<a href=\"#\" class=\"sg-cliente-chip dropdown-toggle\" data-toggle=\"dropdown\" " +
                   "role=\"button\" aria-haspopup=\"true\" aria-expanded=\"false\" " +
                   "title=\"Cambiar de cliente\">" +
                   "<i class=\"mdi mdi-domain\"></i><span>" + Server.HtmlEncode(nombre) + "</span>" +
                   "<i class=\"mdi mdi-chevron-down\"></i></a>";

            rptClientes.DataSource = clientes;
            rptClientes.DataBind();
            pnlClientes.Visible = true;
        }
        else
        {
            html = "<span class=\"sg-cliente-chip is-fijo\">" +
                   "<i class=\"mdi mdi-domain\"></i><span>" + Server.HtmlEncode(nombre) + "</span></span>";
        }

        phCliente.Controls.Clear();
        phCliente.Controls.Add(new System.Web.UI.LiteralControl(html));
    }

    /// <summary>
    /// Cambiar de cliente desde la barra.
    ///
    /// Quién puede pasar a qué empresa lo decide el controlador contra los
    /// clientes elegibles de la persona: acá no se comprueba nada, porque una
    /// comprobación en la pantalla sería la segunda y la que se olvida.
    ///
    /// Al volver se recarga la MISMA dirección: cambiar de empresa no debería
    /// mover a nadie de donde estaba trabajando.
    /// </summary>
    protected void rptClientes_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "elegir") return;

        int idCliente;
        if (!int.TryParse(Convert.ToString(e.CommandArgument), out idCliente)) return;

        if (idCliente == SitioBase.Session.ClienteId()) return;

        ClienteSesionController controller = new ClienteSesionController();
        Respuesta r = controller.CambiarCliente(int.Parse(SitioBase.Session.UsuarioId()), idCliente);

        if (r.error)
        {
            Tools.tools.ClientAlert(r.detalle, "alerta");
            return;
        }

        Response.Redirect(Request.RawUrl, false);
        Context.ApplicationInstance.CompleteRequest();
    }


    /// <summary>
    /// El selector de empresa al entrar (HU-002 escenario 2).
    ///
    /// Se muestra cuando la persona pertenece a varias empresas y la sesion
    /// todavia no tiene ninguna: es exactamente el estado en el que queda
    /// despues de entrar, porque ResolverClienteInicial ya no fija una.
    ///
    /// Usa la lista que PintarClienteActual acaba de leer: son los mismos
    /// clientes elegibles y leerlos dos veces por pantalla seria un viaje a
    /// la base para traer lo que ya se tiene.
    /// </summary>
    private void PintarSelectorCliente(List<Cliente> clientes)
    {
        bool hayQueElegir = clientes != null && clientes.Count > 1 && SitioBase.Session.ClienteId() == 0;

        pnlSelectorCliente.Visible = hayQueElegir;
        if (!hayQueElegir) return;

        litSelcliCuantos.Text = clientes.Count.ToString();
        rptSelectorCliente.DataSource = clientes;
        rptSelectorCliente.DataBind();
    }

    /// <summary>La inicial para el avatar de la empresa.</summary>
    public static string Inicial(string nombre)
    {
        nombre = (nombre ?? "").Trim();
        return nombre.Length > 0 ? nombre.Substring(0, 1).ToUpper() : "?";
    }

    /// <summary>
    /// La segunda linea de la opcion: razon social y RUT, lo que distingue a
    /// dos empresas que se llaman parecido. Si no hay ninguno de los dos, no
    /// se escribe un separador solo.
    /// </summary>
    public static string Detalle(string razon, string identificador)
    {
        razon = (razon ?? "").Trim();
        identificador = (identificador ?? "").Trim();

        if (razon.Length > 0 && identificador.Length > 0) return razon + " \u00B7 " + identificador;
        return razon.Length > 0 ? razon : identificador;
    }

    /// <summary>
    /// Elegir la empresa desde el selector de entrada. Mismo camino que el
    /// combo de la barra: el controlador vuelve a comprobar que la persona
    /// pertenezca a la empresa, porque el id viaja por el navegador.
    /// </summary>
    protected void rptSelectorCliente_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        rptClientes_ItemCommand(source, e);
    }

    /// <summary>
    /// El aviso de "por vencer" o "en gracia" (ANEXO F §6.6).
    ///
    /// El master solo pinta: el texto y el nivel los arma
    /// SuscripcionAcceso, porque cuántos días antes se avisa es un
    /// parámetro del negocio y no una decisión de esta página.
    /// </summary>
    private void PintarAvisoSuscripcion()
    {
        string texto = SitioBase.SuscripcionAcceso.TextoAviso();

        if (string.IsNullOrEmpty(texto))
        {
            pnlAvisoSuscripcion.Visible = false;
            return;
        }

        litAvisoSuscripcion.Text = Server.HtmlEncode(texto);
        pnlAvisoSuscripcion.CssClass = "sg-aviso-suscripcion " + SitioBase.SuscripcionAcceso.NivelAviso();
        pnlAvisoSuscripcion.Visible = true;

        /* El aviso lo ve todo el cliente -que un tecnico sepa que la
           suscripcion vence en tres dias es util, se lo dice a su jefe-,
           pero el enlace solo quien puede abrir esa pantalla. Ofrecer un
           link que termina en "no tienes permiso" es peor que no ofrecerlo. */
        lnkVerSuscripcion.Visible = SitioBase.SuscripcionAcceso.PuedeRenovar();
    }

    protected void lnkCerrarSession_Click(object sender, EventArgs e)
    {
        Session.Abandon();
        Session.RemoveAll();
        SitioBase.SesionPersistente.Borrar();

        /* HU-003 escenario 1: "el boton Atras del navegador no permite
           volver a la aplicacion".

           Sin esto, cerrar sesion vacia la sesion en el servidor pero la
           pagina anterior sigue en la cache del navegador: Atras la vuelve
           a pintar con los datos del cliente a la vista. Estas cabeceras le
           dicen al navegador que no guarde nada, asi que al retroceder pide
           la pagina de nuevo y se encuentra con el login. */
        Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
        Response.Cache.SetExpires(DateTime.UtcNow.AddDays(-1));
        Response.Cache.SetNoStore();

        Response.Redirect("~/Login.aspx");
    }

    /// <summary>
    /// La campana y la bandeja.
    ///
    /// SE DIBUJA EN CADA PAGINA, ASI QUE TIENE QUE SER BARATO
    ///   El resumen son dos consultas pequenas que el controlador cachea por
    ///   peticion. La bandeja -que es mas cara- solo se arma si hay algo que
    ///   mostrar: con cero alertas no se consulta la lista.
    /// </summary>
    protected void CargarAlertas()
    {
        lnkVerTodas.NavigateUrl = ResolveUrl("~/View/Comun/Notificaciones/Notificaciones.aspx");

        AlertaController controller = new AlertaController();
        AlertaResumen resumen = controller.GetResumen();

        List<Alerta> lista = controller.GetAlertas(false, 60);
        if (lista == null) lista = new List<Alerta>();

        DateTime ahora = SitioBase.Hora.Ahora;

        /* LAS FILAS SE ARMAN UNA VEZ Y DE AHI SALE TODO

           La campana, el encabezado y los chips cuentan sobre las mismas
           filas ya agrupadas: antes la campana decia 63, el encabezado 12 y
           ocho avisos de stock de una misma bodega eran ocho filas. */
        List<NpFila> filas = new List<NpFila>();
        Dictionary<string, NpFila> grupos = new Dictionary<string, NpFila>();

        foreach (Alerta a in lista)
        {
            string lugar = !string.IsNullOrEmpty(a.BODEGA_NOMBRE) ? a.BODEGA_NOMBRE : (a.INSTALACION_NOMBRE ?? "");
            string clave = a.alt_codigo + "|" + lugar;

            NpFila f;
            if (!a.ES_PREDICCION && grupos.TryGetValue(clave, out f)) { f.A.Add(a); continue; }

            f = new NpFila { Lugar = lugar };
            f.A.Add(a);
            filas.Add(f);
            if (!a.ES_PREDICCION) grupos[clave] = f;
        }

        foreach (NpFila f in filas) f.Calcular(ahora);

        int sinLeer = 0, requieren = 0;
        bool critSinLeer = false;
        foreach (NpFila f in filas)
        {
            if (f.SinLeer) sinLeer++;
            if (f.Requiere) requieren++;
            if (f.SinLeer && f.Critica) critSinLeer = true;
        }

        litBadgeAlertas.Text = sinLeer > 0
            ? "<span class=\"sigma-notification__count\" aria-hidden=\"true\">" + (sinLeer > 99 ? "99+" : sinLeer.ToString()) + "</span>"
            : "";
        lnkCampana.Attributes["aria-label"] = sinLeer > 0 ? sinLeer + " notificaciones sin leer" : "Notificaciones";
        lnkCampana.Attributes["class"] = "dropdown-toggle sigma-notification sigma-notification--light" + (critSinLeer ? " sigma-notification--critical" : "");

        litPanelNuevas.Text = "";
        litPanelResumen.Text = (requieren == 0 && sinLeer == 0)
            ? "Estás al día"
            : "<strong data-np-n-req>" + requieren + " requieren acción</strong> · <span data-np-n-sin>" + sinLeer + " sin leer</span>";

        pnlSinAlertas.Visible = (filas.Count == 0);
        lnkLeerTodo.Visible = (sinLeer > 0);

        /* Chips: Todas · Requieren acción · Sin leer y solo los tipos que
           tienen algo. Se ocultan los filtros en cero. */
        StringBuilder chips = new StringBuilder();
        chips.Append(Chip("", "Todas", filas.Count));
        chips.Append(Chip("req", "Requieren acción", requieren));
        chips.Append(Chip("0", "Sin leer", sinLeer));

        string[] cats = { "ai", "stock", "ordenes", "soporte", "medidores", "permisos" };
        string[] catNom = { "SIGMA AI", "Stock", "Órdenes", "Soporte", "Medidores", "Permisos" };
        for (int i = 0; i < cats.Length; i++)
        {
            int n = 0;
            foreach (NpFila f in filas) if (f.Cat == cats[i]) n++;
            if (n > 0) chips.Append(Chip(cats[i], catNom[i], n));
        }
        litPanelChips.Text = chips.ToString();

        /* El cuerpo: la tarjeta de SIGMA AI arriba y el resto por fecha. */
        StringBuilder sb = new StringBuilder();

        NpFila ai = filas.Find(x => x.Prediccion);
        if (ai != null) sb.Append(HtmlAi(ai));

        string seccion = null;
        foreach (NpFila f in filas)
        {
            if (f == ai) continue;
            if (f.Seccion != seccion)
            {
                seccion = f.Seccion;
                sb.Append("<div class=\"np-sec\">" + Server.HtmlEncode(seccion) + "</div>");
            }
            sb.Append(f.A.Count > 1 ? HtmlGrupo(f) : HtmlFila(f.A[0], f));
        }
        litPanelCuerpo.Text = sb.ToString();

        int semana = 0;
        foreach (Alerta a in lista) if (a.MINUTOS <= 7 * 24 * 60) semana++;
        litPanelPie.Text = "<span class=\"np-pie-n\">" + semana + (semana == 1 ? " notificación" : " notificaciones") + " en los últimos 7 días</span>";
    }

    /* Una fila del panel: una alerta suelta o un grupo (mismo tipo y mismo lugar). */
    private class NpFila
    {
        public List<Alerta> A = new List<Alerta>();
        public string Lugar;
        public bool SinLeer, Critica, Requiere, Prediccion;
        public string Cat, Seccion;
        public DateTime Fecha;

        public void Calcular(DateTime ahora)
        {
            Alerta p = A[0];
            Prediccion = p.ES_PREDICCION;
            int min = int.MaxValue;
            foreach (Alerta a in A)
            {
                if (!a.LEIDA) SinLeer = true;
                if (a.Activa && (a.sev_codigo == "CRITICA" || a.sev_codigo == "ALTA")) Requiere = true;
                if (a.Activa && a.sev_codigo == "CRITICA") Critica = true;
                if (a.MINUTOS < min) min = a.MINUTOS;
            }
            Fecha = ahora.AddMinutes(-min);

            DateTime hoy = ahora.Date;
            Seccion = Fecha.Date >= hoy ? "Hoy" : (Fecha.Date >= hoy.AddDays(-1) ? "Ayer" : (Fecha.Date >= hoy.AddDays(-7) ? "Esta semana" : "Antes"));

            string cod = p.alt_codigo ?? "";
            switch (cod)
            {
                case "STOCK MINIMO": case "STOCK MAXIMO": case "LOTE VENCIDO": case "LOTE POR VENCER": Cat = "stock"; break;
                case "MEDICION FUERA RANGO": case "LECTURA A REVISAR": case "MEDIDOR SIN LECTURA": case "MEDIDOR PROXIMO MANTENIMIENTO": Cat = "medidores"; break;
                case "PERMISO VENCIDO": case "CERTIFICACION POR VENCER": Cat = "permisos"; break;
                case "OCURRENCIA VENCIDA": case "HALLAZGO CRITICO": case "COMPARTIDO": Cat = "ordenes"; break;
                default: Cat = (cod.StartsWith("TICKET") || cod.StartsWith("SOPORTE") || cod == "CAMPANA") ? "soporte" : "otros"; break;
            }
            if (Prediccion) Cat = "ai";
        }
    }

    private string Chip(string valor, string texto, int n)
    {
        return "<button type=\"button\" class=\"np-chip" + (valor == "" ? " is-activo" : "") + (n == 0 ? " is-vacia" : "") + "\" data-np-filtro=\"" + valor +
               "\" aria-pressed=\"" + (valor == "" ? "true" : "false") + "\">" + Server.HtmlEncode(texto) + " <b>" + n + "</b></button>";
    }

    /// <summary>La hora relativa a la sección: 06:00 · Ayer 18:00 · sáb 3.</summary>
    private string Cuando(NpFila f)
    {
        if (f.Seccion == "Hoy") return f.Fecha.ToString("HH:mm");
        if (f.Seccion == "Ayer") return "Ayer " + f.Fecha.ToString("HH:mm");
        string[] dias = { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" };
        return dias[(int)f.Fecha.DayOfWeek] + " " + f.Fecha.Day;
    }

    /// <summary>«CODIGO · Nombre» del repuesto o del activo de la alerta (lo que se nombra, siempre con su código).</summary>
    private static string ItemTexto(Alerta a)
    {
        string cod = !string.IsNullOrEmpty(a.REPUESTO_CODIGO) ? a.REPUESTO_CODIGO : (a.ACTIVO_CODIGO ?? "");
        string nom = !string.IsNullOrEmpty(a.REPUESTO_CODIGO) ? (a.REPUESTO_NOMBRE ?? "") : (a.ACTIVO_NOMBRE ?? "");
        if (cod == "") return nom;
        return nom == "" || nom == cod ? cod : cod + " · " + nom;
    }

    private string Etiqueta(Alerta a)
    {
        if (a.sev_codigo == "CRITICA") return "<span class=\"np-sev crit\">Crítica</span>";
        if (a.sev_codigo == "ALTA") return "<span class=\"np-sev alta\">Alta</span>";
        return "";
    }

    private string IcoTono(Alerta a)
    {
        switch (a.alt_codigo)
        {
            case "STOCK MINIMO": case "STOCK MAXIMO": case "LOTE VENCIDO": case "LOTE POR VENCER": return "t-stock";
            case "PERMISO VENCIDO": case "CERTIFICACION POR VENCER": return "t-perm";
            case "MEDICION FUERA RANGO": case "LECTURA A REVISAR": case "MEDIDOR SIN LECTURA": case "MEDIDOR PROXIMO MANTENIMIENTO": return "t-med";
            case "PREDICCION RIESGO": return "t-ai";
        }
        return "t-gen";
    }

    private string AbrirAttrs(Alerta a)
    {
        return " data-np-url=\"" + Server.HtmlEncode(ResolveUrl("~/View/Comun/Notificaciones/AlertaDetalle.aspx")) + "\" data-np-q=\"" +
               Server.HtmlEncode(Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.ale_id))) + "\" data-np-id=\"" + a.ale_id + "\"";
    }

    private string Acciones(string ids, string tipo)
    {
        return "<span class=\"np-acts\"><button type=\"button\" class=\"np-ib\" data-np-leer=\"" + ids + "\" title=\"Marcar leída\" aria-label=\"Marcar leída\"><i class=\"mdi mdi-check\"></i></button>" +
               "<button type=\"button\" class=\"np-ib\" data-np-silenciar=\"" + Server.HtmlEncode(tipo) + "\" title=\"Silenciar este tipo por 24 h\" aria-label=\"Silenciar este tipo por 24 horas\"><i class=\"mdi mdi-bell-off-outline\"></i></button></span>";
    }

    private string HtmlFila(Alerta a, NpFila f)
    {
        string contexto = ItemTexto(a);
        if (!string.IsNullOrEmpty(f.Lugar)) contexto = string.IsNullOrEmpty(contexto) ? f.Lugar : contexto + " · " + f.Lugar;

        StringBuilder sb = new StringBuilder();
        sb.Append("<div class=\"np-row" + (a.LEIDA ? " is-leida" : " is-nueva") + "\" role=\"button\" tabindex=\"0\" data-np-row data-np-abre data-ids=\"" + a.ale_id + "\" data-tipo=\"" + Server.HtmlEncode(a.alt_codigo) + "\" data-tn=\"" + Server.HtmlEncode(a.alt_nombre) +
                  "\" data-visto=\"" + (a.LEIDA ? "1" : "0") + "\" data-req=\"" + (f.Requiere ? "1" : "0") + "\" data-cat=\"" + f.Cat + "\"" + AbrirAttrs(a) +
                  " aria-label=\"" + (a.LEIDA ? "" : "Sin leer. ") + Server.HtmlEncode(a.ale_titulo) + "\">");
        sb.Append("<span class=\"np-ico " + IcoTono(a) + "\"><i class=\"" + IconoTipo(a.alt_icono) + "\" aria-hidden=\"true\"></i></span>");
        sb.Append("<span class=\"np-tx\"><b>" + Server.HtmlEncode(a.ale_titulo) + "</b>");
        if (contexto != "") sb.Append("<small>" + Server.HtmlEncode(contexto) + "</small>");
        sb.Append("<span class=\"np-meta\"><time>" + Cuando(f) + "</time>" + Etiqueta(a) + (a.Activa ? "" : "<em>" + Server.HtmlEncode((a.aet_nombre ?? "").ToLower()) + "</em>") + "<span class=\"np-go\">" + Server.HtmlEncode(Accion(a.alt_codigo)) + " <i class=\"mdi mdi-arrow-right\"></i></span></span></span>");
        sb.Append(Acciones(a.ale_id.ToString(), a.alt_codigo));
        sb.Append(a.LEIDA ? "" : "<i class=\"np-dot\" aria-hidden=\"true\"></i>");
        sb.Append("</div>");
        return sb.ToString();
    }

    private string HtmlGrupo(NpFila f)
    {
        Alerta p = f.A[0];
        bool stock = p.alt_codigo == "STOCK MINIMO" || p.alt_codigo == "STOCK MAXIMO";
        int n = f.A.Count;

        string ids = "";
        foreach (Alerta a in f.A) ids += (ids == "" ? "" : ",") + a.ale_id;

        string titulo = p.alt_codigo == "STOCK MINIMO" ? n + " repuestos bajo el mínimo"
                      : p.alt_codigo == "STOCK MAXIMO" ? n + " repuestos sobre el máximo"
                      : n + " avisos de " + (p.alt_nombre ?? "").ToLower();

        /* El más grave del grupo: el que está más lejos de su umbral. */
        Alerta peor = p;
        double peorR = double.MaxValue;
        foreach (Alerta a in f.A)
        {
            if (a.ale_valor_observado == null || a.ale_valor_umbral == null || a.ale_valor_umbral == 0) continue;
            double r = (double)a.ale_valor_observado.Value / (double)a.ale_valor_umbral.Value;
            if (p.alt_codigo == "STOCK MAXIMO") r = -r;
            if (r < peorR) { peorR = r; peor = a; }
        }
        string detalle = f.Lugar;
        if (stock && peor.ale_valor_observado != null && peor.ale_valor_umbral != null)
            detalle += (detalle == "" ? "" : " · ") + (p.alt_codigo == "STOCK MINIMO" ? "el más bajo: " : "el más alto: ") +
                       (ItemTexto(peor) != "" ? ItemTexto(peor) : peor.ale_titulo) + " (" + Num(peor.ale_valor_observado) + " de " + Num(peor.ale_valor_umbral) + ")";

        int sin = 0; foreach (Alerta a in f.A) if (!a.LEIDA) sin++;

        StringBuilder sb = new StringBuilder();
        sb.Append("<div class=\"np-grp" + (f.SinLeer ? " is-nueva" : " is-leida") + "\" data-np-row data-np-grupo data-ids=\"" + ids + "\" data-tipo=\"" + Server.HtmlEncode(p.alt_codigo) + "\" data-tn=\"" + Server.HtmlEncode(p.alt_nombre) +
                  "\" data-visto=\"" + (f.SinLeer ? "0" : "1") + "\" data-req=\"" + (f.Requiere ? "1" : "0") + "\" data-cat=\"" + f.Cat + "\">");
        sb.Append("<div class=\"np-row np-grp-h\" role=\"button\" tabindex=\"0\" aria-expanded=\"false\" data-np-expandir>");
        sb.Append("<span class=\"np-ico " + IcoTono(p) + "\"><i class=\"" + IconoTipo(p.alt_icono) + "\" aria-hidden=\"true\"></i><span class=\"np-cant\">" + n + "</span></span>");
        sb.Append("<span class=\"np-tx\"><b>" + Server.HtmlEncode(titulo) + "</b>");
        if (detalle != "") sb.Append("<small>" + Server.HtmlEncode(detalle) + "</small>");
        sb.Append("<span class=\"np-meta\"><time>" + Cuando(f) + "</time>" + Etiqueta(peor) + "<span class=\"np-go\">" + (sin > 0 ? sin + " sin leer" : "todas leídas") + " <i class=\"mdi mdi-chevron-down np-chev\"></i></span></span></span>");
        sb.Append(Acciones(ids, p.alt_codigo));
        sb.Append(f.SinLeer ? "<i class=\"np-dot\" aria-hidden=\"true\"></i>" : "");
        sb.Append("</div>");

        sb.Append("<div class=\"np-grp-b\" hidden>");
        foreach (Alerta a in f.A)
        {
            string cod = !string.IsNullOrEmpty(a.REPUESTO_CODIGO) ? a.REPUESTO_CODIGO : (a.ACTIVO_CODIGO ?? a.ale_titulo);
            string nombre = !string.IsNullOrEmpty(a.REPUESTO_CODIGO) ? (a.REPUESTO_NOMBRE ?? "") : (a.ACTIVO_NOMBRE ?? "");
            string barra = "";
            if (stock && a.ale_valor_observado != null && a.ale_valor_umbral != null && a.ale_valor_umbral > 0)
            {
                double pc = Math.Min(100, (double)a.ale_valor_observado.Value / (double)a.ale_valor_umbral.Value * 100.0);
                barra = "<span class=\"np-bar\"><i style=\"width:" + pc.ToString("0", System.Globalization.CultureInfo.InvariantCulture) + "%\"></i></span><em>" + Num(a.ale_valor_observado) + " / " + Num(a.ale_valor_umbral) + "</em>";
            }
            sb.Append("<div class=\"np-sub" + (a.LEIDA ? " is-leida" : "") + "\" role=\"button\" tabindex=\"0\" data-np-abre data-ids=\"" + a.ale_id + "\"" + AbrirAttrs(a) + "><span class=\"np-nm\"><b>" + Server.HtmlEncode(nombre == "" ? cod : nombre) + "</b>" + (nombre == "" ? "" : "<code>" + Server.HtmlEncode(cod) + "</code>") + "</span>" + barra + (a.LEIDA ? "" : "<i class=\"np-dot\"></i>") + "</div>");
        }
        sb.Append("<div class=\"np-grp-f\">");
        if (stock)
        {
            sb.Append("<a class=\"np-btn out\" href=\"" + Server.HtmlEncode(ResolveUrl("~/View/Inventario/Existencias/Existencias.aspx")) + "\" data-np-ir=\"" + ids + "\">Ver existencias</a>");
            sb.Append("<a class=\"np-btn pri\" href=\"" + Server.HtmlEncode(ResolveUrl("~/View/Inventario/Movimientos/Movimientos.aspx")) + "\" data-np-ir=\"" + ids + "\">Registrar ingreso</a>");
        }
        else
        {
            sb.Append("<button type=\"button\" class=\"np-btn pri\" data-np-primera=\"1\">Ver detalle</button>");
        }
        sb.Append("</div></div></div>");
        return sb.ToString();
    }

    private string HtmlAi(NpFila f)
    {
        Alerta a = f.A[0];
        StringBuilder sb = new StringBuilder();
        sb.Append("<div class=\"np-ai" + (a.LEIDA ? " is-leida" : " is-nueva") + "\" data-np-row data-ids=\"" + a.ale_id + "\" data-tipo=\"" + Server.HtmlEncode(a.alt_codigo) + "\" data-tn=\"" + Server.HtmlEncode(a.alt_nombre) + "\" data-visto=\"" + (a.LEIDA ? "1" : "0") +
                  "\" data-req=\"" + (f.Requiere ? "1" : "0") + "\" data-cat=\"ai\">");
        sb.Append("<div class=\"np-ai-h\"><img src=\"" + ResolveUrl("~/Imagen/sigma-ai/sigma-ai-status-prediction.svg") + "\" alt=\"\" aria-hidden=\"true\" /><span>SIGMA AI · " +
                  Server.HtmlEncode(a.alt_nombre) + " · " + Server.HtmlEncode(a.Antiguedad) + "</span>" + (a.LEIDA ? "" : "<i class=\"np-dot\"></i>") + "</div>");
        sb.Append("<b>" + Server.HtmlEncode(a.ale_titulo) + "</b>");
        if (!string.IsNullOrEmpty(a.ale_descripcion)) sb.Append("<p>" + Server.HtmlEncode(a.ale_descripcion) + "</p>");
        sb.Append("<div class=\"np-ai-f\"><button type=\"button\" class=\"np-btn out\" data-np-abre" + AbrirAttrs(a) + ">Ver análisis</button>");
        sb.Append("<button type=\"button\" class=\"np-btn pri\" data-np-crear-ot=\"" + a.ale_id + "\">Crear OT</button></div></div>");
        return sb.ToString();
    }

    private static string Num(decimal? v)
    {
        return v == null ? "—" : v.Value.ToString("0.##", new System.Globalization.CultureInfo("es-CL"));
    }

    /// <summary>
    /// Qué se va a hacer al tocar la fila, dicho con el nombre de lo que se
    /// abre. «Revisar» a secas obliga a adivinar si lleva al repuesto, a la
    /// orden o al medidor; con el sustantivo se sabe antes de tocar.
    /// </summary>
    protected string Accion(string tipo)
    {
        switch (tipo)
        {
            case "STOCK MINIMO":
            case "STOCK MAXIMO":            return "Ver existencias";
            case "LOTE VENCIDO":
            case "LOTE POR VENCER":         return "Ver lote";
            case "MEDICION FUERA RANGO":
            case "LECTURA A REVISAR":       return "Ver medición";
            case "MEDIDOR SIN LECTURA":
            case "MEDIDOR PROXIMO MANTENIMIENTO": return "Ver medidor";
            case "PREDICCION RIESGO":       return "Revisar predicción";
            case "CERTIFICACION POR VENCER": return "Revisar certificación";
            case "PERMISO VENCIDO":         return "Ver permiso";
            case "OCURRENCIA VENCIDA":      return "Ver ocurrencia";
            case "HALLAZGO CRITICO":        return "Ver hallazgo";
            case "DESCUBRIMIENTO TERRENO":  return "Revisar registro";
            case "COMPARTIDO":              return "Ver trabajo";
        }

        return "Revisar";
    }

    /// <summary>
    /// La clase del icono de Material que le toca al tipo de alerta, tal
    /// como viene del catálogo (Alerta_Tipo.alt_icono).
    ///
    /// Se normaliza porque el catálogo tiene las dos formas: la mayoría trae
    /// «mdi mdi-gauge» y alguna quedó con el nombre pelado. Y se limpia a
    /// letras, números y guiones: es texto de una tabla y va directo al
    /// atributo class de la página.
    /// </summary>
    protected string IconoTipo(string icono)
    {
        string v = (icono ?? "").Trim().ToLowerInvariant();

        System.Text.StringBuilder limpio = new System.Text.StringBuilder();
        foreach (char c in v)
            if (char.IsLetterOrDigit(c) || c == '-' || c == ' ') limpio.Append(c);

        v = limpio.ToString().Trim();

        if (v.Length == 0) return "mdi mdi-bell-outline";
        if (v.StartsWith("mdi mdi-")) return v;
        if (v.StartsWith("mdi-")) return "mdi " + v;

        return "mdi mdi-" + v;
    }

    /// <summary>
    /// La clase de gravedad. Se traduce acá y no en el SP porque es decisión
    /// de pantalla: la app va a pintar lo mismo de otra manera.
    /// </summary>
    protected string Clase(string codigo)
    {
        switch (codigo)
        {
            case "CRITICA": return "sev-critica";
            case "ALTA": return "sev-alta";
            case "ADVERTENCIA": return "sev-advertencia";
            case "BAJA": return "sev-baja";
        }

        return "sev-normal";
    }

    /// <summary>
    /// Qué ilustración de SIGMA le corresponde a cada tipo.
    ///
    /// NO TODO ES UNA PREDICCION
    ///   El icono de predicción es para lo que SALE DE UN MODELO. Un stock bajo
    ///   el mínimo es una resta contra un umbral que alguien escribió: llamarlo
    ///   predicción le atribuiría al sistema una inteligencia que no usó, y el
    ///   día que exista una predicción de verdad nadie la distinguiría.
    ///
    ///   Lo de umbrales va con "realtime", que es lo que efectivamente es:
    ///   vigilancia continua de un valor.
    /// </summary>
    protected string IconoSigma(string tipo)
    {
        switch (tipo)
        {
            case "PREDICCION RIESGO":
                return "sigma-ai-status-prediction.svg";

            case "STOCK MINIMO":
            case "STOCK MAXIMO":
            case "MEDICION FUERA RANGO":
            case "MEDIDOR SIN LECTURA":
            case "LOTE VENCIDO":
            case "LOTE POR VENCER":
                return "sigma-ai-status-realtime.svg";

            case "MEDIDOR PROXIMO MANTENIMIENTO":
                return "sigma-ai-status-recommendation.svg";
        }

        return "sigma-ai-status-analyzing.svg";
    }

}

