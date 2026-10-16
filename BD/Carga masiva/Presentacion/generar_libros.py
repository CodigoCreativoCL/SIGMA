# -*- coding: utf-8 -*-
"""Genera los tres libros de la presentación a partir de las plantillas oficiales de SIGMA (con sus ayudas)."""
import datetime as dt
import os
import sys
import warnings

import openpyxl
from openpyxl.worksheet.datavalidation import DataValidation

warnings.filterwarnings('ignore')
AQUI = os.path.dirname(os.path.abspath(__file__))
SALIDA = sys.argv[1] if len(sys.argv) > 1 else AQUI
D = dt.date

PLANTA = 'Planta Renca'


def abrir(nombre):
    return openpyxl.load_workbook(os.path.join(AQUI, nombre + '.xlsx'))


def llenar(wb, hoja, filas, fechas=()):
    """Reemplaza la fila de ejemplo por los datos. `fechas`: encabezados cuya celda es una fecha."""
    ws = wb[hoja]
    enc = [c.value for c in ws[1]]
    # borrar todo bajo el encabezado
    for r in range(2, ws.max_row + 1):
        for c in range(1, ws.max_column + 1):
            ws.cell(r, c).value = None
    for i, fila in enumerate(filas, start=2):
        for j, v in enumerate(fila, start=1):
            if v is None or v == '':
                continue
            c = ws.cell(i, j, v)
            if isinstance(v, (dt.date, dt.datetime)):
                c.number_format = 'dd-mm-yyyy'
            elif isinstance(v, str):
                c.number_format = '@'
    return len(filas)


def lista(ws, col_titulo, formula=None, valores=None):
    """Vuelve a poner una lista desplegable (openpyxl no conserva las de la plantilla)."""
    enc = [c.value for c in ws[1]]
    if col_titulo not in enc:
        return
    j = enc.index(col_titulo) + 1
    letra = openpyxl.utils.get_column_letter(j)
    dv = DataValidation(type='list', formula1=formula if formula else '"' + ','.join(valores) + '"', allow_blank=True, showErrorMessage=False)
    dv.add(f'{letra}2:{letra}600')
    ws.add_data_validation(dv)


def desplegables(wb, mapa):
    for hoja, cols in mapa.items():
        ws = wb[hoja]
        for titulo, spec in cols.items():
            if isinstance(spec, tuple):
                ayuda, col = spec
                n = wb[ayuda].max_row
                lista(ws, titulo, formula=f"'{ayuda}'!${col}$2:${col}${max(n, 2)}")
            else:
                lista(ws, titulo, valores=spec)


SN = ['SI', 'NO']

