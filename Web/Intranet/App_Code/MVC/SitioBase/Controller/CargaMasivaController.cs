using OfficeOpenXml;
using OfficeOpenXml.DataValidation;
using OfficeOpenXml.Style;
using SitioBase;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Hosting;
using System.Web.Script.Serialization;

namespace SitioBase.Controller
{
    /// <summary>
    /// Centro de carga de datos (bloques 334 en adelante).
    ///
    /// LA DEFINICION VIVE AQUI, UNA VEZ
    ///   Cada modulo declara sus hojas y columnas: con eso se arma la plantilla
    ///   (encabezados, ayudas, listas desplegables, ejemplo), se lee el archivo
    ///   (encabezados sin importar mayusculas, acentos ni sinonimos) y se
    ///   dibuja la pantalla. Las reglas de negocio no estan aqui: estan en
    ///   PRC_CARGA_&lt;MODULO&gt;, que llama a los SP de las fichas.
    ///
    /// RAPIDO CON MILES DE FILAS
    ///   El archivo se lee en memoria y se sube completo con SqlBulkCopy a
    ///   Carga_Masiva_Fila (una fila de Excel = un JSON). El procesamiento corre
    ///   dentro de la base, en segundo plano (QueueBackgroundWorkItem): la
    ///   pantalla consulta el avance cada segundo y nadie espera con el
    ///   navegador colgado.
    /// </summary>
    public class CargaMasivaController
    {
        public const string PERMISO = "GESTIONAR CARGAS MASIVAS";
        public const int MAX_FILAS = 100000;

        // ================================================================ definiciones
        public enum Tipo { Texto, Numero, Entero, Fecha, SiNo, Lista }

        public class Columna
        {
            public string clave { get; set; }
            public string titulo { get; set; }
            public bool obligatoria { get; set; }
            public string ayuda { get; set; }
            public string ejemplo { get; set; }
            public Tipo tipo { get; set; }
            public string[] valores { get; set; }      // Lista: los valores validos
            public string ayudaHoja { get; set; }       // hoja de ayuda de la que sale la lista
            public string[] sinonimos { get; set; }
            public int ancho { get; set; }
        }

        public class Hoja
        {
            public string clave { get; set; }
            public string titulo { get; set; }
            public string descripcion { get; set; }
            public string icono { get; set; }
            public List<Columna> columnas { get; set; }
        }

        public class Modulo
        {
            public string clave { get; set; }
            public string nombre { get; set; }
            public string descripcion { get; set; }
            public string icono { get; set; }
            public string color { get; set; }
            public string procedimiento { get; set; }
            public bool disponible { get; set; }
            public string[] ayudas { get; set; }        // hojas de ayuda: PLANTAS, UNIDADES...
            public List<Hoja> hojas { get; set; }
        }

        private static Columna C(string clave, string titulo, bool obligatoria, string ayuda, string ejemplo, Tipo tipo = Tipo.Texto,
                                 int ancho = 18, string[] valores = null, string ayudaHoja = null, params string[] sinonimos)
        {
            return new Columna { clave = clave, titulo = titulo, obligatoria = obligatoria, ayuda = ayuda, ejemplo = ejemplo, tipo = tipo,
                                 ancho = ancho, valores = valores, ayudaHoja = ayudaHoja, sinonimos = sinonimos };
        }

        private static readonly string[] SINO = { "SI", "NO" };
        private static readonly string[] METODOS_BODEGA = { "FEFO", "FIFO", "LIFO" };
        private static readonly string[] METODOS_REP = { "Según bodega", "FEFO", "FIFO", "LIFO" };

