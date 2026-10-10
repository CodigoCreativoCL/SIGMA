/* =====================================================================
   OPERACIÓN · Ejecuciones (lista única) · parte d
   Referencia: docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html (Operación › Ejecuciones)
   Une lo programado de los tres tipos de trabajo: Planes, Inspecciones y Tareas (SEL_OPERACION_EJECUCIONES, BD/401).
   Acciones: Generar OT (planes; individual o en lote, nunca en silencio), Hecha con Deshacer (tareas),
   Registrar (inspecciones: cajón con la pauta, BD/418; lo que no cumple pasa a Avisos).
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
    if (x.TIPO === 'TAREA') return x.SITUACION === 'CERRADA' ? '<button type="button" class="cp-okd cp-okb" data-a="exver" data-k="' + esc(x.KEY) + '" title="Ver lo que se registró">' + ic('check', 13) + 'Hecha · ver</button>' : '<button type="button" class="cp-btn cp-plain cp-xs" data-a="extar" data-k="' + esc(x.KEY) + '">' + ic('check', 13) + 'Hecha</button>';
    if (x.TIPO === 'INSPECCION') return x.SITUACION === 'CERRADA' ? '<button type="button" class="cp-okd cp-okb' + (+x.HALLAZGOS ? ' cp-w' : '') + '" data-a="exreg" data-k="' + esc(x.KEY) + '" title="Ver lo que se registró">' + ic(+x.HALLAZGOS ? 'bell' : 'check', 13) + (+x.HALLAZGOS ? pl(+x.HALLAZGOS, 'hallazgo', 'hallazgos') : 'Sin hallazgos') + ' · ver</button>' : '<button type="button" class="cp-btn cp-out cp-xs" data-a="exreg" data-k="' + esc(x.KEY) + '">Registrar</button>';
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
        '<span class="cp-s"><b>' + tag(x) + ' ' + esc(x.TITULO) + (x.CHOQUE ? ' <span class="cp-tg cp-w" title="Choque de horario: ' + esc(x.CHOQUE) + '">' + ic('clock', 11) + 'Choque</span>' : '') + '</b><small>' + (x.TIPO === 'PLAN' ? esc(x.REF) + ' · ' + esc(x.REF_NOMBRE) : x.TIPO === 'INSPECCION' ? 'Inspección' : esc(x.REF)) + '</small>' + (x.TIPO === 'PLAN' && +x.ACTIVIDADES ? '<span class="cp-tgs2"><span class="cp-tg">' + pl(+x.ACTIVIDADES, 'actividad', 'actividades') + '</span></span>' : '') + '</span>' +
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
  /* 418 · registrar una inspección (PANELS.rocc del mockup): la pauta de la ocurrencia, con los mismos SP de la app. */
  var mc = function (cls, txt, ico) { return '<div class="cp-msg ' + (cls ? 'cp-' + cls : '') + '">' + ic(ico || (cls === 'i' ? 'help' : 'alert'), 13) + '<span>' + txt + '</span></div>'; };
  var TIT = { 5: 'ok', 4: 'num', 3: 'num', 1: 'txt', 2: 'txt', 12: 'foto' };
  var fN2 = function (n) { return String(+(+n).toFixed(2)).replace('.', ','); };
  var rango = function (it) { var a = it.MINIMO != null, b = it.MAXIMO != null, u = it.UNIDAD ? ' ' + it.UNIDAD : ''; return a && b ? fN2(it.MINIMO) + '–' + fN2(it.MAXIMO) + u : a ? 'mín. ' + fN2(it.MINIMO) + u : b ? 'máx. ' + fN2(it.MAXIMO) + u : ''; };
  function fuera(it, v) {
    var t = TIT[it.TIPO] || 'txt';
    if (t === 'ok') return v === 'no';
    if (t !== 'num' || v === '' || v == null || isNaN(+String(v).replace(',', '.'))) return false;
    var n = +String(v).replace(',', '.'); return (it.MINIMO != null && n < +it.MINIMO) || (it.MAXIMO != null && n > +it.MAXIMO);
  }
  var PREG = function (st) {
    if (st.cargando) return { t: 'Inspección', s: 'Operación · Registrar', w: 'n', b: '<div class="cp-sk" style="height:60px"></div><div class="cp-sk" style="height:260px;margin-top:12px"></div>' };
    var c = st.r.cab, its = st.r.items || [], can = !!c.PUEDE && st.r.puede, n = 0;
    var malos = its.filter(function (it) { return fuera(it, st.ans[it.ID]); });
    var secs = []; its.forEach(function (it) { var sc = secs.filter(function (z) { return z.n === it.SECCION; })[0]; if (!sc) { sc = { n: it.SECCION, items: [] }; secs.push(sc); } sc.items.push(it); });
    var form = secs.map(function (sc) {
      return '<div class="cp-rgs"><h5>' + esc(sc.n) + '</h5>' + sc.items.map(function (it) {
        var t = TIT[it.TIPO] || 'txt', v = st.ans[it.ID], bad = fuera(it, v), miss = st.err && t === 'num' && it.OBLIGATORIO && (v === '' || v == null);
        var ctl = t === 'ok' ? '<div class="cp-segc cp-sm3" role="group" aria-label="' + esc(it.TEXTO) + '">' + [['si', 'Cumple'], ['no', 'No cumple'], ['na', 'N/A']].map(function (o) { return '<button type="button" data-a="regans" data-i="' + it.ID + '" data-v="' + o[0] + '" aria-pressed="' + (v === o[0]) + '">' + o[1] + '</button>'; }).join('') + '</div>'
          : t === 'num' ? '<div class="cp-unit cp-sm2"><input id="rg' + it.ID + '" class="cp-inp' + (miss ? ' cp-err' : '') + '" type="number" step="any" data-pv="rg_' + it.ID + '" value="' + esc(v == null ? '' : v) + '" aria-label="' + esc(it.TEXTO) + '">' + (it.UNIDAD ? '<span class="cp-u">' + esc(it.UNIDAD) + '</span>' : '') + '</div>'
          : t === 'foto' ? '<small class="cp-muted2">La foto se adjunta desde la app</small>'
          : '<input id="rg' + it.ID + '" class="cp-inp" style="max-width:240px" data-pv="rg_' + it.ID + '" value="' + esc(v || '') + '" placeholder="Opcional" aria-label="' + esc(it.TEXTO) + '">';
        n++;
        return '<div class="cp-rgr' + (bad ? ' cp-bad' : '') + '"><div class="cp-rgn"><b>' + esc(it.TEXTO) + '</b>' + (it.CRITICO ? ' <span class="cp-tg cp-w">Crítico</span>' : '') + (t === 'num' && rango(it) ? '<small>Rango ' + esc(rango(it)) + '</small>' : '') + (bad ? '<small class="cp-rgf">' + ic('bell', 12) + 'Pasa a Avisos como hallazgo' + (it.CRITICO ? ' de severidad alta' : '') + '</small>' : '') + '</div>' + ctl + '</div>';
      }).join('') + '</div>';
    }).join('');
    var hecha = c.EJECUCION ? '<div class="cp-bnr cp-ok">' + ic('check', 18) + '<span><b>Registrada' + (c.HECHA_POR ? ' por ' + esc(c.HECHA_POR) : '') + '</b>' + (c.HECHA_EL ? ' el ' + K.fDL(K.dIso(c.HECHA_EL)) : '') + '. ' + ((st.r.hallazgos || []).length ? pl(st.r.hallazgos.length, 'hallazgo pasó', 'hallazgos pasaron') + ' a Avisos.' : 'Sin hallazgos.') + '</span></div>' +
      ((st.r.hallazgos || []).length ? '<div class="cp-mini">' + st.r.hallazgos.map(function (h) { return '<a class="cp-mini-r" href="' + esc(CFG.base_ + 'View/Mantenimiento/Avisos/Avisos.aspx') + '#avisos"><span class="cp-tg' + (+h.SEVERIDAD >= 4 ? ' cp-w' : '') + '">' + (+h.SEVERIDAD >= 4 ? 'Alta' : 'Media') + '</span><span><b>' + esc(h.ITEM) + '</b></span>' + ic('chev', 14) + '</a>'; }).join('') + '</div>' : '') : '';
    var b = '<div class="cp-exh"><span class="cp-tg">' + ic('clip', 11) + 'Inspección</span><span class="cp-tg">' + esc(c.ESTADO) + '</span><span class="cp-tg">' + pl(its.length, 'ítem', 'ítems') + '</span></div>' +
      (c.VENCIDA && !c.EJECUCION ? '<div class="cp-bnr cp-e">' + ic('alert', 18) + '<span>Venció el ' + K.fDL(K.dIso(c.LIMITE)) + '. Cuenta como no cumplida; puedes registrarla igual para dejar la evidencia.</span></div>' : '') +
      '<div class="cp-facts"><div><span>Fecha</span><b>' + K.fDL(K.dIso(c.FECHA)) + '</b><small>' + esc(String(c.FECHA || '').slice(11, 16)) + '</small></div><div><span>Responsable</span><b>' + (esc(c.RESPONSABLE) || 'Disponible') + '</b></div>' +
      '<div><span>Activo</span><b>' + esc(c.ACTIVO || '—') + '</b><small>' + esc(c.ACTIVO_CODIGO || '') + '</small></div><div><span>Pauta</span><b>' + esc(c.PAUTA_CODIGO) + ' v' + esc(c.PAUTA_VERSION) + '</b><small>' + esc(c.PAUTA) + '</small></div></div>' + hecha + (c.EJECUCION ? regHTML(st.r, secs) : '') +
      (can ? '<div class="cp-rgf2">' + form + '</div>' + (malos.length ? '<div class="cp-bnr cp-w">' + ic('bell', 18) + '<span><b>' + pl(malos.length, 'hallazgo', 'hallazgos') + '</b> se ' + (malos.length === 1 ? 'enviará' : 'enviarán') + ' a Avisos al registrar.</span></div>' : '') +
        '<div class="cp-fld"><label for="rgObs">Observación <small>opcional</small></label><textarea id="rgObs" class="cp-inp" rows="2" data-pv="rg_obs" placeholder="Algo que deba saber quien revise">' + esc(st.obs) + '</textarea></div>' + (st.err ? mc('', 'Completa las mediciones marcadas.') : '')
        : !c.EJECUCION ? mc('i', !st.r.puede ? 'Necesitas el permiso para ejecutar inspecciones para registrarla.' : c.ESTADO_ID > 3 ? 'Esta inspección está ' + String(c.ESTADO).toLowerCase() + '.' : 'Se puede registrar desde el ' + K.fDL(K.dIso(c.DISPONIBLE || c.FECHA)) + '.', 'help') : '');
    var f = '<button type="button" class="cp-btn cp-plain" data-a="pclose">Cerrar</button>' + (can ? '<span class="cp-r"><button type="button" class="cp-btn cp-pri' + (st.busy ? ' cp-load' : '') + '" data-a="regok">' + ic('check', 16) + 'Registrar inspección</button></span>' : '');
    return { t: esc(c.NOMBRE), s: 'Inspección · ' + esc(c.ACTIVO_CODIGO || ''), w: 'n', b: b, f: f };
  };
  A.exreg = function (d) {
    var id = +String(d.k || '').split('-')[1]; if (!id) return;
    var st = { t: 'reg', id: id, cargando: true, r: null, ans: {}, obs: '', err: false, busy: false };
    K.Panel.open({ render: PREG, st: st });
    api('Inspeccion', { ocurrencia: id }).then(function (r) {
      st.r = r; (r.items || []).forEach(function (it) { if ((TIT[it.TIPO] || 'txt') === 'ok') st.ans[it.ID] = 'si'; });
      st.cargando = false; if (K.Panel.state() === st) K.Panel.paint();
    }).catch(function (e) { K.Panel.close(); K.toastError(e); });
  };
  /* 425 · lo que se registró en terreno (app o web): datos de la ejecución, respuesta por ítem y fotos. */
  var fHM = function (s) { return s ? K.fD(K.dIso(s)) + ' ' + String(s).slice(11, 16) : '—'; };
  function fotosHTML(l) { return l && l.length ? '<div class="cp-fot">' + l.map(function (f) { return '<a href="' + esc(f.URL) + '" target="_blank" rel="noopener" title="' + esc(f.TITULO || 'Foto') + '"><img src="' + esc(f.URL) + '" alt="' + esc(f.TITULO || 'Foto de evidencia') + '" loading="lazy"></a>'; }).join('') + '</div>' : ''; }
  function ejecFacts(e, quien) {
    if (!e) return '';
    var dur = e.DURACION != null ? (+e.DURACION >= 60 ? K.fH(+e.DURACION / 60) : (+e.DURACION) + ' min') : '—';
    return '<div class="cp-blk"><div class="cp-blk-h"><h4>Lo que se registró</h4><small>' + esc(e.DISPOSITIVO || 'App') + (e.SIN_SENAL ? ' · registrada sin señal' : '') + '</small></div>' +
      '<div class="cp-facts"><div><span>Quién</span><b>' + esc(quien || '—') + '</b></div><div><span>Duración</span><b>' + dur + '</b><small>' + fHM(e.INICIO) + ' → ' + String(e.FIN || '').slice(11, 16) + '</small></div>' +
      (e.TOTAL != null ? '<div><span>Ítems</span><b>' + (+e.RESPONDIDOS || 0) + ' de ' + (+e.TOTAL || 0) + '</b><small>' + (+e.NO_CONFORMES ? pl(+e.NO_CONFORMES, 'no conforme', 'no conformes') : 'Todo conforme') + '</small></div>' : '') +
      (e.LAT != null && e.LNG != null ? '<div><span>Ubicación</span><b><a class="cp-lnk" href="https://www.google.com/maps?q=' + (+e.LAT) + ',' + (+e.LNG) + '" target="_blank" rel="noopener">Ver en el mapa</a></b></div>' : '') + '</div>' +
      (e.OBSERVACION ? '<p class="cp-obs">' + ic('help', 13) + esc(e.OBSERVACION) + '</p>' : '') + '</div>';
  }
  /* 427 · trazabilidad completa: línea de tiempo de la ocurrencia. */
  var TZI = { prog: 'calw', estado: 'clock', asig: 'check', acepta: 'check', inicio: 'clock', sync: 'arrow', fin: 'check', hallazgo: 'alert', descarte: 'x', ot: 'wrench', otini: 'wrench', otfin: 'check' };
  function trazaHTML(l) {
    if (!l || !l.length) return '';
    return '<div class="cp-blk"><div class="cp-blk-h"><h4>Trazabilidad</h4><small>' + pl(l.length, 'evento', 'eventos') + ', de lo más antiguo a lo más nuevo</small></div><ol class="cp-tz">' + l.map(function (e) {
      var cls = e.CLASE === 'hallazgo' ? (+e.SEVERIDAD >= 4 ? ' cp-tz-r' : ' cp-tz-a') : e.CLASE === 'fin' || e.CLASE === 'otfin' ? ' cp-tz-ok' : e.CLASE.indexOf('ot') === 0 ? ' cp-tz-p' : '';
      return '<li class="cp-tz-' + e.CLASE + cls + '"><span class="cp-tz-i">' + ic(TZI[e.CLASE] || 'clock', 12) + '</span><div class="cp-tz-b"><b>' + esc(e.TITULO) + '</b>' + (e.DETALLE ? '<small>' + esc(e.DETALLE) + '</small>' : '') +
        '<em>' + fHM(e.FECHA) + (e.QUIEN ? ' · ' + esc(e.QUIEN) : '') + '</em>' + (e.URL ? '<a class="cp-lnk" href="' + esc(e.URL) + '">Abrir la OT</a>' : '') + '</div></li>';
    }).join('') + '</ol></div>';
  }
  function regHTML(r, secs) {
    var res = {}, fot = {}; (r.respuestas || []).forEach(function (x) { res[x.ITEM] = x; }); (r.fotos || []).forEach(function (f) { (fot[f.ITEM] = fot[f.ITEM] || []).push(f); });
    return ejecFacts(r.ejecucion, r.cab.HECHA_POR) + trazaHTML(r.traza) + '<div class="cp-rgf2">' + secs.map(function (sc) {
      return '<div class="cp-rgs"><h5>' + esc(sc.n) + '</h5>' + sc.items.map(function (it) {
        var x = res[it.ID];
        return '<div class="cp-rgr' + (x && x.FUERA ? ' cp-bad' : '') + '"><div class="cp-rgn"><b>' + esc(it.TEXTO) + '</b>' + (it.CRITICO ? ' <span class="cp-tg cp-w">Crítico</span>' : '') + (x && x.COMENTARIO ? '<small>«' + esc(x.COMENTARIO) + '»' + (x.VOZ ? ' · dictado por voz' : '') + '</small>' : '') + fotosHTML(fot[it.ID]) + '</div>' +
          '<span class="cp-rgv' + (x && x.FUERA ? ' cp-bad' : x && x.NA ? ' cp-na' : '') + '">' + (x ? esc(x.VALOR || '—') : '<span class="cp-muted2">Sin respuesta</span>') + (x && x.FUERA ? '<small>' + ic('bell', 11) + 'Fuera de rango</small>' : '') + '</span></div>';
      }).join('') + '</div>';
    }).join('') + '</div>';
  }
  /* 425 · tarea hecha en terreno: quién, cuándo, cuánto duró, resultado y fotos. */
  var PTAR = function (st) {
    if (st.cargando) return { t: 'Tarea', s: 'Operación', w: 'n', b: '<div class="cp-sk" style="height:60px"></div><div class="cp-sk" style="height:200px;margin-top:12px"></div>' };
    var c = st.r.cab, ej = st.r.ejecuciones || [], fot = {}; (st.r.fotos || []).forEach(function (f) { (fot[f.EJECUCION] = fot[f.EJECUCION] || []).push(f); });
    var b = '<div class="cp-exh"><span class="cp-tg">' + ic('check', 11) + 'Tarea</span><span class="cp-tg">' + esc(c.ESTADO) + '</span>' + (c.OT_ID ? '<a class="cp-tg cp-p" href="' + esc(URL_OT + '#ordenes&ot=' + c.QOT) + '">Con OT</a>' : '') + '</div>' +
      '<div class="cp-facts"><div><span>Programada</span><b>' + fHM(c.FECHA) + '</b></div><div><span>Asignada a</span><b>' + (esc(c.ASIGNADOS) || 'Disponible') + '</b></div><div><span>Activo</span><b>' + esc(c.ACTIVO || '—') + '</b><small>' + esc(c.ACTIVO_CODIGO || '') + '</small></div><div><span>Código</span><b>' + esc(c.CODIGO) + '</b></div></div>' +
      (c.DESCRIPCION ? '<p class="cp-obs">' + esc(c.DESCRIPCION) + '</p>' : '') +
      (ej.length ? ej.map(function (e) {
        return ejecFacts(e, e.QUIEN) + '<div class="cp-rgr' + (e.CONFORME === false ? ' cp-bad' : '') + '" style="border:0"><div class="cp-rgn"><b>Resultado</b><small>' + (esc(e.RESULTADO) || 'Sin comentario') + '</small>' + fotosHTML(fot[e.ID]) + '</div><span class="cp-rgv' + (e.CONFORME === false ? ' cp-bad' : '') + '">' + (e.CONFORME == null ? '—' : e.CONFORME ? 'Conforme' : 'No conforme') + '</span></div>';
      }).join('') + trazaHTML(st.r.traza) : trazaHTML(st.r.traza) + (c.ESTADO_ID === 4 || c.ESTADO_ID === 5 ? mc('i', 'Se marcó como hecha desde la web, sin registro de terreno.' + (c.OBSERVACION ? ' Observación: ' + esc(c.OBSERVACION) : ''), 'help') : mc('i', 'Todavía no se ejecuta.', 'help')));
    return { t: esc(c.NOMBRE), s: esc(c.CODIGO) + ' · tarea recurrente', w: 'n', b: b, f: '<span></span><span class="cp-r"><button type="button" class="cp-btn cp-plain" data-a="pclose">Cerrar</button></span>' };
  };
  A.exver = function (d) {
    var id = +String(d.k || '').split('-')[1]; if (!id) return;
    var st = { t: 'tar', cargando: true, r: null };
    K.Panel.open({ render: PTAR, st: st });
    api('Tarea', { ocurrencia: id }).then(function (r) { st.r = r; st.cargando = false; if (K.Panel.state() === st) K.Panel.paint(); }).catch(function (e) { K.Panel.close(); K.toastError(e); });
  };
  A.regans = function (d) { var st = K.Panel.state(); if (!st || st.t !== 'reg') return; st.ans[+d.i] = d.v; K.Panel.paint(); };
  A.regok = function () {
    var st = K.Panel.state(); if (!st || st.t !== 'reg' || st.busy) return;
    var its = st.r.items || [];
    st.err = its.some(function (it) { var v = st.ans[it.ID]; return (TIT[it.TIPO] || 'txt') === 'num' && it.OBLIGATORIO && (v === '' || v == null); });
    if (st.err) { K.Panel.paint(); var e1 = $('#cpLayer .cp-err'); if (e1) e1.focus(); return; }
    st.busy = true; K.Panel.paint();
    api('RegistrarInspeccion', { datos: JSON.stringify({ ocurrencia: st.id, observacion: st.obs, respuestas: its.map(function (it) { return { item: it.ID, tipo: TIT[it.TIPO] || 'txt', v: st.ans[it.ID] == null ? '' : String(st.ans[it.ID]) }; }) }) })
      .then(function (r) {
        K.Panel.close(); var h = +r.hallazgos || 0;
        if (h) K.toastA('Inspección registrada. ' + pl(h, 'hallazgo pasó', 'hallazgos pasaron') + ' a Avisos.', 'Ver avisos', function () { location.href = CFG.base_ + 'View/Mantenimiento/Avisos/Avisos.aspx#avisos'; });
        else K.toast('Inspección registrada. Sin hallazgos.');
        cargar(); OP.recargar();
      }).catch(function (e) { st.busy = false; K.Panel.paint(); K.toastError(e); });
  };
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
      if (k.indexOf('rg_') === 0) { var sr = K.Panel.state(); if (!sr || sr.t !== 'reg') return; if (k === 'rg_obs') { sr.obs = v; return; } var it = +k.slice(3), was = fuera((sr.r.items || []).filter(function (z) { return z.ID === it; })[0] || {}, sr.ans[it]); sr.ans[it] = v; var now = fuera((sr.r.items || []).filter(function (z) { return z.ID === it; })[0] || {}, v); if (was !== now || (sr.err && v !== '')) { sr.err = false; K.Panel.paint(); var el = $('#rg' + it); if (el) { el.focus(); var L2 = String(el.value).length; try { el.setSelectionRange(L2, L2); } catch (e2) { } } } return; }
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
      /* #ejecuciones&plan=PMA-1 (desde el menú «…» del plan en Planificación) */
      var hk = /[#&]k=(\w+)/.exec(location.hash), hf = /[#&]f=(\w+)/.exec(location.hash), hq = /[#&]q=([^&]*)/.exec(location.hash);
      if (hk || hf || hq) { if (hk) U.k = hk[1]; if (hf) U.f = hf[1]; if (hq) U.q = decodeURIComponent(hq[1]); if (!/[#&]plan=/.test(location.hash)) { try { history.replaceState(null, '', '#ejecuciones'); } catch (e) { } } }
      var mp = /[#&]plan=([^&]+)/.exec(location.hash); if (mp) { U.plan = decodeURIComponent(mp[1]); U.k = 'plan'; U.f = 'all'; try { history.replaceState(null, '', '#ejecuciones'); } catch (e) { } }
      cargar();
    },
    hero: function () { return OP.hero(); }
  });
})();
