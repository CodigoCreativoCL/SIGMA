/* =========================================================================
   SIGMA · Soporte: mesa de ayuda, centro de ayuda y campañas.

   Referencia visual y de comportamiento:
     docs/rediseno-soporte/sigma-soporte-referencia.html

   Lo carga el master en TODAS las páginas porque tres cosas viven en la
   cabecera: «Reportar problema», «? Ayuda» y la entrega de campañas (banner,
   modal y «Te puede interesar»). Las pantallas del módulo (View/Soporte/*)
   ponen un <div id="sgs-app" data-vista="…"> y este archivo las dibuja.

   Los datos vienen de WsSoporte, WsAyuda y WsCampanas; quién puede qué lo
   decide cada SP, aquí solo se esconden botones. Todo el CSS vive bajo .sgs
   (Css/LookAndFeel/sigma-soporte.css) para no tocar el resto del sitio.
   ========================================================================= */
(function(){
'use strict';
const CFG = window.SIGMA_SOPORTE;
if (!CFG) return;

/* ================= Utilidades ================= */
const $ = (s, r) => (r || document).querySelector(s);
const $$ = (s, r) => [...(r || document).querySelectorAll(s)];
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const norm = s => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
const RM = matchMedia('(prefers-reduced-motion: reduce)').matches;
const P = {
  home:'<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/>', inbox:'<path d="M3 13l3-8h12l3 8v6H3z"/><path d="M3 13h5l1 3h6l1-3h5"/>', mega:'<path d="M3 10v4h3l7 5V5L6 10H3z"/><path d="M17 8a5 5 0 0 1 0 8"/>',
  book:'<path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2z"/><path d="M4 19V5M8 7h7"/>', caps:'<rect x="3" y="8" width="18" height="8" rx="4"/><path d="M12 8v8"/>', doc:'<path d="M14 3H6v18h12V7z"/><path d="M14 3v4h4M9 12h6M9 16h4"/>',
  video:'<rect x="3" y="5" width="14" height="14" rx="3"/><path d="M17 10l4-2v8l-4-2"/>', folder:'<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>', chart:'<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
  search:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>', plus:'<path d="M12 5v14M5 12h14"/>', bell:'<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
  help:'<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.3-1 .9-1 1.7M12 17h.01"/>', warn:'<path d="M12 4L2.8 19.5h18.4z"/><path d="M12 10v4M12 17h.01"/>', user:'<circle cx="12" cy="8" r="3.5"/><path d="M5 20a7 7 0 0 1 14 0"/>',
  users:'<circle cx="9" cy="8" r="3.2"/><path d="M3 19a6 6 0 0 1 12 0"/><path d="M16 4.5a3 3 0 0 1 0 6M18 19a6 6 0 0 0-3-5.2"/>', filter:'<path d="M4 5h16l-6 8v5l-4 2v-7z"/>', cr:'<path d="M9 6l6 6-6 6"/>', cd:'<path d="M6 9l6 6 6-6"/>', cl:'<path d="M15 6l-6 6 6 6"/>',
  x:'<path d="M6 6l12 12M18 6L6 18"/>', expand:'<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>', check:'<path d="M5 12.5l4.5 4.5L19 7.5"/>', clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', building:'<path d="M4 21V5l8-2v18M12 9h8v12M8 8h.01M8 12h.01M8 16h.01M16 13h.01M16 17h.01"/>',
  gear:'<circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M5.5 18.5l1.7-1.7M16.8 7.2l1.7-1.7"/>', upload:'<path d="M12 15V4M7 9l5-5 5 5M4 15v5h16v-5"/>',
  clip:'<path d="M20 11.5l-8 8a5 5 0 0 1-7-7l8.5-8.5a3.3 3.3 0 0 1 4.7 4.7L9.7 17.2a1.7 1.7 0 0 1-2.4-2.4L15 7"/>', img:'<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5-8 8"/>', send:'<path d="M4 12l16-8-6 16-3-7z"/>',
  star:'<path d="M12 3.2l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17.2 6.6 20.1l1-6.1L3.2 9.7l6.1-.9z"/>', edit:'<path d="M4 20h4l10-10-4-4L4 16z"/><path d="M13 7l4 4"/>', eye:'<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  down:'<path d="M12 4v11M7 10l5 5 5-5M4 20h16"/>', link:'<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>', target:'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5"/>',
  cal:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>', reopen:'<path d="M4 12a8 8 0 1 0 3-6.2"/><path d="M4 4v4h4"/>', arrow:'<path d="M5 12h14M13 6l6 6-6 6"/>', more:'<path d="M5 12h.01M12 12h.01M19 12h.01" stroke-width="3"/>',
  bulb:'<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.8.8 1 1.5 1 2.5h6c0-1 .2-1.7 1-2.5A6 6 0 0 0 12 3z"/>', layers:'<path d="M12 3l9 5-9 5-9-5z"/><path d="M3 13l9 5 9-5"/>', pin:'<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  box:'<path d="M3 7l9-4 9 4v10l-9 4-9-4z"/><path d="M3 7l9 4 9-4M12 11v10"/>', wrench:'<path d="M14.5 4a4.5 4.5 0 0 0-4.3 5.9L4 16.1V20h3.9l6.2-6.2A4.5 4.5 0 1 0 14.5 4z"/>', gauge:'<path d="M4 15a8 8 0 1 1 16 0"/><path d="M12 15l4-5"/>',
  spark:'<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>', phone:'<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>', tablet:'<rect x="4" y="2.5" width="16" height="19" rx="2.5"/><path d="M11 18.5h2"/>',
  monitor:'<rect x="2.5" y="4" width="19" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>', play:'<path d="M8 5.5v13l11-6.5z" fill="currentColor"/>', lock:'<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>', tag:'<path d="M3 12V4h8l10 10-8 8z"/><circle cx="7.5" cy="8.5" r="1.5"/>',
  list:'<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>', grid:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  ext:'<path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>', trash:'<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>', history:'<path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5M12 8v4l3 2"/>',
  flag:'<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>', zap:'<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>', activity:'<path d="M3 12h4l3-8 4 16 3-8h4"/>', drag:'<path d="M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01" stroke-width="3"/>',
  chat:'<path d="M4 5h16v11H9l-5 4z"/>', note:'<path d="M5 3h10l4 4v14H5z"/><path d="M9 11h6M9 15h4"/>', swap:'<path d="M7 7h13l-4-4M17 17H4l4 4"/>', sys:'<rect x="4" y="4" width="16" height="12" rx="2"/><path d="M9 20h6M12 16v4"/>',
  shield:'<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>', copy:'<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3"/>', rocket:'<path d="M5 15c-1.5 1.5-2 5-2 5s3.5-.5 5-2M9 18l-3-3c1-4 4.5-9.5 12-11-1.5 7.5-7 11-9 14z"/><circle cx="14.5" cy="9.5" r="1.5"/>',
  factory:'<path d="M3 21V10l6 4V10l6 4V6h6v15z"/>', thumb:'<path d="M7 11v9H4v-9zM7 11l4-8c1.5 0 2.5 1 2.5 2.5V9h5.5a2 2 0 0 1 2 2.3l-1.2 7A2 2 0 0 1 17.8 20H7"/>', menu:'<path d="M4 7h16M4 12h16M4 17h16"/>',
  smile:'<circle cx="12" cy="12" r="9"/><path d="M8.5 14.5a4.5 4.5 0 0 0 7 0M9 9.5h.01M15 9.5h.01" stroke-width="2.2"/>', meh:'<circle cx="12" cy="12" r="9"/><path d="M8.5 15h7M9 9.5h.01M15 9.5h.01" stroke-width="2.2"/>', frown:'<circle cx="12" cy="12" r="9"/><path d="M8.5 16a4.5 4.5 0 0 1 7 0M9 9.5h.01M15 9.5h.01" stroke-width="2.2"/>',
  pause:'<path d="M8 5v14M16 5v14" stroke-width="2.6"/>'
};
const ic = (n, s = 18, extra = '') => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 24 24" fill="${extra.includes('fill') ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="width:${s}px;height:${s}px">${P[n] || ''}</svg>`;
const MES = ['ene','feb','mar','abr','may','jun','jul','ago','sept','oct','nov','dic'];
const pad = n => String(n).padStart(2, '0');
const D = s => s ? (s instanceof Date ? s : new Date(s)) : null;
const fD = d => d ? `${pad(d.getDate())} ${MES[d.getMonth()]} ${d.getFullYear()}` : '—';
const fDs = d => d ? `${pad(d.getDate())} ${MES[d.getMonth()]}` : '—';
const fT = d => d ? `${pad(d.getHours())}:${pad(d.getMinutes())}` : '';
const fDT = d => d ? `${fDs(d)} · ${fT(d)}` : '—';
const ago = d => { if (!d) return '—'; const m = Math.round((Date.now() - d) / 6e4); if (m < 1) return 'recién'; if (m < 60) return `hace ${m} min`; const h = Math.round(m / 60); if (h < 24) return `hace ${h} h`; const dd = Math.round(h / 24); return dd === 1 ? 'ayer' : `hace ${dd} días`; };
const num = n => Number(n || 0).toLocaleString('es-CL');
const dur = m => { m = Math.abs(Math.round(m || 0)); return m >= 2880 ? `${Math.floor(m / 1440)} d ${Math.floor(m % 1440 / 60)} h` : m >= 60 ? `${Math.floor(m / 60)} h ${pad(m % 60)} min` : `${m} min`; };
const ini = n => String(n || '?').trim().split(/\s+/).map(x => x[0]).join('').slice(0, 2).toUpperCase();
const pct = (a, b) => b ? Math.round(a / b * 100) : 0;
const urlDe = ruta => !ruta ? '' : ruta.startsWith('~/') ? CFG.raiz + ruta.slice(2) : ruta;
const qs = new URLSearchParams(location.search);
const debounce = (f, ms) => { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => f(...a), ms); }; };

/* ================= Servidor ================= */
const SVC = {s:'WsSoporte.asmx', a:'WsAyuda.asmx', c:'WsCampanas.asmx'};
async function ws(svc, metodo, datos){
  let r;
  try {
    r = await fetch(CFG.raiz + 'WebService/' + SVC[svc] + '/' + metodo, {method:'POST', credentials:'same-origin',
      headers:{'Content-Type':'application/json; charset=utf-8'}, body:JSON.stringify(datos || {})});
  } catch (e){ throw new Error('No hay conexión con SIGMA. Revisa tu internet.'); }
  if (!r.ok) throw new Error('SIGMA no respondió (' + r.status + '). Intenta de nuevo.');
  const j = await r.json();
  const d = typeof j.d === 'string' ? JSON.parse(j.d) : j.d;
  if (d && d.sesion){ location.href = CFG.raiz + 'Login.aspx'; throw new Error('La sesión expiró.'); }
  if (d && d.error) throw new Error(d.detalle || 'No se pudo completar la acción.');
  return d;
}
const leer64 = f => new Promise((ok, mal) => { const r = new FileReader(); r.onload = () => ok(String(r.result).split(',')[1] || ''); r.onerror = () => mal(new Error('No se pudo leer el archivo.')); r.readAsDataURL(f); });
const pesoTxt = b => b > 1048576 ? (b / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(b / 1024)) + ' KB';
const tipoArch = n => { const e = String(n || '').split('.').pop().toLowerCase(); return /png|jpe?g|gif|webp|bmp/.test(e) ? 'img' : /mp4|webm|mov|avi/.test(e) ? 'video' : 'doc'; };
/* Un botón que espera al servidor lo dice: girando y con el verbo en curso. */
function ocupado(b, txt){ if (!b) return; b.disabled = true; b.setAttribute('aria-busy', 'true'); b.innerHTML = `<span class="giro" aria-hidden="true"></span>${txt}`; }
const fallo = e => toast(esc((e && e.message) || 'Algo falló.'), null, true);

/* ================= Catálogos ================= */
const ST = {rep:{l:'Reportado', c:'tone-b', d:'Recién llegó'}, rev:{l:'En revisión', c:'tone-b', d:'Mesa de ayuda lo está viendo'}, asg:{l:'Asignado', c:'tone-b', d:'Tiene responsable'}, ana:{l:'En análisis', c:'tone-w', d:'Buscando la causa'},
  esp:{l:'Esperando usuario', c:'tone-c', d:'Pausa el SLA'}, dev:{l:'En corrección', c:'tone-w', d:'Desarrollo lo corrige'}, res:{l:'Resuelto', c:'tone-s', d:'Envía la encuesta'}, cer:{l:'Cerrado', c:'tone-n', d:'Sin más cambios'}, rea:{l:'Reabierto', c:'tone-d', d:'Vuelve a abrirse'}};
const ST_ORDER = ['rep','rev','asg','ana','esp','dev','res','cer','rea'];
const PR = {c:{l:'Crítica', bars:4, h:4, d:'Toda la planta o un proceso está detenido'}, a:{l:'Alta', bars:3, h:12, d:'No puedo terminar una tarea'}, m:{l:'Media', bars:2, h:24, d:'Puedo seguir trabajando con dificultad'}, b:{l:'Baja', bars:1, h:72, d:'Es una duda o una mejora'}};
const CATS = [['error','Error del sistema','warn'],['func','Problema funcional','gear'],['acceso','Acceso/permisos','lock'],['datos','Datos incorrectos','list'],['rend','Rendimiento','gauge'],['integ','Integración','link'],['sug','Sugerencia','bulb'],['otro','Otro','more']];
const CAT = Object.fromEntries(CATS.map(([k, l, i]) => [k, {l, i}]));
const KIND = {capsula:{l:'Cápsula', i:'caps', c:'tone-p'}, video:{l:'Video', i:'video', c:'tone-b'}, manual:{l:'Manual', i:'book', c:'tone-c'}, documento:{l:'Documento', i:'doc', c:'tone-c'}, guia:{l:'Guía rápida', i:'bulb', c:'tone-w'}, faq:{l:'FAQ', i:'help', c:'tone-n'}};
const CTYPES = [['anuncio','Anuncio','mega'],['novedad','Novedad','spark'],['mant','Mantenimiento','wrench'],['tutorial','Tutorial','caps'],['importante','Importante','warn'],['comunicado','Comunicado','chat'],['consejo','Consejo','bulb']];
const CT = Object.fromEntries(CTYPES.map(([k, l, i]) => [k, {l, i}]));
const CST = {activa:['Activa','tone-s'], programada:['Programada','tone-b'], borrador:['Borrador','tone-n'], finalizada:['Finalizada','tone-n'], pausada:['Pausada','tone-w']};
const FMT = {banner:'Banner', modal:'Modal', card:'Card', notif:'Notificación'};
const TONO = {b:'tone-b', w:'tone-w', c:'tone-c', s:'tone-s', n:'tone-n', d:'tone-d', p:'tone-p'};
const THEMES = [['#6732F4','#4820C9','#16C6C9'],['#087BEA','#0565C2','#16C6C9'],['#141B33','#2A3456','#6732F4'],['#007F8A','#005E66','#16C6C9']];
const AV = ['', 'c', 'w', 'p'];

const stChip = k => ST[k] ? `<span class="chip ${ST[k].c}"><i></i>${ST[k].l}</span>` : '';
const prBars = n => `<svg viewBox="0 0 14 14" aria-hidden="true">${[0,1,2,3].map(i => `<rect x="${1 + i * 3.3}" y="${10 - i * 2.6}" width="2.3" height="${3 + i * 2.6}" rx="1" fill="currentColor" opacity="${i < n ? 1 : .28}"/>`).join('')}</svg>`;
const prChip = k => PR[k] ? `<span class="prio ${k}">${prBars(PR[k].bars)}${PR[k].l}</span>` : '';
const cstChip = s => CST[s] ? `<span class="chip ${CST[s][1]}"><i></i>${CST[s][0]}</span>` : '';
const avatar = (id, n, cls = 'sm') => id == null ? `<span class="av ${cls} g" title="SIGMA">${ic('sys', 13)}</span>` : `<span class="av ${cls} ${AV[Math.abs(+id || 0) % 4]}" title="${esc(n)}">${ini(n)}</span>`;
const kmeta = k => k.dur ? `${k.dur} min` : k.pages ? `${k.fmt || 'PDF'} · ${k.pages} páginas` : k.read ? k.read : (k.fmt || '');

/* Ticket tal como lo usan las vistas (desde la fila del SP). */
function TK(r){
  return {id:r.stk_id, folio:r.stk_folio, t:r.stk_titulo, cat:r.stk_categoria, prio:r.stk_prioridad, st:r.stk_estado, abierto:!!r.ses_abierto,
    user:{id:r.stk_usuario, n:r.USUARIO_NOMBRE}, perfil:r.stk_perfil || '', cliente:r.CLIENTE_NOMBRE || '', clienteId:r.stk_cliente, planta:r.PLANTA_NOMBRE || '',
    mod:r.stk_modulo || 'Sin módulo', pant:r.stk_pantalla || '—', reg:r.stk_registro || '—', resp:r.stk_responsable ? {id:r.stk_responsable, n:r.RESPONSABLE_NOMBRE} : null,
    area:r.AREA_NOMBRE || 'Mesa de Ayuda', recur:r.stk_recurrente, created:D(r.stk_fecha_creacion), upd:D(r.stk_fecha_actualizacion),
    slaTot:r.SLA_TOTAL_MIN || 0, slaUso:r.SLA_USADO_MIN || 0, unread:!!r.NO_LEIDO, last:r.ULTIMO_TIPO, enc:r.ENCUESTA, raw:r};
}
function slaOf(t){
  if (!t.abierto){ const ok = t.slaUso <= t.slaTot; return {cls:ok ? 's' : 'd', l:ok ? 'SLA cumplido' : 'Resuelto fuera de plazo', pct:100}; }
  const left = t.slaTot - t.slaUso;
  if (t.st === 'esp') return {cls:'', l:left < 0 ? `En pausa · vencido hace ${dur(-left)}` : `En pausa · quedan ${dur(left)}`, pct:pct(t.slaUso, t.slaTot), pausa:true};
  if (left < 0) return {cls:'d', l:`Vencido hace ${dur(-left)}`, pct:100};
  return {cls:left < t.slaTot * .25 ? 'w' : '', l:`Vence en ${dur(left)}`, pct:Math.min(100, pct(t.slaUso, t.slaTot))};
}
/* Contenido de ayuda tal como lo usan las vistas. */
function KB(r){
  return {id:r.ayc_id, kind:r.ayc_tipo, t:r.ayc_titulo, desc:r.ayc_descripcion || '', fmt:r.ayc_formato || '', dur:r.ayc_duracion, pages:r.ayc_paginas, read:r.ayc_lectura,
    status:r.ayc_estado || 'Publicado', ver:r.ayc_version || 'v1.0', tema:r.ayc_tema || 0, upd:D(r.ayc_fecha_actualizacion), author:r.AUTOR || '', aud:r.ayc_audiencia || 'Todos los usuarios',
    mod:r.MODULO || 'General', path:[r.MODULO, r.SUBMODULO, r.PANTALLA, r.SECCION].filter(Boolean), nota:r.NOTA || '', cat:r.ayc_categoria,
    views:r.VISTAS || 0, viewsT:r.VISTAS_TOTAL || 0, uniq:r.UNICOS || 0, dl:r.DESCARGAS || 0, plays:r.REPRODUCCIONES || 0, comp:r.REPRODUCCIONES ? pct(r.COMPLETOS, r.REPRODUCCIONES) : 0,
    rating:r.VALORACION || 0, ratings:r.VALORACIONES || 0};
}

/* ================= Capas: modal, drawer, popover, toast, tooltip ================= */
let CAPA = null;
function capa(){
  if (CAPA) return CAPA;
  CAPA = document.createElement('div'); CAPA.className = 'sgs sgs-capa'; CAPA.id = 'sgs-capa';
  CAPA.innerHTML = '<div id="sgs-layer"></div><div class="toasts" id="sgs-toasts" role="status" aria-live="polite"></div><div class="tipbox" id="sgs-tip" hidden></div>';
  document.body.appendChild(CAPA); return CAPA;
}
const layer = () => (capa(), $('#sgs-layer'));
let lastFocus = null;
function openModal(html, cls = ''){ lastFocus = document.activeElement; layer().innerHTML = `<div class="scrim" data-scrim="1"><div class="modal ${cls}" role="dialog" aria-modal="true">${html}</div></div>`; setTimeout(() => { const f = $('#sgs-layer .modal [autofocus]') || $('#sgs-layer .modal textarea, #sgs-layer .modal input:not([type=hidden]), #sgs-layer .modal .btn.pri'); f && f.focus({preventScroll:true}); }, 30); }
function openDrawer(html){ lastFocus = document.activeElement; layer().innerHTML = `<div class="scrim" data-scrim="1" style="justify-content:flex-end;padding:0"></div><aside class="drawer" role="dialog" aria-modal="true">${html}</aside>`; setTimeout(() => { const f = $('#sgs-layer .drawer [autofocus]') || $('#sgs-layer .drawer input, #sgs-layer .drawer button'); f && f.focus(); }, 30); }
function setModal(html){ const m = $('#sgs-layer .modal'); if (m) m.innerHTML = html; }
function setDrawer(html){ const m = $('#sgs-layer .drawer'); if (m) m.innerHTML = html; }
function closeLayer(){ const l = layer(); if (!l.innerHTML) return; l.innerHTML = ''; if (lastFocus && document.body.contains(lastFocus)) lastFocus.focus({preventScroll:true}); }
let popEl = null, popAnchor = null;
function openPop(html, anchor, w){
  closePop(); popAnchor = anchor; const p = document.createElement('div'); p.className = 'pop'; p.setAttribute('role', 'dialog'); p.innerHTML = html;
  if (w) p.style.width = `min(${w}px, calc(100vw - 24px))`; capa().appendChild(p); popEl = p; placePop();
  setTimeout(() => { const f = p.querySelector('[autofocus], button, input'); f && f.focus(); }, 20);
  return p;
}
function placePop(){ if (!popEl || !popAnchor) return; const r = popAnchor.getBoundingClientRect(); const w = popEl.offsetWidth; popEl.style.left = Math.min(innerWidth - w - 12, Math.max(12, r.right - w)) + 'px'; popEl.style.top = Math.min(r.bottom + 8, innerHeight - 120) + 'px'; }
function closePop(){ if (popEl){ popEl.remove(); popEl = null; if (popAnchor && document.body.contains(popAnchor)) popAnchor.focus({preventScroll:true}); popAnchor = null; } }
function toast(msg, undo, malo){ capa(); const t = document.createElement('div'); t.className = 'toast'; t.innerHTML = `${ic(malo ? 'warn' : 'check', 18)}<span>${msg}</span>${undo ? '<button type="button">Deshacer</button>' : ''}`; if (malo) t.classList.add('is-error'); $('#sgs-toasts').appendChild(t); if (undo) t.querySelector('button').onclick = () => { undo(); t.remove(); }; setTimeout(() => t.remove(), malo ? 7000 : 4500); }
function showTip(el, e){ const tb = $('#sgs-tip'); if (!tb) return; tb.innerHTML = el.dataset.tip; tb.hidden = false; tb.style.left = Math.min(innerWidth - tb.offsetWidth - 8, e.clientX + 14) + 'px'; tb.style.top = Math.min(innerHeight - tb.offsetHeight - 8, e.clientY + 14) + 'px'; }
document.addEventListener('mousemove', e => { const el = e.target.closest && e.target.closest('.sgs [data-tip]'); const tb = $('#sgs-tip'); if (el) showTip(el, e); else if (tb) tb.hidden = true; });
addEventListener('resize', placePop);
addEventListener('scroll', () => { if (popEl) placePop(); }, true);

/* ================= Gráficos (SVG simples) ================= */
function hbars(list, o = {}){
  if (!list.length || !list.some(x => x.v)) return `<p class="mut" style="font-size:12.5px">Sin datos en el período.</p>`;
  const max = Math.max(1, ...list.map(x => x.v));
  return `<div class="hb">${list.map(x => `<div class="hb-r" data-tip="<b>${esc(x.l)}</b><br>${num(x.v)} ${o.unit || 'tickets'}" tabindex="0"><span class="lb">${esc(x.l)}</span><span class="tr"><span style="width:${Math.max(1.5, x.v / max * 100)}%;${x.c ? 'background:' + x.c : ''}"></span></span><span class="v">${num(x.v)}${o.suffix || ''}</span></div>`).join('')}</div>`;
}
function lineChart(series, labels, o = {}){
  const H = o.h || 200, PH = H - 26; const all = series.flatMap(s => s.d); const max = Math.max(1, ...all) * 1.15; const n = Math.max(2, labels.length);
  const X = i => i / (n - 1) * 100, Y = v => (1 - v / max) * 100;
  const ticks = [0, .5, 1].map(f => Math.round(max * f / 1.15));
  const grid = ticks.map(t => `<line x1="0" x2="100" y1="${Y(t)}" y2="${Y(t)}" stroke="#EDF0F5" stroke-width="1" vector-effect="non-scaling-stroke"/>`).join('');
  const line = s => s.d.map((v, i) => (i ? 'L' : 'M') + X(i).toFixed(2) + ' ' + Y(v).toFixed(2)).join(' ');
  const paths = series.map(s => `<path d="${line(s)}" fill="none" stroke="${s.c}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" vector-effect="non-scaling-stroke"/>`).join('');
  const area = o.area && series[0] ? `<path d="${line(series[0])} L100 100 L0 100Z" fill="${series[0].c}" opacity=".08"/>` : '';
  const step = Math.ceil(n / 6);
  const xl = labels.map((l, i) => (i % step === 0 || i === n - 1) && !(i !== n - 1 && n - 1 - i < step / 2) ? `<span style="position:absolute;left:${X(i)}%;transform:translateX(${i === 0 ? '0' : i === n - 1 ? '-100%' : '-50%'});white-space:nowrap">${l}</span>` : '').join('');
  const hits = labels.map((l, i) => `<span class="lc-hit" style="left:${Math.max(0, X(i) - 50 / (n - 1))}%;width:${100 / (n - 1)}%" data-cx="${X(i)}" data-tip="<b>${esc(l)}</b>${series.map(s => `<br><span style='color:${s.c}'>●</span> ${esc(s.l)}: ${num(s.d[i])}`).join('')}"></span>`).join('');
  const dots = series.map(s => `<span class="lc-dot" style="left:${X(n - 1)}%;top:${Y(s.d[s.d.length - 1] || 0)}%;background:${s.c}"></span>`).join('');
  return `<div class="lc" role="img" aria-label="${esc(o.label || 'Gráfico de líneas')}"><div class="lc-y" style="height:${PH}px">${ticks.map(t => `<span style="top:${Y(t)}%">${t}</span>`).join('')}</div>
    <div><div class="lc-plot" style="height:${PH}px"><svg viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">${grid}${area}${paths}</svg>${dots}<span class="lc-xh"></span>${hits}</div><div class="lc-x">${xl}</div></div></div>`;
}
document.addEventListener('mouseover', e => { const r = e.target.closest && e.target.closest('.sgs [data-cx]'); if (!r) return; const xh = r.parentElement.querySelector('.lc-xh'); xh.style.left = r.dataset.cx + '%'; xh.style.opacity = 1; });
document.addEventListener('mouseout', e => { const r = e.target.closest && e.target.closest('.sgs [data-cx]'); if (r){ const xh = r.parentElement.querySelector('.lc-xh'); xh && (xh.style.opacity = 0); } });
function spark(d, c = 'var(--sigma-purple)', w = 96, h = 28){ if (d.length < 2) d = [0, ...d, 0]; const max = Math.max(1, ...d), X = i => i * (w - 4) / (d.length - 1) + 2, Y = v => h - 3 - v / max * (h - 6);
  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" aria-hidden="true"><path d="${d.map((v, i) => (i ? 'L' : 'M') + X(i).toFixed(1) + ' ' + Y(v).toFixed(1)).join(' ')}" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="${X(d.length - 1)}" cy="${Y(d[d.length - 1])}" r="3" fill="${c}"/></svg>`; }
/* Portadas generadas: color sólido con formas, sin degradados. */
function cover(i, kind){ const [a, b, c] = THEMES[(i || 0) % THEMES.length];
  return `<svg class="bg" viewBox="0 0 320 180" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><rect width="320" height="180" fill="${b}"/><circle cx="270" cy="20" r="120" fill="${a}"/><circle cx="40" cy="190" r="90" fill="${a}" opacity=".7"/><path d="M0 140 Q80 100 160 130 T320 110 V180 H0Z" fill="${c}" opacity=".22"/>${kind === 'grid' ? '' : `<g opacity=".35" fill="none" stroke="#fff" stroke-width="1.5"><rect x="190" y="52" width="80" height="56" rx="8"/><path d="M190 72h80M214 52v56"/></g>`}</svg>`; }
const DIAS = n => Array.from({length:n}, (_, i) => { const d = new Date(); d.setDate(d.getDate() - (n - 1 - i)); return fDs(d); });

/* ================= Piezas comunes de las vistas ================= */
const crumbs = list => `<nav class="crumbs" aria-label="Ruta">${list.map((c, i) => i < list.length - 1 ? `<a href="${c[1] ? esc(URL_(c[1], c[2])) : '#'}">${esc(c[0])}</a><i>/</i>` : `<span>${esc(c[0])}</span>`).join('')}</nav>`;
const kpi = (ico, tone, v, l, em, go) => `<${go ? `a href="${esc(URL_(go))}"` : 'div'} class="kpi"><span class="ico ${tone}">${ic(ico, 21)}</span><span style="min-width:0"><strong>${v}</strong><small>${l}</small>${em ? `<em>${em}</em>` : ''}</span></${go ? 'a' : 'div'}>`;
const empty = (icon, tone, t, p, acts = '') => `<div class="empty"><span class="ei ${tone}">${ic(icon, 34)}</span><b>${t}</b><p>${p}</p>${acts ? `<div class="acts">${acts}</div>` : ''}</div>`;
const chdr = (ico, tone, h, p, r = '') => `<header class="ch"><span class="ico ${tone}">${ic(ico, 19)}</span><div class="g"><h2>${h}</h2>${p ? `<p>${p}</p>` : ''}</div>${r ? `<div class="r">${r}</div>` : ''}</header>`;
const btn = (cls, act, label, icon, extra = '') => `<button type="button" class="btn ${cls}" ${act}${extra}>${icon ? ic(icon, 16) : ''}${label}</button>`;
function skeleton(){ return `<div class="sk" style="height:16px;width:200px"></div><div class="sk" style="height:34px;width:min(420px,80%)"></div>
  <div class="grid g4">${'<div class="sk" style="height:84px;border-radius:16px"></div>'.repeat(4)}</div>
  <div class="sk" style="height:46px;border-radius:12px"></div>${'<div class="sk" style="height:78px;border-radius:14px"></div>'.repeat(4)}`; }

/* Las pantallas del módulo y sus direcciones. */
const PAG = {hub:'View/Soporte/Inicio.aspx', tickets:'View/Soporte/Problemas.aspx', umine:'View/Soporte/MisProblemas.aspx', ticket:'View/Soporte/Problema.aspx',
  campaigns:'View/Soporte/Campanas/Campanas.aspx', cwiz:'View/Soporte/Campanas/Campana.aspx', help:'View/Soporte/Ayuda/Centro.aspx', lib:'View/Soporte/Ayuda/Biblioteca.aspx',
  cats:'View/Soporte/Ayuda/Categorias.aspx', kb:'View/Soporte/Ayuda/Contenido.aspx', kwiz:'View/Soporte/Ayuda/ContenidoForm.aspx', analytics:'View/Soporte/Analitica/Soporte.aspx', kbstats:'View/Soporte/Analitica/Ayuda.aspx'};
function URL_(page, id, q){ const p = new URLSearchParams(q || {}); if (id != null && id !== '') p.set('id', id); const s = p.toString(); return CFG.raiz + (PAG[page] || page) + (s ? '?' + s : ''); }
function go(page, id, q){ location.href = URL_(page, id, q); }
const puede = k => !!(CFG.permisos && CFG.permisos[k]);

/* =========================================================================
   GLOBAL (todas las páginas): reportar problema, ayuda contextual, campañas
   ========================================================================= */

/* El contexto lo escribe el master (módulo, submódulo y pantalla según
   Menus); la página puede precisar el registro y la sección:
   window.SigmaContexto = {registro:'OT #4587', seccion:'Repuestos'}. */
function ctxNow(){
  const c = CFG.contexto || {}; const p = window.SigmaContexto || {};
  const b = document.body.dataset;
  return {mod:p.modulo || b.sgModulo || c.modulo || '', sub:p.submodulo || b.sgSubmodulo || c.submodulo || '', pant:p.pantalla || b.sgPantalla || c.pantalla || document.title || '',
    sec:p.seccion || b.sgSeccion || '', reg:p.registro || '', ruta:location.pathname + location.search};
}
const navegador = () => { const u = navigator.userAgent; const b = /Edg\//.test(u) ? 'Edge' : /Chrome\//.test(u) ? 'Chrome' : /Firefox\//.test(u) ? 'Firefox' : /Safari\//.test(u) ? 'Safari' : 'Navegador';
  const v = (u.match(/(Edg|Chrome|Firefox|Version)\/(\d+)/) || [])[2] || ''; const so = /Windows/.test(u) ? 'Windows' : /Android/.test(u) ? 'Android' : /iPhone|iPad/.test(u) ? 'iOS' : /Mac/.test(u) ? 'macOS' : 'Linux';
  return `${b} ${v} · ${so} · ${innerWidth}×${innerHeight}`; };

/* ---------- Reportar un problema (drawer) ---------- */
const RP = {};
let PANTALLAS = null;
/* La pantalla del reporte se elige de la lista de SIGMA (Menus), agrupada por módulo. */
function pantallaSel(c){
  if (!PANTALLAS) return `<select class="sel" disabled aria-label="Pantalla"><option>${esc(c.pant || 'Cargando pantallas…')}</option></select>`;
  const actual = PANTALLAS.find(x => x.apa_modulo === c.mod && x.apa_pantalla === c.pant) || PANTALLAS.find(x => x.apa_pantalla === c.pant);
  const mods = [...new Set(PANTALLAS.map(x => x.apa_modulo))];
  const et = x => x.apa_submodulo && x.apa_submodulo !== x.apa_pantalla ? `${x.apa_submodulo} › ${x.apa_pantalla}` : x.apa_pantalla;
  return `<select class="sel" data-rp="pantSel" aria-label="Pantalla">${actual ? '' : `<option value="" selected>${esc(c.pant || 'Elige la pantalla')}</option>`}${mods.map(m => `<optgroup label="${esc(m)}">${PANTALLAS.filter(x => x.apa_modulo === m).map(x => `<option value="${x.apa_id}"${actual && actual.apa_id === x.apa_id ? ' selected' : ''}>${esc(et(x))}</option>`).join('')}</optgroup>`).join('')}</select>`;
}
function openReport(pre){
  Object.assign(RP, {cat:'', prio:'', t:'', d:'', files:[], sug:[], sugSeen:false, sugId:null, sugDismissed:false, ctx:ctxNow(), onBehalf:'', usuarios:null, done:null, enviando:false}, pre || {});
  closePop(); openDrawer(reportHTML());
  if (puede('gestionar')) ws('s', 'Usuarios').then(d => { RP.usuarios = d.usuarios; refreshReport(); }).catch(() => {});
  if (!PANTALLAS) ws('a', 'Pantallas').then(d => { PANTALLAS = d.pantallas.filter(x => x.apa_visible || x.apa_link === (CFG.contexto || {}).link); refreshReport(); }).catch(() => { PANTALLAS = []; refreshReport(); });
  if (CFG.perfil == null) ws('s', 'Cabecera').then(d => { CFG.planta = d.PLANTA || ''; CFG.plantaId = d.PLANTA_ID || 0; CFG.perfil = d.PERFIL || ''; refreshReport(); }).catch(() => {});
}
const fileRow = f => `<div class="file"><span class="fi ${f.k === 'img' ? 'tone-b' : f.k === 'video' ? 'tone-p' : 'tone-c'}">${esc((f.ext || 'FILE').slice(0, 4).toUpperCase())}</span><span style="min-width:0"><b>${esc(f.n)}</b><small>${f.err ? `<span style="color:var(--danger)">${esc(f.err)}</span>` : f.p == null ? esc(f.s) + ' · listo para enviar' : f.p < 100 ? `Subiendo… ${f.p} %` : esc(f.s) + ' · subido'}</small>${f.p != null && f.p < 100 ? `<div class="prog"><span style="width:${f.p}%"></span></div>` : ''}</span>${f.p == null ? `<button type="button" class="ibtn" data-rmfile="${esc(f.n)}" aria-label="Quitar ${esc(f.n)}">${ic('x', 16)}</button>` : '<span></span>'}</div>`;
function reportHTML(){
  if (RP.done) return `<div class="drawer-h"><h2>Reportar un problema</h2><button type="button" class="ibtn" data-act="close" aria-label="Cerrar">${ic('x', 20)}</button></div>
    <div class="drawer-b"><div class="success"><span class="ok">${ic('check', 34)}</span><h2 style="font-size:20px;font-weight:800">Recibimos tu reporte</h2><p class="mut" style="max-width:42ch">Tu número es <b style="color:var(--ink)">${esc(RP.done.folio)}</b>. Te avisaremos en la campana de notificaciones cada vez que haya novedades.</p>
      <div class="ctx-card" style="width:100%;max-width:420px;text-align:left;margin-top:8px"><dl class="dl"><dt>Tiempo de respuesta</dt><dd>Según prioridad: hasta ${PR[RP.prio || 'm'].h} h</dd><dt>Prioridad</dt><dd>${prChip(RP.prio || 'm')}</dd><dt>Desde</dt><dd>${esc([RP.ctx.mod, RP.ctx.pant].filter(Boolean).join(' › ') || '—')}</dd></dl></div>
      <div style="display:flex;gap:10px;margin-top:10px;flex-wrap:wrap;justify-content:center"><a class="btn out" href="${esc(URL_('ticket', RP.done.id))}">Ver mi reporte</a><button type="button" class="btn pri" data-act="close">Listo</button></div></div></div>`;
  const c = RP.ctx; const ok = RP.t.trim() && RP.cat && RP.prio;
  const tk = CFG.tickets || {}; const agotado = !puede('gestionar') && tk.incluido && !tk.disponible;
  if (agotado) return `<div class="drawer-h"><h2>Reportar un problema</h2><button type="button" class="ibtn" data-act="close" aria-label="Cerrar">${ic('x', 20)}</button></div>
    <div class="drawer-b">${empty('clock', 'tone-w', 'Tu empresa usó los tickets de este mes', `El plan incluye ${num(tk.limite)} tickets de soporte al mes y ya se usaron todos. El cupo se renueva el día 1. Mientras tanto, la respuesta puede estar en el centro de ayuda.`, puede('ayuda') ? `<a class="btn out" href="${esc(URL_('help'))}">${ic('book', 16)}Ir al centro de ayuda</a>` : '')}</div>`;
  const cupo = !puede('gestionar') && tk.limite != null && tk.limite < 1000 ? `Te quedan ${num(Math.max(0, tk.limite - tk.consumo))} de ${num(tk.limite)} tickets este mes. ` : '';
  const quien = puede('gestionar') ? `<select class="sel" data-rp="onBehalf" aria-label="Usuario que reporta"><option value="">Yo (${esc(CFG.nombre)})</option>${(RP.usuarios || []).map(u => `<option value="${u.usu_id}"${String(RP.onBehalf) === String(u.usu_id) ? ' selected' : ''}>${esc(u.NOMBRE)}${u.PERFIL ? ' · ' + esc(u.PERFIL) : ''}</option>`).join('')}</select>` : esc(CFG.nombre);
  return `<div class="drawer-h"><span class="ico tone-d" style="width:38px;height:38px;border-radius:12px;display:flex;align-items:center;justify-content:center">${ic('warn', 20)}</span><h2>${puede('gestionar') ? 'Nuevo problema' : 'Reportar un problema'}<small style="display:block;font-size:12.5px;font-weight:500;color:var(--muted)">Cuéntanos qué pasó. Lo demás ya lo sabemos.</small></h2><button type="button" class="ibtn" data-act="close" aria-label="Cerrar">${ic('x', 20)}</button></div>
  <div class="drawer-b">
    <section class="ctx-card" aria-label="Contexto detectado"><div style="display:flex;align-items:center;gap:8px;margin-bottom:10px"><span class="ico tone-c" style="width:28px;height:28px;border-radius:9px;display:flex;align-items:center;justify-content:center">${ic('target', 15)}</span><b style="font-size:13.5px;flex:1">Contexto detectado</b><span class="tag">${ic('lock', 12)}Se envía solo</span></div>
      <div class="ctx-grid">
        <div class="ctx-f"><span>Módulo</span><b>${esc(c.mod || '—')}</b></div>
        <div class="ctx-f"><span>Pantalla</span>${pantallaSel(c)}</div>
        <div class="ctx-f"><span>Registro</span><input class="in" data-rp="reg" value="${esc(c.reg)}" placeholder="Ej.: OT #4587" aria-label="Registro"></div>
        <div class="ctx-f"><span>Cliente</span><b>${esc(CFG.clienteNombre || '—')}</b></div>
        <div class="ctx-f"><span>Planta</span><b>${esc(CFG.planta || '—')}</b></div>
        <div class="ctx-f"><span>Fecha</span><b>${fD(new Date())} · ${fT(new Date())}</b></div>
        <div class="ctx-f"><span>Usuario</span>${puede('gestionar') ? quien : `<b>${quien}</b>`}</div>
        <div class="ctx-f"><span>Perfil</span><b>${esc(CFG.perfil || '—')}</b></div></div>
      <p class="hint" style="font-size:11.5px;color:var(--muted);margin-top:8px">Puedes corregir la pantalla o el registro si el problema está en otro lugar.</p></section>
    <section style="display:flex;flex-direction:column;gap:14px">
      <h3 style="font-size:16px;font-weight:800;display:flex;align-items:center;gap:8px"><span class="tag tone-p" style="height:24px">1</span>¿Qué ocurrió?</h3>
      <div class="f"><label for="rpT">Título <span class="req">*</span></label><input class="in" id="rpT" data-rp="t" value="${esc(RP.t)}" maxlength="200" placeholder="Ej.: No puedo cerrar la OT 4587" autocomplete="off" autofocus></div>
      <div class="f"><span class="lb">Categoría <span class="req">*</span></span><div class="optcards" role="group" aria-label="Categoría">${CATS.map(([k, l, i]) => `<button type="button" class="opt" data-rpcat="${k}" aria-pressed="${RP.cat === k}">${ic(i, 18)}${l}</button>`).join('')}</div></div>
      <div class="f"><label for="rpD">Descripción</label><textarea class="ta" id="rpD" data-rp="d" placeholder="¿Qué estabas haciendo? ¿Qué esperabas que pasara y qué pasó?">${esc(RP.d)}</textarea></div>
      <div id="rpSug">${sugHTML()}</div>
      <div class="f"><span class="lb">¿Cuánto te afecta? <span class="req">*</span></span><div class="optcards" role="group" aria-label="Prioridad" style="grid-template-columns:repeat(auto-fill,minmax(140px,1fr))">
        ${['b','m','a','c'].map(k => `<button type="button" class="opt" data-rpprio="${k}" aria-pressed="${RP.prio === k}"><span style="display:flex;align-items:center;gap:6px">${prChip(k)}</span><small>${PR[k].d}</small></button>`).join('')}</div></div>
      <div class="f"><span class="lb">Adjuntos</span><label class="drop" data-drop="rp"><span class="di">${ic('upload', 20)}</span><span class="dt"><b>Arrastra capturas, videos o documentos</b>PNG, JPG, MP4, PDF o DOCX · hasta 25 MB cada uno</span><span class="btn out sm">Elegir archivos</span><input type="file" multiple class="sr" data-rpfiles="1"></label>
        <div class="files" id="rpFiles">${RP.files.map(fileRow).join('')}</div></div>
    </section>
  </div>
  <div class="drawer-f"><span class="g" id="rpFoot">${cupo}${ok ? 'Todo listo. Recibirás la respuesta en Notificaciones.' : 'Completa el título, la categoría y cuánto te afecta.'}</span><button type="button" class="btn ghost" data-act="close">Cancelar</button><button type="button" class="btn pri" data-act="sendreport"${ok && !RP.enviando ? '' : ' disabled'}>${RP.enviando ? '<span class="giro" aria-hidden="true"></span>Enviando…' : ic('send', 16) + 'Enviar reporte'}</button></div>`;
}
function sugHTML(){
  const list = RP.sugDismissed ? [] : RP.sug;
  if (!list.length) return '';
  return `<div class="sug" role="status"><div class="hd">${ic('bulb', 18)}Encontramos contenido que podría ayudarte</div>
    <div class="rows">${list.map(k => `<div class="row" style="background:#fff"><span class="ico ${KIND[k.ayc_tipo].c}">${ic(KIND[k.ayc_tipo].i, 17)}</span><span style="min-width:0"><strong>${esc(k.ayc_titulo)}</strong><small>${KIND[k.ayc_tipo].l}${k.ayc_duracion ? ' · ' + esc(k.ayc_duracion) + ' min' : k.ayc_paginas ? ' · ' + k.ayc_paginas + ' páginas' : k.ayc_lectura ? ' · ' + esc(k.ayc_lectura) : ''}</small></span><span class="e"><button type="button" class="btn sec xs" data-act="sugview" data-id="${k.ayc_id}">${['capsula','video'].includes(k.ayc_tipo) ? 'Ver cápsula' : 'Abrir'}</button></span></div>`).join('')}</div>
    <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;border-top:1px solid rgba(0,127,138,.18);padding-top:10px"><span style="flex:1;font-size:12.5px;color:#0B5F67;font-weight:600">${RP.sugSeen ? '¿Te sirvió? Si se resolvió, no hace falta crear el reporte.' : '¿Tu problema continúa?'}</span>${RP.sugSeen ? `<button type="button" class="btn plain xs" data-act="sugsolved">Sí, se resolvió</button>` : ''}<button type="button" class="btn out xs" data-act="sugcontinue">Continuar con el reporte</button></div></div>`;
}
function refreshReport(){
  const dr = $('#sgs-layer .drawer'); if (!dr || !RP.ctx) return;
  /* Redibujar el drawer lo devolvía arriba: se guarda el scroll del cuerpo y
     el foco, y se restauran sin mover la vista. */
  const cuerpo = $('.drawer-b', dr); const y = cuerpo ? cuerpo.scrollTop : 0;
  const ae = document.activeElement; const id = ae && ae.id; const sel = ae && ae.selectionStart;
  dr.innerHTML = reportHTML();
  const nuevo = $('.drawer-b', dr); if (nuevo) nuevo.scrollTop = y;
  if (id && $('#' + id)){ const el = $('#' + id); el.focus({preventScroll:true}); try { el.setSelectionRange(sel, sel); } catch(e){} }
}
function updRpFoot(){ const ok = RP.t.trim() && RP.cat && RP.prio; const b = $('#sgs-layer [data-act="sendreport"]'); b && (b.disabled = !ok || RP.enviando); const f = $('#rpFoot'); if (f){ const tk = CFG.tickets || {}; const cupo = !puede('gestionar') && tk.limite != null && tk.limite < 1000 ? `Te quedan ${num(Math.max(0, tk.limite - tk.consumo))} de ${num(tk.limite)} tickets este mes. ` : ''; f.textContent = cupo + (ok ? 'Todo listo. Recibirás la respuesta en Notificaciones.' : 'Completa el título, la categoría y cuánto te afecta.'); } }
const buscarSug = debounce(async () => {
  const txt = (RP.t + ' ' + RP.d).trim(); if (txt.length < 6 || RP.sugDismissed){ return; }
  try { const d = await ws('s', 'Sugerencia', {texto:txt, modulo:RP.ctx.mod, pantalla:RP.ctx.pant}); RP.sug = d.sugerencias || []; if (RP.sug[0] && !RP.sugId) RP.sugId = RP.sug[0].ayc_id; const box = $('#rpSug'); box && (box.innerHTML = sugHTML()); } catch (e){}
}, 550);
async function sendReport(){
  if (RP.enviando) return; RP.enviando = true; updRpFoot();
  try {
    const c = RP.ctx;
    const d = await ws('s', 'Crear', {datos:JSON.stringify({usuario:RP.onBehalf || 0, planta:CFG.plantaId || 0, titulo:RP.t, descripcion:RP.d, categoria:RP.cat, prioridad:RP.prio,
      modulo:c.mod, submodulo:c.sub, pantalla:c.pant, seccion:c.sec, ruta:c.ruta, registro:c.reg, navegador:navegador(),
      sugerido:RP.sugDismissed && RP.sug.length ? RP.sug[0].ayc_id : 0, sugeridoVisto:RP.sugSeen ? 1 : 0})});
    /* Los adjuntos van después, uno por uno, contra el ticket ya creado. */
    for (const f of RP.files){
      f.p = 10; const box = $('#rpFiles'); box && (box.innerHTML = RP.files.map(fileRow).join(''));
      try { await ws('s', 'Adjuntar', {ticket:d.id, nombre:f.n, mime:f.file.type, base64:await leer64(f.file)}); f.p = 100; }
      catch (e){ f.err = e.message; f.p = 100; }
      const b2 = $('#rpFiles'); b2 && (b2.innerHTML = RP.files.map(fileRow).join(''));
    }
    RP.done = d; RP.enviando = false; if (CFG.tickets && CFG.tickets.limite != null){ CFG.tickets.consumo++; CFG.tickets.disponible = CFG.tickets.consumo < CFG.tickets.limite; } setDrawer(reportHTML());
    if (APP.recargar) APP.recargar();
  } catch (e){ RP.enviando = false; updRpFoot(); fallo(e); }
}
function addFiles(list){
  [...list].forEach(fl => { if (fl.size > 25 * 1048576){ toast(`«${esc(fl.name)}» pesa más de 25 MB.`, null, true); return; }
    RP.files.push({n:fl.name, ext:(fl.name.split('.').pop() || ''), k:tipoArch(fl.name), s:pesoTxt(fl.size), p:null, file:fl}); });
  const box = $('#rpFiles'); box && (box.innerHTML = RP.files.map(fileRow).join(''));
}

/* ---------- «? Ayuda»: lo vinculado a esta pantalla ---------- */
let CAMP_CARDS = [];
function itemAyuda(k){ return `<a class="hitem" href="${esc(URL_('kb', k.ayc_id, {origen:'contextual'}))}"><span class="t ${KIND[k.ayc_tipo].c}">${ic(KIND[k.ayc_tipo].i, 20)}</span><span><b>${esc(k.ayc_titulo)}</b><small>${KIND[k.ayc_tipo].l}${k.ayc_duracion ? ' · ' + esc(k.ayc_duracion) + ' min' : k.ayc_paginas ? ' · ' + esc(k.ayc_formato || 'PDF') + ' · ' + k.ayc_paginas + ' páginas' : k.ayc_lectura ? ' · ' + esc(k.ayc_lectura) : ''}</small></span>${ic('cr', 16)}</a>`; }
function ctxPopHTML(items, cargando){
  const c = ctxNow(); const donde = [c.sub && c.sub !== c.pant ? c.sub : c.mod, c.pant].filter(Boolean).join(' › ') || 'esta pantalla';
  return `<div class="pop-h"><span style="font-size:22px" aria-hidden="true">👋</span><span style="flex:1"><b>¿Necesitas ayuda?</b><small>Contenido para esta pantalla</small></span><button type="button" class="ibtn" data-act="closepop" aria-label="Cerrar">${ic('x', 18)}</button></div>
    <div class="ctxpill">${ic('pin', 14)}<span>Estás en <b>${esc(donde)}</b></span></div>
    <div class="pop-b">${cargando ? '<div class="sk" style="height:56px;margin:4px 6px"></div><div class="sk" style="height:56px;margin:4px 6px"></div>'
      : items.length ? items.map(itemAyuda).join('') : `<div class="empty" style="padding:16px"><b style="font-size:14px">Aún no hay ayuda para esta pantalla</b><p style="font-size:12.5px">Busca en el centro de ayuda o cuéntanos tu duda.</p></div>`}
      ${CAMP_CARDS.length ? `<div class="sec-t" style="padding:10px 8px 4px">💡 Te puede interesar</div>${CAMP_CARDS.slice(0, 2).map(campCardMini).join('')}` : ''}</div>
    <div class="pop-f">${puede('ayuda') ? `<a class="btn out sm" href="${esc(URL_('help'))}">Ver todo el contenido</a>` : '<span></span>'}${puede('reportar') ? `<button type="button" class="link" data-act="report">${ic('warn', 14)}Reportar problema</button>` : ''}</div>`;
}
async function openCtxHelp(anchor){
  const p = openPop(ctxPopHTML([], true), anchor, 380);
  const c = ctxNow();
  try { const d = await ws('a', 'Contextual', {modulo:c.mod, submodulo:c.sub, pantalla:c.pant, seccion:c.sec}); if (popEl === p) p.innerHTML = ctxPopHTML(d.items || []); }
  catch (e){ if (popEl === p) p.innerHTML = ctxPopHTML([]); }
}

/* ---------- Campañas para esta persona ---------- */
const CAMP = {};
const campDest = c => { const a = c.cam_cta_accion, d = c.cam_cta_destino; if (a === 'documento' || a === 'capsula') return URL_('kb', d, {origen:'campana'}); if (a === 'url') return d; if (a === 'modulo' || a === 'pantalla') return urlDe(d); return ''; };
function campCardMini(c){ return `<div class="pv-card" style="margin:4px 6px;box-shadow:var(--e1)"><svg width="44" height="44" viewBox="0 0 44 44" style="border-radius:12px"><rect width="44" height="44" fill="${THEMES[c.cam_tema % 4][1]}"/><circle cx="36" cy="6" r="18" fill="${THEMES[c.cam_tema % 4][0]}"/></svg><div style="min-width:0"><b style="font-size:13px;display:block">${esc(c.cam_titulo)}</b><small class="mut" style="font-size:11.5px">${esc(String(c.cam_descripcion || '').slice(0, 90))}</small>${c.cam_cta_accion !== 'nada' || c.cam_contenido ? `<div style="margin-top:6px"><button type="button" class="link" style="font-size:12px;margin:0;padding:0" data-campcta="${c.cam_id}">${esc(c.cam_cta_texto || (c.CONTENIDO_TITULO ? 'Ver ' + KIND[c.CONTENIDO_TIPO].l.toLowerCase() : 'Ver más'))} ${ic('arrow', 12)}</button></div>` : ''}</div></div>`; }
/* Presentacion de la campaña (bloque 369): ajuste de la imagen (llenar o
   completa), punto de enfoque, alto de la imagen y tamaño del aviso. */
const PRES_DEF = {ajuste:'cover', foco:'center', alto:'medio', tamano:'m', video:''};
const PRES_ALTO = {bajo:140, medio:200, alto:280, xalto:360};
const PRES_TAM = {s:440, m:520, l:680, xl:860};
const presDe = v => { let o = v; if (typeof v === 'string'){ try { o = JSON.parse(v); } catch (e){ o = null; } } return {...PRES_DEF, ...(o || {})}; };
/* La imagen tarda en llegar: mientras, un brillo que recorre el recuadro; al
   cargar aparece con un fundido y el brillo se va. */
/* Enlace de video de otra plataforma (YouTube, Vimeo, Loom): se muestra el reproductor incrustado. */
function videoEmb(u){
  u = String(u || '').trim(); if (!/^https?:\/\//i.test(u)) return null;
  let m = u.match(/(?:youtu\.be\/|youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/|embed\/|live\/))([\w-]{6,})/i); if (m) return 'https://www.youtube-nocookie.com/embed/' + m[1] + '?rel=0';
  m = u.match(/vimeo\.com\/(?:video\/)?(\d+)/i); if (m) return 'https://player.vimeo.com/video/' + m[1];
  m = u.match(/loom\.com\/(?:share|embed)\/([\w]+)/i); if (m) return 'https://www.loom.com/embed/' + m[1];
  m = u.match(/(?:fast\.wistia\.net|wistia\.com)\/medias\/(\w+)/i); if (m) return 'https://fast.wistia.net/embed/iframe/' + m[1];
  return null;
}
function medioHTML(url, video, pres, tema){
  const p = presDe(pres);
  const emb = videoEmb(p.video);
  if (emb) return `<iframe class="sgs-embed" src="${esc(emb)}" title="Video" loading="lazy" allow="accelerometer; encrypted-media; picture-in-picture; fullscreen" allowfullscreen referrerpolicy="strict-origin-when-cross-origin" style="position:absolute;inset:0;width:100%;height:100%;border:0;background:#000"></iframe>`;
  if (!url) return cover(tema);
  const st = `position:absolute;inset:0;width:100%;height:100%;object-fit:${p.ajuste === 'contain' ? 'contain' : 'cover'};object-position:center ${p.foco}`;
  return `<span class="sgs-carga" aria-hidden="true"></span>` + (video
    ? `<video class="sgs-medio" src="${esc(url)}" muted playsinline loop autoplay preload="auto" onloadeddata="this.classList.add('listo')" style="${st}"></video>`
    : `<img class="sgs-medio" src="${esc(url)}" alt="" decoding="async" onload="this.classList.add('listo')" onerror="this.remove()" style="${st}">`);
}
function campMedia(c, h){ return medioHTML(c.IMAGEN_URL, c.cam_medio === 'video', c.cam_presentacion, c.cam_tema); }
function campBotones(c, grande){
  /* El contenido promocionado y el botón principal pueden apuntar a lo mismo («Ver FAQ» dos veces): se deja uno. */
  const txtK = c.CONTENIDO_TIPO && KIND[c.CONTENIDO_TIPO] ? ('Ver ' + KIND[c.CONTENIDO_TIPO].l).toLowerCase() : '';
  const igual = (c.cam_cta_accion === 'documento' || c.cam_cta_accion === 'capsula') && String(c.cam_cta_destino) === String(c.cam_contenido);
  const k = c.cam_contenido && c.CONTENIDO_TITULO && !igual && !(c.cam_cta_accion !== 'nada' && String(c.cam_cta_texto || '').trim().toLowerCase() === txtK);
  return `${c.cam_cta_accion !== 'nada' ? `<button type="button" class="btn ${grande ? 'pri' : 'w sm'}" data-campcta="${c.cam_id}">${esc(c.cam_cta_texto || 'Ver más')}</button>` : ''}${k ? `<button type="button" class="btn out${grande ? '' : ' sm'}" data-campkb="${c.cam_id}">${ic(KIND[c.CONTENIDO_TIPO].i, 14)}Ver ${KIND[c.CONTENIDO_TIPO].l.toLowerCase()}</button>` : ''}${c.cam_confirmar ? `<button type="button" class="btn ${grande ? 'sec' : 'w sm'}" data-campok="${c.cam_id}">${ic('check', 14)}Entendido</button>` : ''}`;
}
function campModal(c){
  const tp = CT[c.cam_tipo] || {l:'Aviso', i:'mega'};
  const pr = presDe(c.cam_presentacion);
  openModal(`<div class="pv-modal sgs-camp"><div class="im" style="height:${PRES_ALTO[pr.alto] || 200}px">${campMedia(c)}<span class="chip tone-p sgs-camp-tipo">${ic(tp.i, 13)}${tp.l}</span>${c.IMAGEN_URL || videoEmb(presDe(c.cam_presentacion).video) ? `<button type="button" class="sgs-cerrar sgs-expandir" data-campexp="${c.cam_id}" aria-label="Ver en pantalla completa" title="Pantalla completa">${ic('expand', 17)}</button>` : ''}${c.cam_cerrable ? `<button type="button" class="sgs-cerrar" data-campx="${c.cam_id}" aria-label="Cerrar aviso">${ic('x', 18)}</button>` : ''}</div>
    <div class="tx"><h4>${esc(c.cam_titulo)}</h4>${c.cam_descripcion ? `<p>${esc(c.cam_descripcion)}</p>` : ''}
      <div class="sgs-camp-acts">${c.cam_cerrable && !c.cam_confirmar ? `<button type="button" class="btn ghost" data-campx="${c.cam_id}">Más tarde</button>` : ''}${campBotones(c, true)}</div></div></div>`, 'sgs-camp-modal');
  const m = $('#sgs-layer .modal.sgs-camp-modal'); if (m) m.style.width = `min(${PRES_TAM[pr.tamano] || 520}px, calc(100vw - 32px))`;
}
/* El aviso a pantalla completa: la imagen o el video enteros, sin recortar. Esc, clic fuera o la cruz lo cierran. */
function campPantallaCompleta(c){
  const url = c.IMAGEN_URL, emb = videoEmb(presDe(c.cam_presentacion).video);
  const cuerpo = emb ? `<iframe src="${esc(emb)}" title="Video" allow="accelerometer; encrypted-media; picture-in-picture; fullscreen" allowfullscreen style="width:min(96vw,1280px);aspect-ratio:16/9;max-height:92vh;border:0;background:#000;border-radius:12px"></iframe>`
    : c.cam_medio === 'video' ? `<video src="${esc(url)}" controls autoplay playsinline style="max-width:96vw;max-height:92vh;border-radius:12px"></video>`
    : `<img src="${esc(url)}" alt="${esc(c.cam_titulo)}" style="max-width:96vw;max-height:92vh;object-fit:contain;border-radius:12px;box-shadow:0 20px 60px rgba(0,0,0,.5)">`;
  const o = document.createElement('div'); o.id = 'sgs-fs'; o.className = 'sgs';
  o.setAttribute('role', 'dialog'); o.setAttribute('aria-label', 'Aviso en pantalla completa');
  o.style.cssText = 'position:fixed;inset:0;z-index:2147483000;background:rgba(10,14,26,.92);display:flex;align-items:center;justify-content:center;padding:16px';
  o.innerHTML = cuerpo + `<button type="button" class="sgs-cerrar" data-fsx="1" aria-label="Cerrar pantalla completa" style="position:fixed;right:18px;top:18px">${ic('x', 18)}</button>`;
  const cerrar = () => { o.remove(); document.removeEventListener('keydown', tecla, true); };
  const tecla = e => { if (e.key === 'Escape'){ e.stopPropagation(); cerrar(); } };
  o.addEventListener('click', e => { if (e.target === o || e.target.closest('[data-fsx]')) cerrar(); });
  document.addEventListener('keydown', tecla, true); document.body.appendChild(o);
}
function campBanner(c){
  const host = $('.sg-page-head') || $('.content-page .content .container-fluid') || document.body.firstElementChild;
  if (!host || $('#sgs-banner')) return;
  const b = document.createElement('div'); b.id = 'sgs-banner'; b.className = 'sgs sgs-banner-host';
  b.innerHTML = `<div class="ubanner" role="region" aria-label="Aviso"><span class="bi">${ic(CT[c.cam_tipo] ? CT[c.cam_tipo].i : 'mega', 20)}</span><span class="g"><b>${esc(c.cam_titulo)}</b><small>${esc(c.cam_descripcion || '')}</small></span><button type="button" class="btn w sm" data-campver="${c.cam_id}">${ic('eye', 14)}Ver más</button>${campBotones(c, false)}${c.cam_cerrable ? `<button type="button" class="x" data-campx="${c.cam_id}" aria-label="Cerrar aviso">${ic('x', 18)}</button>` : ''}</div>`;
  host.parentNode.insertBefore(b, host);
}
async function campEntrega(id, accion){ try { await ws('c', 'Entrega', {campana:id, accion}); } catch (e){} }
const CAMP_VISTAS = new Set();
async function cargarCampanas(){
  if (!CFG.clienteId) return;
  let d; try { d = await ws('c', 'Pendientes', {modulo:(CFG.contexto || {}).modulo || ''}); } catch (e){ return; }
  (d.campanas || []).forEach(c => CAMP[c.cam_id] = c);
  const L = d.campanas || []; const tiene = (c, f) => (',' + c.cam_formatos + ',').includes(',' + f + ',');
  const primera = !CAMP_VISTAS.size && !cargarCampanas.hecha; cargarCampanas.hecha = true;
  /* Conectado: la pantalla vuelve a preguntar cada ~30 s y lo nuevo aparece sin recargar. */
  const N = L.filter(c => !CAMP_VISTAS.has(c.cam_id));
  const vistas = new Set();
  const banner = N.find(c => tiene(c, 'banner') && c.MOSTRAR !== 0);
  if (banner && !$('#sgs-banner')){ campBanner(banner); vistas.add(banner.cam_id); }
  let ya = {}; try { ya = JSON.parse(sessionStorage.getItem('sgs-modal') || '{}'); } catch (e){}
  const modal = N.find(c => tiene(c, 'modal') && c.MOSTRAR !== 0 && !ya[c.cam_id]);
  if (modal && !layer().innerHTML){ setTimeout(() => { if (!layer().innerHTML){ campModal(modal); ya[modal.cam_id] = 1; try { sessionStorage.setItem('sgs-modal', JSON.stringify(ya)); } catch (e){} } }, primera ? 700 : 50); vistas.add(modal.cam_id); }
  CAMP_CARDS = L.filter(c => tiene(c, 'card'));
  CAMP_CARDS.forEach(c => vistas.add(c.cam_id));
  const zona = $('#sgs-te-interesa'); if (zona && CAMP_CARDS.length) zona.innerHTML = `<div class="sec-t" style="margin-bottom:10px">💡 Te puede interesar</div><div class="grid g2">${CAMP_CARDS.map(campCardMini).join('')}</div>`;
  if (!primera){ const nuevo = N.find(c => !vistas.has(c.cam_id) || (!banner && !modal)); if (N.length && nuevo) toast(`Nuevo: ${esc(nuevo.cam_titulo)}`, null, false); }
  vistas.forEach(id => { campEntrega(id, 'vista'); });
  L.forEach(c => CAMP_VISTAS.add(c.cam_id));
}
if (!window.__sgsCampPoll){ window.__sgsCampPoll = setInterval(() => { if (!document.hidden && CFG.clienteId && (puede('ayuda') || puede('reportar'))) cargarCampanas(); }, 30000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden && CFG.clienteId && cargarCampanas.hecha) cargarCampanas(); }); }
function campAccion(id, que){
  const c = CAMP[id]; if (!c) return;
  if (que === 'x'){ campEntrega(id, 'descarte'); closeLayer(); const b = $('#sgs-banner'); if (b && b.querySelector(`[data-campx="${id}"]`)) b.remove(); toast('Aviso cerrado.'); return; }
  if (que === 'ok'){ campEntrega(id, 'confirmacion'); closeLayer(); const b = $('#sgs-banner'); if (b && b.querySelector(`[data-campok="${id}"]`)) b.remove(); toast('Gracias. Quedó registrado que lo leíste.'); return; }
  const dest = que === 'kb' ? URL_('kb', c.cam_contenido, {origen:'campana'}) : campDest(c);
  campEntrega(id, 'interaccion').then(() => { if (!dest) { closeLayer(); return; } if (c.cam_cta_accion === 'url' && que !== 'kb') { open(dest, '_blank', 'noopener'); closeLayer(); } else location.href = dest; });
}

/* ---------- Botones de la cabecera ---------- */
document.addEventListener('click', e => {
  const t = e.target.closest && e.target.closest('[data-sgs-act]'); if (!t) return;
  e.preventDefault();
  if (t.dataset.sgsAct === 'report') openReport();
  if (t.dataset.sgsAct === 'ayuda'){ if (popEl && popAnchor === t) closePop(); else openCtxHelp(t); }
});

/* =========================================================================
   PANTALLAS DEL MÓDULO
   ========================================================================= */
const APP = {vista:null, id:null, el:null, recargar:null};
const VIEWS = {}, LOAD = {}, AFTER = {};
const S = {};          // datos de la vista actual
function render(){ if (!APP.el) return; const f = VIEWS[APP.vista]; APP.el.innerHTML = f ? f() : ''; const a = AFTER[APP.vista]; a && a(); if (window.SigmaCalendario) window.SigmaCalendario.conectar(APP.el); }
async function cargar(sk){
  if (sk !== false) APP.el.innerHTML = skeleton();
  try { await LOAD[APP.vista](); render(); }
  catch (e){ APP.el.innerHTML = empty('warn', 'tone-d', 'No pudimos cargar esta pantalla', esc(e.message), `<button type="button" class="btn out" data-act="reintentar">Reintentar</button>`); }
}
const recurBtn = r => r.sre_contenido ? `<a class="btn plain xs" href="${esc(URL_('kb', r.sre_contenido))}">${ic('book', 14)}Ya tiene ayuda</a>` : (puede('ayudaAdmin') ? `<a class="btn ghost xs" href="${esc(URL_('kwiz', null, {recurrente:r.sre_id}))}">Crear cápsula</a>` : '');
const recurDelta = r => { const d = r.NPREV ? Math.round((r.N30 - r.NPREV) / r.NPREV * 100) : (r.N30 ? 100 : 0); return {d, h:`<span class="delta ${d > 0 ? 'up' : 'ok'}">${d > 0 ? '+' : ''}${d} %</span>`}; };
const recurSerie = r => String(r.SERIE || '').split(',').map(Number).reverse();

/* ---------- 1. Centro de Soporte ---------- */
LOAD.hub = async () => { S.res = await ws('s', 'Resumen'); };
function evText(e){
  const n = e.AUTOR || 'SIGMA';
  switch (e.ste_tipo){ case 'rep': return `${n} reportó el problema`; case 'asg': return e.ste_texto; case 'st': return `Estado: ${e.DESDE_NOMBRE || ''} → ${e.HASTA_NOMBRE || ''}`; case 'req': return `${n} pidió más información`; case 'file': return `${n} adjuntó un archivo`;
    case 'com': return `${n} comentó`; case 'int': return `${n} dejó una nota interna`; case 'res': return `${n} marcó el problema como resuelto`; case 'fb': return `${n} respondió la encuesta`; default: return e.ste_texto || ''; }
}
VIEWS.hub = () => {
  const r = S.res, m = r.mesa || {}, c = r.campanas || {}, a = r.ayuda || {};
  const vis = pct(c.VISTAS, c.ALCANCE), inter = pct(c.INTERACCIONES, c.ALCANCE);
  const area = (ico, tone, t, d, cta, go, mets, foot) => `<section class="card" style="display:flex;flex-direction:column;gap:14px;padding:20px 22px">
      <div class="ch" style="margin:0"><span class="ico ${tone}" style="width:44px;height:44px;border-radius:14px">${ic(ico, 22)}</span><div class="g"><h2 style="font-size:17px">${t}</h2><p style="font-size:13px">${d}</p></div></div>
      <div class="grid g2 keep2" style="gap:8px">${mets.map(([v, l, cls]) => `<div style="background:var(--surface-2);border-radius:12px;padding:10px 12px"><b class="tnum" style="font-size:20px;font-weight:800;display:block${cls ? ';color:var(--' + cls + ')' : ''}">${v}</b><small class="mut" style="font-size:12px;font-weight:600">${l}</small></div>`).join('')}</div>
      ${foot || ''}<div style="margin-top:auto">${go ? `<a class="btn out" href="${esc(URL_(go))}">${cta}${ic('arrow', 16)}</a>` : ''}</div></section>`;
  const top = r.ayudaTop, rec = r.ayudaReciente;
  return `${crumbs([['Soporte'], ['Centro de Soporte']])}
    <div class="ph"><div class="t"><h1>Centro de Soporte</h1><p>SIGMA no solo permite trabajar: también enseña, comunica, acompaña y escucha a cada usuario.</p></div>
      <div class="acts">${puede('analitica') ? `<a class="btn out" href="${esc(URL_('analytics'))}">${ic('chart', 16)}Ver analítica</a>` : ''}${btn('pri', 'data-act="report"', 'Nuevo problema', 'plus')}</div></div>
    <div class="grid g3">
      ${area('inbox', 'tone-p', 'Problemas detectados', 'Reporta, gestiona y realiza seguimiento de problemas informados por los usuarios.', 'Ver problemas', 'tickets',
        [[num(m.ABIERTOS), 'Tickets abiertos'], [num(m.CRITICOS), 'Críticos y altos', m.CRITICOS ? 'danger' : ''], [num(m.ESPERANDO), 'Esperando usuario'], [m.RESOLUCION_MIN != null ? dur(m.RESOLUCION_MIN) : '—', 'Resolución promedio']])}
      ${area('mega', 'tone-b', 'Campañas', 'Crea comunicaciones dirigidas para informar novedades, cambios y contenidos a tus usuarios.', 'Ver campañas', puede('campanas') ? 'campaigns' : '',
        [[num(c.ACTIVAS), 'Campañas activas'], [num(c.ALCANCE), 'Usuarios alcanzados'], [vis + ' %', 'Visualizaciones'], [inter + ' %', 'Interacciones']])}
      ${area('book', 'tone-c', 'Centro de ayuda', 'Manuales, videos, cápsulas y guías para ayudar a los usuarios directamente dentro de SIGMA.', 'Explorar ayuda', 'help',
        [[num(a.PUBLICADOS), 'Contenidos disponibles'], [num(a.VISTAS30), 'Visualizaciones (30 días)']],
        top ? `<div class="rows"><a class="row" href="${esc(URL_('kb', top.ayc_id))}"><span class="ico ${KIND[top.ayc_tipo].c}">${ic(KIND[top.ayc_tipo].i, 17)}</span><span style="min-width:0"><small>Más consultado</small><strong>${esc(top.ayc_titulo)}</strong></span><span class="e tnum mut" style="font-size:12px">${num(top.VISTAS)}</span></a>
          ${rec ? `<a class="row" href="${esc(URL_('kb', rec.ayc_id))}"><span class="ico ${KIND[rec.ayc_tipo].c}">${ic(KIND[rec.ayc_tipo].i, 17)}</span><span style="min-width:0"><small>Reciente · ${fDs(D(rec.ayc_fecha_actualizacion))}</small><strong>${esc(rec.ayc_titulo)}</strong></span><span class="e">${ic('cr', 16)}</span></a>` : ''}</div>` : '')}
    </div>
    <section class="card">
      <div class="ch"><span class="ico tone-p">${ic('reopen', 20)}</span><div class="g"><h2>Un solo ciclo de aprendizaje</h2><p>Cada problema enseña algo. Lo que se repite se convierte en contenido, y el contenido llega a las personas correctas.</p></div></div>
      <div class="loop">${[['user','tone-b','Usuario','Tiene una duda o un problema y pide ayuda desde la pantalla donde está.'],['book','tone-c','Centro de ayuda','Antes de reportar, SIGMA le sugiere la cápsula o el manual de esa pantalla.'],['inbox','tone-p','Soporte','Si sigue el problema, la mesa de ayuda lo atiende con todo el contexto.'],['bulb','tone-w','Conocimiento','Lo que se repite se convierte en una cápsula o un artículo.'],['mega','tone-s','Campañas','Se anuncia a quienes lo necesitan y se mide si sirvió.']].map(([i, t, b, p]) => `<div><span class="ico ${t}">${ic(i, 18)}</span><b>${b}</b>${p}</div>`).join('')}</div>
    </section>
    <div class="split">
      <section class="card">${chdr('activity', 'tone-b', 'Actividad reciente', 'Lo último que pasó en la mesa de ayuda.', `<a class="link" href="${esc(URL_('tickets'))}">Ver bandeja${ic('arrow', 14)}</a>`)}
        ${r.actividad.length ? `<div class="rows">${r.actividad.map(e => `<a class="row" href="${esc(URL_('ticket', e.stk_id))}">${avatar(e.ste_usuario, e.AUTOR, '')}<span style="min-width:0"><strong>${esc(evText(e))}</strong><small>${esc(e.stk_folio)} · ${esc(e.stk_titulo)}</small></span><span class="e mut" style="font-size:12px">${ago(D(e.ste_fecha))}</span></a>`).join('')}</div>`
          : empty('inbox', 'tone-n', 'Todavía no hay actividad', 'Cuando los usuarios reporten problemas, los verás aquí.', btn('pri sm', 'data-act="report"', 'Nuevo problema', 'plus'))}</section>
      <section class="card">${chdr('bulb', 'tone-w', 'Convierte problemas en conocimiento', 'Problemas que se repiten este mes.')}
        ${r.recurrentes.length ? `<div class="rows">${r.recurrentes.slice(0, 3).map(x => `<div class="row"><span class="ico tone-w">${ic('reopen', 17)}</span><span style="min-width:0"><strong>«${esc(x.sre_titulo)}»</strong><small>${num(x.N30)} tickets · ${recurDelta(x).h} este mes</small></span><span class="e">${x.sre_contenido ? `<a class="link" href="${esc(URL_('kb', x.sre_contenido))}">Ver ayuda</a>` : recurBtn(x)}</span></div>`).join('')}</div>`
          : empty('bulb', 'tone-n', 'Sin problemas recurrentes', 'Aparecen cuando 5 o más tickets se parecen en módulo, pantalla y categoría.')}
      </section>
    </div>`;
};

/* ---------- 2. Bandeja: Problemas detectados ---------- */
const TF = {tab:'todos', q:'', f:{}, pag:1};
const POR_PAG = 30;
LOAD.tickets = async () => { const [b, r, a] = await Promise.all([ws('s', 'Bandeja', {soloMios:false}), ws('s', 'Resumen'), ws('s', 'Agentes')]); S.T = b.tickets.map(TK); S.res = r; S.ag = a; };
const uniq = (arr) => [...new Set(arr.filter(Boolean))].sort((a, b) => a.localeCompare(b, 'es'));
const FILTERS = [['st','Estado',() => ST_ORDER.map(k => [k, ST[k].l])],['prio','Prioridad',() => Object.entries(PR).map(([k, v]) => [k, v.l])],['cat','Categoría',() => CATS.map(([k, l]) => [k, l])],
  ['cliente','Cliente',() => uniq(S.T.map(t => t.cliente)).map(c => [c, c])],['planta','Planta',() => uniq(S.T.map(t => t.planta)).map(c => [c, c])],
  ['user','Usuario',() => uniq(S.T.map(t => t.user.n)).map(c => [c, c])],['perfil','Perfil',() => uniq(S.T.flatMap(t => t.perfil.split(', '))).map(c => [c, c])],
  ['area','Área responsable',() => S.ag.areas.map(a => [a.sar_nombre, a.sar_nombre])],['resp','Responsable',() => [...S.ag.agentes.map(a => [String(a.usu_id), a.NOMBRE]), ['none','Sin asignar']]],
  ['mod','Módulo',() => uniq(S.T.map(t => t.mod)).map(c => [c, c])],['fecha','Fecha',() => [['hoy','Hoy'],['7','Últimos 7 días'],['30','Últimos 30 días']]],['sla','SLA',() => [['venc','Vencido'],['riesgo','Por vencer'],['ok','En plazo']]]];
function tkMatch(t){
  const tab = TF.tab, cerrado = !t.abierto;
  if (tab === 'mis' && (!t.resp || t.resp.id !== CFG.usuario || cerrado)) return false;
  if (tab === 'sin' && (t.resp || cerrado)) return false;
  if (tab === 'crit' && !(['c','a'].includes(t.prio) && !cerrado)) return false;
  if (tab === 'esp' && t.st !== 'esp') return false;
  if (tab === 'cer' && !cerrado) return false;
  if (tab === 'todos' && t.st === 'cer') return false;
  const q = norm(TF.q.trim());
  if (q && !norm([t.folio, t.t, t.user.n, t.cliente, t.planta, t.mod, t.pant, t.reg, CAT[t.cat] ? CAT[t.cat].l : ''].join(' ')).includes(q)) return false;
  for (const [k, vals] of Object.entries(TF.f)){ if (!vals.length) continue;
    if (k === 'fecha'){ const d = (Date.now() - t.created) / 864e5; if (!vals.some(v => v === 'hoy' ? d < 1 : d <= +v)) return false; continue; }
    if (k === 'sla'){ const s = slaOf(t); const c = s.cls === 'd' ? 'venc' : s.cls === 'w' ? 'riesgo' : 'ok'; if (!vals.includes(c)) return false; continue; }
    if (k === 'perfil'){ if (!vals.some(v => t.perfil.split(', ').includes(v))) return false; continue; }
    const val = k === 'user' ? t.user.n : k === 'resp' ? (t.resp ? String(t.resp.id) : 'none') : t[k];
    if (!vals.includes(val)) return false; }
  return true;
}
VIEWS.tickets = () => {
  const T = S.T, m = S.res.mesa || {};
  const open = T.filter(t => t.abierto);
  const tabs = [['todos','Todos', T.filter(t => t.st !== 'cer').length],['mis','Mis tickets', open.filter(t => t.resp && t.resp.id === CFG.usuario).length],['sin','Sin asignar', open.filter(t => !t.resp).length],['crit','Críticos', open.filter(t => ['c','a'].includes(t.prio)).length],['esp','Esperando usuario', T.filter(t => t.st === 'esp').length],['cer','Cerrados', T.filter(t => !t.abierto).length]];
  const list = T.filter(tkMatch).sort((a, b) => (b.unread - a.unread) || ('cabm'.indexOf(a.prio) - 'cabm'.indexOf(b.prio)) || (b.upd - a.upd));
  const pags = Math.max(1, Math.ceil(list.length / POR_PAG)); if (TF.pag > pags) TF.pag = pags;
  const vis = list.slice((TF.pag - 1) * POR_PAG, TF.pag * POR_PAG);
  const active = Object.entries(TF.f).filter(([k, v]) => v.length);
  const prev = m.RESOLUCION_PREV_MIN, cur = m.RESOLUCION_MIN; const dRes = prev && cur ? Math.round(cur - prev) : null;
  return `${crumbs([['Soporte','hub'], ['Problemas detectados']])}
    <div class="ph"><div class="t"><h1>Problemas detectados</h1><p>Gestiona, asigna y realiza seguimiento de los problemas reportados por los usuarios.</p></div>
      <div class="acts">${puede('analitica') ? `<a class="btn out" href="${esc(URL_('analytics'))}">${ic('chart', 16)}Analítica</a>` : ''}${btn('pri', 'data-act="report"', 'Nuevo problema', 'plus')}</div></div>
    <div class="grid g5 keep2">
      ${kpi('inbox', 'tone-p', num(open.length), 'Abiertos', `${open.filter(t => !t.resp).length} sin asignar`)}
      ${kpi('warn', 'tone-d', num(open.filter(t => ['c','a'].includes(t.prio)).length), 'Críticos', 'Alta y crítica')}
      ${kpi('clock', 'tone-c', num(T.filter(t => t.st === 'esp').length), 'Esperando usuario', 'Pausan el SLA')}
      ${kpi('smile', 'tone-s', m.CSAT != null ? m.CSAT + ' %' : '—', 'CSAT', m.ENCUESTAS ? `${num(m.ENCUESTAS)} encuestas · 30 días` : 'Sin encuestas aún')}
      ${kpi('zap', 'tone-b', cur != null ? dur(cur) : '—', 'Resolución promedio', dRes == null ? 'Últimos 30 días' : `<span class="delta ${dRes > 0 ? 'up' : 'ok'}">${dRes > 0 ? '+' : '−'}${dur(dRes)}</span> vs. mes anterior`)}
    </div>
    <section class="card pad0" style="padding:4px 18px 18px">
      <div class="tabs" role="tablist" aria-label="Bandejas">${tabs.map(([k, l, n]) => `<button type="button" role="tab" data-tftab="${k}" aria-selected="${TF.tab === k}">${l}<b>${n}</b></button>`).join('')}</div>
      <div class="toolbar" style="margin:14px 0 10px"><label class="search"><span class="sr">Buscar tickets</span>${ic('search', 18)}<input id="tq" value="${esc(TF.q)}" placeholder="Buscar por ticket, usuario, problema, cliente…" autocomplete="off"></label></div>
      <div class="toolbar" style="margin-bottom:14px">${FILTERS.map(([k, l]) => { const n = (TF.f[k] || []).length; const one = n === 1 ? (FILTERS.find(f => f[0] === k)[2]().find(o => o[0] === TF.f[k][0]) || [, TF.f[k][0]])[1] : n; return `<button type="button" class="fbtn${n ? ' on' : ''}" data-filt="${k}" aria-haspopup="true">${n ? '' : ic('plus', 14)}${l}${n ? ` · ${esc(one)}` : ''}${n ? ic('cd', 14) : ''}</button>`; }).join('')}
        ${active.length || TF.q ? `<button type="button" class="link" data-act="clearf">Limpiar filtros</button>` : ''}</div>
      ${vis.length ? `<div class="tk-head" aria-hidden="true"><span>Problema</span><span class="c-who">Reportado por</span><span class="c-resp">Responsable</span><span class="c-st">Estado · SLA</span><span></span></div>
        <div class="rows" style="gap:8px;margin-top:6px">${vis.map(tkRow).join('')}</div>
        <div class="toolbar" style="justify-content:space-between;margin-top:14px;font-size:12.5px;color:var(--muted)"><span>Mostrando ${(TF.pag - 1) * POR_PAG + 1}–${(TF.pag - 1) * POR_PAG + vis.length} de ${list.length}</span>${pags > 1 ? `<div class="seg" role="group" aria-label="Páginas">${TF.pag > 1 ? `<button type="button" data-tfpag="${TF.pag - 1}" aria-label="Anterior">${ic('cl', 14)}</button>` : ''}${Array.from({length:pags}, (_, i) => i + 1).filter(p => Math.abs(p - TF.pag) < 3 || p === 1 || p === pags).map(p => `<button type="button" data-tfpag="${p}" aria-pressed="${p === TF.pag}">${p}</button>`).join('')}${TF.pag < pags ? `<button type="button" data-tfpag="${TF.pag + 1}" aria-label="Siguiente">${ic('cr', 14)}</button>` : ''}</div>` : ''}</div>`
        : (!T.length ? empty('inbox', 'tone-s', 'No hay tickets', 'Nadie ha reportado problemas. Cuando ocurra, llegarán aquí con su contexto.', btn('pri', 'data-act="report"', 'Nuevo problema', 'plus'))
          : TF.tab === 'mis' && !active.length && !TF.q ? empty('user', 'tone-p', 'No tienes problemas asignados', 'Toma uno de la bandeja «Sin asignar» o espera a que la mesa de ayuda te asigne.', `<button type="button" class="btn out" data-tftab="sin">Ver sin asignar</button>`)
          : empty('search', 'tone-n', 'No encontramos resultados', `Ningún ticket coincide con «${esc(TF.q || 'los filtros')}». Prueba con otro número, usuario o módulo.`, `<button type="button" class="btn out" data-act="clearf">Limpiar búsqueda y filtros</button>`))}
    </section>`;
};
function tkRow(t){
  const s = slaOf(t);
  return `<a class="tk p-${t.prio}" href="${esc(URL_('ticket', t.id))}">
    <span style="min-width:0"><span class="id">${t.unread ? '<span class="unread" title="Con novedades"></span>' : ''}${esc(t.folio)}${prChip(t.prio)}${t.recur ? `<span class="tag" title="Parte de un problema recurrente">${ic('reopen', 13)}Recurrente</span>` : ''}</span>
      <h3>${esc(t.t)}</h3><span class="meta"><span>${ic(CAT[t.cat] ? CAT[t.cat].i : 'more', 14)}${esc(t.mod)}</span><span>${ic('clock', 14)}Actualizado ${ago(t.upd)}</span></span>
      <span class="m-st" style="display:none;gap:8px;margin-top:8px;flex-wrap:wrap">${stChip(t.st)}<span class="sla ${s.cls}">${ic(s.pausa ? 'pause' : 'clock', 13)}${s.l}</span></span></span>
    <span class="who c-who">${avatar(t.user.id, t.user.n)}<span style="min-width:0"><b>${esc(t.user.n)}</b><small>${esc(t.cliente)}${t.planta ? ' · Planta ' + esc(t.planta) : ''}</small></span></span>
    <span class="who c-resp">${t.resp ? `${avatar(t.resp.id, t.resp.n)}<span style="min-width:0"><b>${esc(t.resp.n)}</b><small>${esc(t.area)}</small></span>` : `<span class="tag" style="color:var(--warning-ink);background:var(--warning-soft)">Sin asignar</span>`}</span>
    <span class="st c-st">${stChip(t.st)}<span class="sla ${s.cls}">${ic(s.pausa ? 'pause' : 'clock', 13)}${s.l}</span></span>
    <span class="go">${ic('cr', 18)}</span></a>`;
}
let fmenu = null;
function openFmenu(k, anchor){
  closeFmenu(); const def = FILTERS.find(f => f[0] === k); const cur = TF.f[k] || [];
  fmenu = document.createElement('div'); fmenu.className = 'fmenu'; fmenu.dataset.k = k; fmenu.setAttribute('role', 'group'); fmenu.setAttribute('aria-label', def[1]);
  const ops = def[2]();
  fmenu.innerHTML = ops.length ? ops.map(([v, l]) => `<label><input type="checkbox" value="${esc(v)}"${cur.includes(v) ? ' checked' : ''}>${k === 'st' ? stChip(v) : k === 'prio' ? prChip(v) : esc(l)}</label>`).join('') : '<p class="mut" style="padding:10px;font-size:12.5px">Sin opciones.</p>';
  capa().appendChild(fmenu); const r = anchor.getBoundingClientRect(); fmenu.style.position = 'fixed'; fmenu.style.left = Math.max(12, Math.min(innerWidth - fmenu.offsetWidth - 12, r.left)) + 'px'; fmenu.style.top = (r.bottom + 6) + 'px';
  const f = fmenu.querySelector('input'); f && f.focus();
}
function closeFmenu(){ if (fmenu){ fmenu.remove(); fmenu = null; } }
addEventListener('scroll', () => { if (fmenu) closeFmenu(); }, {passive:true});

/* ---------- 3. Detalle 360 del ticket (soporte) y vista del usuario ---------- */
const TD = {flt:'todo', mode:'pub', draft:'', kb:null};
LOAD.ticket = async () => {
  const d = await ws('s', 'Ticket', {id:APP.id}); S.d = d; S.t = TK(d.ticket);
  if (d.ticket.PUEDE_GESTIONAR && !S.ag){ try { S.ag = await ws('s', 'Agentes'); } catch (e){ S.ag = {agentes:[], areas:[]}; } }
};
const gestiona = () => S.d && S.d.ticket && S.d.ticket.PUEDE_GESTIONAR;
VIEWS.ticket = () => gestiona() ? vTicketSoporte() : vTicketUsuario();
function fileChip(e){ const k = tipoArch(e.ste_archivo_nombre); return `<span class="tl-file"><span class="th">${k === 'img' && e.ARCHIVO_URL ? `<img src="${esc(e.ARCHIVO_URL)}" alt="" style="width:100%;height:100%;object-fit:cover;border-radius:8px">` : ic(k === 'video' ? 'video' : 'doc', 18)}</span><span><b>${esc(e.ste_archivo_nombre || 'Archivo')}</b><small>${e.ste_archivo_byte ? pesoTxt(e.ste_archivo_byte) : ''}</small></span>${e.ARCHIVO_URL ? `<a class="ibtn" href="${esc(e.ARCHIVO_URL)}" target="_blank" rel="noopener" aria-label="Ver ${esc(e.ste_archivo_nombre)}">${ic('eye', 16)}</a><a class="ibtn" href="${esc(e.ARCHIVO_BAJAR)}" aria-label="Descargar ${esc(e.ste_archivo_nombre)}">${ic('down', 16)}</a>` : ''}</span>`; }
const kbMini = e => `<a class="row" href="${esc(URL_('kb', e.ste_contenido, {origen:'ticket'}))}" style="background:#fff;box-shadow:var(--e1)"><span class="ico ${KIND[e.CONTENIDO_TIPO].c}">${ic(KIND[e.CONTENIDO_TIPO].i, 17)}</span><span style="min-width:0"><strong>${esc(e.CONTENIDO_TITULO)}</strong><small>${KIND[e.CONTENIDO_TIPO].l}${e.CONTENIDO_DURACION ? ' · ' + esc(e.CONTENIDO_DURACION) + ' min' : ''}</small></span><span class="e">${ic('cr', 16)}</span></a>`;
function evHTML(e){
  const sys = e.ste_usuario == null; const sop = !!e.ste_es_soporte; const usr = !sys && !sop;
  const kind = {rep:['flag','tone-b','Reportó el problema'], com:['chat', usr ? 'tone-b' : 'tone-p', 'Comentario'], req:['help','tone-p','Solicitó información'], file:['clip', usr ? 'tone-b' : 'tone-p','Adjuntó un archivo'], st:['swap','tone-n','Cambio de estado'], asg:['user','tone-n','Cambio de asignación'], int:['note','tone-w','Nota interna · solo soporte'], res:['check','tone-s','Resolución'], fb:['smile','tone-s','Encuesta'], prio:['flag','tone-n','Prioridad'], sys:['sys','tone-n','Sistema']}[e.ste_tipo] || ['sys','tone-n',''];
  const tag = sys ? ['Sistema','background:var(--canvas);color:var(--muted)'] : usr ? ['Usuario','background:var(--sigma-blue-soft);color:var(--sigma-blue-dark)'] : ['Soporte','background:var(--sigma-purple-soft);color:var(--sigma-purple)'];
  let body = '';
  if (e.ste_tipo === 'st') body = `<div class="tl-chg">${stChip(e.ste_estado_desde)}${ic('arrow', 14)}${stChip(e.ste_estado_hasta)}</div>`;
  else if (e.ste_tipo === 'file') body = fileChip(e);
  else if (e.ste_tipo === 'res') body = `<div class="tl-res"><b style="display:block;margin-bottom:2px">Solución</b>${esc(e.ste_texto)}</div>`;
  else if (['rep','com','req','int'].includes(e.ste_tipo)) body = `<div class="tl-q">${e.ste_tipo === 'rep' ? '«' + esc(e.ste_texto) + '»' : esc(e.ste_texto).replace(/\n/g, '<br>')}${e.ste_contenido && e.CONTENIDO_TITULO ? `<div style="margin-top:8px">${kbMini(e)}</div>` : ''}</div>`;
  else body = `<div class="tl-t">${esc(e.ste_texto)}</div>${e.ste_contenido && e.CONTENIDO_TITULO && e.ste_tipo === 'sys' ? `<div style="margin-top:8px;max-width:420px">${kbMini(e)}</div>` : ''}`;
  return `<div class="tl-i ${sys ? 'is-sys' : usr ? 'is-user' : ''}${e.ste_tipo === 'int' ? ' is-int' : ''}"><span class="tl-dot ${kind[1]}">${ic(kind[0], 18)}</span>
    <div class="tl-c"><div class="tl-h"><b>${esc(sys ? 'SIGMA' : e.AUTOR)}</b><span class="who-t" style="${tag[1]}">${tag[0]}</span><span>${kind[2]}</span><span>·</span><time>${fDT(D(e.ste_fecha))}</time></div>${body}</div></div>`;
}
function feedbackCard(){
  const t = S.t, c = S.d.encuesta;
  if (!c) return t.st === 'res' ? `<section class="card" style="background:var(--success-soft);box-shadow:none">${chdr('smile', 'tone-s', 'Esperando la opinión de ' + esc(t.user.n.split(' ')[0]), 'Se envió la encuesta «¿Tu problema fue solucionado?».')}</section>` : '';
  const lbl = {si:'Sí', parcial:'Parcialmente', no:'No'}[c.sen_respuesta]; const tn = c.sen_respuesta === 'no' ? 'tone-d' : c.sen_respuesta === 'parcial' ? 'tone-w' : 'tone-s';
  return `<section class="card">${chdr(c.sen_respuesta === 'no' ? 'frown' : c.sen_respuesta === 'parcial' ? 'meh' : 'smile', tn, 'Opinión del usuario', `${esc(t.user.n)} · ${fDT(D(c.sen_fecha))}`)}
    <div style="display:flex;align-items:center;gap:16px;flex-wrap:wrap"><span class="chip ${tn}"><i></i>¿Se solucionó? ${lbl}</span><span style="color:#F2A900;letter-spacing:2px;font-size:16px" aria-label="${c.sen_estrellas} de 5 estrellas">${'★'.repeat(c.sen_estrellas)}<span style="color:#D4D9E4">${'★'.repeat(5 - c.sen_estrellas)}</span></span><span class="mut" style="font-size:12.5px">CSAT registrado · responsable ${esc(c.RESPONSABLE || '—')}</span></div>
    ${c.sen_comentario ? `<p class="tl-q" style="margin-top:10px">«${esc(c.sen_comentario)}»</p>` : ''}</section>`;
}
function replyBox(){
  const t = S.t;
  return `<div class="reply${TD.mode === 'int' ? ' int' : ''}" style="margin-top:6px">
    <div class="rt" role="group" aria-label="Tipo de mensaje"><button type="button" data-tdm="pub" aria-pressed="${TD.mode === 'pub'}">${ic('chat', 15)} Responder al usuario</button><button type="button" class="int" data-tdm="int" aria-pressed="${TD.mode === 'int'}">${ic('note', 15)} Nota interna</button></div>
    <label class="sr" for="tdText">Mensaje</label><textarea id="tdText" placeholder="${TD.mode === 'int' ? 'Solo lo verá el equipo de soporte…' : 'Escribe tu respuesta a ' + esc(t.user.n.split(' ')[0]) + '…'}">${esc(TD.draft)}</textarea>
    ${TD.kb ? `<div style="padding:0 12px 6px"><span class="tag tone-p">${ic('book', 12)}Se adjunta: ${esc(TD.kbT)}<button type="button" class="ibtn" style="width:20px;height:20px" data-act="quitarkb" aria-label="Quitar">${ic('x', 12)}</button></span></div>` : ''}
    <div class="rb"><label class="ibtn" aria-label="Adjuntar archivo" data-tip="Adjuntar archivo" style="cursor:pointer">${ic('clip', 18)}<input type="file" class="sr" data-adjuntar="${t.id}"></label><button type="button" class="ibtn" data-act="insertkb" aria-label="Insertar contenido de ayuda" data-tip="Insertar cápsula o manual">${ic('book', 18)}</button>
      <label style="display:inline-flex;align-items:center;gap:6px;font-size:12.5px;color:var(--muted);margin-left:4px">${TD.mode === 'pub' ? `<input type="checkbox" id="tdAsk" style="accent-color:var(--sigma-purple)"> Pedir información (pausa el SLA)` : ''}</label>
      <span class="g"></span><button type="button" class="btn ${TD.mode === 'int' ? 'sec' : 'pri'} sm" data-act="send">${ic('send', 15)}${TD.mode === 'int' ? 'Guardar nota' : 'Enviar'}</button></div></div>`;
}
function vTicketSoporte(){
  const t = S.t, d = S.d, k = d.ticket, s = slaOf(t), r = d.recurrente;
  const evs = d.eventos.filter(e => TD.flt === 'todo' || (TD.flt === 'conv' ? ['rep','com','req','res','fb'].includes(e.ste_tipo) : TD.flt === 'cambios' ? ['st','asg','sys','prio'].includes(e.ste_tipo) : TD.flt === 'arch' ? e.ste_tipo === 'file' : e.ste_tipo === 'int'));
  const archivos = d.eventos.filter(e => e.ste_tipo === 'file' && e.ste_usuario === t.user.id).slice(0, 4);
  const prim = k.PRIMERA_RESPUESTA_MIN;
  return `${crumbs([['Soporte','hub'], ['Problemas detectados','tickets'], [t.folio]])}
    <header class="card" style="display:flex;gap:16px;align-items:flex-start;flex-wrap:wrap;padding:20px 22px">
      <div style="flex:1;min-width:260px">
        <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;font-size:12px;font-weight:800;color:var(--muted)">${esc(t.folio)}<span>·</span>${ic(CAT[t.cat].i, 14)}${CAT[t.cat].l}${r ? `<button type="button" class="tag" data-act="recur" data-id="${r.sre_id}" style="border:0;cursor:pointer">${ic('reopen', 13)}Problema recurrente · ${num(r.N)} tickets</button>` : ''}</div>
        <h1 style="font-size:24px;font-weight:800;letter-spacing:-.02em;margin:6px 0 10px;text-wrap:balance">${esc(t.t)}</h1>
        <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">${prChip(t.prio)}${stChip(t.st)}<span class="sla ${s.cls}" style="margin-left:4px">${ic(s.pausa ? 'pause' : 'clock', 14)}${s.l}</span></div>
      </div>
      ${t.st === 'cer' ? '' : `<div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">
        <button type="button" class="btn sec" data-act="assign">${ic('user', 16)}${t.resp ? 'Reasignar' : 'Asignar'}</button>
        <button type="button" class="btn pri" data-act="chstate" aria-haspopup="true">${ic('swap', 16)}Cambiar estado${ic('cd', 14)}</button>
        <button type="button" class="btn plain" data-act="moreacts" aria-haspopup="true">${ic('more', 18)}<span>Más acciones</span></button></div>`}
    </header>
    <div class="split wide">
      <div style="display:flex;flex-direction:column;gap:16px;min-width:0">
        <section class="card">${chdr('user', 'tone-b', 'Lo que reportó ' + esc(t.user.n.split(' ')[0]), fDT(t.created) + ' · desde ' + esc(t.pant))}
          <p style="font-size:14px;line-height:1.6">${esc(k.stk_descripcion || t.t).replace(/\n/g, '<br>')}</p>
          ${archivos.length ? `<div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:12px">${archivos.map(fileChip).join('')}</div>` : ''}
          <div class="ctx-card" style="margin-top:14px"><div class="sec-t" style="margin-bottom:8px;display:flex;align-items:center;gap:6px">${ic('target', 14)}Contexto detectado automáticamente</div>
            <div class="grid g4 keep2" style="gap:8px">${[['Módulo', t.mod], ['Pantalla', t.pant], ['Registro', t.reg], ['Navegador', k.stk_navegador || '—']].map(([l, v]) => `<div style="min-width:0"><small class="mut" style="display:block;font-size:11.5px">${l}</small><b style="font-size:13px;overflow-wrap:anywhere">${esc(v)}</b></div>`).join('')}</div>
            ${k.stk_ruta ? `<p style="margin-top:8px;font-size:12px"><a class="link" style="margin:0;padding:0" href="${esc(k.stk_ruta)}" target="_blank" rel="noopener">${ic('ext', 13)}Abrir la pantalla donde ocurrió</a></p>` : ''}</div>
        </section>
        ${['res','cer'].includes(t.st) || d.encuesta ? feedbackCard() : ''}
        <section class="card">${chdr('history', 'tone-p', 'Trazabilidad', 'Cada acción queda registrada con quién, qué y cuándo. No se edita ni se borra.', `<div class="seg" role="group" aria-label="Filtrar línea de tiempo">${[['todo','Todo'],['conv','Conversación'],['cambios','Cambios'],['arch','Archivos'],['int','Notas internas']].map(([k2, l]) => `<button type="button" data-tdf="${k2}" aria-pressed="${TD.flt === k2}">${l}</button>`).join('')}</div>`)}
          <div class="legend" style="margin:-4px 0 14px"><span><i style="background:var(--sigma-blue)"></i>Usuario</span><span><i style="background:var(--sigma-purple)"></i>Soporte</span><span><i style="background:var(--faint)"></i>Sistema</span><span><i style="background:var(--warning)"></i>Nota interna</span><span><i style="background:var(--success)"></i>Resolución</span></div>
          ${evs.length ? `<div class="tl">${evs.map(evHTML).join('')}</div>` : `<p class="mut" style="font-size:13px;padding:8px 0">No hay eventos de este tipo.</p>`}
          ${t.st === 'cer' ? '' : replyBox()}
        </section>
      </div>
      <aside style="display:flex;flex-direction:column;gap:16px;min-width:0">
        <section class="card">${chdr('list', 'tone-n', 'Detalles', '')}
          <dl class="dl">
            <dt>Usuario</dt><dd>${avatar(t.user.id, t.user.n, 'xs')}${esc(t.user.n)}</dd><dt>Cliente</dt><dd>${esc(t.cliente)}</dd><dt>Planta</dt><dd>${esc(t.planta || '—')}</dd><dt>Perfil</dt><dd>${esc(t.perfil || '—')}</dd>
            <dt>Módulo</dt><dd>${esc(t.mod)}</dd><dt>Pantalla</dt><dd>${esc(t.pant)}</dd><dt>Registro</dt><dd>${esc(t.reg)}</dd>
            <dt>Categoría</dt><dd>${CAT[t.cat].l}</dd><dt>Prioridad</dt><dd>${prChip(t.prio)}</dd><dt>Creado</dt><dd>${fDT(t.created)}</dd><dt>Actualizado</dt><dd>${ago(t.upd)}</dd>
            <dt>Responsable</dt><dd>${t.resp ? avatar(t.resp.id, t.resp.n, 'xs') + esc(t.resp.n) : '<span class="tag" style="color:var(--warning-ink);background:var(--warning-soft)">Sin asignar</span>'}</dd><dt>Área</dt><dd>${esc(t.area)}</dd>
          </dl></section>
        <section class="card">${chdr('clock', s.cls === 'd' ? 'tone-d' : s.cls === 'w' ? 'tone-w' : 'tone-s', 'SLA', `Prioridad ${PR[t.prio].l.toLowerCase()}: resolver en ${PR[t.prio].h} h`)}
          <div class="sla-box"><div style="display:flex;justify-content:space-between;font-size:12.5px"><span>Primera respuesta</span><b style="color:${prim != null ? 'var(--success)' : 'var(--muted)'}">${prim != null ? ic('check', 14) + ' ' + dur(prim) : 'Pendiente'}</b></div></div>
          <div class="sla-box" style="margin-top:8px"><div style="display:flex;justify-content:space-between;font-size:12.5px;gap:8px"><span>Resolución</span><b class="sla ${s.cls}">${s.l}</b></div><div class="bar"><span style="width:${s.pct}%;background:${s.cls === 'd' ? 'var(--danger)' : s.cls === 'w' ? 'var(--warning)' : 'var(--success)'}"></span></div>${t.st === 'esp' ? '<p class="mut" style="font-size:12px;margin-top:6px">En pausa mientras esperamos al usuario.</p>' : ''}</div></section>
        <section class="card">${chdr('book', 'tone-c', 'Ayuda relacionada', 'Para compartir con el usuario o revisar.')}
          ${d.ayuda.length ? `<div class="rows">${d.ayuda.map(x => `<div class="row"><span class="ico ${KIND[x.ayc_tipo].c}">${ic(KIND[x.ayc_tipo].i, 17)}</span><span style="min-width:0"><strong>${esc(x.ayc_titulo)}</strong><small>${KIND[x.ayc_tipo].l}${x.ayc_duracion ? ' · ' + esc(x.ayc_duracion) : x.ayc_paginas ? ' · ' + x.ayc_paginas + ' págs.' : ''}</small></span><span class="e">${t.st === 'cer' ? '' : `<button type="button" class="btn ghost xs" data-act="sharekb" data-id="${x.ayc_id}" data-t="${esc(x.ayc_titulo)}" data-k="${x.ayc_tipo}">Compartir</button>`}</span></div>`).join('')}</div>` : '<p class="mut" style="font-size:12.5px">Aún no hay contenido para este módulo.</p>'}
          ${r && !r.sre_contenido ? `<div style="margin-top:12px;display:flex;gap:10px;padding:12px;border-radius:12px;background:var(--warning-soft);color:#6B4300;font-size:12.5px">${ic('bulb', 18)}<span>Este problema se repite: <b>${num(r.N)} tickets</b> este mes. ${puede('ayudaAdmin') ? `<a class="link" href="${esc(URL_('kwiz', null, {recurrente:r.sre_id}))}" style="margin:0;padding:0;color:var(--warning-ink)">Convertirlo en cápsula</a>` : ''}</span></div>` : ''}
        </section>
        <section class="card">${chdr('user', 'tone-b', 'Lo que ve ' + esc(t.user.n.split(' ')[0]), 'Así le llegan las respuestas en SIGMA. Las notas internas no.')}
          <button type="button" class="btn out sm" data-act="asuser" style="width:100%">${ic('eye', 16)}Ver como usuario</button></section>
      </aside>
    </div>`;
}
function vTicketUsuario(preview){
  const t = S.t, d = S.d;
  const pub = d.eventos.filter(e => !e.ste_interno);
  const ask = t.st === 'esp'; const fb = t.st === 'res' && !d.encuesta;
  const idx = ['rep','rev'].includes(t.st) ? 0 : t.st === 'asg' ? 1 : ['ana','esp','dev','rea'].includes(t.st) ? 2 : 3;
  return `${preview ? '' : crumbs([['Soporte'], ['Mis problemas','umine'], [t.folio]])}
    <header class="card" style="padding:20px 22px"><span class="mut" style="font-size:12px;font-weight:800">${esc(t.folio)} · ${esc(t.mod)} › ${esc(t.pant)}</span><h1 style="font-size:22px;font-weight:800;margin:4px 0 12px">${esc(t.t)}</h1>
      <div class="meter" style="height:8px" role="img" aria-label="Avance">${[0,1,2,3].map(i => `<span style="flex:1;background:${i <= idx ? 'var(--sigma-purple)' : '#E7EAF2'}"></span>`).join('')}</div>
      <div style="display:grid;grid-template-columns:repeat(4,1fr);font-size:11.5px;font-weight:700;margin-top:6px">${['Recibido','Asignado','Trabajando','Resuelto'].map((l, i) => `<span style="color:${i <= idx ? 'var(--sigma-purple)' : 'var(--muted)'}">${l}</span>`).join('')}</div>
      <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:12px">${stChip(t.st)}${t.resp ? `<span class="tag">${ic('user', 12)}Te atiende ${esc(t.resp.n)}</span>` : ''}</div></header>
    ${fb ? `<section class="card" style="background:var(--success-soft);box-shadow:none;display:flex;gap:14px;align-items:center;flex-wrap:wrap"><span style="color:var(--success)">${ic('smile', 30)}</span><div style="flex:1;min-width:200px"><b>¿Tu problema fue solucionado?</b><p style="font-size:12.5px;color:#0E5C3E">Cuéntanos en 10 segundos. Si no se solucionó, puedes reabrirlo.</p></div>${preview ? '' : btn('pri', 'data-act="feedback"', 'Responder')}</section>` : ''}
    ${d.encuesta ? feedbackCard() : ''}
    ${ask ? `<section class="card" style="background:var(--sigma-purple-soft);box-shadow:none;display:flex;gap:12px;align-items:center;flex-wrap:wrap"><span style="color:var(--sigma-purple)">${ic('help', 26)}</span><div style="flex:1;min-width:200px"><b>Soporte te pidió más información</b><p style="font-size:12.5px;color:var(--ink-2)">Respóndela abajo para que sigan con tu caso.</p></div></section>` : ''}
    <section class="card">${chdr('history', 'tone-p', 'Lo que ha pasado', 'Todas las respuestas de soporte quedan aquí.')}
      <div class="tl">${pub.map(evHTML).join('')}</div>
      ${['res','cer'].includes(t.st) || preview ? '' : `<div class="reply" style="margin-top:6px"><label class="sr" for="tdText">Tu respuesta</label><textarea id="tdText" placeholder="Escribe tu respuesta a soporte…"></textarea><div class="rb"><label class="ibtn" aria-label="Adjuntar" style="cursor:pointer">${ic('clip', 18)}<input type="file" class="sr" data-adjuntar="${t.id}"></label><span class="g"></span><button type="button" class="btn pri sm" data-act="usend">${ic('send', 15)}Enviar</button></div></div>`}</section>`;
}
async function accion(promesa, ok, recargar = true){
  try { await promesa; if (ok) toast(ok); if (recargar) await cargar(false); return true; } catch (e){ fallo(e); return false; }
}
function ticketAct(kind, anchor){
  const t = S.t;
  if (kind === 'assign') openPop(`<div class="pop-h"><span style="flex:1"><b>Asignar ${esc(t.folio)}</b><small>Elige quién lo atiende y su área.</small></span></div>
    <div class="pop-b"><div class="f" style="padding:0 6px 6px"><label for="asgArea">Área</label><select class="sel" id="asgArea" style="height:36px">${S.ag.areas.map(a => `<option value="${a.sar_id}"${a.sar_nombre === t.area ? ' selected' : ''}>${esc(a.sar_nombre)}</option>`).join('')}</select></div>
      ${S.ag.agentes.map(a => `<button type="button" class="hitem" data-assign="${a.usu_id}">${avatar(a.usu_id, a.NOMBRE, '')}<span><b>${esc(a.NOMBRE)}${a.usu_id === CFG.usuario ? ' (tú)' : ''}</b><small>${esc(a.PERFIL || 'Soporte')}${a.AREA ? ' · ' + esc(a.AREA) : ''} · ${num(a.ABIERTOS)} abiertos</small></span>${t.resp && t.resp.id === a.usu_id ? ic('check', 18) : ''}</button>`).join('') || '<p class="mut" style="padding:10px">No hay personas en el equipo de soporte.</p>'}</div>`, anchor, 340);
  if (kind === 'chstate') openPop(`<div class="pop-h"><span style="flex:1"><b>Cambiar estado</b><small>Queda registrado en la trazabilidad.</small></span></div>
    <div class="pop-b">${ST_ORDER.filter(k => k !== t.st).map(k => `<button type="button" class="hitem" data-setst="${k}" style="grid-template-columns:minmax(0,1fr) auto">${stChip(k)}<span class="mut" style="font-size:11.5px">${ST[k].d}</span></button>`).join('')}</div>`, anchor, 330);
  if (kind === 'moreacts') openPop(`<div class="pop-b" style="padding-top:10px">
    ${[['prio','flag','Cambiar prioridad'],['link','reopen','Vincular a problema recurrente'], ...(puede('ayudaAdmin') ? [['tokb','caps','Convertir en cápsula']] : []),['copy','copy','Copiar enlace del ticket']].map(([k, i, l]) => `<button type="button" class="hitem" data-more="${k}" style="grid-template-columns:24px minmax(0,1fr)">${ic(i, 18)}<span><b style="font-weight:600">${l}</b></span></button>`).join('')}
    <button type="button" class="hitem" data-more="close" style="grid-template-columns:24px minmax(0,1fr);color:var(--danger)">${ic('x', 18)}<span><b style="font-weight:600">Cerrar sin resolver</b></span></button></div>`, anchor, 280);
}
function resolveModal(){
  openModal(`<div class="modal-h"><span class="ico tone-s" style="width:40px;height:40px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex:none">${ic('check', 22)}</span><div style="flex:1"><h2>Marcar como resuelto</h2><p>El usuario recibirá la solución y la encuesta «¿Tu problema fue solucionado?».</p></div></div>
    <div class="modal-b"><div class="f"><label for="resN">¿Qué se hizo? <span class="req">*</span></label><textarea class="ta" id="resN" autofocus placeholder="Explica la solución con palabras simples."></textarea></div>
      ${puede('ayudaAdmin') ? `<label style="display:flex;gap:8px;align-items:center;font-size:13px"><input type="checkbox" id="resKb" style="accent-color:var(--sigma-purple);width:16px;height:16px"> Crear una cápsula con esta solución después</label>` : ''}</div>
    <div class="modal-f"><button type="button" class="btn ghost" data-act="close">Cancelar</button><button type="button" class="btn pri" data-act="doresolve">${ic('check', 16)}Marcar como resuelto</button></div>`);
}
function confirmModal(title, text, okLabel, act, danger, extra = ''){
  openModal(`<div class="modal-h"><span class="ico ${danger ? 'tone-d' : 'tone-p'}" style="width:40px;height:40px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex:none">${ic(danger ? 'warn' : 'help', 22)}</span><div style="flex:1"><h2>${title}</h2><p>${text}</p></div></div>
    ${extra ? `<div class="modal-b">${extra}</div>` : ''}
    <div class="modal-f"><button type="button" class="btn ghost" data-act="close" autofocus>Cancelar</button><button type="button" class="btn ${danger ? 'dan' : 'pri'}" data-act="${act}">${okLabel}</button></div>`);
}
async function setState(to, nota){
  const from = S.t.st;
  const ok = await accion(ws('s', 'Estado', {ticket:S.t.id, estado:to, nota:nota || ''}), null);
  if (ok) toast(`${esc(S.t.folio)}: ${ST[from].l} → ${ST[to].l}`, to === 'res' || to === 'cer' ? null : () => accion(ws('s', 'Estado', {ticket:S.t.id, estado:from, nota:'Se deshizo el cambio de estado.'}), 'Cambio deshecho'));
}
/* Encuesta del usuario */
const FB = {r:'', s:0, c:''};
function fbHTML(){
  const t = S.t; const no = FB.r === 'no'; const res = S.d.eventos.filter(e => e.ste_tipo === 'res').slice(-1)[0];
  return `<div class="modal-h"><span class="ico tone-s" style="width:40px;height:40px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex:none">${ic('check', 22)}</span><div style="flex:1"><h2>¿Tu problema fue solucionado?</h2><p>${esc(t.folio)} · ${esc(t.t)}</p></div><button type="button" class="ibtn" data-act="close" aria-label="Cerrar">${ic('x', 20)}</button></div>
    <div class="modal-b">
      ${res ? `<div class="tl-res"><b style="display:block;margin-bottom:2px">${esc(res.AUTOR)} escribió:</b>${esc(res.ste_texto)}</div>` : ''}
      <div class="fb-faces" role="group" aria-label="¿Se solucionó?">${[['si','Sí','smile'],['parcial','Parcialmente','meh'],['no','No','frown']].map(([k, l, i]) => `<button type="button" class="face" data-fbr="${k}" aria-pressed="${FB.r === k}">${ic(i, 34)}${l}</button>`).join('')}</div>
      <div class="f"><span class="lb">¿Cómo fue tu experiencia?</span><div class="stars" role="group" aria-label="Valoración">${[1,2,3,4,5].map(n => `<button type="button" class="${n <= FB.s ? 'on' : ''}" data-fbs="${n}" aria-label="${n} de 5" aria-pressed="${n === FB.s}">${ic('star', 24, n <= FB.s ? 'fill' : '')}</button>`).join('')}</div></div>
      <div class="f"><label for="fbC">Comentario</label><textarea class="ta" id="fbC" placeholder="Cuéntanos cómo fue tu experiencia.">${esc(FB.c)}</textarea></div>
      ${no ? `<div class="sug" style="background:var(--danger-soft)"><div class="hd" style="color:var(--danger)">${ic('reopen', 18)}Lo sentimos. Puedes reabrir el problema y lo retomamos con prioridad.</div></div>` : ''}
    </div>
    <div class="modal-f"><button type="button" class="btn ghost" data-act="close">Ahora no</button>${no ? `<button type="button" class="btn pri" data-act="fbsend" data-reopen="1">${ic('reopen', 16)}Reabrir problema</button>` : `<button type="button" class="btn pri" data-act="fbsend"${FB.r ? '' : ' disabled'}>${ic('send', 16)}Enviar opinión</button>`}</div>`;
}
/* Problema recurrente (drawer) */
async function openRecur(id){
  openDrawer(`<div class="drawer-h"><h2>Problema recurrente</h2><button type="button" class="ibtn" data-act="close" aria-label="Cerrar">${ic('x', 20)}</button></div><div class="drawer-b">${skeleton()}</div>`);
  let d; try { d = await ws('s', 'Recurrente', {id}); } catch (e){ closeLayer(); fallo(e); return; }
  const r = d.recurrente; const dl = recurDelta(r);
  setDrawer(`<div class="drawer-h"><span class="ico tone-w" style="width:38px;height:38px;border-radius:12px;display:flex;align-items:center;justify-content:center">${ic('reopen', 20)}</span><h2>«${esc(r.sre_titulo)}»<small style="display:block;font-size:12.5px;font-weight:500;color:var(--muted)">Problema recurrente · ${esc(r.sre_modulo || '')} › ${esc(r.sre_pantalla || '')}</small></h2><button type="button" class="ibtn" data-act="close" aria-label="Cerrar">${ic('x', 20)}</button></div>
    <div class="drawer-b">
      <div class="grid g3 keep2">${kpi('inbox', 'tone-w', num(r.N30), 'Reportes este mes', `${dl.h} vs. mes anterior`)}${kpi('users', 'tone-b', num(r.USUARIOS), 'Usuarios afectados', `${num(r.CLIENTES)} ${r.CLIENTES === 1 ? 'cliente' : 'clientes'}`)}${kpi('clock', 'tone-c', num(r.HORAS) + ' h', 'Horas de soporte', 'Dedicadas a este problema')}</div>
      <section class="card">${chdr('activity', 'tone-w', 'Reportes por semana', 'Últimas 12 semanas.')}${lineChart([{l:'Reportes', c:'#D97706', d:d.semanas.map(x => x.N)}], d.semanas.map(x => x.SEMANA === 0 ? 'Esta' : 'S-' + x.SEMANA), {h:150, area:true, label:'Reportes por semana'})}</section>
      <div class="grid g2"><section class="card">${chdr('building', 'tone-b', 'Dónde ocurre', '')}${hbars(d.donde.map(x => ({l:x.ETIQUETA, v:x.N})), {unit:'reportes'})}</section>
        <section class="card">${chdr('bulb', 'tone-p', 'Causa probable', 'Identificada por soporte.')}<textarea class="ta" id="recCausa" style="min-height:80px" placeholder="¿Qué lo provoca?">${esc(r.sre_causa || '')}</textarea><div style="display:flex;justify-content:flex-end;margin-top:8px"><button type="button" class="btn ghost sm" data-act="guardacausa" data-id="${r.sre_id}">Guardar causa</button></div><div class="path" style="margin-top:12px;font-size:12px">${[r.sre_modulo, r.sre_submodulo, r.sre_pantalla, r.sre_seccion].filter(Boolean).map(esc).join(' <i>›</i> ')}</div></section></div>
      <section class="card">${chdr('inbox', 'tone-p', 'Tickets vinculados', `${num(d.tickets.length)} más recientes`)}<div class="rows">${d.tickets.map(t => `<a class="row" href="${esc(URL_('ticket', t.stk_id))}">${avatar(t.stk_usuario, t.USUARIO_NOMBRE)}<span style="min-width:0"><strong>${esc(t.stk_folio)} · ${esc(t.stk_titulo)}</strong><small>${esc(t.CLIENTE_NOMBRE)} · ${ago(D(t.stk_fecha_actualizacion))}</small></span><span class="e">${stChip(t.stk_estado)}</span></a>`).join('')}</div></section>
    </div>
    <div class="drawer-f"><span class="g">${r.sre_contenido ? `Ya tiene ayuda: «${esc(r.CONTENIDO_TITULO || '')}». Los tickets nuevos la reciben como sugerencia.` : 'Convierte este problema en conocimiento: se precargan el módulo, la pantalla y el contexto.'}</span>
      ${r.sre_contenido ? `<a class="btn out" href="${esc(URL_('kb', r.sre_contenido))}">${ic('book', 16)}Ver la ayuda</a>` : puede('ayudaAdmin') ? `<a class="btn out" href="${esc(URL_('kwiz', null, {recurrente:r.sre_id, tipo:'guia'}))}">${ic('doc', 16)}Crear artículo de ayuda</a><a class="btn pri" href="${esc(URL_('kwiz', null, {recurrente:r.sre_id}))}">${ic('caps', 16)}Crear cápsula</a>` : ''}</div>`);
}

/* ---------- Mis problemas ---------- */
LOAD.umine = async () => { const b = await ws('s', 'Bandeja', {soloMios:true}); S.T = b.tickets.map(TK); };
VIEWS.umine = () => {
  const mine = S.T;
  const sinPlan = !puede('reportar') && !puede('gestionar');
  return `${crumbs([['Soporte'], ['Mis problemas']])}
    <div class="ph"><div class="t"><h1>Mis problemas</h1><p>Lo que reportaste y en qué va cada uno.</p></div><div class="acts">${puede('ayuda') ? `<a class="btn out" href="${esc(URL_('help'))}">${ic('book', 16)}Centro de ayuda</a>` : ''}${sinPlan ? '' : btn('pri', 'data-act="report"', 'Reportar un problema', 'warn')}</div></div>
    ${sinPlan ? `<section class="card" style="display:flex;gap:14px;align-items:center;flex-wrap:wrap;background:var(--sigma-blue-soft);box-shadow:none"><span style="color:var(--sigma-blue)">${ic('lock', 24)}</span><div style="flex:1;min-width:220px"><b>El plan de tu empresa no incluye atención por tickets</b><p style="font-size:12.5px;color:var(--ink-2)">El centro de ayuda sigue disponible para todos. Si necesitas la mesa de ayuda, habla con el administrador de tu empresa.</p></div></section>` : ''}
    <div id="sgs-te-interesa"></div>
    ${mine.length ? `<div class="rows" style="gap:10px">${mine.map(t => { const ask = t.st === 'esp'; const fb = t.st === 'res' && !t.enc;
      return `<a class="tk" href="${esc(URL_('ticket', t.id))}" style="grid-template-columns:minmax(0,1fr) auto 24px"><span style="min-width:0"><span class="id">${t.unread ? '<span class="unread" title="Con novedades"></span>' : ''}${esc(t.folio)}</span><h3>${esc(t.t)}</h3><span class="meta"><span>${ic(CAT[t.cat] ? CAT[t.cat].i : 'more', 14)}${esc(t.mod)}</span><span>${ic('clock', 14)}${ago(t.upd)}</span>${ask ? '<span style="color:var(--sigma-purple);font-weight:700">' + ic('help', 14) + 'Soporte te pidió información</span>' : ''}${fb ? '<span style="color:var(--success);font-weight:700">' + ic('smile', 14) + 'Cuéntanos si se solucionó</span>' : ''}</span></span><span class="st">${stChip(t.st)}</span><span class="go">${ic('cr', 18)}</span></a>`; }).join('')}</div>`
      : sinPlan ? '' : empty('flag', 'tone-s', 'No tienes problemas reportados', 'Cuando algo no funcione, repórtalo desde la misma pantalla con «Reportar problema» y te avisaremos cada avance.', `${btn('pri', 'data-act="report"', 'Reportar un problema', 'warn')}${puede('ayuda') ? `<a class="btn out" href="${esc(URL_('help'))}">Ir al centro de ayuda</a>` : ''}`)}`;
};
AFTER.umine = () => { const z = $('#sgs-te-interesa'); if (z && CAMP_CARDS.length) z.innerHTML = `<div class="sec-t" style="margin-bottom:10px">💡 Te puede interesar</div><div class="grid g2">${CAMP_CARDS.map(campCardMini).join('')}</div>`; };

/* ---------- Analítica de soporte ---------- */
const AN = {per:30};
LOAD.analytics = async () => { S.an = await ws('s', 'Analitica', {dias:AN.per}); };
VIEWS.analytics = () => {
  const a = S.an, k = a.kpi || {};
  const lbl = a.dias.map(x => fDs(D(x.dia)));
  const pr = a.prioridades; const prT = Math.max(1, pr.reduce((s, x) => s + x.ABIERTOS, 0));
  const delta = (cur, prev) => cur != null && prev ? `<span class="delta ${cur > prev ? 'up' : 'ok'}">${cur > prev ? '+' : '−'}${dur(cur - prev)}</span> vs. período anterior` : 'Sin período anterior';
  const reab = k.CERRADOS ? (k.REABIERTOS / k.CERRADOS * 100).toFixed(1).replace('.', ',') + ' %' : '—';
  return `${crumbs([['Soporte','hub'], ['Analítica'], ['Soporte']])}
    <div class="ph"><div class="t"><h1>Analítica de soporte</h1><p>Cómo responde la mesa de ayuda, qué se repite y qué tan satisfechos quedan los usuarios.</p></div>
      <div class="acts"><div class="seg" role="group" aria-label="Período">${[[7,'7 días'],[30,'30 días'],[90,'90 días']].map(([v, l]) => `<button type="button" data-per="${v}" aria-pressed="${AN.per === v}">${l}</button>`).join('')}</div><button type="button" class="btn out" data-act="exportar">${ic('down', 16)}Exportar</button></div></div>
    <div class="grid g4 keep2">
      ${kpi('inbox', 'tone-p', num(k.ABIERTOS), 'Tickets abiertos', `${num(k.NUEVOS_HOY)} nuevos hoy`)}
      ${kpi('check', 'tone-s', num(k.CERRADOS), 'Tickets resueltos', `En ${AN.per} días · ${num(k.CREADOS)} creados`)}
      ${kpi('zap', 'tone-b', k.PRIMERA_MIN != null ? dur(k.PRIMERA_MIN) : '—', 'Primera respuesta promedio', delta(k.PRIMERA_MIN, k.PRIMERA_PREV_MIN))}
      ${kpi('clock', 'tone-c', k.RESOLUCION_MIN != null ? dur(k.RESOLUCION_MIN) : '—', 'Resolución promedio', delta(k.RESOLUCION_MIN, k.RESOLUCION_PREV_MIN))}
      ${kpi('shield', 'tone-s', k.SLA_RESUELTOS ? pct(k.SLA_OK, k.SLA_RESUELTOS) + ' %' : '—', 'SLA cumplido', `${num(k.SLA_OK)} de ${num(k.SLA_RESUELTOS)} tickets`)}
      ${kpi('warn', 'tone-d', num(k.SLA_VENCIDOS), 'SLA incumplido', 'Abiertos o resueltos fuera de plazo')}
      ${kpi('smile', 'tone-s', k.CSAT != null ? k.CSAT + ' %' : '—', 'CSAT', `${num(k.ENCUESTAS)} encuestas respondidas`)}
      ${kpi('reopen', 'tone-w', reab, 'Tasa de reapertura', `${num(k.REABIERTOS)} tickets reabiertos`)}
    </div>
    <section class="card">${chdr('activity', 'tone-p', 'Evolución temporal', 'Tickets creados y resueltos por día.', `<div class="legend"><span><i style="background:var(--c1)"></i>Creados</span><span><i style="background:var(--c2)"></i>Resueltos</span></div>`)}
      ${lineChart([{l:'Creados', c:'#6732F4', d:a.dias.map(x => x.CREADOS)}, {l:'Resueltos', c:'#00A0A6', d:a.dias.map(x => x.RESUELTOS)}], lbl, {label:'Tickets creados y resueltos por día', h:210})}</section>
    <div class="grid g2">
      <section class="card">${chdr('layers', 'tone-p', 'Problemas por módulo', '')}${hbars(a.modulos.map(x => ({l:x.ETIQUETA, v:x.N})))}</section>
      <section class="card">${chdr('building', 'tone-b', 'Problemas por cliente', '')}${hbars(a.clientes.map(x => ({l:x.ETIQUETA, v:x.N})))}</section>
      <section class="card">${chdr('tag', 'tone-c', 'Problemas por categoría', '')}${hbars(a.categorias.map(x => ({l:x.ETIQUETA, v:x.N})))}</section>
      <section class="card">${chdr('flag', 'tone-d', 'Problemas por prioridad', 'Tickets abiertos según cuánto afectan.')}
        <div class="meter" role="img" aria-label="Distribución por prioridad">${pr.map((x, i) => `<span style="width:${x.ABIERTOS / prT * 100}%;background:${['#C7352B','#EE8A82','#E9A23B','#C9D0DE'][i]}" data-tip="<b>${PR[x.spr_codigo].l}</b><br>${x.ABIERTOS} tickets"></span>`).join('')}</div>
        <div class="grid g4" style="gap:8px;margin-top:14px">${pr.map(x => `<div style="background:var(--surface-2);border-radius:12px;padding:10px 12px">${prChip(x.spr_codigo)}<b class="tnum" style="display:block;font-size:20px;font-weight:800;margin-top:6px">${num(x.ABIERTOS)}</b><small class="mut">${pct(x.ABIERTOS, prT)} %</small></div>`).join('')}</div></section>
    </div>
    <div class="grid g2">
      <section class="card">${chdr('shield', 'tone-s', 'SLA por prioridad', 'Porcentaje resuelto dentro del plazo.')}
        <div class="rows">${pr.map(x => { const p = x.RESUELTOS ? pct(x.EN_PLAZO, x.RESUELTOS) : 0; return `<div class="row" style="grid-template-columns:110px minmax(0,1fr) 92px">${prChip(x.spr_codigo)}<span class="meter" style="height:8px" data-tip="<b>${PR[x.spr_codigo].l}</b> · ${x.spr_horas_sla} h<br>${p} % en plazo · ${x.RESUELTOS ? 100 - p : 0} % fuera">${x.RESUELTOS ? `<span style="width:${p}%;background:var(--success)"></span><span style="width:${100 - p}%;background:var(--danger)"></span>` : ''}</span><span class="tnum" style="text-align:right;font-weight:800">${x.RESUELTOS ? p + ' %' : '—'}<small class="mut" style="display:block;font-weight:500;font-size:11px">${num(x.RESUELTOS)} tickets</small></span></div>`; }).join('')}</div></section>
      <section class="card">${chdr('users', 'tone-b', 'Responsables', 'Carga y resultados por persona.')}
        ${a.responsables.length ? `<div style="overflow-x:auto"><table style="width:100%;border-collapse:separate;border-spacing:0 6px;font-size:13px;min-width:460px"><thead><tr style="font-size:10.5px;letter-spacing:.06em;text-transform:uppercase;color:var(--faint)"><th style="text-align:left;padding:0 10px">Persona</th><th style="text-align:right;padding:0 10px">Abiertos</th><th style="text-align:right;padding:0 10px">Resueltos</th><th style="text-align:right;padding:0 10px">Resolución</th><th style="text-align:right;padding:0 10px">CSAT</th></tr></thead><tbody>
        ${a.responsables.map(x => `<tr style="background:var(--surface-2)"><td style="padding:10px;border-radius:12px 0 0 12px"><span style="display:inline-flex;align-items:center;gap:8px;font-weight:700">${avatar(x.stk_responsable, x.NOMBRE)}${esc(x.NOMBRE)}</span></td><td class="tnum" style="text-align:right;padding:10px">${num(x.ABIERTOS)}</td><td class="tnum" style="text-align:right;padding:10px">${num(x.RESUELTOS)}</td><td class="tnum" style="text-align:right;padding:10px">${x.RESOLUCION_MIN != null ? dur(x.RESOLUCION_MIN) : '—'}</td><td class="tnum" style="text-align:right;padding:10px;border-radius:0 12px 12px 0;font-weight:800">${x.CSAT != null ? x.CSAT + ' %' : '—'}</td></tr>`).join('')}</tbody></table></div>` : '<p class="mut" style="font-size:12.5px">Todavía no hay tickets asignados.</p>'}</section>
    </div>
    <section class="card">${chdr('reopen', 'tone-w', 'Problemas recurrentes', 'Lo que más se repite. Conviértelo en conocimiento para que deje de llegar.')}
      ${!a.recurrentes.length ? empty('reopen', 'tone-n', 'Sin problemas recurrentes', 'Aparecen cuando 5 o más tickets se parecen en módulo, pantalla y categoría.') : `<div class="grid g4 keep2" style="gap:12px">${a.recurrentes.map(r => { const dl = recurDelta(r); return `<div style="background:var(--surface-2);border-radius:16px;padding:14px 16px;display:flex;flex-direction:column;gap:8px;min-width:0">
        <b style="font-size:14px">«${esc(r.sre_titulo)}»</b><span class="mut" style="font-size:12px">${esc(r.sre_modulo || '')} · ${esc(r.sre_pantalla || '')}</span>
        <div style="display:flex;align-items:flex-end;justify-content:space-between;gap:8px"><span><b class="tnum" style="font-size:24px;font-weight:800">${num(r.N30)}</b> <span class="mut" style="font-size:12px">reportes</span><br><span style="font-size:12px">${dl.h} este mes</span></span>${spark(recurSerie(r), dl.d > 0 ? '#C7352B' : '#16855B')}</div>
        <div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:auto"><button type="button" class="btn out xs" data-act="recur" data-id="${r.sre_id}">Ver análisis</button>${recurBtn(r)}</div></div>`; }).join('')}</div>`}
    </section>`;
};
function exportar(){
  const a = S.an, k = a.kpi || {}; const filas = [['Analítica de soporte', `Últimos ${AN.per} días`], [], ['Indicador', 'Valor']];
  [['Tickets abiertos', k.ABIERTOS], ['Creados', k.CREADOS], ['Resueltos', k.CERRADOS], ['Primera respuesta (min)', Math.round(k.PRIMERA_MIN || 0)], ['Resolución (min)', Math.round(k.RESOLUCION_MIN || 0)], ['SLA cumplido', k.SLA_OK + '/' + k.SLA_RESUELTOS], ['CSAT %', k.CSAT ?? ''], ['Reabiertos', k.REABIERTOS]].forEach(r => filas.push(r));
  filas.push([], ['Día', 'Creados', 'Resueltos']); a.dias.forEach(x => filas.push([String(x.dia).slice(0, 10), x.CREADOS, x.RESUELTOS]));
  filas.push([], ['Módulo', 'Tickets']); a.modulos.forEach(x => filas.push([x.ETIQUETA, x.N]));
  filas.push([], ['Cliente', 'Tickets']); a.clientes.forEach(x => filas.push([x.ETIQUETA, x.N]));
  filas.push([], ['Categoría', 'Tickets']); a.categorias.forEach(x => filas.push([x.ETIQUETA, x.N]));
  const csv = '﻿' + filas.map(r => r.map(v => `"${String(v ?? '').replace(/"/g, '""')}"`).join(';')).join('\r\n');
  const u = URL.createObjectURL(new Blob([csv], {type:'text/csv;charset=utf-8'})); const l = document.createElement('a'); l.href = u; l.download = `analitica-soporte-${AN.per}d.csv`; document.body.appendChild(l); l.click(); l.remove(); setTimeout(() => URL.revokeObjectURL(u), 1000);
}

