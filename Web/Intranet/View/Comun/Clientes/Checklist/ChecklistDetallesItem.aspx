<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/Master/Simple.master" CodeFile="ChecklistDetallesItem.aspx.cs" Inherits="View_Comun_Clientes_Checklist_ChecklistDetallesItem" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/Checklist/ChecklistDetalleItem.ascx" TagPrefix="wuc" TagName="ChecklistDetalleItem" %>



<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContenHead" ContentPlaceHolderID="chpScript" runat="server">
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


    </script>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="cphBody" runat="server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="1000" Height="380" />
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <wuc:ChecklistDetalleItem runat="server" ID="wucChecklistDetalleItem" />
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
