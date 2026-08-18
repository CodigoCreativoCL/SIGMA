using System;

public partial class View_Comun_Controls_PanelSinSeleccion : System.Web.UI.UserControl
{
    private string icono = "fas fa-filter";
    private string titulo = "Sin selección";
    private string descripcion = "Seleccione un cliente para continuar.";

    public string Icono
    {
        get { return icono; }
        set { icono = value; }
    }

    public string Titulo
    {
        get { return titulo; }
        set { titulo = value; }
    }

    public string Descripcion
    {
        get { return descripcion; }
        set { descripcion = value; }
    }

    public bool MostrarPanel
    {
        get { return phPanel.Visible; }
        set { phPanel.Visible = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
    }
}
