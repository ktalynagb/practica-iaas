# ============================================================
#  PRÁCTICA IaaS — Azure Virtual Machines
#  UAO · Computación en la Nube · Prof. Oscar H. Mondragón
#
#  USO:
#    .\practica-iaas.ps1          → menú interactivo
#    .\practica-iaas.ps1 1        → levanta ejercicio 1+2
#    .\practica-iaas.ps1 3        → levanta ejercicio 3
#    .\practica-iaas.ps1 4        → levanta ejercicio 4
#    .\practica-iaas.ps1 1 kill   → mata ejercicio 1+2
#    .\practica-iaas.ps1 3 kill   → mata ejercicio 3
#    .\practica-iaas.ps1 4 kill   → mata ejercicio 4
# ============================================================

param(
    [string]$Ejercicio = "",
    [string]$Accion    = "up"
)

# ── Configuración global ─────────────────────────────────────
$SUBSCRIPTION = "9168fe2b-2bcc-409f-ad80-5b84e9678901"
$ADMIN_USER   = "azureuser"
$ADMIN_PASS   = "Azure@12345!"
$SSH_KEY      = "D:\AA.ESPES2\COMPUTACION_NUBE_\PRACTICA_6_\vm1-key-nueva.pem"

$RG_EJ12      = "vmgroup"
$RG_EJ3       = "practica-template-rg"
$RG_EJ4       = "practica-windows-rg"
$REGION       = "centralus"

az account set --subscription $SUBSCRIPTION | Out-Null

