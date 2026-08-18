    // dentro de la ventana.
    function dclOnbPosicionarPop(pop, r) {
        var pw = pop.offsetWidth  || 340;
        var ph = pop.offsetHeight || 200;
        var m  = 14;
         
        var top = r.bottom + m;
        if (top + ph > window.innerHeight - 10) {
            top = r.top - ph - m;
            if (top < 10) top = Math.max(10, (window.innerHeight - ph) / 2);
        }
        var left = r.left + (r.width / 2) - (pw / 2);
        if (left < 10) left = 10;
        if (left + pw > window.innerWidth - 10) left = window.innerWidth - pw - 10;

        pop.style.top  = top + 'px';
        pop.style.left = left + 'px';
    }

    function dclOnboardingEnd() {
        dclOnbMarcarVisto();
        dclOnbDemoParar();
        var ov = document.getElementById('dcl-onb');
        document.removeEventListener('keydown', _dclOnbTeclas);
        document.body.classList.remove('dcl-onb-activo');
        if (!ov) return;
        ov.classList.remove('dcl-onb--open');
        setTimeout(function () { if (ov.parentNode) ov.parentNode.removeChild(ov); }, 240);
    }

    // ── Restablecer configuración ─────────────────────────────────────────
    // Deja el dashboard como viene de fábrica: borra layouts guardados, la
    // estructura de los TRES niveles, la meta y el intervalo de auto-refresh,
    // tanto en el navegador como en la BD del usuario. El tema claro/oscuro NO
    // se toca: es una preferencia de visualización, no configuración del
    // dashboard, y resetearlo sería un efecto sorpresa.
    function dclResetConfiguracion() {
        dclSwalConfirm({
            title: 'Restablecer configuración',
            text: 'Se eliminarán tus layouts guardados y volverá todo al layout por ' +
                  'defecto del sistema en General, Por Instalación y Por Zona. También se ' +
                  'restablecen la meta de cumplimiento y la frecuencia de actualización. ' +
                  'Esta acción no se puede deshacer.',
            confirmText: 'Sí, restablecer'
        }, function () {
            // 1. Local: todas las claves del dashboard salvo el tema.
            try {
                var borrar = [];
                for (var i = 0; i < localStorage.length; i++) {
                    var k = localStorage.key(i);
                    // Se preservan el tema (preferencia visual) y la marca del
                    // tutorial: restablecer el layout no es motivo para volver a
                    // mostrarle el onboarding a quien ya lo vio o lo saltó.
                    if (k && k.indexOf('dcl_') === 0 && k !== 'dcl_theme' && k !== _DCL_ONB_KEY) borrar.push(k);
                }
                for (var j = 0; j < borrar.length; j++) localStorage.removeItem(borrar[j]);
            } catch (e) { }

            try {
                sessionStorage.removeItem('dcl_dflt_applied');
                sessionStorage.removeItem('dcl_srv_loaded');
            } catch (e) { }

            // 2. Servidor: la config persistida de los tres niveles.
            dclBorrarCfgServidor(['checklists_general', 'checklists_instalacion', 'checklists_zona']);

            // 3. Reconstruir el estado por defecto y repintar.
            //    dclGetRefreshMs() ya devuelve el valor de fábrica: su clave se borró.
            _dclRefreshMs = dclGetRefreshMs();
            dclEnsureSystemLayout();
            dclSaveCfg(dclDefaultCfg());
            dclSetActiveLayoutName('Por defecto del sistema');
            dclApplySectionState();
            dclUpdateRefreshBtnUI();
            dclMetaInputSync();
            dclStartAutoRefresh();
            dclRenderActiveLayoutName();
            dclSwalToast('Configuración restablecida', 'success');
            dclAutoRefreshAjax(true);
        });
    }

    function dclBorrarCfgServidor(modulos) {
        if (typeof _dclWsBase === 'undefined') return;
        for (var i = 0; i < modulos.length; i++) {
            try {
                var xhr = new XMLHttpRequest();
                xhr.open('POST', _dclWsBase + '/DeleteConfig', true);
                xhr.setRequestHeader('Content-Type', 'application/json');
                xhr.send(JSON.stringify({ module: modulos[i] }));
            } catch (e) { }
        }
    }

    // Crea un layout NUEVO y entra al builder con el canvas EN BLANCO.
    // Antes partía del default del sistema: el usuario tenía que borrar widgets
    // uno por uno para poder armar el suyo desde cero.
    function dclNewLayout() {
        dclSwalPrompt({
            title: 'Nuevo layout',
            placeholder: 'Nombre del nuevo layout',
            value: 'Nuevo layout ' + new Date().toLocaleDateString('es-CL'),
            confirmText: 'Crear'
        }, function (name) {
            var saved = dclGetSavedLayouts();
            var base = { rows: [], sectionHeights: {} };   // lienzo vacío
            var nuevoId = 'cfg_' + Date.now();
            saved.push({
                id: nuevoId, name: name, cfg: base,
                nivel: dclNivelActual(),   // categoría a la que queda asociado
                date: new Date().toISOString(), isDefault: false
            });
            dclSetSavedLayouts(saved);
            dclSaveCfg(base);
            dclSetActiveLayoutName(name);
            dclApplySectionState();
            dclCloseLayoutsPanel();
            // Se pasa el id: lo que se arme queda guardado EN ese layout y no
            // solo como cfg activo (antes quedaba con rows vacío).
            setTimeout(function () { dclEnterBuilderMode(true, nuevoId); }, 80);
        });
    }

    function dclRenameSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id === id) {
                if (saved[i].isSystem) { dclSwalToast('El layout del sistema no se puede renombrar', 'info'); return; }
                (function (idx) {
                    dclSwalPrompt({
                        title: 'Renombrar layout',
                        value: saved[idx].name || '',
                        confirmText: 'Renombrar'
                    }, function (nn) {
                        var s2 = dclGetSavedLayouts();
                        if (s2[idx]) { s2[idx].name = nn; dclSetSavedLayouts(s2); }
                        dclOpenLayoutsPanel();
                    });
                })(i);
                return;
            }
        }
    }

    function dclLoadSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id === id) {
                // Para el layout del sistema, usar la variante de la vista actual
                var src = dclLayoutCfgForView(saved[i]) || saved[i].cfg || {};
                var clone = JSON.parse(JSON.stringify(src));
                // Conservar las preferencias de altura/título/header del cfg actual
                var cur = dclGetCfg();
                if (cur.sectionHeights && !clone.sectionHeights) clone.sectionHeights = cur.sectionHeights;
                if (cur.sectionHeightsPx) clone.sectionHeightsPx = cur.sectionHeightsPx;
                if (cur.sectionTitles) clone.sectionTitles = cur.sectionTitles;
                if (cur.sectionHiddenHd) clone.sectionHiddenHd = cur.sectionHiddenHd;
                // Debe marcarse con el NIVEL (incluido 'zona'): si no,
                // dclReconcileVistaLayout lo ve como de otra vista y descarta el
                // layout que el usuario acaba de aplicar.
                clone._vista = dclNivelActual();
                dclSaveCfg(clone);
                dclSetActiveLayoutName(saved[i].name || '');
                dclCloseLayoutsPanel();
                // Reaplicar tras cerrar el panel (asegura DOM estable y un solo render)
                setTimeout(function () {
                    dclApplySectionState();
                    dclInitSectionDnD();
                }, 0);
                return;
            }
        }
    }

    // Editar un layout guardado: lo aplica y abre "Armar Dashboard" sobre él,
    // para no obligar a "Aplicar" y después buscar el botón del builder aparte.
    // Se entra SIN el flag enBlanco: el builder debe arrancar con las filas del
    // layout, que es justamente lo que se va a editar.
    function dclEditSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id !== id) continue;

            // El layout del sistema es de solo lectura: editarlo lo pisaría para
            // todos los niveles. En vez de bloquear, se duplica y se edita la
            // copia — el usuario igual termina donde quería ir.
            if (saved[i].isSystem) {
                var copia = {
                    id      : 'cfg_' + Date.now(),
                    name    : 'Mi dashboard',
                    cfg     : JSON.parse(JSON.stringify(dclLayoutCfgForView(saved[i]) || saved[i].cfg || {})),
                    nivel   : dclNivelActual(),
                    date    : new Date().toISOString(),
                    isDefault: false
                };
                // Nombre libre: si "Mi dashboard" ya existe, se numera.
                var n = 2;
                for (var k = 0; k < saved.length; k++) {
                    if (saved[k].name === copia.name) { copia.name = 'Mi dashboard ' + n; n++; k = -1; }
                }
                saved.push(copia);
                dclSetSavedLayouts(saved);
                dclSwalToast('Se creó "' + copia.name + '" para editar sin tocar el del sistema', 'info');
                dclEditSavedLayout(copia.id);
                return;
            }

            dclLoadSavedLayout(id);   // aplica el cfg y cierra el panel
            // dclLoadSavedLayout reaplica el DOM en un setTimeout(0); el builder
            // tiene que entrar DESPUÉS de ese render, si no poolea secciones que
            // aún se están reordenando.
            setTimeout(function () { dclEnterBuilderMode(false, id); }, 120);
            return;
        }
    }

    // Aplica el layout marcado como default (si existe) al cargar la página.
    // Se ejecuta una sola vez por sesión para no pisar cambios en vivo del usuario.
    function dclApplyDefaultSavedLayout() {
        if (sessionStorage.getItem('dcl_dflt_applied')) return;
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].isDefault) {
                sessionStorage.setItem('dcl_dflt_applied', '1');
                var src = dclLayoutCfgForView(saved[i]) || saved[i].cfg || {};
                var clone = JSON.parse(JSON.stringify(src));
                clone._vista = dclNivelActual();
                dclSaveCfg(clone);
                dclSetActiveLayoutName(saved[i].name || '');
                return;
            }
        }
        sessionStorage.setItem('dcl_dflt_applied', '1');
    }

    function dclDeleteSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        // El layout del sistema no se puede eliminar
        var target = null;
        for (var k = 0; k < saved.length; k++) {
            if (saved[k].id === id) { target = saved[k]; break; }
        }
        if (!target) return;
        if (target.isSystem) {
            dclSwalToast('El layout del sistema no se puede eliminar', 'info');
            return;
        }
        dclSwalConfirm({
            title: 'Eliminar layout',
            text: '¿Eliminar el layout "' + target.name + '"? Esta acción no se puede deshacer.',
            confirmText: 'Eliminar'
        }, function () {
            var cur = dclGetSavedLayouts();
            var newArr = [];
            var eraDefault = false;
            for (var i = 0; i < cur.length; i++) {
                if (cur[i].id !== id) newArr.push(cur[i]);
                else if (cur[i].isDefault) eraDefault = true;
            }
            // Si se borró el default, devolver el default al layout del sistema
            if (eraDefault) {
                for (var j = 0; j < newArr.length; j++) newArr[j].isDefault = !!newArr[j].isSystem;
            }
            dclSetSavedLayouts(newArr);
            dclOpenLayoutsPanel();
            dclSwalToast('Layout "' + target.name + '" eliminado');
        });
    }

    function dclSetDefaultLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) saved[i].isDefault = (saved[i].id === id);
        dclSetSavedLayouts(saved);
        dclOpenLayoutsPanel();
    }

    function dclDuplicateSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id === id) {
                var copy = { id: 'cfg_' + Date.now(), name: saved[i].name + ' (copia)', cfg: saved[i].cfg, date: new Date().toISOString(), isDefault: false };
                saved.push(copy);
                dclSetSavedLayouts(saved);
                dclOpenLayoutsPanel();
                return;
            }
        }
    }

    // ── Nombre del layout activo (se fusiona en el título del master) ────
    function _dclActiveNameKey() { return 'dcl_active_name_' + dclWsModule(); }
    function dclSetActiveLayoutName(name) {
        try {
            if (name) localStorage.setItem(_dclActiveNameKey(), name);
            else localStorage.removeItem(_dclActiveNameKey());
        } catch (e) { }
        dclRenderActiveLayoutName();
    }
    function dclGetActiveLayoutName() {
        try { return localStorage.getItem(_dclActiveNameKey()) || ''; } catch (e) { return ''; }
    }
    // Título del master limpio (DashboardChecklist.master) + nombre del
    // layout activo, ej: "DASHBOARD GENERAL — CUMPLIMIENTO DE CHECKLISTS | Por defecto del sistema"
    function dclRenderActiveLayoutName() {
        var src = document.querySelector('.dcl-page-title-data');
        var dest = document.querySelector('.dcl-mt-title');
        if (!src || !dest) return;
        var texto = src.textContent.trim();
        var name = dclGetActiveLayoutName();
        if (name) texto += ' | ' + name;
        dest.textContent = texto;
    }

    // Toggle del dropdown Mis Layouts (abre/cierra anclado al botón)
    function dclToggleLayoutsPanel(btn) {
        if (document.getElementById('dcl-layouts-panel')) { dclCloseLayoutsPanel(); return; }
        dclOpenLayoutsPanel(btn);
    }

    function dclOpenLayoutsPanel(anchorBtn) {
        dclCloseLayoutsPanel();
        dclEnsureSystemLayoutExists();     // crear el layout del sistema solo si NO existe (sin reescribirlo)
        var saved = dclGetSavedLayouts();
        var btn = anchorBtn || document.getElementById('dcl-layouts-btn');
        var panel = document.createElement('div');
        panel.id = 'dcl-layouts-panel';
        panel.className = 'dcl-layouts-panel';
        // Backdrop transparente para cerrar al hacer click fuera
        panel.onclick = function (e) { if (e.target === panel) dclCloseLayoutsPanel(); };

        var _activeName = dclGetActiveLayoutName();   // layout actualmente aplicado en la vista
        var itemsHtml = '';
        if (!saved.length) {
            itemsHtml = '<div class="dcl-layouts-empty"><i class="mdi mdi-bookmark-outline"></i>' +
                        '<p>Sin layouts en ' + dclEsc(dclNivelLabel()) + '</p>' +
                        '<p class="dcl-layouts-empty-sub">Cada categoría tiene sus propios layouts. ' +
                        'Crea uno nuevo o guarda el actual con los botones de abajo</p></div>';
        } else {
            for (var i = 0; i < saved.length; i++) {
                var s = saved[i];
                var dt = s.date ? new Date(s.date).toLocaleDateString('es-CL') : '';
                var nm = dclHtmlEsc(s.name || 'Sin nombre');
                var esActivo = !!(_activeName && s.name === _activeName);
                var defMark = s.isDefault ? ' <span class="dcl-layouts-dflt-chip">default</span>' : '';
                var actMark = esActivo ? ' <span class="dcl-layouts-active-chip"><i class="mdi mdi-check"></i> activo</span>' : '';
                var sysMark = s.isSystem ? ' <span class="dcl-layouts-sys-chip"><i class="mdi mdi-shield-check-outline"></i> sistema</span>' : '';
                var idAttr = dclHtmlEsc(s.id);
                // Acciones: el layout del sistema solo permite Aplicar/Duplicar/Default
                var actsHtml =
                    '<button type="button" class="dcl-layouts-act-btn" data-act="load" data-id="' + idAttr + '" data-tip="Aplicar&#10;Usa este layout en el dashboard ahora"><i class="mdi mdi-check-circle-outline"></i></button>' +
                    '<button type="button" class="dcl-layouts-act-btn" data-act="dup" data-id="' + idAttr + '" data-tip="Duplicar&#10;Crea una copia independiente que puedes editar"><i class="mdi mdi-content-copy"></i></button>' +
                    '<button type="button" class="dcl-layouts-act-btn" data-act="default" data-id="' + idAttr + '" data-tip="Marcar como predeterminado&#10;Se aplicará solo al abrir el dashboard"><i class="mdi mdi-star' + (s.isDefault ? '' : '-outline') + '"></i></button>';
                if (s.isSystem) {
                    // También editable: no se toca el original, se duplica y se
                    // abre el builder sobre la copia (ver dclEditSavedLayout).
                    // Sin esto, quien tiene aplicado el layout del sistema —lo
                    // más habitual— no veía ningún botón de editar.
                    actsHtml +=
                        '<button type="button" class="dcl-layouts-act-btn dcl-layouts-act-btn--edit" data-act="edit" data-id="' + idAttr + '" data-tip="Editar&#10;Crea una copia editable sin modificar el layout del sistema"><i class="mdi mdi-view-quilt"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn dcl-layouts-act-btn--lock" disabled data-tip="Layout protegido&#10;El del sistema no se puede renombrar ni borrar"><i class="mdi mdi-lock-outline"></i></button>';
                } else {
                    actsHtml =
                        '<button type="button" class="dcl-layouts-act-btn" data-act="load" data-id="' + idAttr + '" data-tip="Aplicar&#10;Usa este layout en el dashboard ahora"><i class="mdi mdi-check-circle-outline"></i></button>' +
                        // Editar = aplicar el layout y abrir "Armar Dashboard" sobre él.
                        // Ícono de grilla, no lápiz: el lápiz ya es "Renombrar".
                        '<button type="button" class="dcl-layouts-act-btn dcl-layouts-act-btn--edit" data-act="edit" data-id="' + idAttr + '" data-tip="Editar&#10;Abre este layout en Armar Dashboard para modificarlo"><i class="mdi mdi-view-quilt"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn" data-act="rename" data-id="' + idAttr + '" data-tip="Renombrar&#10;Cambia el nombre de este layout"><i class="mdi mdi-pencil-outline"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn" data-act="dup" data-id="' + idAttr + '" data-tip="Duplicar&#10;Crea una copia independiente que puedes editar"><i class="mdi mdi-content-copy"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn" data-act="default" data-id="' + idAttr + '" data-tip="Marcar como predeterminado&#10;Se aplicará solo al abrir el dashboard"><i class="mdi mdi-star' + (s.isDefault ? '' : '-outline') + '"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn dcl-layouts-act-btn--del" data-act="del" data-id="' + idAttr + '" data-tip="Eliminar&#10;Borra este layout de forma permanente"><i class="mdi mdi-delete-outline"></i></button>';
                }
                // Categoría del layout: la guardada al crearlo o, para los
                // anteriores a este cambio, la del nivel donde está almacenado.
                var catChip = dclCatChip(s.nivel || dclNivelActual(), 'dcl-cat-chip--sm');

                itemsHtml +=
                    '<div class="dcl-layouts-item' + (esActivo ? ' dcl-layouts-item--active' : '') + (s.isSystem ? ' dcl-layouts-item--sys' : '') + '">' +
                    '<div class="dcl-layouts-item-info">' +
                    '<span class="dcl-layouts-item-name">' + nm + actMark + defMark + sysMark + '</span>' +
                    '<span class="dcl-layouts-item-date">' + catChip + '<span class="dcl-layouts-item-dt">' + dt + '</span></span>' +
                    '</div>' +
                    '<div class="dcl-layouts-item-acts">' + actsHtml + '</div>' +
                    '</div>';
            }
        }

        panel.innerHTML =
            '<div class="dcl-layouts-box">' +
            '<div class="dcl-layouts-hd">' +
            '<span class="dcl-layouts-title"><i class="mdi mdi-bookmark-multiple-outline"></i>&nbsp;Mis Layouts</span>' +
            '<button type="button" class="dcl-layouts-close" data-act="close" data-tip="Cerrar&#10;Cierra este panel"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            // Categoría activa: deja claro que la lista es SOLO de este nivel y
            // que lo que se cree aquí quedará asociado a él.
            '<div class="dcl-layouts-cat">' +
            '<span class="dcl-layouts-cat-lbl">Categor&iacute;a</span>' +
            dclCatChip(dclNivelActual()) +
            '</div>' +
            '<div class="dcl-layouts-list">' + itemsHtml + '</div>' +
            '<div class="dcl-layouts-ft">' +
            '<button type="button" class="dcl-btn dcl-btn--ghost" data-act="new">' +
            '<i class="mdi mdi-plus-box-outline"></i>&nbsp;Crear nuevo</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="savecur">' +
            '<i class="mdi mdi-content-save-outline"></i>&nbsp;Guardar actual</button>' +
            '</div>' +
            '</div>';

        // Delegación de clicks (robusto: sin onclick inline con IDs)
        panel.addEventListener('click', function (e) {
            var btn = e.target;
            while (btn && btn !== panel && !(btn.getAttribute && btn.getAttribute('data-act'))) btn = btn.parentNode;
            if (!btn || btn === panel) return;
            var act = btn.getAttribute('data-act');
            var id = btn.getAttribute('data-id');
            if (act === 'load') dclLoadSavedLayout(id);
            else if (act === 'edit') dclEditSavedLayout(id);
            else if (act === 'rename') dclRenameSavedLayout(id);
            else if (act === 'dup') dclDuplicateSavedLayout(id);
            else if (act === 'default') dclSetDefaultLayout(id);
            else if (act === 'del') dclDeleteSavedLayout(id);
            else if (act === 'close') dclCloseLayoutsPanel();
            else if (act === 'new') dclNewLayout();
            else if (act === 'savecur') dclSaveCurrentLayout();
        });

        document.body.appendChild(panel);

        // Anclar el dropdown DEBAJO del botón de layouts
        var box = panel.querySelector('.dcl-layouts-box');
        if (box && btn) {
            var r = btn.getBoundingClientRect();
            var boxW = 340;
            var left = Math.min(r.right - boxW, window.innerWidth - boxW - 10);
            if (left < 10) left = 10;
            box.style.position = 'fixed';
            box.style.top = (r.bottom + 8) + 'px';
            box.style.right = 'auto';
            box.style.left = left + 'px';
            box.style.width = boxW + 'px';
        }
        requestAnimationFrame(function () { panel.classList.add('dcl-layouts-panel--open'); });
    }

    function dclCloseLayoutsPanel() {
        var panel = document.getElementById('dcl-layouts-panel');
        if (!panel) return;
        panel.classList.remove('dcl-layouts-panel--open');
        setTimeout(function () { if (panel.parentNode) panel.parentNode.removeChild(panel); }, 260);
    }

    // ── Skeleton de carga ─────────────────────────────────────────────────
    // Dibuja la ESTRUCTURA del layout al que se navega (mismas filas, columnas y
    // alturas del cfg de ese nivel) con bloques animados. Así el cambio de
    // dashboard no muestra datos viejos ni un salto en blanco.
    function dclSkeletonCard(secId, alturaNivel) {
        var reg = _DCL_SECTION_REGISTRY[secId] || {};
        var cat = reg.catClass || 'chart';
        var h   = _DCL_H_PX[parseInt(alturaNivel, 10) || 2] || 280;

        var cuerpo = '';
        if (cat === 'kpi') {
            cuerpo = '<div class="dcl-sk-kpis">' +
                     '<div class="dcl-sk-kpi"></div><div class="dcl-sk-kpi"></div>' +
                     '<div class="dcl-sk-kpi"></div><div class="dcl-sk-kpi"></div>' +
                     '</div>';
        } else if (cat === 'table') {
            cuerpo = '<div class="dcl-sk-rows">' +
                     '<div class="dcl-sk-line dcl-sk-line--hd"></div>' +
                     '<div class="dcl-sk-line"></div><div class="dcl-sk-line"></div>' +
                     '<div class="dcl-sk-line"></div><div class="dcl-sk-line dcl-sk-line--sm"></div>' +
                     '</div>';
        } else {
            cuerpo = '<div class="dcl-sk-rows">' +
                     '<div class="dcl-sk-bar"></div><div class="dcl-sk-bar dcl-sk-bar--2"></div>' +
                     '<div class="dcl-sk-bar dcl-sk-bar--3"></div><div class="dcl-sk-bar dcl-sk-bar--4"></div>' +
                     '</div>';
        }

        return '<div class="dcl-sk-card" style="min-height:' + h + 'px">' +
               '<div class="dcl-sk-hd"><span class="dcl-sk-dot"></span><span class="dcl-sk-tit"></span></div>' +
               '<div class="dcl-sk-body">' + cuerpo + '</div>' +
               '</div>';
    }

    function dclRenderSkeleton() {
        var content = document.getElementById('dcl-content');
        if (!content) return;

        // El nivel ya cambió en los hidden fields, así que dclGetCfg() devuelve
        // el layout del destino: el esqueleto calca esa grilla.
        var cfg    = dclGetCfg();
        var rows   = dclNormalizeRows(cfg.rows);
        if (!rows.length) rows = dclNormalizeRows(dclDefaultCfg().rows);
        var alturas = cfg.sectionHeights || {};

        var html = '<div class="dcl-skeleton" aria-busy="true" aria-label="Cargando dashboard">';
        for (var r = 0; r < rows.length; r++) {
            html += '<div class="dcl-sk-row" style="grid-template-columns:repeat(' + rows[r].cols + ',1fr)">';
            for (var c = 0; c < rows[r].slots.length; c++) {
                var slot = rows[r].slots[c];
                var sec  = dclSlotSec(slot);
                var span = dclSlotSpan(slot);
                if (!sec) { html += '<div></div>'; continue; }
                html += '<div style="grid-column:span ' + span + '">' +
                        dclSkeletonCard(sec, alturas[sec]) + '</div>';
            }
            html += '</div>';
        }
        html += '</div>';
        content.innerHTML = html;
    }

    // Si la carga falla, el esqueleto quedaría girando para siempre: se cambia
    // por un estado de error con reintento.
    function dclSkeletonError(msg) {
        var content = document.getElementById('dcl-content');
        if (!content) return;
        content.innerHTML =
            '<div class="dcl-sk-error">' +
            '<i class="mdi mdi-cloud-alert"></i>' +
            '<p class="dcl-sk-error-tit">No se pudo cargar el dashboard</p>' +
            '<p class="dcl-sk-error-msg">' + dclEsc(msg || '') + '</p>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" onclick="dclAutoRefreshAjax(true)">' +
            '<i class="mdi mdi-refresh"></i>&nbsp;Reintentar</button>' +
            '</div>';
    }

    // esNavegacion=true cuando viene de un drill-down (no del timer): en ese caso
    // el refresh no se puede saltar aunque haya un overlay abierto, y al terminar
    // hay que re-aplicar el layout del NUEVO nivel.
    function dclAutoRefreshAjax(esNavegacion) {
        if (!esNavegacion && dclHayOverlayAbierto()) return;

        var hfU = document.getElementById('hfUsuario');
        var hfC = document.getElementById('hfCliente');
        var hfI = document.getElementById('hfInstalacion');
        var hfZ = document.getElementById('hfZona');
        var hfD = document.getElementById('hfDesde');
        var hfH = document.getElementById('hfHasta');
        var hfN = document.getElementById('hfNomIns');
        if (!hfU || !hfU.value) return;

        var badge = document.getElementById('dcl-refresh-badge');
        if (badge) badge.classList.add('dcl-refreshing');

        // Navegación entre dashboards → esqueleto con la forma del layout destino.
        // Da sensación de continuidad (se ve DÓNDE va a aparecer cada widget) en
        // vez de dejar el contenido viejo congelado hasta que llegue la respuesta.
        // En el auto-refresh de fondo NO se usa: parpadearía todo cada ciclo.
        var toast = null;
        if (esNavegacion) dclRenderSkeleton();
        else toast = dclSwalToast('Actualizando...', 'loading', { duracion: 8000 });

        var params = JSON.stringify({
            usuario: parseInt(hfU.value) || 0,
            cliente: parseInt(hfC ? hfC.value : '0') || 0,
            instalacion: parseInt(hfI ? hfI.value : '0') || 0,
            zona: parseInt(hfZ ? hfZ.value : '0') || 0,
            desde: hfD ? hfD.value : '',
            hasta: hfH ? hfH.value : '',
            nomIns: hfN ? hfN.value : '',
            meta: dclGetMeta()
        });

        var url = window._dclWsAjaxUrl;
        var xhr = new XMLHttpRequest();
        xhr.open('POST', url, true);
        xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) return;
            if (badge) badge.classList.remove('dcl-refreshing');
            if (toast) toast.close();
            if (xhr.status !== 200) {
                dclSwalToast('Error de conexión (' + xhr.status + ') al cargar el dashboard.', 'error');
                if (esNavegacion) dclSkeletonError('No se pudo conectar con el servidor.');
                return;
            }
            try {
                var resp = JSON.parse(xhr.responseText);
                var d = resp.d !== undefined ? resp.d : resp;
                // Un fallo del servidor se descartaba en silencio: el dashboard
                // quedaba con el contenido viejo y sin ninguna pista de por qué.
                if (!d || !d.ok) {
                    dclSwalToast((d && d.error) ? ('No se pudo cargar: ' + d.error)
                                                : 'No se pudo cargar el dashboard.', 'error');
                    if (esNavegacion) dclSkeletonError((d && d.error) ? d.error : 'No se pudo cargar el dashboard.');
                    return;
                }
                var content = document.getElementById('dcl-content');
                if (content) {
                    content.innerHTML = d.html;
                    setTimeout(function () {
                        dclInit();
                        // El refresh reemplaza el HTML: reabrir lo que el usuario
                        // tenía desplegado para no perder su contexto de lectura.
                        dclRestaurarRespuestasAbiertas();
                        if (esNavegacion) {
                            // El nivel cambió: aplicar SU layout (cada nivel tiene
                            // su propia cfg) y refrescar breadcrumb/título.
                            dclApplyDefaultCfgIfEmpty();
                            dclApplySectionState();
                            dclRenderBreadcrumb();
                            dclRenderActiveLayoutName();
                        }
                    }, 80);
                }
                var ts = document.querySelector('.dcl-refresh-text');
                if (ts && d.timestamp) ts.textContent = d.timestamp;
            } catch (e) { }
        };
        xhr.send(params);
    }

    function dclStartAutoRefresh() {
        if (_dclRefreshTimer) { clearInterval(_dclRefreshTimer); _dclRefreshTimer = null; }
        if (_dclRefreshMs > 0) {
            _dclRefreshTimer = setInterval(dclAutoRefreshAjax, _dclRefreshMs);
        }
    }

    // Countdown en el title del badge — sigue la frecuencia elegida por el usuario
    function dclStartCountdown() {
        if (_dclCountdownTimer) { clearInterval(_dclCountdownTimer); _dclCountdownTimer = null; }
        var badge = document.getElementById('dcl-refresh-badge');
        if (_dclRefreshMs <= 0) {
            if (badge) badge.dataset.tip = 'Actualización automática desactivada';
            return;
        }
        var totalSeg = Math.max(1, Math.round(_dclRefreshMs / 1000));
        var seg = totalSeg;
        if (badge) badge.dataset.tip = 'Próxima actualización en ' + seg + ' s';
        _dclCountdownTimer = setInterval(function () {
            seg--;
            if (seg <= 0) seg = totalSeg;
            var b = document.getElementById('dcl-refresh-badge');
            if (b) b.dataset.tip = 'Próxima actualización en ' + seg + ' s';
        }, 1000);
    }

    // ── Panel: elegir frecuencia de actualización automática ──────────────
    function dclToggleRefreshPanel(btn) {
        if (document.getElementById('dcl-refresh-panel')) { dclCloseRefreshPanel(); return; }
        dclOpenRefreshPanel(btn);
    }

    function dclOpenRefreshPanel(anchorBtn) {
        dclCloseRefreshPanel();
        var btn = anchorBtn || document.getElementById('dcl-refresh-btn');
        var panel = document.createElement('div');
        panel.id = 'dcl-refresh-panel';
        panel.className = 'dcl-layouts-panel';
        panel.onclick = function (e) { if (e.target === panel) dclCloseRefreshPanel(); };

        var esPreset = false;
        var optsHtml = '';
        for (var i = 0; i < _DCL_REFRESH_PRESETS.length; i++) {
            var p = _DCL_REFRESH_PRESETS[i];
            var activo = (p.ms === _dclRefreshMs);
            if (activo) esPreset = true;
            optsHtml += '<button type="button" class="dcl-refresh-opt' + (activo ? ' dcl-refresh-opt--active' : '') + '" data-ms="' + p.ms + '">' +
                '<i class="mdi mdi-' + (activo ? 'check-circle-outline' : 'circle-outline') + '"></i>' +
                '<span>' + p.lbl + '</span></button>';
        }
        var customVal = (!esPreset && _dclRefreshMs > 0) ? Math.round(_dclRefreshMs / 1000) : '';

        panel.innerHTML =
            '<div class="dcl-layouts-box">' +
            '<div class="dcl-layouts-hd">' +
            '<span class="dcl-layouts-title"><i class="mdi mdi-clock-outline"></i>&nbsp;Actualización automática</span>' +
            '<button type="button" class="dcl-layouts-close" data-act="close" data-tip="Cerrar&#10;Cierra este panel"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-layouts-list">' + optsHtml + '</div>' +
            '<div class="dcl-refresh-custom-wrap">' +
            '<div class="dcl-layouts-ft dcl-refresh-custom">' +
            '<input type="number" min="5" step="1" class="dcl-refresh-custom-input" id="dcl-refresh-custom-val" placeholder="Personalizado" value="' + customVal + '" />' +
            '<span class="dcl-refresh-custom-unit">seg</span>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="custom" data-tip="Aplicar&#10;Usa este layout en el dashboard ahora"><i class="mdi mdi-check"></i></button>' +
            '</div>' +
            '<span class="dcl-refresh-custom-err" id="dcl-refresh-custom-err"></span>' +
            '</div>' +
            '</div>';

        function aplicarCustom() {
            var inp = document.getElementById('dcl-refresh-custom-val');
            var err = document.getElementById('dcl-refresh-custom-err');
            var seg = parseInt(inp && inp.value, 10);
            if (!seg || seg < 5) {
                if (inp) { inp.focus(); inp.classList.add('dcl-refresh-custom-input--err'); }
                if (err) err.textContent = 'Ingresa un número de al menos 5 segundos';
                return;
            }
            dclSetRefreshMs(seg * 1000);
            dclCloseRefreshPanel();
        }

        panel.addEventListener('click', function (e) {
            var el = e.target;
            while (el && el !== panel && !(el.getAttribute && (el.getAttribute('data-ms') || el.getAttribute('data-act')))) el = el.parentNode;
            if (!el || el === panel) return;
            var msAttr = el.getAttribute('data-ms');
            if (msAttr) {
                dclSetRefreshMs(parseInt(msAttr, 10));
                dclCloseRefreshPanel();
                return;
            }
            var act = el.getAttribute('data-act');
            if (act === 'close') dclCloseRefreshPanel();
            else if (act === 'custom') aplicarCustom();
        });

        var customInput = panel.querySelector('#dcl-refresh-custom-val');
        if (customInput) {
            customInput.addEventListener('keydown', function (e) {
                if (e.key === 'Enter' || e.keyCode === 13) { e.preventDefault(); aplicarCustom(); }
            });
            customInput.addEventListener('input', function () {
                customInput.classList.remove('dcl-refresh-custom-input--err');
                var err = document.getElementById('dcl-refresh-custom-err');
                if (err) err.textContent = '';
            });
        }

        document.body.appendChild(panel);

        var box = panel.querySelector('.dcl-layouts-box');
        if (box && btn) {
            var r = btn.getBoundingClientRect();
            var boxW = 260;
            var left = Math.min(r.right - boxW, window.innerWidth - boxW - 10);
            if (left < 10) left = 10;
            box.style.position = 'fixed';
            box.style.top = (r.bottom + 8) + 'px';
            box.style.right = 'auto';
            box.style.left = left + 'px';
            box.style.width = boxW + 'px';
        }
        requestAnimationFrame(function () { panel.classList.add('dcl-layouts-panel--open'); });
    }

    function dclCloseRefreshPanel() {
        var panel = document.getElementById('dcl-refresh-panel');
        if (!panel) return;
        panel.classList.remove('dcl-layouts-panel--open');
        setTimeout(function () { if (panel.parentNode) panel.parentNode.removeChild(panel); }, 260);
    }

    // ── Hook UpdatePanel ─────────────────────────────────────────────────
    (function () {
        function afterRefresh() { setTimeout(dclInit, 80); }
        if (typeof Sys !== 'undefined' && Sys.WebForms && Sys.WebForms.PageRequestManager)
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(afterRefresh);
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function () { dclInit(); dclStartAutoRefresh(); dclStartCountdown(); });
        } else {
            dclInit();
            dclStartAutoRefresh();
            dclStartCountdown();
        }
    })();
