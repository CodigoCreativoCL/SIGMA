# -*- coding: utf-8 -*-
"""Libros de la demo del miércoles 21-10-2026 — cliente de ejemplo CODELCO, rubro minería (datos inventados).

Se parte de las plantillas oficiales de SIGMA (INVENTARIO.xlsx, ACTIVOS.xlsx, MANTENIMIENTO.xlsx: se descargan desde
Utilidades › Carga de datos) y se les QUITAN las hojas de ayuda, porque traen los datos de otra empresa. Los libros
nombran lo que el cliente crea a mano antes de cargar (ver GUIA_Demo_Codelco.md): una planta y cuatro áreas.

    python generar_libros_codelco.py [carpeta de las plantillas] [carpeta de salida]
"""
import datetime as dt
import os
import sys
import warnings

import openpyxl

warnings.filterwarnings('ignore')
AQUI = os.path.dirname(os.path.abspath(__file__))
PLANTILLAS = sys.argv[1] if len(sys.argv) > 1 else r'C:\Capstone_Archivo\_scratch\plantillas'
SALIDA = sys.argv[2] if len(sys.argv) > 2 else os.path.join(AQUI, 'Codelco')
D = dt.date
PLANTA = 'Concentradora Cerro Alto'
AYUDAS = {
    'INVENTARIO': ['PLANTAS', 'BODEGAS EXISTENTES', 'RACKS EXISTENTES', 'UNIDADES', 'TIPOS', 'FABRICANTES', 'ACTIVOS EXISTENTES'],
    'ACTIVOS': ['PLANTAS', 'AREAS', 'TIPOS ACTIVO', 'ESTADOS', 'CRITICIDADES', 'CENTROS COSTO', 'UNIDADES', 'ACTIVOS EXISTENTES', 'TIPOS COMPONENTE', 'POSICIONES', 'REPUESTOS'],
    'MANTENIMIENTO': ['PLANTAS', 'AREAS', 'ACTIVOS EXISTENTES', 'TIPOS ACTIVO', 'TIPOS Y MODELOS', 'UNIDADES', 'FRECUENCIAS EXISTENTES', 'TAREAS EXISTENTES',
                      'CHECKLISTS EXISTENTES', 'PLANES EXISTENTES', 'PERSONAS', 'GRUPOS', 'PRIORIDADES', 'CATEGORIAS TAREA', 'TIPOS ITEM', 'TIPOS OT', 'PRIORIDADES OT'],
}


def abrir(nombre):
    wb = openpyxl.load_workbook(os.path.join(PLANTILLAS, nombre + '.xlsx'))
    for h in AYUDAS[nombre]:
        if h in wb.sheetnames:
            del wb[h]
    return wb


def llenar(wb, hoja, filas):
    ws = wb[hoja]
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


def guardar(wb, nombre, nota):
    ws = wb['LEAME']
    ws['A2'].value = (ws['A2'].value or '') + ' · ' + nota
    os.makedirs(SALIDA, exist_ok=True)
    wb.save(os.path.join(SALIDA, nombre))
    print('guardado', nombre)


