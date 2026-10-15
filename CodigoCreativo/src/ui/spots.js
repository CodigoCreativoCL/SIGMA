// Spots de SIGMA AI y SIGMA TWIN dentro del scroll horizontal de Proyectos.
// Se cargan al acercarse, se reproducen en silencio mientras su tarjeta está a la vista
// y se pausan al salir. El botón activa la voz (y silencia el otro spot).
export function initSpots() {
  const spots = [...document.querySelectorAll('[data-spot]')].map((video) => ({
    video,
    btn: video.parentElement.querySelector('[data-spot-sound]'),
  }));
  if (!spots.length) return;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const load = (v) => { if (!v.src) { v.src = v.dataset.src; v.load(); } };

  // Precarga: una pantalla antes de entrar (el desplazamiento es horizontal).
  const near = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) { load(e.target); near.unobserve(e.target); } });
  }, { rootMargin: '50% 100% 50% 100%' });

  const view = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      const v = e.target;
      if (e.intersectionRatio >= 0.45) {
        load(v);
        if (!reduced || !v.muted) v.play().catch(() => {});
      } else {
        v.pause();
      }
    });
  }, { threshold: [0, 0.45, 0.8] });

  spots.forEach(({ video, btn }) => {
    near.observe(video);
    view.observe(video);
    btn?.addEventListener('click', () => {
      const turnOn = video.muted;
      spots.forEach((s) => { s.video.muted = true; s.btn?.setAttribute('aria-pressed', 'false'); });
      if (turnOn) {
        load(video);
        video.muted = false;
        if (video.currentTime > 0.5) video.currentTime = 0;
        video.play().catch(() => {});
        btn.setAttribute('aria-pressed', 'true');
      }
    });
  });
}
