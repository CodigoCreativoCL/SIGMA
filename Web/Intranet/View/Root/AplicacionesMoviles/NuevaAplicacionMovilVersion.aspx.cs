using Facilityges.Controller;
using Facilityges.Model;
using SitioBase;
using System;
using System.Collections.Generic;
using System.IO;
using System.Web.UI;

public partial class View_Root_AplicacionesMoviles_NuevaAplicacionMovilVersion : System.Web.UI.Page
{
    public int IdApp
    {
        get { return Convert.ToInt32(ViewState["IdApp"]); }
        set { ViewState.Add("IdApp", value); }
    }

    public int IdVersion
    {
        get { return Convert.ToInt32(ViewState["IdVersion"]); }
        set { ViewState.Add("IdVersion", value); }
    }

    private readonly AplicacionMovilController controller = new AplicacionMovilController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!Token.TokenSeguridad()) Response.Redirect("~/Login.aspx");

        if (!IsPostBack)
        {
            string raw = Request.QueryString["query"];
            if (!string.IsNullOrEmpty(raw))
            {
                string[] parts = Tools.Crypto.Decrypt(Server.UrlDecode(raw)).Split('&');
                foreach (string p in parts)
                {
                    string[] kv = p.Split('=');
                    if (kv.Length != 2) continue;
                    if (kv[0] == "IdApp") IdApp = int.Parse(kv[1]);
                    if (kv[0] == "IdVersion") IdVersion = int.Parse(kv[1]);
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);

        if (!IsPostBack) CargarDatos();
        udPanel.Update();
    }

    private void CargarDatos()
    {
        if (IdVersion <= 0) return;

        List<AppVersion> vers = controller.GetVersions(IdApp);
        if (vers == null) return;

        AppVersion ver = vers.Find(v => v.apv_id == IdVersion);
        if (ver == null) return;

        divID.Visible = true;
        divModoEdicion.Visible = true;
        lblID.Text = ver.apv_id.ToString();

        txtVersion.Text = ver.apv_version_nombre;
        txtVersion.Enabled = false;

        string plat = (ver.apv_plataforma ?? "").ToUpper();
        cboPlataforma.SelectedValue = (plat == "ANDROID" || plat == "IOS") ? plat : "AMBAS";
        cboPlataforma.Enabled = false;

        if (ver.apv_version_codigo.HasValue)
            txtCodigoAndroid.Text = ver.apv_version_codigo.Value.ToString();
        txtCodigoAndroid.Enabled = false;

        txtBuildIos.Text = ver.apv_build_ios ?? "";
        txtBuildIos.Enabled = false;

        txtMinAndroid.Text = ver.apv_min_os_android ?? "";
        txtMinAndroid.Enabled = false;

        txtMinIos.Text = ver.apv_min_os_ios ?? "";
        txtMinIos.Enabled = false;

        txtNotas.Text = ver.apv_notas ?? "";
        chkObligatoria.Checked = ver.apv_obligatoria;

        if (!string.IsNullOrEmpty(ver.apv_ruta_apk))
        {
            lblRutaApk.Text = "APK actual: " + Path.GetFileName(ver.apv_ruta_apk);
            lblRutaApk.Visible = true;
        }
        if (!string.IsNullOrEmpty(ver.apv_ruta_ipa))
        {
            lblRutaIpa.Text = "IPA actual: " + Path.GetFileName(ver.apv_ruta_ipa);
            lblRutaIpa.Visible = true;
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (IdVersion > 0)
                GuardarEdicion();
            else
                GuardarNueva();
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }

    // Crear nueva versión

    private void GuardarNueva()
    {
        string appNombre = ObtenerNombreApp();
        string versionNombre = txtVersion.Text.Trim();

        AppVersion model = new AppVersion();
        model.apv_app = IdApp;
        model.apv_version_nombre = versionNombre;
        model.apv_plataforma = cboPlataforma.SelectedValue;
        model.apv_build_ios = txtBuildIos.Text.Trim();
        model.apv_min_os_android = txtMinAndroid.Text.Trim();
        model.apv_min_os_ios = txtMinIos.Text.Trim();
        model.apv_notas = txtNotas.Text.Trim();
        model.apv_obligatoria = chkObligatoria.Checked;

        string rawCodigo = txtCodigoAndroid.Text.Trim();
        if (!string.IsNullOrEmpty(rawCodigo))
            model.apv_version_codigo = int.Parse(rawCodigo);

        // Guardar APK en carpeta local ~/Apps/
        if (fldApk.HasFile && fldApk.PostedFile.ContentLength > 0)
        {
            string nombreApk = Path.GetFileName(fldApk.FileName);
            if (string.IsNullOrEmpty(nombreApk)) nombreApk = "app.apk";
            string rutaRel = AplicacionMovilController.BuildApkLocalPath(appNombre, versionNombre, nombreApk);
            GuardarArchivo(fldApk, rutaRel);
            model.apv_ruta_apk = rutaRel;
        }

        // Guardar IPA en carpeta local ~/Apps/
        if (fldIpa.HasFile && fldIpa.PostedFile.ContentLength > 0)
        {
            string nombreIpa = Path.GetFileName(fldIpa.FileName);
            if (string.IsNullOrEmpty(nombreIpa)) nombreIpa = "app.ipa";
            string rutaRel = AplicacionMovilController.BuildIpaLocalPath(appNombre, versionNombre, nombreIpa);
            GuardarArchivo(fldIpa, rutaRel);
            model.apv_ruta_ipa = rutaRel;
        }

        Respuesta respuesta = controller.InsertVersion(model);

        if (!respuesta.error)
        {
            IdVersion = respuesta.codigo;
            Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
        }
        else
        {
            Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
    }

    // Edición: solo actualiza los archivos APK / IPA

    private void GuardarEdicion()
    {
        string appNombre = ObtenerNombreApp();
        string versionNombre = txtVersion.Text.Trim();

        string rutaApk = null;
        string rutaIpa = null;

        // Re-guardar APK en carpeta local ~/Apps/
        if (fldApk.HasFile && fldApk.PostedFile.ContentLength > 0)
        {
            string nombreApk = Path.GetFileName(fldApk.FileName);
            if (string.IsNullOrEmpty(nombreApk)) nombreApk = "app.apk";
            string rutaRel = AplicacionMovilController.BuildApkLocalPath(appNombre, versionNombre, nombreApk);
            GuardarArchivo(fldApk, rutaRel);
            rutaApk = rutaRel;
        }

        // Re-guardar IPA en carpeta local ~/Apps/
        if (fldIpa.HasFile && fldIpa.PostedFile.ContentLength > 0)
        {
            string nombreIpa = Path.GetFileName(fldIpa.FileName);
            if (string.IsNullOrEmpty(nombreIpa)) nombreIpa = "app.ipa";
            string rutaRel = AplicacionMovilController.BuildIpaLocalPath(appNombre, versionNombre, nombreIpa);
            GuardarArchivo(fldIpa, rutaRel);
            rutaIpa = rutaRel;
        }

        if (rutaApk == null && rutaIpa == null)
        {
            Tools.tools.ClientAlert("Seleccione al menos un archivo (APK o IPA) para actualizar.", "alerta");
            return;
        }

        Respuesta respuesta = controller.ActualizarRutas(IdVersion, rutaApk, rutaIpa);
        Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
    }

    // Helpers

    private void GuardarArchivo(System.Web.UI.WebControls.FileUpload control, string rutaRelativa)
    {
        string rutaFisica = Server.MapPath("~/" + rutaRelativa);
        Directory.CreateDirectory(Path.GetDirectoryName(rutaFisica));
        control.SaveAs(rutaFisica);
    }

    private string ObtenerNombreApp()
    {
        List<AplicacionMovil> apps = controller.GetAplicacionesMoviles(IdApp);
        return (apps != null && apps.Count > 0) ? apps[0].app_nombre : IdApp.ToString();
    }
}
