using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Model
{
    /// <summary>«Este equipo mide esta variable, en esta unidad, con estos umbrales» (HU-041).</summary>
    public class ActivoVariable
    {
        public int ava_id { get; set; }
        public int ava_cliente { get; set; }
        public int ava_activo { get; set; }
        public int? ava_activo_componente { get; set; }
        public int ava_variable_medicion { get; set; }
        public int? ava_unidad_medida { get; set; }
        public decimal? ava_valor_minimo { get; set; }
        public decimal? ava_valor_maximo { get; set; }
        public decimal? ava_valor_advertencia { get; set; }
        public decimal? ava_valor_critico { get; set; }
        public int? ava_frecuencia_esperada_hora { get; set; }
        public int? ava_registro_descubrimiento { get; set; }
        public DateTime? ava_fecha_creacion { get; set; }
        public DateTime? ava_fecha_actualizacion { get; set; }
        public bool ava_habilitado { get; set; }

        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string planta_nombre { get; set; }
        public string componente_codigo { get; set; }
        public string componente_nombre { get; set; }
        public string variable_codigo { get; set; }
        public string variable_nombre { get; set; }
        public string unidad_simbolo { get; set; }
        public string unidad_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }
        public string etiqueta { get; set; }
        public int mediciones { get; set; }
        public int condiciones { get; set; }

        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public int? filtro_activo { get; set; }
        public int? filtro_instalacion { get; set; }
        public int? filtro_variable { get; set; }

        public bool quita_minimo { get; set; }
        public bool quita_maximo { get; set; }
        public bool quita_advertencia { get; set; }
        public bool quita_critico { get; set; }
        public bool quita_frecuencia { get; set; }
    }
    /// <summary>Un punto de la serie de una variable (SEL_ACTIVO_MEDICION_SERIE, HU-045).</summary>
    [Serializable]
    public class MedicionSerie
    {
        public int amd_id { get; set; }
        public DateTime fecha_utc { get; set; }
        /// <summary>La misma fecha en hora de Santiago, para mostrar.</summary>
        public DateTime fecha { get; set; }
        /// <summary>En la unidad de la variable, que es la de los umbrales.</summary>
        public decimal valor { get; set; }
        public decimal valor_original { get; set; }
        public string unidad_original { get; set; }
        /// <summary>NORMAL, ADVERTENCIA, CRITICO o FUERA_RANGO, calculado por el SP.</summary>
        public string nivel { get; set; }
        public string calidad { get; set; }
        public string origen_codigo { get; set; }
        public string origen { get; set; }
        public string entrada { get; set; }
        public int? orden_trabajo { get; set; }
        public int? ot_correlativo { get; set; }
        public int? checklist_ejecucion { get; set; }
        public string observacion { get; set; }
        public string usuario_nombre { get; set; }
        public DateTime? fecha_registro_utc { get; set; }
    }

    /// <summary>Lo que la cabecera de la serie dice antes del grafico.</summary>
    [Serializable]
    public class MedicionSerieResumen
    {
        public int puntos { get; set; }
        public int criticos { get; set; }
        public int advertencias { get; set; }
        public int fuera_rango { get; set; }
        public decimal? valor_minimo { get; set; }
        public decimal? valor_maximo { get; set; }
        public decimal? promedio { get; set; }
        public decimal? ultimo_valor { get; set; }
        public DateTime? ultima_fecha_utc { get; set; }
    }
}

