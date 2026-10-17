<%@ Page Language="C#" AutoEventWireup="true" %>
<!DOCTYPE html>
<html lang="es-CL">
<head runat="server">
    <meta charset="utf-8" />
    <title>SIGMA · Sistema Integrado de Gestión de Mantenimiento Industrial</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="SIGMA · Órdenes de trabajo, activos, checklists, inventario e indicadores de mantenimiento industrial en un solo lugar, con SIGMA AI y SIGMA Twin." />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="theme-color" content="#070A14" />

    <link href="Imagen/sigma-favicon.svg" rel="icon" type="image/svg+xml" />
    <link href="Css/Inicio/sigma-landing.css?vrs=1" rel="stylesheet" />
    <link href="Css/Inicio/sigma-cine.css?vrs=1" rel="stylesheet" />
    <link href="Imagen/landing/poster-ai.jpg" rel="preload" as="image" />
    <script src="Js/gsap/gsap.min.js" defer></script>
    <script src="Js/gsap/ScrollTrigger.min.js" defer></script>
    <script src="Js/Inicio/sigma-inicio.js?vrs=2" type="module"></script>
</head>
<body>
<div id="sg-root" class="sg" style="font-family: 'Sora', 'Segoe UI', system-ui, sans-serif; color: #17223B; background: #070A14">
<a class="sg-skip" href="#contenido">Saltar al contenido</a>
<div id="sg-progress" class="sg-progress" aria-hidden="true"></div>

<!-- ================= INTRO DE PELÍCULA (la muestra el JS) ================= -->
<div id="sg-film" class="sg-film" hidden>
  <div class="sg-film-bar is-top"></div>
  <div class="sg-film-bar is-bot"></div>
  <div class="sg-film-flash"></div>
  <div class="sg-film-card sg-film-cc"><img src="Imagen/landing/codigo-creativo-logo.png" alt="Código Creativo" width="230" height="110"><span class="sg-mono">presenta</span></div>
  <div class="sg-film-card sg-film-sigma"><img src="Imagen/sigma-logo-horizontal-dark.svg" alt="SIGMA" width="520" height="172"><span class="sg-mono">Sistema Integrado de Gestión de Mantenimiento</span></div>
  <button type="button" class="sg-film-skip" id="sg-film-skip">Saltar intro</button>
</div>

<!-- ================= NAV ================= -->
<header class="sg-nav" id="sg-nav">
  <div class="sg-nav-in">
    <a class="sg-nav-logo" href="#inicio" aria-label="SIGMA, ir al inicio">
      <img class="is-d" src="Imagen/sigma-logo-horizontal-dark.svg" alt="SIGMA" width="79" height="26">
      <img class="is-l" src="Imagen/sigma-logo-horizontal-light.svg" alt="" width="79" height="26">
    </a>
    <nav class="sg-nav-links" aria-label="Secciones">
      <a class="sg-nav-link is-active" href="#inicio" aria-current="location">Inicio</a>
      <a class="sg-nav-link" href="#sigma-ai" aria-current="false"><span class="sg-dot" style="background: #9A72FF"></span>SIGMA AI</a>
      <a class="sg-nav-link" href="#sigma-twin" aria-current="false"><span class="sg-dot" style="background: #16C6C9"></span>SIGMA Twin</a>
      <a class="sg-nav-link" href="#componentes" aria-current="false">Componentes</a>
      <a class="sg-nav-link" href="#planes" aria-current="false">Planes</a>
      <a class="sg-nav-link" href="#nosotros" aria-current="false">Quiénes somos</a>
    </nav>
    <div class="sg-nav-cta">
      <a class="sg-btn sg-btn-primary" href="Login.aspx">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"></path><polyline points="10 17 15 12 10 7"></polyline><line x1="15" y1="12" x2="3" y2="12"></line></svg>
        Ingresar
      </a>
    </div>
    <button type="button" class="sg-burger" id="sg-burger" aria-label="Abrir menú" aria-expanded="false" aria-controls="sg-mnav">
      <svg id="sg-ico-close" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true" hidden><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
      <svg id="sg-ico-open" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><line x1="4" y1="8" x2="20" y2="8"></line><line x1="4" y1="16" x2="20" y2="16"></line></svg>
    </button>
  </div>
  <nav id="sg-mnav" class="sg-mnav" aria-label="Secciones" hidden>
      <a class="sg-nav-link" href="#inicio">Inicio</a>
      <a class="sg-nav-link" href="#sigma-ai">SIGMA AI</a>
      <a class="sg-nav-link" href="#sigma-twin">SIGMA Twin</a>
      <a class="sg-nav-link" href="#componentes">Componentes</a>
      <a class="sg-nav-link" href="#planes">Planes</a>
      <a class="sg-nav-link" href="#nosotros">Quiénes somos</a>
      <a class="sg-btn sg-btn-primary sg-btn-lg" href="Login.aspx">Ingresar a SIGMA</a>
  </nav>
</header>

<main id="contenido">
<!-- ================= HERO · del caos al control ================= -->
<section id="inicio" class="sg-hero sg-dark" data-nav="dark" aria-labelledby="sg-h1">
  <canvas id="sg-gl" class="sg-gl" aria-hidden="true"></canvas>
  <div class="sg-vignette" aria-hidden="true"></div>
  <div class="sg-grain" aria-hidden="true"></div>
  <div class="sg-wrap sg-hero-in">
    <div class="sg-hero-kicker sg-intro">
      <span class="sg-pulse" aria-hidden="true"></span>
      <span class="sg-mono">Sistema Integrado de Gestión de Mantenimiento</span>
      <span class="sg-mono" style="color: rgba(255,255,255,.4)">Web · App móvil · SIGMA AI · SIGMA Twin</span>
    </div>
    <h1 id="sg-h1" class="sg-h1">
      <span class="sg-line"><span>Mantenimiento</span></span>
      <span class="sg-line"><span class="sg-grad">bajo control.</span></span>
    </h1>
    <div class="sg-hero-row">
      <div class="sg-intro">
        <p class="sg-hero-lead">Órdenes de trabajo, activos, checklists, inventario e indicadores en un solo lugar. Con inteligencia que anticipa la falla y un gemelo digital de tus bodegas.</p>
        <p class="sg-hero-help">¿Problemas para entrar? Contacta al administrador de tu planta.</p>
      </div>
      <div class="sg-hero-actions sg-intro">
        <a class="sg-btn sg-btn-primary sg-btn-lg sg-magnet" href="Login.aspx">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"></path><polyline points="10 17 15 12 10 7"></polyline><line x1="15" y1="12" x2="3" y2="12"></line></svg>
          Ingresar a SIGMA
        </a>
        <a class="sg-btn sg-btn-outline-dark sg-btn-lg sg-magnet" href="#spots">
          <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><polygon points="7 4 20 12 7 20 7 4"></polygon></svg>
          Ver los spots
        </a>
      </div>
    </div>
  </div>
  <div class="sg-wrap sg-hero-foot sg-intro">
    <span class="sg-mono"><i class="sg-scrollcue" aria-hidden="true"></i>Desliza</span>
    <span class="sg-mono is-wide">Órdenes · Activos · Pautas · Inventario · Indicadores</span>
    <span class="sg-hero-credit"><span class="sg-mono">Una creación de</span><img src="Imagen/landing/codigo-creativo-logo.png" alt="Código Creativo" width="55" height="26"></span>
  </div>
</section>

