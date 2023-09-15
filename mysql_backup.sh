#!/bin/bash

# Set variables
TIMESTAMP=$(date +'%Y%m%d%H%M%S')
BACKUP_DIR="/var/backups/moodle"
MAX_AGE_DAYS=5
MOODLE_DIR="/var/www/moodle"
PHP_SCRIPT="/var/www/moodle/backup/backup.php"

# Perform MySQL backup
mysqldump "moodle" > "$BACKUP_DIR/mysql_backup_$TIMESTAMP.sql"

# Clean up old MySQL backup files
find "$BACKUP_DIR" -name "mysql_backup_*.sql" -type f -mtime +$MAX_AGE_DAYS -exec rm {} \;
find "$BACKUP_DIR" -name "*.mbz" -type f -mtime +$MAX_AGE_DAYS -exec rm {} \;


cd /var/www/moodle/admin/cli
# Get a list of course IDs from the database
IDS=$(mysql moodle -se "SELECT id FROM mdl_course")

# Loop through each ID and run the PHP command
for ID in $IDS
do
      /usr/bin/php /var/www/moodle/admin/cli/backup.php --courseid="$ID" --destination="/var/backups/moodle"
done
"backup.
