/* =====================================================================
   Lugares del menú Mantenimiento (Operación · Avisos · Biblioteca).
   Cáscara común: el MISMO header del Centro de Planificación (.cp-hero),
   pestañas por hash (#hoy, #ejecuciones, ...) y un cuerpo por pestaña.
   Cada pestaña se registra con MantLugar.tab(clave, function (cuerpo, ctx) {})
   a medida que las partes b–e del rediseño la construyen; mientras no esté
   construida, muestra a dónde llevaba antes (nada queda huérfano).
   Config (window.MantLugarConfig): { lugar, titulo, base_, tabs:
     [{ k, n, parte, hace, enlaces:[{ n, url }] }] }
   ===================================================================== */
(function () {
  var CFG = window.MantLugarConfig || { tabs: [] }, REG = {}, cur = null;
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var $ = function (s) { return document.querySelector(s); };

  function hashTab() { var h = String(location.hash || '').replace(/^#/, '').split('&')[0]; return CFG.tabs.some(function (t) { return t.k === h; }) ? h : CFG.tabs[0].k; }
  function pintarTabs() {
    $('#mlTabs').innerHTML = CFG.tabs.map(function (t) {
      return '<button type="button" role="tab" id="mlTab-' + t.k + '" aria-selected="' + (cur === t.k) + '" tabindex="' + (cur === t.k ? 0 : -1) + '" data-t="' + t.k + '">' + esc(t.n) + '</button>';
    }).join('');
  }
  function pendiente(t) {
    var enl = (t.enlaces || []).map(function (e, i) {
      return '<a class="cp-btn ' + (i ? 'cp-out' : 'cp-pri') + '" href="' + esc(e.url) + '">' + esc(e.n) + '</a>';
    }).join('');
    return '<div class="cp-empty cp-big" style="border:0"><b>' + esc(t.n) + ' llega en la parte ' + esc(t.parte) + ' del rediseño</b>' +
      '<span style="max-width:60ch">' + esc(t.hace || '') + '</span>' +
      (enl ? '<span style="display:flex;gap:8px;flex-wrap:wrap;justify-content:center;margin-top:6px">' + enl + '</span>' : '') +
      (enl ? '<small class="cp-muted2">Mientras tanto, la pantalla actual sigue funcionando.</small>' : '') + '</div>';
  }
  function ir(k, noHash) {
    cur = k; pintarTabs();
    var t = CFG.tabs.filter(function (x) { return x.k === k; })[0], body = $('#mlBody');
    body.innerHTML = '';
    if (REG[k]) REG[k](body, { cfg: CFG, esc: esc, tab: t });
    else body.innerHTML = pendiente(t);
    if (!noHash) { try { history.replaceState(null, '', '#' + k); } catch (e) { } }
    try { document.title = t.n + ' · ' + CFG.titulo + ' · SIGMA'; } catch (e) { }
  }
  window.MantLugar = { tab: function (k, fn) { REG[k] = fn; if (cur === k) ir(k, true); }, ir: ir, esc: esc };

  document.addEventListener('DOMContentLoaded', function () {
    $('#mlTabs').addEventListener('click', function (e) { var b = e.target.closest('button[data-t]'); if (b) ir(b.getAttribute('data-t')); });
    $('#mlTabs').addEventListener('keydown', function (e) {
      if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
      var ks = CFG.tabs.map(function (t) { return t.k; }), i = ks.indexOf(cur) + (e.key === 'ArrowRight' ? 1 : -1);
      if (i >= 0 && i < ks.length) { ir(ks[i]); var b = $('#mlTab-' + ks[i]); if (b) b.focus(); }
    });
    window.addEventListener('hashchange', function () { var k = hashTab(); if (k !== cur) ir(k, true); });
    ir(hashTab(), true);
  });
})();
