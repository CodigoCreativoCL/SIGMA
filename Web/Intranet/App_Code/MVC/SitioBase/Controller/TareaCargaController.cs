using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using System.Web;
using OfficeOpenXml;

namespace SitioBase.Controller
{
    /// <summary>
    /// Carga masiva de tareas recurrentes.
    ///
    /// UN LIBRO, DOS HOJAS
    ///   TAREAS (que se hace y donde) y PROGRAMACIONES (cada cuanto y quien),
    ///   que se cruzan por el CODIGO de la tarea. Una programacion puede
    ///   apuntar a una tarea de la misma planilla o a una que ya exista: las
    ///   tareas se cargan primero, justamente para eso.
    ///
    /// LA CARGA PASA POR EL MISMO CAMINO QUE LA FICHA
    ///   Reusa InsertTarea e InsertTareaProgramacion fila por fila. Con INSERT
    ///   propios habria que repetir cada validacion del SP -codigo unico,
    ///   prioridad valida, programacion del cliente- y esas copias se
    ///   desincronizan a la primera regla nueva.
    ///
    /// UNA FILA MALA NO DETIENE LA CARGA
    ///   Cada fila va en su propio try: se cargan las demas y se informa cual
    ///   fallo, en que hoja, con su numero de fila y el motivo.
    /// </summary>
    public class TareaCargaController
    {
        private const string HOJA_TAREAS = "TAREAS";
        private const string HOJA_PROGRAMACIONES = "PROGRAMACIONES";

        #region Plantilla

        public void Plantilla()
        {
            int cliente = Session.ClienteId();

            using (ExcelPackage excel = new ExcelPackage())
            {
                ExcelWorksheet tareas = excel.Workbook.Worksheets.Add(HOJA_TAREAS);
                Encabezados(tareas, "CODIGO", "TITULO", "DESCRIPCION", "PRIORIDAD", "DURACION MIN",
                            "REQUIERE EVIDENCIA", "PLANTA", "AREA", "EQUIPO", "HABILITADA");
                Fila(tareas, 2, "", "Revisar nivel de aceite del reductor",
                     "Verificar por la mirilla que el nivel quede entre las marcas.",
                     "Media", "10", "NO", "Renca", "", "ACT-34", "SI");
                tareas.Cells["A:A"].Style.Numberformat.Format = "@";

                ExcelWorksheet prog = excel.Workbook.Worksheets.Add(HOJA_PROGRAMACIONES);
                Encabezados(prog, "TAREA", "PROGRAMACION", "RESPONSABLE", "GRUPO");
                Fila(prog, 2, "TAR-001", "Mensual (semilla)", "rodrigo.quezada@hamburgo.cl", "");
                prog.Cells["A:D"].Style.Numberformat.Format = "@";

                /* Las ayudas: lo que hay que escribir, tal cual. Sin ellas se
                   escribe «renca», «Renca L1» y «RENCA» y cada una falla sin
                   que se entienda por que. */
                Ayuda(excel, "PLANTAS", "PLANTA", Plantas(cliente));
                Ayuda(excel, "EQUIPOS", "EQUIPO", Equipos(cliente));
                Ayuda(excel, "PROGRAMACIONES VALIDAS", "PROGRAMACION", Programaciones(cliente));
                Ayuda(excel, "RESPONSABLES", "CORREO", Responsables(cliente));
                Ayuda(excel, "PRIORIDADES", "PRIORIDAD", new List<string> { "Baja", "Media", "Alta", "Crítica" });

                ExcelWorksheet reglas = excel.Workbook.Worksheets.Add("COMO SE LLENA");
                string[] textos =
                {
                    "Hoja TAREAS: una fila por tarea. TITULO es obligatorio; CODIGO vacío se numera solo.",
                    "PRIORIDAD se escribe Baja, Media, Alta o Crítica. Vacío = Media.",
                    "REQUIERE EVIDENCIA y HABILITADA se escriben SI o NO (vacío = NO y SI, respectivamente).",
                    "PLANTA, AREA y EQUIPO se escriben como en las hojas de ayuda. EQUIPO acepta el código (ACT-34).",
                    "Hoja PROGRAMACIONES: TAREA es el código de la tarea, de esta misma planilla o de una que ya exista.",
                    "PROGRAMACION es el nombre de una programación del cliente; RESPONSABLE es el correo de la persona.",
                    "Las ocurrencias NO se generan al cargar: se generan después, desde la tarea."
                };
                for (int i = 0; i < textos.Length; i++) reglas.Cells[i + 1, 1].Value = textos[i];

                foreach (ExcelWorksheet h in excel.Workbook.Worksheets) h.Columns.AutoFit();

                Entregar(excel.GetAsByteArray(), "PLANTILLA CARGA TAREAS");
            }
        }

