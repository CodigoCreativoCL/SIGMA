# Guía — Servidor virtual en Hyper-V con IP fija y acceso desde otra red

**Equipo Código Creativo · CAPSTONE · Proyecto SIGMA**
Equipo anfitrión: `BCHAVEZ-VICTUS` · i7-13700H · 16 GB RAM · 862/954 GB usados

---

## ⚠️ Léelo antes de empezar

Hay **tres cosas** que pueden hacer que todo este trabajo no sirva. Verifícalas primero — te toma 10 minutos y te ahorra una tarde entera.

### 1. ¿Tu Windows tiene Hyper-V?

Hyper-V **no existe en Windows 11 Home**. Los notebooks Victus vienen de fábrica con Home muy seguido.

```powershell
# PowerShell como Administrador
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion
```

- Si dice **Pro / Enterprise / Education** → sigue adelante.
- Si dice **Home** → tienes que actualizar a Pro (licencia de pago) o usar VirtualBox / VMware Workstation en su lugar. Los pasos de red de esta guía sirven igual; solo cambia la parte de crear la VM.

### 2. Espacio en disco — este es tu cuello de botella real

Tienes **~92 GB libres de 954 GB**. Eso es muy justo:

| Componente | Espacio |
|---|---|
| Windows Server 2025 (instalación base) | ~15 GB |
| SQL Server 2022 Developer | ~8 GB |
| Actualizaciones + página de intercambio | ~10 GB |
| Base de datos SIGMA + crecimiento del semestre | ~10-20 GB |
| **Mínimo realista** | **~50 GB** |

Con 92 GB libres alcanza, pero vas a quedar al límite y Windows empieza a comportarse mal bajo ~15 GB libres. **Recomendación fuerte:** libera espacio antes (`Configuración → Sistema → Almacenamiento → Recomendaciones de limpieza`) o compra un SSD externo USB 3.2 / NVMe y aloja ahí el disco virtual. Un SSD externo de 500 GB es barato y te sirve todo el semestre.

> No uses un disco duro externo mecánico: el rendimiento de SQL Server sería inaceptable.

### 3. ¿Tu conexión está detrás de CGNAT?

**Este es el chequeo más importante.** Si tu ISP usa CGNAT (muy común en Chile: Movistar, Mundo, WOM, Entel en planes residenciales), **la redirección de puertos NO va a funcionar**, hagas lo que hagas en el módem.

Cómo verificarlo:

```powershell
# 1. Tu IP pública real, vista desde Internet
curl.exe https://api.ipify.org
```

```
2. Entra al módem (normalmente http://192.168.1.1 o http://192.168.0.1)
   y busca "Estado" / "WAN" / "Internet". Anota la IP WAN que muestra.
```

**Compara las dos:**

| Resultado | Significa |
|---|---|
| Son **iguales** | ✅ Tienes IP pública. La redirección de puertos funcionará. |
| Son **distintas**, y la del módem empieza en `100.64.` a `100.127.` | ❌ **CGNAT.** La redirección de puertos no funcionará. |
| Son **distintas**, y la del módem es `10.x`, `172.16-31.x` o `192.168.x` | ❌ CGNAT o doble NAT. |

**Si estás en CGNAT** tienes dos salidas: pedirle a tu ISP una IP pública (a veces es gratis, a veces tiene costo mensual), o usar la **Opción A** de esta guía (Tailscale), que funciona igual de bien y **no le importa el CGNAT**.

---

## 📌 Recomendación: lee esto antes de decidir

Vas a exponer **IIS + SQL Server**. Sobre eso quiero ser directo contigo:

**Exponer SQL Server (puerto 1433) a Internet es una mala idea.** No es una precaución teórica: hay bots que escanean el rango completo de IPv4 buscando el puerto 1433 abierto, y prueban credenciales `sa` con diccionario de forma continua. Un servidor SQL expuesto con una contraseña débil dura horas, no días. El resultado típico es ransomware o minado de criptomonedas en tu equipo.

Además, si el servidor es tu **notebook personal**, cualquier compromiso de la VM es un salto directo hacia tu red doméstica y tus archivos.

Por eso esta guía te da **dos caminos**:

