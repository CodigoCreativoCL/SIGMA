using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha del permiso de trabajo (HU-063, bloque 94).
///
/// EL ADJUNTO ES LA HISTORIA, Y ES LO QUE FALTA
///   "Adjuntar el permiso firmado que habilita el trabajo." El hueco está
///   conectado de punta a punta —ptr_archivo, el SEL_ devuelve nombre y
///   peso, ArchivoController sabe subir— pero `Almacenamiento.Disponible`
///   devuelve falso mientras la API de blobs no exista (decisión del 29-08).
///
///   La pantalla PREGUNTA antes de ofrecer. Un botón de subir que siempre
///   falla enseña a desconfiar de los botones.
///
/// AUTORIZADO EXIGE EL DOCUMENTO
///   Lo impone `CK_PTR_AUTORIZADO` en la tabla, no esta pantalla. Acá se
///   dice antes de intentarlo, para que nadie llene el formulario entero y
///   se entere al final.
/// </summary>
public partial class View_Terceros_PermisosTrabajo_PermisoTrabajo : System.Web.UI.Page
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
            PermisoTrabajoController controller = new PermisoTrabajoController();

            switch (ctrl.ID)
            {
                case "cboTipo":

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetTipos();
                    ctrl.DataValueField = "ptt_id";
                    ctrl.DataTextField = "ptt_nombre";
                    ctrl.DataBind();
                    break;

                case "cboEstado":

                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetEstados();
                    ctrl.DataValueField = "pte_id";
                    ctrl.DataTextField = "pte_nombre";
                    ctrl.DataBind();

                    /* Nace SOLICITADO: es lo que se puede guardar hoy, porque
                       AUTORIZADO exige el documento adjunto. */
                    RadComboBoxItem sol = ctrl.FindItemByText("Solicitado");
                    if (sol != null) sol.Selected = true;
                    break;

                case "cboSolicitante":

                    CargarPersonas(ctrl);
                    break;
            }
        }
    }

    /// <summary>
    /// Las personas del cliente, con su perfil.
    ///
    /// El mismo criterio que el resto del sitio desde el bloque 88: el
    /// perfil dice qué hace la persona, que es lo que permite decidir; el
    /// correo solo permite comprobar que existe.
    /// </summary>
    protected void CargarPersonas(RadComboBox2 ctrl)
    {
        ctrl.Items.Clear();
        ctrl.Items.Add(new RadComboBoxItem("Yo mismo", ""));

        SqlCommand cmd = new SqlCommand();

        try
        {
            cmd.CommandText = "SEL_USUARIO_CLIENTE_LISTA";
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    string perfiles = dr["PERFILES"].ToString();

                    RadComboBoxItem item = new RadComboBoxItem(
                        dr["USU_NOMBRE"].ToString() + " · " +
                        (string.IsNullOrEmpty(perfiles) ? "sin perfil" : perfiles),
                        dr["USU_ID"].ToString());

                    item.ToolTip = dr["USU_CORREO"].ToString();

                    ctrl.Items.Add(item);
                }
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

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarOrdenes();
        CargarDatos();

        /* El control se dibuja DESPUES de CargarDatos y en PreRender: el
           adjunto puede haber cambiado durante este mismo postback -se acaba
           de subir- y pintarlo antes mostraria el estado anterior. */
        wucAdjunto.ReadOnly = !Token.PuedeFuncion("Crear y editar");
        wucAdjunto.Mostrar(ArchivoActual());

        AjustarEstado();
        Bloqueo();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    /// <summary>
    /// Las órdenes abiertas. Mientras el módulo de órdenes no exista la lista
    /// viene vacía, y se dice: un combo en blanco se lee como pantalla rota.
    /// </summary>
    protected void CargarOrdenes()
    {
        if (cboOrden.Items.Count > 0 && IsPostBack) return;

        InventarioController controller = new InventarioController();
        List<OrdenTrabajoCombo> ordenes = controller.GetOrdenesAbiertas();

        cboOrden.Items.Clear();

        if (ordenes == null || ordenes.Count == 0)
        {
            cboOrden.Items.Add(new RadComboBoxItem("No hay órdenes de trabajo abiertas", ""));
            cboOrden.Enabled = false;

            litAyudaOrden.Text = "El permiso se registra igual, sin asociar a ninguna orden. " +
                                 "Cuando existan órdenes abiertas aparecerán acá.";
            return;
        }

        cboOrden.Enabled = true;
        cboOrden.Items.Add(new RadComboBoxItem("Sin orden", ""));

        foreach (OrdenTrabajoCombo o in ordenes)
            cboOrden.Items.Add(new RadComboBoxItem(o.etiqueta, o.orden_id.ToString()));

        litAyudaOrden.Text = "A qué trabajo corresponde. Opcional.";
    }

    /// <summary>
    /// Se dice qué significa el estado elegido, y si va a poder guardarse.
    /// </summary>
    protected void AjustarEstado()
    {
        bool tiene = wucAdjunto.IdArchivo > 0 || wucAdjunto.HayArchivoNuevo;
        string estado = cboEstado.Text;

        if (estado == "Autorizado" && !tiene)
        {
            litAyudaEstado.Text = "<strong>No se va a poder guardar como Autorizado:</strong> " +
                                  "falta el documento firmado adjunto.";
            return;
        }

        if (estado == "Autorizado")
            litAyudaEstado.Text = "El permiso habilita la faena mientras esté vigente.";
        else if (estado == "Rechazado" || estado == "Cerrado")
            litAyudaEstado.Text = "Es el final de este permiso: después no se podrá corregir.";
        else
            litAyudaEstado.Text = "Solicitado: registrado, todavía sin autorizar.";
    }

    protected void cboEstado_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        AjustarEstado();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            PermisoTrabajoController controller = new PermisoTrabajoController();
            PermisoTrabajo p = controller.GetPermiso(Id);

            if (p == null || p.ptr_id == 0)
            {
                lblId.Text = "—";
                btnGuardar.Visible = false;
                Tools.tools.ClientAlert("El permiso no existe o no pertenece a su empresa.", "alerta");
                return;
            }

            lblId.Text = p.ptr_id.ToString();
            txtNumero.Text = p.ptr_numero;
            txtObservacion.Text = p.ptr_observacion;

            RadComboBoxItem i = cboTipo.FindItemByValue(p.ptr_permiso_trabajo_tipo.ToString());
            if (i != null) i.Selected = true;

            i = cboEstado.FindItemByValue(p.ptr_permiso_trabajo_estado.ToString());
            if (i != null) i.Selected = true;

            if (p.ptr_usuario_solicitante != null)
            {
                i = cboSolicitante.FindItemByValue(p.ptr_usuario_solicitante.Value.ToString());
                if (i != null) i.Selected = true;
            }

            if (p.ptr_orden_trabajo != null)
            {
                i = cboOrden.FindItemByValue(p.ptr_orden_trabajo.Value.ToString());
                if (i != null) i.Selected = true;
            }

            /* El calendario entrega y recibe la fecha ya validada: escribirla
               como texto y volver a interpretarla sería rehacer —peor— lo que
               el control ya hace bien. */
            calDesde.Value = p.ptr_fecha_vigencia_inicio_utc;
            calHasta.Value = p.ptr_fecha_vigencia_fin_utc;

            MostrarSituacion(p);

            wucAuditoria.Mostrar(p.usuario_creacion_nombre, p.ptr_fecha_creacion,
                                 p.usuario_actualizacion_nombre, p.ptr_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    protected void MostrarSituacion(PermisoTrabajo p)
    {
        pnlSituacion.Visible = true;

        litHeroTitulo.Text = Server.HtmlEncode(p.tipo_nombre) +
                             (string.IsNullOrEmpty(p.ptr_numero)
                              ? "" : " · folio " + Server.HtmlEncode(p.ptr_numero));

        litHeroDetalle.Text = Server.HtmlEncode(p.vigencia_texto) +
                              (p.tiene_archivo ? " · con documento adjunto"
                                               : " · sin documento adjunto");

        litHeroChip.Text = "<span class=\"sigma-modal-chip " + p.situacion_clase + "\">" +
                           Server.HtmlEncode(p.situacion) + "</span>";
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.PuedeFuncion("Crear y editar");

        cboTipo.ReadOnly = !puedeEditar;
        cboEstado.ReadOnly = !puedeEditar;
        cboSolicitante.ReadOnly = !puedeEditar;
        txtNumero.ReadOnly = !puedeEditar;
        txtObservacion.ReadOnly = !puedeEditar;

        if (!puedeEditar)
        {
            cboOrden.ReadOnly = true;
            btnGuardar.Visible = false;
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se valida ACA, en el servidor: esconder el botón en Bloqueo() no
               es seguridad —quien manda el postback a mano se lo salta—. */
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para registrar permisos de trabajo.");

            int tipo;

            if (!int.TryParse(cboTipo.SelectedValue, out tipo) || tipo == 0)
                throw new Exception("Indique el tipo de permiso.");

            int estado;
            int.TryParse(cboEstado.SelectedValue, out estado);

            PermisoTrabajo entidad = new PermisoTrabajo();
            entidad.ptr_id = Id;
            entidad.ptr_permiso_trabajo_tipo = tipo;
            entidad.ptr_permiso_trabajo_estado = estado;
            entidad.ptr_numero = txtNumero.Text.Trim();
            entidad.ptr_observacion = txtObservacion.Text.Trim();
            entidad.ptr_habilitado = true;

            entidad.ptr_fecha_vigencia_inicio_utc = calDesde.Value;
            entidad.ptr_fecha_vigencia_fin_utc = calHasta.Value;

            int aux;

            if (int.TryParse(cboSolicitante.SelectedValue, out aux) && aux > 0)
                entidad.ptr_usuario_solicitante = aux;

            if (int.TryParse(cboOrden.SelectedValue, out aux) && aux > 0)
                entidad.ptr_orden_trabajo = aux;

            /* La vigencia al revés se dice acá y no se deja llegar al SP: el
               mensaje es el mismo, pero llega sin un viaje a la base. */
            if (entidad.ptr_fecha_vigencia_inicio_utc != null &&
                entidad.ptr_fecha_vigencia_fin_utc != null &&
                entidad.ptr_fecha_vigencia_fin_utc < entidad.ptr_fecha_vigencia_inicio_utc)
                throw new Exception("La vigencia termina antes de empezar.");

            /* El control sube lo que se haya elegido y devuelve el id; si no
               se eligio nada devuelve el que ya tenia, para no perderlo al
               editar. Lanza si la subida falla: guardar diciendo que todo
               salio bien cuando el documento no quedo es lo peor que puede
               pasar aca. */
            int archivo = wucAdjunto.Guardar();

            if (archivo > 0) entidad.ptr_archivo = archivo;

            PermisoTrabajoController controller = new PermisoTrabajoController();

            Respuesta respuesta = (Id > 0)
                                ? controller.UpdatePermiso(entidad)
                                : controller.InsertPermiso(entidad);

            if (respuesta.error)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                return;
            }

            /* Se recuerda el id para que un segundo Guardar edite en vez de
               crear otro permiso. */
            if (Id == 0) Id = respuesta.codigo;

            Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>El adjunto que ya tenía, para no perderlo al editar.</summary>
    protected int ArchivoActual()
    {
        if (Id == 0) return 0;

        PermisoTrabajoController controller = new PermisoTrabajoController();
        PermisoTrabajo p = controller.GetPermiso(Id);

        return (p != null && p.ptr_archivo != null) ? p.ptr_archivo.Value : 0;
    }
}
