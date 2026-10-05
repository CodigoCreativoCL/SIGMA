using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>
    /// La planta de un vistazo (bloque 346): lo que necesitan las vistas Lista,
    /// Tarjetas, Mapa por áreas, Vista 3D y el explorador del activo.
    ///
    /// UNA LECTURA, NO UNA POR ACTIVO
    ///   SEL_ACTIVO_PLANTA devuelve en seis resultados los tipos de lugar, los
    ///   lugares, los activos con su portada, sus componentes, los repuestos que
    ///   les sirven con su stock y cuantas fotos tiene cada uno.
    ///
    /// EL CLIENTE SALE DE LA SESION
    ///   Ningun metodo recibe el cliente de afuera: un id de otra empresa no
    ///   encuentra nada porque cada SP filtra por el cliente de la sesion.
    /// </summary>
    public class ActivoPlantaController
    {
        private static int Cliente { get { return Session.ClienteId(); } }
        private static int Usuario { get { int u; return int.TryParse(Session.UsuarioId(), out u) ? u : 0; } }

        /// <summary>Los seis resultados de SEL_ACTIVO_PLANTA, en una tabla cada uno.</summary>
        public DataSet GetPlanta(int planta)
        {
            DataSet ds = new DataSet();
            if (!Token.TokenSeguridad() || planta <= 0) return ds;
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("SEL_ACTIVO_PLANTA");
                cmd.Parameters.AddWithValue("@CLIENTE", Cliente);
                cmd.Parameters.AddWithValue("@PLANTA", planta);
                using (SqlDataAdapter da = new SqlDataAdapter(cmd)) da.Fill(ds);
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                throw;
            }
            return ds;
        }

        // ================================================================ fotos

        public DataTable GetFotos(int activo)
        {
            DataTable t = new DataTable();
            if (!Token.TokenSeguridad() || activo <= 0) return t;
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("SEL_ACTIVO_FOTOS");
                cmd.Parameters.AddWithValue("@ACTIVO", activo);
                cmd.Parameters.AddWithValue("@CLIENTE", Cliente);
                using (SqlDataAdapter da = new SqlDataAdapter(cmd)) da.Fill(t);
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                throw;
            }
            return t;
        }

        /// <summary>Agrega una foto ya subida (Archivo) al activo. Sin portada, o si se pide, queda de portada.</summary>
        public Respuesta AgregarFoto(int activo, int archivo, bool portada)
        {
            return Ejecutar("INS_ACTIVO_FOTO", "Foto agregada.", true,
                new SqlParameter("@ACTIVO", activo), new SqlParameter("@ARCHIVO", archivo),
                new SqlParameter("@PORTADA", portada), new SqlParameter("@USUARIO", Usuario));
        }

        public Respuesta CambiarPortada(int activo, int archivo)
        {
            return Ejecutar("UPD_ACTIVO_PORTADA", "Portada cambiada.", false,
                new SqlParameter("@ACTIVO", activo), new SqlParameter("@ARCHIVO", archivo), new SqlParameter("@USUARIO", Usuario));
        }

        public Respuesta QuitarFoto(int activo, int archivo)
        {
            return Ejecutar("DEL_ACTIVO_FOTO", "Foto quitada.", false,
                new SqlParameter("@ACTIVO", activo), new SqlParameter("@ARCHIVO", archivo), new SqlParameter("@USUARIO", Usuario));
        }

        // ============================================== repuestos compatibles

        /// <summary>Los repuestos del cliente con su stock, para el combo que busca al escribir (bloque 351).</summary>
        public DataTable GetRepuestosElegir()
        {
            DataTable t = new DataTable();
            if (!Token.TokenSeguridad()) return t;
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("SEL_REPUESTO_ELEGIR");
                cmd.Parameters.AddWithValue("@CLIENTE", Cliente);
                using (SqlDataAdapter da = new SqlDataAdapter(cmd)) da.Fill(t);
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                throw;
            }
            return t;
        }

        /// <summary>
        /// «Este repuesto le sirve a ESTE activo» (o subactivo) o a uno de sus
        /// componentes: exactamente uno de los dos. Si ya estaba, devuelve el mismo id.
        /// </summary>
        public Respuesta VincularRepuesto(int repuesto, int activo, int componente, string observacion)
        {
            return Ejecutar("INS_ACTIVO_REPUESTO_COMPATIBLE", "Repuesto vinculado.", true,
                new SqlParameter("@CLIENTE", Cliente), new SqlParameter("@REPUESTO", repuesto),
                new SqlParameter("@ACTIVO", activo > 0 ? (object)activo : DBNull.Value),
                new SqlParameter("@COMPONENTE", componente > 0 ? (object)componente : DBNull.Value),
                new SqlParameter("@OBSERVACION", string.IsNullOrWhiteSpace(observacion) ? (object)DBNull.Value : observacion.Trim()),
                new SqlParameter("@USUARIO", Usuario));
        }

        /// <summary>Quita un vinculo directo (activo o componente). Los de tipo o modelo viven en la ficha del repuesto.</summary>
        public Respuesta QuitarVinculoRepuesto(int vinculo)
        {
            return Ejecutar("DEL_ACTIVO_REPUESTO_COMPATIBLE", "Vínculo quitado.", false,
                new SqlParameter("@ID", vinculo), new SqlParameter("@CLIENTE", Cliente));
        }

        // ============================================================== lugares

        /// <summary>Crea (id 0) o renombra un lugar. Devuelve el id en codigo.</summary>
        public Respuesta GuardarLugar(int id, int planta, int padre, int tipo, string nombre)
        {
            return Ejecutar("UPS_LUGAR", "Lugar guardado.", true,
                new SqlParameter("@ID", id) { Direction = ParameterDirection.InputOutput },
                new SqlParameter("@CLIENTE", Cliente), new SqlParameter("@PLANTA", planta),
                new SqlParameter("@PADRE", padre > 0 ? (object)padre : DBNull.Value),
                new SqlParameter("@TIPO", tipo > 0 ? (object)tipo : DBNull.Value),
                new SqlParameter("@NOMBRE", nombre ?? ""), new SqlParameter("@USUARIO", Usuario));
        }

        public Respuesta OrdenLugar(int id, int delta)
        {
            return Ejecutar("UPD_LUGAR_ORDEN", "Orden guardado.", false,
                new SqlParameter("@ID", id), new SqlParameter("@CLIENTE", Cliente), new SqlParameter("@DELTA", delta));
        }

        public Respuesta QuitarLugar(int id)
        {
            return Ejecutar("DEL_LUGAR", "Lugar quitado.", false,
                new SqlParameter("@ID", id), new SqlParameter("@CLIENTE", Cliente), new SqlParameter("@USUARIO", Usuario));
        }

        public Respuesta GuardarTipoLugar(string singular, string plural)
        {
            return Ejecutar("UPS_LUGAR_TIPO", "Tipo de lugar guardado.", true,
                new SqlParameter("@ID", 0) { Direction = ParameterDirection.InputOutput },
                new SqlParameter("@CLIENTE", Cliente), new SqlParameter("@SINGULAR", singular ?? ""),
                new SqlParameter("@PLURAL", string.IsNullOrEmpty(plural) ? (object)DBNull.Value : plural));
        }

        /// <summary>Deja un activo en un lugar (0 = «Por ubicar») y en una posicion dentro de el.</summary>
        public Respuesta MoverActivo(int activo, int lugar, int posicion)
        {
            return Ejecutar("UPD_ACTIVO_UBICACION", "Activo ubicado.", false,
                new SqlParameter("@ACTIVO", activo), new SqlParameter("@CLIENTE", Cliente),
                new SqlParameter("@AREA", lugar > 0 ? (object)lugar : DBNull.Value),
                new SqlParameter("@POSICION", posicion >= 0 ? (object)posicion : DBNull.Value),
                new SqlParameter("@USUARIO", Usuario));
        }

        // ================================================================ comun

        /// <summary>
        /// Corre un SP de escritura. Si tiene @ID de salida, lo devuelve en
        /// codigo. Sin sesion no se finge exito.
        /// </summary>
        private Respuesta Ejecutar(string sp, string ok, bool conId, params SqlParameter[] ps)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad())
            {
                r.error = true; r.codigo = -1;
                r.detalle = "La sesión no es válida o expiró. Vuelve a entrar y repite lo que estabas haciendo.";
                return r;
            }
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand(sp);
                SqlParameter salida = null;
                foreach (SqlParameter p in ps) { cmd.Parameters.Add(p); if (p.ParameterName == "@ID") salida = p; }
                if (conId && salida == null)
                {
                    salida = new SqlParameter("@ID", SqlDbType.Int) { Direction = ParameterDirection.Output };
                    cmd.Parameters.Add(salida);
                }
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
                r.error = false;
                r.detalle = ok;
                r.codigo = salida != null && salida.Value != null && salida.Value != DBNull.Value ? Convert.ToInt32(salida.Value) : 0;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                r.error = true; r.codigo = -1; r.detalle = ex.Message;
            }
            return r;
        }
    }
}
