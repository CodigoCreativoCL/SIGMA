/* ============================================================================
   SIGMA · GRILLAS COMO LISTA + TARJETAS (17-10-2026)
   Complemento de sigma-grilla.css para las grillas Telerik (RadGrid2):
     · pone data-label en cada celda (las tarjetas de pantalla angosta muestran «ETIQUETA: valor»);
     · agrega un buscador sobre la grilla que filtra las filas de la página actual (no hace postback);
   Se vuelve a aplicar tras cada actualización parcial (UpdatePanel). No toca la lógica de la grilla.
   ============================================================================ */
(function (window, document) {
    'use strict';

    var consultas = {};
    var LUPA = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.5"/><path d="m16 16 4.5 4.5"/></svg>';

    function norm(s) { return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }

    function filas(tabla) {
        return [].slice.call(tabla.querySelectorAll('tbody > tr.rgRow, tbody > tr.rgAltRow'));
    }

    /* Celdas que son solo un estado se muestran como chip (hoja de componentes del Centro Comercial). */
    var ESTADOS = {
        'habilitado': 'ok', 'habilitada': 'ok', 'activo': 'ok', 'activa': 'ok', 'vigente': 'ok', 'si': 'ok', 'abierta': 'ok', 'publicado': 'ok', 'publico': 'ok',
        'deshabilitado': 'gr', 'deshabilitada': 'gr', 'inactivo': 'gr', 'inactiva': 'gr', 'no': 'gr', 'borrador': 'gr', 'cerrada': 'gr',
        'pendiente': 'wa', 'por vencer': 'wa', 'vencido': 'da', 'vencida': 'da', 'anulado': 'da', 'anulada': 'da', 'rechazado': 'da'
    };
    function chips(tabla) {
        filas(tabla).forEach(function (tr) {
            [].slice.call(tr.children).forEach(function (td) {
                if (td.getAttribute('data-sg-chip') || td.children.length) return;
                var tono = ESTADOS[norm(td.textContent).trim()];
                if (!tono) return;
                td.setAttribute('data-sg-chip', '1');
                td.innerHTML = '<span class="sg-chip is-' + tono + '">' + td.textContent.trim().toUpperCase() + '</span>';
            });
        });
    }

    function etiquetar(tabla) {
        var cab = tabla.querySelector('thead tr:not(.rgCommandRow) th, thead tr.rgHeaderRow th, th.rgHeader');
        var ths = [].slice.call(tabla.querySelectorAll('thead th.rgHeader'));
        if (!ths.length && cab) ths = [cab];
        var rotulos = ths.map(function (th) { return (th.textContent || '').replace(/\s+/g, ' ').trim(); });
        filas(tabla).forEach(function (tr) {
            [].slice.call(tr.children).forEach(function (td, i) {
                if (rotulos[i] && !td.hasAttribute('data-label')) td.setAttribute('data-label', rotulos[i]);
            });
        });
    }

    function contar(tabla, barra) {
        var todas = filas(tabla), vis = todas.filter(function (f) { return f.style.display !== 'none'; }).length;
        var n = barra.querySelector('.sg-gr-n');
        if (n) n.textContent = vis === todas.length ? todas.length + (todas.length === 1 ? ' registro' : ' registros') : vis + ' de ' + todas.length;
    }

    function filtrar(tabla, barra, q) {
        var t = norm(q);
        filas(tabla).forEach(function (f) { f.style.display = !t || norm(f.textContent).indexOf(t) >= 0 ? '' : 'none'; });
        contar(tabla, barra);
    }

    function buscador(grilla, tabla) {
        if (!filas(tabla).length && !consultas[grilla.id]) return;
        var barra = grilla.previousElementSibling;
        if (!barra || !barra.classList || !barra.classList.contains('sg-gr-bar')) {
            barra = document.createElement('div');
            barra.className = 'sg-gr-bar';
            barra.innerHTML = '<label class="sg-gr-buscar">' + LUPA + '<input type="text" autocomplete="off" placeholder="Buscar en la lista" aria-label="Buscar en la lista"></label><span class="sg-gr-n"></span>';
            grilla.parentNode.insertBefore(barra, grilla);
            var inp = barra.querySelector('input');
            /* Enter en un campo suelto del formulario dispararía un postback: aquí solo filtra. */
            inp.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.keyCode === 13) e.preventDefault(); });
            inp.addEventListener('input', function () { consultas[grilla.id] = inp.value; filtrar(tabla, barra, inp.value); });
        }
        var campo = barra.querySelector('input');
        if (consultas[grilla.id] && campo.value !== consultas[grilla.id]) campo.value = consultas[grilla.id];
        filtrar(tabla, barra, campo.value);
    }

    function aplicar(raiz) {
        [].slice.call((raiz || document).querySelectorAll('.RadGrid')).forEach(function (g) {
            var tabla = g.querySelector('table.rgMasterTable');
            if (!tabla || !g.id) return;
            etiquetar(tabla);
            chips(tabla);
            buscador(g, tabla);
        });
    }

    function iniciar() {
        aplicar(document);
        try {
            var prm = window.Sys && window.Sys.WebForms && window.Sys.WebForms.PageRequestManager.getInstance();
            if (prm) prm.add_endRequest(function () { aplicar(document); });
        } catch (e) { }
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar);
    else iniciar();
    window.SigmaGrilla = { aplicar: aplicar };
})(window, document);
