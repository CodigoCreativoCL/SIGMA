/* =====================================================================
   SIGMA · Lanzador de SIGMA AI y SIGMA Twin (428)
   Botón flotante abajo a la derecha, en todas las páginas del master, solo si el plan comercial
   del cliente incluye SIGMA AI Chat y/o SIGMA Twin y el usuario puede abrir esas vistas
   (window.SIGMA_PLAN, armado por SitioBase.Controller.PlanFuncion.Json()).
   Con uno solo, el menú muestra solo ese. Clic en una tarjeta = ir a su vista.
   ===================================================================== */
(function () {
  var P = window.SIGMA_PLAN; if (!P || (!P.verAi && !P.verTwin)) return;
  var aqui = location.pathname.toLowerCase();
  var ops = [];
  if (P.verAi) ops.push({ k: 'ai', n: 'SIGMA AI Chat', s: 'Pregunta a tu planta: predicciones, riesgos y qué revisar', url: P.urlAi, img: P.img + 'sigma-ai/sigma-ai-symbol-gradient.svg' });
  if (P.verTwin) ops.push({ k: 'twin', n: 'SIGMA Twin', s: 'Gemelo digital 3D de tus bodegas y repuestos', url: P.urlTwin, img: P.img + 'sigma-twin/sigma-twin-symbol-gradient.svg' });

  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  var orb = '<svg class="sgl-orb" viewBox="0 0 64 64" aria-hidden="true">' +
    '<defs><linearGradient id="sglG" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#00E0C2"/><stop offset=".5" stop-color="#6C5CFF"/><stop offset="1" stop-color="#FF4D9D"/></linearGradient>' +
    '<radialGradient id="sglC" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#1B1F3A"/><stop offset="1" stop-color="#070B16"/></radialGradient></defs>' +
    '<circle cx="32" cy="32" r="30" fill="url(#sglC)"/>' +
    '<circle class="sgl-ring" cx="32" cy="32" r="27" fill="none" stroke="url(#sglG)" stroke-width="2.2" stroke-linecap="round" stroke-dasharray="40 130"/>' +
    '<circle class="sgl-ring2" cx="32" cy="32" r="22" fill="none" stroke="rgba(108,92,255,.35)" stroke-width="1" stroke-dasharray="2 5"/>' +
    '<g class="sgl-net" stroke="url(#sglG)" stroke-width="2.4" stroke-linecap="round"><path d="M32 33L22 22M32 33l12-6M32 33l-6 12"/></g>' +
    '<circle class="sgl-n0" cx="32" cy="33" r="4" fill="#fff"/>' +
    '<circle class="sgl-n1" cx="22" cy="22" r="3.2" fill="#fff" stroke="#00E0C2" stroke-width="1.6"/>' +
    '<circle class="sgl-n2" cx="44" cy="27" r="3.2" fill="#fff" stroke="#FF4D9D" stroke-width="1.6"/>' +
    '<circle class="sgl-n3" cx="26" cy="45" r="3.2" fill="#fff" stroke="#6C5CFF" stroke-width="1.6"/></svg>';

  var el = document.createElement('div');
  el.className = 'sgl'; el.id = 'sgLanzador';
  el.innerHTML = '<div class="sgl-menu" id="sglMenu" role="menu" aria-label="SIGMA AI y SIGMA Twin">' +
    '<div class="sgl-h">Inteligencia SIGMA<small>Incluido en tu plan</small></div>' +
    ops.map(function (o, i) {
      var actual = aqui.indexOf(String(o.url).toLowerCase()) >= 0;
      return '<a class="sgl-op sgl-' + o.k + (actual ? ' sgl-act' : '') + '" role="menuitem" href="' + esc(o.url) + '" style="--i:' + i + '"' + (actual ? ' aria-current="page"' : '') + '>' +
        '<span class="sgl-ic"><img src="' + esc(o.img) + '" alt=""></span><span class="sgl-t"><b>' + esc(o.n) + '</b><small>' + esc(actual ? 'Estás aquí' : o.s) + '</small></span>' +
        '<svg class="sgl-go" viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg></a>';
    }).join('') + '</div>' +
    '<button type="button" class="sgl-fab" aria-expanded="false" aria-controls="sglMenu" aria-label="Abrir ' + (ops.length > 1 ? 'SIGMA AI y SIGMA Twin' : esc(ops[0].n)) + '" title="' + (ops.length > 1 ? 'SIGMA AI · SIGMA Twin' : esc(ops[0].n)) + '">' + orb + '<span class="sgl-x" aria-hidden="true"></span></button>';

  function montar() {
    if (document.getElementById('sgLanzador')) return;
    document.body.appendChild(el);
    if (document.querySelector('.fab-help')) el.classList.add('sgl-alto');
    var fab = el.querySelector('.sgl-fab');
    var abrir = function (v) { el.classList.toggle('sgl-on', v); fab.setAttribute('aria-expanded', v); if (v) { var a = el.querySelector('.sgl-op'); if (a) setTimeout(function () { a.focus(); }, 120); } };
    /* SIGMA AI Chat: el chat se abre a la derecha, sobre la pantalla actual, con el mismo diseño que en SIGMA AI. */
    var ch = el.querySelector('.sgl-ai');
    if (ch && aqui.indexOf(String(P.urlAi).toLowerCase()) < 0) ch.addEventListener('click', function (e) { e.preventDefault(); abrir(false); chat(true); });
    window.addEventListener('message', function (e) { if (e.origin === location.origin && e.data === 'sgl-cerrar-chat') chat(false); });
    fab.addEventListener('click', function (e) { e.preventDefault(); e.stopPropagation(); abrir(!el.classList.contains('sgl-on')); });
    document.addEventListener('click', function (e) { if (!el.contains(e.target)) abrir(false); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && el.classList.contains('sgl-on')) { abrir(false); fab.focus(); } });
  }
  var CH = null;
  function chat(v) {
    if (!CH) {
      CH = document.createElement('div'); CH.className = 'sgl-chat'; CH.setAttribute('role', 'dialog'); CH.setAttribute('aria-label', 'SIGMA AI Chat');
      CH.innerHTML = '<div class="sgl-chat-bk"></div><div class="sgl-chat-p"><div class="sgl-chat-h"><img src="' + esc(P.img + 'sigma-ai/sigma-ai-wordmark-dark.svg') + '" alt="SIGMA AI"><span>Chat</span><a href="' + esc(P.urlAi) + '" title="Abrir SIGMA AI completo">Abrir SIGMA AI</a><button type="button" aria-label="Cerrar el chat">×</button></div><div class="sgl-chat-ld"><span></span><b>Conectando con SIGMA AI…</b><button type="button" hidden>Reintentar</button></div><iframe title="SIGMA AI Chat" src="about:blank"></iframe></div>';
      document.body.appendChild(CH);
      CH.querySelector('.sgl-chat-bk').addEventListener('click', function () { chat(false); });
      CH.querySelector('.sgl-chat-h button').addEventListener('click', function () { chat(false); });
      document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && CH.classList.contains('sgl-chat-on')) chat(false); });
    }
    var f = CH.querySelector('iframe'), ld = CH.querySelector('.sgl-chat-ld'), rb = ld.querySelector('button');
    if (!f.dataset.w) {
      f.dataset.w = '1';
      /* Mientras carga se ve «Conectando…»; si la vista no trae el chat, se ofrece reintentar. */
      f.addEventListener('load', function () {
        if (f.getAttribute('src') === 'about:blank') return;
        var d = null; try { d = f.contentDocument; } catch (e) { }
        if (d && d.getElementById('rail')) ld.hidden = true;
        else { ld.querySelector('b').textContent = 'No se pudo abrir el chat.'; rb.hidden = false; }
      });
      rb.addEventListener('click', function () { rb.hidden = true; ld.querySelector('b').textContent = 'Conectando con SIGMA AI…'; f.setAttribute('src', P.urlAi + (P.urlAi.indexOf('?') < 0 ? '?' : '&') + 'solo=chat&r=' + Date.now()); });
    }
    if (v && f.getAttribute('src') === 'about:blank') f.setAttribute('src', P.urlAi + (P.urlAi.indexOf('?') < 0 ? '?' : '&') + 'solo=chat');
    CH.classList.toggle('sgl-chat-on', v); document.documentElement.classList.toggle('sgl-chat-abierto', v);
    if (v) setTimeout(function () { f.focus(); }, 300);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', montar); else montar();
})();
