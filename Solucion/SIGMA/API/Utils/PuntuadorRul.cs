using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Globalization;

namespace API.Utils
{
    /// <summary>
    /// Puntúa SIGMA RUL dentro de la API con los pesos de la versión
    /// publicada: la regresión AFT log-normal que entrenó
    /// `ML/entrenar_rul.py`, escrita a mano en C#.
    ///
    ///   log(días restantes) = b + Σ w_i · (x_i − media_i) / desviación_i
    ///   mediana  = exp(·)
    ///   intervalo 80 % = exp(· ∓ 1,2816 · sigma)
    ///
    /// Mismo criterio que PuntuadorFalla: son los números que hay dentro del
    /// ONNX registrado (la parte lineal), en un JSON legible; el entrenador
    /// comprueba que el ONNX y la fórmula dan lo mismo antes de registrar.
    /// Las frases nombran el dato del que salen y nunca afirman que el
    /// repuesto "va a fallar tal día": dicen cuánto suele durar uno como
    /// este, con su margen.
    /// </summary>
    public class PuntuadorRul
    {
        public class Parametros
        {
            public List<string> caracteristicas { get; set; }
            public List<double> media { get; set; }
            public List<double> desviacion { get; set; }
            public List<double> coeficientes { get; set; }
            public double intercepto { get; set; }
            public double sigma { get; set; }
            public double? z_intervalo { get; set; }
            public string algoritmo { get; set; }
        }

        public class Resultado
        {
            public double dias { get; set; }
            public double diasInferior { get; set; }
            public double diasSuperior { get; set; }
            public double logMediana { get; set; }
            public double confianza { get; set; }
            public List<PuntuadorFalla.Contribucion> contribuciones { get; set; }
        }

        private readonly Parametros _p;

        public PuntuadorRul(string json)
        {
            if (string.IsNullOrEmpty(json))
                throw new ArgumentException("La versión publicada no tiene parámetros: vuelva a registrar el entrenamiento.");

            _p = JsonConvert.DeserializeObject<Parametros>(json);

            if (_p == null || _p.caracteristicas == null || _p.coeficientes == null ||
                _p.caracteristicas.Count != _p.coeficientes.Count)
                throw new ArgumentException("Los parámetros de la versión no son consistentes (características y coeficientes no calzan).");
            if (_p.sigma <= 0)
                throw new ArgumentException("Los parámetros de la versión no traen sigma (la dispersión del AFT).");

            if (_p.media == null) _p.media = new List<double>(new double[_p.caracteristicas.Count]);
            if (_p.desviacion == null)
            {
                _p.desviacion = new List<double>();
                for (int i = 0; i < _p.caracteristicas.Count; i++) _p.desviacion.Add(1.0);
            }
        }

        public IList<string> Caracteristicas { get { return _p.caracteristicas; } }

        public Resultado Puntuar(IDictionary<string, double> valores)
        {
            double z = _p.intercepto;
            List<PuntuadorFalla.Contribucion> partes = new List<PuntuadorFalla.Contribucion>();

            for (int i = 0; i < _p.caracteristicas.Count; i++)
            {
                string codigo = _p.caracteristicas[i];
                double x;
                bool imputado = !valores.TryGetValue(codigo, out x);
                if (imputado) x = _p.media[i];

                double sd = _p.desviacion[i] == 0 ? 1.0 : _p.desviacion[i];
                double c = _p.coeficientes[i] * (x - _p.media[i]) / sd;
                z += c;

                /* La dirección se guarda sobre el RIESGO (CK_PEX_DIRECCION:
                   AUMENTA / DISMINUYE): una contribución positiva alarga la
                   vida, o sea DISMINUYE el riesgo. La frase habla de vida. */
                partes.Add(new PuntuadorFalla.Contribucion
                {
                    codigo = codigo, valor = x, referencia = _p.media[i], contribucion = c,
                    direccion = c > 0 ? "DISMINUYE" : (c < 0 ? "AUMENTA" : null),
                    texto = imputado ? null : Frase(codigo, x, _p.media[i], c)
                });
            }

            double zi = _p.z_intervalo ?? 1.2815515655446004;
            partes.Sort((a, b) => Math.Abs(b.contribucion).CompareTo(Math.Abs(a.contribucion)));

            return new Resultado
            {
                logMediana = z,
                dias = Math.Exp(z),
                diasInferior = Math.Exp(z - zi * _p.sigma),
                diasSuperior = Math.Exp(z + zi * _p.sigma),
                confianza = 0.80,
                contribuciones = partes
            };
        }

        private static string Frase(string codigo, double x, double media, double c)
        {
            if (Math.Abs(c) < 0.05) return null;

            CultureInfo cl = CultureInfo.GetCultureInfo("es-CL");
            string v = x.ToString("0.##", cl);
            string m = media.ToString("0.##", cl);
            string efecto = c > 0 ? "alarga la vida esperada" : "acorta la vida esperada";

            switch (codigo)
            {
                case "DIAS_CORRIENDO":        return "Lleva " + v + " dias instalado (promedio " + m + "): " + efecto + ".";
                case "HORAS_CORRIENDO":       return "Lleva " + v + " horas corriendo (promedio " + m + "): " + efecto + ".";
                case "VIDA_NOMINAL_HORAS":    return "Vida nominal de " + v + " horas (promedio " + m + "): " + efecto + ".";
                case "VIDA_NOMINAL_DIAS":     return "Vida nominal de " + v + " dias (promedio " + m + "): " + efecto + ".";
                case "RATIO_CONSUMIDO":       return "Lleva consumido el " + (x * 100).ToString("0", cl) + " % de su vida nominal: " + efecto + ".";
                case "INSTALACIONES_PREVIAS": return "Es la instalacion numero " + (x + 1).ToString("0", cl) + " de este repuesto aqui: " + efecto + ".";
                case "DURACION_PREVIA_DIAS":  return "Los anteriores duraron " + v + " dias en promedio: " + efecto + ".";
                case "FALLOS_PREVIOS":        return v + " retiro(s) por falla anteriores en este componente: " + efecto + ".";
                case "CRITICIDAD":            return "Criticidad " + v + " (promedio " + m + "): " + efecto + ".";
                case "FALLAS_90D":            return "El equipo tuvo " + v + " falla(s) en 90 dias (promedio " + m + "): " + efecto + ".";
                case "DIAS_DESDE_MANTENCION": return "El equipo lleva " + v + " dias sin mantencion (promedio " + m + "): " + efecto + ".";
                case "MED_30D_ADVERTENCIA":   return v + " medicion(es) sobre advertencia en 30 dias (promedio " + m + "): " + efecto + ".";
                case "MED_30D_RATIO_CRITICO": return "La peor medicion del equipo llego al " + (x * 100).ToString("0", cl) + " % del limite critico: " + efecto + ".";
                case "TENDENCIA_30D":         return "La variable mas rapida se mueve " + (x * 100).ToString("0.##", cl) + " % del limite por dia: " + efecto + ".";
                default:                      return codigo + " = " + v + " (promedio " + m + "): " + efecto + ".";
            }
        }
    }
}
