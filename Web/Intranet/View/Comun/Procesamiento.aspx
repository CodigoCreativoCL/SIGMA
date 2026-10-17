<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Procesamiento.aspx.cs" Inherits="View_Comun_Procesamiento" %>

<asp:Content ID="Content2" ContentPlaceHolderID="cphHeder" runat="server">
   
</asp:Content>

<asp:Content ID="ContenHead" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript" language="javascript">
        //Cierra el RadWindow"
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow)
                oWindow = window.radWindow;
            else if (window.frameElement.radWindow)
                oWindow = window.frameElement.radWindow;
            return oWindow;
        }

        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refreshReuniones) window.BrowserWindow.refreshReuniones();
            window.close();
        }

        $(document).ready(function() {

            setInterval(Segundos, 1000);
                  

            function Minutos() {

                var lblMinutos = $('#<%=lblMinutos.ClientID %>');

                var Minutos = parseInt(lblMinutos.html()) + 1;

                lblMinutos.html(Minutos);
            }

            function Segundos() {

                var lblSegundos = $('#<%=lblSegundos.ClientID %>');

                var segundos = parseInt(lblSegundos.html()) + 1;

                if (segundos > 59) {
                    lblSegundos.html('0');

                    Minutos();

                }
                else
                {
                    lblSegundos.html(segundos);
                }

            }

        });
    </script>
</asp:Content>

<asp:Content ID="Content1" ContentPlaceHolderID="cphBody" Runat="Server">

    <style>
        .proc { min-height: 70vh; display: grid; place-content: center; justify-items: center; gap: 14px; padding: 32px 24px; text-align: center; font-family: "Inter", "Segoe UI", Arial, sans-serif; }
        .proc-anillo { width: 56px; height: 56px; border: 5px solid #F2EFFF; border-top-color: #6732F4; border-radius: 50%; animation: proc-giro .9s linear infinite; }
        .proc h2 { margin: 0; font-size: 17px; font-weight: 800; color: #17223B; }
        .proc p { margin: 0; max-width: 360px; font-size: 13px; line-height: 1.5; color: #68738A; }
        .proc-tiempo { display: inline-flex; align-items: baseline; gap: 6px; padding: 10px 16px; border: 1px solid #E2E7F0; border-radius: 12px; background: #fff; color: #17223B; font-size: 12px; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; }
        .proc-tiempo b { font-size: 22px; letter-spacing: 0; font-variant-numeric: tabular-nums; }
        .proc-tiempo span { color: #68738A; font-weight: 700; text-transform: none; letter-spacing: 0; font-size: 12px; margin-right: 6px; }
        @keyframes proc-giro { to { transform: rotate(360deg); } }
        @media (prefers-reduced-motion: reduce) { .proc-anillo { animation-duration: 2.4s; } }
    </style>

    <div class="proc" role="status" aria-live="polite">
        <div class="proc-anillo" aria-hidden="true"></div>
        <h2>Procesando la planilla</h2>
        <p>Este proceso puede durar varios minutos. Puede dejar esta ventana abierta mientras termina.</p>
        <div class="proc-tiempo">
            Tiempo transcurrido
            <b><asp:Label ID="lblMinutos" runat="server" Text="0" /></b><span>min</span>
            <b><asp:Label ID="lblSegundos" runat="server" Text="0" /></b><span>s</span>
        </div>
    </div>
</asp:Content>
