// Microinteracciones: cursor, botón magnético, chips que esquivan el cursor
// y el flujo de lecturas de sensores de SIGMA AI.
import { t } from '../i18n.js';

const gsap = window.gsap;

export function initCursor() {
  const dot = document.querySelector('.cursor');
  if (!dot || matchMedia('(pointer: coarse)').matches) return;
  const xTo = gsap.quickTo(dot, 'x', { duration: 0.35, ease: 'power3' });
  const yTo = gsap.quickTo(dot, 'y', { duration: 0.35, ease: 'power3' });
  addEventListener('pointermove', (e) => { xTo(e.clientX); yTo(e.clientY); dot.classList.add('is-on'); }, { passive: true });
  document.addEventListener('pointerleave', () => dot.classList.remove('is-on'));
  const hot = 'a, button, .chip__in';
  document.addEventListener('pointerover', (e) => { if (e.target.closest(hot)) dot.classList.add('is-hover'); });
  document.addEventListener('pointerout', (e) => { if (e.target.closest(hot)) dot.classList.remove('is-hover'); });
}

export function initMagnetic() {
  document.querySelectorAll('[data-magnetic]').forEach((btn) => {
    const zone = btn.closest('.magnet-zone') || btn;
    const label = btn.querySelector('.magnet__label');
    zone.addEventListener('pointermove', (e) => {
      const r = btn.getBoundingClientRect();
      const dx = e.clientX - (r.left + r.width / 2);
      const dy = e.clientY - (r.top + r.height / 2);
      const stretch = Math.min(Math.abs(dx) / r.width, 0.6);
      gsap.to(btn, { x: dx * 0.32, y: dy * 0.4, scaleX: 1 + stretch * 0.14, scaleY: 1 - stretch * 0.08, duration: 0.6, ease: 'power3.out' });
      gsap.to(label, { x: dx * 0.12, y: dy * 0.12, duration: 0.6, ease: 'power3.out' });
    });
    zone.addEventListener('pointerleave', () => {
      gsap.to([btn, label], { x: 0, y: 0, scaleX: 1, scaleY: 1, duration: 1.2, ease: 'elastic.out(1, 0.35)' });
    });
  });
}

function whenVisible(el, cb) {
  let on = false;
  new IntersectionObserver(([e]) => { on = e.isIntersecting; cb(on); }).observe(el);
  return () => on;
}

export function initChips() {
  const lab = document.getElementById('laboratorio');
  const chips = [...document.querySelectorAll('.chip__in')].map((el) => ({ el, x: 0, y: 0 }));
  if (!lab || !chips.length || matchMedia('(pointer: coarse)').matches) return;
  let mx = -1e4, my = -1e4;
  addEventListener('pointermove', (e) => { mx = e.clientX; my = e.clientY; }, { passive: true });
  const visible = whenVisible(lab, () => {});
  gsap.ticker.add(() => {
    if (!visible()) return;
    for (const c of chips) {
      const r = c.el.parentElement.getBoundingClientRect();
      const dx = r.left + r.width / 2 - mx, dy = r.top + r.height / 2 - my;
      const d = Math.hypot(dx, dy) || 1;
      const f = Math.max(0, 1 - d / 190);
      c.x += ((dx / d) * f * 70 - c.x) * 0.12;
      c.y += ((dy / d) * f * 70 - c.y) * 0.12;
      c.el.style.transform = `translate(${c.x.toFixed(2)}px, ${c.y.toFixed(2)}px) rotate(${(c.x * 0.1).toFixed(2)}deg)`;
    }
  });
}

export function initStream(getLang) {
  const el = document.querySelector('.ai__stream');
  if (!el) return;
  let timer = 0;
  const tick = () => {
    const [vib, temp, rpm, curr, pres] = t(getLang(), 'stream');
    const r = Math.random;
    el.textContent = [
      `${vib} ${(4.1 + r() * 1.4).toFixed(2)} mm/s`,
      `${temp} ${(68 + r() * 6).toFixed(1)} °C`,
      `${rpm} ${Math.round(1455 + r() * 45)}`,
      `${curr} ${(12 + r() * 3).toFixed(1)} A`,
      `${pres} ${(5.8 + r() * 0.5).toFixed(2)} bar`,
    ].join('\n');
  };
  tick();
  whenVisible(el.closest('.sec'), (on) => {
    clearInterval(timer);
    if (on) timer = setInterval(tick, 140);
  });
}
