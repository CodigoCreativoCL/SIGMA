(function (window, document) {
    'use strict';

    function init() {
        var root = document.querySelector('.sg-grupo-modal');
        if (!root) return;

        var tab = root.querySelector('.RadTabStrip');
        if (tab) tab.setAttribute('aria-label', 'Secciones del grupo de trabajo');

        var search = root.querySelector('.sg-grupo-search input');
        if (search) search.setAttribute('aria-label', 'Buscar integrantes por nombre, identificador o especialidad');
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();

    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(init);
})(window, document);
