using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Consultas de lectura propias del centro Planificación 360. Todas se
    /// acotan al cliente de la sesión; ninguna escribe.
    /// </summary>
    public class Planificacion360Controller
    {
        private static int? Entero(object v) { return v == DBNull.Value ? (int?)null : Convert.ToInt32(v); }

        public List<PlanificacionActividad> GetActividad(int? instalacion, DateTime desde, int top)
        {
            List<PlanificacionActividad> lista = new List<PlanificacionActividad>();
            if (!Token.TokenSeguridad()) return lista;
            SqlCommand cmd = new SqlCommand("SEL_PLANIFICACION_ACTIVIDAD");
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId()); cmd.Parameters.AddWithValue("@DESDE", desde);
            cmd.Parameters.AddWithValue("@TOP", top);
            if (instalacion != null && instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", instalacion.Value);
            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                while (dr.Read()) lista.Add(new PlanificacionActividad {
                    orden_id = Convert.ToInt32(dr["ORDEN_ID"]), orden_correlativo = Convert.ToInt32(dr["ORDEN_CORRELATIVO"]),
                    activo_codigo = dr["ACTIVO_CODIGO"].ToString(), activo_nombre = dr["ACTIVO_NOMBRE"].ToString(),
                    hito_nombre = dr["HITO_NOMBRE"].ToString(), fecha = Convert.ToDateTime(dr["FECHA"]),
                    estado_codigo = dr["ESTADO_CODIGO"].ToString(), estado_nombre = dr["ESTADO_NOMBRE"].ToString() });
            cmd.Connection.Close(); cmd.Dispose(); return lista;
        }

        public List<PlanificacionCobertura> GetCobertura(int? instalacion, bool duplicados, int? tipo = null, int? area = null, int? criticidad = null)
        {
            List<PlanificacionCobertura> lista = new List<PlanificacionCobertura>();
            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand("SEL_PLANIFICACION_COBERTURA");
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            if (instalacion != null && instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", instalacion.Value);
            cmd.Parameters.AddWithValue("@DUPLICADOS", duplicados);
            if (tipo != null && tipo > 0) cmd.Parameters.AddWithValue("@TIPO", tipo.Value);
            if (area != null && area > 0) cmd.Parameters.AddWithValue("@AREA", area.Value);
            if (criticidad != null && criticidad > 0) cmd.Parameters.AddWithValue("@CRITICIDAD", criticidad.Value);
            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    lista.Add(new PlanificacionCobertura {
                        activo_id = Convert.ToInt32(dr["ACTIVO_ID"]), activo_codigo = dr["ACTIVO_CODIGO"].ToString(),
                        activo_nombre = dr["ACTIVO_NOMBRE"].ToString(),
                        tipo_id = Entero(dr["TIPO_ID"]), tipo_nombre = dr["TIPO_NOMBRE"].ToString(),
                        planta_nombre = dr["PLANTA_NOMBRE"].ToString(),
                        area_id = Entero(dr["AREA_ID"]), area_nombre = dr["AREA_NOMBRE"].ToString(),
                        criticidad_id = Entero(dr["CRITICIDAD_ID"]), criticidad_codigo = dr["CRITICIDAD_CODIGO"].ToString(),
                        criticidad_nombre = dr["CRITICIDAD_NOMBRE"].ToString(),
                        planes = Convert.ToInt32(dr["PLANES"]), planes_nombres = dr["PLANES_NOMBRES"].ToString()
                    });
                }
            }
            cmd.Connection.Close(); cmd.Dispose();
            return lista;
        }

        public PlanificacionCoberturaResumen GetCoberturaResumen(int? instalacion)
        {
            PlanificacionCoberturaResumen r = new PlanificacionCoberturaResumen();
            if (!Token.TokenSeguridad()) return r;
            SqlCommand cmd = new SqlCommand("SEL_PLANIFICACION_COBERTURA_RESUMEN");
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            if (instalacion != null && instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", instalacion.Value);
            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                if (dr.Read())
                {
                    r.habilitados = Entero(dr["HABILITADOS"]) ?? 0; r.cubiertos = Entero(dr["CUBIERTOS"]) ?? 0;
                    r.sin_plan = Entero(dr["SIN_PLAN"]) ?? 0; r.varios = Entero(dr["VARIOS"]) ?? 0;
                }
            }
            cmd.Connection.Close(); cmd.Dispose();
            return r;
        }

        public List<PlanificacionProgramacionUso> GetUsosProgramacion()
        {
            List<PlanificacionProgramacionUso> lista = new List<PlanificacionProgramacionUso>();
            if (!Token.TokenSeguridad()) return lista;
            SqlCommand cmd = new SqlCommand("SEL_PLANIFICACION_PROGRAMACION_USO");
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read()) lista.Add(new PlanificacionProgramacionUso {
                    programacion_id = Convert.ToInt32(dr["PROGRAMACION_ID"]), origen = dr["ORIGEN"].ToString(),
                    id = Convert.ToInt32(dr["ID"]), codigo = dr["CODIGO"].ToString(), nombre = dr["NOMBRE"].ToString()
                });
            }
            cmd.Connection.Close(); cmd.Dispose();
            return lista;
        }

        public List<PlanificacionCumplimientoEquipo> GetCumplimientoEquipos(int? instalacion, DateTime desde, DateTime hasta)
        {
            List<PlanificacionCumplimientoEquipo> lista = new List<PlanificacionCumplimientoEquipo>();
            if (!Token.TokenSeguridad()) return lista;
            SqlCommand cmd = new SqlCommand("SEL_PLANIFICACION_CUMPLIMIENTO_EQUIPO");
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            cmd.Parameters.AddWithValue("@DESDE", desde.Date); cmd.Parameters.AddWithValue("@HASTA", hasta.Date);
            if (instalacion != null && instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", instalacion.Value);
            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read()) lista.Add(new PlanificacionCumplimientoEquipo {
                    activo_id = Convert.ToInt32(dr["ACTIVO_ID"]), activo_codigo = dr["ACTIVO_CODIGO"].ToString(),
                    activo_nombre = dr["ACTIVO_NOMBRE"].ToString(), planta_nombre = dr["PLANTA_NOMBRE"].ToString(),
                    programadas = Convert.ToInt32(dr["PROGRAMADAS"]), cumplidas = Convert.ToInt32(dr["CUMPLIDAS"]),
                    a_tiempo = Convert.ToInt32(dr["A_TIEMPO"]), reprogramadas = Convert.ToInt32(dr["REPROGRAMADAS"]),
                    a_tiempo_vigente = Convert.ToInt32(dr["A_TIEMPO_VIGENTE"]), vencidas = Convert.ToInt32(dr["VENCIDAS"]),
                    atrasadas = Convert.ToInt32(dr["ATRASADAS"]), omitidas = Convert.ToInt32(dr["OMITIDAS"]),
                    cumplimiento = dr["CUMPLIMIENTO"] == DBNull.Value ? 0 : Convert.ToDecimal(dr["CUMPLIMIENTO"])
                });
            }
            cmd.Connection.Close(); cmd.Dispose();
            return lista;
        }

        public Dictionary<int, PlanificacionHitoRequisito> GetHitoRequisitos()
        {
            Dictionary<int, PlanificacionHitoRequisito> mapa = new Dictionary<int, PlanificacionHitoRequisito>();
            if (!Token.TokenSeguridad()) return mapa;
            SqlCommand cmd = new SqlCommand("SEL_PLANIFICACION_HITO_REQUISITO");
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    PlanificacionHitoRequisito r = new PlanificacionHitoRequisito {
                        hito_id = Convert.ToInt32(dr["HITO_ID"]), personas = Convert.ToInt32(dr["PERSONAS"]),
                        repuestos = Convert.ToInt32(dr["REPUESTOS"]),
                        repuesto_principal = dr["REPUESTO_PRINCIPAL"] == DBNull.Value ? null : dr["REPUESTO_PRINCIPAL"].ToString(),
                        permiso = Convert.ToBoolean(dr["PERMISO"]) };
                    mapa[r.hito_id] = r;
                }
            }
            cmd.Connection.Close(); cmd.Dispose();
            return mapa;
        }

        public List<PlanificacionBorrador> GetBorradores(int? instalacion)
        {
            List<PlanificacionBorrador> lista = new List<PlanificacionBorrador>();
            if (!Token.TokenSeguridad()) return lista;
            SqlCommand cmd = new SqlCommand("SEL_PLANIFICACION_BORRADOR");
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            if (instalacion != null && instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", instalacion.Value);
            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read()) lista.Add(new PlanificacionBorrador {
                    plan_id = Convert.ToInt32(dr["PLAN_ID"]), codigo = dr["CODIGO"].ToString(), nombre = dr["NOMBRE"].ToString(),
                    familia = dr["FAMILIA"] == DBNull.Value ? "" : dr["FAMILIA"].ToString(),
                    version_numero = Convert.ToInt32(dr["VERSION_NUMERO"]), cambios = Convert.ToInt32(dr["CAMBIOS"]),
                    ultima_edicion = Convert.ToDateTime(dr["ULTIMA_EDICION"]), responsable = dr["RESPONSABLE"].ToString() });
            }
            cmd.Connection.Close(); cmd.Dispose();
            return lista;
        }
    }
}
