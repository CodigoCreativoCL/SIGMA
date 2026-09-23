using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web;
using OfficeOpenXml;

namespace SitioBase.Controller
{
    /// <summary>
    /// La planilla de pasos de un procedimiento: plantilla, revision y listado
    /// de errores.
    ///
    /// ESTE CONTROLADOR NO ESCRIBE EN LA BASE
    ///   Solo lee el libro y devuelve los pasos con su veredicto. Los escribe
    ///   la pantalla, junto con el resto de la receta, cuando la persona
    ///   guarda. Es la diferencia con las otras cargas masivas del sistema
    ///   -planes, repuestos, usuarios-, que insertan fila por fila: aca los
    ///   pasos importados se mezclan con los que ya estaban en pantalla y hay
    ///   que poder revisar el conjunto -y su orden- antes de que exista.
    ///
    /// LA VARIABLE SE ESCRIBE POR NOMBRE
    ///   En la planilla se escribe la etiqueta de la variable, que es lo que la
    ///   persona ve en pantalla, y se resuelve a id con un diccionario leido una
    ///   vez. La plantilla trae la lista exacta en una hoja de ayuda: sin ella
    ///   se escribe "temperatura", "Temp." y "TEMPERATURA °C" y cada una falla
    ///   sin que se entienda por que.
    /// </summary>
    public class ProcedimientoPasoCargaController
    {
        private const string HOJA = "PASOS";

        #region Plantilla

        public void Plantilla()
        {
            using (ExcelPackage excel = new ExcelPackage())
            {
                ExcelWorksheet h = excel.Workbook.Worksheets.Add(HOJA);

                string[] cols = { "NOMBRE", "INSTRUCCION", "MINUTOS", "PUNTO CONTROL", "EVIDENCIA", "MEDICION", "VARIABLE", "HABILITADO" };
                for (int i = 0; i < cols.Length; i++)
                {
                    h.Cells[1, i + 1].Value = cols[i];
                    h.Cells[1, i + 1].Style.Font.Bold = true;
                }

                /* La fila de ejemplo se carga como cualquier otra: si se deja,
                   entra. Se avisa en la ayuda de la pantalla y se pone una sola,
                   a proposito, para que se vea y se borre. */
                h.Cells[2, 1].Value = "Bloquear y señalizar el equipo";
                h.Cells[2, 2].Value = "Corte de energía, candado y tarjeta con el nombre del ejecutante.";
                h.Cells[2, 3].Value = 10;
                h.Cells[2, 4].Value = "SI";
                h.Cells[2, 5].Value = "SI";
                h.Cells[2, 6].Value = "NO";
                h.Cells[2, 7].Value = "";
                h.Cells[2, 8].Value = "SI";

                ExcelWorksheet ayuda = excel.Workbook.Worksheets.Add("VARIABLES");
                ayuda.Cells[1, 1].Value = "VARIABLE";
                ayuda.Cells[1, 1].Style.Font.Bold = true;

                int f = 2;
                foreach (VariableMedicion v in Variables())
                {
                    ayuda.Cells[f, 1].Value = v.etiqueta;
                    f++;
                }

                ExcelWorksheet reglas = excel.Workbook.Worksheets.Add("COMO SE LLENA");
                string[] textos =
                {
                    "Una fila por paso, EN EL ORDEN en que se ejecutan: la numeración la pone el sistema.",
                    "NOMBRE es obligatorio y no pasa de 200 caracteres.",
                    "MINUTOS es opcional: un número entero de minutos.",
                    "PUNTO CONTROL, EVIDENCIA, MEDICION y HABILITADO se escriben SI o NO (vacío = NO, salvo HABILITADO, que vacío = SI).",
                    "Si MEDICION dice SI, VARIABLE es obligatoria y tiene que estar escrita igual que en la hoja VARIABLES.",
                    "Nada se escribe en el sistema al importar: los pasos quedan en la lista de la pantalla y se guardan con el botón Guardar."
                };
                for (int i = 0; i < textos.Length; i++) reglas.Cells[i + 1, 1].Value = textos[i];

                foreach (ExcelWorksheet x in excel.Workbook.Worksheets) x.Columns.AutoFit();

                Entregar(excel.GetAsByteArray(), "PLANTILLA PASOS PROCEDIMIENTO");
            }
        }

