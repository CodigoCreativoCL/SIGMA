<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ChecklistPlantillaVista.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistPlantillaVista" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function cerrarVista() { var w = getRadWindow(); w.close(); }
    </script>
    <style type="text/css">
        .clv-cab { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; padding-bottom: 14px; border-bottom: 1px solid #e5e7eb; margin-bottom: 16px; }
        .clv-cod { font-size: 11px; font-weight: 700; letter-spacing: .04em; color: #6C5CFF; text-transform: uppercase; }
        .clv-nom { margin: 2px 0 4px; font-size: 20px; font-weight: 700; color: #111827; }
        .clv-desc { margin: 0; font-size: 13px; color: #6b7280; max-width: 70ch; }
        .clv-meta { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 8px; }
        .clv-chip { font-size: 11px; padding: 3px 9px; border-radius: 999px; background: #f1f5f9; color: #334155; }
        .clv-chip b { color: #0f172a; }
        .clv-sec { border: 1px solid #e5e7eb; border-radius: 10px; margin-bottom: 12px; overflow: hidden; }
        .clv-sec-cab { display: flex; align-items: center; gap: 8px; padding: 9px 12px; background: #eee9fe; font-weight: 700; color: #0f172a; font-size: 13.5px; }
        .clv-sec-cab .n { margin-left: auto; font-size: 11px; font-weight: 600; color: #6C5CFF; background: #fff; border-radius: 999px; padding: 1px 9px; }
        .clv-item { display: flex; align-items: center; gap: 10px; padding: 8px 14px; border-top: 1px solid #f1f5f9; font-size: 13px; }
        .clv-item .tx { flex: 1; color: #253149; }
        .clv-tipo { font-size: 11px; padding: 2px 8px; border-radius: 6px; background: #eef2ff; color: #4338ca; white-space: nowrap; }
        .clv-req { font-size: 11px; color: #b91c1c; font-weight: 700; }
        .clv-vacio { padding: 18px; text-align: center; color: #94a3b8; font-size: 13px; }
        .clv-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 16px; padding-top: 14px; border-top: 1px solid #e5e7eb; }
        .clv-btn { display: inline-flex; align-items: center; gap: 6px; padding: 9px 18px; border-radius: 10px; font-size: 13px; font-weight: 600; cursor: pointer; text-decoration: none; }
        .clv-btn.cerrar { background: #fff; color: #374151; border: 1px solid #e5e7eb; }
        .clv-btn.editar { background: #6C5CFF; color: #fff; }
    </style>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <div class="clv-cab">
        <div>
            <div class="clv-cod"><asp:Literal ID="litCodigo" runat="server" /></div>
            <div class="clv-nom"><asp:Literal ID="litNombre" runat="server" /></div>
            <p class="clv-desc"><asp:Literal ID="litDescripcion" runat="server" /></p>
            <div class="clv-meta"><asp:Literal ID="litMeta" runat="server" /></div>
        </div>
    </div>

    <asp:Literal ID="litEstructura" runat="server" />

    <div class="clv-actions">
        <a href="javascript:void(0)" class="clv-btn cerrar" onclick="cerrarVista()">Cerrar</a>
        <asp:HyperLink ID="lnkEditar" runat="server" CssClass="clv-btn editar" NavigateUrl="javascript:void(0)">Editar</asp:HyperLink>
    </div>
</div>
</asp:Content>
