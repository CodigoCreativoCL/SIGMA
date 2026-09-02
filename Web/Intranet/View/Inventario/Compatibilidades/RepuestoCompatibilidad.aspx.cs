using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una compatibilidad (HU-051, bloque 92).
///
/// UN ALCANCE POR FILA
///   Se elige de qué clase es —tipo, modelo o componente— y solo entonces
///   aparece el combo que corresponde. Ofrecer los tres a la vez invita a
///   llenar dos, y una fila con dos alcances no se puede leer: "aplica a las
///   bombas Y al modelo NB 65-200" admite dos interpretaciones distintas.
///   El SP lo rechaza; la pantalla directamente no deja llegar ahí.
///
/// EL REPUESTO NO SE CAMBIA
///   Mover una compatibilidad a otro repuesto no es editarla, es hacer otra
///   afirmación. Dejarlo pasar convierte un error de tipeo en un dato que
///   nadie vuelve a revisar.
/// </summary>
public partial class View_Inventario_Compatibilidades_RepuestoCompatibilidad : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        /* Querystring.Entero recibe el valor TAL COMO VIENE de la URL:
           descifra por dentro. Descifrarlo antes lo hace descifrar dos veces,
           la segunda falla, y como el helper no lanza devuelve 0 en silencio:
           la ficha se abre en blanco como si fuera un registro nuevo. */
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
                case "cboRepuesto":

                    RepuestoController ctrlRep = new RepuestoController();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlRep.GetRepuestos(new Repuesto { filtro_habilitado = true });
                    ctrl.DataValueField = "rep_id";
                    ctrl.DataTextField = "rep_codigo";
                    ctrl.DataBind();
                    break;

                case "cboTipo":

                    ActivoTipoController ctrlTipo = new ActivoTipoController();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlTipo.GetActivoTipos(
                        new ActivoTipo { filtro_cliente = SitioBase.Session.ClienteId(),
                                         filtro_habilitado = true });
                    ctrl.DataValueField = "ati_id";
                    ctrl.DataTextField = "ati_nombre";
                    ctrl.DataBind();
                    break;

                case "cboModelo":

                    ActivoModeloController ctrlModelo = new ActivoModeloController();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlModelo.GetModelos(new ActivoModelo { filtro_habilitado = true });
                    ctrl.DataValueField = "amo_id";
                    ctrl.DataTextField = "etiqueta";
                    ctrl.DataBind();
                    break;

                case "cboComponente":

                    ActivoComponenteController ctrlComp = new ActivoComponenteController();

                    List<ActivoComponente> comps = ctrlComp.GetComponentes(
                        new ActivoComponente { filtro_habilitado = true });

                    if (comps == null) comps = new List<ActivoComponente>();

                    /* Hoy la tabla está vacía —poblarla es del módulo de
                       activos—. Se dice, en vez de dejar un desplegable en
                       blanco que se lee como pantalla rota. */
                    if (comps.Count == 0)
                    {
                        ctrl.Items.Add(new RadComboBoxItem("Todavía no hay componentes registrados", ""));
                        ctrl.Enabled = false;
                        break;
                    }

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = comps;
                    ctrl.DataValueField = "aco_id";
                    ctrl.DataTextField = "etiqueta";
                    ctrl.DataBind();
                    break;
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        AjustarAlcance();
        Bloqueo();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    /// <summary>
    /// Solo se muestra el combo del alcance elegido.
    /// </summary>
    protected void AjustarAlcance()
    {
        string alcance = cboAlcance.SelectedValue;

        pnlTipo.Visible = (alcance == "TIPO");
        pnlModelo.Visible = (alcance == "MODELO");
        pnlComponente.Visible = (alcance == "COMPONENTE");

        if (alcance == "MODELO")
            litAyudaAlcance.Text = "Solo ese modelo. Un modelo parecido del mismo fabricante " +
                                   "puede no calzar.";
        else if (alcance == "COMPONENTE")
            litAyudaAlcance.Text = "Una posición concreta de una máquina concreta. Es el más " +
                                   "específico de los tres.";
        else
            litAyudaAlcance.Text = "Cubre TODOS los equipos de esa clase. Es el más amplio.";

        if (pnlComponente.Visible && !cboComponente.Enabled)
            litAyudaComponente.Text = "Los componentes se cargan desde el módulo de activos. " +
                                      "Mientras no existan, use el alcance por tipo o por modelo.";
    }

    protected void cboAlcance_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        AjustarAlcance();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            RepuestoCompatibilidadController controller = new RepuestoCompatibilidadController();
            RepuestoCompatibilidad c = controller.GetCompatibilidad(Id);

            /* Vuelve un objeto vacío cuando el id no es de este cliente: no se
               muestra una ficha en blanco como si fuera un alta. */
            if (c == null || c.rco_id == 0)
            {
                lblId.Text = "—";
                btnGuardar.Visible = false;
                Tools.tools.ClientAlert("La compatibilidad no existe o no pertenece a su empresa.", "alerta");
                return;
            }

            lblId.Text = c.rco_id.ToString();

            RadComboBoxItem rep = cboRepuesto.FindItemByValue(c.rco_repuesto.ToString());
            if (rep != null) rep.Selected = true;

            cboAlcance.SelectedValue = c.alcance;

            if (c.rco_activo_tipo != null)
            {
                RadComboBoxItem i = cboTipo.FindItemByValue(c.rco_activo_tipo.Value.ToString());
                if (i != null) i.Selected = true;
            }

            if (c.rco_activo_modelo != null)
            {
                RadComboBoxItem i = cboModelo.FindItemByValue(c.rco_activo_modelo.Value.ToString());
                if (i != null) i.Selected = true;
            }

            if (c.rco_activo_componente != null)
            {
                RadComboBoxItem i = cboComponente.FindItemByValue(c.rco_activo_componente.Value.ToString());
                if (i != null) i.Selected = true;
            }

            txtObservacion.Text = c.rco_observacion;

            wucAuditoria.Mostrar(c.usuario_creacion_nombre, c.rco_fecha_creacion,
                                 c.usuario_actualizacion_nombre, c.rco_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nueva";
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.PuedeFuncion("Crear y editar");

        /* El repuesto se fija una sola vez: al editar no se cambia, porque
           eso sería otra afirmación y no una corrección. */
        cboRepuesto.ReadOnly = !puedeEditar || Id > 0;

        cboAlcance.ReadOnly = !puedeEditar;
        cboTipo.ReadOnly = !puedeEditar;
        cboModelo.ReadOnly = !puedeEditar;
        txtObservacion.ReadOnly = !puedeEditar;

        // El de componente ya puede venir deshabilitado por no haber datos.
        if (!puedeEditar) cboComponente.ReadOnly = true;

        if (!puedeEditar) btnGuardar.Visible = false;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se valida ACA, en el servidor: esconder el botón en Bloqueo() no
               es seguridad —quien manda el postback a mano se lo salta—. */
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para crear o editar compatibilidades.");

            int repuesto;

            if (!int.TryParse(cboRepuesto.SelectedValue, out repuesto) || repuesto == 0)
                throw new Exception("Indique el repuesto.");

            string alcance = cboAlcance.SelectedValue;

            RepuestoCompatibilidad entidad = new RepuestoCompatibilidad();
            entidad.rco_id = Id;
            entidad.rco_repuesto = repuesto;
            entidad.rco_observacion = txtObservacion.Text.Trim();

            int aux;

            if (alcance == "TIPO")
            {
                if (!int.TryParse(cboTipo.SelectedValue, out aux) || aux == 0)
                    throw new Exception("Indique el tipo de activo.");

                entidad.rco_activo_tipo = aux;
            }
            else if (alcance == "MODELO")
            {
                if (!int.TryParse(cboModelo.SelectedValue, out aux) || aux == 0)
                    throw new Exception("Indique el modelo.");

                entidad.rco_activo_modelo = aux;
            }
            else
            {
                if (!int.TryParse(cboComponente.SelectedValue, out aux) || aux == 0)
                    throw new Exception("Indique el componente. Si todavía no hay ninguno " +
                                        "registrado, use el alcance por tipo o por modelo.");

                entidad.rco_activo_componente = aux;
            }

            RepuestoCompatibilidadController controller = new RepuestoCompatibilidadController();

            Respuesta respuesta = (Id > 0)
                                ? controller.UpdateCompatibilidad(entidad)
                                : controller.InsertCompatibilidad(entidad);

            if (respuesta.error)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                return;
            }

            /* Se recuerda el id para que un segundo Guardar edite en vez de
               crear otra: sin esto, apretar dos veces intenta declarar la
               misma compatibilidad dos veces y el SP la rechaza con un
               mensaje que no explica lo que pasó. */
            if (Id == 0) Id = respuesta.codigo;

            Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
