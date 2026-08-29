<%@ Control Language="C#" AutoEventWireup="true" CodeFile="FiltroAvanzado.ascx.cs" Inherits="Comun_Controls_FiltroAvanzado" %>
<script>
    function fnExpandeFiltro(ObjdivPersonalizado, ObjhdfExpanded) {
        var hdfExpanded = $("#" + ObjhdfExpanded);
        if (hdfExpanded.val() == '0') {
            hdfExpanded.val('1')
        }
        else {
            hdfExpanded.val('0')
        }
        expandeFiltro(false, ObjdivPersonalizado, ObjhdfExpanded);
    }

    function expandeFiltro(isPostback, ObjdivPersonalizado, ObjhdfExpanded) {
        var hdfExpanded = $("#" + ObjhdfExpanded);
        var divPersonalizado = $("#" + ObjdivPersonalizado);

        if (hdfExpanded.val() == '1') {
            if (isPostback)
                divPersonalizado.show();
            else
                divPersonalizado.show(500);
        }
        else {
            divPersonalizado.hide(500);
        }
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
            <a class="filtroToggle" role="button" data-toggle="collapse"
                href="#buscador" aria-expanded="true" aria-controls="buscador"
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
