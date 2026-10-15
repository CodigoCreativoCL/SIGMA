import * as THREE from 'three';
import { createStage } from './three/stage.js';
import { Particles } from './three/particles.js';
import { CATALOG, INDEX, buildShapes } from './three/catalog.js';
import { ecoNodes, ecoLabelAnchors, FACTORY_FOCUS, GAUGE_TIP } from './three/shapes.js';
import { SCROLL_MAP, ECO_SEQ, stepAt } from './scroll/map.js';
import { initSections, heroIntro } from './animations/sections.js';
import { initCursor, initMagnetic, initChips, initStream } from './ui/interactions.js';
import { buildVisuals } from './ui/visuals.js';
import { initContact } from './ui/contact.js';
import { refitAll } from './ui/split.js';
import { initSpots } from './ui/spots.js';
import { initialLang, applyLang, t } from './i18n.js';

const gsap = window.gsap;
const ScrollTrigger = window.ScrollTrigger;
gsap.registerPlugin(ScrollTrigger);

const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
const coarse = matchMedia('(pointer: coarse)').matches;
const mobile = coarse || innerWidth < 768;
const isPortrait = () => innerWidth / innerHeight < 0.85;

// ─── Idioma ──────────────────────────────────────────────
let lang = initialLang();
applyLang(lang);
document.querySelectorAll('[data-year]').forEach((el) => { el.textContent = new Date().getFullYear(); });

// ─── Scroll suave ────────────────────────────────────────
let lenis = null;
if (!reduced && window.Lenis) {
  lenis = new window.Lenis({ lerp: 0.085, smoothWheel: true });
  lenis.on('scroll', ScrollTrigger.update);
  gsap.ticker.add((time) => lenis.raf(time * 1000));
  gsap.ticker.lagSmoothing(0);
}

document.querySelectorAll('a[href^="#"]').forEach((a) => {
  a.addEventListener('click', (e) => {
    const target = document.querySelector(a.getAttribute('href'));
    if (!target) return;
    e.preventDefault();
    if (lenis) lenis.scrollTo(target, { duration: 2.2 });
    else target.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth' });
  });
});

// ─── Proyectos: la altura de la sección = recorrido horizontal ──
const showcase = document.getElementById('proyectos');
const track = showcase.querySelector('.track');
function sizeShowcase() {
  showcase.style.height = `${Math.max(0, track.scrollWidth - innerWidth) + innerHeight}px`;
}
buildVisuals();
sizeShowcase();
ScrollTrigger.addEventListener('refreshInit', sizeShowcase);

// ─── Coreografía DOM (rehecha al cambiar de idioma) ─────────
let ctx = initSections({ reduced });
// La intro corre solo si se entra arriba; arranca cuando se retira el splash.
const withIntro = !reduced && scrollY < 10;
window.__splash?.set(0.3);

document.querySelectorAll('.lang [data-lang]').forEach((btn) => {
  btn.addEventListener('click', () => {
    const next = btn.dataset.lang;
    if (next === lang) return;
    lang = next;
    ctx.revert();
    applyLang(lang);
    ctx = initSections({ reduced });
    ScrollTrigger.refresh();
    updateHud(true);
  });
});

initCursor();
initMagnetic();
initChips();
initStream(() => lang);
initContact({ lenis, getLang: () => lang });
initSpots();

// ─── Mapa scroll → escena ────────────────────────────────
const sections = SCROLL_MAP.map((s) => ({ ...s, el: document.getElementById(s.id) }));
let keys = [];
let vh = innerHeight;

