using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Existencias y movimientos (HU-054, HU-055, HU-056, HU-057).
    ///
    /// UN SOLO MetodoRegistrarMovimiento PARA LAS TRES OPERACIONES
    ///   Ingresar, entregar, devolver y ajustar son el mismo procedimiento
    ///   con distinto tipo. Partirlo aca en cuatro metodos crearia cuatro
    ///   caminos que pueden divergir contra uno que no puede — y lo que no
    ///   puede divergir es justamente lo que mantiene el saldo cuadrado.
    /// </summary>
    public class InventarioController
    {
        // Ids de Inventario_Movimiento_Tipo, con nombre.
        public const int INGRESO_COMPRA  = 1;
        public const int SALIDA_CONSUMO  = 2;
        public const int DEVOLUCION      = 3;
        public const int AJUSTE_POSITIVO = 4;
        public const int AJUSTE_NEGATIVO = 5;
        public const int TRASLADO_SALIDA = 6;
        public const int MERMA           = 8;

        /// <summary>
        /// Los tipos de movimiento. Se leen de la tabla y no se escriben en
        /// el markup: un catalogo copiado en un .aspx es el que nadie
        /// actualiza el dia que cambia.
        /// </summary>
        public List<InventarioMovimientoTipo> GetTipos(bool sinTrasladoIngreso = false)
        {
            List<InventarioMovimientoTipo> lista = new List<InventarioMovimientoTipo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_INVENTARIO_MOVIMIENTO_TIPO";

                    if (sinTrasladoIngreso)
                        cmd.Parameters.AddWithValue("@SIN_TRASLADO_INGRESO", true);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            InventarioMovimientoTipo item = new InventarioMovimientoTipo();

                            item.imt_id = int.Parse(dr["IMT_ID"].ToString());
                            item.imt_codigo = dr["IMT_CODIGO"].ToString();
                            item.imt_nombre = dr["IMT_NOMBRE"].ToString();
                            item.signo = int.Parse(dr["SIGNO"].ToString());
                            item.familia = dr["FAMILIA"].ToString();

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
        /// Quienes han registrado al menos un movimiento, con cuantos lleva
        /// cada uno. La lista se arma sola: nadie tiene que mantenerla.
        /// </summary>
        public List<InventarioMovimientoUsuario> GetUsuariosConMovimiento()
        {
            List<InventarioMovimientoUsuario> lista = new List<InventarioMovimientoUsuario>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_INVENTARIO_MOVIMIENTO_USUARIO";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            InventarioMovimientoUsuario item = new InventarioMovimientoUsuario();

                            item.usu_id = int.Parse(dr["USU_ID"].ToString());
                            item.usuario_nombre = dr["USUARIO_NOMBRE"].ToString();
                            item.movimientos = int.Parse(dr["MOVIMIENTOS"].ToString());

                            if (dr["ULTIMO"] != DBNull.Value)
                                item.ultimo = DateTime.Parse(dr["ULTIMO"].ToString());

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

        public List<InventarioSaldo> GetSaldos(InventarioSaldo filtro = null)
        {
            List<InventarioSaldo> lista = new List<InventarioSaldo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_INVENTARIO_SALDO";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.isa_repuesto > 0) cmd.Parameters.AddWithValue("@REPUESTO", filtro.isa_repuesto);
                        if (filtro.isa_bodega > 0) cmd.Parameters.AddWithValue("@BODEGA", filtro.isa_bodega);
                        if (filtro.filtro_instalacion > 0)
                            cmd.Parameters.AddWithValue("@INSTALACION", filtro.filtro_instalacion);
                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                        if (filtro.filtro_solo_alerta)
                            cmd.Parameters.AddWithValue("@SOLO_ALERTA", true);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            InventarioSaldo item = new InventarioSaldo();

                            item.isa_id = int.Parse(dr["ISA_ID"].ToString());
                            item.isa_repuesto = int.Parse(dr["ISA_REPUESTO"].ToString());
                            item.isa_bodega = int.Parse(dr["ISA_BODEGA"].ToString());
                            item.isa_cantidad = decimal.Parse(dr["ISA_CANTIDAD"].ToString());
                            item.isa_cantidad_reservada = decimal.Parse(dr["ISA_CANTIDAD_RESERVADA"].ToString());
                            item.cantidad_disponible = decimal.Parse(dr["CANTIDAD_DISPONIBLE"].ToString());

                            if (dr["ISA_COSTO_PROMEDIO"] != DBNull.Value)
                                item.isa_costo_promedio = decimal.Parse(dr["ISA_COSTO_PROMEDIO"].ToString());
                            if (dr["ISA_FECHA_ULTIMO_MOVIMIENTO"] != DBNull.Value)
                                item.isa_fecha_ultimo_movimiento = DateTime.Parse(dr["ISA_FECHA_ULTIMO_MOVIMIENTO"].ToString());
                            if (dr["RBS_STOCK_MINIMO"] != DBNull.Value)
                                item.rbs_stock_minimo = decimal.Parse(dr["RBS_STOCK_MINIMO"].ToString());
                            if (dr["RBS_STOCK_MAXIMO"] != DBNull.Value)
                                item.rbs_stock_maximo = decimal.Parse(dr["RBS_STOCK_MAXIMO"].ToString());
                            if (dr["RBS_PUNTO_REPOSICION"] != DBNull.Value)
                                item.rbs_punto_reposicion = decimal.Parse(dr["RBS_PUNTO_REPOSICION"].ToString());

                            item.repuesto_codigo = dr["REPUESTO_CODIGO"].ToString();
                            item.repuesto_nombre = dr["REPUESTO_NOMBRE"].ToString();
                            item.rep_controla_lote = bool.Parse(dr["REP_CONTROLA_LOTE"].ToString());
                            item.unidad_simbolo = dr["UNIDAD_SIMBOLO"].ToString();
                            item.bodega_codigo = dr["BODEGA_CODIGO"].ToString();
                            item.bodega_nombre = dr["BODEGA_NOMBRE"].ToString();
                            item.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            item.ubicacion_codigo = dr["UBICACION_CODIGO"].ToString();
                            item.bajo_minimo = (dr["BAJO_MINIMO"].ToString() == "1");
                            item.sobre_maximo = (dr["SOBRE_MAXIMO"].ToString() == "1");

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

        public List<InventarioMovimiento> GetMovimientos(InventarioMovimiento filtro = null)
        {
            List<InventarioMovimiento> lista = new List<InventarioMovimiento>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_INVENTARIO_MOVIMIENTO";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.imo_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.imo_id);
                        if (filtro.imo_repuesto > 0) cmd.Parameters.AddWithValue("@REPUESTO", filtro.imo_repuesto);
                        if (filtro.imo_bodega > 0) cmd.Parameters.AddWithValue("@BODEGA", filtro.imo_bodega);
                        if (filtro.filtro_tipo > 0) cmd.Parameters.AddWithValue("@TIPO", filtro.filtro_tipo);
                        if (filtro.filtro_usuario > 0) cmd.Parameters.AddWithValue("@USUARIO", filtro.filtro_usuario);
                        if (filtro.filtro_desde != null) cmd.Parameters.AddWithValue("@DESDE", filtro.filtro_desde);
                        if (filtro.filtro_hasta != null) cmd.Parameters.AddWithValue("@HASTA", filtro.filtro_hasta);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            InventarioMovimiento item = new InventarioMovimiento();

                            item.imo_id = int.Parse(dr["IMO_ID"].ToString());
                            item.imo_repuesto = int.Parse(dr["IMO_REPUESTO"].ToString());
                            item.imo_bodega = int.Parse(dr["IMO_BODEGA"].ToString());
                            item.imo_inventario_movimiento_tipo = int.Parse(dr["IMO_INVENTARIO_MOVIMIENTO_TIPO"].ToString());
                            item.imo_cantidad = decimal.Parse(dr["IMO_CANTIDAD"].ToString());
                            item.imo_fecha_movimiento_utc = DateTime.Parse(dr["IMO_FECHA_MOVIMIENTO_UTC"].ToString());

                            if (dr["IMO_COSTO_UNITARIO"] != DBNull.Value)
                                item.imo_costo_unitario = decimal.Parse(dr["IMO_COSTO_UNITARIO"].ToString());
                            if (dr["IMO_ORDEN_TRABAJO"] != DBNull.Value)
                                item.imo_orden_trabajo = int.Parse(dr["IMO_ORDEN_TRABAJO"].ToString());
                            if (dr["IMO_BODEGA_DESTINO"] != DBNull.Value)
                                item.imo_bodega_destino = int.Parse(dr["IMO_BODEGA_DESTINO"].ToString());

                            item.imo_observacion = dr["IMO_OBSERVACION"].ToString();
                            item.tipo_codigo = dr["TIPO_CODIGO"].ToString();
                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            item.signo = int.Parse(dr["SIGNO"].ToString());
                            item.familia = dr["FAMILIA"].ToString();
                            item.repuesto_codigo = dr["REPUESTO_CODIGO"].ToString();
                            item.repuesto_nombre = dr["REPUESTO_NOMBRE"].ToString();
                            item.unidad_simbolo = dr["UNIDAD_SIMBOLO"].ToString();
                            item.bodega_codigo = dr["BODEGA_CODIGO"].ToString();
                            item.bodega_nombre = dr["BODEGA_NOMBRE"].ToString();
                            item.bodega_destino_nombre = dr["BODEGA_DESTINO_NOMBRE"].ToString();
                            item.ubicacion_codigo = dr["UBICACION_CODIGO"].ToString();
                            item.lote_codigo = dr["LOTE_CODIGO"].ToString();
                            item.usuario_nombre = dr["USUARIO_NOMBRE"].ToString();

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

        public InventarioMovimiento GetMovimiento(int id)
        {
            List<InventarioMovimiento> lista = GetMovimientos(new InventarioMovimiento { imo_id = id });
            return (lista != null && lista.Count > 0) ? lista[0] : new InventarioMovimiento();
        }

        /// <summary>
        /// Registra el movimiento. El SP valida saldo, lote y motivo segun
        /// el tipo, y mantiene Inventario_Saldo y la orden de trabajo en la
        /// misma transaccion.
        ///
        /// Desde la web NO se manda uuid: la idempotencia por uuid existe
        /// para el telefono, que encola y reintenta. Un navegador que manda
        /// dos veces esta pidiendo dos movimientos, y ese es un problema de
        /// doble clic que se resuelve deshabilitando el boton, no fingiendo
        /// que el segundo ya habia pasado.
        /// </summary>
        public Respuesta RegistrarMovimiento(InventarioMovimiento entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_INVENTARIO_MOVIMIENTO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@REPUESTO", entidad.imo_repuesto);
                    cmdExecute.Parameters.AddWithValue("@BODEGA", entidad.imo_bodega);
                    cmdExecute.Parameters.AddWithValue("@TIPO", entidad.imo_inventario_movimiento_tipo);
                    cmdExecute.Parameters.AddWithValue("@CANTIDAD", entidad.imo_cantidad);
                    cmdExecute.Parameters.AddWithValue("@UBICACION",
                        entidad.imo_bodega_ubicacion.HasValue ? (object)entidad.imo_bodega_ubicacion.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@LOTE",
                        entidad.imo_repuesto_lote.HasValue ? (object)entidad.imo_repuesto_lote.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@COSTO_UNITARIO",
                        entidad.imo_costo_unitario.HasValue ? (object)entidad.imo_costo_unitario.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MONEDA",
                        entidad.imo_moneda.HasValue ? (object)entidad.imo_moneda.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN_TRABAJO",
                        entidad.imo_orden_trabajo.HasValue ? (object)entidad.imo_orden_trabajo.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@BODEGA_DESTINO",
                        entidad.imo_bodega_destino.HasValue ? (object)entidad.imo_bodega_destino.Value : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", (object)entidad.imo_observacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    string mensaje = "Movimiento registrado.";

                    using (SqlDataReader dr = Conexion.GetDataReader(cmdExecute))
                    {
                        if (dr.Read())
                        {
                            if (dr["MENSAJE"] != DBNull.Value) mensaje = dr["MENSAJE"].ToString();
                            if (dr["ID"] != DBNull.Value) respuesta.codigo = int.Parse(dr["ID"].ToString());
                        }
                    }

                    cmdExecute.Connection.Close();

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
