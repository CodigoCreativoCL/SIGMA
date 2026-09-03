using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un permiso de trabajo: el papel que habilita una faena de riesgo
    /// —altura, espacio confinado, trabajo caliente— (HU-063, bloque 94).
    ///
    /// AUTORIZADO EXIGE EL DOCUMENTO, Y LO DICE LA TABLA
    ///   `CK_PTR_AUTORIZADO` impide que un permiso este AUTORIZADO sin
    ///   `ptr_archivo`. No es una regla de pantalla: la constancia ES el
    ///   papel firmado, no la fila, y sin el adjunto autorizar seria afirmar
    ///   algo que no se puede respaldar.
    ///
    ///   Mientras la API de almacenamiento no exista, ningun permiso puede
    ///   llegar a AUTORIZADO. La ficha lo dice; ver el MD de estado.
    ///
    /// LA SITUACION SE CALCULA, NO SE GUARDA
    ///   El catalogo tiene un estado VENCIDO, pero un estado guardado
    ///   envejece solo: un permiso que vencio anoche seguiria diciendo
    ///   AUTORIZADO hasta que alguien corriera un proceso. `situacion` la
    ///   calcula el SEL_ contra la fecha de hoy.
    /// </summary>
    [Serializable]
    public class PermisoTrabajo
    {
        public int ptr_id { get; set; }
        public int ptr_cliente { get; set; }
        public int? ptr_orden_trabajo { get; set; }
        public int ptr_permiso_trabajo_tipo { get; set; }
        public int ptr_permiso_trabajo_estado { get; set; }
        public string ptr_numero { get; set; }
        public int? ptr_usuario_solicitante { get; set; }
        public DateTime? ptr_fecha_solicitud_utc { get; set; }
        public DateTime? ptr_fecha_vigencia_inicio_utc { get; set; }
        public DateTime? ptr_fecha_vigencia_fin_utc { get; set; }
        public string ptr_observacion { get; set; }
        public int? ptr_archivo { get; set; }
        public bool ptr_habilitado { get; set; }

        public int ptr_usuario_creacion { get; set; }
        public DateTime? ptr_fecha_creacion { get; set; }
        public int? ptr_usuario_actualizacion { get; set; }
        public DateTime? ptr_fecha_actualizacion { get; set; }

        // Columnas que arma el SEL_
        public string tipo_nombre { get; set; }
        public string tipo_codigo { get; set; }
        public string estado_nombre { get; set; }
        public string estado_codigo { get; set; }
        public string solicitante_nombre { get; set; }

        /* Para dibujar su avatar: el id decide el color, la foto la reemplaza
           cuando existe. Ver `SitioBase.Avatar`. */
        public int solicitante_id { get; set; }
        public int solicitante_foto { get; set; }

        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }
        public string orden_correlativo { get; set; }
        public string orden_titulo { get; set; }
        public string archivo_nombre { get; set; }
        public long archivo_byte { get; set; }
        public string archivo_extension { get; set; }

        /// <summary>Dias que le quedan. Negativo = ya vencio. Null = sin fin declarado.</summary>
        public int? dias_restantes { get; set; }

        /// <summary>VIGENTE · POR VENCER · VENCIDO · CERRADO · SIN VIGENCIA.</summary>
        public string situacion { get; set; }

        // Filtros que el Controller convierte en parametros del SEL_
        public string filtro { get; set; }
        public int filtro_orden_trabajo { get; set; }
        public int filtro_tipo { get; set; }
        public int filtro_estado { get; set; }
        public string filtro_situacion { get; set; }
        public bool? filtro_habilitado { get; set; }

        /// <summary>Si tiene el documento firmado adjunto.</summary>
        public bool tiene_archivo
        {
            get { return ptr_archivo != null && ptr_archivo.Value > 0; }
        }

        /// <summary>
        /// La clase del chip segun la situacion. Rojo lo vencido, ambar lo
        /// que esta por vencer: es el orden en que hay que mirarlos.
        /// </summary>
        public string situacion_clase
        {
            get
            {
                if (situacion == "VENCIDO") return "is-alerta";
                if (situacion == "POR VENCER") return "is-advertencia";
                if (situacion == "VIGENTE") return "is-exito";
                return "is-neutro";
            }
        }

        /// <summary>
        /// "Vence en 3 dias", "Vencio hace 5 dias". El numero de dias solo,
        /// en negativo, obliga a interpretarlo.
        /// </summary>
        public string vigencia_texto
        {
            get
            {
                if (dias_restantes == null) return "Sin vigencia declarada";

                int d = dias_restantes.Value;

                if (d < 0) return "Venció hace " + Math.Abs(d) + (Math.Abs(d) == 1 ? " día" : " días");
                if (d == 0) return "Vence hoy";
                if (d == 1) return "Vence mañana";

                return "Vence en " + d + " días";
            }
        }

        /// <summary>El peso del adjunto en algo que se pueda leer.</summary>
        public string archivo_peso
        {
            get
            {
                if (archivo_byte <= 0) return "";
                if (archivo_byte < 1024) return archivo_byte + " B";
                if (archivo_byte < 1048576) return (archivo_byte / 1024.0).ToString("N0") + " KB";

                return (archivo_byte / 1048576.0).ToString("N1") + " MB";
            }
        }
    }


    /// <summary>
    /// Un permiso en la pantalla de alerta (HU-064, bloque 97).
    ///
    /// TRAE MENOS QUE EL DETALLE, A PROPOSITO
    ///   Es para mirar de un vistazo antes de empezar a trabajar, no para
    ///   abrir cada fila. Traer las 32 columnas del detalle para pintar seis
    ///   es pagar el viaje completo por cada permiso de la planta.
    /// </summary>
    [Serializable]
    public class PermisoVigente
    {
        public int ptr_id { get; set; }
        public int ptr_permiso_trabajo_tipo { get; set; }
        public string ptr_numero { get; set; }
        public DateTime? ptr_fecha_vigencia_inicio_utc { get; set; }
        public DateTime? ptr_fecha_vigencia_fin_utc { get; set; }
        public int? ptr_archivo { get; set; }

        public string tipo_nombre { get; set; }
        public string estado_nombre { get; set; }
        public string estado_codigo { get; set; }
        public string solicitante_nombre { get; set; }

        /* Para dibujar su avatar: el id decide el color, la foto la reemplaza
           cuando existe. Ver `SitioBase.Avatar`. */
        public int solicitante_id { get; set; }
        public int solicitante_foto { get; set; }

        public string orden_correlativo { get; set; }
        public string orden_titulo { get; set; }
        public string instalacion_nombre { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }

        /// <summary>
        /// Si tiene el documento firmado. Un permiso vigente SIN documento
        /// no acredita nada, y en terreno eso importa tanto como la fecha.
        /// </summary>
        public bool tiene_documento { get; set; }

        /* Con que se llama el respaldo y de que tipo es. El panel de detalle
           decide con esto si lo muestra como imagen o lo ofrece para bajar. */
        public string archivo_nombre_vig { get; set; }
        public string archivo_extension_vig { get; set; }
        public string archivo_mime { get; set; }
        public long archivo_byte_vig { get; set; }

        public int? dias_restantes { get; set; }

        /// <summary>VIGENTE · POR VENCER · VENCIDO.</summary>
        public string situacion { get; set; }

        public string situacion_clase
        {
            get
            {
                if (situacion == "VENCIDO") return "is-alerta";
                if (situacion == "POR VENCER") return "is-advertencia";
                return "is-exito";
            }
        }

        /// <summary>
        /// "Vence en 3 dias", "Vencio hace 5 dias". Un "-5" obliga a
        /// interpretar el signo.
        /// </summary>
        public string vigencia_texto
        {
            get
            {
                if (dias_restantes == null) return "Sin vigencia declarada";

                int d = dias_restantes.Value;

                if (d < 0) return "Venció hace " + Math.Abs(d) + (Math.Abs(d) == 1 ? " día" : " días");
                if (d == 0) return "Vence hoy";
                if (d == 1) return "Vence mañana";

                return "Vence en " + d + " días";
            }
        }
    }


    /// <summary>Un tipo de permiso, para el combo (bloque 94).</summary>
    [Serializable]
    public class PermisoTrabajoTipo
    {
        public int ptt_id { get; set; }
        public string ptt_codigo { get; set; }
        public string ptt_nombre { get; set; }
        public int ptt_orden { get; set; }
    }


    /// <summary>Un estado de permiso, para el combo (bloque 94).</summary>
    [Serializable]
    public class PermisoTrabajoEstado
    {
        public int pte_id { get; set; }
        public string pte_codigo { get; set; }
        public string pte_nombre { get; set; }
        public int pte_orden { get; set; }
    }
}
