#!/bin/sh
Release_file=/opt/releases.txt
 
if test -f "$Release_file"; then
  echo "Configuration des variables ODOO_URL et PGADMIN_URL "
  export ODOO_URL=$( awk 'NR==1 {print $2}' $Release_file )
  export PGADMIN_URL=$( awk 'NR==2 {print $2}' $Release_file )
else
  echo " Si les urls de ODOO_URL et PGADMIN_URL ne sont pas founis, nous allons utiliser les URL par défaut définies dans le Dockerfile"
fi
 
exec "$@"
