# ☁️ Práctica IaaS — Azure Virtual Machines

**Universidad Autónoma de Occidente**  
Computación en la Nube · Prof. Oscar H. Mondragón

---

## 📌 ¿Qué es IaaS?

**Infrastructure as a Service (IaaS)** es el modelo de servicio en la nube donde el proveedor (en este caso Microsoft Azure) se encarga del hardware físico, la red y la virtualización. Tú, como usuario, gestionas todo lo que está encima: el sistema operativo, el middleware, los datos y las aplicaciones.

```
┌─────────────────────────────────────────┐
│  Tú gestionas        │  Azure gestiona  │
├──────────────────────┼──────────────────┤
│  Aplicaciones        │  Hardware        │
│  Datos               │  Red física      │
│  Runtime             │  Virtualización  │
│  Sistema Operativo   │  Almacenamiento  │
└─────────────────────────────────────────┘
```

**¿Por qué usar IaaS?**
- Control total sobre el entorno de ejecución
- Escalabilidad bajo demanda (pagas solo lo que usas)
- No necesitas comprar ni mantener servidores físicos
- Ideal para migraciones "lift and shift" desde on-premise

**IaaS vs PaaS vs SaaS:**

| Modelo | Ejemplo Azure | Tú gestionas | Azure gestiona |
|--------|--------------|--------------|----------------|
| IaaS | Virtual Machines | SO, apps, datos | Hardware, red |
| PaaS | App Service | Solo el código | Todo lo demás |
| SaaS | Microsoft 365 | Solo el uso | Todo |

---

## 🎯 Objetivo de la Práctica

Comprender el funcionamiento de IaaS creando y gestionando máquinas virtuales en Azure desde cero, usando tanto el portal web como Azure CLI y templates ARM.

---

## 🛠️ Herramientas necesarias

Antes de correr el script asegúrate de tener instalado:

