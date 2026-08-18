<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="LogAppDetalle.aspx.cs" Inherits="View_Root_LogSistema_LogAppDetalle" %>

<asp:Content ID="cntHeader" ContentPlaceHolderID="cphHeder" runat="server">
    <style>
        .det-label  { font-size: .72rem; font-weight: 700; text-transform: uppercase;
                      letter-spacing: .4px; color: #94a3b8; }
        .det-value  { font-size: .88rem; color: #1e293b; word-break: break-all; }
        .det-row    { margin-bottom: 10px; }
        .badge-err  { background: #fce7f3; color: #be185d;
                      padding: 3px 10px; border-radius: 12px; font-size: .8rem; font-weight: 600; }
        .badge-ok   { background: #dcfce7; color: #15803d;
                      padding: 3px 10px; border-radius: 12px; font-size: .8rem; font-weight: 600; }
        .badge-met  { background: #e0e7ff; color: #3730a3;
                      padding: 3px 10px; border-radius: 12px; font-size: .8rem; font-weight: 600; }
        .json-box   { font-family: 'Courier New', monospace; font-size: .78rem;
                      background: #f8fafc; border: 1px solid #e2e8f0;
                      border-radius: 6px; padding: 8px; resize: vertical; }
    </style>
    <script type="text/javascript">
        function getRadWindow() { 
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement && window.frameElement.radWindow)
                oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var win = getRadWindow();
            if (win) win.close();
        }
    </script>
</asp:Content>

<asp:Content ID="cntBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="SubTitulos">Detalle Log Endpoint &mdash; API Control Transporte</div>

            <div class="row col-lg-12" style="margin-top:12px;">

                <%-- Fila 1: ID · Método · Error · Duración --%>
                <div class="col-lg-2 col-md-3 col-xs-6 det-row">
                    <div class="det-label">ID</div>
                    <div class="det-value"><asp:Label ID="lblId" runat="server" /></div>
                </div>
                <div class="col-lg-2 col-md-3 col-xs-6 det-row">
                    <div class="det-label">M&eacute;todo</div>
                    <div class="det-value"><asp:Literal ID="litMetodo" runat="server" /></div>
                </div>
                <div class="col-lg-2 col-md-3 col-xs-6 det-row">
                    <div class="det-label">Error</div>
                    <div class="det-value"><asp:Literal ID="litError" runat="server" /></div>
                </div>
                <div class="col-lg-2 col-md-3 col-xs-6 det-row">
                    <div class="det-label">Duraci&oacute;n (ms)</div>
                    <div class="det-value"><asp:Label ID="lblDuracion" runat="server" /></div>
                </div>
                <div class="col-lg-2 col-md-3 col-xs-6 det-row">
                    <div class="det-label">IP</div>
                    <div class="det-value"><asp:Label ID="lblIp" runat="server" /></div>
                </div>
                <div class="col-lg-2 col-md-3 col-xs-6 det-row">
                    <div class="det-label">Fecha</div>
                    <div class="det-value"><asp:Label ID="lblFecha" runat="server" /></div>
                </div>

                <%-- Endpoint --%>
                <div class="col-lg-8 col-md-8 col-xs-12 det-row">
                    <div class="det-label">Endpoint</div>
                    <div class="det-value"><asp:Label ID="lblEndpoint" runat="server" /></div>
                </div>

                <%-- Nombre usuario --%>
                <div class="col-lg-4 col-md-4 col-xs-12 det-row">
                    <div class="det-label">Usuario</div>
                    <div class="det-value"><asp:Label ID="lblNombreUsuario" runat="server" /></div>
                </div>

                <%-- Usuario JWT --%>
                <div class="col-lg-8 col-md-8 col-xs-12 det-row">
                    <div class="det-label">Identidad JWT</div>
                    <div class="det-value"><asp:Label ID="lblUsuario" runat="server" /></div>
                </div>

                <%-- Mensaje Error (solo si hay error) --%>
                <asp:Panel ID="pnlError" runat="server" Visible="false" CssClass="col-lg-12 col-xs-12 det-row">
                    <div class="det-label">Mensaje Error</div>
                    <div class="det-value" style="color:#be185d;">
                        <asp:Label ID="lblMensajeError" runat="server" />
                    </div>
                </asp:Panel>

                <%-- Stack Trace (solo si hay error no capturado) --%>
                <asp:Panel ID="pnlStack" runat="server" Visible="false" CssClass="col-lg-12 col-xs-12 det-row">
                    <div class="det-label">Stack Trace</div>
                    <asp:TextBox ID="txtStackTrace" runat="server" TextMode="MultiLine"
                        Rows="4" Width="100%" ReadOnly="true" CssClass="json-box" />
                </asp:Panel>

                <%-- Request JSON --%>
                <div class="col-lg-12 col-xs-12 det-row">
                    <div class="det-label">Request (argumentos)</div>
                    <asp:TextBox ID="txtRequest" runat="server" TextMode="MultiLine"
                        Rows="6" Width="100%" ReadOnly="true" CssClass="json-box" />
                </div>

                <%-- Response JSON --%>
                <div class="col-lg-12 col-xs-12 det-row">
                    <div class="det-label">Response</div>
                    <asp:TextBox ID="txtResponse" runat="server" TextMode="MultiLine"
                        Rows="8" Width="100%" ReadOnly="true" CssClass="json-box" />
                </div>

            </div>

            <div class="col-lg-12 col-md-12 col-xs-12 form-col-center" style="margin-top:12px;">
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar"
                    CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
