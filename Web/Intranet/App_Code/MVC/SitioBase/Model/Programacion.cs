using System;
using System.Collections.Generic;

namespace SitioBase.Model
{
    /// <summary>
    /// La regla que dice CUANDO toca un trabajo (HU-070 a HU-075, bloques 103-106).
    ///
    /// UNA CLASE, CINCO VARIANTES
    ///   `tipo_codigo` dice cual es, y solo una de las cinco propiedades de
    ///   detalle viene poblada. No son cinco entidades separadas: comparten
    ///   vigencia, tolerancias, zona horaria y politica, y tenerlas cinco
    ///   veces garantiza que algun dia se desincronicen.
    ///
    /// LA PROYECCION NO ES UNA OCURRENCIA
    ///   `proyeccion` son las fechas que ESTA regla produciria. No hay nada
    ///   creado en la base: es un calculo. Las ocurrencias reales las escribe
    ///   HU-076, que necesita el plan de mantenimiento del Sprint 4.
    /// </summary>
    [Serializable]
    public class Programacion
    {
        public int pro_id { get; set; }
        public int pro_cliente { get; set; }
        public int pro_programacion_tipo { get; set; }
        public int? pro_zona_horaria { get; set; }
        public string pro_nombre { get; set; }
        public DateTime? pro_fecha_inicio { get; set; }
        public DateTime? pro_fecha_fin { get; set; }
        public int pro_tolerancia_antes_minuto { get; set; }
        public int pro_tolerancia_despues_minuto { get; set; }
        public bool pro_permite_anticipada { get; set; }
        public bool pro_permite_atrasada { get; set; }
        public int? pro_cumplimiento_politica { get; set; }
        public bool pro_genera_automaticamente { get; set; }
        public bool pro_habilitado { get; set; }

        public int pro_usuario_creacion { get; set; }
        public DateTime? pro_fecha_creacion { get; set; }
        public int? pro_usuario_actualizacion { get; set; }
        public DateTime? pro_fecha_actualizacion { get; set; }

        /* Los trae el SEL_ resueltos: devolver el id obliga a quien mira la
           ficha a ir a averiguar quien es el 7 o que significa el tipo 3. */
        public string tipo_codigo { get; set; }
        public string tipo_nombre { get; set; }
        public string zona_horaria_nombre { get; set; }
        public string cumplimiento_politica_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        /* Lo que el listado muestra sin abrir la ficha. */
        public bool vigente { get; set; }
        public string detalle { get; set; }
        public int exclusiones { get; set; }
        public int ocurrencias { get; set; }

        /* Solo una viene poblada, segun tipo_codigo. */
        public ProgramacionCalendario calendario { get; set; }
        public ProgramacionIntervalo intervalo { get; set; }
        public ProgramacionMedidor medidor { get; set; }
        public List<ProgramacionFecha> fechas { get; set; }
        public List<ProgramacionCondicion> condiciones { get; set; }

        public List<ProgramacionExclusion> lista_exclusiones { get; set; }
        public List<ProgramacionProyeccion> proyeccion { get; set; }

        // Filtros que el Controller convierte en parametros del SEL_
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool? filtro_vigente { get; set; }
        public int? filtro_tipo { get; set; }

        /// <summary>
        /// La ventana de cumplimiento en palabras: "2 días antes, 3 después".
        /// Los minutos crudos —2880 y 4320— no los lee nadie.
        /// </summary>
        public string tolerancia_texto
        {
            get
            {
                if (pro_tolerancia_antes_minuto == 0 && pro_tolerancia_despues_minuto == 0)
                    return "Sin tolerancia";

                return Duracion(pro_tolerancia_antes_minuto) + " antes, " +
                       Duracion(pro_tolerancia_despues_minuto) + " después";
            }
        }

        private string Duracion(int minutos)
        {
            if (minutos == 0) return "0";
            if (minutos % 1440 == 0) return (minutos / 1440) + (minutos == 1440 ? " día" : " días");
            if (minutos % 60 == 0) return (minutos / 60) + (minutos == 60 ? " hora" : " horas");
            return minutos + " min";
        }
    }

    /// <summary>
    /// Una fila de cualquiera de los ocho catalogos de la ficha. Los ocho
    /// tienen la misma forma —id, codigo, nombre— asi que no hace falta una
    /// clase por catalogo.
    /// </summary>
    [Serializable]
    public class CatalogoItem
    {
        public int id { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
    }

    /// <summary>Recurrencia de calendario (HU-071). 1..1 con la programacion.</summary>
    [Serializable]
    public class ProgramacionCalendario
    {
        public int pca_id { get; set; }
        public int pca_programacion { get; set; }
        public int pca_frecuencia_tipo { get; set; }
        public int pca_intervalo { get; set; }

