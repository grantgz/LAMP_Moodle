#!/bin/bash

# Prompt for the web address
read -p "Enter the web address: " WEBSITE_ADDRESS

# Check if the input is not empty
if [ -n "$WEBSITE_ADDRESS" ]; then
    # Validate the input as a valid FQDN or IPv4 address
    if [[ $WEBSITE_ADDRESS =~ ^((http|https):\/\/)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(\/\S*)?$ ]]; then
        # If the input is a valid FQDN, set FQDN to the entered value
        FQDN="y"
    elif [[ $WEBSITE_ADDRESS =~ ^((http|https):\/\/)?([0-9]{1,3}\.){3}[0-9]{1,3}(\/\S*)?$ ]]; then
        FQDN="n"
    else
        echo "Invalid web address. Please enter a valid FQDN or IPv4 address (e.g., http://example.com or http://192.168.1.100)."
        exit 1
    fi
fi

#Step 1 Update the system and install git, Apache, PHP and modules required by Moodle
sudo apt-get update
sudo apt upgrade -y
sudo apt-get install -y apache2 php libapache2-mod-php php-mysql graphviz aspell git 
sudo apt-get install -y clamav php-pspell php-curl php-gd php-intl php-mysql ghostscript
sudo apt-get install -y php-xml php-xmlrpc php-ldap php-zip php-soap php-mbstring
sudo apt-get install -y  ufw unzip
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades
#Install Debian default database MariaDB 
sudo apt-get install -y mariadb-server mariadb-client
sudo apt install -y certbot python3-certbot-apache
WEB_SERVER_USER="www-data"
echo "Step 1 apt install has completed."


## Changing tabs confuses Geany
	-# Configure unattended-upgrades
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}:\${distro_codename}-updates";
};
EOF
# Enable automatic updates
sudo tee /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
	# Restart the unattended-upgrades service
	sudo systemctl restart unattended-upgrades
echo "Step 1 has completed."
 
# Step 2 Get PHP and MariaDB version 
# Select Moodle version and set database variables where necessary
# Clone the Moodle repository into /var/www
# Based on chart http://www.syndrega.ch/blog/
php_version=$(sudo php -r 'echo PHP_MAJOR_VERSION,PHP_MINOR_VERSION;')
mariadb_version=$(sudo mysqladmin --version | awk '{print $5}' |  tr -d -c 0-9)
echo   "mariadb_version $mariadb_version"
# Check if the MariaDB version is less than or equal to  10.3.38
if [[ "$mariadb_version" -le 10338 ]]; then # Debugged line
    # Check the current values of specific MySQL variables
    variables=$(sudo mysql "SHOW GLOBAL VARIABLES WHERE variable_name IN ('innodb_file_format', 'innodb_large_prefix', 'innodb_file_per_table');" 2>/dev/null)
    # Extract the values from the output
    file_format=$(echo "$variables" | grep innodb_file_format | awk '{print $2}')
    file_per_table=$(echo "$variables" | grep innodb_file_per_table | awk '{print $2}')
    large_prefix=$(echo "$variables" | grep innodb_large_prefix | awk '{print $2}')
    # Check if the variables need to be updated
    if [ "$file_format" != "Barracuda" ] || [ "$file_per_table" != "ON" ] || [ "$large_prefix" != "ON" ]; then
        # Backup the original mysql.cnf file
        sudo cp /etc/mysql/conf.d/mysql.cnf /etc/mysql/conf.d/mysql.cnf.backup
        # Create the new mysql.cnf content
        new_config="[client]\ndefault-character-set = utf8mb4\n\n[mysqld]\n"
        new_config+="innodb_file_format = Barracuda\ninnodb_file_per_table = 1\ninnodb_large_prefix = 1\n"
        new_config+="character-set-server = utf8mb4\ncollation-server = utf8mb4_unicode_ci\nskip-character-set-client-handshake\n\n[mysql]\ndefault-character-set = utf8mb4\n"
        # Write the new content to mysql.cnf
        echo -e "$new_config" | sudo tee /etc/mysql/conf.d/mysql.cnf > /dev/null
		sudo systemctl restart mysql
        echo "MySQL configuration updated and database restarted."
    else
        echo "MySQL configuration is already set."
    fi
