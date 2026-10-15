// Cajón de contacto. Envía por POST (JSON) a api/contact.php, que despacha el correo
// por SMTP del hosting a comercial@codigocreativo.tech. Nunca abre el cliente de correo.
import { t } from '../i18n.js';

const gsap = window.gsap;
const ENDPOINT = 'api/contact.php';
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

export function initContact({ lenis, getLang }) {
  const root = document.getElementById('contact');
  if (!root) return;
  const panel = root.querySelector('.contact__panel');
  const scrim = root.querySelector('.contact__scrim');
  const form = root.querySelector('.contact__form');
  const done = root.querySelector('.contact__done');
  const isSheet = () => matchMedia('(max-width: 640px)').matches;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  let isOpen = false;
  let lastFocus = null;
  let tried = false;

  const offscreen = () => (isSheet() ? { xPercent: 0, yPercent: 100 } : { xPercent: 100, yPercent: 0 });

  function open() {
    if (isOpen) return;
    isOpen = true;
    lastFocus = document.activeElement;
    root.hidden = false;
    form.hidden = false;
    done.hidden = true;
    done.classList.remove('is-in');
    lenis?.stop();
    document.documentElement.style.overflow = 'hidden';

    const d = reduced ? 0 : 1;
    gsap.killTweensOf([panel, scrim]);
    gsap.fromTo(panel, offscreen(), { xPercent: 0, yPercent: 0, duration: 0.85 * d, ease: 'expo.out' });
    gsap.fromTo(scrim, { opacity: 0 }, { opacity: 1, duration: 0.5 * d });
    gsap.fromTo(panel, { '--glow': 0 }, { '--glow': 1, duration: 1.2 * d, ease: 'power3.inOut', delay: 0.15 * d });
    gsap.from(form.querySelectorAll('.contact__title, .contact__lead, .contact__topics, .field, .contact__send, .contact__note'), {
      y: 26, autoAlpha: 0, stagger: 0.05, duration: 0.7 * d, ease: 'power3.out', delay: 0.15 * d, clearProps: 'all',
    });

    document.addEventListener('keydown', onKey);
    // En móvil no se enfoca un campo para no levantar el teclado de golpe.
    setTimeout(() => {
      (isSheet() ? root.querySelector('.contact__close') : form.querySelector('#cf-name'))?.focus({ preventScroll: true });
    }, 380 * d);
  }

  function close() {
    if (!isOpen) return;
    isOpen = false;
    document.removeEventListener('keydown', onKey);
    const d = reduced ? 0 : 1;
    gsap.to(scrim, { opacity: 0, duration: 0.4 * d });
    gsap.to(panel, {
      ...offscreen(), duration: 0.55 * d, ease: 'power3.in',
      onComplete: () => {
        root.hidden = true;
        document.documentElement.style.overflow = '';
        lenis?.resize();
        lenis?.start();
        lastFocus?.focus?.({ preventScroll: true });
      },
    });
  }

  function onKey(e) {
    if (e.key === 'Escape') { e.preventDefault(); close(); return; }
    if (e.key !== 'Tab') return;
    const f = [...panel.querySelectorAll('a[href], button, input, textarea')]
      .filter((el) => !el.disabled && el.offsetParent !== null);
    if (!f.length) return;
    const first = f[0], last = f[f.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  }

  // ── Validación
  const fields = {
    name: (v) => v.trim().length > 1,
    email: (v) => EMAIL_RE.test(v.trim()),
    message: (v) => v.trim().length >= 10,
  };
  function check(name) {
    const input = form.elements[name];
    const ok = fields[name](input.value);
    input.closest('.field').classList.toggle('is-invalid', !ok);
    input.setAttribute('aria-invalid', String(!ok));
    return ok;
  }
  Object.keys(fields).forEach((name) => {
    form.elements[name].addEventListener('input', () => { if (tried) check(name); });
    form.elements[name].addEventListener('blur', () => { if (tried) check(name); });
  });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    tried = true;
    const results = Object.keys(fields).map(check);
    if (results.includes(false)) {
      const bad = form.querySelector('.is-invalid input, .is-invalid textarea');
      bad?.focus();
      gsap.fromTo(form.querySelector('.contact__send'), { x: -8 }, { x: 0, duration: 0.6, ease: 'elastic.out(1, 0.3)' });
      return;
    }

    if (sending) return;
    const data = {
      name: form.elements.name.value.trim(),
      email: form.elements.email.value.trim(),
      company: form.elements.company.value.trim(),
      topics: [...form.querySelectorAll('input[name="topic"]:checked')].map((i) => i.value),
      message: form.elements.message.value.trim(),
      website: form.elements.website.value,
      lang: getLang(),
    };

    setSending(true);
    showError(null);
    let status = 0;
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 20000);
      const res = await fetch(ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(data),
        signal: ctrl.signal,
      });
      clearTimeout(timer);
      status = res.status;
      const json = await res.json().catch(() => ({}));
      if (res.ok && json.ok) { setSending(false); showDone(); return; }
      if (status === 422 && Array.isArray(json.fields)) json.fields.forEach((f) => form.elements[f] && check(f));
    } catch { /* red caída o tiempo agotado */ }
    setSending(false);
    showError(status === 429 ? 'form.errRate' : 'form.error');
  });

  const sendBtn = form.querySelector('.contact__send');
  const errorBox = form.querySelector('.contact__error');
  let sending = false;

  function setSending(on) {
    sending = on;
    sendBtn.disabled = on;
    sendBtn.classList.toggle('is-busy', on);
    form.setAttribute('aria-busy', String(on));
  }

  function showError(key) {
    errorBox.hidden = !key;
    if (!key) return;
    errorBox.querySelector('span').textContent = t(getLang(), key);
    gsap.fromTo(errorBox, { y: 8, autoAlpha: 0 }, { y: 0, autoAlpha: 1, duration: 0.5, ease: 'power3.out' });
  }

  function showDone() {
    form.hidden = true;
    done.hidden = false;
    panel.scrollTop = 0;
    requestAnimationFrame(() => done.classList.add('is-in'));
    gsap.from(done.children, { y: 20, autoAlpha: 0, stagger: 0.07, duration: 0.7, ease: 'power3.out', clearProps: 'all' });
    form.reset();
    tried = false;
    form.querySelectorAll('.is-invalid').forEach((f) => f.classList.remove('is-invalid'));
    done.querySelector('.contact__again')?.focus({ preventScroll: true });
  }

  // Copiar el correo
  root.querySelector('[data-copy]')?.addEventListener('click', async (e) => {
    const btn = e.currentTarget;
    const em = btn.querySelector('em');
    try {
      await navigator.clipboard.writeText(btn.dataset.copy);
      em.textContent = t(getLang(), 'form.copied');
      setTimeout(() => { em.textContent = t(getLang(), 'form.copy'); }, 2200);
    } catch { /* sin portapapeles: el correo queda visible */ }
  });

  root.querySelectorAll('[data-contact-close]').forEach((el) => el.addEventListener('click', close));
  document.querySelectorAll('[data-contact-open]').forEach((el) => {
    el.addEventListener('click', (e) => { e.preventDefault(); open(); });
  });
}
