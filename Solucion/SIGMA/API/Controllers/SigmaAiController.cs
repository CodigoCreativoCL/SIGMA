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
    /// SIGMA AI · Investigación Azure Machine Learning.        SIGMA FAILURE 30D
    ///
    /// EL CAMINO COMPLETO, SIN COSTO
    ///   1. GET  /sigma-ai/dataset        el dataset (equipo × fecha de corte) que
    ///                                    arma la base con `FNC_ML_ACTIVO_HISTORICO_V1`:
    ///                                    características antes del corte, label después.
    ///   2. POST /sigma-ai/datasets       lo registra (filas, positivas, hash) para
    ///                                    que el entrenamiento sea reproducible.
    ///   3. (fuera)                       `ML/entrenar_falla.py` entrena en el equipo de
    ///                                    quien entrena, deja la corrida y el .onnx en
    ///                                    Azure ML (gratis: es registro, no cómputo) …
    ///   4. POST /sigma-ai/entrenamientos … y vuelve con las métricas y los pesos.
    ///   5. POST /sigma-ai/versiones/{id}/publicar
    ///   6. POST /sigma-ai/predecir       puntúa hoy con los pesos de la versión
    ///                                    publicada (`PuntuadorFalla`) y guarda en
    ///                                    `Prediccion`, con explicación y alerta.
    ///   7. GET  /sigma-ai/azure/*        lo que hay en Azure ML, leído con la
    ///                                    entidad de servicio, para contrastarlo.
    ///
    /// QUIEN PUEDE
    ///   Leer: VER PREDICCIONES. Registrar, entrenar, publicar y puntuar:
    ///   ENTRENAR MODELOS (jefatura y planificación).
    ///
    /// LA WEB LLAMA EN NOMBRE DE LA PERSONA
    ///   La pantalla Experimentos pasa por `Services` con la clave de servicio
    ///   y los encabezados X-Sigma-Usuario / X-Sigma-Cliente; `Entrar()` arma
    ///   con eso la misma identidad que armaría un JWT —solo si la clave es
    ///   la correcta— y de ahí en adelante rigen SesionApi, Permisos y
    ///   ExigirPermiso igual que para la app. La auditoría queda a nombre de
    ///   la persona, no de "la web". Es el mismo criterio con el que
    ///   `/archivo` confía en la web desde el 29-08, acotado a este
    ///   controller.
    /// </summary>
    [RoutePrefix("sigma-ai")]
    public class SigmaAiController : ApiBase
    {
        private const string MODELO = "SIGMA FAILURE 30D";

        /* ====================================================================
           ESTADO Y CATALOGO
           ==================================================================== */

        /// <summary>
        /// GET /sigma-ai/estado — el modelo, su versión publicada, cuánto hay
        /// para entrenar y si Azure ML está configurado (sin secretos).
        /// </summary>
        [HttpGet]
        [Route("estado")]
        public IHttpActionResult Estado()
        {
            return Ejecutar(() =>
            {
                Entrar();
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();

                List<MlModeloDto> m = Datos.Listar<MlModeloDto>("API_SEL_ML", Parametros(1));
                MlModeloDto modelo = m.Count > 0 ? m[0] : null;

                return Ok(new
                {
                    modelo = modelo,
                    caracteristicas = Datos.Listar<MlCaracteristicaDto>("API_SEL_ML", Parametros(6)),
                    azure = new
                    {
                        configurado = AzureMl.Configurado,
                        faltantes = AzureMl.Faltantes(),
                        workspace = AzureMl.Workspace,
                        region = AzureMl.Region,
                        mlflow = AzureMl.MlflowUri
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
        /// GET /sigma-ai/dataset?desde=&hasta=&paso=7&formato=json|csv
        /// Las filas que se entrenan. Con formato=csv baja el archivo que lee
        /// el entrenador. Sin fechas: desde el primer registro del cliente
        /// hasta hoy − 30, cada 7 días.
        /// </summary>
        [HttpGet]
        [Route("dataset")]
        public IHttpActionResult Dataset(string desde = null, string hasta = null, int paso = 7, string formato = "json", int? activo = null)
        {
            return Ejecutar(() =>
            {
                Entrar();
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
                        FileName = "sigma_failure_30d_" + DateTime.UtcNow.ToString("yyyyMMdd_HHmm") + ".csv"
                    };
                    return ResponseMessage(r);
                }

                int positivas = Positivas(filas);
                return Ok(new { filas = filas.Count, positivas = positivas, etiquetadas = Etiquetadas(filas), datos = filas });
            });
        }

        /// <summary>
        /// POST /sigma-ai/datasets — arma el dataset y lo deja registrado con
        /// su huella (SHA-256 del CSV), para que la versión que salga de él
        /// diga exactamente con qué se entrenó.
        /// </summary>
        [HttpPost]
        [Route("datasets")]
        public IHttpActionResult RegistrarDataset(MlDatasetNuevoDto dto)
        {
            return Ejecutar(() =>
            {
                Entrar();
                ExigirPermiso("ENTRENAR MODELOS");
                ExigirCliente();
                if (dto == null) dto = new MlDatasetNuevoDto();

                int paso = dto.paso_dias ?? 7;
                List<Dictionary<string, object>> filas = Filas(dto.desde, dto.hasta, paso, false, null);

                if (filas.Count == 0)
                    throw new ArgumentException("El rango no produce ninguna fila: no hay equipos con historial anterior a esos cortes.");

                string csv = Csv(filas);
                string hash = Sha256(csv);
                int positivas = Positivas(filas);

                DateTime primera = (DateTime)filas[0]["CORTE"];
                DateTime ultima = (DateTime)filas[filas.Count - 1]["CORTE"];

                string codigo = string.IsNullOrEmpty(dto.codigo)
                    ? "FALLA30-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmm")
                    : dto.codigo.Trim();
                string nombre = string.IsNullOrEmpty(dto.nombre)
                    ? "SIGMA FAILURE 30D · " + primera.ToString("yyyy-MM-dd") + " a " + ultima.ToString("yyyy-MM-dd") + " cada " + paso + " días"
                    : dto.nombre.Trim();

                int id = Datos.Ejecutar("API_INS_ML_DATASET", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@USUARIO", SesionApi.UsuarioId() },
                    { "@MODELO", MODELO },
                    { "@CODIGO", codigo },
                    { "@NOMBRE", nombre },
                    { "@DESDE", primera.Date },
                    { "@HASTA", ultima.Date },
                    { "@FILAS", filas.Count },
                    { "@POSITIVAS", positivas },
                    { "@HASH", hash },
                    { "@RUTA", "sigma-ai/dataset?desde=" + primera.ToString("yyyy-MM-dd") + "&hasta=" + ultima.ToString("yyyy-MM-dd") + "&paso=" + paso + "&formato=csv" },
                    { "@OBSERVACION", dto.observacion }
                }, true);

                return Creado(id, new
                {
                    id = id, codigo = codigo, nombre = nombre, filas = filas.Count, positivas = positivas,
                    etiquetadas = Etiquetadas(filas), hash = hash,
                    desde = primera.ToString("yyyy-MM-dd"), hasta = ultima.ToString("yyyy-MM-dd"), paso_dias = paso
                });
            });
        }

        [HttpGet]
        [Route("datasets")]
        public IHttpActionResult Datasets()
        {
            return Ejecutar(() =>
            {
                Entrar();
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
        public IHttpActionResult Entrenamientos()
        {
            return Ejecutar(() =>
            {
                Entrar();
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                return Ok(Datos.Listar<MlEjecucionDto>("API_SEL_ML", Parametros(3)));
            });
        }

        /// <summary>
        /// POST /sigma-ai/entrenamientos — lo que el entrenador informa al
        /// terminar: la corrida (métricas, dónde corrió, cuánto tardó) y, si
        /// produjo modelo, la versión con sus pesos. Queda en BORRADOR.
        /// </summary>
        [HttpPost]
        [Route("entrenamientos")]
        public IHttpActionResult RegistrarEntrenamiento(MlEntrenamientoNuevoDto dto)
        {
            return Ejecutar(() =>
            {
                Entrar();
                ExigirPermiso("ENTRENAR MODELOS");
                ExigirCliente();
                ExigirCuerpo(dto);

                int estado = dto.estado ?? 3;
                if (dto.version == null && estado == 3)
                    throw new ArgumentException("Un entrenamiento PROCESADO tiene que traer la versión que produjo; si falló, mándelo con estado 4 y el mensaje.");

                int ejecucion = Datos.Ejecutar("API_INS_ML_ENTRENAMIENTO", new Dictionary<string, object>
                {
                    { "@USUARIO", SesionApi.UsuarioId() },
                    { "@MODELO", MODELO },
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
                    new PuntuadorFalla(parametro);

                    version = Datos.Ejecutar("API_INS_ML_MODELO_VERSION", new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@MODELO", MODELO },
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
                        { "@OBSERVACION", dto.version.observacion }
                    }, true);
                }

                return Creado(ejecucion, new { id = ejecucion, version = version });
            });
        }

        [HttpGet]
        [Route("versiones")]
        public IHttpActionResult Versiones()
        {
            return Ejecutar(() =>
            {
                Entrar();
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
                Entrar();
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
        /// POST /sigma-ai/predecir — puntúa hoy, con la versión publicada, a
        /// todos los equipos del cliente (o a uno), y guarda cada predicción
        /// con sus características, sus razones y la alerta si corresponde.
        /// </summary>
        [HttpPost]
        [Route("predecir")]
        public IHttpActionResult Predecir(MlPredecirDto dto)
        {
            return Ejecutar(() =>
            {
                Entrar();
                ExigirPermiso("ENTRENAR MODELOS");
                ExigirCliente();
                if (dto == null) dto = new MlPredecirDto();

                MlModeloDto modelo = Modelo();
                if (modelo.VERSION_ID == null)
                    throw new ArgumentException("No hay una versión publicada de " + MODELO + ": entrene y publique una antes de puntuar.");

                PuntuadorFalla puntuador = new PuntuadorFalla(modelo.VERSION_PARAMETRO);
                List<Dictionary<string, object>> hoy = Filas(null, null, 7, true, dto.activo);

                List<object> resultado = new List<object>();

                foreach (Dictionary<string, object> fila in hoy)
                {
                    Dictionary<string, double> valores = PuntuadorFalla.Valores(fila);
                    PuntuadorFalla.Resultado r = puntuador.Puntuar(valores);

                    List<object> caracteristicas = new List<object>();
                    foreach (string c in puntuador.Caracteristicas)
                        if (valores.ContainsKey(c)) caracteristicas.Add(new { codigo = c, valor = valores[c] });

                    List<object> explicaciones = new List<object>();
                    foreach (PuntuadorFalla.Contribucion c in r.contribuciones)
                    {
                        if (c.texto == null || explicaciones.Count >= 3) continue;
                        explicaciones.Add(new { codigo = c.codigo, texto = c.texto, contribucion = c.contribucion, direccion = c.direccion, observado = c.valor, referencia = c.referencia });
                    }

                    int id = Datos.Ejecutar("API_INS_PREDICCION_FALLA", new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@VERSION", modelo.VERSION_ID },
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

                return Ok(new { version = modelo.VERSION_NUMERO, equipos = resultado.Count, predicciones = resultado });
            });
        }

        /// <summary>
        /// POST /sigma-ai/simular — "¿qué diría el modelo si…?": puntúa
        /// valores escritos a mano con la versión publicada, sin guardar
        /// nada. Para entender el modelo, no para decidir.
        /// </summary>
        [HttpPost]
        [Route("simular")]
        public IHttpActionResult Simular(MlSimularDto dto)
        {
            return Ejecutar(() =>
            {
                Entrar();
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                ExigirCuerpo(dto);
                if (dto.valores == null) throw new ArgumentException("Faltan los valores.");

                MlModeloDto modelo = Modelo();
                if (modelo.VERSION_ID == null)
                    throw new ArgumentException("No hay una versión publicada de " + MODELO + ".");

                PuntuadorFalla puntuador = new PuntuadorFalla(modelo.VERSION_PARAMETRO);
                PuntuadorFalla.Resultado r = puntuador.Puntuar(new Dictionary<string, double>(dto.valores, StringComparer.OrdinalIgnoreCase));

                return Ok(new { version = modelo.VERSION_NUMERO, probabilidad = Math.Round(r.probabilidad, 4), logit = Math.Round(r.logit, 4), contribuciones = r.contribuciones });
            });
        }

        [HttpGet]
        [Route("predicciones")]
        public IHttpActionResult Predicciones()
        {
            return Ejecutar(() =>
            {
                Entrar();
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                return Ok(Datos.Listar<MlPrediccionDto>("API_SEL_ML", Parametros(5)));
            });
        }

        /* ====================================================================
           LO QUE HAY EN AZURE ML
           ==================================================================== */

        /// <summary>GET /sigma-ai/azure — el área de trabajo, o por qué no se puede leer.</summary>
        [HttpGet]
        [Route("azure")]
        public IHttpActionResult Azure()
        {
            return Ejecutar(() =>
            {
                Entrar();
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
                    return Ok(new { configurado = false, faltantes = AzureMl.Faltantes(), artefactos = artefactos,
                                    mensaje = "El plano de control de Azure ML (experimentos, corridas) no está configurado en el Web.config de la API." });

                return Ok(new { configurado = true, area = AzureMl.AreaTrabajo(), mlflow = AzureMl.MlflowUri, artefactos = artefactos });
            });
        }

        [HttpGet]
        [Route("azure/modelos")]
        public IHttpActionResult AzureModelos(string nombre = null)
        {
            return Ejecutar(() =>
            {
                Entrar();
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
                Entrar();
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
                Entrar();
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
                Entrar();
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

            List<MlVersionDto> lista = Datos.Listar<MlVersionDto>("API_SEL_ML", Parametros(4, id));
            if (lista.Count == 0) throw new ArgumentException("La versión " + id + " no existe.");
            MlVersionDto ver = lista[0];

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
        /// La identidad. Con JWT ya viene puesta por el handler; sin JWT se
        /// acepta la que delega la web con la clave de servicio (ver
        /// ClaveServicio). Si no hay ninguna, ExigirPermiso responde lo de
        /// siempre: "inicie sesión".
        /// </summary>
        private void Entrar()
        {
            if (SesionApi.HayUsuario()) return;

            ClaimsPrincipal delegada = ClaveServicio.SesionDelegada(Request);
            if (delegada == null) return;

            Thread.CurrentPrincipal = delegada;
            if (HttpContext.Current != null) HttpContext.Current.User = delegada;
        }

        private Dictionary<string, object> Parametros(int tipo, int? id = null)
        {
            return new Dictionary<string, object>
            {
                { "@CLIENTE", SesionApi.ClienteId() },
                { "@USUARIO", SesionApi.UsuarioId() },
                { "@TIPO", tipo },
                { "@MODELO", MODELO },
                { "@ID", id }
            };
        }

        private MlModeloDto Modelo()
        {
            List<MlModeloDto> m = Datos.Listar<MlModeloDto>("API_SEL_ML", Parametros(1));
            if (m.Count == 0) throw new ArgumentException("El modelo " + MODELO + " no está registrado: aplique el bloque 245.");
            return m[0];
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
            return Datos.Filas(Datos.Conjunto("API_SEL_ML_DATASET_FALLA", p), 0);
        }

        private static object Fecha(string texto, string campo)
        {
            if (string.IsNullOrEmpty(texto)) return null;
            DateTime f;
            if (!DateTime.TryParseExact(texto, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f))
                throw new ArgumentException("La fecha '" + campo + "' debe venir como yyyy-MM-dd.");
            return f;
        }

        private static int Positivas(List<Dictionary<string, object>> filas)
        {
            int n = 0;
            foreach (Dictionary<string, object> f in filas)
                if (f["FALLO_EN_30D"] != null && Convert.ToBoolean(f["FALLO_EN_30D"])) n++;
            return n;
        }

        private static int Etiquetadas(List<Dictionary<string, object>> filas)
        {
            int n = 0;
            foreach (Dictionary<string, object> f in filas)
                if (f["FALLO_EN_30D"] != null) n++;
            return n;
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
