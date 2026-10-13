/* ============================================================================
   SIGMA · Sidebar propuesto (06-10-2026)
   El HTML del menu lo arma el servidor desde la tabla de menus (MenusLateral.ascx.cs, BD/378).
   Aqui vive lo que hace el navegador:
     - acordeon de los modulos, recordado por persona;
     - boton «Contraer menu» (body.enlarged), recordado;
     - «Ir a…» (Ctrl K / ⌘ K): pantallas del propio menu (ya filtradas por permisos) + activos, OT y repuestos (WsBuscar);
     - las 3 pantallas o fichas abiertas mas recientes;
     - refresco de los contadores cada minuto (WsInicio.Contadores).
   Lo recordado va en localStorage con la clave de la persona (sg-nav-*-<usuario>).
   ========================================================================= */
(function () {
    'use strict';

    var nav = document.getElementById('sgnav');
    if (!nav) return;
    var U = nav.getAttribute('data-usuario') || '0', WS_BUSCAR = nav.getAttribute('data-buscar'), WS_INICIO = nav.getAttribute('data-inicio');
    var KEY = function (k) { return 'sg-nav-' + k + '-' + U; };
    function ls(k, def) { try { var v = JSON.parse(localStorage.getItem(KEY(k))); return v == null ? def : v; } catch (e) { return def; } }
    function guardar(k, v) { try { localStorage.setItem(KEY(k), JSON.stringify(v)); } catch (e) { } }
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function norm(s) { return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }
    var MAC = /Mac|iPhone|iPad/.test(navigator.platform || '');

    /* ------------------------------------------------------------ acordeon */
    var abiertos = ls('open', null);
    (function () {
        if (!abiertos) return;                                    // sin eleccion guardada: queda lo que dejo el servidor (el modulo de la pagina abierta)
        [].forEach.call(nav.querySelectorAll('.nv-li[data-sg-key]'), function (li) {
            var abre = abiertos.indexOf(li.getAttribute('data-sg-key')) >= 0 || li.classList.contains('has-on');
            li.classList.toggle('open', abre);
            var a = li.querySelector('[data-sg-tog]'); if (a) a.setAttribute('aria-expanded', abre ? 'true' : 'false');
        });
    })();
    (function () {
        var go = ls('gopen', null); if (!go) return;
        [].forEach.call(nav.querySelectorAll('.sg-g'), function (gi) {
            var abre = go.indexOf(gi.getAttribute('data-sg-key')) >= 0 || !!gi.querySelector('.sbl.on');
            gi.classList.toggle('open', abre); var t = gi.querySelector('[data-sg-gtog]'); if (t) t.setAttribute('aria-expanded', abre ? 'true' : 'false');
        });
    })();
    function guardarAbiertos() {
        guardar('open', [].map.call(nav.querySelectorAll('.nv-li.open[data-sg-key]'), function (li) { return li.getAttribute('data-sg-key'); }));
    }
    nav.addEventListener('click', function (e) {
        var t = e.target.closest ? e.target.closest('[data-sg-tog]') : null;
        if (t) {
            e.preventDefault();
            if (document.body.classList.contains('enlarged')) return;     // colapsado: el submenu flota con el mouse y el foco
            var li = t.closest('.nv-li'), abre = !li.classList.contains('open');
            li.classList.toggle('open', abre); t.setAttribute('aria-expanded', abre ? 'true' : 'false');
            guardarAbiertos(); return;
        }
        var g = e.target.closest ? e.target.closest('[data-sg-gtog]') : null;
        if (g) {
            e.preventDefault();
            var gi = g.closest('.sg-g'), ab = !gi.classList.contains('open');
            gi.classList.toggle('open', ab); g.setAttribute('aria-expanded', ab ? 'true' : 'false');
            guardar('gopen', [].map.call(nav.querySelectorAll('.sg-g.open'), function (x) { return x.getAttribute('data-sg-key'); })); return;
        }
        var f = e.target.closest ? e.target.closest('[data-sg-cmdk]') : null;
        if (f) { e.preventDefault(); abrirCk(); }
    });
    /* con el menu colapsado, Enter o Espacio sobre un modulo abre el flotante (ya se abre con el foco) */
    nav.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') { var a = document.activeElement; if (a && a.blur && nav.contains(a) && document.body.classList.contains('enlarged')) a.blur(); }
    });

    /* ------------------------------------------------------------ contraer */
    var col = document.querySelector('[data-sg-collapse]');
    function pintarCol() {
        if (!col) return;
        var c = document.body.classList.contains('enlarged');
        col.setAttribute('aria-label', c ? 'Expandir menú' : 'Contraer menú'); col.title = c ? 'Expandir menú' : 'Contraer menú';
        var s = col.querySelector('span'); if (s) s.textContent = c ? 'Expandir menú' : 'Contraer menú';
    }
    if (col) {
        var guardado = ls('col', null);
        if (guardado === 1 && window.innerWidth >= 992) document.body.classList.add('enlarged');
        else if (guardado === 0 && window.innerWidth >= 992) document.body.classList.remove('enlarged');
        pintarCol();
        col.addEventListener('click', function () {
            document.body.classList.toggle('enlarged'); guardar('col', document.body.classList.contains('enlarged') ? 1 : 0); pintarCol();
        });
        /* el boton de hamburguesa de la barra superior tambien contrae: se recuerda igual */
        document.addEventListener('click', function (e) {
            if (e.target.closest && e.target.closest('.button-menu-mobile')) setTimeout(function () { guardar('col', document.body.classList.contains('enlarged') ? 1 : 0); pintarCol(); }, 60);
        });
    }
    var kb = nav.querySelector('.nv-find kbd'); if (kb) kb.textContent = MAC ? '⌘ K' : 'Ctrl K';

    /* ------------------------------------------------------------ scroll con la rueda
       Adminto corre slimScroll sobre «.slimscroll-menu» (app.min.js). Su manejador de la
       rueda hace preventDefault y, como el CSS deja ese contenedor en overflow:hidden y el
       scroll real vive en «.sgnav», la rueda quedaba cancelada sin mover nada. Cortamos el
       evento en captura antes de que slimScroll lo vea; asi el scroll nativo de .sgnav va. */
    (function () {
        var menu = nav.closest ? nav.closest('.slimscroll-menu') : null;
        if (!menu) return;
        menu.addEventListener('wheel', function (e) {
            if (document.body.classList.contains('enlarged')) return;   // colapsado: no hay scroll vertical del menu
            if (!nav.contains(e.target)) return;
            e.stopPropagation();                                        // que no llegue al manejador de slimScroll
        }, true);
    })();

    /* ------------------------------------------------------------ recientes */
    function actual() {
        var p = location.pathname.toLowerCase();
        if (/default\.aspx$|login\.aspx$|\/$/.test(p)) return null;
        var on = nav.querySelector('.sbl.on, .nv-a.on'), h1 = document.querySelector('.sg-page-head h1');
        var titulo = (h1 && h1.textContent.trim().replace(/\s+/g, ' ')) || (on && on.getAttribute('data-sg-t')) || document.title;
        if (!titulo) return null;
        var mod = nav.querySelector('.nv-li.has-on > .nv-a, .nv-a.on'), ic = (on && on.getAttribute('data-sg-i')) || (mod && mod.getAttribute('data-sg-i')) || 'mdi mdi-file-document-outline';
        return { u: location.pathname + location.search, t: titulo.slice(0, 60), i: ic };
    }
    function recientes() {
        var r = ls('rec', []), a = actual();
        if (a) { r = r.filter(function (x) { return x.u !== a.u; }); r.unshift(a); r = r.slice(0, 3); guardar('rec', r); }
        return r;
    }
    var REC = recientes();
    (function () {
        var box = document.getElementById('sgRec'), tit = document.getElementById('sgRecT'); if (!box) return;
        var lista = REC.filter(function (x) { return x.u !== location.pathname + location.search; });
        if (!lista.length) { box.innerHTML = ''; if (tit) tit.hidden = true; return; }
        if (tit) tit.hidden = false;
        box.innerHTML = lista.map(function (x) { return '<a class="rc" href="' + esc(x.u) + '" title="' + esc(x.t) + '"><i class="nv-ic"><span class="' + esc(x.i) + '"></span></i><span>' + esc(x.t) + '</span></a>'; }).join('');
    })();

    /* ------------------------------------------------------------ Ir a… */
    var ck = null, ckSel = 0, ckLista = [], ckT = null, ckSeq = 0;
    function pantallas() {
        var vistos = {}, out = [];
        [].forEach.call(nav.querySelectorAll('a[data-sg-t][href]'), function (a) {
            var h = a.getAttribute('href'); if (!h || h === '#' || vistos[h]) return; vistos[h] = 1;
            var esMod = !a.classList.contains('sbl');
            out.push({ t: a.getAttribute('data-sg-t'), s: esMod ? 'Pantalla' : (a.getAttribute('data-sg-m') || ''), url: h, i: a.getAttribute('data-sg-i') || 'mdi mdi-file-document-outline', tipo: 'Pantalla' });
        });
        return out;
    }
    function abrirCk() {
        if (ck) { cerrarCk(); return; }
        var scr = document.createElement('div'); scr.className = 'sgck-scrim';
        var box = document.createElement('div'); box.className = 'sgck'; box.setAttribute('role', 'dialog'); box.setAttribute('aria-modal', 'true'); box.setAttribute('aria-label', 'Ir a…');
        box.innerHTML = '<div class="sgck-in"><span class="mdi mdi-magnify" style="font-size:18px"></span><input id="sgckQ" type="text" placeholder="Ir a una pantalla, un activo, una OT o un repuesto…" autocomplete="off" aria-label="Buscar para ir a"><kbd>Esc</kbd></div>'
            + '<div class="sgck-l" id="sgckL" role="listbox"></div><div class="sgck-f"><span><kbd>↑</kbd><kbd>↓</kbd> moverse</span><span><kbd>Enter</kbd> abrir</span><span><kbd>Esc</kbd> cerrar</span></div>';
        document.body.appendChild(scr); document.body.appendChild(box);
        var q = box.querySelector('#sgckQ');
        ck = { scr: scr, box: box, previo: document.activeElement, input: q, list: box.querySelector('#sgckL') };
        scr.addEventListener('click', cerrarCk);
        q.addEventListener('input', function () { ckSel = 0; pintarCk(); busquedaServidor(); });
        box.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') { e.preventDefault(); cerrarCk(); }
            else if (e.key === 'ArrowDown') { e.preventDefault(); mover(1); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); mover(-1); }
            else if (e.key === 'Enter') { e.preventDefault(); if (ckLista[ckSel]) irA(ckLista[ckSel]); }
            else if (e.key === 'Tab') { e.preventDefault(); q.focus(); }
        });
        box.addEventListener('click', function (e) { var it = e.target.closest('[data-ck]'); if (it) irA(ckLista[+it.getAttribute('data-ck')]); });
        box.addEventListener('mousemove', function (e) { var it = e.target.closest('[data-ck]'); if (it && +it.getAttribute('data-ck') !== ckSel) { ckSel = +it.getAttribute('data-ck'); marcar(); } });
        ck.modal = true; pintarCk(); q.focus();
    }
    function cerrarCk() { if (!ck) return; if (ck.scr) ck.scr.remove(); ck.box.remove(); var ck0 = ck, p = ck.previo; ck = null; clearTimeout(ckT); if (ck0.modal && p && p.focus && document.body.contains(p)) { try { p.focus(); } catch (e) { } } }
    var remotos = [];
    function pintarCk() {
        var q = norm(ck.input.value.trim()), todas = pantallas(), grupos = [];
        if (!q) {
            var rec = REC.filter(function (x) { return x.u !== location.pathname + location.search; }).map(function (x) { return { t: x.t, s: 'Reciente', url: x.u, i: x.i, tipo: 'Reciente' }; });
            if (rec.length) grupos.push(['Recientes', rec]);
            grupos.push(['Pantallas', todas.filter(function (x) { return x.s === 'Pantalla'; }).slice(0, 8)]);
        } else {
            var p = todas.filter(function (x) { return norm(x.t + ' ' + x.s).indexOf(q) >= 0; }).slice(0, 6);
            if (p.length) grupos.push(['Pantallas', p]);
            ['Activo', 'Orden de trabajo', 'Repuesto'].forEach(function (tp) {
                var r = remotos.filter(function (x) { return x.tipo === tp; }); if (r.length) grupos.push([tp === 'Activo' ? 'Activos' : tp === 'Repuesto' ? 'Repuestos' : 'Órdenes de trabajo', r]);
            });
        }
        ckLista = []; var h = '';
        grupos.forEach(function (g) {
            if (!g[1].length) return;
            h += '<div class="sgck-g">' + esc(g[0]) + '</div>';
            g[1].forEach(function (x) {
                var i = ckLista.length; ckLista.push(x);
                h += '<button type="button" class="sgck-i" role="option" data-ck="' + i + '"><span class="sgck-ic"><span class="' + esc(x.i || iconoTipo(x.tipo)) + '"></span></span><span style="min-width:0"><b>' + esc(x.t) + '</b><small>' + esc(x.s) + '</small></span><kbd>' + esc(x.tipo === 'Pantalla' ? 'Ir' : x.tipo) + '</kbd></button>';
            });
        });
        if (ckSel >= ckLista.length) ckSel = 0;
        ck.list.innerHTML = h || '<div class="sgck-e">' + (q ? 'Nada coincide con «' + esc(ck.input.value) + '».' : 'Escribe para buscar.') + '</div>';
        marcar();
    }
    function iconoTipo(t) { return t === 'Activo' ? 'mdi mdi-cog-outline' : t === 'Repuesto' ? 'mdi mdi-package-variant-closed' : t === 'Orden de trabajo' ? 'mdi mdi-clipboard-text-outline' : 'mdi mdi-file-document-outline'; }
    function marcar() {
        [].forEach.call(ck.box.querySelectorAll('[data-ck]'), function (b) { var s = +b.getAttribute('data-ck') === ckSel; b.classList.toggle('sel', s); b.setAttribute('aria-selected', s ? 'true' : 'false'); if (s) b.scrollIntoView({ block: 'nearest' }); });
    }
    function mover(d) { if (!ckLista.length) return; ckSel = (ckSel + d + ckLista.length) % ckLista.length; marcar(); }
    function busquedaServidor() {
        clearTimeout(ckT);
        var q = ck.input.value.trim();
        if (q.length < 2) { remotos = []; return; }
        var seq = ++ckSeq;
        ckT = setTimeout(function () {
            fetch(WS_BUSCAR + '/Buscar', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify({ q: q }) })
                .then(function (r) { return r.json(); }).then(function (j) {
                    if (seq !== ckSeq || !ck) return;
                    var d = JSON.parse(j.d); remotos = (d.items || []).map(function (x) { return { t: x.t, s: x.s || x.tipo, url: x.url, tipo: x.tipo, modal: x.modal, i: iconoTipo(x.tipo) }; });
                    pintarCk();
                }).catch(function () { });
        }, 220);
    }
    function irA(x) {
        if (!x) return; var url = x.url; cerrarCk();
        if (x.modal && window.SigmaModal) { SigmaModal.open({ url: url, title: x.t, width: 1000, initialHeight: 680 }); return; }
        location.href = url;
    }
    document.addEventListener('keydown', function (e) {
        if ((e.ctrlKey || e.metaKey) && (e.key === 'k' || e.key === 'K')) { e.preventDefault(); if (ck && !ck.modal) cerrarCk(); if (top && !ck) { top.focus(); } else abrirCk(); }
    });
    /* El «Buscar...» de la barra superior busca en vivo: al escribir aparece debajo lo que coincide. */
    var top = document.getElementById('txtBuscarGlobal');
    function abrirTop() {
        if (ck && ck.modal) return;
        if (ck) { pintarCk(); return; }
        var cont = top.closest('.sg-search') || top.parentNode;
        var box = document.createElement('div'); box.className = 'sgck sgck-top'; box.setAttribute('role', 'listbox'); box.setAttribute('aria-label', 'Resultados de la búsqueda');
        box.innerHTML = '<div class="sgck-l" id="sgckLT"></div><div class="sgck-f"><span><kbd>↑</kbd><kbd>↓</kbd> moverse</span><span><kbd>Enter</kbd> abrir</span><span><kbd>Esc</kbd> cerrar</span></div>';
        cont.appendChild(box);
        ck = { scr: null, box: box, previo: top, input: top, list: box.querySelector('#sgckLT'), modal: false };
        box.addEventListener('mousedown', function (e) { e.preventDefault(); });
        box.addEventListener('click', function (e) { var it = e.target.closest('[data-ck]'); if (it) irA(ckLista[+it.getAttribute('data-ck')]); });
        box.addEventListener('mousemove', function (e) { var it = e.target.closest('[data-ck]'); if (it && +it.getAttribute('data-ck') !== ckSel) { ckSel = +it.getAttribute('data-ck'); marcar(); } });
        ckSel = 0; pintarCk();
    }
    if (top) {
        top.removeAttribute('disabled'); top.removeAttribute('readonly');
        top.setAttribute('placeholder', 'Buscar... (' + (MAC ? '⌘ K' : 'Ctrl K') + ')'); top.setAttribute('autocomplete', 'off');
        top.addEventListener('focus', abrirTop);
        top.addEventListener('input', function () { abrirTop(); if (ck && !ck.modal) { ckSel = 0; pintarCk(); busquedaServidor(); } });
        top.addEventListener('keydown', function (e) {
            if (!ck || ck.modal) return;
            if (e.key === 'Escape') { e.preventDefault(); cerrarCk(); top.blur(); }
            else if (e.key === 'ArrowDown') { e.preventDefault(); mover(1); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); mover(-1); }
            else if (e.key === 'Enter') { e.preventDefault(); if (ckLista[ckSel]) irA(ckLista[ckSel]); }
        });
        document.addEventListener('mousedown', function (e) { if (ck && !ck.modal && !e.target.closest('.sg-search')) cerrarCk(); });
    }

    /* ------------------------------------------------------------ contadores en vivo */
    var TONO = { ot: ['r', ' vencidas'], stock: ['a', ' fuera de umbral'], ai: ['n', ' predicciones nuevas'], soporte: ['g', ' abiertos'] };
    function pintarCont(c) {
        [].forEach.call(nav.querySelectorAll('[data-sg-c]'), function (a) {
            var k = a.getAttribute('data-sg-c'), v = Number(c[k.toUpperCase()] || c[k] || 0), nb = a.querySelector('.nb');
            if (v <= 0) { if (nb) nb.remove(); return; }
            if (!nb) { nb = document.createElement('em'); nb.setAttribute('data-sg-cont', k); var ch = a.querySelector('.chev'); a.insertBefore(nb, ch || null); }
            nb.className = 'nb ' + (TONO[k] ? TONO[k][0] : 'g'); nb.textContent = v > 99 ? '99+' : v; nb.title = v + (TONO[k] ? TONO[k][1] : '');
        });
    }
    function refrescarCont() {
        if (document.hidden || !WS_INICIO) return;
        fetch(WS_INICIO + '/Contadores', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: '{}' })
            .then(function (r) { return r.json(); }).then(function (j) { var d = JSON.parse(j.d); if (d && d.cont) pintarCont(d.cont); }).catch(function () { });
    }
    setInterval(refrescarCont, 60000);
    document.addEventListener('sigma:alertas-actualizadas', refrescarCont);
})();