/* ================= Campañas ================= */
const CF = {tab:'activa'};
const condTxt = c => { const f = {estado:'Estado', perfil:'Perfil', cliente:'Cliente', planta:'Planta', usuario:'Usuario'}[c.campo] || c.campo; return `${f} ${c.op === '!=' ? 'no es' : 'es'} ${c.campo === 'usuario' ? esc(valorTxt(c)) : esc(c.valor)}`; };
const valorTxt = c => { const v = (S.val || []).find(x => x.CAMPO === c.campo && x.VALOR === c.valor); return v ? v.ETIQUETA : c.valor; };
const CAMPO = r => ({pres:presDe(r.cam_presentacion), id:r.cam_id, st:r.cam_estado, tipo:r.cam_tipo, t:r.cam_titulo, d:r.cam_descripcion || '', theme:r.cam_tema || 0, media:r.cam_medio, img:r.IMAGEN_URL, archivo:r.cam_archivo,
  fmt:String(r.cam_formatos || 'banner').split(',').filter(Boolean), reach:r.cam_alcance || 0, vis:pct(r.VISTOS, r.cam_alcance), inter:pct(r.INTERACCIONES, r.cam_alcance), vistos:r.VISTOS || 0, inters:r.INTERACCIONES || 0,
  from:D(r.cam_desde), to:D(r.cam_hasta), cta:{a:r.cam_cta_accion, l:r.cam_cta_texto || '', dest:r.cam_cta_destino || ''}, kb:r.cam_contenido, kbT:r.CONTENIDO_TITULO, kbK:r.CONTENIDO_TIPO,
  conds:JSON.parse(r.CONDICIONES || '[]'), join:r.cam_union, freq:r.cam_frecuencia, every:r.cam_cada_dias || 7, where:r.cam_donde, whereMod:r.cam_donde_modulo, closable:!!r.cam_cerrable, confirm:!!r.cam_confirmar, raw:r});
