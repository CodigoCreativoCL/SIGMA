using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Equipos de un plan de mantenimiento (HU-083). El cliente viaja en
    /// @CLIENTE y el SP lo cruza a traves del plan.
    /// </summary>
    public class PlanActivoController
    {
        public List<PlanActivo> GetPlanActivos(PlanActivo filtro = null)
        {
            List<PlanActivo> lista = new List<PlanActivo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_ACTIVO";

                    if (filtro != null)
                    {
                        if (filtro.pac_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.pac_id);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_plan != null && filtro.filtro_plan > 0) cmd.Parameters.AddWithValue("@PLAN", filtro.filtro_plan);
                        if (filtro.filtro_version != null && filtro.filtro_version > 0) cmd.Parameters.AddWithValue("@VERSION", filtro.filtro_version);
                        if (filtro.filtro_activo != null && filtro.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", filtro.filtro_activo);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanActivo item = new PlanActivo();

                            item.pac_id = int.Parse(dr["PAC_ID"].ToString());
                            item.pac_plan_mantenimiento_version = int.Parse(dr["PAC_PLAN_MANTENIMIENTO_VERSION"].ToString());
                            item.pac_activo = int.Parse(dr["PAC_ACTIVO"].ToString());
                            if (dr["PAC_ACTIVO_COMPONENTE"] != DBNull.Value)
                                item.pac_activo_componente = int.Parse(dr["PAC_ACTIVO_COMPONENTE"].ToString());
                            if (dr["PAC_ACTIVO_MEDIDOR"] != DBNull.Value)
                                item.pac_activo_medidor = int.Parse(dr["PAC_ACTIVO_MEDIDOR"].ToString());
                            item.pac_usuario_creacion = int.Parse(dr["PAC_USUARIO_CREACION"].ToString());
                            if (dr["PAC_FECHA_CREACION"] != DBNull.Value)
                                item.pac_fecha_creacion = DateTime.Parse(dr["PAC_FECHA_CREACION"].ToString());

                            item.plan_id = int.Parse(dr["PLAN_ID"].ToString());
                            item.plan_cliente = int.Parse(dr["PLAN_CLIENTE"].ToString());
                            item.plan_codigo = dr["PLAN_CODIGO"].ToString();
                            item.plan_nombre = dr["PLAN_NOMBRE"].ToString();
                            if (dr["VERSION_NUMERO"] != DBNull.Value)
                                item.version_numero = int.Parse(dr["VERSION_NUMERO"].ToString());
                            item.version_estado_codigo = dr["VERSION_ESTADO_CODIGO"].ToString();
                            item.version_estado_nombre = dr["VERSION_ESTADO_NOMBRE"].ToString();
                            item.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            item.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            item.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            item.area_nombre = dr["AREA_NOMBRE"].ToString();
                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            item.estado_activo_nombre = dr["ESTADO_ACTIVO_NOMBRE"].ToString();
                            item.componente_codigo = dr["COMPONENTE_CODIGO"].ToString();
                            item.componente_nombre = dr["COMPONENTE_NOMBRE"].ToString();
                            item.medidor_codigo = dr["MEDIDOR_CODIGO"].ToString();
                            item.medidor_nombre = dr["MEDIDOR_NOMBRE"].ToString();
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();

                            lista.Add(item);
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

        /// <summary>
        /// Los otros planes VIGENTES que ya cubren a este equipo (HU-083 #3).
        ///
        /// Se consulta al elegir el equipo, que es cuando el dato sirve para
        /// decidir, y no al apretar Guardar, que es cuando ya se decidio.
        /// Devuelve lista vacia cuando no hay ninguno, que es lo normal.
        /// </summary>
        public List<PlanCobertura> GetCobertura(int activo, int plan)
        {
            List<PlanCobertura> lista = new List<PlanCobertura>();

            if (activo <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_PLAN_ACTIVO_COBERTURA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO", activo);
                if (plan > 0) cmd.Parameters.AddWithValue("@PLAN", plan);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        PlanCobertura item = new PlanCobertura();

                        item.plan_id = int.Parse(dr["PLAN_ID"].ToString());
                        item.plan_codigo = dr["PLAN_CODIGO"].ToString();
                        item.plan_nombre = dr["PLAN_NOMBRE"].ToString();
                        item.version_id = int.Parse(dr["VERSION_ID"].ToString());
                        if (dr["VERSION_NUMERO"] != DBNull.Value)
                            item.version_numero = int.Parse(dr["VERSION_NUMERO"].ToString());
                        item.version_estado_codigo = dr["VERSION_ESTADO_CODIGO"].ToString();
                        item.version_estado_nombre = dr["VERSION_ESTADO_NOMBRE"].ToString();
                        item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                        item.hitos = int.Parse(dr["HITOS"].ToString());
                        item.mismo_tipo = dr["MISMO_TIPO"].ToString() == "1";
                        item.ocurrencias_abiertas = int.Parse(dr["OCURRENCIAS_ABIERTAS"].ToString());

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
                /* Lista vacia y no null: el aviso es una ayuda, y si la
                   consulta falla lo correcto es no avisar, no impedir
                   guardar. */
                lista = new List<PlanCobertura>();
            }

            return lista;
        }

        public PlanActivo GetPlanActivo(PlanActivo entidad)
        {
            List<PlanActivo> lista = GetPlanActivos(new PlanActivo { pac_id = entidad.pac_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new PlanActivo();
        }

        public Respuesta InsertPlanActivo(PlanActivo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_PLAN_ACTIVO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@PLAN", entidad.plan_id);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO", entidad.pac_activo);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_COMPONENTE", (object)entidad.pac_activo_componente ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_MEDIDOR", (object)entidad.pac_activo_medidor ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Equipo asociado al plan con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
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

        public Respuesta UpdatePlanActivo(PlanActivo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_PLAN_ACTIVO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.pac_id);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_COMPONENTE", (object)entidad.pac_activo_componente ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_MEDIDOR", (object)entidad.pac_activo_medidor ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@QUITA_COMPONENTE", entidad.quita_componente);
                    cmdExecute.Parameters.AddWithValue("@QUITA_MEDIDOR", entidad.quita_medidor);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.pac_id;
                    respuesta.detalle = "Vínculo actualizado con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
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

        public Respuesta DeletePlanActivo(PlanActivo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PLAN_ACTIVO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.pac_id);
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.pac_id;
                    respuesta.detalle = "Equipo quitado del plan con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
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
