# -*- coding: utf-8 -*-
"""
Lectura, validacion y enriquecimiento del archivo de definicion (.json).

De aqui salen los objetos Proyecto / Entidad / Columna / Fk que consumen
todas las plantillas. Toda la logica de "valores por defecto inteligentes"
esta aqui, para que el JSON del usuario sea lo mas corto posible.
"""

import io
import json
import os

from . import util
from .tipos import Tipo, CONTROLES_VALIDOS


class ErrorDefinicion(Exception):
    pass


# ---------------------------------------------------------------------------
# CONTROLES POR DEFECTO (tags de los .ascx). Se pueden sobreescribir en el JSON
# con proyecto.controles, para que cada equipo apunte a sus propios wrappers.
# ---------------------------------------------------------------------------
CONTROLES_DEFECTO = {
    'texto':    'WebControls:TextBox2',
    'textarea': 'WebControls:TextArea2',
    'numero':   'rad:RadNumericBox2',
    'combo':    'rad:RadComboBox2',
    'check':    'WebControls:CheckBox2',
    'fecha':    'rad:RadDatePicker',
    'password': 'WebControls:TextBox2',
    'boton':    'WebControls:PushButton',
    'grid':     'rad:RadGrid2',
    'tabstrip': 'rad:RadTabStrip2',
    'multipage': 'rad:RadMultiPage',
    'pageview': 'rad:RadPageView',
    'tab':      'rad:RadTab',
}

# Prefijo del ID del control segun el tipo de control.
_PREFIJO_CONTROL = {
    'texto': 'txt', 'textarea': 'txt', 'numero': 'txt', 'combo': 'cbo',
    'check': 'chk', 'fecha': 'dtp', 'password': 'txt',
}

# Peso relativo para repartir el ancho de las columnas del grid.
_PESO_GRID = {
    'texto': 22, 'textarea': 0, 'numero': 9, 'combo': 14,
    'check': 0, 'fecha': 11, 'password': 0, 'ninguno': 0,
}


# ===========================================================================
# FK
# ===========================================================================
class Fk(object):
    """Relacion a otra tabla: alimenta el JOIN del SP y el combo de pantalla."""

    def __init__(self, datos, columna_padre):
        if isinstance(datos, str):
            datos = {'tabla': datos}
        if not isinstance(datos, dict) or not datos.get('tabla'):
            raise ErrorDefinicion(
                'La columna "%s" declara "fk" sin "tabla".' % columna_padre)

        self.tabla = str(datos['tabla']).upper()
        self.prefijo = str(datos.get('prefijo') or self.tabla[:3]).upper()

        self.columna = str(datos.get('columna') or (self.prefijo + '_ID')).upper()
        self.columna_texto = str(
            datos.get('columnaTexto') or (self.prefijo + '_NOMBRE')).upper()

        self.modelo = datos.get('modelo') or util.pascal(self.tabla)
        self.controller = datos.get('controller') or (self.modelo + 'Controller')
        self.metodo_lista = datos.get('metodoLista') or ('Get' + _plural(self.modelo))

        # propValor / propTexto -> DataValueField / DataTextField del combo.
        # Son propiedades del Model REFERENCIADO (ej. Paises.pai_nombres).
        self.prop_valor = datos.get('propValor') or self.columna.lower()
        self.prop_texto = datos.get('propTexto') or self.columna_texto.lower()

        # propDenormalizada -> propiedad que se agrega al Model de ESTA entidad
        # para mostrar el texto del JOIN en el grid. Sale de la columna, no del
        # DataTextField: son cosas distintas (PAI_NOMBRE vs pai_nombres).
        self.prop_join = datos.get('propDenormalizada') or self.columna_texto.lower()

        # Como se le pide "solo habilitados" al controller de la tabla referenciada.
        self.filtro_habilitado = datos.get('filtroHabilitado', 'bool')
        if self.filtro_habilitado not in ('bool', 'string', 'none'):
            raise ErrorDefinicion(
                'fk.filtroHabilitado de "%s" debe ser "bool", "string" o "none".'
                % columna_padre)

        # Se completan mas tarde (necesitan ver todas las columnas):
        self.alias_tabla = None       # alias del JOIN si la tabla se repite
        self.prop_denormalizada = None  # propiedad del Model con el texto
        self.columna_select = None    # como se pide en el SELECT del SP


