<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Filtro.ascx.cs" Inherits="View_Comun_Controls_Filtro" %>

<style>
    /* Barra de filtro simple, estilo "M3 Expressive" */
    .filtro-bar {
        display: flex;
        align-items: center;
        gap: 12px;
        width: 100%;
    }

        .filtro-bar .filtro-bar-input {
            flex: 1 1 auto;
        }

        .filtro-bar .filtro-bar-boton {
            flex: 0 0 auto;
        }
</style>

<div class="row card-box filtro">
    <div class="filtro-bar">
        <div class="filtro-bar-input">
            <WebControls:TextBox2 ID="txtFiltro" runat="server" Width="100%" placeholder="Buscar..." />
        </div>
        <div class="filtro-bar-boton">
            <WebControls:PushButton ID="btnFiltrar" runat="server" Text="Buscar" CssClass="ButtonFilter"
                CausesValidation="false" />
        </div>
    </div>
</div>
