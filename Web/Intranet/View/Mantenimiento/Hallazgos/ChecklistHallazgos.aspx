<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ChecklistHallazgos.aspx.cs" Inherits="View_Mantenimiento_Hallazgos_ChecklistHallazgos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function refresh() { __doPostBack("<%=Grid.ClientID %>", '') }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mantenimiento
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Hallazgos de inspección
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Lo que las pautas encontraron en terreno: respuestas fuera de rango y no conformidades. Solo lectura; la orden de trabajo se abre desde el hallazgo cuando corresponde.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-4 col-md-4 col-12">
                    <label for="cboPlanta" style="display:block; margin:0 0 4px;">Planta:</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboSeveridad" style="display:block; margin:0 0 4px;">Severidad:</label>
                    <rad:RadComboBox2 ID="cboSeveridad" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboEstado" style="display:block; margin:0 0 4px;">Estado:</label>
                    <rad:RadComboBox2 ID="cboEstado" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-2 col-md-2 col-xs-12"></div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para ver sus hallazgos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound" AllowPaging="true" PageSize="50">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="cha_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkDescargar" runat="server" Text="Descargar Excel" CssClass="icono_excel" OnClick="lnkDescargar_Click" CausesValidation="false" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
