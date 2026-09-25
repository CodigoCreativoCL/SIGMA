using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Globalization;

namespace API.Utils
{
    /// <summary>
    /// Puntúa SIGMA FAILURE dentro de la API con los pesos de la versión
    /// publicada: la regresión logística que entrenó `ML/entrenar_falla.py`,
    /// escrita a mano en C#.
    ///
    /// POR QUE LOS PESOS Y NO EL .onnx
    ///   El artefacto oficial es el ONNX registrado en Azure ML; puntuarlo
    ///   acá exige ONNX Runtime (dos paquetes NuGet con binarios nativos).
    ///   Una regresión logística son doce multiplicaciones y una sigmoide:
    ///   los mismos números que hay dentro del ONNX, en un JSON que
    ///   cualquiera puede leer en `Modelo_Predictivo_Version.mpv_parametro`.
    ///   El entrenador comprueba, antes de registrar, que el ONNX y el JSON
    ///   dan la misma probabilidad para todo el dataset; si difieren no se
    ///   registra ninguno. Cuando se agregue ONNX Runtime este puntuador es
    ///   el contraste.
    ///
    /// LO QUE DEVUELVE ADEMAS DEL NUMERO
    ///   La contribución de cada característica (peso × valor estandarizado)
    ///   y una frase en español por cada una de las que más pesan. Nunca en
    ///   afirmativo: dice qué empujó la probabilidad, no que el equipo va a
    ///   fallar.
    /// </summary>
    public class PuntuadorFalla
    {
        /// <summary>El JSON que guarda `mpv_parametro`.</summary>
        public class Parametros
        {
            public List<string> caracteristicas { get; set; }
            public List<double> media { get; set; }
            public List<double> desviacion { get; set; }
            public List<double> coeficientes { get; set; }
            public double intercepto { get; set; }
            public string algoritmo { get; set; }
        }

        public class Contribucion
        {
            public string codigo { get; set; }
            public double valor { get; set; }
            public double referencia { get; set; }
            public double contribucion { get; set; }
            public string direccion { get; set; }
            public string texto { get; set; }
        }

        public class Resultado
        {
            public double probabilidad { get; set; }
            public double logit { get; set; }
            public List<Contribucion> contribuciones { get; set; }
        }

        private readonly Parametros _p;

        public PuntuadorFalla(string json)
        {
            if (string.IsNullOrEmpty(json))
                throw new ArgumentException("La versión publicada no tiene parámetros: vuelva a registrar el entrenamiento.");

            _p = JsonConvert.DeserializeObject<Parametros>(json);

            if (_p == null || _p.caracteristicas == null || _p.coeficientes == null ||
                _p.caracteristicas.Count != _p.coeficientes.Count)
                throw new ArgumentException("Los parámetros de la versión no son consistentes (características y coeficientes no calzan).");

            if (_p.media == null) _p.media = new List<double>(new double[_p.caracteristicas.Count]);
            if (_p.desviacion == null)
            {
                _p.desviacion = new List<double>();
                for (int i = 0; i < _p.caracteristicas.Count; i++) _p.desviacion.Add(1.0);
            }
        }

        public IList<string> Caracteristicas { get { return _p.caracteristicas; } }

        /// <summary>
        /// Puntúa una fila. `valores` va por código de característica; la
        /// que falte se toma como la media del entrenamiento (contribución
        /// cero), y se marca en la explicación.
        /// </summary>
        public Resultado Puntuar(IDictionary<string, double> valores)
        {
            double z = _p.intercepto;
            List<Contribucion> partes = new List<Contribucion>();

            for (int i = 0; i < _p.caracteristicas.Count; i++)
            {
                string codigo = _p.caracteristicas[i];
                double x;
                bool imputado = !valores.TryGetValue(codigo, out x);
                if (imputado) x = _p.media[i];

                double sd = _p.desviacion[i] == 0 ? 1.0 : _p.desviacion[i];
                double xs = (x - _p.media[i]) / sd;
                double c = _p.coeficientes[i] * xs;
                z += c;

                partes.Add(new Contribucion
                {
                    codigo = codigo,
                    valor = x,
                    referencia = _p.media[i],
                    contribucion = c,
                    direccion = c > 0 ? "AUMENTA" : (c < 0 ? "DISMINUYE" : null),   // CK_PEX_DIRECCION
                    texto = imputado ? null : Frase(codigo, x, _p.media[i], c)
                });
            }

            double prob = 1.0 / (1.0 + Math.Exp(-z));

            partes.Sort((a, b) => Math.Abs(b.contribucion).CompareTo(Math.Abs(a.contribucion)));

            return new Resultado { probabilidad = prob, logit = z, contribuciones = partes };
        }

