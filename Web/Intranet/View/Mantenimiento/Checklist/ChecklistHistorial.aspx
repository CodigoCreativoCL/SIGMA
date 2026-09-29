<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ChecklistHistorial.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistHistorial" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function refresh() { __doPostBack("<%=Grid.ClientID %>", '') }
        function verDetalle(id) {
            document.getElementById('<%=hidEjecucion.ClientID %>').value = id;
            __doPostBack('<%=Grid.UniqueID %>', '');
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Historial de ejecuciones</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Cómo se ha respondido una pauta a lo largo del tiempo. Solo lectura: elija una pauta y abra una ejecución para ver cada pregunta con su respuesta y sus fotografías.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para ver el historial.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="card-box" style="margin-bottom:12px;">
                <div class="row">
                    <div class="col-lg-6 col-md-6 col-12">
                        <label for="cboPlantilla" style="display:block; margin:0 0 4px;">Pauta:</label>
                        <rad:RadComboBox2 ID="cboPlantilla" runat="server" Width="100%" AutoPostBack="true"
                            Filter="Contains" OnSelectedIndexChanged="Filtro_Changed" />
                    </div>
                    <div class="col-lg-4 col-md-4 col-12">
                        <label for="cboEstado" style="display:block; margin:0 0 4px;">Estado:</label>
                        <rad:RadComboBox2 ID="cboEstado" runat="server" Width="100%" AutoPostBack="true"
                            OnSelectedIndexChanged="Filtro_Changed" />
                    </div>
                    <div class="col-lg-2 col-md-2 col-12"></div>
                </div>
            </div>

            <asp:Panel ID="pnlElijaPauta" runat="server" Visible="false" CssClass="sigma-modal-note" style="margin:0 0 10px;">
                <i class="mdi mdi-clipboard-text-clock-outline"></i>
                <div>Elija una pauta para ver sus ejecuciones.</div>
            </asp:Panel>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound" AllowPaging="true" PageSize="25">
                <MasterTableView>
                    <Columns>
                    </Columns>
                </MasterTableView>
            </rad:RadGrid2>

            <asp:HiddenField ID="hidEjecucion" runat="server" />

            <asp:Panel ID="pnlDetalle" runat="server" Visible="false" CssClass="card-box" style="margin-top:14px;">
                <asp:Literal ID="litDetalle" runat="server" />
            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
