using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;

/// <summary>
/// Ficha de una categoría de repuesto.
///
/// EL CÓDIGO ES PREFIJO + LO QUE ESCRIBA EL CLIENTE
///   El prefijo sale de `Modulo_Codigo` —la misma tabla que usa
///   `FNC_CODIGO_AUTOMATICO`—, nunca escrito acá. Si el campo queda vacío se
///   manda 'AUTO' y el SP lo numera, así nadie queda obligado a inventar uno.
/// </summary>
public partial class View_Inventario_Repuestos_RepuestoTipo : System.Web.UI.Page
{
    private const string TABLA = "Repuesto_Tipo";

    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (IsPostBack) return;

        /* El mismo lector que usan las demas fichas: descifra y devuelve el
           entero, o 0 si no viene. Partir la cadena a mano obligaba a
           adivinar el formato y reventaba con un id no numerico. */
        Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
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
            RepuestoTipoController controller = new RepuestoTipoController();
            RepuestoTipo t = controller.GetRepuestoTipo(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo(TABLA, t.rti_codigo);
            txtNombre.Text = t.rti_nombre;
            txtDescripcion.Text = t.rti_descripcion;
            txtOrden.Text = t.rti_orden.ToString();
            rdbSi.Checked = t.rti_habilitado;
            rdbNo.Checked = !t.rti_habilitado;

            /* Se dice cuántos repuestos cuelgan del tipo porque de eso depende
               si se puede deshabilitar. Enterarse al recibir el error es
               enterarse tarde. */
            if (t.repuestos > 0)
            {
                pnlUso.Visible = true;
                litUso.Text = t.repuestos == 1
                    ? "Hay <strong>1 repuesto</strong> de este tipo, así que no se puede deshabilitar ni eliminar."
                    : "Hay <strong>" + t.repuestos + " repuestos</strong> de este tipo, así que no se puede deshabilitar ni eliminar.";
            }
        }
        else
        {
            lblId.Text = "Nuevo";
            txtOrden.Text = "0";
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR REPUESTOS");

        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta(TABLA);

        /* Se escribe al crear; después el código ya identifica al registro y
           cambiarlo dejaría a quien lo tenga anotado apuntando a nada. */
        txtCodigo.ReadOnly = Id > 0 || !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        txtOrden.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR REPUESTOS"))
            {
                Tools.tools.ClientAlert("No tiene permisos para guardar tipos de repuesto.", "alerta");
                return;
            }

            Page.Validate("Tipo");

            if (!Page.IsValid || string.IsNullOrWhiteSpace(txtNombre.Text))
            {
                Tools.tools.ClientAlert("Indique el nombre del tipo.", "alerta");
                return;
            }

            int orden;

            if (!int.TryParse((txtOrden.Text ?? "").Trim(), out orden)) orden = 0;

            RepuestoTipo t = new RepuestoTipo();
            RepuestoTipoController controller = new RepuestoTipoController();

            t.rti_id = Id;
            t.rti_codigo = SitioBase.CodigoModulo.Componer(TABLA, txtCodigo.Text);
            t.rti_nombre = txtNombre.Text.Trim();
            t.rti_descripcion = txtDescripcion.Text.Trim();
            t.rti_orden = orden;
            t.rti_habilitado = rdbSi.Checked;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateRepuestoTipo(t)
                : controller.InsertRepuestoTipo(t);

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
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }
}
