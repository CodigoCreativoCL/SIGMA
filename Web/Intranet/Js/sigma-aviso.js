/* ============================================================================
   SIGMA · AVISOS Y CONFIRMACIONES (17-10-2026)

   Reemplaza al aviso antiguo de `Tools.tools.ClientAlert` (modal de Bootstrap con el icono animado de SweetAlert),
   a `AlertSweet` y a la confirmación de `ConfirSweetAlert` (SweetAlert2). Todo el sitio habla con la misma voz que los
   Centros rediseñados:

     · «ok»      → toast (no bloquea) abajo a la derecha, como el de los Centros.
     · «error»   → diálogo con icono rojo y un único botón morado «Aceptar».
     · «alerta»  → diálogo con icono ámbar.
     · «info»    → diálogo con icono azul (los avisos sin tipo).
     · confirmar → diálogo con «Cancelar» (ghost) y la acción en morado, o en rojo si es destructiva.

   Dentro de una ficha (iframe de SigmaDrawer) el aviso se pinta en la ventana más alta que lo permita, para que no muera
   cuando la ficha se cierra con `cerrar`.

   API:  SigmaAviso.mostrar(mensaje, tipo, { titulo, cerrar, alAceptar })
         SigmaAviso.confirmar({ titulo, mensaje, aceptar, peligro }) → Promise<boolean>
   ============================================================================ */
