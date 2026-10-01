using API.Utils;
using System;
using System.Collections.Generic;
using Xunit;

namespace API.Pruebas
{
    /// <summary>
    /// SIGMA FAILURE: la regresion logistica que puntua la probabilidad de
    /// que un equipo registre una falla en los proximos 30 dias.
    ///
    /// Se prueba aqui, y no desde la pantalla, porque es aritmetica: si el
    /// resultado se verificara solo mirando el panel, un signo cambiado
    /// daria un numero distinto pero igual de verosimil, y nadie lo notaria.
    /// </summary>
    public class PuntuadorFallaPruebas
    {
        /// <summary>
        /// Parametros minimos y verificables a mano: una caracteristica,
        /// media 10, desviacion 5, coeficiente 2, intercepto 0.
        /// </summary>
        private const string UNA = @"{
            ""caracteristicas"": [""FALLAS_90D""],
            ""media"": [10.0],
            ""desviacion"": [5.0],
            ""coeficientes"": [2.0],
            ""intercepto"": 0.0,
            ""algoritmo"": ""logistica""
        }";

        private static Dictionary<string, double> Valores(params object[] pares)
        {
            var d = new Dictionary<string, double>();
            for (int i = 0; i < pares.Length; i += 2) d[(string)pares[i]] = Convert.ToDouble(pares[i + 1]);
            return d;
        }

        // ------------------------------------------------ la aritmetica

        [Fact]
        public void En_la_media_el_logit_es_el_intercepto_y_la_probabilidad_es_un_medio()
        {
            var r = new PuntuadorFalla(UNA).Puntuar(Valores("FALLAS_90D", 10.0));

            // x = media -> estandarizado 0 -> z = intercepto = 0 -> sigmoide(0) = 0,5
            Assert.Equal(0.0, r.logit, 10);
            Assert.Equal(0.5, r.probabilidad, 10);
        }

        [Fact]
        public void Estandariza_con_la_media_y_la_desviacion_del_entrenamiento()
        {
            var r = new PuntuadorFalla(UNA).Puntuar(Valores("FALLAS_90D", 20.0));

            // (20 - 10) / 5 = 2 ; 2 * coef 2 = 4
            Assert.Equal(4.0, r.logit, 10);
            Assert.Equal(1.0 / (1.0 + Math.Exp(-4.0)), r.probabilidad, 10);
        }

        [Fact]
        public void La_probabilidad_siempre_queda_entre_cero_y_uno()
        {
            var p = new PuntuadorFalla(UNA);

            foreach (double x in new[] { -1e6, -100.0, 0.0, 10.0, 100.0, 1e6 })
            {
                double prob = p.Puntuar(Valores("FALLAS_90D", x)).probabilidad;
                Assert.InRange(prob, 0.0, 1.0);
            }
        }

        [Fact]
        public void Un_coeficiente_positivo_sobre_la_media_sube_la_probabilidad()
        {
            var p = new PuntuadorFalla(UNA);

            double bajo = p.Puntuar(Valores("FALLAS_90D", 5.0)).probabilidad;
            double medio = p.Puntuar(Valores("FALLAS_90D", 10.0)).probabilidad;
            double alto = p.Puntuar(Valores("FALLAS_90D", 15.0)).probabilidad;

            Assert.True(bajo < medio && medio < alto,
                "Mas fallas recientes no puede dar menos riesgo.");
        }

        [Fact]
        public void Una_desviacion_cero_no_divide_por_cero()
        {
            // Una caracteristica constante en el entrenamiento llega con
            // desviacion 0. Debe tratarse como 1, no reventar ni dar NaN.
            string json = @"{""caracteristicas"":[""CRITICIDAD""],""media"":[3.0],
                             ""desviacion"":[0.0],""coeficientes"":[1.0],""intercepto"":0.0}";

            var r = new PuntuadorFalla(json).Puntuar(Valores("CRITICIDAD", 5.0));

