# -*- coding: utf-8 -*-
u"""Paso 2. Decide que se borra, que se conserva y con que condicion.

El criterio
-----------
Se borra el DATO DEL CLIENTE -lo que la planta registro- y se conserva el
SISTEMA -lo que hace que SIGMA funcione y que alguien pueda entrar a recrearlo-.

CONSERVAR esta escrito por nombre y no es negociable: los catalogos, los menus,
los permisos, los perfiles y las cuentas de Codigo Creativo. Sin eso nadie puede
iniciar sesion para rehacer nada, y el reinicio dejaria una base inservible en
vez de una base en blanco.

Tres clases de borrado
----------------------
1. completo  -> tablas que son puro dato del cliente: se vacian enteras.
2. parcial   -> tablas del sistema que ademas guardan filas propias del cliente.
                Los catalogos ampliables (HU-021) llevan columna *_cliente: las
                filas con NULL son del sistema y se quedan; las que apuntan a un
                cliente se van con el. Vaciar esas tablas enteras dejaria a
                SIGMA sin catalogos; no tocarlas dejaria filas huerfanas.
3. autoria   -> una columna que dice QUIEN hizo algo no es lo mismo que una que
                dice DE QUIEN es la fila. La version de un modelo predictivo no
                deja de ser del sistema porque la publicara alguien que ya no
                esta: ahi se anula la autoria y la fila se queda.

Lo que no esta en CONSERVAR se vacia. Es deliberado: una tabla nueva entra al
reinicio sola, y si resultara ser del sistema se agrega aqui a mano. El error
que se prefiere es borrar de mas -hay respaldo- antes que dejar datos viejos del
cliente en una base que se supone en blanco.

Deja _datos/plan.json.
"""
import io, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _comun

_comun.consola()

# ------------------------------------------------- quienes sobreviven al reinicio
# Por login y no por id, para que siga funcionando aunque se recreen en otro orden.
CONSERVAR_LOGIN = ('root@codigocreativo.cl',
                   'emilio@codigocreativo.cl',
                   'catalina@codigocreativo.cl')

# ------------------------------------------------- el sistema, que no se toca
CONSERVAR = set(u"""
Cliente_Usuario_Permiso
Usuario Usuario_Perfil Usuario_Paises Usuario_Password_Historial Usuario_Accesibilidad
Usuario_Recuperacion Usuario_Foto
Perfiles Perfil_Permiso Permiso Permiso_Ambito Tipo_Perfil
Menus Menu_Perfil Menu_Funcion Menu_Funcion_Perfil
Modulos_Sistema Modulo_Codigo Privacidad_Modulos_Sistema Cumplimiento_Politica Sys_Parametros
Suscripcion_Estado Suscripcion_Periodo_Estado Suscripcion_Pago_Estado
Plan_Comercial Plan_Comercial_Funcionalidad Plan_Comercial_Precio
Periodicidad_Cobro Funcionalidad Funcionalidad_Tipo
App Cliente_Binario
Catalogo Paises Idioma Moneda Zona_Horaria Unidad_Medida Unidad_Tiempo Magnitud
Criticidad_Nivel Severidad Tipo_Dato Dia_Semana Frecuencia_Tipo Operador_Comparacion
Entrada_Modo Dato_Origen Etiqueta_Origen Registro_Origen Uf_Origen Valor_Uf
Momento_Ejecucion Rol_Ejecucion Proceso_Estado Medicion_Calidad Diagnostico_Metodo
Dependencia_Accion Resultado_Paso Servicio_Tipo Indisponibilidad_Motivo
Activo_Estado Activo_Posicion_Motivo Activo_Componente_Estado Componente_Tipo Componente_Posicion
Orden_Trabajo_Estado Orden_Trabajo_Tipo Orden_Trabajo_Estrategia Orden_Trabajo_Prioridad
Orden_Trabajo_Origen Orden_Trabajo_Cierre_Motivo Validacion_Tipo
Plan_Ocurrencia_Estado Plan_Version_Estado Programacion_Tipo
Checklist_Item_Tipo Checklist_Version_Estado Checklist_Ocurrencia_Estado
Checklist_Ejecucion_Estado Checklist_Asignacion_Tipo
Tarea_Prioridad Tarea_Ocurrencia_Estado
Inventario_Movimiento_Tipo Repuesto_Tipo Repuesto_Estado_Final Repuesto_Retiro_Motivo
Permiso_Trabajo_Estado Permiso_Trabajo_Tipo
Archivo_Categoria Archivo_Antivirus_Estado Archivo_Carga_Estado
Alerta_Tipo Alerta_Estado Bitacora_Tipo Falla_Modo Falla_Causa
Importacion_Tipo Importacion_Celda_Estado
Modelo_Predictivo Modelo_Predictivo_Version Modelo_Formato Modelo_Objetivo Modelo_Monitoreo
Caracteristica_Modelo Caracteristica_Tipo
Especialidad_Nivel Instalacion_Area_Tipo Voz_Motor Tarea_Categoria
Sis_Excepcion
""".split())

