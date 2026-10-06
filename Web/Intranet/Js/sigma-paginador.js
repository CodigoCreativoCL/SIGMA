/* ============================================================================
   SigmaPaginador · el paginador comun de las vistas Tarjetas y Lista
   (Centro de activos, Centro de repuestos). 06-10-2026.

   Uso:  var p = SigmaPaginador.cortar(items, pagina, tam);
         html += SigmaPaginador.html(p, 'rc');            // 'rc' = prefijo
         SigmaPaginador.escuchar('rc', function (pag, tam) { ...repintar... });
   Los estilos van en sigma-activos.css (.sg-pag), que ya cargan las dos.
   ========================================================================= */
(function () {
    'use strict';
    var TAMANOS = [12, 24, 48, 96];

    function cortar(items, pagina, tam) {
        var total = items.length, paginas = Math.max(1, Math.ceil(total / tam));
        pagina = Math.min(Math.max(1, pagina || 1), paginas);
        var desde = (pagina - 1) * tam;
        return { items: items.slice(desde, desde + tam), pagina: pagina, paginas: paginas, total: total, tam: tam, desde: total ? desde + 1 : 0, hasta: Math.min(total, desde + tam) };
    }

    function numeros(pag, n) {
        var out = [], i;
        if (n <= 7) { for (i = 1; i <= n; i++) out.push(i); return out; }
        out.push(1);
        if (pag > 3) out.push('…');
        for (i = Math.max(2, pag - 1); i <= Math.min(n - 1, pag + 1); i++) out.push(i);
        if (pag < n - 2) out.push('…');
        out.push(n);
        return out;
    }

    function html(p, prefijo, nombre) {
        if (!p.total) return '';
        var flecha = function (d) { return '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="' + (d < 0 ? 'M15 6l-6 6 6 6' : 'M9 6l6 6-6 6') + '"/></svg>'; };
        var b = '<nav class="sg-pag" data-pag-de="' + prefijo + '" aria-label="Páginas">'
            + '<span class="sg-pag-info">' + p.desde + '–' + p.hasta + ' de ' + p.total + ' ' + (nombre || '') + '</span>'
            + '<div class="sg-pag-nums">'
            + '<button type="button" data-pag="' + (p.pagina - 1) + '"' + (p.pagina <= 1 ? ' disabled' : '') + ' aria-label="Página anterior">' + flecha(-1) + '</button>';
        numeros(p.pagina, p.paginas).forEach(function (n) {
            b += n === '…' ? '<span class="sg-pag-gap">…</span>'
               : '<button type="button" data-pag="' + n + '"' + (n === p.pagina ? ' aria-current="page"' : '') + '>' + n + '</button>';
        });
        b += '<button type="button" data-pag="' + (p.pagina + 1) + '"' + (p.pagina >= p.paginas ? ' disabled' : '') + ' aria-label="Página siguiente">' + flecha(1) + '</button></div>'
           + '<label class="sg-pag-tam">Por página<select data-pag-tam>' + TAMANOS.map(function (t) { return '<option value="' + t + '"' + (t === p.tam ? ' selected' : '') + '>' + t + '</option>'; }).join('') + '</select></label>'
           + '</nav>';
        return b;
    }

    function escuchar(prefijo, cb) {
        document.addEventListener('click', function (e) {
            var b = e.target.closest && e.target.closest('[data-pag-de="' + prefijo + '"] [data-pag]');
            if (!b || b.disabled) return;
            e.preventDefault();
            cb(parseInt(b.getAttribute('data-pag'), 10), null);
        });
        document.addEventListener('change', function (e) {
            if (!e.target.matches || !e.target.matches('[data-pag-de="' + prefijo + '"] [data-pag-tam]')) return;
            cb(1, parseInt(e.target.value, 10));
        });
    }

    window.SigmaPaginador = { cortar: cortar, html: html, escuchar: escuchar, TAMANOS: TAMANOS };
})();
