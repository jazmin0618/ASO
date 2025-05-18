Semana7
# LDAP Backup Scripts

Scripts para realizar y descargar copias de seguridad del servicio de directorio LDAP.
## Archivos incluidos
- `ldap_backup.sh`: Ejecutado en el servidor LDAP, genera un respaldo diario en `/var/backups/ldap/`.
- `descargar_backups.sh`: Ejecutado en el cliente, descarga automáticamente los respaldos de los últimos 7 días.
