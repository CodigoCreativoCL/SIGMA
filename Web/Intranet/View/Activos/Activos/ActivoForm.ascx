<%@ Control Language="C#" AutoEventWireup="true" CodeFile="ActivoForm.ascx.cs" Inherits="View_Activos_Activos_ActivoForm" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<%-- EL FORMULARIO DEL ACTIVO, UNA SOLA VEZ

     Lo muestran dos pantallas: el modal de alta -desde el listado y
     desde el centro- y la pestaña Ficha del centro del activo. Es el
     mismo control con dos vestidos, y no dos formularios: duplicarlo
     obligaba a agregar cada campo nuevo en dos partes.

     REDISEÑO 04-10-2026 (maquetas «SIGMA · Rediseño módulo de Activos»):
     asistente de cuatro pasos con los pasos a la izquierda y una ayuda corta
     por paso; todos los botones en UNA barra al pie y siempre en el mismo
     lugar; validacion que dice que falta y lleva al campo; y, al crear, una
     confirmacion con el proximo paso sugerido. --%>

<%-- La piel y el JS del asistente son compartidos (sigma-asistente.css/js).
     En el centro los carga la pagina en su cabecera: la ficha puede llegar
     despues, en un postback parcial, y ahi un <script src> no se ejecuta. --%>
<script type="text/javascript">var AF_PASOS = 6;</script>
<% if (!EnCentro) { %>
<link href='<%=Asset("~/Css/LookAndFeel/sigma-asistente.css") %>' rel="stylesheet" />
<script type="text/javascript" src='<%=Asset("~/Js/sigma-asistente.js") %>'></script>
<% } %>

