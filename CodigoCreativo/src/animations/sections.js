// Coreografía del DOM por sección (GSAP + ScrollTrigger).
// Todo se crea dentro de un gsap.context para poder revertirlo y rehacerlo
// al cambiar de idioma sin recargar la página.
import { split } from '../ui/split.js';
import { ECO_SEQ, SIGMA_PHASES, AI_STEPS, stepAt } from '../scroll/map.js';

const gsap = window.gsap;
const ScrollTrigger = window.ScrollTrigger;
const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];

// Divide de nuevo un elemento que ya pudo estar dividido.
function chars(el) {
  if (el._orig !== undefined && el.querySelector('.c')) el.innerHTML = el._orig;
  el._orig = el.innerHTML;
  return split(el);
}

// Línea de tiempo atada al tramo fijo de una sección (duración normalizada a 1).
function scrub(id, extra = {}) {
  const tl = gsap.timeline({
    defaults: { ease: 'none' },
    scrollTrigger: { trigger: `#${id}`, start: 'top top', end: 'bottom bottom', scrub: true, ...extra },
  });
  tl.set({}, {}, 1);
  return tl;
}

// Entra/sale una lista de frases apiladas en los instantes dados.
function phraseSwap(tl, groups, times, dur = 0.06) {
  groups.forEach((cs, i) => {
    const [tin, tout] = times[i];
    if (tin !== null) {
      gsap.set(cs, { yPercent: 115 });
      tl.to(cs, { yPercent: 0, stagger: 0.003, duration: dur }, tin);
    }
    if (tout !== null) tl.to(cs, { yPercent: -115, stagger: 0.003, duration: dur * 0.85 }, tout);
  });
}

function setStep(items, k) {
  items.forEach((li, i) => {
    li.classList.toggle('is-active', i === k);
    li.classList.toggle('is-done', i < k);
  });
}

export function heroIntro() {
  const lines = $$('.hero__line');
  const cs = lines.flatMap((l) => chars(l));
  // En pausa: los estados iniciales se aplican ya (bajo el splash) y main.js la reproduce.
  const tl = gsap.timeline({ paused: true, delay: 0.1 });
  tl.from(cs, { yPercent: 115, duration: 1.4, ease: 'expo.out', stagger: 0.04 })
    .from('.hero__intro .eyebrow, .hero__sub, .scroll-hint', { autoAlpha: 0, y: 18, duration: 1.1, ease: 'power3.out', stagger: 0.1 }, 0.5)
    .from('.nav, .hud, .hud__bar', { autoAlpha: 0, duration: 1.2, ease: 'power2.out' }, 0.7);
  return tl;
}

