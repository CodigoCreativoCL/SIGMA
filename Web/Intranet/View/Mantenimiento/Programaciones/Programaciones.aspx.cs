using SitioBase;
// La implementación anterior se conserva como referencia del listado Telerik.
#if false
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de programaciones (HU-070 a HU-075, bloques 103-107).
///
/// EL CLIENTE SALE DE LA SESION, NUNCA DE LA PANTALLA
///   El controlador pasa Session.ClienteId() a SEL_PROGRAMACION y ese
///   parametro no es opcional. Los SPs de detalle lo vuelven a exigir, asi
///   que un id escrito a mano en la URL no alcanza para ver la programacion
///   de otra empresa.
///
/// ELIMINAR NO BORRA
///   Deshabilita. Es literalmente el criterio HU-076 #4: "deja de generar
///   ocurrencias nuevas Y las ya generadas se conservan". Un DELETE fisico
///   se llevaria por delante el historial del trabajo hecho.
///
/// LA COLUMNA "PROXIMA"
///   Sale de FNC_PROGRAMACION_FECHAS, que es un calculo y no una tabla. Se
///   pide UNA fecha por fila —no doce— porque el listado solo necesita saber
///   si la regla esta produciendo algo. Medidor y condicion no proyectan:
///   dependen de una lectura que todavia no ocurrio, y ahi la celda lo dice
///   en vez de quedar vacia como si estuviera rota.
/// </summary>
public partial class View_Mantenimiento_Programaciones_Programaciones : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("PRO_ID", "", Width: "3%");
            Grid.AddTemplateColumn("NOMBRE", "", "PROGRAMACIÓN", Width: "24%");
            Grid.AddTemplateColumn("REGLA", "", "REGLA", Width: "18%");

            /* Quién responde. Es lo primero que se busca cuando algo no se
               ejecutó, y hasta ahora había que abrir la ficha para saberlo. */
            Grid.AddTemplateColumn("RESPONSABLES", "", "RESPONSABLES", Width: "18%");

            Grid.AddTemplateColumn("VIGENCIA", "", "VIGENCIA", Width: "16%");
            Grid.AddTemplateColumn("FECHAS", "", "FECHAS PROGRAMADAS", Width: "17%");
            Grid.AddCheckboxColumn("PRO_HABILITADO", "HABILITADO");

            CargarCombos();
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* El boton se esconde a quien no puede, pero eso es cortesia, no
           seguridad: la potestad la valida el servidor en cada accion. */
        lnkNuevo.Visible = Token.PuedeFuncion("Crear y editar");
        lnkEliminar.Visible = Token.PuedeFuncion("Eliminar");

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    /// <summary>
    /// El combo de tipo se llena del catalogo y no se escribe en el markup:
    /// los seis valores viven en Programacion_Tipo y una lista fija en el
    /// .aspx queda vieja el dia que se agregue uno.
    /// </summary>
    protected void CargarCombos()
    {
        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");

        if (cboTipo == null) return;

        ProgramacionController controller = new ProgramacionController();
        List<CatalogoItem> tipos = controller.GetCatalogo("PROGRAMACION_TIPO");

        cboTipo.Items.Clear();
        cboTipo.Items.Add(new RadComboBoxItem("Todos", ""));

        if (tipos != null)
            foreach (CatalogoItem t in tipos)
                cboTipo.Items.Add(new RadComboBoxItem(t.nombre, t.id.ToString()));
    }

    protected void CargarGrid()
    {
        Programacion filtro = new Programacion();
        ProgramacionController controller = new ProgramacionController();

        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboTipo != null && !string.IsNullOrEmpty(cboTipo.SelectedValue))
        {
            int tipo;
            if (int.TryParse(cboTipo.SelectedValue, out tipo)) filtro.filtro_tipo = tipo;
        }

        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetProgramaciones(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        Programacion p = item.DataItem as Programacion;

        if (p == null) return;

        // ---- Enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.pro_id));

        HyperLink editar = new HyperLink();
        editar.ID = "lnkEditar" + item.ItemIndex;
        editar.CssClass = "icono_Editar";
        editar.NavigateUrl = "javascript:void(0)";
        editar.Attributes.Add("onclick", "abrirProgramacion('" + query + "')");

        item["PRO_ID"].Controls.Add(editar);

        // ---- Qué se programa ----
        string nombre = "<strong>" + Server.HtmlEncode(p.pro_nombre) + "</strong>";

        nombre += "<br /><span class=\"sg-tipo " + ClaseTipo(p.tipo_codigo) + "\">" +
                  Server.HtmlEncode(p.tipo_nombre) + "</span>";

        if (p.ocurrencias > 0)
            nombre += " <span style=\"color:#777;font-size:11px;\">" + p.ocurrencias +
                      (p.ocurrencias == 1 ? " ocurrencia" : " ocurrencias") + "</span>";

        item["NOMBRE"].Text = nombre;

        // ---- La regla, en una línea ----
        string regla = string.IsNullOrEmpty(p.detalle)
                     ? "<span style=\"color:#c0392b;\">sin definir</span>"
                     : Server.HtmlEncode(p.detalle);

        if (p.exclusiones > 0)
            regla += "<br /><span style=\"color:#777;font-size:11px;\">" + p.exclusiones +
                     (p.exclusiones == 1 ? " exclusión" : " exclusiones") + "</span>";

        item["REGLA"].Text = regla;

        // ---- Quién responde ----
        item["RESPONSABLES"].Text = Responsables(p);

        // ---- Desde cuándo hasta cuándo ----
        string vigencia = p.pro_fecha_inicio != null
                        ? p.pro_fecha_inicio.Value.ToString("dd-MM-yyyy") : "—";

        vigencia += p.pro_fecha_fin != null
                  ? " al " + p.pro_fecha_fin.Value.ToString("dd-MM-yyyy")
                  : " <span style=\"color:#777;\">en adelante</span>";

        if (!p.vigente)
            vigencia += "<br /><span class=\"grid-estado-chip is-alerta\">Fuera de vigencia</span>";

        item["VIGENCIA"].Text = vigencia;

        // ---- Las fechas programadas ----
        item["FECHAS"].Text = Fechas(p);
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se comprueba en el SERVIDOR, no confiando en que el botón
               estaba escondido: quien manda el postback a mano se lo salta. */
            if (!Token.PuedeFuncion("Eliminar"))
                throw new Exception("No tiene permiso para eliminar programaciones.");

            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            ProgramacionController controller = new ProgramacionController();

            List<string> fallidos = new List<string>();
            int borrados = 0;

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(indice)];

                int id = int.Parse(value["pro_id"].ToString());

                Respuesta respuesta = controller.DeleteProgramacion(id);

                if (respuesta.error) fallidos.Add(respuesta.detalle);
                else borrados++;
            }

            /* Se informa lo que pasó con CADA una. Mostrar solo el último
               resultado diría "eliminada con éxito" cuando se seleccionaron
               tres y dos fueron rechazadas. */
            if (fallidos.Count == 0)
            {
                Tools.tools.ClientAlert(
                    borrados == 1 ? "Programación eliminada con éxito."
                                  : borrados + " programaciones eliminadas con éxito.", "ok", true);
            }
            else
            {
                string detalle = (borrados > 0 ? borrados + " eliminada(s). " : "") +
                                 string.Join(" ", fallidos.ToArray());

                Tools.tools.ClientAlert(detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #region Tipo

    /// <summary>
    /// Un tono por tipo de programación.
    ///
    /// Los seis usaban el mismo azul, así que la pastilla decía "es un tipo"
    /// y nada más: había que leer la palabra completa en cada fila para
    /// distinguir un calendario de un intervalo.
    ///
    /// SON PARIENTES, NO SEMÁFOROS
    ///   Todos comparten la misma saturación baja y el mismo peso. Si uno
    ///   saliera rojo fuerte parecería un estado de error y no lo que es: una
    ///   categoría. La diferencia está en el matiz, no en la intensidad.
    ///
    /// EL COLOR NO ES LA ÚNICA PISTA
    ///   La pastilla lleva el nombre escrito. El color acelera el escaneo de
    ///   una lista larga; quien no lo distinga sigue leyendo exactamente lo
    ///   mismo que antes.
    /// </summary>
    private static string ClaseTipo(string codigo)
    {
        switch (codigo)
        {
            case "CALENDARIO":       return "is-calendario";
            case "INTERVALO TIEMPO": return "is-intervalo";
            case "FECHA UNICA":      return "is-fecha";
            case "MEDIDOR":          return "is-medidor";
            case "CONDICION":        return "is-condicion";
            case "ABIERTA":          return "is-abierta";
        }

        /* Un tipo nuevo que nadie mapeó sale en gris, no sin clase: sin
           fondo, la pastilla se ve como texto suelto y parece rota. */
        return "is-otro";
    }

    #endregion

    #region Fechas

    /// <summary>
    /// Las fechas que va a generar esta programación.
    ///
    /// EN LA CELDA VA LA PRÓXIMA; EL RESTO EN EL POPOVER
    ///   Una lista de doce fechas no cabe en una columna de tabla, y la
    ///   columna anterior mostraba solo la próxima: para ver el resto había
    ///   que abrir la ficha e irse a la última pestaña.
    ///
    /// LAS EXCLUIDAS TAMBIÉN
    ///   Van tachadas y con su motivo. Antes ni siquiera se devolvían: la
    ///   lista salía con días faltantes y nadie sabía si era la regla o una
    ///   exclusión. Ver "08-01 · excluida: Parada de planta" contesta la
    ///   pregunta sin salir de la fila.
    /// </summary>
    private string Fechas(Programacion p)
    {
        /* Medidor y condición no tienen fecha hasta que llegue la lectura.
           Decirlo es mejor que dejar la celda vacía, que se lee como rota. */
        if (p.tipo_codigo == "MEDIDOR" || p.tipo_codigo == "CONDICION")
            return "<span class=\"sg-fechas-nota\">Según medición</span>";

        if (!p.pro_habilitado)
            return "<span class=\"sg-fechas-nota\">—</span>";

        /* Se piden algunas de más porque las excluidas ahora ocupan lugar en
           el tope: con TOP 5 y una parada de planta de dos semanas, la lista
           podía salir entera de fechas tapadas y ninguna real. */
        List<ProgramacionProyeccion> fechas =
            new ProgramacionController().GetProyeccion(p.pro_id, 15);

        if (fechas == null || fechas.Count == 0)
            return "<span class=\"sg-fechas-nota is-alerta\">No produce fechas</span>";

        ProgramacionProyeccion proxima = null;
        int vigentes = 0, excluidas = 0;

        foreach (ProgramacionProyeccion f in fechas)
        {
            if (f.descartada) { excluidas++; continue; }

            vigentes++;
            if (proxima == null) proxima = f;
        }

        StringBuilder b = new StringBuilder();
        b.Append("<span class=\"sg-fechas\">");

        // ---- lo que se ve en la celda ----
        b.Append("<span class=\"sg-fechas-txt\">");

        if (proxima != null)
        {
            b.Append("<span class=\"sg-fechas-prox\">");
            b.Append(proxima.fecha.ToString("dd-MM-yyyy"));
            b.Append("</span>");

            StringBuilder pie = new StringBuilder();
            pie.Append(vigentes + (vigentes == 1 ? " fecha" : " fechas"));

            if (excluidas > 0)
                pie.Append("  ·  " + excluidas + (excluidas == 1 ? " excluida" : " excluidas"));

            b.Append("<span class=\"sg-fechas-pie\">" + pie + "</span>");
        }
        else
        {
            /* Todas tapadas por una exclusión: no es lo mismo que no producir
               fechas, y confundirlos manda a revisar la regla cuando el
               problema está en la parada de planta. */
            b.Append("<span class=\"sg-fechas-prox is-nula\">Sin fechas vigentes</span>");
            b.Append("<span class=\"sg-fechas-pie\">" + excluidas +
                     (excluidas == 1 ? " excluida" : " excluidas") + "</span>");
        }

        b.Append("</span>");

        // ---- el popover con la lista ----
        b.Append("<a class=\"sigma-inv-lupa sg-fechas-ver\" href=\"javascript:void(0)\" ");
        b.Append("onclick=\"sgMotivo(this)\" title=\"Ver las fechas\" ");
        b.Append("data-titulo=\"" + Server.HtmlEncode(p.pro_nombre) + "\" ");
        b.Append("data-motivo=\"" + Server.HtmlEncode(ListaDeFechas(fechas)) + "\">");
        b.Append("<i class=\"mdi mdi-calendar-month-outline\"></i></a>");

        b.Append("</span>");
        return b.ToString();
    }

    /// <summary>
    /// La lista para el popover, AGRUPADA POR MES.
    ///
    /// EL PROBLEMA QUE RESUELVE
    ///   Una fecha por línea daba quince líneas para quince fechas, cada una
    ///   repitiendo "08:00". Con una programación diaria son treinta líneas
    ///   al mes y el panel tapa media pantalla. Y lo que se repite no informa:
    ///   quien mira ya vio la hora en la primera.
    ///
    /// COMO QUEDA
    ///   Septiembre 2026 · 08:00
    ///   03, 08, 10, 15, 17, 22, 24, 29
    ///
    ///   Las mismas quince fechas en cuatro líneas, y de paso se ve el patrón
    ///   —cada dos días, los lunes— que en una columna vertical se pierde.
    ///
    /// LA HORA SE SACA SOLO SI ES LA MISMA
    ///   Si dentro del mes hay horas distintas va pegada a cada día. Colapsar
    ///   una hora que no todos comparten sería decir algo falso.
    ///
    /// SIGUE SIENDO TEXTO PLANO
    ///   El componente lo inserta con textContent, no con innerHTML, y el
    ///   motivo de una exclusión lo escribió una persona.
    /// </summary>
    private static string ListaDeFechas(List<ProgramacionProyeccion> fechas)
    {
        StringBuilder b = new StringBuilder();

        List<ProgramacionProyeccion> vigentes = new List<ProgramacionProyeccion>();
        List<ProgramacionProyeccion> excluidas = new List<ProgramacionProyeccion>();

        foreach (ProgramacionProyeccion f in fechas)
            (f.descartada ? excluidas : vigentes).Add(f);

        AgruparPorMes(b, vigentes);

        /* Las excluidas van al final y en su propio bloque: mezcladas con las
           vigentes obligan a leer cada línea para saber cuáles van a generar
           trabajo de verdad. */
        if (excluidas.Count > 0)
        {
            if (b.Length > 0) { b.Append((char)10); b.Append((char)10); }

            b.Append("NO SE GENERAN (" + excluidas.Count + ")");
            b.Append((char)10);

            AgruparPorMes(b, excluidas);

            /* El motivo se escribe UNA vez por exclusión, no por fecha: una
               parada de dos semanas repetiría "Parada de planta" diez veces. */
            List<string> motivos = new List<string>();

            foreach (ProgramacionProyeccion f in excluidas)
                if (!string.IsNullOrEmpty(f.motivo) && !motivos.Contains(f.motivo))
                    motivos.Add(f.motivo);

            foreach (string m in motivos)
            {
                b.Append((char)10);
                b.Append("Motivo: " + m);
            }
        }

        /* El asterisco se explica. Un simbolo sin leyenda obliga a adivinar,
           y "adivinar" en una lista de fechas de mantenimiento termina en una
           cuadrilla yendo el dia equivocado. */
        bool hayCorridas = false;

        foreach (ProgramacionProyeccion f in fechas)
            if (f.desplazada && !f.descartada) { hayCorridas = true; break; }

        if (hayCorridas)
        {
            b.Append((char)10);
            b.Append((char)10);
            b.Append("* corrida al siguiente hábil por una exclusión.");
        }

        return b.ToString();
    }

    private static readonly string[] MESES = {
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    };

    /// <summary>
    /// Escribe un encabezado por mes y los días en una sola línea.
    /// </summary>
    private static void AgruparPorMes(StringBuilder b, List<ProgramacionProyeccion> lista)
    {
        int mes = -1, anio = -1;
        StringBuilder dias = new StringBuilder();
        string horaDelMes = null;
        bool horaUniforme = true;

        for (int i = 0; i <= lista.Count; i++)
        {
            bool ultimo = (i == lista.Count);

            if (!ultimo && lista[i].fecha.Month == mes && lista[i].fecha.Year == anio)
            {
                AgregarDia(dias, lista[i], ref horaDelMes, ref horaUniforme);
                continue;
            }

            // ---- se cierra el mes anterior ----
            if (mes > 0 && dias.Length > 0)
            {
                if (b.Length > 0) b.Append((char)10);

                b.Append(MESES[mes - 1] + " " + anio);

                /* La hora en el encabezado solo si TODAS la comparten. */
                if (horaUniforme && horaDelMes != null) b.Append("  ·  " + horaDelMes);

                b.Append((char)10);
                b.Append(dias.ToString());
            }

            if (ultimo) break;

            mes = lista[i].fecha.Month;
            anio = lista[i].fecha.Year;
            dias = new StringBuilder();
            horaDelMes = null;
            horaUniforme = true;

            AgregarDia(dias, lista[i], ref horaDelMes, ref horaUniforme);
        }
    }

    /// <summary>Cuantos dias lleva escritos la linea del mes.</summary>
    private static int ContarDias(StringBuilder dias)
    {
        int n = 1;

        for (int i = 0; i < dias.Length; i++)
            if (dias[i] == ',') n++;

        return n;
    }

    private static void AgregarDia(StringBuilder dias, ProgramacionProyeccion f,
                                   ref string horaDelMes, ref bool horaUniforme)
    {
        string hora = f.fecha.TimeOfDay == TimeSpan.Zero ? "" : f.fecha.ToString("HH:mm");

        if (horaDelMes == null) horaDelMes = hora;
        else if (horaDelMes != hora) horaUniforme = false;

        if (dias.Length > 0) dias.Append(", ");

        /* Se corta cada diez. Una programacion diaria tiene treinta y un dias
           en el mes, y en una sola linea el panel se estira mas ancho que la
           pantalla. */
        if (dias.Length > 0 && ContarDias(dias) % 10 == 0)
        {
            dias.Length = dias.Length - 1;   // se quita el espacio de ", "
            dias.Append((char)10);
        }

        dias.Append(f.fecha.ToString("dd"));

        /* Una fecha corrida por un feriado se marca donde está, no en una
           nota aparte: lo que se quiere saber es cuál se movió. */
        if (f.desplazada) dias.Append("*");
    }

    #endregion

    #region Responsables

    /// <summary>
    /// Los mismos doce colores que usa la ficha. Tienen que ser LOS MISMOS:
    /// si una persona sale verde en el listado y naranja al abrir la ficha,
    /// el color deja de servir para reconocerla y pasa a confundir.
    /// </summary>
    private static readonly string[] PALETA = {
        "#6C5CFF", "#0EA5E9", "#10B981", "#F59E0B",
        "#EF4444", "#8B5CF6", "#EC4899", "#14B8A6",
        "#F97316", "#3B82F6", "#84CC16", "#A855F7"
    };

    /// <summary>
    /// El color sale del ID, no del nombre.
    ///
    /// Sumar los códigos de las letras es un hash malo: con los siete usuarios
    /// reales del cliente daba solo cuatro colores. El id es único por
    /// construcción y correlativo, así que un grupo de personas consecutivas
    /// sale con colores distintos garantizados.
    /// </summary>
    private static string ColorDe(int id)
    {
        if (id < 0) return PALETA[0];
        return PALETA[id % PALETA.Length];
    }

    private static string Iniciales(string nombre)
    {
        string[] partes = (nombre ?? "").Trim()
                          .Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);

        if (partes.Length == 0) return "?";
        if (partes.Length == 1) return partes[0].Substring(0, 1).ToUpper();

        return (partes[0].Substring(0, 1) + partes[1].Substring(0, 1)).ToUpper();
    }

    /// <summary>
    /// Quién responde: la cuadrilla, las personas, o que no hay nadie.
    ///
    /// AVATARES **Y** NOMBRES
    ///   Solo avatares obligaba a pasar el mouse por cada fila para saber de
    ///   quién se trataba. Van los dos: las caras arriba —que es lo que se
    ///   reconoce de un golpe— y los nombres debajo, recortados a una línea.
    ///
    /// "SIN ASIGNAR" NO VA EN ROJO
    ///   Estaba en rojo, y en una lista donde cuatro de cinco filas no tienen
    ///   responsable eso pinta la pantalla entera de alarma: deja de ser una
    ///   señal y pasa a ser ruido. Va como pastilla tenue con su icono, que se
    ///   distingue igual sin gritar.
    /// </summary>
    private string Responsables(Programacion p)
    {
        // ---- una cuadrilla ----
        if (!string.IsNullOrEmpty(p.GRUPO_NOMBRE))
            return "<span class=\"sg-resp\">" +
                   "<span class=\"sg-avatar is-grupo\" title=\"Grupo de trabajo\">" +
                   "<i class=\"mdi mdi-account-group\"></i></span>" +
                   "<span class=\"sg-resp-txt\"><span class=\"sg-resp-nombres\">" +
                   Server.HtmlEncode(p.GRUPO_NOMBRE) + "</span>" +
                   "<span class=\"sg-resp-pie\">Grupo de trabajo</span></span></span>";

        // ---- nadie ----
        if (string.IsNullOrEmpty(p.RESPONSABLES))
            return "<span class=\"sg-sinasignar\">" +
                   "<i class=\"mdi mdi-account-off-outline\"></i>Sin asignar</span>";

        string[] nombres = p.RESPONSABLES.Split(new string[] { ", " }, StringSplitOptions.None);
        string[] ids = (p.RESPONSABLES_IDS ?? "").Split(',');

        StringBuilder b = new StringBuilder();
        b.Append("<span class=\"sg-resp\">");

        /* Tres caras y el resto como "+N". Con ocho, la pila de avatares es
           más ancha que la columna. */
        int tope = nombres.Length > 3 ? 3 : nombres.Length;

        b.Append("<span class=\"sg-avatares\">");

        for (int k = 0; k < tope; k++)
        {
            int id;

            /* Nombres e ids vienen ordenados igual desde el SP, así que la
               posición empareja. Sin id utilizable el avatar sale gris en vez
               de reventar. */
            if (k >= ids.Length || !int.TryParse(ids[k].Trim(), out id)) id = -1;

            b.Append("<span class=\"sg-avatar\" style=\"background-color:" +
                     (id < 0 ? "#9ca3af" : ColorDe(id)) + ";\" title=\"" +
                     Server.HtmlEncode(nombres[k]) + "\">" +
                     Server.HtmlEncode(Iniciales(nombres[k])) + "</span>");
        }

        if (nombres.Length > tope)
            b.Append("<span class=\"sg-avatar is-mas\" title=\"" +
                     Server.HtmlEncode(p.RESPONSABLES) + "\">+" +
                     (nombres.Length - tope) + "</span>");

        b.Append("</span>");

        /* El texto: un nombre completo si es uno, o el primero y cuántos más.
           "Emilio Fuentes y 2 más" se lee; tres nombres completos en una
           columna de 18% no caben y se cortan a la mitad de una palabra. */
        string texto = nombres.Length == 1
            ? nombres[0]
            : nombres[0] + " y " + (nombres.Length - 1) +
              (nombres.Length - 1 == 1 ? " más" : " más");

        b.Append("<span class=\"sg-resp-txt\">");
        b.Append("<span class=\"sg-resp-nombres\" title=\"" +
                 Server.HtmlEncode(p.RESPONSABLES) + "\">" +
                 Server.HtmlEncode(texto) + "</span>");

        b.Append("<span class=\"sg-resp-pie\">" +
                 (nombres.Length == 1 ? "1 responsable" : nombres.Length + " responsables") +
                 "</span>");

        b.Append("</span></span>");

        return b.ToString();
    }

    #endregion
}
#endif

