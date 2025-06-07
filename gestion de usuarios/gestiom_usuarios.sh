#!/bin/bash

DOMINIO="dc=miempresa,dc=com"
OU_USUARIOS="ou=usuarios"
ADMIN_DN="cn=admin,$DOMINIO"  
BASE_DN="$OU_USUARIOS,$DOMINIO"
LDAP_SERVER="ldap://192.168.1.10"
LDAP_OPTS="-x -H $LDAP_SERVER"

# Verificar conexión LDAP
verificar_ldap() {
    echo "🔍 Verificando conexión LDAP..."
    if ldapwhoami $LDAP_OPTS 2>/dev/null | grep -q "anonymous"; then
        echo "✅ Conexión LDAP activa (servidor: $LDAP_SERVER)"
        echo "Base DN: $BASE_DN"
        return 0
    else
        echo "❌ Error: No se pudo conectar a $LDAP_SERVER"
        echo "Verifica:"
        echo "1. Que el servidor LDAP (192.168.1.10) esté accesible"
        echo "2. Que tengas permisos de administrador"
        return 1
    fi
}

# Crear usuario
crear_usuario() {
    echo "📝 Creación de nuevo usuario en $BASE_DN"
   
    read -p "Nombre: " nombre
    read -p "Apellido: " apellido
    read -p "Nombre de usuario (uid): " uid
   
    # Verificar si el usuario ya existe
    if ldapsearch $LDAP_OPTS -b "uid=$uid,$BASE_DN" uid 2>/dev/null | grep -q "^uid:"; then
        echo "❌ Error: El usuario $uid ya existe!"
        return 1
    fi
   
    read -p "Correo electrónico: " mail
    read -p "Teléfono: " telefono
    read -s -p "Contraseña: " password
    echo
   
    # Calcular próximo uidNumber disponible
    LAST_UID=$(ldapsearch $LDAP_OPTS -b "$BASE_DN" uidNumber 2>/dev/null |
               awk '/uidNumber:/ {print $2}' | sort -n | tail -1)
    UID_NUMBER=$((LAST_UID + 1))
   
    echo "Creando usuario $uid con uidNumber $UID_NUMBER..."
   
    ldapadd $LDAP_OPTS -D "$ADMIN_DN" -W <<EOF
dn: uid=$uid,$BASE_DN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: $nombre $apellido
sn: $apellido
uid: $uid
uidNumber: $UID_NUMBER
gidNumber: 10000
homeDirectory: /home/$uid
mail: $mail
mobile: $telefono
userPassword: $(slappasswd -s "$password" -crypt)
loginShell: /bin/bash
EOF
   
    # Verificación
    echo "✅ Usuario creado. Verificando..."
    ldapsearch $LDAP_OPTS -b "uid=$uid,$BASE_DN" dn uid cn mail mobile
}

# Función para modificar usuario
modificar_usuario() {
    echo "🔄 Modificación de usuario existente"
   
    read -p "Nombre de usuario (uid) a modificar: " uid
   
    # Verificar existencia
    if ! ldapsearch $LDAP_OPTS -b "uid=$uid,$BASE_DN" uid 2>/dev/null | grep -q "^uid:"; then
        echo "❌ Error: El usuario $uid no existe!"
        return 1
    fi
   
    echo "Datos actuales del usuario:"
    ldapsearch $LDAP_OPTS -b "uid=$uid,$BASE_DN" cn mail mobile
   
    echo "1. Cambiar correo electrónico"
    echo "2. Cambiar número de teléfono"
    read -p "Seleccione qué desea modificar: " opcion
   
    case $opcion in
        1)
            read -p "Nuevo correo electrónico: " nuevo_valor
            atributo="mail"
            ;;
        2)
            read -p "Nuevo teléfono: " nuevo_valor
            atributo="mobile"
            ;;
        *)
            echo "❌ Opción no válida"
            return 1
            ;;
    esac
   
    ldapmodify $LDAP_OPTS -D "$ADMIN_DN" -W <<EOF