<section class="sg-manifesto sg-dark" data-nav="dark" aria-label="Por qué SIGMA">
  <div class="sg-wrap">
    <div class="sg-label sg-mono"><span>(01)</span><span>Por qué SIGMA</span></div>
    <p class="sg-big" id="sg-manif"><span class="sg-mw">Hoy </span><span class="sg-mw">el </span><span class="sg-mw">mantenimiento </span><span class="sg-mw">de </span><span class="sg-mw">una </span><span class="sg-mw">planta </span><span class="sg-mw">vive </span><span class="sg-mw">en </span><span class="sg-mw">planillas </span><span class="sg-mw">sueltas </span><span class="sg-mw">y </span><span class="sg-mw">en </span><span class="sg-mw">la </span><span class="sg-mw">memoria </span><span class="sg-mw">de </span><span class="sg-mw">quien </span><span class="sg-mw">lleva </span><span class="sg-mw">años </span><span class="sg-mw">en </span><span class="sg-mw">el </span><span class="sg-mw">cargo. </span><span class="sg-mw is-key">SIGMA </span><span class="sg-mw">lo </span><span class="sg-mw">reúne </span><span class="sg-mw">en </span><span class="sg-mw">un </span><span class="sg-mw is-key">solo </span><span class="sg-mw is-key">lugar </span><span class="sg-mw">y </span><span class="sg-mw">lo </span><span class="sg-mw">lleva </span><span class="sg-mw">hasta </span><span class="sg-mw">el </span><span class="sg-mw">equipo: </span><span class="sg-mw">del </span><span class="sg-mw">escritorio </span><span class="sg-mw">a </span><span class="sg-mw">la </span><span class="sg-mw">planta, </span><span class="sg-mw">y </span><span class="sg-mw">de </span><span class="sg-mw">vuelta. </span></p>
    <div class="sg-manifesto-foot">
      <span class="sg-chip sg-chip-night">1 plataforma</span>
      <span class="sg-chip sg-chip-night">+8 módulos conectados</span>
      <span class="sg-chip sg-chip-night">Registro en terreno sin señal</span>
      <span class="sg-chip sg-chip-night">Lectura en voz alta e inclusión</span>
    </div>
  </div>
</section>

<!-- ================= HISTORIA · cómo funciona ================= -->
<section id="sg-story" class="sg-story sg-dark" data-nav="dark" aria-labelledby="sg-how">
  <div class="sg-story-track">
    <div class="sg-story-stage">
      <div class="sg-wrap">
        <div class="sg-label sg-mono"><span>(02)</span><span>Cómo funciona</span></div>
        <div class="sg-story-head">
          <h2 id="sg-how">Del escritorio a la planta, y de vuelta.</h2>
          <p>Un mismo dato recorre todo el ciclo: se planifica una vez, se ejecuta donde está el equipo y vuelve convertido en información.</p>
        </div>
        <ol class="sg-chaps">
          <li class="sg-chap">
            <div class="sg-chap-txt">
              <span class="sg-chap-n">01 / 03</span>
              <h3>Planifica en el escritorio.</h3>
              <p>Define planes por calendario, horómetro o ciclos. El Centro de Mantenimiento programa las órdenes y las pautas de cada activo, y la bandeja te muestra lo más urgente primero.</p>
              <ul><li class="sg-chip sg-chip-night">Planificación</li><li class="sg-chip sg-chip-night">Órdenes de trabajo</li><li class="sg-chip sg-chip-night">Bandeja</li></ul>
            </div>
            <div class="sg-chap-vis">
              <figure class="sg-browser has-shot">
                <div class="sg-browser-bar" aria-hidden="true"><div class="sg-dots"><i></i><i></i><i></i></div><div class="sg-url">sigma / mantenimiento / planificacion</div></div>
                <img class="sg-shot" src="Imagen/landing/scr-planificacion.jpg" alt="Captura real de SIGMA: Planificación del Centro de Mantenimiento" width="1424" height="800" loading="lazy">
              </figure>
              <figure class="sg-shot-card" style="right: -24px; bottom: -10px"><img src="Imagen/landing/scr-ordenes.jpg" alt="Captura real de SIGMA: listado de órdenes de trabajo" width="1424" height="749" loading="lazy"></figure>
            </div>
          </li>
          <li class="sg-chap">
            <div class="sg-chap-txt">
              <span class="sg-chap-n">02 / 03</span>
              <h3>Ejecuta en la planta.</h3>
              <p>La app móvil lleva el trabajo hasta el equipo: checklist con umbrales, fotos y dictado por voz, incluso sin señal.</p>
              <ul><li class="sg-chip sg-chip-night">App móvil</li><li class="sg-chip sg-chip-night">Fotos</li><li class="sg-chip sg-chip-night">Voz</li></ul>
            </div>
            <div class="sg-chap-vis" role="img" aria-label="Vista ilustrativa de una pauta de inspección en la app móvil">
              <div class="sg-phone" aria-hidden="true">
                <div class="sg-phone-scr">
                  <div class="sg-phone-top"><small>Pauta de inspección</small><b>Dosificador de Manteca · ACT-10</b></div>
                  <div class="sg-phone-body">
                    <div class="sg-check"><i class="ok"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg></i>Nivel de lubricante</div>
                    <div class="sg-check"><i class="ok"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg></i>Temperatura</div>
                    <div class="sg-check warn"><i><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><line x1="12" y1="7" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg></i>Vibración<em>En alza</em></div>
                    <div class="sg-check"><i class="no"></i>Ruido</div>
                    <div class="sg-check"><i class="no"></i>Foto del equipo</div>
                    <div class="sg-voice"><b><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2" width="6" height="12" rx="3"></rect><path d="M19 10v1a7 7 0 0 1-14 0v-1"></path><line x1="12" y1="18" x2="12" y2="22"></line></svg></b>Dictar hallazgo<div class="sg-wave"><span style="height: 6px"></span><span style="height: 12px"></span><span style="height: 16px"></span><span style="height: 9px"></span><span style="height: 13px"></span><span style="height: 5px"></span></div></div>
                  </div>
                  <div class="sg-phone-foot"><i></i>Sin señal · se sincroniza al reconectar</div>
                </div>
              </div>
              <div class="sg-float" style="left: 2%; top: 70px" aria-hidden="true"><i class="sg-ico-ai"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2" width="6" height="12" rx="3"></rect><path d="M19 10v1a7 7 0 0 1-14 0v-1"></path></svg></i><div>Hallazgo dictado<small>«Vibración en alza en el eje»</small></div></div>
              <div class="sg-float" style="right: 2%; bottom: 80px" aria-hidden="true"><i class="sg-ico-sync"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="2" y1="2" x2="22" y2="22"></line><path d="M8.5 16.5a5 5 0 0 1 7 0"></path></svg></i><div>Sin señal<small>Guardado en el equipo</small></div></div>
            </div>
          </li>
          <li class="sg-chap">
            <div class="sg-chap-txt">
              <span class="sg-chap-n">03 / 03</span>
              <h3>Vuelve con datos.</h3>
              <p>Al reconectar, todo se sincroniza: la bandeja se actualiza, el inventario cuadra y SIGMA AI aprende de cada cierre para anticipar la próxima falla.</p>
              <ul><li class="sg-chip sg-chip-night">Sincronización</li><li class="sg-chip sg-chip-night">Indicadores</li><li class="sg-chip sg-chip-night">SIGMA AI</li></ul>
            </div>
            <div class="sg-chap-vis">
              <figure class="sg-browser has-shot">
                <div class="sg-browser-bar" aria-hidden="true"><div class="sg-dots"><i></i><i></i><i></i></div><div class="sg-url">sigma / inicio</div></div>
                <img class="sg-shot" src="Imagen/landing/scr-home.jpg" alt="Captura real de SIGMA: inicio con accesos a SIGMA Twin, SIGMA AI y el resumen operativo" width="1424" height="749" loading="lazy">
              </figure>
              <figure class="sg-shot-card" style="left: -30px; bottom: -20px; width: 42%"><img src="Imagen/landing/scr-bandeja.jpg" alt="Captura real de SIGMA: bandeja de mantenciones vencidas y por vencer" width="1424" height="860" loading="lazy"></figure>
            </div>
          </li>
        </ol>
        <div class="sg-rail" aria-hidden="true"><span class="sg-mono" id="sg-rail-label">01 — Planifica</span><div class="sg-rail-bar"><i id="sg-rail-fill"></i></div><span class="sg-mono">03</span></div>
      </div>
    </div>
  </div>
