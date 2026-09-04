using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Web.UI;

/// <summary>
/// Ficha del proveedor (HU-060, bloque 91).
///
/// EL IDENTIFICADOR NO SE LLAMA IGUAL EN LOS CINCO PAISES
///   La etiqueta sale del país del cliente —RUT en Chile, RUC en Perú, CUIT
///   en Argentina— con el mismo SEL_PAIS_IDENTIFICADOR que usa la ficha del
///   cliente. Escribir "RUT" fijo en el markup sería correcto en un país de
///   los cinco, y la validación del SP rechazaría documentos buenos sin que
///   la pantalla explicara por qué.
///
/// NO LLEVA CODIGO AUTOMATICO
///   El resto de los maestros muestra "Se genera solo al guardar: XXX-…".
///   Acá no: una empresa ya tiene un identificador único, que es su RUT, y
///   agregarle un PRV-12 sería un segundo nombre para lo mismo.
/// </summary>
public partial class View_Terceros_Proveedores_Proveedor : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /* El rotulo del identificador sale del PAIS del cliente —RUT en Chile,
       RUC en Peru, CUIT en Argentina—, asi que no puede estar escrito fijo en
       el markup. Lo resuelve EtiquetaIdentificador() y se guarda aca para que
       los pintores lo usen igual. */
    private string _rotuloRut = "Identificación";

    /* Con que esta comprometido el proveedor. Lo calcula MostrarUso() y lo
       consume el panel lateral, que se arma despues. */
    private string _dependencias = "";

    protected void Page_Load(object sender, EventArgs e)
    {
        /* Querystring.Entero recibe el valor TAL COMO VIENE de la URL:
           descifra por dentro. Pasarle el resultado de Descifrar lo hace
           descifrar dos veces, la segunda falla, y como el helper no lanza
           devuelve 0 en silencio: la ficha se abre en blanco como si fuera
           un registro nuevo. */
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        EtiquetaIdentificador();
        CargarDatos();
        Bloqueo();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    /// <summary>
    /// Cómo se llama el documento en el país del cliente.
    ///
    /// Si no se puede resolver queda "Identificación", que es neutro y
    /// correcto: es preferible a dejar el formulario sin poder usarse.
    /// </summary>
    protected void EtiquetaIdentificador()
    {
        string etiqueta = "Identificación";

        try
        {
            ClienteController ctrlCliente = new ClienteController();
            Cliente cliente = ctrlCliente.GetCliente(new Cliente { cli_id = SitioBase.Session.ClienteId() });

            if (cliente != null && cliente.cli_pais > 0)
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PAIS_IDENTIFICADOR";
                    cmd.Parameters.AddWithValue("@PAIS", cliente.cli_pais);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read()) etiqueta = dr["ETIQUETA"].ToString();
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                }
            }
        }
        catch (Exception)
        {
            // Queda la etiqueta neutra.
        }

        litRotuloRut.Text = etiqueta;
        _rotuloRut = etiqueta;
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ProveedorController controller = new ProveedorController();
            Proveedor p = controller.GetProveedor(Id);

            /* GetProveedor vuelve con un objeto vacío cuando el id no es de
               este cliente: no se muestra una ficha en blanco como si fuera
               un alta, se dice que no está y se cierra el paso. */
            if (p == null || p.prv_id == 0)
            {
                lblId.Text = "—";
                btnGuardar.Visible = false;
                Tools.tools.ClientAlert("El proveedor no existe o no pertenece a su empresa.", "alerta");
                return;
            }

            lblId.Text = p.prv_id.ToString();
            txtRut.Text = p.prv_rut;
            txtRazonSocial.Text = p.prv_razon_social;
            txtNombreFantasia.Text = p.prv_nombre_fantasia;
            txtGiro.Text = p.prv_giro;
            txtContacto.Text = p.prv_contacto;
            txtEmail.Text = p.prv_email;
            txtTelefono.Text = p.prv_telefono;
            txtDireccion.Text = p.prv_direccion;
            txtObservacion.Text = p.prv_observacion;

            chkContratista.Checked = p.prv_es_contratista;
            chkProveedorRepuesto.Checked = p.prv_es_proveedor_repuesto;

            rdbSi.Checked = p.prv_habilitado;
            rdbNo.Checked = !p.prv_habilitado;

            /* El orden importa: MostrarUso() calcula las dependencias y
               PintarFicha() las consume para armar el panel lateral. */
            MostrarUso(p);
            PintarFicha(p);

        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    /// <summary>
    /// Lo que ya se le compró o contrató.
    ///
    /// Sirve para dos cosas: saber si el proveedor está en uso antes de
    /// deshabilitarlo, y entender por qué la eliminación lo va a rechazar.
    /// </summary>
    /// <summary>
    /// Con qué está comprometido el proveedor, y qué se puede hacer con él.
    ///
    /// Los dos números salen de contar filas reales —lotes de repuesto y
    /// servicios de orden— no de suponer. De ahí sale también si el botón de
    /// eliminar se ofrece o se apaga con su motivo: uno que se ve disponible
    /// y falla siempre es peor que uno apagado que explica por qué.
    /// </summary>
    protected void MostrarUso(Proveedor p)
    {
        int total = p.lotes + p.servicios;

        StringBuilder b = new StringBuilder();

        if (total == 0)
        {
            b.Append("<div class=\"sg-fx-nota\"><i class=\"mdi mdi-information-outline\"></i>");
            b.Append("<div>Todavía no se le ha comprado ni contratado nada. Se puede eliminar.</div></div>");

            litEliminar.Text =
                "<a href=\"#\" class=\"sg-fx-menu-item is-borrar\" role=\"menuitem\" " +
                "onclick=\"return false;\"><i class=\"mdi mdi-trash-can-outline\"></i>" +
                "<span>Eliminar proveedor</span></a>";
        }
        else
        {
            StringBuilder q = new StringBuilder();

            if (p.lotes > 0)
                q.Append(p.lotes + (p.lotes == 1 ? " lote" : " lotes") + " de repuestos");

            if (p.servicios > 0)
                q.Append((q.Length > 0 ? " y " : "") +
                         p.servicios + (p.servicios == 1 ? " servicio" : " servicios"));

            b.Append("<div class=\"sg-fx-nota is-info\"><i class=\"mdi mdi-information-outline\"></i><div>");
            b.Append("Este proveedor tiene <strong>" + q + "</strong> asociado" +
                     (total == 1 ? "" : "s") + ". No puede eliminarse sin afectar su historial.");
            b.Append("</div></div>");

            /* Apagado y con el motivo escrito al lado. */
            litEliminar.Text =
                "<span class=\"sg-fx-menu-item is-off\" aria-disabled=\"true\">" +
                "<i class=\"mdi mdi-trash-can-outline\"></i><span>Eliminar proveedor" +
                "<span class=\"sg-fx-menu-motivo\">No disponible: tiene " +
                Server.HtmlEncode(q.ToString()) + "</span></span></span>";
        }

        _dependencias = b.ToString();
    }

    /// <summary>Lo que se ve arriba, en la tarjeta y en el lateral.</summary>
    protected void PintarFicha(Proveedor p)
    {
        string nombre = string.IsNullOrEmpty(p.prv_razon_social) ? "Proveedor" : p.prv_razon_social;

        litTitulo.Text = Server.HtmlEncode(nombre);
        litHeroNombre.Text = Server.HtmlEncode(nombre);

        litEstadoChip.Text = p.prv_habilitado
            ? "<span class=\"sg-fx-chip is-ok\"><i class=\"mdi mdi-check-circle-outline\"></i>Habilitado</span>"
            : "<span class=\"sg-fx-chip is-off\"><i class=\"mdi mdi-close-circle-outline\"></i>Deshabilitado</span>";

        litFantasia.Text = Server.HtmlEncode(p.prv_nombre_fantasia ?? "");
        litHeroFantasia.Text = Server.HtmlEncode(p.prv_nombre_fantasia ?? "");

        StringBuilder meta = new StringBuilder();
        meta.Append("<span class=\"sg-fx-meta-item\"><i class=\"mdi mdi-account-outline\"></i>" +
                    "<span>Proveedor ID #" + p.prv_id + "</span></span>");

        if (!string.IsNullOrEmpty(p.prv_rut))
            meta.Append("<span class=\"sg-fx-punto\">·</span>" +
                        "<span class=\"sg-fx-meta-item\"><i class=\"mdi mdi-earth\"></i>" +
                        "<span>" + Server.HtmlEncode(_rotuloRut) + " " +
                        Server.HtmlEncode(p.prv_rut) + "</span></span>");

        litMeta.Text = meta.ToString();

        /* Las iniciales sobre un color estable sacado del id: sin logo, un
           cuadro vacío no dice de quién es la ficha. */
        litAvatar.Text = "<span class=\"sg-fx-inicial\" style=\"background:" +
                         ColorDe(p.prv_id) + ";\">" +
                         Server.HtmlEncode(Iniciales(nombre)) + "</span>";

        StringBuilder hc = new StringBuilder();
        Campo(hc, "mdi-card-account-details-outline", _rotuloRut, p.prv_rut);
        Campo(hc, "mdi-briefcase-outline", "Giro", p.prv_giro);
        litHeroCampos.Text = hc.ToString();

        StringBuilder roles = new StringBuilder();

        if (p.prv_es_contratista)
            roles.Append("<span class=\"sg-fx-chip is-rol\"><i class=\"mdi mdi-check-circle-outline\"></i>Contratista</span>");

        if (p.prv_es_proveedor_repuesto)
            roles.Append("<span class=\"sg-fx-chip is-rol\"><i class=\"mdi mdi-check-circle-outline\"></i>Proveedor de repuestos</span>");

        /* Sin ningún rol se dice: un proveedor que no es ni contratista ni
           proveedor de repuestos no aparece en ninguna lista de selección, y
           eso se descubre cuando alguien lo busca y no está. */
        if (roles.Length == 0)
            roles.Append("<span class=\"sg-fx-chip is-alerta\">" +
                         "<i class=\"mdi mdi-alert-outline\"></i>Sin rol asignado</span>");

        litRoles.Text = roles.ToString();

        // ---- las tres columnas de la tarjeta ----
        StringBuilder ci = new StringBuilder();

        Cifra(ci, "mdi-account-outline",
              string.IsNullOrEmpty(p.prv_contacto) ? "No informado" : p.prv_contacto,
              "Contacto principal", string.IsNullOrEmpty(p.prv_contacto));

        Cifra(ci, "mdi-map-marker-outline",
              string.IsNullOrEmpty(p.prv_direccion) ? "No informada" : p.prv_direccion,
              "Ubicación", string.IsNullOrEmpty(p.prv_direccion));

        int total = p.lotes + p.servicios;
        Cifra(ci, "mdi-file-document-outline",
              total == 0 ? "Sin movimientos"
                         : total + (total == 1 ? " registro" : " registros"),
              "Historial", total == 0);

        litCifras.Text = ci.ToString();

        // ---- las vistas de las otras pestañas ----
        StringBuilder t = new StringBuilder();
        t.Append("<div class=\"sg-fx-rejilla\">");
        Dato(t, _rotuloRut, p.prv_rut);
        Dato(t, "Razón social", p.prv_razon_social);
        Dato(t, "Nombre de fantasía", p.prv_nombre_fantasia);
        Dato(t, "Giro", p.prv_giro);
        t.Append("</div>");
        litTributaria.Text = t.ToString();

        StringBuilder c = new StringBuilder();
        c.Append("<div class=\"sg-fx-rejilla\">");
        Dato(c, "Nombre del contacto", p.prv_contacto);
        Dato(c, "Correo electrónico", p.prv_email);
        Dato(c, "Teléfono", p.prv_telefono);
        Dato(c, "Dirección", p.prv_direccion);
        c.Append("</div>");
        litContactoVista.Text = c.ToString();

        litComercial.Text = Servicios(p);

        // ---- el aviso del estado ----
        litAvisoEstado.Text = p.prv_habilitado
            ? "<div class=\"sg-fx-nota is-alerta\"><i class=\"mdi mdi-alert-outline\"></i>" +
              "<div>Al deshabilitarlo dejará de ofrecerse, pero conservará su historial.</div></div>"
            : "<div class=\"sg-fx-nota\"><i class=\"mdi mdi-information-outline\"></i>" +
              "<div>No se ofrece para seleccionar en servicios, compras ni operaciones.</div></div>";

        // ---- el lateral ----
        StringBuilder l = new StringBuilder();

        l.Append("<div class=\"sg-fx-tarjeta\"><div class=\"sg-fx-tarjeta-cab\">");
        l.Append("<span class=\"sg-fx-num is-tenue\"><i class=\"mdi mdi-shield-outline\"></i></span>");
        l.Append("<div><div class=\"sg-fx-tarjeta-titulo\">Estado del proveedor</div></div></div>");

        l.Append(p.prv_habilitado
            ? "<div class=\"sg-fx-aviso is-ok\"><i class=\"mdi mdi-check-circle\"></i><div>" +
              "<strong>Proveedor habilitado</strong><span>Puede ser seleccionado en servicios, " +
              "compras y operaciones según sus permisos.</span></div></div>"
            : "<div class=\"sg-fx-aviso is-off\"><i class=\"mdi mdi-close-circle\"></i><div>" +
              "<strong>Proveedor deshabilitado</strong><span>No se ofrece para seleccionar en " +
              "servicios, compras ni operaciones.</span></div></div>");

        l.Append("</div>");

        l.Append("<div class=\"sg-fx-tarjeta\"><div class=\"sg-fx-tarjeta-cab\">");
        l.Append("<span class=\"sg-fx-num is-tenue\"><i class=\"mdi mdi-history\"></i></span>");
        l.Append("<div><div class=\"sg-fx-tarjeta-titulo\">Historial y dependencias</div></div></div>");
        l.Append(_dependencias + "</div>");

        l.Append("<div class=\"sg-fx-tarjeta\"><div class=\"sg-fx-tarjeta-cab\">");
        l.Append("<span class=\"sg-fx-num is-tenue\"><i class=\"mdi mdi-information-outline\"></i></span>");
        l.Append("<div><div class=\"sg-fx-tarjeta-titulo\">Metadatos</div></div></div>");
        l.Append("<div class=\"sg-fx-lista\">");
        Renglon(l, "mdi-account-outline", "Creado por", p.usuario_creacion_nombre);
        Renglon(l, "mdi-calendar-outline", "Fecha de creación", Fecha(p.prv_fecha_creacion));
        Renglon(l, "mdi-clock-outline", "Última edición", Fecha(p.prv_fecha_actualizacion));
        l.Append("</div></div>");

        litLateral.Text = l.ToString();
    }

    #region Servicios

    /// <summary>
    /// Lo que el proveedor hizo, no cuántas veces.
    ///
    /// Antes esta pestaña mostraba dos números —"1 servicio", "0 lotes"—. Un
    /// número no sirve para lo que la gente viene a hacer acá: saber qué
    /// trabajo se le encargó, cuándo, cuánto costó y con qué respaldo.
    /// </summary>
    private string Servicios(Proveedor p)
    {
        List<ProveedorServicio> lista = new ProveedorController().GetServicios(p.prv_id);

        StringBuilder b = new StringBuilder();

        // ---- el resumen de arriba ----
        b.Append("<div class=\"sg-fx-rejilla\">");
        Dato(b, "Servicios prestados", p.servicios.ToString());
        Dato(b, "Lotes de repuesto recibidos", p.lotes.ToString());
        Dato(b, "Observaciones", p.prv_observacion);
        b.Append("</div>");

        if (lista == null || lista.Count == 0)
        {
            b.Append("<div class=\"sg-fx-vacio\" style=\"margin-top:16px;\">");
            b.Append("<i class=\"mdi mdi-clipboard-text-outline\"></i>");
            b.Append("<div><strong>Sin servicios registrados.</strong> ");
            b.Append("Todavía no se le ha encargado trabajo a este proveedor.</div></div>");
            return b.ToString();
        }

        b.Append("<div class=\"sg-sv-titulo\">Servicios prestados</div>");
        b.Append("<div class=\"sg-sv-lista\">");

        foreach (ProveedorServicio x in lista)
        {
            b.Append("<div class=\"sg-sv\">");

            // ---- encabezado del servicio ----
            b.Append("<div class=\"sg-sv-cab\">");
            b.Append("<span class=\"sg-sv-ot\">" + Server.HtmlEncode(x.OT_NUMERO) + "</span>");

            if (!string.IsNullOrEmpty(x.OT_ESTADO))
                b.Append("<span class=\"sg-sv-estado\">" + Server.HtmlEncode(x.OT_ESTADO) + "</span>");

            if (x.ots_fecha_servicio_utc != null)
                b.Append("<span class=\"sg-sv-fecha\">" +
                         x.ots_fecha_servicio_utc.Value.ToString("dd-MM-yyyy") + "</span>");

            b.Append("</div>");

            if (!string.IsNullOrEmpty(x.OT_TITULO))
                b.Append("<div class=\"sg-sv-ottitulo\">" + Server.HtmlEncode(x.OT_TITULO) + "</div>");

            b.Append("<div class=\"sg-sv-desc\">" + Server.HtmlEncode(x.ots_descripcion) + "</div>");

            // ---- los datos del servicio ----
            b.Append("<div class=\"sg-sv-datos\">");
            SvDato(b, "Tipo", x.TIPO_NOMBRE);

            if (x.ots_cantidad != null)
                SvDato(b, "Cantidad", x.ots_cantidad.Value.ToString("0.##"));

            SvDato(b, "Monto", x.MontoTexto);
            SvDato(b, "Documento", x.ots_documento_referencia);

            if (x.ots_fecha_documento != null)
                SvDato(b, "Fecha documento", x.ots_fecha_documento.Value.ToString("dd-MM-yyyy"));

            b.Append("</div>");

            // ---- los adjuntos ----
            b.Append(Adjuntos(x));

            b.Append("</div>");
        }

        b.Append("</div>");
        return b.ToString();
    }

    /// <summary>
    /// Los archivos que se pueden abrir y bajar.
    ///
    /// SON DE LA ORDEN, NO DE LA LÍNEA
    ///   `Archivo_Vinculo` engancha a la orden de trabajo, no al servicio. Se
    ///   rotula así: llamarlos "adjuntos del servicio" sugeriría que alguien
    ///   los subió para esa línea, y si la OT tiene dos servicios del mismo
    ///   proveedor los dos muestran los mismos archivos.
    ///
    /// SOLO LOS LIMPIOS
    ///   El SP ya filtra por estado de antivirus. Los que quedaron fuera se
    ///   cuentan y se dicen: hacerlos desaparecer sin explicación deja a
    ///   alguien buscando un informe que sí existe.
    /// </summary>
    private string Adjuntos(ProveedorServicio x)
    {
        StringBuilder b = new StringBuilder();

        if (x.Adjuntos.Count == 0 && x.ADJUNTOS_RETENIDOS == 0)
            return "<div class=\"sg-sv-sinadj\">" +
                   "<i class=\"mdi mdi-paperclip\"></i>Sin adjuntos en esta orden.</div>";

        b.Append("<div class=\"sg-sv-adj\">");
        b.Append("<div class=\"sg-sv-adj-cab\"><i class=\"mdi mdi-paperclip\"></i>");
        b.Append("Adjuntos de la orden " + Server.HtmlEncode(x.OT_NUMERO));
        b.Append("</div>");

        foreach (ProveedorAdjunto a in x.Adjuntos)
        {
            b.Append("<div class=\"sg-sv-arch\">");
            b.Append("<i class=\"mdi " + a.Icono + "\"></i>");

            b.Append("<span class=\"sg-sv-arch-txt\">");
            b.Append("<span class=\"n\">" + Server.HtmlEncode(a.arc_nombre_original) + "</span>");

            StringBuilder pie = new StringBuilder();

            if (!string.IsNullOrEmpty(a.CATEGORIA)) pie.Append(a.CATEGORIA);
            if (!string.IsNullOrEmpty(a.TamanoTexto))
                pie.Append((pie.Length > 0 ? "  ·  " : "") + a.TamanoTexto);

            if (a.arc_fecha_creacion != null)
                pie.Append((pie.Length > 0 ? "  ·  " : "") +
                           a.arc_fecha_creacion.Value.ToString("dd-MM-yyyy"));

            b.Append("<span class=\"d\">" + Server.HtmlEncode(pie.ToString()) + "</span>");
            b.Append("</span>");

            b.Append("<span class=\"sg-sv-arch-acc\">");

            /* Ver solo cuando el visor puede mostrarlo. Un .xlsx abierto en
               el visor sale como basura binaria; ese se baja y se abre con su
               programa. */
            if (a.SeVeEnPantalla)
                b.Append("<a class=\"sg-sv-icono\" target=\"_blank\" title=\"Ver\" href=\"" +
                         SitioBase.UrlArchivo.Ver(a.arc_id) +
                         "\"><i class=\"mdi mdi-eye-outline\"></i></a>");

            b.Append("<a class=\"sg-sv-icono\" title=\"Descargar\" href=\"" +
                     SitioBase.UrlArchivo.Descargar(a.arc_id) +
                     "\"><i class=\"mdi mdi-download\"></i></a>");

            b.Append("</span></div>");
        }

        /* Los que existen pero no se ofrecen. */
        if (x.ADJUNTOS_RETENIDOS > 0)
        {
            b.Append("<div class=\"sg-sv-retenido\"><i class=\"mdi mdi-shield-alert-outline\"></i>");
            b.Append("<div>" + x.ADJUNTOS_RETENIDOS +
                     (x.ADJUNTOS_RETENIDOS == 1
                        ? " archivo no se muestra: está pendiente de revisión antivirus o fue detectado como infectado."
                        : " archivos no se muestran: están pendientes de revisión antivirus o fueron detectados como infectados."));
            b.Append("</div></div>");
        }

        b.Append("</div>");
        return b.ToString();
    }

    private void SvDato(StringBuilder b, string rotulo, string valor)
    {
        if (string.IsNullOrEmpty(valor)) return;

        b.Append("<span class=\"sg-sv-dato\">");
        b.Append("<span class=\"r\">" + Server.HtmlEncode(rotulo) + "</span>");
        b.Append("<span class=\"v\">" + Server.HtmlEncode(valor) + "</span></span>");
    }

    #endregion

    #region Piezas

    /// <summary>Los mismos doce colores del resto del sistema.</summary>
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

    private static string Iniciales(string nombre)
    {
        string[] partes = (nombre ?? "").Trim()
                          .Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);

        if (partes.Length == 0) return "?";
        if (partes.Length == 1) return partes[0].Substring(0, 1).ToUpper();

        return (partes[0].Substring(0, 1) + partes[1].Substring(0, 1)).ToUpper();
    }

    private void Campo(StringBuilder b, string icono, string rotulo, string valor)
    {
        if (string.IsNullOrEmpty(valor)) return;

        b.Append("<span class=\"sg-fx-campo\"><i class=\"mdi " + icono + "\"></i>");
        b.Append("<span class=\"r\">" + Server.HtmlEncode(rotulo) + "</span>");
        b.Append("<span class=\"v\">" + Server.HtmlEncode(valor) + "</span></span>");
    }

    private void Cifra(StringBuilder b, string icono, string valor, string rotulo, bool vacio)
    {
        b.Append("<div class=\"sg-fx-cifra\"><i class=\"mdi " + icono + "\"></i>");
        b.Append("<span class=\"n" + (vacio ? " is-vacio" : "") + "\">" +
                 Server.HtmlEncode(valor) + "</span>");
        b.Append("<span class=\"r\">" + rotulo + "</span></div>");
    }

    /// <summary>Un dato de consulta. Si falta se dice, no se deja el hueco.</summary>
    private void Dato(StringBuilder b, string rotulo, string valor)
    {
        b.Append("<div class=\"sg-fx-dato\">");
        b.Append("<span class=\"sg-fx-rotulo\">" + Server.HtmlEncode(rotulo) + "</span>");

        b.Append(string.IsNullOrEmpty(valor)
            ? "<span class=\"sg-fx-valor is-vacio\">No informado</span>"
            : "<span class=\"sg-fx-valor\">" + Server.HtmlEncode(valor) + "</span>");

        b.Append("</div>");
    }

    private void Renglon(StringBuilder b, string icono, string rotulo, string valor)
    {
        b.Append("<div class=\"sg-fx-renglon\"><i class=\"mdi " + icono + "\"></i>");
        b.Append("<span class=\"sg-fx-renglon-txt\">");
        b.Append("<span class=\"r\">" + Server.HtmlEncode(rotulo) + "</span>");

        b.Append(string.IsNullOrEmpty(valor)
            ? "<span class=\"v is-vacio\">No informado</span>"
            : "<span class=\"v\">" + Server.HtmlEncode(valor) + "</span>");

        b.Append("</span></div>");
    }

    private static string Fecha(DateTime? f)
    {
        return f != null ? f.Value.ToString("dd/MM/yyyy · HH:mm") : "";
    }

    #endregion

    /// <summary>
    /// Quien solo puede ver, ve. El bloqueo es de cortesía: la potestad la
    /// vuelve a validar el servidor al guardar.
    /// </summary>
    protected void Bloqueo()
    {
        bool puedeEditar = Token.PuedeFuncion("Crear y editar");

        txtRut.ReadOnly = !puedeEditar;
        txtRazonSocial.ReadOnly = !puedeEditar;
        txtNombreFantasia.ReadOnly = !puedeEditar;
        txtGiro.ReadOnly = !puedeEditar;
        txtContacto.ReadOnly = !puedeEditar;
        txtEmail.ReadOnly = !puedeEditar;
        txtTelefono.ReadOnly = !puedeEditar;
        txtDireccion.ReadOnly = !puedeEditar;
        txtObservacion.ReadOnly = !puedeEditar;

        chkContratista.Enabled = puedeEditar;
        chkProveedorRepuesto.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        if (!puedeEditar) btnGuardar.Visible = false;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            /* SE VALIDA ACA, EN EL SERVIDOR.
               Esconder el botón en Bloqueo() no es seguridad: quien manda el
               postback a mano se lo salta. */
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para crear o editar proveedores.");

            if (string.IsNullOrEmpty(txtRut.Text.Trim()))
                throw new Exception("Indique el identificador tributario del proveedor.");

            if (string.IsNullOrEmpty(txtRazonSocial.Text.Trim()))
                throw new Exception("Indique la razón social.");

            /* La misma regla que el SP, dicha antes de viajar: un proveedor
               que no es ni contratista ni vendedor de repuestos no se puede
               elegir en ninguna pantalla. */
            if (!chkContratista.Checked && !chkProveedorRepuesto.Checked)
                throw new Exception("Marque al menos un tipo: contratista o proveedor de repuestos.");

            Proveedor entidad = new Proveedor();
            entidad.prv_id = Id;
            entidad.prv_rut = txtRut.Text.Trim();
            entidad.prv_razon_social = txtRazonSocial.Text.Trim();
            entidad.prv_nombre_fantasia = txtNombreFantasia.Text.Trim();
            entidad.prv_giro = txtGiro.Text.Trim();
            entidad.prv_contacto = txtContacto.Text.Trim();
            entidad.prv_email = txtEmail.Text.Trim();
            entidad.prv_telefono = txtTelefono.Text.Trim();
            entidad.prv_direccion = txtDireccion.Text.Trim();
            entidad.prv_observacion = txtObservacion.Text.Trim();
            entidad.prv_es_contratista = chkContratista.Checked;
            entidad.prv_es_proveedor_repuesto = chkProveedorRepuesto.Checked;
            entidad.prv_habilitado = rdbSi.Checked;

            ProveedorController controller = new ProveedorController();

            Respuesta respuesta = (Id > 0)
                                ? controller.UpdateProveedor(entidad)
                                : controller.InsertProveedor(entidad);

            if (respuesta.error)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                return;
            }

            /* Se recuerda el id para que un segundo Guardar edite en vez de
               crear otro: sin esto, apretar dos veces deja dos proveedores
               —y el segundo lo frena el RUT único, con un mensaje que no
               explica lo que pasó. */
            if (Id == 0) Id = respuesta.codigo;

            Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
