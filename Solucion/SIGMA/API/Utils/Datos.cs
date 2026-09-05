using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Reflection;

namespace API.Utils
{
    /// <summary>
    /// Ejecuta los stored procedures de SIGMA y mapea el resultado a DTOs.
    ///
    /// POR QUE UN MAPEADOR POR REFLEXION Y NO EL BUCLE A MANO
    ///   El sitio web escribe el bucle de lectura columna por columna en
    ///   cada controller. Funciona, pero son quince entidades por cuatro
    ///   operaciones, y ese bucle es donde se cuela el error que ya costó
    ///   tiempo tres veces: int.Parse() sobre una columna que admite NULL,
    ///   que lanza FormatException y voltea la pantalla.
    ///
    ///   Acá el NULL se resuelve UNA vez, bien, para todas las entidades: si
    ///   la columna viene nula y la propiedad no admite nulos, se deja el
    ///   valor por defecto en vez de reventar.
    ///
    /// LA CONVENCION QUE LO HACE POSIBLE
    ///   Las propiedades del DTO se llaman igual que la columna del SP
    ///   (cin_id, cin_nombre), que es exactamente lo que ya exige el patrón
    ///   del grupo para los Model. La comparación ignora mayúsculas porque
    ///   los SEL_ devuelven los alias en MAYUSCULAS.
    ///
    /// LO QUE NO HACE
    ///   No arma SQL. Todo pasa por SP, sin excepción: es una prohibición
    ///   dura del estándar y además lo que mantiene las reglas de negocio en
    ///   un solo lugar para la web, la API y la app.
    /// </summary>
    public static class Datos
    {
        /// <summary>
        /// Ejecuta un SEL_ y devuelve la lista mapeada.
        /// Los parámetros nulos NO se envían: los SEL_ del proyecto usan
        /// "@X IS NULL OR columna = @X", así que omitir es no filtrar.
        /// </summary>
        public static List<T> Listar<T>(string sp, Dictionary<string, object> parametros = null) where T : new()
        {
            List<T> lista = new List<T>();

            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = sp;

            Agregar(cmd, parametros);

            try
            {
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    PropertyInfo[] propiedades = typeof(T).GetProperties();

                    // El mapa columna -> propiedad se arma UNA vez por
                    // consulta, no una por fila: con 200 filas y 20 columnas
                    // la diferencia es real.
                    Dictionary<string, PropertyInfo> mapa =
                        new Dictionary<string, PropertyInfo>(StringComparer.OrdinalIgnoreCase);

                    foreach (PropertyInfo p in propiedades)
                        if (p.CanWrite) mapa[p.Name] = p;

                    List<string> columnas = new List<string>();
                    for (int i = 0; i < dr.FieldCount; i++) columnas.Add(dr.GetName(i));

                    while (dr.Read())
                    {
                        T item = new T();

                        for (int i = 0; i < columnas.Count; i++)
                        {
                            PropertyInfo p;
                            if (!mapa.TryGetValue(columnas[i], out p)) continue;

                            object valor = dr.IsDBNull(i) ? null : dr.GetValue(i);
                            Asignar(item, p, valor);
                        }

                        lista.Add(item);
                    }
                }
            }
            finally
            {
                Cerrar(cmd);
            }

            return lista;
        }

        /// <summary>
        /// Igual que <see cref="Listar{T}"/>, pero para los SEL_ que paginan
        /// en SQL y devuelven el total en un parámetro de salida.
        ///
        /// POR QUE HIZO FALTA
        ///   SEL_ACTIVO_FICHA declara @TOTAL INT OUTPUT y, al ser obligatorio,
        ///   SQL Server rechaza la llamada que no lo manda: "expects parameter
        ///   '@TOTAL', which was not supplied". El controller lo omitía y
        ///   GET /activos/{id}/ficha respondía 500 en cada llamada. Se detectó
        ///   ejercitando la API por HTTP el 04-09-2026.
        ///
        ///   Agregar el parámetro de salida al diccionario común no alcanza:
        ///   <c>Agregar</c> los manda todos como entrada, y un parámetro de
        ///   salida enviado como entrada sigue faltando.
        ///
        /// EL TOTAL SE LEE DESPUES DE CERRAR EL LECTOR
        ///   SQL Server llena los parámetros de salida recién cuando terminó
        ///   de enviar los resultados. Leerlo con el DataReader abierto
        ///   devuelve null, y ese null se ve como "no hay nada" en vez de como
        ///   un error.
        /// </summary>
        public static List<T> ListarConTotal<T>(string sp, Dictionary<string, object> parametros,
                                                out int total, string parametroTotal = "@TOTAL") where T : new()
        {
            List<T> lista = new List<T>();
            total = 0;

            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = sp;

            Agregar(cmd, parametros);
            cmd.Parameters.Add(parametroTotal, SqlDbType.Int).Direction = ParameterDirection.Output;

            try
            {
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read()) lista.Add(Mapear<T>(dr));
                }

