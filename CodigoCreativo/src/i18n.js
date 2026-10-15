// Textos de la landing en español e inglés.
// El HTML trae el español como base (SEO / sin JS); este diccionario manda cuando hay JS.
// Los valores pueden llevar <br> y <em>: se insertan como HTML.

const DICT = {
  es: {
    'meta.title': 'Código Creativo — Software, IA y experiencias digitales | Creadores de SIGMA',
    'meta.desc': 'Código Creativo crea software, inteligencia artificial y experiencias digitales. Creadores de SIGMA, la plataforma de mantenimiento industrial con los módulos SIGMA AI y SIGMA TWIN.',

    'nav.eco': 'Ecosistema',
    'nav.lab': 'Laboratorio',
    'nav.work': 'Proyectos',
    'nav.cta': 'Iniciar proyecto',

    'label.hero': 'Inicio',
    'label.phil': 'Filosofía',
    'label.eco': 'Ecosistema',
    'label.sigma': 'SIGMA',
    'label.ai': 'SIGMA AI',
    'label.lab': 'Laboratorio',
    'label.work': 'Proyectos',
    'label.trans': 'Lo que sigue',
    'label.cta': 'Contacto',

    'hero.eyebrow': 'Software · Inteligencia artificial · Experiencias digitales',
    'hero.sub': 'Creamos soluciones.<br>Impulsamos el futuro.',
    'hero.w1': 'CONSTRUIR',
    'hero.w2': 'CREAR',
    'hero.w3': 'TRANSFORMAR',
    'hero.scroll': 'Desliza',

    'tag.phil': '02 — Filosofía',
    'phil.p1': 'NO SOLO HACEMOS SOFTWARE.',
    'phil.p2': 'CREAMOS <em>EXPERIENCIAS.</em>',
    'phil.p3': 'CREAMOS <em>SISTEMAS.</em>',
    'phil.p4': 'CREAMOS <em>EL FUTURO.</em>',

    'tag.eco': '03 — Ecosistema',
    'eco.title': 'Un núcleo.<br>Muchas soluciones.',
    'eco.sigma': 'Plataforma de mantenimiento',
    'eco.go': 'Visitar ↗',
    'eco.module': 'MÓDULO DE SIGMA',
    'eco.ai': 'Inteligencia predictiva',
    'eco.twin': 'Gemelo digital',
    'eco.soft': 'A la medida',

    'tag.sigma': '04 — Producto',
    'sigma.line': 'Toda la planta, en un solo sistema.',
    'sigma.go': 'Ir a SIGMA',
    'sigma.m1': 'ACTIVOS',
    'sigma.m2': 'ÓRDENES DE TRABAJO',
    'sigma.m3': 'MANTENIMIENTO',
    'sigma.m4': 'ANALÍTICA',
    'sigma.readout': 'ACTIVOS EN LÍNEA ▸ 15<br>ÓRDENES ABIERTAS ▸ 6<br>PLAN PREVENTIVO ▸ AL DÍA',
    'sigma.f1': 'Caos',
    'sigma.f2': 'Organización',
    'sigma.f3': 'Información',
    'sigma.f4': 'Predicción',
    'sigma.alert': 'PRENSA-07 · Falla probable',

    'tag.ai': '05 — Módulo de inteligencia de SIGMA',
    'ai.s1': 'DATOS',
    'ai.s2': 'ANÁLISIS',
    'ai.s3': 'PREDICCIÓN',
    'ai.s4': 'ACCIÓN',
    'ai.l1': 'PROBABILIDAD DE FALLA',
    'ai.days': 'DÍAS',
    'ai.l2': 'VENTANA ESTIMADA',
    'ai.final': 'ACTÚA ANTES<br>DE LA FALLA.',

    'tag.lab': '06 — Laboratorio',
    'lab.w1': 'EXPERIMENTAMOS.',
    'lab.w2': 'DISEÑAMOS.',
    'lab.w3': 'CREAMOS.',
    'lab.mobile': 'MÓVIL',
    'lab.ai': 'IA',
    'lab.auto': 'AUTOMATIZACIÓN',
    'lab.data': 'DATOS',

    'tag.work': '07 — Proyectos',
    'work.p1': 'Plataforma de mantenimiento industrial de punta a punta, con módulos de inteligencia integrados.',
    'work.module': 'Módulo de inteligencia de SIGMA',
    'work.goSigma': 'Ir a SIGMA',
    'work.goModule': 'Verlo en SIGMA',
    'work.p2': 'Predice la falla antes de que detenga la línea.',
    'work.p3': 'La planta replicada en 3D y conectada a sus datos en tiempo real.',
    'work.t4': 'SOLUCIONES DIGITALES',
    'work.p4': 'Producto digital a la medida: web, móvil, automatización y nube.',
    'work.mobile': 'MÓVIL',
    'work.analytics': 'ANALÍTICA',
    'work.realtime': 'TIEMPO REAL',
    'work.v1a': 'PLANTA · 40 ACTIVOS',
    'work.v1b': '1 CRÍTICO',
    'work.v2a': 'PRENSA-07 · VIBRACIÓN',
    'work.v2limit': 'UMBRAL',
    'work.v2window': '12 DÍAS',
    'work.v2today': 'HOY',
    'work.v3a': 'GEMELO DIGITAL · NAVE 2',
    'video.sound': 'Activar voz',
    'video.mute': 'Silenciar',
    'work.code':
      '<span class="k">const</span> futuro = <span class="k">await</span> <span class="f">crear</span>({\n' +
      '  idea:  <span class="s">\'tuya\'</span>,\n' +
      '  web:   <span class="b">true</span>,\n' +
      '  movil: <span class="b">true</span>,\n' +
      '  ia:    <span class="s">\'predictiva\'</span>,\n' +
      '});\n\n' +
      'futuro.<span class="f">lanzar</span>(); <span class="c">// ✓ listo</span>',

    'trans.cap': 'Todo empieza con un punto.',
    'trans.q': '¿LISTO PARA CONSTRUIR<br>LO QUE SIGUE?',

    'cta.title': 'CONSTRUYAMOS<br>LO QUE SIGUE.',
    'cta.sub': '¿Tienes una idea?<br>Hagámosla realidad.',
    'cta.btn': 'INICIA UN PROYECTO',
    'cta.or': 'o escríbenos a',

    'form.tag': 'Nuevo proyecto',
    'form.close': 'Cerrar formulario',
    'form.title': 'Hablemos.',
    'form.lead': 'Cuéntanos tu idea y nuestro equipo comercial se pondrá en contacto contigo.',
    'form.topic': '¿Qué necesitas?',
    'form.custom': 'A LA MEDIDA',
    'form.name': 'Nombre',
    'form.email': 'Correo',
    'form.company': 'Empresa (opcional)',
    'form.msg': 'Tu idea, en pocas líneas',
    'form.errName': 'Cuéntanos cómo te llamas.',
    'form.errEmail': 'Revisa el correo: parece incompleto.',
    'form.errMsg': 'Escribe al menos una frase sobre tu proyecto.',
    'form.send': 'ENVIAR',
    'form.sending': 'ENVIANDO…',
    'form.error': 'No pudimos enviar tu mensaje. Inténtalo de nuevo o escríbenos a',
    'form.errRate': 'Recibimos varios mensajes desde tu conexión. Espera un momento o escríbenos a',
    'form.note': 'Usamos tus datos solo para responderte.',
    'form.doneTitle': '¡Listo!',
    'form.doneText': 'Recibimos tu mensaje. Nuestro equipo comercial te escribirá pronto.',
    'form.doneFallback': '¿Algo más? Escríbenos a',
    'form.copy': 'copiar',
    'form.copied': 'copiado ✓',
    'form.closeBtn': 'Cerrar',

    'foot.tag': 'Creamos soluciones. Impulsamos el futuro.',
    'foot.top': 'Volver arriba ↑',

    'stream': ['VIB-07 ', 'TEMP   ', 'RPM    ', 'CORR   ', 'PRES   '],
  },

  en: {
    'meta.title': 'Código Creativo — Software, AI and digital experiences | Makers of SIGMA',
    'meta.desc': 'Código Creativo builds software, artificial intelligence and digital experiences. Makers of SIGMA, the industrial maintenance platform with the SIGMA AI and SIGMA TWIN modules.',

    'nav.eco': 'Ecosystem',
    'nav.lab': 'Lab',
    'nav.work': 'Work',
    'nav.cta': 'Start a project',

    'label.hero': 'Home',
    'label.phil': 'Philosophy',
    'label.eco': 'Ecosystem',
    'label.sigma': 'SIGMA',
    'label.ai': 'SIGMA AI',
    'label.lab': 'Lab',
    'label.work': 'Work',
    'label.trans': "What's next",
    'label.cta': 'Contact',

    'hero.eyebrow': 'Software · Artificial intelligence · Digital experiences',
    'hero.sub': 'We create solutions.<br>We drive the future.',
    'hero.w1': 'BUILD',
    'hero.w2': 'CREATE',
    'hero.w3': 'TRANSFORM',
    'hero.scroll': 'Scroll',

    'tag.phil': '02 — Philosophy',
    'phil.p1': "WE DON'T JUST BUILD SOFTWARE.",
    'phil.p2': 'WE BUILD <em>EXPERIENCES.</em>',
    'phil.p3': 'WE BUILD <em>SYSTEMS.</em>',
    'phil.p4': 'WE BUILD <em>THE FUTURE.</em>',

    'tag.eco': '03 — Ecosystem',
    'eco.title': 'One core.<br>Many solutions.',
    'eco.sigma': 'Maintenance platform',
    'eco.go': 'Visit ↗',
    'eco.module': 'SIGMA MODULE',
    'eco.ai': 'Predictive intelligence',
    'eco.twin': 'Digital twin',
    'eco.soft': 'Custom built',

    'tag.sigma': '04 — Product',
    'sigma.line': 'The whole plant, in a single system.',
    'sigma.go': 'Go to SIGMA',
    'sigma.m1': 'ASSETS',
    'sigma.m2': 'WORK ORDERS',
    'sigma.m3': 'MAINTENANCE',
    'sigma.m4': 'ANALYTICS',
    'sigma.readout': 'ASSETS ONLINE ▸ 15<br>OPEN WORK ORDERS ▸ 6<br>PREVENTIVE PLAN ▸ ON TRACK',
    'sigma.f1': 'Chaos',
    'sigma.f2': 'Organization',
    'sigma.f3': 'Information',
    'sigma.f4': 'Prediction',
    'sigma.alert': 'PRESS-07 · Likely failure',

    'tag.ai': '05 — SIGMA intelligence module',
    'ai.s1': 'DATA',
    'ai.s2': 'ANALYSIS',
    'ai.s3': 'PREDICTION',
    'ai.s4': 'ACTION',
    'ai.l1': 'PREDICTED FAILURE',
    'ai.days': 'DAYS',
    'ai.l2': 'ESTIMATED WINDOW',
    'ai.final': 'ACT BEFORE<br>IT FAILS.',

    'tag.lab': '06 — Lab',
    'lab.w1': 'WE EXPERIMENT.',
    'lab.w2': 'WE ENGINEER.',
    'lab.w3': 'WE CREATE.',
    'lab.mobile': 'MOBILE',
    'lab.ai': 'AI',
    'lab.auto': 'AUTOMATION',
    'lab.data': 'DATA',

    'tag.work': '07 — Work',
    'work.p1': 'End-to-end industrial maintenance platform, with built-in intelligence modules.',
    'work.module': 'SIGMA intelligence module',
    'work.goSigma': 'Go to SIGMA',
    'work.goModule': 'See it in SIGMA',
    'work.p2': 'Predicts the failure before it stops the line.',
    'work.p3': 'The plant, replicated in 3D and connected to its live data.',
    'work.t4': 'DIGITAL SOLUTIONS',
    'work.p4': 'Custom digital products: web, mobile, automation and cloud.',
    'work.mobile': 'MOBILE',
    'work.analytics': 'ANALYTICS',
    'work.realtime': 'REAL TIME',
    'work.v1a': 'PLANT · 40 ASSETS',
    'work.v1b': '1 CRITICAL',
    'work.v2a': 'PRESS-07 · VIBRATION',
    'work.v2limit': 'THRESHOLD',
    'work.v2window': '12 DAYS',
    'work.v2today': 'TODAY',
    'work.v3a': 'DIGITAL TWIN · HALL 2',
    'video.sound': 'Sound on',
    'video.mute': 'Mute',
    'work.code':
      '<span class="k">const</span> future = <span class="k">await</span> <span class="f">create</span>({\n' +
      '  idea:   <span class="s">\'yours\'</span>,\n' +
      '  web:    <span class="b">true</span>,\n' +
      '  mobile: <span class="b">true</span>,\n' +
      '  ai:     <span class="s">\'predictive\'</span>,\n' +
      '});\n\n' +
      'future.<span class="f">launch</span>(); <span class="c">// ✓ ready</span>',

    'trans.cap': 'Everything starts with a dot.',
    'trans.q': "READY TO BUILD<br>WHAT'S NEXT?",

    'cta.title': "LET'S BUILD<br>WHAT'S NEXT.",
    'cta.sub': 'Got an idea?<br>Let’s make it real.',
    'cta.btn': 'START A PROJECT',
    'cta.or': 'or write to us at',

    'form.tag': 'New project',
    'form.close': 'Close form',
    'form.title': "Let's talk.",
    'form.lead': 'Tell us about your idea and our sales team will get in touch with you.',
    'form.topic': 'What do you need?',
    'form.custom': 'CUSTOM BUILT',
    'form.name': 'Name',
    'form.email': 'Email',
    'form.company': 'Company (optional)',
    'form.msg': 'Your idea, in a few lines',
    'form.errName': 'Tell us your name.',
    'form.errEmail': 'Check the email: it looks incomplete.',
    'form.errMsg': 'Write at least one sentence about your project.',
    'form.send': 'SEND',
    'form.sending': 'SENDING…',
    'form.error': 'We could not send your message. Try again or write to us at',
    'form.errRate': 'We received several messages from your connection. Wait a moment or write to us at',
    'form.note': 'We only use your details to get back to you.',
    'form.doneTitle': 'Done!',
    'form.doneText': 'We got your message. Our sales team will write to you soon.',
    'form.doneFallback': 'Anything else? Write to us at',
    'form.copy': 'copy',
    'form.copied': 'copied ✓',
    'form.closeBtn': 'Close',

    'foot.tag': 'We create solutions. We drive the future.',
    'foot.top': 'Back to top ↑',

    'stream': ['VIB-07 ', 'TEMP   ', 'RPM    ', 'CURR   ', 'PRES   '],
  },
};

