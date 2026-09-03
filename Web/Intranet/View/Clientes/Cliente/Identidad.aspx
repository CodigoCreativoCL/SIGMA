<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Identidad.aspx.cs" Inherits="View_Clientes_Cliente_Identidad" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-ficha-cliente.css?vrs=3") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Clientes
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Identidad
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Ficha corporativa y configuración general del cliente.
</asp:Content>

<%-- ============================================================
     DOS COSAS QUE ESTA PANTALLA YA NO HACE
     ============================================================

     1. NO TRAE SU PROPIO SELECTOR DE CLIENTE

        Tenia un combo en `cphComboCliente`, ademas del selector global que
        el Master muestra arriba a la derecha (HU-002). Dos selectores para
        lo mismo, en la misma pantalla, y nada garantizaba que dijeran
        igual: se podia estar viendo la ficha de una empresa mientras el
        resto del sitio trabajaba con otra.

        Ahora lee el cliente de la SESION, que es el que fija el selector
        global. Se revisaron las referencias antes de sacarlo:
        `wucCliente.GetCliente()` se usaba solo en el Page_PreRender de esta
        pagina. No queda ninguna referencia al control eliminado.

     2. NO EDITA

        Este menu es del CLIENTE mirando su propia ficha: es informativo.
        Editar la identidad —razon social, RUT, pais— es una operacion de
        administracion y vive en su mantenedor, con su permiso. Dejar aca un
        boton de editar seria ofrecer una accion que esta pantalla no deberia
        tener.

        Por eso tampoco se registra `Identidad.ascx`: sin modo edicion, no
        hace falta.
     ============================================================ --%>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>

    <div class="sg-ficha">

        <div class="sg-fc-cab">
            <div class="sg-fc-cab-txt">
                <h1 class="sg-fc-titulo">
                    <asp:Literal ID="litTitulo" runat="server" />
                    <asp:Literal ID="litEstadoChip" runat="server" />
                </h1>

                <p class="sg-fc-bajada">Ficha corporativa y configuración general del cliente.</p>

                <div class="sg-fc-meta"><asp:Literal ID="litMeta" runat="server" /></div>
            </div>
        </div>

        <asp:Panel ID="pnlFicha" runat="server">

            <%-- ------------------------------------------------------
                 TARJETA PRINCIPAL
                 ------------------------------------------------------ --%>
            <div class="sg-fc-hero">
                <div class="sg-fc-hero-datos">
                    <div class="sg-fc-logo">
                        <asp:Image ID="imgLogo" runat="server" AlternateText="Logotipo del cliente" />
                        <asp:Literal ID="litLogoVacio" runat="server" />
                    </div>

                    <div class="sg-fc-hero-txt">
                        <div class="sg-fc-hero-nombre"><asp:Literal ID="litNombre" runat="server" /></div>
                        <div class="sg-fc-campos"><asp:Literal ID="litHeroCampos" runat="server" /></div>
                        <div class="sg-fc-chips"><asp:Literal ID="litChips" runat="server" /></div>
                    </div>
                </div>

                <%-- Los tres numeros salen de contar: cuantas personas y
                     cuantas instalaciones tiene, y si la configuracion
                     regional esta completa. Ninguno esta escrito a mano. --%>
                <div class="sg-fc-cifras"><asp:Literal ID="litCifras" runat="server" /></div>
            </div>

            <%-- ------------------------------------------------------
                 PESTAÑAS

                 Son <a> normales, no botones de servidor: las CINCO se
                 renderizan y el navegador muestra una. Cambiar de pestaña es
                 mirar otra parte de lo mismo, no una consulta nueva, y
                 hacerlo con un viaje al servidor se sentia lento sin motivo.
                 ------------------------------------------------------ --%>
            <div class="sg-fc-tabs" role="tablist">
                <a href="#" class="sg-fc-tab is-activa" data-tab="RESUMEN" role="tab">
                    <i class="mdi mdi-view-list-outline"></i><span>Resumen</span></a>
                <a href="#" class="sg-fc-tab" data-tab="LEGAL" role="tab">
                    <i class="mdi mdi-bank-outline"></i><span>Identidad legal</span></a>
                <a href="#" class="sg-fc-tab" data-tab="CONTACTO" role="tab">
                    <i class="mdi mdi-card-account-mail-outline"></i><span>Contacto</span></a>
                <a href="#" class="sg-fc-tab" data-tab="CONFIG" role="tab">
                    <i class="mdi mdi-cog-outline"></i><span>Configuración</span></a>
                <a href="#" class="sg-fc-tab" data-tab="AUDITORIA" role="tab">
                    <i class="mdi mdi-shield-check-outline"></i><span>Auditoría</span></a>
            </div>

            <div class="sg-fc-paneles">
                <div class="sg-fc-panel is-activo" data-panel="RESUMEN">
                    <div class="sg-fc-cuerpo">
                        <div class="sg-fc-col"><asp:Literal ID="litResumenIzq" runat="server" /></div>
                        <div class="sg-fc-col"><asp:Literal ID="litResumenDer" runat="server" /></div>
                        <aside class="sg-fc-lateral"><asp:Literal ID="litLateral" runat="server" /></aside>
                    </div>
                </div>

                <div class="sg-fc-panel" data-panel="LEGAL">
                    <div class="sg-fc-cuerpo">
                        <div class="sg-fc-col"><asp:Literal ID="litLegal" runat="server" /></div>
                        <div class="sg-fc-col"><asp:Literal ID="litLegalDer" runat="server" /></div>
                        <aside class="sg-fc-lateral"><asp:Literal ID="litLateral2" runat="server" /></aside>
                    </div>
                </div>

                <div class="sg-fc-panel" data-panel="CONTACTO">
                    <div class="sg-fc-cuerpo">
                        <div class="sg-fc-col"><asp:Literal ID="litContacto" runat="server" /></div>
                        <div class="sg-fc-col"><asp:Literal ID="litComercial" runat="server" /></div>
                        <aside class="sg-fc-lateral"><asp:Literal ID="litLateral3" runat="server" /></aside>
                    </div>
                </div>

                <div class="sg-fc-panel" data-panel="CONFIG">
                    <div class="sg-fc-cuerpo">
                        <div class="sg-fc-col"><asp:Literal ID="litRegional" runat="server" /></div>
                        <div class="sg-fc-col"><asp:Literal ID="litEstado" runat="server" /></div>
                        <aside class="sg-fc-lateral"><asp:Literal ID="litLateral4" runat="server" /></aside>
                    </div>
                </div>

                <div class="sg-fc-panel" data-panel="AUDITORIA">
                    <div class="sg-fc-cuerpo">
                        <div class="sg-fc-col"><asp:Literal ID="litAuditoria" runat="server" /></div>
                        <div class="sg-fc-col"></div>
                        <aside class="sg-fc-lateral"><asp:Literal ID="litLateral5" runat="server" /></aside>
                    </div>
                </div>
            </div>

        </asp:Panel>
    </div>

    </ContentTemplate>
