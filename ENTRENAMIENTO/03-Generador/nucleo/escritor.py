# -*- coding: utf-8 -*-
"""
Escritura de archivos respetando la regla de codificacion del proyecto:
UTF-8 CON BOM y terminadores CRLF (ver PATRON_MVC.md seccion 8).
"""

import io
import os


class Escritor(object):
    def __init__(self, raiz, forzar=False):
        self.raiz = os.path.abspath(raiz)
        self.forzar = forzar
        self.escritos = []
        self.omitidos = []

    def escribir(self, ruta_relativa, contenido):
        destino = os.path.join(self.raiz, ruta_relativa.replace('/', os.sep))

        if os.path.exists(destino) and not self.forzar:
            self.omitidos.append(ruta_relativa)
            return False

        carpeta = os.path.dirname(destino)
        if carpeta and not os.path.isdir(carpeta):
            os.makedirs(carpeta)

        texto = contenido.replace('\r\n', '\n').replace('\r', '\n')
        if not texto.endswith('\n'):
            texto += '\n'

        # utf-8-sig = UTF-8 con BOM. newline='\r\n' convierte cada \n en CRLF.
        with io.open(destino, 'w', encoding='utf-8-sig', newline='\r\n') as f:
            f.write(texto)

        self.escritos.append(ruta_relativa)
        return True

    @property
    def total(self):
        return len(self.escritos)
