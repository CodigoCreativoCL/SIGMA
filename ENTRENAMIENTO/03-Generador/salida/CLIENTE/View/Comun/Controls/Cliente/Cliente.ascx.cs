using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// CODE-BEHIND DEL CONTENEDOR DE TABS DE CLIENTE.
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
public partial class View_Comun_Controls_Cliente_Cliente : System.Web.UI.UserControl
{
    #region PROPIEDADES

    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    /// <summary>0 = alta de un registro nuevo. > 0 = edicion de uno existente.</summary>
    public int IdCliente
    {
        get { return ViewState["IdCliente"] == null ? 0 : (int)ViewState["IdCliente"]; }
        set { ViewState["IdCliente"] = value; }
    }

    public string URLVolverCliente
    {
        get { return ViewState["URLVolverCliente"] == null ? "" : ViewState["URLVolverCliente"].ToString(); }
        set { ViewState["URLVolverCliente"] = value; }
    }

    #endregion

    /// <summary>
    /// Propaga el estado a los tabs. Se hace en PreRender para que los valores
    /// que la pagina padre seteo en su Page_Load ya esten disponibles.
    /// </summary>
    protected void Page_PreRender(object sender, EventArgs e)
    {
        wucIdentidad.ReadOnly = ReadOnly;
        wucIdentidad.IdCliente = IdCliente;

        // Si en el futuro se agregan tabs, se les pasan las mismas
        // propiedades aqui y nada mas cambia.
    }
}