using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Web;
using System.Web.UI;

/// <summary>
/// Vista maestro-detalle de programaciones.
///
/// El listado se carga una vez y el navegador resuelve búsqueda, filtros,
/// orden y paginación. Las acciones que cambian datos siguen volviendo al
/// servidor: el permiso y la barrera por cliente no dependen del JavaScript.
///
/// Cada fila trae su proyección una sola vez. La próxima ejecución, el panel
/// lateral y el calendario ampliado reutilizan esa misma lista; abrir el
/// detalle no agrega consultas.
/// </summary>
public partial class View_Mantenimiento_Programaciones_Programaciones : System.Web.UI.Page
{
    private static readonly CultureInfo CULTURA = new CultureInfo("es-CL");


    protected void Page_Load(object sender, EventArgs e)
    {
        lnkNuevo.Visible = Token.PuedeFuncion("Crear y editar");
        lnkDuplicar.Visible = Token.PuedeFuncion("Crear y editar");
        lnkDeshabilitar.Visible = Token.PuedeFuncion("Eliminar");
        lnkDeshabilitarDetalle.Visible = Token.PuedeFuncion("Eliminar");
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarListado();
        udPanel.Update();
    }

    protected void CargarListado()
    {
        ProgramacionController controller = new ProgramacionController();
        List<Programacion> lista = controller.GetProgramaciones();

        if (lista == null) lista = new List<Programacion>();

        int habilitadas = 0;
        int sinResponsable = 0;
        int conExclusiones = 0;
        List<ProgramacionListadoFila> filas = new List<ProgramacionListadoFila>();

        foreach (Programacion p in lista)
        {
            if (p.pro_habilitado) habilitadas++;
            if (SinResponsable(p)) sinResponsable++;
            if (p.exclusiones > 0) conExclusiones++;

            List<ProgramacionProyeccion> fechas = new List<ProgramacionProyeccion>();

            if (p.pro_habilitado && p.tipo_codigo != "MEDIDOR" && p.tipo_codigo != "CONDICION")
            {
                fechas = controller.GetProyeccion(p.pro_id, 24);
                if (fechas == null) fechas = new List<ProgramacionProyeccion>();
            }

            filas.Add(CrearFila(p, fechas));
        }

        PintarConteos(lista.Count, habilitadas, sinResponsable, conExclusiones);

        rptProgramaciones.DataSource = filas;
        rptProgramaciones.DataBind();

        List<CatalogoItem> tipos = controller.GetCatalogo("PROGRAMACION_TIPO");
        rptTipos.DataSource = tipos ?? new List<CatalogoItem>();
        rptTipos.DataBind();
    }

