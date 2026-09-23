<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="PlanOcurrenciaReprogramar.aspx.cs" Inherits="View_Mantenimiento_Planes_PlanOcurrenciaReprogramar" %>

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
        .por-cab { padding-bottom: 14px; border-bottom: 1px solid #e5e7eb; margin-bottom: 16px; }
        .por-cod { font-size: 11px; font-weight: 700; letter-spacing: .04em; color: #6C5CFF; text-transform: uppercase; }
        .por-nom { margin: 2px 0 0; font-size: 20px; font-weight: 700; color: #111827; }
        .por-datos { display: grid; grid-template-columns: 1fr 1fr; gap: 10px 18px; margin-bottom: 16px; }
        .por-item { font-size: 13px; }
        .por-item .k { color: #64748b; font-size: 11.5px; text-transform: uppercase; letter-spacing: .03em; }
        .por-item .v { color: #0f172a; font-weight: 600; }
        .por-box { border: 1px solid #e5e7eb; border-radius: 10px; padding: 12px 14px; background: #fafbfc; margin-bottom: 16px; }
        .por-box .t { font-weight: 700; color: #0f172a; font-size: 13.5px; margin-bottom: 6px; }
        .por-box input[type=date] { padding: 8px 10px; border: 1px solid #e5e7eb; border-radius: 9px; font-size: 13px; font-family: inherit; }
        .por-box textarea { width: 100%; box-sizing: border-box; padding: 8px 10px; border: 1px solid #e5e7eb; border-radius: 9px; font-size: 13px; min-height: 54px; font-family: inherit; margin-top: 8px; }
        .por-ok { border: 1px solid #bbf7d0; background: #f0fdf4; border-radius: 10px; padding: 12px 14px; margin-bottom: 16px; }
        .por-ok .t { font-weight: 700; color: #15803d; font-size: 13.5px; margin-bottom: 4px; }
        .por-ok .m { color: #166534; font-size: 13px; }
        .por-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 16px; padding-top: 14px; border-top: 1px solid #e5e7eb; }
    </style>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <div class="por-cab">
        <div class="por-cod"><asp:Literal ID="litActivo" runat="server" /></div>
        <div class="por-nom"><asp:Literal ID="litPlan" runat="server" /></div>
    </div>

    <div class="por-datos">
        <div class="por-item"><div class="k">Hito</div><div class="v"><asp:Literal ID="litHito" runat="server" /></div></div>
        <div class="por-item"><div class="k">Estado</div><div class="v"><asp:Literal ID="litEstado" runat="server" /></div></div>
        <div class="por-item"><div class="k">Fecha programada</div><div class="v"><asp:Literal ID="litFecha" runat="server" /></div></div>
        <div class="por-item"><div class="k">Fecha original</div><div class="v"><asp:Literal ID="litOriginal" runat="server" /></div></div>
    </div>

    <%-- Ya fue reprogramada: se muestra el resultado --%>
    <asp:Panel ID="pnlResultado" runat="server" CssClass="por-ok" Visible="false">
        <div class="t"><i class="mdi mdi-check-circle-outline"></i> Ocurrencia reprogramada</div>
        <div class="m"><asp:Literal ID="litResultado" runat="server" /></div>
    </asp:Panel>

    <%-- Reprogramar (solo si está pendiente/disponible y hay permiso) --%>
    <asp:Panel ID="pnlForm" runat="server" CssClass="por-box" Visible="false">
        <div class="t"><i class="mdi mdi-calendar-edit"></i> Reprogramar a una nueva fecha</div>
        <span class="sigma-modal-ayuda">La ocurrencia actual queda como <b>reprogramada</b> (con el motivo) y se crea una nueva en la fecha que indique. Queda registrado quién y cuándo.</span>
        <div style="margin-top:10px;">
            <label style="display:block; font-size:12px; color:#64748b; margin-bottom:4px;">Nueva fecha(*)</label>
            <asp:TextBox ID="txtFecha" runat="server" TextMode="Date" />
        </div>
        <asp:TextBox ID="txtMotivo" runat="server" TextMode="MultiLine" placeholder="Motivo de la reprogramación (obligatorio)…" />
        <div style="margin-top:10px;">
            <WebControls:PushButton ID="btnReprogramar" runat="server" Text="Reprogramar" OnClick="btnReprogramar_Click"
                OnClientClick="return ConfirSweetAlert(this, '', '¿Reprogramar esta ocurrencia? La actual quedará como reprogramada.');" />
        </div>
    </asp:Panel>

    <asp:Panel ID="pnlBloqueada" runat="server" CssClass="por-box" Visible="false">
        <div class="t"><i class="mdi mdi-information-outline"></i> No se puede reprogramar</div>
        <span class="sigma-modal-ayuda"><asp:Literal ID="litBloqueada" runat="server" /></span>
    </asp:Panel>

    <div class="por-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
