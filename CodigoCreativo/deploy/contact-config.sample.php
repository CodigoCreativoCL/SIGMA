<?php
/**
 * Plantilla de configuración SMTP del formulario de contacto.
 *
 * Lo normal es NO usar esta plantilla: el pipeline (desplegar-landing.yml) genera
 * App_Data/contact-config.php desde el secreto CC_SMTP_PASSWORD. Si prefieres hacerlo a mano:
 *
 * 1. Copia este archivo al servidor como  private/contact-config.php
 *    (la carpeta "private" está al mismo nivel que "httpdocs", fuera de lo público;
 *     en Plesk Windows: C:\Inetpub\vhosts\codigocreativo.tech\private\).
 * 2. Escribe la contraseña del buzón comercial@codigocreativo.tech en 'pass'.
 * 3. No subas el archivo con la contraseña al repositorio.
 *
 * Alternativa sin archivo: define la variable de entorno CC_SMTP_PASS en Plesk.
 */
return [
    'pass' => 'ESCRIBE_AQUI_LA_CONTRASEÑA',

    // Opcionales (estos son los valores por defecto):
    // 'host'        => 'codigocreativo.tech',
    // 'port'        => 465,
    // 'user'        => 'comercial@codigocreativo.tech',
    // 'to'          => 'comercial@codigocreativo.tech',
    // 'verify_peer' => true,   // pásalo a false solo si el certificado SSL del correo aún no está emitido
];
