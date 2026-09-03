using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// La ficha corporativa del cliente. SOLO LECTURA.
///
/// ES INFORMATIVA A PROPÓSITO
///   Este menú es el del cliente mirando su propia ficha. Editar la identidad
///   —razón social, RUT, país— es una operación de administración y vive en su
///   mantenedor, con su permiso. Un botón de editar acá ofrecería una acción
///   que esta pantalla no debería tener.
///
/// DE DÓNDE SALE EL CLIENTE
///   De la SESIÓN, que es lo que fija el selector global del Master (HU-002).
///   Antes esta pantalla traía además su propio combo: dos selectores para lo
///   mismo, sin nada que garantizara que dijeran igual.
///
/// LAS CINCO PESTAÑAS SE PINTAN TODAS
///   Y el navegador muestra una. Cambiar de pestaña es mirar otra parte de lo
///   mismo, no una consulta nueva: los datos ya vinieron todos en la misma
///   llamada al SP.
/// </summary>
public partial class View_Clientes_Cliente_Identidad : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina
        /* La página se registra en Menus como todas: sin fila que la autorice
           no se abre. No hay funciones de edición que proteger porque no hay
           edición. */
        #endregion
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        Pintar(SitioBase.Session.ClienteId());
        udPanel.Update();
    }

    #region Pintar

    private void Pintar(int idCliente)
    {
        ClienteFicha f = new ClienteController().GetFicha(idCliente);

        if (f == null)
        {
            /* Sin cliente en sesión la ficha no se inventa: se dice qué pasa
               y adónde ir. */
            litTitulo.Text = "Sin cliente seleccionado";
            pnlFicha.Visible = false;

            litMeta.Text =
                "<span class=\"sg-fc-meta-item\"><i class=\"mdi mdi-information-outline\"></i>" +
                "<span>Elija un cliente en el selector de la barra superior para ver su ficha.</span></span>";

            return;
        }

        pnlFicha.Visible = true;

        // ---------------- encabezado ----------------
        litTitulo.Text = Server.HtmlEncode(f.Titulo);

        litEstadoChip.Text = f.cli_habilitado
            ? Chip("mdi-check-circle-outline", "Habilitado", "is-ok")
            : Chip("mdi-close-circle-outline", "Deshabilitado", "is-off");

        StringBuilder meta = new StringBuilder();
        Meta(meta, "mdi-account-outline", "Cliente ID #" + f.cli_id);

        if (!string.IsNullOrEmpty(f.PAIS_NOMBRE))
            Meta(meta, "mdi-earth", f.PAIS_NOMBRE);

        if (!string.IsNullOrEmpty(f.cli_identificador))
            Meta(meta, "mdi-card-account-details-outline",
                 f.IDENTIFICADOR_ROTULO + " " + f.cli_identificador);

        litMeta.Text = meta.ToString();

        // ---------------- tarjeta principal ----------------
        if (f.cli_archivo_logo != null && f.cli_archivo_logo.Value > 0)
        {
            imgLogo.ImageUrl = SitioBase.UrlArchivo.Ver(f.cli_archivo_logo.Value);
            imgLogo.Visible = true;
            litLogoVacio.Text = "";
        }
        else
        {
            /* Sin logo se muestra la inicial, no un cuadro roto. */
            imgLogo.Visible = false;
            string inicial = string.IsNullOrEmpty(f.Titulo) ? "?" : f.Titulo.Substring(0, 1).ToUpper();
            litLogoVacio.Text = "<span class=\"sg-fc-inicial\">" + Server.HtmlEncode(inicial) + "</span>";
        }

        litNombre.Text = Server.HtmlEncode(f.Titulo);

        StringBuilder hc = new StringBuilder();
        Campo(hc, "Nombre de fantasía", f.cli_nombre_fantasia);
        Campo(hc, f.IDENTIFICADOR_ROTULO, f.cli_identificador);
        Campo(hc, "País", f.PAIS_NOMBRE);
        litHeroCampos.Text = hc.ToString();

        StringBuilder ch = new StringBuilder();
        ch.Append(f.cli_habilitado
            ? Chip("mdi-check-circle-outline", "Cliente activo", "is-ok")
            : Chip("mdi-close-circle-outline", "Cliente inactivo", "is-off"));

        if (!string.IsNullOrEmpty(f.IDIOMA_NOMBRE))
            ch.Append(Chip("mdi-web", f.IDIOMA_NOMBRE, "is-info"));

        if (!string.IsNullOrEmpty(f.MONEDA_NOMBRE))
            ch.Append(Chip("mdi-currency-usd", f.MONEDA_NOMBRE, "is-info"));

        litChips.Text = ch.ToString();

        // ---------------- las tres cifras ----------------
        StringBuilder ci = new StringBuilder();

        Cifra(ci, "mdi-account-group-outline", f.USUARIOS.ToString(),
              f.USUARIOS == 1 ? "usuario" : "usuarios");

        Cifra(ci, "mdi-map-marker-outline", f.INSTALACIONES.ToString(),
              f.INSTALACIONES == 1 ? "instalación" : "instalaciones");

        Cifra(ci, "mdi-cog-outline",
              f.CONFIGURACION_COMPLETA ? "Completa" : "Incompleta", "configuración");

        litCifras.Text = ci.ToString();

        // ---------------- las cinco pestañas ----------------
        string legal = TarjetaLegal(f);
        string regional = TarjetaRegional(f);
        string estado = TarjetaEstado(f);
        string contacto = TarjetaContacto();
        string comercial = TarjetaComercial();
        string metadatos = TarjetaMetadatos(f);

        litResumenIzq.Text = legal + contacto;
        litResumenDer.Text = regional + estado;

        litLegal.Text = legal;
        litLegalDer.Text = estado;

        litContacto.Text = contacto;
        litComercial.Text = comercial;

        litRegional.Text = regional;
        litEstado.Text = estado;

        litAuditoria.Text = TarjetaAuditoria(f);

        /* El lateral se repite en las cinco: es el que dice de qué cliente se
           está hablando, y esconderlo al cambiar de pestaña obligaría a
           volver para acordarse. */
        litLateral.Text = metadatos;
        litLateral2.Text = metadatos;
        litLateral3.Text = metadatos;
        litLateral4.Text = metadatos;
        litLateral5.Text = metadatos;
    }

    #endregion

    #region Tarjetas

    private string TarjetaLegal(ClienteFicha f)
    {
        StringBuilder b = new StringBuilder();
        b.Append(CabTarjeta("mdi-bank-outline", "Identidad y datos legales"));
        b.Append("<div class=\"sg-fc-rejilla\">");
        Dato(b, "Razón social", f.cli_razon_social);
        Dato(b, "Nombre de fantasía", f.cli_nombre_fantasia);
        Dato(b, f.IDENTIFICADOR_ROTULO, f.cli_identificador);
        Dato(b, "País", f.PAIS_NOMBRE);
        Dato(b, "ID del cliente", "#" + f.cli_id);
        b.Append("</div></div>");
        return b.ToString();
    }

    private string TarjetaRegional(ClienteFicha f)
    {
        StringBuilder b = new StringBuilder();
        b.Append(CabTarjeta("mdi-cog-outline", "Configuración regional"));
        b.Append("<div class=\"sg-fc-lista\">");
        Renglon(b, "mdi-clock-outline", "Zona horaria", f.ZONA_HORARIA_NOMBRE);
        Renglon(b, "mdi-web", "Idioma", f.IDIOMA_NOMBRE);
        Renglon(b, "mdi-currency-usd", "Moneda", f.MONEDA_NOMBRE);
        b.Append("</div>");

        /* Si falta algo se dice CUÁL. Un "incompleta" a secas obliga a
           revisar las tres para encontrar la que falta. */
        b.Append(f.CONFIGURACION_COMPLETA
            ? Nota("mdi-information-outline",
                   "Esta configuración define fechas, formatos e identificadores del cliente.", "")
            : Nota("mdi-alert-outline",
                   "Falta definir " + Server.HtmlEncode(f.FaltaTexto) +
                   ". Sin eso, las fechas y los montos se muestran con el formato por omisión.",
                   "is-alerta"));

        b.Append("</div>");
        return b.ToString();
    }

    private string TarjetaEstado(ClienteFicha f)
    {
        StringBuilder b = new StringBuilder();
        b.Append(CabTarjeta("mdi-shield-outline", "Estado y operación"));

        b.Append(f.cli_habilitado
            ? Aviso("mdi-check-circle", "Cliente habilitado",
                    "Los usuarios asociados pueden acceder y operar según sus permisos.", "is-ok")
            : Aviso("mdi-close-circle", "Cliente deshabilitado",
                    "Sus usuarios no pueden acceder al sistema ni a sus operaciones.", "is-off"));

        b.Append("</div>");
        return b.ToString();
    }

    /// <summary>
    /// Los contactos del cliente.
    ///
    /// Ya existen de verdad: `Cliente_Contacto` (bloque 124). El principal va
    /// primero y marcado, porque es el que usaría cualquier aviso automático
    /// y el que se busca en la mayoría de los casos.
    ///
    /// Esta ficha es de CONSULTA: no lleva botón de agregar. Los contactos se
    /// mantienen desde el mantenedor de clientes, con su permiso.
    /// </summary>
    private string TarjetaContacto()
    {
        StringBuilder b = new StringBuilder();
        b.Append(CabTarjeta("mdi-card-account-mail-outline", "Información de contacto"));

        List<ClienteContacto> contactos = new ClienteContactoController().GetContactos();

        if (contactos == null || contactos.Count == 0)
        {
            b.Append("<div class=\"sg-fc-vacio\">");
            b.Append("<i class=\"mdi mdi-account-box-outline\"></i>");
            b.Append("<div><strong>Sin contacto configurado.</strong> ");
            b.Append("Agregue uno desde el mantenedor de clientes para centralizar ");
            b.Append("las comunicaciones operacionales.</div>");
            b.Append("</div></div>");
            return b.ToString();
        }

        b.Append("<div class=\"sg-fc-contactos\">");

        foreach (ClienteContacto c in contactos)
        {
            b.Append("<div class=\"sg-fc-contacto\">");

            /* El color del avatar sale del id, no del nombre: sumar letras
               hace que dos personas distintas caigan en el mismo tono. */
            b.Append("<span class=\"sg-fc-avatar\" style=\"background-color:" +
                     ColorDe(c.ccn_id) + ";\">" +
                     Server.HtmlEncode(c.Iniciales) + "</span>");

            b.Append("<span class=\"sg-fc-contacto-txt\">");

            b.Append("<span class=\"sg-fc-contacto-nombre\">" +
                     Server.HtmlEncode(c.ccn_nombre));

            if (c.ccn_principal)
                b.Append("<span class=\"sg-fc-principal\">Principal</span>");

            b.Append("</span>");

            if (!string.IsNullOrEmpty(c.ccn_cargo))
                b.Append("<span class=\"sg-fc-contacto-cargo\">" +
                         Server.HtmlEncode(c.ccn_cargo) + "</span>");

            /* El correo y el teléfono como enlaces: copiarlos a mano para
               pegarlos en el cliente de correo es un paso que no hace falta. */
            b.Append("<span class=\"sg-fc-contacto-vias\">");

            if (!string.IsNullOrEmpty(c.ccn_email))
                b.Append("<a href=\"mailto:" + Server.HtmlEncode(c.ccn_email) + "\">" +
                         "<i class=\"mdi mdi-email-outline\"></i>" +
                         Server.HtmlEncode(c.ccn_email) + "</a>");

            if (!string.IsNullOrEmpty(c.ccn_telefono))
                b.Append("<a href=\"tel:" + Server.HtmlEncode(c.ccn_telefono.Replace(" ", "")) + "\">" +
                         "<i class=\"mdi mdi-phone-outline\"></i>" +
                         Server.HtmlEncode(c.ccn_telefono) + "</a>");

            b.Append("</span></span></div>");
        }

        b.Append("</div></div>");
        return b.ToString();
    }

    /// <summary>
    /// Los mismos doce colores que usan los avatares de programaciones: una
    /// persona tiene que verse igual en todo el sistema.
    /// </summary>
    private static readonly string[] PALETA = {
        "#6C5CFF", "#0EA5E9", "#10B981", "#F59E0B",
        "#EF4444", "#8B5CF6", "#EC4899", "#14B8A6",
        "#F97316", "#3B82F6", "#84CC16", "#A855F7"
    };

    private static string ColorDe(int id)
    {
        if (id < 0) return PALETA[0];
        return PALETA[id % PALETA.Length];
    }

    /// <summary>Los datos comerciales. Mismo caso que el contacto.</summary>
    private string TarjetaComercial()
    {
        StringBuilder b = new StringBuilder();
        b.Append(CabTarjeta("mdi-cash-multiple", "Información comercial"));
        b.Append("<div class=\"sg-fc-vacio\">");
        b.Append("<i class=\"mdi mdi-file-document-outline\"></i>");
        b.Append("<div><strong>Sin datos comerciales.</strong> ");
        b.Append("El modelo de datos todavía no guarda condiciones comerciales del cliente.</div>");
        b.Append("</div></div>");
        return b.ToString();
    }

    /// <summary>
    /// La auditoría.
    ///
    /// Es quién CREÓ el registro y quién lo tocó por última vez. NO es un
    /// historial de cambios: no existe `Cliente_Historial` y nadie está
    /// guardando el detalle. Se dice, para que nadie lo dé por hecho.
    /// </summary>
    private string TarjetaAuditoria(ClienteFicha f)
    {
        StringBuilder b = new StringBuilder();
        b.Append(CabTarjeta("mdi-shield-check-outline", "Auditoría"));
        b.Append("<div class=\"sg-fc-rejilla\">");

        Dato(b, "Creado por", f.USUARIO_CREACION_NOMBRE);
        Dato(b, "Fecha de creación", Fecha(f.cli_fecha_creacion));
        Dato(b, "Última modificación por", f.USUARIO_ACTUALIZACION_NOMBRE);
        Dato(b, "Fecha de modificación", Fecha(f.cli_fecha_actualizacion));

        b.Append("</div>");

        b.Append(Nota("mdi-information-outline",
                      "Se registra quién creó la ficha y quién la modificó por última vez. " +
                      "El detalle de cada cambio no se está guardando.", ""));

        b.Append("</div>");
        return b.ToString();
    }

    private string TarjetaMetadatos(ClienteFicha f)
    {
        StringBuilder b = new StringBuilder();
        b.Append(CabTarjeta("mdi-information-outline", "Metadatos"));
        b.Append("<div class=\"sg-fc-lista\">");
        Renglon(b, "mdi-pound", "ID del cliente", "#" + f.cli_id);
        Renglon(b, f.cli_habilitado ? "mdi-circle" : "mdi-circle-outline", "Estado",
                f.cli_habilitado ? "Habilitado" : "Deshabilitado");
        Renglon(b, "mdi-account-group-outline", "Usuarios", f.USUARIOS.ToString());
        Renglon(b, "mdi-map-marker-outline", "Instalaciones", f.INSTALACIONES.ToString());
        b.Append("</div>");

        b.Append(Nota("mdi-eye-outline",
                      "Esta ficha es de consulta. Los datos de identidad se modifican " +
                      "desde el mantenedor de clientes.", ""));

        b.Append("</div>");
        return b.ToString();
    }

    #endregion

    #region Piezas

    private static string CabTarjeta(string icono, string titulo)
    {
        return "<div class=\"sg-fc-tarjeta\"><div class=\"sg-fc-tarjeta-cab\">" +
               "<i class=\"mdi " + icono + "\"></i><span>" + titulo + "</span></div>";
    }

    private static string Chip(string icono, string texto, string clase)
    {
        return "<span class=\"sg-fc-chip " + clase + "\">" +
               "<i class=\"mdi " + icono + "\"></i><span>" + texto + "</span></span>";
    }

    private static void Meta(StringBuilder b, string icono, string texto)
    {
        if (b.Length > 0) b.Append("<span class=\"sg-fc-punto\">·</span>");

        b.Append("<span class=\"sg-fc-meta-item\"><i class=\"mdi " + icono + "\"></i>" +
                 "<span>" + texto + "</span></span>");
    }

    private void Campo(StringBuilder b, string rotulo, string valor)
    {
        if (string.IsNullOrEmpty(valor)) return;

        b.Append("<div class=\"sg-fc-campo\"><span class=\"r\">" + Server.HtmlEncode(rotulo) +
                 "</span><span class=\"v\">" + Server.HtmlEncode(valor) + "</span></div>");
    }

    private static void Cifra(StringBuilder b, string icono, string valor, string rotulo)
    {
        b.Append("<div class=\"sg-fc-cifra\"><i class=\"mdi " + icono + "\"></i>" +
                 "<span class=\"n\">" + valor + "</span>" +
                 "<span class=\"r\">" + rotulo + "</span></div>");
    }

    /// <summary>
    /// Un dato de consulta. Si no hay valor lo dice: dejar el hueco en blanco
    /// hace dudar de si falta el dato o si falló la carga.
    /// </summary>
    private void Dato(StringBuilder b, string rotulo, string valor)
    {
        b.Append("<div class=\"sg-fc-dato\">");
        b.Append("<span class=\"sg-fc-rotulo\">" + Server.HtmlEncode(rotulo) + "</span>");

        b.Append(string.IsNullOrEmpty(valor)
            ? "<span class=\"sg-fc-valor is-vacio\">No informado</span>"
            : "<span class=\"sg-fc-valor\">" + Server.HtmlEncode(valor) + "</span>");

        b.Append("</div>");
    }

    private void Renglon(StringBuilder b, string icono, string rotulo, string valor)
    {
        b.Append("<div class=\"sg-fc-renglon\"><i class=\"mdi " + icono + "\"></i>");
        b.Append("<span class=\"sg-fc-renglon-txt\">");
        b.Append("<span class=\"r\">" + Server.HtmlEncode(rotulo) + "</span>");

        b.Append(string.IsNullOrEmpty(valor)
            ? "<span class=\"v is-vacio\">No informado</span>"
            : "<span class=\"v\">" + Server.HtmlEncode(valor) + "</span>");

        b.Append("</span></div>");
    }

    private static string Nota(string icono, string texto, string clase)
    {
        return "<div class=\"sg-fc-nota " + clase + "\"><i class=\"mdi " + icono + "\"></i>" +
               "<span>" + texto + "</span></div>";
    }

    private static string Aviso(string icono, string titulo, string texto, string clase)
    {
        return "<div class=\"sg-fc-aviso " + clase + "\"><i class=\"mdi " + icono + "\"></i>" +
               "<div><strong>" + titulo + "</strong><span>" + texto + "</span></div></div>";
    }

    private static string Fecha(DateTime? f)
    {
        return f != null ? f.Value.ToString("dd-MM-yyyy HH:mm") : "";
    }

    #endregion
}