    private void PintarConteos(int total, int habilitadas, int sinResponsable, int conExclusiones)
    {
        ltlTotal.Text = total.ToString();
        ltlHabilitadas.Text = habilitadas.ToString();
        ltlSinResponsable.Text = sinResponsable.ToString();
        ltlConExclusiones.Text = conExclusiones.ToString();

        ltlTabTotal.Text = total.ToString();
        ltlTabHabilitadas.Text = habilitadas.ToString();
        ltlTabSinResponsable.Text = sinResponsable.ToString();
        ltlTabConExclusiones.Text = conExclusiones.ToString();
    }

    private ProgramacionListadoFila CrearFila(Programacion p, List<ProgramacionProyeccion> fechas)
    {
        ProgramacionProyeccion proxima = PrimeraVigente(fechas);

        ProgramacionListadoFila fila = new ProgramacionListadoFila();
        fila.id = p.pro_id;
        fila.query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.pro_id));
        fila.nombre = p.pro_nombre;
        fila.nombre_orden = (p.pro_nombre ?? "").ToLowerInvariant();
        fila.tipo_codigo = p.tipo_codigo;
        fila.tipo_nombre = p.tipo_nombre;
        fila.tipo_clase = ClaseTipoListado(p.tipo_codigo);
        fila.habilitada_valor = p.pro_habilitado ? "1" : "0";
        fila.asignada_valor = SinResponsable(p) ? "0" : "1";
        fila.exclusiones = p.exclusiones;
        fila.proxima_orden = proxima != null ? proxima.fecha.ToString("yyyyMMddHHmmss") : "99999999999999";
        fila.vigencia_orden = p.pro_fecha_inicio != null ? p.pro_fecha_inicio.Value.ToString("yyyyMMdd") : "99999999";
        fila.seleccionar_texto = "Seleccionar " + p.pro_nombre;
        fila.acciones_texto = "Acciones de " + p.pro_nombre;
        fila.regla_html = ReglaHtml(p, proxima);
        fila.proxima_html = ProximaHtml(p, proxima, fechas);
        fila.responsables_html = ResponsablesListadoHtml(p);
        fila.vigencia_html = VigenciaHtml(p);
        fila.estado_html = EstadoHtml(p);
        fila.detalle_html = DetalleHtml(p, fechas, proxima);
        fila.calendario_html = CalendarioHtml(p, fechas);

        return fila;
    }

    #region Acciones

    protected void lnkRecargar_Click(object sender, EventArgs e)
    {
        hfSeleccionadas.Value = "";
        hfAccionId.Value = "";
    }

    protected void lnkDeshabilitar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.PuedeFuncion("Eliminar"))
                throw new Exception("No tiene permiso para deshabilitar programaciones.");

            List<int> ids = LeerIds(hfSeleccionadas.Value);
            if (ids.Count == 0) throw new Exception("Seleccione al menos una programación.");

            Deshabilitar(ids);
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void lnkDeshabilitarDetalle_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.PuedeFuncion("Eliminar"))
                throw new Exception("No tiene permiso para deshabilitar programaciones.");

            int id;
            if (!int.TryParse(hfAccionId.Value, out id) || id <= 0)
                throw new Exception("Seleccione una programación.");

            Deshabilitar(new List<int> { id });
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    private void Deshabilitar(List<int> ids)
    {
        ProgramacionController controller = new ProgramacionController();
        List<string> fallidos = new List<string>();
        int deshabilitadas = 0;

        foreach (int id in ids)
        {
            Respuesta respuesta = controller.DeleteProgramacion(id);
            if (respuesta.error) fallidos.Add(respuesta.detalle);
            else deshabilitadas++;
        }

        hfSeleccionadas.Value = "";
        hfAccionId.Value = "";

        if (fallidos.Count == 0)
        {
            string mensaje = deshabilitadas == 1
                ? "Programación deshabilitada con éxito."
                : deshabilitadas + " programaciones deshabilitadas con éxito.";

            Tools.tools.ClientAlert(mensaje, "ok");
            return;
        }

        string detalle = (deshabilitadas > 0 ? deshabilitadas + " deshabilitada(s). " : "") +
                         string.Join(" ", fallidos.ToArray());
        Tools.tools.ClientAlert(detalle, "alerta");
    }

    protected void lnkDuplicar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.PuedeFuncion("Crear y editar"))
                throw new Exception("No tiene permiso para duplicar programaciones.");

            int id;
            if (!int.TryParse(hfAccionId.Value, out id) || id <= 0)
                throw new Exception("Seleccione una programación.");

            ProgramacionController controller = new ProgramacionController();
            Respuesta respuesta = controller.DuplicarProgramacion(id);

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
            hfAccionId.Value = "";
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    private static List<int> LeerIds(string csv)
    {
        List<int> ids = new List<int>();
        string[] partes = (csv ?? "").Split(',');

        foreach (string parte in partes)
        {
            int id;
            if (int.TryParse(parte, out id) && id > 0 && !ids.Contains(id)) ids.Add(id);
        }

        return ids;
    }

    #endregion
}