export function initSections({ onEco, reduced }) {
  return gsap.context(() => {
    // 01 · Entrada
    {
      const tl = scrub('inicio');
      tl.to('.scroll-hint', { autoAlpha: 0, duration: 0.04 }, 0.02)
        .to('.hero__intro', { yPercent: -14, autoAlpha: 0, filter: reduced ? 'none' : 'blur(10px)', duration: 0.14 }, 0.1);
      const words = $$('.hero__words span').map((w) => chars(w));
      phraseSwap(tl, words, [[0.27, 0.43], [0.49, 0.65], [0.71, 0.93]], 0.07);
    }

    // 02 · Filosofía
    {
      const tl = scrub('filosofia');
      const groups = $$('.phrase').map((p) => chars(p));
      phraseSwap(tl, groups, [[null, 0.2], [0.26, 0.44], [0.5, 0.66], [0.74, null]]);
    }

    // 03 · Ecosistema
    {
      const tl = scrub('ecosistema');
      tl.fromTo('.eco__labels', { autoAlpha: 0 }, { autoAlpha: 1, duration: 0.06 }, 0)
        .fromTo('.eco__title', { autoAlpha: 0, y: 30 }, { autoAlpha: 1, y: 0, duration: 0.08 }, 0.02);
      const labels = $$('.node-label');
      let last = '';
      ScrollTrigger.create({
        trigger: '#ecosistema', start: 'top top', end: 'bottom bottom',
        onUpdate: (self) => {
          const key = ECO_SEQ[stepAt(self.progress, ECO_SEQ.map((s) => s[0]))][1];
          if (key === last) return;
          last = key;
          labels.forEach((l) => {
            const a = l.dataset.anchor;
            l.classList.toggle('is-active', key === 'all' || a === key || a === 'core');
          });
          onEco?.(key);
        },
      });
      labels.forEach((l) => l.classList.toggle('is-active', l.dataset.anchor === 'core'));
    }

    // 04 · SIGMA
    {
      const tl = scrub('sigma');
      gsap.set('.sigma__modules li', { autoAlpha: 0, x: 24 });
      tl.to('.sigma__modules li', { autoAlpha: 1, x: 0, stagger: 0.025, duration: 0.06 }, 0.24)
        .fromTo('.sigma__readout', { autoAlpha: 0, y: 14 }, { autoAlpha: 1, y: 0, duration: 0.06 }, 0.48)
        .fromTo('.sigma__alert', { autoAlpha: 0 }, { autoAlpha: 1, duration: 0.05 }, 0.76);
      const phases = $$('.sigma__phases li');
      setStep(phases, 0);
      ScrollTrigger.create({
        trigger: '#sigma', start: 'top top', end: 'bottom bottom',
        onUpdate: (self) => setStep(phases, stepAt(self.progress, SIGMA_PHASES)),
      });
    }

    // 05 · SIGMA AI
    {
      const tl = scrub('sigma-ai');
      const nums = $$('.stat__num').map((el) => ({ el, to: +el.dataset.count, v: { n: 0 } }));
      tl.fromTo('.ai__stream', { autoAlpha: 0 }, { autoAlpha: 1, duration: 0.04 }, 0.02)
        .to('.ai__stream', { autoAlpha: 0, duration: 0.05 }, 0.34)
        .fromTo('.stat--main', { autoAlpha: 0, scale: 0.92 }, { autoAlpha: 1, scale: 1, duration: 0.06 }, 0.4)
        .fromTo('.stat--side', { autoAlpha: 0, y: 20 }, { autoAlpha: 1, y: 0, duration: 0.06 }, 0.5);
      nums.forEach(({ el, to, v }, i) => {
        el.textContent = '0';
        tl.to(v, { n: to, duration: 0.14, onUpdate: () => { el.textContent = Math.round(v.n); } }, 0.42 + i * 0.08);
      });
      tl.to('.ai__prediction', { autoAlpha: 0, scale: 1.04, duration: 0.05 }, 0.66);
      const final = chars($('.ai__final'));
      gsap.set(final, { yPercent: 115 });
      tl.to(final, { yPercent: 0, stagger: 0.004, duration: 0.08 }, 0.71);

      const steps = $$('.ai__steps li');
      setStep(steps, 0);
      ScrollTrigger.create({
        trigger: '#sigma-ai', start: 'top top', end: 'bottom bottom',
        onUpdate: (self) => setStep(steps, stepAt(self.progress, AI_STEPS)),
      });
    }

    // 06 · Laboratorio
    {
      const tl = scrub('laboratorio');
      const groups = $$('.lab__words h2').map((h) => chars(h));
      phraseSwap(tl, groups, [[null, 0.2], [0.25, 0.43], [0.49, null]]);
      gsap.set('.chip', { xPercent: -50, yPercent: -50, autoAlpha: 0, scale: 0.5 });
      tl.to('.chip', { autoAlpha: 1, scale: 1, stagger: 0.03, duration: 0.08, ease: 'back.out(2)' }, 0.58);
      ScrollTrigger.create({
        trigger: '#laboratorio', start: 'top 36px', end: 'bottom 36px',
        toggleClass: { targets: document.body, className: 'is-light' },
      });
    }

    // 07 · Proyectos: scroll horizontal dentro del vertical
    {
      const track = $('.track');
      const dist = () => Math.max(0, track.scrollWidth - innerWidth);
      const h = gsap.to(track, {
        x: () => -dist(), ease: 'none',
        scrollTrigger: {
          trigger: '#proyectos', start: 'top top', end: 'bottom bottom', scrub: true, invalidateOnRefresh: true,
          onUpdate: (self) => gsap.set('.track__progress i', { scaleX: self.progress }),
        },
      });
      $$('.panel').forEach((p) => {
        gsap.fromTo(p.querySelector('.panel__visual'), { xPercent: 6 }, {
          xPercent: -6, ease: 'none',
          scrollTrigger: { trigger: p, containerAnimation: h, start: 'left right', end: 'right left', scrub: true },
        });
        gsap.from(p.querySelectorAll('.panel__num, .panel__title, .panel__line, .panel__tags'), {
          y: 40, autoAlpha: 0, stagger: 0.08, duration: 1, ease: 'power3.out',
          scrollTrigger: { trigger: p, containerAnimation: h, start: 'left 78%', toggleActions: 'play none none reverse' },
        });
      });
    }

    // 08 · Transición
    {
      const tl = scrub('transicion');
      tl.fromTo('.trans__cap', { autoAlpha: 0, y: 10 }, { autoAlpha: 1, y: 0, duration: 0.05 }, 0.03)
        .to('.trans__cap', { autoAlpha: 0, duration: 0.05 }, 0.3);
      const q = chars($('.trans__q'));
      gsap.set(q, { yPercent: 115 });
      tl.to(q, { yPercent: 0, stagger: 0.004, duration: 0.07 }, 0.88);
    }

    // 09 · CTA
    {
      const t = chars($('.cta__title'));
      gsap.timeline({ scrollTrigger: { trigger: '#contacto', start: 'top 62%', toggleActions: 'play none none reverse' } })
        .from(t, { yPercent: 115, duration: 1.2, ease: 'expo.out', stagger: 0.025 })
        .from('.cta__sub, .magnet-zone, .cta__mail', { autoAlpha: 0, y: 24, duration: 1, ease: 'power3.out', stagger: 0.12 }, 0.35);
    }
  });
}
