<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="OrdenTrabajos.aspx.cs" Inherits="View_Mantenimiento_Ordenes_OrdenTrabajos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* La orden es un centro (ficha, asignación, pasos, indisponibilidad,
           cierre): se entra a ella, no se abre en modal. */
        function abrirOrdenTrabajo(query) {
            location.href = '<%=ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") %>' + (String(query) === '0' ? '' : '?query=' + query);
            return false;
        }
        function refresh() { __doPostBack("<%=Grid.ClientID %>", '') }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mantenimiento
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Órdenes de trabajo
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    El trabajo concreto: qué, a qué equipo, quién y en qué estado. La <strong>bandeja de cierre</strong> es lo que el técnico ya finalizó y espera que alguien con facultad cierre.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboEstado" style="display:block; margin:0 0 4px;">Estado:</label>
                    <rad:RadComboBox2 ID="cboEstado" runat="server" Width="100%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Abiertas y en ejecución" Value="ABIERTAS" Selected="true" />
                            <rad:RadComboBoxItem Text="Abierta" Value="1" />
                            <rad:RadComboBoxItem Text="En ejecución" Value="2" />
                            <rad:RadComboBoxItem Text="Bandeja de cierre (en espera)" Value="3" />
                            <rad:RadComboBoxItem Text="Cerrada" Value="4" />
                            <rad:RadComboBoxItem Text="Todas" Value="" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboTipo" style="display:block; margin:0 0 4px;">Tipo:</label>
                    <rad:RadComboBox2 ID="cboTipo" runat="server" Width="100%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Preventiva" Value="1" />
                            <rad:RadComboBoxItem Text="Correctiva" Value="2" />
                            <rad:RadComboBoxItem Text="Predictiva" Value="3" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboPlanta" style="display:block; margin:0 0 4px;">Planta:</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-xs-12"></div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus órdenes.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <%-- La bandeja de cierre (HU-122): cierre masivo con motivo común; cada cierre queda registrado por su cuenta. --%>
            <asp:Panel ID="pnlCierre" runat="server" Visible="false" CssClass="sigma-modal-grid" style="margin:0 0 8px;">
                <div class="sigma-modal-field is-chico">
                    <label>Motivo de cierre (común)</label>
                    <rad:RadComboBox2 ID="cboMotivoCierre" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Trabajo realizado" Value="1" Selected="true" />
                            <rad:RadComboBoxItem Text="Sin hallazgo, no requirió intervención" Value="2" />
                            <rad:RadComboBoxItem Text="Resuelta en otra orden" Value="3" />
                            <rad:RadComboBoxItem Text="Duplicada" Value="4" />
                            <rad:RadComboBoxItem Text="Anulada por error de registro" Value="5" />
                            <rad:RadComboBoxItem Text="No aplica" Value="6" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="sigma-modal-field is-grande">
                    <label>Trabajo realizado (obligatorio si el motivo es «Trabajo realizado»)</label>
                    <WebControls:TextBox2 ID="txtResultado" runat="server" MaxLength="2000" />
                </div>
            </asp:Panel>
            <asp:Panel ID="pnlResultado" runat="server" Visible="false" CssClass="sigma-modal-note" style="margin:0 0 10px;">
                <i class="mdi mdi-clipboard-check-outline"></i>
                <div><asp:Literal ID="litResultado" runat="server" /></div>
            </asp:Panel>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound" AllowPaging="true" PageSize="50">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="otr_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nueva orden" CssClass="icono_guardar" OnClientClick="return abrirOrdenTrabajo(0);" />
                            <asp:LinkButton ID="lnkCerrar" runat="server" Text="Cerrar seleccionadas" CssClass="icono_excel" OnClick="lnkCerrar_Click" CausesValidation="false"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Cerrar las órdenes seleccionadas con el motivo indicado? Cada cierre queda registrado por separado.');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
