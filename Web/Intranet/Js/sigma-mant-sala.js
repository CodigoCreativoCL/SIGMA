/* =====================================================================
   OPERACIÓN · Sala de control · parte d
   Referencia: docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html (Operación › Sala de control)
   El tablero oscuro del día: franja de 21 días, indicadores, áreas con mantención (planes, inspecciones, tareas y OT)
   y el programa por ubicación a 14 días. Datos: SEL_OPERACION_MONITOREO (BD/403), con los filtros de Operación.
   El CSS (cp-mon…) es el del Centro de Planificación; la lógica se tomó de su antiguo Monitoreo.
   ===================================================================== */
(function () {
  var K = window.MantKit, L = window.MantLugar, CFG = K.CFG, OP = window.OpShared;
  if (!OP) return;
  var esc = K.esc, ic = K.ic, pl = K.pl, $ = K.$, D = K.D, addD = K.addD, wday = K.wday, fD = K.fD, fDL = K.fDL, rel = K.rel, fH = K.fH, dIso = K.dIso, hIso = K.hIso, TODAY = K.TODAY;
  var api = function (m, d) { return K.llamar(CFG.ws, m, d); };
  var pad = function (n) { return (n < 10 ? '0' : '') + n; };
  var DIAC = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  var chL = function (n) { return ic('chev', n).replace('<svg ', '<svg style="transform:rotate(180deg)" '); };
  var short = function (n) { var p = String(n || '').trim().split(/\s+/); return p.length > 1 ? p[0] + ' ' + p[1].charAt(0) + '.' : p[0] || ''; };
  var plantaTxt = function () { var p = (CFG.plantas || []).filter(function (x) { return String(x.id) === String(L.planta()); })[0]; return p ? p.n : ''; };
  var U = { md: TODAY, mc: {}, mf: '' };
  var MON = { filas: null, rango: '', cargando: false, areas: [], error: '' };
  var KD = { PLAN: ['k-plan', 'Plan'], INSPECCION: ['k-ron', 'Inspección'], TAREA: ['k-tar', 'Tarea'], OT: ['k-otx', 'OT'] };
  var URL_OT = CFG.base_ + 'View/Mantenimiento/Ordenes/Ordenes.aspx';
  var kd = function (x) { var t = KD[x.tipo] || KD.PLAN; return '<span class="cp-kd cp-' + t[0] + '">' + t[1] + '</span> '; };

var hmin = function (h) { var a = String(h || '08:00').split(':').map(Number); return (a[0] || 0) * 60 + (a[1] || 0); };
var addH = function (h, min) { var m = hmin(h) + Math.round(+min || 0); return pad(Math.floor(m / 60) % 24) + ':' + pad(m % 60); };
var weekMon = function (s) { return addD(s, -(wday(s) - 1)); };
var capF = function (s) { return String(s || '').replace(/^./, function (c) { return c.toUpperCase(); }); };
var fechaDe = function (v) { return dIso(v); };

function normMon(r) {
  var d = dIso(r.FECHA), hora = hIso(r.FECHA) || '08:00';
  return { proj: false, tipo: r.TIPO, d: d, hora: hora, dur: +r.DURACION || 0, parada: !!r.PARADA, ref: r.REF, hitoN: r.TITULO, eq: r.ACTIVO_ID, eqCod: r.ACTIVO_CODIGO, eqN: r.ACTIVO,
    pl: r.PLANTA_ID, plN: r.PLANTA || 'Sin planta', ar: r.AREA_ID || 0, arN: r.AREA || 'Sin área', comp: r.COMPONENTE || '', resp: r.RESPONSABLE || '', sit: r.SITUACION, estado: r.ESTADO_ID,
    ot: r.OT_ID || 0, otNum: r.OT_NUMERO, otEst: r.OT_ESTADO, key: r.KEY, qot: r.QOT };
}
function monItems() { return MON.filas || []; }
function sitM(x) {
  if (x.sit === 'CERRADA') return 'cer';
  if (x.ot) return 'ot';
  return { VENCIDA: 'venc', ATRASADA: 'atr', DISPONIBLE: 'disp' }[x.sit] || 'fut';
}
function nowLive(x) {
  if (x.d !== TODAY || x.proj || sitM(x) === 'cer') return false;
  if (x.ot && x.otEst === 2) return true;
  var n = new Date(), m = n.getHours() * 60 + n.getMinutes(), s = hmin(x.hora);
  return m >= s && m < s + Math.max(30, x.dur);
}
var OTX = { 1: 'Por iniciar', 2: 'En ejecución', 3: 'Completada', 4: 'Cerrada' };
function xState(x) {
  if (nowLive(x)) return ['live', 'En curso'];
  var s = sitM(x);
  if (s === 'venc') return ['venc', 'Vencida']; if (s === 'atr') return ['atr', 'Atrasada']; if (s === 'cer') return ['cer', 'Cerrada'];
  if (s === 'ot') return ['ot', OTX[x.otEst] || 'Con OT'];
  if (s === 'disp') return ['disp', 'Sin OT'];
  return ['fut', 'Programada'];
}
var RANK = { venc: 0, atr: 1, live: 2, disp: 3, ot: 4, fut: 5, pj: 6, cer: 7 };
var attn = function (x) { return !x.proj && (sitM(x) === 'venc' || sitM(x) === 'atr'); };
var AREA_MODE = { live: ['En mantención ahora', 'gauge'], stop: ['Activo detenido por mantención', 'alert'], att: ['Requiere atención', 'alert'], sched: ['Mantención programada', 'calw'], done: ['Mantención terminada', 'check'] };
var MORD = ['live', 'stop', 'att', 'sched', 'done'];

function monAreas(items) {
  var m = {};
  items.forEach(function (x) { var k = x.pl + '|' + x.ar; (m[k] = m[k] || { k: k, pl: x.pl, plN: x.plN, ar: x.ar, arN: x.arN, xs: [] }).xs.push(x); });
  return Object.keys(m).map(function (k) {
    var g = m[k], st = g.xs.map(xState), att = g.xs.some(attn), stop = g.xs.some(function (x) { return x.parada && xState(x)[0] !== 'cer'; });
    var live = st.some(function (s) { return s[0] === 'live'; }), done = st.every(function (s) { return s[0] === 'cer'; });
    g.mode = done ? 'done' : live ? 'live' : stop ? 'stop' : att ? 'att' : 'sched';
    g.eqs = Object.keys(g.xs.reduce(function (o, x) { o[x.eq] = 1; return o; }, {}));
    g.min = g.xs.reduce(function (t, x) { return t + x.dur; }, 0);
    return g;
  }).sort(function (a, b) { return MORD.indexOf(a.mode) - MORD.indexOf(b.mode) || b.xs.length - a.xs.length; });
}

/* ---- carga ---- */
function monRango() { var s0 = addD(weekMon(U.md), -7); return [s0, addD(s0, 20)]; }
function monCargar(forzar) {
  var r = monRango(), f = OP.filtros(), key = [r[0], r[1], f.planta, f.area, f.responsable, f.criticidad].join('|');
  if (!forzar && MON.rango === key && MON.filas) return Promise.resolve();
  MON.cargando = true;
  return api('Monitoreo', { planta: f.planta, area: f.area, responsable: f.responsable, criticidad: f.criticidad, desde: r[0], hasta: r[1] }).then(function (x) {
    MON.filas = x.filas.map(normMon); MON.areas = x.areas; MON.rango = key; MON.cargando = false; pintar();
  }).catch(function (e) { MON.cargando = false; MON.error = e.message; K.toastError(e); pintar(); });
}
var monTimer = null;
function monReloj() {
  clearInterval(monTimer);
  monTimer = setInterval(function () {
    var el = document.getElementById('cpMonClock'); if (!el) { clearInterval(monTimer); return; }
    var n = new Date(); el.textContent = pad(n.getHours()) + ':' + pad(n.getMinutes());
  }, 30000);
}

/* ---- vista ---- */
function monHTML() {
  if (!MON.filas) { if (!MON.cargando && !MON.error) monCargar(); return '<div class="cp-card" style="padding:18px"><div class="cp-sk" style="height:34px;width:40%"></div><div class="cp-sk" style="height:120px;margin-top:12px"></div></div>'; }
  var items = monItems(), d = U.md, isT = d === TODAY;
  var r = monRango(), strip = []; for (var k = 0; k < 21; k++) strip.push(addD(r[0], k));
  var perDay = {}; items.forEach(function (x) { (perDay[x.d] = perDay[x.d] || []).push(x); });
  var maxH = Math.max(1, Math.max.apply(null, strip.map(function (s) { return (perDay[s] || []).reduce(function (t, x) { return t + x.dur; }, 0); })));
  var dayItems = (perDay[d] || []).slice().sort(function (a, b) { return hmin(a.hora) - hmin(b.hora); });
  var areas = monAreas(dayItems);
  var allAreas = (MON.areas || []).map(function (a) { return { k: a.PLANTA_ID + '|' + a.AREA_ID, n: a.AREA, pl: a.PLANTA }; });
  var quiet = allAreas.filter(function (a) { return !areas.some(function (g) { return g.k === a.k; }); });
  var nEq = Object.keys(dayItems.reduce(function (o, x) { o[x.eq] = 1; return o; }, {})).length;
  var nStop = Object.keys(dayItems.filter(function (x) { return x.parada; }).reduce(function (o, x) { o[x.eq] = 1; return o; }, {})).length;
  var nAtt = dayItems.filter(attn).length, mins = dayItems.reduce(function (t, x) { return t + x.dur; }, 0);
  var now = new Date(), clock = pad(now.getHours()) + ':' + pad(now.getMinutes());
  var kpi = function (v, l, cls) { return '<div class="cp-mk ' + (cls || '') + '"><b>' + v + '</b><span>' + l + '</span></div>'; };
  var tile = function (g) {
    var lab = AREA_MODE[g.mode], byEq = {};
    g.xs.forEach(function (x) { (byEq[x.eq] = byEq[x.eq] || []).push(x); });
    var rows = Object.keys(byEq).map(function (k2) { return byEq[k2]; }).sort(function (a, b) { return Math.min.apply(null, a.map(function (x) { return RANK[xState(x)[0]]; })) - Math.min.apply(null, b.map(function (x) { return RANK[xState(x)[0]]; })); });
    return '<article class="cp-at cp-m-' + g.mode + '"><header><div><span class="cp-at-pl">' + esc(g.plN) + '</span><h4>' + esc(g.arN) + '</h4></div><span class="cp-at-st">' + (g.mode === 'live' ? '<i class="cp-pulse"></i>' : ic(lab[1], 13)) + lab[0] + '</span></header>' +
      '<div class="cp-at-m"><span>' + pl(g.eqs.length, 'activo', 'activos') + '</span><span>' + pl(g.xs.length, 'trabajo', 'trabajos') + '</span><span>' + fH(g.min) + '</span></div><ul>' +
      rows.slice(0, 4).map(function (xs) {
        var top = xs.slice().sort(function (p, q) { return RANK[xState(p)[0]] - RANK[xState(q)[0]]; })[0], s = xState(top);
        return '<li><button type="button" data-a="monopen" data-k="' + esc(top.key) + '"><span class="cp-at-a"><b>' + esc(top.eqN) + '</b><small>' + esc(top.eqCod) + (top.comp ? ' <span class="cp-cmp">› ' + esc(top.comp) + '</span>' : '') + '</small></span>' +
          '<span class="cp-at-w"><b>' + esc(top.hitoN) + (xs.length > 1 ? ' <em>+' + (xs.length - 1) + '</em>' : '') + '</b><small>' + top.hora + '–' + addH(top.hora, top.dur) + (top.parada ? ' · <span class="cp-pz">parada</span>' : '') + (top.resp ? ' · ' + esc(short(top.resp)) : '') + '</small></span>' +
          '<span class="cp-xst cp-s-' + s[0] + '">' + (s[0] === 'live' ? '<i class="cp-pulse"></i>' : '<i></i>') + s[1] + '</span></button></li>';
      }).join('') + '</ul>' + (rows.length > 4 ? '<button type="button" class="cp-at-more" data-a="mfoc" data-v="' + esc(g.k) + '">Ver ' + (rows.length - 4) + ' activos más en el programa</button>' : '') + '</article>';
  };
  var strp = strip.map(function (s) {
    var xs = perDay[s] || [], h = xs.reduce(function (t, x) { return t + x.dur; }, 0), bad = xs.some(attn);
    return '<button type="button" class="cp-sd' + (s === d ? ' cp-on' : '') + (s === TODAY ? ' cp-tdy' : '') + (wday(s) > 5 ? ' cp-we' : '') + (s < TODAY ? ' cp-past' : '') + '" data-a="mday" data-v="' + s + '" aria-pressed="' + (s === d) + '" aria-label="' + fDL(s) + ': ' + pl(xs.length, 'trabajo', 'trabajos') + '"><span class="cp-w">' + DIAC[wday(s)] + '</span><span class="cp-n">' + D(s).getDate() + '</span><span class="cp-b"><i style="height:' + (h ? Math.max(12, h / maxH * 100) : 0) + '%"' + (bad ? ' class="cp-r"' : '') + '></i></span><span class="cp-c">' + (xs.length || '') + '</span></button>';
  }).join('');
  monReloj();
  return '<section class="cp-mon" aria-label="Monitoreo de mantenimiento"><div class="cp-mon-top"><div class="cp-mon-t"><span class="cp-ey"><i class="cp-pulse"></i>Sala de control · mantenimiento</span><h2>' + (isT ? 'Hoy, ' : '') + fDL(d) + '</h2><p>' + (isT ? 'Son las <b id="cpMonClock">' + clock + '</b> · ' : capF(rel(d)) + ' · ') + esc(plantaTxt() || 'Todas las plantas') + '</p></div>' +
    '<div class="cp-mon-ctl"><button type="button" class="cp-mbtn" data-a="mstep" data-v="-1" aria-label="Día anterior">' + chL(16) + '</button>' + (isT ? '' : '<button type="button" class="cp-mbtn cp-txt" data-a="mday" data-v="' + TODAY + '">Ir a hoy</button>') + '<button type="button" class="cp-mbtn" data-a="mstep" data-v="1" aria-label="Día siguiente">' + ic('chev', 16) + '</button>' +
    '</div></div>' +
    '<div class="cp-mon-strip" role="group" aria-label="Elegir día">' + strp + '</div>' +
    '<div class="cp-mon-k">' + kpi(areas.length + '<small>/' + allAreas.length + '</small>', 'áreas con mantención', areas.some(function (a) { return a.mode === 'live'; }) ? 'cp-k-live' : '') + kpi(nEq, 'activos intervenidos') + kpi(nStop, 'con parada de activo', nStop ? 'cp-k-stop' : '') + kpi(fH(mins), 'horas de trabajo') + kpi(nAtt, 'requieren atención', nAtt ? 'cp-k-att' : '') + '</div>' +
    (areas.length ? '<div class="cp-mon-g">' + areas.map(tile).join('') + '</div>' : '<div class="cp-mon-e">' + ic('check', 26) + '<b>' + (isT ? 'Hoy' : capF(fDL(d))) + ' no hay mantención programada</b><span>Todas las áreas operan con normalidad. Elige otro día en la barra de arriba.</span></div>') +
    (quiet.length ? '<div class="cp-mon-q"><span>' + ic('check', 14) + 'Operando sin mantención</span>' + quiet.map(function (a) { return '<em>' + esc(a.n) + (!L.planta() && (CFG.plantas || []).length > 1 ? ' <small>· ' + esc(a.pl) + '</small>' : '') + '</em>'; }).join('') + '</div>' : '') + '</section>' + progHTML(items);
}

/* ---- programa por ubicación: planta › área › activo › componente ---- */
function progHTML(items) {
  var d0 = weekMon(U.md), days = []; for (var k = 0; k < 14; k++) days.push(addD(d0, k));
  var win = items.filter(function (x) { return x.d >= days[0] && x.d <= days[13]; });
  var cellCls = function (xs) { var st = xs.map(function (x) { return xState(x)[0]; }).sort(function (a, b) { return RANK[a] - RANK[b]; })[0]; return 'cp-s-' + st + (xs.some(function (x) { return x.parada; }) ? ' cp-s-pz' : ''); };
  var cells = function (getXs, lvl) {
    return days.map(function (dd) {
      var xs = getXs(dd), cls = (dd === TODAY ? ' cp-tdy' : '') + (dd === U.md ? ' cp-sel' : '') + (wday(dd) > 5 ? ' cp-we' : '');
      if (!xs.length) return '<span class="cp-pc' + cls + '"></span>';
      var tip = fDL(dd) + '\n' + Object.keys(xs.reduce(function (o, x) { o[(lvl === 'eq' ? '' : x.eqCod + ' · ') + x.hitoN] = 1; return o; }, {})).join('\n');
      return '<button type="button" class="cp-pc' + cls + '" data-a="mday" data-v="' + dd + '" title="' + esc(tip) + '"><span class="cp-mb cp-' + lvl + ' ' + cellCls(xs) + '">' + (lvl === 'eq' ? (xs.length > 1 ? xs.length : '') : xs.length) + '</span></button>';
    }).join('');
  };
  var plantas = {}; win.forEach(function (x) { (plantas[x.pl] = plantas[x.pl] || { n: x.plN, xs: [] }).xs.push(x); });
  var rows = '';
  Object.keys(plantas).forEach(function (pk) {
    var P0 = plantas[pk], key = 'p:' + pk, open = !U.mc[key], pEq = Object.keys(P0.xs.reduce(function (o, x) { o[x.eq] = 1; return o; }, {}));
    rows += '<div class="cp-gr cp-lv0"><button type="button" class="cp-gr-h" data-a="mtog" data-v="' + key + '" aria-expanded="' + open + '">' + ic(open ? 'chevd' : 'chev', 14) + ic('cog', 15) + '<b>' + esc(P0.n) + '</b><small>' + pl(pEq.length, 'activo', 'activos') + '</small></button>' + cells(function (dd) { return P0.xs.filter(function (x) { return x.d === dd; }); }, 'pl') + '</div>';
    if (!open) return;
    var ars = {}; P0.xs.forEach(function (x) { (ars[x.ar] = ars[x.ar] || { n: x.arN, xs: [] }).xs.push(x); });
    Object.keys(ars).sort(function (a, b) { return ars[a].n.localeCompare(ars[b].n); }).forEach(function (ak) {
      var A0 = ars[ak], k2 = 'a:' + pk + '|' + ak, aOpen = !U.mc[k2], eqs = {};
      A0.xs.forEach(function (x) { (eqs[x.eq] = eqs[x.eq] || { n: x.eqN, cod: x.eqCod, xs: [], comps: {} }).xs.push(x); if (x.comp) eqs[x.eq].comps[x.comp] = 1; });
      rows += '<div class="cp-gr cp-lv1' + (U.mf === pk + '|' + ak ? ' cp-foc' : '') + '" id="cpAr' + pk + '_' + ak + '"><button type="button" class="cp-gr-h" data-a="mtog" data-v="' + k2 + '" aria-expanded="' + aOpen + '">' + ic(aOpen ? 'chevd' : 'chev', 14) + '<b>' + esc(A0.n) + '</b><small>' + pl(Object.keys(eqs).length, 'activo', 'activos') + '</small></button>' + cells(function (dd) { return A0.xs.filter(function (x) { return x.d === dd; }); }, 'ar') + '</div>';
      if (!aOpen) return;
      Object.keys(eqs).sort(function (a, b) { return eqs[a].cod.localeCompare(eqs[b].cod); }).forEach(function (ek) {
        var E0 = eqs[ek], comps = Object.keys(E0.comps);
        rows += '<div class="cp-gr cp-lv2"><div class="cp-gr-h" title="' + esc(E0.n) + '"><span class="cp-eqn"><b>' + esc(E0.n) + '</b><small>' + esc(E0.cod) + (comps.length ? ' › ' + esc(comps.join(', ')) : '') + '</small></span></div>' + cells(function (dd) { return E0.xs.filter(function (x) { return x.d === dd; }); }, 'eq') + '</div>';
      });
    });
  });
  return '<section class="cp-card cp-prog" aria-label="Programa por ubicación"><div class="cp-prog-h"><div><h3>Programa por ubicación</h3><p>Planta › área › activo › componente · ' + fD(days[0]) + ' al ' + fD(days[13]) + '</p></div>' +
    '<div class="cp-prog-n"><button type="button" class="cp-ibx" data-a="mweek" data-v="-14" aria-label="Dos semanas antes">' + chL(16) + '</button><button type="button" class="cp-ibx" data-a="mweek" data-v="14" aria-label="Dos semanas después">' + ic('chev', 16) + '</button></div>' +
    '<div class="cp-prog-lg"><span><i class="cp-mb cp-eq cp-s-fut"></i>Programada</span><span><i class="cp-mb cp-eq cp-s-ot"></i>Con OT</span><span><i class="cp-mb cp-eq cp-s-venc"></i>Vencida o atrasada</span><span><i class="cp-mb cp-eq cp-s-fut cp-s-pz"></i>Con parada</span><span><i class="cp-mb cp-eq cp-s-pj"></i>Proyección</span></div></div>' +
    '<div class="cp-prog-s"><div class="cp-prog-t"><div class="cp-gr cp-hd"><span class="cp-gr-h"></span>' + days.map(function (dd) { return '<span class="cp-pc cp-hd' + (dd === TODAY ? ' cp-tdy' : '') + (dd === U.md ? ' cp-sel' : '') + (wday(dd) > 5 ? ' cp-we' : '') + '"><small>' + DIAC[wday(dd)] + '</small><b>' + D(dd).getDate() + '</b>' + (dd === TODAY ? '<em>Hoy</em>' : '') + '</span>'; }).join('') + '</div>' +
    (rows || '<div class="cp-mon-e cp-light">' + ic('calw', 22) + '<b>Sin trabajo en estas dos semanas</b></div>') + '</div></div></section>';
}

function pintar() {
  var el = $('#saRoot'); if (!el) return;
  var sy = window.scrollY;
  el.innerHTML = MON.error ? '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudo cargar la sala de control</b>' + esc(MON.error) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="monreload">Reintentar</button></div>' : monHTML();
  window.scrollTo(0, sy);
}
var A = L.A;
A.monreload = function () { MON.error = ''; monCargar(true); };
A.mday = function (d) { U.md = d.v; var r = monRango(); if (d.v < r[0] || d.v > r[1]) { MON.filas = null; } pintar(); if (!MON.filas) monCargar(true); };
A.mstep = function (d) { A.mday({ v: addD(U.md, +d.v) }); };
A.mweek = function (d) { A.mday({ v: addD(U.md, +d.v) }); };
A.mtog = function (d) { if (U.mc[d.v]) delete U.mc[d.v]; else U.mc[d.v] = 1; pintar(); };
A.mfoc = function (d) { U.mf = d.v; var ps = d.v.split('|'); delete U.mc['p:' + ps[0]]; delete U.mc['a:' + d.v]; pintar(); var el = document.getElementById('cpAr' + ps[0] + '_' + ps[1]); if (el) el.scrollIntoView({ block: 'center', behavior: 'smooth' }); };
A.monopen = function (d) {
  var x = (MON.filas || []).filter(function (y) { return y.key === d.k; })[0]; if (!x) return;
  if (x.ot && x.qot) { location.href = URL_OT + '#ordenes&ot=' + x.qot; return; }
  window.OperacionFiltroEj = { f: 'all', activo: x.eq }; L.ir('ejecuciones');
};
OP.suscribir(function () { if ($('#saRoot')) { MON.filas = null; monCargar(true); } });
L.tab('monitoreo', {
  mount: function (body) { body.innerHTML = '<div id="saRoot"></div>'; MON.error = ''; pintar(); },
  hero: function () { return OP.hero(); }
});
})();