| | **Opción A — Tailscale** | **Opción B — Redirección de puertos** |
|---|---|---|
| Dificultad | Baja (15 min) | Media-alta (1-2 h) |
| Funciona con CGNAT | ✅ Sí | ❌ No |
| Necesita IP pública fija | No | Sí (o DDNS) |
| Exposición a Internet | **Ninguna** | Total |
| Riesgo de que te hackeen | Muy bajo | Alto si te descuidas |
| Tus compañeros necesitan | Instalar una app y aceptar invitación | Nada |
| Costo | Gratis (6 usuarios) | Gratis |

**Para un CAPSTONE con 4-6 personas del equipo, la Opción A es objetivamente la mejor.** No es "la fácil": es la correcta. La Opción B tiene sentido si necesitas que el sitio sea **público** (que cualquiera con el link entre, por ejemplo para una demo abierta o para el profesor sin instalar nada).

Puedes hacer las dos: Tailscale para SQL Server (equipo) + puertos 80/443 para IIS (público). Es la combinación que recomiendo si necesitas demo pública.

---

# PARTE 1 — Preparar Hyper-V en el anfitrión

## Paso 1.1 — Habilitar Hyper-V

PowerShell **como Administrador**:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

Reinicia el equipo cuando te lo pida.

Verifica que quedó activo:

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | Select-Object State
```

> Si falla con "no se puede completar", entra a la BIOS/UEFI del Victus (F10 al arrancar) y activa **Intel VT-x / Virtualization Technology**.

## Paso 1.2 — Crear el switch virtual externo

Esto es lo que hace que la VM tenga **su propia IP en tu red doméstica**, como si fuera un computador más conectado al módem. Es imprescindible para lo que quieres hacer.

Primero mira qué adaptadores tienes:

```powershell
Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, InterfaceDescription, LinkSpeed
```

Crea el switch (reemplaza `Ethernet` por el nombre exacto que te salió):

```powershell
New-VMSwitch -Name "SW-Externo" -NetAdapterName "Ethernet" -AllowManagementOS $true
```

> ⚠️ **Usa cable de red, no Wi-Fi.** El switch externo sobre Wi-Fi funciona, pero es inestable y da problemas raros de conectividad. Para un servidor que debe estar disponible, conecta el notebook por cable al módem. Si no tienes puerto Ethernet, un adaptador USB-C a RJ45 cuesta poco.

> Durante unos segundos vas a perder la conexión de red del anfitrión mientras se crea el switch. Es normal.

## Paso 1.3 — Crear la máquina virtual

Ajusta las rutas a donde tengas espacio (si compraste SSD externo, apunta ahí):

```powershell
$vm   = "SIGMA-SRV"
$ruta = "D:\HyperV"          # <-- cámbialo a tu disco con espacio
New-Item -ItemType Directory -Path $ruta -Force

New-VM -Name $vm `
       -MemoryStartupBytes 4GB `
       -Generation 2 `
       -NewVHDPath "$ruta\$vm.vhdx" `
       -NewVHDSizeBytes 80GB `
       -SwitchName "SW-Externo" `
       -Path $ruta

# 4 núcleos y memoria dinámica: la VM toma lo que necesita y devuelve el resto
Set-VM -Name $vm -ProcessorCount 4 `
       -DynamicMemory -MemoryMinimumBytes 2GB -MemoryMaximumBytes 8GB `
       -AutomaticStartAction Start -AutomaticStopAction Save
```

**Sobre los recursos con tus 16 GB:** el máximo de 8 GB para la VM deja ~8 GB al anfitrión. Si notas que el notebook se arrastra mientras desarrollas, baja el máximo a 6 GB. La memoria dinámica ayuda mucho aquí.

**El VHDX de 80 GB es dinámico**: no ocupa 80 GB de entrada, crece según lo que uses. Pero puede llegar a 80 GB, así que cuenta con eso en tu planificación de espacio.

## Paso 1.4 — Montar la ISO y arrancar

Descarga **Windows Server 2025 Standard (evaluación)** desde el [Centro de evaluación de Microsoft](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025). Son 180 días gratis — te cubre el semestre completo.

> Debes activarla por Internet dentro de los primeros 10 días o la VM empieza a apagarse sola.

```powershell
$iso = "C:\ISO\WindowsServer2025.iso"   # <-- ruta de tu descarga
Add-VMDvdDrive -VMName $vm -Path $iso

