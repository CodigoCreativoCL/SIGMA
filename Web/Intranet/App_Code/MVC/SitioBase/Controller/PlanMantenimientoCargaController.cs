using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Text;
using System.Web;
using OfficeOpenXml;

namespace SitioBase.Controller
{
    /// <summary>
    /// Carga masiva de planes de mantenimiento COMPLETOS desde una planilla.
    ///
    /// UN LIBRO, TRES HOJAS
    ///   PLANES (que es el plan), HITOS (que se le hace y cada cuanto) y
    ///   EQUIPOS (a que maquinas). Las tres se cruzan por el CODIGO del plan.
    ///   Un plan de la hoja HITOS que no exista en la base ni en la hoja
    ///   PLANES es un error de esa fila, no de la carga.
    ///
    /// LA CARGA PASA POR EL MISMO CAMINO QUE LAS FICHAS
    ///   Reusa InsertPlanMantenimiento, InsertPlanHito e InsertPlanActivo
    ///   fila por fila. Con INSERT propios habria que repetir cada validacion
    ///   del SP —codigo unico, alcance del equipo, borrador— y esas copias se
    ///   desincronizan a la primera regla nueva.
    ///
    /// LOS NOMBRES SE RESUELVEN EN MEMORIA
    ///   Planta, planificador, tipo, modelo, programacion, unidad, tipo y
    ///   prioridad de OT, equipo, componente y medidor se escriben por nombre
    ///   o codigo -lo que la persona ve en pantalla- y se resuelven a id con
    ///   diccionarios leidos UNA vez. Consultar la base por cada celda serian
    ///   miles de viajes para traer siempre las mismas tablas chicas.
    ///
    /// UNA FILA MALA NO DETIENE LA CARGA
    ///   Cada fila va en su propio try. Se cargan las demas y se informa
    ///   cual fallo, en que hoja, con su numero de fila y el motivo.
    /// </summary>
    public class PlanMantenimientoCargaController
    {
        private const string HOJA_PLANES  = "PLANES";
        private const string HOJA_HITOS   = "HITOS";
        private const string HOJA_EQUIPOS = "EQUIPOS";

        #region Plantilla

        /// <summary>
        /// La planilla para cargar: tres hojas de datos con una fila de
        /// ejemplo cada una, y hojas de ayuda con los valores validos tal
        /// como hay que escribirlos.
        /// </summary>
        public void Plantilla()
        {
            int cliente = Session.ClienteId();

            using (ExcelPackage excel = new ExcelPackage())
            {
                ExcelWorksheet planes = excel.Workbook.Worksheets.Add(HOJA_PLANES);
                Encabezados(planes, "CODIGO", "NOMBRE", "DESCRIPCION", "PLANTA", "PLANIFICADOR", "TIPO ACTIVO", "MODELO", "HABILITADO");
                Fila(planes, 2, "EJEMPLO-L1", "Preventivo de hornos de línea 1",
                     "Lubricación, inspección de quemadores y calibración.", "Renca",
                     "rodrigo.quezada@hamburgo.cl", "Horno", "", "SI");
                planes.Cells["A:A"].Style.Numberformat.Format = "@";

                ExcelWorksheet hitos = excel.Workbook.Worksheets.Add(HOJA_HITOS);
                Encabezados(hitos, "PLAN", "CODIGO", "NOMBRE", "ORDEN", "PROGRAMACION", "VALOR MEDIDOR", "UNIDAD",
                            "OVERHAUL", "REQUIERE PARADA", "DURACION MIN", "TIPO OT", "PRIORIDAD OT", "DESCRIPCION");
                Fila(hitos, 2, "EJEMPLO-L1", "LUB-MENSUAL", "Lubricación de cadenas", "1", "Mensual (semilla)",
                     "", "", "NO", "NO", "90", "", "", "Engrase de cadena de transporte.");
                hitos.Cells["A:B"].Style.Numberformat.Format = "@";

                ExcelWorksheet equipos = excel.Workbook.Worksheets.Add(HOJA_EQUIPOS);
                Encabezados(equipos, "PLAN", "EQUIPO", "COMPONENTE", "MEDIDOR");
                Fila(equipos, 2, "EJEMPLO-L1", "ACT-34", "", "");
                equipos.Cells["A:D"].Style.Numberformat.Format = "@";

                /* Las ayudas: lo que hay que escribir, tal cual. Sin ellas se
                   escribe «horno», «Hornos», «HORNO industrial» y cada una
                   falla sin que se entienda por que. */
                Ayuda(excel, "PLANTAS", "PLANTA", Plantas(cliente));
                Ayuda(excel, "PLANIFICADORES", "CORREO", Planificadores(cliente));
                Ayuda(excel, "TIPOS Y MODELOS", "TIPO ACTIVO", "MODELO", TiposModelos(cliente));
                Ayuda(excel, "PROGRAMACIONES", "PROGRAMACION", Programaciones());
                Ayuda(excel, "UNIDADES", "UNIDAD", Unidades());
                Ayuda(excel, "TIPOS OT", "TIPO OT", Catalogo("ORDEN_TRABAJO_TIPO", cliente));
                Ayuda(excel, "PRIORIDADES OT", "PRIORIDAD OT", Catalogo("ORDEN_TRABAJO_PRIORIDAD", cliente));
                Ayuda(excel, "EQUIPOS VALIDOS", "EQUIPO", "NOMBRE", Equipos(cliente));

                foreach (ExcelWorksheet h in excel.Workbook.Worksheets) h.Columns.AutoFit();

                Entregar(excel.GetAsByteArray(), "PLANTILLA CARGA PLANES");
            }
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

        private static void Ayuda(ExcelPackage excel, string nombre, string col1, string col2, List<KeyValuePair<string, string>> valores)
        {
            ExcelWorksheet h = excel.Workbook.Worksheets.Add(nombre);
            h.Cells[1, 1].Value = col1; h.Cells[1, 1].Style.Font.Bold = true;
            h.Cells[1, 2].Value = col2; h.Cells[1, 2].Style.Font.Bold = true;
            for (int i = 0; i < valores.Count; i++)
            {
                h.Cells[i + 2, 1].Value = valores[i].Key;
                h.Cells[i + 2, 2].Value = valores[i].Value;
            }
        }

        #endregion

        #region Carga

        public Respuesta Cargar(byte[] archivo)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad()) return respuesta;

