using System;
using System.Web;

/// <summary>
/// Trazabilidad de una ficha: quién la creó, quién la tocó y cuándo.
///
/// POR QUE ESTOS CUATRO DATOS VAN EN TODAS LAS FICHAS
///   Las tablas del proyecto llevan sus cuatro columnas de auditoría desde
///   las fundaciones y los SP las escriben religiosamente. Hasta ahora
///   ningún SEL_ las devolvía y ninguna pantalla las mostraba: el dato
///   existía y solo se podía leer con acceso a la base.
///
///   Una auditoría que hay que consultar por SSMS no sirve para lo que se
///   hizo. Cuando alguien pregunta "¿quién bajó este mínimo a 2?", la
///   respuesta tiene que estar en la ficha.
///
/// EL NOMBRE Y NO EL ID
///   "7" obliga a ir a buscar quién es 7. El SP devuelve el nombre armado.
/// </summary>
public partial class Comun_Controls_Auditoria : System.Web.UI.UserControl
{
    /// <summary>
    /// Pinta el bloque. Con todo vacío no se muestra: en un registro nuevo
    /// no hay nada que trazar y un panel con cuatro guiones es ruido.
    /// </summary>
    public void Mostrar(string usuarioCreacion, DateTime? fechaCreacion,
                        string usuarioActualizacion, DateTime? fechaActualizacion)
    {
        if (fechaCreacion == null && fechaActualizacion == null)
        {
            pnlAuditoria.Visible = false;
            return;
        }

        pnlAuditoria.Visible = true;

        litCreacion.Text = Linea(usuarioCreacion, fechaCreacion, "Sin registro");

        /* "Todavía no se ha editado" y no un guion: el guion se lee como
           "falta el dato", y acá el dato es justamente que nadie la tocó
           desde que se creó. */
        litActualizacion.Text = Linea(usuarioActualizacion, fechaActualizacion,
                                      "Todavía no se ha editado");
    }

    private string Linea(string usuario, DateTime? fecha, string vacio)
    {
        if (fecha == null)
            return "<span class=\"sin-dato\">" + HttpUtility.HtmlEncode(vacio) + "</span>";

        string texto = fecha.Value.ToString("dd-MM-yyyy HH:mm");

        if (!string.IsNullOrEmpty(usuario) && usuario.Trim().Length > 0)
            texto = HttpUtility.HtmlEncode(usuario.Trim()) + " &middot; " + texto;

        return texto;
    }
}