LOAD.campaigns = async () => { const [c, v] = await Promise.all([ws('c', 'Campanas'), ws('c', 'Valores').catch(() => ({valores:[]}))]); S.C = c.campanas.map(CAMPO); S.val = v.valores; };
VIEWS.campaigns = () => {
  const C = S.C; const act = C.filter(c => c.st === 'activa');
  const tabs = [['activa','Activas'],['programada','Programadas'],['borrador','Borradores'],['finalizada','Finalizadas']].map(([k, l]) => [k, l, C.filter(c => c.st === k || (k === 'activa' && c.st === 'pausada')).length]);
  const list = C.filter(c => c.st === CF.tab || (CF.tab === 'activa' && c.st === 'pausada'));
  const reachT = act.reduce((a, c) => a + c.reach, 0);
  return `${crumbs([['Soporte','hub'], ['Campañas']])}
    <div class="ph"><div class="t"><h1>Campañas</h1><p>Comunica novedades y contenidos a los usuarios correctos.</p></div><div class="acts"><a class="btn pri" href="${esc(URL_('cwiz'))}">${ic('plus', 16)}Crear campaña</a></div></div>
    <div class="grid g4 keep2">${kpi('mega', 'tone-p', act.length, 'Campañas activas', `${C.filter(c => c.st === 'programada').length} programadas`)}${kpi('users', 'tone-b', num(reachT), 'Usuarios alcanzados', 'Por campañas activas')}${kpi('eye', 'tone-c', reachT ? pct(act.reduce((a, c) => a + c.vistos, 0), reachT) + ' %' : '—', 'Visualización', 'Promedio de activas')}${kpi('target', 'tone-s', reachT ? pct(act.reduce((a, c) => a + c.inters, 0), reachT) + ' %' : '—', 'Interacción', 'Tocaron el botón')}</div>
    <div class="tabs" role="tablist" aria-label="Estado de las campañas">${tabs.map(([k, l, n]) => `<button type="button" role="tab" data-cftab="${k}" aria-selected="${CF.tab === k}">${l}<b>${n}</b></button>`).join('')}</div>
    ${list.length ? `<div class="grid g3">${list.map(campCard).join('')}</div>`
      : empty('mega', 'tone-b', !C.length ? 'No hay campañas' : `No hay campañas ${{activa:'activas', programada:'programadas', borrador:'en borrador', finalizada:'finalizadas'}[CF.tab]}`, 'Las campañas avisan novedades, mantenciones o cápsulas nuevas solo a quienes les sirven.', `<a class="btn pri" href="${esc(URL_('cwiz'))}">${ic('plus', 16)}Crear campaña</a>`)}`;
};
const campCover = c => c.img && c.media !== 'video' ? `<img src="${esc(c.img)}" alt="" onerror="this.remove()" style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover">` : cover(c.theme);
function campCard(c){
  const sched = c.st === 'programada'; const draft = c.st === 'borrador';
  return `<button type="button" class="cc" data-camp="${c.id}"><div class="cv">${campCover(c)}<span class="st">${cstChip(c.st)}</span><span class="ty">${ic(CT[c.tipo] ? CT[c.tipo].i : 'mega', 13)} ${CT[c.tipo] ? CT[c.tipo].l : ''}</span></div>
    <div class="cb"><h3>${esc(c.t)}</h3><p>${esc(c.d)}</p>
      ${draft ? `<div class="ft" style="margin-top:auto"><span>Sin publicar · ${c.fmt.map(f => FMT[f]).join(', ')}</span><span class="link">Continuar ${ic('arrow', 14)}</span></div>`
        : sched ? `<div class="stats" style="grid-template-columns:repeat(2,minmax(0,1fr))"><div><b>${num(c.reach)}</b><small>usuarios</small></div><div><b style="font-size:14px">${fDs(c.from)} · ${fT(c.from)}</b><small>programada</small></div></div><div class="ft"><span>${c.fmt.map(f => FMT[f]).join(' · ')}</span><span class="link">Ver campaña ${ic('arrow', 14)}</span></div>`
        : `<div class="stats"><div><b>${num(c.reach)}</b><small>alcanzados</small></div><div><b>${c.vis} %</b><small>visualización</small></div><div><b>${c.inter} %</b><small>interacción</small></div></div><div class="ft"><span>Desde ${fD(c.from)}${c.to ? ' · hasta ' + fDs(c.to) : ''}</span><span class="link">Ver campaña ${ic('arrow', 14)}</span></div>`}</div></button>`;
}
const campToD = c => ({t:c.t, desc:c.d, tipo:c.tipo, theme:c.theme, cta:c.cta, kb:c.kb, kbT:c.kbT, kbK:c.kbK, media:c.media, img:c.img});
async function openCamp(id){
  const c = S.C.find(x => x.id === id); if (!c) return;
  if (c.st === 'borrador'){ go('cwiz', id); return; }
  const freqTxt = {una:'una vez', usuario:'una vez por usuario', leer:'hasta que la lean', repetir:'cada ' + c.every + ' días'}[c.freq] || '';
  const html = seg => `<div class="drawer-h"><h2>${esc(c.t)}<small style="display:flex;gap:8px;align-items:center;font-size:12.5px;font-weight:500;color:var(--muted);margin-top:4px">${cstChip(c.st)} ${CT[c.tipo] ? CT[c.tipo].l : ''} · ${c.fmt.map(f => FMT[f]).join(', ')}</small></h2><button type="button" class="ibtn" data-act="close" aria-label="Cerrar">${ic('x', 20)}</button></div>
    <div class="drawer-b">
      ${pvHTML(campToD(c), c.fmt[0], 'desktop', true)}
      ${c.st === 'programada' ? `<section class="card">${chdr('cal', 'tone-b', 'Programada', `Se publicará el ${fD(c.from)} a las ${fT(c.from)} para ${num(c.reach)} usuarios.`)}</section>` : `
      <section class="card">${chdr('target', 'tone-p', 'Resultados', 'Desde que se publicó.')}
        <div class="rows">${[['Audiencia', c.reach, 100, 'users'], ['La vieron', c.vistos, c.vis, 'eye'], ['Tocaron «' + esc(c.cta.l || 'el aviso') + '»', c.inters, c.inter, 'target']].map(([l, n, p, i]) => `<div class="row" style="grid-template-columns:34px minmax(0,1fr) 70px"><span class="ico tone-p">${ic(i, 16)}</span><span><strong>${l}</strong><span class="meter" style="height:8px;margin-top:6px"><span style="width:${p}%;background:var(--sigma-purple)"></span></span></span><span class="tnum" style="text-align:right;font-weight:800">${num(n)}<small class="mut" style="display:block;font-weight:500">${p} %</small></span></div>`).join('')}</div>
        ${seg ? `${c.confirm ? `<p class="mut" style="font-size:12.5px;margin-top:10px">${num(seg.totales.CONFIRMADOS)} confirmaron la lectura · ${num(seg.totales.DESCARTADOS)} la cerraron.</p>` : ''}<div style="margin-top:14px">${lineChart([{l:'Vieron', c:'#6732F4', d:seg.dias.map(x => x.VISTAS)}, {l:'Interacciones', c:'#00A0A6', d:seg.dias.map(x => x.INTERACCIONES)}], seg.dias.map(x => fDs(D(x.dia))), {h:140, area:true, label:'Visualizaciones por día'})}</div>` : '<div class="sk" style="height:140px;margin-top:14px"></div>'}</section>`}
      <section class="card">${chdr('users', 'tone-b', 'Audiencia', `${num(c.reach)} usuarios`)}<div class="pills">${c.conds.length ? c.conds.map((x, i) => `${i ? `<span class="tag">${c.join === 'OR' ? 'O' : 'Y'}</span>` : ''}<span class="tag tone-p">${condTxt(x)}</span>`).join('') : '<span class="tag tone-p">Todos los usuarios</span>'}</div></section>
    </div>
    <div class="drawer-f"><span class="g">${c.st === 'activa' ? 'Se muestra ' + freqTxt : c.st === 'pausada' ? 'Pausada: nadie la ve hasta reanudarla.' : ''}</span>
      ${c.st === 'activa' ? `<button type="button" class="btn plain" data-campst="pausada" data-id="${c.id}">${ic('pause', 16)}Pausar</button>` : c.st === 'pausada' ? `<button type="button" class="btn sec" data-campst="activa" data-id="${c.id}">Reanudar</button>` : ''}
      <a class="btn plain" href="${esc(URL_('cwiz', null, {copia:c.id}))}">${ic('copy', 16)}Duplicar</a><a class="btn out" href="${esc(URL_('cwiz', c.id))}">${ic('edit', 16)}Editar</a></div>`;
  openDrawer(html(null));
  if (c.st !== 'programada') try { const seg = await ws('c', 'Seguimiento', {id}); setDrawer(html(seg)); } catch (e){}
}