</section>

<section id="spots" class="sg-cine sg-dark" data-nav="dark" style="scroll-margin-top: 80px" aria-labelledby="sg-cine-t">
  <div class="sg-wrap">
    <div class="sg-label sg-mono"><span>(03)</span><span>En pantalla</span></div>
    <div class="sg-cine-head">
      <div class="sg-rv">
        <h2 id="sg-cine-t">Dos módulos,<br>treinta segundos cada uno.</h2>
        <p>Los spots oficiales de SIGMA AI y SIGMA Twin, con voz. La pantalla se arma pieza por pieza: así trabaja SIGMA, uniendo cada dato hasta ver el cuadro completo.</p>
      </div>
      <div class="sg-cine-tabs sg-rv" role="group" aria-label="Elegir spot">
        <button type="button" class="is-on" aria-pressed="true" data-spot="ai"><img src="Imagen/sigma-ai/sigma-ai-logo-horizontal-dark.svg" alt="SIGMA AI" width="110" height="30"><span><small>Anticípate a la falla</small></span></button>
        <button type="button" class="" aria-pressed="false" data-spot="twin"><img src="Imagen/sigma-twin/sigma-twin-logo-horizontal-dark.svg" alt="SIGMA Twin" width="120" height="30"><span><small>Tu bodega, en 3D</small></span></button>
      </div>
    </div>
    <div id="sg-cine-stage" class="sg-cine-stage sg-rv">
      <canvas id="sg-cine-gl" class="sg-cine-gl" aria-hidden="true"></canvas>
      <div class="sg-cine-fallback">
        <video id="sg-cine-video" src="Video/landing/sigma-ai-spot.mp4" poster="Imagen/landing/poster-ai.jpg" muted autoplay loop playsinline preload="metadata" aria-label="Spot de SIGMA AI: anticípate a la falla. 30 segundos, con voz."></video>
      </div>
      <div class="sg-cine-tag sg-mono" aria-hidden="true"><i class="sg-rec"></i><span id="sg-cine-title">SIGMA AI</span> · 30 s · con voz</div>
      <div class="sg-cine-hud">
        <button type="button" class="sg-cine-btn" id="sg-cine-play" aria-label="Pausar el spot">
          <svg id="sg-ico-pause" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><rect x="6" y="5" width="4" height="14" rx="1"></rect><rect x="14" y="5" width="4" height="14" rx="1"></rect></svg>
          <svg id="sg-ico-play" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" hidden><polygon points="7 4 20 12 7 20 7 4"></polygon></svg>
        </button>
        <button type="button" class="sg-cine-btn" id="sg-cine-snd" aria-label="Activar sonido del spot" aria-pressed="false">
          <svg id="sg-ico-muted" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><line x1="23" y1="9" x2="17" y2="15"></line><line x1="17" y1="9" x2="23" y2="15"></line></svg>
          <svg id="sg-ico-sound" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" hidden><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M15.5 8.5a5 5 0 0 1 0 7"></path><path d="M19 5a10 10 0 0 1 0 14"></path></svg>
        </button>
        <div class="sg-cine-prog" aria-hidden="true"><i id="sg-cine-prog"></i></div>
        <span class="sg-cine-meta sg-mono" id="sg-cine-hint">Activa el sonido para escuchar la voz</span>
      </div>
    </div>
  </div>
</section>

<!-- ================= SIGMA AI ================= -->
<section id="sigma-ai" class="sg-prod sg-prod-ai sg-dark" data-nav="dark" style="scroll-margin-top: 80px" aria-labelledby="sg-ai-t">
  <div class="sg-grain" aria-hidden="true"></div>
  <div class="sg-wrap">
    <div class="sg-label sg-mono"><span>(04)</span><span>Inteligencia predictiva</span></div>
    <div class="sg-prod-grid">
      <div class="sg-rv">
        <img class="sg-prod-logo" src="Imagen/sigma-ai/sigma-ai-logo-horizontal-dark.svg" alt="SIGMA AI" width="170" height="46">
        <h2 id="sg-ai-t">Anticípate<br>a la <em>falla.</em></h2>
        <p class="sg-prod-lead">Toda falla avisa. SIGMA AI escucha las señales de tus activos —lecturas, inspecciones, historial y fotos—, te dice qué revisar primero y por qué, y convierte la respuesta en una orden de trabajo.</p>
        <div class="sg-flow sg-mono"><b>Detectar</b><i></i><b>Comprender</b><i></i><b>Actuar</b></div>
        <div class="sg-prod-plan"><span class="sg-chip sg-chip-night">Chat con el copiloto desde el plan Medio</span><span class="sg-chip sg-chip-night">Predicción y análisis visual en el plan Full</span></div>
      </div>
      <div class="sg-prod-vis">
        <canvas id="sg-ai-gl" class="sg-prod-gl" aria-hidden="true"></canvas>
        <figure class="sg-prod-shot sg-par" style="right: 0; top: 10px; width: 82%"><img src="Imagen/landing/scr-ai-monitoreo.jpg" alt="Captura real del Centro de monitoreo de SIGMA AI: salud de la planta y activos en riesgo" width="1600" height="834" loading="lazy"><figcaption class="sg-mono">Centro de monitoreo · real</figcaption></figure>
        <div class="sg-risk sg-par2" style="left: 0; top: 300px" aria-hidden="true">
          <span class="sg-mono" style="color: rgba(255,255,255,.55)">Predicción · Dosificador de Manteca</span>
          <b>87<span>%</span></b>
          <div class="sg-risk-bar"><i></i></div>
          <small>Riesgo de falla · ventana estimada 12 días · vibración en alza</small>
        </div>
        <div class="sg-copilot sg-par3" style="right: 10px; top: 360px" aria-hidden="true">
          <span class="sg-mono" style="color: #B08CFF">SIGMA AI Chat</span>
          <div class="sg-copilot-q">¿Qué reviso primero hoy?</div>
          <div class="sg-copilot-a">Empieza por el <b>Dosificador de Manteca (ACT-10)</b>: su vibración va en alza.</div>
          <div class="sg-copilot-act"><small class="sg-mono">Acción recomendada</small>Adelantar la mantención de 200 h del dosificador<span class="sg-btn sg-btn-primary">+ Crear OT</span></div>
        </div>
      </div>
    </div>
    <div class="sg-feat-grid">
      <article class="sg-feat sg-rv"><span class="sg-mono">01 · Predicción</span><h3>Riesgo de falla por activo</h3><p>Cada activo recibe un riesgo con sus razones —temperatura, vibración, historial— para intervenir antes de la detención.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">02 · Vida útil</span><h3>Cuánto le queda a cada repuesto</h3><p>Estima la vida útil restante según el uso real, para cambiar a tiempo y no antes de lo necesario.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">03 · Visión</span><h3>Revisa las fotos de terreno</h3><p>Analiza las fotografías que llegan desde la app y clasifica lo que ve, para que un hallazgo no dependa de quién lo mire.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">04 · Copiloto</span><h3>«¿Qué reviso primero hoy?»</h3><p>Responde con la cola de riesgo y sus razones, y ofrece acciones directas: crear la OT o pedir el repuesto.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">05 · Aprende solo</span><h3>Mejora con cada cierre de OT</h3><p>Se reentrena con los cierres y solo publica una versión nueva si supera a la vigente. Nadie tiene que apretar un botón.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">06 · En vivo</span><h3>La planta, en este momento</h3><p>Salud por área, activos en riesgo y alertas en tiempo real, en un solo centro de monitoreo.</p></article>
    </div>
  </div>