# ====================================================================== INVENTARIO
def inventario():
    wb = abrir('INVENTARIO')
    llenar(wb, 'BODEGAS', [
        ['BOD-CEN', 'Bodega Central de Repuestos Cerro Alto', PLANTA, 'Rodamientos, motores, variadores, sensores, sellos y válvulas', 'FIFO'],
        ['BOD-DES', 'Bodega de Piezas de Desgaste', PLANTA, 'Revestimientos de molinos y chancadores, bolas de acero, rodillos y banda transportadora', 'FIFO'],
        ['BOD-LUB', 'Bodega de Lubricantes y Reactivos', PLANTA, 'Aceites, grasas y reactivos de flotación, con lote y vencimiento', 'FEFO'],
    ])
    racks = []
    for bod, pas, n, cap in (('BOD-CEN', 'A', 4, 800), ('BOD-CEN', 'B', 2, 1200), ('BOD-DES', 'A', 3, 5000), ('BOD-LUB', 'A', 3, 2000)):
        for k in range(1, n + 1):
            racks.append([bod, 'Pasillo', pas, k, None, None, cap])
    llenar(wb, 'RACKS', racks)
    # codigo, nombre, unidad, fabricante, modelo, lote, consumible, reparable, costo, vida_h, bodega, largo, ancho, alto, peso
    R = [
        ('CA-LIN-SAG', 'Revestimiento (liner) de descarga del molino SAG', 'UNIDAD', 'Metso', 'Outotec SAG-DL36', 'NO', 'SI', 'NO', 4800000, 9000, 'BOD-DES', 180, 120, 45, 1450),
        ('CA-LIN-BOL', 'Revestimiento (liner) del molino de bolas', 'UNIDAD', 'Metso', 'Outotec BM-L26', 'NO', 'SI', 'NO', 2650000, 9000, 'BOD-DES', 150, 100, 40, 820),
        ('CA-MAN-CHA', 'Manto del chancador giratorio primario', 'UNIDAD', 'Metso', 'Superior 60-89', 'NO', 'SI', 'NO', 21500000, 7000, 'BOD-DES', 260, 260, 220, 9200),
        ('CA-CON-CHA', 'Cóncavo del chancador giratorio primario', 'UNIDAD', 'Metso', 'Superior 60-89 C', 'NO', 'SI', 'NO', 18900000, 7000, 'BOD-DES', 280, 280, 120, 8100),
        ('CA-BOL-5', 'Bolas de acero forjado 5 pulgadas', 'KILOGRAMO', 'Moly-Cop', 'Forjada 5"', 'NO', 'SI', 'NO', 1450, None, 'BOD-DES', 100, 100, 100, 1000),
        ('CA-ROD-23240', 'Rodamiento esférico de rodillos 23240 CC/W33', 'UNIDAD', 'SKF', '23240 CC/W33', 'NO', 'NO', 'NO', 1850000, 30000, 'BOD-CEN', 60, 60, 25, 118),
        ('CA-ROD-22232', 'Rodamiento esférico de rodillos 22232 E', 'UNIDAD', 'FAG', '22232-E1-K', 'NO', 'NO', 'NO', 740000, 30000, 'BOD-CEN', 45, 45, 16, 38),
        ('CA-RODILLO-152', 'Rodillo de carga Ø152 mm para correa transportadora', 'UNIDAD', 'Rulmeca', 'PSV-152x1000', 'NO', 'SI', 'NO', 96000, 40000, 'BOD-DES', 110, 16, 16, 32),
        ('CA-BANDA-ST1600', 'Banda transportadora ST-1600 (por metro)', 'METRO', 'Fenner Dunlop', 'ST-1600 EP', 'NO', 'SI', 'NO', 430000, 60000, 'BOD-DES', 200, 160, 160, 38),
        ('CA-POL-TRAC', 'Polea tractora Ø800 con enlainado', 'UNIDAD', 'Continental', 'PT-800', 'NO', 'NO', 'SI', 9800000, None, 'BOD-DES', 120, 100, 100, 2300),
        ('CA-IMP-PULPA', 'Impulsor de bomba de pulpa 8x6', 'UNIDAD', 'Weir Minerals', 'Warman AH 8/6', 'NO', 'SI', 'SI', 3900000, 4500, 'BOD-DES', 80, 80, 50, 310),
        ('CA-LIN-PULPA', 'Revestimiento (liner) de bomba de pulpa', 'UNIDAD', 'Weir Minerals', 'Warman AH 8/6 LN', 'NO', 'SI', 'NO', 2700000, 4500, 'BOD-DES', 90, 90, 50, 240),
        ('CA-SEL-PULPA', 'Sello mecánico para bomba de pulpa', 'UNIDAD', 'John Crane', 'Type 5610', 'NO', 'SI', 'NO', 1250000, 6000, 'BOD-CEN', 25, 25, 20, 9),
        ('CA-MOT-250', 'Motor eléctrico trifásico 250 kW 6 kV 4 polos', 'UNIDAD', 'ABB', 'M3BM 400', 'NO', 'NO', 'SI', 28500000, 90000, 'BOD-CEN', 150, 80, 90, 2100),
        ('CA-VAR-500', 'Variador de frecuencia de media tensión 500 kW', 'UNIDAD', 'ABB', 'ACS1000', 'NO', 'NO', 'SI', 65000000, None, 'BOD-CEN', 200, 120, 220, 3800),
        ('CA-CON-MV', 'Contactor de media tensión 7,2 kV', 'UNIDAD', 'Siemens', '3TL6', 'NO', 'NO', 'NO', 3200000, None, 'BOD-CEN', 40, 35, 40, 24),
        ('CA-SEN-VIB', 'Sensor de vibración IEPE con cable', 'UNIDAD', 'SKF', 'CMSS 2200', 'NO', 'NO', 'NO', 215000, None, 'BOD-CEN', 12, 10, 10, 1),
        ('CA-SEN-NIV', 'Transmisor de nivel ultrasónico', 'UNIDAD', 'Endress+Hauser', 'Prosonic FMU90', 'NO', 'NO', 'NO', 1380000, None, 'BOD-CEN', 20, 15, 15, 3),
        ('CA-VAL-CUC', 'Válvula de cuchillo DN200 para pulpa', 'UNIDAD', 'Weir Minerals', 'Clarkson KGA', 'NO', 'NO', 'SI', 2400000, None, 'BOD-CEN', 60, 40, 40, 85),
        ('CA-MAN-HID', 'Manguera hidráulica de 2 pulgadas alta presión (por metro)', 'METRO', 'Gates', 'MegaSys 2"', 'NO', 'SI', 'NO', 62000, 12000, 'BOD-CEN', 100, 20, 20, 3),
        ('CA-ACE-HID', 'Aceite hidráulico ISO VG 46 (tambor 200 L)', 'LITRO', 'Shell', 'Tellus S2 M 46', 'SI', 'SI', 'NO', 3900, None, 'BOD-LUB', 60, 60, 90, 180),
        ('CA-ACE-ENG', 'Aceite para engranajes ISO VG 320 (tambor 200 L)', 'LITRO', 'Mobil', 'Mobilgear 600 XP 320', 'SI', 'SI', 'NO', 4800, None, 'BOD-LUB', 60, 60, 90, 185),
        ('CA-GRA-EP2', 'Grasa EP-2 base litio cartucho 400 g', 'UNIDAD', 'Klüber', 'Centoplex 2 EP', 'SI', 'SI', 'NO', 6900, None, 'BOD-LUB', 5, 5, 25, 0.5),
        ('CA-QUI-XAN', 'Xantato amílico de potasio (tambor 200 kg)', 'KILOGRAMO', 'Qiborax', 'PAX Premium', 'SI', 'SI', 'NO', 2350, None, 'BOD-LUB', 60, 60, 90, 200),
    ]
    filas = [[c, n, u, f, m, lo, co, re, costo, vida, None, None, None, 'SI', None, None, la, an, al, pe]
             for (c, n, u, f, m, lo, co, re, costo, vida, b, la, an, al, pe) in R]
    llenar(wb, 'REPUESTOS', filas)
    # minimo, maximo, reposicion, cantidad inicial, indice de rack
    Q = {
        'CA-LIN-SAG': (2, 6, 3, 4, 0), 'CA-LIN-BOL': (4, 12, 6, 8, 1), 'CA-MAN-CHA': (1, 2, 1, 1, 2), 'CA-CON-CHA': (1, 2, 1, 1, 2),
        'CA-BOL-5': (20000, 80000, 40000, 52000, 0), 'CA-ROD-23240': (1, 3, 2, 2, 0), 'CA-ROD-22232': (2, 5, 3, 3, 0),
        'CA-RODILLO-152': (20, 120, 50, 85, 1), 'CA-BANDA-ST1600': (30, 120, 60, 80, 2), 'CA-POL-TRAC': (1, 2, 1, 1, 2),
        'CA-IMP-PULPA': (1, 3, 2, 2, 1), 'CA-LIN-PULPA': (2, 6, 3, 4, 1), 'CA-SEL-PULPA': (2, 6, 3, 4, 1),
        'CA-MOT-250': (1, 2, 1, 1, 4), 'CA-VAR-500': (1, 1, 1, 1, 5), 'CA-CON-MV': (2, 4, 2, 3, 2),
        'CA-SEN-VIB': (4, 12, 6, 9, 3), 'CA-SEN-NIV': (1, 3, 2, 2, 3), 'CA-VAL-CUC': (1, 3, 2, 2, 5), 'CA-MAN-HID': (20, 80, 40, 55, 3),
        'CA-ACE-HID': (400, 2000, 800, 1200, 0), 'CA-ACE-ENG': (400, 2000, 800, 1000, 1), 'CA-GRA-EP2': (24, 120, 48, 72, 2), 'CA-QUI-XAN': (400, 2400, 1200, 1600, 2),
    }
    vence = {'CA-ACE-HID': D(2028, 6, 30), 'CA-ACE-ENG': D(2028, 9, 30), 'CA-GRA-EP2': D(2028, 3, 31), 'CA-QUI-XAN': D(2027, 12, 31)}
    racks_de = {
        'BOD-CEN': ['Pasillo A · Rack 01', 'Pasillo A · Rack 02', 'Pasillo A · Rack 03', 'Pasillo A · Rack 04', 'Pasillo B · Rack 01', 'Pasillo B · Rack 02'],
        'BOD-DES': ['Pasillo A · Rack 01', 'Pasillo A · Rack 02', 'Pasillo A · Rack 03'],
        'BOD-LUB': ['Pasillo A · Rack 01', 'Pasillo A · Rack 02', 'Pasillo A · Rack 03'],
    }
    umbr, stock = [], []
    for (c, n, u, f, m, lo, co, re, costo, vida, bod, la, an, al, pe) in R:
        mn, mx, rp, cant, ri = Q[c]
        umbr.append([c, bod, mn, mx, rp, None])
        stock.append([c, bod, racks_de[bod][ri], cant, costo, ('LOTE-2026-' + c[-3:]) if c in vence else None, vence.get(c), 'Stock inicial al implementar SIGMA'])
    llenar(wb, 'UMBRALES', umbr)
    llenar(wb, 'STOCK INICIAL', stock)
    llenar(wb, 'COMPATIBILIDADES', [])
    guardar(wb, '1_Carga_Inventario_Codelco.xlsx', 'Demostración: Codelco · Concentradora Cerro Alto (datos inventados).')


