using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>Un elemento del diagrama de estructura: subactivo, componente o repuesto.</summary>
    public class ActivoEstructuraItem
    {
        public int id { get; set; }
        public int padre { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
        public string tipo { get; set; }
        public string detalle { get; set; }
        public string estado { get; set; }
        public string estado_codigo { get; set; }
        public int componentes { get; set; }
        public int subactivos { get; set; }
        public decimal existencia { get; set; }
        public decimal minimo { get; set; }
        public string unidad { get; set; }
    }

    /// <summary>Todo lo que cuelga de un activo (bloque 343).</summary>
    public class ActivoEstructura
    {
        public ActivoEstructuraItem principal { get; set; }
        public List<ActivoEstructuraItem> subactivos = new List<ActivoEstructuraItem>();
        public List<ActivoEstructuraItem> componentes = new List<ActivoEstructuraItem>();
        public List<ActivoEstructuraItem> repuestos = new List<ActivoEstructuraItem>();
    }

    /// <summary>Padre, contadores y area completa de una fila del listado (bloque 343).</summary>
    public class ActivoArbolFila
    {
        public int id { get; set; }
        public int padre { get; set; }
        public int subactivos { get; set; }
        public int componentes { get; set; }
        public int repuestos { get; set; }
        public string area_ruta { get; set; }
    }

    /// <summary>
    /// La estructura del activo de un vistazo (revisión del cliente, 04-10-2026):
    /// subactivos, componentes y repuestos en UNA lectura, no una por bloque.
    /// El cliente sale de la sesion, nunca de afuera.
    /// </summary>
    public class ActivoEstructuraController
    {
        private static string Txt(SqlDataReader dr, string c) { return dr[c] == DBNull.Value ? "" : dr[c].ToString(); }
        private static int Int(SqlDataReader dr, string c) { return dr[c] == DBNull.Value ? 0 : Convert.ToInt32(dr[c]); }

        public ActivoEstructura GetEstructura(int activo)
        {
            ActivoEstructura e = new ActivoEstructura();
            if (!Token.TokenSeguridad() || activo <= 0) return e;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("SEL_ACTIVO_ESTRUCTURA");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO", activo);
                using (SqlDataReader dr = cmd.ExecuteReader())
                {
                    if (dr.Read())
                        e.principal = new ActivoEstructuraItem { id = Int(dr, "ID"), codigo = Txt(dr, "CODIGO"), nombre = Txt(dr, "NOMBRE") };

                    dr.NextResult();
                    while (dr.Read())
                        e.subactivos.Add(new ActivoEstructuraItem
                        {
                            id = Int(dr, "ID"), codigo = Txt(dr, "CODIGO"), nombre = Txt(dr, "NOMBRE"),
                            estado = Txt(dr, "ESTADO"), estado_codigo = Txt(dr, "ESTADO_CODIGO"),
                            tipo = Txt(dr, "TIPO"), detalle = Txt(dr, "CRITICIDAD"),
                            componentes = Int(dr, "COMPONENTES"), subactivos = Int(dr, "SUBACTIVOS")
                        });

                    dr.NextResult();
                    while (dr.Read())
                        e.componentes.Add(new ActivoEstructuraItem
                        {
                            id = Int(dr, "ID"), padre = Int(dr, "PADRE"), codigo = Txt(dr, "CODIGO"), nombre = Txt(dr, "NOMBRE"),
                            tipo = Txt(dr, "TIPO"), detalle = Txt(dr, "LADO"),
                            estado = Txt(dr, "ESTADO"), estado_codigo = Txt(dr, "ESTADO_CODIGO")
                        });

                    dr.NextResult();
                    while (dr.Read())
                        e.repuestos.Add(new ActivoEstructuraItem
                        {
                            id = Int(dr, "ID"), codigo = Txt(dr, "CODIGO"), nombre = Txt(dr, "NOMBRE"),
                            detalle = Txt(dr, "ALCANCE"), unidad = Txt(dr, "UNIDAD"),
                            existencia = dr["EXISTENCIA"] == DBNull.Value ? 0 : Convert.ToDecimal(dr["EXISTENCIA"]),
                            minimo = dr["MINIMO"] == DBNull.Value ? 0 : Convert.ToDecimal(dr["MINIMO"])
                        });
                }
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                throw;
            }
            return e;
        }

        public Dictionary<int, ActivoArbolFila> GetArbolLista()
        {
            Dictionary<int, ActivoArbolFila> mapa = new Dictionary<int, ActivoArbolFila>();
            if (!Token.TokenSeguridad()) return mapa;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("SEL_ACTIVO_ARBOL_LISTA");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                using (SqlDataReader dr = cmd.ExecuteReader())
                    while (dr.Read())
                    {
                        ActivoArbolFila f = new ActivoArbolFila
                        {
                            id = Int(dr, "ID"), padre = Int(dr, "PADRE"), subactivos = Int(dr, "SUBACTIVOS"),
                            componentes = Int(dr, "COMPONENTES"), repuestos = Int(dr, "REPUESTOS"), area_ruta = Txt(dr, "AREA_RUTA")
                        };
                        mapa[f.id] = f;
                    }
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
            return mapa;
        }
    }
}