# Gen 2 arranca por UEFI: hay que decirle que parta desde el DVD
$dvd = Get-VMDvdDrive -VMName $vm
Set-VMFirmware -VMName $vm -FirstBootDevice $dvd

Start-VM -Name $vm
vmconnect.exe localhost $vm
```

Instala Windows Server normalmente. Elige la edición **"Experiencia de escritorio"** (Desktop Experience) — con Server Core te vas a complicar innecesariamente.

Cuando termine la instalación, quita el DVD para que no arranque de nuevo desde ahí:

```powershell
Remove-VMDvdDrive -VMName $vm -ControllerNumber 0 -ControllerLocation 1
```

---

# PARTE 2 — IP fija para la VM

Aquí hay una decisión que mucha gente hace mal. Hay **dos formas** de dar una IP fija:

| Método | Dónde se configura | Recomendado |
|---|---|---|
| **Reserva DHCP** | En el módem, asociada a la MAC de la VM | ✅ **Sí** |
| **IP estática** | Dentro de Windows Server | Solo si el módem no soporta reservas |

**Por qué la reserva DHCP es mejor:** la VM sigue pidiendo su IP por DHCP, pero el módem siempre le entrega la misma. Si algún día cambias de módem o de rango de red, no tienes que entrar a la VM a reconfigurar nada — y no corres el riesgo de asignarle una IP que el módem ya le dio a otro equipo (conflicto de IP, un dolor de cabeza clásico).

## Paso 2.1 — Fijar la MAC de la VM

Por defecto Hyper-V asigna la MAC dinámicamente y **puede cambiarla**. Si la reserva DHCP está atada a una MAC que cambia, la reserva deja de funcionar. Fíjala:

```powershell
# Ver la MAC actual (con la VM encendida)
Get-VMNetworkAdapter -VMName "SIGMA-SRV" | Select-Object MacAddress, SwitchName

# Congelarla (VM APAGADA)
Stop-VM -Name "SIGMA-SRV"
Set-VMNetworkAdapter -VMName "SIGMA-SRV" -StaticMacAddress "00155D010203"
Start-VM -Name "SIGMA-SRV"
```

Anota esa MAC. La vas a necesitar en el módem.

## Paso 2.2 — Elegir la IP

Primero mira qué rango usa tu red. Desde el anfitrión:

```powershell
ipconfig | Select-String "Puerta de enlace|Gateway|IPv4"
```

Digamos que tu red es `192.168.1.x` y el módem es `192.168.1.1`.

**Elige una IP fuera del rango DHCP.** Los módems suelen repartir desde `.100` en adelante, así que una IP baja como `192.168.1.50` es segura. Revisa en el módem, en `LAN → DHCP`, cuál es el rango que reparte.

Para esta guía uso:

| | Valor |
|---|---|
| IP de la VM | `192.168.1.50` |
| Máscara | `255.255.255.0` (prefijo 24) |
| Puerta de enlace | `192.168.1.1` |
| DNS | `1.1.1.1` y `8.8.8.8` |

## Paso 2.3 — Opción recomendada: reserva DHCP en el módem

1. Entra al módem: `http://192.168.1.1` (usuario/clave suelen estar en la etiqueta del equipo).
2. Busca la sección: **LAN → DHCP → Reserva de direcciones** / *Address Reservation* / *Static DHCP* / *DHCP Binding*. El nombre cambia según el fabricante.
3. Agrega una entrada:
   - **MAC:** `00:15:5D:01:02:03` (la que fijaste — algunos módems la piden con dos puntos, otros sin)
   - **IP:** `192.168.1.50`
   - **Nombre:** `SIGMA-SRV`
4. Guarda y reinicia la VM para que tome la IP nueva.

## Paso 2.4 — Alternativa: IP estática dentro de la VM

Si tu módem no tiene reservas DHCP, configúralo dentro de Windows Server:

```powershell
# DENTRO de la VM, PowerShell como Administrador
$if = (Get-NetAdapter | Where-Object Status -eq 'Up').Name

New-NetIPAddress -InterfaceAlias $if `
                 -IPAddress 192.168.1.50 `
                 -PrefixLength 24 `
                 -DefaultGateway 192.168.1.1