</section>

<!-- ================= SIGMA TWIN ================= -->
<section id="sigma-twin" class="sg-prod sg-prod-twin sg-dark" data-nav="dark" style="scroll-margin-top: 80px" aria-labelledby="sg-tw-t">
  <div class="sg-grain" aria-hidden="true"></div>
  <div class="sg-wrap">
    <div class="sg-label sg-mono"><span>(05)</span><span>Gemelo digital</span></div>
    <div class="sg-prod-grid is-rev">
      <div class="sg-prod-vis">
        <canvas id="sg-twin-gl" class="sg-prod-gl" aria-hidden="true"></canvas>
        <figure class="sg-prod-shot sg-par" style="left: 0; top: 30px; width: 80%"><img src="Imagen/landing/scr-twin.jpg" alt="Captura real de SIGMA Twin: bodega en 3D con el panel del repuesto" width="1600" height="900" loading="lazy"><figcaption class="sg-mono">SIGMA Twin · real</figcaption></figure>
        <figure class="sg-prod-shot sg-par2" style="right: 0; top: 330px; width: 50%"><img src="Imagen/landing/tw-10.jpg" alt="Captura real de SIGMA Twin: caja abierta con el rodamiento y su etiqueta QR" width="1600" height="900" loading="lazy"><figcaption class="sg-mono">Caja abierta · QR</figcaption></figure>
      </div>
      <div class="sg-rv">
        <img class="sg-prod-logo" src="Imagen/sigma-twin/sigma-twin-logo-horizontal-dark.svg" alt="SIGMA Twin" width="180" height="46">
        <h2 id="sg-tw-t">Tu bodega,<br><em>en 3D.</em></h2>
        <p class="sg-prod-lead">La falla ya avisó: ¿dónde está el repuesto? SIGMA Twin es el gemelo digital de tus bodegas. La escena se arma sola desde tus datos: cada rack en su pasillo y cada caja con su stock.</p>
        <div class="sg-flow sg-mono"><b>Encuéntralo en segundos</b><i></i><b>Recorre sin moverte</b><i></i><b>Ve lo que falta</b></div>
        <div class="sg-prod-plan"><span class="sg-chip sg-chip-night">Incluido en el plan Full</span><span class="sg-chip sg-chip-night">Web y tablet</span></div>
      </div>
    </div>
    <div class="sg-feat-grid">
      <article class="sg-feat sg-rv"><span class="sg-mono">01 · Desde tus datos</span><h3>Se arma solo, sin dibujar planos</h3><p>El código de ubicación (P1-A-R01) dice el pasillo y el rack. El stock sin ubicación aparece en una zona de recepción, nunca se esconde.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">02 · Caja que se abre</span><h3>Un clic y ves la pieza</h3><p>La caja sale al pasillo, se abre y muestra la pieza o su foto, con stock, umbrales y acciones: entregar, ajustar, trasladar.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">03 · Picking</span><h3>Ruta en «S» contra la OT</h3><p>Elige la orden y el mapa reparte cada repuesto entre sus cajas y arma el recorrido. Cada retiro queda descontado contra la OT.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">04 · Método de salida</span><h3>FEFO, FIFO o LIFO</h3><p>Se configura por bodega o por repuesto y decide de qué caja y de qué lote sale cada unidad.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">05 · Análisis</span><h3>Rotación ABC y bajo mínimo</h3><p>Muestra lo que más se mueve, sugiere acercarlo a la entrada y marca lo que está por faltar, antes de que falte.</p></article>
      <article class="sg-feat sg-rv"><span class="sg-mono">06 · Orden físico</span><h3>Carga por nivel y etiquetas QR</h3><p>Medidas, peso y carga admisible por nivel con aviso de sobrecarga, y etiquetas QR del Centro de etiquetas en vigas y cajas.</p></article>
    </div>
  </div>
</section>

<!-- ================= MARQUESINA ================= -->
<section class="sg-marquee sg-dark" data-nav="dark" aria-label="Módulos de SIGMA">
  <div class="sg-mq-row" id="sg-mq1" aria-hidden="true">
    <span class="is-solid">Activos</span><span>Órdenes de trabajo</span><span class="is-cyan">Pautas</span><span>Inventario</span><span class="is-solid">Terceros</span><span>Indicadores</span>
    <span class="is-solid">Activos</span><span>Órdenes de trabajo</span><span class="is-cyan">Pautas</span><span>Inventario</span><span class="is-solid">Terceros</span><span>Indicadores</span>
  </div>
  <div class="sg-mq-row" id="sg-mq2" aria-hidden="true">
    <span>SIGMA AI</span><span class="is-solid">SIGMA Twin</span><span>App móvil</span><span class="is-cyan">Voz</span><span>Predicción</span><span class="is-solid">Inclusión</span>
    <span>SIGMA AI</span><span class="is-solid">SIGMA Twin</span><span>App móvil</span><span class="is-cyan">Voz</span><span>Predicción</span><span class="is-solid">Inclusión</span>
  </div>
  <p style="position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0)">Activos, órdenes de trabajo, pautas, inventario, terceros, indicadores, SIGMA AI, SIGMA Twin y app móvil.</p>
</section>

