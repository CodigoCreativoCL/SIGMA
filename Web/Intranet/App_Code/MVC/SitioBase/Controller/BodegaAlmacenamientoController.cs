using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text.RegularExpressions;

namespace SitioBase.Controller
{
    /// <summary>
    /// Lo que el mapa 3D sabe de una bodega, para la ficha del menu
    /// (Inventario > Bodegas): metodo de salida, racks con su carga, plano y
    /// conteo, y la convencion de codigos con que el mapa arma los pasillos.
    ///
    /// LA CONVENCION <prefijo>-<pasillo>-R<numero>
    ///   El mapa lee P1-A-R04 como pasillo A, rack 4 (impares a la izquierda,
    ///   pares a la derecha). Un codigo que no calza -el UBI-17 que generaba
    ///   esta ficha antes- queda en un pasillo aparte. Por eso los racks
    ///   nuevos se crean aqui con el mismo codigo que sugiere el mapa
    ///   (sugerirRack en Js/sigma-bodega3d.js): si una regla cambia, cambia
    ///   la otra.
    /// </summary>
    public class BodegaAlmacenamientoController
    {
        public static readonly string[] Metodos = { "FEFO", "FIFO", "LIFO" };

        private static DataTable Leer(string sp, params object[] pares)
        {
            if (!Token.TokenSeguridad()) return new DataTable();
            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = sp;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                for (int i = 0; i + 1 < pares.Length; i += 2) cmd.Parameters.AddWithValue((string)pares[i], pares[i + 1] ?? DBNull.Value);
                return Conexion.GetDataTable(cmd);
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                return new DataTable();
            }
        }

        /// <summary>Por bodega: METODO, RACKS, MOVIDOS, CONTADOS_30. Sin bodega, todas las del cliente.</summary>
        public DataTable Resumen(int? bodega = null)
        {
            return Leer("SEL_BODEGA_RESUMEN_MAPA", "@BODEGA", bodega.HasValue ? (object)bodega.Value : null);
        }

        public string Metodo(int bodega)
        {
            DataTable t = Resumen(bodega);
            return t.Rows.Count > 0 ? Convert.ToString(t.Rows[0]["METODO"]) : "FEFO";
        }

        /// <summary>Por rack: BUB_ID, CODIGO, NOMBRE, CARGA, MOVIDO, REPUESTOS, CANTIDAD, CONTEO_FECHA.</summary>
        public DataTable Ubicaciones(int bodega)
        {
            return Leer("SEL_BODEGA_UBICACIONES_MAPA", "@BODEGA", bodega);
        }

