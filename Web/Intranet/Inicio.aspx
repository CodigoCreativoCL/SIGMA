<%@ Page Language="C#" AutoEventWireup="true" %>
<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <title>SIGMA · Sistema Integrado de Gestión de Mantenimiento Industrial</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="SIGMA · Órdenes de trabajo, activos, checklists, inventario e indicadores de mantenimiento industrial en un solo lugar." />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="theme-color" content="#0B0F1A" />

    <link href="Imagen/sigma-favicon.svg" rel="icon" type="image/svg+xml" />
    <link href="Css/Inicio/sigma-inicio.css?vrs=1" rel="stylesheet" />
</head>
<body>
    <div class="sg-home">

        <!-- ---------- Barra superior ---------- -->
        <header class="sg-nav">
            <div class="sg-nav-logo">
                <img src="Imagen/sigma-logo-horizontal-dark.svg"
                     alt="SIGMA · Sistema Integrado de Gestión de Mantenimiento Industrial" />
            </div>
            <nav class="sg-nav-actions">
                <a class="sg-nav-link" href="RecuperarClave.aspx">Olvidé mi contraseña</a>
                <a class="sg-btn sg-btn-primary" href="Login.aspx">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                    Ingresar
                </a>
            </nav>
        </header>

        <!-- ---------- Hero ---------- -->
        <section class="sg-hero">
            <span class="sg-hero-glow" aria-hidden="true"></span>
            <span class="sg-hero-glow is-teal" aria-hidden="true"></span>
            <div class="sg-hero-inner">
                <span class="sg-eyebrow">Sistema Integrado de Gestión de Mantenimiento</span>
                <h1>El mantenimiento industrial,<br /><span class="grad">bajo control.</span></h1>
                <p>
                    Órdenes de trabajo, activos, checklists, inventario e indicadores en un
                    solo lugar. Del escritorio a la planta, y de vuelta.
                </p>
                <div class="sg-cta">
                    <a class="sg-btn sg-btn-primary" href="Login.aspx">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                        Ingresar a SIGMA
                    </a>
                    <a class="sg-btn sg-btn-ghost" href="RecuperarClave.aspx">Recuperar mi contraseña</a>
                </div>
                <p class="sg-hero-note">¿Problemas para entrar? Contacta al administrador de tu planta.</p>
            </div>
        </section>

        <!-- ---------- Capacidades ---------- -->
        <main class="sg-features">
            <div class="sg-features-head">
                <h2>Todo el mantenimiento, en una plataforma</h2>
                <p>Planificado y correctivo en un mismo flujo, con registro en terreno e inteligencia asistida.</p>
            </div>
            <div class="sg-grid">

                <article class="sg-card">
                    <div class="sg-card-icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>
                    </div>
                    <h3>Órdenes de trabajo</h3>
                    <p>Trabajo planificado y correctivo en un mismo flujo, con prioridades, programación y cierre.</p>
                </article>

                <article class="sg-card">
                    <div class="sg-card-icon is-teal">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/></svg>
                    </div>
                    <h3>Activos y checklists</h3>
                    <p>Pautas de inspección con umbrales, hallazgos y dependencias entre ítems para cada equipo.</p>
                </article>

                <article class="sg-card">
                    <div class="sg-card-icon is-blue">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>
                    </div>
                    <h3>Inventario</h3>
                    <p>Repuestos y existencias por planta, con movimientos y disponibilidad siempre a mano.</p>
                </article>

                <article class="sg-card">
                    <div class="sg-card-icon is-pink">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 2a3 3 0 0 0-3 3v1a3 3 0 0 0-3 3 3 3 0 0 0 0 6 3 3 0 0 0 3 3v1a3 3 0 0 0 6 0v-1a3 3 0 0 0 3-3 3 3 0 0 0 0-6 3 3 0 0 0-3-3V5a3 3 0 0 0-3-3z"/></svg>
                    </div>
                    <h3>SIGMA AI</h3>
                    <p>Registro por voz, predicción de fallas y recomendaciones para adelantarse a los problemas.</p>
                </article>

            </div>
        </main>

        <!-- ---------- Pie ---------- -->
        <footer class="sg-footer">
            <img src="Imagen/sigma-logo-horizontal-dark.svg" alt="SIGMA" />
            <div class="sg-footer-links">
                <a href="Privacidad/Privacidad.aspx">Privacidad</a>
                <a href="Login.aspx">Ingresar</a>
                <span>Código Creativo · SIGMA 2026</span>
            </div>
        </footer>

    </div>
</body>
</html>
