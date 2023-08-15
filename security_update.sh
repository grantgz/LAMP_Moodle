#!/bin/bash

# This function is intended ONLY to update security patches, ie weekly updates
# It is not intended to update Moodle ie from 4.1 to 4.2

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> /var/www/moodle-update.log
}

log "Starting Moodle security update process."

# Change to the Moodle installation directory
cd /var/www/moodle

# Capture the SHA-1 hash of the existing commit
LAST_COMMIT=$(git rev-parse HEAD)

# Fetch the latest changes from the remote repository
git fetch origin

# Capture the SHA-1 hash of the new commit
LATEST_COMMIT=$(git rev-parse HEAD)

# Check if there are new commits since the last update
if [ "$LATEST_COMMIT" != "$LAST_COMMIT" ]; then
    log "New Moodle commits found. Enabling maintenance mode."
    log "Running Moodle security update script."
    log "Last commit: $LAST_COMMIT"
    log "Latest commit: $LATEST_COMMIT"
  
    # Enable maintenance mode
    sudo -u www-data /usr/bin/php admin/cli/maintenance.php --enable
    sudo -u www-data /usr/bin/php /var/www/moodle/admin/cli/upgrade.php --non-interactive

    # Check the exit code of the upgrade script
    if [ $? -ne 0 ]; then
        log "Moodle upgrade failed. Rolling back to the previous version."
        # Perform a hard reset back to the previous commit
        git reset --hard "$LAST_COMMIT"
        log "Moodle rollback completed."
    else
        log "Moodle upgrade successful."
        LAST_COMMIT=$LATEST_COMMIT
    fi
    log "Disabling maintenance mode."
    sudo -u www-data /usr/bin/php admin/cli/maintenance.php --disable
fi

log "Moodle security update process completed."


(crontab -l ; echo "$CRON_JOB") | crontab




