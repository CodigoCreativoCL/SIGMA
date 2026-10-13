using SitioBase.Controller;
using System;
using System.Globalization;
using System.Web.UI;
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

    /// <summary>Guarda lo elegido. La validación dura la hacen los SP; acá sólo se arma el modelo.</summary>
    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        AccesibilidadController ctrl = new AccesibilidadController();

        // Se parte de lo guardado para conservar el uac_id (crear vs corregir).
        UsuarioAccesibilidad o = ctrl.GetMisOpciones();

        o.texto_grande = chkTextoGrande.Checked;
        o.alto_contraste = chkAltoContraste.Checked;
        o.iconos_grandes = chkIconosGrandes.Checked;
        o.entrada_voz = chkEntradaVoz.Checked;
        o.lectura_voz = chkLecturaVoz.Checked;
        o.confirmacion_hablada = chkConfirmacionHablada.Checked;
        o.silenciar_alertas = chkSilenciar.Checked;
        o.velocidad_voz = ADecimal(cboVelocidad.SelectedValue, 1.00m);
        o.volumen = ADecimal(cboVolumen.SelectedValue, 1.00m);

        Respuesta r = ctrl.GuardarMisOpciones(o);

        litAviso.Text = "<div class=\"sg-ot-nota " + (r.error ? "es-aviso" : "es-ok") + "\" style=\"margin-bottom:14px\">" +
                        "<i class=\"mdi " + (r.error ? "mdi-alert-outline" : "mdi-check-circle-outline") + "\"></i>" +
                        "<span>" + Server.HtmlEncode(r.detalle) + "</span></div>";

        if (!r.error)
        {
            /* Que el cambio se vea YA, sin recargar: se ajustan las clases del
               body en el cliente. En las demás pantallas las pone el master
               desde la sesión. */
            string js = "var b=document.body;" +
                        "b.classList.toggle('sg-acc-texto-grande'," + Js(o.texto_grande) + ");" +
                        "b.classList.toggle('sg-acc-alto-contraste'," + Js(o.alto_contraste) + ");" +
                        "b.classList.toggle('sg-acc-iconos-grandes'," + Js(o.iconos_grandes) + ");";
            ScriptManager.RegisterStartupScript(this, GetType(), "accAplica", js, true);
        }

        udPanel.Update();
    }

    private static decimal ADecimal(string v, decimal def)
    {
        decimal d;
        return decimal.TryParse(v, NumberStyles.Any, CultureInfo.InvariantCulture, out d) ? d : def;
    }

    private static string Js(bool b) { return b ? "true" : "false"; }
}