(function (window, document) {
    'use strict';

    if (window.SigmaAviso && window.SigmaAviso._pintar) return;

    var ICONOS = {
        ok: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12.5 4.2 4.2L19 7" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
        error: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 7 10 10M17 7 7 17" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>',
        alerta: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 8v5.2M12 16.6v.1" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/><path d="M10.3 4.6 3.5 16.4a2 2 0 0 0 1.7 3h13.6a2 2 0 0 0 1.7-3L13.7 4.6a2 2 0 0 0-3.4 0Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>',
        info: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8.4" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M12 11v5M12 7.9v.1" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"/></svg>',
        pregunta: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8.4" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M9.6 9.6a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1.1.9-1.1 1.7M12 16.6v.1" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>'
    };
    var TITULOS = { ok: 'Listo', error: 'No se pudo completar', alerta: 'Revise esto', info: 'Aviso', pregunta: 'Confirmar' };
    var abiertos = 0;

    function normalizarTipo(t) {
        t = String(t || '').toLowerCase();
        return ICONOS[t] ? t : 'info';
    }

    function escapar(v) {
        return String(v == null ? '' : v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    /* Los mensajes del servidor pueden traer <br> o negritas; todo lo demás se escapa. */
    function limpio(v) {
        return escapar(v).replace(/&lt;(\/?)(br|b|strong|i|em|ul|li|p)\s*\/?&gt;/gi, function (m, c, t) {
            return '<' + c + t.toLowerCase() + (t.toLowerCase() === 'br' ? '/' : '') + '>';
        });
    }

    function contenedorToasts() {
        var c = document.getElementById('sgAvToasts');
        if (!c) {
            c = document.createElement('div');
            c.id = 'sgAvToasts';
            c.className = 'sg-av-toasts';
            c.setAttribute('aria-live', 'polite');
            document.body.appendChild(c);
        }
        return c;
    }

    function toast(mensaje, opts) {
        var t = document.createElement('div');
        t.className = 'sg-av-toast';
        t.setAttribute('role', 'status');
        t.innerHTML = '<span class="sg-av-toast__ico">' + ICONOS.ok + '</span><span class="sg-av-toast__txt">' + limpio(mensaje) + '</span>' +
            '<button type="button" class="sg-av-toast__x" aria-label="Cerrar">' + ICONOS.error + '</button>';
        contenedorToasts().appendChild(t);
        var quitar = function () {
            t.classList.remove('is-in');
            window.setTimeout(function () { if (t.parentNode) t.parentNode.removeChild(t); }, 220);
        };
        t.querySelector('.sg-av-toast__x').addEventListener('click', quitar);
        window.requestAnimationFrame(function () { t.classList.add('is-in'); });
        window.setTimeout(quitar, (opts && opts.ms) || 4600);
        return t;
    }

    function dialogo(cfg) {
        var previo = document.activeElement;
        var caja = document.createElement('div');
        caja.className = 'sg-av';
        caja.setAttribute('role', 'alertdialog');
        caja.setAttribute('aria-modal', 'true');
        var idT = 'sgAvT' + (++abiertos);
        caja.setAttribute('aria-labelledby', idT);
        caja.innerHTML =
            '<div class="sg-av__card sg-av--' + cfg.tipo + '">' +
                '<span class="sg-av__ico">' + ICONOS[cfg.tipo] + '</span>' +
                '<div class="sg-av__body"><strong class="sg-av__t" id="' + idT + '">' + limpio(cfg.titulo) + '</strong>' +
                (cfg.mensaje ? '<p class="sg-av__m">' + limpio(cfg.mensaje) + '</p>' : '') + '</div>' +
                '<div class="sg-av__acc">' +
                    (cfg.cancelar ? '<button type="button" class="sg-av__btn sg-av__btn--ghost" data-r="0">' + escapar(cfg.cancelar) + '</button>' : '') +
                    '<button type="button" class="sg-av__btn ' + (cfg.peligro ? 'sg-av__btn--peligro' : 'sg-av__btn--primario') + '" data-r="1">' + escapar(cfg.aceptar) + '</button>' +
                '</div>' +
            '</div>';
        document.body.appendChild(caja);
        document.documentElement.classList.add('sg-av-bloqueado');

        var cerrado = false;
        function cerrar(ok) {
            if (cerrado) return;
            cerrado = true;
            document.removeEventListener('keydown', tecla, true);
            caja.classList.remove('is-in');
            window.setTimeout(function () {
                if (caja.parentNode) caja.parentNode.removeChild(caja);
                if (!document.querySelector('.sg-av')) document.documentElement.classList.remove('sg-av-bloqueado');
                if (previo && previo.focus) { try { previo.focus(); } catch (e) { } }
            }, 160);
            if (cfg.fin) cfg.fin(ok);
        }
        function tecla(e) {
            if (e.key === 'Escape' || e.keyCode === 27) { e.preventDefault(); e.stopPropagation(); cerrar(false); }
            else if ((e.key === 'Tab' || e.keyCode === 9)) {
                var bs = caja.querySelectorAll('button');
                var primero = bs[0], ultimo = bs[bs.length - 1];
                if (e.shiftKey && document.activeElement === primero) { e.preventDefault(); ultimo.focus(); }
                else if (!e.shiftKey && document.activeElement === ultimo) { e.preventDefault(); primero.focus(); }
            }
        }
        document.addEventListener('keydown', tecla, true);
        caja.addEventListener('click', function (e) {
            if (e.target === caja) cerrar(false);
            var b = e.target.closest ? e.target.closest('button[data-r]') : null;
            if (b) cerrar(b.getAttribute('data-r') === '1');
        });
        window.requestAnimationFrame(function () {
            caja.classList.add('is-in');
            var foco = caja.querySelector('.sg-av__btn--primario, .sg-av__btn--peligro');
            if (foco) foco.focus();
        });
    }

    function pintar(mensaje, tipo, opts) {
        opts = opts || {};
        tipo = normalizarTipo(tipo);
        if (tipo === 'ok') { toast(mensaje, opts); return; }
        dialogo({
            tipo: tipo, titulo: opts.titulo || TITULOS[tipo], mensaje: mensaje, aceptar: 'Aceptar',
            fin: function () { if (opts.cerrar && window.closeWindow) { try { window.closeWindow(); } catch (e) { } } if (opts.alAceptar) opts.alAceptar(); }
        });
    }

    /* La ventana más alta (mismo origen) que tenga SigmaAviso: ahí se pinta, para sobrevivir al cierre de la ficha. */
    function superior() {
        var w = window;
        try {
            while (w.parent && w.parent !== w && w.parent.SigmaAviso && w.parent.SigmaAviso._pintar && w.parent.document) w = w.parent;
        } catch (e) { }
        return w;
    }

    var api = {
        _pintar: pintar,
        mostrar: function (mensaje, tipo, opts) {
            opts = opts || {};
            var w = superior();
            tipo = normalizarTipo(tipo);
            if (tipo === 'ok') {
                /* El toast no espera nada: lo que había que hacer «al aceptar» se hace ya. */
                w.SigmaAviso._pintar(mensaje, tipo, opts);
                if (opts.alAceptar) opts.alAceptar();
                if (opts.cerrar && window.closeWindow) { try { window.closeWindow(); } catch (e) { } }
                return;
            }
            if (w === window) { pintar(mensaje, tipo, opts); return; }
            /* Diálogo en la ventana superior; `cerrar` y `alAceptar` corren aquí, cuando la persona acepta. */
            w.SigmaAviso._pintar(mensaje, tipo, {
                titulo: opts.titulo,
                alAceptar: function () {
                    if (opts.cerrar && window.closeWindow) { try { window.closeWindow(); } catch (e) { } }
                    if (opts.alAceptar) opts.alAceptar();
                }
            });
        },
        confirmar: function (cfg) {
            cfg = cfg || {};
            var w = superior();
            return new Promise(function (resolver) {
                var conf = {
                    tipo: cfg.peligro ? 'alerta' : 'pregunta', titulo: cfg.titulo || '¿Confirmar?', mensaje: cfg.mensaje || '',
                    aceptar: cfg.aceptar || 'Sí, continuar', cancelar: cfg.cancelar || 'Cancelar', peligro: !!cfg.peligro, fin: resolver
                };
                (w.SigmaAviso._dialogo || dialogo)(conf);
            });
        },
        _dialogo: dialogo
    };

    window.SigmaAviso = api;
})(window, document);