public partial class View_Mantenimiento_Programaciones_Programaciones
{
    #region Celdas

    private string ReglaHtml(Programacion p, ProgramacionProyeccion proxima)
    {
        string regla = string.IsNullOrEmpty(p.detalle)
            ? "<span class=\"sgp-muted is-alert\">Sin definir</span>"
            : "<span class=\"sgp-rule-main\">" + Html(p.detalle) + HoraCompacta(proxima, " · ") + "</span>";

        if (p.exclusiones > 0)
            regla += "<span class=\"sgp-rule-note\"><i class=\"mdi mdi-alert-circle\"></i>" +
                     p.exclusiones + (p.exclusiones == 1 ? " exclusión" : " exclusiones") + "</span>";

        return regla;
    }

    private string ProximaHtml(Programacion p, ProgramacionProyeccion proxima,
                               List<ProgramacionProyeccion> fechas)
    {
        if (!p.pro_habilitado) return "<span class=\"sgp-muted\">—</span>";

        if (p.tipo_codigo == "MEDIDOR" || p.tipo_codigo == "CONDICION")
            return "<span class=\"sgp-muted\">Según medición</span>";

        if (proxima == null)
        {
            int excluidas = ContarDescartadas(fechas);
            return excluidas > 0
                ? "<span class=\"sgp-muted is-alert\">Sin fechas vigentes</span>"
                : "<span class=\"sgp-muted is-alert\">No produce fechas</span>";
        }

        return "<span class=\"sgp-next\">" + FechaHora(proxima.fecha) + "</span>" +
               (proxima.desplazada
                    ? "<span class=\"sgp-rule-note\"><i class=\"mdi mdi-arrow-right\"></i>Movida al siguiente hábil</span>"
                    : "");
    }

