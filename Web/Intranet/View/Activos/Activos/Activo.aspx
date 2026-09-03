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
    </style>
    <script type="text/javascript">
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
                <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" UpperCase="true" ReadOnly="true" />
                <span class="sigma-modal-ayuda">Se genera solo al guardar: <strong>ACT-</strong>más el número del registro.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Tipo(*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
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
