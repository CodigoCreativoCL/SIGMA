using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;

/// <summary>
/// La ficha de UNA alerta, para abrirla desde la campana o desde la bandeja.
///
/// POR QUE UNA PANTALLA PROPIA Y NO LA FICHA DEL REGISTRO
///   Tocar una notificación llevaba a la ficha del origen —el repuesto, el
///   permiso, el medidor—, y de los quince tipos de alerta solo unos pocos la
///   tienen configurada: el resto terminaba en «no tiene registro relacionado
///   configurado», que es una puerta cerrada.
///
///   Y cuando existía tampoco alcanzaba: la ficha del repuesto dice cuántas
///   unidades hay, no que el sistema lo detectó hace tres días, que se repitió
///   doce veces, quién la tomó ni qué se decidió. Eso es la alerta, y vive acá.
///
/// SE MARCA LEÍDA AL ABRIRLA
///   Abrirla es haberla visto. No hay un botón «marcar como leída» porque
///   sería pedir dos gestos para una sola intención.
/// </summary>
public partial class View_Comun_Notificaciones_AlertaDetalle : System.Web.UI.Page
{
    private readonly AlertaController controller = new AlertaController();

    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>RESUELTA o DESCARTADA mientras se pide el motivo.</summary>
    public string Cierre
    {
        get { return ViewState["Cierre"] as string ?? ""; }
        set { ViewState["Cierre"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (IsPostBack) return;

        Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");

        /* Abrirla es haberla visto: se marca antes de dibujar para que el
           contador de la campana ya baje en esta misma vuelta. */
        if (Id > 0) controller.Leer(Id);

        Cargar();
    }

    // ------------------------------------------------------------------ carga
    protected void Cargar()
    {
        Alerta a = Buscar(Id);

        pnlFicha.Visible = (a != null);
        pnlNoExiste.Visible = (a == null);

        if (a == null) return;

        litIcono.Text = a.ES_PREDICCION
            ? "<img src=\"" + ResolveUrl("~/Imagen/sigma-ai/sigma-ai-status-prediction.svg") + "\" alt=\"\" />"
            : "<i class=\"" + IconoTipo(a.alt_icono) + "\" aria-hidden=\"true\"></i>";

        StringBuilder chips = new StringBuilder();
        chips.Append("<span class=\"sg-ald-chip is-tipo\">" + Server.HtmlEncode(a.alt_nombre) + "</span>");
        chips.Append("<span class=\"sg-ald-chip is-estado\">" + Server.HtmlEncode(a.aet_nombre) + "</span>");

        if (a.sev_codigo == "CRITICA" || a.sev_codigo == "ALTA")
            chips.Append("<span class=\"sg-ald-chip is-grave\">" + Server.HtmlEncode(a.sev_nombre) + "</span>");

        if (a.ES_PREDICCION)
            chips.Append("<span class=\"sg-ald-chip is-ai\">SIGMA AI</span>");

        litChips.Text = chips.ToString();
        litTitulo.Text = Server.HtmlEncode(a.ale_titulo);
        litDescripcion.Text = Server.HtmlEncode(a.ale_descripcion);

        List<string> donde = new List<string>();
        if (!string.IsNullOrEmpty(a.ACTIVO_CODIGO)) donde.Add(a.ACTIVO_CODIGO + " · " + a.ACTIVO_NOMBRE);
        else if (!string.IsNullOrEmpty(a.ACTIVO_NOMBRE)) donde.Add(a.ACTIVO_NOMBRE);
        if (!string.IsNullOrEmpty(a.REPUESTO_CODIGO)) donde.Add("Repuesto " + a.REPUESTO_CODIGO);
        if (!string.IsNullOrEmpty(a.BODEGA_NOMBRE)) donde.Add(a.BODEGA_NOMBRE);
        if (!string.IsNullOrEmpty(a.INSTALACION_NOMBRE)) donde.Add(a.INSTALACION_NOMBRE);

        litContexto.Text = Server.HtmlEncode(string.Join(" · ", donde.ToArray()));

        litDatos.Text = Datos(a);

        Prediccion(a);
        Imagenes(a);
        Historial(a);
        Botones(a);

        udPanel.Update();
    }

    /// <summary>
    /// Los números de la alerta. Van en pares rótulo/valor y no en un párrafo
    /// porque lo que se busca acá es comparar: cuánto hay contra cuánto
    /// debería haber.
    /// </summary>
    private string Datos(Alerta a)
    {
        StringBuilder sb = new StringBuilder();

        if (a.ale_valor_observado != null)
            sb.Append(Dato("Medido", a.ale_valor_observado.Value.ToString("N2")));

        if (a.ale_valor_umbral != null)
            sb.Append(Dato("Umbral", a.ale_valor_umbral.Value.ToString("N2")));

        sb.Append(Dato("Detectada", a.Antiguedad));

        /* Las veces que se repitió importa: una medición fuera de rango una
           vez puede ser el instrumento; quinientas veces es la máquina. */
        if (a.ale_ocurrencias > 1)
            sb.Append(Dato("Se repitió", a.ale_ocurrencias + " veces"));

        if (!string.IsNullOrEmpty(a.RESPONSABLE_NOMBRE))
            sb.Append(Dato("Responsable", a.RESPONSABLE_NOMBRE));

        return sb.ToString();
    }

    private string Dato(string rotulo, string valor)
    {
        return "<div class=\"sg-ald-dato\"><span class=\"r\">" + Server.HtmlEncode(rotulo) +
               "</span><span class=\"v\">" + Server.HtmlEncode(valor) + "</span></div>";
    }

    private void Prediccion(Alerta a)
    {
        if (!a.ES_PREDICCION) return;

        AlertaPrediccion p = controller.GetPrediccion(a.ale_id);
        if (p == null) return;

        StringBuilder sb = new StringBuilder();

        if (p.pre_probabilidad != null)
            sb.Append(Dato("Probabilidad", (p.pre_probabilidad.Value * 100).ToString("N0") + " %"));

        if (p.pre_dia_restante != null)
            sb.Append(Dato("Horizonte", p.pre_dia_restante.Value + " días"));

        if (!string.IsNullOrEmpty(p.MODELO_NOMBRE))
            sb.Append(Dato("Modelo", p.MODELO_NOMBRE +
                (string.IsNullOrEmpty(p.MODELO_VERSION) ? "" : " " + p.MODELO_VERSION)));

        litPrediccion.Text = "<div class=\"sg-ald-datos\">" + sb.ToString() + "</div>";
        pnlPrediccion.Visible = sb.Length > 0;
    }

    /// <summary>
    /// Las fotos del equipo al que apunta la alerta. No son «evidencias de la
    /// alerta» —eso todavía no existe— pero sirven para lo mismo: saber de qué
    /// máquina se está hablando sin ir a buscarla.
    /// </summary>
    private void Imagenes(Alerta a)
    {
        if (a.ale_activo == null || a.ale_activo <= 0) return;

        List<ActivoArchivo> archivos =
            new ActivoArchivoController().GetArchivos(a.ale_activo.Value, SitioBase.Session.ClienteId());

        if (archivos == null) return;

        StringBuilder sb = new StringBuilder();
        string pagina = ResolveUrl("~/View/Comun/Archivos/VerArchivo.aspx");

        foreach (ActivoArchivo f in archivos)
        {
            if (!f.es_imagen) continue;

            /* El id va cifrado, como en el resto del sitio: con la ruta a la
               vista en claro cualquiera pediría otro archivo cambiando el
               número. */
            string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + f.arc_id + "&Modo=VER"));

            sb.Append("<a class=\"sg-ald-foto\" href=\"" + pagina + "?query=" + q +
                      "\" target=\"_top\" title=\"" + Server.HtmlEncode(f.arc_nombre) + "\">");
            sb.Append("<img src=\"" + pagina + "?query=" + q + "\" alt=\"" +
                      Server.HtmlEncode(f.arc_nombre) + "\" /></a>");
        }

        litImagenes.Text = sb.ToString();
        pnlImagenes.Visible = sb.Length > 0;
    }

