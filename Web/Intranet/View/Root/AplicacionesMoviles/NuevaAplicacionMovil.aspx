<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="NuevaAplicacionMovil.aspx.cs" Inherits="View_Root_AplicacionesMoviles_NuevaAplicacionMovil" %>

<asp:Content ID="cntHeader" ContentPlaceHolderID="cphHeder" runat="server">
    <style>
        .logo-preview {
            width: 72px;
            height: 72px;
            border-radius: 12px;
            object-fit: cover;
            display: none;
            margin-top: 6px;
        }

            .logo-preview.visible {
                display: block;
            }

        .badge-preview {
            height: 40px;
            display: none;
            margin-top: 6px;
        }

            .badge-preview.visible {
                display: block;
            }

        .field-hint {
            font-size: .72rem;
            color: #94a3b8;
            margin-top: 2px;
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
            if (w && w.BrowserWindow && w.BrowserWindow.refreshApps) w.BrowserWindow.refreshApps();
            if (w) w.close();
        }
    </script>
</asp:Content>

<asp:Content ID="cntBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="SubTitulos">Aplicación Móvil</div>

            <%-- ID (solo edición) --%>
            <div class="row col-lg-12" id="divID" runat="server" visible="false">
                <div class="col-lg-3">
                    <label>ID</label></div>
                <div class="col-lg-9">
                    <asp:Label ID="lblID" runat="server" /></div>
            </div>

            <%-- Nombre --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Nombre (*)</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                    <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl"
                        ValidationGroup="App" />
                </div>
            </div>

            <%-- Descripción --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Descripción</label></div>
                <div class="col-lg-9 col-xs-12">
                    <asp:TextBox ID="txtDescripcion" runat="server" TextMode="MultiLine" Rows="3"
                        CssClass="form-control" MaxLength="1000" />
                </div>
            </div>

            <%-- Paquete Android --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Paquete Android</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtPaqueteAndroid" runat="server" MaxLength="500" />
                    <div class="field-hint">Ej: com.facilityges.controlgate</div>
                </div>
            </div>

            <%-- Paquete iOS --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Paquete iOS</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtPaqueteIos" runat="server" MaxLength="500" />
                    <div class="field-hint">Ej: com.facilityges.controlgate</div>
                </div>
            </div>

            <%-- URL Store Android --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>URL Google Play</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtUrlAndroid" runat="server" MaxLength="1000" />
                </div>
            </div>

            <%-- URL Store iOS --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>URL App Store</label></div>
                <div class="col-lg-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtUrlIos" runat="server" MaxLength="1000" />
                </div>
            </div>

            <%-- Logo --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Logo</label></div>
                <div class="col-lg-9 col-xs-12">
                    <asp:FileUpload ID="fldLogo" runat="server" />
                    <div class="field-hint">Imagen cuadrada recomendada (PNG/JPG)</div>
                    <asp:Label ID="lblRutaLogo" runat="server" Visible="false" CssClass="field-hint" />
                    <br />
                    <asp:Image ID="imgLogoActual" runat="server" CssClass="logo-preview" />
                </div>
            </div>

            <%-- Badge Android --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Badge Google Play</label></div>
                <div class="col-lg-9 col-xs-12">
                    <asp:FileUpload ID="fldBadgeAndroid" runat="server" />
                    <div class="field-hint">Imagen del distintivo "Disponible en Google Play"</div>
                    <asp:Label ID="lblRutaBadgeAndroid" runat="server" Visible="false" CssClass="field-hint" />
                    <br />
                    <asp:Image ID="imgBadgeAndroidActual" runat="server" CssClass="badge-preview" />
                </div>
            </div>

            <%-- Badge iOS --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Badge App Store</label></div>
                <div class="col-lg-9 col-xs-12">
                    <asp:FileUpload ID="fldBadgeIos" runat="server" />
                    <div class="field-hint">Imagen del distintivo "Disponible en App Store"</div>
                    <asp:Label ID="lblRutaBadgeIos" runat="server" Visible="false" CssClass="field-hint" />
                    <br />
                    <asp:Image ID="imgBadgeIosActual" runat="server" CssClass="badge-preview" />
                </div>
            </div>

            <%-- Activa --%>
            <div class="row col-lg-12 col-xs-12">
                <div class="col-lg-3 col-xs-12">
                    <label>Activa</label></div>
                <div class="col-lg-9 col-xs-12" style="padding-top: 6px;">
                    <asp:CheckBox ID="chkActiva" runat="server" Checked="true" />
                </div>
            </div>

            <div class="col-lg-12 form-col-center mt-1">
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar"
                    OnClick="btnGuardar_Click" ValidationGroup="App" />
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar"
                    CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
