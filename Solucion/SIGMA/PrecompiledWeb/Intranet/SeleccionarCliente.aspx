<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="SeleccionarCliente, App_Web_niiluyu0" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="sigma-modal">

                <h1 class="sigma-modal-title">Seleccione el cliente</h1>

                <div class="sigma-modal-note">
                    Usted trabaja con más de una empresa. Elija con cuál va a trabajar en esta sesión.
                    Puede cambiar de cliente cuando quiera desde el encabezado.
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-ancho">
                        <label>Cliente(*)</label>
                        <rad:RadComboBox2 ID="cboCliente" runat="server" Filter="Contains" Width="80%" />
                        <asp:CustomValidator ID="cvCliente" runat="server" ControlToValidate="cboCliente"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Cliente" />
                    </div>
                </div>

                <asp:Panel ID="pnlError" runat="server" Visible="false" CssClass="sigma-modal-note is-alerta">
                    <asp:Literal ID="litError" runat="server" />
                </asp:Panel>

                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnContinuar" runat="server" Text="Continuar"
                        OnClick="btnContinuar_Click" ValidationGroup="Cliente" />
                </div>

            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
