# -*- coding: utf-8 -*-
"""Generacion del Controller (capa de acceso a datos) - PATRON_MVC.md seccion 3."""

from nucleo import util
from .modelo import tipo_filtro


def _valor_parametro(columna, var):
    """Expresion C# para el valor de un parametro del SP."""
    prop = '%s.%s' % (var, columna.prop)
    if columna.tipo.categoria in ('fecha', 'binario'):
        return '(object)%s ?? DBNull.Value' % prop
    if columna.tipo.es_texto and not columna.requerido:
        return '(object)%s ?? DBNull.Value' % prop
    if columna.fk and not columna.requerido:
        # FK opcional: 0 no es un id valido, se manda NULL para no romper la FK.
        return '%s > 0 ? (object)%s : DBNull.Value' % (prop, prop)
    return prop


def _lectura(d, var, indent):
    """Bloque de asignaciones item.x = dr[...] del DataReader."""
    e = d.entidad
    pad = ' ' * indent
    lineas = [pad + '%s.%s = int.Parse(dr["%s"].ToString());' % (var, e.id_prop, e.id_columna)]

    for c in d.columnas:
        if c.control == 'password':
            continue          # el SEL nunca devuelve la password
        lineas.append(pad + '%s.%s = %s;' % (var, c.prop, c.tipo.lector(c.columna, not c.requerido)))

    if d.fks:
        lineas.append('')
        lineas.append(pad + '// Campos del JOIN: se muestran en el grid.')
        for c in d.fks:
            columna = c.fk.prop_denormalizada.upper()
            lineas.append(pad + '%s.%s = dr["%s"].ToString();' % (var, c.fk.prop_denormalizada, columna))

    return '\n'.join(lineas)


def _filtros(d, var, indent):
    e = d.entidad
    pad = ' ' * indent
    l = []
    l.append(pad + 'if (%s.%s > 0)' % (var, e.id_prop))
    l.append(pad + '    cmd.Parameters.AddWithValue("@ID", %s.%s);' % (var, e.id_prop))

    if d.columnas_busqueda:
        l.append('')
        l.append(pad + 'if (!string.IsNullOrEmpty(%s.filtro))' % var)
        l.append(pad + '    cmd.Parameters.AddWithValue("@FILTRO", %s.filtro);' % var)

    if e.habilitado:
        l.append('')
        l.append(pad + 'if (%s.filtro_habilitado.HasValue)' % var)
        l.append(pad + '    cmd.Parameters.AddWithValue("@HABILITADO", %s.filtro_habilitado.Value);' % var)

    for c in d.columnas_filtro:
        campo = '%s.filtro_%s' % (var, c.nombre.lower())
        l.append('')
        if tipo_filtro(c) == 'string':
            l.append(pad + 'if (!string.IsNullOrEmpty(%s))' % campo)
            l.append(pad + '    cmd.Parameters.AddWithValue("%s", %s);' % (c.param, campo))
        else:
            l.append(pad + 'if (%s.HasValue && %s.Value > 0)' % (campo, campo))
            l.append(pad + '    cmd.Parameters.AddWithValue("%s", %s.Value);' % (c.param, campo))

    if e.seguridad_por_pais:
        l.append('')
        l.append(pad + '// Seguridad por pais: CSV de paises permitidos del usuario logueado.')
        l.append(pad + 'if (!string.IsNullOrEmpty(%s.filtro_paises))' % var)
        l.append(pad + '    cmd.Parameters.AddWithValue("@PAISES", %s.filtro_paises);' % var)

    return '\n'.join(l)