# Estas se van con el cliente aunque suenen a sistema: la afiliacion de una
# persona a un cliente y la suscripcion no sobreviven al cliente que las tenia.
# La suscripcion se vuelve a contratar al recrearlo (HU-191).
DEL_CLIENTE = ('Cliente', 'Cliente_Usuario', 'Cliente_Usuario_Perfil',
               'Cliente_Usuario_Permiso', 'Cliente_Contacto', 'Cliente_Binario',
               'Cliente_App_Instalacion',
               'Suscripcion', 'Suscripcion_Periodo', 'Suscripcion_Pago',
               'Suscripcion_Consumo', 'Suscripcion_Bloqueo_Log',
               'Suscripcion_Key_Historial')

# Una columna de autoria no hace suya la fila.
AUTORIA = ('creacion', 'actualizacion', 'publicacion', 'verificador', '_act')

E = json.load(io.open(_comun.ruta('esquema.json'), encoding='utf-8'))
TABLAS = sorted(t for t in E['tablas'] if t != 'sysdiagrams')
FKS = E['fks']

faltan = CONSERVAR - set(TABLAS)
if faltan:
    print('AVISO · declaradas para conservar pero no existen:', ', '.join(sorted(faltan)))

# ------------------------------------------------------- 1. se vacian enteras
completo = [t for t in TABLAS if t not in CONSERVAR]
for t in DEL_CLIENTE:
    if t in TABLAS and t not in completo:
        completo.append(t)
completo = [t for t in completo if t != 'Cliente'] + ['Cliente']

# -------------------------------------- 2. filas del cliente en tablas del sistema
conservadas = CONSERVAR - set(completo)
LOGINS = ', '.join("'%s'" % l for l in CONSERVAR_LOGIN)
USU = 'SELECT usu_id FROM [dbo].[Usuario] WHERE usu_login NOT IN (%s)' % LOGINS

parcial, anular = [], []
for f in FKS:
    if f['tabla'] not in conservadas:
        continue
    if f['ref_tabla'] == 'Cliente':
        par = (f['tabla'], '[%s] IS NOT NULL' % f['columna'])
        if par not in parcial:
            parcial.append(par)
    elif f['ref_tabla'] == 'Usuario':
        if any(k in f['columna'].lower() for k in AUTORIA):
            par = (f['tabla'], f['columna'])
            if par not in anular:
                anular.append(par)
        else:
            par = (f['tabla'], '[%s] IN (%s)' % (f['columna'], USU))
            if par not in parcial:
                parcial.append(par)

# ------------------------------------------------------------- 3. las personas
parcial.append(('Usuario', 'usu_login NOT IN (%s)' % LOGINS))

json.dump({'conservar_login': list(CONSERVAR_LOGIN),
           'vaciar_completo': completo,
           'vaciar_parcial': parcial,
           'anular_autoria': anular},
          io.open(_comun.ruta('plan.json'), 'w', encoding='utf-8'),
          ensure_ascii=False, indent=1)

print('se vacian enteras:    %d tablas' % len(completo))
print('se limpian en parte:  %d tablas' % len(parcial))
for t, w in parcial:
    print('   %-32s %s' % (t, w if len(w) < 56 else w[:53] + '...'))
print('se anula la autoria:  %d columnas' % len(anular))
for t, c in anular:
    print('   %-32s %s' % (t, c))
print('\nse conservan las cuentas: %s' % ', '.join(CONSERVAR_LOGIN))
print('plan en', _comun.ruta('plan.json'))
