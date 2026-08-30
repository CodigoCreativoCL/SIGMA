# -*- coding: utf-8 -*-
"""
INTERFAZ GRAFICA del generador de mantenedores.

Aplicacion de escritorio (Tkinter, incluido en Python: no hay que instalar nada).
Usa exactamente el mismo motor que la version de consola: nucleo/ + plantillas/.

    pythonw interfaz.py        (sin ventana negra)
    python  interfaz.py        (con consola, para ver errores)
    GENERADOR.bat              (doble clic)
"""

import json
import os
import subprocess
import sys
import traceback

RAIZ = os.path.dirname(os.path.abspath(__file__))
if RAIZ not in sys.path:
    sys.path.insert(0, RAIZ)

try:
    import tkinter as tk
    from tkinter import ttk, filedialog, messagebox, scrolledtext
except ImportError:                                    # pragma: no cover
    sys.stderr.write('Tkinter no esta disponible en esta instalacion de Python.\n')
    raise

from nucleo import definicion as defmod
from nucleo import piezas as piezasmod
from nucleo import util
from nucleo.tipos import Tipo, tipos_soportados, CONTROLES_VALIDOS
import generar as motor


# ===========================================================================
# CONSTANTES DE UI
# ===========================================================================
TIPOS_COMUNES = [
    'NVARCHAR(50)', 'NVARCHAR(100)', 'NVARCHAR(200)', 'NVARCHAR(MAX)',
    'INT', 'BIGINT', 'BIT', 'DECIMAL(18,2)', 'MONEY',
    'DATE', 'DATETIME', 'VARCHAR(20)', 'UNIQUEIDENTIFIER',
]

CONTROLES = ['(auto)'] + list(CONTROLES_VALIDOS)
TRIESTADO = ['(auto)', 'Si', 'No']

COLOR_FONDO = '#f4f6f8'
COLOR_CABECERA = '#1f3a5f'
COLOR_OK = '#1a7f37'
COLOR_SKIP = '#9a6700'
COLOR_ERROR = '#b42318'


def _tri_a_valor(texto):
    """'(auto)' -> None, 'Si' -> True, 'No' -> False."""
    if texto == 'Si':
        return True
    if texto == 'No':
        return False
    return None


def _valor_a_tri(valor):
    if valor is True:
        return 'Si'
    if valor is False:
        return 'No'
    return '(auto)'


