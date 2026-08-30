using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un tope del plan con su consumo actual (ANEXO F §2.2, HU-193).
    ///
    /// `tope` y `disponible` en **nulo** no son cero: significan "sin tope"
    /// —como está cargado FULL— o "sin plan todavía". Cero es otra cosa muy
    /// distinta: cero es no poder crear ninguno.
    ///
    /// El consumo cuenta lo HABILITADO, no lo existente. Una planta dada de
    /// baja no ocupa cupo; si lo ocupara, la única salida para un cliente
    /// al límite sería borrar datos, que es justo lo que §8 prohíbe.
    /// </summary>
    [Serializable]
    public class ClienteLimite
    {
        public string fun_codigo { get; set; }
        public string fun_nombre { get; set; }
        public bool incluida { get; set; }

        public decimal? tope { get; set; }
        public decimal consumo { get; set; }
        public decimal? disponible { get; set; }

        public bool puede_crear { get; set; }

        /// <summary>
        /// SIN SUSCRIPCION · NO INCLUIDA · SIN TOPE · AL LIMITE · DISPONIBLE
        /// </summary>
        public string estado { get; set; }

        /// <summary>Para pintar la barra de consumo. Sin tope no hay barra.</summary>
        public int PorcentajeUso
        {
            get
            {
                if (tope == null || tope.Value <= 0) return 0;

                int p = (int)Math.Round((consumo / tope.Value) * 100m, 0);
                return p > 100 ? 100 : p;
            }
        }
    }
}
