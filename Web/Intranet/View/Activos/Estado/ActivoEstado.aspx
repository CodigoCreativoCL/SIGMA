<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoEstado.aspx.cs" Inherits="View_Activos_Estado_ActivoEstado" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Activos</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Cambiar estado</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Cambia el estado de un activo dejando constancia del motivo y de quién lo hizo.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-6 col-md-8 col-xs-12 d-flex align-items-center" style="gap: 12px;">
                    <label for="cboActivo" style="margin: 0; white-space: nowrap;">Activo:</label>
                    <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                        OnSelectedIndexChanged="cboActivo_SelectedIndexChanged" Filter="Contains" Width="100%" />
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para consultar sus activos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Panel ID="pnlSinActivo" runat="server" Visible="true" CssClass="card-box">
                <p>Elija un activo para ver su estado y cambiarlo.</p>
            </asp:Panel>

            <%-- ====== ACCION: CAMBIAR ESTADO ====== --%>
            <asp:Panel ID="pnlCambio" runat="server" Visible="false" CssClass="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-sync"></i>Cambiar estado</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-chico">
                        <label>Estado actual</label>
                        <div class="sigma-modal-valor"><asp:Label ID="lblEstadoActual" runat="server" /></div>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Nuevo estado(*)</label>
                        <rad:RadComboBox2 ID="cboNuevoEstado" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    </div>
                    <div class="sigma-modal-field is-grande">
                        <label>Motivo</label>
                        <WebControls:TextArea2 ID="txtMotivo" runat="server" MaxLength="500" />
                        <span class="sigma-modal-ayuda">Obligatorio al detener, dejar fuera de servicio o dar de baja.</span>
                    </div>
                </div>
                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnCambiar" runat="server" Text="Cambiar estado" OnClick="btnCambiar_Click" />
                </div>
            </asp:Panel>

            <%-- ====== HISTORIAL DE ESTADOS ====== --%>
            <asp:Panel ID="pnlHistorial" runat="server" Visible="false">
                <div class="sigma-form-seccion">
                    <div class="titulo"><i class="mdi mdi-history"></i>Historial de estados</div>
                </div>
                <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrHistorial_ItemDataBound">
                    <MasterTableView CommandItemDisplay="None" />
                </rad:RadGrid2>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
