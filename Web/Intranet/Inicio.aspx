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
    <link href="Css/Inicio/sigma-inicio.css?vrs=2" rel="stylesheet" />
</head>
<body>
    <div class="sg-home">

        <!-- ---------- Barra superior con pestañas ---------- -->
        <header class="sg-topbar">
            <div class="sg-topbar-logo">
                <img src="Imagen/sigma-logo-horizontal-dark.svg"
                     alt="SIGMA · Sistema Integrado de Gestión de Mantenimiento Industrial" />
            </div>
            <nav class="sg-tabs" role="tablist" aria-label="Secciones">
                <button type="button" class="sg-tab" data-tab="inicio" role="tab">Inicio</button>
                <button type="button" class="sg-tab" data-tab="planes" role="tab">Planes</button>
                <button type="button" class="sg-tab" data-tab="componentes" role="tab">Componentes</button>
                <button type="button" class="sg-tab" data-tab="quienes" role="tab">Quiénes somos</button>
            </nav>
            <a class="sg-topbar-cta" href="Login.aspx">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                Ingresar
            </a>
        </header>

        <!-- ================= INICIO ================= -->
        <section class="sg-panel" data-panel="inicio" role="tabpanel">
            <div class="sg-hero">
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
                        <button type="button" class="sg-btn sg-btn-ghost" data-tab="planes">Ver los planes</button>
                    </div>
                    <p class="sg-hero-note">¿Problemas para entrar? Contacta al administrador de tu planta.</p>
                </div>
            </div>

            <div class="sg-features">
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
            </div>
        </section>

        <!-- ================= PLANES ================= -->
        <section class="sg-panel" data-panel="planes" role="tabpanel">
            <div class="sg-section">
                <div class="sg-section-head">
                    <span class="sg-eyebrow">Oferta comercial</span>
                    <h2>Planes que crecen con tu operación</h2>
                    <p>Tres planes sobre la misma plataforma. Precios en UF; valor mensual, con descuento al pagar trimestral o anual.</p>
                </div>

                <div class="sg-pricing">

                    <!-- Básico -->
                    <div class="sg-plan">
                        <h3 class="sg-plan-name">Básico</h3>
                        <p class="sg-plan-tagline">Mantenimiento preventivo por calendario para una planta.</p>
                        <div class="sg-plan-price"><span class="num">9</span><span class="uf">UF</span><span class="per">/ mes</span></div>
                        <p class="sg-plan-year">o 90 UF al año (ahorra 17%)</p>
                        <div class="sg-plan-limits">
                            <span class="sg-chip">1 planta</span>
                            <span class="sg-chip">5 usuarios</span>
                            <span class="sg-chip">150 activos</span>
                            <span class="sg-chip">5 GB</span>
                        </div>
                        <ul class="sg-plan-feats">
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Gestión de activos y componentes</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Checklist dinámico y tareas</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Órdenes y planes de mantenimiento</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Programación por calendario</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Evidencia fotográfica</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Lectura en voz alta e inclusión</li>
                        </ul>
                        <a class="sg-btn sg-btn-outline" href="Login.aspx">Comenzar</a>
                    </div>

                    <!-- Medio -->
                    <div class="sg-plan is-featured">
                        <span class="sg-plan-badge">Más elegido</span>
                        <h3 class="sg-plan-name">Medio</h3>
                        <p class="sg-plan-tagline">Suma horómetros, voz, inclusión, inventario y terreno.</p>
                        <div class="sg-plan-price"><span class="num">22</span><span class="uf">UF</span><span class="per">/ mes</span></div>
                        <p class="sg-plan-year">o 220 UF al año (ahorra 17%)</p>
                        <div class="sg-plan-limits">
                            <span class="sg-chip">3 plantas</span>
                            <span class="sg-chip">25 usuarios</span>
                            <span class="sg-chip">750 activos</span>
                            <span class="sg-chip">50 GB</span>
                        </div>
                        <ul class="sg-plan-feats">
                            <li class="is-head">Todo lo de Básico, más:</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Programación por horómetro o ciclos</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Bitácora del técnico y registro desde terreno</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Creación y dictado por voz</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Inventario de repuestos y proveedores</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Permisos de trabajo e importación desde Excel</li>
                        </ul>
                        <a class="sg-btn sg-btn-primary" href="Login.aspx">Comenzar</a>
                    </div>

                    <!-- Full -->
                    <div class="sg-plan">
                        <h3 class="sg-plan-name">Full</h3>
                        <p class="sg-plan-tagline">Suma análisis visual, predicción de fallas y API de integración.</p>
                        <div class="sg-plan-price"><span class="num">45</span><span class="uf">UF</span><span class="per">/ mes</span></div>
                        <p class="sg-plan-year">o 450 UF al año (ahorra 17%)</p>
                        <div class="sg-plan-limits">
                            <span class="sg-chip">Plantas ilimitadas</span>
                            <span class="sg-chip">Usuarios ilimitados</span>
                            <span class="sg-chip">500 GB</span>
                        </div>
                        <ul class="sg-plan-feats">
                            <li class="is-head">Todo lo de Medio, más:</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Análisis visual de fotografías</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Predicción de fallas y vida útil restante</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>Indicadores avanzados y exportación</li>
                            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>API para integrar con otros sistemas</li>
                        </ul>
                        <a class="sg-btn sg-btn-solid" href="Login.aspx">Comenzar</a>
                    </div>

                </div>
                <p class="sg-pricing-note">Todos los planes incluyen la app móvil con registro en terreno y un período de gracia al vencer. Los límites y funcionalidades se ajustan según el plan contratado.</p>
            </div>
        </section>

        <!-- ================= COMPONENTES ================= -->
        <section class="sg-panel" data-panel="componentes" role="tabpanel">
            <div class="sg-section">
                <div class="sg-section-head">
                    <span class="sg-eyebrow">Cómo está hecho</span>
                    <h2>Los componentes del sistema</h2>
                    <p>SIGMA reúne módulos que trabajan juntos: cada uno resuelve una parte del mantenimiento y comparte la misma información.</p>
                </div>
                <div class="sg-grid">

                    <article class="sg-card">
                        <div class="sg-card-icon is-navy">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21h18"/><path d="M5 21V7l8-4v18"/><path d="M19 21V11l-6-4"/></svg>
                        </div>
                        <h3>Control de activos</h3>
                        <p>Equipos, componentes y la jerarquía de la planta. La base que todo lo demás referencia.</p>
                    </article>

                    <article class="sg-card">
                        <div class="sg-card-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
                        </div>
                        <h3>Centro de mantenimiento</h3>
                        <p>Órdenes de trabajo, planes y programaciones. Coordina el trabajo preventivo y correctivo.</p>
                    </article>

                    <article class="sg-card">
                        <div class="sg-card-icon is-teal">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>
                        </div>
                        <h3>Pautas de inspección</h3>
                        <p>Checklists dinámicos con umbrales, dependencias entre ítems y hallazgos que derivan en acciones.</p>
                    </article>

                    <article class="sg-card">
                        <div class="sg-card-icon is-blue">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>
                        </div>
                        <h3>Inventario</h3>
                        <p>Catálogo de repuestos, bodegas y existencias. Qué hay, dónde está y cuánto queda.</p>
                    </article>

                    <article class="sg-card">
                        <div class="sg-card-icon is-amber">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                        </div>
                        <h3>Terceros y permisos</h3>
                        <p>Proveedores, servicios contratados y permisos de trabajo para coordinar a quienes entran a la planta.</p>
                    </article>

                    <article class="sg-card">
                        <div class="sg-card-icon is-pink">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2a3 3 0 0 0-3 3v1a3 3 0 0 0-3 3 3 3 0 0 0 0 6 3 3 0 0 0 3 3v1a3 3 0 0 0 6 0v-1a3 3 0 0 0 3-3 3 3 0 0 0 0-6 3 3 0 0 0-3-3V5a3 3 0 0 0-3-3z"/></svg>
                        </div>
                        <h3>SIGMA AI</h3>
                        <p>Voz para registrar sin teclado, análisis visual de fotos y predicción de fallas sobre tus datos.</p>
                    </article>

                    <article class="sg-card">
                        <div class="sg-card-icon is-teal">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2"/><line x1="12" y1="18" x2="12" y2="18"/></svg>
                        </div>
                        <h3>App móvil y sincronización</h3>
                        <p>Registro en terreno incluso sin cobertura; los datos se sincronizan al recuperar la conexión.</p>
                    </article>

                    <article class="sg-card">
                        <div class="sg-card-icon is-navy">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="20" x2="12" y2="10"/><line x1="18" y1="20" x2="18" y2="4"/><line x1="6" y1="20" x2="6" y2="16"/></svg>
                        </div>
                        <h3>Indicadores y comercial</h3>
                        <p>Tableros de gestión, exportación de datos y la administración de la suscripción y sus pagos.</p>
                    </article>

                </div>
            </div>
        </section>

        <!-- ================= QUIÉNES SOMOS ================= -->
        <section class="sg-panel" data-panel="quienes" role="tabpanel">
            <div class="sg-section">
                <div class="sg-section-head">
                    <span class="sg-eyebrow">Quiénes somos</span>
                    <h2>Hecho por Código Creativo</h2>
                </div>
                <div class="sg-about">
                    <div>
                        <p class="sg-about-lead">
                            Somos <strong>Código Creativo</strong>, un equipo que construye SIGMA: el Sistema Integrado
                            de Gestión de Mantenimiento Industrial. Nacimos de una idea simple: el mantenimiento de una
                            planta no debería vivir en planillas sueltas ni en la memoria de quien lleva años en el cargo.
                        </p>
                        <p class="sg-about-lead">
                            Por eso creamos una plataforma que une el escritorio y la planta —órdenes, activos, checklists,
                            inventario e indicadores— y la acercamos a quien hace el trabajo, con registro en terreno e
                            inteligencia que ayuda a anticiparse a las fallas.
                        </p>
                        <div class="sg-values">
                            <div class="sg-value">
                                <div class="sg-value-icon">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
                                </div>
                                <div>
                                    <h4>Pensado para terreno</h4>
                                    <p>Lo diseñamos con y para quienes mantienen equipos, no solo para quien reporta.</p>
                                </div>
                            </div>
                            <div class="sg-value">
                                <div class="sg-value-icon">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
                                </div>
                                <div>
                                    <h4>Anticiparse, no reaccionar</h4>
                                    <p>Datos e IA al servicio de prevenir la falla antes de que detenga la planta.</p>
                                </div>
                            </div>
                            <div class="sg-value">
                                <div class="sg-value-icon">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/></svg>
                                </div>
                                <div>
                                    <h4>Accesible e inclusivo</h4>
                                    <p>Voz, lectura en voz alta y una interfaz clara para que cualquiera pueda usarlo.</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <aside class="sg-about-card">
                        <h3>Nuestra misión</h3>
                        <p>
                            Que cada planta tenga su mantenimiento bajo control: ordenado, trazable y a la mano,
                            del escritorio al terreno y de vuelta.
                        </p>
                        <div class="sg-stats">
                            <div class="sg-stat"><div class="n">1</div><div class="l">plataforma, todo integrado</div></div>
                            <div class="sg-stat"><div class="n">3</div><div class="l">planes a tu medida</div></div>
                            <div class="sg-stat"><div class="n">+8</div><div class="l">módulos conectados</div></div>
                            <div class="sg-stat"><div class="n">IA</div><div class="l">voz y predicción</div></div>
                        </div>
                    </aside>
                </div>
            </div>
        </section>

        <!-- ---------- Pie ---------- -->
        <footer class="sg-footer">
            <img src="Imagen/sigma-logo-horizontal-dark.svg" alt="SIGMA" />
            <div class="sg-footer-links">
                <button type="button" class="sg-link-btn" data-tab="planes">Planes</button>
                <button type="button" class="sg-link-btn" data-tab="componentes">Componentes</button>
                <button type="button" class="sg-link-btn" data-tab="quienes">Quiénes somos</button>
                <a href="Privacidad/Privacidad.aspx">Privacidad</a>
                <a href="Login.aspx">Ingresar</a>
                <span>Código Creativo · SIGMA 2026</span>
            </div>
        </footer>

    </div>

    <script type="text/javascript">
        (function () {
            var tabs = document.querySelectorAll('[data-tab]');
            var panels = document.querySelectorAll('[data-panel]');
            var names = {};
            for (var i = 0; i < panels.length; i++) { names[panels[i].getAttribute('data-panel')] = true; }

            function activate(name, push) {
                if (!names[name]) { name = 'inicio'; }
                for (var i = 0; i < panels.length; i++) {
                    panels[i].classList.toggle('is-active', panels[i].getAttribute('data-panel') === name);
                }
                var tablist = document.querySelectorAll('.sg-tab');
                for (var j = 0; j < tablist.length; j++) {
                    var on = tablist[j].getAttribute('data-tab') === name;
                    tablist[j].classList.toggle('is-active', on);
                    tablist[j].setAttribute('aria-selected', on ? 'true' : 'false');
                }
                if (push && window.history && history.replaceState) {
                    history.replaceState(null, '', '#' + name);
                }
                window.scrollTo(0, 0);
            }

            for (var k = 0; k < tabs.length; k++) {
                tabs[k].addEventListener('click', function (e) {
                    if (this.tagName === 'BUTTON') { e.preventDefault(); }
                    activate(this.getAttribute('data-tab'), true);
                });
            }

            var initial = (location.hash || '#inicio').replace('#', '');
            activate(initial, false);
        })();
    </script>
</body>
</html>
