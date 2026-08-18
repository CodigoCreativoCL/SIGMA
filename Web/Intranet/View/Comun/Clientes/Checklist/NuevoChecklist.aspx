<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="NuevoChecklist.aspx.cs" Inherits="View_Comun_Clientes_Checklist_NuevoChecklist" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/Checklist/ChecklistDetalle.ascx" TagPrefix="wuc" TagName="ChecklistDetalle" %>


<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">

    <script>
        function abrirBusqueda(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Comun/Clientes/Checklist/ChecklistDetallesItem.aspx") %>?query=' + query);
            oWin.show();
            bloqueaScroll(false);

            oWin.add_close(function () {
                __doPostBack('', '');
            });
        }


        function abrirDetalleObjeto(query) {
            var owin = $find("<%=rwiDetalle.ClientID %>");
            owin.setUrl('<%=ResolveUrl("~/View/Comun/Clientes/Checklist/CheckListDetalleObjetos.aspx") %>?query=' + query);
            owin.show();
            bloqueaScroll(false);

            oWin.add_close(function () {
                __doPostBack('', '');
            });
        }


    </script>
</asp:Content>



<asp:Content ID="Content1" ContentPlaceHolderID="cphBody" runat="Server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="1000" Height="380" />
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <wuc:ChecklistDetalle ID="wucChecklistDetalle" runat="server" />
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
