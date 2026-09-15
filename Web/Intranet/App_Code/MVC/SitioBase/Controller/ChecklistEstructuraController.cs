using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Estructura interna de una pauta (HU-090+): secciones y campos/items con
    /// su tipo, unidad y rangos, sobre la VERSIÓN BORRADOR de la plantilla. El
    /// guardado es por REEMPLAZO: se limpia el borrador y se re-inserta lo que
    /// mandó la ficha (simple y correcto: nada publicado depende del borrador).
    /// </summary>
    public class ChecklistEstructuraController
    {
        // Tipos numéricos (Checklist_Item_Tipo): ENTERO=3, DECIMAL=4. En estos
        // el editor muestra unidad y rangos.
        public const int TIPO_ENTERO = 3;
        public const int TIPO_DECIMAL = 4;

        /// <summary>Tipos de campo que ofrece el editor (subconjunto útil del catálogo).</summary>
        public List<ChecklistItemTipo> GetItemTipos()
        {
            List<ChecklistItemTipo> lista = new List<ChecklistItemTipo>();
            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_CHECKLIST_ITEM_TIPO";
                cmd.Parameters.AddWithValue("@HABILITADO", true);
                // Orden de aparición pensado para el caso de uso (Sí/No y números primero).
                HashSet<int> permitidos = new HashSet<int> { 5, 4, 3, 2, 1 };
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        int id = int.Parse(dr["CIT_ID"].ToString());
                        if (!permitidos.Contains(id)) continue;
                        lista.Add(new ChecklistItemTipo
                        {
                            cit_id = id,
                            cit_codigo = dr["CIT_CODIGO"].ToString(),
                            cit_nombre = dr["CIT_NOMBRE"].ToString()
                        });
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
            // Reordena: Sí/No, Decimal, Entero, Texto largo, Texto corto.
            lista.Sort((a, b) => Peso(a.cit_id).CompareTo(Peso(b.cit_id)));
            return lista;
        }

        private int Peso(int id)
        {
            switch (id) { case 5: return 1; case 4: return 2; case 3: return 3; case 2: return 4; case 1: return 5; default: return 9; }
        }

        /// <summary>
        /// Id de la versión BORRADOR de la plantilla. Con crear=true la crea si
        /// no existe (al guardar); con crear=false devuelve 0 si no hay (al abrir,
        /// para no dejar un borrador vacío que impida dar de baja la pauta).
        /// </summary>
        public int GetBorradorVersion(int plantilla, string usuario, bool crear = true)
        {
            int version = 0;
            if (!Token.TokenSeguridad()) return 0;
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("GET_CHECKLIST_BORRADOR");
                cmd.Parameters.AddWithValue("@PLANTILLA", plantilla);
                cmd.Parameters.AddWithValue("@USUARIO", usuario);
                cmd.Parameters.AddWithValue("@CREAR", crear);
                SqlParameter pv = cmd.Parameters.AddWithValue("@VERSION", 0);
                pv.Direction = ParameterDirection.Output;
                cmd.ExecuteNonQuery();
                if (pv.Value != DBNull.Value) version = (int)pv.Value;
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
            return version;
        }

        public List<ChecklistSeccion> GetSecciones(int version)
        {
            List<ChecklistSeccion> lista = new List<ChecklistSeccion>();
            if (version <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_CHECKLIST_SECCION";
                cmd.Parameters.AddWithValue("@VERSION", version);
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ChecklistSeccion s = new ChecklistSeccion();
                        s.cps_id = int.Parse(dr["CPS_ID"].ToString());
                        s.sid = "s" + s.cps_id;
                        s.cps_nombre = dr["CPS_NOMBRE"].ToString();
                        s.cps_orden = int.Parse(dr["CPS_ORDEN"].ToString());
                        lista.Add(s);
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
            return lista;
        }

        public List<ChecklistItem> GetItems(int version)
        {
            List<ChecklistItem> lista = new List<ChecklistItem>();
            if (version <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_CHECKLIST_ITEM";
                cmd.Parameters.AddWithValue("@VERSION", version);
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ChecklistItem i = new ChecklistItem();
                        i.cpi_id = int.Parse(dr["CPI_ID"].ToString());
                        i.seccion_sid = dr["CPI_SECCION"] != DBNull.Value ? "s" + dr["CPI_SECCION"].ToString() : "";
                        i.cpi_texto = dr["CPI_TEXTO"].ToString();
                        i.cpi_tipo = int.Parse(dr["CPI_TIPO"].ToString());
                        i.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                        i.cpi_orden = int.Parse(dr["CPI_ORDEN"].ToString());
                        i.cpi_obligatorio = bool.Parse(dr["CPI_OBLIGATORIO"].ToString());
                        if (dr["CPI_UNIDAD"] != DBNull.Value) i.cpi_unidad = int.Parse(dr["CPI_UNIDAD"].ToString());
                        i.unidad_simbolo = dr["UNIDAD_SIMBOLO"].ToString();
                        i.rango_min = dr["RANGO_MINIMO"] != DBNull.Value ? ((decimal)dr["RANGO_MINIMO"]).ToString("0.####", CultureInfo.InvariantCulture) : "";
                        i.rango_max = dr["RANGO_MAXIMO"] != DBNull.Value ? ((decimal)dr["RANGO_MAXIMO"]).ToString("0.####", CultureInfo.InvariantCulture) : "";
                        lista.Add(i);
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
            return lista;
        }

        /// <summary>Reemplaza la estructura del borrador con lo que mandó la ficha.</summary>
        public bool GuardarEstructura(int plantilla, List<ChecklistSeccion> secciones)
        {
            if (plantilla <= 0 || !Token.TokenSeguridad()) return false;
            string usuario = Session.UsuarioId();

            int version = GetBorradorVersion(plantilla, usuario);
            if (version <= 0) return false;

            Ejecutar("LIMPIAR_CHECKLIST_BORRADOR", "@VERSION", version);

            int sorden = 1;
            foreach (ChecklistSeccion sec in secciones)
            {
                if (string.IsNullOrEmpty(sec.cps_nombre)) { sorden++; continue; }
                int secId = InsertarSeccion(version, "SEC-" + sorden, sec.cps_nombre, sorden, usuario);
                if (secId <= 0) { sorden++; continue; }

                int iorden = 1;
                foreach (ChecklistItem it in sec.items)
                {
                    if (string.IsNullOrEmpty(it.cpi_texto)) { iorden++; continue; }
                    int itemId = InsertarItem(version, secId, "ITM-" + sorden + "-" + iorden, it.cpi_texto,
                                              it.cpi_tipo, iorden, it.cpi_obligatorio, it.cpi_unidad, usuario);
                    if (itemId > 0 && (it.cpi_tipo == TIPO_ENTERO || it.cpi_tipo == TIPO_DECIMAL))
                        InsertarValidacion(itemId, it.rango_min, it.rango_max, usuario);
                    iorden++;
                }
                sorden++;
            }
            return true;
        }

        private int InsertarSeccion(int version, string codigo, string nombre, int orden, string usuario)
        {
            int id = 0;
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("INS_CHECKLIST_SECCION");
                SqlParameter pid = cmd.Parameters.AddWithValue("@ID", 0); pid.Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@VERSION", version);
                cmd.Parameters.AddWithValue("@CODIGO", codigo);
                cmd.Parameters.AddWithValue("@NOMBRE", nombre);
                cmd.Parameters.AddWithValue("@ORDEN", orden);
                cmd.Parameters.AddWithValue("@USUARIO", usuario);
                cmd.ExecuteNonQuery();
                if (pid.Value != DBNull.Value) id = (int)pid.Value;
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
            return id;
        }

        private int InsertarItem(int version, int seccion, string codigo, string texto, int tipo,
                                 int orden, bool obligatorio, int? unidad, string usuario)
        {
            int id = 0;
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("INS_CHECKLIST_ITEM");
                SqlParameter pid = cmd.Parameters.AddWithValue("@ID", 0); pid.Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@VERSION", version);
                cmd.Parameters.AddWithValue("@SECCION", seccion);
                cmd.Parameters.AddWithValue("@CODIGO", codigo);
                cmd.Parameters.AddWithValue("@TEXTO", texto);
                cmd.Parameters.AddWithValue("@TIPO", tipo);
                cmd.Parameters.AddWithValue("@ORDEN", orden);
                cmd.Parameters.AddWithValue("@OBLIGATORIO", obligatorio);
                cmd.Parameters.AddWithValue("@UNIDAD", (object)unidad ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", usuario);
                cmd.ExecuteNonQuery();
                if (pid.Value != DBNull.Value) id = (int)pid.Value;
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
            return id;
        }

        private void InsertarValidacion(int item, string min, string max, string usuario)
        {
            object vmin = ParseDecimal(min), vmax = ParseDecimal(max);
            if (vmin == null && vmax == null) return;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("INS_CHECKLIST_VALIDACION");
                cmd.Parameters.AddWithValue("@ITEM", item);
                cmd.Parameters.AddWithValue("@MINIMO", vmin ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@MAXIMO", vmax ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", usuario);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
        }

        private object ParseDecimal(string s)
        {
            if (string.IsNullOrEmpty(s)) return null;
            decimal d;
            if (decimal.TryParse(s.Replace(',', '.'), NumberStyles.Any, CultureInfo.InvariantCulture, out d)) return d;
            return null;
        }

        private void Ejecutar(string sp, string param, object valor)
        {
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand(sp);
                cmd.Parameters.AddWithValue(param, valor);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
        }
    }
}