        #endregion

        #region Carga

        /// <summary>
        /// Lee el libro y crea lo que venga. Devuelve cuantas entraron, cuantas
        /// fallaron y una tabla con el motivo de cada fallo.
        /// </summary>
        public Respuesta Cargar(byte[] binario)
        {
            Respuesta r = new Respuesta();

            DataTable errores = new DataTable();
            errores.Columns.Add("FILA");
            errores.Columns.Add("CODIGO");
            errores.Columns.Add("MOTIVO");

            int cargadas = 0;

            Dictionary<string, int> plantas = new Dictionary<string, int>();
            Dictionary<string, int> areas = new Dictionary<string, int>();
            Dictionary<string, int> equipos = new Dictionary<string, int>();
            Dictionary<string, int> programaciones = new Dictionary<string, int>();
            Dictionary<string, int> usuarios = new Dictionary<string, int>();
            Dictionary<string, int> tareasPorCodigo = new Dictionary<string, int>();

            Diccionarios(plantas, areas, equipos, programaciones, usuarios, tareasPorCodigo);

            using (System.IO.MemoryStream ms = new System.IO.MemoryStream(binario))
            using (ExcelPackage excel = new ExcelPackage(ms))
            {
                TareaController controller = new TareaController();

                // ---------------------------------------------- 1. las tareas
                foreach (Registro fila in Leer(excel.Workbook.Worksheets[HOJA_TAREAS]))
                {
                    string codigo = fila["CODIGO"];

                    try
                    {
                        Tarea t = new Tarea();

                        t.tar_titulo = fila["TITULO"];
                        if (t.tar_titulo.Length == 0) throw new Exception("Falta el título de la tarea.");

                        t.tar_codigo = CodigoModulo.Componer("Tarea", codigo);
                        t.tar_descripcion = fila["DESCRIPCION"].Length > 0 ? fila["DESCRIPCION"] : null;
                        if (t.tar_descripcion == null) t.quita_descripcion = true;
                        t.tar_tarea_prioridad = Prioridad(fila["PRIORIDAD"]);
                        t.tar_requiere_evidencia = EsSi(fila["REQUIERE EVIDENCIA"]);
                        t.tar_habilitado = fila["HABILITADA"].Length == 0 || EsSi(fila["HABILITADA"]);

                        if (fila["DURACION MIN"].Length > 0)
                        {
                            int d;
                            if (!int.TryParse(fila["DURACION MIN"], out d) || d <= 0)
                                throw new Exception("\"" + fila["DURACION MIN"] + "\" no es una duración válida en minutos.");
                            t.tar_duracion_estimada_minuto = d;
                        }
                        else t.quita_duracion = true;

                        t.tar_cliente_instalacion = Buscar(plantas, fila["PLANTA"], "La planta");
                        if (t.tar_cliente_instalacion == null) t.quita_instalacion = true;

                        t.tar_instalacion_area = Buscar(areas, fila["AREA"], "El área");
                        if (t.tar_instalacion_area == null) t.quita_area = true;

                        t.tar_activo = Buscar(equipos, fila["EQUIPO"], "El equipo");
                        if (t.tar_activo == null) t.quita_activo = true;

                        Respuesta ins = controller.InsertTarea(t);
                        if (ins.error) throw new Exception(ins.detalle);

                        cargadas++;

                        /* Se anota con el codigo que la planilla escribio para
                           que la hoja de programaciones pueda encontrarla, aunque
                           el codigo definitivo lo haya puesto el SP. */
                        if (codigo.Length > 0) tareasPorCodigo[Clave(t.tar_codigo)] = ins.codigo;
                    }
                    catch (Exception ex)
                    {
                        Error(errores, HOJA_TAREAS, fila.fila, codigo, ex.Message);
                    }
                }

                // -------------------------------------- 2. las programaciones
                foreach (Registro fila in Leer(excel.Workbook.Worksheets[HOJA_PROGRAMACIONES]))
                {
                    string codigo = fila["TAREA"];

                    try
                    {
                        int tarea;
                        string clave = Clave(CodigoModulo.Componer("Tarea", codigo));

                        if (!tareasPorCodigo.TryGetValue(clave, out tarea))
                            throw new Exception("La tarea \"" + codigo + "\" no existe ni viene en la hoja TAREAS.");

                        int programacion;
                        if (!programaciones.TryGetValue(Clave(fila["PROGRAMACION"]), out programacion))
                            throw new Exception("La programación \"" + fila["PROGRAMACION"] + "\" no existe. Escríbala como en la hoja de ayuda.");

                        TareaProgramacion p = new TareaProgramacion { tpr_tarea = tarea, tpr_programacion = programacion, tpr_habilitado = true };

                        if (fila["RESPONSABLE"].Length > 0)
                        {
                            int usuario;
                            if (!usuarios.TryGetValue(Clave(fila["RESPONSABLE"]), out usuario))
                                throw new Exception("El responsable \"" + fila["RESPONSABLE"] + "\" no es un usuario del cliente.");
                            p.tpr_usuario_responsable = usuario;
                        }

                        Respuesta ins = controller.InsertTareaProgramacion(p);
                        if (ins.error) throw new Exception(ins.detalle);

                        cargadas++;
                    }
                    catch (Exception ex)
                    {
                        Error(errores, HOJA_PROGRAMACIONES, fila.fila, codigo, ex.Message);
                    }
                }
            }

            r.cantidaCargada = cargadas;
            r.cantidaError = errores.Rows.Count;
            r.table = errores;
            r.error = cargadas == 0 && errores.Rows.Count > 0;
            r.detalle = cargadas == 0 && errores.Rows.Count == 0
                ? "El libro no trae filas para cargar. Descargue la plantilla y trabaje sobre ella."
                : cargadas + (cargadas == 1 ? " fila cargada" : " filas cargadas") +
                  (errores.Rows.Count > 0 ? ", " + errores.Rows.Count + " con error." : ".");

            return r;
        }

