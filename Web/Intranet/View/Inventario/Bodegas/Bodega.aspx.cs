using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using WebControls;

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
        CargarEtiquetas();
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
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Bodega", entidad.bod_codigo);
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

        BodegaController controller = new BodegaController();

        List<BodegaUbicacion> lista = controller.GetUbicaciones(
            new BodegaUbicacion { bub_bodega = Id, filtro_habilitado = true });

        pnlSinUbicaciones.Visible = (lista == null || lista.Count == 0);

        rptUbicaciones.DataSource = lista;
        rptUbicaciones.DataBind();
    }

    protected void rptUbicaciones_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        BodegaUbicacion u = (BodegaUbicacion)e.Item.DataItem;
        bool editando = (u.bub_id == UbicacionId);
        bool puedeEditar = Token.Puede("CREAR EDITAR BODEGAS");

        /* El id viaja en el CommandArgument de cada botón: es el único dato
           que el evento va a recibir, y sacarlo del índice de la fila se
           rompe en cuanto la lista se reordena entre un clic y el otro. */
        string id = u.bub_id.ToString();

        LinkButton editar = (LinkButton)e.Item.FindControl("lnkEditar");
        LinkButton guardar = (LinkButton)e.Item.FindControl("lnkGuardar");
        LinkButton cancelar = (LinkButton)e.Item.FindControl("lnkCancelar");

        editar.CommandArgument = id;
        guardar.CommandArgument = id;
        cancelar.CommandArgument = id;

        Panel vista = (Panel)e.Item.FindControl("pnlVista");
        Panel edicion = (Panel)e.Item.FindControl("pnlEdicion");

        vista.Visible = !editando;
        edicion.Visible = editando;

        /* Mientras una fila se edita, el lápiz del resto desaparece: dos
           filas abiertas a la vez dejarían dudando cuál se va a guardar. */
        editar.Visible = (!editando && UbicacionId == 0 && puedeEditar);
        guardar.Visible = editando;
        cancelar.Visible = editando;

        if (editando)
        {
            TextBox2 txt = (TextBox2)e.Item.FindControl("txtNombre");
            txt.Text = u.bub_nombre;
        }
        else
        {
            Literal lit = (Literal)e.Item.FindControl("litNombre");
            lit.Text = Server.HtmlEncode(u.bub_nombre);
        }
    }

    protected void rptUbicaciones_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        try
        {
            int id = 0;
            int.TryParse(Convert.ToString(e.CommandArgument), out id);

            if (e.CommandName == "Cancelar")
            {
                UbicacionId = 0;
            }
            else if (e.CommandName == "Editar")
            {
                if (!Token.Puede("CREAR EDITAR BODEGAS"))
                    throw new Exception("No tiene permiso para editar ubicaciones.");

                UbicacionId = id;
            }
            else if (e.CommandName == "Guardar")
            {
                TextBox2 txt = (TextBox2)e.Item.FindControl("txtNombre");
                string nombre = txt.Text.Trim();

                if (nombre.Length == 0)
                    throw new Exception("Indique el nombre de la ubicación.");

                /* Solo viaja el nombre. El código identifica la ubicación y ya
                   está impreso en la etiqueta del estante: cambiarlo dejaría
                   las etiquetas pegadas apuntando a algo que no existe, así
                   que no se ofrece siquiera. */
                BodegaUbicacion entidad = new BodegaUbicacion();
                entidad.bub_id = id;
                entidad.bub_bodega = Id;
                entidad.bub_nombre = nombre;
                entidad.bub_habilitado = true;

                BodegaController controller = new BodegaController();
                Respuesta respuesta = controller.GuardarUbicacion(entidad);

                if (respuesta.error)
                {
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                    return;
                }

                UbicacionId = 0;
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            }

            /* Page_PreRender vuelve a cargar la lista, así que no se recarga
               acá: hacerlo dos veces por clic es trabajo de base repetido. */
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Los tres accesos de impresión.
    ///
    /// Van como onclick a una ventana emergente y no como postback porque lo
    /// que abren es una pantalla que se imprime: dentro del modal, el
    /// navegador imprimiría la ficha de la bodega en lugar de las etiquetas.
    /// </summary>
    protected void CargarEtiquetas()
    {
        /* Sin bodega guardada no hay nada que rotular, y las ubicaciones
           todavía no existen. */
        pnlEtiquetas.Visible = (Id > 0 && Token.Puede("IMPRIMIR ETIQUETAS"));

        if (!pnlEtiquetas.Visible) return;

        btnEtiquetaBodega.Attributes["onclick"] =
            "return abrirEtiquetas('" + QueryEtiqueta("BODEGA") + "');";

        btnEtiquetaUbicaciones.Attributes["onclick"] =
            "return abrirEtiquetas('" + QueryEtiqueta("UBICACION") + "');";

        /* La etiqueta con el repuesto solo tiene sentido si hay algo
           guardado: en una bodega recién creada saldría una hoja en blanco y
           el bodeguero creería que la impresión falló.

           Deshabilitada dice POR QUE, en la nota de la propia tarjeta: una
           opción apagada sin explicación se lee como que algo se rompió. */
        if (HayExistencia())
        {
            btnEtiquetaConRepuesto.Attributes["onclick"] =
                "return abrirEtiquetas('" + QueryEtiqueta("UBICACION_REPUESTO") + "');";
        }
        else
        {
            btnEtiquetaConRepuesto.Attributes["disabled"] = "disabled";
            litNotaConRepuesto.Text = "Todavía no hay existencia registrada en esta bodega.";
        }
    }

    /// <summary>
    /// La etiqueta de bodega lleva el id de la bodega; las de ubicación se
    /// acotan con @BODEGA para no imprimir los estantes de todas.
    /// </summary>
    protected string QueryEtiqueta(string origen)
    {
        string datos = "Origen=" + origen + "&Bodega=" + Id;

        if (origen == "BODEGA") datos += "&Ids=" + Id;

        return Server.UrlEncode(Tools.Crypto.Encrypt(datos));
    }

    protected bool HayExistencia()
    {
        InventarioController controller = new InventarioController();

        List<InventarioSaldo> saldos = controller.GetSaldos(
            new InventarioSaldo { isa_bodega = Id });

        return (saldos != null && saldos.Count > 0);
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR BODEGAS");

        // El codigo solo se escribe al crear: despues identifica la bodega.
        /* Nunca se escribe a mano: lo genera el SP al crear, y despues
               identifica el registro. */
            litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Bodega");
            txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
        btnAgregarUbicacion.Visible = puedeEditar;
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
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como BOD-<id>: el
               codigo depende del ID, y el ID no existe hasta despues del
               INSERT, asi que no hay forma de calcularlo antes.

               AUTO y no vacio: el SP valida que el codigo venga ANTES de
               insertar, asi que un vacio se rechaza con "indique el codigo".
               AUTO pasa esa validacion, nunca queda guardado, y el SP lo
               reemplaza en cuanto conoce el ID.

               Al editar viaja el que ya tiene. No se regenera nunca: el
               codigo esta impreso en su etiqueta, y cambiarlo dejaria la
               etiqueta pegada apuntando a algo que no existe. */
            entidad.bod_codigo = SitioBase.CodigoModulo.Componer("Bodega", txtCodigo.Text);
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
    protected void btnAgregarUbicacion_Click(object sender, EventArgs e)
    {
        try
        {
            if (Id == 0) throw new Exception("Primero guarde la bodega.");

            BodegaUbicacion entidad = new BodegaUbicacion();

            /* Cero SIEMPRE: este boton solo da de alta. Pasarle UbicacionId
               haria que, con una fila abierta en edicion, "Agregar" guardara
               sobre esa fila en vez de crear una nueva. */
            entidad.bub_id     = 0;
            entidad.bub_bodega = Id;
            /* El código lo genera el SP como UBI-<id>. Va AUTO y no cadena
               vacía porque el SP valida que el código venga ANTES de
               insertar, y un vacío se rechazaría con "indique el código". */
            entidad.bub_codigo = "AUTO";

            /* El nombre pasa a ser obligatorio. Antes, sin nombre, el código
               hacía de nombre; con el código generándose solo, eso daría una
               ubicación llamada "AUTO". */
            if (txtUbiNombre.Text.Trim().Length == 0)
                throw new Exception("Indique el nombre de la ubicación.");

            entidad.bub_nombre = txtUbiNombre.Text.Trim();

            entidad.bub_habilitado = true;

            BodegaController controller = new BodegaController();
            Respuesta respuesta = controller.GuardarUbicacion(entidad);

            if (!respuesta.error)
            {
                UbicacionId = 0;
                txtUbiNombre.Text = "";
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