<script type="text/javascript">
    // Muestra los nombres de los documentos elegidos (aún sin subir).
    function sigmaDocsNombres(input) {
        var d = document.getElementById('sigmaDocsLista');
        if (!d) return;
        if (input.files && input.files.length) {
            var n = [];
            for (var i = 0; i < input.files.length; i++) n.push(input.files[i].name);
            d.textContent = n.join('  ·  ');
        } else { d.textContent = ''; }
    }
    // Guardado: muestra el velo "Guardando…" SIN bloquear el postback.
    // Importante: NO retorna valor (este PushButton no reenvía si el
    // OnClientClick retorna). El velo se muestra con un setTimeout, después
    // de que corra la validación del botón: si algún campo falla,
    // Page_IsValid queda en false, se dice qué falta y no se muestra el velo.
    function sigmaGuardando() {
        setTimeout(function () {
            if (typeof Page_IsValid !== 'undefined' && Page_IsValid === false) { afMostrarFaltas(true); return; }
            var ov = document.getElementById('sigmaGuardandoOv');
            if (ov) ov.style.display = 'flex';
        }, 0);
    }

    // Al elegir una imagen: muestra el nombre, Quitar y la vista previa al
    // instante (sin subir todavía; sube al guardar).
    function sigmaPrevImg(input) {
        var name = document.getElementById('sigmaFileName');
        var quit = document.getElementById('sigmaQuitar');
        var img = document.getElementById('sigmaThumb');
        var caja = document.querySelector('.af-foto');
        if (input.files && input.files[0]) {
            if (name) name.textContent = input.files[0].name;
            if (quit) quit.style.display = 'inline-flex';
            if (img && window.FileReader) {
                var r = new FileReader();
                r.onload = function (e) { img.src = e.target.result; img.style.display = 'block'; if (caja) caja.classList.add('con-prev'); };
                r.readAsDataURL(input.files[0]);
            }
        } else {
            if (name) name.textContent = '';
            if (quit) quit.style.display = 'none';
            if (img) { img.src = ''; img.style.display = 'none'; }
            if (caja) caja.classList.remove('con-prev');
        }
    }
    function sigmaQuitarSel() {
        var input = document.getElementById('fuImagen');
        if (input) { input.value = ''; sigmaPrevImg(input); }
    }

    // Crear un modelo al vuelo, sin ir al catálogo.
    function nuevoModelo() {
        var url = '<%=ResolveUrl("~/View/Activos/Modelos/ActivoModelo.aspx") %>?query=0';
        var M = (window.parent && window.parent.SigmaModal) ? window.parent.SigmaModal : window.SigmaModal;
        if (M && M.open) { M.open({ url: url, title: 'Nuevo modelo', width: 820, initialHeight: 560 }); }
        else { window.open(url, '_blank'); }
        return false;
    }
    /* La invoca el modal de modelo al cerrarse. Se define solo si la
       pagina que aloja el formulario no trajo el suyo. */
    window.refresh = window.refresh || function () { __doPostBack('', ''); };

    /* ---- ¿Depende de otra maquina? Si/No y, si es Si, cual ---- */
    function afPadreCombo() { var e = document.querySelector('.af-padre .RadComboBox'); return e && window.$find ? $find(e.id) : null; }
    /* No se llama afDepende: el radio se llama asi y, dentro del form, el
       nombre del control tapa a la funcion en el onclick (trampa conocida). */
    function afMarcarDepende(si) {
        var w = document.querySelector('.af-padre'); if (!w) return;
        w.hidden = !si;
        if (!si) { var c = afPadreCombo(); if (c && c.get_items().get_count()) c.get_items().getItem(0).select(); }
    }
    function afIniciarDepende() {
        var c = afPadreCombo(), si = document.getElementById('afDependeSi'), no = document.getElementById('afDependeNo');
        if (!si || !no) return;
        var tiene = c && c.get_value && c.get_value() !== '';
        si.checked = !!tiene; no.checked = !tiene;
        var w = document.querySelector('.af-padre'); if (w) w.hidden = !tiene;
    }

    function fpIniciar() {
        if (!document.querySelector('.af-seccion')) return;
        fpIr(fpActual());
        afIniciarDepende();
        ndCabecera();
        afSoltar(document.querySelector('.af-foto'), 'fuImagen', sigmaPrevImg);
        afSoltar(document.querySelector('.af-docs'), 'fuDocs', sigmaDocsNombres);
        var cont = document.getElementById('coContainer');
        if (cont && !cont.children.length && document.querySelector('.af-es-nuevo')) coAgregar('', '', true);
        vaCabecera(); meCabecera();
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fpIniciar); else setTimeout(fpIniciar, 0);
    window.addEventListener('load', function () {
        afIniciarDepende();
        if (window.Sys && Sys.WebForms) Sys.WebForms.PageRequestManager.getInstance().add_endRequest(fpIniciar);
    });

    // Componentes nuevos: nombre + que es + donde va + foto
    function coAgregar(nombre, tipo, sinFoco) {
        var cont = document.getElementById('coContainer'); if (!cont) return;
        /* una sugerencia llena la primera fila vacia antes de agregar otra */
        var row = null;
        if (nombre) cont.querySelectorAll('.co-row').forEach(function (r) { if (!row && !r.querySelector('[name="co_nombre"]').value.trim()) row = r; });
        if (!row) {
            row = document.createElement('div');
            row.className = 'af-fila co-row';
            row.innerHTML =
                '<input type="text" name="co_nombre" class="sigma-nd-txt" aria-label="Nombre del componente" placeholder="Ej.: Motor principal" />' +
                afComboHtml('co_tipo', 'tipos', 'Ej.: Motor', 'Qué es') +
                afComboHtml('co_lado', 'lados', 'Ej.: Lado motor', 'Dónde va') +
                afFotoHtml('co_foto') +
                '<button type="button" class="af-borrar" title="Quitar esta fila" aria-label="Quitar esta fila" onclick="afQuitarFila(this, coCabecera)"><i class="mdi mdi-trash-can-outline"></i></button>';
            cont.appendChild(row);
        }
        if (nombre) { row.querySelector('[name="co_nombre"]').value = nombre; row.querySelector('[name="co_tipo"]').value = tipo || nombre; }
        coCabecera();
        if (!sinFoco) row.querySelector('input[name="' + (nombre ? 'co_lado' : 'co_nombre') + '"]').focus();
    }

    // Variables de condicion: que se mide + unidad + rango normal
    function vaAgregar(sinFoco) {
        var cont = document.getElementById('vaContainer'); if (!cont) return;
        var row = document.createElement('div');
        row.className = 'af-fila af-fila-var va-row';
        row.innerHTML =
            afComboHtml('va_nombre', 'vars', 'Ej.: Temperatura de la cámara', 'Qué se mide') +
            '<select name="va_unidad" class="sigma-nd-sel" aria-label="Unidad"><option value="">Unidad…</option>' + AF_UNIDADES + '</select>' +
            '<input type="text" name="va_min" class="sigma-nd-txt" inputmode="decimal" aria-label="Mínimo normal" placeholder="Mín." />' +
            '<input type="text" name="va_max" class="sigma-nd-txt" inputmode="decimal" aria-label="Máximo normal" placeholder="Máx." />' +
            '<button type="button" class="af-borrar" title="Quitar esta fila" aria-label="Quitar esta fila" onclick="afQuitarFila(this, vaCabecera)"><i class="mdi mdi-trash-can-outline"></i></button>';
        cont.appendChild(row);
        vaCabecera();
        if (!sinFoco) row.querySelector('input').focus();
    }
    function vaCabecera() { var c = document.getElementById('vaCab'), k = document.getElementById('vaContainer'); if (c && k) c.style.display = k.children.length ? '' : 'none'; }

    // Medidores (contadores): nombre + unidad + lectura de hoy
    function meAgregar(sinFoco) {
        var cont = document.getElementById('meContainer'); if (!cont) return;
        var row = document.createElement('div');
        row.className = 'af-fila af-fila-med me-row';
        row.innerHTML =
            afComboHtml('me_nombre', 'meds', 'Ej.: Horas de marcha', 'Qué cuenta') +
            '<select name="me_unidad" class="sigma-nd-sel" aria-label="Unidad"><option value="">Unidad…</option>' + AF_UNIDADES + '</select>' +
            '<input type="text" name="me_valor" class="sigma-nd-txt" inputmode="decimal" aria-label="Lectura de hoy" placeholder="Ej.: 1250" />' +
            '<button type="button" class="af-borrar" title="Quitar esta fila" aria-label="Quitar esta fila" onclick="afQuitarFila(this, meCabecera)"><i class="mdi mdi-trash-can-outline"></i></button>';
        cont.appendChild(row);
        meCabecera();
        if (!sinFoco) row.querySelector('input').focus();
    }
    function meCabecera() { var c = document.getElementById('meCab'), k = document.getElementById('meContainer'); if (c && k) c.style.display = k.children.length ? '' : 'none'; }
    function coCabecera() {
        var cab = document.getElementById('coCab'), cont = document.getElementById('coContainer');
        if (cab && cont) cab.style.display = cont.children.length ? '' : 'none';
    }
    function coSugerir(b) { coAgregar(b.getAttribute('data-nombre'), b.getAttribute('data-nombre')); }

    // Opciones de unidad (para las filas nuevas), armadas en el servidor.
    var AF_UNIDADES = '<%= BuildUnidadOptions() %>';
    var ND_UNIT_OPTIONS = '<option value="">Sin unidad</option>' + AF_UNIDADES;
    // Opciones de los combos con texto libre: tipos, lugares, variables y contadores.
    var AF_OPC = <%= OpcionesCombosJson() %>;
    function ndAgregar() {
        var cont = document.getElementById('ndContainer');
        if (!cont) return;
        var row = document.createElement('div');
        row.className = 'sigma-nd-fila nd-row';
        row.innerHTML =
            '<input type="text" name="nd_nombre" class="sigma-nd-txt" aria-label="Nombre del dato" placeholder="Ej.: Potencia" />' +
            '<input type="text" name="nd_valor" class="sigma-nd-txt" aria-label="Valor" placeholder="Ej.: 5,5" />' +
            '<select name="nd_unidad" class="sigma-nd-sel" aria-label="Unidad">' + ND_UNIT_OPTIONS + '</select>' +
            afFotoHtml('nd_foto') +
            '<button type="button" class="sigma-nd-quitar" title="Quitar este dato" aria-label="Quitar este dato" onclick="afQuitarFila(this, ndCabecera)"><i class="mdi mdi-trash-can-outline"></i></button>';
        cont.appendChild(row);
        ndCabecera();
        var inp = row.querySelector('input[name="nd_nombre"]');
        if (inp) inp.focus();
    }
    function ndCabecera() {
        var cab = document.getElementById('ndCab');
        if (cab) cab.style.display = document.querySelectorAll('.af .sigma-nd-fila:not([style*="none"])').length ? '' : 'none';
    }

    // Quita un dato ya guardado: vacía su valor (al Guardar se elimina del activo)
    // y oculta la fila para dar feedback.
    function ndQuitarDato(a) {
        var field = a.closest('.sigma-nd-fila');
        if (!field) return;
        var txt = field.querySelector('input[type="text"]');
        var sel = field.querySelector('select');
        if (txt) txt.value = '';
        if (sel) sel.selectedIndex = 0;
        field.style.display = 'none';
        ndCabecera();
    }

    /* ---- Confirmacion: el proximo paso sugerido ---- */
    function afSeguirConPartes() {
        var l = document.getElementById('afListo'), f = document.querySelector('.af');
        if (l) l.classList.add('af-oculto');
        if (f) f.classList.remove('af-oculto');
        fpIr(4);
        coAgregar('', '', false);
        return false;
    }
    function afAbrirCentro(url) {
        try { (window.top || window).location.href = url; } catch (e) { window.open(url, '_blank'); }
        return false;
    }