def _plural(palabra):
    """Pluralizacion suficiente para nombres de metodos en espanol."""
    if not palabra:
        return palabra
    ultima = palabra[-1].lower()
    if ultima in 'aeiou':
        return palabra + 's'
    if ultima == 'z':
        return palabra[:-1] + 'ces'
    if ultima == 's':
        return palabra
    return palabra + 'es'


# ===========================================================================
# COLUMNA
# ===========================================================================
class Columna(object):
    def __init__(self, datos, entidad_prefijo, sintetica=False):
        if isinstance(datos, str):
            datos = {'nombre': datos, 'tipo': 'NVARCHAR(200)'}
        if not isinstance(datos, dict):
            raise ErrorDefinicion('Cada elemento de "columnas" debe ser un objeto.')

        nombre = datos.get('nombre')
        if not nombre:
            raise ErrorDefinicion('Hay una columna sin "nombre".')

        self.sintetica = sintetica                     # generada por el generador
        self.nombre = str(nombre).upper()
        try:
            self.tipo = Tipo(datos.get('tipo') or 'NVARCHAR(200)')
        except ValueError as ex:
            raise ErrorDefinicion('Columna "%s": %s' % (self.nombre, ex))

        self.columna = '%s_%s' % (entidad_prefijo, self.nombre)   # PRO_NOMBRE
        self.prop = self.columna.lower()                          # pro_nombre
        self.param = '@' + self.nombre                            # @NOMBRE

        self.requerido = bool(datos.get('requerido', False))
        self.etiqueta = datos.get('etiqueta') or util.titulo(self.nombre)

        self.fk = Fk(datos['fk'], self.nombre) if datos.get('fk') else None

        control = datos.get('control')
        if control is None:
            control = 'combo' if self.fk else self.tipo.control_sugerido(self.nombre)
        if control not in CONTROLES_VALIDOS:
            raise ErrorDefinicion(
                'Columna "%s": control "%s" invalido. Validos: %s'
                % (self.nombre, control, ', '.join(CONTROLES_VALIDOS)))
        self.control = control

        if self.control == 'combo' and not self.fk:
            raise ErrorDefinicion(
                'Columna "%s": control "combo" requiere un bloque "fk".' % self.nombre)

        self.control_id = datos.get('controlId') or (
            _PREFIJO_CONTROL.get(self.control, 'txt') + util.pascal(self.nombre))

        # --- Grid ---
        self.grid = bool(datos.get('grid', self.control not in
                                   ('textarea', 'password', 'ninguno')))
        self.grid_ancho = datos.get('gridAncho')
        self.grid_titulo = (datos.get('gridTitulo') or
                            util.sin_acentos(self.etiqueta).upper())

        # --- Filtros / busqueda ---
        # Por defecto los textos cortos entran en el LIKE del @FILTRO.
        self.busqueda = bool(datos.get('busqueda',
                                       self.tipo.es_texto and
                                       self.control in ('texto',) and
                                       not self.tipo.es_max))
        # Filtro propio (combo en la barra de filtros + parametro del SP).
        self.filtro = bool(datos.get('filtro', bool(self.fk)))

        # --- Reglas SQL ---
        self.unico = bool(datos.get('unico', False))
        self.indice = bool(datos.get('indice', bool(self.fk)))
        self.defecto = datos.get('defecto')

        # --- Cosmetica del TextBox2 ---
        self.upper = bool(datos.get('upperCase', False))
        self.lower = bool(datos.get('lowerCase', False))
        self.icono = datos.get('icono')            # ej. "fa-phone"
        self.ancho_form = datos.get('anchoForm') or (
            'col-lg-12 col-md-12 col-xs-12' if self.control == 'textarea'
            else 'col-lg-4 col-md-6 col-xs-12')

        # --- Formulario ---
        self.en_formulario = bool(datos.get('formulario', self.control != 'ninguno'))
        self.solo_lectura = bool(datos.get('soloLectura', False))

    # -- helpers de plantilla -------------------------------------------------
    @property
    def max_length(self):
        return self.tipo.longitud

    @property
    def nullable_sql(self):
        return 'NOT NULL' if self.requerido else 'NULL'

    @property
    def valida(self):
        """Lleva CustomValidator en el formulario."""
        return self.requerido and self.control in (
            'texto', 'textarea', 'numero', 'combo', 'fecha', 'password')

    def __repr__(self):
        return '<Columna %s %s>' % (self.columna, self.tipo.sql)