| Herramienta | Cómo instalar | Para qué se usa |
|-------------|--------------|-----------------|
| [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) | `winget install Microsoft.AzureCLI` | Crear y gestionar recursos en Azure |
| [Git](https://git-scm.com/) | `winget install Git.Git` | Control de versiones |
| [GitHub CLI](https://cli.github.com/) | `winget install GitHub.cli` | Subir el repo a GitHub |
| Clave SSH | `ssh-keygen -t rsa` | Conectarse a la VM Linux |

**Iniciar sesión en Azure:**
```powershell
az login
```

---

## ⚙️ Configuración del script

Antes de correr el script, edita estas variables al inicio de `practica-iaas.ps1`:

```powershell
$SUBSCRIPTION = "tu-subscription-id"        # ID de tu suscripción Azure
$ADMIN_USER   = "azureuser"                  # Usuario para las VMs
$ADMIN_PASS   = "TuPassword@123!"            # Contraseña (mínimo 12 chars, mayús, núm, símbolo)
$SSH_KEY      = "C:\ruta\a\tu\clave.pem"     # Ruta a tu llave SSH privada
```

> ⚠️ **Importante:** la suscripción de Azure for Students tiene un límite de **6 vCPUs** en la región `centralus` y solo permite ciertas familias de VM. El script usa `Standard_D2s_v3` (2 vCPUs). Por eso los ejercicios 1+2, 3 y 4 no pueden estar activos simultáneamente — hay que matar uno antes de levantar el siguiente.

---

## 🚀 Uso del script

### Menú interactivo (recomendado para la sustentación)

```powershell
.\practica-iaas.ps1
```

Aparece este menú y se muestra el estado actual de todas las VMs:

```
  ╔═══════════════════════════════════════════════╗
  ║   PRÁCTICA IaaS · Azure Virtual Machines      ║
  ║   UAO · Computación en la Nube                ║
  ╠═══════════════════════════════════════════════╣
  ║                                               ║
  ║   LEVANTAR                                    ║
  ║   [1]  Ejercicio 1+2  (Ubuntu + disco)        ║
  ║   [3]  Ejercicio 3    (Template ARM)          ║
  ║   [4]  Ejercicio 4    (Windows + RDP)         ║
  ║                                               ║
  ║   MATAR                                       ║
  ║   [1k] Matar ejercicio 1+2                    ║
  ║   [3k] Matar ejercicio 3                      ║
  ║   [4k] Matar ejercicio 4                      ║
  ║                                               ║
  ║   [q]  Salir                                  ║
  ╚═══════════════════════════════════════════════╝
  ── Estado actual ──────────────────────────
  ● vm1             VM running           20.x.x.x
  ○ vm-windows      VM deallocated       sin IP
  ───────────────────────────────────────────
```

### Por parámetros (desde terminal directamente)

```powershell
.\practica-iaas.ps1 1        # Levanta ejercicio 1+2
.\practica-iaas.ps1 3        # Levanta ejercicio 3
.\practica-iaas.ps1 4        # Levanta ejercicio 4

.\practica-iaas.ps1 1 kill   # Mata ejercicio 1+2
.\practica-iaas.ps1 3 kill   # Mata ejercicio 3
.\practica-iaas.ps1 4 kill   # Mata ejercicio 4
```

---

## 📋 Ejercicios

### Ejercicio 1 — VM Ubuntu con Apache (IaaS básico)

**¿Qué se hace?**  
Se crea una máquina virtual con Ubuntu Server 22.04 en Azure y se instala el servidor web Apache para que sea accesible por HTTP desde internet.

**Conceptos clave:**
- **Resource Group:** contenedor lógico que agrupa todos los recursos relacionados (VM, disco, IP, NSG)
- **NSG (Network Security Group):** firewall virtual que controla el tráfico entrante/saliente. Se abre el puerto 80 para HTTP
- **IP pública:** dirección IP asignada por Azure para acceder a la VM desde internet
- **SSH:** protocolo seguro para conectarse a la terminal de la VM Linux

**Lo que crea el script:**
```
Resource Group: vmgroup
├── VM: vm1 (Ubuntu 22.04, Standard_D2s_v3)
├── Disco OS: 30 GB
├── IP pública: dinámica
└── NSG: vm1NSG (puerto 22 SSH + puerto 80 HTTP abiertos)
```

**Qué mostrar en la sustentación:**
```powershell
# Verificar que Apache está corriendo
ssh -i vm1-key-nueva.pem azureuser@<IP> "systemctl status apache2"

# Ver en el browser
start http://<IP>
```

---

### Ejercicio 2 — Disco adicional montado en `/datadrive`

**¿Qué se hace?**  
Se agrega un disco de datos independiente al disco del sistema operativo y se monta en `/datadrive` dentro de la VM Ubuntu.

**Conceptos clave:**
- **Disco OS vs disco de datos:** el disco OS contiene el sistema operativo. El disco de datos es independiente — si recreas la VM, los datos persisten
- **Managed Disk:** Azure gestiona el almacenamiento físico automáticamente
- **XFS:** sistema de archivos de alto rendimiento usado en servidores Linux
- **fstab:** archivo de configuración de Linux que define qué discos se montan automáticamente al arrancar

**Lo que crea el script:**
```
Disco: vm1-disk-data (4 GB, StandardSSD_LRS)
Montado en: /datadrive
Sistema de archivos: XFS
Montaje automático: sí (via /etc/fstab con UUID)
```

**Qué mostrar en la sustentación:**
```bash
# Conectado por SSH a la VM:
df -h /datadrive          # Ver que el disco está montado
lsblk                     # Ver la estructura de discos
cat /etc/fstab            # Ver que quedó configurado para arranque automático
```

---

### Ejercicio 3 — VM desde template ARM

**¿Qué se hace?**  
Se despliega una máquina virtual usando un template ARM (Azure Resource Manager), que es un archivo JSON que describe toda la infraestructura como código.

**Conceptos clave:**
- **Infrastructure as Code (IaC):** describir la infraestructura en archivos de texto versionables, reproducibles y automatizables
- **Template ARM:** formato JSON nativo de Azure para IaC. Define recursos, parámetros y dependencias
- **Deployment:** Azure interpreta el template y crea todos los recursos declarados automáticamente
- **Idempotencia:** si corres el mismo template dos veces, el resultado es el mismo — no duplica recursos

**Por qué es importante:**
En producción nunca se crean VMs manualmente. Los templates permiten crear entornos idénticos en segundos, en cualquier región, sin errores humanos.

**Template usado:** [Simple Linux VM - Azure Quickstart](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.compute/vm-simple-linux)

**Qué mostrar en la sustentación:**
```powershell
# Ver el deployment creado
az deployment group list --resource-group practica-template-rg --output table

# Ver los recursos creados por el template
az resource list --resource-group practica-template-rg --output table
```

---

### Ejercicio 4 — VM Windows Server + RDP

**¿Qué se hace?**  
Se crea una VM con Windows Server 2022 Datacenter y se accede a ella usando RDP (Remote Desktop Protocol), que permite ver y controlar el escritorio de Windows de forma remota.

**Conceptos clave:**
- **Windows Server 2022 Datacenter:** versión de Windows diseñada para servidores. Incluye roles como Active Directory, IIS, Hyper-V
- **RDP (Remote Desktop Protocol):** protocolo de Microsoft para acceso remoto gráfico. Usa el puerto TCP 3389
- **Server Manager:** herramienta de Windows Server para gestionar roles, características y servidores remotos
- **NSG rule RDP:** regla del firewall que permite tráfico entrante al puerto 3389

**Diferencia SSH vs RDP:**

| | SSH | RDP |
|--|-----|-----|
| SO | Linux | Windows |
| Puerto | 22 | 3389 |
| Interfaz | Terminal texto | Escritorio gráfico |
| Autenticación | Clave pública/contraseña | Usuario/contraseña |

**Qué mostrar en la sustentación:**
```powershell
# Abrir conexión RDP
mstsc /v:<IP>
# Usuario: azureuser
# Contraseña: Azure@12345!
```
Mostrar el **Server Manager** abierto con la VM `vm-windows` visible en la lista de servidores.

---

## 📊 Resumen de recursos creados

| Ejercicio | Resource Group | VM | SO | Tamaño |
|-----------|---------------|----|----|--------|
| 1 + 2 | vmgroup | vm1 | Ubuntu 22.04 | Standard_D2s_v3 |
| 3 | practica-template-rg | simpleLinuxVM | Ubuntu 22.04 | Standard_D2s_v3 |
| 4 | practica-windows-rg | vm-windows | Windows Server 2022 | Standard_D2s_v3 |

> ⚠️ **Límite de cuota:** la suscripción Azure for Students solo permite 6 vCPUs totales en `centralus`. Cada VM usa 2 vCPUs, por lo que solo pueden coexistir máximo 3 VMs — y en la práctica, solo 2 a la vez para no agotar la familia DSv3 (límite 4).

---

## 🗂️ Estructura del repositorio

```
practica-iaas/
├── practica-iaas.ps1    # Script principal con menú interactivo
└── README.md            # Esta documentación
```

---

## 💡 Flujo recomendado para la sustentación

```
1. .\practica-iaas.ps1
2. Escribe [1]  → espera ~5 min → muestra Apache + disco
3. Escribe [1k] → espera que elimine
4. Escribe [3]  → espera ~3 min → muestra VM del template
5. Escribe [3k] → espera que elimine
6. Escribe [4]  → espera ~3 min → conecta RDP → muestra Server Manager
7. Escribe [4k] → limpia todo
```

---

## 🔗 Referencias

- [Portal Azure](https://portal.azure.com)
- [Documentación Azure Virtual Machines](https://docs.microsoft.com/azure/virtual-machines/)
- [Azure Quickstart Templates](https://azure.microsoft.com/resources/templates/)
- [Attach a disk to a Linux VM](https://docs.microsoft.com/azure/virtual-machines/linux/attach-disk-portal)
- [Tutorial Windows VM + RDP](https://www.youtube.com/watch?v=iUaTq06m26g)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/)
