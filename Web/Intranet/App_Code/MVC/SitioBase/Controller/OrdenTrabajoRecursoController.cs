using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>Un repuesto que la orden pidio, reservo, gasto o devolvio.</summary>
    [Serializable]
    public class OrdenTrabajoRepuesto
    {
        public int ore_id { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
        public string unidad { get; set; }
        public string lote { get; set; }
        public string componente { get; set; }
        public decimal planificada { get; set; }
        public decimal reservada { get; set; }
        public decimal consumida { get; set; }
        public decimal devuelta { get; set; }
        public decimal costo_unitario { get; set; }
        public decimal costo { get; set; }
        public string moneda { get; set; }
        public string observacion { get; set; }
        public string usuario { get; set; }

        /// <summary>Lo que efectivamente salio de bodega.</summary>
        public decimal neto { get { return consumida - devuelta; } }
    }

    /// <summary>Una linea de trabajo: quien, cuanto rato y a que costo.</summary>
    [Serializable]
    public class OrdenTrabajoManoObra
    {
        public int omo_id { get; set; }
        public string usuario { get; set; }
        public string proveedor { get; set; }
        public string especialidad { get; set; }
        public DateTime? inicio { get; set; }
        public DateTime? fin { get; set; }
        public int minutos { get; set; }
        public bool hora_extra { get; set; }
        public decimal costo_hora { get; set; }
        public decimal costo { get; set; }
        public string moneda { get; set; }
        public string observacion { get; set; }

        public string quien { get { return !string.IsNullOrEmpty(usuario) ? usuario : proveedor; } }
    }

    /// <summary>Un servicio contratado afuera para esta orden.</summary>
    [Serializable]
    public class OrdenTrabajoServicio
    {
        public int ots_id { get; set; }
        public string proveedor { get; set; }
        public string tipo { get; set; }
        public string descripcion { get; set; }
        public decimal cantidad { get; set; }
        public decimal monto_unitario { get; set; }
        public decimal costo { get; set; }
        public string moneda { get; set; }
        public string documento { get; set; }
        public DateTime? fecha_servicio { get; set; }
        public DateTime? fecha_documento { get; set; }
    }

    /// <summary>
    /// Lo que costo una orden de trabajo.
    ///
    /// DE DONDE SALE
    ///   Los repuestos y la mano de obra los escribe la app cuando el tecnico
    ///   retira de bodega y cuando registra su tiempo; los servicios se cargan
    ///   desde el escritorio con la factura del contratista. La web los LEE:
    ///   una orden sin sus consumos no sirve para costear un equipo ni para
    ///   decidir si conviene repararlo otra vez.
    ///
    /// EL COSTO LO CALCULA EL SP
    ///   Cantidad por precio, minutos por valor hora. Repartir esa cuenta
    ///   entre la pantalla, el informe y la app termina en tres numeros
    ///   distintos para la misma orden.
    /// </summary>
    public class OrdenTrabajoRecursoController
    {
        public List<OrdenTrabajoRepuesto> GetRepuestos(int orden)
        {
            List<OrdenTrabajoRepuesto> lista = new List<OrdenTrabajoRepuesto>();

            Leer("SEL_ORDEN_TRABAJO_REPUESTO", orden, dr =>
            {
                OrdenTrabajoRepuesto r = new OrdenTrabajoRepuesto();

                r.ore_id = int.Parse(dr["ore_id"].ToString());
                r.codigo = dr["REPUESTO_CODIGO"].ToString();
                r.nombre = dr["REPUESTO_NOMBRE"].ToString();
                r.unidad = dr["UNIDAD"].ToString();
                r.lote = dr["LOTE"].ToString();
                r.componente = dr["COMPONENTE"].ToString();
                r.planificada = decimal.Parse(dr["PLANIFICADA"].ToString());
                r.reservada = decimal.Parse(dr["RESERVADA"].ToString());
                r.consumida = decimal.Parse(dr["CONSUMIDA"].ToString());
                r.devuelta = decimal.Parse(dr["DEVUELTA"].ToString());
                r.costo_unitario = decimal.Parse(dr["COSTO_UNITARIO"].ToString());
                r.costo = decimal.Parse(dr["COSTO"].ToString());
                r.moneda = dr["MONEDA"].ToString();
                r.observacion = dr["OBSERVACION"].ToString();
                r.usuario = dr["USUARIO_NOMBRE"].ToString();

                lista.Add(r);
            });

            return lista;
        }

        public List<OrdenTrabajoManoObra> GetManoObra(int orden)
        {
            List<OrdenTrabajoManoObra> lista = new List<OrdenTrabajoManoObra>();

            Leer("SEL_ORDEN_TRABAJO_MANO_OBRA", orden, dr =>
            {
                OrdenTrabajoManoObra m = new OrdenTrabajoManoObra();

                m.omo_id = int.Parse(dr["omo_id"].ToString());
                m.usuario = dr["USUARIO_NOMBRE"].ToString();
                m.proveedor = dr["PROVEEDOR_NOMBRE"].ToString();
                m.especialidad = dr["ESPECIALIDAD"].ToString();
                if (dr["omo_fecha_inicio_utc"] != DBNull.Value) m.inicio = DateTime.Parse(dr["omo_fecha_inicio_utc"].ToString());
                if (dr["omo_fecha_fin_utc"] != DBNull.Value) m.fin = DateTime.Parse(dr["omo_fecha_fin_utc"].ToString());
                m.minutos = int.Parse(dr["MINUTOS"].ToString());
                m.hora_extra = dr["HORA_EXTRA"].ToString() == "True" || dr["HORA_EXTRA"].ToString() == "1";
                m.costo_hora = decimal.Parse(dr["COSTO_HORA"].ToString());
                m.costo = decimal.Parse(dr["COSTO"].ToString());
                m.moneda = dr["MONEDA"].ToString();
                m.observacion = dr["OBSERVACION"].ToString();

                lista.Add(m);
            });

            return lista;
        }

        public List<OrdenTrabajoServicio> GetServicios(int orden)
        {
            List<OrdenTrabajoServicio> lista = new List<OrdenTrabajoServicio>();

            Leer("SEL_ORDEN_TRABAJO_SERVICIO", orden, dr =>
            {
                OrdenTrabajoServicio s = new OrdenTrabajoServicio();

                s.ots_id = int.Parse(dr["ots_id"].ToString());
                s.proveedor = dr["PROVEEDOR_NOMBRE"].ToString();
                s.tipo = dr["TIPO"].ToString();
                s.descripcion = dr["DESCRIPCION"].ToString();
                s.cantidad = decimal.Parse(dr["CANTIDAD"].ToString());
                s.monto_unitario = decimal.Parse(dr["MONTO_UNITARIO"].ToString());
                s.costo = decimal.Parse(dr["COSTO"].ToString());
                s.moneda = dr["MONEDA"].ToString();
                s.documento = dr["DOCUMENTO"].ToString();
                if (dr["ots_fecha_servicio_utc"] != DBNull.Value) s.fecha_servicio = DateTime.Parse(dr["ots_fecha_servicio_utc"].ToString());
                if (dr["ots_fecha_documento"] != DBNull.Value) s.fecha_documento = DateTime.Parse(dr["ots_fecha_documento"].ToString());

                lista.Add(s);
            });

            return lista;
        }

        /// <summary>
        /// Los tres SP se llaman igual -cliente y orden- y se leen igual. Una
        /// sola rutina evita repetir tres veces la apertura, el cierre y el
        /// catch que deja la conexion cerrada pase lo que pase.
        /// </summary>
        private static void Leer(string sp, int orden, Action<SqlDataReader> fila)
        {
            if (orden <= 0 || !Token.TokenSeguridad()) return;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = sp;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ORDEN", orden);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    while (dr.Read()) fila(dr);

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }
        }
    }
}
