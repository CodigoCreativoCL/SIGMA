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

                case "cboTipo":

                    /* Solo los habilitados: un tipo apagado no se puede
                       elegir, aunque los repuestos que ya lo tienen lo
                       conserven. */
                    RepuestoTipoController ctrlTipo = new RepuestoTipoController();

                    ctrl.Items.Add(new RadComboBoxItem("Sin clasificar", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlTipo.GetRepuestoTipos(
                        new RepuestoTipo { filtro_habilitado = true });
                    ctrl.DataValueField = "rti_id";
                    ctrl.DataTextField = "rti_nombre";
                    ctrl.DataBind();
                    break;

                case "cboBodega":

                    BodegaController ctrlBodega = new BodegaController();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlBodega.GetBodegas(new Bodega { filtro_habilitado = true });
                    ctrl.DataValueField = "bod_id";
                    ctrl.DataTextField = "bod_nombre";
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
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardarUmbral);

        udPanel.Update();
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

                if (entidad.rep_repuesto_tipo > 0)
                    cboTipo.SelectedValue = entidad.rep_repuesto_tipo.ToString();

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
        /* La pestaña se oculta entera, no el panel: dejar la pestaña visible
           y vaciarla hace que alguien la abra y crea que se rompió. Sin
           repuesto guardado no hay a qué colgarle un umbral. */
        tabUmbrales.Visible = (Id > 0);
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
            tabLotes.Visible = false;
            pnlLotes.Visible = false;
            return;
        }

        RepuestoController controller = new RepuestoController();

        bool controla = controller.GetRepuesto(Id).rep_controla_lote;

        tabLotes.Visible = controla;
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
            int dias = (int)(l.rlo_fecha_vencimiento.Value.Date - DateTime.Today).TotalDays;

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

        if (Id <= 0) return;

        bool puedeEditar = Token.Puede("CREAR EDITAR REPUESTOS");

        fupFoto.Visible = puedeEditar;
        lnkAgregarFoto.Visible = puedeEditar;

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

    protected void lnkAgregarFoto_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR REPUESTOS"))
            {
                Tools.tools.ClientAlert("No tiene permisos para agregar fotos.", "alerta");
                return;
            }

            if (!fupFoto.HasFile)
            {
                Tools.tools.ClientAlert("Elija una imagen.", "alerta");
                return;
            }

            RepuestoFotoController controller = new RepuestoFotoController();

            Respuesta respuesta = controller.Agregar(Id, fupFoto.FileBytes,
                fupFoto.FileName, fupFoto.PostedFile.ContentType, null);

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
        cboTipo.ReadOnly = !puedeEditar;
        txtVidaHora.ReadOnly = !puedeEditar;
        txtVidaDia.ReadOnly = !puedeEditar;
        txtVidaCiclo.ReadOnly = !puedeEditar;

        rdbLoteSi.Enabled = puedeEditar;
        rdbLoteNo.Enabled = puedeEditar;
        rdbConsumibleSi.Enabled = puedeEditar;
        rdbConsumibleNo.Enabled = puedeEditar;
        rdbReparableSi.Enabled = puedeEditar;
        rdbReparableNo.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;

        /* Los umbrales son otro permiso: definir cuando avisar por una pieza
           critica es decision de quien maneja el inventario, no de quien
           mantiene el catalogo. */
        btnGuardarUmbral.Visible = puedeStock;
        cboBodega.ReadOnly = !puedeStock;
        txtMinimo.ReadOnly = !puedeStock;
        txtMaximo.ReadOnly = !puedeStock;
        txtReposicion.ReadOnly = !puedeStock;
    }

    /// <summary>
    /// Lee un decimal escrito a mano. Acepta coma y punto: en un teclado
    /// chileno la coma es lo natural, y rechazar "4,5" por eso seria
    /// castigar al usuario por la configuracion regional.
    /// </summary>
    private decimal? LeerDecimal(string texto, string campo)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim())) return null;

        decimal valor;
        string limpio = texto.Trim().Replace(",", ".");

        if (!decimal.TryParse(limpio, NumberStyles.Any, CultureInfo.InvariantCulture, out valor))
            throw new Exception("El campo '" + campo + "' no es un número válido.");

        return valor;
    }

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
               Al crear se manda AUTO y el SP lo genera como REP-<id>: el
               codigo depende del ID, y el ID no existe hasta despues del
               INSERT, asi que no hay forma de calcularlo antes.

               AUTO y no vacio: el SP valida que el codigo venga ANTES de
               insertar, asi que un vacio se rechaza con "indique el codigo".
               AUTO pasa esa validacion, nunca queda guardado, y el SP lo
               reemplaza en cuanto conoce el ID.

               Al editar viaja el que ya tiene. No se regenera nunca: el
               codigo esta impreso en su etiqueta, y cambiarlo dejaria la
               etiqueta pegada apuntando a algo que no existe. */
            entidad.rep_codigo = SitioBase.CodigoModulo.Componer("Repuesto", txtCodigo.Text);
            entidad.rep_nombre = txtNombre.Text.Trim();
            entidad.rep_fabricante = txtFabricante.Text.Trim();
            entidad.rep_modelo = txtModelo.Text.Trim();
            entidad.rep_descripcion = txtDescripcion.Text.Trim();
            entidad.rep_unidad_medida = int.Parse(cboUnidad.SelectedValue);

            /* Vacio es "sin clasificar": 0 viaja como NULL a la base. */
            int tipo;
            entidad.rep_repuesto_tipo =
                int.TryParse(cboTipo.SelectedValue, out tipo) ? tipo : 0;
            entidad.rep_costo_referencia = LeerDecimal(txtCosto.Text, "costo de referencia");

            /* Vida util esperada. Las tres son opcionales y pueden convivir:
               un aceite vence a las 2.000 horas O a los 365 dias, lo que
               ocurra primero. */
            entidad.rep_vida_util_hora = LeerDecimal(txtVidaHora.Text, "vida útil en horas");
            entidad.rep_vida_util_ciclo = LeerDecimal(txtVidaCiclo.Text, "vida útil en ciclos");

            decimal? dias = LeerDecimal(txtVidaDia.Text, "vida útil en días");

            if (dias != null)
            {
                if (dias.Value != Math.Floor(dias.Value))
                    throw new Exception("La vida útil en días tiene que ser un número entero.");

                entidad.rep_vida_util_dia = (int)dias.Value;
            }

            /* Al EDITAR, un campo vacio significa borrar. Al crear no hay
               nada que borrar, asi que la bandera solo viaja con Id > 0. */
            entidad.limpia_vida_util = (Id > 0);
            entidad.rep_controla_lote = rdbLoteSi.Checked;
            entidad.rep_es_consumible = rdbConsumibleSi.Checked;
            entidad.rep_es_reparable = rdbReparableSi.Checked;
            entidad.rep_habilitado = rdbSi.Checked;

            /* La baja pasa por DEL_REPUESTO, que rechaza si queda
               existencia. UPD_REPUESTO con @HABILITADO = 0 tambien lo
               deshabilitaria, pero sin comprobar nada. */
            if (Id > 0 && rdbNo.Checked)
            {
                Respuesta baja = controller.DeleteRepuesto(Id);

                if (baja.error)
                {
                    Tools.tools.ClientAlert(baja.detalle, "alerta");
                    return;
                }
            }

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateRepuesto(entidad)
                : controller.InsertRepuesto(entidad);

            if (!respuesta.error)
            {
                // Al crear no se cierra: falta definir sus umbrales.
                if (Id == 0)
                {
                    Id = respuesta.codigo;
                    Tools.tools.ClientAlert(respuesta.detalle + " Defina sus umbrales por bodega.", "ok");
                    return;
                }

                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void btnGuardarUmbral_Click(object sender, EventArgs e)
    {
        try
        {
            if (Id == 0) throw new Exception("Primero guarde el repuesto.");

            if (string.IsNullOrEmpty(cboBodega.SelectedValue))
                throw new Exception("Debe elegir la bodega.");

            decimal? minimo = LeerDecimal(txtMinimo.Text, "mínimo");

            if (minimo == null)
                throw new Exception("El stock mínimo es obligatorio: es lo que dispara el aviso.");

            RepuestoBodegaStock entidad = new RepuestoBodegaStock();
            entidad.rbs_repuesto = Id;
            entidad.rbs_bodega = int.Parse(cboBodega.SelectedValue);
            entidad.rbs_stock_minimo = minimo.Value;
            entidad.rbs_stock_maximo = LeerDecimal(txtMaximo.Text, "máximo");
            entidad.rbs_punto_reposicion = LeerDecimal(txtReposicion.Text, "punto de reposición");

            RepuestoController controller = new RepuestoController();
            Respuesta respuesta = controller.GuardarUmbral(entidad);

            if (!respuesta.error)
            {
                txtMinimo.Text = "";
                txtMaximo.Text = "";
                txtReposicion.Text = "";
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