/* ---------- Asistente de campaña ---------- */
const CW = {step:1, d:null, pv:{fmt:'banner', dev:'desktop'}, done:null, editing:null, n:null, aud:null, guardando:false};
const CW_STEPS = [['Contenido','Qué vas a comunicar'],['Audiencia','A quién le llega'],['Comportamiento','Dónde y cómo aparece'],['Programación','Cuándo y cuántas veces'],['Vista previa','Cómo se verá'],['Publicar','Revisa y publica']];
/* Fechas con el calendario de SIGMA (Js/sigma-calendario.js): el campo va
   dentro de .sigma-modal-fecha y el componente escribe dd-mm-aaaa. Por
   dentro el asistente guarda aaaa-mm-dd. */
const isoATxt = iso => { const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso || ''); return m ? `${m[3]}-${m[2]}-${m[1]}` : ''; };
const txtAIso = t => { const m = /^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$/.exec(String(t || '').trim()); return m ? `${m[3]}-${pad(m[2])}-${pad(m[1])}` : ''; };
const campoFecha = (clave, iso, id) => `<span class="sigma-modal-fecha sgs-fecha"><input type="text" class="in" id="${id}" data-cwfecha="${clave}" value="${isoATxt(iso)}" placeholder="dd-mm-aaaa" autocomplete="off" inputmode="numeric"><a role="button" tabindex="0" aria-label="Abrir calendario"></a></span>`;
const HORAS = Array.from({length:48}, (_, i) => `${pad(Math.floor(i / 2))}:${i % 2 ? '30' : '00'}`);
const campoHora = (clave, v, id) => `<select class="sel" id="${id}" data-cw="${clave}">${(HORAS.includes(v) ? HORAS : [v, ...HORAS]).map(h => `<option${h === v ? ' selected' : ''}>${h}</option>`).join('')}</select>`;
const hoyISO = (dias = 2) => { const d = new Date(); d.setDate(d.getDate() + dias); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; };
LOAD.cwiz = async () => {
  const [c, v, k, p] = await Promise.all([ws('c', 'Campanas'), ws('c', 'Valores'), ws('a', 'Contenidos'), ws('a', 'Pantallas')]);
  S.C = c.campanas.map(CAMPO); S.val = v.valores; S.segs = v.segmentos; S.K = k.contenidos.map(KB).filter(x => x.status === 'Publicado'); S.pant = p.pantallas.filter(x => x.apa_visible);
  const id = +APP.id || 0, copia = +(qs.get('copia') || 0); const src = S.C.find(x => x.id === (id || copia));
  CW.editing = id && src ? id : null; CW.step = 1; CW.done = null;
  CW.d = src ? {pres:{...presDe(src.pres)}, t:src.t + (copia ? ' (copia)' : ''), desc:src.d, tipo:src.tipo, media:src.media || 'imagen', theme:src.theme, archivo:src.archivo, img:src.img, kb:src.kb || '', cta:{...src.cta}, conds:src.conds.map(x => ({...x})), join:src.join || 'AND', fmt:[...src.fmt],
      where:src.where || 'login', whereMod:src.whereMod || '', closable:src.closable, confirm:src.confirm, when:src.from && src.from > new Date() ? 'prog' : 'now', from:src.from && src.from > new Date() ? `${src.from.getFullYear()}-${pad(src.from.getMonth() + 1)}-${pad(src.from.getDate())}` : hoyISO(), fromT:src.from ? fT(src.from) : '09:00', to:src.to ? `${src.to.getFullYear()}-${pad(src.to.getMonth() + 1)}-${pad(src.to.getDate())}` : '', perm:!src.to, freq:src.freq || 'usuario', every:src.every || 7}
    : {pres:{...PRES_DEF}, t:'', desc:'', tipo:'novedad', media:'imagen', theme:0, archivo:null, img:null, kb:'', cta:{a:'modulo', l:'Ver novedad', dest:''}, conds:[{campo:'estado', op:'=', valor:'Activo'}], join:'AND', fmt:['banner'], where:'login', whereMod:'', closable:true, confirm:false, when:'now', from:hoyISO(), fromT:'09:00', to:'', perm:true, freq:'usuario', every:7};
  const pre = +(qs.get('contenido') || 0); const pk = pre && S.K.find(x => x.id === pre);
  if (pk && !src) Object.assign(CW.d, {t:(pk.kind === 'capsula' ? 'Nueva cápsula: ' : 'Nuevo: ') + pk.t.slice(0, 50), desc:pk.desc.slice(0, 220), tipo:'tutorial', kb:pk.id, cta:{a:['capsula','video'].includes(pk.kind) ? 'capsula' : 'documento', l:'Ver ' + KIND[pk.kind].l.toLowerCase(), dest:String(pk.id)}});
  if (!CW.d.cta.dest && CW.d.cta.a === 'modulo') CW.d.cta.dest = (destinos().modulo[0] || [''])[0];
  CW.pv.fmt = CW.d.fmt[0] || 'banner'; CW.n = null; audiencia();
};
const MODS = () => [...new Set(S.pant.map(p => p.apa_modulo))];
function destinos(){
  const primera = m => S.pant.find(p => p.apa_modulo === m);
  return {modulo:MODS().map(m => [primera(m).apa_link, m]), pantalla:S.pant.map(p => [p.apa_link, `${p.apa_modulo} › ${p.apa_pantalla}`]),
    documento:S.K.filter(k => ['manual','documento','guia','faq'].includes(k.kind)).map(k => [String(k.id), k.t]), capsula:S.K.filter(k => ['capsula','video'].includes(k.kind)).map(k => [String(k.id), k.t]), url:[], nada:[]};
}
const audiencia = debounce(async () => {
  const d = CW.d; if (!d) return;
  const dim = ['perfil','planta','cliente'].find(f => !d.conds.some(c => c.campo === f && c.op === '=')) || 'cliente';
  try { CW.aud = await ws('c', 'Audiencia', {condiciones:JSON.stringify(d.conds), union:d.join, dimension:dim}); CW.aud.dim = dim; CW.n = CW.aud.conteo.ALCANCE; }
  catch (e){ CW.aud = null; }
  const n = $('#reachN'); if (n && APP.vista === 'cwiz' && CW.step === 2) render(); else { const h = $('.ph .t p'); h && CW.d && (h.textContent = `${CW.d.t || 'Campaña sin título'} · ${num(CW.n)} usuarios`); }
}, 300);
VIEWS.cwiz = () => {
  if (CW.done) return `${crumbs([['Soporte','hub'], ['Campañas','campaigns'], ['Campaña publicada']])}<section class="card"><div class="success"><span class="ok">${ic('check', 34)}</span><h2 style="font-size:22px;font-weight:800">${CW.done.estado === 'programada' ? 'Campaña programada' : CW.done.estado === 'borrador' ? 'Borrador guardado' : 'Campaña publicada'}</h2><p class="mut" style="max-width:46ch">«${esc(CW.d.t)}» ${CW.done.estado === 'programada' ? `se publicará el ${fD(D(CW.done.desde))} a las ${fT(D(CW.done.desde))}` : CW.done.estado === 'borrador' ? 'quedó guardada. Puedes seguir editándola' : 'ya se está mostrando'} a <b style="color:var(--ink)">${num(CW.done.alcance)} usuarios</b>. Verás sus resultados en Campañas.</p>${CW.done.estado === 'borrador' || CW.done.estado === 'programada' ? '' : `<div id="cwConect" class="sgs-conect" data-camp="${CW.done.id}" aria-live="polite"><span class="mut">Buscando quién está conectado…</span></div>`}<div style="display:flex;gap:10px;flex-wrap:wrap;justify-content:center"><a class="btn pri" href="${esc(URL_('campaigns'))}">Volver a campañas</a></div></div></section>`;
  const d = CW.d, n = CW.n, step = CW.step;
  const body = [cwContenido, cwAudiencia, cwComportamiento, cwProgramacion, cwPreview, cwPublicar][step - 1](d, n);
  const can = !!d.t.trim();
  return `${crumbs([['Soporte','hub'], ['Campañas','campaigns'], [CW.editing ? 'Editar campaña' : 'Crear campaña']])}
    <div class="ph"><div class="t"><h1>${CW.editing ? 'Editar campaña' : 'Crear campaña'}</h1><p>${esc(d.t || 'Campaña sin título')} · ${n == null ? '…' : num(n)} usuarios</p></div><div class="acts"><button type="button" class="btn plain" data-act="cwdraft"${CW.guardando ? ' disabled' : ''}>${ic('doc', 16)}Guardar borrador</button></div></div>
    <div class="wz"><nav class="steps" aria-label="Pasos">${CW_STEPS.map(([t, s], i) => `<button type="button" class="step${i + 1 < step ? ' done' : ''}" data-cwstep="${i + 1}"${i + 1 === step ? ' aria-current="step"' : ''}${!can && i ? ' disabled' : ''}><span class="n">${i + 1 < step ? ic('check', 15) : i + 1}</span><span><b>${t}</b><small>${s}</small></span></button>`).join('')}</nav>
      <div style="display:flex;flex-direction:column;gap:16px;min-width:0">${body}
        <div class="wz-foot">${step > 1 ? `<button type="button" class="btn out" data-cwstep="${step - 1}">${ic('cl', 16)}Anterior</button>` : ''}<span class="g">Paso ${step} de 6${!can ? ' · Falta el título' : ''}</span><a class="btn ghost" href="${esc(URL_('campaigns'))}">Cancelar</a>
          ${step < 6 ? `<button type="button" class="btn pri" data-cwstep="${step + 1}"${!can ? ' disabled' : ''}>Siguiente${ic('arrow', 16)}</button>` : `<button type="button" class="btn pri" data-act="cwpublish"${can && !CW.guardando ? '' : ' disabled'}>${CW.guardando ? '<span class="giro" aria-hidden="true"></span>' + (d.when === 'now' ? 'Publicando…' : 'Programando…') : ic(d.when === 'now' ? 'send' : 'cal', 16) + (d.when === 'now' ? 'Publicar ahora' : 'Programar')}</button>`}</div>
      </div></div>`;
};
function cwContenido(d){
  const dests = destinos();
  return `<div class="split" style="grid-template-columns:minmax(0,1fr) 340px">
    <section class="card">${chdr('edit', 'tone-p', 'Contenido', 'Lo que verá el usuario. Corto y claro.')}
      <div class="fg">
        <div class="f full"><label for="cwT">Título <span class="req">*</span></label><input class="in" id="cwT" data-cw="t" value="${esc(d.t)}" placeholder="Ej.: Nuevo mapa 3D de Inventario" maxlength="70" autofocus><span class="hint">${d.t.length}/70 · Se lee en un vistazo.</span></div>
        <div class="f full"><label for="cwD">Descripción</label><textarea class="ta" id="cwD" data-cw="desc" maxlength="220" placeholder="Qué cambia y por qué le importa a quien lo lee.">${esc(d.desc)}</textarea></div>
        <div class="f full"><span class="lb">Tipo</span><div class="optcards" role="group" aria-label="Tipo de campaña" style="grid-template-columns:repeat(auto-fill,minmax(130px,1fr))">${CTYPES.map(([k, l, i]) => `<button type="button" class="opt" data-cwtipo="${k}" aria-pressed="${d.tipo === k}">${ic(i, 18)}${l}</button>`).join('')}</div></div>
        <div class="f full"><span class="lb">Imagen, video o ícono</span><div class="seg" role="group" aria-label="Medio">${[['imagen','Imagen','img'],['video','Video','video'],['icono','Ícono','spark']].map(([k, l, i]) => `<button type="button" data-cwmedia="${k}" aria-pressed="${d.media === k}">${ic(i, 15)}${l}</button>`).join('')}</div>
          ${d.media === 'video' ? `<div style="margin-top:8px"><label for="cwVid" style="font-size:12px;font-weight:700">Enlace de video <span class="mut" style="font-weight:600">(YouTube, Vimeo, Loom…)</span></label><input class="in" id="cwVid" data-cwvideo="1" value="${esc(presDe(d.pres).video)}" placeholder="https://www.youtube.com/watch?v=…" inputmode="url" autocomplete="off"><span class="hint">${videoEmb(presDe(d.pres).video) ? 'Se reproducirá dentro del aviso.' : (presDe(d.pres).video ? 'No reconozco ese enlace: usa uno de YouTube, Vimeo o Loom.' : 'O sube un archivo de video abajo.')}</span></div>` : ''}
          ${d.media === 'icono' ? `<p class="hint" style="margin-top:8px">Se usa el ícono del tipo elegido.</p>`
            : `<div style="display:flex;gap:8px;margin-top:8px;align-items:center;flex-wrap:wrap">${THEMES.map((t, i) => `<button type="button" class="ibtn" data-cwtheme="${i}" aria-label="Portada ${i + 1}" aria-pressed="${d.theme === i && !d.archivo}" style="width:56px;height:34px;border-radius:9px;overflow:hidden;position:relative;${d.theme === i && !d.archivo ? 'box-shadow:0 0 0 2px var(--sigma-purple)' : ''}"><svg viewBox="0 0 56 34" width="56" height="34"><rect width="56" height="34" fill="${t[1]}"/><circle cx="46" cy="4" r="20" fill="${t[0]}"/></svg></button>`).join('')}<label class="btn out sm" style="cursor:pointer"${CW.subiendo ? ' aria-busy="true"' : ''}>${CW.subiendo ? '<span class="giro" aria-hidden="true"></span>Subiendo ' + (d.media === 'video' ? 'video' : 'imagen') + '…' : ic('upload', 15) + (d.archivo ? 'Cambiar ' : 'Subir ') + (d.media === 'video' ? 'video' : 'imagen')}<input${CW.subiendo ? ' disabled' : ''} type="file" accept="${d.media === 'video' ? 'video/*' : 'image/*'}" class="sr" data-cwupload="1"></label>${d.archivo ? `<span class="tag tone-p">${ic('check', 12)}Archivo propio<button type="button" class="ibtn" style="width:20px;height:20px" data-act="cwquitarimg" aria-label="Quitar">${ic('x', 12)}</button></span>` : ''}</div>`}</div>
        <div class="f full">${presControles(d)}</div>
        <div class="f full"><label for="cwKb">Promocionar contenido de ayuda <span class="mut" style="font-weight:600">(opcional)</span></label><select class="sel" id="cwKb" data-cw="kb"><option value="">Ninguno</option>${S.K.map(k => `<option value="${k.id}"${String(d.kb) === String(k.id) ? ' selected' : ''}>${KIND[k.kind].l} · ${esc(k.t)}</option>`).join('')}</select><span class="hint">Agrega un segundo botón «Ver ${d.kb && S.K.find(k => k.id === +d.kb) ? KIND[S.K.find(k => k.id === +d.kb).kind].l.toLowerCase() : 'contenido'}».</span></div>
        <div class="f"><label for="cwCa">Botón principal: qué hace</label><select class="sel" id="cwCa" data-cwcta="a">${[['modulo','Abrir módulo'],['pantalla','Abrir pantalla'],['documento','Abrir documento'],['capsula','Abrir cápsula'],['url','Abrir URL'],['nada','No hacer nada']].map(([k, l]) => `<option value="${k}"${d.cta.a === k ? ' selected' : ''}>${l}</option>`).join('')}</select></div>
        <div class="f"><label for="cwCl">Texto del botón</label><input class="in" id="cwCl" data-cwcta="l" value="${esc(d.cta.l)}" maxlength="60" placeholder="Ej.: Explorar funcionalidad"${d.cta.a === 'nada' ? ' disabled' : ''}></div>
        ${d.cta.a !== 'nada' ? `<div class="f full"><label for="cwCd">Destino</label>${d.cta.a === 'url' ? `<input class="in" id="cwCd" data-cwcta="dest" value="${esc(d.cta.dest || 'https://')}" placeholder="https://">` : `<select class="sel" id="cwCd" data-cwcta="dest">${dests[d.cta.a].map(([v, l]) => `<option value="${esc(v)}"${String(d.cta.dest) === String(v) ? ' selected' : ''}>${esc(l)}</option>`).join('') || '<option value="">No hay opciones</option>'}</select>`}</div>` : ''}
      </div></section>
    <aside style="display:flex;flex-direction:column;gap:12px;position:sticky;top:84px"><span class="sec-t">Vista rápida</span>${pvModal(d)}</aside></div>`;
}
const pvMedia = d => medioHTML(d.media === 'icono' ? null : d.img, d.media === 'video', d.pres, d.theme);
function presControles(d){
  if (d.media === 'icono') return '';
  const p = presDe(d.pres);
  const g = (k, lbl, ops) => `<div class="f"><span class="lb">${lbl}</span><div class="seg" role="group" aria-label="${lbl}">${ops.map(([v, l]) => `<button type="button" data-cwpres="${k}" data-v="${v}" aria-pressed="${p[k] === v}">${l}</button>`).join('')}</div></div>`;
  return `<div class="sgs-pres">${g('ajuste', 'Imagen', [['cover', 'Llenar'], ['contain', 'Completa']])}${g('foco', 'Enfoque', [['top', 'Arriba'], ['center', 'Centro'], ['bottom', 'Abajo']])}${g('alto', 'Alto de la imagen', [['bajo', 'Bajo'], ['medio', 'Medio'], ['alto', 'Alto'], ['xalto', 'Muy alto']])}${g('tamano', 'Tamaño del aviso', [['s', 'S'], ['m', 'M'], ['l', 'L'], ['xl', 'XL']])}<p class="hint" style="grid-column:1/-1;margin:0">«Completa» muestra la imagen entera, sin recortar. Pruébalo en Vista previa › Modal.</p></div>`;
}
function pvModal(d){ const k = d.kb && S.K && S.K.find(x => x.id === +d.kb); const pr = presDe(d.pres);
  return `<div class="pv-modal" style="width:100%;max-width:${PRES_TAM[pr.tamano] || 520}px;margin:0 auto"><div class="im" style="height:${Math.round((PRES_ALTO[pr.alto] || 200) * .75)}px">${pvMedia(d)}<span style="position:absolute;left:12px;top:12px" class="chip tone-p">${ic(CT[d.tipo].i, 13)}${CT[d.tipo].l}</span></div><div class="tx"><h4>${esc(d.t || 'Título de la campaña')}</h4><p>${esc(d.desc || 'La descripción aparece aquí.')}</p>
    <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:4px">${d.cta.a !== 'nada' ? `<span class="btn pri sm">${esc(d.cta.l || 'Ver más')}</span>` : ''}${k ? `<span class="btn out sm">${ic(KIND[k.kind].i, 14)}Ver ${KIND[k.kind].l.toLowerCase()}</span>` : ''}<span class="btn plain sm">Más tarde</span></div></div></div>`; }
