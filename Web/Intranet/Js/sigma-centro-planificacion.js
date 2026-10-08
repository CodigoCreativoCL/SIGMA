/* ============================================================================
   SIGMA · CENTRO DE PLANIFICACIÓN (08-10-2026)

   Referencia visual: docs/rediseno-planificacion/sigma-centro-planificacion-referencia.html
   Alcance (manda siempre): MD/CENTRO_PLANIFICACION_ALCANCE.md

   CÓMO ESTÁ ARMADO
     Una sola página que se pinta en el navegador. Las lecturas y escrituras
     van a WsCentroPlanificacion.asmx (planes) y los KPI, ejecuciones,
     cumplimiento y cobertura a WsPlanificacion360.asmx. Nada hace postback.

     U es el estado de la pantalla (pestaña, filtros, plan abierto, lo que
     está desplegado) y F la ficha del plan abierto tal como la devolvió el
     servidor. Cada escritura guarda en el servidor y, cuando el servidor
     abrió un borrador o cambió ids (recargar = true), se vuelve a pedir la
     ficha. render() repinta conservando el foco, lo escrito y el scroll.

   LO QUE NO SE INVENTA EN EL NAVEGADOR
     Las fechas (FNC_PROGRAMACION_FECHAS vía SEL_PLAN_HITO_PROYECCION), el
     impacto de activar (SEL_PLAN_IMPACTO) y las ejecuciones las calcula la
     base. La pantalla solo valida lo obvio junto al campo para no mandar
     algo que el SP va a rechazar.

   CONVENCIONES DEL SITIO
     Clases con cp- y todo bajo .cp-root; combos con SigmaCombo; fechas con
     el calendario SIGMA (.sigma-modal-fecha + SigmaCalendario.conectar);
     todo <button> con type="button"; el texto dice «activo», nunca «equipo».
   ========================================================================= */
