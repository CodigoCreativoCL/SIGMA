using System;
using System.Collections.Generic;

namespace SitioBase.Model
{
    /// <summary>
    /// Un hallazgo que el sistema detectó y alguien tiene que ver.
    ///
    /// NO ES "UNA NOTIFICACIÓN"
    ///   Es el hecho: este repuesto está bajo su mínimo, este lote venció. La
    ///   notificación es cómo se le muestra a cada persona, y eso vive en
    ///   Leida —que es por usuario— mientras el hallazgo es uno solo para
    ///   toda la empresa.
    /// </summary>
    public class Alerta
    {
        public int ale_id { get; set; }
        public string ale_titulo { get; set; }
        public string ale_descripcion { get; set; }
        public DateTime ale_fecha_deteccion_utc { get; set; }

        public string alt_codigo { get; set; }
        public string alt_nombre { get; set; }
        public string alt_icono { get; set; }

        /// <summary>
        /// La PANTALLA donde vive el tema. Alimenta el número del menú
        /// lateral: "las tres alertas son de Existencias".
        /// </summary>
        public string alt_menu_link { get; set; }

        /// <summary>
        /// El REGISTRO concreto, que es lo que se abre al tocar la
        /// notificación. Distinto de alt_menu_link a propósito: el badge del
        /// menú apunta a una pantalla, la notificación a una fila.
        ///
        /// Llevar al listado sería avisar y después hacer buscar, que es la
        /// mitad del trabajo.
        /// </summary>
        public string FICHA_LINK { get; set; }

        /// <summary>
        /// El id que esa ficha espera. Lo resuelve el SP desde la columna que
        /// el tipo declara, para que web y app no repitan el mismo CASE en
        /// dos idiomas. Nulo = no hay registro que abrir.
        /// </summary>
        public int? FICHA_ID { get; set; }

        public string aet_codigo { get; set; }
        public string aet_nombre { get; set; }

        public string sev_codigo { get; set; }
        public string sev_nombre { get; set; }

        public int? ale_repuesto { get; set; }
        public int? ale_bodega { get; set; }
        public int? ale_repuesto_lote { get; set; }

        public decimal? ale_valor_observado { get; set; }
        public decimal? ale_valor_umbral { get; set; }

        public bool LEIDA { get; set; }

        /// <summary>
        /// Cuántos minutos hace. Lo calcula el SP y no la pantalla porque la
        /// web y la app tienen que decir lo mismo.
        /// </summary>
        public int MINUTOS { get; set; }

        #region Centro de Acción Operacional

        /// <summary>
        /// De quién es la alerta AHORA. Distinto de quien la cerró: uno la
        /// toma el lunes y otro la termina el jueves. Nulo = sin responsable,
        /// que es el indicador que la bandeja pone arriba.
        /// </summary>
        public int? ale_usuario_responsable { get; set; }
        public string RESPONSABLE_NOMBRE { get; set; }

        public int? ale_cliente_instalacion { get; set; }
        public string INSTALACION_NOMBRE { get; set; }

        public int? ale_activo { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }
        public string REPUESTO_CODIGO { get; set; }
        public string BODEGA_NOMBRE { get; set; }

        /// <summary>
        /// Cuántas veces se repitió la condición. El detector no duplica la
        /// alerta, así que sin este número un repuesto que cayó bajo el
        /// mínimo catorce veces se ve igual que uno que cayó una sola vez.
        /// </summary>
        public int ale_ocurrencias { get; set; }
        public DateTime? ale_fecha_primera_ocurrencia_utc { get; set; }
        public DateTime? ale_fecha_ultima_ocurrencia_utc { get; set; }

        /// <summary>
        /// Nació del modelo predictivo. SOLO estas llevan el distintivo de
        /// SIGMA AI: rotular como IA un stock bajo el mínimo —que es una
        /// resta— sería atribuirle al modelo un trabajo que no hizo.
        /// </summary>
        public bool ES_PREDICCION { get; set; }
        public int? ale_prediccion { get; set; }

        /// <summary>ACTIVAS · GESTION · RESUELTAS. Lo resuelve el SP.</summary>
        public string GRUPO { get; set; }

        /// <summary>1 = crítica sin responsable … 9 = cerrada.</summary>
        public int ORDEN_PRIORIDAD { get; set; }

        /// <summary>
        /// La alerta sigue viva: nueva, reconocida o en gestión. Es lo que
        /// cuenta la campana, y no las no leídas.
        /// </summary>
        public bool Activa
        {
            get
            {
                return aet_codigo == "NUEVA" || aet_codigo == "RECONOCIDA" ||
                       aet_codigo == "EN GESTION";
            }
        }

        /// <summary>Lo que se puede hacer con ella según en qué estado está.</summary>
        public bool PuedeReconocer { get { return aet_codigo == "NUEVA"; } }
        public bool PuedeGestionar { get { return aet_codigo == "NUEVA" || aet_codigo == "RECONOCIDA"; } }
        public bool PuedeCerrar { get { return Activa; } }

        #endregion

        /// <summary>
        /// "hace 5 minutos", "hace 3 días".
        ///
        /// Una fecha exacta obliga a restar de cabeza para saber si es de hoy,
        /// que es lo único que importa en una bandeja de avisos.
        /// </summary>
        public string Antiguedad
        {
            get
            {
                if (MINUTOS < 1) return "recién";
                if (MINUTOS < 60) return "hace " + MINUTOS + " min";

                int horas = MINUTOS / 60;
                if (horas < 24) return "hace " + horas + (horas == 1 ? " hora" : " horas");

                int dias = horas / 24;
                if (dias < 30) return "hace " + dias + (dias == 1 ? " día" : " días");

                int meses = dias / 30;
                return "hace " + meses + (meses == 1 ? " mes" : " meses");
            }
        }
    }

