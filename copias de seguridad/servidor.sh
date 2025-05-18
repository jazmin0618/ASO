#!/bin/bash

RUTA="/var/backups/ldap_backup"
FECHA=$(date +%F)
ARCHIVO="$RUTA/ldap-backup-$FECHA.ldif"

function crear_respaldo() {
    echo "[1] Creando respaldo de hoy ($FECHA)..."
    sudo slapcat | sudo tee "$ARCHIVO" > /dev/null
    echo "[✔] Respaldo guardado en: $ARCHIVO"
}

function restaurar_respaldo() {
    read -p "Ingrese la fecha del respaldo a restaurar (formato YYYY-MM-DD): " fecha
    archivo_restaurar="$RUTA/ldap-backup-$fecha.ldif"

    if [[ -f "$archivo_restaurar" ]]; then
        echo "[2] Restaurando respaldo de $fecha..."
        sudo systemctl stop slapd
        sudo slapadd < "$archivo_restaurar"
        sudo chown -R openldap:openldap /var/lib/ldap
        sudo systemctl start slapd
        echo "[✔] Restauración completada."
    else
        echo "[X] Archivo $archivo_restaurar no existe."
    fi
}

while true; do
    echo ""
    echo "========== MENU DE LDAP =========="
    echo "[1] Crear copia de seguridad de hoy"
    echo "[2] Restaurar una copia desde archivo"
    echo "[3] Salir"
    echo "=================================="
    read -p "Seleccione una opción [1-3]: " opcion

    case $opcion in
        1) crear_respaldo ;;
        2) restaurar_respaldo ;;
        3) echo "Saliendo..."; exit 0 ;;
        *) echo "[X] Opción inválida." ;;
    esac
done
