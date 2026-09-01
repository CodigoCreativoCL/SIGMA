<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoFicha.aspx.cs" Inherits="View_Activos_Ficha_ActivoFicha" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Activos
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Ficha e historial
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Toda la vida de un equipo en una sola pantalla.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12 sigma-filtro">
                <div class="col-lg-4 col-md-6 col-xs-12 sigma-filtro-campo">
                    <label>Activo</label>
                    <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                </div>
                <div class="col-lg-3 col-md-6 col-xs-12 sigma-filtro-campo">
                    <label>Tipo de evento</label>
                    <rad:RadComboBox2 ID="cboTipo" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Cambios de estado" Value="ESTADO" />
                            <rad:RadComboBoxItem Text="Cambios de posición" Value="POSICION" />
                            <rad:RadComboBoxItem Text="Mediciones" Value="MEDICION" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-2 col-md-6 col-xs-12 sigma-filtro-campo">
                    <label>Desde</label>
                    <div class="sigma-filtro-fecha"><WebControls:Calendar ID="calDesde" runat="server" /></div>
                </div>
                <div class="col-lg-2 col-md-6 col-xs-12 sigma-filtro-campo">
                    <label>Hasta</label>
                    <div class="sigma-filtro-fecha"><WebControls:Calendar ID="calHasta" runat="server" /></div>
                </div>
                <div class="col-lg-1 col-md-6 col-xs-12 sigma-filtro-campo sigma-filtro-accion">
                    <WebControls:PushButton ID="btnBuscar" runat="server" Text="Buscar" OnClick="btnBuscar_Click" />
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
                <p>Elija un activo en el filtro para ver su ficha y su historial.</p>
            </asp:Panel>

            <%-- ====== FICHA DEL ACTIVO (CA1) ====== --%>
            <asp:Panel ID="pnlFicha" runat="server" Visible="false" CssClass="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-cog-outline"></i>Ficha del activo</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-chico"><label>Código</label><div class="sigma-modal-valor"><asp:Label ID="lblCodigo" runat="server" /></div></div>
                    <div class="sigma-modal-field is-medio"><label>Nombre</label><div class="sigma-modal-valor"><asp:Label ID="lblNombre" runat="server" /></div></div>
                    <div class="sigma-modal-field is-chico"><label>Planta</label><div class="sigma-modal-valor"><asp:Label ID="lblPlanta" runat="server" /></div></div>
                    <div class="sigma-modal-field is-chico"><label>Área</label><div class="sigma-modal-valor"><asp:Label ID="lblArea" runat="server" /></div></div>
                    <div class="sigma-modal-field is-chico"><label>Tipo</label><div class="sigma-modal-valor"><asp:Label ID="lblTipo" runat="server" /></div></div>
                    <div class="sigma-modal-field is-chico"><label>Estado</label><div class="sigma-modal-valor"><asp:Label ID="lblEstado" runat="server" /></div></div>
                    <div class="sigma-modal-field is-chico"><label>Criticidad</label><div class="sigma-modal-valor"><asp:Label ID="lblCriticidad" runat="server" /></div></div>
                </div>
            </asp:Panel>

            <%-- ====== HISTORIAL (CA2) ====== --%>
            <asp:Panel ID="pnlHistorial" runat="server" Visible="false">
                <div class="sigma-form-seccion">
                    <div class="titulo"><i class="mdi mdi-history"></i>Historial</div>
                </div>

                <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrHistorial_ItemDataBound">
                    <MasterTableView CommandItemDisplay="Top">
                        <CommandItemTemplate>
                            <div style="margin-bottom: 5px;">
                                <asp:LinkButton ID="lnkExportar" runat="server" Text="Exportar a Excel" CssClass="icono_excel" OnClick="lnkExportar_Click" />
                            </div>
                        </CommandItemTemplate>
                    </MasterTableView>
                </rad:RadGrid2>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