        private static List<Modulo> _modulos;
        public static List<Modulo> Modulos()
        {
            if (_modulos != null) return _modulos;
            List<Modulo> m = new List<Modulo>();

            m.Add(new Modulo
            {
                clave = "INVENTARIO",
                nombre = "Inventario",
                descripcion = "Bodegas, racks, repuestos, umbrales, el stock con que parte cada bodega y en qué equipos sirve cada repuesto.",
                icono = "mdi-warehouse",
                color = "#6732F4",
                procedimiento = "PRC_CARGA_INVENTARIO",
                disponible = true,
                ayudas = new[] { "PLANTAS", "BODEGAS", "RACKS", "UNIDADES", "TIPOS", "FABRICANTES", "ACTIVOS" },
                hojas = new List<Hoja>
                {
                    new Hoja { clave = "BODEGAS", titulo = "BODEGAS", icono = "mdi-warehouse",
                        descripcion = "Una fila por bodega. Con el mismo código (o el mismo nombre, si no lleva código) se actualiza.",
                        columnas = new List<Columna> {
                            C("CODIGO", "CODIGO", false, "Vacío: se numera solo (BOD-<n>). No se puede cambiar después.", "EJEMPLO-CENTRAL", Tipo.Texto, 16),
                            C("NOMBRE", "NOMBRE", true, "Cómo la reconoce la gente.", "Bodega Central", Tipo.Texto, 28),
                            C("PLANTA", "PLANTA", true, "Tal como aparece en la hoja PLANTAS.", "Planta Renca", Tipo.Lista, 22, null, "PLANTAS"),
                            C("DESCRIPCION", "DESCRIPCION", false, "Para qué se usa.", "Repuestos críticos de línea 1", Tipo.Texto, 36),
                            C("METODO_SALIDA", "METODO SALIDA", false, "FEFO (vence primero), FIFO (entró primero) o LIFO. Vacío: FEFO.", "FEFO", Tipo.Lista, 16, METODOS_BODEGA, null, "METODO")
                        } },
                    new Hoja { clave = "RACKS", titulo = "RACKS", icono = "mdi-view-grid-outline",
                        descripcion = "Una fila por rack. Sin código, se arma como en el mapa 3D: <prefijo>-<área>-R<nn>, desde el siguiente número libre del área (pasillo, sala, zona…).",
                        columnas = new List<Columna> {
                            C("BODEGA", "BODEGA", true, "Código o nombre de la bodega (de la base o de la hoja BODEGAS).", "EJEMPLO-CENTRAL", Tipo.Texto, 22),
                            C("TIPO_AREA", "TIPO AREA", false, "Pasillo, Sala, Zona, Sector… Vacío: Pasillo. Si no existe, se crea.", "Pasillo", Tipo.Texto, 14),
                            C("PASILLO", "AREA", false, "Código del área: 1 a 3 letras (A, B, AB). Obligatorio si no escribe el código.", "A", Tipo.Texto, 10, null, null, "PASILLO"),
                            C("NUMERO", "NUMERO", false, "Número del rack en el área. Vacío: el siguiente libre.", "1", Tipo.Entero, 10),
                            C("CODIGO", "CODIGO", false, "Solo si ya tiene un código impreso. Vacío: se arma solo.", "", Tipo.Texto, 18),
                            C("NOMBRE", "NOMBRE", false, "Vacío: «Pasillo A · Rack 01» (con el tipo de área).", "", Tipo.Texto, 26),
                            C("CARGA_NIVEL_KG", "CARGA NIVEL KG", false, "Carga admisible por nivel. Vacío: 1.000 kg.", "1000", Tipo.Numero, 16, null, null, "CARGA KG", "CARGA")
                        } },
                    new Hoja { clave = "REPUESTOS", titulo = "REPUESTOS", icono = "mdi-package-variant-closed",
                        descripcion = "Las mismas columnas de la carga de repuestos de siempre, más método y medidas. Con el mismo código se actualiza: las celdas vacías conservan lo que había.",
                        columnas = new List<Columna> {
                            C("CODIGO", "CODIGO", false, "Vacío: se numera solo. Con un código existente, se actualiza.", "EJEMPLO-ROD-001", Tipo.Texto, 20),
                            C("NOMBRE", "NOMBRE", true, "Obligatorio para un repuesto nuevo.", "Rodamiento 6205-2RS1", Tipo.Texto, 34),
                            C("UNIDAD", "UNIDAD", true, "Como en la hoja UNIDADES (UNIDAD, LITRO, METRO...).", "UNIDAD", Tipo.Lista, 14, null, "UNIDADES"),
                            C("FABRICANTE", "FABRICANTE", false, "Se normaliza solo: «skf» y «SKF» son el mismo.", "SKF", Tipo.Texto, 18, null, null, "MARCA"),
                            C("MODELO", "MODELO", false, "Código del fabricante.", "6205-2RS1", Tipo.Texto, 18),
                            C("CONTROLA_LOTE", "CONTROLA LOTE", false, "SI: cada ingreso pide lote y vencimiento.", "NO", Tipo.SiNo, 14, SINO, null, "LOTE"),
                            C("CONSUMIBLE", "CONSUMIBLE", false, "SI: se gasta y no vuelve a bodega.", "NO", Tipo.SiNo, 13, SINO),
                            C("REPARABLE", "REPARABLE", false, "SI: puede volver reparado.", "NO", Tipo.SiNo, 12, SINO),
                            C("COSTO_REFERENCIA", "COSTO REFERENCIA", false, "En pesos. Referencial.", "8500", Tipo.Numero, 16, null, null, "COSTO"),
                            C("VIDA_UTIL_HORAS", "VIDA UTIL HORAS", false, "Horas de marcha que declara el fabricante.", "8000", Tipo.Numero, 15),
                            C("VIDA_UTIL_DIAS", "VIDA UTIL DIAS", false, "Días de calendario.", "", Tipo.Entero, 14),
                            C("VIDA_UTIL_CICLOS", "VIDA UTIL CICLOS", false, "Maniobras.", "", Tipo.Numero, 15),
                            C("DESCRIPCION", "DESCRIPCION", false, "Detalle técnico.", "Una hilera de bolas, sello de contacto.", Tipo.Texto, 36),
                            C("HABILITADO", "HABILITADO", false, "Solo al actualizar: NO lo da de baja.", "SI", Tipo.SiNo, 12, SINO),
                            C("TIPO", "TIPO", false, "Código o nombre, como en la hoja TIPOS.", "MEC-RODAMIENTO", Tipo.Lista, 18, null, "TIPOS", "TIPO REPUESTO"),
                            C("METODO_SALIDA", "METODO SALIDA", false, "Excepción del repuesto. «Según bodega» la quita.", "", Tipo.Lista, 16, METODOS_REP),
                            C("LARGO_CM", "LARGO CM", false, "Para el mapa 3D.", "", Tipo.Numero, 10, null, null, "LARGO"),
                            C("ANCHO_CM", "ANCHO CM", false, "", "", Tipo.Numero, 10, null, null, "ANCHO"),
                            C("ALTO_CM", "ALTO CM", false, "", "", Tipo.Numero, 10, null, null, "ALTO"),
                            C("PESO_KG", "PESO KG", false, "Por unidad. El mapa avisa la sobrecarga del nivel.", "", Tipo.Numero, 10, null, null, "PESO")
                        } },
                    new Hoja { clave = "UMBRALES", titulo = "UMBRALES", icono = "mdi-chart-bell-curve-cumulative",
                        descripcion = "Mínimo, máximo y punto de reposición de cada repuesto en cada bodega. Si ya existe, se reemplaza.",
                        columnas = new List<Columna> {
                            C("REPUESTO", "REPUESTO", true, "Código del repuesto (de la base o de la hoja REPUESTOS).", "EJEMPLO-ROD-001", Tipo.Texto, 20),
                            C("BODEGA", "BODEGA", true, "Código o nombre de la bodega.", "EJEMPLO-CENTRAL", Tipo.Texto, 20),
                            C("MINIMO", "MINIMO", true, "Bajo este número el repuesto queda en alerta.", "2", Tipo.Numero, 10),
                            C("MAXIMO", "MAXIMO", false, "Hasta cuánto se repone.", "10", Tipo.Numero, 10),
                            C("PUNTO_REPOSICION", "PUNTO REPOSICION", false, "Cuándo pedir: entre el mínimo y el máximo.", "4", Tipo.Numero, 16, null, null, "REPOSICION"),
                            C("OBSERVACION", "OBSERVACION", false, "", "", Tipo.Texto, 26)
                        } },
                    new Hoja { clave = "STOCK_INICIAL", titulo = "STOCK INICIAL", icono = "mdi-tray-arrow-down",
                        descripcion = "Lo que hay hoy en cada bodega y rack. Entra como un ingreso, una sola vez: si ya hay stock en ese rack (y lote), la fila se rechaza.",
                        columnas = new List<Columna> {
                            C("REPUESTO", "REPUESTO", true, "Código del repuesto.", "EJEMPLO-ROD-001", Tipo.Texto, 20),
                            C("BODEGA", "BODEGA", true, "Código o nombre de la bodega.", "EJEMPLO-CENTRAL", Tipo.Texto, 20),
                            C("RACK", "RACK", false, "Código o nombre del rack. Obligatorio si la bodega tiene racks.", "Pasillo A · Rack 01", Tipo.Texto, 20, null, null, "UBICACION"),
                            C("CANTIDAD", "CANTIDAD", true, "Mayor que cero.", "12", Tipo.Numero, 11),
                            C("COSTO_UNITARIO", "COSTO UNITARIO", false, "En pesos. Valoriza el stock.", "8500", Tipo.Numero, 14, null, null, "COSTO"),
                            C("LOTE", "LOTE", false, "Obligatorio si el repuesto controla lote.", "", Tipo.Texto, 14),
                            C("VENCE", "VENCE", false, "Fecha de vencimiento del lote.", "", Tipo.Fecha, 13, null, null, "VENCIMIENTO", "FECHA VENCIMIENTO"),
                            C("OBSERVACION", "OBSERVACION", false, "", "", Tipo.Texto, 26)
                        } },
                    /* Bloque 368: donde sirve cada repuesto, lo mismo que se vincula
                       desde la ficha del activo. */
                    new Hoja { clave = "COMPATIBILIDADES", titulo = "COMPATIBILIDADES", icono = "mdi-puzzle-outline",
                        descripcion = "En qué equipos o componentes sirve cada repuesto. El activo tiene que existir (carga de Activos). Si ya está vinculado, se omite.",
                        columnas = new List<Columna> {
                            C("REPUESTO", "REPUESTO", true, "Código o nombre del repuesto (de la base o de la hoja REPUESTOS).", "EJEMPLO-ROD-001", Tipo.Texto, 20),
                            C("ACTIVO", "ACTIVO", true, "Código o nombre del activo, como en la hoja ACTIVOS EXISTENTES.", "", Tipo.Lista, 22, null, "ACTIVOS"),
                            C("COMPONENTE", "COMPONENTE", false, "Si sirve a una pieza del activo: su nombre. Vacío: al activo entero.", "", Tipo.Texto, 20),
                            C("OBSERVACION", "OBSERVACION", false, "", "", Tipo.Texto, 26)
                        } }
                }
            });

            /* Los que siguen se encienden a medida que su PRC_CARGA_<MODULO>
               queda probado: la pantalla los muestra "en preparacion". */
            /* ACTIVOS (bloque 367): todo lo que pide la ficha de «Nuevo activo»
               en sus 6 pasos, más los repuestos compatibles. Las fotos se
               agregan después desde el Centro de activos. */
            m.Add(new Modulo
            {
                clave = "ACTIVOS",
                nombre = "Activos",
                descripcion = "Equipos y su jerarquía, datos técnicos, componentes, variables, medidores y los repuestos compatibles con cada uno.",
                icono = "mdi-robot-industrial",
                color = "#087BEA",
                procedimiento = "PRC_CARGA_ACTIVOS",
                disponible = true,
                ayudas = new[] { "PLANTAS", "AREAS", "TIPOS ACTIVO", "ESTADOS", "CRITICIDADES", "CENTROS COSTO", "UNIDADES", "ACTIVOS", "TIPOS COMPONENTE", "POSICIONES", "REPUESTOS" },
                hojas = new List<Hoja>
                {
                    new Hoja { clave = "ACTIVOS", titulo = "ACTIVOS", icono = "mdi-robot-industrial",
                        descripcion = "Una fila por equipo, como los pasos 1 y 2 de la ficha. Con el mismo código (o el mismo nombre en la planta, si no lleva código) se actualiza.",
                        columnas = new List<Columna> {
                            C("CODIGO", "CODIGO", false, "Vacío: se numera solo (ACT-<n>). Si lo escribe, queda ACT-<lo escrito>. No se cambia después: va en la etiqueta.", "EJEMPLO-HORNO-01", Tipo.Texto, 18),
                            C("NOMBRE", "NOMBRE", true, "Cómo lo reconoce la gente.", "Horno túnel línea 1", Tipo.Texto, 30),
                            C("PLANTA", "PLANTA", true, "Tal como aparece en la hoja PLANTAS.", "Planta Renca", Tipo.Lista, 20, null, "PLANTAS"),
                            C("AREA", "AREA", false, "Área de esa planta, como en la hoja AREAS.", "Producción", Tipo.Lista, 20, null, "AREAS", "UBICACION"),
                            C("TIPO", "TIPO", true, "Como en la hoja TIPOS ACTIVO. Si no existe, se crea.", "Horno", Tipo.Lista, 18, null, "TIPOS ACTIVO", "TIPO ACTIVO"),
                            C("MODELO", "MODELO", false, "Si no existe para ese tipo, se crea.", "HT-2000", Tipo.Texto, 16),
                            C("MARCA", "MARCA", false, "El fabricante.", "Siemens", Tipo.Texto, 16, null, null, "FABRICANTE"),
                            C("SERIE", "N SERIE", false, "Número de serie de la placa.", "SN-88231", Tipo.Texto, 16, null, null, "SERIE", "NUMERO SERIE"),
                            C("ESTADO", "ESTADO", true, "Como en la hoja ESTADOS.", "Operativo", Tipo.Lista, 16, null, "ESTADOS"),
                            C("CRITICIDAD", "CRITICIDAD", true, "Baja, Media, Alta o Crítica.", "Alta", Tipo.Lista, 13, null, "CRITICIDADES"),
                            C("CENTRO_COSTO", "CENTRO COSTO", false, "Como en la hoja CENTROS COSTO.", "", Tipo.Lista, 18, null, "CENTROS COSTO", "CENTRO DE COSTO"),
                            C("DEPENDE_DE", "DEPENDE DE", false, "Código o nombre del activo principal (de la base o de esta hoja). Vacío: es una máquina principal.", "", Tipo.Texto, 20, null, null, "ACTIVO PADRE", "PADRE"),
                            C("ANIO_FABRICACION", "ANIO FABRICACION", false, "Año, por ejemplo 2019.", "2019", Tipo.Entero, 14, null, null, "AÑO FABRICACION", "AÑO"),
                            C("PUESTA_MARCHA", "PUESTA EN MARCHA", false, "Fecha dd-mm-aaaa. No puede ser futura.", "", Tipo.Fecha, 16, null, null, "PUESTA MARCHA", "FECHA PUESTA EN MARCHA"),
                            C("EN_USO", "EN USO", false, "NO lo deja deshabilitado. Vacío: SI.", "SI", Tipo.SiNo, 9, SINO),
                            C("DESCRIPCION", "DESCRIPCION", false, "", "Horno a gas de 3 zonas", Tipo.Texto, 34)
                        } },
                    new Hoja { clave = "DATOS_TECNICOS", titulo = "DATOS TECNICOS", icono = "mdi-format-list-bulleted-type",
                        descripcion = "Paso 3 de la ficha: una fila por dato (potencia, voltaje, capacidad…). Si el activo ya tenía ese dato, se reemplaza.",
                        columnas = new List<Columna> {
                            C("ACTIVO", "ACTIVO", true, "Código o nombre del activo (de la base o de la hoja ACTIVOS).", "EJEMPLO-HORNO-01", Tipo.Texto, 20),
                            C("DATO", "DATO", true, "Qué característica: Potencia, Voltaje, Capacidad…", "Potencia", Tipo.Texto, 20, null, null, "ATRIBUTO", "CARACTERISTICA"),
                            C("VALOR", "VALOR", true, "El valor tal como está en la placa o el manual.", "75", Tipo.Texto, 14),
                            C("UNIDAD", "UNIDAD", false, "Como en la hoja UNIDADES.", "KW", Tipo.Lista, 12, null, "UNIDADES")
                        } },
                    new Hoja { clave = "COMPONENTES", titulo = "COMPONENTES", icono = "mdi-cog-outline",
                        descripcion = "Paso 4: las piezas que importan de cada equipo. Con el mismo nombre en el mismo activo se omite (no se duplica).",
                        columnas = new List<Columna> {
                            C("ACTIVO", "ACTIVO", true, "Código o nombre del activo.", "EJEMPLO-HORNO-01", Tipo.Texto, 20),
                            C("NOMBRE", "NOMBRE", true, "Cómo se le dice a esa pieza.", "Motor ventilador", Tipo.Texto, 26),
                            C("QUE_ES", "QUE ES", false, "Como en la hoja TIPOS COMPONENTE. Si no existe, se crea. Vacío: Otro.", "Motor", Tipo.Lista, 16, null, "TIPOS COMPONENTE", "TIPO"),
                            C("DONDE_VA", "DONDE VA", false, "Como en la hoja POSICIONES. Si no existe, se crea.", "Lado accionamiento", Tipo.Lista, 18, null, "POSICIONES", "POSICION"),
                            C("CRITICIDAD", "CRITICIDAD", false, "Vacío: la del activo.", "", Tipo.Lista, 13, null, "CRITICIDADES"),
                            C("FECHA_INSTALACION", "FECHA INSTALACION", false, "Vacío: hoy.", "", Tipo.Fecha, 16, null, null, "INSTALACION"),
                            C("DESCRIPCION", "DESCRIPCION", false, "", "", Tipo.Texto, 30)
                        } },
                    new Hoja { clave = "VARIABLES", titulo = "VARIABLES", icono = "mdi-thermometer",
                        descripcion = "Paso 5: lo que se mide para saber cómo está (temperatura, presión, vibración) y su rango normal. Si ya existe en ese activo, se omite.",
                        columnas = new List<Columna> {
                            C("ACTIVO", "ACTIVO", true, "Código o nombre del activo.", "EJEMPLO-HORNO-01", Tipo.Texto, 20),
                            C("COMPONENTE", "COMPONENTE", false, "Si se mide en una pieza: su nombre (de la base o de la hoja COMPONENTES).", "", Tipo.Texto, 20),
                            C("VARIABLE", "VARIABLE", true, "Qué se mide. Si no existe, se crea.", "Temperatura", Tipo.Texto, 18, null, null, "QUE SE MIDE"),
                            C("UNIDAD", "UNIDAD", true, "Como en la hoja UNIDADES.", "°C", Tipo.Lista, 10, null, "UNIDADES"),
                            C("MINIMO", "MINIMO", false, "Debajo de esto, SIGMA avisa.", "180", Tipo.Numero, 10),
                            C("MAXIMO", "MAXIMO", false, "Encima de esto, SIGMA avisa.", "240", Tipo.Numero, 10),
                            C("ADVERTENCIA", "ADVERTENCIA", false, "Valor de advertencia.", "", Tipo.Numero, 12),
                            C("CRITICO", "CRITICO", false, "Valor crítico.", "", Tipo.Numero, 10),
                            C("FRECUENCIA_HORAS", "FRECUENCIA HORAS", false, "Cada cuántas horas se espera una lectura.", "", Tipo.Entero, 16, null, null, "FRECUENCIA")
                        } },
                    new Hoja { clave = "MEDIDORES", titulo = "MEDIDORES", icono = "mdi-speedometer",
                        descripcion = "Paso 6: cuánto ha trabajado (horas, ciclos, km), con la lectura de hoy. Si ya existe en ese activo, se omite.",
                        columnas = new List<Columna> {
                            C("ACTIVO", "ACTIVO", true, "Código o nombre del activo.", "EJEMPLO-HORNO-01", Tipo.Texto, 20),
                            C("NOMBRE", "NOMBRE", true, "Horómetro, Contador de ciclos, Odómetro…", "Horómetro", Tipo.Texto, 20),
                            C("UNIDAD", "UNIDAD", true, "Como en la hoja UNIDADES (HORA, CICLO, KM…).", "HORA", Tipo.Lista, 10, null, "UNIDADES"),
                            C("LECTURA_ACTUAL", "LECTURA ACTUAL", false, "Lo que marca hoy. Vacío: 0.", "12500", Tipo.Numero, 14, null, null, "LECTURA", "VALOR ACTUAL"),
                            C("PERMITE_REINICIO", "PERMITE REINICIO", false, "SI si el contador puede volver a cero.", "NO", Tipo.SiNo, 14, SINO, null, "REINICIO"),
                            C("VALOR_REINICIO", "VALOR REINICIO", false, "Desde qué valor parte al reiniciar.", "", Tipo.Numero, 13)
                        } },
                    new Hoja { clave = "REPUESTOS_COMPATIBLES", titulo = "REPUESTOS COMPATIBLES", icono = "mdi-puzzle-outline",
                        descripcion = "Los repuestos de bodega que le sirven a cada equipo o componente. El repuesto tiene que existir (carga de Inventario). Si ya está vinculado, se omite.",
                        columnas = new List<Columna> {
                            C("ACTIVO", "ACTIVO", true, "Código o nombre del activo.", "EJEMPLO-HORNO-01", Tipo.Texto, 20),
                            C("COMPONENTE", "COMPONENTE", false, "Si es para una pieza: su nombre.", "", Tipo.Texto, 20),
                            C("REPUESTO", "REPUESTO", true, "Código o nombre del repuesto, como en la hoja REPUESTOS.", "ROD-6205", Tipo.Lista, 20, null, "REPUESTOS"),
                            C("OBSERVACION", "OBSERVACION", false, "", "", Tipo.Texto, 26)
                        } }
                }
            });
            m.Add(new Modulo { clave = "MANTENIMIENTO", nombre = "Mantenimiento", icono = "mdi-calendar-check", color = "#007F8A",
                descripcion = "Tareas, checklists con sus ítems, planes y su programación sobre cada equipo.", procedimiento = "PRC_CARGA_MANTENIMIENTO", hojas = new List<Hoja>() });

            _modulos = m;
            return m;
        }