<!-- ================= COMPONENTES ================= -->
<section id="componentes" class="sg-section sg-section-white" data-nav="light" style="scroll-margin-top: 80px" aria-labelledby="sg-comp">
  <div class="sg-wrap">
    <div class="sg-label sg-mono"><span>(06)</span><span>Componentes</span></div>
    <div class="sg-split">
      <div class="sg-rv">
        <h2 id="sg-comp" class="sg-h2">Módulos conectados,<br>una sola información.</h2>
        <p class="sg-sub">Cada módulo resuelve una parte del mantenimiento y comparte el mismo registro con los demás. Elige uno para verlo.</p>
      </div>
    </div>
    <div class="sg-mods">
      <ol class="sg-idx" aria-label="Módulos">
          <li class="sg-rv">
            <button type="button" class="is-on" aria-pressed="true" aria-controls="sg-viewer" data-mod="0" data-name="Control de activos" data-desc="Equipos, componentes y la jerarquía de la planta, todo en un mismo registro." data-val="es la base única sobre la que se apoya el resto; nada se mantiene bien si antes no está bien identificado." data-star="0">
              <span class="sg-idx-n">01</span>
              <span><span class="sg-idx-name">Control de activos</span><span class="sg-idx-desc">Equipos, componentes y la jerarquía de la planta, todo en un mismo registro.</span></span>
              <span class="sg-idx-go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></span>
            </button>
          </li>
          <li class="sg-rv">
            <button type="button" class="" aria-pressed="false" aria-controls="sg-viewer" data-mod="1" data-name="Centro de mantenimiento" data-desc="Órdenes de trabajo, planes y programaciones del trabajo preventivo y correctivo." data-val="coordina a todos en un mismo flujo; el trabajo queda planificado, trazable y sin duplicarse." data-star="0">
              <span class="sg-idx-n">02</span>
              <span><span class="sg-idx-name">Centro de mantenimiento</span><span class="sg-idx-desc">Órdenes de trabajo, planes y programaciones del trabajo preventivo y correctivo.</span></span>
              <span class="sg-idx-go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></span>
            </button>
          </li>
          <li class="sg-rv">
            <button type="button" class="" aria-pressed="false" aria-controls="sg-viewer" data-mod="2" data-name="Pautas de inspección" data-desc="Checklists dinámicos con umbrales, dependencias entre ítems y hallazgos." data-val="convierte una inspección en acción; detecta a tiempo lo que está fuera de rango y lo deriva." data-star="0">
              <span class="sg-idx-n">03</span>
              <span><span class="sg-idx-name">Pautas de inspección</span><span class="sg-idx-desc">Checklists dinámicos con umbrales, dependencias entre ítems y hallazgos.</span></span>
              <span class="sg-idx-go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></span>
            </button>
          </li>
          <li class="sg-rv">
            <button type="button" class="" aria-pressed="false" aria-controls="sg-viewer" data-mod="3" data-name="Inventario" data-desc="Catálogo de repuestos, bodegas y existencias por planta." data-val="evita detener un equipo por falta de repuesto y mantiene bajo control el costo del stock." data-star="0">
              <span class="sg-idx-n">04</span>
              <span><span class="sg-idx-name">Inventario</span><span class="sg-idx-desc">Catálogo de repuestos, bodegas y existencias por planta.</span></span>
              <span class="sg-idx-go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></span>
            </button>
          </li>
          <li class="sg-rv">
            <button type="button" class="" aria-pressed="false" aria-controls="sg-viewer" data-mod="4" data-name="SIGMA Twin" data-desc="Gemelo digital de bodegas y repuestos: racks, cajas y stock en 3D, con picking guiado." data-val="encuentras el repuesto en segundos y ves lo que falta antes de que falte." data-star="1">
              <span class="sg-idx-n">05</span>
              <span><span class="sg-idx-name">SIGMA Twin</span><span class="sg-chip sg-chip-purple">Módulo de SIGMA</span><span class="sg-idx-desc">Gemelo digital de bodegas y repuestos: racks, cajas y stock en 3D, con picking guiado.</span></span>
              <span class="sg-idx-go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></span>
            </button>
          </li>
          <li class="sg-rv">
            <button type="button" class="" aria-pressed="false" aria-controls="sg-viewer" data-mod="5" data-name="Terceros y permisos" data-desc="Proveedores, servicios contratados y permisos de trabajo." data-val="ordena y da seguridad a quienes entran a la planta, con respaldo de cada autorización." data-star="0">
              <span class="sg-idx-n">06</span>
              <span><span class="sg-idx-name">Terceros y permisos</span><span class="sg-idx-desc">Proveedores, servicios contratados y permisos de trabajo.</span></span>
              <span class="sg-idx-go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></span>
            </button>
          </li>
          <li class="sg-rv">
            <button type="button" class="" aria-pressed="false" aria-controls="sg-viewer" data-mod="6" data-name="Indicadores" data-desc="Tableros de gestión, bandeja de mantenciones y exportación de datos." data-val="decisiones con datos a la vista y lo más urgente siempre primero." data-star="0">
              <span class="sg-idx-n">07</span>
              <span><span class="sg-idx-name">Indicadores</span><span class="sg-idx-desc">Tableros de gestión, bandeja de mantenciones y exportación de datos.</span></span>
              <span class="sg-idx-go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></span>
            </button>
          </li>
          <li class="sg-rv">
            <button type="button" class="" aria-pressed="false" aria-controls="sg-viewer" data-mod="7" data-name="SIGMA AI" data-desc="Predicción de fallas, vida útil restante, análisis visual y un copiloto que responde." data-val="ahorra tiempo en terreno y anticipa la falla antes de que detenga la operación." data-star="1">
              <span class="sg-idx-n">08</span>
              <span><span class="sg-idx-name">SIGMA AI</span><span class="sg-chip sg-chip-purple">Módulo de SIGMA</span><span class="sg-idx-desc">Predicción de fallas, vida útil restante, análisis visual y un copiloto que responde.</span></span>
              <span class="sg-idx-go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></span>
            </button>
          </li>
          <li class="sg-rv">
            <button type="button" class="" aria-pressed="false" aria-controls="sg-viewer" data-mod="8" data-name="App móvil y sincronización" data-desc="Registro en terreno incluso sin cobertura, con sincronización al reconectar." data-val="el dato se captura donde ocurre, sin depender de volver al escritorio ni de la señal." data-star="0">
              <span class="sg-idx-n">09</span>
              <span><span class="sg-idx-name">App móvil y sincronización</span><span class="sg-idx-desc">Registro en terreno incluso sin cobertura, con sincronización al reconectar.</span></span>
              <span class="sg-idx-go" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></span>
            </button>
          </li>
      </ol>

      <aside id="sg-viewer" class="sg-viewer" aria-live="polite" aria-label="Detalle del módulo">
        <div class="sg-viewer-top"><span class="sg-mono">Módulo <span id="sg-mod-n">01</span> / 09</span><span class="sg-chip sg-chip-purple" id="sg-mod-star" hidden>Módulo de SIGMA</span></div>
        <h3 id="sg-mod-name">Control de activos</h3>
        <div class="sg-viewer-stage" id="sg-viewer-stage">
          <div class="sg-mini-slot" data-mini="0">
            <div class="sg-mini" aria-hidden="true">
              <div class="sg-tree"><i style="background: #087BEA"></i>Planta Renca</div>
              <div class="sg-tree l1"><i style="background: #6732F4"></i>Línea 2</div>
              <div class="sg-tree l2"><i style="background: #16C6C9"></i>Dosificador de Manteca · ACT-10</div>
              <div class="sg-tree l3"><i style="background: #CFD6E3"></i>Rodamiento lado acople</div>
            </div>
          </div>
          <div class="sg-mini-slot" data-mini="1" hidden>
            <div class="sg-mini-img"><img src="Imagen/landing/scr-planificacion.jpg" alt="Captura real: Planificación del Centro de Mantenimiento" width="1424" height="800"></div>
          </div>
          <div class="sg-mini-slot" data-mini="2" hidden>
            <div class="sg-mini" aria-hidden="true">
              <div class="sg-row">Presión de descarga<span class="sg-chip sg-chip-success">En rango</span></div>
              <div class="sg-row">Temperatura<span class="sg-chip sg-chip-warning">Fuera de rango</span></div>
              <div class="sg-row">Si temperatura alta → revisar enfriador<span class="sg-chip sg-chip-blue">Dependencia</span></div>
            </div>
          </div>
          <div class="sg-mini-slot" data-mini="3" hidden>
            <div class="sg-mini" aria-hidden="true">
              <div class="sg-row">Rodamientos<span class="sg-meter"><b style="width: 72%; background: #16855B"></b></span></div>
              <div class="sg-row">Filtros de aire<span class="sg-meter"><b style="width: 22%; background: #B65C00"></b></span></div>
              <div class="sg-row">Correas<span class="sg-meter"><b style="width: 55%; background: #087BEA"></b></span></div>
            </div>
          </div>
          <div class="sg-mini-slot" data-mini="4" hidden>
            <div class="sg-mini-img"><img src="Imagen/landing/scr-twin.jpg" alt="Captura real de SIGMA Twin" width="1600" height="900"></div>
          </div>
          <div class="sg-mini-slot" data-mini="5" hidden>
            <div class="sg-mini" aria-hidden="true">
              <div class="sg-row">Permiso de trabajo en altura<span class="sg-chip sg-chip-success">Vigente</span></div>
              <div class="sg-row">Servicio contratado<span class="sg-chip sg-chip-blue">En planta</span></div>
              <div class="sg-row">Permiso en caliente<span class="sg-chip sg-chip-warning">Por vencer</span></div>
            </div>
          </div>
          <div class="sg-mini-slot" data-mini="6" hidden>
            <div class="sg-mini-img"><img src="Imagen/landing/scr-bandeja.jpg" alt="Captura real: bandeja de mantenciones" width="1424" height="860"></div>
          </div>
          <div class="sg-mini-slot" data-mini="7" hidden>
            <div class="sg-mini-img"><img src="Imagen/landing/scr-ai-monitoreo.jpg" alt="Captura real: Centro de monitoreo SIGMA AI" width="1600" height="834"></div>
          </div>
          <div class="sg-mini-slot" data-mini="8" hidden>
            <div class="sg-mini sg-mini-cyan" aria-hidden="true">
              <div class="sg-sync">
                <div class="sg-row"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#B65C00" stroke-width="2" stroke-linecap="round"><line x1="2" y1="2" x2="22" y2="22"></line><path d="M8.5 16.5a5 5 0 0 1 7 0"></path></svg>Sin señal: se guarda en el equipo</div>
                <div class="sg-row"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#007F8A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"></polyline><path d="M20.49 15A9 9 0 1 1 18.36 5.64L23 10"></path></svg>Al reconectar: sincronizado<span class="sg-chip sg-chip-success">Listo</span></div>
              </div>
            </div>
          </div>
        </div>
        <p id="sg-mod-desc">Equipos, componentes y la jerarquía de la planta, todo en un mismo registro.</p>
        <div class="sg-viewer-val"><b>Valor que aporta:</b> <span id="sg-mod-val">es la base única sobre la que se apoya el resto; nada se mantiene bien si antes no está bien identificado.</span></div>
        <span class="sg-viewer-big" id="sg-mod-big" aria-hidden="true">01</span>
      </aside>
    </div>
  </div>
