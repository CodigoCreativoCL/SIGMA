using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Web.UI;

/// <summary>
/// Alta de varios activos desde una planilla (bloque 283).
///
/// POR QUE EXISTE
///   Un cliente que parte con SIGMA llega con su catalogo en un Excel:
///   doscientos equipos. Cargarlos de a uno por la ficha son doscientas
///   aperturas de modal, y es lo PRIMERO que hay que hacer para que el resto
///   del sistema sirva de algo.
///
/// NADA SE ESCRIBE ANTES DE MOSTRAR QUE SE VA A ESCRIBIR
///   La pantalla valida la planilla entera y muestra fila por fila que va a
///   pasar. Una carga que se cae a la mitad deja un catalogo incompleto y
///   nadie sabe donde quedo.
///
/// LAS REGLAS NO SE DUPLICAN
///   Cada fila valida entra por InsertActivo, el mismo camino de la ficha.
///   Escribir el INSERT aca significaria mantener dos veces las reglas de
///   codigo repetido, de planta obligatoria y de todo lo que valide el SP.
/// </summary>
public partial class View_Activos_Ficha_CargaMasivaActivos : System.Web.UI.Page
{
    /// <summary>
    /// Una fila de la planilla, ya interpretada.
    ///
    /// Serializable porque lo revisado viaja en el ViewState: confirmar no
    /// vuelve a leer el archivo, que ya no esta -el FileUpload se vacia en el
    /// postback siguiente- y ademas se estaria validando dos veces contra una
    /// base que pudo cambiar en el medio.
    /// </summary>
    [Serializable]
    private class Fila
    {
        public int numero;
        public string codigo = "";
        public string nombre = "";
        public string planta = "";
        public string area = "";
        public string tipo = "";
        public string estado = "";
        public string criticidad = "";
        public string fabricante = "";
        public string serie = "";
        public string anio = "";
        public string puesta = "";
        public string descripcion = "";

        public Activo activo;
        public List<string> errores = new List<string>();

        public bool valida { get { return errores.Count == 0; } }
    }

    private int _cliente;

