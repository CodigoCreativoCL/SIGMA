USE [db_acd593_sigma]
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA:           20-08-2026
-- DESCRIPTION:     BLOQUE RETIRADO. NO CREA NADA.
-- =============================================
-- Este archivo creaba Servicio_Nube_Tarifa y Consumo_Servicio_Nube, mas
-- los catalogos Proveedor_Nube, Servicio_Nube y Unidad_Consumo. Se retiro
-- el 20-08-2026 por decision de producto.
--
-- POR QUE SE RETIRO
--   SIGMA corre sobre SmarterASP Premium, que es una FACTURA FIJA MENSUAL:
--   no varia con cuantos clientes usen el sistema. La voz corre en el
--   telefono, sin costo por minuto. No hay consumo variable que medir.
--
--   Medir por cliente algo que llega como un unico monto fijo no produce
--   un dato: produce un numero inventado. Repartir 12,50 USD entre tres
--   clientes daria una cifra distinta cada mes segun cuantos clientes haya,
--   sin que nada del consumo real haya cambiado.
--
--   El analisis de retorno sigue existiendo y esta donde corresponde:
--   SIGMA_ANEXO_G_COSTOS_RETORNO.md. Es un argumento comercial, no un dato
--   transaccional, y por eso vive en un documento y no en una tabla.
--
-- QUE HACER CON ESTE ARCHIVO
--   Borrarlo. Ya no esta en 00_MAESTRO.sql y no se ejecuta.
--   Se deja este texto en su lugar para que quien lo encuentre en un
--   respaldo sepa por que desaparecio, en vez de suponer que se perdio.
--
-- SI LAS TABLAS YA SE CREARON EN LA BASE
--   Descomentar el bloque de abajo y ejecutarlo UNA vez.
-- =============================================

PRINT 'Bloque 09 COSTOS DE NUBE: retirado el 20-08-2026. No hace nada.'
GO

/*
-- Limpieza, solo si las tablas alcanzaron a crearse.
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Consumo_Servicio_Nube]') AND type = 'U')
    DROP TABLE [dbo].[Consumo_Servicio_Nube]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Servicio_Nube_Tarifa]') AND type = 'U')
    DROP TABLE [dbo].[Servicio_Nube_Tarifa]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Proveedor_Nube]') AND type = 'U')
    DROP TABLE [dbo].[Proveedor_Nube]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Servicio_Nube]') AND type = 'U')
    DROP TABLE [dbo].[Servicio_Nube]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Unidad_Consumo]') AND type = 'U')
    DROP TABLE [dbo].[Unidad_Consumo]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VW_RENTABILIDAD_CLIENTE_MES]') AND type = 'V')
    DROP VIEW [dbo].[VW_RENTABILIDAD_CLIENTE_MES]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VW_SALUD_INFRAESTRUCTURA]') AND type = 'V')
    DROP VIEW [dbo].[VW_SALUD_INFRAESTRUCTURA]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FNC_TARIFA_NUBE]') AND type IN ('FN','IF','TF'))
    DROP FUNCTION [dbo].[FNC_TARIFA_NUBE]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FNC_CLIENTE_CONSUMO_NUBE]') AND type IN ('FN','IF','TF'))
    DROP FUNCTION [dbo].[FNC_CLIENTE_CONSUMO_NUBE]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[INS_CONSUMO_SERVICIO_NUBE]') AND type = 'P')
    DROP PROCEDURE [dbo].[INS_CONSUMO_SERVICIO_NUBE]
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPD_CONSUMO_SERVICIO_NUBE_CIERRE]') AND type = 'P')
    DROP PROCEDURE [dbo].[UPD_CONSUMO_SERVICIO_NUBE_CIERRE]
GO
*/
