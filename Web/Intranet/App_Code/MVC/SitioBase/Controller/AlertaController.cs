using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;

namespace SitioBase.Controller
{
    /// <summary>
    /// Las notificaciones: lo que el sistema encontró y hay que mirar.
    ///
    /// EL RESUMEN SE PIDE UNA VEZ POR PÁGINA, Y SE GUARDA
    ///   La cabecera se dibuja en TODAS las pantallas, y el menú lateral
    ///   también. Sin caché, cada carga del sitio serían dos consultas más
    ///   para pintar un número que cambia cada varios minutos.
    ///
    ///   Se guarda en HttpContext.Items —que vive lo que dura UNA petición— y
    ///   no en Session: en Session el contador se quedaría pegado y la persona
    ///   vería un punto rojo que ya no corresponde, o peor, no vería uno nuevo.
    /// </summary>
    public class AlertaController
    {
        private const string CLAVE_RESUMEN = "SIGMA_ALERTA_RESUMEN";

        /// <summary>
        /// Los números de la campana y de cada menú, en una sola llamada: la
        /// cabecera necesita los dos y pedirlos por separado duplicaría el
        /// costo en cada página del sitio.
        /// </summary>
        public AlertaResumen GetResumen()
        {
            HttpContext ctx = HttpContext.Current;

            if (ctx != null && ctx.Items[CLAVE_RESUMEN] != null)
                return (AlertaResumen)ctx.Items[CLAVE_RESUMEN];

            AlertaResumen resumen = new AlertaResumen();

            if (!Token.TokenSeguridad()) return resumen;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ALERTA_RESUMEN";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        resumen.Abiertas = dr["ABIERTAS"] != DBNull.Value
                                           ? int.Parse(dr["ABIERTAS"].ToString()) : 0;
                        resumen.NoLeidas = dr["NO_LEIDAS"] != DBNull.Value
                                           ? int.Parse(dr["NO_LEIDAS"].ToString()) : 0;

                        /* Los cuatro indicadores del Centro de Acción Operacional.
                           Se leen con Columna() —que devuelve 0 si la columna no
                           viene— porque este resumen lo pide la cabecera de TODAS
                           las pantallas: si en algún ambiente quedara publicado el
                           SP viejo, la campana tiene que seguir funcionando en vez
                           de caerse por una columna que aún no existe. */
                        resumen.Criticas = Columna(dr, "CRITICAS");
                        resumen.EnGestion = Columna(dr, "EN_GESTION");
                        resumen.SinResponsable = Columna(dr, "SIN_RESPONSABLE");
                        resumen.Predicciones = Columna(dr, "PREDICCIONES");
                    }

