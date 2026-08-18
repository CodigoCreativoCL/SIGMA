using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;

public partial class View_Comun_Controls_MenusLateral : System.Web.UI.UserControl
{
    private MenusController menusController = new MenusController();

    protected void Page_Load(object sender, EventArgs e)
    {
        CargarMenus();
    }

    protected void CargarMenus()
    {
        Menus menu = new Menus();

        List<Menus> menus = menusController.GetMenus(menu);
        StringBuilder sbMenus = new StringBuilder();
       

        //Comienzo a leer solo los nodos padres
        foreach (Menus item in menus.Where(x => x.mnu_nivel == 1).OrderBy(x => x.mnu_orden))
        {
            MenuPerfil menuPerfil = new MenuPerfil();
            menuPerfil.mpe_menu = item.mnu_id;

            if (SitioBase.Token.SecurityManagerPermisoMenu(menuPerfil))
            {
                if (item.mnu_visible)
                {
                    sbMenus.AppendLine("<li class='menu-title'>");
                    sbMenus.AppendLine(item.mnu_nombre);
                    sbMenus.AppendLine("</li>");

                    int countNivel = 1;
                    sbMenus.AppendLine(addMenu(menus, item.mnu_id, countNivel).ToString());
                }
            }
        }

        LiteralControl lc = new LiteralControl();
        lc.Text = sbMenus.ToString();
        phdMenus.Controls.Add(lc);
    }

    protected StringBuilder addMenu(List<Menus> menus, int padre, int countNivel)
    {
        StringBuilder sb = new StringBuilder();

        foreach (Menus item in menus.Where(x => x.mnu_padre == padre).OrderBy(x => x.mnu_orden))
        {
            MenuPerfil menuPerfil = new MenuPerfil();
            menuPerfil.mpe_menu = item.mnu_id;

            if (SitioBase.Token.SecurityManagerPermisoMenu(menuPerfil))
            {
                if (item.mnu_visible)
                {
                    if (item.mnu_link == "#")
                    {
                        sb.AppendLine("<li>");
                        sb.AppendLine(" <a href='javascript: void(0);'>");
                        sb.AppendLine("     <i class='" + item.mnu_icon +"'></i>");
                        sb.AppendLine("     <span>" + item.mnu_nombre + "</span>");
                        sb.AppendLine("     <span class='menu-arrow'></span>");
                        sb.AppendLine(" </a>");

                        sb.AppendLine(" <ul class='nav-second-level' aria-expanded='false'>");
                        sb.AppendLine(addMenu(menus, item.mnu_id, 0).ToString());
                        sb.AppendLine(" </ul>");

                        sb.AppendLine("</li>");
                    }
                    else 
                    {
                        sb.AppendLine("<li>");
                        sb.AppendLine(" <a href='" + ResolveUrl(item.mnu_link) + "'>");

                        if (countNivel == 0)
                        {
                            sb.AppendLine(item.mnu_nombre);
                        }
                        else
                        {
                            sb.AppendLine("     <i class='" + item.mnu_icon + "'></i>");
                            sb.AppendLine("     <span>" + item.mnu_nombre + "</span>");
                        }
                        sb.AppendLine(" </a>");

                        sb.AppendLine(addMenu(menus, item.mnu_id, 1).ToString());

                        sb.AppendLine("</li>");
                    }
                }
            }

        }

        return sb;
    }

}