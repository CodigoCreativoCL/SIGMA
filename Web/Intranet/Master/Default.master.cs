using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.UI;

public partial class Master_Default : System.Web.UI.MasterPage
{
    private MenuMaterialApoyoController menuCapsulaController = new MenuMaterialApoyoController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!SitioBase.Token.TokenSeguridad())
        {
            Response.Redirect("~/Login.aspx");
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (SitioBase.Token.TokenSeguridad())
        {
            if (SitioBase.Session.UsuarioFoto() != null)
            {
                string base64String = SitioBase.Session.UsuarioFoto();

                this.imgUsuario.ImageUrl = "data:image/jpeg;base64," + base64String;

                this.imgUsuarioLateral.ImageUrl = "data:image/jpeg;base64," + base64String;

            }
            else
            {
                this.imgUsuario.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.png");
                this.imgUsuarioLateral.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.png");
            }

            CargarMaterialApoyo();
        }
    }

    protected void lnkCerrarSession_Click(object sender, EventArgs e)
    {
        Session.Abandon();
        Session.RemoveAll();

        Response.Redirect("~/Login.aspx");
    }
    protected void CargarMaterialApoyo()
    {
        #region 0.- Datos Base
        StringBuilder sb = new StringBuilder();

        string baseUrl = Request.Url.Scheme + "://" + Request.Url.Authority + Request.ApplicationPath.TrimEnd('/') + "/";
        string pathUrl = Request.Url.ToString().Replace(baseUrl, "~/").Split('?')[0];

        // 0.1.-  Obtengo los materiales de apoyo
        MenuMaterialApoyo filtro = new MenuMaterialApoyo();
        filtro.mma_ruta = pathUrl;
        filtro.filtro_habilitado = "true";
        List<MenuMaterialApoyo> menuMaterialApoyos = menuCapsulaController.GetMenuMaterialApoyos(filtro);

        // 0.2.- Obtengo las estadisticas por usuario
        MenuMaterialApoyoEstadisticaController menuMaterialApoyoEstadisticaController = new MenuMaterialApoyoEstadisticaController();
        MenuMaterialApoyoEstadistica menuMaterialApoyoEstadistica = new MenuMaterialApoyoEstadistica();
        menuMaterialApoyoEstadistica.mae_usuario = int.Parse(SitioBase.Session.UsuarioId());

        List<MenuMaterialApoyoEstadistica> listaEstadisticas = menuMaterialApoyoEstadisticaController.GetEstadisticas(menuMaterialApoyoEstadistica);

        // Si no encuentro material de apoyo en el Menú retorno ocultando el icono en el navbar
        if (menuMaterialApoyos == null || menuMaterialApoyos.Count == 0)
        {
            capsulasMenuContainer.Visible = false;
            return;
        }

        #endregion

        foreach (MenuMaterialApoyo item in menuMaterialApoyos)
        {
            #region 1.- Buscar si el usuario ya reaccionó 
            List<MenuMaterialApoyoEstadistica> estadisticaUsuario = listaEstadisticas
                .Where(e => e.mae_menu_apoyo == item.mma_id)
                .ToList();

            bool usuarioLike = estadisticaUsuario.Any(e => e.mae_tipo == 1);
            bool usuarioDislike = estadisticaUsuario.Any(e => e.mae_tipo == 2);
            bool usuarioVisto = estadisticaUsuario.Any(e => e.mae_tipo == 3);

            // Colores activos según usuario
            string colorLike = usuarioLike ? "#d90429" : "#6c757d";
            string bgLike = usuarioLike ? "#ffe2e2" : "transparent";
            string colorDislike = usuarioDislike ? "#0a2463" : "#6c757d";
            string bgDislike = usuarioDislike ? "#e0e7ff" : "transparent";
            string colorView = usuarioVisto ? "#0a4d71" : "#6c757d";
            string bgView = usuarioVisto ? "#dff6ff" : "transparent";

            string dataLike = usuarioLike ? "true" : "false";
            string dataDislike = usuarioDislike ? "true" : "false";
            string dataView = usuarioVisto ? "true" : "false";
            #endregion
            #region 2.- Datos del Archivo
            string nombreCompleto = (item.mma_nombre ?? string.Empty).Trim();
            string nombreCorto = nombreCompleto.Length > 40 ? nombreCompleto.Substring(0, 40) + "..." : nombreCompleto;
            string extension = (Path.GetExtension(item.mma_ruta) ?? string.Empty).ToLower();

            string icono = "fa-file-o";
            string color = "#6c757d";
            bool esDescargable = false;

            switch (extension)
            {
                case ".pdf": icono = "fa-file-pdf"; color = "#e63946"; break;
                case ".xls":
                case ".xlsx":
                case ".csv": icono = "fa-file-excel"; color = "#2b9348"; esDescargable = true; break;
                case ".doc":
                case ".docx": icono = "fa-file-word"; color = "#1d4ed8"; esDescargable = true; break;
                case ".mp4":
                case ".webm":
                case ".mov":
                case ".avi": icono = "fa-play-circle"; color = "#0a2463"; break;
                case ".jpg":
                case ".jpeg":
                case ".png":
                case ".gif":
                case ".bmp":
                case ".webp": icono = "fa-file-image"; color = "#0a4d71"; break;
            }
            #endregion
            #region 3.- Configuracion de Querys y Spans
            // === Identificadores únicos ===
            string spnMegustaMenu = "spnMegustaMenu" + item.mma_id;
            string spnNoMegustaMenu = "spnNoMegustaMenu" + item.mma_id;
            string spnVistoMenu = "spnVistoMenu" + item.mma_id;

            // === Queries cifradas ===
            string idEncoded = Server.UrlEncode(Tools.Crypto.Encrypt("idMenu=" + item.mma_id));
            string queryRuta = Server.UrlEncode(Tools.Crypto.Encrypt("ruta=" + item.mma_ruta + "&nombre=" + item.mma_nombre));

            // Contadores en formatos miles
            string likes = item.meGusta.ToString("N0");
            string dislikes = item.noMeGusta.ToString("N0");
            string views = item.visto.ToString("N0");
            #endregion
            #region 4.- Construccion del HTML
            //  Contenedor principal 
            sb.AppendLine("<div class=\"material-item \">");
            sb.AppendLine("  <div class=\"d-flex justify-content-between align-items-center\">");

            //Enlace principal
            sb.Append("    <a class=\"material-link d-flex align-items-center\" style=\"text-decoration:none; color:#333;\" ");

            if (esDescargable)
            {
                string virtualPath = item.mma_ruta.Replace("~", "").Replace("//", "/");
                string fullPath = HttpContext.Current.Server.MapPath("~" + virtualPath);

                if (File.Exists(fullPath))
                {
                    string descargaUrl = ResolveUrl("~/MaterialApoyo/Mantenedores/DescargarArchivo.aspx?path=" + HttpUtility.UrlEncode(virtualPath));
                    sb.Append("href=\"#\" onclick=\"EstadoMaterial('" + idEncoded + "', '" + spnMegustaMenu + "', '" + spnNoMegustaMenu + "', '" + spnVistoMenu + "', 3); ");
                    sb.Append("window.open('" + descargaUrl + "', '_blank'); return false;\" ");
                    sb.Append("title=\"Descargar: " + HttpUtility.HtmlEncode(nombreCompleto) + "\">");
                }
                else
                {
                    sb.Append("href=\"#\" class=\"disabled\" title=\"Archivo no disponible\">");
                }
            }
            else
            {
                sb.Append("href=\"#\" onclick=\"abrirCapsula('" + queryRuta + "'); EstadoMaterial('" + idEncoded + "', '" + spnMegustaMenu + "', '" + spnNoMegustaMenu + "', '" + spnVistoMenu + "', 3); return false;\" ");
                sb.Append("title=\"Ver: " + HttpUtility.HtmlEncode(nombreCompleto) + "\">");
            }

            sb.Append("      <i class=\"fa " + icono + "\" style=\"color:" + color + "; font-size:13px; margin-right:8px;\"></i>");
            sb.Append("      <span class=\"truncate-name\">" + HttpUtility.HtmlEncode(nombreCorto) + "</span>");
            sb.AppendLine("    </a>");
            sb.AppendLine("  </div>");

            // === Estadísticas ===
            sb.AppendLine("  <div class=\"stats-row\">");
            sb.AppendLine("    <div class=\"stats-right\">");

            // Me gusta
            sb.Append("      <span class='stat-item' data-title='Me gusta' data-color='rojo' role='button' style='cursor:pointer;' ");
            sb.Append("     onclick=\"EstadoMaterial('" + idEncoded + "','" + spnMegustaMenu + "','" + spnNoMegustaMenu + "','" + spnVistoMenu + "',1); return false;\">");
            sb.Append("        <span class='icon-badge like' data-active='" + dataLike + "'>");
            sb.Append("         <i class='far fa-heart'></i>");
            sb.Append("            <span class='counter' id='" + spnMegustaMenu + "'>" + likes + "</span>");
            sb.Append("        </span>");
            sb.AppendLine("      </span>");

            // No me gusta
            sb.Append("      <span class='stat-item' data-title='No me gusta' data-color='gris' role='button' style='cursor:pointer;' ");
            sb.Append("onclick=\"EstadoMaterial('" + idEncoded + "','" + spnMegustaMenu + "','" + spnNoMegustaMenu + "','" + spnVistoMenu + "',2); return false;\">");
            sb.Append("        <span class='icon-badge dislike' data-active='" + dataDislike + "'>");
            sb.Append(" <i class='far fa-thumbs-down'></i>");
            sb.Append("            <span class='counter' id='" + spnNoMegustaMenu + "'>" + dislikes + "</span>");
            sb.Append("        </span>");
            sb.AppendLine("      </span>");

            // Vistos
            sb.Append("      <span class='stat-item' data-title='Visto' data-color='azul' style='cursor:default;'>");
            sb.Append("        <span class='icon-badge view' data-active='" + dataView + "'>");
            sb.Append(" <i class='far fa-eye'></i>");
            sb.Append("            <span class='counter' id='" + spnVistoMenu + "'>" + views + "</span>");
            sb.Append("        </span>");
            sb.AppendLine("      </span>");

            sb.AppendLine("    </div>");
            sb.AppendLine("  </div>");

            sb.AppendLine("</div>");

            #endregion
        }

        ltlCapsulas.Controls.Clear();
        ltlCapsulas.Controls.Add(new LiteralControl(sb.ToString()));
    }

}

