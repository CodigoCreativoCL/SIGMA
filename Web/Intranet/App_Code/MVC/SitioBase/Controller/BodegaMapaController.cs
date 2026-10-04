using SitioBase;
using System;
using System.Data;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Lecturas del mapa 3D de bodegas.
    ///
    /// SOLO LEE
    ///   Lo que el mapa escribe (bodegas, racks, repuestos, movimientos,
    ///   conteos) pasa por WsBodegaMapa a los controllers de siempre, con sus
    ///   validaciones. Aqui solo estan las dos lecturas propias del mapa.
    ///
    /// DOS LECTURAS Y NO UNA
    ///   La estructura (bodegas y ubicaciones) casi no cambia; el stock cambia
    ///   todo el dia. Separadas, el visor puede refrescar el stock despues de
    ///   un movimiento sin volver a construir la escena entera.
    /// </summary>
    public class BodegaMapaController
    {
        public DataTable GetEstructura(int instalacion)
        {
            return Leer("SEL_BODEGA_MAPA_ESTRUCTURA", instalacion);
        }

        public DataTable GetSaldos(int instalacion)
        {
            return Leer("SEL_BODEGA_MAPA_SALDOS", instalacion);
        }

        private DataTable Leer(string sp, int instalacion)
        {
            if (!Token.TokenSeguridad()) return new DataTable();

            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = sp;
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            cmd.Parameters.AddWithValue("@INSTALACION", instalacion > 0 ? (object)instalacion : DBNull.Value);

            return Conexion.GetDataTable(cmd);
        }
    }
}
