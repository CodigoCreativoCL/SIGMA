using API.MVC.Model;
using API.Utils;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// SIGMA AI · Investigación Azure Machine Learning.
    ///
    /// TRES MODELOS, UN CAMINO
    ///   Todo endpoint recibe `?modelo=FALLA|RUL|VISION` (FALLA por omisión) y
    ///   el resto es igual para los tres:
    ///   1. GET  /sigma-ai/dataset        el dataset (sujeto × fecha de corte) que
    ///                                    arma la base: características antes del
    ///                                    corte, label después (sin fuga).
    ///   2. POST /sigma-ai/datasets       lo registra (filas, positivas, hash).
    ///   3. (fuera)                       `ML/entrenar_*.py` entrena en el equipo de
    ///                                    quien entrena, deja la corrida y el .onnx en
    ///                                    Azure ML (gratis: registro, no cómputo) …
    ///   4. POST /sigma-ai/entrenamientos … y vuelve con las métricas y los pesos.
    ///   5. POST /sigma-ai/versiones/{id}/publicar
    ///   6. POST /sigma-ai/predecir       puntúa hoy con los pesos de la versión
    ///                                    publicada (`PuntuadorFalla` / `PuntuadorRul`)
    ///                                    y guarda en `Prediccion`, con explicación y alerta.
    ///   7. GET  /sigma-ai/versiones/{id}/artefactos   el .onnx registrado, leído del
    ///                                    almacenamiento del área (sin entidad de servicio).
    ///
    ///   FALLA  = SIGMA FAILURE 30D  · sujeto: el equipo        · probabilidad
    ///   RUL    = SIGMA RUL          · sujeto: la instalación   · días restantes + intervalo
    ///   VISION = SIGMA VISION       · sujeto: la imagen        · etiqueta (Custom Vision)
    ///
    /// QUIEN PUEDE
    ///   Leer: VER PREDICCIONES. Registrar, entrenar, publicar y puntuar:
    ///   ENTRENAR MODELOS.
    ///
    /// LA WEB LLAMA EN NOMBRE DE LA PERSONA
    ///   La pantalla Experimentos pasa por `Services` con la clave de servicio
    ///   y los encabezados X-Sigma-Usuario / X-Sigma-Cliente; `Entrar()` arma
    ///   con eso la misma identidad que armaría un JWT —solo si la clave es
    ///   la correcta— y de ahí en adelante rigen SesionApi, Permisos y
    ///   ExigirPermiso igual que para la app. Es el mismo criterio con el que
    ///   `/archivo` confía en la web desde el 29-08, acotado a este controller.
    /// </summary>
    [RoutePrefix("sigma-ai")]
    public class SigmaAiController : ApiBase
    {
        /// <summary>El código del modelo de la petición (lo fija Entrar).</summary>
        private string _modelo = "SIGMA FAILURE 30D";

        private bool EsFalla  { get { return _modelo == "SIGMA FAILURE 30D"; } }
        private bool EsRul    { get { return _modelo == "SIGMA RUL"; } }
        private bool EsVision { get { return _modelo == "SIGMA VISION"; } }

        /// <summary>FALLA | RUL | VISION (o el código completo) → código del catálogo.</summary>
        private static string CodigoModelo(string modelo)
        {
            string m = (modelo ?? "").Trim().ToUpperInvariant();
            if (m == "" || m == "FALLA" || m == "FAILURE" || m == "SIGMA FAILURE 30D") return "SIGMA FAILURE 30D";
            if (m == "RUL" || m == "SIGMA RUL") return "SIGMA RUL";
            if (m == "VISION" || m == "SIGMA VISION") return "SIGMA VISION";
            throw new ArgumentException("Modelo desconocido: '" + modelo + "'. Use FALLA, RUL o VISION.");
        }

        /* ====================================================================
           ESTADO Y CATALOGO
           ==================================================================== */

        /// <summary>
        /// GET /sigma-ai/estado?modelo= — el modelo, su versión publicada, cuánto
        /// hay para entrenar y si Azure ML está configurado (sin secretos).
        /// </summary>
        [HttpGet]
        [Route("estado")]
        public IHttpActionResult Estado(string modelo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();

                List<MlModeloDto> m = Datos.Listar<MlModeloDto>("API_SEL_ML", Parametros(1));
                MlModeloDto md = m.Count > 0 ? m[0] : null;

                return Ok(new
                {
                    modelo = md,
                    caracteristicas = Datos.Listar<MlCaracteristicaDto>("API_SEL_ML", Parametros(6)),
                    azure = new
                    {
                        configurado = AzureMl.Configurado,
                        faltantes = AzureMl.Faltantes(),
                        artefactos = AzureMl.ArtefactosDisponibles,
                        workspace = AzureMl.Workspace,
                        region = AzureMl.Region,
                        mlflow = AzureMl.MlflowUri,
                        customVision = CustomVision.Configurado
                    },
                    puedeEntrenar = Permisos.Tiene("ENTRENAR MODELOS"),
                    servidorUtc = DateTime.UtcNow
                });
            });
        }

        /* ====================================================================
           EL DATASET
           ==================================================================== */

        /// <summary>
        /// GET /sigma-ai/dataset?modelo=&desde=&hasta=&paso=7&formato=json|csv
        /// Las filas que se entrenan. Con formato=csv baja el archivo que lee
        /// el entrenador.
        /// </summary>
        [HttpGet]
        [Route("dataset")]
        public IHttpActionResult Dataset(string modelo = null, string desde = null, string hasta = null, int paso = 7, string formato = "json", int? activo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();

                List<Dictionary<string, object>> filas = Filas(desde, hasta, paso, false, activo);

                if (string.Equals(formato, "csv", StringComparison.OrdinalIgnoreCase))
                {
                    string csv = Csv(filas);
                    HttpResponseMessage r = new HttpResponseMessage(HttpStatusCode.OK);
                    r.Content = new StringContent(csv, new UTF8Encoding(true), "text/csv");
                    r.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
                    {
                        FileName = Prefijo().ToLowerInvariant() + "_" + DateTime.UtcNow.ToString("yyyyMMdd_HHmm") + ".csv"
                    };
                    return ResponseMessage(r);
                }

                return Ok(new { modelo = _modelo, filas = filas.Count, positivas = Positivas(filas), etiquetadas = Etiquetadas(filas), datos = filas });
            });
        }

        /// <summary>
        /// POST /sigma-ai/datasets?modelo= — arma el dataset y lo deja registrado
        /// con su huella (SHA-256 del CSV), para que la versión que salga de él
        /// diga exactamente con qué se entrenó.
        /// </summary>
        [HttpPost]
        [Route("datasets")]
        public IHttpActionResult RegistrarDataset(MlDatasetNuevoDto dto, string modelo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("ENTRENAR MODELOS");
                ExigirCliente();
                if (dto == null) dto = new MlDatasetNuevoDto();

                int paso = dto.paso_dias ?? 7;
                List<Dictionary<string, object>> filas = Filas(dto.desde, dto.hasta, paso, false, null);

                if (filas.Count == 0)
                    throw new ArgumentException("El rango no produce ninguna fila: no hay historial anterior a esos cortes para " + _modelo + ".");

                string csv = Csv(filas);
                string hash = Sha256(csv);
                int positivas = Positivas(filas);

                DateTime primera = (DateTime)filas[0]["CORTE"];
                DateTime ultima = (DateTime)filas[filas.Count - 1]["CORTE"];

                string codigo = string.IsNullOrEmpty(dto.codigo)
                    ? Prefijo() + "-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmm")
                    : dto.codigo.Trim();
                string nombre = string.IsNullOrEmpty(dto.nombre)
                    ? _modelo + " · " + primera.ToString("yyyy-MM-dd") + " a " + ultima.ToString("yyyy-MM-dd") + " cada " + paso + " días"
                    : dto.nombre.Trim();

                int id = Datos.Ejecutar("API_INS_ML_DATASET", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@USUARIO", SesionApi.UsuarioId() },
                    { "@MODELO", _modelo },
                    { "@CODIGO", codigo },
                    { "@NOMBRE", nombre },
                    { "@DESDE", primera.Date },
                    { "@HASTA", ultima.Date },
                    { "@FILAS", filas.Count },
                    { "@POSITIVAS", positivas },
                    { "@HASH", hash },
                    { "@RUTA", "sigma-ai/dataset?modelo=" + Clave() + "&desde=" + primera.ToString("yyyy-MM-dd") + "&hasta=" + ultima.ToString("yyyy-MM-dd") + "&paso=" + paso + "&formato=csv" },
                    { "@OBSERVACION", dto.observacion }
                }, true);

                return Creado(id, new
                {
                    id = id, modelo = _modelo, codigo = codigo, nombre = nombre, filas = filas.Count, positivas = positivas,
                    etiquetadas = Etiquetadas(filas), hash = hash,
                    desde = primera.ToString("yyyy-MM-dd"), hasta = ultima.ToString("yyyy-MM-dd"), paso_dias = paso
                });
            });
        }

        [HttpGet]
        [Route("datasets")]
        public IHttpActionResult Datasets(string modelo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                return Ok(Datos.Listar<MlDatasetDto>("API_SEL_ML", Parametros(2)));
            });
        }

        /* ====================================================================
           ENTRENAMIENTOS Y VERSIONES
           ==================================================================== */

        [HttpGet]
        [Route("entrenamientos")]
        public IHttpActionResult Entrenamientos(string modelo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                return Ok(Datos.Listar<MlEjecucionDto>("API_SEL_ML", Parametros(3)));
            });
        }

        /// <summary>
        /// POST /sigma-ai/entrenamientos?modelo= — lo que el entrenador informa al
        /// terminar: la corrida (métricas, dónde corrió, cuánto tardó) y, si
        /// produjo modelo, la versión con sus pesos. Queda en BORRADOR.
        /// </summary>
        [HttpPost]
        [Route("entrenamientos")]
        public IHttpActionResult RegistrarEntrenamiento(MlEntrenamientoNuevoDto dto, string modelo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("ENTRENAR MODELOS");
                ExigirCliente();
                ExigirCuerpo(dto);

                int estado = dto.estado ?? 3;
                if (dto.version == null && estado == 3)
                    throw new ArgumentException("Un entrenamiento PROCESADO tiene que traer la versión que produjo; si falló, mándelo con estado 4 y el mensaje.");

                int ejecucion = Datos.Ejecutar("API_INS_ML_ENTRENAMIENTO", new Dictionary<string, object>
                {
                    { "@USUARIO", SesionApi.UsuarioId() },
                    { "@MODELO", _modelo },
                    { "@DATASET", dto.dataset },
                    { "@ENTORNO", dto.entorno },
                    { "@ESTADO", estado },
                    { "@SEGUNDOS", dto.segundos },
                    { "@METRICA", Json(dto.metrica) },
                    { "@MENSAJE", dto.mensaje }
                }, true);

                int? version = null;

                if (dto.version != null && estado == 3)
                {
                    string parametro = Json(dto.version.parametro);
                    ExigirTexto(parametro, "version.parametro");
                    ExigirTexto(dto.version.algoritmo, "version.algoritmo");

                    /* Se prueba a puntuar con los pesos ANTES de guardarlos: una
                       versión que no se puede leer no sirve publicada. */
                    ProbarPesos(parametro);

                    version = Datos.Ejecutar("API_INS_ML_MODELO_VERSION", new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@MODELO", _modelo },
                        { "@DATASET", dto.dataset },
                        { "@EJECUCION", ejecucion },
                        { "@FORMATO", string.IsNullOrEmpty(dto.version.formato) ? "ONNX" : dto.version.formato },
                        { "@ALGORITMO", dto.version.algoritmo },
                        { "@HIPERPARAMETRO", Json(dto.version.hiperparametro) },
                        { "@PARAMETRO", parametro },
                        { "@RUTA", dto.version.ruta },
                        { "@REGISTRO", dto.version.registro },
                        { "@HASH", dto.version.hash },
                        { "@BYTE", dto.version.bytes },
                        { "@AUC", dto.version.auc },
                        { "@PRECISION", dto.version.precision },
                        { "@RECALL", dto.version.recall },
                        { "@F1", dto.version.f1 },
                        { "@MAE", dto.version.mae },
                        { "@OBSERVACION", dto.version.observacion }
                    }, true);
                }

                return Creado(ejecucion, new { id = ejecucion, version = version });
            });
        }

        [HttpGet]
        [Route("versiones")]
        public IHttpActionResult Versiones(string modelo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                return Ok(Datos.Listar<MlVersionDto>("API_SEL_ML", Parametros(4)));
            });
        }

        /// <summary>POST /sigma-ai/versiones/{id}/publicar — la deja vigente y retira la anterior.</summary>
        [HttpPost]
        [Route("versiones/{id:int}/publicar")]
        public IHttpActionResult Publicar(int id)
        {
            return Ejecutar(() =>
            {
                Entrar(null);
                ExigirPermiso("ENTRENAR MODELOS");
                ExigirCliente();

                Datos.Ejecutar("API_UPD_ML_MODELO_VERSION_PUBLICAR", new Dictionary<string, object>
                {
                    { "@ID", id },
                    { "@USUARIO", SesionApi.UsuarioId() }
                });

                return Ok(new { id = id, estado = "PUBLICADO" });
            });
        }

        /* ====================================================================
           PUNTUAR
           ==================================================================== */

        /// <summary>
        /// POST /sigma-ai/predecir?modelo= — puntúa hoy, con la versión
        /// publicada, a todos los sujetos del cliente (o a los de un equipo), y
        /// guarda cada predicción con sus características, sus razones y la
        /// alerta si corresponde.
        /// </summary>
        [HttpPost]
        [Route("predecir")]
        public IHttpActionResult Predecir(MlPredecirDto dto, string modelo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("ENTRENAR MODELOS");
                ExigirCliente();
                if (dto == null) dto = new MlPredecirDto();
                if (EsVision)
                    throw new ArgumentException("SIGMA VISION no se puntúa por lote: use POST /sigma-ai/vision/clasificar con una imagen.");

                MlModeloDto md = Modelo();
                if (md.VERSION_ID == null)
                    throw new ArgumentException("No hay una versión publicada de " + _modelo + ": entrene y publique una antes de puntuar.");

                List<Dictionary<string, object>> hoy = Filas(null, null, 7, true, dto.activo);
                List<object> resultado = new List<object>();

                if (EsRul)
                {
                    PuntuadorRul puntuador = new PuntuadorRul(md.VERSION_PARAMETRO);
                    foreach (Dictionary<string, object> fila in hoy)
                    {
                        Dictionary<string, double> valores = PuntuadorFalla.Valores(fila);
                        PuntuadorRul.Resultado r = puntuador.Puntuar(valores);
                        List<object> caracteristicas = Caracteristicas(puntuador.Caracteristicas, valores);
                        List<object> explicaciones = Explicaciones(r.contribuciones);

                        int id = Datos.Ejecutar("API_INS_PREDICCION_RUL", new Dictionary<string, object>
                        {
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@USUARIO", SesionApi.UsuarioId() },
                            { "@VERSION", md.VERSION_ID },
                            { "@INSTALACION", Convert.ToInt32(fila["INSTALACION"]) },
                            { "@DIAS", Math.Round((decimal)r.dias, 2) },
                            { "@DIAS_INFERIOR", Math.Round((decimal)r.diasInferior, 2) },
                            { "@DIAS_SUPERIOR", Math.Round((decimal)r.diasSuperior, 2) },
                            { "@CONFIANZA", (decimal)r.confianza },
                            { "@CARACTERISTICAS", JsonConvert.SerializeObject(caracteristicas) },
                            { "@EXPLICACIONES", JsonConvert.SerializeObject(explicaciones) }
                        }, true);

                        resultado.Add(new
                        {
                            prediccion = id,
                            instalacion = Convert.ToInt32(fila["INSTALACION"]),
                            activo = Convert.ToInt32(fila["ACTIVO"]),
                            codigo = fila["ACTIVO_CODIGO"],
                            nombre = fila["REPUESTO_CODIGO"] + " " + fila["REPUESTO_NOMBRE"] + " en " + fila["COMPONENTE_CODIGO"] + " " + fila["COMPONENTE_NOMBRE"],
                            dias = Math.Round(r.dias, 1),
                            diasInferior = Math.Round(r.diasInferior, 1),
                            diasSuperior = Math.Round(r.diasSuperior, 1),
                            fechaEstimada = DateTime.UtcNow.AddDays(r.dias).ToString("yyyy-MM-dd"),
                            probabilidad = (double?)null,
                            explicaciones = explicaciones
                        });
                    }
                    resultado.Sort((a, b) => ((double)Propiedad(a, "dias")).CompareTo((double)Propiedad(b, "dias")));
                }
                else
                {
                    PuntuadorFalla puntuador = new PuntuadorFalla(md.VERSION_PARAMETRO);
                    foreach (Dictionary<string, object> fila in hoy)
                    {
                        Dictionary<string, double> valores = PuntuadorFalla.Valores(fila);
                        PuntuadorFalla.Resultado r = puntuador.Puntuar(valores);
                        List<object> caracteristicas = Caracteristicas(puntuador.Caracteristicas, valores);
                        List<object> explicaciones = Explicaciones(r.contribuciones);

                        int id = Datos.Ejecutar("API_INS_PREDICCION_FALLA", new Dictionary<string, object>
                        {
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@USUARIO", SesionApi.UsuarioId() },
                            { "@VERSION", md.VERSION_ID },
                            { "@ACTIVO", Convert.ToInt32(fila["ACTIVO"]) },
                            { "@PROBABILIDAD", Math.Round((decimal)r.probabilidad, 6) },
                            { "@CARACTERISTICAS", JsonConvert.SerializeObject(caracteristicas) },
                            { "@EXPLICACIONES", JsonConvert.SerializeObject(explicaciones) }
                        }, true);

                        resultado.Add(new
                        {
                            prediccion = id,
                            activo = Convert.ToInt32(fila["ACTIVO"]),
                            codigo = fila["ACTIVO_CODIGO"],
                            nombre = fila["ACTIVO_NOMBRE"],
                            probabilidad = Math.Round(r.probabilidad, 4),
                            explicaciones = explicaciones
                        });
                    }
                    resultado.Sort((a, b) => ((double)Propiedad(b, "probabilidad")).CompareTo((double)Propiedad(a, "probabilidad")));
                }

                return Ok(new { modelo = _modelo, version = md.VERSION_NUMERO, equipos = resultado.Count, predicciones = resultado });
            });
        }

        /// <summary>
        /// POST /sigma-ai/simular?modelo= — "¿qué diría el modelo si…?": puntúa
        /// valores escritos a mano con la versión publicada, sin guardar nada.
        /// </summary>
        [HttpPost]
        [Route("simular")]
        public IHttpActionResult Simular(MlSimularDto dto, string modelo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                ExigirCuerpo(dto);
                if (dto.valores == null) throw new ArgumentException("Faltan los valores.");

                MlModeloDto md = Modelo();
                if (md.VERSION_ID == null)
                    throw new ArgumentException("No hay una versión publicada de " + _modelo + ".");

                Dictionary<string, double> v = new Dictionary<string, double>(dto.valores, StringComparer.OrdinalIgnoreCase);

                if (EsRul)
                {
                    PuntuadorRul.Resultado r = new PuntuadorRul(md.VERSION_PARAMETRO).Puntuar(v);
                    return Ok(new { modelo = _modelo, version = md.VERSION_NUMERO, dias = Math.Round(r.dias, 1), diasInferior = Math.Round(r.diasInferior, 1),
                                    diasSuperior = Math.Round(r.diasSuperior, 1), contribuciones = r.contribuciones });
                }

                PuntuadorFalla.Resultado f = new PuntuadorFalla(md.VERSION_PARAMETRO).Puntuar(v);
                return Ok(new { modelo = _modelo, version = md.VERSION_NUMERO, probabilidad = Math.Round(f.probabilidad, 4), logit = Math.Round(f.logit, 4), contribuciones = f.contribuciones });
            });
        }

        [HttpGet]
        [Route("predicciones")]
        public IHttpActionResult Predicciones(string modelo = null)
        {
            return Ejecutar(() =>
            {
                Entrar(modelo);
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                return Ok(Datos.Listar<MlPrediccionDto>("API_SEL_ML", Parametros(5)));
            });
        }

        /* ====================================================================
           SIGMA VISION (bloque 248): Custom Vision predice, la API guarda
           ==================================================================== */

        /// <summary>
        /// POST /sigma-ai/vision/clasificar — { archivo } (un archivo del
        /// cliente, que la API baja del almacenamiento) o { imagen_base64,
        /// nombre, mime } (una imagen suelta, solo para probar). Devuelve las
        /// etiquetas con su probabilidad y, si era un archivo registrado, deja
        /// la revisión visual SIN confirmar.
        /// </summary>
        [HttpPost]
        [Route("vision/clasificar")]
        public IHttpActionResult Clasificar(MlClasificarDto dto)
        {
            return Ejecutar(() =>
            {
                Entrar("VISION");
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                ExigirCuerpo(dto);

                if (!CustomVision.Configurado)
                    throw new ArgumentException("SIGMA VISION no está configurado: faltan " + string.Join(", ", CustomVision.Faltantes()) + " en el Web.config de la API.");

                byte[] imagen;
                string nombre = dto.nombre;

                if (dto.archivo != null)
                {
                    List<ArchivoIdDto> a = Datos.Listar<ArchivoIdDto>("API_SEL_ARCHIVO_ID", new Dictionary<string, object>
                    {
                        { "@ID", dto.archivo }, { "@CLIENTE", SesionApi.ClienteId() }
                    });
                    if (a.Count == 0) throw new ArgumentException("El archivo " + dto.archivo + " no existe para el cliente en sesión.");
                    if (string.IsNullOrEmpty(a[0].ARC_MIME) || !a[0].ARC_MIME.StartsWith("image/"))
                        throw new ArgumentException("El archivo " + dto.archivo + " no es una imagen (" + a[0].ARC_MIME + ").");
                    imagen = new API.Services.BlobService().Descargar(a[0].ARC_RUTA);
                    nombre = a[0].ARC_NOMBRE;
                }
                else
                {
                    ExigirTexto(dto.imagen_base64, "imagen_base64");
                    try { imagen = Convert.FromBase64String(dto.imagen_base64); }
                    catch (FormatException) { throw new ArgumentException("imagen_base64 no es base64 válido."); }
                    if (imagen.Length > 4 * 1024 * 1024) throw new ArgumentException("La imagen supera los 4 MB que acepta Custom Vision.");
                }

                System.Diagnostics.Stopwatch reloj = System.Diagnostics.Stopwatch.StartNew();
                List<CustomVision.Etiqueta> etiquetas = CustomVision.Clasificar(imagen);
                reloj.Stop();

                MlModeloDto md = Modelo();
                string version = md.VERSION_NUMERO != null ? "v" + md.VERSION_NUMERO + " · " + CustomVision.Iteracion : CustomVision.Iteracion;

                int revision = 0;
                if (dto.archivo != null)
                    revision = Datos.Ejecutar("API_INS_ANALISIS_VISUAL", new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@ARCHIVO", dto.archivo },
                        { "@MOTOR", "SIGMA VISION (Azure Custom Vision)" },
                        { "@VERSION", version },
                        { "@MILISEGUNDOS", (int)reloj.ElapsedMilliseconds },
                        { "@ETIQUETAS", JsonConvert.SerializeObject(etiquetas) },
                        { "@MENSAJE", "Clasificada desde la API; sin confirmar." }
                    }, true);

                return Ok(new
                {
                    modelo = _modelo, iteracion = CustomVision.Iteracion, version = md.VERSION_NUMERO,
                    archivo = dto.archivo, nombre = nombre, milisegundos = reloj.ElapsedMilliseconds,
                    revision = revision > 0 ? (int?)revision : null,
                    etiquetas = etiquetas
                });
            });
        }

        /// <summary>
        /// POST /sigma-ai/vision/confirmar — { deteccion, etiqueta? }: una
        /// persona confirma (o corrige) lo que dijo el modelo. Es lo que
        /// alimenta el próximo dataset.
        /// </summary>
        [HttpPost]
        [Route("vision/confirmar")]
        public IHttpActionResult ConfirmarDeteccion(MlConfirmarDto dto)
        {
            return Ejecutar(() =>
            {
                Entrar("VISION");
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                ExigirCuerpo(dto);
                if (dto.deteccion <= 0) throw new ArgumentException("Falta la detección.");

                Datos.Ejecutar("API_UPD_ANALISIS_VISUAL_CONFIRMAR", new Dictionary<string, object>
                {
                    { "@ID", dto.deteccion }, { "@CLIENTE", SesionApi.ClienteId() }, { "@USUARIO", SesionApi.UsuarioId() }, { "@ETIQUETA", dto.etiqueta }
                });
                return Ok(new { deteccion = dto.deteccion, confirmada = true, etiqueta = dto.etiqueta });
            });
        }

        private class ArchivoIdDto
        {
            public int ARC_ID { get; set; }
            public string ARC_RUTA { get; set; }
            public string ARC_MIME { get; set; }
            public string ARC_NOMBRE { get; set; }
        }

        /* ====================================================================
           LO QUE HAY EN AZURE ML (plano de control: exige entidad de servicio)
           ==================================================================== */

        /// <summary>GET /sigma-ai/azure — el área de trabajo, o por qué no se puede leer.</summary>
        [HttpGet]
        [Route("azure")]
        public IHttpActionResult Azure()
        {
            return Ejecutar(() =>
            {
                Entrar(null);
                ExigirPermiso("VER PREDICCIONES");

                object artefactos = new
                {
                    disponible = AzureMl.ArtefactosDisponibles,
                    contenedor = AzureMl.ContenedorArtefactos,
                    mensaje = AzureMl.ArtefactosDisponibles
                        ? "La API lee los artefactos registrados por el almacenamiento del área de trabajo (SAS del módulo de archivos), sin entidad de servicio."
                        : "Sin SAS del almacenamiento no se pueden leer los artefactos."
                };

                if (!AzureMl.Configurado)
                    return Ok(new { configurado = false, faltantes = AzureMl.Faltantes(), artefactos = artefactos, customVision = CustomVision.Configurado,
                                    mensaje = "El plano de control de Azure ML (experimentos, corridas) no está configurado en el Web.config de la API." });

                return Ok(new { configurado = true, area = AzureMl.AreaTrabajo(), mlflow = AzureMl.MlflowUri, artefactos = artefactos, customVision = CustomVision.Configurado });
            });
        }

        [HttpGet]
        [Route("azure/modelos")]
        public IHttpActionResult AzureModelos(string nombre = null)
        {
            return Ejecutar(() =>
            {
                Entrar(null);
                ExigirPermiso("VER PREDICCIONES");
                if (!AzureMl.Configurado) return Ok(new { configurado = false, faltantes = AzureMl.Faltantes() });
                if (!string.IsNullOrEmpty(nombre)) return Ok(new { configurado = true, modelo = nombre, versiones = AzureMl.Versiones(nombre) });
                return Ok(new { configurado = true, modelos = AzureMl.Modelos() });
            });
        }

        [HttpGet]
        [Route("azure/experimentos")]
        public IHttpActionResult AzureExperimentos(string id = null)
        {
            return Ejecutar(() =>
            {
                Entrar(null);
                ExigirPermiso("VER PREDICCIONES");
                if (!AzureMl.Configurado) return Ok(new { configurado = false, faltantes = AzureMl.Faltantes() });
                if (!string.IsNullOrEmpty(id)) return Ok(new { configurado = true, experimento = id, corridas = AzureMl.Corridas(id) });
                return Ok(new { configurado = true, experimentos = AzureMl.Experimentos() });
            });
        }

        /* ====================================================================
           EL ARTEFACTO REGISTRADO EN AZURE ML (bloque 246)
           ==================================================================== */

        /// <summary>
        /// GET /sigma-ai/versiones/{id}/artefactos — baja del área de trabajo
        /// los archivos del modelo registrado, compara el SHA-256 del .onnx
        /// con el que informó el entrenador y los pesos del JSON con los de
        /// la versión. Si el hash coincide deja constancia
        /// (mpv_fecha_verificacion_utc).
        /// </summary>
        [HttpGet]
        [Route("versiones/{id:int}/artefactos")]
        public IHttpActionResult Artefactos(int id)
        {
            return Ejecutar(() =>
            {
                Entrar(null);
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();

                Verificacion v = Verificar(id);

                if (v.hashCoincide)
                    Datos.Ejecutar("API_UPD_ML_MODELO_VERSION_ARTEFACTO", new Dictionary<string, object>
                    {
                        { "@ID", id }, { "@USUARIO", SesionApi.UsuarioId() }, { "@HASH", v.hashAzure }, { "@BYTE", v.bytesOnnx }
                    });

                return Ok(v);
            });
        }

        /// <summary>
        /// POST /sigma-ai/versiones/{id}/sincronizar — toma los pesos desde
        /// el JSON que acompaña al artefacto en Azure ML y los deja en la
        /// versión. Solo si el .onnx de Azure es el que informó el
        /// entrenador (mismo hash): con eso "Azure ML entrega el modelo".
        /// </summary>
        [HttpPost]
        [Route("versiones/{id:int}/sincronizar")]
        public IHttpActionResult Sincronizar(int id)
        {
            return Ejecutar(() =>
            {
                Entrar(null);
                ExigirPermiso("ENTRENAR MODELOS");
                ExigirCliente();

                Verificacion v = Verificar(id);

                if (!v.hashCoincide)
                    throw new ArgumentException("El .onnx registrado en Azure ML no coincide con el que informó el entrenador (" +
                                                Corto(v.hashAzure) + " vs " + Corto(v.hashVersion) + "): no se toman sus pesos.");
                if (string.IsNullOrEmpty(v.parametrosAzure))
                    throw new ArgumentException("El artefacto de Azure ML no trae el JSON de pesos.");

                // Se prueba a puntuar con esos pesos antes de guardarlos.
                new PuntuadorFalla(v.parametrosAzure);

                Datos.Ejecutar("API_UPD_ML_MODELO_VERSION_ARTEFACTO", new Dictionary<string, object>
                {
                    { "@ID", id }, { "@USUARIO", SesionApi.UsuarioId() }, { "@HASH", v.hashAzure }, { "@BYTE", v.bytesOnnx },
                    { "@PARAMETRO", v.parametrosAzure },
                    { "@OBSERVACION", "Pesos tomados del artefacto de Azure ML el " + DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm") + " UTC." }
                });

                v.pesosCoinciden = true;
                return Ok(v);
            });
        }

        /// <summary>Lo que se le cuenta a la pantalla sobre el artefacto.</summary>
        public class Verificacion
        {
            public int version { get; set; }
            public string registro { get; set; }
            public string rutaAzure { get; set; }
            public string rutaBlob { get; set; }
            public List<object> archivos { get; set; }
            public string hashVersion { get; set; }
            public string hashAzure { get; set; }
            public long? bytesOnnx { get; set; }
            public bool hashCoincide { get; set; }
            public bool pesosCoinciden { get; set; }
            public string mensaje { get; set; }
            [JsonIgnore] public string parametrosAzure { get; set; }
        }

        private Verificacion Verificar(int id)
        {
            if (!AzureMl.ArtefactosDisponibles)
                throw new ArgumentException("La API no tiene acceso al almacenamiento del área de trabajo (AzureBlobSas).");

            MlVersionDto ver = VersionPorId(id);

            Verificacion v = new Verificacion
            {
                version = ver.mpv_numero, registro = ver.mpv_registro, rutaAzure = ver.mpv_ruta,
                hashVersion = ver.mpv_hash, archivos = new List<object>()
            };

            v.rutaBlob = AzureMl.RutaBlob(ver.mpv_ruta);
            if (v.rutaBlob == null)
            {
                v.mensaje = string.IsNullOrEmpty(ver.mpv_ruta)
                    ? "Esta versión no tiene artefacto en Azure ML (se entrenó sin registrar)."
                    : "La ruta de la versión no es de un datastore del área de trabajo: " + ver.mpv_ruta;
                return v;
            }

            API.Services.BlobService blob = new API.Services.BlobService();
            int corte = v.rutaBlob.IndexOf('/');
            string contenedor = v.rutaBlob.Substring(0, corte);
            string prefijo = v.rutaBlob.Substring(corte + 1).TrimEnd('/') + "/";

            List<API.Services.ContenidoBlob> blobs = blob.Listar(contenedor, prefijo);
            if (blobs.Count == 0)
            {
                v.mensaje = "En Azure ML no hay archivos bajo " + v.rutaBlob + ".";
                return v;
            }

            foreach (API.Services.ContenidoBlob b in blobs)
            {
                string nombre = b.nombre.Substring(prefijo.Length);
                string hash = null;

                if (nombre.EndsWith(".onnx", StringComparison.OrdinalIgnoreCase))
                {
                    byte[] onnx = blob.Descargar(contenedor + "/" + b.nombre);
                    hash = API.Services.BlobService.Hash(onnx);
                    v.hashAzure = hash;
                    v.bytesOnnx = onnx.LongLength;
                }
                else if (nombre.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
                {
                    byte[] json = blob.Descargar(contenedor + "/" + b.nombre);
                    hash = API.Services.BlobService.Hash(json);
                    try
                    {
                        Newtonsoft.Json.Linq.JObject j = Newtonsoft.Json.Linq.JObject.Parse(Encoding.UTF8.GetString(json));
                        Newtonsoft.Json.Linq.JToken par = j["parametros"] ?? j;
                        if (par["coeficientes"] != null)
                        {
                            v.parametrosAzure = par.ToString(Newtonsoft.Json.Formatting.None);
                            v.pesosCoinciden = MismosPesos(v.parametrosAzure, ver.mpv_parametro);
                        }
                    }
                    catch (Exception) { /* un JSON que no es de pesos: se lista igual */ }
                }

                v.archivos.Add(new { nombre = nombre, bytes = b.tamano, modificado = b.modificado, sha256 = hash });
            }

            v.hashCoincide = v.hashAzure != null && (string.IsNullOrEmpty(v.hashVersion) ||
                             string.Equals(v.hashAzure, v.hashVersion, StringComparison.OrdinalIgnoreCase));
            v.mensaje = v.hashAzure == null ? "El artefacto no trae un .onnx."
                      : v.hashCoincide ? "El .onnx de Azure ML es el que informó el entrenador (SHA-256 igual)."
                      : "El .onnx de Azure ML NO es el que informó el entrenador.";
            return v;
        }

        /// <summary>Los coeficientes e intercepto, comparados con tolerancia.</summary>
        private static bool MismosPesos(string a, string b)
        {
            if (string.IsNullOrEmpty(a) || string.IsNullOrEmpty(b)) return false;
            try
            {
                PuntuadorFalla.Parametros pa = JsonConvert.DeserializeObject<PuntuadorFalla.Parametros>(a);
                PuntuadorFalla.Parametros pb = JsonConvert.DeserializeObject<PuntuadorFalla.Parametros>(b);
                if (pa.coeficientes.Count != pb.coeficientes.Count) return false;
                if (Math.Abs(pa.intercepto - pb.intercepto) > 1e-9) return false;
                for (int i = 0; i < pa.coeficientes.Count; i++)
                    if (Math.Abs(pa.coeficientes[i] - pb.coeficientes[i]) > 1e-9) return false;
                return true;
            }
            catch (Exception) { return false; }
        }

        private static string Corto(string hash)
        {
            return string.IsNullOrEmpty(hash) ? "(sin hash)" : hash.Substring(0, Math.Min(12, hash.Length)) + "…";
        }

        /* ====================================================================
           AYUDAS
           ==================================================================== */

        /// <summary>
        /// La identidad y el modelo de la petición. Con JWT la identidad ya
        /// viene puesta por el handler; sin JWT se acepta la que delega la web
        /// con la clave de servicio (ver ClaveServicio). Si no hay ninguna,
        /// ExigirPermiso responde lo de siempre: "inicie sesión".
        /// </summary>
        private void Entrar(string modelo)
        {
            _modelo = CodigoModelo(modelo);

            if (SesionApi.HayUsuario()) return;

            ClaimsPrincipal delegada = ClaveServicio.SesionDelegada(Request);
            if (delegada == null) return;

            Thread.CurrentPrincipal = delegada;
            if (HttpContext.Current != null) HttpContext.Current.User = delegada;
        }

        /// <summary>FALLA / RUL / VISION, para armar rutas.</summary>
        private string Clave()
        {
            return EsRul ? "RUL" : (EsVision ? "VISION" : "FALLA");
        }

        /// <summary>El prefijo de los códigos de dataset.</summary>
        private string Prefijo()
        {
            return EsRul ? "RUL" : (EsVision ? "VISION" : "FALLA30");
        }

        private Dictionary<string, object> Parametros(int tipo, int? id = null)
        {
            return new Dictionary<string, object>
            {
                { "@CLIENTE", SesionApi.ClienteId() },
                { "@USUARIO", SesionApi.UsuarioId() },
                { "@TIPO", tipo },
                { "@MODELO", _modelo },
                { "@ID", id }
            };
        }

        private MlModeloDto Modelo()
        {
            List<MlModeloDto> m = Datos.Listar<MlModeloDto>("API_SEL_ML", Parametros(1));
            if (m.Count == 0) throw new ArgumentException("El modelo " + _modelo + " no está registrado: aplique los bloques 245/247/248.");
            return m[0];
        }

        /// <summary>Una versión por id, sea del modelo que sea (los artefactos no saben de modelos).</summary>
        private MlVersionDto VersionPorId(int id)
        {
            string original = _modelo;
            try
            {
                foreach (string codigo in new[] { "SIGMA FAILURE 30D", "SIGMA RUL", "SIGMA VISION" })
                {
                    _modelo = codigo;
                    List<MlVersionDto> lista = Datos.Listar<MlVersionDto>("API_SEL_ML", Parametros(4, id));
                    if (lista.Count > 0) return lista[0];
                }
            }
            finally { _modelo = original; }

            throw new ArgumentException("La versión " + id + " no existe.");
        }

        /// <summary>Que los pesos se puedan leer con el puntuador del modelo.</summary>
        private void ProbarPesos(string parametro)
        {
            if (EsRul) new PuntuadorRul(parametro);
            else if (EsFalla) new PuntuadorFalla(parametro);
            /* VISION: los pesos viven en Custom Vision; el JSON es descriptivo. */
        }

        private List<Dictionary<string, object>> Filas(string desde, string hasta, int paso, bool hoy, int? activo)
        {
            Dictionary<string, object> p = new Dictionary<string, object>
            {
                { "@CLIENTE", SesionApi.ClienteId() },
                { "@USUARIO", SesionApi.UsuarioId() },
                { "@DESDE", Fecha(desde, "desde") },
                { "@HASTA", Fecha(hasta, "hasta") },
                { "@PASO_DIAS", paso < 1 ? 7 : paso },
                { "@HOY", hoy },
                { "@ACTIVO", activo }
            };
            string sp = EsRul ? "API_SEL_ML_DATASET_RUL" : (EsVision ? "API_SEL_ML_DATASET_VISION" : "API_SEL_ML_DATASET_FALLA");
            return Datos.Filas(Datos.Conjunto(sp, p), 0);
        }

        private static object Fecha(string texto, string campo)
        {
            if (string.IsNullOrEmpty(texto)) return null;
            DateTime f;
            if (!DateTime.TryParseExact(texto, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f))
                throw new ArgumentException("La fecha '" + campo + "' debe venir como yyyy-MM-dd.");
            return f;
        }

        /// <summary>
        /// "Positivas" según el modelo: FALLA = falló en 30 d; RUL = retiro
        /// observado (no censurado); VISION = imagen con etiqueta confirmada.
        /// </summary>
        private int Positivas(List<Dictionary<string, object>> filas)
        {
            int n = 0;
            foreach (Dictionary<string, object> f in filas)
            {
                if (EsRul) { if (f["CENSURADO"] != null && !Convert.ToBoolean(f["CENSURADO"])) n++; }
                else if (EsVision) { if (f.ContainsKey("ETIQUETA") && f["ETIQUETA"] != null) n++; }
                else if (f["FALLO_EN_30D"] != null && Convert.ToBoolean(f["FALLO_EN_30D"])) n++;
            }
            return n;
        }

        private int Etiquetadas(List<Dictionary<string, object>> filas)
        {
            int n = 0;
            foreach (Dictionary<string, object> f in filas)
            {
                if (EsRul) { if (f["DIAS_RESTANTES"] != null) n++; }
                else if (EsVision) { if (f.ContainsKey("ETIQUETA") && f["ETIQUETA"] != null) n++; }
                else if (f["FALLO_EN_30D"] != null) n++;
            }
            return n;
        }

        private static List<object> Caracteristicas(IList<string> codigos, Dictionary<string, double> valores)
        {
            List<object> lista = new List<object>();
            foreach (string c in codigos)
                if (valores.ContainsKey(c)) lista.Add(new { codigo = c, valor = valores[c] });
            return lista;
        }

        /// <summary>Las tres razones que más pesan, con frase.</summary>
        private static List<object> Explicaciones(List<PuntuadorFalla.Contribucion> contribuciones)
        {
            List<object> lista = new List<object>();
            foreach (PuntuadorFalla.Contribucion c in contribuciones)
            {
                if (c.texto == null || lista.Count >= 3) continue;
                lista.Add(new { codigo = c.codigo, texto = c.texto, contribucion = c.contribucion, direccion = c.direccion, observado = c.valor, referencia = c.referencia });
            }
            return lista;
        }

        /// <summary>CSV con punto decimal y fechas ISO: lo lee pandas sin configurar nada.</summary>
        private static string Csv(List<Dictionary<string, object>> filas)
        {
            StringBuilder sb = new StringBuilder();
            if (filas.Count == 0) return "";

            List<string> columnas = new List<string>(filas[0].Keys);
            sb.AppendLine(string.Join(",", columnas));

            foreach (Dictionary<string, object> f in filas)
            {
                List<string> celdas = new List<string>();
                foreach (string c in columnas)
                {
                    object v = f[c];
                    if (v == null) celdas.Add("");
                    else if (v is DateTime) celdas.Add(((DateTime)v).ToString("yyyy-MM-dd HH:mm:ss"));
                    else if (v is bool) celdas.Add((bool)v ? "1" : "0");
                    else if (v is string) celdas.Add("\"" + ((string)v).Replace("\"", "\"\"") + "\"");
                    else celdas.Add(Convert.ToString(v, CultureInfo.InvariantCulture));
                }
                sb.AppendLine(string.Join(",", celdas));
            }
            return sb.ToString();
        }

        private static string Sha256(string texto)
        {
            using (SHA256 sha = SHA256.Create())
            {
                byte[] h = sha.ComputeHash(Encoding.UTF8.GetBytes(texto));
                StringBuilder sb = new StringBuilder();
                foreach (byte b in h) sb.Append(b.ToString("x2"));
                return sb.ToString();
            }
        }

        private static string Json(object o)
        {
            if (o == null) return null;
            if (o is string) return (string)o;
            return JsonConvert.SerializeObject(o);
        }

        private static object Propiedad(object o, string nombre)
        {
            return o.GetType().GetProperty(nombre).GetValue(o, null);
        }
    }
}