dn: uid=$uid,$BASE_DN
changetype: modify
replace: $atributo
$atributo: $nuevo_valor
EOF
   
    echo "✅ Usuario modificado. Nuevos datos:"
    ldapsearch $LDAP_OPTS -b "uid=$uid,$BASE_DN" $atributo
}

# Función para borrar usuario
borrar_usuario() {
    echo "🗑️  Eliminación de usuario"
   
    read -p "Nombre de usuario (uid) a eliminar: " uid
   
    # Verificar existencia
    if ! ldapsearch $LDAP_OPTS -b "uid=$uid,$BASE_DN" uid 2>/dev/null | grep -q "^uid:"; then
        echo "❌ Error: El usuario $uid no existe!"
        return 1
    fi
   
    echo "Datos del usuario a eliminar:"
    ldapsearch $LDAP_OPTS -b "uid=$uid,$BASE_DN" dn uid cn
   
    read -p "¿Está seguro que desea eliminar este usuario? (s/n): " confirmacion
   
    if [[ "$confirmacion" =~ [sS] ]]; then
        ldapdelete $LDAP_OPTS -D "$ADMIN_DN" -W "uid=$uid,$BASE_DN"
        echo "✅ Usuario $uid eliminado."
       
        # Verificación
        echo "Verificando eliminación..."
        if ! ldapsearch $LDAP_OPTS -b "uid=$uid,$BASE_DN" uid 2>/dev/null | grep -q "^uid:"; then
            echo "✅ Eliminación confirmada"
        else
            echo "⚠️  El usuario parece seguir existiendo"
        fi
    else
        echo "Operación cancelada"
    fi
}

# Función para buscar usuario
buscar_usuario() {
    echo "🔍 Búsqueda de usuarios"
   
    echo "1. Buscar por nombre"
    echo "2. Buscar por apellido"
    echo "3. Buscar por uid"
    read -p "Seleccione opción de búsqueda: " opcion
   
    case $opcion in
        1)
            read -p "Introduzca nombre: " termino
            atributo="cn"
            ;;
        2)
            read -p "Introduzca apellido: " termino
            atributo="sn"
            ;;
        3)
            read -p "Introduzca uid: " termino
            atributo="uid"
            ;;
        *)
            echo "❌ Opción no válida"
            return 1
            ;;
    esac
   
    echo "Resultados para $atributo = *$termino*:"
    echo "----------------------------------------"
    ldapsearch $LDAP_OPTS -b "$BASE_DN" "($atributo=*$termino*)" cn uid mail mobile | \
    awk '/^dn:/ {print "\nUsuario:"} /^cn:/ {print "Nombre:",$0} /^uid:/ {print "UID:",$0} /^mail:/ {print "Correo:",$0} /^mobile:/ {print "Teléfono:",$0}'
    echo "----------------------------------------"
}

# Menú principal
while true; do
    clear
    echo "=== GESTIÓN DE USUARIOS LDAP ==="
    echo "Empresa: $DOMINIO"
    echo "OU Usuarios: $OU_USUARIOS"
    echo "Servidor LDAP: $LDAP_SERVER"
    echo "--------------------------------"
    echo "1. Verificar conexión LDAP"
    echo "2. Crear nuevo usuario"
    echo "3. Modificar usuario"
    echo "4. Eliminar usuario"
    echo "5. Buscar usuarios"
    echo "6. Salir"
    echo ""
   
    read -p "Seleccione una opción (1-6): " opcion
   
    case $opcion in
        1) verificar_ldap ;;
        2) crear_usuario ;;
        3) modificar_usuario ;;
        4) borrar_usuario ;;
        5) buscar_usuario ;;
        6)
            echo "Saliendo del sistema..."
            exit 0
            ;;
        *)
            echo "❌ Opción no válida"
            ;;
    esac
   
    read -p "Presione Enter para continuar..."
done