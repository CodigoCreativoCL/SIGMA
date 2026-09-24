using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Reflection;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Lectura por nombre de columna, sin escribir un dr["X"] por propiedad.
    /// El mapa columna -> propiedad se arma una vez por consulta; DBNull queda
    /// como null y los tipos se convierten al de la propiedad. Es lo mismo que
    /// hace Datos.Listar en la API; aqui vive para los controladores nuevos
    /// del Sprint 5, que tienen 40 columnas cada uno.
    /// </summary>
    internal static class Sql
    {
        public static List<T> Listar<T>(string sp, Action<SqlCommand> parametros) where T : new()
        {
            List<T> lista = new List<T>();
            if (!Token.TokenSeguridad()) return null;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = sp;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                if (parametros != null) parametros(cmd);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    Dictionary<string, PropertyInfo> mapa = new Dictionary<string, PropertyInfo>(StringComparer.OrdinalIgnoreCase);
                    foreach (PropertyInfo p in typeof(T).GetProperties()) mapa[p.Name] = p;

                    int n = dr.FieldCount;
                    PropertyInfo[] cols = new PropertyInfo[n];
                    for (int i = 0; i < n; i++) { PropertyInfo p; cols[i] = mapa.TryGetValue(dr.GetName(i), out p) ? p : null; }

                    while (dr.Read())
                    {
                        T item = new T();
                        for (int i = 0; i < n; i++)
                        {
                            if (cols[i] == null || dr.IsDBNull(i)) continue;
                            Type t = Nullable.GetUnderlyingType(cols[i].PropertyType) ?? cols[i].PropertyType;
                            object v = dr.GetValue(i);
                            try { cols[i].SetValue(item, t == typeof(Guid) ? (object)(Guid)v : Convert.ChangeType(v, t), null); }
                            catch { }
                        }
                        lista.Add(item);
                    }
                }
                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                lista = null;
            }
            return lista;
        }

        /// <summary>INS/UPD/DEL: la sesion se valida antes, el SP decide, sin sesion NO se finge exito.</summary>
        public static Respuesta Ejecutar(string sp, string exito, Action<SqlCommand> parametros, bool conSalida, int id = 0)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad())
            {
                r.codigo = -1; r.error = true; r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                return r;
            }
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand(sp);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                if (conSalida) cmd.Parameters.AddWithValue("@ID", 0).Direction = ParameterDirection.Output;
                parametros(cmd);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
                r.codigo = conSalida ? (cmd.Parameters["@ID"].Value == DBNull.Value ? 0 : (int)cmd.Parameters["@ID"].Value) : id;
                r.detalle = exito; r.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                r.codigo = -1; r.detalle = ex.Message; r.error = true;
            }
            return r;
        }

        public static object N(object v) { return v ?? DBNull.Value; }
    }

    public class OrdenTrabajoController
    {
        public List<OrdenTrabajo> GetOrdenes(OrdenTrabajo f)
        {
            return Sql.Listar<OrdenTrabajo>("SEL_ORDEN_TRABAJO", cmd =>
            {
                if (f == null) return;
                if (f.otr_id > 0) cmd.Parameters.AddWithValue("@ID", f.otr_id);
                if (f.filtro_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", f.filtro_instalacion);
                if (f.filtro_estado > 0) cmd.Parameters.AddWithValue("@ESTADO", f.filtro_estado);
                if (f.filtro_tipo > 0) cmd.Parameters.AddWithValue("@TIPO", f.filtro_tipo);
                if (f.filtro_origen > 0) cmd.Parameters.AddWithValue("@ORIGEN", f.filtro_origen);
                if (f.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", f.filtro_activo);
                if (f.filtro_falla > 0) cmd.Parameters.AddWithValue("@FALLA", f.filtro_falla);
                if (f.filtro_desde != null) cmd.Parameters.AddWithValue("@DESDE", f.filtro_desde.Value.Date);
                if (f.filtro_hasta != null) cmd.Parameters.AddWithValue("@HASTA", f.filtro_hasta.Value.Date);
                if (!string.IsNullOrEmpty(f.filtro)) cmd.Parameters.AddWithValue("@FILTRO", f.filtro);
            });
        }

        public OrdenTrabajo GetOrden(int id)
        {
            List<OrdenTrabajo> l = GetOrdenes(new OrdenTrabajo { otr_id = id });
            return (l != null && l.Count > 0) ? l[0] : new OrdenTrabajo();
        }

        public Respuesta Insert(OrdenTrabajo e)
        {
            return Sql.Ejecutar("INS_ORDEN_TRABAJO", "Orden de trabajo creada con éxito.", cmd =>
            {
                cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", e.otr_cliente_instalacion > 0 ? (object)e.otr_cliente_instalacion : DBNull.Value);
                cmd.Parameters.AddWithValue("@INSTALACION_AREA", Sql.N(e.otr_instalacion_area));
                cmd.Parameters.AddWithValue("@ACTIVO", Sql.N(e.otr_activo));
                cmd.Parameters.AddWithValue("@ACTIVO_COMPONENTE", Sql.N(e.otr_activo_componente));
                cmd.Parameters.AddWithValue("@TIPO", e.otr_orden_trabajo_tipo);
                cmd.Parameters.AddWithValue("@ESTRATEGIA", e.otr_orden_trabajo_estrategia);
                cmd.Parameters.AddWithValue("@PRIORIDAD", e.otr_orden_trabajo_prioridad);
                cmd.Parameters.AddWithValue("@TITULO", e.otr_titulo);
                cmd.Parameters.AddWithValue("@DESCRIPCION", Sql.N(e.otr_descripcion));
                cmd.Parameters.AddWithValue("@FECHA_PROGRAMADA_UTC", Sql.N(e.otr_fecha_programada_utc));
                cmd.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", Sql.N(e.otr_duracion_estimada_minuto));
                cmd.Parameters.AddWithValue("@REQUIERE_PERMISO", e.otr_requiere_permiso);
                cmd.Parameters.AddWithValue("@REGISTRO_POSTERIOR", e.otr_registro_posterior);
                cmd.Parameters.AddWithValue("@FECHA_OCURRENCIA", Sql.N(e.otr_fecha_ocurrencia));
                cmd.Parameters.AddWithValue("@FALLA", Sql.N(e.otr_falla));
            }, true);
        }

        public Respuesta Update(OrdenTrabajo e)
        {
            return Sql.Ejecutar("UPD_ORDEN_TRABAJO", "Orden de trabajo actualizada.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", e.otr_id);
                cmd.Parameters.AddWithValue("@TITULO", e.otr_titulo);
                cmd.Parameters.AddWithValue("@DESCRIPCION", Sql.N(e.otr_descripcion));
                cmd.Parameters.AddWithValue("@PRIORIDAD", e.otr_orden_trabajo_prioridad);
                cmd.Parameters.AddWithValue("@ESTRATEGIA", e.otr_orden_trabajo_estrategia);
                cmd.Parameters.AddWithValue("@FECHA_PROGRAMADA_UTC", Sql.N(e.otr_fecha_programada_utc));
                cmd.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", Sql.N(e.otr_duracion_estimada_minuto));
                cmd.Parameters.AddWithValue("@REQUIERE_PERMISO", e.otr_requiere_permiso);
                cmd.Parameters.AddWithValue("@NOTAS", Sql.N(e.otr_notas));
                cmd.Parameters.AddWithValue("@QUITA_FECHA", e.quita_fecha);
                cmd.Parameters.AddWithValue("@QUITA_DURACION", e.quita_duracion);
            }, false, e.otr_id);
        }

        /// <summary>HU-120/122. El SP decide jerarquia, estado y resultado obligatorio.</summary>
        /// <summary>
        /// Le copia a la orden los pasos de un procedimiento (bloque 276).
        ///
        /// POR QUE HACIA FALTA
        ///   Una correctiva creada desde la web nace SIN pasos: INS_ORDEN_TRABAJO
        ///   no toca Orden_Trabajo_Paso. Los pasos venian solo del plan, de un
        ///   hallazgo o de lo que el tecnico agregaba en terreno, asi que quien
        ///   creaba la orden sabia lo que habia que hacer y no tenia donde
        ///   escribirlo.
        ///
        ///   El nombre y la instruccion se COPIAN. Si manana alguien edita el
        ///   procedimiento, la orden ya ejecutada sigue diciendo lo que se mando
        ///   a hacer ese dia.
        /// </summary>
        public Respuesta AgregarPasosDeProcedimiento(int orden, int procedimiento)
        {
            Respuesta r = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                r.codigo = -1;
                r.detalle = "La sesión no es válida o expiró. Vuelva a entrar y repita la operación.";
                r.error = true;
                return r;
            }

            if (orden <= 0 || procedimiento <= 0)
            {
                r.codigo = -1;
                r.detalle = "Elija el procedimiento cuyos pasos quiere agregar.";
                r.error = true;
                return r;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("INS_ORDEN_TRABAJO_PASO_PROCEDIMIENTO");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@ORDEN", orden);
                cmd.Parameters.AddWithValue("@PROCEDIMIENTO", procedimiento);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                int agregados = cmd.Parameters["@ID"].Value == DBNull.Value
                              ? 0 : (int)cmd.Parameters["@ID"].Value;

                r.codigo = agregados;
                r.error = false;
                r.detalle = agregados == 0
                    ? "La orden ya tenía los pasos de ese procedimiento."
                    : agregados + (agregados == 1 ? " paso agregado." : " pasos agregados.");
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                r.codigo = -1;
                r.detalle = ex.Message;
                r.error = true;
            }

            return r;
        }

        public Respuesta Cerrar(int orden, int motivo, string resultado)
        {
            return Sql.Ejecutar("UPD_ORDEN_TRABAJO_CERRAR_WEB", "Orden cerrada.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", orden);
                cmd.Parameters.AddWithValue("@CIERRE_MOTIVO", motivo);
                cmd.Parameters.AddWithValue("@RESULTADO", Sql.N(string.IsNullOrEmpty(resultado) ? null : resultado));
            }, false, orden);
        }

        public List<OrdenTrabajoAsignacion> GetAsignaciones(int orden)
        {
            return Sql.Listar<OrdenTrabajoAsignacion>("SEL_ORDEN_TRABAJO_ASIGNACION", cmd => cmd.Parameters.AddWithValue("@ORDEN", orden));
        }

        /// <summary>HU-112. Devuelve la advertencia de especialidad en detalle si la hubo.</summary>
        public Respuesta Asignar(OrdenTrabajoAsignacion a)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.codigo = -1; r.error = true; r.detalle = "La sesion no es valida o expiro."; return r; }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("INS_ORDEN_TRABAJO_ASIGNACION");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ORDEN", a.ota_orden_trabajo);
                cmd.Parameters.AddWithValue("@USUARIO_ASIG", Sql.N(a.ota_usuario));
                cmd.Parameters.AddWithValue("@PROVEEDOR", Sql.N(a.ota_proveedor));
                cmd.Parameters.AddWithValue("@GRUPO_TRABAJO", Sql.N(a.ota_grupo_trabajo));
                cmd.Parameters.AddWithValue("@ES_RESPONSABLE", a.ota_es_responsable);
                cmd.Parameters.AddWithValue("@ROL_EJECUCION", Sql.N(a.ota_rol_ejecucion));
                cmd.Parameters.AddWithValue("@OBSERVACION", Sql.N(a.ota_observacion));
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                string advertencia = null; int id = 0;
                using (SqlDataReader dr = cmd.ExecuteReader())
                    if (dr.Read()) { id = int.Parse(dr["OTA_ID"].ToString()); if (dr["ADVERTENCIA"] != DBNull.Value) advertencia = dr["ADVERTENCIA"].ToString(); }
                cmd.Connection.Close();

                r.codigo = id;
                r.detalle = advertencia == null ? "Asignación registrada." : "Asignación registrada con advertencia: " + advertencia;
                r.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                r.codigo = -1; r.detalle = ex.Message; r.error = true;
            }
            return r;
        }

        public Respuesta QuitarAsignacion(int id)
        {
            return Sql.Ejecutar("DEL_ORDEN_TRABAJO_ASIGNACION", "Asignación quitada.", cmd => cmd.Parameters.AddWithValue("@ID", id), false, id);
        }
    }

    public class FallaController
    {
        public List<Falla> GetFallas(Falla f)
        {
            return Sql.Listar<Falla>("SEL_FALLA", cmd =>
            {
                if (f == null) return;
                if (f.fal_id > 0) cmd.Parameters.AddWithValue("@ID", f.fal_id);
                if (f.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", f.filtro_activo);
                if (f.filtro_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", f.filtro_instalacion);
                if (f.filtro_abiertas != null) cmd.Parameters.AddWithValue("@ABIERTAS", f.filtro_abiertas);
                if (!string.IsNullOrEmpty(f.filtro)) cmd.Parameters.AddWithValue("@FILTRO", f.filtro);
            });
        }

        public Falla GetFalla(int id)
        {
            List<Falla> l = GetFallas(new Falla { fal_id = id });
            return (l != null && l.Count > 0) ? l[0] : new Falla();
        }

        public Respuesta Insert(Falla e)
        {
            return Sql.Ejecutar("INS_FALLA", "Falla registrada.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ACTIVO", e.fal_activo);
                cmd.Parameters.AddWithValue("@ACTIVO_COMPONENTE", Sql.N(e.fal_activo_componente));
                cmd.Parameters.AddWithValue("@FALLA_SINTOMA", Sql.N(e.fal_falla_sintoma));
                cmd.Parameters.AddWithValue("@CRITICIDAD_NIVEL", e.fal_criticidad_nivel);
                cmd.Parameters.AddWithValue("@TITULO", e.fal_titulo);
                cmd.Parameters.AddWithValue("@DESCRIPCION", Sql.N(e.fal_descripcion));
                cmd.Parameters.AddWithValue("@CONSECUENCIA", Sql.N(e.fal_consecuencia));
                cmd.Parameters.AddWithValue("@ESTADO_POSTERIOR", Sql.N(e.fal_activo_estado_posterior));
                cmd.Parameters.AddWithValue("@DETUVO_PRODUCCION", e.fal_detuvo_produccion);
                cmd.Parameters.AddWithValue("@FECHA_DETECCION_UTC", Sql.N(e.fal_fecha_deteccion_utc));
            }, true);
        }

        public Respuesta Update(Falla e)
        {
            return Sql.Ejecutar("UPD_FALLA", "Falla actualizada.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", e.fal_id);
                cmd.Parameters.AddWithValue("@TITULO", e.fal_titulo);
                cmd.Parameters.AddWithValue("@DESCRIPCION", Sql.N(e.fal_descripcion));
                cmd.Parameters.AddWithValue("@CONSECUENCIA", Sql.N(e.fal_consecuencia));
                cmd.Parameters.AddWithValue("@CRITICIDAD_NIVEL", e.fal_criticidad_nivel);
                cmd.Parameters.AddWithValue("@DETUVO_PRODUCCION", e.fal_detuvo_produccion);
                cmd.Parameters.AddWithValue("@FECHA_SOLUCION_UTC", Sql.N(e.fal_fecha_solucion_utc));
                cmd.Parameters.AddWithValue("@QUITA_SOLUCION", e.quita_solucion);
            }, false, e.fal_id);
        }

        public List<FallaDiagnostico> GetDiagnosticos(int falla)
        {
            return Sql.Listar<FallaDiagnostico>("SEL_FALLA_DIAGNOSTICO", cmd => cmd.Parameters.AddWithValue("@FALLA", falla));
        }

        public Respuesta InsertDiagnostico(FallaDiagnostico d)
        {
            return Sql.Ejecutar("INS_FALLA_DIAGNOSTICO", "Diagnóstico registrado.", cmd =>
            {
                cmd.Parameters.AddWithValue("@FALLA", d.fdi_falla);
                cmd.Parameters.AddWithValue("@FALLA_MODO", Sql.N(d.fdi_falla_modo));
                cmd.Parameters.AddWithValue("@FALLA_CAUSA", Sql.N(d.fdi_falla_causa));
                cmd.Parameters.AddWithValue("@DIAGNOSTICO_METODO", Sql.N(d.fdi_diagnostico_metodo));
                cmd.Parameters.AddWithValue("@DESCRIPCION", d.fdi_descripcion ?? "");
                cmd.Parameters.AddWithValue("@ES_DEFINITIVO", d.fdi_es_definitivo);
                cmd.Parameters.AddWithValue("@CONFIANZA", Sql.N(d.fdi_confianza));
            }, true);
        }

        public List<FallaAccion> GetAcciones(int falla)
        {
            return Sql.Listar<FallaAccion>("SEL_FALLA_ACCION", cmd => cmd.Parameters.AddWithValue("@FALLA", falla));
        }

        public Respuesta InsertAccion(FallaAccion a)
        {
            return Sql.Ejecutar("INS_FALLA_ACCION", a.fac_es_definitiva ? "Acción definitiva registrada; la falla queda resuelta." : "Acción provisoria registrada.", cmd =>
            {
                cmd.Parameters.AddWithValue("@FALLA", a.fac_falla);
                cmd.Parameters.AddWithValue("@FALLA_DIAGNOSTICO", Sql.N(a.fac_falla_diagnostico));
                cmd.Parameters.AddWithValue("@ORDEN_TRABAJO", Sql.N(a.fac_orden_trabajo));
                cmd.Parameters.AddWithValue("@DESCRIPCION", a.fac_descripcion ?? "");
                cmd.Parameters.AddWithValue("@ES_DEFINITIVA", a.fac_es_definitiva);
                cmd.Parameters.AddWithValue("@FECHA_ACCION_UTC", Sql.N(a.fac_fecha_accion_utc));
            }, true);
        }
    }

    public class IndisponibilidadController
    {
        public List<ActivoIndisponibilidad> Get(ActivoIndisponibilidad f)
        {
            return Sql.Listar<ActivoIndisponibilidad>("SEL_ACTIVO_INDISPONIBILIDAD", cmd =>
            {
                if (f == null) return;
                if (f.ain_id > 0) cmd.Parameters.AddWithValue("@ID", f.ain_id);
                if (f.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", f.filtro_activo);
                if (f.filtro_orden > 0) cmd.Parameters.AddWithValue("@ORDEN", f.filtro_orden);
                if (f.filtro_falla > 0) cmd.Parameters.AddWithValue("@FALLA", f.filtro_falla);
                if (f.filtro_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", f.filtro_instalacion);
            });
        }

        public ActivoIndisponibilidad GetUna(int id)
        {
            List<ActivoIndisponibilidad> l = Get(new ActivoIndisponibilidad { ain_id = id });
            return (l != null && l.Count > 0) ? l[0] : new ActivoIndisponibilidad();
        }

        public Respuesta Insert(ActivoIndisponibilidad e)
        {
            return Sql.Ejecutar("INS_ACTIVO_INDISPONIBILIDAD", "Indisponibilidad registrada.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ACTIVO", e.ain_activo);
                cmd.Parameters.AddWithValue("@ORDEN_TRABAJO", Sql.N(e.ain_orden_trabajo));
                cmd.Parameters.AddWithValue("@FALLA", Sql.N(e.ain_falla));
                cmd.Parameters.AddWithValue("@FECHA_INICIO_UTC", e.ain_fecha_inicio_utc);
                cmd.Parameters.AddWithValue("@FECHA_FIN_UTC", Sql.N(e.ain_fecha_fin_utc));
                cmd.Parameters.AddWithValue("@PLANIFICADA", e.ain_planificada);
                cmd.Parameters.AddWithValue("@DETUVO_PRODUCCION", e.ain_detuvo_produccion);
                cmd.Parameters.AddWithValue("@MOTIVO_CATALOGO", Sql.N(e.ain_indisponibilidad_motivo));
                cmd.Parameters.AddWithValue("@MOTIVO", Sql.N(e.ain_motivo));
            }, true);
        }

        public Respuesta Update(ActivoIndisponibilidad e)
        {
            return Sql.Ejecutar("UPD_ACTIVO_INDISPONIBILIDAD", "Indisponibilidad actualizada.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", e.ain_id);
                cmd.Parameters.AddWithValue("@FECHA_FIN_UTC", Sql.N(e.ain_fecha_fin_utc));
                cmd.Parameters.AddWithValue("@PLANIFICADA", e.ain_planificada);
                cmd.Parameters.AddWithValue("@DETUVO_PRODUCCION", e.ain_detuvo_produccion);
                cmd.Parameters.AddWithValue("@MOTIVO_CATALOGO", Sql.N(e.ain_indisponibilidad_motivo));
                cmd.Parameters.AddWithValue("@MOTIVO", Sql.N(e.ain_motivo));
                cmd.Parameters.AddWithValue("@HABILITADO", e.ain_habilitado);
            }, false, e.ain_id);
        }
    }
}
