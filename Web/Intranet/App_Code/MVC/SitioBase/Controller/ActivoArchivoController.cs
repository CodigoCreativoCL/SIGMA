using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>Un documento adjunto de un activo (PDF, manual, plano…).</summary>
    [Serializable]
    public class ActivoArchivo
    {
        public int arc_id { get; set; }
        public string arc_nombre { get; set; }
        public string arc_mime { get; set; }
        public long arc_byte { get; set; }
        public bool es_imagen { get; set; }
    }

    /// <summary>
    /// Documentos opcionales de un activo (PDF, manuales, planos…). Reutiliza el
    /// sistema Archivo (Azure) y los enlaza por Archivo_Vinculo (avi_activo con
    /// avi_es_referencia = 0, para no mezclarse con la imagen del activo). Un
    /// activo puede tener VARIOS.
    /// </summary>
    public class ActivoArchivoController
    {
        public List<ActivoArchivo> GetArchivos(int activo, int cliente)
        {
            List<ActivoArchivo> lista = new List<ActivoArchivo>();
            if (activo <= 0) return lista;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_ACTIVO_ARCHIVO";
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoArchivo a = new ActivoArchivo();
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

        /// <summary>Enlaza un Archivo ya subido como documento del activo.</summary>
        public int Vincular(int activo, int archivo)
        {
            int id = -1;
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int salida = 0;
                    cmd = Conexion.GetCommand("VIN_ACTIVO_ARCHIVO");
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

        /// <summary>Quita (baja lógica) un documento del activo.</summary>
        public bool Desvincular(int activo, int archivo)
        {
            bool ok = false;
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_ACTIVO_ARCHIVO");
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
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
