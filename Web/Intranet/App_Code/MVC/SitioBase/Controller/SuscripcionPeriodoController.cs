using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Períodos de cobro (ANEXO F §4.3).
    ///
    /// No hay Update ni Delete. Un período emitido es un cobro emitido: se
    /// cierra, se paga o queda impago, pero no se edita ni se borra. Lo que
    /// cambia su estado es la verificación de un pago, y eso lo hace
    /// SuscripcionPagoController en una transacción que también toca el
    /// período y la suscripción.
    /// </summary>
    public class SuscripcionPeriodoController
    {
        public List<SuscripcionPeriodo> GetPeriodos(SuscripcionPeriodo filtro = null)
        {
            List<SuscripcionPeriodo> lista = new List<SuscripcionPeriodo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_SUSCRIPCION_PERIODO";

                    if (filtro != null)
                    {
                        if (filtro.spe_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.spe_id);
                        if (filtro.filtro_suscripcion != null && filtro.filtro_suscripcion > 0)
                            cmd.Parameters.AddWithValue("@SUSCRIPCION", filtro.filtro_suscripcion);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0)
                            cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_estado != null && filtro.filtro_estado > 0)
                            cmd.Parameters.AddWithValue("@ESTADO", filtro.filtro_estado);
                        if (filtro.filtro_solo_impagos)
                            cmd.Parameters.AddWithValue("@SOLO_IMPAGOS", true);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            SuscripcionPeriodo item = new SuscripcionPeriodo();

                            item.spe_id = int.Parse(dr["SPE_ID"].ToString());
                            item.spe_suscripcion = int.Parse(dr["SPE_SUSCRIPCION"].ToString());
                            item.sus_cliente = int.Parse(dr["SUS_CLIENTE"].ToString());
                            item.cli_nombre = dr["CLI_NOMBRE"].ToString();

                            if (dr["SPE_PLAN_COMERCIAL"] != DBNull.Value)
                                item.spe_plan_comercial = int.Parse(dr["SPE_PLAN_COMERCIAL"].ToString());

                            item.plc_nombre = dr["PLC_NOMBRE"].ToString();
                            item.pcb_nombre = dr["PCB_NOMBRE"].ToString();
                            item.spe_fecha_inicio = DateTime.Parse(dr["SPE_FECHA_INICIO"].ToString());
                            item.spe_fecha_fin = DateTime.Parse(dr["SPE_FECHA_FIN"].ToString());
                            item.spe_valor_uf_plan = decimal.Parse(dr["SPE_VALOR_UF_PLAN"].ToString());
                            item.spe_valor_uf_dia = decimal.Parse(dr["SPE_VALOR_UF_DIA"].ToString());

                            if (dr["SPE_FECHA_VALOR_UF"] != DBNull.Value)
                                item.spe_fecha_valor_uf = DateTime.Parse(dr["SPE_FECHA_VALOR_UF"].ToString());

                            item.spe_monto_clp = decimal.Parse(dr["SPE_MONTO_CLP"].ToString());
                            item.spe_monto_pagado_clp = decimal.Parse(dr["SPE_MONTO_PAGADO_CLP"].ToString());
                            item.saldo_clp = decimal.Parse(dr["SALDO_CLP"].ToString());
                            item.spe_estado = int.Parse(dr["SPE_ESTADO"].ToString());
                            item.spd_nombre = dr["SPD_NOMBRE"].ToString();
                            item.spe_es_implantacion = bool.Parse(dr["SPE_ES_IMPLANTACION"].ToString());
                            item.spe_observacion = dr["SPE_OBSERVACION"].ToString();
                            item.spe_habilitado = bool.Parse(dr["SPE_HABILITADO"].ToString());

                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public SuscripcionPeriodo GetPeriodo(SuscripcionPeriodo entidad)
        {
            List<SuscripcionPeriodo> lista = GetPeriodos(new SuscripcionPeriodo { spe_id = entidad.spe_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new SuscripcionPeriodo();
        }

        /// <summary>
        /// Emitir un período ES facturar: acá se congelan los tres números
        /// (§4.3). No se pasa fecha de inicio a propósito — el SP la
        /// calcula continuando donde terminó el período anterior, de modo
        /// que pagar con tres días de atraso no regale ni quite días.
        ///
        /// valor_uf_manual solo viaja si viene con valor. Es lo que permite
        /// cobrar una implantación acordada; sin él, una implantación se
        /// emite en cero, porque no hay precio definido y facturar un
        /// número que nadie acordó es peor que facturar cero.
        /// </summary>
        public Respuesta EmitirPeriodo(SuscripcionPeriodo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_SUSCRIPCION_PERIODO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@SUSCRIPCION", entidad.spe_suscripcion);
                    cmdExecute.Parameters.AddWithValue("@PERIODICIDAD", entidad.spe_periodicidad_cobro);
                    cmdExecute.Parameters.AddWithValue("@PLAN_COMERCIAL", (object)entidad.spe_plan_comercial ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ES_IMPLANTACION", entidad.spe_es_implantacion);
                    cmdExecute.Parameters.AddWithValue("@VALOR_UF_MANUAL", (object)entidad.valor_uf_manual ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", (object)entidad.spe_observacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Período emitido con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }
    }
}