# ── Helpers ──────────────────────────────────────────────────
function Write-Title($msg) {
    Write-Host "`n══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════" -ForegroundColor Cyan
}
function Write-OK($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Step($msg) { Write-Host "  → $msg" -ForegroundColor Yellow }
function Write-Bye($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }

# ════════════════════════════════════════════════════════════
#  EJERCICIO 1+2 — Ubuntu + Apache + disco /datadrive
# ════════════════════════════════════════════════════════════
function Levantar-Ej12 {
    Write-Title "EJ 1+2 · Ubuntu + Apache + disco adicional"

    Write-Step "Creando resource group $RG_EJ12..."
    az group create --name $RG_EJ12 --location $REGION | Out-Null

    Write-Step "Creando VM Ubuntu 22.04 (Standard_D2s_v3)..."
    az vm create `
        --resource-group $RG_EJ12 `
        --name vm1 `
        --image Ubuntu2204 `
        --size Standard_D2s_v3 `
        --admin-username $ADMIN_USER `
        --ssh-key-values "$SSH_KEY.pub" `
        --public-ip-sku Standard `
        --output none

    Write-Step "Abriendo puerto 80..."
    az vm open-port --resource-group $RG_EJ12 --name vm1 --port 80 | Out-Null

    $IP = (az vm show -d -g $RG_EJ12 -n vm1 --query publicIps -o tsv)

    Write-Step "Instalando Apache via SSH..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$ADMIN_USER@$IP" `
        "sudo apt-get update -y -q && sudo apt-get install -y -q apache2 && sudo systemctl enable apache2 && sudo systemctl start apache2"

    Write-Step "Adjuntando disco de 4GB..."
    az vm disk attach `
        --resource-group $RG_EJ12 `
        --vm-name vm1 `
        --name vm1-disk-data `
        --size-gb 4 `
        --sku StandardSSD_LRS `
        --new | Out-Null

    Write-Step "Montando disco en /datadrive..."
    $MOUNT = @'
DISK=$(ls /dev/sdc 2>/dev/null || echo /dev/sdb)
sudo parted $DISK --script mklabel gpt
sudo parted $DISK --script mkpart primary xfs 0% 100%
sleep 2
PART=${DISK}1
sudo mkfs.xfs $PART -f
sudo mkdir -p /datadrive
UUID=$(sudo blkid -s UUID -o value $PART)
echo "UUID=$UUID /datadrive xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo mount -a
df -h /datadrive
'@
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$ADMIN_USER@$IP" $MOUNT

    Write-OK "Apache corriendo en http://$IP"
    Write-OK "Disco montado en /datadrive"
    Write-Host "  SSH: ssh -i $SSH_KEY $ADMIN_USER@$IP" -ForegroundColor Gray
}

function Matar-Ej12 {
    Write-Title "EJ 1+2 · Eliminando VM Ubuntu y disco"
    Write-Bye "Borrando resource group $RG_EJ12..."
    az group delete --name $RG_EJ12 --yes
    Write-OK "Resource group $RG_EJ12 eliminado"
}

# ════════════════════════════════════════════════════════════
#  EJERCICIO 3 — VM desde template ARM
# ════════════════════════════════════════════════════════════
function Levantar-Ej3 {
    Write-Title "EJ 3 · VM desde template ARM"

    Write-Step "Creando resource group $RG_EJ3..."
    az group create --name $RG_EJ3 --location $REGION | Out-Null

    $DNS = "simplelinuxvm$(Get-Random -Maximum 9999)"
    Write-Step "Desplegando template ARM..."
    az deployment group create `
        --resource-group $RG_EJ3 `
        --template-uri "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.compute/vm-simple-linux/azuredeploy.json" `
        --parameters `
            adminUsername=$ADMIN_USER `
            authenticationType=password `
            adminPasswordOrKey=$ADMIN_PASS `
            dnsLabelPrefix=$DNS `
            ubuntuOSVersion="Ubuntu-2204" `
            vmSize="Standard_D2s_v3" `
        --output none

    Write-OK "VM creada desde template en $RG_EJ3"
    Write-OK "DNS: $DNS.$REGION.cloudapp.azure.com"
}

function Matar-Ej3 {
    Write-Title "EJ 3 · Eliminando VM de template ARM"
    Write-Bye "Borrando resource group $RG_EJ3..."
    az group delete --name $RG_EJ3 --yes
    Write-OK "Resource group $RG_EJ3 eliminado"
}

# ════════════════════════════════════════════════════════════
#  EJERCICIO 4 — Windows Server + RDP
# ════════════════════════════════════════════════════════════
function Levantar-Ej4 {
    Write-Title "EJ 4 · Windows Server 2022 + RDP"

    Write-Step "Creando resource group $RG_EJ4..."
    az group create --name $RG_EJ4 --location $REGION | Out-Null

    Write-Step "Creando VM Windows Server 2022 (Standard_D2s_v3)..."
    az vm create `
        --resource-group $RG_EJ4 `
        --name vm-windows `
        --image Win2022Datacenter `
        --size Standard_D2s_v3 `
        --admin-username $ADMIN_USER `
        --admin-password $ADMIN_PASS `
        --public-ip-sku Standard `
        --nsg-rule RDP `
        --location $REGION `
        --output none

    $IP = (az vm show -d -g $RG_EJ4 -n vm-windows --query publicIps -o tsv)

    Write-OK "VM Windows lista"
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────┐" -ForegroundColor Green
    Write-Host "  │  IP       : $IP              " -ForegroundColor Green
    Write-Host "  │  Usuario  : $ADMIN_USER           " -ForegroundColor Green
    Write-Host "  │  Password : $ADMIN_PASS       " -ForegroundColor Green
    Write-Host "  │  Puerto   : 3389 (RDP)            " -ForegroundColor Green
    Write-Host "  └─────────────────────────────────┘" -ForegroundColor Green

    $r = Read-Host "`n  ¿Abrir RDP ahora? (s/N)"
    if ($r -eq "s" -or $r -eq "S") {
        Start-Process "mstsc" -ArgumentList "/v:$IP"
    }
}

function Matar-Ej4 {
    Write-Title "EJ 4 · Eliminando VM Windows"
    Write-Bye "Borrando resource group $RG_EJ4..."
    az group delete --name $RG_EJ4 --yes
    Write-OK "Resource group $RG_EJ4 eliminado"
}

# ════════════════════════════════════════════════════════════
#  ESTADO ACTUAL DE VMs
# ════════════════════════════════════════════════════════════
function Mostrar-Estado {
    Write-Host "  ── Estado actual ──────────────────────────" -ForegroundColor DarkGray

    $vms = az vm list -d --query "[].{nombre:name, rg:resourceGroup, estado:powerState, ip:publicIps}" -o json 2>$null | ConvertFrom-Json

    if (-not $vms -or $vms.Count -eq 0) {
        Write-Host "  (ninguna VM corriendo)" -ForegroundColor DarkGray
    } else {
        foreach ($vm in $vms) {
            $viva   = ($vm.estado -eq "VM running") -or ($vm.ip -and $vm.estado -ne "VM deallocated")
            $color  = if ($viva) { "Green" } else { "DarkGray" }
            $ip     = if ($vm.ip) { $vm.ip } else { "sin IP" }
            $icono  = if ($viva) { "●" } else { "○" }
            $estado = if ($vm.estado) { $vm.estado } else { "running" }
            Write-Host "  $icono $($vm.nombre.PadRight(16)) $($estado.PadRight(20)) $ip" -ForegroundColor $color
        }
    }

    Write-Host "  ───────────────────────────────────────────" -ForegroundColor DarkGray
}

# ════════════════════════════════════════════════════════════
#  MENÚ INTERACTIVO
# ════════════════════════════════════════════════════════════
function Mostrar-Menu {
    Clear-Host
    Write-Host @"

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
"@ -ForegroundColor Cyan

    Mostrar-Estado
    $op = Read-Host "  Opción"
    switch ($op.ToLower()) {
        "1"  { Levantar-Ej12 }
        "3"  { Levantar-Ej3  }
        "4"  { Levantar-Ej4  }
        "1k" { Matar-Ej12    }
        "3k" { Matar-Ej3     }
        "4k" { Matar-Ej4     }
        "q"  { Write-Host "  Hasta luego." -ForegroundColor Gray; return }
        default { Write-Host "  Opción no válida." -ForegroundColor Red }
    }

    Write-Host ""
    Read-Host "  Presiona Enter para volver al menú"
    Mostrar-Menu
}

# ════════════════════════════════════════════════════════════
#  PUNTO DE ENTRADA
# ════════════════════════════════════════════════════════════
switch ($Ejercicio) {
    "1"  { if ($Accion -eq "kill") { Matar-Ej12 } else { Levantar-Ej12 } }
    "2"  { if ($Accion -eq "kill") { Matar-Ej12 } else { Levantar-Ej12 } }
    "3"  { if ($Accion -eq "kill") { Matar-Ej3  } else { Levantar-Ej3  } }
    "4"  { if ($Accion -eq "kill") { Matar-Ej4  } else { Levantar-Ej4  } }
    default { Mostrar-Menu }
}