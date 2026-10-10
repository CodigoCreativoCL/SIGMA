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
  bell: '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
  spark: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 16l.7 1.8 1.8.7-1.8.7L19 21l-.7-1.8-1.8-.7 1.8-.7z"/>',
  repeat: '<path d="M4 11V9a3 3 0 0 1 3-3h12M16 3l3 3-3 3"/><path d="M20 13v2a3 3 0 0 1-3 3H5M8 21l-3-3 3-3"/>',
  book: '<path d="M5 4.5A1.5 1.5 0 0 1 6.5 3H19v15H6.5A1.5 1.5 0 0 0 5 19.5z"/><path d="M5 19.5A1.5 1.5 0 0 0 6.5 21H19"/>',
  layers: '<path d="M12 3l9 5-9 5-9-5z"/><path d="M3 13l9 5 9-5"/>',
  users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.2A6.5 6.5 0 0 1 21.5 20"/>',
  monitor: '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
  grid: '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>',
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
var TABS = [['planes', 'Planes', 'calw', 'Qué se mantiene y cada cuánto'], ['inspecciones', 'Inspecciones', 'clip', 'Rondas con pauta de verificación'], ['tareas', 'Tareas recurrentes', 'repeat', 'Trabajos simples que se repiten'], ['cobertura', 'Cobertura', 'shield', 'Activos sin plan que los cuide']];
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
/* Personas del cliente (Catalogos: NOMBRE, PERFIL, ESPECIALIDAD, FOTO): la foto si
   tiene, si no las iniciales; perfil y especialidad en la línea secundaria. */
