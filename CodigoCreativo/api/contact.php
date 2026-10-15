<?php
/**
 * Formulario de contacto de codigocreativo.tech → comercial@codigocreativo.tech
 *
 * Envía por SMTP autenticado (SSL, puerto 465) al servidor de correo del hosting.
 * La contraseña NUNCA va en este archivo ni en el repositorio. Se lee, en este orden, de:
 *   1. La variable de entorno CC_SMTP_PASS, o
 *   2. App_Data/contact-config.php del sitio: lo genera el pipeline de GitHub Actions desde el
 *      secreto CC_SMTP_PASSWORD (IIS nunca sirve App_Data), o
 *   3. <raíz del dominio>/private/contact-config.php (fuera de httpdocs), si se dejó a mano.
 *      Plantilla manual: deploy/contact-config.sample.php
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store');

const MAX_BODY = 20000;       // bytes del JSON entrante
const RATE_LIMIT = 5;         // envíos por IP…
const RATE_WINDOW = 3600;     // …por hora

function reply(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function config(): array
{
    $cfg = [
        'host'        => 'codigocreativo.tech',
        'port'        => 465,
        'user'        => 'comercial@codigocreativo.tech',
        'pass'        => getenv('CC_SMTP_PASS') ?: '',
        'to'          => 'comercial@codigocreativo.tech',
        'from_name'   => 'Web Código Creativo',
        'verify_peer' => true,
        'origins'     => ['codigocreativo.tech', 'www.codigocreativo.tech'],
    ];
    foreach ([dirname(__DIR__) . '/App_Data/contact-config.php', dirname(__DIR__, 2) . '/private/contact-config.php'] as $file) {
        if (!is_readable($file)) continue;
        $extra = require $file;
        if (is_array($extra)) $cfg = array_merge($cfg, array_filter($extra, static fn($v) => $v !== '' && $v !== null));
        break;
    }
    return $cfg;
}

// ── Solicitud ────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    reply(405, ['ok' => false, 'error' => 'method']);
}

$cfg = config();

// Solo desde el propio sitio
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($origin !== '') {
    $host = parse_url($origin, PHP_URL_HOST) ?: '';
    if (!in_array($host, $cfg['origins'], true)) reply(403, ['ok' => false, 'error' => 'origin']);
}

$raw = file_get_contents('php://input', false, null, 0, MAX_BODY + 1);
if ($raw === false || strlen($raw) > MAX_BODY) reply(413, ['ok' => false, 'error' => 'size']);
$in = json_decode($raw, true);
if (!is_array($in)) reply(400, ['ok' => false, 'error' => 'json']);

// Trampa para bots: el campo oculto debe venir vacío. Se responde "ok" para no dar pistas.
if (!empty($in['website'])) reply(200, ['ok' => true]);

$clean = static fn($v, int $max) => mb_substr(trim(preg_replace('/[\r\n\t]+/', ' ', (string)$v)), 0, $max);
$name    = $clean($in['name'] ?? '', 120);
$email   = $clean($in['email'] ?? '', 160);
$company = $clean($in['company'] ?? '', 160);
$lang    = ($in['lang'] ?? 'es') === 'en' ? 'en' : 'es';
$message = mb_substr(trim(str_replace("\r", '', (string)($in['message'] ?? ''))), 0, 5000);
$allowedTopics = ['SIGMA', 'Web', 'Móvil', 'IA', 'Automatización', 'Software a la medida'];
$topics  = array_values(array_intersect(array_map('strval', (array)($in['topics'] ?? [])), $allowedTopics));

$errors = [];
if (mb_strlen($name) < 2) $errors[] = 'name';
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) $errors[] = 'email';
if (mb_strlen($message) < 10) $errors[] = 'message';
if ($errors) reply(422, ['ok' => false, 'error' => 'validation', 'fields' => $errors]);

// Límite por IP (archivo en el temporal del sistema)
$ip = $_SERVER['REMOTE_ADDR'] ?? '0';
$bucket = sys_get_temp_dir() . '/cc-contact-' . hash('sha256', $ip) . '.json';
$now = time();
$hits = is_readable($bucket) ? (json_decode((string)file_get_contents($bucket), true) ?: []) : [];
$hits = array_values(array_filter($hits, static fn($t) => $t > $now - RATE_WINDOW));
if (count($hits) >= RATE_LIMIT) reply(429, ['ok' => false, 'error' => 'rate']);

if ($cfg['pass'] === '') {
    error_log('[contact] Falta la contraseña SMTP (secreto CC_SMTP_PASSWORD del pipeline → App_Data/contact-config.php).');
    reply(500, ['ok' => false, 'error' => 'config']);
}

// ── Mensaje ──────────────────────────────────────────────
$subjectBase = $lang === 'en' ? 'New project' : 'Nuevo proyecto';
$subject = $subjectBase . ' · ' . $name . ($company !== '' ? ' · ' . $company : '');
$lines = [
    'Nombre:  ' . $name,
    'Correo:  ' . $email,
    $company !== '' ? 'Empresa: ' . $company : null,
    $topics ? 'Interés: ' . implode(', ', $topics) : null,
    'Idioma:  ' . strtoupper($lang),
    '',
    'Mensaje:',
    $message,
    '',
    '—',
    'Enviado desde el formulario de https://codigocreativo.tech',
];
$body = implode("\r\n", array_filter($lines, static fn($l) => $l !== null));

$enc = static fn(string $s) => '=?UTF-8?B?' . base64_encode($s) . '?=';
$domain = substr(strrchr($cfg['user'], '@'), 1);
$headers = [
    'Date: ' . date(DATE_RFC2822),
    'From: ' . $enc($cfg['from_name']) . ' <' . $cfg['user'] . '>',
    'To: <' . $cfg['to'] . '>',
    'Reply-To: ' . $enc($name) . ' <' . $email . '>',
    'Subject: ' . $enc($subject),
    'Message-ID: <' . bin2hex(random_bytes(12)) . '@' . $domain . '>',
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    'X-Mailer: codigocreativo.tech',
];
$data = implode("\r\n", $headers) . "\r\n\r\n" . rtrim(chunk_split(base64_encode($body), 76, "\r\n"));

// ── SMTP (SSL 465, AUTH LOGIN) ───────────────────────────
function smtp_send(array $cfg, string $data): void
{
    $ctx = stream_context_create(['ssl' => [
        'verify_peer'      => (bool)$cfg['verify_peer'],
        'verify_peer_name' => (bool)$cfg['verify_peer'],
        'peer_name'        => $cfg['host'],
    ]]);
    $fp = @stream_socket_client('ssl://' . $cfg['host'] . ':' . $cfg['port'], $errno, $errstr, 15, STREAM_CLIENT_CONNECT, $ctx);
    if (!$fp) throw new RuntimeException("conexión: $errstr ($errno)");
    stream_set_timeout($fp, 15);

    $read = static function () use ($fp): string {
        $out = '';
        while (($line = fgets($fp, 515)) !== false) {
            $out .= $line;
            if (strlen($line) < 4 || $line[3] === ' ') break;
        }
        return $out;
    };
    $cmd = static function (?string $c, array $ok) use ($fp, $read): string {
        if ($c !== null) fwrite($fp, $c . "\r\n");
        $r = $read();
        if (!in_array((int)substr($r, 0, 3), $ok, true)) {
            $shown = ($c !== null && str_starts_with($c, 'AUTH')) ? 'AUTH' : ($c ?? 'saludo');
            throw new RuntimeException("SMTP [$shown] → " . trim($r));
        }
        return $r;
    };

    try {
        $cmd(null, [220]);
        $cmd('EHLO ' . (parse_url('https://' . ($_SERVER['HTTP_HOST'] ?? 'codigocreativo.tech'), PHP_URL_HOST) ?: 'localhost'), [250]);
        $cmd('AUTH LOGIN', [334]);
        $cmd(base64_encode($cfg['user']), [334]);
        fwrite($fp, base64_encode($cfg['pass']) . "\r\n");
        $r = $read();
        if ((int)substr($r, 0, 3) !== 235) throw new RuntimeException('SMTP [AUTH] → ' . trim($r));
        $cmd('MAIL FROM:<' . $cfg['user'] . '>', [250]);
        $cmd('RCPT TO:<' . $cfg['to'] . '>', [250, 251]);
        $cmd('DATA', [354]);
        $cmd($data . "\r\n.", [250]);
        $cmd('QUIT', [221]);
    } finally {
        fclose($fp);
    }
}

try {
    smtp_send($cfg, $data);
} catch (Throwable $e) {
    error_log('[contact] ' . $e->getMessage());
    reply(502, ['ok' => false, 'error' => 'smtp']);
}

$hits[] = $now;
@file_put_contents($bucket, json_encode($hits), LOCK_EX);
reply(200, ['ok' => true]);