# ===========================================================================
# DIALOGO DE COLUMNA
# ===========================================================================
class DialogoColumna(tk.Toplevel):
    """Alta/edicion de una columna. Devuelve un dict listo para el JSON."""

    def __init__(self, padre, columna=None, prefijo='XXX'):
        tk.Toplevel.__init__(self, padre)
        self.transient(padre)
        self.resultado = None
        self.prefijo = prefijo

        self.title('Columna' if columna is None else 'Editar columna')
        self.configure(bg=COLOR_FONDO)
        self.resizable(False, False)

        datos = dict(columna or {})
        fk = dict(datos.get('fk') or {})

        cont = ttk.Frame(self, padding=12)
        cont.pack(fill='both', expand=True)

        # ------------------------------------------------------- basicos
        caja = ttk.LabelFrame(cont, text=' Datos de la columna ', padding=10)
        caja.grid(row=0, column=0, sticky='nsew', padx=(0, 8))

        self.v_nombre = tk.StringVar(value=datos.get('nombre', ''))
        self.v_tipo = tk.StringVar(value=datos.get('tipo', 'NVARCHAR(200)'))
        self.v_etiqueta = tk.StringVar(value=datos.get('etiqueta', ''))
        self.v_requerido = tk.BooleanVar(value=bool(datos.get('requerido', False)))
        self.v_control = tk.StringVar(value=datos.get('control', '(auto)'))
        self.v_unico = tk.BooleanVar(value=bool(datos.get('unico', False)))
        self.v_upper = tk.BooleanVar(value=bool(datos.get('upperCase', False)))
        self.v_lower = tk.BooleanVar(value=bool(datos.get('lowerCase', False)))

        f = 0
        ttk.Label(caja, text='Nombre (sin el prefijo %s_)' % prefijo).grid(row=f, column=0, sticky='w')
        e_nombre = ttk.Entry(caja, textvariable=self.v_nombre, width=30)
        e_nombre.grid(row=f + 1, column=0, sticky='we', pady=(0, 8))
        e_nombre.bind('<KeyRelease>', self._sugerir_etiqueta)

        f += 2
        ttk.Label(caja, text='Tipo SQL').grid(row=f, column=0, sticky='w')
        cb = ttk.Combobox(caja, textvariable=self.v_tipo, values=TIPOS_COMUNES, width=28)
        cb.grid(row=f + 1, column=0, sticky='we', pady=(0, 8))

        f += 2
        ttk.Label(caja, text='Etiqueta en pantalla').grid(row=f, column=0, sticky='w')
        ttk.Entry(caja, textvariable=self.v_etiqueta, width=30).grid(
            row=f + 1, column=0, sticky='we', pady=(0, 8))

        f += 2
        ttk.Label(caja, text='Control (auto = segun el tipo)').grid(row=f, column=0, sticky='w')
        ttk.Combobox(caja, textvariable=self.v_control, values=CONTROLES,
                     state='readonly', width=28).grid(row=f + 1, column=0, sticky='we', pady=(0, 8))

        f += 2
        ttk.Checkbutton(caja, text='Obligatorio (NOT NULL)',
                        variable=self.v_requerido).grid(row=f, column=0, sticky='w')
        ttk.Checkbutton(caja, text='Valor unico (indice UX_ + validacion en el SP)',
                        variable=self.v_unico).grid(row=f + 1, column=0, sticky='w')
        ttk.Checkbutton(caja, text='Convertir a MAYUSCULAS',
                        variable=self.v_upper).grid(row=f + 2, column=0, sticky='w')
        ttk.Checkbutton(caja, text='Convertir a minusculas',
                        variable=self.v_lower).grid(row=f + 3, column=0, sticky='w')

        # ------------------------------------------------------- avanzado
        caja2 = ttk.LabelFrame(cont, text=' Listado y filtros ', padding=10)
        caja2.grid(row=0, column=1, sticky='nsew')

        self.v_grid = tk.StringVar(value=_valor_a_tri(datos.get('grid')))
        self.v_busqueda = tk.StringVar(value=_valor_a_tri(datos.get('busqueda')))
        self.v_filtro = tk.StringVar(value=_valor_a_tri(datos.get('filtro')))
        self.v_indice = tk.StringVar(value=_valor_a_tri(datos.get('indice')))
        self.v_gancho = tk.StringVar(value=datos.get('gridAncho', ''))
        self.v_gtitulo = tk.StringVar(value=datos.get('gridTitulo', ''))
        self.v_icono = tk.StringVar(value=datos.get('icono', ''))
        self.v_defecto = tk.StringVar(value='' if datos.get('defecto') is None
                                      else str(datos.get('defecto')))

        for i, (txt, var, ayuda) in enumerate([
            ('Se muestra en el grid', self.v_grid, ''),
            ('Entra en la busqueda libre', self.v_busqueda, ''),
            ('Tiene filtro propio', self.v_filtro, ''),
            ('Crea indice IX_', self.v_indice, ''),
        ]):
            ttk.Label(caja2, text=txt).grid(row=i * 2, column=0, sticky='w')
            ttk.Combobox(caja2, textvariable=var, values=TRIESTADO,
                         state='readonly', width=12).grid(row=i * 2 + 1, column=0,
                                                          sticky='w', pady=(0, 6))

        ttk.Label(caja2, text='Ancho en el grid (ej. 20%)').grid(row=8, column=0, sticky='w')
        ttk.Entry(caja2, textvariable=self.v_gancho, width=14).grid(row=9, column=0, sticky='w', pady=(0, 6))

        ttk.Label(caja2, text='Encabezado del grid').grid(row=10, column=0, sticky='w')
        ttk.Entry(caja2, textvariable=self.v_gtitulo, width=20).grid(row=11, column=0, sticky='w', pady=(0, 6))

        ttk.Label(caja2, text='Icono FontAwesome (ej. fa-phone)').grid(row=12, column=0, sticky='w')
        ttk.Entry(caja2, textvariable=self.v_icono, width=20).grid(row=13, column=0, sticky='w', pady=(0, 6))

        ttk.Label(caja2, text='DEFAULT en la tabla (ej. 1)').grid(row=14, column=0, sticky='w')
        ttk.Entry(caja2, textvariable=self.v_defecto, width=14).grid(row=15, column=0, sticky='w')

        # ------------------------------------------------------- FK
        self.v_es_fk = tk.BooleanVar(value=bool(datos.get('fk')))
        self.caja_fk = ttk.LabelFrame(cont, text=' Relacion a otra tabla (FK) ', padding=10)
        self.caja_fk.grid(row=1, column=0, columnspan=2, sticky='nsew', pady=(10, 0))

        ttk.Checkbutton(self.caja_fk, text='Esta columna es una FK (genera combo, JOIN y columna de texto)',
                        variable=self.v_es_fk, command=self._toggle_fk).grid(
            row=0, column=0, columnspan=4, sticky='w', pady=(0, 8))

        self.v_fk = {}
        campos_fk = [
            ('tabla', 'Tabla referenciada', 0, 0),
            ('prefijo', 'Prefijo de esa tabla', 0, 1),
            ('columna', 'Columna PK', 0, 2),
            ('columnaTexto', 'Columna a mostrar', 0, 3),
            ('modelo', 'Clase Model', 1, 0),
            ('controller', 'Clase Controller', 1, 1),
            ('metodoLista', 'Metodo de listado', 1, 2),
            ('propTexto', 'DataTextField del combo', 1, 3),
        ]
        self.widgets_fk = []
        for clave, etiqueta, fila, col in campos_fk:
            ttk.Label(self.caja_fk, text=etiqueta).grid(
                row=1 + fila * 2, column=col, sticky='w', padx=(0, 8))
            var = tk.StringVar(value=fk.get(clave, ''))
            ent = ttk.Entry(self.caja_fk, textvariable=var, width=22)
            ent.grid(row=2 + fila * 2, column=col, sticky='we', padx=(0, 8), pady=(0, 6))
            self.v_fk[clave] = var
            self.widgets_fk.append(ent)

        ttk.Label(self.caja_fk, text='filtro_habilitado del Model referenciado').grid(
            row=5, column=0, columnspan=2, sticky='w')
        self.v_fk_hab = tk.StringVar(value=fk.get('filtroHabilitado', 'bool'))
        cb_hab = ttk.Combobox(self.caja_fk, textvariable=self.v_fk_hab,
                              values=['bool', 'string', 'none'], state='readonly', width=12)
        cb_hab.grid(row=6, column=0, sticky='w')
        self.widgets_fk.append(cb_hab)

        self.v_fk['tabla'].trace_add('write', lambda *_: self._sugerir_fk())

        # ------------------------------------------------------- botones
        barra = ttk.Frame(cont)
        barra.grid(row=2, column=0, columnspan=2, sticky='e', pady=(12, 0))
        ttk.Button(barra, text='Cancelar', command=self.destroy).pack(side='right', padx=(6, 0))
        ttk.Button(barra, text='Aceptar', command=self._aceptar).pack(side='right')

        self._toggle_fk()
        e_nombre.focus_set()
        self.bind('<Return>', lambda _: self._aceptar())
        self.bind('<Escape>', lambda _: self.destroy())

        self.grab_set()
        self.wait_window(self)

    # ------------------------------------------------------------------
    def _sugerir_etiqueta(self, _=None):
        if not self.v_etiqueta.get().strip():
            return
        # solo autocompleta si el usuario no la toco
        pass

    def _sugerir_fk(self):
        tabla = self.v_fk['tabla'].get().strip().upper()
        if not tabla:
            return
        sugerencias = {
            'prefijo': tabla[:3],
            'columna': tabla[:3] + '_ID',
            'columnaTexto': tabla[:3] + '_NOMBRE',
            'modelo': util.pascal(tabla),
            'controller': util.pascal(tabla) + 'Controller',
            'metodoLista': 'Get' + util.pascal(tabla) + 's',
        }
        for clave, valor in sugerencias.items():
            if not self.v_fk[clave].get().strip():
                self.v_fk[clave].set(valor)

    def _toggle_fk(self):
        estado = 'normal' if self.v_es_fk.get() else 'disabled'
        for w in self.widgets_fk:
            try:
                w.configure(state=estado if not isinstance(w, ttk.Combobox)
                            else ('readonly' if estado == 'normal' else 'disabled'))
            except tk.TclError:
                pass

    def _aceptar(self):
        nombre = self.v_nombre.get().strip().upper()
        if not nombre:
            messagebox.showwarning('Falta el nombre', 'La columna necesita un nombre.', parent=self)
            return

        tipo_txt = self.v_tipo.get().strip().upper() or 'NVARCHAR(200)'
        try:
            Tipo(tipo_txt)
        except ValueError as ex:
            messagebox.showerror('Tipo invalido', str(ex), parent=self)
            return

        col = {'nombre': nombre, 'tipo': tipo_txt}

        if self.v_requerido.get():
            col['requerido'] = True
        etiqueta = self.v_etiqueta.get().strip()
        if etiqueta and etiqueta != util.titulo(nombre):
            col['etiqueta'] = etiqueta
        if self.v_control.get() != '(auto)':
            col['control'] = self.v_control.get()
        if self.v_unico.get():
            col['unico'] = True
        if self.v_upper.get():
            col['upperCase'] = True
        if self.v_lower.get():
            col['lowerCase'] = True

        for clave, var in [('grid', self.v_grid), ('busqueda', self.v_busqueda),
                           ('filtro', self.v_filtro), ('indice', self.v_indice)]:
            valor = _tri_a_valor(var.get())
            if valor is not None:
                col[clave] = valor

        for clave, var in [('gridAncho', self.v_gancho), ('gridTitulo', self.v_gtitulo),
                           ('icono', self.v_icono)]:
            if var.get().strip():
                col[clave] = var.get().strip()

        if self.v_defecto.get().strip():
            bruto = self.v_defecto.get().strip()
            try:
                col['defecto'] = int(bruto)
            except ValueError:
                col['defecto'] = bruto

        if self.v_es_fk.get():
            tabla = self.v_fk['tabla'].get().strip().upper()
            if not tabla:
                messagebox.showwarning('Falta la tabla',
                                       'Indica la tabla referenciada por la FK.', parent=self)
                return
            fk = {'tabla': tabla}
            for clave, var in self.v_fk.items():
                if clave == 'tabla':
                    continue
                if var.get().strip():
                    fk[clave] = var.get().strip()
            fk['filtroHabilitado'] = self.v_fk_hab.get()
            col['fk'] = fk

        self.resultado = col
        self.destroy()


