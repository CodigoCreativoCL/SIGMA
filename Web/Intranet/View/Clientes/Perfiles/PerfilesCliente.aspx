<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="PerfilesCliente.aspx.cs" Inherits="View_Clientes_Perfiles_PerfilesCliente" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- PERFILES DE LA EMPRESA (bloque 341). El Administrador del Cliente crea los
         perfiles que su empresa usa y decide qué puede hacer cada uno. Pensada
         para alguien que no es informático: el flujo va en pasos, cada opción
         dice qué significa, y las combinaciones imposibles no se pueden marcar
         ("crear y editar" sin "ver", cerrar órdenes en un perfil que solo
         ejecuta). Las reglas igual las valida el SP: la pantalla ayuda, no
         protege. --%>
    <style type="text/css">
        .pc { --sigma-purple:#6732F4; --sigma-purple-dark:#4820C9; --sigma-purple-soft:#F2EFFF;
              --sigma-blue:#087BEA; --sigma-blue-dark:#0565C2; --sigma-blue-soft:#EAF4FF;
              --sigma-cyan:#16C6C9; --sigma-cyan-dark:#007F8A; --sigma-cyan-soft:#E8FBFB;
              --ink:#17223B; --muted:#68738A; --line:#E2E7F0; --surface:#FFFFFF; --canvas:#F4F6FA;
              --success:#16855B; --warning:#B65C00; --danger:#C7352B;
              color: var(--ink); font-size: 13px; }
        .pc *, .pc *::before, .pc *::after { box-sizing: border-box; }
        .pc-card { background: var(--surface); border: 1px solid var(--line); border-radius: 14px;
                   box-shadow: 0 1px 2px rgba(23,34,59,.05); padding: 18px 20px; margin-bottom: 14px; }
        .pc h2 { font-size: 15px; font-weight: 800; margin: 0; color: var(--ink); }
        .pc p { margin: 0; }
        .pc-muted { color: var(--muted); }

        /* ---- botones: el color lo decide la función ---- */
        .pc-btn, a.pc-btn, a.pc-btn:hover, a.pc-btn:focus { display: inline-flex; align-items: center; gap: 6px; justify-content: center;
            min-height: 38px; padding: 8px 16px; border-radius: 10px; border: 1px solid transparent;
            font-size: 13px; font-weight: 700; text-decoration: none; cursor: pointer; white-space: nowrap; transition: background .15s; }
        .pc-btn i { font-size: 16px; }
        .pc-btn.es-primario { background: var(--sigma-purple); color: #fff; }
        .pc-btn.es-primario:hover { background: var(--sigma-purple-dark); color: #fff; }
        .pc-btn.es-contorno { background: #fff; border-color: var(--sigma-blue); color: var(--sigma-blue); }
        .pc-btn.es-contorno:hover { background: var(--sigma-blue-soft); color: var(--sigma-blue-dark); }
        .pc-btn.es-ghost { background: var(--sigma-purple-soft); color: var(--sigma-purple); }
        .pc-btn.es-ghost:hover { background: #E6E0FF; color: var(--sigma-purple-dark); }
        .pc-btn.es-peligro { background: #fff; border-color: #F1C9C5; color: var(--danger); }
        .pc-btn.es-peligro:hover { background: #FDECEA; }
        .pc-btn.es-chico { min-height: 32px; padding: 5px 11px; font-size: 12.5px; }
        .pc-btn[disabled], .pc-btn.aspNetDisabled { opacity: .42; cursor: not-allowed; }
        .pc-btn:focus-visible, .pc input:focus-visible, .pc textarea:focus-visible, .pc label:focus-within {
            outline: 3px solid rgba(22,198,201,.27); outline-offset: 1px; }

        /* ---- pasos del flujo ---- */
        .pc-flujo { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
        .pc-paso { display: flex; gap: 12px; align-items: flex-start; padding: 12px 14px; border-radius: 12px; background: var(--canvas); }
        .pc-paso b { display: block; font-size: 13px; margin-bottom: 2px; }
        .pc-paso span { color: var(--muted); font-size: 12px; line-height: 1.45; }
        .pc-num { flex: 0 0 auto; width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center;
                  background: var(--sigma-purple-soft); color: var(--sigma-purple); font-weight: 800; }
        .pc-paso.es-aqui .pc-num { background: var(--sigma-purple); color: #fff; }
        @media (max-width: 860px) { .pc-flujo { grid-template-columns: 1fr; } }

        /* ---- barra del listado ---- */
        .pc-barra { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; justify-content: space-between; margin-bottom: 14px; }
        .pc-buscar { position: relative; flex: 1 1 260px; max-width: 420px; }
        .pc-buscar i { position: absolute; left: 11px; top: 50%; transform: translateY(-50%); color: var(--muted); font-size: 17px; }
        .pc-buscar input { width: 100%; height: 38px; padding: 8px 12px 8px 34px; border: 1px solid #CFD6E3; border-radius: 9px; font-size: 13px; }
        .pc-check { display: inline-flex; align-items: center; gap: 6px; color: var(--muted); font-weight: 600; cursor: pointer; }
        .pc-check input { margin: 0; }

        /* ---- tarjetas de perfil ---- */
        .pc-grilla { display: grid; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); gap: 14px; }
        .pc-perfil { display: flex; flex-direction: column; gap: 10px; background: var(--surface); border: 1px solid var(--line);
                     border-radius: 14px; padding: 16px; transition: box-shadow .15s, border-color .15s; }
        .pc-perfil:hover { border-color: #CBD3E1; box-shadow: 0 6px 18px rgba(23,34,59,.07); }
        .pc-perfil.es-off { background: var(--canvas); }
        .pc-perfil.es-off .pc-perfil-nombre { color: var(--muted); }
        .pc-perfil.es-nuevo { border-color: var(--sigma-cyan); box-shadow: 0 0 0 3px rgba(22,198,201,.18); }
        .pc-perfil-cab { display: flex; gap: 12px; align-items: flex-start; }
        .pc-avatar { flex: 0 0 auto; width: 40px; height: 40px; border-radius: 12px; display: flex; align-items: center; justify-content: center;
                     background: var(--sigma-purple-soft); color: var(--sigma-purple); font-size: 20px; }
        .pc-perfil.es-sistema .pc-avatar { background: var(--sigma-cyan-soft); color: var(--sigma-cyan-dark); }
        .pc-perfil-nombre { font-size: 14.5px; font-weight: 800; line-height: 1.3; }
        .pc-perfil-desc { color: var(--muted); font-size: 12.5px; line-height: 1.45; margin-top: 2px; }
        .pc-chips { display: flex; flex-wrap: wrap; gap: 6px; }
        .pc-chip { display: inline-flex; align-items: center; gap: 4px; padding: 3px 9px; border-radius: 999px; font-size: 11.5px; font-weight: 800; }
        .pc-chip.es-purple { background: var(--sigma-purple-soft); color: var(--sigma-purple); }
        .pc-chip.es-cyan { background: var(--sigma-cyan-soft); color: var(--sigma-cyan-dark); }
        .pc-chip.es-blue { background: var(--sigma-blue-soft); color: var(--sigma-blue); }
        .pc-chip.es-gris { background: var(--canvas); color: var(--muted); }
        .pc-chip.es-warning { background: #FFF4E5; color: var(--warning); }
        .pc-perfil-acc { display: flex; flex-wrap: wrap; gap: 8px; margin-top: auto; padding-top: 6px; border-top: 1px dashed var(--line); }
        .pc-aviso-uso { font-size: 11.5px; color: var(--muted); }

        .pc-vacio { text-align: center; padding: 34px 10px; color: var(--muted); }
        .pc-vacio i { font-size: 40px; color: var(--sigma-cyan-dark); display: block; margin-bottom: 6px; }
        .pc-vacio b { display: block; color: var(--ink); font-size: 14px; margin-bottom: 4px; }

        .pc-msg { display: flex; gap: 10px; align-items: flex-start; padding: 12px 14px; border-radius: 12px; margin-bottom: 14px; font-size: 13px; line-height: 1.5; }
        .pc-msg i { font-size: 18px; }
        .pc-msg.es-ok { background: #E9F7F0; color: #0F5E40; }
        .pc-msg.es-error { background: #FDECEA; color: #8E2219; }
        .pc-msg.es-info { background: var(--sigma-cyan-soft); color: var(--ink); }
        .pc-msg.es-info i { color: var(--sigma-cyan-dark); }
        .pc-msg a { font-weight: 800; color: inherit; text-decoration: underline; }

        /* ---- ficha ---- */
        .pc-miga { font-size: 12px; color: var(--muted); margin-bottom: 6px; }
        .pc-miga a { color: var(--sigma-blue); text-decoration: none; font-weight: 700; }
        .pc-ficha-cab { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; margin-bottom: 14px; }
        .pc-ficha-cab h1 { font-size: 20px; font-weight: 800; margin: 0; }
        .pc-sec-tit { display: flex; align-items: center; gap: 10px; margin-bottom: 14px; }
        .pc-sec-tit .pc-num { background: var(--sigma-purple); color: #fff; }
        .pc-sec-tit small { display: block; color: var(--muted); font-size: 12px; font-weight: 500; margin-top: 1px; }
        .pc-campos { display: grid; grid-template-columns: 1fr 1fr; gap: 14px 18px; }
        @media (max-width: 760px) { .pc-campos { grid-template-columns: 1fr; } }
        .pc-campo label.pc-etq { display: block; margin: 0 0 5px; font-size: 11px; font-weight: 800; color: #4A556D; }
        .pc-campo label.pc-etq em { color: var(--danger); font-style: normal; }
        .pc-campo input[type=text], .pc-campo textarea, .pc-campo select { width: 100%; border: 1px solid #CFD6E3; border-radius: 9px; padding: 9px 11px; font-size: 13.5px; color: var(--ink); background: #fff; }
        .pc-campo textarea { min-height: 64px; resize: vertical; }
        .pc-campo input.es-error { border-color: var(--danger); background: #FFF8F7; }
        .pc-ayuda { display: block; margin-top: 4px; font-size: 11.5px; color: var(--muted); }
        .pc-err { display: none; margin-top: 4px; font-size: 11.5px; color: var(--danger); font-weight: 700; }
        .pc-err.es-visible { display: block; }

        .pc-opciones { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
        @media (max-width: 760px) { .pc-opciones { grid-template-columns: 1fr; } }
        .pc-opcion { position: relative; display: flex; gap: 10px; align-items: flex-start; padding: 13px 14px; border: 1.5px solid var(--line);
                     border-radius: 12px; cursor: pointer; background: #fff; transition: border-color .15s, background .15s; margin: 0; font-weight: 400; }
        .pc-opcion:hover { border-color: #C9C0F7; }
        .pc-opcion input { position: absolute; opacity: 0; pointer-events: none; }
        .pc-opcion > i { font-size: 22px; color: var(--muted); }
        .pc-opcion b { display: block; font-size: 13.5px; }
        .pc-opcion span { font-size: 12px; color: var(--muted); line-height: 1.4; }
        .pc-opcion.es-elegida { border-color: var(--sigma-purple); background: var(--sigma-purple-soft); }
        .pc-opcion.es-elegida > i { color: var(--sigma-purple); }
        .pc-opcion .pc-tic { position: absolute; top: 9px; right: 10px; color: var(--sigma-purple); font-size: 18px; display: none; }
        .pc-opcion.es-elegida .pc-tic { display: block; }

        .pc-toggle-fila { display: flex; gap: 12px; align-items: flex-start; margin-top: 14px; padding: 12px 14px; border-radius: 12px; background: var(--canvas); cursor: pointer; }
        .pc-toggle-fila b { display: block; font-size: 13px; }
        .pc-toggle-fila span { font-size: 12px; color: var(--muted); }

        /* interruptor */
        .pc-sw { position: relative; flex: 0 0 auto; width: 38px; height: 22px; margin-top: 1px; }
        .pc-sw input { position: absolute; opacity: 0; width: 100%; height: 100%; margin: 0; cursor: pointer; z-index: 1; }
        .pc-sw i { position: absolute; inset: 0; border-radius: 999px; background: #CFD6E3; transition: background .15s; }
        .pc-sw i::after { content: ""; position: absolute; top: 3px; left: 3px; width: 16px; height: 16px; border-radius: 50%; background: #fff;
                          box-shadow: 0 1px 2px rgba(0,0,0,.2); transition: transform .15s; }
        .pc-sw input:checked + i { background: var(--sigma-purple); }
        .pc-sw input:checked + i::after { transform: translateX(16px); }
        .pc-sw input:disabled { cursor: not-allowed; }
        .pc-sw input:disabled + i { opacity: .42; }
        .pc-sw input:focus-visible + i { outline: 3px solid rgba(22,198,201,.27); }

        /* permisos */
        .pc-perm-barra { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin-bottom: 12px; }
        .pc-contador { margin-left: auto; font-weight: 800; color: var(--sigma-purple); background: var(--sigma-purple-soft); padding: 6px 12px; border-radius: 999px; }
        .pc-modulo { border: 1px solid var(--line); border-radius: 12px; margin-bottom: 10px; overflow: hidden; }
        .pc-mod-cab { display: flex; align-items: center; gap: 10px; padding: 11px 14px; background: #FAFBFD; cursor: pointer; user-select: none; }
        .pc-mod-cab:hover { background: var(--canvas); }
        .pc-mod-ico { width: 32px; height: 32px; border-radius: 9px; display: flex; align-items: center; justify-content: center;
                      background: var(--sigma-cyan-soft); color: var(--sigma-cyan-dark); font-size: 18px; }
        .pc-mod-cab b { font-size: 13.5px; }
        .pc-mod-cab small { display: block; color: var(--muted); font-size: 11.5px; }
        .pc-mod-cuenta { margin-left: auto; font-size: 12px; font-weight: 800; color: var(--muted); }
        .pc-mod-cuenta.es-algo { color: var(--sigma-purple); }
        .pc-mod-todo { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 700; color: var(--muted); }
        .pc-flecha { color: var(--muted); font-size: 20px; transition: transform .15s; }
        .pc-modulo.es-abierto .pc-flecha { transform: rotate(180deg); }
        .pc-mod-cuerpo { display: none; border-top: 1px solid var(--line); }
        .pc-modulo.es-abierto .pc-mod-cuerpo { display: block; }
        .pc-permiso { display: flex; gap: 12px; align-items: flex-start; padding: 10px 14px; border-top: 1px dashed var(--line); cursor: pointer; margin: 0; font-weight: 400; }
        .pc-permiso:first-child { border-top: 0; }
        .pc-permiso:hover { background: #FBFBFE; }
        .pc-permiso b { display: block; font-size: 13px; font-weight: 700; }
        .pc-permiso span.d { display: block; font-size: 12px; color: var(--muted); line-height: 1.4; margin-top: 1px; }
        .pc-permiso .pc-tipo { margin-left: auto; flex: 0 0 auto; }
        .pc-permiso.es-oculto, .pc-modulo.es-oculto { display: none; }
        .pc-permiso.es-bloqueado { cursor: not-allowed; }

        .pc-pie { position: sticky; bottom: 0; z-index: 5; display: flex; gap: 10px; align-items: center; justify-content: flex-end;
                  padding: 12px 20px; margin: 0 -2px; background: rgba(255,255,255,.96); border: 1px solid var(--line); border-radius: 14px;
                  box-shadow: 0 -6px 18px rgba(23,34,59,.06); }
        .pc-sucio { margin-right: auto; display: none; align-items: center; gap: 6px; color: var(--warning); font-weight: 700; }
        .pc-sucio.es-visible { display: inline-flex; }

        .pc-toast { position: fixed; left: 50%; bottom: 90px; transform: translateX(-50%) translateY(20px); opacity: 0; z-index: 9999;
                    background: var(--ink); color: #fff; padding: 10px 16px; border-radius: 10px; font-size: 12.5px; max-width: 90vw;
                    box-shadow: 0 8px 24px rgba(23,34,59,.25); transition: opacity .2s, transform .2s; pointer-events: none; }
        .pc-toast.es-visible { opacity: 1; transform: translateX(-50%) translateY(0); }
    </style>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Cliente · Usuarios</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Perfiles</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Los cargos de su empresa y lo que puede hacer cada uno en SIGMA.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
<div class="pc">
    <asp:HiddenField ID="hdnPermisos" runat="server" />
    <asp:HiddenField ID="hdnAccion" runat="server" />
    <asp:HiddenField ID="hdnAccionId" runat="server" />
    <asp:LinkButton ID="lnkAccion" runat="server" OnClick="lnkAccion_Click" style="display:none" CausesValidation="false" />

    <asp:UpdatePanel ID="udPanel" runat="server" UpdateMode="Always">
        <ContentTemplate>

        <asp:Literal ID="litMensaje" runat="server" />

        <%-- ============================== LISTADO ============================== --%>
        <asp:Panel ID="pnlLista" runat="server">
            <div class="pc-card">
                <div class="pc-flujo">
                    <div class="pc-paso es-aqui"><span class="pc-num">1</span><div><b>Cree el perfil</b><span>El cargo tal como lo llaman en su empresa: jardinero, jefe de turno, mayordomo.</span></div></div>
                    <div class="pc-paso es-aqui"><span class="pc-num">2</span><div><b>Elija qué puede hacer</b><span>Marque lo que ese cargo necesita ver o hacer. Nada más.</span></div></div>
                    <div class="pc-paso"><span class="pc-num">3</span><div><b>Asígnelo a sus usuarios</b><span>En <asp:HyperLink ID="hlUsuarios" runat="server" Text="Usuarios" />, cada persona recibe su perfil.</span></div></div>
                </div>
            </div>

            <div class="pc-barra">
                <div class="pc-buscar">
                    <i class="mdi mdi-magnify"></i>
                    <asp:TextBox ID="txtBuscar" runat="server" placeholder="Buscar un perfil…" AutoPostBack="true" OnTextChanged="Filtro_Changed" />
                </div>
                <label class="pc-check"><asp:CheckBox ID="chkInactivos" runat="server" AutoPostBack="true" OnCheckedChanged="Filtro_Changed" /> Mostrar desactivados</label>
                <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="pc-btn es-primario" OnClick="lnkNuevo_Click" CausesValidation="false">
                    <i class="mdi mdi-plus"></i>Nuevo perfil</asp:LinkButton>
            </div>

            <asp:Literal ID="litLista" runat="server" />
        </asp:Panel>

        <%-- ============================== FICHA ============================== --%>
        <asp:Panel ID="pnlFicha" runat="server" Visible="false">
            <div class="pc-miga"><a href="#" onclick="return pcVolver();">Perfiles</a> / <asp:Literal ID="litMiga" runat="server" /></div>
            <div class="pc-ficha-cab">
                <div>
                    <h1><asp:Literal ID="litFichaTitulo" runat="server" /></h1>
                    <p class="pc-muted"><asp:Literal ID="litFichaSub" runat="server" /></p>
                </div>
            </div>

            <asp:Literal ID="litSoloLectura" runat="server" />

            <%-- Paso 1 --%>
            <div class="pc-card">
                <div class="pc-sec-tit"><span class="pc-num">1</span><div><h2>¿Cómo se llama este cargo?</h2><small>Use el nombre que su gente reconoce.</small></div></div>
                <div class="pc-campos">
                    <div class="pc-campo">
                        <label class="pc-etq" for="<%=txtNombre.ClientID %>">Nombre del perfil <em>*</em></label>
                        <asp:TextBox ID="txtNombre" runat="server" MaxLength="200" placeholder="Ej.: Jardinero" />
                        <span class="pc-err" id="pcErrNombre">Escriba el nombre del perfil.</span>
                    </div>
                    <asp:Panel ID="pnlPlantilla" runat="server" CssClass="pc-campo">
                        <label class="pc-etq" for="<%=ddlPlantilla.ClientID %>">Empezar con los permisos de…</label>
                        <asp:DropDownList ID="ddlPlantilla" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlPlantilla_Changed" />
                        <span class="pc-ayuda">Opcional. Copia sus permisos como punto de partida; después puede cambiarlos.</span>
                    </asp:Panel>
                    <div class="pc-campo" style="grid-column: 1 / -1">
                        <label class="pc-etq" for="<%=txtDescripcion.ClientID %>">¿Qué hace esta persona?</label>
                        <asp:TextBox ID="txtDescripcion" runat="server" TextMode="MultiLine" MaxLength="1000"
                            placeholder="Ej.: Mantiene las áreas verdes y reporta fallas del sistema de riego." />
                        <span class="pc-ayuda">Opcional. Ayuda a elegir bien el perfil al crear un usuario.</span>
                    </div>
                </div>
            </div>

            <%-- Paso 2 --%>
            <div class="pc-card">
                <div class="pc-sec-tit"><span class="pc-num">2</span><div><h2>¿Dónde trabaja?</h2><small>Desde dónde va a usar SIGMA.</small></div></div>
                <div class="pc-opciones" id="pcAmbitos">
                    <label class="pc-opcion"><asp:RadioButton ID="rdbWeb" runat="server" GroupName="Ambito" />
                        <i class="mdi mdi-monitor"></i><div><b>En el computador</b><span>Solo la web. Para oficina y administración.</span></div><i class="mdi mdi-check-circle pc-tic"></i></label>
                    <label class="pc-opcion"><asp:RadioButton ID="rdbApp" runat="server" GroupName="Ambito" />
                        <i class="mdi mdi-cellphone"></i><div><b>En terreno, con el teléfono</b><span>Solo la app. No entra a la web.</span></div><i class="mdi mdi-check-circle pc-tic"></i></label>
                    <label class="pc-opcion"><asp:RadioButton ID="rdbAmbos" runat="server" GroupName="Ambito" />
                        <i class="mdi mdi-devices"></i><div><b>En ambos</b><span>Web y app. Lo más común.</span></div><i class="mdi mdi-check-circle pc-tic"></i></label>
                </div>
                <label class="pc-toggle-fila" for="<%=chkSoloEjecucion.ClientID %>">
                    <span class="pc-sw"><asp:CheckBox ID="chkSoloEjecucion" runat="server" /><i></i></span>
                    <div><b>Solo ejecuta trabajo</b><span>Hace las tareas que le asignan, pero no puede cerrar órdenes de trabajo. Típico de técnicos y operarios.</span></div>
                </label>
            </div>

            <%-- Paso 3 --%>
            <div class="pc-card">
                <div class="pc-sec-tit"><span class="pc-num">3</span><div><h2>¿Qué puede hacer?</h2><small>Abra cada área y marque lo que este cargo necesita. Lo que no marque, no lo verá.</small></div></div>
                <div class="pc-perm-barra">
                    <div class="pc-buscar">
                        <i class="mdi mdi-magnify"></i>
                        <input type="text" id="pcBuscarPerm" placeholder="Buscar un permiso: activos, bodega, cerrar…" autocomplete="off" />
                    </div>
                    <button type="button" class="pc-btn es-contorno es-chico" onclick="pcAbrirTodo(true)"><i class="mdi mdi-unfold-more-horizontal"></i>Abrir todo</button>
                    <button type="button" class="pc-btn es-contorno es-chico" onclick="pcAbrirTodo(false)"><i class="mdi mdi-unfold-less-horizontal"></i>Cerrar todo</button>
                    <span class="pc-contador" id="pcContador">0 permisos</span>
                </div>
                <div id="pcPermisos"><asp:Literal ID="litPermisos" runat="server" /></div>
            </div>

            <div class="pc-pie">
                <span class="pc-sucio" id="pcSucio"><i class="mdi mdi-circle-medium"></i>Hay cambios sin guardar</span>
                <a href="#" class="pc-btn es-ghost" onclick="return pcVolver();"><i class="mdi mdi-close"></i>Cancelar</a>
                <asp:LinkButton ID="lnkGuardar" runat="server" CssClass="pc-btn es-primario" OnClick="lnkGuardar_Click"
                    OnClientClick="return pcAntesDeGuardar();" CausesValidation="false"><i class="mdi mdi-content-save-outline"></i>Guardar perfil</asp:LinkButton>
            </div>
        </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>

    <div class="pc-toast" id="pcToast" role="status" aria-live="polite"></div>
</div>

<script type="text/javascript">
    /* Todo lo de esta pantalla vive en el navegador hasta Guardar: marcar
       permisos no hace viajes. hdnPermisos lleva los elegidos al servidor. */
    var pcSucio = false;

    function pcToast(t) {
        var el = document.getElementById('pcToast'); if (!el) return;
        el.textContent = t; el.classList.add('es-visible');
        clearTimeout(pcToast.t); pcToast.t = setTimeout(function () { el.classList.remove('es-visible'); }, 3800);
    }
    function pcMarcarSucio() {
        pcSucio = true;
        var s = document.getElementById('pcSucio'); if (s) s.classList.add('es-visible');
    }
    function pcVolver() {
        if (pcSucio && !confirm('Tiene cambios sin guardar. ¿Salir sin guardarlos?')) return false;
        pcSucio = false;
        pcAccion('volver', 0);
        return false;
    }
    function pcAccion(accion, id) {
        document.getElementById('<%=hdnAccion.ClientID %>').value = accion;
        document.getElementById('<%=hdnAccionId.ClientID %>').value = id;
        __doPostBack('<%=lnkAccion.UniqueID %>', '');
        return false;
    }
    function pcDesactivar(id, nombre) {
        if (!confirm('¿Desactivar el perfil «' + nombre + '»?\n\nNo se borra: deja de ofrecerse al crear usuarios y lo puede volver a activar cuando quiera.')) return false;
        return pcAccion('desactivar', id);
    }

    function pcChecks() { return [].slice.call(document.querySelectorAll('#pcPermisos input[data-prm]')); }
    function pcPorId(id) { return document.querySelector('#pcPermisos input[data-prm="' + id + '"]'); }

    function pcRecontar() {
        var todos = pcChecks(), sel = [];
        todos.forEach(function (c) { if (c.checked) sel.push(c.getAttribute('data-prm')); });
        var h = document.getElementById('<%=hdnPermisos.ClientID %>'); if (h) h.value = sel.join(',');
        var cont = document.getElementById('pcContador');
        if (cont) cont.textContent = sel.length === 0 ? 'Ningún permiso' : (sel.length === 1 ? '1 permiso' : sel.length + ' permisos');
        [].slice.call(document.querySelectorAll('.pc-modulo')).forEach(function (m) {
            var cs = [].slice.call(m.querySelectorAll('input[data-prm]')), n = cs.filter(function (c) { return c.checked; }).length;
            var lab = m.querySelector('.pc-mod-cuenta'); if (lab) { lab.textContent = n + ' de ' + cs.length; lab.classList.toggle('es-algo', n > 0); }
            var todo = m.querySelector('input.pc-todo');
            if (todo) { todo.checked = n === cs.length && n > 0; todo.indeterminate = n > 0 && n < cs.length; }
        });
    }

    /* Dependencias: "Crear y editar X" necesita "Ver X"; "Cerrar órdenes" no va con "Solo ejecuta". */
    function pcCambio(c) {
        var req = c.getAttribute('data-requiere');
        if (c.checked && req) {
            var v = pcPorId(req);
            if (v && !v.checked) { v.checked = true; pcToast('También se marcó «' + v.getAttribute('data-nombre') + '»: sin verlo no podría editarlo.'); }
        }
        if (!c.checked) {
            var dep = pcChecks().filter(function (x) { return x.getAttribute('data-requiere') === c.getAttribute('data-prm') && x.checked; });
            if (dep.length) {
                dep.forEach(function (x) { x.checked = false; });
                pcToast('También se quitó «' + dep[0].getAttribute('data-nombre') + '»: no se puede editar lo que no se ve.');
            }
        }
        pcMarcarSucio(); pcRecontar();
    }
    function pcTodoModulo(t, ev) {
        if (ev) ev.stopPropagation();
        var m = t.closest('.pc-modulo');
        m.querySelectorAll('input[data-prm]').forEach(function (c) { if (!c.disabled) c.checked = t.checked; });
        if (t.checked) m.querySelectorAll('input[data-prm]:checked').forEach(function (c) { pcCambio(c); });
        pcMarcarSucio(); pcRecontar();
    }
    function pcAbrirTodo(abrir) {
        document.querySelectorAll('.pc-modulo').forEach(function (m) { m.classList.toggle('es-abierto', abrir); });
    }
    function pcSoloEjecucion() {
        var s = document.getElementById('<%=chkSoloEjecucion.ClientID %>');
        var cerrar = document.querySelector('#pcPermisos input[data-codigo="CERRAR OT"]');
        if (!s || !cerrar) return;
        var fila = cerrar.closest('.pc-permiso');
        if (s.checked) {
            if (cerrar.checked) { cerrar.checked = false; pcToast('Se quitó «Cerrar órdenes de trabajo»: un perfil que solo ejecuta no las cierra.'); }
            cerrar.disabled = true; fila.classList.add('es-bloqueado');
            fila.title = 'Desactive «Solo ejecuta trabajo» para poder dar este permiso.';
        } else if (!cerrar.hasAttribute('data-ro')) {
            cerrar.disabled = false; fila.classList.remove('es-bloqueado'); fila.title = '';
        }
        pcRecontar();
    }
    function pcAmbitos() {
        document.querySelectorAll('#pcAmbitos .pc-opcion').forEach(function (o) {
            o.classList.toggle('es-elegida', !!o.querySelector('input:checked'));
        });
    }
    function pcFiltrar(q) {
        q = (q || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
        document.querySelectorAll('.pc-modulo').forEach(function (m) {
            var visibles = 0;
            m.querySelectorAll('.pc-permiso').forEach(function (p) {
                var ok = !q || (p.getAttribute('data-buscar') || '').indexOf(q) >= 0;
                p.classList.toggle('es-oculto', !ok); if (ok) visibles++;
            });
            m.classList.toggle('es-oculto', visibles === 0);
            if (q && visibles) m.classList.add('es-abierto');
        });
    }
    function pcAntesDeGuardar() {
        var n = document.getElementById('<%=txtNombre.ClientID %>'), e = document.getElementById('pcErrNombre');
        if (n && !n.value.trim()) {
            n.classList.add('es-error'); if (e) e.classList.add('es-visible');
            n.focus(); n.scrollIntoView({ behavior: 'smooth', block: 'center' });
            return false;
        }
        pcRecontar();
        if (pcChecks().filter(function (c) { return c.checked; }).length === 0 &&
            !confirm('Este perfil no tiene ningún permiso: quien lo tenga no verá ningún menú.\n\n¿Guardarlo así de todas formas?')) return false;
        pcSucio = false;
        return true;
    }

    function pcIniciar() {
        pcAmbitos(); pcSoloEjecucion(); pcRecontar();
        var n = document.getElementById('<%=txtNombre.ClientID %>');
        if (n) n.addEventListener('input', function () {
            n.classList.remove('es-error'); var e = document.getElementById('pcErrNombre'); if (e) e.classList.remove('es-visible'); pcMarcarSucio();
        });
        var d = document.getElementById('<%=txtDescripcion.ClientID %>'); if (d) d.addEventListener('input', pcMarcarSucio);
        var b = document.getElementById('pcBuscarPerm'); if (b) b.addEventListener('input', function () { pcFiltrar(b.value); });
        var s = document.getElementById('<%=chkSoloEjecucion.ClientID %>'); if (s) s.addEventListener('change', function () { pcSoloEjecucion(); pcMarcarSucio(); });
        document.querySelectorAll('#pcAmbitos input').forEach(function (r) { r.addEventListener('change', function () { pcAmbitos(); pcMarcarSucio(); }); });
        var nuevo = document.querySelector('.pc-perfil.es-nuevo'); if (nuevo) nuevo.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
    document.addEventListener('DOMContentLoaded', function () {
        pcIniciar();
        if (typeof Sys !== 'undefined' && Sys.WebForms)
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(pcIniciar);
    });
    window.addEventListener('beforeunload', function (e) { if (pcSucio) { e.preventDefault(); e.returnValue = ''; } });
</script>
</asp:Content>