function measure() {
  vh = innerHeight;
  keys = [];
  let lastO = 1;
  for (const s of sections) {
    const top = s.el.getBoundingClientRect().top + scrollY;
    s.top = top;
    s.bottom = top + s.el.offsetHeight;
    s.stickEnd = Math.max(top + 1, s.bottom - vh);
    s.stage = s.el.querySelector('.stage');
    if (s.enter) {
      lastO = s.enter[1] ?? lastO;
      keys.push([top - vh, s.enter[0], lastO]);
    }
    for (const [u, p, o] of s.keys) {
      lastO = o ?? lastO;
      keys.push([top + u * (s.stickEnd - top), p, lastO]);
    }
  }
  keys.sort((a, b) => a[0] - b[0]);
}

const sample = (y, out) => {
  if (y <= keys[0][0]) { out[0] = keys[0][1]; out[1] = keys[0][2]; return out; }
  for (let i = 1; i < keys.length; i++) {
    const b = keys[i];
    if (y < b[0]) {
      const a = keys[i - 1];
      const f = b[0] - a[0] > 0 ? (y - a[0]) / (b[0] - a[0]) : 1;
      out[0] = a[1] + (b[1] - a[1]) * f;
      out[1] = a[2] + (b[2] - a[2]) * f;
      return out;
    }
  }
  const z = keys[keys.length - 1];
  out[0] = z[1]; out[1] = z[2];
  return out;
};

measure();
ScrollTrigger.addEventListener('refresh', measure);
// La altura de #proyectos la fija JS: Lenis debe recalcular su límite o no llega al final.
ScrollTrigger.addEventListener('refresh', () => lenis?.resize());

// ─── HUD ─────────────────────────────────────────────────
const hud = document.querySelector('.hud');
const hudNum = document.querySelector('.hud__num');
const hudName = document.querySelector('.hud__name');
const hudBar = document.querySelector('.hud__bar i');
let hudIdx = -1;

function updateHud(force = false) {
  const mid = scrollY + vh * 0.5;
  let idx = 0;
  sections.forEach((s, i) => { if (mid >= s.top) idx = i; });
  if (idx !== hudIdx || force) {
    hudIdx = idx;
    hudNum.textContent = String(idx + 1).padStart(2, '0');
    hudName.textContent = t(lang, sections[idx].el.dataset.i18nLabel);
  }
  const max = document.documentElement.scrollHeight - vh;
  hudBar.style.transform = `scaleY(${max > 0 ? Math.min(1, scrollY / max) : 0})`;
  hud.classList.toggle('is-hidden', scrollY > max - 90);
}

// ─── WebGL ───────────────────────────────────────────────
let stage = null;
try {
  stage = createStage(document.getElementById('gl'), { mobile });
} catch (err) {
  console.warn('WebGL no disponible:', err);
  document.documentElement.classList.add('no-webgl');
}

// Fuentes listas antes de mostrar nada: evita el salto de letras al cargar.
await Promise.race([
  Promise.all([document.fonts.load('800 expanded 100px Archivo'), document.fonts.ready]).catch(() => {}),
  new Promise((r) => setTimeout(r, 3500)),
]);
refitAll(); // los ajustes de tamaño se midieron con la fuente de respaldo
window.__splash?.set(0.6);

let playWorldIntro = () => {};
if (!stage) {
  gsap.ticker.add(() => updateHud());
} else {
  playWorldIntro = startWorld(stage);
  window.__splash?.set(0.85);
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))); // primer cuadro pintado
}
ScrollTrigger.refresh();

// La intro del hero se prepara (oculta) bajo el splash y se reproduce al retirarlo.
const hero = withIntro ? heroIntro() : null;
if (window.__splash) await window.__splash.hide();
if (withIntro) {
  hero.play();
  playWorldIntro();
}

