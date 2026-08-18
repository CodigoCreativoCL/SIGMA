<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="AplicacionMovilVersiones.aspx.cs" Inherits="View_Root_AplicacionesMoviles_AplicacionMovilVersiones" %>

<asp:Content ID="cntHeader" ContentPlaceHolderID="cphHeder" runat="server">
    <style>
        .distintivo-plantilla {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 10px;
            border-radius: 20px;
            background: #f3f4f6;
            color: #374151;
            font-size: 12px;
            font-weight: 500;
            border: 1px solid #e5e7eb;
            box-shadow: 0 1px 2px rgba(0,0,0,.05);
        }

        .chip-md {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 12px;
            border-radius: 16px;
            font-size: 12px;
            font-weight: 500;
            line-height: 1;
            border: 1px solid transparent;
            white-space: nowrap;
        }

            .chip-md i {
                font-size: 13px;
            }

        .chip-android {
            background: #e8f5e9;
            color: #2e7d32;
        }

        .chip-ios {
            background: #f5f5f5;
            color: #424242;
        }

        .chip-both {
            background: #e3f2fd;
            color: #1565c0;
        }

        .chip-success {
            background: #e8f5e9;
            color: #2e7d32;
        }

        .chip-warning {
            background: #fff8e1;
            color: #f57c00;
        }

        .chip-danger {
            background: #ffebee;
            color: #c62828;
        }

        .chip-info {
            background: #e3f2fd;
            color: #1565c0;
        }

        .chip-muted {
            background: #f5f5f5;
            color: #757575;
        }

        .version-info {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }

        .version-item {
            font-size: 12px;
            color: #475569;
        }

            .version-item b {
                color: #0f172a;
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
        function abrirVersion(query) {
            var oWin = $find("<%= rwiVersion.ClientID %>");
            if (!query) {
                query = $("#<%= hdfQuery.ClientID %>").val();
            }
            oWin.setUrl('<%= ResolveUrl("~/View/Root/AplicacionesMoviles/NuevaAplicacionMovilVersion.aspx") %>?query=' + encodeURIComponent(query));
            oWin.set_title(!query ? 'Nueva Versión' : 'Editar Versión');
            oWin.show();
        }
        function refreshVersiones() {
            __doPostBack('<%= Grid.ClientID %>', '');
        }
    </script>
</asp:Content>

<asp:Content ID="cntBody" ContentPlaceHolderID="cphBody" runat="server">
    <rad:RadWindow2 ID="rwiVersion" runat="server" Title="Versiones" Width="700" Height="580" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="SubTitulos">
                Versiones &mdash;
                <asp:Label ID="lblAppNombre" runat="server" />
            </div>
            <asp:HiddenField runat="server" ID="hdfQuery" />

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound" OnItemCreated="Grid_OnItemCreated">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="apv_id">
                    <CommandItemTemplate>
                        <div class="contenedor-botones">
                            <asp:LinkButton ID="lnkNueva" runat="server" CssClass="icono_guardar" Text="Nueva Versión"
                                OnClick="lnkNueva_Click" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" CssClass="icono_eliminar" Text="Eliminar"
                                OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Eliminar la(s) versión(es) seleccionada(s)?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>

            <div class="col-lg-12 form-col-center mt-2">
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar"
                    CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
