using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Qué se está mirando: una bodega, un estante o un repuesto.
    /// </summary>
    public class DesgloseCabecera
    {
        public int Id { get; set; }

        /// <summary>"Bodega", "Ubicación" o "Repuesto". Es el rótulo, no un código.</summary>
        public string Tipo { get; set; }

        public string Codigo { get; set; }
        public string Nombre { get; set; }

        /// <summary>Dónde está: la planta, la bodega del estante, el fabricante del repuesto.</summary>
        public string Contexto { get; set; }

        public bool Habilitado { get; set; }

        /// <summary>
        /// Solo para un repuesto: cuánto hay en total.
        ///
        /// Va en la cabecera y no se deduce sumando el detalle porque, parado
        /// frente al estante, "cuánto tengo en total" es la primera pregunta,
        /// y sumar seis filas de cabeza es justo lo que no hay que pedirle a
        /// nadie con un teléfono en la mano.
        /// </summary>
        public decimal? Total { get; set; }

        public string Unidad { get; set; }
        public bool ControlaLote { get; set; }
    }

    /// <summary>
    /// Una línea del desglose: un repuesto, en un sitio, de un lote, con
    /// cuánto hay. Los tres SP devuelven esta misma forma; las columnas que
    /// no aplican vienen vacías y la pantalla las omite.
    /// </summary>
    public class DesgloseLinea
    {
        public int RepuestoId { get; set; }
        public string RepuestoCodigo { get; set; }
        public string RepuestoNombre { get; set; }
        public string Fabricante { get; set; }
        public string Modelo { get; set; }

        public string Bodega { get; set; }
        public string Ubicacion { get; set; }
        public string UbicacionNombre { get; set; }

        public string Unidad { get; set; }
        public decimal Cantidad { get; set; }
        public decimal? CostoPromedio { get; set; }

        public string LoteCodigo { get; set; }
        public DateTime? LoteVence { get; set; }
        public int? DiasParaVencer { get; set; }

        public DateTime? UltimoMovimiento { get; set; }
        public string UltimoUsuario { get; set; }
    }
}
