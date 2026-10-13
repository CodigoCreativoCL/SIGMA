"""Imprime el siguiente numero libre de migracion en BD/, mirando master y TODAS las ramas remotas
(evita que dos personas creen el mismo numero). Antes: git fetch.
    python -I Dev/siguiente_migracion.py
"""
import re, subprocess
def sh(*a):
    return subprocess.run(a, capture_output=True, text=True, encoding='utf-8', errors='replace').stdout
mx, donde = 0, ''
for rama in sh('git', 'for-each-ref', '--format=%(refname:short)', 'refs/remotes/origin', 'refs/heads').split():
    if rama.endswith('/HEAD'):
        continue
    for ruta in sh('git', 'ls-tree', '--name-only', rama, 'BD/').splitlines():
        m = re.match(r'^BD/(\d+)[A-Za-z]?_.*\.sql$', ruta)
        if m and int(m.group(1)) > mx:
            mx, donde = int(m.group(1)), rama
print('Ultimo numero usado: %d (en %s). Siguiente libre: %d' % (mx, donde, mx + 1))