else
    echo "MariaDB version is > 10.3.38. No changes needed."
fi
compatible_moodle_versions=""
# Check compatible Moodle versions based on PHP and MariaDB versions
if [[ ( "$mariadb_version" -ge 5531  && "$mariadb_version" -le 10500 ) && \
      ( "$php_version" -ge 70 && "$php_version" -le 72 ) ]]; then
    compatible_moodle_versions+="MOODLE_35_STABLE "
fi
if [[ ( "$mariadb_version" -ge 10000  && "$mariadb_version" -le 10500 ) && \
      ( "$php_version" -ge 71 && "$php_version" -le 73 ) ]]; then
    compatible_moodle_versions+="MOODLE_37_STABLE "
fi
if [[ ( "$mariadb_version" -ge 10000  && "$mariadb_version" -le 10500 ) && \
      ( "$php_version" -ge 71 && "$php_version" -le 74 ) ]]; then
    compatible_moodle_versions+="MOODLE_38_STABLE "
fi
if [[ ( "$mariadb_version" -ge 10229  && "$mariadb_version" -le 10667 ) && \
      ( "$php_version" -ge 72 && "$php_version" -le 74 ) ]]; then
     compatible_moodle_versions+="MOODLE_39_STABLE MOODLE_310_STABLE "
fi
if [[ ( "$mariadb_version" -ge 10229  && "$mariadb_version" -le 10667 ) && \
      ( "$php_version" -ge 73 && "$php_version" -le 80 ) ]]; then
     compatible_moodle_versions+="MOODLE_311_STABLE MOODLE_400_STABLE "
fi
if [[ ( "$mariadb_version" -ge 10400  && "$mariadb_version" -le 10667 ) && \
      ( "$php_version" -ge 74 && "$php_version" -le 81 ) ]]; then
     compatible_moodle_versions+="MOODLE_401_STABLE "
fi
if [[ "$mariadb_version" -ge 10667 && ( "$php_version" -ge 80 && "$php_version" -lt 82 ) ]]; then
    compatible_moodle_versions+="MOODLE_402_STABLE "
