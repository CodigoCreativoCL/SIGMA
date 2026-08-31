using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Declaración y verificación de un pago (ANEXO F §5.3 y §5.4).
///
/// Con Id = 0 es el formulario con el que el cliente declara lo que
/// transfirió; con Id > 0 es el detalle, y si el pago sigue esperando
/// aparece además el bloque de verificación.
///
/// SON DOS PERMISOS Y NO UNO
///   "Declarar pago" lo tiene el cliente. "Verificar pago" lo tiene SIGMA.
///   Que estén en la misma página no los mezcla: cada bloque se muestra
///   según su propio permiso, así que un administrador del cliente ve el
///   detalle completo y no ve los botones de verificar.
///
/// EL COMPROBANTE
///   Es obligatorio y va al Blob Storage a través de la API de servicios.
///   Mientras esa API no exista, el formulario no se muestra y se explica
///   por qué. La alternativa -dejar declarar sin comprobante- rompería la
///   regla que hace que verificar signifique algo.
/// </summary>
public partial class View_Comercial_Suscripciones_Pago : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        /* Querystring.Entero y no Crypto.Decrypt directo: el listado abre
           esta ficha con abrirPago(0) para declarar uno nuevo, asi que
           llega literalmente ?query=0, que no es texto cifrado valido.
           Descifrarlo sin red lanzaba y la pagina respondia 500. */
        if (!IsPostBack) Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                if (ctrl.ID == "cboPeriodo")
                {
                    /* Solo los períodos CON SALDO. Declarar un pago sobre uno
                       ya cubierto no está prohibido, pero no es lo que nadie
                       quiere hacer: ofrecerlos todos convierte la lista en un
                       historial donde hay que buscar el correcto. */
                    SuscripcionPeriodoController controller = new SuscripcionPeriodoController();

                    List<SuscripcionPeriodo> lista = controller.GetPeriodos(
                        new SuscripcionPeriodo
                        {
                            filtro_cliente = SitioBase.Session.ClienteId(),
                            filtro_solo_impagos = true
                        });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione", ""));

                    if (lista != null)
                    {
                        CultureInfo cl = CultureInfo.GetCultureInfo("es-CL");

                        foreach (SuscripcionPeriodo p in lista)
                        {
                            ctrl.Items.Add(new RadComboBoxItem(
                                p.spe_fecha_inicio.ToString("dd-MM-yyyy") + " al " +
                                p.spe_fecha_fin.ToString("dd-MM-yyyy") + " · saldo " +
                                p.saldo_clp.ToString("C0", cl),
                                p.spe_id.ToString()));
                        }
                    }
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (Id == 0) PrepararDeclaracion();
        else CargarDetalle();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnDeclarar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnVerificar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnRechazar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnCorregir);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkComprobante);

        udPanel.Update();
    }

    protected void PrepararDeclaracion()
    {
        pnlDetalle.Visible = false;

        litCliente.Text = Server.HtmlEncode(SitioBase.Session.ClienteNombre());
        litTitulo.Text = "Declarar una transferencia";
        litChipEstado.Text = "<span class=\"sigma-modal-chip is-neutro\">Sin declarar</span>";
        litHeroTitulo.Text = Server.HtmlEncode(SitioBase.Session.ClienteNombre());
        litHeroDetalle.Text = "Elija el período que está pagando y adjunte el comprobante de la " +
                              "transferencia.";

        IAlmacenamiento almacenamiento = Almacenamiento.Actual();

        if (!almacenamiento.Disponible)
        {
            pnlDeclarar.Visible = false;
            litAviso.Text = "<strong>No se puede declarar todavía.</strong> " +
                            Server.HtmlEncode(almacenamiento.Motivo) +
                            " El comprobante es obligatorio, así que hasta que el almacenamiento esté " +
                            "configurado no se puede registrar un pago.";
            pnlAviso.Visible = true;
            return;
        }

        if (!Token.Puede("DECLARAR PAGO SUSCRIPCION"))
        {
            pnlDeclarar.Visible = false;
            litAviso.Text = "<strong>Sin permiso.</strong> No tiene la facultad de declarar pagos.";
            pnlAviso.Visible = true;
            return;
        }

        pnlDeclarar.Visible = true;
        pnlAviso.Visible = false;
    }

    protected void CargarDetalle()
    {
        pnlDeclarar.Visible = false;
        pnlDetalle.Visible = true;

        SuscripcionPagoController controller = new SuscripcionPagoController();
        SuscripcionPago p = controller.GetPago(new SuscripcionPago { spa_id = Id });

        if (p == null || p.spa_id == 0) return;

        /* El pago tiene que ser de la empresa con la que se esta trabajando.

           Sin esto, cambiando el id del querystring se podia leer el banco,
           el numero de operacion y el monto de OTRO cliente. Antes la ficha
           estaba abierta solo a cuentas de plataforma y no se notaba; desde
           que el Administrador del Cliente entra aqui para declarar sus
           pagos, la comprobacion es imprescindible.

           Quien tiene VER TODO CLIENTES -Root, Soporte, Gerente Comercial-
           pasa: su trabajo es justamente mirar los pagos de todos. */
        if (p.sus_cliente != SitioBase.Session.ClienteId()
            && !Token.Puede("VER TODO CLIENTES"))
        {
            pnlDetalle.Visible = false;
            litAviso.Text = "<strong>Ese pago no existe.</strong> " +
                            "Revise el listado de sus pagos declarados.";
            pnlAviso.Visible = true;
            return;
        }

        CultureInfo cl = CultureInfo.GetCultureInfo("es-CL");

        litCliente.Text = Server.HtmlEncode(p.cli_nombre);
        litTitulo.Text = "Pago " + p.spa_id + " &middot; " +
                         p.spa_monto_declarado_clp.ToString("C0", cl);

        lblFecha.Text = p.spa_fecha_transferencia.ToString("dd-MM-yyyy");
        lblBanco.Text = p.spa_banco;
        lblOperacion.Text = p.spa_numero_operacion;
        lblComprobante.Text = "";

        lblPeriodo.Text = (p.spe_fecha_inicio != null && p.spe_fecha_fin != null)
            ? p.spe_fecha_inicio.Value.ToString("dd-MM-yyyy") + " al " +
              p.spe_fecha_fin.Value.ToString("dd-MM-yyyy") + " · monto " +
              p.spe_monto_clp.ToString("C0", cl)
            : "";

        string chip;
        string texto;

        switch ((p.spo_codigo ?? "").Trim().ToUpper())
        {
            case "VERIFICADO":
                chip = "is-exito";
                texto = "Verificado por " + p.verificado_por +
                        (p.spa_fecha_verificacion_utc != null
                            ? " el " + p.spa_fecha_verificacion_utc.Value.ToLocalTime().ToString("dd-MM-yyyy HH:mm")
                            : "");
                break;
            case "RECHAZADO":
                chip = "is-alerta";
                texto = "Rechazado por " + p.verificado_por + ".";
                break;
            default:
                chip = "is-info";
                texto = "Esperando verificación. Todavía no descuenta saldo del período.";
                break;
        }

        litChipEstado.Text = "<span class=\"sigma-modal-chip " + chip + "\">" +
                             Server.HtmlEncode(p.spo_nombre) + "</span>";

        litHeroTitulo.Text = "Declarado " + p.spa_monto_declarado_clp.ToString("C0", cl) +
                             (p.spa_monto_verificado_clp != null
                                 ? " &middot; verificado " + p.spa_monto_verificado_clp.Value.ToString("C0", cl)
                                 : "");

        litHeroDetalle.Text = texto;

        pnlRechazo.Visible = !string.IsNullOrEmpty(p.spa_motivo_rechazo);
        lblMotivoRechazo.Text = p.spa_motivo_rechazo;

        /* Verificar solo mientras el pago siga esperando (1 DECLARADO,
           2 EN REVISION). Un pago ya resuelto no se re-verifica desde acá:
           revertir una verificación mueve saldos y vigencias, y eso merece
           su propio flujo antes que un botón que parece inocente. */
        bool pendiente = (p.spa_estado == 1 || p.spa_estado == 2);

        pnlVerificar.Visible = pendiente && Token.Puede("VERIFICAR PAGOS SUSCRIPCION");

        /* CORREGIR es otra cosa que verificar, y por eso otro panel y otro
           permiso: lo hace quien declaró, no quien cuadra la cartola.

           Se puede mientras el pago no esté verificado —1 DECLARADO,
           2 EN REVISION, 4 RECHAZADO—. Con el pago ya verificado no: su
           monto ya sumó al período y pudo extender la vigencia de la
           suscripción, así que cambiarlo dejaría el saldo apoyado en una
           cifra que ya no existe. El SP lo rechaza igual; esto solo evita
           mostrar un formulario que va a fallar. */
        bool corregible = (p.spa_estado == 1 || p.spa_estado == 2 || p.spa_estado == 4);

        pnlCorregir.Visible = corregible && Token.Puede("DECLARAR PAGO SUSCRIPCION");
        pnlCorregirRechazado.Visible = (p.spa_estado == 4);

        if (pnlCorregir.Visible && !IsPostBack)
        {
            txtMontoCorregir.Text = p.spa_monto_declarado_clp.ToString("0");
            txtFechaCorregir.Text = p.spa_fecha_transferencia.ToString("dd-MM-yyyy");
            txtBancoCorregir.Text = p.spa_banco;
            txtOperacionCorregir.Text = p.spa_numero_operacion;
        }

        // Sin almacenamiento no hay de dónde bajar el comprobante.
        IAlmacenamiento almacenamiento = Almacenamiento.Actual();

        lnkComprobante.Visible = almacenamiento.Disponible;

        if (!almacenamiento.Disponible)
            lblComprobante.Text = "No disponible: el almacenamiento no está configurado.";
    }

    protected void btnDeclarar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboPeriodo.SelectedValue))
                throw new Exception("Debe elegir el período que se está pagando.");

            if (!fldComprobante.HasFile)
                throw new Exception("Debe adjuntar el comprobante de la transferencia.");

            decimal monto = LeerMonto(txtMonto.Text, "monto transferido");

            if (monto <= 0)
                throw new Exception("El monto transferido debe ser mayor que cero.");

            DateTime fecha = LeerFecha(txtFecha.Text);

            /* 1. El comprobante primero. Si falla la subida no queda un
                  pago declarado sin respaldo, que es lo que después nadie
                  puede verificar. */
            ArchivoController archivos = new ArchivoController();

            Archivo archivo = new Archivo();
            archivo.arc_cliente = SitioBase.Session.ClienteId();
            archivo.arc_archivo_categoria = ArchivoController.CATEGORIA_COMPROBANTE_PAGO;
            archivo.arc_nombre_original = fldComprobante.FileName;
            archivo.arc_mime = fldComprobante.PostedFile.ContentType;
            archivo.contenido = fldComprobante.FileBytes;

            Respuesta subida = archivos.InsertArchivo(archivo, "comprobantes");

            if (subida.error)
                throw new Exception("No se pudo guardar el comprobante: " + subida.detalle);

            // 2. Recién ahora el pago.
            SuscripcionPago entidad = new SuscripcionPago();

            entidad.spa_periodo = int.Parse(cboPeriodo.SelectedValue);
            entidad.spa_monto_declarado_clp = monto;
            entidad.spa_fecha_transferencia = fecha;
            entidad.spa_banco = txtBanco.Text.Trim();
            entidad.spa_numero_operacion = txtOperacion.Text.Trim();
            entidad.spa_archivo = subida.codigo;

            SuscripcionPagoController controller = new SuscripcionPagoController();
            Respuesta respuesta = controller.InsertPago(entidad);

            if (!respuesta.error)
            {
                Id = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                /* El pago no entró pero el comprobante sí. Se da de baja
                   para no dejar un archivo colgando que nadie va a mirar.
                   El blob queda: darlo de baja es lógico, no físico. */
                archivos.DeleteArchivo(new Archivo { arc_id = subida.codigo });

                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Corrige lo que se declaró mal (T-2211).
    ///
    /// Los cuatro campos son opcionales: lo que se deja vacío no se toca.
    /// El SP recibe NULL y aplica ISNULL(@X, columna). Mandar la fila entera
    /// con lo que haya en pantalla es como UPD_CLIENTE_INSTALACION borró la
    /// zona horaria de las plantas.
    /// </summary>
    protected void btnCorregir_Click(object sender, EventArgs e)
    {
        try
        {
            SuscripcionPago entidad = new SuscripcionPago();
            entidad.spa_id = Id;

            if (!string.IsNullOrEmpty(txtMontoCorregir.Text.Trim()))
            {
                decimal monto = LeerMonto(txtMontoCorregir.Text, "monto transferido");

                if (monto <= 0)
                    throw new Exception("El monto transferido debe ser mayor que cero.");

                entidad.spa_monto_declarado_clp = monto;
            }

            if (!string.IsNullOrEmpty(txtFechaCorregir.Text.Trim()))
                entidad.spa_fecha_transferencia = LeerFecha(txtFechaCorregir.Text);

            entidad.spa_banco = txtBancoCorregir.Text.Trim();
            entidad.spa_numero_operacion = txtOperacionCorregir.Text.Trim();

            SuscripcionPagoController controller = new SuscripcionPagoController();
            Respuesta respuesta = controller.CorregirPago(entidad);

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void btnVerificar_Click(object sender, EventArgs e)
    {
        Resolver(true);
    }

    protected void btnRechazar_Click(object sender, EventArgs e)
    {
        Resolver(false);
    }

    private void Resolver(bool verificado)
    {
        try
        {
            SuscripcionPago entidad = new SuscripcionPago();

            entidad.spa_id = Id;
            entidad.verificado = verificado;

            if (verificado)
            {
                if (!string.IsNullOrEmpty(txtMontoVerificado.Text) &&
                    !string.IsNullOrEmpty(txtMontoVerificado.Text.Trim()))
                    entidad.monto_verificado = LeerMonto(txtMontoVerificado.Text, "monto verificado");
            }
            else
            {
                // El SP también lo exige; avisar acá evita el viaje a la base
                // para recibir un error en mayúsculas.
                if (string.IsNullOrEmpty(txtMotivo.Text) || txtMotivo.Text.Trim().Length < 5)
                    throw new Exception("Indique el motivo del rechazo.");

                entidad.motivo_rechazo = txtMotivo.Text.Trim();
            }

            SuscripcionPagoController controller = new SuscripcionPagoController();
            Respuesta respuesta = controller.VerificarPago(entidad);

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok", !respuesta.error);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Entrega el comprobante. El binario nunca estuvo en la base: se pide
    /// al almacenamiento en el momento.
    /// </summary>
    protected void lnkComprobante_Click(object sender, EventArgs e)
    {
        try
        {
            SuscripcionPagoController pagos = new SuscripcionPagoController();
            SuscripcionPago p = pagos.GetPago(new SuscripcionPago { spa_id = Id });

            if (p == null || p.spa_archivo == 0)
                throw new Exception("Este pago no tiene comprobante registrado.");

            ArchivoController archivos = new ArchivoController();

            Archivo archivo = archivos.GetArchivo(new Archivo { arc_id = p.spa_archivo });
            byte[] contenido = archivos.Descargar(p.spa_archivo);

            Response.Clear();
            Response.ContentType = string.IsNullOrEmpty(archivo.arc_mime)
                ? "application/octet-stream"
                : archivo.arc_mime;
            Response.AddHeader("Content-Disposition",
                "attachment; filename=\"" + archivo.arc_nombre_original + "\"");
            Response.BinaryWrite(contenido);
            Response.End();
        }
        catch (System.Threading.ThreadAbortException)
        {
            // Response.End() siempre lanza esta. No es un error.
            throw;
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Lee un monto en pesos aceptando puntos de miles y coma o punto
    /// decimal. Quien copie el monto desde la cartola lo va a traer con
    /// puntos; rechazarlo por eso sería hacer fallar la carga por el
    /// formato en que el banco muestra sus propios números.
    /// </summary>
    private decimal LeerMonto(string texto, string nombreCampo)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim()))
            throw new Exception("Debe indicar el " + nombreCampo + ".");

        string limpio = texto.Trim().Replace("$", "").Replace(" ", "").Replace(".", "").Replace(",", ".");

        decimal valor;

        if (!decimal.TryParse(limpio, NumberStyles.Float, CultureInfo.InvariantCulture, out valor))
            throw new Exception("El " + nombreCampo + " no es un número válido.");

        return valor;
    }

    /// <summary>
    /// Lee la fecha en dd-MM-yyyy o dd/MM/yyyy. No se usa la cultura del
    /// hilo: un servidor mal configurado leería 03-04-2026 como 4 de marzo
    /// y nadie lo notaría hasta que un pago quedara fuera de su período.
    /// </summary>
    private DateTime LeerFecha(string texto)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim()))
            throw new Exception("Debe indicar la fecha de la transferencia.");

        string[] formatos = new string[] { "dd-MM-yyyy", "dd/MM/yyyy", "yyyy-MM-dd" };

        DateTime fecha;

        if (!DateTime.TryParseExact(texto.Trim(), formatos, CultureInfo.InvariantCulture,
                                    DateTimeStyles.None, out fecha))
            throw new Exception("La fecha de la transferencia no es válida. Use dd-mm-aaaa.");

        if (fecha.Date > DateTime.Today)
            throw new Exception("La fecha de la transferencia no puede ser futura.");

        return fecha;
    }
}
