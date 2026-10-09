/* =====================================================================
   Lugares del menú Mantenimiento (Operación · Avisos · Recursos).
   Cáscara común: el MISMO header del Centro de Planificación (.cp-hero) con el filtro
   de planta, pestañas por hash (#hoy, #ejecuciones, ...) y un cuerpo por pestaña.
   Cada pestaña se registra con MantLugar.tab(clave, { mount(cuerpo), hero(), planta() })
   a medida que las partes b–e del rediseño la construyen; mientras no esté construida
   muestra a dónde llevaba antes (nada queda huérfano).
   Config (window.MantLugarConfig): { lugar, titulo, hoy, ws, plantas:[{id,n}], tabs:
     [{ k, n, parte, hace, enlaces:[{ n, url }] }] }
   Depende de sigma-mant-comun.js (window.MantKit).
   ===================================================================== */
(function () {
  var K = window.MantKit, CFG = K.CFG, esc = K.esc, $ = K.$;
  var REG = {}, cur = null, badges = {}, H = { pv: [], combo: [], fecha: [], key: [] };
  var plantas = CFG.plantas || [];
  var planta = (function () { try { var v = +sessionStorage.getItem('mantPlanta') || 0; return plantas.some(function (p) { return p.id === v; }) ? v : 0; } catch (e) { return 0; } })();

  function hashTab() { var h = String(location.hash || '').replace(/^#/, '').split('&')[0]; return CFG.tabs.some(function (t) { return t.k === h; }) ? h : CFG.tabs[0].k; }
  function pintarTabs() {
    var nav = $('#mlTabs');
    nav.style.display = CFG.tabs.length > 1 ? '' : 'none';
    nav.innerHTML = CFG.tabs.map(function (t) {
      var b = badges[t.k];
      return '<button type="button" role="tab" id="mlTab-' + t.k + '" aria-selected="' + (cur === t.k) + '" tabindex="' + (cur === t.k ? 0 : -1) + '" data-a="mltab" data-t="' + t.k + '">' + esc(t.n) + (b != null ? '<span class="cp-ct">' + b + '</span>' : '') + '</button>';
    }).join('');
  }
  function pintarHero() {
    var acc = $('#mlAcc'), t = REG[cur];
    var pla = plantas.length > 1
      ? '<label class="cp-hsel">Planta' + K.combo('mlPlanta', [{ id: 0, n: 'Todas las plantas' }].concat(plantas), planta, { etiqueta: 'Planta', ph: 'Todas las plantas' }) + '</label>'
      : plantas.length === 1 ? '<span class="cp-hsel">Planta <b>' + esc(plantas[0].n) + '</b></span>' : '';
    acc.innerHTML = pla + (t && t.hero ? t.hero() : '');
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
    K.Panel.close(); K.Pop.close();
    body.innerHTML = '';
    if (REG[k]) REG[k].mount(body); else body.innerHTML = pendiente(t);
    pintarHero();
    if (!noHash) { try { history.replaceState(null, '', '#' + k); } catch (e) { } }
    try { document.title = t.n + ' · ' + CFG.titulo + ' · SIGMA'; } catch (e) { }
  }

  var A = {
    mltab: function (d) { ir(d.t); }
  };
  window.MantLugar = {
    A: A,
    planta: function () { return planta; },
    tab: function (k, def) { REG[k] = typeof def === 'function' ? { mount: def } : def; if (cur === k) ir(k, true); },
    badge: function (k, n) { badges[k] = n; if (cur) pintarTabs(); },
    heroRefresh: pintarHero,
    ir: ir,
    on: function (o) { ['pv', 'combo', 'fecha', 'key'].forEach(function (n) { if (o[n]) H[n].push(o[n]); }); }
  };

  document.addEventListener('DOMContentLoaded', function () {
    K.bind({
      A: A,
      pv: function (k, v, el, tipo) { H.pv.forEach(function (f) { f(k, v, el, tipo); }); },
      fecha: function (el) { H.fecha.forEach(function (f) { f(el); }); },
      combo: function (span, v) {
        if (span.getAttribute('data-cb') === 'mlPlanta') {
          planta = +v || 0; try { sessionStorage.setItem('mantPlanta', String(planta)); } catch (e) { }
          if (REG[cur] && REG[cur].planta) REG[cur].planta();
          return;
        }
        H.combo.forEach(function (f) { f(span, v); });
      },
      key: function (e) {
        if (e.target.getAttribute('role') === 'tab' && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) {
          var ks = CFG.tabs.map(function (t) { return t.k; }), i = ks.indexOf(cur) + (e.key === 'ArrowRight' ? 1 : -1);
          if (i >= 0 && i < ks.length) { e.preventDefault(); ir(ks[i]); var b = $('#mlTab-' + ks[i]); if (b) b.focus(); }
        }
        H.key.forEach(function (f) { f(e); });
      }
    });
    window.addEventListener('hashchange', function () { var k = hashTab(); if (k !== cur) ir(k, true); });
    ir(hashTab(), true);
  });
})();
