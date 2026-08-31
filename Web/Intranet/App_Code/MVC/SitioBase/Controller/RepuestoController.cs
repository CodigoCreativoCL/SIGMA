using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Maestro de repuestos (HU-050) y sus umbrales por bodega (HU-053).
    ///
    /// LOS UMBRALES VIVEN AQUI Y NO EN SU PROPIO CONTROLLER
    ///   Porque no son una entidad que alguien administre por su cuenta:
    ///   son una propiedad del repuesto EN una bodega, y se editan desde la
    ///   ficha del repuesto. Un mantenedor aparte obligaria a elegir dos
    ///   veces lo que ya se eligio.
    /// </summary>
    public class RepuestoController
    {
        public List<Repuesto> GetRepuestos(Repuesto filtro = null)
        {
            List<Repuesto> lista = new List<Repuesto>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_REPUESTO";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.rep_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.rep_id);
                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Repuesto item = new Repuesto();

                            item.rep_id = int.Parse(dr["REP_ID"].ToString());
                            item.rep_cliente = int.Parse(dr["REP_CLIENTE"].ToString());
                            item.rep_codigo = dr["REP_CODIGO"].ToString();
                            item.rep_nombre = dr["REP_NOMBRE"].ToString();
                            item.rep_fabricante = dr["REP_FABRICANTE"].ToString();
                            item.rep_modelo = dr["REP_MODELO"].ToString();
                            item.rep_descripcion = dr["REP_DESCRIPCION"].ToString();
                            item.rep_unidad_medida = int.Parse(dr["REP_UNIDAD_MEDIDA"].ToString());
                            item.rep_es_reparable = bool.Parse(dr["REP_ES_REPARABLE"].ToString());
                            item.rep_es_consumible = bool.Parse(dr["REP_ES_CONSUMIBLE"].ToString());
                            item.rep_controla_lote = bool.Parse(dr["REP_CONTROLA_LOTE"].ToString());
                            item.rep_habilitado = bool.Parse(dr["REP_HABILITADO"].ToString());

                            // Anulables: se comprueban antes de convertir.
                            if (dr["REP_COSTO_REFERENCIA"] != DBNull.Value)
                                item.rep_costo_referencia = decimal.Parse(dr["REP_COSTO_REFERENCIA"].ToString());
                            if (dr["REP_MONEDA"] != DBNull.Value)
                                item.rep_moneda = int.Parse(dr["REP_MONEDA"].ToString());
                            if (dr["REP_VIDA_UTIL_HORA"] != DBNull.Value)
                                item.rep_vida_util_hora = decimal.Parse(dr["REP_VIDA_UTIL_HORA"].ToString());
                            if (dr["REP_VIDA_UTIL_DIA"] != DBNull.Value)
                                item.rep_vida_util_dia = int.Parse(dr["REP_VIDA_UTIL_DIA"].ToString());
                            if (dr["REP_VIDA_UTIL_CICLO"] != DBNull.Value)
                                item.rep_vida_util_ciclo = decimal.Parse(dr["REP_VIDA_UTIL_CICLO"].ToString());

                            item.unidad_nombre = dr["UNIDAD_NOMBRE"].ToString();
                            item.unidad_simbolo = dr["UNIDAD_SIMBOLO"].ToString();
                            item.moneda_codigo = dr["MONEDA_CODIGO"].ToString();
                            item.existencia_total = decimal.Parse(dr["EXISTENCIA_TOTAL"].ToString());
                            item.bodegas_con_saldo = int.Parse(dr["BODEGAS_CON_SALDO"].ToString());

                            if (dr["REP_FECHA_CREACION"] != DBNull.Value)
                                item.rep_fecha_creacion = DateTime.Parse(dr["REP_FECHA_CREACION"].ToString());
                            if (dr["REP_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.rep_fecha_actualizacion = DateTime.Parse(dr["REP_FECHA_ACTUALIZACION"].ToString());
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();


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
            }

            return lista;
        }

        public Repuesto GetRepuesto(int id)
        {
            List<Repuesto> lista = GetRepuestos(new Repuesto { rep_id = id });
            return (lista != null && lista.Count > 0) ? lista[0] : new Repuesto();
        }

        public Respuesta InsertRepuesto(Repuesto entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_REPUESTO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.rep_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.rep_nombre);
                    cmdExecute.Parameters.AddWithValue("@UNIDAD_MEDIDA", entidad.rep_unidad_medida);
                    cmdExecute.Parameters.AddWithValue("@FABRICANTE", (object)entidad.rep_fabricante ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MODELO", (object)entidad.rep_modelo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.rep_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ES_REPARABLE", entidad.rep_es_reparable);
                    cmdExecute.Parameters.AddWithValue("@ES_CONSUMIBLE", entidad.rep_es_consumible);
                    cmdExecute.Parameters.AddWithValue("@CONTROLA_LOTE", entidad.rep_controla_lote);
                    cmdExecute.Parameters.AddWithValue("@COSTO_REFERENCIA",
                        entidad.rep_costo_referencia.HasValue ? (object)entidad.rep_costo_referencia.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MONEDA",
                        entidad.rep_moneda.HasValue ? (object)entidad.rep_moneda.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@VIDA_UTIL_HORA",
                        entidad.rep_vida_util_hora.HasValue ? (object)entidad.rep_vida_util_hora.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@VIDA_UTIL_DIA",
                        entidad.rep_vida_util_dia.HasValue ? (object)entidad.rep_vida_util_dia.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@VIDA_UTIL_CICLO",
                        entidad.rep_vida_util_ciclo.HasValue ? (object)entidad.rep_vida_util_ciclo.Value : DBNull.Value);
                    // Vacio significa borrar solo si la ficha lo dice.
                    cmdExecute.Parameters.AddWithValue("@LIMPIA_VIDA_UTIL", entidad.limpia_vida_util);
                    cmdExecute.Parameters.AddWithValue("@VIDA_UTIL_HORA",
                        entidad.rep_vida_util_hora.HasValue ? (object)entidad.rep_vida_util_hora.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@VIDA_UTIL_DIA",
                        entidad.rep_vida_util_dia.HasValue ? (object)entidad.rep_vida_util_dia.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@VIDA_UTIL_CICLO",
                        entidad.rep_vida_util_ciclo.HasValue ? (object)entidad.rep_vida_util_ciclo.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = (int)cmdExecute.Parameters["@ID"].Value;
                    respuesta.detalle = "Repuesto creado con éxito.";
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

        public Respuesta UpdateRepuesto(Repuesto entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_REPUESTO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.rep_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.rep_nombre);
                    cmdExecute.Parameters.AddWithValue("@UNIDAD_MEDIDA", entidad.rep_unidad_medida);
                    cmdExecute.Parameters.AddWithValue("@FABRICANTE", (object)entidad.rep_fabricante ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MODELO", (object)entidad.rep_modelo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.rep_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ES_REPARABLE", entidad.rep_es_reparable);
                    cmdExecute.Parameters.AddWithValue("@ES_CONSUMIBLE", entidad.rep_es_consumible);
                    cmdExecute.Parameters.AddWithValue("@CONTROLA_LOTE", entidad.rep_controla_lote);
                    cmdExecute.Parameters.AddWithValue("@COSTO_REFERENCIA",
                        entidad.rep_costo_referencia.HasValue ? (object)entidad.rep_costo_referencia.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MONEDA",
                        entidad.rep_moneda.HasValue ? (object)entidad.rep_moneda.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.rep_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.rep_id;
                    respuesta.detalle = "Repuesto actualizado con éxito.";
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

        public Respuesta DeleteRepuesto(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_REPUESTO");
                    cmdExecute.Parameters.AddWithValue("@ID", id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    string mensaje = "Repuesto dado de baja.";

                    using (SqlDataReader dr = Conexion.GetDataReader(cmdExecute))
                    {
                        if (dr.Read() && dr["MENSAJE"] != DBNull.Value) mensaje = dr["MENSAJE"].ToString();
                    }

                    cmdExecute.Connection.Close();

                    respuesta.codigo = id;
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


        /* ================================================================
           UMBRALES POR BODEGA  (HU-053)
           ================================================================ */

        public List<RepuestoBodegaStock> GetUmbrales(RepuestoBodegaStock filtro = null)
        {
            List<RepuestoBodegaStock> lista = new List<RepuestoBodegaStock>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_REPUESTO_BODEGA_STOCK";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.rbs_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.rbs_id);
                        if (filtro.rbs_repuesto > 0) cmd.Parameters.AddWithValue("@REPUESTO", filtro.rbs_repuesto);
                        if (filtro.rbs_bodega > 0) cmd.Parameters.AddWithValue("@BODEGA", filtro.rbs_bodega);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            RepuestoBodegaStock item = new RepuestoBodegaStock();

                            item.rbs_id = int.Parse(dr["RBS_ID"].ToString());
                            item.rbs_repuesto = int.Parse(dr["RBS_REPUESTO"].ToString());
                            item.rbs_bodega = int.Parse(dr["RBS_BODEGA"].ToString());
                            item.rbs_stock_minimo = decimal.Parse(dr["RBS_STOCK_MINIMO"].ToString());

                            if (dr["RBS_STOCK_MAXIMO"] != DBNull.Value)
                                item.rbs_stock_maximo = decimal.Parse(dr["RBS_STOCK_MAXIMO"].ToString());
                            if (dr["RBS_PUNTO_REPOSICION"] != DBNull.Value)
                                item.rbs_punto_reposicion = decimal.Parse(dr["RBS_PUNTO_REPOSICION"].ToString());

                            item.rbs_observacion = dr["RBS_OBSERVACION"].ToString();
                            item.repuesto_codigo = dr["REPUESTO_CODIGO"].ToString();
                            item.repuesto_nombre = dr["REPUESTO_NOMBRE"].ToString();
                            item.bodega_codigo = dr["BODEGA_CODIGO"].ToString();
                            item.bodega_nombre = dr["BODEGA_NOMBRE"].ToString();
                            item.existencia = decimal.Parse(dr["EXISTENCIA"].ToString());
                            item.bajo_minimo = (dr["BAJO_MINIMO"].ToString() == "1");
                            item.sobre_maximo = (dr["SOBRE_MAXIMO"].ToString() == "1");

                            if (dr["RBS_FECHA_CREACION"] != DBNull.Value)
                                item.rbs_fecha_creacion = DateTime.Parse(dr["RBS_FECHA_CREACION"].ToString());
                            if (dr["RBS_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.rbs_fecha_actualizacion = DateTime.Parse(dr["RBS_FECHA_ACTUALIZACION"].ToString());
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();


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
            }

            return lista;
        }

        /// <summary>
        /// UPS y no Insert/Update: la fila es "los umbrales de este repuesto
        /// en esta bodega" y tiene indice unico sobre el par. Preguntar
        /// antes si existe es una ida a la base que el SP ya hace.
        /// </summary>
        public Respuesta GuardarUmbral(RepuestoBodegaStock entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("UPS_REPUESTO_BODEGA_STOCK");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@REPUESTO", entidad.rbs_repuesto);
                    cmdExecute.Parameters.AddWithValue("@BODEGA", entidad.rbs_bodega);
                    cmdExecute.Parameters.AddWithValue("@STOCK_MINIMO", entidad.rbs_stock_minimo);
                    cmdExecute.Parameters.AddWithValue("@STOCK_MAXIMO",
                        entidad.rbs_stock_maximo.HasValue ? (object)entidad.rbs_stock_maximo.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@PUNTO_REPOSICION",
                        entidad.rbs_punto_reposicion.HasValue ? (object)entidad.rbs_punto_reposicion.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", (object)entidad.rbs_observacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = (int)cmdExecute.Parameters["@ID"].Value;
                    respuesta.detalle = "Umbrales guardados.";
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

        public Respuesta DeleteUmbral(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_REPUESTO_BODEGA_STOCK");
                    cmdExecute.Parameters.AddWithValue("@ID", id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = id;
                    respuesta.detalle = "Umbrales retirados.";
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


        /* ================================================================
           LOTES  (HU-054 criterio 2)
           ================================================================ */

        public List<RepuestoLote> GetLotes(RepuestoLote filtro = null)
        {
            List<RepuestoLote> lista = new List<RepuestoLote>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_REPUESTO_LOTE";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.rlo_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.rlo_id);
                        if (filtro.rlo_repuesto > 0) cmd.Parameters.AddWithValue("@REPUESTO", filtro.rlo_repuesto);
                        if (filtro.filtro_vigentes) cmd.Parameters.AddWithValue("@VIGENTES", true);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            RepuestoLote item = new RepuestoLote();

                            item.rlo_id = int.Parse(dr["RLO_ID"].ToString());
                            item.rlo_repuesto = int.Parse(dr["RLO_REPUESTO"].ToString());
                            item.rlo_codigo = dr["RLO_CODIGO"].ToString();

                            if (dr["RLO_FECHA_INGRESO"] != DBNull.Value)
                                item.rlo_fecha_ingreso = DateTime.Parse(dr["RLO_FECHA_INGRESO"].ToString());
                            if (dr["RLO_FECHA_VENCIMIENTO"] != DBNull.Value)
                                item.rlo_fecha_vencimiento = DateTime.Parse(dr["RLO_FECHA_VENCIMIENTO"].ToString());
                            if (dr["RLO_COSTO_UNITARIO"] != DBNull.Value)
                                item.rlo_costo_unitario = decimal.Parse(dr["RLO_COSTO_UNITARIO"].ToString());

                            item.rlo_observacion = dr["RLO_OBSERVACION"].ToString();
                            item.rlo_habilitado = bool.Parse(dr["RLO_HABILITADO"].ToString());
                            item.repuesto_codigo = dr["REPUESTO_CODIGO"].ToString();
                            item.vencido = (dr["VENCIDO"].ToString() == "1");

                            if (dr["RLO_FECHA_CREACION"] != DBNull.Value)
                                item.rlo_fecha_creacion = DateTime.Parse(dr["RLO_FECHA_CREACION"].ToString());
                            if (dr["RLO_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.rlo_fecha_actualizacion = DateTime.Parse(dr["RLO_FECHA_ACTUALIZACION"].ToString());
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();


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
            }

            return lista;
        }

        /// <summary>
        /// El lote se crea al recibir la mercaderia: nadie sabe el numero
        /// hasta que llega el camion. Por eso el ingreso puede crearlo al
        /// vuelo, y el SP es idempotente por (repuesto, codigo) —recibir
        /// otra vez del mismo lote es lo normal, no un error—.
        /// </summary>
        public Respuesta InsertLote(RepuestoLote entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_REPUESTO_LOTE");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@REPUESTO", entidad.rlo_repuesto);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.rlo_codigo);
                    cmdExecute.Parameters.AddWithValue("@FECHA_INGRESO",
                        entidad.rlo_fecha_ingreso.HasValue ? (object)entidad.rlo_fecha_ingreso.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_VENCIMIENTO",
                        entidad.rlo_fecha_vencimiento.HasValue ? (object)entidad.rlo_fecha_vencimiento.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    string mensaje = "Lote creado.";

                    using (SqlDataReader dr = Conexion.GetDataReader(cmdExecute))
                    {
                        if (dr.Read())
                        {
                            if (dr["MENSAJE"] != DBNull.Value) mensaje = dr["MENSAJE"].ToString();
                            if (dr["ID"] != DBNull.Value) respuesta.codigo = int.Parse(dr["ID"].ToString());
                        }
                    }

                    cmdExecute.Connection.Close();

                    if (respuesta.codigo == 0)
                        respuesta.codigo = (int)cmdExecute.Parameters["@ID"].Value;

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
    }
}
