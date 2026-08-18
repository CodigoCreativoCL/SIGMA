<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="NuevaAplicacionMovilVersion.aspx.cs" Inherits="View_Root_AplicacionesMoviles_NuevaAplicacionMovilVersion" %>

<asp:Content ID="cntHeader" ContentPlaceHolderID="cphHeder" runat="server">
    <style>
        .field-hint {
            font-size: .72rem;
            color: #94a3b8;
            margin-top: 2px;
        }

        .file-actual {
            font-size: .72rem;
            color: #64748b;
            margin-top: 3px;
        }

        .edit-badge {
            display: inline-block;
            font-size: .72rem;
            background: #eff6ff;
            color: #1d4ed8;
            border-radius: 4px;
            padding: 2px 8px;
            margin-bottom: 6px;
        }
    </style>
</asp:Content>

<asp:Content ID="cntScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var w = null;
            if (window.radWindow) w = window.radWindow;
            else if (window.frameElement && window.frameElement.radWindow) w = window.frameElement.radWindow;
            return w;
        }
        function closeWindow() {
            var w = getRadWindow();
            if (w && w.BrowserWindow && w.BrowserWindow.refreshVersiones) w.BrowserWindow.refreshVersiones();
            if (w) w.close();
        }

        // Overlay propio para full postback (FileUpload no admite async postback)
        var _timerGuardar = null;

        function mostrarProgresoGuardar() {
            if (typeof Page_ClientValidate === 'function' && !Page_ClientValidate('Ver')) return false;

            var ov = document.getElementById('overlayGuardar');
            if (ov) ov.style.display = 'flex';

            var seg = 0;
            if (_timerGuardar) clearInterval(_timerGuardar);
            _timerGuardar = setInterval(function () {
                seg++;
                var elMin = document.getElementById('ovMin');
                var elSeg = document.getElementById('ovSeg');
                if (elMin) elMin.innerHTML = Math.floor(seg / 60);
                if (elSeg) elSeg.innerHTML = seg % 60;
            }, 1000);

            return true;
        }

        // Visibilidad de campos según plataforma
        function togglePlataforma() {
            var sel = document.getElementById('<%= cboPlataforma.ClientID %>');
            if (!sel) return;
            var plat = sel.value;
            var showAndroid = (plat !== 'IOS');
            var showIos = (plat !== 'ANDROID');
            setVisible('divAndroid', showAndroid);
            setVisible('divIos', showIos);
            setVisible('divMinAndroid', showAndroid);
            setVisible('divMinIos', showIos);
            setVisible('divApk', showAndroid);
            setVisible('divIpa', showIos);
        }
        function setVisible(id, visible) {
            var el = document.getElementById(id);
            if (el) el.style.display = visible ? '' : 'none';
        }
        Sys.Application.add_load(function () { togglePlataforma(); });
    </script>
</asp:Content>

