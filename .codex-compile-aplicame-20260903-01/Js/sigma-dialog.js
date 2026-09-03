(function (window, document) {
    'use strict';

    if (window.SigmaModal) return;

    var root;
    var surface;
    var frame;
    var titleNode;
    var lastFocus;
    var current;
    var resizeObserver;
    var mutationObserver;
    var measureTimer;
    var closeTimer;
    var measuring = false;
    var modalTimeline;
    var dragState;
    var instances = [];
    var instanceSequence = 0;

    function number(value, fallback) {
        var result = parseInt(value, 10);
        return isNaN(result) ? fallback : result;
    }

    function clamp(value, min, max) {
        return Math.min(Math.max(value, min), max);
    }

    function escapeText(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function ensure() {
        if (root) return root;

        root = document.createElement('div');
        instanceSequence += 1;
        root.id = 'sigmaDialog_' + instanceSequence;
        root.className = 'sigma-dialog';
        root.hidden = true;
        var titleId = 'sigmaDialogTitle_' + instanceSequence;
        root.innerHTML =
            '<button type="button" class="sigma-dialog__backdrop" data-sigma-dialog-close aria-label="Cerrar ventana"></button>' +
            '<section class="sigma-dialog__surface" role="dialog" aria-modal="true" aria-labelledby="' + titleId + '">' +
                '<header class="sigma-dialog__bar">' +
                    '<div class="sigma-dialog__identity">' +
                        '<span class="sigma-dialog__mark" aria-hidden="true"></span>' +
                        '<span class="sigma-dialog__heading">' +
                            '<span class="sigma-dialog__eyebrow">SIGMA · FICHA</span>' +
                            '<span class="sigma-dialog__title-line">' +
                                '<strong class="sigma-dialog__title" id="' + titleId + '">Detalle</strong>' +
                                '<small class="sigma-dialog__record-id" hidden></small>' +
                            '</span>' +
                        '</span>' +
                    '</div>' +
                    '<span class="sigma-dialog__controls">' +
                        '<button type="button" data-sigma-dialog-action="minimize" aria-label="Minimizar" title="Minimizar">' +
                            '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 17.5h12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>' +
                        '</button>' +
                        '<button type="button" data-sigma-dialog-action="maximize" aria-label="Maximizar" title="Maximizar">' +
                            '<svg class="is-maximize" viewBox="0 0 24 24" aria-hidden="true"><rect x="6.5" y="6.5" width="11" height="11" rx="1.3" fill="none" stroke="currentColor" stroke-width="1.7"/></svg>' +
                            '<svg class="is-restore" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 8V6.8A1.8 1.8 0 0 1 10.8 5h6.4A1.8 1.8 0 0 1 19 6.8v6.4a1.8 1.8 0 0 1-1.8 1.8H16M6.8 9h6.4a1.8 1.8 0 0 1 1.8 1.8v6.4a1.8 1.8 0 0 1-1.8 1.8H6.8A1.8 1.8 0 0 1 5 17.2v-6.4A1.8 1.8 0 0 1 6.8 9Z" fill="none" stroke="currentColor" stroke-width="1.6"/></svg>' +
                        '</button>' +
                        '<button type="button" data-sigma-dialog-action="popout" aria-label="Abrir en otra ventana" title="Abrir en otra ventana">' +
                            '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M13 5h6v6m-.5-5.5L11 13m5 1v3a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h3" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>' +
                        '</button>' +
                        '<button type="button" class="sigma-dialog__close" data-sigma-dialog-action="close" aria-label="Cerrar" title="Cerrar">' +
                            '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6.4 6.4 11.2 11.2m0-11.2L6.4 17.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>' +
                        '</button>' +
                    '</span>' +
                '</header>' +
                '<div class="sigma-dialog__viewport">' +
                    '<div class="sigma-dialog__loading" aria-live="polite">' +
                        '<div class="sigma-dialog__skeleton" aria-hidden="true">' +
                            '<div class="sigma-dialog__sk-head"><i></i><span><b></b><b></b></span><em></em></div>' +
                            '<div class="sigma-dialog__sk-grid">' +
                                '<div class="sigma-dialog__sk-main">' +
                                    '<section><b></b><i></i><i></i><span><em></em><em></em><em></em></span></section>' +
                                    '<section><b></b><i></i><span><em></em><em></em></span><i></i></section>' +
                                '</div>' +
                                '<aside><b></b><i></i><i></i><i></i><em></em></aside>' +
                            '</div>' +
                        '</div>' +
                        '<div class="sigma-dialog__loading-brand" aria-label="Cargando ficha SIGMA">' +
                            '<span class="sigma-dialog__particle is-1"></span><span class="sigma-dialog__particle is-2"></span>' +
                            '<span class="sigma-dialog__particle is-3"></span><span class="sigma-dialog__particle is-4"></span>' +
                            '<span class="sigma-dialog__particle is-5"></span><span class="sigma-dialog__particle is-6"></span>' +
                            '<span class="sigma-dialog__particle is-7"></span><span class="sigma-dialog__particle is-8"></span>' +
                            '<span class="sigma-dialog__particle is-9"></span><span class="sigma-dialog__particle is-10"></span>' +
                            '<span class="sigma-dialog__particle is-11"></span><span class="sigma-dialog__particle is-12"></span>' +
                            '<span class="sigma-dialog__loader" aria-hidden="true"></span>' +
                        '</div>' +
                    '</div>' +
                    '<iframe class="sigma-dialog__frame" title="Contenido de la ficha"></iframe>' +
                '</div>' +
            '</section>';

        document.body.appendChild(root);
        surface = root.querySelector('.sigma-dialog__surface');
        frame = root.querySelector('.sigma-dialog__frame');
        titleNode = root.querySelector('.sigma-dialog__title');
        var instanceRoot = root;
        instances.push(instanceRoot);

        root.addEventListener('click', function (event) {
            var wasMinimized = instanceRoot.classList.contains('is-minimized');
            activateInstance(instanceRoot);
            var button = event.target.closest && event.target.closest('[data-sigma-dialog-action]');
            if (!button) {
                if (event.target.hasAttribute && event.target.hasAttribute('data-sigma-dialog-close')) {
                    close();
                    return;
                }
                if (wasMinimized) minimize();
                return;
            }
            var action = button.getAttribute('data-sigma-dialog-action');
            if (action === 'close') close();
            else if (action === 'minimize') minimize();
            else if (action === 'maximize') maximize();
            else if (action === 'popout') popout();
        });
        frame.addEventListener('load', function () {
            if (instanceRoot === root) loaded();
            else loadedInactive(instanceRoot);
        });
        root.querySelector('.sigma-dialog__bar').addEventListener('pointerdown', dragStart);
        return root;
    }

    function rememberInstance() {
        if (!root) return;
        root._sigmaDialogState = {
            surface: surface,
            frame: frame,
            titleNode: titleNode,
            lastFocus: lastFocus,
            current: current,
            resizeObserver: resizeObserver,
            mutationObserver: mutationObserver,
            measureTimer: measureTimer
        };
    }

    function releaseInstance() {
        rememberInstance();
        root = null;
        surface = null;
        frame = null;
        titleNode = null;
        lastFocus = null;
        current = null;
        resizeObserver = null;
        mutationObserver = null;
        measureTimer = null;
        modalTimeline = null;
    }

    function activateInstance(instanceRoot) {
        if (!instanceRoot || instanceRoot === root) return;

        if (root && !root.hidden && !root.classList.contains('is-minimized')) minimize(true);
        rememberInstance();

        var state = instanceRoot._sigmaDialogState;
        if (!state) return;
        document.body.appendChild(instanceRoot);
        root = instanceRoot;
        surface = state.surface;
        frame = state.frame;
        titleNode = state.titleNode;
        lastFocus = state.lastFocus;
        current = state.current;
        resizeObserver = state.resizeObserver || null;
        mutationObserver = state.mutationObserver || null;
        measureTimer = state.measureTimer || null;
        modalTimeline = null;
        root.style.zIndex = '2147482300';
        reindexMinimized();
    }

    function reindexMinimized() {
        var minimized = instances.filter(function (instance) {
            return instance && document.documentElement.contains(instance) && instance.classList.contains('is-minimized');
        });
        var cardWidth = Math.min(360, Math.max(280, window.innerWidth - 32));
        var columns = Math.max(1, Math.floor((window.innerWidth - 32) / (cardWidth + 10)));

        minimized.forEach(function (instance, index) {
            var column = index % columns;
            var row = Math.floor(index / columns);
            instance.style.setProperty('--sigma-dialog-dock-width', cardWidth + 'px');
            instance.style.setProperty('--sigma-dialog-dock-right', (16 + column * (cardWidth + 10)) + 'px');
            instance.style.setProperty('--sigma-dialog-dock-bottom', (16 + row * 64) + 'px');
            instance.style.zIndex = String(2147482000 + index);
        });
    }

    function syncDocumentLock() {
        var hasActive = instances.some(function (instance) {
            return instance && !instance.hidden &&
                !instance.classList.contains('is-minimized') &&
                !instance.classList.contains('is-closing');
        });
        document.documentElement.classList.toggle('sigma-dialog-locked', hasActive);
    }

    function normalise(urlOrOptions, options) {
        var result;

        if (typeof urlOrOptions === 'object') result = urlOrOptions || {};
        else {
            result = options || {};
            result.url = urlOrOptions;
        }

        var url = result.url || '';
        var recordId = result.recordId == null ? '' : String(result.recordId);
        var explicitRecordId = result.recordId != null;
        if (!recordId) {
            var match = /[?&]query=([^&#]*)/i.exec(url);
            if (match) {
                try { recordId = decodeURIComponent(match[1].replace(/\+/g, ' ')); }
                catch (ignore) { recordId = match[1]; }
            }
        }
        if (!explicitRecordId && recordId && !/^\d+$/.test(recordId)) {
            try {
                var decoded = window.atob(recordId);
                var decodedId = /(?:^|\b)id\s*[:=_-]?\s*(\d+)$/i.exec(decoded);
                recordId = decodedId ? decodedId[1] : '';
            } catch (ignoreDecode) { recordId = ''; }
        }
        if (recordId === '0') recordId = '';

        return {
            url: url,
            title: result.title || 'Detalle',
            recordId: recordId,
            width: number(result.width, 960),
            initialHeight: number(result.initialHeight || result.height, 520),
            minHeight: number(result.minHeight, 250),
            maxHeight: number(result.maxHeight, 0)
        };
    }

    function viewportFrameHeight() {
        var reserved = window.innerWidth <= 680 ? 52 : 54;
        var margin = window.innerWidth <= 680 ? 0 : clamp(Math.round(window.innerWidth * .022), 10, 28) * 2;
        return Math.max(220, window.innerHeight - reserved - margin);
    }

    function layoutInitial() {
        if (!current || !surface || !frame) return;
        if (root.classList.contains('is-maximized') || root.classList.contains('is-minimized')) return;
        var maxWidth = Math.max(320, window.innerWidth - (window.innerWidth <= 680 ? 0 : 20));
        surface.style.setProperty('--sigma-dialog-width', clamp(current.width, 320, maxWidth) + 'px');
        frame.style.height = clamp(current.initialHeight, current.minHeight, viewportFrameHeight()) + 'px';
    }

    function contentHeight() {
        try {
            var doc = frame.contentDocument;
            if (!doc) return 0;
            var html = doc.documentElement;
            var body = doc.body;
            return Math.max(
                html ? html.scrollHeight : 0,
                html ? html.offsetHeight : 0,
                body ? body.scrollHeight : 0,
                body ? body.offsetHeight : 0
            );
        } catch (ignore) {
            return 0;
        }
    }

    function measure() {
        if (!current || root.hidden || measuring || window.innerWidth <= 680 ||
            root.classList.contains('is-maximized') || root.classList.contains('is-minimized')) return;

        measuring = true;
        window.requestAnimationFrame(function () {
            var maximum = viewportFrameHeight();
            if (current.maxHeight > 0) maximum = Math.min(maximum, current.maxHeight);

            var wanted = contentHeight();
            if (!wanted) wanted = current.initialHeight;
            wanted = clamp(wanted + 2, current.minHeight, maximum);

            if (Math.abs(number(frame.style.height, 0) - wanted) > 1)
                frame.style.height = wanted + 'px';

            measuring = false;
        });
    }

    function clearObservers() {
        if (resizeObserver) resizeObserver.disconnect();
        if (mutationObserver) mutationObserver.disconnect();
        resizeObserver = null;
        mutationObserver = null;
        window.clearTimeout(measureTimer);
    }

    function observeCurrentFrame() {
        clearObservers();
        try {
            if (window.ResizeObserver && frame.contentDocument.body) {
                resizeObserver = new ResizeObserver(measure);
                resizeObserver.observe(frame.contentDocument.body);
            }

            if (window.MutationObserver && frame.contentDocument.body) {
                mutationObserver = new MutationObserver(measure);
                mutationObserver.observe(frame.contentDocument.body, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    characterData: false
                });
            }
            rememberInstance();
        } catch (ignore) { }
    }

    function compatibilityAdapter(ownerRoot) {
        function withOwner(action) {
            return function () {
                activateInstance(ownerRoot);
                return action.apply(null, arguments);
            };
        }

        return {
            BrowserWindow: window,
            close: withOwner(close),
            center: withOwner(layoutInitial),
            isVisible: function () { return !!ownerRoot && !ownerRoot.hidden; },
            get_contentFrame: function () { return ownerRoot._sigmaDialogState.frame; },
            get_contentFrameElement: function () { return ownerRoot._sigmaDialogState.frame; },
            setSize: withOwner(function (width, height) {
                if (!current) return;
                current.width = number(width, current.width);
                current.initialHeight = number(height, current.initialHeight);
                layoutInitial();
                measure();
            })
        };
    }

    function recordNameFromDocument(doc) {
        if (!doc) return '';
        var selectors = [
            '[data-sigma-record-name]',
            'input[id*="txtNombre"]',
            'input[id*="txtRazonSocial"]',
            'input[id*="txtNombreFantasia"]',
            'input[id*="txtNumero"]',
            'input[id*="txtFolio"]',
            'input[id*="txtDescripcion"]',
            'input[id*="txtCodigo"]'
        ];
        for (var i = 0; i < selectors.length; i++) {
            var preferred = doc.querySelector(selectors[i]);
            var value = preferred ? (preferred.value || preferred.textContent || '') : '';
            value = String(value).replace(/\s+/g, ' ').trim();
            if (value) return value;
        }

        var heading = doc.querySelector('.sg-prog-titulo, .sigma-modal-title, main h1, main h2');
        return heading ? String(heading.textContent || '').replace(/\s+/g, ' ').trim() : '';
    }

    function updateInstanceIdentity(ownerRoot, doc) {
        var state = ownerRoot && ownerRoot._sigmaDialogState;
        if (!state || !state.current) return;
        var recordName = recordNameFromDocument(doc);
        if (!recordName || recordName.toLowerCase() === String(state.current.title).toLowerCase()) return;

        state.current.recordName = recordName;
        var eyebrow = ownerRoot.querySelector('.sigma-dialog__eyebrow');
        if (eyebrow) eyebrow.textContent = 'SIGMA · ' + String(state.current.title).toUpperCase();
        state.titleNode.textContent = recordName;
        state.frame.title = recordName;
    }

    function wireFrame(ownerRoot) {
        var state = ownerRoot && ownerRoot._sigmaDialogState;
        if (!state || !state.frame || !state.current) return false;

        try {
            var ownerFrame = state.frame;
            var doc = ownerFrame.contentDocument;
            var adapter = compatibilityAdapter(ownerRoot);
            ownerFrame.radWindow = adapter;
            ownerFrame.contentWindow.radWindow = adapter;
            doc.documentElement.classList.add('sigma-dialog-child');
            updateInstanceIdentity(ownerRoot, doc);

            if (!doc._sigmaDialogWired) {
                doc._sigmaDialogWired = true;
                doc.addEventListener('keydown', function (event) {
                    if (event.key === 'Escape' || event.keyCode === 27) {
                        activateInstance(ownerRoot);
                        close();
                    }
                });
                doc.addEventListener('input', function () {
                    updateInstanceIdentity(ownerRoot, doc);
                });
                doc.addEventListener('change', function () {
                    updateInstanceIdentity(ownerRoot, doc);
                });
            }
            return true;
        } catch (ignore) {
            return false;
        }
    }

    function loadedInactive(instanceRoot) {
        var state = instanceRoot && instanceRoot._sigmaDialogState;
        if (!state || !state.current || !state.frame || state.frame.src === 'about:blank') return;
        wireFrame(instanceRoot);
        instanceRoot.classList.add('is-ready');

        var loading = instanceRoot.querySelector('.sigma-dialog__loading');
        var particles = instanceRoot.querySelectorAll('.sigma-dialog__particle');
        if (window.gsap) {
            gsap.killTweensOf(particles);
            gsap.set([loading, state.frame], { clearProps: 'opacity,visibility,transform' });
        }
    }

    function loaded() {
        if (!current || !frame.src || frame.src === 'about:blank') return;

        var ownerRoot = root;
        var chromeItems = root.querySelectorAll('.sigma-dialog__identity, .sigma-dialog__controls');

        /* La carga puede terminar mientras sigue el tween de entrada. Si GSAP
           sobrescribe ese tween para revelar el iframe, no debe dejar el
           chrome con el estado inicial opacity:0. */
        if (window.gsap) gsap.set(chromeItems, { clearProps: 'opacity,visibility,transform' });

        if (wireFrame(ownerRoot)) observeCurrentFrame();
        else {
            /* Una URL externa sigue abriendo; solo pierde auto-medicion y el
               adaptador WebForms, que requieren mismo origen. */
        }

        var loading = root.querySelector('.sigma-dialog__loading');
        var particles = root.querySelectorAll('.sigma-dialog__particle');

        if (window.gsap) {
            gsap.killTweensOf(particles);
            gsap.timeline({
                onComplete: function () {
                    ownerRoot.classList.add('is-ready');
                    gsap.set([loading, ownerRoot._sigmaDialogState.frame], { clearProps: 'opacity,visibility' });
                }
            })
                .to(loading, { opacity: 0, duration: .28, ease: 'power2.out' }, 0)
                .fromTo(frame, { opacity: 0, scale: .996 }, {
                    opacity: 1,
                    scale: 1,
                    duration: .42,
                    ease: 'power2.out',
                    clearProps: 'transform'
                }, .08);
        } else root.classList.add('is-ready');

        measure();
        window.setTimeout(measure, 80);
        window.setTimeout(measure, 350);
        measureTimer = window.setTimeout(measure, 900);
    }

    function open(urlOrOptions, options) {
        if (root && !root.hidden) {
            if (!root.classList.contains('is-minimized')) minimize(true);
            releaseInstance();
        }
        ensure();
        clearObservers();
        window.clearTimeout(closeTimer);

        current = normalise(urlOrOptions, options);
        if (!current.url) return false;

        lastFocus = document.activeElement;
        root.classList.remove('is-maximized', 'is-minimized', 'is-closing', 'is-dragging');
        surface.style.removeProperty('transform');
        surface.removeAttribute('data-sigma-x');
        surface.removeAttribute('data-sigma-y');
        titleNode.innerHTML = escapeText(current.title);
        var recordNode = root.querySelector('.sigma-dialog__record-id');
        if (recordNode) {
            recordNode.hidden = !current.recordId;
            recordNode.textContent = current.recordId ? 'ID ' + current.recordId : '';
        }
        root.classList.remove('is-ready');
        root.hidden = false;
        document.documentElement.classList.add('sigma-dialog-locked');
        layoutInitial();

        frame.title = current.title;
        rememberInstance();
        frame.src = current.url;
        var openingRoot = root;
        var openingSurface = surface;

        window.requestAnimationFrame(function () {
            if (!document.documentElement.contains(openingRoot)) return;
            openingRoot.classList.add('is-open');
            var backdrop = openingRoot.querySelector('.sigma-dialog__backdrop');
            var barItems = openingRoot.querySelectorAll('.sigma-dialog__identity, .sigma-dialog__controls');
            var loader = openingRoot.querySelector('.sigma-dialog__loader');
            var particles = openingRoot.querySelectorAll('.sigma-dialog__particle');

            if (window.gsap) {
                if (modalTimeline) modalTimeline.kill();
                gsap.killTweensOf([backdrop, openingSurface, barItems, loader, particles]);
                gsap.set([backdrop, openingSurface], { transition: 'none' });

                modalTimeline = gsap.timeline({
                    defaults: { overwrite: 'auto' },
                    onComplete: function () {
                        gsap.set([backdrop, openingSurface], { clearProps: 'transition,opacity,transform' });
                    }
                });
                modalTimeline
                    .fromTo(backdrop, { opacity: 0 }, { opacity: 1, duration: .30, ease: 'power2.out' }, 0)
                    .fromTo(openingSurface, { opacity: 0, y: 30, scale: .965, rotateX: -2 }, {
                        opacity: 1,
                        y: 0,
                        scale: 1,
                        rotateX: 0,
                        duration: .62,
                        ease: 'power4.out'
                    }, .03)
                    .fromTo(barItems, { opacity: 0, y: -8 }, {
                        opacity: 1,
                        y: 0,
                        duration: .38,
                        stagger: .06,
                        ease: 'power3.out'
                    }, .22)
                    .fromTo(loader, { opacity: 0, scale: .72, rotate: -12 }, {
                        opacity: 1,
                        scale: 1,
                        rotate: 0,
                        duration: .58,
                        ease: 'back.out(1.7)'
                    }, .20);

                Array.prototype.forEach.call(particles, function (particle, index) {
                    var directions = [
                        [-28, -72], [-18, -90], [-8, -64], [5, -98], [17, -76], [29, -88],
                        [-34, -56], [-22, -105], [10, -68], [24, -108], [36, -62], [2, -118]
                    ];
                    var direction = directions[index % directions.length];
                    gsap.fromTo(particle,
                        { opacity: 0, x: 0, y: 8, scale: .35 },
                        {
                            opacity: 0,
                            x: direction[0],
                            y: direction[1],
                            scale: .92 + (index % 3) * .18,
                            duration: .82 + (index % 5) * .13,
                            delay: .10 + index * .075,
                            repeat: -1,
                            repeatDelay: .05 + (index % 4) * .04,
                            ease: 'power2.out',
                            keyframes: [
                                { opacity: .95, duration: .16 },
                                { opacity: .58, duration: .36 },
                                { opacity: 0, duration: .30 }
                            ]
                        });
                });
            }

            var closeButton = openingRoot.querySelector('.sigma-dialog__close');
            if (closeButton) closeButton.focus();
        });

        return false;
    }

    function finishClose(closingRoot, closingFrame, focusTarget) {
        if (!closingRoot) return;
        closingRoot.classList.remove('is-open', 'is-ready', 'is-closing');
        closingRoot.hidden = true;
        closingFrame.src = 'about:blank';
        instances = instances.filter(function (instance) { return instance !== closingRoot; });
        if (closingRoot.parentNode) closingRoot.parentNode.removeChild(closingRoot);

        if (root === closingRoot) {
            root = null;
            surface = null;
            frame = null;
            titleNode = null;
            lastFocus = null;
            current = null;
            resizeObserver = null;
            mutationObserver = null;
            measureTimer = null;
            modalTimeline = null;
        }
        reindexMinimized();
        syncDocumentLock();
        if (focusTarget && focusTarget.focus) focusTarget.focus();

        var event;
        if (typeof window.CustomEvent === 'function') event = new CustomEvent('sigma:modalclosed');
        else {
            event = document.createEvent('Event');
            event.initEvent('sigma:modalclosed', true, true);
        }
        document.dispatchEvent(event);
    }

    function close() {
        if (!root || root.hidden || root.classList.contains('is-closing')) return false;

        clearObservers();
        var closingRoot = root;
        var closingSurface = surface;
        var closingFrame = frame;
        var focusTarget = lastFocus;
        var closingBackdrop = closingRoot.querySelector('.sigma-dialog__backdrop');
        closingRoot.classList.add('is-closing');
        current = null;
        rememberInstance();
        syncDocumentLock();

        function done() {
            if (window.gsap) gsap.set([closingSurface, closingBackdrop], { clearProps: 'opacity,transform,transition' });
            finishClose(closingRoot, closingFrame, focusTarget);
        }

        if (window.gsap) {
            if (modalTimeline) modalTimeline.kill();
            var inner = closingRoot.querySelectorAll('.sigma-dialog__frame');
            gsap.killTweensOf([closingBackdrop, closingSurface, inner]);
            gsap.set([closingBackdrop, closingSurface], { transition: 'none' });
            modalTimeline = gsap.timeline({ onComplete: done });
            modalTimeline
                .to(inner, { opacity: 0, y: -5, duration: .16, stagger: .025, ease: 'power2.in' }, 0)
                .to(closingSurface, { opacity: 0, y: 24, scale: .975, duration: .34, ease: 'power3.in' }, .06)
                .to(closingBackdrop, { opacity: 0, duration: .28, ease: 'power2.inOut' }, .10);
        } else closeTimer = window.setTimeout(done, 190);

        return false;
    }

    function minimize(forceMinimize) {
        if (!current || root.hidden) return false;

        var wasMinimized = root.classList.contains('is-minimized');
        var willMinimize = forceMinimize === true || !wasMinimized;
        if (forceMinimize === true && wasMinimized) {
            rememberInstance();
            reindexMinimized();
            return false;
        }

        if (willMinimize) clearObservers();
        root.classList.toggle('is-minimized', willMinimize);
        root.classList.remove('is-maximized');
        surface.style.removeProperty('transform');
        root.style.zIndex = willMinimize ? '' : '2147482300';
        syncDocumentLock();

        var button = root.querySelector('[data-sigma-dialog-action="minimize"]');
        if (button) {
            button.setAttribute('aria-label', willMinimize ? 'Restaurar' : 'Minimizar');
            button.setAttribute('title', willMinimize ? 'Restaurar' : 'Minimizar');
        }

        if (window.gsap) {
            gsap.killTweensOf(surface);
            gsap.fromTo(surface,
                { opacity: willMinimize ? .35 : 1, y: willMinimize ? 24 : 8, scale: willMinimize ? .94 : .985 },
                {
                    opacity: 1,
                    y: 0,
                    scale: 1,
                    duration: willMinimize ? .36 : .24,
                    ease: 'power3.out',
                    clearProps: 'opacity,transform'
                });
        }

        if (!willMinimize) {
            layoutInitial();
            if (root.classList.contains('is-ready')) {
                observeCurrentFrame();
                measure();
            } else {
                try {
                    if (frame.contentDocument && frame.contentDocument.readyState === 'complete') loaded();
                } catch (ignore) { }
            }
        }
        rememberInstance();
        reindexMinimized();
        return false;
    }

    function maximize() {
        if (!current || root.hidden || window.innerWidth <= 680) return false;

        if (root.classList.contains('is-minimized')) minimize();
        var maximized = !root.classList.contains('is-maximized');
        root.classList.toggle('is-maximized', maximized);
        surface.style.removeProperty('transform');

        var button = root.querySelector('[data-sigma-dialog-action="maximize"]');
        if (button) {
            button.setAttribute('aria-label', maximized ? 'Restaurar tamaño' : 'Maximizar');
            button.setAttribute('title', maximized ? 'Restaurar tamaño' : 'Maximizar');
        }

        if (!maximized) {
            layoutInitial();
            measure();
        }

        if (window.gsap) {
            gsap.killTweensOf(surface);
            gsap.fromTo(surface, { opacity: .72, scale: maximized ? .975 : 1.018 }, {
                opacity: 1,
                scale: 1,
                duration: .40,
                ease: 'power3.out',
                clearProps: 'opacity,transform'
            });
        }
        return false;
    }

    function popout() {
        if (!current || !current.url) return false;

        var settings = current;
        var width = clamp(current.width, 620, Math.max(620, window.screen.availWidth - 80));
        var height = clamp(current.initialHeight + 54, 480, Math.max(480, window.screen.availHeight - 80));
        var features = 'popup=yes,resizable=yes,scrollbars=no,toolbar=no,menubar=no,location=no,status=no,width=' + width + ',height=' + height;
        var external = window.open('about:blank', 'SigmaFicha_' + new Date().getTime(), features);

        if (external) {
            try {
                buildPopout(external, settings);
            } catch (ignore) { }
            close();
        }
        return false;
    }

    function applicationRoot() {
        var scripts = document.getElementsByTagName('script');
        for (var i = scripts.length - 1; i >= 0; i--) {
            var src = scripts[i].src || '';
            var marker = src.toLowerCase().indexOf('/js/sigma-dialog.js');
            if (marker >= 0) return src.substring(0, marker + 1);
        }
        return new URL('./', window.location.href).href;
    }

    function buildPopout(external, settings) {
        var doc = external.document;
        var base = applicationRoot();
        doc.open();
        doc.write('<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title></title></head><body></body></html>');
        doc.close();
        doc.title = settings.title + ' · SIGMA';

        var style = doc.createElement('style');
        style.textContent =
            '*{box-sizing:border-box}html,body{height:100%;margin:0;overflow:hidden;background:#fff;font-family:Inter,Segoe UI,Arial,sans-serif}' +
            'body{display:flex;flex-direction:column}' +
            '.sp-bar{height:56px;flex:0 0 56px;display:flex;align-items:center;justify-content:space-between;gap:16px;padding:0 12px 0 17px;border-bottom:1px solid #e7eaf1;background:linear-gradient(90deg,#f4f1ff 0,#f9feff 48%,#fff 82%);user-select:none}' +
            '.sp-id{min-width:0;display:flex;align-items:center;gap:11px}.sp-logo{width:29px;height:34px;object-fit:contain;filter:drop-shadow(0 5px 8px rgba(83,50,229,.2))}' +
            '.sp-copy{min-width:0;display:grid;gap:2px}.sp-copy small{color:#7867e9;font-size:9px;font-weight:800;letter-spacing:.13em}.sp-copy strong{max-width:70vw;overflow:hidden;color:#11182d;font-size:13px;text-overflow:ellipsis;white-space:nowrap}' +
            '.sp-close{width:36px;height:36px;display:grid;place-items:center;border:1px solid transparent;border-radius:11px;background:transparent;color:#526078;cursor:pointer}.sp-close:hover{border-color:#ded9ff;background:#f5f3ff;color:#4d31df}.sp-close svg{width:19px}' +
            '.sp-main{position:relative;min-height:0;flex:1}.sp-frame{display:block;width:100%;height:100%;border:0;background:#fff;opacity:0;transition:opacity .24s ease}' +
            '.sp-main.is-ready .sp-frame{opacity:1}.sp-loading{position:absolute;inset:0;display:grid;place-items:center;background:linear-gradient(145deg,#fbfbff,#f6f4ff);transition:opacity .22s ease}' +
            '.sp-main.is-ready .sp-loading{opacity:0;pointer-events:none}.sp-loading img{width:58px;height:67px;object-fit:contain;filter:drop-shadow(0 12px 17px rgba(69,43,203,.25));animation:sp-pulse 1.35s ease-in-out infinite}' +
            '@keyframes sp-pulse{50%{transform:translateY(-5px) scale(1.035)}}';
        doc.head.appendChild(style);

        var bar = doc.createElement('header');
        bar.className = 'sp-bar';
        var identity = doc.createElement('div');
        identity.className = 'sp-id';
        var logo = doc.createElement('img');
        logo.className = 'sp-logo';
        logo.src = base + 'Imagen/sigma-isotipo-gradient.svg';
        logo.alt = 'SIGMA';
        var copy = doc.createElement('span');
        copy.className = 'sp-copy';
        var eyebrow = doc.createElement('small');
        eyebrow.textContent = 'SIGMA · VENTANA DE TRABAJO';
        var heading = doc.createElement('strong');
        heading.textContent = settings.title;
        copy.appendChild(eyebrow);
        copy.appendChild(heading);
        identity.appendChild(logo);
        identity.appendChild(copy);

        var closeButton = doc.createElement('button');
        closeButton.type = 'button';
        closeButton.className = 'sp-close';
        closeButton.setAttribute('aria-label', 'Cerrar ventana');
        closeButton.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6.4 6.4 11.2 11.2m0-11.2L6.4 17.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>';
        closeButton.onclick = function () { external.close(); };
        bar.appendChild(identity);
        bar.appendChild(closeButton);

        var main = doc.createElement('main');
        main.className = 'sp-main';
        var loading = doc.createElement('div');
        loading.className = 'sp-loading';
        var loadingLogo = doc.createElement('img');
        loadingLogo.src = base + 'Imagen/sigma-isotipo-gradient.svg';
        loadingLogo.alt = '';
        loading.appendChild(loadingLogo);

        var contentFrame = doc.createElement('iframe');
        contentFrame.className = 'sp-frame';
        contentFrame.title = settings.title;
        var adapter = {
            BrowserWindow: window,
            close: function () { external.close(); },
            isVisible: function () { return !external.closed; },
            get_contentFrame: function () { return contentFrame; },
            get_contentFrameElement: function () { return contentFrame; }
        };
        contentFrame.radWindow = adapter;
        contentFrame.onload = function () {
            try {
                contentFrame.contentWindow.radWindow = adapter;
                contentFrame.contentDocument.documentElement.classList.add('sigma-dialog-child');
            } catch (ignore) { }
            main.classList.add('is-ready');
        };
        main.appendChild(loading);
        main.appendChild(contentFrame);
        doc.body.appendChild(bar);
        doc.body.appendChild(main);
        contentFrame.src = settings.url;
    }

    function dragStart(event) {
        if (!current || root.hidden || window.innerWidth <= 680 ||
            root.classList.contains('is-maximized') || root.classList.contains('is-minimized') ||
            (event.target.closest && event.target.closest('button'))) return;

        var x = number(surface.getAttribute('data-sigma-x'), 0);
        var y = number(surface.getAttribute('data-sigma-y'), 0);
        dragState = { startX: event.clientX, startY: event.clientY, x: x, y: y, pointerId: event.pointerId };
        root.classList.add('is-dragging');
        if (event.currentTarget.setPointerCapture) event.currentTarget.setPointerCapture(event.pointerId);
        event.preventDefault();
    }

    function dragMove(event) {
        if (!dragState || event.pointerId !== dragState.pointerId) return;

        var box = surface.getBoundingClientRect();
        var dx = dragState.x + event.clientX - dragState.startX;
        var dy = dragState.y + event.clientY - dragState.startY;
        var limitX = Math.max(0, (window.innerWidth - Math.min(box.width, window.innerWidth)) / 2 - 8);
        var limitY = Math.max(0, (window.innerHeight - Math.min(box.height, window.innerHeight)) / 2 - 8);
        dx = clamp(dx, -limitX, limitX);
        dy = clamp(dy, -limitY, limitY);

        surface.setAttribute('data-sigma-x', Math.round(dx));
        surface.setAttribute('data-sigma-y', Math.round(dy));
        if (window.gsap) gsap.set(surface, { x: dx, y: dy });
        else surface.style.transform = 'translate(' + dx + 'px,' + dy + 'px)';
    }

    function dragEnd(event) {
        if (!dragState || (event && event.pointerId !== dragState.pointerId)) return;
        dragState = null;
        if (root) root.classList.remove('is-dragging');
    }

    function keydown(event) {
        if (!root || root.hidden) return;

        if (event.key === 'Escape' || event.keyCode === 27) {
            event.preventDefault();
            close();
            return;
        }

        if ((event.key === 'Tab' || event.keyCode === 9) && document.activeElement !== frame) {
            var closeButton = root.querySelector('.sigma-dialog__close');
            if (closeButton) {
                event.preventDefault();
                closeButton.focus();
            }
        }
    }

    document.addEventListener('keydown', keydown);
    document.addEventListener('pointermove', dragMove);
    document.addEventListener('pointerup', dragEnd);
    document.addEventListener('pointercancel', dragEnd);
    window.addEventListener('resize', function () {
        reindexMinimized();
        layoutInitial();
        measure();
    });

    window.SigmaModal = {
        open: open,
        close: close,
        minimize: minimize,
        maximize: maximize,
        resize: measure,
        isOpen: function () {
            return instances.some(function (instance) { return instance && !instance.hidden; });
        }
    };
})(window, document);
