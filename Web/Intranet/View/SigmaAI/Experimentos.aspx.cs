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

    /// <summary>FALLA, RUL o VISION: viene en la URL; sin él, FALLA.</summary>
    private string Modelo
    {
        get
        {
            string m = (Request.QueryString["modelo"] ?? "FALLA").Trim().ToUpperInvariant();
            return m == "RUL" || m == "VISION" ? m : "FALLA";
        }
    }

    private bool EsRul { get { return Modelo == "RUL"; } }
    private bool EsVision { get { return Modelo == "VISION"; } }

    private string Q()
    {
        return "?modelo=" + Modelo;
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
        btnPredecir.Visible = puede && !EsVision;
        pnlClasificar.Visible = EsVision;

        PintarTextos();
        if (!IsPostBack) Cargar();
    }

    /* ====================================================================
       LO QUE SE PINTA SIEMPRE
       ==================================================================== */

    /// <summary>Las pestañas y los textos que cambian con el modelo.</summary>
    private void PintarTextos()
    {
        string url = ResolveUrl("~/View/SigmaAI/Experimentos.aspx");
        litTabs.Text =
            Tab(url, "FALLA", "mdi-alert-decagram-outline", "SIGMA FAILURE", "falla a 30 días") +
            Tab(url, "RUL", "mdi-timer-sand", "SIGMA RUL", "vida útil restante") +
            Tab(url, "VISION", "mdi-image-search-outline", "SIGMA VISION", "clasificación de fotos");

        if (EsRul)
        {
            litSubtitulo.Text = "SIGMA RUL: cuántos días más va a durar cada repuesto instalado, con su margen. Mismo camino: dataset con censura desde la base, AFT log-normal local, registro en Azure ML, puntuación en la API.";
            litTituloDataset.Text = "Dataset: una instalación de repuesto × una fecha de corte";
            litTextoDataset.Text = "<code>FNC_ML_COMPONENTE_HISTORICO_V1</code> calcula, para cada repuesto instalado y cada corte en que seguía puesto, 14 características con lo que pasó <strong>antes</strong> (días y horas corriendo, vida nominal y consumida, historial del mismo repuesto en ese componente, estado del equipo) y el label <code>DIAS_RESTANTES</code> con lo que pasó <strong>después</strong>. <code>CENSURADO = 1</code> marca los que siguen puestos o se retiraron por otro motivo que falla o desgaste: duraron <em>al menos</em> eso, y así los usa el entrenador. «Positivas» aquí son los retiros observados.";
            litTituloEntrenar.Text = "Entrenar en tu computador y registrar en Azure ML";
            litTextoEntrenar.Text = "<code>ML/entrenar_rul.py</code> baja el dataset por la API y ajusta una regresión de supervivencia (AFT log-normal con censura, scipy): log(días restantes) = pesos · características + sigma · ruido. Valida el error en días sobre los retiros observados y la cobertura del intervalo del 80 %, exporta la parte lineal a ONNX, la contrasta con los pesos y, con <code>MLFLOW_TRACKING_URI</code>, deja la corrida y registra <code>SIGMA_RUL</code> en Azure ML. Informa la versión con <code>POST /sigma-ai/entrenamientos?modelo=RUL</code>.";
            litTituloPuntuar.Text = "Puntuar hoy las instalaciones vigentes";
            litTextoPuntuar.Text = "<code>POST /sigma-ai/predecir?modelo=RUL</code> arma la fila de hoy de cada repuesto que sigue puesto, la puntúa dentro de la API (<code>PuntuadorRul</code>: estandarizar, pesos, exponencial) y guarda la mediana de días restantes, el intervalo del 80 %, la fecha estimada, las tres razones y la alerta si quedan menos días que el umbral (30). El intervalo ancho es honesto: dice cuánto sabe el modelo.";
            litBotonPuntuar.Text = "Puntuar las instalaciones vigentes";
        }
        else if (EsVision)
        {
            litSubtitulo.Text = "SIGMA VISION: qué muestra una foto de terreno (corrosión, fuga, desgaste, normal). Custom Vision F0 entrena y predice gratis con claves; el modelo exportado a ONNX se registra en Azure ML como los otros dos.";
            litTituloDataset.Text = "Dataset: una imagen etiquetada";
            litTextoDataset.Text = "<code>API_SEL_ML_DATASET_VISION</code> lista las imágenes del cliente con una etiqueta <strong>confirmada por una persona</strong> (<code>Analisis_Visual_Deteccion.avd_confirmado_humano = 1</code>): la ruta del archivo, la etiqueta, la severidad y quién la confirmó. Sin revisión humana no hay dataset: una etiqueta que puso otro modelo no enseña nada nuevo. «Positivas» aquí son las imágenes etiquetadas.";
            litTituloEntrenar.Text = "Entrenar en Custom Vision y registrar en Azure ML";
            litTextoEntrenar.Text = "<code>ML/entrenar_vision.py</code> baja las imágenes etiquetadas por la API (<code>/archivo/ver</code>), las sube al proyecto de Custom Vision con sus etiquetas, entrena (nivel F0: 1 h/mes), publica la iteración <code>sigma-vision</code>, lee la precisión y el recall por etiqueta, exporta el modelo a ONNX y lo registra en Azure ML con su hash. Con <code>--demo</code> fabrica imágenes sintéticas etiquetadas para probar el camino. Necesita <code>CV_TRAINING_ENDPOINT</code> y <code>CV_TRAINING_KEY</code> en el entorno.";
            litTituloPuntuar.Text = "Clasificar una imagen con la iteración publicada";
            litTextoPuntuar.Text = "<code>POST /sigma-ai/vision/clasificar</code> manda la imagen a Custom Vision (clave de predicción del Web.config), devuelve las etiquetas con su probabilidad y deja el resultado en <code>Analisis_Visual_Revision</code> / <code>Analisis_Visual_Deteccion</code> con motor SIGMA VISION y la versión del modelo, <strong>sin confirmar</strong>: la confirmación es de una persona y es lo que alimenta el próximo dataset.";
        }
        else
        {
            litTituloDataset.Text = "Dataset: un equipo × una fecha de corte";
            litTextoDataset.Text = "<code>FNC_ML_ACTIVO_HISTORICO_V1</code> calcula, para cada equipo y cada corte, 15 características con lo que pasó <strong>antes</strong> del corte y el label <code>FALLO_EN_30D</code> con lo que pasó <strong>después</strong> (una falla en los 30 días siguientes). Sin fechas toma desde el primer registro del cliente hasta hoy − 30, un corte cada 7 días. Registrar el dataset guarda cuántas filas tiene, cuántas positivas y su huella SHA-256: la versión que salga de él dirá exactamente con qué se entrenó.";
            litTextoEntrenar.Text = "<code>ML/entrenar_falla.py</code> baja el dataset por la API, entrena una regresión logística (scikit-learn), la valida, la convierte a ONNX y comprueba que el ONNX y los pesos dan la misma probabilidad. Si <code>MLFLOW_TRACKING_URI</code> apunta al área de trabajo, deja la corrida y registra el modelo en Azure ML (gratis); si no, lo deja en <code>ML/mlruns</code>. Al terminar informa la corrida y la versión con <code>POST /sigma-ai/entrenamientos</code>; la versión queda en <strong>borrador</strong>.";
            litTextoPuntuar.Text = "<code>POST /sigma-ai/predecir</code> arma la fila de hoy de cada equipo, la puntúa dentro de la API (<code>PuntuadorFalla</code>: estandarizar, multiplicar por los pesos, sigmoide) y guarda la predicción con las características que usó, las tres razones que más pesaron y la alerta si supera el umbral del modelo. Volver a puntuar el mismo día devuelve la misma predicción. Lo que sale se ve también en <strong>Alertas</strong> y en la app (Análisis de SIGMA AI).";
        }
    }

    private string Tab(string url, string codigo, string icono, string nombre, string detalle)
    {
        bool activa = Modelo == codigo;
        return "<a class='sg-ml-tab" + (activa ? " is-activa" : "") + "' href='" + url + "?modelo=" + codigo + "'><i class='mdi " + icono + "'></i>" +
               HttpUtility.HtmlEncode(nombre) + " <small>· " + HttpUtility.HtmlEncode(detalle) + "</small></a>";
    }

    private void Cargar()
    {
        try
        {
            Dictionary<string, object> estado = Services.GetJson("/sigma-ai/estado" + Q());
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
                      hayVersion ? (EsRul ? "MAE " + Num(m["VERSION_MAE"], "0.0") + " días" : "AUC " + Num(m["VERSION_AUC"], "0.000")) + " · " + T(m["VERSION_ALGORITMO"]) : "Nada publicado aún"));
        string datos = EsRul ? T(m["INSTALACIONES"]) + " instalaciones · " + T(m["RETIROS"]) + " retiros"
                     : EsVision ? T(m["IMAGENES_ETIQUETADAS"]) + " imágenes etiquetadas por una persona"
                     : T(m["ACTIVOS"]) + " equipos · " + T(m["FALLAS"]) + " fallas · " + T(m["MEDICIONES"]) + " mediciones";
        sb.Append(Kpi("mdi-database-outline", T(m["DATASETS"]), "Datasets registrados", datos));
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
        sb.Append(Paso(true, EsRul ? "Base de datos (bloque 247): modelo <strong>SIGMA RUL</strong>, 14 características, función de dataset con censura y sin fuga, SP de puntuación con intervalo."
                           : EsVision ? "Base de datos (bloque 248): modelo <strong>SIGMA VISION</strong>, 6 etiquetas, dataset de imágenes confirmadas, SP que guarda la revisión visual sin confirmar."
                           : "Base de datos (bloque 245): modelo <strong>SIGMA FAILURE 30D</strong>, 15 características, función de dataset sin fuga, SP de registro y puntuación, menú y permiso."));
        sb.Append(Paso(true, "API: <code>/sigma-ai/*</code> (estado, dataset, datasets, entrenamientos, versiones, predecir, simular, azure) y el puntuador en C#."));
        sb.Append(Paso(hayDataset, "Paso 1 · Registrar un dataset desde esta pantalla (o <code>POST /sigma-ai/datasets</code>)."));
        sb.Append(PasoPersona("Instalar en tu computador: <code>pip install scikit-learn pandas requests mlflow azureml-mlflow skl2onnx onnxruntime</code>."));
        sb.Append(PasoPersona("En el portal de Azure (una sola vez, sin costo): <strong>Entra ID › Registros de aplicaciones › Nuevo</strong> «sigma-api-ml» → anotar <em>Id. de aplicación</em> e <em>Id. de inquilino</em> → <em>Certificados y secretos</em> → nuevo secreto. Luego en el área de trabajo <strong>SIGMA_AI › Control de acceso (IAM) › Agregar asignación de roles › AzureML Data Scientist</strong> a esa aplicación. No crear instancias ni clústeres de cómputo."));
        sb.Append(PasoPersona("Poner esas claves en <code>API/Web.config</code> (<code>AzureML.TenantId</code>, <code>ClientId</code>, <code>ClientSecret</code>, <code>SubscriptionId</code>); nunca por chat ni correo. Región, grupo y área ya vienen puestos."));
        sb.Append(Paso(hayCorrida, "Paso 2 · Correr <code>ML/" + (EsRul ? "entrenar_rul.py" : (EsVision ? "entrenar_vision.py" : "entrenar_falla.py")) + "</code> con el id del dataset: entrena, valida, exporta ONNX, registra en Azure ML e informa a la API."));
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
        string script = EsRul ? "entrenar_rul.py" : (EsVision ? "entrenar_vision.py" : "entrenar_falla.py");
        if (EsVision) sb.Append("set CV_TRAINING_ENDPOINT=https://&lt;recurso&gt;.cognitiveservices.azure.com/\nset CV_TRAINING_KEY=&lt;clave de entrenamiento&gt;\nset CV_PROJECT_ID=&lt;id del proyecto&gt;\n");
        sb.Append("python " + script + " --usuario &lt;tu login&gt; --dataset &lt;id&gt;      (pide la contraseña; --sin-azure para no registrar; --demo para un dataset sintético)");
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
            Dictionary<string, object> r = Services.GetJson("/sigma-ai/dataset?" + Rango() + "&formato=json&modelo=" + Modelo);
            object[] datos = Lista(r["datos"]);

            StringBuilder sb = new StringBuilder();
            string unidad = EsRul ? "(instalación × corte)" : (EsVision ? "(imágenes)" : "(equipo × corte)");
            string positivas = EsRul ? "retiros observados</strong> (el resto duró <em>al menos</em> lo registrado)"
                             : (EsVision ? "con etiqueta confirmada</strong>" : "positivas</strong> (falla en los 30 días siguientes)");
            sb.Append("<div class='sg-ml-aviso is-ok'><strong>" + T(r["filas"]) + " filas</strong> " + unidad + " · " +
                      T(r["etiquetadas"]) + " con label observable · <strong>" + T(r["positivas"]) + " " + positivas + ". " +
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
                        else if (kv.Key == "CENSURADO")
                            sb.Append("<td>" + (kv.Value != null && Convert.ToBoolean(kv.Value) ? "<span class='neg'>al menos</span>" : "<span class='pos'>observado</span>") + "</td>");
                        else if (kv.Key == "CORTE" || kv.Key == "INSTALADO")
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
            Dictionary<string, object> r = Services.PostJson("/sigma-ai/datasets" + Q(), cuerpo);

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
        object[] lista = Lista(Services.GetJsonLibre("/sigma-ai/datasets" + Q()));
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
        object[] lista = Lista(Services.GetJsonLibre("/sigma-ai/entrenamientos" + Q()));
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
        object[] lista = Lista(Services.GetJsonLibre("/sigma-ai/versiones" + Q()));
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
                string registro = T(d["mpv_registro"]);
                bool verificada = d["mpv_fecha_verificacion_utc"] != null;
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
                    mae = Num(d["mpv_metrica_mae"], "0.0"),
                    ruta = HttpUtility.HtmlEncode(ruta),
                    registroHtml = string.IsNullOrEmpty(ruta)
                        ? "<span class='neg'>sin registrar</span>"
                        : "<strong>" + HttpUtility.HtmlEncode(string.IsNullOrEmpty(registro) ? "registrado" : registro) + "</strong>" +
                          (verificada ? " <span class='sg-ml-pill is-ok' title='La API bajó el .onnx y su hash coincide'>verificado " + Fecha(d["mpv_fecha_verificacion_utc"]) + "</span>"
                                      : " <span class='sg-ml-pill is-bor'>sin verificar</span>"),
                    entrenada = Fecha(d["mpv_fecha_entrenamiento_utc"]),
                    puedePublicar = puede && estado == 1,
                    tieneArtefacto = !string.IsNullOrEmpty(ruta)
                });
            }
        }

        rptVersiones.DataSource = filas;
        rptVersiones.DataBind();
        litVersionesVacio.Text = filas.Count == 0 ? "<div class='txt' style='margin-top:8px'><em>Ninguna versión entrenada todavía.</em></div>" : "";
    }

    protected void rptVersiones_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        try
        {
            if (e.CommandName == "publicar")
            {
                Services.PostJson("/sigma-ai/versiones/" + e.CommandArgument + "/publicar", new Dictionary<string, object>());
                Tools.tools.ClientAlert("Versión publicada. La API ya puntúa con sus pesos.", "ok");
                Cargar();
            }
            else if (e.CommandName == "verificar")
            {
                Dictionary<string, object> v = Services.GetJson("/sigma-ai/versiones/" + e.CommandArgument + "/artefactos");
                Cargar();
                litArtefacto.Text = PintarArtefacto(v, Convert.ToInt32(e.CommandArgument));
            }
            else if (e.CommandName == "sincronizar")
            {
                Dictionary<string, object> v = Services.PostJson("/sigma-ai/versiones/" + e.CommandArgument + "/sincronizar", new Dictionary<string, object>());
                Tools.tools.ClientAlert("Los pesos de la versión ahora son los del artefacto registrado en Azure ML.", "ok");
                Cargar();
                litArtefacto.Text = PintarArtefacto(v, Convert.ToInt32(e.CommandArgument));
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Lo que la API encontró en el área de trabajo para esa versión: los
    /// archivos, el hash de Azure contra el del entrenador y si los pesos
    /// son los mismos. Con permiso, el botón para tomar los pesos de Azure.
    /// </summary>
    private string PintarArtefacto(Dictionary<string, object> v, int id)
    {
        StringBuilder sb = new StringBuilder();
        bool hash = v["hashCoincide"] != null && Convert.ToBoolean(v["hashCoincide"]);
        bool pesos = v["pesosCoinciden"] != null && Convert.ToBoolean(v["pesosCoinciden"]);
        object[] archivos = Lista(v["archivos"]);

        sb.Append("<div class='sg-ml-aviso " + (hash ? "is-ok" : "is-mal") + "' style='margin-top:12px'><strong>v" + T(v["version"]) +
                  (string.IsNullOrEmpty(T(v["registro"])) ? "" : " · " + HttpUtility.HtmlEncode(T(v["registro"]))) + "</strong> — " +
                  HttpUtility.HtmlEncode(T(v["mensaje"])) +
                  (archivos != null && archivos.Length > 0 ? (pesos ? " Los pesos del JSON de Azure son los de la versión." : " Los pesos del JSON de Azure NO son los de la versión.") : "") +
                  "</div>");

        if (archivos != null && archivos.Length > 0)
        {
            sb.Append("<div class='txt'>Ruta en el área de trabajo: <code>" + HttpUtility.HtmlEncode(T(v["rutaBlob"])) + "</code></div>");
            sb.Append("<table class='sg-tabla is-compacta'><tr><th>Archivo</th><th class='num'>Bytes</th><th>Modificado (UTC)</th><th>SHA-256</th></tr>");
            foreach (object o in archivos)
            {
                Dictionary<string, object> a = (Dictionary<string, object>)o;
                sb.Append("<tr><td><strong>" + HttpUtility.HtmlEncode(T(a["nombre"])) + "</strong></td><td class='num'>" + T(a["bytes"]) +
                          "</td><td>" + Fecha(a["modificado"]) + "</td><td><code title='" + HttpUtility.HtmlEncode(T(a["sha256"])) + "'>" +
                          Corto(T(a["sha256"]), 16) + "</code></td></tr>");
            }
            sb.Append("</table>");
            sb.Append("<div class='txt' style='margin-top:6px'>Hash informado por el entrenador: <code>" + Corto(T(v["hashVersion"]), 16) +
                      "</code> · hash del .onnx en Azure: <code>" + Corto(T(v["hashAzure"]), 16) + "</code></div>");
        }

        litArtefacto.Text = sb.ToString();

        /* El botón de sincronizar se agrega como control real, no como HTML:
           tiene que hacer postback con permiso. */
        if (hash && PuedeEntrenar)
        {
            sb.Append("<div class='sg-ml-form'><a href=\"javascript:__doPostBack('" + btnSincronizar.UniqueID + "','" + id + "')\" class='sigma-accion'>" +
                      "<i class='mdi mdi-cloud-download-outline'></i><span>Tomar los pesos desde Azure ML</span></a></div>");
        }
        return sb.ToString();
    }

    /// <summary>Postback del enlace «Tomar los pesos desde Azure ML» (el id viene como argumento).</summary>
    protected void btnSincronizar_Click(object sender, EventArgs e)
    {
        string arg = Request.Form["__EVENTARGUMENT"];
        int id;
        if (!int.TryParse(arg, out id)) return;
        rptVersiones_ItemCommand(rptVersiones, new RepeaterCommandEventArgs(null, sender, new CommandEventArgs("sincronizar", id)));
    }

    /* ====================================================================
       PASO 4 · PUNTUAR
       ==================================================================== */

    protected void btnPredecir_Click(object sender, EventArgs e)
    {
        try
        {
            Dictionary<string, object> r = Services.PostJson("/sigma-ai/predecir" + Q(), new Dictionary<string, object>());
            object[] lista = Lista(r["predicciones"]);

            StringBuilder sb = new StringBuilder();
            sb.Append("<div class='sg-ml-aviso is-ok'>Puntuados <strong>" + T(r["equipos"]) + (EsRul ? " repuestos instalados" : " equipos") + "</strong> con la versión v" + T(r["version"]) + ".</div>");
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
        if (EsVision)
        {
            litPredicciones.Text = "<div class='txt' style='margin-top:8px'><em>SIGMA VISION clasifica imagen por imagen; el resultado queda en la revisión visual del archivo.</em></div>";
            return;
        }
        object[] lista = Lista(Services.GetJsonLibre("/sigma-ai/predicciones" + Q()));
        if (lista == null || lista.Length == 0)
        {
            litPredicciones.Text = "<div class='txt' style='margin-top:8px'><em>No hay predicciones vigentes de SIGMA FAILURE.</em></div>";
            return;
        }
        litPredicciones.Text = TablaPredicciones(lista, false);
    }

    /// <summary>La misma tabla para lo recién puntuado y para lo vigente.</summary>
    private string TablaPredicciones(object[] lista, bool recien)
    {
        if (lista == null || lista.Length == 0) return "";
        if (EsRul) return TablaRul(lista, recien);

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

    /// <summary>RUL: días restantes con su intervalo, en vez de probabilidad.</summary>
    private static string TablaRul(object[] lista, bool recien)
    {
        StringBuilder sb = new StringBuilder();
        sb.Append("<table class='sg-tabla is-compacta'><tr><th>Repuesto en componente</th><th>Equipo</th><th class='num'>Días restantes</th><th>Intervalo 80 %</th><th>Fecha estimada</th><th>Por qué</th>" + (recien ? "" : "<th>Severidad</th><th>Alerta</th>") + "</tr>");
        foreach (object o in lista)
        {
            Dictionary<string, object> d = (Dictionary<string, object>)o;
            string sujeto = recien ? T(d["nombre"]) : T(d["REPUESTO_CODIGO"]) + " " + T(d["REPUESTO_NOMBRE"]) + " en " + T(d["COMPONENTE_CODIGO"]) + " " + T(d["COMPONENTE_NOMBRE"]);
            string equipo = recien ? T(d["codigo"]) : T(d["ACTIVO_CODIGO"]) + " " + T(d["ACTIVO_NOMBRE"]);
            string dias = recien ? Num(d["dias"], "0") : T(d["pre_dia_restante"]);
            string inf = recien ? Num(d["diasInferior"], "0") : Num(d["pre_intervalo_inferior"], "0");
            string sup = recien ? Num(d["diasSuperior"], "0") : Num(d["pre_intervalo_superior"], "0");
            string fecha = recien ? T(d["fechaEstimada"]) : Fecha(d["pre_fecha_evento_estimada_utc"], true);
            string porque;
            if (recien)
            {
                List<string> frases = new List<string>();
                object[] ex = Lista(d["explicaciones"]);
                if (ex != null) foreach (object x in ex) frases.Add(T(((Dictionary<string, object>)x)["texto"]));
                porque = string.Join(" ", frases.ToArray());
            }
            else porque = T(d["EXPLICACION"]);

            sb.Append("<tr><td><strong>" + HttpUtility.HtmlEncode(sujeto) + "</strong></td><td>" + HttpUtility.HtmlEncode(equipo) + "</td>" +
                      "<td class='num'><strong>" + dias + "</strong></td><td class='num'>" + inf + " – " + sup + "</td><td>" + HttpUtility.HtmlEncode(fecha) + "</td>" +
                      "<td class='sg-ml-exp'>" + HttpUtility.HtmlEncode(porque) + "</td>");
            if (!recien)
                sb.Append("<td>" + HttpUtility.HtmlEncode(T(d["SEVERIDAD"])) + "</td><td>" + (d["pre_alerta"] == null ? "—" : "#" + T(d["pre_alerta"])) + "</td>");
            sb.Append("</tr>");
        }
        sb.Append("</table>");
        return sb.ToString();
    }

    /* ====================================================================
       PASO 4b · SIGMA VISION: clasificar una imagen
       ==================================================================== */

    protected void btnClasificar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!fuImagen.HasFile) throw new Exception("Elija una imagen (JPG o PNG).");
            byte[] bytes = fuImagen.FileBytes;
            if (bytes.Length > 4 * 1024 * 1024) throw new Exception("La imagen supera los 4 MB que acepta Custom Vision.");

            Dictionary<string, object> r = Services.PostJson("/sigma-ai/vision/clasificar", new Dictionary<string, object>
            {
                { "nombre", fuImagen.FileName },
                { "mime", fuImagen.PostedFile.ContentType },
                { "imagen_base64", Convert.ToBase64String(bytes) }
            });

            StringBuilder sb = new StringBuilder();
            sb.Append("<div class='sg-ml-aviso is-ok'>Imagen <strong>" + HttpUtility.HtmlEncode(fuImagen.FileName) + "</strong> clasificada con la iteración <code>" +
                      HttpUtility.HtmlEncode(T(r["iteracion"])) + "</code>" + (r["revision"] == null ? "" : " · revisión #" + T(r["revision"])) + ".</div>");
            sb.Append("<table class='sg-tabla is-compacta'><tr><th>Etiqueta</th><th class='num'>Probabilidad</th><th></th></tr>");
            object[] etiquetas = Lista(r["etiquetas"]);
            if (etiquetas != null)
                foreach (object o in etiquetas)
                {
                    Dictionary<string, object> d = (Dictionary<string, object>)o;
                    double p = Convert.ToDouble(d["probabilidad"], CultureInfo.InvariantCulture);
                    sb.Append("<tr><td><strong>" + HttpUtility.HtmlEncode(T(d["nombre"])) + "</strong></td><td class='num'>" + (p * 100).ToString("0.0", CL) +
                              " %</td><td><span class='sg-ml-barra' style='width:" + Math.Max(4, (int)(p * 120)) + "px'></span></td></tr>");
                }
            sb.Append("</table>");
            litPredicciones.Text = sb.ToString();
        }
        catch (Exception ex)
        {
            litPredicciones.Text = "<div class='sg-ml-aviso is-mal'>" + HttpUtility.HtmlEncode(ex.Message) + "</div>";
        }
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
