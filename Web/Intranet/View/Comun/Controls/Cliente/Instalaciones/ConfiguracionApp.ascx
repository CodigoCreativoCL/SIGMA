<%@ Control Language="C#" AutoEventWireup="true" CodeFile="ConfiguracionApp.ascx.cs" Inherits="View_Comun_Controls_Cliente_Instalaciones_ConfiguracionApp" %>


<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <div class="sigma-modal-note">
            Qué puede hacer la app móvil en esta planta. Solo aparece lo que incluye
            el plan contratado; apague aquí lo que en esta planta no corresponda
            —por ejemplo, fotos donde la cámara está prohibida—.
        </div>

        <%-- El plan no incluye ninguna funcionalidad de app. Se dice, en vez
             de dejar un recuadro vacío que parece un error de carga. --%>
        <asp:Panel ID="pnlSinFuncionalidades" runat="server" Visible="false" CssClass="sigma-modal-note is-neutro">
            El plan contratado no incluye funcionalidades de app móvil.
            Cámbielo desde Comercial para habilitarlas.
        </asp:Panel>

        <asp:Repeater ID="rtpHtml" runat="server" OnItemDataBound="rtpHtml_ItemDataBound">
            <ItemTemplate>
                <asp:Literal ID="litGrupo" runat="server" />
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-ancho">
                        <asp:Label ID="lblnombreapp" runat="server" />
                        <asp:HiddenField ID="hdfId" runat="server" />
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                        </div>
                    </div>
                </div>
            </ItemTemplate>
        </asp:Repeater>

        <div class="sigma-modal-actions">
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Cliente" />
        </div>
    </ContentTemplate>
</asp:UpdatePanel>
<br />
