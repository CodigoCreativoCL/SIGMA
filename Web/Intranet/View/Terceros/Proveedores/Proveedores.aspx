<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Proveedores.aspx.cs" Inherits="View_Terceros_Proveedores_Proveedores" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirProveedor(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Terceros/Proveedores/Proveedor.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo proveedor' : 'Editar proveedor',
                width: 1000,
                initialHeight: 640
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Terceros
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Proveedores
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Las empresas que le prestan servicios a la planta y las que le venden repuestos.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboTipo" style="margin: 0;">Tipo:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboTipo" runat="server" Width="80%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Contratistas" Value="C" />
                            <rad:RadComboBoxItem Text="Proveedores de repuestos" Value="R" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboHabilitado" style="margin: 0;">Habilitado:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="60%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Sí" Value="1" Selected="true" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                            <rad:RadComboBoxItem Text="Todos" Value="" />
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

            <div class="sigma-acciones-barra">
                <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sigma-accion is-primaria"
                    OnClientClick="return abrirProveedor(0);">
                    <i class="mdi mdi-plus"></i><span>Nuevo proveedor</span>
                </asp:LinkButton>

                <asp:LinkButton ID="lnkEliminar" runat="server" CssClass="sigma-accion"
                    OnClick="lnkEliminar_Click"
                    OnClientClick="return ConfirSweetAlert(this, '', '¿Deshabilitar los proveedores seleccionados?');"
                    ToolTip="Deja de ofrecerlos sin perder su historial">
                    <i class="mdi mdi-trash-can-outline"></i><span>Eliminar</span>
                </asp:LinkButton>
            </div>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" DataKeyNames="prv_id" />
            </rad:RadGrid2>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                El buscador mira el <strong>identificador tributario, la razón social, el nombre de
                fantasía, el contacto y el correo</strong>.<br />
                <strong>Eliminar</strong> no borra: <strong>deshabilita</strong>. Un proveedor con lotes
                recibidos o servicios contratados aparece en el historial de compra y en el gasto del
                año, así que su nombre tiene que seguir estando. Deshabilitado deja de ofrecerse en los
                combos y conserva todo lo anterior.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
