<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="PermisoTrabajoVigentes.aspx.cs" Inherits="View_Terceros_PermisosTrabajo_PermisoTrabajoVigentes" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-permisos-lista.css?vrs=2") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPermiso(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Terceros/PermisosTrabajo/PermisoTrabajo.aspx") %>?query=' + query,
                title: 'Permiso de trabajo vigente',
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
    Permisos vigentes y por vencer
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Para no descubrir en terreno que el permiso caducó.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboTipo" style="margin: 0;">Tipo:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="80%" AutoPostBack="true" />
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboAviso" style="margin: 0;">Avisar con:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <%-- Cuántos días antes se considera "por vencer". No es
                         una constante del sistema: una faena de una semana y
                         una de un día no necesitan el mismo aviso. --%>
                    <rad:RadComboBox2 ID="cboAviso" runat="server" Width="60%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="3 días de anticipación" Value="3" />
                            <rad:RadComboBoxItem Text="7 días de anticipación" Value="7" Selected="true" />
                            <rad:RadComboBoxItem Text="15 días de anticipación" Value="15" />
                            <rad:RadComboBoxItem Text="30 días de anticipación" Value="30" />
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

            <%-- LOS TRES NUMEROS ANTES DE LA LISTA

                 Alguien entra a esta pantalla con una pregunta —"¿tengo algo
                 vencido?"— y la respuesta cabe en un número. Que tenga que
                 contar filas para saberlo es hacerle el trabajo al revés. --%>
            <%-- EL CONTENIDO DE LAS TARJETAS SE ARMA EN EL SERVIDOR

                 Estaban con el numero y el rotulo como controles HIJOS -dos
                 <span> con un <asp:Literal> dentro-. Un LinkButton dibuja su
                 `Text` si tiene algo y, si no, dibuja sus hijos: o sea que lo
                 que se ve dependia de que el arbol de controles se
                 reconstruyera igual en cada postback parcial. Al tocar una
                 tarjeta, las tres quedaban vacias.

                 Ahora `Text` se asigna desde el code-behind. Es una cadena:
                 no hay arbol que reconstruir ni Literal que encontrar. --%>
            <div class="sg-resumen-permisos">
                <asp:LinkButton ID="lnkVencidos" runat="server"
                    OnClick="lnkVencidos_Click" ToolTip="Ver solo los vencidos" />

                <asp:LinkButton ID="lnkPorVencer" runat="server"
                    OnClick="lnkPorVencer_Click" ToolTip="Ver solo los que están por vencer" />

                <asp:LinkButton ID="lnkVigentes" runat="server"
                    OnClick="lnkVigentes_Click" ToolTip="Ver todos" />
            </div>

            <div class="sigma-acciones-barra">
                <asp:Literal ID="litFiltroActivo" runat="server" />

                <asp:LinkButton ID="lnkTodos" runat="server" CssClass="sigma-accion" Visible="false"
                    OnClick="lnkVigentes_Click">
                    <i class="mdi mdi-filter-remove-outline"></i><span>Quitar el filtro</span>
                </asp:LinkButton>

                <asp:LinkButton ID="lnkExportar" runat="server" CssClass="sigma-accion"
                    OnClick="lnkExportar_Click" ToolTip="Baja lo que muestra la pantalla">
                    <i class="mdi mdi-file-excel-outline"></i><span>Descargar a Excel</span>
                </asp:LinkButton>

                <span class="sg-arbol-cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
            </div>

            <div class="sg-permit-list-shell">
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" DataKeyNames="ptr_id" />
            </rad:RadGrid2>
            </div>

            <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="sg-arbol-vacio">
                <i class="mdi mdi-shield-check-outline"></i>
                <div class="titulo">Nada que revisar</div>
                <div class="texto"><asp:Literal ID="litVacio" runat="server" /></div>
            </asp:Panel>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                Esta pantalla es de <strong>solo lectura</strong>: para corregir un permiso se abre
                su ficha desde acá.<br />
                <strong>Por vencer</strong> depende del aviso que elija arriba: con 7 días, un
                permiso que caduca el jueves aparece desde el jueves anterior.<br />
                Los permisos <strong>cerrados</strong> y los que <strong>no tienen vigencia
                declarada</strong> no aparecen: no son parte de esta pregunta. Están en el listado
                completo de permisos.<br />
                <span class="grid-estado-chip is-advertencia"><i class="mdi mdi-file-alert-outline"></i>Sin documento</span>
                marca los que <strong>no tienen el papel firmado adjunto</strong>: un permiso vigente
                sin documento no acredita nada.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
