using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>Un atributo del tipo del activo con su valor y unidad (por activo).</summary>
    [Serializable]
    public class ActivoAtributoValor
    {
        public int ate_id { get; set; }
        public string ate_codigo { get; set; }
        public string ate_nombre { get; set; }
        public int ate_tipo_dato { get; set; }
        public int unidad_id { get; set; }           // unidad elegida en el activo (0 = ninguna)
        public string unidad { get; set; }           // "Kilogramo (kg)"
        public string unidad_simbolo { get; set; }   // "kg"
        public string valor_edit { get; set; }       // para el input (80)
        public string valor_mostrar { get; set; }    // para la ficha (80 kg)
    }

    /// <summary>
    /// Valores de los atributos de un activo (Activo_Atributo). Los CAMPOS vienen
    /// del tipo (nombre + tipo de dato); el VALOR y la UNIDAD se eligen por activo.
    /// </summary>
    public class ActivoAtributoController
    {
        public List<ActivoAtributoValor> GetValores(int activo, int cliente)
        {
            List<ActivoAtributoValor> lista = new List<ActivoAtributoValor>();
            if (activo <= 0) return lista;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_ACTIVO_ATRIBUTO";
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoAtributoValor a = new ActivoAtributoValor();
                            a.ate_id = int.Parse(dr["ATE_ID"].ToString());
                            a.ate_codigo = dr["ATE_CODIGO"].ToString();
                            a.ate_nombre = dr["ATE_NOMBRE"].ToString();
                            a.ate_tipo_dato = int.Parse(dr["ATE_TIPO_DATO"].ToString());
                            a.unidad_id = dr["UNIDAD_ID"] != DBNull.Value ? int.Parse(dr["UNIDAD_ID"].ToString()) : 0;
                            a.unidad = dr["UNIDAD"].ToString();
                            a.unidad_simbolo = dr["UNIDAD_SIMBOLO"].ToString();

                            a.valor_edit = ValorEdit(a.ate_tipo_dato, dr);
                            a.valor_mostrar = "";
                            if (!string.IsNullOrEmpty(a.valor_edit))
                            {
                                string v = a.ate_tipo_dato == 4
                                    ? (dr["VALOR_BIT"] != DBNull.Value && Convert.ToBoolean(dr["VALOR_BIT"]) ? "Sí" : "No")
                                    : a.valor_edit;
                                a.valor_mostrar = v + (!string.IsNullOrEmpty(a.unidad_simbolo) && a.ate_tipo_dato != 4 ? " " + a.unidad_simbolo : "");
                            }
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

        private string ValorEdit(int tipoDato, SqlDataReader dr)
        {
            switch (tipoDato)
            {
                case 1:
                    return dr["VALOR_TEXTO"] != DBNull.Value ? dr["VALOR_TEXTO"].ToString() : "";
                case 2:
                    return dr["VALOR_NUMERO"] != DBNull.Value
                        ? ((decimal)dr["VALOR_NUMERO"]).ToString("0", CultureInfo.InvariantCulture) : "";
                case 3:
                    return dr["VALOR_NUMERO"] != DBNull.Value
                        ? ((decimal)dr["VALOR_NUMERO"]).ToString("0.####", CultureInfo.InvariantCulture) : "";
                case 4:
                    return dr["VALOR_BIT"] != DBNull.Value ? (Convert.ToBoolean(dr["VALOR_BIT"]) ? "Sí" : "No") : "";
                default:
                    return dr["VALOR_FECHA"] != DBNull.Value ? Convert.ToDateTime(dr["VALOR_FECHA"]).ToString("dd-MM-yyyy") : "";
            }
        }

        /// <summary>
        /// Graba un dato del activo. Si @atributo=0, busca-o-crea el atributo del
        /// tipo por @nombre (two-way: aparece también en Atributos técnicos).
        /// Vacío = quita el valor.
        /// </summary>
        public bool GrabarDato(int activo, int atributo, string nombre, int unidad, string valor)
        {
            bool ok = false;
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("GRABAR_DATO_ACTIVO");
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@ATRIBUTO", atributo > 0 ? (object)atributo : DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", (object)(nombre ?? "") ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@UNIDAD", unidad > 0 ? (object)unidad : DBNull.Value);
                    cmd.Parameters.AddWithValue("@VALOR", (object)(valor ?? "") ?? DBNull.Value);
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

        /// <summary>Graba (upsert) el valor + unidad de un atributo para un activo. Vacío = lo borra.</summary>
        public bool Grabar(int activo, int atributo, string valor, int unidad)
        {
            bool ok = false;
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("GRABAR_ACTIVO_ATRIBUTO");
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@ATRIBUTO", atributo);
                    cmd.Parameters.AddWithValue("@VALOR", (object)(valor ?? "") ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@UNIDAD", unidad > 0 ? (object)unidad : DBNull.Value);
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
