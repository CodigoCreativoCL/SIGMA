<%@ Control Language="C#" AutoEventWireup="true" CodeFile="ConfiguracionApp.ascx.cs" Inherits="View_Comun_Controls_Cliente_Instalaciones_ConfiguracionApp" %>


<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <div class="DescripcionTitulo">Funcionalidades de la app dentro de cada área</div>
        <asp:Repeater ID="rtpHtml" runat="server" OnItemDataBound="rtpHtml_ItemDataBound">
            <ItemTemplate>
                <div class="row col-lg-12 col-md-12 col-sm-12 col-12">
                    <div class="row col-lg-12 col-md-12 col-sm-12 col-12">
                        <div class="col-lg-4 col-md-4 col-sm-12 col-12">
                            <asp:Label ID="lblnombreapp" runat="server" />
                            <asp:HiddenField ID="hdfId" runat="server" />
                        </div>
                        <div class="col-lg-8 col-md-8 col-sm-12 col-12">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                        </div>
                    </div>
                </div>
            </ItemTemplate>
        </asp:Repeater>
        <div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Cliente" />
        </div>
    </ContentTemplate>
</asp:UpdatePanel>
<br />