# ===========================================================================
# PROYECTO
# ===========================================================================
class Proyecto(object):
    def __init__(self, datos):
        datos = datos or {}
        self.base_datos = str(datos.get('baseDatos') or 'SIGMA')
        self.namespace = str(datos.get('namespace') or 'Sigma')
        self.autor = str(datos.get('autor') or 'EQUIPO CODIGO CREATIVO')
        self.master = str(datos.get('master') or '~/Master/Default.master')

        self.ruta_app_code = str(datos.get('rutaAppCode') or
                                 ('App_Code/MVC/' + self.namespace)).replace('\\', '/')
        self.ruta_view = str(datos.get('rutaView') or 'View').replace('\\', '/')
        self.ruta_bd = str(datos.get('rutaBD') or 'BD').replace('\\', '/')
        self.ruta_filtro = str(datos.get('rutaFiltroAvanzado') or
                               '~/View/Comun/Controls/FiltroAvanzado.ascx')
        self.salida = datos.get('salida')

        self.controles = dict(CONTROLES_DEFECTO)
        self.controles.update(datos.get('controles') or {})

        self.usings_extra = list(datos.get('usingsExtra') or [])
        self.fecha = datos.get('fecha')   # se completa en generar.py

    @property
    def ns_model(self):
        return self.namespace + '.Model'

    @property
    def ns_controller(self):
        return self.namespace + '.Controller'


# ===========================================================================
# ENTIDAD
# ===========================================================================
class Entidad(object):
    def __init__(self, datos, proyecto):
        datos = datos or {}
        if not datos.get('tabla'):
            raise ErrorDefinicion('Falta "entidad.tabla" en la definicion.')

        self.tabla = str(datos['tabla']).upper()
        self.prefijo = str(datos.get('prefijo') or self.tabla[:3]).upper()
        self.prefijo_lower = self.prefijo.lower()

        self.singular = datos.get('singular') or util.pascal(self.tabla)
        self.plural = datos.get('plural') or _plural(self.singular)
        self.genero = util.genero_de(self.singular, datos.get('genero'))

        self.modulo = util.pascal(datos.get('modulo') or 'Comun')
        self.sub_modulo = util.pascal(datos.get('subModulo') or self.plural)
        self.menu = str(datos.get('menu') or 'menu_1')

        self.titulo_listado = datos.get('tituloListado') or self.plural
        self.titulo_formulario = datos.get('tituloFormulario') or ('Ficha de ' + self.singular)
        self.tab = datos.get('tab') or 'Identidad'

        self.tipo = str(datos.get('tipo') or 'maestro').lower()
        if self.tipo not in ('maestro', 'detalle'):
            raise ErrorDefinicion('entidad.tipo debe ser "maestro" o "detalle".')

        self.auditoria = bool(datos.get('auditoria', True))
        self.habilitado = bool(datos.get('habilitado', True))
        self.seguridad_por_pais = bool(datos.get('seguridadPorPais', False))
        self.columna_pais = str(datos.get('columnaPais') or 'PAIS').upper()
        self.orden = datos.get('orden')

        self.proyecto = proyecto

    # -- nombres derivados ----------------------------------------------------
    @property
    def id_columna(self):
        return self.prefijo + '_ID'

    @property
    def id_prop(self):
        return self.id_columna.lower()

    @property
    def col_habilitado(self):
        return self.prefijo + '_HABILITADO'

    @property
    def clase_model(self):
        return self.singular

    @property
    def clase_controller(self):
        return self.singular + 'Controller'

    @property
    def sp_sel(self):
        return 'SEL_' + self.tabla

    @property
    def sp_ins(self):
        return 'INS_' + self.tabla

    @property
    def sp_upd(self):
        return 'UPD_' + self.tabla

    @property
    def sp_del(self):
        return 'DEL_' + self.tabla

    @property
    def usa_baja_logica(self):
        return self.tipo == 'maestro' and self.habilitado

    # -- rutas de archivos ----------------------------------------------------
    @property
    def dir_controls(self):
        return '%s/%s/Controls/%s' % (self.proyecto.ruta_view, self.modulo, self.singular)

    @property
    def dir_paginas(self):
        return '%s/%s/%s' % (self.proyecto.ruta_view, self.modulo, self.sub_modulo)

    @property
    def url_pagina_listado(self):
        return '~/%s/%s.aspx' % (self.dir_paginas, self.plural)

    @property
    def url_pagina_formulario(self):
        return '~/%s/%s.aspx' % (self.dir_paginas, self.singular)

    @property
    def src_control_listado(self):
        return '~/%s/%s.ascx' % (self.dir_controls, self.plural)

    @property
    def src_control_formulario(self):
        return '~/%s/%s.ascx' % (self.dir_controls, self.singular)

    @property
    def src_control_tab(self):
        return '~/%s/%s.ascx' % (self.dir_controls, self.tab)

    # -- clases Inherits (ASP.NET arma el nombre desde la ruta) ---------------
    def _clase_ruta(self, directorio, archivo):
        piezas = [util.identificador(p) for p in directorio.split('/') if p]
        piezas.append(util.identificador(archivo))
        return '_'.join(piezas)

    @property
    def clase_listado(self):
        return self._clase_ruta(self.dir_controls, self.plural)

    @property
    def clase_formulario(self):
        return self._clase_ruta(self.dir_controls, self.singular)

    @property
    def clase_tab(self):
        return self._clase_ruta(self.dir_controls, self.tab)

    @property
    def clase_pagina_listado(self):
        return self._clase_ruta(self.dir_paginas, self.plural)

    @property
    def clase_pagina_formulario(self):
        return self._clase_ruta(self.dir_paginas, self.singular)

    # -- mensajes en espanol con concordancia de genero ----------------------
    def mensaje(self, verbo_masculino):
        return '%s %s con exito.' % (self.singular, util.concordar(verbo_masculino, self.genero))

    @property
    def articulo_mayus(self):
        return util.articulo_de(self.genero)


