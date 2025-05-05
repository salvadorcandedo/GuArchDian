# SSH Hardening Script

Este script automatiza el endurecimiento de la configuración de SSH (`sshd_config` y `ssh_config`) para mejorar la seguridad del servidor Linux. Elimina claves antiguas, genera nuevas claves seguras, configura parámetros estrictos y establece controles de acceso recomendados para entornos de producción.

## Características del script

### Seguridad de claves y autenticación

- Elimina todas las claves de host existentes en `/etc/ssh/`
- Genera nuevas claves `ed25519` y `RSA 4096`
- Configura el uso exclusivo de claves públicas y desactiva métodos de autenticación obsoletos o inseguros
- Crea un archivo para gestionar claves revocadas (`/etc/ssh/revokedKeys`)
- Define algoritmos seguros de intercambio de claves, cifrados y MACs

### Configuración de acceso

- Desactiva el acceso del usuario `root`
- Restringe el acceso SSH al usuario actual
- Limita el número de intentos de autenticación, sesiones y startups
- Establece un timeout para autenticación y sesiones inactivas
- Muestra un banner legal antes del login (`/etc/issue.net`)

### Seguridad del canal SSH

- Desactiva todas las formas de reenvío de puertos, X11 y agentes
- Configura `ClientAliveInterval` y `ClientAliveCountMax` para cerrar sesiones inactivas
- Desactiva `TCPKeepAlive` para evitar mantener conexiones zombies
- Desactiva la compresión para prevenir ataques de tipo CRIME

### Endurecimiento de configuración del cliente SSH (`/etc/ssh/ssh_config`)

- Define un conjunto de algoritmos seguros para clientes SSH
- Establece un timeout de conexión y control de conexiones persistentes (`ControlMaster`)
- Obliga al cliente a verificar las huellas digitales del host (`StrictHostKeyChecking`)

### Otros

- Crea y asegura permisos del archivo `/etc/issue.net`
- Aplica rate limiting con `iptables` para evitar ataques de fuerza bruta (4 intentos en 60 segundos)

## Requisitos

- Usuario con privilegios de `root`
- Sistema Linux con `OpenSSH` instalado
- `iptables` para aplicar el rate limiting

## Uso

```bash
sudo ./ssh.sh
