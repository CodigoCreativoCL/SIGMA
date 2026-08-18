using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.UI.WebControls;

public partial class _Default : System.Web.UI.Page
{


    protected void Page_Load(object sender, EventArgs e)
    {
        CargarSaludo();

    }

    protected void CargarSaludo()
    {
        int hora = DateTime.Now.Hour;

        if (hora < 12)
            litSaludo.Text = "Buenos días";
        else if (hora < 19)
            litSaludo.Text = "Buenas tardes";
        else
            litSaludo.Text = "Buenas noches";

        string nombre = SitioBase.Session.UsuarioNombre();
        litNombreUsuario.Text = !string.IsNullOrEmpty(nombre) ? nombre.Split(' ')[0] : SitioBase.Session.UsuarioLogin();

        string perfiles = SitioBase.Session.UsuarioPerfiles();
        litPerfilActual.Text = !string.IsNullOrEmpty(perfiles) ? perfiles : "Usuario";

        CultureInfo cultura = new CultureInfo("es-ES");
        string fecha = DateTime.Now.ToString("dddd dd 'de' MMMM 'de' yyyy", cultura);
        litFechaActual.Text = char.ToUpper(fecha[0]) + fecha.Substring(1);
    }
}