    private string VigenciaHtml(Programacion p)
    {
        if (p.pro_fecha_inicio == null) return "<span class=\"sgp-muted\">Sin definir</span>";

        string texto = "Desde " + FechaCorta(p.pro_fecha_inicio.Value);

        if (p.pro_fecha_fin != null)
            texto += "<span class=\"sgp-subline\">Hasta " + FechaCorta(p.pro_fecha_fin.Value) + "</span>";

        if (!p.vigente)
            texto += "<span class=\"sgp-rule-note is-alert\">Fuera de vigencia</span>";

        return "<span class=\"sgp-validity\">" + texto + "</span>";
    }

    private static string EstadoHtml(Programacion p)
    {
        return p.pro_habilitado
            ? "<span class=\"sgp-status is-enabled\">Habilitada</span>"
            : "<span class=\"sgp-status is-disabled\">Deshabilitada</span>";
    }

    #endregion

    #region Panel lateral

    private string DetalleHtml(Programacion p, List<ProgramacionProyeccion> fechas,
                               ProgramacionProyeccion proxima)
    {
        StringBuilder b = new StringBuilder();

        b.Append("<div class=\"sgp-drawer-badges\">");
        b.Append("<span class=\"sg-tipo " + ClaseTipoListado(p.tipo_codigo) + "\">" + Html(p.tipo_nombre) + "</span>");
        b.Append(EstadoHtml(p));
        b.Append("</div>");
        b.Append("<h2>" + Html(p.pro_nombre) + "</h2>");
        b.Append("<div class=\"sgp-drawer-id\">ID de programación <strong>" + p.pro_id + "</strong>");
        b.Append("<button type=\"button\" data-sgp-copy=\"" + p.pro_id + "\" aria-label=\"Copiar ID\">");
        b.Append("<i class=\"mdi mdi-content-copy\"></i></button></div>");
        b.Append("<div class=\"sgp-drawer-rule\"><i class=\"mdi mdi-sync\"></i><strong>");
        b.Append(Html(ReglaDetalle(p, proxima)));
        b.Append("</strong></div>");

        b.Append("<div class=\"sgp-drawer-facts\">");
        b.Append(DetalleDato("mdi-calendar-month-outline", "Próxima ejecución",
                             proxima != null ? FechaHora(proxima.fecha) : ProximaVacia(p, fechas)));
        b.Append(DetalleAsignacion(p));
        b.Append(DetalleDato("mdi-calendar-range-outline", "Vigencia", VigenciaTexto(p)));
        b.Append(DetalleDato("mdi-alert-circle-outline", "Exclusiones",
                             p.exclusiones == 0 ? "Ninguna" : p.exclusiones +
                             (p.exclusiones == 1 ? " configurada" : " configuradas")));
        b.Append(DetalleDato("mdi-lightning-bolt-outline", "Estado de generación",
                             p.pro_genera_automaticamente ? "Generación automática" : "Generación manual"));
        b.Append("</div>");

        b.Append("<section class=\"sgp-upcoming\"><h3>Próximas ejecuciones</h3>");

        int agregadas = 0;
        foreach (ProgramacionProyeccion fecha in fechas)
        {
            if (fecha.descartada) continue;

            b.Append("<div class=\"sgp-upcoming-row\"><i class=\"mdi mdi-calendar-blank-outline\"></i>");
            b.Append("<span>" + FechaHora(fecha.fecha) + "</span>");

            if (fecha.desplazada)
                b.Append("<em title=\"" + Atributo(fecha.motivo) + "\">movida</em>");

            b.Append("</div>");
            agregadas++;
            if (agregadas == 3) break;
        }

        if (agregadas == 0)
            b.Append("<p class=\"sgp-upcoming-empty\">" + Html(ProximaVacia(p, fechas)) + "</p>");

        if (fechas.Count > 0)
            b.Append("<button type=\"button\" class=\"sgp-calendar-link\" data-sgp-action=\"calendar\">" +
                     "Ver calendario completo <i class=\"mdi mdi-open-in-new\"></i></button>");

        b.Append("</section>");
        return b.ToString();
    }

