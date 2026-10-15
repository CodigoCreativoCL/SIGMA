# Código Creativo — landing

Landing cinemática y bilingüe (ES/EN): el scroll transforma un único sistema de partículas 3D a lo largo de 9 escenas.
Sitio estático (HTML + CSS + JS) más un endpoint PHP para el formulario. Sin compilación.

## Correr en local

```bash
python -m http.server 5180 --directory CodigoCreativo
```

Abrir http://localhost:5180 (`?lang=en` para inglés). En local no hay PHP: el formulario mostrará su estado de error (es lo esperado).

## Publicar (GitHub Actions → HostChile)

Se publica sola: cada push a la rama **`landing-codigocreativo`** que toque `CodigoCreativo/` ejecuta
`.github/workflows/desplegar-landing.yml` (Web Deploy al servidor de HostChile; el dominio principal usa sus propias
credenciales `HC_LANDING_USER` / `HC_LANDING_DEPLOY_PASSWORD`, porque las del subdominio `sigma` no tienen permiso sobre él).
Detalle y secretos: `Dev/ci/LEEME.md` → «Landing codigocreativo.tech».

- La contraseña del buzón `comercial@` va **solo** en el secreto de GitHub `CC_SMTP_PASSWORD`; el pipeline la deja en
  `App_Data/contact-config.php` del servidor (IIS no sirve `App_Data`).
- En Plesk, el dominio necesita **PHP 8+** activado para el formulario.

`web.config` fuerza HTTPS, redirige `www` → `codigocreativo.tech`, bloquea `/deploy`, define tipos MIME (webp, mp4,
webmanifest), caché (HTML/CSS/JS se revalidan; `assets/` 30 días) y deja pasar las respuestas JSON de error del formulario.

Correo (SMTP SSL 465 → comercial@codigocreativo.tech):
- Si el envío falla por certificado, emitir el SSL del correo con **SSL It!** marcando
  "Asignar el certificado al dominio de correo" (o, temporalmente, `'verify_peer' => false` en la config privada;
  plantilla en `deploy/contact-config.sample.php`).
- Los errores se escriben en el log de PHP del dominio con el prefijo `[contact]`; la contraseña nunca se registra.

## Google Search Console

- La etiqueta `google-site-verification` ya está en el `<head>`: elegir el método **Etiqueta HTML** y pulsar *Verificar* después de publicar. No quitarla.
- Luego: *Sitemaps* → enviar `https://codigocreativo.tech/sitemap.xml`.
- Incluye: canonical, hreflang (es / en / x-default), datos estructurados (Organization, WebSite, SoftwareApplication SIGMA, 2 × VideoObject), `robots.txt`, sitemap con video e imagen, favicon e iconos.

## Meta (Facebook / Instagram / WhatsApp)

- Open Graph completo con imagen de 1200×630 (`assets/og/og-image.jpg`).
- Verificación de dominio: en Meta Business Suite → Seguridad de la marca → Dominios, copiar el código y pegarlo en la etiqueta
  `facebook-domain-verification` que está comentada en `index.html`.
- Para refrescar la vista previa al compartir: https://developers.facebook.com/tools/debug/

## Estructura

| Ruta | Qué hace |
|---|---|
| `src/scroll/map.js` | **Guion del scroll**: qué escena 3D se ve en cada tramo de cada sección |
| `src/three/catalog.js` | Las 16 escenas (forma, cámara, paleta) en orden de aparición |
| `src/three/shapes.js` | Generadores de formas (foco del logo, ecosistema, fábrica, indicador…) |
| `src/shaders/particles.glsl.js` | Morph entre formas, dispersión, cursor, foco de luz, grano |
| `src/animations/sections.js` | Coreografía del DOM por sección (se rehace al cambiar idioma) |
| `src/ui/contact.js` · `api/contact.php` | Cajón de contacto y envío SMTP |
| `src/ui/spots.js` | Videos de SIGMA AI y SIGMA TWIN en el scroll horizontal |
| `src/i18n.js` | Todos los textos ES/EN |
| `assets/products/` | Logos oficiales de SIGMA, SIGMA AI y SIGMA TWIN |
| `assets/video/` | Spots comprimidos a 720p (originales en `C:\Capstone_Archivo\Videos_SIGMA`) |
| `deploy/` | No se publica: plantilla SMTP manual y fuentes HTML de la imagen OG y los iconos |

SIGMA AI y SIGMA TWIN se presentan como **módulos de inteligencia de SIGMA**. Todo enlace de SIGMA lleva a https://sigma.codigocreativo.tech.
El splash 3D tapa la página hasta que cargan las fuentes y la escena WebGL: evita el salto de letras.