        private static Respuesta Escribir(string sp, string ok, params object[] pares)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "La sesión expiró."; return r; }
            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = sp;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                for (int i = 0; i + 1 < pares.Length; i += 2) cmd.Parameters.AddWithValue((string)pares[i], pares[i + 1] ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                Conexion.GetDataTable(cmd);
                r.detalle = ok;
            }
            catch (Exception ex)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                r.error = true; r.codigo = -1; r.detalle = ex.Message;
            }
            return r;
        }

        public Respuesta GuardarMetodo(int bodega, string metodo)
        {
            return Escribir("UPD_BODEGA_METODO_SALIDA", "Método de salida actualizado.", "@BODEGA", bodega, "@METODO", metodo);
        }

        /// <summary>Vacio vuelve al valor por defecto del mapa (1.000 kg por nivel).</summary>
        public Respuesta GuardarCarga(int ubicacion, decimal? carga)
        {
            return Escribir("UPD_UBICACION_CARGA", "Carga actualizada.", "@UBICACION", ubicacion, "@CARGA", carga.HasValue ? (object)carga.Value : null);
        }

        // ------------------------------------------------------------ codigos

        /// <summary>
        /// Pasillo y numero tal como los lee el mapa (leerUbicacion): la
        /// penultima parte de 1 a 3 letras es el pasillo y la ultima trae el
        /// numero. Falso si no calza: el mapa lo pone en un pasillo aparte.
        /// </summary>
        public static bool LeerCodigo(string codigo, out string pasillo, out int numero)
        {
            pasillo = ""; numero = 0;
            string[] p = Regex.Split((codigo ?? "").ToUpperInvariant(), @"[-_\s.]+").Where(x => x.Length > 0).ToArray();
            if (p.Length < 2) return false;
            string ult = Regex.Replace(p[p.Length - 1], @"\D", ""), pen = p[p.Length - 2];
            if (ult.Length == 0 || !Regex.IsMatch(pen, "^[A-Z]{1,3}$")) return false;
            if (!int.TryParse(ult, out numero)) return false;
            pasillo = pen;
            return true;
        }

        /// <summary>
        /// El prefijo de la bodega (prefijoBodega del mapa): lo que va antes del
        /// pasillo en el primer codigo con tres partes o mas; si no hay, el
        /// codigo de la bodega.
        /// </summary>
        public static string Prefijo(IEnumerable<string> codigos, string codigoBodega)
        {
            foreach (string c in codigos)
            {
                string[] p = (c ?? "").Split('-');
                if (p.Length >= 3) return string.Join("-", p.Take(p.Length - 2));
            }
            string b = Regex.Replace(codigoBodega ?? "", @"\s+", "");
            return b.Length > 0 ? b : "BOD";
        }

        public static string CodigoRack(string prefijo, string pasillo, int numero)
        {
            return prefijo + "-" + pasillo + "-R" + numero.ToString("00");
        }

        /// <summary>Los tipos de area (Pasillo, Sala, Zona...) que ve este cliente (BD 375).</summary>
        public List<string> TiposArea()
        {
            List<string> l = new List<string>();
            foreach (DataRow f in Leer("SEL_AREA_TIPOS").Rows) l.Add(Convert.ToString(f["NOMBRE"]));
            return l;
        }

        /// <summary>El tipo de area de cada rack de la bodega: {ubicacion: tipo}.</summary>
        public Dictionary<int, string> AreasDeBodega()
        {
            Dictionary<int, string> d = new Dictionary<int, string>();
            foreach (DataRow f in Leer("SEL_BODEGA_UBICACION_NIVELES").Rows) d[Convert.ToInt32(f["BUB_ID"])] = Convert.ToString(f["AREA_TIPO"]);
            return d;
        }

        private static void AsignarArea(int ubicacion, string tipo)
        {
            try
            {
                DataTable t = Leer("INS_AREA_TIPO", "@NOMBRE", tipo);
                if (t.Rows.Count > 0) Leer("UPD_UBICACION_AREA_TIPO", "@UBICACION", ubicacion, "@TIPO", Convert.ToInt32(t.Rows[0]["ID"]));
            }
            catch (Exception) { /* el rack ya existe; sin tipo se llama «Pasillo» */ }
        }

        /// <summary>
        /// Crea <paramref name="cantidad"/> racks seguidos en el area, desde
        /// el siguiente numero libre. Para en el primero que falle y dice
        /// cuantos alcanzo a crear: no deja la mitad sin avisar.
        /// </summary>
        public Respuesta CrearRacks(int bodega, string codigoBodega, IList<string> codigosActuales, string pasillo, int cantidad, string nombre, string tipoArea = null)
        {
            Respuesta r = new Respuesta();
            pasillo = (pasillo ?? "").Trim().ToUpperInvariant();
            tipoArea = string.IsNullOrWhiteSpace(tipoArea) ? "Pasillo" : tipoArea.Trim();
            if (tipoArea.Length > 60) { r.error = true; r.detalle = "El tipo de área es muy largo (máximo 60 letras)."; return r; }
            if (!Regex.IsMatch(pasillo, "^[A-Z]{1,3}$")) { r.error = true; r.detalle = "El código del área es de 1 a 3 letras, como A o AB."; return r; }
            if (cantidad < 1 || cantidad > 30) { r.error = true; r.detalle = "Se crean de 1 a 30 racks por vez."; return r; }

            string prefijo = Prefijo(codigosActuales, codigoBodega);
            int desde = 0;
            foreach (string c in codigosActuales)
            {
                string pa; int n;
                if (LeerCodigo(c, out pa, out n) && pa == pasillo && n > desde) desde = n;
            }

            BodegaController bc = new BodegaController();
            List<string> creados = new List<string>();
            for (int k = 1; k <= cantidad; k++)
            {
                int n = desde + k;
                string codigo = CodigoRack(prefijo, pasillo, n);
                string nom = string.IsNullOrEmpty(nombre) ? tipoArea + " " + pasillo + " · Rack " + n.ToString("00")
                           : (cantidad == 1 ? nombre : nombre + " " + n.ToString("00"));
                Respuesta x = bc.GuardarUbicacion(new BodegaUbicacion { bub_id = 0, bub_bodega = bodega, bub_codigo = codigo, bub_nombre = nom, bub_habilitado = true });
                if (x.error)
                {
                    r.error = true;
                    r.detalle = (creados.Count > 0 ? "Se crearon " + string.Join(", ", creados) + ", pero " : "") + codigo + " no: " + x.detalle;
                    return r;
                }
                creados.Add(codigo);
                if (x.codigo > 0) AsignarArea(x.codigo, tipoArea);
            }
            r.codigo = creados.Count;
            r.detalle = creados.Count == 1 ? "Rack " + creados[0] + " creado." : "Racks " + creados[0] + " a " + creados[creados.Count - 1] + " creados.";
            return r;
        }
    }
}
