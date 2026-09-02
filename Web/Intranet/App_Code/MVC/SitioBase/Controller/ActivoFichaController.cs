using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Historial (línea de tiempo) de un activo (HU-037). Lee
    /// SEL_ACTIVO_FICHA, que une los cambios de estado, de posición y las
    /// mediciones, con filtros y paginación. El cliente lo pone la pantalla
    /// desde Session.ClienteId: es la barrera multicliente.
    /// </summary>
    public class ActivoFichaController
    {
        /// <summary>
        /// Devuelve una página del historial. <paramref name="total"/> sale
        /// con el total de eventos que cumplen el filtro, para paginar en la
        /// pantalla.
        /// </summary>
        public List<ActivoFichaEvento> GetHistorial(int activo, int cliente, string tipoEvento,
            DateTime? desde, DateTime? hasta, bool ordenDesc, int pagina, int tamano, out int total)
        {
            List<ActivoFichaEvento> lista = new List<ActivoFichaEvento>();
            total = 0;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("SEL_ACTIVO_FICHA");
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);
                    cmd.Parameters.AddWithValue("@TIPO_EVENTO", string.IsNullOrEmpty(tipoEvento) ? (object)DBNull.Value : tipoEvento);
                    cmd.Parameters.AddWithValue("@FECHA_DESDE", (object)desde ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@FECHA_HASTA", (object)hasta ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ORDEN_DESC", ordenDesc);
                    cmd.Parameters.AddWithValue("@PAGINA", pagina);
                    cmd.Parameters.AddWithValue("@TAMANO", tamano);

                    SqlParameter pTotal = cmd.Parameters.Add("@TOTAL", SqlDbType.Int);
                    pTotal.Direction = ParameterDirection.Output;

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoFichaEvento item = new ActivoFichaEvento();
                            if (dr["FECHA"] != DBNull.Value) item.fecha = DateTime.Parse(dr["FECHA"].ToString());
                            item.tipo_evento = dr["TIPO_EVENTO"].ToString();
                            item.titulo = dr["TITULO"].ToString();
                            item.detalle = dr["DETALLE"].ToString();
                            item.usuario_nombre = dr["USUARIO_NOMBRE"].ToString();
                            lista.Add(item);
                        }
                    }

                    // El parámetro de salida solo tiene valor una vez leído el
                    // resultado y cerrado el reader.
                    if (pTotal.Value != null && pTotal.Value != DBNull.Value)
                        total = (int)pTotal.Value;

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    if (cmd != null) cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }
    }
}
