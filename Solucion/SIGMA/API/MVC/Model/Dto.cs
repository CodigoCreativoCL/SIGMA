using System;

namespace API.MVC.Model
{
    /* =====================================================================
       DTOs de la API.

       POR QUE NO SE DEVUELVE LA FILA COMPLETA
         Los SEL_ del proyecto traen todo lo que la web necesita para
         pintar sus grillas, y eso incluye columnas que fuera del servidor
         no le sirven a nadie y sí ayudan a quien quiera atacar: hashes de
         contraseña, sales, ids de auditoría, banderas internas.

         Un DTO por recurso es la lista explícita de lo que sale. Lo que no
         está declarado no viaja, y agregar una columna al SP no la publica
         por accidente.

       LOS NOMBRES SE MANTIENEN IGUALES A LA COLUMNA
         cin_id, no Id. Es la convención del grupo para los Model, es lo que
         permite que el mapeador por reflexión funcione sin configuración, y
         hace que un problema se pueda rastrear del JSON al SP sin traducir
         nombres por el camino.
       ===================================================================== */


    /// <summary>Lo que devuelve un login correcto (HU-001).</summary>
    [Serializable]
    public class SesionDto
    {
        public int usuario { get; set; }
        public string login { get; set; }
        public string nombre { get; set; }
        public int cliente { get; set; }
        public string cliente_nombre { get; set; }
        public string token { get; set; }
        public int expira_minutos { get; set; }

        /// <summary>
        /// True cuando la persona pertenece a más de un cliente y todavía
        /// no eligió (HU-002). La app tiene que mandarla a elegir antes de
        /// dejarla operar.
        /// </summary>
        public bool debe_elegir_cliente { get; set; }
    }

    /// <summary>Credenciales de entrada.</summary>
    public class LoginDto
    {
        public string login { get; set; }
        public string password { get; set; }
    }

    /// <summary>Lo que devuelve SEL_LOGIN.</summary>
    public class LoginResultado
    {
        public int ID { get; set; }
        public string CODE { get; set; }
        public string MENSAJE { get; set; }
    }

    /// <summary>Un cliente al que pertenece la persona (HU-002).</summary>
    public class ClienteElegibleDto
    {
        public int cli_id { get; set; }
        public string cli_nombre { get; set; }
    }

    public class SeleccionarClienteDto
    {
        public int cliente { get; set; }
    }


    /// <summary>Un permiso del usuario en el cliente en contexto (HU-006).</summary>
    public class PermisoDto
    {
        public string prm_codigo { get; set; }
    }


    /// <summary>Usuario del cliente (HU-014).</summary>
    public class ClienteUsuarioDto
    {
        public int usu_id { get; set; }
        public string usu_login { get; set; }
        public string usu_identificador { get; set; }
        public string usu_nombre { get; set; }
        public string usu_apellido_paterno { get; set; }
        public string usu_apellido_materno { get; set; }
        public string usu_correo { get; set; }
        public string usu_telefono { get; set; }
        public bool usu_habilitado { get; set; }
        public string PERFILES { get; set; }
    }

    public class ClienteUsuarioAltaDto
    {
        public string identificador { get; set; }
        public string login { get; set; }
        public string password { get; set; }
        public string nombres { get; set; }
        public string apellido_paterno { get; set; }
        public string apellido_materno { get; set; }
        public string telefono { get; set; }
        public string correo { get; set; }
        /// <summary>Ids de perfil separados por coma, como los espera el SP.</summary>
        public string perfiles { get; set; }
        public bool habilitado { get; set; }
    }


    /// <summary>Perfil y su matriz de permisos (HU-015).</summary>
    public class PerfilDto
    {
        public int per_id { get; set; }
        public string per_nombre { get; set; }
        public string per_descripcion { get; set; }
        public int per_tipo_perfil { get; set; }
        public bool per_solo_ejecucion { get; set; }
        public bool per_habilitado { get; set; }
    }

    public class PerfilAltaDto
    {
        public string nombre { get; set; }
        public string descripcion { get; set; }
        public int tipo { get; set; }
        public bool solo_ejecucion { get; set; }
        public bool habilitado { get; set; }
    }