Set-DnsClientServerAddress -InterfaceAlias $if -ServerAddresses 1.1.1.1,8.8.8.8
```

Verifica:

```powershell
Get-NetIPConfiguration
Test-NetConnection 8.8.8.8          # ¿hay salida a Internet?
Test-NetConnection google.com       # ¿resuelve DNS?
```

## Paso 2.5 — Comprueba desde el anfitrión

```powershell
# Desde el notebook (fuera de la VM)
Test-NetConnection 192.168.1.50
```

Si responde, la VM ya es un equipo más de tu red doméstica. Este es el hito importante: **si esto no funciona, no sigas** — nada de lo que viene después va a servir.

---

# PARTE 3 — Instalar y abrir los servicios

## Paso 3.1 — IIS

Dentro de la VM:

```powershell
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# ASP.NET 4.8 para SIGMA (WebForms)
Install-WindowsFeature Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter
```

## Paso 3.2 — SQL Server

Descarga **SQL Server 2022 Developer Edition** (gratis, funcionalidad completa de Enterprise, uso no productivo — perfecto para un CAPSTONE).

Durante la instalación:
- Modo de autenticación: **Mixto** (necesitas usuario SQL para la cadena de conexión de SIGMA).
- Ponle a `sa` una contraseña **larga y aleatoria**. No `Sa123456`. Genera una de 20+ caracteres y guárdala en un gestor de contraseñas.
- Habilita **TCP/IP** en el Administrador de configuración de SQL Server (viene deshabilitado por defecto): `SQL Server Network Configuration → Protocols → TCP/IP → Enabled`. Reinicia el servicio.

## Paso 3.3 — Reglas de firewall

Aquí está el detalle que importa: **las reglas de SQL Server se limitan a tu red local**, no se abren a todo el mundo.

```powershell
# DENTRO de la VM

# IIS: abierto (lo vas a exponer)
New-NetFirewallRule -DisplayName "HTTP entrante"  -Direction Inbound -Protocol TCP -LocalPort 80  -Action Allow
New-NetFirewallRule -DisplayName "HTTPS entrante" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow

# SQL Server: SOLO desde la red local. Ajusta el rango al tuyo.
New-NetFirewallRule -DisplayName "SQL Server (LAN)" -Direction Inbound -Protocol TCP -LocalPort 1433 `
                    -RemoteAddress 192.168.1.0/24 -Action Allow

# Si usarás Tailscale (Opción A), agrega también su rango:
New-NetFirewallRule -DisplayName "SQL Server (Tailscale)" -Direction Inbound -Protocol TCP -LocalPort 1433 `
                    -RemoteAddress 100.64.0.0/10 -Action Allow

# RDP para administrar la VM, solo desde la LAN
New-NetFirewallRule -DisplayName "RDP (LAN)" -Direction Inbound -Protocol TCP -LocalPort 3389 `
                    -RemoteAddress 192.168.1.0/24 -Action Allow
```

Habilita RDP:

```powershell
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
```

---

# PARTE 4 · OPCIÓN A — Acceso con Tailscale (recomendada)

Tailscale crea una **red privada virtual entre los equipos de tu equipo**. Cada máquina recibe una IP fija en el rango `100.x.x.x` que funciona desde cualquier parte del mundo, sin abrir un solo puerto en el módem.

**Por qué encaja perfecto en tu caso:**
- Funciona **aunque estés detrás de CGNAT**.
- No expones absolutamente nada a Internet.
- El plan gratuito cubre **6 usuarios y dispositivos ilimitados** — justo el tamaño de un equipo CAPSTONE.
- La IP `100.x.x.x` que te da **nunca cambia**, así que es literalmente la "IP fija" que estabas buscando.

## Paso A.1 — Crear la cuenta

