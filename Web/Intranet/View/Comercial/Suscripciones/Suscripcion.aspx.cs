using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de la suscripción (ANEXO F §5 y §8).
///
/// TRES OPERACIONES DISTINTAS EN UNA PANTALLA, Y NO ES UN DESCUIDO
///   Crear la suscripción, mantener su contacto y cambiar de plan son cosas
///   distintas y están detrás de permisos distintos, pero pasan sobre el
///   mismo objeto y quien las hace necesita ver el mismo contexto: qué plan
///   tiene hoy, hasta cuándo está vigente, a quién se le cobra. Separarlas
///   en tres pantallas obligaría a repetir ese contexto tres veces.
///
///   El plan del combo de arriba solo se puede elegir al CREAR. Después es
///   solo lectura y el cambio pasa por la sección de abajo, porque cambiar
///   el plan tiene consecuencias de cobro que UPD_SUSCRIPCION no aplica:
///   las aplica UPS_SUSCRIPCION_PLAN.
/// </summary>
public partial class View_Comercial_Suscripciones_Suscripcion : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        /* Querystring.Entero y no Crypto.Decrypt directo: el listado abre
           esta ficha con abrirSuscripcion(0) para "Nueva", asi que llega
           literalmente ?query=0, que no es texto cifrado valido.
           Descifrarlo sin red lanzaba y la pagina respondia 500 antes de
           pintar nada. */
        if (!IsPostBack) Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                if (ctrl.ID == "cboPlan" || ctrl.ID == "cboPlanNuevo")
                {
                    /* GetPlanesDistintos y no GetPlanesComerciales:
                       SEL_PLAN_COMERCIAL devuelve una fila por plan Y
                       periodicidad, así que el mismo plan aparecería tres
                       veces en el combo y quien elija no sabría cuál marcó. */
                    PlanComercialController controller = new PlanComercialController();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetPlanesDistintos();
                    ctrl.DataValueField = "plc_id";
                    ctrl.DataTextField = "plc_nombre";
                    ctrl.DataBind();
                }

                if (ctrl.ID == "cboEstado")
                {
                    CatalogoController controller = new CatalogoController();

                    ctrl.DataSource = controller.GetValoresPorCodigo("SUSCRIPCION_ESTADO", SitioBase.Session.ClienteId());
                    ctrl.DataValueField = "valor_id";
                    ctrl.DataTextField = "valor_nombre";
                    ctrl.DataBind();
                }

                if (ctrl.ID == "cboPeriodicidad")
                {
                    CatalogoController controller = new CatalogoController();

                    // Vacío = la misma periodicidad del período vigente. Es
                    // lo normal en un cambio de plan: se cambia el plan, no
                    // la forma de pago.
                    ctrl.Items.Add(new RadComboBoxItem("La misma de hoy", ""));
                    ctrl.AppendDataBoundItems = true;
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
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnCambiarPlan);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnReemitirKey);
        udPanel.Update();
    }

    /// <summary>
    /// Reemite la clave. No hay "reenviar": la clave no está guardada en
    /// claro en ninguna parte, así que lo único que se puede hacer es
    /// generar otra.
    ///
    /// La nueva se muestra en el mismo recuadro que al crear y SIN cerrar
    /// el modal: cerrarlo se la llevaría puesta, y esta vez además habría
    /// dejado al cliente sin la anterior.
    /// </summary>
    protected void btnReemitirKey_Click(object sender, EventArgs e)
    {
        try
        {
            if (Id == 0) throw new Exception("Primero guarde la suscripción.");

            SuscripcionController controller = new SuscripcionController();
            Suscripcion entidad = new Suscripcion { sus_id = Id };

            Respuesta respuesta = controller.ReemitirKey(entidad, txtMotivoKey.Text);

            if (respuesta.error)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                return;
            }

            litClave.Text =
                "<strong>Clave de suscripción reemitida</strong><br />" +
                "<span style=\"font-family: 'Courier New', monospace; font-size: 16px; " +
                "font-weight: 700; letter-spacing: .04em;\">" +
                Server.HtmlEncode(entidad.key_texto) + "</span><br />" +
                "Cópiela ahora y hágasela llegar al cliente. La anterior ya no sirve, así que " +
                "su instalación está desconectada hasta que cargue esta.";

            pnlClave.Visible = true;
            txtMotivoKey.Text = "";

            // Refresca el prefijo que se muestra arriba.
            Suscripcion actual = controller.GetSuscripcion(new Suscripcion { sus_id = Id });

            lblKey.Text = string.IsNullOrEmpty(actual.sus_key_prefijo)
                ? ""
                : Server.HtmlEncode(actual.sus_key_prefijo) +
                  "-&bull;&bull;&bull;&bull;-&bull;&bull;&bull;&bull;-&bull;&bull;&bull;&bull;-&bull;&bull;&bull;&bull;";

            Tools.tools.ClientAlert(respuesta.detalle, "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        litCliente.Text = Server.HtmlEncode(SitioBase.Session.ClienteNombre());

        if (Id > 0)
        {
            SuscripcionController controller = new SuscripcionController();
            Suscripcion entidad = controller.GetSuscripcion(new Suscripcion { sus_id = Id });

            lblId.Text = Id.ToString();

            litTitulo.Text = "Suscripción " + Server.HtmlEncode(entidad.cli_nombre);

            lblKey.Text = string.IsNullOrEmpty(entidad.sus_key_prefijo)
                ? ""
                : Server.HtmlEncode(entidad.sus_key_prefijo) +
                  "-&bull;&bull;&bull;&bull;-&bull;&bull;&bull;&bull;-&bull;&bull;&bull;&bull;-&bull;&bull;&bull;&bull;";

            PintarHero(entidad);

            txtContactoNombre.Text = entidad.sus_contacto_nombre;
            txtContactoEmail.Text = entidad.sus_contacto_email;
            txtContactoTelefono.Text = entidad.sus_contacto_telefono;
            txtObservacion.Text = entidad.sus_observacion;

            if (entidad.sus_plan_comercial != null)
                cboPlan.SelectedValue = entidad.sus_plan_comercial.ToString();

            cboEstado.SelectedValue = entidad.sus_suscripcion_estado.ToString();

            rdbSi.Checked = entidad.sus_habilitado;
            rdbNo.Checked = !entidad.sus_habilitado;

            litPlanActual.Text = "<span class=\"sigma-modal-ayuda\">" +
                                 "El plan no se cambia desde acá: use la sección de abajo." +
                                 "</span>";

            pnlCambioPlan.Visible = Token.Puede("CAMBIAR PLAN SUSCRIPCION");
            pnlReemitir.Visible = Token.Puede("REEMITIR KEY SUSCRIPCION");
        }
        else
        {
            lblId.Text = "Nueva";
            lblKey.Text = "Se genera al guardar.";

            litTitulo.Text = "Nueva suscripción";
            litChipEstado.Text = "<span class=\"sigma-modal-chip is-neutro\">Sin crear</span>";
            litHeroTitulo.Text = Server.HtmlEncode(SitioBase.Session.ClienteNombre());
            litHeroDetalle.Text = "Elija el plan y guarde. La clave de suscripción se genera en ese " +
                                  "momento y se muestra una sola vez.";

            pnlCambioPlan.Visible = false;
            pnlReemitir.Visible = false;
        }
    }

    /// <summary>
    /// El resumen de arriba: qué es y cómo está, antes de que nadie lea un
    /// campo.
    ///
    /// El estado que se pinta es el CALCULADO -el de
    /// FNC_SUSCRIPCION_VIGENTE- y no el guardado, porque es el que decide
    /// si el cliente puede trabajar hoy. El guardado se edita más abajo,
    /// en su combo.
    /// </summary>
    private void PintarHero(Suscripcion entidad)
    {
        litHeroTitulo.Text = Server.HtmlEncode(entidad.cli_nombre) +
                             (string.IsNullOrEmpty(entidad.plc_nombre)
                                 ? ""
                                 : " &middot; plan " + Server.HtmlEncode(entidad.plc_nombre));

        string estado = (entidad.estado ?? "").Trim();

        if (entidad.sus_fecha_fin == null)
        {
            litChipEstado.Text = "<span class=\"sigma-modal-chip is-neutro\">Sin períodos</span>";
            litHeroDetalle.Text = "Todavía no se ha emitido ningún período, así que la suscripción " +
                                  "existe pero no habilita nada. Cobrar es lo que la pone en marcha.";
            return;
        }

        string clase = entidad.puede_operar ? "is-exito" : "is-alerta";

        // En gracia opera, pero es un aviso: se acabó el período y está
        // usando el colchón del plan.
        if (estado.ToUpper() == "EN GRACIA") clase = "is-info";

        litChipEstado.Text = "<span class=\"sigma-modal-chip " + clase + "\">" +
                             Server.HtmlEncode(estado) + "</span>";

        string detalle = "Vigente hasta el " + entidad.sus_fecha_fin.Value.ToString("dd-MM-yyyy");

        if (entidad.dias_restantes != null)
        {
            detalle += (entidad.dias_restantes >= 0)
                ? " &middot; quedan " + entidad.dias_restantes + " día(s)."
                : " &middot; venció hace " + Math.Abs(entidad.dias_restantes.Value) + " día(s). " +
                  "Los días de gracia del plan son " + entidad.sus_dias_gracia + ".";
        }
        else
        {
            detalle += ".";
        }

        if (!entidad.puede_operar)
            detalle += " <strong>El cliente no puede operar.</strong>";

        litHeroDetalle.Text = detalle;
    }

    protected void Bloqueo()
    {
        /* Token.Puede y NO Token.PuedeFuncion.
           PuedeFuncion resuelve las funciones DE LA PAGINA ACTUAL, y esta
           ficha es una pagina distinta del listado: Menu_Funcion cuelga de
           Suscripciones.aspx, no de Suscripcion.aspx. Preguntando por
           funcion desde aca la respuesta era siempre false y la ficha se
           abria en solo lectura hasta para Root. En las fichas se pregunta
           por el CODIGO del permiso, como hace Planta.aspx. */
        bool puedeEditar = Token.Puede("CREAR EDITAR SUSCRIPCIONES");

        txtContactoNombre.ReadOnly = !puedeEditar;
        txtContactoEmail.ReadOnly = !puedeEditar;
        txtContactoTelefono.ReadOnly = !puedeEditar;
        txtObservacion.ReadOnly = !puedeEditar;
        cboEstado.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;

        // El plan se elige una sola vez, al crear.
        cboPlan.ReadOnly = (Id > 0) || !puedeEditar;

        // Estado y habilitado no aplican a una suscripción que todavía no
        // existe: nace activa y habilitada.
        /* Se oculta la TARJETA entera, no solo el control: dejar la tarjeta
           con su label y un hueco donde deberia ir el combo se lee como un
           campo roto. */
        pnlEstado.Visible = (Id > 0);
        pnlHabilitada.Visible = (Id > 0);
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            SuscripcionController controller = new SuscripcionController();
            Suscripcion entidad = new Suscripcion();

            entidad.sus_id = Id;
            entidad.sus_cliente = SitioBase.Session.ClienteId();
            entidad.sus_contacto_nombre = txtContactoNombre.Text.Trim();
            entidad.sus_contacto_email = txtContactoEmail.Text.Trim();
            entidad.sus_contacto_telefono = txtContactoTelefono.Text.Trim();
            entidad.sus_observacion = txtObservacion.Text.Trim();

            Respuesta respuesta;

            if (Id > 0)
            {
                entidad.sus_suscripcion_estado = int.Parse(cboEstado.SelectedValue);
                entidad.sus_habilitado = rdbSi.Checked;

                respuesta = controller.UpdateSuscripcion(entidad);
            }
            else
            {
                if (string.IsNullOrEmpty(cboPlan.SelectedValue))
                    throw new Exception("Debe elegir un plan.");

                entidad.sus_plan_comercial = int.Parse(cboPlan.SelectedValue);

                respuesta = controller.InsertSuscripcion(entidad);

                /* La clave en claro existe solo en esta vuelta. La base
                   guarda el prefijo y el hash, así que si no se copia
                   ahora hay que emitir una nueva. Se muestra sin cerrar el
                   modal a propósito: cerrarlo se la llevaría puesta. */
                if (!respuesta.error && !string.IsNullOrEmpty(entidad.key_texto))
                {
                    Id = respuesta.codigo;

                    litClave.Text =
                        "<strong>Clave de suscripción</strong><br />" +
                        "<span style=\"font-family: 'Courier New', monospace; font-size: 16px; " +
                        "font-weight: 700; letter-spacing: .04em;\">" +
                        Server.HtmlEncode(entidad.key_texto) + "</span><br />" +
                        "Cópiela ahora. No se guarda en claro en ningún lado: de acá en adelante solo " +
                        "queda su prefijo y un hash. Si se pierde, hay que emitir una nueva.";

                    pnlClave.Visible = true;

                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
                    return;
                }
            }

            if (!respuesta.error)
            {
                if (Id == 0) Id = respuesta.codigo;
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

    /// <summary>
    /// Sube o baja de plan (§8). Cuál de las dos cosas es lo decide el SP
    /// comparando el orden de los planes, no esta pantalla: el orden es la
    /// escalera declarada del modelo comercial y compararlo por precio
    /// daría lo mismo hasta el día en que un plan superior salga en oferta.
    /// </summary>
    protected void btnCambiarPlan_Click(object sender, EventArgs e)
    {
        try
        {
            if (Id == 0)
                throw new Exception("Primero guarde la suscripción.");

            if (string.IsNullOrEmpty(cboPlanNuevo.SelectedValue))
                throw new Exception("Debe elegir el plan nuevo.");

            int planNuevo = int.Parse(cboPlanNuevo.SelectedValue);

            int? periodicidad = null;
            if (!string.IsNullOrEmpty(cboPeriodicidad.SelectedValue))
                periodicidad = int.Parse(cboPeriodicidad.SelectedValue);

            SuscripcionController controller = new SuscripcionController();

            Respuesta respuesta = controller.CambiarPlan(new Suscripcion { sus_id = Id }, planNuevo, periodicidad);

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok", !respuesta.error);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
