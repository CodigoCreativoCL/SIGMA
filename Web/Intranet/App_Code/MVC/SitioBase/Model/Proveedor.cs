using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un proveedor o contratista del cliente (HU-060, bloque 91).
    ///
    /// NO TIENE CODIGO Y NO SE LE INVENTA UNO
    ///   El resto de los maestros lleva un codigo `XXX-&lt;id&gt;` que genera el
    ///   bloque 77. Una empresa no lo necesita: ya tiene un identificador
    ///   unico y universal, que es su RUT. Un `PRV-12` al lado seria un
    ///   segundo nombre para lo mismo, y quien busque por uno no va a
    ///   encontrar el otro.
    ///
    /// DOS TIPOS QUE NO SON EXCLUYENTES
    ///   Una empresa puede prestar servicio Y vender repuestos —Electrica Bio
    ///   Bio hace las dos cosas—, asi que son dos banderas y no una lista
    ///   desplegable. Al menos una tiene que estar encendida: un proveedor
    ///   que no es ninguna de las dos no se puede elegir en ninguna pantalla
    ///   y queda registrado sin ser alcanzable.
    /// </summary>
    [Serializable]
    public class Proveedor
    {
        public int prv_id { get; set; }
        public int prv_cliente { get; set; }
        public string prv_rut { get; set; }
        public string prv_razon_social { get; set; }
        public string prv_nombre_fantasia { get; set; }
        public string prv_giro { get; set; }
        public string prv_contacto { get; set; }
        public string prv_email { get; set; }
        public string prv_telefono { get; set; }
        public string prv_direccion { get; set; }
        public bool prv_es_contratista { get; set; }
        public bool prv_es_proveedor_repuesto { get; set; }
        public string prv_observacion { get; set; }
        public bool prv_habilitado { get; set; }

        public int prv_usuario_creacion { get; set; }
        public DateTime? prv_fecha_creacion { get; set; }
        public int? prv_usuario_actualizacion { get; set; }
        public DateTime? prv_fecha_actualizacion { get; set; }

        /* Las trae el SEL_ con LEFT JOIN a Usuario: devolver el id obliga a
           quien mira la ficha a ir a averiguar quien es el 7. */
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        /* Cuanto se le ha comprado y contratado, para decidir en el listado
           sin abrir la ficha —y para saber por que la baja se va a rechazar
           antes de intentarla. */
        public int lotes { get; set; }
        public int servicios { get; set; }

        // Filtros que el Controller convierte en parametros del SEL_
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool? filtro_es_contratista { get; set; }
        public bool? filtro_es_proveedor_repuesto { get; set; }

        /// <summary>
        /// Lo que se lee en un combo de proveedores: el nombre con el que la
        /// gente lo llama, y el RUT para desempatar dos razones sociales
        /// parecidas.
        /// </summary>
        public string etiqueta
        {
            get
            {
                string nombre = string.IsNullOrEmpty(prv_nombre_fantasia)
                              ? prv_razon_social : prv_nombre_fantasia;

                return nombre + "  ·  " + prv_rut;
            }
        }

        /// <summary>
        /// "Contratista", "Proveedor de repuestos" o las dos.
        /// </summary>
        public string tipos
        {
            get
            {
                if (prv_es_contratista && prv_es_proveedor_repuesto)
                    return "Contratista y proveedor";

                if (prv_es_contratista) return "Contratista";
                if (prv_es_proveedor_repuesto) return "Proveedor de repuestos";

                /* No deberia ocurrir: el SP lo impide en el alta y en la
                   edicion. Si aparece es que alguien escribio en la tabla por
                   fuera, y decirlo es mejor que mostrar una celda vacia. */
                return "Sin tipo";
            }
        }
    }
}
