using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System.Configuration;
using System;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una planta (HU-011).
/// </summary>
public partial class View_Organizacion_Plantas_Planta : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>
    /// El cliente dueno de la planta.
    ///
    /// Sale del querystring si viene, y si no del cliente en sesion.
    ///
    /// La distincion importa desde que esta ficha atiende a los dos caminos:
    /// Organizacion > Plantas trabaja siempre sobre el cliente en sesion,
    /// pero Comercial > Cliente > pestana Plantas abre la ficha de UNA
    /// empresa concreta, que no tiene por que ser la de la sesion -es
    /// justamente lo que hace un administrador de plataforma configurando a
    /// un cliente-. Tomar el de sesion en ese caso guardaria la planta en la
    /// empresa equivocada.
    /// </summary>
    public int IdCliente
    {
        get
        {
            int id = ViewState["IdCliente"] != null ? (int)ViewState["IdCliente"] : 0;
            return id > 0 ? id : SitioBase.Session.ClienteId();
        }
        set { ViewState["IdCliente"] = value; }
    }

    /// <summary>
    /// El nombre del cliente que se muestra en el encabezado.
    ///
    /// Si la ficha se abrio sobre otro cliente que el de la sesion, hay que
    /// ir a buscarlo: poner el de la sesion diria una empresa y guardaria en
    /// otra, que es la peor combinacion posible.
    /// </summary>
    protected string NombreCliente()
    {
        if (IdCliente == SitioBase.Session.ClienteId())
            return SitioBase.Session.ClienteNombre();

        SitioBase.Model.Cliente c = new SitioBase.Model.Cliente();
        c.cli_id = IdCliente;
        c = new ClienteController().GetCliente(c);

        return c != null && !string.IsNullOrEmpty(c.cli_nombre) ? c.cli_nombre : "";
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        /* Querystring.Entero y no Crypto.Decrypt directo: el listado abre
           esta ficha con abrirPlanta(0) para "Nueva", asi que llega
           literalmente ?query=0, que no es texto cifrado valido.
           Descifrarlo sin red lanzaba y la pagina respondia 500. */
        if (!IsPostBack)
        {
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            IdCliente = SitioBase.Querystring.Entero(Request.QueryString["query"], "IdCliente");
        }

        CargarMapas();

        /* El geocodificador se dispara al SALIR del campo, no en cada tecla:
           "Camino a Melipilla 12" a medio escribir es una direccion valida
           en otra comuna, y buscarla mientras se teclea llenaria las
           coordenadas con un punto equivocado antes de terminar. */
        txtDireccion.Attributes["onblur"] = "sigmaGeo(false);";
    }

    /// <summary>
    /// Inyecta la Maps JavaScript API con la clave de Web.config.
    ///
    /// Si no hay clave, no se emite el script y la ficha sigue funcionando:
    /// las coordenadas se escriben a mano. Son un dato de apoyo, no una
    /// condicion para guardar una planta, y dejar la pantalla inutilizable
    /// por una configuracion faltante seria desproporcionado.
    /// </summary>
    private void CargarMapas()
    {
        string clave = ConfigurationManager.AppSettings["GoogleMapsApiKey"];

        if (string.IsNullOrEmpty(clave) || clave == "PENDIENTE")
        {
            litMaps.Text = "";
            return;
        }

        litMaps.Text =
            "<script src=\"https://maps.googleapis.com/maps/api/js?key=" +
            Server.UrlEncode(clave) + "&v=quarterly\" async defer></script>";
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                if (ctrl.ID == "cboZonaHoraria")
                {
                    // Las zonas horarias son un catálogo del sistema: se leen
                    // por el registro de catálogos y no con un controller
                    // propio, que para una tabla de dos columnas sería puro
                    // código repetido.
                    CatalogoController controller = new CatalogoController();

                    ctrl.Items.Add(new RadComboBoxItem("Hereda la del cliente", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetValoresPorCodigo("ZONA_HORARIA", IdCliente);
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
        PintarSecciones();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ClienteInstalacionController controller = new ClienteInstalacionController();
            ClienteInstalacion entidad = controller.GetClienteInstalacion(new ClienteInstalacion { cin_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Cliente_Instalacion", entidad.cin_codigo);
            txtNombre.Text = entidad.cin_nombre;
            txtDireccion.Text = entidad.cin_direccion;
            txtDescripcion.Text = entidad.cin_descripcion;

            if (entidad.cin_zona_horaria != null)
                cboZonaHoraria.SelectedValue = entidad.cin_zona_horaria.ToString();

            // InvariantCulture al mostrar: las coordenadas usan punto
            // decimal. Con la cultura local es-CL saldrían con coma y al
            // volver a guardarlas no parsearían.
            if (entidad.cin_latitud != null)
                txtLatitud.Text = entidad.cin_latitud.Value.ToString(CultureInfo.InvariantCulture);
            if (entidad.cin_longitud != null)
                txtLongitud.Text = entidad.cin_longitud.Value.ToString(CultureInfo.InvariantCulture);

            rdbSi.Checked = entidad.cin_habilitado;
            rdbNo.Checked = !entidad.cin_habilitado;

            litTitulo.Text = Server.HtmlEncode(entidad.cin_nombre);

            litChipEstado.Text = entidad.cin_habilitado
                ? "<span class=\"sigma-modal-chip is-exito\">Habilitada</span>"
                : "<span class=\"sigma-modal-chip is-alerta\">Deshabilitada</span>";

            litHeroTitulo.Text = Server.HtmlEncode(entidad.cin_codigo) + " &middot; " +
                                 Server.HtmlEncode(entidad.cin_nombre);

            litHeroDetalle.Text = string.IsNullOrEmpty(entidad.cin_direccion)
                ? "Sin dirección registrada."
                : Server.HtmlEncode(entidad.cin_direccion);
        }
        else
        {
            lblId.Text = "Nueva";

            litTitulo.Text = "Nueva planta";
            litChipEstado.Text = "<span class=\"sigma-modal-chip is-neutro\">Sin guardar</span>";
            litHeroTitulo.Text = Server.HtmlEncode(NombreCliente());
            litHeroDetalle.Text = "Escriba la dirección y las coordenadas se buscan solas.";
        }

        litCliente.Text = Server.HtmlEncode(NombreCliente());
    }

    /// <summary>
    /// Las dos secciones que antes eran pestanas de NuevaInstalacion.aspx.
    ///
    /// Aparecen solo con la planta ya creada: las dos guardan contra su id,
    /// y una planta sin guardar todavia no tiene ninguno.
    /// </summary>
    protected void PintarSecciones()
    {
        pnlExistente.Visible = Id > 0;

        if (!pnlExistente.Visible) return;

        wucConfiguracionApp.IdCliente = IdCliente;
        wucConfiguracionApp.IdClienteInstalacion = Id;
        wucConfiguracionApp.ReadOnly = !Token.Puede("CREAR EDITAR PLANTAS");

        /* Perfiles de tipo CLIENTE. NuevaInstalacion pedia aqui los de tipo
           Sistema -Root, Soporte, Gerente Comercial-, que son las cuentas
           del equipo de SIGMA: la lista de responsables salia con la gente
           equivocada y sin ninguna de la empresa. */
        wucResponsables.IdCliente = IdCliente;
        wucResponsables.IdClienteInstalacion = Id;
        wucResponsables.TipoPerfil = (int)SitioBase.SitioBase.TipoPefil.Cliente;
        wucResponsables.ReadOnly = !Token.Puede("CREAR EDITAR PLANTAS");
        wucResponsables.Asociar = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR PLANTAS");

        /* Nunca se escribe a mano: lo genera el SP al crear, y despues
               identifica el registro. */
            litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Cliente_Instalacion");
            txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtDireccion.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        txtLatitud.ReadOnly = !puedeEditar;
        txtLongitud.ReadOnly = !puedeEditar;
        cboZonaHoraria.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    /// <summary>
    /// Lee una coordenada aceptando punto o coma como separador decimal.
    /// El teclado numérico de un teléfono en es-CL escribe coma; el
    /// copiado desde un mapa escribe punto. Rechazar uno de los dos sería
    /// hacer fallar la carga por una diferencia que no le importa a nadie.
    /// </summary>
    private decimal? LeerCoordenada(string texto, string nombreCampo, decimal minimo, decimal maximo)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim()))
            return null;

        decimal valor;
        string normalizado = texto.Trim().Replace(",", ".");

        if (!decimal.TryParse(normalizado, NumberStyles.Float, CultureInfo.InvariantCulture, out valor))
            throw new Exception("La " + nombreCampo + " no es un número válido.");

        if (valor < minimo || valor > maximo)
            throw new Exception("La " + nombreCampo + " debe estar entre " + minimo + " y " + maximo + ".");

        return valor;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            ClienteInstalacion entidad = new ClienteInstalacion();
            ClienteInstalacionController controller = new ClienteInstalacionController();

            entidad.cin_id = Id;
            entidad.cin_cliente = IdCliente;
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como PLA-<id>: el
               codigo depende del ID, y el ID no existe hasta despues del
               INSERT, asi que no hay forma de calcularlo antes.

               AUTO y no vacio: el SP valida que el codigo venga ANTES de
               insertar, asi que un vacio se rechaza con "indique el codigo".
               AUTO pasa esa validacion, nunca queda guardado, y el SP lo
               reemplaza en cuanto conoce el ID.

               Al editar viaja el que ya tiene. No se regenera nunca: el
               codigo esta impreso en su etiqueta, y cambiarlo dejaria la
               etiqueta pegada apuntando a algo que no existe. */
            entidad.cin_codigo = SitioBase.CodigoModulo.Componer("Cliente_Instalacion", txtCodigo.Text);
            entidad.cin_nombre = txtNombre.Text.Trim();
            entidad.cin_direccion = txtDireccion.Text.Trim();
            entidad.cin_descripcion = txtDescripcion.Text.Trim();
            entidad.cin_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboZonaHoraria.SelectedValue))
                entidad.cin_zona_horaria = int.Parse(cboZonaHoraria.SelectedValue);

            entidad.cin_latitud = LeerCoordenada(txtLatitud.Text, "latitud", -90, 90);
            entidad.cin_longitud = LeerCoordenada(txtLongitud.Text, "longitud", -180, 180);

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateClienteInstalacion(entidad)
                : controller.InsertClienteInstalacion(entidad);

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
}
