<%@ Control Language="C#" AutoEventWireup="true" CodeFile="FiltroAvanzado.ascx.cs" Inherits="Comun_Controls_FiltroAvanzado" %>
<script>
    /* ========================================================================
       EL FILTRO AVANZADO SE ABRE Y SE CIERRA

       LA FUENTE DE VERDAD ES EL DOM

         Antes el estado vivia solo en un campo oculto y la funcion decidia
         segun ese flag. Si el flag y lo que se ve se desincronizaban, un clic
         hacia lo contrario de lo esperado. Ahora se pregunta si el panel esta
         visible: eso no se puede desincronizar de si mismo. El campo oculto
         se sigue escribiendo, pero solo para que el estado sobreviva al
         postback, no para decidir.

       LA ANIMACION MIDE, NO ADIVINA

         Se anima la ALTURA desde 0 hasta la que el panel realmente ocupa
         —`scrollHeight`—, no hasta un valor fijo. Un alto escrito a mano se
         rompe en cuanto una pantalla agrega un campo mas.

       Y TERMINA EN `display:none`

         Al cerrar, la animacion deja el panel realmente oculto y le borra los
         estilos que uso para animar. Si quedara en `height:0` pero visible,
         seguiria ocupando su margen y recibiendo el foco con el tabulador.
       ======================================================================== */
    function sgFiltroAnimable() {
        return window.gsap &&
               !(window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches);
    }

    function sgFiltroAbrir(div) {
        div.style.display = '';

        if (!sgFiltroAnimable()) return;

        gsap.killTweensOf(div);

        /* Se mide con el panel ya visible: con display:none, scrollHeight es 0
           y la animacion no tendria hacia donde crecer. */
        var alto = div.scrollHeight;

        gsap.fromTo(div,
            { height: 0, opacity: 0, overflow: 'hidden' },
            {
                height: alto,
                opacity: 1,
                duration: 0.3,
                ease: 'power2.out',
                /* Se sueltan las propiedades al terminar: si quedara un alto
                   fijo, el panel no crecería al abrir un combo largo. */
                clearProps: 'height,opacity,overflow'
            });

        var campos = div.querySelectorAll('.RadComboBox, input, label, .sigma-modal-fecha');

        if (campos.length) {
            gsap.fromTo(campos,
                { opacity: 0, y: -6 },
                { opacity: 1, y: 0, duration: 0.24, stagger: 0.02, delay: 0.05,
                  ease: 'power2.out', clearProps: 'transform,opacity' });
        }
    }

    function sgFiltroCerrar(div) {
        if (!sgFiltroAnimable()) {
            div.style.display = 'none';
            return;
        }

        gsap.killTweensOf(div);

        gsap.to(div, {
            height: 0,
            opacity: 0,
            overflow: 'hidden',
            duration: 0.22,
            ease: 'power2.in',
            onComplete: function () {
                div.style.display = 'none';
                gsap.set(div, { clearProps: 'height,opacity,overflow' });
            }
        });
    }

    function fnExpandeFiltro(ObjdivPersonalizado, ObjhdfExpanded) {
        var div = document.getElementById(ObjdivPersonalizado);
        var hdf = document.getElementById(ObjhdfExpanded);

        if (!div) return false;

        /* Se mira la pantalla, no el flag. */
        var abierto = div.style.display !== 'none' && div.offsetHeight > 0;

        if (abierto) sgFiltroCerrar(div);
        else sgFiltroAbrir(div);

        if (hdf) hdf.value = abierto ? '0' : '1';

        var enlace = document.querySelector('.filtroToggle');

        if (enlace) enlace.setAttribute('aria-expanded', abierto ? 'false' : 'true');

        return false;
    }

    /* Al volver de un postback se restaura lo que habia, SIN animar: la
       animacion es la respuesta a un clic, y repetirla en cada busqueda la
       convierte en ruido. */
    function expandeFiltro(isPostback, ObjdivPersonalizado, ObjhdfExpanded) {
        var div = document.getElementById(ObjdivPersonalizado);
        var hdf = document.getElementById(ObjhdfExpanded);

        if (!div || !hdf) return;

        var abrir = hdf.value === '1';

        div.style.display = abrir ? '' : 'none';

        if (window.gsap) gsap.set(div, { clearProps: 'height,opacity,overflow' });

        var enlace = document.querySelector('.filtroToggle');

        if (enlace) enlace.setAttribute('aria-expanded', abrir ? 'true' : 'false');
    }
</script>

<style>
    .filtro {
        margin-bottom: 4px;
        padding: 10px 5px;
    }

    .filtroBusqueda {
        padding: 8px;
    }



    .filtroToggle {
        display: inline-flex;
        align-items: center;
        white-space: nowrap;
        gap: 6px;
        padding: 8px 14px;
        background: var(--fg-m3-chip-bg);
        border: 1px solid var(--fg-m3-outline);
        border-radius: var(--fg-m3-radius-pill);
        color: var(--fg-m3-primary) !important;
        font-size: 12px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: .3px;
        text-decoration: none !important;
        transition: background-color 150ms ease, border-color 150ms ease;
    }

        .filtroToggle:hover {
            background: var(--fg-m3-primary-container);
            border-color: var(--fg-m3-primary);
        }

        .filtroToggle .fa {
            font-size: 12px;
        }

    .filtroPersonalizado {
        margin-right: 5px;
        padding-right: 1px !important;
        border-top: 1px dashed var(--fg-m3-outline);
    }
</style>

<div class="row card-box filtro mb-2">
    <div class="row col-lg-12 col-md-12 col-xs-12" style="margin-left: 0px;">
        <div class="col-auto filtroBusqueda">
            <%-- SIN data-toggle="collapse".

                 Tenia DOS mecanismos de apertura peleando: el collapse de
                 Bootstrap y el onclick propio. Al hacer clic, uno cerraba el
                 panel y el otro lo volvia a abrir, asi que no habia forma de
                 cerrarlo.

                 Queda el propio, que ademas guarda el estado en el campo
                 oculto —el collapse de Bootstrap no sobrevive al postback y
                 el filtro se cerraba solo al buscar—.

                 `href="#buscador"` tambien se va: apuntaba a un id que no
                 existe en este control y hacia saltar la pagina al tope. --%>
            <a class="filtroToggle" role="button" href="javascript:void(0)"
                aria-expanded="false" aria-controls="<%=divPersonalizado.ClientID %>"
                onclick="fnExpandeFiltro('<%=divPersonalizado.ClientID %>', '<%=hdfExpanded.ClientID %>')">
                <span class="mdi mdi-filter-variant"></span>Busqueda Avanzada
                    <asp:HiddenField ID="hdfExpanded" runat="server" Value="0" />
            </a>
        </div>
        <div class="col">
            <WebControls:TextBox2 ID="txtFiltro" runat="server" Width="100%" placeholder="Buscar..." />
        </div>
        <div class="col-auto">
            <WebControls:PushButton ID="btnFiltrar" CssClass="ButtonFilter" runat="server" Text="Buscar" CausesValidation="false" />
        </div>
    </div>
    <div id="divPersonalizado" runat="server" class="row col-lg-12 col-md-12 col-xs-12 filtroPersonalizado" style="display: none;">
        <asp:PlaceHolder ID="phPersonalizado" runat="server"></asp:PlaceHolder>
    </div>
</div>