        #endregion

        #region Diccionarios y apoyo

        private static void Diccionarios(Dictionary<string, int> plantas, Dictionary<string, int> areas,
                                         Dictionary<string, int> equipos, Dictionary<string, int> programaciones,
                                         Dictionary<string, int> usuarios, Dictionary<string, int> tareas)
        {
            int cliente = Session.ClienteId();

            List<ClienteInstalacion> pl = new ClienteInstalacionController().GetClienteInstalaciones(
                new ClienteInstalacion { filtro_cliente = cliente.ToString(), filtro_habilitado = "1" });
            if (pl != null) foreach (ClienteInstalacion p in pl) Agregar(plantas, p.cin_nombre, p.cin_id);

            List<InstalacionArea> ar = new InstalacionAreaController().GetInstalacionAreas(
                new InstalacionArea { iar_cliente = cliente, filtro_habilitado = true });
            if (ar != null)
                foreach (InstalacionArea a in ar)
                {
                    Agregar(areas, a.iar_nombre, a.iar_id);
                    Agregar(areas, a.ruta, a.iar_id);
                }

            List<Activo> eq = new ActivoController().GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true });
            if (eq != null)
                foreach (Activo a in eq)
                {
                    Agregar(equipos, a.act_codigo, a.act_id);
                    Agregar(equipos, a.act_nombre, a.act_id);
                }

            /* Programacion no filtra por cliente en su modelo: el SP ya lee
               las del cliente en sesion. */
            List<Programacion> pr = new ProgramacionController().GetProgramaciones(
                new Programacion { filtro_habilitado = true });
            if (pr != null) foreach (Programacion p in pr) Agregar(programaciones, p.pro_nombre, p.pro_id);

            List<Usuario> us = new UsuarioController().GetUsuarios(new Usuario());
            if (us != null)
                foreach (Usuario u in us)
                {
                    Agregar(usuarios, u.usu_login, u.usu_id);
                    Agregar(usuarios, u.usu_correo, u.usu_id);
                }