        public static Modulo Buscar(string clave)
        {
            return Modulos().FirstOrDefault(x => string.Equals(x.clave, clave, StringComparison.OrdinalIgnoreCase));
        }

        // ================================================================ texto
        /// <summary>Encabezado o nombre de hoja comparable: sin acentos, mayusculas, "_" = espacio.</summary>
        public static string Normal(string t)
        {
            if (string.IsNullOrEmpty(t)) return "";
            string d = t.Normalize(NormalizationForm.FormD);
            StringBuilder sb = new StringBuilder();
            foreach (char c in d)
                if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark) sb.Append(c);
            string s = sb.ToString().ToUpperInvariant().Replace("_", " ").Replace("(*)", "").Replace("*", "");
            s = System.Text.RegularExpressions.Regex.Replace(s, @"[^A-Z0-9 ]", " ");
            return System.Text.RegularExpressions.Regex.Replace(s, @"\s+", " ").Trim();
        }

        // ================================================================ plantilla
        public byte[] Plantilla(string clave)
        {
            Modulo mod = Buscar(clave);
            if (mod == null || !mod.disponible) throw new Exception("El módulo no tiene plantilla todavía.");
            int cliente = Session.ClienteId();

            Color morado = ColorTranslator.FromHtml("#6732F4"), tinta = ColorTranslator.FromHtml("#17223B"),
                  suave = ColorTranslator.FromHtml("#F2EFFF"), azulSuave = ColorTranslator.FromHtml("#EAF4FF"),
                  linea = ColorTranslator.FromHtml("#E2E7F0"), gris = ColorTranslator.FromHtml("#68738A");

            using (ExcelPackage x = new ExcelPackage())
            {
                // ---- LEAME
                ExcelWorksheet lea = x.Workbook.Worksheets.Add("LEAME");
                lea.Cells["A1"].Value = "SIGMA · Carga de datos · " + mod.nombre;
                lea.Cells["A1"].Style.Font.Size = 16; lea.Cells["A1"].Style.Font.Bold = true; lea.Cells["A1"].Style.Font.Color.SetColor(morado);
                lea.Cells["A2"].Value = mod.descripcion; lea.Cells["A2"].Style.Font.Color.SetColor(gris);
                int r = 4;
                string[] reglas = {
                    "1. Complete las hojas en el orden en que aparecen: cada una puede nombrar lo que crea una hoja anterior de este mismo archivo.",
                    "2. Las columnas con encabezado MORADO son obligatorias para un registro nuevo; las celestes son opcionales.",
                    "3. Pase el mouse por cada encabezado para ver qué escribir. Las listas desplegables y las hojas de ayuda (al final) muestran los valores válidos.",
                    "4. La fila que empieza con EJEMPLO se ignora: bórrela o déjela.",
                    "5. Con el mismo código se ACTUALIZA: las celdas con dato reemplazan y las vacías conservan lo que había. Volver a cargar el archivo no duplica.",
                    "6. Primero REVISE: SIGMA dice qué pasará con cada fila (crear, actualizar, error) sin escribir nada. Después cargue.",
                    "7. Una fila con error no detiene la carga: se informa con su hoja, fila, columna y motivo, y se descarga en Excel para corregir."
                };
                foreach (string t in reglas) { lea.Cells[r, 1].Value = t; r++; }
                r++;
                lea.Cells[r, 1].Value = "HOJAS"; lea.Cells[r, 1].Style.Font.Bold = true; r++;
                foreach (Hoja h in mod.hojas) { lea.Cells[r, 1].Value = h.titulo + " — " + h.descripcion; r++; }
                lea.Column(1).Width = 150;
                lea.Cells["A4:A" + r].Style.WrapText = true;

                // ---- hojas de ayuda (se crean antes para poder referenciarlas en las listas)
                Dictionary<string, int> filasAyuda = new Dictionary<string, int>();
                List<ExcelWorksheet> ayudas = new List<ExcelWorksheet>();
                foreach (string a in mod.ayudas ?? new string[0])
                {
                    DataTable t = Ayuda(cliente, a);
                    ExcelWorksheet w = x.Workbook.Worksheets.Add(NombreAyuda(a));
                    w.Cells["A1"].LoadFromDataTable(t, true);
                    using (ExcelRange cab = w.Cells[1, 1, 1, Math.Max(1, t.Columns.Count)])
                    {
                        cab.Style.Font.Bold = true; cab.Style.Fill.PatternType = ExcelFillStyle.Solid; cab.Style.Fill.BackgroundColor.SetColor(suave);
                        cab.Style.Font.Color.SetColor(tinta);
                    }
                    for (int c = 1; c <= t.Columns.Count; c++) w.Column(c).Width = c == 1 ? 30 : 26;
                    w.View.FreezePanes(2, 1);
                    w.TabColor = gris;
                    filasAyuda[a] = t.Rows.Count;
                    ayudas.Add(w);
                }

                // ---- hojas de datos, en orden y antes que las ayudas
                int pos = 2;
                foreach (Hoja h in mod.hojas)
                {
                    ExcelWorksheet w = x.Workbook.Worksheets.Add(h.titulo);
                    x.Workbook.Worksheets.MoveBefore(h.titulo, ayudas.Count > 0 ? ayudas[0].Name : "LEAME");
                    w.TabColor = morado;
                    for (int c = 0; c < h.columnas.Count; c++)
                    {
                        Columna col = h.columnas[c];
                        ExcelRange cab = w.Cells[1, c + 1];
                        cab.Value = col.titulo;
                        cab.Style.Font.Bold = true;
                        cab.Style.Fill.PatternType = ExcelFillStyle.Solid;
                        cab.Style.Fill.BackgroundColor.SetColor(col.obligatoria ? morado : azulSuave);
                        cab.Style.Font.Color.SetColor(col.obligatoria ? Color.White : tinta);
                        cab.Style.Border.Bottom.Style = ExcelBorderStyle.Thin; cab.Style.Border.Bottom.Color.SetColor(linea);
                        string nota = (col.obligatoria ? "OBLIGATORIA. " : "") + (col.ayuda ?? "") +
                                      (col.valores != null ? " Valores: " + string.Join(", ", col.valores) + "." : "") +
                                      (col.ayudaHoja != null ? " Vea la hoja " + NombreAyuda(col.ayudaHoja) + "." : "");
                        if (nota.Trim().Length > 0) { var cm = cab.AddComment(nota.Trim(), "SIGMA"); cm.AutoFit = true; }
                        w.Column(c + 1).Width = col.ancho;

                        // ejemplo (se ignora al leer: la fila empieza con EJEMPLO)
                        if (!string.IsNullOrEmpty(col.ejemplo))
                        {
                            ExcelRange ej = w.Cells[2, c + 1];
                            double num;
                            if ((col.tipo == Tipo.Numero || col.tipo == Tipo.Entero) && double.TryParse(col.ejemplo, NumberStyles.Any, CultureInfo.InvariantCulture, out num)) ej.Value = num;
                            else ej.Value = col.ejemplo;
                            ej.Style.Font.Color.SetColor(gris); ej.Style.Font.Italic = true;
                        }
                        if (col.tipo == Tipo.Texto) w.Column(c + 1).Style.Numberformat.Format = "@";
                        if (col.tipo == Tipo.Fecha) w.Column(c + 1).Style.Numberformat.Format = "dd-mm-yyyy";

                        // listas desplegables
                        string rango = ExcelCellBase.GetAddress(2, c + 1, MAX_FILAS, c + 1);
                        if (col.valores != null)
                        {
                            var v = w.DataValidations.AddListValidation(rango);
                            foreach (string val in col.valores) v.Formula.Values.Add(val);
                            v.AllowBlank = true; v.ShowErrorMessage = false;
                        }
                        else if (col.ayudaHoja != null && filasAyuda.ContainsKey(col.ayudaHoja) && filasAyuda[col.ayudaHoja] > 0)
                        {
                            var v = w.DataValidations.AddListValidation(rango);
                            v.Formula.ExcelFormula = "'" + NombreAyuda(col.ayudaHoja) + "'!$A$2:$A$" + (filasAyuda[col.ayudaHoja] + 1);
                            v.AllowBlank = true; v.ShowErrorMessage = false;   // aviso suave: tambien acepta el codigo
                        }
                    }
                    w.View.FreezePanes(2, 1);
                    w.Row(1).Height = 22;
                    pos++;
                }
                x.Workbook.Worksheets.MoveToStart("LEAME");
                return x.GetAsByteArray();
            }
        }

