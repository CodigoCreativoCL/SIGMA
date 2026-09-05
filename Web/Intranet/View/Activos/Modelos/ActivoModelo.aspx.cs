using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.IO;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un modelo de activo (HU-031). La escritura la habilita
/// Token.Puede("CREAR EDITAR MODELOS ACTIVO"). Un modelo global de la
/// plataforma se muestra en solo lectura: no se edita desde el cliente.
/// </summary>
public partial class View_Activos_Modelos_ActivoModelo : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    // Un modelo global (amo_cliente NULL) no lo edita el cliente.
    public bool EsGlobal
    {
        get { return ViewState["EsGlobal"] != null && (bool)ViewState["EsGlobal"]; }
        set { ViewState["EsGlobal"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        if (ctrl.ID == "cboTipo")
        {
            ActivoTipoController c = new ActivoTipoController();
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = c.GetActivoTipos(new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });
            ctrl.DataValueField = "ati_id"; ctrl.DataTextField = "ati_nombre"; ctrl.DataBind();
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarArchivos();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    /// <summary>URL para ver/descargar un archivo del modelo.</summary>
    public string VerUrl(int idArchivo) { return UrlArchivo.Ver(idArchivo); }

    /// <summary>Lista los archivos adjuntos del modelo (edición).</summary>
    protected void CargarArchivos()
    {
        List<ModeloArchivo> l = new ActivoModeloArchivoController().GetArchivos(Id, SitioBase.Session.ClienteId());
        if (l == null) l = new List<ModeloArchivo>();
        rptArchivos.DataSource = l;
        rptArchivos.DataBind();
    }

    /// <summary>El "Quitar" hace postback completo (el form es multipart por el uploader).</summary>
    protected void rptArchivos_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType == ListItemType.Item || e.Item.ItemType == ListItemType.AlternatingItem)
            foreach (Control ctl in e.Item.Controls)
                if (ctl is LinkButton)
                    ScriptManager.GetCurrent(Page).RegisterPostBackControl((LinkButton)ctl);
    }

    protected void rptArchivos_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName == "quitar")
        {
            int idArchivo;
            if (int.TryParse(Convert.ToString(e.CommandArgument), out idArchivo) && Id > 0)
                new ActivoModeloArchivoController().Desvincular(Id, idArchivo);
            CargarArchivos();
        }
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ActivoModeloController c = new ActivoModeloController();
            ActivoModelo x = c.GetModelo(Id);

            lblId.Text = Id.ToString();
            txtFabricante.Text = x.amo_fabricante;
            txtNombre.Text = x.amo_nombre;
            txtDescripcion.Text = x.amo_descripcion;
            EsGlobal = x.es_global;

            SeleccionarCombo(cboTipo, x.amo_activo_tipo);

            rdbSi.Checked = x.amo_habilitado;
            rdbNo.Checked = !x.amo_habilitado;

            wucAuditoria.Mostrar(x.usuario_creacion_nombre, x.amo_fecha_creacion,
                                 x.usuario_actualizacion_nombre, x.amo_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    private void SeleccionarCombo(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR MODELOS ACTIVO") && !EsGlobal;

        pnlGlobal.Visible = EsGlobal;

        cboTipo.ReadOnly = !puedeEditar;
        txtFabricante.ReadOnly = !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        pnlSubir.Visible = puedeEditar;   // el uploader solo si puede editar (los archivos igual se ven)

        btnGuardar.Visible = puedeEditar;
    }

    /// <summary>
    /// Sube los archivos elegidos (opcional, varios) y los enlaza al modelo.
    /// Reutiliza el sistema Archivo (Azure). PDF -> DOCUMENTO, imagen -> REFERENCIA.
    /// </summary>
    private void GuardarArchivos(int modelo)
    {
        if (modelo <= 0 || fuModelo == null || !fuModelo.HasFiles) return;

        foreach (System.Web.HttpPostedFile f in fuModelo.PostedFiles)
        {
            if (f == null || f.ContentLength == 0) continue;
            try
            {
                byte[] contenido;
                using (MemoryStream ms = new MemoryStream()) { f.InputStream.CopyTo(ms); contenido = ms.ToArray(); }
                if (contenido.Length == 0) continue;

                string mime = f.ContentType ?? "";
                bool esImagen = mime.StartsWith("image", StringComparison.OrdinalIgnoreCase);

                Archivo arc = new Archivo();
                arc.arc_cliente = SitioBase.Session.ClienteId();
                arc.arc_archivo_categoria = esImagen ? 10 : 9;   // 10 REFERENCIA / 9 DOCUMENTO
                arc.arc_nombre_original = Path.GetFileName(f.FileName);
                arc.arc_mime = mime;
                arc.contenido = contenido;

                Respuesta r = new ArchivoController().InsertArchivo(arc, "modelos");
                if (!r.error && r.codigo > 0)
                    new ActivoModeloArchivoController().Vincular(modelo, r.codigo);
            }
            catch (Exception) { /* un archivo que falla no anula el guardado del modelo */ }
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (EsGlobal) throw new Exception("Este es un modelo global de la plataforma y no se edita desde aquí.");
            if (string.IsNullOrEmpty(cboTipo.SelectedValue)) throw new Exception("Debe elegir el tipo de activo.");
            if (string.IsNullOrEmpty(txtNombre.Text.Trim())) throw new Exception("Debe indicar el modelo.");

            ActivoModelo x = new ActivoModelo();
            ActivoModeloController c = new ActivoModeloController();

            x.amo_id = Id;
            x.amo_cliente = SitioBase.Session.ClienteId();
            x.amo_activo_tipo = int.Parse(cboTipo.SelectedValue);
            x.amo_nombre = txtNombre.Text.Trim();
            x.amo_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(txtFabricante.Text.Trim())) x.amo_fabricante = txtFabricante.Text.Trim();
            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim())) x.amo_descripcion = txtDescripcion.Text.Trim();

            Respuesta r = (Id > 0) ? c.UpdateModelo(x) : c.InsertModelo(x);

            if (!r.error)
            {
                Id = r.codigo;
                GuardarArchivos(Id);   // sube los adjuntos elegidos (opcional)
                Tools.tools.ClientAlert(r.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(r.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
