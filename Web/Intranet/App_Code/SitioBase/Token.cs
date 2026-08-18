using System;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase.Model;

namespace SitioBase
{
    public class Token
    {
        public static bool TokenSeguridad()
        {
            bool token = true;

            //Valida que exista session
            if (string.IsNullOrEmpty(Session.UsuarioId()))
                token = false;

            return token;
        }

        public static bool SecurityManager(MenuFuncion menuFuncion)
        {
            bool permiso = false;

            if (!string.IsNullOrEmpty(Session.UsuarioId()))
            {
                if (!string.IsNullOrEmpty(Session.UsuarioPerfil()))
                {
                    string[] perfiles = Session.UsuarioPerfil().Split(',');

                    if (!perfiles.Contains(Convert.ToInt32(SitioBase.Perfil.root).ToString()))
                    {
                        string perfil = Session.UsuarioPerfil();

                        SqlCommand cmd = new SqlCommand();
                        cmd.CommandText = "SEGURIDAD_SEL_MENUS_PERMISO";
                        cmd.Parameters.AddWithValue("@FUNNCIONALIDA", menuFuncion.mfu_id);
                        cmd.Parameters.AddWithValue("@PERFIL", perfil);

                        using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                        {
                            while (dr.Read())
                            {
                                permiso = bool.Parse(dr["MFP_HABILITADO"].ToString());
                                if (permiso)
                                    break;
                            }
                        }
                    }
                    else
                    {
                        permiso = true;
                    }
                }
            }
            return permiso;
        }

        public static void SecurityManagerVer(MenuPerfil menuPerfil)
        {
            if (TokenSeguridad())
            {
                bool permiso = false;

                if (!string.IsNullOrEmpty(Session.UsuarioId()))
                {
                    string[] perfiles = Session.UsuarioPerfil().Split(',');

                    if (!perfiles.Contains(Convert.ToInt32(SitioBase.Perfil.root).ToString()))
                    {
                        string perfil = Session.UsuarioPerfil();

                        SqlCommand cmd = new SqlCommand();
                        cmd.CommandText = "SEGURIDAD_SEL_MENUS_PERMISO";
                        cmd.Parameters.AddWithValue("@PERFIL", perfil);
                        cmd.Parameters.AddWithValue("@MENU", menuPerfil.mpe_menu);

                        using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                        {
                            while (dr.Read())
                            {
                                permiso = bool.Parse(dr["MPE_HABILITADO"].ToString());
                                if (permiso)
                                    break;

                            }
                        }
                    }
                    else
                    {
                        permiso = true;
                    }
                }

                if (!permiso)
                {
                    HttpContext.Current.Response.Redirect("~/Default.aspx");
                }
            }
        }

        public static bool SecurityManagerPermisoMenu(MenuPerfil menuPerfil)
        {
            bool permiso = false;

            if (TokenSeguridad())
            {
                if (!string.IsNullOrEmpty(Session.UsuarioId()))
                {
                    string[] perfiles = Session.UsuarioPerfil().Split(',');

                    if (!perfiles.Contains(Convert.ToInt32(SitioBase.Perfil.root).ToString()))
                    {
                        string perfil = Session.UsuarioPerfil();

                        SqlCommand cmd = new SqlCommand();
                        cmd.CommandText = "SEGURIDAD_SEL_MENUS_PERMISO";
                        if (!string.IsNullOrEmpty(perfil)) cmd.Parameters.AddWithValue("@PERFIL", perfil); //perfil.Substring(0, perfil.Length - 2));
                        cmd.Parameters.AddWithValue("@MENU", menuPerfil.mpe_menu);

                        using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                        {
                            while (dr.Read())
                            {
                                permiso = bool.Parse(dr["MPE_HABILITADO"].ToString());

                                if (permiso)
                                    break;
                            }
                        }
                    }
                    else
                    {
                        permiso = true;
                    }
                }
            }
            return permiso;
        }
    }
}