        #endregion

        #region Revision

        /// <summary>
        /// Lee la hoja PASOS y devuelve un paso por fila con su veredicto. Una
        /// fila mala no detiene la lectura: se marca y se sigue, porque el
        /// valor de revisar antes de importar es ver TODOS los problemas de una
        /// vez y no el primero.
        /// </summary>
        public List<ProcedimientoPasoEdicion> Analizar(byte[] binario)
        {
            List<ProcedimientoPasoEdicion> lista = new List<ProcedimientoPasoEdicion>();

            Dictionary<string, int> variables = new Dictionary<string, int>();
            Dictionary<string, string> etiquetas = new Dictionary<string, string>();

            foreach (VariableMedicion v in Variables())
            {
                string k = Clave(v.etiqueta);
                if (k.Length == 0 || variables.ContainsKey(k)) continue;
                variables.Add(k, v.vme_id);
                etiquetas.Add(k, v.etiqueta);
            }

            using (System.IO.MemoryStream ms = new System.IO.MemoryStream(binario))
            using (ExcelPackage excel = new ExcelPackage(ms))
            {
                ExcelWorksheet hoja = excel.Workbook.Worksheets[HOJA];

                /* Si la hoja no se llama PASOS se usa la primera: renombrarla
                   es el error mas comun y rechazar el libro entero por eso
                   seria pedir que se adivine el nombre. */
                if (hoja == null && excel.Workbook.Worksheets.Count > 0) hoja = excel.Workbook.Worksheets[1];
                if (hoja == null || hoja.Dimension == null) return lista;

                int cols = hoja.Dimension.End.Column, filas = hoja.Dimension.End.Row;

                Dictionary<string, int> col = new Dictionary<string, int>();
                for (int c = 1; c <= cols; c++)
                {
                    string nombre = Clave(hoja.Cells[1, c].Text);
                    if (nombre.Length > 0 && !col.ContainsKey(nombre)) col.Add(nombre, c);
                }

                for (int f = 2; f <= filas; f++)
                {
                    string nombre = Texto(hoja, col, "NOMBRE", f);
                    string instruccion = Texto(hoja, col, "INSTRUCCION", f);
                    string minutos = Texto(hoja, col, "MINUTOS", f);
                    string pc = Texto(hoja, col, "PUNTO CONTROL", f);
                    string ev = Texto(hoja, col, "EVIDENCIA", f);
                    string med = Texto(hoja, col, "MEDICION", f);
                    string variable = Texto(hoja, col, "VARIABLE", f);
                    string hab = Texto(hoja, col, "HABILITADO", f);

                    // Una fila vacia no es un error: es el final de la planilla.
                    if ((nombre + instruccion + minutos + pc + ev + med + variable + hab).Trim().Length == 0)
                        continue;

                    ProcedimientoPasoEdicion p = new ProcedimientoPasoEdicion
                    {
                        id = 0,
                        fila = f,
                        nombre = nombre,
                        instruccion = instruccion,
                        punto_control = EsSi(pc),
                        evidencia = EsSi(ev),
                        medicion = EsSi(med),
                        habilitado = hab.Trim().Length == 0 || EsSi(hab),
                        ok = true,
                        motivo = ""
                    };

                    if (nombre.Length == 0)
                        Falla(p, "Falta el nombre del paso.");
                    else if (nombre.Length > 200)
                        Falla(p, "El nombre pasa de 200 caracteres.");

                    if (minutos.Length > 0)
                    {
                        int m;
                        if (!int.TryParse(minutos, out m) || m < 0)
                            Falla(p, "\"" + minutos + "\" no es un número de minutos.");
                        else if (m > 0)
                            p.duracion = m;
                    }

                    if (p.medicion)
                    {
                        string k = Clave(variable);
                        if (k.Length == 0)
                            Falla(p, "Dice que requiere medición pero no indica la variable.");
                        else if (!variables.ContainsKey(k))
                            Falla(p, "La variable \"" + variable + "\" no existe. Escríbala como en la hoja VARIABLES.");
                        else
                        {
                            p.variable = variables[k];
                            p.variable_nombre = etiquetas[k];
                        }
                    }

                    lista.Add(p);
                }
            }

            return lista;
        }

