using API.Utils;
using System.Collections.Generic;
using System.Linq;
using Xunit;

namespace API.Pruebas
{
    /// <summary>
    /// La paginacion de la API. Verifica RNF-12: un listado que puede crecer
    /// se pagina en el servidor y nunca se trae completo.
    ///
    /// El tope importa de verdad: el consumidor principal es la app movil
    /// sobre la red de una planta, y un listado sin limite funciona perfecto
    /// con diez filas en desarrollo y deja el telefono colgado el dia que el
    /// cliente tiene cuarenta mil activos.
    /// </summary>
    public class PaginacionPruebas
    {
        private static List<int> Lista(int n)
        {
            return Enumerable.Range(1, n).ToList();
        }

        // ------------------------------------------------ los limites

        [Fact]
        public void Sin_indicar_nada_pagina_de_a_cincuenta_desde_la_primera()
        {
            var p = new Pagina();

            Assert.Equal(1, p.pagina);
            Assert.Equal(Pagina.TAMANO_DEFECTO, p.tamano);
            Assert.Equal(0, p.Saltar());
        }

        [Theory]
        [InlineData(201)]
        [InlineData(1000)]
        [InlineData(int.MaxValue)]
        public void Nadie_puede_pedir_mas_del_tope(int pedido)
        {
            // Este es el requisito: el tope se aplica en el servidor, no se
            // confia en que quien llama pida una cantidad razonable.
            var p = new Pagina { tamano = pedido };

            Assert.Equal(Pagina.TAMANO_MAXIMO, p.tamano);
        }

        [Theory]
        [InlineData(0)]
        [InlineData(-1)]
        [InlineData(-500)]
        public void Un_tamano_absurdo_cae_al_valor_por_defecto(int pedido)
        {
            var p = new Pagina { tamano = pedido };

            Assert.Equal(Pagina.TAMANO_DEFECTO, p.tamano);
        }

        [Theory]
        [InlineData(0)]
        [InlineData(-3)]
        public void Una_pagina_menor_que_uno_se_trata_como_la_primera(int pedida)
        {
            var p = new Pagina { pagina = pedida };

            Assert.Equal(1, p.pagina);
            Assert.Equal(0, p.Saltar());
        }

        [Fact]
        public void El_salto_cuenta_desde_uno_no_desde_cero()
        {
            Assert.Equal(0, new Pagina { pagina = 1, tamano = 20 }.Saltar());
            Assert.Equal(20, new Pagina { pagina = 2, tamano = 20 }.Saltar());
            Assert.Equal(180, new Pagina { pagina = 10, tamano = 20 }.Saltar());
        }

        // ------------------------------------------------ el recorte

        [Fact]
        public void Devuelve_el_tramo_que_corresponde_a_la_pagina()
        {
            var r = Paginado<int>.Armar(Lista(100), new Pagina { pagina = 3, tamano = 10 });

            Assert.Equal(10, r.datos.Count);
            Assert.Equal(21, r.datos.First());
            Assert.Equal(30, r.datos.Last());
        }

        [Fact]
        public void Informa_el_total_y_la_cantidad_de_paginas_para_no_pedir_un_conteo_aparte()
        {
            var r = Paginado<int>.Armar(Lista(95), new Pagina { pagina = 1, tamano = 10 });

            Assert.Equal(95, r.total);
            Assert.Equal(10, r.paginas);   // 9 llenas + 1 con 5
        }

        [Fact]
        public void La_ultima_pagina_trae_solo_lo_que_queda()
        {
            var r = Paginado<int>.Armar(Lista(95), new Pagina { pagina = 10, tamano = 10 });

            Assert.Equal(5, r.datos.Count);
            Assert.Equal(95, r.datos.Last());
        }

        [Fact]
        public void Pedir_una_pagina_mas_alla_del_final_devuelve_vacio_y_no_falla()
        {
            // Llegar al final de una lista no es un error: devolver 404
            // obligaria a quien pagina a tratarlo como una falla.
            var r = Paginado<int>.Armar(Lista(3), new Pagina { pagina = 40, tamano = 10 });

            Assert.Empty(r.datos);
            Assert.Equal(3, r.total);
        }

        [Fact]
        public void Una_lista_vacia_devuelve_cero_paginas_y_ningun_dato()
        {
            var r = Paginado<int>.Armar(new List<int>(), new Pagina());

            Assert.Equal(0, r.total);
            Assert.Equal(0, r.paginas);
            Assert.Empty(r.datos);
        }

        [Fact]
        public void Una_lista_nula_se_trata_como_vacia_y_no_revienta()
        {
            var r = Paginado<int>.Armar(null, new Pagina());

            Assert.Equal(0, r.total);
            Assert.Empty(r.datos);
        }

        [Fact]
        public void Recorriendo_todas_las_paginas_se_obtiene_la_lista_completa_sin_repetir()
        {
            // La prueba que de verdad importa: paginar no puede perder ni
            // duplicar una fila.
            var todo = Lista(237);
            var vistos = new List<int>();
            var p = new Pagina { tamano = 25 };

            for (int i = 1; i <= Paginado<int>.Armar(todo, p).paginas; i++)
                vistos.AddRange(Paginado<int>.Armar(todo, new Pagina { pagina = i, tamano = 25 }).datos);

            Assert.Equal(237, vistos.Count);
            Assert.Equal(todo, vistos);
            Assert.Equal(vistos.Count, vistos.Distinct().Count());
        }

        [Fact]
        public void Aunque_se_pida_mas_del_tope_la_pagina_respeta_el_maximo()
        {
            var r = Paginado<int>.Armar(Lista(5000), new Pagina { pagina = 1, tamano = 99999 });

            Assert.Equal(Pagina.TAMANO_MAXIMO, r.datos.Count);
            Assert.Equal(5000, r.total);
        }
    }
}
