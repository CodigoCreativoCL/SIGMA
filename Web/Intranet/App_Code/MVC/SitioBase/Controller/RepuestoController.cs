using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using OfficeOpenXml;
using System.Web;
using System.Text;
using System.Linq;
using System.IO;
using System.Data;

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
                            item.rep_repuesto_tipo = int.Parse(dr["REPUESTO_TIPO"].ToString());
                            item.repuesto_tipo_nombre = dr["REPUESTO_TIPO_NOMBRE"].ToString();
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

        /// <summary>
        /// Le pone el mismo tipo a varios repuestos de una vez.
        ///
        /// POR QUÉ EN LOTE
        ///   Clasificar un maestro que ya existe es el caso real: una planta
        ///   con trescientos repuestos tiene que ponerles tipo a todos. Uno
        ///   por uno son trescientas fichas abiertas, y nadie lo va a hacer:
        ///   el campo queda vacío y las pestañas no sirven.
        /// </summary>
        /// <param name="tipo">0 desclasifica.</param>
        /// <param name="ids">Ids separados por coma.</param>
        public Respuesta AsignarTipo(int tipo, string ids)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("UPS_REPUESTO_TIPO_ASIGNAR");
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@REPUESTO_TIPO", tipo > 0 ? (object)tipo : DBNull.Value);
                    cmd.Parameters.AddWithValue("@IDS", ids ?? "");
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    object r = cmd.ExecuteScalar();
                    cmd.Connection.Close();

                    int n = 0;
                    if (r != null && r != DBNull.Value) int.TryParse(r.ToString(), out n);

                    respuesta.codigo = n;
                    respuesta.detalle = n == 1
                        ? "1 repuesto actualizado."
                        : n + " repuestos actualizados.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
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
                    /* 0 significa "sin clasificar" y viaja como NULL: la
                       columna admite nulo y 0 no es un id valido. */
                    cmdExecute.Parameters.AddWithValue("@REPUESTO_TIPO",
                        entidad.rep_repuesto_tipo > 0 ? (object)entidad.rep_repuesto_tipo : DBNull.Value);
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
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
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
                    /* 0 significa "sin clasificar" y viaja como NULL: la
                       columna admite nulo y 0 no es un id valido. */
                    cmdExecute.Parameters.AddWithValue("@REPUESTO_TIPO",
                        entidad.rep_repuesto_tipo > 0 ? (object)entidad.rep_repuesto_tipo : DBNull.Value);
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
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
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
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
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
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
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
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
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
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        /* ================================================================
           DESCARGA Y CARGA MASIVA
           ================================================================ */

        /// <summary>
        /// Baja a Excel los repuestos que se están viendo.
        ///
        /// RESPETA EL FILTRO DE LA PANTALLA
        ///   Si alguien buscó "rodamiento" y descarga, espera los rodamientos,
        ///   no el catálogo entero. Bajar todo cuando la pantalla muestra diez
        ///   filas es una sorpresa desagradable, y con cinco mil repuestos es
        ///   además un archivo inútil.
        /// </summary>
        public void ExportarRepuestos(Repuesto filtro)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "RPT_REPUESTO_EXCEL";
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

            if (filtro != null)
            {
                if (!string.IsNullOrEmpty(filtro.filtro))
                    cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);

                if (filtro.filtro_habilitado != null)
                    cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
            }

            Entregar(Conexion.GetDataTable(cmd), "REPUESTOS");
        }

        /// <summary>
        /// La planilla para cargar.
        ///
        /// LLEVA UNA SEGUNDA HOJA CON LAS UNIDADES VALIDAS
        ///   Sin ella, quien la llena escribe "unidades", "un", "u." y cada
        ///   una falla en la carga sin que se entienda por qué. La hoja dice
        ///   exactamente qué escribir en la columna UNIDAD.
        /// </summary>
        public void PlantillaRepuestos()
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "RPT_REPUESTO_PLANTILLA";

            DataTable plantilla = Conexion.GetDataTable(cmd);

            SqlCommand cmdUni = new SqlCommand();
            cmdUni.CommandText = "RPT_UNIDAD_MEDIDA_EXCEL";

            DataTable unidades = Conexion.GetDataTable(cmdUni);

            byte[] binario = Tools.Excel.exportExcelXLSX_Bytes(plantilla, true);

            using (ExcelPackage excel = new ExcelPackage())
            {
                using (MemoryStream stream = new MemoryStream(binario))
                {
                    excel.Load(stream);
                }

                ExcelWorksheet hoja = excel.Workbook.Worksheets.First();
                hoja.Name = "REPUESTOS";
                hoja.Columns.AutoFit();

                /* El código va como texto: un código que empiece por ceros
                   -0012-A- lo convertiría Excel en número y perdería los
                   ceros, y ese ya no es el código que el usuario escribió. */
                hoja.Cells["A:A"].Style.Numberformat.Format = "@";

                ExcelWorksheet ayuda = excel.Workbook.Worksheets.Add("UNIDADES VALIDAS");
                ayuda.Cells["A1"].LoadFromDataTable(unidades, true);
                ayuda.Columns.AutoFit();

                binario = excel.GetAsByteArray();
            }

            Entregar(binario, "PLANTILLA CARGA REPUESTOS");
        }

        /// <summary>
        /// Carga los repuestos de una planilla, fila por fila.
        ///
        /// REUSA InsertRepuesto Y NO ESCRIBE SU PROPIO INSERT
        ///   Con un INSERT propio, la carga masiva tendría que repetir cada
        ///   validación del SP —código único, unidad que exista, lote— y esas
        ///   copias se desincronizan a la primera regla nueva. Pasando por el
        ///   mismo camino que la ficha, lo que se puede crear a mano es
        ///   exactamente lo que se puede cargar en masa.
        ///
        /// UNA FILA MALA NO DETIENE LA CARGA
        ///   Cada fila va en su propio try. Con cien repuestos, que la número
        ///   40 tenga la unidad mal escrita no puede obligar a rehacer la
        ///   planilla entera: se cargan 99 y se informa cuál falló y por qué.
        /// </summary>
        public Respuesta InsertRepuestosMasivo(byte[] archivo)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad()) return respuesta;

            DataTable resultado = new DataTable();
            resultado.Columns.Add("FILA", typeof(string));
            resultado.Columns.Add("CODIGO", typeof(string));
            resultado.Columns.Add("MOTIVO", typeof(string));

            try
            {
                DataTable entrada = Tools.Excel.excelXLSX_ToDataTable(archivo, 1, 1, 14);

                if (!entrada.Columns.Contains("NOMBRE") || !entrada.Columns.Contains("UNIDAD"))
                {
                    respuesta.error = true;
                    respuesta.detalle = "La planilla no tiene las columnas NOMBRE y UNIDAD. " +
                                        "Descargue la plantilla y trabaje sobre ella.";
                    return respuesta;
                }

                /* Las unidades se leen UNA vez y se resuelven en memoria:
                   consultar la base por cada fila serían mil viajes para
                   traer siempre la misma tabla de veinte filas. */
                Dictionary<string, int> unidades = new Dictionary<string, int>();

                UnidadMedidaController umc = new UnidadMedidaController();

                foreach (UnidadMedida u in umc.GetUnidades())
                {
                    string clave = u.ume_codigo.Trim().ToUpper();
                    if (!unidades.ContainsKey(clave)) unidades.Add(clave, u.ume_id);
                }

                int cargados = 0;
                int fallidos = 0;
                int fila = 1;

                foreach (DataRow row in entrada.Rows)
                {
                    fila++;

                    string codigo = Columna(row, "CODIGO");
                    string nombre = Columna(row, "NOMBRE");

                    try
                    {
                        /* La fila de ejemplo de la plantilla se salta sola:
                           da lo mismo si alguien olvida borrarla. */
                        if (codigo.ToUpper().StartsWith("EJEMPLO")) continue;

                        /* Una fila entera en blanco no es un error: es el
                           final de lo que alguien escribió. */
                        if (nombre.Length == 0 && codigo.Length == 0) continue;

                        if (nombre.Length == 0)
                            throw new Exception("Falta el nombre.");

                        string unidad = Columna(row, "UNIDAD").ToUpper();

                        if (unidad.Length == 0)
                            throw new Exception("Falta la unidad de medida.");

                        if (!unidades.ContainsKey(unidad))
                            throw new Exception("La unidad \"" + unidad + "\" no existe. " +
                                                "Vea la hoja UNIDADES VALIDAS de la plantilla.");

                        Repuesto r = new Repuesto();

                        /* Sin código en la planilla, lo genera el SP como
                           REP-<id>: es el mismo comportamiento que la ficha. */
                        r.rep_codigo = codigo.Length > 0 ? codigo : "AUTO";
                        r.rep_nombre = nombre;
                        r.rep_unidad_medida = unidades[unidad];
                        r.rep_fabricante = Columna(row, "FABRICANTE");
                        r.rep_modelo = Columna(row, "MODELO");
                        r.rep_descripcion = Columna(row, "DESCRIPCION");

                        r.rep_controla_lote = EsSi(row, "CONTROLA LOTE");
                        r.rep_es_consumible = EsSi(row, "CONSUMIBLE");
                        r.rep_es_reparable = EsSi(row, "REPARABLE");

                        /* Sin la columna, habilitado: es lo que espera quien
                           carga repuestos para empezar a usarlos. */
                        r.rep_habilitado = !entrada.Columns.Contains("HABILITADO")
                                           || Columna(row, "HABILITADO").Length == 0
                                           || EsSi(row, "HABILITADO");

                        r.rep_costo_referencia = Numero(row, "COSTO REFERENCIA");
                        r.rep_vida_util_hora = Numero(row, "VIDA UTIL HORAS");
                        r.rep_vida_util_ciclo = Numero(row, "VIDA UTIL CICLOS");

                        decimal? dias = Numero(row, "VIDA UTIL DIAS");

                        if (dias != null)
                        {
                            if (dias.Value != Math.Floor(dias.Value))
                                throw new Exception("La vida útil en días tiene que ser un número entero.");

                            r.rep_vida_util_dia = (int)dias.Value;
                        }

                        Respuesta uno = InsertRepuesto(r);

                        if (uno.error) throw new Exception(uno.detalle);

                        cargados++;
                    }
                    catch (Exception ex)
                    {
                        fallidos++;

                        DataRow err = resultado.NewRow();
                        err["FILA"] = fila.ToString();
                        err["CODIGO"] = codigo.Length > 0 ? codigo : nombre;
                        err["MOTIVO"] = ex.Message;
                        resultado.Rows.Add(err);
                    }
                }

                respuesta.cantidaCargada = cargados;
                respuesta.cantidaError = fallidos;
                respuesta.error = (fallidos > 0);
                respuesta.table = resultado;
                respuesta.detalle = cargados.ToString() + " repuesto(s) cargado(s).";
            }
            catch (Exception ex)
            {
                respuesta.error = true;
                respuesta.detalle = "No se pudo leer la planilla: " + ex.Message;
                respuesta.table = resultado;
            }

            return respuesta;
        }

        /* ---- Lectura tolerante de la planilla ----
           Una planilla que pasó por manos humanas trae columnas que faltan,
           espacios de más y celdas vacías. Preguntar por cada caso en cada
           uso llenaría el método de ruido. */

        private string Columna(DataRow row, string nombre)
        {
            if (!row.Table.Columns.Contains(nombre)) return "";
            if (row[nombre] == null || row[nombre] == DBNull.Value) return "";

            return row[nombre].ToString().Trim();
        }

        /// <summary>
        /// SI/NO tolerante: acepta SI, S, 1, TRUE, X. Quien llena una planilla
        /// escribe lo que le parece, y rechazar la fila por una "X" en vez de
        /// un "SI" es hacerle perder el tiempo por nada.
        /// </summary>
        private bool EsSi(DataRow row, string nombre)
        {
            string v = Columna(row, nombre).ToUpper();

            return (v == "SI" || v == "S" || v == "1" || v == "TRUE" || v == "X" || v == "SÍ");
        }

        private decimal? Numero(DataRow row, string nombre)
        {
            string v = Columna(row, nombre);

            if (v.Length == 0) return null;

            decimal d;

            /* Se prueba con la cultura del servidor y con punto decimal: una
               planilla puede venir de un Excel en inglés y "1500.50" no debe
               volverse 150050. */
            if (decimal.TryParse(v, out d)) return d;

            if (decimal.TryParse(v, System.Globalization.NumberStyles.Any,
                                 System.Globalization.CultureInfo.InvariantCulture, out d))
                return d;

            throw new Exception("\"" + v + "\" no es un número válido en " + nombre + ".");
        }

        /// <summary>
        /// Manda el archivo al navegador. Un solo sitio para que la descarga y
        /// la plantilla no terminen con encabezados distintos.
        /// </summary>
        private void Entregar(DataTable datos, string nombre)
        {
            Entregar(Tools.Excel.exportExcelXLSX_Bytes(datos, true), nombre);
        }

        private void Entregar(byte[] binario, string nombre)
        {
            string archivo = nombre + " " + DateTime.Now.ToString("dd-MM-yyyy");

            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.ContentType = "application/vnd.ms-excel";
            HttpContext.Current.Response.HeaderEncoding = Encoding.Default;
            HttpContext.Current.Response.ContentEncoding = Encoding.Default;
            HttpContext.Current.Response.AddHeader("content-disposition",
                                                   "attachment; filename=" + archivo + ".xlsx");

            HttpContext.Current.Response.BinaryWrite(binario);
            HttpContext.Current.Response.End();
        }

    }
}