        /* Las ayudas que se llaman igual que una hoja de datos (BODEGAS, RACKS)
           van como "... EXISTENTES": dos hojas no pueden tener el mismo nombre,
           y al leer se reconocen las de datos por su nombre exacto. */
        private static string NombreAyuda(string lista)
        {
            return lista == "BODEGAS" || lista == "RACKS" || lista == "ACTIVOS" ? lista + " EXISTENTES" : lista;
        }

        private static DataTable Ayuda(int cliente, string lista)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "SEL_CARGA_MASIVA_AYUDA";
            cmd.Parameters.AddWithValue("@CLIENTE", cliente);
            cmd.Parameters.AddWithValue("@LISTA", lista);
            return Conexion.GetDataTable(cmd);
        }

        // ================================================================ lectura
        public class Lectura
        {
            public DataTable filas;
            public Dictionary<string, int> porHoja = new Dictionary<string, int>();
            public List<string> avisos = new List<string>();
        }

        /// <summary>
        /// El archivo a filas JSON. Encabezados y hojas se reconocen sin importar
        /// mayusculas, acentos ni "_"; los numeros y fechas de Excel se pasan a un
        /// formato unico (punto decimal, yyyy-MM-dd) para que la base no adivine.
        /// </summary>
        public Lectura Leer(Modulo mod, byte[] archivo)
        {
            Lectura l = new Lectura();
            DataTable t = new DataTable();
            t.Columns.Add("cmf_carga", typeof(int));
            t.Columns.Add("cmf_hoja", typeof(string));
            t.Columns.Add("cmf_fila", typeof(int));
            t.Columns.Add("cmf_datos", typeof(string));
            t.Columns.Add("cmf_resultado", typeof(string));
            t.Columns.Add("cmf_id", typeof(int));
            JavaScriptSerializer js = new JavaScriptSerializer();
            int total = 0;

            using (MemoryStream ms = new MemoryStream(archivo))
            using (ExcelPackage x = new ExcelPackage(ms))
            {
                foreach (Hoja h in mod.hojas)
                {
                    ExcelWorksheet w = x.Workbook.Worksheets.FirstOrDefault(s => Normal(s.Name) == Normal(h.titulo) || Normal(s.Name) == Normal(h.clave));
                    if (w == null || w.Dimension == null) { l.porHoja[h.clave] = 0; continue; }

                    // encabezado -> columna
                    Dictionary<int, Columna> mapa = new Dictionary<int, Columna>();
                    int ultCol = w.Dimension.End.Column, ultFila = w.Dimension.End.Row;
                    for (int c = 1; c <= ultCol; c++)
                    {
                        string enc = Normal(Convert.ToString(w.Cells[1, c].Value));
                        if (enc.Length == 0) continue;
                        Columna col = h.columnas.FirstOrDefault(k => Normal(k.titulo) == enc || Normal(k.clave) == enc ||
                                                                     (k.sinonimos != null && k.sinonimos.Any(s => Normal(s) == enc)));
                        if (col != null && !mapa.Values.Contains(col)) mapa[c] = col;
                        else if (col == null) l.avisos.Add("Hoja " + h.titulo + ": la columna «" + Convert.ToString(w.Cells[1, c].Value) + "» no se usa y se ignora.");
                    }
                    foreach (Columna obl in h.columnas.Where(k => k.obligatoria && !mapa.Values.Contains(k)))
                        l.avisos.Add("Hoja " + h.titulo + ": falta la columna " + obl.titulo + ".");

                    int n = 0;
                    for (int f = 2; f <= ultFila; f++)
                    {
                        Dictionary<string, string> d = new Dictionary<string, string>();
                        bool vacia = true, ejemplo = false;
                        foreach (KeyValuePair<int, Columna> kv in mapa)
                        {
                            string v = Valor(w.Cells[f, kv.Key], kv.Value.tipo);
                            if (v.Length == 0) continue;
                            if (vacia && kv.Key == mapa.Keys.Min() && v.StartsWith("EJEMPLO", StringComparison.OrdinalIgnoreCase)) ejemplo = true;
                            vacia = false;
                            d[kv.Value.clave] = v;
                        }
                        // la primera columna con EJEMPLO marca la fila de muestra
                        string primera = mapa.Count > 0 ? Valor(w.Cells[f, mapa.Keys.Min()], Tipo.Texto) : "";
                        if (primera.StartsWith("EJEMPLO", StringComparison.OrdinalIgnoreCase)) ejemplo = true;
                        if (vacia || ejemplo) continue;
                        if (++total > MAX_FILAS) throw new Exception("La planilla supera las " + MAX_FILAS.ToString("N0", new CultureInfo("es-CL")) + " filas: divídala en partes.");
                        t.Rows.Add(0, h.clave, f, js.Serialize(d), DBNull.Value, DBNull.Value);
                        n++;
                    }
                    l.porHoja[h.clave] = n;
                }
            }
            l.filas = t;
            return l;
        }

        private static string Valor(ExcelRange celda, Tipo tipo)
        {
            object v = celda.Value;
            if (v == null) return "";
            if (v is DateTime) return ((DateTime)v).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            if (v is bool) return (bool)v ? "SI" : "NO";
            if (v is double || v is decimal || v is int || v is long || v is float)
            {
                double d = Convert.ToDouble(v, CultureInfo.InvariantCulture);
                if (tipo == Tipo.Fecha) { try { return DateTime.FromOADate(d).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture); } catch { } }
                return d.ToString("0.############", CultureInfo.InvariantCulture);
            }
            string s = Convert.ToString(v, CultureInfo.InvariantCulture).Replace(' ', ' ').Trim();
            if (s.Length == 0) return "";
            if (tipo == Tipo.Numero || tipo == Tipo.Entero)
            {
                string n = s.Replace(" ", "").Replace("$", "");
                if (n.Contains(",") && n.Contains(".")) n = n.Replace(".", "").Replace(",", ".");   // 1.234,5
                else if (n.Contains(",")) n = n.Replace(",", ".");
                return n;
            }
            if (tipo == Tipo.Fecha)
            {
                DateTime f;
                string[] formatos = { "dd-MM-yyyy", "d-M-yyyy", "dd/MM/yyyy", "d/M/yyyy", "yyyy-MM-dd", "dd-MM-yy", "dd/MM/yy" };
                if (DateTime.TryParseExact(s, formatos, CultureInfo.InvariantCulture, DateTimeStyles.None, out f)) return f.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                return s;   // la base informa que no se entiende
            }
            return s;
        }

        // ================================================================ ejecucion
        public class Inicio { public int id; public Dictionary<string, int> porHoja; public List<string> avisos; }

        /// <summary>Lee, sube y deja el proceso corriendo en segundo plano.</summary>
        public Inicio Iniciar(string clave, string archivoNombre, byte[] archivo, string modo, string existentes)
        {
            Modulo mod = Buscar(clave);
            if (mod == null || !mod.disponible) throw new Exception("Ese módulo todavía no se puede cargar.");
            if (archivo == null || archivo.Length == 0) throw new Exception("El archivo está vacío.");
            if (!(archivoNombre ?? "").ToLowerInvariant().EndsWith(".xlsx"))
                throw new Exception("El archivo tiene que ser .xlsx (libro de Excel). Si es .xls o .csv, ábralo y guárdelo como .xlsx.");

            int cliente = Session.ClienteId(), usuario = Convert.ToInt32(Session.UsuarioId());
            Lectura l;
            try { l = Leer(mod, archivo); }
            catch (Exception ex)
            {
                if (ex.Message.StartsWith("La planilla")) throw;
                throw new Exception("No se pudo leer el archivo: " + ex.Message);
            }
            if (l.filas.Rows.Count == 0)
                throw new Exception("La planilla no tiene filas para cargar en las hojas " + string.Join(", ", mod.hojas.Select(h => h.titulo)) + "." +
                                    (l.avisos.Count > 0 ? " " + string.Join(" ", l.avisos.Take(3)) : ""));

            int id = Crear(cliente, usuario, mod.clave, archivoNombre, modo, existentes);
            try
            {
                foreach (DataRow r in l.filas.Rows) r["cmf_carga"] = id;
                using (SqlConnection cn = new SqlConnection(Conexion.GetConnectionString()))
                {
                    cn.Open();
                    using (SqlBulkCopy b = new SqlBulkCopy(cn) { DestinationTableName = "dbo.Carga_Masiva_Fila", BulkCopyTimeout = 0, BatchSize = 5000 })
                    {
                        foreach (DataColumn c in l.filas.Columns) b.ColumnMappings.Add(c.ColumnName, c.ColumnName);
                        b.WriteToServer(l.filas);
                    }
                }
                Exec("UPD_CARGA_MASIVA_LEIDA", "@CLIENTE", cliente, "@ID", id);
            }
            catch (Exception ex)
            {
                Exec("UPD_CARGA_MASIVA_FALLA", "@ID", id, "@MENSAJE", "No se pudo subir la planilla: " + ex.Message);
                throw;
            }
            Encolar(id, mod.procedimiento);
            return new Inicio { id = id, porHoja = l.porHoja, avisos = l.avisos };
        }

        /// <summary>"Cargar ahora" desde una revision: mismas filas, sin volver a subir.</summary>
        public int CargarRevision(int origen, string existentes)
        {
            int cliente = Session.ClienteId(), usuario = Convert.ToInt32(Session.UsuarioId());
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "INS_CARGA_MASIVA_DESDE";
            cmd.Parameters.AddWithValue("@ID", 0).Direction = ParameterDirection.Output;
            cmd.Parameters.AddWithValue("@CLIENTE", cliente);
            cmd.Parameters.AddWithValue("@USUARIO", usuario);
            cmd.Parameters.AddWithValue("@ORIGEN", origen);
            cmd.Parameters.AddWithValue("@EXISTENTES", string.IsNullOrEmpty(existentes) ? (object)DBNull.Value : existentes);
            Conexion.GetDataTable(cmd);
            int id = Convert.ToInt32(cmd.Parameters["@ID"].Value);
            DataRow c = Estado(id).Rows.Count > 0 ? Estado(id).Rows[0] : null;
            Modulo mod = c != null ? Buscar(Convert.ToString(c["MODULO"])) : null;
            if (mod == null) throw new Exception("No se encontró el módulo de la revisión.");
            Encolar(id, mod.procedimiento);
            return id;
        }

        private static int Crear(int cliente, int usuario, string modulo, string archivo, string modo, string existentes)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "INS_CARGA_MASIVA";
            cmd.Parameters.AddWithValue("@ID", 0).Direction = ParameterDirection.Output;
            cmd.Parameters.AddWithValue("@CLIENTE", cliente);
            cmd.Parameters.AddWithValue("@USUARIO", usuario);
            cmd.Parameters.AddWithValue("@MODULO", modulo);
            cmd.Parameters.AddWithValue("@ARCHIVO", Path.GetFileName(archivo ?? ""));
            cmd.Parameters.AddWithValue("@MODO", modo == "CARGAR" ? "CARGAR" : "VALIDAR");
            cmd.Parameters.AddWithValue("@EXISTENTES", existentes == "OMITIR" ? "OMITIR" : "ACTUALIZAR");
            Conexion.GetDataTable(cmd);
            return Convert.ToInt32(cmd.Parameters["@ID"].Value);
        }

        /* En segundo plano y sin sesion: la conexion sale de la configuracion y
           el cliente y el usuario ya quedaron en la fila de Carga_Masiva. */
        private static void Encolar(int id, string procedimiento)
        {
            HostingEnvironment.QueueBackgroundWorkItem(ct =>
            {
                try
                {
                    using (SqlConnection cn = new SqlConnection(Conexion.GetConnectionString()))
                    {
                        cn.Open();
                        using (SqlCommand cmd = new SqlCommand(procedimiento, cn) { CommandType = CommandType.StoredProcedure, CommandTimeout = 0 })
                        {
                            cmd.Parameters.AddWithValue("@CARGA", id);
                            cmd.ExecuteNonQuery();
                        }
                    }
                }
                catch (Exception ex)
                {
                    try { Exec("UPD_CARGA_MASIVA_FALLA", "@ID", id, "@MENSAJE", ex.Message); } catch { }
                }
            });
        }

        private static DataTable Exec(string sp, params object[] pares)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = sp;
            for (int i = 0; i + 1 < pares.Length; i += 2) cmd.Parameters.AddWithValue((string)pares[i], pares[i + 1] ?? DBNull.Value);
            return Conexion.GetDataTable(cmd);
        }

        // ================================================================ consultas
        public DataTable Estado(int id)
        {
            return Exec("SEL_CARGA_MASIVA", "@CLIENTE", Session.ClienteId(), "@ID", id);
        }

        /// <summary>Estado y resumen por hoja (el SP devuelve dos tablas).</summary>
        public DataSet EstadoCompleto(int id)
        {
            DataSet ds = new DataSet();
            using (SqlConnection cn = new SqlConnection(Conexion.GetConnectionString()))
            using (SqlCommand cmd = new SqlCommand("SEL_CARGA_MASIVA", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ID", id);
                using (SqlDataAdapter a = new SqlDataAdapter(cmd)) a.Fill(ds);
            }
            return ds;
        }

        public DataTable Historial() { return Exec("SEL_CARGA_MASIVA_HISTORIAL", "@CLIENTE", Session.ClienteId()); }
        public DataTable Errores(int id) { return Exec("SEL_CARGA_MASIVA_ERRORES", "@CLIENTE", Session.ClienteId(), "@ID", id); }
        public DataTable ResumenModulos() { return Exec("SEL_CARGA_MASIVA_MODULOS", "@CLIENTE", Session.ClienteId()); }
        public DataTable Incidencias() { return Exec("SEL_CARGA_MASIVA_INCIDENCIAS", "@CLIENTE", Session.ClienteId()); }

        public Respuesta Incidencia(int? carga, string comentario, string contexto)
        {
            Respuesta r = new Respuesta();
            try
            {
                SqlCommand cmd = new SqlCommand();
                cmd.CommandText = "INS_CARGA_MASIVA_INCIDENCIA";
                cmd.Parameters.AddWithValue("@ID", 0).Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.Parameters.AddWithValue("@CARGA", carga.HasValue && carga.Value > 0 ? (object)carga.Value : DBNull.Value);
                cmd.Parameters.AddWithValue("@COMENTARIO", comentario ?? "");
                cmd.Parameters.AddWithValue("@CONTEXTO", string.IsNullOrEmpty(contexto) ? (object)DBNull.Value : contexto);
                DataTable dt = Conexion.GetDataTable(cmd);
                r.codigo = Convert.ToInt32(cmd.Parameters["@ID"].Value);
                r.detalle = dt.Rows.Count > 0 ? Convert.ToString(dt.Rows[0]["MENSAJE"]) : "Problema registrado.";
            }
            catch (Exception ex) { r.error = true; r.detalle = ex.Message; }
            return r;
        }

        /// <summary>Los errores en Excel, para corregir sobre la planilla.</summary>
        public byte[] ErroresExcel(int id)
        {
            DataTable e = Errores(id);
            using (ExcelPackage x = new ExcelPackage())
            {
                ExcelWorksheet w = x.Workbook.Worksheets.Add("ERRORES");
                w.Cells["A1"].LoadFromDataTable(e, true);
                using (ExcelRange cab = w.Cells[1, 1, 1, Math.Max(1, e.Columns.Count)])
                {
                    cab.Style.Font.Bold = true; cab.Style.Fill.PatternType = ExcelFillStyle.Solid;
                    cab.Style.Fill.BackgroundColor.SetColor(ColorTranslator.FromHtml("#6732F4")); cab.Style.Font.Color.SetColor(Color.White);
                }
                w.Column(1).Width = 18; w.Column(2).Width = 8; w.Column(3).Width = 20; w.Column(4).Width = 26; w.Column(5).Width = 90;
                w.View.FreezePanes(2, 1);
                return x.GetAsByteArray();
            }
        }
    }
}
