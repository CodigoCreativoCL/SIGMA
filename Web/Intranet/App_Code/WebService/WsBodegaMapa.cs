using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Mapa 3D de bodegas (BodegaMapa3D.aspx): lectura y administracion.
///
/// EL MAPA SE DIBUJA CON LO QUE HAY EN LA BASE
///   Bodegas, ubicaciones y stock salen de la base en cada carga. No hay un
///   plano guardado aparte que se desactualice.
///
/// EL MAPA ADMINISTRA, PERO NO TIENE REGLAS PROPIAS
///   Crear una bodega, un rack, un repuesto o registrar un movimiento pasa por
///   los MISMOS controllers que usan las pantallas de siempre (BodegaController,
///   RepuestoController, InventarioController, RepuestoFotoController). Lo que
///   se puede hacer en el mapa es exactamente lo que se puede hacer en esas
///   pantallas, con las mismas validaciones del SP: si una regla cambia, cambia
///   para las dos.
///
///   Las reglas que viven en el code-behind de Movimiento.aspx -no en el SP- se
///   replican aqui tal cual: la salida sale de un origen concreto (ubicacion +
///   lote), no puede superar lo que hay, la reubicacion necesita un destino
///   distinto, y el lote nuevo se crea ANTES del movimiento.
///
/// CADA LLAMADA VUELVE A VALIDAR SESION Y PERMISO
///   Con los mismos permisos que cada pantalla: CREAR EDITAR BODEGAS, CREAR
///   EDITAR REPUESTOS, GESTIONAR STOCK, y para movimientos los de
///   Movimiento.aspx (ingreso, entrega, ajuste).
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsBodegaMapa : System.Web.Services.WebService
{
    private const string P_VER = "VER BODEGAS";
    private const string P_BODEGAS = "CREAR EDITAR BODEGAS";
    private const string P_REPUESTOS = "CREAR EDITAR REPUESTOS";
    private const string P_STOCK = "GESTIONAR STOCK";
    private const string P_INGRESO = "REGISTRAR INGRESO REPUESTO";
    private const string P_ENTREGA = "ENTREGAR REPUESTO";
    private const string P_AJUSTE = "AJUSTAR INVENTARIO";

    // =================================================================== lectura

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cargar(int planta)
    {
        return Ejecutar(P_VER, () =>
        {
            ClienteInstalacion filtroPlanta = new ClienteInstalacion();
            filtroPlanta.filtro_cliente = SitioBase.Session.ClienteId().ToString();
            filtroPlanta.filtro_habilitado = "1";

            var plantas = new ClienteInstalacionController().GetClienteInstalaciones(filtroPlanta)
                .Select(p => new { id = p.cin_id, nombre = p.cin_nombre })
                .ToList();

            /* Sin planta elegida se toma la primera: mezclar las bodegas de dos
               plantas dibujaria edificios que no estan uno al lado del otro. */
            if (planta <= 0 && plantas.Count > 0) planta = plantas[0].id;

            BodegaMapaController ctrl = new BodegaMapaController();
            DataTable estructura = ctrl.GetEstructura(planta), saldos = ctrl.GetSaldos(planta);

            return new
            {
                error = false,
                planta = planta,
                plantas = plantas,
                permisos = Permisos(),
                bodegas = ArmarEstructura(estructura),
                saldos = ArmarSaldos(saldos),
                qr = Qrs(estructura),
                conteos = ArmarConteos(new InventarioConteoController().GetUltimos(planta))
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Saldos(int planta)
    {
        return Ejecutar(P_VER, () =>
        {
            DataTable saldos = new BodegaMapaController().GetSaldos(planta);
            return new
            {
                error = false, saldos = ArmarSaldos(saldos),
                conteos = ArmarConteos(new InventarioConteoController().GetUltimos(planta))
            };
        });
    }

    /// <summary>
    /// Todo lo que necesitan los formularios del mapa: unidades, tipos, tipos
    /// de movimiento permitidos, ordenes abiertas y el maestro de repuestos
    /// (liviano) para elegir que ingresar.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Catalogos()
    {
        return Ejecutar(P_VER, () =>
        {
            var unidades = new UnidadMedidaController().GetUnidades()
                .Where(u => u.ume_habilitado)
                .Select(u => new { id = u.ume_id, codigo = u.ume_codigo, nombre = u.ume_nombre, simbolo = u.ume_simbolo })
                .OrderBy(u => u.nombre).ToList();

            var tipos = new RepuestoTipoController().GetRepuestoTipos(new RepuestoTipo { filtro_habilitado = true })
                .Select(t => new { id = t.rti_id, codigo = t.rti_codigo, nombre = t.rti_nombre })
                .ToList();

            Dictionary<int, int> portadas = new RepuestoFotoController().GetPortadas();
            var repuestos = new RepuestoController().GetRepuestos(new Repuesto { filtro_habilitado = true })
                .Select(r =>
                {
                    int a;
                    return new
                    {
                        id = r.rep_id, c = r.rep_codigo, n = r.rep_nombre, tid = r.rep_repuesto_tipo,
                        tn = r.repuesto_tipo_nombre, un = r.unidad_simbolo, lote = r.rep_controla_lote,
                        foto = portadas.TryGetValue(r.rep_id, out a) && a > 0 ? UrlArchivo.Ver(a) : ""
                    };
                }).ToList();

            // los mismos tipos y el mismo criterio de permiso que Movimiento.aspx
            var movs = new List<object>();
            if (Token.Puede(P_INGRESO)) movs.Add(Mov(1, "Ingreso por compra", "entrada"));
            if (Token.Puede(P_ENTREGA)) { movs.Add(Mov(2, "Entrega (salida por consumo)", "salida")); movs.Add(Mov(3, "Devolución", "entrada")); }
            if (Token.Puede(P_AJUSTE))
            {
                movs.Add(Mov(4, "Ajuste positivo (sobra en el conteo)", "entrada"));
                movs.Add(Mov(5, "Ajuste negativo (falta en el conteo)", "salida"));
                movs.Add(Mov(9, "Cambio de ubicación (mismo depósito)", "reubicacion"));
                movs.Add(Mov(6, "Traslado a otra bodega", "traslado"));
                movs.Add(Mov(8, "Merma", "salida"));
            }

            var ordenes = new InventarioController().GetOrdenesAbiertas(0)
                .Select(o => new { id = o.orden_id, texto = o.correlativo + " · " + o.titulo })
                .ToList();

            return new { error = false, unidades, tipos, repuestos, movimientos = movs, ordenes };
        });
    }

    /// <summary>La ficha completa de un repuesto, para editarlo en el panel.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string FichaRepuesto(int id)
    {
        return Ejecutar(P_VER, () =>
        {
            RepuestoController rc = new RepuestoController();
            Repuesto r = rc.GetRepuesto(id);
            if (r == null) throw new Exception("El repuesto no existe o no es de este cliente.");

            var fotos = (new RepuestoFotoController().GetFotos(id) ?? new List<RepuestoFoto>())
                .Where(f => string.IsNullOrEmpty(f.mime) || f.mime.StartsWith("image/"))
                .Select(f => new { vinculo = f.vinculo, url = UrlArchivo.Ver(f.archivo), titulo = f.titulo, orden = f.orden })
                .ToList();

            var umbrales = rc.GetUmbrales(new RepuestoBodegaStock { rbs_repuesto = id })
                .Select(u => new { bodega = u.rbs_bodega, min = u.rbs_stock_minimo, max = u.rbs_stock_maximo, pr = u.rbs_punto_reposicion })
                .ToList();

            return new
            {
                error = false,
                repuesto = new
                {
                    id = r.rep_id, codigo = r.rep_codigo, nombre = r.rep_nombre, unidad = r.rep_unidad_medida,
                    tipo = r.rep_repuesto_tipo, fabricante = r.rep_fabricante, modelo = r.rep_modelo,
                    descripcion = r.rep_descripcion, reparable = r.rep_es_reparable, consumible = r.rep_es_consumible,
                    lote = r.rep_controla_lote, costo = r.rep_costo_referencia, vidaHoras = r.rep_vida_util_hora,
                    vidaDias = r.rep_vida_util_dia, vidaCiclos = r.rep_vida_util_ciclo, habilitado = r.rep_habilitado
                },
                fotos,
                umbrales,
                qr = new EtiquetaController().QrMatriz("REP-" + id),
                metodo = MetodoRepuesto(id)
            };
        });
    }

    /// <summary>
    /// QR de etiquetas pedidos por el visor, en lote (hasta 200 por llamada).
    /// Solo tokens con la forma de SEL_ETIQUETA (REP-, UBI-, BOD- y un numero):
    /// el QR lleva el token, no datos del cliente, asi que no expone nada.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Qr(string tokens)
    {
        return Ejecutar(P_VER, () =>
        {
            EtiquetaController etq = new EtiquetaController();
            var qr = new Dictionary<string, string>();
            foreach (string t in (tokens ?? "").Split(',').Select(x => x.Trim().ToUpperInvariant()).Distinct().Take(200))
                if (System.Text.RegularExpressions.Regex.IsMatch(t, "^(REP|UBI|BOD)-[0-9]{1,9}$")) qr[t] = etq.QrMatriz(t);
            return new { error = false, qr };
        });
    }

    /// <summary>
    /// La hoja de impresion de etiquetas (Comun/Impresion/Etiquetas.aspx) con
    /// el query cifrado como lo arma Bodega.aspx. La pagina vuelve a validar
    /// permisos: esto solo arma la direccion.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string UrlEtiquetas(string origen, string ids, int bodega)
    {
        return Ejecutar(P_VER, () =>
        {
            string o = (origen ?? "").ToUpperInvariant();
            if (o != EtiquetaOrigen.Bodega && o != EtiquetaOrigen.Ubicacion && o != EtiquetaOrigen.UbicacionRepuesto && o != EtiquetaOrigen.Repuesto)
                throw new Exception("Origen de etiqueta no valido.");

            string datos = "Origen=" + o;
            if (!string.IsNullOrEmpty(ids)) datos += "&Ids=" + string.Join(",", ids.Split(',').Select(x => x.Trim()).Where(x => x.All(char.IsDigit) && x.Length > 0));
            if (bodega > 0) datos += "&Bodega=" + bodega;

            return new
            {
                error = false,
                url = VirtualPathUtility.ToAbsolute("~/View/Comun/Impresion/Etiquetas.aspx") + "?query=" + HttpUtility.UrlEncode(Tools.Crypto.Encrypt(datos))
            };
        });
    }

    private static string MetodoRepuesto(int id)
    {
        SqlCommand cmd = new SqlCommand();
        cmd.CommandText = "SEL_REPUESTO_METODO_SALIDA";
        cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());
        cmd.Parameters.AddWithValue("@REPUESTO", id);
        DataTable dt = Conexion.GetDataTable(cmd);
        return dt.Rows.Count > 0 && dt.Rows[0]["METODO"] != DBNull.Value ? Convert.ToString(dt.Rows[0]["METODO"]) : "";
    }

    /// <summary>De donde puede salir un repuesto en una bodega: ubicacion + lote con saldo.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Origenes(int repuesto, int bodega)
    {
        return Ejecutar(P_VER, () => new
        {
            error = false,
            origenes = new InventarioController().GetOrigenes(repuesto, bodega, true).Select(o => new
            {
                ubicacion = o.ubicacion_id ?? 0, ubicacionCodigo = o.ubicacion_codigo, lote = o.lote_id ?? 0,
                loteCodigo = o.lote_codigo, vence = o.lote_vence.HasValue ? o.lote_vence.Value.ToString("dd-MM-yyyy") : "",
                vencido = o.lote_vencido, cantidad = o.cantidad, unidad = o.unidad
            }).ToList()
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Lotes(int repuesto)
    {
        return Ejecutar(P_VER, () => new
        {
            error = false,
            lotes = new RepuestoController().GetLotes(new RepuestoLote { rlo_repuesto = repuesto, filtro_vigentes = true })
                .Select(l => new { id = l.rlo_id, codigo = l.rlo_codigo, vence = l.rlo_fecha_vencimiento.HasValue ? l.rlo_fecha_vencimiento.Value.ToString("dd-MM-yyyy") : "" })
                .ToList()
        });
    }

    // ============================================================ administracion

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarBodega(string datos)
    {
        return Ejecutar(P_BODEGAS, () =>
        {
            var d = Leer(datos);
            BodegaController bc = new BodegaController();
            Bodega b = new Bodega
            {
                bod_id = Entero(d, "id"),
                bod_cliente_instalacion = Entero(d, "planta"),
                bod_codigo = Texto(d, "codigo"),
                bod_nombre = Texto(d, "nombre"),
                bod_descripcion = Texto(d, "descripcion"),
                bod_habilitado = !d.ContainsKey("habilitado") || Bool(d, "habilitado")
            };
            if (string.IsNullOrEmpty(b.bod_nombre)) throw new Exception("Indique el nombre de la bodega.");
            if (b.bod_cliente_instalacion <= 0) throw new Exception("Indique la planta de la bodega.");
            if (b.bod_id == 0 && string.IsNullOrEmpty(b.bod_codigo)) b.bod_codigo = "AUTO";

            Respuesta res = b.bod_id > 0 ? bc.UpdateBodega(b) : bc.InsertBodega(b);
            int idBodega = b.bod_id > 0 ? b.bod_id : res.codigo;
            if (!res.error && d.ContainsKey("metodo") && idBodega > 0)
            {
                string err = EjecutarMetodo("UPD_BODEGA_METODO_SALIDA", "@BODEGA", idBodega, Texto(d, "metodo"));
                if (err != null) return new { error = true, detalle = "La bodega se guardó, pero no el método de salida: " + err, id = idBodega };
            }
            return Resultado(res, b.bod_id);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarUbicacion(string datos)
    {
        return Ejecutar(P_BODEGAS, () =>
        {
            var d = Leer(datos);
            BodegaUbicacion u = new BodegaUbicacion
            {
                bub_id = Entero(d, "id"),
                bub_bodega = Entero(d, "bodega"),
                bub_codigo = Texto(d, "codigo"),
                bub_nombre = Texto(d, "nombre"),
                bub_habilitado = !d.ContainsKey("habilitado") || Bool(d, "habilitado")
            };
            if (u.bub_id == 0 && u.bub_bodega <= 0) throw new Exception("Indique la bodega de la ubicación.");
            if (u.bub_id == 0 && string.IsNullOrEmpty(u.bub_codigo)) throw new Exception("Indique el código de la ubicación.");
            if (string.IsNullOrEmpty(u.bub_nombre)) u.bub_nombre = u.bub_codigo;

            return Resultado(new BodegaController().GuardarUbicacion(u), u.bub_id);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string EliminarUbicacion(int id)
    {
        return Ejecutar(P_BODEGAS, () => Resultado(new BodegaController().DeleteUbicacion(id), id));
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarRepuesto(string datos)
    {
        return Ejecutar(P_REPUESTOS, () =>
        {
            var d = Leer(datos);
            RepuestoController rc = new RepuestoController();
            int id = Entero(d, "id");

            /* Al editar se parte del repuesto COMPLETO y se pisan solo los campos
               que vienen: lo que el mapa no muestra no se borra por omision. */
            Repuesto r = id > 0 ? rc.GetRepuesto(id) : new Repuesto { rep_habilitado = true };
            if (r == null) throw new Exception("El repuesto no existe o no es de este cliente.");

            if (d.ContainsKey("codigo") && id == 0) r.rep_codigo = string.IsNullOrEmpty(Texto(d, "codigo")) ? "AUTO" : Texto(d, "codigo");
            if (d.ContainsKey("nombre")) r.rep_nombre = Texto(d, "nombre");
            if (d.ContainsKey("unidad")) r.rep_unidad_medida = Entero(d, "unidad");
            if (d.ContainsKey("tipo")) r.rep_repuesto_tipo = Entero(d, "tipo");
            if (d.ContainsKey("fabricante")) r.rep_fabricante = Texto(d, "fabricante");
            if (d.ContainsKey("modelo")) r.rep_modelo = Texto(d, "modelo");
            if (d.ContainsKey("descripcion")) r.rep_descripcion = Texto(d, "descripcion");
            if (d.ContainsKey("reparable")) r.rep_es_reparable = Bool(d, "reparable");
            if (d.ContainsKey("consumible")) r.rep_es_consumible = Bool(d, "consumible");
            if (d.ContainsKey("lote")) r.rep_controla_lote = Bool(d, "lote");
            if (d.ContainsKey("costo")) r.rep_costo_referencia = Num(d, "costo");
            if (d.ContainsKey("vidaHoras")) r.rep_vida_util_hora = Num(d, "vidaHoras");
            if (d.ContainsKey("vidaDias")) { decimal? v = Num(d, "vidaDias"); r.rep_vida_util_dia = v.HasValue ? (int?)Convert.ToInt32(v.Value) : null; }
            if (d.ContainsKey("vidaCiclos")) r.rep_vida_util_ciclo = Num(d, "vidaCiclos");
            if (d.ContainsKey("habilitado")) r.rep_habilitado = Bool(d, "habilitado");

            if (string.IsNullOrEmpty(r.rep_nombre)) throw new Exception("Indique el nombre del repuesto.");
            if (r.rep_unidad_medida <= 0) throw new Exception("Indique la unidad de medida.");
            if (id == 0 && string.IsNullOrEmpty(r.rep_codigo)) r.rep_codigo = "AUTO";

            Respuesta res = id > 0 ? rc.UpdateRepuesto(r) : rc.InsertRepuesto(r);
            int idRep = id > 0 ? id : res.codigo;
            if (!res.error && d.ContainsKey("metodo") && idRep > 0)
            {
                string err = EjecutarMetodo("UPD_REPUESTO_METODO_SALIDA", "@REPUESTO", idRep, Texto(d, "metodo"));
                if (err != null) return new { error = true, detalle = "El repuesto se guardó, pero no el método de salida: " + err, id = idRep };
            }
            return Resultado(res, id);
        });
    }

    /// <summary>
    /// Sube una foto del repuesto. Llega en base64 ya reducida por el visor (no
    /// mas de 1600 px), asi que no se mandan fotos de celular de 8 MB.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string SubirFoto(int repuesto, string nombre, string mime, string base64)
    {
        return Ejecutar(P_REPUESTOS, () =>
        {
            if (string.IsNullOrEmpty(base64)) throw new Exception("Elija una imagen.");
            int coma = base64.IndexOf(',');
            byte[] bytes = Convert.FromBase64String(coma >= 0 ? base64.Substring(coma + 1) : base64);
            return Resultado(new RepuestoFotoController().Agregar(repuesto, bytes, nombre, mime, nombre), repuesto);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarFoto(int vinculo)
    {
        return Ejecutar(P_REPUESTOS, () => Resultado(new RepuestoFotoController().Quitar(vinculo), vinculo));
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string PortadaFoto(int vinculo)
    {
        return Ejecutar(P_REPUESTOS, () => Resultado(new RepuestoFotoController().HacerPortada(vinculo), vinculo));
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarUmbral(string datos)
    {
        return Ejecutar(P_STOCK, () =>
        {
            var d = Leer(datos);
            decimal? min = Num(d, "min");
            RepuestoBodegaStock u = new RepuestoBodegaStock
            {
                rbs_repuesto = Entero(d, "repuesto"),
                rbs_bodega = Entero(d, "bodega"),
                rbs_stock_minimo = min ?? 0,
                rbs_stock_maximo = Num(d, "max"),
                rbs_punto_reposicion = Num(d, "pr"),
                rbs_habilitado = true
            };
            if (u.rbs_stock_maximo.HasValue && u.rbs_stock_maximo < u.rbs_stock_minimo)
                throw new Exception("El máximo no puede ser menor que el mínimo.");
            return Resultado(new RepuestoController().GuardarUmbral(u), u.rbs_repuesto);
        });
    }

    /// <summary>
    /// Registra un movimiento con las MISMAS reglas que Movimiento.aspx.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string RegistrarMovimiento(string datos)
    {
        try
        {
            if (!Token.TokenSeguridad()) return Json(new { error = true, sesion = true, detalle = "La sesión expiró. Vuelve a entrar." });

            var d = Leer(datos);
            int tipo = Entero(d, "tipo");
            string permiso = tipo == 1 ? P_INGRESO : (tipo == 2 || tipo == 3) ? P_ENTREGA
                           : (tipo == 4 || tipo == 5 || tipo == 6 || tipo == 8 || tipo == 9) ? P_AJUSTE : null;
            if (permiso == null) throw new Exception("Indique qué movimiento va a registrar.");
            if (!Token.Puede(permiso)) return Json(new { error = true, sinPermiso = true, detalle = "No tienes permiso para registrar este movimiento." });

            int repuesto = Entero(d, "repuesto"), bodega = Entero(d, "bodega");
            if (repuesto == 0) throw new Exception("Indique el repuesto.");
            if (bodega == 0) throw new Exception("Indique la bodega.");

            decimal? cantidad = Num(d, "cantidad");
            if (cantidad == null || cantidad <= 0) throw new Exception("La cantidad debe ser mayor que cero.");

            bool sale = tipo == 2 || tipo == 5 || tipo == 6 || tipo == 8 || tipo == 9;

            InventarioMovimiento m = new InventarioMovimiento
            {
                imo_repuesto = repuesto,
                imo_bodega = bodega,
                imo_inventario_movimiento_tipo = tipo,
                imo_cantidad = cantidad.Value,
                imo_observacion = Texto(d, "observacion"),
                imo_costo_unitario = tipo == 1 ? Num(d, "costo") : null
            };

            if (sale)
            {
                /* La ubicacion y el lote salen JUNTOS del origen elegido: mandarlos
                   por separado combinaba un estante con un lote que no estaba ahi. */
                int ubic = Entero(d, "origenUbicacion"), lote = Entero(d, "origenLote");
                InventarioOrigen o = new InventarioController().GetOrigenes(repuesto, bodega, true)
                    .FirstOrDefault(x => (x.ubicacion_id ?? 0) == ubic && (x.lote_id ?? 0) == lote);
                if (o == null) throw new Exception("Indique de dónde sale: ese origen ya no tiene existencia.");
                if (o.cantidad < cantidad.Value)
                    throw new Exception("Ahí hay " + o.cantidad.ToString("N2") + " " + o.unidad + " y se intenta sacar " +
                                        cantidad.Value.ToString("N2") + ". Elija otro origen o baje la cantidad.");
                m.imo_bodega_ubicacion = o.ubicacion_id;
                m.imo_repuesto_lote = o.lote_id;

                if (tipo == 9)
                {
                    int dest = Entero(d, "destinoUbicacion");
                    if (dest == 0) throw new Exception("Indique a qué ubicación se cambia.");
                    if (o.ubicacion_id.HasValue && o.ubicacion_id.Value == dest) throw new Exception("La ubicación de destino es la misma de origen.");
                    m.imo_bodega_ubicacion_destino = dest;
                }
                if (tipo == 6)
                {
                    int bd = Entero(d, "destinoBodega");
                    if (bd == 0) throw new Exception("Indique la bodega de destino del traslado.");
                    if (bd == bodega) throw new Exception("La bodega de destino es la misma de origen.");
                    m.imo_bodega_destino = bd;

                    /* El SP exige en que ubicacion queda cuando la bodega de destino
                       tiene ubicaciones (regla 17). Movimiento.aspx no la manda en el
                       traslado, asi que ahi no se puede trasladar a una bodega con
                       racks; aqui si se manda. */
                    int du = Entero(d, "destinoUbicacion");
                    if (du > 0) m.imo_bodega_ubicacion_destino = du;
                }
            }
            else
            {
                int ubic = Entero(d, "ubicacion");
                if (ubic > 0) m.imo_bodega_ubicacion = ubic;

                Repuesto r = new RepuestoController().GetRepuesto(repuesto);
                if (r != null && r.rep_controla_lote)
                {
                    int lote = Entero(d, "lote");
                    string nuevo = Texto(d, "loteNuevo");
                    if (lote > 0) m.imo_repuesto_lote = lote;
                    else if (!string.IsNullOrEmpty(nuevo))
                    {
                        /* El lote nuevo se crea ANTES del movimiento: despues dejaria
                           un movimiento apuntando a un lote que todavia no existe. */
                        RepuestoLote l = new RepuestoLote
                        {
                            rlo_repuesto = repuesto,
                            rlo_codigo = nuevo,
                            rlo_fecha_ingreso = global::SitioBase.Hora.Hoy,
                            rlo_fecha_vencimiento = Fecha(d, "loteVence")
                        };
                        Respuesta rl = new RepuestoController().InsertLote(l);
                        if (rl.error) throw new Exception("No se pudo crear el lote: " + rl.detalle);
                        m.imo_repuesto_lote = rl.codigo;
                    }
                    else throw new Exception("Este repuesto controla lote: elija uno o escriba el código del lote nuevo.");
                }
            }

            int ot = Entero(d, "orden");
            if ((tipo == 2 || tipo == 3) && ot > 0) m.imo_orden_trabajo = ot;

            return Json(Resultado(new InventarioController().RegistrarMovimiento(m), 0));
        }
        catch (Exception ex)
        {
            return Json(new { error = true, detalle = ex.Message });
        }
    }

    // ==================================================================== picking

    /*  PICKING DESDE EL MAPA
          El mapa arma la ruta y el bodeguero la recorre; cada retiro es una
          SALIDA POR CONSUMO (tipo 2) por INS_INVENTARIO_MOVIMIENTO, contra la
          orden si la hay. No hay tabla de picking: lo pendiente de la orden es
          planificado menos consumido, y el consumo lo suma el propio SP. */

    /// <summary>Lo que una orden todavia tiene que sacar de bodega.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string PickingOT(int orden)
    {
        return Ejecutar(P_ENTREGA, () =>
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "SEL_ORDEN_TRABAJO_PICKING";
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());
            cmd.Parameters.AddWithValue("@ORDEN", orden);
            DataTable dt = Conexion.GetDataTable(cmd);
            var lineas = new List<object>();
            foreach (DataRow r in dt.Rows)
                lineas.Add(new
                {
                    id = Convert.ToInt32(r["REP_ID"]), c = Convert.ToString(r["REP_CODIGO"]), n = Convert.ToString(r["REP_NOMBRE"]),
                    un = Convert.ToString(r["UNIDAD"]), planificada = Numero(r["PLANIFICADA"]),
                    consumida = Numero(r["CONSUMIDA"]), pendiente = Numero(r["PENDIENTE"])
                });
            return new { error = false, lineas };
        });
    }

    /// <summary>
    /// Retira de UNA caja (repuesto en una ubicacion), sacando de sus lotes en
    /// el orden del metodo de salida (FEFO, FIFO o LIFO, BD/328). Si la caja no alcanza, no saca nada: el mapa ya
    /// repartio lo pedido entre las cajas, y un retiro a medias en silencio
    /// dejaria al bodeguero creyendo que tiene en la mano lo que no tiene.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string RetirarPicking(string datos)
    {
        return Ejecutar(P_ENTREGA, () =>
        {
            var d = Leer(datos);
            int rep = Entero(d, "repuesto"), bodega = Entero(d, "bodega"), ubic = Entero(d, "ubicacion"), orden = Entero(d, "orden");
            decimal? cant = Num(d, "cantidad");
            if (rep <= 0 || bodega <= 0) throw new Exception("Indique el repuesto y la bodega.");
            if (cant == null || cant <= 0) throw new Exception("La cantidad debe ser mayor que cero.");

            InventarioController ic = new InventarioController();
            // los lotes de la caja en el orden del metodo de salida (BD/328)
            var aqui = ic.GetOrigenes(rep, bodega, true).Where(o => (o.ubicacion_id ?? 0) == ubic).ToList();
            decimal hay = aqui.Sum(o => o.cantidad);
            if (hay < cant.Value)
                throw new Exception("En esa caja hay " + hay.ToString("0.##") + " y se piden " + cant.Value.ToString("0.##") + ". Retire lo que hay o busque en otra ubicación.");

            string obs = Texto(d, "observacion");
            if (string.IsNullOrEmpty(obs)) obs = orden > 0 ? "Picking desde el mapa 3D." : "Retiro libre desde el mapa 3D.";

            decimal falta = cant.Value;
            var movs = new List<int>();
            foreach (var o in aqui)
            {
                if (falta <= 0) break;
                decimal sale = Math.Min(falta, o.cantidad);
                Respuesta r = ic.RegistrarMovimiento(new InventarioMovimiento
                {
                    imo_repuesto = rep, imo_bodega = bodega, imo_inventario_movimiento_tipo = 2, imo_cantidad = sale,
                    imo_bodega_ubicacion = o.ubicacion_id, imo_repuesto_lote = o.lote_id, imo_observacion = obs,
                    imo_orden_trabajo = orden > 0 ? (int?)orden : null
                });
                if (r.error)
                {
                    /* El primer lote no salio: no se saco nada y se devuelve el
                       motivo tal cual (p. ej. la compatibilidad con el equipo de la
                       orden, que se resuelve indicando el motivo). Si fallo un lote
                       posterior, lo ya sacado queda registrado y se dice cuanto. */
                    if (movs.Count == 0) throw new Exception(r.detalle);
                    return new { error = false, retirado = (double)(cant.Value - falta), movimientos = movs, parcial = true, detalle = r.detalle };
                }
                movs.Add(r.codigo);
                falta -= sale;
            }
            return new { error = false, retirado = (double)cant.Value, movimientos = movs, parcial = false, detalle = "" };
        });
    }

    // ============================================================ conteo ciclico

    /*  CONTEO CICLICO DESDE EL RECORRIDO
          El bodeguero recorre el pasillo con la tablet y en cada rack confirma o
          corrige lo que hay en cada caja. Lo que no calza se ajusta EN EL ACTO,
          con INS_INVENTARIO_MOVIMIENTO:
            - falta  -> AJUSTE NEGATIVO (5), sacado de los lotes de esa caja
                        en el orden del metodo de salida de la bodega o del
                        repuesto (FEFO, FIFO o LIFO, BD/328): lo que falta es lo
                        que, segun ese metodo, ya se deberia haber usado;
            - sobra  -> AJUSTE POSITIVO (4), al lote mas reciente de esa caja o,
                        si el repuesto controla lote y ahi no hay ninguno, al
                        lote que indique el bodeguero.
          Lo que "decia el sistema" se lee aqui, al confirmar: no lo manda la
          pantalla, asi la diferencia se mide contra el stock real del momento.
          Permiso: AJUSTAR INVENTARIO, el mismo de cualquier ajuste. */

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string IniciarConteo(int bodega, string alcance)
    {
        return Ejecutar(P_AJUSTE, () => Resultado(new InventarioConteoController().Iniciar(bodega, alcance), 0));
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ContarRack(string datos)
    {
        return Ejecutar(P_AJUSTE, () =>
        {
            var d = Leer(datos);
            int conteo = Entero(d, "conteo"), bodega = Entero(d, "bodega"), ubic = Entero(d, "ubicacion");
            if (conteo <= 0) throw new Exception("No hay un conteo abierto.");
            if (bodega <= 0 || ubic <= 0) throw new Exception("Indique la bodega y la ubicación que se contó.");

            object crudas;
            var lineas = d.TryGetValue("lineas", out crudas) && crudas is System.Collections.IEnumerable
                ? ((System.Collections.IEnumerable)crudas).OfType<Dictionary<string, object>>().ToList()
                : new List<Dictionary<string, object>>();
            if (lineas.Count == 0) throw new Exception("No hay cajas contadas en este rack.");

            InventarioController ic = new InventarioController();
            InventarioConteoController cc = new InventarioConteoController();
            RepuestoController rc = new RepuestoController();
            var resultado = new List<object>();
            int ajustes = 0;

            foreach (var l in lineas)
            {
                int rep = Entero(l, "repuesto");
                decimal? contadoN = Num(l, "contado");
                if (rep <= 0 || contadoN == null) continue;
                decimal contado = contadoN.Value;
                if (contado < 0) throw new Exception("La cantidad contada no puede ser negativa.");

                var aqui = ic.GetOrigenes(rep, bodega, true).Where(o => (o.ubicacion_id ?? 0) == ubic).ToList();
                decimal sistema = aqui.Sum(o => o.cantidad);
                decimal dif = contado - sistema;
                var movs = new List<string>();
                string error = null;
                string obs = "Conteo cíclico N° " + conteo + ": el sistema decía " + sistema.ToString("0.##") +
                             " y se contaron " + contado.ToString("0.##") + ".";

                if (dif < 0)
                {
                    decimal falta = -dif;
                    // en el orden del metodo de salida (FEFO/FIFO/LIFO): SEL_INVENTARIO_ORIGEN ya los trae asi
                    foreach (var o in aqui)
                    {
                        if (falta <= 0) break;
                        decimal sale = Math.Min(falta, o.cantidad);
                        Respuesta r = ic.RegistrarMovimiento(new InventarioMovimiento
                        {
                            imo_repuesto = rep, imo_bodega = bodega, imo_inventario_movimiento_tipo = 5, imo_cantidad = sale,
                            imo_bodega_ubicacion = o.ubicacion_id, imo_repuesto_lote = o.lote_id, imo_observacion = obs
                        });
                        if (r.error) { error = r.detalle; break; }
                        movs.Add(r.codigo.ToString());
                        falta -= sale;
                    }
                }
                else if (dif > 0)
                {
                    int? lote = aqui.Where(o => o.lote_id.HasValue).OrderByDescending(o => o.lote_id).Select(o => o.lote_id).FirstOrDefault();
                    Repuesto rp = rc.GetRepuesto(rep);
                    bool controla = rp != null && rp.rep_controla_lote;
                    if (controla && !lote.HasValue)
                    {
                        string nuevo = Texto(l, "loteNuevo");
                        if (string.IsNullOrEmpty(nuevo)) error = "Este repuesto controla lote y en esta caja no hay ninguno: indique el código del lote.";
                        else
                        {
                            Respuesta rl = rc.InsertLote(new RepuestoLote { rlo_repuesto = rep, rlo_codigo = nuevo, rlo_fecha_ingreso = global::SitioBase.Hora.Hoy });
                            if (rl.error) error = "No se pudo crear el lote: " + rl.detalle; else lote = rl.codigo;
                        }
                    }
                    if (error == null)
                    {
                        Respuesta r = ic.RegistrarMovimiento(new InventarioMovimiento
                        {
                            imo_repuesto = rep, imo_bodega = bodega, imo_inventario_movimiento_tipo = 4, imo_cantidad = dif,
                            imo_bodega_ubicacion = ubic, imo_repuesto_lote = controla ? lote : null, imo_observacion = obs
                        });
                        if (r.error) error = r.detalle; else movs.Add(r.codigo.ToString());
                    }
                }

                ajustes += movs.Count;
                Respuesta rd = cc.RegistrarCaja(conteo, rep, ubic, sistema, contado, string.Join(",", movs), error);
                if (rd.error && error == null) error = rd.detalle;

                resultado.Add(new
                {
                    repuesto = rep, sistema = (double)sistema, contado = (double)contado, diferencia = (double)dif,
                    ok = error == null, detalle = error ?? ""
                });
            }

            return new { error = false, lineas = resultado, ajustes };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CerrarConteo(int id)
    {
        return Ejecutar(P_AJUSTE, () =>
        {
            string error;
            DataRow r = new InventarioConteoController().Cerrar(id, out error);
            if (r == null) throw new Exception(error ?? "No se pudo cerrar el conteo.");
            return new
            {
                error = false,
                resumen = new
                {
                    id = Convert.ToInt32(r["ID"]), alcance = Convert.ToString(r["ALCANCE"]),
                    lineas = Convert.ToInt32(r["LINEAS"]), coinciden = Convert.ToInt32(r["COINCIDEN"]),
                    exactitud = NumeroONulo(r["EXACTITUD"]), ubicaciones = Convert.ToInt32(r["UBICACIONES"]),
                    sobrantes = r["SOBRANTES"] == DBNull.Value ? 0 : Convert.ToInt32(r["SOBRANTES"]),
                    faltantes = r["FALTANTES"] == DBNull.Value ? 0 : Convert.ToInt32(r["FALTANTES"]),
                    unidades = Numero(r["UNIDADES_AJUSTADAS"])
                }
            };
        });
    }

    // ================================================================== armado

    /// <summary>El ultimo conteo de cada ubicacion: el mapa muestra "contado hace 3 dias por ...".</summary>
    private static List<object> ArmarConteos(DataTable dt)
    {
        var lista = new List<object>();
        foreach (DataRow r in dt.Rows)
        {
            DateTime f = Convert.ToDateTime(r["FECHA"]);
            lista.Add(new
            {
                u = Convert.ToInt32(r["BUB_ID"]),
                conteo = Convert.ToInt32(r["CONTEO"]),
                fecha = f.ToString("dd-MM-yyyy HH:mm"),
                dias = Math.Max(0, (global::SitioBase.Hora.Hoy - f.Date).Days),
                lineas = Convert.ToInt32(r["LINEAS"]),
                coinciden = Convert.ToInt32(r["COINCIDEN"]),
                usuario = Convert.ToString(r["USUARIO"])
            });
        }
        return lista;
    }


    private static object Permisos()
    {
        return new
        {
            bodegas = Token.Puede(P_BODEGAS),
            repuestos = Token.Puede(P_REPUESTOS),
            stock = Token.Puede(P_STOCK),
            ingreso = Token.Puede(P_INGRESO),
            entrega = Token.Puede(P_ENTREGA),
            ajuste = Token.Puede(P_AJUSTE)
        };
    }

    private static object Mov(int id, string nombre, string clase) { return new { id, nombre, clase }; }

    private static List<object> ArmarEstructura(DataTable dt)
    {
        var bodegas = new List<object>();
        var porId = new Dictionary<int, List<object>>();

        foreach (DataRow r in dt.Rows)
        {
            int bod = Convert.ToInt32(r["BOD_ID"]);
            List<object> ubic;

            if (!porId.TryGetValue(bod, out ubic))
            {
                ubic = new List<object>();
                porId.Add(bod, ubic);
                bodegas.Add(new
                {
                    id = bod,
                    codigo = Convert.ToString(r["BOD_CODIGO"]),
                    nombre = Convert.ToString(r["BOD_NOMBRE"]),
                    descripcion = Convert.ToString(r["BOD_DESCRIPCION"]),
                    metodo = Convert.ToString(r["BOD_METODO_SALIDA"]),
                    plantaId = Convert.ToInt32(r["CIN_ID"]),
                    planta = Convert.ToString(r["CIN_NOMBRE"]),
                    ubicaciones = ubic
                });
            }

            if (r["BUB_ID"] != DBNull.Value)
                ubic.Add(new
                {
                    id = Convert.ToInt32(r["BUB_ID"]),
                    codigo = Convert.ToString(r["BUB_CODIGO"]),
                    nombre = Convert.ToString(r["BUB_NOMBRE"])
                });
        }

        return bodegas;
    }

    /// <summary>
    /// Los QR de las etiquetas de bodegas (BOD-) y racks (UBI-), que van en la
    /// carga porque se dibujan al construir la escena. Son los mismos tokens
    /// de SEL_ETIQUETA: un QR leido desde la pantalla abre lo mismo que el del
    /// estante. Los de los repuestos (REP-) se piden aparte, con Qr(), solo
    /// para las cajas a las que la camara se acerca.
    /// </summary>
    private static Dictionary<string, string> Qrs(DataTable estructura)
    {
        EtiquetaController etq = new EtiquetaController();
        var qr = new Dictionary<string, string>();
        Action<string> agregar = t => { if (!qr.ContainsKey(t)) qr[t] = etq.QrMatriz(t); };

        foreach (DataRow r in estructura.Rows)
        {
            agregar("BOD-" + Convert.ToInt32(r["BOD_ID"]));
            if (r["BUB_ID"] != DBNull.Value) agregar("UBI-" + Convert.ToInt32(r["BUB_ID"]));
        }
        return qr;
    }

    private static List<object> ArmarSaldos(DataTable dt)
    {
        Dictionary<int, int> portadas = new RepuestoFotoController().GetPortadas();
        string ficha = VirtualPathUtility.ToAbsolute("~/View/Inventario/Repuestos/RepuestoCentro.aspx");
        var lista = new List<object>();

        foreach (DataRow r in dt.Rows)
        {
            int rep = Convert.ToInt32(r["REP_ID"]);
            int archivo;

            lista.Add(new
            {
                b = Convert.ToInt32(r["BOD_ID"]),
                u = r["BUB_ID"] == DBNull.Value ? 0 : Convert.ToInt32(r["BUB_ID"]),
                id = rep,
                c = Convert.ToString(r["REP_CODIGO"]),
                n = Convert.ToString(r["REP_NOMBRE"]),
                fab = Convert.ToString(r["REP_FABRICANTE"]),
                mod = Convert.ToString(r["REP_MODELO"]),
                tid = Convert.ToInt32(r["RTI_ID"]),
                tc = Convert.ToString(r["RTI_CODIGO"]),
                tn = Convert.ToString(r["RTI_NOMBRE"]),
                un = Convert.ToString(r["UNIDAD"]),
                q = Numero(r["CANTIDAD"]),
                res = Numero(r["RESERVADA"]),
                lot = Convert.ToInt32(r["LOTES"]),
                ult = r["ULTIMO_MOVIMIENTO"] == DBNull.Value ? "" : Convert.ToDateTime(r["ULTIMO_MOVIMIENTO"]).ToString("dd-MM-yyyy HH:mm"),
                min = NumeroONulo(r["STOCK_MINIMO"]),
                max = NumeroONulo(r["STOCK_MAXIMO"]),
                pr = NumeroONulo(r["PUNTO_REPOSICION"]),
                met = Convert.ToString(r["METODO"]),
                ing = Fecha(r["INGRESO_MIN"]),
                ingN = Fecha(r["INGRESO_MAX"]),
                vence = Fecha(r["VENCE_MIN"]),
                foto = portadas.TryGetValue(rep, out archivo) && archivo > 0 ? UrlArchivo.Ver(archivo) : "",
                ficha = ficha + "?query=" + HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + rep))
            });
        }

        return lista;
    }

    // =============================================================== utilidades

    private static string Ejecutar(string permiso, Func<object> accion)
    {
        try
        {
            if (!Token.TokenSeguridad())
                return Json(new { error = true, sesion = true, detalle = "La sesión expiró. Vuelve a entrar." });
            if (!Token.Puede(permiso))
                return Json(new { error = true, sinPermiso = true, detalle = "No tienes permiso para esta acción." });
            return Json(accion());
        }
        catch (Exception ex)
        {
            return Json(new { error = true, detalle = ex.Message });
        }
    }

    private static object Resultado(Respuesta r, int idPrevio)
    {
        return new { error = r.error, detalle = r.detalle, id = r.error ? 0 : (r.codigo > 0 ? r.codigo : idPrevio) };
    }

    private static Dictionary<string, object> Leer(string datos)
    {
        if (string.IsNullOrEmpty(datos)) return new Dictionary<string, object>();
        return new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(datos) ?? new Dictionary<string, object>();
    }

    private static string Texto(Dictionary<string, object> d, string k)
    {
        object v; return d.TryGetValue(k, out v) && v != null ? Convert.ToString(v, CultureInfo.InvariantCulture).Trim() : "";
    }

    private static int Entero(Dictionary<string, object> d, string k)
    {
        int n; return int.TryParse(Texto(d, k), NumberStyles.Integer, CultureInfo.InvariantCulture, out n) ? n : 0;
    }

    private static bool Bool(Dictionary<string, object> d, string k)
    {
        string t = Texto(d, k).ToLowerInvariant();
        return t == "true" || t == "1" || t == "si" || t == "sí";
    }

    /// <summary>Acepta "1.5" y "1,5": quien escribe una cantidad no piensa en la cultura.</summary>
    private static decimal? Num(Dictionary<string, object> d, string k)
    {
        string t = Texto(d, k).Replace(" ", "");
        if (t.Length == 0) return null;
        if (t.Contains(",") && !t.Contains(".")) t = t.Replace(",", ".");
        else if (t.Contains(",") && t.Contains(".")) t = t.Replace(".", "").Replace(",", ".");
        decimal n;
        if (!decimal.TryParse(t, NumberStyles.Number, CultureInfo.InvariantCulture, out n))
            throw new Exception("\"" + Texto(d, k) + "\" no es un número válido.");
        return n;
    }

    private static DateTime? Fecha(Dictionary<string, object> d, string k)
    {
        DateTime f;
        return DateTime.TryParseExact(Texto(d, k), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f) ? (DateTime?)f : null;
    }

/// <summary>Fecha ISO (yyyy-MM-dd HH:mm), ordenable como texto en el visor; vacia si no hay.</summary>
    private static string Fecha(object v)
    {
        return v == null || v == DBNull.Value ? "" : Convert.ToDateTime(v).ToString("yyyy-MM-dd HH:mm");
    }

    /// <summary>Ejecuta un SP de escritura del bloque 328 y devuelve su error, o null.</summary>
    private static string EjecutarMetodo(string sp, string campo, int id, string metodo)
    {
        try
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = sp;
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());
            cmd.Parameters.AddWithValue(campo, id);
            cmd.Parameters.AddWithValue("@METODO", string.IsNullOrEmpty(metodo) ? (object)DBNull.Value : metodo);
            cmd.Parameters.AddWithValue("@USUARIO", SitioBase.Session.UsuarioId());
            Conexion.GetDataTable(cmd);
            return null;
        }
        catch (Exception ex) { return ex.Message; }
    }

    private static double Numero(object v) { return v == null || v == DBNull.Value ? 0 : Convert.ToDouble(v); }

    private static double? NumeroONulo(object v) { return v == null || v == DBNull.Value ? (double?)null : Convert.ToDouble(v); }

    private static string Json(object o)
    {
        JavaScriptSerializer js = new JavaScriptSerializer();
        js.MaxJsonLength = int.MaxValue;
        return js.Serialize(o);
    }
}