namespace SitioBase.Controller
{
    public class ActivoVariableController
    {
        public List<ActivoVariable> GetVariables(ActivoVariable filtro = null)
        {
            List<ActivoVariable> lista = new List<ActivoVariable>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_VARIABLE";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.ava_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.ava_id);
                        if (filtro.filtro_activo != null && filtro.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", filtro.filtro_activo);
                        if (filtro.filtro_variable != null && filtro.filtro_variable > 0) cmd.Parameters.AddWithValue("@VARIABLE", filtro.filtro_variable);
                        if (filtro.filtro_instalacion != null && filtro.filtro_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", filtro.filtro_instalacion);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoVariable v = new ActivoVariable();
                            v.ava_id = int.Parse(dr["ava_id"].ToString());
                            v.ava_cliente = int.Parse(dr["ava_cliente"].ToString());
                            v.ava_activo = int.Parse(dr["ava_activo"].ToString());
                            if (dr["ava_activo_componente"] != DBNull.Value) v.ava_activo_componente = int.Parse(dr["ava_activo_componente"].ToString());
                            v.ava_variable_medicion = int.Parse(dr["ava_variable_medicion"].ToString());
                            if (dr["ava_unidad_medida"] != DBNull.Value) v.ava_unidad_medida = int.Parse(dr["ava_unidad_medida"].ToString());
                            if (dr["ava_valor_minimo"] != DBNull.Value) v.ava_valor_minimo = decimal.Parse(dr["ava_valor_minimo"].ToString());
                            if (dr["ava_valor_maximo"] != DBNull.Value) v.ava_valor_maximo = decimal.Parse(dr["ava_valor_maximo"].ToString());
                            if (dr["ava_valor_advertencia"] != DBNull.Value) v.ava_valor_advertencia = decimal.Parse(dr["ava_valor_advertencia"].ToString());
                            if (dr["ava_valor_critico"] != DBNull.Value) v.ava_valor_critico = decimal.Parse(dr["ava_valor_critico"].ToString());
                            if (dr["ava_frecuencia_esperada_hora"] != DBNull.Value) v.ava_frecuencia_esperada_hora = int.Parse(dr["ava_frecuencia_esperada_hora"].ToString());
                            if (dr["ava_registro_descubrimiento"] != DBNull.Value) v.ava_registro_descubrimiento = int.Parse(dr["ava_registro_descubrimiento"].ToString());
                            if (dr["ava_fecha_creacion"] != DBNull.Value) v.ava_fecha_creacion = (DateTime)dr["ava_fecha_creacion"];
                            if (dr["ava_fecha_actualizacion"] != DBNull.Value) v.ava_fecha_actualizacion = (DateTime)dr["ava_fecha_actualizacion"];
                            v.ava_habilitado = (bool)dr["ava_habilitado"];
                            v.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            v.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            v.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            v.componente_codigo = dr["COMPONENTE_CODIGO"].ToString();
                            v.componente_nombre = dr["COMPONENTE_NOMBRE"].ToString();
                            v.variable_codigo = dr["VARIABLE_CODIGO"].ToString();
                            v.variable_nombre = dr["VARIABLE_NOMBRE"].ToString();
                            v.unidad_simbolo = dr["UNIDAD_SIMBOLO"].ToString();
                            v.unidad_nombre = dr["UNIDAD_NOMBRE"].ToString();
                            v.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            v.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                            v.etiqueta = dr["ETIQUETA"].ToString();
                            v.mediciones = int.Parse(dr["MEDICIONES"].ToString());
                            v.condiciones = int.Parse(dr["CONDICIONES"].ToString());
                            lista.Add(v);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        /// <summary>La serie de una variable en un rango (HU-045). Sin fechas: los ultimos 90 dias.</summary>
        public List<MedicionSerie> GetSerie(int variable, DateTime? desde, DateTime? hasta)
        {
            List<MedicionSerie> lista = new List<MedicionSerie>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_MEDICION_SERIE";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@ACTIVO_VARIABLE", variable);
                    if (desde != null) cmd.Parameters.AddWithValue("@DESDE", desde);
                    if (hasta != null) cmd.Parameters.AddWithValue("@HASTA", hasta);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            MedicionSerie p = new MedicionSerie();
                            p.amd_id = int.Parse(dr["AMD_ID"].ToString());
                            p.fecha_utc = DateTime.Parse(dr["FECHA_UTC"].ToString());
                            p.fecha = DateTime.Parse(dr["FECHA"].ToString());
                            p.valor = decimal.Parse(dr["VALOR"].ToString());
                            p.valor_original = decimal.Parse(dr["VALOR_ORIGINAL"].ToString());
                            p.unidad_original = dr["UNIDAD_ORIGINAL"].ToString();
                            p.nivel = dr["NIVEL"].ToString();
                            p.calidad = dr["CALIDAD"].ToString();
                            p.origen_codigo = dr["ORIGEN_CODIGO"].ToString();
                            p.origen = dr["ORIGEN"].ToString();
                            p.entrada = dr["ENTRADA"].ToString();
                            if (dr["ORDEN_TRABAJO"] != DBNull.Value) p.orden_trabajo = int.Parse(dr["ORDEN_TRABAJO"].ToString());
                            if (dr["OT_CORRELATIVO"] != DBNull.Value) p.ot_correlativo = int.Parse(dr["OT_CORRELATIVO"].ToString());
                            if (dr["CHECKLIST_EJECUCION"] != DBNull.Value) p.checklist_ejecucion = int.Parse(dr["CHECKLIST_EJECUCION"].ToString());
                            p.observacion = dr["OBSERVACION"].ToString();
                            p.usuario_nombre = dr["USUARIO_NOMBRE"].ToString();
                            if (dr["FECHA_REGISTRO_UTC"] != DBNull.Value) p.fecha_registro_utc = DateTime.Parse(dr["FECHA_REGISTRO_UTC"].ToString());
                            lista.Add(p);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public MedicionSerieResumen GetSerieResumen(int variable, DateTime? desde, DateTime? hasta)
        {
            MedicionSerieResumen r = new MedicionSerieResumen();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_MEDICION_SERIE_RESUMEN";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@ACTIVO_VARIABLE", variable);
                    if (desde != null) cmd.Parameters.AddWithValue("@DESDE", desde);
                    if (hasta != null) cmd.Parameters.AddWithValue("@HASTA", hasta);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            r.puntos = int.Parse(dr["PUNTOS"].ToString());
                            if (dr["CRITICOS"] != DBNull.Value) r.criticos = int.Parse(dr["CRITICOS"].ToString());
                            if (dr["ADVERTENCIAS"] != DBNull.Value) r.advertencias = int.Parse(dr["ADVERTENCIAS"].ToString());
                            if (dr["FUERA_RANGO"] != DBNull.Value) r.fuera_rango = int.Parse(dr["FUERA_RANGO"].ToString());
                            if (dr["VALOR_MINIMO"] != DBNull.Value) r.valor_minimo = decimal.Parse(dr["VALOR_MINIMO"].ToString());
                            if (dr["VALOR_MAXIMO"] != DBNull.Value) r.valor_maximo = decimal.Parse(dr["VALOR_MAXIMO"].ToString());
                            if (dr["PROMEDIO"] != DBNull.Value) r.promedio = decimal.Parse(dr["PROMEDIO"].ToString());
                            if (dr["ULTIMO_VALOR"] != DBNull.Value) r.ultimo_valor = decimal.Parse(dr["ULTIMO_VALOR"].ToString());
                            if (dr["ULTIMA_FECHA_UTC"] != DBNull.Value) r.ultima_fecha_utc = DateTime.Parse(dr["ULTIMA_FECHA_UTC"].ToString());
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
            }

            return r;
        }

        public ActivoVariable GetVariable(int id)
        {
            List<ActivoVariable> l = GetVariables(new ActivoVariable { ava_id = id });
            return (l != null && l.Count > 0) ? l[0] : new ActivoVariable();
        }

        public Respuesta Insert(ActivoVariable e)
        {
            return Ejecutar("INS_ACTIVO_VARIABLE", "Variable del equipo creada con éxito.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO", e.ava_activo);
                cmd.Parameters.AddWithValue("@ACTIVO_COMPONENTE", (object)e.ava_activo_componente ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VARIABLE_MEDICION", e.ava_variable_medicion);
                cmd.Parameters.AddWithValue("@UNIDAD_MEDIDA", (object)e.ava_unidad_medida ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VALOR_MINIMO", (object)e.ava_valor_minimo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VALOR_MAXIMO", (object)e.ava_valor_maximo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VALOR_ADVERTENCIA", (object)e.ava_valor_advertencia ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VALOR_CRITICO", (object)e.ava_valor_critico ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@FRECUENCIA_ESPERADA_HORA", (object)e.ava_frecuencia_esperada_hora ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, true);
        }

        public Respuesta Update(ActivoVariable e)
        {
            return Ejecutar("UPD_ACTIVO_VARIABLE", "Variable del equipo actualizada con éxito.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", e.ava_id);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@UNIDAD_MEDIDA", (object)e.ava_unidad_medida ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VALOR_MINIMO", (object)e.ava_valor_minimo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VALOR_MAXIMO", (object)e.ava_valor_maximo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VALOR_ADVERTENCIA", (object)e.ava_valor_advertencia ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VALOR_CRITICO", (object)e.ava_valor_critico ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@FRECUENCIA_ESPERADA_HORA", (object)e.ava_frecuencia_esperada_hora ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@HABILITADO", e.ava_habilitado);
                cmd.Parameters.AddWithValue("@QUITA_MINIMO", e.quita_minimo);
                cmd.Parameters.AddWithValue("@QUITA_MAXIMO", e.quita_maximo);
                cmd.Parameters.AddWithValue("@QUITA_ADVERTENCIA", e.quita_advertencia);
                cmd.Parameters.AddWithValue("@QUITA_CRITICO", e.quita_critico);
                cmd.Parameters.AddWithValue("@QUITA_FRECUENCIA", e.quita_frecuencia);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, false, e.ava_id);
        }

        public Respuesta Delete(int id)
        {
            return Ejecutar("DEL_ACTIVO_VARIABLE", "Variable deshabilitada.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", id);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, false, id);
        }

        private static Respuesta Ejecutar(string sp, string exito, Action<SqlCommand> parametros, bool conSalida, int id = 0)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand(sp);
                    parametros(cmd);
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    respuesta.codigo = conSalida ? (int)cmd.Parameters["@ID"].Value : id;
                    respuesta.detalle = exito;
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1; respuesta.detalle = ex.Message; respuesta.error = true;
                }
            }
            else
            {
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }
    }
}
