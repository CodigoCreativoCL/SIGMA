/* =====================================================================
   OPERACIÓN · Ejecuciones (lista única) · parte d
   Referencia: docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html (Operación › Ejecuciones)
   Une lo programado de los tres tipos de trabajo: Planes, Inspecciones y Tareas (SEL_OPERACION_EJECUCIONES, BD/401).
   Acciones: Generar OT (planes; individual o en lote, nunca en silencio), Hecha con Deshacer (tareas),
   Registrar (inspecciones: llega con la parte e).
   Comparte filtros e indicadores con las otras pestañas de Operación (window.OpShared).
   ===================================================================== */
(function () {
  var K = window.MantKit, L = window.MantLugar, CFG = K.CFG, OP = window.OpShared;
  if (!OP) return;
  var esc = K.esc, ic = K.ic, pl = K.pl, nrm = K.nrm, $ = K.$;
  var api = function (m, d) { return K.llamar(CFG.ws, m, d); };
  var WSC = CFG.base_ + 'WebService/WsCentroPlanificacion.asmx/';
  var URL_OT = CFG.base_ + 'View/Mantenimiento/Ordenes/Ordenes.aspx';

  var U = { filas: null, error: '', k: 'all', vista: 'list', f: 'att', plan: '', activo: '', par: false, q: '', sel: {}, wk: 0, mes: 0 };
  var TIPOS = { PLAN: ['k-plan', 'Plan', 'calw'], INSPECCION: ['k-ron', 'Inspección', 'clip'], TAREA: ['k-tar', 'Tarea', 'check'] };
  var SIT = { VENCIDA: ['Vencida', 'venc'], ATRASADA: ['Atrasada', 'atr'], DISPONIBLE: ['Disponible', 'disp'], FUTURA: ['Futura', 'fut'], CERRADA: ['Cerrada', 'cer'], ENCURSO: ['En curso', 'curso'], CANCELADA: ['Cancelada', 'can'] };
  var EXF = [['att', 'Requieren atención'], ['hoy', 'Hoy'], ['curso', 'En curso'], ['prox', 'Próximas'], ['sinot', 'Sin OT'], ['conot', 'Con OT'], ['hall', 'Con hallazgos'], ['cer', 'Completadas'], ['can', 'Canceladas'], ['all', 'Todas']];
  var DIAS = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'], MESES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  var cap = function (s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; };
  var dia = function (x) { return K.dIso(x.FECHA); };
  var pasada = function (x) { return dia(x) < K.TODAY; };
  var atencion = function (x) { return (x.SITUACION === 'VENCIDA' || x.SITUACION === 'ATRASADA') && !x.OT_ID; };
  var generable = function (x) { return x.TIPO === 'PLAN' && !x.OT_ID && (x.SITUACION === 'VENCIDA' || x.SITUACION === 'ATRASADA' || x.SITUACION === 'DISPONIBLE'); };
  var rangoSem = function () { var d = K.D(K.TODAY), w = K.wday(K.TODAY); return K.addD(K.TODAY, -(w - 1) + U.wk * 7); };

  /* ---------------------------------------------------------------- filtrado */
  function porTipo(x) { return U.k === 'all' || (U.k === 'plan' && x.TIPO === 'PLAN') || (U.k === 'ron' && x.TIPO === 'INSPECCION') || (U.k === 'tar' && x.TIPO === 'TAREA'); }
  function base(sinChip) {
    var q = nrm(U.q);
    return (U.filas || []).filter(function (x) {
      if (!porTipo(x)) return false;
      if (U.plan && x.REF !== U.plan) return false;
      if (U.activo && String(x.ACTIVO_ID) !== String(U.activo)) return false;
      if (U.par && !x.PARADA) return false;
      return !q || nrm([x.ACTIVO, x.ACTIVO_CODIGO, x.TITULO, x.REF, x.REF_NOMBRE, x.OT_NUMERO ? 'OT-' + x.OT_NUMERO : ''].join(' ')).indexOf(q) >= 0;
    });
  }
  function coincide(x, k) {
    if (k === 'all') return true;
    if (k === 'att') return atencion(x);
    if (k === 'hoy') return dia(x) === K.TODAY && x.SITUACION !== 'CANCELADA';
    if (k === 'curso') return x.SITUACION === 'ENCURSO';
    if (k === 'prox') return dia(x) > K.TODAY && x.SITUACION !== 'CANCELADA' && x.SITUACION !== 'CERRADA';
    if (k === 'sinot') return x.TIPO === 'PLAN' && !x.OT_ID && x.SITUACION !== 'CERRADA' && x.SITUACION !== 'CANCELADA';
    if (k === 'conot') return !!x.OT_ID;
    if (k === 'hall') return +x.HALLAZGOS > 0;
    if (k === 'cer') return x.SITUACION === 'CERRADA';
    if (k === 'can') return x.SITUACION === 'CANCELADA';
    return true;
  }
  var filtradas = function () { return base().filter(function (x) { return coincide(x, U.f); }); };

  /* ---------------------------------------------------------------- piezas */
  function sitChip(x) {
    var s = SIT[x.SITUACION] || ['', ''];
    var col = x.SITUACION === 'VENCIDA' ? 'var(--red)' : x.SITUACION === 'ATRASADA' ? 'var(--amber)' : x.SITUACION === 'DISPONIBLE' ? 'var(--sigma-cyan-dark)' : x.SITUACION === 'ENCURSO' ? 'var(--sigma-purple)' : x.SITUACION === 'CERRADA' ? 'var(--ok-ink)' : 'var(--faint)';
    return '<span class="cp-sit cp-sit-' + s[1] + '"><i style="background:' + col + '"></i>' + s[0] + '</span>';
  }
  var tag = function (x) { var t = TIPOS[x.TIPO]; return '<span class="cp-kd cp-' + t[0] + '">' + ic(t[2], 11) + t[1].toUpperCase() + '</span>'; };
  function accion(x) {
    if (x.OT_ID) return '<a class="cp-btn cp-out cp-xs" href="' + esc(URL_OT + '#ordenes&ot=' + x.QOT) + '">OT-' + x.OT_NUMERO + '</a>';
    if (generable(x)) return '<button type="button" class="cp-btn cp-sec cp-xs" data-a="exgen1" data-k="' + esc(x.KEY) + '">Generar OT</button>';
    if (x.TIPO === 'TAREA') return x.SITUACION === 'CERRADA' ? '<span class="cp-okd">' + ic('check', 13) + 'Hecha</span>' : '<button type="button" class="cp-btn cp-plain cp-xs" data-a="extar" data-k="' + esc(x.KEY) + '">' + ic('check', 13) + 'Hecha</button>';
    if (x.TIPO === 'INSPECCION') return x.SITUACION === 'CERRADA' ? '<span class="cp-okd' + (+x.HALLAZGOS ? ' cp-w' : '') + '">' + ic(+x.HALLAZGOS ? 'bell' : 'check', 13) + (+x.HALLAZGOS ? pl(+x.HALLAZGOS, 'hallazgo', 'hallazgos') : 'Sin hallazgos') + '</span>' : '<button type="button" class="cp-btn cp-out cp-xs" data-a="exreg" data-k="' + esc(x.KEY) + '">Registrar</button>';
    return '<span style="font-size:11.5px;color:var(--muted)">' + (x.SITUACION === 'FUTURA' ? 'desde ' + K.fD(dia(x)) : '') + '</span>';
  }
  var cuando = function (x) {
    if (x.SITUACION === 'VENCIDA' && x.LIMITE) return 'Venció ' + K.rel(K.dIso(x.LIMITE));
    return K.rel(dia(x)) + (x.TIPO !== 'PLAN' ? ' · ' + K.hIso(x.FECHA) : x.LIMITE && K.dIso(x.LIMITE) !== dia(x) ? ' · vence ' + K.fD(K.dIso(x.LIMITE)) : '');
  };

  /* ---------------------------------------------------------------- encabezado y filtros */
  function aviso() {
    var n = (U.filas || []).filter(function (x) { return x.TIPO === 'PLAN' && generable(x) && x.SITUACION !== 'DISPONIBLE'; }).length;
    return n ? '<div class="cp-pend">' + ic('clock', 18) + '<span><b>' + pl(n, 'ejecución de plan ya debería tener OT', 'ejecuciones de planes ya deberían tener OT') + '</b> y no la ' + (n === 1 ? 'tiene' : 'tienen') + '. SIGMA no las crea en silencio: revisa y confirma.</span><button type="button" class="cp-btn cp-sec cp-sm" data-a="expend">' + ic('plus', 15) + 'Generar OTs pendientes</button></div>' : '';
  }
  function barra() {
    var planes = {}, activos = {};
    (U.filas || []).forEach(function (x) { if (x.TIPO === 'PLAN' && x.REF) planes[x.REF] = x.REF_NOMBRE; activos[x.ACTIVO_ID] = x.ACTIVO_CODIGO + ' · ' + x.ACTIVO; });
    var tipos = '<div class="cp-segc" role="group" aria-label="Tipo de trabajo">' + [['all', 'Todo'], ['plan', 'Planes'], ['ron', 'Inspecciones'], ['tar', 'Tareas']].map(function (a) { return '<button type="button" data-a="exk" data-v="' + a[0] + '" aria-pressed="' + (U.k === a[0]) + '">' + a[1] + '</button>'; }).join('') + '</div>';
    var vistas = '<div class="cp-segc" role="group" aria-label="Vista">' + [['list', 'Lista'], ['week', 'Semana'], ['month', 'Mes']].map(function (a) { return '<button type="button" data-a="exview" data-v="' + a[0] + '" aria-pressed="' + (U.vista === a[0]) + '">' + a[1] + '</button>'; }).join('') + '</div>';
    var filtros = '<div class="cp-ex-f">' + (U.k === 'all' || U.k === 'plan' ? K.combo('exPlan', [{ id: '', n: 'Todos los planes' }].concat(Object.keys(planes).sort().map(function (k) { return { id: k, n: k + ' · ' + planes[k] }; })), U.plan, { etiqueta: 'Plan', ph: 'Todos los planes' }) : '') +
      K.combo('exActivo', [{ id: '', n: 'Todos los activos' }].concat(Object.keys(activos).map(function (k) { return { id: k, n: activos[k] }; })), U.activo, { etiqueta: 'Activo', ph: 'Todos los activos' }) +
      '<label class="cp-sw"><input type="checkbox" data-pv="ex_par"' + (U.par ? ' checked' : '') + '><i></i>Solo con parada</label>' +
      '<label class="cp-srch2" style="height:34px;min-width:220px;flex:1;max-width:320px">' + ic('search', 14) + '<input id="exq" data-pv="ex_q" data-live="1" value="' + esc(U.q) + '" placeholder="Activo, intervención u OT" aria-label="Buscar ejecuciones" autocomplete="off"></label>' +
      (U.plan || U.activo || U.par || U.q ? '<button type="button" class="cp-lnk" data-a="exclear">Limpiar filtros</button>' : '') + '</div>';
    var b = base(), cnt = function (k) { return b.filter(function (x) { return coincide(x, k); }).length; };
    var chips = U.vista === 'list' ? '<div class="cp-chips">' + EXF.map(function (a) { return '<button type="button" class="cp-fc" data-a="exf" data-v="' + a[0] + '" aria-pressed="' + (U.f === a[0]) + '">' + (a[0] === 'att' ? '<i style="background:var(--red)"></i>' : '') + a[1] + '<b>' + cnt(a[0]) + '</b></button>'; }).join('') + '</div>'
      : '<div class="cp-legend"><span><i style="background:var(--red)"></i>Vencida</span><span><i style="background:var(--amber)"></i>Atrasada</span><span><i style="background:var(--sigma-cyan-dark)"></i>Disponible</span><span><i style="background:var(--faint)"></i>Futura o con OT</span></div>';
    return '<div class="cp-card cp-ex-card"><div class="cp-ex-bar">' + tipos + vistas + filtros + '</div>' + chips + '</div>';
  }

  /* ---------------------------------------------------------------- lista */
  var COLS = 'grid-template-columns:24px 150px minmax(0,1fr) minmax(0,1.25fr) 132px 26px 104px';
  function listaHTML() {
    var todas = filtradas().sort(function (a, b) { return String(a.FECHA).localeCompare(String(b.FECHA)) || String(a.ACTIVO_CODIGO).localeCompare(String(b.ACTIVO_CODIGO)); }), lista = todas.slice(0, 80);
    var gen = lista.filter(generable), todasSel = gen.length && gen.every(function (x) { return U.sel[x.KEY]; }), nSel = Object.keys(U.sel).length;
    if (!todas.length) return '<div class="cp-card"><div class="cp-empty" style="border:0"><span class="cp-ei">' + ic('check', 20) + '</span><b>' + (U.f === 'att' ? 'Nada requiere atención' : 'Ninguna ejecución coincide') + '</b>' + (U.f === 'att' ? 'No hay ejecuciones vencidas ni atrasadas con estos filtros.' : 'Prueba con otra situación, plan o activo.') + (U.f !== 'all' ? '<button type="button" class="cp-btn cp-out cp-sm" data-a="exf" data-v="all">Ver todas</button>' : '') + '</div></div>';
    var filas = lista.map(function (x) {
      var g = generable(x), sel = !!U.sel[x.KEY];
      return '<div class="cp-rw cp-click' + (sel ? ' cp-rsel' : '') + '" style="' + COLS + '"' + (x.OT_ID ? ' data-a="exot" data-q="' + esc(x.QOT) + '"' : '') + '>' +
        '<span>' + (g ? '<input type="checkbox" class="cp-cbx" data-a="exsel" data-k="' + esc(x.KEY) + '"' + (sel ? ' checked' : '') + ' aria-label="Seleccionar ' + esc(x.ACTIVO_CODIGO) + '">' : '<input type="checkbox" class="cp-cbx" disabled title="' + (x.TIPO !== 'PLAN' ? 'Las inspecciones y tareas no generan OT en lote' : x.OT_ID ? 'Ya tiene OT' : 'Todavía no está disponible') + '" aria-label="No seleccionable">') + '</span>' +
        '<span class="cp-dt"><b>' + K.fD(dia(x)) + '</b><small>' + cuando(x) + '</small></span>' +
        '<span class="cp-s"><b>' + esc(x.ACTIVO) + '</b><small>' + esc(x.ACTIVO_CODIGO) + (x.PARADA ? ' · <span class="cp-pz2">con parada</span>' : '') + '</small></span>' +
        '<span class="cp-s"><b>' + tag(x) + ' ' + esc(x.TITULO) + '</b><small>' + (x.TIPO === 'PLAN' ? esc(x.REF) + ' · ' + esc(x.REF_NOMBRE) : x.TIPO === 'INSPECCION' ? 'Inspección' : esc(x.REF)) + '</small>' + (x.TIPO === 'PLAN' && +x.ACTIVIDADES ? '<span class="cp-tgs2"><span class="cp-tg">' + pl(+x.ACTIVIDADES, 'actividad', 'actividades') + '</span></span>' : '') + '</span>' +
        '<span>' + sitChip(x) + '</span><span class="cp-c-r">' + (x.RESPONSABLE ? K.avatar(x.RESPONSABLE) : '') + '</span><span style="text-align:right">' + accion(x) + '</span></div>';
    }).join('');
    return '<div class="cp-card cp-exl" style="padding:8px 10px"><div class="cp-rows"><div class="cp-rw cp-h" style="' + COLS + '"><span>' + (gen.length ? '<input type="checkbox" class="cp-cbx" data-a="exall"' + (todasSel ? ' checked' : '') + ' aria-label="Seleccionar todas las disponibles">' : '') + '</span><span>Fecha</span><span>Activo</span><span>Plan · intervención</span><span>Situación</span><span class="cp-c-r"></span><span></span></div>' + filas + '</div>' +
      (todas.length > lista.length ? '<p class="cp-more-n">Mostrando ' + lista.length + ' de ' + todas.length + '. Afina con los filtros para ver el resto.</p>' : '') +
      (nSel ? '<div class="cp-exbulk"><b>' + nSel + ' ' + (nSel === 1 ? 'seleccionada' : 'seleccionadas') + '</b><span style="flex:1"></span><button type="button" class="cp-btn cp-plain cp-sm" data-a="exclr">Quitar selección</button><button type="button" class="cp-btn cp-sec cp-sm" data-a="exbulk">' + ic('plus', 15) + 'Generar ' + nSel + ' OT</button></div>' : '') + '</div>';
  }

  /* ---------------------------------------------------------------- semana y mes */
  var evCls = function (x) { return x.SITUACION === 'VENCIDA' ? 'venc' : x.SITUACION === 'ATRASADA' ? 'atr' : x.SITUACION === 'DISPONIBLE' ? 'disp' : x.SITUACION === 'CERRADA' ? 'cer' : ''; };
  var ev = function (x) { return '<button type="button" class="cp-ev cp-ev-' + evCls(x) + '" data-a="exdet" data-k="' + esc(x.KEY) + '" title="' + esc(x.ACTIVO_CODIGO + ' · ' + x.TITULO) + '"><b>' + esc(x.ACTIVO_CODIGO) + '</b><span>' + esc(x.TITULO) + '</span></button>'; };
  function semanaHTML() {
    var ini = rangoSem(), dias = [0, 1, 2, 3, 4, 5, 6].map(function (k) { return K.addD(ini, k); }), todas = base();
    var cab = '<div class="cp-wk-h"><button type="button" class="cp-ibx" data-a="exwk" data-v="-1" aria-label="Semana anterior">' + ic('chev', 16).replace('<svg ', '<svg style="transform:rotate(180deg)" ') + '</button><b>' + K.fD(ini) + ' – ' + K.fD(K.addD(ini, 6)) + '</b><button type="button" class="cp-ibx" data-a="exwk" data-v="1" aria-label="Semana siguiente">' + ic('chev', 16) + '</button>' + (U.wk ? '<button type="button" class="cp-lnk" data-a="exwk" data-v="0">Esta semana</button>' : '') + '</div>';
    return '<div class="cp-card" style="padding:12px">' + cab + '<div class="cp-wk">' + dias.map(function (d, i) {
      var xs = todas.filter(function (x) { return dia(x) === d; }); return '<div class="cp-wk-d' + (d === K.TODAY ? ' cp-hoy' : '') + '"><div class="cp-wk-t"><small>' + DIAS[i] + '</small><b>' + K.D(d).getDate() + '</b></div>' + (xs.map(ev).join('') || '<span class="cp-wk-v">—</span>') + '</div>';
    }).join('') + '</div></div>';
  }
  function mesHTML() {
    var hoy = K.D(K.TODAY), primero = new Date(hoy.getFullYear(), hoy.getMonth() + U.mes, 1, 12), mes = primero.getMonth(), anio = primero.getFullYear();
    var off = (primero.getDay() + 6) % 7, ini = K.addD(K.iso(primero), -off), todas = base(), celdas = [];
    for (var i = 0; i < 42; i++) celdas.push(K.addD(ini, i));
    var cab = '<div class="cp-wk-h"><button type="button" class="cp-ibx" data-a="exmes" data-v="-1" aria-label="Mes anterior">' + ic('chev', 16).replace('<svg ', '<svg style="transform:rotate(180deg)" ') + '</button><b>' + MESES[mes] + ' ' + anio + '</b><button type="button" class="cp-ibx" data-a="exmes" data-v="1" aria-label="Mes siguiente">' + ic('chev', 16) + '</button>' + (U.mes ? '<button type="button" class="cp-lnk" data-a="exmes" data-v="0">Este mes</button>' : '') + '</div>';
    return '<div class="cp-card" style="padding:12px">' + cab + '<div class="cp-mo-h">' + DIAS.map(function (d) { return '<span>' + d + '</span>'; }).join('') + '</div><div class="cp-mo">' + celdas.map(function (d) {
      var xs = todas.filter(function (x) { return dia(x) === d; }), fuera = K.D(d).getMonth() !== mes;
      return '<div class="cp-mo-d' + (d === K.TODAY ? ' cp-hoy' : '') + (fuera ? ' cp-fuera' : '') + '"><b>' + K.D(d).getDate() + '</b>' + xs.slice(0, 3).map(ev).join('') + (xs.length > 3 ? '<small class="cp-mas-n">+' + (xs.length - 3) + ' más</small>' : '') + '</div>';
    }).join('') + '</div></div>';
  }

  /* ---------------------------------------------------------------- pintado y carga */
  function html() {
    if (U.error) return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudieron cargar las ejecuciones</b>' + esc(U.error) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="exreload">Reintentar</button></div>';
    if (!U.filas) return '<div class="cp-sk" style="height:60px"></div><div class="cp-sk" style="height:300px;margin-top:12px"></div>';
    return aviso() + barra() + (U.vista === 'week' ? semanaHTML() : U.vista === 'month' ? mesHTML() : listaHTML());
  }
  function pintar() {
    var b = $('#exRoot'); if (!b) return;
    var fo = K.grabFocus(b), sy = window.scrollY;
    b.innerHTML = html(); K.putFocus(fo, b); window.scrollTo(0, sy);
  }
  function cargar() {
    U.error = ''; U.filas = null; pintar();
    var f = OP.filtros();
    var ini = K.addD(K.TODAY, -60), fin = K.addD(K.TODAY, 120);
    return api('Ejecuciones', { planta: f.planta, area: f.area, responsable: f.responsable, criticidad: f.criticidad, desde: ini, hasta: fin }).then(function (r) { U.filas = r.filas || []; U.sel = {}; pintar(); }).catch(function (e) { U.error = e.message || 'Error'; pintar(); });
  }
  var porKey = function (k) { return (U.filas || []).filter(function (x) { return x.KEY === k; })[0]; };

  /* ---------------------------------------------------------------- acciones */
  var A = L.A;
  A.exreload = function () { cargar(); };
  A.exk = function (d) { U.k = d.v; U.plan = U.k === 'ron' || U.k === 'tar' ? '' : U.plan; pintar(); };
  A.exview = function (d) { U.vista = d.v; pintar(); };
  A.exf = function (d) { U.f = d.v; pintar(); };
  A.exclear = function () { U.plan = ''; U.activo = ''; U.par = false; U.q = ''; pintar(); };
  A.exwk = function (d) { U.wk = +d.v ? U.wk + (+d.v) : 0; pintar(); };
  A.exmes = function (d) { U.mes = +d.v ? U.mes + (+d.v) : 0; pintar(); };
  A.exot = function (d, el, e) { if (e && e.target.closest('a,button,input')) return; location.href = URL_OT + '#ordenes&ot=' + d.q; };
  A.exsel = function (d, el) { if (el.checked) U.sel[d.k] = true; else delete U.sel[d.k]; pintar(); };
  A.exall = function (d, el) { filtradas().slice(0, 80).filter(generable).forEach(function (x) { if (el.checked) U.sel[x.KEY] = true; else delete U.sel[x.KEY]; }); pintar(); };
  A.exclr = function () { U.sel = {}; pintar(); };
  A.exdet = function (d) { var x = porKey(d.k); if (!x) return; if (x.OT_ID) location.href = URL_OT + '#ordenes&ot=' + x.QOT; else if (generable(x)) A.exgen1({ k: d.k }); else K.toast(x.ACTIVO_CODIGO + ' · ' + x.TITULO + ': ' + (SIT[x.SITUACION] || [''])[0].toLowerCase() + '.'); };
  A.exreg = function () { K.toast('Registrar una inspección llega con la parte e (Inspecciones).'); };
  A.extar = function (d) {
    var x = porKey(d.k); if (!x) return;
    api('TareaHecha', { id: +x.ID, hecha: true }).then(function () {
      K.toast(x.TITULO + ': hecha.', function () { api('TareaHecha', { id: +x.ID, hecha: false }).then(cargar).catch(K.toastError); });
      cargar();
    }).catch(K.toastError);
  };
  function generar(tokens, cb) {
    return K.llamar(WSC, 'GenerarOt', { tokens: tokens.join(',') }).then(cb);
  }
  A.exgen1 = function (d) {
    var x = porKey(d.k); if (!x || !x.Q) return;
    generar([x.Q], function (r) {
      var y = (r.resultados || [])[0] || {};
      if (y.r === 'ok' || y.r === 'ya') K.toastA((y.r === 'ya' ? 'Ya tenía la ' : '') + 'OT-' + y.ot + (y.r === 'ok' ? ' generada.' : '.'), 'Abrir OT', function () { location.href = y.url || (URL_OT + '#ordenes'); });
      else K.toastError(new Error(y.detalle || 'No se pudo generar la OT.'));
      cargar(); OP.recargar();
    }).catch(K.toastError);
  };
  /* en lote o todas las pendientes: panel con la lista y la confirmación */
  var PG = function (st) {
    var l = st.lista, n = l.filter(function (x) { return st.sel[x.KEY]; }).length;
    return { t: st.todas ? 'Generar OTs pendientes' : 'Generar OT en lote', s: 'Se encontraron ' + pl(l.length, 'ejecución', 'ejecuciones') + (st.todas ? ' sin OT' : ' elegidas'), w: 'w',
      b: st.res ? '<div class="cp-bnr cp-' + (st.res.no ? 'w' : 'ok') + '">' + ic(st.res.no ? 'alert' : 'check', 18) + '<span><b>' + st.res.ok + ' generadas</b>' + (st.res.ya ? ' · ' + st.res.ya + ' ya existían' : '') + (st.res.no ? ' · ' + st.res.no + ' rechazadas' : '') + '</span></div><div class="cp-rows">' + st.res.det.map(function (d) { return '<div class="cp-rw" style="grid-template-columns:minmax(0,1fr) 160px"><span class="cp-s"><b>' + esc(d.t) + '</b><small>' + esc(d.m) + '</small></span><span>' + (d.r === 'no' ? '<span class="cp-tg cp-w">Rechazada</span>' : '<span class="cp-tg cp-c">OT-' + d.ot + '</span>') + '</span></div>'; }).join('') + '</div>'
        : '<div class="cp-bnr cp-i">' + ic('help', 18) + '<span>SIGMA no crea OT en silencio: revisa la lista y confirma. Se respetan las reglas de siempre (no duplica y rechaza con motivo).</span></div><div class="cp-rows">' + l.map(function (x) { return '<label class="cp-rw" style="grid-template-columns:28px minmax(0,1fr) 120px;cursor:pointer"><input type="checkbox" class="cp-cbx" data-pv="eg_' + esc(x.KEY) + '"' + (st.sel[x.KEY] ? ' checked' : '') + '><span class="cp-s"><b>' + esc(x.ACTIVO) + ' <small>' + esc(x.ACTIVO_CODIGO) + '</small></b><small>' + esc(x.REF) + ' · ' + esc(x.TITULO) + '</small></span><span class="cp-dt"><b>' + K.fD(dia(x)) + '</b><small>' + K.rel(dia(x)) + '</small></span></label>'; }).join('') + '</div>',
      f: st.res ? '<span></span><span class="cp-r"><button type="button" class="cp-btn cp-pri" data-a="pclose">Listo</button></span>' : '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-sec' + (st.busy ? ' cp-load' : '') + '" data-a="exgenok"' + (n ? '' : ' disabled') + '>' + ic('plus', 15) + 'Generar ' + n + ' ' + (n === 1 ? 'OT' : 'OTs') + '</button></span>' };
  };
  function abrirPanel(lista, todas) {
    var sel = {}; lista.forEach(function (x) { sel[x.KEY] = true; });
    K.Panel.open({ render: PG, st: { lista: lista, sel: sel, busy: false, res: null, todas: todas } });
  }
  A.expend = function () { abrirPanel((U.filas || []).filter(function (x) { return x.TIPO === 'PLAN' && generable(x) && x.SITUACION !== 'DISPONIBLE'; }), true); };
  A.exbulk = function () { abrirPanel((U.filas || []).filter(function (x) { return U.sel[x.KEY]; }), false); };
  A.exgenok = function () {
    var st = K.Panel.state(); if (!st) return;
    var xs = st.lista.filter(function (x) { return st.sel[x.KEY]; }); if (!xs.length) return;
    st.busy = true; K.Panel.paint();
    generar(xs.map(function (x) { return x.Q; }), function (r) {
      var res = { ok: 0, ya: 0, no: 0, det: [] };
      (r.resultados || []).forEach(function (y) { var f = xs.filter(function (x) { return x.Q === y.token; })[0] || {}; if (y.r === 'ok') res.ok++; else if (y.r === 'ya') res.ya++; else res.no++; res.det.push({ r: y.r, ot: y.ot, t: (f.ACTIVO_CODIGO || '') + ' · ' + (f.TITULO || ''), m: y.r === 'no' ? y.detalle : 'Generada' }); });
      st.busy = false; st.res = res; K.Panel.paint(); cargar(); OP.recargar();
    }).catch(function (e) { st.busy = false; K.Panel.paint(); K.toastError(e); });
  };

  L.on({
    pv: function (k, v) {
      if (k === 'ex_q') { U.q = v; pintar(); return; }
      if (k === 'ex_par') { U.par = !!v; pintar(); return; }
      if (k.indexOf('eg_') === 0) { var st = K.Panel.state(); if (st && st.sel) { st.sel[k.slice(3)] = !!v; K.Panel.paint(); } }
    },
    combo: function (span, v) {
      var n = span.getAttribute('data-cb');
      if (n === 'exPlan') { U.plan = v; pintar(); }
      if (n === 'exActivo') { U.activo = v; pintar(); }
    }
  });
  OP.suscribir(function () { if (U.filas) cargar(); });

  L.tab('ejecuciones', {
    mount: function (body) {
      body.innerHTML = '<div id="exRoot"></div>';
      var fi = window.OperacionFiltroEj; window.OperacionFiltroEj = null;
      if (typeof fi === 'string') U.f = fi;
      else if (fi) { U.f = fi.f || 'all'; U.k = fi.k || 'all'; U.plan = fi.plan || ''; U.activo = fi.activo ? String(fi.activo) : ''; }
      cargar();
    },
    hero: function () { return OP.hero(); }
  });
})();