    /// <summary>Lo revisado, para no volver a leer el archivo al confirmar.</summary>
    private List<Fila> Filas
    {
        get { return ViewState["Filas"] as List<Fila> ?? new List<Fila>(); }
        set { ViewState["Filas"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        _cliente = SitioBase.Session.ClienteId();
    }

    #region 1. La plantilla

    /// <summary>
    /// La plantilla, con una fila de ejemplo hecha con los valores que ESTE
    /// cliente tiene cargados.
    ///
    /// Una plantilla con "Planta 1" de ejemplo obliga a adivinar como se
    /// llaman las plantas de verdad; con la primera planta real, se copia.
    /// </summary>
    protected void lnkPlantilla_Click(object sender, EventArgs e)
    {
        try
        {
            StringBuilder sb = new StringBuilder();

            sb.AppendLine("Codigo;Nombre;Planta;Area;Tipo;Estado;Criticidad;Fabricante;NumeroSerie;AnioFabricacion;FechaPuestaMarcha;Descripcion");

            sb.Append("ACT-001;Ejemplo: bomba centrifuga 1;")
              .Append(Primero(Plantas())).Append(";")
              .Append(Primero(Areas())).Append(";")
              .Append(Primero(Tipos())).Append(";")
              .Append(Primero(Estados())).Append(";")
              .Append(Primero(Criticidades())).Append(";")
              .AppendLine("Grundfos;SN-12345;2021;01-03-2021;Borre esta fila antes de subir el archivo");

            Response.Clear();
            Response.Buffer = true;
            Response.AddHeader("content-disposition", "attachment;filename=Plantilla_Activos.csv");
            Response.ContentType = "text/csv";
            Response.Charset = "UTF-8";
            Response.ContentEncoding = Encoding.UTF8;

            /* El BOM: sin el, Excel abre el CSV en la codificacion del sistema
               y "Línea 1" llega como "LÃ­nea 1". */
            Response.BinaryWrite(Encoding.UTF8.GetPreamble());
            Response.Write(sb.ToString());
            Response.Flush();
            Response.End();
        }
        catch (System.Threading.ThreadAbortException) { }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    private static string Primero(Dictionary<string, int> catalogo)
    {
        foreach (KeyValuePair<string, int> x in catalogo) return x.Key;
        return "";
    }

    #endregion

    #region 2. Revisar

    protected void lnkRevisar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR ACTIVOS"))
                throw new Exception("No tiene permiso para crear activos.");

            if (!fuPlanilla.HasFile)
                throw new Exception("Elija primero el archivo con la planilla.");

            string texto;

            using (System.IO.StreamReader sr = new System.IO.StreamReader(fuPlanilla.FileContent, Encoding.UTF8, true))
                texto = sr.ReadToEnd();

            List<Fila> filas = Interpretar(texto);

            if (filas.Count == 0)
                throw new Exception("La planilla no tiene filas con datos.");

            Validar(filas);

            Filas = filas;
            Pintar(filas);

            pnlPrevia.Visible = true;
            pnlResultado.Visible = false;
            udPanel.Update();
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Lee el CSV. Punto y coma, que es lo que escribe Excel en español.
    ///
    /// No se usa un lector de CSV completo a proposito: un catalogo de
    /// equipos no trae saltos de linea dentro de una celda, y las comillas se
    /// limpian. Lo que no calce lo dice la validacion, con el numero de fila.
    /// </summary>
    private List<Fila> Interpretar(string texto)
    {
        List<Fila> filas = new List<Fila>();

        string[] lineas = (texto ?? "").Replace("\r\n", "\n").Replace("\r", "\n").Split('\n');

        for (int i = 0; i < lineas.Length; i++)
        {
            string linea = lineas[i];

            if (string.IsNullOrEmpty(linea.Trim())) continue;

            // la cabecera se salta por su primera celda, no por ser la primera
            // linea: hay planillas que traen una fila de titulo antes.
            string[] c = linea.Split(';');
            string primera = Limpiar(c.Length > 0 ? c[0] : "");

            if (primera.Equals("Codigo", StringComparison.OrdinalIgnoreCase) ||
                primera.Equals("Código", StringComparison.OrdinalIgnoreCase)) continue;

            Fila f = new Fila();
            f.numero = i + 1;
            f.codigo = Celda(c, 0);
            f.nombre = Celda(c, 1);
            f.planta = Celda(c, 2);
            f.area = Celda(c, 3);
            f.tipo = Celda(c, 4);
            f.estado = Celda(c, 5);
            f.criticidad = Celda(c, 6);
            f.fabricante = Celda(c, 7);
            f.serie = Celda(c, 8);
            f.anio = Celda(c, 9);
            f.puesta = Celda(c, 10);
            f.descripcion = Celda(c, 11);

            // una fila con todo vacio es el final del archivo, no un error
            if (f.codigo.Length == 0 && f.nombre.Length == 0) continue;

            filas.Add(f);
        }

        return filas;
    }

    private static string Celda(string[] c, int i)
    {
        return i < c.Length ? Limpiar(c[i]) : "";
    }

    private static string Limpiar(string s)
    {
        return (s ?? "").Trim().Trim('"').Trim();
    }

    /// <summary>
    /// Arma el activo de cada fila y anota lo que no calza.
    ///
    /// Los catalogos se resuelven por NOMBRE porque es lo que la planilla
    /// trae: nadie escribe el id de la planta. Y se comparan sin distinguir
    /// mayusculas ni espacios de mas, que es como se escriben a mano.
    /// </summary>
    private void Validar(List<Fila> filas)
    {
        Dictionary<string, int> plantas = Plantas();
        Dictionary<string, int> areas = Areas();
        Dictionary<string, int> tipos = Tipos();
        Dictionary<string, int> estados = Estados();
        Dictionary<string, int> criticidades = Criticidades();

        // los codigos que ya existen, para no mandar al SP lo que va a rebotar
        List<Activo> existentes = new ActivoController().GetActivos(
            new Activo { act_cliente = _cliente }) ?? new List<Activo>();

        HashSet<string> yaEstan = new HashSet<string>(
            existentes.Where(x => !string.IsNullOrEmpty(x.act_codigo)).Select(x => Clave(x.act_codigo)));

        HashSet<string> enLaPlanilla = new HashSet<string>();

        foreach (Fila f in filas)
        {
            Activo a = new Activo();
            a.act_cliente = _cliente;
            a.act_habilitado = true;

            if (f.codigo.Length == 0) f.errores.Add("Falta el código");
            else if (yaEstan.Contains(Clave(f.codigo))) f.errores.Add("Ya existe un activo con ese código");
            else if (!enLaPlanilla.Add(Clave(f.codigo))) f.errores.Add("El código está repetido en la planilla");

            if (f.nombre.Length == 0) f.errores.Add("Falta el nombre");

            a.act_codigo = f.codigo;
            a.act_nombre = f.nombre;

            a.act_cliente_instalacion = Buscar(plantas, f.planta, "Planta", f.errores);
            a.act_activo_tipo = Buscar(tipos, f.tipo, "Tipo", f.errores);
            a.act_activo_estado = Buscar(estados, f.estado, "Estado", f.errores);
            a.act_criticidad_nivel = Buscar(criticidades, f.criticidad, "Criticidad", f.errores);

            /* El area es opcional, pero si la escribieron mal hay que decirlo:
               dejarla en blanco en silencio pierde el dato sin avisar. */
            if (f.area.Length > 0)
            {
                int area;
                if (areas.TryGetValue(Clave(f.area), out area)) a.act_instalacion_area = area;
                else f.errores.Add("El área «" + f.area + "» no existe");
            }

            if (f.fabricante.Length > 0) a.act_fabricante = f.fabricante;
            if (f.serie.Length > 0) a.act_numero_serie = f.serie;
            if (f.descripcion.Length > 0) a.act_descripcion = f.descripcion;

            if (f.anio.Length > 0)
            {
                int anio;
                if (!int.TryParse(f.anio, out anio) || anio < 1900 || anio > DateTime.Now.Year + 1)
                    f.errores.Add("El año de fabricación «" + f.anio + "» no es un año válido");
                else a.act_anio_fabricacion = anio;
            }

            if (f.puesta.Length > 0)
            {
                DateTime fecha;
                string[] formatos = { "dd-MM-yyyy", "dd/MM/yyyy", "yyyy-MM-dd" };

                if (!DateTime.TryParseExact(f.puesta, formatos, CultureInfo.InvariantCulture,
                                            DateTimeStyles.None, out fecha))
                    f.errores.Add("La fecha «" + f.puesta + "» no es una fecha válida (dd-mm-aaaa)");
                else a.act_fecha_puesta_marcha = fecha;
            }

            f.activo = a;
        }
    }

    /// <summary>Resuelve un catalogo por nombre y anota el error con el valor que vino.</summary>
    private static int Buscar(Dictionary<string, int> catalogo, string valor, string campo, List<string> errores)
    {
        if (valor.Length == 0) { errores.Add("Falta " + campo.ToLower()); return 0; }

        int id;
        if (catalogo.TryGetValue(Clave(valor), out id)) return id;

        errores.Add(campo + " «" + valor + "» no existe");
        return 0;
    }

    private static string Clave(string s)
    {
        return (s ?? "").Trim().ToUpperInvariant();
    }

    #endregion

    #region Los catalogos

    private Dictionary<string, int> Plantas()
    {
        Dictionary<string, int> d = new Dictionary<string, int>();

        List<ClienteInstalacion> lista = new ClienteInstalacionController().GetClienteInstalaciones(
            new ClienteInstalacion { filtro_cliente = _cliente.ToString(), filtro_habilitado = "1" });

        if (lista != null)
            foreach (ClienteInstalacion x in lista) d[Clave(x.cin_nombre)] = x.cin_id;

        return d;
    }

    private Dictionary<string, int> Areas()
    {
        Dictionary<string, int> d = new Dictionary<string, int>();

        List<InstalacionArea> lista = new InstalacionAreaController().GetInstalacionAreas(
            new InstalacionArea { iar_cliente = _cliente, filtro_habilitado = true });

        if (lista != null)
            foreach (InstalacionArea x in lista) d[Clave(x.iar_nombre)] = x.iar_id;

        return d;
    }

    private Dictionary<string, int> Tipos()
    {
        Dictionary<string, int> d = new Dictionary<string, int>();

        List<ActivoTipo> lista = new ActivoTipoController().GetActivoTipos(
            new ActivoTipo { filtro_cliente = _cliente, filtro_habilitado = true });

        if (lista != null)
            foreach (ActivoTipo x in lista) d[Clave(x.ati_nombre)] = x.ati_id;

        return d;
    }

    private Dictionary<string, int> Estados()
    {
        Dictionary<string, int> d = new Dictionary<string, int>();

        List<ActivoEstado> lista = new ActivoEstadoController().GetActivoEstados(
            new ActivoEstado { filtro_habilitado = true });

        if (lista != null)
            foreach (ActivoEstado x in lista) d[Clave(x.aes_nombre)] = x.aes_id;

        return d;
    }

    private Dictionary<string, int> Criticidades()
    {
        Dictionary<string, int> d = new Dictionary<string, int>();

        List<CriticidadNivel> lista = new CriticidadNivelController().GetCriticidadNiveles(
            new CriticidadNivel { filtro_habilitado = true });

        if (lista != null)
            foreach (CriticidadNivel x in lista) d[Clave(x.crn_nombre)] = x.crn_id;

        return d;
    }

    #endregion

    #region 3. La vista previa y la carga

    private void Pintar(List<Fila> filas)
    {
        int validas = filas.Count(x => x.valida);

        litResumen.Text =
            "<div class=\"sg-ot-avance\">" +
            "<div class=\"sg-ot-avance-num\"><strong>" + filas.Count + "</strong><span>filas leídas</span></div>" +
            "<div class=\"sg-ot-avance-num\"><strong>" + validas + "</strong><span>se van a crear</span></div>" +
            "<div class=\"sg-ot-avance-num\"><strong>" + (filas.Count - validas) + "</strong><span>con problemas</span></div></div>";

        lnkCargar.Visible = validas > 0;

        StringBuilder s = new StringBuilder("<div class=\"sg-carga-tabla\">");

        s.Append("<div class=\"sg-carga-cab\"><span>Fila</span><span>Código</span><span>Activo</span>")
         .Append("<span>Dónde</span><span>Resultado</span></div>");

        foreach (Fila f in filas)
        {
            s.Append("<div class=\"sg-carga-fila ").Append(f.valida ? "es-ok" : "es-mal").Append("\">")
             .Append("<span>").Append(f.numero).Append("</span>")
             .Append("<span>").Append(Server.HtmlEncode(f.codigo)).Append("</span>")
             .Append("<span>").Append(Server.HtmlEncode(f.nombre)).Append("</span>")
             .Append("<span>").Append(Server.HtmlEncode(f.planta))
             .Append(f.area.Length == 0 ? "" : " · " + Server.HtmlEncode(f.area)).Append("</span>")
             .Append("<span>")
             .Append(f.valida
                    ? "<span class=\"sg-ot-chip es-ok\">Lista para crear</span>"
                    : "<span class=\"sg-ot-chip es-rojo\">" + Server.HtmlEncode(string.Join(" · ", f.errores.ToArray())) + "</span>")
             .Append("</span></div>");
        }

        litPrevia.Text = s.Append("</div>").ToString();
    }

    protected void lnkCargar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR ACTIVOS"))
                throw new Exception("No tiene permiso para crear activos.");

            List<Fila> filas = Filas;
            List<Fila> validas = filas.Where(x => x.valida).ToList();

            if (validas.Count == 0)
                throw new Exception("No hay filas válidas para crear.");

            ActivoController ctl = new ActivoController();

            int creados = 0;
            List<string> fallaron = new List<string>();

            foreach (Fila f in validas)
            {
                /* Fila por fila y por el mismo camino que la ficha: las reglas
                   viven en el SP y no se duplican aca. Si una revienta, las
                   demas igual entran y el resumen dice cual quedo fuera. */
                Respuesta r = ctl.InsertActivo(f.activo);

                if (r.error) fallaron.Add("Fila " + f.numero + " (" + f.codigo + "): " + r.detalle);
                else creados++;
            }

            StringBuilder s = new StringBuilder();

            s.Append("<div class=\"sg-ot-avance\">")
             .Append("<div class=\"sg-ot-avance-num\"><strong>").Append(creados).Append("</strong><span>activos creados</span></div>")
             .Append("<div class=\"sg-ot-avance-num\"><strong>").Append(fallaron.Count).Append("</strong><span>no se pudieron crear</span></div>")
             .Append("</div>");

            if (fallaron.Count > 0)
            {
                s.Append("<div class=\"sg-carga-tabla\">");
                foreach (string x in fallaron)
                    s.Append("<div class=\"sg-carga-fila es-mal\"><span colspan=\"5\">")
                     .Append(Server.HtmlEncode(x)).Append("</span></div>");
                s.Append("</div>");
            }

            if (creados > 0)
                s.Append("<p class=\"sigma-modal-nota\"><i class=\"mdi mdi-information-outline\"></i>")
                 .Append("Cierre esta ventana para ver los activos nuevos en la lista.</p>");

            litResultado.Text = s.ToString();

            pnlResultado.Visible = true;
            pnlPrevia.Visible = false;
            udPanel.Update();

            Tools.tools.ClientAlert(creados + (creados == 1 ? " activo creado." : " activos creados."),
                                    fallaron.Count > 0 ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #endregion
}