            DataTable resultado = new DataTable();
            resultado.Columns.Add("FILA", typeof(string));
            resultado.Columns.Add("CODIGO", typeof(string));
            resultado.Columns.Add("MOTIVO", typeof(string));

            int cargados = 0, fallidos = 0;
            int planesOk = 0, hitosOk = 0, equiposOk = 0;

            try
            {
                using (ExcelPackage excel = new ExcelPackage())
                {
                    using (MemoryStream ms = new MemoryStream(archivo)) excel.Load(ms);

                    ExcelWorksheet hPlanes  = excel.Workbook.Worksheets[HOJA_PLANES];
                    ExcelWorksheet hHitos   = excel.Workbook.Worksheets[HOJA_HITOS];
                    ExcelWorksheet hEquipos = excel.Workbook.Worksheets[HOJA_EQUIPOS];

                    if (hPlanes == null && hHitos == null && hEquipos == null)
                    {
                        respuesta.error = true;
                        respuesta.detalle = "La planilla no tiene las hojas PLANES, HITOS ni EQUIPOS. Descargue la plantilla y trabaje sobre ella.";
                        return respuesta;
                    }

                    Diccionarios d = new Diccionarios(Session.ClienteId());

                    // ---- 1) Planes ----
                    foreach (Registro r in Leer(hPlanes))
                    {
                        string codigo = r["CODIGO"];
                        try
                        {
                            if (codigo.ToUpper().StartsWith("EJEMPLO")) continue;
                            if (codigo.Length == 0 && r["NOMBRE"].Length == 0) continue;
                            if (r["NOMBRE"].Length == 0) throw new Exception("Falta el nombre.");

                            PlanMantenimiento p = new PlanMantenimiento();
                            p.pma_cliente = Session.ClienteId();
                            p.pma_codigo = codigo.Length > 0 ? CodigoModulo.Componer("Plan_Mantenimiento", codigo) : "AUTO";
                            p.pma_nombre = r["NOMBRE"];
                            p.pma_descripcion = r["DESCRIPCION"].Length > 0 ? r["DESCRIPCION"] : null;
                            p.pma_habilitado = r["HABILITADO"].Length == 0 || EsSi(r["HABILITADO"]);

                            if (r["PLANTA"].Length > 0) p.pma_cliente_instalacion = d.Resolver(d.plantas, r["PLANTA"], "planta", "PLANTAS");
                            if (r["PLANIFICADOR"].Length > 0) p.pma_usuario_planificador = d.Resolver(d.planificadores, r["PLANIFICADOR"], "planificador", "PLANIFICADORES");
                            if (r["TIPO ACTIVO"].Length > 0)
                            {
                                p.pma_activo_tipo = d.Resolver(d.tipos, r["TIPO ACTIVO"], "tipo de activo", "TIPOS Y MODELOS");
                                if (r["MODELO"].Length > 0)
                                    p.pma_activo_modelo = d.Resolver(d.Modelos(p.pma_activo_tipo.Value), r["MODELO"], "modelo del tipo " + r["TIPO ACTIVO"], "TIPOS Y MODELOS");
                            }
                            else if (r["MODELO"].Length > 0)
                                throw new Exception("Para acotar a un modelo hay que indicar antes el TIPO ACTIVO.");

                            Respuesta uno = new PlanMantenimientoController().InsertPlanMantenimiento(p);
                            if (uno.error) throw new Exception(uno.detalle);

                            // El plan recien creado queda disponible para las otras hojas
                            d.planes[Clave(p.pma_codigo)] = uno.codigo;
                            if (codigo.Length > 0) d.planes[Clave(codigo)] = uno.codigo;
                            planesOk++; cargados++;
                        }
                        catch (Exception ex) { fallidos++; Error(resultado, HOJA_PLANES, r.fila, codigo.Length > 0 ? codigo : r["NOMBRE"], ex.Message); }
                    }

                    // ---- 2) Hitos ----
                    foreach (Registro r in Leer(hHitos))
                    {
                        string codigo = r["CODIGO"];
                        try
                        {
                            if (r["PLAN"].ToUpper().StartsWith("EJEMPLO")) continue;
                            if (r["PLAN"].Length == 0 && codigo.Length == 0 && r["NOMBRE"].Length == 0) continue;
                            if (r["PLAN"].Length == 0) throw new Exception("Falta el código del PLAN.");
                            if (codigo.Length == 0) throw new Exception("Falta el código del hito.");
                            if (r["NOMBRE"].Length == 0) throw new Exception("Falta el nombre.");
                            if (r["PROGRAMACION"].Length == 0) throw new Exception("Falta la PROGRAMACION.");

                            PlanHito h = new PlanHito();
                            h.plan_id = d.Plan(r["PLAN"]);
                            h.pmh_codigo = codigo.ToUpper();
                            h.pmh_nombre = r["NOMBRE"];
                            h.pmh_programacion = d.Resolver(d.programaciones, r["PROGRAMACION"], "programación", "PROGRAMACIONES");
                            h.pmh_orden = (int)(Numero(r["ORDEN"], "ORDEN") ?? 0);
                            h.pmh_valor_medidor = Numero(r["VALOR MEDIDOR"], "VALOR MEDIDOR");
                            if (r["UNIDAD"].Length > 0) h.pmh_unidad_medida = d.Resolver(d.unidades, r["UNIDAD"], "unidad", "UNIDADES");
                            h.pmh_es_overhaul = EsSi(r["OVERHAUL"]);
                            h.pmh_requiere_parada = EsSi(r["REQUIERE PARADA"]);
                            decimal? dur = Numero(r["DURACION MIN"], "DURACION MIN");
                            if (dur != null) h.pmh_duracion_estimada_minuto = (int)dur.Value;
                            if (r["TIPO OT"].Length > 0) h.pmh_orden_trabajo_tipo = d.Resolver(d.otTipos, r["TIPO OT"], "tipo de OT", "TIPOS OT");
                            if (r["PRIORIDAD OT"].Length > 0) h.pmh_orden_trabajo_prioridad = d.Resolver(d.otPrioridades, r["PRIORIDAD OT"], "prioridad de OT", "PRIORIDADES OT");
                            h.pmh_descripcion = r["DESCRIPCION"].Length > 0 ? r["DESCRIPCION"] : null;

                            Respuesta uno = new PlanHitoController().InsertPlanHito(h);
                            if (uno.error) throw new Exception(uno.detalle);
                            hitosOk++; cargados++;
                        }
                        catch (Exception ex) { fallidos++; Error(resultado, HOJA_HITOS, r.fila, r["PLAN"] + " / " + codigo, ex.Message); }
                    }

                    // ---- 3) Equipos ----
                    foreach (Registro r in Leer(hEquipos))
                    {
                        try
                        {
                            if (r["PLAN"].ToUpper().StartsWith("EJEMPLO")) continue;
                            if (r["PLAN"].Length == 0 && r["EQUIPO"].Length == 0) continue;
                            if (r["PLAN"].Length == 0) throw new Exception("Falta el código del PLAN.");
                            if (r["EQUIPO"].Length == 0) throw new Exception("Falta el código del EQUIPO.");

                            PlanActivo a = new PlanActivo();
                            a.plan_id = d.Plan(r["PLAN"]);
                            a.pac_activo = d.Resolver(d.activos, r["EQUIPO"], "equipo", "EQUIPOS VALIDOS");
                            if (r["COMPONENTE"].Length > 0) a.pac_activo_componente = d.Componente(a.pac_activo, r["COMPONENTE"]);
                            if (r["MEDIDOR"].Length > 0) a.pac_activo_medidor = d.Medidor(a.pac_activo, r["MEDIDOR"]);

                            Respuesta uno = new PlanActivoController().InsertPlanActivo(a);
                            if (uno.error) throw new Exception(uno.detalle);
                            equiposOk++; cargados++;
                        }
                        catch (Exception ex) { fallidos++; Error(resultado, HOJA_EQUIPOS, r.fila, r["PLAN"] + " / " + r["EQUIPO"], ex.Message); }
                    }
                }

                respuesta.cantidaCargada = cargados;
                respuesta.cantidaError = fallidos;
                respuesta.error = fallidos > 0;
                respuesta.table = resultado;
                respuesta.detalle = planesOk + " plan(es), " + hitosOk + " hito(s) y " + equiposOk + " equipo(s) cargados.";
            }
            catch (Exception ex)
            {
                respuesta.error = true;
                respuesta.detalle = "No se pudo leer la planilla: " + ex.Message;
                respuesta.table = resultado;
            }

