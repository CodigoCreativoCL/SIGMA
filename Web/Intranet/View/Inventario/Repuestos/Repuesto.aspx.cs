using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un repuesto (HU-050) y sus umbrales por bodega (HU-053).
///
/// LOS UMBRALES ESTAN AQUI Y NO EN SU PROPIA PANTALLA
///   No son una entidad que alguien administre por su cuenta: son una
///   propiedad del repuesto EN una bodega. Un mantenedor aparte obligaria
///   a elegir el repuesto otra vez en una pantalla que ya sabe cual es.
/// </summary>
public partial class View_Inventario_Repuestos_Repuesto : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

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

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            switch (ctrl.ID)
            {
                case "cboUnidad":

                    UnidadMedidaController ctrlUnidad = new UnidadMedidaController();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlUnidad.GetUnidades();
                    ctrl.DataValueField = "ume_id";
                    ctrl.DataTextField = "etiqueta";
                    ctrl.DataBind();
                    break;

            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGaleria();

        CargarDatos();
        CargarUmbrales();
        CargarLotes();
        Bloqueo();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);

        /* Lo que necesita el constructor del navegador: si es nuevo y que puede hacer quien lo abre. */
        litRpDatos.Text = "<div id=\"rpDatos\" hidden data-nuevo=\"" + (Id == 0 ? "1" : "0") + "\" data-stock=\"" + (Token.Puede("GESTIONAR STOCK") ? "1" : "0")
                        + "\" data-ingreso=\"" + (Token.Puede("REGISTRAR INGRESO REPUESTO") ? "1" : "0") + "\"></div>";

        udPanel.Update();
    }

    private List<FabricanteController.Fabricante> catalogoFab;
    private List<FabricanteController.Fabricante> CatalogoFab()
    {
        return catalogoFab ?? (catalogoFab = new FabricanteController().Catalogo());
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            RepuestoController controller = new RepuestoController();
            Repuesto entidad = controller.GetRepuesto(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Repuesto", entidad.rep_codigo);
            txtNombre.Text = entidad.rep_nombre;
            /* Combos SIGMA con texto libre: la lista sale del catalogo (bloque
               333) y el valor guardado se muestra aunque no este en ella. */
            txtFabricante.Text = entidad.rep_fabricante;
            txtModelo.Text = entidad.rep_modelo;
            txtDescripcion.Text = entidad.rep_descripcion;

            if (entidad.rep_costo_referencia != null)
                txtCosto.Text = entidad.rep_costo_referencia.Value.ToString("0.##", CultureInfo.InvariantCulture);

            if (entidad.rep_vida_util_hora != null)
                txtVidaHora.Text = entidad.rep_vida_util_hora.Value.ToString("0.##", CultureInfo.InvariantCulture);
            if (entidad.rep_vida_util_dia != null)
                txtVidaDia.Text = entidad.rep_vida_util_dia.Value.ToString();
            if (entidad.rep_vida_util_ciclo != null)
                txtVidaCiclo.Text = entidad.rep_vida_util_ciclo.Value.ToString("0.##", CultureInfo.InvariantCulture);

            if (entidad.rep_unidad_medida > 0)
                cboUnidad.SelectedValue = entidad.rep_unidad_medida.ToString();

            // almacenamiento: metodo propio (o vacio = el de la bodega), medidas y peso
            System.Data.DataRow alm = new RepuestoAlmacenamientoController().Ficha(Id);
            if (alm != null)
            {
                string met = Convert.ToString(alm["METODO"]);
                RadComboBoxItem im = ddlMetodo.FindItemByValue(met ?? "");
                if (im != null) im.Selected = true;
                txtLargo.Text = Medida(alm["LARGO"]);
                txtAncho.Text = Medida(alm["ANCHO"]);
                txtAlto.Text = Medida(alm["ALTO"]);
                txtPeso.Text = Medida(alm["PESO"]);
            }

            if (entidad.rep_repuesto_tipo > 0) txtTipo.Text = entidad.repuesto_tipo_nombre;

            // sus vinculos directos, para editarlos en el paso Compatibilidades
            hdnCompat.Value = CompatInicial(Id);

            rdbLoteSi.Checked = entidad.rep_controla_lote;
            rdbLoteNo.Checked = !entidad.rep_controla_lote;
            rdbConsumibleSi.Checked = entidad.rep_es_consumible;
            rdbConsumibleNo.Checked = !entidad.rep_es_consumible;
            rdbReparableSi.Checked = entidad.rep_es_reparable;
            rdbReparableNo.Checked = !entidad.rep_es_reparable;
            rdbSi.Checked = entidad.rep_habilitado;
            rdbNo.Checked = !entidad.rep_habilitado;

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.rep_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.rep_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    protected void CargarUmbrales()
    {
        /* Al crear no hay umbrales que mostrar: se arman en el constructor del paso Stock. */
        pnlUmbrales.Visible = (Id > 0);

        if (Id == 0) return;

        if (GridUmbrales.Columns.Count == 0)
        {
            GridUmbrales.AddColumn("BODEGA_NOMBRE", "BODEGA", Width: "34%");
            GridUmbrales.AddColumn("RBS_STOCK_MINIMO", "MÍNIMO", Width: "14%", DataFormat: "{0:N2}");
            GridUmbrales.AddColumn("RBS_STOCK_MAXIMO", "MÁXIMO", Width: "14%", DataFormat: "{0:N2}");
            GridUmbrales.AddColumn("RBS_PUNTO_REPOSICION", "REPOSICIÓN", Width: "16%", DataFormat: "{0:N2}");
            GridUmbrales.AddColumn("EXISTENCIA", "EXISTENCIA", Width: "22%", DataFormat: "{0:N2}");
        }

        RepuestoController controller = new RepuestoController();

        GridUmbrales.DataSource = controller.GetUmbrales(new RepuestoBodegaStock { rbs_repuesto = Id });
        GridUmbrales.DataBind();
    }

    /// <summary>
    /// Los lotes recibidos. Solo aparece si el repuesto los controla: en uno
    /// que no, la sección estaría siempre vacía y solo agregaría ruido.
    /// </summary>
    protected void CargarLotes()
    {
        if (Id == 0)
        {
            pnlLotes.Visible = false;
            return;
        }

        RepuestoController controller = new RepuestoController();

        bool controla = controller.GetRepuesto(Id).rep_controla_lote;

        pnlLotes.Visible = controla;

        if (!controla) return;

        if (GridLotes.Columns.Count == 0)
        {
            GridLotes.AddColumn("RLO_CODIGO", "LOTE", Width: "34%");
            GridLotes.AddColumn("RLO_FECHA_INGRESO", "INGRESÓ", Width: "20%",
                DataFormat: "{0:dd-MM-yyyy}");
            GridLotes.AddTemplateColumn("VENCE", "", "VENCE", Width: "46%");
        }

        GridLotes.DataSource = controller.GetLotes(new RepuestoLote { rlo_repuesto = Id });
        GridLotes.DataBind();
    }

    /// <summary>
    /// El vencimiento con su chip. VENCIDO lo calcula el SP contra la fecha
    /// de hoy: una columna con esa marca estaría mal la mitad del tiempo.
    /// </summary>
    protected void GridLotes_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        RepuestoLote l = item.DataItem as RepuestoLote;

        if (l == null) return;

        string html;

        if (l.rlo_fecha_vencimiento == null)
        {
            /* Sin fecha no se puede avisar de nada, y en un repuesto que
               controla lote eso es un dato que falta, no una elección. Se
               dice, para que alguien lo complete al próximo ingreso. */
            html = "<span class=\"grid-estado-chip is-neutro\">"
                 + "<i class=\"mdi mdi-calendar-remove-outline\"></i>Sin fecha</span>";
        }
        else
        {
            string fecha = l.rlo_fecha_vencimiento.Value.ToString("dd-MM-yyyy");
            int dias = (int)(l.rlo_fecha_vencimiento.Value.Date - global::SitioBase.Hora.Hoy).TotalDays;

            if (l.vencido)
                html = "<span class=\"grid-estado-chip is-alerta\">"
                     + "<i class=\"mdi mdi-alert-circle\"></i>Vencido el " + fecha + "</span>";
            else if (dias <= 60)
                html = "<span class=\"grid-estado-chip is-advertencia\">"
                     + "<i class=\"mdi mdi-clock-alert-outline\"></i>Vence en " + dias + " días</span>";
            else
                html = "<span class=\"grid-estado-chip is-exito\">"
                     + "<i class=\"mdi mdi-check-circle\"></i>" + fecha + "</span>";
        }

        item["VENCE"].Controls.Add(new Literal { Text = html });
    }

    /* ======================================================================
       LA GALERIA

       Solo se dibuja cuando el repuesto YA existe: una foto necesita algo a
       lo que colgarse, y un subidor en una ficha sin guardar promete algo que
       no puede cumplir.

       El <img> apunta a `VerArchivo.aspx` con el id CIFRADO. No se incrusta
       la imagen en el HTML: asi el navegador la cachea entre aperturas de la
       ficha, y el HTML de una galeria de ocho fotos no pesa ocho fotos.
       ====================================================================== */
    protected void CargarGaleria()
    {
        pnlGaleria.Visible = Id > 0;
        /* Al crear, Siguiente guía hasta el último paso (sigma-asistente.js). */
        pnlAf.CssClass = Id > 0 ? "af" : "af af-es-nuevo";

        if (Id <= 0) return;

        bool puedeEditar = Token.Puede("CREAR EDITAR REPUESTOS");

        fupFotos.Visible = puedeEditar;

        List<RepuestoFoto> fotos = new RepuestoFotoController().GetFotos(Id);

        rptFotos.DataSource = fotos;
        rptFotos.DataBind();

        rptFotos.Visible = fotos.Count > 0;
        pnlSinFotos.Visible = fotos.Count == 0;
    }

    protected void rptFotos_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item &&
            e.Item.ItemType != ListItemType.AlternatingItem) return;

        RepuestoFoto f = e.Item.DataItem as RepuestoFoto;

        if (f == null) return;

        bool puedeEditar = Token.Puede("CREAR EDITAR REPUESTOS");

        LinkButton portada = (LinkButton)e.Item.FindControl("lnkPortada");
        LinkButton quitar = (LinkButton)e.Item.FindControl("lnkQuitarFoto");

        if (portada != null)
        {
            portada.CommandArgument = f.vinculo.ToString();

            /* La que ya es portada no ofrece "hacer portada": un boton que no
               cambia nada es una invitacion a preguntarse si funciono. */
            portada.Visible = puedeEditar && !f.es_portada;
            ScriptManager.GetCurrent(Page).RegisterPostBackControl(portada);
        }

        if (quitar != null)
        {
            quitar.CommandArgument = f.vinculo.ToString();
            quitar.Visible = puedeEditar;
            quitar.OnClientClick = "if (!ConfirSweetAlert(this, \'\', \'¿Quitar esta foto de la galería?\')) return false;";
            ScriptManager.GetCurrent(Page).RegisterPostBackControl(quitar);
        }

        Literal lit = (Literal)e.Item.FindControl("litFoto");

        if (lit == null) return;

        string alt = string.IsNullOrEmpty(f.titulo) ? f.nombre : f.titulo;

        StringBuilder b = new StringBuilder();

        /* La miniatura enlaza al original en otra pestaña: el recorte sirve
           para reconocerla, y para mirarla de verdad hace falta el tamaño
           completo. */
        b.Append("<a class=\"sg-galeria-foto\" href=\"" +
                 Server.HtmlEncode(SitioBase.UrlArchivo.Ver(f.archivo)) +
                 "\" target=\"_blank\" rel=\"noopener\" title=\"Ver en tamaño completo\">");

        b.Append("<img src=\"" + Server.HtmlEncode(SitioBase.UrlArchivo.Ver(f.archivo)) +
                 "\" alt=\"" + Server.HtmlEncode(alt) + "\" loading=\"lazy\" />");

        if (f.es_portada)
            b.Append("<span class=\"sg-galeria-portada\"><i class=\"mdi mdi-star\"></i>Portada</span>");

        b.Append("</a>");

        b.Append("<div class=\"sg-galeria-pie\" title=\"" + Server.HtmlEncode(f.nombre) + "\">" +
                 Server.HtmlEncode(f.nombre) + "</div>");

        lit.Text = b.ToString();
    }

    protected void rptFotos_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR REPUESTOS"))
            {
                Tools.tools.ClientAlert("No tiene permisos para editar las fotos.", "alerta");
                return;
            }

            int vinculo;

            if (!int.TryParse(Convert.ToString(e.CommandArgument), out vinculo)) return;

            RepuestoFotoController controller = new RepuestoFotoController();
            Respuesta respuesta;

            if (e.CommandName == "quitar") respuesta = controller.Quitar(vinculo);
            else if (e.CommandName == "portada") respuesta = controller.HacerPortada(vinculo);
            else return;

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR REPUESTOS");
        bool puedeStock = Token.Puede("GESTIONAR STOCK");

        // El codigo solo se escribe al crear.
        /* Nunca se escribe a mano: lo genera el SP al crear, y despues
               identifica el registro. */
            litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Repuesto");
            txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtFabricante.ReadOnly = !puedeEditar;
        txtModelo.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        txtCosto.ReadOnly = !puedeEditar;
        cboUnidad.ReadOnly = !puedeEditar;
        txtTipo.ReadOnly = !puedeEditar;
        txtVidaHora.ReadOnly = !puedeEditar;
        txtVidaDia.ReadOnly = !puedeEditar;
        txtVidaCiclo.ReadOnly = !puedeEditar;
        ddlMetodo.ReadOnly = !puedeEditar;
        txtLargo.ReadOnly = !puedeEditar;
        txtAncho.ReadOnly = !puedeEditar;
        txtAlto.ReadOnly = !puedeEditar;
        txtPeso.ReadOnly = !puedeEditar;

        rdbLoteSi.Enabled = puedeEditar;
        rdbLoteNo.Enabled = puedeEditar;
        rdbConsumibleSi.Enabled = puedeEditar;
        rdbConsumibleNo.Enabled = puedeEditar;
        rdbReparableSi.Enabled = puedeEditar;
        rdbReparableNo.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    /// <summary>
    /// Lee un decimal escrito a mano. Acepta coma y punto: en un teclado
    /// chileno la coma es lo natural, y rechazar "4,5" por eso seria
    /// castigar al usuario por la configuracion regional.
    /// </summary>
    private static string Medida(object v)
    {
        return v == null || v == DBNull.Value ? "" : Convert.ToDecimal(v).ToString("0.###", CultureInfo.InvariantCulture);
    }

    private decimal? LeerDecimal(string texto, string campo)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim())) return null;

        decimal valor;
        string limpio = texto.Trim().Replace(",", ".");

        if (!decimal.TryParse(limpio, NumberStyles.Any, CultureInfo.InvariantCulture, out valor))
            throw new Exception("El campo '" + campo + "' no es un número válido.");

        return valor;
    }

    /* ======================================================================
       GUARDAR

       Un solo «Guardar» crea o actualiza el repuesto y, con el, lo que se armo
       en los pasos: las fotos (paso 1), las compatibilidades (paso 5) y el stock
       -existencia inicial y umbrales- (paso 6). Si algo de eso falla, el repuesto
       ya quedo guardado: se avisa que, y la ficha sigue abierta para corregirlo.
       ====================================================================== */
    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboUnidad.SelectedValue))
                throw new Exception("Debe elegir la unidad de medida.");

            Repuesto entidad = new Repuesto();
            RepuestoController controller = new RepuestoController();

            entidad.rep_id = Id;
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como REP-<id>. Al editar viaja
               el que ya tiene: no se regenera nunca, esta impreso en su etiqueta. */
            entidad.rep_codigo = SitioBase.CodigoModulo.Componer("Repuesto", txtCodigo.Text);
            entidad.rep_nombre = txtNombre.Text.Trim();
            entidad.rep_fabricante = (txtFabricante.Text ?? "").Trim();
            entidad.rep_modelo = (txtModelo.Text ?? "").Trim();
            entidad.rep_descripcion = txtDescripcion.Text.Trim();
            entidad.rep_unidad_medida = int.Parse(cboUnidad.SelectedValue);

            /* El tipo se elige o se escribe: lo que no existe se crea como propio de la empresa. */
            entidad.rep_repuesto_tipo = ResolverTipo(txtTipo.Text);
            entidad.rep_costo_referencia = LeerDecimal(txtCosto.Text, "costo de referencia");

            /* Vida util esperada. Las tres son opcionales y pueden convivir. */
            entidad.rep_vida_util_hora = LeerDecimal(txtVidaHora.Text, "vida útil en horas");
            entidad.rep_vida_util_ciclo = LeerDecimal(txtVidaCiclo.Text, "vida útil en ciclos");

            decimal? dias = LeerDecimal(txtVidaDia.Text, "vida útil en días");

            if (dias != null)
            {
                if (dias.Value != Math.Floor(dias.Value))
                    throw new Exception("La vida útil en días tiene que ser un número entero.");

                entidad.rep_vida_util_dia = (int)dias.Value;
            }

            /* Al EDITAR, un campo vacio significa borrar. Al crear no hay nada que borrar. */
            entidad.limpia_vida_util = (Id > 0);
            entidad.rep_controla_lote = rdbLoteSi.Checked;
            entidad.rep_es_consumible = rdbConsumibleSi.Checked;
            entidad.rep_es_reparable = rdbReparableSi.Checked;
            entidad.rep_habilitado = rdbSi.Checked;

            decimal? largo = LeerDecimal(txtLargo.Text, "largo");
            decimal? ancho = LeerDecimal(txtAncho.Text, "ancho");
            decimal? alto = LeerDecimal(txtAlto.Text, "alto");
            decimal? peso = LeerDecimal(txtPeso.Text, "peso");

            /* La baja pasa por DEL_REPUESTO, que rechaza si queda existencia. */
            if (Id > 0 && rdbNo.Checked)
            {
                Respuesta baja = controller.DeleteRepuesto(Id);

                if (baja.error)
                {
                    Tools.tools.ClientAlert(baja.detalle, "alerta");
                    return;
                }
            }

            bool eraNuevo = Id == 0;
            Respuesta respuesta = (Id > 0)
                ? controller.UpdateRepuesto(entidad)
                : controller.InsertRepuesto(entidad);

            if (respuesta.error)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                return;
            }

            int repId = Id > 0 ? Id : respuesta.codigo;
            Id = repId;          // desde aqui un reintento ACTUALIZA, no crea otro
            List<string> avisos = new List<string>();

            /* Metodo y medidas van por sus propios SP (los mismos que usa el mapa 3D). */
            RepuestoAlmacenamientoController alm = new RepuestoAlmacenamientoController();
            Respuesta rm = alm.GuardarMetodo(repId, ddlMetodo.SelectedValue);
            Respuesta rd = rm.error ? rm : alm.GuardarMedidas(repId, largo, ancho, alto, peso);
            if (rd.error) avisos.Add("el almacenamiento no se guardó (" + rd.detalle + ")");

            try { GuardarFotos(repId, avisos); } catch (Exception ex) { avisos.Add("las fotos (" + ex.Message + ")"); }
            try { GuardarCompat(repId, avisos); } catch (Exception ex) { avisos.Add("las compatibilidades (" + ex.Message + ")"); }
            try { GuardarStock(repId, eraNuevo, entidad.rep_controla_lote, avisos); } catch (Exception ex) { avisos.Add("el stock (" + ex.Message + ")"); }

            if (avisos.Count == 0)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle + " Pero no se guardó: " + string.Join("; ", avisos.ToArray()) + ".", "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    // ---------------------------------------------------------------- el tipo, creado si no existe

    private static string Clave(string t)
    {
        string d = (t ?? "").Normalize(NormalizationForm.FormD);
        StringBuilder b = new StringBuilder();
        foreach (char c in d)
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark) b.Append(char.ToLowerInvariant(c));
        return System.Text.RegularExpressions.Regex.Replace(b.ToString(), "\\s+", " ").Trim();
    }

    /// <summary>El id del tipo escrito: el que ya existe (sin distinguir tildes ni mayusculas) o uno nuevo. Vacio = sin clasificar.</summary>
    private int ResolverTipo(string texto)
    {
        texto = (texto ?? "").Trim();
        if (texto == "") return 0;

        RepuestoTipoController c = new RepuestoTipoController();
        List<RepuestoTipo> todos = c.GetRepuestoTipos(new RepuestoTipo { filtro_habilitado = true }) ?? new List<RepuestoTipo>();
        RepuestoTipo t = todos.Find(x => Clave(x.rti_nombre) == Clave(texto));
        if (t != null) return t.rti_id;

        Respuesta r = c.InsertRepuestoTipo(new RepuestoTipo { rti_codigo = "AUTO", rti_nombre = texto, rti_orden = 0 });
        if (r.error) throw new Exception("No se pudo crear el tipo «" + texto + "»: " + r.detalle);
        return r.codigo;
    }

    // ---------------------------------------------------------------- fotos

    private void GuardarFotos(int repId, List<string> avisos)
    {
        if (!fupFotos.HasFiles) return;
        RepuestoFotoController fc = new RepuestoFotoController();

        foreach (System.Web.HttpPostedFile f in fupFotos.PostedFiles)
        {
            if (f == null || f.ContentLength == 0) continue;
            if (!(f.ContentType ?? "").StartsWith("image/", StringComparison.OrdinalIgnoreCase)) { avisos.Add("«" + f.FileName + "» no es una imagen"); continue; }

            byte[] bytes = new byte[f.ContentLength];
            f.InputStream.Position = 0;
            f.InputStream.Read(bytes, 0, bytes.Length);

            Respuesta r = fc.Agregar(repId, bytes, System.IO.Path.GetFileName(f.FileName), f.ContentType, null);
            if (r.error) avisos.Add("la foto «" + f.FileName + "» (" + r.detalle + ")");
        }
    }

    // ---------------------------------------------------------------- compatibilidades

    private static List<Dictionary<string, object>> LeerLista(string json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new List<Dictionary<string, object>>();
        return new System.Web.Script.Serialization.JavaScriptSerializer().Deserialize<List<Dictionary<string, object>>>(json)
               ?? new List<Dictionary<string, object>>();
    }
    private static string Txt(Dictionary<string, object> d, string k)
    {
        object v; return d.TryGetValue(k, out v) && v != null ? Convert.ToString(v).Trim() : "";
    }
    private static decimal? Num(Dictionary<string, object> d, string k)
    {
        string t = Txt(d, k).Replace(",", ".");
        decimal n; return t != "" && decimal.TryParse(t, NumberStyles.Any, CultureInfo.InvariantCulture, out n) ? (decimal?)n : null;
    }

    /// <summary>Los vinculos directos (a un activo o a un componente) que el repuesto ya tiene.</summary>
    private System.Data.DataTable Directos(int repId)
    {
        System.Data.SqlClient.SqlCommand cmd = new System.Data.SqlClient.SqlCommand();
        cmd.CommandText = "SEL_REPUESTO_COMPAT_DIRECTAS";
        cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());
        cmd.Parameters.AddWithValue("@REPUESTO", repId);
        return Conexion.GetDataTable(cmd);
    }

    private string CompatInicial(int repId)
    {
        List<Dictionary<string, object>> l = new List<Dictionary<string, object>>();
        try
        {
            List<Dictionary<string, object>> destinos = Destinos();
            foreach (System.Data.DataRow f in Directos(repId).Rows)
            {
                string v = f["rco_activo"] != DBNull.Value ? "a:" + f["rco_activo"] : "c:" + f["rco_activo_componente"];
                Dictionary<string, object> d = destinos.Find(x => Convert.ToString(x["id"]) == v);
                string k = d != null ? Convert.ToString(((Dictionary<string, object>)d["tag"])["k"]) : (v.StartsWith("c:") ? "c" : "a");
                l.Add(new Dictionary<string, object> { { "v", v }, { "n", d != null ? Convert.ToString(d["n"]) : "(ya no está disponible)" }, { "k", k }, { "obs", Convert.ToString(f["rco_observacion"]) } });
            }
        }
        catch (Exception) { }
        return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(l);
    }

    private void GuardarCompat(int repId, List<string> avisos)
    {
        /* Sin lista no se toca nada: si el navegador no la mando, quitar vinculos seria perder datos. */
        if (string.IsNullOrWhiteSpace(hdnCompat.Value)) return;

        ActivoPlantaController ap = new ActivoPlantaController();
        HashSet<string> deseados = new HashSet<string>();

        foreach (Dictionary<string, object> d in LeerLista(hdnCompat.Value))
        {
            string v = Txt(d, "v"); int id;
            if (v.Length < 3 || !int.TryParse(v.Substring(2), out id)) continue;
            bool comp = v.StartsWith("c:");
            deseados.Add(v);
            Respuesta r = ap.VincularRepuesto(repId, comp ? 0 : id, comp ? id : 0, Txt(d, "obs"));
            if (r.error) avisos.Add("la compatibilidad con «" + Txt(d, "n") + "» (" + r.detalle + ")");
        }

        foreach (System.Data.DataRow f in Directos(repId).Rows)
        {
            string key = f["rco_activo"] != DBNull.Value ? "a:" + f["rco_activo"] : "c:" + f["rco_activo_componente"];
            if (!deseados.Contains(key)) ap.QuitarVinculoRepuesto(Convert.ToInt32(f["rco_id"]));
        }

        hdnCompat.Value = CompatInicial(repId);
    }

    // ---------------------------------------------------------------- stock

    private void GuardarStock(int repId, bool eraNuevo, bool controlaLote, List<string> avisos)
    {
        List<Dictionary<string, object>> filas = LeerLista(hdnStock.Value);
        if (filas.Count == 0) return;

        bool puedeStock = Token.Puede("GESTIONAR STOCK");
        bool puedeIngreso = Token.Puede("REGISTRAR INGRESO REPUESTO");
        RepuestoController rc = new RepuestoController();
        InventarioController ic = new InventarioController();
        List<Dictionary<string, object>> pendientes = new List<Dictionary<string, object>>();

        foreach (Dictionary<string, object> d in filas)
        {
            int bodega = int.Parse(Txt(d, "b") == "" ? "0" : Txt(d, "b"));
            string nombre = Txt(d, "bn");
            bool fallo = false;
            decimal? mn = Num(d, "min"), mx = Num(d, "max"), rp = Num(d, "rep"), cant = Num(d, "cant");

            // umbral
            if (mn != null && bodega > 0)
            {
                if (!puedeStock) { avisos.Add("no tienes permiso para definir umbrales (" + nombre + ")"); fallo = true; }
                else
                {
                    Respuesta r = rc.GuardarUmbral(new RepuestoBodegaStock { rbs_repuesto = repId, rbs_bodega = bodega, rbs_stock_minimo = mn.Value, rbs_stock_maximo = mx, rbs_punto_reposicion = rp });
                    if (r.error) { avisos.Add("los umbrales de " + nombre + " (" + r.detalle + ")"); fallo = true; }
                }
            }

            // existencia inicial: un ingreso, una sola vez
            if (eraNuevo && cant != null && cant.Value > 0 && bodega > 0)
            {
                if (!puedeIngreso) { avisos.Add("no tienes permiso para ingresar existencia (" + nombre + ")"); fallo = true; }
                else
                {
                    try
                    {
                        InventarioMovimiento m = new InventarioMovimiento { imo_repuesto = repId, imo_bodega = bodega, imo_inventario_movimiento_tipo = 1, imo_cantidad = cant.Value,
                                                                            imo_observacion = "Existencia inicial al crear el repuesto." };
                        int ub; if (int.TryParse(Txt(d, "u"), out ub) && ub > 0) m.imo_bodega_ubicacion = ub;
                        if (controlaLote)
                        {
                            string lote = Txt(d, "lote");
                            if (lote == "") throw new Exception("falta el código del lote");
                            DateTime venc; DateTime? vence = DateTime.TryParseExact(Txt(d, "vence"), new[] { "dd-MM-yyyy", "d-M-yyyy", "yyyy-MM-dd" }, CultureInfo.InvariantCulture, DateTimeStyles.None, out venc) ? (DateTime?)venc : null;
                            Respuesta rl = rc.InsertLote(new RepuestoLote { rlo_repuesto = repId, rlo_codigo = lote, rlo_fecha_ingreso = global::SitioBase.Hora.Hoy, rlo_fecha_vencimiento = vence });
                            if (rl.error) throw new Exception("el lote: " + rl.detalle);
                            m.imo_repuesto_lote = rl.codigo;
                        }
                        Respuesta ri = ic.RegistrarMovimiento(m);
                        if (ri.error) throw new Exception(ri.detalle);
                    }
                    catch (Exception ex) { avisos.Add("la existencia de " + nombre + " (" + ex.Message + ")"); fallo = true; }
                }
            }

            if (fallo) pendientes.Add(d);
        }

        // lo que quedo sin aplicar vuelve a la lista para corregirlo; lo aplicado ya no se repite
        hdnStock.Value = pendientes.Count == 0 ? "[]" : new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(pendientes);
    }

    // ---------------------------------------------------------------- listas para el navegador

    private static string EnScript(object o)
    {
        return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(o).Replace("</", "<\\/");
    }

    public string TiposJson()
    {
        List<string> l = new List<string>();
        try
        {
            foreach (RepuestoTipo t in new RepuestoTipoController().GetRepuestoTipos(new RepuestoTipo { filtro_habilitado = true }) ?? new List<RepuestoTipo>())
                l.Add(t.rti_nombre);
        }
        catch (Exception) { }
        return EnScript(l);
    }

    public string MarcasJson()
    {
        List<object> l = new List<object>();
        try
        {
            foreach (FabricanteController.Fabricante f in CatalogoFab() ?? new List<FabricanteController.Fabricante>())
                l.Add(new Dictionary<string, object> { { "n", f.nombre }, { "m", f.modelos ?? new List<string>() } });
        }
        catch (Exception) { }
        return EnScript(l);
    }

    /// <summary>Las bodegas con sus ubicaciones (racks), para el constructor de stock.</summary>
    public string BodegasJson()
    {
        List<object> l = new List<object>();
        try
        {
            List<Bodega> bodegas = new BodegaController().GetBodegas(new Bodega { filtro_habilitado = true }) ?? new List<Bodega>();
            List<BodegaUbicacion> ubic = new BodegaController().GetUbicaciones(new BodegaUbicacion { filtro_habilitado = true }) ?? new List<BodegaUbicacion>();
            foreach (Bodega b in bodegas)
            {
                List<object> us = new List<object>();
                foreach (BodegaUbicacion u in ubic)
                    if (u.bub_bodega == b.bod_id) us.Add(new Dictionary<string, object> { { "id", u.bub_id }, { "n", u.bub_codigo + (string.IsNullOrEmpty(u.bub_nombre) || u.bub_nombre == u.bub_codigo ? "" : " · " + u.bub_nombre) } });
                l.Add(new Dictionary<string, object> { { "id", b.bod_id }, { "n", b.bod_nombre }, { "planta", b.planta_nombre ?? "" }, { "ubic", us } });
            }
        }
        catch (Exception) { }
        return EnScript(l);
    }

    private List<Dictionary<string, object>> _destinos;

    /// <summary>Activos, subactivos y componentes en orden de arbol, cada uno con su tipo para que el combo los distinga.</summary>
    private List<Dictionary<string, object>> Destinos()
    {
        if (_destinos != null) return _destinos;
        _destinos = new List<Dictionary<string, object>>();
        try
        {
            int cliente = SitioBase.Session.ClienteId();
            List<Activo> activos = new ActivoController().GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true }) ?? new List<Activo>();
            List<ActivoComponente> comps = new ActivoComponenteController().GetComponentes(new ActivoComponente { aco_cliente = cliente, filtro_habilitado = true }) ?? new List<ActivoComponente>();
            HashSet<int> ids = new HashSet<int>(activos.ConvertAll(x => x.act_id));

            Action<Activo, string, int> agregar = null;
            agregar = (a, padre, nivel) =>
            {
                string k = padre == null ? "a" : "s";
                _destinos.Add(new Dictionary<string, object> { { "id", "a:" + a.act_id }, { "n", a.act_nombre + " · " + a.act_codigo },
                    { "sub", padre == null ? "Todo el activo" : "Subactivo de " + padre }, { "nivel", nivel },
                    { "tag", new Dictionary<string, object> { { "k", k }, { "t", k == "a" ? "Activo" : "Subactivo" } } } });
                List<ActivoComponente> suyos = comps.FindAll(c => c.aco_activo == a.act_id);
                suyos.Sort((x, y) => string.Compare(x.aco_nombre, y.aco_nombre, StringComparison.CurrentCultureIgnoreCase));
                foreach (ActivoComponente c in suyos)
                    _destinos.Add(new Dictionary<string, object> { { "id", "c:" + c.aco_id }, { "n", c.aco_nombre + " · " + c.aco_codigo },
                        { "sub", "Componente de " + a.act_nombre }, { "nivel", nivel + 1 },
                        { "tag", new Dictionary<string, object> { { "k", "c" }, { "t", "Componente" } } } });
                foreach (Activo h in activos.FindAll(x => x.act_activo_padre == a.act_id)) agregar(h, a.act_nombre, nivel + 1);
            };
            foreach (Activo a in activos)
                if (a.act_activo_padre == null || !ids.Contains(a.act_activo_padre.Value)) agregar(a, null, 0);
        }
        catch (Exception) { }
        return _destinos;
    }

    public string DestinosJson() { return EnScript(Destinos()); }
}