            List<Tarea> ta = new TareaController().GetTareas(new Tarea());
            if (ta != null) foreach (Tarea t in ta) Agregar(tareas, t.tar_codigo, t.tar_id);
        }

        private static void Agregar(Dictionary<string, int> d, string clave, int id)
        {
            string k = Clave(clave);
            if (k.Length > 0 && !d.ContainsKey(k)) d.Add(k, id);
        }

        private static int? Buscar(Dictionary<string, int> d, string valor, string que)
        {
            if (string.IsNullOrEmpty(valor)) return null;

            int id;
            if (d.TryGetValue(Clave(valor), out id)) return id;

            throw new Exception(que + " \"" + valor + "\" no existe. Escríbalo como en la hoja de ayuda.");
        }

        private static int Prioridad(string texto)
        {
            switch (Clave(texto))
            {
                case "BAJA": return 1;
                case "ALTA": return 3;
                case "CRITICA":
                case "CRÍTICA": return 4;
                default: return 2;   // vacio o "Media"
            }
        }

        private static List<string> Plantas(int cliente)
        {
            List<string> l = new List<string>();
            List<ClienteInstalacion> pl = new ClienteInstalacionController().GetClienteInstalaciones(
                new ClienteInstalacion { filtro_cliente = cliente.ToString(), filtro_habilitado = "1" });
            if (pl != null) foreach (ClienteInstalacion p in pl) l.Add(p.cin_nombre);
            return l;
        }

        private static List<string> Equipos(int cliente)
        {
            List<string> l = new List<string>();
            List<Activo> eq = new ActivoController().GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true });
            if (eq != null) foreach (Activo a in eq) l.Add(a.act_codigo + " — " + a.act_nombre);
            return l;
        }

        private static List<string> Programaciones(int cliente)
        {
            List<string> l = new List<string>();
            /* Programacion no filtra por cliente en su modelo: el SP ya lee
               las del cliente en sesion. */
            List<Programacion> pr = new ProgramacionController().GetProgramaciones(
                new Programacion { filtro_habilitado = true });
            if (pr != null) foreach (Programacion p in pr) l.Add(p.pro_nombre);
            return l;
        }

        private static List<string> Responsables(int cliente)
        {
            List<string> l = new List<string>();
            List<Usuario> us = new UsuarioController().GetUsuarios(new Usuario());
            if (us != null) foreach (Usuario u in us) l.Add(u.usu_login);
            return l;
        }

        private static void Encabezados(ExcelWorksheet hoja, params string[] nombres)
        {
            for (int i = 0; i < nombres.Length; i++)
            {
                hoja.Cells[1, i + 1].Value = nombres[i];
                hoja.Cells[1, i + 1].Style.Font.Bold = true;
            }
        }

        private static void Fila(ExcelWorksheet hoja, int fila, params string[] valores)
        {
            for (int i = 0; i < valores.Length; i++) hoja.Cells[fila, i + 1].Value = valores[i];
        }

        private static void Ayuda(ExcelPackage excel, string nombre, string columna, List<string> valores)
        {
            ExcelWorksheet h = excel.Workbook.Worksheets.Add(nombre);
            h.Cells[1, 1].Value = columna;
            h.Cells[1, 1].Style.Font.Bold = true;

            for (int i = 0; i < valores.Count; i++) h.Cells[i + 2, 1].Value = valores[i];
        }

        private static void Error(DataTable t, string hoja, int fila, string codigo, string motivo)
        {
            DataRow e = t.NewRow();
            e["FILA"] = hoja + " " + fila;
            e["CODIGO"] = codigo;
            e["MOTIVO"] = motivo;
            t.Rows.Add(e);
        }

        /// <summary>Una fila leida por nombre de columna; lo que no existe es cadena vacia.</summary>
        private class Registro
        {
            public int fila;
            private readonly Dictionary<string, string> _v = new Dictionary<string, string>();
            public void Set(string col, string valor) { _v[col] = valor; }
            public string this[string col] { get { string s; return _v.TryGetValue(col, out s) ? s : ""; } }
        }

        private static IEnumerable<Registro> Leer(ExcelWorksheet hoja)
        {
            if (hoja == null || hoja.Dimension == null) yield break;

            int cols = hoja.Dimension.End.Column, filas = hoja.Dimension.End.Row;

            string[] nombres = new string[cols + 1];
            for (int c = 1; c <= cols; c++) nombres[c] = (hoja.Cells[1, c].Text ?? "").Trim().ToUpper();

            for (int f = 2; f <= filas; f++)
            {
                Registro r = new Registro { fila = f };
                bool vacia = true;

                for (int c = 1; c <= cols; c++)
                {
                    if (nombres[c].Length == 0) continue;

                    string v = (hoja.Cells[f, c].Text ?? "").Trim();
                    if (v.Length > 0) vacia = false;
                    r.Set(nombres[c], v);
                }

                if (!vacia) yield return r;
            }
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
