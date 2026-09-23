<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ChecklistVersion.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistVersion" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
    <style type="text/css">
        .cvv-cab { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; padding-bottom: 14px; border-bottom: 1px solid #e5e7eb; margin-bottom: 16px; }
        .cvv-cod { font-size: 11px; font-weight: 700; letter-spacing: .04em; color: #6C5CFF; text-transform: uppercase; }
        .cvv-nom { margin: 2px 0 0; font-size: 20px; font-weight: 700; color: #111827; }
        .cvv-pub { border: 1px solid #e5e7eb; border-radius: 10px; padding: 12px 14px; background: #fafbfc; margin-bottom: 16px; }
        .cvv-pub .t { font-weight: 700; color: #0f172a; font-size: 13.5px; margin-bottom: 6px; }
        .cvv-pub textarea { width: 100%; box-sizing: border-box; padding: 8px 10px; border: 1px solid #e5e7eb; border-radius: 9px; font-size: 13px; min-height: 54px; font-family: inherit; }
        .cvv-hist-t { font-weight: 700; color: #0f172a; font-size: 13px; margin: 4px 0 8px; }
        .cvv-row { display: flex; align-items: center; gap: 12px; padding: 9px 12px; border: 1px solid #eef0f4; border-radius: 10px; margin-bottom: 6px; font-size: 13px; }
        .cvv-num { font-weight: 700; color: #0f172a; min-width: 34px; }
        .cvv-badge { font-size: 11px; font-weight: 700; padding: 2px 9px; border-radius: 999px; }
        .cvv-badge.b { background: #fef9c3; color: #a16207; }
        .cvv-badge.p { background: #dcfce7; color: #15803d; }
        .cvv-badge.r { background: #f1f5f9; color: #64748b; }
        .cvv-meta { color: #64748b; font-size: 12px; flex: 1; }
        .cvv-vacio { padding: 16px; text-align: center; color: #94a3b8; font-size: 13px; }
        .cvv-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 16px; padding-top: 14px; border-top: 1px solid #e5e7eb; }
    </style>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <div class="cvv-cab">
        <div>
            <div class="cvv-cod"><asp:Literal ID="litCodigo" runat="server" /></div>
            <div class="cvv-nom"><asp:Literal ID="litNombre" runat="server" /></div>
        </div>
    </div>

    <%-- Publicar el borrador --%>
    <asp:Panel ID="pnlPublicar" runat="server" CssClass="cvv-pub" Visible="false">
        <div class="t"><i class="mdi mdi-publish"></i> Publicar la versión en borrador</div>
        <span class="sigma-modal-ayuda">Al publicar, esta versión queda vigente y la publicada anterior pasa a <b>retirada</b>. Queda registrado quién la publicó y cuándo. No se puede publicar una versión sin ítems.</span>
        <div style="margin-top:8px;">
            <asp:TextBox ID="txtObservacion" runat="server" TextMode="MultiLine" placeholder="Observación de la publicación (opcional)…" />
        </div>
        <div style="margin-top:10px;">
            <WebControls:PushButton ID="btnPublicar" runat="server" Text="Publicar versión en borrador" OnClick="btnPublicar_Click"
                OnClientClick="return ConfirSweetAlert(this, '', '¿Publicar la versión en borrador? La publicada anterior pasará a retirada.');" />
        </div>
    </asp:Panel>

    <asp:Panel ID="pnlSinBorrador" runat="server" CssClass="cvv-pub" Visible="false">
        <div class="t"><i class="mdi mdi-information-outline"></i> Sin versión en borrador</div>
        <span class="sigma-modal-ayuda">Esta pauta no tiene una versión en borrador para publicar. Para cambiarla, edítela: al guardar sus campos se abre un nuevo borrador.</span>
    </asp:Panel>

    <%-- Historial de versiones --%>
    <div class="cvv-hist-t">Historial de versiones</div>
    <asp:Repeater ID="rptVersiones" runat="server" OnItemDataBound="rptVersiones_ItemDataBound">
        <ItemTemplate>
            <div class="cvv-row">
                <span class="cvv-num">v<%# Eval("cpv_numero") %></span>
                <span class='<%# "cvv-badge " + EstadoClase((int)Eval("cpv_estado")) %>'><%# Eval("estado_nombre") %></span>
                <span class="cvv-meta"><asp:Literal ID="litMeta" runat="server" /></span>
            </div>
        </ItemTemplate>
    </asp:Repeater>
    <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="cvv-vacio">Esta pauta todavía no tiene versiones.</asp:Panel>

    <div class="cvv-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