# ====================================================================== ACTIVOS
def activos():
    wb = abrir('ACTIVOS')
    # codigo, nombre, area, tipo, modelo, marca, serie, estado, criticidad, depende, anio, puesta, descripcion
    A = [
        ('CA-CHA-01', 'Chancador giratorio primario 60-89', 'CHA', 'Chancador', 'Superior 60-89', 'Metso', 'SN-CH-60891', 'Operativo', 'Crítica', None, 2018, D(2018, 5, 14), 'Chancador giratorio de 60x89 pulgadas, primera etapa de reducción del mineral'),
        ('CA-ALI-01', 'Alimentador de placas del chancador primario', 'CHA', 'Alimentador', 'AP-2400', 'Metso', 'SN-AL-2210', 'Operativo', 'Alta', 'CA-CHA-01', 2018, D(2018, 5, 14), 'Alimentador de placas que regula la entrega de mineral al chancador'),
        ('CA-CV-101', 'Correa transportadora CV-101 de mineral chancado', 'CHA', 'Correa transportadora', 'CV-1600', 'Fenner Dunlop', 'SN-CV-1010', 'Operativo', 'Crítica', None, 2018, D(2018, 6, 2), 'Correa de 1.600 mm de ancho que lleva el mineral chancado hacia el acopio'),
        ('CA-SUB-01', 'Subestación eléctrica 23 kV / 6,6 kV', 'CHA', 'Subestación', 'SE-23/6.6', 'ABB', 'SN-SE-0231', 'Operativo', 'Crítica', None, 2018, D(2018, 4, 20), 'Subestación que alimenta chancado y molienda'),
        ('CA-SAG-01', 'Molino SAG 36x19 pies', 'MOL', 'Molino', 'SAG 36x19', 'Metso', 'SN-SG-3619', 'Operativo', 'Crítica', None, 2018, D(2018, 8, 30), 'Molino semiautógeno de 36 pies de diámetro, 19 pies de largo'),
        ('CA-BOL-01', 'Molino de bolas 26x40 pies', 'MOL', 'Molino', 'BM 26x40', 'Metso', 'SN-BM-2640', 'Operativo', 'Crítica', None, 2018, D(2018, 9, 18), 'Molino de bolas en circuito cerrado con hidrociclones'),
        ('CA-BOM-SAG', 'Bomba de pulpa de descarga del molino SAG', 'MOL', 'Bomba de pulpa', 'Warman AH 8/6', 'Weir Minerals', 'SN-BP-8061', 'Operativo', 'Alta', 'CA-SAG-01', 2018, D(2018, 9, 1), 'Bomba centrífuga de pulpa hacia la batería de hidrociclones'),
        ('CA-FLO-R1', 'Celda de flotación rougher 300 m3', 'FLO', 'Celda de flotación', 'TC-300', 'Metso', 'SN-FL-3001', 'Operativo', 'Alta', None, 2019, D(2019, 2, 11), 'Celda de flotación primaria de 300 m3'),
        ('CA-SOP-FLO', 'Soplador de aire de las celdas de flotación', 'FLO', 'Soplador', 'ZS-90', 'Aerzen', 'SN-SP-9012', 'Operativo con observación', 'Alta', 'CA-FLO-R1', 2019, D(2019, 2, 11), 'Entrega el aire de las celdas; presenta vibración sobre el promedio'),
        ('CA-BOM-CON', 'Bomba de concentrado de cobre', 'FLO', 'Bomba de pulpa', 'Warman AH 6/4', 'Weir Minerals', 'SN-BP-6042', 'Operativo', 'Alta', None, 2019, D(2019, 2, 20), 'Envía el concentrado hacia el espesador'),
        ('CA-ESP-01', 'Espesador de relaves de 90 metros', 'REL', 'Espesador', 'HRT-90', 'FLSmidth', 'SN-ES-9001', 'Operativo', 'Crítica', None, 2019, D(2019, 4, 8), 'Espesador de alta tasa; recupera agua del relave'),
        ('CA-BOM-REL', 'Bomba de relaves del espesador', 'REL', 'Bomba de pulpa', 'Warman AH 10/8', 'Weir Minerals', 'SN-BP-1081', 'Operativo', 'Alta', 'CA-ESP-01', 2019, D(2019, 4, 8), 'Impulsa los relaves espesados al depósito'),
    ]
    llenar(wb, 'ACTIVOS', [[c, n, PLANTA, ar, t, m, mar, s, e, cr, None, dep, an, pu, 'SI', ds] for (c, n, ar, t, m, mar, s, e, cr, dep, an, pu, ds) in A])

    T = [
        ('CA-CHA-01', 'Potencia del motor', '1000', 'KW'), ('CA-CHA-01', 'Voltaje', '6.6', 'KV'), ('CA-CHA-01', 'Capacidad nominal', '4.500 t/h', None),
        ('CA-ALI-01', 'Potencia', '90', 'KW'), ('CA-ALI-01', 'Voltaje', '440', 'V'),
        ('CA-CV-101', 'Potencia', '250', 'KW'), ('CA-CV-101', 'Largo', '1800', 'METRO'), ('CA-CV-101', 'Ancho de banda', '1600', 'MM'), ('CA-CV-101', 'Velocidad de la banda', '4.2', 'MMS'),
        ('CA-SUB-01', 'Voltaje primario', '23', 'KV'), ('CA-SUB-01', 'Voltaje secundario', '6.6', 'KV'),
        ('CA-SAG-01', 'Potencia instalada', '20000', 'KW'), ('CA-SAG-01', 'Velocidad de giro', '10.5', 'RPM'), ('CA-SAG-01', 'Voltaje', '6.6', 'KV'), ('CA-SAG-01', 'Carga de bolas', '12 %', None),
        ('CA-BOL-01', 'Potencia instalada', '15000', 'KW'), ('CA-BOL-01', 'Velocidad de giro', '12.8', 'RPM'), ('CA-BOL-01', 'Voltaje', '6.6', 'KV'),
        ('CA-BOM-SAG', 'Potencia', '250', 'KW'), ('CA-BOM-SAG', 'Caudal', '1800', 'M3H'), ('CA-BOM-SAG', 'Presión de descarga', '3', 'BAR'),
        ('CA-FLO-R1', 'Volumen', '300', 'M3'), ('CA-FLO-R1', 'Potencia del agitador', '110', 'KW'),
        ('CA-SOP-FLO', 'Caudal de aire', '7200', 'M3H'), ('CA-SOP-FLO', 'Potencia', '90', 'KW'), ('CA-SOP-FLO', 'Velocidad', '2980', 'RPM'),
        ('CA-BOM-CON', 'Potencia', '75', 'KW'), ('CA-BOM-CON', 'Caudal', '320', 'M3H'),
        ('CA-ESP-01', 'Diámetro', '90', 'METRO'), ('CA-ESP-01', 'Potencia del rastrillo', '45', 'KW'),
        ('CA-BOM-REL', 'Potencia', '315', 'KW'), ('CA-BOM-REL', 'Caudal', '2400', 'M3H'),
    ]
    llenar(wb, 'DATOS TECNICOS', [list(t) for t in T])

    # activo, nombre, que_es, donde_va, criticidad, fecha, descripcion
    C = [
        ('CA-CHA-01', 'Motor principal', 'Motor', 'Único', 'Crítica', D(2018, 5, 14), 'Motor síncrono de 1.000 kW'),
        ('CA-CHA-01', 'Rodamiento del eje principal', 'Rodamiento', 'Inferior', 'Crítica', D(2018, 5, 14), None),
        ('CA-CHA-01', 'Sensor de vibración', 'Sensor', 'Superior', 'Alta', D(2018, 5, 14), None),
        ('CA-ALI-01', 'Motorreductor', 'Reductor', 'Central', 'Alta', D(2018, 5, 14), None),
        ('CA-CV-101', 'Motor de accionamiento', 'Motor', 'Lado motor', 'Crítica', D(2018, 6, 2), None),
        ('CA-CV-101', 'Polea tractora', 'Polea', 'Lado motor', 'Crítica', D(2018, 6, 2), None),
        ('CA-CV-101', 'Rodamiento de la polea tractora', 'Rodamiento', 'Lado motor', 'Crítica', D(2018, 6, 2), None),
        ('CA-CV-101', 'Reductor principal', 'Reductor', 'Lado acople', 'Alta', D(2018, 6, 2), None),
        ('CA-SUB-01', 'Transformador de poder', 'Otro', 'Central', 'Crítica', D(2018, 4, 20), None),
        ('CA-SUB-01', 'Tablero de media tensión', 'Tablero', 'Derecha', 'Crítica', D(2018, 4, 20), None),
        ('CA-SAG-01', 'Motor del molino', 'Motor', 'Lado motor', 'Crítica', D(2018, 8, 30), 'Motor anular sin engranajes'),
        ('CA-SAG-01', 'Cojinete de entrada', 'Rodamiento', 'Entrada', 'Crítica', D(2018, 8, 30), None),
        ('CA-SAG-01', 'Cojinete de descarga', 'Rodamiento', 'Salida', 'Crítica', D(2018, 8, 30), None),
        ('CA-SAG-01', 'Sistema de lubricación', 'Bomba', 'Inferior', 'Alta', D(2018, 8, 30), None),
        ('CA-BOL-01', 'Motor del molino', 'Motor', 'Lado motor', 'Crítica', D(2018, 9, 18), None),
        ('CA-BOL-01', 'Cojinete de descarga', 'Rodamiento', 'Salida', 'Crítica', D(2018, 9, 18), None),
        ('CA-BOM-SAG', 'Motor de la bomba', 'Motor', 'Lado motor', 'Alta', D(2018, 9, 1), None),
        ('CA-BOM-SAG', 'Impulsor', 'Otro', 'Central', 'Alta', D(2018, 9, 1), None),
        ('CA-BOM-SAG', 'Sello mecánico', 'Retén', 'Lado acople', 'Alta', D(2018, 9, 1), None),
        ('CA-FLO-R1', 'Motor del agitador', 'Motor', 'Superior', 'Alta', D(2019, 2, 11), None),
        ('CA-FLO-R1', 'Sensor de nivel', 'Sensor', 'Superior', 'Media', D(2019, 2, 11), None),
        ('CA-SOP-FLO', 'Motor del soplador', 'Motor', 'Lado motor', 'Alta', D(2019, 2, 11), None),
        ('CA-SOP-FLO', 'Rodamiento lado motor', 'Rodamiento', 'Lado motor', 'Alta', D(2019, 2, 11), None),
        ('CA-SOP-FLO', 'Acople elástico', 'Acople', 'Central', 'Media', D(2019, 2, 11), None),
        ('CA-BOM-CON', 'Motor de la bomba', 'Motor', 'Lado motor', 'Media', D(2019, 2, 20), None),
        ('CA-BOM-CON', 'Sello mecánico', 'Retén', 'Lado acople', 'Media', D(2019, 2, 20), None),
        ('CA-ESP-01', 'Motorreductor del rastrillo', 'Reductor', 'Superior', 'Crítica', D(2019, 4, 8), None),
        ('CA-ESP-01', 'Sensor de nivel de la cama de lodos', 'Sensor', 'Central', 'Alta', D(2019, 4, 8), None),
        ('CA-BOM-REL', 'Motor de la bomba', 'Motor', 'Lado motor', 'Alta', D(2019, 4, 8), None),
        ('CA-BOM-REL', 'Impulsor', 'Otro', 'Central', 'Alta', D(2019, 4, 8), None),
    ]
    llenar(wb, 'COMPONENTES', [list(c) for c in C])

    # activo, componente, variable, unidad, min, max, advertencia, critico, frecuencia horas
    V = [
        ('CA-CHA-01', 'Rodamiento del eje principal', 'Temperatura del rodamiento', 'CELSIUS', 20, 90, 75, 85, 1),
        ('CA-CHA-01', 'Sensor de vibración', 'Vibración del chancador', 'MMS', 0, 12, 7, 10, 1),
        ('CA-CHA-01', 'Motor principal', 'Corriente del motor', 'A', 40, 130, 115, 125, 1),
        ('CA-CV-101', 'Rodamiento de la polea tractora', 'Temperatura del rodamiento de la polea', 'CELSIUS', 20, 85, 70, 80, 1),
        ('CA-SAG-01', 'Cojinete de entrada', 'Temperatura del cojinete de entrada', 'CELSIUS', 20, 70, 58, 65, 1),
        ('CA-SAG-01', 'Sistema de lubricación', 'Presión de aceite de lubricación', 'BAR', 1, 8, 7, 7.5, 1),
        ('CA-BOL-01', 'Cojinete de descarga', 'Temperatura del cojinete de descarga', 'CELSIUS', 20, 70, 58, 65, 1),
        ('CA-BOM-SAG', 'Motor de la bomba', 'Corriente de la bomba de pulpa', 'A', 10, 40, 34, 38, 1),
        ('CA-SOP-FLO', 'Rodamiento lado motor', 'Vibración del soplador', 'MMS', 0, 8, 4.5, 7.1, 1),
        ('CA-ESP-01', 'Sensor de nivel de la cama de lodos', 'Nivel de la cama de lodos', 'METRO', 1, 4, 3.2, 3.6, 1),
        ('CA-SUB-01', 'Transformador de poder', 'Temperatura del aceite del transformador', 'CELSIUS', 20, 105, 90, 100, 1),
    ]
    llenar(wb, 'VARIABLES', [list(v) for v in V])
    M = [
        ('CA-CHA-01', 'Horómetro', 'HORA', 41200, 'NO', None), ('CA-ALI-01', 'Horómetro', 'HORA', 38800, 'NO', None),
        ('CA-SAG-01', 'Horómetro', 'HORA', 52900, 'NO', None), ('CA-BOL-01', 'Horómetro', 'HORA', 51400, 'NO', None),
        ('CA-BOM-SAG', 'Horómetro', 'HORA', 47100, 'NO', None), ('CA-SOP-FLO', 'Horómetro', 'HORA', 36200, 'NO', None),
        ('CA-BOM-REL', 'Horómetro', 'HORA', 33800, 'NO', None),
    ]
    llenar(wb, 'MEDIDORES', [list(m) for m in M])
    P = [
        ('CA-CHA-01', 'Rodamiento del eje principal', 'CA-ROD-23240', 'Rodamiento del eje'),
        ('CA-CHA-01', 'Sensor de vibración', 'CA-SEN-VIB', None),
        ('CA-CHA-01', 'Motor principal', 'CA-MOT-250', 'Motor de referencia de la línea de chancado (revisar potencia)'),
        ('CA-CHA-01', None, 'CA-MAN-CHA', 'Manto de reposición'), ('CA-CHA-01', None, 'CA-CON-CHA', 'Cóncavo de reposición'),
        ('CA-CHA-01', None, 'CA-ACE-HID', 'Aceite hidráulico del sistema de ajuste'),
        ('CA-ALI-01', 'Motorreductor', 'CA-ACE-ENG', None), ('CA-ALI-01', None, 'CA-MAN-HID', None),
        ('CA-CV-101', 'Polea tractora', 'CA-POL-TRAC', None), ('CA-CV-101', 'Rodamiento de la polea tractora', 'CA-ROD-22232', None),
        ('CA-CV-101', None, 'CA-RODILLO-152', 'Rodillos de carga'), ('CA-CV-101', None, 'CA-BANDA-ST1600', 'Empalmes y reparaciones de banda'),
        ('CA-CV-101', 'Reductor principal', 'CA-ACE-ENG', None),
        ('CA-SUB-01', 'Tablero de media tensión', 'CA-CON-MV', None),
        ('CA-SAG-01', None, 'CA-LIN-SAG', 'Revestimiento de descarga'), ('CA-SAG-01', None, 'CA-BOL-5', 'Bolas de molienda'),
        ('CA-SAG-01', 'Cojinete de entrada', 'CA-GRA-EP2', None), ('CA-SAG-01', 'Sistema de lubricación', 'CA-ACE-ENG', None),
        ('CA-BOL-01', None, 'CA-LIN-BOL', None), ('CA-BOL-01', None, 'CA-BOL-5', None), ('CA-BOL-01', 'Cojinete de descarga', 'CA-GRA-EP2', None),
        ('CA-BOM-SAG', 'Impulsor', 'CA-IMP-PULPA', None), ('CA-BOM-SAG', None, 'CA-LIN-PULPA', None), ('CA-BOM-SAG', 'Sello mecánico', 'CA-SEL-PULPA', None),
        ('CA-FLO-R1', 'Sensor de nivel', 'CA-SEN-NIV', None), ('CA-FLO-R1', None, 'CA-QUI-XAN', 'Reactivo colector'), ('CA-FLO-R1', None, 'CA-VAL-CUC', None),
        ('CA-SOP-FLO', 'Rodamiento lado motor', 'CA-ROD-22232', None), ('CA-SOP-FLO', 'Motor del soplador', 'CA-SEN-VIB', None),
        ('CA-BOM-CON', 'Sello mecánico', 'CA-SEL-PULPA', None), ('CA-BOM-CON', None, 'CA-IMP-PULPA', None),
        ('CA-ESP-01', 'Sensor de nivel de la cama de lodos', 'CA-SEN-NIV', None), ('CA-ESP-01', 'Motorreductor del rastrillo', 'CA-ACE-ENG', None),
        ('CA-BOM-REL', 'Impulsor', 'CA-IMP-PULPA', None), ('CA-BOM-REL', None, 'CA-LIN-PULPA', None), ('CA-BOM-REL', None, 'CA-VAL-CUC', None),
        ('CA-BOM-REL', 'Motor de la bomba', 'CA-VAR-500', 'Variador de referencia (revisar potencia)'),
    ]
    llenar(wb, 'REPUESTOS COMPATIBLES', [list(p) for p in P])
    guardar(wb, '2_Carga_Activos_Codelco.xlsx', 'Demostración: Codelco · Concentradora Cerro Alto (datos inventados).')


