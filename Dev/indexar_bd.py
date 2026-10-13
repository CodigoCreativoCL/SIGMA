"""Indexa BD/ por CONTEXTO (cero tokens): genera Boveda/Base de datos/<Contexto>.md con
numero, archivo y descripcion de cada migracion, mas un Indice. Lo llama actualizar_boveda.py.
    python -I Dev/indexar_bd.py
"""
import os, re
R = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
BD = os.path.join(R, 'BD')
OUT = os.path.join(R, 'Boveda', 'Base de datos')

# (contexto, palabras clave sobre los tokens del nombre). Gana la primera coincidencia.
REGLAS = [
    ('App móvil y API', ['APP', 'API', 'FLUTTER']),
    ('Seguridad, menús y permisos', ['MENU', 'MENUS', 'PERMISO', 'PERMISOS', 'PAGINAS', 'PAGINA', 'ROOT', 'PERFIL', 'USUARIO', 'USUARIOS', 'MANTENEDOR', 'ICONOS', 'SESION', 'TOKEN', 'LOGIN', 'CLAVE', 'PASSWORD', 'SEGURIDAD', 'PERFILES', 'SIDEBAR']),
    ('Suscripción y comercial', ['SUSCRIPCION', 'COSTOS', 'COMERCIAL', 'MODULO', 'MODULOS']),
    ('Alertas e inteligencia (SIGMA AI)', ['ALERTA', 'ALERTAS', 'PREDICCION', 'VIDA', 'ML', 'AI', 'MACHINE', 'FAILURE', 'RUL', 'ANOMALIA']),
    ('Planificación y programación', ['PLAN', 'PLANES', 'PLANIFICACION', 'PROGRAMACION', 'PROGRAMACIONES', 'PAUTA', 'PAUTAS360', 'CALENDARIO', 'CHOQUES', 'CENTRO', 'HITO', 'OCURRENCIAS', 'REPROGRAMAR', 'JOB', 'NOCTURNO', 'VENTANA', 'PROGRAMA']),
    ('Órdenes y operación', ['OT', 'ORDEN', 'ORDENES', 'OPERACION', 'TAREA', 'TAREAS', 'CHECKLIST', 'PROCEDIMIENTO', 'PROCEDIMIENTOS', 'HALLAZGO', 'HALLAZGOS', 'AVISO', 'AVISOS', 'FALLA', 'FALLAS', 'GALERIA', 'EVIDENCIA', 'EVIDENCIAS', 'CUMPLIMIENTO', 'EJECUCION', 'RECURSOS']),
    ('Inventario y bodegas', ['REPUESTO', 'REPUESTOS', 'INVENTARIO', 'BODEGA', 'BODEGAS', 'MOVIMIENTO', 'MOVIMIENTOS', 'SALDO', 'SALDOS', 'COMPATIBILIDAD', 'STOCK', 'EXISTENCIA', 'EXISTENCIAS', 'RACK', 'MAPA', 'UBICACION', 'REUBICACION', 'ETIQUETA', 'ETIQUETAS', 'ESCANEO', 'SALIDA', 'DESGLOSE']),
    ('Activos y componentes', ['ACTIVO', 'ACTIVOS', 'COMPONENTE', 'COMPONENTES', 'MEDIDOR', 'MEDIDORES', 'MEDICION', 'MEDICIONES', 'ATRIBUTO', 'MODELO', 'MODELOS', 'LECTURA', 'LECTURAS', 'POSICION', 'POSICIONES', 'TIPO', 'TIPOS', 'VARIABLE', 'VARIABLES', 'DETALLE', 'FICHA', 'FABRICANTE']),
    ('Terceros y clientes', ['CLIENTE', 'CLIENTES', 'PROVEEDOR', 'PROVEEDORES', 'CONTACTO', 'TERCERO', 'TERCEROS']),
    ('Soporte, notificaciones y ayuda', ['SOPORTE', 'CAMPANA', 'CAMPANAS', 'NOTIFICACION', 'NOTIFICACIONES', 'BITACORA', 'VOZ', 'AYUDA', 'PROBLEMA', 'PROBLEMAS', 'INICIO']),
    ('Organización, catálogos y cargas', ['PLANTA', 'PLANTAS', 'GRUPO', 'GRUPOS', 'AREA', 'AREAS', 'CATALOGO', 'CATALOGOS', 'ESPECIALIDAD', 'ESPECIALIDADES', 'LOGO', 'CARGA', 'SANEAMIENTO', 'REPARACION', 'FUNDACIONES', 'FUNDACION', 'REFINAMIENTOS', 'DESCUBRIMIENTO', 'UNIDAD', 'UNIDADES', 'SIGMA', 'CENTROS', 'COSTO', 'ARCHIVOS', 'ARCHIVO', 'FK', 'DIFERIDAS', 'PAIS', 'ZONA', 'HORARIA', 'HORA', 'EQUIPOS', 'AJUSTES', 'IDENTIFICADOR', 'CODIGO', 'PREFIJO', 'MAESTRO']),
]
OTROS = 'Otros y transversales'