var persona = function (id) { return (U.cat && U.cat.personas || []).filter(function (p) { return String(p.ID) === String(id); })[0] || null; };
var persSub = function (p) { return p ? [p.PERFIL, p.ESPECIALIDAD].filter(Boolean).join(' · ') : ''; };
var avatarP = function (p, lg) {
  if (!p) return '';
  if (p.FOTO) return '<img class="cp-av cp-avi' + (lg ? ' cp-lg' : '') + '" src="' + esc(p.FOTO) + '" alt="" title="' + esc(p.NOMBRE) + '" loading="lazy">';
  return lg ? avatar(p.NOMBRE).replace('class="cp-av"', 'class="cp-av cp-lg"') : avatar(p.NOMBRE);
};
/* 429 · Carga de los próximos 30 días dentro de las opciones de personas (se pide una vez para todas). */
var CARGA = null, CARGA_PIDE = false;
function cargaDe(personas) {
  if (!window.SigmaCarga || CARGA_PIDE || !personas || !personas.length) return;
  CARGA_PIDE = true;
  SigmaCarga.resumen(personas.map(function (p) { return 'U:' + p.ID; })).then(function (m) { CARGA = m; render(); if (PN) panel(); }).catch(function () { });
}
function cargaSub(id, base) {
  var r = CARGA && CARGA['U:' + id]; if (!r) return base;
  var h = Math.round((+r.MINUTOS || 0) / 6) / 10;
  return String(h).replace('.', ',') + ' h en 30 días' + (+r.CHOQUES ? ' · ⚠ ' + r.CHOQUES + (+r.CHOQUES === 1 ? ' choque' : ' choques') : '') + (+r.DIAS_SOBRE ? ' · ' + r.DIAS_SOBRE + ' días sobre 8 h' : '') + ' · ' + base;
}
var persItems = function (fuera) {
  fuera = fuera || [];
  cargaDe(U.cat && U.cat.personas);
  return (U.cat && U.cat.personas || []).filter(function (p) { return fuera.indexOf(+p.ID) < 0; })
    .map(function (p) { return { id: p.ID, n: p.NOMBRE, sub: cargaSub(p.ID, persSub(p) || 'Sin perfil'), img: p.FOTO || '', ini: ini(p.NOMBRE) }; });
};
var persFila = function (p, extra, quitar) {
  return '<div class="cp-rp">' + avatarP(p, true) + '<span class="cp-s"><b>' + esc(p.NOMBRE) + (extra || '') + '</b><small>' + esc(persSub(p) || 'Sin perfil') + '</small></span>' + (quitar || '') + '</div>';
};
/* Responsables de una intervención: ids en orden, el primero es el principal. */
var respIds = function (i) { return (i.RESPONSABLES && i.RESPONSABLES.length ? i.RESPONSABLES : i.RESPONSABLE_ID ? [i.RESPONSABLE_ID] : []).map(Number); };
var respNombres = function (i) { return respIds(i).map(function (id) { var p = persona(id); return p ? p.NOMBRE : ''; }).filter(Boolean); };
var integrantes = function (g) { return (U.cat && U.cat.integrantes || []).filter(function (x) { return String(x.GRUPO_ID) === String(g); }); };

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
  var ed = U.permisos.editar;
  if (U.tab === 'inspecciones') return pla + '<button type="button" class="cp-hbtn cp-pri" data-a="insnueva"' + (ed ? '' : ' disabled') + '>' + ic('plus', 17) + 'Nueva inspección</button>';
  if (U.tab === 'tareas') return pla + '<button type="button" class="cp-hbtn cp-pri" data-a="tarnueva"' + (ed ? '' : ' disabled') + '>' + ic('plus', 17) + 'Nueva tarea</button>';
  if (U.tab !== 'planes') return pla;
  return pla +
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
  var n = { planes: c.todos, inspecciones: INS.filas ? INS.filas.length : null, tareas: TAR.filas ? TAR.filas.length : null, cobertura: sin };
  return TABS.map(function (t) {
    var k = t[0], v = n[k];
    return '<button type="button" role="tab" id="cpTab-' + k + '" aria-selected="' + (U.tab === k) + '" tabindex="' + (U.tab === k ? 0 : -1) + '" data-a="tab" data-t="' + k + '">' +
      '<span class="cp-mt-i">' + ic(t[2], 18) + '</span><span class="cp-mt-t"><span class="cp-mt-n">' + t[1] + (v != null ? '<b class="' + (k === 'cobertura' && v ? 'cp-r' : '') + '">' + v + '</b>' : '') + '</span><small>' + t[3] + '</small></span></button>';
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
function cmpPlanes(a, b) {
  var aa = (+a.VENCIDAS || 0) + (+a.ATRASADAS || 0) > 0, bb = (+b.VENCIDAS || 0) + (+b.ATRASADAS || 0) > 0;
  return (bb - aa) || String(a.PROXIMA_FECHA || '9').localeCompare(String(b.PROXIMA_FECHA || '9')) || String(a.NOMBRE).localeCompare(String(b.NOMBRE));
}
/* =====================================================================
   PLANES · lista a ancho completo: Lista · Tarjetas · Monitoreo
   (nunca conviven con la ficha: o se ve la lista o se ve el plan)
   ===================================================================== */
var PF = [['all', 'Todos', 'todos'], ['active', 'Activos', 'activos'], ['draft', 'Borradores', 'borradores'], ['changes', 'Con cambios', 'cambios'], ['inactive', 'Inactivos', 'inactivos'], ['att', 'Requieren atención', 'atencion']];
var PCOLS = 'grid-template-columns:24px minmax(0,2.1fr) 214px minmax(0,1fr) minmax(0,1.1fr) minmax(0,1fr) minmax(0,1.05fr) 18px';
Object.assign(P, {
  vlist: '<path d="M8 6h12M8 12h12M8 18h12"/><circle cx="4" cy="6" r="1"/><circle cx="4" cy="12" r="1"/><circle cx="4" cy="18" r="1"/>',
  vgrid: '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>'
});
var vistaKey = function () { return 'cpVista:' + (CFG.usuario || 0); };
U.pv = (function () { try { var v = localStorage.getItem(vistaKey()); return v === 'cards' || v === 'cal' ? v : 'list'; } catch (e) { return 'list'; } })();

/* 414 · «N choques»: fechas que chocan con otro trabajo (mismo activo o mismas personas) en 90 días. */
function choqChip(x) { var n = +x.CHOQUES || 0; return n ? ' <span class="cp-tg cp-w" title="' + pl(n, 'fecha choca', 'fechas chocan') + ' con otro trabajo: mismo activo, subactivo o componente, o las mismas personas">' + ic('clock', 11) + pl(n, 'choque', 'choques') + '</span>' : ''; }
function planAttn(p) {
  var venc = +p.VENCIDAS || 0, atr = +p.ATRASADAS || 0, e = estado(p)[0];
  if (venc || atr) return '<span class="cp-atn ' + (venc ? 'cp-r' : 'cp-a') + '"><i></i>' + (venc ? pl(venc, 'vencida', 'vencidas') : '') + (venc && atr ? ' · ' : '') + (atr ? pl(atr, 'atrasada', 'atrasadas') : '') + '</span>';
  if (e === 'draft') { var n = +p.FALTAN || 0; return n ? '<span class="cp-atn cp-a">' + ic('alert', 12) + 'Falta ' + pl(n, 'dato', 'datos') + '</span>' : '<span class="cp-atn" style="color:var(--ok-ink)">' + ic('check', 12) + 'Listo para activar</span>'; }
  if (e === 'changes') return '<span class="cp-atn" style="color:var(--sigma-purple)">' + ic('pencil', 12) + 'Cambios sin aplicar</span>';
  if (e === 'inactive') return '<span class="cp-muted2">—</span>';
  return '<span class="cp-atn" style="color:var(--ok-ink)">' + ic('check', 12) + 'Al día</span>';
}
var respDe = function (p) { return String(p.RESPONSABLES || p.RESPONSABLE || '').split('|').filter(Boolean); };
var proxTxt = function (p) { return p.PROXIMA_FECHA ? '<b>' + fD(dIso(p.PROXIMA_FECHA)) + '</b>' : ''; };

/* 407 · Qué cubre el plan: cada objeto mantenible con su tipo (activo completo, subactivo
   o componente). Hasta tres en la tarjeta; el resto como «+N más» con la lista en el título. */
var OBJK = { ACT: ['Activo', 'cog'], SUB: ['Subactivo', 'box'], COMP: ['Componente', 'wrench'] };
function objetosCard(p) {
  var os = p.OBJETOS || []; if (!os.length) return '';
  var txt = function (o) { return o.c + ' · ' + (o.t === 'COMP' ? o.n + ' › ' + o.comp : o.t === 'SUB' && o.padre ? o.padre + ' › ' + o.n : o.n); };
  var fila = function (o) { var k = OBJK[o.t] || OBJK.ACT; return '<span class="cp-pc-ob" title="' + esc(k[0] + ': ' + txt(o)) + '"><i class="cp-obk cp-obk-' + o.t.toLowerCase() + '">' + ic(k[1], 11) + k[0] + '</i><span><b>' + esc(o.c) + '</b> ' + esc(o.t === 'COMP' ? o.comp : o.n) + '</span></span>'; };
  return '<li class="cp-pc-obl"><span class="cp-pc-obs">' + os.slice(0, 3).map(fila).join('') + (os.length > 3 ? '<small title="' + esc(os.slice(3).map(txt).join(' · ')) + '">+' + (os.length - 3) + ' más</small>' : '') + '</span></li>';
}
function cardsBody(ps) {
  return ps.map(function (p) {
    var e = estado(p)[0], fq = String(p.FRECUENCIAS || ''), resp = respDe(p), sel = !!U.multi[p.PLAN_ID];
    var ok = e === 'draft' ? 5 - Math.min(5, +p.FALTAN || 0) : 0;
    var nx = e === 'draft' ? '<li class="cp-pc-pg">' + ic('clip', 15) + '<span><span class="cp-pg' + (+p.FALTAN ? '' : ' cp-ok') + '"><i style="width:' + (ok / 5 * 100) + '%"></i></span><small>' + ok + ' de 5 obligatorios</small></span></li>'
      : '<li>' + ic('calw', 15) + '<span>' + (p.PROXIMA_FECHA ? 'Próxima: ' + proxTxt(p) + (p.PROXIMA_ACTIVO ? ' · ' + esc(p.PROXIMA_ACTIVO) : '') : '<span class="cp-muted2">' + (e === 'inactive' ? 'No genera ejecuciones' : 'Sin próximas ejecuciones') + '</span>') + '</span></li>';
    return '<div class="cp-pcard' + (sel ? ' cp-rsel' : '') + ' cp-st-' + e + '" data-a="open" data-p="' + p.PLAN_ID + '" role="button" tabindex="0" aria-label="Abrir ' + esc(p.NOMBRE) + '">' +
      '<div class="cp-pc-top"><div class="cp-pc-t"><b title="' + esc(p.NOMBRE) + '">' + (esc(p.NOMBRE) || '<em class="cp-miss">Sin nombre</em>') + '</b><small>' + esc(p.CODIGO) + ' · ' + esc(p.PLANTA || 'Sin planta') + '</small></div><input type="checkbox" class="cp-cbx" data-a="mul" data-p="' + p.PLAN_ID + '"' + (sel ? ' checked' : '') + ' aria-label="Seleccionar ' + esc(p.NOMBRE) + '"></div>' +
      '<div class="cp-pc-s">' + stChip(p) + '</div>' +
      '<ul class="cp-pc-m"><li>' + ic('cog', 15) + '<span>' + pl(+p.ACTIVOS || 0, 'activo', 'activos') + ' · ' + pl(+p.INTERVENCIONES || 0, 'intervención', 'intervenciones') + '</span></li>' + objetosCard(p) +
      '<li>' + ic('clock', 15) + '<span title="' + esc(fq) + '">' + (fq ? esc(fq) : '<span class="cp-muted2">Frecuencia sin definir</span>') + '</span></li>' + nx + '</ul>' +
      '<div class="cp-pc-f"><span class="cp-pc-at">' + planAttn(p) + choqChip(p) + '</span><span class="cp-pc-av">' + resp.slice(0, 3).map(avatar).join('') + (resp.length > 3 ? '<span class="cp-av cp-more">+' + (resp.length - 3) + '</span>' : '') + '</span></div></div>';
  }).join('');
}
function listBody() {
  if (!U.lista) return '<div style="padding:10px;display:flex;flex-direction:column;gap:10px">' + [1, 2, 3, 4].map(function () { return '<div class="cp-sk" style="height:64px"></div>'; }).join('') + '</div>';
  var ps = U.lista.filter(planMatch).slice().sort(function (a, b) { return cmpPlanes(a, b) || ((estado(a)[0] === 'draft') - (estado(b)[0] === 'draft')); });
  if (!ps.length) return '<div class="cp-empty" style="margin:10px"><span class="cp-ei">' + ic('search', 20) + '</span><b>Ningún plan coincide</b>Prueba con otro nombre, código o activo.<button type="button" class="cp-lnk" data-a="pfclear">Limpiar filtros</button></div>';
  if (U.pv === 'cards') return cardsBody(ps);
  return ps.map(function (p) {
    var e = estado(p)[0], fq = String(p.FRECUENCIAS || '').split(' · ').filter(Boolean), resp = respDe(p)[0], sel = !!U.multi[p.PLAN_ID];
    return '<div class="cp-rw cp-click cp-prw' + (sel ? ' cp-rsel' : '') + '" style="' + PCOLS + '" data-a="open" data-p="' + p.PLAN_ID + '" role="button" tabindex="0" aria-label="Abrir ' + esc(p.NOMBRE) + '">' +
      '<span><input type="checkbox" class="cp-cbx" data-a="mul" data-p="' + p.PLAN_ID + '"' + (sel ? ' checked' : '') + ' aria-label="Seleccionar ' + esc(p.NOMBRE) + '"></span>' +
      '<span class="cp-s cp-c-pl"><b>' + (esc(p.NOMBRE) || '<em class="cp-miss">Sin nombre</em>') + '</b><small>' + esc(p.CODIGO) + ' · ' + esc(p.PLANTA || 'Sin planta') + (resp ? ' · ' + esc(resp) : '') + '</small></span>' +
      '<span class="cp-c-st">' + stChip(p) + '</span>' +
      '<span class="cp-s cp-c-al"><b style="font-weight:600">' + pl(+p.ACTIVOS || 0, 'activo', 'activos') + '</b><small>' + pl(+p.INTERVENCIONES || 0, 'intervención', 'intervenciones') + '</small></span>' +
      '<span class="cp-s cp-c-fq"><b style="font-weight:600">' + (fq.slice(0, 2).join(' · ') || '<span class="cp-muted2">Sin definir</span>') + '</b>' + (fq.length > 2 ? '<small>y ' + (fq.length - 2) + ' más</small>' : '') + '</span>' +
      '<span class="cp-dt cp-c-nx">' + (p.PROXIMA_FECHA ? proxTxt(p) + '<small>' + (p.PROXIMA_PROYECCION ? 'Proyección · ' : '') + esc(p.PROXIMA_ACTIVO || '') + '</small>' : '<small>' + (e === 'inactive' ? 'No genera ejecuciones' : 'Sin próximas') + '</small>') + '</span>' +
      '<span class="cp-c-at">' + planAttn(p) + choqChip(p) + '</span><span class="cp-c-go">' + ic('chev', 15) + '</span></div>';
  }).join('');
}
function listHTML() {
  var c = U.conteos || {}, nm = Object.keys(U.multi).length;
  if (U.lista && !U.lista.length) return '<div class="cp-card"><div class="cp-empty cp-big" style="border:0"><span class="cp-ei">' + ic('calw', 22) + '</span><b>Todavía no hay planes' + (U.planta ? ' en ' + esc(plantaN(U.planta)) : '') + '</b><span style="max-width:52ch">Un plan reúne el mantenimiento preventivo de uno o varios activos: qué se hace, cada cuánto y quién lo ejecuta.</span>' + (U.permisos.editar ? '<button type="button" class="cp-btn cp-pri" data-a="newplan">' + ic('plus', 16) + 'Nuevo plan</button>' : '') + '</div></div>';
  if (U.pv === 'cal') U.pv = 'list';
  var vistas = [['list', 'Lista', 'vlist'], ['cards', 'Tarjetas', 'vgrid']];
  return '<section class="cp-card cp-plt" aria-label="Planes"><div class="cp-plt-bar"><div class="cp-plt-r1"><label class="cp-srch2">' + ic('search', 15) + '<input id="cpQ" value="' + esc(U.q) + '" placeholder="Buscar por plan, código, activo o intervención" aria-label="Buscar planes" autocomplete="off"></label>' +
    '<div class="cp-vt" role="group" aria-label="Ver como">' + vistas.map(function (v) { return '<button type="button" data-a="pview" data-v="' + v[0] + '" aria-pressed="' + (U.pv === v[0]) + '" title="Ver como ' + v[1].toLowerCase() + '">' + ic(v[2], 16) + '<span>' + v[1] + '</span></button>'; }).join('') + '</div></div>' +
    '<div class="cp-chips">' + PF.map(function (x) { return '<button type="button" class="cp-fc" data-a="pf" data-v="' + x[0] + '" aria-pressed="' + (U.pf === x[0]) + '">' + (x[0] === 'att' ? '<i style="background:var(--red)"></i>' : '') + x[1] + '<b>' + (c[x[2]] || 0) + '</b></button>'; }).join('') + '</div></div>' +
    (U.pv === 'cal' ? '' : U.pv === 'cards' ? '<div class="cp-pcards" id="cpPlb">' + listBody() + '</div>'
      : '<div class="cp-rows cp-plr"><div class="cp-rw cp-h" style="' + PCOLS + '"><span></span><span>Plan</span><span>Estado</span><span>Alcance</span><span>Frecuencia</span><span>Próxima ejecución</span><span>Atención</span><span></span></div><div id="cpPlb">' + listBody() + '</div></div>') +
    (nm ? '<div class="cp-exbulk"><b>' + pl(nm, 'plan seleccionado', 'planes seleccionados') + '</b><span style="flex:1"></span><button type="button" class="cp-btn cp-plain cp-sm" data-a="bulkclr">Quitar selección</button><button type="button" class="cp-btn cp-out cp-sm" data-a="bulkdup"' + (nm > 1 ? ' disabled title="Duplicar funciona de a un plan"' : '') + '>Duplicar</button><button type="button" class="cp-btn cp-out cp-sm" data-a="bulkoff">Desactivar…</button></div>' : '') +
    '</section>' + (U.pv === 'cal' ? monHTML() : '');
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
  4: ['Responsable', '¿Quién lo ejecuta?', 'Cada orden de trabajo nace asignada a estas personas, grupo o empresa externa. Sin nadie, queda disponible: en la app la toma quien llegue primero.'],
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

/* 413 · Los choques de horario del plan (sus ocurrencias generadas contra las de otros), una vez por plan abierto. */
var CHQ = {};
function choqBotonPlan() { var l = planChoques(); return l && l.length ? '<button type="button" class="cp-btn cp-sec cp-sm" style="margin-top:10px" data-a="choqabrir" data-t="PLAN" data-r="' + F.plan.PLAN_ID + '" data-n="' + esc(F.plan.CODIGO) + '">' + ic('clock', 15) + 'Resolver choques de horario</button>' : ''; }
function planChoques() {
  var k = F && F.plan ? F.plan.PLAN_ID : 0; if (!k) return null;
  if (CHQ[k] === undefined) { CHQ[k] = null; api('Choques', { tipo: 'PLAN', refId: k }).then(function (r) { CHQ[k] = r.choques || []; render(); }).catch(function () { CHQ[k] = []; }); }
  return CHQ[k];
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
  });
  act.forEach(function (a) {
    if (a.FUERA_ALCANCE) W.push({ step: 1, t: a.CODIGO + ' queda fuera del alcance del plan: no generará trabajo' });
    if (a.OTROS_PLANES) W.push({ step: 1, t: a.CODIGO + ' ya está en ' + a.OTROS_PLANES });
  });
  /* 413 · Choques de horario con inspecciones, tareas u otros planes sobre el mismo objeto mantenible. */
  var ch = planChoques();
  if (ch && ch.length) {
    var g = {}; ch.forEach(function (c) { var k = c.OBJETO + '|' + c.CON_TIPO + c.CON_REF; (g[k] = g[k] || { c: c, n: 0 }).n++; });
    Object.keys(g).forEach(function (k) { var x = g[k], c = x.c; W.push({ step: c.CLASE === 'RECURSO' ? 4 : 3, t: (c.CLASE === 'RECURSO' ? c.OBJETO + ' ya está ocupado en ' : c.OBJETO + ' coincide en horario con ') +  + (TIPN[c.CON_TIPO] || '').toLowerCase() + ' ' + c.CON_CODIGO + ' · ' + c.CON_NOMBRE + ' (' + (x.n === 1 ? 'el ' + fD(dIso(c.FECHA)) + ' ' + hIso(c.FECHA) : x.n + ' veces, la primera el ' + fD(dIso(c.FECHA)) + ' ' + hIso(c.FECHA)) + ')' }); });
  }
  var okNombre = !!String(F.plan.NOMBRE || '').trim();
  return { B: B, W: W, ok: B.every(function (b) { return b.ok; }) && okNombre };
}
function stepInfo() {
  var ck = checks(), en = enab(), nAct = ints().reduce(function (t, i) { return t + (i.ACTIVIDADES || []).length; }, 0), est = planEst();
  var fqs = [], seen = {};
  en.forEach(function (i) { var f = fqDe2(i); if (!freqIssue(f)) { var s = freqCorta(f); if (!seen[s]) { seen[s] = 1; fqs.push(s); } } });
  var resps = []; en.forEach(function (i) { var ns = respNombres(i); if (!ns.length && i.GRUPO) ns = [i.GRUPO]; ns.forEach(function (n) { if (resps.indexOf(short(n)) < 0) resps.push(short(n)); }); });
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
/* 408 · El objeto mantenible de un activo del plan: activo completo, subactivo o componente (del activo o del subactivo).
   Editable, es el combo de SIGMA con el árbol; cambiarlo quita el vínculo y lo vuelve a agregar con el objeto nuevo. */
function eqObjHTML(a, E) {
  if (!PG) { pgCatalogo().then(function () { render(); }).catch(function () { }); return '<span class="cp-tg">' + (a.COMPONENTE ? esc(a.COMPONENTE) : 'Activo completo') + '</span>'; }
  var o = pgObjDesde(a.ACTIVO_ID, a.COMPONENTE_ID), base = pgBase(pgAct(a.ACTIVO_ID));
  if (!E || !base) return '<span class="cp-tg">' + esc(pgObjTxt(o) || (a.COMPONENTE ? a.COMPONENTE : 'Activo completo')) + '</span>';
  return '<span class="cp-eq-obj">' + combo('cpPlObj' + a.VINCULO_ID, pgObjOpts(base), o, { etiqueta: 'Objeto mantenible de ' + a.CODIGO, data: ' data-pg="plaeq:' + a.VINCULO_ID + '"' }) + '</span>';
}
function cambiarObjPlan(vinculo, v) {
  var a = (F.activos || []).filter(function (x) { return x.VINCULO_ID === +vinculo; })[0], o = pgObjDe(v); if (!a || !o) return;
  if (o.activo === +a.ACTIVO_ID && (o.componente || 0) === (+a.COMPONENTE_ID || 0)) return;
  escribir('QuitarActivo', { plan: pid(), vinculo: +vinculo }).then(function () {
    return escribir('AgregarActivos', { plan: pid(), items: JSON.stringify([{ activo: o.activo, componente: o.componente || null, medidor: a.MEDIDOR_ID || null }]) });
  }).then(function () { delete SUG[pid()]; toast(a.CODIGO + ': ' + pgObjTxt(v) + '.'); }).catch(toastError);
}
function s1HTML(E) {
  var p = F.plan, act = F.activos, fuera = act.filter(function (a) { return a.FUERA_ALCANCE; });
  var modelos = (U.cat.modelos || []).filter(function (m) { return p.TIPO_ID && m.TIPO_ID === p.TIPO_ID; }).map(function (m) { return { id: m.ID, n: m.NOMBRE }; });
  return '<div class="cp-scope"><div class="cp-fld"><label>Planta</label>' + combo('cpScPlanta', CFG.plantas || [], p.PLANTA_ID || '', { etiqueta: 'Planta', ph: 'Elige la planta', dis: !E, data: ' data-pf="planta"' }) + '</div>' +
    '<div class="cp-fld"><label>Tipo de activo <small>opcional</small></label>' + combo('cpScTipo', [{ id: '', n: 'Cualquier tipo' }].concat(catL('tipos')), p.TIPO_ID || '', { etiqueta: 'Tipo de activo', ph: 'Cualquier tipo', dis: !E, data: ' data-pf="tipo"' }) + '</div>' +
    '<div class="cp-fld"><label>Modelo <small>opcional</small></label>' + combo('cpScModelo', [{ id: '', n: p.TIPO_ID ? 'Cualquier modelo' : 'Elige primero el tipo' }].concat(modelos), p.MODELO_ID || '', { etiqueta: 'Modelo', ph: p.TIPO_ID ? 'Cualquier modelo' : 'Elige primero el tipo', dis: !E || !p.TIPO_ID, data: ' data-pf="modelo"' }) + '</div></div>' +
    (act.length ? '<div class="cp-s-row"><b>' + pl(act.length, 'activo en el plan', 'activos en el plan') + '</b>' + (E ? '<button type="button" class="cp-btn cp-out cp-sm" data-a="addeq">' + ic('plus', 15) + 'Agregar activos</button>' : '') + '</div>' +
      (fuera.length ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span><b>' + esc(fuera.map(function (a) { return a.CODIGO; }).join(', ')) + '</b> ' + (fuera.length === 1 ? 'queda' : 'quedan') + ' fuera del alcance y no generará trabajo. Ajusta el alcance o quítalos.</span></div>' : '') +
      '<div class="cp-eqs">' + act.map(function (a) {
        return '<div class="cp-eq' + (a.FUERA_ALCANCE ? ' cp-outx' : '') + '"><span class="cp-ph">' + (a.FOTO ? '<img class="cp-ph-img" src="' + esc(a.FOTO) + '" alt="">' : ic('cog', 20)) + '</span><div style="min-width:0"><b>' + esc(a.NOMBRE) + '</b><small>' + esc(a.CODIGO) + (a.AREA ? ' · ' + esc(a.AREA) : '') + '</small><div class="cp-tgs">' + (E ? '' : eqObjHTML(a, E)) + (a.MEDIDOR_ID ? '<span class="cp-tg cp-c">' + ic('gauge', 11) + fN(a.MEDIDOR_VALOR) + ' ' + esc(a.MEDIDOR_UNIDAD || '') + '</span>' : '') + (a.FUERA_ALCANCE ? '<span class="cp-tg cp-w">Fuera del alcance</span>' : '') + (a.OTROS_PLANES ? '<span class="cp-tg cp-w" title="También en ' + esc(a.OTROS_PLANES) + '">También en ' + esc(a.OTROS_PLANES) + '</span>' : '') + '</div></div>' +
          (E ? '<div class="cp-eq-ob"><span class="cp-eq-obl">Objeto mantenible</span>' + eqObjHTML(a, E) + '</div>' : '') +
          '<div class="cp-x"><a class="cp-ibx" href="' + esc(a.URL) + '" target="_blank" rel="noopener" aria-label="Ver ficha del activo ' + esc(a.CODIGO) + '">' + ic('arrow', 15) + '</a>' + (E ? '<button type="button" class="cp-ibx cp-dn" data-a="rmeq" data-v="' + a.VINCULO_ID + '" data-c="' + esc(a.CODIGO) + '" aria-label="Quitar ' + esc(a.CODIGO) + ' del plan">' + ic('x', 15) + '</button>' : '') + '</div></div>';
      }).join('') + '</div>'
      : '<div class="cp-empty cp-big' + (U.tried[F.plan.PLAN_ID] ? ' cp-err' : '') + '"><span class="cp-ei">' + ic('cog', 22) + '</span><b>Todavía no hay activos</b><span>Agrega los activos' + (p.PLANTA ? ' de ' + esc(p.PLANTA) : '') + ' que recibirán este mantenimiento.</span>' + (E ? '<button type="button" class="cp-btn cp-pri" data-a="addeq">' + ic('plus', 16) + 'Agregar activos</button>' : '') + '</div>');
}

/* ---- selector de intervención (pasos 2 y 3) ---- */
/* Mockup v5 · tarjetas de intervención: código, tipo de OT y estado arriba; nombre; actividades, duración y parada. */
function intTabs(cur, E, mode) {
  return '<div class="cp-itabs2" role="tablist" aria-label="Intervenciones">' + ints().map(function (i) {
    var bad = mode === 2 ? intIssue(i) : !!freqIssue(fqDe2(i));
    var meta = !i.HABILITADO ? 'Deshabilitada' : mode === 3 ? (bad ? 'Sin frecuencia' : esc(freqCorta(fqDe2(i)))) : pl((i.ACTIVIDADES || []).length, 'actividad', 'actividades') + ' · ' + fH(i.DURACION);
    return '<button type="button" role="tab" class="cp-itc' + (i === cur ? ' cp-on' : '') + (i.HABILITADO ? '' : ' cp-off') + (i.HABILITADO && bad ? ' cp-bad' : '') + '" data-a="isel" data-i="' + i.HITO_ID + '" aria-selected="' + (i === cur) + '">' +
      '<span class="cp-itc-t"><span class="cp-icd">' + esc(i.CODIGO) + '</span><span class="cp-itc-tp">' + esc(i.OT_TIPO || '') + '</span>' +
      (!i.HABILITADO ? '<span class="cp-itc-s cp-off">Pausada</span>' : bad ? '<span class="cp-itc-s cp-bad" title="Falta completar">Falta un dato</span>' : '<span class="cp-itc-s cp-ok" title="Completa">' + ic('check', 11) + '</span>') + '</span>' +
      '<span class="cp-itc-n">' + (esc(i.NOMBRE) || '<em>Sin nombre</em>') + '</span><small class="cp-itc-m">' + meta + (i.PARADA && i.HABILITADO ? ' · <span class="cp-pz2">parada</span>' : '') + '</small></button>';
  }).join('') + (mode === 2 && E ? '<button type="button" class="cp-itc cp-add" data-a="addint"><span class="cp-itc-plus">' + ic('plus', 18) + '</span><span class="cp-itc-n">Agregar intervención</span><small class="cp-itc-m">Otra tarea del plan con su frecuencia</small></button>' : '') + '</div>';
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
  var list = ints(), dis = !E;
  var firmas = list.map(function (i) { return respIds(i).join(','); });
  var same = firmas.every(function (x) { return x === firmas[0]; }) && respIds(list[0]).length === 1 ? respIds(list[0])[0] : '';
  var grupos = [{ id: '', n: 'Sin grupo' }].concat((U.cat && U.cat.grupos || []).map(function (g) { var n = integrantes(g.ID).length; return { id: g.ID, n: g.NOMBRE, sub: n ? pl(n, 'integrante', 'integrantes') : 'Sin integrantes' }; }));
  return (E && list.length > 1 ? '<div class="cp-allr"><span>' + ic('users', 16) + 'Asignar todas las intervenciones a</span><span style="min-width:280px">' + combo('cpAllResp', persItems(), same, { etiqueta: 'Responsable para todas', ph: 'Elegir persona…', data: ' data-ar="1"', clave: 'cpAllResps' }) + '</span></div>' : '') +
    '<div class="cp-rtbl cp-rtbl2 cp-rtbl3"><div class="cp-rh"><span>Intervención</span><span>Responsables <small>uno o más</small></span><span>Grupo de trabajo <small>opcional</small></span><span>Empresa externa <small>opcional</small></span></div>' +
    list.map(function (i) {
      var f = fqDe2(i), ids = respIds(i), id = i.HITO_ID, nom = i.NOMBRE || i.CODIGO;
      var resp = ids.map(function (u, k) {
        var p = persona(u) || { NOMBRE: 'Usuario ' + u };
        return persFila(p, k === 0 && ids.length > 1 ? ' <span class="cp-tg cp-p">Principal</span>' : '',
          E ? '<button type="button" class="cp-ibx" data-a="rrm" data-i="' + id + '" data-v="' + u + '" aria-label="Quitar a ' + esc(p.NOMBRE) + '">' + ic('x', 13) + '</button>' : '') +
          '<div class="cp-carga-row cp-carga-sm">' + cargaUI('U:' + u, p.NOMBRE, persSub(p)) + '</div>';
      }).join('') +
        (E ? combo('cpIvResp' + id, persItems(ids), '', { etiqueta: 'Agregar responsable a ' + nom, ph: ids.length ? 'Agregar otro responsable…' : 'Elegir responsable…', data: ' data-radd="' + id + '"', clave: 'cpRespAdd' + id })
          : ids.length ? '' : '<small class="cp-mut">Sin responsable</small>') +
        (!ids.length && !i.GRUPO_ID && !i.PROVEEDOR_ID ? '<span class="cp-tg cp-c" style="align-self:flex-start" title="Sin asignar: en la app cualquiera la toma">Disponible</span>' : '');
      /* 411 · Empresa externa: responsable de la OT si no hay persona; si la hay, entra de apoyo. */
      if (!PG) pgCatalogo().then(function () { render(); }).catch(function () { });
      var empresa = PG ? combo('cpIvProv' + id, [{ id: '', n: 'Sin empresa' }].concat((PG.proveedores || []).map(function (x) { return { id: x.ID, n: x.NOMBRE }; })), i.PROVEEDOR_ID || '', { etiqueta: 'Empresa externa de ' + nom, ph: 'Sin empresa', dis: dis, data: ' data-iv="proveedor" data-i="' + id + '"', clave: 'cpProvs' })
        : '<span class="cp-sk" style="height:38px;display:block"></span>';
      if (PG && i.PROVEEDOR_ID) empresa += '<div class="cp-carga-row cp-carga-sm">' + cargaUI('E:' + i.PROVEEDOR_ID, ((PG.proveedores || []).filter(function (x) { return +x.ID === +i.PROVEEDOR_ID; })[0] || {}).NOMBRE || 'Empresa', 'Empresa externa') + '</div>';
      var miembros = i.GRUPO_ID ? integrantes(i.GRUPO_ID) : [];
      var grupo = combo('cpIvGrupo' + id, grupos, i.GRUPO_ID || '', { etiqueta: 'Grupo de ' + nom, ph: 'Sin grupo', dis: dis, data: ' data-iv="grupo" data-i="' + id + '"', clave: 'cpGrupos' }) +
        (i.GRUPO_ID ? '<div class="cp-gm"><span class="cp-lb2">Integrantes · ' + miembros.length + '</span>' + (miembros.length ? miembros.map(function (m) {
          var p = persona(m.USUARIO_ID) || { NOMBRE: 'Usuario ' + m.USUARIO_ID };
          return persFila(p, m.LIDER ? ' <span class="cp-tg cp-c">Líder</span>' : '');
        }).join('') : '<small class="cp-mut">El grupo no tiene integrantes vigentes.</small>') + '</div><div class="cp-carga-row cp-carga-sm">' + cargaUI('G:' + i.GRUPO_ID, ((U.cat && U.cat.grupos || []).filter(function (g) { return +g.ID === +i.GRUPO_ID; })[0] || {}).NOMBRE || 'Grupo', 'Grupo de trabajo') + '</div>' : '');
      return '<div class="cp-rr' + (i.HABILITADO ? '' : ' cp-off') + '"><span class="cp-s"><b>' + esc(i.CODIGO) + ' · ' + (esc(i.NOMBRE) || 'Sin nombre') + '</b><small>' + (freqIssue(f) ? 'Sin frecuencia' : esc(freqCorta(f))) + ' · ' + fH(i.DURACION) + '</small></span>' +
        '<div class="cp-rps">' + resp + '</div><div class="cp-rps">' + grupo + '</div><div class="cp-rps">' + empresa + '</div></div>';
    }).join('') + '</div>' +
    mc('i', 'Al generar cada OT, SIGMA la asigna al responsable principal; los demás responsables entran como apoyo.' +
      (enab().some(function (i) { return !i.RESPONSABLE_ID && !i.GRUPO_ID && !i.PROVEEDOR_ID; }) ? ' Una intervención sin responsable, grupo ni empresa queda <b>disponible</b>: en la app la ve quien puede ejecutarla y la toma quien llegue primero; ahí puede sumar integrantes, un grupo o una empresa externa.' : ''), 'help');
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
    var f = fqDe2(i), iss = freqIssue(f), who = respNombres(i).join(', ') || i.RESPONSABLE || i.GRUPO;
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
      '<div class="cp-chk">' + ck.B.map(function (b) { return item(b, b.ok ? 'ok' : 'no'); }).join('') + '</div>' + (ck.W.length ? '<h5>Conviene revisar <small>no impide ' + (est === 'draft' ? 'activar' : 'aplicar') + '</small></h5><div class="cp-chk">' + ck.W.map(function (w) { return item(w, 'wa'); }).join('') + '</div>' : '') + choqBotonPlan() + '</div>' +
      '<div class="cp-rv-r"><h5>Así funcionará</h5>' + (planStory() || '<p class="cp-miss2">Cuando agregues intervenciones, aquí verás en palabras simples qué hará el plan.</p>') +
      (est === 'draft' ? '<div class="cp-imp">' + (ck.ok ? (im.CREAN != null ? 'Al activar se generarán <b>' + pl(+im.CREAN, 'ejecución', 'ejecuciones') + '</b> entre hoy y el ' + fDY(dIso(im.HASTA) || addD(TODAY, 90)) + ' para <b>' + pl(F.activos.length, 'activo', 'activos') + '</b>.' : 'Al activar, SIGMA programa las ejecuciones de los próximos 90 días.') : 'Cuando completes lo obligatorio, aquí verás cuántas ejecuciones se generarán.') + '</div>'
        : '<h5>Al aplicar, desde hoy</h5>' + imp4(im)) + '</div></div>';
  }
  var nProg = (F.proximas || []).filter(function (o) { return dIso(o.FECHA) >= TODAY; }).length, nx = proxima(), aten = (+p.VENCIDAS || 0) + (+p.ATRASADAS || 0);
  return seg + '<div class="cp-rv"><div class="cp-rv-l"><h5>Así funciona</h5>' + planStory() + '</div><div class="cp-rv-r">' + (est === 'inactive'
    ? '<div class="cp-bnr cp-i">' + ic('alert', 18) + '<span>' + esc(p.RETIRO_MOTIVO || '') + '<br><small style="color:var(--muted)">' + esc(p.RETIRO_USUARIO || '') + ' · ' + fDN(p.RETIRO_FECHA) + '</small></span></div>'
    : '<div class="cp-facts"><div><span>Próxima ejecución</span><b>' + (nx ? fDL(nx.d) : '—') + '</b></div><div><span>Pendientes · próximos 90 días</span><b>' + (im.DESACTIVAR_CANCELAN != null ? im.DESACTIVAR_CANCELAN : nProg) + '</b></div><div><span>Requieren atención</span><b style="' + (aten ? 'color:var(--red)' : '') + '">' + aten + '</b></div><div><span>Versión</span><b>v' + p.VERSION_VIGENTE + '</b><small>desde ' + fDN(p.VERSION_DESDE) + '</small></div></div>' + (ck.W.length ? '<h5>Conviene revisar</h5><div class="cp-chk">' + ck.W.map(function (w) { return item(w, 'wa'); }).join('') + '</div>' : '') + choqBotonPlan()) + '</div></div>';
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
  if (f.t === 'cond') body = condHTML(i, E);
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
/* ---- condición en línea: las reglas de la programación y el alta ----
   CND[programación] = condiciones (o { err }), CCAT = combos (una vez),
   CF[código de intervención] = lo que se está escribiendo. */
var CND = {}, CCAT = null, CF = {};
function cargarCond(pro) {
  if (CND[pro]) return;
  CND[pro] = { cargando: true };
  api('Condiciones', { plan: pid(), programacion: pro }).then(function (r) {
    CND[pro] = r.condiciones; CCAT = { variables: r.variables, operadores: r.operadores, severidades: r.severidades };
    render();
  }).catch(function (e) { CND[pro] = { err: e.message }; render(); });
}
function condForm(i) {
  var v = CF[i.CODIGO];
  if (!v) {
    var cod = function (lista, c) { var x = (lista || []).filter(function (o) { return o.CODIGO === c; })[0]; return x ? x.ID : ''; };
    var vars = condVars();
    v = CF[i.CODIGO] = { variable: vars.length === 1 ? vars[0].ID : '', operador: cod(CCAT.operadores, 'MAYOR'), umbral: '', hasta: '', duracion: '', severidad: cod(CCAT.severidades, 'ADVERTENCIA') };
  }
  return v;
}
/* Solo las variables de los activos del plan: una condición sobre otro equipo no dispararía esta intervención. */
function condVars() {
  var ids = {}; F.activos.forEach(function (a) { ids[a.ACTIVO_ID] = 1; });
  return ((CCAT && CCAT.variables) || []).filter(function (x) { return ids[x.ACTIVO_ID]; });
}
function condHTML(i, E) {
  var id = i.HITO_ID, pro = i.PROGRAMACION_ID, lista = CND[pro];
  var nota = '<div style="font-size:12px;color:var(--muted)">Se dispara al registrar una medición que cumple la condición.</div>';
  if (!lista) { cargarCond(pro); lista = { cargando: true }; }
  if (lista.cargando) return '<div class="cp-fld">' + nota + mc('i', 'Cargando condiciones…') + '</div>';
  if (lista.err) return '<div class="cp-fld">' + mc('', esc(lista.err)) + '</div>';
  var unica = lista.length === 1;
  var filas = lista.map(function (c) {
    return '<div class="cp-exr"><span>' + ic('trend', 14) + ' <b>' + esc(c.ACTIVO_NOMBRE) + '</b> <small>· ' + esc(c.REGLA) + '</small></span><span class="cp-tg">' + esc(c.SEVERIDAD_NOMBRE) + '</span>' +
      (E ? '<button type="button" class="cp-ibx cp-dn" data-a="condrm" data-i="' + id + '" data-v="' + c.pco_id + '"' + (unica ? ' disabled title="Es la única condición: agrega otra antes de quitarla"' : '') + ' aria-label="Quitar condición">' + ic('x', 14) + '</button>' : '<span></span>') + '</div>';
  }).join('');
  var form = '';
  if (E) {
    var vars = condVars();
    if (!vars.length) form = mc('i', F.activos.length ? 'Los activos del plan no tienen variables de medición. Defínelas en la ficha del activo para poder dispararla por condición.' : 'Agrega activos al plan para elegir la variable que se mide.');
    else {
      var v = condForm(i);
      var op = (CCAT.operadores || []).filter(function (o) { return String(o.ID) === String(v.operador); })[0];
      var entre = op && op.CODIGO === 'ENTRE';
      var cb = function (k, l, val, etq, ph) { return combo('cpCf' + k + id, l, val, { etiqueta: etq, ph: ph, data: ' data-cf="' + k + '" data-i="' + id + '"', clave: 'cpCf' + k }); };
      var nm = function (k, etq, ph) { return '<input class="cp-inp" type="number" step="any" data-cf="' + k + '" data-i="' + id + '" value="' + esc(v[k]) + '" placeholder="' + (ph || '') + '" aria-label="' + etq + '">'; };
      form = '<div class="cp-exr" style="grid-template-columns:1fr;gap:10px;background:var(--surface-2)">' +
        '<div class="cp-grid3c"><div class="cp-fld" style="grid-column:span 2"><label>Variable</label>' + cb('variable', vars.map(function (x) { return { id: x.ID, n: x.ACTIVO + (x.COMPONENTE ? ' · ' + x.COMPONENTE : '') + ' · ' + x.VARIABLE + (x.UNIDAD ? ' (' + x.UNIDAD + ')' : '') }; }), v.variable, 'Variable', 'Elige la variable') + '</div>' +
        '<div class="cp-fld"><label>Se cumple si es</label>' + cb('operador', (CCAT.operadores || []).map(function (o) { return { id: o.ID, n: o.NOMBRE }; }), v.operador, 'Operador', 'Operador') + '</div></div>' +
        '<div class="cp-grid4c"><div class="cp-fld"><label>' + (entre ? 'Desde' : 'Valor') + '</label>' + nm('umbral', 'Valor') + '</div>' +
        (entre ? '<div class="cp-fld"><label>Hasta</label>' + nm('hasta', 'Hasta') + '</div>' : '') +
        '<div class="cp-fld"><label>Durante <small>opcional</small></label><div class="cp-unit">' + nm('duracion', 'Durante', '0') + '<span class="cp-u">min</span></div></div>' +
        '<div class="cp-fld"><label>Severidad</label>' + cb('severidad', (CCAT.severidades || []).map(function (s) { return { id: s.ID, n: s.NOMBRE }; }), v.severidad, 'Severidad', 'Severidad') + '</div></div>' +
        '<div style="display:flex;gap:10px;align-items:center"><span style="flex:1"></span><button type="button" class="cp-btn cp-pri cp-xs" data-a="condadd" data-i="' + id + '">' + ic('plus', 14) + 'Agregar condición</button></div>' +
        (v.err ? mc('', esc(v.err)) : '') + '</div>';
    }
  }
  return '<div class="cp-fld"><span class="cp-lb">Condiciones</span>' + nota + '<div class="cp-exc">' + filas + form + '</div></div>';
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
        return repFila(r, id, E, dis);
      }).join('') +
      (E ? sugReps(a, id) : '') +
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
    if (/Repuesto$/.test(metodo)) delete SUG[pid()];   // 422: el stock de lo planificado se vuelve a leer
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
    if (U.tab === 'planes' && !U.plan) render();
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
var FKEYS = ['pf', 'iv', 'act', 'fk', 'fe', 'xv', 'xp', 'rq', 'repq', 'pv', 'pp', 'mv', 'ppv', 'pg'];
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
  if (window.SigmaCarga) SigmaCarga.pintarResumen(body);
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
  var ha = $('#cpHeroAcc'); if (ha) { ha.dataset.ok = ''; pintarCascara(); }
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
  if (window.SigmaCarga) SigmaCarga.pintarResumen(L);
}

/* ---- agregar activos (CA-07: resultado por fila) ---- */
PANELS.addeq = function () {
  var p = F.plan, ttl = 'Agregar activos', sub = esc(p.CODIGO) + ' · ' + esc(p.NOMBRE);
  if (PN.res) {
    var ok = PN.res.filter(function (r) { return r.ok; }).length;
    return { t: ttl, s: sub, b: '<div class="cp-bnr cp-' + (ok === PN.res.length ? 'ok' : 'w') + '">' + ic(ok === PN.res.length ? 'check' : 'alert', 18) + '<span><b>' + ok + ' de ' + PN.res.length + '</b> ' + (ok === 1 ? 'activo agregado' : 'activos agregados') + ' al plan.</span></div><div class="cp-res">' + PN.res.map(function (r) { var a = (PN.lista || []).filter(function (x) { return x.ACTIVO_ID === r.activo; })[0] || {}; return '<div class="cp-' + (r.ok ? 'ok' : 'no') + '">' + ic(r.ok ? 'check' : 'x', 15) + '<span><b>' + esc(a.CODIGO || r.activo) + '</b> · ' + esc(a.NOMBRE || '') + '<small style="display:block;color:' + (r.ok ? 'var(--muted)' : 'var(--red)') + '">' + esc(r.ok ? (a.PLANES ? 'Agregado · también está en ' + a.PLANES_CODIGOS : 'Agregado') : r.detalle) + '</small></span><span></span></div>'; }).join('') + '</div>', f: '<span class="cp-r"><button type="button" class="cp-btn cp-pri" data-a="pclose">Listo</button></span>' };
  }
  if (!PN.lista) return { t: ttl, s: sub, b: '<div class="cp-sk" style="height:40px"></div><div class="cp-sk" style="height:300px"></div>' };
  /* Los subactivos no van como fila propia: se eligen desde su activo, en «Objeto mantenible». */
  var q = nrm(PN.q), pool = PN.lista.filter(function (a) { return !a.YA_EN_PLAN && !(pgAct(a.ACTIVO_ID) || {}).PADRE_ID && (!q || nrm(a.CODIGO + ' ' + a.NOMBRE + ' ' + (a.AREA || '') + ' ' + (a.TIPO || '')).indexOf(q) >= 0) && (!PN.fa || a.AREA === PN.fa); });
  var ok2 = pool.filter(function (a) { return !a.MOTIVO; }), no = pool.filter(function (a) { return a.MOTIVO; });
  var areas = {}; PN.lista.forEach(function (a) { if (a.AREA) areas[a.AREA] = 1; });
  var n = Object.keys(PN.sel).length;
  var row = function (a) {
    var s = PN.sel[a.ACTIVO_ID], comps = (PN.comp || []).filter(function (c) { return c.ACTIVO_ID === a.ACTIVO_ID; }), meds = (PN.med || []).filter(function (m) { return m.ACTIVO_ID === a.ACTIVO_ID; });
    return '<div class="cp-pk-r' + (a.MOTIVO ? ' cp-dis' : '') + '"><input type="checkbox" class="cp-cbx" data-a="eqpick" data-v="' + a.ACTIVO_ID + '"' + (s ? ' checked' : '') + (a.MOTIVO ? ' disabled' : '') + ' aria-label="Elegir ' + esc(a.CODIGO) + '"><span class="cp-ph2">' + ic('cog', 18) + '</span><span class="cp-s"><b>' + esc(a.NOMBRE) + '</b><small>' + esc(a.CODIGO) + (a.AREA ? ' · ' + esc(a.AREA) : '') + (a.MODELO ? ' · ' + esc(a.MODELO) : a.TIPO ? ' · ' + esc(a.TIPO) : '') + '</small></span><span style="text-align:right">' + (a.MOTIVO ? '<span class="cp-tg">' + esc(a.MOTIVO) + '</span>' : a.PLANES ? '<span class="cp-tg cp-w" title="' + esc(a.PLANES_CODIGOS) + '">En ' + pl(+a.PLANES, 'plan', 'planes') + '</span>' : '<span class="cp-tg cp-c">Sin plan</span>') + '</span>' +
      (s && pgAct(a.ACTIVO_ID) ? '<div class="cp-eqo">' + combo('cpEqObj' + a.ACTIVO_ID, pgObjOpts(pgAct(a.ACTIVO_ID)), s.o || 'a:' + a.ACTIVO_ID, { etiqueta: 'Objeto mantenible de ' + a.CODIGO, data: ' data-pg="addeq:' + a.ACTIVO_ID + '"' }) + combo('cpEqMed' + a.ACTIVO_ID, meds.length ? meds.map(function (m) { return { id: m.ID, n: m.NOMBRE + ' · ' + fN(m.VALOR) + ' ' + (m.UNIDAD || '') }; }) : [{ id: '', n: 'Sin medidor' }], s.medidor || (meds[0] ? meds[0].ID : ''), { etiqueta: 'Medidor', dis: !meds.length, data: ' data-pq="medidor" data-v="' + a.ACTIVO_ID + '"' }) + '</div>' : '') + '</div>';
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
  /* Activar, aplicar, desactivar o reactivar cambia las ejecuciones: la pestaña
     las vuelve a pedir al entrar (antes mostraba las de antes hasta un F5). */
  return fn().then(function (r) { closeModal(); EX.rango = null; return r; }, function (e) { if (MD) { MD.busy = false; MD.err2 = e.message; modal(); } throw e; });
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
/* ---- Monitoreo ---- */
A.mday = function (d) { U.md = d.v; if (U.md < MON.rango.split('|')[0] || U.md > MON.rango.split('|')[1]) { MON.filas = null; } render(); if (!MON.filas) monCargar(); };
A.mstep = function (d) { A.mday({ v: addD(U.md, +d.v) }); };
A.mweek = function (d) { A.mday({ v: addD(U.md, +d.v) }); };
A.mtog = function (d) { if (U.mc[d.v]) delete U.mc[d.v]; else U.mc[d.v] = 1; render(); };
A.mfoc = function (d) { U.mf = d.v; var ps = d.v.split('|'); delete U.mc['p:' + ps[0]]; delete U.mc['a:' + d.v]; render(); var el = document.getElementById('cpAr' + ps[0] + '_' + ps[1]); if (el) goEl(el); };
A.mplan = function (d) { abrirPlan(+d.p); };
A.cplans = function (d, t) { openPop(t, { t: 'cplans' }); };
A.cpl = function (d, t, e) { if (e) e.stopPropagation(); var id = +d.p; if (U.ch[id]) delete U.ch[id]; else U.ch[id] = 1; var o = POP; render(); if (o) { POP = o; paintPop(); } };
A.cpall = function () { U.ch = {}; var o = POP; render(); if (o) { POP = o; paintPop(); } };

A.pview = function (d) { U.pv = d.v; U.multi = {}; try { localStorage.setItem(vistaKey(), d.v); } catch (e) { } render(); if (d.v === 'cal' && window.monCargar) monCargar(); };
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
/* El historial es una pestaña del paso 5 (Revisar y activar). */
A.mhist = function () { cerrarPop(); A.stp({ v: 5, t5: 'hist' }); setTimeout(function () { goEl('#cpSecHist'); }, 60); };
/* Las ejecuciones viven en Operación › Ejecuciones: se abre filtrada por este plan. */
A.mexec = function () { cerrarPop(); location.href = CFG.base_ + 'View/Mantenimiento/Operacion/Operacion.aspx#ejecuciones&plan=' + encodeURIComponent(F.plan.CODIGO); };
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
  Promise.all([api('Candidatos', { plan: pid(), filtro: '' }), pgCatalogo()]).then(function (x) { var r = x[0]; if (!PN || PN.t !== 'addeq') return; PN.lista = r.activos; PN.comp = r.componentes; PN.med = r.medidores; panel(); }).catch(function (e) { closePanel(); toastError(e); });
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
    var s = PN.sel[id], o = pgObjDe(s.o) || { activo: +id, componente: 0 }, meds = (PN.med || []).filter(function (m) { return m.ACTIVO_ID === o.activo; });
    return { activo: o.activo, componente: o.componente || null, medidor: s.medidor ? +s.medidor : (meds[0] ? meds[0].ID : null) };
  });
  t.classList.add('cp-load');
  escribir('AgregarActivos', { plan: pid(), items: JSON.stringify(items) }).then(function (r) { delete SUG[pid()]; if (PN && PN.t === 'addeq') { PN.res = r.resultados; PN.sel = {}; panel(); } }).catch(function (e) { t.classList.remove('cp-load'); toastError(e); });
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
/* La respuesta trae las condiciones de la programación que quedó (puede ser
   la copia privada): se guardan antes de pedir la ficha para no recargarlas. */
function condEscribir(metodo, datos, msg) {
  return escribir(metodo, datos, { sinFicha: true }).then(function (r) {
    CND[r.programacion] = r.condiciones;
    return recargarFicha().then(function () { recargarLista(); toast(msg); });
  });
}
function cfCampo(hid, k, v) {
  var h = hById(hid); if (!h || !CF[h.CODIGO]) return;
  CF[h.CODIGO][k] = v; CF[h.CODIGO].err = '';
  if (k === 'operador') render();
}
A.condadd = function (d) {
  var h = hById(d.i); if (!h) return; var v = CF[h.CODIGO]; if (!v) return;
  var op = (CCAT.operadores || []).filter(function (o) { return String(o.ID) === String(v.operador); })[0];
  var entre = op && op.CODIGO === 'ENTRE', num = function (x) { return String(x).trim() !== '' && !isNaN(+x); };
  v.err = !v.variable ? 'Elige la variable que se mide.' : !v.operador ? 'Elige cómo se compara.' : !num(v.umbral) ? 'Indica el valor de la condición.'
    : entre && !num(v.hasta) ? 'Indica hasta qué valor.' : entre && +v.hasta <= +v.umbral ? '«Hasta» debe ser mayor que «Desde».'
    : String(v.duracion).trim() !== '' && !(+v.duracion >= 0) ? 'La duración no puede ser negativa.' : !v.severidad ? 'Elige la severidad.' : '';
  if (v.err) { render(); return; }
  var datos = { variable: +v.variable, operador: +v.operador, umbral: +v.umbral, hasta: entre ? +v.hasta : '', duracion: String(v.duracion).trim() === '' ? '' : +v.duracion, severidad: +v.severidad };
  condEscribir('AgregarCondicion', { plan: pid(), hito: +d.i, datos: JSON.stringify(datos) }, 'Condición agregada.')
    .then(function () { delete CF[h.CODIGO]; render(); }).catch(toastError);
};
A.condrm = function (d) {
  var h = hById(d.i); if (!h) return;
  condEscribir('QuitarCondicion', { plan: pid(), hito: +d.i, programacion: h.PROGRAMACION_ID, condicion: +d.v }, 'Condición quitada.').catch(toastError);
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
/* 409 · Repuestos sugeridos por compatibilidad con los activos, subactivos y componentes del plan. */
var SUG = {};
/* 422 · Parte f · repuestos dentro de la actividad, como repsHTML del mockup: compatibilidad con lo que mantiene
   el plan, «cantidad × N activos = total», stock en bodega y sugerencias por nivel. */
var NIVN = { 1: ['Del objeto mantenible', 'Calzan exactamente en el activo, subactivo o componente que mantiene el plan'], 2: ['De sus componentes', 'Se instalan en piezas que forman parte de lo que se mantiene'], 3: ['Del activo', 'Consumibles y filtros del modelo o tipo de activo'] };
function repSug() {
  var k = pid(), x = SUG[k];
  if (x === undefined) { SUG[k] = null; api('RepuestosSugeridos', { plan: k }).then(function (r) { SUG[k] = { l: r.repuestos || [], st: r.stock || [], n: +r.objetos || 0 }; render(); }).catch(function () { SUG[k] = { l: [], st: [], n: 0 }; }); return null; }
  return x;
}
function repStock(x, repId) { if (!x) return null; return x.l.filter(function (r) { return +r.ID === +repId; })[0] || x.st.filter(function (r) { return +r.ID === +repId; })[0] || null; }
function stkHTML(s, need, un) {
  if (!s) return '';
  if (!s.CON_REGISTRO) return '<span class="cp-stk cp-s-na">Sin registro de stock</span>';
  var d = +s.STOCK || 0, mn = s.MINIMO == null ? null : +s.MINIMO;
  if (d <= 0) return '<span class="cp-stk cp-s-0" title="' + esc(s.BODEGA || '') + '">Sin stock</span>';
  if (d < need || (mn != null && d <= mn)) return '<span class="cp-stk cp-s-lo" title="' + (mn != null ? 'Mínimo ' + fN(mn) + ' ' + esc(un) : '') + (s.BODEGA ? ' · ' + esc(s.BODEGA) : '') + '">Stock bajo · ' + fN(d) + ' ' + esc(un) + '</span>';
  return '<span class="cp-stk cp-s-ok" title="' + esc(s.BODEGA || '') + '">' + fN(d) + ' ' + esc(un) + ' en bodega</span>';
}
function repFila(r, actId, E, dis) {
  var x = repSug(), n = x ? x.n : 0, cf = x ? x.l.filter(function (c) { return +c.ID === +r.REPUESTO_ID; })[0] : null, un = r.UNIDAD || (cf && cf.UNIDAD) || 'un';
  var nEq = cf ? +cf.FITS : n || 1, q = +r.CANTIDAD || 0;
  var fit = !x || !n ? '' : !cf ? '<span class="cp-cpt cp-c-no" title="No está registrado como compatible con los activos del plan">' + ic('alert', 11) + 'Sin compatibilidad registrada</span>'
    : +cf.FITS >= n ? '<span class="cp-cpt cp-c-ok" title="' + esc(cf.DONDE || '') + '">' + ic('check', 11) + (n > 1 ? 'Compatible con los ' + n + ' activos' : 'Compatible') + '</span>'
    : '<span class="cp-cpt cp-c-pt" title="' + esc(cf.DONDE || '') + '">Compatible con ' + cf.FITS + ' de ' + n + ' activos</span>';
  return '<div class="cp-rp2"><span class="cp-s"><b>' + esc(r.NOMBRE) + '</b><small><code>' + esc(r.CODIGO) + '</code>' + fit + '</small></span>' +
    '<span class="cp-rp2-q"><input class="cp-inp" type="number" min="0" step="any" data-rq="' + r.ID + '" data-c="' + actId + '" data-rep="' + r.REPUESTO_ID + '" value="' + q + '"' + dis + ' aria-label="Cantidad por ejecución de ' + esc(r.NOMBRE) + '"><span class="cp-un">' + esc(un) + '</span></span>' +
    '<span class="cp-rp2-t">' + (nEq > 1 ? '× ' + nEq + ' activos = <b>' + fN(q * nEq) + ' ' + esc(un) + '</b>' : '<span class="cp-mut">por ejecución</span>') + '</span>' + stkHTML(repStock(x, r.REPUESTO_ID), q * nEq, un) +
    (E ? '<button type="button" class="cp-ibx cp-dn" data-a="rmrep" data-v="' + r.ID + '" aria-label="Quitar ' + esc(r.NOMBRE) + '">' + ic('x', 14) + '</button>' : '<span></span>') + '</div>';
}
function sugReps(a, actId) {
  var x = repSug();
  if (!x) return '<div class="cp-sk" style="height:40px"></div>';
  if (!x.n) return '<div class="cp-rpc-e">' + ic('help', 15) + 'Agrega activos en el paso 1 para ver sus repuestos compatibles.</div>';
  var ya = (a.REPUESTOS || []).map(function (r) { return +r.REPUESTO_ID; }), key = 'rc' + actId, todos = !!U.vp[key];
  if (!x.l.length) return '<div class="cp-rpc-e">' + ic('box', 15) + 'No hay repuestos registrados como compatibles con los activos del plan. Puedes buscarlos abajo; para que aparezcan aquí, regístralos en la compatibilidad del repuesto.</div>';
  var lista = todos ? x.l : x.l.slice(0, 6), nAdd = x.l.filter(function (c) { return +c.NIVEL === 1 && ya.indexOf(+c.ID) < 0; });
  var fila = function (c) {
    var on = ya.indexOf(+c.ID) >= 0, f = +c.FITS;
    return '<div class="cp-rc' + (on ? ' cp-on' : '') + '"><span class="cp-s"><b>' + esc(c.NOMBRE) + '</b><small><code>' + esc(c.CODIGO) + '</code> · ' + esc(c.DONDE || c.POR || '') + '</small></span>' +
      '<span>' + (f >= x.n ? '<span class="cp-cpt cp-c-ok">' + ic('check', 11) + (x.n > 1 ? 'Los ' + x.n + ' activos' : 'Compatible') + '</span>' : '<span class="cp-cpt cp-c-pt">' + f + ' de ' + x.n + ' activos</span>') + '</span>' +
      stkHTML(c, f, c.UNIDAD || 'un') +
      (on ? '<span class="cp-rc-ok">' + ic('check', 14) + 'Agregado</span>' : '<button type="button" class="cp-btn cp-out cp-xs" data-a="addsug" data-c="' + actId + '" data-v="' + c.ID + '">' + ic('plus', 13) + 'Agregar</button>') + '</div>';
  };
  var grupos = [1, 2, 3].map(function (t) { var g = lista.filter(function (c) { return +c.NIVEL === t; }); return g.length ? '<div class="cp-rc-g"><div class="cp-rc-gh"><b>' + NIVN[t][0] + '</b><small>' + NIVN[t][1] + '</small></div>' + g.map(fila).join('') + '</div>' : ''; }).join('');
  return '<div class="cp-rpc"><div class="cp-rpc-h"><span class="cp-rpc-t">' + ic('box', 15) + '<b>Compatibles con lo que mantiene este plan</b></span>' +
    (nAdd.length > 1 ? '<button type="button" class="cp-lnk" data-a="addsugall" data-c="' + actId + '" data-v="' + nAdd.map(function (c) { return c.ID; }).join(',') + '">Agregar los ' + nAdd.length + ' del objeto mantenible</button>' : '') + '</div>' + grupos +
    (x.l.length > 6 ? '<button type="button" class="cp-lnk" style="margin-top:6px" data-a="sugmas" data-c="' + actId + '">' + (todos ? 'Ver menos' : 'Ver los ' + x.l.length + ' compatibles') + '</button>' : '') + '</div>';
}
A.sugmas = function (d) { var k = 'rc' + d.c; U.vp[k] = !U.vp[k]; render(); };
A.addsugall = function (d) {
  var ids = String(d.v || '').split(',').filter(Boolean), k = 0;
  (function sig() { if (k >= ids.length) { toast(pl(ids.length, 'repuesto agregado', 'repuestos agregados') + ' a la actividad.'); return; } escribir('AgregarRepuesto', { plan: pid(), actividad: +d.c, repuesto: +ids[k++], cantidad: 1 }).then(sig).catch(toastError); })();
};
A.addsug = function (d) { escribir('AgregarRepuesto', { plan: pid(), actividad: +d.c, repuesto: +d.v, cantidad: 1 }).catch(toastError); };

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
  if (t.hasAttribute('data-pg')) return pgCampo(t.getAttribute('data-pg'), t.value, false);
  if (t.hasAttribute('data-fe')) return fechaCambio(t);
  if (t.hasAttribute('data-pf')) return planCampo(t.getAttribute('data-pf'), t.value);
  if (t.hasAttribute('data-pp') && PN && PN.d) return setPP(t, t.type === 'checkbox' ? t.checked : t.value);
  if (t.hasAttribute('data-iv')) return ivCampo(t, t.getAttribute('data-iv'), t.type === 'checkbox' ? (t.checked ? '1' : '0') : t.value);
  if (t.hasAttribute('data-act')) return actCampo(t, t.getAttribute('data-act'), t.type === 'checkbox' ? t.checked : t.value);
  if (t.hasAttribute('data-fk')) return fqCampo(t.getAttribute('data-i'), t.getAttribute('data-fk'), t.value);
  if (t.hasAttribute('data-cf')) return cfCampo(t.getAttribute('data-i'), t.getAttribute('data-cf'), t.value);
  if (t.hasAttribute('data-rq')) return repCantidad(t);
  if (t.hasAttribute('data-pv') && PN) { var k = t.getAttribute('data-pv'); PN[k] = t.type === 'checkbox' ? t.checked : t.value; if (PN.t === 'pick' && k === 'only') { PN.lista = null; panel(); cargarProcs(); } else if (t.type === 'checkbox') panel(); return; }
  if (t.hasAttribute('data-mv') && MD) { MD[t.getAttribute('data-mv')] = t.value; return; }
  if (TABR[U.tab] && TABR[U.tab].cambio) TABR[U.tab].cambio(t, e);
}
function comboCambio(span) {
  var v = valorCombo(span), nombre = span.getAttribute('data-cb');
  if (nombre === 'cpPlanta') { if (+v !== U.planta) { U.planta = +v || 0; pintarCascara(); recargarTodo(); } return; }
  if (span.hasAttribute('data-ar')) return asignarTodas(v);
  if (span.hasAttribute('data-radd')) return respAgregar(span.getAttribute('data-radd'), v);
  if (span.hasAttribute('data-pg')) return pgCampo(span.getAttribute('data-pg'), v, false);
  if (span.hasAttribute('data-pp') && PN && PN.d) return setPP(span, v);
  if (span.hasAttribute('data-pf')) return planCampo(span.getAttribute('data-pf'), v);
  if (span.hasAttribute('data-iv')) return ivCampo(span, span.getAttribute('data-iv'), v);
  if (span.hasAttribute('data-act')) return actCampo(span, span.getAttribute('data-act'), v);
  if (span.hasAttribute('data-fk')) return fqCampo(span.getAttribute('data-i'), span.getAttribute('data-fk'), v);
  if (span.hasAttribute('data-cf')) return cfCampo(span.getAttribute('data-i'), span.getAttribute('data-cf'), v);
  if (span.hasAttribute('data-pq') && PN) {
    var k = span.getAttribute('data-pq');
    if (k === 'area') { PN.fa = v; panel(); return; }
    var a = +span.getAttribute('data-v'); if (PN.sel[a]) PN.sel[a][k] = v; return;
  }
  if (span.hasAttribute('data-ppq') && POP) { POP[span.getAttribute('data-ppq')] = v; return; }
  if (TABR[U.tab] && TABR[U.tab].combo) TABR[U.tab].combo(span, v);
}
function asignarTodas(v) {
  var list = ints().filter(function (i) { return respIds(i).join(',') !== String(v || ''); });
  if (!v || !list.length) return;
  list.forEach(function (i, k) { escribir('GuardarIntervencion', { plan: pid(), hito: i.HITO_ID, campo: 'responsable', valor: String(v) }, k < list.length - 1 ? { sinFicha: true } : {}).catch(toastError); });
}
/* 391 · responsables: la lista completa viaja en cada cambio (ids en orden). */
function respGuardar(h, ids, msg) {
  escribir('GuardarIntervencion', { plan: pid(), hito: h.HITO_ID, campo: 'responsable', valor: ids.join(',') }).then(function () { if (msg) toast(msg); }).catch(toastError);
}
function respAgregar(hid, v) {
  var h = hById(hid); if (!h || !v) return;
  var ids = respIds(h); if (ids.indexOf(+v) >= 0) return;
  var p = persona(v);
  respGuardar(h, ids.concat([+v]), p ? p.NOMBRE + (ids.length ? ' se agregó como responsable.' : ' es el responsable.') : '');
}
A.rrm = function (d) {
  var h = hById(d.i); if (!h) return;
  respGuardar(h, respIds(h).filter(function (x) { return x !== +d.v; }));
};
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
  var actual = { nombre: h.NOMBRE, descripcion: h.DESCRIPCION, habilitado: h.HABILITADO ? '1' : '0', parada: h.PARADA ? '1' : '0', overhaul: h.OVERHAUL ? '1' : '0', tipo: h.OT_TIPO_ID, prioridad: h.OT_PRIORIDAD_ID, responsable: h.RESPONSABLE_ID, grupo: h.GRUPO_ID, proveedor: h.PROVEEDOR_ID, duracion: h.DURACION }[campo];
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
  if (t.hasAttribute('data-pg') && !t.closest('[data-cb]')) { pgCampo(t.getAttribute('data-pg'), t.value, true); return; }
  if (t.hasAttribute('data-pp') && PN && PN.d && t.type !== 'checkbox') { setPP(t, t.value); return; }
  if (t.hasAttribute('data-xp') && PN && PN.xf) { PN.xf[t.getAttribute('data-xp')] = t.value; return; }
  if (t.hasAttribute('data-cf')) { cfCampo(t.getAttribute('data-i'), t.getAttribute('data-cf'), t.value); return; }
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
  var esCbx = { mul: 1, eqpick: 1, eqall: 1, exsel: 1, exall: 1, covtg: 1, covall: 1, calpers: 1, cpl: 1, pgeq: 1 };
  if (t.type === 'checkbox' && !esCbx[a]) return;
  if (!(t.type === 'checkbox' && esCbx[a])) e.preventDefault();
  fn(t.dataset, t, e);
}
function alTeclado(e) {
  var root = $('#cpRoot'); if (!root) return;
  if (e.key === 'Enter' && e.target && e.target.id === 'cpPgPaso') { e.preventDefault(); A.pgpasoadd(); return; }
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
    insCargar(); tarCargar();
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
    insCargar(); tarCargar();
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
/* Cobertura muestra de a COB_PAG filas en una caja con scroll propio: con cientos de activos
   la barra de selección (Crear plan / Agregar a un plan) sigue a la vista. */
var COB_PAG = 50;
var CB = U.cob = { lista: null, f: 'sin', tipo: '', q: '', sel: {}, sinPlan: null, cargando: false, lim: COB_PAG };
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
    '<div style="min-width:0"><h3 style="font-size:16px;font-weight:800">' + (sin ? sin + ' ' + (sin === 1 ? 'activo no tiene' : 'activos no tienen') + ' plan preventivo' : 'Todos los activos tienen plan preventivo') + '</h3><p style="font-size:13px;color:var(--muted);margin-top:4px;max-width:70ch">' + (all.length - sin) + ' de ' + all.length + ' activos ' + (U.planta ? 'de ' + esc(plantaN(U.planta)) : (CFG.plantas || []).length === 1 ? 'de ' + esc(CFG.plantas[0].n) : 'de todas las plantas') + ' están en al menos un plan activo. Selecciona varios para crear un plan con ellos o sumarlos a uno existente.</p></div></div>' +
    '<div class="cp-card" style="padding:8px 10px"><div class="cp-ex-bar" style="padding:6px 6px 10px"><div class="cp-chips">' + [['sin', 'Sin plan'], ['con', 'Con plan'], ['all', 'Todos']].map(function (x) { return '<button type="button" class="cp-fc" data-a="covf" data-v="' + x[0] + '" aria-pressed="' + (CB.f === x[0]) + '">' + (x[0] === 'sin' ? '<i style="background:var(--red)"></i>' : '') + x[1] + '<b>' + (x[0] === 'sin' ? sin : x[0] === 'con' ? all.length - sin : all.length) + '</b></button>'; }).join('') + '</div>' +
    '<div class="cp-ex-f"><span style="min-width:200px">' + combo('cpCvTipo', [{ id: '', n: 'Cualquier tipo' }].concat(Object.keys(tipos).sort().map(function (t) { return { id: t, n: t }; })), CB.tipo, { etiqueta: 'Tipo de activo', ph: 'Cualquier tipo', data: ' data-cvf="tipo"' }) + '</span><label class="cp-srch2" style="height:34px;min-width:200px">' + ic('search', 14) + '<input id="cpCvq" value="' + esc(CB.q) + '" placeholder="Código, nombre o área" aria-label="Buscar activos" autocomplete="off"></label></div></div>' +
    (nSel ? '<div class="cp-exbulk cp-exbulk-top"><b>' + pl(nSel, 'activo seleccionado', 'activos seleccionados') + '</b><span style="flex:1"></span><button type="button" class="cp-btn cp-plain cp-sm" data-a="covclr">Quitar selección</button><button type="button" class="cp-btn cp-out cp-sm" data-a="covadd">Agregar a un plan existente</button><button type="button" class="cp-btn cp-pri cp-sm" data-a="covnew">' + ic('plus', 15) + 'Crear plan con estos activos</button></div>' : '') +
    '<div class="cp-rows cp-cov-rows"><div class="cp-rw cp-h" style="' + cols + '"><span>' + (list.length ? '<input type="checkbox" class="cp-cbx" data-a="covall"' + (allSel ? ' checked' : '') + ' aria-label="Seleccionar todos">' : '') + '</span><span>Activo</span><span>Tipo · modelo</span><span>Ubicación</span><span>Cobertura</span></div>' +
    (list.slice(0, CB.lim).map(function (a) {
      return '<div class="cp-rw cp-click' + (CB.sel[a.ACTIVO_ID] ? ' cp-rsel' : '') + '" style="' + cols + '" data-a="covtg" data-v="' + a.ACTIVO_ID + '" role="button" tabindex="0"><span><input type="checkbox" class="cp-cbx" data-a="covtg" data-v="' + a.ACTIVO_ID + '"' + (CB.sel[a.ACTIVO_ID] ? ' checked' : '') + ' aria-label="Seleccionar ' + esc(a.CODIGO) + '"></span><span class="cp-s"><b>' + esc(a.NOMBRE) + '</b><small>' + esc(a.CODIGO) + '</small></span><span class="cp-s"><b style="font-weight:600">' + esc(a.TIPO || '—') + '</b><small>' + esc(a.MODELO || '') + '</small></span><span class="cp-s"><b style="font-weight:600">' + esc(a.AREA || '—') + '</b><small>' + esc(a.PLANTA || '') + '</small></span>' +
        '<span>' + (+a.PLANES ? String(a.PLANES_CODIGOS || '').split(', ').map(function (c) { return '<span class="cp-tg cp-c" style="margin-right:4px">' + esc(c) + '</span>'; }).join('') : '<span class="cp-atn cp-r"><i></i>Sin plan</span>') + '</span></div>';
    }).join('') || '<div class="cp-empty" style="margin:10px">' + ic('check', 18) + '<b>Nada que mostrar</b>Ningún activo coincide con estos filtros.</div>') +
    (list.length > CB.lim ? '<div class="cp-cov-more"><span>Mostrando ' + CB.lim + ' de ' + list.length + '</span><button type="button" class="cp-btn cp-out cp-xs" data-a="covmas">Mostrar ' + Math.min(COB_PAG, list.length - CB.lim) + ' más</button></div>' : '') + '</div>' +
    '</div>';
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
  /* La fecha se guarda ANTES de cerrar: closePanel() deja PN en null y el aviso
     fallaba, cortando la recarga (la ejecución seguía «Vencida» hasta un F5).
     Se conserva la hora de la ejecución: sin ella quedaba a las 00:00. */
  var nd = PN.nd, hora = hIso(x.FECHA_PROGRAMADA);
  api('Reprogramar', { token: x.TOKEN, fecha: nd + (hora ? 'T' + hora : ''), motivo: PN.why.trim() }).then(function () {
    closePanel(); toast('Ejecución reprogramada al ' + fDL(nd) + '. El cumplimiento sigue midiendo la fecha original.');
    return Promise.all([exCargar(true), recargarKpis(), recargarLista(), U.plan ? recargarFicha() : null]);
  }).catch(function (e) { t.classList.remove('cp-load'); if (!PN) { toastError(e); return; } PN.err2 = e.message; PN.err = false; panel(); });
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
/* =====================================================================
   INSPECCIONES y TAREAS RECURRENTES (mockup · parte e)
   Una fila por programación de inspección / por tarea, con su pauta o categoría, dónde, frecuencia,
   responsable, próxima y el cumplimiento de los últimos 30 días. Editar abre el formulario del sitio.
   ===================================================================== */
var INS = { filas: null, q: '', error: '' }, TAR = { filas: null, q: '', error: '' };
function insCargar() { INS.error = ''; return api('Inspecciones', { planta: U.planta }).then(function (r) { INS.filas = r.filas || []; $('#cpTabs').innerHTML = tabsHTML(); if (U.tab === 'inspecciones') render(); }).catch(function (e) { INS.filas = INS.filas || []; INS.error = e.message || 'Error'; if (U.tab === 'inspecciones') render(); }); }
function tarCargar() { TAR.error = ''; return api('Tareas', { planta: U.planta }).then(function (r) { TAR.filas = r.filas || []; $('#cpTabs').innerHTML = tabsHTML(); if (U.tab === 'tareas') render(); }).catch(function (e) { TAR.filas = TAR.filas || []; TAR.error = e.message || 'Error'; if (U.tab === 'tareas') render(); }); }
var lNorm = function (t) { return String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); };
function proxCell(x) { return x.PROXIMA ? '<b>' + fD(x.PROXIMA) + '</b><small>' + rel(String(x.PROXIMA).slice(0, 10)) + '</small>' : '<b>—</b><small>Sin próxima</small>'; }
function ultCell(x) {
  var t = +x.TOTAL, h = +x.HECHAS;
  if (!t) return '<small>Sin registros aún</small>';
  var p = Math.round(100 * h / t);
  return '<span class="cp-mbar"><i class="' + (p < 90 ? 'cp-low' : '') + '" style="width:' + p + '%"></i></span><small>' + h + ' de ' + t + '</small>';
}
/* La asignación en la lista: el avatar de la persona (con «+N» si hay más) o una etiqueta para Disponible, grupo o empresa. */
function quienCell(x) {
  var t = x.ASIGNA_TXT || '';
  if (!t || t === 'Disponible') return '<span class="cp-tg cp-c" title="Sin asignar: cualquiera la toma desde la app">Disponible</span>';
  if (/^(Grupo|Externa) · /.test(t)) return '<span class="cp-tg" title="' + esc(t) + '">' + ic(/^Grupo/.test(t) ? 'cog' : 'box', 11) + esc(t.replace(/^(Grupo|Externa) · /, '')) + '</span>';
  var mas = /\+(\d+)$/.exec(t);
  return avatar(x.RESPONSABLE) + (mas ? '<span class="cp-av cp-more">+' + mas[1] + '</span>' : '');
}
function ayudaHTML(t) { return '<div class="cp-hint2">' + ic('help', 15) + '<span>' + t + '</span></div>'; }
function insHTML() {
  var f = INS.filas;
  if (!f) return skel();
  var q = lNorm(INS.q), l = f.filter(function (x) { return !q || lNorm([x.NOMBRE, x.CODIGO, x.PAUTA, x.DONDE, x.DONDE_CODIGO].join(' ')).indexOf(q) >= 0; });
  var cols = 'minmax(0,1.5fr) minmax(0,1.2fr) minmax(0,1.2fr) minmax(0,1.1fr) minmax(190px,1fr) minmax(0,1fr) 22px';
  var rows = l.map(function (x) {
    return '<div class="cp-rw cp-click" style="grid-template-columns:' + cols + '" data-a="insabrir" data-id="' + x.ID + '" role="button" tabindex="0"><span class="cp-s"><b>' + esc(x.NOMBRE) + choqChip(x) + '</b><small>' + esc(x.CODIGO) + (x.PLANTA ? ' · ' + esc(x.PLANTA) : '') + '</small></span>' +
      '<span class="cp-s"><b>' + esc(x.PAUTA) + '</b><small>' + pl(+x.ITEMS, 'ítem', 'ítems') + ' · ' + esc(x.PAUTA_NOMBRE) + '</small></span>' +
      '<span class="cp-s"><b>' + esc(x.DONDE) + '</b><small>' + esc(x.DONDE_CODIGO) + '</small></span>' +
      '<span class="cp-s"><b>' + esc(x.FRECUENCIA) + '</b></span>' +
      '<span class="cp-who">' + quienCell(x) + '<span class="cp-s">' + proxCell(x) + '</span></span>' +
      '<span class="cp-ult">' + ultCell(x) + '</span><span class="cp-go">' + ic('chev', 15) + '</span></div>';
  }).join('');
  return ayudaHTML('Una inspección recorre activos con una <b>pauta</b>. Se programa aquí, se registra en <a class="cp-lnk" href="' + esc(CFG.base_ + 'View/Mantenimiento/Operacion/Operacion.aspx#ejecuciones') + '">Operación › Ejecuciones</a> y lo que no cumple llega a <a class="cp-lnk" href="' + esc(CFG.base_ + 'View/Mantenimiento/Avisos/Avisos.aspx') + '">Avisos</a>.') +
    '<div class="cp-card cp-plt"><label class="cp-srch2" style="max-width:360px;margin-bottom:8px">' + ic('search', 15) + '<input id="cpInsQ" value="' + esc(INS.q) + '" placeholder="Inspección, código o activo" aria-label="Buscar inspección" autocomplete="off"></label>' +
    (l.length ? '<div class="cp-rows"><div class="cp-rw cp-h" style="grid-template-columns:' + cols + '"><span>Inspección</span><span>Pauta</span><span>Activos</span><span>Frecuencia</span><span>Próxima</span><span>Últimos 30 días</span><span></span></div>' + rows + '</div>'
      : '<div class="cp-empty cp-big" style="border:0"><span class="cp-ei">' + ic('clip', 22) + '</span><b>' + (f.length ? 'Ninguna inspección coincide' : 'Todavía no hay inspecciones programadas') + '</b>' + (INS.error ? esc(INS.error) : 'Crea la primera con «Nueva inspección».') + '</div>') + '</div>';
}
function tarHTML() {
  var f = TAR.filas;
  if (!f) return skel();
  var q = lNorm(TAR.q), l = f.filter(function (x) { return !q || lNorm([x.NOMBRE, x.CODIGO, x.CATEGORIA, x.DONDE, x.DONDE_CODIGO].join(' ')).indexOf(q) >= 0; });
  var cols = 'minmax(0,1.5fr) minmax(0,1fr) minmax(0,1.2fr) minmax(0,1.1fr) minmax(190px,1fr) minmax(0,1fr) 22px';
  var rows = l.map(function (x) {
    return '<div class="cp-rw cp-click" style="grid-template-columns:' + cols + '" data-a="tarabrir" data-id="' + x.ID + '" role="button" tabindex="0"><span class="cp-s"><b>' + esc(x.NOMBRE) + choqChip(x) + '</b><small>' + esc(x.CODIGO) + (+x.ESCALADAS ? ' · <span class="cp-lnk">' + pl(+x.ESCALADAS, 'escalada a OT', 'escaladas a OT') + '</span>' : '') + '</small></span>' +
      '<span class="cp-s"><b class="cp-cat"><i style="background:' + esc(x.COLOR) + '"></i>' + esc(x.CATEGORIA) + '</b></span>' +
      '<span class="cp-s"><b>' + esc(x.DONDE) + '</b><small>' + esc(x.DONDE_CODIGO) + '</small></span>' +
      '<span class="cp-s"><b>' + esc(x.FRECUENCIA) + '</b></span>' +
      '<span class="cp-who">' + quienCell(x) + '<span class="cp-s">' + proxCell(x) + '</span></span>' +
      '<span class="cp-ult">' + ultCell(x) + '</span><span class="cp-go">' + ic('chev', 15) + '</span></div>';
  }).join('');
  return ayudaHTML('Una tarea es trabajo rutinario y breve: <b>no es una OT</b>. Si al hacerla aparece un problema, se escala a OT desde Operación › Ejecuciones.') +
    '<div class="cp-card cp-plt"><label class="cp-srch2" style="max-width:360px;margin-bottom:8px">' + ic('search', 15) + '<input id="cpTarQ" value="' + esc(TAR.q) + '" placeholder="Tarea, categoría o activo" aria-label="Buscar tarea" autocomplete="off"></label>' +
    (l.length ? '<div class="cp-rows"><div class="cp-rw cp-h" style="grid-template-columns:' + cols + '"><span>Tarea</span><span>Categoría</span><span>Dónde</span><span>Frecuencia</span><span>Próxima</span><span>Últimos 30 días</span><span></span></div>' + rows + '</div>'
      : '<div class="cp-empty cp-big" style="border:0"><span class="cp-ei">' + ic('check', 22) + '</span><b>' + (f.length ? 'Ninguna tarea coincide' : 'Todavía no hay tareas recurrentes') + '</b>' + (TAR.error ? esc(TAR.error) : 'Crea la primera con «Nueva tarea».') + '</div>') + '</div>';
}
var URL_INS = function (q) { return CFG.base_ + 'View/Mantenimiento/Checklist/ChecklistProgramacion.aspx' + (q ? '?query=' + q : ''); };
var URL_TAR = function (q) { return CFG.base_ + 'View/Mantenimiento/Tareas/Tarea.aspx' + (q ? '?query=' + q : ''); };
/* =====================================================================
   408 · CAJONES «INSPECCIÓN» Y «TAREA RECURRENTE» (mockup PANELS.rone / PANELS.tare)
   Reemplazan el modal ChecklistProgramacion.aspx y la página Tarea.aspx. Una inspección recorre
   varios activos en orden; cada uno (y el «dónde» de una tarea) puede ser el activo completo,
   un subactivo o un componente. Frecuencia propia (semanal / mensual) o un calendario compartido.
   Los campos llevan data-pg="clave" (sus propios manejadores: pgCampo).
   ===================================================================== */
