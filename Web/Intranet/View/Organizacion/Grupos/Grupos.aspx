<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Grupos.aspx.cs" Inherits="View_Organizacion_Grupos_Grupos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <style>
        /* Integrantes como caras pequenas, una al lado de otra (sin
           encimarse); el lider primero con borde morado. */
        .sg-avatares { display: inline-flex; align-items: center; gap: 4px; flex-wrap: wrap; justify-content: center; }
        .sg-avatar {
            width: 24px; height: 24px; border-radius: 50%; box-sizing: border-box;
            display: inline-flex; align-items: center; justify-content: center;
            font-size: 10px; font-weight: 800; line-height: 1; letter-spacing: 0;
            background: #EAF4FF; color: #0565C2; border: 1.5px solid transparent;
        }
        .sg-avatar.t1 { background: #F2EFFF; color: #4820C9; }
        .sg-avatar.t2 { background: #E8FBFB; color: #007F8A; }
        .sg-avatar.t3 { background: #EAF4FF; color: #0565C2; }
        .sg-avatar.t4 { background: #FFF3E6; color: #B65C00; }
        .sg-avatar.is-lider { border-color: #6732F4; }
        .sg-avatar.is-mas { background: #F4F6FA; color: #68738A; }
        .sg-avatares-vacio { color: #68738A; font-size: 12px; }
    </style>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-grupo.css?vrs=1") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirGrupo(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Organizacion/Grupos/Grupo.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo grupo de trabajo' : 'Editar grupo de trabajo',
                width: 1060,
                initialHeight: 660
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }

        /* Al cerrar la ficha de un grupo se recarga la grilla: los
           integrantes se agregan y quitan dentro de la ficha sin cerrarla,
           y sin esto las caras y el lider seguian mostrando lo de antes
           hasta apretar F5. Es una recarga parcial (UpdatePanel). */
        document.addEventListener('sigma:modalclosed', function () {
            refresh();
        });
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Organización
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Grupos de Trabajo
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Cuadrillas y turnos, para asignar trabajo al equipo y no a una persona.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboPlanta" style="margin: 0;">Planta:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="80%" />
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboHabilitado" style="margin: 0;">Habilitado:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="60%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Si" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus grupos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrGrupos_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="gtr_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sigma-accion is-primaria" OnClientClick="return abrirGrupo(0);">
                                <i class="mdi mdi-plus"></i><span>Nuevo grupo</span>
                            </asp:LinkButton>
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
