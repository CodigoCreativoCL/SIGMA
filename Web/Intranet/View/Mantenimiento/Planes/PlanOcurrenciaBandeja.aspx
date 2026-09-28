<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="PlanOcurrenciaBandeja.aspx.cs" Inherits="View_Mantenimiento_Planes_PlanOcurrenciaBandeja" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- La cáscara de tarjetas y chips es la misma del centro del plan y del
         activo: se reusa tal cual, no se vuelve a inventar. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-orden.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activo360.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-plan360.css") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirOrden(query) {
            location.href = '<%=ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") %>?query=' + query;
            return false;
        }

        function abrirPlan(query) {
            location.href = '<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx") %>?query=' + query;
            return false;
        }

        function abrirReprogramar(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanOcurrenciaReprogramar.aspx") %>?query=' + query,
                title: 'Reprogramar la mantención',
                width: 720,
                initialHeight: 560
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mantenimiento · Planificación
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Bandeja de mantenciones
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Lo que está por vencer o ya venció, de todos los planes y en un solo lugar. Lo más urgente primero.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboPlanta" style="display:block; margin:0 0 4px;">Planta:</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboPlan" style="display:block; margin:0 0 4px;">Plan:</label>
                    <rad:RadComboBox2 ID="cboPlan" runat="server" Width="100%" Filter="Contains" AutoPostBack="true" />
                </div>
                <div class="col-lg-2 col-md-2 col-12">
                    <label for="calDesde" style="display:block; margin:0 0 4px;">Desde:</label>
                    <WebControls:Calendar ID="calDesde" runat="server" />
                </div>
                <div class="col-lg-2 col-md-2 col-12">
                    <label for="calHasta" style="display:block; margin:0 0 4px;">Hasta:</label>
                    <WebControls:Calendar ID="calHasta" runat="server" />
                </div>
                <div class="col-lg-2 col-md-2 col-12">
                    <label style="display:block; margin:0 0 4px;">&nbsp;</label>
                    <asp:CheckBox ID="chkSoloParada" runat="server" Text="Solo con parada" AutoPostBack="true" OnCheckedChanged="Filtro_Changed" />
                    <asp:CheckBox ID="chkVerCerradas" runat="server" Text="Ver también cerradas" AutoPostBack="true" OnCheckedChanged="Filtro_Changed" />
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para ver su bandeja de mantenciones.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- Los tokens de color viven en .sg-a3: sin esa clase, las
                 variables no resuelven y las tarjetas salen en blanco. --%>
            <asp:Panel ID="pnlResumen" runat="server" CssClass="sg-a3 sg-ot">

                <%-- LOS CONTADORES SON LA BOTONERA

                     No son adorno: cada uno filtra la grilla por su
                     situación. Es la forma natural de usar una bandeja
                     -"muéstrame las 7 vencidas"- y evita un combo más
                     arriba que diga lo mismo con menos información.

                     El HTML lo arma el servidor y el postback lo recibe el
                     LinkButton escondido de abajo: el markup metido DENTRO
                     de un LinkButton no sobrevive al re-render asíncrono
                     -vuelve un <a> vacío- porque LinkButton es un control
                     de texto, no un contenedor. --%>
                <asp:Literal ID="litKpis" runat="server" />

                <%-- La situacion elegida viaja en el campo oculto y el
                     LinkButton solo dispara el viaje: el argumento de
                     __doPostBack llegaba vacio. Es el mismo par que usa el
                     centro del plan con hdnSeccion. --%>
                <asp:HiddenField ID="hdnSituacion" runat="server" Value="" ClientIDMode="Static" />
                <asp:LinkButton ID="lnkSituacion" runat="server" style="display:none"
                    OnClick="lnkSituacion_Click" CausesValidation="false" />

                <asp:Literal ID="litContexto" runat="server" />
            </asp:Panel>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound" AllowPaging="true" PageSize="50">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="pmo_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkGenerarOT" runat="server" Text="Generar órdenes de trabajo" CssClass="icono_guardar"
                                OnClick="lnkGenerarOT_Click" CausesValidation="false"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Generar una orden de trabajo por cada ocurrencia seleccionada? Las que ya tienen orden se informan y no se duplican.');" />
                            <asp:LinkButton ID="lnkDescargar" runat="server" Text="Descargar Excel" CssClass="icono_excel"
                                OnClick="lnkDescargar_Click" CausesValidation="false" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>

            <asp:Panel ID="pnlResultado" runat="server" Visible="false" CssClass="sg-a3 sg-ot">
                <div class="sg-ot-nota">
                    <i class="mdi mdi-clipboard-check-outline"></i>
                    <span><asp:Literal ID="litResultado" runat="server" /></span>
                </div>
            </asp:Panel>

            <asp:Panel runat="server" CssClass="sg-a3 sg-ot">
                <div class="sg-ot-nota es-chica">
                    <i class="mdi mdi-information-outline"></i>
                    <span>La <strong>situación</strong> se calcula al consultar, comparando las fechas con ahora: no depende de ningún proceso nocturno que «venza» filas. Las ocurrencias las genera la versión publicada de cada plan y las cierra la orden de trabajo.</span>
                </div>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
