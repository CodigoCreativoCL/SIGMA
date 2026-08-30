using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using Sigma.Model;
using Sigma.Controller;
using SitioBase;

/// <summary>
/// CODE-BEHIND DEL TAB / SUB-FORMULARIO DE PRODUCTO.
///
/// Aqui vive el CRUD real de la pantalla. Siempre los mismos metodos:
///
///   LoadControls()     -> puebla los combos (una sola vez, en !IsPostBack).
///   CargarDatos()      -> si IdProducto > 0 trae el registro y llena los controles.
///   Bloqueo()          -> aplica ReadOnly a cada control.
///   btnGuardar_Click() -> arma el Model desde los controles y llama Insert/Update.
///
/// PATRON (ver PATRON_MVC.md seccion 6):
///  - Nunca se llama a la BD desde aqui: siempre a traves del Controller.
///  - El "alta vs edicion" se decide con un solo if: IdProducto > 0.
///  - Todo va envuelto en try/catch que termina en Tools.tools.ClientAlert.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class View_Inventario_Controls_Producto_Identidad : System.Web.UI.UserControl
{
    #region PROPIEDADES

    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    public int IdProducto
    {
        get { return ViewState["IdProducto"] == null ? 0 : (int)ViewState["IdProducto"]; }
        set { ViewState["IdProducto"] = value; }
    }

    #endregion

    #region CICLO DE VIDA

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();

        // Sin esta linea el boton Guardar NO dispara postback dentro del UpdatePanel.
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);

        udPanel.Update();
    }

    #endregion

    #region CARGA DE COMBOS

    /// <summary>
    /// Un unico metodo atiende a TODOS los combos del control.
    /// Se engancha desde el markup con OnLoad="LoadControls" y se
    /// desambigua con switch (ctrl.ID).
    ///
    /// El !IsPostBack es clave: sin el, el combo se recargaria en cada
    /// postback y perderia la seleccion del usuario.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                switch (ctrl.ID)
                {
                    case "cboCategoria":

                        CategoriaController categoriaController = new CategoriaController();
                        Categoria filtroCategoria = new Categoria { filtro_habilitado = true };

                        // El item vacio se agrega ANTES del DataBind
                        // y se conserva gracias a AppendDataBoundItems.
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = categoriaController.GetCategorias(filtroCategoria);
                        ctrl.DataValueField = "cat_id";   // debe existir en el Model
                        ctrl.DataTextField = "cat_nombre";
                        ctrl.DataBind();
                        break;

                    case "cboProveedor":

                        ProveedorController proveedorController = new ProveedorController();
                        Proveedor filtroProveedor = new Proveedor { filtro_habilitado = true };

                        // El item vacio se agrega ANTES del DataBind
                        // y se conserva gracias a AppendDataBoundItems.
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = proveedorController.GetProveedores(filtroProveedor);
                        ctrl.DataValueField = "prv_id";   // debe existir en el Model
                        ctrl.DataTextField = "prv_nombre";
                        ctrl.DataBind();
                        break;
                }
            }
        }
    }

    #endregion

    #region CARGA Y BLOQUEO

    /// <summary>
    /// Modo edicion -> trae el registro y llena los controles.
    /// Modo alta    -> limpia todo.
    /// </summary>
    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (IdProducto > 0)
        {
            ProductoController productoController = new ProductoController();
            Producto producto = productoController.GetProducto(new Producto { pro_id = IdProducto });

            if (producto == null) return;

            txtCodigo.Text = producto.pro_codigo;
            txtNombre.Text = producto.pro_nombre;
            txtDescripcion.Text = producto.pro_descripcion;
            cboCategoria.SelectedValue = producto.pro_categoria.ToString();
            cboProveedor.SelectedValue = producto.pro_proveedor.ToString();
            txtPrecio.Value = (double)producto.pro_precio;
            txtStock.Value = producto.pro_stock;
            dtpVencimiento.SelectedDate = producto.pro_vencimiento;
            chkHabilitado.Checked = producto.pro_habilitado;
        }
        else
        {
            txtCodigo.Text = string.Empty;
            txtNombre.Text = string.Empty;
            txtDescripcion.Text = string.Empty;
            cboCategoria.SelectedValue = "";
            cboProveedor.SelectedValue = "";
            txtPrecio.Value = null;
            txtStock.Value = null;
            dtpVencimiento.SelectedDate = null;
            chkHabilitado.Checked = true;
        }
    }

    /// <summary>
    /// Un unico lugar donde se aplica el modo consulta.
    /// ReadOnly en los controles del proyecto renderiza un span con el valor
    /// y oculta el input: no se puede editar ni por inspector.
    /// </summary>
    protected void Bloqueo()
    {
        txtCodigo.ReadOnly = ReadOnly;
        txtNombre.ReadOnly = ReadOnly;
        txtDescripcion.ReadOnly = ReadOnly;
        cboCategoria.ReadOnly = ReadOnly;
        cboProveedor.ReadOnly = ReadOnly;
        txtPrecio.ReadOnly = ReadOnly;
        txtStock.ReadOnly = ReadOnly;

        dtpVencimiento.Enabled = !ReadOnly;
        chkHabilitado.Enabled = !ReadOnly;

        btnGuardar.Visible = !ReadOnly;
    }

    #endregion

    #region GUARDAR

    /// <summary>
    /// Unico punto de escritura de la pantalla.
    /// Secuencia: armar Model -> validar -> Insert o Update -> avisar.
    /// </summary>
    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            // 1. Armar el Model desde los controles.
            Producto producto = new Producto();
            producto.pro_id = IdProducto;
            producto.pro_codigo = txtCodigo.Text.Trim();
            producto.pro_nombre = txtNombre.Text.Trim();
            producto.pro_descripcion = txtDescripcion.Text.Trim();
            producto.pro_categoria = int.Parse(cboCategoria.SelectedValue);
            producto.pro_proveedor = string.IsNullOrEmpty(cboProveedor.SelectedValue) ? 0 : int.Parse(cboProveedor.SelectedValue);
            producto.pro_precio = txtPrecio.Value.HasValue ? (decimal)txtPrecio.Value.Value : 0;
            producto.pro_stock = txtStock.Value.HasValue ? (int)txtStock.Value.Value : 0;
            producto.pro_vencimiento = dtpVencimiento.SelectedDate;
            producto.pro_habilitado = chkHabilitado.Checked;

            // 2. Insert o Update segun el modo.
            ProductoController productoController = new ProductoController();
            Respuesta respuesta;

            if (IdProducto > 0)
                respuesta = productoController.UpdateProducto(producto);
            else
                respuesta = productoController.InsertProducto(producto);

            // 3. Avisar. En el alta guardamos el id devuelto para que
            //    el siguiente Guardar sea un Update y no otro Insert.
            if (!respuesta.error)
            {
                IdProducto = respuesta.codigo;
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

    #endregion
}
