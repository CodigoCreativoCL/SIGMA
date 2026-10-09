/* =====================================================================
   SIGMA · Kit compartido de los lugares de Mantenimiento (Operación, Avisos, Recursos)
   09-10-2026. Se generó copiando del Centro de Planificación lo que no cambia (íconos,
   fechas, llamar, avatar, combo, foco) con _scratch/gen_mant_comun.py; desde ahora se
   edita a mano. Expone window.MantKit.
   Convenciones: clases cp- bajo .cp-root; combos SigmaCombo; fechas con el calendario
   SIGMA; todo <button> con type="button"; «activo», nunca «equipo».
   ===================================================================== */
(function () {
'use strict';
var CFG = window.MantLugarConfig || {};
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

/* ------------------------------------------------------------ íconos que el Centro no traía */
Object.assign(P, {
  spark: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 15l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z"/>',
  bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 8 3 8H3s3-1 3-8"/><path d="M10.3 21a1.9 1.9 0 0 0 3.4 0"/>',
  send: '<path d="M22 2L11 13"/><path d="M22 2l-7 20-4-9-9-4z"/>'
});

/* ------------------------------------------------------------ avisos emergentes */
var UNDO = null;
function toastEl(html, role, ms) {
  var t = document.createElement('div'); t.className = 'cp-toast'; t.setAttribute('role', role || 'status'); t.innerHTML = html;
  $('#cpToasts').appendChild(t); setTimeout(function () { t.remove(); if (UNDO && UNDO.el === t) UNDO = null; }, ms || 4200); return t;
}
function toast(msg, deshacer) {
  var t = toastEl(ic('check', 18) + '<span>' + esc(msg) + '</span>' + (deshacer ? '<button type="button" class="cp-undo" data-a="undo">Deshacer</button>' : ''), 'status', deshacer ? 7000 : 4200);
  if (deshacer) UNDO = { fn: deshacer, el: t };
}
/* Aviso con una acción («Abrir OT», «Ver avisos»): fn recibe nada y se llama al pulsar. */
function toastA(msg, etiqueta, fn) {
  var t = toastEl(ic('check', 18) + '<span>' + esc(msg) + '</span><button type="button" class="cp-undo" data-a="toastact">' + esc(etiqueta) + '</button>', 'status', 8000);
  t.querySelector('[data-a=toastact]').addEventListener('click', function () { t.remove(); fn(); });
}
function toastError(e) {
  var m = e && e.message ? e.message : String(e || 'No se pudo completar.');
  if (e && e.sesion) m = 'La sesión expiró. Vuelve a entrar.';
  var t = toastEl(ic('alert', 18) + '<span>' + esc(m) + '</span>', 'alert', 6000);
  t.querySelector('.cp-ic').style.color = '#FF9B93';
}

/* ------------------------------------------------------------ panel lateral (cajón) */
var PN = null;
var Panel = {
  state: function () { return PN ? PN.st : null; },
  open: function (def) { PN = def; Panel.paint(); setTimeout(function () { var f = $('#cpLayer [data-autofocus]') || $('#cpLayer .cp-pnl-h .cp-ibx'); if (f) f.focus(); }, 30); },
  close: function () { var d = PN; PN = null; var L = $('#cpLayer'); if (L) L.innerHTML = ''; if (d && d.onclose) d.onclose(); },
  paint: function () {
    var Lh = $('#cpLayer'); if (!PN) { Lh.innerHTML = ''; return; }
    var fo = grabFocus(Lh), sb = $('#cpLayer .cp-pnl-b'), st = sb ? sb.scrollTop : 0;
    var r = PN.render(PN.st);
    var inner = '<div class="cp-pnl-h"><div class="cp-t">' + (r.s ? '<small>' + r.s + '</small>' : '') + '<h3 id="cpPnlT">' + r.t + '</h3></div><button type="button" class="cp-ibx" data-a="pclose" aria-label="Cerrar panel">' + ic('x', 18) + '</button></div><div class="cp-pnl-b">' + r.b + '</div>' + (r.f ? '<div class="cp-pnl-f">' + r.f + '</div>' : '');
    var ex = $('#cpLayer .cp-pnl');
    if (ex) { ex.className = 'cp-pnl ' + (r.w ? 'cp-' + r.w : ''); ex.innerHTML = inner; }
    else Lh.innerHTML = '<div class="cp-scr" data-a="pclose"></div><aside class="cp-pnl ' + (r.w ? 'cp-' + r.w : '') + '" role="dialog" aria-modal="true" aria-labelledby="cpPnlT">' + inner + '</aside>';
    var nb = $('#cpLayer .cp-pnl-b'); if (nb) nb.scrollTop = st;
    putFocus(fo, Lh); conectarFechas(Lh);
  }
};

/* ------------------------------------------------------------ popover */
var POP = null;
var Pop = {
  open: function (el, def) { def.el = el; POP = def; Pop.paint(); setTimeout(function () { var f = $('#cpPop [data-autofocus]'); if (f) f.focus({ preventScroll: true }); }, 20); },
  close: function () { if (!POP) return; var el = POP.el; POP = null; Pop.paint(); if (el && el.isConnected && el.getAttribute('aria-expanded')) el.setAttribute('aria-expanded', 'false'); },
  isOpen: function () { return !!POP; },
  state: function () { return POP; },
  paint: function () {
    var host = $('#cpPop'); if (!POP) { host.innerHTML = ''; return; }
    var fo = grabFocus(host);
    host.innerHTML = '<div class="cp-pp ' + (POP.cls || '') + '" role="dialog" style="visibility:hidden">' + POP.render(POP) + '</div>';
    Pop.pos(); putFocus(fo, host);
  },
  pos: function () {
    var pp = $('#cpPop .cp-pp'); if (!pp || !POP) return;
    if (POP.el && POP.el.isConnected) { var r = POP.el.getBoundingClientRect(); POP.r = { l: r.left, t: r.top, b: r.bottom, rr: r.right }; }
    var w = pp.offsetWidth, h = pp.offsetHeight, R = POP.r || { l: 20, t: 20, b: 20, rr: 20 };
    var left = POP.right ? R.rr - w : R.l; left = Math.max(12, Math.min(left, innerWidth - w - 12));
    var top = R.b + 6; if (top + h > innerHeight - 12) top = Math.max(12, R.t - h - 6);
    pp.style.left = left + 'px'; pp.style.top = top + 'px'; pp.style.visibility = '';
  }
};

/* ------------------------------------------------------------ eventos
   bind({ A: { nombre: function (dataset, el, evento) }, pv: function (clave, valor, el),
          combo: function (span, valor), fecha: function (el), key: function (e) })
   data-a dispara A[nombre]; data-pv avisa cada cambio de un campo del panel. */
function bind(o) {
  var A = o.A || {};
  A.pclose = function () { Panel.close(); };
  A.popx = function () { Pop.close(); };
  A.undo = function () { if (UNDO) { var f = UNDO.fn; UNDO.el.remove(); UNDO = null; f(); } };
  var root = $('#cpRoot');
  document.addEventListener('click', function (e) {
    if (!root.contains(e.target)) return;
    if (POP && !e.target.closest('#cpPop') && !e.target.closest('[data-a]')) Pop.close();
    var a = e.target.closest('[data-a]'); if (!a || !root.contains(a)) return;
    if (a.tagName === 'INPUT' && a.type === 'checkbox') { /* se atiende en change */ if (!A[a.getAttribute('data-a')]) return; }
    var fn = A[a.getAttribute('data-a')]; if (!fn) return;
    if (a.tagName === 'A' && !a.getAttribute('href')) e.preventDefault();
    if (a.tagName !== 'INPUT') e.preventDefault();
    var ds = {}; for (var i = 0; i < a.attributes.length; i++) { var n = a.attributes[i].name; if (n.indexOf('data-') === 0) ds[n.slice(5)] = a.attributes[i].value; }
    fn(ds, a, e);
  });
  function cambio(e) {
    var t = e.target; if (!root.contains(t)) return;
    var span = t.closest('[data-cb]');
    if (span && t.type === 'text') { var h = span.querySelector('input[type=hidden]'); if (o.combo) o.combo(span, h ? h.value : ''); return; }
    if (t.hasAttribute('data-fe')) { if (o.fecha) o.fecha(t); return; }
    if (t.hasAttribute('data-pv') && o.pv) o.pv(t.getAttribute('data-pv'), t.type === 'checkbox' ? t.checked : t.value, t, e.type);
  }
  document.addEventListener('change', cambio);
  document.addEventListener('input', function (e) { if (e.target.hasAttribute('data-pv') && e.target.hasAttribute('data-live')) cambio(e); });
  document.addEventListener('keydown', function (e) {
    if (!root.contains(e.target) && e.key !== 'Escape') return;
    if (e.key === 'Escape') { if (POP) Pop.close(); else if (PN) Panel.close(); return; }
    if ((e.key === 'Enter' || e.key === ' ') && e.target.getAttribute('role') === 'button' && e.target.tagName !== 'BUTTON' && e.target.tagName !== 'A') { e.preventDefault(); e.target.click(); return; }
    if (o.key) o.key(e);
  });
  window.addEventListener('resize', function () { Pop.pos(); });
}

window.MantKit = {
  CFG: CFG, $: $, $$: $$, esc: esc, nrm: nrm, pl: pl, ic: ic, iso: iso, D: D, TODAY: TODAY, addD: addD, diffD: diffD, wday: wday,
  fD: fD, fDY: fDY, fDL: fDL, fDN: fDN, deDN: deDN, dIso: dIso, hIso: hIso, rel: rel, fN: fN, fH: fH,
  llamar: llamar, ini: ini, avatar: avatar, combo: combo, fecha: fecha, conectarFechas: conectarFechas,
  toast: toast, toastA: toastA, toastError: toastError, Panel: Panel, Pop: Pop, bind: bind, grabFocus: grabFocus, putFocus: putFocus
};
})();