            return respuesta;
        }

        private static void Error(DataTable t, string hoja, int fila, string codigo, string motivo)
        {
            DataRow e = t.NewRow();
            e["FILA"] = hoja + " " + fila;
            e["CODIGO"] = codigo;
            e["MOTIVO"] = motivo;
            t.Rows.Add(e);
        }

        #endregion

        #region Lectura tolerante de la planilla

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
            for (int c = 1; c <= cols; c++)
                nombres[c] = (hoja.Cells[1, c].Text ?? "").Trim().ToUpper();

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

        private static decimal? Numero(string v, string columna)
        {
            if (string.IsNullOrEmpty(v)) return null;
            decimal d;
            if (decimal.TryParse(v, out d)) return d;
            if (decimal.TryParse(v, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out d)) return d;
            throw new Exception("\"" + v + "\" no es un número válido en " + columna + ".");
        }

        private static string Clave(string s) { return (s ?? "").Trim().ToUpperInvariant(); }

        #endregion

        #region Diccionarios (nombre -> id), leidos una vez

        private class Diccionarios
        {
            private readonly int _cliente;
            public readonly Dictionary<string, int> planes = new Dictionary<string, int>();
            public readonly Dictionary<string, int> plantas, planificadores, tipos, programaciones, unidades, otTipos, otPrioridades, activos;
            private readonly Dictionary<int, Dictionary<string, int>> _modelos = new Dictionary<int, Dictionary<string, int>>();
            private readonly Dictionary<int, Dictionary<string, int>> _componentes = new Dictionary<int, Dictionary<string, int>>();
            private readonly Dictionary<int, Dictionary<string, int>> _medidores = new Dictionary<int, Dictionary<string, int>>();

