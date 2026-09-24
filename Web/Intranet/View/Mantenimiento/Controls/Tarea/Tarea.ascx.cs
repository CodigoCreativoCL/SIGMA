using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// CODE-BEHIND DEL CONTENEDOR DE TABS DE TAREA.
///
/// PATRON (ver PATRON_MVC.md seccion 5):
///  - Este archivo es intencionalmente MINIMO.
///  - No carga datos, no guarda, no llama al Controller.
///  - Solo declara las propiedades publicas y se las pasa a los tabs hijos.
///
/// Regla para el equipo: si estas escribiendo logica de negocio aqui,
/// esa logica va en el tab (Identidad.ascx.cs) o en el Controller.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class View_Mantenimiento_Controls_Tarea_Tarea : System.Web.UI.UserControl
{
    #region PROPIEDADES

    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    /// <summary>0 = alta de un registro nuevo. > 0 = edicion de uno existente.</summary>
    public int IdTarea
    {
        get { return ViewState["IdTarea"] == null ? 0 : (int)ViewState["IdTarea"]; }
        set { ViewState["IdTarea"] = value; }
    }

    public string URLVolverTarea
    {
        get { return ViewState["URLVolverTarea"] == null ? "" : ViewState["URLVolverTarea"].ToString(); }
        set { ViewState["URLVolverTarea"] = value; }
    }

    #endregion

    /// <summary>
    /// Propaga el estado a los tabs. Se hace en PreRender para que los valores
    /// que la pagina padre seteo en su Page_Load ya esten disponibles.
    /// </summary>
    protected void Page_PreRender(object sender, EventArgs e)
    {
        wucIdentidad.ReadOnly = ReadOnly;
        wucIdentidad.IdTarea = IdTarea;

        // Si en el futuro se agregan tabs, se les pasan las mismas
        // propiedades aqui y nada mas cambia.
    }
}
