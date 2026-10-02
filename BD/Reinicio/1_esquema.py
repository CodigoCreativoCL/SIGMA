# -*- coding: utf-8 -*-
u"""Paso 1. Lee el esquema de la base: tablas, columnas y claves foraneas.

El plan de borrado no se escribe a mano contra una lista de tablas que envejece:
se deduce del esquema real cada vez. Asi, cuando el modelo crezca -una tabla
nueva de un sprint que viene-, el reinicio la incluye sola si es dato del
cliente, en vez de dejarla con datos viejos sin que nadie se entere.

Deja _datos/esquema.json.
"""
import io, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _comun

_comun.consola()
cx = _comun.conectar()
cu = cx.cursor()

cu.execute("""
SELECT t.name, c.name, ty.name, c.max_length, c.is_nullable, c.is_identity,
       ISNULL(ic.es_pk, 0)
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
OUTER APPLY (SELECT 1 AS es_pk FROM sys.index_columns k
             JOIN sys.indexes i ON i.object_id = k.object_id AND i.index_id = k.index_id
             WHERE k.object_id = t.object_id AND k.column_id = c.column_id
               AND i.is_primary_key = 1) ic
ORDER BY t.name, c.column_id
""")
tablas = {}
for t, col, tipo, largo, nulo, ident, pk in cu.fetchall():
    tablas.setdefault(t, []).append(
        {'col': col, 'tipo': tipo, 'nulo': 'NULL' if nulo else 'NOT NULL',
         'identity': bool(ident), 'pk': bool(pk)})

cu.execute("""
SELECT fk.name, tp.name, cp.name, tr.name, cr.name
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN sys.tables tp ON tp.object_id = fkc.parent_object_id
JOIN sys.columns cp ON cp.object_id = tp.object_id AND cp.column_id = fkc.parent_column_id
JOIN sys.tables tr ON tr.object_id = fkc.referenced_object_id
JOIN sys.columns cr ON cr.object_id = tr.object_id AND cr.column_id = fkc.referenced_column_id
""")
fks = [{'fk': n, 'tabla': tp, 'columna': cp, 'ref_tabla': tr, 'ref_columna': cr}
       for n, tp, cp, tr, cr in cu.fetchall()]
cx.close()

json.dump({'tablas': tablas, 'fks': fks},
          io.open(_comun.ruta('esquema.json'), 'w', encoding='utf-8'),
          ensure_ascii=False, indent=1)
print('%d tablas · %d columnas · %d claves foraneas'
      % (len(tablas), sum(len(v) for v in tablas.values()), len(fks)))
print('esquema en', _comun.ruta('esquema.json'))
