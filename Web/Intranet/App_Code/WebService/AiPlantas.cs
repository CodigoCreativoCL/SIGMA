using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;

/// <summary>
/// El filtro por planta de SIGMA AI (Centro e Inicio). Las plantas que la persona puede ver son las
/// asignadas a su usuario en este cliente; si no tiene ninguna asignada (por ejemplo soporte) ve todas.
/// </summary>
public static class AiPlantas
{
    /// <summary>Las plantas vigentes de la persona; null = sin restriccion.</summary>
    private static HashSet<int> Mias()
    {
        int u; if (!int.TryParse(SitioBase.Session.UsuarioId(), out u)) return null;
        List<ClienteUsuarioPlanta> l;
        try { l = new ClienteUsuarioController().PlantasDelUsuario(u, SitioBase.Session.ClienteId()) ?? new List<ClienteUsuarioPlanta>(); }
        catch (Exception) { return null; }
        if (l.Count == 0) return null;
        DateTime hoy = global::SitioBase.Hora.Hoy;
        return new HashSet<int>(l.Where(p => p.habilitada && (p.fecha_inicio == null || p.fecha_inicio.Value.Date <= hoy) && (p.fecha_fin == null || p.fecha_fin.Value.Date >= hoy))
                                 .Select(p => p.instalacion));
    }

    /// <summary>Las plantas para el combo: {id, nombre}.</summary>
    public static List<object> Lista()
    {
        ClienteInstalacion f = new ClienteInstalacion();
        f.filtro_cliente = SitioBase.Session.ClienteId().ToString();
        f.filtro_habilitado = "1";
        HashSet<int> mias = Mias();
        return (new ClienteInstalacionController().GetClienteInstalaciones(f) ?? new List<ClienteInstalacion>())
            .Where(p => mias == null || mias.Contains(p.cin_id))
            .OrderBy(p => p.cin_nombre)
            .Select(p => (object)new { id = p.cin_id, nombre = p.cin_nombre }).ToList();
    }

    /// <summary>
    /// El valor del parametro @PLANTAS de los SP: una planta, o las de la persona si pidio «todas»
    /// (null = sin filtro). Una planta ajena (por ejemplo una recordada de otra sesion) se trata como «todas».
    /// </summary>
    public static string Filtro(int planta)
    {
        HashSet<int> mias = Mias();
        if (planta > 0 && (mias == null || mias.Contains(planta))) return planta.ToString();
        return mias == null ? null : (mias.Count == 0 ? "0" : string.Join(",", mias));
    }
}