# ====================================================================== INVENTARIO
def inventario():
    wb = abrir('INVENTARIO')
    llenar(wb, 'BODEGAS', [
        ['BOD-L2', 'Bodega Línea 2', PLANTA, 'Repuestos mecánicos y eléctricos de la Línea 2', 'FEFO'],
        ['BOD-LUB', 'Bodega de lubricantes y refrigerantes', PLANTA, 'Aceites, grasas y refrigerante, con control de lote y vencimiento', 'FEFO'],
    ])
    llenar(wb, 'RACKS', [
        ['BOD-L2', 'Pasillo', 'A', 1, None, None, 800],
        ['BOD-L2', 'Pasillo', 'A', 2, None, None, 800],
        ['BOD-L2', 'Pasillo', 'A', 3, None, None, 800],
        ['BOD-L2', 'Pasillo', 'A', 4, None, None, 800],
        ['BOD-L2', 'Pasillo', 'B', 1, None, None, 1200],
        ['BOD-L2', 'Pasillo', 'B', 2, None, None, 1200],
        ['BOD-LUB', 'Pasillo', 'A', 1, None, None, 1500],
        ['BOD-LUB', 'Pasillo', 'A', 2, None, None, 1500],
    ])
    # codigo, nombre, unidad, fabricante, modelo, lote, consumible, reparable, costo, vida_h, vida_d, vida_c, descripcion, habilitado, tipo, metodo, largo, ancho, alto, peso
    R = [
        ('L2-ROD-6312', 'Rodamiento rígido de bolas 6312-C3', 'UNIDAD', 'SKF', '6312-C3', 'NO', 'NO', 'NO', 38500, 20000, 'MEC-RODAMIENTO', 13, 13, 3.5, 2.8),
        ('L2-ROD-6212', 'Rodamiento rígido de bolas 6212-C3', 'UNIDAD', 'SKF', '6212-C3', 'NO', 'NO', 'NO', 22900, 20000, 'MEC-RODAMIENTO', 11, 11, 2.2, 1.6),
        ('L2-ROD-22216', 'Rodamiento oscilante de rodillos 22216 E', 'UNIDAD', 'FAG', '22216-E1', 'NO', 'NO', 'NO', 71000, 16000, 'MEC-RODAMIENTO', 14, 14, 3.3, 4.4),
        ('L2-COR-SPB2000', 'Correa trapezoidal SPB-2000', 'UNIDAD', 'Optibelt', 'SPB 2000', 'NO', 'SI', 'NO', 14500, 4000, 'MEC-CORREA', 30, 5, 2, 0.4),
        ('L2-COR-SPB2360', 'Correa trapezoidal SPB-2360', 'UNIDAD', 'Gates', 'SPB 2360', 'NO', 'SI', 'NO', 16900, 4000, 'MEC-CORREA', 32, 5, 2, 0.5),
        ('L2-POL-SPB180', 'Polea de dos canales SPB Ø180', 'UNIDAD', 'Martin', 'SPB2-180', 'NO', 'NO', 'NO', 48200, None, 'MEC-POLEA', 20, 20, 8, 3.1),
        ('L2-CAD-12B', 'Cadena de rodillos 12B-1 (por metro)', 'METRO', 'Tsubaki', '12B-1', 'NO', 'SI', 'NO', 18900, 8000, 'MEC-CADENA', 100, 2, 2, 0.9),
        ('L2-SEL-MEC35', 'Sello mecánico Ø35 para bomba dosificadora', 'UNIDAD', 'John Crane', 'T21-35', 'NO', 'SI', 'NO', 64000, 6000, 'MEC-SELLO', 8, 8, 6, 0.4),
        ('L2-RET-45', 'Retén 45x62x8', 'UNIDAD', 'NOK', 'AP2055E', 'NO', 'SI', 'NO', 2900, 8000, 'MEC-RETEN', 6, 6, 1, 0.05),
        ('L2-ACO-GR28', 'Acople elástico GR-28', 'UNIDAD', 'KTR', 'ROTEX 28', 'NO', 'NO', 'SI', 53400, None, 'MEC-ACOPLE', 11, 11, 7, 1.2),
        ('L2-MOT-55KW', 'Motor eléctrico trifásico 5,5 kW 4 polos', 'UNIDAD', 'WEG', 'W22 132S', 'NO', 'NO', 'SI', 420000, 40000, 'ELE-MOTOR', 45, 30, 30, 48),
        ('L2-CON-25A', 'Contactor 25 A bobina 24 V', 'UNIDAD', 'Schneider Electric', 'LC1D25BL', 'NO', 'NO', 'NO', 31800, None, 'ELE-CONTACTOR', 8, 8, 9, 0.5),
        ('L2-VAR-75KW', 'Variador de frecuencia 7,5 kW', 'UNIDAD', 'Danfoss', 'VLT FC-302', 'NO', 'NO', 'SI', 890000, None, 'ELE-VARIADOR', 40, 25, 25, 12),
        ('L2-FUS-NH63', 'Fusible NH 63 A', 'UNIDAD', 'Schneider Electric', 'NH00-63', 'NO', 'SI', 'NO', 4200, None, 'ELE-FUSIBLE', 8, 5, 5, 0.3),
        ('L2-SEN-PT100', 'Sensor de temperatura PT100 con vaina', 'UNIDAD', 'WIKA', 'TR10-A', 'NO', 'NO', 'NO', 36500, None, 'ELE-SENSOR', 25, 5, 5, 0.2),
        ('L2-SEN-PRES25', 'Transmisor de presión 0-25 bar', 'UNIDAD', 'WIKA', 'A-10', 'NO', 'NO', 'NO', 98000, None, 'ELE-SENSOR', 12, 6, 6, 0.3),
        ('L2-FIL-SEC', 'Filtro secador de línea de líquido', 'UNIDAD', 'Danfoss', 'DML 164', 'NO', 'SI', 'NO', 41500, 8000, 'REF-FILTRO', 18, 8, 8, 1.1),
        ('L2-VAL-EXP', 'Válvula de expansión termostática', 'UNIDAD', 'Danfoss', 'TEX 5', 'NO', 'NO', 'SI', 123000, None, 'MEC-VALVULA', 15, 8, 8, 0.8),
        ('L2-FIL-ACE', 'Filtro de aceite compresor', 'UNIDAD', 'Donaldson', 'P550148', 'NO', 'SI', 'NO', 19800, 4000, 'LUB-FILTRO', 12, 12, 17, 1.4),
        ('L2-REF-R404A', 'Refrigerante R404A cilindro 10,9 kg', 'KILOGRAMO', 'Chemours', 'R404A', 'SI', 'SI', 'NO', 9800, None, 'REF-REFRIGERANTE', 30, 30, 70, 15),
        ('L2-ACE-ISO68', 'Aceite lubricante ISO VG 68 (tambor 20 L)', 'LITRO', 'Mobil', 'DTE Oil Heavy Medium', 'SI', 'SI', 'NO', 4200, None, 'LUB-ACEITE', 30, 30, 40, 18),
        ('L2-ACE-POE', 'Aceite POE para compresor Bitzer (bidón 5 L)', 'LITRO', 'Bitzer', 'BSE55', 'SI', 'SI', 'NO', 18500, None, 'LUB-ACEITE', 20, 20, 25, 5),
        ('L2-GRA-EP2', 'Grasa EP-2 cartucho 400 g', 'UNIDAD', 'Klüber', 'Centoplex 2 EP', 'SI', 'SI', 'NO', 6900, None, 'LUB-GRASA', 5, 5, 25, 0.5),
        ('L2-GRA-H1', 'Grasa grado alimenticio NSF H1 cartucho 400 g', 'UNIDAD', 'Mobil', 'SHC Polyrex 222', 'SI', 'SI', 'NO', 11800, None, 'LUB-GRASA', 5, 5, 25, 0.5),
    ]
    filas = []
    for (cod, nom, uni, fab, mod, lote, cons, rep, costo, vida, tipo, largo, ancho, alto, peso) in R:
        filas.append([cod, nom, uni, fab, mod, lote, cons, rep, costo, vida, None, None, None, 'SI', tipo, None, largo, ancho, alto, peso])
    llenar(wb, 'REPUESTOS', filas)
    # bodega por repuesto: lubricantes, refrigerante y su filtro van a BOD-LUB; el resto, a BOD-L2
    LUB = {'L2-REF-R404A', 'L2-ACE-ISO68', 'L2-ACE-POE', 'L2-GRA-EP2', 'L2-GRA-H1'}
    umbr, stock = [], []
    ra = ['Pasillo A · Rack 01', 'Pasillo A · Rack 02', 'Pasillo A · Rack 03', 'Pasillo A · Rack 04', 'Pasillo B · Rack 01', 'Pasillo B · Rack 02']
    rl = ['Pasillo A · Rack 01', 'Pasillo A · Rack 02']
    # minimo, maximo, reposicion, cantidad, rack (indice)
    Q = {
        'L2-ROD-6312': (2, 8, 4, 6, 0), 'L2-ROD-6212': (2, 8, 4, 5, 0), 'L2-ROD-22216': (1, 4, 2, 3, 0),
        'L2-COR-SPB2000': (2, 8, 4, 6, 1), 'L2-COR-SPB2360': (2, 8, 4, 4, 1), 'L2-POL-SPB180': (1, 3, 2, 2, 1),
        'L2-CAD-12B': (5, 20, 10, 12, 2), 'L2-SEL-MEC35': (2, 6, 3, 4, 2), 'L2-RET-45': (4, 20, 8, 15, 2),
        'L2-ACO-GR28': (1, 3, 2, 2, 3), 'L2-MOT-55KW': (1, 2, 1, 1, 4), 'L2-CON-25A': (2, 6, 3, 5, 3),
        'L2-VAR-75KW': (1, 2, 1, 1, 5), 'L2-FUS-NH63': (6, 30, 12, 18, 3), 'L2-SEN-PT100': (2, 6, 3, 4, 3),
        'L2-SEN-PRES25': (1, 3, 2, 2, 3), 'L2-FIL-SEC': (2, 6, 3, 4, 5), 'L2-VAL-EXP': (1, 3, 2, 2, 5), 'L2-FIL-ACE': (2, 8, 4, 6, 5),
        'L2-REF-R404A': (20, 60, 30, 43.6, 1), 'L2-ACE-ISO68': (40, 160, 80, 100, 0), 'L2-ACE-POE': (10, 40, 20, 25, 1),
        'L2-GRA-EP2': (6, 24, 12, 18, 1), 'L2-GRA-H1': (6, 24, 12, 14, 1),
    }
    vence = {'L2-REF-R404A': D(2028, 12, 31), 'L2-ACE-ISO68': D(2028, 6, 30), 'L2-ACE-POE': D(2028, 3, 31), 'L2-GRA-EP2': D(2028, 9, 30), 'L2-GRA-H1': D(2028, 1, 31)}
    cost = {r[0]: r[8] for r in R}
    for r in R:
        cod = r[0]
        mn, mx, rp, cant, ri = Q[cod]
        bod = 'BOD-LUB' if cod in LUB else 'BOD-L2'
        rack = (rl if cod in LUB else ra)[ri]
        umbr.append([cod, bod, mn, mx, rp, None])
        stock.append([cod, bod, rack, cant, cost[cod], ('LOTE-2026-' + cod[-4:].replace('-', '')) if cod in vence else None, vence.get(cod), 'Stock inicial al implementar SIGMA'])
    llenar(wb, 'UMBRALES', umbr)
    llenar(wb, 'STOCK INICIAL', stock)
    llenar(wb, 'COMPATIBILIDADES', [])
    desplegables(wb, {
        'BODEGAS': {'PLANTA': ('PLANTAS', 'A'), 'METODO SALIDA': ['FEFO', 'FIFO', 'LIFO']},
        'REPUESTOS': {'UNIDAD': ('UNIDADES', 'A'), 'CONTROLA LOTE': SN, 'CONSUMIBLE': SN, 'REPARABLE': SN, 'HABILITADO': SN, 'TIPO': ('TIPOS', 'A')},
    })
    guardar(wb, '1_Carga_Inventario_Linea2.xlsx')