    private string DetalleAsignacion(Programacion p)
    {
        return "<div class=\"sgp-drawer-fact is-assignment\"><i class=\"mdi mdi-account-multiple-outline\"></i>" +
               "<div><span>Responsables</span>" + ResponsablesListadoHtml(p) + "</div></div>";
    }

    private string DetalleDato(string icono, string rotulo, string valor)
    {
        return "<div class=\"sgp-drawer-fact\"><i class=\"mdi " + icono + "\"></i><div>" +
               "<span>" + Html(rotulo) + "</span><strong>" + Html(valor) + "</strong></div></div>";
    }

    private static string ProximaVacia(Programacion p, List<ProgramacionProyeccion> fechas)
    {
        if (!p.pro_habilitado) return "Programación deshabilitada";
        if (p.tipo_codigo == "MEDIDOR" || p.tipo_codigo == "CONDICION") return "Depende de una medición";
        if (ContarDescartadas(fechas) > 0) return "Todas las fechas proyectadas están excluidas";
        return "La regla no produce fechas próximas";
    }

    #endregion

    #region Calendario proyectado

    private string CalendarioHtml(Programacion p, List<ProgramacionProyeccion> fechas)
    {
        StringBuilder b = new StringBuilder();
        b.Append("<div class=\"sgp-calendar-summary\"><strong>" + Html(p.pro_nombre) + "</strong>");

        if (fechas.Count == 0)
        {
            b.Append("<p>" + Html(ProximaVacia(p, fechas)) + ".</p></div>");
            return b.ToString();
        }

        int vigentes = 0;
        int excluidas = 0;
        bool hayMovidas = false;

        foreach (ProgramacionProyeccion f in fechas)
        {
            if (f.descartada) excluidas++;
            else vigentes++;
            if (f.desplazada && !f.descartada) hayMovidas = true;
        }

        b.Append("<p>" + vigentes + (vigentes == 1 ? " fecha vigente" : " fechas vigentes"));
        if (excluidas > 0) b.Append(" · " + excluidas + (excluidas == 1 ? " excluida" : " excluidas"));
        b.Append("</p><div class=\"sgp-calendar-legend\">");
        b.Append("<span><i class=\"is-active\"></i>Se genera</span>");
        if (excluidas > 0) b.Append("<span><i class=\"is-excluded\"></i>No se genera</span>");
        if (hayMovidas) b.Append("<span><i class=\"is-moved\"></i>Movida al siguiente hábil</span>");
        b.Append("</div></div>");

        int indice = 0;
        while (indice < fechas.Count)
        {
            int mes = fechas[indice].fecha.Month;
            int anio = fechas[indice].fecha.Year;
            int fin = indice;

            while (fin < fechas.Count && fechas[fin].fecha.Month == mes && fechas[fin].fecha.Year == anio) fin++;

            string horaComun = HoraComun(fechas, indice, fin);
            string nombreMes = CULTURA.TextInfo.ToTitleCase(CULTURA.DateTimeFormat.GetMonthName(mes));

            b.Append("<section class=\"sgp-calendar-month\"><header><div><strong>" + nombreMes + " " + anio + "</strong>");
            if (!string.IsNullOrEmpty(horaComun)) b.Append("<span>" + horaComun + "</span>");
            b.Append("</div><em>" + (fin - indice) + ((fin - indice) == 1 ? " fecha" : " fechas") + "</em></header>");
            b.Append("<div class=\"sgp-calendar-days\">");

            for (int i = indice; i < fin; i++) b.Append(DiaCalendario(fechas[i], horaComun));

            b.Append("</div></section>");
            indice = fin;
        }

        b.Append(MotivosHtml(fechas));

        if (fechas.Count == 24)
            b.Append("<p class=\"sgp-calendar-limit\"><i class=\"mdi mdi-information-outline\"></i>" +
                     "Se muestran las próximas 24 fechas calculadas.</p>");

        return b.ToString();
    }

