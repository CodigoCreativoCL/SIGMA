using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Mantenedor de menus, funciones y permisos.
    ///
    /// Es la pieza que hace que el modelo cierre: antes no existia ningun
    /// INS/UPD/DEL de Menus ni de Menu_Funcion, asi que publicar una
    /// pagina nueva pasaba por editar Paginas.cs y recompilar. Ahora se
    /// hace por pantalla.
    ///
    /// Cada operacion que toca el arbol llama a Token.RefrescarMapa(): el
    /// mapa URL -> permiso vive en memoria y hay que invalidarlo, o el
    /// cambio no se ve hasta reiniciar el sitio.
    /// </summary>
    public class MantenedorMenusController
    {
        /* ================================================================
           MENUS
           ================================================================ */

        public List<Menus> GetMenus(Menus filtro)
        {
            List<Menus> menus = new List<Menus>();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_MENUS_MANTENEDOR";
                if (filtro != null && filtro.mnu_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.mnu_id);
                if (filtro != null && !string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                        menus.Add(Leer(dr));
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }
            return menus;
        }

        public Menus GetMenu(int id)
        {
            Menus menu = null;
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_MENUS_MANTENEDOR";
                cmd.Parameters.AddWithValue("@ID", id);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read()) menu = Leer(dr);
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }
            return menu;
        }

        private Menus Leer(SqlDataReader dr)
        {
            Menus m = new Menus();
            m.mnu_id = Convert.ToInt32(dr["MNU_ID"]);
            m.mnu_nombre = dr["MNU_NOMBRE"].ToString();
            m.mnu_descripcion = dr["MNU_DESCRIPCION"].ToString();
            m.mnu_nivel = Convert.ToInt32(dr["MNU_NIVEL"]);
            m.mnu_padre = Convert.ToInt32(dr["MNU_PADRE"]);
            m.mnu_orden = Convert.ToInt32(dr["MNU_ORDEN"]);
            m.mnu_link = dr["MNU_LINK"].ToString();
            m.mnu_visible = Convert.ToBoolean(dr["MNU_VISIBLE"]);
            m.mnu_icon = dr["MNU_ICON"].ToString();
            m.mnu_permiso = Convert.ToInt32(dr["MNU_PERMISO"]);
            m.prm_codigo = dr["PRM_CODIGO"].ToString();
            m.padre_nombre = dr["PADRE_NOMBRE"].ToString();
            m.mnu_tipo = dr["MNU_TIPO"].ToString();
            return m;
        }

        public Respuesta InsertMenu(Menus menu)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad()) return respuesta;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("INS_MENUS");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                CargarParametros(cmd, menu);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                respuesta.detalle = "Menú creado con éxito.";
                respuesta.error = false;

                Token.RefrescarMapa();
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

        public Respuesta UpdateMenu(Menus menu)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad()) return respuesta;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("UPD_MENUS");
                cmd.Parameters.AddWithValue("@ID", menu.mnu_id);
                CargarParametros(cmd, menu);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = 0;
                respuesta.detalle = "Menú actualizado con éxito.";
                respuesta.error = false;

                Token.RefrescarMapa();
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

        private void CargarParametros(SqlCommand cmd, Menus menu)
        {
            cmd.Parameters.AddWithValue("@NOMBRE", menu.mnu_nombre);
            cmd.Parameters.AddWithValue("@DESCRIPCION", (object)menu.mnu_descripcion ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@NIVEL", menu.mnu_nivel);
            cmd.Parameters.AddWithValue("@PADRE", menu.mnu_padre);
            cmd.Parameters.AddWithValue("@ORDEN", menu.mnu_orden);
            cmd.Parameters.AddWithValue("@LINK", string.IsNullOrEmpty(menu.mnu_link) ? "#" : menu.mnu_link);
            cmd.Parameters.AddWithValue("@VISIBLE", menu.mnu_visible);
            cmd.Parameters.AddWithValue("@ICON", (object)menu.mnu_icon ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@PERMISO", menu.mnu_permiso > 0 ? (object)menu.mnu_permiso : DBNull.Value);
        }

        public Respuesta DeleteMenu(int id)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad()) return respuesta;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("DEL_MENUS");
                cmd.Parameters.AddWithValue("@ID", id);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = 0;
                respuesta.detalle = "Menú eliminado con éxito.";
                respuesta.error = false;

                Token.RefrescarMapa();
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


        /* ================================================================
           FUNCIONES DE UN MENU
           ================================================================ */

        public List<MenuFuncion> GetFunciones(int menu)
        {
            List<MenuFuncion> funciones = new List<MenuFuncion>();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_MENU_FUNCION";
                if (menu > 0) cmd.Parameters.AddWithValue("@MENU", menu);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        MenuFuncion f = new MenuFuncion();
                        f.mfu_id = Convert.ToInt32(dr["mfu_id"]);
                        f.mfu_nombre = dr["mfu_nombre"].ToString();
                        f.mfu_menu = Convert.ToInt32(dr["mfu_menu"]);
                        f.mnu_nombre = dr["mnu_nombre"].ToString();
                        f.mfu_permiso = dr["mfu_permiso"] == DBNull.Value ? 0 : Convert.ToInt32(dr["mfu_permiso"]);
                        f.prm_codigo = dr["prm_codigo"].ToString();
                        f.prm_nombre = dr["prm_nombre"].ToString();
                        f.prm_modulo = dr["prm_modulo"].ToString();
                        funciones.Add(f);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }
            return funciones;
        }

        public Respuesta InsertFuncion(MenuFuncion funcion)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad()) return respuesta;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("INS_MENU_FUNCION");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@NOMBRE", funcion.mfu_nombre);
                cmd.Parameters.AddWithValue("@MENU", funcion.mfu_menu);
                cmd.Parameters.AddWithValue("@PERMISO", funcion.mfu_permiso);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                respuesta.detalle = "Función creada con éxito.";
                respuesta.error = false;

                Token.RefrescarMapa();
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

        public Respuesta UpdateFuncion(MenuFuncion funcion)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad()) return respuesta;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("UPD_MENU_FUNCION");
                cmd.Parameters.AddWithValue("@ID", funcion.mfu_id);
                cmd.Parameters.AddWithValue("@NOMBRE", funcion.mfu_nombre);
                cmd.Parameters.AddWithValue("@MENU", funcion.mfu_menu);
                cmd.Parameters.AddWithValue("@PERMISO", funcion.mfu_permiso);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = 0;
                respuesta.detalle = "Función actualizada con éxito.";
                respuesta.error = false;

                Token.RefrescarMapa();
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

        public Respuesta DeleteFuncion(int id)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad()) return respuesta;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("DEL_MENU_FUNCION");
                cmd.Parameters.AddWithValue("@ID", id);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = 0;
                respuesta.detalle = "Función eliminada con éxito.";
                respuesta.error = false;

                Token.RefrescarMapa();
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


        /* ================================================================
           CATALOGO DE PERMISOS
           ================================================================ */

        public List<Permiso> GetPermisos(Permiso filtro)
        {
            List<Permiso> permisos = new List<Permiso>();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_PERMISO";
                if (filtro != null && filtro.prm_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.prm_id);
                if (filtro != null && !string.IsNullOrEmpty(filtro.filtro_modulo)) cmd.Parameters.AddWithValue("@MODULO", filtro.filtro_modulo);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        Permiso p = new Permiso();
                        p.prm_id = Convert.ToInt32(dr["prm_id"]);
                        p.prm_codigo = dr["prm_codigo"].ToString();
                        p.prm_nombre = dr["prm_nombre"].ToString();
                        p.prm_modulo = dr["prm_modulo"].ToString();
                        p.prm_permiso_ambito = dr["prm_permiso_ambito"] == DBNull.Value ? 0 : Convert.ToInt32(dr["prm_permiso_ambito"]);
                        p.prm_descripcion = dr["prm_descripcion"].ToString();
                        p.prm_habilitado = Convert.ToBoolean(dr["prm_habilitado"]);
                        p.prm_asignable_usuario = Convert.ToBoolean(dr["prm_asignable_usuario"]);
                        permisos.Add(p);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }
            return permisos;
        }
    }
}
