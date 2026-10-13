"""Aplica un .sql con sqlcmd (-f 65001) usando la conexion de Solucion/SIGMA/API/Web.config.
Uso:  python -I Dev/sql_aplicar.py BD/NNN_archivo.sql
No imprime ni guarda la clave. Equivalente en PowerShell: Dev/sql.ps1."""
import io, os, re, subprocess, sys
R = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
cfg = io.open(os.path.join(R, 'Solucion', 'SIGMA', 'API', 'Web.config'), encoding='utf-8-sig', errors='replace').read()
m = re.search(r'(?:Data Source|Server)=(?:tcp:)?([^;]*);Initial Catalog=([^;]*);(?:Persist Security Info=[^;]*;)?User I[dD]=([^;]*);Password=([^;"]*)', cfg)
s, d, u, p = m.groups()
s = s.replace(',1433', '')
SQLCMD = os.environ.get('SQLCMD', r'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe')
r = subprocess.run([SQLCMD, '-S', s, '-d', d, '-U', u, '-P', p, '-f', '65001', '-b', '-W', '-s', '|', '-i', sys.argv[1]] + sys.argv[2:], capture_output=True)
sys.stdout.buffer.write(r.stdout + r.stderr + b'\nEXIT %d\n' % r.returncode)