    private string DiaCalendario(ProgramacionProyeccion f, string horaComun)
    {
        string clase = f.descartada ? " is-excluded" : (f.desplazada ? " is-moved" : "");
        string titulo = f.descartada
            ? "No se genera" + (string.IsNullOrEmpty(f.motivo) ? "" : ": " + f.motivo)
            : (f.desplazada ? "Movida al siguiente hábil" : "Se genera");

        StringBuilder b = new StringBuilder();
        b.Append("<span class=\"sgp-calendar-day" + clase + "\" title=\"" + Atributo(titulo) + "\">");
        b.Append("<small>" + DiaSemana(f.fecha) + "</small><strong>" + f.fecha.ToString("dd") + "</strong>");

        if (string.IsNullOrEmpty(horaComun) && f.fecha.TimeOfDay != TimeSpan.Zero)
            b.Append("<span>" + f.fecha.ToString("HH:mm") + "</span>");

        if (f.desplazada && !f.descartada) b.Append("<i class=\"mdi mdi-arrow-right\"></i>");
        if (f.descartada) b.Append("<i class=\"mdi mdi-close\"></i>");

        b.Append("</span>");
        return b.ToString();
    }

    private string MotivosHtml(List<ProgramacionProyeccion> fechas)
    {
        List<string> motivos = new List<string>();
        List<List<DateTime>> dias = new List<List<DateTime>>();

        foreach (ProgramacionProyeccion f in fechas)
        {
            if (!f.descartada) continue;

            string motivo = string.IsNullOrEmpty(f.motivo) ? "Exclusión configurada" : f.motivo;
            int pos = motivos.IndexOf(motivo);

            if (pos < 0)
            {
                motivos.Add(motivo);
                dias.Add(new List<DateTime>());
                pos = motivos.Count - 1;
            }

            dias[pos].Add(f.fecha);
        }

        if (motivos.Count == 0) return "";

        StringBuilder b = new StringBuilder();
        b.Append("<section class=\"sgp-calendar-reasons\"><h3>Fechas que no generan trabajo</h3>");

        for (int i = 0; i < motivos.Count; i++)
        {
            List<string> textos = new List<string>();
            foreach (DateTime fecha in dias[i]) textos.Add(FechaCorta(fecha));

            b.Append("<div><i class=\"mdi mdi-calendar-remove-outline\"></i><p><strong>" +
                     Html(motivos[i]) + "</strong><span>" + Html(string.Join(", ", textos.ToArray())) +
                     "</span></p></div>");
        }

        b.Append("</section>");
        return b.ToString();
    }