function startWorld({ scene, camera, composer, finish, size, resize }) {
  const count = mobile ? 7000 : 15000;
  let portrait = isPortrait();
  let nodes = ecoNodes(portrait);
  const particles = new Particles(buildShapes(count, portrait), CATALOG, count);
  const group = new THREE.Group();
  group.add(particles.points);
  scene.add(group);
  const U = particles.uniforms;
  U.uPixelRatio.value = size.dpr;

  // Puntos 3D a los que se anclan etiquetas del DOM
  const anchors = [...document.querySelectorAll('[data-anchor]')].map((el) => ({
    el, key: el.dataset.anchor, section: sections.find((s) => s.el.contains(el)),
  }));
  let labelAnchors = {};
  const placeLabels = () => {
    labelAnchors = ecoLabelAnchors(portrait);
    for (const an of anchors) {
      const side = labelAnchors[an.key]?.side;
      an.el.classList.toggle('node-label--left', side === 'left');
      an.el.classList.toggle('node-label--above', side === 'above');
      an.el.classList.toggle('node-label--center', side === 'center');
    }
  };
  placeLabels();
  const anchorPos = (key) => {
    if (key === 'press') return [FACTORY_FOCUS[0], FACTORY_FOCUS[1] + 0.1, FACTORY_FOCUS[2]];
    return labelAnchors[key].pos;
  };

  let cams = [];
  const computeCams = () => { cams = CATALOG.map((d) => d.cam(camera.aspect)); };
  computeCams();

  const onResize = () => {
    if (!resize()) return;
    U.uPixelRatio.value = size.dpr;
    computeCams();
    if (isPortrait() !== portrait) {
      portrait = isPortrait();
      nodes = ecoNodes(portrait);
      particles.replaceShapes(buildShapes(count, portrait));
      placeLabels();
    }
  };
  addEventListener('resize', onResize);

  // Estado suavizado
  const st = { p: 0, o: 1, intro: reduced || scrollY > 10 ? 1 : 0 };
  const fx = { focus: new THREE.Vector3(), amt: 0, radius: 1.4, shift: new THREE.Vector3() };
  const fxT = { focus: new THREE.Vector3(), amt: 0, radius: 1.4, shift: new THREE.Vector3() };
  const mouse = { x: 0, y: 0, sx: 0, sy: 0, active: false };
  const target = [0, 1];
  const tmp = new THREE.Vector3();
  const ndc = new THREE.Vector3();

  // Explosión → foco del logo. Se dispara al retirarse el splash.
  const playIntro = () => {
    if (st.intro >= 1) return;
    lenis?.stop();
    gsap.to(st, { intro: 1, duration: 2.6, ease: 'power3.inOut', onComplete: () => lenis?.start() });
  };

  if (!coarse) {
    addEventListener('pointermove', (e) => {
      mouse.x = (e.clientX / innerWidth) * 2 - 1;
      mouse.y = -(e.clientY / innerHeight) * 2 + 1;
      mouse.active = true;
    }, { passive: true });
  }

  // Efectos por sección: foco de luz y desplazamiento de cámara
  function sectionFx(id, u) {
    fxT.amt = 0; fxT.radius = 1.4; fxT.shift.set(0, 0, 0);
    if (id === 'ecosistema') {
      const key = ECO_SEQ[stepAt(u, ECO_SEQ.map((s) => s[0]))][1];
      if (key === 'all') { fxT.focus.set(0, 0, 0); fxT.amt = 0.35; fxT.radius = 6; }
      else if (key !== 'core') {
        const n = nodes[key];
        fxT.focus.set(n[0], n[1], n[2]); fxT.amt = 1; fxT.radius = 1.05;
        fxT.shift.set((n[0] - nodes.core[0]) * 0.12, n[1] * 0.2, -0.7);
      }
    } else if (id === 'sigma' && u > 0.7) {
      fxT.focus.set(...FACTORY_FOCUS); fxT.amt = 1; fxT.radius = 1.05;
      fxT.shift.set(FACTORY_FOCUS[0] * 0.25, 0, -1.2);
    } else if (id === 'sigma-ai' && u > 0.36) {
      fxT.focus.set(...GAUGE_TIP); fxT.amt = u > 0.66 ? 1 : 0.6; fxT.radius = u > 0.66 ? 2.2 : 0.9;
    }
  }

  const lerp = (a, b, k) => a + (b - a) * k;
  const last = CATALOG.length - 1;

  gsap.ticker.add((time, deltaMs) => {
    const dt = Math.min(deltaMs / 1000, 0.05);
    const y = scrollY;
    updateHud();
    sample(y, target);
    // El suavizado usa el tiempo real (no el dt acotado) para no quedarse atrás con FPS bajos.
    const real = Math.min(deltaMs / 1000, 1);
    const k = 1 - Math.exp(-real * 7);
    st.p += (target[0] - st.p) * k;
    st.o += (target[1] - st.o) * k;

    // Sección activa → efectos
    const mid = y + vh * 0.5;
    let act = sections[0];
    for (const s of sections) if (mid >= s.top) act = s;
    sectionFx(act.id, Math.min(1, Math.max(0, (y - act.top) / (act.stickEnd - act.top))));
    const kf = 1 - Math.exp(-real * 3.2);
    fx.focus.lerp(fxT.focus, kf); fx.shift.lerp(fxT.shift, kf);
    fx.amt += (fxT.amt - fx.amt) * kf; fx.radius += (fxT.radius - fx.radius) * kf;

    // Par de escenas y mezcla
    let a, b, m;
    if (st.intro < 1 && st.p < 0.02) { a = INDEX.burst; b = INDEX.bulb; m = st.intro; }
    else {
      st.intro = 1;
      a = Math.min(Math.floor(st.p), last - 1); b = a + 1; m = Math.min(1, st.p - a);
    }
    particles.setPair(a, b);
    U.uMorph.value = m;
    const e = m * m * (3 - 2 * m);
    const A = CATALOG[a], B = CATALOG[b], ca = cams[a], cb = cams[b];

    camera.position.set(
      lerp(ca[0], cb[0], e) + fx.shift.x,
      lerp(ca[1], cb[1], e) + fx.shift.y,
      lerp(ca[2], cb[2], e) + fx.shift.z,
    );
    mouse.sx += (mouse.x - mouse.sx) * 0.06;
    mouse.sy += (mouse.y - mouse.sy) * 0.06;
    const still = reduced ? 0 : 1;
    group.rotation.x = lerp(A.tilt, B.tilt, e) - mouse.sy * 0.06 * still;
    group.rotation.y = lerp(A.sway, B.sway, e) * Math.sin(time * 0.22) * still + mouse.sx * 0.1 * still;
    group.updateMatrixWorld();

    U.uTime.value = time;
    U.uNoise.value = lerp(A.noise, B.noise, e) * still;
    U.uOpacity.value = st.o;
    U.uFocusPos.value.copy(fx.focus);
    U.uFocusAmt.value = fx.amt;
    U.uFocusRadius.value = fx.radius;

    // Cursor → plano z = 0
    if (mouse.active && !reduced) {
      ndc.set(mouse.sx, mouse.sy, 0.5).unproject(camera).sub(camera.position).normalize();
      const dist = -camera.position.z / ndc.z;
      U.uMouse.value.copy(camera.position).addScaledVector(ndc, dist);
      U.uMouseForce.value = lerp(A.mouse, B.mouse, e);
    }

    // Etiquetas ancladas a puntos 3D
    for (const an of anchors) {
      const s = an.section;
      if (!s || y < s.top - vh || y > s.bottom) continue;
      const stTop = s.stage.getBoundingClientRect().top;
      tmp.set(...anchorPos(an.key)).applyMatrix4(group.matrixWorld).project(camera);
      const sx = (tmp.x + 1) * 0.5 * size.w;
      const sy = (1 - tmp.y) * 0.5 * size.h - stTop;
      an.el.style.transform = `translate3d(${sx.toFixed(1)}px, ${sy.toFixed(1)}px, 0)`;
    }

    if (st.o > 0.004) {
      finish.uniforms.uTime.value = time;
      composer.render(dt);
    }
  });

  return playIntro;
}
