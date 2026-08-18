<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/Master/Simple.master" CodeFile="CheckListDetalleObjetos.aspx.cs" Inherits="View_Comun_Clientes_Checklist_CheckListDetalleObjetos" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/Checklist/ChecklistDetalleObjetos.ascx" TagPrefix="wuc" TagName="ChecklistDetalleObjetos" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript" language="javascript">
        //Cierra el RadWindow"
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

        function abrirDetalleObjeto(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("CheckListDetalleLista.aspx") %>?query=' + query);
            oWin.show();
            bloqueaScroll(false);

        }


    </script>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="cphBody" runat="server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="1000" Height="380" />
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
             <wuc:ChecklistDetalleObjetos ID="wucChecklistDetalleObjetos" runat="server" />
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