    private static string HoraComun(List<ProgramacionProyeccion> fechas, int desde, int hasta)
    {
        if (desde >= hasta) return "";

        TimeSpan hora = fechas[desde].fecha.TimeOfDay;
        for (int i = desde + 1; i < hasta; i++)
            if (fechas[i].fecha.TimeOfDay != hora) return "";

        return hora == TimeSpan.Zero ? "" : fechas[desde].fecha.ToString("HH:mm");
    }

    #endregion
}

public partial class View_Mantenimiento_Programaciones_Programaciones
{
    #region Responsables

    /* Las caras las dibuja `SitioBase.Avatar`, que es el mismo codigo que usan
       el resto de las pantallas. Estaba resuelto aca adentro, con su propia
       paleta y sus propias iniciales: una copia mas de lo mismo, y una copia
       se desincroniza. Si el color de una persona cambia segun la pantalla,
       deja de servir para reconocerla. */
    private string ResponsablesListadoHtml(Programacion p)
    {
        if (!string.IsNullOrEmpty(p.GRUPO_NOMBRE))
            return SitioBase.Avatar.CeldaGrupo(p.GRUPO_NOMBRE);

        if (string.IsNullOrEmpty(p.RESPONSABLES))
            return SitioBase.Avatar.SinAsignar("Sin responsable");

        return SitioBase.Avatar.Celda(p.RESPONSABLES, p.RESPONSABLES_IDS, "", 3);
    }

    private static bool SinResponsable(Programacion p)
    {
        return string.IsNullOrEmpty(p.RESPONSABLES) && string.IsNullOrEmpty(p.GRUPO_NOMBRE);
    }

    #endregion

    #region Formato

    public string Html(object valor)
    {
        return Server.HtmlEncode(valor == null ? "" : valor.ToString());
    }

    public string Atributo(object valor)
    {
        return HttpUtility.HtmlAttributeEncode(valor == null ? "" : valor.ToString());
    }

    private static string ClaseTipoListado(string codigo)
    {
        switch (codigo)
        {
            case "CALENDARIO":       return "is-calendario";
            case "INTERVALO TIEMPO": return "is-intervalo";
            case "FECHA UNICA":      return "is-fecha";
            case "MEDIDOR":          return "is-medidor";
            case "CONDICION":        return "is-condicion";
            case "ABIERTA":          return "is-abierta";
            default:                  return "is-otro";
        }
    }

    private static ProgramacionProyeccion PrimeraVigente(List<ProgramacionProyeccion> fechas)
    {
        foreach (ProgramacionProyeccion fecha in fechas)
            if (!fecha.descartada) return fecha;

        return null;
    }

    private static int ContarDescartadas(List<ProgramacionProyeccion> fechas)
    {
        int total = 0;
        foreach (ProgramacionProyeccion fecha in fechas) if (fecha.descartada) total++;
        return total;
    }

    private static string FechaCorta(DateTime fecha)
    {
        return fecha.ToString("dd MMM yyyy", CULTURA).Replace(".", "");
    }

    private static string FechaHora(DateTime fecha)
    {
        string texto = FechaCorta(fecha);
        if (fecha.TimeOfDay != TimeSpan.Zero) texto += " · " + fecha.ToString("HH:mm");
        return texto;
    }

    private static string DiaSemana(DateTime fecha)
    {
        string dia = CULTURA.DateTimeFormat.GetAbbreviatedDayName(fecha.DayOfWeek).Replace(".", "");
        return CULTURA.TextInfo.ToTitleCase(dia);
    }

    private static string HoraCompacta(ProgramacionProyeccion fecha, string separador)
    {
        return fecha != null && fecha.fecha.TimeOfDay != TimeSpan.Zero
            ? separador + fecha.fecha.ToString("HH:mm")
            : "";
    }

    private static string ReglaDetalle(Programacion p, ProgramacionProyeccion proxima)
    {
        string regla = string.IsNullOrEmpty(p.detalle) ? "Regla sin definir" : p.detalle;

        if (proxima != null && proxima.fecha.TimeOfDay != TimeSpan.Zero)
            regla += " a las " + proxima.fecha.ToString("HH:mm");

        return regla;
    }

    private static string VigenciaTexto(Programacion p)
    {
        if (p.pro_fecha_inicio == null) return "Sin definir";

        string texto = "Desde " + FechaCorta(p.pro_fecha_inicio.Value);
        texto += p.pro_fecha_fin == null ? " · Sin término" : " · Hasta " + FechaCorta(p.pro_fecha_fin.Value);
        return texto;
    }

    #endregion
}

[Serializable]
public class ProgramacionListadoFila
{
    public int id { get; set; }
    public string query { get; set; }
    public string nombre { get; set; }
    public string nombre_orden { get; set; }
    public string tipo_codigo { get; set; }
    public string tipo_nombre { get; set; }
    public string tipo_clase { get; set; }
    public string habilitada_valor { get; set; }
    public string asignada_valor { get; set; }
    public int exclusiones { get; set; }
    public string proxima_orden { get; set; }
    public string vigencia_orden { get; set; }
    public string seleccionar_texto { get; set; }
    public string acciones_texto { get; set; }
    public string regla_html { get; set; }
    public string proxima_html { get; set; }
    public string responsables_html { get; set; }
    public string vigencia_html { get; set; }
    public string estado_html { get; set; }
    public string detalle_html { get; set; }
    public string calendario_html { get; set; }
}
