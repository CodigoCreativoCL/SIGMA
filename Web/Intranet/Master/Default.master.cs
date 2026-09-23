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

    protected void Page_PreRender(object sender, EventArgs e)
    {
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
        /* El pie del panel no llevaba a ninguna parte. La bandeja completa
           vive en su propia pantalla, agrupada por categoria. */
        lnkVerTodas.NavigateUrl = ResolveUrl("~/View/Comun/Notificaciones/Notificaciones.aspx");

        AlertaController controller = new AlertaController();
        AlertaResumen resumen = controller.GetResumen();

        /* El punto cuenta lo NO LEIDO. Sin no leidas no hay punto: un badge
           permanente deja de significar "mira esto" y pasa a ser decoracion. */
        litBadgeAlertas.Text = resumen.NoLeidas > 0
            ? "<span class=\"sigma-notification__count\" aria-hidden=\"true\">" +
              (resumen.NoLeidas > 99 ? "99+" : resumen.NoLeidas.ToString()) + "</span>"
            : "";

        lnkCampana.Attributes["aria-label"] = resumen.NoLeidas > 0
            ? resumen.NoLeidas.ToString() + " alertas sin leer"
            : "Alertas";

        /* El modificador critico solo cuando lo hay: si todo se pintara rojo,
           el rojo dejaria de querer decir algo. */
        string clase = "dropdown-toggle sigma-notification sigma-notification--light";

        /* La bandeja muestra también las últimas resueltas: una alerta leída
           no es lo mismo que una cerrada, y sin ese contexto ambos estados
           parecían desaparecer. El SP conserva el orden operacional. */
        List<Alerta> lista = controller.GetAlertas(false, 12);
        if (lista == null) lista = new List<Alerta>();

        /* La pastilla dice lo que llegó sin mirar; la línea de abajo dice si
           algo de eso pide una decisión hoy. Son dos preguntas distintas y
           por eso van separadas. */
        /* LA PREDICCION, ARRIBA

           El panel llega ordenado por fecha y una predicción de hace tres
           días quedaba en el medio de diez avisos de stock de hace una hora.
           Es la única fila que pide entender algo antes de actuar, así que
           se sube al principio: es la que se dibuja como tarjeta y la que le
           da sentido al rótulo "En tu operación" que separa el resto.

           Se mueve UNA, la más reciente. Subirlas todas volvería a ser una
           lista ordenada por tipo y no por urgencia. */
        int iPred = lista.FindIndex(x => x.ES_PREDICCION);
        if (iPred > 0)
        {
            Alerta pred = lista[iPred];
            lista.RemoveAt(iPred);
            lista.Insert(0, pred);
        }

        int sinLeer = 0;
        foreach (Alerta c in lista) if (!c.LEIDA) sinLeer++;

        litPanelNuevas.Text = sinLeer > 0
            ? "<span class=\"sg-notif-pill\">" + sinLeer +
              (sinLeer == 1 ? " nueva" : " nuevas") + "</span>"
            : "";

        int criticas = 0;
        foreach (Alerta c in lista)
            if (c.Activa && (c.sev_codigo == "CRITICA" || c.sev_codigo == "ALTA")) criticas++;

        litPanelResumen.Text = criticas > 0
            ? "<strong>" + criticas + (criticas == 1 ? " crítica requiere" : " críticas requieren") +
              "</strong> tu atención"
            : (resumen.Abiertas > 0
                ? resumen.Abiertas + (resumen.Abiertas == 1 ? " activa" : " activas") + ", nada urgente"
                : "Estás al día");

        _primeraOperacion = true;
        _aiDestacada = false;

        foreach (Alerta a in lista)
        {
            if (a.LEIDA) continue;
            if (a.sev_codigo != "CRITICA" && a.sev_codigo != "ALTA") continue;

            clase += " sigma-notification--critical";
            break;
        }

        lnkCampana.Attributes["class"] = clase;

        pnlSinAlertas.Visible = (lista.Count == 0);
        rptAlertas.Visible = (lista.Count > 0);

        lnkLeerTodo.Visible = (resumen.NoLeidas > 0);

        rptAlertas.DataSource = lista;
        rptAlertas.DataBind();
    }

    /* La primera predicción se dibuja como tarjeta y el resto de la lista va
       bajo el rótulo "En tu operación". Las dos cosas dependen de por dónde
       va la pasada del repetidor, así que el estado vive acá. */
    private bool _primeraOperacion = true;
    private bool _aiDestacada = false;

    protected void rptAlertas_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        Alerta a = (Alerta)e.Item.DataItem;

        HtmlButton enlace = (HtmlButton)e.Item.FindControl("lnkItem");
        Literal lit = (Literal)e.Item.FindControl("litItem");

        /* El id y el destino viajan como datos del boton. El clic no dispara
           el ciclo de pagina: WsAlertas marca la lectura y el modal se abre
           con el token cifrado que preparo el servidor. */
        enlace.Attributes["data-alerta-id"] = a.ale_id.ToString();

        /* Si esta vista o no, como dato de la fila: con eso el filtro del
           panel trabaja sin ir al servidor. Es la misma informacion que ya se
           usa para pintarla —la clase `is-nueva`—, pero en un atributo, que es
           lo que se puede consultar sin depender de como se vea. */
        enlace.Attributes["data-visto"] = a.LEIDA ? "1" : "0";

        /* La gravedad va en la FILA, no solo en el icono: tine el borde
           izquierdo, el halo y el rotulo. Al pasar a los SVG de marca se
           perdio esa clase y las tres alertas se veian identicas — un stock
           critico y uno sobre el maximo pedian la misma atencion. */
        string sev = Clase(a.sev_codigo);

        enlace.Attributes["class"] = "sg-notif-item " + sev +
                                     (a.LEIDA ? " is-leida" : " is-nueva") +
                                     (a.Activa ? " is-activa" : " is-resuelta") +
                                     (a.ES_PREDICCION ? " is-ai" : "");
        enlace.Attributes["aria-label"] = (a.LEIDA ? "" : "Nueva. ") +
                                           Server.HtmlEncode(a.ale_titulo) + ". " +
                                           Server.HtmlEncode(a.aet_nombre);
        enlace.Attributes["data-sg-notif-close"] = "1";

        JavaScriptSerializer js = new JavaScriptSerializer();

        /* TOCAR LA FILA ABRE LA ALERTA, NO EL REGISTRO

           Antes llevaba a la ficha del origen -el repuesto, el permiso, el
           medidor- y de los quince tipos solo unos pocos la tienen
           configurada: el resto terminaba en "esta notificación no tiene un
           registro relacionado configurado", que es una puerta cerrada.

           Ahora abre la ficha de la alerta, que existe siempre: cuenta qué se
           detectó, contra qué umbral, cuántas veces se repitió, su línea de
           tiempo y qué hacer con ella. Abrir el registro de origen queda como
           un botón adentro, para cuando haga falta. */
        string qAlerta = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.ale_id));

        enlace.Attributes["onclick"] = "return abrirNotificacion(" +
            js.Serialize(ResolveUrl("~/View/Comun/Notificaciones/AlertaDetalle.aspx")) + "," +
            js.Serialize(qAlerta) + "," + a.ale_id + ");";

        bool destacada = a.ES_PREDICCION && !_aiDestacada;
        if (destacada) _aiDestacada = true;

        enlace.Attributes["data-ai"] = a.ES_PREDICCION ? "1" : "0";
        if (destacada) enlace.Attributes["class"] += " es-destacada";

        /* El rótulo de sección, una sola vez y solo si arriba quedó la
           tarjeta de la predicción: sin ella no hay dos grupos que separar. */
        Literal sec = (Literal)e.Item.FindControl("litSeccion");
        if (!a.ES_PREDICCION && _primeraOperacion)
        {
            _primeraOperacion = false;
            if (_aiDestacada) sec.Text = "<div class=\"sg-notif-seccion\">En tu operación</div>";
        }

        StringBuilder sb = new StringBuilder();

        /* EL ICONO LO DICE EL TIPO

           Sale de Alerta_Tipo.alt_icono, que es catálogo: el día que se
           agregue una clase de alerta, su icono entra con el mismo INSERT y
           nadie tiene que tocar esta pantalla. La predicción conserva el SVG
           de SIGMA AI: es la única fila que sale de un modelo. */
        if (a.ES_PREDICCION)
        {
            sb.Append("<span class=\"icono es-ai\">");
            sb.Append("<img src=\"" + ResolveUrl("~/Imagen/sigma-ai/sigma-ai-status-prediction.svg") +
                      "\" alt=\"\" aria-hidden=\"true\" /></span>");
        }
        else
        {
            sb.Append("<span class=\"icono\"><i class=\"" + IconoTipo(a.alt_icono) +
                      "\" aria-hidden=\"true\"></i></span>");
        }

        sb.Append("<span class=\"texto\">");

        /* En la tarjeta, la marca va arriba: quien la mira tiene que saber
           que esto lo dijo un modelo antes de leer lo que dice. */
        if (destacada)
            sb.Append("<span class=\"sg-notif-marca\">SIGMA AI · " +
                      Server.HtmlEncode(a.alt_nombre) + " · " + Server.HtmlEncode(a.Antiguedad) + "</span>");

        sb.Append("<span class=\"titulo\">" + Server.HtmlEncode(a.ale_titulo) + "</span>");

        string contexto = !string.IsNullOrEmpty(a.ACTIVO_NOMBRE) ? a.ACTIVO_NOMBRE :
                          (!string.IsNullOrEmpty(a.REPUESTO_CODIGO) ? a.REPUESTO_CODIGO : "");
        string lugar = !string.IsNullOrEmpty(a.BODEGA_NOMBRE) ? a.BODEGA_NOMBRE : a.INSTALACION_NOMBRE;

        if (!string.IsNullOrEmpty(lugar))
            contexto = string.IsNullOrEmpty(contexto) ? lugar : contexto + " · " + lugar;

        if (!string.IsNullOrEmpty(contexto))
            sb.Append("<span class=\"contexto\">" + Server.HtmlEncode(contexto) + "</span>");

        if (destacada)
            sb.Append("<span class=\"detalle\">" + Server.HtmlEncode(a.ale_descripcion) + "</span>");

        /* La línea de abajo: cuándo, y la gravedad solo cuando pide decidir.
           En la tarjeta el cuándo ya está arriba, junto a la marca. */
        sb.Append("<span class=\"cuando\">");

        if (!destacada) sb.Append(Server.HtmlEncode(a.Antiguedad));

        if (a.sev_codigo == "CRITICA" || a.sev_codigo == "ALTA")
            sb.Append((destacada ? "" : " · ") + "<span class=\"sev\">" +
                      Server.HtmlEncode(a.sev_nombre) + "</span>");

        if (!a.Activa)
            sb.Append(" · " + Server.HtmlEncode(a.aet_nombre.ToLower()));

        sb.Append("</span>");

        if (destacada)
            sb.Append("<span class=\"sg-notif-cta\">" + Server.HtmlEncode(Accion(a.alt_codigo)) +
                      " <i class=\"mdi mdi-arrow-right\"></i></span>");

        sb.Append("</span>");

        if (!destacada)
            sb.Append("<span class=\"sg-notif-action\">" + Server.HtmlEncode(Accion(a.alt_codigo)) +
                      " <i class=\"mdi mdi-arrow-right\"></i></span>");

        /* El punto de "sin leer" a la derecha, como en cualquier bandeja: se
           recorre la columna de un vistazo. */
        if (!a.LEIDA) sb.Append("<span class=\"punto\"></span>");

        lit.Text = sb.ToString();
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