const AFIELDS = [['estado','Estado'],['perfil','Perfil'],['cliente','Cliente'],['planta','Planta'],['usuario','Usuario']];
const valoresDe = f => (S.val || []).filter(v => v.CAMPO === f);
function cwAudiencia(d, n){
  const a = CW.aud; const total = a ? a.conteo.TOTAL : null;
  const dimL = {perfil:'perfil', planta:'planta', cliente:'cliente'}[a ? a.dim : 'cliente'];
  return `<div class="split" style="grid-template-columns:minmax(0,1fr) 320px">
    <section class="card">${chdr('filter', 'tone-p', 'Constructor de audiencia', 'Combina condiciones. El total se recalcula al instante.')}
      <div class="pills" style="margin-bottom:14px"><span class="sec-t" style="align-self:center;margin-right:4px">Segmentos guardados</span>${(S.segs || []).length ? S.segs.map(s => `<button type="button" class="pill" data-seg="${s.csg_id}">${ic('users', 14)}${esc(s.csg_nombre)}</button>`).join('') : '<span class="mut" style="font-size:12px;align-self:center">Aún no hay. Arma uno y guárdalo.</span>'}</div>
      <div class="aud">
        <div class="aud-base">${ic('users', 18)}Usuarios de SIGMA<span style="margin-left:auto;font-weight:600;font-size:12px;opacity:.8">${total == null ? '…' : num(total)} en total</span></div>
        ${d.conds.map((c, i) => `<div class="aud-join"><div class="seg" role="group" aria-label="Unión">${i === 0 ? `<button type="button" aria-pressed="true" disabled>DONDE</button>` : `<button type="button" data-join="AND" aria-pressed="${d.join === 'AND'}">Y</button><button type="button" data-join="OR" aria-pressed="${d.join === 'OR'}">O</button>`}</div></div>
          <div class="cond"><select class="sel" data-condf="${i}" aria-label="Campo">${AFIELDS.map(([k, l]) => `<option value="${k}"${c.campo === k ? ' selected' : ''}>${l}</option>`).join('')}</select>
            <select class="sel" data-condo="${i}" aria-label="Operador"><option value="="${c.op === '=' ? ' selected' : ''}>es</option><option value="!="${c.op === '!=' ? ' selected' : ''}>no es</option></select>
            <select class="sel" data-condv="${i}" aria-label="Valor">${valoresDe(c.campo).map(x => `<option value="${esc(x.VALOR)}"${x.VALOR === c.valor ? ' selected' : ''}>${esc(x.ETIQUETA)}</option>`).join('')}</select>
            <button type="button" class="ibtn" data-conddel="${i}" aria-label="Quitar condición">${ic('trash', 16)}</button></div>`).join('')}
        <div class="aud-join"><button type="button" class="btn ghost sm" data-act="condadd" style="position:relative;z-index:1">${ic('plus', 15)}Agregar condición</button></div>
      </div></section>
    <aside style="display:flex;flex-direction:column;gap:12px;position:sticky;top:84px">
      <div class="aud-reach" aria-live="polite"><div style="flex:1"><b id="reachN">${n == null ? '…' : num(n)}</b><small style="display:block">usuarios serán alcanzados</small></div><div class="aud-faces">${a ? a.caras.map((x, i) => avatar(i + 1, x.NOMBRE, '')).join('') : ''}</div></div>
      <div class="card" style="padding:14px 16px"><div class="sec-t" style="margin-bottom:10px">Así se reparte por ${dimL}</div>${a && a.reparto.length ? hbars(a.reparto.map(x => ({l:x.ETIQUETA, v:x.N})), {unit:'usuarios'}) : '<p class="mut" style="font-size:12.5px">Sin datos para repartir.</p>'}
        <p class="mut" style="font-size:12px;margin-top:10px">${n === 0 ? '<b style="color:var(--danger)">Nadie cumple todas las condiciones.</b> Quita alguna o cambia «Y» por «O».' : total ? `Equivale al ${pct(n, total)} % de los usuarios.` : ''}</p></div>
      <button type="button" class="link" data-act="saveseg" style="align-self:flex-start;margin:0">${ic('plus', 14)}Guardar como segmento</button></aside></div>`;
}
function cwComportamiento(d){
  return `<section class="card">${chdr('layers', 'tone-p', 'Comportamiento', 'Dónde aparece y cómo se presenta.')}
    <div class="fg">
      <div class="f full"><span class="lb">Formato (puedes elegir varios)</span><div class="optcards" style="grid-template-columns:repeat(auto-fill,minmax(180px,1fr))">${[['banner','Banner','Franja arriba de la pantalla. No interrumpe.','mega'],['modal','Modal','Ventana al centro. Para lo importante.','layers'],['card','Card','Tarjeta en «Te puede interesar».','grid'],['notif','Centro de notificaciones','Queda en la campana de avisos.','bell']].map(([k, l, s, i]) => `<button type="button" class="opt" data-cwfmt="${k}" aria-pressed="${d.fmt.includes(k)}">${ic(i, 18)}${l}<small>${s}</small></button>`).join('')}</div></div>
      <div class="f"><label for="cwWhere">Dónde aparece</label><select class="sel" id="cwWhere" data-cw="where"><option value="login"${d.where === 'login' ? ' selected' : ''}>En cualquier pantalla de SIGMA</option><option value="modulo"${d.where === 'modulo' ? ' selected' : ''}>Al entrar a un módulo</option></select></div>
      ${d.where === 'modulo' ? `<div class="f"><label for="cwWm">Módulo</label><select class="sel" id="cwWm" data-cw="whereMod">${MODS().map(m => `<option${d.whereMod === m ? ' selected' : ''}>${esc(m)}</option>`).join('')}</select></div>` : '<div></div>'}
      <div class="f full" style="gap:10px">
        <label style="display:flex;align-items:center;gap:12px;font-size:13.5px"><button type="button" class="switch" role="switch" aria-checked="${d.closable}" data-cwsw="closable" aria-label="Se puede cerrar"></button><span><b>El usuario puede cerrarla</b><span class="mut" style="display:block;font-size:12px">Desactívalo solo para avisos obligatorios.</span></span></label>
        <label style="display:flex;align-items:center;gap:12px;font-size:13.5px"><button type="button" class="switch" role="switch" aria-checked="${d.confirm}" data-cwsw="confirm" aria-label="Pedir confirmación de lectura"></button><span><b>Pedir confirmación de lectura</b><span class="mut" style="display:block;font-size:12px">Agrega «Entendido» y registra quién la leyó.</span></span></label></div>
    </div></section>`;
}
function cwProgramacion(d, n){
  const freqTxt = {una:'una sola vez', usuario:'una vez por usuario', leer:'hasta que la lea', repetir:`cada ${d.every} días`}[d.freq];
  const fromTxt = d.when === 'now' ? 'desde ahora' : `desde el ${d.from.split('-').reverse().slice(0, 2).join('/')} a las ${d.fromT}`;
  return `<section class="card">${chdr('cal', 'tone-b', 'Programación', 'Cuándo empieza, cuándo termina y cuántas veces se muestra.')}
    <div class="fg">
      <div class="f full"><span class="lb">Publicación</span><div class="optcards" style="grid-template-columns:repeat(2,minmax(0,1fr))"><button type="button" class="opt" data-cwwhen="now" aria-pressed="${d.when === 'now'}">${ic('send', 18)}Publicar ahora<small>Apenas termines este asistente.</small></button><button type="button" class="opt" data-cwwhen="prog" aria-pressed="${d.when === 'prog'}">${ic('cal', 18)}Programar<small>Elige día y hora de inicio.</small></button></div></div>
      ${d.when === 'prog' ? `<div class="f"><label for="cwFrom">Fecha de inicio</label>${campoFecha('from', d.from, 'cwFrom')}</div><div class="f"><label for="cwFromT">Hora</label>${campoHora('fromT', d.fromT, 'cwFromT')}</div>` : ''}
      <div class="f full"><span class="lb">Término</span><label style="display:flex;align-items:center;gap:12px;font-size:13.5px"><button type="button" class="switch" role="switch" aria-checked="${d.perm}" data-cwsw="perm" aria-label="Permanente"></button><b>Permanente</b><span class="mut" style="font-size:12px">Sin fecha de término.</span></label></div>
      ${d.perm ? '' : `<div class="f"><label for="cwTo">Fecha de término</label>${campoFecha('to', d.to || hoyISO(30), 'cwTo')}</div><div></div>`}
      <div class="f full"><span class="lb">Frecuencia</span><div class="pills">${[['una','Una vez'],['usuario','Una vez por usuario'],['leer','Hasta que lo lea'],['repetir','Repetir cada X días']].map(([k, l]) => `<button type="button" class="pill" data-cwfreq="${k}" aria-pressed="${d.freq === k}">${l}</button>`).join('')}</div>
        ${d.freq === 'repetir' ? `<div style="display:flex;align-items:center;gap:8px;margin-top:8px"><span class="mut">Cada</span><input type="number" min="1" max="60" class="in" style="width:80px" data-cw="every" value="${d.every}" aria-label="Días"><span class="mut">días</span></div>` : ''}</div>
    </div>
    <div style="margin-top:16px;display:flex;gap:10px;padding:12px 14px;border-radius:12px;background:var(--sigma-blue-soft);color:var(--sigma-blue-dark);font-size:13px">${ic('cal', 18)}<span>Se mostrará a <b>${n == null ? '…' : num(n)} usuarios</b> ${fromTxt}, ${freqTxt}${d.perm ? ', sin fecha de término' : ' hasta el ' + (d.to || hoyISO(30)).split('-').reverse().slice(0, 2).join('/')}.</span></div></section>`;
}
function cwPreview(d){
  return `<section class="card">${chdr('eye', 'tone-c', 'Vista previa', 'Así la verán tus usuarios dentro de SIGMA.', `<div class="seg" role="group" aria-label="Formato">${['banner','modal','card','notif'].map(k => `<button type="button" data-pvf="${k}" aria-pressed="${CW.pv.fmt === k}">${FMT[k]}</button>`).join('')}</div><div class="seg" role="group" aria-label="Dispositivo">${[['desktop','monitor','Escritorio'],['tablet','tablet','Tablet'],['mobile','phone','Móvil']].map(([k, i, l]) => `<button type="button" data-pvd="${k}" aria-pressed="${CW.pv.dev === k}" aria-label="${l}">${ic(i, 15)}</button>`).join('')}</div>`)}
    ${!d.fmt.includes(CW.pv.fmt) ? `<p class="mut" style="font-size:12.5px;margin-bottom:10px">${ic('help', 14)} Este formato no está activo en tu campaña; lo ves solo como referencia.</p>` : ''}
    ${pvHTML(d, CW.pv.fmt, CW.pv.dev)}
    <div style="margin-top:14px"><span class="sec-t">Ajustar la presentación</span>${presControles(d)}</div></section>`;
}
function pvHTML(d, fmt, dev, compact){
  const k = d.kb && S.K && S.K.find(x => x.id === +d.kb); const kT = k ? k.t : d.kbT, kK = k ? k.kind : d.kbK;
  const tp = CT[d.tipo] || CT.novedad;
  const banner = `<div class="pv-banner"><span>${ic(tp.i, 20)}</span><span style="min-width:0"><b>${esc(d.t || 'Título')}</b>${dev === 'mobile' ? '' : esc(String(d.desc || '').slice(0, 80))}</span>${d.cta.a !== 'nada' ? `<span class="btn">${esc(d.cta.l || 'Ver')}</span>` : ''}</div>`;
  const card = `<div class="sec-t" style="font-size:9.5px">💡 Te puede interesar</div><div class="pv-card"><svg width="44" height="44" viewBox="0 0 44 44" style="border-radius:12px"><rect width="44" height="44" fill="${THEMES[d.theme % 4][1]}"/><circle cx="36" cy="6" r="18" fill="${THEMES[d.theme % 4][0]}"/></svg><div style="min-width:0"><b style="font-size:13px;display:block">${esc(d.t || 'Título')}</b><small class="mut" style="font-size:11.5px">${esc(String(d.desc || '').slice(0, 70))}</small><div style="margin-top:6px"><span class="link" style="font-size:12px">${esc(d.cta.l || 'Ver más')} ${ic('arrow', 12)}</span></div></div></div>`;
  const notif = `<div class="pv-notif"><b style="font-size:13px;display:block;padding:4px 6px 8px">Notificaciones</b><div class="notif" style="background:var(--sigma-purple-soft)"><span class="ico tone-p">${ic(tp.i, 16)}</span><span style="min-width:0"><b>${esc(d.t || 'Título')}</b><small>${esc(String(d.desc || '').slice(0, 60))}</small><time>Ahora</time></span><span class="unread"></span></div><div class="notif"><span class="ico tone-s">${ic('check', 16)}</span><span><b>Resolvimos tu problema. ¿Se solucionó?</b><small>Mesa de ayuda</small><time>Ayer</time></span><span></span></div></div>`;
  return `<div class="devices"${compact ? ' style="padding:14px"' : ''}><div class="dev ${compact ? 'tablet' : dev}"${compact ? ' style="width:100%"' : ''}><div class="bar"><i></i><i></i><i></i><span style="margin-left:10px;font-size:11px;color:var(--muted)">sigma · ${esc(d.where === 'modulo' && d.whereMod ? d.whereMod : 'inicio')}</span></div>
    <div class="mini"><div class="ms"><span style="width:60%;background:#fff;opacity:.9"></span><span class="on"></span><span></span><span></span><span style="width:70%"></span><span></span></div>
      <div class="mc">${fmt === 'banner' ? banner : ''}<div class="sk" style="width:40%;height:14px"></div><div class="sk" style="width:70%"></div>${fmt === 'card' ? card : ''}<div style="display:grid;grid-template-columns:repeat(${dev === 'mobile' ? 1 : 3},1fr);gap:8px"><div class="skc"></div>${dev === 'mobile' ? '' : '<div class="skc"></div><div class="skc"></div>'}</div><div class="skc" style="height:90px"></div>${fmt === 'notif' ? notif : ''}</div>
      ${fmt === 'modal' ? `<div class="pv-scrim">${pvModal(d)}</div>` : ''}</div></div></div>`;
}
function cwPublicar(d, n){
  const ok = (b, t, s) => `<div class="row"><span class="ico ${b ? 'tone-s' : 'tone-d'}">${ic(b ? 'check' : 'warn', 17)}</span><span><strong>${t}</strong><small>${s}</small></span><span class="e"></span></div>`;
  const k = d.kb && S.K.find(x => x.id === +d.kb);
  return `<section class="card">${chdr('send', 'tone-p', 'Revisa y publica', 'Último vistazo antes de que llegue a tus usuarios.')}
    <div class="rows">${ok(!!d.t.trim(), 'Contenido', `${CT[d.tipo].l} · «${esc(d.t || 'Sin título')}»${k ? ' · promociona ' + esc(k.t) : ''}`)}${ok(n > 0, 'Audiencia', `${n == null ? '…' : num(n)} usuarios · ${d.conds.length} condiciones (${d.join === 'AND' ? 'todas' : 'cualquiera'})`)}${ok(d.fmt.length > 0, 'Comportamiento', d.fmt.map(f => FMT[f]).join(', ') + (d.closable ? ' · se puede cerrar' : ' · obligatoria') + (d.confirm ? ' · pide confirmación' : ''))}${ok(true, 'Programación', d.when === 'now' ? 'Publicar ahora' : `Inicia ${d.from.split('-').reverse().join('/')} ${d.fromT}`)}</div>
    <div style="margin-top:16px">${pvHTML(d, d.fmt[0] || 'banner', 'desktop', true)}</div></section>`;
}
function readCW(){ if (!CW.d) return; $$('[data-cwvideo]').forEach(el => { CW.d.pres = {...presDe(CW.d.pres), video:el.value.trim()}; }); $$('[data-cw]').forEach(el => { CW.d[el.dataset.cw] = el.type === 'number' ? +el.value : el.value; }); $$('[data-cwcta]').forEach(el => { CW.d.cta[el.dataset.cwcta] = el.value; }); }
async function guardarCampana(accion){
  readCW(); const d = CW.d; CW.guardando = true;
  try {
    const r = await ws('c', 'Guardar', {datos:JSON.stringify({id:CW.editing, accion, tipo:d.tipo, titulo:d.t, descripcion:d.desc, medio:d.media, tema:d.theme, archivo:d.archivo, presentacion:presDe(d.pres), formatos:d.fmt, donde:d.where, dondeModulo:d.whereMod,
      cerrable:d.closable, confirmar:d.confirm, cta:d.cta.a === 'nada' ? {a:'nada'} : d.cta, contenido:d.kb ? +d.kb : null, union:d.join, condiciones:d.conds, frecuencia:d.freq, cadaDias:d.freq === 'repetir' ? d.every : null,
      cuando:d.when, desde:d.when === 'prog' ? `${d.from}T${d.fromT}:00` : null, hasta:d.perm ? null : `${d.to || hoyISO(30)}T23:59:00`})});
    CW.guardando = false; CW.editing = r.id;
    if (accion === 'borrador'){ toast('Borrador guardado'); CF.tab = 'borrador'; go('campaigns'); return; }
    CW.done = r; closeLayer(); render(); toast(r.estado === 'programada' ? 'Campaña programada' : 'Campaña publicada');
  } catch (e){ CW.guardando = false; closeLayer(); render(); fallo(e); }
}

