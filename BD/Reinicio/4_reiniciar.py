# -*- coding: utf-8 -*-
u"""Paso 4. Aplica el plan: deja la base en blanco para rehacer el flujo.

Por que es seguro
-----------------
Todo ocurre en una transaccion con XACT_ABORT: o queda todo aplicado o no queda
nada a medias. Antes de confirmar se reactivan las claves foraneas CON
comprobacion, asi que si el plan dejo una fila huerfana la base lo rechaza y la
transaccion se deshace sola. No hay que confiar en que la lista de tablas estaba
completa: la base lo verifica. Despues se cuenta lo que quedo en pie y, si
faltan los menus, los permisos o alguna de las cuentas a conservar, tambien
aborta.

Las claves se sueltan durante el borrado unicamente para no tener que adivinar
el orden correcto entre cientos de relaciones, y se dejan como estaban.

La confirmacion se hace con cx.commit() y no con un COMMIT en SQL: pyodbc con
autocommit=False ya abre su propia transaccion, y un BEGIN/COMMIT propio la
anida, de modo que el COMMIT cierra solo la de adentro y al cerrar la conexion
la de afuera se deshace. Paso en la primera corrida: el script dijo
"confirmado" y la base habia quedado intacta.

Antes de correrlo
-----------------
    python 1_esquema.py
    python 2_plan.py
    python 3_respaldo.py
"""
import io, re, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _comun

_comun.consola()

# Sin respaldo esto es irreversible, asi que no se ejecuta sin el. Es una
# comprobacion tonta a proposito -que exista la carpeta-: cualquier cosa mas
# lista se puede enganiar sola, y lo que se quiere es que nadie llegue aqui sin
# haber corrido el paso 3.
import glob
if not glob.glob(_comun.ruta('respaldo_*')):
    print('No hay ningun respaldo en %s.' % _comun.DATOS)
    print('Corra primero:  python 3_respaldo.py')
    sys.exit(1)

P = json.load(io.open(_comun.ruta('plan.json'), encoding='utf-8'))
LOGINS = ', '.join("'%s'" % l for l in P['conservar_login'])

cx = _comun.conectar(autocommit=False)
cu = cx.cursor()

cu.execute("SELECT name FROM sys.tables")
EXISTEN = {r[0] for r in cu.fetchall()}

try:
    cu.execute("SET XACT_ABORT ON")

    # La lista de quienes se van se materializa ANTES de borrarlos: despues la
    # consulta que los identifica ya no encontraria a nadie.
    cu.execute("SELECT usu_id, usu_login INTO #fuera FROM [dbo].[Usuario] "
               "WHERE usu_login NOT IN (%s)" % LOGINS)
    cu.execute("SELECT COUNT(*) FROM #fuera")
    print('personas que se van: %d' % cu.fetchone()[0])

    cu.execute("EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL'")
    print('claves foraneas desactivadas')

    # --- 1. tablas que son puro dato del cliente
    borradas = {}
    for t in P['vaciar_completo']:
        if t not in EXISTEN:
            print('  (ya no existe) %s' % t); continue
        cu.execute("DELETE FROM [dbo].[%s]" % t)
        if cu.rowcount > 0:
            borradas[t] = cu.rowcount

    # --- 2. filas del cliente dentro de tablas del sistema
    for t, w in P['vaciar_parcial']:
        if t not in EXISTEN:
            print('  (ya no existe) %s' % t); continue
        w2 = re.sub(r'SELECT usu_id FROM \[dbo\]\.\[Usuario\] WHERE usu_login NOT IN \([^)]*\)',
                    'SELECT usu_id FROM #fuera', w)
        cu.execute("DELETE FROM [dbo].[%s] WHERE %s" % (t, w2))
        if cu.rowcount > 0:
            borradas[t] = borradas.get(t, 0) + cu.rowcount

    # --- 3. autoria de quien ya no esta: se anula, la fila se queda
    for t, c in P.get('anular_autoria', []):
        if t not in EXISTEN:
            continue
        cu.execute("UPDATE [dbo].[%s] SET [%s] = NULL "
                   "WHERE [%s] IN (SELECT usu_id FROM #fuera)" % (t, c, c))
        if cu.rowcount:
            print('  autoria anulada en %s.%s: %d filas' % (t, c, cu.rowcount))

    print('\n%d tablas con filas borradas, %s filas' %
          (len(borradas), format(sum(borradas.values()), ',d').replace(',', '.')))

    # --- 4. identidades a cero donde la tabla quedo vacia: el flujo empieza en 1
    reseteadas = 0
    for t in P['vaciar_completo']:
        if t not in EXISTEN:
            continue
        cu.execute("SELECT COUNT(*) FROM [dbo].[%s]" % t)
        if cu.fetchone()[0]:
            continue
        cu.execute("SELECT COUNT(*) FROM sys.identity_columns "
                   "WHERE object_id = OBJECT_ID('dbo.%s')" % t)
        if cu.fetchone()[0]:
            cu.execute("DBCC CHECKIDENT ('dbo.%s', RESEED, 0) WITH NO_INFOMSGS" % t)
            reseteadas += 1
    print('identidades reiniciadas: %d tablas' % reseteadas)

    # --- 5. las claves vuelven COMPROBANDO: aqui salta cualquier huerfano
    cu.execute("EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL'")
    print('claves foraneas reactivadas y verificadas')

    # --- 6. lo que tiene que haber quedado en pie
    control = {}
    for t, etiqueta in (('Menus', 'menus'), ('Perfiles', 'perfiles'), ('Permiso', 'permisos'),
                        ('Perfil_Permiso', 'permisos por perfil'), ('Catalogo', 'catalogos'),
                        ('Usuario', 'cuentas'), ('Usuario_Perfil', 'perfiles de cuenta'),
                        ('Cliente', 'clientes')):
        if t in EXISTEN:
            cu.execute("SELECT COUNT(*) FROM [dbo].[%s]" % t)
            control[etiqueta] = cu.fetchone()[0]

    cu.execute("SELECT usu_login FROM [dbo].[Usuario] ORDER BY usu_id")
    quedan = [r[0] for r in cu.fetchall()]

    print('\nqueda en pie:')
    for k, v in control.items():
        print('   %-22s %d' % (k, v))
    print('   cuentas: %s' % ', '.join(quedan))

    if sorted(quedan) != sorted(P['conservar_login']):
        raise RuntimeError('las cuentas que quedan no son las esperadas: %s' % quedan)
    if control.get('clientes', -1) != 0:
        raise RuntimeError('quedaron clientes sin borrar')
    if control.get('menus', 0) < 100 or control.get('permisos', 0) < 50:
        raise RuntimeError('se perdieron menus o permisos: el sistema quedaria inusable')

    cx.commit()
    print('\nconfirmado. La base quedo lista para rehacer el flujo desde cero.')

except Exception as e:
    try:
        cx.rollback()
    except Exception:
        pass
    print('\nNO se aplico nada: la transaccion se deshizo por\n  %s' % e)
    raise
finally:
    cx.close()
