using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Especialidad y certificacion de una persona (HU-017).
    ///
    /// ESTADO y DIAS_PARA_VENCER los calcula SEL_USUARIO_ESPECIALIDAD:
    ///   VIGENTE / POR_VENCER / VENCIDA / SIN_CERTIFICACION
    ///
    /// Una certificacion vencida NO impide asignar trabajo. El escenario 2
    /// es explicito: se muestra la advertencia y la asignacion se permite.
    /// Bloquearla detendria la planta cuando un certificado caduca fuera de
    /// horario administrativo.
    /// </summary>
    [Serializable]
    public class UsuarioEspecialidad
    {
        public int ues_id { get; set; }
        public int ues_usuario { get; set; }
        public int ues_cliente { get; set; }
        public int ues_especialidad { get; set; }
        public int? ues_especialidad_nivel { get; set; }
        public string ues_certificacion { get; set; }
        public DateTime? ues_fecha_vencimiento { get; set; }
        public int ues_usuario_creacion { get; set; }
        public DateTime? ues_fecha_creacion { get; set; }
        public bool ues_habilitado { get; set; }

        // Columnas del JOIN y calculadas
        public string esp_codigo { get; set; }
        public string esp_nombre { get; set; }
        public string enl_nombre { get; set; }
        public string usu_nombre { get; set; }
        public string usu_correo { get; set; }
        public int? dias_para_vencer { get; set; }
        public string estado { get; set; }

        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool filtro_solo_vencidas { get; set; }
        public bool filtro_solo_por_vencer { get; set; }
    }
}
