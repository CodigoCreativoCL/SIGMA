# -*- coding: utf-8 -*-
u"""Conexion y rutas compartidas por los cuatro pasos del reinicio.

La contrasena se lee del Web.config de la API y no se escribe en ningun lado:
ni en un archivo de configuracion de esta carpeta, ni en la salida por pantalla.
Cambiarla en el Web.config basta para que esto siga funcionando.

Todo lo que estos scripts generan -el esquema, el plan, el respaldo- va a
_datos/, que esta fuera del control de versiones: son datos del cliente.
"""
import io, os, re, sys

BASE = os.path.dirname(os.path.abspath(__file__))
DATOS = os.path.join(BASE, '_datos')
os.makedirs(DATOS, exist_ok=True)

# BD/Reinicio -> SIGMA
SIGMA = os.path.dirname(os.path.dirname(BASE))
WEBCONFIG = os.path.join(SIGMA, 'Solucion', 'SIGMA', 'API', 'Web.config')


def consola():
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass


def cadena_conexion():
    """La cadena de la API, con el driver ODBC que usa pyodbc."""
    cfg = io.open(WEBCONFIG, encoding='utf-8-sig', errors='replace').read()
    # SIGMA la guarda como appSetting (value="..."), no en <connectionStrings>.
    m = re.search(r'(?:value|connectionString)\s*=\s*"([^"]*Data Source[^"]*)"', cfg, re.I)
    if not m:
        raise RuntimeError('no se encontro la cadena de conexion en %s' % WEBCONFIG)
    c = m.group(1)

    def val(*nombres):
        for n in nombres:
            x = re.search(r'(?:^|;)\s*%s\s*=\s*([^;]*)' % n, c, re.I)
            if x:
                return x.group(1).strip()
        return ''

    srv = val('Data Source', 'Server')
    bd = val('Initial Catalog', 'Database')
    usr = val('User ID', 'Uid')
    pwd = val('Password', 'Pwd')
    if not (srv and bd and usr and pwd):
        raise RuntimeError('la cadena de conexion esta incompleta')
    return ('DRIVER={ODBC Driver 17 for SQL Server};SERVER=%s;DATABASE=%s;UID=%s;PWD=%s'
            % (srv, bd, usr, pwd))


def conectar(autocommit=True, timeout=180):
    import pyodbc
    return pyodbc.connect(cadena_conexion(), autocommit=autocommit, timeout=timeout)


def ruta(*partes):
    return os.path.join(DATOS, *partes)