</section>

<!-- ================= PLANES ================= -->
<section id="planes" class="sg-section" data-nav="light" style="scroll-margin-top: 80px; background: #F4F6FA" aria-labelledby="sg-planes">
  <div class="sg-wrap">
    <div class="sg-label sg-mono"><span>(07)</span><span>Planes</span></div>
    <div class="sg-split">
      <div class="sg-rv">
        <h2 id="sg-planes" class="sg-h2">Planes que crecen<br>con tu operación.</h2>
        <p class="sg-sub">Tres planes sobre la misma plataforma. Precios en UF, con descuento al pagar trimestral o anual.</p>
      </div>
      <div class="sg-plans-bar sg-rv">
        <div class="sg-bill" role="group" aria-label="Período de facturación">
          <button type="button" class="is-on" aria-pressed="true" data-bill="mensual">Mensual</button>
          <button type="button" class="" aria-pressed="false" data-bill="trimestral">Trimestral</button>
          <button type="button" class="" aria-pressed="false" data-bill="anual">Anual <span class="sg-chip sg-chip-cyan">Ahorra 17%</span></button>
        </div>
        <p>Valores en UF + IVA. Equivalente en pesos (CLP) al valor de la UF del día de facturación.</p>
      </div>
    </div>

    <div class="sg-plans">
      <article class="sg-plan sg-rv" aria-labelledby="pl-b">
        <div><h3 id="pl-b">Básico</h3><p class="sg-plan-desc">Mantenimiento preventivo por calendario para una planta.</p></div>
        <div><div class="sg-price"><b data-pb="basico">9</b><span>UF</span><small data-pp="basico">/ mes</small></div><p class="sg-price-sub" data-ps="basico">o 90 UF al año (ahorra 17%)</p></div>
        <div class="sg-limits"><span class="sg-chip sg-chip-neutral">1 planta</span><span class="sg-chip sg-chip-neutral">5 usuarios</span><span class="sg-chip sg-chip-neutral">150 activos</span><span class="sg-chip sg-chip-neutral">5 GB</span></div>
        <ul class="sg-feats">
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Gestión de activos y componentes</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Checklist dinámico y tareas</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Órdenes y planes de mantenimiento</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Programación por calendario</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Evidencia fotográfica</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Lectura en voz alta e inclusión</li>
        </ul>
        <a class="sg-btn sg-btn-outline sg-btn-lg sg-btn-block" href="Login.aspx">Comenzar con Básico</a>
      </article>

      <article class="sg-plan sg-plan-featured sg-rv" aria-labelledby="pl-m">
        <span class="sg-plan-flag">MÁS ELEGIDO</span>
        <div><h3 id="pl-m">Medio</h3><p class="sg-plan-desc">Suma horómetros, voz, inventario, terreno y el copiloto de SIGMA AI.</p></div>
        <div><div class="sg-price"><b data-pb="medio">22</b><span>UF</span><small data-pp="medio">/ mes</small></div><p class="sg-price-sub" data-ps="medio">o 220 UF al año (ahorra 17%)</p></div>
        <div class="sg-limits"><span class="sg-chip sg-chip-purple">3 plantas</span><span class="sg-chip sg-chip-purple">25 usuarios</span><span class="sg-chip sg-chip-purple">750 activos</span><span class="sg-chip sg-chip-purple">50 GB</span></div>
        <ul class="sg-feats">
          <li class="is-head">Todo lo de Básico, más:</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>SIGMA AI Chat: el copiloto de mantenimiento</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Programación por horómetro o ciclos</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Bitácora de trabajo y registro desde terreno</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Creación y dictado por voz</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Inventario de repuestos y proveedores</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Permisos de trabajo e importación desde Excel</li>
        </ul>
        <a class="sg-btn sg-btn-primary sg-btn-lg sg-btn-block" href="Login.aspx">Comenzar con Medio</a>
      </article>

      <article class="sg-plan sg-rv" aria-labelledby="pl-f">
        <div><h3 id="pl-f">Full</h3><p class="sg-plan-desc">Suma SIGMA Twin, predicción de fallas, análisis visual y API.</p></div>
        <div><div class="sg-price"><b data-pb="full">45</b><span>UF</span><small data-pp="full">/ mes</small></div><p class="sg-price-sub" data-ps="full">o 450 UF al año (ahorra 17%)</p></div>
        <div class="sg-limits"><span class="sg-chip sg-chip-neutral">Plantas ilimitadas</span><span class="sg-chip sg-chip-neutral">Usuarios ilimitados</span><span class="sg-chip sg-chip-neutral">500 GB</span></div>
        <ul class="sg-feats">
          <li class="is-head">Todo lo de Medio, más:</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>SIGMA Twin: gemelo digital de bodegas</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Análisis visual de fotografías</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Predicción de fallas y vida útil restante</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>Indicadores avanzados y exportación</li>
          <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>API para integrar con otros sistemas</li>
        </ul>
        <a class="sg-btn sg-btn-outline sg-btn-lg sg-btn-block" href="Login.aspx">Comenzar con Full</a>
      </article>
    </div>

    <p class="sg-plans-note"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>Todos los planes incluyen la app móvil con registro en terreno y un período de gracia al vencer. Los límites y funcionalidades se ajustan según el plan contratado.</p>

    <div class="sg-compare sg-rv">
      <div class="sg-compare-head"><h3>Compara los planes</h3><span class="sg-hint">Desliza la tabla en pantallas pequeñas.</span></div>
      <div class="sg-table-box" tabindex="0" role="region" aria-label="Tabla comparativa de planes">
        <table class="sg-table">
          <thead><tr><th scope="col">Incluye</th><th scope="col">Básico</th><th scope="col" class="is-feat">Medio</th><th scope="col">Full</th></tr></thead>
          <tbody>
            <tr class="sg-group"><th scope="colgroup" colspan="4">Límites</th></tr>
            <tr><th scope="row">Plantas</th><td><span>1</span></td><td class="is-feat"><span>3</span></td><td><span>Ilimitadas</span></td></tr>
            <tr><th scope="row">Usuarios</th><td><span>5</span></td><td class="is-feat"><span>25</span></td><td><span>Ilimitados</span></td></tr>
            <tr><th scope="row">Activos</th><td><span>150</span></td><td class="is-feat"><span>750</span></td><td><span>Ilimitados</span></td></tr>
            <tr><th scope="row">Almacenamiento</th><td><span>5 GB</span></td><td class="is-feat"><span>50 GB</span></td><td><span>500 GB</span></td></tr>
            <tr class="sg-group"><th scope="colgroup" colspan="4">Operación</th></tr>
            <tr><th scope="row">Gestión de activos y componentes</th><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Checklist dinámico y tareas</th><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Órdenes y planes de mantenimiento</th><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Programación por calendario</th><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Evidencia fotográfica</th><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">App móvil con registro en terreno</th><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Lectura en voz alta e inclusión</th><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr class="sg-group"><th scope="colgroup" colspan="4">Desde el plan Medio</th></tr>
            <tr><th scope="row">SIGMA AI Chat (copiloto)</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Programación por horómetro o ciclos</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Bitácora de trabajo y registro desde terreno</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Creación y dictado por voz</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Inventario de repuestos y proveedores</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Permisos de trabajo e importación desde Excel</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr class="sg-group"><th scope="colgroup" colspan="4">Plan Full</th></tr>
            <tr><th scope="row">SIGMA Twin · gemelo digital de bodegas</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-no" aria-label="No incluido">—</span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Análisis visual de fotografías</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-no" aria-label="No incluido">—</span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Predicción de fallas y vida útil restante</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-no" aria-label="No incluido">—</span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">Indicadores avanzados y exportación</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-no" aria-label="No incluido">—</span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
            <tr><th scope="row">API para integrar con otros sistemas</th><td><span class="sg-no" aria-label="No incluido">—</span></td><td class="is-feat"><span class="sg-no" aria-label="No incluido">—</span></td><td><span class="sg-yes" role="img" aria-label="Incluido"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span></td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ================= ASESORÍA ================= -->
    <div id="asesoria" class="sg-lead sg-rv" style="scroll-margin-top: 96px">
      <aside class="sg-lead-side" aria-labelledby="sg-ases">
        <span class="sg-eyebrow sg-eyebrow-cyan">Asesoría sin costo</span>
        <h2 id="sg-ases">¿Prefieres que te asesoremos?</h2>
        <p>Cuéntanos de tu operación y un especialista te contacta para recomendarte el plan y ayudarte a poner SIGMA en marcha.</p>
        <ul class="sg-benefits">
          <li><span>01</span>Demo personalizada según tu planta</li>
          <li><span>02</span>Acompañamiento en la puesta en marcha</li>
          <li><span>03</span>Migración de tus activos y datos</li>
          <li><span>04</span>Respuesta dentro de 1 día hábil</li>
        </ul>
        <p class="sg-lead-foot">Tus datos solo se usan para responder esta solicitud.</p>
      </aside>

      <div class="sg-done" id="sg-done" role="status" aria-live="polite" hidden>
        <span class="sg-done-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg></span>
        <h3>¡Listo, <span id="sg-done-name">gracias</span>! Recibimos tu solicitud.</h3>
        <p>Te escribiremos a <strong id="sg-done-mail"></strong> dentro de 1 día hábil. Lo que sigue:</p>
        <ol>
          <li>Revisamos tu operación y el plan que te interesa.</li>
          <li>Agendamos una demo personalizada según tu planta.</li>
          <li>Te acompañamos en la puesta en marcha.</li>
        </ol>
        <button type="button" class="sg-btn sg-btn-ghost" id="sg-reset">Enviar otra solicitud</button>
      </div>

      <div class="sg-form" id="sg-form" aria-labelledby="sg-form-t">
        <ol class="sg-stepper" aria-label="Pasos del formulario">
          <li class="is-current" aria-current="step" data-st="1"><b>1 · Tus datos</b><span>Contacto</span></li>
          <li class="" aria-current="false" data-st="2"><b>2 · Tu empresa</b><span>Rubro y tamaño</span></li>
          <li class="" aria-current="false" data-st="3"><b>3 · Tu operación</b><span>Plan e interés</span></li>
        </ol>
        <div class="sg-form-title"><h3 id="sg-form-t">¿Cómo te contactamos?</h3><small>Los campos con <abbr title="obligatorio" style="color: #C7352B; text-decoration: none">*</abbr> son obligatorios</small></div>

        <div class="sg-alert sg-alert-danger" id="sg-summary" role="alert" hidden><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg><span id="sg-summary-txt">Revisa los campos marcados para continuar.</span></div>

        <div class="sg-fields" data-step="1">
          <div class="sg-field" data-f="nombre">
            <label for="asNombre">Nombre <abbr title="obligatorio">*</abbr></label>
            <input id="asNombre" class="sg-input" type="text" autocomplete="given-name" required aria-required="true" aria-invalid="false" aria-describedby="asNombreErr">
            <span id="asNombreErr" class="sg-err" hidden></span>
          </div>
          <div class="sg-field" data-f="apellido">
            <label for="asApellido">Apellido</label>
            <input id="asApellido" class="sg-input" type="text" autocomplete="family-name">
          </div>
          <div class="sg-field" data-f="correo">
            <label for="asCorreo">Correo corporativo <abbr title="obligatorio">*</abbr></label>
            <input id="asCorreo" class="sg-input" type="email" autocomplete="email" placeholder="nombre@empresa.cl" required aria-required="true" aria-invalid="false" aria-describedby="asCorreoErr">
            <span id="asCorreoErr" class="sg-err" hidden></span>
          </div>
          <div class="sg-field" data-f="telefono">
            <label for="asTelefono">Teléfono</label>
            <input id="asTelefono" class="sg-input" type="tel" autocomplete="tel" placeholder="+56 9 1234 5678">
          </div>
        </div>

        <div class="sg-fields" data-step="2" hidden>
          <div class="sg-field" data-f="empresa">
            <label for="asEmpresa">Empresa <abbr title="obligatorio">*</abbr></label>
            <input id="asEmpresa" class="sg-input" type="text" autocomplete="organization" required aria-required="true" aria-invalid="false" aria-describedby="asEmpresaErr">
            <span id="asEmpresaErr" class="sg-err" hidden></span>
          </div>
          <div class="sg-field" data-f="rubro">
            <label for="asRubro">Rubro</label>
            <select id="asRubro" class="sg-input">
              <option value="">Selecciona…</option><option>Minería</option><option>Energía</option><option>Alimentos y bebidas</option><option>Manufactura e industria</option><option>Forestal y celulosa</option><option>Agroindustria</option><option>Retail y logística</option><option>Salud</option><option>Otro</option>
            </select>
          </div>
          <div class="sg-field" data-f="cargo">
            <label for="asCargo">Cargo</label>
            <input id="asCargo" class="sg-input" type="text" autocomplete="organization-title" placeholder="Ej.: Jefatura de mantenimiento">
          </div>
          <div class="sg-field" data-f="pais">
            <label for="asPais">País</label>
            <select id="asPais" class="sg-input">
              <option value="Chile">Chile</option><option value="Perú">Perú</option><option value="Colombia">Colombia</option><option value="México">México</option><option value="Argentina">Argentina</option><option value="Ecuador">Ecuador</option><option value="Otro">Otro país…</option>
            </select>
          </div>
          <div class="sg-field" data-f="ident">
            <label for="asIdent" id="asIdentLbl">RUT de tu empresa</label>
            <input id="asIdent" class="sg-input" type="text" maxlength="30" autocomplete="off" placeholder="76.123.456-7" aria-describedby="asMoneda">
            <span id="asMoneda" class="sg-hint">Se cotiza en UF y se cobra en pesos (CLP).</span>
          </div>
          <div class="sg-field" data-f="activos">
            <label for="asActivos">N.° de activos aprox.</label>
            <select id="asActivos" class="sg-input">
              <option value="">Selecciona…</option><option>Menos de 150</option><option>Entre 150 y 750</option><option>Más de 750</option><option>Aún no lo sé</option>
            </select>
          </div>
        </div>

        <div class="sg-fields" data-step="3" hidden>
          <div class="sg-field" data-f="plan">
            <label for="asPlan">Plan de interés</label>
            <select id="asPlan" class="sg-input">
              <option value="">Selecciona…</option><option>Básico</option><option>Medio</option><option>Full</option><option>No estoy seguro</option>
            </select>
          </div>
          <div class="sg-field sg-field-full" data-f="mensaje">
            <label for="asMensaje">Cuéntanos de tu operación</label>
            <textarea id="asMensaje" class="sg-input" placeholder="Tipo de planta, cuántas personas mantienen los equipos, qué buscas resolver…"></textarea>
          </div>
          <%-- Honeypot: invisible para las personas; un robot lo llena y el servidor lo descarta. --%>
          <div style="position:absolute;left:-10000px;width:1px;height:1px;overflow:hidden" aria-hidden="true">
            <label for="asWeb">Sitio web</label>
            <input type="text" id="asWeb" name="web" tabindex="-1" autocomplete="off" />
          </div>
          <div class="sg-field sg-field-full" data-f="consent">
            <label class="sg-consent" id="asConsentWrap" for="asConsent">
              <input id="asConsent" type="checkbox" required aria-required="true" aria-invalid="false" aria-describedby="asConsentErr">
              <span>Autorizo a Código Creativo a contactarme para orientarme sobre SIGMA. <abbr title="obligatorio" style="color: #C7352B; text-decoration: none">*</abbr></span>
            </label>
            <span id="asConsentErr" class="sg-err" hidden></span>
          </div>
          <div class="sg-alert sg-alert-danger" id="asErr" role="alert" hidden></div>
        </div>

        <div class="sg-form-actions">
          <span class="sg-hint">Paso <span id="sg-step-n">1</span> de 3</span>
          <div class="sg-group">
            <button type="button" class="sg-btn sg-btn-ghost sg-btn-lg" id="sg-back" hidden>Volver</button>
            <button type="button" class="sg-btn sg-btn-primary sg-btn-lg" id="sg-next">Continuar<svg class="sg-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></button>
            <button type="button" class="sg-btn sg-btn-primary sg-btn-lg" id="sg-send" aria-busy="false" hidden><span class="sg-spin" aria-hidden="true" hidden></span><span id="sg-send-txt">Solicitar asesoría</span><svg class="sg-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></button>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- ================= QUIÉNES SOMOS ================= -->