        /* -1 significa "el ultimo". Es la convencion que evita guardar
           28/29/30/31 y elegir mal en febrero. */
        public int? pca_semana_ordinal { get; set; }
        public int? pca_dia_mes { get; set; }
        public int? pca_mes { get; set; }
        public TimeSpan? pca_hora_local { get; set; }
        public bool pca_habilitado { get; set; }

        public string frecuencia_codigo { get; set; }
        public string frecuencia_nombre { get; set; }

        /* "2,4" para el combo multiple; "Martes, Jueves" para mostrar. */
        public string dias { get; set; }
        public string dias_nombre { get; set; }
    }

    /// <summary>Intervalo de tiempo (HU-072). 1..1 con la programacion.</summary>
    [Serializable]
    public class ProgramacionIntervalo
    {
        public int pin_id { get; set; }
        public int pin_programacion { get; set; }
        public int pin_unidad_tiempo { get; set; }
        public int pin_cantidad { get; set; }
        public DateTime? pin_fecha_ancla_utc { get; set; }

        /* false = desde la fecha programada: un atraso NO desplaza las
           siguientes (HU-072 #2). true = desde la ultima ejecucion (#1). */
        public bool pin_desde_ejecucion { get; set; }
        public bool pin_habilitado { get; set; }

        public string unidad_codigo { get; set; }
        public string unidad_nombre { get; set; }
    }

    /// <summary>Disparo por medidor (HU-073). 1..1 con la programacion.</summary>
    [Serializable]
    public class ProgramacionMedidor
    {
        public int pme_id { get; set; }
        public int pme_programacion { get; set; }
        public int pme_activo_medidor { get; set; }
        public decimal pme_valor_inicial { get; set; }
        public decimal pme_cada_cantidad { get; set; }
        public decimal? pme_aviso_anticipacion { get; set; }
        public bool pme_habilitado { get; set; }

        public string medidor_codigo { get; set; }
        public string medidor_nombre { get; set; }
        public decimal medidor_valor_actual { get; set; }
        public int ame_activo { get; set; }
        public string activo_nombre { get; set; }
        public decimal proximo_valor { get; set; }
    }

    /// <summary>Una fecha puntual (HU-070). 1..N.</summary>
    [Serializable]
    public class ProgramacionFecha
    {
        public int pfe_id { get; set; }
        public int pfe_programacion { get; set; }
        public DateTime pfe_fecha { get; set; }
        public TimeSpan? pfe_hora { get; set; }
        public bool pfe_incluida { get; set; }
    }

    /// <summary>Un umbral que dispara (HU-074). 1..N.</summary>
    [Serializable]
    public class ProgramacionCondicion
    {
        public int pco_id { get; set; }
        public int pco_programacion { get; set; }
        public int pco_activo_variable { get; set; }
        public int pco_operador_comparacion { get; set; }
        public decimal pco_umbral { get; set; }
        public decimal? pco_umbral_hasta { get; set; }
        public int? pco_duracion_minima_minuto { get; set; }
        public int pco_severidad { get; set; }
        public bool pco_habilitado { get; set; }

        public int ava_activo { get; set; }
        public string activo_nombre { get; set; }
        public string variable_nombre { get; set; }
        public string operador_codigo { get; set; }
        public string operador_nombre { get; set; }
        public string severidad_nombre { get; set; }
        public string regla { get; set; }
    }

    /// <summary>Un periodo sin trabajo programado (HU-075). 1..N.</summary>
    [Serializable]
    public class ProgramacionExclusion
    {
        public int pxc_id { get; set; }
        public int pxc_programacion { get; set; }
        public DateTime pxc_fecha_inicio_utc { get; set; }
        public DateTime pxc_fecha_fin_utc { get; set; }
        public string pxc_motivo { get; set; }

        /* false = no se genera nada en el periodo (parada de planta, #3).
           true  = la fecha se corre al siguiente dia habil (feriado, #2). */
        public bool pxc_desplaza { get; set; }
        public bool pxc_habilitado { get; set; }

        public int pxc_usuario_creacion { get; set; }
        public DateTime? pxc_fecha_creacion { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public int dias { get; set; }
        public string efecto { get; set; }
    }

    /// <summary>
    /// Una fecha que la regla produciria. No existe en la base: es el
    /// resultado de FNC_PROGRAMACION_FECHAS.
    /// </summary>
    [Serializable]
    public class ProgramacionProyeccion
    {
        public DateTime fecha { get; set; }

        /* Solo viene cuando la fecha se corrio por una exclusion: es el
           "la fecha original queda registrada" de HU-075 #2. */
        public DateTime? fecha_original { get; set; }
        public bool desplazada { get; set; }
        public string motivo { get; set; }
        public bool es_pasada { get; set; }
        public string tipo_codigo { get; set; }
    }
}
