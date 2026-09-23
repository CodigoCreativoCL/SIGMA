using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un paso de procedimiento MIENTRAS SE EDITA, antes de existir en la base.
    ///
    /// No es ProcedimientoPaso: ese es la fila de la tabla y siempre tiene id.
    /// Este vive en el ViewState de la pantalla unificada -donde la receta y
    /// sus pasos se arman completos y se escriben al guardar- y ademas carga el
    /// resultado de revisar una planilla: de que fila salio, si sirve y por que
    /// no. Con id = 0 todavia no esta escrito.
    ///
    /// Vive en App_Code y no en la pagina porque el controlador de la carga
    /// masiva devuelve listas de esto, y App_Code se compila antes que las
    /// paginas: un tipo declarado en un .aspx.cs no se ve desde aca.
    /// </summary>
    [Serializable]
    public class ProcedimientoPasoEdicion
    {
        public int id { get; set; }                  // 0 = todavia no esta en la base
        public string nombre { get; set; }
        public string instruccion { get; set; }
        public int? duracion { get; set; }
        public bool punto_control { get; set; }
        public bool evidencia { get; set; }
        public bool medicion { get; set; }
        public int? variable { get; set; }
        public string variable_nombre { get; set; }
        public bool habilitado { get; set; }

        // Solo para la revision de la planilla.
        public int fila { get; set; }
        public bool ok { get; set; }
        public string motivo { get; set; }
    }
}