# ===========================================================================
# VENTANA PRINCIPAL
# ===========================================================================
class Aplicacion(tk.Tk):
    def __init__(self):
        tk.Tk.__init__(self)
        self.title('Generador de mantenedores')
        self.minsize(920, 620)
        self.configure(bg=COLOR_FONDO)
        self._dimensionar()

        self.columnas = []
        self.ruta_definicion = None
        self._campos_tocados = set()

        self._estilos()
        self._menu()
        self._cabecera()

        cuerpo = ttk.Frame(self, padding=(14, 10))
        cuerpo.pack(fill='both', expand=True)

        # Split arrastrable: en pantallas bajas el usuario achica el log
        # y el formulario sigue entrando completo.
        self.split = ttk.PanedWindow(cuerpo, orient='vertical')
        self.split.pack(fill='both', expand=True)

        arriba = ttk.Frame(self.split)
        abajo = ttk.Frame(self.split)
        self.split.add(arriba, weight=3)
        self.split.add(abajo, weight=1)

        self.nb = ttk.Notebook(arriba)
        self.nb.pack(fill='both', expand=True)
        self._tab_proyecto()
        self._tab_entidad()
        self._tab_columnas()
        self._tab_piezas()

        self._barra_inferior(abajo)
        self._log_inicial()

    # ------------------------------------------------------------------
    def _dimensionar(self):
        """Tamano inicial adaptado a la pantalla, y ventana centrada."""
        pantalla_w = self.winfo_screenwidth()
        pantalla_h = self.winfo_screenheight()

        ancho = min(1180, max(920, pantalla_w - 120))
        alto = min(920, max(620, pantalla_h - 140))

        x = max((pantalla_w - ancho) // 2, 0)
        y = max((pantalla_h - alto) // 2 - 20, 0)
        self.geometry('%dx%d+%d+%d' % (ancho, alto, x, y))

    def _estilos(self):
        s = ttk.Style(self)
        try:
            s.theme_use('vista')
        except tk.TclError:
            pass
        s.configure('TFrame', background=COLOR_FONDO)
        s.configure('TLabel', background=COLOR_FONDO)
        s.configure('TLabelframe', background=COLOR_FONDO)
        s.configure('TLabelframe.Label', background=COLOR_FONDO, foreground=COLOR_CABECERA)
        s.configure('TCheckbutton', background=COLOR_FONDO)
        s.configure('Cabecera.TLabel', background=COLOR_CABECERA, foreground='white')
        s.configure('Accion.TButton', padding=(14, 7))
        s.configure('Treeview', rowheight=24)

    def _menu(self):
        barra = tk.Menu(self)

        archivo = tk.Menu(barra, tearoff=0)
        archivo.add_command(label='Nueva definicion', command=self.nueva, accelerator='Ctrl+N')
        archivo.add_command(label='Abrir definicion...', command=self.abrir, accelerator='Ctrl+O')
        archivo.add_command(label='Guardar definicion...', command=self.guardar, accelerator='Ctrl+S')
        archivo.add_separator()
        archivo.add_command(label='Salir', command=self.destroy)
        barra.add_cascade(label='Archivo', menu=archivo)

        ejemplos = tk.Menu(barra, tearoff=0)
        carpeta = os.path.join(RAIZ, 'ejemplos')
        if os.path.isdir(carpeta):
            for nombre in sorted(os.listdir(carpeta)):
                if nombre.endswith('.json'):
                    ruta = os.path.join(carpeta, nombre)
                    ejemplos.add_command(label=nombre,
                                         command=lambda r=ruta: self.abrir(r))
        barra.add_cascade(label='Ejemplos', menu=ejemplos)

        ayuda = tk.Menu(barra, tearoff=0)
        ayuda.add_command(label='Como se usa', command=self._ayuda)
        ayuda.add_command(label='Tipos SQL soportados', command=self._ayuda_tipos)
        barra.add_cascade(label='Ayuda', menu=ayuda)

        self.config(menu=barra)
        self.bind('<Control-n>', lambda _: self.nueva())
        self.bind('<Control-o>', lambda _: self.abrir())
        self.bind('<Control-s>', lambda _: self.guardar())

    def _cabecera(self):
        cab = tk.Frame(self, bg=COLOR_CABECERA)
        cab.pack(fill='x')
        tk.Label(cab, text='  Generador de mantenedores', bg=COLOR_CABECERA, fg='white',
                 font=('Segoe UI', 15, 'bold')).pack(side='left', pady=10)
        tk.Label(cab, text='Tabla + SP + Model + Controller + vistas .aspx/.ascx   ',
                 bg=COLOR_CABECERA, fg='#b9c9dd',
                 font=('Segoe UI', 9)).pack(side='right', pady=14)

    # ------------------------------------------------------------------
    def _campo(self, padre, etiqueta, valor, fila, col, ancho=26, ayuda=None, clave=None):
        ttk.Label(padre, text=etiqueta).grid(row=fila, column=col, sticky='w', padx=(0, 10))
        var = tk.StringVar(value=valor)
        ent = ttk.Entry(padre, textvariable=var, width=ancho)
        ent.grid(row=fila + 1, column=col, sticky='we', padx=(0, 10), pady=(0, 4))
        if ayuda:
            ttk.Label(padre, text=ayuda, foreground='#667085',
                      font=('Segoe UI', 8)).grid(row=fila + 2, column=col, sticky='w', pady=(0, 6))
        if clave:
            ent.bind('<KeyRelease>', lambda _e, k=clave: self._campos_tocados.add(k))
        return var

    def _tab_proyecto(self):
        t = ttk.Frame(self.nb, padding=16)
        self.nb.add(t, text='  1. Proyecto  ')

        g = ttk.LabelFrame(t, text=' Configuracion comun (se guarda con la definicion) ', padding=14)
        g.pack(fill='x')
        for i in range(3):
            g.columnconfigure(i, weight=1)

        self.p_bd = self._campo(g, 'Base de datos', 'SIGMA', 0, 0,
                                ayuda='Va en el USE [..] de los .sql')
        self.p_ns = self._campo(g, 'Namespace raiz', 'Sigma', 0, 1,
                                ayuda='Genera <ns>.Model y <ns>.Controller')
        self.p_autor = self._campo(g, 'Autor', 'EQUIPO CODIGO CREATIVO', 0, 2,
                                   ayuda='Encabezado AUTHOR de cada SP')

        self.p_appcode = self._campo(g, 'Ruta App_Code', 'App_Code/MVC/Sigma', 3, 0)
        self.p_view = self._campo(g, 'Ruta View', 'View', 3, 1)
        self.p_master = self._campo(g, 'MasterPage', '~/Master/Default.master', 3, 2)

        self.p_filtro = self._campo(g, 'UserControl de filtros', 6, 0, ancho=40) \
            if False else None
        ttk.Label(g, text='UserControl de la barra de filtros').grid(row=6, column=0, sticky='w')
        self.p_filtro = tk.StringVar(value='~/View/Comun/Controls/FiltroAvanzado.ascx')
        ttk.Entry(g, textvariable=self.p_filtro, width=50).grid(
            row=7, column=0, columnspan=2, sticky='we', padx=(0, 10))

        nota = ttk.LabelFrame(t, text=' Controles de pantalla ', padding=14)
        nota.pack(fill='x', pady=(14, 0))
        ttk.Label(nota, text='Cambia estos tags si tu proyecto usa otros wrappers.',
                  foreground='#667085').grid(row=0, column=0, columnspan=4, sticky='w', pady=(0, 8))

        self.p_controles = {}
        defaults = defmod.CONTROLES_DEFECTO
        for i, clave in enumerate(['texto', 'textarea', 'numero', 'combo',
                                   'check', 'fecha', 'boton', 'grid']):
            fila, col = divmod(i, 4)
            ttk.Label(nota, text=clave).grid(row=1 + fila * 2, column=col, sticky='w', padx=(0, 10))
            var = tk.StringVar(value=defaults[clave])
            ttk.Entry(nota, textvariable=var, width=24).grid(
                row=2 + fila * 2, column=col, sticky='we', padx=(0, 10), pady=(0, 6))
            self.p_controles[clave] = var
        for i in range(4):
            nota.columnconfigure(i, weight=1)

    def _tab_entidad(self):
        t = ttk.Frame(self.nb, padding=16)
        self.nb.add(t, text='  2. Entidad  ')

        g = ttk.LabelFrame(t, text=' Identificacion ', padding=14)
        g.pack(fill='x')
        for i in range(4):
            g.columnconfigure(i, weight=1)

        ttk.Label(g, text='Tabla (MAYUSCULAS)').grid(row=0, column=0, sticky='w', padx=(0, 10))
        self.e_tabla = tk.StringVar()
        ent = ttk.Entry(g, textvariable=self.e_tabla, width=26, font=('Segoe UI', 10, 'bold'))
        ent.grid(row=1, column=0, sticky='we', padx=(0, 10), pady=(0, 4))
        ent.bind('<KeyRelease>', self._autocompletar)
        pie = ttk.Frame(g)
        pie.grid(row=2, column=0, sticky='w', pady=(0, 6))
        ttk.Label(pie, text='Unico dato realmente obligatorio', foreground='#667085',
                  font=('Segoe UI', 8)).pack(side='left')
        ttk.Button(pie, text='Recalcular nombres', width=19,
                   command=self.recalcular_nombres).pack(side='left', padx=(10, 0))

        self.e_prefijo = self._campo(g, 'Prefijo de columnas', '', 0, 1, clave='prefijo',
                                     ayuda='3 letras. Ej: PRODUCTO -> PRO')
        self.e_singular = self._campo(g, 'Singular (codigo)', '', 0, 2, clave='singular',
                                      ayuda='Clase Model y ficha')
        self.e_plural = self._campo(g, 'Plural (codigo)', '', 0, 3, clave='plural',
                                    ayuda='Listado y Get<Plural>')

        self.e_modulo = self._campo(g, 'Modulo', 'Comun', 3, 0, clave='modulo',
                                    ayuda='Carpeta bajo View/')
        self.e_submodulo = self._campo(g, 'Submodulo', '', 3, 1, clave='submodulo',
                                       ayuda='Carpeta de las paginas .aspx')
        self.e_menu = self._campo(g, 'Menu de permisos', 'menu_1', 3, 2, clave='menu',
                                  ayuda='Enum de SitioBase.Paginas')
        self.e_orden = self._campo(g, 'ORDER BY del SEL', '', 3, 3, clave='orden',
                                   ayuda='Vacio = primera columna de busqueda')

        self.e_tit_list = self._campo(g, 'Titulo del listado', '', 6, 0, clave='tit_list')
        self.e_tit_form = self._campo(g, 'Titulo del formulario', '', 6, 1, clave='tit_form')
        self.e_tab = self._campo(g, 'Nombre del tab', 'Identidad', 6, 2, clave='tab')

        g2 = ttk.LabelFrame(t, text=' Comportamiento ', padding=14)
        g2.pack(fill='x', pady=(14, 0))

        ttk.Label(g2, text='Tipo de tabla').grid(row=0, column=0, sticky='w', padx=(0, 12))
        self.e_tipo = tk.StringVar(value='maestro')
        marco = ttk.Frame(g2)
        marco.grid(row=1, column=0, sticky='w', padx=(0, 24))
        ttk.Radiobutton(marco, text='Maestro  (baja logica: boton Deshabilitar)',
                        variable=self.e_tipo, value='maestro').pack(anchor='w')
        ttk.Radiobutton(marco, text='Detalle  (borrado fisico: boton Eliminar)',
                        variable=self.e_tipo, value='detalle').pack(anchor='w')

        self.e_auditoria = tk.BooleanVar(value=True)
        self.e_habilitado = tk.BooleanVar(value=True)
        self.e_pais = tk.BooleanVar(value=False)
        self.e_col_pais = tk.StringVar(value='PAIS')

        marco2 = ttk.Frame(g2)
        marco2.grid(row=1, column=1, sticky='w')
        ttk.Checkbutton(marco2, text='Columnas de auditoria (usuario/fecha creacion y actualizacion)',
                        variable=self.e_auditoria).pack(anchor='w')
        ttk.Checkbutton(marco2, text='Columna HABILITADO (baja logica y filtro)',
                        variable=self.e_habilitado).pack(anchor='w')
        fila_pais = ttk.Frame(marco2)
        fila_pais.pack(anchor='w', pady=(2, 0))
        ttk.Checkbutton(fila_pais, text='Seguridad por pais del usuario  -  columna:',
                        variable=self.e_pais).pack(side='left')
        ttk.Entry(fila_pais, textvariable=self.e_col_pais, width=10).pack(side='left', padx=(6, 0))

        self.lbl_rutas = ttk.Label(t, text='', foreground=COLOR_CABECERA,
                                   font=('Consolas', 9), justify='left')
        self.lbl_rutas.pack(anchor='w', pady=(14, 0))
        for var in (self.e_tabla, self.e_singular, self.e_plural,
                    self.e_modulo, self.e_submodulo):
            var.trace_add('write', lambda *_: self._refrescar_rutas())

    def _tab_columnas(self):
        t = ttk.Frame(self.nb, padding=16)
        self.nb.add(t, text='  3. Columnas  ')

        ttk.Label(t, text='No declares ID, HABILITADO ni las columnas de auditoria: '
                          'el generador las agrega solo.',
                  foreground='#667085').pack(anchor='w', pady=(0, 8))

        marco = ttk.Frame(t)
        marco.pack(fill='both', expand=True)

        cols = ('nombre', 'tipo', 'req', 'control', 'fk', 'grid', 'extra')
        self.tabla_cols = ttk.Treeview(marco, columns=cols, show='headings', height=14)
        for clave, texto, ancho in [
            ('nombre', 'COLUMNA', 190), ('tipo', 'TIPO SQL', 150),
            ('req', 'OBLIG.', 70), ('control', 'CONTROL', 110),
            ('fk', 'FK', 150), ('grid', 'GRID', 60), ('extra', 'NOTAS', 190)]:
            self.tabla_cols.heading(clave, text=texto)
            self.tabla_cols.column(clave, width=ancho, anchor='w')
        self.tabla_cols.pack(side='left', fill='both', expand=True)
        self.tabla_cols.bind('<Double-1>', lambda _: self.editar_columna())

        sb = ttk.Scrollbar(marco, orient='vertical', command=self.tabla_cols.yview)
        sb.pack(side='left', fill='y')
        self.tabla_cols.configure(yscrollcommand=sb.set)

        botones = ttk.Frame(marco, padding=(12, 0))
        botones.pack(side='left', fill='y')
        for texto, cmd in [('Agregar', self.agregar_columna),
                           ('Editar', self.editar_columna),
                           ('Duplicar', self.duplicar_columna),
                           ('Eliminar', self.eliminar_columna),
                           ('Subir', lambda: self.mover(-1)),
                           ('Bajar', lambda: self.mover(1))]:
            ttk.Button(botones, text=texto, command=cmd, width=12).pack(pady=3)

    def _tab_piezas(self):
        t = ttk.Frame(self.nb, padding=16)
        self.nb.add(t, text='  4. Que generar  ')

        ttk.Label(t, text='Cada pieza es independiente. Destilda lo que no necesites y se '
                          'generara solo el resto. Pasa el mouse por encima para ver que hace cada una.',
                  foreground='#667085').pack(anchor='w', pady=(0, 10))

        atajos = ttk.Frame(t)
        atajos.pack(fill='x', pady=(0, 12))
        ttk.Button(atajos, text='Todo', width=12,
                   command=lambda: self._marcar_piezas(piezasmod.TODAS)).pack(side='left')
        ttk.Button(atajos, text='Nada', width=12,
                   command=lambda: self._marcar_piezas([])).pack(side='left', padx=6)
        ttk.Separator(atajos, orient='vertical').pack(side='left', fill='y', padx=10)
        for alias, texto in [('bd', 'Solo base de datos'),
                             ('crud', 'Solo Model + Controller'),
                             ('ui', 'Solo vistas y paginas')]:
            ttk.Button(atajos, text=texto,
                       command=lambda a=alias: self._marcar_piezas(piezasmod.ALIAS[a])
                       ).pack(side='left', padx=(0, 6))

        contenedor = ttk.Frame(t)
        contenedor.pack(fill='both', expand=True)

        self.v_piezas = {}
        for i, (grupo, etiqueta_grupo, lista) in enumerate(piezasmod.GRUPOS):
            fila, col = divmod(i, 3)
            caja = ttk.LabelFrame(contenedor, text=' %s ' % etiqueta_grupo, padding=8)
            caja.grid(row=fila, column=col, sticky='nsew', padx=(0, 10), pady=(0, 8))
            contenedor.columnconfigure(col, weight=1)

            marco_titulo = ttk.Frame(caja)
            marco_titulo.pack(fill='x', pady=(0, 4))
            ttk.Button(marco_titulo, text='Todo', width=8,
                       command=lambda g=grupo: self._marcar_grupo(g, True)).pack(side='left')
            ttk.Button(marco_titulo, text='Nada', width=8,
                       command=lambda g=grupo: self._marcar_grupo(g, False)).pack(side='left', padx=4)

            for clave, etiqueta, descripcion in lista:
                var = tk.BooleanVar(value=True)
                self.v_piezas[clave] = var
                chk = ttk.Checkbutton(caja, text=etiqueta, variable=var,
                                      command=self._resumen_piezas)
                chk.pack(anchor='w')
                self._tooltip(chk, descripcion)

        self.lbl_piezas = ttk.Label(t, text='', foreground=COLOR_CABECERA,
                                    font=('Segoe UI', 9, 'bold'))
        self.lbl_piezas.pack(anchor='w', pady=(6, 0))

        self.lbl_dependencias = ttk.Label(t, text='', foreground=COLOR_SKIP,
                                          font=('Segoe UI', 8), justify='left')
        self.lbl_dependencias.pack(anchor='w')

        self._resumen_piezas()

    def _tooltip(self, widget, texto):
        """Globo de ayuda simple al pasar el mouse."""
        estado = {'ventana': None}

        def mostrar(evento):
            if estado['ventana'] or not texto:
                return
            v = tk.Toplevel(widget)
            v.wm_overrideredirect(True)
            v.wm_geometry('+%d+%d' % (evento.x_root + 14, evento.y_root + 12))
            tk.Label(v, text=texto, bg='#111827', fg='#e5e7eb', padx=8, pady=4,
                     font=('Segoe UI', 8), justify='left').pack()
            estado['ventana'] = v

        def ocultar(_):
            if estado['ventana']:
                estado['ventana'].destroy()
                estado['ventana'] = None

        widget.bind('<Enter>', mostrar)
        widget.bind('<Leave>', ocultar)

    def _marcar_piezas(self, claves):
        activas = set(claves)
        for clave, var in self.v_piezas.items():
            var.set(clave in activas)
        self._resumen_piezas()

    def _marcar_grupo(self, grupo, valor):
        for clave in piezasmod.ALIAS[grupo]:
            self.v_piezas[clave].set(valor)
        self._resumen_piezas()

    def _piezas_activas(self):
        return set(k for k, v in self.v_piezas.items() if v.get())

    def _resumen_piezas(self):
        activas = self._piezas_activas()
        total = len(piezasmod.TODAS)

        if len(activas) == total:
            self.lbl_piezas.config(text='Se generara TODO (%d piezas).' % total)
        elif not activas:
            self.lbl_piezas.config(text='No hay ninguna pieza seleccionada.')
        else:
            self.lbl_piezas.config(
                text='Seleccionadas %d de %d piezas.' % (len(activas), total))

        avisos = piezasmod.faltantes(activas)
        if avisos:
            texto = ['Dependencias que no se van a generar (ignoralo si ya existen '
                     'en el proyecto):']
            for pieza, requerida in avisos:
                texto.append('   - "%s" necesita "%s"'
                             % (piezasmod.ETIQUETAS[pieza], piezasmod.ETIQUETAS[requerida]))
            self.lbl_dependencias.config(text='\n'.join(texto))
        else:
            self.lbl_dependencias.config(text='')

    def _barra_inferior(self, padre):
        marco = ttk.Frame(padre)
        marco.pack(fill='both', pady=(12, 0))

        fila = ttk.Frame(marco)
        fila.pack(fill='x')

        ttk.Label(fila, text='Carpeta de salida:').pack(side='left')
        self.v_salida = tk.StringVar(value=os.path.join(RAIZ, 'salida'))
        ttk.Entry(fila, textvariable=self.v_salida).pack(side='left', fill='x', expand=True, padx=8)
        ttk.Button(fila, text='Examinar...', command=self._elegir_salida).pack(side='left')

        self.v_forzar = tk.BooleanVar(value=False)
        ttk.Checkbutton(fila, text='Sobreescribir', variable=self.v_forzar).pack(side='left', padx=(12, 0))

        ttk.Button(fila, text='GENERAR', style='Accion.TButton',
                   command=self.generar).pack(side='left', padx=(12, 0))
        self.btn_abrir = ttk.Button(fila, text='Abrir carpeta', command=self._abrir_carpeta,
                                    state='disabled')
        self.btn_abrir.pack(side='left', padx=(6, 0))

        self.log = scrolledtext.ScrolledText(marco, height=6, font=('Consolas', 9),
                                             bg='#111827', fg='#d1d5db',
                                             insertbackground='#d1d5db', wrap='none')
        self.log.pack(fill='both', expand=True, pady=(10, 0))
        self.log.tag_config('ok', foreground='#4ade80')
        self.log.tag_config('skip', foreground='#fbbf24')
        self.log.tag_config('err', foreground='#f87171')
        self.log.tag_config('tit', foreground='#93c5fd')
        self.log.configure(state='disabled')

    # ------------------------------------------------------------------
    # LOG
    # ------------------------------------------------------------------
    def _escribir(self, texto, tag=None):
        self.log.configure(state='normal')
        self.log.insert('end', texto + '\n', tag or ())
        self.log.see('end')
        self.log.configure(state='disabled')

    def _limpiar_log(self):
        self.log.configure(state='normal')
        self.log.delete('1.0', 'end')
        self.log.configure(state='disabled')

    def _log_inicial(self):
        self._escribir('Listo.', 'tit')
        self._escribir('1) Completa la pestana Entidad (basta el nombre de la tabla).')
        self._escribir('2) Agrega las columnas en la pestana Columnas.')
        self._escribir('3) Pulsa GENERAR.')
        self._escribir('')
        self._escribir('Menu Ejemplos: carga una definicion de referencia para ver como queda.')

    # ------------------------------------------------------------------
    # AUTOCOMPLETADO
    # ------------------------------------------------------------------
    def recalcular_nombres(self):
        """
        Vuelve a derivar prefijo, singular, plural, submodulo y titulos desde la tabla,
        pisando lo que hubiera. Es el boton a usar cuando se renombra la tabla de una
        definicion ya cargada: sin esto, los nombres derivados quedan obsoletos y los
        archivos saldrian con el nombre anterior.
        """
        if not self.e_tabla.get().strip():
            messagebox.showinfo('Falta la tabla', 'Escribi primero el nombre de la tabla.')
            return
        self._campos_tocados.clear()
        self._autocompletar()
        self._refrescar_columnas(self._indice_seleccionado())
        self._escribir('Nombres recalculados desde la tabla "%s".'
                       % self.e_tabla.get().strip().upper(), 'ok')

    def _autocompletar(self, _=None):
        tabla = self.e_tabla.get().strip().upper()
        if not tabla:
            return
        singular = util.pascal(tabla)
        sugerencias = {
            'prefijo': (self.e_prefijo, tabla[:3]),
            'singular': (self.e_singular, singular),
            'plural': (self.e_plural, singular + 's'),
            'submodulo': (self.e_submodulo, singular + 's'),
            'tit_list': (self.e_tit_list, singular + 's'),
            'tit_form': (self.e_tit_form, 'Ficha de ' + singular),
        }
        for clave, (var, valor) in sugerencias.items():
            if clave not in self._campos_tocados:
                var.set(valor)
        self._refrescar_rutas()

    def _refrescar_rutas(self):
        tabla = self.e_tabla.get().strip().upper()
        if not tabla:
            self.lbl_rutas.config(text='')
            return
        singular = self.e_singular.get().strip() or util.pascal(tabla)
        plural = self.e_plural.get().strip() or (singular + 's')
        modulo = util.pascal(self.e_modulo.get().strip() or 'Comun')
        sub = util.pascal(self.e_submodulo.get().strip() or plural)
        view = self.p_view.get().strip() or 'View'
        app = self.p_appcode.get().strip() or 'App_Code'

        self.lbl_rutas.config(text=(
            'Se generara:\n'
            '  %s/Model/%s.cs      %s/Controller/%sController.cs\n'
            '  %s/%s/Controls/%s/   ->  %s.ascx  %s.ascx  %s.ascx\n'
            '  %s/%s/%s/            ->  %s.aspx  %s.aspx'
            % (app, singular, app, singular,
               view, modulo, singular, plural, singular,
               self.e_tab.get().strip() or 'Identidad',
               view, modulo, sub, plural, singular)))

    # ------------------------------------------------------------------
    # COLUMNAS
    # ------------------------------------------------------------------
    def _prefijo_actual(self):
        return (self.e_prefijo.get().strip().upper() or
                self.e_tabla.get().strip().upper()[:3] or 'XXX')

    def agregar_columna(self):
        dlg = DialogoColumna(self, None, self._prefijo_actual())
        if dlg.resultado:
            self.columnas.append(dlg.resultado)
            self._refrescar_columnas(len(self.columnas) - 1)

    def _indice_seleccionado(self):
        sel = self.tabla_cols.selection()
        if not sel:
            return None
        return int(self.tabla_cols.index(sel[0]))

    def editar_columna(self):
        i = self._indice_seleccionado()
        if i is None:
            messagebox.showinfo('Sin seleccion', 'Selecciona una columna de la lista.')
            return
        dlg = DialogoColumna(self, self.columnas[i], self._prefijo_actual())
        if dlg.resultado:
            self.columnas[i] = dlg.resultado
            self._refrescar_columnas(i)

    def duplicar_columna(self):
        i = self._indice_seleccionado()
        if i is None:
            return
        copia = json.loads(json.dumps(self.columnas[i]))
        copia['nombre'] = copia['nombre'] + '_2'
        copia.pop('unico', None)
        self.columnas.insert(i + 1, copia)
        self._refrescar_columnas(i + 1)

    def eliminar_columna(self):
        i = self._indice_seleccionado()
        if i is None:
            return
        if messagebox.askyesno('Eliminar', 'Quitar la columna "%s"?' % self.columnas[i]['nombre']):
            del self.columnas[i]
            self._refrescar_columnas(min(i, len(self.columnas) - 1))

    def mover(self, delta):
        i = self._indice_seleccionado()
        if i is None:
            return
        j = i + delta
        if 0 <= j < len(self.columnas):
            self.columnas[i], self.columnas[j] = self.columnas[j], self.columnas[i]
            self._refrescar_columnas(j)

    def _refrescar_columnas(self, seleccionar=None):
        self.tabla_cols.delete(*self.tabla_cols.get_children())
        prefijo = self._prefijo_actual()

        for col in self.columnas:
            try:
                tipo = Tipo(col.get('tipo', 'NVARCHAR(200)'))
                control = col.get('control') or (
                    'combo' if col.get('fk') else tipo.control_sugerido(col['nombre']))
            except ValueError:
                control = col.get('control', '?')

            fk = col.get('fk')
            notas = []
            if col.get('unico'):
                notas.append('unico')
            if col.get('upperCase'):
                notas.append('MAYUS')
            if col.get('lowerCase'):
                notas.append('minus')
            if col.get('busqueda') is True:
                notas.append('busqueda')
            if col.get('gridAncho'):
                notas.append(col['gridAncho'])

            self.tabla_cols.insert('', 'end', values=(
                '%s_%s' % (prefijo, col['nombre']),
                col.get('tipo', 'NVARCHAR(200)'),
                'Si' if col.get('requerido') else 'No',
                control,
                fk['tabla'] if fk else '',
                'No' if col.get('grid') is False else 'Si',
                ', '.join(notas),
            ))

        hijos = self.tabla_cols.get_children()
        if seleccionar is not None and 0 <= seleccionar < len(hijos):
            self.tabla_cols.selection_set(hijos[seleccionar])
            self.tabla_cols.focus(hijos[seleccionar])

    # ------------------------------------------------------------------
    # DEFINICION <-> UI
    # ------------------------------------------------------------------
    def _construir_definicion(self):
        proyecto = {
            'baseDatos': self.p_bd.get().strip() or 'SIGMA',
            'namespace': self.p_ns.get().strip() or 'Sigma',
            'autor': self.p_autor.get().strip(),
            'master': self.p_master.get().strip(),
            'rutaAppCode': self.p_appcode.get().strip(),
            'rutaView': self.p_view.get().strip(),
            'rutaFiltroAvanzado': self.p_filtro.get().strip(),
        }
        controles = {k: v.get().strip() for k, v in self.p_controles.items()
                     if v.get().strip() and v.get().strip() != defmod.CONTROLES_DEFECTO[k]}
        if controles:
            proyecto['controles'] = controles

        entidad = {
            'tabla': self.e_tabla.get().strip().upper(),
            'prefijo': self.e_prefijo.get().strip().upper(),
            'singular': self.e_singular.get().strip(),
            'plural': self.e_plural.get().strip(),
            'modulo': self.e_modulo.get().strip(),
            'subModulo': self.e_submodulo.get().strip(),
            'menu': self.e_menu.get().strip(),
            'tituloListado': self.e_tit_list.get().strip(),
            'tituloFormulario': self.e_tit_form.get().strip(),
            'tab': self.e_tab.get().strip() or 'Identidad',
            'tipo': self.e_tipo.get(),
            'auditoria': self.e_auditoria.get(),
            'habilitado': self.e_habilitado.get(),
            'seguridadPorPais': self.e_pais.get(),
        }
        if self.e_pais.get():
            entidad['columnaPais'] = self.e_col_pais.get().strip().upper() or 'PAIS'
        if self.e_orden.get().strip():
            entidad['orden'] = self.e_orden.get().strip()

        entidad = {k: v for k, v in entidad.items() if v not in ('', None)}

        return {'proyecto': proyecto, 'entidad': entidad,
                'columnas': json.loads(json.dumps(self.columnas))}

    def _cargar_definicion(self, datos):
        p = datos.get('proyecto') or {}
        self.p_bd.set(p.get('baseDatos', 'SIGMA'))
        self.p_ns.set(p.get('namespace', 'Sigma'))
        self.p_autor.set(p.get('autor', 'EQUIPO CODIGO CREATIVO'))
        self.p_master.set(p.get('master', '~/Master/Default.master'))
        self.p_appcode.set(p.get('rutaAppCode', 'App_Code/MVC/' + p.get('namespace', 'Sigma')))
        self.p_view.set(p.get('rutaView', 'View'))
        self.p_filtro.set(p.get('rutaFiltroAvanzado',
                                '~/View/Comun/Controls/FiltroAvanzado.ascx'))
        for clave, var in self.p_controles.items():
            var.set((p.get('controles') or {}).get(clave, defmod.CONTROLES_DEFECTO[clave]))

        e = datos.get('entidad') or {}

        # Solo se consideran "tocados" los campos que el archivo trae con valor:
        # asi, si vienen vacios, el autocompletado sigue funcionando.
        self._campos_tocados = set(
            clave for clave, valor in [
                ('prefijo', e.get('prefijo')), ('singular', e.get('singular')),
                ('plural', e.get('plural')), ('submodulo', e.get('subModulo')),
                ('tit_list', e.get('tituloListado')), ('tit_form', e.get('tituloFormulario')),
                ('modulo', e.get('modulo')), ('menu', e.get('menu')),
                ('orden', e.get('orden')), ('tab', e.get('tab')),
            ] if valor)

        self.e_tabla.set(e.get('tabla', ''))
        self.e_prefijo.set(e.get('prefijo', ''))
        self.e_singular.set(e.get('singular', ''))
        self.e_plural.set(e.get('plural', ''))
        self.e_modulo.set(e.get('modulo', 'Comun'))
        self.e_submodulo.set(e.get('subModulo', ''))
        self.e_menu.set(e.get('menu', 'menu_1'))
        self.e_orden.set(e.get('orden', ''))
        self.e_tit_list.set(e.get('tituloListado', ''))
        self.e_tit_form.set(e.get('tituloFormulario', ''))
        self.e_tab.set(e.get('tab', 'Identidad'))
        self.e_tipo.set(e.get('tipo', 'maestro'))
        self.e_auditoria.set(e.get('auditoria', True))
        self.e_habilitado.set(e.get('habilitado', True))
        self.e_pais.set(e.get('seguridadPorPais', False))
        self.e_col_pais.set(e.get('columnaPais', 'PAIS'))

        self.columnas = [c for c in (datos.get('columnas') or [])
                         if isinstance(c, dict)]
        self._refrescar_columnas(0 if self.columnas else None)
        self._refrescar_rutas()

    # ------------------------------------------------------------------
    # ARCHIVO
    # ------------------------------------------------------------------
    def nueva(self, confirmar=True):
        if confirmar and self.columnas and not messagebox.askyesno(
                'Nueva definicion', 'Se perderan los datos actuales. Continuar?'):
            return
        self.ruta_definicion = None
        self._cargar_definicion({'proyecto': {}, 'entidad': {}, 'columnas': []})
        self._campos_tocados = set()      # despues de cargar: todo vuelve a autocompletarse
        self._limpiar_log()
        self._log_inicial()

    def abrir(self, ruta=None):
        if ruta is None:
            ruta = filedialog.askopenfilename(
                title='Abrir definicion',
                initialdir=os.path.join(RAIZ, 'ejemplos'),
                filetypes=[('Definicion JSON', '*.json'), ('Todos', '*.*')])
        if not ruta:
            return
        try:
            with open(ruta, 'r', encoding='utf-8-sig') as f:
                datos = json.load(f)
        except Exception as ex:                             # noqa: BLE001
            messagebox.showerror('No se pudo abrir', str(ex))
            return
        self._cargar_definicion(datos)
        self.ruta_definicion = ruta
        self._limpiar_log()
        self._escribir('Definicion cargada: %s' % ruta, 'tit')
        self._escribir('%d columnas.' % len(self.columnas))
        self.nb.select(1)

    def guardar(self):
        if not self.e_tabla.get().strip():
            messagebox.showwarning('Falta la tabla', 'Indica el nombre de la tabla.')
            return
        inicial = '%s.json' % self.e_tabla.get().strip().lower()
        ruta = filedialog.asksaveasfilename(
            title='Guardar definicion', defaultextension='.json',
            initialfile=inicial,
            initialdir=os.path.join(RAIZ, 'definiciones'),
            filetypes=[('Definicion JSON', '*.json')])
        if not ruta:
            return
        carpeta = os.path.dirname(ruta)
        if carpeta and not os.path.isdir(carpeta):
            os.makedirs(carpeta)
        datos = self._construir_definicion()
        datos = dict([('$schema', 'esquema/definicion.schema.json')] + list(datos.items()))
        with open(ruta, 'w', encoding='utf-8') as f:
            json.dump(datos, f, indent=2, ensure_ascii=False)
        self.ruta_definicion = ruta
        self._escribir('Definicion guardada: %s' % ruta, 'ok')

    def _elegir_salida(self):
        carpeta = filedialog.askdirectory(title='Carpeta de salida',
                                          initialdir=self.v_salida.get())
        if carpeta:
            self.v_salida.set(carpeta)

    def _abrir_carpeta(self):
        carpeta = getattr(self, 'ultima_salida', None)
        if carpeta and os.path.isdir(carpeta):
            try:
                os.startfile(carpeta)                        # noqa: S606
            except AttributeError:
                subprocess.Popen(['xdg-open', carpeta])

    # ------------------------------------------------------------------
    # GENERAR
    # ------------------------------------------------------------------
    def generar(self):
        self._limpiar_log()

        if not self.e_tabla.get().strip():
            self._escribir('ERROR: falta el nombre de la tabla (pestana Entidad).', 'err')
            self.nb.select(1)
            return
        if not self.columnas:
            self._escribir('ERROR: agrega al menos una columna (pestana Columnas).', 'err')
            self.nb.select(2)
            return

        activas = self._piezas_activas()
        if not activas:
            self._escribir('ERROR: no hay ninguna pieza seleccionada (pestana Que generar).', 'err')
            self.nb.select(3)
            return

        datos = self._construir_definicion()

        try:
            d = defmod.Definicion(datos)
        except defmod.ErrorDefinicion as ex:
            self._escribir('ERROR EN LA DEFINICION', 'err')
            self._escribir(str(ex), 'err')
            messagebox.showerror('Definicion invalida', str(ex))
            return

        motor._fechar(d)
        carpeta = os.path.join(self.v_salida.get().strip() or
                               os.path.join(RAIZ, 'salida'), d.entidad.tabla)

        try:
            escritor = motor.generar(d, carpeta, forzar=self.v_forzar.get(),
                                     seleccion=activas)
        except Exception as ex:                              # noqa: BLE001
            self._escribir('ERROR GENERANDO: %s' % ex, 'err')
            self._escribir(traceback.format_exc(), 'err')
            messagebox.showerror('Error', str(ex))
            return

        e = d.entidad
        self._escribir('%s (%s)  ->  %d archivos' % (e.singular, e.tabla, escritor.total), 'tit')
        if activas != set(piezasmod.TODAS):
            self._escribir('Piezas     : %s'
                           % ', '.join(k for k in piezasmod.TODAS if k in activas))
        self._escribir('Salida     : %s' % os.path.abspath(carpeta))
        self._escribir('Namespaces : %s / %s' % (d.proyecto.ns_model, d.proyecto.ns_controller))
        self._escribir('Columnas   : %d  (grid: %d, formulario: %d, filtros: %d, FK: %d)'
                       % (len(d.columnas), len(d.columnas_grid), len(d.columnas_formulario),
                          len(d.columnas_filtro), len(d.fks)))
        self._escribir('Baja       : %s' % ('logica (HABILITADO = 0)' if e.usa_baja_logica
                                            else 'fisica (DELETE)'))

        if d.prefijos_en_conflicto:
            self._escribir('')
            self._escribir('AVISO: %s comparte el prefijo "%s_" con: %s'
                           % (e.tabla, e.prefijo, ', '.join(d.prefijos_en_conflicto)), 'skip')
            self._escribir('       Se calificaron las columnas con "%s." para que el SEL'
                           % e.tabla, 'skip')
            self._escribir('       no quede ambiguo, pero conviene revisar el prefijo.', 'skip')

        self._escribir('')
        for a in escritor.escritos:
            self._escribir('  [OK]   %s' % a, 'ok')
        for a in escritor.omitidos:
            self._escribir('  [YA EXISTE] %s   (marca Sobreescribir para pisarlo)' % a, 'skip')

        for pieza, requerida in piezasmod.faltantes(activas):
            self._escribir('  NOTA: "%s" necesita "%s", que no se genero en esta corrida.'
                           % (piezasmod.ETIQUETAS[pieza], piezasmod.ETIQUETAS[requerida]), 'skip')

        self._escribir('')
        if 'leeme' in activas:
            self._escribir('Siguiente paso: leer _LEEME_%s.md en la carpeta de salida.'
                           % e.tabla, 'tit')

        self.ultima_salida = os.path.abspath(carpeta)
        self.btn_abrir.configure(state='normal')

        if escritor.omitidos and not escritor.escritos:
            messagebox.showinfo('Nada que escribir',
                                'Todos los archivos ya existian.\n'
                                'Marca "Sobreescribir" si queres regenerarlos.')

    # ------------------------------------------------------------------
    def _ayuda(self):
        messagebox.showinfo(
            'Como se usa',
            '1. Pestana Proyecto: base de datos, namespace y rutas.\n'
            '   Se completa una vez y queda guardado en la definicion.\n\n'
            '2. Pestana Entidad: escribi el nombre de la tabla y el resto\n'
            '   se autocompleta (prefijo, singular, plural, rutas, titulos).\n\n'
            '3. Pestana Columnas: agrega las columnas de negocio.\n'
            '   NO agregues ID, HABILITADO ni las de auditoria.\n\n'
            '4. GENERAR: escribe los 18 archivos en la carpeta de salida.\n\n'
            'Menu Archivo > Guardar definicion: deja el .json para regenerar\n'
            'mas adelante cuando cambie la tabla.')

    def _ayuda_tipos(self):
        messagebox.showinfo('Tipos SQL soportados',
                            '\n'.join(', '.join(tipos_soportados()[i:i + 6])
                                      for i in range(0, len(tipos_soportados()), 6)))


def main():
    # Texto nitido en pantallas con escalado (Windows).
    try:
        import ctypes
        ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except Exception:                                        # noqa: BLE001
        pass

    app = Aplicacion()
    app.mainloop()


if __name__ == '__main__':
    main()