(function () {
'use strict';

var CFG = window.CentroPlanificacionConfig || {};
var $ = function (s, r) { return (r || document).querySelector(s); };
var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
var nrm = function (s) { return String(s == null ? '' : s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); };
var pl = function (n, s, p) { return n + ' ' + (n === 1 ? s : p); };

/* ------------------------------------------------------------ íconos */
var P = {
  search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
  calw: '<rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/><path d="M9 15.5l2 2 4-4"/>',
  chev: '<path d="M9 6l6 6-6 6"/>', chevl: '<path d="M15 6l-6 6 6 6"/>', chevd: '<path d="M6 9l6 6 6-6"/>',
  plus: '<path d="M12 5v14M5 12h14"/>', arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  pencil: '<path d="M4 20h4L19 9l-4-4L4 16z"/>', check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>', x: '<path d="M6 6l12 12M18 6L6 18"/>',
  dots: '<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>',
  box: '<path d="M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8"/>',
  shield: '<path d="M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6z"/>',
  gauge: '<path d="M4 17a8 8 0 1 1 16 0"/><path d="M12 17l4-5"/>',
  clip: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3h6v1M9 12l2 2 4-4"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  trend: '<path d="M4 17l6-6 4 4 6-7"/><path d="M15 8h5v5"/>',
  wrench: '<path d="M14.5 6.5a4 4 0 0 0-5.3 5.3L4 17l3 3 5.2-5.2a4 4 0 0 0 5.3-5.3l-2.5 2.5-2.5-.5-.5-2.5z"/>',
  cog: '<circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.6M12 18.6v2.6M2.8 12h2.6M18.6 12h2.6M5.5 5.5l1.8 1.8M16.7 16.7l1.8 1.8M5.5 18.5l1.8-1.8M16.7 7.3l1.8-1.8"/>',
  alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.5"/>',
  help: '<circle cx="12" cy="12" r="8.5"/><path d="M9.6 9.5a2.5 2.5 0 0 1 4.8 1c0 1.7-2.4 2-2.4 3.5M12 17v.4"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  upload: '<path d="M12 15V4M7 9l5-5 5 5M4 15v5h16v-5"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3"/>'
};
var ic = function (k, n) { n = n || 18; return '<svg class="cp-ic" style="width:' + n + 'px;height:' + n + 'px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (P[k] || '') + '</svg>'; };

/* ------------------------------------------------------------ fechas (siempre «AAAA-MM-DD», hora local de la planta) */
var pad = function (n) { return (n < 10 ? '0' : '') + n; };
var iso = function (d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); };
var D = function (s) { var p = String(s).slice(0, 10).split('-').map(Number); return new Date(p[0], p[1] - 1, p[2], 12); };
var TODAY = CFG.hoy || iso(new Date());
var addD = function (s, n) { var d = D(s); d.setDate(d.getDate() + n); return iso(d); };
var diffD = function (a, b) { return Math.round((D(b) - D(a)) / 864e5); };
var wday = function (s) { var w = D(s).getDay(); return w === 0 ? 7 : w; };
var MES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
var MESC = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
var DIA = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
var DIAC = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
var dIso = function (s) { return s ? String(s).slice(0, 10) : ''; };
var hIso = function (s) { return s && String(s).length >= 16 ? String(s).slice(11, 16) : ''; };
var fD = function (s) { var d = D(s); return DIAC[wday(s)] + ' ' + d.getDate() + ' ' + MESC[d.getMonth()]; };
var fDY = function (s) { var d = D(s); return d.getDate() + ' ' + MESC[d.getMonth()] + ' ' + d.getFullYear(); };
var fDL = function (s) { var d = D(s); return DIA[wday(s)] + ' ' + d.getDate() + ' de ' + MES[d.getMonth()]; };
var fDN = function (s) { if (!s) return '—'; var d = D(s); return pad(d.getDate()) + '-' + pad(d.getMonth() + 1) + '-' + d.getFullYear(); };
var deDN = function (t) { var m = /^(\d{1,2})-(\d{1,2})-(\d{4})$/.exec(String(t || '').trim()); return m ? m[3] + '-' + pad(+m[2]) + '-' + pad(+m[1]) : ''; };
var rel = function (s) { var n = diffD(TODAY, s); return n === 0 ? 'hoy' : n === 1 ? 'mañana' : n === -1 ? 'ayer' : n > 0 ? 'en ' + n + ' días' : 'hace ' + (-n) + ' días'; };
var fN = function (n, d) { return Number(n || 0).toLocaleString('es-CL', { minimumFractionDigits: d || 0, maximumFractionDigits: d || 0 }); };
var fH = function (min) { var h = (+min || 0) / 60; return fN(h, h % 1 ? (Math.round(h * 100) % 10 ? 2 : 1) : 0) + ' h'; };
var hrs = function (min) { var h = (+min || 0) / 60; return Math.round(h * 100) / 100; };

/* ------------------------------------------------------------ servidor */
function llamar(base, metodo, datos) {
  return fetch(base + metodo, {
    method: 'POST', credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify(datos || {})
  }).then(function (r) {
    if (!r.ok) throw new Error(r.status === 500 ? 'El servidor no pudo completar la acción.' : 'No se pudo conectar con el servidor.');
    return r.json();
  }).then(function (j) {
    var x = typeof j.d === 'string' ? JSON.parse(j.d) : j.d;
    if (x && x.error) { var e = new Error(x.detalle || 'No se pudo completar.'); e.sesion = !!x.sesion; throw e; }
    return x;
  });
}
var api = function (m, d) { return llamar(CFG.ws, m, d); };
var p360 = function (seccion, extra) {
  var mes = U.periodo, ini = mes + '-01', fin = iso(new Date(+mes.slice(0, 4), +mes.slice(5, 7), 0, 12));
  var d = { seccion: seccion, planta: U.planta, desde: ini, hasta: fin, pagina: 1, filtro: '', soloParada: false, situacion: '', plan: 0, equipo: 0, tipo: 0, area: 0, criticidad: 0, vista: '' };
  Object.keys(extra || {}).forEach(function (k) { d[k] = extra[k]; });
  return llamar(CFG.p360, 'Cargar', d).then(function (r) { return r.datos; });
};

/* ------------------------------------------------------------ estado */
var EST = { BORRADOR: ['draft', 'Borrador'], ACTIVO: ['active', 'Activo'], CAMBIOS: ['changes', 'Activo · cambios sin aplicar'], INACTIVO: ['inactive', 'Inactivo'] };
var TABS = [['planes', 'Planes'], ['ejecuciones', 'Ejecuciones'], ['cumplimiento', 'Cumplimiento'], ['cobertura', 'Cobertura'], ['biblioteca', 'Biblioteca']];
var U = {
  tab: 'planes', planta: 0, periodo: CFG.periodo, plan: null, pf: 'all', q: '', multi: {},
  lista: null, conteos: null, permisos: {}, cat: null, kpis: null,
  oi: {}, oa: {}, vp: {}, fq: {}, pend: {}, otf: 'open', flash: {}, saved: { s: 'ok' }, cargando: false, fichaCargando: false,
  ex: {}, cob: {}, lib: {}
};
var F = null;   // ficha del plan abierto
var PN = null, MD = null, POP = null, UNDO = null;

var catN = function (lista, id) { var x = (U.cat && U.cat[lista] || []).filter(function (r) { return String(r.ID) === String(id); })[0]; return x ? x.NOMBRE : ''; };
var catL = function (lista) { return (U.cat && U.cat[lista] || []).map(function (r) { return { id: r.ID, n: r.NOMBRE }; }); };
var plantaN = function (id) { var p = (CFG.plantas || []).filter(function (x) { return x.id === +id; })[0]; return p ? p.n : ''; };
var estado = function (p) { return EST[p.ESTADO] || EST.BORRADOR; };
var stChip = function (p) { var e = estado(p); return '<span class="cp-st cp-' + e[0] + '"><i></i>' + e[1] + '</span>'; };
var mc = function (cls, txt, ico) { return '<div class="cp-msg ' + (cls ? 'cp-' + cls : '') + '">' + ic(ico || (cls === 'i' ? 'help' : 'alert'), 13) + '<span>' + txt + '</span></div>'; };
var editable = function () { return F && U.permisos.editar && F.plan.ESTADO !== 'INACTIVO'; };
var ini = function (n) { return String(n || '').split(' ').filter(Boolean).map(function (w) { return w[0]; }).slice(0, 2).join('').toUpperCase(); };
var AVC = [['#E6F0FE', '#1675F2'], ['#FFF4E6', '#B65C00'], ['#EFEBFE', '#5A30F2'], ['#DFF8F8', '#007F8A'], ['#FDECEA', '#C7352B'], ['#E7F5EE', '#16855B']];
var avatar = function (n) { if (!n) return ''; var h = 0; for (var i = 0; i < n.length; i++) h = (h * 31 + n.charCodeAt(i)) >>> 0; var c = AVC[h % AVC.length]; return '<span class="cp-av" style="background:' + c[0] + ';color:' + c[1] + '" title="' + esc(n) + '">' + esc(ini(n)) + '</span>'; };

/* ------------------------------------------------------------ combos y fechas del sitio */
var combo = function (nombre, lista, sel, o) {
  o = o || {};
  if (!window.SigmaCombo) return '';
  var h = window.SigmaCombo.html(nombre, lista, sel == null ? '' : sel, { ph: o.ph || 'Elige una opción', clave: o.clave || nombre, etiqueta: o.etiqueta, id: o.id, vacio: o.vacio, crear: !!o.crear });
  h = h.replace('<span class="sg-combo">', '<span class="sg-combo' + (o.err ? ' cp-err' : '') + '" data-cb="' + esc(nombre) + '"' + (o.data || '') + '>');
  if (o.dis) h = h.replace('<input type="text"', '<input type="text" readonly tabindex="-1"');
  return h;
};
var fecha = function (bind, val, o) {
  o = o || {};
  return '<span class="sigma-modal-fecha cp-fecha' + (o.err ? ' cp-err' : '') + '"><input type="text" data-fe="' + esc(bind) + '" value="' + (val ? fDN(val) : '') + '" placeholder="' + esc(o.ph || 'dd-mm-aaaa') + '" autocomplete="off" inputmode="numeric"' + (o.dis ? ' disabled' : '') + ' aria-label="' + esc(o.etiqueta || 'Fecha') + '">' + (o.dis ? '' : '<a role="button" tabindex="0" aria-label="Abrir calendario"></a>') + '</span>';
};
function conectarFechas(raiz) { if (window.SigmaCalendario && SigmaCalendario.conectar) SigmaCalendario.conectar(raiz); }

/* ------------------------------------------------------------ guardado y avisos */
function guardando() { U.saved = { s: 'ing' }; pintarGuardado(); }
function guardado() { U.saved = { s: 'ok' }; pintarGuardado(); }
function noGuardado(m) { U.saved = { s: 'bad', m: m }; pintarGuardado(); }
function pintarGuardado() {
  var el = $('#cpSaved'); if (!el) return;
  var s = U.saved;
  el.className = 'cp-saved' + (s.s === 'ing' ? ' cp-ing' : s.s === 'bad' ? ' cp-bad' : '');
  el.innerHTML = s.s === 'ing' ? ic('clock', 14) + 'Guardando…' : s.s === 'bad' ? ic('alert', 14) + 'No se pudo guardar: ' + esc(s.m) : ic('check', 14) + 'Guardado';
}
function toast(msg, deshacer) {
  var t = document.createElement('div'); t.className = 'cp-toast'; t.setAttribute('role', 'status');
  t.innerHTML = ic('check', 18) + '<span>' + esc(msg) + '</span>' + (deshacer ? '<button type="button" class="cp-undo" data-a="undo">Deshacer</button>' : '');
  if (deshacer) UNDO = { fn: deshacer, el: t };
  $('#cpToasts').appendChild(t);
  setTimeout(function () { t.remove(); if (UNDO && UNDO.el === t) UNDO = null; }, deshacer ? 7000 : 4200);
}
function toastError(e) {
  var m = e && e.message ? e.message : String(e || 'No se pudo completar.');
  if (e && e.sesion) { m = 'La sesión expiró. Vuelve a entrar.'; }
  var t = document.createElement('div'); t.className = 'cp-toast'; t.setAttribute('role', 'alert');
  t.innerHTML = ic('alert', 18) + '<span>' + esc(m) + '</span>';
  t.querySelector('.cp-ic').style.color = '#FF9B93';
  $('#cpToasts').appendChild(t); setTimeout(function () { t.remove(); }, 6000);
}

/* =====================================================================
   Frecuencia: del dato del servidor a un borrador editable y su texto
   ===================================================================== */
var REP = { DIARIA: 'd', SEMANAL: 'w', MENSUAL: 'm', ANUAL: 'y' };
var REPC = { d: 'DIARIA', w: 'SEMANAL', m: 'MENSUAL', y: 'ANUAL' };
var TIPOF = { CALENDARIO: 'cal', 'INTERVALO TIEMPO': 'int', 'FECHA UNICA': 'fec', MEDIDOR: 'med', CONDICION: 'cond' };
var TIPOFC = { cal: 'CALENDARIO', int: 'INTERVALO TIEMPO', fec: 'FECHA UNICA', med: 'MEDIDOR', cond: 'CONDICION' };
var UNI = { MINUTO: ['minuto', 'minutos'], HORA: ['hora', 'horas'], DIA: ['día', 'días'], SEMANA: ['semana', 'semanas'], MES: ['mes', 'meses'], ANIO: ['año', 'años'] };
var uniCod = function (id) { var u = (U.cat && U.cat.unidades || []).filter(function (x) { return x.ID === +id; })[0]; return u ? u.CODIGO : ''; };
var uniId = function (cod) { var u = (U.cat && U.cat.unidades || []).filter(function (x) { return x.CODIGO === cod; })[0]; return u ? u.ID : 0; };
var frecId = function (rep) { var u = (U.cat && U.cat.frecuencias || []).filter(function (x) { return x.CODIGO === REPC[rep]; })[0]; return u ? u.ID : 0; };

function fqDe(h) {
  var t = TIPOF[h.TIPO_CODIGO] || null;
  var f = { t: t, rep: 'm', n: 1, days: [], mmode: 'day', md: +dIso(TODAY).slice(8, 10), ord: 1, wd: 1, month: 1, hour: '08:00',
    iu: uniId('MES'), anchor: TODAY, dates: [], mn: 500, mstart: 0, mwarn: 0, ctext: '',
    from: dIso(h.VIGENCIA_DESDE) || TODAY, to: dIso(h.VIGENCIA_HASTA), tb: Math.round((+h.TOL_ANTES || 0) / 1440), ta: Math.round((+h.TOL_DESPUES || 0) / 1440), excl: [] };
  var c = h.CALENDARIO;
  if (c) {
    f.rep = REP[c.FRECUENCIA] || 'm'; f.n = +c.INTERVALO || 1; f.hour = c.HORA || '08:00';
    f.days = String(c.DIAS || '').split(',').filter(Boolean).map(Number).sort();
    if (c.ORDINAL != null) { f.mmode = 'ord'; f.ord = +c.ORDINAL; f.wd = f.days[0] || 1; } else { f.mmode = 'day'; f.md = +c.DIA_MES || f.md; }
    f.month = +c.MES || 1;
  }
  var i = h.INTERVALO;
  if (i) { f.n = +i.CANTIDAD || 1; f.iu = +i.UNIDAD_ID || f.iu; f.anchor = dIso(i.ANCLA) || TODAY; f.hour = hIso(i.ANCLA) || f.hour; }
  if (t === 'fec') f.dates = (h.FECHAS_PUNTUALES || []).map(function (x) { return { fecha: dIso(x.FECHA), hora: x.HORA ? String(x.HORA).slice(0, 5) : '' }; });
  var m = h.MEDIDOR;
  if (m) { f.mn = +m.CADA || 500; f.mstart = +m.VALOR_INICIAL || 0; f.mwarn = +m.AVISO || 0; }
  f.ctext = (h.CONDICIONES || []).map(function (x) { return x.TEXTO; }).join(' y ');
  f.excl = (h.EXCLUSIONES || []).map(function (x) { return { a: dIso(x.DESDE), b: dIso(x.HASTA), why: x.MOTIVO || '', shift: !!x.DESPLAZA }; });
  return f;
}
function fqDe2(h) { return U.fq[h.CODIGO] || fqDe(h); }
function datosDe(f) {
  var d = { tipo: TIPOFC[f.t], desde: f.from || TODAY, hasta: f.to || '', tolAntes: (+f.tb || 0) * 1440, tolDespues: (+f.ta || 0) * 1440,
    exclusiones: (f.excl || []).map(function (x) { return { desde: x.a, hasta: x.b, motivo: x.why, desplaza: !!x.shift }; }) };
  if (f.t === 'cal') {
    var c = { frecuencia: frecId(f.rep), intervalo: Math.max(1, +f.n || 1), hora: f.hour || '08:00', dias: [] };
    if (f.rep === 'w') c.dias = f.days.slice();
    if (f.rep === 'm' || f.rep === 'y') { if (f.mmode === 'ord') { c.ordinal = +f.ord; c.dias = [+f.wd]; } else c.diaMes = +f.md; }
    if (f.rep === 'y') c.mes = +f.month;
    d.calendario = c;
  }
  if (f.t === 'int') d.intervalo = { cantidad: Math.max(1, +f.n || 1), unidad: +f.iu, ancla: (f.anchor || TODAY) + 'T' + (f.hour || '08:00') };
  if (f.t === 'fec') d.fechas = f.dates.map(function (x) { return { fecha: x.fecha, hora: x.hora || f.hour || '' }; });
  if (f.t === 'med') d.medidor = { cada: +f.mn, inicial: +f.mstart || 0, aviso: +f.mwarn || 0 };
  return d;
}
/* Lo que el SP rechazaría: se muestra junto al campo y no se manda. */
function fqError(f) {
  if (!f || !f.t) return 'Esta intervención necesita una frecuencia para poder activarse.';
  if (f.t === 'cal' && f.rep === 'w' && !f.days.length) return 'Elige al menos un día de la semana.';
  if ((f.t === 'cal' || f.t === 'int') && !(+f.n >= 1)) return 'Indica cada cuánto (1 o más).';
  if (f.t === 'fec' && !f.dates.length) return 'Agrega al menos una fecha.';
  if (f.t === 'med' && !(+f.mn > 0)) return 'Indica cada cuántas unidades del medidor.';
  if (f.to && f.from && f.to < f.from) return 'La fecha «Hasta» debe ser posterior a «Vigente desde».';
  return '';
}
function freqText(f, corto, unidadMed) {
  if (!f || !f.t) return '';
  var dd = function (n) { return n + ' ' + (+n === 1 ? 'día' : 'días'); };
  var tol = !(+f.tb) && !(+f.ta) ? '' : +f.tb === +f.ta ? ' · tolerancia ±' + dd(f.tb) : !(+f.tb) ? ' · tolerancia +' + dd(f.ta) : !(+f.ta) ? ' · tolerancia −' + dd(f.tb) : ' · tolerancia −' + f.tb + '/+' + dd(f.ta);
  var s = '', n = +f.n || 1;
  if (f.t === 'cal') {
    if (f.rep === 'd') s = n === 1 ? 'Cada día' : 'Cada ' + n + ' días';
    if (f.rep === 'w') { var ds = f.days.slice().sort().map(function (x) { return DIA[x]; }); var dl = ds.length > 1 ? ds.slice(0, -1).join(', ') + ' y ' + ds[ds.length - 1] : ds[0] || '—'; s = (n === 1 ? 'Cada semana, ' : 'Cada ' + n + ' semanas, ') + 'el ' + dl; }
    var o = { 1: 'primer', 2: 'segundo', 3: 'tercer', 4: 'cuarto', '-1': 'último' }[f.ord];
    if (f.rep === 'm') s = (n === 1 ? 'Cada mes' : 'Cada ' + n + ' meses') + (f.mmode === 'ord' ? ', el ' + o + ' ' + DIA[f.wd] : ', el día ' + f.md);
    if (f.rep === 'y') s = (n === 1 ? 'Cada año' : 'Cada ' + n + ' años') + (f.mmode === 'ord' ? ', el ' + o + ' ' + DIA[f.wd] + ' de ' + MES[f.month - 1] : ', el ' + f.md + ' de ' + MES[f.month - 1]);
    s += f.hour ? ' a las ' + f.hour : '';
  }
  if (f.t === 'int') { var u = UNI[uniCod(f.iu)] || ['', '']; s = 'Cada ' + n + ' ' + (n === 1 ? u[0] : u[1]) + ' desde el ' + fDY(f.anchor); }
  if (f.t === 'fec') { var fs = f.dates.map(function (x) { return x.fecha; }).sort(); s = fs.length ? 'En fechas puntuales: ' + fs.slice(0, 2).map(fDY).join(', ') + (fs.length > 2 ? ' y ' + (fs.length - 2) + ' más' : '') : 'Fechas puntuales (sin fechas)'; }
  if (f.t === 'med') s = 'Cada ' + fN(f.mn) + ' ' + (unidadMed || 'unidades') + ' del medidor';
  if (f.t === 'cond') s = f.ctext ? 'Cuando ' + f.ctext : 'Por condición';
  return corto || f.t === 'med' || f.t === 'cond' ? s : s + tol;
}
var unidadMedidor = function () { var a = (F && F.activos || []).filter(function (x) { return x.MEDIDOR_UNIDAD; })[0]; return a ? a.MEDIDOR_UNIDAD : ''; };

/* =====================================================================
   Cáscara: cabecera, KPI y pestañas
   ===================================================================== */
function heroAcciones() {
  var plantas = CFG.plantas || [];
  var pla = plantas.length === 1
    ? '<span class="cp-hsel">Planta <b>' + esc(plantas[0].n) + '</b></span>'
    : '<label class="cp-hsel">Planta' + combo('cpPlanta', [{ id: 0, n: 'Todas las plantas' }].concat(plantas), U.planta, { etiqueta: 'Planta', ph: 'Todas las plantas' }) + '</label>';
  var mesTxt = function (v) { var m = /^(\d{4})-(\d{2})$/.exec(v || ''); return m ? MES[+m[2] - 1].charAt(0).toUpperCase() + MES[+m[2] - 1].slice(1) + ' ' + m[1] : ''; };
  var per = '<label class="cp-hsel">Período<span class="sigma-modal-fecha cp-mes"><input type="text" id="cpPeriodo" data-sgcal-modo="mes" data-valor="' + esc(U.periodo) + '" value="' + esc(mesTxt(U.periodo)) + '" aria-label="Período: mes y año" autocomplete="off"><a role="button" tabindex="0" aria-label="Elegir mes y año"></a></span></label>';
  var ed = U.permisos.editar;
  return pla + per +
    '<button type="button" class="cp-hbtn cp-teal" data-a="bulkload"' + (ed ? '' : ' disabled title="No tienes permiso para crear planes"') + '>' + ic('upload', 17) + 'Carga masiva</button>' +
    '<button type="button" class="cp-hbtn cp-pri" data-a="newplan"' + (ed ? '' : ' disabled title="No tienes permiso para crear planes"') + ' aria-haspopup="dialog">' + ic('plus', 17) + 'Nuevo plan</button>';
}
function kpisHTML() {
  var k = U.kpis || {};
  var v = function (x) { return x == null ? '—' : x; };
  var kp = function (go, fondo, color, icono, etq, valor, nota, titulo) {
    return '<button type="button" class="cp-kpi" data-a="kpi" data-go="' + go + '" title="' + titulo + '"><span class="cp-kpi-ico" style="--kb:' + fondo + ';--kc:' + color + '">' + ic(icono, 22) + '</span><span><small>' + etq + '</small><strong>' + valor + '</strong><em>' + nota + '</em></span><span class="cp-go">' + ic('chev', 16) + '</span></button>';
  };
  var urg = k.urgente;
  return kp('att', urg ? '#FDECEA' : '#FFF4E6', urg ? '#C7352B' : '#B65C00', 'alert', 'Requieren atención', v(urg), urg ? pl(k.vencidas || 0, 'vencida', 'vencidas') + ' · ' + pl(k.atrasadas || 0, 'atrasada', 'atrasadas') : 'Vencidas y atrasadas', 'Ver en Ejecuciones') +
    kp('disp', '#E8FBFB', '#007F8A', 'clock', 'Disponibles', v(k.disponibles), 'Se pueden generar hoy', 'Ver en Ejecuciones') +
    kp('cum', '#EAF4FF', '#087BEA', 'trend', 'Cumplimiento del año', k.cumplimiento == null ? '—' : k.cumplimiento + ' %', esc(k.cumplimientoPie || 'Enero a hoy'), 'Ver Cumplimiento') +
    kp('week', '#F2EFFF', '#6732F4', 'calw', 'Carga próximas 4 semanas', k.carga == null ? '—' : fN(k.carga) + ' h', esc(k.cargaPie || ''), 'Ver la semana en Ejecuciones');
}
function tabsHTML() {
  var c = U.conteos || {}, att = (U.kpis || {}).urgente || 0, sin = U.cob.sinPlan;
  var n = { planes: c.todos, ejecuciones: att, cobertura: sin };
  return TABS.map(function (t) {
    var k = t[0], v = n[k];
    return '<button type="button" role="tab" id="cpTab-' + k + '" aria-selected="' + (U.tab === k) + '" tabindex="' + (U.tab === k ? 0 : -1) + '" data-a="tab" data-t="' + k + '">' + t[1] +
      (v != null ? '<b class="' + (k === 'ejecuciones' && v ? 'cp-r' : '') + '">' + v + '</b>' : '') + '</button>';
  }).join('');
}
function pintarCascara() {
  $('#cpTituloPlanta').textContent = U.planta ? ' · ' + plantaN(U.planta) : '';
  var acc = $('#cpHeroAcc'); if (!acc.dataset.ok) { acc.innerHTML = heroAcciones(); acc.dataset.ok = '1'; conectarFechas(acc); }
  $('#cpKpis').innerHTML = kpisHTML();
  $('#cpTabs').innerHTML = tabsHTML();
}

/* =====================================================================
   PLANES · lista
   ===================================================================== */
var CHIPS = [['all', 'Todos', 'todos'], ['active', 'Activos', 'activos'], ['draft', 'Borradores', 'borradores'], ['changes', 'Con cambios', 'cambios'], ['inactive', 'Inactivos', 'inactivos'], ['att', 'Requieren atención', 'atencion']];
function planMatch(p) {
  if (U.q) { var q = nrm(U.q); if (nrm([p.NOMBRE, p.CODIGO, p.PROXIMA_ACTIVO, p.ACTIVOS_TXT, p.INTERVENCIONES_TXT, p.RESPONSABLE].join(' ')).indexOf(q) < 0) return false; }
  var e = estado(p)[0];
  if (U.pf === 'all') return true;
  if (U.pf === 'att') return (+p.VENCIDAS || 0) + (+p.ATRASADAS || 0) > 0;
  if (U.pf === 'active') return e === 'active' || e === 'changes';
  return e === U.pf;
}
function listHTML() {
  var c = U.conteos || {}, nm = Object.keys(U.multi).length;
  return '<aside class="cp-plist' + (nm ? ' cp-multi' : '') + '" aria-label="Planes">' +
    '<div class="cp-plist-h"><label class="cp-srch2">' + ic('search', 15) + '<input id="cpQ" value="' + esc(U.q) + '" placeholder="Plan, código, activo o intervención" aria-label="Buscar planes" autocomplete="off"></label>' +
    '<div class="cp-chips" role="group" aria-label="Filtrar planes">' + CHIPS.map(function (x) { return '<button type="button" class="cp-fc" data-a="pf" data-v="' + x[0] + '" aria-pressed="' + (U.pf === x[0]) + '">' + (x[0] === 'att' ? '<i style="background:var(--red)"></i>' : '') + x[1] + '<b>' + (c[x[2]] || 0) + '</b></button>'; }).join('') + '</div></div>' +
    '<div class="cp-plist-b" id="cpPlb">' + listBody() + '</div>' +
    (nm ? '<div class="cp-plist-bulk"><span>' + pl(nm, 'seleccionado', 'seleccionados') + '</span><span style="flex:1"></span><button type="button" class="cp-btn cp-out cp-xs" data-a="bulkdup"' + (nm > 1 ? ' disabled title="Duplicar funciona de a un plan"' : '') + '>Duplicar</button><button type="button" class="cp-btn cp-out cp-xs" data-a="bulkoff">Desactivar</button><button type="button" class="cp-ibx" data-a="bulkclr" aria-label="Quitar selección">' + ic('x', 15) + '</button></div>' : '') +
    '</aside>';
}
function cmpPlanes(a, b) {
  var aa = (+a.VENCIDAS || 0) + (+a.ATRASADAS || 0) > 0, bb = (+b.VENCIDAS || 0) + (+b.ATRASADAS || 0) > 0;
  return (bb - aa) || String(a.PROXIMA_FECHA || '9').localeCompare(String(b.PROXIMA_FECHA || '9')) || String(a.NOMBRE).localeCompare(String(b.NOMBRE));
}
function listBody() {
  if (!U.lista) return '<div style="padding:10px;display:flex;flex-direction:column;gap:10px">' + [1, 2, 3, 4].map(function () { return '<div class="cp-sk" style="height:84px"></div>'; }).join('') + '</div>';
  var ps = U.lista.filter(planMatch);
  ps.sort(cmpPlanes);
  if (!ps.length) return U.lista.length
    ? '<div class="cp-empty" style="margin:8px"><span class="cp-ei">' + ic('search', 20) + '</span><b>Ningún plan coincide</b>Prueba con otro nombre, código o activo.<button type="button" class="cp-lnk" data-a="pfclear">Limpiar filtros</button></div>'
    : '<div class="cp-empty" style="margin:8px"><span class="cp-ei">' + ic('calw', 20) + '</span><b>Aún no hay planes</b>Crea el primero con «Nuevo plan».</div>';
  return ps.map(function (p) {
    var e = estado(p)[0], venc = +p.VENCIDAS || 0, atr = +p.ATRASADAS || 0, sel = U.plan === p.PLAN_ID;
    var nx = p.PROXIMA_FECHA ? (p.PROXIMA_PROYECCION ? 'Proyección: ' : '') + '<b>' + fD(p.PROXIMA_FECHA) + '</b>' + (p.PROXIMA_ACTIVO ? ' · ' + esc(p.PROXIMA_ACTIVO) : '')
      : e === 'inactive' ? 'No genera ejecuciones' : '<span style="color:var(--muted)">Sin próximas ejecuciones</span>';
    return '<div class="cp-prow' + (sel ? ' cp-on' : '') + '" data-a="open" data-p="' + p.PLAN_ID + '" role="button" tabindex="0" aria-current="' + sel + '">' +
      '<input type="checkbox" class="cp-cbx" data-a="mul" data-p="' + p.PLAN_ID + '"' + (U.multi[p.PLAN_ID] ? ' checked' : '') + ' aria-label="Seleccionar ' + esc(p.NOMBRE) + '">' +
      '<div class="cp-b"><div class="cp-r1"><b>' + esc(p.NOMBRE) + '</b>' + stChip(p) + '</div>' +
      '<div class="cp-r2"><span class="cp-mono" style="font-size:11px">' + esc(p.CODIGO) + '</span><span class="cp-sep">·</span><span>' + esc(p.PLANTA || 'Sin planta') + '</span><span class="cp-sep">·</span><span>' + pl(+p.ACTIVOS || 0, 'activo', 'activos') + ' · ' + pl(+p.INTERVENCIONES || 0, 'intervención', 'intervenciones') + '</span></div>' +
      '<div class="cp-r3"><span class="cp-nx">' + ic('calw', 14) + nx + '</span></div>' +
      '<div class="cp-r4"><span>' + esc(p.FRECUENCIAS || 'Sin frecuencias') + '</span>' + (p.RESPONSABLE ? '<span class="cp-sep">·</span>' + avatar(p.RESPONSABLE) + '<span>' + esc(p.RESPONSABLE) + '</span>' : '') +
      (venc ? '<span class="cp-atn cp-r"><i></i>' + pl(venc, 'vencida', 'vencidas') + '</span>' : '') + (atr ? '<span class="cp-atn cp-a"><i></i>' + pl(atr, 'atrasada', 'atrasadas') + '</span>' : '') +
      (e === 'draft' && !p.LISTO ? '<span class="cp-atn cp-a">' + ic('alert', 12) + 'Configuración incompleta</span>' : '') +
      (e === 'draft' && p.LISTO ? '<span class="cp-atn" style="color:var(--ok-ink)">' + ic('check', 12) + 'Listo para activar</span>' : '') + '</div></div></div>';
  }).join('');
}

/* =====================================================================
   PLANES · ficha
   ===================================================================== */
function freqCorta(f) {
  if (!f || !f.t) return '—';
  if (f.t === 'med') return 'Cada ' + fN(f.mn) + ' ' + (unidadMedidor() || 'u.');
  if (f.t === 'cond') return 'Por condición';
  if (f.t === 'fec') return 'Fechas puntuales';
  if (f.t === 'int') { var u = UNI[uniCod(f.iu)] || ['', '']; return 'Cada ' + f.n + ' ' + (+f.n === 1 ? u[0] : u[1]); }
  var n = +f.n;
  return f.rep === 'd' ? (n === 1 ? 'Diaria' : 'Cada ' + n + ' días') : f.rep === 'w' ? (n === 1 ? (f.days.length > 1 ? f.days.length + ' veces por semana' : 'Semanal') : 'Cada ' + n + ' semanas') : f.rep === 'm' ? (n === 1 ? 'Mensual' : n === 3 ? 'Trimestral' : n === 6 ? 'Semestral' : 'Cada ' + n + ' meses') : 'Anual';
}
function proxima() {
  var e = estado(F.plan)[0];
  if (e === 'draft') { var p = (F.proyeccion || [])[0]; return p ? { d: dIso(p.FECHA), proj: true } : null; }
  var x = (F.proximas || []).filter(function (o) { return dIso(o.FECHA) >= TODAY; })[0];
  return x ? { d: dIso(x.FECHA) } : null;
}

/* =====================================================================
   FICHA POR PASOS (§ «Planes por pasos»)
   Cinco pasos con barra fija: Activos · Trabajo · Frecuencia ·
   Responsable · Activar / Aplicar / Resumen. Una sola fuente de
   validación (checks) alimenta la barra, el pie, la Revisión y el
   bloqueo de «Siguiente»; el servidor valida lo mismo al activar.
   ===================================================================== */
var STEPS = {
  1: ['Activos', '¿Qué activos se mantienen?', 'Elige los activos que recibirán este mantenimiento. Puedes agregar varios a la vez.'],
  2: ['Trabajo', '¿Qué trabajo se hace?', 'Cada intervención es un trabajo que se repite y genera su propia orden de trabajo, por ejemplo «Mantención 2.000 h» o «Inspección mensual».'],
  3: ['Frecuencia', '¿Cada cuánto se hace?', 'Define cuándo toca cada intervención. Las fechas se recalculan mientras editas.'],
  4: ['Responsable', '¿Quién lo ejecuta?', 'Cada orden de trabajo nacerá asignada a esta persona y grupo. El detalle se ajusta después en la OT.'],
  5: ['Revisar', '', '']
};
Object.assign(U, { step: {}, vis: {}, t5: {}, nx: {}, tried: {} });
var short = function (n) { var w = String(n || '').split(' ').filter(Boolean); return w[0] ? w[0] + (w[1] ? ' ' + w[1][0] + '.' : '') : ''; };
var chL = function (n) { return ic('chevl', n); };
var planEst = function () { return estado(F.plan)[0]; };            // draft | active | changes | inactive
var ints = function () { return F ? F.intervenciones : []; };
var enab = function () { return ints().filter(function (i) { return i.HABILITADO; }); };

/* Lo que impide guardar una frecuencia, en una frase (vacío si está bien). */
function freqIssue(f) {
  if (!f || !f.t) return 'falta definir cada cuánto se hace';
  if (f.t === 'cal' && f.rep === 'w' && !f.days.length) return 'elige al menos un día de la semana';
  if (f.t === 'fec' && !f.dates.length) return 'agrega al menos una fecha';
  if (f.t === 'cond' && !f.ctext) return 'define la condición que la dispara';
  if ((f.t === 'cal' || f.t === 'int') && !(+f.n > 0)) return '«cada» debe ser mayor que 0';
  if (f.t === 'med' && !(+f.mn > 0)) return '«cada» debe ser mayor que 0';
  if (f.to && f.from && f.to < f.from) return 'la fecha «hasta» es anterior a «desde»';
  return '';
}
var permPend = function (i, a) { return !!U.pend['perm' + i.CODIGO + a.CODIGO]; };
function intIssue(i) {
  return !String(i.NOMBRE || '').trim() || !(+i.DURACION > 0) || (i.ACTIVIDADES || []).some(function (a) { return !String(a.NOMBRE || '').trim() || permPend(i, a); });
}

function checks() {
  var B = [], W = [], act = F.activos, en = enab(), nm = function (i) { return i.NOMBRE || i.CODIGO; };
  B.push({ ok: act.length > 0, step: 1, t: act.length ? pl(act.length, 'activo', 'activos') : 'La planificación necesita al menos un activo' });
  B.push({ ok: en.length > 0, step: 2, t: en.length ? pl(en.length, 'intervención habilitada', 'intervenciones habilitadas') : 'Agrega al menos una intervención' });
  var bad = en.filter(function (i) { return !String(i.NOMBRE || '').trim() || !(+i.DURACION > 0); })[0], badA = null;
  en.forEach(function (i) { (i.ACTIVIDADES || []).forEach(function (a) { if (!badA && !String(a.NOMBRE || '').trim()) badA = [i, a]; }); });
  B.push({ ok: !bad && !badA, step: 2, t: bad ? bad.CODIGO + ': ' + (!String(bad.NOMBRE || '').trim() ? 'falta el nombre' : 'la duración debe ser mayor que 0') : badA ? badA[1].CODIGO + ' de ' + nm(badA[0]) + ': falta el nombre de la actividad' : 'Cada intervención tiene nombre y duración', int: bad ? bad.HITO_ID : badA && badA[0].HITO_ID, act: !bad && badA ? badA[1].ACTIVIDAD_ID : null });
  var np = null; en.forEach(function (i) { (i.ACTIVIDADES || []).forEach(function (a) { if (!np && permPend(i, a)) np = [i, a]; }); });
  B.push({ ok: !np, step: 2, t: np ? (np[1].NOMBRE || np[1].CODIGO) + ': indica el tipo de permiso' : 'Las actividades con permiso tienen su tipo', int: np && np[0].HITO_ID, act: np && np[1].ACTIVIDAD_ID });
  var nof = en.filter(function (i) { return freqIssue(fqDe2(i)); })[0];
  B.push({ ok: en.length > 0 && !nof, step: 3, t: nof ? nm(nof) + ': ' + freqIssue(fqDe2(nof)) : 'Cada intervención tiene frecuencia', int: nof && nof.HITO_ID });
  en.forEach(function (i) {
    if (!(i.ACTIVIDADES || []).length) W.push({ step: 2, t: nm(i) + ': sin actividades, la OT tendrá un solo paso', int: i.HITO_ID });
    var f = fqDe2(i);
    if (f.t && !freqIssue(f) && f.t !== 'med' && f.t !== 'cond' && !(i.FECHAS || []).some(function (x) { return !x.DESCARTADA && dIso(x.FECHA) <= addD(TODAY, 90); })) W.push({ step: 3, t: nm(i) + ': no tiene fechas en los próximos 90 días', int: i.HITO_ID });
    if (f.t === 'med') { var sin = act.filter(function (a) { return !a.MEDIDOR_ID; }); if (sin.length) W.push({ step: 3, t: nm(i) + ': ' + sin.map(function (a) { return a.CODIGO; }).join(', ') + ' no ' + (sin.length === 1 ? 'tiene medidor y nunca generará' : 'tienen medidor y nunca generarán'), int: i.HITO_ID }); }
    if (!i.RESPONSABLE_ID && !i.GRUPO_ID) W.push({ step: 4, t: nm(i) + ': sin responsable, las OT nacerán sin asignar', int: i.HITO_ID });
  });
  act.forEach(function (a) {
    if (a.FUERA_ALCANCE) W.push({ step: 1, t: a.CODIGO + ' queda fuera del alcance del plan: no generará trabajo' });
    if (a.OTROS_PLANES) W.push({ step: 1, t: a.CODIGO + ' ya está en ' + a.OTROS_PLANES });
  });
  var okNombre = !!String(F.plan.NOMBRE || '').trim();
  return { B: B, W: W, ok: B.every(function (b) { return b.ok; }) && okNombre };
}
function stepInfo() {
  var ck = checks(), en = enab(), nAct = ints().reduce(function (t, i) { return t + (i.ACTIVIDADES || []).length; }, 0), est = planEst();
  var fqs = [], seen = {};
  en.forEach(function (i) { var f = fqDe2(i); if (!freqIssue(f)) { var s = freqCorta(f); if (!seen[s]) { seen[s] = 1; fqs.push(s); } } });
  var resps = []; en.forEach(function (i) { var n = i.RESPONSABLE || i.GRUPO; if (n && resps.indexOf(short(n)) < 0) resps.push(short(n)); });
  var nb = ck.B.filter(function (b) { return !b.ok; }).length;
  return {
    ck: ck,
    err: function (k) { return ck.B.filter(function (b) { return !b.ok && b.step === k; }); },
    warn: function (k) { return ck.W.filter(function (w) { return w.step === k; }); },
    done: { 1: F.activos.length > 0, 2: en.length > 0, 3: en.length > 0, 4: en.length > 0 && en.every(function (i) { return i.RESPONSABLE_ID || i.GRUPO_ID; }), 5: ck.ok },
    sub: { 1: F.activos.length ? pl(F.activos.length, 'activo', 'activos') : 'Sin activos', 2: ints().length ? pl(ints().length, 'intervención', 'intervenciones') + ' · ' + pl(nAct, 'actividad', 'actividades') : 'Sin intervenciones', 3: fqs.join(' · ') || 'Sin definir', 4: resps.join(', ') || 'Sin responsable', 5: nb ? 'Falta ' + nb : est === 'draft' ? 'Listo para activar' : est === 'changes' ? 'Listo para aplicar' : 'Todo en orden' }
  };
}
function pasoInicial(info) {
  var est = planEst();
  if (est !== 'draft') return 5;
  if (!F.activos.length && !ints().length) return 1;
  return [1, 2, 3].filter(function (k) { return info.err(k).length; })[0] || 5;
}
function curStep(info) {
  var id = F.plan.PLAN_ID;
  if (!U.step[id]) U.step[id] = pasoInicial(info);
  return U.step[id];
}
var step5Name = function () { var e = planEst(); return e === 'draft' ? 'Activar' : e === 'changes' ? 'Aplicar' : 'Resumen'; };
function nextLabel(i) {
  var f = fqDe2(i); if (!i.HABILITADO || freqIssue(f)) return '';
  if (f.t === 'cond') return 'Cuando ' + f.ctext;
  if (f.t === 'med') {
    var m = F.activos.map(function (a) { return medNext(f, a); }).filter(Boolean).sort(function (a, b) { return a - b; })[0];
    return m ? 'al llegar a ' + fN(m) + ' ' + (unidadMedidor() || '') : '';
  }
  var d = (i.FECHAS || []).filter(function (x) { return !x.DESCARTADA && dIso(x.FECHA) >= TODAY; })[0];
  return d ? fDL(dIso(d.FECHA)) : '';
}
/* Intervención seleccionada en los pasos 2 y 3 (por código: sobrevive a las copias de borrador). */
function selInt() {
  var id = F.plan.PLAN_ID, list = ints(), cur = U.oi[id];
  var h = list.filter(function (i) { return i.CODIGO === cur; })[0];
  if (!h) { h = list[0] || null; U.oi[id] = h ? h.CODIGO : null; }
  return h;
}
/* El orden de la lista (atención primero) también rige las flechas de la ficha. */
function ordenPlanes() { return (U.lista || []).filter(planMatch).slice().sort(cmpPlanes); }

/* ---- la ficha ---- */
function fichaHTML() {
  if (!U.plan) return '';
  if (!F || F.plan.PLAN_ID !== U.plan) return '<section class="cp-fi"><div class="cp-card" style="display:flex;flex-direction:column;gap:12px" aria-busy="true" aria-label="Cargando"><div class="cp-sk" style="height:34px;width:46%"></div><div class="cp-sk" style="height:60px"></div><div class="cp-sk" style="height:260px"></div></div></section>';
  var p = F.plan, E = editable(), info = stepInfo(), ck = info.ck, k = curStep(info), est = planEst(), id = p.PLAN_ID;
  U.step[id] = k; (U.vis[id] = U.vis[id] || {})[k] = 1;
  var ver = est === 'active' ? '<button type="button" class="cp-lnk" data-a="stp" data-v="5" data-t5="hist">v' + p.VERSION_VIGENTE + ' activa desde ' + fDN(p.VERSION_DESDE) + '</button>'
    : est === 'changes' ? '<button type="button" class="cp-lnk" data-a="stp" data-v="5" data-t5="hist">v' + p.VERSION_VIGENTE + ' activa · cambios en v' + p.VERSION_BORRADOR + '</button>'
    : est === 'draft' ? '<span>Nunca activado</span>' : '<span>Inactivo desde ' + fDN(p.RETIRO_FECHA) + '</span>';
  var nb = ck.B.filter(function (b) { return !b.ok; }).length, acts = '';
  if (est === 'draft') acts = '<button type="button" class="cp-rpill' + (ck.ok ? ' cp-ok' : '') + '" data-a="stp" data-v="5">' + ic(ck.ok ? 'check' : 'clip', 15) + (ck.ok ? 'Listo para activar' : 'Falta ' + pl(nb, 'dato', 'datos') + ' para activar') + '</button>';
  if (est === 'changes') acts = '<button type="button" class="cp-rpill cp-p" data-a="stp" data-v="5">' + ic('pencil', 15) + pl(+p.CAMBIOS || 0, 'cambio sin aplicar', 'cambios sin aplicar') + '</button>';
  if (est === 'inactive' && U.permisos.editar) acts = '<button type="button" class="cp-btn cp-pri" data-a="reactivate">' + ic('trend', 16) + 'Reactivar</button>';
  var vv = +p.VENCIDAS || 0, aa = +p.ATRASADAS || 0, fl = U.flash[id];
  var banner = fl ? '<div class="cp-bnr cp-' + (fl.w ? 'w' : 'ok') + '">' + ic(fl.w ? 'alert' : 'check', 18) + '<span>' + fl.t + '</span><span class="cp-r">' + (fl.retry ? '<button type="button" class="cp-btn cp-sec cp-xs" data-a="retrygen">Reintentar</button>' : '<button type="button" class="cp-btn cp-out cp-xs" data-a="tab" data-t="ejecuciones" data-fp="' + id + '">Ver ejecuciones</button>') + '<button type="button" class="cp-ibx" data-a="flashx" aria-label="Cerrar">' + ic('x', 15) + '</button></span></div>'
    : est === 'changes' ? '<div class="cp-bnr cp-p">' + ic('pencil', 18) + '<span><b>Estás editando cambios sin aplicar.</b> La v' + p.VERSION_VIGENTE + ' sigue generando trabajo hasta que apliques en el paso 5.</span></div>'
    : est === 'inactive' ? '<div class="cp-bnr cp-i">' + ic('alert', 18) + '<span><b>Plan inactivo:</b> no genera ejecuciones. Motivo: ' + esc(p.RETIRO_MOTIVO || '—') + ' — ' + esc(p.RETIRO_USUARIO || '') + '</span></div>'
    : vv + aa ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span><b>' + pl(vv + aa, 'ejecución vencida o atrasada', 'ejecuciones vencidas o atrasadas') + '</b> sin orden de trabajo.</span><span class="cp-r"><button type="button" class="cp-btn cp-sec cp-xs" data-a="tab" data-t="ejecuciones" data-fp="' + id + '" data-ff="att">Revisar y generar OT</button></span></div>' : '';
  var bar = [1, 2, 3, 4, 5].map(function (n) {
    var e = info.err(n).length, w = n === 4 ? info.warn(n).length : 0, seen = U.tried[id] || est !== 'draft' || (U.vis[id][n] && n !== k);
    var state = n === k ? 'cur' : seen && e ? 'err' : info.done[n] && !e ? (w ? 'wa' : 'ok') : '';
    var c = state === 'ok' ? ic('check', 15) : state === 'err' ? '!' : n;
    return '<button type="button" class="cp-sti ' + (state ? 'cp-' + state : '') + '" data-a="stp" data-v="' + n + '"' + (n === k ? ' aria-current="step"' : '') + '><span class="cp-c">' + c + '</span><span class="cp-tx"><b>' + (n === 5 ? step5Name() : STEPS[n][0]) + '</b><small>' + esc(info.sub[n]) + '</small></span></button>';
  }).join('<span class="cp-ln" aria-hidden="true"></span>');
  var orden = ordenPlanes(), x = orden.findIndex(function (q) { return q.PLAN_ID === id; });
  var cnav = orden.length > 1 && x >= 0 ? '<span>' + (x + 1) + ' de ' + orden.length + '</span><button type="button" class="cp-ibx" data-a="pnav" data-v="-1" aria-label="Plan anterior"' + (x > 0 ? '' : ' disabled') + '>' + chL(15) + '</button><button type="button" class="cp-ibx" data-a="pnav" data-v="1" aria-label="Plan siguiente"' + (x < orden.length - 1 ? '' : ' disabled') + '>' + ic('chev', 15) + '</button>' : '';
  return '<section class="cp-fi" aria-label="Plan ' + esc(p.NOMBRE) + '">' +
    '<div class="cp-fh"><div class="cp-crumb"><button type="button" class="cp-lnk" data-a="back">' + chL(15) + 'Planes</button><span class="cp-sep">/</span><button type="button" class="cp-psw" data-a="psw" aria-haspopup="dialog">' + (esc(p.NOMBRE) || esc(p.CODIGO)) + ic('chevd', 14) + '</button><span class="cp-cnav">' + cnav + '</span></div>' +
    '<div class="cp-fh-1"><div class="cp-nm"><input class="cp-ie' + (String(p.NOMBRE).trim() ? '' : ' cp-err') + '" data-pf="nombre" value="' + esc(p.NOMBRE) + '" aria-label="Nombre del plan" placeholder="Nombre del plan"' + (E ? '' : ' disabled') + ' maxlength="200">' +
    '<div class="cp-meta"><code>' + esc(p.CODIGO) + '</code>' + stChip(p) + ver + '<span class="cp-sep">·</span><span>' + esc(p.PLANTA || 'Sin planta') + (p.TIPO ? ' · ' + esc(p.TIPO) : '') + '</span><span class="cp-saved" id="cpSaved"></span></div>' + (String(p.NOMBRE).trim() ? '' : mc('', 'El plan necesita un nombre.')) + '</div>' +
    '<div class="cp-acts">' + acts + '<button type="button" class="cp-ibx" data-a="more" aria-label="Más acciones" aria-haspopup="menu">' + ic('dots', 18) + '</button></div></div>' + banner + '</div>' +
    '<nav class="cp-stb" aria-label="Pasos del plan">' + bar + '</nav>' + stepHTML(E, info, k) + '</section>';
}
function stepHTML(E, info, k) {
  var id = F.plan.PLAN_ID, est = planEst(), errs = info.err(k), warns = k === 5 ? [] : info.warn(k), tried = U.nx[id] === k || U.tried[id];
  var body = k === 1 ? s1HTML(E) : k === 2 ? s2HTML(E) : k === 3 ? s3HTML(E) : k === 4 ? s4HTML(E) : s5HTML(E, info);
  var head = k === 5 ? s5Head(info) : '<span class="cp-ey">Paso ' + k + ' de 5</span><h2>' + STEPS[k][1] + '</h2><p>' + STEPS[k][2] + '</p>';
  var msg = errs.length && tried ? '<span class="cp-msg">' + ic('alert', 14) + '<span>Falta: ' + esc(errs[0].t) + '</span></span>' : errs.length ? '<span class="cp-msg cp-i">' + ic('help', 14) + '<span>' + pl(errs.length, 'dato pendiente', 'datos pendientes') + ' en este paso</span></span>' : warns.length ? '<span class="cp-msg cp-w">' + ic('alert', 14) + '<span>' + pl(warns.length, 'punto', 'puntos') + ' por revisar</span></span>' : k < 5 ? '<span class="cp-msg cp-ok2">' + ic('check', 14) + '<span>Paso completo</span></span>' : '';
  var ed = U.permisos.editar, right = '';
  if (k < 5) right = '<button type="button" class="cp-btn cp-pri" data-a="next">Siguiente: ' + (k + 1 === 5 ? 'revisar' : STEPS[k + 1][0].toLowerCase()) + ic('chev', 16) + '</button>';
  else if (est === 'draft') right = ed ? '<button type="button" class="cp-btn cp-pri" data-a="activate"' + (info.ck.ok ? '' : ' aria-disabled="true"') + '>' + ic('check', 16) + 'Activar plan</button>' : '';
  else if (est === 'changes') right = ed ? '<button type="button" class="cp-btn cp-plain" data-a="discard">Descartar cambios</button><button type="button" class="cp-btn cp-pri" data-a="apply"' + (info.ck.ok ? '' : ' aria-disabled="true"') + '>' + ic('check', 16) + 'Aplicar cambios</button>' : '';
  else if (est === 'inactive') right = ed ? '<button type="button" class="cp-btn cp-pri" data-a="reactivate">' + ic('trend', 16) + 'Reactivar plan</button>' : '';
  else right = '<button type="button" class="cp-btn cp-out" data-a="tab" data-t="ejecuciones" data-fp="' + id + '" data-ff="all">Ver ejecuciones</button>';
  return '<div class="cp-stc" id="cpStc"><div class="cp-stc-h">' + head + '</div><div class="cp-stc-b">' + body + '</div><div class="cp-stc-f">' + (k > 1 ? '<button type="button" class="cp-btn cp-plain" data-a="stp" data-v="' + (k - 1) + '">' + chL(16) + 'Anterior</button>' : '<span></span>') + '<span class="cp-fm">' + msg + '</span><span class="cp-r">' + right + '</span></div></div>';
}

/* ---- paso 1 · activos ---- */
function s1HTML(E) {
  var p = F.plan, act = F.activos, fuera = act.filter(function (a) { return a.FUERA_ALCANCE; });
  var modelos = (U.cat.modelos || []).filter(function (m) { return p.TIPO_ID && m.TIPO_ID === p.TIPO_ID; }).map(function (m) { return { id: m.ID, n: m.NOMBRE }; });
  return '<div class="cp-scope"><div class="cp-fld"><label>Planta</label>' + combo('cpScPlanta', CFG.plantas || [], p.PLANTA_ID || '', { etiqueta: 'Planta', ph: 'Elige la planta', dis: !E, data: ' data-pf="planta"' }) + '</div>' +
    '<div class="cp-fld"><label>Tipo de activo <small>opcional</small></label>' + combo('cpScTipo', [{ id: '', n: 'Cualquier tipo' }].concat(catL('tipos')), p.TIPO_ID || '', { etiqueta: 'Tipo de activo', ph: 'Cualquier tipo', dis: !E, data: ' data-pf="tipo"' }) + '</div>' +
    '<div class="cp-fld"><label>Modelo <small>opcional</small></label>' + combo('cpScModelo', [{ id: '', n: p.TIPO_ID ? 'Cualquier modelo' : 'Elige primero el tipo' }].concat(modelos), p.MODELO_ID || '', { etiqueta: 'Modelo', ph: p.TIPO_ID ? 'Cualquier modelo' : 'Elige primero el tipo', dis: !E || !p.TIPO_ID, data: ' data-pf="modelo"' }) + '</div></div>' +
    (act.length ? '<div class="cp-s-row"><b>' + pl(act.length, 'activo en el plan', 'activos en el plan') + '</b>' + (E ? '<button type="button" class="cp-btn cp-out cp-sm" data-a="addeq">' + ic('plus', 15) + 'Agregar activos</button>' : '') + '</div>' +
      (fuera.length ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span><b>' + esc(fuera.map(function (a) { return a.CODIGO; }).join(', ')) + '</b> ' + (fuera.length === 1 ? 'queda' : 'quedan') + ' fuera del alcance y no generará trabajo. Ajusta el alcance o quítalos.</span></div>' : '') +
      '<div class="cp-eqs">' + act.map(function (a) {
        return '<div class="cp-eq' + (a.FUERA_ALCANCE ? ' cp-outx' : '') + '"><span class="cp-ph">' + (a.FOTO ? '<img class="cp-ph-img" src="' + esc(a.FOTO) + '" alt="">' : ic('cog', 20)) + '</span><div style="min-width:0"><b>' + esc(a.NOMBRE) + '</b><small>' + esc(a.CODIGO) + (a.AREA ? ' · ' + esc(a.AREA) : '') + '</small><div class="cp-tgs"><span class="cp-tg">' + (a.COMPONENTE ? esc(a.COMPONENTE) : 'Activo completo') + '</span>' + (a.MEDIDOR_ID ? '<span class="cp-tg cp-c">' + ic('gauge', 11) + fN(a.MEDIDOR_VALOR) + ' ' + esc(a.MEDIDOR_UNIDAD || '') + '</span>' : '') + (a.FUERA_ALCANCE ? '<span class="cp-tg cp-w">Fuera del alcance</span>' : '') + (a.OTROS_PLANES ? '<span class="cp-tg cp-w" title="También en ' + esc(a.OTROS_PLANES) + '">También en ' + esc(a.OTROS_PLANES) + '</span>' : '') + '</div></div>' +
          '<div class="cp-x"><a class="cp-ibx" href="' + esc(a.URL) + '" target="_blank" rel="noopener" aria-label="Ver ficha del activo ' + esc(a.CODIGO) + '">' + ic('arrow', 15) + '</a>' + (E ? '<button type="button" class="cp-ibx cp-dn" data-a="rmeq" data-v="' + a.VINCULO_ID + '" data-c="' + esc(a.CODIGO) + '" aria-label="Quitar ' + esc(a.CODIGO) + ' del plan">' + ic('x', 15) + '</button>' : '') + '</div></div>';
      }).join('') + '</div>'
      : '<div class="cp-empty cp-big' + (U.tried[F.plan.PLAN_ID] ? ' cp-err' : '') + '"><span class="cp-ei">' + ic('cog', 22) + '</span><b>Todavía no hay activos</b><span>Agrega los activos' + (p.PLANTA ? ' de ' + esc(p.PLANTA) : '') + ' que recibirán este mantenimiento.</span>' + (E ? '<button type="button" class="cp-btn cp-pri" data-a="addeq">' + ic('plus', 16) + 'Agregar activos</button>' : '') + '</div>');
}

/* ---- selector de intervención (pasos 2 y 3) ---- */
function intTabs(cur, E, mode) {
  return '<div class="cp-itabs" role="tablist" aria-label="Intervenciones">' + ints().map(function (i) {
    var bad = mode === 2 ? intIssue(i) : !!freqIssue(fqDe2(i));
    return '<button type="button" role="tab" class="cp-itab' + (i === cur ? ' cp-on' : '') + (i.HABILITADO ? '' : ' cp-off') + '" data-a="isel" data-i="' + i.HITO_ID + '" aria-selected="' + (i === cur) + '"><span class="cp-cd">' + esc(i.CODIGO) + '</span><span class="cp-nm">' + (esc(i.NOMBRE) || '<em>Sin nombre</em>') +
      (mode === 3 ? '<small>' + (i.HABILITADO && !bad ? esc(freqCorta(fqDe2(i))) : i.HABILITADO ? 'Sin frecuencia' : 'Deshabilitada') + '</small>' : '<small>' + (i.HABILITADO ? pl((i.ACTIVIDADES || []).length, 'actividad', 'actividades') : 'Deshabilitada') + '</small>') + '</span>' +
      (!i.HABILITADO ? '' : bad ? '<span class="cp-ix" title="Falta completar">!</span>' : '<span class="cp-iok">' + ic('check', 12) + '</span>') + '</button>';
  }).join('') + (mode === 2 && E ? '<button type="button" class="cp-itab cp-add" data-a="addint">' + ic('plus', 15) + 'Agregar intervención</button>' : '') + '</div>';
}

/* ---- paso 2 · trabajo ---- */
function s2HTML(E) {
  var list = ints(), tried = U.tried[F.plan.PLAN_ID];
  if (!list.length) return '<div class="cp-empty cp-big' + (tried ? ' cp-err' : '') + '"><span class="cp-ei">' + ic('wrench', 22) + '</span><b>Agrega la primera intervención</b><span>Escribe un nombre o elige uno frecuente para empezar.</span>' + (E ? '<div class="cp-quick">' + ['Inspección mensual', 'Lubricación', 'Mantención 500 h', 'Limpieza'].map(function (n) { return '<button type="button" class="cp-fc" data-a="addint" data-n="' + n + '">' + ic('plus', 13) + n + '</button>'; }).join('') + '</div><button type="button" class="cp-btn cp-pri" data-a="addint">' + ic('plus', 16) + 'Agregar intervención</button>' : '') + '</div>';
  var i = selInt(), id = i.HITO_ID, dis = E ? ' disabled' : '', nombre = String(i.NOMBRE || '').trim();
  dis = E ? '' : ' disabled';
  return intTabs(i, E, 2) + '<div class="cp-ipanel" id="cpInt' + id + '">' +
    '<div class="cp-blk"><div class="cp-blk-h"><h4>' + esc(i.CODIGO) + ' · Datos de la orden de trabajo</h4><div class="cp-r"><label class="cp-sw"><input type="checkbox" data-iv="habilitado" data-i="' + id + '"' + (i.HABILITADO ? ' checked' : '') + dis + '><i></i>' + (i.HABILITADO ? 'Habilitada' : 'Deshabilitada') + '</label></div></div>' +
    '<div class="cp-grid4c"><div class="cp-fld" style="grid-column:span 2"><label>Nombre de la intervención</label><input class="cp-inp' + (nombre ? '' : ' cp-err') + '" data-iv="nombre" data-i="' + id + '" value="' + esc(i.NOMBRE) + '"' + dis + ' placeholder="Ej.: Mantención 2.000 h" maxlength="200">' + (nombre ? '' : mc('', 'La intervención necesita un nombre.')) + '</div>' +
    '<div class="cp-fld"><label>Tipo de OT</label>' + combo('cpIvTipo' + id, catL('otTipos'), i.OT_TIPO_ID || '', { etiqueta: 'Tipo de OT', dis: !E, crear: E, ph: 'Elige o escribe uno nuevo', data: ' data-iv="tipo" data-i="' + id + '"', clave: 'cpOtTipos' }) + '</div>' +
    '<div class="cp-fld"><label>Prioridad</label>' + combo('cpIvPrio' + id, catL('prioridades'), i.OT_PRIORIDAD_ID || '', { etiqueta: 'Prioridad', dis: !E, data: ' data-iv="prioridad" data-i="' + id + '"', clave: 'cpPrioridades' }) + '</div>' +
    '<div class="cp-fld"><label>Duración estimada</label><div class="cp-unit"><input class="cp-inp' + (+i.DURACION > 0 ? '' : ' cp-err') + '" type="number" min="0.25" step="0.25" data-iv="duracion" data-i="' + id + '" value="' + (i.DURACION ? hrs(i.DURACION) : '') + '"' + dis + '><span class="cp-u">horas</span></div>' + (+i.DURACION > 0 ? '' : mc('', 'La duración debe ser mayor que 0.')) + '</div>' +
    '<div class="cp-fld" style="grid-column:2/-1;justify-content:flex-end"><div style="display:flex;gap:18px;flex-wrap:wrap;padding-bottom:9px"><label class="cp-sw"><input type="checkbox" data-iv="parada" data-i="' + id + '"' + (i.PARADA ? ' checked' : '') + dis + '><i></i>Requiere parada del activo</label><label class="cp-sw"><input type="checkbox" data-iv="overhaul" data-i="' + id + '"' + (i.OVERHAUL ? ' checked' : '') + dis + '><i></i>Es overhaul</label></div></div>' +
    '<div class="cp-fld" style="grid-column:1/-1"><label>Descripción <small>opcional · se copia a la OT</small></label><textarea class="cp-inp" rows="2" data-iv="descripcion" data-i="' + id + '"' + dis + ' placeholder="Qué debe saber el técnico antes de empezar">' + esc(i.DESCRIPCION || '') + '</textarea></div></div></div>' +
    actsHTML(i, E) +
    (E ? '<div class="cp-ifoot">' + (!i.GENERO ? '<button type="button" class="cp-btn cp-dano cp-xs" data-a="rmint" data-i="' + id + '">' + ic('x', 14) + 'Quitar ' + esc(i.CODIGO) + '</button>' : '<span class="cp-msg cp-i">' + ic('help', 13) + '<span>' + esc(i.CODIGO) + ' ya generó ejecuciones: para dejar de usarla, deshabilítala.</span></span>') + '</div>' : '') + '</div>';
}

/* ---- paso 3 · frecuencia ---- */
function s3HTML(E) {
  if (!ints().length) return '<div class="cp-empty cp-big"><span class="cp-ei">' + ic('calw', 22) + '</span><b>Primero define el trabajo</b><span>La frecuencia se configura para cada intervención.</span><button type="button" class="cp-btn cp-out" data-a="stp" data-v="2">' + chL(15) + 'Ir a Trabajo</button></div>';
  var i = selInt(), nx = nextLabel(i), iss = freqIssue(fqDe2(i)), nm = i.NOMBRE || i.CODIGO;
  return intTabs(i, E, 3) +
    '<div class="cp-nxt' + (nx ? '' : ' cp-no') + '">' + ic('calw', 20) + '<span>' + (nx ? '<small>Próxima ejecución de ' + esc(nm) + '</small><b>' + esc(nx) + '</b>' : '<small>' + esc(nm) + '</small><b>' + (i.HABILITADO ? (iss ? esc(iss.charAt(0).toUpperCase() + iss.slice(1)) : 'Sin fechas próximas') : 'Intervención deshabilitada') + '</b>') + '</span></div>' + whenHTML(i, E);
}

/* ---- paso 4 · responsable ---- */
function s4HTML(E) {
  if (!ints().length) return '<div class="cp-empty cp-big"><span class="cp-ei">' + ic('users', 22) + '</span><b>Primero define el trabajo</b><span>El responsable se asigna a cada intervención.</span><button type="button" class="cp-btn cp-out" data-a="stp" data-v="2">' + chL(15) + 'Ir a Trabajo</button></div>';
  var list = ints(), dis = !E, ids = {}; list.forEach(function (i) { ids[i.RESPONSABLE_ID || 0] = 1; });
  var same = Object.keys(ids).length === 1 ? (list[0].RESPONSABLE_ID || '') : '';
  var personas = [{ id: '', n: 'Sin responsable' }].concat(catL('personas'));
  return (E && list.length > 1 ? '<div class="cp-allr"><span>' + ic('users', 16) + 'Asignar todas las intervenciones a</span><span style="min-width:240px">' + combo('cpAllResp', [{ id: '', n: 'Elegir persona…' }].concat(catL('personas')), same, { etiqueta: 'Responsable para todas', ph: 'Elegir persona…', data: ' data-ar="1"', clave: 'cpAllResps' }) + '</span></div>' : '') +
    '<div class="cp-rtbl"><div class="cp-rh"><span>Intervención</span><span>Responsable</span><span>Grupo de trabajo <small>opcional</small></span></div>' +
    list.map(function (i) {
      var f = fqDe2(i);
      return '<div class="cp-rr' + (i.HABILITADO ? '' : ' cp-off') + '"><span class="cp-s"><b>' + esc(i.CODIGO) + ' · ' + (esc(i.NOMBRE) || 'Sin nombre') + '</b><small>' + (freqIssue(f) ? 'Sin frecuencia' : esc(freqCorta(f))) + ' · ' + fH(i.DURACION) + '</small></span>' +
        '<span>' + combo('cpIvResp' + i.HITO_ID, personas, i.RESPONSABLE_ID || '', { etiqueta: 'Responsable de ' + (i.NOMBRE || i.CODIGO), ph: 'Sin responsable', dis: dis, data: ' data-iv="responsable" data-i="' + i.HITO_ID + '"', clave: 'cpPersonas', err: false }) + '</span>' +
        '<span>' + combo('cpIvGrupo' + i.HITO_ID, [{ id: '', n: 'Sin grupo' }].concat(catL('grupos')), i.GRUPO_ID || '', { etiqueta: 'Grupo de ' + (i.NOMBRE || i.CODIGO), ph: 'Sin grupo', dis: dis, data: ' data-iv="grupo" data-i="' + i.HITO_ID + '"', clave: 'cpGrupos' }) + '</span></div>';
    }).join('') + '</div>' +
    (enab().some(function (i) { return !i.RESPONSABLE_ID && !i.GRUPO_ID; }) ? mc('w', 'Sin responsable, las OT nacerán sin asignar y habrá que asignarlas una por una. Puedes activar igual.') : mc('i', 'Al generar cada OT, SIGMA la asigna a este responsable y su grupo.', 'help'));
}

/* ---- paso 5 · revisar / activar / aplicar / resumen ---- */
function s5Head(info) {
  var e = planEst(), p = F.plan, ok = info.ck.ok;
  if (e === 'draft') return '<span class="cp-ey">Paso 5 de 5</span><h2>' + (ok ? 'Todo listo para activar' : 'Revisa antes de activar') + '</h2><p>' + (ok ? 'Así funcionará el plan. Al activarlo, SIGMA programa las ejecuciones de los próximos 90 días.' : 'Completa lo que falta: cada punto te lleva directo al campo.') + '</p>';
  if (e === 'changes') return '<span class="cp-ey">Paso 5 de 5</span><h2>Revisa los cambios antes de aplicar</h2><p>La v' + p.VERSION_VIGENTE + ' sigue activa hasta que apliques. Abajo ves cómo quedan las ejecuciones.</p>';
  if (e === 'inactive') return '<span class="cp-ey">Resumen</span><h2>Plan inactivo</h2><p>No genera ejecuciones desde el ' + fDN(p.RETIRO_FECHA) + '. Al reactivarlo, SIGMA vuelve a programar los próximos 90 días.</p>';
  return '<span class="cp-ey">Resumen</span><h2>Así funciona este plan</h2><p>Para cambiar algo, entra al paso que corresponda: lo activo sigue igual hasta que apliques los cambios.</p>';
}
function planStory() {
  var en = enab(); if (!en.length) return '';
  var eqs = F.activos.length ? pl(F.activos.length, 'activo', 'activos') + ' (' + F.activos.slice(0, 3).map(function (a) { return esc(a.CODIGO); }).join(', ') + (F.activos.length > 3 ? '…' : '') + ')' : '<span class="cp-miss">ningún activo</span>';
  return '<ul class="cp-story">' + en.map(function (i) {
    var f = fqDe2(i), iss = freqIssue(f), who = i.RESPONSABLE || i.GRUPO;
    return '<li><span class="cp-cd">' + esc(i.CODIGO) + '</span><span><b>' + (esc(i.NOMBRE) || '<span class="cp-miss">Sin nombre</span>') + '</b> ' + (iss ? '<span class="cp-miss">· ' + esc(iss) + '</span>' : '· ' + esc(freqText(f, true, unidadMedidor()).replace(/^C/, 'c'))) + ' · en ' + eqs + ' · ' + pl((i.ACTIVIDADES || []).length || 1, 'paso', 'pasos') + ' en la OT · ' + (who ? 'asignada a <b>' + esc(who) + '</b>' : '<span class="cp-wmiss">sin responsable</span>') + '</span></li>';
  }).join('') + '</ul>';
}
function s5HTML(E, info) {
  var p = F.plan, est = planEst(), ck = info.ck, id = p.PLAN_ID, t = U.t5[id] || 'rev', im = U.imp || {};
  var tabs = est === 'draft' ? [['rev', 'Revisión'], ['next', 'Proyección']] : [['rev', est === 'changes' ? 'Revisión' : 'Resumen'], ['next', 'Próximas ejecuciones'], ['ot', 'OT generadas'], ['hist', 'Historial']];
  var seg = '<div class="cp-segc cp-t5" role="tablist">' + tabs.map(function (x) { return '<button type="button" role="tab" data-a="t5" data-v="' + x[0] + '" aria-pressed="' + (t === x[0]) + '">' + x[1] + '</button>'; }).join('') + '</div>';
  if (t === 'next') return seg + nextHTML();
  if (t === 'ot') return seg + otHTML();
  if (t === 'hist') return seg + histHTML();
  var item = function (o, cls) { return '<button type="button" class="cp-' + cls + '" data-a="fix" data-step="' + o.step + '" data-i="' + (o.int || '') + '" data-c="' + (o.act || '') + '">' + ic(cls === 'ok' ? 'check' : cls === 'no' ? 'x' : 'alert', 15) + '<span>' + esc(o.t) + '</span><em>Paso ' + o.step + ' · ' + STEPS[o.step][0] + (cls === 'ok' ? '' : ' ›') + '</em></button>'; };
  if (est === 'draft' || est === 'changes') {
    var nb = ck.B.filter(function (b) { return b.ok; }).length;
    return seg + '<div class="cp-rv"><div class="cp-rv-l"><div class="cp-pgx"><div class="cp-pg' + (ck.ok ? ' cp-ok' : '') + '"><i style="width:' + Math.round(nb / ck.B.length * 100) + '%"></i></div><span>' + nb + ' de ' + ck.B.length + ' obligatorios</span></div>' +
      '<div class="cp-chk">' + ck.B.map(function (b) { return item(b, b.ok ? 'ok' : 'no'); }).join('') + '</div>' + (ck.W.length ? '<h5>Conviene revisar <small>no impide ' + (est === 'draft' ? 'activar' : 'aplicar') + '</small></h5><div class="cp-chk">' + ck.W.map(function (w) { return item(w, 'wa'); }).join('') + '</div>' : '') + '</div>' +
      '<div class="cp-rv-r"><h5>Así funcionará</h5>' + (planStory() || '<p class="cp-miss2">Cuando agregues intervenciones, aquí verás en palabras simples qué hará el plan.</p>') +
      (est === 'draft' ? '<div class="cp-imp">' + (ck.ok ? (im.CREAN != null ? 'Al activar se generarán <b>' + pl(+im.CREAN, 'ejecución', 'ejecuciones') + '</b> entre hoy y el ' + fDY(dIso(im.HASTA) || addD(TODAY, 90)) + ' para <b>' + pl(F.activos.length, 'activo', 'activos') + '</b>.' : 'Al activar, SIGMA programa las ejecuciones de los próximos 90 días.') : 'Cuando completes lo obligatorio, aquí verás cuántas ejecuciones se generarán.') + '</div>'
        : '<h5>Al aplicar, desde hoy</h5>' + imp4(im)) + '</div></div>';
  }
  var nProg = (F.proximas || []).filter(function (o) { return dIso(o.FECHA) >= TODAY; }).length, nx = proxima(), aten = (+p.VENCIDAS || 0) + (+p.ATRASADAS || 0);
  return seg + '<div class="cp-rv"><div class="cp-rv-l"><h5>Así funciona</h5>' + planStory() + '</div><div class="cp-rv-r">' + (est === 'inactive'
    ? '<div class="cp-bnr cp-i">' + ic('alert', 18) + '<span>' + esc(p.RETIRO_MOTIVO || '') + '<br><small style="color:var(--muted)">' + esc(p.RETIRO_USUARIO || '') + ' · ' + fDN(p.RETIRO_FECHA) + '</small></span></div>'
    : '<div class="cp-facts"><div><span>Próxima ejecución</span><b>' + (nx ? fDL(nx.d) : '—') + '</b></div><div><span>Pendientes · próximos 90 días</span><b>' + (im.DESACTIVAR_CANCELAN != null ? im.DESACTIVAR_CANCELAN : nProg) + '</b></div><div><span>Requieren atención</span><b style="' + (aten ? 'color:var(--red)' : '') + '">' + aten + '</b></div><div><span>Versión</span><b>v' + p.VERSION_VIGENTE + '</b><small>desde ' + fDN(p.VERSION_DESDE) + '</small></div></div>' + (ck.W.length ? '<h5>Conviene revisar</h5><div class="cp-chk">' + ck.W.map(function (w) { return item(w, 'wa'); }).join('') + '</div>' : '')) + '</div></div>';
}

/* ---- cuándo (editor de frecuencia, §15) ---- */
var HORAS = (function () { var l = []; for (var k = 0; k < 48; k++) { var h = pad(Math.floor(k / 2)) + ':' + (k % 2 ? '30' : '00'); l.push({ id: h, n: h }); } return l; })();
var DIAS31 = (function () { var l = []; for (var k = 1; k <= 31; k++) l.push({ id: k, n: String(k) }); return l; })();
var ORD = [{ id: 1, n: 'Primer' }, { id: 2, n: 'Segundo' }, { id: 3, n: 'Tercer' }, { id: 4, n: 'Cuarto' }, { id: -1, n: 'Último' }];
var DSEM = [1, 2, 3, 4, 5, 6, 7].map(function (d) { return { id: d, n: DIA[d].charAt(0).toUpperCase() + DIA[d].slice(1) }; });
var MESES = MES.map(function (m, k) { return { id: k + 1, n: m.charAt(0).toUpperCase() + m.slice(1) }; });
var TIPOS_F = [['cal', 'Calendario'], ['int', 'Intervalo'], ['fec', 'Fechas puntuales'], ['med', 'Por medidor'], ['cond', 'Por condición']];

function whenHTML(i, E) {
  var id = i.HITO_ID, f = fqDe2(i), dis = E ? '' : ' disabled', err = fqError(f);
  var segT = function (pressed) { return '<div class="cp-segc" role="group" aria-label="Tipo de frecuencia">' + TIPOS_F.map(function (x) { return '<button type="button" data-a="ftype" data-i="' + id + '" data-v="' + x[0] + '" aria-pressed="' + (pressed === x[0]) + '"' + dis + '>' + x[1] + '</button>'; }).join('') + '</div>'; };
  if (!f.t) return '<div class="cp-blk cp-err" id="cpWhen' + id + '"><div class="cp-blk-h"><h4>Cuándo</h4></div><div style="display:flex;flex-direction:column;gap:10px">' + mc('', 'Esta intervención necesita una frecuencia para poder activarse.') + segT(null) +
    (E && (U.cat.calendarios || []).length ? '<button type="button" class="cp-lnk" data-a="useshared" data-i="' + id + '">' + ic('link', 14) + 'O usar un calendario compartido de la Biblioteca</button>' : '') + '</div></div>';
  if (!i.PRIVADA) {
    return '<div class="cp-blk" id="cpWhen' + id + '"><div class="cp-blk-h"><h4>Cuándo</h4></div><div class="cp-fq-ed"><div class="cp-fq-f"><div class="cp-shrd"><span class="cp-pci2">' + ic('link', 18) + '</span><div style="flex:1;min-width:0"><b style="font-size:13px">Calendario compartido «' + esc(i.PROGRAMACION) + '»</b><div style="font-size:12px;color:var(--muted)">' + esc(freqText(f, true, unidadMedidor())) + ' · ' + pl(+i.OTROS_USOS || 0, 'otro uso', 'otros usos') + '</div></div></div>' +
      mc('i', 'Es de solo lectura aquí. Si lo cambias en la Biblioteca, cambia para todos los que lo usan.') +
      (E ? '<div style="display:flex;gap:8px;flex-wrap:wrap"><button type="button" class="cp-btn cp-out cp-xs" data-a="tab" data-t="biblioteca" data-lib="cal">Editar en Biblioteca</button><button type="button" class="cp-btn cp-ghost cp-xs" data-a="ownfreq" data-i="' + id + '">Convertir en propia</button></div>' : '') + '</div>' + pvHTML(i, f) + '</div></div>';
  }
  var seg = function (k, opts) { return '<div class="cp-segc" role="group">' + opts.map(function (o) { return '<button type="button" data-a="fset" data-i="' + id + '" data-k="' + k + '" data-v="' + o[0] + '" aria-pressed="' + (String(f[k]) === String(o[0])) + '"' + dis + '>' + o[1] + '</button>'; }).join('') + '</div>'; };
  var fc = function (k, lista, val, etq, ph) { return combo('cpF' + k + id, lista, val, { etiqueta: etq, ph: ph, dis: !E, data: ' data-fk="' + k + '" data-i="' + id + '"', clave: 'cpF' + k }); };
  var num = function (k, val, min, etq) { return '<input class="cp-inp" type="number" min="' + min + '" data-fk="' + k + '" data-i="' + id + '" value="' + (val == null ? '' : val) + '"' + dis + ' aria-label="' + etq + '">'; };
  var hourSel = '<div class="cp-fld"><label>Hora</label>' + fc('hour', HORAS, f.hour, 'Hora', 'Hora') + '</div>';
  var body = '';
  if (f.t === 'cal') {
    var unit = { d: +f.n === 1 ? 'día' : 'días', w: +f.n === 1 ? 'semana' : 'semanas', m: +f.n === 1 ? 'mes' : 'meses', y: +f.n === 1 ? 'año' : 'años' }[f.rep];
    var semErr = f.rep === 'w' && !f.days.length;
    body = '<div class="cp-fld"><span class="cp-lb">Se repite</span>' + seg('rep', [['d', 'Diaria'], ['w', 'Semanal'], ['m', 'Mensual'], ['y', 'Anual']]) + '</div>' +
      '<div class="cp-grid3c"><div class="cp-fld"><label>Cada</label><div class="cp-unit">' + num('n', f.n, 1, 'Cada cuánto') + '<span class="cp-u">' + unit + '</span></div></div>' + hourSel + '<div></div></div>' +
      (f.rep === 'w' ? '<div class="cp-fld"><span class="cp-lb">Días</span><div class="cp-days">' + [1, 2, 3, 4, 5, 6, 7].map(function (d) { return '<button type="button" data-a="fday" data-i="' + id + '" data-v="' + d + '" aria-pressed="' + (f.days.indexOf(d) >= 0) + '"' + dis + ' aria-label="' + DIA[d] + '">' + DIAC[d] + '</button>'; }).join('') + '</div>' + (semErr ? mc('', 'Elige al menos un día de la semana.') : '') + '</div>' : '') +
      (f.rep === 'm' || f.rep === 'y' ? '<div class="cp-fld"><span class="cp-lb">Qué día ' + (f.rep === 'm' ? 'del mes' : 'del año') + '</span>' + seg('mmode', [['day', 'Un día fijo'], ['ord', 'Un día de la semana']]) + '</div>' +
        '<div class="cp-grid3c">' + (f.rep === 'y' ? '<div class="cp-fld"><label>Mes</label>' + fc('month', MESES, f.month, 'Mes', 'Mes') + '</div>' : '') +
        (f.mmode === 'ord' ? '<div class="cp-fld"><label>Semana</label>' + fc('ord', ORD, f.ord, 'Semana del mes', 'Semana') + '</div><div class="cp-fld"><label>Día</label>' + fc('wd', DSEM, f.wd, 'Día de la semana', 'Día') + '</div>'
          : '<div class="cp-fld"><label>Día del mes</label>' + fc('md', DIAS31, f.md, 'Día del mes', 'Día') + (+f.md > 28 ? mc('i', 'En los meses más cortos se usa el último día.') : '') + '</div>') + '</div>' : '');
  }
  if (f.t === 'int') {
    var unis = (U.cat.unidades || []).filter(function (u) { return u.CODIGO !== 'MINUTO'; }).map(function (u) { var x = UNI[u.CODIGO] || [u.NOMBRE, u.NOMBRE]; return { id: u.ID, n: x[1] }; });
    body = '<div class="cp-grid3c"><div class="cp-fld"><label>Cada</label><div class="cp-unit">' + num('n', f.n, 1, 'Cada cuánto') + '</div></div><div class="cp-fld"><label>Unidad</label>' + fc('iu', unis, f.iu, 'Unidad', 'Unidad') + '</div><div class="cp-fld"><label>A partir de</label>' + fecha('f:' + id + ':anchor', f.anchor, { dis: !E, etiqueta: 'A partir de' }) + '</div></div><div class="cp-grid3c">' + hourSel + '</div>';
  }
  if (f.t === 'fec') {
    body = '<div class="cp-fld"><span class="cp-lb">Fechas</span><div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center">' + f.dates.slice().sort(function (a, b) { return a.fecha.localeCompare(b.fecha); }).map(function (x) {
      return '<span class="cp-fc" style="cursor:default">' + fDY(x.fecha) + (E ? '<button type="button" class="cp-ibx" style="width:22px;height:22px" data-a="rmdate" data-i="' + id + '" data-v="' + x.fecha + '" aria-label="Quitar ' + fDY(x.fecha) + '">' + ic('x', 12) + '</button>' : '') + '</span>';
    }).join('') + (E ? '<span style="width:170px">' + fecha('f:' + id + ':add', '', { ph: 'Agregar fecha', etiqueta: 'Agregar fecha' }) + '</span>' : '') + '</div>' + (f.dates.length ? '' : mc('', 'Agrega al menos una fecha.')) + '</div><div class="cp-grid3c">' + hourSel + '</div>';
  }
  if (f.t === 'med') {
    var um = unidadMedidor() || 'u.';
    var rows = F.activos.map(function (a) {
      var m = medNext(f, a);
      return '<div><span><b>' + esc(a.CODIGO) + '</b> <small>' + esc(a.NOMBRE) + '</small></span>' + (m ? '<small>Lectura ' + fN(a.MEDIDOR_VALOR) + ' ' + esc(a.MEDIDOR_UNIDAD || '') + '</small><b>al llegar a ' + fN(m) + ' ' + esc(a.MEDIDOR_UNIDAD || '') + '</b>' : '<small style="color:var(--amber)">Sin medidor</small><b style="color:var(--amber)">Nunca generará</b>') + '</div>';
    }).join('');
    body = '<div class="cp-grid3c"><div class="cp-fld"><label>Cada</label><div class="cp-unit">' + num('mn', f.mn, 1, 'Cada cuántas unidades') + '<span class="cp-u">' + esc(um) + '</span></div></div><div class="cp-fld"><label>Desde la lectura</label><div class="cp-unit">' + num('mstart', f.mstart, 0, 'Desde la lectura') + '<span class="cp-u">' + esc(um) + '</span></div></div><div class="cp-fld"><label>Avisar antes</label><div class="cp-unit">' + num('mwarn', f.mwarn, 0, 'Avisar antes') + '<span class="cp-u">' + esc(um) + '</span></div></div></div>' +
      '<div class="cp-fld"><span class="cp-lb">Medidor de cada activo del plan</span>' + (F.activos.length ? '<div class="cp-mtr">' + rows + '</div>' : mc('i', 'Agrega activos para ver cuándo se dispara en cada uno.')) + '</div>';
  }
  if (f.t === 'cond') body = '<div class="cp-shrd">' + ic('trend', 18) + '<div style="flex:1;min-width:0"><b style="font-size:13px">' + (f.ctext ? 'Cuando ' + esc(f.ctext) : 'Sin condición definida') + '</b><div style="font-size:12px;color:var(--muted)">Se dispara al registrar una medición que cumple la condición.</div></div>' + (E ? '<button type="button" class="cp-btn cp-out cp-xs" data-a="condpanel" data-i="' + id + '">Editar condición</button>' : '') + '</div>' + (f.ctext ? '' : mc('', 'Define la condición que dispara la intervención.'));
  var tolU = function (k, l) { return '<div class="cp-fld"><label>' + l + '</label><div class="cp-unit">' + num(k, f[k] || 0, 0, l) + '<span class="cp-u">días</span></div></div>'; };
  var vx = U.vp['exc' + i.CODIGO];
  var comun = f.t === 'med' || f.t === 'cond' ? '' :
    '<div class="cp-grid4c"><div class="cp-fld"><label>Vigente desde</label>' + fecha('f:' + id + ':from', f.from, { dis: !E, etiqueta: 'Vigente desde' }) + '</div><div class="cp-fld"><label>Hasta <small>opcional</small></label>' + fecha('f:' + id + ':to', f.to, { dis: !E, ph: 'Sin fin', etiqueta: 'Hasta', err: f.to && f.to < f.from }) + '</div>' + tolU('tb', 'Puede hacerse antes') + tolU('ta', 'Vence después de') + '</div>' +
    '<div class="cp-fld"><span class="cp-lb">Exclusiones <small>días en que no se programa</small></span><div class="cp-exc">' + f.excl.map(function (x, k) {
      return '<div class="cp-exr"><span><b>' + fDY(x.a) + ' – ' + fDY(x.b) + '</b> <small>· ' + esc(x.why) + '</small></span><span class="cp-tg">' + (x.shift ? 'Corre la fecha' : 'Omite la fecha') + '</span>' + (E ? '<button type="button" class="cp-ibx cp-dn" data-a="rmexc" data-i="' + id + '" data-v="' + k + '" aria-label="Quitar exclusión">' + ic('x', 14) + '</button>' : '<span></span>') + '</div>';
    }).join('') +
    (vx ? excForm(id, vx) : E ? '<button type="button" class="cp-btn cp-plain cp-xs" style="align-self:flex-start" data-a="addexc" data-i="' + id + '">' + ic('plus', 14) + 'Agregar exclusión</button>' : '') + '</div></div>';
  return '<div class="cp-blk' + (err ? ' cp-err' : '') + '" id="cpWhen' + id + '"><div class="cp-blk-h"><h4>Cuándo</h4><small>' + (f.t === 'med' ? 'Se dispara con las lecturas del medidor' : 'Las fechas se recalculan al guardar') + '</small><div class="cp-r">' + (E && (U.cat.calendarios || []).length ? '<button type="button" class="cp-lnk" data-a="useshared" data-i="' + id + '">' + ic('link', 14) + 'Usar calendario compartido</button>' : '') + '</div></div>' +
    '<div class="cp-fq-ed"><div class="cp-fq-f"><div class="cp-fld"><span class="cp-lb">Tipo</span>' + segT(f.t) + '</div>' + body + comun + (err && f.t !== 'cal' && f.t !== 'fec' ? mc('', esc(err)) : '') + '</div>' + pvHTML(i, f) + '</div></div>';
}
function medNext(f, a) {
  if (!a.MEDIDOR_ID) return null;
  var v = +a.MEDIDOR_VALOR || 0, s = +f.mstart || 0, c = +f.mn || 0; if (c <= 0) return null;
  var k = Math.max(1, Math.floor((v - s) / c) + 1); return s + k * c;
}
function excForm(id, v) {
  return '<div class="cp-exr" style="grid-template-columns:1fr;gap:10px;background:var(--surface-2)"><div class="cp-grid4c"><div class="cp-fld"><label>Desde</label>' + fecha('x:' + id + ':a', v.a, { etiqueta: 'Exclusión desde' }) + '</div><div class="cp-fld"><label>Hasta</label>' + fecha('x:' + id + ':b', v.b, { etiqueta: 'Exclusión hasta' }) + '</div><div class="cp-fld" style="grid-column:span 2"><label>Motivo</label><input class="cp-inp" data-xv="why" data-i="' + id + '" value="' + esc(v.why) + '" placeholder="Ej.: Parada de planta de fin de año" maxlength="300"></div></div>' +
    '<div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap"><div class="cp-segc">' + [[1, 'Correr la fecha al día siguiente'], [0, 'Omitir la fecha']].map(function (o) { return '<button type="button" data-a="xeff" data-i="' + id + '" data-v="' + o[0] + '" aria-pressed="' + (!!v.shift === !!o[0]) + '">' + o[1] + '</button>'; }).join('') + '</div><span style="flex:1"></span><button type="button" class="cp-btn cp-plain cp-xs" data-a="excx" data-i="' + id + '">Cancelar</button><button type="button" class="cp-btn cp-pri cp-xs" data-a="excok" data-i="' + id + '">Agregar</button></div>' +
    (v.err ? mc('', esc(v.err)) : '') + '</div>';
}
function pvHTML(i, f) {
  var list = '';
  if (f.t === 'med') list = F.activos.length ? F.activos.map(function (a) { var m = medNext(f, a); return m ? '<div class="cp-d">' + ic('gauge', 14) + '<span><b>' + esc(a.CODIGO) + '</b> al llegar a ' + fN(m) + ' ' + esc(a.MEDIDOR_UNIDAD || '') + '<small style="display:block;color:var(--muted)">Lectura actual ' + fN(a.MEDIDOR_VALOR) + '</small></span></div>' : '<div class="cp-d cp-x">' + ic('alert', 14) + '<span><s>' + esc(a.CODIGO) + '</s><small>Sin medidor: nunca generará</small></span></div>'; }).join('') : '<div class="cp-d cp-x"><span></span><span>Sin activos</span></div>';
  else if (f.t === 'cond') list = '<div class="cp-d">' + ic('trend', 14) + '<span>' + (f.ctext ? 'Cuando ' + esc(f.ctext) : 'Define la condición') + '</span></div>';
  else {
    var pend = !!U.fq[i.CODIGO];
    var ds = (i.FECHAS || []).filter(function (x) { return dIso(x.FECHA) >= TODAY; }).slice(0, 6);
    list = pend && fqError(f) ? '<div class="cp-d cp-x">' + ic('alert', 14) + '<span>Completa la frecuencia para ver las fechas</span></div>'
      : ds.length ? ds.map(function (x) {
        return x.DESCARTADA ? '<div class="cp-d cp-x">' + ic('x', 14) + '<span><s>' + fDL(x.FECHA) + '</s><small>Excluida: ' + esc(x.MOTIVO || '') + '</small></span></div>'
          : '<div class="cp-d' + (x.DESPLAZADA ? ' cp-sh' : '') + '">' + ic('check', 14) + '<span>' + fDL(x.FECHA) + (x.DESPLAZADA && x.FECHA_ORIGINAL ? '<small>Corrida desde el ' + fD(x.FECHA_ORIGINAL) + ' · ' + esc(x.MOTIVO || '') + '</small>' : '') + '</span></div>';
      }).join('') : '<div class="cp-d cp-x">' + ic('alert', 14) + '<span>Sin fechas próximas con esta configuración</span></div>';
  }
  var tol = f.t === 'med' || f.t === 'cond' ? (f.t === 'med' ? 'Avisa ' + fN(f.mwarn || 0) + ' antes.' : '') : 'Disponible desde ' + pl(+f.tb || 0, 'día', 'días') + ' antes · vence ' + pl(+f.ta || 0, 'día', 'días') + ' después.';
  return '<div class="cp-pv" id="cpPv' + i.HITO_ID + '" aria-live="polite"><h5>' + (f.t === 'med' ? 'Próximos disparos' : 'Próximas fechas') + '</h5><div class="cp-nl">' + esc(freqText(f, true, unidadMedidor())) + '</div>' + list + '<div class="cp-ft">' + tol + (F.activos.length > 1 && f.t !== 'med' ? ' Se repite en los ' + F.activos.length + ' activos.' : '') + '</div></div>';
}

/* ---- qué se hace (actividades) ---- */
function actsHTML(i, E) {
  var id = i.HITO_ID, acts = i.ACTIVIDADES || [], open = U.oa[i.CODIGO];
  var sumA = acts.reduce(function (t, a) { return t + (+a.DURACION || 0); }, 0);
  var dsum = acts.length ? '<div class="cp-dsum">' + ic('clock', 14) + '<span>Las actividades suman <b>' + fH(sumA) + '</b>; la intervención estima <b>' + fH(i.DURACION) + '</b>.</span>' + (Math.abs(sumA - (+i.DURACION || 0)) > 0.5 ? '<span class="cp-w">La OT usará ' + fH(i.DURACION) + '.</span>' : '') + '</div>' : '';
  return '<div class="cp-blk" id="cpActs' + id + '"><div class="cp-blk-h"><h4>Qué se hace</h4><small>Cada actividad es un paso de la OT</small><div class="cp-r">' + (E ? '<button type="button" class="cp-btn cp-out cp-xs" data-a="pickproc" data-i="' + id + '">' + ic('clip', 14) + 'Agregar desde procedimiento</button><button type="button" class="cp-btn cp-out cp-xs" data-a="addact" data-i="' + id + '">' + ic('plus', 14) + 'Agregar actividad</button>' : '') + '</div></div>' +
    (acts.length ? '<div class="cp-acts">' + acts.map(function (a, k) { return acHTML(i, a, k, E, open === a.CODIGO); }).join('') + '</div>' + dsum
      : '<div class="cp-empty" style="padding:16px">' + ic('wrench', 18) + '<span>Sin actividades, la OT tendrá un solo paso: «' + esc(i.NOMBRE) + '». Agrega actividades para guiar al técnico.</span></div>') + '</div>';
}
function acHTML(i, a, k, E, open) {
  var id = a.ACTIVIDAD_ID, dis = E ? '' : ' disabled', acts = i.ACTIVIDADES;
  var permOn = a.PERMISO || U.pend['perm' + i.CODIGO + a.CODIGO], permErr = !!U.pend['perm' + i.CODIGO + a.CODIGO];
  var pasos = U.vp['st' + i.CODIGO + a.CODIGO];
  var nombre = String(a.NOMBRE || '').trim();
  return '<div class="cp-ac' + (open ? ' cp-open' : '') + '" data-ac="' + id + '">' +
    '<div class="cp-ac-h" data-a="toggleact" data-i="' + i.HITO_ID + '" data-c="' + id + '" role="button" tabindex="0" aria-expanded="' + open + '">' +
    '<span class="cp-gr" aria-hidden="true">' + ic('dots', 15) + '</span><code>' + esc(a.CODIGO) + '</code>' +
    '<div class="cp-nm"><b>' + (nombre ? esc(nombre) : '<span style="color:var(--red)">Sin nombre</span>') + '</b><small>' + (a.PROCEDIMIENTO_ID ? '<span class="cp-tg cp-p">' + ic('clip', 11) + esc(a.PROCEDIMIENTO_CODIGO || '') + ' v' + (a.PROCEDIMIENTO_VERSION || 1) + ' · ' + pl(+a.PASOS || 0, 'paso', 'pasos') + '</span>' : '<span>Sin procedimiento</span>') + ((a.REPUESTOS || []).length ? '<span>· ' + pl(a.REPUESTOS.length, 'repuesto', 'repuestos') + '</span>' : '') + '</small></div>' +
    '<span class="cp-du">' + (a.DURACION ? fH(a.DURACION) : '—') + '</span>' +
    '<span class="cp-fl">' + (a.OBLIGATORIA ? '' : '<span class="cp-tg">Opcional</span>') + (a.PARADA ? '<span class="cp-tg cp-w">Parada</span>' : '') + (permOn ? '<span class="cp-tg' + (permErr ? ' cp-w' : '') + '">' + (permErr ? ic('alert', 11) : '') + 'Permiso</span>' : '') + '</span>' +
    '<span class="cp-chev" style="color:var(--muted);transition:transform .2s;' + (open ? 'transform:rotate(90deg)' : '') + '">' + ic('chev', 15) + '</span></div>' +
    (open ? '<div class="cp-ac-b">' +
      '<div class="cp-grid3c"><div class="cp-fld" style="grid-column:span 2"><label>Nombre</label><input class="cp-inp' + (nombre ? '' : ' cp-err') + '" data-act="nombre" data-c="' + id + '" value="' + esc(a.NOMBRE) + '"' + dis + ' maxlength="200">' + (nombre ? '' : mc('', 'La actividad necesita un nombre.')) + '</div><div class="cp-fld"><label>Duración</label><div class="cp-unit"><input class="cp-inp" type="number" min="0.25" step="0.25" data-act="duracion" data-c="' + id + '" value="' + (a.DURACION ? hrs(a.DURACION) : '') + '"' + dis + '><span class="cp-u">horas</span></div></div></div>' +
      '<div style="display:flex;gap:18px;flex-wrap:wrap"><label class="cp-sw" title="Sin resultado no deja cerrar la OT"><input type="checkbox" data-act="obligatoria" data-c="' + id + '"' + (a.OBLIGATORIA ? ' checked' : '') + dis + '><i></i>Obligatoria</label><label class="cp-sw"><input type="checkbox" data-act="parada" data-c="' + id + '"' + (a.PARADA ? ' checked' : '') + dis + '><i></i>Requiere parada</label><label class="cp-sw"><input type="checkbox" data-act="permisoOn" data-c="' + id + '"' + (permOn ? ' checked' : '') + dis + '><i></i>Requiere permiso de trabajo</label></div>' +
      (permOn ? '<div class="cp-grid2c"><div class="cp-fld"><label>Tipo de permiso</label>' + combo('cpAcPerm' + id, catL('permisos'), a.PERMISO_TIPO_ID || '', { etiqueta: 'Tipo de permiso', ph: 'Elige el tipo', err: permErr, dis: !E, data: ' data-act="permiso" data-c="' + id + '"', clave: 'cpPermisos' }) + (permErr ? mc('', 'Indica el tipo de permiso: la OT lo exigirá antes de empezar.') : '') + '</div></div>' : '') +
      '<div class="cp-fld"><label>Descripción <small>opcional</small></label><textarea class="cp-inp" rows="2" data-act="descripcion" data-c="' + id + '"' + dis + ' placeholder="Instrucciones breves para el técnico">' + esc(a.DESCRIPCION || '') + '</textarea></div>' +
      '<div class="cp-fld"><span class="cp-lb">Procedimiento</span>' + (a.PROCEDIMIENTO_ID
        ? '<div class="cp-prc"><span class="cp-pci">' + ic('clip', 17) + '</span><div style="min-width:0"><b>' + esc(a.PROCEDIMIENTO_CODIGO || '') + ' v' + (a.PROCEDIMIENTO_VERSION || 1) + ' · ' + esc(a.PROCEDIMIENTO || '') + '</b><small>' + pl(+a.PASOS || 0, 'paso', 'pasos') + '</small></div><div class="cp-r"><button type="button" class="cp-btn cp-plain cp-xs" data-a="vsteps" data-c="' + id + '" data-pr="' + a.PROCEDIMIENTO_ID + '">' + (pasos ? 'Ocultar pasos' : 'Ver pasos') + '</button>' + (E ? '<button type="button" class="cp-btn cp-plain cp-xs" data-a="pickproc" data-i="' + i.HITO_ID + '" data-c="' + id + '">Cambiar</button><button type="button" class="cp-ibx cp-dn" data-a="rmproc" data-c="' + id + '" aria-label="Quitar procedimiento">' + ic('x', 14) + '</button>' : '') + '</div></div>' +
          (pasos ? (pasos === 'cargando' ? '<div class="cp-sk" style="height:60px;margin-top:6px"></div>' : '<ol style="margin:6px 0 0;padding-left:20px;font-size:12.5px;color:var(--ink-2);display:flex;flex-direction:column;gap:4px">' + pasos.map(function (s) { return '<li>' + esc(s.n) + (s.ctrl ? ' <span class="cp-tg cp-p">Control</span>' : '') + (s.med ? ' <span class="cp-tg cp-c">Medición</span>' : '') + (s.ev ? ' <span class="cp-tg">Evidencia</span>' : '') + '</li>'; }).join('') + '</ol><p class="cp-msg cp-i" style="margin-top:6px">' + ic('help', 13) + '<span>Al generar la OT, cada paso se copia: si cambias el procedimiento después, las OT ya generadas no cambian.</span></p>') : '')
        : E ? '<div style="display:flex;gap:8px;flex-wrap:wrap"><button type="button" class="cp-btn cp-out cp-xs" data-a="pickproc" data-i="' + i.HITO_ID + '" data-c="' + id + '">' + ic('search', 14) + 'Elegir procedimiento</button></div>' : '<span style="font-size:12.5px;color:var(--muted)">Sin procedimiento</span>') + '</div>' +
      '<div class="cp-fld"><span class="cp-lb">Repuestos planificados</span><div class="cp-reps">' + (a.REPUESTOS || []).map(function (r) {
        return '<div class="cp-rp"><span><b style="font-weight:600">' + esc(r.NOMBRE) + '</b> <code>' + esc(r.CODIGO) + '</code></span><input class="cp-inp" type="number" min="0" step="any" data-rq="' + r.ID + '" data-c="' + id + '" data-rep="' + r.REPUESTO_ID + '" value="' + (+r.CANTIDAD) + '"' + dis + ' aria-label="Cantidad"><span class="cp-un" style="color:var(--muted)">' + esc(r.UNIDAD || '') + '</span>' + (E ? '<button type="button" class="cp-ibx cp-dn" data-a="rmrep" data-v="' + r.ID + '" aria-label="Quitar repuesto">' + ic('x', 14) + '</button>' : '<span></span>') + '</div>';
      }).join('') +
      (E ? '<label class="cp-srch2" style="height:34px;max-width:360px">' + ic('plus', 14) + '<input data-repq="' + id + '" placeholder="Agregar repuesto: busca por nombre o código" aria-label="Agregar repuesto" autocomplete="off" aria-haspopup="listbox"></label>' : '') + (!(a.REPUESTOS || []).length && !E ? '<span style="font-size:12.5px;color:var(--muted)">Sin repuestos</span>' : '') + '</div></div>' +
      (E ? '<div style="display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap"><span style="display:flex;gap:6px"><button type="button" class="cp-btn cp-plain cp-xs" data-a="mvact" data-i="' + i.HITO_ID + '" data-c="' + id + '" data-v="-1"' + (k === 0 ? ' disabled' : '') + '>Subir</button><button type="button" class="cp-btn cp-plain cp-xs" data-a="mvact" data-i="' + i.HITO_ID + '" data-c="' + id + '" data-v="1"' + (k === acts.length - 1 ? ' disabled' : '') + '>Bajar</button></span><button type="button" class="cp-btn cp-dano cp-xs" data-a="rmact" data-c="' + id + '">' + ic('x', 14) + 'Quitar actividad</button></div>' : '') +
      '</div>' : '') + '</div>';
}

/* ---- 3 · próximas ejecuciones · 4 · OT generadas · 5 · historial ---- */
var SIT = { VENCIDA: ['venc', 'Vencida'], ATRASADA: ['atr', 'Atrasada'], DISPONIBLE: ['disp', 'Disponible'], FUTURA: ['fut', 'Futura'] };
function nextHTML() {
  var e = estado(F.plan)[0], draft = e === 'draft';
  var list = draft ? (F.proyeccion || []).slice(0, 10) : e === 'inactive' ? [] : (F.proximas || []);
  var g = 'grid-template-columns:130px minmax(0,1fr) minmax(0,1fr) 150px 80px';
  return '<section class="cp-sc" id="cpSecNext"><div class="cp-sc-h"><span class="cp-n">3</span><h3>Próximas ejecuciones</h3><small>' + (draft ? 'Proyección: se generarán al activar' : e === 'inactive' ? 'El plan está inactivo' : 'Lo que SIGMA ya programó') + '</small><div class="cp-r">' + (!draft && e !== 'inactive' ? '<button type="button" class="cp-btn cp-out cp-xs" data-a="tab" data-t="ejecuciones" data-fp="' + F.plan.PLAN_ID + '" data-ff="all">Ver todas en Ejecuciones</button>' : '') + '</div></div>' +
    (list.length ? '<div class="cp-rows"><div class="cp-rw cp-h" style="' + g + '"><span>Fecha</span><span>Activo</span><span>Intervención</span><span>Situación</span><span>OT</span></div>' + list.map(function (x) {
      var s = x.OT_ID ? '<span class="cp-st cp-ot-a"><i></i>Con OT</span>' : draft ? '<span class="cp-st cp-proj"><i></i>Proyección</span>' : '<span class="cp-st cp-' + (SIT[x.SITUACION] || SIT.FUTURA)[0] + '"><i></i>' + (SIT[x.SITUACION] || SIT.FUTURA)[1] + '</span>';
      var clic = !draft && x.TOKEN;
      return '<div class="cp-rw' + (clic ? ' cp-click' : '') + '" style="' + g + '"' + (clic ? ' data-a="exopen" data-k="' + esc(x.TOKEN) + '" role="button" tabindex="0"' : '') + '><span class="cp-dt"><b>' + fD(x.FECHA) + '</b><small>' + rel(dIso(x.FECHA)) + '</small></span><span class="cp-s"><b>' + esc(x.ACTIVO) + '</b><small>' + esc(x.ACTIVO_CODIGO) + '</small></span><span class="cp-s"><b>' + esc(x.HITO) + '</b><small>' + esc(x.HITO_CODIGO) + '</small></span><span>' + s + '</span><span class="cp-mono">' + (x.OT_ID ? (x.OT_URL ? '<a href="' + esc(x.OT_URL) + '" target="_blank" rel="noopener">' + esc(x.OT_NUMERO) + '</a>' : esc(x.OT_NUMERO)) : '—') + '</span></div>';
    }).join('') + '</div>'
      : '<div class="cp-empty" style="padding:18px">' + (e === 'inactive' ? 'Al reactivar el plan, SIGMA vuelve a programar las ejecuciones.' : draft ? 'Completa la frecuencia y los activos para ver la proyección.' : 'Sin ejecuciones pendientes en los próximos 90 días.') + '</div>') + '</section>';
}
var OTG = { open: ['ABIERTA', 'EN EJECUCION'], wait: ['EN ESPERA DE CIERRE'], done: ['CERRADA'] };
var OTC = { ABIERTA: 'cp-ot-a', 'EN EJECUCION': 'cp-ot-e', 'EN ESPERA DE CIERRE': 'cp-ot-w', CERRADA: 'cp-ot-c' };
function otHTML() {
  var all = F.ots || [], grp = {};
  Object.keys(OTG).forEach(function (k) { grp[k] = all.filter(function (o) { return OTG[k].indexOf(o.ESTADO_CODIGO) >= 0; }); });
  var list = (grp[U.otf] || []).slice(0, 8), g = 'grid-template-columns:76px minmax(0,1fr) minmax(0,1fr) 100px 170px 34px 96px';
  return '<section class="cp-sc" id="cpSecOt"><div class="cp-sc-h"><span class="cp-n">4</span><h3>OT generadas</h3><small>' + pl(all.length, 'orden de trabajo', 'órdenes de trabajo') + '</small><div class="cp-r">' + (all.length ? '<a class="cp-btn cp-out cp-xs" href="' + CFG.base_ + 'View/Mantenimiento/Ordenes/OrdenTrabajos.aspx?plan=' + F.plan.Q + '" target="_blank" rel="noopener">Ver en Órdenes de trabajo</a>' : '') + '</div></div>' +
    (all.length ? '<div class="cp-chips" style="margin-bottom:10px">' + [['open', 'Abiertas'], ['wait', 'En espera de cierre'], ['done', 'Cerradas']].map(function (x) { return '<button type="button" class="cp-fc" data-a="otf" data-v="' + x[0] + '" aria-pressed="' + (U.otf === x[0]) + '">' + x[1] + '<b>' + grp[x[0]].length + '</b></button>'; }).join('') + '</div>' +
      (list.length ? '<div class="cp-rows">' + list.map(function (o) {
        return '<div class="cp-rw" style="' + g + '"><span class="cp-mono">' + esc(o.NUMERO) + '</span><span class="cp-s"><b>' + esc(o.ACTIVO) + '</b><small>' + esc(o.ACTIVO_CODIGO) + '</small></span><span class="cp-s"><b>' + esc(o.HITO) + '</b><small>' + esc(o.TITULO || '') + '</small></span><span class="cp-dt"><b>' + (o.FECHA ? fD(o.FECHA) : '—') + '</b></span><span><span class="cp-st ' + (OTC[o.ESTADO_CODIGO] || 'cp-ot-a') + '"><i></i>' + esc(o.ESTADO) + '</span></span><span>' + avatar(o.RESPONSABLE) + '</span><a class="cp-btn cp-out cp-xs" href="' + esc(o.URL) + '" target="_blank" rel="noopener">Abrir OT</a></div>';
      }).join('') + '</div>' : '<div class="cp-empty" style="padding:16px">Ninguna OT en este estado.</div>')
      : '<div class="cp-empty" style="padding:18px">' + (estado(F.plan)[0] === 'draft' ? 'Este plan todavía no genera OT. Al activarlo, las ejecuciones aparecerán en Ejecuciones y desde ahí se generan las OT.' : 'Aún no se generaron OT de este plan.') + '</div>') + '</section>';
}
function histHTML() {
  var g = 'grid-template-columns:60px 130px 170px minmax(0,1fr)';
  var V = { BORRADOR: ['changes', 'Borrador'], PUBLICADO: ['active', 'Activa'], RETIRADO: ['inactive', 'Retirada'] };
  var p = F.plan;
  return '<section class="cp-sc" id="cpSecHist"><div class="cp-sc-h"><span class="cp-n">5</span><h3>Historial</h3><small>Solo lectura</small></div>' +
    '<div class="cp-rows">' + (F.versiones || []).map(function (v) {
      var st = V[v.ESTADO_CODIGO] || V.RETIRADO, cuando = v.PUBLICADA || v.CREADA, quien = v.PUBLICADA ? v.PUBLICADA_POR : v.CREADA_POR;
      var nota = v.ESTADO_CODIGO === 'BORRADOR' && estado(p)[0] === 'changes' ? 'Cambios sin aplicar (' + (+p.CAMBIOS || 0) + ')' : [v.OBSERVACION, v.MOTIVO_RETIRO ? 'Retirada: ' + v.MOTIVO_RETIRO : ''].filter(Boolean).join(' · ');
      return '<div class="cp-rw" style="' + g + '"><span class="cp-mono">v' + v.NUMERO + '</span><span><span class="cp-st cp-' + st[0] + '"><i></i>' + st[1] + '</span></span><span class="cp-dt"><b>' + fDN(cuando) + '</b><small>' + esc(quien || '') + '</small></span><span style="color:var(--ink-2)">' + esc(nota) + '<small style="display:block;color:var(--muted)">' + pl(+v.INTERVENCIONES || 0, 'intervención', 'intervenciones') + ' · ' + pl(+v.ACTIVOS || 0, 'activo', 'activos') + (v.EJECUCIONES ? ' · ' + pl(+v.EJECUCIONES, 'ejecución', 'ejecuciones') : '') + '</small></span></div>';
    }).join('') + '</div>' +
    '<p style="font-size:11.5px;color:var(--muted);margin-top:10px">Creado por ' + esc(p.CREADO_POR || '—') + ' el ' + fDN(p.CREADO_EL) + (p.MODIFICADO_EL ? ' · última modificación ' + fDN(p.MODIFICADO_EL) + ' por ' + esc(p.MODIFICADO_POR || '') : '') + '</p></section>';
}

function imp4(im) {
  var n = function (x) { return x == null ? '…' : x; };
  return '<div class="cp-imp4"><div class="cp-t"><b class="cp-tn">' + n(im.TRASPASAN) + '</b><span>Se mantienen</span><small>pasan a la versión nueva</small></div><div class="cp-n"><b class="cp-tn">' + n(im.CREAN) + '</b><span>Se crean</span><small>fechas nuevas</small></div><div class="cp-c"><b class="cp-tn">' + n(im.CANCELAN) + '</b><span>Se cancelan</span><small>ya no corresponden</small></div><div><b class="cp-tn">' + n(im.CON_OT) + '</b><span>Con OT</span><small>no se tocan</small></div></div>' +
    (+im.REABREN ? '<p class="cp-msg cp-i">' + ic('help', 13) + '<span>' + pl(+im.REABREN, 'ejecución cancelada vuelve', 'ejecuciones canceladas vuelven') + ' a quedar pendiente' + (+im.REABREN === 1 ? '' : 's') + '.</span></p>' : '');
}

/* =====================================================================
   Escrituras: una cola, el indicador de guardado y la ficha al día
   ===================================================================== */
var cola = Promise.resolve();
var hById = function (id) { return F ? F.intervenciones.filter(function (h) { return h.HITO_ID === +id; })[0] : null; };
var aById = function (id) { var r = null; (F ? F.intervenciones : []).forEach(function (h) { (h.ACTIVIDADES || []).forEach(function (a) { if (a.ACTIVIDAD_ID === +id) r = { h: h, a: a }; }); }); return r; };

/* Toda escritura pasa por aquí, de a una: el servidor abre el borrador en
   la primera y las siguientes ya lo encuentran. Después se pide la ficha
   de nuevo: el estado (Activo → con cambios), los ids del borrador, el
   conteo de cambios y las fechas los decide la base. */
function escribir(metodo, datos, o) {
  o = o || {};
  if (U.plan) delete U.flash[U.plan];
  guardando();
  var pr = cola.then(function () { return api(metodo, datos); }).then(function (r) {
    guardado();
    if (o.sinFicha) return r;
    return recargarFicha().then(function () { recargarLista(); return r; });
  }, function (e) {
    noGuardado(e.message);
    if (e.sesion) toastError(e);
    throw e;
  });
  cola = pr.catch(function () { });
  return pr;
}
function recargarFicha() {
  if (!U.plan) return Promise.resolve();
  var id = U.plan;
  return api('Ficha', { plan: id }).then(function (r) {
    if (U.plan !== id) return;
    F = r; U.permisos = r.permisos || U.permisos;
    render();
    if (F.plan.ESTADO !== 'INACTIVO') api('Impacto', { plan: id }).then(function (im) { if (U.plan === id) { U.imp = im; if (U.step[id] === 5) render(); } }).catch(function () { });
  });
}
function recargarLista() {
  return api('Lista', { planta: U.planta }).then(function (r) {
    U.lista = r.planes; U.conteos = r.conteos; U.permisos = r.permisos || U.permisos;
    if (U.tab === 'planes') { var b = $('#cpPlb'); if (b) { var st = b.scrollTop; var l = $('.cp-plist'); if (l) { l.outerHTML = listHTML(); var nb = $('#cpPlb'); if (nb) nb.scrollTop = st; } } }
    $('#cpTabs').innerHTML = tabsHTML();
  });
}
function recargarKpis() {
  return p360('kpis').then(function (k) { U.kpis = k; $('#cpKpis').innerHTML = kpisHTML(); $('#cpTabs').innerHTML = tabsHTML(); }).catch(function () { });
}
function abrirPlan(id, o) {
  o = o || {};
  if (U.plan !== id) { F = null; U.imp = null; U.vp = {}; U.pend = {}; U.fq = {}; }
  U.plan = id; U.tab = 'planes';
  if (o.paso) U.step[id] = o.paso;
  render(); hashOut();
  return recargarFicha().then(function () { if (o.top !== false && matchMedia('(max-width:1100px)').matches) window.scrollTo(0, 0); }).catch(toastError);
}

/* =====================================================================
   Pintar: foco, lo escrito y el scroll sobreviven al repintado
   ===================================================================== */
var FKEYS = ['pf', 'iv', 'act', 'fk', 'fe', 'xv', 'xp', 'rq', 'repq', 'pv', 'pp', 'mv', 'ppv'];
function grabFocus(root) {
  var a = document.activeElement; if (!a || !root || !root.contains(a) || a === document.body) return null;
  var sel = null, cb = a.closest('[data-cb]');
  if (cb) sel = '[data-cb="' + cb.getAttribute('data-cb') + '"] input[type=text]';
  else if (a.id) sel = '#' + CSS.escape(a.id);
  else for (var k = 0; k < FKEYS.length; k++) {
    var key = FKEYS[k], v = a.getAttribute('data-' + key);
    if (v != null) { sel = '[data-' + key + '="' + CSS.escape(v) + '"]'; ['i', 'c'].forEach(function (x) { var w = a.getAttribute('data-' + x); if (w != null) sel += '[data-' + x + '="' + CSS.escape(w) + '"]'; }); break; }
  }
  if (!sel && a.getAttribute('data-a')) { sel = '[data-a="' + a.getAttribute('data-a') + '"]'; ['i', 'c', 'v', 'p', 't', 'k'].forEach(function (x) { var w = a.getAttribute('data-' + x); if (w != null) sel += '[data-' + x + '="' + CSS.escape(w) + '"]'; }); }
  var s = null, e = null; try { s = a.selectionStart; e = a.selectionEnd; } catch (er) { }
  return sel ? { sel: sel, s: s, e: e, v: (a.tagName === 'INPUT' && a.type !== 'checkbox') || a.tagName === 'TEXTAREA' ? a.value : null, cb: !!cb } : null;
}
function putFocus(fo, root) {
  if (!fo || !root) return; var el = root.querySelector(fo.sel); if (!el) return;
  if (fo.v != null && !fo.cb && el.value !== fo.v) el.value = fo.v;
  el.focus({ preventScroll: true });
  try { if (fo.s != null) el.setSelectionRange(fo.s, fo.e); } catch (er) { }
}
var TABR = {};   // las otras pestañas se registran aquí (bloques C y D)
function cuerpoHTML() {
  if (U.tab === 'planes') return U.plan ? fichaHTML() : '<div class="cp-ws">' + listHTML() + '</div>';
  var t = TABR[U.tab];
  return t ? t.html() : '<div class="cp-card" style="padding:24px">Esta pestaña se habilita en el siguiente bloque.</div>';
}
function render() {
  var body = $('#cpBody'); if (!body) return;
  var fo = grabFocus(body), plb = $('#cpPlb'), ps = plb ? plb.scrollTop : 0, sy = window.scrollY;
  body.innerHTML = U.cargando ? skel() : cuerpoHTML();
  var nb = $('#cpPlb'); if (nb) nb.scrollTop = ps;
  putFocus(fo, body);
  if (Math.abs(window.scrollY - sy) > 2) window.scrollTo(0, sy);
  pintarGuardado();
  conectarFechas(body);
  $$('#cpTabs [role=tab]').forEach(function (b) { var on = b.getAttribute('data-t') === U.tab; b.setAttribute('aria-selected', on); b.tabIndex = on ? 0 : -1; });
  if (U.tab !== 'planes' && TABR[U.tab] && TABR[U.tab].despues) TABR[U.tab].despues();
}
function skel() { return '<div class="cp-card" style="display:flex;flex-direction:column;gap:12px" aria-busy="true" aria-label="Cargando"><div class="cp-sk" style="height:34px;width:46%"></div>' + [0, 1, 2, 3, 4].map(function (k) { return '<div style="display:grid;grid-template-columns:110px 1fr 1fr 120px;gap:14px"><div class="cp-sk" style="height:30px"></div><div class="cp-sk" style="height:30px"></div><div class="cp-sk" style="height:30px;width:' + (70 + (k * 7) % 30) + '%"></div><div class="cp-sk" style="height:24px"></div></div>'; }).join('') + '</div>'; }
function goEl(sel, focusSel) {
  var el = typeof sel === 'string' ? $(sel) : sel; if (!el) return;
  el.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'center' });
  el.classList.remove('cp-flashb'); void el.offsetWidth; el.classList.add('cp-flashb');
  if (focusSel) { var f = el.querySelector(focusSel); if (f) setTimeout(function () { f.focus({ preventScroll: true }); }, 350); }
}
function switchTab(t, extra) {
  if (!TABS.some(function (x) { return x[0] === t; })) t = 'planes';
  U.tab = t; cerrarPop();
  if (TABR[t] && TABR[t].entrar) { TABR[t].entrar(extra || {}); }
  render(); hashOut();
}

/* ---- la URL: #tab=planes&plan=<id cifrado> ---- */
function hashOut() {
  var h = 'tab=' + U.tab;
  if (U.tab === 'planes' && U.plan && U.lista) { var p = U.lista.filter(function (x) { return x.PLAN_ID === U.plan; })[0]; if (p) h += '&plan=' + p.Q + (U.step[U.plan] ? '&paso=' + U.step[U.plan] : ''); }
  if (U.tab === 'biblioteca' && U.lib.v) h += '&lib=' + U.lib.v;
  try { history.replaceState(null, '', '#' + h); } catch (e) { }
}
function hashIn() {
  var o = {}; String(location.hash || '').replace(/^#/, '').split('&').forEach(function (kv) { var i = kv.indexOf('='); if (i > 0) o[kv.slice(0, i)] = kv.slice(i + 1); });
  return o;
}
var mismoQ = function (a, b) { try { return decodeURIComponent(a) === decodeURIComponent(b); } catch (e) { return a === b; } };

/* =====================================================================
   Paneles laterales
   ===================================================================== */
var PANELS = {};
function openPanel(o) { PN = o; cerrarPop(); panel(); setTimeout(function () { var f = $('#cpLayer [data-autofocus]') || $('#cpLayer .cp-pnl-h .cp-ibx'); if (f) f.focus(); }, 30); }
function closePanel() { PN = null; $('#cpLayer').innerHTML = ''; }
function panel() {
  var L = $('#cpLayer'); if (!PN) { L.innerHTML = ''; return; }
  var fo = grabFocus(L), sb = $('#cpLayer .cp-pnl-b'), st = sb ? sb.scrollTop : 0;
  var r = PANELS[PN.t]();
  var inner = '<div class="cp-pnl-h"><div class="cp-t">' + (r.s ? '<small>' + r.s + '</small>' : '') + '<h3 id="cpPnlT">' + r.t + '</h3></div><button type="button" class="cp-ibx" data-a="pclose" aria-label="Cerrar panel">' + ic('x', 18) + '</button></div><div class="cp-pnl-b">' + r.b + '</div>' + (r.f ? '<div class="cp-pnl-f">' + r.f + '</div>' : '');
  var ex = $('#cpLayer .cp-pnl');
  if (ex) { ex.className = 'cp-pnl ' + (r.w ? 'cp-' + r.w : ''); ex.innerHTML = inner; }   // el cajón y su animación de entrada se conservan
  else L.innerHTML = '<div class="cp-scr" data-a="pclose"></div><aside class="cp-pnl ' + (r.w ? 'cp-' + r.w : '') + '" role="dialog" aria-modal="true" aria-labelledby="cpPnlT">' + inner + '</aside>';
  var nb = $('#cpLayer .cp-pnl-b'); if (nb) nb.scrollTop = st;
  putFocus(fo, L); conectarFechas(L);
}

/* ---- agregar activos (CA-07: resultado por fila) ---- */
PANELS.addeq = function () {
  var p = F.plan, ttl = 'Agregar activos', sub = esc(p.CODIGO) + ' · ' + esc(p.NOMBRE);
  if (PN.res) {
    var ok = PN.res.filter(function (r) { return r.ok; }).length;
    return { t: ttl, s: sub, b: '<div class="cp-bnr cp-' + (ok === PN.res.length ? 'ok' : 'w') + '">' + ic(ok === PN.res.length ? 'check' : 'alert', 18) + '<span><b>' + ok + ' de ' + PN.res.length + '</b> ' + (ok === 1 ? 'activo agregado' : 'activos agregados') + ' al plan.</span></div><div class="cp-res">' + PN.res.map(function (r) { var a = (PN.lista || []).filter(function (x) { return x.ACTIVO_ID === r.activo; })[0] || {}; return '<div class="cp-' + (r.ok ? 'ok' : 'no') + '">' + ic(r.ok ? 'check' : 'x', 15) + '<span><b>' + esc(a.CODIGO || r.activo) + '</b> · ' + esc(a.NOMBRE || '') + '<small style="display:block;color:' + (r.ok ? 'var(--muted)' : 'var(--red)') + '">' + esc(r.ok ? (a.PLANES ? 'Agregado · también está en ' + a.PLANES_CODIGOS : 'Agregado') : r.detalle) + '</small></span><span></span></div>'; }).join('') + '</div>', f: '<span class="cp-r"><button type="button" class="cp-btn cp-pri" data-a="pclose">Listo</button></span>' };
  }
  if (!PN.lista) return { t: ttl, s: sub, b: '<div class="cp-sk" style="height:40px"></div><div class="cp-sk" style="height:300px"></div>' };
  var q = nrm(PN.q), pool = PN.lista.filter(function (a) { return !a.YA_EN_PLAN && (!q || nrm(a.CODIGO + ' ' + a.NOMBRE + ' ' + (a.AREA || '') + ' ' + (a.TIPO || '')).indexOf(q) >= 0) && (!PN.fa || a.AREA === PN.fa); });
  var ok2 = pool.filter(function (a) { return !a.MOTIVO; }), no = pool.filter(function (a) { return a.MOTIVO; });
  var areas = {}; PN.lista.forEach(function (a) { if (a.AREA) areas[a.AREA] = 1; });
  var n = Object.keys(PN.sel).length;
  var row = function (a) {
    var s = PN.sel[a.ACTIVO_ID], comps = (PN.comp || []).filter(function (c) { return c.ACTIVO_ID === a.ACTIVO_ID; }), meds = (PN.med || []).filter(function (m) { return m.ACTIVO_ID === a.ACTIVO_ID; });
    return '<div class="cp-pk-r' + (a.MOTIVO ? ' cp-dis' : '') + '"><input type="checkbox" class="cp-cbx" data-a="eqpick" data-v="' + a.ACTIVO_ID + '"' + (s ? ' checked' : '') + (a.MOTIVO ? ' disabled' : '') + ' aria-label="Elegir ' + esc(a.CODIGO) + '"><span class="cp-ph2">' + ic('cog', 18) + '</span><span class="cp-s"><b>' + esc(a.NOMBRE) + '</b><small>' + esc(a.CODIGO) + (a.AREA ? ' · ' + esc(a.AREA) : '') + (a.MODELO ? ' · ' + esc(a.MODELO) : a.TIPO ? ' · ' + esc(a.TIPO) : '') + '</small></span><span style="text-align:right">' + (a.MOTIVO ? '<span class="cp-tg">' + esc(a.MOTIVO) + '</span>' : a.PLANES ? '<span class="cp-tg cp-w" title="' + esc(a.PLANES_CODIGOS) + '">En ' + pl(+a.PLANES, 'plan', 'planes') + '</span>' : '<span class="cp-tg cp-c">Sin plan</span>') + '</span>' +
      (s && (comps.length || meds.length) ? '<div class="cp-eqo">' + combo('cpEqComp' + a.ACTIVO_ID, [{ id: '', n: 'Activo completo' }].concat(comps.map(function (c) { return { id: c.ID, n: c.NOMBRE }; })), s.componente || '', { etiqueta: 'Componente', ph: 'Activo completo', data: ' data-pq="componente" data-v="' + a.ACTIVO_ID + '"' }) + combo('cpEqMed' + a.ACTIVO_ID, meds.length ? meds.map(function (m) { return { id: m.ID, n: m.NOMBRE + ' · ' + fN(m.VALOR) + ' ' + (m.UNIDAD || '') }; }) : [{ id: '', n: 'Sin medidor' }], s.medidor || (meds[0] ? meds[0].ID : ''), { etiqueta: 'Medidor', dis: !meds.length, data: ' data-pq="medidor" data-v="' + a.ACTIVO_ID + '"' }) + '</div>' : '') + '</div>';
  };
  return { t: ttl, s: sub,
    b: '<div class="cp-bnr cp-i">' + ic('help', 18) + '<span>Filtrado por el alcance del plan: <b>' + esc(p.PLANTA || 'Cualquier planta') + (p.TIPO ? ' · ' + esc(p.TIPO) : '') + (p.MODELO ? ' · ' + esc(p.MODELO) : '') + '</b>. Los que no calzan aparecen al final, deshabilitados.</span></div>' +
      '<div style="display:flex;gap:8px;flex-wrap:wrap"><label class="cp-srch2" style="flex:1;min-width:200px">' + ic('search', 14) + '<input data-pv="q" value="' + esc(PN.q) + '" placeholder="Código, nombre o área" aria-label="Buscar activos" data-autofocus="1" autocomplete="off"></label><span style="width:200px">' + combo('cpEqArea', [{ id: '', n: 'Todas las áreas' }].concat(Object.keys(areas).sort().map(function (x) { return { id: x, n: x }; })), PN.fa, { etiqueta: 'Área', ph: 'Todas las áreas', data: ' data-pq="area"' }) + '</span></div>' +
      (ok2.length ? '<div style="display:flex;align-items:center;gap:8px;font-size:12px;color:var(--muted)"><input type="checkbox" class="cp-cbx" data-a="eqall"' + (ok2.every(function (a) { return PN.sel[a.ACTIVO_ID]; }) ? ' checked' : '') + ' aria-label="Elegir todos"><span>Elegir los ' + ok2.length + ' que calzan con el alcance</span></div>' : '') +
      '<div class="cp-pk">' + ok2.map(row).join('') + no.map(row).join('') + (!pool.length ? '<div class="cp-empty" style="border:0">Ningún activo coincide.</div>' : '') + '</div>',
    f: '<span style="font-size:12.5px;color:var(--muted)">' + (n ? '<b style="color:var(--ink)">' + n + '</b> ' + (n === 1 ? 'elegido' : 'elegidos') : 'Elige uno o varios') + '</span><span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><button type="button" class="cp-btn cp-pri" data-a="eqok"' + (n ? '' : ' disabled') + '>' + ic('plus', 16) + 'Agregar ' + (n || '') + ' ' + (n === 1 ? 'activo' : 'activos') + '</button></span>' };
};

/* ---- elegir procedimiento ---- */
PANELS.pick = function () {
  var q = nrm(PN.q), list = (PN.lista || []).filter(function (x) { return !q || nrm(x.PRC_CODIGO + ' ' + x.PRC_NOMBRE).indexOf(q) >= 0; });
  var pr = PN.sel && (PN.lista || []).filter(function (x) { return x.PRC_ID === PN.sel; })[0];
  return { t: PN.c ? 'Elegir procedimiento' : 'Agregar desde procedimiento', s: PN.c ? 'Se copia a la OT al generarla' : 'Crea una actividad con el nombre, la duración y el permiso del procedimiento', w: 'w',
    b: '<div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center"><label class="cp-srch2" style="flex:1;min-width:220px">' + ic('search', 14) + '<input data-pv="q" value="' + esc(PN.q) + '" placeholder="Código o nombre" aria-label="Buscar procedimiento" data-autofocus="1" autocomplete="off"></label>' + (F.plan.TIPO_ID ? '<label class="cp-sw"><input type="checkbox" data-pv="only"' + (PN.only ? ' checked' : '') + '><i></i>Solo ' + esc(String(F.plan.TIPO).toLowerCase()) + '</label>' : '') + '</div>' +
      '<div class="cp-pkw"><div class="cp-pk">' + (!PN.lista ? '<div class="cp-sk" style="height:200px"></div>' : list.map(function (x) { return '<button type="button" class="cp-pk-o' + (PN.sel === x.PRC_ID ? ' cp-on' : '') + '" data-a="pksel" data-v="' + x.PRC_ID + '"><b>' + esc(x.PRC_NOMBRE) + '</b><small>' + esc(x.PRC_CODIGO) + ' v' + (x.PRC_VERSION || 1) + (x.PRC_DURACION_ESTIMADA_MINUTO ? ' · ' + fH(x.PRC_DURACION_ESTIMADA_MINUTO) : '') + (x.PRC_REQUIERE_PERMISO ? ' · permiso' : '') + '</small></button>'; }).join('') || '<div class="cp-empty" style="border:0">Sin resultados.' + (U.permisos.editarProcedimientos ? '<a class="cp-lnk" href="' + CFG.base_ + 'View/Mantenimiento/Procedimientos/Procedimiento.aspx" target="_blank" rel="noopener">Crear un procedimiento</a>' : '') + '</div>') + '</div>' +
      '<div class="cp-pkv">' + (pr ? '<span class="cp-tg cp-p">' + esc(pr.PRC_CODIGO) + ' v' + (pr.PRC_VERSION || 1) + '</span><h4>' + esc(pr.PRC_NOMBRE) + '</h4><div class="cp-facts">' + [['Tipo de activo', esc(pr.ACTIVO_TIPO_NOMBRE || 'Cualquier tipo')], ['Duración', pr.PRC_DURACION_ESTIMADA_MINUTO ? fH(pr.PRC_DURACION_ESTIMADA_MINUTO) : '—'], ['Pasos', PN.pasos ? PN.pasos.length : '…'], ['Permiso', pr.PRC_REQUIERE_PERMISO ? 'Sí' : 'No']].map(function (x) { return '<div><span>' + x[0] + '</span><b>' + x[1] + '</b></div>'; }).join('') + '</div>' +
        (PN.pasos ? '<ol class="cp-olst">' + PN.pasos.map(function (s) { return '<li><b>' + esc(s.n) + '</b>' + (s.ctrl ? ' <span class="cp-tg cp-p">Control</span>' : '') + (s.med ? ' <span class="cp-tg cp-c">Medición</span>' : '') + (s.ev ? ' <span class="cp-tg">Evidencia</span>' : '') + (s.ins ? '<small>' + esc(s.ins) + '</small>' : '') + '</li>'; }).join('') + '</ol>' : '<div class="cp-sk" style="height:120px"></div>')
        : '<div class="cp-empty" style="border:0;height:100%;justify-content:center">' + ic('clip', 20) + '<span>Elige un procedimiento para ver sus pasos.</span></div>') + '</div></div>',
    f: '<span></span><span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><button type="button" class="cp-btn cp-pri" data-a="pkok"' + (pr ? '' : ' disabled') + '>' + (PN.c ? 'Usar este procedimiento' : 'Agregar como actividad') + '</button></span>' };
};
function pasosDe(rows) {
  return (rows || []).map(function (r) {
    var g = function () { for (var i = 0; i < arguments.length; i++) if (r[arguments[i]] != null) return r[arguments[i]]; return null; };
    return { n: g('PPA_NOMBRE', 'NOMBRE', 'ppa_nombre') || '', ins: g('PPA_INSTRUCCION', 'INSTRUCCION', 'PPA_DESCRIPCION') || '', ctrl: !!g('PPA_ES_PUNTO_CONTROL', 'PUNTO_CONTROL'), ev: !!g('PPA_REQUIERE_EVIDENCIA', 'REQUIERE_EVIDENCIA'), med: !!g('PPA_REQUIERE_MEDICION', 'REQUIERE_MEDICION', 'PPA_VARIABLE_MEDICION') };
  });
}

/* ---- duplicar ---- */
PANELS.dup = function () {
  var nInt = F && F.plan.PLAN_ID === PN.pid ? F.intervenciones.length : null, nAct = F && F.plan.PLAN_ID === PN.pid ? F.activos.length : PN.nAct;
  return { t: 'Duplicar plan', s: esc(PN.codigo) + ' · ' + esc(PN.nombre), w: 'n',
    b: '<div class="cp-imp">Se copian las intervenciones' + (nInt != null ? ' (<b>' + nInt + '</b>)' : '') + ', con sus actividades, repuestos y responsables. La copia nace como <b>borrador</b>, sin historial ni ejecuciones.</div>' +
      '<div class="cp-fld"><label for="cpDpn">Nombre</label><input id="cpDpn" class="cp-inp' + (PN.err ? ' cp-err' : '') + '" data-pv="n" value="' + esc(PN.n) + '" data-autofocus="1" maxlength="200">' + (PN.err ? mc('', 'El plan necesita un nombre.') : '') + '</div>' +
      '<label class="cp-sw"><input type="checkbox" data-pv="inc"' + (PN.inc ? ' checked' : '') + (nAct === 0 ? ' disabled' : '') + '><i></i>Incluir los activos' + (nAct != null ? ' (' + nAct + ')' : '') + '</label>' +
      mc('i', 'Las frecuencias propias se copian como nuevas, con la misma regla. Las que usan un calendario compartido siguen usando el mismo.', 'help'),
    f: '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><button type="button" class="cp-btn cp-pri" data-a="dupok" id="cpDupOk">Crear copia</button></span>' };
};

/* ---- carga masiva: el asistente de importación de planes del sitio ---- */
PANELS.bulk = function () {
  return { t: 'Carga masiva', s: 'Crea varios planes desde un Excel', w: 'n',
    b: '<div class="cp-stepsx"><div><span class="cp-o">1</span><div><b>Descarga la plantilla</b><small>Hojas de planes, intervenciones y actividades, con las frecuencias escritas como en la ficha.</small></div></div>' +
      '<div><span class="cp-o">2</span><div><b>Súbela completada</b><small>SIGMA valida cada fila y te dice qué falta antes de crear nada.</small></div></div>' +
      '<div><span class="cp-o">3</span><div><b>Revisa el resultado por fila</b><small>Los planes se crean en borrador. Nada se activa solo.</small></div></div></div>' +
      mc('i', 'La importación se abre en una ventana del sitio. Al cerrarla, la lista de planes se actualiza.', 'help'),
    f: '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><button type="button" class="cp-btn cp-pri" data-a="bulkgo">' + ic('upload', 16) + 'Abrir la importación</button></span>' };
};

/* =====================================================================
   Confirmaciones (solo Activar, Aplicar, Descartar, Desactivar, Reactivar y Eliminar)
   ===================================================================== */
var MODALS = {};
function openModal(o) { MD = o; cerrarPop(); modal(); setTimeout(function () { var f = $('#cpLayer2 [data-autofocus]') || $('#cpLayer2 .cp-mdl-f .cp-btn:last-child'); if (f) f.focus(); }, 30); }
function closeModal() { MD = null; $('#cpLayer2').innerHTML = ''; }
function modal() {
  var L = $('#cpLayer2'); if (!MD) { L.innerHTML = ''; return; }
  var fo = grabFocus(L), r = MODALS[MD.t]();
  L.innerHTML = '<div class="cp-scr cp-mdl-scr" data-a="mclose"></div><div class="cp-mdl" role="alertdialog" aria-modal="true" aria-labelledby="cpMdlT"><div class="cp-mdl-h"><span class="cp-mi ' + (r.c ? 'cp-' + r.c : '') + '">' + ic(r.i, 20) + '</span><div><h3 id="cpMdlT">' + r.t + '</h3>' + (r.p ? '<p>' + r.p + '</p>' : '') + '</div></div><div class="cp-mdl-b">' + (r.b || '') + (MD.err2 ? mc('', esc(MD.err2)) : '') + '</div><div class="cp-mdl-f">' + r.f + '</div></div>';
  putFocus(fo, L);
}
var mFoot = function (lbl, cls, a) { return '<button type="button" class="cp-btn cp-plain" data-a="mclose">Cancelar</button><button type="button" class="cp-btn cp-' + cls + (MD && MD.busy ? ' cp-load' : '') + '" data-a="' + a + '" id="cpMok"' + (MD && MD.busy ? ' aria-busy="true"' : '') + '>' + lbl + '</button>'; };
MODALS.activate = function () {
  var p = F.plan, im = U.imp || {}, ck = checks();
  return { i: 'check', t: 'Activar «' + esc(p.NOMBRE) + '»', p: 'SIGMA publica la versión 1 y programa las ejecuciones de los próximos 90 días.',
    b: '<div class="cp-facts">' + [['Activos', F.activos.length], ['Intervenciones', F.intervenciones.filter(function (i) { return i.HABILITADO; }).length], ['Ejecuciones en 90 días', im.CREAN == null ? '…' : im.CREAN], ['Primera ejecución', im.PRIMERA ? fDL(im.PRIMERA) : 'Por medidor o condición']].map(function (x) { return '<div><span>' + x[0] + '</span><b>' + x[1] + '</b></div>'; }).join('') + '</div>' +
      (ck.W.length ? mc('w', pl(ck.W.length, 'advertencia', 'advertencias') + ' en «Listo para activar». Puedes activar igual.') : '') + '<p class="cp-msg cp-i">' + ic('help', 13) + '<span>Después podrás editarlo: los cambios se guardan aparte hasta que los apliques.</span></p>',
    f: mFoot(ic('check', 16) + 'Activar plan', 'pri', 'mact') };
};
MODALS.apply = function () {
  var p = F.plan, im = U.imp || {};
  return { i: 'check', t: 'Aplicar cambios · v' + p.VERSION_BORRADOR, p: pl(+p.CAMBIOS || 0, 'cambio', 'cambios') + ' respecto de la v' + p.VERSION_VIGENTE + '. Así quedan las ejecuciones desde hoy:',
    b: imp4(im) + '<div class="cp-fld"><label for="cpMobs">Observación de la versión <small>opcional</small></label><input id="cpMobs" class="cp-inp" data-mv="obs" value="' + esc(MD.obs || '') + '" placeholder="Ej.: Se agrega la calibración de termocuplas" maxlength="500"></div>',
    f: mFoot(ic('check', 16) + 'Aplicar cambios', 'pri', 'mapply') };
};
MODALS.discard = function () { var p = F.plan; return { i: 'alert', c: 'a', t: 'Descartar los cambios', p: 'Se pierden ' + pl(+p.CAMBIOS || 0, 'cambio', 'cambios') + ' sin aplicar. La v' + p.VERSION_VIGENTE + ' sigue activa, igual que antes.', f: mFoot('Descartar cambios', 'dan', 'mdiscard') }; };
MODALS.deact = function () {
  var ps = MD.planes, uno = ps.length === 1, im = MD.im || {};
  return { i: 'alert', c: 'a', t: uno ? 'Desactivar «' + esc(ps[0].NOMBRE) + '»' : 'Desactivar ' + ps.length + ' planes', p: 'Deja de generar trabajo. Puedes reactivarlo cuando quieras.',
    b: (uno ? '<div class="cp-imp">Se cancelan <b>' + (im.DESACTIVAR_CANCELAN == null ? '…' : pl(+im.DESACTIVAR_CANCELAN, 'ejecución futura', 'ejecuciones futuras')) + '</b> sin OT.' + (+im.CON_OT ? ' Las <b>' + im.CON_OT + ' con OT</b> siguen su curso.' : '') + (ps[0].ESTADO === 'CAMBIOS' ? ' Los cambios sin aplicar se descartan.' : '') + '</div>' : '<div class="cp-imp">Se cancelan las ejecuciones futuras sin OT de los ' + ps.length + ' planes. Las que tienen OT siguen su curso.</div>') +
      '<div class="cp-fld"><label for="cpMmot">Motivo <small>obligatorio</small></label><textarea id="cpMmot" class="cp-inp' + (MD.err ? ' cp-err' : '') + '" rows="2" data-mv="mot" data-autofocus="1" placeholder="Ej.: El activo se retira de la línea" maxlength="500">' + esc(MD.mot || '') + '</textarea>' + (MD.err ? mc('', 'Escribe el motivo (al menos 5 letras): queda en el historial del plan.') : '') + '</div>',
    f: mFoot(uno ? 'Desactivar plan' : 'Desactivar ' + ps.length + ' planes', 'pri', 'mdeact') };
};
MODALS.react = function () { var p = F.plan; return { i: 'trend', t: 'Reactivar «' + esc(p.NOMBRE) + '»', p: 'Se publica como versión nueva. Las ejecuciones futuras que se cancelaron vuelven a quedar pendientes y se genera lo que falte.', b: '<div class="cp-imp">SIGMA programa los próximos 90 días para <b>' + pl(F.activos.length, 'activo', 'activos') + '</b>.</div>', f: mFoot('Reactivar plan', 'pri', 'mreact') }; };
MODALS.del = function () { var p = F.plan; return { i: 'x', c: 'r', t: 'Eliminar «' + esc(p.NOMBRE || p.CODIGO) + '»', p: p.ESTADO === 'BORRADOR' ? 'El borrador nunca se activó: no tiene ejecuciones ni OT. Se elimina por completo.' : 'Nunca generó ejecuciones. Se elimina por completo.', f: mFoot('Eliminar plan', 'dan', 'mdel') }; };
function confirmar(fn) {
  if (U.plan) delete U.flash[U.plan];
  MD.busy = true; MD.err2 = null; modal();
  return fn().then(function (r) { closeModal(); return r; }, function (e) { if (MD) { MD.busy = false; MD.err2 = e.message; modal(); } throw e; });
}

/* =====================================================================
   Menús y popovers
   ===================================================================== */
var POPS = {};
function openPop(el, o) { o.el = el; POP = o; paintPop(); setTimeout(function () { var f = $('#cpPop [data-autofocus]'); if (f) f.focus({ preventScroll: true }); }, 20); }
function cerrarPop() { if (!POP) return; var el = POP.el; POP = null; paintPop(); if (el && el.isConnected && el.getAttribute('aria-expanded')) el.setAttribute('aria-expanded', 'false'); }
function paintPop() {
  var host = $('#cpPop'); if (!POP) { host.innerHTML = ''; return; }
  var fo = grabFocus(host);
  host.innerHTML = '<div class="cp-pp ' + (POP.cls || '') + '" role="' + (POP.t === 'more' ? 'menu' : POP.t === 'rep' ? 'listbox' : 'dialog') + '" style="visibility:hidden">' + POPS[POP.t]() + '</div>';
  posPop(); putFocus(fo, host);
}
function posPop() {
  var pp = $('#cpPop .cp-pp'); if (!pp || !POP) return;
  if (POP.el && POP.el.isConnected) { var r = POP.el.getBoundingClientRect(); POP.r = { l: r.left, t: r.top, b: r.bottom, rr: r.right }; }
  var w = pp.offsetWidth, h = pp.offsetHeight, R = POP.r || { l: 20, t: 20, b: 20, rr: 20 };
  var left = POP.right ? R.rr - w : R.l; left = Math.max(12, Math.min(left, innerWidth - w - 12));
  var top = R.b + 6; if (top + h > innerHeight - 12) top = Math.max(12, R.t - h - 6);
  pp.style.left = left + 'px'; pp.style.top = top + 'px'; pp.style.visibility = '';
}
POPS.newplan = function () {
  var plantas = CFG.plantas || [];
  return '<div class="cp-npf" data-form="np"><b>Nuevo plan</b><div class="cp-fld"><label for="cpNpn">Nombre</label><input id="cpNpn" class="cp-inp' + (POP.err ? ' cp-err' : '') + '" data-ppv="n" value="' + esc(POP.n || '') + '" placeholder="Ej.: Preventivo secadores de aire" data-autofocus="1" autocomplete="off" maxlength="200">' + (POP.err ? mc('', 'Escribe un nombre para crear el plan.') : '') + '</div>' +
    (plantas.length > 1 ? '<div class="cp-fld"><label>Planta</label>' + combo('cpNpPlanta', plantas, POP.pl || '', { etiqueta: 'Planta', ph: 'Elige la planta', data: ' data-ppq="pl"' }) + '</div>' : '') +
    (POP.activos ? '<div class="cp-imp" style="padding:8px 10px">' + pl(POP.activos.length, 'activo', 'activos') + ': ' + esc(POP.activosTxt || '') + '</div>' : '') +
    '<p class="cp-msg cp-i">' + ic('help', 13) + '<span>Solo el nombre es obligatorio. El código se asigna solo y el plan nace en borrador.</span></p>' +
    '<div style="display:flex;justify-content:flex-end;gap:8px"><button type="button" class="cp-btn cp-plain cp-sm" data-a="popx">Cancelar</button><button type="button" class="cp-btn cp-pri cp-sm' + (POP.busy ? ' cp-load' : '') + '" data-a="npok">Crear borrador</button></div></div>';
};
POPS.more = function () {
  var p = F.plan, e = estado(p)[0], ed = U.permisos.editar;
  var mi = function (a, i, l, cls) { return '<button type="button" class="cp-mi2 ' + (cls ? 'cp-' + cls : '') + '" role="menuitem" data-a="' + a + '">' + ic(i, 16) + l + '</button>'; };
  return [ed ? mi('mdup', 'copy', 'Duplicar plan') : '', e !== 'draft' ? mi('mhist', 'clock', 'Ver historial') : '', e === 'active' || e === 'changes' ? mi('mexec', 'calw', 'Ver ejecuciones') : '',
    ed && (e === 'active' || e === 'changes') ? '<hr>' + mi('mdeactq', 'alert', 'Desactivar plan…') : '',
    ed && (e === 'draft' || (e === 'inactive' && !p.GENERO)) ? '<hr>' + mi('mdelq', 'x', 'Eliminar plan', 'dn') : ''].join('') || '<p style="padding:10px;font-size:12.5px;color:var(--muted)">Sin acciones disponibles.</p>';
};
POPS.psw = function () {
  var q = nrm(POP.q || ''), l = ordenPlanes().filter(function (p) { return !q || nrm(p.NOMBRE + ' ' + p.CODIGO).indexOf(q) >= 0; }).slice(0, 12);
  return '<div class="cp-ppt"><b>Cambiar de plan</b></div><label class="cp-srch2" style="margin:0 6px 6px">' + ic('search', 14) + '<input data-ppv="q" value="' + esc(POP.q || '') + '" placeholder="Buscar plan" aria-label="Buscar plan" data-autofocus="1" autocomplete="off"></label><div class="cp-srchres">' +
    (l.map(function (p) { return '<button type="button" class="cp-mi2 cp-sh2" data-a="pgo" data-p="' + p.PLAN_ID + '"' + (p.PLAN_ID === U.plan ? ' aria-current="true"' : '') + '>' + ic('calw', 16) + '<span><b>' + esc(p.NOMBRE) + '</b><small>' + esc(p.CODIGO) + ' · ' + estado(p)[1] + '</small></span></button>'; }).join('') || '<p style="padding:10px;font-size:12.5px;color:var(--muted)">Ningún plan coincide.</p>') + '</div>';
};
POPS.shared = function () {
  return '<div class="cp-ppt"><b>Usar un calendario compartido</b><small>La intervención tomará sus fechas. Si alguien lo cambia en la Biblioteca, cambia aquí también.</small></div>' + (U.cat.calendarios || []).map(function (c) { return '<button type="button" class="cp-mi2 cp-sh2" data-a="pickshared" data-c="' + c.ID + '">' + ic('link', 16) + '<span><b>' + esc(c.NOMBRE) + '</b><small>' + esc(c.TIPO || '') + '</small></span></button>'; }).join('');
};
POPS.rep = function () {
  if (POP.cargando) return '<p style="padding:10px;font-size:12.5px;color:var(--muted)">Buscando…</p>';
  var l = POP.lista || [];
  return '<div class="cp-srchres">' + (l.length ? l.map(function (r) { return '<button type="button" class="cp-mi2" role="option" data-a="addrep" data-v="' + r.id + '">' + ic('box', 15) + '<span><b style="font-weight:600">' + esc(r.nombre) + '</b> <small style="color:var(--muted)">' + esc(r.codigo) + '</small></span></button>'; }).join('') : '<p style="padding:10px;font-size:12.5px;color:var(--muted)">' + (String(POP.q || '').length < 2 ? 'Escribe al menos 2 letras.' : 'Ningún repuesto coincide.') + '</p>') + '</div>';
};

/* =====================================================================
   Acciones (data-a)
   ===================================================================== */
var A = {};
var upKeys = function (r) { var o = {}; Object.keys(r || {}).forEach(function (k) { o[k.toUpperCase()] = r[k]; }); return o; };
var pid = function () { return U.plan; };
var sinCambio = function (a, b) { return String(a == null ? '' : a) === String(b == null ? '' : b); };

A.tab = function (d) {
  var extra = {};
  if (d.fp) { extra.plan = +d.fp; extra.f = d.ff || 'all'; }
  if (d.lib) extra.lib = d.lib;
  switchTab(d.t, extra);
};
A.kpi = function (d) {
  if (d.go === 'cum') return switchTab('cumplimiento');
  switchTab('ejecuciones', d.go === 'att' ? { f: 'att', vista: 'lista', plan: 0 } : d.go === 'disp' ? { f: 'disp', vista: 'lista', plan: 0 } : { vista: 'semana', plan: 0 });
};
A.pf = function (d) { U.pf = d.v; render(); };
A.pfclear = function () { U.pf = 'all'; U.q = ''; render(); };
A.open = function (d, t, e) { if (e && e.target && e.target.closest('.cp-cbx')) return; abrirPlan(+d.p); };
A.back = function () { U.plan = null; F = null; render(); hashOut(); window.scrollTo(0, 0); };
A.mul = function (d, t, e) { if (e) e.stopPropagation(); if (U.multi[d.p]) delete U.multi[d.p]; else U.multi[d.p] = 1; render(); };
A.bulkclr = function () { U.multi = {}; render(); };
A.bulkdup = function () { var id = +Object.keys(U.multi)[0], p = U.lista.filter(function (x) { return x.PLAN_ID === id; })[0]; if (p) openPanel({ t: 'dup', pid: id, codigo: p.CODIGO, nombre: p.NOMBRE, n: 'Copia de ' + p.NOMBRE, inc: true, nAct: +p.ACTIVOS }); };
A.bulkoff = function () {
  var ps = U.lista.filter(function (p) { return U.multi[p.PLAN_ID] && (p.ESTADO === 'ACTIVO' || p.ESTADO === 'CAMBIOS'); });
  if (!ps.length) { toast('Solo se desactivan planes activos.'); return; }
  openModal({ t: 'deact', planes: ps, mot: '' });
};
A.flashx = function () { delete U.flash[pid()]; render(); };
A.go = function (d) { goEl('#' + d.s); };
function toFicha() { var el = $('.cp-fi'); if (!el) return; var t = el.getBoundingClientRect().top; if (t < 76 || t > innerHeight * .5) window.scrollTo({ top: window.scrollY + t - 84, behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' }); }
function focusIn(sel) { setTimeout(function () { var el = sel && $(sel); if (el) { el.focus({ preventScroll: true }); el.scrollIntoView({ block: 'center', behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' }); el.classList.remove('cp-flashb'); void el.offsetWidth; el.classList.add('cp-flashb'); } }, 80); }
/* Lleva a un pendiente: abre el paso, la intervención y la actividad, y enfoca el campo. */
A.fix = function (d) {
  var id = pid(), k = +d.step, h = d.i ? hById(d.i) : null;
  U.step[id] = k; if (d.t5) U.t5[id] = d.t5;
  if (h) U.oi[id] = h.CODIGO;
  var ac = d.c ? aById(d.c) : null; if (ac) U.oa[ac.h.CODIGO] = ac.a.CODIGO;
  render(); toFicha();
  var sel = k === 1 ? (F.activos.length ? '[data-cb="cpScPlanta"] input[type=text]' : '#cpStc [data-a="addeq"]')
    : k === 2 ? (!ints().length ? '#cpStc [data-a="addint"]' : ac ? '.cp-ac[data-ac="' + d.c + '"] .cp-err, .cp-ac[data-ac="' + d.c + '"] .cp-inp' : '.cp-ipanel .cp-err, .cp-ipanel [data-iv="nombre"]')
    : k === 3 ? (d.i ? '#cpWhen' + d.i + ' .cp-err, #cpWhen' + d.i + ' .cp-segc button, #cpWhen' + d.i + ' .cp-inp' : null)
    : k === 4 ? (d.i ? '[data-cb="cpIvResp' + d.i + '"] input[type=text]' : '.cp-rtbl input[type=text]') : null;
  focusIn(sel);
};
A.stp = function (d) { U.step[pid()] = +d.v; if (d.t5) U.t5[pid()] = d.t5; cerrarPop(); render(); hashOut(); toFicha(); };
A.t5 = function (d) { U.t5[pid()] = d.v; render(); };
A.isel = function (d) { var h = hById(d.i); if (h) { U.oi[pid()] = h.CODIGO; render(); } };
A.next = function () {
  var id = pid(), info = stepInfo(), k = U.step[id] || 1, e = info.err(k);
  if (e.length) { U.nx[id] = k; (U.vis[id] = U.vis[id] || {})[k] = 1; A.fix({ step: k, i: e[0].int, c: e[0].act }); return; }
  U.step[id] = Math.min(5, k + 1); render(); hashOut(); toFicha();
};
function blockFail() {
  var id = pid(), b = checks().B.filter(function (x) { return !x.ok; })[0]; U.tried[id] = true;
  if (b) A.fix({ step: b.step, i: b.int, c: b.act });
  toast('Falta completar un dato: te llevé directo a él.');
}
A.psw = function (d, t) { openPop(t, { t: 'psw', q: '' }); };
A.pnav = function (d) { var l = ordenPlanes(), x = l.findIndex(function (q) { return q.PLAN_ID === U.plan; }), n = l[x + (+d.v)]; if (n) abrirPlan(n.PLAN_ID, { top: false }); };
A.pgo = function (d) { cerrarPop(); abrirPlan(+d.p, { top: false }); };
A.activate = function (d, t) { if (t.getAttribute('aria-disabled') === 'true') return blockFail(); openModal({ t: 'activate' }); };
A.apply = function (d, t) { if (t.getAttribute('aria-disabled') === 'true') return blockFail(); openModal({ t: 'apply', obs: '' }); };
A.discard = function () { openModal({ t: 'discard' }); };
A.reactivate = function () { openModal({ t: 'react' }); };
A.more = function (d, t) { t.setAttribute('aria-expanded', 'true'); openPop(t, { t: 'more', right: true }); };
A.mdup = function () { cerrarPop(); var p = F.plan; openPanel({ t: 'dup', pid: p.PLAN_ID, codigo: p.CODIGO, nombre: p.NOMBRE, n: 'Copia de ' + p.NOMBRE, inc: true }); };
A.mhist = function () { cerrarPop(); goEl('#cpSecHist'); };
A.mexec = function () { cerrarPop(); switchTab('ejecuciones', { plan: pid(), f: 'all' }); };
A.mdeactq = function () {
  cerrarPop(); var lp = U.lista.filter(function (x) { return x.PLAN_ID === pid(); })[0] || F.plan;
  openModal({ t: 'deact', planes: [lp], mot: '', im: U.imp });
};
A.mdelq = function () { cerrarPop(); openModal({ t: 'del' }); };
A.newplan = function (d, t) { t.setAttribute('aria-expanded', 'true'); openPop(t, { t: 'newplan', right: true, n: '', pl: U.planta || ((CFG.plantas || []).length === 1 ? CFG.plantas[0].id : '') }); };
A.popx = function () { cerrarPop(); };
A.pclose = function () { closePanel(); };
A.mclose = function () { if (MD && MD.busy) return; closeModal(); };
A.undo = function () { if (!UNDO) return; var u = UNDO; UNDO = null; u.el.remove(); u.fn(); };
A.otf = function (d) { U.otf = d.v; render(); };
A.retrygen = function () {
  guardando();
  api('Generar', { plan: pid() }).then(function (r) { guardado(); U.flash[pid()] = r.ERROR_GENERACION ? { t: 'No se pudieron generar las ejecuciones: ' + esc(r.ERROR_GENERACION), w: true, retry: true } : { t: 'Ejecuciones generadas · ' + pl(+r.GENERADAS || 0, 'nueva', 'nuevas') + '.' }; return recargarFicha(); }).catch(function (e) { noGuardado(e.message); toastError(e); });
};

/* ---- crear plan ---- */
A.npok = function () {
  var n = String(POP.n || '').trim();
  if (!n) { POP.err = true; paintPop(); return; }
  POP.busy = true; paintPop();
  var act = POP.activos ? POP.activos.join(',') : '';
  api('CrearPlan', { nombre: n, planta: +POP.pl || 0, tipo: 0, activos: act }).then(function (r) {
    if (POP && POP.activos) { U.cob.sel = {}; cobCargar(); }
    cerrarPop(); U.pf = 'all'; U.q = '';
    var malos = (r.resultados || []).filter(function (x) { return !x.ok; });
    return recargarLista().then(function () { U.tab = 'planes'; return abrirPlan(r.plan); }).then(function () {
      toast(malos.length ? 'Plan creado en borrador. ' + pl(malos.length, 'activo no se pudo agregar', 'activos no se pudieron agregar') + '.' : 'Plan creado en borrador.');
      var nm = $('[data-pf="nombre"]'); if (nm && !POP) nm.focus();
    });
  }).catch(function (e) { if (POP) { POP.busy = false; paintPop(); } toastError(e); });
};

/* ---- confirmaciones ---- */
A.mact = function () {
  var id = pid();
  confirmar(function () { return api('Activar', { plan: id, observacion: '' }); }).then(function (r) {
    U.tried[id] = false; U.step[id] = 5; U.t5[id] = 'rev';
    U.flash[id] = r.ERROR_GENERACION ? { t: 'Plan activado (v' + r.VERSION + '), pero no se pudieron generar las ejecuciones: ' + esc(r.ERROR_GENERACION), w: true, retry: true }
      : { t: 'Plan activado · ' + pl(+r.GENERADAS || 0, 'ejecución programada', 'ejecuciones programadas') + ' hasta el ' + fDY(addD(TODAY, 90)) + '.' };
    toast('Plan activo. SIGMA ya programó sus ejecuciones.');
    return Promise.all([recargarFicha(), recargarLista(), recargarKpis()]);
  }).catch(function () { });
};
A.mapply = function () {
  var id = pid(), obs = MD.obs || '';
  confirmar(function () { return api('Activar', { plan: id, observacion: obs }); }).then(function (r) {
    U.flash[id] = r.ERROR_GENERACION ? { t: 'Cambios aplicados (v' + r.VERSION + '), pero no se pudieron generar las ejecuciones: ' + esc(r.ERROR_GENERACION), w: true, retry: true }
      : { t: 'Cambios aplicados · v' + r.VERSION + ' activa. ' + (+r.TRASPASADAS || 0) + ' se mantienen, ' + (+r.GENERADAS || 0) + ' se crean y ' + (+r.CANCELADAS || 0) + ' se cancelan.' + (+r.REABIERTAS ? ' ' + pl(+r.REABIERTAS, 'vuelve', 'vuelven') + ' a quedar pendiente' + (+r.REABIERTAS === 1 ? '' : 's') + '.' : '') };
    toast('v' + r.VERSION + ' publicada.');
    return Promise.all([recargarFicha(), recargarLista(), recargarKpis()]);
  }).catch(function () { });
};
A.mdiscard = function () {
  var id = pid();
  confirmar(function () { return api('DescartarCambios', { plan: id }); }).then(function () {
    U.fq = {}; U.pend = {}; toast('Cambios descartados. La versión activa sigue igual.');
    return Promise.all([recargarFicha(), recargarLista()]);
  }).catch(function () { });
};
A.mdeact = function () {
  var mot = String(MD.mot || '').trim();
  if (mot.length < 5) { MD.err = true; modal(); return; }
  var ps = MD.planes;
  confirmar(function () {
    return ps.reduce(function (c, p) { return c.then(function (n) { return api('Desactivar', { plan: p.PLAN_ID, motivo: mot }).then(function (r) { return n + (+r.CANCELADAS || 0); }); }); }, Promise.resolve(0));
  }).then(function (n) {
    U.multi = {};
    toast(ps.length === 1 ? ps[0].CODIGO + ' desactivado. ' + pl(n, 'ejecución futura sin OT quedó cancelada', 'ejecuciones futuras sin OT quedaron canceladas') + '.' : ps.length + ' planes desactivados.');
    return Promise.all([recargarFicha(), recargarLista(), recargarKpis()]);
  }).catch(function () { });
};
A.mreact = function () {
  var id = pid();
  confirmar(function () { return api('Reactivar', { plan: id }); }).then(function (r) {
    U.flash[id] = { t: 'Plan reactivado · ' + pl(+r.REABIERTAS || 0, 'ejecución reabierta', 'ejecuciones reabiertas') + ' y ' + pl(+r.GENERADAS || 0, 'nueva', 'nuevas') + '.' };
    return Promise.all([recargarFicha(), recargarLista(), recargarKpis()]);
  }).catch(function () { });
};
A.mdel = function () {
  var id = pid(), cod = F.plan.CODIGO;
  confirmar(function () { return api('Eliminar', { plan: id }); }).then(function () {
    U.plan = null; F = null; toast(cod + ' eliminado.');
    return recargarLista().then(function () { render(); hashOut(); });
  }).catch(function () { });
};

/* ---- activos ---- */
A.addeq = function () {
  openPanel({ t: 'addeq', q: '', fa: '', sel: {}, res: null, lista: null });
  api('Candidatos', { plan: pid(), filtro: '' }).then(function (r) { if (!PN || PN.t !== 'addeq') return; PN.lista = r.activos; PN.comp = r.componentes; PN.med = r.medidores; panel(); }).catch(function (e) { closePanel(); toastError(e); });
};
A.eqpick = function (d) { var id = +d.v; if (PN.sel[id]) delete PN.sel[id]; else PN.sel[id] = {}; panel(); };
A.eqall = function () {
  var q = nrm(PN.q), ok = PN.lista.filter(function (a) { return !a.YA_EN_PLAN && !a.MOTIVO && (!q || nrm(a.CODIGO + ' ' + a.NOMBRE + ' ' + (a.AREA || '')).indexOf(q) >= 0) && (!PN.fa || a.AREA === PN.fa); });
  var all = ok.every(function (a) { return PN.sel[a.ACTIVO_ID]; });
  ok.forEach(function (a) { if (all) delete PN.sel[a.ACTIVO_ID]; else PN.sel[a.ACTIVO_ID] = PN.sel[a.ACTIVO_ID] || {}; });
  panel();
};
A.eqok = function (d, t) {
  var items = Object.keys(PN.sel).map(function (id) {
    var s = PN.sel[id], meds = (PN.med || []).filter(function (m) { return m.ACTIVO_ID === +id; });
    return { activo: +id, componente: s.componente ? +s.componente : null, medidor: s.medidor ? +s.medidor : (meds[0] ? meds[0].ID : null) };
  });
  t.classList.add('cp-load');
  escribir('AgregarActivos', { plan: pid(), items: JSON.stringify(items) }).then(function (r) { if (PN && PN.t === 'addeq') { PN.res = r.resultados; PN.sel = {}; panel(); } }).catch(function (e) { t.classList.remove('cp-load'); toastError(e); });
};
A.rmeq = function (d) {
  var cod = d.c, a = F.activos.filter(function (x) { return x.VINCULO_ID === +d.v; })[0];
  escribir('QuitarActivo', { plan: pid(), vinculo: +d.v }).then(function () {
    toast(cod + ' quitado del plan.', a ? function () { escribir('AgregarActivos', { plan: pid(), items: JSON.stringify([{ activo: a.ACTIVO_ID, componente: a.COMPONENTE_ID, medidor: a.MEDIDOR_ID }]) }).catch(toastError); } : null);
  }).catch(toastError);
};

/* ---- intervenciones ---- */
A.addint = function (d) {
  var id = pid();
  escribir('AgregarIntervencion', { plan: id, nombre: d.n || '' }).then(function (r) {
    var h = hById(r.hito); if (!h) return;
    U.oi[id] = h.CODIGO; U.step[id] = 2; U.oa[h.CODIGO] = null; render(); hashOut();
    if (d.n) { goEl('#cpActs' + h.HITO_ID); } else { var n = $('#cpInt' + h.HITO_ID + ' [data-iv="nombre"]'); if (n) { n.focus(); n.select(); } }
  }).catch(toastError);
};
A.rmint = function (d) {
  var h = hById(d.i), nom = h ? h.CODIGO + ' · ' + (h.NOMBRE || 'Intervención') : 'Intervención';
  escribir('QuitarIntervencion', { plan: pid(), hito: +d.i }).then(function () { toast(nom + ' quitada.'); }).catch(toastError);
};

/* ---- frecuencia: borrador local y guardado ---- */
var fqVer = {};
function fqEditar(hid, fn) {
  var h = hById(hid); if (!h) return;
  var k = h.CODIGO, f = U.fq[k] || (U.fq[k] = fqDe(h));
  fn(f, h);
  fqVer[k] = (fqVer[k] || 0) + 1;
  render();
  if (!fqError(f)) guardarFq(h.HITO_ID, k);
}
function guardarFq(hid, k) {
  var v = fqVer[k], f = U.fq[k];
  escribir('GuardarFrecuencia', { plan: pid(), hito: +hid, datos: JSON.stringify(datosDe(f)) }).then(function () {
    if (fqVer[k] === v) { delete U.fq[k]; render(); }
  }).catch(function (e) { toastError(e); });
}
A.ftype = function (d) {
  var h = hById(d.i); if (!h) return;
  if (d.v === 'cond') return A.condpanel(d);
  fqEditar(d.i, function (f) {
    var antes = f.t; f.t = d.v;
    if (d.v === 'cal' && antes !== 'cal') { f.rep = f.rep || 'm'; f.n = 1; }
    if (d.v === 'int' && antes !== 'int') { f.n = 1; f.iu = uniId('MES'); f.anchor = f.from || TODAY; }
    if (d.v === 'med' && !(+f.mn > 0)) f.mn = 500;
    if (d.v === 'fec' && antes !== 'fec') f.dates = [];
  });
};
A.fset = function (d) {
  fqEditar(d.i, function (f) {
    var k = d.k, v = d.v;
    f[k] = k === 'mmode' || k === 'rep' ? v : isNaN(+v) ? v : +v;
    if (k === 'rep' && v === 'w' && !f.days.length) f.days = [wday(TODAY)];
    if (k === 'rep' && (v === 'm' || v === 'y') && f.mmode !== 'ord' && !f.md) f.md = +TODAY.slice(8, 10);
  });
};
A.fday = function (d) {
  fqEditar(d.i, function (f) { var x = +d.v, i = f.days.indexOf(x); if (i >= 0) f.days.splice(i, 1); else f.days.push(x); f.days.sort(); });
};
A.rmdate = function (d) { fqEditar(d.i, function (f) { f.dates = f.dates.filter(function (x) { return x.fecha !== d.v; }); }); };
A.addexc = function (d) { var h = hById(d.i); if (!h) return; U.vp['exc' + h.CODIGO] = { a: '', b: '', why: '', shift: false }; render(); var f = $('#cpWhen' + d.i + ' [data-fe="x:' + d.i + ':a"]'); if (f) f.focus(); };
A.excx = function (d) { var h = hById(d.i); if (h) delete U.vp['exc' + h.CODIGO]; render(); };
A.xeff = function (d) { var h = hById(d.i); if (!h) return; U.vp['exc' + h.CODIGO].shift = d.v === '1'; render(); };
A.excok = function (d) {
  var h = hById(d.i); if (!h) return; var v = U.vp['exc' + h.CODIGO];
  v.err = !v.a || !v.b ? 'Indica desde y hasta.' : v.b < v.a ? '«Hasta» debe ser igual o posterior a «Desde».' : !String(v.why || '').trim() ? 'Escribe el motivo de la exclusión.' : '';
  if (v.err) { render(); return; }
  delete U.vp['exc' + h.CODIGO];
  fqEditar(d.i, function (f) { f.excl.push({ a: v.a, b: v.b, why: v.why.trim(), shift: !!v.shift }); });
};
A.rmexc = function (d) { fqEditar(d.i, function (f) { f.excl.splice(+d.v, 1); }); };
A.useshared = function (d, t) { openPop(t, { t: 'shared', hito: +d.i }); };
A.pickshared = function (d) {
  var h = POP.hito; cerrarPop();
  escribir('CalendarioCompartido', { plan: pid(), hito: h, programacion: +d.c }).then(function () { toast('La intervención usa el calendario compartido.'); }).catch(toastError);
};
A.ownfreq = function (d) {
  escribir('CalendarioCompartido', { plan: pid(), hito: +d.i, programacion: 0 }).then(function () { toast('La frecuencia ahora es propia de esta intervención.'); }).catch(toastError);
};
A.condpanel = function (d) {
  guardando();
  cola = cola.then(function () {
    return api('PrepararCondicion', { plan: pid(), hito: +d.i }).then(function (r) {
      guardado();
      if (window.SigmaModal) {
        SigmaModal.open({ url: r.url, title: 'Condición que dispara la intervención', width: 1000, initialHeight: 680 });
        var al = function () { document.removeEventListener('sigma:modalclosed', al); recargarFicha(); };
        document.addEventListener('sigma:modalclosed', al);
      } else window.open(r.url, '_blank');
      return recargarFicha();
    });
  }).catch(function (e) { noGuardado(e.message); toastError(e); });
};

/* ---- actividades, procedimientos y repuestos ---- */
A.toggleact = function (d) { var ac = aById(d.c); if (!ac) return; var k = ac.h.CODIGO; U.oa[k] = U.oa[k] === ac.a.CODIGO ? null : ac.a.CODIGO; render(); };
A.addact = function (d) {
  var h = hById(d.i); if (!h) return; var hc = h.CODIGO;
  escribir('AgregarActividad', { plan: pid(), hito: +d.i, nombre: '', procedimiento: 0 }).then(function (r) {
    var ac = aById(r.actividad); if (ac) { U.oa[hc] = ac.a.CODIGO; U.oi[pid()] = hc; render(); goEl('.cp-ac[data-ac="' + r.actividad + '"]', '[data-act="nombre"]'); }
  }).catch(toastError);
};
A.rmact = function (d) {
  var ac = aById(d.c); var nom = ac ? ac.a.CODIGO + ' · ' + (ac.a.NOMBRE || 'Actividad') : 'Actividad';
  escribir('QuitarActividad', { plan: pid(), actividad: +d.c }).then(function () { toast(nom + ' quitada.'); }).catch(toastError);
};
A.mvact = function (d) {
  var ac = aById(d.c); if (!ac) return;
  var l = ac.h.ACTIVIDADES, k = l.indexOf(ac.a), j = k + (+d.v); if (j < 0 || j >= l.length) return;
  var b = l[j], oa = ac.a.ORDEN, ob = b.ORDEN; if (oa === ob) { oa = k + 1; ob = j + 1; }
  escribir('GuardarActividad', { plan: pid(), actividad: ac.a.ACTIVIDAD_ID, campo: 'orden', valor: String(ob) }, { sinFicha: true })
    .then(function () { var b2 = aById(b.ACTIVIDAD_ID) ? b.ACTIVIDAD_ID : b.ACTIVIDAD_ID; return escribir('GuardarActividad', { plan: pid(), actividad: b2, campo: 'orden', valor: String(oa) }); }).catch(toastError);
};
A.pickproc = function (d) {
  var ac = d.c ? aById(d.c) : null;
  openPanel({ t: 'pick', i: +d.i, c: d.c ? +d.c : null, q: '', only: !!F.plan.TIPO_ID, sel: ac ? ac.a.PROCEDIMIENTO_ID : null, lista: null, pasos: null });
  cargarProcs();
  if (PN.sel) cargarPasos(PN.sel);
};
function cargarProcs() {
  api('Procedimientos', { filtro: '', tipo: PN.only ? (F.plan.TIPO_ID || 0) : 0 }).then(function (r) { if (!PN || PN.t !== 'pick') return; PN.lista = (r.procedimientos || []).map(upKeys); panel(); }).catch(function (e) { closePanel(); toastError(e); });
}
function cargarPasos(prId) {
  if (PN) PN.pasos = null;
  api('ProcedimientoPasos', { procedimiento: prId }).then(function (r) { if (!PN || PN.t !== 'pick' || PN.sel !== prId) return; PN.pasos = pasosDe((r.pasos || []).map(upKeys)); panel(); }).catch(function () { if (PN) { PN.pasos = []; panel(); } });
}
A.pksel = function (d) { PN.sel = +d.v; panel(); cargarPasos(PN.sel); };
A.pkok = function (d, t) {
  var o = PN; t.classList.add('cp-load');
  var pr = o.c
    ? escribir('GuardarActividad', { plan: pid(), actividad: o.c, campo: 'procedimiento', valor: String(o.sel) })
    : escribir('AgregarActividad', { plan: pid(), hito: o.i, nombre: '', procedimiento: o.sel });
  pr.then(function (r) {
    closePanel();
    var ac = aById(r.actividad); if (ac) { U.oa[ac.h.CODIGO] = ac.a.CODIGO; U.oi[pid()] = ac.h.CODIGO; render(); }
    toast(o.c ? 'Procedimiento vinculado a la actividad.' : 'Actividad agregada desde el procedimiento.');
  }).catch(function (e) { t.classList.remove('cp-load'); toastError(e); });
};
A.rmproc = function (d) { escribir('GuardarActividad', { plan: pid(), actividad: +d.c, campo: 'procedimiento', valor: '' }).catch(toastError); };
A.vsteps = function (d) {
  var ac = aById(d.c); if (!ac) return; var k = 'st' + ac.h.CODIGO + ac.a.CODIGO;
  if (U.vp[k]) { delete U.vp[k]; render(); return; }
  U.vp[k] = 'cargando'; render();
  api('ProcedimientoPasos', { procedimiento: +d.pr }).then(function (r) { U.vp[k] = pasosDe((r.pasos || []).map(upKeys)); render(); }).catch(function (e) { delete U.vp[k]; render(); toastError(e); });
};
A.addrep = function (d) {
  var act = POP.act, q = POP.input; cerrarPop(); if (q) q.value = '';
  escribir('AgregarRepuesto', { plan: pid(), actividad: act, repuesto: +d.v, cantidad: 1 }).catch(toastError);
};
A.rmrep = function (d) { escribir('QuitarRepuesto', { plan: pid(), id: +d.v }).catch(toastError); };

/* ---- duplicar y carga masiva ---- */
A.dupok = function (d, t) {
  var n = String(PN.n || '').trim(); if (!n) { PN.err = true; panel(); return; }
  var o = PN; t.classList.add('cp-load');
  api('Duplicar', { plan: o.pid, nombre: n, conActivos: !!o.inc }).then(function (r) {
    closePanel(); U.multi = {};
    return recargarLista().then(function () { return abrirPlan(r.PLAN_ID); }).then(function () { toast(r.CODIGO + ' creado como copia de ' + o.codigo + '.'); });
  }).catch(function (e) { t.classList.remove('cp-load'); toastError(e); });
};
A.bulkload = function () { openPanel({ t: 'bulk' }); };
A.bulkgo = function () {
  closePanel();
  var url = CFG.base_ + 'View/Mantenimiento/Planes/CargaMasivaPlanes.aspx';
  if (window.SigmaModal) {
    SigmaModal.open({ url: url, title: 'Carga masiva de planes', width: 1100, initialHeight: 720 });
    var al = function () { document.removeEventListener('sigma:modalclosed', al); recargarLista(); };
    document.addEventListener('sigma:modalclosed', al);
  } else window.open(url, '_blank');
};

/* =====================================================================
   Edición en línea
   ===================================================================== */
function valorCombo(span) { var h = span.querySelector('input[type=hidden]'); return h ? h.value : ''; }
function alCambiar(e) {
  var t = e.target; if (!$('#cpRoot').contains(t)) return;
  if (t.id === 'cpPeriodo') { var pv = t.getAttribute('data-valor'); if (pv && pv !== U.periodo) { U.periodo = pv; if (TABR[U.tab] && TABR[U.tab].periodo) TABR[U.tab].periodo(); } return; }
  var span = t.closest('[data-cb]');
  if (span && t.type === 'text') return comboCambio(span);
  if (t.hasAttribute('data-fe')) return fechaCambio(t);
  if (t.hasAttribute('data-pf')) return planCampo(t.getAttribute('data-pf'), t.value);
  if (t.hasAttribute('data-pp') && PN && PN.d) return setPP(t, t.type === 'checkbox' ? t.checked : t.value);
  if (t.hasAttribute('data-iv')) return ivCampo(t, t.getAttribute('data-iv'), t.type === 'checkbox' ? (t.checked ? '1' : '0') : t.value);
  if (t.hasAttribute('data-act')) return actCampo(t, t.getAttribute('data-act'), t.type === 'checkbox' ? t.checked : t.value);
  if (t.hasAttribute('data-fk')) return fqCampo(t.getAttribute('data-i'), t.getAttribute('data-fk'), t.value);
  if (t.hasAttribute('data-rq')) return repCantidad(t);
  if (t.hasAttribute('data-pv') && PN) { var k = t.getAttribute('data-pv'); PN[k] = t.type === 'checkbox' ? t.checked : t.value; if (PN.t === 'pick' && k === 'only') { PN.lista = null; panel(); cargarProcs(); } else if (t.type === 'checkbox') panel(); return; }
  if (t.hasAttribute('data-mv') && MD) { MD[t.getAttribute('data-mv')] = t.value; return; }
  if (TABR[U.tab] && TABR[U.tab].cambio) TABR[U.tab].cambio(t, e);
}
function comboCambio(span) {
  var v = valorCombo(span), nombre = span.getAttribute('data-cb');
  if (nombre === 'cpPlanta') { if (+v !== U.planta) { U.planta = +v || 0; pintarCascara(); recargarTodo(); } return; }
  if (span.hasAttribute('data-ar')) return asignarTodas(v);
  if (span.hasAttribute('data-pp') && PN && PN.d) return setPP(span, v);
  if (span.hasAttribute('data-pf')) return planCampo(span.getAttribute('data-pf'), v);
  if (span.hasAttribute('data-iv')) return ivCampo(span, span.getAttribute('data-iv'), v);
  if (span.hasAttribute('data-act')) return actCampo(span, span.getAttribute('data-act'), v);
  if (span.hasAttribute('data-fk')) return fqCampo(span.getAttribute('data-i'), span.getAttribute('data-fk'), v);
  if (span.hasAttribute('data-pq') && PN) {
    var k = span.getAttribute('data-pq');
    if (k === 'area') { PN.fa = v; panel(); return; }
    var a = +span.getAttribute('data-v'); if (PN.sel[a]) PN.sel[a][k] = v; return;
  }
  if (span.hasAttribute('data-ppq') && POP) { POP[span.getAttribute('data-ppq')] = v; return; }
  if (TABR[U.tab] && TABR[U.tab].combo) TABR[U.tab].combo(span, v);
}
function asignarTodas(v) {
  var list = ints().filter(function (i) { return String(i.RESPONSABLE_ID || '') !== String(v || ''); });
  if (!v || !list.length) return;
  list.forEach(function (i, k) { escribir('GuardarIntervencion', { plan: pid(), hito: i.HITO_ID, campo: 'responsable', valor: String(v) }, k < list.length - 1 ? { sinFicha: true } : {}).catch(toastError); });
}
function planCampo(campo, v) {
  var p = F.plan;
  var actual = { nombre: p.NOMBRE, planta: p.PLANTA_ID, tipo: p.TIPO_ID, modelo: p.MODELO_ID }[campo];
  if (sinCambio(actual, v)) return;
  if (campo === 'nombre' && !String(v).trim()) { render(); toast('El plan necesita un nombre.'); return; }
  if (campo === 'planta' && !String(v).trim()) { render(); return; }
  escribir('GuardarPlan', { plan: pid(), campo: campo, valor: String(v == null ? '' : v) }).catch(toastError);
}
function ivCampo(el, campo, v) {
  var id = +el.getAttribute('data-i'), h = hById(id); if (!h) return;
  var actual = { nombre: h.NOMBRE, descripcion: h.DESCRIPCION, habilitado: h.HABILITADO ? '1' : '0', parada: h.PARADA ? '1' : '0', overhaul: h.OVERHAUL ? '1' : '0', tipo: h.OT_TIPO_ID, prioridad: h.OT_PRIORIDAD_ID, responsable: h.RESPONSABLE_ID, grupo: h.GRUPO_ID, duracion: h.DURACION }[campo];
  if (campo === 'duracion') { var hh = parseFloat(String(v).replace(',', '.')); if (!(hh > 0)) { el.classList.add('cp-err'); noGuardado('La duración debe ser mayor que 0.'); return; } v = String(Math.round(hh * 60)); }
  if (campo === 'nombre' && !String(v).trim()) { el.classList.add('cp-err'); noGuardado('La intervención necesita un nombre.'); return; }
  if (sinCambio(actual, v)) return;
  escribir('GuardarIntervencion', { plan: pid(), hito: id, campo: campo, valor: String(v == null ? '' : v) }).then(function () {
    if (campo === 'tipo' && /^nuevo:/i.test(String(v))) return recargarCatalogos().then(function () { render(); toast('Tipo de OT creado: ya está disponible para todas las intervenciones.'); });
  }).catch(toastError);
}
function actCampo(el, campo, v) {
  var id = +el.getAttribute('data-c'), ac = aById(id); if (!ac) return;
  var a = ac.a, kp = 'perm' + ac.h.CODIGO + a.CODIGO;
  if (campo === 'permisoOn') {
    if (v) { if (!a.PERMISO) { U.pend[kp] = true; render(); var c = $('.cp-ac[data-ac="' + id + '"] [data-act="permiso"] input[type=text]'); if (c) c.focus(); } return; }
    delete U.pend[kp]; render();
    if (a.PERMISO) escribir('GuardarActividad', { plan: pid(), actividad: id, campo: 'permiso', valor: '' }).catch(toastError);
    return;
  }
  if (campo === 'permiso') { if (!v || sinCambio(a.PERMISO_TIPO_ID, v)) return; escribir('GuardarActividad', { plan: pid(), actividad: id, campo: 'permiso', valor: String(v) }).then(function () { delete U.pend[kp]; render(); }).catch(toastError); return; }
  if (campo === 'obligatoria' || campo === 'parada') v = v ? '1' : '0';
  var actual = { nombre: a.NOMBRE, descripcion: a.DESCRIPCION, obligatoria: a.OBLIGATORIA ? '1' : '0', parada: a.PARADA ? '1' : '0', duracion: a.DURACION }[campo];
  if (campo === 'duracion') { if (String(v).trim() === '') v = ''; else { var hh = parseFloat(String(v).replace(',', '.')); if (!(hh > 0)) { el.classList.add('cp-err'); noGuardado('La duración debe ser mayor que 0.'); return; } v = String(Math.round(hh * 60)); } }
  if (campo === 'nombre' && !String(v).trim()) { el.classList.add('cp-err'); noGuardado('La actividad necesita un nombre.'); return; }
  if (sinCambio(actual, v)) return;
  escribir('GuardarActividad', { plan: pid(), actividad: id, campo: campo, valor: String(v) }).catch(toastError);
}
function fqCampo(hid, k, v) {
  var h = hById(hid); if (!h) return;
  var f = fqDe2(h), nv = k === 'hour' ? v : +v;
  if (k !== 'hour' && (v === '' || isNaN(nv))) return;
  if (sinCambio(f[k], nv)) return;
  fqEditar(hid, function (x) { x[k] = nv; if (k === 'wd') x.days = [nv]; });
}
function fechaCambio(t) {
  var b = t.getAttribute('data-fe'), txt = t.value.trim(), v = deDN(txt);
  if (txt && !v) { t.parentNode.classList.add('cp-err'); return; }
  var m = /^([fx]):(\d+):(\w+)$/.exec(b);
  if (!m) { if (TABR[U.tab] && TABR[U.tab].fecha) TABR[U.tab].fecha(b, v, t); else if (PN && PANELS[PN.t] && PN.fecha) PN.fecha(b, v); return; }
  var h = hById(m[2]); if (!h) return;
  if (m[1] === 'x') { var x = U.vp['exc' + h.CODIGO]; if (x) { x[m[3]] = v; } return; }
  var f = fqDe2(h);
  if (m[3] === 'add') { if (v && !f.dates.some(function (x) { return x.fecha === v; })) fqEditar(h.HITO_ID, function (y) { y.dates.push({ fecha: v, hora: y.hour || '' }); }); else t.value = ''; return; }
  if (m[3] === 'from' && !v) { render(); return; }
  if (sinCambio(f[m[3]], v)) return;
  fqEditar(h.HITO_ID, function (y) { y[m[3]] = v; });
}
function repCantidad(t) {
  var id = +t.getAttribute('data-rq'), act = +t.getAttribute('data-c'), rep = +t.getAttribute('data-rep'), q = parseFloat(String(t.value).replace(',', '.'));
  var ac = aById(act), r = ac ? (ac.a.REPUESTOS || []).filter(function (x) { return x.ID === id; })[0] : null;
  if (!r || !(q > 0) || +r.CANTIDAD === q) { if (r && !(q > 0)) t.value = +r.CANTIDAD; return; }
  /* No hay «actualizar cantidad»: se quita y se vuelve a agregar con la nueva. */
  escribir('QuitarRepuesto', { plan: pid(), id: id }, { sinFicha: true }).then(function () { return escribir('AgregarRepuesto', { plan: pid(), actividad: aById(act) ? act : act, repuesto: rep, cantidad: q }); }).catch(function (e) { toastError(e); recargarFicha(); });
}
var repT = 0;
function alEscribir(e) {
  var t = e.target; if (!$('#cpRoot').contains(t)) return;
  if (t.id === 'cpQ') { U.q = t.value; var b = $('#cpPlb'); if (b) b.innerHTML = listBody(); return; }
  if (t.hasAttribute('data-repq')) {
    var q = t.value.trim(), act = +t.getAttribute('data-repq');
    if (!POP || POP.t !== 'rep' || POP.act !== act) openPop(t.closest('.cp-srch2'), { t: 'rep', act: act, input: t, q: q, lista: [] });
    POP.q = q; clearTimeout(repT);
    if (q.length < 2) { POP.lista = []; POP.cargando = false; paintPop(); return; }
    POP.cargando = true; paintPop();
    repT = setTimeout(function () { api('Repuestos', { filtro: q }).then(function (r) { if (POP && POP.t === 'rep' && POP.q === q) { POP.lista = r.repuestos; POP.cargando = false; paintPop(); } }).catch(function () { }); }, 250);
    return;
  }
  if (t.hasAttribute('data-pp') && PN && PN.d && t.type !== 'checkbox') { setPP(t, t.value); return; }
  if (t.hasAttribute('data-xp') && PN && PN.xf) { PN.xf[t.getAttribute('data-xp')] = t.value; return; }
  if (t.hasAttribute('data-xv')) { var h = hById(t.getAttribute('data-i')); if (h && U.vp['exc' + h.CODIGO]) U.vp['exc' + h.CODIGO][t.getAttribute('data-xv')] = t.value; return; }
  if (t.hasAttribute('data-pv') && PN && t.type !== 'checkbox') { PN[t.getAttribute('data-pv')] = t.value; if (t.getAttribute('data-pv') === 'q') panel(); return; }
  if (t.hasAttribute('data-ppv') && POP) { POP[t.getAttribute('data-ppv')] = t.value; if (POP.err && t.value.trim()) { POP.err = false; paintPop(); } return; }
  if (t.hasAttribute('data-mv') && MD) { MD[t.getAttribute('data-mv')] = t.value; return; }
  if (t.getAttribute('data-pf') === 'nombre') { t.classList.toggle('cp-err', !t.value.trim()); return; }
  if (TABR[U.tab] && TABR[U.tab].escribir) TABR[U.tab].escribir(t, e);
}

/* =====================================================================
   Eventos
   ===================================================================== */
function alClic(e) {
  var root = $('#cpRoot'); if (!root || !root.contains(e.target)) { if (POP && !e.target.closest('#sgComboLista')) cerrarPop(); return; }
  if (POP && !e.target.closest('#cpPop') && !e.target.closest('[data-a="more"],[data-a="newplan"],[data-a="useshared"]') && !e.target.closest('#sgComboLista') && !e.target.closest('[data-repq]')) cerrarPop();
  var t = e.target.closest('[data-a]'); if (!t || !root.contains(t)) return;
  if (t.disabled) return;
  var a = t.getAttribute('data-a'), fn = A[a] || (TABR[U.tab] && TABR[U.tab].A && TABR[U.tab].A[a]);
  if (!fn) return;
  if (t.tagName === 'A' && t.getAttribute('href')) return;
  var esCbx = { mul: 1, eqpick: 1, eqall: 1, exsel: 1, exall: 1, covtg: 1, covall: 1, calpers: 1 };
  if (t.type === 'checkbox' && !esCbx[a]) return;
  if (!(t.type === 'checkbox' && esCbx[a])) e.preventDefault();
  fn(t.dataset, t, e);
}
function alTeclado(e) {
  var root = $('#cpRoot'); if (!root) return;
  if (e.key === 'Escape') {
    if (document.getElementById('sgComboLista') && !document.getElementById('sgComboLista').hidden) return;
    if (POP) { var el = POP.el; cerrarPop(); if (el && el.focus) el.focus(); e.preventDefault(); return; }
    if (MD && !MD.busy) { closeModal(); e.preventDefault(); return; }
    if (PN) { closePanel(); e.preventDefault(); return; }
  }
  if (!root.contains(e.target)) return;
  if ((e.key === 'Enter' || e.key === ' ') && e.target.getAttribute('role') === 'button' && e.target.tagName !== 'BUTTON' && e.target.tagName !== 'A') { e.preventDefault(); e.target.click(); return; }
  if (e.key === 'Enter' && e.target.tagName === 'INPUT' && e.target.type !== 'checkbox') {
    if (e.target.hasAttribute('data-ppv')) { e.preventDefault(); A.npok(); return; }
    if (e.target.closest('[data-cb]')) return;
    e.preventDefault(); e.target.blur();   // el «change» guarda; Enter no envía el form del master
  }
  if (e.target.getAttribute('role') === 'tab' && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) {
    var tabs = $$('#cpTabs [role=tab]'), i = tabs.indexOf(e.target), j = (i + (e.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
    tabs[j].focus(); tabs[j].click(); e.preventDefault();
  }
  if (MD && e.key === 'Tab') { var fs = $$('#cpLayer2 button, #cpLayer2 input, #cpLayer2 textarea').filter(function (x) { return !x.disabled; }); if (fs.length) { var first = fs[0], last = fs[fs.length - 1]; if (e.shiftKey && document.activeElement === first) { last.focus(); e.preventDefault(); } else if (!e.shiftKey && document.activeElement === last) { first.focus(); e.preventDefault(); } } }
}

/* =====================================================================
   Arranque
   ===================================================================== */
function recargarTodo() {
  U.lista = null; render();
  return Promise.all([recargarLista(), recargarKpis()]).then(function () {
    if (U.plan && !U.lista.some(function (p) { return p.PLAN_ID === U.plan; })) { U.plan = null; F = null; }
    Object.keys(TABR).forEach(function (k) { if (TABR[k].planta) TABR[k].planta(); });
    render(); hashOut();
  }).catch(toastError);
}
function iniciar() {
  var root = $('#cpRoot'); if (!root) return;
  if (!CFG.puedeVer) { $('#cpBody').innerHTML = '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('shield', 20) + '</span><b>No tienes permiso para ver el Centro de Planificación</b>Pide el permiso «Ver planes de mantenimiento» a quien administra tu empresa.</div>'; return; }
  document.addEventListener('click', alClic);
  document.addEventListener('change', alCambiar);
  document.addEventListener('input', alEscribir);
  document.addEventListener('keydown', alTeclado);
  window.addEventListener('resize', function () { if (POP) posPop(); });
  window.addEventListener('scroll', function () { if (POP) posPop(); }, true);
  if ((CFG.plantas || []).length === 1) U.planta = 0;
  var h = hashIn();
  if (h.tab) U.tab = TABS.some(function (x) { return x[0] === h.tab; }) ? h.tab : 'planes';
  if (h.lib) U.lib.v = h.lib;
  pintarCascara(); render();
  Promise.all([api('Catalogos', {}), api('Lista', { planta: U.planta })]).then(function (r) {
    U.cat = r[0]; if (r[0].hoy) TODAY = r[0].hoy;
    U.lista = r[1].planes; U.conteos = r[1].conteos; U.permisos = r[1].permisos || {};
    $('#cpHeroAcc').dataset.ok = ''; pintarCascara();
    var sel = h.plan ? U.lista.filter(function (p) { return mismoQ(p.Q, h.plan); })[0] : null;
    if (U.tab !== 'planes' && TABR[U.tab] && TABR[U.tab].entrar) TABR[U.tab].entrar({});
    if (sel) abrirPlan(sel.PLAN_ID, { top: false, paso: +h.paso >= 1 && +h.paso <= 5 ? +h.paso : 0 }); else render();
    if (U.tab !== 'cobertura' && TABR.cobertura) cobCargar();
    recargarKpis();
  }).catch(function (e) { toastError(e); $('#cpBody').innerHTML = '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudo cargar el Centro de Planificación</b>' + esc(e.message) + '<button type="button" class="cp-btn cp-out cp-sm" onclick="location.reload()">Reintentar</button></div>'; });
}

/* =====================================================================
   EJECUCIONES (§10.4): lista, semana y mes + generar OT + reprogramar
   ===================================================================== */
var EX = U.ex = { f: 'att', vista: 'lista', plan: 0, activo: 0, par: false, q: '', sel: {}, wk: 0, mo: 0, filas: null, rango: null, cargando: false };
var EXF = [['att', 'Requieren atención'], ['venc', 'Vencidas'], ['atr', 'Atrasadas'], ['disp', 'Disponibles'], ['fut', 'Futuras'], ['ot', 'Con OT'], ['cer', 'Cerradas'], ['all', 'Todas']];
var SITX = { venc: ['venc', 'Vencida'], atr: ['atr', 'Atrasada'], disp: ['disp', 'Disponible'], fut: ['fut', 'Futura'], cer: ['ot-c', 'Cerrada'], ot: ['ot-a', 'Con OT'] };
var OTX = { 1: ['ot-a', 'OT abierta'], 2: ['ot-e', 'OT en ejecución'], 3: ['ot-w', 'OT en espera de cierre'], 4: ['ot-c', 'OT cerrada'] };
var xd = function (x) { return dIso(x.FECHA_PROGRAMADA); };
var xlim = function (x) { return dIso(x.FECHA_LIMITE || x.FECHA_PROGRAMADA); };
var xdisp = function (x) { return dIso(x.FECHA_DISPONIBLE || x.FECHA_PROGRAMADA); };
function sit(x) {
  if (x.ESTADO_ID === 6 || x.ESTADO_ID === 7) return 'can';
  if (x.ESTADO_ID === 4 || x.ESTADO_ID === 5 || x.SITUACION === 'CERRADA') return 'cer';
  if (x.ORDEN_TRABAJO_ID) return 'ot';
  return { VENCIDA: 'venc', ATRASADA: 'atr', DISPONIBLE: 'disp', FUTURA: 'fut' }[x.SITUACION] || 'fut';
}
var canGen = function (x) { var s = sit(x); return U.permisos.generarOt && (s === 'venc' || s === 'atr' || s === 'disp'); };
function sitChip(x) {
  var s = sit(x);
  if (s === 'ot') { var o = OTX[x.ORDEN_TRABAJO_ESTADO_ID] || OTX[1]; return '<span class="cp-st cp-' + o[0] + '"><i></i>' + o[1] + '</span>'; }
  var c = SITX[s] || SITX.fut; return '<span class="cp-st cp-' + c[0] + '"><i></i>' + c[1] + '</span>';
}
function exMatch(x, f) { var s = sit(x); if (s === 'can') return false; if (f === 'all') return true; if (f === 'att') return s === 'venc' || s === 'atr'; return s === f; }
function exFiltered(sinSit) {
  var q = nrm(EX.q);
  return (EX.filas || []).filter(function (x) {
    return (sinSit || exMatch(x, EX.f)) && sit(x) !== 'can' && (!EX.plan || x.PLAN_ID === EX.plan) && (!EX.activo || x.ACTIVO_ID === EX.activo) && (!EX.par || x.REQUIERE_PARADA)
      && (!q || nrm([x.ACTIVO_CODIGO, x.ACTIVO_NOMBRE, x.HITO_NOMBRE, x.PLAN_CODIGO, x.PLAN_NOMBRE, x.ORDEN_TRABAJO_CORRELATIVO || ''].join(' ')).indexOf(q) >= 0);
  });
}
var exTags = function (x) { return (x.REQUIERE_PARADA ? '<span class="cp-tg cp-w">Parada</span>' : '') + (x.ES_OVERHAUL ? '<span class="cp-tg cp-p">Overhaul</span>' : '') + '<span class="cp-tg">' + pl(+x.ACTIVIDADES || 0, 'actividad', 'actividades') + '</span>'; };
var periodoFin = function () { var p = U.periodo; return iso(new Date(+p.slice(0, 4), +p.slice(5, 7), 0, 12)); };
var mesIni = function (off) { var d = D(TODAY.slice(0, 8) + '01'); d.setDate(1); d.setMonth(d.getMonth() + off); return iso(d); };
function periodoOff() { var p = U.periodo, h = D(TODAY); return (+p.slice(0, 4) - h.getFullYear()) * 12 + (+p.slice(5, 7) - 1 - h.getMonth()); }

function exCargar(forzar) {
  var desde, hasta;
  if (EX.vista === 'semana') { desde = weekStart(EX.wk); hasta = addD(desde, 6); }
  else if (EX.vista === 'mes') { var m0 = mesIni(EX.mo); desde = addD(m0, -7); hasta = addD(m0, 40); }
  else { desde = addD(TODAY, -45); var pf = periodoFin(); hasta = pf > addD(TODAY, 120) ? pf : addD(TODAY, 120); }
  var key = [desde, hasta, U.planta].join('|');
  if (!forzar && EX.rango === key && EX.filas) return Promise.resolve();
  EX.cargando = true; if (U.tab === 'ejecuciones') render();
  var base = { planta: U.planta, plan: 0, activo: 0 };
  var rec = api('Ejecuciones', Object.assign({ desde: desde, hasta: hasta, abiertas: false }, base));
  var abiertas = EX.vista === 'lista' ? api('Ejecuciones', Object.assign({ desde: '', hasta: hasta, abiertas: true }, base)) : Promise.resolve({ filas: [] });
  return Promise.all([rec, abiertas]).then(function (r) {
    var m = {}; r[1].filas.concat(r[0].filas).forEach(function (f) { m[f.PMO_ID] = f; });
    EX.filas = Object.keys(m).map(function (k) { return m[k]; }); EX.rango = key; EX.cargando = false;
    Object.keys(EX.sel).forEach(function (k) { if (!EX.filas.some(function (f) { return f.TOKEN === k && canGen(f); })) delete EX.sel[k]; });
    if (U.tab === 'ejecuciones') render();
  }).catch(function (e) { EX.cargando = false; if (U.tab === 'ejecuciones') render(); toastError(e); });
}
var weekStart = function (off) { return addD(addD(TODAY, -(wday(TODAY) - 1)), off * 7); };
var evCls = function (x) { var s = sit(x); return s === 'venc' || s === 'atr' || s === 'disp' || s === 'cer' ? 'cp-' + s : ''; };

function execHTML() {
  if (!EX.filas) return skel();
  var base = exFiltered(true), cnt = function (k) { return base.filter(function (x) { return exMatch(x, k); }).length; };
  var planes = (U.lista || []).filter(function (p) { return p.ESTADO === 'ACTIVO' || p.ESTADO === 'CAMBIOS'; });
  var activos = {}; EX.filas.forEach(function (x) { activos[x.ACTIVO_ID] = x.ACTIVO_CODIGO + ' · ' + x.ACTIVO_NOMBRE; });
  var views = '<div class="cp-segc" role="group" aria-label="Vista">' + [['lista', 'Lista'], ['semana', 'Semana'], ['mes', 'Mes']].map(function (v) { return '<button type="button" data-a="exview" data-v="' + v[0] + '" aria-pressed="' + (EX.vista === v[0]) + '">' + v[1] + '</button>'; }).join('') + '</div>';
  var filtros = '<div class="cp-ex-f"><span style="min-width:200px">' + combo('cpExPlan', [{ id: 0, n: 'Todos los planes' }].concat(planes.map(function (p) { return { id: p.PLAN_ID, n: p.CODIGO + ' · ' + p.NOMBRE }; })), EX.plan, { etiqueta: 'Plan', ph: 'Todos los planes', data: ' data-ef="plan"' }) + '</span>' +
    '<span style="min-width:200px">' + combo('cpExAct', [{ id: 0, n: 'Todos los activos' }].concat(Object.keys(activos).sort().map(function (k) { return { id: +k, n: activos[k] }; })), EX.activo, { etiqueta: 'Activo', ph: 'Todos los activos', data: ' data-ef="activo"' }) + '</span>' +
    '<label class="cp-sw"><input type="checkbox" data-ef="par"' + (EX.par ? ' checked' : '') + '><i></i>Solo con parada</label>' +
    '<label class="cp-srch2" style="height:34px;min-width:220px;flex:1;max-width:320px">' + ic('search', 14) + '<input id="cpExQ" value="' + esc(EX.q) + '" placeholder="Activo, intervención u OT" aria-label="Buscar ejecuciones" autocomplete="off"></label>' +
    (EX.plan || EX.activo || EX.par || EX.q ? '<button type="button" class="cp-lnk" data-a="exclear">Limpiar filtros</button>' : '') + '</div>';
  var chips = EX.vista === 'lista' ? '<div class="cp-chips">' + EXF.map(function (x) { var k = x[0]; return '<button type="button" class="cp-fc" data-a="exf" data-v="' + k + '" aria-pressed="' + (EX.f === k) + '">' + (k === 'att' || k === 'venc' ? '<i style="background:var(--red)"></i>' : k === 'atr' ? '<i style="background:var(--amber)"></i>' : k === 'disp' ? '<i style="background:var(--sigma-cyan-dark)"></i>' : '') + x[1] + '<b>' + cnt(k) + '</b></button>'; }).join('') + '</div>'
    : '<div class="cp-legend"><span><i style="background:var(--red)"></i>Vencida</span><span><i style="background:var(--amber)"></i>Atrasada</span><span><i style="background:var(--sigma-cyan-dark)"></i>Disponible</span><span><i style="background:var(--faint)"></i>Futura o con OT</span><span class="cp-lh">La barra de cada día es la carga en horas estimadas.</span></div>';
  var body = EX.vista === 'semana' ? weekHTML() : EX.vista === 'mes' ? monthHTML() : listExHTML();
  return '<div class="cp-card cp-ex-card"><div class="cp-ex-bar">' + views + filtros + '</div>' + chips + '</div>' + (EX.cargando ? '<div class="cp-sk" style="height:60px;margin-top:12px"></div>' : '') + body;
}
function listExHTML() {
  var all = exFiltered().sort(function (a, b) { return xd(a).localeCompare(xd(b)) || a.ACTIVO_CODIGO.localeCompare(b.ACTIVO_CODIGO); }), list = all.slice(0, 80);
  var selectable = list.filter(canGen), allSel = selectable.length && selectable.every(function (x) { return EX.sel[x.TOKEN]; });
  var nSel = Object.keys(EX.sel).length, hh = EX.filas.filter(function (x) { return EX.sel[x.TOKEN]; }).reduce(function (s, x) { return s + (+x.DURACION_ESTIMADA_MINUTO || 0); }, 0);
  var cols = 'grid-template-columns:24px 150px minmax(0,1fr) minmax(0,1.25fr) 150px 26px 104px';
  if (!all.length) return '<div class="cp-card"><div class="cp-empty" style="border:0"><span class="cp-ei">' + ic('check', 20) + '</span><b>' + (EX.f === 'att' ? 'Nada requiere atención' : 'Ninguna ejecución coincide') + '</b>' + (EX.f === 'att' ? 'No hay ejecuciones vencidas ni atrasadas con estos filtros.' : 'Prueba con otra situación, plan o activo.') + (EX.f !== 'all' ? '<button type="button" class="cp-btn cp-out cp-sm" data-a="exf" data-v="all">Ver todas</button>' : '') + '</div></div>';
  return '<div class="cp-card cp-exl" style="padding:8px 10px"><div class="cp-rows"><div class="cp-rw cp-h" style="' + cols + '"><span>' + (selectable.length ? '<input type="checkbox" class="cp-cbx" data-a="exall"' + (allSel ? ' checked' : '') + ' aria-label="Seleccionar todas las disponibles">' : '') + '</span><span>Fecha</span><span>Activo</span><span>Plan · intervención</span><span>Situación</span><span class="cp-c-r"></span><span></span></div>' +
    list.map(function (x) {
      var g = canGen(x), s = sit(x), orig = x.FUE_REPROGRAMADA && x.FECHA_ORIGINAL ? 'Reprog. · era ' + fD(dIso(x.FECHA_ORIGINAL)) : s === 'venc' ? 'Venció ' + rel(xlim(x)) : rel(xd(x)) + ' · vence ' + fD(xlim(x));
      return '<div class="cp-rw cp-click' + (EX.sel[x.TOKEN] ? ' cp-rsel' : '') + '" style="' + cols + '" data-a="exopen" data-k="' + esc(x.TOKEN) + '" role="button" tabindex="0">' +
        '<span>' + (g ? '<input type="checkbox" class="cp-cbx" data-a="exsel" data-k="' + esc(x.TOKEN) + '"' + (EX.sel[x.TOKEN] ? ' checked' : '') + ' aria-label="Seleccionar ' + esc(x.ACTIVO_CODIGO) + ' ' + fD(xd(x)) + '">' : '<input type="checkbox" class="cp-cbx" disabled title="' + (x.ORDEN_TRABAJO_ID ? 'Ya tiene OT' : 'Disponible desde el ' + fD(xdisp(x))) + '" aria-label="No seleccionable">') + '</span>' +
        '<span class="cp-dt"><b>' + fD(xd(x)) + '</b><small>' + orig + '</small></span>' +
        '<span class="cp-s"><b>' + esc(x.ACTIVO_NOMBRE) + '</b><small>' + esc(x.ACTIVO_CODIGO) + (x.COMPONENTE_NOMBRE ? ' · ' + esc(x.COMPONENTE_NOMBRE) : '') + (x.VALOR_MEDIDOR_OBJETIVO ? ' · al llegar a ' + fN(x.VALOR_MEDIDOR_OBJETIVO) : '') + '</small></span>' +
        '<span class="cp-s"><b>' + esc(x.HITO_NOMBRE) + '</b><small>' + esc(x.PLAN_CODIGO) + ' · ' + esc(x.PLAN_NOMBRE) + '</small><span class="cp-tgs2">' + exTags(x) + '</span></span>' +
        '<span>' + sitChip(x) + '</span><span class="cp-c-r">' + avatar(x.RESPONSABLE_NOMBRE) + '</span>' +
        '<span style="text-align:right">' + (x.ORDEN_TRABAJO_ID ? '<a class="cp-btn cp-out cp-xs" href="' + esc(x.OT_URL) + '" target="_blank" rel="noopener">OT-' + x.ORDEN_TRABAJO_CORRELATIVO + '</a>' : g ? '<button type="button" class="cp-btn cp-sec cp-xs" data-a="gen1" data-k="' + esc(x.TOKEN) + '">Generar OT</button>' : '<span style="font-size:11.5px;color:var(--muted)">desde ' + fD(xdisp(x)) + '</span>') + '</span></div>';
    }).join('') + '</div>' +
    (all.length > list.length ? '<p class="cp-more-n">Mostrando ' + list.length + ' de ' + all.length + '. Afina con los filtros para ver el resto.</p>' : '') +
    (nSel ? '<div class="cp-exbulk"><b>' + pl(nSel, 'seleccionada', 'seleccionadas') + '</b><span>' + fH(hh) + ' estimadas</span><span style="flex:1"></span><button type="button" class="cp-btn cp-plain cp-sm" data-a="exclr">Quitar selección</button><button type="button" class="cp-btn cp-sec cp-sm" data-a="genbulk">' + ic('plus', 15) + 'Generar ' + nSel + ' OT</button></div>' : '') + '</div>';
}
function weekHTML() {
  var ws = weekStart(EX.wk), days = [0, 1, 2, 3, 4, 5, 6].map(function (k) { return addD(ws, k); }), all = exFiltered(true);
  var per = days.map(function (d) { return all.filter(function (x) { return xd(x) === d; }).sort(function (a, b) { return a.ACTIVO_CODIGO.localeCompare(b.ACTIVO_CODIGO); }); });
  var dur = function (xs) { return xs.reduce(function (s, x) { return s + (+x.DURACION_ESTIMADA_MINUTO || 0); }, 0); };
  var tot = dur([].concat.apply([], per)), cap = 16 * 60;
  var lab = D(ws).getDate() + ' ' + MESC[D(ws).getMonth()] + ' – ' + D(days[6]).getDate() + ' ' + MESC[D(days[6]).getMonth()] + ' ' + D(days[6]).getFullYear();
  return '<div class="cp-cal-bar"><div class="cp-nv"><button type="button" class="cp-ibx" data-a="wk" data-v="-1" aria-label="Semana anterior">' + ic('chevl', 16) + '</button><button type="button" class="cp-btn cp-plain cp-xs" data-a="wk" data-v="0">Esta semana</button><button type="button" class="cp-ibx" data-a="wk" data-v="1" aria-label="Semana siguiente">' + ic('chev', 16) + '</button></div><b>' + lab + '</b><span class="cp-sm">' + pl([].concat.apply([], per).length, 'ejecución', 'ejecuciones') + ' · ' + fH(tot) + ' estimadas</span></div>' +
    '<div class="cp-wk">' + days.map(function (d, k) {
      var h = dur(per[k]);
      return '<div class="cp-wd' + (d === TODAY ? ' cp-tdy' : '') + '"><div class="cp-wd-h"><b>' + DIAC[wday(d)] + ' ' + D(d).getDate() + '</b><small>' + (per[k].length ? per[k].length + ' · ' + fH(h) : 'Sin carga') + '</small><div class="cp-ld" title="' + fH(h) + ' de ' + fH(cap) + ' de capacidad"><i style="width:' + Math.min(100, h / cap * 100) + '%' + (h > cap ? ';background:var(--amber)' : '') + '"></i></div></div><div class="cp-wd-b">' +
        (per[k].map(function (x) { return '<button type="button" class="cp-ev ' + evCls(x) + '" data-a="exopen" data-k="' + esc(x.TOKEN) + '"><b>' + esc(x.ACTIVO_CODIGO) + ' · ' + esc(x.HITO_NOMBRE) + '</b><span>' + fH(x.DURACION_ESTIMADA_MINUTO) + ' · ' + (x.ORDEN_TRABAJO_ID ? 'OT-' + x.ORDEN_TRABAJO_CORRELATIVO : (SITX[sit(x)] || SITX.fut)[1]) + (x.REQUIERE_PARADA ? ' · parada' : '') + '</span></button>'; }).join('') || '<span class="cp-wd-e">—</span>') + '</div></div>';
    }).join('') + '</div>';
}
function monthHTML() {
  var m0 = mesIni(EX.mo), md = D(m0), all = exFiltered(true);
  var first = addD(m0, -(wday(m0) - 1)), lastIso = iso(new Date(md.getFullYear(), md.getMonth() + 1, 0, 12));
  var weeks = []; for (var s = first; s <= lastIso; s = addD(s, 7)) weeks.push(s);
  var cell = function (d) {
    var ev = all.filter(function (x) { return xd(x) === d; }), out = d.slice(0, 7) !== m0.slice(0, 7);
    return '<div class="' + (out ? 'cp-out' : '') + (d === TODAY ? ' cp-tdy' : '') + '"><span class="cp-dn">' + D(d).getDate() + '</span>' +
      ev.slice(0, 3).map(function (x) { return '<button type="button" class="cp-ev ' + evCls(x) + '" data-a="exopen" data-k="' + esc(x.TOKEN) + '" title="' + esc(x.ACTIVO_CODIGO + ' · ' + x.HITO_NOMBRE) + '">' + esc(x.ACTIVO_CODIGO) + ' · ' + esc(x.HITO_NOMBRE) + '</button>'; }).join('') +
      (ev.length > 3 ? '<button type="button" class="cp-lnk" style="font-size:11px" data-a="mowk" data-v="' + d + '">+' + (ev.length - 3) + ' más</button>' : '') + '</div>';
  };
  return '<div class="cp-cal-bar"><div class="cp-nv"><button type="button" class="cp-ibx" data-a="mo" data-v="-1" aria-label="Mes anterior">' + ic('chevl', 16) + '</button><button type="button" class="cp-btn cp-plain cp-xs" data-a="mo" data-v="0">Este mes</button><button type="button" class="cp-ibx" data-a="mo" data-v="1" aria-label="Mes siguiente">' + ic('chev', 16) + '</button></div><b style="text-transform:capitalize">' + MES[md.getMonth()] + ' ' + md.getFullYear() + '</b><span class="cp-sm">' + pl(all.filter(function (x) { return xd(x).slice(0, 7) === m0.slice(0, 7); }).length, 'ejecución en el mes', 'ejecuciones en el mes') + '</span></div>' +
    '<div class="cp-mo-w"><div class="cp-mo">' + ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom', 'Semana'].map(function (h) { return '<div class="cp-hd">' + h + '</div>'; }).join('') +
    weeks.map(function (w) { var ds = [0, 1, 2, 3, 4, 5, 6].map(function (k) { return addD(w, k); }), ev = all.filter(function (x) { return xd(x) >= w && xd(x) <= ds[6]; }); return ds.map(cell).join('') + '<div class="cp-wh"><span><b>' + fH(ev.reduce(function (s, x) { return s + (+x.DURACION_ESTIMADA_MINUTO || 0); }, 0)) + '</b>' + ev.length + ' ejec.</span></div>'; }).join('') + '</div></div>';
}

/* ---- panel de una ejecución y resultado de la generación ---- */
var exDe = function (tok) { return (EX.filas || []).filter(function (x) { return x.TOKEN === tok; })[0]; };
PANELS.ex = function () {
  var x = PN.x || exDe(PN.k);
  if (!x) return { t: 'Ejecución', b: '<div class="cp-empty">Esta ejecución ya no existe en el horizonte.</div>', f: '' };
  var s = sit(x), g = canGen(x), fact = function (k, v) { return '<div><span>' + k + '</span><b>' + v + '</b></div>'; };
  var rp = PN.rp ? '<div class="cp-blk" id="cpRpf"><div class="cp-blk-h"><h4>Reprogramar</h4></div><div class="cp-grid2c"><div class="cp-fld"><label>Fecha nueva</label>' + fecha('r:d', PN.nd, { etiqueta: 'Fecha nueva', err: PN.err && !PN.nd }) + (PN.err && !PN.nd ? mc('', 'Elige la fecha nueva.') : '') + '</div><div class="cp-fld"><label>Fecha original</label><div class="cp-ro">' + fDL(dIso(x.FECHA_ORIGINAL) || xd(x)) + '</div></div></div>' +
    '<div class="cp-fld"><label for="cpRpw">Motivo <small>obligatorio</small></label><textarea id="cpRpw" class="cp-inp' + (PN.err && String(PN.why || '').trim().length < 5 ? ' cp-err' : '') + '" rows="2" data-pv="why" placeholder="Ej.: El activo está en producción hasta el cierre de la campaña">' + esc(PN.why || '') + '</textarea>' + (PN.err && String(PN.why || '').trim().length < 5 ? mc('', 'Escribe el motivo: queda en el historial de la ejecución.') : '') + '</div>' +
    mc('i', 'El cumplimiento se sigue midiendo contra la fecha original (' + fDN(dIso(x.FECHA_ORIGINAL) || xd(x)) + ').', 'help') + (PN.err2 ? mc('', esc(PN.err2)) : '') +
    '<div style="display:flex;justify-content:flex-end;gap:8px"><button type="button" class="cp-btn cp-plain cp-sm" data-a="rpx">Cancelar</button><button type="button" class="cp-btn cp-pri cp-sm" data-a="rpok">Guardar reprogramación</button></div></div>' : '';
  var acts = PN.acts;
  var b = '<div class="cp-exh">' + sitChip(x) + (x.FUE_REPROGRAMADA ? '<span class="cp-tg cp-p">Reprogramada</span>' : '') + exTags(x) + '</div>' +
    (s === 'venc' ? '<div class="cp-bnr cp-e">' + ic('alert', 18) + '<span>Venció el ' + fDL(xlim(x)) + ' sin orden de trabajo.</span></div>' : s === 'atr' ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span>Atrasada: la fecha programada ya pasó. Vence el ' + fDL(xlim(x)) + '.</span></div>' : '') +
    '<div class="cp-facts">' + fact('Fecha programada', fDL(xd(x))) + fact('Disponible desde', fDL(xdisp(x))) + fact('Vence', fDL(xlim(x))) + (x.FUE_REPROGRAMADA && x.FECHA_ORIGINAL ? fact('Fecha original', fDL(dIso(x.FECHA_ORIGINAL))) : '') + (x.VALOR_MEDIDOR_OBJETIVO ? fact('Disparo', 'al llegar a ' + fN(x.VALOR_MEDIDOR_OBJETIVO)) : '') + fact('Duración estimada', fH(x.DURACION_ESTIMADA_MINUTO)) + fact('Responsable', x.RESPONSABLE_NOMBRE ? esc(x.RESPONSABLE_NOMBRE) : '<span style="color:var(--amber)">Sin responsable</span>') + fact('Activo', esc(x.ACTIVO_CODIGO) + '<small>' + esc(x.ACTIVO_NOMBRE) + '</small>') + '</div>' +
    '<div class="cp-blk"><div class="cp-blk-h"><h4>Qué se hará</h4><small>' + (acts ? pl(acts.length || 1, 'paso', 'pasos') + ' en la OT' : '') + '</small></div>' + (acts ? '<ol class="cp-olst">' + (acts.map(function (a) { return '<li><b>' + esc(a) + '</b></li>'; }).join('') || '<li>' + esc(x.HITO_NOMBRE) + ' (un solo paso)</li>') + '</ol>' : '<div class="cp-sk" style="height:60px"></div>') + '</div>' +
    (x.ORDEN_TRABAJO_ID ? '<div class="cp-prc"><span class="cp-pci">' + ic('clip', 17) + '</span><div style="min-width:0"><b>OT-' + x.ORDEN_TRABAJO_CORRELATIVO + ' · ' + ((OTX[x.ORDEN_TRABAJO_ESTADO_ID] || OTX[1])[1]) + '</b><small>Generada desde esta ejecución' + (x.RESPONSABLE_NOMBRE ? ' · asignada a ' + esc(x.RESPONSABLE_NOMBRE) : ' · sin asignar') + '</small></div><div class="cp-r"><a class="cp-btn cp-out cp-xs" href="' + esc(x.OT_URL) + '" target="_blank" rel="noopener">Abrir OT</a></div></div>' : '') + rp +
    '<button type="button" class="cp-lnk" data-a="gopl" data-p="' + x.PLAN_ID + '">' + ic('arrow', 14) + 'Ir al plan ' + esc(x.PLAN_CODIGO) + ' · ' + esc(x.PLAN_NOMBRE) + '</button>';
  var rep = !x.ORDEN_TRABAJO_ID && U.permisos.editar && (x.ESTADO_ID === 1 || x.ESTADO_ID === 2);
  var f = x.ORDEN_TRABAJO_ID ? '<button type="button" class="cp-btn cp-plain" data-a="pclose">Cerrar</button><span class="cp-r"><a class="cp-btn cp-out" href="' + esc(x.OT_URL) + '" target="_blank" rel="noopener">Abrir OT</a></span>'
    : '<button type="button" class="cp-btn cp-plain" data-a="pclose">Cerrar</button><span class="cp-r">' + (rep && !PN.rp ? '<button type="button" class="cp-btn cp-sec" data-a="rpopen">' + ic('calw', 16) + 'Reprogramar</button>' : '') + (U.permisos.generarOt ? '<button type="button" class="cp-btn cp-sec" data-a="gen1" data-k="' + esc(x.TOKEN) + '"' + (g ? '' : ' disabled title="Disponible desde el ' + fD(xdisp(x)) + '"') + '>' + ic('plus', 16) + 'Generar OT</button>' : '') + '</span>' + (g ? '' : '<p class="cp-msg cp-i" style="width:100%">' + ic('help', 13) + '<span>Se puede generar la OT desde el ' + fDL(xdisp(x)) + '.</span></p>');
  return { t: esc(x.HITO_NOMBRE) + ' · ' + esc(x.ACTIVO_CODIGO), s: esc(x.PLAN_CODIGO) + ' · ' + esc(x.PLAN_NOMBRE), b: b, f: f, w: 'n' };
};
PANELS.gen = function () {
  var r = PN.res, ok = r.filter(function (x) { return x.r === 'ok'; }).length, ya = r.filter(function (x) { return x.r === 'ya'; }).length, no = r.filter(function (x) { return x.r === 'no'; }).length;
  return { t: 'Resultado de la generación', s: pl(r.length, 'ejecución', 'ejecuciones'), w: 'n',
    b: '<div class="cp-imp4"><div class="cp-t"><b class="cp-tn">' + ok + '</b><span>Generadas</span><small>OT nuevas, asignadas</small></div><div><b class="cp-tn">' + ya + '</b><span>Ya existían</span><small>no se duplican</small></div><div class="cp-c"><b class="cp-tn">' + no + '</b><span>Rechazadas</span><small>revisa el motivo</small></div></div>' +
      '<div class="cp-res">' + r.map(function (y) { var x = exDe(y.token) || PN.filasPrev[y.token] || {}; return '<div class="cp-' + (y.r === 'no' ? 'no' : y.r === 'ok' ? 'ok' : 'eq2') + '">' + ic(y.r === 'ok' ? 'check' : y.r === 'no' ? 'x' : 'clip', 15) + '<span><b>' + esc((x.ACTIVO_CODIGO || '') + ' · ' + (x.HITO_NOMBRE || '')) + '</b> · ' + (x.FECHA_PROGRAMADA ? fD(xd(x)) : '') + '<small style="display:block;color:' + (y.r === 'no' ? 'var(--red)' : 'var(--muted)') + '">' + esc(y.r === 'ok' ? 'OT-' + y.ot + ' generada' : y.r === 'ya' ? 'Ya tenía la OT-' + y.ot : y.detalle) + '</small></span>' + (y.url && y.r !== 'no' ? '<a class="cp-btn cp-out cp-xs" href="' + esc(y.url) + '" target="_blank" rel="noopener">Abrir OT</a>' : '<span></span>') + '</div>'; }).join('') + '</div>' +
      (no ? mc('i', 'Las rechazadas siguen en Ejecuciones. Puedes reprogramarlas o volver a intentarlo.', 'help') : ''),
    f: '<span class="cp-r"><button type="button" class="cp-btn cp-plain" data-a="pclose">Listo</button></span>' };
};
function generar(tokens, boton) {
  if (boton) boton.classList.add('cp-load');
  var prev = {}; tokens.forEach(function (t) { var x = exDe(t); if (x) prev[t] = x; });
  api('GenerarOt', { tokens: tokens.join(',') }).then(function (r) {
    EX.sel = {};
    openPanel({ t: 'gen', res: r.resultados, filasPrev: prev });
    return Promise.all([exCargar(true), recargarKpis(), recargarLista()]);
  }).catch(function (e) { if (boton) boton.classList.remove('cp-load'); toastError(e); });
}

/* =====================================================================
   CUMPLIMIENTO (§10.5)
   ===================================================================== */
var CU = U.cum = { d: null, cargando: false };
function cumCargar() {
  CU.cargando = true; if (U.tab === 'cumplimiento') render();
  return api('Cumplimiento', { planta: U.planta, periodo: U.periodo }).then(function (r) { CU.d = r; CU.cargando = false; if (U.tab === 'cumplimiento') render(); }).catch(function (e) { CU.cargando = false; if (U.tab === 'cumplimiento') render(); toastError(e); });
}
function cumHTML() {
  var d = CU.d; if (!d) return skel();
  var an = d.anio, pe = d.periodo, kc = function (cls, i, v, l, sm) { return '<div class="cp-kpb ' + cls + '" style="cursor:default"><span class="cp-i">' + ic(i, 19) + '</span><span><b class="cp-tn">' + v + '</b><small>' + l + '</small>' + (sm ? '<small class="cp-k2">' + sm + '</small>' : '') + '</span></div>'; };
  var pcT = function (x) { return x && x.pc != null ? x.pc + ' %' : '—'; };
  var per = new Date(d.desde + 'T12:00:00'), perT = MES[per.getMonth()] + ' ' + per.getFullYear();
  var H = 164, ylab = [100, 75, 50, 25, 0];
  var tbl = function (rows, kind) {
    return '<div class="cp-rows">' + (rows.map(function (o) {
      var pc = +o.pc || 0, sinOt = Math.max(0, o.programadas - o.cumplidas);
      return '<div class="cp-rw' + (kind === 'plan' ? ' cp-click' : '') + '" style="grid-template-columns:minmax(0,1fr) 120px 46px 62px"' + (kind === 'plan' ? ' data-a="cumplan" data-v="' + o.id + '" role="button" tabindex="0"' : '') + '><span class="cp-s"><b>' + esc(o.nombre) + '</b><small>' + esc(o.codigo) + ' · ' + o.cumplidas + ' de ' + o.programadas + ' cumplidas' + (o.vencidas ? ' · <span style="color:var(--red)">' + o.vencidas + ' vencidas</span>' : '') + '</small></span><span class="cp-mbar"><i class="' + (pc < 90 ? 'cp-low' : '') + '" style="width:' + Math.min(100, pc) + '%"></i></span><b class="cp-tn" style="text-align:right;' + (pc < 90 ? 'color:var(--amber)' : '') + '">' + pc + ' %</b><span style="text-align:right">' + (kind === 'plan' ? ic('chev', 15) : '') + '</span></div>';
    }).join('') || '<div class="cp-empty">Sin ejecuciones programadas en el período.</div>') + '</div>';
  };
  return '<div class="cp-kp">' + kc('', 'trend', pcT(an), 'Cumplimiento del año', 'Meta 90 %') + kc(pe && pe.pc != null && pe.pc < 90 ? 'cp-r' : 'cp-c', 'check', pcT(pe), 'Período · ' + perT, pe ? pe.aTiempo + ' de ' + pe.programadas + ' a tiempo' : 'Aún no empieza') + kc(pe && pe.vencidas ? 'cp-r' : '', 'alert', pe ? pe.vencidas : '—', 'Vencidas sin OT', 'Restan al cumplimiento') + kc('cp-p', 'calw', pe ? pe.reprogramadas : '—', 'Reprogramadas', 'Se miden contra la fecha original') + '</div>' +
    '<div class="cp-cm"><section class="cp-card"><div class="cp-sc-h" style="margin-bottom:6px"><h3>Cumplimiento mensual</h3><small>A tiempo sobre programadas · línea punteada: meta 90 %</small></div>' +
    '<div class="cp-bars2" role="img" aria-label="Cumplimiento de los últimos meses. Meta 90 %.">' + ylab.map(function (v) { return '<span class="cp-yl" style="top:' + (10 + (100 - v) / 100 * H) + 'px">' + v + '</span>'; }).join('') + '<span class="cp-gl" style="top:' + (10 + .1 * H) + 'px"></span>' +
    d.meses.map(function (m) { var v = m.datos.pc, mm = D(m.mes + '-01'); return '<div class="cp-bc' + (v != null && v < 90 ? ' cp-low' : '') + '"><em>' + (v == null ? '—' : v + ' %') + '</em><i style="height:' + ((v || 0) / 100 * H) + 'px' + (m.actual ? ';opacity:.75' : '') + '"></i><span>' + MESC[mm.getMonth()] + (m.actual ? ' *' : '') + '</span></div>'; }).join('') + '</div>' +
    '<p class="cp-foot">* Mes en curso: se mide solo lo que ya venció. Una ejecución reprogramada cuenta en el mes de su fecha original.</p></section>' +
    '<section class="cp-card"><div class="cp-sc-h" style="margin-bottom:6px"><h3>Por plan</h3><small>Peor primero · ' + perT + '</small></div>' + tbl(d.planes, 'plan') + '</section></div>' +
    '<section class="cp-card"><div class="cp-sc-h" style="margin-bottom:6px"><h3>Por activo</h3><small>' + perT + '</small></div>' + tbl(d.activos.slice(0, 10), 'activo') + '</section>';
}

/* =====================================================================
   COBERTURA (§10.6)
   ===================================================================== */
var CB = U.cob = { lista: null, f: 'sin', tipo: '', q: '', sel: {}, sinPlan: null, cargando: false };
function cobCargar() {
  CB.cargando = true; if (U.tab === 'cobertura') render();
  return api('Cobertura', { planta: U.planta }).then(function (r) {
    CB.lista = r.activos; CB.cargando = false; CB.sinPlan = r.activos.filter(function (a) { return !(+a.PLANES); }).length;
    $('#cpTabs').innerHTML = tabsHTML(); if (U.tab === 'cobertura') render();
  }).catch(function (e) { CB.cargando = false; if (U.tab === 'cobertura') render(); toastError(e); });
}
function cobFiltrada() {
  var q = nrm(CB.q);
  return (CB.lista || []).filter(function (a) { var cub = +a.PLANES > 0; return (CB.f === 'all' || (CB.f === 'sin' ? !cub : cub)) && (!CB.tipo || a.TIPO === CB.tipo) && (!q || nrm(a.CODIGO + ' ' + a.NOMBRE + ' ' + (a.AREA || '')).indexOf(q) >= 0); });
}
function covHTML() {
  if (!CB.lista) return skel();
  var all = CB.lista, sin = all.filter(function (a) { return !(+a.PLANES); }).length, pc = all.length ? Math.round((all.length - sin) / all.length * 100) : 0;
  var list = cobFiltrada(), R = 34, C = 2 * Math.PI * R, nSel = Object.keys(CB.sel).length, allSel = list.length && list.every(function (a) { return CB.sel[a.ACTIVO_ID]; });
  var tipos = {}; all.forEach(function (a) { if (a.TIPO) tipos[a.TIPO] = 1; });
  var cols = 'grid-template-columns:24px minmax(0,1.3fr) minmax(0,1fr) minmax(0,.9fr) minmax(0,1fr)';
  return '<div class="cp-card cp-cov"><svg width="92" height="92" viewBox="0 0 92 92" role="img" aria-label="' + pc + ' % de los activos con plan"><circle cx="46" cy="46" r="' + R + '" fill="none" stroke="var(--line3)" stroke-width="10"/><circle cx="46" cy="46" r="' + R + '" fill="none" stroke="var(--sigma-cyan-dark)" stroke-width="10" stroke-linecap="round" stroke-dasharray="' + (C * pc / 100) + ' ' + C + '" transform="rotate(-90 46 46)"/><text x="46" y="51" text-anchor="middle" font-size="17" font-weight="800" fill="var(--ink)">' + pc + '%</text></svg>' +
    '<div style="min-width:0"><h3 style="font-size:16px;font-weight:800">' + (sin ? sin + ' ' + (sin === 1 ? 'activo no tiene' : 'activos no tienen') + ' plan preventivo' : 'Todos los activos tienen plan preventivo') + '</h3><p style="font-size:13px;color:var(--muted);margin-top:4px;max-width:70ch">' + (all.length - sin) + ' de ' + all.length + ' activos ' + (U.planta ? 'de ' + esc(plantaN(U.planta)) : 'de todas las plantas') + ' están en al menos un plan activo. Selecciona varios para crear un plan con ellos o sumarlos a uno existente.</p></div></div>' +
    '<div class="cp-card" style="padding:8px 10px"><div class="cp-ex-bar" style="padding:6px 6px 10px"><div class="cp-chips">' + [['sin', 'Sin plan'], ['con', 'Con plan'], ['all', 'Todos']].map(function (x) { return '<button type="button" class="cp-fc" data-a="covf" data-v="' + x[0] + '" aria-pressed="' + (CB.f === x[0]) + '">' + (x[0] === 'sin' ? '<i style="background:var(--red)"></i>' : '') + x[1] + '<b>' + (x[0] === 'sin' ? sin : x[0] === 'con' ? all.length - sin : all.length) + '</b></button>'; }).join('') + '</div>' +
    '<div class="cp-ex-f"><span style="min-width:200px">' + combo('cpCvTipo', [{ id: '', n: 'Cualquier tipo' }].concat(Object.keys(tipos).sort().map(function (t) { return { id: t, n: t }; })), CB.tipo, { etiqueta: 'Tipo de activo', ph: 'Cualquier tipo', data: ' data-cvf="tipo"' }) + '</span><label class="cp-srch2" style="height:34px;min-width:200px">' + ic('search', 14) + '<input id="cpCvq" value="' + esc(CB.q) + '" placeholder="Código, nombre o área" aria-label="Buscar activos" autocomplete="off"></label></div></div>' +
    '<div class="cp-rows"><div class="cp-rw cp-h" style="' + cols + '"><span>' + (list.length ? '<input type="checkbox" class="cp-cbx" data-a="covall"' + (allSel ? ' checked' : '') + ' aria-label="Seleccionar todos">' : '') + '</span><span>Activo</span><span>Tipo · modelo</span><span>Ubicación</span><span>Cobertura</span></div>' +
    (list.slice(0, 200).map(function (a) {
      return '<div class="cp-rw cp-click' + (CB.sel[a.ACTIVO_ID] ? ' cp-rsel' : '') + '" style="' + cols + '" data-a="covtg" data-v="' + a.ACTIVO_ID + '" role="button" tabindex="0"><span><input type="checkbox" class="cp-cbx" data-a="covtg" data-v="' + a.ACTIVO_ID + '"' + (CB.sel[a.ACTIVO_ID] ? ' checked' : '') + ' aria-label="Seleccionar ' + esc(a.CODIGO) + '"></span><span class="cp-s"><b>' + esc(a.NOMBRE) + '</b><small>' + esc(a.CODIGO) + '</small></span><span class="cp-s"><b style="font-weight:600">' + esc(a.TIPO || '—') + '</b><small>' + esc(a.MODELO || '') + '</small></span><span class="cp-s"><b style="font-weight:600">' + esc(a.AREA || '—') + '</b><small>' + esc(a.PLANTA || '') + '</small></span>' +
        '<span>' + (+a.PLANES ? String(a.PLANES_CODIGOS || '').split(', ').map(function (c) { return '<span class="cp-tg cp-c" style="margin-right:4px">' + esc(c) + '</span>'; }).join('') : '<span class="cp-atn cp-r"><i></i>Sin plan</span>') + '</span></div>';
    }).join('') || '<div class="cp-empty" style="margin:10px">' + ic('check', 18) + '<b>Nada que mostrar</b>Ningún activo coincide con estos filtros.</div>') + '</div>' +
    (list.length > 200 ? '<p class="cp-more-n">Mostrando 200 de ' + list.length + '. Afina con los filtros.</p>' : '') +
    (nSel ? '<div class="cp-exbulk"><b>' + pl(nSel, 'activo seleccionado', 'activos seleccionados') + '</b><span style="flex:1"></span><button type="button" class="cp-btn cp-plain cp-sm" data-a="covclr">Quitar selección</button><button type="button" class="cp-btn cp-out cp-sm" data-a="covadd">Agregar a un plan existente</button><button type="button" class="cp-btn cp-pri cp-sm" data-a="covnew">' + ic('plus', 15) + 'Crear plan con estos activos</button></div>' : '') + '</div>';
}
POPS.addto = function () {
  var ids = Object.keys(CB.sel), pls = (U.lista || []).filter(function (p) { return p.ESTADO !== 'INACTIVO'; });
  return '<div class="cp-ppt"><b>Agregar ' + pl(ids.length, 'activo', 'activos') + ' a…</b></div>' + (pls.map(function (p) { return '<button type="button" class="cp-mi2 cp-sh2" data-a="covto" data-p="' + p.PLAN_ID + '">' + ic('calw', 16) + '<span><b>' + esc(p.NOMBRE) + '</b><small>' + esc(p.CODIGO) + ' · ' + estado(p)[1] + '</small></span></button>'; }).join('') || '<p style="padding:10px;font-size:12.5px;color:var(--muted)">No hay planes a los que agregar.</p>');
};

/* ---- registro de las pestañas ---- */
TABR.ejecuciones = {
  html: execHTML,
  entrar: function (x) {
    if (x.plan != null) { EX.plan = x.plan; EX.f = x.f || 'all'; EX.q = ''; EX.par = false; EX.activo = 0; }
    else if (x.f) { EX.f = x.f; EX.plan = 0; EX.activo = 0; EX.q = ''; EX.par = false; }
    if (x.vista) { EX.vista = x.vista; if (x.vista === 'semana') EX.wk = 0; if (x.vista === 'lista') EX.f = x.f || EX.f; }
    EX.sel = {}; if (x.vista === 'mes') EX.mo = periodoOff();
    setTimeout(function () { exCargar(); }, 0);
  },
  periodo: function () { EX.mo = periodoOff(); EX.rango = null; exCargar(true); },
  planta: function () { EX.filas = null; EX.rango = null; if (U.tab === 'ejecuciones') exCargar(true); },
  cambio: function (t) {
    if (t.hasAttribute('data-ef') && t.type === 'checkbox') { EX[t.getAttribute('data-ef')] = t.checked; render(); }
  },
  combo: function (span, v) {
    if (span.hasAttribute('data-ef')) { EX[span.getAttribute('data-ef')] = +v || 0; render(); }
  },
  escribir: function (t) { if (t.id === 'cpExQ') { EX.q = t.value; render(); } },
  A: {}
};
var XA = TABR.ejecuciones.A;
XA.exview = function (d) { EX.vista = d.v; EX.sel = {}; if (d.v === 'mes') EX.mo = periodoOff(); if (d.v === 'semana') EX.wk = 0; exCargar(); render(); };
XA.exf = function (d) { EX.f = d.v; render(); };
XA.exclear = function () { EX.plan = 0; EX.activo = 0; EX.par = false; EX.q = ''; render(); };
XA.exsel = function (d, t, e) { if (e) e.stopPropagation(); if (EX.sel[d.k]) delete EX.sel[d.k]; else EX.sel[d.k] = 1; render(); };
XA.exall = function (d, t, e) { if (e) e.stopPropagation(); var l = exFiltered().filter(canGen), all = l.every(function (x) { return EX.sel[x.TOKEN]; }); l.forEach(function (x) { if (all) delete EX.sel[x.TOKEN]; else EX.sel[x.TOKEN] = 1; }); render(); };
XA.exclr = function () { EX.sel = {}; render(); };
XA.wk = function (d) { EX.wk = +d.v === 0 ? 0 : EX.wk + (+d.v); exCargar(); render(); };
XA.mo = function (d) { EX.mo = +d.v === 0 ? 0 : EX.mo + (+d.v); exCargar(); render(); };
XA.mowk = function (d) { EX.vista = 'semana'; var ws = addD(d.v, -(wday(d.v) - 1)); EX.wk = Math.round(diffD(weekStart(0), ws) / 7); exCargar(); render(); };
XA.exopen = function (d, t, e) {
  if (e && e.target.closest('.cp-cbx, .cp-btn[data-a="gen1"], a')) return;
  var x = exDe(d.k) || (F && F.proximas.filter(function (o) { return o.TOKEN === d.k; })[0]); if (!x) return;
  var ex = exDe(d.k);
  openPanel({ t: 'ex', k: d.k, x: ex || null, rp: false, why: '', nd: '', acts: null, fecha: function (b, v) { PN.nd = v; } });
  if (ex) api('EjecucionActividades', { hito: ex.HITO_ID }).then(function (r) { if (PN && PN.t === 'ex' && PN.k === d.k) { PN.acts = (r.actividades || []).map(upKeys).map(function (a) { return a.PAA_NOMBRE || a.NOMBRE || ''; }).filter(Boolean); panel(); } }).catch(function () { if (PN) { PN.acts = []; panel(); } });
  else { PN.acts = []; PN.x = null; panel(); exCargar().then(function () { if (PN && PN.t === 'ex') { PN.x = exDe(d.k); if (PN.x) A.exopen(d, t); } }); }
};
XA.rpopen = function () { PN.rp = true; PN.nd = ''; PN.err = false; PN.err2 = null; panel(); setTimeout(function () { goEl('#cpRpf'); }, 30); };
XA.rpx = function () { PN.rp = false; panel(); };
XA.rpok = function (d, t) {
  var x = PN.x || exDe(PN.k);
  if (!PN.nd || String(PN.why || '').trim().length < 5) { PN.err = true; panel(); return; }
  t.classList.add('cp-load');
  api('Reprogramar', { token: x.TOKEN, fecha: PN.nd, motivo: PN.why.trim() }).then(function () {
    closePanel(); toast('Ejecución reprogramada al ' + fDL(PN.nd) + '. El cumplimiento sigue midiendo la fecha original.');
    return Promise.all([exCargar(true), recargarKpis(), recargarLista(), U.plan ? recargarFicha() : null]);
  }).catch(function (e) { t.classList.remove('cp-load'); PN.err2 = e.message; PN.err = false; panel(); });
};
XA.gen1 = function (d, t, e) { if (e) e.stopPropagation(); generar([d.k], t); };
XA.genbulk = function (d, t) { generar(Object.keys(EX.sel), t); };
A.gopl = function (d) { closePanel(); var id = +d.p; recargarLista().then(function () { abrirPlan(id); }); };
A.exopen = XA.exopen; A.rpopen = XA.rpopen; A.rpx = XA.rpx; A.rpok = XA.rpok; A.gen1 = XA.gen1;

TABR.cumplimiento = {
  html: cumHTML, entrar: function () { setTimeout(function () { cumCargar(); }, 0); },
  periodo: function () { cumCargar(); }, planta: function () { CU.d = null; if (U.tab === 'cumplimiento') cumCargar(); },
  A: { cumplan: function (d) { U.tab = 'planes'; abrirPlan(+d.v); } }
};
TABR.cobertura = {
  html: covHTML, entrar: function () { setTimeout(function () { cobCargar(); }, 0); },
  planta: function () { CB.lista = null; CB.sel = {}; cobCargar(); },
  escribir: function (t) { if (t.id === 'cpCvq') { CB.q = t.value; render(); } },
  combo: function (span, v) { if (span.hasAttribute('data-cvf')) { CB.tipo = v; render(); } },
  A: {
    covf: function (d) { CB.f = d.v; render(); },
    covtg: function (d, t, e) { if (e && e.target.closest('.cp-cbx') && t.tagName !== 'INPUT') return; var id = +d.v; if (CB.sel[id]) delete CB.sel[id]; else CB.sel[id] = 1; render(); },
    covall: function () { var l = cobFiltrada(), all = l.every(function (a) { return CB.sel[a.ACTIVO_ID]; }); l.forEach(function (a) { if (all) delete CB.sel[a.ACTIVO_ID]; else CB.sel[a.ACTIVO_ID] = 1; }); render(); },
    covclr: function () { CB.sel = {}; render(); },
    covadd: function (d, t) { openPop(t, { t: 'addto' }); },
    covnew: function (d, t) {
      var ids = Object.keys(CB.sel).map(Number), txt = ids.map(function (i) { var a = CB.lista.filter(function (x) { return x.ACTIVO_ID === i; })[0]; return a ? a.CODIGO : i; }).slice(0, 6).join(', ') + (ids.length > 6 ? ' y ' + (ids.length - 6) + ' más' : '');
      openPop(t, { t: 'newplan', n: '', pl: U.planta || ((CFG.plantas || []).length === 1 ? CFG.plantas[0].id : ''), activos: ids, activosTxt: txt });
    },
    covto: function (d) {
      var id = +d.p, items = Object.keys(CB.sel).map(function (a) { return { activo: +a }; }); cerrarPop();
      api('AgregarActivos', { plan: id, items: JSON.stringify(items) }).then(function (r) {
        var bad = r.resultados.filter(function (x) { return !x.ok; }).length; CB.sel = {};
        toast(bad ? (items.length - bad) + ' agregados, ' + pl(bad, 'no calzó o ya estaba', 'no calzaron o ya estaban') + '.' : pl(items.length, 'activo agregado', 'activos agregados') + ' al plan.');
        return Promise.all([cobCargar(), recargarLista()]).then(function () { U.tab = 'planes'; return abrirPlan(id); });
      }).catch(toastError);
    }
  }
};

/* =====================================================================
   BIBLIOTECA (§10.7): procedimientos y calendarios compartidos
   ===================================================================== */
var LB = U.lib = { v: U.lib && U.lib.v || null, procs: null, cals: null, q: '', tipo: '', cargando: false };
var libVista = function () {
  var pp = U.permisos.procedimientos, pc = U.permisos.calendarios;
  if (LB.v === 'proc' && pp) return 'proc'; if (LB.v === 'cal' && pc) return 'cal';
  return pp ? 'proc' : pc ? 'cal' : null;
};
function libCargar() {
  var v = libVista(); if (!v) return Promise.resolve();
  if (v === 'proc' && !LB.procs) {
    LB.cargando = true;
    return api('Procedimientos', { filtro: '', tipo: 0 }).then(function (r) { LB.procs = (r.procedimientos || []).map(upKeys).map(function (x) { x.Q = x.Q; return x; }); LB.cargando = false; if (U.tab === 'biblioteca') render(); }).catch(function (e) { LB.cargando = false; toastError(e); });
  }
  if (v === 'cal' && !LB.cals) {
    LB.cargando = true;
    return api('Calendarios', {}).then(function (r) { LB.cals = r.calendarios; LB.nueva = r.nuevaUrl; LB.cargando = false; if (U.tab === 'biblioteca') render(); }).catch(function (e) { LB.cargando = false; toastError(e); });
  }
  return Promise.resolve();
}
function libHTML() {
  var v = libVista(), pp = U.permisos.procedimientos, pc = U.permisos.calendarios;
  if (!v) return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('shield', 20) + '</span><b>Sin acceso a la Biblioteca</b>Necesitas el permiso de procedimientos o el de programaciones.</div>';
  var nav = '<nav class="cp-lib-n" aria-label="Biblioteca">' +
    (pp ? '<button type="button" data-a="lib" data-v="proc" aria-pressed="' + (v === 'proc') + '">' + ic('clip', 17) + 'Procedimientos' + (LB.procs ? '<em>' + LB.procs.length + '</em>' : '') + '</button>' : '') +
    (pc ? '<button type="button" data-a="lib" data-v="cal" aria-pressed="' + (v === 'cal') + '">' + ic('link', 17) + 'Calendarios compartidos' + (LB.cals ? '<em>' + LB.cals.length + '</em>' : '') + '</button>' : '') +
    '<p class="cp-hint">' + (v === 'proc' ? 'Los procedimientos se usan en las actividades de los planes y en OT manuales.' : 'Un calendario compartido lo usan varios planes, tareas recurrentes o pautas. Cambiarlo cambia para todos.') + '</p></nav>';
  return '<div class="cp-lib">' + nav + '<div style="min-width:0;display:flex;flex-direction:column;gap:12px">' + (v === 'proc' ? procLibHTML() : calLibHTML()) + '</div></div>';
}
function procLibHTML() {
  if (!LB.procs) return skel();
  var q = nrm(LB.q), tipos = {}; LB.procs.forEach(function (p) { if (p.ACTIVO_TIPO_NOMBRE) tipos[p.ACTIVO_TIPO_NOMBRE] = 1; });
  var list = LB.procs.filter(function (p) { return (!q || nrm(p.PRC_CODIGO + ' ' + p.PRC_NOMBRE).indexOf(q) >= 0) && (!LB.tipo || p.ACTIVO_TIPO_NOMBRE === LB.tipo); });
  var cols = 'grid-template-columns:96px minmax(0,1.6fr) minmax(0,1fr) 64px 80px 100px';
  return '<div class="cp-card" style="padding:8px 10px"><div class="cp-ex-bar" style="padding:6px 6px 10px"><label class="cp-srch2" style="height:36px;flex:1;min-width:200px;max-width:380px">' + ic('search', 14) + '<input id="cpLq" value="' + esc(LB.q) + '" placeholder="Código o nombre del procedimiento" aria-label="Buscar procedimientos" autocomplete="off"></label>' +
    '<span style="min-width:220px">' + combo('cpLbTipo', [{ id: '', n: 'Todos los tipos' }].concat(Object.keys(tipos).sort().map(function (t) { return { id: t, n: t }; })), LB.tipo, { etiqueta: 'Tipo de activo', ph: 'Todos los tipos', data: ' data-lbf="tipo"' }) + '</span>' +
    (U.permisos.editarProcedimientos ? '<span class="cp-r"><button type="button" class="cp-btn cp-pri cp-sm" data-a="newproc">' + ic('plus', 15) + 'Nuevo procedimiento</button></span>' : '') + '</div>' +
    '<div class="cp-rows"><div class="cp-rw cp-h" style="' + cols + '"><span>Código</span><span>Nombre</span><span>Tipo de activo</span><span>Pasos</span><span>Duración</span><span></span></div>' +
    (list.map(function (p) {
      return '<div class="cp-rw cp-click" style="' + cols + '" data-a="editproc" data-id="' + p.PRC_ID + '" role="button" tabindex="0"><span class="cp-mono">' + esc(p.PRC_CODIGO) + ' v' + (p.PRC_VERSION || 1) + '</span><span class="cp-s"><b>' + esc(p.PRC_NOMBRE) + '</b><small>' + (p.PERMISO_TIPO_NOMBRE ? esc(p.PERMISO_TIPO_NOMBRE) : 'Sin permiso de trabajo') + '</small></span><span class="cp-s"><b style="font-weight:600">' + esc(p.ACTIVO_TIPO_NOMBRE || 'Cualquier tipo') + '</b></span><span class="cp-tn">' + (+p.PASOS || 0) + '</span><span class="cp-tn">' + (p.PRC_DURACION_ESTIMADA_MINUTO ? fH(p.PRC_DURACION_ESTIMADA_MINUTO) : '—') + '</span><span style="text-align:right"><button type="button" class="cp-btn cp-plain cp-xs" data-a="editproc" data-id="' + p.PRC_ID + '">' + (U.permisos.editarProcedimientos ? 'Editar' : 'Ver') + '</button></span></div>';
    }).join('') || '<div class="cp-empty" style="margin:10px">' + ic('search', 18) + '<b>Ningún procedimiento coincide</b><button type="button" class="cp-lnk" data-a="lqclear">Limpiar búsqueda</button></div>') + '</div></div>';
}
function calLibHTML() {
  if (!LB.cals) return skel();
  var ed = U.permisos.editar;
  return '<div style="display:flex;justify-content:flex-end">' + (ed ? '<button type="button" class="cp-btn cp-pri cp-sm" data-a="newcal">' + ic('plus', 15) + 'Nuevo calendario</button>' : '') + '</div>' +
    (LB.cals.map(function (c) {
      var n = c.usos.length;
      return '<div class="cp-card cp-shc"><div class="cp-shc-h"><span class="cp-pci2">' + ic('link', 18) + '</span><div style="min-width:0;flex:1"><b>' + esc(c.nombre) + '</b><small>' + esc(c.tipo || '') + (c.detalle ? ' · ' + esc(c.detalle) : '') + '</small></div><div class="cp-r"><button type="button" class="cp-btn cp-out cp-xs" data-a="libcal" data-id="' + c.id + '">' + (ed ? 'Editar' : 'Ver') + '</button></div></div>' +
        '<div class="cp-shc-b"><div><span class="cp-lb2">Próximas fechas</span><div>' + (c.fechas.length ? c.fechas.map(function (d) { return '<span class="cp-tg">' + fD(d) + '</span>'; }).join(' ') : '<span style="font-size:12px;color:var(--muted)">' + (c.tipoCodigo === 'MEDIDOR' ? 'Se dispara por medidor' : c.tipoCodigo === 'CONDICION' ? 'Se dispara por condición' : 'Sin fechas próximas') + '</span>') + '</div></div>' +
        '<div><span class="cp-lb2">Dónde se usa · ' + n + '</span><div class="cp-uses">' + c.usos.map(function (u) { return '<span class="cp-tg ' + (u.origen === 'Plan' ? 'cp-c' : '') + '">' + esc(u.origen) + ' · ' + esc(u.nombre) + '</span>'; }).join('') + (n ? '' : '<span style="font-size:12px;color:var(--muted)">Nadie lo usa</span>') + '</div></div></div></div>';
    }).join('') || '<div class="cp-empty">' + ic('link', 18) + '<b>Aún no hay calendarios compartidos</b>Se crean en Programaciones y se pueden usar desde cualquier intervención.</div>');
}
function abrirModalSitio(url, titulo, alCerrar) {
  if (window.SigmaModal) {
    SigmaModal.open({ url: url, title: titulo, width: 1000, initialHeight: 700 });
    var al = function () { document.removeEventListener('sigma:modalclosed', al); alCerrar(); };
    document.addEventListener('sigma:modalclosed', al);
  } else window.open(url, '_blank');
}
var PROC_URL = function (q) { return CFG.base_ + 'View/Mantenimiento/Procedimientos/Procedimiento.aspx' + (q ? '?query=' + q : ''); };
TABR.biblioteca = {
  html: libHTML,
  entrar: function (x) { if (x.lib) LB.v = x.lib; setTimeout(function () { libCargar(); }, 0); },
  escribir: function (t) { if (t.id === 'cpLq') { LB.q = t.value; render(); } },
  combo: function (span, v) { if (span.hasAttribute('data-lbf')) { LB[span.getAttribute('data-lbf')] = v; render(); } },
  A: {
    lib: function (d) { LB.v = d.v; hashOut(); libCargar(); render(); },
    lqclear: function () { LB.q = ''; LB.tipo = ''; render(); },
    newproc: function () { abrirProc(0); },
    editproc: function (d) { abrirProc(+d.id); },
    newcal: function () { abrirCal(); },
    libcal: function (d) { abrirCal(+d.id); }
  }
};
function recargarCatalogos() { return api('Catalogos', {}).then(function (c) { U.cat = c; }).catch(function () { }); }
A.newproc = TABR.biblioteca.A.newproc;

/* =====================================================================
   Nuevo / editar procedimiento y nuevo calendario: paneles laterales,
   sin salir del Centro (no en modal)
   ===================================================================== */
function setPP(el, v) {
  var path = el.getAttribute('data-pp'), d = PN.d, m;
  if ((m = /^s:(\d+)\.(\w+)$/.exec(path))) { var s = d.pasos[+m[1]]; if (s) s[m[2]] = v; }
  else if (/^f\./.test(path)) { var k = path.slice(2); d.f[k] = (k === 'hour' || k === 'mmode' || k === 'rep' || k === 't') ? v : (v === '' ? '' : isNaN(+v) ? v : +v); if (k === 't') panel(); }
  else { d[path] = v; if (path === 'pq') panel(); if (path === 'planta' && PN.t === 'cal') { d.area = ''; d.activo = ''; d.grupo = ''; calAlcance(); } }
}
var ppTxt = function (path, val, o) {
  o = o || {};
  return '<input class="cp-inp' + (o.err ? ' cp-err' : '') + '" data-pp="' + path + '" value="' + esc(val == null ? '' : val) + '"' + (o.ph ? ' placeholder="' + esc(o.ph) + '"' : '') + (o.max ? ' maxlength="' + o.max + '"' : '') + (o.af ? ' data-autofocus="1"' : '') + (o.lbl ? ' aria-label="' + esc(o.lbl) + '"' : '') + ' autocomplete="off">';
};
var pasoVacio = function () { return { id: 0, nombre: '', instruccion: '', ctrl: false, ev: false, dur: '', med: false }; };

function abrirProc(id) {
  openPanel({ t: 'proc', d: { id: 0, nombre: '', tipo: '', permiso: '', dur: '', descripcion: '', pasos: [pasoVacio()] }, err: false, cargando: id > 0, solo: !U.permisos.editarProcedimientos });
  if (!id) return;
  api('ProcedimientoDetalle', { id: id }).then(function (r) {
    if (!PN || PN.t !== 'proc') return;
    var h = upKeys(r.cabecera);
    PN.d = { id: id, codigo: h.PRC_CODIGO, version: h.PRC_VERSION || 1, nombre: h.PRC_NOMBRE || '', tipo: h.PRC_ACTIVO_TIPO || '', permiso: h.PRC_REQUIERE_PERMISO ? (h.PRC_PERMISO_TRABAJO_TIPO || '') : '',
      dur: h.PRC_DURACION_ESTIMADA_MINUTO ? hrs(h.PRC_DURACION_ESTIMADA_MINUTO) : '', descripcion: h.PRC_DESCRIPCION || '',
      pasos: (r.pasos || []).map(upKeys).map(function (s) { return { id: s.PPA_ID, nombre: s.PPA_NOMBRE || '', instruccion: s.PPA_INSTRUCCION || '', ctrl: !!s.PPA_ES_PUNTO_CONTROL, ev: !!s.PPA_REQUIERE_EVIDENCIA, dur: s.PPA_DURACION_ESTIMADA_MINUTO || '', med: !!s.PPA_REQUIERE_MEDICION, medN: s.VARIABLE_NOMBRE || '' }; }) };
    if (!PN.d.pasos.length) PN.d.pasos.push(pasoVacio());
    PN.cargando = false; panel();
  }).catch(function (e) { closePanel(); toastError(e); });
}
PANELS.proc = function () {
  var d = PN.d, e = PN.err, ro = PN.solo, dis = ro ? ' disabled' : '';
  if (PN.cargando) return { t: 'Procedimiento', s: 'Biblioteca · Procedimientos', w: 'w', b: '<div class="cp-sk" style="height:40px"></div><div class="cp-sk" style="height:260px"></div>' };
  var sumMin = d.pasos.reduce(function (s, x) { return s + (+x.dur || 0); }, 0);
  var paso = function (s, k) {
    return '<div class="cp-stp"><span class="cp-o">' + (k + 1) + '</span><div class="cp-b">' + ppTxt('s:' + k + '.nombre', s.nombre, { err: e && !String(s.nombre).trim(), ph: 'Nombre del paso', lbl: 'Nombre del paso ' + (k + 1), max: 200 }) + (e && !String(s.nombre).trim() ? mc('', 'El paso necesita un nombre.') : '') +
      '<textarea class="cp-inp" rows="1" data-pp="s:' + k + '.instruccion" placeholder="Instrucción para el técnico" aria-label="Instrucción del paso ' + (k + 1) + '"' + dis + '>' + esc(s.instruccion) + '</textarea>' +
      '<div class="cp-fl2"><label class="cp-sw"><input type="checkbox" data-pp="s:' + k + '.ctrl"' + (s.ctrl ? ' checked' : '') + dis + '><i></i>Punto de control</label><label class="cp-sw"><input type="checkbox" data-pp="s:' + k + '.ev"' + (s.ev ? ' checked' : '') + dis + '><i></i>Requiere evidencia</label>' +
      (s.med ? '<span class="cp-tg cp-c">Medición' + (s.medN ? ': ' + esc(s.medN) : '') + '</span>' : '') + '<span class="cp-unit" style="width:120px"><input class="cp-inp" type="number" min="0" data-pp="s:' + k + '.dur" value="' + esc(s.dur) + '" aria-label="Duración del paso"' + dis + ' style="height:32px"><span class="cp-u" style="height:32px">min</span></span></div></div>' +
      (ro ? '<span></span>' : '<div class="cp-x"><button type="button" class="cp-ibx" data-a="stmv" data-v="' + k + '" data-d="-1"' + (k ? '' : ' disabled') + ' aria-label="Subir paso">' + ic('chev', 14).replace('<svg', '<svg style="transform:rotate(-90deg)"') + '</button><button type="button" class="cp-ibx" data-a="stmv" data-v="' + k + '" data-d="1"' + (k < d.pasos.length - 1 ? '' : ' disabled') + ' aria-label="Bajar paso">' + ic('chev', 14).replace('<svg', '<svg style="transform:rotate(90deg)"') + '</button><button type="button" class="cp-ibx cp-dn" data-a="strm" data-v="' + k + '"' + (d.pasos.length > 1 ? '' : ' disabled') + ' aria-label="Quitar paso">' + ic('x', 14) + '</button></div>') + '</div>';
  };
  return { t: d.id ? esc(d.codigo) + ' v' + d.version + ' · ' + esc(d.nombre || 'Procedimiento') : 'Nuevo procedimiento', s: 'Biblioteca · Procedimientos', w: 'w',
    b: (d.id ? mc('i', 'Editar cambia este procedimiento tal como está: las OT ya generadas conservan los pasos que copiaron.', 'help') : '') +
      '<div class="cp-grid4c"><div class="cp-fld" style="grid-column:span 2"><label>Nombre</label>' + ppTxt('nombre', d.nombre, { err: e && !String(d.nombre).trim(), af: true, max: 400, lbl: 'Nombre' }) + (e && !String(d.nombre).trim() ? mc('', 'El procedimiento necesita un nombre.') : '') + '</div>' +
      '<div class="cp-fld"><label>Tipo de activo</label>' + combo('cpPrTipo', [{ id: '', n: 'Cualquier tipo' }].concat(catL('tipos')), d.tipo, { etiqueta: 'Tipo de activo', ph: 'Cualquier tipo', dis: ro, data: ' data-pp="tipo"', clave: 'cpPrTipos' }) + '</div>' +
      '<div class="cp-fld"><label>Duración estimada</label><div class="cp-unit"><input class="cp-inp" type="number" min="0.25" step="0.25" data-pp="dur" value="' + esc(d.dur) + '"' + dis + ' aria-label="Duración estimada"><span class="cp-u">horas</span></div></div>' +
      '<div class="cp-fld" style="grid-column:span 2"><label>Permiso de trabajo</label>' + combo('cpPrPerm', [{ id: '', n: 'No requiere permiso' }].concat(catL('permisos')), d.permiso, { etiqueta: 'Permiso de trabajo', ph: 'No requiere permiso', dis: ro, data: ' data-pp="permiso"', clave: 'cpPrPermisos' }) + '</div></div>' +
      '<div class="cp-blk-h" style="margin:4px 0 -4px"><h4>Pasos · ' + d.pasos.length + '</h4><small>Los pasos suman ' + fN(sumMin) + ' min.</small></div><div class="cp-steps">' + d.pasos.map(paso).join('') + '</div>' +
      (ro ? '' : '<button type="button" class="cp-btn cp-out cp-sm" style="align-self:flex-start" data-a="stadd">' + ic('plus', 15) + 'Agregar paso</button>') + (PN.err2 ? mc('', esc(PN.err2)) : ''),
    f: ro ? '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button></span>' : (e ? '<span class="cp-msg">' + ic('alert', 13) + '<span>Revisa los campos marcados.</span></span>' : '') + '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><button type="button" class="cp-btn cp-pri" data-a="prsave">' + ic('check', 16) + 'Guardar procedimiento</button></span>' };
};
A.stadd = function () { PN.d.pasos.push(pasoVacio()); panel(); var l = $$('#cpLayer .cp-stp .cp-b > .cp-inp:first-child'); if (l.length) l[l.length - 1].focus(); };
A.strm = function (d) { PN.d.pasos.splice(+d.v, 1); panel(); };
A.stmv = function (d) { var p = PN.d.pasos, k = +d.v, j = k + (+d.d); if (j < 0 || j >= p.length) return; var x = p[k]; p[k] = p[j]; p[j] = x; panel(); };
A.prsave = function (d, t) {
  var x = PN.d;
  if (!String(x.nombre).trim() || x.pasos.some(function (s) { return !String(s.nombre).trim(); })) { PN.err = true; PN.err2 = null; panel(); return; }
  var dur = parseFloat(String(x.dur).replace(',', '.'));
  t.classList.add('cp-load');
  api('GuardarProcedimiento', { datos: JSON.stringify({ id: x.id, nombre: String(x.nombre).trim(), tipo: +x.tipo || 0, permiso: +x.permiso || 0, descripcion: x.descripcion || '', duracion: dur > 0 ? Math.round(dur * 60) : 0,
    pasos: x.pasos.map(function (s) { return { id: s.id || 0, nombre: s.nombre, instruccion: s.instruccion, ctrl: !!s.ctrl, ev: !!s.ev, duracion: +s.dur || 0 }; }) }) }).then(function () {
    closePanel(); toast('Procedimiento ' + (x.id ? 'guardado' : 'creado') + '.'); LB.procs = null; return libCargar();
  }).catch(function (e) { t.classList.remove('cp-load'); PN.err = false; PN.err2 = e.message; panel(); });
};


/* =====================================================================
   NUEVO CALENDARIO COMPARTIDO: los seis pasos del asistente de
   Programación (Información general · Alcance · Asignación · Frecuencia ·
   Exclusiones · Revisar), en un panel lateral del Centro.
   ===================================================================== */
var CAL_PASOS = ['Información general', 'Alcance', 'Asignación', 'Frecuencia', 'Exclusiones', 'Revisar'];
var CAL_TIPOS = [{ id: 'cal', n: 'Calendario (días y horas fijas)' }, { id: 'int', n: 'Intervalo de tiempo' }, { id: 'fec', n: 'Fechas puntuales' }];
var CAL_ASIG = [['nadie', 'Sin asignar'], ['persona', 'Personas'], ['grupo', 'Grupo de trabajo']];
var calCat = null;
var calCat = null;
function calVacio() {
  return { id: 0, usos: 0, nombre: '', zona: '', planta: (CFG.plantas || []).length === 1 ? CFG.plantas[0].id : (U.planta || ''), area: '', activo: '', modo: 'nadie', personas: {}, grupo: '',
    anticipada: true, atrasada: true, politica: '', genera: true, excl: [],
    f: { t: 'cal', rep: 'm', n: 1, days: [], mmode: 'day', md: +TODAY.slice(8, 10), ord: 1, wd: 1, month: +TODAY.slice(5, 7), hour: '08:00', iu: uniId('MES'), anchor: TODAY, dates: [], from: TODAY, to: '', tb: 0, ta: 0 } };
}
/* Lo que devuelve CalendarioDetalle, en la forma que usa el asistente. */
function calDesdeDetalle(r) {
  var d = calVacio(), f = d.f, c = r.calendario, i = r.intervalo;
  d.id = r.id; d.usos = r.usos || 0; d.nombre = r.nombre; d.zona = r.zona || ''; d.planta = r.planta || ''; d.area = r.area || ''; d.activo = r.activo || ''; d.grupo = r.grupo || ''; d.politica = r.politica || '';
  d.anticipada = !!r.anticipada; d.atrasada = !!r.atrasada; d.genera = !!r.genera;
  (r.personas || []).forEach(function (x) { d.personas[x] = 1; });
  d.modo = (r.personas || []).length ? 'persona' : r.grupo ? 'grupo' : 'nadie';
  f.t = { 'CALENDARIO': 'cal', 'INTERVALO TIEMPO': 'int', 'FECHA UNICA': 'fec' }[r.tipoCodigo];
  f.from = r.desde || TODAY; f.to = r.hasta || ''; f.tb = Math.round((+r.tolAntes || 0) / 1440); f.ta = Math.round((+r.tolDespues || 0) / 1440);
  if (c) {
    var fc = (U.cat.frecuencias || []).filter(function (x) { return x.ID === c.frecuencia; })[0];
    f.rep = REP[fc ? fc.CODIGO : 'MENSUAL'] || 'm'; f.n = +c.intervalo || 1; f.hour = c.hora || '08:00'; f.days = (c.dias || []).map(Number).sort();
    if (c.ordinal != null) { f.mmode = 'ord'; f.ord = +c.ordinal; f.wd = f.days[0] || 1; f.days = f.rep === 'w' ? f.days : []; } else { f.mmode = 'day'; f.md = c.diaMes && c.diaMes > 0 ? +c.diaMes : 31; }
    f.month = +c.mes || f.month;
  }
  if (i) { f.n = +i.cantidad || 1; f.iu = +i.unidad; f.anchor = String(i.ancla || '').slice(0, 10) || TODAY; f.hour = String(i.ancla || '').slice(11, 16) || f.hour; }
  f.dates = (r.fechas || []).map(function (x) { return { fecha: x.fecha, hora: x.hora || '' }; });
  d.excl = (r.exclusiones || []).map(function (x) { return { a: x.desde, b: x.hasta, why: x.motivo || '', shift: !!x.desplaza }; });
  return d;
}
/* Nuevo (id = 0) o editar (id > 0): el mismo asistente de seis pasos, en el cajón. */
function abrirCal(id) {
  id = +id || 0;
  openPanel({ t: 'cal', paso: 1, err: false, alc: null, xf: null, cargando: id > 0, d: calVacio(),
    fecha: function (b, v) {
      var k = b.slice(2), x = PN.xf;
      if (k === 'xa' || k === 'xb') { if (x) x[k.slice(1)] = v; }
      else if (k === 'fadd') { var f = PN.d.f; if (v && !f.dates.some(function (y) { return y.fecha === v; })) { f.dates.push({ fecha: v, hora: f.hour }); panel(); } }
      else PN.d.f[k] = v;
    } });
  var listo = function (r) {
    if (!PN || PN.t !== 'cal') return;
    if (r) {
      if (!r.calendario && !r.intervalo && r.tipoCodigo !== 'FECHA UNICA') { closePanel(); toast('Este calendario es por medidor o por condición: se edita en Programaciones.'); return; }
      PN.d = calDesdeDetalle(r); PN.cargando = false;
    }
    panel(); calAlcance();
  };
  var pideCat = calCat ? Promise.resolve() : api('CalendarioCatalogos', {}).then(function (c) { calCat = c; });
  pideCat.then(function () { return id ? api('CalendarioDetalle', { id: id }) : null; }).then(listo).catch(function (e) { closePanel(); toastError(e); });
}
function calAlcance() {
  if (!PN || PN.t !== 'cal') return;
  var pl0 = +PN.d.planta || 0; PN.alc = null;
  api('CalendarioAlcance', { planta: pl0 }).then(function (r) { if (PN && PN.t === 'cal' && (+PN.d.planta || 0) === pl0) { PN.alc = r; panel(); } }).catch(function () { });
}
var calErr = function () {
  var d = PN.d, e = [];
  if (!String(d.nombre).trim()) e.push([1, 'Falta el nombre.']);
  if (!d.f.from) e.push([1, 'Indica desde cuándo es vigente.']);
  if ((d.area || d.activo) && !d.planta) e.push([2, 'Indica la planta antes del área o del activo.']);
  if (d.modo === 'persona' && !Object.keys(d.personas).length) e.push([3, 'Elige al menos una persona.']);
  if (d.modo === 'grupo' && !d.grupo) e.push([3, 'Elige el grupo de trabajo.']);
  var fe = fqError(d.f); if (fe) e.push([4, fe]);
  return e;
};
function calSeg(f, k, opts) { return '<div class="cp-segc" role="group">' + opts.map(function (o) { return '<button type="button" data-a="calset" data-k="' + k + '" data-v="' + o[0] + '" aria-pressed="' + (String(f[k]) === String(o[0])) + '">' + o[1] + '</button>'; }).join('') + '</div>'; }
function calCombo(k, lista, val, etq, ph, extra) { return combo('cpCal' + k, lista, val, { etiqueta: etq, ph: ph || etq, data: ' data-pp="' + k + '"' + (extra || ''), clave: 'cpCal' + k }); }
PANELS.cal = function () {
  if (PN.cargando) return { t: 'Calendario compartido', s: 'Biblioteca · Calendarios', w: 'w', b: '<div class="cp-sk" style="height:40px"></div><div class="cp-sk" style="height:260px"></div>' };
  var d = PN.d, f = d.f, e = PN.err, errs = calErr(), paso = PN.paso, alc = PN.alc || { areas: [], activos: [], grupos: [] }, cat = calCat || { zonas: [], politicas: [], personas: [] };
  var errDe = function (n) { return errs.filter(function (x) { return x[0] === n; }); };
  var nav = '<nav class="cp-wiz" aria-label="Pasos">' + CAL_PASOS.map(function (n, k) { var i = k + 1, mal = e && errDe(i).length; return '<button type="button" class="' + (paso === i ? 'cp-on' : '') + (mal ? ' cp-bad' : '') + '" data-a="calpaso" data-v="' + i + '"' + (paso === i ? ' aria-current="step"' : '') + '><i>' + (mal ? '!' : i) + '</i>' + n + '</button>'; }).join('') + '</nav>';
  var b = '';
  if (paso === 1) {
    b = (d.id && d.usos ? mc('w', 'Lo usan <b>' + pl(d.usos, 'plan, tarea o pauta', 'planes, tareas o pautas') + '</b>: un cambio aquí cambia las fechas de todos.') : '') + '<div class="cp-fld"><label>Nombre del calendario</label>' + ppTxt('nombre', d.nombre, { err: e && !String(d.nombre).trim(), af: true, max: 400, ph: 'Ej.: Inspección semanal de bombas', lbl: 'Nombre del calendario' }) + (e && !String(d.nombre).trim() ? mc('', 'Falta el nombre.') : '') + '</div>' +
      '<div class="cp-fld"><label>Tipo</label>' + combo('cpCalTipo', CAL_TIPOS, f.t, { etiqueta: 'Tipo', ph: 'Elige el tipo', dis: !!d.id, data: ' data-pp="f.t"', clave: 'cpCalTipos' }) + '<small style="color:var(--muted);font-size:11.5px">' + (d.id ? 'El tipo no se puede cambiar una vez guardado.' : 'Por medidor o por condición se crean en Programaciones.') + '</small></div>' +
      '<div class="cp-grid2c"><div class="cp-fld"><label>Vigente desde</label>' + fecha('p:from', f.from, { etiqueta: 'Vigente desde', err: e && !f.from }) + '</div><div class="cp-fld"><label>Hasta <small>opcional</small></label>' + fecha('p:to', f.to, { ph: 'Sin fin', etiqueta: 'Hasta', err: f.to && f.to < f.from }) + '</div></div>' +
      '<div class="cp-fld"><label>Zona horaria <small>opcional</small></label>' + calCombo('zona', [{ id: '', n: '(sin definir)' }].concat(cat.zonas), d.zona, 'Zona horaria', '(sin definir)') + '<small style="color:var(--muted);font-size:11.5px">La hora se guarda en UTC y se muestra en esta zona. Sin ella, el horario de verano corre las ocurrencias una hora dos veces al año.</small></div>';
  }
  if (paso === 2) {
    b = mc('i', 'El alcance dice dónde aplica el calendario. Es opcional: sin él, aplica a quien lo use.', 'help') +
      '<div class="cp-fld"><label>Planta</label>' + calCombo('planta', [{ id: '', n: 'Todas las plantas' }].concat(CFG.plantas || []), d.planta, 'Planta', 'Todas las plantas') + '</div>' +
      '<div class="cp-grid2c"><div class="cp-fld"><label>Área</label>' + calCombo('area', [{ id: '', n: 'Cualquier área' }].concat(alc.areas), d.area, 'Área', 'Cualquier área') + '</div><div class="cp-fld"><label>Activo</label>' + calCombo('activo', [{ id: '', n: 'Cualquier activo' }].concat(alc.activos), d.activo, 'Activo', 'Cualquier activo') + '</div></div>' +
      (PN.alc ? '' : '<div class="cp-sk" style="height:20px"></div>') + (errDe(2).length ? mc('', esc(errDe(2)[0][1])) : '');
  }
  if (paso === 3) {
    b = '<div class="cp-fld"><span class="cp-lb">Quién ejecuta lo que genere</span>' + calSeg(d, 'modo', CAL_ASIG) + '</div>' +
      (d.modo === 'persona' ? (function () {
        var q = nrm(d.pq || ''), nSel = Object.keys(d.personas).length;
        var lista = cat.personas.filter(function (p) { return !q || nrm(p.n).indexOf(q) >= 0; }).sort(function (x, y) { return x.n.localeCompare(y.n); });
        return '<div class="cp-fld"><span class="cp-lb">Personas <small>' + (nSel ? pl(nSel, 'elegida', 'elegidas') : 'elige una o varias') + '</small></span>' +
          '<label class="cp-srch2" style="height:36px">' + ic('search', 14) + '<input data-pp="pq" value="' + esc(d.pq || '') + '" placeholder="Buscar por nombre o cargo" aria-label="Buscar personas" autocomplete="off"></label>' +
          '<div class="cp-pers">' + (lista.map(function (p) { return '<label class="cp-sw"><input type="checkbox" data-a="calpers" data-v="' + p.id + '"' + (d.personas[p.id] ? ' checked' : '') + '><i></i>' + esc(p.n) + '</label>'; }).join('') || '<span style="font-size:12.5px;color:var(--muted)">Nadie coincide con «' + esc(d.pq) + '».</span>') + '</div>' + (e && errDe(3).length ? mc('', esc(errDe(3)[0][1])) : '') + '</div>';
      })() : '') +
      (d.modo === 'grupo' ? '<div class="cp-fld"><label>Grupo de trabajo</label>' + calCombo('grupo', [{ id: '', n: 'Elige el grupo' }].concat(alc.grupos), d.grupo, 'Grupo de trabajo', 'Elige el grupo') + (e && errDe(3).length ? mc('', esc(errDe(3)[0][1])) : '') + '</div>' : '') +
      (d.modo === 'nadie' ? mc('i', 'Sin asignar: lo que se genere nace sin responsable y se asigna una por una.', 'help') : '');
  }
  if (paso === 4) {
    var unit = { d: +f.n === 1 ? 'día' : 'días', w: +f.n === 1 ? 'semana' : 'semanas', m: +f.n === 1 ? 'mes' : 'meses', y: +f.n === 1 ? 'año' : 'años' }[f.rep];
    var fc = function (k, lista, val, etq) { return calCombo('f.' + k, lista, val, etq); };
    var unis = (U.cat.unidades || []).filter(function (u) { return u.CODIGO !== 'MINUTO'; }).map(function (u) { return { id: u.ID, n: (UNI[u.CODIGO] || [u.NOMBRE, u.NOMBRE])[1] }; });
    var regla = '';
    if (f.t === 'cal') {
      regla = '<div class="cp-fld"><span class="cp-lb">Se repite</span>' + calSeg(f, 'rep', [['d', 'Diaria'], ['w', 'Semanal'], ['m', 'Mensual'], ['y', 'Anual']]) + '</div>' +
        '<div class="cp-grid3c"><div class="cp-fld"><label>Cada</label><div class="cp-unit"><input class="cp-inp" type="number" min="1" data-pp="f.n" value="' + esc(f.n) + '" aria-label="Cada cuánto"><span class="cp-u">' + unit + '</span></div></div><div class="cp-fld"><label>Hora</label>' + fc('hour', HORAS, f.hour, 'Hora') + '</div><div></div></div>' +
        (f.rep === 'w' ? '<div class="cp-fld"><span class="cp-lb">Días</span><div class="cp-days">' + [1, 2, 3, 4, 5, 6, 7].map(function (x) { return '<button type="button" data-a="calday" data-v="' + x + '" aria-pressed="' + (f.days.indexOf(x) >= 0) + '" aria-label="' + DIA[x] + '">' + DIAC[x] + '</button>'; }).join('') + '</div></div>' : '') +
        (f.rep === 'm' || f.rep === 'y' ? '<div class="cp-fld"><span class="cp-lb">Qué día ' + (f.rep === 'm' ? 'del mes' : 'del año') + '</span>' + calSeg(f, 'mmode', [['day', 'Un día fijo'], ['ord', 'Un día de la semana']]) + '</div><div class="cp-grid3c">' +
          (f.rep === 'y' ? '<div class="cp-fld"><label>Mes</label>' + fc('month', MESES, f.month, 'Mes') + '</div>' : '') +
          (f.mmode === 'ord' ? '<div class="cp-fld"><label>Semana</label>' + fc('ord', ORD, f.ord, 'Semana') + '</div><div class="cp-fld"><label>Día</label>' + fc('wd', DSEM, f.wd, 'Día') + '</div>' : '<div class="cp-fld"><label>Día del mes</label>' + fc('md', DIAS31, f.md, 'Día del mes') + '</div>') + '</div>' : '');
    }
    if (f.t === 'int') regla = '<div class="cp-grid3c"><div class="cp-fld"><label>Cada</label><input class="cp-inp" type="number" min="1" data-pp="f.n" value="' + esc(f.n) + '" aria-label="Cada cuánto"></div><div class="cp-fld"><label>Unidad</label>' + fc('iu', unis, f.iu, 'Unidad') + '</div><div class="cp-fld"><label>A partir de</label>' + fecha('p:anchor', f.anchor, { etiqueta: 'A partir de' }) + '</div></div><div class="cp-grid3c"><div class="cp-fld"><label>Hora</label>' + fc('hour', HORAS, f.hour, 'Hora') + '</div></div>';
    if (f.t === 'fec') regla = '<div class="cp-fld"><span class="cp-lb">Fechas</span><div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center">' + f.dates.slice().sort(function (a, c) { return a.fecha.localeCompare(c.fecha); }).map(function (x) { return '<span class="cp-fc" style="cursor:default">' + fDY(x.fecha) + '<button type="button" class="cp-ibx" style="width:22px;height:22px" data-a="calrmdate" data-v="' + x.fecha + '" aria-label="Quitar ' + fDY(x.fecha) + '">' + ic('x', 12) + '</button></span>'; }).join('') + '<span style="width:170px">' + fecha('p:fadd', '', { ph: 'Agregar fecha', etiqueta: 'Agregar fecha' }) + '</span></div></div><div class="cp-grid3c"><div class="cp-fld"><label>Hora</label>' + fc('hour', HORAS, f.hour, 'Hora') + '</div></div>';
    b = regla + (e && errDe(4).length ? mc('', esc(errDe(4)[0][1])) : '') +
      '<div class="cp-blk-h" style="margin-top:6px"><h4>Cumplimiento</h4></div><div class="cp-grid2c"><div class="cp-fld"><label>Puede hacerse antes</label><div class="cp-unit"><input class="cp-inp" type="number" min="0" data-pp="f.tb" value="' + esc(f.tb) + '" aria-label="Puede hacerse antes"><span class="cp-u">días</span></div></div><div class="cp-fld"><label>Vence después de</label><div class="cp-unit"><input class="cp-inp" type="number" min="0" data-pp="f.ta" value="' + esc(f.ta) + '" aria-label="Vence después de"><span class="cp-u">días</span></div></div></div>' +
      '<div style="display:flex;gap:18px;flex-wrap:wrap"><label class="cp-sw"><input type="checkbox" data-pp="anticipada"' + (d.anticipada ? ' checked' : '') + '><i></i>Permite hacerla antes de tiempo</label><label class="cp-sw"><input type="checkbox" data-pp="atrasada"' + (d.atrasada ? ' checked' : '') + '><i></i>Permite hacerla atrasada</label><label class="cp-sw"><input type="checkbox" data-pp="genera"' + (d.genera ? ' checked' : '') + '><i></i>Genera automáticamente</label></div>' +
      '<div class="cp-fld"><label>Política de cumplimiento <small>opcional</small></label>' + calCombo('politica', [{ id: '', n: '(sin definir)' }].concat(cat.politicas), d.politica, 'Política de cumplimiento', '(sin definir)') + '</div>';
  }
  if (paso === 5) {
    var x = PN.xf;
    b = mc('i', 'Las exclusiones son días en que no se programa. Puedes correr la fecha al día siguiente u omitirla.', 'help') + '<div class="cp-exc">' + d.excl.map(function (y, k) { return '<div class="cp-exr"><span><b>' + fDY(y.a) + ' – ' + fDY(y.b) + '</b> <small>· ' + esc(y.why) + '</small></span><span class="cp-tg">' + (y.shift ? 'Corre la fecha' : 'Omite la fecha') + '</span><button type="button" class="cp-ibx cp-dn" data-a="calrmexc" data-v="' + k + '" aria-label="Quitar exclusión">' + ic('x', 14) + '</button></div>'; }).join('') + (d.excl.length ? '' : '<div class="cp-empty" style="padding:14px">Sin exclusiones.</div>') + '</div>' +
      (x ? '<div class="cp-exr" style="grid-template-columns:1fr;gap:10px;background:var(--surface-2)"><div class="cp-grid2c"><div class="cp-fld"><label>Desde</label>' + fecha('p:xa', x.a, { etiqueta: 'Exclusión desde' }) + '</div><div class="cp-fld"><label>Hasta</label>' + fecha('p:xb', x.b, { etiqueta: 'Exclusión hasta' }) + '</div></div><div class="cp-fld"><label>Motivo</label><input class="cp-inp" data-xp="why" value="' + esc(x.why) + '" placeholder="Ej.: Parada de planta de fin de año" maxlength="300"></div>' +
        '<div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap"><div class="cp-segc">' + [[1, 'Correr la fecha al día siguiente'], [0, 'Omitir la fecha']].map(function (o) { return '<button type="button" data-a="calxeff" data-v="' + o[0] + '" aria-pressed="' + (!!x.shift === !!o[0]) + '">' + o[1] + '</button>'; }).join('') + '</div><span style="flex:1"></span><button type="button" class="cp-btn cp-plain cp-xs" data-a="calxx">Cancelar</button><button type="button" class="cp-btn cp-pri cp-xs" data-a="calxok">Agregar</button></div>' + (x.err ? mc('', esc(x.err)) : '') + '</div>'
        : '<button type="button" class="cp-btn cp-out cp-sm" style="align-self:flex-start" data-a="calxadd">' + ic('plus', 15) + 'Agregar exclusión</button>');
  }
  if (paso === 6) {
    var nm = function (l, id) { var r = l.filter(function (z) { return String(z.id) === String(id); })[0]; return r ? r.n : ''; };
    var fila = function (k, v) { return '<div class="cp-rw" style="grid-template-columns:150px minmax(0,1fr)"><span style="color:var(--muted);font-weight:700">' + k + '</span><span>' + v + '</span></div>'; };
    b = (errs.length ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span><b>Falta completar:</b><ul style="margin:4px 0 0;padding-left:18px">' + errs.map(function (x) { return '<li><button type="button" class="cp-lnk" data-a="calpaso" data-v="' + x[0] + '">' + CAL_PASOS[x[0] - 1] + '</button>: ' + esc(x[1]) + '</li>'; }).join('') + '</ul></span></div>' : '<div class="cp-bnr cp-ok">' + ic('check', 18) + '<span>Todo listo para crear el calendario.</span></div>') +
      '<div class="cp-rows">' + fila('Nombre', esc(d.nombre || '—')) + fila('Frecuencia', esc(freqText(f, false)) || '—') + fila('Vigencia', fDN(f.from) + (f.to ? ' al ' + fDN(f.to) : ' · sin fin')) +
      fila('Zona horaria', esc(nm(cat.zonas, d.zona) || '(sin definir)')) + fila('Alcance', esc([nm(CFG.plantas || [], d.planta) || 'Todas las plantas', nm(alc.areas, d.area), nm(alc.activos, d.activo)].filter(Boolean).join(' · '))) +
      fila('Asignación', d.modo === 'persona' ? esc(cat.personas.filter(function (p) { return d.personas[p.id]; }).map(function (p) { return p.n; }).join(', ')) : d.modo === 'grupo' ? esc(nm(alc.grupos, d.grupo) || '—') : 'Sin asignar') +
      fila('Exclusiones', d.excl.length ? pl(d.excl.length, 'exclusión', 'exclusiones') : 'Ninguna') + fila('Generación', d.genera ? 'Automática' : 'Manual') + '</div>' + (PN.err2 ? mc('', esc(PN.err2)) : '');
  }
  return { t: d.id ? 'Editar calendario compartido' : 'Nuevo calendario compartido', s: 'Biblioteca · Calendarios · paso ' + paso + ' de 6', w: 'w',
    b: nav + '<div class="cp-wiz-b">' + b + '</div>',
    f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r">' + (paso > 1 ? '<button type="button" class="cp-btn cp-plain" data-a="calpaso" data-v="' + (paso - 1) + '">Anterior</button>' : '') +
      (paso < 6 ? '<button type="button" class="cp-btn cp-pri" data-a="calpaso" data-v="' + (paso + 1) + '">Siguiente</button>' : '<button type="button" class="cp-btn cp-pri" data-a="calsave">' + ic('check', 16) + (d.id ? 'Guardar cambios' : 'Crear calendario') + '</button>') + '</span>' };
};
A.calpaso = function (d) { PN.paso = +d.v; PN.err2 = null; panel(); };
A.calset = function (d) {
  var o = PN.d, k = d.k, f = o.f;
  if (k === 'modo') { o.modo = d.v; panel(); return; }
  f[k] = (k === 'rep' || k === 'mmode') ? d.v : +d.v; if (k === 'rep' && d.v === 'w' && !f.days.length) f.days = [wday(TODAY)]; panel();
};
A.calday = function (d) { var f = PN.d.f, x = +d.v, i = f.days.indexOf(x); if (i >= 0) f.days.splice(i, 1); else f.days.push(x); f.days.sort(); panel(); };
A.calrmdate = function (d) { var f = PN.d.f; f.dates = f.dates.filter(function (x) { return x.fecha !== d.v; }); panel(); };
A.calpers = function (d, t, e) { if (e) e.stopPropagation(); var p = PN.d.personas, id = d.v; if (p[id]) delete p[id]; else p[id] = 1; panel(); };
A.calxadd = function () { PN.xf = { a: '', b: '', why: '', shift: false }; panel(); };
A.calxx = function () { PN.xf = null; panel(); };
A.calxeff = function (d) { PN.xf.shift = d.v === '1'; panel(); };
A.calxok = function () {
  var x = PN.xf; x.err = !x.a || !x.b ? 'Indica desde y hasta.' : x.b < x.a ? '«Hasta» debe ser igual o posterior a «Desde».' : !String(x.why).trim() ? 'Escribe el motivo de la exclusión.' : '';
  if (x.err) { panel(); return; }
  PN.d.excl.push({ a: x.a, b: x.b, why: x.why.trim(), shift: !!x.shift }); PN.xf = null; panel();
};
A.calrmexc = function (d) { PN.d.excl.splice(+d.v, 1); panel(); };
A.calsave = function (d, t) {
  var x = PN.d, f = x.f, errs = calErr();
  if (errs.length) { PN.err = true; PN.paso = errs[0][0]; panel(); return; }
  t.classList.add('cp-load');
  var datos = datosDe(f); datos.nombre = String(x.nombre).trim(); datos.tipo = TIPOFC[f.t]; datos.zona = +x.zona || 0; datos.planta = +x.planta || 0; datos.area = +x.area || 0; datos.activo = +x.activo || 0; datos.modo = x.modo; datos.id = x.id || 0;
  datos.personas = Object.keys(x.personas); datos.grupo = +x.grupo || 0; datos.politica = +x.politica || 0; datos.anticipada = !!x.anticipada; datos.atrasada = !!x.atrasada; datos.genera = !!x.genera;
  api('CrearCalendario', { datos: JSON.stringify(datos) }).then(function () {
    closePanel(); toast(x.id ? 'Calendario guardado.' : 'Calendario creado. Ya se puede usar desde cualquier intervención.'); LB.cals = null; U.fq = {}; return Promise.all([libCargar(), recargarCatalogos()]);
  }).catch(function (e) { t.classList.remove('cp-load'); PN.err2 = e.message; PN.paso = 6; panel(); });
};


if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar); else iniciar();
})();




