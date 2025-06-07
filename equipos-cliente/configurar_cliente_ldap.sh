#!/bin/bash

# ============================
# Script de configuración LDAP

if [ -z "$1" ]; then
    echo "❌ Debes pasar el dominio como argumento. Ejemplo:"
    echo "   sudo $0 miempresa.com"
    exit 1
fi

DOMINIO=$1
BASE_DN=$(echo $DOMINIO | sed 's/\./,dc=/g' | sed 's/^/dc=/')
IP_SERVIDOR_LDAP="192.168.1.10"   # IP del servidor LDAP

menu() {
  echo ""
  echo "===== MENÚ DE CONFIGURACIÓN LDAP CLIENTE ====="
  echo "Dominio LDAP: $DOMINIO → Base DN: $BASE_DN"
  echo "1. Instalar paquetes necesarios"
  echo "2. Configurar LDAP Auth"
  echo "3. Editar NSSwitch"
  echo "4. Habilitar PAM para crear home"
  echo "5. Reiniciar servicios"
  echo "6. Probar conexión con ldapsearch"
  echo "7. Salir"
  echo "=============================================="
  echo -n "Elige una opción (1-7): "
}

instalar_paquetes() {
    echo "🔧 Instalando paquetes..."
    sudo apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install -y libnss-ldap libpam-ldap ldap-utils nscd
    echo "✅ Paquetes instalados"
}

configurar_auth() {
    echo "🔧 Configurando autenticación LDAP..."

    sudo auth-client-config -t nss -p lac_ldap || true

    sudo bash -c "cat > /etc/ldap.conf" <<EOF
base $BASE_DN
uri ldap://$IP_SERVIDOR_LDAP
ldap_version 3
bind_policy soft
pam_password md5
EOF

    sudo bash -c "cat > /etc/nslcd.conf" <<EOF
uid nslcd
gid nslcd
uri ldap://$IP_SERVIDOR_LDAP
base $BASE_DN
EOF

    echo "✅ LDAP Auth configurado"
}

editar_nsswitch() {
    echo "🔧 Editando /etc/nsswitch.conf..."

    sudo sed -i 's/^passwd:.*/passwd:         files ldap/' /etc/nsswitch.conf
    sudo sed -i 's/^group:.*/group:          files ldap/' /etc/nsswitch.conf
    sudo sed -i 's/^shadow:.*/shadow:         files ldap/' /etc/nsswitch.conf

    echo "✅ NSSwitch configurado"
}

habilitar_pam_home() {
    echo "🔧 Habilitando creación de home automático..."
    PAM_FILE="/etc/pam.d/common-session"
    if ! grep -q "pam_mkhomedir.so" "$PAM_FILE"; then
        echo "session required pam_mkhomedir.so skel=/etc/skel umask=0022" | sudo tee -a "$PAM_FILE"
        echo "✅ Línea agregada a $PAM_FILE"
    else
        echo "ℹ️ Ya está configurado"
    fi
}

reiniciar_servicios() {
    echo "🔄 Reiniciando servicios..."
    sudo systemctl restart nscd || true
    echo "✅ Servicios reiniciados"
}

probar_ldapsearch() {
    echo "🔍 Probar conexión con ldapsearch..."
    ldapsearch -x -H ldap://$IP_SERVIDOR_LDAP -b "$BASE_DN"
}

# ========================
# Menú interactivo
# ========================

while true; do
    menu
    read opcion
    case $opcion in
        1) instalar_paquetes ;;
        2) configurar_auth ;;
        3) editar_nsswitch ;;
        4) habilitar_pam_home ;;
        5) reiniciar_servicios ;;
        6) probar_ldapsearch ;;
        7) echo "👋 Saliendo..." ; exit 0 ;;
        *) echo "❌ Opción inválida" ;;
    esac
done