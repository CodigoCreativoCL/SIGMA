using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Alta y edición de un valor propio de catálogo (HU-021).
/// </summary>
public partial class View_Sistema_Catalogos_CatalogoValor : System.Web.UI.Page
{
    public int IdCatalogo
    {
        get { return ViewState["IdCatalogo"] != null ? (int)ViewState["IdCatalogo"] : 0; }
        set { ViewState["IdCatalogo"] = value; }
    }

    public int IdValor
    {
        get { return ViewState["IdValor"] != null ? (int)ViewState["IdValor"] : 0; }
        set { ViewState["IdValor"] = value; }
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
                    case "IdCatalogo":
                        IdCatalogo = Int32.Parse(array[1].ToString());
                        break;
                    case "IdValor":
                        IdValor = Int32.Parse(array[1].ToString());
                        break;
                }
            }
        }
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

        CatalogoController controller = new CatalogoController();

        if (IdCatalogo > 0)
        {
            Catalogo catalogo = controller.GetCatalogo(IdCatalogo);
            lblCatalogo.Text = catalogo.ctl_modulo + " · " + catalogo.ctl_nombre;
        }

        if (IdValor > 0)
        {
            // Se recupera el valor concreto pidiendo la lista filtrada por
            // su id, que es como funcionan todos los SEL_ del proyecto.
            System.Collections.Generic.List<CatalogoValor> lista =
                controller.GetValores(IdCatalogo, SitioBase.Session.ClienteId());

            if (lista != null)
            {
                CatalogoValor valor = lista.Find(x => x.valor_id == IdValor);

                if (valor != null)
                {
                    txtCodigo.Text = valor.valor_codigo;
                    txtNombre.Text = valor.valor_nombre;
                    txtDescripcion.Text = valor.valor_descripcion;

                    if (valor.valor_orden != null)
                        txtOrden.Value = valor.valor_orden.Value;

                    rdbSi.Checked = valor.valor_habilitado;
                    rdbNo.Checked = !valor.valor_habilitado;

                    /* HU-021 escenario 3: antes de deshabilitar hay que
                       advertir cuántos registros usan el valor. Se calcula
                       al abrir y no al guardar, para que la persona lo sepa
                       ANTES de decidir. El conteo sale de las claves
                       foráneas declaradas: no hay una lista escrita a mano
                       que se pueda quedar desactualizada. */
                    int usos = controller.ContarUsos(IdCatalogo, IdValor);

                    if (usos > 0)
                    {
                        litUso.Text = usos == 1
                            ? "1 registro usa este valor. Si lo deshabilita, deja de ofrecerse pero ese registro lo conserva."
                            : usos + " registros usan este valor. Si lo deshabilita, deja de ofrecerse pero esos registros lo conservan.";
                        pnlUso.Visible = true;
                    }
                }
            }

            // El código no se cambia una vez creado: hay registros que ya lo
            // referencian por id, pero el código es lo que se ve en informes
            // y exportaciones, y moverlo rompe la trazabilidad.
            txtCodigo.Enabled = false;
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR CATALOGOS");

        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;

        if (IdValor == 0) txtCodigo.ReadOnly = !puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (SitioBase.Session.ClienteId() == 0)
            {
                Tools.tools.ClientAlert("Seleccione un cliente antes de agregar valores propios.", "alerta");
                return;
            }

            CatalogoController controller = new CatalogoController();

            CatalogoValor valor = new CatalogoValor();
            valor.valor_id = IdValor;
            valor.valor_codigo = txtCodigo.Text.Trim();
            valor.valor_nombre = txtNombre.Text.Trim();
            valor.valor_descripcion = txtDescripcion.Text.Trim();
            valor.valor_habilitado = rdbSi.Checked;

            if (txtOrden.Value != null)
                valor.valor_orden = (int)txtOrden.Value.Value;

            Respuesta respuesta = (IdValor > 0)
                ? controller.UpdateValor(IdCatalogo, SitioBase.Session.ClienteId(), valor)
                : controller.InsertValor(IdCatalogo, SitioBase.Session.ClienteId(), valor);

            if (!respuesta.error)
            {
                if (IdValor == 0) IdValor = respuesta.codigo;
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
