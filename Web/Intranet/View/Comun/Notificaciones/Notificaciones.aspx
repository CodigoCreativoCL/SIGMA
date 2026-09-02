<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Notificaciones.aspx.cs" Inherits="View_Comun_Notificaciones_Notificaciones" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="../../../Css/LookAndFeel/sigma-notificaciones.css?vrs=3" rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Operación
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Alertas
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Lo que el sistema encontró y todavía nadie resolvió.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-12 d-flex align-items-center" style="gap: 12px;">
                    <label for="cboCategoria" style="margin: 0;">Categoría:</label>
                    <rad:RadComboBox2 ID="cboCategoria" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-12 d-flex align-items-center" style="gap: 12px;">
                    <label for="cboSeveridad" style="margin: 0;">Gravedad:</label>
                    <rad:RadComboBox2 ID="cboSeveridad" runat="server" Width="100%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Todas" Value="" />
                            <rad:RadComboBoxItem Text="Crítica" Value="CRITICA" />
                            <rad:RadComboBoxItem Text="Alta" Value="ALTA" />
                            <rad:RadComboBoxItem Text="Advertencia" Value="ADVERTENCIA" />
                            <rad:RadComboBoxItem Text="Baja" Value="BAJA" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-3 col-md-3 col-12 d-flex align-items-center" style="gap: 12px;">
                    <label for="cboLectura" style="margin: 0;">Estado:</label>
                    <rad:RadComboBox2 ID="cboLectura" runat="server" Width="100%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Abiertas" Value="ABIERTAS" Selected="true" />
                            <rad:RadComboBoxItem Text="Solo sin leer" Value="NUEVAS" />
                            <rad:RadComboBoxItem Text="Todas, incluso resueltas" Value="TODAS" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* Se abre el registro en la misma ventana modal que usa el resto del
           sitio: quien revisa la bandeja quiere resolver sin perder la lista. */
        function abrirFicha(url, query, id, menu) {
            /* Abrirla es haberla leida: se marca ANTES de mostrar la ventana,
               porque despues el foco se lo lleva el modal y el usuario ya no
               vuelve a mirar los contadores.

               menu es el enlace del modulo al que pertenece la alerta, para
               que su numero en el menu lateral baje junto con la campana. */
            if (id && window.sigmaAlertas) sigmaAlertas.leer(id, menu);

            /* La fila se apaga en el acto. Volver de la ficha y encontrarla
               todavia resaltada como nueva se lee como que no se registro. */
            if (window.event && window.event.target && window.event.target.closest) {
                var fila = window.event.target.closest('.sg-notif-item');
                if (fila) fila.classList.remove('is-nueva');
            }

            var oWin = $find("<%=rwiFicha.ClientID %>");
            if (!oWin) return false;

            oWin.setUrl(query ? url + "?query=" + query : url);
            oWin.show();
            return false;
        }

        /* Al cerrar la ficha, la ventana modal llama a refresh(): la alerta
           pudo quedar resuelta y la lista tiene que enterarse. */
        function refresh() { __doPostBack("<%=lnkRevisar.UniqueID %>", ""); }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <rad:RadWindow2 ID="rwiFicha" runat="server" Width="1000" Height="680" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="sigma-acciones-barra">
                <asp:LinkButton ID="lnkLeerTodo" runat="server" CssClass="sigma-accion"
                    OnClick="lnkLeerTodo_Click" ToolTip="Marca como vistas todas las que puede ver">
                    <i class="mdi mdi-check-all"></i><span>Marcar todo como leído</span>
                </asp:LinkButton>

                <asp:LinkButton ID="lnkRevisar" runat="server" CssClass="sigma-accion"
                    OnClick="lnkRevisar_Click"
                    ToolTip="Vuelve a revisar los umbrales y actualiza la lista">
                    <i class="mdi mdi-refresh"></i><span>Revisar ahora</span>
                </asp:LinkButton>

                <span class="sg-notif-cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
            </div>

            <%-- AGRUPADO POR CATEGORIA, NO UNA LISTA PLANA

                 Veinte avisos seguidos obligan a leerlos todos para saber si
                 hay algo de bodega. Agrupados, se mira el grupo que importa y
                 se ignora el resto — y cada grupo dice cuantos trae, asi que
                 se decide sin abrirlo. --%>
            <asp:Repeater ID="rptGrupos" runat="server" OnItemDataBound="rptGrupos_ItemDataBound">
                <ItemTemplate>
                    <div class="sg-notif-grupo">
                        <div class="cabecera">
                            <span class="icono"><i class='<%# Eval("Icono") %>'></i></span>
                            <span class="nombre"><%# Server.HtmlEncode(Eval("Nombre").ToString()) %></span>
                            <span class="cuenta"><%# Eval("Total") %></span>
                        </div>
                        <div class="cuerpo">
                            <asp:Literal ID="litItems" runat="server" />
                        </div>
                    </div>
                </ItemTemplate>
            </asp:Repeater>

            <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="sg-notif-vacio sg-notif-vacio-pagina">
                <div class="sg-notif-ilustracion">
                    <%-- ============================================
                         ESPACIO PARA EL SVG DE SIGMA
                         El contenedor centra y acota a 140px de alto:
                         el svg solo necesita su viewBox y medidas al 100%.
                         ============================================ --%>
                    <i class="mdi mdi-bell-check-outline"></i>
                </div>
                <div class="sg-notif-vacio-titulo">Todo en orden</div>
                <div class="sg-notif-vacio-texto">
                    <asp:Literal ID="litVacio" runat="server"
                        Text="No hay nada que revisar con estos filtros." />
                </div>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>

</asp:Content>
