#!/bin/bash

FQDN=$(hostname -f)
DB=$(hostname | sed 's/-/_/g')
MASTERDB=$(hostname | sed 's/\(.-\).*/\1/; s/-//g;')
MASTERDBUSER="ro_account"
MASTERDBPASS="yoursecretpassword"
RODBSERVER="dbro.yourdomain.com"
WEBROOT="/var/www"

echo "Refreshing ${DB} database..."

# Change directory to the webroot.
cd ${WEBROOT}

# Drop tables.
echo "Dropping all tables in ${DB}..."
drush sql-drop -y

# Copy db from prod.
echo "Copying ${MASTERDB} database to ${DB}..."
mysqldump -v -q --add-drop-table --add-locks --complete-insert --create-options --disable-keys --lock-tables --quick --set-charset --hex-blob --max-allowed-packet=1073741824 --single-transaction -u ${MASTERDBUSER} -h ${RODBSERVER} -p${MASTERDBPASS} ${MASTERDB} --single-transaction --ssl-key=/etc/ssl/mariadb/${FQDN}.key --ssl-cert=/etc/ssl/mariadb/${FQDN}.crt --ssl-ca=/etc/ssl/mariadb/ca.crt | drush sql-cli

# Truncate the cache tables.
echo "Truncating database cache tables since we use memcached..."
IFSSAVE=${IFS}
IFS=$'\n'

for T in $(echo "SELECT CONCAT('TRUNCATE TABLE ', TABLE_SCHEMA, '.', TABLE_NAME, ';') AS truncate_query FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${DB}' AND TABLE_NAME LIKE 'cache_%' AND TABLE_TYPE = 'BASE TABLE';" | drush sql-cli); do
  if [ "${T}" != "truncate_query" ]; then
    echo "Running drush sqlq '${T}'"
    drush sqlq "${T}"
  fi
done

IFS=${IFSSAVE}

# If memcached is running, flush it.
if [[ `sudo /etc/init.d/memcached status` =~ 'memcached is running' ]]; then
  echo "flush_all" | nc localhost 11211
  echo "memcached flushed!"
fi

# Clear Drupal caches.
drush cc all

# run global sql-update command file
if [[ -s /usr/local/bin/global-sql-update ]]; then
  echo "Running Global sql-update commands"
  . /usr/local/bin/global-sql-update
else
  echo "Global sql-update command file not found"
fi

# Run user sql-update command file
if [[ -s ~/sql-update ]]; then
  echo "Running $(whoami)'s sql-update commands"
  . ~/sql-update
else
  echo "No sql-update command file found for $(whoami)"
fi

echo "Database refresh complete!"
