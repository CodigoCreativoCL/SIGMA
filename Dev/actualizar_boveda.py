"""Regenera Boveda/Estado automatico.md (cero tokens): modulos, web services, ultima migracion SQL,
ramas y ultimos commits. Se corre al cerrar un bloque y antes de hacer push:
    python -I Dev/actualizar_boveda.py
"""
import os, re, subprocess, datetime
R = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
def sh(*a):
    try:
        return subprocess.run(a, cwd=R, capture_output=True, text=True, encoding='utf-8', errors='replace').stdout.strip()
    except Exception:
        return ''
view = os.path.join(R, 'Web', 'Intranet', 'View')
mods = []
for m in sorted(os.listdir(view)):
    p = os.path.join(view, m)
    if os.path.isdir(p):
        mods.append('- **%s**: %s' % (m, ', '.join(sorted(d for d in os.listdir(p) if os.path.isdir(os.path.join(p, d)))) or '-'))
ws = sorted(f[:-3] for f in os.listdir(os.path.join(R, 'Web', 'Intranet', 'App_Code', 'WebService')) if f.endswith('.cs'))
sql = sorted(f for f in os.listdir(os.path.join(R, 'BD')) if re.match(r'^\d+_.*\.sql$', f))
ult = sql[-6:]
out = ['# Estado automático (generado, no editar a mano)', '',
       'Generado: %s · rama: `%s` · HEAD `%s`' % (datetime.datetime.now().strftime('%Y-%m-%d %H:%M'), sh('git', 'branch', '--show-current'), sh('git', 'rev-parse', '--short', 'HEAD')),
       '', '## Últimas migraciones SQL (BD/)', ''] + ['- `%s`' % s for s in ult] + \
      ['', '## Últimos commits', ''] + ['- ' + l for l in sh('git', 'log', '-12', '--format=%h %ad %an: %s', '--date=short').splitlines()] + \
      ['', '## Módulos y pantallas', ''] + mods + ['', '## Web services', '', ', '.join(ws), '']
open(os.path.join(R, 'Boveda', 'Estado automatico.md'), 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print('Boveda/Estado automatico.md actualizado (%d migraciones, %d ws)' % (len(sql), len(ws)))
