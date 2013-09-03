sql-backup for Drupal
======================

The `sql-update` script is used by Classic Graphics to refresh the DB from our production environment to the development environment to ensure weare working with current data during development.  This script currently depends heavily on system and database names to be configured in a specific manner as outlined below:
  1. Hostname of development systems should begin with the name of the production system. (Ex: Test system for somesite.knowclassic.com would be named somesite-test.knowclassic.com)
  2. Database name for production and development systems should match hostname - domainname, replacing the dash `-` character with an underscore `_`. (Ex: DB for test system for above would be named somesite_test, and production DB would be named somesite)
  3. You should create a **READ ONLY** account to be used while reading the production DB.  We also recommened that the DB be read from a `replication slave` server, to minimize stress on the production DB system.
  4. Script expects the current sites/default/settings.php file to be configured correctly for the development system you are refreshing the DB on.

Using the `sql-update` script frees developers from having to learn complexe mysqldump parameters, and brings a standard, repeatable process to all development servers, minimizing mistakes and lost development time due to chasing DB dump related issues.

The `sql-update` performs the following actions:
  1. Dumps a copy of the remote production DB into the current VM's development DB.
  2. Truncates all `cache_%` tables in the current development DB.
  3. Checks for memcached, and flushs its cache if found to be running
  4. Uses drush to clear drupal's cache and sessions (redundant)
  5. Determines if a file named global-sql-update exists in `/usr/loca/bin` and is readable.  If a files is found, the contents are sourced into the sql-update script, and executed in-line.  Good things to place here, would be any drush commands that need to be run against the production DB to get things setup for your development environment (Ex: enabling modules, rerouting emails to a blackhole account, etc).  Things that should be done on ALL DB dumps should be placed here.  You should rarely touch this file once setup properly.
  6. Determines if a file name sql-update in the current user's home directory, and if so is it readable?  If yes, then the contents are again sourced and executed in-line.  Things dealing with only the CURRENT ticket you are working should be entered here.  This file should be updated with each new issue you are working on.

That's about it.  Happy SQL'ing!