def contexto(nombre):
    base = re.sub(r'^\d+[A-Za-z]?_', '', nombre[:-4]).upper()
    base = re.sub(r'^SPRINT\d+_', '', base)
    tokens = base.split('_')
    for ctx, claves in REGLAS:
        if any(t in claves for t in tokens):
            return ctx
    return OTROS

def descripcion(path):
    try:
        t = open(path, 'rb').read(3000).decode('utf-8-sig', 'ignore')
    except Exception:
        return ''
    m = re.search(r'DESCRIPTION:\s*(.+)', t)
    if m:
        d = m.group(1).strip()
    else:
        m = re.search(r'^--\s+(?!=|-)([^\r\n]{12,})', t, re.M)
        d = m.group(1).strip() if m else ''
    d = re.sub(r'\s+', ' ', d).replace('|', '/')
    return d[:140]

def clave(n):
    m = re.match(r'^(\d+)', n)
    return (int(m.group(1)) if m else 10**9, n)

def main():
    os.makedirs(OUT, exist_ok=True)
    grupos = {}
    for n in sorted(os.listdir(BD), key=clave):
        if re.match(r'^\d+[A-Za-z]?_.*\.sql$', n):
            grupos.setdefault(contexto(n), []).append(n)
    for viejo in os.listdir(OUT):
        if viejo.endswith('.md'):
            os.remove(os.path.join(OUT, viejo))
    filas = []
    for ctx in [c for c, _ in REGLAS] + [OTROS]:
        fs = grupos.get(ctx, [])
        if not fs:
            continue
        slug = ctx
        lineas = ['# BD — %s' % ctx, '',
                  '%d migraciones (generado por `Dev/indexar_bd.py`; no editar). Ruta: `BD/<archivo>`. Ver [[Indice de base de datos]].' % len(fs), '',
                  '| Archivo | Qué hace |', '|---|---|']
        for f in fs:
            lineas.append('| `%s` | %s |' % (f, descripcion(os.path.join(BD, f))))
        open(os.path.join(OUT, slug + '.md'), 'w', encoding='utf-8', newline='\n').write('\n'.join(lineas) + '\n')
        filas.append((ctx, len(fs), fs[0], fs[-1]))
    idx = ['# Índice de base de datos (por contexto)', '',
           'Las migraciones viven en `BD/` con número correlativo (= orden de ejecución). Para saber **qué migración toca un tema**, abrir la nota de su contexto; no listar `BD/`.', '',
           '| Contexto | Migraciones | Primera | Última |', '|---|---|---|---|']
    for ctx, n, a, b in filas:
        idx.append('| [[%s]] | %d | `%s` | `%s` |' % (ctx, n, a, b))
    idx += ['', '**Otros directorios de BD/**: `Semillas/` (datos de demo y pruebas), `Respaldos/` (copias y propuestas), `Carga masiva/`, `Reinicio/`.',
            '', 'Reglas: SP-first, idempotentes (`CREATE OR ALTER`), una migración nueva = siguiente número libre. Ver [[Patrones y convenciones]] y [[Base de datos y entornos]].']
    open(os.path.join(OUT, 'Indice de base de datos.md'), 'w', encoding='utf-8', newline='\n').write('\n'.join(idx) + '\n')
    for ctx, n, a, b in filas:
        print('%4d  %s' % (n, ctx))

if __name__ == '__main__':
    main()