# ====================================================================== ACTIVOS
def activos():
    wb = abrir('ACTIVOS')
    # codigo, nombre, planta, area(cod), tipo, modelo, marca, serie, estado, criticidad, centro, depende, anio, puesta, en_uso, descripcion
    A = [
        ('L2-AMASADORA-01', 'Amasadora espiral línea 2', 'PAN-L2', 'Amasadoras', 'SPI 160', 'Sancassiano', 'SN-AM-2231', 'Operativo', 'Alta', 'Mecanico', None, 2021, D(2021, 3, 15), 'Amasadora espiral de 160 kg de masa por carga'),
        ('L2-DIVISORA-01', 'Divisora volumétrica línea 2', 'PAN-L2', 'Equipos de producción', 'DV-30', 'Mecatherm', 'SN-DV-8840', 'Operativo', 'Alta', 'Mecanico', None, 2021, D(2021, 3, 22), 'Corta y pesa la masa antes del formado'),
        ('L2-CINTA-01', 'Cinta transportadora de masa línea 2', 'PAN-L2', 'Equipos de producción', 'CT-600', 'Mecatherm', 'SN-CT-1127', 'Operativo', 'Media', 'Mecanico', 'L2-DIVISORA-01', 2021, D(2021, 3, 22), 'Lleva la masa desde la divisora a la laminadora'),
        ('L2-HORNO-01', 'Horno túnel línea 2', 'PAN-L2', 'Hornos', 'M-Tunnel 1200', 'Mecatherm', 'SN-HT-5530', 'Operativo', 'Crítica', 'Mecanico', None, 2021, D(2021, 4, 5), 'Horno túnel de gas, 3 zonas de cocción'),
        ('L2-QUEMADOR-01', 'Quemador a gas del horno línea 2', 'PAN-L2', 'Hornos', 'QG-500', 'Honeywell', 'SN-QG-7712', 'Operativo', 'Crítica', 'Mecanico', 'L2-HORNO-01', 2021, D(2021, 4, 5), 'Quemador modulante de 500 kW'),
        ('L2-COMPRESOR-01', 'Compresor de frío línea 2', 'REF-L2', 'Compresores', '4FES-5', 'Bitzer', 'SN-BZ-9021', 'Operativo', 'Crítica', 'Mecanico', None, 2020, D(2020, 11, 10), 'Compresor semihermético para cámaras de fermentación'),
        ('L2-CAMARA-01', 'Cámara de fermentación línea 2', 'REF-L2', 'Cámaras de frío', 'CF-40', 'Frigorífica Sur', 'SN-CF-3340', 'Operativo', 'Alta', 'Mecanico', None, 2020, D(2020, 11, 20), 'Cámara de fermentación controlada de 40 m³'),
        ('L2-BOMBA-01', 'Bomba dosificadora de agua línea 2', 'DOS-L2', 'Bombas', 'DDA 7.5', 'Grundfos', 'SN-GF-6650', 'Operativo', 'Media', 'Mecanico', None, 2022, D(2022, 2, 8), 'Dosifica el agua de amasado'),
        ('L2-DOSIFICADOR-01', 'Dosificador de manteca línea 2', 'DOS-L2', 'Dosificación', None, 'Mecatherm', 'SN-DM-2208', 'Operativo con observación', 'Media', 'Mecanico', None, 2022, D(2022, 2, 8), 'Tolva con tornillo dosificador de manteca'),
        ('L2-SOPLADOR-01', 'Soplador de enfriamiento línea 2', 'DES-L2', 'Sopladores', None, 'Aerzen', 'SN-AZ-4417', 'Operativo', 'Alta', 'Mecanico', None, 2021, D(2021, 6, 1), 'Soplador de lóbulos para el enfriamiento del producto'),
        ('L2-LAMINADORA-01', 'Laminadora línea 2', 'PAN-L2', 'Laminadora', None, 'Fritsch', 'SN-FR-1190', 'Operativo', 'Media', 'Mecanico', None, 2019, D(2019, 9, 12), 'Lamina la masa a espesor de trabajo'),
        ('L2-TABLERO-01', 'Tablero de control línea 2', 'PAN-L2', 'Equipos de producción', 'TC-125', 'Schneider Electric', 'SN-SE-0932', 'Operativo', 'Alta', 'Electrico', None, 2021, D(2021, 3, 1), 'Tablero general de fuerza y control de la línea'),
    ]
    filas = [[c, n, PLANTA, ar, t, m, mar, s, e, cr, cc, dep, an, pu, 'SI', ds] for (c, n, ar, t, m, mar, s, e, cr, cc, dep, an, pu, ds) in A]
    llenar(wb, 'ACTIVOS', filas)

    T = [
        ('L2-AMASADORA-01', 'Potencia del motor', '11', 'KW'), ('L2-AMASADORA-01', 'Voltaje', '380', 'V'),
        ('L2-AMASADORA-01', 'Velocidad de la espiral', '1450', 'RPM'), ('L2-AMASADORA-01', 'Capacidad de masa', '160', 'KILOGRAMO'),
        ('L2-DIVISORA-01', 'Potencia', '3', 'KW'), ('L2-DIVISORA-01', 'Voltaje', '380', 'V'),
        ('L2-CINTA-01', 'Potencia', '1.5', 'KW'), ('L2-CINTA-01', 'Largo útil', '6', 'METRO'),
        ('L2-HORNO-01', 'Potencia térmica', '850', 'KW'), ('L2-HORNO-01', 'Temperatura de trabajo', '240', 'CELSIUS'), ('L2-HORNO-01', 'Voltaje de control', '380', 'V'),
        ('L2-QUEMADOR-01', 'Potencia', '500', 'KW'), ('L2-QUEMADOR-01', 'Presión de gas', '0.3', 'BAR'),
        ('L2-COMPRESOR-01', 'Potencia', '22', 'KW'), ('L2-COMPRESOR-01', 'Voltaje', '380', 'V'), ('L2-COMPRESOR-01', 'Presión máxima de descarga', '16', 'BAR'), ('L2-COMPRESOR-01', 'Refrigerante', 'R404A', None),
        ('L2-CAMARA-01', 'Temperatura de trabajo', '30', 'CELSIUS'), ('L2-CAMARA-01', 'Volumen', '40', 'M3'),
        ('L2-BOMBA-01', 'Caudal', '7.5', 'LH'), ('L2-BOMBA-01', 'Presión máxima', '10', 'BAR'), ('L2-BOMBA-01', 'Potencia', '0.37', 'KW'),
        ('L2-DOSIFICADOR-01', 'Capacidad de la tolva', '25', 'LITRO'), ('L2-DOSIFICADOR-01', 'Potencia', '0.75', 'KW'),
        ('L2-SOPLADOR-01', 'Caudal', '1200', 'M3H'), ('L2-SOPLADOR-01', 'Potencia', '7.5', 'KW'), ('L2-SOPLADOR-01', 'Velocidad', '2900', 'RPM'),
        ('L2-LAMINADORA-01', 'Potencia', '2.2', 'KW'), ('L2-LAMINADORA-01', 'Ancho de rodillo', '600', 'MM'),
        ('L2-TABLERO-01', 'Voltaje', '380', 'V'), ('L2-TABLERO-01', 'Corriente nominal', '125', 'A'),
    ]
    llenar(wb, 'DATOS TECNICOS', [list(t) for t in T])

    # activo, nombre, que_es, donde_va, criticidad, fecha, descripcion
    C = [
        ('L2-AMASADORA-01', 'Motor principal', 'Motor', 'Único', 'Alta', D(2021, 3, 15), 'Motor trifásico de 11 kW'),
        ('L2-AMASADORA-01', 'Reductor de la espiral', 'Reductor', 'Central', 'Alta', D(2021, 3, 15), None),
        ('L2-AMASADORA-01', 'Rodamiento lado motor', 'Rodamiento', 'Lado motor', 'Alta', D(2021, 3, 15), None),
        ('L2-AMASADORA-01', 'Correa de transmisión', 'Correa', 'Lado acople', 'Media', D(2021, 3, 15), None),
        ('L2-DIVISORA-01', 'Motor de accionamiento', 'Motor', 'Único', 'Media', D(2021, 3, 22), None),
        ('L2-DIVISORA-01', 'Cadena de arrastre', 'Cadena', 'Central', 'Media', D(2021, 3, 22), None),
        ('L2-CINTA-01', 'Motor de la cinta', 'Motor', 'Único', 'Baja', D(2021, 3, 22), None),
        ('L2-CINTA-01', 'Rodamiento del tambor', 'Rodamiento', 'Lado A', 'Media', D(2021, 3, 22), None),
        ('L2-HORNO-01', 'Ventilador de convección', 'Motor', 'Superior', 'Alta', D(2021, 4, 5), None),
        ('L2-HORNO-01', 'Cadena de transporte', 'Cadena', 'Central', 'Crítica', D(2021, 4, 5), 'Mueve las bandejas por el túnel'),
        ('L2-HORNO-01', 'Sensor de temperatura zona 1', 'Sensor', 'Entrada', 'Alta', D(2021, 4, 5), None),
        ('L2-HORNO-01', 'Sensor de temperatura zona 2', 'Sensor', 'Salida', 'Alta', D(2021, 4, 5), None),
        ('L2-QUEMADOR-01', 'Válvula de gas', 'Válvula', 'Entrada', 'Crítica', D(2021, 4, 5), None),
        ('L2-QUEMADOR-01', 'Sensor de llama', 'Sensor', 'Central', 'Crítica', D(2021, 4, 5), None),
        ('L2-COMPRESOR-01', 'Motor eléctrico del compresor', 'Motor', 'Único', 'Crítica', D(2020, 11, 10), None),
        ('L2-COMPRESOR-01', 'Válvula de expansión', 'Válvula', 'Salida', 'Alta', D(2020, 11, 10), None),
        ('L2-COMPRESOR-01', 'Filtro secador', 'Filtro', 'Entrada', 'Media', D(2020, 11, 10), None),
        ('L2-COMPRESOR-01', 'Transmisor de presión', 'Sensor', 'Salida', 'Alta', D(2020, 11, 10), None),
        ('L2-CAMARA-01', 'Motor del ventilador', 'Motor', 'Superior', 'Alta', D(2020, 11, 20), None),
        ('L2-CAMARA-01', 'Sensor de temperatura', 'Sensor', 'Central', 'Alta', D(2020, 11, 20), None),
        ('L2-BOMBA-01', 'Motor de la bomba', 'Motor', 'Único', 'Media', D(2022, 2, 8), None),
        ('L2-BOMBA-01', 'Sello mecánico', 'Retén', 'Lado acople', 'Media', D(2022, 2, 8), None),
        ('L2-DOSIFICADOR-01', 'Motor del dosificador', 'Motor', 'Único', 'Media', D(2022, 2, 8), None),
        ('L2-DOSIFICADOR-01', 'Rodamiento del eje', 'Rodamiento', 'Lado A', 'Media', D(2022, 2, 8), None),
        ('L2-SOPLADOR-01', 'Motor del soplador', 'Motor', 'Único', 'Alta', D(2021, 6, 1), None),
        ('L2-SOPLADOR-01', 'Rodamiento lado motor', 'Rodamiento', 'Lado motor', 'Alta', D(2021, 6, 1), None),
        ('L2-SOPLADOR-01', 'Acople elástico', 'Acople', 'Central', 'Media', D(2021, 6, 1), None),
        ('L2-LAMINADORA-01', 'Motor de rodillos', 'Motor', 'Único', 'Media', D(2019, 9, 12), None),
        ('L2-LAMINADORA-01', 'Rodamiento de rodillo', 'Rodamiento', 'Lado A', 'Media', D(2019, 9, 12), None),
        ('L2-TABLERO-01', 'Variador de frecuencia', 'Otro', 'Izquierda', 'Alta', D(2021, 3, 1), 'Controla la velocidad de la amasadora'),
        ('L2-TABLERO-01', 'Contactor principal', 'Otro', 'Derecha', 'Alta', D(2021, 3, 1), None),
    ]
    llenar(wb, 'COMPONENTES', [list(c) for c in C])

    # activo, componente, variable, unidad, min, max, adv, crit, frecuencia horas
    V = [
        ('L2-HORNO-01', 'Sensor de temperatura zona 1', 'Temperatura zona 1', 'CELSIUS', 200, 250, 235, 245, 1),
        ('L2-HORNO-01', 'Sensor de temperatura zona 2', 'Temperatura zona 2', 'CELSIUS', 190, 240, 225, 235, 1),
        ('L2-COMPRESOR-01', 'Transmisor de presión', 'Presión de descarga', 'BAR', 8, 17, 15, 16, 1),
        ('L2-COMPRESOR-01', None, 'Temperatura de descarga', 'CELSIUS', 40, 95, 80, 90, 4),
        ('L2-CAMARA-01', 'Sensor de temperatura', 'Temperatura de fermentación', 'CELSIUS', 26, 35, 31, 33, 1),
        ('L2-AMASADORA-01', 'Rodamiento lado motor', 'Temperatura del rodamiento', 'CELSIUS', 20, 85, 70, 80, 8),
        ('L2-AMASADORA-01', 'Motor principal', 'Corriente del motor', 'A', 8, 25, 21, 23, 4),
        ('L2-SOPLADOR-01', 'Rodamiento lado motor', 'Vibración', 'MMS', 0, 8, 4.5, 7.1, 8),
        ('L2-SOPLADOR-01', 'Motor del soplador', 'Temperatura del motor', 'CELSIUS', 20, 105, 85, 100, 8),
        ('L2-BOMBA-01', None, 'Presión de descarga de la bomba', 'BAR', 2, 11, 9.5, 10.5, 4),
        ('L2-TABLERO-01', None, 'Corriente total de la línea', 'A', 0, 125, 110, 120, 1),
    ]
    llenar(wb, 'VARIABLES', [list(v) for v in V])

    M = [
        ('L2-AMASADORA-01', 'Horómetro', 'HORA', 12450, 'NO', None),
        ('L2-DIVISORA-01', 'Contador de ciclos', 'CICLO', 1850000, 'SI', 0),
        ('L2-HORNO-01', 'Horómetro', 'HORA', 21800, 'NO', None),
        ('L2-COMPRESOR-01', 'Horómetro', 'HORA', 18200, 'NO', None),
        ('L2-BOMBA-01', 'Horómetro', 'HORA', 6400, 'NO', None),
        ('L2-SOPLADOR-01', 'Horómetro', 'HORA', 9100, 'NO', None),
        ('L2-LAMINADORA-01', 'Horómetro', 'HORA', 5300, 'NO', None),
    ]
    llenar(wb, 'MEDIDORES', [list(m) for m in M])

    P = [
        ('L2-AMASADORA-01', 'Rodamiento lado motor', 'L2-ROD-6312', 'Rodamiento original de la espiral'),
        ('L2-AMASADORA-01', 'Correa de transmisión', 'L2-COR-SPB2000', None),
        ('L2-AMASADORA-01', 'Reductor de la espiral', 'L2-ACE-ISO68', 'Aceite del reductor'),
        ('L2-AMASADORA-01', 'Rodamiento lado motor', 'L2-GRA-H1', 'Grasa grado alimenticio'),
        ('L2-DIVISORA-01', 'Cadena de arrastre', 'L2-CAD-12B', None),
        ('L2-CINTA-01', 'Rodamiento del tambor', 'L2-ROD-6212', None),
        ('L2-HORNO-01', 'Cadena de transporte', 'L2-CAD-12B', None),
        ('L2-HORNO-01', 'Sensor de temperatura zona 1', 'L2-SEN-PT100', None),
        ('L2-HORNO-01', 'Sensor de temperatura zona 2', 'L2-SEN-PT100', None),
        ('L2-HORNO-01', 'Ventilador de convección', 'L2-ROD-6312', None),
        ('L2-HORNO-01', 'Ventilador de convección', 'L2-COR-SPB2360', None),
        ('L2-COMPRESOR-01', 'Válvula de expansión', 'L2-VAL-EXP', None),
        ('L2-COMPRESOR-01', 'Filtro secador', 'L2-FIL-SEC', None),
        ('L2-COMPRESOR-01', 'Transmisor de presión', 'L2-SEN-PRES25', None),
        ('L2-COMPRESOR-01', None, 'L2-ACE-POE', 'Aceite del cárter'),
        ('L2-COMPRESOR-01', None, 'L2-REF-R404A', 'Carga de refrigerante'),
        ('L2-COMPRESOR-01', None, 'L2-FIL-ACE', None),
        ('L2-CAMARA-01', 'Sensor de temperatura', 'L2-SEN-PT100', None),
        ('L2-CAMARA-01', 'Motor del ventilador', 'L2-ROD-6212', None),
        ('L2-BOMBA-01', 'Sello mecánico', 'L2-SEL-MEC35', None),
        ('L2-BOMBA-01', 'Motor de la bomba', 'L2-RET-45', None),
        ('L2-DOSIFICADOR-01', 'Rodamiento del eje', 'L2-ROD-6212', None),
        ('L2-DOSIFICADOR-01', 'Rodamiento del eje', 'L2-GRA-H1', 'Grasa grado alimenticio'),
        ('L2-SOPLADOR-01', 'Rodamiento lado motor', 'L2-ROD-6312', None),
        ('L2-SOPLADOR-01', 'Acople elástico', 'L2-ACO-GR28', None),
        ('L2-SOPLADOR-01', None, 'L2-COR-SPB2360', None),
        ('L2-LAMINADORA-01', 'Rodamiento de rodillo', 'L2-ROD-22216', None),
        ('L2-LAMINADORA-01', 'Rodamiento de rodillo', 'L2-GRA-EP2', None),
        ('L2-TABLERO-01', 'Variador de frecuencia', 'L2-VAR-75KW', None),
        ('L2-TABLERO-01', 'Contactor principal', 'L2-CON-25A', None),
        ('L2-TABLERO-01', None, 'L2-FUS-NH63', None),
        ('L2-AMASADORA-01', 'Motor principal', 'L2-MOT-55KW', 'Equivalente de reposición (revisar potencia)'),
    ]
    llenar(wb, 'REPUESTOS COMPATIBLES', [list(p) for p in P])
    desplegables(wb, {
        'ACTIVOS': {'PLANTA': ('PLANTAS', 'A'), 'AREA': ('AREAS', 'B'), 'TIPO': ('TIPOS ACTIVO', 'A'), 'ESTADO': ('ESTADOS', 'A'), 'CRITICIDAD': ('CRITICIDADES', 'A'),
                    'CENTRO COSTO': ('CENTROS COSTO', 'A'), 'EN USO': SN},
        'DATOS TECNICOS': {'UNIDAD': ('UNIDADES', 'A')},
        'COMPONENTES': {'QUE ES': ('TIPOS COMPONENTE', 'A'), 'DONDE VA': ('POSICIONES', 'A'), 'CRITICIDAD': ('CRITICIDADES', 'A')},
        'VARIABLES': {'UNIDAD': ('UNIDADES', 'A')},
        'MEDIDORES': {'UNIDAD': ('UNIDADES', 'A'), 'PERMITE REINICIO': SN},
    })
    guardar(wb, '2_Carga_Activos_Linea2.xlsx')