<asp:Content ID="cntBody" ContentPlaceHolderID="cphBody" runat="server">

    <%-- Overlay de carga: se muestra durante el full postback de Guardar.
         Desaparece solo al recargar la página una vez que el servidor responde. --%>
    <div id="overlayGuardar" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%;
         background:rgba(0,0,0,0.55); z-index:99999; justify-content:center; align-items:center;">
        <div style="background:#fff; border-radius:10px; padding:32px 48px; text-align:center;
                    box-shadow:0 4px 24px rgba(0,0,0,.3); min-width:220px;">
            <img src="<%=ResolveUrl("~/Css/AjaxProgress/AjaxProgress.gif") %>" alt="Procesando..." style="border-radius:5px;" />
            <p style="margin-top:14px; margin-bottom:0; font-size:.9rem; color:#374151;">
                Tiempo de carga:&nbsp;<strong id="ovMin">0</strong>&nbsp;min&nbsp;<strong id="ovSeg">0</strong>&nbsp;seg
            </p>
        </div>
    </div>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="SubTitulos">Versión de Aplicación</div>

            <%-- Modo edición: aviso --%>
            <div id="divModoEdicion" runat="server" visible="false" class="col-lg-12" style="margin-bottom: 8px;">
                <span class="edit-badge">
                    <i class="fas fa-info-circle"></i>
                    Modo edición &mdash; solo se actualizarán los archivos APK / IPA
                    </span>
            </div>

            <%-- ID (solo edición) --%>
            <div class="row col-lg-12" id="divID" runat="server" visible="false">
                <div class="col-lg-3">
                    <label>ID</label></div>
                <div class="col-lg-9">
                    <asp:Label ID="lblID" runat="server" /></div>
            </div>

            <%-- Versión --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Versión (*)</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtVersion" runat="server" MaxLength="50" />
                    <div class="field-hint">Ej: 1.0.0 &mdash; 2.3.1</div>
                    <asp:CustomValidator ID="cvVersion" runat="server" ControlToValidate="txtVersion"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl"
                        ValidationGroup="Ver" />
                </div>
            </div>

            <%-- Plataforma --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Plataforma (*)</label></div>
                <div class="col-lg-9 col-xs-12">
                    <asp:DropDownList ID="cboPlataforma" runat="server" CssClass="form-control"
                        onchange="togglePlataforma();">
                        <asp:ListItem Value="AMBAS" Text="Ambas (Android + iOS)" Selected="True" />
                        <asp:ListItem Value="ANDROID" Text="Android" />
                        <asp:ListItem Value="IOS" Text="iOS" />
                    </asp:DropDownList>
                </div>
            </div>

            <%-- Código Android --%>
            <div id="divAndroid" class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Código Android</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtCodigoAndroid" runat="server" MaxLength="10" />
                    <div class="field-hint">versionCode del build (solo números, siempre creciente)</div>
                </div>
            </div>

            <%-- Build iOS --%>
            <div id="divIos" class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Build iOS</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtBuildIos" runat="server" MaxLength="50" />
                    <div class="field-hint">CFBundleVersion del build</div>
                </div>
            </div>

            <%-- OS mínimo Android --%>
            <div id="divMinAndroid" class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>OS mínimo Android</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtMinAndroid" runat="server" MaxLength="20" />
                    <div class="field-hint">Ej: 8.0, 10, 12</div>
                </div>
            </div>

            <%-- OS mínimo iOS --%>
            <div id="divMinIos" class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>OS mínimo iOS</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtMinIos" runat="server" MaxLength="20" />
                    <div class="field-hint">Ej: 14.0, 15, 16.4</div>
                </div>
            </div>

            <%-- APK --%>
            <div id="divApk" class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Archivo APK</label></div>
                <div class="col-lg-9 col-xs-12">
                    <asp:FileUpload ID="fldApk" runat="server" />
                    <div class="field-hint">Archivo .apk &mdash; máx. 200 MB</div>
                    <asp:Label ID="lblRutaApk" runat="server" Visible="false" CssClass="file-actual" />
                </div>
            </div>

            <%-- IPA --%>
            <div id="divIpa" class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Archivo IPA</label></div>
                <div class="col-lg-9 col-xs-12">
                    <asp:FileUpload ID="fldIpa" runat="server" />
                    <div class="field-hint">Archivo .ipa &mdash; máx. 200 MB</div>
                    <asp:Label ID="lblRutaIpa" runat="server" Visible="false" CssClass="file-actual" />
                </div>
            </div>

            <%-- Notas / Changelog --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Notas / Changelog</label></div>
                <div class="col-lg-9 col-xs-12">
                    <asp:TextBox ID="txtNotas" runat="server" TextMode="MultiLine" Rows="3"
                        CssClass="form-control" MaxLength="2000" />
                    <div class="field-hint">Descripción de cambios de esta versión</div>
                </div>
            </div>

            <%-- Obligatoria --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Actualización obligatoria</label></div>
                <div class="col-lg-9 col-xs-12" style="padding-top: 6px;">
                    <asp:CheckBox ID="chkObligatoria" runat="server" />
                    <span class="field-hint">Fuerza la actualización en el dispositivo</span>
                </div>
            </div>

            <div class="col-lg-12 form-col-center mt-1">
                <asp:LinkButton ID="btnGuardar" runat="server" Text="Guardar" CssClass="Button"
                    OnClick="btnGuardar_Click" ValidationGroup="Ver"
                    OnClientClick="return mostrarProgresoGuardar();" />
                <asp:LinkButton ID="btnCerrar" runat="server" Text="Cerrar"
                    CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
