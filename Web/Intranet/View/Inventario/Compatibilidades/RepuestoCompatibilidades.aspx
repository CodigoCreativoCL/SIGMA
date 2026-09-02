<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="RepuestoCompatibilidades.aspx.cs" Inherits="View_Inventario_Compatibilidades_RepuestoCompatibilidades" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirCompatibilidad(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Inventario/Compatibilidades/RepuestoCompatibilidad.aspx") %>?query=' + query);
            oWin.show();
            return false;
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
    Compatibilidades
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    En qué equipos aplica cada repuesto, para que no se monte la pieza equivocada.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <%-- LA PREGUNTA SE HACE EN LAS DOS DIRECCIONES

                 El planificador pregunta "¿para qué equipos sirve esta pieza?"
                 y el técnico, que es quien no debe montar la que no
                 corresponde, pregunta al revés: "¿qué piezas sirven para este
                 equipo?". Los dos combos son eso, y se pueden combinar. --%>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboRepuesto" style="margin: 0;">Repuesto:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboRepuesto" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="90%" AutoPostBack="true" />
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboTipo" style="margin: 0;">Tipo de activo:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="90%" AutoPostBack="true" />
                </div>
            </div>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboModelo" style="margin: 0;">Modelo:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboModelo" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="90%" AutoPostBack="true" />
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="900" Height="560" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="sigma-acciones-barra">
                <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sigma-accion is-primaria"
                    OnClientClick="return abrirCompatibilidad(0);">
                    <i class="mdi mdi-plus"></i><span>Nueva compatibilidad</span>
                </asp:LinkButton>

                <asp:LinkButton ID="lnkEliminar" runat="server" CssClass="sigma-accion"
                    OnClick="lnkEliminar_Click"
                    OnClientClick="return ConfirSweetAlert(this, '', '¿Eliminar las compatibilidades seleccionadas?');"
                    ToolTip="Se borran: una compatibilidad equivocada no se guarda apagada">
                    <i class="mdi mdi-trash-can-outline"></i><span>Eliminar</span>
                </asp:LinkButton>

                <span class="sg-arbol-cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
            </div>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" DataKeyNames="rco_id" />
            </rad:RadGrid2>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                Cada fila declara <strong>un</strong> alcance. Si un repuesto sirve para un tipo de
                activo <em>y</em> además para un modelo concreto, son dos filas: así se puede quitar
                una sin tocar la otra, y no queda una fila que admita dos lecturas distintas.<br />
                <span class="grid-estado-chip is-neutro"><i class="mdi mdi-shape-outline"></i>Tipo</span>
                cubre <strong>todos</strong> los equipos de esa clase ·
                <span class="grid-estado-chip is-info"><i class="mdi mdi-tag-outline"></i>Modelo</span>
                solo ese modelo ·
                <span class="grid-estado-chip is-acento"><i class="mdi mdi-cog-outline"></i>Componente</span>
                una posición concreta de una máquina concreta.<br />
                <strong>Eliminar borra de verdad.</strong> Una compatibilidad es una afirmación de
                hecho: si está mal, guardarla deshabilitada deja puesto justo el dato que puede hacer
                que alguien monte la pieza equivocada.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