/* ================= Centro de ayuda ================= */
const CAT_ICO = {p:'tone-p', b:'tone-b', c:'tone-c', w:'tone-w', s:'tone-s', n:'tone-n', d:'tone-d'};
LOAD.help = LOAD.lib = LOAD.cats = async () => { const d = await ws('a', 'Contenidos'); S.K = d.contenidos.map(KB); S.cats = d.categorias; S.perm = d.permisos || {}; };
const admin = () => !!(S.perm && S.perm.ADMIN) || puede('ayudaAdmin');
const pubKB = () => S.K.filter(k => k.status === 'Publicado' && k.mod !== 'Soporte');
function kcard(k, i){
  const vid = ['capsula','video'].includes(k.kind); const doc = ['manual','documento'].includes(k.kind);
  const fmtC = {PDF:'#C7352B', DOCX:'#0B6FD1', XLSX:'#16855B', PPTX:'#D97706'}[k.fmt] || 'var(--sigma-purple)';
  return `<a class="kc" href="${esc(URL_('kb', k.id, {origen:'centro'}))}"><div class="th">${cover(i ?? k.tema, 'grid')}
      ${vid ? `<span class="play">${ic('play', 20)}</span>${k.dur ? `<span class="dur">${esc(k.dur)}</span>` : ''}` : doc ? `<span class="doc"><span style="width:70%"></span><span></span><span></span><span style="width:60%"></span><span></span><em style="background:${fmtC}">${esc(k.fmt || 'DOC')}</em></span>` : `<span class="play" style="color:var(--warning-ink)">${ic(KIND[k.kind].i, 20)}</span>`}
      <span class="kind chip ${KIND[k.kind].c}" style="background:#fff">${ic(KIND[k.kind].i, 13)}${KIND[k.kind].l}</span></div>
    <div class="kb"><h3>${esc(k.t)}</h3><p class="mut" style="font-size:12px;line-height:1.45">${esc(k.desc.slice(0, 90))}</p>
      <div class="km"><span>${ic('layers', 13)}${esc(k.mod)}</span><span>${ic('eye', 13)}${num(k.viewsT)}</span>${k.rating ? `<span>${ic('star', 13)}${String(k.rating).replace('.', ',')}</span>` : ''}${k.status !== 'Publicado' ? `<span class="tag" style="height:20px">${esc(k.status)}</span>` : ''}</div></div></a>`;
}
const HQ = {q:''};
VIEWS.help = () => {
  const K = pubKB();
  const top = [...K].sort((a, b) => b.views - a.views || b.viewsT - a.viewsT).slice(0, 5); const news = [...K].sort((a, b) => b.upd - a.upd).slice(0, 4);
  const rec = [...K].sort((a, b) => (b.rating * 10 + b.viewsT) - (a.rating * 10 + a.viewsT)).slice(0, 4);
  const sugeridas = [...new Set(top.map(k => k.t.toLowerCase().replace(/^c[oó]mo\s+/, '').split(' ').slice(0, 3).join(' ')))].slice(0, 4);
  const cats = S.cats.map(c => ({...c, n:K.filter(k => k.mod === c.aca_modulo).length})).filter(c => c.n || admin());
  return `${crumbs([['Soporte'], ['Centro de ayuda']])}
    <section class="hhero"><h1>Centro de ayuda</h1><p>Encuentra manuales, videos, cápsulas y guías para trabajar mejor con SIGMA.</p>
      <div class="hsearch"><label class="sr" for="hq">¿Qué necesitas aprender?</label>${ic('search', 20)}<input id="hq" placeholder="¿Qué necesitas aprender?" value="${esc(HQ.q)}" autocomplete="off"><div class="hres" id="hres" hidden></div></div>
      ${sugeridas.length ? `<div class="hsug"><span>Lo más buscado:</span>${sugeridas.map(s => `<button type="button" data-hsug="${esc(s)}">${esc(s)}</button>`).join('')}</div>` : ''}</section>
    ${admin() ? `<div class="toolbar"><span class="sec-t" style="flex:1">Gestión de contenidos</span>${puede('analitica') ? `<a class="btn out sm" href="${esc(URL_('kbstats'))}">${ic('chart', 15)}Analítica</a>` : ''}<a class="btn out sm" href="${esc(URL_('lib'))}">${ic('list', 15)}Biblioteca</a><a class="btn pri sm" href="${esc(URL_('kwiz'))}">${ic('plus', 15)}Crear contenido</a></div>` : ''}
    <div id="sgs-te-interesa"></div>
    <section><h2 style="font-size:16px;font-weight:800;margin-bottom:12px">Categorías</h2>${cats.length ? `<div class="cats">${cats.map(c => `<a class="cat" href="${esc(URL_('lib', null, {mod:c.aca_modulo}))}"><span class="ico ${CAT_ICO[c.aca_tono] || 'tone-p'}">${ic(c.aca_icono || 'folder', 20)}</span><b>${esc(c.aca_nombre)}</b><small>${c.n} ${c.n === 1 ? 'contenido' : 'contenidos'}</small></a>`).join('')}</div>` : '<p class="mut">Todavía no hay categorías con contenido.</p>'}</section>
    <section><div class="toolbar" style="margin-bottom:12px"><h2 style="font-size:16px;font-weight:800;flex:1">${admin() ? 'Contenido recomendado' : '💡 Te puede interesar'}</h2><a class="link" href="${esc(URL_('lib'))}">Ver todo${ic('arrow', 14)}</a></div>
      ${rec.length ? `<div class="grid g4 keep2">${rec.map((k, i) => kcard(k, i)).join('')}</div>` : empty('book', 'tone-c', 'Todavía no hay contenido', 'Crea la primera cápsula o sube un manual para que los usuarios aprendan solos.', admin() ? `<a class="btn pri" href="${esc(URL_('kwiz'))}">${ic('plus', 16)}Crear contenido</a>` : '')}</section>
    <div class="grid g2">
      <section class="card">${chdr('activity', 'tone-p', 'Lo más consultado', 'Últimos 30 días.')}${top.length ? `<div class="rows">${top.map((k, i) => `<a class="row" href="${esc(URL_('kb', k.id, {origen:'centro'}))}"><span class="ico ${KIND[k.kind].c}">${ic(KIND[k.kind].i, 17)}</span><span style="min-width:0"><strong>${i + 1}. ${esc(k.t)}</strong><small>${KIND[k.kind].l} · ${esc(kmeta(k))}</small></span><span class="e tnum mut" style="font-size:12px">${ic('eye', 14)}${num(k.views)}</span></a>`).join('')}</div>` : '<p class="mut">Sin datos aún.</p>'}</section>
      <section class="card">${chdr('spark', 'tone-c', 'Novedades', 'Contenido nuevo o actualizado.')}${news.length ? `<div class="rows">${news.map(k => `<a class="row" href="${esc(URL_('kb', k.id, {origen:'centro'}))}"><span class="ico ${KIND[k.kind].c}">${ic(KIND[k.kind].i, 17)}</span><span style="min-width:0"><strong>${esc(k.t)}</strong><small>${esc(k.ver)} · ${fD(k.upd)}${k.nota ? ' · ' + esc(k.nota) : ''}</small></span><span class="e">${ic('cr', 16)}</span></a>`).join('')}</div>` : '<p class="mut">Sin novedades.</p>'}</section>
    </div>
    ${puede('reportar') ? `<section class="card" style="display:flex;align-items:center;gap:16px;flex-wrap:wrap"><span class="ico tone-d" style="width:44px;height:44px;border-radius:14px;display:flex;align-items:center;justify-content:center">${ic('warn', 22)}</span><div style="flex:1;min-width:220px"><b style="font-size:15px">¿No encontraste lo que buscabas?</b><p class="mut" style="font-size:13px">Cuéntanos el problema. Te respondemos con el contexto de la pantalla donde estás.</p></div>${btn('out', 'data-act="report"', 'Reportar un problema', 'warn')}</section>` : ''}`;
};
AFTER.help = AFTER.umine;
const logBusqueda = debounce((q, n) => { if (q.trim().length >= 3) ws('a', 'Busqueda', {texto:q, resultados:n}).catch(() => {}); }, 1200);
function helpResults(q){
  const n = norm(q.trim()); if (n.length < 2) return '';
  const L = pubKB().filter(k => norm(k.t + ' ' + k.desc + ' ' + k.path.join(' ')).includes(n)).slice(0, 6);
  logBusqueda(q, L.length);
  return L.length ? L.map(k => `<a class="hitem" href="${esc(URL_('kb', k.id, {origen:'busqueda'}))}"><span class="t ${KIND[k.kind].c}">${ic(KIND[k.kind].i, 18)}</span><span><b>${esc(k.t)}</b><small>${KIND[k.kind].l} · ${esc(k.path.slice(0, 2).join(' › '))}</small></span>${ic('cr', 16)}</a>`).join('')
    : `<div class="empty" style="padding:18px"><span class="ei tone-n" style="width:52px;height:52px;border-radius:16px">${ic('search', 24)}</span><b style="font-size:14px">No encontramos «${esc(q)}»</b><p style="font-size:12.5px">Prueba con otra palabra o repórtalo: así sabremos qué contenido falta.</p>${puede('reportar') ? `<div class="acts">${btn('out sm', 'data-act="report"', 'Reportar un problema')}</div>` : ''}</div>`;
}
function showHres(){ const box = $('#hres'); if (!box) return; const h = helpResults(HQ.q); box.innerHTML = h; box.hidden = !h; }

/* ---------- Biblioteca ---------- */
const LF = {q:'', mod:qs.get('mod') || '', st:'', view:'grid', kind:qs.get('tipo') || ''};
VIEWS.lib = () => {
  const kind = LF.kind; const all = S.K.filter(k => admin() || k.status === 'Publicado');
  const groups = {'':'Todos', capsula:'Cápsulas', video:'Videos', documento:'Manuales y documentos', guia:'Guías rápidas', faq:'FAQ'};
  const inKind = (k, kk) => !kk || k.kind === kk || (kk === 'documento' && k.kind === 'manual');
  const q = norm(LF.q.trim());
  const L = all.filter(k => inKind(k, kind) && (!LF.mod || k.mod === LF.mod) && (!LF.st || k.status === LF.st) && (!q || norm(k.t + ' ' + k.desc).includes(q)));
  const title = kind ? groups[kind] : 'Biblioteca de contenidos';
  const mods = [...new Set([...S.cats.map(c => c.aca_modulo), ...S.K.map(k => k.mod)])].filter(Boolean);
  return `${crumbs([['Soporte'], ['Centro de ayuda','help'], [title]])}
    <div class="ph"><div class="t"><h1>${title}</h1><p>${{capsula:'Videos cortos con objetivo, pasos y recomendaciones.', video:'Videos de funcionalidades y novedades.', documento:'Manuales, planillas y presentaciones con su historial de versiones.'}[kind] || 'Todo el contenido de ayuda, con su estado, versión y uso.'}</p></div>${admin() ? `<div class="acts"><a class="btn pri" href="${esc(URL_('kwiz', null, kind ? {tipo:kind} : {}))}">${ic('plus', 16)}Crear contenido</a></div>` : ''}</div>
    <div class="toolbar"><label class="search"><span class="sr">Buscar contenido</span>${ic('search', 18)}<input id="lq" value="${esc(LF.q)}" placeholder="Buscar por título o tema…" autocomplete="off"></label>
      <select class="sel" style="width:auto" data-lf="mod" aria-label="Módulo"><option value="">Todos los módulos</option>${mods.map(m => `<option${LF.mod === m ? ' selected' : ''}>${esc(m)}</option>`).join('')}</select>
      ${admin() ? `<select class="sel" style="width:auto" data-lf="st" aria-label="Estado"><option value="">Todos los estados</option>${['Publicado','Borrador','En revisión'].map(s => `<option${LF.st === s ? ' selected' : ''}>${s}</option>`).join('')}</select>` : ''}
      <div class="seg" role="group" aria-label="Vista"><button type="button" data-lv="grid" aria-pressed="${LF.view === 'grid'}" aria-label="Cuadrícula">${ic('grid', 15)}</button><button type="button" data-lv="list" aria-pressed="${LF.view === 'list'}" aria-label="Lista">${ic('list', 15)}</button></div></div>
    <div class="pills">${Object.entries(groups).map(([k, l]) => `<button type="button" class="pill" data-lk="${k}" aria-pressed="${kind === k}">${k ? ic(KIND[k].i, 14) : ''}${l} <b class="tnum" style="opacity:.7">${all.filter(x => inKind(x, k)).length}</b></button>`).join('')}</div>
    ${L.length ? (LF.view === 'grid' ? `<div class="grid g4 keep2">${L.map(k => kcard(k)).join('')}</div>`
      : `<section class="card pad0" style="padding:8px"><div class="rows">${L.map(k => `<a class="row" href="${esc(URL_('kb', k.id, {origen:'centro'}))}" style="grid-template-columns:auto minmax(0,1fr) auto auto auto"><span class="ico ${KIND[k.kind].c}">${ic(KIND[k.kind].i, 17)}</span><span style="min-width:0"><strong>${esc(k.t)}</strong><small>${KIND[k.kind].l} · ${esc(k.path.join(' › ') || k.mod)}</small></span><span class="tag">${esc(k.ver)}</span><span class="chip ${k.status === 'Publicado' ? 'tone-s' : k.status === 'Borrador' ? 'tone-n' : 'tone-w'}"><i></i>${esc(k.status)}</span><span class="tnum mut" style="font-size:12px;min-width:70px;text-align:right">${ic('eye', 13)} ${num(k.viewsT)}</span></a>`).join('')}</div></section>`)
      : (!S.K.length ? empty(kind === 'documento' ? 'doc' : 'caps', 'tone-c', kind === 'documento' ? 'No hay documentación' : kind === 'capsula' ? 'No hay cápsulas' : 'No hay contenido', kind === 'documento' ? 'Sube manuales, planillas o presentaciones. Cada versión queda guardada.' : 'Una cápsula es un video corto con objetivo, pasos y recomendaciones, vinculado a la pantalla donde se usa.', admin() ? `<a class="btn pri" href="${esc(URL_('kwiz', null, kind ? {tipo:kind} : {}))}">${ic('plus', 16)}${kind === 'documento' ? 'Subir documento' : 'Crear cápsula'}</a>` : '')
        : empty('search', 'tone-n', 'No hay resultados', `No encontramos contenido${LF.q ? ` para «${esc(LF.q)}»` : ''} con esos filtros.`, `<button type="button" class="btn out" data-act="clearlf">Limpiar filtros</button>${admin() ? `<a class="btn pri" href="${esc(URL_('kwiz'))}">${ic('plus', 16)}Crear contenido</a>` : puede('reportar') ? btn('plain', 'data-act="report"', 'Reportar un problema') : ''}`))}`;
};

/* ---------- Categorías ---------- */
VIEWS.cats = () => {
  const K = S.K;
  return `${crumbs([['Soporte'], ['Centro de ayuda','help'], ['Categorías']])}
    <div class="ph"><div class="t"><h1>Categorías</h1><p>Ordenan el centro de ayuda. Cada categoría corresponde a un módulo de SIGMA.</p></div><div class="acts">${btn('pri', 'data-act="newcat"', 'Nueva categoría', 'plus')}</div></div>
    ${S.cats.length ? `<div class="grid g3">${S.cats.map(c => { const L = K.filter(k => k.mod === c.aca_modulo); const by = kk => L.filter(k => kk.includes(k.kind)).length;
      return `<section class="card" style="display:flex;flex-direction:column;gap:12px"><div class="ch" style="margin:0"><span class="ico ${CAT_ICO[c.aca_tono] || 'tone-p'}">${ic(c.aca_icono || 'folder', 19)}</span><div class="g"><h2>${esc(c.aca_nombre)}</h2><p>${L.length} contenidos · ${num(L.reduce((a, k) => a + k.viewsT, 0))} visualizaciones</p></div><div class="r"><button type="button" class="ibtn" data-editcat="${c.aca_id}" aria-label="Editar ${esc(c.aca_nombre)}">${ic('edit', 16)}</button></div></div>
        <div class="grid g3" style="gap:6px">${[['Cápsulas',['capsula']],['Videos',['video']],['Documentos',['manual','documento','guia','faq']]].map(([l, kk]) => `<div style="background:var(--surface-2);border-radius:10px;padding:8px 10px"><b class="tnum" style="font-size:17px;display:block">${by(kk)}</b><small class="mut" style="font-size:11.5px">${l}</small></div>`).join('')}</div>
        <a class="btn out sm" href="${esc(URL_('lib', null, {mod:c.aca_modulo}))}" style="align-self:flex-start">Ver contenidos${ic('arrow', 14)}</a></section>`; }).join('')}</div>`
      : empty('folder', 'tone-p', 'No hay categorías', 'Crea una por cada módulo de SIGMA para ordenar el centro de ayuda.', btn('pri', 'data-act="newcat"', 'Nueva categoría', 'plus'))}`;
};
async function catModal(id){
  if (!S.pant){ try { S.pant = (await ws('a', 'Pantallas')).pantallas.filter(x => x.apa_visible); } catch (e){ S.pant = []; } }
  const c = S.cats.find(x => x.aca_id === id) || {};
  const icos = ['box','gear','wrench','users','building','spark','layers','help','folder','chart','cal','shield'];
  openModal(`<div class="modal-h"><span class="ico tone-p" style="width:40px;height:40px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex:none">${ic('folder', 22)}</span><div style="flex:1"><h2>${id ? 'Editar ' + esc(c.aca_nombre) : 'Nueva categoría'}</h2><p>Agrupa contenido del mismo módulo.</p></div></div>
    <div class="modal-b"><div class="f"><label for="catN">Nombre</label><input class="in" id="catN" value="${esc(c.aca_nombre || '')}" placeholder="Ej.: Compras" autofocus></div>
      <div class="f"><label for="catM">Módulo de SIGMA</label><select class="sel" id="catM">${MODS().map(m => `<option${m === c.aca_modulo ? ' selected' : ''}>${esc(m)}</option>`).join('')}</select></div>
      <div class="f"><span class="lb">Ícono</span><div class="pills" id="catI">${icos.map(i => `<button type="button" class="pill" data-catico="${i}" aria-pressed="${(c.aca_icono || 'folder') === i}">${ic(i, 15)}</button>`).join('')}</div></div></div>
    <div class="modal-f"><button type="button" class="btn ghost" data-act="close">Cancelar</button><button type="button" class="btn pri" data-act="savecat" data-id="${id || 0}">Guardar</button></div>`);
}

/* ---------- Detalle de cápsula o documento + versionado ---------- */
LOAD.kb = async () => { S.k = await ws('a', 'Contenido', {id:APP.id, origen:qs.get('origen') || 'directo'}); };
const embed = u => { const y = String(u).match(/(?:youtu\.be\/|v=)([\w-]{6,})/); if (y) return 'https://www.youtube.com/embed/' + y[1]; const v = String(u).match(/vimeo\.com\/(\d+)/); if (v) return 'https://player.vimeo.com/video/' + v[1]; return null; };
const secs = s => { const [m, x] = String(s || '0:00').split(':').map(Number); return (m || 0) * 60 + (x || 0); };
VIEWS.kb = () => {
  const d = S.k, c = d.contenido; if (!c) return empty('search', 'tone-n', 'Ese contenido no existe', 'Puede que se haya archivado.', `<a class="btn out" href="${esc(URL_('help'))}">Ir al centro de ayuda</a>`);
  const kind = c.ayc_tipo, adm = !!c.ADMIN; const vid = ['capsula','video'].includes(kind); const doc = ['manual','documento'].includes(kind);
  const uso = d.uso || {}; const v0 = d.vinculos[0]; const screen = v0 ? (v0.acv_pantalla || v0.acv_submodulo || v0.acv_modulo) : '';
  const media = String(c.ARCHIVO_MIME || '');
  let player = '';
  const embUrl = videoEmb(c.ayc_url);
  const embedPlayer = `<div class="player"><iframe src="${esc(embUrl || '')}" title="${esc(c.ayc_titulo)}" style="position:absolute;inset:0;width:100%;height:100%;border:0" allow="encrypted-media; picture-in-picture; fullscreen" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe></div>`;
  if (vid){
    if (c.ARCHIVO_URL && media.startsWith('video/')) player = `<div class="player" style="background:#0B1020"><video id="kbVideo" src="${esc(c.ARCHIVO_URL)}" controls preload="metadata" style="position:absolute;inset:0;width:100%;height:100%"></video></div>`;
    else if (embUrl) player = embedPlayer;
    else player = `<div class="player">${cover(c.ayc_tema)}<div class="ctr">${c.ayc_url ? `<a class="bigplay" href="${esc(c.ayc_url)}" target="_blank" rel="noopener" data-kbplay="1" aria-label="Abrir el video">${ic('play', 30)}</a>` : `<span class="mut" style="color:#fff">Aún no se subió el video</span>`}</div></div>`;
  } else if (doc){
    player = (embUrl ? embedPlayer : '') + (c.ARCHIVO_URL && media === 'application/pdf' ? `<section class="card pad0" style="overflow:hidden;height:min(70vh,640px)"><iframe src="${esc(c.ARCHIVO_URL)}" title="${esc(c.ayc_titulo)}" style="width:100%;height:100%;border:0"></iframe></section>` : '')
      + `<div style="display:flex;gap:8px;flex-wrap:wrap">${c.ARCHIVO_URL ? `<a class="btn out" href="${esc(c.ARCHIVO_BAJAR)}" data-kbdl="1">${ic('down', 16)}Descargar ${esc(c.ayc_formato || '')}${c.ARCHIVO_BYTE ? ' · ' + pesoTxt(c.ARCHIVO_BYTE) : ''}</a><a class="btn plain" href="${esc(c.ARCHIVO_URL)}" target="_blank" rel="noopener">${ic('ext', 16)}Abrir</a>` : c.ayc_url ? `<a class="btn out" href="${esc(c.ayc_url)}" target="_blank" rel="noopener">${ic('ext', 16)}Abrir documento</a>` : '<p class="mut">Aún no se subió el archivo.</p>'}</div>`;
  } else player = (embUrl ? embedPlayer : '') + `<section class="card"><div style="font-size:14px;line-height:1.7">${esc(c.ayc_cuerpo || c.ayc_descripcion || '').split(/\n{2,}/).map(p => `<p style="margin-bottom:10px">${p.replace(/\n/g, '<br>')}</p>`).join('')}</div>${c.ayc_url && !embUrl ? `<a class="link" href="${esc(c.ayc_url)}" target="_blank" rel="noopener">${ic('ext', 14)}Ver más</a>` : ''}</section>`;
  const mia = d.mia;
  return `${crumbs([['Soporte'], ['Centro de ayuda','help'], [KIND[kind].l, 'lib', null], [c.ayc_titulo]])}
    <header style="display:flex;gap:16px;flex-wrap:wrap;align-items:flex-end">
      <div style="flex:1;min-width:260px"><div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center"><span class="chip ${KIND[kind].c}">${ic(KIND[kind].i, 13)}${KIND[kind].l}</span>${vid && c.ayc_duracion ? `<span class="tag">${ic('clock', 13)}${esc(c.ayc_duracion)} min</span>` : doc ? `<span class="tag">${esc(c.ayc_formato || '')}${c.ayc_paginas ? ' · ' + c.ayc_paginas + ' páginas' : ''}</span>` : c.ayc_lectura ? `<span class="tag">${esc(c.ayc_lectura)}</span>` : ''}<span class="tag">${esc(c.ayc_version)}</span>${c.ayc_estado !== 'Publicado' ? `<span class="chip tone-n"><i></i>${esc(c.ayc_estado)}</span>` : ''}</div>
        <h1 style="font-size:26px;font-weight:800;letter-spacing:-.02em;margin:8px 0 4px">${esc(c.ayc_titulo)}</h1><p class="mut" style="font-size:14px;max-width:70ch">${esc(c.ayc_descripcion || '')}</p>
        <p class="mut" style="font-size:12px;margin-top:8px;display:flex;gap:12px;flex-wrap:wrap"><span>${ic('user', 13)} ${esc(c.EDITOR || c.AUTOR || '')}</span><span>${ic('history', 13)} Actualizado ${fD(D(c.ayc_fecha_actualizacion))}</span><span>${ic('users', 13)} ${esc(c.ayc_audiencia || 'Todos los usuarios')}</span></p></div>
      <div style="display:flex;gap:8px;flex-wrap:wrap">${adm ? `<a class="btn out" href="${esc(URL_('kwiz', c.ayc_id))}">${ic('edit', 16)}Editar</a><button type="button" class="btn sec" data-act="newver">${ic('history', 16)}Nueva versión</button>${c.CAMPANAS && c.ayc_estado === 'Publicado' ? `<a class="btn pri" href="${esc(URL_('cwiz', null, {contenido:c.ayc_id}))}">${ic('mega', 16)}Promocionar</a>` : c.ayc_estado !== 'Publicado' ? `<button type="button" class="btn pri" data-kbestado="Publicado">${ic('send', 16)}Publicar</button>` : ''}` : v0 && v0.URL ? `<a class="btn out" href="${esc(v0.URL)}">${ic('ext', 16)}Ir a ${esc(screen)}</a>` : ''}</div></header>
    <div class="split wide">
      <div style="display:flex;flex-direction:column;gap:16px;min-width:0">
        ${player}
        ${c.ayc_objetivo ? `<section class="card">${chdr('target', 'tone-p', 'Objetivo', '')}<p style="font-size:14px">${esc(c.ayc_objetivo)}</p></section>` : ''}
        ${d.pasos.length ? `<section class="card">${chdr('list', 'tone-p', 'Pasos', vid && $('#kbVideo') !== undefined ? 'Toca un paso para ir a ese momento del video.' : '')}<div class="stepsl">${d.pasos.map((p, i) => `<button type="button" data-seek="${secs(p.acp_minuto)}"${vid ? '' : ' disabled'}><span class="n">${pad(i + 1)}</span><span><b>${esc(p.acp_titulo)}</b></span><time>${esc(p.acp_minuto || '')}</time></button>`).join('')}</div></section>` : ''}
        ${d.recs.length ? `<section class="card">${chdr('bulb', 'tone-w', 'Recomendaciones', '')}<ul style="display:flex;flex-direction:column;gap:8px">${d.recs.map(r => `<li style="display:flex;gap:10px;font-size:13.5px"><span style="color:var(--warning-ink)">${ic('spark', 16)}</span>${esc(r.acr_texto)}</li>`).join('')}</ul></section>` : ''}
        ${d.relacionados.length ? `<section><h2 style="font-size:15px;font-weight:800;margin-bottom:10px">Contenido relacionado</h2><div class="grid g3">${d.relacionados.map((r, i) => kcard(KB(r), i + 1)).join('')}</div></section>` : ''}
      </div>
      <aside style="display:flex;flex-direction:column;gap:16px;min-width:0">
        <section class="card">${chdr('target', 'tone-c', 'Dónde aparece', 'La ayuda contextual la muestra en esta pantalla.')}${d.vinculos.length ? d.vinculos.map(v => `<div class="path" style="margin-bottom:8px">${[v.acv_modulo, v.acv_submodulo, v.acv_pantalla, v.acv_seccion].filter(Boolean).map(esc).join(' <i>›</i> ')}</div>`).join('') : '<p class="mut" style="font-size:12.5px">Sin vincular a una pantalla.</p>'}
          ${v0 && v0.URL ? `<a class="btn out sm" style="margin-top:6px" href="${esc(v0.URL)}">${ic('ext', 15)}Ir a ${esc(screen)}</a>` : ''}</section>
        ${!adm ? `<section class="card">${chdr('thumb', 'tone-s', '¿Te sirvió?', mia ? 'Gracias, ya nos dijiste. Puedes cambiar tu respuesta.' : 'Tu respuesta mejora el contenido.')}<div style="display:flex;gap:8px;flex-wrap:wrap"><button type="button" class="btn ${mia && mia.ava_util ? 'sec' : 'out'} sm" data-util="1">${ic('thumb', 15)}Sí</button><button type="button" class="btn ${mia && !mia.ava_util ? 'sec' : 'plain'} sm" data-util="0">No mucho</button></div></section>` : `
        <section class="card">${chdr('chart', 'tone-p', 'Uso', 'Últimos 30 días.')}<div class="grid g2" style="gap:8px">${[[num(uso.VISTAS), 'Visualizaciones'], [num(uso.UNICOS), 'Usuarios únicos'], vid ? [num(uso.REPRODUCCIONES), 'Reproducciones'] : [num(uso.DESCARGAS), 'Descargas'], vid ? [uso.REPRODUCCIONES ? pct(uso.COMPLETOS, uso.REPRODUCCIONES) + ' %' : '—', 'Vieron hasta el final'] : [uso.VALORACION ? String(uso.VALORACION).replace('.', ',') + ' ★' : '—', 'Valoración']].map(([v, l]) => `<div style="background:var(--surface-2);border-radius:12px;padding:10px 12px"><b class="tnum" style="font-size:18px;display:block">${v}</b><small class="mut" style="font-size:11.5px">${l}</small></div>`).join('')}</div>
          <p class="mut" style="font-size:12px;margin-top:10px">${uso.VALORACION ? 'Valoración ' + String(uso.VALORACION).replace('.', ',') + ' ★ · ' : ''}${num(uso.EVITADOS)} ${uso.EVITADOS === 1 ? 'ticket evitado' : 'tickets evitados'} este mes</p></section>`}
        <section class="card">${chdr('history', 'tone-b', 'Versiones', `${esc(c.ayc_version)} · ${c.ayc_estado === 'Publicado' ? 'publicada' : esc(c.ayc_estado.toLowerCase())} ${fD(D(c.ayc_fecha_actualizacion))}`, d.versiones.length > 1 && adm ? `<button type="button" class="link" data-act="versions">Historial</button>` : '')}
          ${d.versiones.length ? `<div class="ver">${d.versiones.slice(0, 4).map((v, i) => `<div class="ver-i${i === 0 ? ' cur' : ''}"><span class="v">${esc(v.aver_version)}</span><span><b>${esc(v.aver_nota || '')}</b><small>${fD(D(v.aver_fecha))} · ${esc(v.AUTOR || '')}</small></span></div>`).join('')}</div>` : `<p class="mut" style="font-size:12.5px">Todavía no se publica.</p>`}</section>
      </aside></div>`;
};
AFTER.kb = () => {
  const v = $('#kbVideo'); if (!v) return; let rep = false;
  v.addEventListener('play', () => { if (!rep){ rep = true; ws('a', 'Interaccion', {id:APP.id, tipo:'reproduccion', origen:qs.get('origen') || ''}).catch(() => {}); } });
  v.addEventListener('ended', () => ws('a', 'Interaccion', {id:APP.id, tipo:'completo', origen:qs.get('origen') || ''}).catch(() => {}));
};
function openVersions(){
  const d = S.k, c = d.contenido;
  openDrawer(`<div class="drawer-h"><h2>Historial de versiones<small style="display:block;font-size:12.5px;font-weight:500;color:var(--muted)">${esc(c.ayc_titulo)}</small></h2><button type="button" class="ibtn" data-act="close" aria-label="Cerrar">${ic('x', 20)}</button></div>
    <div class="drawer-b">${d.versiones.map((v, i) => `<section class="card"><div class="ch" style="margin-bottom:8px"><span class="ico ${i === 0 ? 'tone-p' : 'tone-n'}" style="font-size:12px;font-weight:800">${esc(v.aver_version)}</span><div class="g"><h3>${esc(v.aver_nota || '')}</h3><p>${fD(D(v.aver_fecha))} · ${esc(v.AUTOR || '')}${i === 0 ? ' · versión actual' : ''}</p></div>${i ? `<div class="r"><button type="button" class="btn plain xs" data-restore="${v.aver_id}" data-v="${esc(v.aver_version)}">${ic('reopen', 14)}Restaurar</button></div>` : `<div class="r"><span class="chip tone-s"><i></i>${esc(v.aver_estado)}</span></div>`}</div>
      <div style="font-size:12.5px" class="mut">${i < d.versiones.length - 1 ? `Estado: ${esc(v.aver_estado)} · Autor: ${esc(v.AUTOR || '')}` : 'Primera publicación.'}</div></section>`).join('')}</div>
    <div class="drawer-f"><span class="g">Cada publicación guarda una versión. Restaurar publica una versión nueva con ese contenido.</span><button type="button" class="btn sec" data-act="newver">${ic('history', 16)}Nueva versión</button></div>`);
}
function siguienteV(v){ const n = parseFloat(String(v || 'v1.0').replace(/[^\d.]/g, '')) || 1; return 'v' + (n + .1).toFixed(1); }
function newVerModal(){
  const c = S.k.contenido; NV.file = null;
  openModal(`<div class="modal-h"><span class="ico tone-c" style="width:40px;height:40px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex:none">${ic('history', 22)}</span><div style="flex:1"><h2>Nueva versión de «${esc(c.ayc_titulo)}»</h2><p>La versión actual queda en el historial.</p></div></div>
    <div class="modal-b"><label class="drop" data-drop="ver"><span class="di">${ic('upload', 20)}</span><span class="dt"><b id="nvF">Archivo actualizado (opcional)</b>${esc(c.ayc_formato || 'PDF, MP4…')} · hasta 60 MB</span><span class="btn out sm">Elegir</span><input type="file" class="sr" data-nvfile="1"></label>
      <div class="fg"><div class="f"><label for="nvV">Versión</label><input class="in" id="nvV" value="${esc(siguienteV(c.ayc_version))}"></div><div class="f"><label for="nvN">Qué cambió <span class="req">*</span></label><input class="in" id="nvN" placeholder="Ej.: Nuevo mapa 3D" autofocus></div></div></div>
    <div class="modal-f"><button type="button" class="btn ghost" data-act="close">Cancelar</button><button type="button" class="btn pri" data-act="donewver">Publicar versión</button></div>`);
}
const NV = {file:null};

