/* =====================================================================
   OPERACIÓN · Hoy (centro de control del día) · parte d
   Referencia: docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html (Operación › Hoy)
   Datos: WsOperacion.asmx (SEL_OPERACION_HOY, BD/400). Las fechas están en hora de la planta.
   Filtros persistentes (planta, área, responsable, criticidad): se guardan en la sesión del navegador.
   Las demás pestañas (Sala de control, Ejecuciones, Cumplimiento) se registran en sus propios archivos.
   ===================================================================== */
(function () {
  var K = window.MantKit, L = window.MantLugar, CFG = K.CFG;
  var esc = K.esc, ic = K.ic, pl = K.pl, $ = K.$;
  var api = function (m, d) { return K.llamar(CFG.ws, m, d); };
  var WSC = CFG.base_ + 'WebService/WsCentroPlanificacion.asmx/';
  var URL_OT = CFG.base_ + 'View/Mantenimiento/Ordenes/Ordenes.aspx';
  var URL_AV = CFG.base_ + 'View/Mantenimiento/Avisos/Avisos.aspx';

  var lsGet = function () { try { return JSON.parse(sessionStorage.getItem('opFiltros') || '{}'); } catch (e) { return {}; } };
  var lsSet = function (o) { try { sessionStorage.setItem('opFiltros', JSON.stringify(o)); } catch (e) { } };
  var F0 = lsGet();
  var U = { area: +F0.area || 0, resp: +F0.resp || 0, crit: +F0.crit || 0, agf: 'all', aqo: null, filtros: null, hoy: null, error: '', cargando: true };
  var SUB = [];   // quienes quieren saber cuando cambian los filtros (las otras pestañas)
  var CRIT = { 1: 'Baja', 2: 'Media', 3: 'Alta', 4: 'Crítica' };
  var MODOS = { DETENIDO: ['stop', 'Activo detenido', 'alert'], MANTENCION: ['live', 'En mantención ahora', 'wrench'], ATENCION: ['att', 'Requiere atención', 'alert'], PROGRAMADO: ['sched', 'Mantención programada', 'calw'], NORMAL: ['ok', 'Operando normal', 'check'] };
  var ORDEN_MODO = ['stop', 'live', 'att', 'sched', 'ok'];
  var cap = function (s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; };
  var hm = function (s) { return K.hIso(s) || ''; };
  var hmin = function (s) { var h = hm(s).split(':'); return (+h[0] || 0) * 60 + (+h[1] || 0); };
  var ahoraDate = function () { var d = new Date(); return d.getHours() * 60 + d.getMinutes(); };
  var nowHM = function () { var d = new Date(), p = function (n) { return (n < 10 ? '0' : '') + n; }; return p(d.getHours()) + ':' + p(d.getMinutes()); };
  var quien = function (n) { var p = String(n || '').trim().split(/\s+/); return p.length > 1 ? p[0] + ' ' + p[1].charAt(0) + '.' : p[0] || ''; };

  /* ---------------------------------------------------------------- gráficos (el mismo trazo del mockup) */
  function miniChart(vals, labs, o) {
    o = o || {};
    var W = o.w || 320, H = o.h || 132, Lm = 30, R = 10, T = 16, B = 22, max = o.max || Math.max.apply(null, vals.concat([o.meta || 0, 1])) * 1.15 || 1, iw = W - Lm - R, ih = H - T - B;
    var x = function (i) { return Lm + (vals.length === 1 ? iw / 2 : (o.type === 'bar' ? (i + .5) * iw / vals.length : i * iw / (vals.length - 1))); };
    var y = function (v) { return T + ih - v / max * ih; }, f = o.fmt || function (v) { return K.fN(v, v % 1 ? 1 : 0); };
    var g = [0, max / 2, max].map(function (t) { return Math.round(t * 10) / 10; }).map(function (t) { return '<line x1="' + Lm + '" x2="' + (W - R) + '" y1="' + y(t) + '" y2="' + y(t) + '" class="cp-cg"/><text x="' + (Lm - 6) + '" y="' + (y(t) + 3.5) + '" text-anchor="end" class="cp-ct">' + f(t) + '</text>'; }).join('');
    if (o.meta) g += '<line x1="' + Lm + '" x2="' + (W - R) + '" y1="' + y(o.meta) + '" y2="' + y(o.meta) + '" class="cp-cmeta"/><text x="' + (Lm + 4) + '" y="' + (y(o.meta) - 4) + '" class="cp-ct cp-ctm">Meta ' + f(o.meta) + '</text>';
    var m = '';
    if (o.type === 'bar') {
      var bw = Math.min(26, iw / vals.length - 8);
      m = vals.map(function (v, i) { var h = Math.max(2, y(0) - y(v)), x0 = x(i) - bw / 2, r = Math.min(4, h); return '<path class="cp-cb' + (i === vals.length - 1 ? ' cp-last' : '') + '" d="M' + x0 + ',' + y(0) + ' V' + (y(v) + r) + ' Q' + x0 + ',' + y(v) + ' ' + (x0 + r) + ',' + y(v) + ' H' + (x0 + bw - r) + ' Q' + (x0 + bw) + ',' + y(v) + ' ' + (x0 + bw) + ',' + (y(v) + r) + ' V' + y(0) + ' Z"><title>' + esc(labs[i]) + ': ' + f(v) + (o.u || '') + '</title></path>'; }).join('');
    } else {
      var pts = vals.map(function (v, i) { return v == null ? null : x(i) + ',' + y(v); }).filter(Boolean).join(' ');
      m = '<polyline class="cp-cl" points="' + pts + '"/>' + vals.map(function (v, i) { return v == null ? '' : '<circle class="cp-cp2' + (i === vals.length - 1 ? ' cp-last' : '') + '" cx="' + x(i) + '" cy="' + y(v) + '" r="' + (i === vals.length - 1 ? 4.5 : 3) + '"><title>' + esc(labs[i]) + ': ' + f(v) + (o.u || '') + '</title></circle>'; }).join('');
    }
    var lv = vals[vals.length - 1];
    if (lv != null) m += '<text x="' + Math.min(x(vals.length - 1), W - R - 2) + '" y="' + (y(lv) - 9) + '" text-anchor="' + (o.type === 'bar' ? 'middle' : 'end') + '" class="cp-ct cp-cv">' + f(lv) + (o.u || '') + '</text>';
    var xl = labs.map(function (l, i) { return '<text x="' + x(i) + '" y="' + (H - 6) + '" text-anchor="middle" class="cp-ct">' + esc(l) + '</text>'; }).join('');
    return '<svg viewBox="0 0 ' + W + ' ' + H + '" class="cp-mch" role="img" aria-label="' + esc(o.aria || '') + '">' + g + m + xl + '</svg>';
  }

  /* ---------------------------------------------------------------- indicadores */
  function kpis(k) {
    var kq = function (cls, v, l, sub, go, title) { return '<button type="button" class="cp-kq ' + cls + '" data-a="opgo" data-go="' + go + '" title="' + title + '"><small>' + l + '</small><b class="cp-tn">' + v + '</b><span>' + sub + '</span></button>'; };
    return '<div class="cp-kq-row">' +
      kq(+k.CUMPLIMIENTO < 90 ? 'cp-w' : 'cp-g', k.CUMPLIMIENTO + ' %', 'Cumplimiento', '40 días · meta 90 %', 'cumplimiento', 'Ver Cumplimiento') +
      kq('', k.HOY_N, 'Trabajo de hoy', k.HOY_HECHAS + ' completados · ' + k.HOY_CURSO + ' en curso', 'hoy', 'Ver lo de hoy en Ejecuciones') +
      kq(+k.ATRASADAS ? 'cp-r' : '', k.ATRASADAS, 'Atrasadas', 'vencidas y atrasadas', 'att', 'Ver las atrasadas en Ejecuciones') +
      kq('', k.OT_ABIERTAS, 'OT abiertas', k.OT_PROGRESO + ' en progreso', 'otabiertas', 'Ver las OT abiertas') +
      kq(+k.OT_VENCIDAS ? 'cp-r' : '', k.OT_VENCIDAS, 'OT vencidas', 'fuera de plazo', 'otvencidas', 'Ver las OT vencidas') +
      kq(+k.RIESGO ? 'cp-w' : '', k.RIESGO, 'Activos en riesgo', 'criticidad A-B con señal', 'riesgo', 'Ver los activos en riesgo') + '</div>';
  }

  /* ---------------------------------------------------------------- agenda de hoy */
  var AGF = [['all', 'Todo'], ['g-pend', 'Pendiente'], ['g-live', 'En curso'], ['g-late', 'Atrasado'], ['g-done', 'Completado']];
  function agState(x) {
    var ot = +x.OT_ESTADO || 0, e = +x.ESTADO;
    if (x.TIPO === 'OT') return ot === 2 ? ['g-live', 'En progreso'] : ot === 3 ? ['g-done', 'Completada'] : x.FECHA && K.dIso(x.FECHA) < K.TODAY ? ['g-late', 'Atrasada'] : ['g-pend', 'OT ' + (ot === 1 ? 'por iniciar' : 'abierta')];
    if (e === 4 || ot === 4) return ['g-done', 'Completada'];
    if (ot === 2 || e === 3) return ['g-live', 'En curso'];
    if (ot === 3) return ['g-done', 'Completada'];
    if (x.OT_NUMERO) return ['g-pend', 'OT asignada'];
    var pasada = K.dIso(x.FECHA) < K.TODAY || (K.dIso(x.FECHA) === K.TODAY && hmin(x.FECHA) < ahoraDate());
    return pasada ? ['g-late', 'Atrasada'] : ['g-pend', 'Pendiente'];
  }
  var agGrp = function (st) { return st === 'g-fut' ? 'g-pend' : st; };
  var KD = { PLAN: ['k-plan', 'Plan'], INSPECCION: ['k-ron', 'Inspección'], TAREA: ['k-tar', 'Tarea'], OT: ['k-otx', 'OT'] };
  function agAct(x) {
    if (x.OT_NUMERO) return '<a class="cp-btn cp-out cp-sm" href="' + esc(URL_OT + '#ordenes&ot=' + (x.QOT || '')) + '">OT-' + x.OT_NUMERO + '</a>';
    if (x.TIPO === 'PLAN' && x.Q && !(+x.ESTADO === 4)) return '<button type="button" class="cp-btn cp-sec cp-sm" data-a="opgen" data-q="' + esc(x.Q) + '">Generar OT</button>';
    return '';
  }
  function agendaHTML(H) {
    var all = H.agenda || [], cnt = function (k) { return k === 'all' ? all.length : all.filter(function (x) { return agGrp(agState(x)[0]) === k; }).length; };
    var items = U.agf === 'all' ? all : all.filter(function (x) { return agGrp(agState(x)[0]) === U.agf; }), done = cnt('g-done'), rows = '', lineDone = U.agf !== 'all', now = ahoraDate();
    /* Primero la hora actual y de ahí hacia lo más antiguo. */
    items = items.slice().sort(function (p, q) { return p.FECHA < q.FECHA ? 1 : p.FECHA > q.FECHA ? -1 : 0; });
    rows += '<li class="cp-ag-now"><span>' + nowHM() + '</span><i></i><em>Ahora</em></li>';
    items.forEach(function (x) {
      var st = agState(x);
      rows += '<li class="cp-ag ' + st[0].replace('g-', 'cp-g-') + '"><span class="cp-ag-t">' + hm(x.FECHA) + '</span><span class="cp-ag-dot"></span><div class="cp-ag-b"><span class="cp-ag-h"><span class="cp-kd cp-' + KD[x.TIPO][0] + '">' + KD[x.TIPO][1] + '</span><b>' + esc(x.TITULO) + '</b></span><small>' + esc(x.ACTIVO) + ' · ' + esc(x.ACTIVO_CODIGO) + (x.RESPONSABLE ? ' · ' + esc(quien(x.RESPONSABLE)) : '') + '</small></div>' +
        '<span class="cp-ag-s"><span class="cp-gst ' + st[0].replace('g-', 'cp-g-') + '"><i></i>' + st[1] + '</span>' + agAct(x) + '</span></li>';
    });
    return '<section class="cp-card cp-ag-c"><div class="cp-sc-h"><h3>Agenda de hoy</h3><small>' + cap(K.fDL(K.TODAY)) + ' · ' + done + ' de ' + all.length + ' completados</small><div class="cp-r"><button type="button" class="cp-lnk" data-a="opgo" data-go="hoy">Ver en Ejecuciones</button></div></div>' +
      '<div class="cp-ag-p"><span><i style="width:' + (all.length ? done / all.length * 100 : 0) + '%"></i></span><small>' + (all.length ? Math.round(done / all.length * 100) : 0) + ' % del día</small></div>' +
      '<div class="cp-chips cp-agf">' + AGF.map(function (a) { return '<button type="button" class="cp-fc" data-a="opagf" data-v="' + a[0] + '" aria-pressed="' + (U.agf === a[0]) + '">' + (a[0] !== 'all' ? '<i class="cp-gi ' + a[0].replace('g-', 'cp-g-') + '"></i>' : '') + a[1] + '<b>' + cnt(a[0]) + '</b></button>'; }).join('') + '</div>' +
      (items.length ? '<ol class="cp-agl">' + rows + '</ol>' : '<div class="cp-empty" style="border:0"><span class="cp-ei">' + ic('check', 20) + '</span><b>' + (all.length ? 'Nada en este estado' : 'Nada programado para hoy con estos filtros') + '</b>' + (all.length ? '<button type="button" class="cp-btn cp-out cp-sm" data-a="opagf" data-v="all">Ver todo</button>' : '') + '</div>') + '</section>';
  }

  /* ---------------------------------------------------------------- atención requerida */
  var rel = function (s) { return K.rel(K.dIso(s)); };
  function atencionHTML(H) {
    var li = function (h, s, a) { return '<li><button type="button" ' + a + '><b>' + h + '</b><small>' + s + '</small></button></li>'; };
    var late = H.atrasadas || [], pend = H.sinOt || [], otl = H.otVencidas || [], av = H.avisos || [], risk = H.riesgo || [], k = H.kpi;
    var cats = [
      { k: 'late', cls: 'cp-ar-r', ico: 'alert', n: +k.ATRASADAS, p: late[0] && late[0].ACTIVO_CODIGO + ' · ' + late[0].TITULO, t: 'Atrasadas o vencidas', l: late.slice(0, 4).map(function (x) { return li(esc(x.ACTIVO_CODIGO) + ' · ' + esc(x.TITULO), ({ PLAN: 'Plan', INSPECCION: 'Inspección', TAREA: 'Tarea' })[x.TIPO] + ' · era ' + rel(x.FECHA), 'data-a="opgo" data-go="att"'); }), cta: '<button type="button" class="cp-btn cp-out cp-sm" data-a="opgo" data-go="att">Ver las ' + k.ATRASADAS + ' en Ejecuciones</button>' },
      { k: 'pend', cls: 'cp-ar-c', ico: 'clock', n: pend.length, p: pend[0] && pend[0].ACTIVO_CODIGO + ' · ' + pend[0].TITULO, t: 'Ejecuciones sin OT', l: pend.slice(0, 4).map(function (x) { return li(esc(x.ACTIVO_CODIGO) + ' · ' + esc(x.TITULO), K.fD(K.dIso(x.FECHA)) + ' · ' + rel(x.FECHA), 'data-a="opgo" data-go="hoy"'); }), cta: '<button type="button" class="cp-btn cp-sec cp-sm" data-a="oppend">' + ic('plus', 15) + 'Generar OTs pendientes</button>' },
      { k: 'otl', cls: 'cp-ar-r', ico: 'wrench', n: otl.length, p: otl[0] && 'OT-' + otl[0].NUMERO + ' · ' + otl[0].TITULO, t: 'OT vencidas', l: otl.slice(0, 4).map(function (o) { return li('OT-' + o.NUMERO + ' · ' + esc(o.TITULO), esc(o.ACTIVO_CODIGO) + ' · venció ' + rel(o.PROGRAMADA), 'data-a="opot" data-q="' + esc(o.QOT) + '"'); }), cta: '<a class="cp-btn cp-out cp-sm" href="' + esc(URL_OT) + '#ordenes">Ver las OT</a>' },
      { k: 'hall', cls: 'cp-ar-a', ico: 'bell', n: +k.AVISOS_N, p: av[0] && av[0].ACTIVO_CODIGO + ' · ' + av[0].TITULO, t: 'Hallazgos y fallas por evaluar', l: av.slice(0, 4).map(function (a) { return li(esc(a.ACTIVO_CODIGO) + ' · ' + esc(a.TITULO), esc(a.AVISO) + ' · ' + rel(a.FECHA), 'data-a="opav"'); }), cta: '<a class="cp-btn cp-out cp-sm" href="' + esc(URL_AV) + '#avisos">Ir a Avisos</a>' },
      { k: 'risk', cls: 'cp-ar-p', ico: 'shield', n: risk.length, p: risk[0] && risk[0].CODIGO + ' · ' + risk[0].NOMBRE, t: 'Activos en riesgo', l: risk.slice(0, 4).map(function (o) { return li(esc(o.CODIGO) + ' · ' + esc(o.NOMBRE), esc(o.AREA || '') + ' · ' + esc(o.SENAL), 'data-a="opriesgo"'); }), cta: '' }
    ].filter(function (c) { return c.n; });
    var openK = U.aqo || (cats[0] && cats[0].k), total = cats.reduce(function (s, c) { return s + c.n; }, 0);
    return '<section class="cp-card cp-atq"><div class="cp-sc-h"><h3>Atención requerida</h3><small>' + (total ? pl(total, 'asunto', 'asuntos') : 'Todo al día') + '</small></div>' +
      (cats.length ? '<div class="cp-aql">' + cats.map(function (c) { return '<details class="cp-aq ' + c.cls + '" data-aq="' + c.k + '"' + (c.k === openK ? ' open' : '') + '><summary><span class="cp-ar-i">' + ic(c.ico, 15) + '</span><b class="cp-tn cp-aq-n">' + c.n + '</b><span class="cp-aq-t"><b>' + c.t + '</b><small>' + esc(c.p || '') + (c.n > 1 ? ' y ' + (c.n - 1) + ' más' : '') + '</small></span><span class="cp-aq-c">' + ic('chev', 15) + '</span></summary><ul>' + c.l.join('') + '</ul>' + (c.cta ? '<div class="cp-aq-f">' + c.cta + '</div>' : '') + '</details>'; }).join('') + '</div>'
        : '<div class="cp-empty" style="border:0"><span class="cp-ei">' + ic('check', 20) + '</span><b>Nada requiere atención</b>Todo lo programado está al día.</div>') + '</section>';
  }
  function iaHTML(H) {
    var a = (H.avisos || []).filter(function (x) { return +x.ORIGEN === 5; })[0];
    if (!a) return '';
    return '<section class="cp-sai"><div class="cp-sai-h"><b class="cp-sai-k">' + ic('spark', 14) + 'Recomendación de SIGMA AI</b></div><p>' + esc(a.TITULO) + '</p><small>' + esc(a.ACTIVO_CODIGO) + ' · ' + esc(a.AVISO) + '</small><div class="cp-sai-a"><a class="cp-btn cp-plain cp-sm" href="' + esc(URL_AV) + '#avisos">Ver aviso</a></div></section>';
  }

  /* ---------------------------------------------------------------- estado por área */
  function areas(H) {
    var m = {};
    (H.activos || []).forEach(function (a) {
      var k = (a.PLANTA || '') + '|' + (a.AREA_ID || 0), g = m[k] = m[k] || { k: k, pl: a.PLANTA, ar: a.AREA, id: a.AREA_ID || 0, ast: [], hoy: 0, late: 0, ot: 0, av: 0 };
      g.ast.push({ a: a, s: MODOS[a.ESTADO][0] }); g.hoy += +a.HOY_N; g.late += +a.ATRASOS_N; g.ot += +a.OT_N; g.av += +a.AVISOS_N;
    });
    return Object.keys(m).map(function (k) { var g = m[k]; g.mode = ORDEN_MODO.filter(function (x) { return g.ast.some(function (o) { return o.s === x; }); })[0] || 'ok'; return g; })
      .sort(function (a, b) { return ORDEN_MODO.indexOf(a.mode) - ORDEN_MODO.indexOf(b.mode) || b.late - a.late || b.hoy - a.hoy; });
  }
  var AMODE = { stop: ['Activo detenido', 'alert'], live: ['En mantención ahora', 'wrench'], att: ['Requiere atención', 'alert'], sched: ['Mantención programada', 'calw'], ok: ['Operando normal', 'check'] };
  var ASTN = { stop: 'detenido por OT', live: 'en mantención', att: 'requiere atención', sched: 'programado hoy', ok: 'sin novedades' };
  function tableroHTML(H) {
    var ab = areas(H), am = function (m) { return ab.filter(function (a) { return a.mode === m; }).length; };
    var tile = function (g) {
      return '<button type="button" class="cp-at3 cp-m-' + g.mode + (U.area && +U.area === +g.id ? ' cp-sel' : '') + '" data-a="opafoc" data-v="' + g.id + '" aria-pressed="' + (U.area && +U.area === +g.id) + '"><span class="cp-at3-h"><span><small>' + esc(String(g.pl || '').replace('Planta ', '')) + '</small><b>' + esc(g.ar) + '</b></span><span class="cp-at3-s">' + (g.mode === 'live' ? '<i class="cp-pulse2"></i>' : ic(AMODE[g.mode][1], 12)) + AMODE[g.mode][0] + '</span></span>' +
        '<span class="cp-adots">' + g.ast.map(function (o) { return '<i class="cp-d-' + o.s + '" title="' + esc(o.a.CODIGO + ' · ' + o.a.NOMBRE + ': ' + ASTN[o.s]) + '"></i>'; }).join('') + '<em>' + pl(g.ast.length, 'activo', 'activos') + '</em></span>' +
        '<span class="cp-at3-m"><span' + (g.hoy ? '' : ' class="cp-z"') + '><b>' + g.hoy + '</b>hoy</span><span class="' + (g.late ? 'cp-r' : 'cp-z') + '"><b>' + g.late + '</b>atrasos</span><span class="' + (g.ot ? '' : 'cp-z') + '"><b>' + g.ot + '</b>OT</span><span class="' + (g.av ? 'cp-a' : 'cp-z') + '"><b>' + g.av + '</b>avisos</span></span></button>';
    };
    return '<section class="cp-card cp-arb"><div class="cp-sc-h"><h3>Estado por área</h3><small>' + pl(ab.length, 'área', 'áreas') + ' · toca una para filtrar todo el tablero</small><div class="cp-r cp-arb-lg">' + [['stop', 'Detenido'], ['live', 'En mantención'], ['att', 'Atención'], ['sched', 'Programado'], ['ok', 'Normal']].map(function (x) { return '<span><i class="cp-d-' + x[0] + '"></i>' + x[1] + (am(x[0]) ? ' <b>' + am(x[0]) + '</b>' : '') + '</span>'; }).join('') + '</div></div>' +
      (U.area ? '<div class="cp-arb-f">' + ic('cog', 14) + 'Mostrando solo el área elegida<button type="button" class="cp-lnk" data-a="opafoc" data-v="0">Ver todas las áreas</button></div>' : '') +
      '<div class="cp-arb-g">' + (ab.map(tile).join('') || '<div class="cp-empty" style="border:0"><b>Sin activos con estos filtros</b></div>') + '</div></section>';
  }
  function tendenciaHTML(H) {
    var t = H.tendencia || [], MES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'], lab = t.map(function (x) { return MES[+String(x.MES).slice(5, 7) - 1]; });
    var fig = function (b, s, svg) { return '<figure><figcaption><b>' + b + '</b><small>' + s + '</small></figcaption>' + svg + '</figure>'; };
    var cum = t.map(function (x) { return x.CUMPLIMIENTO; }), res = t.map(function (x) { return x.RESOLUCION_H == null ? null : Math.round(x.RESOLUCION_H / 24 * 10) / 10; });
    return '<section class="cp-card cp-trd"><div class="cp-sc-h"><h3>Tendencia</h3><small>Pasa el cursor sobre cada punto para ver el valor</small></div><div class="cp-trd-g">' +
      fig('Cumplimiento mensual', '% de lo programado que se hizo', miniChart(cum, lab, { meta: 90, max: 100, u: ' %', aria: 'Cumplimiento de los últimos 6 meses' })) +
      fig('Backlog de OT', 'horas estimadas abiertas, al cierre de cada mes', miniChart(t.map(function (x) { return +x.BACKLOG_H || 0; }), lab, { type: 'bar', u: ' h', aria: 'Backlog de OT abiertas' })) +
      fig('Tiempo de resolución', 'días promedio desde que se crea la OT hasta su cierre', miniChart(res, lab, { u: ' d', aria: 'Tiempo medio de resolución' })) +
      fig('Fallas reportadas', 'avisos de falla por mes', miniChart(t.map(function (x) { return +x.FALLAS || 0; }), lab, { type: 'bar', aria: 'Fallas por mes' })) + '</div></section>';
  }

  /* ---------------------------------------------------------------- pintado */
  function hoyHTML() {
    if (U.error) return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudo cargar Operación</b>' + esc(U.error) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="opreload">Reintentar</button></div>';
    if (!U.hoy) return '<div class="cp-kq-row">' + [1, 2, 3, 4, 5, 6].map(function () { return '<div class="cp-sk" style="height:84px"></div>'; }).join('') + '</div><div class="cp-sk" style="height:360px;margin-top:14px"></div>';
    var H = U.hoy;
    /* una sola mampostería: las tarjetas se acomodan por su alto y no quedan huecos entre ellas */
    return '<div class="cp-mas cp-mas-op" style="margin-top:14px">' + agendaHTML(H) + tableroHTML(H) + atencionHTML(H) + iaHTML(H) + tendenciaHTML(H) + '</div>';
  }
  function pintarKpis() {
    var el = $('#opKpis'); if (!el) return;
    el.innerHTML = U.hoy ? kpis(U.hoy.kpi) : '<div class="cp-kq-row">' + [1, 2, 3, 4, 5, 6].map(function () { return '<div class="cp-sk" style="height:84px"></div>'; }).join('') + '</div>';
  }
  function pintar() {
    pintarKpis();
    var b = $('#opRoot'); if (!b) return;
    var fo = K.grabFocus(b), sy = window.scrollY;
    b.innerHTML = hoyHTML(); K.putFocus(fo, b); window.scrollTo(0, sy);
  }
  function leadTxt() { var p = (CFG.plantas || []).filter(function (x) { return String(x.id) === String(L.planta()); })[0]; return cap(K.fDL(K.TODAY)) + ' · ' + (p ? p.n : 'Todas las plantas') + ' · Qué estaba planificado, qué está pasando, qué está atrasado y qué hay que hacer ahora.'; }
  function cargar() {
    U.error = ''; U.hoy = null; pintar(); if (L.lead) L.lead(leadTxt());
    return api('Hoy', { planta: L.planta(), area: U.area, responsable: U.resp, criticidad: U.crit }).then(function (r) {
      U.hoy = r; pintar(); L.badge('ejecuciones', +r.kpi.ATRASADAS || null); L.heroRefresh();
    }).catch(function (e) { U.error = e.message || 'Error'; pintar(); });
  }
  function cargarFiltros() {
    return api('Filtros', { planta: L.planta() }).then(function (r) { U.filtros = r; L.heroRefresh(); }).catch(function () { U.filtros = { areas: [], personas: [] }; });
  }
  function guardarFiltros() { lsSet({ area: U.area, resp: U.resp, crit: U.crit }); SUB.forEach(function (f) { f(); }); }
  /* lo que comparten las pestañas de Operación */
  window.OpShared = {
    filtros: function () { return { planta: L.planta(), area: U.area, responsable: U.resp, criticidad: U.crit }; },
    suscribir: function (f) { SUB.push(f); },
    datos: function () { return U.hoy; },
    recargar: function () { return cargar(); },
    hero: function () { return heroFiltros(); },
    miniChart: miniChart,
    personas: function () { return (U.filtros && U.filtros.personas) || []; },
    setResponsable: function (id) { U.resp = +id || 0; guardarFiltros(); cargar(); L.heroRefresh(); }
  };

  /* ---------------------------------------------------------------- acciones */
  var A = L.A;
  A.opreload = function () { cargar(); };
  A.opagf = function (d) { U.agf = d.v; pintar(); };
  A.opafoc = function (d) { U.area = +d.v === +U.area ? 0 : +d.v; guardarFiltros(); cargar(); if (U.area) { K.toast('Tablero filtrado por el área elegida.'); window.scrollTo({ top: 0, behavior: 'smooth' }); } };
  A.opfltclr = function () { U.area = 0; U.resp = 0; U.crit = 0; guardarFiltros(); cargar(); };
  A.opgo = function (d) {
    var go = d.go;
    if (go === 'cumplimiento') return L.ir('cumplimiento');
    if (go === 'hoy' || go === 'att') { window.OperacionFiltroEj = go === 'att' ? 'att' : 'hoy'; return L.ir('ejecuciones'); }
    if (go === 'otabiertas' || go === 'otvencidas') { location.href = URL_OT + '#ordenes'; return; }
    if (go === 'riesgo') { var el = document.querySelector('[data-aq=risk]'); if (el) { el.open = true; el.scrollIntoView({ block: 'center', behavior: 'smooth' }); } else K.toast('No hay activos en riesgo con estos filtros.'); }
  };
  A.opot = function (d) { location.href = URL_OT + '#ordenes&ot=' + d.q; };
  A.opav = function () { location.href = URL_AV + '#avisos'; };
  A.opriesgo = function () { };
  /* generar la OT de una ejecución de plan (el mismo servicio de Planificación; nunca en silencio) */
  A.opgen = function (d) {
    K.llamar(WSC, 'GenerarOt', { tokens: d.q }).then(function (r) {
      var x = (r.resultados || [])[0] || {};
      if (x.r === 'ok' || x.r === 'ya') K.toastA((x.r === 'ya' ? 'Ya tenía la ' : '') + 'OT-' + x.ot + (x.r === 'ok' ? ' generada.' : '.'), 'Abrir OT', function () { location.href = x.url || (URL_OT + '#ordenes'); });
      else K.toastError(new Error(x.detalle || 'No se pudo generar la OT.'));
      cargar();
    }).catch(K.toastError);
  };
  /* panel «Generar OTs pendientes» */
  var PP = function (st) {
    var l = (U.hoy && U.hoy.sinOt) || [], n = l.filter(function (x) { return st.sel[x.Q]; }).length;
    return { t: 'Generar OTs pendientes', s: 'Se encontraron ' + pl(l.length, 'ejecución sin OT', 'ejecuciones sin OT'), w: 'w',
      b: st.res ? '<div class="cp-bnr cp-' + (st.res.no ? 'w' : 'ok') + '">' + ic(st.res.no ? 'alert' : 'check', 18) + '<span><b>' + st.res.ok + ' generadas</b>' + (st.res.ya ? ' · ' + st.res.ya + ' ya existían' : '') + (st.res.no ? ' · ' + st.res.no + ' rechazadas' : '') + '</span></div><div class="cp-rows">' + st.res.det.map(function (d) { return '<div class="cp-rw" style="grid-template-columns:minmax(0,1fr) 160px"><span class="cp-s"><b>' + esc(d.t) + '</b><small>' + esc(d.m) + '</small></span><span>' + (d.r === 'no' ? '<span class="cp-tg cp-w">Rechazada</span>' : '<span class="cp-tg cp-c">OT-' + d.ot + '</span>') + '</span></div>'; }).join('') + '</div>'
        : '<div class="cp-bnr cp-i">' + ic('help', 18) + '<span>SIGMA no crea OT en silencio: revisa la lista y confirma. Se respetan las reglas de siempre (no duplica y rechaza con motivo).</span></div><div class="cp-rows">' + l.map(function (x) { return '<label class="cp-rw" style="grid-template-columns:28px minmax(0,1fr) 120px;cursor:pointer"><input type="checkbox" class="cp-cbx" data-pv="pg_' + esc(x.Q) + '"' + (st.sel[x.Q] ? ' checked' : '') + '><span class="cp-s"><b>' + esc(x.ACTIVO) + ' <small>' + esc(x.ACTIVO_CODIGO) + '</small></b><small>' + esc(x.REF) + ' · ' + esc(x.TITULO) + '</small></span><span class="cp-dt"><b>' + K.fD(K.dIso(x.FECHA)) + '</b><small>' + rel(x.FECHA) + '</small></span></label>'; }).join('') + '</div>',
      f: st.res ? '<span></span><span class="cp-r"><button type="button" class="cp-btn cp-pri" data-a="pclose">Listo</button></span>' : '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-sec' + (st.busy ? ' cp-load' : '') + '" data-a="oppendok"' + (n ? '' : ' disabled') + '>' + ic('plus', 15) + 'Generar ' + n + ' ' + (n === 1 ? 'OT' : 'OTs') + '</button></span>' };
  };
  A.oppend = function () {
    var sel = {}; ((U.hoy && U.hoy.sinOt) || []).forEach(function (x) { sel[x.Q] = true; });
    K.Panel.open({ render: PP, st: { sel: sel, busy: false, res: null } });
  };
  A.oppendok = function () {
    var st = K.Panel.state(); if (!st) return;
    var qs = Object.keys(st.sel).filter(function (q) { return st.sel[q]; }); if (!qs.length) return;
    st.busy = true; K.Panel.paint();
    K.llamar(WSC, 'GenerarOt', { tokens: qs.join(',') }).then(function (r) {
      var l = (U.hoy && U.hoy.sinOt) || [], res = { ok: 0, ya: 0, no: 0, det: [] };
      (r.resultados || []).forEach(function (x) { var f = l.filter(function (y) { return y.Q === x.token; })[0] || {}; if (x.r === 'ok') res.ok++; else if (x.r === 'ya') res.ya++; else res.no++; res.det.push({ r: x.r, ot: x.ot, t: (f.ACTIVO_CODIGO || '') + ' · ' + (f.TITULO || ''), m: x.r === 'no' ? x.detalle : 'Generada' }); });
      st.busy = false; st.res = res; K.Panel.paint(); cargar();
    }).catch(function (e) { st.busy = false; K.Panel.paint(); K.toastError(e); });
  };
  document.addEventListener('toggle', function (e) { var t = e.target; if (t.matches && t.matches('details.cp-aq') && t.open) { U.aqo = t.getAttribute('data-aq'); Array.prototype.slice.call(document.querySelectorAll('details.cp-aq[open]')).forEach(function (x) { if (x !== t) x.open = false; }); } }, true);

  L.on({
    pv: function (k, v) { if (k.indexOf('pg_') === 0) { var st = K.Panel.state(); if (st && st.sel) { st.sel[k.slice(3)] = !!v; K.Panel.paint(); } } },
    combo: function (span, v) {
      var n = span.getAttribute('data-cb');
      if (n === 'opArea') { U.area = +v || 0; guardarFiltros(); cargar(); }
      if (n === 'opResp') { U.resp = +v || 0; guardarFiltros(); cargar(); }
      if (n === 'opCrit') { U.crit = +v || 0; guardarFiltros(); cargar(); }
    }
  });

  /* ---------------------------------------------------------------- registro */
  function heroFiltros() {
    var f = U.filtros || { areas: [], personas: [] };
    var hs = function (nombre, etiqueta, lista, sel) { return '<label class="cp-hsel">' + etiqueta + K.combo(nombre, lista, sel, { etiqueta: etiqueta, ph: 'Todas' }) + '</label>'; };
    var n = (U.area ? 1 : 0) + (U.resp ? 1 : 0) + (U.crit ? 1 : 0);
    return hs('opArea', 'Área', [{ id: 0, n: 'Todas' }].concat(f.areas.map(function (a) { return { id: a.ID, n: a.NOMBRE, sub: a.UBICACION || a.PLANTA || '', ini: K.ini(a.NOMBRE) }; })), U.area) +
      hs('opResp', 'Responsable', [{ id: 0, n: 'Todos' }].concat(f.personas.map(function (p) { return { id: p.ID, n: p.NOMBRE, sub: [p.PERFIL, p.ESPECIALIDAD].filter(Boolean).join(' · ') || 'Sin perfil', img: p.FOTO || '', ini: K.ini(p.NOMBRE) }; })), U.resp) +
      hs('opCrit', 'Criticidad', [{ id: 0, n: 'Todas' }].concat(Object.keys(CRIT).map(function (k) { return { id: +k, n: CRIT[k] }; })), U.crit) +
      (n ? '<button type="button" class="cp-btn cp-plain cp-sm" data-a="opfltclr">Quitar ' + n + (n === 1 ? ' filtro' : ' filtros') + '</button>' : '') +
      '<a class="cp-btn cp-pri" href="' + esc(URL_AV + '#avisos&nuevo=1') + '">' + ic('alert', 16) + 'Reportar falla</a>';
  }
  /* los indicadores y los filtros van arriba de TODAS las pestañas */
  document.addEventListener('DOMContentLoaded', function () {
    var panel = document.querySelector('.cp-panel');
    if (panel) panel.classList.add('cp-bare');
    if (panel && !$('#opKpis')) panel.insertAdjacentHTML('beforebegin', '<div id="opKpis" style="margin-bottom:14px"></div>');
    pintarKpis(); cargarFiltros(); cargar();
  });
  L.onPlanta(function () { U.area = 0; guardarFiltros(); cargarFiltros(); cargar(); });
  L.tab('hoy', {
    mount: function (body) { body.innerHTML = '<div id="opRoot"></div>'; pintar(); },
    hero: heroFiltros
  });
})();
