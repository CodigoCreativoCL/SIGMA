using SitioBase;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// SIGMA AI · Experimentos (Investigación Azure Machine Learning, bloque 245).
///
/// UN CUADERNO DE LABORATORIO, NO UN MANTENEDOR
///   La pantalla recorre en orden los cinco pasos de la investigación —
///   dataset, entrenamiento, publicación, puntuación, Azure ML— y muestra
///   debajo de cada uno lo que produjo. Nada de acá toca la base directo:
///   todo pasa por la API (`/sigma-ai/*`) a través de `Services`, que
///   presenta a la persona en sesión con la clave de servicio. Es a
///   propósito: la app móvil va a usar los mismos endpoints, y si la web
///   tuviera un camino propio los dos se separarían con el tiempo.
///
/// EL ACCESO LO RESUELVE EL MASTER
///   Ver es VER PREDICCIONES (la página cuelga de ese permiso en Menus);
///   registrar, publicar y puntuar es la función «Entrenar y publicar»
///   (ENTRENAR MODELOS). La API vuelve a comprobarlo: la pantalla esconde
///   botones, el servidor decide.
/// </summary>
public partial class View_SigmaAI_Experimentos : System.Web.UI.Page
{
    private static readonly CultureInfo CL = CultureInfo.GetCultureInfo("es-CL");

    private bool PuedeEntrenar
    {
        get { return Token.PuedeFuncion("Entrenar y publicar"); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!Services.Disponible)
        {
            litAviso.Text = "<div class='sg-ml-aviso is-mal'><i class='mdi mdi-alert-circle-outline'></i> " +
                            HttpUtility.HtmlEncode(Services.Motivo) + "</div>";
            return;
        }

        bool puede = PuedeEntrenar;
        btnRegistrar.Visible = puede;
        btnPredecir.Visible = puede;

        if (!IsPostBack) Cargar();
    }

    /* ====================================================================
       LO QUE SE PINTA SIEMPRE
       ==================================================================== */

    private void Cargar()
    {
        try
        {
            Dictionary<string, object> estado = Services.GetJson("/sigma-ai/estado");
            Dictionary<string, object> modelo = estado["modelo"] as Dictionary<string, object>;
            Dictionary<string, object> azure = estado["azure"] as Dictionary<string, object>;

            PintarKpis(modelo, azure);
            PintarPlan(modelo, azure);
            PintarComando(modelo);
            PintarDatasets();
            PintarCorridas();
            PintarVersiones();
            PintarVigentes();
        }
        catch (Exception ex)
        {
            litAviso.Text = "<div class='sg-ml-aviso is-mal'><i class='mdi mdi-alert-circle-outline'></i> No se pudo leer el estado de SIGMA AI: " +
                            HttpUtility.HtmlEncode(ex.Message) + "</div>";
        }
    }

    private void PintarKpis(Dictionary<string, object> m, Dictionary<string, object> azure)
    {
        if (m == null) { litKpis.Text = ""; return; }

        bool hayVersion = m["VERSION_ID"] != null;
        bool azureOk = azure != null && Convert.ToBoolean(azure["configurado"]);

        StringBuilder sb = new StringBuilder();
        sb.Append(Kpi("mdi-rocket-launch-outline", hayVersion ? "v" + m["VERSION_NUMERO"] : "—", "Versión publicada",
                      hayVersion ? "AUC " + Num(m["VERSION_AUC"], "0.000") + " · " + T(m["VERSION_ALGORITMO"]) : "Nada publicado aún"));
        sb.Append(Kpi("mdi-database-outline", T(m["DATASETS"]), "Datasets registrados",
                      T(m["ACTIVOS"]) + " equipos · " + T(m["FALLAS"]) + " fallas · " + T(m["MEDICIONES"]) + " mediciones"));
        sb.Append(Kpi("mdi-school-outline", T(m["CORRIDAS"]), "Corridas de entrenamiento", T(m["VERSIONES"]) + " versiones en total"));
        sb.Append(Kpi("mdi-brain", T(m["PREDICCIONES_VIGENTES"]), "Predicciones vigentes", "de " + T(m["mpr_codigo"])));
        sb.Append(Kpi("mdi-microsoft-azure", azureOk ? "OK" : "—", "Azure ML",
                      azureOk ? T(azure["workspace"]) + " · " + T(azure["region"]) : "Sin credenciales en la API"));
        litKpis.Text = sb.ToString();
    }

