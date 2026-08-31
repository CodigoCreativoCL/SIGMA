using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Los planes comerciales y sus precios (ANEXO F §3).
    ///
    /// SE MANTIENEN DESDE LA WEB
    ///   Nacieron de solo lectura con el argumento de que la oferta se
    ///   cambia por script versionado. El argumento no se sostiene: quien
    ///   define los precios es el área comercial, no quien despliega, y
    ///   pedir un script para subir un plan convierte una decisión de
    ///   negocio en un ticket técnico.
    ///
    ///   Lo que sí había que preservar del script es que cambiar la lista
    ///   NO altere lo ya cotizado. Eso no lo garantizaba el script: lo
    ///   garantiza el versionado por vigencia, y de eso se encarga
    ///   FijarPrecio.
    /// </summary>
    public class PlanComercialController
    {
        public List<PlanComercial> GetPlanesComerciales(PlanComercial filtro = null)
        {
            List<PlanComercial> lista = new List<PlanComercial>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_COMERCIAL";

                    if (filtro != null)
                    {
                        if (filtro.plc_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.plc_id);
                        if (filtro.filtro_periodicidad != null && filtro.filtro_periodicidad > 0)
                            cmd.Parameters.AddWithValue("@PERIODICIDAD", filtro.filtro_periodicidad);
                        if (filtro.filtro_fecha != null)
                            cmd.Parameters.AddWithValue("@FECHA", filtro.filtro_fecha);
                        if (filtro.filtro_solo_publicos)
                            cmd.Parameters.AddWithValue("@SOLO_PUBLICOS", true);
                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanComercial item = new PlanComercial();

                            item.plc_id = int.Parse(dr["PLC_ID"].ToString());
                            item.plc_codigo = dr["PLC_CODIGO"].ToString();
                            item.plc_nombre = dr["PLC_NOMBRE"].ToString();
                            item.plc_descripcion = dr["PLC_DESCRIPCION"].ToString();
                            if (dr["PLC_DIAS_GRACIA"] != DBNull.Value)
                                item.plc_dias_gracia = int.Parse(dr["PLC_DIAS_GRACIA"].ToString());
                            item.plc_publico = bool.Parse(dr["PLC_PUBLICO"].ToString());
                            if (dr["PLC_ORDEN"] != DBNull.Value)
                                item.plc_orden = int.Parse(dr["PLC_ORDEN"].ToString());
                            item.plc_habilitado = bool.Parse(dr["PLC_HABILITADO"].ToString());

                            item.pcb_id = int.Parse(dr["PCB_ID"].ToString());
                            item.pcb_codigo = dr["PCB_CODIGO"].ToString();
                            item.pcb_nombre = dr["PCB_NOMBRE"].ToString();

                            item.pcp_id = int.Parse(dr["PCP_ID"].ToString());
                            item.pcp_valor_uf = decimal.Parse(dr["PCP_VALOR_UF"].ToString());
                            if (dr["PCP_DESCUENTO_PORCENTAJE"] != DBNull.Value)
                                item.pcp_descuento_porcentaje = decimal.Parse(dr["PCP_DESCUENTO_PORCENTAJE"].ToString());
                            if (dr["MONTO_CLP_REFERENCIAL"] != DBNull.Value)
                                item.monto_clp_referencial = decimal.Parse(dr["MONTO_CLP_REFERENCIAL"].ToString());
                            if (dr["VALOR_UF_DIA"] != DBNull.Value)
                                item.valor_uf_dia = decimal.Parse(dr["VALOR_UF_DIA"].ToString());

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

        /// <summary>
        /// Los planes SIN repetir por periodicidad, para llenar un combo.
        ///
        /// SEL_PLAN_COMERCIAL devuelve una fila por plan y periodicidad: el
        /// mismo plan aparece hasta tres veces. Bindear eso directo a un
        /// RadComboBox2 muestra "BÁSICO" tres veces y quien elija no sabrá
        /// cuál marcó.
        /// </summary>
        public List<PlanComercial> GetPlanesDistintos(bool soloHabilitados = true)
        {
            List<PlanComercial> planes = new List<PlanComercial>();

            PlanComercial filtro = new PlanComercial();
            if (soloHabilitados) filtro.filtro_habilitado = true;

            List<PlanComercial> lista = GetPlanesComerciales(filtro);

            if (lista == null) return planes;

            foreach (PlanComercial item in lista)
            {
                bool yaEsta = false;

                foreach (PlanComercial visto in planes)
                {
                    if (visto.plc_id == item.plc_id) { yaEsta = true; break; }
                }

                if (!yaEsta) planes.Add(item);
            }

            return planes;
        }

        /// <summary>
        /// Un plan por su id, sin repetir por periodicidad.
        /// </summary>
        public PlanComercial GetPlan(PlanComercial entidad)
        {
            List<PlanComercial> lista = GetPlanesComerciales(new PlanComercial { plc_id = entidad.plc_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new PlanComercial();
        }

        public Respuesta InsertPlan(PlanComercial entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_PLAN_COMERCIAL");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.plc_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.plc_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.plc_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", entidad.plc_orden);
                    cmdExecute.Parameters.AddWithValue("@DIAS_GRACIA", entidad.plc_dias_gracia);
                    cmdExecute.Parameters.AddWithValue("@PUBLICO", entidad.plc_publico);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Plan creado con éxito. Ahora fíjele un precio: sin precio vigente, ese plan no se vende.";
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
        /// El CÓDIGO no viaja: no se edita. Es la llave con la que los
        /// scripts de datos y cualquier integración futura identifican al
        /// plan, y renombrarlo desde un formulario rompería en silencio lo
        /// que lo referencie. Para eso está el nombre.
        /// </summary>
        public Respuesta UpdatePlan(PlanComercial entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_PLAN_COMERCIAL");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.plc_id);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.plc_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.plc_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", entidad.plc_orden);
                    cmdExecute.Parameters.AddWithValue("@DIAS_GRACIA", entidad.plc_dias_gracia);
                    cmdExecute.Parameters.AddWithValue("@PUBLICO", entidad.plc_publico);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.plc_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.plc_id;
                    respuesta.detalle = "Plan actualizado con éxito.";
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
        /// Da de baja el plan (T-2196, bloque 59).
        ///
        /// POR QUE NO ES UN UPD_PLAN_COMERCIAL CON @HABILITADO = 0
        ///   Porque ese camino no comprueba nada. Deshabilitar desde la
        ///   ficha un plan que un cliente está pagando lo deja apuntando a
        ///   algo deshabilitado, y la próxima emisión de período no sabría
        ///   qué cobrar. DEL_PLAN_COMERCIAL rechaza ese caso con el número
        ///   de suscripciones que lo impiden.
        ///
        ///   Y arrastra las partes del plan: precios y funcionalidades se
        ///   deshabilitan en la misma transacción. Dejarlas habilitadas
        ///   colgando de un plan que ya no se vende es basura que después
        ///   alguien lee como si valiera.
        ///
        /// El SP devuelve ID/CODE/MENSAJE; lo que rechaza llega por
        /// RAISERROR y sale por el catch, como en el resto del proyecto.
        /// </summary>
        public Respuesta DeletePlan(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PLAN_COMERCIAL");
                    cmdExecute.Parameters.AddWithValue("@ID", id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    string mensaje = "Plan dado de baja.";

                    using (SqlDataReader dr = Conexion.GetDataReader(cmdExecute))
                    {
                        if (dr.Read() && dr["MENSAJE"] != DBNull.Value)
                            mensaje = dr["MENSAJE"].ToString();
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
           PRECIOS
           ================================================================ */

        public List<PlanComercialPrecio> GetPrecios(PlanComercialPrecio filtro = null)
        {
            List<PlanComercialPrecio> lista = new List<PlanComercialPrecio>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_COMERCIAL_PRECIO";

                    if (filtro != null)
                    {
                        if (filtro.pcp_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.pcp_id);
                        if (filtro.filtro_plan != null && filtro.filtro_plan > 0)
                            cmd.Parameters.AddWithValue("@PLAN", filtro.filtro_plan);
                        if (filtro.filtro_periodicidad != null && filtro.filtro_periodicidad > 0)
                            cmd.Parameters.AddWithValue("@PERIODICIDAD", filtro.filtro_periodicidad);
                        if (filtro.filtro_solo_vigentes)
                            cmd.Parameters.AddWithValue("@SOLO_VIGENTES", true);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanComercialPrecio item = new PlanComercialPrecio();

                            item.pcp_id = int.Parse(dr["PCP_ID"].ToString());
                            item.pcp_plan_comercial = int.Parse(dr["PCP_PLAN_COMERCIAL"].ToString());
                            item.plc_codigo = dr["PLC_CODIGO"].ToString();
                            item.plc_nombre = dr["PLC_NOMBRE"].ToString();
                            item.pcp_periodicidad_cobro = int.Parse(dr["PCP_PERIODICIDAD_COBRO"].ToString());
                            item.pcb_codigo = dr["PCB_CODIGO"].ToString();
                            item.pcb_nombre = dr["PCB_NOMBRE"].ToString();
                            item.pcp_valor_uf = decimal.Parse(dr["PCP_VALOR_UF"].ToString());

                            if (dr["PCP_DESCUENTO_PORCENTAJE"] != DBNull.Value)
                                item.pcp_descuento_porcentaje = decimal.Parse(dr["PCP_DESCUENTO_PORCENTAJE"].ToString());

                            item.pcp_vigencia_desde = DateTime.Parse(dr["PCP_VIGENCIA_DESDE"].ToString());

                            // Nulo = precio abierto, el que rige hoy. int.Parse
                            // sobre esta columna es el error que ya volteo
                            // tres pantallas del sitio.
                            if (dr["PCP_VIGENCIA_HASTA"] != DBNull.Value)
                                item.pcp_vigencia_hasta = DateTime.Parse(dr["PCP_VIGENCIA_HASTA"].ToString());

                            item.pcp_habilitado = bool.Parse(dr["PCP_HABILITADO"].ToString());

                            if (dr["MONTO_CLP_REFERENCIAL"] != DBNull.Value)
                                item.monto_clp_referencial = decimal.Parse(dr["MONTO_CLP_REFERENCIAL"].ToString());

                            item.estado = dr["ESTADO"].ToString();

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

        /// <summary>
        /// FIJA el precio de un plan para una periodicidad. No lo edita:
        /// cierra el vigente con la fecha de ayer y abre uno nuevo.
        ///
        /// Un UPDATE sobre pcp_valor_uf borraría la historia y haría que un
        /// período emitido el mes pasado pareciera calculado con el precio
        /// de hoy. Los períodos ya emitidos no se tocan igual —guardan su
        /// propio número congelado— pero el precio tiene que poder
        /// explicarlos.
        /// </summary>
        public Respuesta FijarPrecio(PlanComercialPrecio entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("UPS_PLAN_COMERCIAL_PRECIO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@PLAN", entidad.pcp_plan_comercial);
                    cmdExecute.Parameters.AddWithValue("@PERIODICIDAD", entidad.pcp_periodicidad_cobro);
                    cmdExecute.Parameters.AddWithValue("@VALOR_UF", entidad.pcp_valor_uf);
                    cmdExecute.Parameters.AddWithValue("@DESCUENTO", (object)entidad.pcp_descuento_porcentaje ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DESDE", (object)entidad.vigencia_desde ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Precio fijado con éxito. El anterior queda cerrado, no borrado.";
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
        /// Retira una periodicidad de la venta. Baja lógica: la fila se
        /// conserva porque puede haber cotizado períodos que todavía se
        /// consultan. Sin fila vigente, esa combinación deja de venderse —y
        /// la ausencia de precio ES la regla del modelo, no un error.
        /// </summary>
        public Respuesta RetirarPrecio(PlanComercialPrecio entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PLAN_COMERCIAL_PRECIO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.pcp_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.pcp_id;
                    respuesta.detalle = "Precio retirado con éxito.";
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
           CONTENIDO DEL PLAN
           ================================================================ */

        /// <summary>
        /// Las 25 funcionalidades del plan, tengan o no fila.
        ///
        /// Devolver solo las que tienen fila obligaría a la pantalla a
        /// cruzar contra el catálogo para saber qué falta, y lo que falta
        /// es justamente lo interesante: sin fila la funcionalidad está
        /// NEGADA, y hay que verla para poder concederla.
        ///
        /// Con idCliente se pide la matriz EFECTIVA de ese cliente: donde
        /// tenga excepción se ve la excepción, y donde no, la regla del
        /// plan.
        /// </summary>
        public List<PlanFuncionalidad> GetFuncionalidades(int idPlan, int? idCliente = null)
        {
            List<PlanFuncionalidad> lista = new List<PlanFuncionalidad>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_FUNCIONALIDAD";
                    cmd.Parameters.AddWithValue("@PLAN", idPlan);

                    if (idCliente != null && idCliente > 0)
                        cmd.Parameters.AddWithValue("@CLIENTE", idCliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanFuncionalidad item = new PlanFuncionalidad();

                            item.fun_id = int.Parse(dr["FUN_ID"].ToString());
                            item.fun_codigo = dr["FUN_CODIGO"].ToString();
                            item.fun_nombre = dr["FUN_NOMBRE"].ToString();

                            if (dr["FUN_ORDEN"] != DBNull.Value)
                                item.fun_orden = int.Parse(dr["FUN_ORDEN"].ToString());

                            item.pcf_tipo = int.Parse(dr["PCF_TIPO"].ToString());
                            item.fnt_codigo = dr["FNT_CODIGO"].ToString();

                            // Cero cuando la funcionalidad no tiene fila.
                            if (dr["PCF_ID"] != DBNull.Value)
                                item.pcf_id = int.Parse(dr["PCF_ID"].ToString());

                            item.pcf_incluida = Convert.ToBoolean(dr["PCF_INCLUIDA"]);

                            // Nulo con la funcionalidad incluida = SIN TOPE.
                            if (dr["PCF_LIMITE"] != DBNull.Value)
                                item.pcf_limite = decimal.Parse(dr["PCF_LIMITE"].ToString());

                            if (dr["PCF_CLIENTE"] != DBNull.Value)
                                item.pcf_cliente = int.Parse(dr["PCF_CLIENTE"].ToString());

                            if (dr["PCF_VIGENCIA_HASTA"] != DBNull.Value)
                                item.pcf_vigencia_hasta = DateTime.Parse(dr["PCF_VIGENCIA_HASTA"].ToString());

                            item.pcf_observacion = dr["PCF_OBSERVACION"].ToString();
                            item.origen = dr["ORIGEN"].ToString();
                            item.caducada = Convert.ToBoolean(dr["CADUCADA"]);

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

        /// <summary>
        /// Concede o niega una funcionalidad en un plan, o le fija el tope.
        ///
        /// Con idCliente se está creando una EXCEPCIÓN para ese cliente, que
        /// gana sobre la regla del plan. Sin él, se cambia la regla para
        /// todos los que estén en ese plan.
        /// </summary>
        public Respuesta GuardarFuncionalidad(int idPlan, PlanFuncionalidad entidad, int? idCliente = null)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("UPS_PLAN_FUNCIONALIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@PLAN", idPlan);
                    cmdExecute.Parameters.AddWithValue("@FUNCIONALIDAD", entidad.fun_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", (object)idCliente ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@INCLUIDA", entidad.pcf_incluida);
                    cmdExecute.Parameters.AddWithValue("@LIMITE", (object)entidad.pcf_limite ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@VIGENCIA_HASTA", (object)entidad.pcf_vigencia_hasta ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", (object)entidad.pcf_observacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Contenido del plan actualizado con éxito.";
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