    /// <summary>Planta del cliente (HU-011).</summary>
    public class ClienteInstalacionDto
    {
        public int cin_id { get; set; }
        public int cin_cliente { get; set; }
        public string cin_codigo { get; set; }
        public string cin_nombre { get; set; }
        public string cin_descripcion { get; set; }
        public string cin_direccion { get; set; }
        public int? cin_zona_horaria { get; set; }
        public decimal? cin_latitud { get; set; }
        public decimal? cin_longitud { get; set; }
        public bool cin_habilitado { get; set; }
    }

    public class ClienteInstalacionAltaDto
    {
        public string codigo { get; set; }
        public string nombre { get; set; }
        public string descripcion { get; set; }
        public string direccion { get; set; }
        public int? zona_horaria { get; set; }
        public decimal? latitud { get; set; }
        public decimal? longitud { get; set; }
        public bool habilitado { get; set; }
    }


    /// <summary>Área de una planta (HU-012).</summary>
    public class InstalacionAreaDto
    {
        public int iar_id { get; set; }
        public int iar_cliente { get; set; }
        public int iar_cliente_instalacion { get; set; }
        public int? iar_area_padre { get; set; }
        public string iar_codigo { get; set; }
        public string iar_nombre { get; set; }
        public string iar_descripcion { get; set; }
        public bool iar_habilitado { get; set; }
        public string PADRE_NOMBRE { get; set; }
        public int NIVEL { get; set; }
        public string RUTA { get; set; }
    }

    public class InstalacionAreaAltaDto
    {
        public int cliente_instalacion { get; set; }
        public int? area_padre { get; set; }
        public int? tipo { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
        public string descripcion { get; set; }
        public bool habilitado { get; set; }
        public bool quita_padre { get; set; }
    }


    /// <summary>Cliente de SIGMA (HU-010).</summary>
    public class ClienteDto
    {
        public int cli_id { get; set; }
        public string cli_nombre { get; set; }
        public string cli_razon_social { get; set; }
        public string cli_identificador { get; set; }
        public string cli_nombre_fantasia { get; set; }
        public int? cli_pais { get; set; }
        public string PAI_NOMBRE { get; set; }
        public int? cli_zona_horaria { get; set; }
        public int? cli_idioma { get; set; }
        public int? cli_moneda { get; set; }
        public bool cli_habilitado { get; set; }
    }

    public class ClienteAltaDto
    {
        public string nombre { get; set; }
        public string razon_social { get; set; }
        public string identificador { get; set; }
        public string nombre_fantasia { get; set; }
        public int pais { get; set; }
        public int? zona_horaria { get; set; }
        public int? idioma { get; set; }
        public int? moneda { get; set; }
        public bool habilitado { get; set; }
    }


    /// <summary>Especialidad y certificación de una persona (HU-017).</summary>
    public class UsuarioEspecialidadDto
    {
        public int ues_id { get; set; }
        public int ues_usuario { get; set; }
        public int ues_cliente { get; set; }
        public int ues_especialidad { get; set; }
        public string ESP_NOMBRE { get; set; }
        public int? ues_especialidad_nivel { get; set; }
        public string ENL_NOMBRE { get; set; }
        public string ues_certificacion { get; set; }
        public DateTime? ues_fecha_vencimiento { get; set; }
        public bool ues_habilitado { get; set; }
        public string USU_NOMBRE { get; set; }
        public string estado { get; set; }
        public int? dias_para_vencer { get; set; }
    }

    public class UsuarioEspecialidadAltaDto
    {
        public int usuario_destino { get; set; }
        public int especialidad { get; set; }
        public int? nivel { get; set; }
        public string certificacion { get; set; }
        public DateTime? fecha_vencimiento { get; set; }
        public bool habilitado { get; set; }
    }


    /// <summary>Permiso puntual de una persona (HU-007).</summary>
    public class ClienteUsuarioPermisoDto
    {
        public int cpm_id { get; set; }
        public int cpm_cliente_usuario { get; set; }
        public int cpm_permiso { get; set; }
        public string PRM_CODIGO { get; set; }
        public string PRM_NOMBRE { get; set; }
        public int? cpm_cliente_instalacion { get; set; }
        public int? cpm_instalacion_area { get; set; }
        public bool cpm_otorgado { get; set; }
        public DateTime? cpm_fecha_inicio { get; set; }
        public DateTime? cpm_fecha_fin { get; set; }
        public string cpm_motivo { get; set; }
        public bool cpm_habilitado { get; set; }
    }

