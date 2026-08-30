using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una entrada del registro de catalogos (HU-020).
    ///
    /// No es un catalogo en si: describe DONDE vive uno. ctl_tabla y
    /// ctl_prefijo son lo que SEL_CATALOGO_VALOR usa para consultar la
    /// tabla real. Por eso una sola pantalla puede recorrer los ochenta.
    /// </summary>
    [Serializable]
    public class Catalogo
    {
        public int ctl_id { get; set; }
        public string ctl_codigo { get; set; }
        public string ctl_nombre { get; set; }
        public string ctl_descripcion { get; set; }
        public string ctl_tabla { get; set; }
        public string ctl_prefijo { get; set; }
        public string ctl_modulo { get; set; }
        public bool ctl_ampliable { get; set; }
        public int? ctl_orden { get; set; }
        public bool ctl_habilitado { get; set; }

        public string tipo { get; set; }

        public string filtro { get; set; }
        public bool? filtro_ampliable { get; set; }
        public bool? filtro_habilitado { get; set; }
        public string filtro_modulo { get; set; }
    }

    /// <summary>
    /// Un valor de cualquier catalogo, en una forma unica.
    ///
    /// Da igual que tabla haya detras: SEL_CATALOGO_VALOR siempre devuelve
    /// estas columnas, de modo que la grilla no cambia de un catalogo a
    /// otro. Las que el catalogo no tenga -descripcion, orden, cliente-
    /// vienen en NULL.
    /// </summary>
    [Serializable]
    public class CatalogoValor
    {
        public int valor_id { get; set; }
        public string valor_codigo { get; set; }
        public string valor_nombre { get; set; }
        public string valor_descripcion { get; set; }
        public int? valor_orden { get; set; }
        public bool valor_habilitado { get; set; }
        public int? valor_cliente { get; set; }
        public string origen { get; set; }

        // Solo se informan en el resultado de la busqueda transversal
        public int ctl_id { get; set; }
        public string ctl_codigo { get; set; }
        public string ctl_nombre { get; set; }
        public string ctl_modulo { get; set; }
        public bool ctl_ampliable { get; set; }
    }
}