    private static string Kpi(string icono, string cifra, string titulo, string pie)
    {
        return "<div class='sg-kpi'><div class='sg-kpi-fila'><span class='sg-kpi-icono'><i class='mdi " + icono + "'></i></span>" +
               "<div class='sg-kpi-texto'><span style='font-size:22px;font-weight:800;color:#141c2e;line-height:1.1'>" + HttpUtility.HtmlEncode(cifra) + "</span>" +
               "<span style='font-size:10.5px;font-weight:800;letter-spacing:.05em;text-transform:uppercase;color:#64708a'>" + HttpUtility.HtmlEncode(titulo) + "</span></div></div>" +
               "<div class='sg-kpi-pie' style='font-size:11.5px;color:#4e5b72'>" + HttpUtility.HtmlEncode(pie) + "</div></div>";
    }

    /// <summary>
    /// El plan con su estado real: lo hecho sale de los contadores del
    /// modelo, lo que le toca a la persona en el portal de Azure se marca
    /// aparte porque la web no puede saberlo hasta que la API tenga claves.
    /// </summary>
    private void PintarPlan(Dictionary<string, object> m, Dictionary<string, object> azure)
    {
        bool hayDataset = m != null && Convert.ToInt32(m["DATASETS"]) > 0;
        bool hayCorrida = m != null && Convert.ToInt32(m["CORRIDAS"]) > 0;
        bool hayVersion = m != null && Convert.ToInt32(m["VERSIONES"]) > 0;
        bool hayPublicada = m != null && m["VERSION_ID"] != null;
        bool hayPred = m != null && Convert.ToInt32(m["PREDICCIONES_VIGENTES"]) > 0;
        bool azureOk = azure != null && Convert.ToBoolean(azure["configurado"]);

        StringBuilder sb = new StringBuilder();
        sb.Append(Paso(true, "Base de datos (bloque 245): modelo <strong>SIGMA FAILURE 30D</strong>, 15 características, función de dataset sin fuga, SP de registro y puntuación, menú y permiso."));
        sb.Append(Paso(true, "API: <code>/sigma-ai/*</code> (estado, dataset, datasets, entrenamientos, versiones, predecir, simular, azure) y el puntuador en C#."));
        sb.Append(Paso(hayDataset, "Paso 1 · Registrar un dataset desde esta pantalla (o <code>POST /sigma-ai/datasets</code>)."));
        sb.Append(PasoPersona("Instalar en tu computador: <code>pip install scikit-learn pandas requests mlflow azureml-mlflow skl2onnx onnxruntime</code>."));
        sb.Append(PasoPersona("En el portal de Azure (una sola vez, sin costo): <strong>Entra ID › Registros de aplicaciones › Nuevo</strong> «sigma-api-ml» → anotar <em>Id. de aplicación</em> e <em>Id. de inquilino</em> → <em>Certificados y secretos</em> → nuevo secreto. Luego en el área de trabajo <strong>SIGMA_AI › Control de acceso (IAM) › Agregar asignación de roles › AzureML Data Scientist</strong> a esa aplicación. No crear instancias ni clústeres de cómputo."));
        sb.Append(PasoPersona("Poner esas claves en <code>API/Web.config</code> (<code>AzureML.TenantId</code>, <code>ClientId</code>, <code>ClientSecret</code>, <code>SubscriptionId</code>); nunca por chat ni correo. Región, grupo y área ya vienen puestos."));
        sb.Append(Paso(hayCorrida, "Paso 2 · Correr <code>ML/entrenar_falla.py</code> con el id del dataset: entrena, valida, exporta ONNX, registra en Azure ML e informa a la API."));
        sb.Append(Paso(hayPublicada, "Paso 3 · Publicar la versión (esta pantalla)." + (hayVersion && !hayPublicada ? " <em>Hay una versión en borrador esperando.</em>" : "")));
        sb.Append(Paso(hayPred, "Paso 4 · Puntuar los equipos de hoy y revisar las predicciones, sus razones y las alertas que generaron."));
        sb.Append(Paso(azureOk, "Paso 5 · Contrastar con Azure ML: el modelo registrado y la corrida deben ser los mismos que informa la versión (mismo hash, misma ruta)."));
        sb.Append(PasoPersona("Cerrar la investigación en <code>MD/SIGMA_INVESTIGACION_AZURE_ML.md</code>: qué se probó, qué dio, qué falta para SIGMA RUL y SIGMA VISION."));
        litPlan.Text = sb.ToString();
    }

