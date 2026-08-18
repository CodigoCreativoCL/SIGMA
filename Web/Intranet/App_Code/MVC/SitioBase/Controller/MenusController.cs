using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class MenusController
    {
        public List<Menus> GetMenus(Menus menu = null)
        {
            List<Menus> menus = new List<Menus>();

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_MENUS";
                //if (menu.mnu_tipo > 0) cmd.Parameters.AddWithValue("@TIPO", menu.mnu_tipo);
                //if (menu.mnu_nivel > 0) cmd.Parameters.AddWithValue("@NIVEL", menu.mnu_nivel);
                //if (menu.mnu_padre > 0) cmd.Parameters.AddWithValue("@PADRE", menu.mnu_padre);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        menu = new Menus();

                        menu.mnu_id = int.Parse(dr["MNU_ID"].ToString());
                        menu.mnu_nombre = dr["MNU_NOMBRE"].ToString();
                        menu.mnu_descripcion = dr["MNU_DESCRIPCION"].ToString();
                        menu.mnu_nivel = int.Parse(dr["MNU_NIVEL"].ToString());
                        menu.mnu_padre = int.Parse(dr["MNU_PADRE"].ToString());
                        menu.mnu_orden = int.Parse(dr["MNU_ORDEN"].ToString());
                        menu.mnu_link = dr["MNU_LINK"].ToString();
                        menu.mnu_visible = bool.Parse(dr["MNU_VISIBLE"].ToString());
                        if(dr["MNU_ICON"].ToString() != null) menu.mnu_icon = dr["MNU_ICON"].ToString();
                        menus.Add(menu);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return menus;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return menus;
            }
        }

        // Misma logica de GetMenus + SecurityManagerPermisoMenu (nivel 1 y 2)
        // que View_Comun_Controls_MenusLateral, para los accesos directos del Dashboard.
        public List<MenuAccesoDirecto> GetMenusAccesibles()
        {
            List<MenuAccesoDirecto> accesos = new List<MenuAccesoDirecto>();

            List<Menus> menus = GetMenus();

            foreach (Menus seccion in menus.Where(x => x.mnu_nivel == 1).OrderBy(x => x.mnu_orden))
            {
                MenuPerfil permisoSeccion = new MenuPerfil();
                permisoSeccion.mpe_menu = seccion.mnu_id;

                if (!seccion.mnu_visible || !Token.SecurityManagerPermisoMenu(permisoSeccion))
                    continue;

                foreach (Menus modulo in menus.Where(x => x.mnu_padre == seccion.mnu_id).OrderBy(x => x.mnu_orden))
                {
                    MenuPerfil permisoModulo = new MenuPerfil();
                    permisoModulo.mpe_menu = modulo.mnu_id;

                    if (!modulo.mnu_visible || !Token.SecurityManagerPermisoMenu(permisoModulo))
                        continue;

                    string link = modulo.mnu_link == "#" ? PrimerLinkDisponible(menus, modulo.mnu_id) : modulo.mnu_link;

                    if (string.IsNullOrEmpty(link) || link == "#")
                        continue;

                    accesos.Add(new MenuAccesoDirecto
                    {
                        mnu_id = modulo.mnu_id,
                        mnu_nombre = modulo.mnu_nombre,
                        mnu_icon = string.IsNullOrEmpty(modulo.mnu_icon) ? "mdi mdi-view-grid-outline" : modulo.mnu_icon,
                        mnu_link = link,
                        mnu_seccion = seccion.mnu_nombre
                    });
                }
            }

            return accesos;
        }

        // Para modulos desplegables (mnu_link == "#"), resuelve el primer link
        // real al que el usuario tenga permiso entre sus hijos (recursivo).
        private string PrimerLinkDisponible(List<Menus> menus, int padre)
        {
            foreach (Menus item in menus.Where(x => x.mnu_padre == padre && x.mnu_visible).OrderBy(x => x.mnu_orden))
            {
                MenuPerfil permiso = new MenuPerfil();
                permiso.mpe_menu = item.mnu_id;

                if (!Token.SecurityManagerPermisoMenu(permiso))
                    continue;

                if (item.mnu_link != "#" && !string.IsNullOrEmpty(item.mnu_link))
                    return item.mnu_link;

                string link = PrimerLinkDisponible(menus, item.mnu_id);
                if (!string.IsNullOrEmpty(link))
                    return link;
            }

            return null;
        }

    }
}