    public class ClienteUsuarioPermisoAltaDto
    {
        public int cliente_usuario { get; set; }
        public int permiso { get; set; }
        public int? cliente_instalacion { get; set; }
        public int? instalacion_area { get; set; }
        public bool otorgado { get; set; }
        public DateTime? fecha_inicio { get; set; }
        public DateTime? fecha_fin { get; set; }
        public string motivo { get; set; }
        public bool habilitado { get; set; }
    }


    /// <summary>Grupo de trabajo (HU-016).</summary>
    public class GrupoTrabajoDto
    {
        public int gtr_id { get; set; }
        public int gtr_cliente { get; set; }
        public int? gtr_cliente_instalacion { get; set; }
        public string CIN_NOMBRE { get; set; }
        public string gtr_codigo { get; set; }
        public string gtr_nombre { get; set; }
        public string gtr_descripcion { get; set; }
        public int? gtr_especialidad { get; set; }
        public string ESP_NOMBRE { get; set; }
        public bool gtr_habilitado { get; set; }
    }

    public class GrupoTrabajoAltaDto
    {
        public int? cliente_instalacion { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
        public string descripcion { get; set; }
        public int? especialidad { get; set; }
        public bool habilitado { get; set; }
        public bool quita_planta { get; set; }
    }


    /// <summary>Solicitud de recuperación de contraseña (HU-004).</summary>
    public class RecuperacionDto
    {
        public string correo { get; set; }
    }

    public class RestablecerDto
    {
        public string token { get; set; }
        public string password_nuevo { get; set; }
    }


    /// <summary>Catálogo del sistema (HU-020).</summary>
    public class CatalogoDto
    {
        public int ctl_id { get; set; }
        public string ctl_codigo { get; set; }
        public string ctl_nombre { get; set; }
        public string ctl_descripcion { get; set; }
        public string ctl_modulo { get; set; }
        public bool ctl_ampliable { get; set; }
        public bool ctl_habilitado { get; set; }
    }

    /// <summary>Valor de un catálogo (HU-021).</summary>
    public class CatalogoValorDto
    {
        public int valor_id { get; set; }
        public string valor_codigo { get; set; }
        public string valor_nombre { get; set; }
        public string valor_descripcion { get; set; }
        public int? valor_orden { get; set; }
        public int? valor_cliente { get; set; }
        public bool valor_habilitado { get; set; }
    }

    public class CatalogoValorAltaDto
    {
        public int catalogo { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
        public string descripcion { get; set; }
        public int? orden { get; set; }
        public bool habilitado { get; set; }
    }


    /// <summary>Centro de costo (HU-013).</summary>
    public class CentroCostoDto
    {
        public int cco_id { get; set; }
        public int cco_cliente { get; set; }
        public int? cco_centro_costo_padre { get; set; }
        public string cco_codigo { get; set; }
        public string cco_nombre { get; set; }
        public bool cco_habilitado { get; set; }
        public string PADRE_NOMBRE { get; set; }
        public int NIVEL { get; set; }
        public string RUTA { get; set; }
    }

    public class CentroCostoAltaDto
    {
        public int? centro_costo_padre { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
        public bool habilitado { get; set; }
        public bool quita_padre { get; set; }
    }


    /// <summary>Mi perfil (HU-005).</summary>
    public class MiPerfilDto
    {
        public int usu_id { get; set; }
        public string usu_login { get; set; }
        public string usu_nombre { get; set; }
        public string usu_apellido_paterno { get; set; }
        public string usu_apellido_materno { get; set; }
        public string usu_correo { get; set; }
        public string usu_telefono { get; set; }
        public string PERFILES { get; set; }
    }

    public class MiPerfilEdicionDto
    {
        public string telefono { get; set; }
        public int? idioma { get; set; }
    }

    public class CambioPasswordDto
    {
        public string password_actual { get; set; }
        public string password_nuevo { get; set; }
    }
}
