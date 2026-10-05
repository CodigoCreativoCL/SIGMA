/* ============================================================================
   SIGMA · EL ASISTENTE (rediseño del módulo de Activos, 04-10-2026)

   Lo comun a los formularios guiados: pasos (fpIr/fpSiguiente con hdnPaso),
   validacion amable (afRequerido/afRequeridoLibre + banda de lo que falta),
   combo con texto libre (input[data-combo] contra AF_OPC), foto por fila y
   soltar archivos. Lo propio de cada ficha queda en su pagina.

   Antes de cargarlo, la pagina puede fijar var AF_PASOS (por defecto 4).
   ========================================================================= */
function getRadWindow() {
    var oWindow = null;
    if (window.radWindow) oWindow = window.radWindow;
    else if (window.frameElement && window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
    return oWindow;
}
function closeWindow() {
    var window = getRadWindow();
    if (!window) return;
    if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
    window.close();
}

/* Soltar el archivo encima de la franja es lo mismo que elegirlo. */
function afSoltar(zona, idInput, alCambiar) {
    if (!zona || zona.getAttribute('data-listo') === '1') return;
    zona.setAttribute('data-listo', '1');
    zona.addEventListener('dragover', function (e) { e.preventDefault(); zona.classList.add('es-encima'); });
    zona.addEventListener('dragleave', function () { zona.classList.remove('es-encima'); });
    zona.addEventListener('drop', function (e) {
        e.preventDefault(); zona.classList.remove('es-encima');
        var input = document.getElementById(idInput);
        if (!input || !e.dataTransfer || !e.dataTransfer.files.length) return;
        try { input.files = e.dataTransfer.files; } catch (x) { return; }
        alCambiar(input);
    });
}

/* ---- Asistente: el paso vive en hdnPaso para sobrevivir a los
   postbacks parciales (cambiar el tipo recarga los modelos). ---- */
/* La pagina dice cuantos pasos tiene ANTES de cargar este archivo
   (var AF_PASOS = 6). Sin decirlo, son 4. */
var AF_PASOS = window.AF_PASOS || 4;
function fpCampo() { return document.querySelector('[id$="hdnPaso"]'); }
function fpActual() { var h = fpCampo(); var n = h ? parseInt(h.value, 10) : 1; return n >= 1 && n <= AF_PASOS ? n : 1; }
function fpIr(n) {
    n = Math.max(1, Math.min(AF_PASOS, n || 1));
    var h = fpCampo(); if (h) h.value = n;
    document.querySelectorAll('.af-seccion').forEach(function (p) { p.classList.toggle('es-activo', +p.getAttribute('data-paso') === n); });
    document.querySelectorAll('.af-tip').forEach(function (p) { p.classList.toggle('es-activo', +p.getAttribute('data-paso') === n); });
    document.querySelectorAll('.af-paso').forEach(function (b) {
        var k = +b.getAttribute('data-ir');
        b.classList.toggle('es-activo', k === n);
        b.classList.toggle('es-hecho', k < n && !b.classList.contains('es-falta'));
        b.setAttribute('aria-current', k === n ? 'step' : 'false');
    });
    var ant = document.getElementById('fpBtnAnterior'), sig = document.getElementById('fpBtnSiguiente'), d = document.getElementById('fpDonde');
    if (ant) ant.hidden = n === 1;
    if (sig) sig.hidden = n === AF_PASOS;
    if (d) d.textContent = 'Paso ' + n + ' de ' + AF_PASOS;

    /* Al crear, Siguiente es lo principal hasta el ultimo paso; ahi
       Guardar pasa a morado. Al editar, Guardar es siempre lo principal. */
    var af = document.querySelector('.af');
    var g = document.querySelector('.af-guardar');
    if (af && g && af.classList.contains('af-es-nuevo')) {
        var final = n === AF_PASOS;
        g.classList.toggle('es-primario', final);
        g.classList.toggle('es-secundario', !final);
        if (sig) { sig.classList.toggle('es-primario', !final); sig.classList.toggle('es-contorno', final); }
    }
    return false;
}
/* Del paso se avanza solo si lo obligatorio de ESE paso esta completo. */
function fpSiguiente() {
    var n = fpActual();
    if (!afValidarPaso(n)) { afMostrarFaltas(true); return false; }
    afMostrarFaltas(false);
    fpIr(n + 1);
    var c = document.querySelector('.af-cuerpo'); if (c && c.scrollIntoView && c.getBoundingClientRect().top < 0) c.scrollIntoView({ block: 'start' });
    return false;
}

/* ---- Validacion amable ----
   Cada obligatorio tiene un CustomValidator que llama a afRequerido. La
   funcion marca el campo (rotulo y borde en rojo + una frase de que
   hacer) y la barra de arriba junta lo que falta con un boton que lleva
   al campo. Nada de bordes rojos sin explicacion. */
function afValor(id, libre) {
    var c = window.$find ? $find(id) : null;
    if (c && c.get_text) {
        var t = (c.get_text() || '').trim();
        if (c.get_emptyMessage && t === c.get_emptyMessage()) t = '';
        if (libre || t === '') return t;
        var it = c.findItemByText ? c.findItemByText(t) : null;
        return it && it.get_value() !== '' ? t : '';
    }
    var e = document.getElementById(id);
    return e ? (e.value || '').trim() : '';
}
function afMarcar(id, ok) {
    var e = document.getElementById(id);
    var f = e ? e.closest('.sigma-modal-field') : null;
    if (f) f.classList.toggle('es-falta', !ok);
}
function afRequerido(sender, args) { args.IsValid = afValor(sender.controltovalidate, false) !== ''; afMarcar(sender.controltovalidate, args.IsValid); }
function afRequeridoLibre(sender, args) { args.IsValid = afValor(sender.controltovalidate, true) !== ''; afMarcar(sender.controltovalidate, args.IsValid); }
/* compatibilidad con quien todavia llame al nombre viejo */
function validaComboTexto(sender, args) { afRequeridoLibre(sender, args); }

function afValidadores(dentro) {
    if (typeof Page_Validators === 'undefined') return [];
    return Array.prototype.filter.call(Page_Validators, function (v) {
        if (v.validationGroup !== 'Activo') return false;
        var e = document.getElementById(v.controltovalidate);
        return !dentro || (e && dentro.contains(e));
    });
}
function afValidarPaso(n) {
    var sec = document.querySelector('.af-seccion[data-paso="' + n + '"]');
    var ok = true;
    afValidadores(sec).forEach(function (v) { if (typeof ValidatorValidate === 'function') { ValidatorValidate(v); if (!v.isvalid) ok = false; } });
    return ok;
}
function afMostrarFaltas(irAlPrimero) {
    var caja = document.getElementById('afFaltan');
    var lista = document.getElementById('afFaltanLista');
    var faltan = Array.prototype.slice.call(document.querySelectorAll('.af .sigma-modal-field.es-falta'));
    document.querySelectorAll('.af-paso').forEach(function (b) {
        var sec = document.querySelector('.af-seccion[data-paso="' + b.getAttribute('data-ir') + '"]');
        b.classList.toggle('es-falta', !!(sec && sec.querySelector('.sigma-modal-field.es-falta')));
    });
    if (!caja || !lista) return;
    lista.innerHTML = '';
    faltan.forEach(function (f) {
        var lab = f.querySelector('label');
        var b = document.createElement('button');
        b.type = 'button';
        b.innerHTML = '<i class="mdi mdi-arrow-right"></i>';
        b.insertBefore(document.createTextNode((lab ? lab.textContent : 'Campo').replace('*', '').trim()), b.firstChild);
        b.onclick = function () { afIrCampo(f); };
        lista.appendChild(b);
    });
    var t = document.getElementById('afFaltanTit');
    if (t) t.textContent = faltan.length === 1 ? 'Falta 1 dato para poder guardar' : 'Faltan ' + faltan.length + ' datos para poder guardar';
    caja.classList.toggle('es-visible', faltan.length > 0);
    if (irAlPrimero && faltan.length) afIrCampo(faltan[0]);
    fpIr(fpActual());
}
function afIrCampo(f) {
    var sec = f.closest('.af-seccion');
    if (sec) fpIr(+sec.getAttribute('data-paso'));
    var inp = f.querySelector('input[type="text"]:not([type="hidden"]), textarea');
    setTimeout(function () { if (inp) { inp.focus(); if (inp.scrollIntoView) inp.scrollIntoView({ block: 'center' }); } }, 30);
}
/* Al corregir un campo marcado, se vuelve a mirar ese campo solo. */
function afRevisar(f) {
    afValidadores(f).forEach(function (v) { if (typeof ValidatorValidate === 'function') ValidatorValidate(v); });
    if (document.getElementById('afFaltan') && document.getElementById('afFaltan').classList.contains('es-visible')) afMostrarFaltas(false);
}
document.addEventListener('focusout', function (e) {
    var f = e.target && e.target.closest ? e.target.closest('.af .sigma-modal-field.es-falta') : null;
    if (f) setTimeout(function () { afRevisar(f); }, 200);
});

/* ---- Combo con texto libre ----
   Una caja que se elige de la lista o se escribe: lo que no existe se crea
   al guardar. Las opciones vienen del servidor en AF_OPC. */
function afComboHtml(nombre, cual, ph, etiqueta) {
    return '<span class="af-combo"><input type="text" name="' + nombre + '" class="sigma-nd-txt" data-combo="' + cual +
           '" placeholder="' + ph + '" aria-label="' + etiqueta + '" autocomplete="off" />' +
           '<button type="button" class="af-combo-btn" tabindex="-1" aria-label="Ver opciones"><i class="mdi mdi-chevron-down"></i></button></span>';
}
var afComboInput = null;
function afComboLista() {
    var l = document.getElementById('afComboLista');
    if (!l) { l = document.createElement('div'); l.id = 'afComboLista'; l.setAttribute('role', 'listbox'); document.body.appendChild(l); }
    return l;
}
function afComboAbrir(inp) {
    var opc = (window.AF_OPC && AF_OPC[inp.getAttribute('data-combo')]) || [];
    var l = afComboLista(), t = (inp.value || '').trim(), tl = t.toLowerCase();
    afComboInput = inp;
    l.innerHTML = '';
    var exacta = false, n = 0;
    opc.forEach(function (o) {
        if (tl && o.toLowerCase().indexOf(tl) === -1) return;
        if (o.toLowerCase() === tl) exacta = true;
        if (n++ > 60) return;
        var b = document.createElement('button'); b.type = 'button'; b.textContent = o;
        b.onmousedown = function (e) { e.preventDefault(); afComboElegir(o); };
        l.appendChild(b);
    });
    if (t && !exacta) {
        var c = document.createElement('button'); c.type = 'button'; c.className = 'es-crear';
        c.innerHTML = '<i class="mdi mdi-plus"></i>'; c.appendChild(document.createTextNode('Crear «' + t + '»'));
        c.onmousedown = function (e) { e.preventDefault(); afComboElegir(t); };
        l.appendChild(c);
    }
    if (!l.children.length) { var v = document.createElement('div'); v.className = 'vacio'; v.textContent = 'Escribe para crear uno nuevo.'; l.appendChild(v); }
    var r = inp.getBoundingClientRect();
    l.style.left = r.left + 'px'; l.style.width = Math.max(r.width, 200) + 'px';
    var abajo = window.innerHeight - r.bottom;
    if (abajo < 200 && r.top > abajo) { l.style.top = ''; l.style.bottom = (window.innerHeight - r.top + 4) + 'px'; }
    else { l.style.bottom = ''; l.style.top = (r.bottom + 4) + 'px'; }
    l.classList.add('es-abierto');
}
function afComboCerrar() { var l = document.getElementById('afComboLista'); if (l) l.classList.remove('es-abierto'); afComboInput = null; }
function afComboElegir(v) {
    if (!afComboInput) return;
    afComboInput.value = v;
    afComboInput.dispatchEvent(new Event('change', { bubbles: true }));
    afComboCerrar();
}
document.addEventListener('focusin', function (e) { if (e.target.matches && e.target.matches('input[data-combo]')) afComboAbrir(e.target); });
document.addEventListener('input', function (e) { if (e.target.matches && e.target.matches('input[data-combo]')) afComboAbrir(e.target); });
document.addEventListener('focusout', function (e) { if (e.target === afComboInput) setTimeout(function () { if (document.activeElement !== afComboInput) afComboCerrar(); }, 120); });
document.addEventListener('click', function (e) {
    var b = e.target.closest ? e.target.closest('.af-combo-btn') : null;
    if (b) { var i = b.parentNode.querySelector('input'); i.focus(); afComboAbrir(i); }
});
document.addEventListener('keydown', function (e) {
    if (!afComboInput || e.target !== afComboInput) return;
    var l = afComboLista(), bs = Array.prototype.slice.call(l.querySelectorAll('button')), k = bs.indexOf(l.querySelector('.es-foco'));
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault(); if (!bs.length) return;
        k = e.key === 'ArrowDown' ? Math.min(bs.length - 1, k + 1) : Math.max(0, k - 1);
        bs.forEach(function (x, j) { x.classList.toggle('es-foco', j === k); });
        bs[k].scrollIntoView({ block: 'nearest' });
    } else if (e.key === 'Enter') {
        e.preventDefault();
        var f = l.querySelector('.es-foco'); if (f) f.onmousedown(e); else afComboCerrar();
    } else if (e.key === 'Escape') afComboCerrar();
});
window.addEventListener('scroll', function () { if (afComboInput) afComboAbrir(afComboInput); }, true);

/* La foto de una fila: se ve al instante y sube al guardar. */
function afFotoHtml(nombre) {
    return '<label class="af-fila-foto" title="Agregar una foto"><i class="mdi mdi-camera-plus-outline"></i>' +
           '<input type="file" name="' + nombre + '" accept="image/*" onchange="afFotoFila(this)" aria-label="Foto" /></label>';
}
function afFotoFila(input) {
    var caja = input.closest('.af-fila-foto'); if (!caja) return;
    var viejo = caja.querySelector('img'); if (viejo) viejo.remove();
    var ico = caja.querySelector('i');
    if (input.files && input.files[0] && window.FileReader) {
        var r = new FileReader();
        r.onload = function (e) { var img = document.createElement('img'); img.src = e.target.result; img.alt = ''; caja.insertBefore(img, input); if (ico) ico.style.display = 'none'; caja.classList.add('con-foto'); caja.title = input.files[0].name; };
        r.readAsDataURL(input.files[0]);
    } else { if (ico) ico.style.display = ''; caja.classList.remove('con-foto'); caja.title = 'Agregar una foto'; }
}

function afQuitarFila(b, alQuitar) { b.closest('.af-fila, .sigma-nd-fila').remove(); if (alQuitar) alQuitar(); }