            public Diccionarios(int cliente)
            {
                _cliente = cliente;

                List<PlanMantenimiento> lp = new PlanMantenimientoController().GetPlanesMantenimiento(new PlanMantenimiento { pma_cliente = cliente });
                if (lp != null) foreach (PlanMantenimiento p in lp)
                {
                    planes[Clave(p.pma_codigo)] = p.pma_id;
                    planes[Clave(CodigoModulo.Sufijo("Plan_Mantenimiento", p.pma_codigo))] = p.pma_id;
                }

                plantas = new Dictionary<string, int>();
                foreach (ClienteInstalacion i in new ClienteInstalacionController().GetClienteInstalaciones(
                             new ClienteInstalacion { filtro_cliente = cliente.ToString(), filtro_habilitado = "1" }) ?? new List<ClienteInstalacion>())
                    plantas[Clave(i.cin_nombre)] = i.cin_id;

                planificadores = new Dictionary<string, int>();
                foreach (ClienteUsuario u in new ClienteUsuarioController().GetClienteUsuarios(
                             new ClienteUsuario { ucl_id_cliente = cliente, usu_habilitado = true, id_perfiles = "", filtro = "" }) ?? new List<ClienteUsuario>())
                {
                    if (!string.IsNullOrEmpty(u.usu_login)) planificadores[Clave(u.usu_login)] = u.usu_id;
                    if (!string.IsNullOrEmpty(u.usu_correo)) planificadores[Clave(u.usu_correo)] = u.usu_id;
                }

                tipos = new Dictionary<string, int>();
                foreach (ActivoTipo t in new ActivoTipoController().GetActivoTipos(new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true }) ?? new List<ActivoTipo>())
                    tipos[Clave(t.ati_nombre)] = t.ati_id;

