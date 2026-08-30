using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Security.Cryptography;
using System.Text;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// La suscripción del cliente (ANEXO F §5 y §8).
    ///
    /// Una por cliente, para siempre. Renovar no crea otra: le emite otro
    /// período. Cambiar de plan tampoco: la modifica.
    ///
    /// EL ESTADO QUE SE MUESTRA NO ES EL QUE SE GUARDA
    ///   sue_nombre es lo que alguien decidió (activa, suspendida). estado
    ///   y puede_operar los calcula FNC_SUSCRIPCION_VIGENTE cada vez que se
    ///   consulta, porque VENCIDA y EN GRACIA dependen solo del calendario
    ///   (§6.1). Para decidir si alguien opera se mira puede_operar.
    /// </summary>
    public class SuscripcionController
    {
        public List<Suscripcion> GetSuscripciones(Suscripcion filtro = null)
        {
            List<Suscripcion> lista = new List<Suscripcion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_SUSCRIPCION";

                    if (filtro != null)
                    {
                        if (filtro.sus_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.sus_id);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0)
                            cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Suscripcion item = new Suscripcion();

                            item.sus_id = int.Parse(dr["SUS_ID"].ToString());
                            item.sus_cliente = int.Parse(dr["SUS_CLIENTE"].ToString());
                            item.cli_nombre = dr["CLI_NOMBRE"].ToString();
                            item.sus_key_prefijo = dr["SUS_KEY_PREFIJO"].ToString();
                            item.sus_suscripcion_estado = int.Parse(dr["SUS_SUSCRIPCION_ESTADO"].ToString());
                            item.sue_nombre = dr["SUE_NOMBRE"].ToString();

                            if (dr["SUS_PLAN_COMERCIAL"] != DBNull.Value)
                                item.sus_plan_comercial = int.Parse(dr["SUS_PLAN_COMERCIAL"].ToString());

                            item.plc_codigo = dr["PLC_CODIGO"].ToString();
                            item.plc_nombre = dr["PLC_NOMBRE"].ToString();

                            if (dr["SUS_FECHA_INICIO"] != DBNull.Value)
                                item.sus_fecha_inicio = DateTime.Parse(dr["SUS_FECHA_INICIO"].ToString());
                            if (dr["SUS_FECHA_FIN"] != DBNull.Value)
                                item.sus_fecha_fin = DateTime.Parse(dr["SUS_FECHA_FIN"].ToString());
                            if (dr["SUS_DIAS_GRACIA"] != DBNull.Value)
                                item.sus_dias_gracia = int.Parse(dr["SUS_DIAS_GRACIA"].ToString());

                            item.sus_contacto_nombre = dr["SUS_CONTACTO_NOMBRE"].ToString();
                            item.sus_contacto_email = dr["SUS_CONTACTO_EMAIL"].ToString();
                            item.sus_contacto_telefono = dr["SUS_CONTACTO_TELEFONO"].ToString();
                            item.sus_observacion = dr["SUS_OBSERVACION"].ToString();
                            item.sus_habilitado = bool.Parse(dr["SUS_HABILITADO"].ToString());

                            item.estado = dr["ESTADO"].ToString();

                            // DIAS_RESTANTES y PUEDE_OPERAR son NULL cuando la
                            // suscripcion no tiene ningun periodo emitido.
                            if (dr["DIAS_RESTANTES"] != DBNull.Value)
                                item.dias_restantes = int.Parse(dr["DIAS_RESTANTES"].ToString());
                            if (dr["PUEDE_OPERAR"] != DBNull.Value)
                                item.puede_operar = Convert.ToBoolean(dr["PUEDE_OPERAR"]);

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

        public Suscripcion GetSuscripcion(Suscripcion entidad)
        {
            Suscripcion filtro = new Suscripcion();

            if (entidad.sus_id > 0) filtro.sus_id = entidad.sus_id;
            else filtro.filtro_cliente = entidad.sus_cliente;

            List<Suscripcion> lista = GetSuscripciones(filtro);
            return (lista != null && lista.Count > 0) ? lista[0] : new Suscripcion();
        }

        /// <summary>
        /// Crea la suscripción y deja la clave EN CLARO en
        /// entidad.key_texto — la única vez que se puede ver.
        ///
        /// La base solo guarda el prefijo visible y el hash del resto. Si
        /// quien la crea no la copia ahora, no hay forma de recuperarla:
        /// hay que emitir una nueva. Es incómodo a propósito, y es la misma
        /// razón por la que las contraseñas dejaron de estar en texto
        /// plano en el bloque 26.
        /// </summary>
        public Respuesta InsertSuscripcion(Suscripcion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    string prefijo;
                    string clave = GenerarClave(out prefijo);

                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_SUSCRIPCION");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.sus_cliente);
                    cmdExecute.Parameters.AddWithValue("@PLAN_COMERCIAL", entidad.sus_plan_comercial);
                    cmdExecute.Parameters.AddWithValue("@KEY_PREFIJO", prefijo);
                    cmdExecute.Parameters.AddWithValue("@KEY_TEXTO", clave);
                    cmdExecute.Parameters.AddWithValue("@CONTACTO_NOMBRE", (object)entidad.sus_contacto_nombre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CONTACTO_EMAIL", (object)entidad.sus_contacto_email ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CONTACTO_TELEFONO", (object)entidad.sus_contacto_telefono ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", (object)entidad.sus_observacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Suscripción creada con éxito.";
                    respuesta.error = false;

                    // De vuelta al llamador, para mostrarla una sola vez.
                    entidad.key_texto = clave;
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
        /// Contacto, observación, estado y habilitado. El PLAN no se cambia
        /// por acá: tiene consecuencias de cobro y va por CambiarPlan.
        /// </summary>
        public Respuesta UpdateSuscripcion(Suscripcion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_SUSCRIPCION");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.sus_id);
                    cmdExecute.Parameters.AddWithValue("@ESTADO", entidad.sus_suscripcion_estado);
                    cmdExecute.Parameters.AddWithValue("@CONTACTO_NOMBRE", (object)entidad.sus_contacto_nombre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CONTACTO_EMAIL", (object)entidad.sus_contacto_email ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CONTACTO_TELEFONO", (object)entidad.sus_contacto_telefono ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", (object)entidad.sus_observacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.sus_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.sus_id;
                    respuesta.detalle = "Suscripción actualizada con éxito.";
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

        /// <summary>
        /// Sube o baja de plan (§8). Quién decide cuál de las dos cosas es,
        /// lo hace el SP comparando plc_orden — no el usuario ni esta capa.
        ///
        /// Upgrade: inmediato. Cierra el período vigente y emite uno nuevo
        /// por los días que faltaban, cobrando solo la diferencia
        /// prorrateada. respuesta.codigo trae ese período nuevo.
        ///
        /// Downgrade: se anota y se aplica al cierre del período. No hay
        /// devolución, y respuesta.codigo queda en cero porque no se emitió
        /// nada.
        /// </summary>
        public Respuesta CambiarPlan(Suscripcion entidad, int planNuevo, int? periodicidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPS_SUSCRIPCION_PLAN");
                    cmdExecute.Parameters.AddWithValue("@SUSCRIPCION", entidad.sus_id);
                    cmdExecute.Parameters.AddWithValue("@PLAN_NUEVO", planNuevo);
                    cmdExecute.Parameters.AddWithValue("@PERIODICIDAD", (object)periodicidad ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    SqlParameter pPeriodo = cmdExecute.Parameters.Add("@PERIODO_NUEVO", System.Data.SqlDbType.Int);
                    pPeriodo.Direction = System.Data.ParameterDirection.Output;

                    SqlParameter pMovimiento = cmdExecute.Parameters.Add("@MOVIMIENTO", System.Data.SqlDbType.NVarChar, 20);
                    pMovimiento.Direction = System.Data.ParameterDirection.Output;

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    string movimiento = (pMovimiento.Value == DBNull.Value) ? "" : pMovimiento.Value.ToString();

                    respuesta.codigo = (pPeriodo.Value == DBNull.Value) ? 0 : (int)pPeriodo.Value;
                    respuesta.error = false;

                    if (movimiento == "DOWNGRADE")
                    {
                        respuesta.detalle = "Cambio de plan registrado. Al ser una baja de plan, " +
                                            "se aplica al cierre del período vigente y no genera devolución.";
                    }
                    else if (respuesta.codigo > 0)
                    {
                        respuesta.detalle = "Plan actualizado con éxito. Se emitió un período por la " +
                                            "diferencia prorrateada de los días que quedaban.";
                    }
                    else
                    {
                        respuesta.detalle = "Plan actualizado con éxito. No había período vigente que " +
                                            "prorratear: el próximo se emite con el plan nuevo.";
                    }
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
        /// Reemite la clave. Deja la nueva EN CLARO en entidad.key_texto —
        /// la única vez que se puede ver.
        ///
        /// POR QUÉ NO EXISTE "REENVIAR"
        ///   Porque la clave no está guardada en claro en ninguna parte:
        ///   solo el prefijo visible y el hash del resto. Recuperarla es
        ///   tan imposible como recuperar la contraseña de alguien, y por
        ///   la misma razón. Lo único honesto que se puede ofrecer es
        ///   generar una nueva.
        ///
        /// ESTO CORTA ALGO QUE FUNCIONABA
        ///   La clave anterior deja de servir en el momento. Si el cliente
        ///   la tenía configurada en su instalación o en la app, esa
        ///   integración se cae hasta que le carguen la nueva. Por eso el
        ///   motivo es obligatorio y queda en la observación: dentro de seis
        ///   meses alguien va a preguntar por qué se cortó.
        /// </summary>
        public Respuesta ReemitirKey(Suscripcion entidad, string motivo)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    if (string.IsNullOrEmpty(motivo) || motivo.Trim().Length < 5)
                        throw new Exception("Indique el motivo de la reemisión.");

                    string prefijo;
                    string clave = GenerarClave(out prefijo);

                    cmdExecute = Conexion.GetCommand("UPD_SUSCRIPCION_KEY");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.sus_id);
                    cmdExecute.Parameters.AddWithValue("@KEY_PREFIJO", prefijo);
                    cmdExecute.Parameters.AddWithValue("@KEY_TEXTO", clave);
                    cmdExecute.Parameters.AddWithValue("@MOTIVO", motivo.Trim());
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    // De vuelta al llamador, para mostrarla una sola vez.
                    entidad.key_texto = clave;

                    respuesta.codigo = entidad.sus_id;
                    respuesta.detalle = "Clave reemitida con éxito. La anterior ya no sirve.";
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
        /// Genera la clave de suscripción. Devuelve el texto completo y,
        /// por parámetro de salida, el prefijo que sí se guarda visible.
        ///
        /// El alfabeto omite I, O, 0, 1 y L. Estas claves se dictan por
        /// teléfono en soporte, y ahí una O y un cero son la misma letra.
        ///
        /// Los bytes salen de RNGCryptoServiceProvider y no de Random:
        /// Random se siembra con el reloj, así que dos suscripciones
        /// creadas en el mismo instante saldrían iguales.
        /// </summary>
        private string GenerarClave(out string prefijo)
        {
            const string ALFABETO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

            byte[] bytes = new byte[24];

            using (RNGCryptoServiceProvider rng = new RNGCryptoServiceProvider())
            {
                rng.GetBytes(bytes);
            }

            StringBuilder sb = new StringBuilder();

            for (int i = 0; i < bytes.Length; i++)
            {
                if (i > 0 && i % 6 == 0) sb.Append('-');
                sb.Append(ALFABETO[bytes[i] % ALFABETO.Length]);
            }

            // SIG-XXXX: suficiente para reconocerla en soporte, insuficiente
            // para reconstruirla.
            prefijo = "SIG-" + sb.ToString().Substring(0, 4);

            return prefijo + "-" + sb.ToString();
        }

        #region Bloque D — el estado que decide si el cliente puede operar

        /// <summary>
        /// El estado de la suscripción de un cliente (HU-193).
        ///
        /// Lo consulta la web, que conoce el cliente en sesión pero no la
        /// clave. El SP busca la clave y se la pasa a
        /// FNC_SUSCRIPCION_VIGENTE: la regla vive en un solo lugar, el
        /// mismo que usa la API. Copiarla aquí garantizaría que algún día
        /// la web y la app dijeran cosas distintas del mismo cliente.
        ///
        /// NO exige Token.TokenSeguridad(): lo llama el master en cada
        /// petición, incluida la de alguien cuya sesión acaba de expirar.
        /// Es una consulta de solo lectura sobre el cliente que ya está en
        /// la sesión.
        /// </summary>
        public SuscripcionEstadoCliente GetEstadoCliente(int idCliente)
        {
            SuscripcionEstadoCliente estado = null;
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_SUSCRIPCION_ESTADO_CLIENTE";
                cmd.Parameters.AddWithValue("@CLIENTE", idCliente);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        estado = new SuscripcionEstadoCliente();

                        estado.cliente = idCliente;
                        estado.estado = dr["ESTADO"].ToString();
                        estado.puede_operar = dr["PUEDE_OPERAR"] != DBNull.Value
                                              && Convert.ToBoolean(dr["PUEDE_OPERAR"]);
                        estado.avisar = dr["AVISAR"] != DBNull.Value
                                        && Convert.ToBoolean(dr["AVISAR"]);

                        if (dr["SUSCRIPCION"] != DBNull.Value)
                            estado.suscripcion = int.Parse(dr["SUSCRIPCION"].ToString());
                        if (dr["PLAN_COMERCIAL"] != DBNull.Value)
                            estado.plan_comercial = int.Parse(dr["PLAN_COMERCIAL"].ToString());
                        if (dr["FECHA_FIN"] != DBNull.Value)
                            estado.fecha_fin = DateTime.Parse(dr["FECHA_FIN"].ToString());
                        if (dr["DIAS_RESTANTES"] != DBNull.Value)
                            estado.dias_restantes = int.Parse(dr["DIAS_RESTANTES"].ToString());
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception ex)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();

                /* Si no se puede resolver el estado, se devuelve null y la
                   compuerta deja pasar. Es deliberado: un problema de
                   consulta no puede dejar a un cliente al día fuera de su
                   sistema. Bloquear ante la duda castiga al que paga. */
                estado = null;
            }

            return estado;
        }

        /// <summary>
        /// Deja constancia de un rechazo por suscripción (ANEXO F §6.7).
        ///
        /// Es lo que permite responder "¿desde cuándo no puede entrar este
        /// cliente?" cuando llama enojado, en vez de adivinar.
        /// </summary>
        public void RegistrarBloqueo(int idCliente, string estadoSuscripcion, string endpoint, string ip, int idUsuario)
        {
            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("INS_SUSCRIPCION_BLOQUEO_LOG");
                cmd.Parameters.AddWithValue("@CLIENTE", idCliente);
                cmd.Parameters.AddWithValue("@ESTADO", (object)estadoSuscripcion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@ORIGEN", "WEB");
                cmd.Parameters.AddWithValue("@ENDPOINT", (object)endpoint ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@IP", (object)ip ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", idUsuario > 0 ? (object)idUsuario : DBNull.Value);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
            }
            catch (Exception ex)
            {
                // No poder registrar el bloqueo no debe cambiar el bloqueo.
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
        }

        /// <summary>
        /// Los cuatro topes del plan con su consumo (HU-193). Alimenta el
        /// panel que deja ver "4 de 5 usuarios" ANTES de intentar crear el
        /// sexto.
        /// </summary>
        public List<ClienteLimite> GetLimites(int idCliente)
        {
            List<ClienteLimite> lista = new List<ClienteLimite>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_LIMITE";
                    cmd.Parameters.AddWithValue("@CLIENTE", idCliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ClienteLimite item = new ClienteLimite();

                            item.fun_codigo = dr["FUN_CODIGO"].ToString();
                            item.fun_nombre = dr["FUN_NOMBRE"].ToString();
                            item.incluida = bool.Parse(dr["INCLUIDA"].ToString());
                            item.puede_crear = bool.Parse(dr["PUEDE_CREAR"].ToString());
                            item.estado = dr["ESTADO"].ToString();
                            item.consumo = decimal.Parse(dr["CONSUMO"].ToString());

                            // TOPE y DISPONIBLE en nulo significan "sin
                            // tope" o "sin plan todavía", no cero.
                            if (dr["TOPE"] != DBNull.Value)
                                item.tope = decimal.Parse(dr["TOPE"].ToString());
                            if (dr["DISPONIBLE"] != DBNull.Value)
                                item.disponible = decimal.Parse(dr["DISPONIBLE"].ToString());

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

        #endregion
    }
}