    /// <summary>
    /// Un hito de la línea de tiempo de la alerta: quién la movió, cuándo y
    /// por qué.
    /// </summary>
    public class AlertaHito
    {
        public DateTime Fecha { get; set; }
        public string EstadoDesde { get; set; }
        public string EstadoHasta { get; set; }
        public string Usuario { get; set; }
        public string Motivo { get; set; }
        public string Responsable { get; set; }
    }

    /// <summary>
    /// Lo que SIGMA AI calculó para una alerta de predicción. Solo existe
    /// cuando la alerta salió del modelo.
    /// </summary>
    public class AlertaPrediccion
    {
        public int pre_id { get; set; }
        public decimal? pre_probabilidad { get; set; }
        public int? pre_dia_restante { get; set; }
        public decimal? pre_confianza { get; set; }
        public DateTime? pre_fecha_calculo_utc { get; set; }
        public DateTime? pre_fecha_evento_estimada_utc { get; set; }
        public string MODELO_NOMBRE { get; set; }
        public string MODELO_VERSION { get; set; }
        public string ACTIVO_CODIGO { get; set; }
        public string ACTIVO_NOMBRE { get; set; }

        /// <summary>Qué empujó la predicción y cuánto.</summary>
        public List<AlertaFactor> Factores { get; set; }

        /// <summary>
        /// Cómo venía subiendo el riesgo de este equipo, una corrida por día.
        ///
        /// No sale de la predicción de hoy sino de las ANTERIORES: un modelo
        /// vuelve a puntuar cada día y deja una fila por corrida. Con un solo
        /// punto la pantalla no dibuja la curva, porque una línea de un punto
        /// no cuenta ninguna historia.
        /// </summary>
        public List<AlertaPrediccionPunto> Serie { get; set; }

        /// <summary>
        /// La OT que ya se generó desde esta predicción. Nula mientras nadie
        /// la haya generado; es lo que impide que se creen dos.
        /// </summary>
        public int? ORDEN_TRABAJO { get; set; }
        public int? ORDEN_CORRELATIVO { get; set; }

        public AlertaPrediccion()
        {
            Factores = new List<AlertaFactor>();
            Serie = new List<AlertaPrediccionPunto>();
        }

        /// <summary>"87 %" — o vacío cuando el modelo no la entregó.</summary>
        public string ProbabilidadTexto
        {
            get
            {
                if (pre_probabilidad == null) return "";

                decimal v = pre_probabilidad.Value;

                /* El modelo puede entregarla en 0..1 o en 0..100. Se
                   normaliza acá y no en la pantalla para que la web y la app
                   muestren el mismo número. */
                if (v <= 1) v = v * 100;

                return Math.Round(v, 0).ToString("0") + " %";
            }
        }
    }

    /// <summary>Una corrida del modelo: qué día y con qué probabilidad.</summary>
    public class AlertaPrediccionPunto
    {
        public DateTime Fecha { get; set; }
        public decimal Probabilidad { get; set; }
        public int? DiaRestante { get; set; }

        /// <summary>Siempre 0..100, venga el modelo en 0..1 o en 0..100.</summary>
        public decimal Porcentaje
        {
            get { return Probabilidad <= 1 ? Probabilidad * 100 : Probabilidad; }
        }
    }

    /// <summary>Un factor de la predicción: "Vibración, +31 %".</summary>
    public class AlertaFactor
    {
        public string Texto { get; set; }
        public decimal? Contribucion { get; set; }
        public string Direccion { get; set; }
        public decimal? ValorObservado { get; set; }
        public decimal? ValorReferencia { get; set; }
    }

    /// <summary>
    /// La curva de los últimos días y la comparación con ayer, por indicador.
    ///
    /// Es el ESTADO de cada día —cuántas estaban activas ese día—, no cuántas
    /// nacieron. Un día sin detecciones nuevas pero con veinte alertas
    /// arrastradas tiene veinte activas, y una curva de detecciones lo
    /// dibujaría como cero.
    /// </summary>
    public class AlertaTendencia
    {
        public List<int> Activas { get; set; }
        public List<int> Criticas { get; set; }
        public List<int> EnGestion { get; set; }
        public List<int> SinResponsable { get; set; }
        public List<int> Predicciones { get; set; }

        /// <summary>Nulo cuando ayer fue cero: no hay porcentaje que calcular.</summary>
        public int? VarActivas { get; set; }
        public int? VarCriticas { get; set; }
        public int? VarEnGestion { get; set; }
        public int? VarSinResponsable { get; set; }
        public int? VarPredicciones { get; set; }

        public AlertaTendencia()
        {
            Activas = new List<int>();
            Criticas = new List<int>();
            EnGestion = new List<int>();
            SinResponsable = new List<int>();
            Predicciones = new List<int>();
        }
    }

    /// <summary>Los números de la campana y de cada menú.</summary>
    public class AlertaResumen
    {
        public int Abiertas { get; set; }
        public int NoLeidas { get; set; }

        /// <summary>Los cinco indicadores del Centro de Acción Operacional.</summary>
        public int Criticas { get; set; }
        public int EnGestion { get; set; }
        public int SinResponsable { get; set; }
        public int Predicciones { get; set; }

        /// <summary>
        /// Cuántas hay por pantalla, para el punto del menú lateral. La clave
        /// es el mnu_link, que es lo que el menú ya conoce cuando se dibuja.
        /// </summary>
        public Dictionary<string, int> PorMenu { get; set; }

        public AlertaResumen()
        {
            PorMenu = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        }
    }
}
