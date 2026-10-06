(function (window, document) {
    'use strict';

    var recargando = false;

    function parts() {
        var panel = document.querySelector('[data-sg-notif-panel]');
        if (!panel) return null;
        return {
            panel: panel,
            parent: panel.closest ? panel.closest('.dropdown') : panel.parentNode,
            trigger: panel.parentNode.querySelector('[data-toggle="dropdown"]')
        };
    }

    function closePanel(p) {
        if (!p) return;
        p.parent.classList.remove('show');
        p.panel.classList.remove('show');
        p.trigger.setAttribute('aria-expanded', 'false');
        p.trigger.focus();
    }

    /* ======================================================================
       PANEL v2 (06-10-2026)

       Todo lo que se ve se cuenta sobre las MISMAS filas ya agrupadas que
       dibuja el servidor: la campana, el encabezado y los chips no pueden
       discrepar porque salen de aqui. Filtrar, silenciar y marcar leidas se
       resuelve en el navegador; al servidor solo viaja la lectura.
       ====================================================================== */
    var filtroVisto = '';
    var PREF_KEY = 'sg-np-pref', MUTE_KEY = 'sg-np-mute';

    function leerLS(k) { try { return JSON.parse(localStorage.getItem(k) || '{}') || {}; } catch (e) { return {}; } }
    function guardarLS(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { } }

    function oculta(fila) {
        var tipo = fila.getAttribute('data-tipo') || '';
        var pref = leerLS(PREF_KEY), mute = leerLS(MUTE_KEY);
        return pref[tipo] === 'silencio' || (mute[tipo] && mute[tipo] > Date.now());
    }

    function filasDe(panel) { return Array.prototype.slice.call(panel.querySelectorAll('[data-np-row]')); }

    function pasa(fila, f) {
        if (!f) return true;
        if (f === 'req') return fila.getAttribute('data-req') === '1';
        if (f === '0') return fila.getAttribute('data-visto') === '0';
        return fila.getAttribute('data-cat') === f;
    }

    function badgeDe(n, critica) {
        var enlace = document.querySelector('.sigma-notification');
        if (!enlace) return;
        var b = enlace.querySelector('.sigma-notification__count');
        if (n > 0) {
            if (!b) { b = document.createElement('span'); b.className = 'sigma-notification__count'; b.setAttribute('aria-hidden', 'true'); enlace.appendChild(b); }
            b.textContent = n > 99 ? '99+' : n;
            enlace.setAttribute('aria-label', n + ' notificaciones sin leer');
        }
        else if (b) { b.parentNode.removeChild(b); enlace.setAttribute('aria-label', 'Notificaciones'); }
        enlace.classList.toggle('sigma-notification--critical', !!critica && n > 0);
    }

    function aplicarFiltro(panel) {
        if (!panel) return;
        var filas = filasDe(panel), vis = filas.filter(function (f) { return !oculta(f); });
        var cuenta = { '': vis.length, req: 0, '0': 0 }, cats = {}, critSin = false;

        vis.forEach(function (f) {
            if (f.getAttribute('data-req') === '1') cuenta.req++;
            if (f.getAttribute('data-visto') === '0') { cuenta['0']++; if (f.getAttribute('data-req') === '1' && f.querySelector('.np-sev.crit')) critSin = true; }
            var c = f.getAttribute('data-cat'); cats[c] = (cats[c] || 0) + 1;
        });

        var algunaVisible = false;
        filas.forEach(function (f) {
            var ver = !oculta(f) && pasa(f, filtroVisto);
            f.hidden = !ver;
            if (ver) algunaVisible = true;
        });

        /* El rotulo de fecha solo si le queda alguna fila debajo. */
        var secs = panel.querySelectorAll('.np-sec');
        Array.prototype.forEach.call(secs, function (s) {
            var el = s.nextElementSibling, hay = false;
            while (el && !el.classList.contains('np-sec')) { if (el.hasAttribute('data-np-row') && !el.hidden) hay = true; el = el.nextElementSibling; }
            s.hidden = !hay;
        });

        Array.prototype.forEach.call(panel.querySelectorAll('[data-np-filtro]'), function (b) {
            var v = b.getAttribute('data-np-filtro') || '', suyo = v === filtroVisto;
            var n = v === '' || v === 'req' || v === '0' ? cuenta[v] : (cats[v] || 0);
            b.classList.toggle('is-activo', suyo);
            b.setAttribute('aria-pressed', suyo ? 'true' : 'false');
            b.classList.toggle('is-vacia', n === 0 && !suyo);
            /* Los tipos sin nada no se muestran; los tres primeros siempre. */
            b.hidden = (v !== '' && v !== 'req' && v !== '0') && n === 0 && !suyo;
            var hueco = b.querySelector('b'); if (hueco) hueco.textContent = n;
        });

        var res = panel.querySelector('.sg-notif-resumen');
        if (res) res.innerHTML = (cuenta.req === 0 && cuenta['0'] === 0)
            ? 'Estás al día'
            : '<strong>' + cuenta.req + ' requieren acción</strong> · <span>' + cuenta['0'] + ' sin leer</span>';

        var todo = panel.querySelector('[data-sg-notif-leer-todo]');
        if (todo) todo.hidden = cuenta['0'] === 0;

        badgeDe(cuenta['0'], critSin);

        var cuerpo = panel.querySelector('.np-cuerpo');
        var aviso = panel.querySelector('[data-np-sinfiltro]');
        if (cuerpo && filas.length && !algunaVisible) {
            if (!aviso) { aviso = document.createElement('div'); aviso.className = 'np-vacio-f'; aviso.setAttribute('data-np-sinfiltro', '1'); cuerpo.appendChild(aviso); }
            aviso.innerHTML = filtroVisto === '0' ? '<b>No queda nada sin leer</b>Estás al día.' : '<b>Nada con este filtro</b>Prueba con «Todas».';
            aviso.hidden = false;
        }
        else if (aviso) aviso.hidden = true;
    }

    /* Marca como leidas, en el DOM, las alertas con esos ids. */
    function marcarDom(panel, ids) {
        var set = {}; ids.forEach(function (i) { set[String(i)] = 1; });
        Array.prototype.forEach.call(panel.querySelectorAll('.np-row[data-np-abre], .np-sub, .np-ai'), function (el) {
            var id = (el.getAttribute('data-np-id') || el.getAttribute('data-ids') || '');
            if (!set[id]) return;
            el.classList.add('is-leida'); el.classList.remove('is-nueva');
            Array.prototype.forEach.call(el.querySelectorAll(':scope > .np-dot, :scope > .np-ai-h .np-dot'), function (d) { d.remove(); });
            if (el.hasAttribute('data-np-row')) el.setAttribute('data-visto', '1');
        });
        Array.prototype.forEach.call(panel.querySelectorAll('.np-grp'), function (g) {
            var subs = g.querySelectorAll('.np-sub'), sin = g.querySelectorAll('.np-sub:not(.is-leida)').length;
            var go = g.querySelector('.np-grp-h .np-go');
            if (go && go.firstChild) go.firstChild.textContent = (sin > 0 ? sin + ' sin leer' : 'todas leídas') + ' ';
            if (sin === 0 && subs.length) {
                g.setAttribute('data-visto', '1'); g.classList.add('is-leida'); g.classList.remove('is-nueva');
                var d = g.querySelector('.np-grp-h > .np-dot'); if (d) d.remove();
            }
        });
    }

    function idsSinLeer(panel) {
        var ids = [];
        Array.prototype.forEach.call(panel.querySelectorAll('.np-row[data-np-abre]:not(.is-leida), .np-sub:not(.is-leida), .np-ai:not(.is-leida)'), function (el) {
            var id = el.getAttribute('data-np-id') || el.getAttribute('data-ids'); if (id) ids.push(id);
        });
        return ids;
    }

    function toast(texto, deshacer, alCerrar) {
        var viejo = document.querySelector('.np-toast'); if (viejo) viejo.remove();
        var t = document.createElement('div'); t.className = 'np-toast'; t.setAttribute('role', 'status');
        t.innerHTML = '<span></span>' + (deshacer ? '<button type="button">Deshacer</button>' : '');
        t.firstChild.textContent = texto;
        var deshecho = false;
        if (deshacer) t.querySelector('button').onclick = function () { deshecho = true; deshacer(); t.remove(); };
        document.body.appendChild(t);
        setTimeout(function () { if (t.parentNode) t.remove(); if (!deshecho && alCerrar) alCerrar(); }, 6000);
    }

    function leerEnServidor(csv) {
        if (window.sigmaAlertas) return sigmaAlertas.leer(csv);
        return null;
    }

    function prefsHtml(panel) {
        var tipos = {}, pref = leerLS(PREF_KEY);
        filasDe(panel).forEach(function (f) { tipos[f.getAttribute('data-tipo')] = f.getAttribute('data-tn') || f.getAttribute('data-tipo'); });
        var ks = Object.keys(tipos);
        if (!ks.length) return '<h5>Preferencias</h5><p>Cuando lleguen avisos podrás elegir cómo recibir cada tipo.</p>';
        return '<h5>Cómo quieres recibir cada tipo</h5><p>Se guarda en este navegador. «Por correo» llegará más adelante.</p>' + ks.map(function (k) {
            return '<label class="np-pref"><span>' + tipos[k].replace(/[<>&]/g, '') + '</span><select data-np-pref="' + k.replace(/"/g, '') + '">' +
                '<option value="panel"' + (pref[k] !== 'silencio' ? ' selected' : '') + '>En el panel</option>' +
                '<option value="correo" disabled>Por correo (próximamente)</option>' +
                '<option value="silencio"' + (pref[k] === 'silencio' ? ' selected' : '') + '>En silencio</option></select></label>';
        }).join('');
    }

    function abrirFila(el) {
        var url = el.getAttribute('data-np-url'), q = el.getAttribute('data-np-q'), id = el.getAttribute('data-np-id');
        if (!url) return;
        marcarDom(el.closest('[data-sg-notif-panel]'), [id]);
        aplicarFiltro(el.closest('[data-sg-notif-panel]'));
        if (window.abrirNotificacion) window.abrirNotificacion(url, q, +id);
    }

    /* ======================================================================
       LOS VECTORES SE ANIMAN, Y PARA ESO EL SVG TIENE QUE ESTAR EN LINEA

       POR QUE NO ALCANZA CON <img>

         Un <img> es una caja opaca: el navegador dibuja el SVG adentro pero su
         contenido no es parte del documento, asi que no hay nodos ni trazos
         que animar. Para llegar a los vectores hay que traer el archivo y
         ponerlo en el DOM como <svg>.

         Se descarga UNA vez por archivo y se guarda: seis filas del mismo tipo
         comparten el mismo dibujo, y bajarlo seis veces seria pagar seis
         viajes por lo mismo.

       QUE HACE LA ANIMACION

         Las lineas se DIBUJAN -de la nada hasta su largo completo- y los nodos
         aparecen despues, escalonados. Se lee como que el grafo se esta
         armando, que es lo que el simbolo representa: algo que se conecto y
         produjo un aviso.

         El destello de las predicciones entra girando y con rebote: es el
         unico elemento que no es parte del grafo, y es el que dice que esto
         salio de un modelo.

       UNA VEZ, NO EN BUCLE

         Es una lista de avisos, no una pantalla de carga. Algo que se mueve
         sin parar al lado de un texto que hay que leer compite con el texto.
       ====================================================================== */
    var cacheSvg = {};

    function claveDe(src) {
        var m = /sigma-ai-([a-z-]+)\.svg/i.exec(src || '');
        return m ? m[1] : '';
    }

    function animarVectores(svg) {
        if (!window.gsap) return;

        if (window.matchMedia &&
            matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        var trazos = svg.querySelectorAll('path[stroke]');
        var rellenos = svg.querySelectorAll('path[fill]:not([stroke])');

        var linea = gsap.timeline();

        for (var i = 0; i < trazos.length; i++) {
            var t = trazos[i];
            var largo = 0;

            /* `getTotalLength` puede fallar si el path no esta dibujado
               todavia; sin el largo no hay trazo que animar, pero el icono
               tiene que verse igual. */
            try { largo = t.getTotalLength(); } catch (e) { largo = 0; }

            if (!largo) continue;

            linea.fromTo(t,
                { strokeDasharray: largo, strokeDashoffset: largo },
                { strokeDashoffset: 0, duration: .55, ease: 'power2.out',
                  clearProps: 'strokeDasharray,strokeDashoffset' },
                i * 0.06);
        }

        /* El destello: es relleno, no trazo, asi que no se puede dibujar.
           Entra girando. */
        for (var j = 0; j < rellenos.length; j++) {
            linea.fromTo(rellenos[j],
                { scale: 0, rotate: -120, transformOrigin: 'center', opacity: 0 },
                { scale: 1, rotate: 0, opacity: 1, duration: .5, ease: 'back.out(2.4)',
                  clearProps: 'transform,opacity' },
                .28 + j * 0.05);
        }
    }

    function ponerSvg(img, texto) {
        var molde = document.createElement('div');
        molde.innerHTML = texto;

        var svg = molde.querySelector('svg');
        if (!svg || !img.parentNode) return;

        svg.setAttribute('data-sg-icono', claveDe(img.getAttribute('src')));
        svg.setAttribute('aria-hidden', 'true');
        svg.removeAttribute('width');
        svg.removeAttribute('height');

        img.parentNode.replaceChild(svg, img);
        animarVectores(svg);
    }

    function encenderIconos(panel) {
        if (!panel) return;

        var imgs = panel.querySelectorAll('.sg-notif-item .icono img');

        Array.prototype.forEach.call(imgs, function (img) {
            var src = img.getAttribute('src');
            if (!src) return;

            if (cacheSvg[src] === 'pendiente') return;

            if (typeof cacheSvg[src] === 'string' && cacheSvg[src] !== 'pendiente') {
                ponerSvg(img, cacheSvg[src]);
                return;
            }

            cacheSvg[src] = 'pendiente';

            if (typeof jQuery === 'undefined') { delete cacheSvg[src]; return; }

            jQuery.ajax({
                url: src, dataType: 'text', cache: true,
                success: function (texto) {
                    cacheSvg[src] = texto;
                    /* Puede haber llegado despues de que el panel se repinto:
                       se buscan de nuevo TODAS las que usan este archivo, no
                       solo la que disparo la descarga. */
                    var pendientes = document.querySelectorAll(
                        '.sg-notif-item .icono img[src="' + src + '"]');
                    Array.prototype.forEach.call(pendientes, function (n) {
                        ponerSvg(n, texto);
                    });
                },
                error: function () { delete cacheSvg[src]; }
            });
        });

        /* Los que ya estaban en linea de un repintado anterior tambien se
           animan: si no, al filtrar o al llegar una alerta nueva unos se
           mueven y otros no. */
        var yaVivos = panel.querySelectorAll('.sg-notif-item .icono svg[data-sg-icono]');
        Array.prototype.forEach.call(yaVivos, animarVectores);
    }

    function init() {
        var p = parts();
        if (!p || p.panel.getAttribute('data-sg-ready') === '1') return;
        p.panel.setAttribute('data-sg-ready', '1');

        var panel = p.panel;
        var pendienteLeerTodo = null;

        panel.addEventListener('click', function (event) {
            var t = event.target.closest ? event.target : null;
            if (!t) return;
            var c;

            if ((c = t.closest('[data-sg-notif-dismiss]'))) { event.preventDefault(); event.stopPropagation(); closePanel(p); return; }

            /* Marcar todo: se ve al instante y el POST sale al cerrarse el aviso. */
            if ((c = t.closest('[data-sg-notif-leer-todo]'))) {
                event.preventDefault(); event.stopPropagation();
                var ids = idsSinLeer(panel);
                var cuerpo = panel.querySelector('.np-cuerpo'), antes = cuerpo.innerHTML;
                marcarDom(panel, ids); aplicarFiltro(panel);
                toast('Todo marcado como leído', function () {
                    cuerpo.innerHTML = antes; aplicarFiltro(panel);
                }, function () { leerEnServidor(null); });
                return;
            }

            if ((c = t.closest('[data-np-filtro]'))) {
                event.preventDefault(); event.stopPropagation();
                filtroVisto = c.getAttribute('data-np-filtro') || '';
                aplicarFiltro(panel);
                return;
            }

            if ((c = t.closest('[data-np-prefs]'))) {
                event.preventDefault(); event.stopPropagation();
                var pp = panel.querySelector('[data-np-prefs-panel]');
                if (pp.hidden) pp.innerHTML = prefsHtml(panel);
                pp.hidden = !pp.hidden;
                return;
            }

            if ((c = t.closest('[data-np-leer]'))) {
                event.preventDefault(); event.stopPropagation();
                var lista = (c.getAttribute('data-np-leer') || '').split(',').filter(Boolean);
                marcarDom(panel, lista); aplicarFiltro(panel); leerEnServidor(lista.join(','));
                return;
            }

            if ((c = t.closest('[data-np-silenciar]'))) {
                event.preventDefault(); event.stopPropagation();
                var tipo = c.getAttribute('data-np-silenciar'), mute = leerLS(MUTE_KEY), antesM = mute[tipo];
                mute[tipo] = Date.now() + 24 * 3600 * 1000; guardarLS(MUTE_KEY, mute); aplicarFiltro(panel);
                toast('Silenciadas por 24 h las de este tipo', function () {
                    var m = leerLS(MUTE_KEY); if (antesM) m[tipo] = antesM; else delete m[tipo]; guardarLS(MUTE_KEY, m); aplicarFiltro(panel);
                });
                return;
            }

            if ((c = t.closest('[data-np-crear-ot]'))) {
                event.preventDefault(); event.stopPropagation();
                var id = c.getAttribute('data-np-crear-ot'), ws = panel.getAttribute('data-np-ws');
                if (typeof jQuery === 'undefined' || !ws) return;
                c.disabled = true;
                jQuery.ajax({ type: 'POST', url: ws + '/GenerarOrden', data: JSON.stringify({ alerta: +id }), contentType: 'application/json; charset=utf-8', dataType: 'json' })
                    .done(function (r) {
                        var d = {}; try { d = JSON.parse(r.d); } catch (e) { }
                        toast(d.error ? (d.detalle || 'No se pudo crear la OT.') : (d.detalle || 'Orden de trabajo creada.'));
                        if (!d.error) { marcarDom(panel, [id]); aplicarFiltro(panel); leerEnServidor(id); }
                        c.disabled = false;
                    })
                    .fail(function () { toast('No se pudo crear la OT.'); c.disabled = false; });
                return;
            }

            if ((c = t.closest('[data-np-expandir]'))) {
                event.preventDefault(); event.stopPropagation();
                var abierto = c.getAttribute('aria-expanded') === 'true';
                c.setAttribute('aria-expanded', abierto ? 'false' : 'true');
                var cuerpoG = c.parentNode.querySelector('.np-grp-b'); if (cuerpoG) cuerpoG.hidden = abierto;
                return;
            }

            if ((c = t.closest('[data-np-primera]'))) {
                event.preventDefault();
                var sub = c.closest('.np-grp').querySelector('.np-sub'); if (sub) abrirFila(sub);
                return;
            }

            if ((c = t.closest('[data-np-ir]'))) {
                var idsIr = (c.getAttribute('data-np-ir') || '').split(',').filter(Boolean);
                marcarDom(panel, idsIr); leerEnServidor(idsIr.join(','));
                return;
            }

            if ((c = t.closest('[data-np-abre]'))) { event.preventDefault(); abrirFila(c); return; }

            if (t.closest('a[href]')) return;
            event.stopPropagation();
        });

        panel.addEventListener('change', function (e) {
            var s = e.target.closest && e.target.closest('[data-np-pref]');
            if (!s) return;
            var pref = leerLS(PREF_KEY); pref[s.getAttribute('data-np-pref')] = s.value; guardarLS(PREF_KEY, pref);
            aplicarFiltro(panel);
        });

        aplicarFiltro(panel);

        panel.addEventListener('keydown', function (event) {
            if (event.key === 'Escape' || event.keyCode === 27) {
                event.preventDefault();
                closePanel(p);
                return;
            }
            var el = event.target;
            if ((event.key === 'Enter' || event.key === ' ') && el.matches && el.matches('.np-row, .np-sub')) {
                event.preventDefault();
                el.click();
                return;
            }
            if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
            var focusable = Array.prototype.filter.call(panel.querySelectorAll('a, button, .np-row, .np-sub'), function (n) { return !n.closest('[hidden]') && n.offsetParent !== null; });
            if (!focusable.length) return;
            var index = focusable.indexOf(document.activeElement);
            index += event.key === 'ArrowDown' ? 1 : -1;
            if (index < 0) index = focusable.length - 1;
            if (index >= focusable.length) index = 0;
            event.preventDefault();
            focusable[index].focus();
        });
    }

    function recargar() {
        if (recargando || typeof jQuery === 'undefined') return;

        var actual = parts();
        if (!actual) return;
        recargando = true;

        jQuery.ajax({
            type: 'GET',
            url: window.location.pathname + window.location.search,
            cache: false,
            success: function (html) {
                var pagina = new DOMParser().parseFromString(html, 'text/html');
                var nuevoPanel = pagina.querySelector('[data-sg-notif-panel]');
                var nuevaCampana = pagina.querySelector('.sigma-notification');

                if (nuevoPanel) {
                    actual.panel.innerHTML = nuevoPanel.innerHTML;

                    /* El panel llega del servidor sin filtrar: el filtro es
                       del cliente, asi que se vuelve a aplicar sobre lo que
                       acaba de entrar. Sin esto, una alerta nueva reventaba
                       el filtro puesto. */
                    aplicarFiltro(actual.panel);
                    encenderIconos(actual.panel);
                }

                /* El trigger conserva los listeners de Bootstrap: solo se
                   reconcilian las clases, el rótulo y el badge. */
                if (nuevaCampana && actual.trigger) {
                    actual.trigger.className = nuevaCampana.className;
                    actual.trigger.setAttribute('aria-label',
                        nuevaCampana.getAttribute('aria-label') || 'Alertas');

                    var viejoBadge = actual.trigger.querySelector('.sigma-notification__count');
                    var nuevoBadge = nuevaCampana.querySelector('.sigma-notification__count');

                    if (nuevoBadge) {
                        if (!viejoBadge) {
                            viejoBadge = document.createElement('span');
                            viejoBadge.className = 'sigma-notification__count';
                            viejoBadge.setAttribute('aria-hidden', 'true');
                            actual.trigger.appendChild(viejoBadge);
                        }
                        viejoBadge.textContent = nuevoBadge.textContent;
                    }
                    else if (viejoBadge && viejoBadge.parentNode) {
                        viejoBadge.parentNode.removeChild(viejoBadge);
                    }
                }

                recargando = false;
            },
            error: function () { recargando = false; }
        });
    }

    document.addEventListener('sigma:alertas-actualizadas', recargar);

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
})(window, document);