<section id="nosotros" class="sg-section sg-section-white" data-nav="light" style="scroll-margin-top: 80px" aria-labelledby="sg-nos">
  <div class="sg-wrap">
    <div class="sg-label sg-mono"><span>(08)</span><span>Quiénes somos</span></div>
    <div class="sg-about">
      <div>
        <h2 id="sg-nos" class="sg-h2 sg-rv">Hecho por<br>Código Creativo.</h2>
        <div class="sg-about-text sg-rv">
          <p>Somos <strong>Código Creativo</strong>, un equipo que construye SIGMA: el Sistema Integrado de Gestión de Mantenimiento Industrial. Nacimos de una idea simple: el mantenimiento de una planta no debería vivir en planillas sueltas ni en la memoria de quien lleva años en el cargo.</p>
          <p>Por eso creamos una plataforma que une el escritorio y la planta —órdenes, activos, checklists, inventario e indicadores— y la acercamos a quien hace el trabajo, con registro en terreno e inteligencia que ayuda a anticiparse a las fallas.</p>
        </div>
        <div class="sg-cc sg-rv"><img src="Imagen/landing/codigo-creativo-logo.png" alt="Código Creativo" width="134" height="64"><p>SIGMA, SIGMA AI y SIGMA Twin son productos de Código Creativo: diseño, desarrollo e inteligencia hechos por el mismo equipo.</p></div>
        <div class="sg-values">
          <div class="sg-value sg-rv"><span class="sg-mono">— 01</span><h3>Pensado para terreno</h3><p>Lo diseñamos con y para quienes mantienen equipos, no solo para quien reporta.</p></div>
          <div class="sg-value sg-rv"><span class="sg-mono">— 02</span><h3>Anticiparse, no reaccionar</h3><p>Datos e IA al servicio de prevenir la falla antes de que detenga la planta.</p></div>
          <div class="sg-value sg-rv"><span class="sg-mono">— 03</span><h3>Accesible e inclusivo</h3><p>Voz, lectura en voz alta y una interfaz clara para que cualquiera pueda usarlo.</p></div>
        </div>
      </div>
      <aside class="sg-mission sg-rv" aria-labelledby="sg-mis">
        <span class="sg-eyebrow sg-eyebrow-cyan">Nuestra misión</span>
        <h3 id="sg-mis">Que cada planta tenga su mantenimiento bajo control.</h3>
        <p>Ordenado, trazable y a la mano, del escritorio al terreno y de vuelta.</p>
        <div class="sg-figs">
          <div class="sg-fig"><b>1</b><small>plataforma, todo integrado</small></div>
          <div class="sg-fig"><b>3</b><small>planes a tu medida</small></div>
          <div class="sg-fig"><b><span>+</span>8</b><small>módulos conectados</small></div>
          <div class="sg-fig"><b>IA</b><small>voz y predicción</small></div>
        </div>
        <div class="sg-a11y"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M15.5 8.5a5 5 0 0 1 0 7"></path></svg><span>Lectura en voz alta e inclusión, en todos los planes.</span></div>
      </aside>
    </div>
  </div>
