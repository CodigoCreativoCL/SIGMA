using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Pagos declarados sobre un período (ANEXO F §5.3 y §5.4).
    ///
    /// DECLARAR Y VERIFICAR SON DOS COSAS
    ///   Quien declara es el cliente: dice que transfirió y adjunta el
    ///   comprobante. Quien verifica es SIGMA, cotejando contra la cartola.
    ///   Recién ahí el período se da por cubierto y la suscripción se
    ///   extiende. Están separados en dos métodos y detrás de dos permisos
    ///   distintos porque si fueran uno, el cliente se verificaría solo.
    ///
    /// EL COMPROBANTE ES OBLIGATORIO
    ///   spa_archivo es NOT NULL y el SP lo valida. No es un descuido de la
    ///   tabla: sin respaldo no hay nada que cotejar, y sin cotejo la
    ///   declaración nunca se convierte en pago.
    /// </summary>
    public class SuscripcionPagoController
    {
        public List<SuscripcionPago> GetPagos(SuscripcionPago filtro = null)
        {
            List<SuscripcionPago> lista = new List<SuscripcionPago>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_SUSCRIPCION_PAGO";

                    if (filtro != null)
                    {
                        if (filtro.spa_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.spa_id);
                        if (filtro.filtro_periodo != null && filtro.filtro_periodo > 0)
                            cmd.Parameters.AddWithValue("@PERIODO", filtro.filtro_periodo);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0)
                            cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_solo_pendientes)
                            cmd.Parameters.AddWithValue("@SOLO_PENDIENTES", true);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            SuscripcionPago item = new SuscripcionPago();

                            item.spa_id = int.Parse(dr["SPA_ID"].ToString());
                            item.spa_periodo = int.Parse(dr["SPA_PERIODO"].ToString());
                            item.sus_cliente = int.Parse(dr["SUS_CLIENTE"].ToString());
                            item.cli_nombre = dr["CLI_NOMBRE"].ToString();
                            item.spa_monto_declarado_clp = decimal.Parse(dr["SPA_MONTO_DECLARADO_CLP"].ToString());

                            // Nulo mientras nadie lo haya verificado. int.Parse("")
                            // sobre esta columna es exactamente el error que ya
                            // volteó tres pantallas del sitio.
                            if (dr["SPA_MONTO_VERIFICADO_CLP"] != DBNull.Value)
                                item.spa_monto_verificado_clp = decimal.Parse(dr["SPA_MONTO_VERIFICADO_CLP"].ToString());

                            item.spa_fecha_transferencia = DateTime.Parse(dr["SPA_FECHA_TRANSFERENCIA"].ToString());
                            item.spa_banco = dr["SPA_BANCO"].ToString();
                            item.spa_numero_operacion = dr["SPA_NUMERO_OPERACION"].ToString();
                            item.spa_archivo = int.Parse(dr["SPA_ARCHIVO"].ToString());
                            item.spa_estado = int.Parse(dr["SPA_ESTADO"].ToString());
                            item.spo_nombre = dr["SPO_NOMBRE"].ToString();
                            item.spo_codigo = dr["SPO_CODIGO"].ToString();
                            item.spa_motivo_rechazo = dr["SPA_MOTIVO_RECHAZO"].ToString();

                            if (dr["SPA_FECHA_VERIFICACION_UTC"] != DBNull.Value)
                                item.spa_fecha_verificacion_utc = DateTime.Parse(dr["SPA_FECHA_VERIFICACION_UTC"].ToString());

                            item.verificado_por = dr["VERIFICADO_POR"].ToString();
                            item.spe_monto_clp = decimal.Parse(dr["SPE_MONTO_CLP"].ToString());

                            if (dr["SPE_FECHA_INICIO"] != DBNull.Value)
                                item.spe_fecha_inicio = DateTime.Parse(dr["SPE_FECHA_INICIO"].ToString());
                            if (dr["SPE_FECHA_FIN"] != DBNull.Value)
                                item.spe_fecha_fin = DateTime.Parse(dr["SPE_FECHA_FIN"].ToString());

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

        public SuscripcionPago GetPago(SuscripcionPago entidad)
        {
            List<SuscripcionPago> lista = GetPagos(new SuscripcionPago { spa_id = entidad.spa_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new SuscripcionPago();
        }

        /// <summary>
        /// Declara una transferencia. Nace en DECLARADO: esto no da nada
        /// por pagado.
        ///
        /// entidad.spa_archivo tiene que traer un comprobante ya registrado
        /// (ArchivoController.InsertArchivo). Se pide antes y no acá para
        /// que un fallo al subir el binario no deje un pago a medio crear.
        /// </summary>
        public Respuesta InsertPago(SuscripcionPago entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_SUSCRIPCION_PAGO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@PERIODO", entidad.spa_periodo);
                    cmdExecute.Parameters.AddWithValue("@MONTO_DECLARADO", entidad.spa_monto_declarado_clp);
                    cmdExecute.Parameters.AddWithValue("@FECHA_TRANSFERENCIA", entidad.spa_fecha_transferencia);
                    cmdExecute.Parameters.AddWithValue("@BANCO", (object)entidad.spa_banco ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@NUMERO_OPERACION", (object)entidad.spa_numero_operacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ARCHIVO", entidad.spa_archivo);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Pago declarado con éxito. Queda pendiente de verificación.";
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

        /// <summary>
        /// Corrige lo que quien declaró escribió mal (T-2211, bloque 59).
        ///
        /// NO ES VERIFICAR. Verificar coteja contra la cartola y mueve
        /// saldos; esto arregla el monto, la fecha, el banco o el número de
        /// operación de una declaración todavía sin resolver.
        ///
        /// EL PERÍODO NO VIAJA
        ///   Mover un pago de un período a otro descuadra los dos: el que lo
        ///   pierde y el que lo recibe. Es una operación aparte, con su
        ///   propio recálculo. El SP tampoco lo acepta.
        ///
        /// LO QUE NO SE MANDA NO SE BORRA
        ///   El SP usa ISNULL(@X, columna) en cada campo, así que un nulo
        ///   significa "no lo toques". Es la lección de
        ///   UPD_CLIENTE_INSTALACION, que escribía la fila entera y borraba
        ///   la zona horaria y las coordenadas de la planta.
        ///
        /// Un pago ya VERIFICADO lo rechaza el SP: su monto ya sumó al
        /// período y pudo extender la vigencia de la suscripción.
        /// </summary>
        public Respuesta CorregirPago(SuscripcionPago entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_SUSCRIPCION_PAGO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.spa_id);
                    cmdExecute.Parameters.AddWithValue("@MONTO_DECLARADO",
                        (entidad.spa_monto_declarado_clp > 0)
                            ? (object)entidad.spa_monto_declarado_clp : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_TRANSFERENCIA",
                        (entidad.spa_fecha_transferencia != DateTime.MinValue)
                            ? (object)entidad.spa_fecha_transferencia : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@BANCO",
                        string.IsNullOrEmpty(entidad.spa_banco) ? DBNull.Value : (object)entidad.spa_banco);
                    cmdExecute.Parameters.AddWithValue("@NUMERO_OPERACION",
                        string.IsNullOrEmpty(entidad.spa_numero_operacion)
                            ? DBNull.Value : (object)entidad.spa_numero_operacion);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    string mensaje = "Pago corregido.";

                    using (SqlDataReader dr = Conexion.GetDataReader(cmdExecute))
                    {
                        if (dr.Read() && dr["MENSAJE"] != DBNull.Value)
                            mensaje = dr["MENSAJE"].ToString();
                    }

                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.spa_id;
                    respuesta.detalle = mensaje;
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

        /// <summary>
        /// Verifica o rechaza. Es la operación que mueve dinero en los
        /// papeles: el SP recalcula lo pagado del período sumando solo los
        /// pagos verificados, ajusta el estado del período y, si quedó
        /// cubierto dentro de la tolerancia, extiende la vigencia de la
        /// suscripción. Todo en una transacción.
        ///
        /// El motivo del rechazo es obligatorio y lo exige el SP: un pago
        /// rechazado sin explicación obliga al cliente a adivinar y a
        /// volver a declarar lo mismo.
        /// </summary>
        public Respuesta VerificarPago(SuscripcionPago entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_SUSCRIPCION_PAGO_VERIFICAR");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.spa_id);
                    cmdExecute.Parameters.AddWithValue("@VERIFICADO", entidad.verificado);
                    cmdExecute.Parameters.AddWithValue("@MONTO_VERIFICADO", (object)entidad.monto_verificado ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MOTIVO_RECHAZO", (object)entidad.motivo_rechazo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.spa_id;
                    respuesta.detalle = entidad.verificado
                        ? "Pago verificado con éxito."
                        : "Pago rechazado.";
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

            return respuesta;
        }
    }
}
