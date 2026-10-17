/* =====================================================================
   INDICADORES DE GESTIÓN (EP-18 · HU-180, 181, 182, 183, 185) · BD/474
   Mantenimiento › Indicadores: tablero (cumplimiento, disponibilidad, tiempo medio entre fallas,
   tiempo medio de reparación y órdenes pendientes de cierre) con su variación contra el período anterior,
   detalle de cada indicador en un cajón, y costos por equipo y por centro de costo, siempre por moneda.
   Los filtros (planta, área, equipo y rango de fechas) recalculan todo; Excel e impresión usan los mismos.
   Datos: WsIndicadores → SEL_INDICADORES_TABLERO / _COSTOS / SEL_INDICADOR_DETALLE.
   ===================================================================== */
(function () {
  var K = window.MantKit, L = window.MantLugar, CFG = K.CFG;
  if (!K || !L) return;
  var esc = K.esc, ic = K.ic, $ = K.$, fN = K.fN;
  var api = function (m, d) { return K.llamar(CFG.ws, m, d); };
  var U = { desde: K.addD(K.TODAY, -29), hasta: K.TODAY, area: 0, activo: 0, tab: 'tablero', fil: null, filPl: -1, tb: null, cs: null, err: '', det: null };

  var NOMBRES = { CUMPLIMIENTO: 'Cumplimiento del plan', DISPONIBILIDAD: 'Disponibilidad', MTBF: 'Tiempo medio entre fallas', MTTR: 'Tiempo medio de reparación', PENDIENTES: 'Órdenes pendientes de cierre' };

  var datos = function () { return { planta: L.planta(), area: U.area, activo: U.activo, desde: U.desde, hasta: U.hasta }; };
  var texto = function (v, sufijo, dec) { return v == null ? '—' : fN(v, dec == null ? 1 : dec) + (sufijo || ''); };
  var fHM = function (min) { min = Math.round(+min || 0); return min < 60 ? min + ' min' : Math.floor(min / 60) + ' h' + (min % 60 ? ' ' + (min % 60) + ' min' : ''); };

  /* variación contra el período anterior: «mejor» depende del indicador */
  function delta(act, ant, mejorSube, dec, unidad) {
    if (act == null || ant == null) return '<small class="ix-dl ix-nd">sin período anterior para comparar</small>';
    var d = act - ant, igual = Math.abs(d) < Math.pow(10, -(dec == null ? 1 : dec)) / 2;
    if (igual) return '<small class="ix-dl">igual que el período anterior</small>';
    var bueno = mejorSube ? d > 0 : d < 0;
    return '<small class="ix-dl ' + (bueno ? 'ix-ok' : 'ix-mal') + '">' + (d > 0 ? '▲ +' : '▼ −') + fN(Math.abs(d), dec == null ? 1 : dec) + (unidad || '') + ' vs período anterior</small>';
  }

  /* ------------------------------------------------------------ barra de filtros */
  function nombresPeriodo() { return K.fDY(U.desde) + ' al ' + K.fDY(U.hasta); }
  function barra() {
    var areas = U.fil ? U.fil.areas : [], activos = U.fil ? U.fil.activos.filter(function (a) { return !U.area || +a.AREA === U.area; }) : [];
    var nomA = function (a) { var p = areas.filter(function (x) { return x.ID === a.PADRE; })[0]; return (p ? p.NOMBRE + ' › ' : '') + a.NOMBRE; };
    var pre = function (k, n) { return '<button type="button" class="cp-btn cp-out cp-sm" data-a="ixpre" data-k="' + k + '">' + n + '</button>'; };
    return '<div class="ix-bar" id="ixBar">' +
      '<label class="ix-f">Desde' + K.fecha('ix_desde', U.desde, { etiqueta: 'Desde' }) + '</label>' +
      '<label class="ix-f">Hasta' + K.fecha('ix_hasta', U.hasta, { etiqueta: 'Hasta' }) + '</label>' +
      '<label class="ix-f">Área' + K.combo('ixArea', [{ id: 0, n: 'Todas las áreas' }].concat(areas.map(function (a) { return { id: a.ID, n: nomA(a) }; })), U.area, { etiqueta: 'Área', ph: 'Todas las áreas' }) + '</label>' +
      '<label class="ix-f">Equipo' + K.combo('ixActivo', [{ id: 0, n: 'Todos los equipos' }].concat(activos.map(function (a) { return { id: a.ID, n: a.CODIGO + ' · ' + a.NOMBRE }; })), U.activo, { etiqueta: 'Equipo', ph: 'Todos los equipos' }) + '</label>' +
      '<span class="ix-pre">' + pre('30', '30 días') + pre('90', '90 días') + pre('mes', 'Este mes') + pre('ant', 'Mes anterior') + '</span>' +
      '<span class="ix-acc"><button type="button" class="cp-btn cp-out cp-sm" data-a="ixexcel" data-q="' + U.tab + '">' + ic('upload', 15) + 'Excel</button><button type="button" class="cp-btn cp-out cp-sm" data-a="iximp">Imprimir</button></span></div>';
  }
  function filtrosTexto() {
    var p = CFG.plantas.filter(function (x) { return x.id === L.planta(); })[0], t = [];
    if (p) t.push('Planta: ' + p.n);
    if (U.fil) {
      var a = U.fil.areas.filter(function (x) { return x.ID === U.area; })[0], e = U.fil.activos.filter(function (x) { return x.ID === U.activo; })[0];
      if (a) t.push('Área: ' + a.NOMBRE); if (e) t.push('Equipo: ' + e.CODIGO);
    }
    return t.join(' · ');
  }

  /* ------------------------------------------------------------ tablero */
  function kpi(cod, etiqueta, valor, sub, dl, estado) {
    return '<button type="button" class="cp-kq ix-kpi ' + (estado || '') + '" data-a="ixdet" data-i="' + cod + '"><small>' + etiqueta + '</small><b class="cp-tn">' + valor + '</b><span>' + sub + '</span>' + dl + '<em>Ver el detalle ' + ic('chev', 13) + '</em></button>';
  }
  function tablero() {
    if (U.err) return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudieron cargar los indicadores</b>' + esc(U.err) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="ixrecarga">Reintentar</button></div>';
    if (!U.tb) return '<div class="cp-sk" style="height:150px"></div><div class="cp-sk" style="height:260px;margin-top:12px"></div>';
    var k = U.tb.kpi;
    if (!k) return '<div class="cp-empty">Sin datos para este filtro.</div>';
    var avisoMtbf = k.FALLAS_ACT === 0 ? 'sin fallas en el período' : (k.MTBF_REPRESENTATIVO ? k.FALLAS_ACT + ' fallas' : k.FALLAS_ACT + ' fallas: pocas para que el valor sea representativo');
    var cumpl = k.CUMPL_ACT, disp = k.DISP_ACT;
    var fila = '<div class="cp-kq-row ix-row">' +
      kpi('CUMPLIMIENTO', 'Cumplimiento del plan', texto(cumpl, ' %'), k.CUMPL_HECHAS + ' de ' + k.CUMPL_VENCIDAS + ' vencidas hechas', delta(cumpl, k.CUMPL_ANT, true, 1, ' pts'), cumpl != null && cumpl < 90 ? 'cp-w' : 'cp-g') +
      kpi('DISPONIBILIDAD', 'Disponibilidad', texto(disp, ' %', 2), 'no planificada: ' + fHM(k.DISP_NOPLAN_MIN) + ' · planificada: ' + fHM(k.DISP_PLAN_MIN) + ' (aparte)', delta(disp, k.DISP_ANT, true, 2, ' pts'), disp != null && disp < 95 ? 'cp-w' : 'cp-g') +
      kpi('MTBF', 'Tiempo medio entre fallas', k.MTBF_H_ACT == null ? '—' : fN(k.MTBF_H_ACT, 1) + ' h', avisoMtbf, delta(k.MTBF_H_ACT, k.MTBF_H_ANT, true, 1, ' h'), k.FALLAS_ACT && !k.MTBF_REPRESENTATIVO ? 'cp-w' : '') +
      kpi('MTTR', 'Tiempo medio de reparación', k.MTTR_MIN_ACT == null ? '—' : fHM(k.MTTR_MIN_ACT), k.MTTR_N ? k.MTTR_N + ' correctivas cerradas' : 'sin correctivas cerradas con duración', delta(k.MTTR_MIN_ACT, k.MTTR_MIN_ANT, false, 0, ' min'), '') +
      kpi('PENDIENTES', 'Órdenes pendientes de cierre', k.PEND_ACT, 'terminadas y sin cerrar', delta(k.PEND_ACT, k.PEND_ANT, false, 0, ''), +k.PEND_ACT ? 'cp-w' : 'cp-g') + '</div>';
    var peores = (U.tb.peores || []).map(function (o) {
      var p = +o.VENCIDAS ? Math.round(100 * o.HECHAS / o.VENCIDAS) : null;
      return '<div class="cp-rw" style="grid-template-columns:minmax(0,1fr) 120px 64px"><span class="cp-s"><b>' + esc(o.NOMBRE) + '</b><small>' + esc(o.CODIGO) + ' · ' + o.HECHAS + ' de ' + o.VENCIDAS + ' vencidas hechas</small></span><span class="cp-mbar"><i class="' + (p != null && p < 90 ? 'cp-low' : '') + '" style="width:' + (p == null ? 0 : p) + '%"></i></span><b class="cp-tn" style="text-align:right">' + (p == null ? '—' : p + ' %') + '</b></div>';
    }).join('') || '<div class="cp-empty">Sin trabajo vencido en el período.</div>';
    var nota = '<section class="cp-card"><div class="cp-sc-h"><h3>Cómo se calcula cada indicador</h3></div><ul class="ix-nota">' +
      '<li><b>Cumplimiento:</b> lo hecho sobre lo vencido del plan (planes, inspecciones y tareas), medido contra la fecha original.</li>' +
      '<li><b>Disponibilidad:</b> el tiempo del período menos la indisponibilidad <u>no planificada</u> de los equipos; la planificada se informa aparte.</li>' +
      '<li><b>Tiempo medio entre fallas:</b> tiempo operativo total sobre la cantidad de fallas; con menos de 3 fallas se avisa que no es representativo.</li>' +
      '<li><b>Tiempo medio de reparación:</b> promedio de la duración real de las órdenes correctivas cerradas.</li></ul></section>';
    return fila + '<div class="cp-mas"><section class="cp-card"><div class="cp-sc-h"><h3>Equipos con más trabajo vencido</h3><small>Peor cumplimiento primero · ' + k.ACTIVOS + ' equipos en el filtro</small></div><div class="cp-rows">' + peores + '</div></section>' + nota + '</div>';
  }

  /* ------------------------------------------------------------ costos */
  function totalMoneda(rows, campo) {
    var m = {}; rows.forEach(function (r) { m[r.MONEDA] = (m[r.MONEDA] || 0) + (+r[campo] || 0); }); return m;
  }
  var dinero = function (v, mon) { return fN(v, mon === 'CLP' ? 0 : 2) + ' ' + mon; };
  function costos() {
    if (U.err) return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudieron cargar los costos</b>' + esc(U.err) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="ixrecarga">Reintentar</button></div>';
    if (!U.cs) return '<div class="cp-sk" style="height:110px"></div><div class="cp-sk" style="height:300px;margin-top:12px"></div>';
    var c = U.cs;
    var comp = (c.comparacion || []).map(function (o) {
      var mal = o.VARIACION > 0;
      return '<div class="cp-card ix-cmp"><small class="cp-muted2">Total ' + esc(o.MONEDA) + '</small><b class="cp-tn">' + dinero(o.TOTAL_ACT, o.MONEDA) + '</b><span>período anterior: ' + dinero(o.TOTAL_ANT, o.MONEDA) + '</span>' +
        '<small class="ix-dl ' + (o.VARIACION === 0 || o.VARIACION_PCT == null ? '' : mal ? 'ix-mal' : 'ix-ok') + '">' + (o.VARIACION > 0 ? '▲ +' : o.VARIACION < 0 ? '▼ −' : '') + dinero(Math.abs(o.VARIACION), o.MONEDA) + (o.VARIACION_PCT == null ? ' · sin base de comparación' : ' (' + (o.VARIACION_PCT > 0 ? '+' : '') + fN(o.VARIACION_PCT, 1) + ' %)') + '</small>' +
        '<em>repuestos ' + dinero(o.REP_ACT, o.MONEDA) + ' · mano de obra ' + dinero(o.MO_ACT, o.MONEDA) + ' · servicios ' + dinero(o.SRV_ACT, o.MONEDA) + '</em></div>';
    }).join('') || '<div class="cp-empty" style="grid-column:1/-1">No hay costos registrados en el período ni en el anterior.</div>';
    var fila = function (cols, celdas) { return '<div class="cp-rw" style="grid-template-columns:' + cols + '">' + celdas.join('') + '</div>'; };
    var eq = (c.equipos || []).map(function (o) {
      return fila('minmax(0,1fr) 54px repeat(4,minmax(80px,110px))', ['<span class="cp-s"><b>' + esc(o.ACTIVO) + '</b><small>' + esc(o.CODIGO) + ' · ' + o.ORDENES + ' ' + (o.ORDENES === 1 ? 'orden' : 'órdenes') + '</small></span>', '<span>' + esc(o.MONEDA) + '</span>',
        '<span class="cp-tn">' + fN(o.REPUESTOS, 2) + '</span>', '<span class="cp-tn">' + fN(o.MANO_OBRA, 2) + '</span>', '<span class="cp-tn">' + fN(o.SERVICIOS, 2) + '</span>', '<b class="cp-tn">' + fN(o.TOTAL, 2) + '</b>']);
    }).join('') || '<div class="cp-empty">Sin costos por equipo en el período.</div>';
    var cc = (c.centros || []).map(function (o) {
      return fila('minmax(0,1fr) 54px repeat(3,minmax(80px,110px))', ['<span class="cp-s"><b>' + esc(o.CENTRO) + '</b><small>' + esc(o.CODIGO) + (o.PADRE_CODIGO ? ' · depende de ' + esc(o.PADRE_CODIGO) : '') + '</small></span>', '<span>' + esc(o.MONEDA) + '</span>',
        '<span class="cp-tn">' + fN(o.PROPIO, 2) + '</span>', '<span class="cp-tn">' + fN(o.DEPENDIENTES, 2) + '</span>', '<b class="cp-tn">' + fN(o.TOTAL, 2) + '</b>']);
    }).join('') || '<div class="cp-empty">Sin costos por centro de costo: las órdenes del período no tienen centro de costo asignado.</div>';
    var cab = function (cols, h) { return '<div class="cp-rw cp-h" style="grid-template-columns:' + cols + '">' + h.map(function (x) { return '<span>' + x + '</span>'; }).join('') + '</div>'; };
    return '<div class="ix-cmps">' + comp + '</div><p class="cp-muted2" style="margin:6px 4px">Los montos de cada moneda se muestran por separado: SIGMA nunca suma UF con pesos ni con dólares.</p>' +
      '<div class="cp-mas"><section class="cp-card"><div class="cp-sc-h"><h3>Por equipo</h3><small>Repuestos consumidos · mano de obra · servicios de terceros</small></div><div class="cp-rows">' +
      cab('minmax(0,1fr) 54px repeat(4,minmax(80px,110px))', ['Equipo', 'Mon.', 'Repuestos', 'Mano obra', 'Servicios', 'Total']) + eq + '</div></section>' +
      '<section class="cp-card"><div class="cp-sc-h"><h3>Por centro de costo</h3><small>Cada centro incluye el costo de sus centros dependientes</small></div><div class="cp-rows">' +
      cab('minmax(0,1fr) 54px repeat(3,minmax(80px,110px))', ['Centro de costo', 'Mon.', 'Propio', 'Dependientes', 'Total']) + cc + '</div></section></div>';
  }

  /* ------------------------------------------------------------ detalle (cajón) */
  function cajon(st) {
    var nombre = NOMBRES[st.ind] || st.ind, d = st.datos;
    var cuerpo;
    if (st.err) cuerpo = '<div class="cp-empty"><b>No se pudo cargar</b>' + esc(st.err) + '</div>';
    else if (!d) cuerpo = '<div class="cp-sk" style="height:200px"></div>';
    else {
      var url = d.urlOt;
      var ot = function (f) { return f.OT_ID && f.QOT ? '<a class="cp-btn cp-out cp-sm" href="' + esc(url) + '#ordenes&ot=' + f.QOT + '">OT ' + f.OT_NUMERO + '</a>' : ''; };
      var cols = '86px minmax(0,1fr) 120px 90px';
      var filas = d.filas.map(function (f) {
        var cuando = f.FECHA ? K.fDN(f.FECHA) + (f.FIN ? ' → ' + K.fDN(f.FIN) : '') : '';
        var extra = f.MINUTOS != null ? fHM(f.MINUTOS) : f.DIAS_ESPERA != null ? f.DIAS_ESPERA + ' d en espera' : '';
        return '<div class="cp-rw" style="grid-template-columns:' + cols + '"><span class="cp-tn">' + cuando + '</span><span class="cp-s"><b>' + esc((f.ACTIVO || '') ) + '</b><small>' + esc(f.CODIGO || '') + (f.DETALLE ? ' · ' + esc(f.DETALLE) : '') + '</small></span><span>' + esc(f.RESULTADO || '') + (extra ? '<br><small class="cp-muted2">' + extra + '</small>' : '') + '</span><span>' + ot(f) + '</span></div>';
      }).join('') || '<div class="cp-empty">Ningún registro compone este indicador en el período.</div>';
      var xe = '';
      if (d.porEquipo && d.porEquipo.length) {
        xe = '<section class="cp-card"><div class="cp-sc-h"><h3>Por equipo</h3><small>Fallas y tiempo operativo</small></div><div class="cp-rows">' + d.porEquipo.map(function (o) {
          var mtbf = o.FALLAS ? fN(o.MIN_OPERATIVOS / 60 / o.FALLAS, 1) + ' h' : '—';
          return '<div class="cp-rw" style="grid-template-columns:minmax(0,1fr) 70px 110px 100px"><span class="cp-s"><b>' + esc(o.ACTIVO) + '</b><small>' + esc(o.CODIGO) + '</small></span><span>' + o.FALLAS + ' fallas</span><span>no plan.: ' + fHM(o.MIN_NO_PLAN) + '</span><span class="cp-tn">TMEF ' + mtbf + '</span></div>';
        }).join('') + '</div></section>';
      }
      cuerpo = '<p class="cp-muted2" style="margin:0 0 8px">' + nombresPeriodo() + (filtrosTexto() ? ' · ' + esc(filtrosTexto()) : '') + ' · ' + d.filas.length + ' registros</p>' +
        '<section class="cp-card"><div class="cp-rows">' + filas + '</div></section>' + xe;
    }
    return { t: nombre, s: 'Detalle del indicador', w: 'wide', b: cuerpo, f: '<button type="button" class="cp-btn cp-out" data-a="ixexcel" data-q="detalle" data-i="' + st.ind + '">' + ic('upload', 15) + 'Excel</button><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button>' };
  }

  /* ------------------------------------------------------------ carga */
  function repintar() { var b = $('#ixRoot'); if (!b) return; var cont = $('#ixCont'); if (cont) cont.innerHTML = U.tab === 'costos' ? costos() : tablero(); }
  function pintarTodo() {
    var b = $('#ixRoot'); if (!b) return;
    var sy = window.scrollY;
    b.innerHTML = barra() + '<div id="ixCont">' + (U.tab === 'costos' ? costos() : tablero()) + '</div>';
    K.conectarFechas(b); window.scrollTo(0, sy);
  }
  function cargarFiltros() {
    if (U.filPl === L.planta()) return Promise.resolve();
    return api('Filtros', { planta: L.planta() }).then(function (r) { U.fil = r; U.filPl = L.planta(); if (U.area && !r.areas.some(function (a) { return a.ID === U.area; })) U.area = 0; if (U.activo && !r.activos.some(function (a) { return a.ID === U.activo; })) U.activo = 0; });
  }
  function cargar() {
    U.err = ''; if (U.tab === 'costos') U.cs = null; else U.tb = null;
    pintarTodo();
    var q = cargarFiltros().then(function () { pintarTodo(); return api(U.tab === 'costos' ? 'Costos' : 'Tablero', datos()); });
    return q.then(function (r) { if (U.tab === 'costos') U.cs = r; else U.tb = r; repintar(); }).catch(function (e) { U.err = e.message || 'Error'; repintar(); });
  }

  /* ------------------------------------------------------------ acciones */
  var A = L.A;
  A.ixrecarga = function () { cargar(); };
  A.ixpre = function (d) {
    var h = K.D(K.TODAY), y = h.getFullYear(), m = h.getMonth();
    if (d.k === '30') { U.desde = K.addD(K.TODAY, -29); U.hasta = K.TODAY; }
    else if (d.k === '90') { U.desde = K.addD(K.TODAY, -89); U.hasta = K.TODAY; }
    else if (d.k === 'mes') { U.desde = K.iso(new Date(y, m, 1, 12)); U.hasta = K.TODAY; }
    else { U.desde = K.iso(new Date(y, m - 1, 1, 12)); U.hasta = K.iso(new Date(y, m, 0, 12)); }
    cargar();
  };
  A.ixdet = function (d) {
    var st = { ind: d.i, datos: null, err: '' };
    K.Panel.open({ render: cajon, st: st });
    api('Detalle', Object.assign({ indicador: d.i }, datos())).then(function (r) { st.datos = r; if (K.Panel.state() === st) K.Panel.paint(); })
      .catch(function (e) { st.err = e.message || 'Error'; if (K.Panel.state() === st) K.Panel.paint(); });
  };
  A.ixexcel = function (d, el) {
    var q = d.q || U.tab;
    if (el) el.disabled = true;
    api('Exportar', Object.assign({ que: q, indicador: d.i || '', filtros: filtrosTexto() }, datos())).then(function (r) {
      var bin = atob(r.base64), arr = new Uint8Array(bin.length); for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
      var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([arr], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' })); a.download = r.nombre; document.body.appendChild(a); a.click();
      setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500);
      K.toast('Excel descargado con los mismos filtros de la pantalla.');
    }).catch(K.toastError).then(function () { if (el) el.disabled = false; });
  };
  A.iximp = function () {
    var e = $('#ixPie'); if (e) e.remove();
    var pie = document.createElement('div'); pie.id = 'ixPie'; pie.className = 'ix-pie';
    pie.innerHTML = '<b>' + esc(CFG.cliente_nombre || 'SIGMA') + '</b> · Indicadores de mantenimiento · ' + nombresPeriodo() + (filtrosTexto() ? ' · ' + esc(filtrosTexto()) : '');
    $('#cpRoot').insertBefore(pie, $('#cpRoot').firstChild);
    window.print();
  };

  L.on({
    fecha: function (el) {
      var k = el.getAttribute('data-fe'), v = K.deDN(el.value);
      if (!v || (k !== 'ix_desde' && k !== 'ix_hasta')) return;
      if (k === 'ix_desde') { U.desde = v; if (U.hasta < v) U.hasta = v; } else { U.hasta = v; if (U.desde > v) U.desde = v; }
      cargar();
    },
    combo: function (span, v) {
      var n = span.getAttribute('data-cb');
      if (n === 'ixArea') { U.area = +v || 0; U.activo = 0; cargar(); }
      else if (n === 'ixActivo') { U.activo = +v || 0; cargar(); }
    }
  });

  /* ------------------------------------------------------------ pestañas */
  function montar(tab) {
    return function (body) { U.tab = tab; body.innerHTML = '<div id="ixRoot"></div>'; cargar(); };
  }
  L.tab('tablero', { mount: montar('tablero'), planta: function () { U.filPl = -1; U.area = 0; U.activo = 0; cargar(); } });
  L.tab('costos', { mount: montar('costos'), planta: function () { U.filPl = -1; U.area = 0; U.activo = 0; cargar(); } });
})();
