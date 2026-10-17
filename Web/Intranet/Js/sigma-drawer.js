/* ============================================================================
   SIGMA · DRAWER GLOBAL (17-10-2026)

   Abre una ficha del sitio (una página WebForms con Simple.master) en el MISMO panel lateral de los Centros
   (.cp-scr + .cp-pnl de K.Panel), no en un modal. Reemplaza a SigmaModal.

     SigmaDrawer.open({ url, title, width, recordId })  ó  SigmaDrawer.open(url, { title, width })
     SigmaDrawer.close()      cierra el drawer de arriba
     SigmaDrawer.isOpen()

   · Las fichas siguen cerrando y refrescando por `window.frameElement.radWindow` (close, BrowserWindow.refresh…): aquí se les
     da ese contrato, igual que hace abrirFichaSitio en el Centro Comercial.
   · Desde dentro de una ficha (iframe) el nuevo drawer se abre en la ventana más alta y se apila encima.
   · Al cerrar se emite `sigma:modalclosed` en el documento, que varios Centros ya escuchan para recargar su lista.
   ============================================================================ */
(function (window, document) {
    'use strict';

    if (window.SigmaDrawer) return;

    var pila = [];
    var X = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>';

    function esc(v) {
        return String(v == null ? '' : v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function normalizar(a, b) {
        var o = (typeof a === 'object' && a) ? a : (b || {});
        if (typeof a !== 'object') o.url = a;
        var ancho = parseInt(o.width, 10) || 960;
        return { url: o.url || '', title: o.title || 'Detalle', recordId: o.recordId == null ? '' : String(o.recordId), clase: ancho >= 1100 ? 'cp-xw' : ancho >= 640 ? 'cp-w' : '' };
    }

    function recordName(doc) {
        if (!doc) return '';
        var sel = ['[data-sigma-record-name]', 'input[id*="txtNombre"]', 'input[id*="txtRazonSocial"]', 'input[id*="txtNombreFantasia"]', 'input[id*="txtNumero"]', 'input[id*="txtFolio"]', 'input[id*="txtDescripcion"]', 'input[id*="txtCodigo"]'];
        for (var i = 0; i < sel.length; i++) {
            var n = doc.querySelector(sel[i]);
            var v = n ? String(n.value || n.textContent || '').replace(/\s+/g, ' ').trim() : '';
            if (v) return v;
        }
        return '';
    }

    function superior() {
        var w = window;
        try { while (w.parent && w.parent !== w && w.parent.SigmaDrawer && w.parent.document) w = w.parent; } catch (e) { }
        return w;
    }

    function cerrar(inst) {
        if (!inst || inst.cerrado) return false;
        inst.cerrado = true;
        document.removeEventListener('keydown', inst.tecla, true);
        pila = pila.filter(function (x) { return x !== inst; });
        if (inst.host.parentNode) inst.host.parentNode.removeChild(inst.host);
        if (!pila.length) document.documentElement.classList.remove('sg-drawer-locked');
        if (inst.previo && inst.previo.focus) { try { inst.previo.focus(); } catch (e) { } }
        var ev;
        if (typeof window.CustomEvent === 'function') ev = new CustomEvent('sigma:modalclosed');
        else { ev = document.createEvent('Event'); ev.initEvent('sigma:modalclosed', true, true); }
        document.dispatchEvent(ev);
        return false;
    }

    function adaptador(inst) {
        return {
            BrowserWindow: window,
            close: function () { cerrar(inst); },
            center: function () { }, setSize: function () { },
            isVisible: function () { return !inst.cerrado; },
            get_contentFrame: function () { return inst.frame; },
            get_contentFrameElement: function () { return inst.frame; }
        };
    }

    function abrir(a, b) {
        var w = superior();
        if (w !== window) return w.SigmaDrawer.open(a, b);

        var cfg = normalizar(a, b);
        if (!cfg.url) return false;

        var host = document.createElement('div');
        host.className = 'cp-root sg-drawer-host';
        host.innerHTML =
            '<div class="cp-scr" data-sgd="x"></div>' +
            '<aside class="cp-pnl ' + cfg.clase + '" role="dialog" aria-modal="true">' +
                '<div class="cp-pnl-h"><div class="cp-t"><small>SIGMA</small><h3>' + esc(cfg.title) + '</h3></div>' +
                '<button type="button" class="cp-ibx" data-sgd="x" aria-label="Cerrar panel">' + X + '</button></div>' +
                '<div class="cp-pnl-b"><div class="sg-drawer-load">Cargando…</div><iframe class="sg-drawer-frame" title="' + esc(cfg.title) + '"></iframe></div>' +
            '</aside>';
        var nivel = pila.length;
        host.querySelector('.cp-scr').style.zIndex = 1040 + nivel * 4;
        host.querySelector('.cp-pnl').style.zIndex = 1041 + nivel * 4;
        document.body.appendChild(host);
        document.documentElement.classList.add('sg-drawer-locked');

        var inst = { host: host, frame: host.querySelector('iframe'), cfg: cfg, previo: document.activeElement, cerrado: false };
        inst.tecla = function (e) {
            if ((e.key === 'Escape' || e.keyCode === 27) && pila[pila.length - 1] === inst) { e.preventDefault(); cerrar(inst); }
        };
        document.addEventListener('keydown', inst.tecla, true);
        host.addEventListener('click', function (e) {
            var t = e.target.closest ? e.target.closest('[data-sgd="x"]') : null;
            if (t) cerrar(inst);
        });

        var ad = adaptador(inst);
        inst.frame.radWindow = ad;
        inst.frame.addEventListener('load', function () {
            if (inst.cerrado) return;
            try {
                var cw = inst.frame.contentWindow, doc = inst.frame.contentDocument;
                cw.radWindow = ad;
                doc.documentElement.classList.add('sigma-dialog-child');
                if (!doc._sgdWired) {
                    doc._sgdWired = true;
                    doc.addEventListener('keydown', function (e) { if ((e.key === 'Escape' || e.keyCode === 27) && pila[pila.length - 1] === inst) cerrar(inst); });
                }
                var nom = recordName(doc);
                if (nom && nom.toLowerCase() !== cfg.title.toLowerCase()) {
                    host.querySelector('.cp-pnl-h small').textContent = cfg.title;
                    host.querySelector('.cp-pnl-h h3').textContent = nom;
                }
            } catch (e) { }
            host.querySelector('.cp-pnl-b').classList.add('is-ready');
        });
        pila.push(inst);
        inst.frame.src = cfg.url;
        var x = host.querySelector('.cp-ibx'); if (x) x.focus();
        return false;
    }

    window.SigmaDrawer = {
        open: abrir,
        close: function () { return cerrar(pila[pila.length - 1]); },
        resize: function () { },
        isOpen: function () { return pila.length > 0; }
    };
})(window, document);
