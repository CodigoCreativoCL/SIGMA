<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Comun_Procesamiento, App_Web_cyyn5nr0" %>

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
        .proceso-container {
            text-align: center;
            padding: 40px 20px;
        }

        .proceso-mensaje {
            margin-top: 20px;
            font-size: 15px;
            font-weight: 600;
            color: var(--fg-primary);
        }

        .proceso-tiempo h3 {
            font-size: 12px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: .06em;
            color: var(--fg-outline);
            margin-bottom: 4px;
        }

        .proceso-tiempo p {
            font-size: 16px;
            font-weight: 600;
            color: var(--fg-secondary);
        }
    </style>

    <div class="proceso-container">
        <div>
            <center>
                <asp:Image ID="imgProcesamiento" runat="server" ImageUrl="~/Css/AjaxProgress/AjaxProgress.gif" />
            </center>
        </div>
        <div class="proceso-mensaje">
            Este Proceso puede durar varios minutos, porfavor espere...
        </div>
        <br />
        <div class="proceso-tiempo">
            <h3>Tiempo Trascurrido:</h3>
            <p>Minutos   <asp:Label ID="lblMinutos" runat="server" Text="0 "/>  Segundos   <asp:Label ID="lblSegundos" runat="server" Text="0 " /></p>
        </div>
    </div>
</asp:Content>