# ====================================================================== MANTENIMIENTO
def mantenimiento():
    wb = abrir('MANTENIMIENTO')
    F = {
        'L2 Semanal lunes y jueves': ('SEMANAL', 'LUN,JUE', None, None, None, '07:30'),
        'L2 Diaria hábil': ('SEMANAL', 'LUN,MAR,MIE,JUE,VIE', None, None, None, '06:30'),
        'L2 Mensual día 5': ('MENSUAL', None, 5, None, None, '08:00'),
        'L2 Cada 15 días': ('CADA', None, None, 15, 'DIA', '08:00'),
        'L2 Cada 3 meses': ('CADA', None, None, 3, 'MES', '08:00'),
        'L2 Cada 6 meses': ('CADA', None, None, 6, 'MES', '08:00'),
    }
    llenar(wb, 'FRECUENCIAS', [[n, t, d, dm, c, u, h, None] for n, (t, d, dm, c, u, h) in F.items()])
    # codigo, titulo, descripcion, prioridad, duracion, evidencia, categoria, planta, area, equipo
    T = [
        ('L2-T01', 'Revisar nivel de aceite del reductor de la amasadora', 'Verificar por la mirilla que el nivel quede entre las marcas y completar si falta.', 'Media', 15, 'NO', 'Lubricación', 'PAN-L2', 'L2-AMASADORA-01'),
        ('L2-T02', 'Limpieza de la cinta transportadora de masa', 'Retirar restos de masa y harina con espátula y paño húmedo.', 'Baja', 20, 'NO', 'Aseo y orden', 'PAN-L2', 'L2-CINTA-01'),
        ('L2-T03', 'Verificar tensión y estado de las correas de la amasadora', 'Medir la flecha de la correa y revisar desgaste de poleas.', 'Media', 25, 'SI', 'Inspección', 'PAN-L2', 'L2-AMASADORA-01'),
        ('L2-T04', 'Prueba de alarmas y paradas de emergencia de la línea', 'Accionar cada parada de emergencia y confirmar que corta la energía.', 'Alta', 30, 'SI', 'Seguridad', 'PAN-L2', None),
        ('L2-T05', 'Revisión de presión de aire y purga del tablero de control', 'Purgar el filtro regulador y registrar la presión.', 'Baja', 10, 'NO', 'Inspección', 'PAN-L2', 'L2-TABLERO-01'),
        ('L2-T06', 'Revisión de fugas en el circuito de gas del horno', 'Detectar fugas con espuma en uniones y válvulas del circuito de gas.', 'Alta', 20, 'SI', 'Seguridad', 'PAN-L2', 'L2-QUEMADOR-01'),
    ]
    llenar(wb, 'TAREAS', [[c, t, d, p, du, ev, cat, PLANTA, ar, eq, 'SI'] for (c, t, d, p, du, ev, cat, ar, eq) in T])
    llenar(wb, 'TAREAS PROGRAMADAS', [
        ['L2-T01', 'L2 Semanal lunes y jueves', None, 'Turno Preventivo A'],
        ['L2-T02', 'L2 Diaria hábil', None, 'Turno Preventivo B'],
        ['L2-T03', 'L2 Mensual día 5', None, 'Turno Preventivo A'],
        ['L2-T04', 'L2 Cada 3 meses', None, 'Turno Preventivo C'],
        ['L2-T05', 'L2 Cada 15 días', None, 'Turno Preventivo B'],
        ['L2-T06', 'L2 Semanal lunes y jueves', None, 'Turno Preventivo A'],
    ])
    llenar(wb, 'CHECKLISTS', [
        ['L2-CHK-HORNO', 'Ronda de inspección del horno túnel línea 2', 'Revisión diaria del horno, el quemador y la cadena de transporte.', PLANTA, 'Hornos', 'SI'],
        ['L2-CHK-FRIO', 'Ronda de refrigeración y fermentación línea 2', 'Revisión diaria del compresor y de la cámara de fermentación.', PLANTA, None, 'SI'],
    ])
    I = [
        ('L2-CHK-HORNO', 'Seguridad', '¿Resguardos y paradas de emergencia en su lugar?', 'Sí / No', None),
        ('L2-CHK-HORNO', 'Quemador', '¿La llama es estable y de color azul?', 'Sí / No', None),
        ('L2-CHK-HORNO', 'Quemador', 'Temperatura zona 1', 'Medición', 'CELSIUS'),
        ('L2-CHK-HORNO', 'Quemador', 'Temperatura zona 2', 'Medición', 'CELSIUS'),
        ('L2-CHK-HORNO', 'Mecánica', '¿La cadena de transporte avanza sin ruidos ni saltos?', 'Sí / No', None),
        ('L2-CHK-HORNO', 'Mecánica', 'Observaciones generales', 'Texto largo', None),
        ('L2-CHK-FRIO', 'Compresor', 'Presión de descarga', 'Medición', 'BAR'),
        ('L2-CHK-FRIO', 'Compresor', 'Temperatura de descarga', 'Medición', 'CELSIUS'),
        ('L2-CHK-FRIO', 'Compresor', '¿Se ve el nivel de aceite en la mirilla?', 'Sí / No', None),
        ('L2-CHK-FRIO', 'Compresor', '¿Hay fugas visibles de refrigerante?', 'Sí / No', None),
        ('L2-CHK-FRIO', 'Cámara de fermentación', 'Temperatura de la cámara', 'Medición', 'CELSIUS'),
        ('L2-CHK-FRIO', 'Cámara de fermentación', '¿Puertas y burletes en buen estado?', 'Sí / No', None),
        ('L2-CHK-FRIO', 'Cámara de fermentación', 'Foto del evaporador', 'Fotografía', None),
    ]
    llenar(wb, 'CHECKLIST ITEMS', [[c, s, None, tx, tp, None, 'SI', 'SI', 'SI' if tp == 'Fotografía' else 'NO', u] for (c, s, tx, tp, u) in I])
    llenar(wb, 'CHECKLISTS PROGRAMADOS', [
        ['L2-CHK-HORNO', 'L2 Diaria hábil', 'L2-HORNO-01', None, 'Turno Preventivo A', None, None],
        ['L2-CHK-FRIO', 'L2 Diaria hábil', 'L2-COMPRESOR-01', None, 'Turno Refrigeración A', None, None],
        ['L2-CHK-FRIO', 'L2 Diaria hábil', 'L2-CAMARA-01', None, 'Turno Refrigeración B', None, None],
    ])
    llenar(wb, 'PLANES', [
        ['L2-PM-HORNO', 'Plan preventivo del horno y quemador línea 2', 'Inspección mensual, engrase quincenal y revisión mayor semestral del horno túnel.', PLANTA, None, 'Hornos', None, 'NO'],
        ['L2-PM-LUB', 'Plan de lubricación y correas línea 2', 'Lubricación de rodamientos y cambio de correas de los equipos rotativos de la línea.', PLANTA, None, None, None, 'NO'],
    ])
    # plan, codigo, nombre, orden, frecuencia, duracion, parada, overhaul, tipo_ot, prioridad_ot, responsable, grupo, descripcion
    H = [
        ('L2-PM-HORNO', 'H1', 'Inspección del quemador y los sensores', 1, 'L2 Mensual día 5', 90, 'SI', 'NO', 'Preventiva', 'Alta', 'Turno Preventivo A', 'Cierre de gas, limpieza del sensor de llama y verificación de los PT100.'),
        ('L2-PM-HORNO', 'H2', 'Engrase de la cadena de transporte', 2, 'L2 Cada 15 días', 45, 'NO', 'NO', 'Preventiva', 'Media', 'Turno Preventivo B', 'Limpieza y engrase de la cadena con grasa grado alimenticio.'),
        ('L2-PM-HORNO', 'H3', 'Revisión general semestral', 3, 'L2 Cada 6 meses', 240, 'SI', 'SI', 'Preventiva', 'Alta', 'Turno Preventivo A', 'Revisión mayor del horno con la línea detenida.'),
        ('L2-PM-LUB', 'H1', 'Lubricación de rodamientos', 1, 'L2 Cada 15 días', 60, 'NO', 'NO', 'Preventiva', 'Media', 'Turno Preventivo B', 'Engrase de rodamientos de amasadora, soplador, divisora y laminadora.'),
        ('L2-PM-LUB', 'H2', 'Cambio y tensado de correas', 2, 'L2 Cada 3 meses', 90, 'SI', 'NO', 'Preventiva', 'Media', 'Turno Preventivo C', 'Recambio de correas y verificación de poleas.'),
    ]
    llenar(wb, 'HITOS', [[p, c, n, o, f, d, pa, ov, to, po, None, g, ds] for (p, c, n, o, f, d, pa, ov, to, po, g, ds) in H])
    # plan, hito, codigo, nombre, descripcion, orden, duracion, obligatoria, parada
    A = [
        ('L2-PM-HORNO', 'H1', 'Cerrar el gas y bloquear la energía', 'Aplicar bloqueo y etiquetado antes de intervenir.', 10, 'SI', 'SI'),
        ('L2-PM-HORNO', 'H1', 'Limpiar y revisar el sensor de llama', None, 30, 'SI', 'SI'),
        ('L2-PM-HORNO', 'H1', 'Verificar la calibración de los sensores PT100', None, 40, 'SI', 'SI'),
        ('L2-PM-HORNO', 'H2', 'Limpiar la cadena con desengrasante', None, 15, 'SI', 'NO'),
        ('L2-PM-HORNO', 'H2', 'Engrasar con grasa grado alimenticio NSF H1', None, 30, 'SI', 'NO'),
        ('L2-PM-HORNO', 'H3', 'Revisar la aislación interna y las puertas', None, 120, 'SI', 'SI'),
        ('L2-PM-HORNO', 'H3', 'Probar paradas de emergencia y enclavamientos', None, 60, 'SI', 'SI'),
        ('L2-PM-LUB', 'H1', 'Purgar la grasa vieja y engrasar los rodamientos', None, 40, 'SI', 'NO'),
        ('L2-PM-LUB', 'H1', 'Registrar la cantidad de grasa aplicada', None, 20, 'NO', 'NO'),
        ('L2-PM-LUB', 'H2', 'Retirar la correa y revisar las poleas', None, 40, 'SI', 'SI'),
        ('L2-PM-LUB', 'H2', 'Montar la correa nueva y tensar', None, 50, 'SI', 'SI'),
    ]
    llenar(wb, 'ACTIVIDADES', [[p, h, None, n, d, i + 1, du, ob, pa] for i, (p, h, n, d, du, ob, pa) in enumerate(A)])
    llenar(wb, 'EQUIPOS', [
        ['L2-PM-HORNO', 'L2-HORNO-01', None, 'Horómetro'], ['L2-PM-HORNO', 'L2-QUEMADOR-01', None, None],
        ['L2-PM-LUB', 'L2-AMASADORA-01', None, None], ['L2-PM-LUB', 'L2-SOPLADOR-01', None, None],
        ['L2-PM-LUB', 'L2-LAMINADORA-01', None, None], ['L2-PM-LUB', 'L2-DIVISORA-01', None, None],
    ])
    desplegables(wb, {
        'FRECUENCIAS': {'TIPO': ['SEMANAL', 'MENSUAL', 'CADA'], 'UNIDAD': ['HORA', 'DIA', 'SEMANA', 'MES', 'AÑO']},
        'TAREAS': {'PRIORIDAD': ('PRIORIDADES', 'A'), 'PLANTA': ('PLANTAS', 'A'), 'REQUIERE EVIDENCIA': SN, 'HABILITADA': SN},
        'CHECKLIST ITEMS': {'TIPO': ('TIPOS ITEM', 'A'), 'UNIDAD': ('UNIDADES', 'A'), 'OBLIGATORIO': SN, 'COMENTARIO': SN, 'EVIDENCIA': SN},
        'PLANES': {'PLANTA': ('PLANTAS', 'A'), 'ACTIVAR': SN},
        'HITOS': {'TIPO OT': ('TIPOS OT', 'A'), 'PRIORIDAD OT': ('PRIORIDADES OT', 'A'), 'PARADA': SN, 'OVERHAUL': SN},
        'ACTIVIDADES': {'OBLIGATORIA': SN, 'PARADA': SN},
    })
    guardar(wb, '3_Carga_Mantenimiento_Linea2.xlsx')


