using Facilityges.Controller;
using Facilityges.Model;
using SitioBase;
using System;
using System.IO;
using System.Web.UI;

public partial class View_Root_AplicacionesMoviles_NuevaAplicacionMovil : System.Web.UI.Page
{
    public int IdApp
    {
        get { return Convert.ToInt32(ViewState["IdApp"]); }
        set { ViewState.Add("IdApp", value); }
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
                    if (kv.Length == 2 && kv[0] == "IdApp")
                        IdApp = int.Parse(kv[1]);
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
        if (IdApp <= 0) return;

        AplicacionMovil item = controller.GetLatestVersion(IdApp);
        if (item == null)
        {
            var lista = controller.GetAplicacionesMoviles(IdApp);
            if (lista == null || lista.Count == 0) return;
            item = lista[0];
        }

        divID.Visible = true;
        lblID.Text = item.app_id.ToString();
        txtNombre.Text = item.app_nombre;
        txtDescripcion.Text = item.app_descripcion;
        txtPaqueteAndroid.Text = item.app_paquete_android;
        txtPaqueteIos.Text = item.app_paquete_ios;
        txtUrlAndroid.Text = item.app_url_store_android;
        txtUrlIos.Text = item.app_url_store_ios;
        chkActiva.Checked = item.app_activa;

        if (!string.IsNullOrEmpty(item.app_ruta_logo))
        {
            lblRutaLogo.Text = "Ruta actual: " + item.app_ruta_logo;
            lblRutaLogo.Visible = true;
            imgLogoActual.ImageUrl = ResolveUrl("~/" + item.app_ruta_logo);
            imgLogoActual.CssClass = "logo-preview visible";
        }

        if (!string.IsNullOrEmpty(item.app_ruta_badge_android))
        {
            lblRutaBadgeAndroid.Text = "Ruta actual: " + item.app_ruta_badge_android;
            lblRutaBadgeAndroid.Visible = true;
            imgBadgeAndroidActual.ImageUrl = ResolveUrl("~/" + item.app_ruta_badge_android);
            imgBadgeAndroidActual.CssClass = "badge-preview visible";
        }

        if (!string.IsNullOrEmpty(item.app_ruta_badge_ios))
        {
            lblRutaBadgeIos.Text = "Ruta actual: " + item.app_ruta_badge_ios;
            lblRutaBadgeIos.Visible = true;
            imgBadgeIosActual.ImageUrl = ResolveUrl("~/" + item.app_ruta_badge_ios);
            imgBadgeIosActual.CssClass = "badge-preview visible";
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            AplicacionMovil model = new AplicacionMovil();
            model.app_id = IdApp;
            model.app_nombre = txtNombre.Text.Trim();
            model.app_descripcion = txtDescripcion.Text.Trim();
            model.app_paquete_android = txtPaqueteAndroid.Text.Trim();
            model.app_paquete_ios = txtPaqueteIos.Text.Trim();
            model.app_url_store_android = txtUrlAndroid.Text.Trim();
            model.app_url_store_ios = txtUrlIos.Text.Trim();
            model.app_activa = chkActiva.Checked;

            // Logo
            if (fldLogo.HasFile && fldLogo.PostedFile.ContentLength > 0)
            {
                string nombreArchivo = Path.GetFileName(fldLogo.FileName);
                string rutaRel = AplicacionMovilController.BuildLogoPath(model.app_nombre, "logo" + Path.GetExtension(nombreArchivo));
                GuardarArchivo(fldLogo, rutaRel);
                model.app_ruta_logo = rutaRel;
            }

            // Badge Android
            if (fldBadgeAndroid.HasFile && fldBadgeAndroid.PostedFile.ContentLength > 0)
            {
                string nombreArchivo = Path.GetFileName(fldBadgeAndroid.FileName);
                string rutaRel = AplicacionMovilController.BuildBadgePath(model.app_nombre, "ANDROID", "badge_google_play" + Path.GetExtension(nombreArchivo));
                GuardarArchivo(fldBadgeAndroid, rutaRel);
                model.app_ruta_badge_android = rutaRel;
            }

            // Badge iOS
            if (fldBadgeIos.HasFile && fldBadgeIos.PostedFile.ContentLength > 0)
            {
                string nombreArchivo = Path.GetFileName(fldBadgeIos.FileName);
                string rutaRel = AplicacionMovilController.BuildBadgePath(model.app_nombre, "IOS", "badge_app_store" + Path.GetExtension(nombreArchivo));
                GuardarArchivo(fldBadgeIos, rutaRel);
                model.app_ruta_badge_ios = rutaRel;
            }

            Respuesta respuesta = IdApp > 0 ? controller.UpdAplicacionMovil(model) : controller.InsAplicacionMovil(model);

            if (!respuesta.error)
            {
                IdApp = respuesta.codigo > 0 ? respuesta.codigo : IdApp;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }

    private void GuardarArchivo(System.Web.UI.WebControls.FileUpload control, string rutaRelativa)
    {
        string rutaFisica = Server.MapPath("~/" + rutaRelativa);
        Directory.CreateDirectory(Path.GetDirectoryName(rutaFisica));
        control.SaveAs(rutaFisica);
    }
}