</script>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>

<%-- ============ CONFIRMACION AL CREAR ============
     Guardar un activo nuevo no cierra la ventana a ciegas: dice que quedo
     creado y sugiere lo que normalmente sigue. --%>
<asp:Panel ID="pnlListo" runat="server" Visible="false" ClientIDMode="Static">
    <div class="af-listo" id="afListo">
        <span class="af-listo-ico"><i class="mdi mdi-check-bold"></i></span>
        <h2><asp:Literal ID="litListoTitulo" runat="server" /></h2>
        <p><asp:Literal ID="litListoTexto" runat="server" /></p>
        <p class="af-listo-sig">¿Qué quieres hacer ahora?</p>
        <div class="af-listo-ops">
            <button type="button" class="af-listo-op es-comp" onclick="return afSeguirConPartes();">
                <i class="mdi mdi-puzzle-outline"></i><b>Agregar sus componentes</b>
                <span>Motor, rodamientos, sellos… lo que quieras seguir por separado.</span>
            </button>
            <asp:HyperLink ID="hlListoRepuestos" runat="server" CssClass="af-listo-op es-rep">
                <i class="mdi mdi-package-variant-closed"></i><b>Registrar sus repuestos</b>
                <span>Lo que se compra para este activo y se guarda en bodega.</span>
            </asp:HyperLink>
            <asp:HyperLink ID="hlListoCentro" runat="server" CssClass="af-listo-op es-centro" NavigateUrl="javascript:void(0)">
                <i class="mdi mdi-view-dashboard-outline"></i><b>Abrir su centro 360°</b>
                <span>Su resumen, órdenes, historial y condición.</span>
            </asp:HyperLink>
        </div>
        <div class="af-listo-pie">
            <asp:HyperLink ID="hlListoOtro" runat="server" CssClass="af-btn es-contorno"><i class="mdi mdi-plus"></i>Crear otro activo</asp:HyperLink>
            <button type="button" class="af-btn es-primario" onclick="closeWindow(); return false;"><i class="mdi mdi-check"></i>Listo</button>
        </div>
    </div>