def guardar(wb, nombre):
    # la hoja LEAME de la plantilla queda; se agrega una línea con el contexto de la presentación
    ws = wb['LEAME']
    ws['A2'].value = (ws['A2'].value or '') + ' · Datos de demostración: ampliación Línea 2 de Planta Renca (Hamburgo SA).'
    os.makedirs(SALIDA, exist_ok=True)
    wb.save(os.path.join(SALIDA, nombre))
    print('guardado', nombre)


def activos_con_errores():
    """Archivo corto para mostrar cómo SIGMA revisa y explica los errores antes de escribir nada."""
    wb = abrir('ACTIVOS')
    llenar(wb, 'ACTIVOS', [
        ['L2-DEMO-OK-01', 'Prensa de formado línea 2', PLANTA, 'PAN-L2', 'Equipos de producción', None, 'Mecatherm', 'SN-PF-0001', 'Operativo', 'Media', 'Mecanico', None, 2022, D(2022, 5, 10), 'SI', 'Fila correcta'],
        ['L2-DEMO-OK-02', 'Selladora de bolsas línea 2', PLANTA, 'DES-L2', 'Equipos de producción', None, 'Mecatherm', 'SN-SB-0002', 'Operativo', 'Baja', 'Mecanico', 'L2-DEMO-OK-01', 2022, D(2022, 5, 10), 'SI', 'Fila correcta (depende de la anterior)'],
        ['L2-DEMO-ERR-01', 'Horno de prueba', 'Planta Maipú', 'PAN-L2', 'Hornos', None, None, None, 'Operativo', 'Alta', None, None, 2021, D(2021, 1, 10), 'SI', 'Error: la planta no existe'],
        ['L2-DEMO-ERR-02', 'Compresor de prueba', PLANTA, 'REF-L2', 'Compresores', None, None, None, 'Operativo', 'Extrema', None, None, 2021, D(2021, 1, 10), 'SI', 'Error: la criticidad no existe'],
        ['L2-DEMO-ERR-03', 'Bomba de prueba', PLANTA, 'DOS-L2', 'Bombas', None, None, None, 'Operativo', 'Media', None, 'L2-NO-EXISTE', 2090, D(2090, 1, 1), 'SI', 'Error: año y fecha futuros, y depende de un activo que no existe'],
        [None, 'Soplador de prueba', PLANTA, 'DES-L2', None, None, None, None, 'Operativo', 'Media', None, None, None, None, 'SI', 'Error: falta el tipo de activo'],
    ])
    llenar(wb, 'DATOS TECNICOS', [['L2-DEMO-OK-01', 'Potencia', '4', 'KW'], ['L2-DEMO-ERR-02', 'Potencia', '15', 'KW']])
    llenar(wb, 'COMPONENTES', [['L2-DEMO-OK-01', 'Motor principal', 'Motor', 'Único', 'Media', None, None]])
    llenar(wb, 'VARIABLES', [])
    llenar(wb, 'MEDIDORES', [['L2-DEMO-OK-01', 'Horómetro', 'HORA', 100, 'NO', None]])
    llenar(wb, 'REPUESTOS COMPATIBLES', [])
    guardar(wb, '2b_Activos_con_errores_para_mostrar.xlsx')


if __name__ == '__main__':
    inventario()
    activos()
    mantenimiento()
    activos_con_errores()