var PG = null;   // catálogo de los cajones (WsCentroPlanificacion.ProgramaCatalogo)
function pgCatalogo() { return PG ? Promise.resolve(PG) : api('ProgramaCatalogo', {}).then(function (c) { PG = c; return c; }); }
var pgAct = function (id) { return (PG && PG.activos || []).filter(function (a) { return +a.ID === +id; })[0]; };
var pgComp = function (id) { return (PG && PG.componentes || []).filter(function (c) { return +c.ID === +id; })[0]; };
var pgCrit = function (n) { return +n >= 4 ? 'A' : +n === 3 ? 'B' : 'C'; };   // nivel de criticidad (1–4) → color del mockup (A alta · B media · C baja)
var pgBase = function (a) { return a && a.PADRE_ID ? pgAct(a.PADRE_ID) || a : a; };
/* Las opciones del objeto mantenible de un activo: él completo, sus subactivos y los componentes de cada uno. */
function pgObjOpts(base) {
  var comps = function (actId, nivel) {
    var cs = PG.componentes.filter(function (c) { return +c.ACTIVO_ID === +actId; }), out = [];
    var rama = function (padre, n) { cs.filter(function (c) { return (+c.PADRE_ID || 0) === padre; }).forEach(function (c) { out.push({ id: 'c:' + c.ID, n: c.NOMBRE, tag: { k: 'c', t: 'Componente' }, nivel: Math.min(n, 3), img: c.IMG || '', ini: 'C' }); rama(+c.ID, n + 1); }); };
    rama(0, nivel); return out;
  };
  var l = [{ id: 'a:' + base.ID, n: 'Activo completo', sub: base.CODIGO + ' · ' + base.NOMBRE, txt: base.CODIGO + ' ' + base.NOMBRE, tag: { k: 'a', t: 'Activo' }, nivel: 0, img: base.IMG || '', ini: 'A' }].concat(comps(base.ID, 1));
  PG.activos.filter(function (s) { return +s.PADRE_ID === +base.ID; }).forEach(function (s) { l.push({ id: 'a:' + s.ID, n: s.NOMBRE, sub: s.CODIGO, tag: { k: 's', t: 'Subactivo' }, nivel: 1, img: s.IMG || '', ini: 'S' }); l = l.concat(comps(s.ID, 2)); });
  return l;
}
/* «a:12» / «c:5» → { activo, componente } para guardar. */
function pgObjDe(o) { var m = /^([ac]):(\d+)$/.exec(o || ''); if (!m) return null; if (m[1] === 'a') return { activo: +m[2], componente: 0 }; var c = pgComp(m[2]); return c ? { activo: +c.ACTIVO_ID, componente: +c.ID } : null; }
function pgObjTxt(o) {
  var m = /^([ac]):(\d+)$/.exec(o || ''); if (!m) return '';
  if (m[1] === 'c') { var c = pgComp(m[2]); return c ? 'Componente · ' + c.NOMBRE : ''; }
  var a = pgAct(m[2]); return a && a.PADRE_ID ? 'Subactivo · ' + a.NOMBRE : 'Activo completo';
}
var pgObjDesde = function (act, comp) { return +comp ? 'c:' + comp : 'a:' + act; };
function pgPersonas() { cargaDe(PG.personas); return (PG.personas || []).map(function (p) { return { id: p.ID, n: p.NOMBRE, sub: cargaSub(p.ID, [p.PERFIL, p.ESPECIALIDAD].filter(Boolean).join(' · ')), img: p.FOTO || '', ini: ini(p.NOMBRE) }; }); }
function pgFreqVacia() { return { modo: 'w', dias: [wday(TODAY)], diaMes: +TODAY.slice(8, 10), hora: '08:00', sh: '', pro: 0 }; }
function pgFreqDesde(r) {
  var f = pgFreqVacia(); if (!r) return f;
  f.pro = +r.ID || 0;
  if (!r.PRIVADA) { f.modo = 'sh'; f.sh = r.ID; return f; }
  f.modo = r.FRECUENCIA === 'MENSUAL' ? 'm' : 'w'; f.hora = r.HORA || '08:00';
  f.dias = String(r.DIAS || '').split(',').filter(Boolean).map(Number); if (!f.dias.length) f.dias = [1];
  f.diaMes = +r.DIA_MES || 1; return f;
}
/* Las próximas fechas de la frecuencia propia (la vista previa del mockup). */
function pgProximas(f, n) {
  var out = [], d = TODAY;
  for (var k = 0; k < 400 && out.length < n; k++, d = addD(d, 1)) {
    if (f.modo === 'w' && f.dias.indexOf(wday(d)) >= 0) out.push(d);
    if (f.modo === 'm') { var y = +d.slice(0, 4), m = +d.slice(5, 7), last = new Date(y, m, 0).getDate(); if (+d.slice(8, 10) === Math.min(+f.diaMes || 1, last)) out.push(d); }
  }
  return out;
}
function pgFreqHTML(f, e) {
  var seg = '<div class="cp-segc" role="group" aria-label="Cada cuánto">' + [['w', 'Semanal'], ['m', 'Mensual'], ['sh', 'Calendario compartido']].map(function (o) { return '<button type="button" data-a="pgfq" data-v="' + o[0] + '" aria-pressed="' + (f.modo === o[0]) + '">' + o[1] + '</button>'; }).join('') + '</div>';
  var cuerpo = f.modo === 'w' ? '<div class="cp-fld"><span class="cp-lb">Días</span><div class="cp-days">' + [1, 2, 3, 4, 5, 6, 7].map(function (x) { return '<button type="button" data-a="pgday" data-v="' + x + '" aria-pressed="' + (f.dias.indexOf(x) >= 0) + '" aria-label="' + DIA[x] + '">' + DIAC[x] + '</button>'; }).join('') + '</div>' + (!f.dias.length ? mc('', 'Elige al menos un día.') : '') + '</div>'
    : f.modo === 'm' ? '<div class="cp-fld" style="max-width:200px"><label>Día del mes</label>' + combo('cpPgDm', DIAS31, f.diaMes, { etiqueta: 'Día del mes', data: ' data-pg="f.diaMes"' }) + '</div>'
    : '<div class="cp-fld"><label>Calendario</label>' + combo('cpPgSh', PG.calendarios.map(function (c) { return { id: c.ID, n: c.NOMBRE, sub: c.TIPO }; }), f.sh, { etiqueta: 'Calendario compartido', ph: 'Elige un calendario', err: e && !f.sh, data: ' data-pg="f.sh"' }) +
      mc('i', 'Si alguien cambia el calendario en Recursos, cambia aquí también.', 'help') + '</div>';
  var hora = f.modo !== 'sh' ? '<div class="cp-fld" style="max-width:200px"><label>Hora</label>' + combo('cpPgH', HORAS, f.hora, { etiqueta: 'Hora', data: ' data-pg="f.hora"' }) + '</div>' : '';
  var nx = f.modo === 'sh' ? '' : '<div class="cp-nxd"><span class="cp-lb2">Próximas fechas</span><div>' + (pgProximas(f, 5).map(function (d) { return '<span class="cp-tg">' + fD(d) + '</span>'; }).join(' ') || '<small style="color:var(--muted)">Sin fechas</small>') + '</div></div>';
  return '<div class="cp-fld"><label>Cada cuánto</label>' + seg + '</div>' + cuerpo + hora + nx;
}
/* 431 · «Ver lo ejecutado» en el mismo cajón: lista de ejecuciones y, al tocar una, su detalle completo
   (trazabilidad, respuestas, comentarios, fotos y hallazgos) con los mismos datos de Operación (WsOperacion). */
