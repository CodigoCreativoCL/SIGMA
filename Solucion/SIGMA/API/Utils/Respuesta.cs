using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Data;


[Serializable]
public class Respuesta
{
    public int codigo { get; set; }
    public string detalle { get; set; }
    public bool error { get; set; }
    public DataTable table { get; set; }
    public int cantidaCargada { get; set; }
    public int cantidaError { get; set; }
    public string jsonRespuesta { get; set; }

}

