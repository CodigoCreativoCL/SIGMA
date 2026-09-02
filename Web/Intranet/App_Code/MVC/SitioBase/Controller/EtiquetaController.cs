using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using QRCoder;

namespace SitioBase.Controller
{
    /// <summary>
    /// Etiquetas imprimibles con código QR.
    ///
    /// EL CONTROLADOR ARMA EL QR, NO LA PANTALLA
    ///   Una etiqueta sin su código no sirve para nada: es un papel con un
    ///   nombre. Si generarlo dependiera de que la página se acuerde, la
    ///   primera pantalla que lo olvide imprimiría una tirada entera de
    ///   etiquetas inservibles, y no se notaría hasta que alguien vaya a
    ///   escanear una.
    ///
    /// TODO SE ACOTA POR CLIENTE, SIEMPRE
    ///   @CLIENTE sale de la sesión, nunca de la pantalla. Un token de otra
    ///   empresa escaneado acá no devuelve nada.
    /// </summary>
    public class EtiquetaController
    {
        /// <summary>
        /// El catálogo de módulos imprimibles, tal como está en la base.
        /// </summary>
        public List<EtiquetaOrigenItem> GetOrigenes()
        {
            List<EtiquetaOrigenItem> lista = new List<EtiquetaOrigenItem>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ETIQUETA_ORIGEN";

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        EtiquetaOrigenItem o = new EtiquetaOrigenItem();

                        o.eto_id = int.Parse(dr["eto_id"].ToString());
                        o.eto_codigo = dr["eto_codigo"].ToString();
                        o.eto_nombre = dr["eto_nombre"].ToString();
                        o.eto_descripcion = dr["eto_descripcion"].ToString();
                        o.eto_icono = dr["eto_icono"].ToString();
                        o.eto_orden = int.Parse(dr["eto_orden"].ToString());
                        o.eto_por_bodega = bool.Parse(dr["eto_por_bodega"].ToString());
                        o.eto_habilitado = bool.Parse(dr["eto_habilitado"].ToString());
                        o.eto_motivo_baja = dr["eto_motivo_baja"].ToString();
                        o.Permiso = dr["PERMISO"].ToString();

                        lista.Add(o);
                    }
                }
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        /// <summary>
        /// Trae las etiquetas de un origen. <paramref name="ids"/> vacío
        /// significa "todas": rotular la estantería completa de una vez es el
        /// caso normal, no la excepción.
        /// </summary>
        public List<Etiqueta> GetEtiquetas(string origen, string ids, int bodega, string urlBase)
        {
            List<Etiqueta> lista = new List<Etiqueta>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ETIQUETA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ORIGEN", origen);

                if (!string.IsNullOrEmpty(ids))
                    cmd.Parameters.AddWithValue("@IDS", ids);

                if (bodega > 0)
                    cmd.Parameters.AddWithValue("@BODEGA", bodega);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        Etiqueta item = new Etiqueta();

                        item.Token = dr["TOKEN"].ToString();
                        item.Id = int.Parse(dr["ID"].ToString());
                        item.Codigo = dr["CODIGO"].ToString();
                        item.Titulo = dr["TITULO"].ToString();
                        item.Subtitulo = dr["SUBTITULO"].ToString();
                        item.Detalle = dr["DETALLE"].ToString();
                        item.Pie = dr["PIE"].ToString();

                        item.QrDataUri = GenerarQr(urlBase + item.Token);

                        lista.Add(item);
                    }
                }
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        /// <summary>
        /// El QR como data URI, embebido en el HTML.
        ///
        /// POR QUE EMBEBIDO Y NO UN HANDLER QUE SIRVA LA IMAGEN
        ///   Una hoja de 24 etiquetas serían 24 peticiones más, y al imprimir
        ///   basta que una llegue tarde para que salga un recuadro vacío
        ///   sobre una etiqueta que igual se va a pegar en un estante.
        ///   Embebido, lo que se ve en la vista previa es exactamente lo que
        ///   sale por la impresora.
        ///
        /// CORRECCION DE ERRORES EN Q Y NO EN L
        ///   Q tolera perder cerca de un cuarto del dibujo. Una etiqueta de
        ///   bodega se raya, se moja y junta polvo: con el nivel mínimo
        ///   dejaría de leerse a los pocos meses, que es justo cuando ya
        ///   nadie se acuerda de cómo se reimprimía.
        /// </summary>
        /// <summary>
        /// Un QR de cualquier texto, para quien lo necesite fuera de una
        /// etiqueta. Lo usa la pantalla de escaneo para ofrecer "abra esto en
        /// su telefono": el computador no tiene camara util, pero si puede
        /// mostrar un codigo que el telefono lea.
        /// </summary>
        public string QrDeUrl(string url)
        {
            return GenerarQr(url);
        }

        private string GenerarQr(string contenido)
        {
            try
            {
                QRCodeGenerator generador = new QRCodeGenerator();
                QRCodeGenerator.QRCode qr = generador.CreateQrCode(contenido,
                                                                   QRCodeGenerator.ECCLevel.Q);

                using (Bitmap mapa = qr.GetGraphic(6))
                using (MemoryStream ms = new MemoryStream())
                {
                    mapa.Save(ms, ImageFormat.Png);
                    return "data:image/png;base64," + Convert.ToBase64String(ms.ToArray());
                }
            }
            catch (Exception)
            {
                /* Sin QR la etiqueta sigue sirviendo: el código va impreso en
                   grande justamente para poder teclearlo. Se devuelve vacío y
                   la pantalla deja el hueco, en vez de tumbar toda la tirada
                   por una imagen. */
                return "";
            }
        }

        /// <summary>
        /// Interpreta lo que dejó la cámara o lo que alguien tecleó.
        ///
        /// Acepta las dos formas porque llegan las dos: la cámara del teléfono
        /// abre la URL completa que trae el QR, y cuando la etiqueta está
        /// rayada se escribe el código pelado, "UBI-17". Las dos tienen que
        /// funcionar.
        /// </summary>
        /// <returns>true si pudo entenderlo.</returns>
        public bool Interpretar(string leido, out string tipo, out int id)
        {
            tipo = "";
            id = 0;

            if (string.IsNullOrEmpty(leido)) return false;

            string texto = leido.Trim();

            /* Si vino una URL, lo que importa es lo que va después de c=. */
            int corte = texto.LastIndexOf("c=", StringComparison.OrdinalIgnoreCase);
            if (corte >= 0) texto = texto.Substring(corte + 2);

            /* Un lector puede agregar basura al final; se corta en el primer
               separador. */
            int fin = texto.IndexOfAny(new char[] { '&', '?', ' ', '\r', '\n' });
            if (fin >= 0) texto = texto.Substring(0, fin);

            texto = texto.Trim().ToUpper();

            int guion = texto.IndexOf('-');
            if (guion <= 0) return false;

            tipo = texto.Substring(0, guion);

            if (!int.TryParse(texto.Substring(guion + 1), out id) || id <= 0)
            {
                tipo = "";
                return false;
            }

            return (tipo == "UBI" || tipo == "BOD" || tipo == "REP" || tipo == "ACT");
        }
    }
}
