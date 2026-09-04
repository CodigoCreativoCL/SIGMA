using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un activo (HU-035).
///
/// SEGURIDAD EN EL SERVIDOR
///   La escritura la habilita Token.Puede("CREAR EDITAR ACTIVOS"), no el
///   esconder el botón: Bloqueo() pone en solo lectura los controles y
///   oculta Guardar cuando el usuario no tiene el permiso. El acceso a la
///   ficha misma lo resolvió ya el master con Token.ExigirPagina().
/// </summary>
public partial class View_Activos_Activos_Activo : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        // Querystring.Entero recibe el valor TAL COMO VIENE de la URL:
        // descifra por dentro. Descifrarlo antes lo haría descifrar dos veces
        // y la ficha se abriría en blanco como si fuera nueva.
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    /// <summary>
    /// Puebla los combos. Los catálogos NO se escriben a mano en el markup:
    /// se leen de su SEL_ (el estándar lo exige). Cada combo lleva su opción
    /// vacía cuando es opcional.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboTipo":
                {
                    ActivoTipoController controller = new ActivoTipoController();
                    List<ActivoTipo> lista = controller.GetActivoTipos(
                        new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "ati_id";
                    ctrl.DataTextField = "ati_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboEstado":
                {
                    ActivoEstadoController controller = new ActivoEstadoController();
                    List<ActivoEstado> lista = controller.GetActivoEstados(
                        new ActivoEstado { filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "aes_id";
                    ctrl.DataTextField = "aes_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboCriticidad":
                {
                    CriticidadNivelController controller = new CriticidadNivelController();
                    List<CriticidadNivel> lista = controller.GetCriticidadNiveles(
                        new CriticidadNivel { filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "crn_id";
                    ctrl.DataTextField = "crn_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboPlanta":
                {
                    ClienteInstalacionController controller = new ClienteInstalacionController();

                    // Este modelo trae los filtros como string (convención
                    // heredada de ClienteInstalacion); se respeta tal cual.
                    ClienteInstalacion filtro = new ClienteInstalacion();
                    filtro.filtro_cliente = cliente.ToString();
                    filtro.filtro_habilitado = "1";

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetClienteInstalaciones(filtro);
                    ctrl.DataValueField = "cin_id";
                    ctrl.DataTextField = "cin_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboArea":
                {
                    InstalacionAreaController controller = new InstalacionAreaController();
                    List<InstalacionArea> lista = controller.GetInstalacionAreas(
                        new InstalacionArea { iar_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Sin área", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "iar_id";
                    ctrl.DataTextField = "ruta";
                    ctrl.DataBind();
                    break;
                }

            case "cboCentroCosto":
                {
                    CentroCostoController controller = new CentroCostoController();
                    List<CentroCosto> lista = controller.GetCentrosCosto(
                        new CentroCosto { cco_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Sin centro de costo", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "cco_id";
                    ctrl.DataTextField = "ruta";
                    ctrl.DataBind();
                    break;
                }

            case "cboAnio":
                {
                    // Años del actual hacia atrás: la maquinaria industrial
                    // rara vez es anterior a 1950. Elegir de una lista evita
                    // tipeos como "20226" o un año futuro.
                    ctrl.Items.Add(new RadComboBoxItem("Sin dato", ""));
                    for (int anio = DateTime.Today.Year; anio >= 1950; anio--)
                        ctrl.Items.Add(new RadComboBoxItem(anio.ToString(), anio.ToString()));
                    break;
                }

            case "cboPadre":
                {
                    ActivoController controller = new ActivoController();
                    List<Activo> lista = controller.GetActivos(
                        new Activo { act_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Sin activo superior", ""));
                    ctrl.AppendDataBoundItems = true;

                    if (lista != null)
                    {
                        // Un activo no puede ser su propio padre: se quita de
                        // la lista al editar. Los descendientes los rechaza
                        // igual el SP; aquí se evita solo el caso evidente.
                        if (Id > 0) lista.RemoveAll(x => x.act_id == Id);

                        foreach (Activo a in lista)
                            ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));
                    }

                    break;
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

        if (Id > 0)
        {
            ActivoController controller = new ActivoController();
            Activo entidad = controller.GetActivo(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Activo", entidad.act_codigo);
            txtNombre.Text = entidad.act_nombre;

            SeleccionarCombo(cboTipo, entidad.act_activo_tipo);
            SeleccionarCombo(cboEstado, entidad.act_activo_estado);
            SeleccionarCombo(cboCriticidad, entidad.act_criticidad_nivel);
            SeleccionarCombo(cboPlanta, entidad.act_cliente_instalacion);

            if (entidad.act_instalacion_area != null) SeleccionarCombo(cboArea, entidad.act_instalacion_area.Value);
            if (entidad.act_centro_costo != null) SeleccionarCombo(cboCentroCosto, entidad.act_centro_costo.Value);
            if (entidad.act_activo_padre != null) SeleccionarCombo(cboPadre, entidad.act_activo_padre.Value);

            txtSerie.Text = entidad.act_numero_serie;
            txtFabricante.Text = entidad.act_fabricante;
            if (entidad.act_anio_fabricacion != null) SeleccionarCombo(cboAnio, entidad.act_anio_fabricacion.Value);
            calPuestaMarcha.Value = entidad.act_fecha_puesta_marcha;
            txtDescripcion.Text = entidad.act_descripcion;

            rdbSi.Checked = entidad.act_habilitado;
            rdbNo.Checked = !entidad.act_habilitado;

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.act_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.act_fecha_actualizacion);

            // Vista previa de la imagen actual, si la tiene.
            int idImagen = new ActivoImagenController().GetImagenId(Id, SitioBase.Session.ClienteId());
            if (idImagen > 0)
            {
                imgActual.Src = UrlArchivo.Ver(idImagen);
                pnlImagenActual.Visible = true;
            }
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    /// <summary>
    /// Selecciona un valor en un combo solo si la opción existe. Evita la
    /// excepción de RadComboBox cuando el id ya no está en la lista (por
    /// ejemplo, un tipo deshabilitado después de haberse asignado).
    /// </summary>
    private void SeleccionarCombo(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR ACTIVOS");

        /* Nunca se escribe a mano: lo genera el SP al crear, y despues
               identifica el registro. */
            litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Activo");
            txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtSerie.ReadOnly = !puedeEditar;
        txtFabricante.ReadOnly = !puedeEditar;
        cboAnio.ReadOnly = !puedeEditar;
        calPuestaMarcha.Enabled = puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;

        cboTipo.ReadOnly = !puedeEditar;
        cboEstado.ReadOnly = !puedeEditar;
        cboCriticidad.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        cboArea.ReadOnly = !puedeEditar;
        cboCentroCosto.ReadOnly = !puedeEditar;
        cboPadre.ReadOnly = !puedeEditar;

        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboTipo.SelectedValue))
                throw new Exception("Debe elegir el tipo de activo.");
            if (string.IsNullOrEmpty(cboEstado.SelectedValue))
                throw new Exception("Debe elegir el estado del activo.");
            if (string.IsNullOrEmpty(cboCriticidad.SelectedValue))
                throw new Exception("Debe elegir la criticidad del activo.");
            if (string.IsNullOrEmpty(cboPlanta.SelectedValue))
                throw new Exception("Debe elegir la planta a la que pertenece el activo.");

            Activo entidad = new Activo();
            ActivoController controller = new ActivoController();

            entidad.act_id = Id;
            entidad.act_cliente = SitioBase.Session.ClienteId();
            entidad.act_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            entidad.act_activo_tipo = int.Parse(cboTipo.SelectedValue);
            entidad.act_activo_estado = int.Parse(cboEstado.SelectedValue);
            entidad.act_criticidad_nivel = int.Parse(cboCriticidad.SelectedValue);
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como ACT-<id>: el
               codigo depende del ID, y el ID no existe hasta despues del
               INSERT, asi que no hay forma de calcularlo antes.

               AUTO y no vacio: el SP valida que el codigo venga ANTES de
               insertar, asi que un vacio se rechaza con "indique el codigo".
               AUTO pasa esa validacion, nunca queda guardado, y el SP lo
               reemplaza en cuanto conoce el ID.

               Al editar viaja el que ya tiene. No se regenera nunca: el
               codigo esta impreso en su etiqueta, y cambiarlo dejaria la
               etiqueta pegada apuntando a algo que no existe. */
            entidad.act_codigo = SitioBase.CodigoModulo.Componer("Activo", txtCodigo.Text);
            entidad.act_nombre = txtNombre.Text.Trim();
            entidad.act_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboArea.SelectedValue))
                entidad.act_instalacion_area = int.Parse(cboArea.SelectedValue);
            if (!string.IsNullOrEmpty(cboCentroCosto.SelectedValue))
                entidad.act_centro_costo = int.Parse(cboCentroCosto.SelectedValue);
            if (!string.IsNullOrEmpty(cboPadre.SelectedValue))
                entidad.act_activo_padre = int.Parse(cboPadre.SelectedValue);

            if (!string.IsNullOrEmpty(txtSerie.Text.Trim()))
                entidad.act_numero_serie = txtSerie.Text.Trim();
            if (!string.IsNullOrEmpty(txtFabricante.Text.Trim()))
                entidad.act_fabricante = txtFabricante.Text.Trim();
            if (!string.IsNullOrEmpty(cboAnio.SelectedValue))
                entidad.act_anio_fabricacion = int.Parse(cboAnio.SelectedValue);

            // El calendario ya entrega un DateTime? válido; solo se rechaza
            // una fecha futura, que para una puesta en marcha no tiene sentido.
            if (calPuestaMarcha.Value != null && calPuestaMarcha.Value.Value.Date > DateTime.Today)
                throw new Exception("La fecha de puesta en marcha no puede ser futura.");
            entidad.act_fecha_puesta_marcha = calPuestaMarcha.Value;

            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim()))
                entidad.act_descripcion = txtDescripcion.Text.Trim();

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateActivo(entidad)
                : controller.InsertActivo(entidad);

            if (!respuesta.error)
            {
                Id = respuesta.codigo;

                // La imagen es opcional: si se eligió una, se sube y se enlaza
                // como imagen de referencia del activo. Un fallo aquí no anula
                // el guardado del activo; solo avisa.
                string avisoImg = GuardarImagen(Id);

                Tools.tools.ClientAlert(respuesta.detalle + avisoImg, "ok", true);
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
    /// Sube la imagen elegida (si la hay) y la deja como imagen del activo.
    /// Devuelve "" si todo fue bien o no había imagen, o un aviso si falló la
    /// carga —sin echar abajo el guardado del activo, que ya está hecho—.
    /// </summary>
    private string GuardarImagen(int activo)
    {
        if (activo <= 0) return "";

        bool haySubida = fuImagen != null && fuImagen.HasFile;

        // Sin imagen nueva: si marcó "quitar la imagen actual", se desvincula.
        if (!haySubida)
        {
            if (chkQuitarImagen != null && chkQuitarImagen.Checked)
                new ActivoImagenController().DesvincularImagen(activo);
            return "";
        }

        try
        {
            byte[] contenido = fuImagen.FileBytes;
            if (contenido == null || contenido.Length == 0) return "";

            Archivo arc = new Archivo();
            arc.arc_cliente = SitioBase.Session.ClienteId();
            arc.arc_archivo_categoria = 10;   // REFERENCIA (imagen de referencia)
            arc.arc_nombre_original = System.IO.Path.GetFileName(fuImagen.FileName);
            arc.arc_mime = fuImagen.PostedFile != null ? fuImagen.PostedFile.ContentType : null;
            arc.contenido = contenido;

            Respuesta r = new ArchivoController().InsertArchivo(arc, "activos");
            if (r.error || r.codigo <= 0)
                return " (la imagen no se pudo guardar: " + r.detalle + ")";

            int vin = new ActivoImagenController().VincularImagen(activo, r.codigo);
            if (vin < 0)
                return " (la imagen se subió pero no se pudo enlazar al activo)";

            return "";
        }
        catch (Exception ex)
        {
            return " (la imagen no se pudo guardar: " + ex.Message + ")";
        }
    }
}
