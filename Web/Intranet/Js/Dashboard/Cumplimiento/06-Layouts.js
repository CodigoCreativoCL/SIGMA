    // SISTEMA DE CONFIGURACIONES GUARDADAS (localStorage)
    // ══════════════════════════════════════════════════════════════
    function dclGetSavedLayouts(nivel) {
        try { return JSON.parse(localStorage.getItem(_dclSavedKeyFn(nivel)) || '[]'); } catch (e) { return []; }
    }
    function dclSetSavedLayouts(arr, nivel) {
        try { localStorage.setItem(_dclSavedKeyFn(nivel), JSON.stringify(arr)); } catch (e) { }
    } 

    // ── Layout "Por defecto del sistema" (auto-creado, protegido) ─────────
    // El sistema garantiza SIEMPRE un layout base llamado "Por defecto del
    // sistema" en Mis Layouts. Se crea automáticamente la primera vez, es el
    // default inicial y no se puede eliminar ni renombrar (isSystem:true).
    var _dclSystemLayoutId = 'cfg_system_default';
    // El layout del sistema almacena AMBAS vistas (general / instalación). El
    // campo `cfg` refleja la vista actual; `cfgGeneral`/`cfgInstalacion` guardan
    // cada variante. Así al cambiar de vista se aplica el default correcto.
    function dclEnsureSystemLayout() {
        var saved = dclGetSavedLayouts();
        var sys = null, idx = -1;
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id === _dclSystemLayoutId || saved[i].isSystem) { sys = saved[i]; idx = i; break; }
        }
        var cfgGen = dclDefaultCfg('general');
        var cfgIns = dclDefaultCfg('instalacion');
        var cfgZon = dclDefaultCfg('zona');
        var cfgAct = dclDefaultCfg();   // variante del nivel actual (incluye zona)
        if (!sys) {
            var hayDefault = false;
            for (var j = 0; j < saved.length; j++) if (saved[j].isDefault) { hayDefault = true; break; }
            sys = {
                id: _dclSystemLayoutId,
                name: 'Por defecto del sistema',
                cfg: cfgAct,
                cfgGeneral: cfgGen,
                cfgInstalacion: cfgIns,
                cfgZona: cfgZon,
                date: new Date().toISOString(),
                isDefault: !hayDefault,
                isSystem: true
            };
            saved.unshift(sys);           // siempre primero en la lista
        } else {
            // Mantenerlo siempre actualizado al default del sistema (no editable)
            sys.id = _dclSystemLayoutId;
            sys.name = 'Por defecto del sistema';
            sys.isSystem = true;
            sys.cfgGeneral = cfgGen;
            sys.cfgInstalacion = cfgIns;
            sys.cfgZona = cfgZon;
            sys.cfg = cfgAct;
            // Asegurar que esté primero en la lista
            if (idx > 0) { saved.splice(idx, 1); saved.unshift(sys); }
        }
        dclSetSavedLayouts(saved);
        return sys;
    }

    // Garantiza que el layout del sistema exista, SIN reescribirlo si ya está
    // (para usar al abrir el panel sin pisar nada).
    function dclEnsureSystemLayoutExists() {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].isSystem) return saved[i];
        }
        return dclEnsureSystemLayout();
    }

    // Devuelve el cfg correcto de un layout según la vista actual (para el
    // layout del sistema que tiene cfgGeneral/cfgInstalacion).
    function dclLayoutCfgForView(layout) {
        if (!layout) return null;
        if (layout.isSystem) {
            // El layout del sistema guarda una variante por nivel: si se resolviera
            // solo por general/instalación, en Zona se aplicaría la de instalación
            // (widgets de otro nivel → slots vacíos).
            var nivel = dclNivelActual();
            var c = nivel === 'zona'        ? layout.cfgZona
                  : nivel === 'instalacion' ? layout.cfgInstalacion
                  :                           layout.cfgGeneral;
            if (c && c.rows && c.rows.length) return c;
            return dclDefaultCfg(nivel);   // variante ausente (layout viejo) → default del nivel
        }
        return layout.cfg || null;
    }

    // ── Diálogo propio para pedir un nombre (reemplaza el prompt() nativo) ─
    // Reutiliza el mismo shell .dcl-layouts-panel/.dcl-layouts-box que "Mis
    // Layouts" y "Actualización automática", sin depender de SweetAlert2.
    // onOk recibe el nombre ya trimmeado.
    function dclSwalPrompt(opts, onOk) {
        opts = opts || {};
        var old = document.getElementById('dcl-prompt-panel');
        if (old && old.parentNode) old.parentNode.removeChild(old);

        var panel = document.createElement('div');
        panel.id = 'dcl-prompt-panel';
        panel.className = 'dcl-layouts-panel dcl-prompt-panel';
        panel.onclick = function (e) { if (e.target === panel) dclClosePromptPanel(); };

        panel.innerHTML =
            '<div class="dcl-layouts-box dcl-prompt-box">' +
            '<div class="dcl-layouts-hd">' +
            '<span class="dcl-layouts-title"><i class="mdi mdi-pencil-outline"></i>&nbsp;' + dclHtmlEsc(opts.title || 'Nombre') + '</span>' +
            '<button type="button" class="dcl-layouts-close" data-act="cancel" data-tip="Cerrar&#10;Cierra este panel"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-prompt-body">' +
            '<input type="text" class="dcl-refresh-custom-input dcl-prompt-input" id="dcl-prompt-input" placeholder="' + dclHtmlEsc(opts.placeholder || '') + '" value="' + dclHtmlEsc(opts.value || '') + '" />' +
            '<span class="dcl-refresh-custom-err" id="dcl-prompt-err"></span>' +
            '</div>' +
            '<div class="dcl-layouts-ft">' +
            '<button type="button" class="dcl-btn dcl-btn--ghost" data-act="cancel">Cancelar</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="ok">' + dclHtmlEsc(opts.confirmText || 'Guardar') + '</button>' +
            '</div>' +
            '</div>';

        function confirmar() {
            var inp = document.getElementById('dcl-prompt-input');
            var err = document.getElementById('dcl-prompt-err');
            var v = ((inp && inp.value) || '').trim();
            if (!v) {
                if (inp) { inp.classList.add('dcl-refresh-custom-input--err'); inp.focus(); }
                if (err) err.textContent = 'Ingresa un nombre.';
                return;
            }
            dclClosePromptPanel();
            onOk(v);
        }

        panel.addEventListener('click', function (e) {
            var el = e.target;
            while (el && el !== panel && !(el.getAttribute && el.getAttribute('data-act'))) el = el.parentNode;
            if (!el || el === panel) return;
            var act = el.getAttribute('data-act');
            if (act === 'cancel') dclClosePromptPanel();
            else if (act === 'ok') confirmar();
        });

        document.body.appendChild(panel);

        var inp = document.getElementById('dcl-prompt-input');
        if (inp) {
            inp.addEventListener('keydown', function (e) {
                if (e.key === 'Enter' || e.keyCode === 13) { e.preventDefault(); confirmar(); }
                else if (e.key === 'Escape' || e.keyCode === 27) { dclClosePromptPanel(); }
            });
            inp.addEventListener('input', function () {
                inp.classList.remove('dcl-refresh-custom-input--err');
                var err = document.getElementById('dcl-prompt-err');
                if (err) err.textContent = '';
            });
        }

        requestAnimationFrame(function () {
            panel.classList.add('dcl-layouts-panel--open');
            if (inp) { inp.focus(); inp.select(); }
        });
    }

    function dclClosePromptPanel() {
        var panel = document.getElementById('dcl-prompt-panel');
        if (!panel) return;
        panel.classList.remove('dcl-layouts-panel--open');
        setTimeout(function () { if (panel.parentNode) panel.parentNode.removeChild(panel); }, 200);
    }

    // ── Diálogo propio de confirmación (Sí/No) ─────────────────────────────
    function dclSwalConfirm(opts, onOk) {
        opts = opts || {};
        var old = document.getElementById('dcl-prompt-panel');
        if (old && old.parentNode) old.parentNode.removeChild(old);

        var panel = document.createElement('div');
        panel.id = 'dcl-prompt-panel';
        panel.className = 'dcl-layouts-panel dcl-prompt-panel';
        panel.onclick = function (e) { if (e.target === panel) dclClosePromptPanel(); };

        panel.innerHTML =
            '<div class="dcl-layouts-box dcl-prompt-box">' +
            '<div class="dcl-layouts-hd">' +
            '<span class="dcl-layouts-title"><i class="mdi mdi-alert-outline"></i>&nbsp;' + dclHtmlEsc(opts.title || 'Confirmar') + '</span>' +
            '<button type="button" class="dcl-layouts-close" data-act="cancel" data-tip="Cerrar&#10;Cierra este panel"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-prompt-body"><p class="dcl-prompt-text">' + dclHtmlEsc(opts.text || '') + '</p></div>' +
            '<div class="dcl-layouts-ft">' +
            '<button type="button" class="dcl-btn dcl-btn--ghost" data-act="cancel">' + dclHtmlEsc(opts.cancelText || 'Cancelar') + '</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary dcl-btn--danger" data-act="ok">' + dclHtmlEsc(opts.confirmText || 'Eliminar') + '</button>' +
            '</div>' +
            '</div>';

        panel.addEventListener('click', function (e) {
            var el = e.target;
            while (el && el !== panel && !(el.getAttribute && el.getAttribute('data-act'))) el = el.parentNode;
            if (!el || el === panel) return;
            var act = el.getAttribute('data-act');
            if (act === 'cancel') dclClosePromptPanel();
            else if (act === 'ok') { dclClosePromptPanel(); onOk(); }
        });

        document.body.appendChild(panel);
        requestAnimationFrame(function () { panel.classList.add('dcl-layouts-panel--open'); });
    }

    // ── Toast de confirmación breve (no bloqueante, propio) ────────────────
    // opts.duracion (ms, default 2200) = cierre automático. Devuelve un
    // objeto con .close() para cerrar antes (ej. cuando termina un AJAX).
    function dclSwalToast(msg, icon, opts) {
        opts = opts || {};
        var wrap = document.getElementById('dcl-toast-wrap');
        if (!wrap) {
            wrap = document.createElement('div');
            wrap.id = 'dcl-toast-wrap';
            wrap.className = 'dcl-toast-wrap';
            document.body.appendChild(wrap);
        }
        var ic = icon === 'info' ? 'information-outline'
            : icon === 'error' ? 'close-circle-outline'
            : icon === 'warning' ? 'alert-outline'
            : icon === 'loading' ? 'autorenew'
            : 'check-circle-outline';
        var toast = document.createElement('div');
        toast.className = 'dcl-toast dcl-toast--' + (icon || 'success');
        toast.innerHTML = '<i class="mdi mdi-' + ic + '"></i><span>' + dclHtmlEsc(msg) + '</span>';
        wrap.appendChild(toast);
        requestAnimationFrame(function () { toast.classList.add('dcl-toast--in'); });

        var cerrado = false;
        function cerrar() {
            if (cerrado) return;
            cerrado = true;
            toast.classList.remove('dcl-toast--in');
            setTimeout(function () { if (toast.parentNode) toast.parentNode.removeChild(toast); }, 220);
        }
        var timer = setTimeout(cerrar, opts.duracion || 2200);
        return { close: function () { clearTimeout(timer); cerrar(); } };
    }

    // Guarda el cfg actual como layout con nombre (llamado desde el builder y panel)
    // nivelForzado: lo pasa el builder cuando se armó una categoría distinta a
    // la vista actual, para que el layout se guarde donde corresponde.
    function dclPromptSaveLayout(cfg, nivelForzado) {
        var nivel = nivelForzado || dclNivelActual();
        dclSwalPrompt({
            title: 'Guardar layout en ' + dclNivelLabel(nivel),
            placeholder: 'Nombre del layout',
            value: 'Mi layout ' + new Date().toLocaleDateString('es-CL'),
            confirmText: 'Guardar'
        }, function (name) {
            var saved = dclGetSavedLayouts(nivel);
            var isFirst = saved.length === 0;
            saved.push({
                id: 'cfg_' + Date.now(), name: name,
                cfg: JSON.parse(JSON.stringify(cfg || dclGetCfg())),
                nivel: nivel,   // queda asociado a la categoría donde se guardó
                date: new Date().toISOString(), isDefault: isFirst
            });
            dclSetSavedLayouts(saved, nivel);
            // El nombre activo solo aplica si el layout es de la vista en pantalla.
            if (nivel === dclNivelActual()) dclSetActiveLayoutName(name);
            dclSwalToast('Layout "' + name + '" guardado en ' + dclNivelLabel(nivel));
        });
    }

