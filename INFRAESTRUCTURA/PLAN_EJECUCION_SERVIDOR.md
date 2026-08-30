# Plan de ejecución — Servidor SIGMA en Hyper-V + Tailscale

**Equipo:** 3 personas · **Anfitrión:** BCHAVEZ-VICTUS (Windows 11 Pro, i7-13700H, 16 GB RAM)
**VM:** Windows Server 2022 evaluación · **Disco:** C: · **Acceso remoto:** Tailscale

---

## Lo que ya quedó descartado (no lo hagas)

Con Tailscale **no necesitas nada de esto**, y es bueno que lo sepas para no perder tiempo:

- ❌ Verificar si tu ISP usa CGNAT
- ❌ Entrar al módem a redirigir puertos
- ❌ Configurar DDNS / No-IP / DuckDNS
- ❌ Preocuparte de que tu IP pública `143.255.179.247` cambie
- ❌ Exponer el puerto 1433 a Internet

Tu servidor **nunca queda visible desde Internet**. Solo los 3 del equipo lo ven, por una red privada cifrada.

---

## ⚠️ Advertencia crítica antes de empezar

**NO guardes la máquina virtual dentro de tu carpeta de OneDrive.**

Tu carpeta CAPSTONE está en `C:\Users\Bchavez1\OneDrive - OUTSOURCING Inc\...`. Si pones el disco virtual ahí, OneDrive va a intentar sincronizar un archivo de 60 GB que cambia constantemente. El resultado: el disco se llena, la sincronización se cae, y el rendimiento de la VM se vuelve inutilizable.

**Usa `C:\HyperV`** (fuera de OneDrive). Esta guía ya lo hace así.

---

## Presupuesto de disco — para que sepas si te va a alcanzar

| Concepto | Espacio |
|---|---|
| Espacio libre actual | ~92 GB |
| **A liberar en la Fase 0** | **+25 a 35 GB** |
| Espacio disponible tras limpiar | ~120 GB |
| VHDX de la VM (crecimiento real esperado) | −40 a 45 GB |
| **Margen final** | **~75 GB** ✅ |
| Peor caso (si el VHDX llegara a los 60 GB completos) | ~57 GB ✅ |

El VHDX se declara de 60 GB pero es **dinámico**: crece según lo que uses. En la práctica, Server 2022 + SQL Express + actualizaciones + la BD de SIGMA queda en unos 40-45 GB.

> Si tras la Fase 0 no logras superar los **110 GB libres**, avísame y ajustamos: se puede bajar el VHDX a 45 GB y mover la BD a un pendrive USB 3.

---

# FASE 0 — Liberar espacio en C:

Abre **PowerShell como Administrador** (clic derecho en Inicio → Terminal (Administrador)).

## 0.1 — Mide el punto de partida

```powershell
Get-Volume C | Select-Object DriveLetter,
    @{n='LibreGB'; e={[math]::Round($_.SizeRemaining/1GB,1)}},
    @{n='TotalGB'; e={[math]::Round($_.Size/1GB,1)}}
```

Anota el número. Al final de la fase lo vuelves a correr para ver cuánto ganaste.

## 0.2 — Desactivar hibernación (ganancia: ~6 GB)

`hiberfil.sys` ocupa cerca del 40% de tu RAM, o sea ~6,4 GB en tu equipo.

```powershell
powercfg /h off
```

> **Contrapartida honesta:** pierdes la hibernación y el "inicio rápido". En un notebook que usas a diario esto se nota — el arranque será algo más lento y al cerrar la tapa se suspende (RAM) en vez de hibernar (disco). Si prefieres conservarla, sáltate este paso y compénsalo en los siguientes. Para revertirlo: `powercfg /h on`.

## 0.3 — Limpiar componentes de Windows (ganancia: 5-15 GB)

Esto elimina versiones antiguas de actualizaciones que Windows guarda "por si acaso".

```powershell
Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
```

Tarda entre 10 y 30 minutos. Déjalo correr.

> Tras esto **no podrás desinstalar actualizaciones ya aplicadas**. En la práctica no es un problema.

## 0.4 — Archivos temporales (ganancia: 2-8 GB)

```powershell
Remove-Item "$env:TEMP\*"        -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Temp\*"  -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
```

## 0.5 — Liberador de espacio de Windows (ganancia: variable)

```powershell
cleanmgr /d C:
```

Marca todo, prestando atención a: *Instalaciones anteriores de Windows*, *Archivos de optimización de entrega*, *Papelera de reciclaje*, *Archivos temporales de Internet*.

