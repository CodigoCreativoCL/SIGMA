<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="PermisoTrabajos.aspx.cs" Inherits="View_Terceros_PermisosTrabajo_PermisoTrabajos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-permisos-lista.css?vrs=2") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPermiso(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Terceros/PermisosTrabajo/PermisoTrabajo.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo permiso de trabajo' : 'Editar permiso de trabajo',
                width: 1040,
                initialHeight: 660
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
    Permisos de trabajo
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    La constancia de que la faena de riesgo se ejecutó con la autorización correspondiente.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboSituacion" style="margin: 0;">Situación:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <%-- La situación primero, porque es la pregunta que trae a
                         alguien a esta pantalla: "¿qué está por vencer?". --%>
                    <rad:RadComboBox2 ID="cboSituacion" runat="server" Width="80%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Todas" Value="" Selected="true" />
                            <rad:RadComboBoxItem Text="Vigentes" Value="VIGENTE" />
                            <rad:RadComboBoxItem Text="Por vencer" Value="POR VENCER" />
                            <rad:RadComboBoxItem Text="Vencidos" Value="VENCIDO" />
                            <rad:RadComboBoxItem Text="Cerrados o rechazados" Value="CERRADO" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboTipo" style="margin: 0;">Tipo:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="80%" AutoPostBack="true" />
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
                    OnClientClick="return abrirPermiso(0);">
                    <i class="mdi mdi-plus"></i><span>Nuevo permiso</span>
                </asp:LinkButton>

                <span class="sg-arbol-cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
            </div>

            <%-- El aviso de que todavía no se puede adjuntar. Va arriba y no
                 escondido en la ficha: es lo que hoy limita todo el módulo. --%>
            <asp:Panel ID="pnlSinAdjunto" runat="server" Visible="false" CssClass="sigma-modal-note">
                <i class="mdi mdi-cloud-off-outline"></i>
                <div><asp:Literal ID="litSinAdjunto" runat="server" /></div>
            </asp:Panel>

            <div class="sg-permit-list-shell">
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" DataKeyNames="ptr_id" />
            </rad:RadGrid2>
            </div>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                La <strong>situación</strong> se calcula contra la fecha de hoy, no se guarda: un
                permiso que venció anoche aparece vencido sin que nadie tenga que correr nada.<br />
                <span class="grid-estado-chip is-exito"><i class="mdi mdi-check-circle-outline"></i>Vigente</span>
                <span class="grid-estado-chip is-advertencia"><i class="mdi mdi-clock-alert-outline"></i>Por vencer</span>
                (quedan 7 días o menos) ·
                <span class="grid-estado-chip is-alerta"><i class="mdi mdi-close-circle-outline"></i>Vencido</span><br />
                <strong>Un permiso autorizado necesita su documento firmado adjunto.</strong> Lo exige
                la base de datos, no la pantalla: la constancia es el papel, no el registro.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
