# -*- coding: utf-8 -*-
u"""Paso 5. Comprueba que despues del reinicio todavia se puede trabajar.

Vaciar la base es facil; lo dificil es no dejarla inservible. Este paso entra de
verdad al sitio y mira las cuatro cosas que el reinicio podria haber roto:

  1. que la cuenta pueda iniciar sesion,
  2. que no rebote a Renovar.aspx. Es el riesgo concreto del reinicio: la base
     queda sin ninguna suscripcion vigente, y si la compuerta atajara a quien
     tiene que contratarla, nadie podria arreglarlo desde adentro,
  3. que la barra lateral se dibuje, con Utilidades y sus dos hijos,
  4. que las pantallas por donde arranca el flujo abran sin error con la base
     vacia.

Se ejecuta contra el sitio LOCAL -IIS Express sobre Dev/applicationhost.config,
que ya esta configurado en localhost:8080- y no contra el ambiente productivo.
La base es la misma, asi que la comprobacion vale igual, y no hay por que
escribir credenciales en produccion para responder esto.

    python 5_comprobar.py root@codigocreativo.cl <clave>

La clave se pasa por linea de comandos y no se guarda ni se imprime.
Termina con codigo 0 si todo paso, y 1 si algo fallo.
"""
import sys, re, os
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
import urllib.request, urllib.parse, http.cookiejar

BASE = os.environ.get('SIGMA_URL', 'http://localhost:8080')
if len(sys.argv) < 3:
    print(__doc__)
    sys.exit(2)
USUARIO, CLAVE = sys.argv[1], sys.argv[2]

tarro = http.cookiejar.CookieJar()
abrir = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(tarro))
abrir.addheaders = [('User-Agent', 'comprobacion-sigma')]
fallos = []


def get(url):
    with abrir.open(BASE + url, timeout=180) as r:
        return r.geturl(), r.read().decode('utf-8', 'replace')


def campo(html, nombre):
    m = re.search(r'name="%s"[^>]*value="([^"]*)"' % nombre, html)
    return m.group(1) if m else ''


# --------------------------------------------------------------- 1 y 2. entrar
try:
    _, html = get('/Login.aspx')
except Exception as e:
    print('No responde %s — ¿esta levantado IIS Express?\n  %s' % (BASE, e))
    sys.exit(1)

datos = urllib.parse.urlencode({
    '__VIEWSTATE': campo(html, '__VIEWSTATE'),
    '__VIEWSTATEGENERATOR': campo(html, '__VIEWSTATEGENERATOR'),
    '__EVENTVALIDATION': campo(html, '__EVENTVALIDATION'),
    'txtCorreo': USUARIO,
    'txtPassword': CLAVE,
    'btnLogin': 'Iniciar sesión',
}).encode('utf-8')

with abrir.open(BASE + '/Login.aspx', datos, timeout=180) as r:
    destino, pagina = r.geturl(), r.read().decode('utf-8', 'replace')

print('1. Inicio de sesion')
if 'Login.aspx' in destino:
    msg = re.search(r'(?:alert-danger|sg-login-error)[^>]*>\s*([^<]{3,160})', pagina)
    print('   NO entro. %s' % (msg.group(1).strip() if msg else '(sin mensaje visible)'))
    sys.exit(1)
if 'Renovar.aspx' in destino:
    print('   Entro, pero la compuerta de suscripcion lo mando a Renovar.aspx.')
    sys.exit(1)
print('   entra y no rebota a Renovar.aspx  ->  %s' % destino)

# ------------------------------------------------------------------ 3. el menu
print('\n2. Barra lateral')
lat = re.search(r'<ul class="metismenu" id="side-menu">(.*?)</ul>\s*</div>', pagina, re.S)
cuerpo = lat.group(1) if lat else pagina
secciones = []
for e in re.findall(r'<span[^>]*>([^<]{2,40})</span>', cuerpo):
    e = ' '.join(e.split())
    if e and not e.isdigit() and e not in secciones:
        secciones.append(e)
print('   %d entradas: %s' % (len(secciones), ' · '.join(secciones)))
if len(secciones) < 10:
    fallos.append('la barra lateral trae muy pocas entradas')
for esperado in ('Utilidades', 'Escanear', 'Etiquetas'):
    ok = esperado in cuerpo
    print('   %-12s %s' % (esperado, 'aparece' if ok else 'NO APARECE'))
    if not ok:
        fallos.append('no aparece %s en el menu' % esperado)

# ------------------------------------------------- 4. las pantallas del arranque
print('\n3. Pantallas por donde empieza el flujo')
for nombre, ruta in (('Clientes', '/View/Comercial/Clientes/Clientes.aspx'),
                     ('Planes comerciales', '/View/Comercial/Suscripciones/Planes.aspx'),
                     ('Suscripciones', '/View/Comercial/Suscripciones/Suscripciones.aspx'),
                     ('Centro de repuestos', '/View/Inventario/Repuestos/RepuestoCentro.aspx'),
                     ('Etiquetas', '/View/Comun/Impresion/CentroEtiquetas.aspx'),
                     ('Escanear', '/View/Comun/Impresion/Escanear.aspx')):
    try:
        dest, h = get(ruta)
    except Exception as e:
        print('   %-22s ERROR %s' % (nombre, e)); fallos.append(nombre); continue
    if 'Login.aspx' in dest:
        print('   %-22s rebota al login' % nombre); fallos.append(nombre)
    elif re.search(r'Server Error|Runtime Error|Excepci.n no controlada', h):
        print('   %-22s ERROR de servidor' % nombre); fallos.append(nombre)
    else:
        print('   %-22s abre' % nombre)

print()
if fallos:
    print('FALLO: %s' % '; '.join(fallos))
    sys.exit(1)
print('Todo en orden: se puede empezar el flujo.')
