using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// "¿Qué hay acá?" — la pregunta que contesta escanear una etiqueta.
    ///
    /// POR QUE ES UN CONTROLADOR APARTE Y NO METODOS EN InventarioController
    ///   Ese contesta "cuánto hay de este repuesto" y "qué movimientos hubo":
    ///   preguntas que parten del ARTICULO y devuelven una lista. Esta parte
    ///   del LUGAR y devuelve una cabecera MAS un detalle. Mezclarlas
    ///   obligaría a que el controlador de inventario devolviera dos formas
    ///   distintas según el método.
    ///
    /// LOS TRES SP DEVUELVEN LA MISMA FORMA
    ///   Cabecera y detalle en una sola llamada, y el detalle con las mismas
    ///   columnas para bodega, estante y repuesto. Por eso hay UN solo lector
    ///   de líneas: si cada origen trajera su propio juego de columnas, la
    ///   pantalla necesitaría tres maneras de dibujar lo mismo.
    ///
    /// UNA LLAMADA Y NO DOS
    ///   Se recorren con NextResult(). Pedir cabecera y detalle por separado
    ///   abriría dos conexiones para una sola pregunta, y entre una y otra el
    ///   saldo puede cambiar: la cabecera dejaría de corresponder al detalle.
    /// </summary>
    public class DesgloseController
    {
        public DesgloseCabecera Cabecera { get; set; }
        public List<DesgloseLinea> Lineas { get; set; }

        public DesgloseController()
        {
            Lineas = new List<DesgloseLinea>();
        }

        /// <summary>Lo que hay en un estante.</summary>
        public bool CargarUbicacion(int ubicacion)
        {
            return Cargar("SEL_UBICACION_DESGLOSE", "@UBICACION", ubicacion, "UBI");
        }

        /// <summary>Lo que hay en una bodega, estante por estante.</summary>
        public bool CargarBodega(int bodega)
        {
            return Cargar("SEL_BODEGA_DESGLOSE", "@BODEGA", bodega, "BOD");
        }

        /// <summary>Dónde está repartido un repuesto.</summary>
        public bool CargarRepuesto(int repuesto)
        {
            return Cargar("SEL_REPUESTO_DESGLOSE", "@REPUESTO", repuesto, "REP");
        }

        private bool Cargar(string procedimiento, string parametro, int id, string tipo)
        {
            if (!Token.TokenSeguridad()) return false;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = procedimiento;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue(parametro, id);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read()) Cabecera = LeerCabecera(dr, tipo);

                    if (Cabecera == null) return false;

                    if (dr.NextResult())
                    {
                        while (dr.Read()) Lineas.Add(LeerLinea(dr));
                    }
                }

                return true;
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                return false;
            }
        }

        private DesgloseCabecera LeerCabecera(SqlDataReader dr, string tipo)
        {
            DesgloseCabecera c = new DesgloseCabecera();

            if (tipo == "UBI")
            {
                c.Id = int.Parse(dr["bub_id"].ToString());
                c.Tipo = "Ubicación";
                c.Codigo = dr["bub_codigo"].ToString();
                c.Nombre = dr["bub_nombre"].ToString();
                c.Habilitado = bool.Parse(dr["bub_habilitado"].ToString());
                c.Contexto = dr["bod_codigo"].ToString() + " · " + dr["bod_nombre"].ToString();
            }
            else if (tipo == "BOD")
            {
                c.Id = int.Parse(dr["bod_id"].ToString());
                c.Tipo = "Bodega";
                c.Codigo = dr["bod_codigo"].ToString();
                c.Nombre = dr["bod_nombre"].ToString();
                c.Habilitado = bool.Parse(dr["bod_habilitado"].ToString());
                c.Contexto = dr["PLANTA"].ToString();
            }
            else
            {
                c.Id = int.Parse(dr["rep_id"].ToString());
                c.Tipo = "Repuesto";
                c.Codigo = dr["rep_codigo"].ToString();
                c.Nombre = dr["rep_nombre"].ToString();
                c.Habilitado = bool.Parse(dr["rep_habilitado"].ToString());
                c.Contexto = (dr["rep_fabricante"].ToString() + " " +
                              dr["rep_modelo"].ToString()).Trim();
                c.Total = decimal.Parse(dr["TOTAL"].ToString());
                c.Unidad = dr["UNIDAD"].ToString();
                c.ControlaLote = bool.Parse(dr["rep_controla_lote"].ToString());
            }

            return c;
        }

        private DesgloseLinea LeerLinea(SqlDataReader dr)
        {
            DesgloseLinea l = new DesgloseLinea();

            l.RepuestoId = int.Parse(dr["rep_id"].ToString());
            l.RepuestoCodigo = dr["rep_codigo"].ToString();
            l.RepuestoNombre = dr["rep_nombre"].ToString();
            l.Fabricante = dr["rep_fabricante"].ToString();
            l.Modelo = dr["rep_modelo"].ToString();
            l.Unidad = dr["UNIDAD"].ToString();
            l.Cantidad = decimal.Parse(dr["CANTIDAD"].ToString());

            l.Bodega = dr["BODEGA"].ToString();
            l.Ubicacion = dr["UBICACION"].ToString();
            l.UbicacionNombre = dr["UBICACION_NOMBRE"].ToString();
            l.LoteCodigo = dr["LOTE_CODIGO"].ToString();
            l.UltimoUsuario = dr["ULTIMO_USUARIO"].ToString();

            if (dr["COSTO_PROMEDIO"] != DBNull.Value)
                l.CostoPromedio = decimal.Parse(dr["COSTO_PROMEDIO"].ToString());

            if (dr["ULTIMO_MOVIMIENTO"] != DBNull.Value)
                l.UltimoMovimiento = DateTime.Parse(dr["ULTIMO_MOVIMIENTO"].ToString());

            if (dr["LOTE_VENCE"] != DBNull.Value)
                l.LoteVence = DateTime.Parse(dr["LOTE_VENCE"].ToString());

            if (dr["DIAS_PARA_VENCER"] != DBNull.Value)
                l.DiasParaVencer = int.Parse(dr["DIAS_PARA_VENCER"].ToString());

            return l;
        }
    }
}
