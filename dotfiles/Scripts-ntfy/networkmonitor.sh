#!/bin/bash

# Configuración
NTFY_TOPIC="Your_ntfy_topic"
NTFY_SERVER="Your_ntfy_server"
INTERVAL=5
LOG_FILE="/tmp/network_connections.log"
FILTER_IP=""  
FILTER_PORT="8888"        

# filter
filter_connections() {
    local connections="$1"
    echo "$connections" | grep -vE "$FILTER_PORT(\\s|$)"
}

# markdown
format_connections() {
    local connections="$1"
    echo -e "| Protocolo | Dirección Local | Dirección Remota | Estado | Proceso |\n|-----------|-----------------|------------------|--------|---------|"
    echo "$connections" | awk '
    NR>1 {
        proto = $1;
        local = $5;
        remote = $6;
        state = $2;
        
        # Extraer proceso
        process = "";
        for (i=7; i<=NF; i++) {
            process = process " " $i;
        }
        sub(/^ /, "", process);
        
        # Formatear para markdown
        printf "| %-8s | %-15s | %-16s | %-6s | %-30s |\n", proto, local, remote, state, process;
    }'
}

send_notification() {
    local title="$1"
    local message="$2"
    curl -s \
        -H "Title: $title" \
        -H "Priority: default" \
        -H "Tags: computer,network" \
        -d "$message" \
        "$NTFY_SERVER/$NTFY_TOPIC" > /dev/null
}

#filter
filter_connections "$(ss -tunap)" > "$LOG_FILE"

echo "Iniciando monitoreo de conexiones de red..."
send_notification "Monitor de Red Iniciado" "Se comenzará a monitorear las conexiones cada $INTERVAL segundos\n\nFiltrando conexiones a $FILTER_IP:$FILTER_PORT"

while true; do
    # Obtener y filtrar conexiones actuales
    CURRENT_CONNECTIONS=$(filter_connections "$(ss -tunap)")
    CURRENT_TABLE=$(format_connections "$CURRENT_CONNECTIONS")
    
    # Comparar con las conexiones anteriores
    if ! diff -q "$LOG_FILE" <(echo "$CURRENT_CONNECTIONS") > /dev/null; then
        # Obtener nuevas conexiones (ya filtradas)
        NEW_CONNECTIONS=$(comm -13 <(sort "$LOG_FILE") <(echo "$CURRENT_CONNECTIONS" | sort))
        
        if [ -n "$NEW_CONNECTIONS" ]; then
            # Formatear nuevas conexiones
            NEW_TABLE=$(format_connections "$NEW_CONNECTIONS")
            
            # Preparar mensaje Markdown
            MESSAGE="#·Nueva Conexión Detectada·[$(date)]# \n\n**Detalles:**\n${NEW_TABLE}\n\n**Tabla Completa de Conexiones:**\n${CURRENT_TABLE}"
            
            # Enviar notificación
            send_notification "///" "$MESSAGE"
            
            # Actualizar archivo de registro
            echo "$CURRENT_CONNECTIONS" > "$LOG_FILE"
        fi
    fi
    
    sleep $INTERVAL
done
