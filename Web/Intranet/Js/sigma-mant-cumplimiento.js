/* =====================================================================
   OPERACIÓN · Cumplimiento · parte d
   Referencia: docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html (Operación › Cumplimiento)
   Mide lo programado del mes (planes, inspecciones y tareas): «hecha» es lo cerrado, o su OT cerrada;
   «vencida» es lo que ya pasó su límite. Datos: SEL_OPERACION_CUMPLIMIENTO (BD/402).
   Cada fila lleva a Ejecuciones con el filtro puesto; por responsable filtra todo Operación.
   ===================================================================== */
(function () {
  var K = window.MantKit, L = window.MantLugar, CFG = K.CFG, OP = window.OpShared;
  if (!OP) return;
  var esc = K.esc, ic = K.ic, pl = K.pl, $ = K.$;
  var api = function (m, d) { return K.llamar(CFG.ws, m, d); };
  var U = { mes: 0, d: null, error: '' };
  var MESES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'], MC = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
  var TIPO = { PLAN: ['Planes', 'calw'], INSPECCION: ['Inspecciones', 'clip'], TAREA: ['Tareas', 'check'] };
  var CRIT = { 1: 'D', 2: 'C', 3: 'B', 4: 'A' };
  var fHM = function (min) { min = Math.round(+min || 0); return min < 60 ? min + ' min' : Math.floor(min / 60) + ' h ' + (min % 60 ? (min % 60) + ' min' : ''); };
  var pct = function (c, v) { return +v ? Math.round(100 * c / v) : null; };

  function primerDia(off) { var h = K.D(K.TODAY), d = new Date(h.getFullYear(), h.getMonth() + off, 1, 12); return K.iso(d); }
  function cargar() {
    U.error = ''; U.d = null; pintar();
    var f = OP.filtros();
    return api('Cumplimiento', { planta: f.planta, area: f.area, responsable: f.responsable, criticidad: f.criticidad, mes: primerDia(U.mes) }).then(function (r) { U.d = r; pintar(); }).catch(function (e) { U.error = e.message || 'Error'; pintar(); });
  }
  var mbar = function (p) { return '<span class="cp-mbar"><i class="' + (p != null && p < 90 ? 'cp-low' : '') + '" style="width:' + (p == null ? 0 : p) + '%"></i></span><b class="cp-tn" style="text-align:right;' + (p != null && p < 90 ? 'color:var(--amber)' : '') + '">' + (p == null ? '—' : p + ' %') + '</b>'; };
  var kq = function (cls, v, l, s, a) { return '<button type="button" class="cp-kq cp-sm ' + cls + '" ' + (a || '') + '><small>' + l + '</small><b class="cp-tn">' + v + '</b><span>' + s + '</span></button>'; };

  function html() {
    if (U.error) return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudo cargar el cumplimiento</b>' + esc(U.error) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="cmreload">Reintentar</button></div>';
    if (!U.d) return '<div class="cp-sk" style="height:56px"></div><div class="cp-sk" style="height:90px;margin-top:12px"></div><div class="cp-sk" style="height:320px;margin-top:12px"></div>';
    var d = U.d, k = d.kpi, md = K.D(primerDia(U.mes)), pc = pct(+k.CUMPLIDAS, +k.VENCIDAS);
    var per = md.getFullYear() + '-' + ('0' + (md.getMonth() + 1)).slice(-2);
    var barra = '<div class="cp-cm-bar"><label class="cp-hsel cp-cm-per">Período<span class="sigma-modal-fecha cp-mes"><input type="text" id="cmPeriodo" data-sgcal-modo="mes" data-valor="' + per + '" value="' + MESES[md.getMonth()] + ' ' + md.getFullYear() + '" aria-label="Período: mes y año" autocomplete="off"><a role="button" tabindex="0" aria-label="Abrir calendario"></a></span></label><span class="cp-sm">' + pl(+k.PLANIFICADO, 'ejecución programada', 'ejecuciones programadas') + (U.mes === 0 ? ' · mes en curso: el % se mide sobre lo que ya venció' : '') + '</span></div>';
    var ef = function (f) { return 'data-a="cmgo" data-f="' + f + '"'; };
    var fila1 = '<div class="cp-kq-row cp-k8">' + kq(pc != null && pc < 90 ? 'cp-w' : 'cp-g', pc == null ? '—' : pc + ' %', 'Cumplimiento', k.CUMPLIDAS + ' de ' + k.VENCIDAS + ' vencidas', ef('att')) + kq('', k.PLANIFICADO, 'Planificado', 'ejecuciones del mes', ef('all')) + kq('cp-g', k.EJECUTADO, 'Ejecutado', 'hechas o con OT cerrada', ef('cer')) +
      kq('', k.PENDIENTE, 'Pendiente', 'aún en plazo', ef('prox')) + kq(+k.ATRASADO ? 'cp-r' : '', k.ATRASADO, 'Atrasado', 'sin hacer y sin OT', ef('att')) + kq('cp-p', k.EN_EJECUCION, 'En ejecución', 'OT en progreso o completadas', ef('curso')) +
      kq('', k.OT_ABIERTAS, 'OT abiertas', 'del mes', 'data-a="cmot"') + kq(+k.OT_VENCIDAS ? 'cp-r' : '', k.OT_VENCIDAS, 'OT vencidas', 'fuera de plazo', 'data-a="cmot"') + '</div>';
    var fila2 = '<div class="cp-kq-row cp-k4b">' + kq('', +k.TIEMPO_PROM ? fHM(k.TIEMPO_PROM) : '—', 'Tiempo promedio', 'por OT cerrada', 'data-a="cmot"') + kq('', +k.DURACION_MIN ? fHM(k.DURACION_MIN) : '—', 'Duración total', 'horas registradas en OT cerradas', 'data-a="cmot"') +
      kq(+k.BACKLOG_MIN / 60 > 60 ? 'cp-w' : '', K.fN(Math.round(+k.BACKLOG_MIN / 60), 0) + ' h', 'Backlog', 'horas estimadas en OT abiertas', 'data-a="cmot"') + kq(+k.AFECTADOS ? 'cp-w' : '', k.AFECTADOS, 'Activos afectados', 'con trabajo atrasado', ef('att')) + '</div>';
    var serie = d.serie || [], lab = serie.map(function (x) { return MC[+String(x.MES).slice(5, 7) - 1]; });
    var porTipo = ['PLAN', 'INSPECCION', 'TAREA'].map(function (t) {
      var x = (d.tipos || []).filter(function (y) { return y.TIPO === t; })[0] || { N: 0, VENCIDAS: 0, CUMPLIDAS: 0 }, p = pct(+x.CUMPLIDAS, +x.VENCIDAS);
      return '<button type="button" class="cp-byk-i" data-a="cmgo" data-k="' + t + '"><span>' + ic(TIPO[t][1], 15) + TIPO[t][0] + '</span>' + mbar(p == null ? 100 : p) + '<small>' + x.CUMPLIDAS + ' de ' + x.VENCIDAS + '</small></button>';
    }).join('');
    var tbl = function (rows, a, nombre, sub) {
      return '<div class="cp-rows">' + (rows.map(function (o) { var p = pct(+o.CUMPLIDAS, +o.VENCIDAS); return '<div class="cp-rw cp-click" style="grid-template-columns:minmax(0,1fr) 110px 48px 64px" ' + a(o) + ' role="button" tabindex="0"><span class="cp-s"><b>' + nombre(o) + '</b><small>' + sub(o) + ' · ' + o.CUMPLIDAS + ' de ' + o.VENCIDAS + ' cumplidas' + (+o.ATRASADAS ? ' · <span style="color:var(--red)">' + o.ATRASADAS + ' atrasadas</span>' : '') + '</small></span>' + mbar(p == null ? 100 : p).replace('</b>', '</b>') + '<span style="text-align:right">' + ic('chev', 15) + '</span></div>'; }).join('') || '<div class="cp-empty">Sin datos en el período.</div>') + '</div>';
    };
    var cuadros = '<div class="cp-mas cp-mas-cm">' +
      '<section class="cp-card"><div class="cp-sc-h" style="margin-bottom:6px"><h3>Cumplimiento por período</h3><small>Últimos 6 meses · línea punteada: meta 90 %</small></div>' + OP.miniChart(serie.map(function (x) { return x.CUMPLIMIENTO; }), lab, { meta: 90, max: 100, u: ' %', aria: 'Cumplimiento mensual', w: 560, h: 190 }) +
      '<div class="cp-sc-h" style="margin:12px 0 6px"><h3>Por tipo de trabajo</h3></div><div class="cp-byk">' + porTipo + '</div></section>' +
      '<section class="cp-card"><div class="cp-sc-h" style="margin-bottom:6px"><h3>Por plan, inspección o tarea</h3><small>Peor primero</small></div>' + tbl(d.fuentes || [], function (o) { return 'data-a="cmgo" data-k="' + o.TIPO + '" data-plan="' + (o.TIPO === 'PLAN' ? esc(o.CLAVE) : '') + '"'; }, function (o) { return esc(o.NOMBRE); }, function (o) { return esc(o.CLAVE); }) + '</section>' +
      '<section class="cp-card"><div class="cp-sc-h" style="margin-bottom:6px"><h3>Por activo</h3><small>Con su criticidad</small></div>' + tbl(d.activos || [], function (o) { return 'data-a="cmgo" data-activo="' + o.ACTIVO_ID + '"'; }, function (o) { return '<span class="cp-crit cp-c-' + (CRIT[o.CRITICIDAD] || 'D') + '">' + (CRIT[o.CRITICIDAD] || 'D') + '</span>' + esc(o.NOMBRE); }, function (o) { return esc(o.CODIGO) + ' · ' + esc(o.AREA || ''); }) + '</section>' +
      '<section class="cp-card"><div class="cp-sc-h" style="margin-bottom:6px"><h3>Por responsable</h3><small>Toca para filtrar Operación por esa persona</small></div><div class="cp-rows">' +
      ((d.responsables || []).map(function (o) { var p = pct(+o.CUMPLIDAS, +o.VENCIDAS); return '<div class="cp-rw cp-click" style="grid-template-columns:30px minmax(0,1fr) 110px 48px" data-a="cmresp" data-v="' + esc(o.RESPONSABLE) + '" role="button" tabindex="0">' + K.avatar(o.RESPONSABLE) + '<span class="cp-s"><b>' + esc(o.RESPONSABLE) + '</b><small>' + o.N + ' programadas' + (+o.ATRASADAS ? ' · <span style="color:var(--red)">' + o.ATRASADAS + ' atrasadas</span>' : '') + '</small></span>' + mbar(p == null ? 100 : p) + '</div>'; }).join('') || '<div class="cp-empty">Sin responsables asignados en el período.</div>') + '</div></section></div>';
    return barra + fila1 + fila2 + cuadros;
  }
  function pintar() { var b = $('#cmRoot'); if (!b) return; var sy = window.scrollY; b.innerHTML = html(); K.conectarFechas(b); window.scrollTo(0, sy); }

  var A = L.A;
  A.cmreload = function () { cargar(); };
  document.addEventListener('change', function (e) {
    var t = e.target; if (!t || t.id !== 'cmPeriodo') return;
    var m = /^(\d{4})-(\d{2})$/.exec(t.getAttribute('data-valor') || ''); if (!m) return;
    var h = K.D(K.TODAY), off = (+m[1] - h.getFullYear()) * 12 + (+m[2] - 1 - h.getMonth());
    if (off !== U.mes) { U.mes = off; cargar(); }
  });
  A.cmot = function () { location.href = CFG.base_ + 'View/Mantenimiento/Ordenes/Ordenes.aspx#ordenes'; };
  A.cmgo = function (d) {
    var m = { PLAN: 'plan', INSPECCION: 'ron', TAREA: 'tar' };
    window.OperacionFiltroEj = { f: d.f || 'all', k: d.k ? m[d.k] || 'all' : 'all', plan: d.plan || '', activo: d.activo || '' };
    L.ir('ejecuciones');
  };
  A.cmresp = function (d) {
    var p = ((OP.personas && OP.personas()) || []).filter(function (x) { return x.NOMBRE === d.v; })[0];
    if (p) { OP.setResponsable(+p.ID); K.toast('Operación filtrada por ' + d.v + '.'); } else K.toast('No encontré a ' + d.v + ' en el catálogo de personas.');
  };
  OP.suscribir(function () { if ($('#cmRoot')) cargar(); });
  L.tab('cumplimiento', {
    mount: function (body) { body.innerHTML = '<div id="cmRoot"></div>'; cargar(); },
    hero: function () { return OP.hero(); }
  });
})();
