using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una categoría de repuesto: rodamientos, correas, filtros, eléctrico.
    ///
    /// LOS DEFINE EL CLIENTE, SIEMPRE
    ///   `rti_cliente` es obligatorio en la base: no existen tipos globales.
    ///   Ninguna lista de categorías sirve para dos plantas distintas —una
    ///   papelera y una minera no comparten ninguna—, y una lista "estándar"
    ///   termina siendo la de quien la escribió más un "Otros" donde cae todo.
    /// </summary>
    [Serializable]
    public class RepuestoTipo
    {
        public int rti_id { get; set; }
        public int rti_cliente { get; set; }
        public string rti_codigo { get; set; }
        public string rti_nombre { get; set; }
        public string rti_descripcion { get; set; }

        /// <summary>
        /// Orden de las pestañas del listado. Sin esto quedarían alfabéticas,
        /// y la categoría que más se usa terminaría al final solo por empezar
        /// con T.
        /// </summary>
        public int rti_orden { get; set; }

        public DateTime? rti_fecha_creacion { get; set; }
        public bool rti_habilitado { get; set; }

        /// <summary>
        /// Cuántos repuestos activos cuelgan del tipo. Lo calcula
        /// `SEL_REPUESTO_TIPO` en la misma consulta: la pestaña lo muestra y
        /// la ficha lo necesita para no dejar deshabilitar un tipo en uso.
        /// </summary>
        public int repuestos { get; set; }

        // ---- filtros ----
        public bool? filtro_habilitado { get; set; }
        public string filtro { get; set; }
    }
}