</section>

<!-- ================= FINAL ================= -->
<section class="sg-final sg-dark" data-nav="dark" aria-labelledby="sg-final">
  <div class="sg-grain" aria-hidden="true"></div>
  <div class="sg-wrap sg-final-in">
    <span class="sg-mono" style="color: rgba(255,255,255,.5)">(09) Empieza hoy</span>
    <h2 id="sg-final">Bajo control<em>.</em></h2>
    <p>Ingresa si tu empresa ya usa SIGMA, o pide una asesoría sin costo y te ayudamos a ponerlo en marcha.</p>
    <div class="sg-group">
      <a class="sg-btn sg-btn-primary sg-btn-lg sg-magnet" href="Login.aspx">Ingresar a SIGMA</a>
      <a class="sg-btn sg-btn-secondary sg-btn-lg sg-magnet" href="#asesoria">Solicitar una demo</a>
    </div>
  </div>
  <footer class="sg-foot">
    <div class="sg-wrap sg-foot-in">
      <img src="Imagen/sigma-logo-horizontal-dark.svg" alt="SIGMA" width="73" height="24">
      <span class="sg-foot-cc"><span class="sg-mono">Un producto de</span><img src="Imagen/landing/codigo-creativo-logo.png" alt="Código Creativo" width="71" height="34"></span>
      <nav aria-label="Pie de página">
        <a href="#inicio">Inicio</a>
        <a href="#sigma-ai">SIGMA AI</a>
        <a href="#sigma-twin">SIGMA Twin</a>
        <a href="#planes">Planes</a>
        <a href="#asesoria">Contacto</a>
        <a href="Login.aspx">Ingresar</a>
      </nav>
      <p class="sg-foot-copy">© 2026 Código Creativo · SIGMA — Sistema Integrado de Gestión de Mantenimiento Industrial</p>
    </div>
  </footer>
</section>
</main>
</div>
</body>
</html>
