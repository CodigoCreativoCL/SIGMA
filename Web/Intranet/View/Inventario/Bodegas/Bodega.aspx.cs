using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una bodega y sus ubicaciones (HU-052).
///
/// LAS UBICACIONES VIVEN AQUI Y NO EN SU PROPIO MANTENEDOR
///   Una ubicacion sin bodega no significa nada. Un mantenedor aparte
///   obligaria a elegir la bodega otra vez, en una pantalla que ya sabe
///   cual es.
/// </summary>
public partial class View_Inventario_Bodegas_Bodega : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>
    /// La ubicación que se está editando. Cero es "ninguna, se va a
    /// agregar una nueva". Vive en ViewState porque el alta y la edición
    /// comparten los mismos dos campos: sin esto, al guardar no habría
    /// forma de saber cuál de las dos cosas se pidió.
    /// </summary>
    public int UbicacionId
    {
        get { return ViewState["UbicacionId"] != null ? (int)ViewState["UbicacionId"] : 0; }
        set { ViewState["UbicacionId"] = value; }
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

            if (ctrl.ID == "cboPlanta")
            {
                ClienteInstalacionController controller = new ClienteInstalacionController();

                /* filtro_cliente y filtro_habilitado son STRING en este
                   modelo, no int ni bool. Es la convencion heredada de
                   ClienteInstalacion y se respeta tal cual: cambiarla aca
                   dejaria dos formas de llamar al mismo controller. */
                ClienteInstalacion filtro = new ClienteInstalacion();
                filtro.filtro_cliente = SitioBase.Session.ClienteId().ToString();
                filtro.filtro_habilitado = "1";

                ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                ctrl.AppendDataBoundItems = true;
                ctrl.DataSource = controller.GetClienteInstalaciones(filtro);
                ctrl.DataValueField = "cin_id";
                ctrl.DataTextField = "cin_nombre";
                ctrl.DataBind();
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarUbicaciones();
        Bloqueo();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnAgregarUbicacion);

        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            BodegaController controller = new BodegaController();
            Bodega entidad = controller.GetBodega(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = entidad.bod_codigo;
            txtNombre.Text = entidad.bod_nombre;
            txtDescripcion.Text = entidad.bod_descripcion;

            if (entidad.bod_cliente_instalacion > 0)
                cboPlanta.SelectedValue = entidad.bod_cliente_instalacion.ToString();

            rdbSi.Checked = entidad.bod_habilitado;
            rdbNo.Checked = !entidad.bod_habilitado;

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.bod_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.bod_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nueva";
        }
    }

    /// <summary>
    /// La grilla de ubicaciones se recarga en cada PreRender, no solo al
    /// entrar: despues de agregar una, la lista tiene que mostrarla sin que
    /// nadie recargue la pantalla.
    /// </summary>
    protected void CargarUbicaciones()
    {
        /* La pestaña se oculta entera, no el panel: una pestaña que al
           abrirla no tiene nada se lee como que la pantalla se rompió. */
        tabUbicaciones.Visible = (Id > 0);
        pnlUbicaciones.Visible = (Id > 0);

        if (Id == 0) return;

        if (GridUbicaciones.Columns.Count == 0)
        {
            GridUbicaciones.AddColumn("BUB_CODIGO", "CÓDIGO", Width: "30%");
            GridUbicaciones.AddColumn("BUB_NOMBRE", "NOMBRE", Width: "55%");
            GridUbicaciones.AddTemplateColumn("EDITAR", "", "", Width: "15%",
                                              ItemPosition: HorizontalAlign.Right, HederPosition: HorizontalAlign.Right);
        }

        BodegaController controller = new BodegaController();

        GridUbicaciones.DataSource = controller.GetUbicaciones(
            new BodegaUbicacion { bub_bodega = Id, filtro_habilitado = true });

        GridUbicaciones.DataBind();
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR BODEGAS");

        // El codigo solo se escribe al crear: despues identifica la bodega.
        txtCodigo.ReadOnly = !puedeEditar || Id > 0;
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
        btnAgregarUbicacion.Visible = puedeEditar;
        ModoUbicacion();
        txtUbiCodigo.ReadOnly = !puedeEditar;
        txtUbiNombre.ReadOnly = !puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboPlanta.SelectedValue))
                throw new Exception("Debe elegir la planta a la que pertenece la bodega.");

            Bodega entidad = new Bodega();
            BodegaController controller = new BodegaController();

            entidad.bod_id = Id;
            entidad.bod_codigo = txtCodigo.Text.Trim();
            entidad.bod_nombre = txtNombre.Text.Trim();
            entidad.bod_descripcion = txtDescripcion.Text.Trim();
            entidad.bod_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            entidad.bod_habilitado = rdbSi.Checked;

            /* Deshabilitar pasa por DEL_BODEGA, que es el camino con guarda:
               UPD_BODEGA tambien lo haria, pero sin comprobar la existencia
               ni arrastrar las ubicaciones. Si rechaza, no se guarda nada
               mas: seguir seria entrar por la puerta que acaba de cerrarse. */
            if (Id > 0 && rdbNo.Checked)
            {
                Respuesta baja = controller.DeleteBodega(Id);

                if (baja.error)
                {
                    Tools.tools.ClientAlert(baja.detalle, "alerta");
                    return;
                }
            }

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateBodega(entidad)
                : controller.InsertBodega(entidad);

            if (!respuesta.error)
            {
                /* Al crear NO se cierra: la bodega recien nacida no tiene
                   ubicaciones, y cerrar aca dejaria la sensacion de haber
                   terminado algo que esta a medias. */
                if (Id == 0)
                {
                    Id = respuesta.codigo;
                    Tools.tools.ClientAlert(respuesta.detalle + " Agregue sus ubicaciones.", "ok");
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

    /// <summary>
    /// El lápiz de cada fila. Va como control y no como un &lt;a&gt; con
    /// javascript porque la edición ocurre dentro del UpdatePanel: un
    /// enlace tendría que reconstruir el postback a mano.
    /// </summary>
    protected void GridUbicaciones_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = (GridDataItem)e.Item;

        if (!Token.Puede("CREAR EDITAR BODEGAS")) return;

        LinkButton btn = new LinkButton();
        btn.CommandName = "EditarUbicacion";
        btn.CommandArgument = item.GetDataKeyValue("bub_id").ToString();
        btn.CssClass = "sigma-grid-accion";
        btn.ToolTip = "Editar esta ubicación";
        btn.Text = "<i class=\"mdi mdi-pencil-outline\"></i>";

        item["EDITAR"].Controls.Add(btn);
    }

    protected void GridUbicaciones_ItemCommand(object source, GridCommandEventArgs e)
    {
        if (e.CommandName != "EditarUbicacion") return;

        try
        {
            int id = Convert.ToInt32(e.CommandArgument);

            BodegaController controller = new BodegaController();

            List<BodegaUbicacion> lista = controller.GetUbicaciones(
                new BodegaUbicacion { bub_id = id, bub_bodega = Id });

            if (lista == null || lista.Count == 0)
                throw new Exception("La ubicación ya no existe.");

            BodegaUbicacion u = lista[0];

            UbicacionId       = u.bub_id;
            txtUbiCodigo.Text = u.bub_codigo;
            txtUbiNombre.Text = u.bub_nombre;

            ModoUbicacion();
            udPanel.Update();
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void btnCancelarUbicacion_Click(object sender, EventArgs e)
    {
        LimpiarUbicacion();
        udPanel.Update();
    }

    /// <summary>
    /// El formulario dice lo que va a hacer. El mismo botón rotulado
    /// siempre "Agregar" mientras se edita una fila existente promete un
    /// alta y hace una modificación.
    /// </summary>
    protected void ModoUbicacion()
    {
        bool editando = UbicacionId > 0;

        btnAgregarUbicacion.Text     = editando ? "Guardar ubicación" : "Agregar ubicación";
        btnCancelarUbicacion.Visible = editando;

        /* El código identifica la ubicación y ya está impreso en la
           etiqueta del estante. Cambiarlo dejaría todas las etiquetas
           pegadas apuntando a algo que ya no existe. */
        txtUbiCodigo.ReadOnly = editando || !Token.Puede("CREAR EDITAR BODEGAS");
    }

    protected void LimpiarUbicacion()
    {
        UbicacionId       = 0;
        txtUbiCodigo.Text = "";
        txtUbiNombre.Text = "";
        ModoUbicacion();
    }

    protected void btnAgregarUbicacion_Click(object sender, EventArgs e)
    {
        try
        {
            if (Id == 0) throw new Exception("Primero guarde la bodega.");

            if (string.IsNullOrEmpty(txtUbiCodigo.Text.Trim()))
                throw new Exception("Indique el código de la ubicación.");

            BodegaUbicacion entidad = new BodegaUbicacion();
            entidad.bub_id     = UbicacionId;
            entidad.bub_bodega = Id;
            entidad.bub_codigo = txtUbiCodigo.Text.Trim();

            // Sin nombre, el codigo hace de nombre: obligar a escribir dos
            // veces "PA-E3-N2" no agrega informacion.
            entidad.bub_nombre = string.IsNullOrEmpty(txtUbiNombre.Text.Trim())
                                 ? txtUbiCodigo.Text.Trim()
                                 : txtUbiNombre.Text.Trim();

            entidad.bub_habilitado = true;

            BodegaController controller = new BodegaController();
            Respuesta respuesta = controller.GuardarUbicacion(entidad);

            if (!respuesta.error)
            {
                LimpiarUbicacion();
                CargarUbicaciones();
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
