#!/bin/bash

# Set variables
TIMESTAMP=$(date +'%Y%m%d%H%M%S')
BACKUP_DIR="/var/backups/moodle"
MAX_AGE_DAYS=5

# Perform MySQL backup
mysqldump "moodle" > "$BACKUP_DIR/backup_$TIMESTAMP.sql"

# Clean up old backup files
find "$BACKUP_DIR" -name "backup_*.sql" -type f -mtime +$MAX_AGE_DAYS -exec rm {} \;


#0 1 * * * /path/to/mysql_backup.sh
