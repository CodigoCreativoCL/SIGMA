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

        /// <summary>
        /// Otorga o quita una FUNCION a un perfil.
        ///
        /// Escribe en Perfil_Permiso, que es de donde lee Token. Antes
        /// escribia en Menu_Funcion_Perfil, que ya no lee nadie: marcar en
        /// pantalla no tenia ningun efecto.
        ///
        /// Tampoco propaga hacia el menu padre. Ya no hace falta: el menu
        /// lateral muestra un contenedor si alguno de sus hijos se muestra.
        /// </summary>
        public Respuesta InsertMenuFuncionPerfil(MenuFuncionPerfil menuFuncionPerfil)
        {
            return GuardarAsignacion(menuFuncionPerfil.mfp_perfil, 0,
                                     menuFuncionPerfil.mfp_menu_funcion,
                                     menuFuncionPerfil.mfp_habilitado);
        }

        /// <summary>
        /// Otorga o quita el acceso a una PAGINA -- lo que la grilla muestra
        /// como "Ver". Es el permiso apuntado por Menus.mnu_permiso.
        /// </summary>
        private Respuesta GuardarAsignacion(int perfil, int menu, int funcion, bool otorgado)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad()) return respuesta;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("UPS_PERFIL_PERMISO");
                cmd.Parameters.AddWithValue("@PERFIL", perfil);
                cmd.Parameters.AddWithValue("@MENU", menu);
                cmd.Parameters.AddWithValue("@FUNCION", funcion);
                cmd.Parameters.AddWithValue("@OTORGADO", otorgado);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = 0;
                respuesta.detalle = otorgado ? "Permiso otorgado." : "Permiso retirado.";
                respuesta.error = false;

                // El permiso cambio: quien lo reciba tiene que releerlo.
                Token.Refrescar();
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        /// <summary>
        /// Otorga o quita el "Ver" de una pagina a un perfil.
        ///
        /// "Ver" ya no es una fila en Menu_Perfil: es el permiso que la
        /// pagina declara en Menus.mnu_permiso. Otorgarlo es una fila en
        /// Perfil_Permiso, que es lo unico que Token lee.
        /// </summary>
        public Respuesta InsertMenuPerfil(MenuPerfil menuPerfil)
        {
            return GuardarAsignacion(menuPerfil.mpe_perfil, menuPerfil.mpe_menu, 0,
                                     menuPerfil.mpe_habilitado);
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