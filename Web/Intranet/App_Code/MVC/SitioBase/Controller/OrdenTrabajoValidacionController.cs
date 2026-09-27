using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>Una firma de la orden: aceptación, ejecución o validación (HU-118).</summary>
    [Serializable]
    public class OrdenTrabajoValidacion
    {
        public int id { get; set; }
        public int tipo_id { get; set; }
        public string tipo_codigo { get; set; }
        public string tipo_nombre { get; set; }
        public string resultado { get; set; }
        public DateTime fecha { get; set; }
        public string observacion { get; set; }
        public int? archivo_firma { get; set; }
        public string usuario_nombre { get; set; }

        public bool aprobada { get { return resultado == "APROBADO"; } }
    }

    [Serializable]
    public class ValidacionTipo
    {
        public int id { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
    }

    /// <summary>
    /// Las firmas de la orden en la web. Se ESCRIBEN por el mismo SP que usa
    /// la app (API_INS_ORDEN_TRABAJO_VALIDACION): idempotente por uuid, valida
    /// el vocabulario contra el CHECK de la tabla y exige motivo al rechazar.
    /// Dos caminos de escritura darían dos formatos, y el historial dejaría de
    /// servir como respaldo.
    ///
    /// Las firmas son append-only: un rechazo se supera con una firma
    /// posterior y las dos quedan. La condición «validada» no se guarda: se
    /// calcula al leer (criterio 3 de HU-118).
    /// </summary>
    public class OrdenTrabajoValidacionController
    {
        public List<OrdenTrabajoValidacion> GetValidaciones(int orden)
        {
            List<OrdenTrabajoValidacion> lista = new List<OrdenTrabajoValidacion>();
            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand("SEL_ORDEN_TRABAJO_VALIDACION");
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            cmd.Parameters.AddWithValue("@ORDEN", orden);
            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                    lista.Add(new OrdenTrabajoValidacion
                    {
                        id = Convert.ToInt32(dr["ID"]),
                        tipo_id = Convert.ToInt32(dr["TIPO_ID"]),
                        tipo_codigo = dr["TIPO_CODIGO"].ToString(),
                        tipo_nombre = dr["TIPO_NOMBRE"].ToString(),
                        resultado = dr["RESULTADO"].ToString(),
                        fecha = Convert.ToDateTime(dr["FECHA"]),
                        observacion = dr["OBSERVACION"] == DBNull.Value ? "" : dr["OBSERVACION"].ToString(),
                        archivo_firma = dr["ARCHIVO_FIRMA"] == DBNull.Value ? (int?)null : Convert.ToInt32(dr["ARCHIVO_FIRMA"]),
                        usuario_nombre = dr["USUARIO_NOMBRE"].ToString()
                    });
            }
            cmd.Connection.Close(); cmd.Dispose();
            return lista;
        }

        public List<ValidacionTipo> GetTipos()
        {
            List<ValidacionTipo> lista = new List<ValidacionTipo>();
            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand("SEL_VALIDACION_TIPO");
            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                    lista.Add(new ValidacionTipo { id = Convert.ToInt32(dr["ID"]), codigo = dr["CODIGO"].ToString(), nombre = dr["NOMBRE"].ToString() });
            }
            cmd.Connection.Close(); cmd.Dispose();
            return lista;
        }

        /// <summary>
        /// Registra una firma. El trazo llega como PNG en base64 y se guarda
        /// como archivo de categoría FIRMA, igual que la firma del cierre.
        /// El uuid lo genera la ficha AL ABRIRSE: un doble clic en Guardar
        /// devuelve la misma firma y no crea dos.
        /// </summary>
        public Respuesta Registrar(int orden, int tipo, string resultado, string observacion, string firmaDataUrl, Guid uuid)
        {
            Respuesta r = new Respuesta();
            try
            {
                if (!Token.TokenSeguridad()) throw new Exception("La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.");
                if (!Token.Puede("VALIDAR ORDEN TRABAJO")) throw new Exception("No tiene permiso para firmar órdenes de trabajo.");
                if (string.IsNullOrEmpty(firmaDataUrl)) throw new Exception("Dibuje su firma antes de guardar.");

                int coma = firmaDataUrl.IndexOf(',');
                byte[] bytes = Convert.FromBase64String(coma >= 0 ? firmaDataUrl.Substring(coma + 1) : firmaDataUrl);
                if (bytes.Length == 0) throw new Exception("La firma llegó vacía.");

                Archivo a = new Archivo();
                a.arc_cliente = Session.ClienteId();
                a.arc_archivo_categoria = OrdenTrabajoArchivoController.CATEGORIA_FIRMA;
                a.arc_nombre_original = "firma-" + (resultado ?? "").ToLowerInvariant() + "-ot-" + orden + ".png";
                a.arc_mime = "image/png";
                a.contenido = bytes;

                Respuesta sub = new ArchivoController().InsertArchivo(a, "firmas");
                if (sub.error) return sub;

                SqlCommand cmd = Conexion.GetCommand("API_INS_ORDEN_TRABAJO_VALIDACION");
                try
                {
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@UUID", uuid);
                    cmd.Parameters.AddWithValue("@ORDEN", orden);
                    cmd.Parameters.AddWithValue("@VALIDACION_TIPO", tipo);
                    cmd.Parameters.AddWithValue("@RESULTADO", resultado ?? "");
                    cmd.Parameters.AddWithValue("@OBSERVACION", string.IsNullOrWhiteSpace(observacion) ? (object)DBNull.Value : observacion.Trim());
                    cmd.Parameters.AddWithValue("@ARCHIVO_FIRMA", sub.codigo);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.ExecuteNonQuery();
                    r.codigo = cmd.Parameters["@ID"].Value == DBNull.Value ? 0 : (int)cmd.Parameters["@ID"].Value;
                }
                finally
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                }

                r.error = false;
                r.detalle = "Firma registrada.";
            }
            catch (Exception ex)
            {
                r.codigo = -1; r.error = true; r.detalle = ex.Message;
            }
            return r;
        }
    }
}