    private static string Paso(bool listo, string html)
    {
        return "<li><i class='mdi " + (listo ? "mdi-check-circle is-listo" : "mdi-circle-outline is-pend") + "'></i><span>" + html + "</span></li>";
    }

    private static string PasoPersona(string html)
    {
        return "<li><i class='mdi mdi-account-arrow-right-outline is-bryan' title='Lo hace quien administra la suscripción'></i><span>" + html + "</span></li>";
    }

    private void PintarComando(Dictionary<string, object> m)
    {
        string url = Services.Url();
        StringBuilder sb = new StringBuilder();
        sb.Append("<span class='sg-ml-cmd'>");
        sb.Append("cd C:\\Capstone\\SIGMA\\ML\n");
        sb.Append("set SIGMA_API=" + HttpUtility.HtmlEncode(url) + "\n");
        sb.Append("set MLFLOW_TRACKING_URI=azureml://eastus2.api.azureml.ms/mlflow/v1.0/subscriptions/&lt;suscripción&gt;/resourceGroups/SIGMA/providers/Microsoft.MachineLearningServices/workspaces/SIGMA_AI\n");
        sb.Append("python entrenar_falla.py --usuario &lt;tu login&gt; --dataset &lt;id&gt;      (pide la contraseña; --sin-azure para no registrar; --demo para un dataset sintético)");
        sb.Append("</span>");
        litComando.Text = sb.ToString();
    }

    /* ====================================================================
       PASO 1 · DATASET
       ==================================================================== */