var WSO = function (m, d) { return llamar(CFG.base_ + 'WebService/WsOperacion.asmx/', m, d); };
var EJTZ = { prog: 'calw', estado: 'clock', asig: 'check', acepta: 'check', inicio: 'clock', sync: 'arrow', fin: 'check', hallazgo: 'alert', descarte: 'x', ot: 'wrench', otini: 'wrench', otfin: 'check' };
var fHMe = function (x) { return x ? fD(dIso(x)) + ' ' + String(x).slice(11, 16) : '—'; };
A.pgej = function () {
  var tipo = PN.t === 'ins' ? 'INS' : 'TAR', st = PN;
  PN.ejv = { lista: null, det: null, oc: 0 }; panel();
  api('Ejecutadas', { tipo: tipo, id: PN.id }).then(function (r) { if (PN !== st || !PN.ejv) return; PN.ejv.lista = r.filas || []; panel(); }).catch(function (e) { if (PN === st) { PN.ejv = null; panel(); } toastError(e); });
};
A.pgejx = function () { if (PN.ejv && PN.ejv.oc) { PN.ejv.oc = 0; PN.ejv.det = null; } else PN.ejv = null; panel(); var b = $('#cpLayer .cp-pnl-b'); if (b) b.scrollTop = 0; };
A.pgejo = function (d) {
  var st = PN, tipo = PN.t === 'ins' ? 'INS' : 'TAR', oc = +d.v;
  PN.ejv.oc = oc; PN.ejv.det = null; panel();
  WSO(tipo === 'INS' ? 'Inspeccion' : 'Tarea', { ocurrencia: oc }).then(function (r) { if (PN !== st || !PN.ejv || PN.ejv.oc !== oc) return; PN.ejv.det = r; panel(); var b = $('#cpLayer .cp-pnl-b'); if (b) b.scrollTop = 0; }).catch(function (e) { if (PN === st && PN.ejv) { PN.ejv.oc = 0; panel(); } toastError(e); });
};
function ejFotos(l) { return l && l.length ? '<div class="cp-fot">' + l.map(function (f) { return '<a href="' + esc(f.URL) + '" target="_blank" rel="noopener"><img src="' + esc(f.URL) + '" alt="' + esc(f.TITULO || 'Foto de evidencia') + '" loading="lazy"></a>'; }).join('') + '</div>' : ''; }
function ejTraza(l) {
  if (!l || !l.length) return '';
  return '<div class="cp-blk"><div class="cp-blk-h"><h4>Trazabilidad</h4><small>' + pl(l.length, 'evento', 'eventos') + '</small></div><ol class="cp-tz">' + l.map(function (e) {
    var cls = e.CLASE === 'hallazgo' ? (+e.SEVERIDAD >= 4 ? ' cp-tz-r' : ' cp-tz-a') : e.CLASE === 'fin' || e.CLASE === 'otfin' ? ' cp-tz-ok' : e.CLASE.indexOf('ot') === 0 ? ' cp-tz-p' : '';
    return '<li class="' + cls + '"><span class="cp-tz-i">' + ic(EJTZ[e.CLASE] || 'clock', 12) + '</span><div class="cp-tz-b"><b>' + esc(e.TITULO) + '</b>' + (e.DETALLE ? '<small>' + esc(e.DETALLE) + '</small>' : '') + '<em>' + fHMe(e.FECHA) + (e.QUIEN ? ' · ' + esc(e.QUIEN) : '') + '</em>' + (e.URL ? '<a class="cp-lnk" href="' + esc(e.URL) + '">Abrir la OT</a>' : '') + '</div></li>';
  }).join('') + '</ol></div>';
}
function ejFacts(e, quien) {
  if (!e) return '';
  var dur = e.DURACION != null ? (+e.DURACION >= 60 ? fH(+e.DURACION / 60) : (+e.DURACION) + ' min') : '—';
  return '<div class="cp-facts"><div><span>Quién</span><b>' + esc(quien || '—') + '</b><small>' + esc(e.DISPOSITIVO || 'App') + (e.SIN_SENAL ? ' · sin señal' : '') + '</small></div><div><span>Duración</span><b>' + dur + '</b><small>' + fHMe(e.INICIO) + ' → ' + String(e.FIN || '').slice(11, 16) + '</small></div>' +
    (e.TOTAL != null ? '<div><span>Ítems</span><b>' + (+e.RESPONDIDOS || 0) + ' de ' + (+e.TOTAL || 0) + '</b><small>' + (+e.NO_CONFORMES ? pl(+e.NO_CONFORMES, 'no conforme', 'no conformes') : 'Todo conforme') + '</small></div>' : '') +
    (e.LAT != null && e.LNG != null ? '<div><span>Ubicación</span><b><a class="cp-lnk" href="https://www.google.com/maps?q=' + (+e.LAT) + ',' + (+e.LNG) + '" target="_blank" rel="noopener">Ver en el mapa</a></b></div>' : '') + '</div>' +
    (e.OBSERVACION ? '<p class="cp-obs">' + ic('help', 13) + esc(e.OBSERVACION) + '</p>' : '');
}
function ejDetalle(r, tipo) {
  if (tipo === 'TAR') {
    var c = r.cab, fot = {}; (r.fotos || []).forEach(function (f) { (fot[f.EJECUCION] = fot[f.EJECUCION] || []).push(f); });
    return '<div class="cp-exh"><span class="cp-tg">' + esc(c.ESTADO) + '</span><span class="cp-tg">' + fHMe(c.FECHA) + '</span></div>' +
      (r.ejecuciones || []).map(function (e) { return ejFacts(e, e.QUIEN) + '<div class="cp-rgr' + (e.CONFORME === false ? ' cp-bad' : '') + '"><div class="cp-rgn"><b>Resultado</b><small>' + (esc(e.RESULTADO) || 'Sin comentario') + '</small>' + ejFotos(fot[e.ID]) + '</div><span class="cp-rgv' + (e.CONFORME === false ? ' cp-bad' : '') + '">' + (e.CONFORME == null ? '—' : e.CONFORME ? 'Conforme' : 'No conforme') + '</span></div>'; }).join('') +
      (!(r.ejecuciones || []).length ? mc('i', 'Se marcó como hecha desde la web, sin registro de terreno.' + (c.OBSERVACION ? ' Observación: ' + esc(c.OBSERVACION) : ''), 'help') : '') + ejTraza(r.traza);
  }
  var res = {}, fot2 = {}; (r.respuestas || []).forEach(function (x) { res[x.ITEM] = x; }); (r.fotos || []).forEach(function (f) { (fot2[f.ITEM] = fot2[f.ITEM] || []).push(f); });
  var secs = []; (r.items || []).forEach(function (it) { var sc = secs.filter(function (z) { return z.n === it.SECCION; })[0]; if (!sc) { sc = { n: it.SECCION, items: [] }; secs.push(sc); } sc.items.push(it); });
  return '<div class="cp-exh"><span class="cp-tg">' + esc(r.cab.ESTADO) + '</span><span class="cp-tg">' + esc(r.cab.PAUTA_CODIGO) + ' v' + esc(r.cab.PAUTA_VERSION) + '</span><span class="cp-tg">' + esc(r.cab.ACTIVO_CODIGO || '') + '</span></div>' +
    ejFacts(r.ejecucion, r.cab.HECHA_POR) +
    ((r.hallazgos || []).length ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span><b>' + pl(r.hallazgos.length, 'hallazgo pasó', 'hallazgos pasaron') + ' a Avisos:</b> ' + r.hallazgos.map(function (h) { return esc(h.ITEM) + ' (' + (+h.SEVERIDAD >= 4 ? 'alta' : 'media') + ')'; }).join(', ') + '</span></div>' : '') +
    '<div class="cp-rgf2">' + secs.map(function (sc) {
      return '<div class="cp-rgs"><h5>' + esc(sc.n) + '</h5>' + sc.items.map(function (it) {
        var x = res[it.ID];
        return '<div class="cp-rgr' + (x && x.FUERA ? ' cp-bad' : '') + '"><div class="cp-rgn"><b>' + esc(it.TEXTO) + '</b>' + (it.CRITICO ? ' <span class="cp-tg cp-w">Crítico</span>' : '') + (x && x.COMENTARIO ? '<small>«' + esc(x.COMENTARIO) + '»' + (x.VOZ ? ' · dictado por voz' : '') + '</small>' : '') + ejFotos(fot2[it.ID]) + '</div>' +
          '<span class="cp-rgv' + (x && x.FUERA ? ' cp-bad' : x && x.NA ? ' cp-na' : '') + '">' + (x ? esc(x.VALOR || '—') : '<span class="cp-muted2">Sin respuesta</span>') + (x && x.FUERA ? '<small>' + ic('alert', 11) + 'Fuera de rango</small>' : '') + '</span></div>';
      }).join('') + '</div>';
    }).join('') + '</div>' + ejTraza(r.traza);
}
function ejPanel() {
  var v = PN.ejv, tipo = PN.t === 'ins' ? 'INS' : 'TAR', nom = esc(PN.n || (PN.fila && PN.fila.NOMBRE) || '');
  var vol = '<button type="button" class="cp-btn cp-plain cp-xs cp-ejback" data-a="pgejx">' + ic('chevl', 14) + (v.oc ? 'Volver a la lista' : 'Volver a la programación') + '</button>';
  var b;
  if (v.oc) b = vol + (v.det ? ejDetalle(v.det, tipo) : '<div class="cp-sk" style="height:80px;margin-top:10px"></div><div class="cp-sk" style="height:220px;margin-top:10px"></div>');
  else if (!v.lista) b = vol + '<div class="cp-sk" style="height:60px;margin-top:10px"></div><div class="cp-sk" style="height:60px;margin-top:8px"></div>';
  else b = vol + (v.lista.length ? '<div class="cp-ejl">' + v.lista.map(function (x) {
    var chip = tipo === 'INS' ? (+x.HALLAZGOS ? '<span class="cp-tg cp-w">' + pl(+x.HALLAZGOS, 'hallazgo', 'hallazgos') + '</span>' : (x.QUIEN ? '<span class="cp-tg cp-c">Sin hallazgos</span>' : '')) : (x.CONFORME === false ? '<span class="cp-tg cp-w">No conforme</span>' : x.CONFORME ? '<span class="cp-tg cp-c">Conforme</span>' : '');
    return '<button type="button" class="cp-ejr" data-a="pgejo" data-v="' + x.OCURRENCIA + '"><span class="cp-ejr-d"><b>' + fD(dIso(x.FECHA)) + '</b><small>' + String(x.FECHA).slice(11, 16) + '</small></span><span class="cp-s"><b>' + esc(x.ACTIVO || '—') + '</b><small>' + (x.QUIEN ? esc(x.QUIEN) + ' · ' + fHMe(x.HECHA_EL) + (x.DISPOSITIVO ? ' · ' + esc(x.DISPOSITIVO) : '') : esc(x.ESTADO)) + '</small></span>' + chip + (+x.FOTOS ? '<span class="cp-tg">' + pl(+x.FOTOS, 'foto', 'fotos') + '</span>' : '') + ic('chev', 14) + '</button>';
  }).join('') + '</div>' : '<div class="cp-empty" style="margin-top:10px">' + ic('clip', 18) + '<b>Todavía no hay ejecuciones</b>Cuando alguien la registre en la app (o desde Operación), aparecerá aquí con sus respuestas, fotos y trazabilidad.</div>');
  return { t: nom || (tipo === 'INS' ? 'Inspección' : 'Tarea'), s: (v.oc ? 'Lo ejecutado · detalle' : 'Lo ejecutado · últimas 30'), w: 'w', b: b, f: '<span></span><span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pgejx">Volver</button></span>' };
}
/* 430 · Lo que se respondió en terreno (app o web) se ve en Operación › Ejecuciones › Completadas → «ver». */
function pgEjecutado(h) {
  var k = PN && PN.t === 'ins' ? 'ron' : 'tar';
  return '<div class="cp-pgej">' + ic('clip', 15) + '<span>Respuestas, comentarios, fotos, hallazgos y trazabilidad de cada ejecución en terreno.</span><button type="button" class="cp-btn cp-out cp-xs" data-a="pgej">Ver lo ejecutado</button></div>';
}
function pgFacts(h) { return pgFacts0(h) + pgEjecutado(h); }
function pgFacts0(h) { var t = +h.TOTAL || 0; return '<div class="cp-facts">' + '<div><span>Cumplimiento 30 días</span><b>' + (t ? (+h.HECHAS || 0) + ' de ' + t : 'Sin registros aún') + '</b></div>' + (h.ESCALADAS != null ? '<div><span>Escaladas a OT</span><b>' + (+h.ESCALADAS || 0) + '</b></div>' : '<div><span>Activos</span><b>' + (+h.ACTIVOS || 0) + '</b></div>') + '</div>'; }
/* Quién la ejecuta: Disponible (nadie asignado: en la app la ve quien puede ejecutarla y la toma quien
   llegue primero; ahí puede sumar integrantes, un grupo o una empresa externa), una o varias personas,
   un grupo de trabajo o una empresa externa. */
var ASM = [['D', 'Disponible'], ['P', 'Personas'], ['G', 'Grupo de trabajo'], ['E', 'Empresa externa']];
function pgAsDesde(cod) { var m = /^([PGE]):(.+)$/.exec(cod || ''); return m ? { modo: m[1], ids: m[2].split(',').filter(Boolean).map(Number) } : { modo: 'D', ids: [] }; }
/* 420 · Carga laboral: chip con las horas de los próximos 30 días y «Ver carga» (calendario mensual). */
function cargaUI(clave, nombre, detalle) { return window.SigmaCarga ? '<span class="cp-carga">' + SigmaCarga.chipDe(clave) + SigmaCarga.boton(clave, nombre, detalle) + '</span>' : ''; }
function cargaBtn(clave, nombre, fechaIso, txt) { return window.SigmaCarga && clave ? SigmaCarga.boton(clave, nombre, '', txt, fechaIso) : ''; }
/* 421 · Quién choca: una fila por persona, grupo o empresa ocupada, con el trabajo que ya tiene y «Ver carga». */
function quienesChocan(l) {
  var vis = {}, r = (l || []).filter(function (c) { if (c.CLASE !== 'RECURSO' || !c.CLAVE || vis[c.CLAVE]) return false; vis[c.CLAVE] = 1; return true; });
  if (!r.length) return '';
  return '<div class="cp-qch"><span class="cp-qch-t">Quién tiene el choque</span>' + r.map(function (c) {
    var n = (l || []).filter(function (x) { return x.CLAVE === c.CLAVE; }).length;
    return '<div class="cp-qch-r">' + (c.CLAVE.charAt(0) === 'U' ? avatar(String(c.OBJETO).replace(/\s*\(grupo.*$/, '')) : '<span class="cp-av" style="background:#E8FBFB;color:#007F8A">' + ic(c.CLAVE.charAt(0) === 'G' ? 'users' : 'box', 14) + '</span>') +
      '<span class="cp-s"><b>' + esc(c.OBJETO) + '</b><small>Ya está en ' + (TIPN[c.CON_TIPO] || '').toLowerCase() + ' ' + esc(c.CON_CODIGO) + ' · ' + fD(dIso(c.CON_INICIO)) + ' ' + hIso(c.CON_INICIO) + '–' + hIso(c.CON_FIN) + (n > 1 ? ' · ' + pl(n, 'fecha', 'fechas') + ' con choque' : '') + '</small></span>' +
      cargaBtn(c.CLAVE, String(c.OBJETO).replace(/\s*\(grupo.*$/, ''), c.CON_INICIO) + '</div>';
  }).join('') + '</div>';
}
function pgAsHTML(as, e) {
  var seg = '<div class="cp-segc" role="group" aria-label="Quién la ejecuta">' + ASM.map(function (o) { return '<button type="button" data-a="pgas" data-v="' + o[0] + '" aria-pressed="' + (as.modo === o[0]) + '">' + o[1] + '</button>'; }).join('') + '</div>';
  var falta = e && as.modo !== 'D' && !as.ids.length, b = '';
  if (as.modo === 'D') b = mc('i', 'Queda <b>disponible</b>: en la app la ve quien puede ejecutarla y la toma quien llegue primero. Ahí puede sumar integrantes, un grupo o una empresa externa.', 'help');
  if (as.modo === 'P') {
    var gente = pgPersonas(), sel = as.ids.map(function (id) { return gente.filter(function (p) { return +p.id === +id; })[0]; }).filter(Boolean);
    b = (sel.length ? '<div class="cp-avl">' + sel.map(function (p, i) { return '<div class="cp-rp">' + (p.img ? '<img class="cp-av cp-avi cp-lg" src="' + esc(p.img) + '" alt="">' : avatar(p.n).replace('class="cp-av"', 'class="cp-av cp-lg"')) + '<span class="cp-s"><b>' + esc(p.n) + (i === 0 ? ' <span class="cp-tg cp-p">Responsable</span>' : ' <span class="cp-tg">Apoyo</span>') + '</b><small>' + esc(p.sub || 'Sin perfil') + '</small></span>' + cargaUI('U:' + p.id, p.n, p.sub) + '<button type="button" class="cp-ibx cp-dn" data-a="pgasrm" data-v="' + p.id + '" aria-label="Quitar ' + esc(p.n) + '">' + ic('x', 14) + '</button></div>'; }).join('') + '</div>' : '') +
      combo('cpPgAsP', gente.filter(function (p) { return as.ids.indexOf(+p.id) < 0; }), '', { etiqueta: 'Agregar persona', ph: sel.length ? 'Agregar otra persona' : 'Elige quién la ejecuta', err: falta, data: ' data-pg="asadd"' });
  }
  if (as.modo === 'G') {
    var g = as.ids[0], ints = (PG.integrantes || []).filter(function (x) { return +x.GRUPO_ID === +g; });
    var gN = ((PG.grupos || []).filter(function (x) { return +x.ID === +g; })[0] || {}).NOMBRE || '';
    b = combo('cpPgAsG', (PG.grupos || []).map(function (x) { return { id: x.ID, n: x.NOMBRE }; }), g || '', { etiqueta: 'Grupo de trabajo', ph: 'Elige el grupo', err: falta, data: ' data-pg="asone"' }) +
      (g ? '<div class="cp-carga-row">' + cargaUI('G:' + g, gN, 'Grupo de trabajo') + '</div>' : '') +
      (g ? '<small style="display:block;margin-top:6px;color:var(--muted);font-size:12px">' + (ints.length ? pl(ints.length, 'integrante', 'integrantes') + ': ' + esc(ints.map(function (x) { var p = (PG.personas || []).filter(function (y) { return +y.ID === +x.USUARIO_ID; })[0]; return p ? p.NOMBRE : ''; }).filter(Boolean).join(', ')) : 'El grupo no tiene integrantes vigentes.') + '</small>' : '');
  }
  if (as.modo === 'E') b = combo('cpPgAsE', (PG.proveedores || []).map(function (x) { return { id: x.ID, n: x.NOMBRE }; }), as.ids[0] || '', { etiqueta: 'Empresa externa', ph: 'Elige la empresa', err: falta, data: ' data-pg="asone"' }) +
    (as.ids[0] ? '<div class="cp-carga-row">' + cargaUI('E:' + as.ids[0], ((PG.proveedores || []).filter(function (x) { return +x.ID === +as.ids[0]; })[0] || {}).NOMBRE || '', 'Empresa externa') + '</div>' : '') +
    ((PG.proveedores || []).length ? '' : mc('i', 'No hay empresas contratistas registradas en Terceros.', 'help'));
  return '<div class="cp-fld"><label>Quién la ejecuta</label>' + seg + '</div><div class="cp-fld">' + b + (falta ? mc('', as.modo === 'P' ? 'Elige al menos una persona o déjala disponible.' : as.modo === 'G' ? 'Elige el grupo.' : 'Elige la empresa.') : '') + '</div>';
}
var pgRespDur = function (as, dur, e) {
  return pgAsHTML(as, e) + '<div class="cp-fld" style="max-width:220px"><label for="cpPgDu">Duración</label><div class="cp-unit"><input id="cpPgDu" class="cp-inp" type="number" step="0.25" min="0.25" data-pg="dur" value="' + esc(dur) + '"><span class="cp-u">horas</span></div></div>';
};

/* ---- inspección ---- */
function abrirIns(id) {
  var plantas = CFG.plantas || [];
  openPanel({ t: 'ins', pg: true, id: id || 0, cargando: true, err: false, busy: false, err2: '', n: '', pau: '', pl: U.planta || (plantas[0] || {}).id || 0, eqs: [], aq: '', as: { modo: 'D', ids: [] }, dur: 1, f: pgFreqVacia(), fila: (INS.filas || []).filter(function (x) { return +x.ID === +id; })[0] || null });
  Promise.all([pgCatalogo(), id ? api('Inspeccion', { id: id }) : null]).then(function (x) {
    if (!PN || PN.t !== 'ins') return;
    var r = x[1];
    if (r) {
      var h = r.cabecera; PN.n = h.NOMBRE || ''; PN.pau = h.PLANTILLA; PN.as = pgAsDesde(h.ASIGNACION); PN.dur = h.DURACION ? Math.round(h.DURACION / 60 * 100) / 100 : 1; PN.pl = h.PLANTA_ID || PN.pl;
      PN.eqs = (r.activos || []).map(function (a) { var b = pgBase(pgAct(a.ACTIVO)); return { a: b ? +b.ID : +a.ACTIVO, o: pgObjDesde(a.ACTIVO, a.COMPONENTE) }; });
      PN.f = pgFreqDesde(r.frecuencia);
    } else if (PG.pautas.length) PN.pau = PG.pautas[0].ID;
    PN.cargando = false; panel();
  }).catch(function (e) { closePanel(); toastError(e); });
}
/* Las otras inspecciones que ya recorren un activo (mockup: «En RON-002»), sin contar la que se edita. */
function pgEnOtras(actId) { return (PG.enInspeccion || []).filter(function (x) { return +x.ACTIVO_ID === +actId && +x.INSPECCION !== +PN.id; }); }
function pgEnTag(actId) { var l = pgEnOtras(actId); return l.length ? '<span class="cp-tg" title="Ya lo recorre ' + esc(l.map(function (x) { return x.CODIGO + ' · ' + x.NOMBRE; }).join(', ')) + '">En ' + esc(l.map(function (x) { return x.CODIGO; }).join(', ')) + '</span>' : ''; }
/* 427 · Un solo listado: al marcar un activo, en su misma fila aparecen el orden, el objeto mantenible y las flechas.
   Arriba, el resumen del recorrido y «Solo los elegidos» (antes se marcaba abajo y aparecía arriba). */
function pgPicker(e) {
  var sel = PN.eqs, q = nrm(PN.aq || ''), pool = PG.activos.filter(function (a) { return !a.PADRE_ID && (!PN.pl || +a.PLANTA_ID === +PN.pl); });
  var pos = function (id) { for (var k = 0; k < sel.length; k++) if (+sel[k].a === +id) return k; return -1; };
  if (PN.solo && !sel.length) PN.solo = false;
  var areas = []; pool.forEach(function (a) { if (areas.indexOf(a.AREA) < 0) areas.push(a.AREA); });
  var fila = function (a) {
    var k = pos(a.ID), on = k >= 0, x = on ? sel[k] : null, subs = PG.activos.filter(function (s2) { return +s2.PADRE_ID === +a.ID; }).length, cs = PG.componentes.filter(function (c) { return +c.ACTIVO_ID === +a.ID; }).length;
    return '<div class="cp-apr2' + (on ? ' cp-on' : '') + '">' +
      '<button type="button" class="cp-apr2-h" data-a="pgeq" data-v="' + a.ID + '" aria-pressed="' + on + '">' +
      '<span class="cp-cbx2' + (on ? ' cp-on' : '') + '"></span>' +
      '<span class="cp-apr2-img">' + (a.IMG ? '<img src="' + esc(a.IMG) + '" alt="" loading="lazy">' : ic('box', 16)) + '</span>' +
      '<span class="cp-s"><b>' + esc(a.NOMBRE) + '</b><small>' + esc(a.CODIGO) + ' · ' + esc(a.TIPO || 'Sin tipo') + (subs ? ' · ' + pl(subs, 'subactivo', 'subactivos') : '') + (cs ? ' · ' + pl(cs, 'componente', 'componentes') : '') + '</small></span>' +
      pgEnTag(a.ID) + (+a.CRITICIDAD ? '<span class="cp-crit cp-c-' + pgCrit(a.CRITICIDAD) + '" title="Criticidad ' + a.CRITICIDAD + '">' + a.CRITICIDAD + '</span>' : '') +
      (on ? '<span class="cp-apr2-n" title="Orden en el recorrido">' + (k + 1) + '</span>' : '') + '</button>' +
      (on ? '<div class="cp-apr2-b"><span class="cp-apr2-l">Se inspecciona</span><span class="cp-apr2-o">' + combo('cpPgO' + k, pgObjOpts(a), x.o, { etiqueta: 'Objeto mantenible de ' + a.CODIGO, data: ' data-pg="o:' + k + '"' }) + '</span>' +
        '<span class="cp-apr2-a"><button type="button" class="cp-ibx" data-a="pgmv" data-v="' + k + '" data-d="-1"' + (k ? '' : ' disabled') + ' aria-label="Antes en el recorrido" title="Antes en el recorrido">' + ic('chev', 14).replace('<svg', '<svg style="transform:rotate(-90deg)"') + '</button>' +
        '<button type="button" class="cp-ibx" data-a="pgmv" data-v="' + k + '" data-d="1"' + (k < sel.length - 1 ? '' : ' disabled') + ' aria-label="Después en el recorrido" title="Después en el recorrido">' + ic('chev', 14).replace('<svg', '<svg style="transform:rotate(90deg)"') + '</button></span></div>' : '') + '</div>';
  };
  var lista;
  if (PN.solo) lista = '<div class="cp-apg">' + sel.map(function (x) { return fila(pgAct(x.a) || { ID: x.a, NOMBRE: 'Activo ' + x.a }); }).join('') + '</div>';
  else lista = areas.map(function (ar) {
    var all = pool.filter(function (a) { return a.AREA === ar; }), as = all.filter(function (a) { return !q || nrm(a.CODIGO + ' ' + a.NOMBRE + ' ' + a.TIPO).indexOf(q) >= 0; });
    if (!as.length) return '';
    var n = all.filter(function (a) { return pos(a.ID) >= 0; }).length;
    return '<div class="cp-apg"><button type="button" class="cp-apg-h" data-a="pgarea" data-v="' + esc(ar) + '"><span class="cp-cbx2 ' + (n === all.length ? 'cp-on' : n ? 'cp-mx' : '') + '"></span><b>' + esc(ar) + '</b><small>' + n + ' de ' + all.length + '</small></button>' + as.map(fila).join('') + '</div>';
  }).join('');
  var resumen = '<div class="cp-apk-r' + (e && !sel.length ? ' cp-err' : '') + '">' + ic('clip', 16) + '<span>' + (sel.length ? '<b>' + pl(sel.length, 'activo', 'activos') + ' en el recorrido</b> · ~' + sel.length * 10 + ' min (10 por activo). El número es el orden.' : '<b>Marca los activos que recorre.</b> Al marcarlo eliges ahí mismo qué se inspecciona y su orden.') + '</span>' +
    (sel.length ? '<button type="button" class="cp-btn cp-plain cp-xs" data-a="pgsolo" aria-pressed="' + !!PN.solo + '">' + (PN.solo ? 'Ver todos' : 'Solo los elegidos') + '</button>' : '') + '</div>';
  return '<div class="cp-fld"><label>Activos que recorre <small>' + (sel.length ? pl(sel.length, 'activo', 'activos') : 'obligatorio') + '</small></label>' + resumen +
    '<div class="cp-apk">' + (PN.solo ? '' : '<label class="cp-srch2">' + ic('search', 14) + '<input data-pg="aq" value="' + esc(PN.aq || '') + '" placeholder="Buscar por código, nombre o tipo" aria-label="Buscar activos" autocomplete="off"></label>') +
    '<div class="cp-apk-l">' + (lista || '<div class="cp-empty" style="border:0">' + ic('search', 18) + '<b>Ningún activo coincide</b></div>') + '</div></div></div>';
}
A.pgsolo = function () { PN.solo = !PN.solo; panel(); };

/* 427 · La pauta elegida: qué contiene y, si hace falta, editarla aquí mismo (publica una versión nueva en Recursos). */
var PV = {}, WSR = function (m, d) { return llamar(CFG.base_ + 'WebService/WsRecursos.asmx/', m, d); };
var PITT = { ok: 'Cumple / no cumple', num: 'Medición con rango', txt: 'Texto', foto: 'Foto' }, PTIPO = { 5: 'ok', 4: 'num', 3: 'num', 1: 'txt', 2: 'txt', 12: 'foto' };
function pvCargar(id) {
  PV[id] = { cargando: true };
  WSR('Pauta', { id: +id }).then(function (r) {
    var secs = (r.secciones || []).map(function (x) { return { codigo: x.CODIGO, n: x.NOMBRE, items: [] }; });
    (r.items || []).forEach(function (i) {
      var sc = secs.filter(function (z) { return z.codigo === i.SECCION; })[0]; if (!sc) { sc = { codigo: i.SECCION || '', n: 'General', items: [] }; secs.push(sc); }
      sc.items.push({ k: i.CODIGO, codigo: i.CODIGO, tipoId: i.TIPO, n: i.TEXTO, t: PTIPO[i.TIPO] || 'txt', min: i.MINIMO == null ? '' : i.MINIMO, max: i.MAXIMO == null ? '' : i.MAXIMO, unidad: i.UNIDAD || 0, u: i.UNIDAD_SIMBOLO || '', crit: !!i.CRITICO });
    });
    if (!secs.length) secs.push({ codigo: '', n: 'General', items: [] });
    PV[id] = { cab: r.cabecera, secs: secs, deps: (r.dependencias || []).length, usos: r.usos || [] };
    if (PN && PN.t === 'ins') panel();
  }).catch(function (e) { PV[id] = { error: e.message }; if (PN && PN.t === 'ins') panel(); });
}
function pvRango(it) { var a = it.min !== '' && it.min != null, b = it.max !== '' && it.max != null, u = it.u ? ' ' + it.u : ''; return a && b ? fN(+it.min) + '–' + fN(+it.max) + u : a ? '≥ ' + fN(+it.min) + u : b ? '≤ ' + fN(+it.max) + u : ''; }
function pgPautaHTML() {
  if (!PN.pau) return '';
  var v = PV[PN.pau]; if (!v) { pvCargar(PN.pau); v = PV[PN.pau]; }
  if (v.cargando) return '<div class="cp-pv"><div class="cp-sk" style="height:70px"></div></div>';
  if (v.error) return mc('', 'No se pudo leer la pauta: ' + esc(v.error));
  var ed = !!PN.pved, n = v.secs.reduce(function (t, z) { return t + z.items.length; }, 0), a = PN.pva || (PN.pva = { n: '', t: 'ok', s: 0, min: '', max: '', crit: false });
  var abierto = ed || PN.pvo;
  var h = '<div class="cp-pv"><div class="cp-pv-h"><button type="button" class="cp-pv-t" data-a="pvtog" aria-expanded="' + !!abierto + '">' + ic('clip', 16) + '<b>Qué contiene la pauta</b><small>' + pl(n, 'ítem', 'ítems') + ' · ' + pl(v.secs.length, 'sección', 'secciones') + (v.deps ? ' · ' + pl(v.deps, 'dependencia', 'dependencias') : '') + '</small>' + ic('chev', 14).replace('<svg', '<svg style="margin-left:auto;transition:transform .15s;' + (abierto ? 'transform:rotate(90deg)' : '') + '"') + '</button>' +
    (ed ? '' : '<button type="button" class="cp-btn cp-out cp-xs" data-a="pved">' + ic('pencil', 13) + 'Editar pauta</button>') + '</div>';
  if (!abierto) return h + '</div>';
  h += v.secs.map(function (sc, si) {
    return '<div class="cp-pv-s"><h5>' + esc(sc.n) + '</h5><ul>' + (sc.items.map(function (it, ii) {
      return '<li><span class="cp-pv-n"><b>' + esc(it.n) + '</b><small>' + PITT[it.t] + (it.t === 'num' && pvRango(it) ? ' · ' + esc(pvRango(it)) : '') + '</small></span>' + (it.crit ? '<span class="cp-tg cp-w">Crítico</span>' : '') +
        (ed ? '<button type="button" class="cp-ibx cp-sm" data-a="pvrm" data-s="' + si + '" data-v="' + ii + '" aria-label="Quitar ' + esc(it.n) + '">' + ic('x', 13) + '</button>' : '') + '</li>';
    }).join('') || '<li class="cp-muted2">Sin ítems</li>') + '</ul></div>';
  }).join('');
  if (ed) {
    h += '<div class="cp-pv-add"><div class="cp-grid2c"><div class="cp-fld" style="grid-column:1/-1"><label for="cpPvN">Agregar ítem · qué se revisa</label><input id="cpPvN" class="cp-inp" data-pg="pva.n" value="' + esc(a.n) + '" placeholder="Ej.: Temperatura del rodamiento" maxlength="500" autocomplete="off"></div>' +
      '<div class="cp-fld"><label>Tipo de respuesta</label>' + combo('cpPvT', Object.keys(PITT).map(function (k) { return { id: k, n: PITT[k] }; }), a.t, { etiqueta: 'Tipo de respuesta', data: ' data-pg="pva.t"' }) + '</div>' +
      '<div class="cp-fld"><label>Sección</label>' + combo('cpPvS', v.secs.map(function (z, i) { return { id: i, n: z.n }; }), a.s, { etiqueta: 'Sección', ph: 'Elige o escribe una sección nueva', crear: true, data: ' data-pg="pva.s"' }) + '</div>' +
      (a.t === 'num' ? '<div class="cp-fld"><label for="cpPvMn">Mínimo</label><input id="cpPvMn" class="cp-inp" type="number" step="any" data-pg="pva.min" value="' + esc(a.min) + '"></div><div class="cp-fld"><label for="cpPvMx">Máximo</label><input id="cpPvMx" class="cp-inp" type="number" step="any" data-pg="pva.max" value="' + esc(a.max) + '"></div>' : '') + '</div>' +
      '<div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap"><label class="cp-sw"><input type="checkbox" data-pg="pva.crit"' + (a.crit ? ' checked' : '') + '><i></i>Ítem crítico</label><button type="button" class="cp-btn cp-out cp-xs" data-a="pvadd">' + ic('plus', 13) + 'Agregar ítem</button></div></div>' +
      '<div class="cp-pv-f">' + (v.usos.length ? '<small>' + ic('help', 12) + 'La usan ' + pl(v.usos.length, 'inspección', 'inspecciones') + ': la versión nueva rige para todas desde su próxima fecha.</small>' : '<small>' + ic('help', 12) + 'Se publica como versión nueva en Recursos › Pautas.</small>') +
      '<span><button type="button" class="cp-btn cp-ghost cp-xs" data-a="pvcan">Descartar</button><button type="button" class="cp-btn cp-pri cp-xs' + (PN.pvbusy ? ' cp-load' : '') + '" data-a="pvpub"' + (PN.pvdirty ? '' : ' disabled') + '>' + ic('check', 13) + 'Publicar v' + ((+(v.cab && v.cab.VERSION_PUBLICADA) || 0) + 1) + '</button></span></div>';
  }
  return h + '</div>';
}
A.pvtog = function () { PN.pvo = !PN.pvo; panel(); };
A.pved = function () { PN.pved = true; PN.pvo = true; PN.pvdirty = false; panel(); };
A.pvcan = function () { PN.pved = false; PN.pvdirty = false; PN.pva = null; delete PV[PN.pau]; panel(); };
A.pvrm = function (d) { var v = PV[PN.pau]; v.secs[+d.s].items.splice(+d.v, 1); PN.pvdirty = true; panel(); };
A.pvadd = function () {
  var v = PV[PN.pau], a = PN.pva; if (!String(a.n).trim()) { var el = $('#cpPvN'); if (el) el.focus(); return; }
  v.secs[+a.s || 0].items.push({ k: 'n' + Date.now(), codigo: '', n: String(a.n).trim(), t: a.t, min: a.t === 'num' ? a.min : '', max: a.t === 'num' ? a.max : '', unidad: 0, u: '', crit: !!a.crit });
  PN.pva = { n: '', t: a.t, s: a.s, min: '', max: '', crit: false }; PN.pvdirty = true; panel(); var e2 = $('#cpPvN'); if (e2) { e2.value = ''; e2.focus(); }
};
A.pvpub = function (d, el) {
  if (el && el.disabled) return;
  var v = PV[PN.pau], st = PN, id = +PN.pau;
  if (!v.secs.some(function (z) { return z.items.length; })) { toastError('La pauta necesita al menos un ítem.'); return; }
  PN.pvbusy = true; panel();
  WSR('GuardarPauta', { datos: JSON.stringify({ id: id, nombre: v.cab ? v.cab.NOMBRE : '', secciones: v.secs.filter(function (z) { return z.items.length || z.codigo; }).map(function (z) { return { codigo: z.codigo, nombre: z.n, items: z.items.map(function (i) { return { k: i.k || '', codigo: i.codigo || '', tipoId: i.tipoId || 0, texto: i.n, tipo: i.t, min: i.min, max: i.max, unidad: i.unidad || 0, crit: !!i.crit }; }) }; }) }) })
    .then(function (r) {
      if (PN !== st) return;
      PN.pvbusy = false; PN.pved = false; PN.pvdirty = false; PN.pva = null; delete PV[id];
      var pa = (PG.pautas || []).filter(function (x) { return +x.ID === id; })[0]; if (pa) { pa.VERSION = r.version; pa.ITEMS = v.secs.reduce(function (t, z) { return t + z.items.length; }, 0); }
      panel(); toast(r.codigo + ' v' + r.version + ' publicada. Rige desde la próxima fecha de cada inspección que la usa.');
    }).catch(function (e) { if (PN !== st) return; PN.pvbusy = false; panel(); toastError(e); });
};

PANELS.ins = function () {
  if (PN.ejv && !PN.cargando) return ejPanel();
  if (PN.cargando) return { t: PN.id ? 'Inspección' : 'Nueva inspección', s: 'Planificación · inspecciones', w: 'w', b: '<div class="cp-sk" style="height:40px"></div><div class="cp-sk" style="height:300px;margin-top:12px"></div>' };
  var e = PN.err, plantas = CFG.plantas || [];
  var pautas = PG.pautas.map(function (p) { return { id: p.ID, n: p.CODIGO + ' v' + p.VERSION + ' · ' + p.NOMBRE, sub: pl(+p.ITEMS, 'ítem', 'ítems') }; });
  var b = (PN.id && PN.fila ? pgFacts(PN.fila) : '') +
    '<div class="cp-fld"><label for="cpPgN">Nombre <small>obligatorio</small></label><input id="cpPgN" class="cp-inp' + (e && !PN.n.trim() ? ' cp-err' : '') + '" data-pg="n" value="' + esc(PN.n) + '" placeholder="Ej.: Inspección sala de bombas" maxlength="200" autocomplete="off"' + (PN.id ? '' : ' data-autofocus="1"') + '>' + (e && !PN.n.trim() ? mc('', 'La inspección necesita un nombre.') : '') + '</div>' +
    '<div class="cp-fld"><label>Pauta de inspección</label>' + (pautas.length ? combo('cpPgPau', pautas, PN.pau, { etiqueta: 'Pauta de inspección', ph: 'Elige la pauta', err: e && !PN.pau, data: ' data-pg="pau"' })
      : mc('', 'No hay pautas publicadas. Créala en <a class="cp-lnk" href="' + esc(CFG.base_ + 'View/Mantenimiento/Biblioteca/Biblioteca.aspx#pautas') + '">Recursos › Pautas de inspección</a>.')) + '</div>' +
    pgPautaHTML() +
    (plantas.length > 1 ? '<div class="cp-fld"><label>Planta</label><div class="cp-segc">' + plantas.map(function (p) { return '<button type="button" data-a="pgpl" data-v="' + p.id + '" aria-pressed="' + (+PN.pl === +p.id) + '">' + esc(p.n) + '</button>'; }).join('') + '</div></div>' : '') +
    pgPicker(e) + (e && !PN.eqs.length ? mc('', 'Elige al menos un activo.') : '') +
    pgChoqGuardados() + pgFreqHTML(PN.f, e) + pgRespDur(PN.as, PN.dur, e) + choquesHTML(PN.choq, 'Si es intencional, guarda igual; si no, cambia la hora, la frecuencia, el objeto mantenible o quién la ejecuta.') + (PN.err2 ? mc('', esc(PN.err2)) : '');
  return { t: PN.id ? esc(PN.n || 'Inspección') : 'Nueva inspección', s: PN.id ? (PN.fila ? esc(PN.fila.CODIGO) + ' · ' : '') + 'programación' : 'Planificación · inspecciones', w: 'w', b: b,
    f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-pri' + (PN.busy ? ' cp-load' : '') + '" data-a="pginsok">' + ic(PN.choq && PN.choq.length ? 'alert' : 'check', 16) + (PN.choq && PN.choq.length ? 'Guardar igual' : (PN.id ? 'Guardar cambios' : 'Crear inspección')) + '</button></span>' };
};

/* ---- tarea recurrente ---- */
function abrirTar(id) {
  openPanel({ t: 'tar', pg: true, id: id || 0, cargando: true, err: false, busy: false, err2: '', n: '', cat: '', eq: '', o: '', desc: '', proc: '', pasos: [], paso: '', as: { modo: 'D', ids: [] }, dur: .5, f: pgFreqVacia(), fila: (TAR.filas || []).filter(function (x) { return +x.ID === +id; })[0] || null });
  Promise.all([pgCatalogo(), id ? api('Tarea', { id: id }) : null]).then(function (x) {
    if (!PN || PN.t !== 'tar') return;
    var r = x[1];
    if (r) {
      var h = r.cabecera, b = pgBase(pgAct(h.ACTIVO));
      PN.n = h.NOMBRE || ''; PN.cat = h.CATEGORIA || ''; PN.eq = b ? b.ID : ''; PN.o = h.ACTIVO ? pgObjDesde(h.ACTIVO, h.COMPONENTE) : ''; PN.desc = h.DESCRIPCION || '';
      PN.as = pgAsDesde(h.ASIGNACION); PN.dur = h.DURACION ? Math.round(h.DURACION / 60 * 100) / 100 : .5; PN.f = pgFreqDesde(r.frecuencia);
      PN.proc = r.procedimiento ? String(r.procedimiento.ID) : ''; PN.pasos = r.pasos || [];
      if (PN.fila) PN.fila.ESCALADAS = h.ESCALADAS;
    } else if (PG.categorias.length) PN.cat = PG.categorias[0].ID;
    PN.cargando = false; panel();
  }).catch(function (e) { closePanel(); toastError(e); });
}
/* 426 · «Qué hacer» de la tarea: instrucción, un procedimiento ya creado (primero los del tipo del activo) y/o pasos. */
var durMin = function (m) { m = +m || 0; return m < 60 ? m + ' min' : fH(m / 60); };
function tarQueHacerHTML(base) {
  var tipo = base ? base.TIPO_ID : null, tipoN = base ? base.TIPO : '';
  var procs = (PG.procedimientos || []).slice().sort(function (a, b) { var x = +(+a.ACTIVO_TIPO_ID === +tipo && tipo), y = +(+b.ACTIVO_TIPO_ID === +tipo && tipo); return y - x || String(a.CODIGO).localeCompare(b.CODIGO); })
    .map(function (p) { var rec = tipo && +p.ACTIVO_TIPO_ID === +tipo; return { id: p.ID, n: p.CODIGO + ' v' + (p.VERSION || 1) + ' · ' + p.NOMBRE, sub: (rec ? '★ Para ' + tipoN + ' · ' : (p.TIPO ? p.TIPO + ' · ' : 'General · ')) + pl(+p.PASOS || 0, 'paso', 'pasos') + (p.DURACION ? ' · ' + durMin(p.DURACION) : ''), tag: rec ? { k: 'a', t: 'Recomendado' } : null }; });
  var sel = (PG.procedimientos || []).filter(function (p) { return String(p.ID) === String(PN.proc); })[0];
  var nRec = tipo ? (PG.procedimientos || []).filter(function (p) { return +p.ACTIVO_TIPO_ID === +tipo; }).length : 0;
  return '<div class="cp-blk"><div class="cp-blk-h"><h4>Qué hacer</h4><small>Instrucción, procedimiento y/o pasos: lo ve quien la ejecuta en la app</small></div>' +
    '<div class="cp-fld"><label for="cpPgD">Instrucción <small>opcional</small></label><textarea id="cpPgD" class="cp-inp" rows="2" data-pg="desc" placeholder="Ej.: Revisar que no haya fugas y que el manómetro marque entre 4 y 6 bar">' + esc(PN.desc) + '</textarea></div>' +
    '<div class="cp-fld"><label>Procedimiento <small>' + (nRec ? nRec + ' recomendado' + (nRec > 1 ? 's' : '') + ' para ' + esc(tipoN) : 'opcional') + '</small></label>' +
    combo('cpPgProc', [{ id: '', n: 'Sin procedimiento' }].concat(procs), PN.proc || '', { etiqueta: 'Procedimiento', ph: procs.length ? 'Elige un procedimiento ya creado' : 'No hay procedimientos en Recursos', data: ' data-pg="proc"' }) +
    (sel ? '<div class="cp-prc" style="margin-top:8px"><span class="cp-pci">' + ic('clip', 17) + '</span><div style="min-width:0"><b>' + esc(sel.CODIGO) + ' v' + (sel.VERSION || 1) + ' · ' + esc(sel.NOMBRE) + '</b><small>' + pl(+sel.PASOS || 0, 'paso', 'pasos') + (sel.DURACION ? ' · ' + durMin(sel.DURACION) : '') + ' · se ejecuta tal cual está en Recursos</small></div></div>' : '') + '</div>' +
    '<div class="cp-fld"><label>Pasos <small>' + (PN.pasos.length ? pl(PN.pasos.length, 'paso', 'pasos') : 'opcional · se marcan en la app') + '</small></label>' +
    (PN.pasos.length ? '<ol class="cp-tps">' + PN.pasos.map(function (x, i) { return '<li><span class="cp-tps-n">' + (i + 1) + '</span><span class="cp-tps-t">' + esc(x) + '</span><span class="cp-tps-a"><button type="button" class="cp-ibx cp-sm" data-a="pgpasomv" data-v="' + i + '" data-d="-1"' + (i ? '' : ' disabled') + ' aria-label="Subir paso">' + ic('chev', 13).replace('<svg ', '<svg style="transform:rotate(-90deg)" ') + '</button><button type="button" class="cp-ibx cp-sm" data-a="pgpasorm" data-v="' + i + '" aria-label="Quitar paso">' + ic('x', 13) + '</button></span></li>'; }).join('') + '</ol>' : '') +
    '<div class="cp-tps-add"><input id="cpPgPaso" class="cp-inp" data-pg="paso" value="' + esc(PN.paso) + '" placeholder="Ej.: Cerrar la válvula de entrada" maxlength="300" autocomplete="off"><button type="button" class="cp-btn cp-out cp-sm" data-a="pgpasoadd">' + ic('plus', 14) + 'Agregar paso</button></div></div></div>';
}
A.pgpasoadd = function () { var t = String(PN.paso || '').trim(); if (!t) { var el = $('#cpPgPaso'); if (el) el.focus(); return; } PN.pasos.push(t); PN.paso = ''; panel(); var e2 = $('#cpPgPaso'); if (e2) { e2.value = ''; e2.focus(); } };
A.pgpasorm = function (d) { PN.pasos.splice(+d.v, 1); panel(); };
A.pgpasomv = function (d) { var i = +d.v, j = i + (+d.d); if (j < 0 || j >= PN.pasos.length) return; var x = PN.pasos[i]; PN.pasos[i] = PN.pasos[j]; PN.pasos[j] = x; panel(); };
PANELS.tar = function () {
  if (PN.ejv && !PN.cargando) return ejPanel();
  if (PN.cargando) return { t: PN.id ? 'Tarea recurrente' : 'Nueva tarea recurrente', s: 'Planificación · tareas', w: 'w', b: '<div class="cp-sk" style="height:40px"></div><div class="cp-sk" style="height:300px;margin-top:12px"></div>' };
  var e = PN.err, base = PN.eq ? pgAct(PN.eq) : null;
  var cats = PG.categorias.map(function (c) { return { id: c.ID, n: c.NOMBRE }; });
  if (/^nuevo:/.test(String(PN.cat))) cats.push({ id: PN.cat, n: String(PN.cat).slice(6), sub: 'Nueva · se crea al guardar' });
  var acts = PG.activos.filter(function (a) { return !a.PADRE_ID && (!U.planta || +a.PLANTA_ID === +U.planta); }).map(function (a) { return { id: a.ID, n: a.CODIGO + ' · ' + a.NOMBRE, sub: [a.AREA, a.TIPO].filter(Boolean).join(' · '), txt: a.AREA + ' ' + a.TIPO, img: a.IMG || '', ini: String(a.CODIGO || '?').replace(/^ACT-/, '').slice(0, 2) }; });
  var b = (PN.id && PN.fila ? pgFacts(PN.fila) : '') +
    '<div class="cp-fld"><label for="cpPgN">Nombre <small>obligatorio</small></label><input id="cpPgN" class="cp-inp' + (e && !PN.n.trim() ? ' cp-err' : '') + '" data-pg="n" value="' + esc(PN.n) + '" placeholder="Ej.: Revisión de duchas de emergencia" maxlength="400" autocomplete="off"' + (PN.id ? '' : ' data-autofocus="1"') + '>' + (e && !PN.n.trim() ? mc('', 'La tarea necesita un nombre.') : '') + '</div>' +
    '<div class="cp-grid2c"><div class="cp-fld"><label>Categoría</label>' + combo('cpPgCat', cats, PN.cat, { etiqueta: 'Categoría', ph: 'Sin categoría · escribe para crear una', crear: true, data: ' data-pg="cat"' }) + '</div>' +
    '<div class="cp-fld"><label>Dónde</label>' + combo('cpPgEq', acts, PN.eq, { etiqueta: 'Dónde', ph: 'Elige el activo', err: e && !PN.eq, data: ' data-pg="eq"' }) + (e && !PN.eq ? mc('', 'Elige dónde se hace.') : '') + '</div></div>' +
    (base ? '<div class="cp-fld"><label>Objeto mantenible <small>sobre qué se trabaja</small></label>' + combo('cpPgObj', pgObjOpts(base), PN.o || 'a:' + base.ID, { etiqueta: 'Objeto mantenible', data: ' data-pg="o"' }) + '</div>' : '') +
    tarQueHacerHTML(base) +
    pgChoqGuardados() + pgFreqHTML(PN.f, e) + pgRespDur(PN.as, PN.dur, e) + choquesHTML(PN.choq, 'Si es intencional, guarda igual; si no, cambia la hora, la frecuencia, el objeto mantenible o quién la ejecuta.') + (PN.err2 ? mc('', esc(PN.err2)) : '');
  return { t: PN.id ? esc(PN.n || 'Tarea') : 'Nueva tarea recurrente', s: PN.id ? (PN.fila ? esc(PN.fila.CODIGO) + ' · ' : '') + 'programación' : 'Planificación · tareas', w: 'w', b: b,
    f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-pri' + (PN.busy ? ' cp-load' : '') + '" data-a="pgtarok">' + ic(PN.choq && PN.choq.length ? 'alert' : 'check', 16) + (PN.choq && PN.choq.length ? 'Guardar igual' : (PN.id ? 'Guardar cambios' : 'Crear tarea')) + '</button></span>' };
};

/* ---- campos y acciones ---- */
function pgCampo(k, v, escribiendo) {
  var m;
  if (PN && PN.pg) { PN.choq = null; PN.choqOk = false; }
  if ((m = /^chqh:(.+)$/.exec(k))) { if (PN && PN.otra && PN.otra[m[1]]) PN.otra[m[1]].hora = v; return; }
  if ((m = /^addeq:(\d+)$/.exec(k))) { if (PN && PN.sel && PN.sel[m[1]]) PN.sel[m[1]].o = v; return; }
  if ((m = /^plaeq:(\d+)$/.exec(k))) { cambiarObjPlan(m[1], v); return; }
  if (!PN || !PN.pg) return;
  if ((m = /^f\.(\w+)$/.exec(k))) { PN.f[m[1]] = m[1] === 'hora' ? v : m[1] === 'sh' ? v : +v || 0; panel(); return; }
  if ((m = /^o:(\d+)$/.exec(k))) { if (PN.eqs[+m[1]]) PN.eqs[+m[1]].o = v; return; }
  if (k === 'eq') { PN.eq = v; PN.o = v ? 'a:' + v : ''; panel(); return; }
  if ((m = /^pva\.(\w+)$/.exec(k))) { PN.pva = PN.pva || { n: '', t: 'ok', s: 0, min: '', max: '', crit: false }; if (m[1] === 's' && /^nuevo:/.test(String(v))) { var pvv = PV[PN.pau], nom = String(v).slice(6).trim(); if (pvv && nom) { var ex = -1; pvv.secs.forEach(function (z, i) { if (nrm(z.n) === nrm(nom)) ex = i; }); if (ex < 0) { pvv.secs.push({ codigo: '', n: nom, items: [] }); ex = pvv.secs.length - 1; } PN.pva.s = ex; PN.pvdirty = true; } panel(); return; }
  PN.pva[m[1]] = m[1] === 's' ? +v || 0 : v; if (m[1] === 't') panel(); return; }
  if (k === 'pau') { if (PN.pved && PN.pvdirty && !confirm('Hay cambios sin publicar en la pauta. ¿Descartarlos?')) { panel(); return; } PN.pau = v; PN.pved = false; PN.pvdirty = false; PN.pva = null; panel(); return; }
  if (k === 'asadd') { if (+v && PN.as.ids.indexOf(+v) < 0) PN.as.ids.push(+v); panel(); return; }
  if (k === 'asone') { PN.as.ids = +v ? [+v] : []; panel(); return; }
  PN[k] = v;
  if (k === 'aq') { panel(); return; }
  if (k === 'cat' && /^nuevo:/.test(String(v))) { panel(); return; }
  if (k === 'proc') { panel(); return; }
  if (!escribiendo && (k === 'pau' || k === 'cat')) return;
  if (PN.err && k === 'n' && String(v).trim()) { PN.err = false; }
}
function pgFreqDatos(f) { return { modo: f.modo, dias: f.dias, diaMes: +f.diaMes || 1, hora: f.hora, sh: +f.sh || 0, pro: f.modo === 'sh' ? 0 : f.pro }; }
function pgFreqMala(f) { return f.modo === 'w' ? !f.dias.length : f.modo === 'sh' ? !f.sh : !(+f.diaMes >= 1); }
/* Lo ya guardado: si sus fechas chocan, un aviso con «Resolver choques» (mueve solo las que chocan). */
function pgChoqGuardados() {
  if (!PN.id) return '';
  var tipo = PN.t === 'ins' ? 'INS' : 'TAR', k = tipo + PN.id;
  if (PG_CHQ[k] === undefined) { PG_CHQ[k] = null; api('Choques', { tipo: tipo, refId: PN.id }).then(function (r) { PG_CHQ[k] = r.choques || []; if (PN && PN.pg) panel(); }).catch(function () { PG_CHQ[k] = []; }); }
  var l = PG_CHQ[k]; if (!l || !l.length) return '';
  return '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span><b>' + pl(l.length, 'choque de horario', 'choques de horario') + '</b> con otro trabajo sobre el mismo activo, subactivo o componente, o con las mismas personas, grupo o empresa.<span class="cp-bnr-a"><button type="button" class="cp-btn cp-out cp-xs" data-a="choqabrir" data-t="' + tipo + '" data-r="' + PN.id + '" data-n="' + esc(PN.n) + '">' + ic('clock', 13) + 'Resolver choques</button></span></span></div>' + quienesChocan(l);
}
var PG_CHQ = {};
/* true = hay que esperar (se está revisando o se muestran choques); false = se puede guardar. */
function pgChoquesAntes(tipo, objetos, dur) {
  /* «Guardar igual»: los choques ya están a la vista y no se cambió nada (cualquier cambio borra PN.choq). */
  if (PN.choqOk || (PN.choq && PN.choq.length)) return false;
  var f = PN.f, st = PN;
  PN.busy = true; PN.err2 = ''; panel();
  api('ChoquesCandidato', { datos: JSON.stringify({ tipo: tipo, ref: PN.id, objetos: objetos, fechas: pgFechasCand(f), programacion: f.modo === 'sh' ? +f.sh : 0, duracion: dur, recursos: pgRecursos(PN.as) }) }).then(function (r) {
    if (PN !== st) return;
    PN.busy = false; PN.choq = r.choques || [];
    if (!PN.choq.length) { PN.choqOk = true; A[tipo === 'INS' ? 'pginsok' : 'pgtarok'](); return; }
    panel(); var b = $('#cpLayer .cp-pnl-b'); if (b) b.scrollTop = b.scrollHeight;
  }).catch(function () { if (PN !== st) return; PN.busy = false; PN.choqOk = true; A[tipo === 'INS' ? 'pginsok' : 'pgtarok'](); });
  return true;
}
A.choqmov = function (d) { choqMover(d.k, d.v.replace(' ', 'T')); };
A.choqotra = function (d) { var st = PN, c = (st.lista || []).filter(function (x) { return x.TIPO + x.OCURRENCIA === d.k; })[0]; st.otra[d.k] = st.otra[d.k] ? null : { fecha: dIso(c.FECHA), hora: hIso(c.FECHA) || '08:00' }; panel(); };
A.choqok = function (d) { var o = PN.otra[d.k]; if (!o || !o.fecha) { toastError('Elige la nueva fecha.'); return; } choqMover(d.k, o.fecha + 'T' + (o.hora || '08:00')); };
/* 413 · CA-6 · «Resolver choques»: cada ocurrencia que choca se mueve sola (a una hora libre sugerida o a
   una fecha y hora elegidas); las de los demás activos siguen a su hora. */
function abrirChoques(tipo, ref, titulo) {
  openPanel({ t: 'choq', tipo: tipo, ref: ref, titulo: titulo || '', lista: null, huecos: {}, otra: {}, busy: '', fecha: function (b, v) { var k = b.slice(2); if (PN.otra[k]) PN.otra[k].fecha = v; } });
  choqCargar();
}
function choqCargar() {
  var st = PN; if (!st || st.t !== 'choq') return;
  api('Choques', { tipo: st.tipo, refId: st.ref }).then(function (r) {
    if (PN !== st) return;
    st.lista = r.choques || []; panel();
    st.lista.filter(function (c) { return +c.MOVIBLE; }).slice(0, 25).forEach(function (c) {
      var k = c.TIPO + c.OCURRENCIA; if (st.huecos[k]) return; st.huecos[k] = 'cargando';
      api('Huecos', { tipo: c.TIPO, ocurrencia: c.OCURRENCIA }).then(function (h) { st.huecos[k] = h.huecos || []; if (PN === st) panel(); }).catch(function () { st.huecos[k] = []; });
    });
  }).catch(function (e) { closePanel(); toastError(e); });
}
PANELS.choq = function () {
  var st = PN, l = st.lista;
  var t = 'Resolver choques de horario', s = (st.titulo ? esc(st.titulo) + ' · ' : '') + 'solo se mueve lo que choca';
  if (!l) return { t: t, s: s, w: 'w', b: '<div class="cp-sk" style="height:60px"></div><div class="cp-sk" style="height:60px;margin-top:10px"></div>' };
  if (!l.length) return { t: t, s: s, w: 'w', b: '<div class="cp-bnr cp-ok">' + ic('check', 18) + '<span><b>Sin choques.</b> Ni los activos ni quienes los ejecutan tienen otro trabajo a la misma hora en los próximos 90 días.</span></div>', f: '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button></span>' };
  var vistos = {}, filas = l.filter(function (c) { var k = c.TIPO + c.OCURRENCIA; if (vistos[k]) { vistos[k].push(c); return false; } vistos[k] = [c]; return true; });
  var b = mc('i', 'Mientras dura un trabajo el equipo está parado y quienes lo ejecutan están ocupados: no se les asigna otra inspección, tarea ni OT. Mueve <b>solo</b> la fecha que choca; las de los otros activos siguen a su hora.', 'help') +
    '<div class="cp-chql">' + filas.map(function (c) {
      var k = c.TIPO + c.OCURRENCIA, con = vistos[k], hs = st.huecos[k], ot = st.otra[k];
      var acc = !+c.MOVIBLE ? '<small class="cp-mut">' + (c.OT_ID ? 'Ya tiene OT en curso: cámbiala desde su ficha.' : 'Ya está en ejecución: no se mueve.') + '</small>'
        : (hs === 'cargando' || !hs ? '<span class="cp-sk" style="height:30px;width:220px;display:inline-block"></span>'
          : (hs.length ? hs.map(function (h) { return '<button type="button" class="cp-btn cp-sec cp-xs" data-a="choqmov" data-k="' + k + '" data-v="' + esc(String(h.INICIO).slice(0, 16)) + '"' + (st.busy === k ? ' disabled' : '') + '>' + ic('clock', 13) + 'Mover a ' + fD(dIso(h.INICIO)) + ' ' + hIso(h.INICIO) + '</button>'; }).join('') : '<small class="cp-mut">Sin horas libres en 3 días: elige otra fecha.</small>')) +
          '<button type="button" class="cp-btn cp-plain cp-xs" data-a="choqotra" data-k="' + k + '">Otra fecha…</button>' +
          (ot ? '<div class="cp-chq-otra">' + fecha('q:' + k, ot.fecha, { etiqueta: 'Nueva fecha' }) + combo('cpChqH' + c.OCURRENCIA, HORAS, ot.hora, { etiqueta: 'Hora', data: ' data-pg="chqh:' + k + '"' }) + '<button type="button" class="cp-btn cp-pri cp-xs" data-a="choqok" data-k="' + k + '">Mover</button></div>' : '');
      var obj = con.filter(function (x) { return x.CLASE !== 'RECURSO'; })[0];
      return '<div class="cp-chq"><div class="cp-chq-h"><b>' + fD(dIso(c.FECHA)) + ' ' + hIso(c.FECHA) + '</b><span>' + esc(obj ? obj.OBJETO : 'Mismas personas o equipo') + '</span><small>' + (TIPN[c.TIPO] || '') + ' · ' + fH(c.DURACION) + '</small></div>' +
        '<ul class="cp-olst">' + con.map(function (x) { return '<li>' + (x.CLASE === 'RECURSO' ? '<span class="cp-tg">Ocupado</span> <b>' + esc(x.OBJETO) + '</b> ya está en ' : 'Choca con ') + (TIPN[x.CON_TIPO] || '').toLowerCase() + ' <b>' + esc(x.CON_CODIGO) + '</b> · ' + esc(x.CON_NOMBRE) + '<small>' + hIso(x.CON_INICIO) + '–' + hIso(x.CON_FIN) + '</small>' + (x.CLASE === 'RECURSO' ? ' ' + cargaBtn(x.CLAVE, String(x.OBJETO).replace(/\s*\(grupo.*$/, ''), x.CON_INICIO) : '') + '</li>'; }).join('') + '</ul>' +
        '<div class="cp-chq-a">' + acc + '</div></div>';
    }).join('') + '</div>';
  return { t: t, s: s, w: 'w', b: b, f: '<span class="cp-msg cp-i">' + ic('help', 13) + '<span>' + pl(filas.length, 'fecha choca', 'fechas chocan') + '. Cada movimiento queda en el historial con su motivo.</span></span><span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Listo</button></span>' };
};
function choqMover(k, fechaHora) {
  var st = PN, c = (st.lista || []).filter(function (x) { return x.TIPO + x.OCURRENCIA === k; })[0]; if (!c) return;
  st.busy = k; panel();
  api('ReprogramarAgenda', { tipo: c.TIPO, ocurrencia: +c.OCURRENCIA, fecha: fechaHora, motivo: 'Choque de horario con ' + c.CON_CODIGO }).then(function () {
    if (PN !== st) return; st.busy = ''; st.huecos = {}; st.otra = {}; toast(c.OBJETO + ' movido al ' + fD(fechaHora.slice(0, 10)) + ' ' + fechaHora.slice(11, 16) + '. Lo demás sigue igual.');
    delete CHQ[st.ref]; choqCargar(); if (st.tipo === 'INS') insCargar(); if (st.tipo === 'TAR') tarCargar();
  }).catch(function (e) { if (PN !== st) return; st.busy = ''; panel(); toastError(e); });
}
A.choqabrir = function (d) { abrirChoques(d.t, +d.r, d.n); };
A.pgfq = function (d) { PN.f.modo = d.v; PN.choq = null; PN.choqOk = false; panel(); };
A.pgas = function (d) { if (PN.as.modo !== d.v) PN.as = { modo: d.v, ids: [] }; panel(); };
A.pgasrm = function (d) { PN.as.ids = PN.as.ids.filter(function (x) { return +x !== +d.v; }); panel(); };
A.pgday = function (d) { PN.choq = null; PN.choqOk = false; var f = PN.f, x = +d.v, i = f.dias.indexOf(x); if (i >= 0) f.dias.splice(i, 1); else f.dias.push(x); f.dias.sort(); panel(); };
A.pgpl = function (d) { if (+PN.pl !== +d.v) { PN.pl = +d.v; PN.eqs = []; } panel(); };
A.pgeq = function (d, t, ev) {
  if (ev) ev.stopPropagation(); PN.choq = null; PN.choqOk = false;
  var id = +d.v, i = -1; PN.eqs.forEach(function (x, k) { if (+x.a === id) i = k; });
  if (i >= 0) PN.eqs.splice(i, 1); else PN.eqs.push({ a: id, o: 'a:' + id });
  panel();
};
A.pgarea = function (d) { PN.choq = null; PN.choqOk = false;
  var ids = PG.activos.filter(function (a) { return !a.PADRE_ID && a.AREA === d.v && (!PN.pl || +a.PLANTA_ID === +PN.pl); }).map(function (a) { return +a.ID; });
  var todos = ids.every(function (id) { return PN.eqs.some(function (x) { return +x.a === id; }); });
  if (todos) PN.eqs = PN.eqs.filter(function (x) { return ids.indexOf(+x.a) < 0; });
  else ids.forEach(function (id) { if (!PN.eqs.some(function (x) { return +x.a === id; })) PN.eqs.push({ a: id, o: 'a:' + id }); });
  panel();
};
A.pgmv = function (d) { PN.choq = null; PN.choqOk = false; var l = PN.eqs, i = +d.v, j = i + (+d.d); if (j < 0 || j >= l.length) return; var x = l[i]; l[i] = l[j]; l[j] = x; panel(); };
/* 413 · Choques de horario: antes de guardar se revisan las fechas que tendría (90 días) contra los planes,
   inspecciones y tareas del mismo objeto mantenible. Hay choque → se listan y el botón pasa a «Guardar igual». */
var TIPN = { PLAN: 'Plan', INS: 'Inspección', TAR: 'Tarea' };
function pgFechasCand(f) { if (f.modo === 'sh') return []; var lim = addD(TODAY, 90); return pgProximas(f, 200).filter(function (d) { return d <= lim; }).map(function (d) { return d + 'T' + (f.hora || '08:00'); }); }
/* CA-7 · Quién la ejecutaría, como claves de recurso: personas U:, grupo G:, empresa E:. Disponible = nadie. */
function pgRecursos(as) { return !as || as.modo === 'D' ? [] : as.ids.map(function (id) { return ({ P: 'U:', G: 'G:', E: 'E:' })[as.modo] + id; }); }
function choquesHTML(l, verbo) {
  if (!l || !l.length) return '';
  var otros = {}; l.forEach(function (c) { otros[c.CON_TIPO + c.CON_REF] = 1; });
  var nObj = l.filter(function (c) { return c.CLASE !== 'RECURSO'; }).length, nRec = l.length - nObj;
  return '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span><b>' + pl(l.length, 'choque de horario', 'choques de horario') + '</b> con ' + pl(Object.keys(otros).length, 'otra programación', 'otras programaciones') + ': ' + [nObj ? pl(nObj, 'sobre el mismo activo, subactivo o componente', 'sobre el mismo activo, subactivo o componente') : '', nRec ? pl(nRec, 'con la misma persona, grupo o empresa', 'con las mismas personas, grupos o empresas') : ''].filter(Boolean).join(' y ') + '.' +
    '<ul class="cp-olst" style="margin-top:6px">' + l.slice(0, 5).map(function (c) {
      return '<li><b>' + fD(dIso(c.FECHA)) + ' ' + hIso(c.FECHA) + '</b> · ' + (c.CLASE === 'RECURSO' ? '<span class="cp-tg">Ocupado</span> ' : '') + esc(c.OBJETO) + '<small>' + (TIPN[c.CON_TIPO] || '') + ' ' + esc(c.CON_CODIGO) + ' · ' + esc(c.CON_NOMBRE) + ' · ' + hIso(c.CON_INICIO) + '–' + hIso(c.CON_FIN) + '</small></li>';
    }).join('') + (l.length > 5 ? '<li><small>y ' + (l.length - 5) + ' más</small></li>' : '') + '</ul>' + quienesChocan(l) + (verbo ? '<small style="display:block;margin-top:6px">' + verbo + '</small>' : '') + '</span></div>';
}
function pgGuardar(metodo, datos, recargar, msg) {
  var habia = PN.choq && PN.choq.length, tipo = PN.t === 'ins' ? 'INS' : 'TAR', nom = PN.n;
  PN.busy = true; PN.err2 = ''; panel();
  api(metodo, { datos: JSON.stringify(datos) }).then(function (r) { delete PG_CHQ[tipo + r.id]; closePanel(); recargar(); if (habia && r.id) { abrirChoques(tipo, r.id, nom); toast(msg + ' Mueve aquí solo las fechas que chocan.'); } else toast(msg); })
    .catch(function (e) { if (PN) { PN.busy = false; PN.err2 = e.message; panel(); } });
}
A.pginsok = function () {
  if (!PN.n.trim() || !PN.pau || !PN.eqs.length || pgFreqMala(PN.f) || (PN.as.modo !== 'D' && !PN.as.ids.length)) { PN.err = true; panel(); return; }
  var dur = parseFloat(String(PN.dur).replace(',', '.'));
  if (pgChoquesAntes('INS', PN.eqs.map(function (x) { return pgObjDe(x.o) || { activo: x.a, componente: 0 }; }), Math.round(dur * 60))) return;
  pgGuardar('GuardarInspeccion', { id: PN.id, nombre: PN.n.trim(), pauta: +PN.pau, asignacion: PN.as, duracion: dur > 0 ? Math.round(dur * 60) : 0,
    activos: PN.eqs.map(function (x) { return pgObjDe(x.o) || { activo: x.a, componente: 0 }; }), frecuencia: pgFreqDatos(PN.f) }, insCargar,
    PN.id ? 'Inspección actualizada. Las fechas pendientes se reprogramaron.' : 'Inspección creada. Sus fechas ya aparecen en Operación.');
};
A.pgtarok = function () {
  if (!PN.n.trim() || !PN.eq || pgFreqMala(PN.f) || (PN.as.modo !== 'D' && !PN.as.ids.length)) { PN.err = true; panel(); return; }
  var o = pgObjDe(PN.o) || { activo: +PN.eq, componente: 0 }, dur = parseFloat(String(PN.dur).replace(',', '.'));
  if (pgChoquesAntes('TAR', [o], Math.round(dur * 60))) return;
  if (String(PN.paso || '').trim()) { PN.pasos.push(String(PN.paso).trim()); PN.paso = ''; }
  pgGuardar('GuardarTarea', { id: PN.id, nombre: PN.n.trim(), categoria: /^nuevo:/.test(String(PN.cat)) ? String(PN.cat) : +PN.cat || 0, activo: o.activo, componente: o.componente, descripcion: PN.desc || '', procedimiento: +PN.proc || 0, pasos: PN.pasos,
    asignacion: PN.as, duracion: dur > 0 ? Math.round(dur * 60) : 0, frecuencia: pgFreqDatos(PN.f) }, tarCargar,
    PN.id ? 'Tarea actualizada. Las fechas pendientes se reprogramaron.' : 'Tarea creada. Sus fechas ya aparecen en Operación.');
};
TABR.inspecciones = {
  html: insHTML, entrar: function () { if (!INS.filas) insCargar(); },
  planta: function () { INS.filas = null; insCargar(); },
  escribir: function (t) { if (t.id === 'cpInsQ') { INS.q = t.value; render(); } },
  A: {
    insabrir: function (d) { abrirIns(+d.id); },
    insnueva: function () { abrirIns(0); }
  }
};
TABR.tareas = {
  html: tarHTML, entrar: function () { if (!TAR.filas) tarCargar(); },
  planta: function () { TAR.filas = null; tarCargar(); },
  escribir: function (t) { if (t.id === 'cpTarQ') { TAR.q = t.value; render(); } },
  A: {
    tarabrir: function (d) { abrirTar(+d.id); },
    tarnueva: function () { abrirTar(0); }
  }
};
TABR.cobertura = {
  html: covHTML, entrar: function () { setTimeout(function () { cobCargar(); }, 0); },
  planta: function () { CB.lista = null; CB.sel = {}; cobCargar(); },
  escribir: function (t) { if (t.id === 'cpCvq') { CB.q = t.value; CB.lim = COB_PAG; render(); } },
  combo: function (span, v) { if (span.hasAttribute('data-cvf')) { CB.tipo = v; CB.lim = COB_PAG; render(); } },
  A: {
    covf: function (d) { CB.f = d.v; CB.lim = COB_PAG; render(); },
    covmas: function () { CB.lim += COB_PAG; render(); },
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
  /* La Biblioteca del Centro pasó a Recursos (Biblioteca.aspx): los enlaces viejos #tab=biblioteca llevan allá.
     Ahí el calendario compartido no tiene responsables: quién ejecuta se define en el plan, la inspección o la tarea. */
  entrar: function (x) { location.replace(CFG.base_ + 'View/Mantenimiento/Biblioteca/Biblioteca.aspx#' + ((x.lib || LB.v) === 'cal' ? 'calendarios' : 'procedimientos')); },
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
/* 391 · Área desglosada: cada área seguida de sus hijas, con su tipo y sangría
   (Panadería › Línea 1). La búsqueda encuentra también por el área madre. */
function calAreas(alc) {
  return [{ id: '', n: 'Cualquier área' }].concat((alc.areas || []).map(function (a) {
    return { id: a.id, n: a.n, sub: a.sub ? 'En ' + a.sub : '', txt: a.ruta, tag: { k: a.nivel ? 's' : 'a', t: a.tipo || 'Área' }, nivel: Math.min(+a.nivel || 0, 3) };
  }));
}
function calAreaRuta(alc, id) { var a = (alc.areas || []).filter(function (x) { return String(x.id) === String(id); })[0]; return a ? a.ruta || a.n : ''; }
/* Personas del calendario ({id, n, sub, foto}): la foto o las iniciales. */
function calAvatar(p) { return p.foto ? '<img class="cp-av cp-avi cp-lg" src="' + esc(p.foto) + '" alt="" loading="lazy">' : avatar(p.n).replace('class="cp-av"', 'class="cp-av cp-lg"'); }
function calPersFila(p, extra) { return '<div class="cp-rp">' + calAvatar(p) + '<span class="cp-s"><b>' + esc(p.n) + (extra || '') + '</b><small>' + esc(p.sub || 'Sin perfil') + '</small></span></div>'; }
/* Revisión · Asignación: en lista, cada persona con su foto o sus iniciales;
   un grupo muestra sus integrantes vigentes. */
function calAsignacion(d, cat, alc) {
  if (d.modo === 'persona') {
    var sel = cat.personas.filter(function (p) { return d.personas[p.id]; });
    return sel.length ? '<div class="cp-avl">' + sel.map(function (p) { return calPersFila(p); }).join('') + '</div>' : '—';
  }
  if (d.modo === 'grupo') {
    var g = (alc.grupos || []).filter(function (z) { return String(z.id) === String(d.grupo); })[0];
    if (!g) return '—';
    var ms = integrantes(g.id).map(function (m) {
      var p = cat.personas.filter(function (x) { return String(x.id) === String(m.USUARIO_ID); })[0];
      return p ? calPersFila(p, m.LIDER ? ' <span class="cp-tg cp-c">Líder</span>' : '') : '';
    }).join('');
    return '<div class="cp-avl"><b>' + esc(g.n) + '</b>' + (ms || '<small class="cp-mut">El grupo no tiene integrantes vigentes.</small>') + '</div>';
  }
  return 'Sin asignar';
}
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
      '<div class="cp-grid2c"><div class="cp-fld"><label>Área</label>' + calCombo('area', calAreas(alc), d.area, 'Área', 'Cualquier área') + '</div><div class="cp-fld"><label>Activo</label>' + calCombo('activo', [{ id: '', n: 'Cualquier activo' }].concat(alc.activos), d.activo, 'Activo', 'Cualquier activo') + '</div></div>' +
      (PN.alc ? '' : '<div class="cp-sk" style="height:20px"></div>') + (errDe(2).length ? mc('', esc(errDe(2)[0][1])) : '');
  }
  if (paso === 3) {
    b = '<div class="cp-fld"><span class="cp-lb">Quién ejecuta lo que genere</span>' + calSeg(d, 'modo', CAL_ASIG) + '</div>' +
      (d.modo === 'persona' ? (function () {
        var q = nrm(d.pq || ''), nSel = Object.keys(d.personas).length;
        var lista = cat.personas.filter(function (p) { return !q || nrm(p.n + ' ' + (p.sub || '')).indexOf(q) >= 0; }).sort(function (x, y) { return x.n.localeCompare(y.n); });
        return '<div class="cp-fld"><span class="cp-lb">Personas <small>' + (nSel ? pl(nSel, 'elegida', 'elegidas') : 'elige una o varias') + '</small></span>' +
          '<label class="cp-srch2" style="height:36px">' + ic('search', 14) + '<input data-pp="pq" value="' + esc(d.pq || '') + '" placeholder="Buscar por nombre o cargo" aria-label="Buscar personas" autocomplete="off"></label>' +
          '<div class="cp-pers">' + (lista.map(function (p) { return '<label class="cp-sw cp-swp"><input type="checkbox" data-a="calpers" data-v="' + p.id + '"' + (d.personas[p.id] ? ' checked' : '') + '><i></i>' + calAvatar(p) + '<span class="cp-s"><b>' + esc(p.n) + '</b><small>' + esc(p.sub || 'Sin perfil') + '</small></span></label>'; }).join('') || '<span style="font-size:12.5px;color:var(--muted)">Nadie coincide con «' + esc(d.pq) + '».</span>') + '</div>' + (e && errDe(3).length ? mc('', esc(errDe(3)[0][1])) : '') + '</div>';
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
      fila('Zona horaria', esc(nm(cat.zonas, d.zona) || '(sin definir)')) + fila('Alcance', esc([nm(CFG.plantas || [], d.planta) || 'Todas las plantas', calAreaRuta(alc, d.area), nm(alc.activos, d.activo)].filter(Boolean).join(' · '))) +
      fila('Asignación', calAsignacion(d, cat, alc)) +
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
/* =====================================================================
   MONITOREO · sala de control + programa por ubicación
   Responde de un vistazo: ¿qué área está en mantención hoy, con qué
   activos, y qué viene? Los datos salen de SEL_PLAN_MONITOREO: las
   ejecuciones reales y la proyección de borradores y de lo que está
   más allá del horizonte generado.
   ===================================================================== */
var MON = { filas: null, rango: '', cargando: false, areas: [] };
Object.assign(U, { md: TODAY, mc: {}, ch: {}, mf: '' });
var hmin = function (h) { var a = String(h || '08:00').split(':').map(Number); return (a[0] || 0) * 60 + (a[1] || 0); };
var addH = function (h, min) { var m = hmin(h) + Math.round(+min || 0); return pad(Math.floor(m / 60) % 24) + ':' + pad(m % 60); };
var weekMon = function (s) { return addD(s, -(wday(s) - 1)); };
var capF = function (s) { return String(s || '').replace(/^./, function (c) { return c.toUpperCase(); }); };
var fechaDe = function (v) { return dIso(v); };

function normMon(r, proj) {
  var d = dIso(r.FECHA), hora = hIso(r.FECHA) || '08:00';
  return { proj: !!proj, borrador: !!r.BORRADOR, d: d, hora: hora, dur: +r.DURACION || 0, parada: !!r.PARADA, plan: r.PLAN_ID, planCod: r.PLAN_CODIGO, planN: r.PLAN_NOMBRE,
    hito: r.HITO_ID, hitoN: r.HITO_NOMBRE, eq: r.ACTIVO_ID, eqCod: r.ACTIVO_CODIGO, eqN: r.ACTIVO_NOMBRE, pl: r.PLANTA_ID, plN: r.PLANTA || 'Sin planta', ar: r.AREA_ID || 0, arN: r.AREA || 'Sin área',
    comp: r.COMPONENTE || '', resp: r.RESPONSABLE || '', sit: r.SITUACION, estado: r.ESTADO_ID, ot: r.OT_ID || 0, otNum: r.OT_NUMERO, otEst: r.OT_ESTADO_ID, token: r.TOKEN, otUrl: r.OT_URL };
}
function monItems() {
  if (!MON.filas) return [];
  var ok = {}; (U.lista || []).filter(function (p) { return estado(p)[0] !== 'inactive' && planMatch(p) && !U.ch[p.PLAN_ID]; }).forEach(function (p) { ok[p.PLAN_ID] = 1; });
  return MON.filas.filter(function (x) { return ok[x.plan]; });
}
function sitM(x) {
  if (x.proj) return 'pj';
  if (x.estado === 4 || x.estado === 5 || x.sit === 'CERRADA') return 'cer';
  if (x.ot) return 'ot';
  return { VENCIDA: 'venc', ATRASADA: 'atr', DISPONIBLE: 'disp' }[x.sit] || 'fut';
}
function nowLive(x) {
  if (x.d !== TODAY || x.proj || sitM(x) === 'cer') return false;
  if (x.ot && x.otEst === 2) return true;
  var n = new Date(), m = n.getHours() * 60 + n.getMinutes(), s = hmin(x.hora);
  return m >= s && m < s + Math.max(30, x.dur);
}
function xState(x) {
  if (x.proj) return ['pj', x.borrador ? 'Proyección' : 'Proyección'];
  if (nowLive(x)) return ['live', 'En curso'];
  var s = sitM(x);
  if (s === 'venc') return ['venc', 'Vencida']; if (s === 'atr') return ['atr', 'Atrasada']; if (s === 'cer') return ['cer', 'Cerrada'];
  if (s === 'ot') return ['ot', (OTX[x.otEst] || OTX[1])[1]];
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
  var r = monRango(), key = [r[0], r[1], U.planta].join('|');
  if (!forzar && MON.rango === key && MON.filas) return Promise.resolve();
  MON.cargando = true;
  return api('Monitoreo', { planta: U.planta, desde: r[0], hasta: r[1] }).then(function (x) {
    MON.filas = x.reales.map(function (f) { return normMon(f, false); }).concat(x.proyeccion.map(function (f) { return normMon(f, true); }));
    MON.areas = x.areas; MON.rango = key; MON.cargando = false;
    if (U.tab === 'planes' && !U.plan && U.pv === 'cal') render();
  }).catch(function (e) { MON.cargando = false; toastError(e); });
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
  if (!MON.filas) { if (!MON.cargando) monCargar(); return '<div class="cp-card" style="padding:18px"><div class="cp-sk" style="height:34px;width:40%"></div><div class="cp-sk" style="height:120px;margin-top:12px"></div></div>'; }
  var items = monItems(), d = U.md, isT = d === TODAY;
  var all = (U.lista || []).filter(function (p) { return estado(p)[0] !== 'inactive'; });
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
        return '<li><button type="button" data-a="' + (top.proj ? 'mplan' : 'exopen') + '" data-p="' + top.plan + '" data-k="' + esc(top.token || '') + '"><span class="cp-at-a"><b>' + esc(top.eqN) + '</b><small>' + esc(top.eqCod) + (top.comp ? ' <span class="cp-cmp">› ' + esc(top.comp) + '</span>' : '') + '</small></span>' +
          '<span class="cp-at-w"><b>' + esc(top.hitoN) + (xs.length > 1 ? ' <em>+' + (xs.length - 1) + '</em>' : '') + '</b><small>' + top.hora + '–' + addH(top.hora, top.dur) + (top.parada ? ' · <span class="cp-pz">parada</span>' : '') + (top.resp ? ' · ' + esc(short(top.resp)) : '') + '</small></span>' +
          '<span class="cp-xst cp-s-' + s[0] + '">' + (s[0] === 'live' ? '<i class="cp-pulse"></i>' : '<i></i>') + s[1] + '</span></button></li>';
      }).join('') + '</ul>' + (rows.length > 4 ? '<button type="button" class="cp-at-more" data-a="mfoc" data-v="' + esc(g.k) + '">Ver ' + (rows.length - 4) + ' activos más en el programa</button>' : '') + '</article>';
  };
  var strp = strip.map(function (s) {
    var xs = perDay[s] || [], h = xs.reduce(function (t, x) { return t + x.dur; }, 0), bad = xs.some(attn);
    return '<button type="button" class="cp-sd' + (s === d ? ' cp-on' : '') + (s === TODAY ? ' cp-tdy' : '') + (wday(s) > 5 ? ' cp-we' : '') + (s < TODAY ? ' cp-past' : '') + '" data-a="mday" data-v="' + s + '" aria-pressed="' + (s === d) + '" aria-label="' + fDL(s) + ': ' + pl(xs.length, 'trabajo', 'trabajos') + '"><span class="cp-w">' + DIAC[wday(s)] + '</span><span class="cp-n">' + D(s).getDate() + '</span><span class="cp-b"><i style="height:' + (h ? Math.max(12, h / maxH * 100) : 0) + '%"' + (bad ? ' class="cp-r"' : '') + '></i></span><span class="cp-c">' + (xs.length || '') + '</span></button>';
  }).join('');
  var hidden = Object.keys(U.ch).length;
  monReloj();
  return '<section class="cp-mon" aria-label="Monitoreo de mantenimiento"><div class="cp-mon-top"><div class="cp-mon-t"><span class="cp-ey"><i class="cp-pulse"></i>Sala de control · mantenimiento</span><h2>' + (isT ? 'Hoy, ' : '') + fDL(d) + '</h2><p>' + (isT ? 'Son las <b id="cpMonClock">' + clock + '</b> · ' : capF(rel(d)) + ' · ') + esc(U.planta ? plantaN(U.planta) : 'Todas las plantas') + '</p></div>' +
    '<div class="cp-mon-ctl"><button type="button" class="cp-mbtn" data-a="mstep" data-v="-1" aria-label="Día anterior">' + chL(16) + '</button>' + (isT ? '' : '<button type="button" class="cp-mbtn cp-txt" data-a="mday" data-v="' + TODAY + '">Ir a hoy</button>') + '<button type="button" class="cp-mbtn" data-a="mstep" data-v="1" aria-label="Día siguiente">' + ic('chev', 16) + '</button>' +
    '<button type="button" class="cp-mbtn cp-txt" data-a="cplans" aria-haspopup="dialog">' + ic('calw', 15) + (hidden ? (all.length - hidden) + ' de ' + all.length + ' planes' : 'Todos los planes') + ic('chevd', 14) + '</button></div></div>' +
    '<div class="cp-mon-strip" role="group" aria-label="Elegir día">' + strp + '</div>' +
    '<div class="cp-mon-k">' + kpi(areas.length + '<small>/' + allAreas.length + '</small>', 'áreas con mantención', areas.some(function (a) { return a.mode === 'live'; }) ? 'cp-k-live' : '') + kpi(nEq, 'activos intervenidos') + kpi(nStop, 'con parada de activo', nStop ? 'cp-k-stop' : '') + kpi(fH(mins), 'horas de trabajo') + kpi(nAtt, 'requieren atención', nAtt ? 'cp-k-att' : '') + '</div>' +
    (areas.length ? '<div class="cp-mon-g">' + areas.map(tile).join('') + '</div>' : '<div class="cp-mon-e">' + ic('check', 26) + '<b>' + (isT ? 'Hoy' : capF(fDL(d))) + ' no hay mantención programada</b><span>Todas las áreas operan con normalidad. Elige otro día en la barra de arriba.</span></div>') +
    (quiet.length ? '<div class="cp-mon-q"><span>' + ic('check', 14) + 'Operando sin mantención</span>' + quiet.map(function (a) { return '<em>' + esc(a.n) + (!U.planta && (CFG.plantas || []).length > 1 ? ' <small>· ' + esc(a.pl) + '</small>' : '') + '</em>'; }).join('') + '</div>' : '') + '</section>' + progHTML(items);
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

POPS.cplans = function () {
  var l = (U.lista || []).filter(function (p) { return estado(p)[0] !== 'inactive'; }).sort(cmpPlanes);
  return '<div class="cp-ppt"><b>Planes a monitorear</b></div><div class="cp-srchres">' + l.map(function (p) {
    return '<label class="cp-mi2 cp-sh2" style="cursor:pointer"><input type="checkbox" class="cp-cbx" data-a="cpl" data-p="' + p.PLAN_ID + '"' + (U.ch[p.PLAN_ID] ? '' : ' checked') + '><span><b>' + esc(p.NOMBRE) + '</b><small>' + esc(p.CODIGO) + '</small></span></label>';
  }).join('') + '</div><div style="display:flex;justify-content:space-between;padding:6px"><button type="button" class="cp-btn cp-plain cp-xs" data-a="cpall">Mostrar todos</button><button type="button" class="cp-btn cp-plain cp-xs" data-a="popx">Cerrar</button></div>';
};


if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar); else iniciar();
})();




