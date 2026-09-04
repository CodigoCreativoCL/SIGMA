using System;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>
    /// Imagen de referencia de un activo. No vive en la tabla Activo: se guarda
    /// en Archivo y se enlaza por Archivo_Vinculo (avi_activo + avi_es_referencia).
    /// Este controller solo resuelve el id del Archivo para pintarlo con
    /// UrlArchivo.Ver, y enlaza uno ya subido como la imagen del activo.
    /// </summary>
    public class ActivoImagenController
    {
        /// <summary>Id del Archivo de la imagen vigente del activo, o 0 si no tiene.</summary>
        public int GetImagenId(int activo, int cliente)
        {
            int idArchivo = 0;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_ACTIVO_IMAGEN";
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
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
            }

            return idArchivo;
        }

        /// <summary>
        /// Enlaza un Archivo ya subido como LA imagen del activo (deja una sola
        /// vigente). Devuelve el id del vínculo, o -1 si falla.
        /// </summary>
        public int VincularImagen(int activo, int archivo)
        {
            int id = -1;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int salida = 0;
                    cmd = Conexion.GetCommand("VIN_ACTIVO_IMAGEN");
                    cmd.Parameters.AddWithValue("@ID", salida).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
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
            }

            return id;
        }

        /// <summary>Quita (baja lógica) la imagen vigente del activo.</summary>
        public bool DesvincularImagen(int activo)
        {
            bool ok = false;
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_ACTIVO_IMAGEN");
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    ok = true;
                }
                catch (Exception)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    ok = false;
                }
            }
            return ok;
        }
    }
}
