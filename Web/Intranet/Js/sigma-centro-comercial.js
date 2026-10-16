/* =====================================================================
   SIGMA · Centro Comercial (15-10-2026)
   Resumen · Pipeline (lista y tablero) · Clientes, y la ficha del lead en el
   cajón lateral, donde también se crean la demo, la propuesta, el contrato y
   las reuniones. Nada de modales: la lista sigue visible detrás.

   Habla con WsComercial.asmx (cada método valida sesión y facultad).
   Usa el kit de Mantenimiento (MantKit: cajón, avisos, combo, calendario).
   Convenciones: clases cp-/cc- bajo .cp-root; todo <button> con type="button";
   «activo», nunca «equipo»; mensajes por facultad, nunca por rol.
   ===================================================================== */
function iniciarCentroComercial() {
'use strict';
var K = window.MantKit, CFG = K.CFG || {}, $ = K.$, esc = K.esc;
if (!K || !$('#cpRoot')) return;

function call(m, d) { return K.llamar(CFG.ws, m, d); }
var COB = null;   // cobros en drawers (sigma-cc-cobros.js); se engancha antes de K.bind

/* ------------------------------------------------------------ íconos propios */
var P = {
  dash: '<rect x="3.5" y="3.5" width="7" height="9" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="5" rx="1.5"/><rect x="13.5" y="11.5" width="7" height="9" rx="1.5"/><rect x="3.5" y="15.5" width="7" height="5" rx="1.5"/>',
  kanban: '<rect x="3.5" y="4" width="5" height="16" rx="1.5"/><rect x="10" y="4" width="5" height="10" rx="1.5"/><rect x="16.5" y="4" width="4" height="13" rx="1.5"/>',
  hand: '<path d="M11 14l2 2a2 2 0 0 0 3-3l-3.5-3.5"/><path d="M3 11l4-4 3 1 3-3 4 4 4 1"/><path d="M3 11l6 6 2-1"/><path d="M14 17l1 1a2 2 0 0 0 3-3"/>',
  person: '<circle cx="12" cy="8" r="3.6"/><path d="M5 20a7 7 0 0 1 14 0"/>',
  personadd: '<circle cx="10" cy="8" r="3.6"/><path d="M3 20a7 7 0 0 1 12.5-4.3"/><path d="M18 14v6M15 17h6"/>',
  rocket: '<path d="M14 4c3 0 6 3 6 6l-6 6-4-4z"/><path d="M10 12l-4 0-2 2 4 1M12 14v4l-2 2-1-4"/><circle cx="15.5" cy="8.5" r="1.4"/>',
  quote: '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4M10 12h5M10 15.5h5M10 8.5h2"/>',
  sign: '<path d="M4 20h16"/><path d="M6 16l9.5-9.5a2.1 2.1 0 0 1 3 3L9 19H6z"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>', ok: '<circle cx="12" cy="12" r="8.5"/><path d="M8.5 12.2l2.4 2.4 4.6-4.8"/>',
  timer: '<circle cx="12" cy="13" r="7.5"/><path d="M12 9v4l2.5 1.5M9.5 3h5"/>', clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  off: '<circle cx="10" cy="8" r="3.6"/><path d="M3 20a7 7 0 0 1 11-5.7M16 15l5 5M21 15l-5 5"/>',
  mailx: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3.5 6.5l8.5 6.5 8.5-6.5"/><circle cx="19" cy="6" r="3" fill="currentColor" stroke="none"/>',
  mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3.5 6.5l8.5 6.5 8.5-6.5"/>',
  phone: '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/>',
  users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.2A6.5 6.5 0 0 1 21.5 20"/>',
  note: '<path d="M5 4h14v11l-5 5H5z"/><path d="M14 20v-5h5"/>',
  web: '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.5 2.6 3.7 5.4 3.7 8.5S14.5 17.9 12 20.5C9.5 17.9 8.3 15.1 8.3 12S9.5 6.1 12 3.5z"/>',
  flag: '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>', eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
  send: '<path d="M22 2L11 13"/><path d="M22 2l-7 20-4-9-9-4z"/>', x: '<path d="M6 6l12 12M18 6L6 18"/>',
  plus: '<path d="M12 5v14M5 12h14"/>', arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>', chev: '<path d="M9 6l6 6-6 6"/>',
  chevd: '<path d="M6 9l6 6 6-6"/>', chevu: '<path d="M6 15l6-6 6 6"/>', back: '<path d="M15 6l-6 6 6 6"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3"/>',
  pdf: '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4"/>', badge: '<rect x="3.5" y="5" width="17" height="14" rx="2"/><circle cx="9" cy="11" r="2.2"/><path d="M5.8 16a3.4 3.4 0 0 1 6.4 0M14 10h4M14 13.5h3"/>',
  event: '<rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/>', more: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2M17 3l3 3"/>',
  block: '<circle cx="12" cy="12" r="8.5"/><path d="M6 6l12 12"/>', video: '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3"/>',
  pin: '<path d="M12 21s-6.5-6-6.5-11a6.5 6.5 0 0 1 13 0c0 5-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>', open: '<path d="M14 4h6v6M20 4l-9 9"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>',
  refresh: '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>', light: '<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.8.8 1 1.5 1 2.5h6c0-1 .2-1.7 1-2.5A6 6 0 0 0 12 3z"/>',
  wallet: '<path d="M4 7.5A1.5 1.5 0 0 1 5.5 6H18v3"/><path d="M4 7.5V18a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2H5.5A1.5 1.5 0 0 1 4 7.5z"/><circle cx="16" cy="14.5" r="1.2" fill="currentColor" stroke="none"/>',
  upload: '<path d="M12 15V4M7 9l5-5 5 5M4 15v5h16v-5"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>', list: '<path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"/>'
};
function ic(k, n) { n = n || 18; return '<svg class="cc-ic" style="width:' + n + 'px;height:' + n + 'px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (P[k] || '') + '</svg>'; }

/* ------------------------------------------------------------ catálogos fijos */
var ST = { NUEVO: ['NUEVO', 'bl'], CONTACTADO: ['CONTACTADO', 'cy'], CALIFICADO: ['CALIFICADO', 'cy'], DEMO: ['DEMO', 'pu'], PROPUESTA: ['PROPUESTA', 'pu'],
  NEGOCIACION: ['NEGOCIACIÓN', 'pu'], CONTRATO: ['CONTRATO', 'wa'], CONCRETADO: ['CONCRETADO', 'ok'], PERDIDO: ['PERDIDO', 'gr'] };
var CT = { BORRADOR: 'gr', ENVIADO: 'bl', VISUALIZADO: 'cy', FIRMADO: 'ok', ANULADO: 'da' };
var PT = { BORRADOR: 'gr', ENVIADA: 'bl', ACEPTADA: 'ok', RECHAZADA: 'da', REEMPLAZADA: 'gr' };
var TIPOS = [['LLAMADA', 'phone', 'Llamada'], ['EMAIL', 'mail', 'Email'], ['REUNION', 'users', 'Reunión'], ['NOTA', 'note', 'Nota']];
var MOTIVOS = ['Precio', 'Eligió otra solución', 'Sin presupuesto este año', 'No responde', 'No califica'];
var OBJECIONES = ['Precio', 'Plazo', 'Funcionalidad', 'Otra'];
var PROX = [{ id: 'LLAMADA', n: 'Llamada' }, { id: 'EMAIL', n: 'Email' }, { id: 'REUNION', n: 'Reunión' }, { id: 'DEMO', n: 'Demo' }, { id: 'PROPUESTA', n: 'Propuesta' }, { id: 'SEGUIMIENTO', n: 'Seguimiento' }];
var HORAS = (function () { var h = []; for (var i = 8; i <= 19; i++) ['00', '30'].forEach(function (m) { var t = (i < 10 ? '0' : '') + i + ':' + m; h.push({ id: t, n: t }); }); return h; })();
var LIMS = [['usuarios', 'Usuarios'], ['activos', 'Activos'], ['ot', 'OT'], ['programaciones', 'Programaciones'], ['checklists', 'Checklists'], ['repuestos', 'Repuestos'], ['bodegas', 'Bodegas'], ['plantas', 'Plantas']];

function chip(t, tono) { return '<span class="cc-chip cc-t-' + tono + '">' + esc(t) + '</span>'; }
function stChip(e) { var s = ST[e] || [e, 'gr']; return chip(s[0], s[1]); }
function icb(k, tono, n) { return '<span class="cc-icb cc-t-' + tono + (n === 36 ? ' cc-36' : '') + '">' + ic(k, n === 36 ? 18 : 22) + '</span>'; }
function av(nombre, chico) { return '<span class="cc-av' + (chico ? ' cc-22' : '') + (nombre ? '' : ' cc-no') + '">' + esc(nombre ? K.ini(nombre) : '?') + '</span>'; }
function nombreMod(id) { var m = (S.ini && S.ini.modulos || []).filter(function (x) { return x.id === id; })[0]; return m ? m.n : id; }
function mods(lista) { return String(lista || '').split(',').map(function (x) { return x.trim(); }).filter(Boolean); }
function uf(v, d) { return K.fN(v || 0, d == null ? 1 : d) + ' UF'; }
function clp(v) { return S.ini && S.ini.uf ? '$' + K.fN(Math.round((v || 0) * S.ini.uf)) : ''; }

/* ------------------------------------------------------------ fechas «AAAA-MM-DD HH:mm» */
function dt(s) { if (!s) return null; var m = /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/.exec(s); return m ? new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0)) : null; }
function ahora() { return dt(S.ahora) || new Date(); }
function hoyIso() { return S.hoy || CFG.hoy; }
function dias(a, b) { var x = dt(a), y = dt(b); if (!x || !y) return null; x.setHours(12, 0, 0, 0); y.setHours(12, 0, 0, 0); return Math.round((y - x) / 864e5); }
function hhmm(s) { return s && s.length >= 16 ? s.slice(11, 16) : ''; }
function dmy(s) { return s ? K.fDN(s).replace(/-/g, '/') : '—'; }
function dmyh(s) { return s ? dmy(s) + (hhmm(s) ? ' ' + hhmm(s) : '') : '—'; }
function dm(s) { var d = dt(s); return d ? (d.getDate() < 10 ? '0' : '') + d.getDate() + '/' + (d.getMonth() < 9 ? '0' : '') + (d.getMonth() + 1) : ''; }
function corto(s) { var d = dt(s); if (!d) return ''; return d.getDate() + ' ' + ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEPT', 'OCT', 'NOV', 'DIC'][d.getMonth()]; }
/* «hace 40 min», «hoy 10:00», «ayer 18:42», «hace 3 días», «23 oct» */
function cuando(s) {
  var d = dt(s); if (!d) return '';
  var n = dias(hoyIso(), s), h = hhmm(s);
  if (n === 0) { var min = Math.round((ahora() - d) / 6e4); if (min >= 0 && min < 60) return min < 2 ? 'recién' : 'hace ' + min + ' min'; if (min >= 60 && min < 180) return 'hace ' + Math.round(min / 60) + ' h'; return 'hoy' + (h && h !== '00:00' ? ' ' + h : ''); }
  if (n === -1) return 'ayer' + (h && h !== '00:00' ? ' ' + h : '');
  if (n === 1) return 'mañana' + (h && h !== '00:00' ? ' ' + h : '');
  if (n < -1 && n > -8) return 'hace ' + (-n) + ' días';
  return K.fD(s.slice(0, 10)).replace(/^\S+ /, '');
}

/* ------------------------------------------------------------ estado */
var VKEY = 'sigma-cc-vista-' + (CFG.usuario || '');
function leerVista() { try { return localStorage.getItem(VKEY) === 'tablero' ? 'tablero' : 'lista'; } catch (e) { return 'lista'; } }
function guardarVista(v) { try { localStorage.setItem(VKEY, v); } catch (e) { } }
var S = { tab: CFG.tab || 'resumen', filt: 'todos', view: leerVista(), q: '', ej: '', ini: null, leads: null, clientes: null, cfilt: 'activas', cq: '', sub: { clientes: 'concretados', suscripciones: null }, adm: {}, aq: '', hoy: CFG.hoy, ahora: null, sel: null, verMas: {} };

/* lo que dice cada lead de sí mismo (bandera, atención, etapa) */
function abierto(l) { return l.ESTADO !== 'CONCRETADO' && l.ESTADO !== 'PERDIDO'; }
function demoActiva(l) { return l.DEMO_ESTADO === 'ACTIVA' || l.DEMO_ESTADO === 'EXTENDIDA'; }
function bandera(l) {
  if (!abierto(l)) return null;
  if (l.ESTADO === 'DEMO' && l.DEMO_ESTADO) {
    var d = l.DEMO_DIAS;
    if (l.DEMO_ESTADO === 'VENCIDA' || d < 0) return ['Vencida', 'da'];
    if (d === 0) return ['Vence hoy', 'wa'];
    if (d === 1) return ['Vence mañana', 'wa'];
    if (d <= 3) return ['Vence en ' + d + ' días', 'wa'];
  }
  if (l.ESTADO === 'CONTRATO' && l.CONTRATO_ESTADO === 'ENVIADO') return ['Sin abrir', 'wa'];
  if (l.ESTADO === 'CONTRATO' && l.CONTRATO_ESTADO === 'VISUALIZADO') return ['Visualizado', 'cy'];
  if (l.REUNIONES_SIN_REGISTRAR > 0) return ['Reunión sin registrar', 'wa'];
  return null;
}
function atencion(l) {
  if (!abierto(l)) return false;
  var b = bandera(l);
  return (l.ESTADO === 'NUEVO' && !l.EJECUTIVO_ID) || !!(b && (b[1] === 'wa' || b[1] === 'da')) || !l.PROX_FECHA;
}
function enFiltro(l, f) {
  if (f === 'todos') return abierto(l);
  if (f === 'leads') return ['NUEVO', 'CONTACTADO', 'CALIFICADO'].indexOf(l.ESTADO) >= 0;
  if (f === 'demo') return l.ESTADO === 'DEMO';
  if (f === 'propuesta') return l.ESTADO === 'PROPUESTA' || l.ESTADO === 'NEGOCIACION';
  if (f === 'contrato') return l.ESTADO === 'CONTRATO';
  if (f === 'perdido') return l.ESTADO === 'PERDIDO';
  if (f === 'atencion') return atencion(l);
  return true;
}
function visibles() {
  var q = K.nrm(S.q.trim());
  return (S.leads || []).filter(function (l) {
    if (S.ej && String(l.EJECUTIVO_ID || '') !== String(S.ej) && !(S.ej === 'sin' && !l.EJECUTIVO_ID)) return false;
    return !q || K.nrm([l.EMPRESA, l.CONTACTO, l.CORREO, l.CODIGO].join(' ')).indexOf(q) >= 0;
  });
}

/* ------------------------------------------------------------ carga */
function cargar() {
  return call('Centro').then(function (r) { S.leads = r.leads || []; S.ahora = r.ahora; S.hoy = r.hoy; pintar(); });
}
function cargarClientes() {
  return call('Clientes').then(function (r) { S.clientes = r.clientes || []; if (S.tab === 'clientes') pintar(); });
}
function refrescarLead(f) {
  /* La ficha trae el lead actualizado: se reemplaza su fila sin recargar todo
     y se vuelve a pedir el pipeline en segundo plano (contadores, banderas). */
  cargar().catch(function () { });
  if (f && f.lead && f.lead.ESTADO === 'CONCRETADO') cargarClientes().catch(function () { });
}

/* ------------------------------------------------------------ cabecera y pestañas */
/* El botón principal del encabezado cambia con la pestaña (prompt V2 §1):
   Resumen y Pipeline → «Nuevo lead»; Suscripciones → «Emitir período». */
function pintarCabecera() {
  var ejs = [{ id: '', n: 'Todos' }, { id: 'sin', n: 'Sin asignar' }].concat((S.ini.ejecutivos || []).map(function (e) { return { id: String(e.ID), n: e.NOMBRE }; }));
  var leads = S.tab === 'resumen' || S.tab === 'pipeline';
  var extra = !leads && COB ? COB.boton() : null;
  $('#ccAcc').innerHTML = (leads ? '<span class="cc-hsel">Ejecutivo ' + K.combo('ccEjFiltro', ejs, S.ej, { ph: 'Todos', etiqueta: 'Filtrar por ejecutivo' }) + '</span>' : '') +
    (leads && S.ini.permisos.leads ? '<button type="button" class="cp-btn cp-pri" data-a="nuevo">' + ic('plus', 20) + 'Nuevo lead</button>' : '') + (extra || '');
}
function pintarTabs() {
  var t = [['resumen', 'dash', 'Resumen', 'Qué requiere atención hoy'], ['pipeline', 'kanban', 'Pipeline', 'Leads por estado y próxima acción'], ['clientes', 'hand', 'Clientes', 'Concretados y empresas de SIGMA']];
  if (subVistas('suscripciones').length) t.push(['suscripciones', 'quote', 'Suscripciones', 'Suscripciones, cobros, pagos y planes']);
  $('#ccTabs').innerHTML = t.map(function (x) {
    return '<button type="button" role="tab" aria-selected="' + (S.tab === x[0]) + '" data-a="tab" data-v="' + x[0] + '"><span class="cp-mt-i">' + ic(x[1], 20) + '</span>' +
      '<span class="cp-mt-t"><span class="cp-mt-n">' + x[2] + '</span><small>' + x[3] + '</small></span></button>';
  }).join('');
}
function pintar() {
  if (!S.ini) return;
  pintarTabs();
  var b = $('#ccBody');
  if (S.tab === 'clientes') { b.innerHTML = S.sub.clientes === 'empresas' ? (COB ? COB.vista('empresas') : vistaAdm('empresas')) : vistaClientes(); return; }
  if (S.tab === 'suscripciones') {
    var sv = S.sub.suscripciones || subVistas('suscripciones')[0][0];
    b.innerHTML = COB && COB.maneja(sv) ? COB.vista(sv) : vistaAdm(sv);
    return;
  }
  if (!S.leads) { b.innerHTML = '<div class="cc-cargando">Cargando…</div>'; return; }
  b.innerHTML = S.tab === 'pipeline' ? vistaPipeline() : vistaResumen();
}

/* ------------------------------------------------------------ RESUMEN */
function vistaResumen() {
  var L = visibles(), y = hoyIso().slice(0, 7);
  var cnt = function (f) { return L.filter(f).length; };
  var leads = cnt(function (l) { return ['NUEVO', 'CONTACTADO', 'CALIFICADO'].indexOf(l.ESTADO) >= 0; });
  var nuevos = cnt(function (l) { return l.ESTADO === 'NUEVO'; }), sinEj = cnt(function (l) { return abierto(l) && !l.EJECUTIVO_ID; });
  var demos = cnt(function (l) { return l.ESTADO === 'DEMO' && demoActiva(l); }), semana = cnt(function (l) { return l.ESTADO === 'DEMO' && demoActiva(l) && l.DEMO_DIAS <= 7; });
  var props = cnt(function (l) { return l.ESTADO === 'PROPUESTA' || l.ESTADO === 'NEGOCIACION'; }), neg = cnt(function (l) { return l.ESTADO === 'NEGOCIACION'; });
  var conts = cnt(function (l) { return l.ESTADO === 'CONTRATO'; }), sinAbrir = cnt(function (l) { return l.ESTADO === 'CONTRATO' && l.CONTRATO_ESTADO === 'ENVIADO'; });
  var conc = cnt(function (l) { return l.ESTADO === 'CONCRETADO'; }), mes = cnt(function (l) { return l.ESTADO === 'CONCRETADO' && String(l.FECHA_ESTADO || '').slice(0, 7) === y; });
  var K5 = [
    ['personadd', 'bl', 'Leads', leads, K.pl(nuevos, 'nuevo', 'nuevos') + ' · ' + sinEj + ' sin ejecutivo', 'pipeline', 'leads'],
    ['rocket', 'pu', 'Demos activas', demos, semana ? K.pl(semana, 'vence esta semana', 'vencen esta semana') : 'Ninguna vence esta semana', 'pipeline', 'demo'],
    ['quote', 'pu', 'Propuestas', props, neg + ' en negociación', 'pipeline', 'propuesta'],
    ['sign', 'wa', 'Contratos', conts, sinAbrir ? K.pl(sinAbrir, 'enviado sin abrir', 'enviados sin abrir') : 'Todos abiertos', 'pipeline', 'contrato'],
    ['ok', 'ok', 'Concretados', conc, mes + ' este mes', 'clientes', '']
  ];
  var kpis = '<div class="cc-kpis">' + K5.map(function (k) {
    return '<button type="button" class="cc-kpi" data-a="kpi" data-tab="' + k[5] + '" data-f="' + k[6] + '"><span class="cc-kpi-top">' + icb(k[0], k[1]) + ic('arrow') + '</span>' +
      '<span><small>' + k[2] + '</small><strong>' + k[3] + '</strong><em>' + esc(k[4]) + '</em></span></button>';
  }).join('') + '</div>';

  // Requiere atención, por grupo y en orden de urgencia
  var A = L.filter(abierto);
  var item = function (l, k, t, sub, ch) {
    return '<button type="button" class="cc-att" data-a="ficha" data-id="' + l.ID + '">' + icb(k, t, 36) +
      '<span class="cc-tx"><b>' + esc(l.EMPRESA) + '</b><span>' + esc(sub) + '</span></span>' + (ch ? chip(ch[0], ch[1]) : '') +
      '<span class="cc-ver">Ver ficha' + ic('chev') + '</span></button>';
  };
  var grupos = [];
  var gc = COB ? COB.grupoCobros() : null;   // «Cobros» va primero (prompt V2 §2)
  if (gc) grupos.push(gc);
  var g1 = A.filter(function (l) { var b = bandera(l); return l.ESTADO === 'DEMO' && b && (b[1] === 'da' || b[0].indexOf('Vence') === 0); })
            .sort(function (a, b) { return (a.DEMO_DIAS || 0) - (b.DEMO_DIAS || 0); });
  if (g1.length) grupos.push(['timer', 'Demos por vencer', g1.map(function (l) {
    var acceso = l.DEMO_ULT_ACCESO ? 'último acceso ' + cuando(l.DEMO_ULT_ACCESO) : 'aún no entra a la demo';
    return item(l, 'rocket', 'pu', l.CONTACTO + ' · demo desde el ' + dm(l.DEMO_INICIO) + ' · ' + acceso, bandera(l));
  })]);
  var g2 = A.filter(function (l) { return !l.EJECUTIVO_ID; });
  if (g2.length) grupos.push(['off', 'Leads sin ejecutivo', g2.map(function (l) { return item(l, 'personadd', 'bl', l.CONTACTO + ' · ' + (l.ORIGEN === 'FORM_WEB' ? 'formulario web ' : 'creado ') + cuando(l.FECHA_CREACION), [ST[l.ESTADO][0], ST[l.ESTADO][1]]); })]);
  var g3 = A.filter(function (l) { return l.ESTADO === 'CONTRATO' && l.CONTRATO_ESTADO === 'ENVIADO'; });
  if (g3.length) grupos.push(['mailx', 'Contratos enviados sin abrir', g3.map(function (l) { var d = dias(l.CONTRATO_ENVIADO, hoyIso()); return item(l, 'sign', 'wa', 'Enviado el ' + dmy(l.CONTRATO_ENVIADO) + ' a ' + l.CORREO, ['Sin abrir · ' + K.pl(d, 'día', 'días'), 'wa']); })]);
  var g4 = A.filter(function (l) { return l.REUNIONES_SIN_REGISTRAR > 0; });
  if (g4.length) grupos.push(['users', 'Reuniones sin registrar', g4.map(function (l) { return item(l, 'users', 'cy', l.CONTACTO + ' · registra notas, acuerdos y próxima acción', ['Sin registrar', 'wa']); })]);
  var ya = {}; [g1, g2, g3, g4].forEach(function (g) { g.forEach(function (l) { ya[l.ID] = 1; }); });
  var g5 = A.filter(function (l) { return !l.PROX_FECHA && !ya[l.ID]; });
  if (g5.length) grupos.push(['flag', 'Sin próxima acción', g5.map(function (l) { return item(l, 'flag', 'gr', l.CONTACTO + ' · ' + (l.ULT_TITULO ? l.ULT_TITULO + ' ' + cuando(l.ULT_FECHA) : 'sin actividad'), [ST[l.ESTADO][0], ST[l.ESTADO][1]]); })]);
  var total = {}; grupos.forEach(function (g) { g[2].length; }); A.filter(atencion).forEach(function (l) { total[l.ID] = 1; });
  var att = '<section class="cc-card"><div class="cc-card-h"><h2>Requiere atención</h2><span>' + K.pl(Object.keys(total).length, 'lead', 'leads') + ' · ordenados por urgencia</span></div>' +
    (grupos.length ? grupos.map(function (g) {
      var mas = g[2].length > 5 && !S.verMas[g[1]];
      return '<div class="cc-grp"><div class="cc-grp-t">' + ic(g[0], 16) + esc(g[1]) + '<b>' + g[2].length + '</b></div>' + g[2].slice(0, mas ? 5 : 999).join('') +
        (mas ? '<button type="button" class="cc-mas" data-a="vermas" data-v="' + esc(g[1]) + '">+ ' + (g[2].length - 5) + ' más</button>' : '') + '</div>';
    }).join('') : '<div class="cc-vacio">Nada pendiente. Buen trabajo.</div>') + '</section>';

  // Tus próximas acciones (hoy y atrasadas)
  var yo = String(CFG.usuario || ''), fin = hoyIso();
  var ag = (S.leads || []).filter(function (l) { return abierto(l) && l.PROX_FECHA && String(l.PROX_FECHA).slice(0, 10) <= fin && (S.ej ? true : String(l.EJECUTIVO_ID || '') === yo); })
    .sort(function (a, b) { return a.PROX_FECHA < b.PROX_FECHA ? -1 : 1; });
  var icoProx = { LLAMADA: 'phone', EMAIL: 'mail', REUNION: 'users', DEMO: 'rocket', PROPUESTA: 'quote' };
  var hoyD = dt(fin), titulo = K.fDL(fin);
  var agenda = '<section class="cc-card"><div class="cc-eyebrow">' + esc(titulo.charAt(0).toUpperCase() + titulo.slice(1)) + '</div>' +
    '<h2 style="margin:4px 0 12px">' + (S.ej ? 'Próximas acciones' : 'Tus próximas acciones') + '</h2>' +
    (ag.length ? ag.map(function (l) {
      var tarde = String(l.PROX_FECHA).slice(0, 10) < fin;
      return '<button type="button" class="cc-ag" data-a="ficha" data-id="' + l.ID + '"><b class="' + (tarde ? 'cc-tarde' : '') + '">' + (tarde ? dm(l.PROX_FECHA) : (hhmm(l.PROX_FECHA) && hhmm(l.PROX_FECHA) !== '00:00' ? hhmm(l.PROX_FECHA) : 'Hoy')) + '</b>' +
        '<span class="cc-agi">' + ic(icoProx[l.PROX_TIPO] || 'flag') + '</span><span class="cc-tx"><b>' + esc(l.PROX_TEXTO || 'Seguimiento') + '</b><span>' + esc(l.EMPRESA) + '</span></span></button>';
    }).join('') : '<div class="cc-vacio" style="padding:16px 0">No tienes acciones para hoy.</div>') +
    '<div class="cc-info">' + ic('light') + '<span>Las acciones salen de la «próxima acción» que registras en cada lead. Si un lead no tiene una, aparece en «Requiere atención».</span></div></section>';
  void hoyD;
  return kpis + '<div class="cc-resumen">' + att + agenda + '</div>';
}

/* ------------------------------------------------------------ PIPELINE */
var CHIPS = [['todos', 'Todos'], ['leads', 'Leads'], ['demo', 'Demo'], ['propuesta', 'Propuesta'], ['contrato', 'Contrato'], ['perdido', 'Perdidos'], ['atencion', 'Requieren atención']];
function prox(l) {
  if (!abierto(l)) return ['Sin próxima acción', '—', ''];
  if (!l.EJECUTIVO_ID) return ['Asignar ejecutivo', 'hoy', 'cc-hoy'];
  if (!l.PROX_FECHA) return ['Sin próxima acción', 'definir', 'cc-tarde'];
  var d = dias(hoyIso(), l.PROX_FECHA);
  return [l.PROX_TEXTO || 'Seguimiento', d < 0 ? 'atrasada · ' + dm(l.PROX_FECHA) : cuando(l.PROX_FECHA), d < 0 ? 'cc-tarde' : d === 0 ? 'cc-hoy' : ''];
}
function filaLead(l) {
  var b = bandera(l), p = prox(l);
  return '<button type="button" class="cc-row' + (S.sel === l.ID ? ' cc-sel' : '') + '" data-a="ficha" data-id="' + l.ID + '">' +
    '<span class="cc-c2"><b>' + esc(l.EMPRESA) + '</b><span>' + esc(l.CONTACTO) + (l.CARGO ? ' · ' + esc(l.CARGO) : '') + '</span></span>' +
    '<span class="cc-st">' + stChip(l.ESTADO) + (b ? chip(b[0], b[1]) : '') + '</span>' +
    '<span class="cc-ej">' + (l.EJECUTIVO_ID ? av(l.EJECUTIVO) + '<span>' + esc(l.EJECUTIVO) + '</span>' : '<span class="cc-asig">' + ic('personadd') + 'Asignar</span>') + '</span>' +
    '<span class="cc-c2"><span style="color:var(--ink);font-size:13px">' + esc(l.ULT_TITULO || '—') + '</span><span>' + esc(cuando(l.ULT_FECHA)) + '</span></span>' +
    '<span class="cc-c2"><span style="color:var(--ink);font-size:13px;font-weight:600">' + esc(p[0]) + '</span><span class="' + p[2] + '">' + esc(p[1]) + '</span></span>' +
    '<span class="cc-dias">' + (l.DIAS == null ? '—' : l.DIAS) + '</span>' + ic('chev', 20) + '</button>';
}
function tarjeta(l) {
  var b = bandera(l), p = prox(l);
  return '<button type="button" class="cc-card2' + (S.sel === l.ID ? ' cc-sel' : '') + '" data-a="ficha" data-id="' + l.ID + '"><b>' + esc(l.EMPRESA) + '</b><span>' + esc(l.CONTACTO) + '</span>' +
    (b ? chip(b[0], b[1]) : '') + '<span class="cc-cf"><span>' + av(l.EJECUTIVO, true) + esc(p[1]) + '</span><span style="font-weight:700">' + (l.DIAS || 0) + ' d</span></span></button>';
}
function vistaPipeline() {
  var L = visibles(), rows = L.filter(function (l) { return enFiltro(l, S.filt); });
  var chips = CHIPS.map(function (c) {
    var n = L.filter(function (l) { return enFiltro(l, c[0]); }).length;
    return '<button type="button" class="cc-fchip" aria-pressed="' + (S.filt === c[0]) + '" data-a="filt" data-v="' + c[0] + '">' + (c[0] === 'atencion' ? '<span class="cc-dot"></span>' : '') + c[1] + ' <b>' + n + '</b></button>';
  }).join('');
  var cuerpo;
  if (S.view === 'lista') {
    cuerpo = '<div class="cc-scroll"><div class="cc-tabla"><div class="cc-th"><span>Empresa · contacto</span><span>Estado</span><span>Ejecutivo</span><span>Última actividad</span><span>Próxima acción</span><span style="text-align:right">Días</span><span></span></div>' +
      '<div class="cc-filas">' + (rows.length ? rows.map(filaLead).join('') : '<div class="cc-vacio">No hay leads con este filtro.</div>') + '</div></div></div>' +
      '<div class="cc-pie"><span>Mostrando ' + rows.length + ' de ' + L.filter(function (l) { return enFiltro(l, S.filt); }).length + ' leads</span><span>Ordenado por próxima acción</span></div>';
  } else {
    var cols = ['NUEVO', 'CONTACTADO', 'CALIFICADO', 'DEMO', 'PROPUESTA', 'NEGOCIACION', 'CONTRATO'];
    if (S.filt === 'perdido') cols = ['PERDIDO'];
    cuerpo = '<div class="cc-scroll"><div class="cc-board">' + cols.map(function (c) {
      var cs = rows.filter(function (l) { return l.ESTADO === c; }), mas = cs.length > 8 && !S.verMas['col' + c];
      return '<div class="cc-col"><div class="cc-col-h">' + stChip(c) + '<span>' + cs.length + '</span></div>' + cs.slice(0, mas ? 8 : 999).map(tarjeta).join('') +
        (mas ? '<button type="button" class="cc-mas" data-a="vermas" data-v="col' + c + '">+ ' + (cs.length - 8) + ' más</button>' : '') + '</div>';
    }).join('') + '</div></div>';
  }
  return '<section class="cc-panel"><div class="cc-bar"><label class="cc-buscar">' + ic('search', 20) + '<input type="search" id="ccQ" value="' + esc(S.q) + '" placeholder="Empresa, contacto o correo" aria-label="Buscar lead"></label>' +
    '<div class="cc-seg" role="group" aria-label="Vista"><button type="button" aria-pressed="' + (S.view === 'lista') + '" data-a="vista" data-v="lista">' + ic('list') + 'Lista</button>' +
    '<button type="button" aria-pressed="' + (S.view === 'tablero') + '" data-a="vista" data-v="tablero">' + ic('kanban') + 'Tablero</button></div></div>' +
    '<div class="cc-chips">' + chips + '</div>' + cuerpo + '</section>';
}

/* ------------------------------------------------------------ CLIENTES */
function vistaClientes() {
  if (!S.clientes) { cargarClientes().catch(K.toastError); return '<div class="cc-cargando">Cargando clientes…</div>'; }
  var q = K.nrm(S.cq.trim());
  var C = S.clientes.filter(function (c) { return !q || K.nrm([c.EMPRESA, c.RUT, c.PLAN_NOMBRE].join(' ')).indexOf(q) >= 0; });
  var activa = function (c) { return c.ESTADO === 'ACTIVA' && (c.DIAS_RENOVACION == null || c.DIAS_RENOVACION >= 0); };
  var renueva = function (c) { return activa(c) && c.DIAS_RENOVACION != null && c.DIAS_RENOVACION <= 60; };
  var F = { activas: activa, renuevan: renueva, todas: function () { return true; } };
  var rows = C.filter(F[S.cfilt]);
  var ch = [['activas', 'Activas'], ['renuevan', 'Renuevan en 60 días'], ['todas', 'Todas']].map(function (c) {
    return '<button type="button" class="cc-fchip" aria-pressed="' + (S.cfilt === c[0]) + '" data-a="cfilt" data-v="' + c[0] + '">' + (c[0] === 'renuevan' ? '<span class="cc-dot"></span>' : '') + c[1] + ' <b>' + C.filter(F[c[0]]).length + '</b></button>';
  }).join('');
  var fila = function (c) {
    var tope = c.USUARIOS_TOPE, uso = c.USUARIOS || 0, pct = tope ? Math.min(100, Math.round(uso / tope * 100)) : 0;
    var st = c.ESTADO !== 'ACTIVA' ? [c.ESTADO || 'Sin suscripción', 'da'] : (c.DIAS_RENOVACION != null && c.DIAS_RENOVACION < 0 ? ['Vencida', 'da'] : renueva(c) ? ['Renueva en ' + c.DIAS_RENOVACION + ' días', 'wa'] : ['Activa', 'ok']);
    return '<button type="button" class="cc-crow" data-a="ficha" data-id="' + c.LEAD + '"><span class="cc-c2"><b>' + esc(c.EMPRESA) + '</b><span>' + esc(c.RUT || '') + '</span></span>' +
      '<span style="font-size:13px;font-weight:600">' + esc(c.PLAN_NOMBRE || '—') + '</span><span>' + chip(st[0], st[1]) + '</span>' +
      '<span class="cc-num">' + (c.DESDE ? dm(c.DESDE) + '/' + c.DESDE.slice(2, 4) : '—') + '</span><span class="cc-num">' + (c.RENUEVA ? dmy(c.RENUEVA) : '—') + '</span>' +
      '<span class="cc-num cc-r">' + (c.MENSUAL_UF != null ? uf(c.MENSUAL_UF) : '—') + '</span>' +
      '<span style="display:flex;flex-direction:column;gap:5px"><span style="font-size:12px;color:var(--muted)">' + uso + (tope ? ' de ' + tope : ' · sin tope') + '</span>' +
      (tope ? '<span class="cc-meter cc-6"><span class="' + (pct >= 80 ? 'cc-alto' : '') + '" style="width:' + pct + '%"></span></span>' : '') + '</span>' +
      '<span class="cc-ej">' + av(c.EJECUTIVO) + '<span>' + esc(c.EJECUTIVO || '—') + '</span></span></button>';
  };
  return segSub('clientes') + '<section class="cc-panel"><div class="cc-bar"><label class="cc-buscar">' + ic('search', 20) + '<input type="search" id="ccCQ" value="' + esc(S.cq) + '" placeholder="Cliente, plan o RUT" aria-label="Buscar cliente"></label>' +
    '<div class="cc-chips">' + ch + '</div></div>' +
    '<div class="cc-scroll"><div class="cc-tabla"><div class="cc-th cc-cli"><span>Cliente</span><span>Plan</span><span>Suscripción</span><span>Desde</span><span>Renueva</span><span style="text-align:right">Mensualidad</span><span>Usuarios</span><span>Ejecutivo</span></div>' +
    '<div class="cc-filas">' + (rows.length ? rows.map(fila).join('') : '<div class="cc-vacio">' + (S.clientes.length ? 'No hay clientes con este filtro.' : 'Todavía no hay leads concretados. Al firmar un contrato, el cliente aparece aquí.') + '</div>') + '</div></div></div>' +
    '</section>';
}

/* ------------------------------------------------------------ SUSCRIPCIONES y EMPRESAS
   Lo que antes eran seis menús (bloque 459), como vistas de dos pestañas. La
   lista es propia; la ficha de cada fila es la de siempre, abierta
   en el cajón lateral (nunca en un modal), y al cerrarla la lista se
   vuelve a pedir. */
var SUBS = {
  clientes: [['concretados', 'Concretados', ''], ['empresas', 'Todas las empresas', 'Clientes']],
  suscripciones: [['suscripciones', 'Suscripciones', 'Suscripciones'], ['periodos', 'Períodos', 'Períodos'], ['pagos', 'Pagos', 'Pagos'], ['planes', 'Planes', 'Planes']]
};
function subVistas(tab) {
  var ok = (S.ini && S.ini.administrar || []).map(function (a) { return a.n; });
  return SUBS[tab].filter(function (x) { return !x[2] || ok.indexOf(x[2]) >= 0; });
}
function segSub(tab) {
  var v = subVistas(tab); if (v.length < 2) return '';
  var act = S.sub[tab] || v[0][0];
  return '<div class="cc-seg" role="group" aria-label="Vista" style="margin-bottom:12px">' + v.map(function (x) {
    return '<button type="button" aria-pressed="' + (act === x[0]) + '" data-a="sub" data-t="' + tab + '" data-v="' + x[0] + '">' + x[1] + '</button>';
  }).join('') + '</div>';
}
function cargarAdm(v) {
  S.adm[v] = { cargando: true };
  call('Administracion', { vista: v }).then(function (r) { S.adm[v] = r; pintar(); }).catch(function (e) { S.adm[v] = { error: e.message }; pintar(); });
}
/* La ficha de siempre (Simple.master) en el cajón lateral, no en un modal.
   Las fichas cierran y refrescan por window.frameElement.radWindow: aquí se
   les da el mismo contrato que les da SigmaModal (close, BrowserWindow.refresh),
   así que funcionan sin tocarlas. Al cerrar el cajón la lista se vuelve a pedir. */
function abrirFichaSitio(url, titulo, v) {
  K.Panel.open({ st: { url: url }, onclose: function () { cargarAdm(v); }, render: function (st) {
    return { w: 'w', s: 'Centro Comercial', t: esc(titulo), b: '<iframe class="cc-ficha-frame" src="' + esc(st.url) + '" title="' + esc(titulo) + '"></iframe>' };
  } });
  var f = $('#cpLayer .cc-ficha-frame');
  if (!f) return;
  $('#cpLayer .cp-pnl-b').classList.add('cc-ficha-b');
  var adaptador = {
    BrowserWindow: { refresh: function () { cargarAdm(v); }, LogOut: null },
    close: function () { K.Panel.close(); },
    center: function () { }, setSize: function () { },
    isVisible: function () { return true; },
    get_contentFrame: function () { return f; }, get_contentFrameElement: function () { return f; }
  };
  f.radWindow = adaptador;
  f.addEventListener('load', function () {
    try { f.contentWindow.radWindow = adaptador; f.contentDocument.documentElement.classList.add('sigma-dialog-child'); } catch (e) { }
  });
}
var clp0 = function (n) { return n == null ? '—' : '$' + K.fN(n); };
var ADM = {
  suscripciones: { cols: 'minmax(220px,2fr) 150px 140px 110px 110px minmax(160px,1.2fr)', th: ['Cliente', 'Plan', 'Estado', 'Desde', 'Hasta', 'Contacto'], q: 'Cliente, plan o contacto',
    fila: function (x) {
      var t = !x.opera ? 'da' : x.dias != null && x.dias <= 30 ? 'wa' : 'ok';
      return ['<span class="cc-c2"><b>' + esc(x.cliente) + '</b></span>', esc(x.plan || '—'), chip(x.estadoNombre || x.estado || '—', t),
        '<span class="cc-num">' + dmy(x.desde) + '</span>', '<span class="cc-num">' + (x.hasta ? dmy(x.hasta) + (x.dias != null ? ' · ' + x.dias + ' d' : '') : 'Sin término') + '</span>',
        '<span class="cc-c2"><span style="color:var(--ink);font-size:13px">' + esc(x.contacto || '—') + '</span><span>' + esc(x.correo || '') + '</span></span>'];
    }, txt: function (x) { return [x.cliente, x.plan, x.contacto, x.correo].join(' '); }, titulo: 'Suscripción' },
  periodos: { cols: 'minmax(200px,2fr) 130px 190px 110px 120px 120px 130px', th: ['Cliente', 'Plan', 'Período', 'UF', 'Monto', 'Saldo', 'Estado'], q: 'Cliente o plan',
    fila: function (x) {
      return ['<span class="cc-c2"><b>' + esc(x.cliente) + '</b><span>' + esc(x.cobro || '') + (x.implantacion ? ' · implantación' : '') + '</span></span>', esc(x.plan || '—'),
        '<span class="cc-num">' + dmy(x.desde) + ' – ' + dmy(x.hasta) + '</span>', '<span class="cc-num cc-r">' + K.fN(x.uf, 2) + '</span>', '<span class="cc-num cc-r">' + clp0(x.monto) + '</span>',
        '<span class="cc-num cc-r">' + clp0(x.saldo) + '</span>', chip(x.estado || '—', x.saldo > 0 ? 'wa' : 'ok')];
    }, txt: function (x) { return [x.cliente, x.plan, x.estado].join(' '); }, titulo: 'Período' },
  pagos: { cols: 'minmax(200px,2fr) 110px 130px 130px minmax(160px,1.2fr) 140px', th: ['Cliente', 'Fecha', 'Declarado', 'Verificado', 'Banco · operación', 'Estado'], q: 'Cliente, banco u operación',
    fila: function (x) {
      var t = x.codigo === 'VERIFICADO' ? 'ok' : x.codigo === 'RECHAZADO' ? 'da' : 'wa';
      return ['<span class="cc-c2"><b>' + esc(x.cliente) + '</b><span>' + (x.periodo ? 'Período del ' + dmy(x.periodo) : '') + '</span></span>', '<span class="cc-num">' + dmy(x.fecha) + '</span>',
        '<span class="cc-num cc-r">' + clp0(x.declarado) + '</span>', '<span class="cc-num cc-r">' + clp0(x.verificado) + '</span>',
        '<span class="cc-c2"><span style="color:var(--ink);font-size:13px">' + esc(x.banco || '—') + '</span><span>' + esc(x.operacion || '') + '</span></span>', chip(x.estado || '—', t)];
    }, txt: function (x) { return [x.cliente, x.banco, x.operacion, x.estado].join(' '); }, titulo: 'Pago' },
  planes: { cols: '120px minmax(200px,1.4fr) minmax(220px,2fr) 110px 120px', th: ['Código', 'Plan', 'Descripción', 'Gracia', 'Estado'], q: 'Código o nombre',
    fila: function (x) {
      return ['<b style="font-size:13px">' + esc(x.codigo) + '</b>', '<span class="cc-c2"><b>' + esc(x.nombre) + '</b></span>', '<span class="cc-c2"><span>' + esc(x.descripcion || '') + '</span></span>',
        '<span class="cc-num">' + x.gracia + ' días</span>', chip(!x.habilitado ? 'Deshabilitado' : x.publico ? 'Público' : 'No público', !x.habilitado ? 'gr' : x.publico ? 'ok' : 'bl')];
    }, txt: function (x) { return [x.codigo, x.nombre, x.descripcion].join(' '); }, titulo: 'Plan', nuevo: 'Nuevo plan' },
  empresas: { cols: 'minmax(220px,2fr) minmax(200px,1.6fr) 140px 110px 130px', th: ['Empresa', 'Razón social', 'RUT', 'Desde', 'Estado'], q: 'Empresa, razón social o RUT',
    fila: function (x) {
      return ['<span class="cc-c2"><b>' + esc(x.nombre) + '</b></span>', '<span class="cc-c2"><span>' + esc(x.razon || '') + '</span></span>', '<span class="cc-num">' + esc(x.rut || '') + '</span>',
        '<span class="cc-num">' + dmy(x.desde) + '</span>', chip(x.habilitado ? 'Habilitada' : 'Deshabilitada', x.habilitado ? 'ok' : 'gr')];
    }, txt: function (x) { return [x.nombre, x.razon, x.rut].join(' '); }, titulo: 'Cliente', nuevo: 'Nuevo cliente' }
};
function vistaAdm(v) {
  var tab = v === 'empresas' ? 'clientes' : 'suscripciones', d = S.adm[v], C = ADM[v];
  if (!d) { cargarAdm(v); d = S.adm[v]; }
  var cab = segSub(tab);
  if (d.cargando) return cab + '<div class="cc-cargando">Cargando…</div>';
  if (d.error) return cab + '<div class="cc-vacio">' + esc(d.error) + '</div>';
  var q = K.nrm(S.aq.trim());
  var rows = d.filas.filter(function (x) { return !q || K.nrm(C.txt(x)).indexOf(q) >= 0; });
  var cols = 'grid-template-columns:' + C.cols;
  return cab + '<section class="cc-panel"><div class="cc-bar"><label class="cc-buscar">' + ic('search', 20) + '<input type="search" id="ccAQ" value="' + esc(S.aq) + '" placeholder="' + C.q + '" aria-label="Buscar"></label>' +
    (C.nuevo && d.crear ? '<button type="button" class="cp-btn cp-pri" data-a="admnuevo" data-v="' + v + '">' + ic('plus') + C.nuevo + '</button>' : '') + '</div>' +
    '<div class="cc-scroll"><div class="cc-tabla"><div class="cc-th" style="' + cols + '">' + C.th.map(function (h) { return '<span>' + h + '</span>'; }).join('')  + '</div>' +
    '<div class="cc-filas">' + (rows.length ? rows.map(function (x) {
      return '<div class="cc-crow" role="button" tabindex="0" style="' + cols + '" data-a="admver" data-v="' + v + '" data-q="' + esc(x.q) + '">' + C.fila(x).map(function (c) { return '<span style="min-width:0">' + c + '</span>'; }).join('') + '</div>';
    }).join('') : '<div class="cc-vacio">Sin resultados.</div>') + '</div></div></div>' +
    '<div class="cc-pie"><span>' + rows.length + ' de ' + d.filas.length + '</span><span>Clic en una fila para abrir su ficha</span></div></section>';
}

/* =====================================================================
   FICHA (cajón 600 px) y lo que se crea desde ella
   ===================================================================== */
var F = null;   // estado del cajón: { id, data, modo, open, ... }

function abrirFicha(id) {
  S.sel = +id;
  F = { id: +id, data: null, modo: 'ficha', open: null, tipo: 'LLAMADA', txt: '', perd: false, motivo: '', edit: false, f: {}, ext: false, anular: null, motivoAn: '', prox: null };
  K.Panel.open({ render: render, st: F, onclose: function () { F = null; S.sel = null; pintar(); } });
  pintar();
  call('Ficha', { lead: +id }).then(function (d) { if (F && F.id === +id) { F.data = d; K.Panel.paint(); } }).catch(function (e) { K.toastError(e); K.Panel.close(); });
}
function recibir(d, msg) {
  if (!F) return;
  F.data = d.ficha || d; F.modo = 'ficha'; F.busy = false; F.perd = false; F.edit = false; F.ext = false; F.anular = null;
  K.Panel.paint(); refrescarLead(F.data);
  if (msg) K.toast(msg);
}
function ocupado(p) { if (F) { F.busy = true; K.Panel.paint(); } return p.catch(function (e) { if (F) { F.busy = false; K.Panel.paint(); } K.toastError(e); throw e; }); }

function etapa(d) {
  var e = d.lead.ESTADO;
  if (e === 'CONCRETADO') return 4;
  if (e === 'CONTRATO') return 3;
  if (e === 'PROPUESTA' || e === 'NEGOCIACION') return 2;
  if (e === 'DEMO') return 1;
  if (e === 'PERDIDO') return d.contratos.length ? 3 : d.propuestas.length ? 2 : d.demo ? 1 : 0;
  return 0;
}
function propVigente(d) { return d.propuestas.filter(function (p) { return p.ESTADO === 'ENVIADA' || p.ESTADO === 'ACEPTADA' || p.ESTADO === 'BORRADOR'; })[0] || d.propuestas[0] || null; }
function contUltimo(d) { return d.contratos[0] || null; }

function render(st) {
  var d = st.data;
  if (!d) return { w: 'c', s: 'Cargando…', t: 'Ficha del lead', b: '<div class="cc-cargando">Cargando la ficha…</div>' };
  if (st.modo === 'demo') return vDemo(st, d);
  if (st.modo === 'prop') return vProp(st, d);
  if (st.modo === 'reu') return vReu(st, d);
  return vFicha(st, d);
}

/* ---------------------------------------------------------------- la ficha */
function vFicha(st, d) {
  var l = d.lead, idx = etapa(d), pm = S.ini.permisos, demo = d.demo, uso = d.uso, pv = propVigente(d), ct = contUltimo(d);
  if (!st.open) st.open = { info: idx === 0, demo: idx === 1, prop: idx === 2, cont: idx >= 3, reu: false };

  var pasos = ['Lead', 'Demo', 'Propuesta', 'Contrato', 'Cliente'];
  var fechas = [l.FECHA_CREACION, demo && demo.INICIO, pv && (pv.ENVIADA || pv.CREADA), ct && ct.CREADO, ct && ct.FIRMADO];
  var stepper = '<ol class="cc-step" aria-label="Etapa comercial">' + pasos.map(function (t, i) {
    var cls = i < idx || (idx === 4 && i === 4) ? 'cc-hecho' : i === idx ? 'cc-actual' : '';
    return '<li class="' + cls + '"><span class="cc-pt">' + (cls === 'cc-hecho' ? ic('check', 16) : (i + 1)) + '</span><span class="cc-sl">' + t + '</span><span class="cc-sd">' + (fechas[i] ? dm(fechas[i]) : '—') + '</span></li>';
  }).join('') + '</ol>';

  var sig = siguiente(d, idx);
  var top = '<div class="cc-ficha-top"><div class="cc-contacto">' +
    '<span>' + ic('person', 18) + '<b>' + esc(l.CONTACTO) + '</b>' + (l.CARGO ? ' · ' + esc(l.CARGO) : '') + '</span>' +
    '<span>' + ic('mail', 18) + esc(l.CORREO) + '<button type="button" class="cc-copiar" data-a="copiar" data-v="' + esc(l.CORREO) + '" aria-label="Copiar correo" title="Copiar correo">' + ic('copy', 16) + '</button></span>' +
    (l.TELEFONO ? '<span>' + ic('phone', 18) + esc(l.TELEFONO) + '</span>' : '') + '</div>' +
    (pm.leads && l.ESTADO !== 'CONCRETADO' && l.ESTADO !== 'PERDIDO' ? '<button type="button" class="cp-btn cp-sec cp-sm" data-a="reu" data-f="agendar">' + ic('event') + 'Agendar reunión</button>' : '') + '</div>';

  var b = top + stepper + '<div class="cc-sig ' + sig[2] + '">' + ic(sig[1], 20) + '<span>' + sig[0] + '</span></div>' +
    secInfo(st, d) + (demo ? secDemo(st, d, demo, uso) : '') + (d.propuestas.length ? secProp(st, d) : '') +
    (d.contratos.length ? secCont(st, d) : '') + (d.reuniones.length ? secReu(st, d) : '') + secTimeline(st, d);

  return { w: 'c', s: esc(l.CODIGO) + ' · ' + (l.ORIGEN === 'FORM_WEB' ? 'Formulario web' : 'Creado a mano') + ' · ' + dmy(l.FECHA_CREACION),
    t: esc(l.EMPRESA) + ' ' + stChip(l.ESTADO), b: b, f: pie(st, d, idx) };
}

function siguiente(d, idx) {
  var l = d.lead, pv = propVigente(d), ct = contUltimo(d), demo = d.demo, prim = K.ini(l.CONTACTO) ? l.CONTACTO.split(' ')[0] : l.CONTACTO;
  if (l.ESTADO === 'PERDIDO') return ['Lead perdido' + (l.MOTIVO_PERDIDA ? ': ' + esc(l.MOTIVO_PERDIDA) : '') + '. Puedes reabrirlo si retoma el interés.', 'block', 'cc-da'];
  if (l.ESTADO === 'CONCRETADO') return ['Cliente activo desde el ' + dmy(ct && ct.FIRMADO) + '. Su suscripción, cobros y pagos están en Clientes › Administración comercial.', 'ok', 'cc-ok'];
  if (!l.EJECUTIVO_ID) return ['Siguiente paso: asígnale un ejecutivo en «Información» y haz el primer contacto.', 'personadd', 'cc-wa'];
  if (idx === 0) return ['Siguiente paso: calificar la necesidad y crear la demo' + (l.INTERESES || l.PLAN_INTERES ? ' (' + esc(l.PLAN_INTERES || l.INTERESES) + ')' : '') + '.', 'flag', ''];
  if (idx === 1 && demo) {
    var n = dias(hoyIso(), demo.EXPIRA), u = d.uso || {};
    if (demo.ESTADO === 'VENCIDA' || n < 0) return ['La demo venció el ' + dmy(demo.EXPIRA) + '. Extiéndela o envía la propuesta.', 'timer', 'cc-da'];
    var act = u.OT ? esc(prim) + ' ya creó ' + K.pl(u.OT, 'OT', 'OT') + ': buen momento para enviar la propuesta.' : (demo.ULT_ACCESO ? 'Aún no crea OT en la demo.' : esc(prim) + ' aún no entra a la demo.');
    return ['La demo vence ' + (n === 0 ? 'hoy' : n === 1 ? 'mañana' : 'en ' + n + ' días') + '. ' + act, 'timer', n <= 3 ? 'cc-wa' : ''];
  }
  if (idx === 2 && pv) {
    if (pv.ESTADO === 'BORRADOR') return ['La propuesta v' + pv.VERSION + ' está en borrador. Revísala y envíala.', 'quote', 'cc-wa'];
    if (!l.RUT) return ['Propuesta enviada el ' + dmy(pv.ENVIADA) + '. Para generar el contrato, completa antes el RUT de la empresa en «Información».', 'flag', 'cc-wa'];
    return ['Propuesta v' + pv.VERSION + ' enviada el ' + dmy(pv.ENVIADA) + '. Si la acepta, genera el contrato.', 'flag', ''];
  }
  if (idx === 3 && ct) {
    if (ct.ESTADO === 'ANULADO') return ['El contrato v' + ct.VERSION + ' se anuló. Genera una versión nueva desde la propuesta vigente.', 'sign', 'cc-wa'];
    if (ct.ESTADO === 'VISUALIZADO') return ['Contrato v' + ct.VERSION + ' visualizado el ' + dmyh(ct.VISUALIZADO) + '. Falta la firma de ' + esc(l.CONTACTO) + '.', 'eye', ''];
    var vence = ct.TOKEN_EXPIRA && dias(hoyIso(), ct.TOKEN_EXPIRA) < 0;
    return ['Contrato v' + ct.VERSION + ' enviado el ' + dmy(ct.ENVIADO) + (vence ? '. El enlace venció: reenvíalo.' : '. Aún no lo abre.'), 'mailx', 'cc-wa'];
  }
  return ['Revisa la actividad y define la próxima acción.', 'flag', ''];
}

function sec(k, icono, tono, titulo, resumen, cuerpo, st) {
  var o = st.open[k];
  return '<section class="cc-sec"><button type="button" class="cc-sec-h" data-a="sec" data-v="' + k + '" aria-expanded="' + !!o + '">' +
    '<span style="color:var(--cc-' + tono + ')">' + ic(icono, 20) + '</span><b>' + titulo + '</b>' + (resumen || '') + ic(o ? 'chevu' : 'chevd', 20) + '</button>' +
    (o ? '<div class="cc-sec-b">' + cuerpo + '</div>' : '') + '</section>';
}

/* Información + ejecutivo + próxima acción + cambio de estado a mano */
function secInfo(st, d) {
  var l = d.lead, pm = S.ini.permisos, cerrado = l.ESTADO === 'CONCRETADO';
  var cuerpo;
  if (st.edit) {
    var f = st.f, fld = function (k, t, o) { o = o || {}; return '<div class="cp-fld' + (o.full ? ' cc-full' : '') + '"><label for="cf_' + k + '">' + t + '</label><input class="cp-inp" id="cf_' + k + '" data-pv="f.' + k + '" value="' + esc(f[k] || '') + '"' + (o.ph ? ' placeholder="' + esc(o.ph) + '"' : '') + '></div>'; };
    cuerpo = '<div class="cc-grid2">' + fld('EMPRESA', 'Empresa') + fld('RUT', 'RUT de la empresa', { ph: '76.123.456-7' }) + fld('RUBRO', 'Rubro', { ph: 'Alimentos, minería…' }) +
      fld('CONTACTO', 'Contacto') + fld('CARGO', 'Cargo') + fld('CORREO', 'Correo') + fld('TELEFONO', 'Teléfono') + '</div>' +
      '<div class="cp-fld"><span class="cp-lb">Interés</span>' + modChips(mods(f.INTERESES), 'intmod') + '</div>' +
      '<div class="cc-acc"><button type="button" class="cp-btn cp-ghost cp-sm" data-a="infox">Cancelar</button><span class="cc-sp"></span><button type="button" class="cp-btn cp-pri cp-sm" data-a="infook"' + (st.busy ? ' disabled' : '') + '>Guardar datos</button></div>';
  } else {
    var ejs = (S.ini.ejecutivos || []).map(function (e) { return { id: String(e.ID), n: e.NOMBRE }; });
    var dl = [['Empresa', esc(l.EMPRESA)], ['RUT', l.RUT ? esc(l.RUT) : '<span class="cc-falta">Por completar · lo pide el contrato</span>'], ['Rubro', l.RUBRO ? esc(l.RUBRO) : '—'],
      ['Origen', (l.ORIGEN === 'FORM_WEB' ? 'Formulario web (inicio.aspx)' : 'Registrado a mano') + ' · ' + dmyh(l.FECHA_CREACION)]];
    if (l.N_ACTIVOS) dl.push(['Activos', esc(l.N_ACTIVOS)]);
    if (l.PAIS) dl.push(['País', esc(l.PAIS)]);
    cuerpo = '<dl class="cc-dl">' + dl.map(function (x) { return '<dt>' + x[0] + '</dt><dd>' + x[1] + '</dd>'; }).join('') + '</dl>' +
      (l.INTERESES || l.PLAN_INTERES ? '<div class="cc-wrap">Interés: ' + (mods(l.INTERESES).filter(function (m) { return nombreMod(m) !== m; }).map(function (m) { return chip(nombreMod(m), 'pu'); }).join('') || chip(l.PLAN_INTERES || l.INTERESES, 'pu')) + '</div>' : '') +
      (l.MENSAJE ? '<blockquote class="cc-cita">«' + esc(l.MENSAJE) + '»</blockquote>' : '') +
      (pm.leads && !cerrado ? '<div class="cc-grid2"><div class="cp-fld"><span class="cp-lb">Ejecutivo</span>' + K.combo('ccEjFicha', ejs, l.EJECUTIVO_ID ? String(l.EJECUTIVO_ID) : '', { ph: 'Asignar ejecutivo', etiqueta: 'Ejecutivo del lead' }) + '</div>' +
        '<div class="cp-fld"><span class="cp-lb">Estado</span><div class="cc-acc">' + estadosManuales(l) + '</div></div></div>' : '<div class="cc-nota">Ejecutivo: ' + esc(l.EJECUTIVO || 'sin asignar') + '</div>') +
      (pm.leads && !cerrado && l.ESTADO !== 'PERDIDO' ? bloqueProx(st, l) : '') +
      (pm.leads && !cerrado ? '<div class="cc-acc"><button type="button" class="cp-btn cp-out cp-sm" data-a="infoed">' + ic('badge') + 'Editar datos</button></div>' : '');
  }
  var resumen = '<small>' + esc(l.CONTACTO) + ' · ' + esc(l.EJECUTIVO || 'sin ejecutivo') + '</small>';
  return sec('info', 'badge', 'lab', 'Información', resumen, cuerpo, st);
}
function estadosManuales(l) {
  var op = [];
  if (l.ESTADO === 'NUEVO') op.push(['CONTACTADO', 'Contactado']);
  if (['NUEVO', 'CONTACTADO'].indexOf(l.ESTADO) >= 0) op.push(['CALIFICADO', 'Calificado']);
  if (l.ESTADO === 'PROPUESTA') op.push(['NEGOCIACION', 'En negociación']);
  if (l.ESTADO === 'PERDIDO') op.push(['CONTACTADO', 'Reabrir']);
  return op.length ? op.map(function (o) { return '<button type="button" class="cp-btn cp-plain cp-sm" data-a="estado" data-v="' + o[0] + '">' + ic('arrow', 16) + o[1] + '</button>'; }).join('') : '<span class="cc-nota">Lo mueven sus acciones (demo, propuesta, contrato).</span>';
}
function bloqueProx(st, l) {
  var p = st.prox || { tipo: l.PROX_TIPO || 'LLAMADA', txt: l.PROX_TEXTO || '', fecha: l.PROX_FECHA ? l.PROX_FECHA.slice(0, 10) : '', hora: l.PROX_FECHA ? hhmm(l.PROX_FECHA) : '10:00' };
  st.prox = p;
  return '<div class="cp-fld"><span class="cp-lb">Próxima acción</span><div class="cc-grid4" style="grid-template-columns:120px minmax(0,1fr) 130px 96px">' +
    K.combo('ccProxTipo', PROX, p.tipo, { etiqueta: 'Tipo de próxima acción' }) +
    '<input class="cp-inp" data-pv="prox.txt" value="' + esc(p.txt) + '" placeholder="Qué hay que hacer" aria-label="Próxima acción">' +
    K.fecha('prox.fecha', p.fecha, { etiqueta: 'Fecha de la próxima acción' }) + K.combo('ccProxHora', HORAS, p.hora, { etiqueta: 'Hora' }) + '</div>' +
    '<div class="cc-acc"><span class="cc-hint">' + (l.PROX_FECHA ? 'Actual: ' + esc(l.PROX_TEXTO || '') + ' · ' + dmyh(l.PROX_FECHA) : 'Sin próxima acción: el lead aparece en «Requiere atención».') + '</span><span class="cc-sp"></span>' +
    '<button type="button" class="cp-btn cp-out cp-sm" data-a="proxok">Guardar próxima acción</button></div></div>';
}
function modChips(sel, accion) {
  return '<div class="cc-mods">' + (S.ini.modulos || []).map(function (m) {
    return '<button type="button" class="cc-mod" aria-pressed="' + (sel.indexOf(m.id) >= 0) + '" data-a="' + accion + '" data-v="' + m.id + '">' + (sel.indexOf(m.id) >= 0 ? ic('check', 14) : '') + esc(m.n) + '</button>';
  }).join('') + '</div>';
}

/* Demo: fechas, consumo y acciones */
function secDemo(st, d, demo, u) {
  u = u || {};
  var n = dias(hoyIso(), demo.EXPIRA), vencida = demo.ESTADO === 'VENCIDA' || (n < 0 && demo.ESTADO !== 'FINALIZADA');
  var ch = demo.ESTADO === 'FINALIZADA' ? chip('FINALIZADA', 'gr') : vencida ? chip('VENCIDA', 'da') : chip(demo.ESTADO === 'EXTENDIDA' ? 'EXTENDIDA' : 'ACTIVA', 'ok');
  var flag = !vencida && demo.ESTADO !== 'FINALIZADA' && n <= 3 ? chip(n === 0 ? 'Vence hoy' : n === 1 ? 'Vence mañana' : 'Vence en ' + n + ' días', 'wa') : '';
  var usoH = LIMS.map(function (x) {
    var v = u[x[0].toUpperCase()] || 0, max = demo['LIM_' + x[0].toUpperCase()] || 0, pct = max ? Math.min(100, Math.round(v / max * 100)) : 0, alto = pct >= 80;
    return '<div><div class="cc-uso-h"><span>' + x[1] + '</span><b class="' + (alto ? 'cc-alto' : '') + '">' + v + ' / ' + max + '</b></div>' +
      '<span class="cc-meter" role="meter" aria-label="' + x[1] + '" aria-valuenow="' + v + '" aria-valuemin="0" aria-valuemax="' + max + '"><span class="' + (alto ? 'cc-alto' : '') + '" style="width:' + pct + '%"></span></span></div>';
  }).join('');
  var act = [];
  if (u.ULT_OT) act.push([u.ULT_OT, 'Última OT creada · ' + K.pl(u.OT || 0, 'OT', 'OT') + ' en total']);
  if (u.ULT_CHECKLIST) act.push([u.ULT_CHECKLIST, 'Último checklist ejecutado · ' + (u.CHECKLISTS || 0) + ' en total']);
  if (u.ULT_ACTIVO) act.push([u.ULT_ACTIVO, 'Último activo cargado · ' + (u.ACTIVOS || 0) + ' en total']);
  act.sort(function (a, b) { return a[0] < b[0] ? 1 : -1; });
  var usados = mods(demo.MODULOS).map(function (m) {
    var usado = (m === 'MANTENIMIENTO' && u.ACTIVOS) || (m === 'OT' && u.OT) || (m === 'PLANIFICACION' && u.PROGRAMACIONES) || (m === 'INSPECCION' && u.CHECKLISTS) || (m === 'INVENTARIO' && u.REPUESTOS);
    var medible = ['MANTENIMIENTO', 'OT', 'PLANIFICACION', 'INSPECCION', 'INVENTARIO'].indexOf(m) >= 0;
    return medible ? chip(nombreMod(m) + (usado ? '' : ' · sin usar'), usado ? 'cy' : 'gr') : chip(nombreMod(m), 'gr');
  }).join('');
  var pm = S.ini.permisos;
  var acciones = '';
  if (pm.demos && demo.ESTADO !== 'FINALIZADA') {
    acciones = st.ext ? '<div class="cc-acc"><span class="cc-hint">Extender</span>' + [3, 7, 14].map(function (x) { return '<button type="button" class="cp-btn cp-sec cp-sm" data-a="extok" data-v="' + x + '">+' + x + ' días</button>'; }).join('') +
        '<button type="button" class="cp-btn cp-ghost cp-sm" data-a="extx">Cancelar</button></div>'
      : '<div class="cc-acc"><button type="button" class="cp-btn cp-sec cp-sm" data-a="ext">' + ic('more') + 'Extender demo</button>' +
        '<button type="button" class="cp-btn cp-out cp-sm" data-a="cred"' + (st.busy ? ' disabled' : '') + '>' + ic('send') + 'Reenviar credenciales</button></div>';
  }
  var cuerpo = '<div class="cc-mini"><div><small>Inicio</small><b>' + dmy(demo.INICIO) + '</b></div><div><small>Expira</small><b>' + dmy(demo.EXPIRA) + '</b></div>' +
    '<div><small>Último acceso</small><b>' + (demo.ULT_ACCESO ? dmyh(demo.ULT_ACCESO) : 'Aún no entra') + '</b></div></div>' +
    '<div><div class="cc-acc" style="justify-content:space-between;margin-bottom:8px"><span class="cc-sub">Uso vs. límites</span><span class="cc-hint">Usuario: ' + esc(demo.USUARIO_CORREO) + (demo.PENDIENTE_CLAVE ? ' · clave temporal sin cambiar' : '') + '</span></div><div class="cc-uso">' + usoH + '</div></div>' +
    '<div style="display:flex;flex-direction:column;gap:8px"><span class="cc-sub">Actividad en la demo</span><div class="cc-wrap">Módulos: ' + (usados || '—') + '</div>' +
    (act.length ? '<ul class="cc-tl" style="gap:0">' + act.map(function (a) { return '<li style="display:flex;gap:10px;padding:7px 0;border-top:1px solid var(--line);font-size:13px"><span style="width:96px;flex:0 0 96px;color:var(--muted)">' + dmyh(a[0]).slice(0, 11) + '</span><span>' + esc(a[1]) + '</span></li>'; }).join('') + '</ul>' : '<span class="cc-hint">Todavía no hay registros en la empresa demo.</span>') + '</div>' +
    (pm.demos && vencida ? '<div class="cc-info cc-wa">' + ic('timer') + '<span>El acceso a la demo está suspendido; los datos se conservan. Extiéndela para reactivarlo.</span></div>' : '') + acciones;
  return sec('demo', 'rocket', 'put', 'Demo', ch + flag, cuerpo, st);
}

/* Propuesta: la vigente arriba, las versiones abajo */
function secProp(st, d) {
  var p = propVigente(d), pm = S.ini.permisos, neta = K.fN(mensualNeta(p.MENSUAL_UF, p.DESCUENTO_PCT), 2);
  var caps = [['LIM_USUARIOS', 'usuarios'], ['LIM_ACTIVOS', 'activos'], ['LIM_PLANTAS', 'plantas'], ['LIM_BODEGAS', 'bodegas'], ['LIM_GB', 'GB']].filter(function (c) { return p[c[0]] != null; })
    .map(function (c) { return K.fN(p[c[0]]) + ' ' + c[1]; }).join(' · ');
  var cuerpo = '<div class="cc-mods">' + mods(p.MODULOS).map(function (m) { return chip(nombreMod(m), 'pu'); }).join('') + '</div>' +
    (caps ? '<div class="cc-nota" style="color:var(--cc-lab);font-size:13px">' + caps + '</div>' : '') +
    '<dl class="cc-dl2"><dt>Implementación</dt><dd>' + uf(p.IMPLEMENTACION_UF) + '</dd>' +
    '<dt>Mensualidad' + (p.DESCUENTO_PCT ? ' (' + uf(p.MENSUAL_UF) + ' − ' + K.fN(p.DESCUENTO_PCT) + ' %)' : '') + '</dt><dd>' + neta + ' UF</dd>' +
    '<dt>Vigencia</dt><dd>' + p.VIGENCIA_MESES + ' meses</dd><dt class="cc-tot">Total del período</dt><dd class="cc-tot">' + uf(p.TOTAL_UF) + '</dd></dl>' +
    '<div class="cc-wrap">' + ic('pdf', 18) + 'Propuesta v' + p.VERSION + ' · ' + (p.ENVIADA ? 'enviada el ' + dmy(p.ENVIADA) : 'creada el ' + dmy(p.CREADA) + ' · sin enviar') + '</div>' +
    '<div class="cc-acc">' + (p.TIENE_PDF ? '<button type="button" class="cp-btn cp-out cp-sm" data-a="pdf" data-t="propuesta" data-id="' + p.ID + '">' + ic('eye') + 'Ver PDF</button>' : '') +
    (pm.propuestas && ['PROPUESTA', 'NEGOCIACION', 'DEMO', 'CONTACTADO', 'CALIFICADO', 'NUEVO'].indexOf(d.lead.ESTADO) >= 0 ? '<button type="button" class="cp-btn cp-sec cp-sm" data-a="prop" data-v="copia">' + ic('copy') + 'Nueva versión</button>' : '') +
    (pm.propuestas && p.ESTADO === 'BORRADOR' ? '<span class="cc-sp"></span><button type="button" class="cp-btn cp-pri cp-sm" data-a="propenv" data-id="' + p.ID + '"' + (F.busy ? ' disabled' : '') + '>' + ic('send') + 'Enviar propuesta</button>' : '') + '</div>' +
    (d.propuestas.length > 1 ? '<div><span class="cc-sub">Versiones</span>' + d.propuestas.map(function (x) {
      return '<div class="cc-li" style="grid-template-columns:40px 96px 120px minmax(0,1fr) auto"><b>v' + x.VERSION + '</b><span>' + dmy(x.ENVIADA || x.CREADA) + '</span>' + chip(x.ESTADO, PT[x.ESTADO] || 'gr') +
        '<span class="cc-m">' + esc(x.NOMBRE_PLAN) + ' · ' + uf(x.TOTAL_UF) + '</span>' + (x.TIENE_PDF ? '<button type="button" class="cc-lnk" data-a="pdf" data-t="propuesta" data-id="' + x.ID + '">Ver PDF</button>' : '<span></span>') + '</div>';
    }).join('') + '</div>' : '');
  return sec('prop', 'quote', 'put', 'Propuesta', '<small>' + esc(p.NOMBRE_PLAN) + ' · ' + neta + ' UF/mes</small>' + chip(p.ESTADO, PT[p.ESTADO] || 'gr'), cuerpo, st);
}
function mensualNeta(m, d) { return Math.round((+m || 0) * (100 - (+d || 0))) / 100; }

/* Contrato: estado, versiones y evidencia de la firma */
function secCont(st, d) {
  var c = contUltimo(d), pm = S.ini.permisos;
  var orden = ['BORRADOR', 'ENVIADO', 'VISUALIZADO', 'FIRMADO'], i = orden.indexOf(c.ESTADO);
  var barra = c.ESTADO === 'ANULADO' ? '' : '<ol class="cc-cstep" aria-label="Estado del contrato">' + orden.map(function (e, k) { return '<li class="' + (k < i || c.ESTADO === 'FIRMADO' ? 'cc-ok' : k === i ? 'cc-cy' : '') + '">' + e + '</li>'; }).join('') + '</ol>';
  var cuerpo = barra;
  if (c.ESTADO === 'VISUALIZADO') cuerpo += '<div class="cc-info" style="margin:0;font-size:13px;font-weight:600">' + ic('eye', 20) + '<span>Visualizado por el cliente el ' + dmyh(c.VISUALIZADO) + '</span></div>';
  if (c.ESTADO === 'ENVIADO' || c.ESTADO === 'VISUALIZADO') cuerpo += '<div class="cc-nota">Enlace personal de firma enviado a ' + esc(d.lead.CORREO) + ' · vence el ' + dmyh(c.TOKEN_EXPIRA) + '</div>';
  if (c.ESTADO === 'FIRMADO') cuerpo += '<dl class="cc-dl"><dt>Firmó</dt><dd>' + esc(c.FIRMANTE) + ' · ' + esc(c.FIRMANTE_RUT) + '</dd><dt>Fecha</dt><dd>' + dmyh(c.FIRMADO) + '</dd><dt>IP</dt><dd>' + esc(c.FIRMA_IP || '—') + '</dd>' +
    '<dt>SHA-256 contrato</dt><dd style="font-family:Consolas,monospace;font-size:11.5px">' + esc(c.PDF_SHA256 || '') + '</dd><dt>SHA-256 firmado</dt><dd style="font-family:Consolas,monospace;font-size:11.5px">' + esc(c.PDF_FIRMADO_SHA256 || '') + '</dd></dl>';
  cuerpo += '<div><span class="cc-sub">Versiones</span>' + d.contratos.map(function (x, k) {
    return '<div class="cc-li"><b' + (k ? ' style="color:var(--muted)"' : '') + '>v' + x.VERSION + '</b><span>' + dmy(x.CREADO) + '</span>' + chip(x.ESTADO, CT[x.ESTADO] || 'gr') +
      '<span class="cc-m">' + (x.ESTADO === 'ANULADO' ? esc(x.MOTIVO_ANULACION || '') : k === 0 ? 'Actual' : '') + '</span>' +
      '<button type="button" class="cc-lnk" data-a="pdf" data-t="' + (x.ESTADO === 'FIRMADO' ? 'firmado' : 'contrato') + '" data-id="' + x.ID + '">Ver PDF</button></div>';
  }).join('') + '</div>';
  if (pm.propuestas && (c.ESTADO === 'ENVIADO' || c.ESTADO === 'VISUALIZADO' || c.ESTADO === 'BORRADOR')) {
    cuerpo += st.anular === c.ID
      ? '<div class="cc-perd"><b>¿Por qué se anula el contrato v' + c.VERSION + '?</b><input class="cp-inp" data-pv="motivoAn" value="' + esc(st.motivoAn) + '" placeholder="Por ejemplo: corrección de razón social" aria-label="Motivo de la anulación">' +
        '<div class="cc-acc"><button type="button" class="cp-btn cp-ghost cp-sm" data-a="anx">Cancelar</button><span class="cc-sp"></span><button type="button" class="cp-btn cp-dan cp-sm" data-a="anok" data-id="' + c.ID + '">Confirmar: anular contrato</button></div></div>'
      : '<div class="cc-acc"><span class="cc-sp"></span><button type="button" class="cp-btn cp-dano cp-sm" data-a="anular" data-id="' + c.ID + '">' + ic('block') + 'Anular contrato</button></div>';
  }
  return sec('cont', 'sign', 'wat', 'Contrato', '<small>Versión ' + c.VERSION + '</small>' + chip(c.ESTADO, CT[c.ESTADO] || 'gr'), cuerpo, st);
}

/* Reuniones agendadas y realizadas */
function secReu(st, d) {
  var lug = { VIDEO: ['video', 'Videollamada'], PRESENCIAL: ['pin', 'Presencial'], TELEFONO: ['phone', 'Teléfono'] };
  var pend = d.reuniones.filter(function (r) { return r.ESTADO === 'AGENDADA'; }).length;
  var cuerpo = d.reuniones.map(function (r) {
    var paso = dt(r.INICIO) && new Date(dt(r.INICIO).getTime() + r.DURACION * 6e4) < ahora();
    var ch = r.ESTADO === 'REALIZADA' ? chip('REALIZADA', 'ok') : r.ESTADO === 'CANCELADA' ? chip('CANCELADA', 'gr') : paso ? chip('SIN REGISTRAR', 'wa') : chip('AGENDADA', 'bl');
    return '<div class="cc-li" style="grid-template-columns:28px minmax(0,1fr) auto auto"><span style="color:var(--cc-lab)">' + ic(lug[r.LUGAR][0]) + '</span>' +
      '<span class="cc-c2"><b style="font-size:13px">' + dmyh(r.INICIO) + ' · ' + r.DURACION + ' min</b><span>' + esc(r.RESUMEN || r.MOTIVO || lug[r.LUGAR][1]) + '</span></span>' + ch +
      (r.ESTADO === 'AGENDADA' && paso && S.ini.permisos.leads ? '<button type="button" class="cp-btn cp-sec cp-sm" data-a="reu" data-f="registrar" data-id="' + r.ID + '">Registrar</button>'
        : r.ESTADO === 'AGENDADA' && r.ENLACE ? '<a class="cp-btn cp-out cp-sm" href="' + esc(r.ENLACE) + '" target="_blank" rel="noopener">' + ic('open') + 'Unirme</a>' : '<span></span>') + '</div>';
  }).join('');
  return sec('reu', 'users', 'cyt', 'Reuniones', '<small>' + K.pl(d.reuniones.length, 'reunión', 'reuniones') + '</small>' + (pend ? chip(pend + ' agendada' + (pend > 1 ? 's' : ''), 'bl') : ''), cuerpo, st);
}

/* Línea de tiempo con «Agregar actividad» en línea */
function secTimeline(st, d) {
  var pm = S.ini.permisos, ok = st.txt.trim().length > 0;
  var add = pm.leads ? '<div class="cc-add"><div class="cc-mods" role="group" aria-label="Tipo de actividad">' + TIPOS.map(function (t) {
      return '<button type="button" class="cc-tipo" aria-pressed="' + (st.tipo === t[0]) + '" data-a="tipo" data-v="' + t[0] + '">' + ic(t[1], 16) + t[2] + '</button>';
    }).join('') + '</div><div class="cc-add-f"><input class="cp-inp" data-pv="txt" data-live="1" value="' + esc(st.txt) + '" placeholder="Qué pasó y qué sigue…" aria-label="Detalle de la actividad">' +
    '<button type="button" class="cp-btn cp-sec" data-a="act"' + (ok && !st.busy ? '' : ' disabled') + '>Registrar</button></div></div>' : '';
  var I = { web: 'web', mail: 'mail', person: 'person', rocket: 'rocket', quote: 'quote', sign: 'sign', eye: 'eye', check: 'ok', clock: 'clock', flag: 'flag', send: 'send', x: 'block', users: 'users', phone: 'phone', note: 'note' };
  var tl = '<ol class="cc-tl">' + d.actividad.map(function (a) {
    var man = a.TIPO !== 'SISTEMA';
    return '<li><span class="cc-tl-d">' + corto(a.FECHA) + '</span><span class="cc-tl-c"><span class="cc-tl-i' + (man ? ' cc-man' : '') + '">' + ic(I[a.ICONO] || (man ? 'note' : 'flag'), 16) + '</span></span>' +
      '<span class="cc-tl-t"><b>' + esc(a.TITULO) + '</b>' + (a.DETALLE ? '<span>' + esc(a.DETALLE) + '</span>' : '') + '<small>' + esc(a.QUIEN) + ' · ' + hhmm(a.FECHA) + '</small></span></li>';
  }).join('') + '</ol>';
  return '<section style="display:flex;flex-direction:column;gap:12px;padding:6px 2px 0"><h3 class="cc-tl-h">Actividad</h3>' + add + tl + '</section>';
}

/* Barra inferior: perdido (rojo) · contorno · UNA acción morada según la etapa */
function pie(st, d, idx) {
  var l = d.lead, pm = S.ini.permisos, pv = propVigente(d), ct = contUltimo(d);
  if (st.perd) {
    return '<div class="cc-perd"><b>¿Por qué se pierde este lead?</b><div class="cc-mods">' + MOTIVOS.map(function (m) {
      return '<button type="button" class="cc-mot" aria-pressed="' + (st.motivo === m) + '" data-a="mot" data-v="' + esc(m) + '">' + esc(m) + '</button>';
    }).join('') + '</div></div><button type="button" class="cp-btn cp-ghost" data-a="perdx">Cancelar</button><span class="cc-sp" style="flex:1"></span>' +
      '<button type="button" class="cp-btn cp-dan" data-a="perdok"' + (st.motivo && !st.busy ? '' : ' disabled') + '>Confirmar: marcar perdido</button>';
  }
  var pri = null, sec2 = null;
  if (l.ESTADO === 'PERDIDO') { if (pm.leads) pri = ['estado', 'CONTACTADO', 'flag', 'Reabrir lead']; }
  else if (l.ESTADO === 'CONCRETADO') { if (ct) sec2 = ['pdf', 'firmado', 'pdf', 'Ver contrato firmado', ct.ID]; }
  else if (idx === 0) {
    if (pm.demos && !d.demo) pri = ['demo', '', 'rocket', 'Crear demo'];
    else if (pm.propuestas) pri = ['prop', 'nueva', 'quote', 'Crear propuesta'];
    if (pri && pri[0] === 'demo' && pm.propuestas) sec2 = ['prop', 'nueva', 'quote', 'Crear propuesta'];
  } else if (idx === 1) {
    if (pm.propuestas) pri = ['prop', 'nueva', 'quote', 'Crear propuesta'];
  } else if (idx === 2) {
    if (pv && pv.TIENE_PDF) sec2 = ['pdf', 'propuesta', 'pdf', 'Ver propuesta', pv.ID];
    if (pm.propuestas && pv && pv.ESTADO !== 'BORRADOR') pri = ['contrato', '', 'sign', 'Generar contrato'];
  } else if (idx === 3 && ct) {
    sec2 = ['pdf', ct.ESTADO === 'FIRMADO' ? 'firmado' : 'contrato', 'pdf', 'Ver contrato', ct.ID];
    if (pm.propuestas && (ct.ESTADO === 'ENVIADO' || ct.ESTADO === 'VISUALIZADO')) pri = ['reenviar', '', 'send', 'Reenviar para firma'];
    else if (pm.propuestas && ct.ESTADO === 'ANULADO') pri = ['contrato', '', 'sign', 'Generar contrato'];
  }
  var dis = st.busy ? ' disabled' : '';
  return (pm.leads && l.ESTADO !== 'PERDIDO' && l.ESTADO !== 'CONCRETADO' ? '<button type="button" class="cp-btn cp-dano" data-a="perd">Marcar perdido</button>' : '') +
    '<div class="cp-r">' +
    (sec2 ? '<button type="button" class="cp-btn cp-out" data-a="' + sec2[0] + '" data-v="' + sec2[1] + '" data-t="' + sec2[1] + '"' + (sec2[4] ? ' data-id="' + sec2[4] + '"' : '') + '>' + ic(sec2[2]) + sec2[3] + '</button>' : '') +
    (pri ? '<button type="button" class="cp-btn cp-pri" data-a="' + pri[0] + '" data-v="' + pri[1] + '"' + dis + '>' + ic(pri[2]) + (st.busy ? 'Procesando…' : pri[3]) + '</button>' : '') + '</div>';
}

/* ---------------------------------------------------------------- crear demo */
function abrirDemo() {
  var lim = {}; Object.keys(S.ini.demo.limites).forEach(function (k) { lim[k] = S.ini.demo.limites[k]; });
  var l = F.data.lead, inter = mods(l.INTERESES).filter(function (m) { return nombreMod(m) !== m; });
  F.f = { dias: S.ini.demo.dias, lim: lim, mods: inter.length ? inter : ['MANTENIMIENTO', 'OT', 'PLANIFICACION', 'INSPECCION'] };
  F.modo = 'demo'; K.Panel.paint();
}
function vDemo(st, d) {
  var l = d.lead, f = st.f;
  var b = '<button type="button" class="cc-lnk" data-a="volver" style="align-self:flex-start;display:inline-flex;align-items:center;gap:4px">' + ic('back') + 'Volver a la ficha</button>' +
    '<div class="cp-fld"><span class="cp-lb">Duración</span><div class="cc-acc"><div class="cc-seg" role="group" aria-label="Duración">' + [7, 14, 30].map(function (n) {
      return '<button type="button" aria-pressed="' + (+f.dias === n) + '" data-a="ddias" data-v="' + n + '">' + n + ' días</button>';
    }).join('') + '</div><input class="cp-inp" style="width:90px" type="number" min="1" max="30" data-pv="f.dias" value="' + esc(f.dias) + '" aria-label="Días"><span class="cc-hint">Vence el ' + dmy(K.addD(hoyIso(), +f.dias || 0)) + '</span></div></div>' +
    '<div class="cp-fld"><span class="cp-lb">Plan demo</span><input class="cp-inp" value="Demo · acotada, no productiva" disabled></div>' +
    '<div class="cp-fld"><span class="cp-lb">Módulos</span>' + modChips(f.mods, 'dmod') + '</div>' +
    '<div class="cp-fld"><span class="cp-lb">Límites <small>· precargados desde la configuración comercial</small></span><div class="cc-grid4">' + LIMS.map(function (x) {
      return '<div class="cp-fld"><label for="dl_' + x[0] + '">' + x[1] + '</label><input class="cp-inp" id="dl_' + x[0] + '" type="number" min="' + (['usuarios', 'activos', 'bodegas', 'plantas'].indexOf(x[0]) >= 0 ? 1 : 0) + '" data-pv="lim.' + x[0] + '" value="' + esc(f.lim[x[0]]) + '"></div>';
    }).join('') + '</div><span class="cc-hint">Usuarios, activos y plantas los hace cumplir SIGMA; OT, programaciones, checklists y repuestos se muestran como consumo.</span></div>' +
    '<div class="cp-fld"><span class="cp-lb">Usuario principal</span><div class="cc-part"><span>' + ic('person', 20) + '</span><span class="cc-tx"><b>' + esc(l.CONTACTO) + '</b><span>' + esc(l.CORREO) + ' · Administrador de su empresa demo</span></span></div></div>' +
    '<div class="cc-info" style="margin:0">' + ic('light') + '<span>Se creará la empresa «' + esc(l.EMPRESA) + '» con una planta y una bodega, el usuario de ' + esc(l.CONTACTO.split(' ')[0]) +
    ' con una clave temporal (deberá cambiarla al entrar) y se enviarán las credenciales a ' + esc(l.CORREO) + '.</span></div>';
  return { w: 'c', s: esc(l.CODIGO) + ' · ' + esc(l.EMPRESA), t: 'Crear demo', b: b,
    f: '<button type="button" class="cp-btn cp-ghost" data-a="volver">Cancelar</button><div class="cp-r"><button type="button" class="cp-btn cp-pri" data-a="demook"' + (st.busy ? ' disabled' : '') + '>' + ic('rocket') + (st.busy ? 'Creando la demo…' : 'Crear demo y enviar credenciales') + '</button></div>' };
}

/* ---------------------------------------------------------------- crear propuesta */
function abrirProp(base) {
  var d = F.data, l = d.lead, p = base === 'copia' ? propVigente(d) : null, planes = S.ini.planes || [];
  var pre = F.precarga || {};
  var est = planes[1] || planes[0] || {};
  F.f = p ? { tipo: p.TIPO, plan: p.PLAN_COMERCIAL || est.ID, nombre: p.NOMBRE_PLAN, mods: mods(p.MODULOS), usuarios: p.LIM_USUARIOS, activos: p.LIM_ACTIVOS, plantas: p.LIM_PLANTAS,
              bodegas: p.LIM_BODEGAS, gb: p.LIM_GB, implementacion: p.IMPLEMENTACION_UF, mensual: p.MENSUAL_UF, descuento: p.DESCUENTO_PCT, vigencia: p.VIGENCIA_MESES, condiciones: p.CONDICIONES || '' }
    : { tipo: 'ESTANDAR', plan: est.ID, nombre: '', mods: mods(est.MODULOS), usuarios: est.LIM_USUARIOS, activos: est.LIM_ACTIVOS, plantas: est.LIM_PLANTAS, bodegas: null, gb: est.LIM_GB,
        implementacion: 30, mensual: est.MENSUAL_UF, descuento: 0, vigencia: 12, condiciones: '' };
  if (pre.descuento != null && pre.descuento !== '') F.f.descuento = +pre.descuento;
  if (pre.vigencia) F.f.vigencia = +pre.vigencia;
  if (pre.mods && pre.mods.length) { F.f.mods = pre.mods.slice(); if (F.f.tipo === 'ESTANDAR') F.f.tipo = 'PERSONALIZADA'; }
  if (F.f.tipo === 'PERSONALIZADA' && !F.f.nombre) F.f.nombre = 'Plan ' + l.EMPRESA;
  F.precarga = null; F.modo = 'prop'; K.Panel.paint();
}
function totalProp(f) { var neta = mensualNeta(f.mensual, f.descuento); return { neta: neta, total: Math.round(((+f.implementacion || 0) + neta * (+f.vigencia || 0)) * 100) / 100 }; }
function vProp(st, d) {
  var l = d.lead, f = st.f, planes = S.ini.planes || [], est = f.tipo === 'ESTANDAR';
  var num = function (k, t, o) { o = o || {}; return '<div class="cp-fld"><label for="pp_' + k + '">' + t + '</label><input class="cp-inp" id="pp_' + k + '" type="number" step="' + (o.step || 'any') + '" min="0" data-pv="f.' + k + '" data-live="1" value="' + (f[k] == null ? '' : esc(f[k])) + '"' + (o.ph ? ' placeholder="' + o.ph + '"' : '') + '></div>'; };
  var b = '<button type="button" class="cc-lnk" data-a="volver" style="align-self:flex-start;display:inline-flex;align-items:center;gap:4px">' + ic('back') + 'Volver a la ficha</button>' +
    '<div class="cc-seg cc-full" role="group" aria-label="Tipo de plan"><button type="button" aria-pressed="' + est + '" data-a="ptipo" data-v="ESTANDAR">Plan estándar</button><button type="button" aria-pressed="' + !est + '" data-a="ptipo" data-v="PERSONALIZADA">Plan personalizado</button></div>';
  if (est) {
    b += '<div class="cc-planes">' + planes.map(function (p) {
      return '<button type="button" class="cc-plan" aria-pressed="' + (String(f.plan) === String(p.ID)) + '" data-a="pplan" data-v="' + p.ID + '"><b>' + esc(p.NOMBRE) + '</b><strong>' + uf(p.MENSUAL_UF) + '<small style="font-size:11px;font-weight:600;color:var(--muted)"> /mes</small></strong>' +
        '<span>' + (p.LIM_USUARIOS != null ? K.fN(p.LIM_USUARIOS) + ' usuarios · ' + K.fN(p.LIM_ACTIVOS) + ' activos' : 'Usuarios y activos sin tope') + '</span><span>' + esc(p.DESCRIPCION || '') + '</span></button>';
    }).join('') + '</div><div class="cc-mods">' + f.mods.map(function (m) { return chip(nombreMod(m), 'pu'); }).join('') + '</div>';
  } else {
    b += '<div class="cp-fld"><label for="pp_nombre">Nombre del plan</label><input class="cp-inp" id="pp_nombre" data-pv="f.nombre" value="' + esc(f.nombre) + '"></div>' +
      '<div class="cp-fld"><span class="cp-lb">Módulos</span>' + modChips(f.mods, 'pmod') + '</div>' +
      '<div class="cp-fld"><span class="cp-lb">Límites <small>· vacío = sin tope</small></span><div class="cc-grid3">' + num('usuarios', 'Usuarios', { step: 1 }) + num('activos', 'Activos', { step: 1 }) + num('plantas', 'Plantas', { step: 1 }) +
      num('bodegas', 'Bodegas', { step: 1 }) + num('gb', 'Almacenamiento (GB)', { step: 1 }) + '</div></div>';
  }
  b += '<div class="cp-fld"><span class="cp-lb">Precio <small>· UF más IVA</small></span><div class="cc-grid2">' + num('implementacion', 'Implementación (UF, pago único)') + (est ? '<div class="cp-fld"><label>Mensualidad de lista</label><input class="cp-inp" value="' + uf(f.mensual, 2) + '" disabled></div>' : num('mensual', 'Mensualidad (UF)')) +
    num('descuento', 'Descuento (%)', { step: 0.5 }) + '<div class="cp-fld"><label for="pp_vig">Vigencia</label>' + K.combo('ccVig', [{ id: '6', n: '6 meses' }, { id: '12', n: '12 meses' }, { id: '24', n: '24 meses' }, { id: '36', n: '36 meses' }], String(f.vigencia || 12), { etiqueta: 'Vigencia' }) + '</div></div></div>' +
    '<div class="cp-fld"><label for="pp_cond">Condiciones comerciales <small>· opcional, se suman a las estándar</small></label><textarea class="cp-inp" id="pp_cond" data-pv="f.condiciones" placeholder="Por ejemplo: capacitación adicional en terreno incluida">' + esc(f.condiciones) + '</textarea></div>';
  var t = totalProp(f);
  b += '<div class="cc-total"><div><small>Mensualidad con descuento</small><b id="ccNeta" style="font-variant-numeric:tabular-nums">' + K.fN(t.neta, 2) + ' UF</b></div>' +
    '<div><small>Total del período (' + (f.vigencia || 12) + ' meses + implementación)</small><strong id="ccTot">' + K.fN(t.total, 2) + ' UF</strong> <small id="ccClp">' + (clp(t.total) ? '≈ ' + clp(t.total) + ' + IVA' : '') + '</small></div></div>';
  return { w: 'c', s: esc(l.CODIGO) + ' · ' + esc(l.EMPRESA), t: 'Crear propuesta', b: b,
    f: '<button type="button" class="cp-btn cp-ghost" data-a="volver">Cancelar</button><div class="cp-r"><button type="button" class="cp-btn cp-out" data-a="propok" data-v="0"' + (st.busy ? ' disabled' : '') + '>Guardar borrador</button>' +
       '<button type="button" class="cp-btn cp-pri" data-a="propok" data-v="1"' + (st.busy ? ' disabled' : '') + '>' + ic('send') + (st.busy ? 'Generando…' : 'Enviar propuesta') + '</button></div>' };
}
function actualizarTotal() {
  if (!F || F.modo !== 'prop') return;
  var t = totalProp(F.f), a = $('#ccNeta'), b = $('#ccTot'), c = $('#ccClp');
  if (a) a.textContent = K.fN(t.neta, 2) + ' UF'; if (b) b.textContent = K.fN(t.total, 2) + ' UF'; if (c) c.textContent = clp(t.total) ? '≈ ' + clp(t.total) + ' + IVA' : '';
}

/* ---------------------------------------------------------------- reuniones */
function abrirReu(fase, id) {
  var l = F.data.lead;
  if (fase === 'agendar') {
    var m = K.addD(hoyIso(), 1);
    F.f = { fase: 'agendar', fecha: m, hora: '10:00', dur: 30, lugar: 'VIDEO', enlace: '', direccion: '', motivo: 'Revisar la demo y conversar la propuesta',
            parts: [{ n: l.CONTACTO, c: l.CORREO, on: true }], nuevo: '' };
    call('NuevaSala', { empresa: l.EMPRESA }).then(function (r) { if (F && F.modo === 'reu') { F.f.enlace = r.enlace; K.Panel.paint(); } }).catch(K.toastError);
  } else {
    F.f = { fase: 'registrar', reunion: +id, notas: '', resumen: '', acuerdos: [{ t: '', ok: false }], objecion: '', proxTipo: 'LLAMADA', proxTxt: '', proxFecha: K.addD(hoyIso(), 2), proxHora: '10:00',
            descuento: '', vigencia: '', mods: [] };
  }
  F.modo = 'reu'; K.Panel.paint();
}
function vReu(st, d) {
  var l = d.lead, f = st.f;
  if (f.fase === 'registrar') return vReuReg(st, d);
  var lug = [['VIDEO', 'video', 'Videollamada'], ['PRESENCIAL', 'pin', 'Presencial'], ['TELEFONO', 'phone', 'Teléfono']];
  var dondeH = f.lugar === 'VIDEO'
    ? '<div class="cp-fld"><label for="rr_enl">Enlace de la sala <small>· Jitsi Meet, gratis y sin cuenta para el cliente; puedes pegar uno de Meet o Zoom</small></label><div class="cc-add-f">' +
      '<input class="cp-inp" id="rr_enl" data-pv="f.enlace" value="' + esc(f.enlace) + '" placeholder="Generando sala…"><button type="button" class="cp-btn cp-out cp-sm" data-a="sala">' + ic('refresh') + 'Nueva sala</button>' +
      (f.enlace ? '<a class="cp-btn cp-plain cp-sm" href="' + esc(f.enlace) + '" target="_blank" rel="noopener">' + ic('open') + 'Abrir</a>' : '') + '</div>' +
      '<span class="cc-hint">Quien organiza abre la sala desde el navegador. La sala vive fuera de SIGMA: aquí queda el enlace y, después, el registro de la reunión.</span></div>'
    : f.lugar === 'PRESENCIAL' ? '<div class="cp-fld"><label for="rr_dir">Dirección</label><input class="cp-inp" id="rr_dir" data-pv="f.direccion" value="' + esc(f.direccion) + '" placeholder="Calle, número, comuna"></div>'
    : '<div class="cc-part">' + ic('phone', 20) + '<span class="cc-tx"><b>' + esc(l.TELEFONO || 'Sin teléfono registrado') + '</b><span>' + esc(l.CONTACTO) + '</span></span></div>';
  var parts = f.parts.map(function (p, i) {
    return '<label class="cc-part"><input type="checkbox" data-a="ptog" data-i="' + i + '"' + (p.on ? ' checked' : '') + '><span class="cc-tx"><b>' + esc(p.n || p.c) + '</b><span>' + esc(p.c) + '</span></span></label>';
  }).join('');
  var fin = f.hora ? (function () { var p = f.hora.split(':'), m = +p[0] * 60 + +p[1] + +f.dur; return (m / 60 < 10 ? '0' : '') + Math.floor(m / 60) + ':' + (m % 60 < 10 ? '0' : '') + m % 60; })() : '';
  var b = '<button type="button" class="cc-lnk" data-a="volver" style="align-self:flex-start;display:inline-flex;align-items:center;gap:4px">' + ic('back') + 'Volver a la ficha</button>' +
    '<div class="cc-grid3"><div class="cp-fld"><span class="cp-lb">Fecha</span>' + K.fecha('r.fecha', f.fecha, { etiqueta: 'Fecha de la reunión' }) + '</div>' +
    '<div class="cp-fld"><span class="cp-lb">Hora</span>' + K.combo('ccRHora', HORAS, f.hora, { etiqueta: 'Hora' }) + '</div>' +
    '<div class="cp-fld"><span class="cp-lb">Duración</span><div class="cc-seg" role="group" aria-label="Duración">' + [30, 45, 60].map(function (n) { return '<button type="button" aria-pressed="' + (+f.dur === n) + '" data-a="rdur" data-v="' + n + '">' + n + '</button>'; }).join('') + '</div></div></div>' +
    '<div class="cp-fld"><span class="cp-lb">Participantes <small>· recibes copia como organizador</small></span><div style="display:flex;flex-direction:column;gap:6px">' + parts + '</div>' +
    '<div class="cc-add-f"><input class="cp-inp" data-pv="f.nuevo" value="' + esc(f.nuevo) + '" placeholder="Agregar por correo (nombre@empresa.cl)" aria-label="Agregar participante"><button type="button" class="cp-btn cp-out cp-sm" data-a="padd">' + ic('plus') + 'Agregar</button></div></div>' +
    '<div class="cp-fld"><span class="cp-lb">Dónde</span><div class="cc-seg cc-full" role="group" aria-label="Dónde">' + lug.map(function (x) { return '<button type="button" aria-pressed="' + (f.lugar === x[0]) + '" data-a="rlug" data-v="' + x[0] + '">' + ic(x[1]) + x[2] + '</button>'; }).join('') + '</div></div>' + dondeH +
    '<div class="cp-fld"><label for="rr_mot">Motivo</label><input class="cp-inp" id="rr_mot" data-pv="f.motivo" value="' + esc(f.motivo) + '"></div>' +
    '<div class="cp-fld"><span class="cp-lb">Vista previa del correo</span><div class="cc-correo"><b>Reunión SIGMA · ' + esc(l.EMPRESA) + '</b><br>' + esc(l.CONTACTO.split(' ')[0]) + ', te invitamos a conversar sobre: ' + esc(f.motivo || 'SIGMA') + '.<br>' +
    '<b>Cuándo:</b> ' + (f.fecha ? K.fDL(f.fecha) : '—') + ' · ' + esc(f.hora || '') + ' a ' + fin + '<br><b>Dónde:</b> ' + (f.lugar === 'VIDEO' ? 'Jitsi Meet (desde el navegador)' : f.lugar === 'PRESENCIAL' ? esc(f.direccion || '—') : 'Por teléfono') +
    '<br><span class="cc-hint">Adjunta la invitación .ics para su calendario.</span></div></div>';
  return { w: 'c', s: esc(l.CODIGO) + ' · ' + esc(l.EMPRESA), t: 'Agendar reunión', b: b,
    f: '<button type="button" class="cp-btn cp-ghost" data-a="volver">Cancelar</button><div class="cp-r"><button type="button" class="cp-btn cp-pri" data-a="reuok"' + (st.busy ? ' disabled' : '') + '>' + ic('send') + (st.busy ? 'Enviando…' : 'Enviar invitación') + '</button></div>' };
}
function vReuReg(st, d) {
  var l = d.lead, f = st.f, r = d.reuniones.filter(function (x) { return x.ID === f.reunion; })[0] || {};
  var b = '<button type="button" class="cc-lnk" data-a="volver" style="align-self:flex-start;display:inline-flex;align-items:center;gap:4px">' + ic('back') + 'Volver a la ficha</button>' +
    '<div class="cc-info" style="margin:0">' + ic('event') + '<span>Reunión del ' + dmyh(r.INICIO) + ' · ' + (r.DURACION || '') + ' min · ' + esc(r.MOTIVO || '') + '</span></div>' +
    '<div class="cp-fld"><label for="rg_not">Notas o transcripción pegada <small>· opcional; si pegas una transcripción, avisa antes a los participantes</small></label><textarea class="cp-inp" id="rg_not" data-pv="f.notas" style="min-height:110px">' + esc(f.notas) + '</textarea></div>' +
    '<div class="cp-fld"><label for="rg_res">Resumen</label><textarea class="cp-inp" id="rg_res" data-pv="f.resumen" placeholder="Qué se habló y cómo quedó">' + esc(f.resumen) + '</textarea></div>' +
    '<div class="cp-fld"><span class="cp-lb">Acuerdos</span><div style="display:flex;flex-direction:column;gap:6px">' + f.acuerdos.map(function (a, i) {
      return '<div class="cc-acu"><input type="checkbox" data-a="acok" data-i="' + i + '"' + (a.ok ? ' checked' : '') + ' aria-label="Cumplido"><input class="cp-inp" data-pv="ac.' + i + '" value="' + esc(a.t) + '" placeholder="Acuerdo"><button type="button" class="cc-copiar" data-a="acx" data-i="' + i + '" aria-label="Quitar acuerdo">' + ic('x', 16) + '</button></div>';
    }).join('') + '<button type="button" class="cc-lnk" data-a="acadd" style="align-self:flex-start">+ Agregar acuerdo</button></div></div>' +
    '<div class="cp-fld"><span class="cp-lb">Objeción principal</span><div class="cc-mods">' + OBJECIONES.map(function (o) { return '<button type="button" class="cc-mod" aria-pressed="' + (f.objecion === o) + '" data-a="obj" data-v="' + o + '">' + o + '</button>'; }).join('') + '</div></div>' +
    '<div class="cp-fld"><span class="cp-lb">Próxima acción</span><div class="cc-grid4" style="grid-template-columns:120px minmax(0,1fr) 130px 96px">' + K.combo('ccRgTipo', PROX, f.proxTipo, { etiqueta: 'Tipo' }) +
    '<input class="cp-inp" data-pv="f.proxTxt" value="' + esc(f.proxTxt) + '" placeholder="Qué sigue" aria-label="Próxima acción">' + K.fecha('rg.fecha', f.proxFecha, { etiqueta: 'Fecha' }) + K.combo('ccRgHora', HORAS, f.proxHora, { etiqueta: 'Hora' }) + '</div></div>' +
    '<div class="cp-fld"><span class="cp-lb">Datos para la propuesta</span><div class="cc-grid2"><div class="cp-fld"><label for="rg_desc">Descuento (%)</label><input class="cp-inp" id="rg_desc" type="number" min="0" max="50" data-pv="f.descuento" value="' + esc(f.descuento) + '"></div>' +
    '<div class="cp-fld"><label for="rg_vig">Vigencia (meses)</label><input class="cp-inp" id="rg_vig" type="number" min="1" max="60" data-pv="f.vigencia" value="' + esc(f.vigencia) + '"></div></div>' + modChips(f.mods, 'rgmod') +
    '<div class="cc-acc"><span class="cc-hint">Precarga estos datos al crear la propuesta.</span><span class="cc-sp"></span><button type="button" class="cp-btn cp-out cp-sm" data-a="aplicar"' + (S.ini.permisos.propuestas ? '' : ' disabled') + '>Aplicar a la propuesta</button></div></div>';
  return { w: 'c', s: esc(l.CODIGO) + ' · ' + esc(l.EMPRESA), t: 'Registrar reunión', b: b,
    f: '<button type="button" class="cp-btn cp-ghost" data-a="volver">Cancelar</button><div class="cp-r"><button type="button" class="cp-btn cp-pri" data-a="regok"' + (st.busy ? ' disabled' : '') + '>Guardar en la ficha</button></div>' };
}

/* ---------------------------------------------------------------- nuevo lead */
var N = null;
function abrirNuevo() {
  N = { f: { empresa: '', contacto: '', cargo: '', correo: '', telefono: '', mensaje: '' }, busy: false };
  K.Panel.open({ st: N, render: function (st) {
    var f = st.f, fld = function (k, t, o) { o = o || {}; return '<div class="cp-fld' + (o.full ? ' cc-full' : '') + '"><label for="nl_' + k + '">' + t + '</label><input class="cp-inp" id="nl_' + k + '" data-pv="n.' + k + '" value="' + esc(f[k]) + '"' + (o.af ? ' data-autofocus="1"' : '') + '></div>'; };
    return { w: 'c', s: 'Centro Comercial', t: 'Nuevo lead', b: '<div class="cc-grid2">' + fld('empresa', 'Empresa', { af: 1 }) + fld('contacto', 'Contacto') + fld('cargo', 'Cargo') + fld('correo', 'Correo') + fld('telefono', 'Teléfono') + '</div>' +
      '<div class="cp-fld"><label for="nl_msg">Nota</label><textarea class="cp-inp" id="nl_msg" data-pv="n.mensaje">' + esc(f.mensaje) + '</textarea></div>' +
      '<div class="cc-nota">Queda asignado a ti, en estado CONTACTADO y con origen «registrado a mano».</div>',
      f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><div class="cp-r"><button type="button" class="cp-btn cp-pri" data-a="nuevook"' + (st.busy ? ' disabled' : '') + '>Crear lead</button></div>' };
  }, onclose: function () { N = null; } });
}

/* =====================================================================
   EVENTOS
   ===================================================================== */
function verPdf(tipo, id) {
  call('VerPdf', { tipo: tipo, id: +id }).then(function (r) {
    var bin = atob(r.base64), u8 = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
    var url = URL.createObjectURL(new Blob([u8], { type: 'application/pdf' }));
    var w = window.open(url, '_blank');
    if (!w) { var a = document.createElement('a'); a.href = url; a.download = r.nombre; document.body.appendChild(a); a.click(); a.remove(); }
    setTimeout(function () { URL.revokeObjectURL(url); }, 60000);
  }).catch(K.toastError);
}
function avisoCorreo(r, ok, malo) { return r && r.correo === false ? malo : ok; }
function toggle(lista, v) { var i = lista.indexOf(v); if (i >= 0) lista.splice(i, 1); else lista.push(v); }

var A = {
  tab: function (ds) { S.tab = ds.v; S.verMas = {}; pintarCabecera(); pintar(); history.replaceState(null, '', location.pathname + '?tab=' + ds.v); },
  kpi: function (ds) { S.tab = ds.tab; if (ds.f) S.filt = ds.f; pintarCabecera(); pintar(); history.replaceState(null, '', location.pathname + '?tab=' + ds.tab); },
  filt: function (ds) { S.filt = ds.v; pintar(); },
  cfilt: function (ds) { S.cfilt = ds.v; pintar(); },
  sub: function (ds) { S.sub[ds.t] = ds.v; S.aq = ''; pintar(); },
  admver: function (ds, el, e) {
    var d = S.adm[ds.v]; abrirFichaSitio(d.ficha + '?query=' + ds.q, ADM[ds.v].titulo, ds.v);
  },
  admnuevo: function (ds) { abrirFichaSitio(S.adm[ds.v].ficha, ADM[ds.v].nuevo, ds.v); },
  vista: function (ds) { S.view = ds.v; guardarVista(ds.v); pintar(); },
  vermas: function (ds) { S.verMas[ds.v] = 1; pintar(); },
  ficha: function (ds) { abrirFicha(ds.id); },
  nuevo: function () { abrirNuevo(); },
  nuevook: function () {
    var f = N.f; N.busy = true; K.Panel.paint();
    call('CrearLead', { empresa: f.empresa, contacto: f.contacto, cargo: f.cargo, correo: f.correo, telefono: f.telefono, mensaje: f.mensaje })
      .then(function (r) { K.Panel.close(); K.toast('Lead ' + r.codigo + ' creado'); cargar().then(function () { abrirFicha(r.lead); }); })
      .catch(function (e) { if (N) { N.busy = false; K.Panel.paint(); } K.toastError(e); });
  },
  copiar: function (ds) { try { navigator.clipboard.writeText(ds.v).then(function () { K.toast('Correo copiado'); }); } catch (e) { } },
  sec: function (ds) { F.open[ds.v] = !F.open[ds.v]; K.Panel.paint(); },
  volver: function () { F.modo = 'ficha'; F.busy = false; K.Panel.paint(); },
  /* información */
  infoed: function () { var l = F.data.lead; F.f = { EMPRESA: l.EMPRESA, RUT: l.RUT, RUBRO: l.RUBRO, CONTACTO: l.CONTACTO, CARGO: l.CARGO, CORREO: l.CORREO, TELEFONO: l.TELEFONO, INTERESES: l.INTERESES || '' }; F.edit = true; F.open.info = true; K.Panel.paint(); },
  infox: function () { F.edit = false; K.Panel.paint(); },
  intmod: function (ds) { var m = mods(F.f.INTERESES); toggle(m, ds.v); F.f.INTERESES = m.join(','); K.Panel.paint(); },
  infook: function () {
    var f = F.f;
    ocupado(call('GuardarDatos', { lead: F.id, empresa: f.EMPRESA, rut: f.RUT, rubro: f.RUBRO, contacto: f.CONTACTO, cargo: f.CARGO, correo: f.CORREO, telefono: f.TELEFONO, intereses: f.INTERESES }))
      .then(function (d) { recibir(d, 'Datos del lead guardados'); }).catch(function () { });
  },
  estado: function (ds) { ocupado(call('CambiarEstado', { lead: F.id, estado: ds.v, motivo: null })).then(function (d) { recibir(d, ds.v === 'CONTACTADO' && F && F.data.lead.ESTADO === 'CONTACTADO' ? 'Lead actualizado' : 'Estado actualizado'); }).catch(function () { }); },
  proxok: function () {
    var p = F.prox; if (!p.fecha) { K.toastError('Elige la fecha de la próxima acción.'); return; }
    ocupado(call('GuardarProximaAccion', { lead: F.id, tipo: p.tipo, texto: p.txt, fecha: p.fecha + ' ' + (p.hora || '10:00') }))
      .then(function (d) { F.prox = null; recibir(d, 'Próxima acción guardada'); }).catch(function () { });
  },
  /* actividad */
  tipo: function (ds) { F.tipo = ds.v; K.Panel.paint(); },
  act: function () {
    if (!F.txt.trim()) return;
    ocupado(call('RegistrarActividad', { lead: F.id, tipo: F.tipo, detalle: F.txt })).then(function (d) { F.txt = ''; recibir(d, 'Actividad registrada'); }).catch(function () { });
  },
  /* perdido */
  perd: function () { F.perd = true; F.motivo = ''; K.Panel.paint(); },
  perdx: function () { F.perd = false; K.Panel.paint(); },
  mot: function (ds) { F.motivo = ds.v; K.Panel.paint(); },
  perdok: function () { ocupado(call('CambiarEstado', { lead: F.id, estado: 'PERDIDO', motivo: F.motivo })).then(function (d) { recibir(d, 'Lead marcado perdido'); }).catch(function () { }); },
  /* demo */
  demo: function () { abrirDemo(); },
  ddias: function (ds) { F.f.dias = +ds.v; K.Panel.paint(); },
  dmod: function (ds) { toggle(F.f.mods, ds.v); K.Panel.paint(); },
  demook: function () {
    var f = F.f; if (!f.mods.length) { K.toastError('Elige al menos un módulo.'); return; }
    ocupado(call('CrearDemo', { lead: F.id, dias: +f.dias, modulos: f.mods.join(','), limites: f.lim }))
      .then(function (r) { F.open = null; recibir(r, avisoCorreo(r, 'Demo creada · credenciales enviadas a ' + r.ficha.demo.USUARIO_CORREO, 'Demo creada, pero el correo no salió. Usa «Reenviar credenciales».')); }).catch(function () { });
  },
  ext: function () { F.ext = true; K.Panel.paint(); },
  extx: function () { F.ext = false; K.Panel.paint(); },
  extok: function (ds) { ocupado(call('ExtenderDemo', { lead: F.id, dias: +ds.v })).then(function (d) { recibir(d, 'Demo extendida ' + ds.v + ' días'); }).catch(function () { }); },
  cred: function () {
    ocupado(call('ReenviarCredenciales', { lead: F.id })).then(function (r) { recibir(r, avisoCorreo(r, 'Nuevas credenciales enviadas', 'Se generó una clave nueva, pero el correo no salió. Revisa la configuración de correo.')); }).catch(function () { });
  },
  /* propuesta */
  prop: function (ds) { abrirProp(ds.v); },
  ptipo: function (ds) { F.f.tipo = ds.v; if (ds.v === 'PERSONALIZADA' && !F.f.nombre) F.f.nombre = 'Plan ' + F.data.lead.EMPRESA; if (ds.v === 'ESTANDAR') A.pplan({ v: F.f.plan }); else K.Panel.paint(); },
  pplan: function (ds) {
    var p = (S.ini.planes || []).filter(function (x) { return String(x.ID) === String(ds.v); })[0]; if (!p) { K.Panel.paint(); return; }
    Object.assign(F.f, { plan: p.ID, mods: mods(p.MODULOS), mensual: p.MENSUAL_UF, usuarios: p.LIM_USUARIOS, activos: p.LIM_ACTIVOS, plantas: p.LIM_PLANTAS, gb: p.LIM_GB, bodegas: null });
    K.Panel.paint();
  },
  pmod: function (ds) { toggle(F.f.mods, ds.v); K.Panel.paint(); },
  propok: function (ds) {
    var f = F.f, est = f.tipo === 'ESTANDAR', plan = est ? (S.ini.planes || []).filter(function (x) { return String(x.ID) === String(f.plan); })[0] : null;
    var p = { tipo: f.tipo, plan: est ? f.plan : null, nombre: est ? (plan ? plan.NOMBRE : '') : f.nombre, modulos: f.mods.join(','), usuarios: f.usuarios, activos: f.activos, plantas: f.plantas,
      bodegas: f.bodegas, gb: f.gb, implementacion: f.implementacion, mensual: f.mensual, descuento: f.descuento, vigencia: f.vigencia, condiciones: f.condiciones };
    ocupado(call('GuardarPropuesta', { lead: F.id, p: p, enviar: ds.v === '1' })).then(function (r) {
      F.open = null; recibir(r, ds.v === '1' ? avisoCorreo(r, 'Propuesta enviada a ' + r.ficha.lead.CORREO, 'Propuesta guardada, pero el correo no salió.') : 'Propuesta guardada como borrador');
    }).catch(function () { });
  },
  propenv: function (ds) { ocupado(call('EnviarPropuesta', { lead: F.id, propuesta: +ds.id })).then(function (r) { recibir(r, avisoCorreo(r, 'Propuesta enviada', 'Propuesta marcada como enviada, pero el correo no salió.')); }).catch(function () { }); },
  pdf: function (ds) { verPdf(ds.t, ds.id); },
  /* contrato */
  contrato: function () {
    var d = F.data, pv = d.propuestas.filter(function (p) { return p.ESTADO === 'ENVIADA' || p.ESTADO === 'ACEPTADA'; })[0];
    if (!d.lead.RUT) { F.open.info = true; A.infoed(); K.toastError('Completa el RUT de la empresa antes de generar el contrato.'); return; }
    if (!pv) { K.toastError('Primero envía una propuesta.'); return; }
    ocupado(call('GenerarContrato', { lead: F.id, propuesta: pv.ID })).then(function (r) {
      F.open = null; recibir(r, avisoCorreo(r, 'Contrato generado y enviado para firma', 'Contrato generado, pero el correo no salió. Usa «Reenviar para firma».'));
    }).catch(function () { });
  },
  reenviar: function () {
    var c = contUltimo(F.data);
    ocupado(call('ReenviarContrato', { lead: F.id, contrato: c.ID })).then(function (r) { recibir(r, avisoCorreo(r, 'Enlace de firma reenviado (el anterior dejó de servir)', 'Se generó un enlace nuevo, pero el correo no salió.')); }).catch(function () { });
  },
  anular: function (ds) { F.anular = +ds.id; F.motivoAn = ''; K.Panel.paint(); },
  anx: function () { F.anular = null; K.Panel.paint(); },
  anok: function (ds) {
    if (!F.motivoAn.trim()) { K.toastError('Indica el motivo de la anulación.'); return; }
    ocupado(call('AnularContrato', { lead: F.id, contrato: +ds.id, motivo: F.motivoAn })).then(function (d) { recibir(d, 'Contrato anulado'); }).catch(function () { });
  },
  /* reuniones */
  reu: function (ds) { abrirReu(ds.f, ds.id); },
  sala: function () { call('NuevaSala', { empresa: F.data.lead.EMPRESA }).then(function (r) { F.f.enlace = r.enlace; K.Panel.paint(); }).catch(K.toastError); },
  rdur: function (ds) { F.f.dur = +ds.v; K.Panel.paint(); },
  rlug: function (ds) { F.f.lugar = ds.v; K.Panel.paint(); },
  ptog: function (ds, el) { F.f.parts[+ds.i].on = el.checked; },
  padd: function () {
    var c = (F.f.nuevo || '').trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(c)) { K.toastError('Escribe un correo válido.'); return; }
    F.f.parts.push({ n: '', c: c, on: true }); F.f.nuevo = ''; K.Panel.paint();
  },
  reuok: function () {
    var f = F.f;
    if (!f.fecha || !f.hora) { K.toastError('Elige la fecha y la hora.'); return; }
    var parts = f.parts.filter(function (p) { return p.on; }).map(function (p) { return { n: p.n, c: p.c }; });
    if (!parts.length) { K.toastError('Agrega al menos un participante.'); return; }
    ocupado(call('AgendarReunion', { lead: F.id, inicio: f.fecha + ' ' + f.hora, duracion: +f.dur, lugar: f.lugar, enlace: f.enlace, direccion: f.direccion, motivo: f.motivo, participantes: parts }))
      .then(function (r) { F.open = null; recibir(r, r.enviados ? 'Invitación enviada a ' + K.pl(r.enviados, 'participante', 'participantes') + ' · queda en tus próximas acciones' : 'Reunión agendada, pero el correo no salió.'); })
      .catch(function () { });
  },
  acok: function (ds, el) { F.f.acuerdos[+ds.i].ok = el.checked; },
  acx: function (ds) { F.f.acuerdos.splice(+ds.i, 1); if (!F.f.acuerdos.length) F.f.acuerdos.push({ t: '', ok: false }); K.Panel.paint(); },
  acadd: function () { F.f.acuerdos.push({ t: '', ok: false }); K.Panel.paint(); },
  obj: function (ds) { F.f.objecion = F.f.objecion === ds.v ? '' : ds.v; K.Panel.paint(); },
  rgmod: function (ds) { toggle(F.f.mods, ds.v); K.Panel.paint(); },
  aplicar: function () { var f = F.f; F.precarga = { descuento: f.descuento, vigencia: f.vigencia, mods: f.mods }; abrirProp(propVigente(F.data) ? 'copia' : 'nueva'); K.toast('Datos de la reunión aplicados a la propuesta'); },
  regok: function () {
    var f = F.f;
    if (!f.resumen.trim()) { K.toastError('Escribe un resumen de la reunión.'); return; }
    var dp = (f.descuento !== '' || f.vigencia !== '' || f.mods.length) ? { descuento: f.descuento, vigencia: f.vigencia, modulos: f.mods.join(',') } : null;
    ocupado(call('RegistrarReunion', { lead: F.id, reunion: f.reunion, notas: f.notas, resumen: f.resumen, acuerdos: f.acuerdos.filter(function (a) { return a.t.trim(); }),
      objecion: f.objecion || null, datosPropuesta: dp, proxTipo: f.proxTxt ? f.proxTipo : null, proxTexto: f.proxTxt || null, proxFecha: f.proxTxt && f.proxFecha ? f.proxFecha + ' ' + (f.proxHora || '10:00') : null }))
      .then(function (d) { recibir(d, 'Reunión registrada en la ficha con notas y acuerdos'); }).catch(function () { });
  }
};

function pv(clave, valor, el) {
  if (COB && COB.pv(clave, valor)) return;
  if (N && clave.indexOf('n.') === 0) { N.f[clave.slice(2)] = valor; return; }
  if (!F) return;
  if (clave === 'txt') { F.txt = valor; var b = $('#cpLayer [data-a=act]'); if (b) b.disabled = !valor.trim() || F.busy; return; }
  if (clave === 'motivoAn') { F.motivoAn = valor; return; }
  if (clave.indexOf('prox.') === 0) { F.prox[clave.slice(5)] = valor; return; }
  if (clave.indexOf('lim.') === 0) { F.f.lim[clave.slice(4)] = valor === '' ? 0 : +valor; return; }
  if (clave.indexOf('ac.') === 0) { F.f.acuerdos[+clave.slice(3)].t = valor; return; }
  if (clave.indexOf('f.') === 0) {
    var k = clave.slice(2), num = ['usuarios', 'activos', 'plantas', 'bodegas', 'gb', 'implementacion', 'mensual', 'descuento', 'dias'];
    F.f[k] = num.indexOf(k) >= 0 ? (valor === '' ? null : +valor) : valor;
    if (F.modo === 'prop') actualizarTotal();
    if (k === 'dias' || k === 'motivo' || k === 'direccion') K.Panel.paint();
  }
  void el;
}
function combo(span, valor) {
  var n = span.getAttribute('data-cb');
  if (n === 'ccEjFiltro') { S.ej = valor || ''; pintar(); return; }
  if (COB && COB.combo(n, valor)) return;
  if (!F) return;
  if (n === 'ccEjFicha' && valor && String(valor) !== String(F.data.lead.EJECUTIVO_ID || '')) {
    ocupado(call('AsignarEjecutivo', { lead: F.id, ejecutivo: +valor })).then(function (d) { recibir(d, 'Ejecutivo asignado'); }).catch(function () { });
    return;
  }
  if (n === 'ccProxTipo') F.prox.tipo = valor;
  if (n === 'ccProxHora') F.prox.hora = valor;
  if (n === 'ccVig') { F.f.vigencia = +valor || 12; actualizarTotal(); K.Panel.paint(); }
  if (n === 'ccRHora') { F.f.hora = valor; K.Panel.paint(); }
  if (n === 'ccRgTipo') F.f.proxTipo = valor;
  if (n === 'ccRgHora') F.f.proxHora = valor;
}
function fecha(el) {
  if (COB && COB.fecha(el)) return;
  if (!F) return;
  var b = el.getAttribute('data-fe'), v = K.deDN(el.value);
  if (b === 'prox.fecha') F.prox.fecha = v;
  if (b === 'r.fecha') { F.f.fecha = v; K.Panel.paint(); }
  if (b === 'rg.fecha') F.f.proxFecha = v;
}

if (window.CCCobros && CFG.wsCobros) {
  COB = window.CCCobros({ K: K, S: S, A: A, ic: ic, icb: icb, chip: chip, dmy: dmy, hoyIso: hoyIso, ws: CFG.wsCobros, pintar: pintar, segSub: segSub,
    subPorDefecto: function (t) { return subVistas(t)[0][0]; } });
}
K.bind({ A: A, pv: pv, combo: combo, fecha: fecha });
/* Los buscadores filtran mientras se escribe (no son parte del cajón). */
document.addEventListener('input', function (e) {
  if (e.target.id === 'ccQ') { S.q = e.target.value; var pos = e.target.selectionStart; pintar(); var q = $('#ccQ'); if (q) { q.focus(); try { q.setSelectionRange(pos, pos); } catch (er) { } } }
  if (e.target.id === 'ccAQ') { S.aq = e.target.value; var p3 = e.target.selectionStart; pintar(); var a3 = $('#ccAQ'); if (a3) { a3.focus(); try { a3.setSelectionRange(p3, p3); } catch (er) { } } }
  if (e.target.id === 'ccCQ') { S.cq = e.target.value; var p2 = e.target.selectionStart; pintar(); var c = $('#ccCQ'); if (c) { c.focus(); try { c.setSelectionRange(p2, p2); } catch (er) { } } }
});

/* ------------------------------------------------------------ arranque */
call('Iniciar').then(function (ini) {
  S.ini = ini; S.hoy = ini.hoy; S.ahora = ini.ahora;
  pintarCabecera(); pintar();
  return cargar();
}).then(function () {
  if (CFG.lead) abrirFicha(CFG.lead);
}).catch(function (e) {
  $('#ccBody').innerHTML = '<div class="cc-vacio">' + esc(e.message || 'No se pudo abrir el Centro Comercial.') + '</div>';
  K.toastError(e);
});
}
/* El script va en el <head>: se espera a que exista #cpRoot. */
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciarCentroComercial);
else iniciarCentroComercial();
