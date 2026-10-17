# -*- coding: utf-8 -*-
"""Lee las definiciones de CargaMasivaController.cs: modulo -> hojas -> columnas (clave, titulo, obligatoria, ayuda, ejemplo)."""
import re
import os
CS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'Web', 'Intranet', 'App_Code', 'MVC', 'SitioBase', 'Controller', 'CargaMasivaController.cs')
STR = r'"((?:[^"\\]|\\.)*)"'


def leer():
    src = open(CS, encoding='utf-8-sig').read()
    mods = sorted(((m.start(), m.group(1)) for m in re.finditer(r'clave = "(INVENTARIO|ACTIVOS|MANTENIMIENTO)",\s*nombre', src)))
    out = {}
    pat = re.compile(r'new Hoja \{ clave = "(\w+)", titulo = "([^"]+)"|\bC\("(\w+)", "([^"]*)", (true|false), ' + STR + r', ' + STR, re.S)
    for i, (ini, clave) in enumerate(mods):
        fin = mods[i + 1][0] if i + 1 < len(mods) else len(src)
        bloque = src[ini:fin]
        hojas, cur = [], None
        for m in pat.finditer(bloque):
            if m.group(1):
                cur = {'clave': m.group(1), 'titulo': m.group(2), 'desc': '', 'cols': []}
                hojas.append(cur)
            elif cur is not None:
                cur['cols'].append({'clave': m.group(3), 'titulo': m.group(4), 'obl': m.group(5) == 'true', 'ayuda': m.group(6), 'ejemplo': m.group(7)})
        for h in hojas:
            m = re.search(r'clave = "%s", titulo = "[^"]+",[^}]*?descripcion = %s' % (h['clave'], STR), bloque, re.S)
            h['desc'] = m.group(1) if m else ''
        out[clave] = hojas
    return out


if __name__ == '__main__':
    import sys
    sys.stdout.reconfigure(encoding='utf-8')
    for k, hs in leer().items():
        print('==', k)
        for h in hs:
            print('  ', h['titulo'], '|', ' · '.join(('*' if c['obl'] else '') + c['titulo'] for c in h['cols']))