                programaciones = new Dictionary<string, int>();
                foreach (Programacion p in new ProgramacionController().GetProgramaciones(new Programacion { filtro_habilitado = true }) ?? new List<Programacion>())
                    programaciones[Clave(p.pro_nombre)] = p.pro_id;

                unidades = new Dictionary<string, int>();
                foreach (UnidadMedida u in new UnidadMedidaController().GetUnidades(new UnidadMedida { filtro_habilitado = true }) ?? new List<UnidadMedida>())
                {
                    if (!string.IsNullOrEmpty(u.ume_codigo)) unidades[Clave(u.ume_codigo)] = u.ume_id;
                    if (!string.IsNullOrEmpty(u.ume_simbolo)) unidades[Clave(u.ume_simbolo)] = u.ume_id;
                    if (!string.IsNullOrEmpty(u.ume_nombre)) unidades[Clave(u.ume_nombre)] = u.ume_id;
                }

                otTipos = new Dictionary<string, int>();
                foreach (CatalogoValor v in new CatalogoController().GetValoresPorCodigo("ORDEN_TRABAJO_TIPO", cliente) ?? new List<CatalogoValor>())
                { otTipos[Clave(v.valor_nombre)] = v.valor_id; if (!string.IsNullOrEmpty(v.valor_codigo)) otTipos[Clave(v.valor_codigo)] = v.valor_id; }

                otPrioridades = new Dictionary<string, int>();
                foreach (CatalogoValor v in new CatalogoController().GetValoresPorCodigo("ORDEN_TRABAJO_PRIORIDAD", cliente) ?? new List<CatalogoValor>())
                { otPrioridades[Clave(v.valor_nombre)] = v.valor_id; if (!string.IsNullOrEmpty(v.valor_codigo)) otPrioridades[Clave(v.valor_codigo)] = v.valor_id; }

