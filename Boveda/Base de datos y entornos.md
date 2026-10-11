# Base de datos y entornos
- Dev: SQL remoto MonsterASP (db71936). Alternativa evaluada: Azure SQL gratuita (West US 2) con indicador de cupo (`WsAzureCupo`, `Dev/conectar_azure.ps1`); `data.config` se dejó como estaba.
- Producción: SmarterASP (Web Deploy; requiere contraseña del usuario). Migraciones pendientes allí: 429–436. Faltan `Min Pool Size=20` e `IdFirma`.
- Scripts: `BD/NNN_*.sql` numerados; cargas en `BD/Carga masiva/` (plan Blowers Hamburgo, componentes/repuestos).
- Respaldos y evidencia viven en `C:\Capstone\_scratch`, fuera del repo.
- Claves nunca por chat ni en el MD.
