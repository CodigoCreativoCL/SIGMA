using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Data.SqlClient;
using System.Web.UI;

/// <summary>
/// Ficha del proveedor (HU-060, bloque 91).
///
/// EL IDENTIFICADOR NO SE LLAMA IGUAL EN LOS CINCO PAISES
///   La etiqueta sale del país del cliente —RUT en Chile, RUC en Perú, CUIT
///   en Argentina— con el mismo SEL_PAIS_IDENTIFICADOR que usa la ficha del
///   cliente. Escribir "RUT" fijo en el markup sería correcto en un país de
///   los cinco, y la validación del SP rechazaría documentos buenos sin que
///   la pantalla explicara por qué.
///
/// NO LLEVA CODIGO AUTOMATICO
///   El resto de los maestros muestra "Se genera solo al guardar: XXX-…".
///   Acá no: una empresa ya tiene un identificador único, que es su RUT, y
///   agregarle un PRV-12 sería un segundo nombre para lo mismo.
/// </summary>
public partial class View_Terceros_Proveedores_Proveedor : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
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

    protected void Page_PreRender(object sender, EventArgs e)
    {
        EtiquetaIdentificador();
        CargarDatos();
        Bloqueo();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    /// <summary>
    /// Cómo se llama el documento en el país del cliente.
    ///
    /// Si no se puede resolver queda "Identificación", que es neutro y
    /// correcto: es preferible a dejar el formulario sin poder usarse.
    /// </summary>
    protected void EtiquetaIdentificador()
    {
        string etiqueta = "Identificación";

        try
        {
            ClienteController ctrlCliente = new ClienteController();
            Cliente cliente = ctrlCliente.GetCliente(new Cliente { cli_id = SitioBase.Session.ClienteId() });

            if (cliente != null && cliente.cli_pais > 0)
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PAIS_IDENTIFICADOR";
                    cmd.Parameters.AddWithValue("@PAIS", cliente.cli_pais);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read()) etiqueta = dr["ETIQUETA"].ToString();
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                }
            }
        }
        catch (Exception)
        {
            // Queda la etiqueta neutra.
        }

        litRotuloRut.Text = etiqueta;
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ProveedorController controller = new ProveedorController();
            Proveedor p = controller.GetProveedor(Id);

            /* GetProveedor vuelve con un objeto vacío cuando el id no es de
               este cliente: no se muestra una ficha en blanco como si fuera
               un alta, se dice que no está y se cierra el paso. */
            if (p == null || p.prv_id == 0)
            {
                lblId.Text = "—";
                btnGuardar.Visible = false;
                Tools.tools.ClientAlert("El proveedor no existe o no pertenece a su empresa.", "alerta");
                return;
            }

            lblId.Text = p.prv_id.ToString();
            txtRut.Text = p.prv_rut;
            txtRazonSocial.Text = p.prv_razon_social;
            txtNombreFantasia.Text = p.prv_nombre_fantasia;
            txtGiro.Text = p.prv_giro;
            txtContacto.Text = p.prv_contacto;
            txtEmail.Text = p.prv_email;
            txtTelefono.Text = p.prv_telefono;
            txtDireccion.Text = p.prv_direccion;
            txtObservacion.Text = p.prv_observacion;

            chkContratista.Checked = p.prv_es_contratista;
            chkProveedorRepuesto.Checked = p.prv_es_proveedor_repuesto;

            rdbSi.Checked = p.prv_habilitado;
            rdbNo.Checked = !p.prv_habilitado;

            MostrarUso(p);

            wucAuditoria.Mostrar(p.usuario_creacion_nombre, p.prv_fecha_creacion,
                                 p.usuario_actualizacion_nombre, p.prv_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    /// <summary>
    /// Lo que ya se le compró o contrató.
    ///
    /// Sirve para dos cosas: saber si el proveedor está en uso antes de
    /// deshabilitarlo, y entender por qué la eliminación lo va a rechazar.
    /// </summary>
    protected void MostrarUso(Proveedor p)
    {
        if (p.lotes == 0 && p.servicios == 0) return;

        string texto = "A este proveedor se le ha comprado o contratado: ";

        if (p.lotes > 0)
            texto += "<strong>" + p.lotes + (p.lotes == 1 ? " lote" : " lotes") + "</strong> de repuestos";

        if (p.servicios > 0)
            texto += (p.lotes > 0 ? " y " : "") +
                     "<strong>" + p.servicios + (p.servicios == 1 ? " servicio" : " servicios") + "</strong>";

        texto += ". No se puede eliminar sin perder ese historial; para que deje de " +
                 "ofrecerse, márquelo como no habilitado.";

        litUso.Text = texto;
        pnlUso.Visible = true;
    }

    /// <summary>
    /// Quien solo puede ver, ve. El bloqueo es de cortesía: la potestad la
    /// vuelve a validar el servidor al guardar.
    /// </summary>
    protected void Bloqueo()
    {
        bool puedeEditar = Token.PuedeFuncion("Crear y editar");

        txtRut.ReadOnly = !puedeEditar;
        txtRazonSocial.ReadOnly = !puedeEditar;
        txtNombreFantasia.ReadOnly = !puedeEditar;
        txtGiro.ReadOnly = !puedeEditar;
        txtContacto.ReadOnly = !puedeEditar;
        txtEmail.ReadOnly = !puedeEditar;
        txtTelefono.ReadOnly = !puedeEditar;
        txtDireccion.ReadOnly = !puedeEditar;
        txtObservacion.ReadOnly = !puedeEditar;

        chkContratista.Enabled = puedeEditar;
        chkProveedorRepuesto.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        if (!puedeEditar) btnGuardar.Visible = false;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            /* SE VALIDA ACA, EN EL SERVIDOR.
               Esconder el botón en Bloqueo() no es seguridad: quien manda el
               postback a mano se lo salta. */
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para crear o editar proveedores.");

            if (string.IsNullOrEmpty(txtRut.Text.Trim()))
                throw new Exception("Indique el identificador tributario del proveedor.");

            if (string.IsNullOrEmpty(txtRazonSocial.Text.Trim()))
                throw new Exception("Indique la razón social.");

            /* La misma regla que el SP, dicha antes de viajar: un proveedor
               que no es ni contratista ni vendedor de repuestos no se puede
               elegir en ninguna pantalla. */
            if (!chkContratista.Checked && !chkProveedorRepuesto.Checked)
                throw new Exception("Marque al menos un tipo: contratista o proveedor de repuestos.");

            Proveedor entidad = new Proveedor();
            entidad.prv_id = Id;
            entidad.prv_rut = txtRut.Text.Trim();
            entidad.prv_razon_social = txtRazonSocial.Text.Trim();
            entidad.prv_nombre_fantasia = txtNombreFantasia.Text.Trim();
            entidad.prv_giro = txtGiro.Text.Trim();
            entidad.prv_contacto = txtContacto.Text.Trim();
            entidad.prv_email = txtEmail.Text.Trim();
            entidad.prv_telefono = txtTelefono.Text.Trim();
            entidad.prv_direccion = txtDireccion.Text.Trim();
            entidad.prv_observacion = txtObservacion.Text.Trim();
            entidad.prv_es_contratista = chkContratista.Checked;
            entidad.prv_es_proveedor_repuesto = chkProveedorRepuesto.Checked;
            entidad.prv_habilitado = rdbSi.Checked;

            ProveedorController controller = new ProveedorController();

            Respuesta respuesta = (Id > 0)
                                ? controller.UpdateProveedor(entidad)
                                : controller.InsertProveedor(entidad);

            if (respuesta.error)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                return;
            }

            /* Se recuerda el id para que un segundo Guardar edite en vez de
               crear otro: sin esto, apretar dos veces deja dos proveedores
               —y el segundo lo frena el RUT único, con un mensaje que no
               explica lo que pasó. */
            if (Id == 0) Id = respuesta.codigo;

            Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
