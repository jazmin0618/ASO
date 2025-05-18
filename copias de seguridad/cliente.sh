#!/bin/bash

# Configuración
SERVIDOR="192.168.1.16"         # IP del servidor LDAP
USUARIO="lubuntu"               # Usuario con acceso SSH al servidor
ORIGEN="/var/backups/ldap_backup"
DESTINO="/home/jazmin/ldap_copias"

# Crear carpeta local si no existe
mkdir -p "$DESTINO"

# Función: Descargar todos los respaldos
function descargar_todo() {
    echo "[1] Descargando todos los respaldos..."
    if scp "$USUARIO@$SERVIDOR:$ORIGEN/*.ldif" "$DESTINO"; then
        echo "[✔] Descarga completada. Archivos en $DESTINO"
    else
        echo "[X] Error: No se pudo conectar al servidor o no hay archivos."
    fi
}

# Función: Descargar respaldo por fecha
function descargar_por_fecha() {
    read -p "Ingrese la fecha del respaldo a descargar (YYYY-MM-DD): " fecha
    archivo="ldap-backup-$fecha.ldif"
    if scp "$USUARIO@$SERVIDOR:$ORIGEN/$archivo" "$DESTINO"; then
        echo "[✔] Archivo $archivo descargado correctamente."
    else
        echo "[X] Error al descargar $archivo. ¿La fecha es correcta?"
    fi
}

# Menú principal
while true; do
    echo "======== CLIENTE LDAP ========"
    echo "[1] Descargar todos los respaldos"
    echo "[2] Descargar respaldo por fecha"
    echo "[3] Salir"
    echo "==============================="
    read -p "Seleccione una opción [1-3]: " opcion

    case $opcion in
        1) descargar_todo ;;
        2) descargar_por_fecha ;;
        3) echo "Saliendo..."; break ;;
        *) echo "[X] Opción inválida. Intente de nuevo." ;;
    esac
done
