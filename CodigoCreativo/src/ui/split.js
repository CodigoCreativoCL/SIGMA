// Divide un elemento en palabras (.w, con máscara) y caracteres (.c) conservando
// <em>, <br> y demás etiquetas internas. Lectores de pantalla leen el aria-label.
export function split(el) {
  const label = el.textContent.replace(/\s+/g, ' ').trim();
  const chars = [];

  const build = (src, dest) => {
    for (const node of [...src.childNodes]) {
      if (node.nodeType === Node.TEXT_NODE) {
        for (const part of node.textContent.split(/(\s+)/)) {
          if (!part) continue;
          if (/^\s+$/.test(part)) { dest.appendChild(document.createTextNode(' ')); continue; }
          const word = document.createElement('span');
          word.className = 'w';
          for (const ch of part) {
            const c = document.createElement('span');
            c.className = 'c';
            c.textContent = ch;
            word.appendChild(c);
            chars.push(c);
          }
          dest.appendChild(word);
        }
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        if (node.tagName === 'BR') { dest.appendChild(document.createElement('br')); continue; }
        const clone = node.cloneNode(false);
        dest.appendChild(clone);
        build(node, clone);
      }
    }
  };

  const frag = document.createDocumentFragment();
  build(el, frag);
  el.textContent = '';
  el.appendChild(frag);
  el.setAttribute('aria-label', label);
  for (const child of el.children) child.setAttribute('aria-hidden', 'true');
  fit(el);
  return chars;
}

// Una palabra más ancha que su contenedor se partiría dentro de su máscara y las letras
// ocultas asomarían sobre la frase siguiente. Se achica la fuente hasta que la palabra
// más larga quepa (pasa en móvil con «EXPERIENCIAS.», «EXPERIMENTAMOS.», etc.).
const fitted = new Set();

// Ancho disponible real: un contenedor centrado (grid/flex) crece con su contenido,
// así que también se acota por el padre y por el viewport menos los márgenes laterales.
function availableWidth(el) {
  const parent = el.parentElement;
  const ps = getComputedStyle(parent);
  const parentInner = parent.clientWidth - parseFloat(ps.paddingLeft) - parseFloat(ps.paddingRight);
  const gutter = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--gutter')) || 16;
  const viewport = document.documentElement.clientWidth - gutter * 2;
  return Math.min(el.clientWidth || Infinity, parentInner || Infinity, viewport);
}

function fitWords(el) {
  el.style.fontSize = '';
  const avail = availableWidth(el);
  if (!avail || avail === Infinity) return;
  let widest = 0;
  for (const w of el.querySelectorAll('.w')) widest = Math.max(widest, w.scrollWidth);
  const size = parseFloat(getComputedStyle(el).fontSize);
  // .w lleva .03em de relleno lateral para la máscara: no cuenta como desborde.
  if (widest > avail + size * 0.07) {
    el.style.fontSize = `${Math.floor(size * (avail / widest) * 0.97)}px`;
  }
}

function fit(el) {
  fitted.add(el);
  fitWords(el);
}

/** Recalcula todos los ajustes (al cargar las fuentes definitivas y al redimensionar). */
export function refitAll() {
  fitted.forEach((el) => (el.isConnected ? fitWords(el) : fitted.delete(el)));
}

let resizeTimer = 0;
addEventListener('resize', () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(refitAll, 150);
});
