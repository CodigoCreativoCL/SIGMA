(function (window, document) {
    'use strict';

    var restoreOpen = false;
    var hooked = false;

    function parts() {
        var panel = document.querySelector('[data-sg-notif-panel]');
        if (!panel) return null;
        return {
            panel: panel,
            parent: panel.closest ? panel.closest('.dropdown') : panel.parentNode,
            trigger: panel.parentNode.querySelector('[data-toggle="dropdown"]')
        };
    }

    function openPanel(p) {
        if (!p) return;
        p.parent.classList.add('show');
        p.panel.classList.add('show');
        p.trigger.setAttribute('aria-expanded', 'true');
    }

    function closePanel(p) {
        if (!p) return;
        p.parent.classList.remove('show');
        p.panel.classList.remove('show');
        p.trigger.setAttribute('aria-expanded', 'false');
        p.trigger.focus();
    }

    function init() {
        var p = parts();
        if (!p || p.panel.getAttribute('data-sg-ready') === '1') return;
        p.panel.setAttribute('data-sg-ready', '1');

        p.panel.addEventListener('click', function (event) {
            var item = event.target.closest && event.target.closest('[data-sg-notif-close]');
            if (item) {
                restoreOpen = false;
                return;
            }
            event.stopPropagation();
        });

        p.panel.addEventListener('keydown', function (event) {
            if (event.key === 'Escape' || event.keyCode === 27) {
                event.preventDefault();
                closePanel(p);
                return;
            }
            if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
            var focusable = p.panel.querySelectorAll('a:not([hidden]), button:not([hidden])');
            if (!focusable.length) return;
            var index = Array.prototype.indexOf.call(focusable, document.activeElement);
            index += event.key === 'ArrowDown' ? 1 : -1;
            if (index < 0) index = focusable.length - 1;
            if (index >= focusable.length) index = 0;
            event.preventDefault();
            focusable[index].focus();
        });
    }

    function hookAjax() {
        if (hooked || !window.Sys || !Sys.WebForms || !Sys.WebForms.PageRequestManager) return;
        hooked = true;
        var manager = Sys.WebForms.PageRequestManager.getInstance();
        manager.add_beginRequest(function (sender, args) {
            var source = args.get_postBackElement ? args.get_postBackElement() : null;
            var panel = document.querySelector('[data-sg-notif-panel]');
            restoreOpen = !!(source && panel && panel.contains(source) &&
                             !(source.closest && source.closest('[data-sg-notif-close]')));
        });
        manager.add_endRequest(function () {
            init();
            if (restoreOpen) window.setTimeout(function () { openPanel(parts()); }, 0);
            restoreOpen = false;
        });
    }

    function boot() { init(); hookAjax(); }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
})(window, document);
