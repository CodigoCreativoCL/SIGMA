using SitioBase.Controller;
using System;

public partial class Master_Default : System.Web.UI.MasterPage
{
    private MenuMaterialApoyoController menuCapsulaController = new MenuMaterialApoyoController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!SitioBase.Token.TokenSeguridad())
        {
            Response.Redirect("~/Login.aspx");
        }

        // El permiso de la pagina sale de su propia URL contra Menus.mnu_link.
        // Por eso ninguna pagina bajo este master declara su permiso.
        SitioBase.Token.ExigirPagina();

        /* Alimentador de la UF (ANEXO F §4).
           Se llama en cada visita pero solo trabaja una vez al dia, y nunca
           lanza: si la fuente esta caida, arrastra el ultimo valor conocido
           y sigue. Va aqui porque este hosting no da SQL Agent; el dia que
           lo haya, se programa el job y esta linea se retira. */
        UfController.AsegurarValorDeHoy();

        /* Compuerta de suscripcion (ANEXO F §6.6 · HU-193).
           Va DESPUES de ExigirPagina: primero se resuelve si la persona
           puede ver esta pantalla, y recien despues si su empresa esta al
           dia. Al reves, un cliente vencido veria la pagina de renovacion
           al pedir una pantalla que igual tenia prohibida.
           No aplica a las cuentas de plataforma, que no tienen cliente. */
        SitioBase.SuscripcionAcceso.Exigir();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (SitioBase.Token.TokenSeguridad())
        {
            PintarClienteActual();
            PintarAvisoSuscripcion();

            if (SitioBase.Session.UsuarioFoto() != null)
            {
                string base64String = SitioBase.Session.UsuarioFoto();

                this.imgUsuario.ImageUrl = "data:image/jpeg;base64," + base64String;

                this.imgUsuarioLateral.ImageUrl = "data:image/jpeg;base64," + base64String;

            }
            else
            {
                // El .png que se referenciaba aqui no existe en Imagen/: la
                // imagen salia rota para todo usuario sin foto. Se reemplaza
                // por un marcador SVG con los grises de la paleta.
                this.imgUsuario.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.svg");
                this.imgUsuarioLateral.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.svg");
            }

        }
    }

    /// <summary>
    /// Muestra el cliente con el que se esta trabajando (HU-002).
    ///
    /// Solo se ofrece cambiar cuando la persona pertenece a mas de uno: un
    /// enlace que lleva a una lista de un solo elemento es un paso de mas.
    /// Quien no pertenece a ninguno -la cuenta de plataforma- no ve nada.
    /// </summary>
    private void PintarClienteActual()
    {
        int idCliente = SitioBase.Session.ClienteId();

        ClienteSesionController controller = new ClienteSesionController();
        System.Collections.Generic.List<SitioBase.Model.Cliente> clientes =
            controller.GetClientesElegibles(int.Parse(SitioBase.Session.UsuarioId()));

        int cuantos = clientes != null ? clientes.Count : 0;

        if (cuantos == 0)
        {
            phCliente.Controls.Clear();
            return;
        }

        string nombre = SitioBase.Session.ClienteNombre();
        if (string.IsNullOrEmpty(nombre)) nombre = "Sin cliente";

        string html;

        if (cuantos > 1)
        {
            html = "<a href=\"" + ResolveUrl("~/SeleccionarCliente.aspx") + "\" class=\"sg-cliente-chip\" " +
                   "title=\"Cambiar de cliente\">" +
                   "<i class=\"mdi mdi-domain\"></i><span>" + Server.HtmlEncode(nombre) + "</span>" +
                   "<i class=\"mdi mdi-chevron-down\"></i></a>";
        }
        else
        {
            html = "<span class=\"sg-cliente-chip is-fijo\">" +
                   "<i class=\"mdi mdi-domain\"></i><span>" + Server.HtmlEncode(nombre) + "</span></span>";
        }

        phCliente.Controls.Clear();
        phCliente.Controls.Add(new System.Web.UI.LiteralControl(html));
    }

    /// <summary>
    /// El aviso de "por vencer" o "en gracia" (ANEXO F §6.6).
    ///
    /// El master solo pinta: el texto y el nivel los arma
    /// SuscripcionAcceso, porque cuántos días antes se avisa es un
    /// parámetro del negocio y no una decisión de esta página.
    /// </summary>
    private void PintarAvisoSuscripcion()
    {
        string texto = SitioBase.SuscripcionAcceso.TextoAviso();

        if (string.IsNullOrEmpty(texto))
        {
            pnlAvisoSuscripcion.Visible = false;
            return;
        }

        litAvisoSuscripcion.Text = Server.HtmlEncode(texto);
        pnlAvisoSuscripcion.CssClass = "sg-aviso-suscripcion " + SitioBase.SuscripcionAcceso.NivelAviso();
        pnlAvisoSuscripcion.Visible = true;

        /* El aviso lo ve todo el cliente -que un tecnico sepa que la
           suscripcion vence en tres dias es util, se lo dice a su jefe-,
           pero el enlace solo quien puede abrir esa pantalla. Ofrecer un
           link que termina en "no tienes permiso" es peor que no ofrecerlo. */
        lnkVerSuscripcion.Visible = SitioBase.SuscripcionAcceso.PuedeRenovar();
    }

    protected void lnkCerrarSession_Click(object sender, EventArgs e)
    {
        Session.Abandon();
        Session.RemoveAll();

        /* HU-003 escenario 1: "el boton Atras del navegador no permite
           volver a la aplicacion".

           Sin esto, cerrar sesion vacia la sesion en el servidor pero la
           pagina anterior sigue en la cache del navegador: Atras la vuelve
           a pintar con los datos del cliente a la vista. Estas cabeceras le
           dicen al navegador que no guarde nada, asi que al retroceder pide
           la pagina de nuevo y se encuentra con el login. */
        Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
        Response.Cache.SetExpires(DateTime.UtcNow.AddDays(-1));
        Response.Cache.SetNoStore();

        Response.Redirect("~/Login.aspx");
    }

}

