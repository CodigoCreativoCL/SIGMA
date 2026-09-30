<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ChecklistHallazgos.aspx.cs" Inherits="View_Mantenimiento_Hallazgos_ChecklistHallazgos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-pauta360.css") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function refresh() { __doPostBack('<%=lnkRecargar.UniqueID %>', ''); }

        /* Seleccionar un hallazgo muestra su detalle a la derecha (sin postback). */
        function pcHzSel(id) {
            id = String(id);
            var r = document.querySelectorAll('.pc-hz-fila');
            for (var i = 0; i < r.length; i++) r[i].classList.toggle('es-sel', r[i].getAttribute('data-hz') === id);
            var d = document.querySelectorAll('.pc-hz-det');
            for (var j = 0; j < d.length; j++) d[j].classList.toggle('es-sel', d[j].getAttribute('data-hzdet') === id);
            return false;
        }
        /* Generar OT para un hallazgo (postback). */
        function pcHzOT(id) {
            if (!confirm('¿Generar una orden de trabajo por este hallazgo? Queda enlazado y sale de la bandeja.')) return false;
            document.getElementById('hdnAccionId').value = id;
            __doPostBack('<%=btnGenerarOT.UniqueID %>', '');
            return false;
        }
        /* Descartar con motivo (mínimo 10 caracteres). */
        function pcHzDesc(id) {
            var m = prompt('Motivo del descarte (mínimo 10 caracteres):', '');
            if (m === null) return false;
            if (m.trim().length < 10) { alert('El motivo debe tener al menos 10 caracteres.'); return false; }
            document.getElementById('hdnAccionId').value = id;
            document.getElementById('hdnMotivo').value = m.trim();
            __doPostBack('<%=btnDescartar.UniqueID %>', '');
            return false;
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Hallazgos de inspección</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Bandeja transversal de todas las pautas de inspección.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-4 col-md-4 col-12">
                    <label for="cboPlanta" style="display:block; margin:0 0 4px;">Planta:</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboSeveridad" style="display:block; margin:0 0 4px;">Severidad:</label>
                    <rad:RadComboBox2 ID="cboSeveridad" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboEstado" style="display:block; margin:0 0 4px;">Estado:</label>
                    <rad:RadComboBox2 ID="cboEstado" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-2 col-md-2 col-xs-12"></div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para ver sus hallazgos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="sg-pc">
                <asp:HiddenField ID="hdnAccionId" runat="server" Value="0" ClientIDMode="Static" />
                <asp:HiddenField ID="hdnMotivo" runat="server" Value="" ClientIDMode="Static" />
                <asp:LinkButton ID="lnkRecargar" runat="server" style="display:none" CausesValidation="false" OnClick="lnkRecargar_Click" />
                <asp:LinkButton ID="btnGenerarOT" runat="server" style="display:none" CausesValidation="false" OnClick="btnGenerarOT_Click" />
                <asp:LinkButton ID="btnDescartar" runat="server" style="display:none" CausesValidation="false" OnClick="btnDescartar_Click" />

                <%-- KPIs + Exportar --%>
                <div style="display:flex;gap:12px;align-items:stretch;margin-bottom:16px;flex-wrap:wrap;">
                    <div class="sg-a3-kpi" style="flex:1;min-width:170px;"><span class="sg-a3-kpi-ico es-alerta"><i class="mdi mdi-alert-circle-outline"></i></span><div class="sg-a3-kpi-txt"><span>Pendientes</span><b><asp:Literal ID="litKpiPend" runat="server" Text="0" /></b></div></div>
                    <div class="sg-a3-kpi" style="flex:1;min-width:170px;"><span class="sg-a3-kpi-ico es-info"><i class="mdi mdi-clipboard-text-outline"></i></span><div class="sg-a3-kpi-txt"><span>Con OT</span><b><asp:Literal ID="litKpiOt" runat="server" Text="0" /></b></div></div>
                    <div class="sg-a3-kpi" style="flex:1;min-width:170px;"><span class="sg-a3-kpi-ico es-ok"><i class="mdi mdi-check-circle-outline"></i></span><div class="sg-a3-kpi-txt"><span>Descartados</span><b><asp:Literal ID="litKpiDesc" runat="server" Text="0" /></b></div></div>
                    <asp:LinkButton ID="lnkDescargar" runat="server" CssClass="pc-btn out" style="align-self:center;" OnClick="lnkDescargar_Click" CausesValidation="false"><i class="mdi mdi-download-outline"></i>Exportar a Excel</asp:LinkButton>
                </div>

                <div class="pc-md-grid">
                    <div class="pc-card">
                        <div class="pc-list-cab"><div><h3>Hallazgos</h3><span class="s">Toque una fila para ver el detalle a la derecha.</span></div></div>
                        <asp:Literal ID="litTabla" runat="server" />
                    </div>
                    <aside class="pc-aside">
                        <div class="pc-card"><asp:Literal ID="litDetalle" runat="server" /></div>
                    </aside>
                </div>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
