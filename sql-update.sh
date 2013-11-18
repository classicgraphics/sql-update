#!/bin/bash

# There should never be a reason to run this script as root, so disabling it
if [[ ${EUID} -eq 0 ]]; then
  echo "This script should be run with your normal user account."
  exit 1
fi

# Fully Qualified domain name of this server
FQDN=$(hostname -f)

# The name of the destination database, based on hostname
DB=$(hostname | sed 's/-/_/g')

# The name of the source database, extraced from hostname
MASTERDB=$(hostname | sed 's/\(.-\).*/\1/; s/-//g;')

# A Read Only account that has SELECT permissions on the "source" database
MASTERDBUSER="ro_account"
MASTERDBPASS="yoursecretpassword"

# Read Only DB server (typically would be a slave to the production DB server)
RODBSERVER="dbro.yourdomain.com"

# Your web servers DocRoot directory
WEBROOT="/var/www"

echo "Refreshing ${DB} database..."

# Change directory to the webroot.
cd ${WEBROOT}

# Drop tables.
echo "Dropping all tables in ${DB}..."
drush sql-drop -y

# Copy db from prod.
echo "Copying ${MASTERDB} database to ${DB}..."
mysqldump -v --opt --complete-insert --hex-blob --max-allowed-packet=1073741824 --single-transaction -u ${MASTERDBUSER} -h ${RODBSERVER} -p${MASTERDBPASS} ${MASTERDB} --ssl-key=/etc/ssl/mariadb/${FQDN}.key --ssl-cert=/etc/ssl/mariadb/${FQDN}.crt --ssl-ca=/etc/ssl/mariadb/ca.crt | drush sql-cli

# Truncate the cache tables.
echo "Truncating database cache tables..."
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
if [[ `sudo service memcached status` =~ 'memcached is running' ]]; then
  echo "flush_all" | nc localhost 11211
  echo "memcached flushed!"
fi

# Clear Drupal caches.
echo "Clearing Drupal caches"
drush cc all

# run global sql-update command file
if [[ -s /usr/local/bin/global-sql-update ]]; then
  echo -n "Running Global sql-update commands . . . "
  . /usr/local/bin/global-sql-update
  echo "Complete"
else
  echo "Global sql-update command file not found"
fi

# Run user sql-update command file
if [[ -s ~/sql-update ]]; then
  echo -n "Running $(whoami)'s sql-update commands . . . "
  . ~/sql-update
  echo "Complete
else
  echo "No sql-update command file found for $(whoami)"
fi

echo "Database refresh complete!"