        private static void Falla(ProcedimientoPasoEdicion p, string motivo)
        {
            p.ok = false;
            p.motivo = string.IsNullOrEmpty(p.motivo) ? motivo : p.motivo + " " + motivo;
        }

        /// <summary>
        /// Las filas que no sirven, en un libro con la misma forma que la
        /// plantilla mas una columna con el motivo: se corrige y se vuelve a
        /// subir ese mismo archivo, sin tener que buscar las filas malas en el
        /// original.
        /// </summary>
        public void Errores(List<ProcedimientoPasoEdicion> malas)
        {
            using (ExcelPackage excel = new ExcelPackage())
            {
                ExcelWorksheet h = excel.Workbook.Worksheets.Add(HOJA);

                string[] cols = { "NOMBRE", "INSTRUCCION", "MINUTOS", "PUNTO CONTROL", "EVIDENCIA", "MEDICION", "VARIABLE", "HABILITADO", "FILA ORIGINAL", "QUE PASO" };
                for (int i = 0; i < cols.Length; i++)
                {
                    h.Cells[1, i + 1].Value = cols[i];
                    h.Cells[1, i + 1].Style.Font.Bold = true;
                }

                int f = 2;
                foreach (ProcedimientoPasoEdicion p in malas ?? new List<ProcedimientoPasoEdicion>())
                {
                    h.Cells[f, 1].Value = p.nombre;
                    h.Cells[f, 2].Value = p.instruccion;
                    h.Cells[f, 3].Value = p.duracion;
                    h.Cells[f, 4].Value = p.punto_control ? "SI" : "NO";
                    h.Cells[f, 5].Value = p.evidencia ? "SI" : "NO";
                    h.Cells[f, 6].Value = p.medicion ? "SI" : "NO";
                    h.Cells[f, 7].Value = p.variable_nombre;
                    h.Cells[f, 8].Value = p.habilitado ? "SI" : "NO";
                    h.Cells[f, 9].Value = p.fila;
                    h.Cells[f, 10].Value = p.motivo;
                    f++;
                }

                h.Columns.AutoFit();
                Entregar(excel.GetAsByteArray(), "PASOS CON PROBLEMA");
            }
        }

        #endregion

        #region Apoyo

        private static List<VariableMedicion> Variables()
        {
            List<VariableMedicion> l = new VariableMedicionController().GetVariables(Session.ClienteId());
            return l ?? new List<VariableMedicion>();
        }

        private static string Texto(ExcelWorksheet hoja, Dictionary<string, int> col, string nombre, int fila)
        {
            int c;
            if (!col.TryGetValue(nombre, out c)) return "";
            return (hoja.Cells[fila, c].Text ?? "").Trim();
        }

        private static bool EsSi(string v)
        {
            v = (v ?? "").Trim().ToUpper();
            return v == "SI" || v == "SÍ" || v == "S" || v == "1" || v == "TRUE" || v == "X";
        }

        private static string Clave(string s) { return (s ?? "").Trim().ToUpperInvariant(); }

        private static void Entregar(byte[] binario, string nombre)
        {
            string archivo = nombre + " " + global::SitioBase.Hora.Ahora.ToString("dd-MM-yyyy");
            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.ContentType = "application/vnd.ms-excel";
            HttpContext.Current.Response.HeaderEncoding = Encoding.Default;
            HttpContext.Current.Response.ContentEncoding = Encoding.Default;
            HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + archivo + ".xlsx");
            HttpContext.Current.Response.BinaryWrite(binario);
            HttpContext.Current.Response.End();
        }

        #endregion
    }
}