# ====================================================================== MANTENIMIENTO
def mantenimiento():
    wb = abrir('MANTENIMIENTO')
    F = {
        'CA Diaria (todos los días)': ('SEMANAL', 'LUN,MAR,MIE,JUE,VIE,SAB,DOM', None, None, None, '06:30'),
        'CA Semanal lunes y jueves': ('SEMANAL', 'LUN,JUE', None, None, None, '07:30'),
        'CA Mensual día 5': ('MENSUAL', None, 5, None, None, '08:00'),
        'CA Cada 15 días': ('CADA', None, None, 15, 'DIA', '08:00'),
        'CA Cada 3 meses': ('CADA', None, None, 3, 'MES', '08:00'),
        'CA Cada 6 meses': ('CADA', None, None, 6, 'MES', '08:00'),
    }
    llenar(wb, 'FRECUENCIAS', [[n, t, d, dm, c, u, h, None] for n, (t, d, dm, c, u, h) in F.items()])
    # codigo, titulo, descripcion, prioridad, duracion, evidencia, categoria, area, equipo
    T = [
        ('CA-T01', 'Revisar nivel y presión del aceite de lubricación del molino SAG', 'Leer el manómetro y el nivel del estanque; registrar si hay fuga en las líneas.', 'Alta', 20, 'NO', 'Lubricación', 'MOL', 'CA-SAG-01'),
        ('CA-T02', 'Inspección de rodillos y estado de la banda de la correa CV-101', 'Recorrer la correa buscando rodillos trabados, daños en la banda y derrames.', 'Media', 60, 'SI', 'Inspección', 'CHA', 'CA-CV-101'),
        ('CA-T03', 'Prueba de paradas de emergencia y cordones de la correa CV-101', 'Accionar cada cordón de emergencia y confirmar que la correa se detiene.', 'Alta', 30, 'SI', 'Seguridad', 'CHA', 'CA-CV-101'),
        ('CA-T04', 'Verificar sellos y fugas de las bombas de pulpa', 'Revisar el sello de cada bomba y el estado de las mangueras de agua de sello.', 'Media', 25, 'NO', 'Inspección', 'MOL', None),
        ('CA-T05', 'Toma de muestras de aceite del reductor del alimentador', 'Tomar muestra en la válvula de muestreo y enviarla al laboratorio.', 'Baja', 20, 'NO', 'Lubricación', 'CHA', 'CA-ALI-01'),
        ('CA-T06', 'Limpieza y orden del área de espesadores', 'Retirar derrames y despejar las vías de acceso a la pasarela.', 'Baja', 40, 'NO', 'Aseo y orden', 'REL', 'CA-ESP-01'),
    ]
    llenar(wb, 'TAREAS', [[c, t, d, p, du, ev, cat, PLANTA, ar, eq, 'SI'] for (c, t, d, p, du, ev, cat, ar, eq) in T])
    llenar(wb, 'TAREAS PROGRAMADAS', [
        ['CA-T01', 'CA Diaria (todos los días)', None, None], ['CA-T02', 'CA Semanal lunes y jueves', None, None],
        ['CA-T03', 'CA Mensual día 5', None, None], ['CA-T04', 'CA Semanal lunes y jueves', None, None],
        ['CA-T05', 'CA Cada 3 meses', None, None], ['CA-T06', 'CA Cada 15 días', None, None],
    ])
    llenar(wb, 'CHECKLISTS', [
        ['CA-CHK-CHA', 'Ronda de inspección del chancado primario', 'Ronda por turno del chancador, el alimentador y la correa CV-101.', PLANTA, 'Chancador', 'SI'],
        ['CA-CHK-MOL', 'Ronda de molienda y flotación', 'Ronda por turno del molino SAG, la bomba de pulpa y las celdas de flotación.', PLANTA, None, 'SI'],
    ])
    I = [
        ('CA-CHK-CHA', 'Seguridad', '¿Resguardos, cordones de emergencia y bloqueos en su lugar?', 'Sí / No', None),
        ('CA-CHK-CHA', 'Chancador', 'Temperatura del rodamiento del eje principal', 'Medición', 'CELSIUS'),
        ('CA-CHK-CHA', 'Chancador', 'Corriente del motor', 'Medición', 'A'),
        ('CA-CHK-CHA', 'Chancador', '¿Se escuchan golpes o ruidos anormales?', 'Sí / No', None),
        ('CA-CHK-CHA', 'Correa CV-101', '¿La banda corre centrada y sin derrames?', 'Sí / No', None),
        ('CA-CHK-CHA', 'Correa CV-101', 'Foto del estado de la polea tractora', 'Fotografía', None),
        ('CA-CHK-CHA', 'Correa CV-101', 'Observaciones generales', 'Texto largo', None),
        ('CA-CHK-MOL', 'Molino SAG', 'Presión de aceite de lubricación', 'Medición', 'BAR'),
        ('CA-CHK-MOL', 'Molino SAG', 'Temperatura del cojinete de entrada', 'Medición', 'CELSIUS'),
        ('CA-CHK-MOL', 'Molino SAG', '¿Hay fugas de aceite en las líneas?', 'Sí / No', None),
        ('CA-CHK-MOL', 'Flotación', 'Nivel de la celda rougher', 'Medición', 'METRO'),
        ('CA-CHK-MOL', 'Flotación', '¿La espuma tiene el aspecto normal?', 'Sí / No', None),
        ('CA-CHK-MOL', 'Flotación', 'Foto de la superficie de la celda', 'Fotografía', None),
    ]
    llenar(wb, 'CHECKLIST ITEMS', [[c, s, None, tx, tp, None, 'SI', 'SI', 'SI' if tp == 'Fotografía' else 'NO', u] for (c, s, tx, tp, u) in I])
    llenar(wb, 'CHECKLISTS PROGRAMADOS', [
        ['CA-CHK-CHA', 'CA Diaria (todos los días)', 'CA-CHA-01', None, None, None, None],
        ['CA-CHK-MOL', 'CA Diaria (todos los días)', 'CA-SAG-01', None, None, None, None],
        ['CA-CHK-MOL', 'CA Diaria (todos los días)', 'CA-FLO-R1', None, None, None, None],
    ])
    llenar(wb, 'PLANES', [
        ['CA-PM-SAG', 'Plan preventivo del molino SAG', 'Lubricación quincenal, inspección mensual y revisión mayor semestral del molino SAG.', PLANTA, None, 'Molino', None, 'NO'],
        ['CA-PM-CV', 'Plan preventivo de la correa CV-101', 'Inspección, lubricación y cambio de rodillos de la correa de mineral chancado.', PLANTA, None, 'Correa transportadora', None, 'NO'],
    ])
    # plan, codigo, nombre, orden, frecuencia, duracion, parada, overhaul, tipo_ot, prioridad_ot, responsable, grupo, descripcion
    H = [
        ('CA-PM-SAG', 'H1', 'Lubricación de cojinetes y piñón', 1, 'CA Cada 15 días', 90, 'NO', 'NO', 'Preventiva', 'Alta', 'Engrase de cojinetes de entrada y descarga y del sistema de lubricación.'),
        ('CA-PM-SAG', 'H2', 'Inspección mensual de revestimientos y pernos', 2, 'CA Mensual día 5', 180, 'SI', 'NO', 'Preventiva', 'Alta', 'Medición del desgaste de liners y reapriete de pernos.'),
        ('CA-PM-SAG', 'H3', 'Revisión mayor semestral', 3, 'CA Cada 6 meses', 720, 'SI', 'SI', 'Preventiva', 'Crítica', 'Detención programada del molino para cambio de revestimientos y revisión de cojinetes.'),
        ('CA-PM-CV', 'H1', 'Inspección y limpieza de la correa', 1, 'CA Semanal lunes y jueves', 60, 'NO', 'NO', 'Preventiva', 'Media', 'Recorrido de la correa, limpieza de rascadores y revisión de rodillos.'),
        ('CA-PM-CV', 'H2', 'Cambio de rodillos y revisión de la polea tractora', 2, 'CA Cada 3 meses', 240, 'SI', 'NO', 'Preventiva', 'Alta', 'Recambio de rodillos gastados y revisión del enlainado de la polea.'),
    ]
    llenar(wb, 'HITOS', [[p, c, n, o, f, d, pa, ov, to, po, None, None, ds] for (p, c, n, o, f, d, pa, ov, to, po, ds) in H])
    # plan, hito, codigo, nombre, descripcion, orden, duracion, obligatoria, parada
    A = [
        ('CA-PM-SAG', 'H1', 'Bloquear y señalizar el equipo antes de engrasar', 'Aplicar bloqueo y etiquetado (LOTO).', 10, 'SI', 'NO'),
        ('CA-PM-SAG', 'H1', 'Engrasar los cojinetes de entrada y descarga', None, 40, 'SI', 'NO'),
        ('CA-PM-SAG', 'H1', 'Revisar nivel y filtros del sistema de lubricación', None, 40, 'SI', 'NO'),
        ('CA-PM-SAG', 'H2', 'Medir el espesor de los revestimientos', None, 90, 'SI', 'SI'),
        ('CA-PM-SAG', 'H2', 'Reapretar pernos de los revestimientos', None, 90, 'SI', 'SI'),
        ('CA-PM-SAG', 'H3', 'Cambiar los revestimientos de descarga', None, 360, 'SI', 'SI'),
        ('CA-PM-SAG', 'H3', 'Revisar el estado de los cojinetes', None, 240, 'SI', 'SI'),
        ('CA-PM-CV', 'H1', 'Limpiar rascadores y zona de carga', None, 30, 'SI', 'NO'),
        ('CA-PM-CV', 'H1', 'Revisar rodillos trabados y el centrado de la banda', None, 30, 'SI', 'NO'),
        ('CA-PM-CV', 'H2', 'Cambiar los rodillos con desgaste', None, 150, 'SI', 'SI'),
        ('CA-PM-CV', 'H2', 'Revisar el enlainado de la polea tractora', None, 90, 'SI', 'SI'),
    ]
    llenar(wb, 'ACTIVIDADES', [[p, h, None, n, d, i + 1, du, ob, pa] for i, (p, h, n, d, du, ob, pa) in enumerate(A)])
    llenar(wb, 'EQUIPOS', [
        ['CA-PM-SAG', 'CA-SAG-01', None, 'Horómetro'], ['CA-PM-SAG', 'CA-BOL-01', None, 'Horómetro'],
        ['CA-PM-CV', 'CA-CV-101', None, None],
    ])
    guardar(wb, '3_Carga_Mantenimiento_Codelco.xlsx', 'Demostración: Codelco · Concentradora Cerro Alto (datos inventados).')


