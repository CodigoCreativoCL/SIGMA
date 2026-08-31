using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una etiqueta imprimible, ya normalizada.
    ///
    /// POR QUE LAS PROPIEDADES NO SE LLAMAN COMO COLUMNAS
    ///   La convención del proyecto es que el modelo repita el nombre de la
    ///   columna (bod_codigo, rep_nombre). Acá no aplica: esto no mapea una
    ///   tabla. Es la forma común a la que SEL_ETIQUETA reduce cosas muy
    ///   distintas —una bodega, un estante, un repuesto, un activo— para que
    ///   la pantalla que imprime no tenga que saber cuál está imprimiendo.
    ///
    ///   Un estante y un repuesto no comparten ninguna columna, así que
    ///   copiar nombres de columna acá obligaría a elegir los de uno de los
    ///   dos y mentir sobre el otro.
    /// </summary>
    public class Etiqueta
    {
        /// <summary>Lo que viaja en el QR: UBI-17, BOD-9, REP-24, ACT-31.</summary>
        public string Token { get; set; }

        public int Id { get; set; }

        /// <summary>Lo que se lee de lejos y se teclea si el QR está rayado.</summary>
        public string Codigo { get; set; }

        public string Titulo { get; set; }
        public string Subtitulo { get; set; }
        public string Detalle { get; set; }
        public string Pie { get; set; }

        /// <summary>
        /// La imagen del QR como data URI. Se arma en el controlador y no en
        /// la página: una etiqueta sin su código no es una etiqueta, así que
        /// no puede depender de que la pantalla se acuerde de generarlo.
        /// </summary>
        public string QrDataUri { get; set; }
    }

    /// <summary>
    /// Un módulo que se puede etiquetar, tal como está declarado en la tabla
    /// Etiqueta_Origen.
    ///
    /// El catálogo vive en la base y no en una lista de C#: agregar un módulo
    /// imprimible es un INSERT más una rama en SEL_ETIQUETA, y no se toca
    /// ninguna vista. Es la misma idea que ya gobierna el menú y los
    /// permisos.
    /// </summary>
    public class EtiquetaOrigenItem
    {
        public int eto_id { get; set; }
        public string eto_codigo { get; set; }
        public string eto_nombre { get; set; }
        public string eto_descripcion { get; set; }
        public string eto_icono { get; set; }
        public int eto_orden { get; set; }

        /// <summary>Si el origen se puede acotar a una bodega.</summary>
        public bool eto_por_bodega { get; set; }

        public bool eto_habilitado { get; set; }

        /// <summary>
        /// Por qué está apagado. Se muestra en la tarjeta: una opción gris
        /// sin explicación se lee como que algo se rompió.
        /// </summary>
        public string eto_motivo_baja { get; set; }

        /// <summary>El permiso que hay que tener para ver ese origen.</summary>
        public string Permiso { get; set; }
    }

    /// <summary>
    /// Los códigos que entiende SEL_ETIQUETA. Son los mismos que están en la
    /// tabla; acá viven como constantes para que el compilador atrape un
    /// error de tipeo en las pantallas que los usan directamente.
    /// </summary>
    public static class EtiquetaOrigen
    {
        public const string Bodega = "BODEGA";
        public const string Ubicacion = "UBICACION";
        public const string UbicacionRepuesto = "UBICACION_REPUESTO";
        public const string Repuesto = "REPUESTO";
        public const string Activo = "ACTIVO";
    }
}