                    if (dr.NextResult())
                    {
                        while (dr.Read())
                        {
                            string link = dr["MENU_LINK"].ToString();
                            int abiertas = int.Parse(dr["ABIERTAS"].ToString());

                            if (!resumen.PorMenu.ContainsKey(link))
                                resumen.PorMenu.Add(link, abiertas);
                        }
                    }
                }
            }
            catch (Exception)
            {
                /* La cabecera se dibuja en todas las pantallas: si el resumen
                   falla, el sitio tiene que seguir funcionando sin el número.
                   Tumbar cada página por un contador sería desproporcionado. */
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            if (ctx != null) ctx.Items[CLAVE_RESUMEN] = resumen;

            return resumen;
        }

        /// <summary>La bandeja.</summary>
        public List<Alerta> GetAlertas(bool soloAbiertas = true, int tope = 50,
                                       string grupo = null, string severidad = null,
                                       string tipo = null, bool? sinResponsable = null,
                                       string filtro = null)
        {
            List<Alerta> lista = new List<Alerta>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ALERTA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.Parameters.AddWithValue("@SOLO_ABIERTAS", soloAbiertas);
                cmd.Parameters.AddWithValue("@TOPE", tope);

                /* Los filtros van al SP y no se aplican en memoria: filtrar
                   después de traer 500 filas obliga a traerlas siempre, y el
                   tope recorta lo que llega ANTES de filtrar, así que la
                   página 1 de un filtro podía venir vacía teniendo datos. */
                if (!string.IsNullOrEmpty(grupo))
                    cmd.Parameters.AddWithValue("@GRUPO", grupo);

                if (!string.IsNullOrEmpty(severidad))
                    cmd.Parameters.AddWithValue("@SEVERIDAD", severidad);

                if (!string.IsNullOrEmpty(tipo))
                    cmd.Parameters.AddWithValue("@TIPO", tipo);

                if (sinResponsable != null)
                    cmd.Parameters.AddWithValue("@SIN_RESPONSABLE", sinResponsable.Value);

                if (!string.IsNullOrEmpty(filtro))
                    cmd.Parameters.AddWithValue("@FILTRO", filtro);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        Alerta a = new Alerta();

                        a.ale_id = int.Parse(dr["ale_id"].ToString());
                        a.ale_titulo = dr["ale_titulo"].ToString();
                        a.ale_descripcion = dr["ale_descripcion"].ToString();
                        a.ale_fecha_deteccion_utc = DateTime.Parse(dr["ale_fecha_deteccion_utc"].ToString());

                        a.alt_codigo = dr["alt_codigo"].ToString();
                        a.alt_nombre = dr["alt_nombre"].ToString();
                        a.alt_icono = dr["alt_icono"].ToString();
                        a.alt_menu_link = dr["alt_menu_link"].ToString();
                        a.FICHA_LINK = dr["FICHA_LINK"].ToString();

                        if (dr["FICHA_ID"] != DBNull.Value)
                            a.FICHA_ID = int.Parse(dr["FICHA_ID"].ToString());

                        a.aet_codigo = dr["aet_codigo"].ToString();
                        a.aet_nombre = dr["aet_nombre"].ToString();

                        a.sev_codigo = dr["sev_codigo"].ToString();
                        a.sev_nombre = dr["sev_nombre"].ToString();

                        a.LEIDA = (dr["LEIDA"].ToString() == "1" ||
                                   dr["LEIDA"].ToString().ToUpper() == "TRUE");
                        a.MINUTOS = int.Parse(dr["MINUTOS"].ToString());

                        if (dr["ale_repuesto"] != DBNull.Value)
                            a.ale_repuesto = int.Parse(dr["ale_repuesto"].ToString());

                        if (dr["ale_bodega"] != DBNull.Value)
                            a.ale_bodega = int.Parse(dr["ale_bodega"].ToString());

                        if (dr["ale_repuesto_lote"] != DBNull.Value)
                            a.ale_repuesto_lote = int.Parse(dr["ale_repuesto_lote"].ToString());

                        // ---- Centro de Acción Operacional ----
                        a.ale_usuario_responsable = Entero(dr, "ale_usuario_responsable");
                        a.RESPONSABLE_NOMBRE = Texto(dr, "RESPONSABLE_NOMBRE");
                        a.ale_cliente_instalacion = Entero(dr, "ale_cliente_instalacion");
                        a.INSTALACION_NOMBRE = Texto(dr, "INSTALACION_NOMBRE");
                        a.ale_activo = Entero(dr, "ale_activo");
                        a.ACTIVO_CODIGO = Texto(dr, "ACTIVO_CODIGO");
                        a.ACTIVO_NOMBRE = Texto(dr, "ACTIVO_NOMBRE");
                        a.REPUESTO_CODIGO = Texto(dr, "REPUESTO_CODIGO");
                        a.BODEGA_NOMBRE = Texto(dr, "BODEGA_NOMBRE");
                        a.ale_ocurrencias = Columna(dr, "ale_ocurrencias");
                        a.ale_prediccion = Entero(dr, "ale_prediccion");
                        a.GRUPO = Texto(dr, "GRUPO");
                        a.ORDEN_PRIORIDAD = Columna(dr, "ORDEN_PRIORIDAD");
                        a.ES_PREDICCION = Bandera(dr, "ES_PREDICCION");

                        lista.Add(a);
                    }
                }
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        /// <summary>
        /// Marca como leída. Sin id, marca todo lo que esa persona puede ver.
        /// </summary>
        public int Leer(int alerta = 0)
        {
            if (!Token.TokenSeguridad()) return 0;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "UPD_ALERTA_LEER";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                if (alerta > 0) cmd.Parameters.AddWithValue("@ALERTA", alerta);

                int marcadas = 0;

                /* Este Conexion no tiene GetScalar: se lee la primera fila del
                   lector, que es lo mismo con el helper que si existe. */
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read() && dr[0] != DBNull.Value)
                        marcadas = int.Parse(dr[0].ToString());
                }

                /* El resumen en caché quedó viejo en cuanto se marcó algo. */
                if (HttpContext.Current != null)
                    HttpContext.Current.Items.Remove(CLAVE_RESUMEN);

                return marcadas;
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                return 0;
            }
        }

        /// <summary>
        /// Pregunta si hay algo nuevo, y de paso lo detecta si toca.
        ///
        /// UNA LLAMADA, DOS COSAS
        ///   GEN_ALERTA_DETECTAR decide si corresponde correr el detector —el
        ///   freno vive en la base, para que dos usuarios simultáneos no lo
        ///   ejecuten los dos— y devuelve el resumen SIEMPRE, corriera o no.
        ///   El navegador pregunta para refrescar sus números; hacerle dar dos
        ///   viajes sería el doble de tráfico para lo mismo.
        ///
        /// SE PUEDE LLAMAR CADA MINUTO SIN MIEDO
        ///   El detector es idempotente —abre lo que empezó a pasar y cierra
        ///   lo que dejó de pasar— y el freno lo detiene casi siempre: la
        ///   llamada normal solo cuenta filas.
        ///
        /// <param name="forzar">
        ///   Se salta el freno. Lo usa el botón "Revisar ahora": si alguien lo
        ///   aprieta es porque quiere saber en este momento.
        /// </param>
        /// </summary>
        public AlertaResumen Detectar(bool forzar = false)
        {
            AlertaResumen resumen = new AlertaResumen();

            if (!Token.TokenSeguridad()) return resumen;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "GEN_ALERTA_DETECTAR";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                if (forzar) cmd.Parameters.AddWithValue("@FORZAR", true);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        resumen.Abiertas = dr["ABIERTAS"] != DBNull.Value
                                           ? int.Parse(dr["ABIERTAS"].ToString()) : 0;
                        resumen.NoLeidas = dr["NO_LEIDAS"] != DBNull.Value
                                           ? int.Parse(dr["NO_LEIDAS"].ToString()) : 0;

                        /* Los cuatro indicadores del Centro de Acción Operacional.
                           Se leen con Columna() —que devuelve 0 si la columna no
                           viene— porque este resumen lo pide la cabecera de TODAS
                           las pantallas: si en algún ambiente quedara publicado el
                           SP viejo, la campana tiene que seguir funcionando en vez
                           de caerse por una columna que aún no existe. */
                        resumen.Criticas = Columna(dr, "CRITICAS");
                        resumen.EnGestion = Columna(dr, "EN_GESTION");
                        resumen.SinResponsable = Columna(dr, "SIN_RESPONSABLE");
                        resumen.Predicciones = Columna(dr, "PREDICCIONES");
                    }

                    if (dr.NextResult())
                    {
                        while (dr.Read())
                        {
                            string link = dr["MENU_LINK"].ToString();
                            int abiertas = int.Parse(dr["ABIERTAS"].ToString());

                            if (!resumen.PorMenu.ContainsKey(link))
                                resumen.PorMenu.Add(link, abiertas);
                        }
                    }
                }

                /* Lo que hubiera en caché es de ANTES de detectar. */
                if (HttpContext.Current != null)
                    HttpContext.Current.Items[CLAVE_RESUMEN] = resumen;

                /* DESPUÉS de detectar, nunca antes. El detector cierra las
                   alertas cuya condición dejó de darse; lo que sigue abierto
                   es lo que sigue pasando, y de eso —y solo de eso— se cuenta
                   una repetición más. Al revés se contaría un episodio de un
                   problema que ya se resolvió. */
                Repetir();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return resumen;
        }

        /// <summary>
        /// Suma una repetición a lo que sigue abierto: la condición volvió a
        /// darse. El SP tiene su propio freno de un minuto, así que apretar
        /// "Revisar ahora" dos veces seguidas no infla el contador.
        ///
        /// Si falla, se calla: el contador de repeticiones es informativo y
        /// no puede tumbar la detección, que es lo que de verdad importa.
        /// </summary>
        private void Repetir()
        {
            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("UPD_ALERTA_REPETICION");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
        }

        /// <summary>
        /// La curva de los últimos días y el "vs ayer" de cada indicador.
        ///
        /// Va aparte de GetResumen porque el resumen lo pide la cabecera de
        /// TODAS las pantallas para la campana, y reconstruir siete días de
        /// estado en cada carga sería pagarlo en sitios donde nadie mira la
        /// curva.
        /// </summary>
        public AlertaTendencia GetTendencia(int dias = 7)
        {
            AlertaTendencia t = new AlertaTendencia();

            if (!Token.TokenSeguridad()) return t;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ALERTA_TENDENCIA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.Parameters.AddWithValue("@DIAS", dias);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        t.Activas.Add(Columna(dr, "ACTIVAS"));
                        t.Criticas.Add(Columna(dr, "CRITICAS"));
                        t.EnGestion.Add(Columna(dr, "EN_GESTION"));
                        t.SinResponsable.Add(Columna(dr, "SIN_RESPONSABLE"));
                        t.Predicciones.Add(Columna(dr, "PREDICCIONES"));
                    }

                    if (dr.NextResult() && dr.Read())
                    {
                        t.VarActivas = Entero(dr, "VAR_ACTIVAS");
                        t.VarCriticas = Entero(dr, "VAR_CRITICAS");
                        t.VarEnGestion = Entero(dr, "VAR_EN_GESTION");
                        t.VarSinResponsable = Entero(dr, "VAR_SIN_RESPONSABLE");
                        t.VarPredicciones = Entero(dr, "VAR_PREDICCIONES");
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                /* Sin curva las tarjetas siguen mostrando su número. Perder el
                   adorno es aceptable; perder el indicador no. */
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                t = new AlertaTendencia();
            }

            return t;
        }

        #region Ciclo de vida

        /// <summary>
        /// Reconocer, gestionar, resolver o descartar.
        ///
        /// NO TOCA LA LECTURA. Leer y reconocer son cosas distintas: abrir la
        /// bandeja no puede resolver la planta. El SP valida el permiso otra
        /// vez en el servidor, porque esconder el botón no es seguridad.
        /// </summary>
        public Respuesta CambiarEstado(int alerta, string estado,
                                       string motivo = null, int? responsable = null)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                respuesta.error = true;
                respuesta.detalle = "Sesión no válida.";
                return respuesta;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("UPD_ALERTA_ESTADO");
                cmd.Parameters.AddWithValue("@ALERTA", alerta);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.Parameters.AddWithValue("@ESTADO", estado);
                cmd.Parameters.AddWithValue("@MOTIVO",
                    string.IsNullOrEmpty(motivo) ? (object)DBNull.Value : motivo);
                cmd.Parameters.AddWithValue("@RESPONSABLE",
                    responsable == null ? (object)DBNull.Value : responsable.Value);

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = alerta;
                respuesta.detalle = "Alerta actualizada.";
                respuesta.error = false;

                Invalidar();
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        /// <summary>
        /// Convierte un análisis predictivo en una orden de trabajo.
        ///
        /// Es el único punto donde el panel de SIGMA AI deja de ser una
        /// lectura y se vuelve un encargo. El SP hace el trabajo completo:
        /// crea la OT con origen PREDICCIÓN, la enlaza a la alerta y mueve la
        /// alerta a EN GESTIÓN, todo en una transacción.
        ///
        /// NO CREA DOS. Si la alerta ya tiene orden, devuelve esa misma. Dos
        /// clics seguidos —o dos personas a la vez— no mandan dos cuadrillas
        /// al mismo equipo.
        ///
        /// El permiso se valida acá y otra vez en el SP: esconder el botón no
        /// es seguridad.
        /// </summary>
        public Respuesta GenerarOrdenTrabajo(int alerta)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                respuesta.error = true;
                respuesta.detalle = "Sesión no válida.";
                return respuesta;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("INS_ORDEN_TRABAJO_DESDE_PREDICCION");
                cmd.Parameters.AddWithValue("@ALERTA", alerta);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                int correlativo = 0;
                bool yaExistia = false;

                respuesta.codigo = -1;

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        respuesta.codigo = Entero(dr, "otr_id") ?? -1;
                        correlativo = Entero(dr, "otr_correlativo") ?? 0;
                        yaExistia = Bandera(dr, "YA_EXISTIA");
                    }
                }

                cmd.Connection.Close();

                if (respuesta.codigo <= 0)
                {
                    respuesta.error = true;
                    respuesta.detalle = "No se pudo generar la orden de trabajo.";
                    return respuesta;
                }

                respuesta.error = false;
                respuesta.detalle = yaExistia
                    ? "Esta predicción ya tenía la orden de trabajo N° " + correlativo + "."
                    : "Se generó la orden de trabajo N° " + correlativo + ".";

                Invalidar();
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        /// <summary>Asignar sin cambiar el estado.</summary>
        public Respuesta AsignarResponsable(int alerta, int responsable)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                respuesta.error = true;
                respuesta.detalle = "Sesión no válida.";
                return respuesta;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("UPD_ALERTA_RESPONSABLE");
                cmd.Parameters.AddWithValue("@ALERTA", alerta);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.Parameters.AddWithValue("@RESPONSABLE", responsable);

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = alerta;
                respuesta.detalle = "Responsable asignado.";
                respuesta.error = false;

                Invalidar();
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        /// <summary>La línea de tiempo del detalle.</summary>
        public List<AlertaHito> GetHistorial(int alerta)
        {
            List<AlertaHito> lista = new List<AlertaHito>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ALERTA_HISTORIAL";
                cmd.Parameters.AddWithValue("@ALERTA", alerta);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        AlertaHito h = new AlertaHito();
                        h.Fecha = DateTime.Parse(dr["FECHA"].ToString());
                        h.EstadoDesde = dr["ESTADO_DESDE"].ToString();
                        h.EstadoHasta = dr["ESTADO_HASTA"].ToString();
                        h.Usuario = dr["USUARIO"].ToString();
                        h.Motivo = dr["MOTIVO"].ToString();
                        h.Responsable = dr["RESPONSABLE"].ToString();
                        lista.Add(h);
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
        /// Lo que SIGMA AI calculó, o null cuando la alerta no salió del
        /// modelo. Null y no un objeto vacío: la pantalla esconde el panel
        /// entero, porque mostrar "probabilidad: no disponible" en una alerta
        /// de stock sugiere que el modelo opinó y no lo hizo.
        /// </summary>
        public AlertaPrediccion GetPrediccion(int alerta)
        {
            AlertaPrediccion p = null;

            if (!Token.TokenSeguridad()) return null;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ALERTA_PREDICCION";
                cmd.Parameters.AddWithValue("@ALERTA", alerta);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        p = new AlertaPrediccion();
                        p.pre_id = int.Parse(dr["pre_id"].ToString());
                        p.pre_probabilidad = Decimal(dr, "pre_probabilidad");
                        p.pre_confianza = Decimal(dr, "pre_confianza");
                        p.pre_dia_restante = Entero(dr, "pre_dia_restante");
                        p.pre_fecha_calculo_utc = Fecha(dr, "pre_fecha_calculo_utc");
                        p.pre_fecha_evento_estimada_utc = Fecha(dr, "pre_fecha_evento_estimada_utc");
                        p.MODELO_NOMBRE = Texto(dr, "MODELO_NOMBRE");
                        p.MODELO_VERSION = Texto(dr, "MODELO_VERSION");
                        p.ACTIVO_CODIGO = Texto(dr, "ACTIVO_CODIGO");
                        p.ACTIVO_NOMBRE = Texto(dr, "ACTIVO_NOMBRE");
                    }

                    if (p != null && dr.NextResult())
                    {
                        while (dr.Read())
                        {
                            AlertaFactor f = new AlertaFactor();
                            f.Texto = Texto(dr, "pex_texto");
                            f.Contribucion = Decimal(dr, "pex_contribucion");
                            f.Direccion = Texto(dr, "pex_direccion");
                            f.ValorObservado = Decimal(dr, "pex_valor_observado");
                            f.ValorReferencia = Decimal(dr, "pex_valor_referencia");
                            p.Factores.Add(f);
                        }
                    }

                    /* La curva: las corridas anteriores del mismo equipo. */
                    if (p != null && dr.NextResult())
                    {
                        while (dr.Read())
                        {
                            AlertaPrediccionPunto pt = new AlertaPrediccionPunto();
                            DateTime? f = Fecha(dr, "FECHA");
                            decimal? v = Decimal(dr, "PROBABILIDAD");

                            /* Un punto sin fecha o sin valor no se puede
                               ubicar en la curva: se descarta en vez de
                               dibujarlo en el cero. */
                            if (f == null || v == null) continue;

                            pt.Fecha = f.Value;
                            pt.Probabilidad = v.Value;
                            pt.DiaRestante = Entero(dr, "DIA_RESTANTE");
                            p.Serie.Add(pt);
                        }
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                p = null;
            }

            return p;
        }

        /// <summary>
        /// Bota el resumen cacheado de la petición. Sin esto, la campana
        /// seguiría mostrando el número de antes de la acción que se acaba
        /// de ejecutar.
        /// </summary>
        private void Invalidar()
        {
            if (HttpContext.Current != null)
                HttpContext.Current.Items.Remove(CLAVE_RESUMEN);
        }

        #endregion

        #region Lectura tolerante del reader

        /* Los SP de alertas los consumen la web, la app y la campana de cada
           pantalla. Leer por nombre sin comprobar que la columna exista hace
           que agregar una columna a un SP rompa a los otros dos consumidores,
           y el catch de arriba se lo traga: se ve como una bandeja vacía. */

        private bool Existe(SqlDataReader dr, string columna)
        {
            for (int i = 0; i < dr.FieldCount; i++)
                if (string.Equals(dr.GetName(i), columna, StringComparison.OrdinalIgnoreCase))
                    return true;

            return false;
        }

        private int Columna(SqlDataReader dr, string columna)
        {
            if (!Existe(dr, columna) || dr[columna] == DBNull.Value) return 0;
            return int.Parse(dr[columna].ToString());
        }

        private int? Entero(SqlDataReader dr, string columna)
        {
            if (!Existe(dr, columna) || dr[columna] == DBNull.Value) return null;
            return int.Parse(dr[columna].ToString());
        }

        private decimal? Decimal(SqlDataReader dr, string columna)
        {
            if (!Existe(dr, columna) || dr[columna] == DBNull.Value) return null;
            return decimal.Parse(dr[columna].ToString());
        }

        private DateTime? Fecha(SqlDataReader dr, string columna)
        {
            if (!Existe(dr, columna) || dr[columna] == DBNull.Value) return null;
            return DateTime.Parse(dr[columna].ToString());
        }

        private string Texto(SqlDataReader dr, string columna)
        {
            if (!Existe(dr, columna) || dr[columna] == DBNull.Value) return "";
            return dr[columna].ToString();
        }

        private bool Bandera(SqlDataReader dr, string columna)
        {
            if (!Existe(dr, columna) || dr[columna] == DBNull.Value) return false;
            return Convert.ToBoolean(dr[columna]);
        }

        #endregion
    }
}
