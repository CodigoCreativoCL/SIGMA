using System;
using System.Collections.Generic;

namespace SitioBase.Model
{
    /// <summary>
    /// Un hallazgo que el sistema detectó y alguien tiene que ver.
    ///
    /// NO ES "UNA NOTIFICACIÓN"
    ///   Es el hecho: este repuesto está bajo su mínimo, este lote venció. La
    ///   notificación es cómo se le muestra a cada persona, y eso vive en
    ///   Leida —que es por usuario— mientras el hallazgo es uno solo para
    ///   toda la empresa.
    /// </summary>
    public class Alerta
    {
        public int ale_id { get; set; }
        public string ale_titulo { get; set; }
        public string ale_descripcion { get; set; }
        public DateTime ale_fecha_deteccion_utc { get; set; }

        public string alt_codigo { get; set; }
        public string alt_nombre { get; set; }
        public string alt_icono { get; set; }

        /// <summary>
        /// La PANTALLA donde vive el tema. Alimenta el número del menú
        /// lateral: "las tres alertas son de Existencias".
        /// </summary>
        public string alt_menu_link { get; set; }

        /// <summary>
        /// El REGISTRO concreto, que es lo que se abre al tocar la
        /// notificación. Distinto de alt_menu_link a propósito: el badge del
        /// menú apunta a una pantalla, la notificación a una fila.
        ///
        /// Llevar al listado sería avisar y después hacer buscar, que es la
        /// mitad del trabajo.
        /// </summary>
        public string FICHA_LINK { get; set; }

        /// <summary>
        /// El id que esa ficha espera. Lo resuelve el SP desde la columna que
        /// el tipo declara, para que web y app no repitan el mismo CASE en
        /// dos idiomas. Nulo = no hay registro que abrir.
        /// </summary>
        public int? FICHA_ID { get; set; }

        public string aet_codigo { get; set; }
        public string aet_nombre { get; set; }

        public string sev_codigo { get; set; }
        public string sev_nombre { get; set; }

        public int? ale_repuesto { get; set; }
        public int? ale_bodega { get; set; }
        public int? ale_repuesto_lote { get; set; }

        public decimal? ale_valor_observado { get; set; }
        public decimal? ale_valor_umbral { get; set; }

        public bool LEIDA { get; set; }

        /// <summary>
        /// Cuántos minutos hace. Lo calcula el SP y no la pantalla porque la
        /// web y la app tienen que decir lo mismo.
        /// </summary>
        public int MINUTOS { get; set; }

        /// <summary>
        /// "hace 5 minutos", "hace 3 días".
        ///
        /// Una fecha exacta obliga a restar de cabeza para saber si es de hoy,
        /// que es lo único que importa en una bandeja de avisos.
        /// </summary>
        public string Antiguedad
        {
            get
            {
                if (MINUTOS < 1) return "recién";
                if (MINUTOS < 60) return "hace " + MINUTOS + " min";

                int horas = MINUTOS / 60;
                if (horas < 24) return "hace " + horas + (horas == 1 ? " hora" : " horas");

                int dias = horas / 24;
                if (dias < 30) return "hace " + dias + (dias == 1 ? " día" : " días");

                int meses = dias / 30;
                return "hace " + meses + (meses == 1 ? " mes" : " meses");
            }
        }
    }

    /// <summary>Los números de la campana y de cada menú.</summary>
    public class AlertaResumen
    {
        public int Abiertas { get; set; }
        public int NoLeidas { get; set; }

        /// <summary>
        /// Cuántas hay por pantalla, para el punto del menú lateral. La clave
        /// es el mnu_link, que es lo que el menú ya conoce cuando se dibuja.
        /// </summary>
        public Dictionary<string, int> PorMenu { get; set; }

        public AlertaResumen()
        {
            PorMenu = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        }
    }
}
