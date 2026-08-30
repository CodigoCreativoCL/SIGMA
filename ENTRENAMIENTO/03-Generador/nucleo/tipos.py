# -*- coding: utf-8 -*-
"""
Mapeo de tipos SQL Server -> C# -> control de pantalla.

Todo el conocimiento sobre "que es un NVARCHAR y como se lee del DataReader"
vive aqui. Si el equipo agrega un tipo nuevo, se toca SOLO este archivo.
"""

import re

_RE_TIPO = re.compile(r'^\s*([A-Za-z0-9_]+)\s*(?:\(\s*([^)]*?)\s*\))?\s*$')

# categoria -> (tipo C#, tipo C# nullable, valor por defecto C#)
_CATEGORIAS = {
    'texto':   ('string',   'string',    'string.Empty'),
    'entero':  ('int',      'int?',      '0'),
    'largo':   ('long',     'long?',     '0'),
    'decimal': ('decimal',  'decimal?',  '0'),
    'bool':    ('bool',     'bool?',     'false'),
    'fecha':   ('DateTime', 'DateTime?', 'null'),
    'guid':    ('Guid',     'Guid?',     'Guid.Empty'),
    'binario': ('byte[]',   'byte[]',    'null'),
}

# tipo SQL base -> categoria
_MAPA_SQL = {
    'CHAR': 'texto', 'NCHAR': 'texto', 'VARCHAR': 'texto', 'NVARCHAR': 'texto',
    'TEXT': 'texto', 'NTEXT': 'texto', 'XML': 'texto',
    'TINYINT': 'entero', 'SMALLINT': 'entero', 'INT': 'entero',
    'BIGINT': 'largo',
    'DECIMAL': 'decimal', 'NUMERIC': 'decimal', 'MONEY': 'decimal',
    'SMALLMONEY': 'decimal', 'FLOAT': 'decimal', 'REAL': 'decimal',
    'BIT': 'bool',
    'DATE': 'fecha', 'DATETIME': 'fecha', 'DATETIME2': 'fecha',
    'SMALLDATETIME': 'fecha', 'TIME': 'fecha', 'DATETIMEOFFSET': 'fecha',
    'UNIQUEIDENTIFIER': 'guid',
    'BINARY': 'binario', 'VARBINARY': 'binario', 'IMAGE': 'binario',
}

# categoria -> control de pantalla por defecto
_CONTROL_POR_CATEGORIA = {
    'texto': 'texto',
    'entero': 'numero',
    'largo': 'numero',
    'decimal': 'numero',
    'bool': 'check',
    'fecha': 'fecha',
    'guid': 'texto',
    'binario': 'ninguno',
}

CONTROLES_VALIDOS = ('texto', 'textarea', 'numero', 'combo', 'check',
                     'fecha', 'password', 'ninguno')


class Tipo(object):
    """Un tipo SQL ya parseado, con su equivalente en C#."""

    def __init__(self, texto):
        m = _RE_TIPO.match(str(texto or ''))
        if not m:
            raise ValueError('Tipo SQL no reconocido: "%s"' % texto)

        self.base = m.group(1).upper()
        self.args = (m.group(2) or '').strip().upper()

        if self.base not in _MAPA_SQL:
            raise ValueError(
                'Tipo SQL "%s" no soportado. Tipos validos: %s'
                % (self.base, ', '.join(sorted(_MAPA_SQL)))
            )

        self.categoria = _MAPA_SQL[self.base]
        self.csharp, self.csharp_nullable, self.defecto_csharp = _CATEGORIAS[self.categoria]

    @property
    def sql(self):
        """Texto SQL normalizado: 'NVARCHAR(200)'."""
        return '%s(%s)' % (self.base, self.args) if self.args else self.base

    @property
    def es_texto(self):
        return self.categoria == 'texto'

    @property
    def es_numero(self):
        return self.categoria in ('entero', 'largo', 'decimal')

    @property
    def es_max(self):
        return self.args == 'MAX'

    @property
    def longitud(self):
        """Longitud declarada para MaxLength del TextBox2. None si no aplica."""
        if not self.es_texto or self.es_max or not self.args:
            return None
        try:
            return int(self.args.split(',')[0])
        except ValueError:
            return None

    @property
    def decimales(self):
        """Digitos decimales para el NumberFormat del RadNumericBox2."""
        if self.categoria != 'decimal':
            return 0
        if ',' in self.args:
            try:
                return int(self.args.split(',')[1])
            except ValueError:
                return 2
        return 2 if self.base in ('MONEY', 'SMALLMONEY', 'FLOAT', 'REAL') else 0

    def control_sugerido(self, nombre_columna=''):
        """Control de pantalla por defecto segun el tipo y el nombre de la columna."""
        n = (nombre_columna or '').upper()
        if 'PASSWORD' in n or 'CONTRASENA' in n or 'CLAVE' in n:
            return 'password'
        if self.es_texto and (self.es_max or (self.longitud or 0) > 500):
            return 'textarea'
        return _CONTROL_POR_CATEGORIA[self.categoria]

    def lector(self, columna_sql, admite_null):
        """
        Expresion C# para leer la columna desde el SqlDataReader.
        Las columnas nullables de texto y numero ya vienen con ISNULL desde el SP,
        asi que solo las fechas y los binarios necesitan chequeo de DBNull.
        """
        expr = 'dr["%s"]' % columna_sql

        if self.categoria == 'texto':
            return '%s.ToString()' % expr
        if self.categoria == 'entero':
            return 'int.Parse(%s.ToString())' % expr
        if self.categoria == 'largo':
            return 'long.Parse(%s.ToString())' % expr
        if self.categoria == 'decimal':
            return 'decimal.Parse(%s.ToString())' % expr
        if self.categoria == 'bool':
            return 'bool.Parse(%s.ToString())' % expr
        if self.categoria == 'guid':
            return 'Guid.Parse(%s.ToString())' % expr
        if self.categoria == 'fecha':
            return ('%s == DBNull.Value ? (DateTime?)null : DateTime.Parse(%s.ToString())'
                    % (expr, expr))
        if self.categoria == 'binario':
            return '%s == DBNull.Value ? null : (byte[])%s' % (expr, expr)
        return '%s.ToString()' % expr

    def tipo_propiedad(self, admite_null):
        """Tipo C# de la propiedad del Model."""
        if self.categoria == 'fecha':
            return 'DateTime?'
        if self.categoria == 'binario':
            return 'byte[]'
        return self.csharp

    def __repr__(self):
        return '<Tipo %s -> %s>' % (self.sql, self.csharp)


def tipos_soportados():
    return sorted(_MAPA_SQL.keys())