        /// <summary>
        /// Una frase sobre datos reales, con el número del que sale. Solo
        /// para las contribuciones que mueven algo; una de 0,001 no merece
        /// una oración.
        /// </summary>
        private static string Frase(string codigo, double x, double media, double c)
        {
            if (Math.Abs(c) < 0.05) return null;

            CultureInfo cl = CultureInfo.GetCultureInfo("es-CL");
            string v = x.ToString("0.##", cl);
            string m = media.ToString("0.##", cl);
            string sube = c > 0 ? "sube" : "baja";

            switch (codigo)
            {
                case "FALLAS_90D":            return "Lleva " + v + " falla(s) en 90 dias (lo normal es " + m + "): " + sube + " el riesgo.";
                case "FALLAS_TOTAL":          return "Acumula " + v + " falla(s) historicas frente a " + m + " de promedio: " + sube + " el riesgo.";
                case "DIAS_DESDE_FALLA":      return "Han pasado " + v + " dias desde su ultima falla (promedio " + m + "): " + sube + " el riesgo.";
                case "OT_CERRADAS_180D":      return "Se le cerraron " + v + " ordenes en 180 dias (promedio " + m + "): " + sube + " el riesgo.";
                case "OT_CORRECTIVAS_180D":   return "Tuvo " + v + " correctivas en 180 dias (promedio " + m + "): " + sube + " el riesgo.";
                case "DIAS_DESDE_MANTENCION": return "Lleva " + v + " dias sin mantencion (promedio " + m + "): " + sube + " el riesgo.";
                case "MED_30D_N":             return "Se midio " + v + " veces en 30 dias (promedio " + m + "): " + sube + " el riesgo.";
                case "MED_30D_ADVERTENCIA":   return v + " medicion(es) sobre advertencia en 30 dias (promedio " + m + "): " + sube + " el riesgo.";
                case "MED_30D_RATIO_CRITICO": return "Su peor medicion llego al " + (x * 100).ToString("0", cl) + " % del limite critico: " + sube + " el riesgo.";
                case "TENDENCIA_30D":         return "La variable mas rapida se mueve " + (x * 100).ToString("0.##", cl) + " % del limite por dia: " + sube + " el riesgo.";
                case "BITACORA_30D":          return v + " incidente(s) en bitacora en 30 dias (promedio " + m + "): " + sube + " el riesgo.";
                case "INDISP_MIN_90D":        return v + " minutos indisponible en 90 dias (promedio " + m + "): " + sube + " el riesgo.";
                case "EDAD_DIAS":             return "Tiene " + v + " dias de edad (promedio " + m + "): " + sube + " el riesgo.";
                case "LECTURA_MEDIDOR":       return "Su medidor marca " + v + " (promedio " + m + "): " + sube + " el riesgo.";
                case "CRITICIDAD":            return "Criticidad declarada " + v + " (promedio " + m + "): " + sube + " el riesgo.";
                default:                      return codigo + " = " + v + " (promedio " + m + "): " + sube + " el riesgo.";
            }
        }

        /// <summary>
        /// Lee una fila del dataset (un diccionario columna → valor tal como
        /// lo entrega el SP) y deja solo las numéricas por código.
        /// </summary>
        public static Dictionary<string, double> Valores(IDictionary<string, object> fila)
        {
            Dictionary<string, double> v = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            foreach (KeyValuePair<string, object> kv in fila)
            {
                if (kv.Value == null || kv.Value is DBNull || kv.Value is string || kv.Value is DateTime) continue;
                if (kv.Value is bool) { v[kv.Key] = (bool)kv.Value ? 1 : 0; continue; }
                try { v[kv.Key] = Convert.ToDouble(kv.Value, CultureInfo.InvariantCulture); }
                catch (Exception) { /* no numérica: no es característica */ }
            }
            return v;
        }
    }
}
