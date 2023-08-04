#!/bin/bash

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> /var/www/moodle-upgrade.log
}

log "Starting Moodle upgrade process."

# Change to the Moodle installation directory
cd /var/www/moodle

# Fetch the latest changes from the remote repository
log "Fetching latest changes from origin."
git fetch origin

# Switch to the MOODLE_401_STABLE branch
log "Switching to MOODLE_401_STABLE branch."
git checkout MOODLE_401_STABLE

# Pull the latest changes from the MOODLE_401_STABLE branch
log "Pulling the latest changes from MOODLE_401_STABLE branch."
git pull

# Capture the SHA-1 hash of the latest commit
LATEST_COMMIT=$(git rev-parse HEAD)

# Execute the Moodle upgrade script
log "Running Moodle upgrade script."
/var/www/moodle/admin/cli/upgrade.php

# Check the exit code of the upgrade script
if [ $? -ne 0 ]; then
    log "Moodle upgrade failed. Rolling back to the previous version."
    
    # Perform a hard reset back to the previous commit
    git reset --hard "$LATEST_COMMIT"
    
    log "Moodle rollback completed."
else
    log "Moodle upgrade successful."
    LAST_COMMIT=LATEST_COMMIT  
fi

log "Moodle upgrade process completed."


