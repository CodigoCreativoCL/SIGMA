using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Algo que se paso a revisar en el equipo: una inspeccion de pauta o una
    /// tarea. Van en la misma clase porque en terreno son la misma cosa.
    /// </summary>
    [Serializable]
    /// <summary>
    /// Lo que la tarjeta del contador necesita y no estaba en Activo_Medidor:
    /// de donde vino la ultima lectura y a que valor esta citado el proximo
    /// mantenimiento (bloque 277).
    /// </summary>
    public class ActivoMedidorResumen
    {
        public int id { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
        public decimal valor { get; set; }
        public string unidad { get; set; }
        public string componente { get; set; }
        public DateTime? fecha { get; set; }
        public string origen { get; set; }

        /* Sin plan por uso los tres quedan nulos: la tarjeta dice "sin
           mantenimiento asociado" en vez de inventar una cuenta regresiva. */
        public decimal? objetivo { get; set; }
        public decimal? falta { get; set; }
        public string plan_nombre { get; set; }
    }

    public class ActivoRevision
    {
        public string tipo { get; set; }              // INSPECCION | TAREA
        public int ocurrencia_id { get; set; }
        public int? ejecucion_id { get; set; }
        public string nombre { get; set; }
        public string descripcion { get; set; }
        public string codigo { get; set; }
        public DateTime? fecha { get; set; }
        public DateTime? programada { get; set; }
        public string estado_codigo { get; set; }
        public string estado_nombre { get; set; }
        public string resultado_codigo { get; set; }
        public string responsable { get; set; }
        public int item_total { get; set; }
        public int item_respondido { get; set; }
        public int item_no_conforme { get; set; }
        public string observacion { get; set; }
        public string dispositivo { get; set; }
        public int evidencias { get; set; }

        public bool es_inspeccion { get { return tipo == "INSPECCION"; } }
        public bool ejecutada { get { return ejecucion_id != null; } }

        /// <summary>
        /// El resultado tecnico en palabras. Es distinto del estado: una
        /// inspeccion puede estar completada y con hallazgos.
        /// </summary>
        public string resultado_nombre
        {
            get
            {
                if (resultado_codigo == "CONFORME") return "Sin observaciones";
                if (resultado_codigo == "CON_OBSERVACION") return "Con observación";
                return "Sin evaluar";
            }
        }

        /// <summary>
        /// De donde salio el registro. La app graba el modelo del telefono;
        /// sin dispositivo no se inventa un origen.
        /// </summary>
        public string origen
        {
            get
            {
                if (ejecucion_id == null) return "";
                return string.IsNullOrEmpty(dispositivo) ? "No informado" : "App móvil";
            }
        }
    }

    /// <summary>Un repuesto que salio de bodega para este equipo.</summary>
    [Serializable]
    public class ActivoConsumo
    {
        public int ore_id { get; set; }
        public int repuesto_id { get; set; }
        public string repuesto_codigo { get; set; }
        public string repuesto_nombre { get; set; }
        public string unidad { get; set; }
        public string componente { get; set; }
        public int? componente_id { get; set; }
        public decimal cantidad { get; set; }
        public decimal devuelta { get; set; }
        public decimal costo_unitario { get; set; }
        public decimal costo { get; set; }
        public string moneda { get; set; }
        public int orden_id { get; set; }
        public int orden_correlativo { get; set; }
        public string orden_titulo { get; set; }
        public DateTime? fecha { get; set; }
        public string usuario { get; set; }

        public string orden_codigo { get { return "OT-" + orden_correlativo; } }

        /// <summary>
        /// Un consumo sin costo unitario no es gratis: es un costo que nadie
        /// cargo. La pantalla lo dice asi para no sumar ceros como si fueran
        /// precios.
        /// </summary>
        public bool costo_registrado { get { return costo_unitario > 0; } }
    }

    /// <summary>Los tres totales del equipo en el periodo.</summary>
    [Serializable]
    public class ActivoCosto
    {
        public int ordenes { get; set; }
        public decimal material { get; set; }
        public int lineas_material { get; set; }
        public decimal mano_obra { get; set; }
        public int minutos_mano_obra { get; set; }
        public decimal servicio { get; set; }
        public int lineas_servicio { get; set; }

        public decimal total { get { return material + mano_obra + servicio; } }

        /// <summary>
        /// Hay algo cargado sin precio: horas sin costo hora, o consumos sin
        /// costo unitario. Mientras sea cierto, el total es un piso y no una
        /// cifra.
        /// </summary>
        public bool incompleto
        {
            get
            {
                return (minutos_mano_obra > 0 && mano_obra <= 0)
                    || (lineas_material > 0 && material <= 0);
            }
        }
    }

    /// <summary>Una anotacion de bitacora sobre el equipo.</summary>
    [Serializable]
    public class ActivoBitacora
    {
        public int bit_id { get; set; }
        public string tipo_codigo { get; set; }
        public string tipo_nombre { get; set; }
        public string tipo_icono { get; set; }
        public string titulo { get; set; }
        public string texto { get; set; }
        public DateTime? fecha { get; set; }
        public string turno { get; set; }
        public bool requiere_atencion { get; set; }
        public string severidad_codigo { get; set; }
        public string severidad_nombre { get; set; }
        public string componente { get; set; }
        public int? orden_id { get; set; }
        public int orden_correlativo { get; set; }
        public string origen { get; set; }
        public bool offline { get; set; }
        public DateTime? sincronizacion { get; set; }
        public bool dictado { get; set; }
        public string usuario { get; set; }
        public DateTime? registro { get; set; }

        public string etiqueta { get { return !string.IsNullOrEmpty(titulo) ? titulo : tipo_nombre; } }

        /// <summary>
        /// Se escribio sin conexion y llego despues. Importa para auditar: la
        /// fecha del evento y la de llegada no son la misma, y eso es
        /// exactamente lo que se revisa cuando algo no cuadra.
        /// </summary>
        public bool llego_tarde
        {
            get { return offline && fecha != null && sincronizacion != null && sincronizacion.Value > fecha.Value.AddHours(1); }
        }
    }

    /// <summary>
    /// Lo que la lista de equipos necesita saber de cada uno y no esta en su
    /// ficha: cuanto trabajo tiene encima y cuando le toca lo proximo.
    /// </summary>
    [Serializable]
    public class ActivoResumenLista
    {
        public int activo_id { get; set; }
        public int ot_abiertas { get; set; }
        public int fallas_abiertas { get; set; }
        public int detencion_abierta { get; set; }
        public DateTime? proxima_mantencion { get; set; }
        public int? imagen_id { get; set; }

        /// <summary>
        /// Lo que obliga a mirar este equipo antes que los otros: una falla
        /// sin resolver o una detencion abierta. Tener ordenes abiertas NO
        /// es atencion: un equipo con plan siempre las tiene.
        /// </summary>
        public bool requiere_atencion { get { return fallas_abiertas > 0 || detencion_abierta > 0; } }
    }

    /// <summary>
    /// Las cuatro preguntas que el centro del activo hace al reves de como
    /// pregunta el resto del sistema: dado UN equipo, que se le reviso, que se
    /// le cambio, cuanto costo y que se anoto de el.
    ///
    /// POR QUE NO SIRVEN LOS CONTROLADORES QUE YA EXISTEN
    ///   ChecklistCentroController lee por plantilla, TareaOcurrenciaController
    ///   por tarea y OrdenTrabajoRecursoController por orden. Armar la ficha
    ///   con ellos obliga a una llamada por orden: el equipo con mas historia
    ///   seria el mas lento de abrir. Estos leen por ACTIVO (bloque 267).
    /// </summary>
    public class ActivoCentroController
    {
        /// <summary>Bitacora_Tipo 1 = OBSERVACION, lo que deja la web.</summary>
        private const int TIPO_OBSERVACION = 1;

        /// <summary>
        /// El resumen de TODOS los equipos del cliente, en una consulta.
        ///
        /// POR QUE NO SE PIDE POR ACTIVO
        ///   Ordenes, fallas, detencion, proxima mantencion e imagen son cinco
        ///   preguntas. Por cuarenta y siete equipos son casi doscientas
        ///   consultas para pintar una lista, y el cliente con mas equipos
        ///   seria el mas lento de atender.
        /// </summary>
        public Dictionary<int, ActivoResumenLista> GetResumenLista()
        {
            Dictionary<int, ActivoResumenLista> mapa = new Dictionary<int, ActivoResumenLista>();

            if (!Token.TokenSeguridad()) return mapa;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ACTIVO_LISTA_RESUMEN";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ActivoResumenLista r = new ActivoResumenLista();

                        r.activo_id = int.Parse(dr["ACTIVO_ID"].ToString());
                        r.ot_abiertas = int.Parse(dr["OT_ABIERTAS"].ToString());
                        r.fallas_abiertas = int.Parse(dr["FALLAS_ABIERTAS"].ToString());
                        r.detencion_abierta = int.Parse(dr["DETENCION_ABIERTA"].ToString());
                        if (dr["PROXIMA_MANTENCION"] != DBNull.Value) r.proxima_mantencion = (DateTime)dr["PROXIMA_MANTENCION"];
                        if (dr["IMAGEN_ID"] != DBNull.Value) r.imagen_id = int.Parse(dr["IMAGEN_ID"].ToString());

                        mapa[r.activo_id] = r;
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return mapa;
        }

        /// <summary>Inspecciones y tareas del equipo, lo ejecutado y lo pendiente.</summary>
        /// <summary>
        /// Los contadores del activo, con su proximo mantenimiento por uso.
        ///
        /// Va por SP y no por el controlador de medidores porque el dato que
        /// falta -cuanto falta para el proximo hito- vive en la ocurrencia del
        /// plan, a tres tablas de distancia del contador.
        /// </summary>
        public List<ActivoMedidorResumen> GetResumenMedidores(int activo)
        {
            List<ActivoMedidorResumen> lista = new List<ActivoMedidorResumen>();

            if (!Token.TokenSeguridad() || activo <= 0) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ACTIVO_MEDIDOR_RESUMEN";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO", activo);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ActivoMedidorResumen m = new ActivoMedidorResumen();

                        m.id = int.Parse(dr["ID"].ToString());
                        m.codigo = dr["CODIGO"] == DBNull.Value ? "" : dr["CODIGO"].ToString();
                        m.nombre = dr["NOMBRE"] == DBNull.Value ? "" : dr["NOMBRE"].ToString();
                        m.valor = decimal.Parse(dr["VALOR"].ToString());
                        m.unidad = dr["UNIDAD"] == DBNull.Value ? "" : dr["UNIDAD"].ToString();
                        m.componente = dr["COMPONENTE"] == DBNull.Value ? "" : dr["COMPONENTE"].ToString();
                        m.origen = dr["ORIGEN"] == DBNull.Value ? "" : dr["ORIGEN"].ToString();
                        m.plan_nombre = dr["PLAN_NOMBRE"] == DBNull.Value ? "" : dr["PLAN_NOMBRE"].ToString();

                        if (dr["FECHA"] != DBNull.Value) m.fecha = (DateTime)dr["FECHA"];
                        if (dr["OBJETIVO"] != DBNull.Value) m.objetivo = decimal.Parse(dr["OBJETIVO"].ToString());
                        if (dr["FALTA"] != DBNull.Value) m.falta = decimal.Parse(dr["FALTA"].ToString());

                        lista.Add(m);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        /// <summary>
        /// Anota una medicion de condicion escrita a mano en la web.
        ///
        /// POR QUE USA EL SP DE LA APP
        ///   API_INS_ACTIVO_MEDICION es el unico que sabe calcular el valor
        ///   canonico y comparar contra los umbrales de la variable. Escribir
        ///   la fila por otro lado dejaria una medicion que el semaforo no
        ///   sabe leer.
        ///
        ///   El origen queda MANUAL (3) y el modo TECLADO (1): despues importa
        ///   saber que ese numero lo escribio una persona y no un sensor.
        /// </summary>
        public Respuesta RegistrarMedicion(int variable, decimal valor, DateTime fecha, string observacion)
        {
            Respuesta r = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                r.codigo = -1;
                r.detalle = "La sesión no es válida o expiró. Vuelva a entrar y repita la operación.";
                r.error = true;
                return r;
            }

            ActivoVariable v = new ActivoVariableController().GetVariable(variable);

            if (v == null || v.ava_id == 0)
            {
                r.codigo = -1;
                r.detalle = "La variable no existe o no está disponible.";
                r.error = true;
                return r;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("API_INS_ACTIVO_MEDICION");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO_VARIABLE", variable);
                cmd.Parameters.AddWithValue("@VALOR", valor);
                cmd.Parameters.AddWithValue("@FECHA_MEDICION_UTC", fecha);
                cmd.Parameters.AddWithValue("@UNIDAD_MEDIDA", (object)v.ava_unidad_medida ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@ACTIVO_COMPONENTE", (object)v.ava_activo_componente ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@ORDEN_TRABAJO", DBNull.Value);
                cmd.Parameters.AddWithValue("@OBSERVACION", (object)observacion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@ENTRADA_MODO", 1);
                cmd.Parameters.AddWithValue("@UUID", Guid.NewGuid());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                r.codigo = cmd.Parameters["@ID"].Value == DBNull.Value ? 0 : (int)cmd.Parameters["@ID"].Value;
                r.detalle = "Lectura registrada.";
                r.error = false;
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

        /// <summary>
        /// Anota la lectura de un contador escrita a mano en la web.
        ///
        /// El contador acumula: el SP rechaza un valor menor al que ya tiene a
        /// menos que se declare reinicio, y de ahi sale la generacion de
        /// ocurrencias por uso. Por eso tampoco se escribe la fila a mano.
        /// </summary>
        public Respuesta RegistrarLecturaMedidor(int medidor, decimal valor, DateTime fecha, string observacion, bool esReinicio)
        {
            Respuesta r = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                r.codigo = -1;
                r.detalle = "La sesión no es válida o expiró. Vuelva a entrar y repita la operación.";
                r.error = true;
                return r;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("API_INS_ACTIVO_MEDIDOR_LECTURA");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO_MEDIDOR", medidor);
                cmd.Parameters.AddWithValue("@VALOR_ACUMULADO", valor);
                cmd.Parameters.AddWithValue("@FECHA_LECTURA_UTC", fecha);
                cmd.Parameters.AddWithValue("@ES_REINICIO", esReinicio);
                cmd.Parameters.AddWithValue("@ORDEN_TRABAJO", DBNull.Value);
                cmd.Parameters.AddWithValue("@OBSERVACION", (object)observacion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@ENTRADA_MODO", 1);
                cmd.Parameters.AddWithValue("@UUID", Guid.NewGuid());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                r.codigo = cmd.Parameters["@ID"].Value == DBNull.Value ? 0 : (int)cmd.Parameters["@ID"].Value;
                r.detalle = "Lectura registrada.";
                r.error = false;
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

        public List<ActivoRevision> GetRevisiones(int activo, DateTime? desde = null, DateTime? hasta = null)
        {
            List<ActivoRevision> lista = new List<ActivoRevision>();

            if (activo <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ACTIVO_INSPECCION_TAREA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO", activo);
                if (desde != null) cmd.Parameters.AddWithValue("@DESDE", desde.Value);
                if (hasta != null) cmd.Parameters.AddWithValue("@HASTA", hasta.Value);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ActivoRevision r = new ActivoRevision();

                        r.tipo = dr["TIPO"].ToString();
                        r.ocurrencia_id = int.Parse(dr["OCURRENCIA_ID"].ToString());
                        if (dr["EJECUCION_ID"] != DBNull.Value) r.ejecucion_id = int.Parse(dr["EJECUCION_ID"].ToString());
                        r.nombre = dr["NOMBRE"].ToString();
                        r.descripcion = dr["DESCRIPCION"].ToString();
                        r.codigo = dr["CODIGO"].ToString();
                        if (dr["FECHA"] != DBNull.Value) r.fecha = (DateTime)dr["FECHA"];
                        if (dr["FECHA_PROGRAMADA"] != DBNull.Value) r.programada = (DateTime)dr["FECHA_PROGRAMADA"];
                        r.estado_codigo = dr["ESTADO_CODIGO"].ToString();
                        r.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                        r.resultado_codigo = dr["RESULTADO_CODIGO"].ToString();
                        r.responsable = dr["RESPONSABLE_NOMBRE"].ToString();
                        r.item_total = int.Parse(dr["ITEM_TOTAL"].ToString());
                        r.item_respondido = int.Parse(dr["ITEM_RESPONDIDO"].ToString());
                        r.item_no_conforme = int.Parse(dr["ITEM_NO_CONFORME"].ToString());
                        r.observacion = dr["OBSERVACION"].ToString();
                        r.dispositivo = dr["DISPOSITIVO"].ToString();
                        r.evidencias = int.Parse(dr["EVIDENCIAS"].ToString());

                        lista.Add(r);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        /// <summary>Lo que salio de bodega para este equipo, en todas sus ordenes.</summary>
        public List<ActivoConsumo> GetConsumos(int activo, DateTime? desde = null, DateTime? hasta = null)
        {
            List<ActivoConsumo> lista = new List<ActivoConsumo>();

            if (activo <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ACTIVO_REPUESTO_CONSUMO";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO", activo);
                if (desde != null) cmd.Parameters.AddWithValue("@DESDE", desde.Value);
                if (hasta != null) cmd.Parameters.AddWithValue("@HASTA", hasta.Value);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ActivoConsumo c = new ActivoConsumo();

                        c.ore_id = int.Parse(dr["ore_id"].ToString());
                        if (dr["ore_repuesto"] != DBNull.Value) c.repuesto_id = int.Parse(dr["ore_repuesto"].ToString());
                        c.repuesto_codigo = dr["REPUESTO_CODIGO"].ToString();
                        c.repuesto_nombre = dr["REPUESTO_NOMBRE"].ToString();
                        c.unidad = dr["UNIDAD"].ToString();
                        c.componente = dr["COMPONENTE"].ToString();
                        if (dr["COMPONENTE_ID"] != DBNull.Value) c.componente_id = int.Parse(dr["COMPONENTE_ID"].ToString());
                        c.cantidad = decimal.Parse(dr["CANTIDAD"].ToString());
                        c.devuelta = decimal.Parse(dr["DEVUELTA"].ToString());
                        c.costo_unitario = decimal.Parse(dr["COSTO_UNITARIO"].ToString());
                        c.costo = decimal.Parse(dr["COSTO"].ToString());
                        c.moneda = dr["MONEDA"].ToString();
                        c.orden_id = int.Parse(dr["ORDEN_ID"].ToString());
                        c.orden_correlativo = int.Parse(dr["ORDEN_CORRELATIVO"].ToString());
                        c.orden_titulo = dr["ORDEN_TITULO"].ToString();
                        if (dr["FECHA"] != DBNull.Value) c.fecha = (DateTime)dr["FECHA"];
                        c.usuario = dr["USUARIO_NOMBRE"].ToString();

                        lista.Add(c);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        /// <summary>Materiales, mano de obra y servicios del equipo en el periodo.</summary>
        public ActivoCosto GetCostos(int activo, DateTime? desde = null, DateTime? hasta = null)
        {
            ActivoCosto c = new ActivoCosto();

            if (activo <= 0 || !Token.TokenSeguridad()) return c;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ACTIVO_COSTO_RESUMEN";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO", activo);
                if (desde != null) cmd.Parameters.AddWithValue("@DESDE", desde.Value);
                if (hasta != null) cmd.Parameters.AddWithValue("@HASTA", hasta.Value);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        c.ordenes = int.Parse(dr["ORDENES"].ToString());
                        c.material = decimal.Parse(dr["COSTO_MATERIAL"].ToString());
                        c.lineas_material = int.Parse(dr["LINEAS_MATERIAL"].ToString());
                        c.mano_obra = decimal.Parse(dr["COSTO_MANO_OBRA"].ToString());
                        c.minutos_mano_obra = int.Parse(dr["MINUTOS_MANO_OBRA"].ToString());
                        c.servicio = decimal.Parse(dr["COSTO_SERVICIO"].ToString());
                        c.lineas_servicio = int.Parse(dr["LINEAS_SERVICIO"].ToString());
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return c;
        }

        /// <summary>
        /// Deja una observacion en la bitacora del equipo.
        ///
        /// Se usa el MISMO procedimiento que la app -API_INS_BITACORA- y no uno
        /// nuevo para la web: si hubiera dos caminos de escritura, la bitacora
        /// tendria dos formatos y la auditoria dejaria de servir. Lo unico que
        /// cambia es el modo de entrada, que queda grabado como Web.
        ///
        /// El UUID lo pone el cliente y el SP es idempotente por ese campo: un
        /// doble clic en Publicar no deja dos veces la misma observacion.
        /// </summary>
        public Respuesta AgregarObservacion(int activo, int instalacion, int? area, string texto)
        {
            Respuesta r = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                r.codigo = -1;
                r.detalle = "La sesión no es válida o expiró. Vuelva a entrar y repita la operación.";
                r.error = true;
                return r;
            }

            if (string.IsNullOrEmpty(texto) || texto.Trim().Length == 0)
            {
                r.codigo = -1;
                r.detalle = "Escriba la observación antes de publicarla.";
                r.error = true;
                return r;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("API_INS_BITACORA");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@UUID", Guid.NewGuid());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@INSTALACION", instalacion);
                cmd.Parameters.AddWithValue("@TIPO", TIPO_OBSERVACION);
                cmd.Parameters.AddWithValue("@TEXTO", texto.Trim());
                cmd.Parameters.AddWithValue("@TITULO", DBNull.Value);
                cmd.Parameters.AddWithValue("@AREA", area == null ? (object)DBNull.Value : area.Value);
                cmd.Parameters.AddWithValue("@ACTIVO", activo);
                cmd.Parameters.AddWithValue("@COMPONENTE", DBNull.Value);
                cmd.Parameters.AddWithValue("@ORDEN_TRABAJO", DBNull.Value);
                cmd.Parameters.AddWithValue("@FECHA_EVENTO", Hora.Ahora);
                cmd.Parameters.AddWithValue("@TURNO", DBNull.Value);
                cmd.Parameters.AddWithValue("@REQUIERE_ATENCION", false);
                cmd.Parameters.AddWithValue("@SEVERIDAD", DBNull.Value);
                cmd.Parameters.AddWithValue("@LATITUD", DBNull.Value);
                cmd.Parameters.AddWithValue("@LONGITUD", DBNull.Value);
                cmd.Parameters.AddWithValue("@OFFLINE", false);

                /* Entrada por la web: no hay telefono detras, y por eso
                   tampoco van dictado ni dispositivo. */
                cmd.Parameters.AddWithValue("@ENTRADA_MODO", 0);
                cmd.Parameters.AddWithValue("@DICTADO_UUID", DBNull.Value);
                cmd.Parameters.AddWithValue("@TEXTO_DICTADO", DBNull.Value);
                cmd.Parameters.AddWithValue("@DICTADO_CONFIANZA", DBNull.Value);
                cmd.Parameters.AddWithValue("@DICTADO_SEGUNDOS", DBNull.Value);
                cmd.Parameters.AddWithValue("@DISPOSITIVO", DBNull.Value);

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                r.codigo = (int)cmd.Parameters["@ID"].Value;
                r.detalle = "Observación registrada en la bitácora.";
                r.error = false;
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

        /// <summary>Lo que la gente anoto del equipo, del mas reciente al mas viejo.</summary>
        public List<ActivoBitacora> GetBitacora(int activo, DateTime? desde = null, DateTime? hasta = null)
        {
            List<ActivoBitacora> lista = new List<ActivoBitacora>();

            if (activo <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ACTIVO_BITACORA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ACTIVO", activo);
                if (desde != null) cmd.Parameters.AddWithValue("@DESDE", desde.Value);
                if (hasta != null) cmd.Parameters.AddWithValue("@HASTA", hasta.Value);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ActivoBitacora b = new ActivoBitacora();

                        b.bit_id = int.Parse(dr["bit_id"].ToString());
                        b.tipo_codigo = dr["TIPO_CODIGO"].ToString();
                        b.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                        b.tipo_icono = dr["TIPO_ICONO"].ToString();
                        b.titulo = dr["TITULO"].ToString();
                        b.texto = dr["TEXTO"].ToString();
                        if (dr["FECHA"] != DBNull.Value) b.fecha = (DateTime)dr["FECHA"];
                        b.turno = dr["TURNO"].ToString();
                        b.requiere_atencion = dr["REQUIERE_ATENCION"].ToString() == "True" || dr["REQUIERE_ATENCION"].ToString() == "1";
                        b.severidad_codigo = dr["SEVERIDAD_CODIGO"].ToString();
                        b.severidad_nombre = dr["SEVERIDAD_NOMBRE"].ToString();
                        b.componente = dr["COMPONENTE"].ToString();
                        if (dr["ORDEN_ID"] != DBNull.Value) b.orden_id = int.Parse(dr["ORDEN_ID"].ToString());
                        b.orden_correlativo = int.Parse(dr["ORDEN_CORRELATIVO"].ToString());
                        b.origen = dr["ORIGEN"].ToString();
                        b.offline = dr["OFFLINE"].ToString() == "True" || dr["OFFLINE"].ToString() == "1";
                        if (dr["FECHA_SINCRONIZACION"] != DBNull.Value) b.sincronizacion = (DateTime)dr["FECHA_SINCRONIZACION"];
                        b.dictado = dr["DICTADO"].ToString() != "0";
                        b.usuario = dr["USUARIO_NOMBRE"].ToString();
                        if (dr["FECHA_REGISTRO"] != DBNull.Value) b.registro = (DateTime)dr["FECHA_REGISTRO"];

                        lista.Add(b);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }
    }
}