> Si aparece **"Instalaciones anteriores de Windows"** (`Windows.old`), ahí solos hay 15-25 GB. Es la ganancia más grande de toda la fase.

## 0.6 — Encontrar qué te está comiendo el disco

Para ver dónde está el resto, descarga **[WizTree](https://diskanalyzer.com/)** (gratis, tarda segundos). Es mucho más rápido que cualquier script.

Alternativa en PowerShell (más lenta, unos minutos):

```powershell
Get-ChildItem C:\ -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $s = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
          Measure-Object Length -Sum).Sum
    [PSCustomObject]@{ Carpeta = $_.Name; GB = [math]::Round($s/1GB, 2) }
} | Sort-Object GB -Descending | Select-Object -First 15
```

Sospechosos habituales en un equipo de desarrollo: caché de NuGet, `node_modules`, imágenes de Docker, instaladores viejos en Descargas, y la caché de Visual Studio.

```powershell
# Caché de NuGet (se regenera sola, es seguro borrarla)
dotnet nuget locals all --clear
```

## ✅ Punto de control 0

```powershell
Get-Volume C | Select-Object DriveLetter, @{n='LibreGB'; e={[math]::Round($_.SizeRemaining/1GB,1)}}
```

**Necesitas al menos 110 GB libres para seguir con comodidad.** Si no llegaste, avísame antes de continuar.

---

# FASE 1 — Habilitar Hyper-V

## 1.1 — Activar la característica

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

Reinicia cuando lo pida.

## 1.2 — Verificar

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | Select-Object State
```

Debe decir `Enabled`.

> Si falla: reinicia, entra a la BIOS del Victus con **F10**, y activa *Virtualization Technology (VT-x)* en `Advanced → System Options`.

## ✅ Punto de control 1

```powershell
Get-Command Get-VM   # si responde, Hyper-V está operativo
```

---

# FASE 2 — Crear el switch y la máquina virtual

## 2.1 — Conecta el cable de red

Antes de crear el switch: **conecta el notebook al módem por cable Ethernet**. El switch externo sobre Wi-Fi funciona pero da problemas intermitentes de conectividad, y para un servidor eso significa que se va a caer sin razón aparente. Si el Victus no trae puerto RJ45, un adaptador USB-C a Ethernet cuesta poco y te evita horas de diagnóstico.

## 2.2 — Crear el switch externo

```powershell
# Ver los adaptadores activos
Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, InterfaceDescription
```

Con el nombre exacto que te salió (típicamente `Ethernet`):

```powershell
New-VMSwitch -Name "SW-Externo" -NetAdapterName "Ethernet" -AllowManagementOS $true
```

> Vas a perder la red unos segundos. Es normal.

## 2.3 — Crear la VM

```powershell
$vm   = "SIGMA-SRV"
$ruta = "C:\HyperV"                 # <-- FUERA de OneDrive

New-Item -ItemType Directory -Path $ruta -Force

New-VM -Name $vm `
       -MemoryStartupBytes 4GB `
       -Generation 2 `
       -NewVHDPath "$ruta\$vm.vhdx" `
       -NewVHDSizeBytes 60GB `
       -SwitchName "SW-Externo" `
       -Path $ruta

Set-VM -Name $vm `
       -ProcessorCount 4 `
       -DynamicMemory -MemoryMinimumBytes 2GB -MemoryMaximumBytes 6GB `
       -AutomaticStartAction Start `
       -AutomaticStopAction Save
```

**Sobre los recursos:** el tope de 6 GB deja 10 GB al anfitrión. Con 16 GB totales y Visual Studio abierto, subir de ahí te va a hacer sufrir. La memoria dinámica hace que la VM devuelva lo que no usa.

## 2.4 — Fijar la MAC

Hyper-V puede cambiar la MAC dinámicamente, lo que rompería la reserva DHCP de la Fase 4. Fíjala ahora:

```powershell
Set-VMNetworkAdapter -VMName $vm -StaticMacAddress "00155D0A0B0C"
Get-VMNetworkAdapter -VMName $vm | Select-Object MacAddress
```

**Anota esa MAC.** La necesitas en la Fase 4.

## 2.5 — Montar la ISO y arrancar

Descarga **Windows Server 2022 Standard (evaluación, 180 días)** desde el [Centro de evaluación de Microsoft](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022).

```powershell
$iso = "C:\ISO\WindowsServer2022.iso"    # <-- ajusta a tu ruta

Add-VMDvdDrive -VMName $vm -Path $iso

# Generación 2 arranca por UEFI: hay que indicarle que parta del DVD
$dvd = Get-VMDvdDrive -VMName $vm
Set-VMFirmware -VMName $vm -FirstBootDevice $dvd

Start-VM -Name $vm
vmconnect.exe localhost $vm
```

## ✅ Punto de control 2

La ventana de la VM debe mostrar el instalador de Windows Server.

---

# FASE 3 — Instalar Windows Server 2022

Dentro de la ventana de la VM:

1. Idioma → **Siguiente** → **Instalar ahora**
2. Edición: **Windows Server 2022 Standard Evaluation (Experiencia de escritorio)**
   > Elige la que dice *Experiencia de escritorio* / *Desktop Experience*. Server Core no tiene interfaz gráfica y te va a complicar sin necesidad.
3. **Personalizada: instalar solo Windows**
4. Selecciona el disco de 60 GB → **Siguiente**
5. Espera (10-20 min) y define la contraseña de Administrador
   > Usa una contraseña larga y guárdala donde el equipo la pueda consultar.

## 3.1 — Activar la evaluación (no lo dejes para después)

**Tienes 10 días o la VM empieza a apagarse sola cada hora.** Dentro de la VM, con Internet funcionando:

```powershell
slmgr /ato
```

## 3.2 — Quitar el DVD

Desde el **anfitrión**, con la VM ya instalada:

```powershell
Remove-VMDvdDrive -VMName "SIGMA-SRV" -ControllerNumber 0 -ControllerLocation 1
```

## 3.3 — Renombrar la VM

Dentro de la VM:

```powershell
Rename-Computer -NewName "SIGMA-SRV" -Restart
```

## ✅ Punto de control 3

Dentro de la VM:

```powershell
Test-NetConnection google.com
```

Debe decir `TcpTestSucceeded : True`. Si no hay Internet, revisa que el switch sea externo (`Get-VMSwitch` en el anfitrión debe decir `External`).

---

# FASE 4 — IP fija en tu red local

Tailscale te va a dar la dirección estable para el acceso remoto, pero una IP fija en la LAN sigue siendo útil: te permite administrar la VM por RDP desde tu propio notebook sin buscar la IP cada vez.

## 4.1 — Ver el rango de tu red

En el **anfitrión**:

```powershell
Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway
```

Supongamos que el resultado es red `192.168.1.x` y puerta de enlace `192.168.1.1`. Si tu red es distinta (`192.168.0.x`, `10.0.0.x`), ajusta los valores que siguen.

## 4.2 — Configurar la IP dentro de la VM

Es lo más rápido. Dentro de la VM:

```powershell
$if = (Get-NetAdapter | Where-Object Status -eq 'Up').Name

New-NetIPAddress -InterfaceAlias $if `
                 -IPAddress 192.168.1.50 `
                 -PrefixLength 24 `
                 -DefaultGateway 192.168.1.1

Set-DnsClientServerAddress -InterfaceAlias $if -ServerAddresses 1.1.1.1, 8.8.8.8
```

> **Elige una IP fuera del rango DHCP del módem.** La mayoría reparte desde `.100` en adelante, así que `.50` suele ser seguro. Si al terminar tienes conflictos de IP, entra al módem (`LAN → DHCP`) y confirma desde qué número reparte.

## ✅ Punto de control 4

Desde el **anfitrión**:

```powershell
Test-NetConnection 192.168.1.50
```

Debe responder `PingSucceeded : True`.

---

# FASE 5 — IIS, SQL Server y firewall

Todo esto va **dentro de la VM**.

## 5.1 — IIS con soporte ASP.NET

```powershell
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter
```

Verifica: en el anfitrión, abre `http://192.168.1.50` → debe aparecer la página por defecto de IIS.

## 5.2 — SQL Server 2022 Express

Descarga desde el [sitio de Microsoft](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) (elige **Express**).

Durante la instalación:

- Tipo: **Personalizada** → *Nueva instalación independiente*
- Modo de autenticación: **Mixto**
- Contraseña de `sa`: **larga y aleatoria** (20+ caracteres). No la reutilices de otro sitio.
- Agrega tu usuario como administrador de SQL Server

Después, habilita TCP/IP (viene apagado por defecto):

1. Abre **SQL Server Configuration Manager**
2. `SQL Server Network Configuration → Protocols for SQLEXPRESS → TCP/IP` → **Enabled**
3. Doble clic en TCP/IP → pestaña *IP Addresses* → al final, en **IPAll**, pon `TCP Port = 1433` y deja *TCP Dynamic Ports* vacío
4. `SQL Server Services` → clic derecho en el servicio → **Restart**

> **Límite de Express:** 10 GB por base de datos y 1,4 GB de RAM para caché. Para SIGMA en un CAPSTONE va sobrado. Si algún día te queda corto, SQL Server **Developer** es igual de gratis y sin límites — solo pesa más en disco (~8 GB), que es justo lo que estamos cuidando.

Instala también **SQL Server Management Studio (SSMS)** dentro de la VM para administrarla.

## 5.3 — Reglas de firewall

Aquí está la decisión de seguridad importante: **SQL Server solo acepta conexiones de tu red local y de Tailscale**, nunca de Internet.

```powershell
# IIS
New-NetFirewallRule -DisplayName "HTTP entrante" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow

# SQL Server: solo LAN
New-NetFirewallRule -DisplayName "SQL Server (LAN)" -Direction Inbound -Protocol TCP -LocalPort 1433 `
                    -RemoteAddress 192.168.1.0/24 -Action Allow

# SQL Server: solo Tailscale (rango 100.64.0.0/10)
New-NetFirewallRule -DisplayName "SQL Server (Tailscale)" -Direction Inbound -Protocol TCP -LocalPort 1433 `
                    -RemoteAddress 100.64.0.0/10 -Action Allow

# RDP: LAN + Tailscale
New-NetFirewallRule -DisplayName "RDP (LAN)" -Direction Inbound -Protocol TCP -LocalPort 3389 `
                    -RemoteAddress 192.168.1.0/24 -Action Allow
New-NetFirewallRule -DisplayName "RDP (Tailscale)" -Direction Inbound -Protocol TCP -LocalPort 3389 `
                    -RemoteAddress 100.64.0.0/10 -Action Allow
```

Habilita RDP:

```powershell
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
                 -Name "fDenyTSConnections" -Value 0
```

## ✅ Punto de control 5

Desde el **anfitrión**:

```powershell
Test-NetConnection 192.168.1.50 -Port 80      # IIS
Test-NetConnection 192.168.1.50 -Port 1433    # SQL
```

Ambos deben dar `TcpTestSucceeded : True`.

---

# FASE 6 — Tailscale (el acceso remoto)

Esta es la fase que reemplaza toda la configuración del módem. Toma unos 15 minutos.

## 6.1 — Crear la cuenta

Ve a [tailscale.com](https://tailscale.com) y crea una cuenta gratuita (con Google, GitHub o Microsoft). Esa cuenta es la dueña de la red privada (*tailnet*).

> Usa una cuenta que vaya a seguir existiendo todo el semestre. Si usas la institucional y se cierra al terminar el ramo, pierdes la red.

## 6.2 — Instalar en la VM

Dentro de la VM, descarga el instalador de Windows desde [tailscale.com/download](https://tailscale.com/download), instálalo e inicia sesión.

```powershell
tailscale ip -4
```

Anota la IP que devuelve (algo como `100.101.102.103`). **Esta es la "IP fija" que buscabas**: no cambia nunca y funciona desde cualquier red del mundo.

## 6.3 — Desactivar la caducidad de la clave

Sin esto, la autenticación del servidor **expira a los ~6 meses** y se desconecta solo — justo a mitad de semestre.

1. Entra a [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines)
2. Busca `SIGMA-SRV`
3. Menú `⋯` → **Disable key expiry**

## 6.4 — Activar MagicDNS

En la consola → **DNS** → activa **MagicDNS**. Así el equipo se conecta con `sigma-srv` en vez de memorizar la IP.

## 6.5 — Invitar a tus 2 compañeros

Consola → **Users** → **Invite users** → envíales el link por correo.

Cada uno instala Tailscale en su equipo, acepta la invitación, e inicia sesión. Eso es todo lo que tienen que hacer.

> El plan gratuito cubre **6 usuarios y dispositivos ilimitados**. Ustedes son 3, así que tienen holgura para agregar al profesor o a un segundo equipo por persona.

## 6.6 — Cómo se conecta el equipo

Con Tailscale corriendo, desde cualquier parte:

| Servicio | Dirección |
|---|---|
| Sitio SIGMA | `http://sigma-srv` |
| SQL Server (SSMS) | `sigma-srv,1433` — autenticación de SQL Server |
| Escritorio remoto | `mstsc /v:sigma-srv` |

## ✅ Punto de control 6 — la prueba real

**Desconecta tu notebook del Wi-Fi de casa y conéctalo a los datos móviles de tu celular.** Con Tailscale activo, abre `http://sigma-srv`.

Si ves la página de IIS, **ya está funcionando**. Pídele a un compañero que lo pruebe desde su casa.

---

# FASE 7 — Que el servidor siga vivo

El detalle incómodo: tu servidor es tu notebook. Si lo cierras, se suspende y el equipo pierde acceso.

## 7.1 — Que no se suspenda

En el anfitrión, `Configuración → Sistema → Inicio/apagado y batería`:

- **Conectado a corriente:** pantalla y suspensión en **Nunca**
- `Panel de control → Opciones de energía → Elegir el comportamiento del cierre de la tapa` → **Conectado: No hacer nada**

```powershell
# Equivalente por comando (con el equipo enchufado)
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 15
```

## 7.2 — Arranque automático de la VM

Ya quedó configurado con `-AutomaticStartAction Start` en la Fase 2. Verifica:

```powershell
Get-VM "SIGMA-SRV" | Select-Object Name, AutomaticStartAction, AutomaticStopAction
```

## 7.3 — Respaldo

Un CAPSTONE perdido por un disco muerto es una historia que se repite cada semestre. Una vez al mes, o antes de cada entrega:

```powershell
Stop-VM -Name "SIGMA-SRV"
Export-VM -Name "SIGMA-SRV" -Path "D:\Respaldos"   # a un disco externo
Start-VM -Name "SIGMA-SRV"
```

Y lo más importante: **el código y los scripts de BD viven en Git**, no solo dentro de la VM. La VM debe ser reemplazable.

```powershell
# Respaldo de la BD dentro de la VM (rápido y liviano)
sqlcmd -S localhost -Q "BACKUP DATABASE SIGMA TO DISK='C:\Respaldos\SIGMA.bak' WITH INIT, COMPRESSION"
```

---

# Resumen de verificación

| # | Fase | Comprobación | Estado |
|---|---|---|---|
| 0 | Espacio | ≥110 GB libres en C: | ☐ |
| 1 | Hyper-V | `Get-Command Get-VM` responde | ☐ |
| 2 | VM creada | Arranca el instalador | ☐ |
| 3 | Server 2022 | `Test-NetConnection google.com` OK + `slmgr /ato` | ☐ |
| 4 | IP fija | Ping a `192.168.1.50` desde el anfitrión | ☐ |
| 5 | Servicios | Puertos 80 y 1433 responden en la LAN | ☐ |
| 6 | Tailscale | `http://sigma-srv` desde datos móviles | ☐ |
| 7 | Persistencia | La VM arranca sola y el notebook no se suspende | ☐ |

---

# Si algo falla

| Síntoma | Causa | Solución |
|---|---|---|
| `Enable-WindowsOptionalFeature` falla | VT-x apagado | Activarlo en la BIOS (F10 al arrancar) |
| La VM no tiene Internet | Switch no es externo | `Get-VMSwitch` debe decir `External` |
| Conflicto de IP en la red | `.50` está dentro del rango DHCP | Revisar el rango en el módem y elegir otra |
| La VM se apaga sola cada hora | Evaluación sin activar | `slmgr /ato` dentro de la VM |
| SQL no acepta conexiones remotas | TCP/IP deshabilitado | Habilitarlo en Configuration Manager y reiniciar el servicio |
| SSMS no conecta por Tailscale | Falta la regla de firewall | Revisar la regla con `100.64.0.0/10` |
| Tailscale conecta pero va lento | Relay en vez de conexión directa | `tailscale status` — si dice `relay`, normal tras CGNAT; funciona igual |
| El servidor desaparece a los ~6 meses | Caducó la clave del nodo | *Disable key expiry* (Paso 6.3) |
| El notebook se arrastra | La VM toma mucha RAM | Bajar `-MemoryMaximumBytes` a 4GB |
| OneDrive se vuelve loco | El VHDX quedó dentro de OneDrive | Mover la VM a `C:\HyperV` |

---

## Fuentes

- [Install Hyper-V in Windows and Windows Server — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/install-hyper-v)
- [Windows Server 2022 — Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022)
- [SQL Server Downloads — Microsoft](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- [Free pricing plans and discounts — Tailscale Docs](https://tailscale.com/docs/account/manage-plans/free-plans-discounts)
