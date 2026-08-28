<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Menu.aspx.cs" Inherits="View_Root_Mantenedores_Menu" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow)
                oWindow = window.radWindow;
            else if (window.frameElement.radWindow)
                oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="SubTitulos">Menú</div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>ID</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <asp:Label ID="lblId" runat="server"></asp:Label>
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Nombre(*)</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="100" />
                    <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Menu" />
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Descripción</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <WebControls:TextBox2 ID="txtDescripcion" runat="server" MaxLength="200" />
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Depende de</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <rad:RadComboBox2 ID="cboPadre" runat="server" Width="60%" />
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Nivel(*)</label></div>
                <div class="col-lg-4 col-md-4 col-xs-12">
                    <WebControls:TextBox2 ID="txtNivel" runat="server" MaxLength="2" />
                </div>
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Orden(*)</label></div>
                <div class="col-lg-4 col-md-4 col-xs-12">
                    <WebControls:TextBox2 ID="txtOrden" runat="server" MaxLength="3" />
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Página</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <WebControls:TextBox2 ID="txtLink" runat="server" MaxLength="200" />
                    <span style="font-size: 11px; color: #777;">
                        Ruta tal cual, por ejemplo ~/View/Sistema/Mantenedores/Paises/Paises.aspx.
                        Dejar en # si es una carpeta que solo agrupa otros menús.
                    </span>
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Permiso</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <rad:RadComboBox2 ID="cboPermiso" runat="server" Width="60%" />
                    <span style="font-size: 11px; color: #777;">
                        Obligatorio cuando hay página. Es lo que se exige al abrirla.
                    </span>
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Ícono</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <WebControls:TextBox2 ID="txtIcon" runat="server" MaxLength="100" />
                    <span style="font-size: 11px; color: #777;">Clase de Font Awesome, por ejemplo fas fa-users.</span>
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Visible(*)</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Visible" Checked="true" ValidationGroup="Menu" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Visible" ValidationGroup="Menu" />
                    <span style="font-size: 11px; color: #777;">
                        NO es una página que existe pero no aparece en el menú lateral,
                        como las ventanas de detalle.
                    </span>
                </div>
            </div>

            <div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Menu" />
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