def activos_con_errores():
    """Archivo corto para mostrar cómo SIGMA explica los errores antes de escribir nada."""
    wb = abrir('ACTIVOS')
    llenar(wb, 'ACTIVOS', [
        ['CA-DEMO-OK-01', 'Chancador secundario de prueba', PLANTA, 'CHA', 'Chancador', None, 'Metso', 'SN-DM-0001', 'Operativo', 'Alta', None, None, 2022, D(2022, 5, 10), 'SI', 'Fila correcta'],
        ['CA-DEMO-OK-02', 'Correa de transferencia de prueba', PLANTA, 'CHA', 'Correa transportadora', None, 'Fenner Dunlop', 'SN-DM-0002', 'Operativo', 'Media', None, 'CA-DEMO-OK-01', 2022, D(2022, 5, 10), 'SI', 'Fila correcta (depende de la anterior)'],
        ['CA-DEMO-ERR-01', 'Molino de prueba', 'Planta Los Bronces', 'MOL', 'Molino', None, None, None, 'Operativo', 'Alta', None, None, 2021, D(2021, 1, 10), 'SI', 'Error: la planta no existe'],
        ['CA-DEMO-ERR-02', 'Bomba de prueba', PLANTA, 'MOL', 'Bomba de pulpa', None, None, None, 'Operativo', 'Extrema', None, None, 2021, D(2021, 1, 10), 'SI', 'Error: la criticidad no existe'],
        ['CA-DEMO-ERR-03', 'Espesador de prueba', PLANTA, 'REL', 'Espesador', None, None, None, 'Operativo', 'Media', None, 'CA-NO-EXISTE', 2090, D(2090, 1, 1), 'SI', 'Error: año y fecha futuros, y el activo padre no existe'],
        [None, 'Celda de prueba', PLANTA, 'FLO', None, None, None, None, 'Operativo', 'Media', None, None, None, None, 'SI', 'Error: falta el tipo de activo'],
    ])
    llenar(wb, 'DATOS TECNICOS', [['CA-DEMO-OK-01', 'Potencia', '400', 'KW'], ['CA-DEMO-ERR-02', 'Potencia', '150', 'KW']])
    llenar(wb, 'COMPONENTES', [['CA-DEMO-OK-01', 'Motor principal', 'Motor', 'Único', 'Media', None, None]])
    llenar(wb, 'VARIABLES', [])
    llenar(wb, 'MEDIDORES', [['CA-DEMO-OK-01', 'Horómetro', 'HORA', 100, 'NO', None]])
    llenar(wb, 'REPUESTOS COMPATIBLES', [])
    guardar(wb, '2b_Activos_con_errores_para_mostrar.xlsx', 'Archivo con errores a propósito, solo para mostrar la revisión; no se carga.')


if __name__ == '__main__':
    inventario()
    activos()
    mantenimiento()
    activos_con_errores()
