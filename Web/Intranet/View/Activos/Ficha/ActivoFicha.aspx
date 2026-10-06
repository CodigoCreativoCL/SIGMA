<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoFicha.aspx.cs" Inherits="View_Activos_Ficha_ActivoFicha" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>
<%@ Register TagPrefix="wuc" TagName="ActivoForm" Src="~/View/Activos/Activos/ActivoForm.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-modal.css") %>' rel="stylesheet" />

    <%-- La cascara -tarjetas, chips, datos, vacios, botones- es la misma del
         centro de la orden de trabajo y se reusa tal cual. Aca va solo lo
         propio del centro del activo. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-orden.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activo360.css") %>' rel="stylesheet" />
    <%-- Las vistas de la planta (rediseño 05-10-2026) y three.js bajo demanda:
         el importmap deja que el import dinamico encuentre "three". --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activos.css") %>' rel="stylesheet" />
    <script type="importmap">
        {
            "imports": {
                "three": "<%=ResolveUrl("~/Js/three/three.module.min.js") %>",
                "three/addons/": "<%=ResolveUrl("~/Js/three/addons/") %>"
            }
        }
    </script>
    <%-- El asistente de la pestaña Ficha y el formulario de componente de
         «¿Qué vas a agregar?» usan la piel compartida. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-asistente.css") %>' rel="stylesheet" />
    <%-- El combo con busqueda es uno solo para la planta y el asistente. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-combo.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-combo.js") %>'></script>
    <script type="text/javascript">var AF_PASOS = 6;</script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-asistente.js") %>'></script>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* El listado suelto de Activos ya no esta en el menu: el alta vive
           aca, en el mismo modal que usa la edicion. */
        function abrirActivo(query) {
            seccionPendiente = null;
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Activos/Activo.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo activo' : 'Editar activo',
                width: 1060,
                initialHeight: 620
            });
        }

        /* Los componentes se crean y se editan aca: el listado suelto no
           esta en el menu, y salir del centro para agregar una pieza del
           equipo que se esta mirando es perder el lugar. */
        function abrirComponente(query) {
            seccionPendiente = 'componentes';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Componentes/ActivoComponente.aspx") %>?query=' + query,
                title: query === queryNuevoComponente ? 'Nuevo componente' : 'Editar componente',
                width: 1040,
                initialHeight: 620
            });
        }

        function abrirVariable(query) {
            seccionPendiente = 'condicion';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Variables/ActivoVariable.aspx") %>?query=' + query,
                title: query === queryNuevaVariable ? 'Nueva variable de condición' : 'Editar variable',
                width: 940,
                initialHeight: 600
            });
        }

        function abrirMedidor(query) {
            seccionPendiente = 'condicion';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Medidores/ActivoMedidor.aspx") %>?query=' + query,
                title: query === queryNuevoMedidor ? 'Nuevo contador' : 'Editar contador',
                width: 920,
                initialHeight: 560
            });
        }

        /* Registrar una lectura a mano. `query` lo cifra el servidor: el de
           la tarjeta trae la variable o el contador ya elegido; el del boton
           de arriba trae solo el equipo. */
        function abrirLectura(query) {
            seccionPendiente = 'condicion';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Ficha/RegistrarLectura.aspx") %>?query=' + (query || queryLecturaSuelta),
                title: 'Registrar lectura',
                width: 860,
                initialHeight: 560
            });
        }

        /* Un cliente que parte con SIGMA llega con su catalogo en una
           planilla: doscientos equipos de a uno son doscientos modales. */
        function abrirCargaMasiva() {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Ficha/CargaMasivaActivos.aspx") %>',
                title: 'Carga masiva de activos',
                width: 1080,
                initialHeight: 640
            });
        }

        var seccionPendiente = null;

        /* El campo donde vive el equipo elegido. El JS de la lista lo escribe
           y hace postback: el centro se arma en el servidor. */
        window.sgCampoActivo = '<%=IdCampoActivo %>';

        /* Los ids nunca viajan a la vista: el activo va DENTRO del
           querystring cifrado que arma el servidor. */
        var queryNuevoComponente = '<%=QueryNuevoComponente %>';
        var queryNuevoMedidor = '<%=QueryNuevoMedidor %>';
        var queryNuevaVariable = '<%=QueryNuevaVariable %>';

        /* El querystring de la lectura tambien lo cifra el servidor. */
        var queryLecturaSuelta = '<%=QueryLectura %>';

        /* Al cerrar un modal se vuelve a la seccion desde donde se abrio, no
           al Resumen: el postback repinta el bloque entero. */
        /* ---- Estructura: el diagrama y su detalle (bloque 343, rediseño 344) ---- */
        var queryNuevoSubactivo = '<%=QueryNuevoSubactivo %>';
        var queryNuevaCompat = '<%=QueryNuevaCompat %>';
        var urlNuevaOt = '<%=ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") %>';
        var esSeleccion = null;

        function esAsistente(abrir) {
            var a = document.getElementById('sgEsAsistente');
            if (!a) return false;
            if (abrir) {
                esVista('elegir');
                var nom = document.querySelector('.sg-a3-hero-nom'), donde = document.getElementById('sgEsAsisDonde');
                if (donde) donde.textContent = nom && nom.textContent.trim() ? 'Agregar a ' + nom.textContent.trim() : 'Agregar a este activo';
                esSeleccion = null;
                document.querySelectorAll('.sg-es-op').forEach(function (o) { o.classList.remove('es-elegida'); o.setAttribute('aria-checked', 'false'); });
                var c = document.getElementById('sgEsContinuar');
                if (c) { c.disabled = true; c.firstChild.nodeValue = 'Elige una opción'; }
            }
            a.classList.toggle('es-abierto', !!abrir);
            if (abrir) { var f = a.querySelector('.sg-es-op'); if (f) f.focus(); }
            return false;
        }
        function esElegir(b) {
            document.querySelectorAll('.sg-es-op').forEach(function (o) { o.classList.toggle('es-elegida', o === b); o.setAttribute('aria-checked', o === b ? 'true' : 'false'); });
            esSeleccion = b.getAttribute('data-que');
            var c = document.getElementById('sgEsContinuar');
            if (c) { c.disabled = false; c.firstChild.nodeValue = 'Continuar con «' + b.getAttribute('data-txt') + '»'; }
            return false;
        }
        function esContinuar() { return esSeleccion ? esAgregar(esSeleccion) : false; }

        /* Las tres vistas del asistente: elegir, el componente aqui mismo, o
           el formulario de subactivo/repuesto dentro de esta misma ventana. */
        function esVista(v) {
            document.querySelectorAll('#sgEsAsistente .sg-es-vista').forEach(function (x) { x.hidden = x.getAttribute('data-vista') !== v; });
            var caja = document.querySelector('#sgEsAsistente .sg-es-asis-caja');
            if (caja) caja.classList.toggle('es-ancha', v === 'marco');
            if (v !== 'marco') { var m = document.getElementById('sgEsMarco'); if (m) m.src = 'about:blank'; }
            return false;
        }
        function esMarco(url, titulo) {
            var m = document.getElementById('sgEsMarco');
            document.getElementById('sgEsMarcoTit').textContent = titulo;
            /* La pagina de adentro cierra con closeWindow(): se le da una
               "ventana" que refresca el centro y cierra este asistente. */
            m.radWindow = { BrowserWindow: window, close: function () { esAsistente(false); } };
            m.onload = function () {
                try {
                    m.contentWindow.radWindow = m.radWindow;
                    /* Como en SigmaModal: sin el titulo propio de la pagina, que aca ya lo dice la cabecera. */
                    m.contentDocument.documentElement.classList.add('sigma-dialog-child');
                } catch (e) { }
            };
            m.src = url;
            esVista('marco');
            return false;
        }
        function escAbrir() {
            escEnPlanta = false;
            var ca = document.getElementById('escActivoCampo'); if (ca) ca.hidden = true;
            ['escNombre', 'escTipo', 'escLado', 'escDesc'].forEach(function (id) { var e = document.getElementById(id); if (e) { e.value = ''; e.classList.remove('is-nuevo'); } });
            var tpl = document.getElementById('sgEsDatos');
            var nom = tpl ? tpl.getAttribute('data-nombre') : '';
            var padre = document.getElementById('escPadre'), est = document.getElementById('escEstado');
            if (padre) padre.innerHTML = tpl ? tpl.querySelector('[data-padres]').innerHTML : '';
            if (est) est.innerHTML = tpl ? tpl.querySelector('[data-estados]').innerHTML : '';
            var f = document.getElementById('escFecha'); if (f) { var h = new Date(); f.value = ('0' + h.getDate()).slice(-2) + '-' + ('0' + (h.getMonth() + 1)).slice(-2) + '-' + h.getFullYear(); }
            var foto = document.getElementById('escFoto'); if (foto) { foto.value = ''; escFotoVer(foto); }
            document.querySelectorAll('#sgEsAsistente .sg-es-campo.es-falta').forEach(function (x) { x.classList.remove('es-falta'); });
            document.getElementById('sgEscFaltan').hidden = true;
            var d = document.querySelector('[data-vista="componente"] .sg-es-donde-txt');
            if (d) d.textContent = nom ? 'Una parte de «' + nom + '» que quieres seguir por separado.' : 'Una parte de este activo que quieres seguir por separado.';
            esVista('componente');
            setTimeout(function () { document.getElementById('escNombre').focus(); }, 30);
            return false;
        }
        /* Desde la pestaña Componentes de la planta: el mismo formulario, con el
           activo a elegir (los datos salen de la planta ya cargada). */
        var escEnPlanta = false;
        function escDesdePlanta() {
            var P = window.sigmaPlanta, d = P && P.datos ? P.datos() : null;
            if (!d) return false;
            /* En la planta no esta el formulario del activo, que es el que trae
               AF_OPC del servidor: sin esto «Qué es» y «Dónde va» solo ofrecian
               «Crear». Se llenan con lo que ya usan los componentes de la
               planta; si AF_OPC ya viene del servidor (centro 360), manda ese. */
            window.AF_OPC = window.AF_OPC || {};
            if (!(AF_OPC.tipos || []).length) AF_OPC.tipos = d.tipos || [];
            if (!(AF_OPC.lados || []).length) AF_OPC.lados = d.lados || [];
            esAsistente(true);
            escAbrir();
            escEnPlanta = true;
            document.getElementById('escActivoCampo').hidden = false;
            var sel = document.getElementById('escActivo');
            sel.innerHTML = '<option value="">Elige el activo</option>';
            d.activos.forEach(function (a) {
                var o = document.createElement('option'); o.value = a.id; o.textContent = a.n + (a.c ? ' · ' + a.c : ''); sel.appendChild(o);
            });
            var est = document.getElementById('escEstado'); est.innerHTML = '';
            d.estados.forEach(function (e) {
                var o = document.createElement('option'); o.value = e.id; o.textContent = e.n; if (/operativ/i.test(e.n) && !est.value) o.selected = true; est.appendChild(o);
            });
            escActivoCambia();
            var txt = document.querySelector('[data-vista="componente"] .sg-es-donde-txt');
            if (txt) txt.textContent = 'Una parte de un activo que quieres seguir por separado.';
            setTimeout(function () { sel.focus(); }, 40);
            return false;
        }
        function escActivoCambia() {
            var P = window.sigmaPlanta, d = P && P.datos ? P.datos() : null; if (!d) return;
            var id = document.getElementById('escActivo').value, padre = document.getElementById('escPadre');
            var a = d.activos.filter(function (x) { return String(x.id) === id; })[0];
            padre.innerHTML = '';
            var o0 = document.createElement('option'); o0.value = '0'; o0.textContent = a ? 'Directamente de «' + a.n + '»' : 'Directamente del activo'; padre.appendChild(o0);
            (a ? a.comps : []).forEach(function (c) { var o = document.createElement('option'); o.value = c.id; o.textContent = 'De la parte «' + c.n + '»'; padre.appendChild(o); });
        }

        function escFotoVer(input) {
            var ico = document.getElementById('escFotoIco'), nom = document.getElementById('escFotoNom');
            if (input.files && input.files[0] && window.FileReader) {
                var r = new FileReader();
                r.onload = function (e) { ico.innerHTML = ''; var i = document.createElement('img'); i.src = e.target.result; i.alt = ''; ico.appendChild(i); };
                r.readAsDataURL(input.files[0]);
                nom.textContent = input.files[0].name;
            } else { ico.innerHTML = '<i class="mdi mdi-image-outline"></i>'; nom.textContent = 'PNG o JPG. Ayuda a reconocer la pieza.'; }
        }
        function escGuardar() {
            var faltan = [];
            (escEnPlanta ? [['escActivo', 'Activo'], ['escNombre', 'Nombre'], ['escTipo', 'Qué es']] : [['escNombre', 'Nombre'], ['escTipo', 'Qué es']]).forEach(function (c) {
                var e = document.getElementById(c[0]), ok = e && e.value.trim() !== '';
                e.closest('.sg-es-campo').classList.toggle('es-falta', !ok);
                if (!ok) faltan.push(c[1]);
            });
            var aviso = document.getElementById('sgEscFaltan');
            if (faltan.length) {
                document.getElementById('sgEscFaltanTxt').textContent = (faltan.length === 1 ? 'Falta: ' : 'Faltan: ') + faltan.join(' y ') + '.';
                aviso.hidden = false;
                var mal = document.querySelector('#sgEsAsistente .sg-es-campo.es-falta input, #sgEsAsistente .sg-es-campo.es-falta select'); if (mal) mal.focus();
                return false;
            }
            aviso.hidden = true;
            /* desde la planta, al volver del guardado se abre de nuevo la pestaña Componentes */
            if (escEnPlanta && window.sigmaPlanta && window.sigmaPlanta.recordar) window.sigmaPlanta.recordar('componentes');
            __doPostBack('<%=lnkEsGuardarComp.UniqueID %>', '');
            return false;
        }
        document.addEventListener('DOMContentLoaded', function () {
            var z = document.getElementById('escFotoZona');
            if (!z) return;
            z.addEventListener('dragover', function (e) { e.preventDefault(); z.classList.add('es-encima'); });
            z.addEventListener('dragleave', function () { z.classList.remove('es-encima'); });
            z.addEventListener('drop', function (e) {
                e.preventDefault(); z.classList.remove('es-encima');
                var i = document.getElementById('escFoto');
                try { i.files = e.dataTransfer.files; escFotoVer(i); } catch (x) { }
            });
        });
        /* La ventana de impresion de etiquetas (la misma de Posiciones y Bodega). */
        function abrirEtiquetas(query) {
            var w = 980, h = 760;
            var x = window.screenX + Math.max(0, (window.outerWidth - w) / 2);
            var y = window.screenY + Math.max(0, (window.outerHeight - h) / 2);
            var vent = window.open('<%=ResolveUrl("~/View/Comun/Impresion/Etiquetas.aspx") %>?query=' + query, 'sigmaEtiquetas',
                'width=' + w + ',height=' + h + ',left=' + Math.round(x) + ',top=' + Math.round(y) + ',resizable=yes,scrollbars=yes');
            if (!vent) { alert('El navegador bloqueó la ventana de impresión. Permite las ventanas emergentes para este sitio y vuelve a intentarlo.'); return false; }
            vent.focus();
            return false;
        }

        /* ---- Bitacora: responder en el mismo hilo (bloque 352) ---- */
        document.addEventListener('click', function (e) {
            var t = e.target.closest ? e.target.closest('[data-bit-responder],[data-bit-cancelar],[data-bit-enviar],[data-bit-hilo]') : null;
            if (!t) return;
            e.preventDefault();
            if (t.hasAttribute('data-bit-hilo')) {
                var ul = document.querySelector('[data-bit-hijos="' + t.getAttribute('data-bit-hilo') + '"]');
                if (!ul) return;
                var abierto = ul.hidden; ul.hidden = !abierto;
                t.setAttribute('aria-expanded', abierto ? 'true' : 'false');
                t.querySelector('i').className = 'mdi ' + (abierto ? 'mdi-chevron-up' : 'mdi-chevron-down');
                return;
            }
            var id = t.getAttribute('data-bit-responder') || t.getAttribute('data-bit-cancelar') || t.getAttribute('data-bit-enviar');
            var f = document.querySelector('[data-bit-form="' + id + '"]');
            if (!f) return;
            if (t.hasAttribute('data-bit-responder')) {
                document.querySelectorAll('[data-bit-form]').forEach(function (x) { if (x !== f) x.hidden = true; });
                f.hidden = false; f.querySelector('textarea').focus(); return;
            }
            if (t.hasAttribute('data-bit-cancelar')) { f.hidden = true; return; }
            var txt = f.querySelector('textarea').value.trim();
            if (!txt) { f.querySelector('textarea').focus(); f.classList.add('es-falta'); return; }
            document.getElementById('bitPadre').value = id;
            document.getElementById('bitRespuesta').value = txt;
            t.disabled = true;
            __doPostBack('<%=lnkResponder.UniqueID %>', '');
        });

        /* Todo se agrega dentro del mismo asistente: no se abre otra ventana. */
        function esAgregar(que) {
            var a = document.getElementById('sgEsAsistente');
            if (a && !a.classList.contains('es-abierto')) esAsistente(true);
            seccionPendiente = 'componentes';
            if (que === 'subactivo')
                return esMarco('<%=ResolveUrl("~/View/Activos/Activos/Activo.aspx") %>?query=' + queryNuevoSubactivo, 'Nuevo subactivo');
            if (que === 'componente') return escAbrir();
            if (que === 'repuesto') return esrAbrir();
            return false;
        }

        /* ---- Repuesto compatible en el mismo asistente (bloque 351) ----
           El combo es el de la planta (busca al escribir, con foto y stock) y
           se guarda con WsActivos.VincularRepuesto. */
        var esrRepuestos = null;
        function esrAbrir() {
            var tpl = document.getElementById('sgEsDatos'), para = document.getElementById('esrPara');
            if (para) para.innerHTML = tpl && tpl.querySelector('[data-alcances]') ? tpl.querySelector('[data-alcances]').innerHTML : '';
            document.getElementById('esrObs').value = '';
            document.getElementById('sgEsrFaltan').hidden = true;
            esVista('repuesto');
            var caja = document.getElementById('esrCombo'), P = window.sigmaPlanta;
            if (!P || !P.combo) { caja.innerHTML = '<p class="sg-es-ayuda">No se pudo cargar el buscador. Recarga la página.</p>'; return false; }
            var pintar = function () {
                caja.innerHTML = P.combo('esrep', esrRepuestos.map(function (r) {
                    return { id: r.id, n: r.n, txt: r.c, img: r.foto || '', sub: [r.c, r.stock + (r.u ? ' ' + r.u : '') + ' en bodega'].filter(Boolean).join(' · ') };
                }), 0, { ph: 'Busca por nombre o código', req: true, vacio: 'Ningún repuesto se llama así' });
                setTimeout(function () { var i = caja.querySelector('[data-sacombo]'); if (i) i.focus(); }, 40);
            };
            if (esrRepuestos) pintar();
            else P.ws('Repuestos', {}).then(function (d) { esrRepuestos = d.filas || []; pintar(); })
                  .catch(function (e) { caja.innerHTML = ''; var p = document.createElement('p'); p.className = 'sg-es-ayuda'; p.textContent = e.message; caja.appendChild(p); });
            return false;
        }
        function esrFalta(txt) {
            document.getElementById('sgEsrFaltanTxt').textContent = txt;
            document.getElementById('sgEsrFaltan').hidden = false;
        }
        function esrGuardar(b) {
            var P = window.sigmaPlanta, caja = document.getElementById('esrCombo');
            var inp = caja.querySelector('[data-sacombo]'); if (inp && P.comboSalir) P.comboSalir(inp);
            var h = caja.querySelector('input[name="esrep"]'), rep = h ? +h.value || 0 : 0;
            if (!rep) { esrFalta('Elige el repuesto de la lista.'); if (inp) inp.focus(); return false; }
            var v = (document.getElementById('esrPara').value || '').split(':');
            b.disabled = true;
            P.ws('VincularRepuesto', { repuesto: rep, activo: v[0] === 'a' ? +v[1] : 0, componente: v[0] === 'c' ? +v[1] : 0, observacion: document.getElementById('esrObs').value })
             .then(function () {
                 esAsistente(false); seccionPendiente = 'componentes';
                 if (typeof refresh === 'function') refresh(); else location.reload();
             })
             .catch(function (e) { b.disabled = false; esrFalta(e.message); });
            return false;
        }
        /* Un subactivo se abre en su propio centro, directo en su estructura. */
        function esAbrirActivo(id) {
            var campo = document.getElementById(window.sgCampoActivo || '');
            var h = document.getElementById('hdnSeccion');
            if (!campo) return false;
            if (h) h.value = 'componentes';
            campo.value = id;
            __doPostBack('', '');
            return false;
        }
        function esAbrirComponente(query) { abrirComponente(query); seccionPendiente = 'componentes'; return false; }
        document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { esAsistente(false); esCerrarDet(); } });

        /* El detalle de lo elegido. Todo lo escrito por personas entra por
           textContent: un nombre puede traer comillas o angulos. */
        function esNodo(tag, cls, txt) {
            var n = document.createElement(tag);
            if (cls) n.className = cls;
            if (txt != null) n.textContent = txt;
            return n;
        }
        function esIco(nombre) { var i = document.createElement('i'); i.className = 'mdi ' + nombre; return i; }
        function esBoton(clase, icono, texto, alClic) {
            var b = esNodo('button', 'sg-ot-btn ' + clase);
            b.type = 'button';
            b.appendChild(esIco(icono)); b.appendChild(document.createTextNode(texto));
            b.onclick = function () { alClic(); return false; };
            return b;
        }
        var ES_CLASE = { sub: ['Subactivo', 'mdi-cogs'], comp: ['Componente', 'mdi-puzzle-outline'], rep: ['Repuesto', 'mdi-package-variant-closed'] };
        function esPintar(d) {
            var det = document.getElementById('sgEsDetalle');
            if (!det || !d || !ES_CLASE[d.k]) return;
            det.innerHTML = '';
            det.className = 'sg-es-det es-abierto es-' + d.k;
            var x = esNodo('button', 'sg-es-det-x'); x.type = 'button'; x.setAttribute('aria-label', 'Cerrar el detalle');
            x.appendChild(esIco('mdi-close')); x.onclick = function () { return esCerrarDet(); };
            det.appendChild(x);

            var cab = esNodo('div', 'sg-es-det-cab');
            var ico = esNodo('span', 'sg-es-det-ico'); ico.appendChild(esIco(ES_CLASE[d.k][1])); cab.appendChild(ico);
            var tt = esNodo('div');
            tt.appendChild(esNodo('b', 'sg-es-det-nom', d.n));
            var chips = esNodo('div', 'sg-es-det-chips');
            chips.appendChild(esNodo('span', 'sg-es-etq es-' + d.k, ES_CLASE[d.k][0]));
            if (d.e) chips.appendChild(esNodo('span', 'sg-es-chip es-' + (d.t || 'ok'), d.e));
            tt.appendChild(chips); cab.appendChild(tt); det.appendChild(cab);

            if (d.nota) {
                var nota = esNodo('div', 'sg-es-det-nota');
                nota.appendChild(esIco('mdi-alert-outline'));
                var nt = esNodo('span'); nt.appendChild(esNodo('b', '', 'Observación: ')); nt.appendChild(document.createTextNode(d.nota));
                nota.appendChild(nt); det.appendChild(nota);
            }

            var dl = esNodo('dl', 'sg-es-det-datos');
            (d.datos || []).forEach(function (x) {
                if (!x[1]) return;
                dl.appendChild(esNodo('dt', '', x[0]));
                var dd = esNodo('dd');
                if (x[2]) { var a = esNodo('a', '', x[1]); a.href = '#'; a.onclick = function () { return esAbrirActivo(x[2]); }; dd.appendChild(a); }
                else dd.textContent = x[1];
                dl.appendChild(dd);
            });
            det.appendChild(dl);

            if (d.reps && d.reps.length) {
                det.appendChild(esNodo('h5', '', d.reps.length === 1 ? 'Repuesto que le sirve' : 'Repuestos que le sirven'));
                d.reps.forEach(function (r) {
                    var f = esNodo('div', 'sg-es-det-rep');
                    f.appendChild(esIco('mdi-package-variant-closed'));
                    f.appendChild(esNodo('span', '', r[0]));
                    f.appendChild(esNodo('span', 'sg-es-chip es-' + r[2], r[1]));
                    det.appendChild(f);
                });
            }

            var acc = esNodo('div', 'sg-es-det-acc');
            if (d.k === 'sub') acc.appendChild(esBoton('es-primario', 'mdi-open-in-new', 'Abrir su centro 360°', function () { esAbrirActivo(d.id); }));
            if (d.k === 'comp') {
                var ot = esNodo('a', 'sg-ot-btn es-primario'); ot.href = urlNuevaOt; ot.appendChild(esIco('mdi-plus')); ot.appendChild(document.createTextNode('Crear OT'));
                acc.appendChild(ot);
                if (d.q) acc.appendChild(esBoton('es-secundario', 'mdi-pencil-outline', 'Editar esta parte', function () { esAbrirComponente(d.q); }));
            }
            if (d.k === 'rep' && d.url)
                acc.appendChild(esBoton('es-contorno', 'mdi-open-in-new', 'Ver ficha del repuesto', function () {
                    SigmaModal.open({ url: d.url, title: 'Repuesto', width: 1000, initialHeight: 620 });
                }));
            if (acc.children.length) det.appendChild(acc);
            if (d.pie) det.appendChild(esNodo('p', 'sg-es-det-pie', d.pie));
        }
        function esVer(btn, sinMover) {
            document.querySelectorAll('.sg-es-item.es-viendo').forEach(function (x) { x.classList.remove('es-viendo'); x.removeAttribute('aria-current'); });
            btn.classList.add('es-viendo');
            btn.setAttribute('aria-current', 'true');
            var d = null;
            try { d = JSON.parse(btn.getAttribute('data-det')); } catch (e) { return false; }
            esPintar(d);
            var x = document.querySelector('#sgEsDetalle .sg-es-det-x'); if (x && !sinMover) x.focus();
            return false;
        }
        function esCerrarDet() {
            var det = document.getElementById('sgEsDetalle');
            if (det) det.classList.remove('es-abierto');
            var v = document.querySelector('.sg-es-item.es-viendo');
            if (v) { v.classList.remove('es-viendo'); v.removeAttribute('aria-current'); v.focus(); }
            return false;
        }
        function esRetiradas(b) {
            var col = b.closest('.sg-es-col');
            var ver = col.classList.toggle('ver-retiradas');
            b.textContent = ver ? 'Ocultar partes retiradas' : b.getAttribute('data-txt');
            return false;
        }
        /* Ya no se abre nada solo: el detalle aparece cuando se toca algo. */
        function esIniciar() { }

        /* "Agregar qué medir" en Condición: un menu chico, se cierra al tocar afuera. */
        function sgCondMenu(b) {
            var w = b.closest('.sg-cond-agregar');
            var abierto = w.classList.toggle('es-abierto');
            b.setAttribute('aria-expanded', abierto ? 'true' : 'false');
            return false;
        }
        document.addEventListener('click', function (e) {
            document.querySelectorAll('.sg-cond-agregar.es-abierto').forEach(function (w) { if (!w.contains(e.target)) w.classList.remove('es-abierto'); });
        });

        window.addEventListener('load', function () {
            esIniciar();
            if (window.Sys && Sys.WebForms) Sys.WebForms.PageRequestManager.getInstance().add_endRequest(esIniciar);
        });

        /* ---- Listado: menus de la cabecera, vistas y "Crear" ---- */
        function sgMenuBtn(b) {
            var w = b.closest('.sg-menu-btn');
            document.querySelectorAll('.sg-menu-btn.es-abierto').forEach(function (x) { if (x !== w) x.classList.remove('es-abierto'); });
            w.classList.toggle('es-abierto');
            return false;
        }
        document.addEventListener('click', function (e) {
            document.querySelectorAll('.sg-menu-btn.es-abierto').forEach(function (w) { if (!w.contains(e.target)) w.classList.remove('es-abierto'); });
        });
        function crearDesdeLista(que) {
            document.querySelectorAll('.sg-menu-btn.es-abierto').forEach(function (w) { w.classList.remove('es-abierto'); });
            seccionPendiente = null;
            var u = {
                componente: ['<%=ResolveUrl("~/View/Activos/Componentes/ActivoComponente.aspx") %>?query=0', 'Nuevo componente', 1040, 620],
                variable: ['<%=ResolveUrl("~/View/Activos/Variables/ActivoVariable.aspx") %>?query=0', 'Nueva variable de condición', 940, 600],
                medidor: ['<%=ResolveUrl("~/View/Activos/Medidores/ActivoMedidor.aspx") %>?query=0', 'Nuevo medidor', 920, 560],
                tipo: ['<%=ResolveUrl("~/View/Activos/Tipos/ActivoTipo.aspx") %>?query=0', 'Nuevo tipo de activo', 820, 520],
                modelo: ['<%=ResolveUrl("~/View/Activos/Modelos/ActivoModelo.aspx") %>?query=0', 'Nuevo modelo', 820, 560]
            }[que];
            if (que === 'tipos') { window.location.href = '<%=ResolveUrl("~/View/Activos/Tipos/ActivoTipos.aspx") %>'; return false; }
            if (u) SigmaModal.open({ url: u[0], title: u[1], width: u[2], initialHeight: u[3] });
            return false;
        }
        function sgListaVista(v) {
            document.querySelectorAll('.sg-lista-vista').forEach(function (b) {
                var on = b.getAttribute('data-vista') === v;
                b.classList.toggle('es-activa', on); b.setAttribute('aria-selected', on ? 'true' : 'false');
            });
            var a = document.getElementById('sgVistaActivos'), c = document.getElementById('sgVistaComp');
            if (a) a.hidden = v !== 'activos';
            if (c) c.hidden = v !== 'componentes';
            try { sessionStorage.setItem('sgListaVista', v); } catch (e) { }
            sgCompFiltrar();
            return false;
        }
        /* El buscador de arriba filtra tambien los componentes. */
        function sgCompFiltrar() {
            var c = document.getElementById('sgVistaComp'); if (!c || c.hidden) return;
            var q = ((document.getElementById('sgListaBuscar') || {}).value || '').toLowerCase().trim(), hay = 0;
            c.querySelectorAll('.sg-lc-grupo').forEach(function (g) {
                var visibles = 0, cab = (g.getAttribute('data-txt') || '');
                g.querySelectorAll('.sg-lc-fila').forEach(function (f) {
                    var ok = !q || cab.indexOf(q) !== -1 || (f.getAttribute('data-txt') || '').indexOf(q) !== -1;
                    f.hidden = !ok; if (ok) visibles++;
                });
                g.hidden = visibles === 0; hay += visibles;
            });
            var v = document.getElementById('sgCompSinRes'); if (v) v.hidden = hay > 0;
        }
        document.addEventListener('input', function (e) { if (e.target && e.target.id === 'sgListaBuscar') sgCompFiltrar(); });
        function sgListaIniciar() {
            var v = null; try { v = sessionStorage.getItem('sgListaVista'); } catch (e) { }
            if (v === 'componentes' && document.getElementById('sgVistaComp')) sgListaVista('componentes');
        }
        window.addEventListener('load', function () {
            sgListaIniciar();
            if (window.Sys && Sys.WebForms) Sys.WebForms.PageRequestManager.getInstance().add_endRequest(sgListaIniciar);
        });

        function refresh() {
            var h = document.getElementById('hdnSeccion');
            if (h && seccionPendiente) h.value = seccionPendiente;
            __doPostBack('<%=lnkRecargar.UniqueID %>', '');
        }
    </script>

    <style type="text/css">
        /* ====================================================================
           CENTRO DEL ACTIVO · REDISEÑO 04-10-2026 (bloque 344)
           Un color fijo por clase de cosa, igual en el diagrama, la leyenda,
           los chips del listado y el asistente: morado el equipo, azul el
           subactivo, turquesa el componente y ambar el repuesto.
           ==================================================================== */
        .sg-a3, [data-mpanel="componentes"], .sg-es-asis {
            --es-purple: #6732F4; --es-purple-dark: #4820C9; --es-purple-soft: #F2EFFF;
            --es-blue: #087BEA; --es-blue-dark: #0565C2; --es-blue-soft: #EAF4FF;
            --es-cyan: #16C6C9; --es-cyan-dark: #007F8A; --es-cyan-soft: #E8FBFB;
            --es-rep: #E08A00; --es-rep-ink: #8F4E00; --es-rep-soft: #FFF4E0;
            --es-ink: #17223B; --es-muted: #68738A; --es-line: #E2E7F0; --es-canvas: #F4F6FA;
            --es-success: #16855B; --es-success-soft: #E7F5EE; --es-warning: #B65C00; --es-warning-soft: #FFF3E3;
            --es-danger: #C7352B; --es-danger-soft: #FDECEA;
        }

        /* ---- cabecera: foto, nombre, estado, donde esta ---- */
        .sg-a3-hero.es-v2 { align-items: center; gap: 16px; }
        .sg-a3-hero.es-v2 .sg-a3-foto { flex: 0 0 auto; width: 68px; height: 68px; border-radius: 14px; border: 1px solid var(--es-line); overflow: hidden; background: var(--es-canvas); }
        .sg-a3-hero.es-v2 .sg-a3-foto.es-vacia { font-size: 30px; color: #A9B1C3; }
        .sg-a3-hero.es-v2 h1 { font-size: 26px; font-weight: 800; color: var(--es-ink); gap: 10px; }
        .sg-a3-hero-chips { display: inline-flex; flex-wrap: wrap; gap: 6px; }
        .sg-a3-hero.es-v2 .sg-a3-hero-sub { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 14px; margin-top: 6px; font-size: 13.5px; color: var(--es-muted); }
        .sg-a3-hero-sub .es-cod { font-weight: 800; color: var(--es-ink); }
        .sg-a3-hero-sub .mdi { font-size: 16px; vertical-align: -2px; margin-right: 2px; }
        .sg-a3-hero-padre { display: inline-flex; align-items: center; gap: 6px; margin: 8px 0 0; padding: 4px 10px; border-radius: 999px; background: var(--es-blue-soft); color: var(--es-blue-dark); font-size: 13px; }
        .sg-a3-hero-padre a { color: var(--es-blue-dark); font-weight: 800; text-decoration: underline; text-underline-offset: 2px; }
        .sg-a3-hero.es-v2 .sg-a3-hero-acc .sg-ot-btn { min-height: 40px; }

        /* ---- menu "Mas": separado del contenido ---- */
        .sg-a3-mas-menu { top: calc(100% + 8px); width: 280px; padding: 8px; border-color: var(--es-line); border-radius: 14px;
            box-shadow: 0 20px 44px -12px rgba(23, 34, 59, .38), 0 0 0 1px rgba(23, 34, 59, .04); }
        .sg-a3-mas-tit { padding: 6px 10px 8px; margin-bottom: 4px; border-bottom: 1px solid var(--es-line); font-size: 11.5px; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; color: var(--es-muted); }
        a.sg-a3-mas-op, a.sg-a3-mas-op:hover, a.sg-a3-mas-op:focus { min-height: 40px; font-size: 14px; }

        /* ---- Condicion: una sola accion morada ---- */
        .sg-cond-agregar { position: relative; }
        .sg-cond-agregar:not(:has(.sg-cond-op)) { display: none; }
        .sg-cond-agregar-menu { position: absolute; right: 0; top: calc(100% + 6px); z-index: 30; display: none; width: 320px; padding: 6px; background: #fff;
            border: 1px solid var(--es-line); border-radius: 14px; box-shadow: 0 20px 44px -12px rgba(23, 34, 59, .38); }
        .sg-cond-agregar.es-abierto .sg-cond-agregar-menu { display: block; }
        a.sg-cond-op, a.sg-cond-op:hover { display: flex; gap: 10px; align-items: flex-start; padding: 10px; border-radius: 10px; color: var(--es-ink); text-decoration: none; }
        a.sg-cond-op:hover { background: var(--es-canvas); }
        a.sg-cond-op > i { width: 32px; height: 32px; flex: 0 0 auto; border-radius: 9px; background: var(--es-cyan-soft); color: var(--es-cyan-dark); display: grid; place-items: center; font-size: 18px; }
        a.sg-cond-op b { display: block; font-size: 13.5px; }
        a.sg-cond-op small { display: block; font-size: 12px; color: var(--es-muted); line-height: 1.35; }

        /* ---- la pestaña Componentes ---- */
        .sg-es-card { padding: 20px; }
        .sg-es-barra { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 14px; }
        .sg-es-barra h3 { margin: 0; font-size: 20px; font-weight: 800; color: var(--es-ink); }
        .sg-es-barra p { margin: 2px 0 0; color: var(--es-muted); font-size: 13.5px; }
        .sg-es-barra .sg-ot-btn { min-height: 40px; }

        .sg-es-regla { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 10px 20px; padding: 10px 14px; margin-bottom: 18px;
            border-radius: 12px; background: var(--es-canvas); font-size: 13px; color: #4A556D; }
        .sg-es-regla-txt { display: flex; gap: 8px; align-items: flex-start; flex: 1 1 360px; }
        .sg-es-regla-txt > i { color: var(--es-purple); font-size: 18px; line-height: 1; }
        .sg-es-regla b { color: var(--es-ink); }
        .sg-es-leyenda { display: flex; flex-wrap: wrap; gap: 14px; font-size: 12.5px; font-weight: 700; color: #4A556D; }
        .sg-es-leyenda span { display: inline-flex; align-items: center; gap: 6px; }
        .sg-es-leyenda i { width: 11px; height: 11px; border-radius: 3px; display: inline-block; }
        .sg-es-leyenda i.es-equipo { background: var(--es-purple); } .sg-es-leyenda i.es-sub { background: var(--es-blue); }
        .sg-es-leyenda i.es-comp { background: var(--es-cyan); } .sg-es-leyenda i.es-rep { background: var(--es-rep); }

        /* El diagrama usa todo el ancho: con el detalle fijo al lado, las tres
           columnas quedaban de 200px y los nombres se partian en tres lineas. */
        .sg-es-layout { display: block; }

        /* el recuadro de cada subactivo, con SUS componentes adentro */
        .sg-es-grupo { margin-bottom: 10px; padding: 6px; border: 1px solid #D6E6FA; border-radius: 14px; background: #F7FBFF; }
        .sg-es-grupo > .sg-es-item { margin-bottom: 6px; }
        .sg-es-grupo-hijos { position: relative; margin: 0 0 2px 14px; padding-left: 12px; border-left: 2px solid #BFE9EA; }
        .sg-es-grupo-tit { display: flex; align-items: center; gap: 4px; margin: 2px 0 6px; font-size: 11.5px; font-weight: 800; color: #007F8A; }
        .sg-es-grupo-vacio { display: block; padding: 2px 0 6px; font-size: 12px; color: #68738A; }
        .sg-es-item.es-mini { min-height: 40px; padding: 7px 10px; margin-bottom: 6px; }
        .sg-es-item.es-mini b { font-size: 13px; }

        /* el equipo arriba */
        .sg-es-raiz { position: relative; display: flex; align-items: center; gap: 14px; max-width: 420px; margin: 0 auto; padding: 14px 16px;
            border: 2px solid var(--es-purple); border-radius: 16px; background: var(--es-purple-soft); }
        .sg-es-raiz .ico { width: 48px; height: 48px; flex: 0 0 auto; border-radius: 12px; background: var(--es-purple); color: #fff; display: grid; place-items: center; font-size: 26px; overflow: hidden; }
        .sg-es-raiz .ico img { width: 100%; height: 100%; object-fit: cover; }
        .sg-es-raiz b { display: block; font-size: 17px; color: var(--es-ink); line-height: 1.25; }
        .sg-es-raiz small { display: block; color: #4A556D; font-size: 12.5px; }
        .sg-es-raiz .sg-es-chip { margin-left: auto; }
        .sg-es-raiz-padre { text-align: center; margin: 0 0 8px; font-size: 13px; color: #4A556D; }
        .sg-es-raiz-padre a { color: var(--es-blue-dark); font-weight: 800; }
        .sg-es-etq { display: inline-block; font-size: 10.5px; font-weight: 800; letter-spacing: .06em; text-transform: uppercase; padding: 2px 8px; border-radius: 999px; }
        .sg-es-etq.es-activo { background: var(--es-purple); color: #fff; margin-bottom: 3px; }
        .sg-es-etq.es-sub { background: var(--es-blue-soft); color: var(--es-blue-dark); }
        .sg-es-etq.es-comp { background: var(--es-cyan-soft); color: var(--es-cyan-dark); }
        .sg-es-etq.es-rep { background: var(--es-rep-soft); color: var(--es-rep-ink); }

        /* las tres ramas, con su conector */
        .sg-es-tronco { width: 2px; height: 18px; margin: 0 auto; background: #CFD6E3; }
        .sg-es-ramas { position: relative; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; padding-top: 18px; }
        .sg-es-ramas::before { content: ""; position: absolute; top: 0; left: calc(100% / 6); right: calc(100% / 6); height: 2px; background: #CFD6E3; }
        .sg-es-col { position: relative; min-width: 0; padding: 14px; border: 1px solid var(--es-line); border-radius: 14px; background: #fff; }
        .sg-es-col::before { content: ""; position: absolute; top: -19px; left: 50%; width: 2px; height: 18px; background: #CFD6E3; }
        .sg-es-col.es-sub { border-top: 4px solid var(--es-blue); }
        .sg-es-col.es-comp { border-top: 4px solid var(--es-cyan); }
        .sg-es-col.es-rep { border-top: 4px solid var(--es-rep); }
        @media (max-width: 900px) {
            .sg-es-ramas { grid-template-columns: minmax(0, 1fr); }
            .sg-es-ramas::before, .sg-es-col::before { display: none; }
        }
        .sg-es-col h4 { margin: 0; display: flex; align-items: center; gap: 8px; font-size: 15px; font-weight: 800; color: var(--es-ink); }
        .sg-es-col h4 > i { width: 28px; height: 28px; border-radius: 8px; display: grid; place-items: center; font-size: 17px; }
        .sg-es-col.es-sub h4 > i { background: var(--es-blue-soft); color: var(--es-blue-dark); }
        .sg-es-col.es-comp h4 > i { background: var(--es-cyan-soft); color: var(--es-cyan-dark); }
        .sg-es-col.es-rep h4 > i { background: var(--es-rep-soft); color: var(--es-rep-ink); }
        .sg-es-col h4 .n { margin-left: auto; min-width: 24px; text-align: center; font-size: 12px; padding: 2px 8px; border-radius: 999px; background: var(--es-canvas); color: #4A556D; }
        .sg-es-que { margin: 6px 0 12px; font-size: 12.5px; color: var(--es-muted); line-height: 1.45; }

        /* cada elemento: nombre arriba, chip de estado abajo (nunca se monta) */
        .sg-es-item { position: relative; display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 4px 8px; align-items: start; width: 100%; min-height: 44px;
            margin-bottom: 8px; padding: 10px 12px; border: 1.5px solid var(--es-line); border-radius: 12px; background: #fff; color: var(--es-ink);
            font: inherit; text-align: left; cursor: pointer; }
        .sg-es-item:hover { background: #FAFBFD; }
        .sg-es-item:focus-visible { outline: 3px solid rgba(22, 198, 201, .27); outline-offset: 1px; }
        .sg-es-item.es-sub:hover, .sg-es-item.es-sub.es-viendo { border-color: var(--es-blue); }
        .sg-es-item.es-comp:hover, .sg-es-item.es-comp.es-viendo { border-color: var(--es-cyan); }
        .sg-es-item.es-rep:hover, .sg-es-item.es-rep.es-viendo { border-color: var(--es-rep); }
        .sg-es-item.es-viendo { box-shadow: 0 0 0 3px rgba(22, 198, 201, .14); }
        .sg-es-item .t { min-width: 0; }
        .sg-es-item b { display: block; font-size: 13.5px; line-height: 1.3; overflow-wrap: anywhere; }
        .sg-es-item span.d { display: block; margin-top: 1px; font-size: 12px; color: var(--es-muted); overflow-wrap: anywhere; }
        .sg-es-item .sg-es-chip { grid-column: 1; justify-self: start; }
        .sg-es-item .flecha { grid-column: 2; grid-row: 1; color: #A9B1C3; font-size: 18px; line-height: 1; }
        .sg-es-viendo-tag { display: none; grid-column: 2; grid-row: 2; align-self: end; font-size: 10px; font-weight: 800; letter-spacing: .06em; color: var(--es-cyan-dark); }
        .sg-es-item.es-viendo .sg-es-viendo-tag { display: block; }
        .sg-es-item.es-hijo { width: calc(100% - 18px); margin-left: 18px; }
        .sg-es-item.es-hijo::before { content: ""; position: absolute; left: -12px; top: -9px; width: 10px; height: 30px; border-left: 2px solid #CFD6E3; border-bottom: 2px solid #CFD6E3; border-bottom-left-radius: 6px; }
        .sg-es-item.es-retirada { display: none; background: var(--es-canvas); }
        .sg-es-col.ver-retiradas .sg-es-item.es-retirada { display: grid; }
        /* con foto: la foto a la izquierda, el nombre y el estado al medio, la flecha a la derecha */
        .sg-es-item.con-foto { grid-template-columns: 48px minmax(0, 1fr) auto; gap: 4px 12px; text-align: left; align-items: center; }
        .sg-es-item.con-foto .sg-es-mini { grid-column: 1; grid-row: 1 / span 2; width: 48px; height: 48px; border-radius: 12px; overflow: hidden; background: #fff; border: 1px solid var(--es-line); }
        .sg-es-item .sg-es-mini img { width: 100%; height: 100%; object-fit: cover; display: block; }
        .sg-es-item.con-foto .t { grid-column: 2; grid-row: 1; }
        .sg-es-item.con-foto .flecha { grid-column: 3; grid-row: 1 / span 2; align-self: center; }
        .sg-es-item.con-foto .sg-es-chip { grid-column: 2; grid-row: 2; }
        .sg-es-chip { display: inline-flex; align-items: center; gap: 4px; padding: 2px 9px; border-radius: 999px; font-size: 11.5px; font-weight: 800; white-space: nowrap; max-width: 100%; }
        .sg-es-chip::before { content: ""; width: 6px; height: 6px; border-radius: 50%; background: currentColor; }
        .sg-es-chip.es-ok { background: var(--es-success-soft); color: var(--es-success); }
        .sg-es-chip.es-ojo { background: var(--es-warning-soft); color: var(--es-warning); }
        .sg-es-chip.es-mal { background: var(--es-danger-soft); color: var(--es-danger); }
        .sg-es-chip.es-neutro { background: var(--es-canvas); color: var(--es-muted); }
        .sg-es-vacio { padding: 14px; border: 1.5px dashed var(--es-line); border-radius: 12px; color: var(--es-muted); font-size: 12.5px; text-align: center; line-height: 1.45; }
        .sg-es-vacio a { display: inline-block; margin-top: 4px; color: var(--es-blue-dark); font-weight: 800; text-decoration: none; }
        .sg-es-mas { display: inline-flex; align-items: center; gap: 4px; min-height: 32px; padding: 0; border: 0; background: none; color: var(--es-blue-dark);
            font: inherit; font-size: 12.5px; font-weight: 800; cursor: pointer; text-decoration: none; }
        .sg-es-mas:hover { text-decoration: underline; }

        /* el detalle de lo elegido */
        /* El detalle se abre como panel a la derecha al tocar un elemento y
           se cierra con la X o con Escape. */
        .sg-es-det { position: fixed; top: 0; right: 0; bottom: 0; z-index: 2500; width: 400px; max-width: 100vw; overflow: auto; padding: 20px;
            background: #fff; border-left: 1px solid var(--es-line); box-shadow: -24px 0 48px -24px rgba(23, 34, 59, .45);
            transform: translateX(105%); transition: transform .2s ease; visibility: hidden; }
        .sg-es-det.es-abierto { transform: none; visibility: visible; }
        .sg-es-det-x { position: absolute; top: 12px; right: 12px; width: 40px; height: 40px; border: 0; border-radius: 10px; background: #F4F6FA; color: #17223B; font-size: 20px; cursor: pointer; }
        .sg-es-det-x:hover { background: #E9ECF3; }
        .sg-es-det .sg-es-det-cab { padding-right: 44px; }
        .sg-es-det.es-sub { border-top: 5px solid var(--es-blue); } .sg-es-det.es-comp { border-top: 5px solid var(--es-cyan); } .sg-es-det.es-rep { border-top: 5px solid var(--es-rep); }
        .sg-es-det-vacio { display: grid; place-items: center; gap: 8px; margin: 0; padding: 30px 10px; text-align: center; color: var(--es-muted); font-size: 13px; }
        .sg-es-det-vacio i { font-size: 28px; color: #A9B1C3; }
        .sg-es-det-cab { display: flex; gap: 12px; align-items: flex-start; margin-bottom: 12px; }
        .sg-es-det-ico { width: 40px; height: 40px; flex: 0 0 auto; border-radius: 10px; display: grid; place-items: center; font-size: 22px; }
        .sg-es-det.es-sub .sg-es-det-ico { background: var(--es-blue-soft); color: var(--es-blue-dark); }
        .sg-es-det.es-comp .sg-es-det-ico { background: var(--es-cyan-soft); color: var(--es-cyan-dark); }
        .sg-es-det.es-rep .sg-es-det-ico { background: var(--es-rep-soft); color: var(--es-rep-ink); }
        .sg-es-det-nom { display: block; font-size: 16px; font-weight: 800; color: var(--es-ink); line-height: 1.3; overflow-wrap: anywhere; }
        .sg-es-det-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 6px; }
        .sg-es-det-nota { display: flex; gap: 8px; align-items: flex-start; margin-bottom: 12px; padding: 10px 12px; border-radius: 10px; background: var(--es-warning-soft); color: #7A3E00; font-size: 13px; line-height: 1.45; }
        .sg-es-det-nota > i { color: var(--es-warning); font-size: 17px; line-height: 1.2; }
        .sg-es-det-datos { display: grid; grid-template-columns: auto minmax(0, 1fr); gap: 0; margin: 0 0 12px; font-size: 13px; }
        .sg-es-det-datos dt, .sg-es-det-datos dd { margin: 0; padding: 7px 0; border-bottom: 1px solid #EEF1F6; }
        .sg-es-det-datos dt { padding-right: 14px; color: var(--es-muted); font-weight: 600; }
        .sg-es-det-datos dd { color: var(--es-ink); font-weight: 700; overflow-wrap: anywhere; }
        .sg-es-det-datos dd a { color: var(--es-blue-dark); }
        .sg-es-det h5 { margin: 4px 0 8px; font-size: 13px; font-weight: 800; color: var(--es-ink); }
        .sg-es-det-rep { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; padding: 8px 10px; border: 1px solid var(--es-line); border-radius: 10px; font-size: 13px; }
        .sg-es-det-rep > i { color: var(--es-rep); font-size: 17px; }
        .sg-es-det-rep > span:nth-child(2) { flex: 1 1 auto; min-width: 0; font-weight: 700; }
        .sg-es-det-acc { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 14px; }
        .sg-es-det-acc .sg-ot-btn { min-height: 40px; }
        .sg-es-det-pie { margin: 12px 0 0; font-size: 12px; color: var(--es-muted); }

        /* listado en arbol: chips con el mismo color del diagrama */
        .sg-lista-chips { display: flex; flex-wrap: wrap; gap: 4px; margin-top: 4px; }
        .sg-lista-chips em { font-style: normal; display: inline-flex; align-items: center; gap: 3px; padding: 1px 7px; border-radius: 999px; font-size: 11px; font-weight: 800; }
        .sg-lista-chips em.es-sub { background: var(--es-blue-soft); color: var(--es-blue-dark); }
        .sg-lista-chips em.es-comp { background: var(--es-cyan-soft); color: var(--es-cyan-dark); }
        .sg-lista-chips em.es-rep { background: var(--es-rep-soft); color: var(--es-rep-ink); }
        .sg-lista-fila.es-hijo { background: #FBFCFE; }
        .sg-lista-rama { color: var(--es-blue); margin-right: 4px; }
        /* "En mantenimiento" no cabia y se montaba sobre la criticidad: que baje de linea */
        .sg-lista-fila .sg-ot-chip { white-space: normal; max-width: 100%; line-height: 1.25; }

        /* ---- asistente "¿Qué vas a agregar?" ---- */
        .sg-es-asis { position: fixed; inset: 0; z-index: 3000; display: none; align-items: center; justify-content: center; background: rgba(23, 34, 59, .5); padding: 16px; }
        .sg-es-asis.es-abierto { display: flex; }
        .sg-es-asis-caja { width: 100%; max-width: 880px; max-height: calc(100vh - 32px); overflow: auto; padding: 22px 24px; border-radius: 18px; background: #fff; box-shadow: 0 24px 64px rgba(23, 34, 59, .35); color: #17223B; }
        .sg-es-asis-cab { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 16px; }
        .sg-es-asis-cab small { display: block; font-size: 12.5px; font-weight: 700; color: #68738A; }
        .sg-es-asis-cab h3 { margin: 2px 0 2px; font-size: 21px; font-weight: 800; color: #17223B; }
        .sg-es-asis-cab p { margin: 0; color: #68738A; font-size: 13.5px; }
        .sg-es-asis-x { width: 40px; height: 40px; flex: 0 0 auto; border: 0; border-radius: 10px; background: #F4F6FA; color: #17223B; font-size: 20px; cursor: pointer; }
        .sg-es-asis-x:hover { background: #E9ECF3; }
        .sg-es-opciones { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; margin-bottom: 14px; }
        @media (max-width: 760px) { .sg-es-opciones { grid-template-columns: minmax(0, 1fr); } }
        .sg-es-op { display: flex; flex-direction: column; align-items: flex-start; gap: 8px; padding: 16px; border: 2px solid #E2E7F0; border-radius: 16px; background: #fff;
            color: #17223B; font: inherit; text-align: left; cursor: pointer; }
        .sg-es-op:hover { border-color: #C9D1E0; background: #FAFBFD; }
        .sg-es-op:focus-visible { outline: 3px solid rgba(22, 198, 201, .3); outline-offset: 1px; }
        .sg-es-op.es-elegida { border-color: #6732F4; background: #FBFAFF; box-shadow: 0 0 0 3px #F2EFFF; }
        .sg-es-op-top { display: flex; justify-content: space-between; align-items: center; width: 100%; }
        .sg-es-op-ico { width: 40px; height: 40px; border-radius: 11px; display: grid; place-items: center; font-size: 22px; }
        .sg-es-op.es-sub .sg-es-op-ico { background: #EAF4FF; color: #0565C2; }
        .sg-es-op.es-comp .sg-es-op-ico { background: #E8FBFB; color: #007F8A; }
        .sg-es-op.es-rep .sg-es-op-ico { background: #FFF4E0; color: #8F4E00; }
        .sg-es-op-radio { width: 20px; height: 20px; border-radius: 50%; border: 2px solid #CFD6E3; box-sizing: border-box; }
        .sg-es-op.es-elegida .sg-es-op-radio { border: 6px solid #6732F4; }
        .sg-es-op b { font-size: 15.5px; line-height: 1.3; }
        .sg-es-op .regla { font-size: 13px; color: #4A556D; line-height: 1.45; }
        .sg-es-op .ej { margin-top: auto; padding-top: 8px; width: 100%; border-top: 1px solid #EEF1F6; font-size: 12.5px; color: #68738A; }
        .sg-es-op .ej b { font-size: 12.5px; color: #17223B; }
        .sg-es-regla.es-chica { margin-bottom: 0; }
        .sg-es-asis-pie { display: flex; justify-content: flex-end; align-items: center; gap: 8px; margin-top: 16px; padding-top: 14px; border-top: 1px solid #E2E7F0; }
        .sg-es-asis-pie .sg-ot-btn { min-height: 40px; }
        .sg-es-asis-pie .sg-ot-btn:disabled { opacity: .42; cursor: not-allowed; filter: none; }
        .sg-ot-btn.es-fantasma { background: #F2EFFF; border-color: #F2EFFF; color: #4820C9 !important; }
        .sg-ot-btn.es-fantasma:hover { background: #E6E0FF; }
        /* El asistente vive fuera de .sg-a3: sus botones llevan su color propio
           (sin esto "Continuar" quedaba blanco sobre blanco). */
        .sg-es-asis .sg-ot-btn.es-primario { background: #6732F4; border-color: #6732F4; color: #fff !important; }
        .sg-es-asis .sg-ot-btn.es-primario:hover { background: #4820C9; filter: none; }
        .sg-es-asis .sg-ot-btn.es-plano { background: #fff; border: 1px solid #E2E7F0; color: #17223B !important; }
        .sg-es-volver { display: inline-flex; align-items: center; gap: 4px; min-height: 32px; padding: 0; margin-bottom: 4px; border: 0; background: none;
            color: #0565C2; font: inherit; font-size: 13px; font-weight: 800; cursor: pointer; }
        .sg-es-asis-caja.es-ancha { max-width: 1120px; height: calc(100vh - 32px); display: flex; flex-direction: column; }
        .sg-es-vista.es-marco { display: flex; flex-direction: column; flex: 1 1 auto; min-height: 0; }
        .sg-es-vista.es-marco[hidden] { display: none; }
        #sgEsMarco { flex: 1 1 auto; width: 100%; min-height: 0; border: 0; border-top: 1px solid #E2E7F0; }
        .sg-es-form { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px 20px; }
        @media (max-width: 700px) { .sg-es-form { grid-template-columns: minmax(0, 1fr); } }
        .sg-es-campo { display: flex; flex-direction: column; gap: 6px; min-width: 0; margin: 0; }
        .sg-es-campo.es-ancho { grid-column: 1 / -1; }
        .sg-es-etiq { font-size: 12px; font-weight: 800; color: #4A556D; }
        .sg-es-etiq .req { color: #C7352B; }
        .sg-es-campo input[type="text"], .sg-es-campo input[type="date"], .sg-es-campo select, .sg-es-campo textarea {
            width: 100%; min-height: 40px; box-sizing: border-box; padding: 8px 12px; border: 1px solid #CFD6E3; border-radius: 9px; background: #fff;
            color: #17223B; font: inherit; font-size: 14px; }
        .sg-es-campo textarea { min-height: 64px; resize: vertical; }
        .sg-es-campo input:focus, .sg-es-campo select:focus, .sg-es-campo textarea:focus { outline: 3px solid rgba(22, 198, 201, .27); border-color: #007F8A; }
        .sg-es-ayuda { font-size: 12px; color: #68738A; }
        .sg-es-msg { display: none; font-size: 12px; font-weight: 700; color: #C7352B; }
        .sg-es-campo.es-falta .sg-es-msg { display: block; }
        .sg-es-campo.es-falta .sg-es-etiq { color: #C7352B; }
        .sg-es-campo.es-falta input { border-color: #C7352B; background: #FFFAF9; }
        .sg-es-campo.es-falta .sg-es-ayuda { display: none; }
        .sg-es-faltan { display: flex; gap: 8px; align-items: center; margin-bottom: 14px; padding: 10px 12px; border: 1px solid #F2B8B3; border-radius: 12px;
            background: #FDECEA; color: #7A1F18; font-size: 13.5px; font-weight: 700; }
        .sg-es-faltan[hidden] { display: none; }
        .sg-es-faltan i { font-size: 20px; color: #C7352B; }

        /* ---- Listado (maqueta A1): cabecera, menus, vistas, leyenda ---- */
        .sg-lista-top h3 { font-size: 20px; font-weight: 800; }
        .sg-lista-acc { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
        .sg-lista-acc .sg-ot-btn { min-height: 40px; }
        .sg-menu-btn { position: relative; }
        .sg-menu-lista { position: absolute; right: 0; top: calc(100% + 6px); z-index: 40; display: none; width: 300px; padding: 6px; background: #fff;
            border: 1px solid #E2E7F0; border-radius: 14px; box-shadow: 0 20px 44px -12px rgba(23, 34, 59, .38); text-align: left; }
        .sg-menu-lista.es-ancha { width: 340px; }
        .sg-menu-btn.es-abierto .sg-menu-lista { display: block; }
        .sg-menu-tit { padding: 8px 10px 4px; font-size: 11px; font-weight: 800; letter-spacing: .05em; text-transform: uppercase; color: #68738A; }
        a.sg-menu-op, a.sg-menu-op:hover { display: flex; gap: 10px; align-items: flex-start; padding: 9px 10px; border-radius: 10px; color: #17223B; text-decoration: none; }
        a.sg-menu-op:hover { background: #F4F6FA; }
        a.sg-menu-op > i { width: 32px; height: 32px; flex: 0 0 auto; border-radius: 9px; background: #EAF4FF; color: #0565C2; display: grid; place-items: center; font-size: 18px; }
        a.sg-menu-op > i.es-comp { background: #E8FBFB; color: #007F8A; }
        a.sg-menu-op > i.es-cat { background: #F2EFFF; color: #6732F4; }
        a.sg-menu-op b { display: block; font-size: 13.5px; }
        a.sg-menu-op small { display: block; font-size: 12px; color: #68738A; line-height: 1.35; }

        .sg-lista-vistas { display: inline-flex; gap: 4px; padding: 4px; margin: 4px 0 14px; border-radius: 12px; background: #F4F6FA; }
        .sg-lista-vista { display: inline-flex; align-items: center; gap: 8px; min-height: 40px; padding: 0 16px; border: 0; border-radius: 9px; background: transparent;
            color: #68738A; font: inherit; font-size: 14px; font-weight: 700; cursor: pointer; }
        .sg-lista-vista b { min-width: 22px; padding: 1px 7px; border-radius: 999px; background: #fff; color: #4A556D; font-size: 12px; }
        .sg-lista-vista.es-activa { background: #fff; color: #4820C9; box-shadow: 0 1px 3px rgba(23, 34, 59, .12); }
        .sg-lista-vista.es-activa b { background: #F2EFFF; color: #4820C9; }
        .sg-lista-vista:focus-visible { outline: 3px solid rgba(22, 198, 201, .27); }
        .sg-lista-leyenda { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 10px; margin: 0 0 10px; font-size: 12.5px; color: #68738A; }
        .sg-lista-leyenda em { font-style: normal; display: inline-flex; align-items: center; gap: 4px; padding: 2px 9px; border-radius: 999px; font-size: 12px; font-weight: 800; }
        .sg-lista-leyenda em.es-sub { background: #EAF4FF; color: #0565C2; } .sg-lista-leyenda em.es-comp { background: #E8FBFB; color: #007F8A; } .sg-lista-leyenda em.es-rep { background: #FFF4E0; color: #8F4E00; }

        /* vista de componentes: un grupo por activo */
        .sg-lc-grupo { margin-bottom: 14px; border: 1px solid #E2E7F0; border-radius: 14px; overflow: hidden; background: #fff; }
        .sg-lc-cab { display: flex; align-items: center; gap: 12px; padding: 12px 14px; background: #FBFCFE; border-bottom: 1px solid #E2E7F0; }
        .sg-lc-cab .ico { width: 36px; height: 36px; border-radius: 10px; display: grid; place-items: center; font-size: 19px; flex: 0 0 auto; }
        .sg-lc-cab.es-activo .ico { background: #F2EFFF; color: #6732F4; } .sg-lc-cab.es-sub .ico { background: #EAF4FF; color: #0565C2; }
        .sg-lc-cab b { display: block; font-size: 14.5px; color: #17223B; } .sg-lc-cab small { display: block; font-size: 12px; color: #68738A; }
        .sg-lc-cab .sg-es-etq { margin-left: 4px; vertical-align: 1px; }
        .sg-lc-cab .der { margin-left: auto; }
        .sg-lc-fila { display: grid; grid-template-columns: 48px minmax(0, 2fr) minmax(0, 1.4fr) minmax(0, 1fr) 140px 110px; gap: 12px; align-items: center;
            min-height: 60px; padding: 8px 14px; border-bottom: 1px solid #EEF1F6; }
        .sg-lc-fila:last-child { border-bottom: 0; }
        .sg-lc-fila:hover { background: #FAFBFD; }
        .sg-lc-fila.es-hijo .t { padding-left: 22px; }
        .sg-lc-fila .t b { display: block; font-size: 14px; color: #17223B; } .sg-lc-fila .t span { display: block; font-size: 12px; color: #68738A; }
        .sg-lc-fila .d { font-size: 13px; color: #4A556D; } .sg-lc-fila .f { font-size: 12.5px; color: #68738A; }
        .sg-lc-foto { width: 44px; height: 44px; border-radius: 10px; background: #E8FBFB; color: #007F8A; display: grid; place-items: center; font-size: 20px; overflow: hidden; }
        .sg-lc-foto img { width: 100%; height: 100%; object-fit: cover; }
        /* la observacion del estado, debajo del chip (bloque 356) */
        .sg-lc-fila .e { display: flex; flex-direction: column; align-items: flex-start; gap: 3px; min-width: 0; }
        .sg-lc-obs { font-size: 12px; color: #9A4D00; line-height: 1.35; overflow-wrap: anywhere; }
        /* con foto: la del activo o la del componente, no el icono */
        .sg-lc-cab .ico.es-foto { width: 48px; height: 48px; border-radius: 12px; overflow: hidden; background: #F4F6FA; padding: 0; }
        .sg-lc-cab .ico.es-foto img, .sg-lc-foto.es-foto img { width: 100%; height: 100%; object-fit: cover; display: block; }
        .sg-lc-foto.es-foto { background: #F4F6FA; }
        .sg-lc-cabcol { display: grid; grid-template-columns: 48px minmax(0, 2fr) minmax(0, 1.4fr) minmax(0, 1fr) 140px 110px; gap: 12px; padding: 0 14px 8px;
            font-size: 11.5px; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; color: #68738A; }
        @media (max-width: 1000px) {
            .sg-lc-cabcol { display: none; }
            .sg-lc-fila { grid-template-columns: 48px minmax(0, 1fr) auto; }
            .sg-lc-fila .d, .sg-lc-fila .f { display: none; }
        }
        .sg-lista-comp-vacio { padding: 24px; text-align: center; color: #68738A; }
    </style>

    <%-- La version sale de la fecha del archivo: con `?vrs=1` fijo, el
         navegador se quedaba con la copia vieja y las correcciones se
         publicaban sin llegar. --%>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-activo360.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-orden.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/gsap/Flip.min.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/gsap/Draggable.min.js") %>'></script>
    <script type="text/javascript">
        /* El modulo de activos no muestra el velo de carga: se ve pegado. */
        window.SIGMA_SIN_VELO = true;
        window.SIGMA_PLANTA = {
            ws: '<%=ResolveUrl("~/WebService/WsActivos.asmx") %>',
            raiz: '<%=ResolveUrl("~/") %>',
            three: '<%=ResolveUrl("~/Js/three/") %>',
            urlComponente: '<%=ResolveUrl("~/View/Activos/Componentes/ActivoComponente.aspx") %>',
            urls: {
                variables: '<%=ResolveUrl("~/View/Activos/Variables/ActivoVariable.aspx") %>',
                medidores: '<%=ResolveUrl("~/View/Activos/Medidores/ActivoMedidor.aspx") %>',
                tipos: '<%=ResolveUrl("~/View/Activos/Tipos/ActivoTipo.aspx") %>',
                modelos: '<%=ResolveUrl("~/View/Activos/Modelos/ActivoModelo.aspx") %>',
                serie: '<%=ResolveUrl("~/View/Activos/Variables/ActivoVariableSerie.aspx") %>'
            },
            exportar: '<%=lnkExportarLista.ClientID %>'
        };
    </script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-planta.js") %>'></script>
</asp:Content>

<%-- El rotulo dice el modulo, no la pantalla: el titulo ya dice cual es. --%>
<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Control de activos</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server"><asp:Literal ID="litTitulo" runat="server" Text="Centro de activos 360°" /></asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    <asp:Literal ID="litSubtitulo" runat="server" Text="Historial, mantenimiento y condición de tus activos." />
</asp:Content>

<%-- LA BUSQUEDA AVANZADA DEL SITIO NO SIRVE EN EL CENTRO

     El `wucFiltro` del encabezado trae un cuadro de texto que busca contra
     SEL_ACTIVO. Aca eso no hace nada visible: la lista ya se filtra en el
     navegador con su propio buscador, y una vez abierto un activo el centro
     no es una lista, asi que escribir "ot-20" arriba y apretar Buscar no
     cambiaba una sola fila.

     Los combos de planta, area y linea SI filtraban de verdad, y por eso no
     se borraron: bajaron a la barra de la lista, donde estan las cosas que
     afectan a lo que se ve. Siguen siendo de servidor -con postback- porque
     "Exportar" entrega lo que el filtro dejo, y para eso el servidor tiene
     que saber cual es. --%>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para consultar sus activos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:HiddenField ID="hdnActivo" runat="server" Value="0" />

            <%-- La seccion abierta viaja en un campo oculto: un postback
                 asincrono repinta el bloque entero y sin esto siempre volveria
                 al Resumen. --%>
            <asp:HiddenField ID="hdnSeccion" runat="server" Value="resumen" ClientIDMode="Static" />
            <asp:LinkButton ID="lnkRecargar" runat="server" style="display:none" CausesValidation="false" />

            <%-- ====== LA LISTA DE EQUIPOS ====== --%>
            <asp:Panel ID="pnlLista" runat="server" Visible="false">
<%-- ====== LAS VISTAS DE LA PLANTA (rediseño 05-10-2026) ======
     Encabezado navy, indicadores, pestañas del modulo y, en «Activos», el
     menu «Ver como» con Lista, Tarjetas, Mapa por areas y Vista 3D. Lo dibuja
     Js/sigma-planta.js con los datos de WsActivos.asmx; la unica referencia
     es docs/rediseno-activos/sigma-activos-referencia.html. --%>
<div class="sgap is-cargando" id="saPlanta">
<div class="wrap">
  <header class="hero">
    <div class="hero-top">
      <div class="hero-title">
        <span class="hero-eyebrow">Control de activos</span>
        <h1>Centro de activos 360°</h1>
        <p>Historial, mantenimiento y condición de tus activos.</p>
      </div>
      <div class="hero-actions">
        <%-- la planta que se ve: un combo si la persona tiene mas de una --%><div class="sa-planta" id="saPlantaSel" hidden></div>
        <div class="menu-wrap">
          <button type="button" class="btn btn--hero" id="btnIO" aria-haspopup="menu" aria-expanded="false" aria-controls="menuIO"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 17V5M3 9l4-4 4 4M17 7v12M13 15l4 4 4-4"/></svg>Importar o exportar<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg></button>
          <div class="menu" id="menuIO" role="menu" hidden>
            <button type="button" role="menuitem" data-io="import"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 15V4M7 9l5-5 5 5M4 15v5h16v-5"/></svg><span><b>Importar desde Excel</b><small>Carga muchos activos de una vez</small></span></button>
            <button type="button" role="menuitem" data-io="template"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14 3H6v18h12V7l-4-4zM14 3v4h4M9 13h6M9 17h6"/></svg><span><b>Descargar plantilla</b><small>El Excel con las columnas listas para llenar</small></span></button>
            <button type="button" role="menuitem" data-io="export"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M4 20h16"/></svg><span><b>Exportar a Excel</b><small>Los activos que estás viendo ahora</small></span></button>
          </div>
        </div>
        <button type="button" class="btn btn--primary btn--glow" id="btnNuevo"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>Nuevo activo</button>
      </div>
    </div>
  </header>
  <section class="kpis" id="pulse" aria-label="Resumen de los activos"></section>

  <section class="panel">
  <nav class="mtabs" id="mtabs" aria-label="Secciones de Control de activos" role="tablist"></nav>
  <%-- Mientras llega la planta: un esqueleto de las tarjetas (la vista con la que se entra), nunca el mapa vacio. --%>
  <div class="sa-cargando sa-esq" id="saCargando" role="status" aria-live="polite">
    <span class="sr">Cargando los activos…</span>
    <div class="sa-esq-barra" aria-hidden="true"><i style="height:40px;width:140px"></i><i style="height:40px;width:140px"></i><i style="height:40px;width:140px"></i></div>
    <div class="sa-esq-cards" aria-hidden="true"><div class="sa-esq-card"><i></i><i style="height:22px;width:62%"></i><i style="height:14px;width:44%"></i><i style="height:64px"></i><i style="height:44px"></i></div><div class="sa-esq-card"><i></i><i style="height:22px;width:62%"></i><i style="height:14px;width:44%"></i><i style="height:64px"></i><i style="height:44px"></i></div><div class="sa-esq-card"><i></i><i style="height:22px;width:62%"></i><i style="height:14px;width:44%"></i><i style="height:64px"></i><i style="height:44px"></i></div><div class="sa-esq-card"><i></i><i style="height:22px;width:62%"></i><i style="height:14px;width:44%"></i><i style="height:64px"></i><i style="height:44px"></i></div></div>
  </div>

  <div class="tabpanel" role="tabpanel" aria-label="Activos" data-mpanel="activos">

  <div class="viewbar">
    <div class="viewbar-l">
      <span class="viewbar-lbl" id="verComo">Ver como</span>
      <div class="seg seg--views" role="group" aria-labelledby="verComo">
        <button type="button" data-view="lista" aria-pressed="false"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"/></svg><span>Lista</span></button>
        <button type="button" data-view="tarjetas" aria-pressed="true"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/></svg><span>Tarjetas</span></button>
        <button type="button" data-view="2d" aria-pressed="false"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="4" width="11" height="8" rx="1.5"/><rect x="16" y="4" width="5" height="16" rx="1.5"/><rect x="3" y="14" width="11" height="6" rx="1.5"/></svg><span>Mapa por áreas</span></button>
        <button type="button" data-view="3d" aria-pressed="false"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3l8 4.5v9L12 21l-8-4.5v-9L12 3zM4 7.5l8 4.5 8-4.5M12 12v9"/></svg><span>Vista 3D</span></button>
      </div>
      <span class="viewbar-help" id="viewHelp"></span>
    </div>
    <button type="button" class="btn btn--secondary" id="btnEstructura" title="Cambia cómo se llaman y se dividen los lugares de tu planta"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3l9 5-9 5-9-5 9-5zM3 12.5l9 5 9-5M3 16.5l9 5 9-5"/></svg><span id="estrLbl">Áreas y líneas</span></button>
  </div>

  <div class="hint" id="hint" hidden>
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.8.8 1 1.5 1 2.5h6c0-1 .2-1.7 1-2.5A6 6 0 0 0 12 3z"/></svg>
    <p id="hintText"></p>
    <button type="button" id="hintClose">Entendido</button>
  </div>

  <div class="work" id="work">
    <aside class="tray" aria-labelledby="trayTitle">
      <div><h2 id="trayTitle">Por ubicar</h2><p id="trayText"></p></div>
      <div class="tray-list" id="tray" data-drop="tray"></div>
      <button type="button" class="btn" id="btnNuevo2"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>Agregar activo aquí</button>
    </aside>
    <div id="view2d"><div class="mapcrumbs-wrap" id="mapCrumbs"></div><div class="map" id="map"></div></div>
    <div id="viewLista" hidden><div class="lv" id="lv"></div></div>
    <div id="viewTarjetas" hidden><div class="tv" id="tv"></div></div>
    <div id="view3d" hidden>
      <div class="scene-wrap" id="sceneWrap">
        <div class="scene" id="scene"></div>
        <div class="labels3d" id="labels3d"></div>
        <div class="scene-fallback" id="sceneFallback" hidden>No se pudo cargar la vista 3D en este navegador. El mapa sigue funcionando igual.</div>
        <div class="s3-top">
          <div class="locnav" id="locnav3d"></div>
        </div>
        <div class="s3-ctl glass" id="ctl3d" role="toolbar" aria-label="Cámara">
          <button type="button" class="cbtn" data-c3="in" aria-label="Acercar" title="Acercar"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg></button>
          <button type="button" class="cbtn" data-c3="out" aria-label="Alejar" title="Alejar"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14"/></svg></button>
          <span class="sep"></span>
          <button type="button" class="cbtn" data-c3="left" aria-label="Girar a la izquierda" title="Girar a la izquierda"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 12a8 8 0 1 0 2.4-5.7M4 4v4h4"/></svg></button>
          <button type="button" class="cbtn" data-c3="right" aria-label="Girar a la derecha" title="Girar a la derecha"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 12a8 8 0 1 1-2.4-5.7M20 4v4h-4"/></svg></button>
          <span class="sep"></span>
          <button type="button" class="cbtn cbtn--txt" data-c3="iso" title="Vista en ángulo">3D</button>
          <button type="button" class="cbtn cbtn--txt" data-c3="top" title="Vista desde arriba">Planta</button>
          <button type="button" class="cbtn cbtn--txt" data-c3="front" title="Vista de frente">Frente</button>
          <span class="sep"></span>
          <button type="button" class="cbtn" data-c3="home" aria-label="Ver toda la planta" title="Ver toda la planta"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 11l9-7 9 7M5 10v10h14V10"/></svg></button>
          <button type="button" class="cbtn" data-c3="spin" aria-label="Giro automático" title="Giro automático" aria-pressed="false"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3a9 9 0 1 0 9 9M21 3v6h-6"/></svg></button>
        </div>
        <aside class="s3-panel glass" id="areaPanel" hidden aria-live="polite"></aside>
        <div class="s3-tour glass" id="tourCard" hidden aria-live="polite"></div>
        <div class="s3-bottom">
          <div class="glass s3-legend">
            <span class="tone-ok"><span class="dot"></span>Operativo</span>
            <span class="tone-warn"><span class="dot"></span>Con aviso</span>
            <span class="tone-bad"><span class="dot"></span>Detenido o fuera de servicio</span>
            <button type="button" class="chipbtn" id="btnOnly" aria-pressed="false">Solo con aviso</button>
          </div>
          <button type="button" class="btn btn--primary btn--sm" id="btnTour"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 3l14 9-14 9V3z"/></svg><span id="tourLbl">Recorrer avisos</span></button>
          <span class="s3-hint">Arrastra para girar · clic derecho para mover · doble clic para acercarte</span>
        </div>
      </div>
    </div>
  </div>
  </div>
  <%-- Las otras pestañas del modulo. Componentes es propia (todas las piezas
       agrupadas por su activo); Variables, Medidores, Tipos y Modelos son
       listas propias que dibuja Js/sigma-planta.js (sin grilla del servidor)
       y abren la ficha de siempre en un modal. --%>
  <div class="tabpanel" role="tabpanel" aria-label="Componentes" data-mpanel="componentes" hidden>
    <%-- Crear un componente desde aqui: el mismo modal del centro 360, eligiendo el activo. --%>
    <div class="sa-cat-bar sa-comp-bar">
      <div class="sa-cat-tit"><h2>Componentes</h2><p>Las partes de cada activo, agrupadas por su activo. Los que tienen avisos van primero y abiertos.</p></div>
      <label class="sa-cat-buscar"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>
        <input type="search" data-cg-q placeholder="Busca un componente, código, tipo o activo…" aria-label="Buscar componentes" autocomplete="off"></label>
      <button type="button" class="btn btn--primary" id="btnNuevoComp" hidden onclick="return escDesdePlanta();">+ Nuevo componente</button>
    </div>
    <div class="sa-cg-filtros" role="group" aria-label="Filtrar por estado">
      <button type="button" class="chipbtn" data-cgf="todos" aria-pressed="true">Todos <b>0</b></button>
      <button type="button" class="chipbtn" data-cgf="aviso" aria-pressed="false">Con aviso <b>0</b></button>
      <button type="button" class="chipbtn" data-cgf="ok" aria-pressed="false">Operativos <b>0</b></button>
    </div>
    <div class="sa-cg" aria-live="polite"></div>
    <%-- La lista la dibuja Js/sigma-planta.js con la planta ya cargada (grupos plegados,
         busqueda y carga por tandas): el servidor ya no arma miles de filas. --%>
    <asp:Literal ID="litListaComp" runat="server" Visible="false" />
  </div>
  <div class="tabpanel" role="tabpanel" aria-label="Variables" data-mpanel="variables" hidden>
    <div class="sa-cat"></div>
  </div>
  <div class="tabpanel" role="tabpanel" aria-label="Medidores" data-mpanel="medidores" hidden>
    <div class="sa-cat"></div>
  </div>
  <div class="tabpanel" role="tabpanel" aria-label="Tipos de activo" data-mpanel="tipos" hidden>
    <div class="sa-cat"></div>
  </div>
  <div class="tabpanel" role="tabpanel" aria-label="Modelos" data-mpanel="modelos" hidden>
    <div class="sa-cat"></div>
  </div>
  </section>
</div>
<!-- Visor de fotos con portada -->
<div class="gal" id="gal" hidden role="dialog" aria-modal="true" aria-label="Fotos del activo"></div>

<!-- Explorador del activo -->
<div class="xp" id="xp" hidden>
  <div class="xp-card" role="dialog" aria-modal="true" aria-labelledby="xpTitle" id="xpCard"></div>
</div>

<!-- Estructura de la planta -->
<div class="modal" id="modalCfg" hidden>
  <div class="modal-card modal-card--wide" role="dialog" aria-modal="true" aria-labelledby="cfgTitle">
    <header>
      <span class="tile-ico"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/></svg></span>
      <h2 id="cfgTitle">Ubicaciones de la planta</h2>
      <button type="button" class="icon-btn" data-close="modalCfg" aria-label="Cerrar"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg></button>
    </header>
    <div class="ub-body">
      <p class="ub-intro">Cada lugar se divide a su manera: un área en líneas, una bodega en pasillos, un edificio en pisos y salas. Un lugar también puede no dividirse. Los activos pueden ir en cualquier lugar.</p>
      <div class="field"><label for="ubPlanta">Nombre de la planta</label><input id="ubPlanta" autocomplete="off"></div>
      <div class="ub-tree" id="ubTree"></div>
    </div>
    <footer class="ub-foot"><span class="ub-note">Los cambios se guardan solos y puedes deshacerlos.</span><button type="button" class="btn btn--primary" data-close="modalCfg">Listo</button></footer>
  </div>
</div>

<div class="lightbox" id="lightbox" hidden role="dialog" aria-modal="true" aria-label="Foto ampliada"><img id="lbImg" alt=""><button type="button" id="lbClose" aria-label="Cerrar foto"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>

<div class="navpop" id="navpop" hidden role="dialog" aria-modal="false" aria-label="Ir a un lugar o activo">
  <div class="np-search"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg><input id="npQ" placeholder="Busca un lugar o un activo…" autocomplete="off" role="combobox" aria-expanded="true" aria-controls="npList" aria-autocomplete="list"><kbd>Esc</kbd></div>
  <div class="np-filters" role="group" aria-label="Filtrar"><button type="button" data-npf="all" aria-pressed="true">Todo</button><button type="button" data-npf="issues" aria-pressed="false">Con avisos</button><button type="button" data-npf="empty" aria-pressed="false">Sin activos</button></div>
  <div class="np-list" id="npList" role="listbox"></div>
  <div class="np-foot"><span><kbd>↑</kbd><kbd>↓</kbd> moverte</span><span><kbd>Enter</kbd> ir</span><span><kbd>/</kbd> abrir desde cualquier parte</span></div>
</div>
<div class="toast" id="toast" role="status" aria-live="polite" hidden><span id="toastMsg"></span><button type="button" id="toastUndo">Deshacer</button></div>
</div>

                <%-- EL LISTADO ANTERIOR, OCULTO. Queda solo porque Exportar a Excel y la
                     carga masiva siguen siendo controles del servidor; el menu
                     «Importar o exportar» de arriba los acciona. --%>
                <div class="sa-legado" hidden>

                <asp:Literal ID="litListaKpis" runat="server" />

                <div class="sg-ot-card">
                    <%-- CABECERA DEL LISTADO (maqueta A1). Todo lo que se crea para
                         armar un activo esta aca, en "Crear": no hace falta ir al
                         menu lateral a buscar tipos, componentes o medidores. --%>
                    <header class="sg-ot-card-cab sg-lista-top">
                        <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-cog-outline"></i></span>
                        <div>
                            <h3>Activos de la planta</h3>
                            <p class="sg-ot-card-sub">Todas las máquinas. Toca una para ver todo sobre ella.</p>
                        </div>
                        <div class="sg-ot-card-acc sg-lista-acc">
                            <div class="sg-menu-btn">
                                <button type="button" class="sg-ot-btn es-contorno" aria-haspopup="true" onclick="return sgMenuBtn(this);"><i class="mdi mdi-swap-vertical"></i>Importar o exportar<i class="mdi mdi-chevron-down"></i></button>
                                <div class="sg-menu-lista" role="menu">
                                    <asp:LinkButton ID="lnkExportarLista" runat="server" CssClass="sg-menu-op"
                                        OnClick="lnkExportarLista_Click"><i class="mdi mdi-download-outline"></i><span><b>Exportar a Excel</b><small>La lista tal como la ves, con sus filtros.</small></span></asp:LinkButton>
                                    <asp:LinkButton ID="lnkCargaMasiva" runat="server" CssClass="sg-menu-op"
                                        OnClientClick="return abrirCargaMasiva();"><i class="mdi mdi-upload-outline"></i><span><b>Carga masiva</b><small>Muchos activos de una vez desde una planilla.</small></span></asp:LinkButton>
                                </div>
                            </div>
                            <asp:Panel ID="pnlCrear" runat="server" CssClass="sg-menu-btn">
                                <button type="button" class="sg-ot-btn es-secundario" aria-haspopup="true" onclick="return sgMenuBtn(this);"><i class="mdi mdi-plus-box-multiple-outline"></i>Crear<i class="mdi mdi-chevron-down"></i></button>
                                <div class="sg-menu-lista es-ancha" role="menu">
                                    <div class="sg-menu-tit">Lo que arma un activo</div>
                                    <a href="#" class="sg-menu-op" onclick="return crearDesdeLista('componente');"><i class="mdi mdi-puzzle-outline es-comp"></i><span><b>Componente</b><small>Una parte de un activo: motor, rodamiento, válvula.</small></span></a>
                                    <a href="#" class="sg-menu-op" onclick="return crearDesdeLista('variable');"><i class="mdi mdi-pulse es-comp"></i><span><b>Variable de condición</b><small>Lo que se mide para saber cómo está: temperatura, presión.</small></span></a>
                                    <a href="#" class="sg-menu-op" onclick="return crearDesdeLista('medidor');"><i class="mdi mdi-counter es-comp"></i><span><b>Medidor</b><small>Lo que cuenta cuánto trabajó: horas, ciclos.</small></span></a>
                                    <div class="sg-menu-tit">Catálogos</div>
                                    <a href="#" class="sg-menu-op" onclick="return crearDesdeLista('tipo');"><i class="mdi mdi-shape-outline es-cat"></i><span><b>Tipo de activo</b><small>Ej.: Cámaras de frío, Hornos, Bombas.</small></span></a>
                                    <a href="#" class="sg-menu-op" onclick="return crearDesdeLista('modelo');"><i class="mdi mdi-tag-outline es-cat"></i><span><b>Modelo</b><small>Ej.: Frigorífica Sur CF-40.</small></span></a>
                                    <a href="#" class="sg-menu-op" onclick="return crearDesdeLista('tipos');"><i class="mdi mdi-format-list-bulleted es-cat"></i><span><b>Ver todos los tipos de activo</b><small>Revisar, renombrar o dar de baja.</small></span></a>
                                </div>
                            </asp:Panel>
                            <asp:LinkButton ID="lnkNuevoActivo" runat="server" CssClass="sg-ot-btn es-primario"
                                OnClientClick="return abrirActivo(0);"><i class="mdi mdi-plus"></i>Nuevo activo</asp:LinkButton>
                        </div>
                    </header>

                    <%-- Activos o componentes: la misma lista vista por sus maquinas
                         o por sus partes. Antes los componentes eran otra pantalla
                         con una grilla vieja en el menu lateral. --%>
                    <div class="sg-lista-vistas" role="tablist" aria-label="Qué ver">
                        <button type="button" class="sg-lista-vista es-activa" role="tab" aria-selected="true" data-vista="activos" onclick="return sgListaVista('activos');"><i class="mdi mdi-cog-outline"></i>Activos <b><asp:Literal ID="litVistaActivos" runat="server" Text="0" /></b></button>
                        <button type="button" class="sg-lista-vista" role="tab" aria-selected="false" data-vista="componentes" onclick="return sgListaVista('componentes');"><i class="mdi mdi-puzzle-outline"></i>Componentes <b><asp:Literal ID="litVistaComp" runat="server" Text="0" /></b></button>
                    </div>

                    <%-- PLANTA, AREA Y LINEA NO HACEN FALTA

                         El buscador de la lista ya compara contra la
                         ubicacion -"Renca · Linea 1" viaja en el texto de
                         cada fila-, asi que escribir "renca" hace lo mismo
                         que la cascada de tres combos, sin tres postbacks ni
                         la regla de que el hijo se vacia cuando cambia el
                         padre.

                         Queda solo "Habilitado", que es el unico que muestra
                         algo que de otra forma no se puede ver: un activo
                         dado de baja no aparece escrito en ninguna parte. --%>
                    <div class="sg-a3-filtros">
                        <%-- El buscador de la lista.

                             No existia: lo que buscaba era el cuadro de la
                             busqueda avanzada del encabezado, que pegaba
                             contra el servidor. Al sacarlo, la lista se
                             quedaba sin ninguna forma de buscar, asi que
                             entra aca y compara contra el texto que cada fila
                             ya trae -codigo, nombre, tipo y ubicacion-. --%>
                        <span class="sg-a3-filtro-buscar">
                            <i class="mdi mdi-magnify"></i>
                            <input type="search" id="sgListaBuscar" autocomplete="off"
                                placeholder="Buscar por código, nombre, tipo o ubicación…" />
                        </span>

                        <label class="sg-a3-filtro"><i class="mdi mdi-check-circle-outline"></i>
                            <span>Mostrar</span>
                            <rad:RadComboBox2 ID="cboHabilitado" runat="server" AutoPostBack="true" Width="100%">
                                <Items>
                                    <rad:RadComboBoxItem Text="Solo los que están en uso" Value="1" />
                                    <rad:RadComboBoxItem Text="También los que ya no se usan" Value="" />
                                    <rad:RadComboBoxItem Text="Solo los que ya no se usan" Value="0" />
                                </Items>
                            </rad:RadComboBox2>
                        </label>
                    </div>

                    <div id="sgVistaActivos" class="sg-lista-vista-panel">
                    <div class="sg-ot-ev-filtros">
                        <div class="sg-ot-ev-tipos" id="sgListaChips">
                            <a href="#" class="sg-a3-chip es-activa" data-lista="todos">Todos <b><asp:Literal ID="litListaTodos" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-lista="atencion"><i class="mdi mdi-alert-outline"></i>Necesitan atención <b><asp:Literal ID="litListaAtencion" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-lista="ot"><i class="mdi mdi-wrench-outline"></i>Con OT abiertas <b><asp:Literal ID="litListaOt" runat="server" Text="0" /></b></a>
                        </div>
                        <select id="sgListaPorPagina" class="sg-ot-select">
                            <option value="10">10 por página</option>
                            <option value="25" selected="selected">25 por página</option>
                            <option value="50">50 por página</option>
                            <option value="0">Todos</option>
                        </select>
                    </div>

                    <div class="sg-lista-leyenda"><span>Debajo de cada activo:</span>
                        <em class="es-sub"><i class="mdi mdi-cogs"></i>Subactivos</em>
                        <em class="es-comp"><i class="mdi mdi-puzzle-outline"></i>Componentes</em>
                        <em class="es-rep"><i class="mdi mdi-package-variant-closed"></i>Repuestos</em></div>

                    <asp:Literal ID="litLista" runat="server" />

                    <div class="sg-lista-pie">
                        <span id="sgListaConteo" class="sg-ot-vacio-txt"></span>
                        <div class="sg-lista-paginas" id="sgListaPaginas"></div>
                    </div>
                    </div>

                    <%-- LOS COMPONENTES DE TODOS LOS ACTIVOS, agrupados por el
                         activo (o subactivo) del que son parte. --%>
                    <div id="sgVistaComp" class="sg-lista-vista-panel" hidden>
                        
                        <p class="sg-lista-comp-vacio" id="sgCompSinRes" hidden>Ningún componente coincide con la búsqueda.</p>
                    </div>
                </div>
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlSinActivo" runat="server" Visible="false" CssClass="sg-ot-vacio">
                <i class="mdi mdi-magnify"></i>
                <p>No hay activos que coincidan</p>
                <span>Ajuste la búsqueda o la ubicación.</span>
            </asp:Panel>

            <%-- ====================================================================
                 EL CENTRO
                 ==================================================================== --%>
            <asp:Panel ID="pnlFicha" runat="server" Visible="false" CssClass="sg-a3 sg-ot sg-a3--v3">

                <%-- La miga usa los nombres del menu: el modulo es "Control de
                     activos" y la pantalla de vuelta es "Activos". Dejarla con
                     los nombres viejos obliga a traducir mentalmente donde
                     esta uno. --%>
                <div class="sg-a3-miga">
                    <asp:LinkButton ID="lnkVolver" runat="server" CssClass="sg-a3-volver" OnClick="btnVolver_Click" CausesValidation="false"><i class="mdi mdi-chevron-left"></i>Volver</asp:LinkButton>
                    <span>Control de activos</span>
                    <span class="sep">/</span>
                    <asp:LinkButton ID="lnkVolverLista" runat="server" OnClick="btnVolver_Click" CausesValidation="false">Activos</asp:LinkButton>
                    <span class="sep">/</span><asp:Literal ID="litMigaActivo" runat="server" />
                </div>

                <%-- La cabecera responde, antes de leer nada, que equipo es, como
                     esta y donde esta; y si es subactivo, de que maquina es parte. --%>
                <header class="sg-a3-hero es-v2">
                    <asp:Literal ID="litHeroFoto" runat="server" />
                    <div class="sg-a3-hero-txt">
                        <h1>
                            <span class="sg-a3-hero-nom"><asp:Literal ID="litHeroNombre" runat="server" /></span>
                            <span class="sg-a3-hero-chips"><asp:Literal ID="litBadges" runat="server" /></span>
                        </h1>
                        <div class="sg-a3-hero-sub"><asp:Literal ID="litHeroSub" runat="server" /></div>
                        <asp:Literal ID="litHeroPadre" runat="server" />
                    </div>

                    <div class="sg-a3-hero-acc">
                        <%-- La etiqueta para pegar en el activo: QR o codigo de barras, en la
                             ventana de impresion de siempre (Comun/Impresion/Etiquetas). --%>
                        <asp:HyperLink ID="hlEtiqueta" runat="server" CssClass="sg-ot-btn es-plano" NavigateUrl="javascript:void(0)" Visible="false"
                            ToolTip="Imprimir la etiqueta del activo con su QR o código de barras"><i class="mdi mdi-qrcode"></i>Etiqueta</asp:HyperLink>
                        <asp:HyperLink ID="hlEditar" runat="server" CssClass="sg-ot-btn es-contorno" NavigateUrl="javascript:void(0)"
                            ToolTip="Editar la ficha del activo"><i class="mdi mdi-pencil-outline"></i>Editar ficha</asp:HyperLink>
                        <asp:HyperLink ID="hlGenerarOT" runat="server" CssClass="sg-ot-btn es-primario">
                            <i class="mdi mdi-plus"></i>Nueva OT
                        </asp:HyperLink>
                    </div>
                </header>

                <%-- ---------------- navegacion: cuatro a la vista, el resto en Mas -------- --%>
                <%-- Barra de pestañas (05-10-2026, como el mockup): blanca, fija al
                     bajar, con las seis principales en una zona que se desplaza
                     (flechas si no caben), «Más» y SIGMA AI siempre a la vista. --%>
                <nav class="sg-a3-nav" aria-label="Secciones del activo">
                    <button type="button" class="sg-a3-flecha es-izq" aria-label="Ver las pestañas anteriores" hidden><i class="mdi mdi-chevron-left"></i></button>
                    <div class="sg-a3-nav-scroll">
                        <%-- Orden pedido por el cliente (04-10-2026): lo que se mira de un
                             activo primero -resumen, su ficha, sus partes y como esta-,
                             despues su historia. --%>
                        <a href="#" class="sg-a3-tab" data-sec="resumen"><i class="mdi mdi-home-outline"></i>Resumen</a>
                        <a href="#" class="sg-a3-tab" data-sec="ficha"><i class="mdi mdi-file-document-outline"></i>Ficha</a>
                        <a href="#" class="sg-a3-tab" data-sec="componentes"><i class="mdi mdi-puzzle-outline"></i>Componentes<asp:Literal ID="litNumComp" runat="server" /></a>
                        <a href="#" class="sg-a3-tab" data-sec="condicion"><i class="mdi mdi-gauge"></i>Condición y medidores<asp:Literal ID="litNumCond" runat="server" /></a>
                        <a href="#" class="sg-a3-tab" data-sec="historial"><i class="mdi mdi-clock-outline"></i>Historial</a>
                        <a href="#" class="sg-a3-tab" data-sec="ordenes"><i class="mdi mdi-clipboard-text-outline"></i>Órdenes de trabajo<asp:Literal ID="litNumOt" runat="server" /></a>
                    </div>
                    <button type="button" class="sg-a3-flecha es-der" aria-label="Ver más pestañas" hidden><i class="mdi mdi-chevron-right"></i></button>
                    <div class="sg-a3-mas">
                        <a href="#" class="sg-a3-tab sg-a3-mas-btn" aria-haspopup="menu"><i class="mdi mdi-dots-horizontal"></i>Más<span class="sg-a3-mas-nombre" id="sgA3MasNombre"></span><i class="mdi mdi-chevron-down"></i></a>

                        <div class="sg-a3-mas-menu" role="menu">
                            <div class="sg-a3-mas-tit">Más sobre este activo</div>
                            <a href="#" class="sg-a3-mas-op" role="menuitem" data-sec="mantenimiento"><i class="mdi mdi-wrench-outline"></i><span><b>Mantenimiento</b><small>Planes donde está y lo que viene</small></span></a>
                            <a href="#" class="sg-a3-mas-op" role="menuitem" data-sec="inspecciones"><i class="mdi mdi-clipboard-check-outline"></i><span><b>Inspecciones y tareas</b><small>Rondas, pautas y su resultado</small></span></a>
                            <a href="#" class="sg-a3-mas-op" role="menuitem" data-sec="fallas"><i class="mdi mdi-alert-outline"></i><span><b>Fallas e indisponibilidad</b><small>Lo reportado y cuándo estuvo detenido</small></span></a>
                            <a href="#" class="sg-a3-mas-op" role="menuitem" data-sec="documentos"><i class="mdi mdi-image-multiple-outline"></i><span><b>Documentos y fotos</b><small>Manuales, planos, fotos y la portada</small></span></a>
                            <a href="#" class="sg-a3-mas-op" role="menuitem" data-sec="repuestos"><i class="mdi mdi-package-variant-closed"></i><span><b>Repuestos y costos</b><small>Lo compatible y lo que ha consumido</small></span></a>
                            <a href="#" class="sg-a3-mas-op" role="menuitem" data-sec="bitacora"><i class="mdi mdi-notebook-outline"></i><span><b>Bitácora y trazabilidad</b><small>Notas y cada cambio auditable</small></span></a>
                        </div>
                    </div>
                    <span class="sg-a3-sep" aria-hidden="true"></span>

                    <%-- SIGMA AI va aparte y no dentro de Mas: es lo unico de esta
                         pantalla que no afirma hechos, sino que propone revisar. --%>
                    <a href="#" class="sg-a3-tab es-ia" data-sec="ia" aria-label="SIGMA AI"><img class="sgx-tab-logo" src='<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-logo-horizontal-light.svg") %>' alt="SIGMA AI" /></a>
                </nav>

                <%-- ================================================================
                     1. RESUMEN
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="resumen">
                    <asp:Literal ID="litKpis" runat="server" />

                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-alerta"><i class="mdi mdi-alert-outline"></i></span>
                                    <div>
                                        <h3>Requiere atención</h3>
                                        <p class="sg-ot-card-sub">Lo abierto sobre este activo, con acceso a su registro.</p>
                                    </div>
                                    <%-- La tarjeta muestra los primeros: sin salida,
                                         el resto queda escondido sin decirlo. --%>
                                    <a href="#" class="sg-ot-card-acc sg-ot-link" data-ir-sec="ordenes">Ver todas <i class="mdi mdi-arrow-right"></i></a>
                                </header>
                                <asp:Literal ID="litAtencion" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-clock-outline"></i></span>
                                    <div>
                                        <h3>Actividad reciente</h3>
                                        <p class="sg-ot-card-sub">Lo último que se registró sobre el activo.</p>
                                    </div>
                                    <a href="#" class="sg-ot-card-acc sg-ot-link" data-ir-sec="historial">Ver todo el historial <i class="mdi mdi-arrow-right"></i></a>
                                </header>
                                <asp:Literal ID="litActividad" runat="server" />
                            </div>
                        </div>

                        <aside class="sg-a3-lado">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-factory"></i></span>
                                    <h3>Identidad del activo</h3>
                                </header>
                                <asp:Literal ID="litIdentidad" runat="server" />
                                <div class="sg-ot-card-pie">
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="ficha"><i class="mdi mdi-file-document-outline"></i>Ver ficha técnica</a>
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="documentos"><i class="mdi mdi-image-multiple-outline"></i>Galería</a>
                                </div>
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <%-- La marca de SIGMA AI es su simbolo, no una estrellita
                                         de la fuente de iconos: es lo unico de esta pantalla
                                         que no lo escribio una persona. --%>
                                    <img class="sg-ai-badge" src="<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-badge-light.svg") %>" alt="SIGMA AI" />
                                    <h3>SIGMA AI</h3>
                                </header>
                                <asp:Literal ID="litIA" runat="server" />
                            </div>

                            <%-- QUIEN RESPONDE POR EL EQUIPO Y CUANDO SE TOCO

                                 La ficha dice como es el equipo; esto dice de
                                 quien es y si el dato esta fresco. Una ficha
                                 sin fecha de actualizacion se lee como si
                                 estuviera al dia, y puede llevar dos años
                                 sin que nadie la mire. --%>
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-account-group-outline"></i></span>
                                    <h3>Contexto del activo</h3>
                                </header>
                                <asp:Literal ID="litContexto" runat="server" />
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- ================================================================
                     2. HISTORIAL
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-hist" data-panel="historial">
                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-timeline-text-outline"></i></span>
                                    <div>
                                        <h3>Todo lo que ha ocurrido en este activo</h3>
                                        <p class="sg-ot-card-sub">Órdenes, inspecciones, fallas, repuestos, lecturas y cambios, en una sola línea de tiempo.</p>
                                    </div>
                                    <asp:LinkButton ID="lnkExportar" runat="server" CssClass="sg-ot-btn es-plano sg-ot-card-acc" OnClick="lnkExportar_Click">
                                        <i class="mdi mdi-download"></i>Exportar
                                    </asp:LinkButton>
                                </header>

                                <%-- La barra y la linea de tiempo las arma el
                                     servidor: los filtros salen de lo que hay,
                                     no de un catalogo fijo. --%>
                                <asp:Literal ID="litHistorial" runat="server" />

                                <asp:Panel ID="pnlSinEventos" runat="server" Visible="false" CssClass="sg-ot-vacio">
                                    <i class="mdi mdi-timeline-text-outline"></i>
                                    <p>Sin eventos registrados</p>
                                    <span>Este activo todavía no tiene historia que mostrar.</span>
                                </asp:Panel>
                            </div>
                        </div>

                        <%-- EL EVENTO ELEGIDO

                             La linea de tiempo responde "que paso y cuando";
                             este panel responde "que fue exactamente eso", sin
                             salir a la pantalla de origen y perder el lugar en
                             la linea. Se llena en el navegador con lo que ya
                             trae cada evento. --%>
                        <div class="sg-a3-col es-angosta">
                            <aside class="sg-hist-detalle" id="sgHistDetalle">
                                <div class="sg-ot-card">
                                    <header class="sg-ot-card-cab">
                                        <span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span>
                                        <div><h3>Evento seleccionado</h3></div>
                                    </header>
                                    <p class="sg-ot-vacio-txt">Toque un evento de la línea para ver su detalle.</p>
                                </div>
                            </aside>
                        </div>
                    </div>

                    <div class="sg-ot-nota es-chica">
                        <i class="mdi mdi-information-outline"></i>
                        <span>Cada evento conserva el vínculo a su registro de origen.</span>
                    </div>
                </section>

<%-- ================================================================
                     3. ÓRDENES DE TRABAJO
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="ordenes">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-clipboard-text-outline"></i></span>
                            <div>
                                <h3>Órdenes de trabajo del activo</h3>
                                <p class="sg-ot-card-sub">Todas las intervenciones, con acceso a su detalle y cierre.</p>
                            </div>
                            <asp:Literal ID="litOtConteos" runat="server" />
                        </header>

                        <asp:Literal ID="litOrdenes" runat="server" />

                        <div class="sg-ot-nota es-chica">
                            <i class="mdi mdi-information-outline"></i>
                            <span>Toque una fila para ver su trabajo, repuestos, evidencias y cierre sin salir de acá.</span>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     4. MANTENIMIENTO
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-mant" data-panel="mantenimiento">
                    <div class="sg-mant-cols">
                        <div class="sg-mant-centro">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-calendar-text-outline"></i></span>
                                    <div>
                                        <h3>Planes que lo cubren</h3>
                                        <p class="sg-ot-card-sub">Los planes de mantenimiento donde este activo está incluido.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litPlanes" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-calendar-clock"></i></span>
                                    <div>
                                        <h3>Próximas actividades</h3>
                                        <p class="sg-ot-card-sub">Ocurrencias planificadas del plan de mantenimiento.</p>
                                    </div>
                                    <asp:Literal ID="litOcurrenciasConteo" runat="server" />
                                </header>
                                <asp:Literal ID="litOcurrencias" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-checkbox-marked-circle-outline"></i></span>
                                    <div>
                                        <h3>Tareas recurrentes</h3>
                                        <p class="sg-ot-card-sub">Rondas y revisiones que se repiten sobre el activo.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litTareas" runat="server" />
                            </div>

                            <%-- QUE CUBRE EL MANTENIMIENTO

                                 "Preventivo de hornos v1" no dice si entra el
                                 quemador. Quien firma una parada necesita
                                 saber que se va a tocar y que queda fuera. --%>
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-target"></i></span>
                                    <div>
                                        <h3>Alcance del mantenimiento</h3>
                                        <p class="sg-ot-card-sub">Componentes y actividades que cubre el plan.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litAlcance" runat="server" />
                            </div>
                        </div>

                        <aside class="sg-mant-lado">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-calendar-month-outline"></i></span>
                                    <div>
                                        <h3>Agenda de mantenimiento</h3>
                                        <p class="sg-ot-card-sub">Próximas actividades y OT vinculadas.</p>
                                    </div>
                                </header>

                                <%-- El calendario se arma en el servidor con los
                                     dias que TIENEN algo: pintar un mes vacio
                                     es pedirle a alguien que recorra treinta
                                     casillas para descubrir que no hay nada. --%>
                                <asp:Literal ID="litAgenda" runat="server" />

                                <div class="sg-mant-dia" id="sgMantDia"></div>
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-target"></i></span>
                                    <div><h3>Cómo se lee</h3></div>
                                </header>
                                <p class="sg-ot-texto">Una <strong>ocurrencia programada</strong> es una cita del plan: existe aunque nadie la haya tomado todavía. La <strong>orden de trabajo</strong> es el trabajo real, y aparece cuando alguien la genera desde esa cita.</p>
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- ================================================================
                     2. FICHA  ·  el activo se edita aca, sin salir del centro
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-ficha" data-panel="ficha">
                    <header class="sg-a3-ficha-cab">
                        <h2>Ficha del activo</h2>
                        <asp:Literal ID="litFichaModo" runat="server" />
                    </header>

                    <%-- Es el MISMO formulario del modal de alta: un control, no
                         una copia. Lo unico que cambia es donde van Guardar y
                         Cancelar. --%>
                    <wuc:ActivoForm runat="server" ID="frmFicha" EnCentro="true" OnGuardado="frmFicha_Guardado" />
                </section>

                <%-- ================================================================
                     6. COMPONENTES
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-comp" data-panel="componentes">
                    <%-- ¿DE QUE ESTA HECHO ESTE EQUIPO? (rediseño 04-10-2026)

                         Un solo diagrama con un color fijo por clase de cosa -morado
                         el equipo, azul sus subactivos, turquesa sus partes, ambar
                         sus repuestos- y el detalle de lo elegido AL LADO. Antes,
                         debajo del diagrama se repetia lo mismo en un arbol, una
                         tabla y otro detalle: cuatro vistas de la misma lista. --%>
                    <div class="sg-ot-card sg-es-card">
                        <div class="sg-es-barra">
                            <div>
                                <h3>¿De qué está hecho este activo?</h3>
                                <p>Toca cualquier elemento para ver su detalle.</p>
                            </div>
                            <asp:Panel ID="pnlEsAgregar" runat="server" CssClass="sg-es-agregar-wrap">
                                <button type="button" class="sg-ot-btn es-primario" onclick="return esAsistente(true);"><i class="mdi mdi-plus"></i>Agregar</button>
                            </asp:Panel>
                        </div>

                        <%-- La regla y la leyenda siempre a la vista: son lo que
                             permite leer el diagrama sin manual. --%>
                        <div class="sg-es-regla">
                            <span class="sg-es-regla-txt"><i class="mdi mdi-lightbulb-on-outline"></i>
                                <span>¿Te importa <b>esa</b> pieza en particular? → subactivo o componente. &nbsp;¿Da lo mismo cuál uses de la bodega? → repuesto.</span></span>
                            <span class="sg-es-leyenda" aria-label="Colores">
                                <span><i class="es-equipo"></i>Activo</span>
                                <span><i class="es-sub"></i>Subactivo</span>
                                <span><i class="es-comp"></i>Componente</span>
                                <span><i class="es-rep"></i>Repuesto</span>
                            </span>
                        </div>

                        <div class="sg-es-layout">
                            <div class="sg-es-diagrama">
                                <asp:Literal ID="litEstructura" runat="server" />
                            </div>

                            <%-- El detalle se arma en el navegador con lo que ya trae
                                 cada elemento: pedirlo al servidor para mostrar lo
                                 que ya esta en pantalla es un viaje de mas. --%>
                            <aside class="sg-es-det" id="sgEsDetalle" aria-live="polite">
                                <p class="sg-es-det-vacio"><i class="mdi mdi-gesture-tap"></i>Toca un elemento del diagrama para ver su detalle.</p>
                            </aside>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     7. FALLAS E INDISPONIBILIDAD
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-fallas" data-panel="fallas">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande es-rojo"><i class="mdi mdi-alert-outline"></i></span>
                            <div>
                                <h3>Fallas e indisponibilidad</h3>
                                <p class="sg-ot-card-sub">Lo que se reportó del activo y los períodos en que estuvo detenido.</p>
                            </div>
                            <asp:Literal ID="litEstadoAhora" runat="server" />
                        </header>

                        <%-- Una falla es lo que le pasa al equipo; una detencion
                             es el tiempo que costo. Se cuentan distinto y se
                             miran en momentos distintos. --%>
                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgFallaVistas">
                            <a href="#" class="sg-a3-chip es-activa" data-falla-vista="fallas"><i class="mdi mdi-alert-outline"></i>Fallas <b><asp:Literal ID="litFallasN" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-falla-vista="detenciones"><i class="mdi mdi-clock-alert-outline"></i>Detenciones <b><asp:Literal ID="litDetencionesN" runat="server" Text="0" /></b></a>
                        </div>

                        <div class="sg-cond-vista" data-falla-vista="fallas">
                            <div class="sg-ot-ev-filtros">
                                <div class="sg-ot-ev-tipos" id="sgFallaEstados">
                                    <a href="#" class="sg-a3-chip es-activa" data-falla-estado="todas">Todas</a>
                                    <a href="#" class="sg-a3-chip" data-falla-estado="abierta">Abiertas <b><asp:Literal ID="litFallasAbiertas" runat="server" Text="0" /></b></a>
                                    <a href="#" class="sg-a3-chip" data-falla-estado="resuelta">Resueltas</a>
                                </div>
                                <div class="sg-ot-ev-buscar">
                                    <i class="mdi mdi-magnify"></i>
                                    <input type="search" id="sgFallaBuscar" placeholder="Buscar falla por descripción o síntoma..." autocomplete="off" />
                                </div>
                            </div>

                            <asp:Literal ID="litFallas" runat="server" />
                        </div>

                        <div class="sg-cond-vista es-oculta" data-falla-vista="detenciones">
                            <div class="sg-falla-total">
                                <asp:Literal ID="litDetencionTotal" runat="server" />
                            </div>

                            <asp:Literal ID="litIndisponibilidad" runat="server" />

                            <div class="sg-ot-nota es-chica">
                                <i class="mdi mdi-information-outline"></i>
                                <span>Una detención planificada es tiempo que se decidió gastar; una no planificada es tiempo que se perdió. El indicador de disponibilidad los cuenta distinto.</span>
                            </div>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     8. CONDICIÓN Y MEDIDORES
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-cond-panel" data-panel="condicion">
                    <div class="sg-ot-card">

                        <%-- La cabecera trae las cuatro cosas que se hacen aca:
                             buscar, filtrar por estado, configurar que se mide
                             y registrar una lectura. --%>
                        <header class="sg-ot-card-cab sg-cond-top">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-pulse"></i></span>
                            <div>
                                <h3>Condición y medidores</h3>
                                <p class="sg-ot-card-sub"><asp:Literal ID="litCondActivo" runat="server" /></p>
                            </div>

                            <div class="sg-cond-acciones">
                                <div class="sg-ot-ev-buscar sg-cond-buscar">
                                    <i class="mdi mdi-magnify"></i>
                                    <input type="search" id="sgCondBuscar" placeholder="Buscar variable o contador..." autocomplete="off" />
                                </div>

                                <select id="sgCondEstado" class="sg-ot-select">
                                    <option value="">Estado: Todos</option>
                                    <option value="es-critico">Fuera de límite</option>
                                    <option value="es-aviso">Revisar</option>
                                    <option value="es-normal">En rango</option>
                                    <option value="es-sin">Sin lectura</option>
                                </select>

                                <%-- UNA accion morada: registrar la lectura, que es lo
                                     de todos los dias. Configurar que se mide es de
                                     una vez y queda en un menu, con la regla de cada uno. --%>
                                <div class="sg-cond-agregar">
                                    <button type="button" class="sg-ot-btn es-plano" aria-haspopup="true" aria-expanded="false"
                                        onclick="return sgCondMenu(this);"><i class="mdi mdi-plus"></i>Agregar qué medir<i class="mdi mdi-chevron-down"></i></button>
                                    <div class="sg-cond-agregar-menu" role="menu">
                                        <asp:LinkButton ID="lnkNuevaVariable" runat="server" CssClass="sg-cond-op"
                                            OnClientClick="return abrirVariable(queryNuevaVariable);"><i class="mdi mdi-pulse"></i><span><b>Una variable de condición</b><small>Cómo está ahora. Ej.: temperatura de la cámara, en °C.</small></span></asp:LinkButton>
                                        <asp:LinkButton ID="lnkNuevoMedidor" runat="server" CssClass="sg-cond-op"
                                            OnClientClick="return abrirMedidor(queryNuevoMedidor);"><i class="mdi mdi-counter"></i><span><b>Un contador</b><small>Cuánto ha trabajado. Ej.: horas de marcha del compresor.</small></span></asp:LinkButton>
                                    </div>
                                </div>
                                <asp:LinkButton ID="lnkRegistrarLectura" runat="server" CssClass="sg-ot-btn es-primario"
                                    OnClientClick="return abrirLectura('');"><i class="mdi mdi-plus"></i>Registrar lectura</asp:LinkButton>
                            </div>
                        </header>

                        <%-- La banda dice cuantas piden atencion ANTES de la
                             grilla: con doce tarjetas, la que esta fuera de
                             limite se pierde entre las que estan bien. --%>
                        <asp:Literal ID="litCondAviso" runat="server" />

                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgCondVistas">
                            <a href="#" class="sg-a3-chip es-activa" data-cond-vista="todas">Todas <b><asp:Literal ID="litCondTodas" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-cond-vista="variables"><i class="mdi mdi-pulse"></i>Variables <b><asp:Literal ID="litCondVariables" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-cond-vista="medidores"><i class="mdi mdi-counter"></i>Contadores <b><asp:Literal ID="litCondMedidores" runat="server" Text="0" /></b></a>
                        </div>

                        <section class="sg-cond-seccion" data-cond-grupo="variables">
                            <h4>Variables de condición <b><asp:Literal ID="litCondVariables2" runat="server" Text="0" /></b></h4>
                            <p>Cómo está el activo según la última lectura.</p>
                            <div class="sg-cond-grid"><asp:Literal ID="litCondicion" runat="server" /></div>
                        </section>

                        <section class="sg-cond-seccion" data-cond-grupo="medidores">
                            <h4>Contadores acumulativos <b><asp:Literal ID="litCondMedidores2" runat="server" Text="0" /></b></h4>
                            <p>Cuánto ha trabajado o consumido el activo.</p>
                            <div class="sg-cond-grid"><asp:Literal ID="litMedidores" runat="server" /></div>
                        </section>

                        <p class="sg-cond-nada" id="sgCondNada" style="display:none">Ninguna variable o contador coincide con la búsqueda.</p>

                        <%-- El historial y las acciones de la tarjeta elegida se
                             despliegan DEBAJO de su fila, no en una columna al
                             costado: asi la tarjeta no se mueve al abrirse. --%>
                        <div class="sg-cond-detalle" id="sgCondDetalle" style="display:none"></div>

                        <%-- Las lecturas viajan escondidas y el navegador las
                             mueve al detalle: pedirlas de a una obligaria a un
                             postback por tarjeta. --%>
                        <div class="sg-cond-fuente" id="sgCondFuente" style="display:none"><asp:Literal ID="litCondLecturas" runat="server" /></div>

                        <div class="sg-a3-umbrales">
                            <i class="mdi mdi-information-outline"></i>
                            Los rangos se configuran por activo en su variable. No son límites de operación: valídelos con mantención antes de usarlos para decidir.
                        </div>
                    </div>
                </section>

<%-- ================================================================
                     9. DOCUMENTOS Y GALERÍA
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-docs" data-panel="documentos">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-image-multiple-outline"></i></span>
                            <div>
                                <h3>Documentos y galería</h3>
                                <p class="sg-ot-card-sub">Documentos técnicos, fotografías y lo que el terreno adjuntó.</p>
                            </div>
                            <asp:Literal ID="litDocConteos" runat="server" />
                        </header>

                        <%-- Tres vistas por lo que SON, no por su extension: un
                             manual y la foto de una correa rota son dos cosas
                             distintas aunque las dos sean archivos. --%>
                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgDocChips">
                            <a href="#" class="sg-a3-chip es-activa" data-doc="todos">Todos <b><asp:Literal ID="litEvTodas" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-doc="documento"><i class="mdi mdi-file-document-outline"></i>Documentos <b><asp:Literal ID="litEvDocs" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-doc="fotografia"><i class="mdi mdi-camera-outline"></i>Fotografías <b><asp:Literal ID="litEvFotos" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-doc="evidencia"><i class="mdi mdi-cellphone-link"></i>Evidencias <b><asp:Literal ID="litEvEvidencias" runat="server" Text="0" /></b></a>
                        </div>

                        <div class="sg-ot-ev-filtros">
                            <div class="sg-ot-ev-buscar">
                                <i class="mdi mdi-magnify"></i>
                                <input type="search" id="sgDocBuscar" placeholder="Buscar archivo, origen o persona..." autocomplete="off" />
                            </div>
                            <select id="sgDocOrigen" class="sg-ot-select"><option value="">Todos los orígenes</option></select>

                            <%-- Fecha y tipo: con cuarenta archivos, "el
                                 informe de la semana pasada" se encuentra por
                                 cuando llego, no leyendo cuarenta nombres. --%>
                            <select id="sgDocFecha" class="sg-ot-select">
                                <option value="">Cualquier fecha</option>
                                <option value="7">Últimos 7 días</option>
                                <option value="30">Últimos 30 días</option>
                                <option value="90">Últimos 90 días</option>
                                <option value="365">Último año</option>
                            </select>

                            <select id="sgDocTipo" class="sg-ot-select">
                                <option value="">Todos los tipos</option>
                                <option value="imagen">Imágenes</option>
                                <option value="video">Videos</option>
                                <option value="audio">Audios</option>
                                <option value="documento">Documentos</option>
                            </select>
                        </div>

                        <div class="sg-ot-ev-cols">
                            <div class="sg-ot-ev-grid" id="sgOtEvGrid">
                                <asp:Literal ID="litArchivos" runat="server" />
                            </div>

                            <%-- El detalle del archivo elegido. Se llena en el
                                 navegador con lo que ya trae la tarjeta. --%>
                            <aside class="sg-ot-ev-detalle" id="sgOtEvDetalle"></aside>
                        </div>

                        <asp:Panel ID="pnlSinArchivos" runat="server" Visible="false" CssClass="sg-ot-vacio">
                            <i class="mdi mdi-image-off-outline"></i>
                            <p>Sin documentos ni fotografías</p>
                            <span>Se adjuntan desde la ficha del activo o llegan con las evidencias de la app.</span>
                        </asp:Panel>

                        <%-- Solo las miniaturas (05-10-2026): la lista de archivos repetia lo
                             mismo debajo. El detalle de cada uno se abre al tocarlo. --%>
                        <asp:Literal ID="litDocTabla" runat="server" Visible="false" />
                    </div>
                </section>

                <%-- ================================================================
                     10. INSPECCIONES Y TAREAS
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="inspecciones">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-clipboard-check-outline"></i></span>
                            <div>
                                <h3>Inspecciones y tareas</h3>
                                <p class="sg-ot-card-sub">Lo que se pasó a revisar en este activo: pautas de inspección y tareas.</p>
                            </div>
                            <asp:Literal ID="litRevConteos" runat="server" />
                        </header>

                        <div class="sg-ot-ev-filtros">
                            <div class="sg-ot-ev-tipos" id="sgA3RevTipos">
                                <a href="#" class="sg-a3-chip es-activa" data-rev-tipo="todas">Todas <b><asp:Literal ID="litRevTodas" runat="server" Text="0" /></b></a>
                                <a href="#" class="sg-a3-chip" data-rev-tipo="INSPECCION"><i class="mdi mdi-clipboard-text-outline"></i>Inspecciones <b><asp:Literal ID="litRevInsp" runat="server" Text="0" /></b></a>
                                <a href="#" class="sg-a3-chip" data-rev-tipo="TAREA"><i class="mdi mdi-checkbox-marked-circle-outline"></i>Tareas <b><asp:Literal ID="litRevTareas" runat="server" Text="0" /></b></a>
                            </div>
                            <div class="sg-ot-ev-buscar">
                                <i class="mdi mdi-magnify"></i>
                                <input type="search" id="sgA3RevBuscar" placeholder="Buscar inspección o tarea..." autocomplete="off" />
                            </div>
                            <select id="sgA3RevResultado" class="sg-ot-select">
                                <option value="">Todos los resultados</option>
                                <option value="CONFORME">Sin observaciones</option>
                                <option value="CON_OBSERVACION">Con observación</option>
                                <option value="SIN_EVALUAR">Sin evaluar</option>
                            </select>
                        </div>

                        <asp:Literal ID="litRevisiones" runat="server" />

                        <div class="sg-ot-nota es-chica">
                            <i class="mdi mdi-information-outline"></i>
                            <span>El <strong>estado</strong> dice el avance de la inspección o tarea. El <strong>resultado</strong> refleja la evaluación del técnico: una revisión puede estar completada y con hallazgos.</span>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     11. REPUESTOS Y COSTOS
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-rep-panel" data-panel="repuestos">
                    <asp:Literal ID="litCostoKpis" runat="server" />

                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-package-variant-closed"></i></span>
                            <div>
                                <h3>Repuestos y costos</h3>
                                <p class="sg-ot-card-sub">Gestión de materiales, devoluciones y costos asociados al activo.</p>
                            </div>
                            <asp:Literal ID="litConsumoConteos" runat="server" />
                        </header>

                        <%-- CONSUMOS, DEVOLUCIONES Y COSTOS NO SON LA MISMA LISTA

                             Lo consumido dice que se gasto; lo devuelto dice
                             que se pidio de mas y volvio a bodega -que no es
                             gasto y no puede sumarse igual-; y los costos
                             agrupan por orden, que es como se aprueba el
                             presupuesto. Mezclarlas obliga a leer una columna
                             para saber que se esta mirando. --%>
                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgRepVistas">
                            <a href="#" class="sg-a3-chip es-activa" data-rep-vista="consumos"><i class="mdi mdi-package-variant-closed"></i>Consumos <b><asp:Literal ID="litRepConsumos" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-rep-vista="devoluciones"><i class="mdi mdi-undo-variant"></i>Devoluciones <b><asp:Literal ID="litRepDevoluciones" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-rep-vista="costos"><i class="mdi mdi-calculator-variant-outline"></i>Costos <b><asp:Literal ID="litRepOrdenes" runat="server" Text="0" /></b></a>
                        </div>

                        <div class="sg-cond-vista" data-rep-vista="consumos">
                            <asp:Literal ID="litConsumos" runat="server" />
                        </div>

                        <div class="sg-cond-vista es-oculta" data-rep-vista="devoluciones">
                            <asp:Literal ID="litDevoluciones" runat="server" />
                        </div>

                        <div class="sg-cond-vista es-oculta" data-rep-vista="costos">
                            <asp:Literal ID="litCostos" runat="server" />
                        </div>
                    </div>

                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico"><i class="mdi mdi-shape-outline"></i></span>
                            <div>
                                <h3>Repuestos compatibles</h3>
                                <p class="sg-ot-card-sub">Lo que este activo puede llevar, con lo que hay en bodega ahora.</p>
                            </div>
                        </header>

                        <asp:Literal ID="litCompatibles" runat="server" />
                    </div>
                </section>

<%-- ================================================================
                     12. SIGMA AI
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="ia">
                    <asp:Literal ID="litIaPanel" runat="server" />
                </section>

                <%-- ================================================================
                     13. BITÁCORA Y TRAZABILIDAD
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="bitacora">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-notebook-outline"></i></span>
                            <div>
                                <h3>Bitácora y trazabilidad</h3>
                                <p class="sg-ot-card-sub">Registro cronológico de lo que se anotó del activo y de cada cambio auditable.</p>
                            </div>
                            <asp:Literal ID="litBitConteos" runat="server" />
                        </header>

                        <%-- LA BITACORA Y LA AUDITORIA NO SON LO MISMO

                             La bitacora la escribe una persona: "el equipo
                             suena raro". La auditoria la escribe el sistema:
                             "la criticidad paso de media a alta". Una se
                             corrige agregando otra nota; la otra no se corrige
                             nunca, y por eso van separadas. --%>
                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgBitVistas">
                            <a href="#" class="sg-a3-chip es-activa" data-bit-vista="bitacora"><i class="mdi mdi-note-text-outline"></i>Bitácora <b><asp:Literal ID="litBitRegistros" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-bit-vista="auditoria"><i class="mdi mdi-shield-check-outline"></i>Auditoría <b><asp:Literal ID="litBitCambios" runat="server" Text="0" /></b></a>
                        </div>

                        <div class="sg-cond-vista" data-bit-vista="bitacora">
                            <asp:Literal ID="litBitacora" runat="server" />

                            <div class="sg-a3-obs">
                                <asp:TextBox ID="txtObservacion" runat="server" TextMode="MultiLine" Rows="3"
                                    CssClass="sg-ot-textarea" placeholder="Escribe una observación sobre el activo..." />
                                <div class="sg-a3-obs-acc">
                                    <asp:LinkButton ID="lnkPublicar" runat="server" CssClass="sg-ot-btn es-primario"
                                        OnClick="lnkPublicar_Click"><i class="mdi mdi-send-outline"></i>Publicar</asp:LinkButton>
                                </div>
                            </div>

                            <asp:Literal ID="litObsAviso" runat="server" />
                            <%-- Responder una nota (bloque 352): el hilo escribe aca y envia lnkResponder. --%>
                            <input type="hidden" name="bit_padre" id="bitPadre" />
                            <input type="hidden" name="bit_respuesta" id="bitRespuesta" />
                            <asp:LinkButton ID="lnkResponder" runat="server" OnClick="lnkResponder_Click" CausesValidation="false" style="display:none" />
                        </div>

                        <div class="sg-cond-vista es-oculta" data-bit-vista="auditoria">
                            <asp:Literal ID="litTrazabilidad" runat="server" />
                        </div>
                    </div>

                    <div class="sg-ot-nota es-chica">
                        <i class="mdi mdi-information-outline"></i>
                        <span>Los registros de auditoría no son editables. Las correcciones se registran como nuevos eventos en la bitácora.</span>
                    </div>
                </section>

            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>

    <%-- Asistente: una pregunta, tres respuestas con su regla. Quien no sabe la
         diferencia entre subactivo, componente y repuesto elige por la regla y
         el sistema lo guarda donde corresponde. --%>
    <div class="sg-es-asis" id="sgEsAsistente" role="dialog" aria-modal="true" aria-labelledby="sgEsAsisTit" onclick="if (event.target === this) esAsistente(false);">
        <div class="sg-es-asis-caja">
          <%-- 1) Elegir que se agrega --%>
          <div class="sg-es-vista" data-vista="elegir">
            <header class="sg-es-asis-cab">
                <div>
                    <small id="sgEsAsisDonde">Agregar a este activo</small>
                    <h3 id="sgEsAsisTit">¿Qué vas a agregar?</h3>
                    <p>Elige una opción. Si dudas, mira el ejemplo de cada una.</p>
                </div>
                <button type="button" class="sg-es-asis-x" aria-label="Cerrar" onclick="return esAsistente(false);"><i class="mdi mdi-close"></i></button>
            </header>
            <div class="sg-es-opciones" role="radiogroup" aria-label="Qué vas a agregar">
                <button type="button" role="radio" aria-checked="false" class="sg-es-op es-sub" data-que="subactivo" data-txt="Una máquina" onclick="return esElegir(this);">
                    <span class="sg-es-op-top"><span class="sg-es-op-ico"><i class="mdi mdi-cogs"></i></span><span class="sg-es-op-radio"></span></span>
                    <b>Un activo que depende de este</b>
                    <span class="sg-es-etq es-sub">Subactivo</span>
                    <span class="regla">Tiene su propio número de serie, se saca para repararlo aparte y puede tener sus propios componentes.</span>
                    <span class="ej"><b>Ej.:</b> el compresor de la cámara, la bomba de una caldera.</span>
                </button>
                <button type="button" role="radio" aria-checked="false" class="sg-es-op es-comp" data-que="componente" data-txt="Una parte" onclick="return esElegir(this);">
                    <span class="sg-es-op-top"><span class="sg-es-op-ico"><i class="mdi mdi-puzzle-outline"></i></span><span class="sg-es-op-radio"></span></span>
                    <b>Una parte de este activo</b>
                    <span class="sg-es-etq es-comp">Componente</span>
                    <span class="regla">No existe fuera del activo, pero quieres saber cuándo se instaló y cuándo cambiarla.</span>
                    <span class="ej"><b>Ej.:</b> el burlete de la puerta, el termostato, un rodamiento.</span>
                </button>
                <button type="button" role="radio" aria-checked="false" class="sg-es-op es-rep" data-que="repuesto" data-txt="Un repuesto" onclick="return esElegir(this);">
                    <span class="sg-es-op-top"><span class="sg-es-op-ico"><i class="mdi mdi-package-variant-closed"></i></span><span class="sg-es-op-radio"></span></span>
                    <b>Un repuesto que le sirve</b>
                    <span class="sg-es-etq es-rep">Repuesto</span>
                    <span class="regla">Se compra por cantidad y se guarda en bodega. Da lo mismo cuál uses.</span>
                    <span class="ej"><b>Ej.:</b> filtro secador, correa, refrigerante R-404A.</span>
                </button>
            </div>
            <div class="sg-es-regla es-chica">
                <span class="sg-es-regla-txt"><i class="mdi mdi-lightbulb-on-outline"></i>
                    <span>¿Te importa <b>esa</b> pieza en particular? → subactivo o componente. &nbsp;¿Da lo mismo cuál uses de la bodega? → repuesto.</span></span>
            </div>
            <footer class="sg-es-asis-pie">
                <button type="button" class="sg-ot-btn es-fantasma" onclick="return esAsistente(false);">Cancelar</button>
                <button type="button" class="sg-ot-btn es-primario" id="sgEsContinuar" disabled="disabled" onclick="return esContinuar();">Elige una opción<i class="mdi mdi-arrow-right"></i></button>
            </footer>
          </div>

          <%-- 3) El repuesto compatible, AQUI MISMO (bloque 351): el repuesto de
               la bodega y a que le sirve -el activo, un subactivo o una parte-. --%>
          <div class="sg-es-vista" data-vista="repuesto" hidden>
            <header class="sg-es-asis-cab">
                <div>
                    <button type="button" class="sg-es-volver" onclick="return esVista('elegir');"><i class="mdi mdi-arrow-left"></i>Cambiar lo que agrego</button>
                    <h3>Repuesto compatible</h3>
                    <p class="sg-es-donde-txt">Un repuesto de la bodega que le sirve a este activo.</p>
                </div>
                <button type="button" class="sg-es-asis-x" aria-label="Cerrar" onclick="return esAsistente(false);"><i class="mdi mdi-close"></i></button>
            </header>

            <div class="sg-es-faltan" id="sgEsrFaltan" role="alert" hidden><i class="mdi mdi-alert-circle-outline"></i><span id="sgEsrFaltanTxt"></span></div>

            <div class="sg-es-form es-una">
                <div class="sg-es-campo es-ancho">
                    <span class="sg-es-etiq">Repuesto <b class="req">*</b></span>
                    <div class="sgap sg-es-sgap" id="esrCombo"><p class="sg-es-ayuda">Cargando repuestos…</p></div>
                    <span class="sg-es-ayuda">Busca por nombre o código. Ves su foto y lo que hay en bodega.</span>
                </div>
                <label class="sg-es-campo es-ancho">
                    <span class="sg-es-etiq">Le sirve a</span>
                    <select id="esrPara"></select>
                    <span class="sg-es-ayuda">El activo completo, uno de sus subactivos o una de sus partes.</span>
                </label>
                <label class="sg-es-campo es-ancho">
                    <span class="sg-es-etiq">Observación</span>
                    <input type="text" id="esrObs" maxlength="500" placeholder="Ej.: verificar la medida antes de montar" autocomplete="off" />
                </label>
            </div>

            <footer class="sg-es-asis-pie">
                <button type="button" class="sg-ot-btn es-fantasma" onclick="return esAsistente(false);">Cancelar</button>
                <button type="button" class="sg-ot-btn es-primario" id="esrGuardar" onclick="return esrGuardar(this);"><i class="mdi mdi-plus"></i>Agregar repuesto</button>
            </footer>
          </div>

          <%-- 2) El componente se crea AQUI MISMO, sin abrir otra ventana y con
               el diseño del asistente del activo. --%>
          <div class="sg-es-vista" data-vista="componente" hidden>
            <header class="sg-es-asis-cab">
                <div>
                    <button type="button" class="sg-es-volver" onclick="return esVista('elegir');"><i class="mdi mdi-arrow-left"></i>Cambiar lo que agrego</button>
                    <h3>Nuevo componente</h3>
                    <p class="sg-es-donde-txt">Una parte de este activo que quieres seguir por separado.</p>
                </div>
                <button type="button" class="sg-es-asis-x" aria-label="Cerrar" onclick="return esAsistente(false);"><i class="mdi mdi-close"></i></button>
            </header>

            <div class="sg-es-faltan" id="sgEscFaltan" role="alert" hidden><i class="mdi mdi-alert-circle-outline"></i><span id="sgEscFaltanTxt"></span></div>

            <div class="sg-es-form">
                <label class="sg-es-campo es-ancho" id="escActivoCampo" hidden>
                    <span class="sg-es-etiq">Activo <b class="req">*</b></span>
                    <select name="esc_activo" id="escActivo" onchange="escActivoCambia();"></select>
                    <span class="sg-es-ayuda">El activo o subactivo al que pertenece esta parte.</span>
                    <span class="sg-es-msg">Elige a qué activo pertenece.</span>
                </label>
                <label class="sg-es-campo">
                    <span class="sg-es-etiq">Nombre <b class="req">*</b></span>
                    <input type="text" name="esc_nombre" id="escNombre" maxlength="200" placeholder="Ej.: Burlete de la puerta" autocomplete="off" />
                    <span class="sg-es-msg">Escribe cómo le dicen a esta parte.</span>
                </label>
                <div class="sg-es-campo">
                    <span class="sg-es-etiq">Qué es <b class="req">*</b></span>
                    <span class="sg-combo"><input type="text" name="esc_tipo" id="escTipo" data-sgcombo="af:tipos" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="sgComboLista" placeholder="Ej.: Sello, Motor, Sensor" autocomplete="off" spellcheck="false" aria-label="Qué es" />
                        <button type="button" class="sg-combo-btn" tabindex="-1" aria-label="Ver opciones"><i class="mdi mdi-chevron-down"></i></button></span>
                    <span class="sg-es-ayuda">Elige de la lista o escribe uno nuevo: se crea al guardar.</span>
                    <span class="sg-es-msg">Elige o escribe qué es esta parte.</span>
                </div>
                <div class="sg-es-campo">
                    <span class="sg-es-etiq">Dónde va</span>
                    <span class="sg-combo"><input type="text" name="esc_lado" id="escLado" data-sgcombo="af:lados" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="sgComboLista" placeholder="Ej.: Delantero, Lado motor" autocomplete="off" spellcheck="false" aria-label="Dónde va" />
                        <button type="button" class="sg-combo-btn" tabindex="-1" aria-label="Ver opciones"><i class="mdi mdi-chevron-down"></i></button></span>
                </div>
                <label class="sg-es-campo">
                    <span class="sg-es-etiq">Es parte de</span>
                    <select name="esc_padre" id="escPadre"></select>
                    <span class="sg-es-ayuda">Si va dentro de otra parte (el rodamiento DEL motor), elígela.</span>
                </label>
                <label class="sg-es-campo">
                    <span class="sg-es-etiq">Estado</span>
                    <select name="esc_estado" id="escEstado"></select>
                </label>
                <%-- El calendario de SIGMA (sigma-calendario.js) toma el campo por el
                     envoltorio .sigma-modal-fecha y escribe dd-mm-aaaa. Es un div y no
                     un label: dentro de un label, el clic en el icono enfocaba el campo. --%>
                <div class="sg-es-campo">
                    <span class="sg-es-etiq">Se instaló el</span>
                    <span class="sigma-modal-fecha"><input type="text" name="esc_fecha" id="escFecha" maxlength="10" placeholder="dd-mm-aaaa" autocomplete="off" aria-label="Se instaló el" /><a href="javascript:void(0)" title="Elegir fecha" aria-label="Elegir fecha"></a></span>
                </div>
                <label class="sg-es-campo es-ancho">
                    <span class="sg-es-etiq">Descripción u observación</span>
                    <textarea name="esc_desc" id="escDesc" rows="2" maxlength="500" placeholder="Ej.: está gastado y se escapa el frío"></textarea>
                </label>
                <div class="sg-es-campo es-ancho">
                    <span class="sg-es-etiq">Foto del componente</span>
                    <div class="af-drop" id="escFotoZona">
                        <span class="af-drop-ico" id="escFotoIco"><i class="mdi mdi-image-outline"></i></span>
                        <span class="af-drop-txt"><b>Arrastra una foto aquí</b><span id="escFotoNom">PNG o JPG. Ayuda a reconocer la pieza.</span></span>
                        <span class="af-drop-acc"><label for="escFoto" class="sg-ot-btn es-plano"><i class="mdi mdi-camera-outline"></i>Elegir foto</label></span>
                        <input type="file" name="esc_foto" id="escFoto" accept="image/*" style="display:none" onchange="escFotoVer(this)" />
                    </div>
                </div>
            </div>

            <footer class="sg-es-asis-pie">
                <button type="button" class="sg-ot-btn es-fantasma" onclick="return esAsistente(false);">Cancelar</button>
                <button type="button" class="sg-ot-btn es-primario" onclick="return escGuardar();"><i class="mdi mdi-check"></i>Guardar componente</button>
                <asp:LinkButton ID="lnkEsGuardarComp" runat="server" OnClick="lnkEsGuardarComp_Click" CausesValidation="false" style="display:none" />
            </footer>
          </div>

          <%-- 3) Subactivo y repuesto: su formulario dentro de esta misma ventana. --%>
          <div class="sg-es-vista es-marco" data-vista="marco" hidden>
            <header class="sg-es-asis-cab">
                <div>
                    <button type="button" class="sg-es-volver" onclick="return esVista('elegir');"><i class="mdi mdi-arrow-left"></i>Cambiar lo que agrego</button>
                    <h3 id="sgEsMarcoTit">Nuevo subactivo</h3>
                </div>
                <button type="button" class="sg-es-asis-x" aria-label="Cerrar" onclick="return esAsistente(false);"><i class="mdi mdi-close"></i></button>
            </header>
            <iframe id="sgEsMarco" title="Formulario" src="about:blank"></iframe>
          </div>
        </div>
    </div>
</asp:Content>
