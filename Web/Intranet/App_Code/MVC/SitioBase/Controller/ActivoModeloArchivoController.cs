using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>Un archivo adjunto de un modelo (catálogo, foto de placa…).</summary>
    [Serializable]
    public class ModeloArchivo
    {
        public int arc_id { get; set; }
        public string arc_nombre { get; set; }
        public string arc_mime { get; set; }
        public long arc_byte { get; set; }
        public bool es_imagen { get; set; }
    }

    /// <summary>
    /// Archivos opcionales de un modelo de activo. Reutiliza el sistema Archivo
    /// (Azure) y los enlaza por Archivo_Vinculo (avi_activo_modelo). Un modelo
    /// puede tener VARIOS (catálogo PDF, foto de placa, manual…).
    /// </summary>
    public class ActivoModeloArchivoController
    {
        public List<ModeloArchivo> GetArchivos(int modelo, int cliente)
        {
            List<ModeloArchivo> lista = new List<ModeloArchivo>();
            if (modelo <= 0) return lista;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_ACTIVO_MODELO_ARCHIVO";
                    cmd.Parameters.AddWithValue("@MODELO", modelo);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ModeloArchivo a = new ModeloArchivo();
                            a.arc_id = int.Parse(dr["ARC_ID"].ToString());
                            a.arc_nombre = dr["ARC_NOMBRE"].ToString();
                            a.arc_mime = dr["ARC_MIME"] != DBNull.Value ? dr["ARC_MIME"].ToString() : "";
                            if (dr["ARC_BYTE"] != DBNull.Value) a.arc_byte = long.Parse(dr["ARC_BYTE"].ToString());
                            a.es_imagen = a.arc_mime.StartsWith("image", StringComparison.OrdinalIgnoreCase);
                            lista.Add(a);
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }
            return lista;
        }

        /// <summary>Enlaza un Archivo ya subido como adjunto del modelo.</summary>
        public int Vincular(int modelo, int archivo)
        {
            int id = -1;
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int salida = 0;
                    cmd = Conexion.GetCommand("VIN_ACTIVO_MODELO_ARCHIVO");
                    cmd.Parameters.AddWithValue("@ID", salida).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@MODELO", modelo);
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

        /// <summary>Quita (baja lógica) un archivo del modelo.</summary>
        public bool Desvincular(int modelo, int archivo)
        {
            bool ok = false;
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_ACTIVO_MODELO_ARCHIVO");
                    cmd.Parameters.AddWithValue("@MODELO", modelo);
                    cmd.Parameters.AddWithValue("@ARCHIVO", archivo);
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
