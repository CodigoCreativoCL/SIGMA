using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;

public partial class Privacidad_Privacidad : System.Web.UI.Page
{
    private PrivacidadModuloSistemaController controller = new PrivacidadModuloSistemaController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
            CargarContenido();
    }

    // ── Lógica principal ─────────────────────────────────────────────────────

    private void CargarContenido()
    {
        // Parámetro público plano: ?modulo=ControlTransporte  (sin encriptar — URL pública)
        string moduloParam = Request.QueryString["modulo"];

        if (!string.IsNullOrWhiteSpace(moduloParam))
        {
            // ── Vista MÓDULO ESPECÍFICO ─────────────────────────────────────
            string nombreModulo = moduloParam.Trim();
            PrivacidadModuloSistema item = controller.GetPrivacidadPublica(nombreModulo); 

            if (item != null && !string.IsNullOrWhiteSpace(item.pms_descripcion))
            {
                string nombreEncoded = HttpUtility.HtmlEncode(item.mds_nombre);
                string fechaTexto = (item.pms_fecha_act != DateTime.MinValue
                        ? item.pms_fecha_act
                        : item.pms_fecha_creacion)
                    .ToString("dd/MM/yyyy");
                string urlIndice = ResolveUrl("~/Privacidad/Privacidad.aspx");

                // Hero: breadcrumb + título del módulo + fecha de actualización + badge
                ltlHero.Text = string.Format(
                    "<div class=\"prv-hero-detail-row\">" +
                        "<div>" +
                            "<nav class=\"prv-breadcrumb\">" +
                                "<a href=\"{0}\">Inicio</a>" +
                                "<i class=\"fas fa-chevron-right\"></i>" +
                                "<span>{1}</span>" +
                            "</nav>" +
                            "<h1 class=\"prv-hero-title\">{1}</h1>" +
                            "<p class=\"prv-hero-meta-row\"><i class=\"fas fa-calendar-alt\"></i> Última actualización: {2}</p>" +
                        "</div>" +
                        "<div>" +
                            "<span class=\"prv-badge prv-badge-success\"><i class=\"fas fa-check-circle\"></i> Política vigente</span>" +
                        "</div>" +
                    "</div>",
                    urlIndice,
                    nombreEncoded,
                    fechaTexto
                );

                // Cuerpo: HTML del editor con tabla de contenidos lateral (si tiene encabezados)
                string tocHtml;
                string contenidoProcesado = ProcesarContenido(item.pms_descripcion, out tocHtml);

                var sb = new StringBuilder();

                if (!string.IsNullOrEmpty(tocHtml))
                {
                    sb.Append("<div class=\"prv-detail-grid\">");
                    sb.Append("<aside class=\"prv-toc\">");
                    sb.Append("<div class=\"prv-toc-label\">Contenido</div>");
                    sb.Append(tocHtml);
                    sb.Append("</aside>");
                    sb.Append("<div class=\"prv-content\">");
                }
                else
                {
                    sb.Append("<div class=\"prv-detail-grid prv-detail-grid-single\">");
                    sb.Append("<div class=\"prv-content\">");
                }

                sb.Append(contenidoProcesado);

                // Llamado a la acción / contacto
                sb.Append(
                    "<div class=\"prv-callout\">" +
                        "<div class=\"prv-callout-icon\"><i class=\"fas fa-headset\"></i></div>" +
                        "<div class=\"prv-callout-text\">" +
                            "<h3>¿Tienes preguntas sobre el uso de tus datos?</h3>" +
                            "<p>Si tienes dudas sobre el tratamiento de tu información en esta aplicación, contáctanos.</p>" +
                        "</div>" +
                    "</div>"
                );

                sb.Append("</div>"); // .prv-content
                sb.Append("</div>"); // .prv-detail-grid

                // Botón volver al índice
                sb.AppendFormat(
                    "<div class=\"prv-back-wrap\">" +
                        "<a class=\"prv-back-btn\" href=\"{0}\">" +
                            "<i class=\"fas fa-arrow-left\"></i> Ver todas las aplicaciones" +
                        "</a>" +
                    "</div>",
                    urlIndice
                );

                ltlContenido.Text = sb.ToString();
            }
            else
            {
                // Módulo encontrado pero sin contenido, o no existe
                string urlIndice = ResolveUrl("~/Privacidad/Privacidad.aspx");
                string moduloEncoded = HttpUtility.HtmlEncode(moduloParam);

                ltlHero.Text = string.Format(
                    "<div class=\"prv-hero-detail-row\">" +
                        "<div>" +
                            "<nav class=\"prv-breadcrumb\">" +
                                "<a href=\"{0}\">Inicio</a>" +
                                "<i class=\"fas fa-chevron-right\"></i>" +
                                "<span>{1}</span>" +
                            "</nav>" +
                            "<h1 class=\"prv-hero-title\">Política de Privacidad</h1>" +
                            "<p class=\"prv-hero-sub\" style=\"margin:0;\">No se encontró contenido para este módulo.</p>" +
                        "</div>" +
                    "</div>",
                    urlIndice,
                    moduloEncoded
                );

                ltlContenido.Text = string.Format(
                    "<div class=\"prv-detail-grid prv-detail-grid-single\">" +
                        "<div class=\"prv-content\">" +
                            "<div class=\"prv-info\">" +
                                "<i class=\"fas fa-info-circle\"></i>" +
                                "<span>El módulo <strong>{0}</strong> aún no tiene una política de privacidad registrada.</span>" +
                            "</div>" +
                            "<div class=\"prv-back-wrap\">" +
                                "<a class=\"prv-back-btn\" href=\"{1}\">" +
                                    "<i class=\"fas fa-arrow-left\"></i> Ver todas las aplicaciones" +
                                "</a>" +
                            "</div>" +
                        "</div>" +
                    "</div>",
                    moduloEncoded,
                    urlIndice
                );
            }
        }
        else
        {
            // ── Vista ÍNDICE (lista de todas las aplicaciones) ──────────────
            List<PrivacidadModuloSistema> lista = controller.GetPrivacidadesPublicas();

            ltlHero.Text =
                "<div class=\"prv-hero-center\">" +
                    "<div class=\"prv-hero-badge\">" +
                        "<i class=\"fas fa-user-shield\"></i>Centro de Transparencia" +
                    "</div>" +
                    "<h1 class=\"prv-hero-title\">Privacidad de Aplicaciones</h1>" +
                    "<p class=\"prv-hero-sub\">" +
                        "Transparencia en el tratamiento de tus datos personales. " +
                        "Cada uno de nuestros sistemas cuenta con su propia política de privacidad, " +
                        "adaptada a los datos que procesa y a la normativa vigente." +
                    "</p>" +
                "</div>";

            var sb = new StringBuilder();

            if (lista != null && lista.Count > 0)
            {
                sb.Append(
                    "<p class=\"prv-lead\">" +
                        "Selecciona la aplicación que deseas consultar para revisar el detalle " +
                        "de cómo recopilamos, usamos y protegemos tus datos en cada plataforma." +
                    "</p>"
                );

                sb.Append("<div class=\"prv-apps-label\">Nuestras aplicaciones</div>");
                sb.Append("<div class=\"prv-app-grid\">");

                foreach (PrivacidadModuloSistema prv in lista)
                {
                    string url = string.Format(
                        "{0}?modulo={1}",
                        ResolveUrl("~/Privacidad/Privacidad.aspx"),
                        HttpUtility.UrlEncode(prv.mds_nombre)
                    );

                    string fechaTexto = (prv.pms_fecha_act != DateTime.MinValue
                            ? prv.pms_fecha_act
                            : prv.pms_fecha_creacion)
                        .ToString("dd/MM/yyyy");

                    sb.AppendFormat(
                        "<a class=\"prv-app-card\" href=\"{0}\">" +
                            "<div>" +
                                "<div class=\"prv-app-card-icon\">" +
                                    "<i class=\"fas {1}\"></i>" +
                                "</div>" +
                                "<h3 class=\"prv-app-card-title\">{2}</h3>" +
                                "<p class=\"prv-app-card-desc\">{3}</p>" +
                                "<div class=\"prv-app-card-tags\">" +
                                    "<span class=\"prv-tag\">Actualizado {4}</span>" +
                                "</div>" +
                            "</div>" +
                            "<span class=\"prv-app-card-cta\">" +
                                "Ver privacidad <i class=\"fas fa-arrow-right\"></i>" +
                            "</span>" +
                        "</a>",
                        url,
                        ObtenerIcono(prv.mds_nombre),
                        HttpUtility.HtmlEncode(prv.mds_nombre),
                        ObtenerExtracto(prv.pms_descripcion, 130),
                        fechaTexto
                    );
                }

                sb.Append("</div>");
            }
            else
            {
                sb.Append(
                    "<div class=\"prv-detail-grid prv-detail-grid-single\">" +
                        "<div class=\"prv-content\">" +
                            "<div class=\"prv-info\">" +
                                "<i class=\"fas fa-info-circle\"></i>" +
                                "<span>Aún no hay políticas de privacidad registradas en el sistema.</span>" +
                            "</div>" +
                        "</div>" +
                    "</div>"
                );
            }

            ltlContenido.Text = sb.ToString();
        }
    }

    // ── Utilidades ───────────────────────────────────────────────────────────

    /// <summary>
    /// Inyecta un id en cada h2/h3 del HTML del editor y arma la lista de enlaces
    /// para el sidebar de tabla de contenidos (TOC). Si no hay encabezados, retorna TOC vacío.
    /// </summary>
    private string ProcesarContenido(string html, out string tocHtml)
    {
        var toc = new StringBuilder();
        int contador = 0;

        string procesado = Regex.Replace(html, @"<h([23])([^>]*)>(.*?)</h\1>", match =>
        {
            string nivel = match.Groups[1].Value;
            string atributos = match.Groups[2].Value;
            string interno = match.Groups[3].Value;

            string texto = HttpUtility.HtmlDecode(Regex.Replace(interno, "<[^>]+>", "")).Trim();
            if (string.IsNullOrEmpty(texto)) return match.Value;

            contador++;
            string id = "prv-sec-" + contador;

            string cssClass = nivel == "2" ? "prv-toc-link" : "prv-toc-link prv-toc-sub";
            toc.AppendFormat(
                "<a class=\"{0}\" href=\"#{1}\">{2}</a>",
                cssClass, id, HttpUtility.HtmlEncode(texto)
            );

            return string.Format("<h{0} id=\"{1}\"{2}>{3}</h{0}>", nivel, id, atributos, interno);
        }, RegexOptions.IgnoreCase | RegexOptions.Singleline);

        tocHtml = toc.ToString();
        return procesado;
    }

    /// <summary>
    /// Extrae texto plano (sin HTML) del contenido del editor, recortado a un largo máximo.
    /// </summary>
    private string ObtenerExtracto(string html, int largoMaximo)
    {
        if (string.IsNullOrWhiteSpace(html)) return string.Empty;

        string texto = HttpUtility.HtmlDecode(Regex.Replace(html, "<[^>]+>", " "));
        texto = Regex.Replace(texto, @"\s+", " ").Trim();

        if (texto.Length > largoMaximo)
            texto = texto.Substring(0, largoMaximo).TrimEnd() + "…";

        return HttpUtility.HtmlEncode(texto);
    }

    /// <summary>
    /// Determina el ícono de FontAwesome según el nombre del módulo del sistema.
    /// </summary>
    private string ObtenerIcono(string nombreModulo)
    {
        string nombre = (nombreModulo ?? string.Empty).ToLowerInvariant();

        if (nombre.Contains("transporte")) return "fa-truck";
        if (nombre.Contains("agend")) return "fa-calendar-check";
        if (nombre.Contains("achs")) return "fa-user-md";
        if (nombre.Contains("totem") || nombre.Contains("tótem")) return "fa-tablet-alt";
        if (nombre.Contains("recep")) return "fa-door-open";
        if (nombre.Contains("qr")) return "fa-qrcode";

        return "fa-shield-alt";
    }
}