    private void Historial(Alerta a)
    {
        List<AlertaHito> hitos = controller.GetHistorial(a.ale_id);
        if (hitos == null || hitos.Count == 0) return;

        StringBuilder sb = new StringBuilder();

        foreach (AlertaHito h in hitos)
        {
            sb.Append("<div class=\"sg-ald-hito\">");
            sb.Append("<span class=\"p\"></span>");
            sb.Append("<div><span class=\"e\">" + Server.HtmlEncode(h.EstadoHasta) + "</span>");
            sb.Append("<span class=\"f\">" + h.Fecha.ToString("dd-MM-yyyy HH:mm") +
                      (string.IsNullOrEmpty(h.Usuario) ? "" : " · " + Server.HtmlEncode(h.Usuario)) + "</span>");

            if (!string.IsNullOrEmpty(h.Motivo))
                sb.Append("<span class=\"m\">" + Server.HtmlEncode(h.Motivo) + "</span>");

            sb.Append("</div></div>");
        }

        litHistorial.Text = sb.ToString();
        pnlHistorial.Visible = true;
    }

    private void Botones(Alerta a)
    {
        /* Quién puede ver esta pantalla ya lo decidió el framework con la
           fila de Menus; acá solo manda el ESTADO de la alerta, que es la
           misma regla que usa la bandeja: una nueva se toma, una tomada se
           gestiona, y cerrarla se puede mientras siga activa. */
        btnTomar.Visible = a.PuedeReconocer;
        btnGestionar.Visible = a.PuedeGestionar;
        btnResolver.Visible = a.PuedeCerrar;
        btnDescartar.Visible = a.PuedeCerrar;

        btnGenerarOt.Visible = a.ES_PREDICCION && a.Activa &&
                               Token.PuedeFuncion("Generar orden de trabajo");

        /* El registro de origen deja de ser el destino del clic y pasa a ser
           una acción más: se abre cuando hace falta y no antes. */
        if (!string.IsNullOrEmpty(a.FICHA_LINK) && a.FICHA_ID != null && a.FICHA_ID > 0)
        {
            string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.FICHA_ID.Value));
            lnkOrigen.NavigateUrl = ResolveUrl(a.FICHA_LINK) + "?query=" + q;
            lnkOrigen.Visible = true;
        }
        else if (!string.IsNullOrEmpty(a.alt_menu_link))
        {
            lnkOrigen.NavigateUrl = ResolveUrl(a.alt_menu_link);
            lnkOrigen.Visible = true;
        }
    }

    // ---------------------------------------------------------------- acciones
    protected void btnTomar_Click(object sender, EventArgs e) { Cambiar("RECONOCIDA", null); }

    protected void btnGestionar_Click(object sender, EventArgs e) { Cambiar("EN GESTION", null); }

    protected void btnResolver_Click(object sender, EventArgs e) { PedirMotivo("RESUELTA"); }

    protected void btnDescartar_Click(object sender, EventArgs e) { PedirMotivo("DESCARTADA"); }

    /// <summary>
    /// Cerrar una alerta pide el motivo. No es burocracia: la misma alerta va
    /// a volver el mes que viene y lo primero que se pregunta es qué se hizo
    /// la vez anterior.
    /// </summary>
    private void PedirMotivo(string estado)
    {
        Cierre = estado;
        litMotivoRotulo.Text = estado == "RESUELTA"
            ? "¿Qué se hizo para resolverla?"
            : "¿Por qué se descarta?";
        txtMotivo.Text = "";
        pnlMotivo.Visible = true;
        udPanel.Update();
    }

    protected void btnCancelarMotivo_Click(object sender, EventArgs e)
    {
        Cierre = "";
        pnlMotivo.Visible = false;
        udPanel.Update();
    }

    protected void btnConfirmar_Click(object sender, EventArgs e)
    {
        if (string.IsNullOrEmpty(Cierre)) return;

        string motivo = (txtMotivo.Text ?? "").Trim();

        if (motivo.Length < 5)
        {
            Tools.tools.ClientAlert("Escriba el motivo: al menos cinco caracteres.", "alerta");
            return;
        }

        pnlMotivo.Visible = false;
        Cambiar(Cierre, motivo);
        Cierre = "";
    }

    private void Cambiar(string estado, string motivo)
    {
        Respuesta r = controller.CambiarEstado(Id, estado, motivo);

        if (r.error)
        {
            Tools.tools.ClientAlert(r.detalle, "alerta");
            return;
        }

        Cargar();
        Refrescar(r.detalle);
    }

    protected void btnGenerarOt_Click(object sender, EventArgs e)
    {
        Respuesta r = controller.GenerarOrdenTrabajo(Id);

        if (r.error)
        {
            Tools.tools.ClientAlert(r.detalle, "alerta");
            return;
        }

        Cargar();
        Refrescar(r.detalle);
    }

    /// <summary>
    /// Avisa y le pide a la pantalla de atrás que se ponga al día: la campana
    /// y la bandeja muestran esta misma alerta y quedarían mintiendo.
    /// </summary>
    private void Refrescar(string mensaje)
    {
        ScriptManager.RegisterStartupScript(this, GetType(), "sg-ald-refrescar",
            "try{ if(window.parent && window.parent.sigmaAlertas) window.parent.sigmaAlertas.refrescar(); }catch(e){}", true);

        Tools.tools.ClientAlert(string.IsNullOrEmpty(mensaje) ? "Listo." : mensaje, "ok");
    }

    // ------------------------------------------------------------------ apoyo
    /// <summary>
    /// La alerta por su id. Se busca en la misma lista que ve la persona
    /// —abiertas y últimas resueltas— para no inventar un SP nuevo por una
    /// pantalla, y porque así hereda el filtro de permiso del SP.
    /// </summary>
    private Alerta Buscar(int id)
    {
        if (id <= 0) return null;

        List<Alerta> lista = controller.GetAlertas(false, 200);
        if (lista == null) return null;

        foreach (Alerta a in lista)
            if (a.ale_id == id) return a;

        return null;
    }

    /// <summary>La clase del icono de Material del tipo, normalizada.</summary>
    protected string IconoTipo(string icono)
    {
        string v = (icono ?? "").Trim().ToLowerInvariant();

        StringBuilder limpio = new StringBuilder();
        foreach (char c in v)
            if (char.IsLetterOrDigit(c) || c == '-' || c == ' ') limpio.Append(c);

        v = limpio.ToString().Trim();

        if (v.Length == 0) return "mdi mdi-bell-outline";
        if (v.StartsWith("mdi mdi-")) return v;
        if (v.StartsWith("mdi-")) return "mdi " + v;

        return "mdi mdi-" + v;
    }
}