</asp:UpdatePanel>

</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/gsap/gsap.min.js") %>'></script>

    <script type="text/javascript">
        /* Las pestañas, en el navegador.

           Los cinco paneles ya están en el HTML: cambiar de pestaña es
           mostrar otro, no volver a preguntarle al servidor lo mismo. */
        (function () {
            'use strict';

            function conectar() {
                var tabs = document.querySelectorAll('.sg-fc-tab');
                var paneles = document.querySelectorAll('.sg-fc-panel');

                if (!tabs.length) return;

                function abrir(codigo) {
                    var i;

                    for (i = 0; i < tabs.length; i++)
                        tabs[i].className = 'sg-fc-tab' +
                            (tabs[i].getAttribute('data-tab') === codigo ? ' is-activa' : '');

                    for (i = 0; i < paneles.length; i++) {
                        var activo = paneles[i].getAttribute('data-panel') === codigo;
                        paneles[i].className = 'sg-fc-panel' + (activo ? ' is-activo' : '');

                        if (activo && window.gsap)
                            gsap.fromTo(paneles[i], { opacity: 0, y: 8 },
                                { opacity: 1, y: 0, duration: .25, ease: 'power2.out',
                                  clearProps: 'transform,opacity' });
                    }
                }

                for (var i = 0; i < tabs.length; i++) {
                    (function (t) {
                        t.onclick = function (ev) {
                            ev.preventDefault();
                            abrir(t.getAttribute('data-tab'));
                            return false;
                        };
                    })(tabs[i]);
                }
            }

            if (document.readyState === 'loading')
                document.addEventListener('DOMContentLoaded', conectar);
            else
                conectar();

            /* Si algo del sitio provoca un refresco parcial, el HTML es nuevo
               y los manejadores se fueron con el anterior. */
            if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
                Sys.WebForms.PageRequestManager.getInstance().add_endRequest(conectar);
        })();
    </script>
</asp:Content>
