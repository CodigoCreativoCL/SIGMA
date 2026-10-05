<%@ Control Language="C#" AutoEventWireup="true" CodeFile="ActivoForm.ascx.cs" Inherits="View_Activos_Activos_ActivoForm" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<%-- EL FORMULARIO DEL ACTIVO, UNA SOLA VEZ

     Lo muestran dos pantallas: el modal de alta -desde el listado y
     desde el centro- y la pestaña Ficha del centro del activo. Es el
     mismo control con dos vestidos, y no dos formularios: duplicarlo
     obligaba a agregar cada campo nuevo en dos partes.

     REDISEÑO 04-10-2026 (maquetas «SIGMA · Rediseño módulo de Activos»):
     asistente de cuatro pasos con los pasos a la izquierda y una ayuda corta
     por paso; todos los botones en UNA barra al pie y siempre en el mismo
     lugar; validacion que dice que falta y lleva al campo; y, al crear, una
     confirmacion con el proximo paso sugerido. --%>

<style type="text/css">
    .af {
        --af-purple: #6732F4; --af-purple-dark: #4820C9; --af-purple-soft: #F2EFFF;
        --af-blue: #087BEA; --af-blue-dark: #0565C2; --af-blue-soft: #EAF4FF;
        --af-cyan: #16C6C9; --af-cyan-dark: #007F8A; --af-cyan-soft: #E8FBFB;
        --af-ink: #17223B; --af-muted: #68738A; --af-line: #E2E7F0; --af-input: #CFD6E3;
        --af-canvas: #F4F6FA; --af-success: #16855B; --af-success-soft: #E7F5EE;
        --af-warning: #B65C00; --af-warning-soft: #FFF3E3; --af-danger: #C7352B; --af-danger-soft: #FDECEA;
        display: grid; grid-template-columns: 228px minmax(0, 1fr); gap: 24px; align-items: start;
        color: var(--af-ink); font-size: 14px; line-height: 1.45;
    }
    .af.af-centro { grid-template-columns: 248px minmax(0, 1fr); max-width: 1120px; }
    @media (max-width: 860px) { .af, .af.af-centro { grid-template-columns: minmax(0, 1fr); gap: 16px; } }

    /* ---- Riel: los pasos y la ayuda del paso ---- */
    .af-rail { display: grid; gap: 16px; position: sticky; top: 8px; }
    .af-pasos { display: grid; gap: 4px; position: relative; }
    .af-paso { position: relative; display: flex; align-items: flex-start; gap: 12px; width: 100%; min-height: 56px; padding: 10px 12px;
        border: 0; border-radius: 12px; background: transparent; color: var(--af-ink); font: inherit; text-align: left; cursor: pointer; }
    .af-paso:hover { background: var(--af-canvas); }
    .af-paso:focus-visible { outline: 3px solid rgba(22,198,201,.27); outline-offset: 0; }
    /* la linea que une los pasos */
    .af-paso:not(:last-child)::after { content: ""; position: absolute; left: 27px; top: 44px; bottom: -8px; width: 2px; background: var(--af-line); }
    .af-paso.es-hecho:not(:last-child)::after { background: #BFE3D1; }
    .af-n { position: relative; z-index: 1; flex: 0 0 auto; width: 32px; height: 32px; border-radius: 50%; display: grid; place-items: center;
        background: var(--af-canvas); color: var(--af-muted); font-weight: 800; font-size: 14px; border: 2px solid #fff; box-shadow: 0 0 0 1px var(--af-line); }
    .af-n .mdi { display: none; font-size: 18px; }
    .af-paso b { display: block; font-size: 14px; font-weight: 700; line-height: 1.3; }
    .af-paso small { display: block; margin-top: 2px; font-size: 12px; color: var(--af-muted); line-height: 1.35; }
    .af-paso.es-activo { background: var(--af-purple-soft); }
    .af-paso.es-activo b { color: var(--af-purple-dark); }
    .af-paso.es-activo .af-n { background: var(--af-purple); color: #fff; box-shadow: 0 0 0 1px var(--af-purple); }
    .af-paso.es-hecho .af-n { background: var(--af-success-soft); color: var(--af-success); box-shadow: 0 0 0 1px #BFE3D1; }
    .af-paso.es-hecho .af-n span { display: none; } .af-paso.es-hecho .af-n .mdi { display: block; }
    .af-paso .af-falta-dot { display: none; margin-top: 3px; font-size: 12px; font-weight: 700; color: var(--af-danger); }
    .af-paso.es-falta .af-falta-dot { display: block; }
    .af-paso.es-falta .af-n { background: var(--af-danger-soft); color: var(--af-danger); box-shadow: 0 0 0 1px #F2B8B3; }
    .af-paso.es-falta .af-n span { display: block; } .af-paso.es-falta .af-n .mdi { display: none; }

    .af-tip { display: none; gap: 10px; padding: 14px; border: 1px solid var(--af-line); border-radius: 14px; background: #fff; font-size: 13px; color: #4A556D; line-height: 1.5; }
    .af-tip.es-activo { display: flex; }
    .af-tip > i { flex: 0 0 auto; width: 24px; height: 24px; border-radius: 50%; background: var(--af-purple-soft); color: var(--af-purple); display: grid; place-items: center; font-size: 15px; }
    .af-tip b { color: var(--af-ink); }
    .af-sobre { padding: 14px; border: 1px solid var(--af-line); border-radius: 14px; background: #fff; font-size: 13px; display: grid; gap: 10px; }
    .af-sobre h4 { margin: 0; font-size: 13px; font-weight: 800; color: var(--af-ink); }
    .af-sobre .sg-a3-pie-dato { display: flex; margin: 0; align-items: flex-start; color: var(--af-muted); font-size: 12.5px; }
    .af-sobre .sg-a3-pie-dato b { color: #4A556D; }
    .af-sobre-chips { display: flex; flex-wrap: wrap; gap: 6px; }
    .af-sobre-chips span { padding: 3px 10px; border-radius: 999px; font-size: 12px; font-weight: 800; }
    .af-sobre-chips .es-sub { background: var(--af-blue-soft); color: var(--af-blue-dark); }
    .af-sobre-chips .es-comp { background: var(--af-cyan-soft); color: var(--af-cyan-dark); }
    .af-sobre-chips .es-rep { background: #FFF4E0; color: #8F4E00; }
    .af-sobre a { color: var(--af-blue-dark); font-weight: 700; text-decoration: none; }
    @media (max-width: 860px) {
        .af-rail { position: static; }
        .af-pasos { grid-template-columns: repeat(4, minmax(0, 1fr)); }
        .af-paso { flex-direction: column; align-items: center; text-align: center; gap: 6px; }
        .af-paso small, .af-paso:not(:last-child)::after { display: none; }
    }

    /* ---- Cuerpo ---- */
    .af-cuerpo { min-width: 0; display: grid; gap: 16px; }
    .af-seccion { display: none; }
    .af-seccion.es-activo { display: grid; gap: 18px; }
    .af-cab { display: flex; gap: 12px; align-items: flex-start; }
    .af-cab > i { flex: 0 0 auto; width: 36px; height: 36px; border-radius: 10px; background: var(--af-purple-soft); color: var(--af-purple); display: grid; place-items: center; font-size: 20px; }
    .af-cab h3 { margin: 0; font-size: 17px; font-weight: 800; color: var(--af-ink); line-height: 1.3; }
    .af-cab p { margin: 2px 0 0; font-size: 13px; color: var(--af-muted); }
    .af-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px 20px; }
    .af-grid > .af-ancho { grid-column: 1 / -1; }
    @media (max-width: 640px) { .af-grid { grid-template-columns: minmax(0, 1fr); } }
    .af-sub { margin: 0 0 8px; font-size: 13px; font-weight: 800; color: var(--af-ink); }
    .af-sub small { display: block; font-size: 12px; font-weight: 500; color: var(--af-muted); }

    /* los campos: rotulo legible y control de 40px */
    .af .sigma-modal-field { gap: 6px; }
    .af .sigma-modal-field > label { height: auto; line-height: 1.3; margin: 0; font-size: 12px; font-weight: 800; color: #4A556D; letter-spacing: 0; white-space: normal; }
    .af .req { color: var(--af-danger); font-weight: 800; }
    .af .sigma-modal-field input[type="text"], .af .sigma-modal-field textarea, .af select.sigma-nd-sel, .af input.sigma-nd-txt {
        width: 100%; min-height: 40px; box-sizing: border-box; padding: 8px 12px; border: 1px solid var(--af-input); border-radius: 9px;
        background: #fff; color: var(--af-ink); font: inherit; font-size: 14px; box-shadow: none; }
    .af .sigma-modal-field textarea { min-height: 84px; resize: vertical; }
    .af .sigma-modal-field input[type="text"]:focus, .af .sigma-modal-field textarea:focus, .af select.sigma-nd-sel:focus, .af input.sigma-nd-txt:focus {
        outline: 3px solid rgba(22,198,201,.27); border-color: var(--af-cyan-dark); }
    .af .sigma-modal-field input[readonly] { background: var(--af-canvas) !important; border: 1px solid var(--af-line) !important; border-radius: 9px !important; font-weight: 600; }
    .af .sigma-modal-field .RadComboBox { width: 100% !important; }
    .af .sigma-modal-ayuda { font-size: 12px; color: var(--af-muted); line-height: 1.4; }
    .af .sg-codigo input[type="text"] { border: 0 !important; min-height: 38px; }

    /* falta un dato: se dice cual y como arreglarlo */
    .af-msg { display: none; align-items: center; gap: 5px; font-size: 12px; font-weight: 700; color: var(--af-danger); }
    .af .sigma-modal-field.es-falta .af-msg { display: flex; }
    .af .sigma-modal-field.es-falta > label { color: var(--af-danger); }
    .af .sigma-modal-field.es-falta input[type="text"], .af .sigma-modal-field.es-falta .rcbInputCell, .af .sigma-modal-field.es-falta .sg-codigo { border-color: var(--af-danger) !important; background-color: #FFFAF9 !important; }
    .af .sigma-modal-field.es-falta .RadComboBox { box-shadow: 0 0 0 1px var(--af-danger); border-radius: 9px; }
    .af .sigma-modal-field.es-falta .sigma-modal-ayuda { display: none; }
    .af-faltan { display: none; gap: 12px; align-items: flex-start; padding: 12px 14px; border: 1px solid #F2B8B3; border-radius: 12px; background: var(--af-danger-soft); color: #7A1F18; }
    .af-faltan.es-visible { display: flex; }
    .af-faltan > i { font-size: 22px; color: var(--af-danger); line-height: 1; }
    .af-faltan b { display: block; font-size: 14px; }
    .af-faltan span { font-size: 13px; }
    .af-faltan-lista { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
    .af-faltan-lista button { display: inline-flex; align-items: center; gap: 4px; min-height: 32px; padding: 0 12px; border: 1px solid #F2B8B3; border-radius: 999px;
        background: #fff; color: var(--af-danger); font: inherit; font-size: 12.5px; font-weight: 800; cursor: pointer; }
    .af-faltan-lista button:hover { background: #FFF5F4; }

    /* opciones Si/No como dos botones pegados */
    .af-pills { position: relative; display: inline-flex; flex-wrap: wrap; gap: 8px; }
    .af-pills input { position: absolute; opacity: 0; width: 1px; height: 1px; pointer-events: none; }
    .af-pills label { display: inline-flex !important; align-items: center; gap: 8px; min-height: 40px; height: auto !important; padding: 0 16px; margin: 0;
        border: 1.5px solid var(--af-input); border-radius: 10px; background: #fff; color: var(--af-ink) !important; font-size: 13.5px !important; font-weight: 700 !important; cursor: pointer; white-space: nowrap; }
    .af-pills label::before { content: ""; width: 16px; height: 16px; border-radius: 50%; border: 2px solid var(--af-input); box-sizing: border-box; background: #fff; }
    .af-pills input:checked + label { border-color: var(--af-purple); background: var(--af-purple-soft); color: var(--af-purple-dark) !important; }
    .af-pills input:checked + label::before { border: 5px solid var(--af-purple); }
    .af-pills input:focus-visible + label { outline: 3px solid rgba(22,198,201,.27); }
    .af-pills input:disabled + label { opacity: .55; cursor: not-allowed; }
    .af-linea { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; }
    .af-linea .sigma-modal-ayuda { flex: 1 1 220px; }
    .af-padre[hidden] { display: none; }

    /* foto y documentos: una franja donde soltar el archivo */
    .af-drop { display: flex; align-items: center; gap: 14px; padding: 12px 14px; border: 1.5px dashed var(--af-input); border-radius: 12px; background: #FBFCFE; transition: border-color .15s, background .15s; }
    .af-drop.es-encima { border-color: var(--af-cyan-dark); background: var(--af-cyan-soft); }
    .af-drop-ico { flex: 0 0 auto; width: 56px; height: 56px; border-radius: 10px; background: var(--af-canvas); color: var(--af-muted); display: grid; place-items: center; font-size: 26px; overflow: hidden; }
    .af-drop-ico img { width: 100%; height: 100%; object-fit: cover; display: block; }
    .af-drop-txt { flex: 1 1 auto; min-width: 0; display: grid; gap: 2px; }
    .af-drop-txt b { font-size: 13.5px; color: var(--af-ink); }
    .af-drop-txt span { font-size: 12px; color: var(--af-muted); }
    .af-drop-txt .sigma-img-name, .af-drop-txt #sigmaDocsLista { color: var(--af-cyan-dark); font-weight: 700; word-break: break-all; }
    .af-drop-acc { flex: 0 0 auto; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
    .af-quitar-foto { display: inline-flex; align-items: center; gap: 6px; margin-top: 4px; font-size: 12.5px; color: #4A556D; }
    .af-quitar-foto input { width: 16px; height: 16px; accent-color: var(--af-purple); }
    .af-foto.con-prev .af-foto-vacia, .af-foto.con-prev .af-foto-actual { display: none; }
    .af-foto-vacia { display: contents; }
    @media (max-width: 640px) { .af-drop { flex-wrap: wrap; } .af-drop-acc { width: 100%; justify-content: flex-start; } }

    .sigma-doc-lista { display: grid; gap: 8px; margin-bottom: 10px; }
    .sigma-doc { display: flex; align-items: center; gap: 10px; min-height: 44px; padding: 6px 12px; border: 1px solid var(--af-line); border-radius: 10px; font-size: 13px; color: var(--af-ink); }
    .sigma-doc > i { font-size: 18px; color: var(--af-purple); }
    .sigma-doc .nom { flex: 1 1 auto; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .sigma-doc .ver { color: var(--af-blue-dark) !important; font-weight: 700; text-decoration: none; }
    .sigma-doc .quitar { color: var(--af-danger) !important; font-weight: 700; text-decoration: none; }

    /* filas de datos de placa y de partes */
    .af-filas-cab, .af-fila, .sigma-nd-fila { display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr) minmax(0, 1fr) 44px 40px; gap: 8px; align-items: center; }
    .af-fila-var { grid-template-columns: minmax(0, 1.6fr) minmax(0, 1fr) 96px 96px 40px; }
    .af-fila-med { grid-template-columns: minmax(0, 1.6fr) minmax(0, 1fr) 130px 40px; }
    .af-filas-cab { padding: 0 2px 6px; font-size: 12px; font-weight: 800; color: #4A556D; }
    .af-filas { display: grid; gap: 8px; }
    .sigma-nd-fila > label { margin: 0; font-size: 13.5px; font-weight: 700; color: var(--af-ink); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .af-borrar, .sigma-nd-quitar { width: 40px; height: 40px; border: 0; border-radius: 9px; background: transparent; color: var(--af-muted); display: grid; place-items: center;
        font-size: 19px; cursor: pointer; text-decoration: none; }
    .af-borrar:hover, .sigma-nd-quitar:hover { background: var(--af-danger-soft); color: var(--af-danger); }
    @media (max-width: 640px) {
        .af-filas-cab { display: none; }
        .af-fila, .sigma-nd-fila { grid-template-columns: minmax(0, 1fr) 40px; padding: 10px; border: 1px solid var(--af-line); border-radius: 12px; }
        .af-fila > *:not(.af-borrar), .sigma-nd-fila > *:not(.sigma-nd-quitar) { grid-column: 1; }
        .af-fila > .af-borrar, .sigma-nd-fila > .sigma-nd-quitar { grid-column: 2; grid-row: 1; }
    }
    .af-ya { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; font-size: 13px; color: var(--af-muted); }
    .sigma-co-chip { display: inline-flex; align-items: center; gap: 5px; padding: 4px 10px; border-radius: 999px; background: var(--af-cyan-soft); color: var(--af-cyan-dark); font-size: 12px; font-weight: 800; }
    .af-sugerir { padding: 12px 14px; border: 1px solid var(--af-line); border-radius: 12px; background: var(--af-canvas); }
    .af-sugerir p { margin: 0 0 8px; font-size: 13px; color: var(--af-muted); }
    .af-sugerir p b { color: var(--af-ink); }
    .af-sugerir-chips { display: flex; flex-wrap: wrap; gap: 6px; }
    .af-sug { display: inline-flex; align-items: center; gap: 4px; min-height: 34px; padding: 0 12px; border: 1px solid var(--af-line); border-radius: 999px;
        background: #fff; color: var(--af-ink); font: inherit; font-size: 13px; font-weight: 700; cursor: pointer; }
    .af-sug:hover { border-color: var(--af-cyan-dark); color: var(--af-cyan-dark); }
    .af-sug:focus-visible { outline: 3px solid rgba(22,198,201,.27); }

    /* ---- Botones ---- */
    .af-btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; min-height: 40px; padding: 0 16px; margin: 0;
        border: 1.5px solid transparent; border-radius: 10px; font: inherit; font-size: 13px; font-weight: 700; line-height: 1; cursor: pointer;
        text-decoration: none; white-space: nowrap; box-shadow: none; }
    .af-btn .mdi { font-size: 17px; }
    .af-btn:focus-visible { outline: 3px solid rgba(22,198,201,.27); outline-offset: 1px; }
    .af-btn[hidden] { display: none !important; }
    .af-btn.es-contorno { background: #fff; border-color: var(--af-blue); color: var(--af-blue); }
    .af-btn.es-contorno:hover { background: var(--af-blue-soft); border-color: var(--af-blue-dark); color: var(--af-blue-dark); }
    .af-btn.es-primario { background: var(--af-purple); border-color: var(--af-purple); color: #fff; }
    .af-btn.es-primario:hover { background: var(--af-purple-dark); border-color: var(--af-purple-dark); }
    .af-btn.es-secundario { background: var(--af-cyan-dark); border-color: var(--af-cyan-dark); color: #fff; }
    .af-btn.es-secundario:hover { background: #006872; border-color: #006872; }
    .af-btn.es-ghost { background: var(--af-purple-soft); border-color: var(--af-purple-soft); color: var(--af-purple-dark); }
    .af-btn.es-ghost:hover { background: #E6E0FF; }
    .af-btn.es-suave { background: #fff; border-color: var(--af-line); color: var(--af-ink); }
    .af-btn.es-suave .mdi { color: var(--af-purple); }
    .af-btn.es-suave:hover { border-color: #C9D1E0; background: var(--af-canvas); }
    .af-btn:disabled { opacity: .42; cursor: not-allowed; }
    .af-link-quitar { display: inline-flex; align-items: center; gap: 4px; font-size: 12.5px; font-weight: 700; color: var(--af-danger); text-decoration: none; }

    /* ---- La barra del pie: todo en una sola fila, siempre en el mismo lugar ---- */
    .af-pie { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; padding-top: 16px; margin-top: 4px; border-top: 1px solid var(--af-line); }
    .af-pie-donde { flex: 1 1 auto; text-align: center; font-size: 12.5px; font-weight: 700; color: var(--af-muted); }
    .af-pie-der { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
    .af-pie-acc { display: contents; }
    .af-pie-der .ButtonCerrar, .af-pie-der .af-cancelar { order: 1; }
    .af-pie-der #fpBtnSiguiente { order: 2; }
    .af-pie-der .af-guardar { order: 3; }
    /* en el centro la barra queda pegada abajo mientras se edita */
    .af-centro .af-pie { position: sticky; bottom: 0; z-index: 5; padding: 12px 14px; margin-top: 0; border: 1px solid var(--af-line); border-radius: 14px;
        background: rgba(255,255,255,.97); box-shadow: 0 -6px 18px rgba(15,23,42,.06); }
    .af-centro .sg-a3-ficha-sucio { display: none; align-items: center; gap: 2px; font-size: 12px; font-weight: 700; color: var(--af-warning); }
    .sg-a3-ficha.es-sucia .af-centro .sg-a3-ficha-sucio { display: inline-flex; }
    @media (max-width: 640px) { .af-pie-donde { order: -1; flex-basis: 100%; text-align: left; } .af-pie-der { flex: 1 1 auto; } }

    /* ---- Confirmacion al crear ---- */
    .af-listo { display: grid; gap: 20px; max-width: 760px; margin: 8px auto; text-align: center; }
    .af-listo-ico { width: 64px; height: 64px; margin: 0 auto; border-radius: 50%; background: var(--af-success-soft); color: var(--af-success); display: grid; place-items: center; font-size: 36px; }
    .af-listo h2 { margin: 0; font-size: 22px; font-weight: 800; color: var(--af-ink); }
    .af-listo > p { margin: -12px 0 0; font-size: 14px; color: var(--af-muted); }
    .af-listo > p b { color: var(--af-ink); }
    .af-listo-sig { margin: 0; font-size: 13px; font-weight: 800; color: #4A556D; text-align: left; }
    .af-listo-ops { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; text-align: left; }
    @media (max-width: 640px) { .af-listo-ops { grid-template-columns: minmax(0, 1fr); } }
    .af-listo-op { display: grid; gap: 6px; align-content: start; padding: 16px; border: 1.5px solid var(--af-line); border-radius: 14px; background: #fff;
        color: var(--af-ink); font: inherit; text-align: left; cursor: pointer; text-decoration: none; }
    .af-listo-op:hover { border-color: var(--af-blue); background: #FAFCFF; }
    .af-listo-op:focus-visible { outline: 3px solid rgba(22,198,201,.27); }
    .af-listo-op > i { width: 38px; height: 38px; border-radius: 10px; display: grid; place-items: center; font-size: 21px; }
    .af-listo-op.es-comp > i { background: var(--af-cyan-soft); color: var(--af-cyan-dark); }
    .af-listo-op.es-rep > i { background: #FFF4E0; color: #8F4E00; }
    .af-listo-op.es-centro > i { background: var(--af-purple-soft); color: var(--af-purple); }
    .af-listo-op b { font-size: 14.5px; }
    .af-listo-op span { font-size: 12.5px; color: var(--af-muted); line-height: 1.4; }
    .af-listo-pie { display: flex; justify-content: flex-end; gap: 8px; padding-top: 16px; border-top: 1px solid var(--af-line); }
    .af-oculto { display: none !important; }

    /* ---- combo con texto libre: se elige de la lista o se escribe y se crea ---- */
    .af-combo { position: relative; display: block; min-width: 0; }
    .af-combo input { padding-right: 36px !important; }
    .af-combo-btn { position: absolute; right: 2px; top: 50%; transform: translateY(-50%); width: 34px; height: 34px; border: 0; border-radius: 8px;
        background: transparent; color: var(--af-muted); display: grid; place-items: center; font-size: 19px; cursor: pointer; }
    .af-combo-btn:hover { background: var(--af-canvas); color: var(--af-ink); }
    #afComboLista { position: fixed; z-index: 100000; display: none; max-height: 240px; overflow: auto; padding: 4px; background: #fff;
        border: 1px solid var(--af-line, #E2E7F0); border-radius: 10px; box-shadow: 0 16px 36px -12px rgba(23,34,59,.35); font-size: 13.5px; color: #17223B; }
    #afComboLista.es-abierto { display: block; }
    #afComboLista button { display: flex; align-items: center; gap: 6px; width: 100%; min-height: 36px; padding: 0 10px; border: 0; border-radius: 8px;
        background: transparent; color: inherit; font: inherit; text-align: left; cursor: pointer; }
    #afComboLista button:hover, #afComboLista button.es-foco { background: #F2EFFF; color: #4820C9; }
    #afComboLista button.es-crear { color: #007F8A; font-weight: 700; border-top: 1px solid #EEF1F6; border-radius: 0 0 8px 8px; }
    #afComboLista .vacio { padding: 8px 10px; color: #68738A; font-size: 12.5px; }

    /* ---- foto por fila (componente o dato de placa) ---- */
    .af-fila-foto { position: relative; width: 44px; height: 40px; margin: 0; border: 1.5px dashed var(--af-input); border-radius: 9px; background: #FBFCFE;
        color: var(--af-muted); display: grid; place-items: center; font-size: 19px; cursor: pointer; overflow: hidden; }
    .af-fila-foto:hover { border-color: var(--af-cyan-dark); color: var(--af-cyan-dark); }
    .af-fila-foto input[type="file"] { position: absolute; inset: 0; opacity: 0; cursor: pointer; width: 100%; height: 100%; }
    .af-fila-foto img { width: 100%; height: 100%; object-fit: cover; display: block; }
    .af-fila-foto.con-foto { border-style: solid; border-color: var(--af-cyan-dark); }
    .af-filas-cab .c { text-align: center; }
    @media (max-width: 640px) { .af-fila-foto { width: 100%; } }
</style>

<script type="text/javascript">
    // Muestra los nombres de los documentos elegidos (aún sin subir).
    function sigmaDocsNombres(input) {
        var d = document.getElementById('sigmaDocsLista');
        if (!d) return;
        if (input.files && input.files.length) {
            var n = [];
            for (var i = 0; i < input.files.length; i++) n.push(input.files[i].name);
            d.textContent = n.join('  ·  ');
        } else { d.textContent = ''; }
    }
    function getRadWindow() {
        var oWindow = null;
        if (window.radWindow) oWindow = window.radWindow;
        else if (window.frameElement && window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
        return oWindow;
    }
    function closeWindow() {
        var window = getRadWindow();
        if (!window) return;
        if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
        window.close();
    }

    // Guardado: muestra el velo "Guardando…" SIN bloquear el postback.
    // Importante: NO retorna valor (este PushButton no reenvía si el
    // OnClientClick retorna). El velo se muestra con un setTimeout, después
    // de que corra la validación del botón: si algún campo falla,
    // Page_IsValid queda en false, se dice qué falta y no se muestra el velo.
    function sigmaGuardando() {
        setTimeout(function () {
            if (typeof Page_IsValid !== 'undefined' && Page_IsValid === false) { afMostrarFaltas(true); return; }
            var ov = document.getElementById('sigmaGuardandoOv');
            if (ov) ov.style.display = 'flex';
        }, 0);
    }

    // Al elegir una imagen: muestra el nombre, Quitar y la vista previa al
    // instante (sin subir todavía; sube al guardar).
    function sigmaPrevImg(input) {
        var name = document.getElementById('sigmaFileName');
        var quit = document.getElementById('sigmaQuitar');
        var img = document.getElementById('sigmaThumb');
        var caja = document.querySelector('.af-foto');
        if (input.files && input.files[0]) {
            if (name) name.textContent = input.files[0].name;
            if (quit) quit.style.display = 'inline-flex';
            if (img && window.FileReader) {
                var r = new FileReader();
                r.onload = function (e) { img.src = e.target.result; img.style.display = 'block'; if (caja) caja.classList.add('con-prev'); };
                r.readAsDataURL(input.files[0]);
            }
        } else {
            if (name) name.textContent = '';
            if (quit) quit.style.display = 'none';
            if (img) { img.src = ''; img.style.display = 'none'; }
            if (caja) caja.classList.remove('con-prev');
        }
    }
    function sigmaQuitarSel() {
        var input = document.getElementById('fuImagen');
        if (input) { input.value = ''; sigmaPrevImg(input); }
    }

    /* Soltar el archivo encima de la franja es lo mismo que elegirlo. */
    function afSoltar(zona, idInput, alCambiar) {
        if (!zona || zona.getAttribute('data-listo') === '1') return;
        zona.setAttribute('data-listo', '1');
        zona.addEventListener('dragover', function (e) { e.preventDefault(); zona.classList.add('es-encima'); });
        zona.addEventListener('dragleave', function () { zona.classList.remove('es-encima'); });
        zona.addEventListener('drop', function (e) {
            e.preventDefault(); zona.classList.remove('es-encima');
            var input = document.getElementById(idInput);
            if (!input || !e.dataTransfer || !e.dataTransfer.files.length) return;
            try { input.files = e.dataTransfer.files; } catch (x) { return; }
            alCambiar(input);
        });
    }

    // Crear un modelo al vuelo, sin ir al catálogo.
    function nuevoModelo() {
        var url = '<%=ResolveUrl("~/View/Activos/Modelos/ActivoModelo.aspx") %>?query=0';
        var M = (window.parent && window.parent.SigmaModal) ? window.parent.SigmaModal : window.SigmaModal;
        if (M && M.open) { M.open({ url: url, title: 'Nuevo modelo', width: 820, initialHeight: 560 }); }
        else { window.open(url, '_blank'); }
        return false;
    }
    /* La invoca el modal de modelo al cerrarse. Se define solo si la
       pagina que aloja el formulario no trajo el suyo. */
    window.refresh = window.refresh || function () { __doPostBack('', ''); };

    /* ---- Asistente: el paso vive en hdnPaso para sobrevivir a los
       postbacks parciales (cambiar el tipo recarga los modelos). ---- */
    var AF_PASOS = 6;
    function fpCampo() { return document.querySelector('[id$="hdnPaso"]'); }
    function fpActual() { var h = fpCampo(); var n = h ? parseInt(h.value, 10) : 1; return n >= 1 && n <= AF_PASOS ? n : 1; }
    function fpIr(n) {
        n = Math.max(1, Math.min(AF_PASOS, n || 1));
        var h = fpCampo(); if (h) h.value = n;
        document.querySelectorAll('.af-seccion').forEach(function (p) { p.classList.toggle('es-activo', +p.getAttribute('data-paso') === n); });
        document.querySelectorAll('.af-tip').forEach(function (p) { p.classList.toggle('es-activo', +p.getAttribute('data-paso') === n); });
        document.querySelectorAll('.af-paso').forEach(function (b) {
            var k = +b.getAttribute('data-ir');
            b.classList.toggle('es-activo', k === n);
            b.classList.toggle('es-hecho', k < n && !b.classList.contains('es-falta'));
            b.setAttribute('aria-current', k === n ? 'step' : 'false');
        });
        var ant = document.getElementById('fpBtnAnterior'), sig = document.getElementById('fpBtnSiguiente'), d = document.getElementById('fpDonde');
        if (ant) ant.hidden = n === 1;
        if (sig) sig.hidden = n === AF_PASOS;
        if (d) d.textContent = 'Paso ' + n + ' de ' + AF_PASOS;

        /* Al crear, Siguiente es lo principal hasta el ultimo paso; ahi
           Guardar pasa a morado. Al editar, Guardar es siempre lo principal. */
        var af = document.querySelector('.af');
        var g = document.querySelector('.af-guardar');
        if (af && g && af.classList.contains('af-es-nuevo')) {
            var final = n === AF_PASOS;
            g.classList.toggle('es-primario', final);
            g.classList.toggle('es-secundario', !final);
            if (sig) { sig.classList.toggle('es-primario', !final); sig.classList.toggle('es-contorno', final); }
        }
        return false;
    }
    /* Del paso se avanza solo si lo obligatorio de ESE paso esta completo. */
    function fpSiguiente() {
        var n = fpActual();
        if (!afValidarPaso(n)) { afMostrarFaltas(true); return false; }
        afMostrarFaltas(false);
        fpIr(n + 1);
        var c = document.querySelector('.af-cuerpo'); if (c && c.scrollIntoView && c.getBoundingClientRect().top < 0) c.scrollIntoView({ block: 'start' });
        return false;
    }

    /* ---- Validacion amable ----
       Cada obligatorio tiene un CustomValidator que llama a afRequerido. La
       funcion marca el campo (rotulo y borde en rojo + una frase de que
       hacer) y la barra de arriba junta lo que falta con un boton que lleva
       al campo. Nada de bordes rojos sin explicacion. */
    function afValor(id, libre) {
        var c = window.$find ? $find(id) : null;
        if (c && c.get_text) {
            var t = (c.get_text() || '').trim();
            if (c.get_emptyMessage && t === c.get_emptyMessage()) t = '';
            if (libre || t === '') return t;
            var it = c.findItemByText ? c.findItemByText(t) : null;
            return it && it.get_value() !== '' ? t : '';
        }
        var e = document.getElementById(id);
        return e ? (e.value || '').trim() : '';
    }
    function afMarcar(id, ok) {
        var e = document.getElementById(id);
        var f = e ? e.closest('.sigma-modal-field') : null;
        if (f) f.classList.toggle('es-falta', !ok);
    }
    function afRequerido(sender, args) { args.IsValid = afValor(sender.controltovalidate, false) !== ''; afMarcar(sender.controltovalidate, args.IsValid); }
    function afRequeridoLibre(sender, args) { args.IsValid = afValor(sender.controltovalidate, true) !== ''; afMarcar(sender.controltovalidate, args.IsValid); }
    /* compatibilidad con quien todavia llame al nombre viejo */
    function validaComboTexto(sender, args) { afRequeridoLibre(sender, args); }

    function afValidadores(dentro) {
        if (typeof Page_Validators === 'undefined') return [];
        return Array.prototype.filter.call(Page_Validators, function (v) {
            if (v.validationGroup !== 'Activo') return false;
            var e = document.getElementById(v.controltovalidate);
            return !dentro || (e && dentro.contains(e));
        });
    }
    function afValidarPaso(n) {
        var sec = document.querySelector('.af-seccion[data-paso="' + n + '"]');
        var ok = true;
        afValidadores(sec).forEach(function (v) { if (typeof ValidatorValidate === 'function') { ValidatorValidate(v); if (!v.isvalid) ok = false; } });
        return ok;
    }
    function afMostrarFaltas(irAlPrimero) {
        var caja = document.getElementById('afFaltan');
        var lista = document.getElementById('afFaltanLista');
        var faltan = Array.prototype.slice.call(document.querySelectorAll('.af .sigma-modal-field.es-falta'));
        document.querySelectorAll('.af-paso').forEach(function (b) {
            var sec = document.querySelector('.af-seccion[data-paso="' + b.getAttribute('data-ir') + '"]');
            b.classList.toggle('es-falta', !!(sec && sec.querySelector('.sigma-modal-field.es-falta')));
        });
        if (!caja || !lista) return;
        lista.innerHTML = '';
        faltan.forEach(function (f) {
            var lab = f.querySelector('label');
            var b = document.createElement('button');
            b.type = 'button';
            b.innerHTML = '<i class="mdi mdi-arrow-right"></i>';
            b.insertBefore(document.createTextNode((lab ? lab.textContent : 'Campo').replace('*', '').trim()), b.firstChild);
            b.onclick = function () { afIrCampo(f); };
            lista.appendChild(b);
        });
        var t = document.getElementById('afFaltanTit');
        if (t) t.textContent = faltan.length === 1 ? 'Falta 1 dato para poder guardar' : 'Faltan ' + faltan.length + ' datos para poder guardar';
        caja.classList.toggle('es-visible', faltan.length > 0);
        if (irAlPrimero && faltan.length) afIrCampo(faltan[0]);
        fpIr(fpActual());
    }
    function afIrCampo(f) {
        var sec = f.closest('.af-seccion');
        if (sec) fpIr(+sec.getAttribute('data-paso'));
        var inp = f.querySelector('input[type="text"]:not([type="hidden"]), textarea');
        setTimeout(function () { if (inp) { inp.focus(); if (inp.scrollIntoView) inp.scrollIntoView({ block: 'center' }); } }, 30);
    }
    /* Al corregir un campo marcado, se vuelve a mirar ese campo solo. */
    function afRevisar(f) {
        afValidadores(f).forEach(function (v) { if (typeof ValidatorValidate === 'function') ValidatorValidate(v); });
        if (document.getElementById('afFaltan') && document.getElementById('afFaltan').classList.contains('es-visible')) afMostrarFaltas(false);
    }
    document.addEventListener('focusout', function (e) {
        var f = e.target && e.target.closest ? e.target.closest('.af .sigma-modal-field.es-falta') : null;
        if (f) setTimeout(function () { afRevisar(f); }, 200);
    });

    /* ---- ¿Depende de otra maquina? Si/No y, si es Si, cual ---- */
    function afPadreCombo() { var e = document.querySelector('.af-padre .RadComboBox'); return e && window.$find ? $find(e.id) : null; }
    /* No se llama afDepende: el radio se llama asi y, dentro del form, el
       nombre del control tapa a la funcion en el onclick (trampa conocida). */
    function afMarcarDepende(si) {
        var w = document.querySelector('.af-padre'); if (!w) return;
        w.hidden = !si;
        if (!si) { var c = afPadreCombo(); if (c && c.get_items().get_count()) c.get_items().getItem(0).select(); }
    }
    function afIniciarDepende() {
        var c = afPadreCombo(), si = document.getElementById('afDependeSi'), no = document.getElementById('afDependeNo');
        if (!si || !no) return;
        var tiene = c && c.get_value && c.get_value() !== '';
        si.checked = !!tiene; no.checked = !tiene;
        var w = document.querySelector('.af-padre'); if (w) w.hidden = !tiene;
    }

    function fpIniciar() {
        if (!document.querySelector('.af-seccion')) return;
        fpIr(fpActual());
        afIniciarDepende();
        ndCabecera();
        afSoltar(document.querySelector('.af-foto'), 'fuImagen', sigmaPrevImg);
        afSoltar(document.querySelector('.af-docs'), 'fuDocs', sigmaDocsNombres);
        var cont = document.getElementById('coContainer');
        if (cont && !cont.children.length && document.querySelector('.af-es-nuevo')) coAgregar('', '', true);
        vaCabecera(); meCabecera();
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fpIniciar); else setTimeout(fpIniciar, 0);
    window.addEventListener('load', function () {
        afIniciarDepende();
        if (window.Sys && Sys.WebForms) Sys.WebForms.PageRequestManager.getInstance().add_endRequest(fpIniciar);
    });

    /* ---- Combo con texto libre ----
       Una caja que se elige de la lista o se escribe: lo que no existe se crea
       al guardar. Las opciones vienen del servidor en AF_OPC. */
    function afComboHtml(nombre, cual, ph, etiqueta) {
        return '<span class="af-combo"><input type="text" name="' + nombre + '" class="sigma-nd-txt" data-combo="' + cual +
               '" placeholder="' + ph + '" aria-label="' + etiqueta + '" autocomplete="off" />' +
               '<button type="button" class="af-combo-btn" tabindex="-1" aria-label="Ver opciones"><i class="mdi mdi-chevron-down"></i></button></span>';
    }
    var afComboInput = null;
    function afComboLista() {
        var l = document.getElementById('afComboLista');
        if (!l) { l = document.createElement('div'); l.id = 'afComboLista'; l.setAttribute('role', 'listbox'); document.body.appendChild(l); }
        return l;
    }
    function afComboAbrir(inp) {
        var opc = (window.AF_OPC && AF_OPC[inp.getAttribute('data-combo')]) || [];
        var l = afComboLista(), t = (inp.value || '').trim(), tl = t.toLowerCase();
        afComboInput = inp;
        l.innerHTML = '';
        var exacta = false, n = 0;
        opc.forEach(function (o) {
            if (tl && o.toLowerCase().indexOf(tl) === -1) return;
            if (o.toLowerCase() === tl) exacta = true;
            if (n++ > 60) return;
            var b = document.createElement('button'); b.type = 'button'; b.textContent = o;
            b.onmousedown = function (e) { e.preventDefault(); afComboElegir(o); };
            l.appendChild(b);
        });
        if (t && !exacta) {
            var c = document.createElement('button'); c.type = 'button'; c.className = 'es-crear';
            c.innerHTML = '<i class="mdi mdi-plus"></i>'; c.appendChild(document.createTextNode('Crear «' + t + '»'));
            c.onmousedown = function (e) { e.preventDefault(); afComboElegir(t); };
            l.appendChild(c);
        }
        if (!l.children.length) { var v = document.createElement('div'); v.className = 'vacio'; v.textContent = 'Escribe para crear uno nuevo.'; l.appendChild(v); }
        var r = inp.getBoundingClientRect();
        l.style.left = r.left + 'px'; l.style.width = Math.max(r.width, 200) + 'px';
        var abajo = window.innerHeight - r.bottom;
        if (abajo < 200 && r.top > abajo) { l.style.top = ''; l.style.bottom = (window.innerHeight - r.top + 4) + 'px'; }
        else { l.style.bottom = ''; l.style.top = (r.bottom + 4) + 'px'; }
        l.classList.add('es-abierto');
    }
    function afComboCerrar() { var l = document.getElementById('afComboLista'); if (l) l.classList.remove('es-abierto'); afComboInput = null; }
    function afComboElegir(v) {
        if (!afComboInput) return;
        afComboInput.value = v;
        afComboInput.dispatchEvent(new Event('change', { bubbles: true }));
        afComboCerrar();
    }
    document.addEventListener('focusin', function (e) { if (e.target.matches && e.target.matches('input[data-combo]')) afComboAbrir(e.target); });
    document.addEventListener('input', function (e) { if (e.target.matches && e.target.matches('input[data-combo]')) afComboAbrir(e.target); });
    document.addEventListener('focusout', function (e) { if (e.target === afComboInput) setTimeout(function () { if (document.activeElement !== afComboInput) afComboCerrar(); }, 120); });
    document.addEventListener('click', function (e) {
        var b = e.target.closest ? e.target.closest('.af-combo-btn') : null;
        if (b) { var i = b.parentNode.querySelector('input'); i.focus(); afComboAbrir(i); }
    });
    document.addEventListener('keydown', function (e) {
        if (!afComboInput || e.target !== afComboInput) return;
        var l = afComboLista(), bs = Array.prototype.slice.call(l.querySelectorAll('button')), k = bs.indexOf(l.querySelector('.es-foco'));
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
            e.preventDefault(); if (!bs.length) return;
            k = e.key === 'ArrowDown' ? Math.min(bs.length - 1, k + 1) : Math.max(0, k - 1);
            bs.forEach(function (x, j) { x.classList.toggle('es-foco', j === k); });
            bs[k].scrollIntoView({ block: 'nearest' });
        } else if (e.key === 'Enter') {
            e.preventDefault();
            var f = l.querySelector('.es-foco'); if (f) f.onmousedown(e); else afComboCerrar();
        } else if (e.key === 'Escape') afComboCerrar();
    });
    window.addEventListener('scroll', function () { if (afComboInput) afComboAbrir(afComboInput); }, true);

    /* La foto de una fila: se ve al instante y sube al guardar. */
    function afFotoHtml(nombre) {
        return '<label class="af-fila-foto" title="Agregar una foto"><i class="mdi mdi-camera-plus-outline"></i>' +
               '<input type="file" name="' + nombre + '" accept="image/*" onchange="afFotoFila(this)" aria-label="Foto" /></label>';
    }
    function afFotoFila(input) {
        var caja = input.closest('.af-fila-foto'); if (!caja) return;
        var viejo = caja.querySelector('img'); if (viejo) viejo.remove();
        var ico = caja.querySelector('i');
        if (input.files && input.files[0] && window.FileReader) {
            var r = new FileReader();
            r.onload = function (e) { var img = document.createElement('img'); img.src = e.target.result; img.alt = ''; caja.insertBefore(img, input); if (ico) ico.style.display = 'none'; caja.classList.add('con-foto'); caja.title = input.files[0].name; };
            r.readAsDataURL(input.files[0]);
        } else { if (ico) ico.style.display = ''; caja.classList.remove('con-foto'); caja.title = 'Agregar una foto'; }
    }

    function afQuitarFila(b, alQuitar) { b.closest('.af-fila, .sigma-nd-fila').remove(); if (alQuitar) alQuitar(); }

    // Componentes nuevos: nombre + que es + donde va + foto
    function coAgregar(nombre, tipo, sinFoco) {
        var cont = document.getElementById('coContainer'); if (!cont) return;
        /* una sugerencia llena la primera fila vacia antes de agregar otra */
        var row = null;
        if (nombre) cont.querySelectorAll('.co-row').forEach(function (r) { if (!row && !r.querySelector('[name="co_nombre"]').value.trim()) row = r; });
        if (!row) {
            row = document.createElement('div');
            row.className = 'af-fila co-row';
            row.innerHTML =
                '<input type="text" name="co_nombre" class="sigma-nd-txt" aria-label="Nombre del componente" placeholder="Ej.: Motor principal" />' +
                afComboHtml('co_tipo', 'tipos', 'Ej.: Motor', 'Qué es') +
                afComboHtml('co_lado', 'lados', 'Ej.: Lado motor', 'Dónde va') +
                afFotoHtml('co_foto') +
                '<button type="button" class="af-borrar" title="Quitar esta fila" aria-label="Quitar esta fila" onclick="afQuitarFila(this, coCabecera)"><i class="mdi mdi-trash-can-outline"></i></button>';
            cont.appendChild(row);
        }
        if (nombre) { row.querySelector('[name="co_nombre"]').value = nombre; row.querySelector('[name="co_tipo"]').value = tipo || nombre; }
        coCabecera();
        if (!sinFoco) row.querySelector('input[name="' + (nombre ? 'co_lado' : 'co_nombre') + '"]').focus();
    }

    // Variables de condicion: que se mide + unidad + rango normal
    function vaAgregar(sinFoco) {
        var cont = document.getElementById('vaContainer'); if (!cont) return;
        var row = document.createElement('div');
        row.className = 'af-fila af-fila-var va-row';
        row.innerHTML =
            afComboHtml('va_nombre', 'vars', 'Ej.: Temperatura de la cámara', 'Qué se mide') +
            '<select name="va_unidad" class="sigma-nd-sel" aria-label="Unidad"><option value="">Unidad…</option>' + AF_UNIDADES + '</select>' +
            '<input type="text" name="va_min" class="sigma-nd-txt" inputmode="decimal" aria-label="Mínimo normal" placeholder="Mín." />' +
            '<input type="text" name="va_max" class="sigma-nd-txt" inputmode="decimal" aria-label="Máximo normal" placeholder="Máx." />' +
            '<button type="button" class="af-borrar" title="Quitar esta fila" aria-label="Quitar esta fila" onclick="afQuitarFila(this, vaCabecera)"><i class="mdi mdi-trash-can-outline"></i></button>';
        cont.appendChild(row);
        vaCabecera();
        if (!sinFoco) row.querySelector('input').focus();
    }
    function vaCabecera() { var c = document.getElementById('vaCab'), k = document.getElementById('vaContainer'); if (c && k) c.style.display = k.children.length ? '' : 'none'; }

    // Medidores (contadores): nombre + unidad + lectura de hoy
    function meAgregar(sinFoco) {
        var cont = document.getElementById('meContainer'); if (!cont) return;
        var row = document.createElement('div');
        row.className = 'af-fila af-fila-med me-row';
        row.innerHTML =
            afComboHtml('me_nombre', 'meds', 'Ej.: Horas de marcha', 'Qué cuenta') +
            '<select name="me_unidad" class="sigma-nd-sel" aria-label="Unidad"><option value="">Unidad…</option>' + AF_UNIDADES + '</select>' +
            '<input type="text" name="me_valor" class="sigma-nd-txt" inputmode="decimal" aria-label="Lectura de hoy" placeholder="Ej.: 1250" />' +
            '<button type="button" class="af-borrar" title="Quitar esta fila" aria-label="Quitar esta fila" onclick="afQuitarFila(this, meCabecera)"><i class="mdi mdi-trash-can-outline"></i></button>';
        cont.appendChild(row);
        meCabecera();
        if (!sinFoco) row.querySelector('input').focus();
    }
    function meCabecera() { var c = document.getElementById('meCab'), k = document.getElementById('meContainer'); if (c && k) c.style.display = k.children.length ? '' : 'none'; }
    function coCabecera() {
        var cab = document.getElementById('coCab'), cont = document.getElementById('coContainer');
        if (cab && cont) cab.style.display = cont.children.length ? '' : 'none';
    }
    function coSugerir(b) { coAgregar(b.getAttribute('data-nombre'), b.getAttribute('data-nombre')); }

    // Opciones de unidad (para las filas nuevas), armadas en el servidor.
    var AF_UNIDADES = '<%= BuildUnidadOptions() %>';
    var ND_UNIT_OPTIONS = '<option value="">Sin unidad</option>' + AF_UNIDADES;
    // Opciones de los combos con texto libre: tipos, lugares, variables y contadores.
    var AF_OPC = <%= OpcionesCombosJson() %>;
    function ndAgregar() {
        var cont = document.getElementById('ndContainer');
        if (!cont) return;
        var row = document.createElement('div');
        row.className = 'sigma-nd-fila nd-row';
        row.innerHTML =
            '<input type="text" name="nd_nombre" class="sigma-nd-txt" aria-label="Nombre del dato" placeholder="Ej.: Potencia" />' +
            '<input type="text" name="nd_valor" class="sigma-nd-txt" aria-label="Valor" placeholder="Ej.: 5,5" />' +
            '<select name="nd_unidad" class="sigma-nd-sel" aria-label="Unidad">' + ND_UNIT_OPTIONS + '</select>' +
            afFotoHtml('nd_foto') +
            '<button type="button" class="sigma-nd-quitar" title="Quitar este dato" aria-label="Quitar este dato" onclick="afQuitarFila(this, ndCabecera)"><i class="mdi mdi-trash-can-outline"></i></button>';
        cont.appendChild(row);
        ndCabecera();
        var inp = row.querySelector('input[name="nd_nombre"]');
        if (inp) inp.focus();
    }
    function ndCabecera() {
        var cab = document.getElementById('ndCab');
        if (cab) cab.style.display = document.querySelectorAll('.af .sigma-nd-fila:not([style*="none"])').length ? '' : 'none';
    }

    // Quita un dato ya guardado: vacía su valor (al Guardar se elimina del activo)
    // y oculta la fila para dar feedback.
    function ndQuitarDato(a) {
        var field = a.closest('.sigma-nd-fila');
        if (!field) return;
        var txt = field.querySelector('input[type="text"]');
        var sel = field.querySelector('select');
        if (txt) txt.value = '';
        if (sel) sel.selectedIndex = 0;
        field.style.display = 'none';
        ndCabecera();
    }

    /* ---- Confirmacion: el proximo paso sugerido ---- */
    function afSeguirConPartes() {
        var l = document.getElementById('afListo'), f = document.querySelector('.af');
        if (l) l.classList.add('af-oculto');
        if (f) f.classList.remove('af-oculto');
        fpIr(4);
        coAgregar('', '', false);
        return false;
    }
    function afAbrirCentro(url) {
        try { (window.top || window).location.href = url; } catch (e) { window.open(url, '_blank'); }
        return false;
    }
</script>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>

<%-- ============ CONFIRMACION AL CREAR ============
     Guardar un activo nuevo no cierra la ventana a ciegas: dice que quedo
     creado y sugiere lo que normalmente sigue. --%>
<asp:Panel ID="pnlListo" runat="server" Visible="false" ClientIDMode="Static">
    <div class="af-listo" id="afListo">
        <span class="af-listo-ico"><i class="mdi mdi-check-bold"></i></span>
        <h2><asp:Literal ID="litListoTitulo" runat="server" /></h2>
        <p><asp:Literal ID="litListoTexto" runat="server" /></p>
        <p class="af-listo-sig">¿Qué quieres hacer ahora?</p>
        <div class="af-listo-ops">
            <button type="button" class="af-listo-op es-comp" onclick="return afSeguirConPartes();">
                <i class="mdi mdi-puzzle-outline"></i><b>Agregar sus componentes</b>
                <span>Motor, rodamientos, sellos… lo que quieras seguir por separado.</span>
            </button>
            <asp:HyperLink ID="hlListoRepuestos" runat="server" CssClass="af-listo-op es-rep">
                <i class="mdi mdi-package-variant-closed"></i><b>Registrar sus repuestos</b>
                <span>Lo que se compra para este equipo y se guarda en bodega.</span>
            </asp:HyperLink>
            <asp:HyperLink ID="hlListoCentro" runat="server" CssClass="af-listo-op es-centro" NavigateUrl="javascript:void(0)">
                <i class="mdi mdi-view-dashboard-outline"></i><b>Abrir su centro 360°</b>
                <span>Su resumen, órdenes, historial y condición.</span>
            </asp:HyperLink>
        </div>
        <div class="af-listo-pie">
            <asp:HyperLink ID="hlListoOtro" runat="server" CssClass="af-btn es-contorno"><i class="mdi mdi-plus"></i>Crear otro activo</asp:HyperLink>
            <button type="button" class="af-btn es-primario" onclick="closeWindow(); return false;"><i class="mdi mdi-check"></i>Listo</button>
        </div>
    </div>
</asp:Panel>

<asp:Panel ID="pnlSecciones" runat="server" CssClass="af">

    <asp:HiddenField ID="hdnPaso" runat="server" Value="1" />

    <%-- ============ RIEL: pasos + ayuda del paso ============ --%>
    <aside class="af-rail">
        <nav class="af-pasos" aria-label="Pasos de la ficha">
            <button type="button" class="af-paso" data-ir="1" onclick="fpIr(1)"><span class="af-n"><span>1</span><i class="mdi mdi-check"></i></span><span><b>Información básica</b><small>Qué es el equipo</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="2" onclick="fpIr(2)"><span class="af-n"><span>2</span><i class="mdi mdi-check"></i></span><span><b>Ubicación</b><small>Dónde está</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="3" onclick="fpIr(3)"><span class="af-n"><span>3</span><i class="mdi mdi-check"></i></span><span><b>Datos técnicos</b><small>Placa, año y documentos</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="4" onclick="fpIr(4)"><span class="af-n"><span>4</span><i class="mdi mdi-check"></i></span><span><b>Componentes</b><small><asp:Literal ID="litPartesRail" runat="server" Text="Motor, rodamientos…" /></small></span></button>
            <button type="button" class="af-paso" data-ir="5" onclick="fpIr(5)"><span class="af-n"><span>5</span><i class="mdi mdi-check"></i></span><span><b>Variables</b><small><asp:Literal ID="litVarsRail" runat="server" Text="Qué se mide: temperatura…" /></small></span></button>
            <button type="button" class="af-paso" data-ir="6" onclick="fpIr(6)"><span class="af-n"><span>6</span><i class="mdi mdi-check"></i></span><span><b>Medidores</b><small><asp:Literal ID="litMedsRail" runat="server" Text="Horas, ciclos, kilómetros" /></small></span></button>
        </nav>

        <div class="af-tip" data-paso="1"><i class="mdi mdi-information-variant"></i><div><b>Completa lo principal.</b> Con el nombre, el tipo, el estado, la criticidad y la planta ya puedes guardar. Lo demás lo agregas cuando quieras.</div></div>
        <div class="af-tip" data-paso="2"><i class="mdi mdi-information-variant"></i><div><b>Indica dónde está.</b> Si depende de una máquina más grande, como el compresor de una cámara de frío, marca «Sí» y elígela: quedará como su subactivo.</div></div>
        <div class="af-tip" data-paso="3"><i class="mdi mdi-information-variant"></i><div><b>Este paso es opcional.</b> Copia lo que dice la placa o el manual del equipo. Puedes hacerlo ahora o después, desde su ficha.</div></div>
        <div class="af-tip" data-paso="4"><i class="mdi mdi-information-variant"></i><div><b>¿Le importa esa pieza en particular?</b> Es un componente. <b>¿Da lo mismo cuál uses de la bodega?</b> Es un repuesto y se agrega después.</div></div>
        <div class="af-tip" data-paso="5"><i class="mdi mdi-information-variant"></i><div><b>Este paso es opcional.</b> Una variable dice <b>cómo está</b> el equipo: la temperatura, la presión, la vibración. Si anotas el rango normal, SIGMA avisa cuando una lectura se sale.</div></div>
        <div class="af-tip" data-paso="6"><i class="mdi mdi-information-variant"></i><div><b>Este paso es opcional.</b> Un medidor dice <b>cuánto ha trabajado</b>: horas de marcha, ciclos, kilómetros. Sirve para programar el mantenimiento por uso y no solo por calendario.</div></div>

        <%-- Solo en el centro: quien lo creo y que cuelga de el. --%>
        <asp:Panel ID="pnlSobre" runat="server" Visible="false" CssClass="af-sobre">
            <h4>Sobre esta ficha</h4>
            <asp:Literal ID="litAuditoriaPie" runat="server" />
            <asp:Literal ID="litSobreEstructura" runat="server" />
        </asp:Panel>
    </aside>

    <div class="af-cuerpo">

        <%-- Lo que falta para guardar, con un boton que lleva a cada campo. --%>
        <div class="af-faltan" id="afFaltan" role="alert" aria-live="assertive">
            <i class="mdi mdi-alert-circle-outline"></i>
            <div><b id="afFaltanTit">Faltan datos para poder guardar</b><span>Toca cada uno para ir a completarlo.</span>
                <div class="af-faltan-lista" id="afFaltanLista"></div></div>
        </div>

        <%-- ============ PASO 1 · INFORMACIÓN BÁSICA ============ --%>
        <section class="af-seccion" data-paso="1">
            <header class="af-cab"><i class="mdi mdi-cog-outline"></i><div><h3>Información básica</h3><p>Lo que identifica al equipo.</p></div></header>

            <span class="af-oculto"><asp:Label ID="lblId" runat="server"></asp:Label></span>

            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Código</label>
                    <%-- El prefijo lo pone el sistema; el resto lo escribe quien
                         crea el activo. Van juntos para que se lea como UN codigo. --%>
                    <div class="sg-codigo">
                        <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" UpperCase="true" ReadOnly="true" />
                    </div>
                    <span class="sigma-modal-ayuda">Si lo dejas vacío, se numera solo.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Nombre <span class="req">*</span></label>
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" placeholder="Ej.: Cámara de frío 1" />
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Escribe cómo le dicen al equipo en la planta.</span>
                    <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Tipo <span class="req">*</span></label>
                    <%-- Texto libre (bloque 342): si el tipo no existe, se escribe y se crea al guardar. --%>
                    <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                        OnSelectedIndexChanged="cboTipo_SelectedIndexChanged" Filter="Contains" Width="100%"
                        AllowCustomText="true" EmptyMessage="Elige o escribe uno nuevo" />
                    <span class="sigma-modal-ayuda">¿No está? Escríbelo y se crea al guardar.</span>
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige el tipo de la lista o escribe uno nuevo.</span>
                    <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequeridoLibre" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Modelo</label>
                    <rad:RadComboBox2 ID="cboModelo" runat="server" AutoPostBack="true"
                        OnSelectedIndexChanged="cboModelo_SelectedIndexChanged" Filter="Contains" Width="100%"
                        AllowCustomText="true" EmptyMessage="Elige o escribe uno nuevo" />
                    <span class="sigma-modal-ayuda">Muestra los de ese tipo y esa marca. ¿No está? Escríbelo y se crea.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Estado <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboEstado" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige cómo está el equipo hoy.</span>
                    <asp:CustomValidator ID="cvEstado" runat="server" ControlToValidate="cboEstado" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Criticidad <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboCriticidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda">¿Qué tan grave es si se detiene?</span>
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige qué tan grave es si se detiene.</span>
                    <asp:CustomValidator ID="cvCriticidad" runat="server" ControlToValidate="cboCriticidad" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Marca</label>
                    <rad:RadComboBox2 ID="cboFabricante" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                        OnSelectedIndexChanged="cboFabricante_Changed" OnTextChanged="cboFabricante_Changed" Filter="Contains" Width="100%" MaxLength="200"
                        AllowCustomText="true" EmptyMessage="Elige o escribe una nueva" />
                    <span class="sigma-modal-ayuda">¿No está? Escríbela y se crea al guardar.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>N° de serie</label>
                    <WebControls:TextBox2 ID="txtSerie" runat="server" MaxLength="100" placeholder="Está en la placa del equipo" />
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>Descripción</label>
                    <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" placeholder="Para qué sirve o algo que convenga saber" />
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>Foto del equipo</label>
                    <div class="af-drop af-foto">
                        <span class="af-drop-ico">
                            <asp:Panel ID="pnlSinImagen" runat="server" CssClass="af-foto-vacia"><i class="mdi mdi-image-outline"></i></asp:Panel>
                            <asp:Panel ID="pnlImagenActual" runat="server" Visible="false" CssClass="af-foto-actual">
                                <a id="lnkImagenActual" runat="server" target="_blank" rel="noopener" title="Ampliar">
                                    <img id="imgActual" runat="server" alt="Foto actual del equipo" data-ampliar="1" />
                                </a>
                            </asp:Panel>
                            <img id="sigmaThumb" alt="Vista previa" style="display:none" />
                        </span>
                        <span class="af-drop-txt">
                            <b>Arrastra una foto aquí</b>
                            <span>PNG o JPG. Ayuda a reconocer el equipo en la planta.</span>
                            <span id="sigmaFileName" class="sigma-img-name"></span>
                            <asp:Panel ID="pnlQuitarImagen" runat="server" Visible="false" CssClass="af-quitar-foto">
                                <asp:CheckBox ID="chkQuitarImagen" runat="server" Text="Quitar la foto actual al guardar" />
                            </asp:Panel>
                        </span>
                        <span class="af-drop-acc">
                            <a id="sigmaQuitar" href="javascript:void(0)" onclick="sigmaQuitarSel()" class="af-link-quitar" style="display:none;"><i class="mdi mdi-close"></i>Quitar</a>
                            <label for="fuImagen" class="af-btn es-suave"><i class="mdi mdi-camera-outline"></i>Elegir foto</label>
                        </span>
                        <asp:FileUpload ID="fuImagen" runat="server" accept="image/*" ClientIDMode="Static" onchange="sigmaPrevImg(this)" style="display:none;" />
                    </div>
                </div>
            </div>
        </section>

        <%-- ============ PASO 2 · UBICACIÓN ============ --%>
        <section class="af-seccion" data-paso="2">
            <header class="af-cab"><i class="mdi mdi-map-marker-outline"></i><div><h3>Ubicación</h3><p>En qué planta y área está el equipo.</p></div></header>

            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Planta <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige la planta donde está el equipo.</span>
                    <asp:CustomValidator ID="cvPlanta" runat="server" ControlToValidate="cboPlanta" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Área</label>
                    <rad:RadComboBox2 ID="cboArea" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda">Ej.: Refrigeración › Línea 1.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Centro de costo</label>
                    <rad:RadComboBox2 ID="cboCentroCosto" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>¿Depende de otra máquina?</label>
                    <div class="af-pills" role="radiogroup" aria-label="¿Depende de otra máquina?">
                        <input type="radio" name="afDependeOpc" id="afDependeNo" onclick="afMarcarDepende(false)" /><label for="afDependeNo">No, es una máquina principal</label>
                        <input type="radio" name="afDependeOpc" id="afDependeSi" onclick="afMarcarDepende(true)" /><label for="afDependeSi">Sí, depende de otra</label>
                    </div>
                    <span class="sigma-modal-ayuda">Si depende de una más grande, quedará como su <b>subactivo</b>. Ej.: el compresor de una cámara de frío.</span>
                </div>
                <div class="sigma-modal-field af-padre" hidden>
                    <label>¿De cuál máquina depende?</label>
                    <rad:RadComboBox2 ID="cboPadre" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                </div>
            </div>
        </section>

        <%-- ============ PASO 3 · DATOS TÉCNICOS ============ --%>
        <section class="af-seccion" data-paso="3">
            <header class="af-cab"><i class="mdi mdi-tune-variant"></i><div><h3>Datos técnicos</h3><p>Año, puesta en marcha, datos de la placa y documentos.</p></div></header>

            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Año de fabricación</label>
                    <rad:RadComboBox2 ID="cboAnio" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                </div>
                <div class="sigma-modal-field">
                    <label>Puesta en marcha</label>
                    <div class="sigma-modal-fecha">
                        <WebControls:Calendar ID="calPuestaMarcha" runat="server" />
                    </div>
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>¿Está en uso? <span class="req">*</span></label>
                    <div class="af-linea">
                        <div class="af-pills">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="Sí" GroupName="Habilitado" Checked="true" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="No" GroupName="Habilitado" />
                        </div>
                        <span class="sigma-modal-ayuda">Si eliges «No», deja de aparecer en las listas, pero su historia se conserva.</span>
                    </div>
                </div>
            </div>

            <%-- Datos de placa: nombre · valor · unidad, propios del activo. --%>
            <asp:Panel ID="pnlDatosTecnicos" runat="server">
                <p class="af-sub">Datos de placa<small>Lo que dice la placa o el manual. Ej.: Potencia 5,5 kW. La foto de cada dato queda en Documentos con su nombre.</small></p>
                <div class="af-filas-cab" id="ndCab"><span>Nombre</span><span>Valor</span><span>Unidad</span><span class="c">Foto</span><span></span></div>
                <div class="af-filas">
                    <asp:Repeater ID="rptDatos" runat="server" OnItemDataBound="rptDatos_ItemDataBound">
                        <ItemTemplate>
                            <div class="sigma-nd-fila">
                                <label><%# Server.HtmlEncode(Convert.ToString(Eval("ate_nombre"))) %></label>
                                <asp:HiddenField runat="server" ID="hdnAte" Value='<%# Eval("ate_id") %>' />
                                <asp:TextBox runat="server" ID="txtValor" Text='<%# Eval("valor_edit") %>' MaxLength="200" CssClass="sigma-nd-txt" />
                                <asp:DropDownList runat="server" ID="ddlUnidad" CssClass="sigma-nd-sel" />
                                <label class="af-fila-foto" title="Agregar una foto de este dato"><i class="mdi mdi-camera-plus-outline"></i><asp:FileUpload runat="server" ID="fuDato" accept="image/*" onchange="afFotoFila(this)" /></label>
                                <a href="javascript:void(0)" onclick="ndQuitarDato(this)" title="Quitar este dato" aria-label="Quitar este dato" class="sigma-nd-quitar"><i class="mdi mdi-trash-can-outline"></i></a>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                    <div id="ndContainer" class="af-filas"></div>
                </div>
                <button type="button" class="af-btn es-suave" style="margin-top:10px" onclick="ndAgregar()"><i class="mdi mdi-plus"></i>Agregar dato</button>
            </asp:Panel>

            <%-- Documentos: manuales, planos, certificados. --%>
            <div>
                <p class="af-sub">Documentos<small>Manuales, planos o certificados.</small></p>
                <asp:Repeater ID="rptArchivos" runat="server" OnItemCommand="rptArchivos_ItemCommand" OnItemDataBound="rptArchivos_ItemDataBound">
                    <HeaderTemplate><div class="sigma-doc-lista"></HeaderTemplate>
                    <ItemTemplate>
                        <div class="sigma-doc">
                            <i class='mdi <%# (bool)Eval("es_imagen") ? "mdi-image-outline" : "mdi-file-document-outline" %>'></i>
                            <span class="nom"><%# Server.HtmlEncode(Convert.ToString(Eval("arc_nombre"))) %></span>
                            <asp:HyperLink runat="server" Target="_blank" CssClass="ver"
                                NavigateUrl='<%# VerUrl((int)Eval("arc_id")) %>'><i class="mdi mdi-open-in-new"></i> Ver</asp:HyperLink>
                            <asp:LinkButton runat="server" CssClass="quitar" CommandName="quitar" CommandArgument='<%# Eval("arc_id") %>'
                                OnClientClick="return confirm('¿Quitar este documento del equipo?');"><i class="mdi mdi-close"></i> Quitar</asp:LinkButton>
                        </div>
                    </ItemTemplate>
                    <FooterTemplate></div></FooterTemplate>
                </asp:Repeater>

                <asp:Panel ID="pnlSubirDocs" runat="server" CssClass="af-drop af-docs">
                    <span class="af-drop-ico"><i class="mdi mdi-file-document-outline"></i></span>
                    <span class="af-drop-txt">
                        <b>Arrastra aquí manuales, planos o certificados</b>
                        <span>PDF o imágenes. Puedes subir varios a la vez.</span>
                        <span id="sigmaDocsLista"></span>
                    </span>
                    <span class="af-drop-acc">
                        <label for="fuDocs" class="af-btn es-suave"><i class="mdi mdi-upload"></i>Elegir archivos</label>
                    </span>
                    <asp:FileUpload ID="fuDocs" runat="server" AllowMultiple="true" ClientIDMode="Static"
                        accept=".pdf,image/*" onchange="sigmaDocsNombres(this)" style="display:none;" />
                </asp:Panel>
            </div>
        </section>

        <%-- ============ PASO 4 · PARTES ============
             Las partes del equipo que se quieren seguir, agregadas aqui mismo. --%>
        <section class="af-seccion" data-paso="4">
            <header class="af-cab"><i class="mdi mdi-puzzle-outline"></i><div><h3>Componentes</h3><p>Las partes del equipo que quieres seguir por separado: el motor, un rodamiento, una válvula.</p></div></header>

            <asp:Panel ID="pnlComponentes" runat="server" CssClass="af-grid">
                <div class="af-ancho">
                    <asp:Literal ID="litComponentes" runat="server" />
                    <div class="af-filas-cab" id="coCab" style="display:none"><span>Nombre del componente</span><span>Qué es</span><span>Dónde va</span><span class="c">Foto</span><span></span></div>
                    <div id="coContainer" class="af-filas"></div>
                    <button type="button" class="af-btn es-suave" style="margin-top:10px" onclick="coAgregar()"><i class="mdi mdi-plus"></i>Agregar componente</button>
                </div>
                <div class="af-ancho af-sugerir">
                    <p><b>Componentes comunes</b> · toca uno para agregarlo</p>
                    <div class="af-sugerir-chips"><%= OpcionesPartesComunes() %></div>
                </div>
            </asp:Panel>
        </section>

        <%-- ============ PASO 5 · VARIABLES DE CONDICIÓN ============ --%>
        <section class="af-seccion" data-paso="5">
            <header class="af-cab"><i class="mdi mdi-pulse"></i><div><h3>Variables de condición</h3><p>Lo que se mide para saber cómo está el equipo y entre qué valores es normal.</p></div></header>
            <div>
                <asp:Literal ID="litVariables" runat="server" />
                <div class="af-filas-cab af-fila-var" id="vaCab" style="display:none"><span>Qué se mide</span><span>Unidad</span><span>Mínimo normal</span><span>Máximo normal</span><span></span></div>
                <div id="vaContainer" class="af-filas"></div>
                <button type="button" class="af-btn es-suave" style="margin-top:10px" onclick="vaAgregar()"><i class="mdi mdi-plus"></i>Agregar variable</button>
                <p class="sigma-modal-ayuda" style="margin:10px 0 0">Ej.: Temperatura de la cámara, en °C, normal entre −22 y −18. Si no está en la lista, escríbela y se crea.</p>
            </div>
        </section>

        <%-- ============ PASO 6 · MEDIDORES ============ --%>
        <section class="af-seccion" data-paso="6">
            <header class="af-cab"><i class="mdi mdi-counter"></i><div><h3>Medidores</h3><p>Lo que cuenta cuánto ha trabajado el equipo, con la lectura de hoy.</p></div></header>
            <div>
                <asp:Literal ID="litMedidores" runat="server" />
                <div class="af-filas-cab af-fila-med" id="meCab" style="display:none"><span>Qué cuenta</span><span>Unidad</span><span>Lectura de hoy</span><span></span></div>
                <div id="meContainer" class="af-filas"></div>
                <button type="button" class="af-btn es-suave" style="margin-top:10px" onclick="meAgregar()"><i class="mdi mdi-plus"></i>Agregar medidor</button>
                <p class="sigma-modal-ayuda" style="margin:10px 0 0">Ej.: Horas de marcha del compresor, en horas, hoy marca 1.250.</p>
            </div>
        </section>

        <%-- ============ LA BARRA DEL PIE ============
             Anterior a la izquierda; Cancelar, Siguiente y Guardar a la
             derecha, en ese orden y en la misma fila, en el modal y en el
             centro. Lo unico que cambia es la clase: en el centro va pegada
             abajo porque la ficha es larga. --%>
        <div class="af-pie">
            <button type="button" class="af-btn es-contorno" id="fpBtnAnterior" onclick="fpIr(fpActual() - 1)"><i class="mdi mdi-arrow-left"></i>Anterior</button>
            <span class="af-pie-donde"><span id="fpDonde"></span>
                <span class="sg-a3-ficha-sucio" id="sgA3Sucio"><i class="mdi mdi-circle-medium"></i>Cambios sin guardar</span></span>
            <div class="af-pie-der">
                <button type="button" class="af-btn es-contorno" id="fpBtnSiguiente" onclick="fpSiguiente()">Siguiente<i class="mdi mdi-arrow-right"></i></button>

                <asp:Panel ID="pnlAccionesModal" runat="server" CssClass="af-pie-acc">
                    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cancelar" CssClass="af-btn es-ghost af-cancelar" OnClientClick="closeWindow(); return false;" />
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" CssClass="af-btn es-primario af-guardar" OnClick="btnGuardar_Click" ValidationGroup="Activo" OnClientClick="sigmaGuardando();" />
                </asp:Panel>

                <asp:Panel ID="pnlAccionesCentro" runat="server" Visible="false" CssClass="af-pie-acc">
                    <WebControls:PushButton ID="btnCancelar" runat="server" Text="Cancelar" CssClass="af-btn es-ghost af-cancelar" OnClick="btnCancelar_Click" CausesValidation="false" />
                    <WebControls:PushButton ID="btnGuardarCentro" runat="server" Text="Guardar cambios" CssClass="af-btn es-primario af-guardar" OnClick="btnGuardar_Click" ValidationGroup="Activo" OnClientClick="sigmaGuardando();" />
                </asp:Panel>
            </div>
        </div>

        <wuc:Auditoria runat="server" ID="wucAuditoria" />
    </div>
</asp:Panel>

<%-- Velo de guardado: cubre la ficha para que se note que está trabajando
     y no se pueda volver a apretar Guardar mientras sube la imagen. --%>
<div id="sigmaGuardandoOv" style="display:none;position:fixed;inset:0;z-index:99999;background:rgba(255,255,255,.82);align-items:center;justify-content:center;">
    <div style="display:flex;flex-direction:column;align-items:center;gap:12px;text-align:center;">
        <div style="width:44px;height:44px;border:4px solid #E2E7F0;border-top-color:#6732F4;border-radius:50%;animation:sigmaSpin .8s linear infinite;"></div>
        <div style="font-size:15px;font-weight:700;color:#17223B;">Guardando el equipo…</div>
        <div style="font-size:13px;color:#68738A;">Si elegiste una foto o documentos, se están subiendo. No cierres esta ventana.</div>
    </div>
</div>
<style>@keyframes sigmaSpin{to{transform:rotate(360deg)}}</style>

    </ContentTemplate>
</asp:UpdatePanel>
