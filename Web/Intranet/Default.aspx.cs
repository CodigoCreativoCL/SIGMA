using System;
using System.Globalization;

public partial class _Default : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        CargarEncabezado();
    }

    /// <summary>
    /// El saludo del inicio. Sale de la sesion, que ya trae el nombre
    /// del login: no hace falta volver a consultar el usuario.
    /// </summary>
    protected void CargarEncabezado()
    {
        string nombre = SitioBase.Session.UsuarioNombre();

        if (!string.IsNullOrWhiteSpace(nombre))
            nombre = nombre.Trim().Split(' ')[0];

        litNombre.Text = Server.HtmlEncode(nombre);

        CultureInfo es = CultureInfo.GetCultureInfo("es-CL");
        litFecha.Text = DateTime.Now.ToString("dddd, d 'de' MMMM", es).ToUpper(es);
    }
}
