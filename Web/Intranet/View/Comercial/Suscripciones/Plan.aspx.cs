using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Ficha del plan comercial y sus precios (ANEXO F §3).
///
/// EL PRECIO NO SE EDITA, SE REEMPLAZA
///   Plan_Comercial_Precio tiene un índice único filtrado que permite UNA
///   sola fila abierta por plan y periodicidad. Fijar un precio cierra la
///   vigente y abre otra, en la misma transacción. Por eso acá no hay un
///   campo "precio" editable sino un formulario de "fijar", y debajo el
///   historial completo.
///
/// EL CÓDIGO SOLO SE ESCRIBE AL CREAR
///   Es la llave con la que los scripts de datos y cualquier integración
///   futura identifican al plan. Renombrarlo desde un formulario rompería
///   en silencio lo que lo referencie por código.
/// </summary>
public partial class View_Comercial_Suscripciones_Plan : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");

            Grid.AddColumn("PCB_NOMBRE", "PERIODICIDAD", Width: "16%");
            Grid.AddColumn("PCP_VALOR_UF", "UF", Width: "10%", DataFormat: "{0:N2}");
            Grid.AddColumn("MONTO_CLP_REFERENCIAL", "REFERENCIAL HOY", Width: "16%", DataFormat: "{0:C0}");
            Grid.AddColumn("PCP_DESCUENTO_PORCENTAJE", "DESC.", Width: "9%", DataFormat: "{0:N1} %");
            Grid.AddColumn("PCP_VIGENCIA_DESDE", "DESDE", Width: "12%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddColumn("PCP_VIGENCIA_HASTA", "HASTA", Width: "12%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "13%", ItemPosition: HorizontalAlign.Center);
            Grid.AddColumn("PCP_ID", "", Width: "5%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                if (ctrl.ID == "cboPeriodicidad")
                {
                    CatalogoController controller = new CatalogoController();

                    ctrl.DataSource = controller.GetValoresPorCodigo("PERIODICIDAD_COBRO", SitioBase.Session.ClienteId());
                    ctrl.DataValueField = "valor_id";
                    ctrl.DataTextField = "valor_nombre";
                    ctrl.DataBind();
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();

        if (Id > 0)
        {
            CargarPrecios();
            Grid.DataBind();

            /* El repeater solo se rellena en la primera carga: en postback
               hay que conservar lo que la persona marcó, y volver a bindear
               lo pisaría con lo que hay en base. */
            if (!IsPostBack) CargarFuncionalidades();
        }

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnFijarPrecio);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardarContenido);
        udPanel.Update();
    }

    protected void CargarFuncionalidades()
    {
        PlanComercialController controller = new PlanComercialController();

        rptFuncionalidades.DataSource = controller.GetFuncionalidades(Id);
        rptFuncionalidades.DataBind();
    }

    /// <summary>
    /// Pinta una fila de la matriz. El tope solo aparece en las cuatro
    /// funcionalidades de tipo LÍMITE: mostrar una caja de número junto a
    /// "Órdenes de trabajo" invitaría a escribir algo que no significa nada.
    /// </summary>
    protected void rptFuncionalidades_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        PlanFuncionalidad f = (PlanFuncionalidad)e.Item.DataItem;

        HiddenField hdf = (HiddenField)e.Item.FindControl("hdfFuncionalidad");
        CheckBox chk = (CheckBox)e.Item.FindControl("chkIncluida");
        Label lbl = (Label)e.Item.FindControl("lblNombre");
        TextBox txt = (TextBox)e.Item.FindControl("txtTope");
        Literal litOrigen = (Literal)e.Item.FindControl("litOrigen");
        Literal litUnidad = (Literal)e.Item.FindControl("litUnidad");

        hdf.Value = f.fun_id.ToString();
        lbl.Text = Server.HtmlEncode(f.fun_nombre);

        chk.Checked = f.pcf_incluida && !f.caducada;
        chk.Enabled = Token.Puede("CREAR EDITAR PLANES COMERCIALES");

        if (f.EsLimite)
        {
            txt.Visible = true;
            txt.Enabled = chk.Enabled;
            txt.Text = (f.pcf_limite != null)
                ? f.pcf_limite.Value.ToString("0.##", CultureInfo.InvariantCulture)
                : "";
            txt.Attributes["placeholder"] = "sin límite";

            litUnidad.Text = (f.fun_codigo == "LIMITE ALMACENAMIENTO")
                ? "<span class=\"sigma-plan-unidad\">GB</span>"
                : "";
        }

        // De dónde sale lo que se muestra: sin esto, un "sí" en la matriz de
        // un cliente no se distingue de una excepción que alguien le dio.
        string origen = (f.origen ?? "").Trim();

        if (f.caducada)
            litOrigen.Text = "<span class=\"grid-estado-chip is-alerta\">Caducó el " +
                             f.pcf_vigencia_hasta.Value.ToString("dd-MM-yyyy") + "</span>";
        else if (origen == "EXCEPCIÓN")
            litOrigen.Text = "<span class=\"grid-estado-chip is-info\">Excepción</span>";
        else if (f.pcf_vigencia_hasta != null)
            litOrigen.Text = "<span class=\"grid-estado-chip is-info\">Hasta el " +
                             f.pcf_vigencia_hasta.Value.ToString("dd-MM-yyyy") + "</span>";
        else
            litOrigen.Text = "";
    }

    protected void btnGuardarContenido_Click(object sender, EventArgs e)
    {
        try
        {
            if (Id == 0) throw new Exception("Primero guarde el plan.");

            PlanComercialController controller = new PlanComercialController();

            int guardadas = 0;
            string errores = "";

            foreach (RepeaterItem fila in rptFuncionalidades.Items)
            {
                HiddenField hdf = (HiddenField)fila.FindControl("hdfFuncionalidad");
                CheckBox chk = (CheckBox)fila.FindControl("chkIncluida");
                TextBox txt = (TextBox)fila.FindControl("txtTope");

                int idFuncionalidad;
                if (hdf == null || !int.TryParse(hdf.Value, out idFuncionalidad)) continue;

                PlanFuncionalidad entidad = new PlanFuncionalidad();

                entidad.fun_id = idFuncionalidad;
                entidad.pcf_incluida = chk.Checked;

                /* Tope vacío con la casilla marcada = SIN LÍMITE, que es
                   como está el plan Full. Cero es otra cosa: cero es no
                   poder crear ninguno, y hay que poder decirlo. */
                if (txt != null && txt.Visible &&
                    !string.IsNullOrEmpty(txt.Text) && !string.IsNullOrEmpty(txt.Text.Trim()))
                {
                    decimal tope;
                    string normalizado = txt.Text.Trim().Replace(",", ".");

                    if (!decimal.TryParse(normalizado, NumberStyles.Float,
                                          CultureInfo.InvariantCulture, out tope))
                        throw new Exception("El tope de una de las funcionalidades no es un número válido.");

                    entidad.pcf_limite = tope;
                }

                Respuesta r = controller.GuardarFuncionalidad(Id, entidad);

                if (r.error) errores += r.detalle + " ";
                else guardadas++;
            }

            if (!string.IsNullOrEmpty(errores))
                Tools.tools.ClientAlert(errores, "alerta");
            else
                Tools.tools.ClientAlert("Contenido del plan actualizado: " + guardadas +
                                        " funcionalidades.", "ok");

            CargarFuncionalidades();
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            PlanComercialController controller = new PlanComercialController();
            PlanComercial p = controller.GetPlan(new PlanComercial { plc_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Plan_Comercial", p.plc_codigo);
            txtNombre.Text = p.plc_nombre;
            txtDescripcion.Text = p.plc_descripcion;
            txtOrden.Text = p.plc_orden.ToString();
            txtDiasGracia.Text = p.plc_dias_gracia.ToString();

            rdbPublicoSi.Checked = p.plc_publico;
            rdbPublicoNo.Checked = !p.plc_publico;
            rdbSi.Checked = p.plc_habilitado;
            rdbNo.Checked = !p.plc_habilitado;

            litTitulo.Text = Server.HtmlEncode(p.plc_nombre);

            litChipEstado.Text = p.plc_habilitado
                ? "<span class=\"sigma-modal-chip is-exito\">A la venta</span>"
                : "<span class=\"sigma-modal-chip is-alerta\">Retirado</span>";

            litHeroTitulo.Text = Server.HtmlEncode(p.plc_codigo) + " &middot; " +
                                 Server.HtmlEncode(p.plc_nombre);

            litHeroDetalle.Text = "Orden " + p.plc_orden + " &middot; " + p.plc_dias_gracia +
                                  " día(s) de gracia" +
                                  (p.plc_publico ? "" : " &middot; no público");

            pnlPrecios.Visible = true;
        }
        else
        {
            lblId.Text = "Nuevo";

            litTitulo.Text = "Nuevo plan";
            litChipEstado.Text = "<span class=\"sigma-modal-chip is-neutro\">Sin guardar</span>";
            litHeroTitulo.Text = "Plan comercial";
            litHeroDetalle.Text = "Guarde el plan y después fíjele un precio. Sin precio vigente para " +
                                  "una periodicidad, esa combinación no se vende.";

            txtDiasGracia.Text = "5";

            // Habilitado y precios no aplican a algo que todavia no existe.
            pnlHabilitado.Visible = false;
            pnlPrecios.Visible = false;
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR PLANES COMERCIALES");

        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        txtOrden.ReadOnly = !puedeEditar;
        txtDiasGracia.ReadOnly = !puedeEditar;
        txtValorUf.ReadOnly = !puedeEditar;
        txtDescuento.ReadOnly = !puedeEditar;
        txtDesde.ReadOnly = !puedeEditar;
        cboPeriodicidad.ReadOnly = !puedeEditar;

        rdbPublicoSi.Enabled = puedeEditar;
        rdbPublicoNo.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
        btnFijarPrecio.Visible = puedeEditar;

        // El codigo se escribe una sola vez, al crear.
        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Plan_Comercial");
        txtCodigo.ReadOnly = (Id > 0) || !puedeEditar;
    }

    protected void CargarPrecios()
    {
        PlanComercialController controller = new PlanComercialController();

        Grid.DataSource = controller.GetPrecios(new PlanComercialPrecio { filtro_plan = Id });
    }

    protected void rgrPrecios_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;

                string estado = DataBinder.Eval(item.DataItem, "estado") != null
                    ? DataBinder.Eval(item.DataItem, "estado").ToString()
                    : "";

                Label lblEstado = new Label();
                lblEstado.Text = estado;
                lblEstado.CssClass = "grid-estado-chip " + ChipDeEstado(estado);
                item["estadoChip"].Controls.Add(lblEstado);

                /* Retirar solo el precio que rige o el que todavía no
                   empezó. Un histórico no se retira: ya cotizó períodos que
                   se siguen consultando, y quitarlo dejaría cobros sin
                   explicación. */
                if ((estado == "VIGENTE" || estado == "PROGRAMADO") &&
                    Token.Puede("CREAR EDITAR PLANES COMERCIALES"))
                {
                    LinkButton quitar = new LinkButton();
                    quitar.ID = "lnkQuitar" + item.GetDataKeyValue("pcp_id");
                    quitar.CommandArgument = item.GetDataKeyValue("pcp_id").ToString();
                    quitar.CssClass = "icono_eliminar";
                    quitar.ToolTip = "Retirar este precio de la venta";
                    quitar.Click += lnkQuitar_Click;
                    quitar.OnClientClick =
                        "return ConfirSweetAlert(this, '', '¿Retirar este precio? Esa periodicidad deja de venderse.');";

                    item["pcp_id"].Controls.Add(quitar);
                }
            }
        }
    }

    private string ChipDeEstado(string estado)
    {
        switch ((estado ?? "").Trim().ToUpper())
        {
            case "VIGENTE": return "is-exito";
            case "PROGRAMADO": return "is-info";
            case "RETIRADO": return "is-alerta";
            default: return "is-neutro";   // HISTÓRICO
        }
    }

    protected void lnkQuitar_Click(object sender, EventArgs e)
    {
        try
        {
            LinkButton boton = (LinkButton)sender;

            int idPrecio;
            if (!int.TryParse(boton.CommandArgument, out idPrecio)) return;

            PlanComercialController controller = new PlanComercialController();
            Respuesta respuesta = controller.RetirarPrecio(new PlanComercialPrecio { pcp_id = idPrecio });

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            PlanComercial entidad = new PlanComercial();
            PlanComercialController controller = new PlanComercialController();

            entidad.plc_id = Id;
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como PLC-<id>: el
               codigo depende del ID, y el ID no existe hasta despues del
               INSERT, asi que no hay forma de calcularlo antes.

               AUTO y no vacio: el SP valida que el codigo venga ANTES de
               insertar, asi que un vacio se rechaza con "indique el codigo".
               AUTO pasa esa validacion, nunca queda guardado, y el SP lo
               reemplaza en cuanto conoce el ID.

               Al editar viaja el que ya tiene. No se regenera nunca: el
               codigo esta impreso en su etiqueta, y cambiarlo dejaria la
               etiqueta pegada apuntando a algo que no existe. */
            entidad.plc_codigo = SitioBase.CodigoModulo.Componer("Plan_Comercial", txtCodigo.Text);
            entidad.plc_nombre = txtNombre.Text.Trim();
            entidad.plc_descripcion = txtDescripcion.Text.Trim();
            entidad.plc_orden = LeerEntero(txtOrden.Text, "orden");
            entidad.plc_dias_gracia = LeerEntero(txtDiasGracia.Text, "días de gracia");
            entidad.plc_publico = rdbPublicoSi.Checked;
            entidad.plc_habilitado = (Id == 0) ? true : rdbSi.Checked;

            /* DAR DE BAJA NO ES GUARDAR CON UN CAMPO EN 0 (T-2196)

               Si se deja pasar por UPD_PLAN_COMERCIAL, deshabilitar es un
               UPDATE que no comprueba nada: el plan cae aunque haya clientes
               pagándolo, y sus precios y funcionalidades quedan habilitados
               colgando de algo que ya no se vende.

               DEL_PLAN_COMERCIAL es el camino con guarda. Va PRIMERO y, si
               rechaza, no se guarda nada más: seguir con el UPD sería
               entrar por la puerta que acabamos de cerrar. */
            if (Id > 0 && rdbNo.Checked)
            {
                Respuesta baja = controller.DeletePlan(Id);

                if (baja.error)
                {
                    Tools.tools.ClientAlert(baja.detalle, "alerta");
                    return;
                }
            }

            Respuesta respuesta = (Id > 0)
                ? controller.UpdatePlan(entidad)
                : controller.InsertPlan(entidad);

            if (!respuesta.error)
            {
                /* Al crear NO se cierra el modal: el plan recién nacido no
                   tiene precio y por lo tanto no se vende. Cerrar acá dejaría
                   la sensación de haber terminado algo que está a medias. */
                if (Id == 0)
                {
                    Id = respuesta.codigo;
                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
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

    protected void btnFijarPrecio_Click(object sender, EventArgs e)
    {
        try
        {
            if (Id == 0)
                throw new Exception("Primero guarde el plan.");

            if (string.IsNullOrEmpty(cboPeriodicidad.SelectedValue))
                throw new Exception("Debe elegir la periodicidad.");

            PlanComercialPrecio entidad = new PlanComercialPrecio();

            entidad.pcp_plan_comercial = Id;
            entidad.pcp_periodicidad_cobro = int.Parse(cboPeriodicidad.SelectedValue);
            entidad.pcp_valor_uf = LeerDecimal(txtValorUf.Text, "valor en UF");
            entidad.pcp_descuento_porcentaje = LeerDecimalOpcional(txtDescuento.Text, "descuento");
            entidad.vigencia_desde = LeerFecha(txtDesde.Text);

            if (entidad.pcp_valor_uf <= 0)
                throw new Exception("El valor en UF debe ser mayor que cero.");

            PlanComercialController controller = new PlanComercialController();
            Respuesta respuesta = controller.FijarPrecio(entidad);

            if (!respuesta.error)
            {
                txtValorUf.Text = "";
                txtDescuento.Text = "";
                txtDesde.Text = "";
            }

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    private int LeerEntero(string texto, string campo)
    {
        int valor;

        if (!int.TryParse((texto ?? "").Trim(), out valor))
            throw new Exception("El " + campo + " tiene que ser un número entero.");

        if (valor < 0)
            throw new Exception("El " + campo + " no puede ser negativo.");

        return valor;
    }

    /// <summary>
    /// Acepta punto o coma decimal: el teclado en es-CL escribe coma, una
    /// planilla copiada trae punto. Rechazar uno de los dos sería hacer
    /// fallar la carga por una diferencia que no le importa a nadie.
    /// </summary>
    private decimal LeerDecimal(string texto, string campo)
    {
        decimal valor;
        string normalizado = (texto ?? "").Trim().Replace(",", ".");

        if (!decimal.TryParse(normalizado, NumberStyles.Float, CultureInfo.InvariantCulture, out valor))
            throw new Exception("El " + campo + " no es un número válido.");

        return valor;
    }

    private decimal? LeerDecimalOpcional(string texto, string campo)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim())) return null;

        return LeerDecimal(texto, campo);
    }

    /// <summary>
    /// dd-MM-yyyy o dd/MM/yyyy, con formato explícito. No se usa la cultura
    /// del hilo: un servidor mal configurado leería 03-04-2026 como 4 de
    /// marzo y el precio entraría a regir un mes antes sin que nadie lo note.
    /// </summary>
    private DateTime? LeerFecha(string texto)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim())) return null;

        string[] formatos = new string[] { "dd-MM-yyyy", "dd/MM/yyyy", "yyyy-MM-dd" };

        DateTime fecha;

        if (!DateTime.TryParseExact(texto.Trim(), formatos, CultureInfo.InvariantCulture,
                                    DateTimeStyles.None, out fecha))
            throw new Exception("La fecha desde la que rige el precio no es válida. Use dd-mm-aaaa.");

        return fecha;
    }
}