</asp:Panel>

<asp:Panel ID="pnlSecciones" runat="server" CssClass="af">

    <asp:HiddenField ID="hdnPaso" runat="server" Value="1" />

    <%-- ============ RIEL: pasos + ayuda del paso ============ --%>
    <aside class="af-rail">
        <nav class="af-pasos" aria-label="Pasos de la ficha">
            <button type="button" class="af-paso" data-ir="1" onclick="fpIr(1)"><span class="af-n"><span>1</span><i class="mdi mdi-check"></i></span><span><b>Información básica</b><small>Qué es el activo</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="2" onclick="fpIr(2)"><span class="af-n"><span>2</span><i class="mdi mdi-check"></i></span><span><b>Ubicación</b><small>Dónde está</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="3" onclick="fpIr(3)"><span class="af-n"><span>3</span><i class="mdi mdi-check"></i></span><span><b>Datos técnicos</b><small>Características, año y documentos</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="4" onclick="fpIr(4)"><span class="af-n"><span>4</span><i class="mdi mdi-check"></i></span><span><b>Componentes</b><small><asp:Literal ID="litPartesRail" runat="server" Text="Motor, rodamientos…" /></small></span></button>
            <button type="button" class="af-paso" data-ir="5" onclick="fpIr(5)"><span class="af-n"><span>5</span><i class="mdi mdi-check"></i></span><span><b>Variables</b><small><asp:Literal ID="litVarsRail" runat="server" Text="Qué se mide: temperatura…" /></small></span></button>
            <button type="button" class="af-paso" data-ir="6" onclick="fpIr(6)"><span class="af-n"><span>6</span><i class="mdi mdi-check"></i></span><span><b>Medidores</b><small><asp:Literal ID="litMedsRail" runat="server" Text="Horas, ciclos, kilómetros" /></small></span></button>
        </nav>

        <div class="af-tip" data-paso="1"><i class="mdi mdi-information-variant"></i><div><b>Completa lo principal.</b> Con el nombre, el tipo, el estado, la criticidad y la planta ya puedes guardar. Lo demás lo agregas cuando quieras.</div></div>
        <div class="af-tip" data-paso="2"><i class="mdi mdi-information-variant"></i><div><b>Indica dónde está.</b> Si depende de una máquina más grande, como el compresor de una cámara de frío, marca «Sí» y elígela: quedará como su subactivo.</div></div>
        <div class="af-tip" data-paso="3"><i class="mdi mdi-information-variant"></i><div><b>Este paso es opcional.</b> Anota sus características (potencia, capacidad, voltaje…) desde el manual o la ficha del fabricante. Puedes hacerlo ahora o después, desde su ficha.</div></div>
        <div class="af-tip" data-paso="4"><i class="mdi mdi-information-variant"></i><div><b>¿Le importa esa pieza en particular?</b> Es un componente. <b>¿Da lo mismo cuál uses de la bodega?</b> Es un repuesto y se agrega después.</div></div>
        <div class="af-tip" data-paso="5"><i class="mdi mdi-information-variant"></i><div><b>Este paso es opcional.</b> Una variable dice <b>cómo está</b> el activo: la temperatura, la presión, la vibración. Si anotas el rango normal, SIGMA avisa cuando una lectura se sale.</div></div>
        <div class="af-tip" data-paso="6"><i class="mdi mdi-information-variant"></i><div><b>Este paso es opcional.</b> Un medidor dice <b>cuánto ha trabajado</b>: horas de marcha, ciclos, kilómetros. Sirve para programar el mantenimiento por uso y no solo por calendario.</div></div>

        <%-- Solo en el centro: quien lo creo y que cuelga de el. --%>
        <asp:Panel ID="pnlSobre" runat="server" Visible="false" CssClass="af-sobre">
            <h4>Sobre esta ficha</h4>
            <asp:Literal ID="litAuditoriaPie" runat="server" />
            <asp:Literal ID="litSobreEstructura" runat="server" />
        </asp:Panel>
    </aside>

    <div class="af-cuerpo">

        <%-- Lo que falta para guardar, con un boton que lleva a cada campo. --%>
        <div class="af-faltan" id="afFaltan" role="alert" aria-live="assertive">
            <i class="mdi mdi-alert-circle-outline"></i>
            <div><b id="afFaltanTit">Faltan datos para poder guardar</b><span>Toca cada uno para ir a completarlo.</span>
                <div class="af-faltan-lista" id="afFaltanLista"></div></div>
        </div>

        <%-- ============ PASO 1 · INFORMACIÓN BÁSICA ============ --%>
        <section class="af-seccion" data-paso="1">
            <header class="af-cab"><i class="mdi mdi-cog-outline"></i><div><h3>Información básica</h3><p>Lo que identifica al activo.</p></div></header>

            <span class="af-oculto"><asp:Label ID="lblId" runat="server"></asp:Label></span>

            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Código</label>
                    <%-- El prefijo lo pone el sistema; el resto lo escribe quien
                         crea el activo. Van juntos para que se lea como UN codigo. --%>
                    <div class="sg-codigo">
                        <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" UpperCase="true" ReadOnly="true" />
                    </div>
                    <span class="sigma-modal-ayuda">Si lo dejas vacío, se numera solo.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Nombre <span class="req">*</span></label>
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" placeholder="Ej.: Cámara de frío 1" />
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Escribe cómo le dicen al activo en la planta.</span>
                    <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Tipo <span class="req">*</span></label>
                    <%-- Texto libre (bloque 342): si el tipo no existe, se escribe y se crea al guardar. --%>
                    <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                        OnSelectedIndexChanged="cboTipo_SelectedIndexChanged" Filter="Contains" Width="100%"
                        AllowCustomText="true" EmptyMessage="Elige o escribe uno nuevo" />
                    <span class="sigma-modal-ayuda">¿No está? Escríbelo y se crea al guardar.</span>
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige el tipo de la lista o escribe uno nuevo.</span>
                    <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequeridoLibre" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Modelo</label>
                    <rad:RadComboBox2 ID="cboModelo" runat="server" AutoPostBack="true"
                        OnSelectedIndexChanged="cboModelo_SelectedIndexChanged" Filter="Contains" Width="100%"
                        AllowCustomText="true" EmptyMessage="Elige o escribe uno nuevo" />
                    <span class="sigma-modal-ayuda">Muestra los de ese tipo y esa marca. ¿No está? Escríbelo y se crea.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Estado <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboEstado" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige cómo está el activo hoy.</span>
                    <asp:CustomValidator ID="cvEstado" runat="server" ControlToValidate="cboEstado" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Criticidad <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboCriticidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda">¿Qué tan grave es si se detiene?</span>
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige qué tan grave es si se detiene.</span>
                    <asp:CustomValidator ID="cvCriticidad" runat="server" ControlToValidate="cboCriticidad" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Marca</label>
                    <rad:RadComboBox2 ID="cboFabricante" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                        OnSelectedIndexChanged="cboFabricante_Changed" OnTextChanged="cboFabricante_Changed" Filter="Contains" Width="100%" MaxLength="200"
                        AllowCustomText="true" EmptyMessage="Elige o escribe una nueva" />
                    <span class="sigma-modal-ayuda">¿No está? Escríbela y se crea al guardar.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>N° de serie</label>
                    <WebControls:TextBox2 ID="txtSerie" runat="server" MaxLength="100" placeholder="Está en la placa del activo" />
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>Descripción</label>
                    <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" placeholder="Para qué sirve o algo que convenga saber" />
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>Foto del activo</label>
                    <div class="af-drop af-foto">
                        <span class="af-drop-ico">
                            <asp:Panel ID="pnlSinImagen" runat="server" CssClass="af-foto-vacia"><i class="mdi mdi-image-outline"></i></asp:Panel>
                            <asp:Panel ID="pnlImagenActual" runat="server" Visible="false" CssClass="af-foto-actual">
                                <a id="lnkImagenActual" runat="server" target="_blank" rel="noopener" title="Ampliar">
                                    <img id="imgActual" runat="server" alt="Foto actual del activo" data-ampliar="1" />
                                </a>
                            </asp:Panel>
                            <img id="sigmaThumb" alt="Vista previa" style="display:none" />
                        </span>
                        <span class="af-drop-txt">
                            <b>Arrastra una foto aquí</b>
                            <span>PNG o JPG. Ayuda a reconocer el activo en la planta.</span>
                            <span id="sigmaFileName" class="sigma-img-name"></span>
                            <asp:Panel ID="pnlQuitarImagen" runat="server" Visible="false" CssClass="af-quitar-foto">
                                <asp:CheckBox ID="chkQuitarImagen" runat="server" Text="Quitar la foto actual al guardar" />
                            </asp:Panel>
                        </span>
                        <span class="af-drop-acc">
                            <a id="sigmaQuitar" href="javascript:void(0)" onclick="sigmaQuitarSel()" class="af-link-quitar" style="display:none;"><i class="mdi mdi-close"></i>Quitar</a>
                            <label for="fuImagen" class="af-btn es-suave"><i class="mdi mdi-camera-outline"></i>Elegir foto</label>
                        </span>
                        <asp:FileUpload ID="fuImagen" runat="server" accept="image/*" ClientIDMode="Static" onchange="sigmaPrevImg(this)" style="display:none;" />
                    </div>
                </div>
            </div>
        </section>

        <%-- ============ PASO 2 · UBICACIÓN ============ --%>
        <section class="af-seccion" data-paso="2">
            <header class="af-cab"><i class="mdi mdi-map-marker-outline"></i><div><h3>Ubicación</h3><p>En qué planta y área está el activo.</p></div></header>

            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Planta <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige la planta donde está el activo.</span>
                    <asp:CustomValidator ID="cvPlanta" runat="server" ControlToValidate="cboPlanta" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Área</label>
                    <rad:RadComboBox2 ID="cboArea" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda">Ej.: Refrigeración › Línea 1.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Centro de costo</label>
                    <rad:RadComboBox2 ID="cboCentroCosto" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>¿Depende de otra máquina?</label>
                    <div class="af-pills" role="radiogroup" aria-label="¿Depende de otra máquina?">
                        <input type="radio" name="afDependeOpc" id="afDependeNo" onclick="afMarcarDepende(false)" /><label for="afDependeNo">No, es una máquina principal</label>
                        <input type="radio" name="afDependeOpc" id="afDependeSi" onclick="afMarcarDepende(true)" /><label for="afDependeSi">Sí, depende de otra</label>
                    </div>
                    <span class="sigma-modal-ayuda">Si depende de una más grande, quedará como su <b>subactivo</b>. Ej.: el compresor de una cámara de frío.</span>
                </div>
                <div class="sigma-modal-field af-padre" hidden>
                    <label>¿De cuál máquina depende?</label>
                    <rad:RadComboBox2 ID="cboPadre" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                </div>
            </div>
        </section>

        <%-- ============ PASO 3 · DATOS TÉCNICOS ============ --%>
        <section class="af-seccion" data-paso="3">
            <header class="af-cab"><i class="mdi mdi-tune-variant"></i><div><h3>Datos técnicos</h3><p>Año, puesta en marcha, características y documentos.</p></div></header>

            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Año de fabricación</label>
                    <rad:RadComboBox2 ID="cboAnio" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                </div>
                <div class="sigma-modal-field">
                    <label>Puesta en marcha</label>
                    <div class="sigma-modal-fecha">
                        <WebControls:Calendar ID="calPuestaMarcha" runat="server" />
                    </div>
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>¿Está en uso? <span class="req">*</span></label>
                    <div class="af-linea">
                        <div class="af-pills">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="Sí" GroupName="Habilitado" Checked="true" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="No" GroupName="Habilitado" />
                        </div>
                        <span class="sigma-modal-ayuda">Si eliges «No», deja de aparecer en las listas, pero su historia se conserva.</span>
                    </div>
                </div>
            </div>

            <%-- Datos de placa: nombre · valor · unidad, propios del activo. --%>
            <asp:Panel ID="pnlDatosTecnicos" runat="server">
                <p class="af-sub">Características técnicas<small>Lo que describe al activo. Ej.: Potencia 5,5 kW. La foto de cada dato queda en Documentos con su nombre.</small></p>
                <div class="af-filas-cab" id="ndCab"><span>Nombre</span><span>Valor</span><span>Unidad</span><span class="c">Foto</span><span></span></div>
                <div class="af-filas">
                    <asp:Repeater ID="rptDatos" runat="server" OnItemDataBound="rptDatos_ItemDataBound">
                        <ItemTemplate>
                            <div class="sigma-nd-fila">
                                <label><%# Server.HtmlEncode(Convert.ToString(Eval("ate_nombre"))) %></label>
                                <asp:HiddenField runat="server" ID="hdnAte" Value='<%# Eval("ate_id") %>' />
                                <asp:TextBox runat="server" ID="txtValor" Text='<%# Eval("valor_edit") %>' MaxLength="200" CssClass="sigma-nd-txt" />
                                <asp:DropDownList runat="server" ID="ddlUnidad" CssClass="sigma-nd-sel" />
                                <label class="af-fila-foto" title="Agregar una foto de este dato"><i class="mdi mdi-camera-plus-outline"></i><asp:FileUpload runat="server" ID="fuDato" accept="image/*" onchange="afFotoFila(this)" /></label>
                                <a href="javascript:void(0)" onclick="ndQuitarDato(this)" title="Quitar este dato" aria-label="Quitar este dato" class="sigma-nd-quitar"><i class="mdi mdi-trash-can-outline"></i></a>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                    <div id="ndContainer" class="af-filas"></div>
                </div>
                <button type="button" class="af-btn es-suave" style="margin-top:10px" onclick="ndAgregar()"><i class="mdi mdi-plus"></i>Agregar dato</button>
            </asp:Panel>

            <%-- Documentos: manuales, planos, certificados. --%>
            <div>
                <p class="af-sub">Documentos<small>Manuales, planos o certificados.</small></p>
                <asp:Repeater ID="rptArchivos" runat="server" OnItemCommand="rptArchivos_ItemCommand" OnItemDataBound="rptArchivos_ItemDataBound">
                    <HeaderTemplate><div class="sigma-doc-lista"></HeaderTemplate>
                    <ItemTemplate>
                        <div class="sigma-doc">
                            <i class='mdi <%# (bool)Eval("es_imagen") ? "mdi-image-outline" : "mdi-file-document-outline" %>'></i>
                            <span class="nom"><%# Server.HtmlEncode(Convert.ToString(Eval("arc_nombre"))) %></span>
                            <asp:HyperLink runat="server" Target="_blank" CssClass="ver"
                                NavigateUrl='<%# VerUrl((int)Eval("arc_id")) %>'><i class="mdi mdi-open-in-new"></i> Ver</asp:HyperLink>
                            <asp:LinkButton runat="server" CssClass="quitar" CommandName="quitar" CommandArgument='<%# Eval("arc_id") %>'
                                OnClientClick="return confirm('¿Quitar este documento del activo?');"><i class="mdi mdi-close"></i> Quitar</asp:LinkButton>
                        </div>
                    </ItemTemplate>
                    <FooterTemplate></div></FooterTemplate>
                </asp:Repeater>

                <asp:Panel ID="pnlSubirDocs" runat="server" CssClass="af-drop af-docs">
                    <span class="af-drop-ico"><i class="mdi mdi-file-document-outline"></i></span>
                    <span class="af-drop-txt">
                        <b>Arrastra aquí manuales, planos o certificados</b>
                        <span>PDF o imágenes. Puedes subir varios a la vez.</span>
                        <span id="sigmaDocsLista"></span>
                    </span>
                    <span class="af-drop-acc">
                        <label for="fuDocs" class="af-btn es-suave"><i class="mdi mdi-upload"></i>Elegir archivos</label>
                    </span>
                    <asp:FileUpload ID="fuDocs" runat="server" AllowMultiple="true" ClientIDMode="Static"
                        accept=".pdf,image/*" onchange="sigmaDocsNombres(this)" style="display:none;" />
                </asp:Panel>
            </div>
        </section>

        <%-- ============ PASO 4 · PARTES ============
             Las partes del equipo que se quieren seguir, agregadas aqui mismo. --%>
        <section class="af-seccion" data-paso="4">
            <header class="af-cab"><i class="mdi mdi-puzzle-outline"></i><div><h3>Componentes</h3><p>Las partes del activo que quieres seguir por separado: el motor, un rodamiento, una válvula.</p></div></header>

            <asp:Panel ID="pnlComponentes" runat="server" CssClass="af-grid">
                <div class="af-ancho">
                    <asp:Literal ID="litComponentes" runat="server" />
                    <div class="af-filas-cab" id="coCab" style="display:none"><span>Nombre del componente</span><span>Qué es</span><span>Dónde va</span><span class="c">Foto</span><span></span></div>
                    <div id="coContainer" class="af-filas"></div>
                    <button type="button" class="af-btn es-suave" style="margin-top:10px" onclick="coAgregar()"><i class="mdi mdi-plus"></i>Agregar componente</button>
                </div>
                <div class="af-ancho af-sugerir">
                    <p><b>Componentes comunes</b> · toca uno para agregarlo</p>
                    <div class="af-sugerir-chips"><%= OpcionesPartesComunes() %></div>
                </div>
            </asp:Panel>
        </section>

        <%-- ============ PASO 5 · VARIABLES DE CONDICIÓN ============ --%>
        <section class="af-seccion" data-paso="5">
            <header class="af-cab"><i class="mdi mdi-pulse"></i><div><h3>Variables de condición</h3><p>Lo que se mide para saber cómo está el activo y entre qué valores es normal.</p></div></header>
            <div>
                <asp:Literal ID="litVariables" runat="server" />
                <div class="af-filas-cab af-fila-var" id="vaCab" style="display:none"><span>Qué se mide</span><span>Unidad</span><span>Mínimo normal</span><span>Máximo normal</span><span></span></div>
                <div id="vaContainer" class="af-filas"></div>
                <button type="button" class="af-btn es-suave" style="margin-top:10px" onclick="vaAgregar()"><i class="mdi mdi-plus"></i>Agregar variable</button>
                <p class="sigma-modal-ayuda" style="margin:10px 0 0">Ej.: Temperatura de la cámara, en °C, normal entre −22 y −18. Si no está en la lista, escríbela y se crea.</p>
            </div>
        </section>

        <%-- ============ PASO 6 · MEDIDORES ============ --%>
        <section class="af-seccion" data-paso="6">
            <header class="af-cab"><i class="mdi mdi-counter"></i><div><h3>Medidores</h3><p>Lo que cuenta cuánto ha trabajado el activo, con la lectura de hoy.</p></div></header>
            <div>
                <asp:Literal ID="litMedidores" runat="server" />
                <div class="af-filas-cab af-fila-med" id="meCab" style="display:none"><span>Qué cuenta</span><span>Unidad</span><span>Lectura de hoy</span><span></span></div>
                <div id="meContainer" class="af-filas"></div>
                <button type="button" class="af-btn es-suave" style="margin-top:10px" onclick="meAgregar()"><i class="mdi mdi-plus"></i>Agregar medidor</button>
                <p class="sigma-modal-ayuda" style="margin:10px 0 0">Ej.: Horas de marcha del compresor, en horas, hoy marca 1.250.</p>
            </div>
        </section>

        <%-- ============ LA BARRA DEL PIE ============
             Anterior a la izquierda; Cancelar, Siguiente y Guardar a la
             derecha, en ese orden y en la misma fila, en el modal y en el
             centro. Lo unico que cambia es la clase: en el centro va pegada
             abajo porque la ficha es larga. --%>
        <div class="af-pie">
            <button type="button" class="af-btn es-contorno" id="fpBtnAnterior" onclick="fpIr(fpActual() - 1)"><i class="mdi mdi-arrow-left"></i>Anterior</button>
            <span class="af-pie-donde"><span id="fpDonde"></span>
                <span class="sg-a3-ficha-sucio" id="sgA3Sucio"><i class="mdi mdi-circle-medium"></i>Cambios sin guardar</span></span>
            <div class="af-pie-der">
                <button type="button" class="af-btn es-contorno" id="fpBtnSiguiente" onclick="fpSiguiente()">Siguiente<i class="mdi mdi-arrow-right"></i></button>

                <asp:Panel ID="pnlAccionesModal" runat="server" CssClass="af-pie-acc">
                    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cancelar" CssClass="af-btn es-ghost af-cancelar" OnClientClick="closeWindow(); return false;" />
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" CssClass="af-btn es-primario af-guardar" OnClick="btnGuardar_Click" ValidationGroup="Activo" OnClientClick="sigmaGuardando();" />
                </asp:Panel>

                <asp:Panel ID="pnlAccionesCentro" runat="server" Visible="false" CssClass="af-pie-acc">
                    <WebControls:PushButton ID="btnCancelar" runat="server" Text="Cancelar" CssClass="af-btn es-ghost af-cancelar" OnClick="btnCancelar_Click" CausesValidation="false" />
                    <WebControls:PushButton ID="btnGuardarCentro" runat="server" Text="Guardar cambios" CssClass="af-btn es-primario af-guardar" OnClick="btnGuardar_Click" ValidationGroup="Activo" OnClientClick="sigmaGuardando();" />
                </asp:Panel>
            </div>
        </div>

        <wuc:Auditoria runat="server" ID="wucAuditoria" />
    </div>
</asp:Panel>

<%-- Velo de guardado: cubre la ficha para que se note que está trabajando
     y no se pueda volver a apretar Guardar mientras sube la imagen. --%>
<div id="sigmaGuardandoOv" style="display:none;position:fixed;inset:0;z-index:99999;background:rgba(255,255,255,.82);align-items:center;justify-content:center;">
    <div style="display:flex;flex-direction:column;align-items:center;gap:12px;text-align:center;">
        <div style="width:44px;height:44px;border:4px solid #E2E7F0;border-top-color:#6732F4;border-radius:50%;animation:sigmaSpin .8s linear infinite;"></div>
        <div style="font-size:15px;font-weight:700;color:#17223B;">Guardando el activo…</div>
        <div style="font-size:13px;color:#68738A;">Si elegiste una foto o documentos, se están subiendo. No cierres esta ventana.</div>
    </div>
</div>
<style>@keyframes sigmaSpin{to{transform:rotate(360deg)}}</style>

    </ContentTemplate>
</asp:UpdatePanel>
