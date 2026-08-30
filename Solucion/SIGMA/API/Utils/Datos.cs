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
