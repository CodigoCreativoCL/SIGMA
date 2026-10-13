# -*- coding: utf-8 -*-
u"""Deja un archivo en UTF-8 con BOM y CRLF, como el resto del sitio."""
import io, sys, time
for ruta in sys.argv[1:]:
    txt = io.open(ruta, encoding='utf-8-sig').read()
    for intento in range(6):
        try:
            io.open(ruta, 'w', encoding='utf-8-sig', newline='\r\n').write(txt)
            print('ok ' + ruta)
            break
        except (IOError, OSError) as ex:
            print('reintento: %s' % ex); time.sleep(1)