def _params_escritura(d, var, incluir_id, indent, password_condicional):
    e = d.entidad
    pad = ' ' * indent
    l = []

    if incluir_id:
        l.append(pad + 'cmdExecute.Parameters.AddWithValue("@ID", %s.%s);' % (var, e.id_prop))

    condicionales = []
    for c in d.columnas:
        if password_condicional and c.control == 'password':
            condicionales.append(c)
            continue
        l.append(pad + 'cmdExecute.Parameters.AddWithValue("%s", %s);'
                 % (c.param, _valor_parametro(c, var)))

    l.append('')
    l.append(pad + '// La auditoria NUNCA la manda la pantalla: se toma de la sesion.')
    l.append(pad + 'cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());')

    for c in condicionales:
        l.append('')
        l.append(pad + '// La %s solo se manda si el usuario la cambio.'
                 % util.sin_acentos(c.etiqueta).lower())
        l.append(pad + '// El SP la actualiza con ISNULL(%s, %s).' % (c.param, c.columna))
        l.append(pad + 'if (!string.IsNullOrEmpty(%s.%s))' % (var, c.prop))
        l.append(pad + '    cmdExecute.Parameters.AddWithValue("%s", %s.%s);' % (c.param, var, c.prop))

    return '\n'.join(l)


def generar(d):
    e = d.entidad
    p = d.proyecto
    var = util.camel(e.singular)

    usings = ['using System;',
              'using System.Collections.Generic;',
              'using System.Data;',
              'using System.Data.SqlClient;',
              'using System.Linq;',
              'using System.Web;',
              'using %s;' % p.ns_model,
              'using SitioBase;']
    for u in p.usings_extra:
        usings.append('using %s;' % u)

    bloque_deshabilitar = ''
    if e.usa_baja_logica:
        bloque_deshabilitar = util.render(r'''

        /// <summary>
        /// BAJA LOGICA: la que realmente usa el boton "Deshabilitar" del grid.
        /// Reutiliza {{SP_UPD}} en vez de crear un SP nuevo.
        /// </summary>
        public Respuesta Deshabilitar{{SINGULAR}}({{CLASE}} {{VAR}})
        {
            {{VAR}}.{{PROP_HABILITADO}} = false;
            Respuesta respuesta = Update{{SINGULAR}}({{VAR}});

            if (!respuesta.error)
                respuesta.detalle = "{{MSG_DESHABILITADO}}";

            return respuesta;
        }''', {
            'SP_UPD': e.sp_upd,
            'SINGULAR': e.singular,
            'CLASE': e.clase_model,
            'VAR': var,
            'PROP_HABILITADO': d.col_habilitado.prop,
            'MSG_DESHABILITADO': e.mensaje('deshabilitado'),
        })

    nota_delete = ('/// BAJA. %s es una tabla MAESTRO: el patron pide baja LOGICA\n'
                   '        /// (%s con @HABILITADO = 0), no DELETE fisico.\n'
                   '        /// %s existe solo para casos excepcionales.'
                   % (e.tabla, e.sp_upd, e.sp_del)) if e.usa_baja_logica else \
                  ('/// BAJA FISICA. %s es una tabla de DETALLE/RELACION,\n'
                   '        /// aqui el DELETE si corresponde.' % e.tabla)

    plantilla = r'''{{USINGS}}

namespace {{NS_CONTROLLER}}
{
    /// <summary>
    /// CONTROLLER de la entidad {{TABLA}}.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 3):
    ///  1. Namespace {{NS_CONTROLLER}}. Una clase por entidad.
    ///  2. TODA operacion arranca con if (Token.TokenSeguridad()).
    ///  3. NUNCA SQL embebido. Siempre Stored Procedures:
    ///        {{SP_SEL}}  {{SP_INS}}  {{SP_UPD}}  {{SP_DEL}}
    ///  4. Acceso a datos SIEMPRE via SitioBase.Conexion.
    ///  5. Los metodos de escritura devuelven SitioBase.Respuesta.
    ///  6. try/catch en todos los metodos, cerrando la conexion en AMBOS caminos.
    ///  7. Los parametros de filtro se agregan SOLO si vienen informados.
    ///
    /// ARCHIVO GENERADO por 03-Generador.
    /// </summary>
    public class {{CLASE_CONTROLLER}}
    {
        #region LECTURA

        /// <summary>
        /// LISTADO. Se usa como DataSource del RadGrid2.
        /// Recibe un Model que actua SOLO como bolsa de filtros.
        /// </summary>
        public List<{{CLASE}}> Get{{PLURAL}}({{CLASE}} {{VAR}} = null)
        {
            List<{{CLASE}}> {{VAR_PLURAL}} = new List<{{CLASE}}>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "{{SP_SEL}}";

                    // Cada filtro se agrega SOLO si viene informado. Lo que no se
                    // agrega llega al SP como NULL y ese IF del WHERE no se concatena.
                    if ({{VAR}} != null)
                    {
{{FILTROS}}
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            {{CLASE}} item = new {{CLASE}}();

{{LECTURA}}

                            {{VAR_PLURAL}}.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    // En los Get devolvemos null para que la vista distinga
                    // "error" de "lista vacia".
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    {{VAR_PLURAL}} = null;
                }
            }

            return {{VAR_PLURAL}};
        }

        /// <summary>
        /// REGISTRO UNICO. Se usa al abrir el formulario de edicion.
        /// Reutiliza el mismo SP {{SP_SEL}} pasandole @ID.
        /// </summary>
        public {{CLASE}} Get{{SINGULAR}}({{CLASE}} {{VAR}})
        {
            {{CLASE}} item = new {{CLASE}}();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "{{SP_SEL}}";
                    cmd.Parameters.AddWithValue("@ID", {{VAR}}.{{ID_PROP}});

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
{{LECTURA_UNICO}}
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    item = null;
                }
            }

            return item;
        }

        #endregion

        #region ESCRITURA

        /// <summary>
        /// ALTA. El SP {{SP_INS}} devuelve el id generado por el parametro @ID OUTPUT.
        /// </summary>
        public Respuesta Insert{{SINGULAR}}({{CLASE}} {{VAR}})
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    int id = 0;
                    cmdExecute = Conexion.GetCommand("{{SP_INS}}");

                    // @ID SIEMPRE primero y como OUTPUT: el SP hace SET @ID = SCOPE_IDENTITY().
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;

{{PARAMS_INSERT}}

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "{{MSG_CREADO}}";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    // ex.Message trae el texto del RAISERROR del SP.
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// MODIFICACION. Mismo patron que el alta pero con @ID de entrada.
        /// </summary>
        public Respuesta Update{{SINGULAR}}({{CLASE}} {{VAR}})
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("{{SP_UPD}}");

{{PARAMS_UPDATE}}

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = {{VAR}}.{{ID_PROP}};
                    respuesta.detalle = "{{MSG_ACTUALIZADO}}";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        {{NOTA_DELETE}}
        /// </summary>
        public Respuesta Delete{{SINGULAR}}({{CLASE}} {{VAR}})
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("{{SP_DEL}}");
                    cmdExecute.Parameters.AddWithValue("@ID", {{VAR}}.{{ID_PROP}});

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = {{VAR}}.{{ID_PROP}};
                    respuesta.detalle = "{{MSG_ELIMINADO}}";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }{{DESHABILITAR}}

        #endregion
    }
}'''

    return util.render(plantilla, {
        'USINGS': '\n'.join(usings),
        'NS_CONTROLLER': p.ns_controller,
        'TABLA': e.tabla,
        'SP_SEL': e.sp_sel,
        'SP_INS': e.sp_ins,
        'SP_UPD': e.sp_upd,
        'SP_DEL': e.sp_del,
        'CLASE_CONTROLLER': e.clase_controller,
        'CLASE': e.clase_model,
        'SINGULAR': e.singular,
        'PLURAL': e.plural,
        'VAR': var,
        'VAR_PLURAL': util.camel(e.plural),
        'ID_PROP': e.id_prop,
        'FILTROS': _filtros(d, var, 24),
        'LECTURA': _lectura(d, 'item', 28),
        'LECTURA_UNICO': _lectura(d, 'item', 28),
        'PARAMS_INSERT': _params_escritura(d, var, False, 20, False),
        'PARAMS_UPDATE': _params_escritura(d, var, True, 20, True),
        'MSG_CREADO': e.mensaje('creado'),
        'MSG_ACTUALIZADO': e.mensaje('actualizado'),
        'MSG_ELIMINADO': e.mensaje('eliminado'),
        'NOTA_DELETE': nota_delete,
        'DESHABILITAR': bloque_deshabilitar,
    })
