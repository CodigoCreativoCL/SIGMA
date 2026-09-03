using SitioBase.Controller;
using System;
using System.Web.UI.WebControls;
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
            html = "<a href=\"" + ResolveUrl("~/SeleccionarCliente.aspx") + "\" class=\"sg-cliente-chip\" " +
                   "title=\"Cambiar de cliente\">" +
                   "<i class=\"mdi mdi-domain\"></i><span>" + Server.HtmlEncode(nombre) + "</span>" +
                   "<i class=\"mdi mdi-chevron-down\"></i></a>";
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

        litPanelResumen.Text = "<strong>" + resumen.Abiertas +
                               (resumen.Abiertas == 1 ? " activa" : " activas") + "</strong> · " +
                               resumen.NoLeidas + (resumen.NoLeidas == 1 ? " nueva" : " nuevas");

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

    protected void rptAlertas_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        Alerta a = (Alerta)e.Item.DataItem;

        LinkButton enlace = (LinkButton)e.Item.FindControl("lnkItem");
        Literal lit = (Literal)e.Item.FindControl("litItem");

        /* El id viaja en el comando: es lo unico que el evento va a recibir, y
           sacarlo del indice de la fila se rompe si la lista cambia entre el
           dibujo y el clic —que es justo lo que pasa cuando entra una alerta
           nueva mientras el panel esta abierto—. */
        enlace.CommandArgument = a.ale_id.ToString();

        /* La gravedad va en la FILA, no solo en el icono: tine el borde
           izquierdo, el halo y el rotulo. Al pasar a los SVG de marca se
           perdio esa clase y las tres alertas se veian identicas — un stock
           critico y uno sobre el maximo pedian la misma atencion. */
        string sev = Clase(a.sev_codigo);

        enlace.CssClass = "sg-notif-item " + sev +
                          (a.LEIDA ? " is-leida" : " is-nueva") +
                          (a.Activa ? " is-activa" : " is-resuelta") +
                          (a.ES_PREDICCION ? " is-ai" : "");
        enlace.Attributes["aria-label"] = (a.LEIDA ? "" : "Nueva. ") +
                                           Server.HtmlEncode(a.ale_titulo) + ". " +
                                           Server.HtmlEncode(a.aet_nombre);
        enlace.Attributes["data-sg-notif-close"] = "1";

        StringBuilder sb = new StringBuilder();

        sb.Append("<span class=\"icono\">");
        sb.Append("<img src=\"" + ResolveUrl("~/Imagen/sigma-ai/" + IconoSigma(a.alt_codigo)) +
                  "\" alt=\"\" aria-hidden=\"true\" /></span>");

        sb.Append("<span class=\"texto\">");
        sb.Append("<span class=\"titulo\">" + Server.HtmlEncode(a.ale_titulo) + "</span>");
        sb.Append("<span class=\"detalle\">" + Server.HtmlEncode(a.ale_descripcion) + "</span>");

        string contexto = !string.IsNullOrEmpty(a.ACTIVO_NOMBRE) ? a.ACTIVO_NOMBRE :
                          (!string.IsNullOrEmpty(a.REPUESTO_CODIGO) ? "Repuesto " + a.REPUESTO_CODIGO :
                           (!string.IsNullOrEmpty(a.BODEGA_NOMBRE) ? a.BODEGA_NOMBRE : a.INSTALACION_NOMBRE));
        if (!string.IsNullOrEmpty(contexto))
            sb.Append("<span class=\"contexto\"><i class=\"mdi mdi-map-marker-radius-outline\"></i>" +
                      Server.HtmlEncode(contexto) + "</span>");

        sb.Append("<span class=\"cuando\"><span>" + Server.HtmlEncode(a.Antiguedad) + "</span>");

        sb.Append("<span class=\"sg-notif-state\">" + Server.HtmlEncode(a.aet_nombre) + "</span>");

        if (!a.LEIDA) sb.Append("<span class=\"sg-notif-state is-new\">Nueva</span>");
        if (a.ES_PREDICCION) sb.Append("<span class=\"sg-notif-ai\">SIGMA AI</span>");

        /* El rotulo de gravedad SOLO cuando pide accion. Poner "Normal" en
           cada fila que no es grave llenaria la lista de una etiqueta que no
           dice nada, y de paso le quitaria peso a la que si. */
        if (a.sev_codigo == "CRITICA" || a.sev_codigo == "ALTA")
            sb.Append("<span class=\"sev\">" + Server.HtmlEncode(a.sev_nombre) + "</span>");

        sb.Append("</span><span class=\"sg-notif-action\">Revisar <i class=\"mdi mdi-arrow-right\"></i></span></span>");

        /* El punto de "sin leer" a la derecha, como en cualquier bandeja: se
           recorre la columna de un vistazo. */
        if (!a.LEIDA) sb.Append("<span class=\"punto\"></span>");

        lit.Text = sb.ToString();
    }

    /// <summary>
    /// Tocar una alerta: se marca leida y se abre su registro.
    ///
    /// EN EL SERVIDOR Y NO POR AJAX
    ///   Antes lo hacia el sondeo: el javascript le pedia al handler que la
    ///   marcara. Si esa peticion fallaba, no pasaba nada y nadie se enteraba
    ///   — el contador se quedaba igual, sin explicacion. Acá el clic va al
    ///   servidor, marca, y el panel se redibuja con lo que la base dice.
    /// </summary>
    protected void rptAlertas_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "Abrir") return;

        try
        {
            int id = 0;
            int.TryParse(Convert.ToString(e.CommandArgument), out id);

            if (id <= 0) return;

            AlertaController controller = new AlertaController();

            /* El destino se resuelve ANTES de marcar como leída. Leer no
               debería cambiar la cola, pero hacerlo en este orden evita que
               una implementación futura del SP haga desaparecer justo el
               registro que necesitamos abrir. */
            Alerta seleccionada = null;

            foreach (Alerta a in controller.GetAlertas(false, 50))
            {
                if (a.ale_id == id) { seleccionada = a; break; }
            }

            controller.Leer(id);
            CargarAlertas();
            udAlertas.Update();
            Refrescar();

            if (seleccionada != null &&
                !string.IsNullOrEmpty(seleccionada.FICHA_LINK) &&
                seleccionada.FICHA_ID != null && seleccionada.FICHA_ID > 0)
            {
                string query = Server.UrlEncode(
                    Tools.Crypto.Encrypt("Id=" + seleccionada.FICHA_ID.Value));

                /* JavaScriptSerializer genera literales JS válidos también
                   si mañana una ruta contiene comillas u otros caracteres.
                   Concatenar la ruta entre comillas simples dejaba el script
                   completo inválido en ese caso. */
                JavaScriptSerializer js = new JavaScriptSerializer();
                string abrir = "abrirNotificacion(" +
                               js.Serialize(ResolveUrl(seleccionada.FICHA_LINK)) + "," +
                               js.Serialize(query) + ");";

                ScriptManager.RegisterStartupScript(udAlertas, udAlertas.GetType(),
                    "abrir-alerta-" + id, abrir, true);
            }
            else if (seleccionada != null && !string.IsNullOrEmpty(seleccionada.alt_menu_link))
            {
                /* false evita ThreadAbortException: ese aborto caía en el
                   catch de abajo y transformaba una navegación válida en un
                   falso mensaje de error. */
                Response.Redirect(ResolveUrl(seleccionada.alt_menu_link), false);
                Context.ApplicationInstance.CompleteRequest();
                return;
            }
            else
            {
                RegistrarAvisoNotificacion(
                    "Esta notificación no tiene un registro relacionado configurado.");
            }
        }
        catch (Exception)
        {
            /* La cabecera no se cae por un fallo aislado, pero tampoco lo
               escondemos: antes el catch vacío hacía que un clic roto se
               pareciera a un elemento sin acción. */
            RegistrarAvisoNotificacion(
                "No fue posible abrir el detalle. Intenta nuevamente.");
        }
    }

    /// <summary>Muestra un error acotado sin abandonar la pantalla actual.</summary>
    protected void RegistrarAvisoNotificacion(string mensaje)
    {
        string texto = new JavaScriptSerializer().Serialize(mensaje);
        string script = "if(window.sigmaToast){" +
                        "sigmaToast('No se pudo abrir la notificación'," + texto +
                        ",'',true,'alerta-sin-destino');" +
                        "}else{window.alert(" + texto + ");}";

        ScriptManager.RegisterStartupScript(udAlertas, udAlertas.GetType(),
            "aviso-alerta-" + Guid.NewGuid().ToString("N"), script, true);
    }

    /// <summary>
    /// Le avisa al sondeo que los numeros cambiaron.
    ///
    /// El panel se redibujo con lo que la base dice, pero el javascript sigue
    /// con el ultimo valor que vio: sin esto, su proxima consulta creeria que
    /// el contador BAJO por si solo y, peor, si luego sube lo tomaria como
    /// novedad y dispararia el aviso emergente por algo que ya se leyo.
    /// </summary>
    protected void Refrescar()
    {
        ScriptManager.RegisterStartupScript(udAlertas, udAlertas.GetType(), "refrescar-alertas",
            "if(window.sigmaAlertas) sigmaAlertas.refrescar();", true);
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

    protected void lnkLeerTodo_Click(object sender, EventArgs e)
    {
        new AlertaController().Leer();

        /* Se redibuja el panel, no la pagina: recargar entera haria perder lo
           que la persona estuviera haciendo detras, y lo unico que cambio son
           el contador y los puntos. */
        CargarAlertas();
        udAlertas.Update();
        Refrescar();
    }


}