/* ---------- Crear o editar contenido (con vinculación contextual) ---------- */
const KW = {step:1, d:null, done:null, from:null, guardando:false, aud:null};
const KW_STEPS = [['Información','Qué enseña'],['Contenido','Archivo, pasos y consejos'],['Ubicación','Dónde aparece'],['Audiencia','Quién la ve'],['Publicar','Versión y estado']];
LOAD.kwiz = async () => {
  const [p, v] = await Promise.all([ws('a', 'Pantallas'), ws('c', 'Valores').catch(() => ({valores:[], segmentos:[]}))]);
  S.pant = p.pantallas; S.secs = p.secciones; S.val = v.valores; S.segs = v.segmentos;
  KW.step = 1; KW.done = null; KW.from = null;
  KW.d = {id:null, t:'', kind:qs.get('tipo') && KIND[qs.get('tipo')] ? qs.get('tipo') : 'capsula', desc:'', obj:'', cuerpo:'', archivo:null, archivoN:'', fmt:'', dur:'', pages:'', url:'', steps:[{t:'Abrir la pantalla', m:'0:00'}], recs:[''],
    path:['','','',''], aud:'todos', perfiles:[], seg:null, pub:'now', ver:'v1.0', notes:'Primera versión.', announce:false, tema:0, recurrente:null};
  if (APP.id){
    const d = await ws('a', 'Contenido', {id:APP.id, origen:''}); const c = d.contenido; const v0 = d.vinculos[0] || {};
    let conds = []; try { conds = JSON.parse(c.ayc_audiencia_condiciones || '[]'); } catch (e){}
    Object.assign(KW.d, {id:c.ayc_id, t:c.ayc_titulo, kind:c.ayc_tipo, desc:c.ayc_descripcion || '', obj:c.ayc_objetivo || '', cuerpo:c.ayc_cuerpo || '', archivo:c.ayc_archivo, archivoN:c.ARCHIVO_NOMBRE || '', fmt:c.ayc_formato || '', dur:c.ayc_duracion || '', pages:c.ayc_paginas || '', url:c.ayc_url || '',
      steps:d.pasos.length ? d.pasos.map(x => ({t:x.acp_titulo, m:x.acp_minuto || ''})) : [{t:'', m:''}], recs:d.recs.length ? d.recs.map(x => x.acr_texto) : [''], path:[v0.acv_modulo || '', v0.acv_submodulo || '', v0.acv_pantalla || '', v0.acv_seccion || ''],
      aud:!conds.length ? 'todos' : conds.every(x => x.campo === 'perfil') ? 'perfiles' : 'seg', perfiles:conds.filter(x => x.campo === 'perfil').map(x => x.valor), condsSeg:conds, unionSeg:c.ayc_audiencia_union,
      ver:c.ayc_estado === 'Publicado' ? siguienteV(c.ayc_version) : c.ayc_version, notes:'', pub:c.ayc_estado === 'Publicado' ? 'now' : c.ayc_estado === 'En revisión' ? 'review' : 'draft', tema:c.ayc_tema || 0, estadoAnt:c.ayc_estado});
  }
  const rec = +(qs.get('recurrente') || 0);
  if (rec){ const r = (await ws('s', 'Recurrente', {id:rec})).recurrente; KW.from = r;
    Object.assign(KW.d, {t:'Cómo resolver: ' + r.sre_titulo, kind:qs.get('tipo') || 'capsula', desc:(r.sre_causa ? r.sre_causa + ' ' : '') + `Esta ${qs.get('tipo') === 'guia' ? 'guía' : 'cápsula'} explica cómo evitarlo.`, obj:`Que el usuario pueda resolver «${r.sre_titulo}» sin crear un ticket.`,
      path:[r.sre_modulo || '', r.sre_submodulo || '', r.sre_pantalla || '', r.sre_seccion || ''], recs:r.sre_causa ? [r.sre_causa] : [''], recurrente:r.sre_id}); }
  const tk = +(qs.get('ticket') || 0);
  if (tk){ const t = (await ws('s', 'Ticket', {id:tk})).ticket; const res = null;
    Object.assign(KW.d, {t:'Cómo resolver: ' + t.stk_titulo, desc:t.stk_descripcion || '', path:[t.stk_modulo || '', t.stk_submodulo || '', t.stk_pantalla || '', t.stk_seccion || ''], recurrente:t.stk_recurrente}); }
  if (qs.get('q')) KW.d.t = 'Cómo ' + qs.get('q');
  kwAudiencia();
};
const kwConds = () => { const d = KW.d; return d.aud === 'todos' ? [] : d.aud === 'perfiles' ? d.perfiles.map(p => ({campo:'perfil', op:'=', valor:p})) : (d.condsSeg || []); };
const kwUnion = () => KW.d.aud === 'perfiles' ? 'OR' : KW.d.aud === 'seg' ? (KW.d.unionSeg || 'AND') : 'AND';
const kwAudiencia = debounce(async () => { try { KW.aud = (await ws('c', 'Audiencia', {condiciones:JSON.stringify(kwConds()), union:kwUnion(), dimension:'perfil'})).conteo; } catch (e){ KW.aud = null; } if (APP.vista === 'kwiz' && KW.step === 4) render(); }, 250);
VIEWS.kwiz = () => {
  const d = KW.d, st = KW.step; const r = KW.from;
  if (KW.done){ const k = KW.done;
    return `${crumbs([['Soporte'], ['Centro de ayuda','help'], ['Contenido guardado']])}<section class="card"><div class="success"><span class="ok">${ic('check', 34)}</span><h2 style="font-size:22px;font-weight:800">${k.estado === 'Publicado' ? '¡Publicado!' : k.estado === 'En revisión' ? 'Enviado a revisión' : 'Borrador guardado'}</h2>
      <p class="mut" style="max-width:48ch">«${esc(d.t)}» ${k.estado === 'Publicado' ? `ya aparece en <b style="color:var(--ink)">${esc(d.path.filter(Boolean).join(' › ') || 'el centro de ayuda')}</b> cuando alguien abre la ayuda.` : 'quedó guardado. Lo puedes seguir editando.'}</p>
      <div style="display:flex;gap:10px;flex-wrap:wrap;justify-content:center"><a class="btn out" href="${esc(URL_('kb', k.id))}">Ver ${KIND[d.kind].l.toLowerCase()}</a>${k.estado === 'Publicado' && puede('campanas') ? `<a class="btn pri" href="${esc(URL_('cwiz', null, {contenido:k.id}))}">${ic('mega', 16)}Anunciar con una campaña</a>` : `<a class="btn pri" href="${esc(URL_('help'))}">Volver al centro de ayuda</a>`}</div></div></section>`; }
  const body = [kwInfo, kwContent, kwPlace, kwAud, kwPub][st - 1](d);
  const can = d.t.trim().length > 2;
  return `${crumbs([['Soporte'], ['Centro de ayuda','help'], [d.id ? 'Editar contenido' : 'Crear contenido']])}
    <div class="ph"><div class="t"><h1>${d.id ? 'Editar' : 'Crear'} ${KIND[d.kind].l.toLowerCase()}</h1><p>${esc(d.t || 'Sin título')} · ${esc(d.path.filter(Boolean).join(' › ') || 'sin ubicación')}</p></div></div>
    ${r ? `<div class="sug" style="background:var(--warning-soft)"><div class="hd" style="color:var(--warning-ink)">${ic('bulb', 18)}Creado desde el problema recurrente «${esc(r.sre_titulo)}» (${num(r.N30)} tickets este mes)</div><span style="font-size:12.5px;color:#6B4300">Precargamos el módulo, la pantalla y el contexto. Cuando se publique, los tickets nuevos sobre esto recibirán este contenido como sugerencia.</span></div>` : ''}
    <div class="wz"><nav class="steps" aria-label="Pasos">${KW_STEPS.map(([t, s], i) => `<button type="button" class="step${i + 1 < st ? ' done' : ''}" data-kwstep="${i + 1}"${i + 1 === st ? ' aria-current="step"' : ''}${!can && i ? ' disabled' : ''}><span class="n">${i + 1 < st ? ic('check', 15) : i + 1}</span><span><b>${t}</b><small>${s}</small></span></button>`).join('')}</nav>
      <div style="display:flex;flex-direction:column;gap:16px;min-width:0">${body}
        <div class="wz-foot">${st > 1 ? `<button type="button" class="btn out" data-kwstep="${st - 1}">${ic('cl', 16)}Anterior</button>` : ''}<span class="g">Paso ${st} de 5${!can ? ' · Falta el título' : ''}</span><a class="btn ghost" href="${esc(d.id ? URL_('kb', d.id) : URL_('help'))}">Cancelar</a>
          ${st < 5 ? `<button type="button" class="btn pri" data-kwstep="${st + 1}"${!can ? ' disabled' : ''}>Siguiente${ic('arrow', 16)}</button>` : `<button type="button" class="btn pri" data-act="kwsave"${can && !KW.guardando ? '' : ' disabled'}>${KW.guardando ? '<span class="giro" aria-hidden="true"></span>' + {now:'Publicando…', review:'Enviando…', draft:'Guardando…'}[d.pub] : ic(d.pub === 'now' ? 'send' : 'check', 16) + {now:'Publicar', review:'Enviar a revisión', draft:'Guardar borrador'}[d.pub]}</button>`}</div></div></div>`;
};
function kwInfo(d){
  return `<section class="card">${chdr('caps', 'tone-p', 'Información', 'Lo esencial para que el usuario sepa si le sirve.')}
    <div class="fg"><div class="f full"><span class="lb">Tipo</span><div class="optcards" style="grid-template-columns:repeat(auto-fill,minmax(150px,1fr))">${[['capsula','Video corto con pasos'],['video','Video de una funcionalidad'],['documento','PDF, Word, Excel o PowerPoint'],['manual','Documento largo con versiones'],['guia','Artículo breve'],['faq','Pregunta y respuesta']].map(([k, s]) => `<button type="button" class="opt" data-kwkind="${k}" aria-pressed="${d.kind === k}">${ic(KIND[k].i, 18)}${KIND[k].l}<small>${s}</small></button>`).join('')}</div></div>
      <div class="f full"><label for="kwT">Título <span class="req">*</span></label><input class="in" id="kwT" data-kw="t" value="${esc(d.t)}" maxlength="200" placeholder="Empieza con un verbo. Ej.: Cómo crear una ubicación" autofocus></div>
      <div class="f full"><label for="kwD">Descripción</label><textarea class="ta" id="kwD" data-kw="desc" maxlength="1000" placeholder="Una o dos frases: qué aprenderá.">${esc(d.desc)}</textarea></div>
      <div class="f full"><label for="kwO">Objetivo</label><input class="in" id="kwO" data-kw="obj" value="${esc(d.obj)}" maxlength="500" placeholder="Al terminar, el usuario podrá…"></div></div></section>`;
}
function kwContent(d){
  const vid = ['capsula','video'].includes(d.kind), doc = ['documento','manual'].includes(d.kind), txt = ['guia','faq'].includes(d.kind);
  return `<section class="card">${chdr('upload', 'tone-c', 'Contenido', txt ? 'Escribe el artículo. Puedes enlazar una URL externa.' : 'Sube el archivo o enlaza una URL externa.')}
      ${txt ? `<div class="f"><label for="kwC">${d.kind === 'faq' ? 'Respuesta' : 'Texto de la guía'}</label><textarea class="ta" id="kwC" data-kw="cuerpo" style="min-height:180px" placeholder="Separa los párrafos con una línea en blanco.">${esc(d.cuerpo)}</textarea></div>`
        : `<label class="drop" data-drop="kw"><span class="di">${ic('upload', 20)}</span><span class="dt"><b>${d.archivo ? 'Archivo cargado: ' + esc(d.archivoN || 'listo') : 'Arrastra el archivo aquí'}</b>${vid ? 'MP4 o WebM' : 'PDF, DOCX, XLSX o PPTX'} · hasta 60 MB</span><span class="btn out sm">${d.archivo ? 'Reemplazar' : 'Elegir archivo'}</span><input type="file" class="sr" data-kwfiles="1" accept="${vid ? 'video/*' : '.pdf,.docx,.xlsx,.pptx,.doc,.xls,.ppt'}"></label>
          <div class="files" id="kwFiles">${KW.subiendo ? fileRow(KW.subiendo) : ''}</div>`}
      <div class="fg" style="margin-top:12px"><div class="f${vid || doc ? '' : ' full'}"><label for="kwU">${txt ? 'Enlace (opcional)' : 'O una URL externa'}</label><input class="in" id="kwU" data-kw="url" value="${esc(d.url)}" placeholder="https://… (YouTube, Vimeo, SharePoint)"></div>
        ${vid ? `<div class="f"><label for="kwDur">Duración (m:ss)</label><input class="in tnum" id="kwDur" data-kw="dur" value="${esc(d.dur)}" placeholder="2:34"></div>` : doc ? `<div class="f"><label for="kwPg">Páginas</label><input class="in tnum" type="number" min="1" id="kwPg" data-kw="pages" value="${esc(d.pages)}" placeholder="12"></div>` : ''}</div></section>
    ${['capsula','video','guia','manual'].includes(d.kind) ? `<section class="card">${chdr('list', 'tone-p', 'Pasos', vid ? 'Con el minuto en que aparece cada uno. Arrastra para ordenar.' : 'Arrastra para ordenar.')}
      <div class="rows" id="kwSteps">${d.steps.map((s, i) => `<div class="row" draggable="true" data-kwdrag="${i}" style="grid-template-columns:20px 34px minmax(0,1fr) ${vid ? '90px ' : ''}34px;cursor:grab"><span class="mut">${ic('drag', 16)}</span><span class="tag tone-p" style="justify-content:center">${pad(i + 1)}</span><input class="in" style="height:36px" data-kwstepn="${i}" value="${esc(s.t)}" aria-label="Paso ${i + 1}">${vid ? `<input class="in tnum" style="height:36px" data-kwstept="${i}" value="${esc(s.m)}" placeholder="0:00" aria-label="Minuto del paso ${i + 1}">` : ''}<button type="button" class="ibtn" data-kwdel="${i}" aria-label="Quitar paso">${ic('trash', 16)}</button></div>`).join('')}</div>
      <button type="button" class="btn ghost sm" style="margin-top:10px" data-act="kwaddstep">${ic('plus', 15)}Agregar paso</button></section>` : ''}
    <section class="card">${chdr('bulb', 'tone-w', 'Recomendaciones', 'Consejos cortos que evitan errores.')}<div class="rows">${d.recs.map((r, i) => `<div class="row" style="grid-template-columns:minmax(0,1fr) 34px"><input class="in" style="height:36px" data-kwrec="${i}" value="${esc(r)}" maxlength="400" placeholder="Ej.: Usa códigos cortos y ordenados por pasillo." aria-label="Recomendación ${i + 1}"><button type="button" class="ibtn" data-kwrecdel="${i}" aria-label="Quitar">${ic('trash', 16)}</button></div>`).join('')}</div><button type="button" class="btn ghost sm" style="margin-top:10px" data-act="kwaddrec">${ic('plus', 15)}Agregar recomendación</button></section>`;
}
function kwPlace(d){
  const [m, s, p, sec] = d.path; const P_ = S.pant.filter(x => x.apa_visible || x.apa_pantalla === p);
  const mods = [...new Set(P_.map(x => x.apa_modulo))]; const subs = m ? [...new Set(P_.filter(x => x.apa_modulo === m).map(x => x.apa_submodulo))] : [];
  const pants = m && s ? [...new Set(P_.filter(x => x.apa_modulo === m && x.apa_submodulo === s).map(x => x.apa_pantalla))] : [];
  const secs_ = m && s && p ? [...new Set(S.secs.filter(x => x.acv_modulo === m && x.acv_pantalla === p).map(x => x.acv_seccion)), ...(sec ? [sec] : [])].filter((v, i, a) => a.indexOf(v) === i) : [];
  const col = (h, list, cur, lvl, extra = '') => `<div class="casc-col" role="group" aria-label="${h}"><h4>${h}</h4>${list.length ? list.map(x => `<button type="button" data-kwpath="${lvl}" data-v="${esc(x)}" aria-pressed="${cur === x}">${esc(x)}${lvl < 3 ? ic('cr', 14) : ''}</button>`).join('') : `<span class="mut" style="font-size:12px;padding:8px">${lvl === 3 && p ? 'Sin secciones aún' : 'Elige ' + (lvl === 1 ? 'un módulo' : lvl === 2 ? 'un submódulo' : 'una pantalla')}</span>`}${extra}</div>`;
  const items = [{ayc_id:0, ayc_tipo:d.kind, ayc_titulo:d.t || 'Tu contenido', ayc_duracion:d.dur, ayc_paginas:d.pages, ayc_formato:d.fmt}];
  return `<section class="card">${chdr('target', 'tone-c', 'Vinculación contextual', 'Elige dónde se usa. La ayuda aparecerá sola en esa pantalla, en «? Ayuda».')}
      <div class="cascade">${col('Módulo', mods, m, 0)}${col('Submódulo', subs, s, 1)}${col('Pantalla', pants, p, 2)}${col('Sección', secs_, sec, 3, p ? `<div style="display:flex;gap:4px;padding:4px"><input class="in" id="kwSecN" style="height:32px;font-size:12.5px" placeholder="Nueva sección"><button type="button" class="ibtn" data-act="kwaddsec" aria-label="Agregar sección">${ic('plus', 15)}</button></div>` : '')}</div>
      <div class="path" style="margin-top:14px">${ic('pin', 16)}${d.path.filter(Boolean).map(esc).join(' <i>›</i> ') || 'Sin ubicación'}</div></section>
    <section class="card">${chdr('eye', 'tone-p', 'Así aparecerá', `Cuando alguien toque «? Ayuda» en ${esc(p || s || m || 'esa pantalla')}.`)}
      <div style="background:var(--canvas);border-radius:16px;padding:18px;display:flex;justify-content:flex-end"><div class="pop" style="position:static;z-index:auto;box-shadow:var(--e2)"><div class="pop-h"><span style="font-size:22px" aria-hidden="true">👋</span><span style="flex:1"><b>¿Necesitas ayuda?</b><small>Contenido para esta pantalla</small></span></div><div class="ctxpill">${ic('pin', 14)}<span>Estás en <b>${esc([s, p].filter(Boolean).join(' › ') || m || '—')}</b></span></div><div class="pop-b">${items.map(k => `<span class="hitem"><span class="t ${KIND[k.ayc_tipo].c}">${ic(KIND[k.ayc_tipo].i, 20)}</span><span><b>${esc(k.ayc_titulo)}</b><small>${KIND[k.ayc_tipo].l}</small></span><span class="tag tone-p">Nuevo</span></span>`).join('')}</div></div></div></section>`;
}
function kwAud(d){
  const n = KW.aud ? KW.aud.ALCANCE : null; const perfiles = valoresDe('perfil');
  return `<section class="card">${chdr('users', 'tone-b', 'Audiencia', 'Quién puede ver este contenido.')}
    <div class="optcards" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr))">${[['todos','Todos los usuarios','Cualquiera que abra la ayuda.'],['perfiles','Algunos perfiles','Solo los perfiles que elijas.'],['seg','Un segmento guardado','El mismo que usas en campañas.']].map(([k, l, s]) => `<button type="button" class="opt" data-kwaud="${k}" aria-pressed="${d.aud === k}">${l}<small>${s}</small></button>`).join('')}</div>
    ${d.aud === 'perfiles' ? `<div class="pills" style="margin-top:12px">${perfiles.map(p => `<button type="button" class="pill" data-kwperf="${esc(p.VALOR)}" aria-pressed="${d.perfiles.includes(p.VALOR)}">${esc(p.ETIQUETA)}</button>`).join('')}</div>`
      : d.aud === 'seg' ? `<div class="pills" style="margin-top:12px">${(S.segs || []).length ? S.segs.map(s => `<button type="button" class="pill" data-kwseg="${s.csg_id}" aria-pressed="${d.seg === s.csg_id}">${esc(s.csg_nombre)}</button>`).join('') : '<span class="mut" style="font-size:12.5px">No hay segmentos guardados. Créalos en el asistente de campañas.</span>'}</div>` : ''}
    <div class="aud-reach" style="margin-top:14px"><div style="flex:1"><b>${n == null ? '…' : num(n)}</b><small style="display:block">usuarios podrán verlo${d.aud === 'perfiles' && !d.perfiles.length ? ' (elige al menos un perfil)' : ''}</small></div></div></section>`;
}
function kwPub(d){
  return `<section class="card">${chdr('send', 'tone-p', 'Publicar', 'Cada publicación queda como una versión.')}
    <div class="fg"><div class="f full"><span class="lb">Estado</span><div class="optcards" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr))">${[['now','Publicar ahora','Aparece de inmediato en la ayuda.','send'],['review','Enviar a revisión','Otra persona del equipo la aprueba.','eye'],['draft','Guardar borrador','Nadie más la ve todavía.','doc']].map(([k, l, s, i]) => `<button type="button" class="opt" data-kwpub="${k}" aria-pressed="${d.pub === k}">${ic(i, 18)}${l}<small>${s}</small></button>`).join('')}</div></div>
      <div class="f"><label for="kwV">Versión</label><input class="in" id="kwV" data-kw="ver" value="${esc(d.ver)}"></div><div class="f"><label for="kwN">Notas de la versión</label><input class="in" id="kwN" data-kw="notes" value="${esc(d.notes)}" placeholder="Qué cambió"></div>
      ${puede('campanas') ? `<div class="f full"><label style="display:flex;align-items:center;gap:12px;font-size:13.5px"><button type="button" class="switch" role="switch" aria-checked="${d.announce}" data-kwsw="announce" aria-label="Anunciar con campaña"></button><span><b>Anunciarla con una campaña</b><span class="mut" style="display:block;font-size:12px">Al publicar te llevamos al asistente de campañas con el contenido ya elegido.</span></span></label></div>` : ''}</div>
    <div class="rows" style="margin-top:16px"><div class="row"><span class="ico tone-p">${ic(KIND[d.kind].i, 17)}</span><span><strong>${esc(d.t || 'Sin título')}</strong><small>${KIND[d.kind].l} · ${d.archivo ? esc(d.archivoN || 'Archivo') : d.url ? 'URL externa' : ['guia','faq'].includes(d.kind) ? 'Texto' : 'Sin archivo'} · ${d.steps.filter(s => s.t.trim()).length} pasos</small></span><span class="e"></span></div><div class="row"><span class="ico tone-c">${ic('target', 17)}</span><span><strong>${esc(d.path.filter(Boolean).join(' › ') || 'Sin ubicación')}</strong><small>Aparece en la ayuda contextual</small></span><span class="e"></span></div></div></section>`;
}
function readKW(){ if (!KW.d) return; $$('[data-kw]').forEach(el => { KW.d[el.dataset.kw] = el.value; }); $$('[data-kwstepn]').forEach(el => { KW.d.steps[+el.dataset.kwstepn].t = el.value; }); $$('[data-kwstept]').forEach(el => { KW.d.steps[+el.dataset.kwstept].m = el.value; }); $$('[data-kwrec]').forEach(el => { KW.d.recs[+el.dataset.kwrec] = el.value; }); }
async function subirKW(f){
  if (f.size > 60 * 1048576){ toast('El archivo pesa más de 60 MB.', null, true); return; }
  KW.subiendo = {n:f.name, ext:f.name.split('.').pop(), k:tipoArch(f.name), s:pesoTxt(f.size), p:30}; const box = $('#kwFiles'); box && (box.innerHTML = fileRow(KW.subiendo));
  try { const r = await ws('a', 'Subir', {nombre:f.name, mime:f.type, base64:await leer64(f), destino:'ayuda'}); readKW();
    Object.assign(KW.d, {archivo:r.id, archivoN:f.name, fmt:(f.name.split('.').pop() || '').toUpperCase()}); KW.subiendo = null; render(); toast('Archivo cargado');
    if (/^video\//.test(f.type)){ const v = document.createElement('video'); v.preload = 'metadata'; v.onloadedmetadata = () => { if (!KW.d.dur){ KW.d.dur = Math.floor(v.duration / 60) + ':' + pad(Math.round(v.duration % 60)); render(); } URL.revokeObjectURL(v.src); }; v.src = URL.createObjectURL(f); }
  } catch (e){ KW.subiendo = null; render(); fallo(e); }
}
async function guardarKW(){
  readKW(); const d = KW.d; KW.guardando = true; render();
  const estado = {now:'Publicado', review:'En revisión', draft:'Borrador'}[d.pub];
  const aud = d.aud === 'todos' ? 'Todos los usuarios' : d.aud === 'perfiles' ? 'Perfiles: ' + d.perfiles.join(', ') : 'Segmento: ' + ((S.segs || []).find(s => s.csg_id === d.seg) || {}).csg_nombre;
  try {
    const r = await ws('a', 'Guardar', {datos:JSON.stringify({id:d.id, tipo:d.kind, titulo:d.t, descripcion:d.desc, objetivo:d.obj, cuerpo:d.cuerpo, formato:d.fmt || (['guia','faq'].includes(d.kind) ? 'Web' : d.url ? 'URL' : ''),
      duracion:d.dur, paginas:d.pages || null, lectura:['guia','faq'].includes(d.kind) ? Math.max(1, Math.round((d.cuerpo || d.desc).split(/\s+/).length / 180)) + ' min de lectura' : null,
      archivo:d.archivo, url:d.url, estado, version:d.ver, nota:d.notes || (d.id ? 'Actualización' : 'Primera versión.'), audiencia:aud, condiciones:kwConds(), union:kwUnion(), tema:d.tema, recurrente:d.recurrente,
      pasos:d.steps.filter(s => s.t.trim()).map(s => ({t:s.t, m:s.m})), recs:d.recs.filter(x => x.trim()).map(t => ({t})), vinculos:d.path[0] ? [{m:d.path[0], s:d.path[1], p:d.path[2], sec:d.path[3]}] : []})});
    KW.guardando = false;
    if (estado === 'Publicado' && d.announce && puede('campanas')){ toast('Publicado. Ahora arma la campaña para anunciarlo.'); go('cwiz', null, {contenido:r.id}); return; }
    KW.done = r; render(); toast(estado === 'Publicado' ? 'Contenido publicado' : 'Contenido guardado');
  } catch (e){ KW.guardando = false; render(); fallo(e); }
}

/* ---------- Analítica del centro de ayuda ---------- */
const AK = {per:30};
LOAD.kbstats = async () => { const [a, k] = await Promise.all([ws('a', 'Analitica', {dias:AK.per}), ws('a', 'Contenidos')]); S.ak = a; S.K = k.contenidos.map(KB); };
VIEWS.kbstats = () => {
  const a = S.ak, k = a.kpi || {}; const K = S.K.filter(x => x.status === 'Publicado');
  const top = [...K].sort((x, y) => y.views - x.views || y.viewsT - x.viewsT); const low = [...K].sort((x, y) => x.views - y.views || x.viewsT - y.viewsT).slice(0, 3);
  const dv = k.VISTAS_PREV ? Math.round((k.VISTAS - k.VISTAS_PREV) / k.VISTAS_PREV * 100) : null;
  const iniciados = (k.EVITADOS || 0) + (k.TICKETS || 0);
  return `${crumbs([['Soporte','hub'], ['Analítica'], ['Centro de ayuda']])}
    <div class="ph"><div class="t"><h1>Analítica del centro de ayuda</h1><p>Qué contenido se usa, cuál no, y cuántos problemas se evitan con autoservicio.</p></div><div class="acts"><div class="seg" role="group" aria-label="Período">${[[7,'7 días'],[30,'30 días'],[90,'90 días']].map(([v, l]) => `<button type="button" data-akper="${v}" aria-pressed="${AK.per === v}">${l}</button>`).join('')}</div></div></div>
    <div class="grid g3 keep2">
      ${kpi('eye', 'tone-p', num(k.VISTAS), 'Visualizaciones', dv == null ? `En ${AK.per} días` : `<span class="delta ${dv >= 0 ? 'ok' : 'up'}">${dv >= 0 ? '+' : ''}${dv} %</span> vs. período anterior`)}${kpi('users', 'tone-b', num(k.UNICOS), 'Usuarios únicos', 'Al menos una consulta')}${kpi('down', 'tone-c', num(k.DESCARGAS), 'Descargas', 'Manuales y documentos')}
      ${kpi('play', 'tone-p', num(k.REPRODUCCIONES), 'Reproducciones', 'Cápsulas y videos')}${kpi('check', 'tone-s', k.REPRODUCCIONES ? pct(k.COMPLETOS, k.REPRODUCCIONES) + ' %' : '—', 'Finalización de videos', 'Vieron hasta el final')}${kpi('star', 'tone-w', k.VALORACION ? String(k.VALORACION).replace('.', ',') + ' ★' : '—', 'Valoración', `${num(k.VALORACIONES)} respuestas`)}
    </div>
    <div class="split">
      <section class="card">${chdr('activity', 'tone-p', 'Visualizaciones por día', `Últimos ${AK.per} días.`)}${lineChart([{l:'Visualizaciones', c:'#6732F4', d:a.dias.map(x => x.N)}], a.dias.map(x => fDs(D(x.dia))), {area:true, h:200, label:'Visualizaciones por día'})}</section>
      <section class="card">${chdr('shield', 'tone-s', 'Ayuda que evitó tickets', 'Sugerida al reportar y el usuario dijo «Sí, se resolvió».')}
        <div style="display:flex;align-items:baseline;gap:8px"><b class="tnum" style="font-size:34px;font-weight:800">${iniciados ? pct(k.EVITADOS, iniciados) + ' %' : '—'}</b><span class="mut">de los reportes iniciados</span></div><p class="mut" style="font-size:12.5px;margin:4px 0 12px">${num(k.EVITADOS)} ${k.EVITADOS === 1 ? 'problema se resolvió' : 'problemas se resolvieron'} sin crear ticket en el período.</p>
        ${hbars(a.evitados.map(x => ({l:x.ayc_titulo, v:x.N})), {unit:'tickets evitados'})}</section>
    </div>
    <section class="card">${chdr('chart', 'tone-p', 'Contenido más consultado', `Últimos 30 días.`)}
      ${top.length ? `<div style="overflow-x:auto"><table style="width:100%;border-collapse:separate;border-spacing:0 6px;font-size:13px;min-width:720px"><thead><tr style="font-size:10.5px;letter-spacing:.06em;text-transform:uppercase;color:var(--faint)">${['Contenido','Visualizaciones','Usuarios únicos','Descargas / reproducciones','Finalización','Valoración'].map((h, i) => `<th style="text-align:${i ? 'right' : 'left'};padding:0 12px">${h}</th>`).join('')}</tr></thead><tbody>
        ${top.slice(0, 6).map(x => `<tr style="background:var(--surface-2);cursor:pointer" data-href="${esc(URL_('kb', x.id))}"><td style="padding:10px 12px;border-radius:12px 0 0 12px"><span style="display:flex;align-items:center;gap:10px"><span class="ico ${KIND[x.kind].c}" style="width:30px;height:30px;border-radius:9px;display:inline-flex;align-items:center;justify-content:center">${ic(KIND[x.kind].i, 15)}</span><b>${esc(x.t)}</b></span></td><td class="tnum" style="text-align:right;padding:10px 12px;font-weight:800">${num(x.views)}</td><td class="tnum" style="text-align:right;padding:10px 12px">${num(x.uniq)}</td><td class="tnum" style="text-align:right;padding:10px 12px">${num(x.dl || x.plays)}</td><td class="tnum" style="text-align:right;padding:10px 12px">${x.plays ? x.comp + ' %' : '—'}</td><td class="tnum" style="text-align:right;padding:10px 12px;border-radius:0 12px 12px 0">${x.rating ? String(x.rating).replace('.', ',') + ' ★' : '—'}</td></tr>`).join('')}</tbody></table></div>` : empty('chart', 'tone-n', 'Sin datos todavía', 'Cuando los usuarios abran contenido verás aquí qué les sirve.')}</section>
    <div class="grid g2">
      <section class="card">${chdr('warn', 'tone-w', 'Contenido menos utilizado', 'Promociónalo o revisa si sigue vigente.')}${low.length ? `<div class="rows">${low.map(x => `<div class="row"><span class="ico ${KIND[x.kind].c}">${ic(KIND[x.kind].i, 17)}</span><span style="min-width:0"><strong>${esc(x.t)}</strong><small>${num(x.views)} visualizaciones · ${fD(x.upd)}</small></span><span class="e">${puede('campanas') ? `<a class="btn ghost xs" href="${esc(URL_('cwiz', null, {contenido:x.id}))}">Promocionar</a>` : ''}</span></div>`).join('')}</div>` : '<p class="mut">Sin datos.</p>'}</section>
      <section class="card">${chdr('search', 'tone-d', 'Búsquedas sin resultados', 'Lo que buscan y todavía no existe.')}${a.sinResultados.length ? `<div class="rows">${a.sinResultados.map(x => `<div class="row"><span class="ico tone-n">${ic('search', 16)}</span><span><strong>«${esc(x.abu_texto)}»</strong><small>${num(x.N)} ${x.N === 1 ? 'búsqueda' : 'búsquedas'} en el período</small></span><span class="e">${puede('ayudaAdmin') ? `<a class="btn ghost xs" href="${esc(URL_('kwiz', null, {q:x.abu_texto}))}">Crear contenido</a>` : ''}</span></div>`).join('')}</div>` : '<p class="mut">Ninguna: todo lo que buscan existe.</p>'}</section>
    </div>`;
};

/* ================= Eventos ================= */
document.addEventListener('click', async e => {
  const a = e.target.closest('.sgs button, .sgs a, .sgs [data-scrim], .sgs tr[data-href]');
  if (!a){ if (popEl && !e.target.closest('.pop') && !e.target.closest('[data-sgs-act]')) closePop(); if (!e.target.closest('.fmenu')) closeFmenu(); return; }
  const ds = a.dataset;
  if (popEl && !a.closest('.pop') && !['assign','chstate','moreacts','insertkb'].includes(ds.act)) closePop();
  if (!a.closest('.fmenu') && !ds.filt) closeFmenu();
  if (ds.scrim){ if (e.target === a) closeLayer(); return; }
  if (ds.href){ location.href = ds.href; return; }
  if (a.tagName === 'A' && !ds.act) return;          // los enlaces navegan solos
  if (a.tagName === 'A') e.preventDefault();
  /* Campañas en la página */
  if (ds.campcta){ campAccion(+ds.campcta, 'cta'); return; }
  if (ds.campkb){ campAccion(+ds.campkb, 'kb'); return; }
  if (ds.campok){ campAccion(+ds.campok, 'ok'); return; }
  if (ds.campexp){ const c = CAMP[+ds.campexp]; if (c) campPantallaCompleta(c); return; }
  if (ds.campx){ campAccion(+ds.campx, 'x'); return; }
  if (ds.campver){ const c = CAMP[+ds.campver]; if (c) campModal(c); return; }
  /* Reporte */
  if (ds.rpcat){ RP.cat = ds.rpcat; $$('[data-rpcat]').forEach(b => b.setAttribute('aria-pressed', b === a)); updRpFoot(); return; }
  if (ds.rpprio){ RP.prio = ds.rpprio; $$('[data-rpprio]').forEach(b => b.setAttribute('aria-pressed', b === a)); updRpFoot(); return; }
  if (ds.rmfile && RP.files){ RP.files = RP.files.filter(f => f.n !== ds.rmfile); const b = $('#rpFiles'); b && (b.innerHTML = RP.files.map(fileRow).join('')); return; }
  /* Bandeja */
  if (ds.tftab){ TF.tab = ds.tftab; TF.pag = 1; render(); return; }
  if (ds.tfpag){ TF.pag = +ds.tfpag; render(); scrollTo({top:0}); return; }
  if (ds.filt){ if (fmenu && fmenu.dataset.k === ds.filt) closeFmenu(); else openFmenu(ds.filt, a); return; }
  /* Ticket */
  if (ds.tdf){ TD.flt = ds.tdf; TD.draft = ($('#tdText') || {}).value || TD.draft; render(); return; }
  if (ds.tdm){ TD.draft = ($('#tdText') || {}).value || ''; TD.mode = ds.tdm; render(); setTimeout(() => $('#tdText') && $('#tdText').focus(), 20); return; }
  if (ds.assign){ closePop(); const area = $('#asgArea'); await accion(ws('s', 'Asignar', {ticket:S.t.id, responsable:+ds.assign, area:area ? +area.value : 0}), `${esc(S.t.folio)} asignado`); return; }
  if (ds.setst){ closePop(); if (ds.setst === 'res') resolveModal(); else if (ds.setst === 'cer') confirmModal('¿Cerrar el ticket?', 'El usuario no podrá responder más. Si vuelve a ocurrir, tendrá que reportarlo de nuevo.', 'Cerrar ticket', 'doclose', false); else setState(ds.setst); return; }
  if (ds.more){ closePop(); const m = ds.more;
    if (m === 'tokb'){ go('kwiz', null, {ticket:S.t.id}); return; }
    if (m === 'close'){ confirmModal('¿Cerrar sin resolver?', 'Quedará registrado como cerrado sin solución. Úsalo para duplicados o reportes que no corresponden.', 'Cerrar sin resolver', 'doclosenr', true, `<div class="f"><label for="cnrN">Motivo</label><input class="in" id="cnrN" placeholder="Ej.: Duplicado de SUP-000120" autofocus></div>`); return; }
    if (m === 'copy'){ const u = location.origin + URL_('ticket', S.t.id); try { await navigator.clipboard.writeText(u); toast('Enlace copiado.'); } catch (err){ prompt('Copia el enlace:', u); } return; }
    if (m === 'prio'){ openPop(`<div class="pop-b" style="padding-top:10px">${Object.keys(PR).map(k => `<button type="button" class="hitem" data-setprio="${k}" style="grid-template-columns:minmax(0,1fr)">${prChip(k)}</button>`).join('')}</div>`, $('[data-act="moreacts"]'), 220); return; }
    if (m === 'link'){ let r; try { r = (await ws('s', 'Recurrentes')).recurrentes; } catch (err){ fallo(err); return; }
      openPop(`<div class="pop-h"><span style="flex:1"><b>Vincular a un problema recurrente</b><small>Se agrupa con los demás tickets.</small></span></div><div class="pop-b">${r.length ? r.map(x => `<button type="button" class="hitem" data-vincular="${x.sre_id}" style="grid-template-columns:24px minmax(0,1fr)">${ic('reopen', 18)}<span><b>«${esc(x.sre_titulo)}»</b><small>${esc(x.sre_modulo || '')} · ${num(x.NTOTAL)} tickets</small></span></button>`).join('') : '<p class="mut" style="padding:10px;font-size:12.5px">Aún no hay problemas recurrentes. Se forman solos cuando 5 tickets se parecen.</p>'}</div>`, $('[data-act="moreacts"]'), 340); return; }
    return; }
  if (ds.setprio){ closePop(); await accion(ws('s', 'Prioridad', {ticket:S.t.id, prioridad:ds.setprio}), 'Prioridad actualizada'); return; }
  if (ds.vincular){ closePop(); await accion(ws('s', 'Vincular', {ticket:S.t.id, recurrente:+ds.vincular}), 'Ticket vinculado'); return; }
  if (ds.insertkb){ closePop(); TD.draft = ($('#tdText') || {}).value || ''; TD.kb = +ds.insertkb; TD.kbT = ds.t; TD.mode = 'pub'; if (!TD.draft) TD.draft = `Te dejo «${ds.t}», te va a servir.`; render(); toast('Contenido agregado a la respuesta'); return; }
  /* Encuesta */
  if (ds.fbr){ FB.c = ($('#fbC') || {}).value || FB.c; FB.r = ds.fbr; if (!FB.s) FB.s = ds.fbr === 'si' ? 5 : ds.fbr === 'parcial' ? 3 : 1; setModal(fbHTML()); return; }
  if (ds.fbs){ FB.c = ($('#fbC') || {}).value || FB.c; FB.s = +ds.fbs; setModal(fbHTML()); return; }
  /* Campañas */
  if (ds.cftab){ CF.tab = ds.cftab; render(); return; }
  if (ds.camp){ openCamp(+ds.camp); return; }
  if (ds.campst){ closeLayer(); await accion(ws('c', 'Estado', {id:+ds.id, estado:ds.campst}), ds.campst === 'pausada' ? 'Campaña pausada' : 'Campaña reanudada'); return; }
  if (ds.cwstep){ readCW(); CW.step = +ds.cwstep; render(); scrollTo({top:0}); return; }
  if (ds.cwtipo){ readCW(); CW.d.tipo = ds.cwtipo; render(); return; }
  if (ds.cwmedia){ readCW(); CW.d.media = ds.cwmedia; if (ds.cwmedia === 'icono'){ CW.d.archivo = null; CW.d.img = null; } render(); return; }
  if (ds.cwtheme){ readCW(); CW.d.theme = +ds.cwtheme; CW.d.archivo = null; CW.d.img = null; render(); return; }
  if (ds.cwfmt){ const f = CW.d.fmt; const i = f.indexOf(ds.cwfmt); if (i >= 0){ if (f.length > 1) f.splice(i, 1); } else f.push(ds.cwfmt); CW.pv.fmt = f[0]; readCW(); render(); return; }
  if (ds.cwsw){ readCW(); CW.d[ds.cwsw] = !CW.d[ds.cwsw]; render(); return; }
  if (ds.cwwhen){ readCW(); CW.d.when = ds.cwwhen; render(); return; }
  if (ds.cwfreq){ readCW(); CW.d.freq = ds.cwfreq; render(); return; }
  if (ds.pvf){ CW.pv.fmt = ds.pvf; render(); return; }
  if (ds.cwpres && CW.d){ CW.d.pres = {...presDe(CW.d.pres), [ds.cwpres]:ds.v}; if (ds.cwpres === 'tamano' || ds.cwpres === 'alto') { if (CW.step === 5) CW.pv.fmt = 'modal'; } readCW(); render(); return; }
  if (ds.pvd){ CW.pv.dev = ds.pvd; render(); return; }
  if (ds.join){ CW.d.join = ds.join; CW.n = null; render(); audiencia(); return; }
  if (ds.conddel){ CW.d.conds.splice(+ds.conddel, 1); CW.n = null; render(); audiencia(); return; }
  if (ds.seg){ const s = S.segs.find(x => x.csg_id === +ds.seg); if (s){ CW.d.conds = JSON.parse(s.csg_condiciones); CW.d.join = s.csg_union; CW.n = null; render(); audiencia(); toast(`Segmento «${esc(s.csg_nombre)}» aplicado`); } return; }
  /* Ayuda */
  if (ds.hsug){ HQ.q = ds.hsug; const i = $('#hq'); i && (i.value = ds.hsug); showHres(); return; }
  if (ds.lv){ LF.view = ds.lv; render(); return; }
  if (ds.lk != null){ LF.kind = ds.lk; history.replaceState(null, '', URL_('lib', null, Object.assign(ds.lk ? {tipo:ds.lk} : {}, LF.mod ? {mod:LF.mod} : {}))); render(); return; }
  if (ds.editcat){ catModal(+ds.editcat); return; }
  if (ds.catico){ $$('[data-catico]').forEach(b => b.setAttribute('aria-pressed', b === a)); return; }
  if (ds.seek != null && !a.disabled){ const v = $('#kbVideo'); if (v){ v.currentTime = +ds.seek; v.play(); } return; }
  if (ds.util != null){ try { await ws('a', 'Valorar', {id:APP.id, util:ds.util === '1', estrellas:0}); toast(ds.util === '1' ? '¡Gracias! Nos ayuda a saber qué sirve.' : 'Gracias. Si te quedó una duda, usa «Reportar problema».'); await cargar(false); } catch (err){ fallo(err); } return; }
  if (ds.kbestado){ await accion(ws('a', 'Estado', {id:APP.id, estado:ds.kbestado}), 'Contenido publicado'); return; }
  if (ds.restore){ confirmModal(`¿Restaurar ${esc(ds.v)}?`, 'Se publicará como una versión nueva con el contenido de esa versión. El historial no se borra.', 'Restaurar', 'dorestore', false); RESTORE.id = +ds.restore; RESTORE.v = ds.v; return; }
  if (ds.kbdl){ ws('a', 'Interaccion', {id:APP.id, tipo:'descarga', origen:qs.get('origen') || ''}).catch(() => {}); return; }
  if (ds.kbplay){ ws('a', 'Interaccion', {id:APP.id, tipo:'reproduccion', origen:qs.get('origen') || ''}).catch(() => {}); return; }
  if (ds.kwstep){ readKW(); KW.step = +ds.kwstep; render(); scrollTo({top:0}); if (KW.step === 4) kwAudiencia(); return; }
  if (ds.kwkind){ readKW(); KW.d.kind = ds.kwkind; render(); return; }
  if (ds.kwpath != null){ const l = +ds.kwpath; KW.d.path = KW.d.path.slice(0, l).concat([ds.v]).concat(['','','','']).slice(0, 4); render(); return; }
  if (ds.kwdel){ readKW(); KW.d.steps.splice(+ds.kwdel, 1); render(); return; }
  if (ds.kwrecdel){ readKW(); KW.d.recs.splice(+ds.kwrecdel, 1); render(); return; }
  if (ds.kwaud){ KW.d.aud = ds.kwaud; KW.aud = null; render(); kwAudiencia(); return; }
  if (ds.kwperf){ const p = KW.d.perfiles; const i = p.indexOf(ds.kwperf); i >= 0 ? p.splice(i, 1) : p.push(ds.kwperf); render(); kwAudiencia(); return; }
  if (ds.kwseg){ const s = S.segs.find(x => x.csg_id === +ds.kwseg); KW.d.seg = +ds.kwseg; KW.d.condsSeg = s ? JSON.parse(s.csg_condiciones) : []; KW.d.unionSeg = s ? s.csg_union : 'AND'; render(); kwAudiencia(); return; }
  if (ds.kwpub){ readKW(); KW.d.pub = ds.kwpub; render(); return; }
  if (ds.kwsw){ readKW(); KW.d[ds.kwsw] = !KW.d[ds.kwsw]; render(); return; }
  if (ds.per){ AN.per = +ds.per; cargar(); return; }
  if (ds.akper){ AK.per = +ds.akper; cargar(); return; }
  const act = ds.act; if (!act) return;
  switch (act){
    case 'close': closeLayer(); break;
    case 'closepop': closePop(); break;
    case 'reintentar': cargar(); break;
    case 'report': closePop(); closeLayer(); openReport(); break;
    case 'sugview': { RP.sugSeen = true; RP.sugId = +ds.id; open(URL_('kb', ds.id, {origen:'sugerencia'}), '_blank', 'noopener'); const box = $('#rpSug'); box && (box.innerHTML = sugHTML()); toast('Abrimos la ayuda en otra pestaña. Tu reporte sigue aquí.'); break; }
    case 'sugcontinue': RP.sugDismissed = true; { const box = $('#rpSug'); box && (box.innerHTML = ''); } setTimeout(() => $('#rpD') && $('#rpD').focus(), 20); break;
    case 'sugsolved': ws('s', 'Evitado', {contenido:RP.sugId || (RP.sug[0] || {}).ayc_id || 0, titulo:RP.t, modulo:RP.ctx.mod, pantalla:RP.ctx.pant}).catch(() => {}); closeLayer(); toast('¡Bien! Registramos que la ayuda resolvió tu duda sin crear un ticket.'); break;
    case 'sendreport': ocupado(a, 'Enviando…'); sendReport(); break;
    case 'clearf': TF.f = {}; TF.q = ''; TF.pag = 1; if (TF.tab === 'mis') TF.tab = 'todos'; render(); break;
    case 'assign': case 'chstate': case 'moreacts': if (popEl && popAnchor === a) closePop(); else ticketAct(act, a); break;
    case 'insertkb': { if (popEl && popAnchor === a){ closePop(); break; }
      if (!S.Kpub){ try { S.Kpub = (await ws('a', 'Contenidos')).contenidos.map(KB).filter(k => k.status === 'Publicado'); } catch (err){ fallo(err); break; } }
      const mod = S.t.mod; const L = [...S.Kpub].sort((x, y) => (y.mod === mod) - (x.mod === mod) || y.viewsT - x.viewsT).slice(0, 8);
      openPop(`<div class="pop-h"><span style="flex:1"><b>Insertar ayuda</b><small>El usuario la verá dentro de la respuesta.</small></span></div><div class="pop-b">${L.length ? L.map(k => `<button type="button" class="hitem" data-insertkb="${k.id}" data-t="${esc(k.t)}"><span class="t ${KIND[k.kind].c}">${ic(KIND[k.kind].i, 18)}</span><span><b>${esc(k.t)}</b><small>${KIND[k.kind].l} · ${esc(k.mod)}</small></span></button>`).join('') : '<p class="mut" style="padding:10px;font-size:12.5px">No hay contenido publicado todavía.</p>'}</div>`, a, 360); break; }
    case 'quitarkb': TD.draft = ($('#tdText') || {}).value || ''; TD.kb = null; render(); break;
    case 'sharekb': TD.mode = 'pub'; TD.kb = +ds.id; TD.kbT = ds.t; TD.draft = (($('#tdText') || {}).value || '') || `Te dejo «${ds.t}», te va a servir.`; render(); setTimeout(() => { const ta = $('#tdText'); ta && (ta.scrollIntoView({block:'center'}), ta.focus()); }, 30); break;
    case 'recur': openRecur(+ds.id); break;
    case 'guardacausa': await accion(ws('s', 'GuardarRecurrente', {id:+ds.id, causa:($('#recCausa') || {}).value || ''}), 'Causa guardada', false); break;
    case 'doresolve': { const n = ($('#resN') || {}).value || ''; if (!n.trim()){ $('#resN').focus(); toast('Cuéntale al usuario qué se hizo.', null, true); break; } const kb = $('#resKb') && $('#resKb').checked; closeLayer(); await setState('res', n); if (kb) go('kwiz', null, {ticket:S.t.id}); break; }
    case 'doclose': closeLayer(); await setState('cer'); break;
    case 'doclosenr': { const m = ($('#cnrN') || {}).value || ''; closeLayer(); await setState('cer', 'Cerrado sin resolver' + (m.trim() ? ': ' + m.trim() : '.')); break; }
    case 'asuser': openDrawer(`<div class="drawer-h"><h2>Lo que ve ${esc(S.t.user.n)}<small style="display:block;font-size:12.5px;font-weight:500;color:var(--muted)">Vista del usuario: sin notas internas.</small></h2><button type="button" class="ibtn" data-act="close" aria-label="Cerrar">${ic('x', 20)}</button></div><div class="drawer-b">${vTicketUsuario(true)}</div>`); break;
    case 'feedback': FB.r = ''; FB.s = 0; FB.c = ''; openModal(fbHTML()); break;
    case 'fbsend': { FB.c = ($('#fbC') || {}).value || FB.c; const re = !!ds.reopen; closeLayer(); await accion(ws('s', 'Encuesta', {ticket:S.t.id, respuesta:FB.r, estrellas:FB.s, comentario:FB.c, reabrir:re}), re ? `Reabriste ${esc(S.t.folio)}. Soporte ya fue avisado.` : '¡Gracias! Tu opinión quedó registrada.'); break; }
    case 'send': { const ta = $('#tdText'); const txt = ta.value.trim(); if (!txt){ ta.focus(); return; } const ask = $('#tdAsk') && $('#tdAsk').checked; const modo = TD.mode;
      a.disabled = true; const ok = await accion(ws('s', 'Evento', {ticket:S.t.id, tipo:modo === 'int' ? 'int' : ask ? 'req' : 'com', texto:txt, contenido:modo === 'int' ? 0 : (TD.kb || 0)}), modo === 'int' ? 'Nota interna guardada' : ask ? 'Pedimos la información. El SLA queda en pausa.' : 'Respuesta enviada al usuario');
      if (ok){ TD.draft = ''; TD.kb = null; render(); } else a.disabled = false; break; }
    case 'usend': { const ta = $('#tdText'); const txt = ta.value.trim(); if (!txt){ ta.focus(); return; } a.disabled = true; if (!await accion(ws('s', 'Evento', {ticket:S.t.id, tipo:'com', texto:txt, contenido:0}), 'Enviado. Soporte ya fue avisado.')) a.disabled = false; break; }
    case 'exportar': exportar(); break;
    case 'condadd': { const v = valoresDe('perfil')[0]; CW.d.conds.push({campo:'perfil', op:'=', valor:v ? v.VALOR : ''}); CW.n = null; render(); audiencia(); break; }
    case 'saveseg': { const n = prompt('Nombre del segmento:', ''); if (!n || !n.trim()) break; try { await ws('c', 'GuardarSegmento', {nombre:n.trim(), union:CW.d.join, condiciones:JSON.stringify(CW.d.conds)}); S.segs = (await ws('c', 'Valores')).segmentos; render(); toast('Segmento guardado. Lo verás en «Segmentos guardados».'); } catch (err){ fallo(err); } break; }
    case 'cwquitarimg': readCW(); CW.d.archivo = null; CW.d.img = null; render(); break;
    case 'cwdraft': ocupado(a, 'Guardando…'); guardarCampana('borrador'); break;
    case 'cwpublish': readCW(); confirmModal(CW.d.when === 'now' ? '¿Publicar la campaña?' : '¿Programar la campaña?', `«${esc(CW.d.t)}» llegará a ${CW.n == null ? 'la audiencia elegida' : num(CW.n) + ' usuarios'}.`, CW.d.when === 'now' ? 'Publicar' : 'Programar', 'docwpublish', false); break;
    case 'docwpublish': ocupado(a, CW.d.when === 'now' ? 'Publicando…' : 'Programando…'); $$('#sgs-layer .modal-f .btn').forEach(x => x.disabled = true); guardarCampana('publicar'); break;
    case 'clearlf': LF.q = ''; LF.mod = ''; LF.st = ''; LF.kind = ''; render(); break;
    case 'newcat': catModal(0); break;
    case 'savecat': { const nombre = $('#catN').value.trim(); const ico = ($('[data-catico][aria-pressed="true"]') || {}).dataset; closeLayer();
      await accion(ws('a', 'Categoria', {id:+ds.id, nombre, modulo:$('#catM') ? $('#catM').value : '', icono:ico ? ico.catico : 'folder', tono:''}), 'Categoría guardada'); break; }
    case 'versions': openVersions(); break;
    case 'newver': newVerModal(); break;
    case 'donewver': { const nota = $('#nvN').value.trim(); if (!nota){ $('#nvN').focus(); toast('Cuenta qué cambió.', null, true); break; } const ver = $('#nvV').value.trim(); ocupado(a, NV.file ? 'Subiendo…' : 'Publicando…');
      try { let arc = 0; if (NV.file){ arc = (await ws('a', 'Subir', {nombre:NV.file.name, mime:NV.file.type, base64:await leer64(NV.file), destino:'ayuda'})).id; }
        ocupado(a, 'Publicando…'); const r = await ws('a', 'NuevaVersion', {id:APP.id, version:ver, nota, archivo:arc}); closeLayer(); toast(`Versión ${esc(r.version)} publicada`); await cargar(false); }
      catch (err){ a.disabled = false; a.removeAttribute('aria-busy'); a.textContent = 'Publicar versión'; fallo(err); } break; }
    case 'dorestore': closeLayer(); try { const r = await ws('a', 'Restaurar', {version:RESTORE.id}); toast(`Se restauró ${esc(RESTORE.v)} como ${esc(r.version)}`); await cargar(false); } catch (err){ fallo(err); } break;
    case 'kwaddstep': readKW(); KW.d.steps.push({t:'', m:''}); render(); setTimeout(() => { const ins = $$('[data-kwstepn]'); ins.length && ins[ins.length - 1].focus(); }, 20); break;
    case 'kwaddrec': readKW(); KW.d.recs.push(''); render(); break;
    case 'kwaddsec': { const v = ($('#kwSecN') || {}).value || ''; if (!v.trim()) break; readKW(); KW.d.path[3] = v.trim(); S.secs.push({acv_modulo:KW.d.path[0], acv_submodulo:KW.d.path[1], acv_pantalla:KW.d.path[2], acv_seccion:v.trim()}); render(); break; }
    case 'kwsave': guardarKW(); break;
  }
});
const RESTORE = {id:0, v:''};
document.addEventListener('input', e => {
  const t = e.target; if (!t.closest || !t.closest('.sgs')) return;
  if (t.id === 'tq'){ TF.q = t.value; TF.pag = 1; const pos = t.selectionStart; render(); const n = $('#tq'); n.focus(); n.setSelectionRange(pos, pos); }
  if (t.id === 'lq'){ LF.q = t.value; const pos = t.selectionStart; render(); const n = $('#lq'); n.focus(); n.setSelectionRange(pos, pos); }
  if (t.id === 'hq'){ HQ.q = t.value; showHres(); }
  if (t.dataset.rp){ if (t.dataset.rp === 't' || t.dataset.rp === 'd'){ RP[t.dataset.rp] = t.value; buscarSug(); updRpFoot(); } else if (t.dataset.rp !== 'onBehalf') RP.ctx[t.dataset.rp] = t.value; }
  if (t.dataset.cw === 't' && CW.d){ CW.d.t = t.value; const h = t.parentElement.querySelector('.hint'); h && (h.textContent = `${t.value.length}/70 · Se lee en un vistazo.`); $$('.wz-foot .btn.pri, .steps .step').forEach((b, i) => { if (b.classList.contains('step') && !b.hasAttribute('aria-current')) b.disabled = !t.value.trim(); else if (!b.classList.contains('step')) b.disabled = !t.value.trim(); }); const pv = $('.pv-modal h4'); pv && (pv.textContent = t.value || 'Título de la campaña'); }
  if (t.dataset.cw === 'desc' && CW.d){ CW.d.desc = t.value; const pv = $('.pv-modal .tx p'); pv && (pv.textContent = t.value || 'La descripción aparece aquí.'); }
  if (t.dataset.cwcta === 'l' && CW.d){ CW.d.cta.l = t.value; }
  if (t.dataset.kw === 't' && KW.d){ KW.d.t = t.value; $$('.wz-foot .btn.pri').forEach(b => b.disabled = t.value.trim().length < 3); }
});
document.addEventListener('change', async e => {
  const t = e.target; if (!t.closest || !t.closest('.sgs')) return; const ds = t.dataset; if (ds.cwvideo && CW.d){ readCW(); render(); return; }
  if (ds.rp === 'onBehalf'){ RP.onBehalf = t.value; return; }
  if (ds.rp === 'pantSel'){ const x = (PANTALLAS || []).find(p => String(p.apa_id) === t.value); if (x){ Object.assign(RP.ctx, {mod:x.apa_modulo, sub:x.apa_submodulo, pant:x.apa_pantalla, sec:''}); RP.sug = []; refreshReport(); buscarSug(); } return; }
  if (ds.rpfiles && t.files.length){ addFiles(t.files); t.value = ''; return; }
  if (ds.adjuntar && t.files.length){ const f = t.files[0]; t.value = ''; if (f.size > 25 * 1048576){ toast('El archivo pesa más de 25 MB.', null, true); return; }
    TD.draft = ($('#tdText') || {}).value || TD.draft; toast(`Subiendo «${esc(f.name)}»…`);
    await accion(ws('s', 'Adjuntar', {ticket:+ds.adjuntar, nombre:f.name, mime:f.type, base64:await leer64(f)}), 'Archivo adjuntado'); return; }
  if (t.closest('.fmenu')){ const k = t.closest('.fmenu').dataset.k; TF.f[k] = $$('.fmenu input:checked').map(x => x.value); TF.pag = 1; render(); const na = $(`[data-filt="${k}"]`); na && openFmenu(k, na); return; }
  if (ds.condf != null){ const i = +ds.condf; const v = valoresDe(t.value)[0]; CW.d.conds[i] = {campo:t.value, op:'=', valor:v ? v.VALOR : ''}; CW.n = null; render(); audiencia(); return; }
  if (ds.condo != null){ CW.d.conds[+ds.condo].op = t.value; CW.n = null; render(); audiencia(); return; }
  if (ds.condv != null){ CW.d.conds[+ds.condv].valor = t.value; CW.n = null; render(); audiencia(); return; }
  if (ds.cwcta === 'a'){ readCW(); const dd = destinos()[t.value] || []; CW.d.cta.dest = t.value === 'url' ? 'https://' : dd[0] ? dd[0][0] : ''; CW.d.cta.l = {modulo:'Abrir módulo', pantalla:'Abrir pantalla', documento:'Ver documento', capsula:'Ver cápsula', url:'Abrir enlace', nada:''}[t.value]; render(); return; }
  if (ds.cwcta === 'dest'){ CW.d.cta.dest = t.value; return; }
  if (ds.cwfecha){ const iso = txtAIso(t.value); if (!iso){ if (t.value.trim()) toast('Escribe la fecha como dd-mm-aaaa.', null, true); return; } readCW(); CW.d[ds.cwfecha] = iso; render(); return; }
  if (ds.cw && (t.tagName === 'SELECT' || ['from','fromT','to','every'].includes(ds.cw))){ readCW(); render(); return; }
  if (ds.cwupload && t.files.length){ const f = t.files[0]; t.value = ''; if (f.size > 60 * 1048576){ toast('El archivo pesa más de 60 MB.', null, true); return; } readCW(); CW.subiendo = true; render();
    try { const r = await ws('a', 'Subir', {nombre:f.name, mime:f.type, base64:await leer64(f), destino:'campanas'}); CW.d.archivo = r.id; CW.d.img = r.url; CW.subiendo = false; render(); toast(/^video\//.test(f.type) ? 'Video cargado para la campaña.' : 'Imagen cargada para la campaña.'); } catch (err){ CW.subiendo = false; render(); fallo(err); } return; }
  if (ds.kwfiles && t.files.length){ const f = t.files[0]; t.value = ''; subirKW(f); return; }
  if (ds.nvfile && t.files.length){ NV.file = t.files[0]; const b = $('#nvF'); b && (b.textContent = 'Nuevo archivo: ' + NV.file.name); return; }
  if (ds.lf){ LF[ds.lf] = t.value; render(); return; }
});
['dragover','dragleave','drop'].forEach(ev => document.addEventListener(ev, e => {
  const z = e.target.closest && e.target.closest('.sgs [data-drop]'); if (!z || !e.dataTransfer || (ev !== 'dragleave' && ![...(e.dataTransfer.types || [])].includes('Files'))) return;
  e.preventDefault(); z.classList.toggle('is-over', ev === 'dragover');
  if (ev === 'drop'){ const which = z.dataset.drop; const fs = e.dataTransfer.files; if (which === 'rp') addFiles(fs); if (which === 'kw' && fs[0]) subirKW(fs[0]); if (which === 'ver' && fs[0]){ NV.file = fs[0]; const b = $('#nvF'); b && (b.textContent = 'Nuevo archivo: ' + fs[0].name); } }
}));
/* Reordenar pasos arrastrando */
let dragI = null;
document.addEventListener('dragstart', e => { const r = e.target.closest && e.target.closest('[data-kwdrag]'); if (r){ dragI = +r.dataset.kwdrag; e.dataTransfer.effectAllowed = 'move'; try { e.dataTransfer.setData('text/plain', String(dragI)); } catch (err){} r.style.opacity = '.5'; } });
document.addEventListener('dragend', e => { const r = e.target.closest && e.target.closest('[data-kwdrag]'); if (r) r.style.opacity = ''; });
document.addEventListener('dragover', e => { const r = e.target.closest && e.target.closest('[data-kwdrag]'); if (r && dragI != null) e.preventDefault(); });
document.addEventListener('drop', e => { const r = e.target.closest && e.target.closest('[data-kwdrag]'); if (r && dragI != null){ e.preventDefault(); readKW(); const to = +r.dataset.kwdrag; const [m] = KW.d.steps.splice(dragI, 1); KW.d.steps.splice(to, 0, m); dragI = null; render(); toast('Pasos reordenados'); } });
document.addEventListener('keydown', e => {
  if (e.key !== 'Escape') return;
  if (fmenu){ closeFmenu(); return; } if (popEl){ closePop(); return; } if (CAPA && layer().innerHTML){ closeLayer(); return; }
  const h = $('#hres'); if (h && !h.hidden) h.hidden = true;
});

/* ================= Inicio ================= */
function barraInferior(){
  const gestion = puede('gestionar');
  const items = gestion ? [['hub','Inicio','home'],['tickets','Problemas','inbox'], ...(puede('campanas') ? [['campaigns','Campañas','mega']] : []),['help','Ayuda','book'], ...(puede('analitica') ? [['analytics','Analítica','chart']] : [])]
    : [['umine','Mis problemas','flag'],['help','Ayuda','book'],['@report','Reportar','warn'],['@ayuda','Esta pantalla','help']];
  const cur = {ticket:gestion ? 'tickets' : 'umine', cwiz:'campaigns', lib:'help', kb:'help', kwiz:'help', cats:'help', kbstats:'analytics'}[APP.vista] || APP.vista;
  const n = document.createElement('nav'); n.className = 'sgs bnav sgs-bnav'; n.setAttribute('aria-label', 'Navegación de soporte');
  n.innerHTML = items.slice(0, 5).map(([k, l, i]) => k[0] === '@' ? `<button type="button" data-sgs-act="${k.slice(1)}">${ic(i, 20)}${l}</button>` : `<a href="${esc(URL_(k))}"${cur === k ? ' aria-current="page"' : ''}>${ic(i, 20)}${l}</a>`).join('');
  document.body.appendChild(n);
}
function iniciar(){
  const el = document.getElementById('sgs-app');
  if (el){
    APP.el = el; APP.vista = el.dataset.vista; APP.id = +el.dataset.id || +qs.get('id') || null;
    document.body.classList.add('sgs-pagina');
    APP.recargar = () => { if (['tickets','umine','hub'].includes(APP.vista)) cargar(false); };
    if (LOAD[APP.vista]) cargar(); else render();
    barraInferior();
  }
  if (puede('ayuda') || puede('reportar')) cargarCampanas();
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar); else iniciar();
window.sigmaSoporte = {reportar:openReport, ayuda:a => openCtxHelp(a), verCampana:c => { CAMP[c.cam_id] = c; campModal(c); }};
/* Quién está conectado y a quién ya le llegó la campaña recién publicada (se refresca solo). */
async function pintarConectados(){
  const el = $('#cwConect'); if (!el) return;
  try {
    const d = await ws('c', 'Conectados', {id:+el.dataset.camp}); const r = d.resumen || {}, us = d.usuarios || [];
    el.innerHTML = `<div class="sgs-conect-t"><span class="live" aria-hidden="true"></span><b>${num(r.CONECTADOS || 0)} conectados ahora</b><small>de ${num(r.AUDIENCIA || 0)} en la audiencia · ${num(r.VIERON || 0)} ya la vieron</small></div>`
      + (us.length ? `<ul class="sgs-conect-l">${us.map(u => `<li><span class="av">${esc((u.NOMBRE || '?').trim().charAt(0).toUpperCase())}</span><span>${esc(u.NOMBRE)}</span><em class="${u.VIO ? 'ok' : ''}">${u.VIO ? 'La vio' : 'Llegando…'}</em></li>`).join('')}</ul>` : `<p class="mut" style="margin:6px 0 0">Nadie de la audiencia está conectado ahora: la recibirán al entrar.</p>`)
      + `<p class="mut" style="font-size:11.5px;margin:6px 0 0">Cada pantalla abierta consulta sus avisos cada 30 segundos.</p>`;
  } catch (e){ el.innerHTML = ''; }
}
setInterval(() => { if ($('#cwConect') && !document.hidden) pintarConectados(); }, 6000);
new MutationObserver(() => { const el = $('#cwConect'); if (el && !el.dataset.listo){ el.dataset.listo = '1'; pintarConectados(); } }).observe(document.body, {childList:true, subtree:true});

})();
