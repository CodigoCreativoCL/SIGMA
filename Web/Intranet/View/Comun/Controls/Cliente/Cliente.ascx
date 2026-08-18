<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Cliente.ascx.cs" Inherits="View_Comun_Controls_Cliente_Cliente" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Identidad.ascx" TagPrefix="wuc" TagName="Identidad" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Usuarios.ascx" TagPrefix="wuc" TagName="Usuarios" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Instalaciones.ascx" TagPrefix="wuc" TagName="Instalaciones" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Checklist/Checklist.ascx" TagPrefix="wuc" TagName="Checklist" %>

<script type="text/javascript">
    function closeWindow() {
        window.location = ('<%=ResolveUrl(URLVolverCliente) %>');
    }
</script>

<style>
    .cliente-layout {
        display: flex;
        align-items: flex-start;
        gap: 4px;
        overflow: hidden;
    }

    .cliente-tab-sidebar {
        width: 120px;
        flex-shrink: 0;
        position: sticky;
        left: 0;
        z-index: 1;
        background: #fff;
    }

    #ragTab .rtsLink {
        padding: 7px 10px !important;
        font-size: 13px;
    }

    .cliente-tab-body {
        flex: 1;
        min-width: 0;
        padding-left: 10px;
        overflow-x: auto;
    }

    .cliente-tab-footer {
        margin-top: 10px;
        text-align: center;
    }
</style>

<div class="cliente-layout">

    <div class="cliente-tab-sidebar">
        <rad:RadTabStrip2 ID="ragTab" runat="server" MultiPageID="MultiPage"
            Orientation="VerticalLeft" Skin="Bootstrap" RenderMode="Lightweight" SelectedIndex="0">
            <Tabs>
                <rad:RadTab Text="Identidad" runat="server" PageViewID="rtvIdentidad" />
                <rad:RadTab Text="Usuarios" runat="server" PageViewID="rtvUsuarios" />
                <rad:RadTab Text="Checklist" runat="server" PageViewID="rtvChecklist" />
                <rad:RadTab Text="Instalaciones" runat="server" PageViewID="rtvInstalaciones" />
            </Tabs>
        </rad:RadTabStrip2>
    </div>

    <div class="cliente-tab-body">
        <rad:RadMultiPage ID="MultiPage" runat="server" SelectedIndex="0">
            <rad:RadPageView ID="rtvIdentidad" runat="server">
                <wuc:Identidad runat="server" ID="wucIdentidad" />
            </rad:RadPageView>
            <rad:RadPageView ID="rtvUsuarios" runat="server">
                <div class="SubTitulos">Usuarios</div>
                <wuc:Usuarios runat="server" ID="wucUsuarios" />
            </rad:RadPageView>
            <rad:RadPageView ID="rtvChecklist" runat="server">
                <wuc:Checklist runat="server" ID="wucChecklist" />
            </rad:RadPageView>
            <rad:RadPageView ID="rtvInstalaciones" runat="server">
                <wuc:Instalaciones runat="server" ID="wucInstalaciones" />
            </rad:RadPageView>
        </rad:RadMultiPage>

        <div class="cliente-tab-footer">
            <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar"
                CssClass="ButtonCerrar" Width="102px"
                OnClientClick="closeWindow(); return false;" />
        </div>
    </div>

</div>
