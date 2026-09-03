<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Bodegas.aspx.cs" Inherits="View_Inventario_Bodegas_Bodegas" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirBodega(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Bodegas/Bodega.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nueva bodega' : 'Editar bodega',
                width: 960,
                initialHeight: 640
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Inventario
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Bodegas
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Dónde se guardan los repuestos, y en qué estante de cada una.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboPlanta" style="margin: 0;">Planta:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="80%" />
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboHabilitado" style="margin: 0;">Habilitada:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="80%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todas" Value="" />
                            <rad:RadComboBoxItem Text="Sí" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="bod_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nueva bodega" CssClass="icono_guardar" OnClientClick="return abrirBodega(0);" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                Una bodega pertenece a una <strong>planta</strong>: el mismo repuesto puede existir
                en dos plantas y son existencias distintas.<br />
                Una bodega con existencia <strong>no se puede dar de baja</strong>: esconderla no
                vacía la estantería. Primero se traslada o se ajusta lo que queda.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