Ve a [tailscale.com](https://tailscale.com), crea una cuenta gratuita (con Google/GitHub/Microsoft) — esa cuenta es la dueña de la red (*tailnet*).

## Paso A.2 — Instalar en la VM

Dentro de la VM, descarga el instalador de Windows desde [tailscale.com/download](https://tailscale.com/download) e instálalo. Inicia sesión con tu cuenta.

Toma nota de la IP que te asigna (algo como `100.101.102.103`):

```powershell
tailscale ip -4
```

## Paso A.3 — Hacer la IP permanente

En la [consola de administración](https://login.tailscale.com/admin/machines):

1. Busca la máquina `SIGMA-SRV`.
2. Menú `⋯` → **Disable key expiry**. Sin esto, la autenticación caduca a los ~6 meses y el servidor se desconecta solo.

## Paso A.4 — Invitar al equipo

En la consola → **Users** → **Invite external users**, y envía el link a tus compañeros. Cada uno instala Tailscale en su equipo, acepta la invitación, y listo.

## Paso A.5 — Cómo se conectan

Desde cualquier lugar, con Tailscale corriendo:

| Servicio | Dirección |
|---|---|
| Sitio SIGMA | `http://100.101.102.103` |
| SQL Server (SSMS) | `100.101.102.103,1433` |

**Tip que hace la vida más fácil:** activa **MagicDNS** en la consola (Settings → DNS). Entonces se conectan con `http://sigma-srv` en vez de recordar la IP.

---

# PARTE 4 · OPCIÓN B — Redirección de puertos en el módem

Usa esta vía **solo si necesitas que el sitio sea público** y confirmaste que **no estás detrás de CGNAT**.

## Paso B.1 — Redirigir puertos

Entra al módem y busca: **Port Forwarding** / *Redirección de puertos* / *Virtual Server* / *NAT → Servidores virtuales*.

Agrega:

| Nombre | Puerto externo | IP interna | Puerto interno | Protocolo |
|---|---|---|---|---|
| SIGMA-HTTP | 80 | 192.168.1.50 | 80 | TCP |
| SIGMA-HTTPS | 443 | 192.168.1.50 | 443 | TCP |

> **No redirijas el 1433 (SQL Server) ni el 3389 (RDP).** Si tus compañeros necesitan SQL desde fuera, usa Tailscale para eso — puedes combinar las dos opciones. Es la configuración que recomiendo: IIS público, SQL por Tailscale.

Algunos ISP bloquean el puerto 80 entrante en planes residenciales. Si es tu caso, usa el 8080 externo → 80 interno, y el acceso queda como `http://tudominio:8080`.

## Paso B.2 — DDNS (tu IP pública cambia)

Salvo que hayas contratado IP fija, tu ISP te cambia la IP cada cierto tiempo y el acceso se cae sin aviso. La solución es un **DNS dinámico**: un nombre que siempre apunta a tu IP actual.

Muchos módems traen DDNS integrado (`Avanzado → DDNS`). Si el tuyo lo tiene, usa **No-IP** o **DuckDNS** (ambos gratis) y configúralo ahí. Si no lo tiene, instala el cliente de actualización dentro de la VM.

Resultado: tus compañeros entran a `http://sigma-capstone.duckdns.org` y funciona aunque tu IP cambie.

## Paso B.3 — Endurecimiento mínimo (no es opcional)

Si expones el servidor a Internet, esto es lo mínimo:

```powershell
# DENTRO de la VM

# 1. HTTPS con certificado gratuito: instala win-acme (Let's Encrypt)
#    https://www.win-acme.com/  -- sin esto las credenciales viajan en texto plano

# 2. Bloqueo de cuentas tras intentos fallidos
net accounts /lockoutthreshold:5 /lockoutduration:30 /lockoutwindow:30

# 3. Actualizaciones automáticas activadas
# 4. Renombra la cuenta Administrador y usa contraseña de 20+ caracteres
# 5. Revisa los intentos de acceso fallidos periódicamente:
Get-EventLog -LogName Security -InstanceId 4625 -Newest 30 |
    Select-Object TimeGenerated, Message | Format-List
```

Y una advertencia práctica: **si expones el servidor, revisa el log de seguridad cada pocos días**. Vas a ver intentos de acceso desde todo el mundo a las pocas horas de abrir el puerto. Es normal y esperable — lo que no es normal es que uno tenga éxito.

---

# PARTE 5 — Verificación

Ejecuta en orden. Si uno falla, no sigas: el problema está ahí.

| # | Prueba | Comando / acción | Esperado |
|---|---|---|---|
| 1 | La VM tiene la IP correcta | `Get-NetIPConfiguration` (en la VM) | `192.168.1.50` |
| 2 | La VM llega a Internet | `Test-NetConnection google.com` | `TcpTestSucceeded : True` |
| 3 | El anfitrión ve la VM | `Test-NetConnection 192.168.1.50 -Port 80` | `True` |
| 4 | Otro equipo de tu casa ve el sitio | Navegador → `http://192.168.1.50` | Página de IIS |
| 5 | SQL responde en la LAN | `Test-NetConnection 192.168.1.50 -Port 1433` | `True` |
| 6 | **(Opción A)** Acceso remoto | Desde 4G, con Tailscale → `http://100.x.x.x` | Página de IIS |
| 7 | **(Opción B)** Puerto abierto | [canyouseeme.org](https://canyouseeme.org) puerto 80 | *Success* |
| 8 | **(Opción B)** Acceso remoto real | Desde datos móviles → `http://tudominio.duckdns.org` | Página de IIS |

> El paso 8 **hazlo desde datos móviles, no desde tu Wi-Fi**. Muchos módems no soportan *NAT loopback*, así que probar desde dentro de tu propia red falla aunque todo esté bien configurado. Es una fuente clásica de confusión.

---

# PARTE 6 — Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| No aparece Hyper-V en Windows | Edición Home | Actualizar a Pro, o usar VirtualBox |
| `Enable-WindowsOptionalFeature` falla | Virtualización desactivada | Activar Intel VT-x en la BIOS (F10 al arrancar) |
| La VM no tiene red | Switch interno en vez de externo | `Get-VMSwitch` debe decir `External` |
| La VM pierde la IP fija | La MAC cambió | Fijarla con `-StaticMacAddress` (Paso 2.1) |
| Conflicto de IP en la red | La IP está dentro del rango DHCP | Elegir una IP fuera del rango, o usar reserva |
| Funciona en la LAN, no desde fuera | CGNAT | Verificar (chequeo 3) → usar Tailscale |
| El puerto se ve cerrado desde fuera | Firewall de la VM | Revisar reglas del Paso 3.3 |
| El puerto se ve cerrado, firewall OK | El ISP bloquea el 80 | Usar 8080 externo → 80 interno |
| Funciona desde 4G pero no desde tu casa | Sin NAT loopback en el módem | Normal. Dentro de casa usa la IP local |
| Deja de funcionar cada cierto tiempo | Cambió tu IP pública | Configurar DDNS (Paso B.2) |
| Se cae a los ~6 meses (Tailscale) | Caducó la clave del nodo | *Disable key expiry* (Paso A.3) |
| El notebook se arrastra | La VM toma mucha RAM | Bajar `-MemoryMaximumBytes` a 6GB |
| SQL no acepta conexiones remotas | TCP/IP deshabilitado | Habilitarlo en SQL Server Configuration Manager |

---

# Apéndice — Consideraciones para el CAPSTONE

Algunas cosas que conviene que el equipo tenga claras:

**El servidor es tu notebook.** Si lo cierras, lo llevas a clases o se queda sin batería, el servidor desaparece. Para un servicio que el equipo va a usar todo el semestre, considera:
- Configurar el plan de energía en **Alto rendimiento** y desactivar la suspensión al cerrar la tapa.
- `-AutomaticStartAction Start` (ya está en el Paso 1.3) hace que la VM arranque sola al encender el notebook.
- Si el equipo depende de esto para trabajar, evalúa un VPS barato (DigitalOcean, Hetzner, Azure for Students) — Azure for Students da crédito gratis con correo institucional y te evita todos estos problemas.

**Respaldos.** Un CAPSTONE perdido por un disco muerto es una historia que se repite todos los semestres. Exporta la VM periódicamente:

```powershell
Export-VM -Name "SIGMA-SRV" -Path "E:\Respaldos"
```

Y sobre todo, mantén la **base de datos y el código en control de versiones** (ya tienes Git en CAPSTONE). La VM debe ser reemplazable, no irreemplazable.

**Documenta las credenciales** en un lugar compartido del equipo — pero nunca en el repositorio Git.

---

## Fuentes

- [Install Hyper-V in Windows and Windows Server — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/install-hyper-v)
- [Windows Server 2025 — Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025)
- [Free pricing plans and discounts — Tailscale Docs](https://tailscale.com/docs/account/manage-plans/free-plans-discounts)
- [Tailscale pricing](https://tailscale.com/pricing)
