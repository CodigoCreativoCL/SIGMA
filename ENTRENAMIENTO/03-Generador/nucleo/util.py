# -*- coding: utf-8 -*-
"""
Utilidades de texto y renderizado de plantillas.

El motor de plantillas es deliberadamente simple: reemplaza tokens {{NOMBRE}}.
No se usan f-strings ni str.format() sobre las plantillas porque el codigo
generado (C#, ASPX, SQL) esta lleno de llaves { } y se romperia.
"""

import re
import unicodedata

_SEPARADORES = re.compile(r'[^A-Za-z0-9]+')
_TOKEN = re.compile(r'\{\{(\w+)\}\}')


def sin_acentos(texto):
    """QUITA acentos y enies. Se usa para nombres de clase/archivo."""
    if texto is None:
        return ''
    norm = unicodedata.normalize('NFKD', str(texto))
    return ''.join(c for c in norm if not unicodedata.combining(c))


def partes(texto):
    """Parte un identificador en palabras: 'FECHA_VENCIMIENTO' -> ['FECHA','VENCIMIENTO']."""
    return [p for p in _SEPARADORES.split(sin_acentos(texto or '')) if p]


def pascal(texto):
    """'FECHA_VENCIMIENTO' -> 'FechaVencimiento'."""
    return ''.join(p[:1].upper() + p[1:].lower() for p in partes(texto))


def camel(texto):
    """'FECHA_VENCIMIENTO' -> 'fechaVencimiento'."""
    p = pascal(texto)
    return p[:1].lower() + p[1:]


def titulo(texto):
    """'FECHA_VENCIMIENTO' -> 'Fecha Vencimiento'. Etiqueta por defecto de un campo."""
    return ' '.join(p[:1].upper() + p[1:].lower() for p in partes(texto))


def identificador(texto):
    """Convierte una ruta/segmento en un identificador valido de clase C#."""
    limpio = _SEPARADORES.sub('_', sin_acentos(texto or ''))
    limpio = limpio.strip('_')
    if limpio and limpio[0].isdigit():
        limpio = '_' + limpio
    return limpio


def render(plantilla, variables):
    """Reemplaza {{TOKEN}} por variables[TOKEN]. Falla si falta un token."""
    def _sub(m):
        clave = m.group(1)
        if clave not in variables:
            raise KeyError("Token {{%s}} sin valor en la plantilla." % clave)
        valor = variables[clave]
        return '' if valor is None else str(valor)
    return _TOKEN.sub(_sub, plantilla)


def indentar(texto, espacios):
    """Indenta cada linea no vacia."""
    pad = ' ' * espacios
    return '\n'.join((pad + l) if l.strip() else l for l in texto.split('\n'))


def alinear(filas, separador=' ', relleno=' '):
    """
    Alinea una lista de filas (cada fila = lista de celdas) en columnas.
    La ultima celda de cada fila no se rellena.
    Se usa para que los CREATE TABLE y las listas de parametros queden prolijos.
    """
    if not filas:
        return []
    ancho_max = max(len(f) for f in filas)
    normal = [list(f) + [''] * (ancho_max - len(f)) for f in filas]
    anchos = []
    for i in range(ancho_max):
        anchos.append(max(len(str(f[i])) for f in normal))

    salida = []
    for fila in normal:
        piezas = []
        for i, celda in enumerate(fila):
            celda = str(celda)
            if i == ancho_max - 1:
                piezas.append(celda)
            else:
                piezas.append(celda + relleno * (anchos[i] - len(celda)))
        salida.append(separador.join(piezas).rstrip())
    return salida


def lista_con_comas(lineas, indentacion=0, coma_al_final=False):
    """
    Devuelve las lineas separadas por coma.
    coma_al_final=False -> la ultima linea no lleva coma (listas de parametros SQL).
    """
    pad = ' ' * indentacion
    salida = []
    for i, l in enumerate(lineas):
        ultima = (i == len(lineas) - 1)
        sufijo = '' if (ultima and not coma_al_final) else ','
        salida.append(pad + l + sufijo)
    return '\n'.join(salida)


def genero_de(singular, explicito=None):
    """'m' o 'f'. Se usa para 'creado' vs 'creada'."""
    if explicito in ('m', 'f'):
        return explicito
    s = sin_acentos(singular or '').lower()
    return 'f' if s.endswith('a') or s.endswith('ion') or s.endswith('dad') else 'm'


def concordar(palabra_masculina, genero):
    """'creado' + 'f' -> 'creada'."""
    if genero == 'f' and palabra_masculina.endswith('o'):
        return palabra_masculina[:-1] + 'a'
    return palabra_masculina


def articulo_de(genero):
    return 'LA' if genero == 'f' else 'EL'