    protected void btnMuestra_Click(object sender, EventArgs e)
    {
        try
        {
            Dictionary<string, object> r = Services.GetJson("/sigma-ai/dataset?" + Rango() + "&formato=json");
            object[] datos = Lista(r["datos"]);

            StringBuilder sb = new StringBuilder();
            sb.Append("<div class='sg-ml-aviso is-ok'><strong>" + T(r["filas"]) + " filas</strong> (equipo × corte) · " +
                      T(r["etiquetadas"]) + " con label observable · <strong>" + T(r["positivas"]) + " positivas</strong> (falla en los 30 días siguientes). " +
                      "Se muestran las últimas 15.</div>");

            if (datos != null && datos.Length > 0)
            {
                Dictionary<string, object> primera = (Dictionary<string, object>)datos[0];
                sb.Append("<table class='sg-tabla is-compacta'><tr>");
                foreach (string k in primera.Keys)
                    if (k != "INSTALACION") sb.Append("<th>" + HttpUtility.HtmlEncode(k.Replace("_", " ")) + "</th>");
                sb.Append("</tr>");

                int desde = Math.Max(0, datos.Length - 15);
                for (int i = desde; i < datos.Length; i++)
                {
                    Dictionary<string, object> f = (Dictionary<string, object>)datos[i];
                    sb.Append("<tr>");
                    foreach (KeyValuePair<string, object> kv in f)
                    {
                        if (kv.Key == "INSTALACION") continue;
                        if (kv.Key == "FALLO_EN_30D")
                            sb.Append("<td>" + (kv.Value == null ? "<span class='neg'>sin observar</span>" : (Convert.ToBoolean(kv.Value) ? "<span class='pos'>SÍ</span>" : "<span class='neg'>no</span>")) + "</td>");
                        else if (kv.Key == "CORTE")
                            sb.Append("<td>" + HttpUtility.HtmlEncode(Fecha(kv.Value)) + "</td>");
                        else
                            sb.Append("<td class='" + (kv.Value is string ? "" : "num") + "'>" + HttpUtility.HtmlEncode(Celda(kv.Value)) + "</td>");
                    }
                    sb.Append("</tr>");
                }
                sb.Append("</table>");
            }
            litMuestra.Text = sb.ToString();
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void btnRegistrar_Click(object sender, EventArgs e)
    {
        try
        {
            Dictionary<string, object> cuerpo = new Dictionary<string, object>
            {
                { "desde", txtDesde.Text.Trim() },
                { "hasta", txtHasta.Text.Trim() },
                { "paso_dias", Paso() },
                { "observacion", "Registrado desde Experimentos por " + SitioBase.Session.UsuarioLogin() }
            };
            Dictionary<string, object> r = Services.PostJson("/sigma-ai/datasets", cuerpo);

            Tools.tools.ClientAlert("Dataset " + T(r["codigo"]) + " registrado: " + T(r["filas"]) + " filas, " + T(r["positivas"]) + " positivas.", "ok");
            Cargar();
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    private string Rango()
    {
        string q = "paso=" + Paso();
        if (txtDesde.Text.Trim().Length > 0) q += "&desde=" + HttpUtility.UrlEncode(txtDesde.Text.Trim());
        if (txtHasta.Text.Trim().Length > 0) q += "&hasta=" + HttpUtility.UrlEncode(txtHasta.Text.Trim());
        return q;
    }

    private int Paso()
    {
        int p;
        return int.TryParse(txtPaso.Text.Trim(), out p) && p > 0 ? p : 7;
    }

    private void PintarDatasets()
    {
        object[] lista = Lista(Services.GetJsonLibre("/sigma-ai/datasets"));
        if (lista == null || lista.Length == 0)
        {
            litDatasets.Text = "<div class='txt' style='margin-top:8px'><em>Todavía no hay datasets registrados para este cliente.</em></div>";
            return;
        }

        StringBuilder sb = new StringBuilder();
        sb.Append("<table class='sg-tabla is-compacta'><tr><th>Id</th><th>Código</th><th>Rango</th><th class='num'>Filas</th><th class='num'>Positivas</th><th>Huella</th><th class='num'>Versiones</th><th>Registrado</th><th>CSV</th></tr>");
        foreach (object o in lista)
        {
            Dictionary<string, object> d = (Dictionary<string, object>)o;
            sb.Append("<tr><td>" + T(d["den_id"]) + "</td><td><strong>" + HttpUtility.HtmlEncode(T(d["den_codigo"])) + "</strong></td>" +
                      "<td>" + Fecha(d["den_fecha_desde"], true) + " → " + Fecha(d["den_fecha_hasta"], true) + "</td>" +
                      "<td class='num'>" + T(d["den_fila_total"]) + "</td><td class='num'>" + T(d["den_fila_positiva"]) + "</td>" +
                      "<td><code title='" + HttpUtility.HtmlEncode(T(d["den_hash_datos"])) + "'>" + Corto(T(d["den_hash_datos"]), 12) + "</code></td>" +
                      "<td class='num'>" + T(d["VERSIONES"]) + "</td><td>" + Fecha(d["den_fecha_creacion"]) + "</td>" +
                      "<td><code>" + HttpUtility.HtmlEncode(T(d["den_ruta"])) + "</code></td></tr>");
        }
        sb.Append("</table>");
        litDatasets.Text = sb.ToString();
    }

    /* ====================================================================
       PASO 2 · CORRIDAS
       ==================================================================== */

    private void PintarCorridas()
    {
        object[] lista = Lista(Services.GetJsonLibre("/sigma-ai/entrenamientos"));
        if (lista == null || lista.Length == 0)
        {
            litCorridas.Text = "<div class='txt' style='margin-top:8px'><em>Ninguna corrida informada todavía.</em></div>";
            return;
        }

        StringBuilder sb = new StringBuilder();
        sb.Append("<div class='sg-ml-scroll'><table class='sg-tabla is-compacta'><tr><th>Id</th><th>Estado</th><th>Dataset</th><th>Versión</th><th>Entorno</th><th>Inicio (UTC)</th><th class='num'>Seg.</th><th>Métricas</th><th>Mensaje</th></tr>");
        foreach (object o in lista)
        {
            Dictionary<string, object> d = (Dictionary<string, object>)o;
            string estado = T(d["ESTADO"]);
            sb.Append("<tr><td>" + T(d["eej_id"]) + "</td>" +
                      "<td><span class='sg-ml-pill " + (estado.ToUpper().StartsWith("ERROR") ? "is-err" : "is-ok") + "'>" + HttpUtility.HtmlEncode(estado) + "</span></td>" +
                      "<td>" + HttpUtility.HtmlEncode(T(d["DATASET_CODIGO"])) + "</td>" +
                      "<td>" + (d["VERSION_NUMERO"] == null ? "—" : "v" + T(d["VERSION_NUMERO"])) + "</td>" +
                      "<td class='sg-ml-exp'>" + HttpUtility.HtmlEncode(T(d["eej_entorno"])) + "</td>" +
                      "<td>" + Fecha(d["eej_fecha_inicio_utc"]) + "</td><td class='num'>" + T(d["eej_segundo_duracion"]) + "</td>" +
                      "<td class='sg-ml-exp'><code>" + HttpUtility.HtmlEncode(Corto(T(d["eej_metrica"]), 160)) + "</code></td>" +
                      "<td class='sg-ml-exp'>" + HttpUtility.HtmlEncode(Corto(T(d["eej_mensaje"]), 160)) + "</td></tr>");
        }
        sb.Append("</table></div>");
        litCorridas.Text = sb.ToString();
    }

    /* ====================================================================
       PASO 3 · VERSIONES
       ==================================================================== */

    private void PintarVersiones()
    {
        object[] lista = Lista(Services.GetJsonLibre("/sigma-ai/versiones"));
        List<object> filas = new List<object>();
        bool puede = PuedeEntrenar;

        if (lista != null)
        {
            foreach (object o in lista)
            {
                Dictionary<string, object> d = (Dictionary<string, object>)o;
                int estado = Convert.ToInt32(d["mpv_plan_version_estado"]);
                string pill = estado == 2 ? "is-pub" : (estado == 1 ? "is-bor" : "is-ret");
                string ruta = T(d["mpv_ruta"]);
                filas.Add(new
                {
                    id = Convert.ToInt32(d["mpv_id"]),
                    numero = T(d["mpv_numero"]),
                    estadoHtml = "<span class='sg-ml-pill " + pill + "'>" + HttpUtility.HtmlEncode(T(d["ESTADO"])) + "</span>",
                    algoritmo = HttpUtility.HtmlEncode(T(d["mpv_algoritmo"])),
                    dataset = HttpUtility.HtmlEncode(T(d["DATASET_CODIGO"])) + (d["DATASET_FILAS"] == null ? "" : " <span class='neg'>(" + T(d["DATASET_FILAS"]) + "/" + T(d["DATASET_POSITIVAS"]) + ")</span>"),
                    auc = Num(d["mpv_metrica_auc"], "0.000"),
                    precision = Num(d["mpv_metrica_precision"], "0.000"),
                    recall = Num(d["mpv_metrica_recall"], "0.000"),
                    f1 = Num(d["mpv_metrica_f1"], "0.000"),
                    ruta = HttpUtility.HtmlEncode(ruta),
                    rutaCorta = HttpUtility.HtmlEncode(string.IsNullOrEmpty(ruta) ? "sin registrar" : Corto(ruta, 34)),
                    entrenada = Fecha(d["mpv_fecha_entrenamiento_utc"]),
                    puedePublicar = puede && estado == 1
                });
            }
        }

        rptVersiones.DataSource = filas;
        rptVersiones.DataBind();
        litVersionesVacio.Text = filas.Count == 0 ? "<div class='txt' style='margin-top:8px'><em>Ninguna versión entrenada todavía.</em></div>" : "";
    }

    protected void rptVersiones_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "publicar") return;
        try
        {
            Services.PostJson("/sigma-ai/versiones/" + e.CommandArgument + "/publicar", new Dictionary<string, object>());
            Tools.tools.ClientAlert("Versión publicada. La API ya puntúa con sus pesos.", "ok");
            Cargar();
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /* ====================================================================
       PASO 4 · PUNTUAR
       ==================================================================== */

    protected void btnPredecir_Click(object sender, EventArgs e)
    {
        try
        {
            Dictionary<string, object> r = Services.PostJson("/sigma-ai/predecir", new Dictionary<string, object>());
            object[] lista = Lista(r["predicciones"]);

            StringBuilder sb = new StringBuilder();
            sb.Append("<div class='sg-ml-aviso is-ok'>Puntuados <strong>" + T(r["equipos"]) + " equipos</strong> con la versión v" + T(r["version"]) + ".</div>");
            sb.Append(TablaPredicciones(lista, true));

            Cargar();                       // los contadores cambiaron
            litPredicciones.Text = sb.ToString();
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    private void PintarVigentes()
    {
        object[] lista = Lista(Services.GetJsonLibre("/sigma-ai/predicciones"));
        if (lista == null || lista.Length == 0)
        {
            litPredicciones.Text = "<div class='txt' style='margin-top:8px'><em>No hay predicciones vigentes de SIGMA FAILURE.</em></div>";
            return;
        }
        litPredicciones.Text = TablaPredicciones(lista, false);
    }

    /// <summary>La misma tabla para lo recién puntuado y para lo vigente.</summary>
    private static string TablaPredicciones(object[] lista, bool recien)
    {
        if (lista == null || lista.Length == 0) return "";

        StringBuilder sb = new StringBuilder();
        sb.Append("<table class='sg-tabla is-compacta'><tr><th>Equipo</th><th class='num'>Probabilidad</th><th></th><th>Por qué</th>" + (recien ? "" : "<th>Severidad</th><th>Calculada (UTC)</th><th>Alerta</th>") + "</tr>");
        foreach (object o in lista)
        {
            Dictionary<string, object> d = (Dictionary<string, object>)o;
            double p = recien ? Convert.ToDouble(d["probabilidad"], CultureInfo.InvariantCulture) : Convert.ToDouble(d["pre_probabilidad"], CultureInfo.InvariantCulture);
            string codigo = recien ? T(d["codigo"]) : T(d["ACTIVO_CODIGO"]);
            string nombre = recien ? T(d["nombre"]) : T(d["ACTIVO_NOMBRE"]);

            string porque;
            if (recien)
            {
                List<string> frases = new List<string>();
                object[] ex = Lista(d["explicaciones"]);
                if (ex != null) foreach (object x in ex) frases.Add(T(((Dictionary<string, object>)x)["texto"]));
                porque = string.Join(" ", frases.ToArray());
            }
            else porque = T(d["EXPLICACION"]);

            sb.Append("<tr><td><strong>" + HttpUtility.HtmlEncode(codigo) + "</strong> " + HttpUtility.HtmlEncode(nombre) + "</td>" +
                      "<td class='num'><strong>" + (p * 100).ToString("0.0", CL) + " %</strong></td>" +
                      "<td><span class='sg-ml-barra' style='width:" + Math.Max(4, (int)(p * 120)) + "px'></span></td>" +
                      "<td class='sg-ml-exp'>" + HttpUtility.HtmlEncode(porque) + "</td>");
            if (!recien)
                sb.Append("<td>" + HttpUtility.HtmlEncode(T(d["SEVERIDAD"])) + "</td><td>" + Fecha(d["pre_fecha_calculo_utc"]) + "</td>" +
                          "<td>" + (d["pre_alerta"] == null ? "—" : "#" + T(d["pre_alerta"])) + "</td>");
            sb.Append("</tr>");
        }
        sb.Append("</table>");
        return sb.ToString();
    }

    /* ====================================================================
       PASO 5 · AZURE ML
       ==================================================================== */

    protected void btnAzure_Click(object sender, EventArgs e)
    {
        try
        {
            Dictionary<string, object> a = Services.GetJson("/sigma-ai/azure");
            StringBuilder sb = new StringBuilder();

            if (!Convert.ToBoolean(a["configurado"]))
            {
                object[] faltan = Lista(a["faltantes"]);
                sb.Append("<div class='sg-ml-aviso'><strong>Azure ML no está configurado en la API.</strong> Faltan en Web.config: <code>" +
                          HttpUtility.HtmlEncode(faltan == null ? "" : string.Join(", ", Array.ConvertAll(faltan, x => T(x)))) +
                          "</code>. La API no intenta conectarse hasta que estén.</div>");
                litAzure.Text = sb.ToString();
                return;
            }

            Dictionary<string, object> area = a["area"] as Dictionary<string, object>;
            sb.Append("<div class='sg-ml-aviso is-ok'>Área de trabajo <strong>" + HttpUtility.HtmlEncode(T(area["nombre"])) + "</strong> · " +
                      HttpUtility.HtmlEncode(T(area["region"])) + " · " + HttpUtility.HtmlEncode(T(area["estado"])) +
                      " · almacenamiento <code>" + HttpUtility.HtmlEncode(T(area["almacenamiento"])) + "</code></div>");

            Dictionary<string, object> m = Services.GetJson("/sigma-ai/azure/modelos");
            object[] modelos = Lista(m["modelos"]);
            sb.Append("<h5 style='font-size:13px;font-weight:800;margin:10px 0 4px'>Modelos registrados</h5>");
            if (modelos == null || modelos.Length == 0) sb.Append("<div class='txt'><em>Ninguno todavía.</em></div>");
            else
            {
                sb.Append("<table class='sg-tabla is-compacta'><tr><th>Nombre</th><th>Última versión</th><th>Descripción</th><th>Modificado</th></tr>");
                foreach (object o in modelos)
                {
                    Dictionary<string, object> d = (Dictionary<string, object>)o;
                    sb.Append("<tr><td><strong>" + HttpUtility.HtmlEncode(T(d["nombre"])) + "</strong></td><td>" + HttpUtility.HtmlEncode(T(d["ultimaVersion"])) +
                              "</td><td class='sg-ml-exp'>" + HttpUtility.HtmlEncode(T(d["descripcion"])) + "</td><td>" + HttpUtility.HtmlEncode(T(d["modificado"])) + "</td></tr>");
                }
                sb.Append("</table>");
            }

            Dictionary<string, object> ex = Services.GetJson("/sigma-ai/azure/experimentos");
            object[] experimentos = Lista(ex["experimentos"]);
            sb.Append("<h5 style='font-size:13px;font-weight:800;margin:14px 0 4px'>Experimentos (MLflow)</h5>");
            if (experimentos == null || experimentos.Length == 0) sb.Append("<div class='txt'><em>Ninguno todavía.</em></div>");
            else
            {
                sb.Append("<table class='sg-tabla is-compacta'><tr><th>Nombre</th><th>Id</th><th>Estado</th><th>Actualizado</th></tr>");
                foreach (object o in experimentos)
                {
                    Dictionary<string, object> d = (Dictionary<string, object>)o;
                    sb.Append("<tr><td><strong>" + HttpUtility.HtmlEncode(T(d["nombre"])) + "</strong></td><td><code>" + HttpUtility.HtmlEncode(T(d["id"])) +
                              "</code></td><td>" + HttpUtility.HtmlEncode(T(d["estado"])) + "</td><td>" + HttpUtility.HtmlEncode(T(d["actualizado"])) + "</td></tr>");
                }
                sb.Append("</table>");
            }

            litAzure.Text = sb.ToString();
        }
        catch (Exception ex)
        {
            litAzure.Text = "<div class='sg-ml-aviso is-mal'>" + HttpUtility.HtmlEncode(ex.Message) + "</div>";
        }
    }

    /* ====================================================================
       AYUDAS
       ==================================================================== */

    /// <summary>
    /// Un arreglo JSON llega como object[] cuando es la raíz (DeserializeObject)
    /// y como ArrayList cuando viene anidado en un Dictionary: se unifica.
    /// </summary>
    private static object[] Lista(object o)
    {
        if (o == null) return null;
        if (o is object[]) return (object[])o;
        System.Collections.ArrayList al = o as System.Collections.ArrayList;
        return al == null ? null : al.ToArray();
    }

    private static string T(object o)
    {
        return o == null ? "" : Convert.ToString(o, CultureInfo.InvariantCulture);
    }

    private static string Num(object o, string formato)
    {
        if (o == null) return "—";
        double v;
        return double.TryParse(Convert.ToString(o, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out v)
            ? v.ToString(formato, CL) : T(o);
    }

    private static string Celda(object o)
    {
        if (o == null) return "";
        if (o is bool) return (bool)o ? "1" : "0";
        double v;
        if (!(o is string) && double.TryParse(Convert.ToString(o, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out v))
            return v == Math.Floor(v) && Math.Abs(v) < 1e9 ? v.ToString("0", CL) : v.ToString("0.####", CL);
        return T(o);
    }

    /// <summary>Las fechas de la API vienen como texto ISO; se muestran cortas.</summary>
    private static string Fecha(object o, bool soloDia = false)
    {
        if (o == null) return "";
        DateTime f;
        string s = T(o);
        if (DateTime.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.None, out f))
            return f.ToString(soloDia ? "dd-MM-yyyy" : "dd-MM-yyyy HH:mm", CL);
        return s;
    }

    private static string Corto(string s, int n)
    {
        if (string.IsNullOrEmpty(s)) return "";
        return s.Length <= n ? s : s.Substring(0, n) + "…";
    }
}
