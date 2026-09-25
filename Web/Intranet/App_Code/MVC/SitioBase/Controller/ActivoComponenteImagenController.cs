using System;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>
    /// La imagen de un componente (bloque 274).
    ///
    /// Es el mismo trato que el activo -una sola vigente, la anterior se apaga
    /// y el archivo se queda-, apuntando a avi_activo_componente. Se separa en
    /// su propio controlador y no se le agrega un parametro al del activo
    /// porque son dos cosas distintas con dos permisos distintos.
    ///
    /// Los bytes nunca pasan por aqui: el archivo vive en Blob Storage y la
    /// pantalla lo pide por VerArchivo.aspx con el id cifrado.
    /// </summary>
    public class ActivoComponenteImagenController
    {
        /// <summary>Id del Archivo de la imagen vigente del componente, o 0.</summary>
        public int GetImagenId(int componente, int cliente)
        {
            int idArchivo = 0;

            if (componente <= 0 || !Token.TokenSeguridad()) return 0;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ACTIVO_COMPONENTE_IMAGEN";
                cmd.Parameters.AddWithValue("@COMPONENTE", componente);
                cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read() && dr["ARC_ID"] != DBNull.Value)
                        idArchivo = int.Parse(dr["ARC_ID"].ToString());
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                idArchivo = 0;
            }

            return idArchivo;
        }

        /// <summary>Deja un Archivo ya subido como LA imagen del componente.</summary>
        public int VincularImagen(int componente, int archivo)
        {
            int id = -1;

            if (!Token.TokenSeguridad()) return id;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("VIN_ACTIVO_COMPONENTE_IMAGEN");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@COMPONENTE", componente);
                cmd.Parameters.AddWithValue("@ARCHIVO", archivo);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                id = (int)cmd.Parameters["@ID"].Value;
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                id = -1;
            }

            return id;
        }

        /// <summary>Quita la imagen vigente. El archivo se queda donde esta.</summary>
        public bool DesvincularImagen(int componente)
        {
            if (!Token.TokenSeguridad()) return false;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("DEL_ACTIVO_COMPONENTE_IMAGEN");
                cmd.Parameters.AddWithValue("@COMPONENTE", componente);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
                return true;
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                return false;
            }
        }
    }
}