# ===========================================================================
# DEFINICION COMPLETA
# ===========================================================================
class Definicion(object):
    def __init__(self, datos):
        self.proyecto = Proyecto(datos.get('proyecto'))
        self.entidad = Entidad(datos.get('entidad'), self.proyecto)

        crudas = datos.get('columnas')
        if not crudas:
            raise ErrorDefinicion('La definicion no tiene "columnas".')

        self.columnas = [Columna(c, self.entidad.prefijo) for c in crudas]
        self._validar_nombres()
        self._agregar_columna_habilitado()
        self._resolver_fks()
        self._repartir_anchos_grid()
        self._resolver_orden()

    # -- construccion ---------------------------------------------------------
    def _validar_nombres(self):
        vistos = set()
        for c in self.columnas:
            if c.nombre == 'ID':
                raise ErrorDefinicion(
                    'No declares la columna "ID": el generador crea %s automaticamente.'
                    % self.entidad.id_columna)
            if c.nombre in ('USUARIO_CREACION', 'FECHA_CREACION',
                            'USUARIO_ACT', 'FECHA_ACT'):
                raise ErrorDefinicion(
                    'No declares "%s": es una columna de auditoria automatica.' % c.nombre)
            if c.nombre in vistos:
                raise ErrorDefinicion('Columna "%s" declarada dos veces.' % c.nombre)
            vistos.add(c.nombre)

    def _agregar_columna_habilitado(self):
        """HABILITADO es parte del patron: si la entidad lo usa, se sintetiza."""
        if not self.entidad.habilitado:
            self.col_habilitado = None
            return

        existente = next((c for c in self.columnas if c.nombre == 'HABILITADO'), None)
        if existente:
            self.col_habilitado = existente
            self.columnas.remove(existente)
        else:
            self.col_habilitado = Columna({
                'nombre': 'HABILITADO',
                'tipo': 'BIT',
                'requerido': True,
                'etiqueta': 'Habilitado',
                'control': 'check',
                'grid': True,
                'busqueda': False,
                'filtro': False,
                'defecto': 1,
            }, self.entidad.prefijo, sintetica=True)

        self.columnas.append(self.col_habilitado)   # va siempre al final

    def _resolver_fks(self):
        """Resuelve alias de JOIN y nombres de propiedades denormalizadas."""
        conteo = {}
        for c in self.fks:
            conteo[c.fk.tabla] = conteo.get(c.fk.tabla, 0) + 1

        usados = set(c.prop for c in self.columnas)

        for c in self.fks:
            fk = c.fk
            if conteo[fk.tabla] > 1:
                fk.alias_tabla = '%s_%s' % (fk.tabla, c.nombre)
                alias_prop = '%s_%s' % (fk.prop_join, c.nombre.lower())
                fk.columna_select = '%s.%s AS %s' % (
                    fk.alias_tabla, fk.columna_texto, alias_prop.upper())
                fk.prop_denormalizada = alias_prop
            else:
                fk.alias_tabla = None
                fk.columna_select = fk.columna_texto
                fk.prop_denormalizada = fk.prop_join

            if fk.prop_denormalizada in usados:
                fk.prop_denormalizada = fk.prop_denormalizada + '_' + c.nombre.lower()
            usados.add(fk.prop_denormalizada)

    def _repartir_anchos_grid(self):
        """Calcula anchos % para las columnas del grid que no traen uno definido."""
        visibles = [c for c in self.columnas_grid if c.control != 'check']
        sin_ancho = [c for c in visibles if not c.grid_ancho]
        if not sin_ancho:
            return

        ocupado = 0
        for c in visibles:
            if c.grid_ancho and str(c.grid_ancho).endswith('%'):
                try:
                    ocupado += float(str(c.grid_ancho).rstrip('%'))
                except ValueError:
                    pass

        disponible = max(97.0 - 3.0 - ocupado, 10.0)   # 3% para la celda del link Editar
        pesos = [max(_PESO_GRID.get(c.control, 10), 1) for c in sin_ancho]
        total = float(sum(pesos))

        for c, peso in zip(sin_ancho, pesos):
            c.grid_ancho = '%d%%' % max(int(round(disponible * peso / total)), 4)

    def _resolver_orden(self):
        if self.entidad.orden:
            return
        candidatas = [c for c in self.columnas if c.busqueda]
        if candidatas:
            self.entidad.orden = candidatas[0].columna
        else:
            self.entidad.orden = self.entidad.id_columna

    # -- vistas sobre las columnas -------------------------------------------
    @property
    def columnas_datos(self):
        """Columnas reales de la tabla, sin auditoria ni PK."""
        return list(self.columnas)

    @property
    def columnas_editables(self):
        """Las que viajan en INSERT/UPDATE (todas menos la PK y la auditoria)."""
        return list(self.columnas)

    @property
    def columnas_formulario(self):
        return [c for c in self.columnas if c.en_formulario and c.control != 'ninguno']

    @property
    def columnas_grid(self):
        return [c for c in self.columnas if c.grid and c.control != 'ninguno']

    @property
    def columnas_busqueda(self):
        return [c for c in self.columnas if c.busqueda]

    @property
    def columnas_filtro(self):
        """Columnas con filtro propio (combo en la barra de filtros)."""
        return [c for c in self.columnas if c.filtro and c is not self.col_habilitado]

    @property
    def columnas_unicas(self):
        return [c for c in self.columnas if c.unico]

    @property
    def fks(self):
        return [c for c in self.columnas if c.fk]

    @property
    def columnas_password(self):
        return [c for c in self.columnas if c.control == 'password']

    @property
    def prefijos_en_conflicto(self):
        """
        Tablas de FK que comparten prefijo con la entidad. El patron asume
        prefijos unicos por tabla; cuando no lo son, las columnas sin calificar
        del SEL quedan ambiguas.
        """
        return sorted(set(c.fk.tabla for c in self.fks
                          if c.fk.prefijo == self.entidad.prefijo))

    @property
    def calificador(self):
        """Prefijo 'TABLA.' a usar en el SEL cuando hay prefijos repetidos."""
        return (self.entidad.tabla + '.') if self.prefijos_en_conflicto else ''

    @property
    def columnas_combo(self):
        return [c for c in self.columnas if c.control == 'combo']


# ===========================================================================
# CARGA DESDE DISCO
# ===========================================================================
def cargar(ruta_definicion, ruta_proyecto=None):
    """Lee el JSON de definicion (y opcionalmente uno de proyecto) y valida."""
    datos = _leer_json(ruta_definicion)

    if ruta_proyecto:
        base = _leer_json(ruta_proyecto)
        proyecto = dict(base.get('proyecto') or base)
        proyecto.update(datos.get('proyecto') or {})
        datos['proyecto'] = proyecto

    if 'entidad' not in datos and 'tabla' in datos:
        # Permite un JSON "plano" sin el nodo entidad.
        datos = {'proyecto': datos.get('proyecto'), 'entidad': datos,
                 'columnas': datos.get('columnas')}

    return Definicion(datos)


def _leer_json(ruta):
    if not os.path.isfile(ruta):
        raise ErrorDefinicion('No existe el archivo: %s' % ruta)
    with io.open(ruta, 'r', encoding='utf-8-sig') as f:
        try:
            return json.load(f)
        except ValueError as ex:
            raise ErrorDefinicion('JSON invalido en %s: %s' % (ruta, ex))
