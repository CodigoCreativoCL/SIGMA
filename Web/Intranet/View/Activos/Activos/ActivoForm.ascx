<%@ Control Language="C#" AutoEventWireup="true" CodeFile="ActivoForm.ascx.cs" Inherits="View_Activos_Activos_ActivoForm" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<%-- EL FORMULARIO DEL ACTIVO, UNA SOLA VEZ

     Lo muestran dos pantallas: el modal de alta -desde el listado y
     desde el centro- y la pestaña Ficha del centro del activo. Es el
     mismo control con dos vestidos, y no dos formularios: duplicarlo
     obligaba a agregar cada campo nuevo en dos partes. --%>

<style type="text/css">
        /* Cargador de imagen propio: botón estilizado + nombre + quitar. El
           input file real va oculto; el label lo dispara. */
        .sigma-img-uploader { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
        /* Agregar un dato, una imagen o un documento no es LA accion de la
           pantalla: es una mas. Va en tono suave para que el morado quede
           reservado a Guardar, que es lo unico que no se puede deshacer
           solo. */
        .sigma-img-btn {
            display: inline-flex; align-items: center; gap: 7px;
            background: #fff; color: #4b5563; border: 1px solid #e5e7eb;
            border-radius: 9px;
            padding: 9px 16px; font-size: 13px; font-weight: 600; cursor: pointer;
            transition: background .15s ease, border-color .15s ease; margin: 0;
        }
        .sigma-img-btn i { color: #6C5CFF; }
        .sigma-img-btn:hover { background: #f7f7fc; border-color: #d7dbe7; }
        .sigma-img-btn i { font-size: 17px; }
        .sigma-img-name { font-size: 12.5px; color: #475569; word-break: break-all; }
        .sigma-img-quitar { font-size: 12px; color: #b91c1c; font-weight: 600; text-decoration: none; display: inline-flex; align-items: center; gap: 4px; }
        .sigma-doc-lista { display: grid; gap: 8px; margin-bottom: 10px; }
        .sigma-doc { display: flex; align-items: center; gap: 10px; padding: 9px 12px; border: 1px solid #e5e7eb; border-radius: 10px; font-size: 13px; color: #334155; }
        .sigma-doc > i { font-size: 18px; color: #6C5CFF; }
        .sigma-doc .nom { flex: 1 1 auto; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .sigma-doc .ver { color: #6C5CFF !important; font-weight: 600; text-decoration: none; }
        .sigma-doc .quitar { color: #b91c1c !important; font-weight: 600; text-decoration: none; }

        /* ---- Asistente de tres pasos ---- */
        .fp-pasos { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; margin-bottom: 14px; }
        .fp-paso { display: flex; align-items: center; gap: 10px; text-align: left; padding: 12px 14px; border: 1.5px solid #E2E7F0;
            border-radius: 14px; background: #fff; cursor: pointer; font: inherit; color: #17223B; }
        .fp-paso b { display: block; font-size: 14px; }
        .fp-paso small { display: block; font-size: 12px; color: #68738A; }
        .fp-n { flex: 0 0 auto; width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center;
            background: #F2EFFF; color: #6732F4; font-weight: 800; font-size: 15px; }
        .fp-paso.es-activo { border-color: #6732F4; background: #F2EFFF; }
        .fp-paso.es-activo .fp-n { background: #6732F4; color: #fff; }
        .fp-paso.es-hecho .fp-n { background: #E9F7F0; color: #16855B; }
        .fp-paso:focus-visible { outline: 3px solid rgba(22,198,201,.27); }
        @media (max-width: 760px) { .fp-pasos { grid-template-columns: 1fr; } }
        .sg-paso { display: none; }
        .sg-paso.es-activo { display: grid; gap: 12px; grid-template-columns: minmax(0, 1fr); }
        .sg-paso.es-activo > .sigma-form-seccion { margin: 0; }
        @media (min-width: 900px) {
            /* paso 1: identificacion y foto lado a lado, ubicacion debajo */
            .sg-paso.fp-paso-1.es-activo { grid-template-columns: minmax(0, 1fr) 280px; }
            .sg-paso.fp-paso-1 > .es-ubicacion { grid-column: 1 / -1; }
            .sg-paso.fp-paso-2.es-activo { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); }
            .sg-paso.fp-paso-2 > .es-tecnica { grid-column: 1 / -1; }
        }
        /* Menos texto: en el asistente quedan solo las ayudas que explican un
           concepto (.es-clave); el ID de un activo nuevo no dice nada. */
        .sg-paso .sigma-modal-ayuda { display: none; }
        .sg-paso .sigma-modal-ayuda.es-clave { display: block; }
        .sg-paso .es-identificacion .es-id { display: none; }
        .fp-nav { display: flex; align-items: center; gap: 10px; margin-top: 14px; }
        .fp-donde { flex: 1 1 auto; text-align: center; font-size: 12.5px; color: #68738A; font-weight: 600; }
        .fp-btn { display: inline-flex; align-items: center; gap: 6px; min-height: 40px; padding: 8px 18px; border-radius: 10px; font: inherit;
            font-weight: 700; font-size: 13.5px; cursor: pointer; border: 1.5px solid #087BEA; background: #fff; color: #087BEA; }
        .fp-btn:hover { background: #EAF4FF; }
        .fp-btn[hidden] { display: none; }

        /* Filas de componentes (bloque 342) */

        .sigma-co-cab, .sigma-co-fila { display: grid; grid-template-columns: minmax(0,1.4fr) minmax(0,1fr) minmax(0,1fr) 18px; gap: 6px; align-items: center; }
        .sigma-co-cab { font-size: 11px; font-weight: 700; color: #8a93a6; text-transform: uppercase; letter-spacing: .03em; padding: 0 2px 6px; }
        .sigma-co-fila { margin-bottom: 8px; }
        .sigma-co-lista { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 12px; }
        .sigma-co-chip { display: inline-flex; align-items: center; gap: 5px; padding: 5px 10px; border-radius: 999px;
            background: #E8FBFB; color: #007F8A; font-size: 12px; font-weight: 700; }

        /* El asterisco del campo obligatorio se ve, no se lee entre parentesis. */
        .req { color: #dc2626; font-weight: 700; }

        /* Zona vacia de la imagen: dice que falta y como ponerlo. */
        .sigma-img-vacio {
            width: 100%;
            display: grid;
            place-items: center;
            gap: 4px;
            padding: 26px 16px;
            border: 1.5px dashed #d7dbe7;
            border-radius: 12px;
            background: #fbfbfe;
            text-align: center;
        }
        .sigma-img-vacio i { font-size: 30px; color: #b6bccd; }
        .sigma-img-vacio strong { font-size: 13.5px; color: #475569; }
        .sigma-img-vacio span { font-size: 12px; color: #8a93a6; max-width: 260px; }

        /* Documentos: la misma zona, para que se lea como un lugar donde soltar. */
        .sigma-doc-zona {
            display: grid;
            place-items: center;
            gap: 8px;
            padding: 22px 16px;
            border: 1.5px dashed #d7dbe7;
            border-radius: 12px;
            background: #fbfbfe;
            text-align: center;
        }
        .sigma-doc-zona .sigma-modal-ayuda { text-align: center; }
        .sigma-doc-btn { margin: 0; }

        /* Encabezado de los datos tecnicos: tres palabras que evitan tener que
           adivinar cual caja es cual. */
        .sigma-nd-lista { display: grid; gap: 8px; }
        .sigma-nd-fila {
            display: grid;
            grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr) 112px 18px;
            gap: 6px;
            align-items: center;
        }
        .sigma-nd-fila > label {
            margin: 0;
            font-size: 12.5px;
            color: #475569;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .sigma-nd-txt, .sigma-nd-sel {
            width: 100%;
            min-width: 0;
            padding: 9px 11px;
            border: 1px solid #e5e7eb;
            border-radius: 9px;
            font-size: 13px;
            background: #fff;
        }
        .sigma-nd-sel { padding: 9px 8px; }
        .sigma-nd-quitar { color: #b91c1c; font-weight: 700; text-decoration: none; text-align: center; }

        .sigma-nd-cab {
            display: grid;
            grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr) 112px 18px;
            gap: 6px;
            padding: 0 2px 6px;
            border-bottom: 1px solid #eceef5;
            margin-bottom: 8px;
            font-size: 11px;
            font-weight: 700;
            color: #8a93a6;
            text-transform: uppercase;
            letter-spacing: .03em;
        }
    </style>
    <script type="text/javascript">
        // Muestra los nombres de los documentos elegidos (aún sin subir).
        function sigmaDocsNombres(input) {
            var d = document.getElementById('sigmaDocsLista');
            if (!d) return;
            if (input.files && input.files.length) {
                var n = [];
                for (var i = 0; i < input.files.length; i++) n.push(input.files[i].name);
                d.textContent = '▸ ' + n.join('  ·  ');
            } else { d.textContent = ''; }
        }
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }

        // Guardado: muestra el velo "Guardando…" SIN bloquear el postback.
        // Importante: NO retorna valor (este PushButton no reenvía si el
        // OnClientClick retorna). El velo se muestra con un setTimeout, después
        // de que corra la validación del botón: si algún campo falla,
        // Page_IsValid queda en false y no se muestra el velo (no se envió).
        function sigmaGuardando() {
            setTimeout(function () {
                if (typeof Page_IsValid !== 'undefined' && Page_IsValid === false) { fpIr(1); return; }
                var ov = document.getElementById('sigmaGuardandoOv');
                if (ov) ov.style.display = 'flex';
            }, 0);
        }

        // Al elegir una imagen: muestra el nombre, el botón Quitar y una
        // miniatura de vista previa al instante (sin subir todavía; sube al
        // guardar).
        function sigmaPrevImg(input) {
            var name = document.getElementById('sigmaFileName');
            var quit = document.getElementById('sigmaQuitar');
            var img = document.getElementById('sigmaThumb');
            if (input.files && input.files[0]) {
                if (name) name.textContent = input.files[0].name;
                if (quit) quit.style.display = 'inline-flex';
                if (img && window.FileReader) {
                    var r = new FileReader();
                    r.onload = function (e) { img.src = e.target.result; img.style.display = 'block'; };
                    r.readAsDataURL(input.files[0]);
                }
            } else {
                if (name) name.textContent = '';
                if (quit) quit.style.display = 'none';
                if (img) { img.src = ''; img.style.display = 'none'; }
            }
        }
        function sigmaQuitarSel() {
            var input = document.getElementById('fuImagen');
            if (input) { input.value = ''; sigmaPrevImg(input); }
        }

        // Crear un modelo al vuelo, sin ir al catálogo. Abre la ficha de modelo
        // en un modal; al cerrarla, refresh() recarga la lista de modelos.
        function nuevoModelo() {
            var url = '<%=ResolveUrl("~/View/Activos/Modelos/ActivoModelo.aspx") %>?query=0';
            var M = (window.parent && window.parent.SigmaModal) ? window.parent.SigmaModal : window.SigmaModal;
            if (M && M.open) { M.open({ url: url, title: 'Nuevo modelo', width: 820, initialHeight: 560 }); }
            else { window.open(url, '_blank'); }
            return false;
        }
        /* La invoca el modal de modelo al cerrarse. Se define solo si la
           pagina que aloja el formulario no trajo el suyo: el centro del
           activo ya tiene un refresh() que sabe a que seccion volver. */
        window.refresh = window.refresh || function () { __doPostBack('', ''); };

        /* ---- Asistente: el paso vive en hdnPaso para sobrevivir a los
           postbacks parciales (cambiar el tipo recarga los modelos). ---- */
        function fpCampo() { return document.querySelector('[id$="hdnPaso"]'); }
        function fpActual() { var h = fpCampo(); var n = h ? parseInt(h.value, 10) : 1; return n >= 1 && n <= 3 ? n : 1; }
        function fpIr(n) {
            n = Math.max(1, Math.min(3, n || 1));
            var h = fpCampo(); if (h) h.value = n;
            document.querySelectorAll('.sg-paso').forEach(function (p) { p.classList.toggle('es-activo', +p.getAttribute('data-paso') === n); });
            document.querySelectorAll('.fp-paso').forEach(function (b) {
                var k = +b.getAttribute('data-ir');
                b.classList.toggle('es-activo', k === n); b.classList.toggle('es-hecho', k < n);
                b.setAttribute('aria-current', k === n ? 'step' : 'false');
            });
            var ant = document.getElementById('fpBtnAnterior'), sig = document.getElementById('fpBtnSiguiente'), d = document.getElementById('fpDonde');
            if (ant) ant.hidden = n === 1;
            if (sig) sig.hidden = n === 3;
            if (d) d.textContent = 'Paso ' + n + ' de 3';
            return false;
        }
        /* Del paso 1 no se avanza con un obligatorio vacio: se marca ahi. */
        function fpSiguiente() {
            var n = fpActual();
            if (n === 1 && typeof Page_ClientValidate === 'function' && !Page_ClientValidate('Activo')) return false;
            return fpIr(n + 1);
        }
        function fpIniciar() { if (document.querySelector('.sg-paso')) fpIr(fpActual()); }
        if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fpIniciar); else setTimeout(fpIniciar, 0);
        window.addEventListener('load', function () {
            if (window.Sys && Sys.WebForms) Sys.WebForms.PageRequestManager.getInstance().add_endRequest(fpIniciar);
        });

        /* Un combo con texto libre es valido si tiene algo escrito, aunque no
           este en la lista: lo que no existe se crea al guardar. */
        function validaComboTexto(sender, args) {
            var c = $find(sender.controltovalidate);
            var t = c ? (c.get_text() || '').trim() : '';
            if (c && c.get_emptyMessage && t === c.get_emptyMessage()) t = '';
            args.IsValid = t !== '';
            if (c && c._element) c._element.style.border = args.IsValid ? '' : 'solid 1px red';
        }

        // Componentes nuevos: nombre + que es + donde va (opciones del servidor)
        var CO_LADOS = '<option value="">—</option><%= OpcionesComponenteLado() %>';
        function coAgregar() {
            var cont = document.getElementById('coContainer'); if (!cont) return;
            var row = document.createElement('div');
            row.className = 'sigma-co-fila co-row';
            row.innerHTML =
                '<input type="text" name="co_nombre" class="sigma-nd-txt" placeholder="Ej.: Motor principal" />' +
                '<input type="text" name="co_tipo" class="sigma-nd-txt" list="coTiposLista" placeholder="Ej.: Motor, Quemador" />' +
                '<select name="co_lado" class="sigma-nd-sel">' + CO_LADOS + '</select>' +
                '<a href="javascript:void(0)" onclick="this.closest(\'.co-row\').remove()" class="sigma-nd-quitar">✕</a>';
            cont.appendChild(row);
            var cab = document.getElementById('coCab'); if (cab) cab.style.display = '';
            row.querySelector('input').focus();
        }

        // Opciones de unidad (para las filas nuevas), armadas en el servidor.
        var ND_UNIT_OPTIONS = '<option value="">— sin unidad</option><%= BuildUnidadOptions() %>';
        // Agrega una fila nueva de dato técnico (nombre + unidad + valor).
        function ndAgregar() {
            var cont = document.getElementById('ndContainer');
            if (!cont) return;
            var row = document.createElement('div');
            row.className = 'sigma-nd-fila nd-row';
            row.innerHTML =
                '<input type="text" name="nd_nombre" class="sigma-nd-txt" placeholder="Nombre (ej. Potencia)" />' +
                '<input type="text" name="nd_valor" class="sigma-nd-txt" placeholder="Valor" />' +
                '<select name="nd_unidad" class="sigma-nd-sel">' + ND_UNIT_OPTIONS + '</select>' +
                '<a href="javascript:void(0)" onclick="this.closest(\'.nd-row\').remove()" class="sigma-nd-quitar">✕</a>';
            cont.appendChild(row);
            var inp = row.querySelector('input[name="nd_nombre"]');
            if (inp) inp.focus();
        }

        // Quita un dato ya guardado: vacía su valor (al Guardar se elimina del activo)
        // y oculta la fila para dar feedback. El campo del tipo se conserva.
        function ndQuitarDato(a) {
            var field = a.closest('.sigma-nd-fila');
            if (!field) return;
            var txt = field.querySelector('input[type="text"]');
            var sel = field.querySelector('select');
            if (txt) txt.value = '';
            if (sel) sel.selectedIndex = 0;
            field.style.display = 'none';
        }
    </script>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <asp:Panel ID="pnlSecciones" runat="server">

    <%-- ASISTENTE DE TRES PASOS (revisión del cliente, 04-10-2026). La ficha
         entera de una vez era una pared de campos; ahora se llena por partes:
         que es y donde esta, sus datos tecnicos y sus componentes. Lo
         obligatorio esta todo en el paso 1, asi que se puede guardar ahi
         mismo. Es el mismo control en el modal de alta y en la pestaña Ficha. --%>
    <asp:HiddenField ID="hdnPaso" runat="server" Value="1" />
    <nav class="fp-pasos" aria-label="Pasos de la ficha">
        <button type="button" class="fp-paso" data-ir="1" onclick="fpIr(1)"><span class="fp-n">1</span><span><b>Qué es y dónde está</b><small>Nombre, tipo, foto y ubicación</small></span></button>
        <button type="button" class="fp-paso" data-ir="2" onclick="fpIr(2)"><span class="fp-n">2</span><span><b>Datos técnicos</b><small>Serie, marca, medidas y documentos</small></span></button>
        <button type="button" class="fp-paso" data-ir="3" onclick="fpIr(3)"><span class="fp-n">3</span><span><b>Componentes</b><small>Sus partes: motor, rodamientos…</small></span></button>
    </nav>

    <div class="sg-paso fp-paso-1" data-paso="1">
    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion es-identificacion">
        <div class="titulo"><i class="mdi mdi-cog-outline"></i>Identificación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini es-id">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Código</label>
                <%-- El prefijo lo pone el sistema y no se puede tocar; el resto
                     lo escribe quien crea el registro. Van juntos en una sola
                     caja para que se lea como UN codigo y no como dos campos. --%>
                <div class="sg-codigo">
                    <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                    <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" UpperCase="true" ReadOnly="true" />
                </div>
                <span class="sigma-modal-ayuda">El prefijo lo pone el sistema; escriba usted el resto (por ejemplo <em>CALDERAS</em>). Si lo deja vacío, se numera solo.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Nombre <span class="req">*</span></label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Tipo <span class="req">*</span></label>
                <%-- Texto libre (bloque 342): si el tipo no existe, se escribe y se
                     crea al guardar. Ya no hay que ir al menu de configuracion. --%>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                    OnSelectedIndexChanged="cboTipo_SelectedIndexChanged" Filter="Contains" Width="100%"
                    AllowCustomText="true" EmptyMessage="Elija o escriba uno nuevo" />
                <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                    ValidateEmptyText="true" ClientValidationFunction="validaComboTexto" ValidationGroup="Activo" />
                <span class="sigma-modal-ayuda es-clave">¿No está? Escríbalo y se crea al guardar.</span>
            </div>
            <div class="sigma-modal-field is-medio is-cuarto">
                <label>Modelo</label>
                <rad:RadComboBox2 ID="cboModelo" runat="server" AutoPostBack="true"
                    OnSelectedIndexChanged="cboModelo_SelectedIndexChanged" Filter="Contains" Width="100%"
                    AllowCustomText="true" EmptyMessage="Elija o escriba uno nuevo" />
                <span class="sigma-modal-ayuda">Opcional. Muestra los de ese tipo y fabricante. ¿No está? Escríbalo: se crea al guardar.</span>
            </div>
            <div class="sigma-modal-field is-chico is-cuarto">
                <label>Estado <span class="req">*</span></label>
                <rad:RadComboBox2 ID="cboEstado" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvEstado" runat="server" ControlToValidate="cboEstado"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico is-cuarto">
                <label>Criticidad <span class="req">*</span></label>
                <rad:RadComboBox2 ID="cboCriticidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvCriticidad" runat="server" ControlToValidate="cboCriticidad"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-medio is-cuarto">
                <label>Habilitado <span class="req">*</span></label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
                <span class="sigma-modal-ayuda">Deshabilitar es la baja lógica: el activo conserva su historia.</span>
            </div>
        </div>
    </div>

    <%-- ============ IMAGEN ============ --%>
    <div class="sigma-form-seccion es-imagen">
        <div class="titulo"><i class="mdi mdi-image-outline"></i>Imagen del activo</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Imagen del activo</label>
                <div class="sigma-img-uploader">
                    <%-- El estado vacio dice QUE falta y COMO ponerlo. Un boton
                         solo, sin nada alrededor, no dice que el equipo no
                         tiene foto: parece que la foto no cargo. --%>
                    <asp:Panel ID="pnlSinImagen" runat="server" CssClass="sigma-img-vacio">
                        <i class="mdi mdi-image-off-outline"></i>
                        <strong>Sin imagen</strong>
                        <span>Agrega una imagen del equipo (PNG, JPG) para su identificación.</span>
                    </asp:Panel>
                    <label for="fuImagen" class="sigma-img-btn"><i class="mdi mdi-image-plus-outline"></i> Elegir imagen</label>
                    <asp:FileUpload ID="fuImagen" runat="server" accept="image/*" ClientIDMode="Static" onchange="sigmaPrevImg(this)" style="display:none;" />
                    <span id="sigmaFileName" class="sigma-img-name"></span>
                    <a id="sigmaQuitar" href="javascript:void(0)" onclick="sigmaQuitarSel()" class="sigma-img-quitar" style="display:none;"><i class="mdi mdi-close-circle-outline"></i> Quitar</a>
                </div>
                <span class="sigma-modal-ayuda">Foto o esquema del equipo (JPG/PNG). Se muestra en la ficha e historial.</span>
                <img id="sigmaThumb" class="sigma-img-prev" alt="Vista previa" style="display:none" />

                <%-- Imagen ya guardada (edición): mostrar y permitir quitarla.

                     Iba con estilos en linea y una fila flex: dentro de la
                     ficha, que es una columna angosta, la etiqueta caia en
                     tres lineas al lado de la foto. Ahora es una tarjeta que
                     se apila cuando no hay ancho. --%>
                <asp:Panel ID="pnlImagenActual" runat="server" Visible="false" CssClass="sigma-img-actual">
                    <a id="lnkImagenActual" runat="server" class="sigma-img-actual-foto" target="_blank" rel="noopener" title="Ampliar">
                        <img id="imgActual" runat="server" alt="Imagen actual del equipo" data-ampliar="1" />
                    </a>
                    <label class="sigma-img-actual-quitar">
                        <asp:CheckBox ID="chkQuitarImagen" runat="server" />
                        <span>Quitar la imagen actual al guardar</span>
                    </label>
                </asp:Panel>
            </div>
        </div>
    </div>

    <%-- ============ UBICACIÓN ============ --%>
    <div class="sigma-form-seccion es-ubicacion">
        <div class="titulo"><i class="mdi mdi-map-marker-outline"></i>Ubicación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Planta <span class="req">*</span></label>
                <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvPlanta" runat="server" ControlToValidate="cboPlanta"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Área</label>
                <rad:RadComboBox2 ID="cboArea" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Posición funcional dentro de la planta.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Centro de costo</label>
                <rad:RadComboBox2 ID="cboCentroCosto" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Depende de (máquina principal)</label>
                <rad:RadComboBox2 ID="cboPadre" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda es-clave">
                    <b>¿Esta máquina depende de otra más grande?</b> Elíjala aquí y quedará como su
                    <b>subactivo</b> (ej.: el compresor de una cámara de frío). Vacío = máquina principal.
                </span>
            </div>
        </div>
    </div>

    </div>

    <div class="sg-paso fp-paso-2" data-paso="2">
    <%-- ============ FICHA TÉCNICA ============ --%>
    <div class="sigma-form-seccion es-tecnica">
        <div class="titulo"><i class="mdi mdi-file-document-outline"></i>Ficha técnica</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>N° de serie</label>
                <WebControls:TextBox2 ID="txtSerie" runat="server" MaxLength="100" />
                <span class="sigma-modal-ayuda">La identidad física real de la máquina.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Fabricante</label>
                <rad:RadComboBox2 ID="cboFabricante" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                    OnSelectedIndexChanged="cboFabricante_Changed" OnTextChanged="cboFabricante_Changed" Filter="Contains" Width="100%" MaxLength="200"
                    AllowCustomText="true" EmptyMessage="Elija o escriba uno nuevo" />
                <span class="sigma-modal-ayuda">El mismo catálogo de marcas de los repuestos.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Año fabricación</label>
                <rad:RadComboBox2 ID="cboAnio" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Elija el año de la lista. Vacío indica sin dato.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Puesta en marcha</label>
                <div class="sigma-modal-fecha">
                    <WebControls:Calendar ID="calPuestaMarcha" runat="server" />
                </div>
                <span class="sigma-modal-ayuda">Elija la fecha en el calendario. Vacío indica sin dato.</span>
            </div>
            <div class="sigma-modal-field is-grande">
                <label>Descripción</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
            </div>
        </div>
    </div>

    <%-- ============ DATOS TÉCNICOS (nombre · unidad · valor, propios del activo) ============ --%>
    <asp:Panel ID="pnlDatosTecnicos" runat="server" CssClass="sigma-form-seccion es-datos">
        <div class="titulo"><i class="mdi mdi-tune-variant"></i>Datos técnicos</div>

        <%-- Datos ya definidos (del tipo): editar valor + unidad. --%>
        <div class="sigma-nd-cab"><span>Nombre</span><span>Valor</span><span>Unidad</span><span></span></div>

        <div class="sigma-nd-lista">
            <asp:Repeater ID="rptDatos" runat="server" OnItemDataBound="rptDatos_ItemDataBound">
                <ItemTemplate>
                    <%-- Una fila de tres columnas que calzan con el encabezado:
                         nombre, valor y unidad. Antes era un campo con un flex
                         adentro y se salia de la tarjeta en la columna angosta
                         del centro. --%>
                    <div class="sigma-nd-fila">
                        <label><%# Server.HtmlEncode(Convert.ToString(Eval("ate_nombre"))) %></label>
                        <asp:HiddenField runat="server" ID="hdnAte" Value='<%# Eval("ate_id") %>' />
                        <asp:TextBox runat="server" ID="txtValor" Text='<%# Eval("valor_edit") %>' MaxLength="200" CssClass="sigma-nd-txt" />
                        <asp:DropDownList runat="server" ID="ddlUnidad" CssClass="sigma-nd-sel" />
                        <a href="javascript:void(0)" onclick="ndQuitarDato(this)" title="Quitar este dato" class="sigma-nd-quitar">✕</a>
                    </div>
                </ItemTemplate>
            </asp:Repeater>
        </div>

        <%-- Datos nuevos (se agregan al vuelo; quedan también en Atributos técnicos del tipo). --%>
        <div id="ndContainer"></div>
        <a href="javascript:void(0)" onclick="ndAgregar()" class="sigma-img-btn"
           style="display:inline-flex;align-items:center;gap:7px;margin-top:6px;">
            <i class="mdi mdi-plus"></i> Agregar dato
        </a>
        <span class="sigma-modal-ayuda">Nombre + unidad + valor. Lo que agregues aquí también queda como campo del tipo (Atributos técnicos).</span>
    </asp:Panel>

    <%-- ============ DOCUMENTOS (opcional, varios PDF/archivos) ============ --%>
    <div class="sigma-form-seccion es-documentos">
        <div class="titulo"><i class="mdi mdi-paperclip"></i>Documentos</div>

        <%-- Documentos ya cargados (edición): ver / quitar. --%>
        <asp:Repeater ID="rptArchivos" runat="server" OnItemCommand="rptArchivos_ItemCommand" OnItemDataBound="rptArchivos_ItemDataBound">
            <HeaderTemplate><div class="sigma-doc-lista"></HeaderTemplate>
            <ItemTemplate>
                <div class="sigma-doc">
                    <i class='mdi <%# (bool)Eval("es_imagen") ? "mdi-image-outline" : "mdi-file-document-outline" %>'></i>
                    <span class="nom"><%# Server.HtmlEncode(Convert.ToString(Eval("arc_nombre"))) %></span>
                    <asp:HyperLink runat="server" Target="_blank" CssClass="ver"
                        NavigateUrl='<%# VerUrl((int)Eval("arc_id")) %>'><i class="mdi mdi-open-in-new"></i> Ver</asp:HyperLink>
                    <asp:LinkButton runat="server" CssClass="quitar" CommandName="quitar" CommandArgument='<%# Eval("arc_id") %>'
                        OnClientClick="return confirm('¿Quitar este documento del activo?');"><i class="mdi mdi-close-circle-outline"></i> Quitar</asp:LinkButton>
                </div>
            </ItemTemplate>
            <FooterTemplate></div></FooterTemplate>
        </asp:Repeater>

        <asp:Panel ID="pnlSubirDocs" runat="server" CssClass="sigma-doc-zona">
            <label for="fuDocs" class="sigma-img-btn sigma-doc-btn">
                <i class="mdi mdi-upload"></i> Agregar documentos
            </label>
            <asp:FileUpload ID="fuDocs" runat="server" AllowMultiple="true" ClientIDMode="Static"
                accept=".pdf,image/*" onchange="sigmaDocsNombres(this)" style="display:none;" />
            <span id="sigmaDocsLista" style="display:block;margin-top:6px;font-size:12px;color:#475569;"></span>
            <span class="sigma-modal-ayuda">Opcional. Manuales, planos, certificados… PDF o imágenes; puede subir varios a la vez.</span>
        </asp:Panel>
    </div>

    </div>

    <div class="sg-paso fp-paso-3" data-paso="3">
    <%-- ============ COMPONENTES ============
         Las partes del equipo que se quieren seguir, agregadas aqui mismo.
         Antes habia que guardar, ir al centro y abrir otro modal por cada una. --%>
    <asp:Panel ID="pnlComponentes" runat="server" CssClass="sigma-form-seccion es-componentes">
        <div class="titulo"><i class="mdi mdi-puzzle-outline"></i>Componentes</div>
        <p class="sigma-modal-ayuda es-clave" style="margin:0 0 10px">
            Un <b>componente</b> es una <b>parte de esta máquina</b> que quiere seguir por separado: el motor, un rodamiento,
            una válvula. No existe fuera de ella. Si la parte tiene número de serie y se saca a reparar aparte, mejor
            créela como <b>subactivo</b>.
        </p>
        <asp:Literal ID="litComponentes" runat="server" />
        <div class="sigma-co-cab" id="coCab" style="display:none"><span>Nombre</span><span>Qué es</span><span>Dónde va</span><span></span></div>
        <datalist id="coTiposLista"><%= OpcionesComponenteTipo() %></datalist>
        <div id="coContainer"></div>
        <a href="javascript:void(0)" onclick="coAgregar()" class="sigma-img-btn" style="display:inline-flex;margin-top:6px">
            <i class="mdi mdi-plus"></i> Agregar componente</a>
    </asp:Panel>

    </div>

    <div class="fp-nav">
        <button type="button" class="fp-btn" id="fpBtnAnterior" onclick="fpIr(fpActual() - 1)"><i class="mdi mdi-arrow-left"></i>Anterior</button>
        <span class="fp-donde" id="fpDonde"></span>
        <button type="button" class="fp-btn es-sig" id="fpBtnSiguiente" onclick="fpSiguiente()">Siguiente<i class="mdi mdi-arrow-right"></i></button>
    </div>

    </asp:Panel>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <%-- Las acciones cambian de forma segun donde viva el formulario: en el
         modal van al pie del contenido; en el centro van en una barra fija,
         porque la ficha es larga y el boton no puede quedar a dos pantallas
         de scroll del campo que se acaba de tocar. --%>
    <asp:Panel ID="pnlAccionesModal" runat="server" CssClass="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Activo" OnClientClick="sigmaGuardando();" />
    </asp:Panel>

    <asp:Panel ID="pnlAccionesCentro" runat="server" Visible="false" CssClass="sg-a3-ficha-pie">
        <div class="sg-a3-ficha-pie-info">
            <asp:Literal ID="litAuditoriaPie" runat="server" />
        </div>
        <span class="sg-a3-ficha-sucio" id="sgA3Sucio"><i class="mdi mdi-circle-medium"></i>Cambios sin guardar</span>
        <WebControls:PushButton ID="btnCancelar" runat="server" Text="Cancelar" CssClass="ButtonCerrar" OnClick="btnCancelar_Click" CausesValidation="false" />
        <WebControls:PushButton ID="btnGuardarCentro" runat="server" Text="Guardar cambios" OnClick="btnGuardar_Click" ValidationGroup="Activo" OnClientClick="sigmaGuardando();" />
    </asp:Panel>

    <%-- Velo de guardado: cubre la ficha para que se note que está trabajando
         y no se pueda volver a apretar Guardar mientras sube la imagen. --%>
    <div id="sigmaGuardandoOv" style="display:none;position:fixed;inset:0;z-index:99999;background:rgba(255,255,255,.78);align-items:center;justify-content:center;">
        <div style="display:flex;flex-direction:column;align-items:center;gap:12px;text-align:center;">
            <div style="width:44px;height:44px;border:4px solid #e5e7eb;border-top-color:#6C5CFF;border-radius:50%;animation:sigmaSpin .8s linear infinite;"></div>
            <div style="font-size:14px;font-weight:700;color:#334155;">Guardando activo…</div>
            <div style="font-size:12px;color:#6b7280;">Subiendo la imagen, no cierre esta ventana.</div>
        </div>
    </div>
    <style>@keyframes sigmaSpin{to{transform:rotate(360deg)}}</style>

        </ContentTemplate>
    </asp:UpdatePanel>
