<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Activo.aspx.cs" Inherits="View_Activos_Activos_Activo" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <style type="text/css">
        /* Cargador de imagen propio: botón estilizado + nombre + quitar. El
           input file real va oculto; el label lo dispara. */
        .sigma-img-uploader { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
        .sigma-img-btn {
            display: inline-flex; align-items: center; gap: 7px;
            background: #6C5CFF; color: #fff; border-radius: 9px;
            padding: 9px 16px; font-size: 13px; font-weight: 600; cursor: pointer;
            transition: filter .15s ease; margin: 0;
        }
        .sigma-img-btn:hover { filter: brightness(1.07); }
        .sigma-img-btn i { font-size: 17px; }
        .sigma-img-name { font-size: 12.5px; color: #475569; word-break: break-all; }
        .sigma-img-quitar { font-size: 12px; color: #b91c1c; font-weight: 600; text-decoration: none; display: inline-flex; align-items: center; gap: 4px; }
        .sigma-doc-lista { display: grid; gap: 8px; margin-bottom: 10px; }
        .sigma-doc { display: flex; align-items: center; gap: 10px; padding: 9px 12px; border: 1px solid #e5e7eb; border-radius: 10px; font-size: 13px; color: #334155; }
        .sigma-doc > i { font-size: 18px; color: #6C5CFF; }
        .sigma-doc .nom { flex: 1 1 auto; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .sigma-doc .ver { color: #6C5CFF !important; font-weight: 600; text-decoration: none; }
        .sigma-doc .quitar { color: #b91c1c !important; font-weight: 600; text-decoration: none; }
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
                if (typeof Page_IsValid !== 'undefined' && Page_IsValid === false) return;
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
        // La invoca el modal de modelo al cerrarse: recarga el combo de modelos.
        function refresh() { __doPostBack('', ''); }

        // Opciones de unidad (para las filas nuevas), armadas en el servidor.
        var ND_UNIT_OPTIONS = '<option value="">— sin unidad</option><%= BuildUnidadOptions() %>';
        // Agrega una fila nueva de dato técnico (nombre + unidad + valor).
        function ndAgregar() {
            var cont = document.getElementById('ndContainer');
            if (!cont) return;
            var row = document.createElement('div');
            row.className = 'nd-row';
            row.style.cssText = 'display:flex;gap:6px;align-items:center;margin-top:8px;';
            row.innerHTML =
                '<input type="text" name="nd_nombre" placeholder="Nombre (ej. Potencia)" style="flex:1;padding:9px 11px;border:1px solid #e5e7eb;border-radius:9px;font-size:13px;" />' +
                '<select name="nd_unidad" style="width:150px;padding:9px 8px;border:1px solid #e5e7eb;border-radius:9px;font-size:13px;background:#fff;">' + ND_UNIT_OPTIONS + '</select>' +
                '<input type="text" name="nd_valor" placeholder="Valor" style="width:120px;padding:9px 11px;border:1px solid #e5e7eb;border-radius:9px;font-size:13px;" />' +
                '<a href="javascript:void(0)" onclick="this.closest(\'.nd-row\').remove()" style="color:#b91c1c;font-weight:700;text-decoration:none;padding:0 6px;">✕</a>';
            cont.appendChild(row);
            var inp = row.querySelector('input[name="nd_nombre"]');
            if (inp) inp.focus();
        }

        // Quita un dato ya guardado: vacía su valor (al Guardar se elimina del activo)
        // y oculta la fila para dar feedback. El campo del tipo se conserva.
        function ndQuitarDato(a) {
            var field = a.closest('.sigma-modal-field');
            if (!field) return;
            var txt = field.querySelector('input[type="text"]');
            var sel = field.querySelector('select');
            if (txt) txt.value = '';
            if (sel) sel.selectedIndex = 0;
            field.style.display = 'none';
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <h1 class="sigma-modal-title">Activo</h1>

    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-cog-outline"></i>Identificación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
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
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Tipo(*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                    OnSelectedIndexChanged="cboTipo_SelectedIndexChanged" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Modelo</label>
                <rad:RadComboBox2 ID="cboModelo" runat="server" AutoPostBack="true"
                    OnSelectedIndexChanged="cboModelo_SelectedIndexChanged" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">
                    Elija primero el tipo. ¿No está el modelo?
                    <a href="javascript:void(0)" onclick="nuevoModelo()" style="color:#6C5CFF;font-weight:600;">+ Nuevo modelo</a>
                </span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Estado(*)</label>
                <rad:RadComboBox2 ID="cboEstado" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvEstado" runat="server" ControlToValidate="cboEstado"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Criticidad(*)</label>
                <rad:RadComboBox2 ID="cboCriticidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvCriticidad" runat="server" ControlToValidate="cboCriticidad"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Habilitado(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
                <span class="sigma-modal-ayuda">Deshabilitar es la baja lógica: el activo conserva su historia.</span>
            </div>
        </div>
    </div>

    <%-- ============ UBICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-map-marker-outline"></i>Ubicación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Planta(*)</label>
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
                <label>Activo superior</label>
                <rad:RadComboBox2 ID="cboPadre" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Vacío indica que es un activo de primer nivel. Úselo para un subactivo.</span>
            </div>
        </div>
    </div>

    <%-- ============ FICHA TÉCNICA ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-file-document-outline"></i>Ficha técnica</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>N° de serie</label>
                <WebControls:TextBox2 ID="txtSerie" runat="server" MaxLength="100" />
                <span class="sigma-modal-ayuda">La identidad física real de la máquina.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Fabricante</label>
                <WebControls:TextBox2 ID="txtFabricante" runat="server" MaxLength="200" />
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
            <div class="sigma-modal-field is-medio">
                <label>Imagen del activo</label>
                <div class="sigma-img-uploader">
                    <label for="fuImagen" class="sigma-img-btn"><i class="mdi mdi-image-plus-outline"></i> Elegir imagen</label>
                    <asp:FileUpload ID="fuImagen" runat="server" accept="image/*" ClientIDMode="Static" onchange="sigmaPrevImg(this)" style="display:none;" />
                    <span id="sigmaFileName" class="sigma-img-name"></span>
                    <a id="sigmaQuitar" href="javascript:void(0)" onclick="sigmaQuitarSel()" class="sigma-img-quitar" style="display:none;"><i class="mdi mdi-close-circle-outline"></i> Quitar</a>
                </div>
                <span class="sigma-modal-ayuda">Foto o esquema del equipo (JPG/PNG). Se muestra en la ficha e historial.</span>
                <img id="sigmaThumb" alt="Vista previa" style="display:none;width:auto;height:auto;max-height:150px;max-width:260px;object-fit:contain;margin-top:8px;border-radius:8px;border:1px solid #e5e7eb;" />

                <%-- Imagen ya guardada (edición): mostrar y permitir quitarla. --%>
                <asp:Panel ID="pnlImagenActual" runat="server" Visible="false" style="margin-top:8px;">
                    <div style="display:flex;align-items:center;gap:10px;">
                        <img id="imgActual" runat="server" alt="Imagen actual" style="width:auto;height:auto;max-height:110px;max-width:200px;object-fit:contain;border-radius:8px;border:1px solid #e5e7eb;" />
                        <label style="font-size:12px;color:#b91c1c;font-weight:600;display:inline-flex;align-items:center;gap:5px;cursor:pointer;">
                            <asp:CheckBox ID="chkQuitarImagen" runat="server" /> Quitar la imagen actual al guardar
                        </label>
                    </div>
                </asp:Panel>
            </div>
        </div>
    </div>

    <%-- ============ DATOS TÉCNICOS (nombre · unidad · valor, propios del activo) ============ --%>
    <asp:Panel ID="pnlDatosTecnicos" runat="server" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-tune-variant"></i>Datos técnicos</div>

        <%-- Datos ya definidos (del tipo): editar valor + unidad. --%>
        <div class="sigma-modal-grid">
            <asp:Repeater ID="rptDatos" runat="server" OnItemDataBound="rptDatos_ItemDataBound">
                <ItemTemplate>
                    <div class="sigma-modal-field is-grande">
                        <label><%# Server.HtmlEncode(Convert.ToString(Eval("ate_nombre"))) %></label>
                        <asp:HiddenField runat="server" ID="hdnAte" Value='<%# Eval("ate_id") %>' />
                        <div style="display:flex;gap:6px;align-items:center;">
                            <asp:TextBox runat="server" ID="txtValor" Text='<%# Eval("valor_edit") %>' MaxLength="200"
                                style="flex:1;padding:9px 11px;border:1px solid #e5e7eb;border-radius:9px;font-size:13px;" />
                            <asp:DropDownList runat="server" ID="ddlUnidad"
                                style="width:150px;padding:9px 8px;border:1px solid #e5e7eb;border-radius:9px;font-size:13px;background:#fff;" />
                            <a href="javascript:void(0)" onclick="ndQuitarDato(this)" title="Quitar este dato"
                               style="color:#b91c1c;font-weight:700;text-decoration:none;padding:0 6px;">✕</a>
                        </div>
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
    <div class="sigma-form-seccion">
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

        <asp:Panel ID="pnlSubirDocs" runat="server">
            <label for="fuDocs" class="sigma-img-btn" style="display:inline-flex;align-items:center;gap:7px;margin-top:6px;">
                <i class="mdi mdi-upload"></i> Agregar documentos
            </label>
            <asp:FileUpload ID="fuDocs" runat="server" AllowMultiple="true" ClientIDMode="Static"
                accept=".pdf,image/*" onchange="sigmaDocsNombres(this)" style="display:none;" />
            <span id="sigmaDocsLista" style="display:block;margin-top:6px;font-size:12px;color:#475569;"></span>
            <span class="sigma-modal-ayuda">Opcional. Manuales, planos, certificados… PDF o imágenes; puede subir varios a la vez.</span>
        </asp:Panel>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Activo" OnClientClick="sigmaGuardando();" />
    </div>

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
</div>
</asp:Content>
