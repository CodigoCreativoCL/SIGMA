using SitioBase.Controller;
using System;
using System.Globalization;
using Telerik.Web.UI;

/// <summary>
/// Accesibilidad: cada persona configura SUS opciones (HU-162).
///
/// La pantalla carga lo que la persona tiene guardado (o los valores por
/// defecto si todavía no configuró nada) y, al guardar, lo conserva. El acceso
/// lo exige el master contra el menú; las opciones son siempre las de la
/// persona en sesión, nunca las de otra.
/// </summary>
public partial class View_Comun_Accesibilidad_Accesibilidad : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack) Cargar();
    }

    /// <summary>Pinta en la pantalla lo que la persona tiene hoy.</summary>
    private void Cargar()
    {
        UsuarioAccesibilidad o = new AccesibilidadController().GetMisOpciones();

        chkTextoGrande.Checked = o.texto_grande;
        chkAltoContraste.Checked = o.alto_contraste;
        chkIconosGrandes.Checked = o.iconos_grandes;

        chkEntradaVoz.Checked = o.entrada_voz;
        chkLecturaVoz.Checked = o.lectura_voz;
        chkConfirmacionHablada.Checked = o.confirmacion_hablada;

        chkSilenciar.Checked = o.silenciar_alertas;

        Seleccionar(cboVelocidad, o.velocidad_voz);
        Seleccionar(cboVolumen, o.volumen);
    }

    /// <summary>Marca en el combo la opción cuyo valor coincide con el guardado.</summary>
    private static void Seleccionar(RadComboBox2 combo, decimal valor)
    {
        string v = valor.ToString("0.00", CultureInfo.InvariantCulture);
        RadComboBoxItem item = combo.FindItemByValue(v);
        if (item != null) item.Selected = true;
        else if (combo.Items.Count > 0) combo.Items[0].Selected = true;
    }
}
