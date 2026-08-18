using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class AccesoController
    {
        public List<Menus> GetMenus(Menus menu = null)
        {
            List<Menus> menus = new List<Menus>();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEGURIDAD_SEL_MENUS";
                //if (menu.mnu_tipo > 0) cmd.Parameters.AddWithValue("@TIPO", menu.mnu_tipo);
                if (menu.mnu_nivel > 0) cmd.Parameters.AddWithValue("@NIVEL", menu.mnu_nivel);
                if (menu.mnu_padre > 0) cmd.Parameters.AddWithValue("@PADRE", menu.mnu_padre);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        menu = new Menus();

                        menu.mnu_id = int.Parse(dr["MNU_ID"].ToString());
                        menu.mnu_nombre = dr["MNU_NOMBRE"].ToString();
                        menu.mnu_descripcion = dr["MNU_DESCRIPCION"].ToString();
                        //menu.mnu_tipo = int.Parse(dr["MNU_TIPO"].ToString());
                        menu.mnu_nivel = int.Parse(dr["MNU_NIVEL"].ToString());
                        if (dr["MNU_PADRE"].ToString() != "") menu.mnu_padre = int.Parse(dr["MNU_PADRE"].ToString());
                        menu.mnu_orden = int.Parse(dr["MNU_ORDEN"].ToString());
                        menu.mnu_link = dr["MNU_LINK"].ToString();
                        menu.mnu_visible = bool.Parse(dr["MNU_VISIBLE"].ToString());

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

        public List<Menus> GetMenusAdministracion()
        {
            List<Menus> menus = new List<Menus>();
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "SEGURIDAD_SEL_MENUS";

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    Menus menu = new Menus();

                    menu.mnu_id = Int32.Parse(dr["mnu_id"].ToString());
                    menu.mnu_nombre = dr["mnu_nombre"].ToString();
                    menu.mnu_nivel = Int32.Parse(dr["mnu_nivel"].ToString());
                    menu.mnu_padre = Int32.Parse(dr["mnu_padre"].ToString());
                    menu.mnu_orden = Int32.Parse(dr["mnu_orden"].ToString());
                    menu.mnu_link = dr["mnu_link"].ToString();

                    menus.Add(menu);
                }
            }

            return menus;
        }

        public DataTable GetMenusFuncionesPerfiles(Menus menu)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "SEGURIDAD_SEL_MENUS_PERMISOS";
            cmd.Parameters.AddWithValue("@MENU", menu.mnu_id);

            DataTable dt = new DataTable();
            dt = Conexion.GetDataTable(cmd);

            return dt;
        }

        public List<Menus> GetMenusTools(Menus menu)
        {
            List<Menus> menus = new List<Menus>();

            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "SEGURIDAD_SEL_MENUS";
            cmd.Parameters.AddWithValue("@VISIBLE", menu.mnu_visible);
            //cmd.Parameters.AddWithValue("@TOOLS", menu.mnu_tools);

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    menu = new Menus();

                    menu.mnu_id = Int32.Parse(dr["mnu_id"].ToString());
                    menu.mnu_nombre = dr["mnu_nombre"].ToString();
                    menu.mnu_nivel = Int32.Parse(dr["mnu_nivel"].ToString());
                    menu.mnu_padre = Int32.Parse(dr["mnu_padre"].ToString());
                    menu.mnu_orden = Int32.Parse(dr["mnu_orden"].ToString());
                    menu.mnu_link = dr["mnu_link"].ToString();
                    //menu.mnu_tools = bool.Parse(dr["mnu_tools"].ToString());

                    menus.Add(menu);
                }
            }

            return menus;
        }

        public Menus GetMenuPadre(Menus menu)
        {
            Menus menuPadre = new Menus();

            try
            {
                SqlCommand cmd = new SqlCommand();
                cmd.CommandText = "SEGURIDAD_SEL_MENUS";
                cmd.Parameters.AddWithValue("@PADRE", menu.mnu_padre);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        menuPadre.mnu_id = Int32.Parse(dr["mnu_id"].ToString());
                        menuPadre.mnu_nombre = dr["mnu_nombre"].ToString();
                        menuPadre.mnu_padre = Int32.Parse(dr["mnu_padre"].ToString());
                    }
                }
            }
            catch (Exception ex)
            {
            }

            return menuPadre;
        }

        public Menus GetMenu(Menus menu)
        {
            try
            {
                SqlCommand cmd = new SqlCommand();
                cmd.CommandText = "SEGURIDAD_SEL_MENUS";
                cmd.Parameters.AddWithValue("@ID", menu.mnu_id);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        menu = new Menus();

                        menu.mnu_id = Int32.Parse(dr["mnu_id"].ToString());
                        menu.mnu_nombre = dr["mnu_nombre"].ToString();
                        menu.mnu_padre = Int32.Parse(dr["mnu_padre"].ToString());
                    }
                }
            }
            catch (Exception)
            {
            }

            return menu;
        }

        public Menus GetMenuFuncion(MenuFuncionPerfil menuFuncionPerfil)
        {
            Menus menu = new Menus();

            try
            {
                SqlCommand cmd = new SqlCommand();
                cmd.CommandText = "SEL_FUNCION_MENU";
                cmd.Parameters.AddWithValue("@ID", menuFuncionPerfil.mfp_menu_funcion);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        menu.mnu_id = Int32.Parse(dr["mnu_id"].ToString());
                        menu.mnu_nombre = dr["mnu_nombre"].ToString();
                        menu.mnu_padre = Int32.Parse(dr["mnu_padre"].ToString());
                    }
                }
            }
            catch (Exception ex)
            {
            }

            return menu;
        }

        public Respuesta InsertMenuFuncionPerfil(MenuFuncionPerfil menuFuncionPerfil)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                SqlCommand cmdExecute = Conexion.GetCommand("SEGURIDAD_INS_MENU_FUNCION_PERFIL");
                cmdExecute.Parameters.AddWithValue("@PERFIL", menuFuncionPerfil.mfp_perfil);
                cmdExecute.Parameters.AddWithValue("@FUNCION", menuFuncionPerfil.mfp_menu_funcion);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", menuFuncionPerfil.mfp_habilitado);
                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo = 0;
                respuesta.error = false;

                if (menuFuncionPerfil.mfp_habilitado)
                {
                    Menus menuHijo = new Menus();
                    menuHijo = GetMenuFuncion(menuFuncionPerfil);

                    Menus menuPadre = GetMenuPadre(menuHijo);

                    if ((menuPadre.mnu_id == menuHijo.mnu_padre) & menuPadre.mnu_id > 0)
                    {
                        MenuPerfil menuPerfilPadre = new MenuPerfil();
                        menuPerfilPadre.mpe_menu = menuPadre.mnu_id;
                        menuPerfilPadre.mpe_perfil = menuFuncionPerfil.mfp_perfil;
                        menuPerfilPadre.mpe_habilitado = true;

                        respuesta = InsertMenuPerfilTransaccion(menuPerfilPadre);
                        InsertMenuPerfilPadre(menuPerfilPadre, menuPadre);
                    }
                }
            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta InsertMenuPerfil(MenuPerfil menuPerfil)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                respuesta = InsertMenuPerfilTransaccion(menuPerfil);

                if (menuPerfil.mpe_habilitado)
                {
                    Menus menuHijo = new Menus();
                    menuHijo.mnu_id = menuPerfil.mpe_menu;
                    menuHijo = GetMenu(menuHijo);

                    Menus menuPadre = GetMenuPadre(menuHijo);

                    if ((menuPadre.mnu_id == menuHijo.mnu_padre) & menuPadre.mnu_id > 0)
                    {
                        MenuPerfil menuPerfilPadre = new MenuPerfil();
                        menuPerfilPadre.mpe_menu = menuPadre.mnu_id;
                        menuPerfilPadre.mpe_perfil = menuPerfil.mpe_perfil;
                        menuPerfilPadre.mpe_habilitado = true;

                        respuesta = InsertMenuPerfilTransaccion(menuPerfilPadre);
                        InsertMenuPerfilPadre(menuPerfilPadre, menuPadre);
                    }
                }
            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta InsertMenuPerfilPadre(MenuPerfil menuPerfilHijo, Menus menuHijo)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                Menus menuPadre = GetMenuPadre(menuHijo);

                if ((menuPadre.mnu_id == menuHijo.mnu_padre) & menuPadre.mnu_id > 0)
                {
                    MenuPerfil menuPerfilPadre = new MenuPerfil();
                    menuPerfilPadre.mpe_menu = menuPadre.mnu_id;
                    menuPerfilPadre.mpe_perfil = menuPerfilHijo.mpe_perfil;
                    menuPerfilPadre.mpe_habilitado = true;

                    respuesta = InsertMenuPerfilTransaccion(menuPerfilPadre);
                    InsertMenuPerfilPadre(menuPerfilPadre, menuPadre);
                }
            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta InsertMenuPerfilTransaccion(MenuPerfil menuPerfil)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                SqlCommand cmdExecute = Conexion.GetCommand("SEGURIDAD_INS_MENU_PERFIL");
                cmdExecute.Parameters.AddWithValue("@PERFIL", menuPerfil.mpe_perfil);
                cmdExecute.Parameters.AddWithValue("@MENU", menuPerfil.mpe_menu);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", menuPerfil.mpe_habilitado);
                cmdExecute.Parameters.AddWithValue("@HOST", Session.RemoteHost());
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo = 0;
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }
    }
}