fi
# List compatible Moodle versions in order
IFS=' ' read -ra moodle_versions <<< "$compatible_moodle_versions"
echo "Moodle releases compatible with this server are:"
for (( i=0; i<${#moodle_versions[@]}; i++ )); do
    echo "$((i+1)). ${moodle_versions[i]}"
done
# Prompt user to select a version
read -p "Select your version (1-${#moodle_versions[@]}) [Default is latest]: " selection
# Set default selection to the latest release
if [[ -z "$selection" ]]; then
    selection="${#moodle_versions[@]}"
fi
# Validate user selection
if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le "${#moodle_versions[@]}" ]]; then
    MoodleVersion="${moodle_versions[$((selection-1))]}"
    echo "Selected Moodle version: $selected_version"
else
    echo "MariaDB and php versions on this server are incompatible with Moodle versions"
	echo "You will need to use a different Ubuntu or Debian release"
	exit 1
fi
echo "Cloning Moodle repository into /var/www/"
cd /var/www
sudo git clone https://github.com/moodle/moodle.git
cd moodle
sudo git checkout -t origin/$MoodleVersion
git config pull.ff only
# Check if the Moodle version is not in the list of incompatible versions
if [[ $MoodleVersion != "MOODLE_35_STABLE" && $MoodleVersion != "MOODLE_37_STABLE" && $MoodleVersion != "MOODLE_38_STABLE" ]]; then
    # Change to the Moodle local directory
    cd /var/www/moodle/local

    # Clone the local_adminer repository from Git
    sudo git clone https://github.com/grabs/moodle-local_adminer.git

    # Rename the cloned directory to match the expected plugin directory name
    sudo mv moodle-local_adminer adminer

    # Change into the plugin directory
    cd adminer

    # Update the plugin (pull any changes from the repository)
    sudo git pull origin master
    
    # Change to the Moodle root directory
	cd /var/www/moodle

	# Clone the moodle-report_benchmark repository from Git
	sudo git clone https://github.com/mikasmart/moodle-report_benchmark.git report/benchmark

	# Change into the benchmark directory
	cd report/benchmark

	# Update the plugin (pull any changes from the repository)
	sudo git pull origin master
fi
echo "Step 2 has completed."



# Step 3  Create a Moodle Virtual Host File and call certbot for https encryption
# Strip the 'http://' or 'https://' part from the web address
FQDN_ADDRESS=$(echo "$WEBSITE_ADDRESS" | sed -e 's#^https\?://##')
# Create a new moodle.conf file
cat << EOF | sudo tee /etc/apache2/sites-available/moodle.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/moodle
    ServerName "$FQDN_ADDRESS"
    ServerAlias "www.$FQDN_ADDRESS"

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
sudo a2dissite 000-default.conf
sudo a2ensite moodle.conf
if [ "$FQDN" = "y" ]; then    
        echo "Setting up SSL Certificates for your website"
        sudo ufw allow 'Apache Full'
        sudo ufw delete allow 'Apache'
        sudo certbot --apache
        WEBSITE_ADDRESS="https://${FQDN_ADDRESS#http://}"
fi
sudo systemctl reload apache2
echo "Step 3 has completed."

# Step 4 Directories, ownership, permissions and php.ini required by 
sudo mkdir -p /var/www/moodledata
sudo chown -R $WEB_SERVER_USER /var/www/moodledata
sudo chmod -R 777 /var/www/moodledata
sudo chmod -R 755 /var/www/moodle
# Determine PHP version
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
PHP_CONFIG_DIR="/etc/php/$PHP_VERSION"
# Update PHP configuration
sudo sed -i 's/.*max_input_vars =.*/max_input_vars = 5000/' "$PHP_CONFIG_DIR/apache2/php.ini"
sudo sed -i 's/.*max_input_vars =.*/max_input_vars = 5000/' "$PHP_CONFIG_DIR/cli/php.ini"
sudo sed -i 's/.*post_max_size =.*/post_max_size = 80M/' "$PHP_CONFIG_DIR/apache2/php.ini"
sudo sed -i 's/.*upload_max_filesize =.*/upload_max_filesize = 80M/' "$PHP_CONFIG_DIR/apache2/php.ini"
# Restart the web server based on distribution
sudo service apache2 restart
# Step 5 Directories, ownership, permissions completed

# Step 6  Create a user to run backups
# Generate a random password for backupuser
# Set backup directory and permissions
BACKUP_DIR="/var/backups/moodle"
sudo mkdir -p "$BACKUP_DIR"
# Generate a random password for DBbackupuser
DBbackupuserPW=$(openssl rand -base64 12)
SQLbackupuserPW=$(openssl rand -base64 12)
sudo useradd -m -d "/home/DBbackupuser" -s "/bin/bash" "DBbackupuser"
echo "DBbackupuser:$DBbackupuserPW" | sudo chpasswd
sudo usermod -aG mysql "DBbackupuser"
# Create and set permissions for .my.cnf
# Store the current user
original_user=$(whoami)
# Switch to the DBbackupuser user and pass the password variable
sudo -u DBbackupuser bash <<EOF
DBbackupuser_home="/home/DBbackupuser"
mycnf_file="\$DBbackupuser_home/.my.cnf"  # Use \$ to prevent interpolation
SQLbackupuserPW="$SQLbackupuserPW"  # Pass the password variable
# Create .my.cnf file with correct permissions so passwords are not passed in scripts
echo "[mysqldump]" > "\$mycnf_file"
echo "user=SQLbackupuser" >> "\$mycnf_file"
echo "password=\$SQLbackupuserPW" >> "\$mycnf_file"
echo "[client]" > "$mycnf_file"
echo "user=SQLbackupuser" >> "$mycnf_file"
echo "password=$SQLbackupuserPW" >> "$mycnf_file"
chmod 600 "\$mycnf_file"
unset DBbackupuserPW
chown DBbackupuser:DBbackupuser "\$mycnf_file"
EOF


# Switch back to the original user
sudo -u "$original_user" echo "Switched back to user: $original_user"
# Set permissions for the backup directory
sudo chown -R DBbackupuser:DBbackupuser "$BACKUP_DIR"
sudo chmod -R 700 "$BACKUP_DIR"

#  Set up cron jobs
# to run Moodle housekeeping every minue
# to keep Moodle code up to date
# to keep 5 days of database backups
sudo chmod +x  "/opt/Moodle/security_update.sh"
sudo chmod +x  "/opt/Moodle/mysql_backup.sh"
sudo touch /var/www/moodle-update.log
sudo chown :www-data /var/www/moodle-update.log
sudo chmod g+w /var/www/moodle-update.log
sudo sh -c 'echo "* * * * * www-data /var/www/moodle/admin/cli/cron.php >/dev/null" >> /etc/crontab'
sudo sh -c 'echo "0 0 * * * www-data /bin/bash /opt/Moodle/security_update.sh >/dev/null" >> /etc/crontab'
sudo sh -c 'echo "0 0 * * * DBbackupuser /bin/bash /opt/Moodle/mysql_backup.sh >/dev/null" >> /etc/crontab'
# Step 6 has finished


# Step 7 Set the MySQL service and create the database and user for Moodle
MYSQL_MOODLEUSER_PASSWORD=$(openssl rand -base64 6)
MOODLE_ADMIN_PASSWORD=$(openssl rand -base64 6)
# Set the root password using mysqladmin
#sudo mysqladmin -u root password "$MYSQL_ROOT_PASSWORD"
# Create the Moodle database and user
echo "Creating the Moodle database and user..."
sudo mysql   <<EOF
CREATE DATABASE moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY '$MYSQL_MOODLEUSER_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, CREATE TEMPORARY TABLES, DROP, INDEX, ALTER ON moodle.* TO 'moodleuser'@'localhost';
CREATE USER 'SQLbackupuser'@'localhost' IDENTIFIED BY '$SQLbackupuserPW';
GRANT SELECT ON moodle.* TO 'DBbackupuser'@'localhost';
\q
EOF
sudo chmod -R 777 /var/www/moodle
sudo mkdir /etc/moodle_installation
sudo chmod 700 /etc/moodle_installation
# Create info.txt and add installation details with date and time
sudo bash -c "echo 'Installation script' > /etc/moodle_installation/info.txt"
sudo bash -c "echo 'Date and Time of Installation: $(date)' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'Web Address: $WEBSITE_ADDRESS ' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'Moodle SQL user password: $MYSQL_MOODLEUSER_PASSWORD' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'The following password is used by admin to log on to Moodle' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'Moodle Site Password for admin: $MOODLE_ADMIN_PASSWORD' >> /etc/moodle_installation/info.txt"
cat /etc/moodle_installation/info.txt
echo "Step 7 Database setup has completed."


#Step 8 Finish the install 
echo "The script will now try to finish the installation. If this fails, log on to your site at $WEBSITE_ADDRESS and follow the prompts."
INSTALL_COMMAND="sudo -u $WEB_SERVER_USER /usr/bin/php /var/www/moodle/admin/cli/install.php \
    --non-interactive \
    --lang=en \
    --wwwroot=\"$WEBSITE_ADDRESS\" \
    --dataroot=/var/www/moodledata \
    --dbtype=mariadb \
    --dbhost=localhost \
    --dbname=moodle \
    --dbuser=moodleuser \
    --dbpass=\"$MYSQL_MOODLEUSER_PASSWORD\" \
    --fullname=Dummy_Name\
    --shortname=\DN \
    --adminuser=admin \
    --summary=\"\" \
    --adminpass=\"$MOODLE_ADMIN_PASSWORD\" \
    --adminemail=joe@123.com \
    --agree-license"

if eval "$INSTALL_COMMAND"; then
    echo "Moodle installation completed successfully."
    sudo chmod -R 755 /var/www/moodle
    echo "You can now log on to your new Moodle at $WEBSITE_ADDRESS as admin with $MOODLE_ADMIN_PASSWORD"
else
    echo "Error: Moodle installation encountered an error. Go to $WEBSITE_ADDRESS and follow the prompts to complete the installation."

fi
#Step 8 has finished"

# Run the MySQL secure installation script
sudo mysql_secure_installation

sudo cat /etc/moodle_installation/info.txt
echo "For better security on web accessible sites, copy the contents of /etc/moodle_installation/info.txt to your password manager and delete the file"












