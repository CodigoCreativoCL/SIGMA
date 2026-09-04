using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un area de planta (HU-012).
/// </summary>
public partial class View_Organizacion_Areas_Area : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>
    /// El área de la que va a colgar esta, cuando se entró por "nueva
    /// subárea" desde una rama del listado.
    /// </summary>
    public int Padre
    {
        get { return ViewState["Padre"] != null ? (int)ViewState["Padre"] : 0; }
        set { ViewState["Padre"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack && Request.QueryString["query"] != null)
        {
            string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "Id":
                        Id = Int32.Parse(array[1].ToString());
                        break;

                    /* "Nueva subárea acá dentro": el listado ya sabe de qué
                       rama cuelga, así que lo manda resuelto. Antes había que
                       abrir "Nueva" y volver a buscar el padre en el
                       desplegable, que es pedirle a alguien que escriba lo
                       que estaba mirando un segundo antes. */
                    case "Padre":
                        int padre;
                        if (int.TryParse(array[1].ToString(), out padre) && padre > 0)
                            Padre = padre;
                        break;
                }
            }
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                switch (ctrl.ID)
                {
                    case "cboPlanta":

                        ClienteInstalacion filtroPlanta = new ClienteInstalacion();
                        filtroPlanta.filtro_cliente = SitioBase.Session.ClienteId().ToString();
                        filtroPlanta.filtro_habilitado = "1";

                        ClienteInstalacionController ctrlPlanta = new ClienteInstalacionController();

                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = ctrlPlanta.GetClienteInstalaciones(filtroPlanta);
                        ctrl.DataValueField = "cin_id";
                        ctrl.DataTextField = "cin_nombre";
                        ctrl.DataBind();
                        break;

                    case "cboTipo":

                        CatalogoController ctrlCatalogo = new CatalogoController();

                        ctrl.Items.Add(new RadComboBoxItem("Sin tipo", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = ctrlCatalogo.GetValoresPorCodigo("INSTALACION_AREA_TIPO", SitioBase.Session.ClienteId());
                        ctrl.DataValueField = "valor_id";
                        ctrl.DataTextField = "valor_nombre";
                        ctrl.DataBind();
                        break;
                }
            }
        }
    }

    /// <summary>
    /// El combo de area superior depende de la planta elegida: un area solo
    /// puede colgar de otra de SU planta. Por eso se recarga cada vez que
    /// la planta cambia, y no una sola vez en !IsPostBack.
    /// </summary>
    protected void CargarAreasPadre()
    {
        cboPadre.Items.Clear();
        cboPadre.Items.Add(new RadComboBoxItem("Área de primer nivel", ""));
        cboPadre.AppendDataBoundItems = true;

        if (string.IsNullOrEmpty(cboPlanta.SelectedValue))
        {
            cboPadre.DataSource = null;
            cboPadre.DataBind();
            return;
        }

        InstalacionArea filtro = new InstalacionArea();
        filtro.iar_cliente = SitioBase.Session.ClienteId();
        filtro.iar_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
        filtro.filtro_habilitado = true;

        InstalacionAreaController controller = new InstalacionAreaController();
        List<InstalacionArea> lista = controller.GetInstalacionAreas(filtro);

        if (lista != null)
        {
            // Un area no puede ser su propio padre. El resto de la
            // descendencia la corta UPD_INSTALACION_AREA recorriendo el
            // arbol; aqui se quita el caso obvio para no ofrecer una
            // opcion que la base va a rechazar.
            if (Id > 0) lista.RemoveAll(x => x.iar_id == Id);

            cboPadre.DataSource = lista;
            cboPadre.DataValueField = "iar_id";
            cboPadre.DataTextField = "ruta";
            cboPadre.DataBind();
        }
    }

    protected void cboPlanta_SelectedIndexChanged(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        CargarAreasPadre();
        udPanel.Update();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            InstalacionAreaController controller = new InstalacionAreaController();
            InstalacionArea entidad = controller.GetInstalacionArea(new InstalacionArea { iar_id = Id });

            lblId.Text = Id.ToString();
            cboPlanta.SelectedValue = entidad.iar_cliente_instalacion.ToString();

            CargarAreasPadre();

            if (entidad.iar_area_padre != null)
                cboPadre.SelectedValue = entidad.iar_area_padre.ToString();

            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Instalacion_Area", entidad.iar_codigo);
            txtNombre.Text = entidad.iar_nombre;
            txtDescripcion.Text = entidad.iar_descripcion;

            if (entidad.iar_instalacion_area_tipo != null)
                cboTipo.SelectedValue = entidad.iar_instalacion_area_tipo.ToString();

            rdbSi.Checked = entidad.iar_habilitado;
            rdbNo.Checked = !entidad.iar_habilitado;
        }
        else
        {
            lblId.Text = "Nueva";

            /* La planta se toma del padre: una subárea no puede estar en una
               planta distinta de aquella de la que cuelga, y preguntarlo
               sería ofrecer una respuesta incorrecta. */
            if (Padre > 0)
            {
                InstalacionAreaController controller = new InstalacionAreaController();
                InstalacionArea padre = controller.GetInstalacionArea(
                    new InstalacionArea { iar_id = Padre });

                if (padre != null && padre.iar_id > 0)
                    cboPlanta.SelectedValue = padre.iar_cliente_instalacion.ToString();
            }

            CargarAreasPadre();

            if (Padre > 0)
            {
                RadComboBoxItem item = cboPadre.FindItemByValue(Padre.ToString());
                if (item != null) item.Selected = true;
            }
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR AREAS");

        cboPlanta.ReadOnly = !puedeEditar;
        cboPadre.ReadOnly = !puedeEditar;
        cboTipo.ReadOnly = !puedeEditar;
        /* Nunca se escribe a mano: lo genera el SP al crear, y despues
               identifica el registro. */
            litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Instalacion_Area");
            txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;

        // La planta no se cambia despues de creada: mover un area a otra
        // planta dejaria a sus subareas y sus activos en otro sitio del que
        // creen estar. Se crea de nuevo donde corresponda.
        if (Id > 0) cboPlanta.Enabled = false;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboPlanta.SelectedValue))
            {
                Tools.tools.ClientAlert("Debe indicar la planta.", "alerta");
                return;
            }

            InstalacionArea entidad = new InstalacionArea();
            InstalacionAreaController controller = new InstalacionAreaController();

            entidad.iar_id = Id;
            entidad.iar_cliente = SitioBase.Session.ClienteId();
            entidad.iar_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como ARE-<id>: el
               codigo depende del ID, y el ID no existe hasta despues del
               INSERT, asi que no hay forma de calcularlo antes.

               AUTO y no vacio: el SP valida que el codigo venga ANTES de
               insertar, asi que un vacio se rechaza con "indique el codigo".
               AUTO pasa esa validacion, nunca queda guardado, y el SP lo
               reemplaza en cuanto conoce el ID.

               Al editar viaja el que ya tiene. No se regenera nunca: el
               codigo esta impreso en su etiqueta, y cambiarlo dejaria la
               etiqueta pegada apuntando a algo que no existe. */
            entidad.iar_codigo = SitioBase.CodigoModulo.Componer("Instalacion_Area", txtCodigo.Text);
            entidad.iar_nombre = txtNombre.Text.Trim();
            entidad.iar_descripcion = txtDescripcion.Text.Trim();
            entidad.iar_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboTipo.SelectedValue))
                entidad.iar_instalacion_area_tipo = int.Parse(cboTipo.SelectedValue);

            if (!string.IsNullOrEmpty(cboPadre.SelectedValue))
                entidad.iar_area_padre = int.Parse(cboPadre.SelectedValue);
            else
                entidad.quita_padre = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateInstalacionArea(entidad)
                : controller.InsertInstalacionArea(entidad);

            if (!respuesta.error)
            {
                Id = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}
