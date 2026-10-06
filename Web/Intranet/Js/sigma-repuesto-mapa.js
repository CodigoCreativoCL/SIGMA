/* ============================================================================
   Centro de repuestos · Mapa por ubicación v3 (06-10-2026)
   Referencia: docs/rediseno-repuestos/sigma-mapa-ubicaciones-referencia.html

   Plano a la izquierda (cada rack dibujado como rack, un punto por repuesto, sin nombres) y un
   panel a la derecha con la lista LEGIBLE de lo que hay en el rack o la repisa elegida.
   Se dibuja con WsBodegaMapa (el mismo servicio de SIGMA Twin), asi que moverlo aqui es mover
   el stock de verdad:
     - A OTRO rack ......... ReubicarCaja (movimiento «cambio de ubicacion») + planograma.
     - A otra repisa ....... GuardarPosiciones (el nivel del planograma del rack).
   Cada llamada vuelve a validar sesion y permiso en el servidor (permisos.ajuste / permisos.bodegas).
   Todo movimiento muestra «quedó en X · Nivel N» con Deshacer. Crear bodegas, racks y niveles es
   inline (sin modal).
   ========================================================================= */
(function () {
    'use strict';

    var WSURL = (function () {
        var s = document.querySelector('script[src*="sigma-repuesto-mapa.js"]');
        return (s ? s.getAttribute('src').split('/Js/')[0] : '') + '/WebService/WsBodegaMapa.asmx';
    })();
    /* Los nombres de las cosas viven aqui: SIGMA es multicliente y no van sueltos por el codigo. */
    var T = { nivel: 'Nivel', pasillo: 'Pasillo', rack: 'Rack', sinNivel: 'Sin nivel' };

    var M = null, planta = 0, OPT = {}, host = null;
    var BODS = [], RACKS = [], ITEMS = [], posBy = {};
    var forms = { bodega: false, ubic: 0, editar: 0 };
    var U = { bod: 0, q: '', st: 'all', rack: 0, lv: null, ord: false, ordTotal: 0, part: null, mv: null, flash: null, sinu: 0 };
    var cola = Promise.resolve(), cargando = false, dragK = null;

    /* ------------------------------------------------------------ utilidades */
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function norm(s) { return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }
    function num(n) { return n == null ? '—' : Number(n).toLocaleString('es-CL', { maximumFractionDigits: 2 }); }
    function $(s, r) { return (r || document).querySelector(s); }
    function $$(s, r) { return [].slice.call((r || document).querySelectorAll(s)); }
    function cssEsc(s) { return window.CSS && CSS.escape ? CSS.escape(s) : String(s).replace(/"/g, '\\"'); }
    var P = {
        search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
        rack: '<rect x="4" y="3" width="16" height="18" rx="1.5"/><path d="M4 9h16M4 15h16"/>',
        box: '<path d="M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8"/>',
        x: '<path d="M6 6l12 12M18 6L6 18"/>',
        arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
        check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
        alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.5"/>',
        qr: '<path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 14h2v6h-4M14 18h2"/>',
        plant: '<path d="M3 21V9l6-4v4l6-4v4l6-4v16z"/>',
        layers: '<path d="M12 3l9 5-9 5-9-5 9-5z"/><path d="M3 13l9 5 9-5"/>',
        move: '<path d="M5 9l-3 3 3 3M9 5l3-3 3 3M15 19l-3 3-3-3M19 9l3 3-3 3M2 12h20M12 2v20"/>',
        plus: '<path d="M12 5v14M5 12h14"/>',
        minus: '<path d="M5 12h14"/>',
        pin: '<path d="M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
        twin: '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M12 12l8-4.5M12 12v9M12 12L4 7.5"/>',
        lapiz: '<path d="M4 20h4L19 9l-4-4L4 16z"/>'
    };
    function ic(k, n) { n = n || 18; return '<svg class="mp-ic" style="width:' + n + 'px;height:' + n + 'px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (P[k] || P.box) + '</svg>'; }

    async function ws(metodo, datos) {
        var r = await fetch(WSURL + '/' + metodo, {
            method: 'POST', credentials: 'same-origin',
            headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify(datos || {})
        });
        if (!r.ok) throw new Error('El servidor respondió ' + r.status + '.');
        var d = JSON.parse((await r.json()).d);
        if (d.error) throw new Error(d.detalle || 'No se pudo completar la operación.');
        return d;
    }
    function toast(msg, undo, error) {
        var box = $('.mp-toasts') || (function () { var b = document.createElement('div'); b.className = 'mp-toasts'; b.setAttribute('aria-live', 'polite'); document.body.appendChild(b); return b; })();
        var t = document.createElement('div');
        t.className = 'mp-toast' + (error ? ' es-error' : ''); t.setAttribute('role', 'status');
        t.innerHTML = ic(error ? 'alert' : 'check', 18) + '<span>' + esc(msg) + '</span>' + (undo ? '<button type="button">Deshacer</button>' : '');
        if (undo) t.querySelector('button').onclick = function () { undo(); t.remove(); };
        box.appendChild(t);
        setTimeout(function () { t.remove(); }, error ? 7000 : 6000);
    }
    function puedeMover() { return !!(M && M.permisos && M.permisos.ajuste); }
    function puedeCrear() { return !!(M && M.permisos && M.permisos.bodegas); }
    function mobile() { return matchMedia('(max-width:900px)').matches; }

    /* ------------------------------------------------------------ datos */
    async function cargar(p) {
        if (cargando) return;
        cargando = true;
        try { M = await ws('Cargar', { planta: p || planta || 0 }); planta = M.planta; indexar(); }
        finally { cargando = false; }
    }
    function pasillo(u) {
        var m = /-([A-Z]{1,3})-R?\d+$/i.exec(u.codigo || '') || /pasillo\s+([A-Za-z0-9]+)/i.exec(u.nombre || '');
        return m ? m[1].toUpperCase() : '';
    }
    function indexar() {
        posBy = {};
        (M.posiciones || []).forEach(function (x) { posBy[x.u + '_' + x.rep] = x; });
        BODS = (M.bodegas || []).filter(function (b) { return b.plantaId === planta; });
        RACKS = [];
        BODS.forEach(function (b) {
            (b.ubicaciones || []).slice().sort(function (a, c) { return String(a.codigo).localeCompare(String(c.codigo), 'es', { numeric: true }); }).forEach(function (u) {
                var niv = (M.niveles && M.niveles[u.id]) || 4;
                (M.posiciones || []).forEach(function (x) { if (x.u === u.id && x.n > niv) niv = x.n; });
                RACKS.push({ id: u.id, cod: u.codigo, nombre: u.nombre || u.codigo, b: b.id, pas: pasillo(u), L: Math.min(10, niv), carga: u.carga });
            });
        });
        var ids = {}; BODS.forEach(function (b) { ids[b.id] = 1; });
        ITEMS = (M.saldos || []).filter(function (s) { return ids[s.b] && s.q > 0; }).map(function (s) {
            var p = posBy[s.u + '_' + s.id];
            return { k: s.b + '|' + s.u + '|' + s.id, rep: s.id, c: s.c, n: s.n, fab: s.fab || '', mod: s.mod || '', q: s.q, res: s.res, un: s.un || '', min: s.min, max: s.max, pr: s.pr,
                     b: s.b, u: s.u, lv: p ? p.n : 0, foto: s.foto || '', lot: s.lot, ult: s.ult, ing: s.ing, vence: s.vence, met: s.met, tn: s.tn };
        });
    }
    function rackById(id) { return RACKS.filter(function (r) { return r.id === id; })[0]; }
    function bodById(id) { return BODS.filter(function (b) { return b.id === id; })[0]; }
    function itemsOf(rid) { return ITEMS.filter(function (i) { return i.u === rid; }); }
    function itemBy(k) { return ITEMS.filter(function (i) { return i.k === k; })[0]; }
    function tone(i) { return i.min != null && i.q < i.min ? 'bajo' : (i.max != null && i.max > 0 && i.q > i.max ? 'alto' : 'ok'); }
    function scope() { return ITEMS.filter(function (i) { return !U.bod || i.b === U.bod; }); }
    function active() { return !!(U.q || U.st !== 'all'); }
    function qMatch(i) { return !U.q || norm(i.n + ' ' + i.c + ' ' + i.fab + ' ' + i.mod).indexOf(norm(U.q)) >= 0; }
    function stMatch(i) { return U.st === 'all' || (U.st === 'sin' ? (i.u > 0 && !i.lv) : tone(i) === U.st); }
    function match(i) { return qMatch(i) && stMatch(i); }
    function porAtencion(a, b) { return (tone(a) === 'bajo' ? 0 : 1) - (tone(b) === 'bajo' ? 0 : 1) || a.n.localeCompare(b.n, 'es'); }
    function lvName(n) { return n ? T.nivel + ' ' + n : T.sinNivel; }
    function niveles(r) { return Array.apply(null, Array(r.L)).map(function (_, k) { return r.L - k; }); }
    function hl(s) {
        if (!U.q) return esc(s);
        var i = norm(s).indexOf(norm(U.q));
        return i < 0 ? esc(s) : esc(s.slice(0, i)) + '<mark>' + esc(s.slice(i, i + U.q.length)) + '</mark>' + esc(s.slice(i + U.q.length));
    }

    /* ------------------------------------------------------------ esqueleto (una vez) */
    function armar() {
        if ($('#mpBar', host)) return;
        host.innerHTML = '<div class="mp">'
            + '<div class="mp-bar" id="mpBar"><span class="mp-planta" id="mpPlanta"></span>'
            + '<label class="mp-srch">' + ic('search', 17) + '<input id="mpQ" type="search" placeholder="¿Dónde está…? Código, nombre o fabricante" autocomplete="off" aria-label="Buscar un repuesto en el mapa"><kbd>/</kbd></label>'
            + '<div class="mp-seg" id="mpBods" role="group" aria-label="Bodega"></div>'
            + '<span class="mp-acc" id="mpAcc"></span></div>'
            + '<div class="mp-chips" id="mpChips"></div><div id="mpForms"></div>'
            + '<div class="mp-body"><div class="mp-plan" id="mpPlan"></div><aside class="mp-pn" id="mpPn" aria-label="Detalle"><div class="mp-pn-in" id="mpPnIn"></div></aside></div>'
            + '</div><div id="mpSheet"></div><div id="mpLayer"></div>';
        $('#mpQ', host).addEventListener('input', function (e) {
            U.q = e.target.value.trim();
            if (U.q) { U.rack = 0; U.ord = false; U.sinu = 0; }
            renderChips(); renderPlan(); renderPanel();
        });
    }

    /* ------------------------------------------------------------ barra y chips */
    function renderBar() {
        var pl = (M.plantas || []).filter(function (p) { return p.id === planta; })[0];
        var opcion = (M.plantas || []).length > 1 && !(OPT.planta > 0);
        $('#mpPlanta', host).innerHTML = opcion
            ? ic('plant', 17) + '<select id="mpPlantaSel" aria-label="Planta">' + M.plantas.map(function (p) { return '<option value="' + p.id + '"' + (p.id === planta ? ' selected' : '') + '>' + esc(p.nombre) + '</option>'; }).join('') + '</select>'
            : ic('plant', 17) + esc(pl ? pl.nombre : '');
        $('#mpBods', host).innerHTML = [[0, 'Todas']].concat(BODS.map(function (b) { return [b.id, b.nombre]; })).map(function (x) {
            return '<button type="button" data-bod="' + x[0] + '" aria-pressed="' + (U.bod === x[0]) + '">' + esc(x[1]) + '</button>';
        }).join('');
        $('#mpAcc', host).innerHTML = puedeCrear() ? '<button type="button" class="mp-btn out sm" data-nueva-bod="1">' + ic('plus', 15) + 'Nueva bodega</button>' : '';
    }
    function renderChips() {
        var s = scope(), c = { all: s.length, bajo: s.filter(function (i) { return tone(i) === 'bajo'; }).length, alto: s.filter(function (i) { return tone(i) === 'alto'; }).length, sin: s.filter(function (i) { return i.u > 0 && !i.lv; }).length };
        var chip = function (k, l, dot) { return '<button type="button" class="mp-chip" data-st="' + k + '" aria-pressed="' + (U.st === k) + '">' + (dot ? '<i class="' + dot + '"></i>' : '') + l + '<b class="tn">' + c[k] + '</b></button>'; };
        $('#mpChips', host).innerHTML = chip('all', 'Todos', '') + chip('bajo', 'Bajo el mínimo', 'bajo') + chip('alto', 'Sobre el máximo', 'alto') + chip('sin', 'Sin nivel', 'sin')
            + (puedeMover() ? '<span class="hint">' + ic('move', 15) + 'Arrastra un repuesto a otra repisa para moverlo</span>' : '');
    }

    /* ------------------------------------------------------------ formularios inline (bodega y racks) */
    function formBodega(b) {
        var nueva = !b;
        var pl = (M.plantas || []).map(function (p) { return '<option value="' + p.id + '"' + ((b ? b.plantaId : planta) === p.id ? ' selected' : '') + '>' + esc(p.nombre) + '</option>'; }).join('');
        return '<div class="rm-form rm-form-b" data-formbodega="' + (b ? b.id : 0) + '"><b>' + (nueva ? 'Nueva bodega' : 'Editar ' + esc(b.nombre)) + '</b>'
            + '<label>Nombre *<input type="text" data-f="nombre" maxlength="400" value="' + esc(b ? b.nombre : '') + '" placeholder="Ej.: Bodega central"></label>'
            + '<label>Planta *<select data-f="planta">' + pl + '</select></label>'
            + '<label>Descripción<input type="text" data-f="descripcion" maxlength="400" value="' + esc(b ? b.descripcion : '') + '" placeholder="Para qué se usa"></label>'
            + '<label>Método de salida<select data-f="metodo">' + [['', 'Según la configuración'], ['FEFO', 'FEFO · vence primero'], ['FIFO', 'FIFO · entró primero'], ['LIFO', 'LIFO · entró último']]
                .map(function (o) { return '<option value="' + o[0] + '"' + ((b ? b.metodo : '') === o[0] ? ' selected' : '') + '>' + o[1] + '</option>'; }).join('') + '</select></label>'
            + '<span class="rm-form-acc"><button type="button" class="rm-bt es-ghost" data-cancelar="1">Cancelar</button><button type="button" class="rm-bt es-pri" data-guardarbodega="' + (b ? b.id : 0) + '">' + (nueva ? 'Crear bodega' : 'Guardar cambios') + '</button></span></div>';
    }
    function formUbic(b) {
        var pas = {}; RACKS.filter(function (r) { return r.b === b.id && r.pas; }).forEach(function (r) { pas[r.pas] = 1; });
        var lista = Object.keys(pas).sort(), sug = lista.length ? lista[lista.length - 1] : 'A';
        return '<div class="rm-form" data-formubic="' + b.id + '"><b>Nuevos racks en ' + esc(b.nombre) + '</b>'
            + '<label>' + T.pasillo + ' (1 a 3 letras)<input type="text" data-f="pasillo" maxlength="3" value="' + esc(sug) + '" autocapitalize="characters"' + (lista.length ? ' list="mpPasillos"' : '') + '>'
            + (lista.length ? '<datalist id="mpPasillos">' + lista.map(function (x) { return '<option value="' + x + '">'; }).join('') + '</datalist>' : '') + '</label>'
            + '<label>Cuántos<input type="number" data-f="cantidad" min="1" max="30" value="1"></label>'
            + '<label>Niveles<input type="number" data-f="niveles" min="1" max="10" value="4"></label>'
            + '<label class="rm-form-ancho">Nombre <small>(opcional, si es uno solo)</small><input type="text" data-f="nombre" maxlength="100" placeholder="Se arma solo: Pasillo A · Rack 01"></label>'
            + '<p class="rm-prev" data-prev="1">Escribe el pasillo para ver el código.</p>'
            + '<span class="rm-form-acc"><button type="button" class="rm-bt es-ghost" data-cancelar="1">Cancelar</button><button type="button" class="rm-bt es-pri" data-guardarubic="' + b.id + '">Crear</button></span></div>';
    }
    function renderForms() {
        var h = '';
        if (forms.bodega) h = formBodega(null);
        else if (forms.editar) { var be = bodById(forms.editar); if (be) h = formBodega(be); }
        else if (forms.ubic) { var bu = bodById(forms.ubic); if (bu) h = formUbic(bu); }
        $('#mpForms', host).innerHTML = h;
    }
    var tPrev = null;
    function prevRack(bId) {
        clearTimeout(tPrev);
        tPrev = setTimeout(async function () {
            var f = $('[data-formubic="' + bId + '"]', host); if (!f) return;
            var pas = (($('[data-f="pasillo"]', f) || {}).value || '').trim().toUpperCase(), cant = Math.max(1, +($('[data-f="cantidad"]', f) || {}).value || 1), el = $('[data-prev]', f);
            if (!el) return;
            if (!/^[A-Z]{1,3}$/.test(pas)) { el.textContent = 'El pasillo son de 1 a 3 letras (A, B, AB).'; return; }
            try {
                var d = await ws('SiguienteRack', { bodega: bId, pasillo: pas });
                el.innerHTML = cant === 1 ? 'Se creará <b>' + esc(d.codigo) + '</b> · ' + esc(d.nombre) : 'Se crearán <b>' + cant + ' racks</b> desde <b>' + esc(d.codigo) + '</b> en adelante.';
            } catch (e) { el.textContent = e.message; }
        }, 250);
    }

    /* ------------------------------------------------------------ plano */
    function puntos(arr) {
        var act = active(), MAX = 18;
        return arr.slice().sort(porAtencion).slice(0, MAX).map(function (i) { return '<i class="' + (act ? (match(i) ? 'hit' : 'off') : tone(i)) + '"></i>'; }).join('')
            + (arr.length > MAX ? '<em>+' + (arr.length - MAX) + '</em>' : '');
    }
    function rackCard(r) {
        var its = itemsOf(r.id), act = active(), hits = its.filter(match).length, bajos = its.filter(function (i) { return tone(i) === 'bajo'; }).length, sh = '';
        for (var n = r.L; n >= 1; n--) {
            var arr = its.filter(function (i) { return i.lv === n; });
            sh += '<button type="button" class="mp-sh' + (U.rack === r.id && U.lv === n ? ' on' : '') + '" data-open="' + r.id + '" data-lv="' + n + '" title="' + esc(r.cod) + ' · ' + lvName(n) + ': ' + arr.length + ' repuestos">'
                + '<span class="mp-sh-l">N' + n + '</span><span class="mp-sh-d">' + (arr.length ? puntos(arr) : '<span class="vac">vacío</span>') + '</span><b class="tn">' + (arr.length || '') + '</b></button>';
        }
        var sin = its.filter(function (i) { return !i.lv; });
        return '<div class="mp-rk' + (U.rack === r.id ? ' on' : '') + (act && !hits ? ' dim' : '') + (its.length ? '' : ' empty') + '">'
            + '<button type="button" class="mp-rk-h" data-open="' + r.id + '">' + ic('rack', 15) + '<b>' + esc(r.cod) + '</b>'
            + (act && hits ? '<span class="hit tn">' + hits + '</span>' : (!act && bajos ? '<span class="al tn" title="' + bajos + ' bajo el mínimo">' + bajos + '</span>' : ''))
            + '<span class="n tn">' + its.length + '</span></button>'
            + '<div class="mp-frame">' + sh + '</div>'
            + (sin.length ? '<button type="button" class="mp-sin" data-open="' + r.id + '" data-lv="0" data-ord="1">' + num(sin.length) + ' sin nivel<span class="mp-sh-d">' + puntos(sin.slice().sort(porAtencion).slice(0, 10)) + '</span></button>' : '')
            + '</div>';
    }
    function renderPlan() {
        var bs = BODS.filter(function (b) { return !U.bod || b.id === U.bod; });
        $('#mpPlan', host).innerHTML = bs.length ? bs.map(function (b) {
            var its = ITEMS.filter(function (i) { return i.b === b.id; }), rs = RACKS.filter(function (r) { return r.b === b.id; });
            var sinU = its.filter(function (i) { return !i.u; });
            var pas = []; rs.forEach(function (r) { if (pas.indexOf(r.pas) < 0) pas.push(r.pas); });
            var nuevo = puedeCrear() ? '<button type="button" class="mp-rk-new" data-nueva-ubic="' + b.id + '">' + ic('plus', 20) + 'Nueva ubicación</button>' : '';
            return '<section class="mp-bod"><div class="mp-bod-h"><h2>' + esc(b.nombre) + '</h2><small>' + esc(b.codigo) + ' · ' + rs.length + ' ubicaciones' + (b.metodo ? ' · ' + esc(b.metodo) : '') + '</small>'
                + (puedeCrear() ? '<button type="button" class="mp-ib" data-editar-bod="' + b.id + '" title="Editar la bodega">' + ic('lapiz', 15) + '</button>' : '')
                + '<div class="st"><span><b class="tn">' + its.length + '</b> repuestos</span><span class="r"><b class="tn">' + its.filter(function (i) { return tone(i) === 'bajo'; }).length + '</b> bajo el mínimo</span>'
                + '<span class="p"><b class="tn">' + its.filter(function (i) { return i.u > 0 && !i.lv; }).length + '</b> sin nivel</span></div></div>'
                + (sinU.length ? '<button type="button" class="mp-sinu" data-sinu="' + b.id + '">' + ic('alert', 15) + '<b>' + sinU.length + '</b> repuestos sin ubicar · asígnalos a un rack</button>' : '')
                + (pas.length ? pas.map(function (p, pi) {
                    return '<div class="mp-psl' + (p ? '' : ' es-sola') + '">' + (p ? '<div class="mp-psl-l">' + T.pasillo + ' ' + esc(p) + '</div>' : '')
                        + '<div class="mp-racks">' + rs.filter(function (r) { return r.pas === p; }).map(rackCard).join('') + (pi === pas.length - 1 ? nuevo : '') + '</div></div>';
                }).join('') : '<div class="mp-psl es-sola"><div class="mp-racks">' + (nuevo || '<p class="mp-nada">Esta bodega aún no tiene ubicaciones.</p>') + '</div></div>')
                + '</section>';
        }).join('') : '<div class="rm-vacio">' + ic('rack', 34) + '<b>No hay bodegas en esta planta</b><span>' + (puedeCrear() ? 'Crea la primera con «Nueva bodega».' : 'Pide a un administrador que cree una.') + '</span></div>';
    }

    /* ------------------------------------------------------------ panel */
    function fila(i, o) {
        o = o || {};
        var t = tone(i), r = rackById(i.u), top = Math.max((i.max || 0) * 1.2, i.q, 1), pc = function (v) { return Math.min(100, v / top * 100); };
        var right = o.asg && r
            ? '<span class="mp-asg" role="group" aria-label="Asignar nivel">' + niveles(r).map(function (n) { return '<button type="button" data-asg="' + esc(i.k) + '" data-n="' + n + '" title="' + T.nivel + ' ' + n + '">N' + n + '</button>'; }).join('') + '</span>'
            : '<span class="mp-pr-q"><b class="' + t + ' tn">' + num(i.q) + '<small>' + esc(i.un) + '</small></b><span class="mp-mb" aria-hidden="true"><i class="' + t + '" style="width:' + pc(i.q) + '%"></i>' + (i.min != null ? '<em style="left:' + pc(i.min) + '%"></em>' : '') + '</span>'
              + (t !== 'ok' ? '<span class="' + t + '">' + (t === 'bajo' ? 'mín. ' + num(i.min) : 'máx. ' + num(i.max)) + '</span>' : '') + '</span>';
        return '<div class="mp-pr' + (U.flash === i.k ? ' flash' : '') + '" data-part="' + esc(i.k) + '" tabindex="0"' + (puedeMover() && i.u ? ' draggable="true"' : '') + ' aria-label="' + esc(i.n) + ', ' + num(i.q) + ' ' + esc(i.un) + '">'
            + '<span class="mp-pr-ic">' + (i.foto ? '<img src="' + esc(i.foto) + '" alt="" loading="lazy">' : ic('box', 17)) + '</span>'
            + '<span class="mp-pr-t"><b>' + hl(i.n) + '</b><small><code>' + hl(i.c) + '</code>' + (i.fab ? ' · ' + hl(i.fab) : '') + (o.where && r ? ' · ' + esc(r.cod) + ' · ' + lvName(i.lv) : '') + '</small></span>' + right + '</div>';
    }
    function rackPanel() {
        var r = rackById(U.rack); if (!r) { U.rack = 0; return summaryPanel(); }
        var b = bodById(r.b), its = itemsOf(r.id), sin = its.filter(function (i) { return !i.lv; }).sort(porAtencion), bajo = its.filter(function (i) { return tone(i) === 'bajo'; });
        var flt = active(), vis = function (i) { return !flt || match(i); };
        var h = '<div class="mp-pn-h"><span class="mp-pn-ic">' + ic('rack', 22) + '</span><div><h3>' + esc(r.cod) + '</h3><small>' + esc(b.nombre) + ' · ' + esc(r.nombre) + ' · ' + r.L + ' niveles</small></div><button type="button" class="mp-ib" data-close="1" aria-label="Cerrar">' + ic('x') + '</button></div>'
            + '<div class="mp-kv"><div><b class="tn">' + its.length + '</b>repuestos</div><div class="r"><b class="tn">' + bajo.length + '</b>bajo el mínimo</div><div class="p"><b class="tn">' + sin.length + '</b>sin nivel</div></div>';
        if (!U.ord) h += '<div class="mp-acts">' + (sin.length && puedeCrear() ? '<button type="button" class="mp-btn pri sm" data-ord="1">' + ic('layers', 16) + 'Asignar niveles</button>' : '')
            + '<button type="button" class="mp-btn plain sm" data-etiq-ub="' + r.id + '">' + ic('qr', 16) + 'Etiquetas QR</button>'
            + '<a class="mp-btn plain sm" href="' + esc(OPT.urlTwin || '#') + '" target="_blank" rel="noopener">' + ic('twin', 16) + 'Ver en SIGMA Twin</a>'
            + (puedeCrear() ? '<button type="button" class="mp-btn plain sm" data-addniv="' + r.id + '"' + (r.L >= 10 ? ' disabled' : '') + ' title="Agrega un nivel arriba">' + ic('plus', 15) + 'Nivel</button>'
                + '<button type="button" class="mp-btn plain sm" data-delniv="' + r.id + '"' + (r.L <= 1 || its.some(function (i) { return i.lv === r.L; }) ? ' disabled' : '') + ' title="Quita el nivel de más arriba (solo si está vacío)">' + ic('minus', 15) + 'Nivel</button>' : '') + '</div>';
        h += '<div class="mp-lvnav"><b class="mp-lvn-id">' + esc(r.cod) + '</b>' + niveles(r).map(function (n) { return '<button type="button" data-jump="' + n + '">N' + n + '<b class="tn">' + its.filter(function (i) { return i.lv === n; }).length + '</b></button>'; }).join('')
            + (sin.length ? '<button type="button" class="p" data-jump="0">' + T.sinNivel + '<b class="tn">' + sin.length + '</b></button>' : '') + '<button type="button" class="mp-ib mp-lvn-x" data-close="1" aria-label="Cerrar">' + ic('x', 18) + '</button></div>';
        if (flt) h += '<p class="mp-more">Mostrando ' + its.filter(match).length + ' de ' + its.length + ' por el filtro · <button type="button" data-clear="1">Ver todos</button></p>';
        var sinSec = function () { return '<section class="mp-lv sinlv" id="lv-0"><div class="mp-lv-h"><span class="tag">—</span><h4>' + T.sinNivel + '</h4><small>' + sin.length + ' en el rack, sin repisa</small></div>' + (sin.filter(vis).map(function (i) { return fila(i, { asg: U.ord }); }).join('') || '<div class="mp-lv-e">Nada por asignar.</div>') + '</section>'; };
        if (U.ord) {
            var done = Math.max(0, U.ordTotal - sin.length), pct = U.ordTotal ? done / U.ordTotal * 100 : 100;
            h += '<div class="mp-prog"><div class="mp-prog-t"><span>Asignando niveles · ' + done + ' de ' + U.ordTotal + '</span><button type="button" class="mp-btn xs plain" data-endord="1">Terminar</button></div><div class="mp-prog-b"><i style="width:' + pct + '%"></i></div>'
                + '<small>Elige la repisa donde está cada repuesto (N' + r.L + ' es la de arriba). También puedes usar las teclas 1 a ' + Math.min(r.L, 9) + '.</small></div>';
            h += sin.length ? sinSec() : '<div class="mp-done"><span class="ok">' + ic('check', 22) + '</span><b>Todo ' + esc(r.cod) + ' tiene nivel</b>Ahora el mapa dice exactamente en qué repisa buscar.<button type="button" class="mp-btn ghost sm" data-endord="1">Listo</button></div>';
        } else if (sin.length && puedeCrear()) {
            h += '<div class="mp-call"><p><b>' + sin.length + ' repuestos</b> están en este rack pero no se sabe en qué repisa. Asígnalos y el mapa dirá exactamente dónde buscar.</p><button type="button" class="mp-btn ghost sm" data-ord="1">Asignar</button></div>';
        }
        if (puedeCrear() && puedeMover() && r.L < 10) h += '<div class="mp-newlv" data-drop="' + r.id + '|new">' + ic('plus', 14) + 'Suelta aquí para crear el nivel ' + (r.L + 1) + '</div>';
        niveles(r).forEach(function (n) {
            var arr = its.filter(function (i) { return i.lv === n; }).sort(porAtencion), nb = arr.filter(function (i) { return tone(i) === 'bajo'; }).length, v = arr.filter(vis);
            h += '<section class="mp-lv" id="lv-' + n + '" data-drop="' + r.id + '|' + n + '"><div class="mp-lv-h"><span class="tag">N' + n + '</span><h4>' + T.nivel + ' ' + n + '</h4><small>' + (n === r.L ? 'arriba · ' : n === 1 ? 'piso · ' : '') + arr.length + ' repuestos</small>'
                + (nb ? '<span class="r">' + nb + ' bajo el mínimo</span>' : '') + '</div>'
                + (v.map(function (i) { return fila(i); }).join('') || '<div class="mp-lv-e">' + (arr.length ? 'Ninguno coincide con el filtro.' : 'Repisa vacía · arrastra aquí un repuesto.') + '</div>') + '</section>';
        });
        if (!U.ord && sin.length) h += sinSec();
        return h;
    }
    function sinUbicarPanel() {
        var b = bodById(U.sinu), its = ITEMS.filter(function (i) { return i.b === U.sinu && !i.u; }).sort(porAtencion);
        return '<div class="mp-pn-h"><span class="mp-pn-ic">' + ic('alert', 22) + '</span><div><h3>Sin ubicar</h3><small>' + esc(b ? b.nombre : '') + ' · ' + its.length + ' repuestos con stock sin rack</small></div><button type="button" class="mp-ib" data-close="1" aria-label="Cerrar">' + ic('x') + '</button></div>'
            + '<p class="mp-more">Arrastra cada repuesto a la repisa de un rack del plano, o ábrelo y elige su ubicación.</p>'
            + (its.map(function (i) { return '<div class="mp-pr" data-part="' + esc(i.k) + '" tabindex="0"' + (puedeMover() ? ' draggable="true"' : '') + '><span class="mp-pr-ic">' + ic('box', 17) + '</span><span class="mp-pr-t"><b>' + esc(i.n) + '</b><small><code>' + esc(i.c) + '</code></small></span><span class="mp-pr-q"><b class="tn">' + num(i.q) + '<small>' + esc(i.un) + '</small></b></span></div>'; }).join('')
                || '<div class="mp-done"><span class="ok">' + ic('check', 22) + '</span><b>Todo está ubicado</b></div>');
    }
    function searchPanel() {
        var res = scope().filter(match).sort(function (a, b) { return a.u - b.u || b.lv - a.lv || porAtencion(a, b); });
        var racks = {}; res.forEach(function (i) { racks[i.u] = 1; });
        var nr = Object.keys(racks).length;
        var titulo = U.q ? 'Dónde está «' + esc(U.q) + '»' : (U.st === 'bajo' ? 'Bajo el mínimo' : U.st === 'alto' ? 'Sobre el máximo' : 'Sin nivel');
        var h = '<div class="mp-pn-h"><span class="mp-pn-ic">' + ic('pin', 22) + '</span><div><h3>' + titulo + '</h3><small>' + (res.length ? res.length + (res.length === 1 ? ' repuesto en ' : ' repuestos en ') + nr + (nr === 1 ? ' rack' : ' racks') : 'Sin resultados') + '</small></div><button type="button" class="mp-ib" data-clear="1" aria-label="Limpiar búsqueda">' + ic('x') + '</button></div>';
        if (!res.length) return h + '<div class="mp-done"><span class="ok mute">' + ic('search', 22) + '</span><b>No está en ' + (U.bod ? esc(bodById(U.bod).nombre) : 'esta planta') + '</b>Revisa el código o busca por fabricante.' + (U.bod ? '<button type="button" class="mp-btn ghost sm" data-bod="0">Buscar en todas las bodegas</button>' : '') + '</div>';
        var last = '', shown = 0; h += '<div>';
        res.slice(0, 40).forEach(function (i) {
            var g = i.u + '|' + i.lv, r = rackById(i.u), b = bodById(i.b);
            if (g !== last) { last = g; h += '<button type="button" class="mp-grp-h"' + (r ? ' data-open="' + i.u + '" data-lv="' + i.lv + '" data-flash="' + esc(i.k) + '"' : '') + '>' + ic('pin', 15) + '<span>' + esc(b ? b.nombre : '') + ' › <b>' + esc(r ? r.cod : 'sin ubicar') + '</b> › <b>' + lvName(i.lv) + '</b></span></button>'; }
            h += fila(i); shown++;
        });
        h += '</div>';
        if (res.length > shown) h += '<p class="mp-more">y ' + (res.length - shown) + ' más · afina la búsqueda</p>';
        return h;
    }
    function summaryPanel() {
        var s = scope(), sin = s.filter(function (i) { return i.u > 0 && !i.lv; }), bajo = s.filter(function (i) { return tone(i) === 'bajo'; }).sort(function (a, b) { return a.q / (a.min || 1) - b.q / (b.min || 1); });
        var rs = RACKS.filter(function (r) { return !U.bod || r.b === U.bod; }).map(function (r) { return { r: r, its: itemsOf(r.id) }; }).filter(function (x) { return x.its.some(function (i) { return !i.lv; }); })
            .sort(function (a, b) { return b.its.filter(function (i) { return !i.lv; }).length - a.its.filter(function (i) { return !i.lv; }).length; });
        var pl = (M.plantas || []).filter(function (p) { return p.id === planta; })[0];
        var h = '<div class="mp-pn-h"><span class="mp-pn-ic">' + ic('layers', 22) + '</span><div><h3>' + esc(U.bod ? bodById(U.bod).nombre : (pl ? pl.nombre : 'Planta')) + '</h3><small>Haz clic en una repisa para ver qué hay en ella.</small></div></div>';
        h += '<div class="mp-box"><h4><span class="mp-dot-sin"></span>' + sin.length + ' repuestos sin nivel</h4>';
        h += sin.length ? '<p>Están en un rack, pero no se sabe en qué repisa. Ordénalos rack por rack: un clic por repuesto.</p><div class="mp-rl">' + rs.slice(0, 6).map(function (x) {
            var n = x.its.filter(function (i) { return !i.lv; }).length, pc = Math.round((1 - n / x.its.length) * 100);
            return '<button type="button" data-open="' + x.r.id + '" data-lv="0" data-ord="1">' + ic('rack', 16) + '<span><b>' + esc(x.r.cod) + '</b><small>' + esc(bodById(x.r.b).nombre) + ' · ' + n + ' de ' + x.its.length + ' sin nivel</small></span><span class="bar"><i style="width:' + pc + '%"></i></span><b class="tn">' + pc + '%</b></button>';
        }).join('') + '</div>' + (rs.length > 6 ? '<p class="mp-more">y ' + (rs.length - 6) + ' racks más · filtra por «Sin nivel»</p>' : '') : '<p>Todos los repuestos tienen repisa asignada.</p>';
        h += '</div><div class="mp-box"><h4><span class="mp-dot-bajo"></span>' + bajo.length + ' bajo el mínimo</h4><div class="mp-rl">' + bajo.slice(0, 6).map(function (i) {
            var r = rackById(i.u);
            return '<button type="button" data-part="' + esc(i.k) + '">' + ic('box', 16) + '<span>' + esc(i.n) + '<small>' + esc(r ? r.cod : 'sin ubicar') + ' · ' + lvName(i.lv) + '</small></span><b class="tn" style="color:var(--danger)">' + num(i.q) + '/' + num(i.min) + '</b></button>';
        }).join('') + '</div>' + (bajo.length > 6 ? '<p class="mp-more"><button type="button" data-st="bajo">Ver los ' + bajo.length + ' en el mapa</button></p>' : '') + '</div>';
        return h;
    }
    function renderPanel() {
        var pn = $('#mpPn', host), el = $('#mpPnIn', host), keep = U.rack && el.dataset.rack === String(U.rack) ? el.scrollTop : 0;
        el.innerHTML = U.rack ? rackPanel() : U.sinu ? sinUbicarPanel() : active() ? searchPanel() : summaryPanel();
        el.dataset.rack = U.rack || '';
        el.scrollTop = keep;
        var sheet = !!U.rack && mobile();
        pn.classList.toggle('sheet', sheet);
        $('#mpSheet', host).innerHTML = sheet ? '<div class="mp-scrim s" data-close="1"></div>' : '';
    }

    /* ------------------------------------------------------------ drawer del repuesto */
    function renderDrawer() {
        var L = $('#mpLayer', host);
        if (!U.part) { L.innerHTML = ''; return; }
        var i = itemBy(U.part); if (!i) { U.part = null; L.innerHTML = ''; return; }
        var r = rackById(i.u), b = bodById(i.b), t = tone(i), otros = ITEMS.filter(function (x) { return x.rep === i.rep && x.k !== i.k; });
        var top = Math.max((i.max || 0) * 1.25, i.q, 1), pc = function (v) { return Math.min(100, v / top * 100); };
        var mvR = rackById(U.mv.r) || r, racksB = RACKS.filter(function (x) { return x.b === i.b; });
        var mismo = !mvR || (r && U.mv.r === r.id && U.mv.lv === i.lv);
        L.innerHTML = '<div class="mp-scrim" data-dclose="1"></div><aside class="mp-dr" role="dialog" aria-modal="true" aria-label="' + esc(i.n) + '"><div class="mp-dr-b">'
            + '<div class="mp-dr-h"><span class="ph">' + (i.foto ? '<img src="' + esc(i.foto) + '" alt="">' : ic('box', 26)) + '</span><div style="flex:1;min-width:0"><small><code>' + esc(i.c) + '</code>' + (i.fab ? ' · ' + esc(i.fab) : '') + '</small><h3>' + esc(i.n) + '</h3>'
            + '<span class="mp-pill ' + t + '"><i></i>' + (t === 'bajo' ? 'Bajo el mínimo' : t === 'alto' ? 'Sobre el máximo' : 'En orden') + '</span></div><button type="button" class="mp-ib" data-dclose="1" aria-label="Cerrar">' + ic('x') + '</button></div>'
            + '<div class="mp-sec"><h5>Dónde está</h5><div class="mp-where"><div class="path"><span>' + esc(b ? b.planta + ' › ' + b.nombre : '') + '</span><b>' + esc(r ? r.cod : 'Sin ubicar') + '</b><span>' + esc(r ? r.nombre : 'Elige un rack abajo para ubicarlo') + '</span><span class="big">' + (r ? lvName(i.lv) : '') + '</span></div>'
            + (r ? '<div class="mp-elev" aria-hidden="true">' + niveles(r).map(function (n) { return '<span class="' + (n === i.lv ? 'on' : '') + '">N' + n + '</span>'; }).join('') + '</div>' : '') + '</div></div>'
            + '<div class="mp-sec"><h5>Existencia</h5><div class="mp-qn"><b class="' + t + ' tn">' + num(i.q) + '</b><span>' + esc(i.un) + ' disponibles</span></div><div class="mp-qbar"><i class="' + t + '" style="width:' + pc(i.q) + '%"></i>'
            + (i.min != null ? '<em style="left:' + pc(i.min) + '%" data-l="Mín. ' + num(i.min) + '"></em>' : '') + (i.max ? '<em style="left:' + pc(i.max) + '%" data-l="Máx. ' + num(i.max) + '"></em>' : '') + '</div>'
            + '<div class="mp-dl"><div><span>Reservada</span><b>' + num(i.res) + '</b></div><div><span>Lotes</span><b>' + (i.lot || '—') + '</b></div><div><span>Último movimiento</span><b>' + esc(i.ult || '—') + '</b></div><div><span>Vence</span><b>' + esc(i.vence || '—') + '</b></div></div></div>'
            + (puedeMover() && racksB.length ? '<div class="mp-sec mv"><h5>Mover dentro de ' + esc(b ? b.nombre : '') + '</h5><label>Ubicación<select id="mpMvR">' + racksB.map(function (x) { return '<option value="' + x.id + '"' + (x.id === U.mv.r ? ' selected' : '') + '>' + esc(x.cod) + ' · ' + esc(x.nombre) + '</option>'; }).join('') + '</select></label>'
                + '<label>Nivel</label><div class="mp-seg" role="group" aria-label="Nivel">' + (mvR ? niveles(mvR) : []).map(function (n) { return '<button type="button" data-mvl="' + n + '" aria-pressed="' + (U.mv.lv === n) + '">N' + n + '</button>'; }).join('') + '</div>'
                + '<p>Queda un movimiento «cambio de ubicación». Para llevarlo a otra bodega, registra un traslado.</p></div>' : '')
            + (otros.length ? '<div class="mp-sec"><h5>También está en</h5><div class="mp-rl">' + otros.map(function (o) { var ro = rackById(o.u), bo = bodById(o.b); return '<button type="button" data-part="' + esc(o.k) + '">' + ic('pin', 16) + '<span>' + esc(bo ? bo.nombre : '') + ' › ' + esc(ro ? ro.cod : 'sin ubicar') + '<small>' + lvName(o.lv) + '</small></span><b class="tn">' + num(o.q) + ' ' + esc(o.un) + '</b></button>'; }).join('') + '</div></div>' : '')
            + '</div><div class="mp-dr-f"><button type="button" class="mp-btn plain sm" data-etiq-rep="' + i.rep + '">' + ic('qr', 16) + 'Etiqueta</button>'
            + (puedeMover() ? '<button type="button" class="mp-btn sec sm" data-domove="1"' + (mismo ? ' disabled' : '') + '>' + ic('move', 16) + 'Mover</button>' : '')
            + '<button type="button" class="mp-btn pri sm" data-ficha="' + i.rep + '">Abrir ficha' + ic('arrow', 16) + '</button></div></aside>';
    }

    /* ------------------------------------------------------------ acciones */
    function render() { renderBar(); renderChips(); renderForms(); renderPlan(); renderPanel(); renderDrawer(); }
    function encolar(fn) { cola = cola.then(fn).catch(function (e) { toast(e.message, null, true); return recargar(); }); return cola; }
    async function recargar(msg) {
        try { await cargar(planta); } catch (e) { toast(e.message, null, true); }
        if (U.part && !itemBy(U.part)) U.part = null;
        if (U.rack && !rackById(U.rack)) U.rack = 0;
        render();
        if (msg) toast(msg);
    }
    function listaLocal(uid) {
        return (M.posiciones || []).filter(function (x) { return x.u === uid; }).map(function (x) { return { repuesto: x.rep, nivel: x.n, posicion: x.p, fila: x.f }; });
    }
    /* Pone (o quita) el nivel en la copia local: lo que se ve cambia al instante, el servidor se entera despues. */
    function setNivelLocal(rep, uid, nivel) {
        M.posiciones = (M.posiciones || []).filter(function (x) { return !(x.u === uid && x.rep === rep); });
        if (nivel > 0) {
            var usado = {};
            M.posiciones.forEach(function (x) { if (x.u === uid && x.n === nivel && !x.f) usado[x.p] = 1; });
            var p = 1; while (usado[p] && p < 30) p++;
            M.posiciones.push({ u: uid, rep: rep, n: nivel, p: p, f: 0 });
        }
        posBy = {}; M.posiciones.forEach(function (x) { posBy[x.u + '_' + x.rep] = x; });
    }
    function guardarPlano(uid) { return ws('GuardarPosiciones', { ubicacion: uid, lista: JSON.stringify(listaLocal(uid)) }); }

    function mover(it, rackId, lv) {
        var prev = { u: it.u, lv: it.lv };
        if (prev.u === rackId && prev.lv === lv) return;
        var tr = rackById(rackId); if (!tr) return;
        if (tr.b !== it.b) { toast('Para llevarlo a otra bodega, registra un traslado en Movimientos.', null, true); return; }
        lv = Math.min(lv, tr.L);
        var etq = it.c + ' quedó en ' + tr.cod + (lv ? ' · ' + lvName(lv) : '');
        if (prev.u === rackId) {
            if (!puedeCrear()) { toast('No tienes permiso para cambiar la repisa.', null, true); return; }
            setNivelLocal(it.rep, rackId, lv); it.lv = lv;
            if (U.part === it.k) U.mv = { r: rackId, lv: lv || 1 };
            render();
            encolar(function () { return guardarPlano(rackId); });
        } else {
            if (!puedeMover()) { toast('No tienes permiso para mover existencias.', null, true); return; }
            var antes = prev.u, k0 = it.k;
            /* El stock se mueve en el servidor; lo que se ve cambia ya. */
            M.saldos.forEach(function (s) { if (s.id === it.rep && s.b === it.b && s.u === antes) s.u = rackId; });
            if (antes) setNivelLocal(it.rep, antes, 0);
            setNivelLocal(it.rep, rackId, lv);
            indexar();
            if (U.part === k0) { U.part = it.b + '|' + rackId + '|' + it.rep; U.mv = { r: rackId, lv: lv || 1 }; }
            render();
            encolar(function () { return ws('ReubicarCaja', { datos: JSON.stringify({ repuesto: it.rep, bodega: it.b, origen: antes, destino: rackId }) }); });
            if (puedeCrear()) {
                if (antes) encolar(function () { return guardarPlano(antes); });
                encolar(function () { return guardarPlano(rackId); });
            }
        }
        toast(etq, function () { var cur = ITEMS.filter(function (x) { return x.rep === it.rep && x.b === it.b && x.u === rackId; })[0] || it; mover(cur, prev.u, prev.lv); });
    }
    function abrirRack(id, lv, ord, flash) {
        if (U.rack !== id) $('#mpPnIn', host).scrollTop = 0;
        U.rack = id; U.lv = lv; U.flash = flash || null; U.sinu = 0;
        var sin = itemsOf(id).filter(function (i) { return !i.lv; }).length;
        if (ord && sin) { U.ord = true; U.ordTotal = sin; } else if (!ord) U.ord = false;
        if (!flash && !ord) { U.q = ''; U.st = 'all'; $('#mpQ', host).value = ''; }
        render();
        requestAnimationFrame(function () {
            var el = $('#mpPnIn', host), sec = flash ? $('.mp-pr[data-part="' + cssEsc(flash) + '"]', el) : $('#lv-' + (lv == null ? 'x' : lv), el);
            if (sec) el.scrollTop = Math.max(0, sec.offsetTop - (flash ? 160 : 58));
            if (!mobile()) { var pn = $('#mpPn', host).getBoundingClientRect(); if (pn.top > innerHeight * .6 || pn.bottom < 0) $('#mpPn', host).scrollIntoView({ block: 'start', behavior: 'smooth' }); }
            U.flash = null;
        });
    }
    async function guardarBodega(id) {
        var f = $('[data-formbodega="' + id + '"]', host); if (!f) return;
        var v = function (k) { return ($('[data-f="' + k + '"]', f) || {}).value || ''; };
        var d = { id: id, planta: parseInt(v('planta'), 10), nombre: v('nombre').trim(), descripcion: v('descripcion').trim() };
        if (id) d.codigo = (bodById(id) || {}).codigo;
        if (v('metodo')) d.metodo = v('metodo');
        if (!d.nombre) { toast('Escribe el nombre de la bodega.', null, true); return; }
        try { await ws('GuardarBodega', { datos: JSON.stringify(d) }); forms = { bodega: false, ubic: 0, editar: 0 }; if (d.planta && d.planta !== planta && !(OPT.planta > 0)) planta = d.planta; await recargar(id ? 'Bodega actualizada.' : 'Bodega creada.'); }
        catch (e) { toast(e.message, null, true); }
    }
    async function crearRacks(bId) {
        var f = $('[data-formubic="' + bId + '"]', host); if (!f) return;
        var v = function (k) { return ($('[data-f="' + k + '"]', f) || {}).value || ''; };
        var pas = v('pasillo').trim().toUpperCase();
        if (!/^[A-Z]{1,3}$/.test(pas)) { toast('El pasillo son de 1 a 3 letras (A, B, AB).', null, true); return; }
        try { var d = await ws('CrearRacks', { datos: JSON.stringify({ bodega: bId, pasillo: pas, cantidad: +v('cantidad') || 1, niveles: +v('niveles') || 4, nombre: v('nombre').trim() }) }); forms = { bodega: false, ubic: 0, editar: 0 }; await recargar(d.detalle); }
        catch (e) { toast(e.message, null, true); }
    }
    async function cambiarNiveles(uid, n) {
        try { await ws('GuardarNiveles', { ubicacion: uid, niveles: n }); await recargar(); } catch (e) { toast(e.message, null, true); }
    }
    async function urlEtiqueta(origen, id) {
        try { var d = await ws('UrlEtiquetas', { origen: origen, ids: String(id), bodega: 0, simbolo: '' }); window.open(d.url, 'sigmaEtiquetas', 'width=980,height=760,resizable=yes,scrollbars=yes'); }
        catch (e) { toast(e.message, null, true); }
    }

    /* ------------------------------------------------------------ eventos (una vez) */
    function ligar() {
        if (host.dataset.listo) return;
        host.dataset.listo = '1';
        host.addEventListener('click', function (e) {
            var t = e.target.closest ? e.target.closest('button,[data-part],a') : null; if (!t) return;
            var d = t.dataset;
            if ('nuevaBod' in d) { forms = { bodega: true, ubic: 0, editar: 0 }; renderForms(); return; }
            if ('editarBod' in d) { forms = { bodega: false, ubic: 0, editar: +d.editarBod }; renderForms(); return; }
            if ('nuevaUbic' in d) { forms = { bodega: false, ubic: +d.nuevaUbic, editar: 0 }; renderForms(); prevRack(+d.nuevaUbic); $('#mpForms', host).scrollIntoView({ block: 'nearest', behavior: 'smooth' }); return; }
            if ('cancelar' in d) { forms = { bodega: false, ubic: 0, editar: 0 }; renderForms(); return; }
            if ('guardarbodega' in d) { guardarBodega(+d.guardarbodega); return; }
            if ('guardarubic' in d) { crearRacks(+d.guardarubic); return; }
            if ('addniv' in d) { var ra = rackById(+d.addniv); if (ra) cambiarNiveles(ra.id, ra.L + 1); return; }
            if ('delniv' in d) { var rd = rackById(+d.delniv); if (rd) cambiarNiveles(rd.id, rd.L - 1); return; }
            if ('etiqUb' in d) { urlEtiqueta('UBICACION', d.etiqUb); return; }
            if ('etiqRep' in d) { urlEtiqueta('REPUESTO', d.etiqRep); return; }
            if ('ficha' in d) { if (OPT.abrirFicha) OPT.abrirFicha(d.ficha); return; }
            if ('bod' in d) { U.bod = +d.bod; if (U.rack && U.bod && rackById(U.rack) && rackById(U.rack).b !== U.bod) { U.rack = 0; U.ord = false; } U.sinu = 0; render(); return; }
            if ('st' in d) { U.st = U.st === d.st ? 'all' : d.st; U.rack = 0; U.ord = false; U.sinu = 0; render(); return; }
            if ('asg' in d) {
                var it = itemBy(d.asg), el = t.closest('.mp-pr');
                if (!it) return;
                if (el) el.classList.add('out');
                setTimeout(function () { mover(it, it.u, +d.n); }, 220);
                return;
            }
            if ('dclose' in d) { U.part = null; renderDrawer(); return; }
            if ('mvl' in d) { U.mv.lv = +d.mvl; renderDrawer(); return; }
            if ('domove' in d) { var im = itemBy(U.part); if (im) mover(im, U.mv.r, U.mv.lv); return; }
            if ('part' in d) { var ip = itemBy(d.part); if (!ip) return; U.part = ip.k; U.mv = { r: ip.u || (RACKS.filter(function (x) { return x.b === ip.b; })[0] || {}).id, lv: ip.lv || 1 }; renderDrawer(); return; }
            if ('sinu' in d) { U.sinu = +d.sinu; U.rack = 0; renderPanel(); return; }
            if ('open' in d) { abrirRack(+d.open, d.lv == null ? null : +d.lv, 'ord' in d, d.flash); return; }
            if ('close' in d) { U.rack = 0; U.sinu = 0; U.ord = false; U.lv = null; render(); return; }
            if ('ord' in d) { abrirRack(U.rack, 0, true); return; }
            if ('endord' in d) { U.ord = false; render(); return; }
            if ('jump' in d) { var el2 = $('#mpPnIn', host), s2 = $('#lv-' + d.jump, el2); if (s2) el2.scrollTo({ top: s2.offsetTop - 58, behavior: 'smooth' }); return; }
            if ('clear' in d) { U.q = ''; U.st = 'all'; $('#mpQ', host).value = ''; render(); return; }
        });
        host.addEventListener('input', function (e) {
            var f = e.target.closest && e.target.closest('[data-formubic]');
            if (f && e.target.matches('[data-f="pasillo"],[data-f="cantidad"]')) prevRack(+f.dataset.formubic);
        });
        host.addEventListener('change', function (e) {
            if (e.target.id === 'mpMvR') { var nr = rackById(+e.target.value); U.mv = { r: +e.target.value, lv: Math.min(U.mv.lv, nr ? nr.L : 1) }; renderDrawer(); }
            else if (e.target.id === 'mpPlantaSel') { planta = parseInt(e.target.value, 10); U.bod = 0; U.rack = 0; U.part = null; forms = { bodega: false, ubic: 0, editar: 0 }; recargar(); }
        });
        document.addEventListener('keydown', function (e) {
            if (!host || !host.isConnected || host.offsetParent === null) return;
            var tag = (e.target.tagName || '').toLowerCase();
            if (e.key === '/' && tag !== 'input' && tag !== 'select' && tag !== 'textarea') { e.preventDefault(); $('#mpQ', host).focus(); return; }
            if (e.key === 'Escape') {
                if (U.part) { U.part = null; renderDrawer(); }
                else if (U.rack || U.sinu) { U.rack = 0; U.sinu = 0; U.ord = false; render(); }
                else if (U.q || U.st !== 'all') { U.q = ''; U.st = 'all'; $('#mpQ', host).value = ''; render(); }
                return;
            }
            var pr = e.target.closest && e.target.closest('.mp-pr');
            if (pr && e.key === 'Enter') { pr.click(); return; }
            if (pr && U.ord && /^[1-9]$/.test(e.key)) {
                var it = itemBy(pr.dataset.part), n = +e.key, r = it && rackById(it.u);
                if (it && r && !it.lv && n <= r.L) {
                    var nx = pr.nextElementSibling; mover(it, it.u, n);
                    if (nx && nx.dataset.part) setTimeout(function () { var f = $('.mp-pr[data-part="' + cssEsc(nx.dataset.part) + '"]', host); if (f) f.focus(); }, 30);
                }
            }
        });
        /* arrastrar y soltar: a una repisa del panel o del plano (misma bodega) */
        var dropOf = function (el) { return el && el.closest && el.closest('[data-drop],.mp-sh[data-open]'); };
        host.addEventListener('dragstart', function (e) { var pr = e.target.closest && e.target.closest('.mp-pr'); if (!pr) return; dragK = pr.dataset.part; e.dataTransfer.effectAllowed = 'move'; try { e.dataTransfer.setData('text/plain', dragK); } catch (x) { } pr.classList.add('drag-ghost'); host.classList.add('es-arrastrando'); });
        host.addEventListener('dragend', function () { dragK = null; host.classList.remove('es-arrastrando'); $$('.drop', host).forEach(function (x) { x.classList.remove('drop'); }); $$('.drag-ghost', host).forEach(function (x) { x.classList.remove('drag-ghost'); }); });
        host.addEventListener('dragover', function (e) { if (!dragK) return; var z = dropOf(e.target); if (!z) return; e.preventDefault(); $$('.drop', host).forEach(function (x) { if (x !== z) x.classList.remove('drop'); }); z.classList.add('drop'); });
        host.addEventListener('drop', function (e) {
            if (!dragK) return; var z = dropOf(e.target); if (!z) return; e.preventDefault();
            var rid, n;
            if (z.dataset.drop) { var a = z.dataset.drop.split('|'); rid = +a[0]; n = a[1]; } else { rid = +z.dataset.open; n = z.dataset.lv; }
            var it = itemBy(dragK); dragK = null; host.classList.remove('es-arrastrando');
            if (!it) return;
            if (n === 'new') {
                var r = rackById(rid), nuevo = r.L + 1;
                ws('GuardarNiveles', { ubicacion: rid, niveles: nuevo }).then(function () { M.niveles = M.niveles || {}; M.niveles[rid] = nuevo; indexar(); mover(itemBy(it.k) || it, rid, nuevo); }).catch(function (x) { toast(x.message, null, true); });
                return;
            }
            mover(it, rid, +n);
        });
        var wasMobile = mobile();
        window.addEventListener('resize', function () { if (host && host.isConnected && mobile() !== wasMobile) { wasMobile = mobile(); renderPanel(); } });
    }

    window.RcMapa = {
        /* host: el contenedor; opts: {abrirFicha(id), planta, urlTwin}. La primera vez trae los datos; despues solo redibuja. */
        pintar: async function (el, opts) {
            host = el; OPT = opts || {};
            ligar();
            if (OPT.planta > 0 && OPT.planta !== planta) { planta = OPT.planta; M = null; U.bod = 0; U.rack = 0; U.part = null; }
            if (!M) {
                host.innerHTML = '<div class="rm-cargando"><span></span><span></span><span></span>Cargando el mapa de ubicaciones…</div>';
                try { await cargar(0); } catch (e) { host.innerHTML = '<div class="rm-vacio">' + ic('alert', 30) + '<b>No se pudo cargar el mapa</b><span>' + esc(e.message) + '</span></div>'; return; }
            }
            armar();
            render();
        },
        invalidar: function () { M = null; }
    };
})();
