<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Adjunto.ascx.cs" Inherits="Comun_Controls_Adjunto" %>

<%-- ============================================================
     EL DOCUMENTO ADJUNTO DE CUALQUIER FICHA

     Todo módulo que adjunta algo necesita lo mismo: verlo, bajarlo,
     y —cuando todavía no hay nada— poder subirlo o que se explique
     por qué no se puede. Escrito una vez, no en cada ficha.

     Los tres estados son excluyentes y los decide el code-behind:
       1. Tiene archivo   -> nombre, peso, Ver y Descargar
       2. No tiene, y se puede subir -> el selector de archivo
       3. No tiene, y no se puede    -> el motivo, con todas sus letras
     ============================================================ --%>

<div class="sigma-adjunto">

    <asp:Panel ID="pnlTiene" runat="server" Visible="false" CssClass="sigma-adjunto-archivo">
        <span class="icono"><i class="mdi mdi-file-document-outline"></i></span>

        <span class="texto">
            <span class="nombre"><asp:Literal ID="litNombre" runat="server" /></span>
            <span class="meta"><asp:Literal ID="litMeta" runat="server" /></span>
        </span>

        <span class="acciones">
            <%-- Ver abre en pestaña nueva y NO hace postback: un target
                 _blank desde un LinkButton pierde el postback y no abre
                 nada. Es un enlace de verdad. --%>
            <asp:HyperLink ID="lnkVer" runat="server" CssClass="sigma-accion"
                Target="_blank" ToolTip="Abrir el documento en una pestaña nueva">
                <i class="mdi mdi-eye-outline"></i><span>Ver</span>
            </asp:HyperLink>

            <asp:HyperLink ID="lnkDescargar" runat="server" CssClass="sigma-accion"
                ToolTip="Guardar el documento">
                <i class="mdi mdi-download"></i><span>Descargar</span>
            </asp:HyperLink>
        </span>
    </asp:Panel>

    <asp:Panel ID="pnlSubir" runat="server" Visible="false">
        <asp:FileUpload ID="fup" runat="server" CssClass="form-control" />
        <span class="sigma-modal-ayuda"><asp:Literal ID="litAyudaSubir" runat="server" /></span>
    </asp:Panel>

    <asp:Panel ID="pnlNoSePuede" runat="server" Visible="false" CssClass="sigma-modal-note">
        <i class="mdi mdi-cloud-off-outline"></i>
        <div><asp:Literal ID="litMotivo" runat="server" /></div>
    </asp:Panel>

    <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="sigma-adjunto-vacio">
        <i class="mdi mdi-file-outline"></i>
        <span>Sin documento adjunto.</span>
    </asp:Panel>

</div>