                activos = new Dictionary<string, int>();
                foreach (Activo a in new ActivoController().GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true }) ?? new List<Activo>())
                    activos[Clave(a.act_codigo)] = a.act_id;
            }

            public int Resolver(Dictionary<string, int> dic, string texto, string que, string hojaAyuda)
            {
                int id;
                if (dic.TryGetValue(Clave(texto), out id)) return id;
                throw new Exception("La " + que + " \"" + texto + "\" no existe. Vea la hoja " + hojaAyuda + " de la plantilla.");
            }

            public int Plan(string codigo)
            {
                int id;
                if (planes.TryGetValue(Clave(codigo), out id)) return id;
                if (planes.TryGetValue(Clave(CodigoModulo.Componer("Plan_Mantenimiento", codigo)), out id)) return id;
                throw new Exception("El plan \"" + codigo + "\" no existe ni viene en la hoja PLANES.");
            }

            public Dictionary<string, int> Modelos(int tipo)
            {
                Dictionary<string, int> m;
                if (_modelos.TryGetValue(tipo, out m)) return m;
                m = new Dictionary<string, int>();
                foreach (ActivoModelo x in new ActivoModeloController().GetModelos(new ActivoModelo { filtro_cliente = _cliente, filtro_activo_tipo = tipo, filtro_habilitado = true }) ?? new List<ActivoModelo>())
                { m[Clave(x.amo_nombre)] = x.amo_id; if (!string.IsNullOrEmpty(x.etiqueta)) m[Clave(x.etiqueta)] = x.amo_id; }
                _modelos[tipo] = m;
                return m;
            }

            public int Componente(int activo, string codigo)
            {
                Dictionary<string, int> m;
                if (!_componentes.TryGetValue(activo, out m))
                {
                    m = new Dictionary<string, int>();
                    foreach (ActivoComponente c in new ActivoComponenteController().GetComponentes(new ActivoComponente { aco_cliente = _cliente, filtro_activo = activo, filtro_habilitado = true }) ?? new List<ActivoComponente>())
                    { m[Clave(c.aco_codigo)] = c.aco_id; m[Clave(c.aco_nombre)] = c.aco_id; }
                    _componentes[activo] = m;
                }
                return Resolver(m, codigo, "componente del equipo", "EQUIPOS VALIDOS");
            }

            public int Medidor(int activo, string codigo)
            {
                Dictionary<string, int> m;
                if (!_medidores.TryGetValue(activo, out m))
                {
                    m = new Dictionary<string, int>();
                    foreach (ActivoMedidor x in new ActivoMedidorController().GetActivoMedidores(new ActivoMedidor { ame_cliente = _cliente, filtro_activo = activo, filtro_habilitado = true }) ?? new List<ActivoMedidor>())
                    { m[Clave(x.ame_codigo)] = x.ame_id; m[Clave(x.ame_nombre)] = x.ame_id; }
                    _medidores[activo] = m;
                }
                return Resolver(m, codigo, "medidor del equipo", "EQUIPOS VALIDOS");
            }
        }

        #endregion

        #region Listas de ayuda de la plantilla

        private static List<string> Plantas(int cliente)
        {
            List<string> l = new List<string>();
            foreach (ClienteInstalacion i in new ClienteInstalacionController().GetClienteInstalaciones(
                         new ClienteInstalacion { filtro_cliente = cliente.ToString(), filtro_habilitado = "1" }) ?? new List<ClienteInstalacion>())
                l.Add(i.cin_nombre);
            return l;
        }

        private static List<string> Planificadores(int cliente)
        {
            List<string> l = new List<string>();
            foreach (ClienteUsuario u in new ClienteUsuarioController().GetClienteUsuarios(
                         new ClienteUsuario { ucl_id_cliente = cliente, usu_habilitado = true, id_perfiles = "", filtro = "" }) ?? new List<ClienteUsuario>())
                l.Add(u.usu_login);
            return l;
        }

        private static List<KeyValuePair<string, string>> TiposModelos(int cliente)
        {
            List<KeyValuePair<string, string>> l = new List<KeyValuePair<string, string>>();
            foreach (ActivoTipo t in new ActivoTipoController().GetActivoTipos(new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true }) ?? new List<ActivoTipo>())
            {
                List<ActivoModelo> modelos = new ActivoModeloController().GetModelos(new ActivoModelo { filtro_cliente = cliente, filtro_activo_tipo = t.ati_id, filtro_habilitado = true });
                if (modelos == null || modelos.Count == 0) { l.Add(new KeyValuePair<string, string>(t.ati_nombre, "")); continue; }
                foreach (ActivoModelo m in modelos) l.Add(new KeyValuePair<string, string>(t.ati_nombre, m.amo_nombre));
            }
            return l;
        }

        private static List<string> Programaciones()
        {
            List<string> l = new List<string>();
            foreach (Programacion p in new ProgramacionController().GetProgramaciones(new Programacion { filtro_habilitado = true }) ?? new List<Programacion>())
                l.Add(p.pro_nombre);
            return l;
        }

        private static List<string> Unidades()
        {
            List<string> l = new List<string>();
            foreach (UnidadMedida u in new UnidadMedidaController().GetUnidades(new UnidadMedida { filtro_habilitado = true }) ?? new List<UnidadMedida>())
                l.Add(u.ume_simbolo);
            return l;
        }

        private static List<string> Catalogo(string codigo, int cliente)
        {
            List<string> l = new List<string>();
            foreach (CatalogoValor v in new CatalogoController().GetValoresPorCodigo(codigo, cliente) ?? new List<CatalogoValor>())
                l.Add(v.valor_nombre);
            return l;
        }

        private static List<KeyValuePair<string, string>> Equipos(int cliente)
        {
            List<KeyValuePair<string, string>> l = new List<KeyValuePair<string, string>>();
            foreach (Activo a in new ActivoController().GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true }) ?? new List<Activo>())
                l.Add(new KeyValuePair<string, string>(a.act_codigo, a.act_nombre));
            return l;
        }

        #endregion

        private static void Entregar(byte[] binario, string nombre)
        {
            string archivo = nombre + " " + DateTime.Now.ToString("dd-MM-yyyy");
            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.ContentType = "application/vnd.ms-excel";
            HttpContext.Current.Response.HeaderEncoding = Encoding.Default;
            HttpContext.Current.Response.ContentEncoding = Encoding.Default;
            HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + archivo + ".xlsx");
            HttpContext.Current.Response.BinaryWrite(binario);
            HttpContext.Current.Response.End();
        }
    }
}
