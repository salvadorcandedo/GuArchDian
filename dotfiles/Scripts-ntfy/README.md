# Scripts de Notificación con NTFY

Este repositorio contiene dos scripts bash que utilizan `ntfy` para enviar notificaciones relacionadas con eventos del sistema:

---

## 1. Notificación de Inicio de Sesión Local (`LocalLogin.sh`)

Este script envía una notificación mediante `ntfy` cada vez que un usuario inicia sesión local en el sistema.

### Funcionamiento

- Utiliza la variable `PAM_USER` y `PAM_TTY` para registrar qué usuario inició sesión y desde qué terminal.
- El mensaje se envía usando `curl` a un servidor `ntfy`.

### Requisitos

Debe integrarse con PAM (Pluggable Authentication Modules). Para ello, añade la siguiente línea al archivo `/etc/pam.d/common-auth` (o el archivo de PAM correspondiente en tu sistema):

```pam
auth    optional    pam_exec.so /usr/local/bin/LocalLogin.sh
```

## 2. Monitor de Conexiones de Red (`network_monitor.sh`)

Este script monitorea en tiempo real las conexiones de red activas en el sistema y envía una notificación a través de `ntfy` cuando se detectan nuevas conexiones o cambios relevantes.

### Funcionamiento

- Usa `ss -tunap` para listar todas las conexiones TCP y UDP activas.
- Compara el estado actual con el estado previo (guardado en `/tmp/network_connections.log`) para detectar diferencias.
- Filtra conexiones por puerto (`FILTER_PORT`) o IP (`FILTER_IP`) si se configura.
- Envía un mensaje formateado en Markdown a través de `curl` usando el servidor `ntfy`.

### Formato de las notificaciones

Las notificaciones incluyen:
- La fecha y hora del evento.
- Una tabla Markdown con detalles de la(s) nueva(s) conexión(es).
- Una tabla con todas las conexiones activas.

### Configuración del Script

Edita los siguientes valores al inicio del script:

```bash
NTFY_TOPIC="Your_ntfy_topic"      # Tema del canal ntfy
NTFY_SERVER="Your_ntfy_server"    # URL del servidor ntfy
INTERVAL=5                        # Intervalo de monitoreo en segundos
FILTER_IP=""                      # IP que se desea excluir (opcional)
FILTER_PORT=""                # Puerto que se exclute (tu puerto de ntfy[para evitar el flood de mensajes]) 
```