const KEY = 'cc-lang';

export function initialLang() {
  const q = new URLSearchParams(location.search).get('lang');
  if (q === 'es' || q === 'en') return q;
  try {
    const saved = localStorage.getItem(KEY);
    if (saved === 'es' || saved === 'en') return saved;
  } catch { /* almacenamiento bloqueado */ }
  return (navigator.language || 'es').toLowerCase().startsWith('es') ? 'es' : 'en';
}

export function t(lang, key) {
  return DICT[lang]?.[key] ?? DICT.es[key];
}

export function applyLang(lang) {
  const d = DICT[lang];
  document.documentElement.lang = lang;
  document.title = d['meta.title'];
  document.querySelector('meta[name="description"]')?.setAttribute('content', d['meta.desc']);

  // URL propia por idioma (la indexa Google vía hreflang): / en español, /?lang=en en inglés.
  const url = new URL(location.href);
  if (lang === 'en') url.searchParams.set('lang', 'en'); else url.searchParams.delete('lang');
  if (url.href !== location.href) history.replaceState(null, '', url);
  document.querySelector('link[rel="canonical"]')
    ?.setAttribute('href', lang === 'en' ? 'https://codigocreativo.tech/?lang=en' : 'https://codigocreativo.tech/');

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const v = d[el.dataset.i18n];
    if (v !== undefined) el.innerHTML = v;
  });
  document.querySelectorAll('[data-i18n-aria]').forEach((el) => {
    const v = d[el.dataset.i18nAria];
    if (v !== undefined) el.setAttribute('aria-label', v);
  });
  document.querySelectorAll('.lang [data-lang]').forEach((b) => {
    b.setAttribute('aria-pressed', String(b.dataset.lang === lang));
  });
  try { localStorage.setItem(KEY, lang); } catch { /* sin persistencia */ }
}