                object v = cmd.Parameters[parametroTotal].Value;
                if (v != null && v != DBNull.Value) total = Convert.ToInt32(v);
            }
            finally
            {
                Cerrar(cmd);
            }

            return lista;
        }

        /// <summary>
        /// Ejecuta un SP que devuelve VARIOS resultados y los entrega crudos.
        ///
        /// POR QUE NO SE MAPEA A DTO
        ///   La sábana de datos (HU-150) devuelve ocho bloques distintos, con
        ///   forma distinta cada uno, y la app los guarda tal cual en su
        ///   SQLite. Declarar ocho DTOs para volver a serializarlos a JSON
        ///   sería escribir dos veces la misma lista de columnas y tener que
        ///   tocar la API cada vez que un bloque suma un campo.
        ///
        ///   Acá las columnas viajan como las nombró el SP. Es exactamente lo
        ///   que la app necesita: el nombre de la columna ES el contrato.
        /// </summary>
        public static DataSet Conjunto(string sp, Dictionary<string, object> parametros)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = sp;
            cmd.CommandType = CommandType.StoredProcedure;

            Agregar(cmd, parametros);

            DataSet ds = new DataSet();

            using (SqlConnection cn = new SqlConnection(Conexion.GetConnectionString()))
            {
                cmd.Connection = cn;
                cn.Open();

                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                {
                    da.Fill(ds);
                }
            }

            return ds;
        }

        /// <summary>
        /// Un resultado del conjunto, como lista de diccionarios.
        ///
        /// El DBNull se convierte a null: serializado tal cual, Json.NET
        /// escribe un objeto vacío `{}` en vez de `null` y el cliente no
        /// puede distinguir "sin valor" de "objeto raro".
        /// </summary>
        public static List<Dictionary<string, object>> Filas(DataSet ds, int indice)
        {
            List<Dictionary<string, object>> lista = new List<Dictionary<string, object>>();

            if (ds == null || ds.Tables.Count <= indice) return lista;

            DataTable t = ds.Tables[indice];

            foreach (DataRow r in t.Rows)
            {
                Dictionary<string, object> fila = new Dictionary<string, object>();

                foreach (DataColumn c in t.Columns)
                    fila[c.ColumnName] = r.IsNull(c) ? null : r[c];

                lista.Add(fila);
            }

            return lista;
        }

        /// <summary>Un valor suelto de un resultado de una sola fila.</summary>
        public static object Escalar(DataSet ds, int indice, string columna)
        {
            if (ds == null || ds.Tables.Count <= indice) return null;

            DataTable t = ds.Tables[indice];

            if (t.Rows.Count == 0 || !t.Columns.Contains(columna)) return null;

            DataRow r = t.Rows[0];
            return r.IsNull(columna) ? null : r[columna];
        }

        /// <summary>
        /// Para los SP que devuelven CABECERA y DETALLE en una sola llamada.
        ///
        /// POR QUE NO SON DOS Listar SEGUIDOS
        ///   Serian dos conexiones para contestar una sola pregunta, y entre
        ///   una y otra el saldo puede cambiar: la cabecera dejaria de
        ///   corresponder al detalle que se muestra debajo. Desde un telefono
        ///   ademas son dos viajes de red donde alcanza uno.
        /// </summary>
        public static void ListarDos<TA, TB>(string sp, Dictionary<string, object> parametros,
                                             out TA cabecera, out List<TB> detalle)
            where TA : class, new()
            where TB : new()
        {
            cabecera = null;
            detalle = new List<TB>();

            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = sp;

            Agregar(cmd, parametros);

            try
            {
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read()) cabecera = Mapear<TA>(dr);

                    if (dr.NextResult())
                    {
                        while (dr.Read()) detalle.Add(Mapear<TB>(dr));
                    }
                }
            }
            finally
            {
                Cerrar(cmd);
            }
        }

        /// <summary>
        /// Mapea la fila actual del lector a un objeto.
        ///
        /// Se armaba dentro de Listar; sacarlo permite reusarlo en ListarDos
        /// sin copiar la logica de columnas y nulos, que es donde aparecen
        /// las diferencias sutiles entre dos copias.
        /// </summary>
        private static T Mapear<T>(SqlDataReader dr) where T : new()
        {
            T item = new T();

            Dictionary<string, PropertyInfo> mapa =
                new Dictionary<string, PropertyInfo>(StringComparer.OrdinalIgnoreCase);

            foreach (PropertyInfo p in typeof(T).GetProperties())
                if (p.CanWrite) mapa[p.Name] = p;

            for (int i = 0; i < dr.FieldCount; i++)
            {
                PropertyInfo p;
                if (!mapa.TryGetValue(dr.GetName(i), out p)) continue;

                object valor = dr.IsDBNull(i) ? null : dr.GetValue(i);
                Asignar(item, p, valor);
            }

            return item;
        }

        /// <summary>
        /// Ejecuta un INS_ / UPD_ / DEL_ y devuelve el @ID de salida si el
        /// SP lo declara.
        ///
        /// NO captura la SqlException: la deja subir para que ApiBase la
        /// traduzca. Tragarla acá y devolver un booleano perdería el mensaje
        /// del RAISERROR, que es justamente lo que hay que mostrarle a la
        /// persona.
        /// </summary>
        public static int Ejecutar(string sp, Dictionary<string, object> parametros, bool devuelveId = false)
        {
            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand(sp);

                if (devuelveId)
                    cmd.Parameters.Add("@ID", SqlDbType.Int).Direction = ParameterDirection.Output;

                Agregar(cmd, parametros);

                cmd.ExecuteNonQuery();

                if (devuelveId && cmd.Parameters["@ID"].Value != DBNull.Value)
                    return Convert.ToInt32(cmd.Parameters["@ID"].Value);

                return 0;
            }
            finally
            {
                Cerrar(cmd);
            }
        }

        private static void Agregar(SqlCommand cmd, Dictionary<string, object> parametros)
        {
            if (parametros == null) return;

            foreach (KeyValuePair<string, object> p in parametros)
            {
                // Omitir el nulo es no filtrar. Enviarlo como DBNull en un
                // INS_ sí importa, y para eso el llamador manda DBNull.Value
                // explícito.
                if (p.Value == null) continue;

                if (cmd.Parameters.Contains(p.Key))
                    cmd.Parameters[p.Key].Value = p.Value;
                else
                    cmd.Parameters.AddWithValue(p.Key, p.Value);
            }
        }

        /// <summary>
        /// Convierte y asigna, tolerando el NULL.
        ///
        /// Acá está la lección que costó tres pantallas: una columna
        /// anulable leída con int.Parse("") lanza FormatException. Si la
        /// propiedad no admite nulos, un NULL de la base se deja como el
        /// valor por defecto del tipo y no como una excepción.
        /// </summary>
        private static void Asignar(object destino, PropertyInfo p, object valor)
        {
            try
            {
                if (valor == null)
                {
                    if (!p.PropertyType.IsValueType ||
                        Nullable.GetUnderlyingType(p.PropertyType) != null)
                        p.SetValue(destino, null, null);

                    return;
                }

                Type tipo = Nullable.GetUnderlyingType(p.PropertyType) ?? p.PropertyType;

                if (tipo == typeof(Guid))
                    p.SetValue(destino, (valor is Guid) ? valor : new Guid(valor.ToString()), null);
                else if (tipo.IsEnum)
                    p.SetValue(destino, Enum.ToObject(tipo, Convert.ToInt32(valor)), null);
                else
                    p.SetValue(destino, Convert.ChangeType(valor, tipo), null);
            }
            catch (Exception ex)
            {
                /* Una columna que no calza con su propiedad es un error de
                   programación, no de datos: se registra y se sigue con el
                   resto del DTO. Tumbar la consulta entera dejaría sin
                   respuesta un listado por un campo secundario mal escrito. */
                System.Diagnostics.Trace.TraceWarning(
                    "SIGMA API: no se pudo mapear " + p.Name + " (" + p.PropertyType.Name + "): " + ex.Message);
            }
        }

        private static void Cerrar(SqlCommand cmd)
        {
            if (cmd == null) return;

            try
            {
                if (cmd.Connection != null && cmd.Connection.State != ConnectionState.Closed)
                    cmd.Connection.Close();

                cmd.Dispose();
            }
            catch (Exception ex)
            {
            }
        }
    }
}