            Assert.Equal(2.0, r.logit, 10);          // (5 - 3) / 1 * 1
            Assert.False(double.IsNaN(r.probabilidad));
        }

        // ------------------------------------------------ datos que faltan

        [Fact]
        public void La_caracteristica_que_falta_se_imputa_con_la_media_y_no_aporta()
        {
            var r = new PuntuadorFalla(UNA).Puntuar(new Dictionary<string, double>());

            Assert.Equal(0.0, r.logit, 10);
            Assert.Equal(0.0, r.contribuciones[0].contribucion, 10);
        }

        [Fact]
        public void Una_caracteristica_imputada_no_genera_explicacion()
        {
            // Explicar con un dato que no se tiene seria inventar: el equipo
            // no "tiene" ese valor, se asumio el promedio.
            var r = new PuntuadorFalla(UNA).Puntuar(new Dictionary<string, double>());

            Assert.Null(r.contribuciones[0].texto);
        }

        [Fact]
        public void Un_valor_que_sobra_y_no_es_caracteristica_se_ignora()
        {
            var r = new PuntuadorFalla(UNA).Puntuar(Valores("FALLAS_90D", 10.0, "COLOR_DEL_EQUIPO", 7.0));

            Assert.Single(r.contribuciones);
            Assert.Equal(0.0, r.logit, 10);
        }

        // ------------------------------------------------ la explicacion

        [Fact]
        public void Las_contribuciones_vienen_ordenadas_por_cuanto_pesan()
        {
            string json = @"{""caracteristicas"":[""A"",""B"",""C""],
                             ""media"":[0.0,0.0,0.0],""desviacion"":[1.0,1.0,1.0],
                             ""coeficientes"":[0.1,5.0,-2.0],""intercepto"":0.0}";

            var r = new PuntuadorFalla(json).Puntuar(Valores("A", 1.0, "B", 1.0, "C", 1.0));

            Assert.Equal("B", r.contribuciones[0].codigo);   // |5,0|
            Assert.Equal("C", r.contribuciones[1].codigo);   // |-2,0|
            Assert.Equal("A", r.contribuciones[2].codigo);   // |0,1|
        }

        [Fact]
        public void La_direccion_dice_si_empujo_hacia_arriba_o_hacia_abajo()
        {
            var p = new PuntuadorFalla(UNA);

            Assert.Equal("AUMENTA", p.Puntuar(Valores("FALLAS_90D", 20.0)).contribuciones[0].direccion);
            Assert.Equal("DISMINUYE", p.Puntuar(Valores("FALLAS_90D", 1.0)).contribuciones[0].direccion);
            Assert.Null(p.Puntuar(Valores("FALLAS_90D", 10.0)).contribuciones[0].direccion);
        }

        [Fact]
        public void Una_contribucion_despreciable_no_merece_una_frase()
        {
            // Umbral declarado en el codigo: por debajo de 0,05 no se explica.
            string json = @"{""caracteristicas"":[""FALLAS_90D""],""media"":[10.0],
                             ""desviacion"":[1.0],""coeficientes"":[0.001],""intercepto"":0.0}";

            var r = new PuntuadorFalla(json).Puntuar(Valores("FALLAS_90D", 11.0));

            Assert.Null(r.contribuciones[0].texto);
        }

        [Fact]
        public void La_frase_nunca_afirma_que_el_equipo_va_a_fallar()
        {
            var r = new PuntuadorFalla(UNA).Puntuar(Valores("FALLAS_90D", 30.0));
            string texto = r.contribuciones[0].texto;

            Assert.NotNull(texto);
            Assert.Contains("riesgo", texto);
            Assert.DoesNotContain("va a fallar", texto);
            Assert.DoesNotContain("fallara", texto);
        }

        [Fact]
        public void La_frase_trae_el_valor_real_y_el_de_referencia()
        {
            var r = new PuntuadorFalla(UNA).Puntuar(Valores("FALLAS_90D", 30.0));

            Assert.Contains("30", r.contribuciones[0].texto);
            Assert.Contains("10", r.contribuciones[0].texto);
        }

        // ------------------------------------------------ parametros invalidos

        [Fact]
        public void Sin_parametros_no_puntua()
        {
            Assert.Throws<ArgumentException>(() => new PuntuadorFalla(null));
            Assert.Throws<ArgumentException>(() => new PuntuadorFalla(""));
        }

        [Fact]
        public void Si_las_caracteristicas_y_los_coeficientes_no_calzan_no_puntua()
        {
            // Publicar una version con los pesos desalineados daria numeros
            // sin sentido en silencio: tiene que fallar al construirse.
            string json = @"{""caracteristicas"":[""A"",""B""],""media"":[0.0,0.0],
                             ""desviacion"":[1.0,1.0],""coeficientes"":[1.0],""intercepto"":0.0}";

            Assert.Throws<ArgumentException>(() => new PuntuadorFalla(json));
        }

        // ------------------------------------------------ lectura de la fila

        [Fact]
        public void Valores_toma_las_columnas_numericas_y_descarta_el_resto()
        {
            var fila = new Dictionary<string, object>
            {
                { "FALLAS_90D", 3 },
                { "EDAD_DIAS", 1200.5m },
                { "NOMBRE", "Bomba 3" },
                { "FECHA", DateTime.Now },
                { "SIN_DATO", DBNull.Value },
                { "VACIO", null }
            };

            var v = PuntuadorFalla.Valores(fila);

            Assert.Equal(2, v.Count);
            Assert.Equal(3.0, v["FALLAS_90D"]);
            Assert.Equal(1200.5, v["EDAD_DIAS"]);
        }

        [Fact]
        public void Valores_convierte_un_booleano_en_uno_o_cero()
        {
            var v = PuntuadorFalla.Valores(new Dictionary<string, object>
            {
                { "ES_CRITICO", true },
                { "ESTA_PARADO", false }
            });

            Assert.Equal(1.0, v["ES_CRITICO"]);
            Assert.Equal(0.0, v["ESTA_PARADO"]);
        }

        [Fact]
        public void Valores_no_distingue_mayusculas_de_minusculas()
        {
            // El SP puede devolver la columna en otra caja que el codigo de
            // la caracteristica; si distinguiera, la caracteristica se
            // imputaria en silencio y la prediccion saldria plana.
            var v = PuntuadorFalla.Valores(new Dictionary<string, object> { { "fallas_90d", 4 } });

            Assert.Equal(4.0, v["FALLAS_90D"]);
        }
    }
}
