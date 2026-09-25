using System;
using System.Globalization;
using System.Text;

namespace API.Services
{
    /// <summary>
    /// DONDE QUEDA GUARDADO CADA ARCHIVO QUE SUBE LA APP.
    ///
    /// LA ESTRUCTURA, LA MISMA QUE LA WEB
    ///
    ///     sigma / 0001-hamburgo-sa / bitacora / 2026 / 09 / a1b2….m4a
    ///     └cont┘ └──── cliente ───┘ └─módulo─┘ └─ cuándo ─┘ └ nombre ┘
    ///
    /// POR QUE ESTA CLASE EXISTE
    ///
    ///   La app guardaba en «sigma/bitacora/archivo.m4a»: SIN el cliente. La
    ///   web, con `RutaArchivo` en Services.cs, guarda bajo la carpeta de la
    ///   empresa desde siempre. Dos sistemas escribiendo en el mismo contenedor
    ///   con dos estructuras distintas, y una de ellas mezclando empresas en la
    ///   misma carpeta.
    ///
    ///   No es un problema de orden. Es de AISLAMIENTO: con el cliente arriba,
    ///   un SAS acotado a un prefijo deja fuera a las demás empresas con una
    ///   sola regla. Sin él no hay prefijo que acotar, y el día que se entregue
    ///   una credencial de solo-lectura para «los archivos de Hamburgo» habría
    ///   que enumerar archivo por archivo.
    ///
    /// POR QUE NO SE REUSA LA CLASE DE LA WEB
    ///
    ///   La intranet es un proyecto de sitio web con App_Code; la API es un
    ///   ensamblado aparte y no la referencia. Copiar treinta líneas es
    ///   preferible a acoplar los dos despliegues, pero la REGLA es una sola y
    ///   tiene que quedar idéntica: si un día cambia, cambia en los dos, y este
    ///   comentario es el que lo recuerda.
    ///
    /// POR QUE EL ID Y EL NOMBRE JUNTOS
    ///
    ///   Solo el id —«sigma/1/…»— no dice de quién es nada cuando alguien abre
    ///   el portal de Azure a buscar un archivo. Solo el nombre no sirve: dos
    ///   clientes pueden llamarse parecido, y un nombre cambia —una empresa se
    ///   renombra— mientras que el id no cambia nunca. Con el id relleno a
    ///   cuatro dígitos la carpeta además ORDENA: 0002 va antes que 0010, cosa
    ///   que «2» y «10» no hacen en un listado alfabético.
    ///
    /// LO YA SUBIDO NO SE MUEVE
    ///
    ///   La ruta de cada archivo vive en `Archivo.arc_ruta`, así que lo que ya
    ///   está guardado se sigue encontrando donde está. Esto cambia lo que se
    ///   sube de aquí en adelante. Mover lo anterior es una migración de datos
    ///   —copiar en Azure y actualizar la columna—, no parte de este cambio.
    /// </summary>
    public static class RutaArchivo
    {
        /// <summary>
        /// Arma la ruta completa. <paramref name="modulo"/> es la carpeta del
        /// módulo —«bitacora», «orden»— y la decide quien llama, que es el que
        /// sabe a qué corresponde el archivo.
        /// </summary>
        public static string Armar(string contenedor, int cliente, string clienteNombre,
                                   string modulo, string nombreAlmacenado, DateTime cuando)
        {
            if (string.IsNullOrEmpty(contenedor)) contenedor = "sigma";

            return contenedor + "/" +
                   CarpetaCliente(cliente, clienteNombre) + "/" +
                   Limpiar(string.IsNullOrEmpty(modulo) ? "otros" : modulo) + "/" +
                   cuando.ToString("yyyy") + "/" +
                   cuando.ToString("MM") + "/" +
                   nombreAlmacenado;
        }

        /// <summary>«0001-hamburgo-sa».</summary>
        public static string CarpetaCliente(int cliente, string nombre)
        {
            string slug = Limpiar(nombre);

            /* Sin nombre queda solo el id: es preferible una carpeta fea a una
               que diga «sin-nombre», que se lee como si el cliente tuviera un
               problema. */
            return cliente.ToString("0000") + (string.IsNullOrEmpty(slug) ? "" : "-" + slug);
        }

        /// <summary>
        /// Un texto en algo que se pueda poner en una ruta: minúsculas, sin
        /// tildes, sin espacios ni signos.
        ///
        /// Blob Storage aceptaría casi cualquier cosa, pero una ruta con tildes
        /// y espacios hay que escaparla en cada URL, y basta que alguien olvide
        /// hacerlo una vez para que el archivo deje de encontrarse.
        /// </summary>
        public static string Limpiar(string texto)
        {
            if (string.IsNullOrEmpty(texto)) return "";

            string normal = texto.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);

            StringBuilder sb = new StringBuilder(normal.Length);
            bool guion = false;

            foreach (char c in normal)
            {
                // Se descartan las marcas diacríticas: «ó» queda en «o».
                if (CharUnicodeInfo.GetUnicodeCategory(c) == UnicodeCategory.NonSpacingMark) continue;

                if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))
                {
                    sb.Append(c);
                    guion = false;
                }
                else if (!guion && sb.Length > 0)
                {
                    sb.Append('-');
                    guion = true;
                }
            }

            return sb.ToString().Trim('-');
        }
    }
}
