<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="PermisoTrabajos.aspx.cs" Inherits="View_Terceros_PermisosTrabajo_PermisoTrabajos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Permisos de trabajo unificado (10-10-2026): el Registro de permisos y
         «Vigentes y por vencer», que eran dos pantallas sueltas bajo la carpeta
         «Permisos de trabajo», pasan a ser dos PESTAÑAS de una sola vista, como
         en Proveedores. Así Terceros queda con dos ítems: Proveedores y Permisos
         de trabajo. El detalle sigue en el modal (PermisoTrabajo.aspx). --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-terceros.css?vrs=1") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-permisos-lista.css?vrs=2") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPermiso(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Terceros/PermisosTrabajo/PermisoTrabajo.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo permiso de trabajo' : 'Permiso de trabajo',
                width: 1040,
                initialHeight: 660
            });
        }

        /* El modal llama a refresh() al guardar: refresca el Registro, que es
           la pestaña donde se da de alta y se edita. */
        function refresh() {
            __doPostBack("<%=GridRegistro.ClientID %>", '')
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
    <asp:Literal ID="litSubtitulo" runat="server" />
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">

    <%-- Las pestañas arriba del filtro: primero se elige la vista y después se
         filtra dentro de ella. La activa en morado con subrayado. --%>
    <div class="sg-ter-tabs" role="tablist" aria-label="Vistas de Permisos de trabajo">
        <asp:LinkButton ID="tabRegistro" runat="server" CssClass="sg-ter-tab" OnClick="Tab_Click"
            CommandArgument="R" role="tab">
            <i class="mdi mdi-clipboard-check-outline"></i><span>Registro de permisos</span>
        </asp:LinkButton>
        <asp:LinkButton ID="tabVigentes" runat="server" CssClass="sg-ter-tab" OnClick="Tab_Click"
            CommandArgument="V" role="tab">
            <i class="mdi mdi-clock-alert-outline"></i><span>Vigentes y por vencer</span>
        </asp:LinkButton>
    </div>

    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <%-- Filtros del Registro --%>
            <asp:Panel ID="pnlFiltroRegistro" runat="server">
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
            </asp:Panel>

            <%-- Filtros de Vigentes y por vencer --%>
            <asp:Panel ID="pnlFiltroVigentes" runat="server">
                <div class="row col-lg-12 col-md-12 col-xs-12">
                    <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                        <label for="cboTipoVig" style="margin: 0;">Tipo:</label>
                    </div>
                    <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                        <rad:RadComboBox2 ID="cboTipoVig" runat="server" OnLoad="LoadControls"
                            Filter="Contains" Width="80%" AutoPostBack="true" />
                    </div>
                    <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                        <label for="cboAviso" style="margin: 0;">Avisar con:</label>
                    </div>
                    <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                        <%-- Cuántos días antes se considera "por vencer". No es una
                             constante del sistema: una faena de una semana y una de
                             un día no necesitan el mismo aviso. --%>
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
            </asp:Panel>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- ===================== PESTAÑA: REGISTRO ===================== --%>
            <asp:Panel ID="pnlRegistro" runat="server">

                <div class="sigma-acciones-barra">
                    <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sigma-accion is-primaria"
                        OnClientClick="return abrirPermiso(0);">
                        <i class="mdi mdi-plus"></i><span>Nuevo permiso</span>
                    </asp:LinkButton>

                    <span class="sg-arbol-cuenta"><asp:Literal ID="litCuentaReg" runat="server" /></span>
                </div>

                <%-- El aviso de que todavía no se puede adjuntar. Va arriba y no
                     escondido en la ficha: es lo que hoy limita todo el módulo. --%>
                <asp:Panel ID="pnlSinAdjunto" runat="server" Visible="false" CssClass="sigma-modal-note">
                    <i class="mdi mdi-cloud-off-outline"></i>
                    <div><asp:Literal ID="litSinAdjunto" runat="server" /></div>
                </asp:Panel>

                <div class="sg-permit-list-shell">
                    <rad:RadGrid2 ID="GridRegistro" runat="server" OnItemDataBound="GridRegistro_ItemDataBound">
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
            </asp:Panel>

            <%-- ================= PESTAÑA: VIGENTES Y POR VENCER ================= --%>
            <asp:Panel ID="pnlVigentes" runat="server">

                <%-- LOS TRES NÚMEROS ANTES DE LA LISTA
                     Alguien entra con una pregunta —"¿tengo algo vencido?"— y la
                     respuesta cabe en un número. Y los tres son botones: el que ve
                     un 3 en rojo quiere ver esos tres, no leer toda la lista.
                     El contenido va en `Text` (cadena) y no en controles hijos:
                     un LinkButton dibuja su Text si tiene algo; con hijos, al
                     tocar una tarjeta las tres quedaban vacías en el postback. --%>
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

                    <span class="sg-arbol-cuenta"><asp:Literal ID="litCuentaVig" runat="server" /></span>
                </div>

                <div class="sg-permit-list-shell">
                    <rad:RadGrid2 ID="GridVigentes" runat="server" OnItemDataBound="GridVigentes_ItemDataBound">
                        <MasterTableView CommandItemDisplay="None" DataKeyNames="ptr_id" />
                    </rad:RadGrid2>
                </div>

                <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="sg-arbol-vacio">
                    <i class="mdi mdi-shield-check-outline"></i>
                    <div class="titulo">Nada que revisar</div>
                    <div class="texto"><asp:Literal ID="litVacio" runat="server" /></div>
                </asp:Panel>

                <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                    Esta pestaña es de <strong>solo lectura</strong>: para corregir un permiso se abre
                    su ficha desde acá.<br />
                    <strong>Por vencer</strong> depende del aviso que elija arriba: con 7 días, un
                    permiso que caduca el jueves aparece desde el jueves anterior.<br />
                    Los permisos <strong>cerrados</strong> y los que <strong>no tienen vigencia
                    declarada</strong> no aparecen: no son parte de esta pregunta. Están en el Registro
                    de permisos.<br />
                    <span class="grid-estado-chip is-advertencia"><i class="mdi mdi-file-alert-outline"></i>Sin documento</span>
                    marca los que <strong>no tienen el papel firmado adjunto</strong>: un permiso vigente
                    sin documento no acredita nada.
                </div>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
