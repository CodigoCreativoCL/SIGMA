/* ============================================================================
   Ficha del repuesto (Repuesto.aspx) · constructores del asistente (06-10-2026)

   Tres cosas que viven en el navegador hasta el «Guardar»:
     - Fotos        (paso 1): se eligen o se sueltan, con vista previa; la primera es la portada.
     - Compatibilidades (paso 5): a que activo, subactivo o componente le sirve.
     - Stock        (paso 6): existencia inicial y umbrales por bodega, sin tener que guardar antes.
   Lo elegido viaja en dos campos ocultos (hdnCompat y hdnStock, en JSON) y el servidor lo aplica
   despues de guardar el repuesto. Los combos son SigmaCombo (Js/sigma-combo.js): el mismo de todo SIGMA.
   ========================================================================= */
(function () {
    'use strict';

    var L = window.RP_LISTAS || { destinos: [], bodegas: [], tipos: [], marcas: [] };
    var compat = [], stock = [];
    var TAGS = { a: 'Activo', s: 'Subactivo', c: 'Componente' };

    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function norm(s) { return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim(); }
    function $(s, r) { return (r || document).querySelector(s); }
    function hid(suf) { return document.querySelector('[id$="' + suf + '"]'); }
    function cfg() { var e = document.getElementById('rpDatos'); return e ? { nuevo: e.dataset.nuevo === '1', stock: e.dataset.stock === '1', ingreso: e.dataset.ingreso === '1' } : { nuevo: true, stock: false, ingreso: false }; }
    function loteActivo() { var r = hid('rdbLoteSi'); return !!(r && r.checked); }
    function numero(v) { v = String(v == null ? '' : v).trim().replace(',', '.'); if (v === '') return null; var n = Number(v); return isNaN(n) ? NaN : n; }
    function fmt(n) { return n == null ? '—' : Number(n).toLocaleString('es-CL', { maximumFractionDigits: 2 }); }
    function svg(p, n) { return '<svg width="' + (n || 16) + '" height="' + (n || 16) + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>'; }

    /* ---- estado <-> campos ocultos ---- */
    function leer() {
        var c = hid('hdnCompat'), s = hid('hdnStock');
        try { compat = JSON.parse((c && c.value) || '[]'); } catch (e) { compat = []; }
        try { stock = JSON.parse((s && s.value) || '[]'); } catch (e) { stock = []; }
    }
    function guardar() {
        var c = hid('hdnCompat'), s = hid('hdnStock');
        if (c) c.value = JSON.stringify(compat);
        if (s) s.value = JSON.stringify(stock);
    }

    /* ---- los combos ---- */
    function definir() {
        if (!window.SigmaCombo) return;
        SigmaCombo.definir('rp:tipo', { libre: true, fuente: function () { return L.tipos; } });
        SigmaCombo.definir('rp:marca', { libre: true, fuente: function () { return L.marcas.map(function (m) { return m.n; }); } });
        SigmaCombo.definir('rp:modelo', {
            libre: true, fuente: function () {
                var m = $('[data-sgcombo="rp:marca"]'), t = norm(m ? m.value : ''), r = [], vistos = {};
                L.marcas.forEach(function (x) { if (!t || norm(x.n) === t) x.m.forEach(function (n) { if (!vistos[norm(n)]) { vistos[norm(n)] = 1; r.push(n); } }); });
                return r;
            }
        });
        SigmaCombo.definir('rp:dest', { fuente: function () { return L.destinos; } });
        SigmaCombo.definir('rp:bod', { fuente: function () { return L.bodegas.map(function (b) { return { id: b.id, n: b.n, sub: b.planta }; }); } });
        SigmaCombo.definir('rp:ubi', {
            fuente: function () {
                var h = $('input[name="rpbod"]'), b = L.bodegas.filter(function (x) { return String(x.id) === (h ? h.value : ''); })[0];
                return b ? b.ubic.map(function (u) { return { id: u.id, n: u.n }; }) : [];
            }
        });
    }
    function valorCombo(nombre) { var h = $('input[name="' + nombre + '"]'); return h ? h.value : ''; }
    function limpiarCombo(nombre) { var h = $('input[name="' + nombre + '"]'); if (h) { h.value = ''; var i = h.parentNode.querySelector('input[type=text]'); if (i) { i.value = ''; i.classList.remove('is-nuevo'); } } }
    function msg(id, texto) { var e = document.getElementById(id); if (!e) return; e.textContent = texto || ''; e.hidden = !texto; }

    /* ======================= FOTOS ======================= */
    function fotos() {
        var inp = $('[id$="fupFotos"]'), drop = document.getElementById('rpDrop'), pre = document.getElementById('rpPrevias');
        if (!inp || !drop || drop.dataset.listo) return;
        drop.dataset.listo = '1';
        function pintar() {
            pre.innerHTML = '';
            [].slice.call(inp.files || []).forEach(function (f, i) {
                if (!/^image\//.test(f.type)) return;
                var li = document.createElement('span'); li.className = 'rp-prev';
                var im = document.createElement('img'); im.alt = ''; li.appendChild(im);
                var r = new FileReader(); r.onload = function (e) { im.src = e.target.result; }; r.readAsDataURL(f);
                li.insertAdjacentHTML('beforeend', (i === 0 && cfg().nuevo ? '<em>Portada</em>' : '') + '<small>' + esc(f.name) + '</small>');
                pre.appendChild(li);
            });
        }
        inp.addEventListener('change', pintar);
        ['dragenter', 'dragover'].forEach(function (n) { drop.addEventListener(n, function (e) { e.preventDefault(); drop.classList.add('es-sobre'); }); });
        ['dragleave', 'drop'].forEach(function (n) { drop.addEventListener(n, function (e) { e.preventDefault(); drop.classList.remove('es-sobre'); }); });
        drop.addEventListener('drop', function (e) {
            if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length) { try { inp.files = e.dataTransfer.files; pintar(); } catch (x) { } }
        });
    }

    /* ======================= COMPATIBILIDADES ======================= */
    function pintarCompat() {
        var cont = document.getElementById('rpCompLista'); if (!cont) return;
        cont.innerHTML = compat.length ? compat.map(function (c, i) {
            return '<span class="rp-chip es-' + esc(c.k) + '"><b>' + (TAGS[c.k] || 'Parte') + '</b>' + esc(c.n) + (c.obs ? '<small>' + esc(c.obs) + '</small>' : '')
                + '<button type="button" data-rp-qcompat="' + i + '" aria-label="Quitar">' + svg('<path d="M6 6l12 12M18 6L6 18"/>', 14) + '</button></span>';
        }).join('') : '<p class="rp-nada">Todavía no se indica a qué le sirve. Es opcional: se puede completar después.</p>';
        guardar();
    }
    function armarCompat() {
        var w = document.getElementById('rpCompUi'); if (!w || !window.SigmaCombo) return;
        w.innerHTML = '<div class="rp-add"><div class="rp-c1"><span class="rp-lb">Le sirve a</span>'
            + SigmaCombo.html('rpdest', L.destinos, '', { clave: 'rp:dest', id: 'rpDest', ph: 'Busca un activo, subactivo o componente' }) + '</div>'
            + '<div class="rp-c2"><span class="rp-lb">Observación</span><input type="text" id="rpCompObs" maxlength="500" placeholder="Ej.: verificar la medida antes de montar" autocomplete="off"></div>'
            + '<button type="button" class="af-btn es-secundario" data-rp-addcompat="1">' + svg('<path d="M12 5v14M5 12h14"/>', 15) + 'Agregar</button></div>'
            + '<p class="rp-msg" id="rpCompMsg" hidden></p><div class="rp-chips" id="rpCompLista"></div>';
        pintarCompat();
    }
    function agregarCompat() {
        var inp = $('#rpDest'); if (inp && window.SigmaCombo) SigmaCombo.salir(inp);
        var v = valorCombo('rpdest'), d = L.destinos.filter(function (x) { return String(x.id) === v; })[0];
        if (!d) return msg('rpCompMsg', 'Elige de la lista a qué activo, subactivo o componente le sirve.');
        if (compat.some(function (c) { return c.v === d.id; })) return msg('rpCompMsg', '«' + d.n + '» ya está en la lista.');
        compat.push({ v: d.id, n: d.n, k: d.tag ? d.tag.k : 'a', obs: ($('#rpCompObs') || {}).value || '' });
        limpiarCombo('rpdest'); var o = $('#rpCompObs'); if (o) o.value = '';
        msg('rpCompMsg', ''); pintarCompat();
    }

    /* ======================= STOCK ======================= */
    function pintarStock() {
        var cont = document.getElementById('rpStockLista'), c = cfg(); if (!cont) return;
        cont.innerHTML = stock.length ? '<table class="rp-tabla"><thead><tr><th>Bodega</th>' + (c.nuevo ? '<th>Ubicación</th><th class="n">Existencia</th>' : '') + '<th class="n">Mínimo</th><th class="n">Máximo</th><th class="n">Reposición</th><th></th></tr></thead><tbody>'
            + stock.map(function (s, i) {
                return '<tr><td><b>' + esc(s.bn) + '</b>' + (s.lote ? '<small>Lote ' + esc(s.lote) + (s.vence ? ' · vence ' + esc(s.vence) : '') + '</small>' : '') + '</td>'
                    + (c.nuevo ? '<td>' + esc(s.un || '—') + '</td><td class="n">' + (s.cant ? fmt(s.cant) : '—') + '</td>' : '')
                    + '<td class="n">' + fmt(s.min) + '</td><td class="n">' + fmt(s.max) + '</td><td class="n">' + fmt(s.rep) + '</td>'
                    + '<td><button type="button" class="rp-x" data-rp-qstock="' + i + '" aria-label="Quitar">' + svg('<path d="M6 6l12 12M18 6L6 18"/>', 14) + '</button></td></tr>';
            }).join('') + '</tbody></table>' : '';
        guardar();
    }
    function armarStock() {
        var w = document.getElementById('rpStockUi'); if (!w || !window.SigmaCombo) return;
        var c = cfg();
        if (!c.stock && !c.ingreso) { w.innerHTML = '<p class="rp-nada">No tienes permiso para definir stock ni umbrales. Lo hace quien maneja el inventario.</p>'; return; }
        var f = function (id, lb, ph, extra) { return '<label class="rp-f' + (extra || '') + '"><span class="rp-lb">' + lb + '</span><input type="text" id="' + id + '" inputmode="decimal" placeholder="' + ph + '" maxlength="14" autocomplete="off"></label>'; };
        w.innerHTML = '<div class="rp-stock"><div class="rp-stock-g">'
            + '<div class="rp-f"><span class="rp-lb">Bodega *</span>' + SigmaCombo.html('rpbod', [], '', { clave: 'rp:bod', id: 'rpBod', ph: 'Elige la bodega' }) + '</div>'
            + (c.nuevo && c.ingreso ? '<div class="rp-f"><span class="rp-lb">Ubicación</span>' + SigmaCombo.html('rpubi', [], '', { clave: 'rp:ubi', id: 'rpUbi', ph: 'Rack o estante' }) + '</div>'
                + f('rpCant', 'Existencia inicial', 'Cuánto hay hoy') : '')
            + (c.nuevo && c.ingreso ? '<span id="rpLoteW" class="rp-lote" ' + (loteActivo() ? '' : 'hidden') + '><label class="rp-f"><span class="rp-lb">Lote *</span><input type="text" id="rpLote" maxlength="100" placeholder="Código del lote" autocomplete="off"></label>'
                + '<label class="rp-f"><span class="rp-lb">Vence</span><span class="sigma-modal-fecha"><input type="text" id="rpVence" maxlength="10" placeholder="dd-mm-aaaa" autocomplete="off"><a href="javascript:void(0)" title="Elegir fecha" aria-label="Elegir fecha"></a></span></label></span>' : '')
            + (c.stock ? f('rpMin', 'Mínimo', 'Avisa bajo este') + f('rpMax', 'Máximo', 'Hasta cuánto') + f('rpRep', 'Reposición', 'Cuándo pedir') : '')
            + '</div><div class="rp-stock-b"><p class="rp-msg" id="rpStockMsg" hidden></p><button type="button" class="af-btn es-secundario" data-rp-addstock="1">' + svg('<path d="M12 5v14M5 12h14"/>', 15) + 'Agregar a la lista</button></div></div>'
            + '<div id="rpStockLista"></div>';
        pintarStock();
        if (window.SigmaCalendario) SigmaCalendario.conectar(w);
    }
    function agregarStock() {
        var c = cfg();
        var ib = $('#rpBod'); if (ib && window.SigmaCombo) SigmaCombo.salir(ib);
        var b = L.bodegas.filter(function (x) { return String(x.id) === valorCombo('rpbod'); })[0];
        if (!b) return msg('rpStockMsg', 'Elige la bodega de la lista.');
        var iu = $('#rpUbi'); if (iu && window.SigmaCombo) SigmaCombo.salir(iu);
        var uid = valorCombo('rpubi'), u = b.ubic.filter(function (x) { return String(x.id) === uid; })[0];
        var cant = c.nuevo && c.ingreso ? numero(($('#rpCant') || {}).value) : null;
        var mn = c.stock ? numero(($('#rpMin') || {}).value) : null, mx = c.stock ? numero(($('#rpMax') || {}).value) : null, rp = c.stock ? numero(($('#rpRep') || {}).value) : null;
        if ([cant, mn, mx, rp].some(function (n) { return n !== null && (isNaN(n) || n < 0); })) return msg('rpStockMsg', 'Los valores son números mayores o iguales a cero.');
        if (cant === null && mn === null && mx === null && rp === null) return msg('rpStockMsg', 'Escribe la existencia o los umbrales de esta bodega.');
        if (mn === null && (mx !== null || rp !== null)) return msg('rpStockMsg', 'El mínimo es lo que dispara el aviso: escríbelo.');
        if (mn !== null && mx !== null && mx < mn) return msg('rpStockMsg', 'El máximo no puede ser menor que el mínimo.');
        if (rp !== null && ((mn !== null && rp < mn) || (mx !== null && rp > mx))) return msg('rpStockMsg', 'La reposición va entre el mínimo y el máximo.');
        var lote = '', vence = '';
        if (cant > 0) {
            if (b.ubic.length && !u) return msg('rpStockMsg', 'Esta bodega tiene ubicaciones: elige en cuál queda.');
            if (loteActivo()) { lote = (($('#rpLote') || {}).value || '').trim(); vence = (($('#rpVence') || {}).value || '').trim(); if (!lote) return msg('rpStockMsg', 'Este repuesto controla lote: escribe el código del lote.'); }
        }
        stock = stock.filter(function (s) { return s.b !== b.id || (s.u || 0) !== (u ? u.id : 0); });
        stock.push({ b: b.id, bn: b.n, u: u ? u.id : 0, un: u ? u.n : '', cant: cant, lote: lote, vence: vence, min: mn, max: mx, rep: rp });
        ['rpCant', 'rpMin', 'rpMax', 'rpRep', 'rpLote', 'rpVence'].forEach(function (i) { var e = document.getElementById(i); if (e) e.value = ''; });
        limpiarCombo('rpubi');
        msg('rpStockMsg', ''); pintarStock();
    }

    /* ---- arranque: tambien despues de cada postback parcial (el UpdatePanel repinta el paso) ---- */
    function iniciar() {
        definir(); leer(); fotos(); armarCompat(); armarStock();
    }
    function lote() { var w = document.getElementById('rpLoteW'); if (w) w.hidden = !loteActivo(); }

    document.addEventListener('click', function (e) {
        var t = e.target; if (!t.closest) return;
        var c;
        if ((c = t.closest('[data-rp-addcompat]'))) { agregarCompat(); return; }
        if ((c = t.closest('[data-rp-qcompat]'))) { compat.splice(+c.getAttribute('data-rp-qcompat'), 1); pintarCompat(); return; }
        if ((c = t.closest('[data-rp-addstock]'))) { agregarStock(); return; }
        if ((c = t.closest('[data-rp-qstock]'))) { stock.splice(+c.getAttribute('data-rp-qstock'), 1); pintarStock(); return; }
    });
    document.addEventListener('change', function (e) {
        if (e.target.matches && e.target.matches('[id$="rdbLoteSi"],[id$="rdbLoteNo"]')) lote();
        if (e.target.matches && e.target.matches('[data-sgcombo="rp:bod"]')) limpiarCombo('rpubi');
    });
    /* Enter en estos campos agrega a la lista; nunca envia el formulario. */
    document.addEventListener('keydown', function (e) {
        if (e.key !== 'Enter' || !e.target.closest) return;
        if (e.target.closest('#rpCompUi')) { e.preventDefault(); agregarCompat(); }
        else if (e.target.closest('#rpStockUi')) { e.preventDefault(); agregarStock(); }
    }, true);

    window.rpGuardarHdn = guardar;
    window.rpIniciar = iniciar;
    window.addEventListener('load', function () {
        setTimeout(iniciar, 0);
        if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () { setTimeout(iniciar, 0); });
    });
})();
