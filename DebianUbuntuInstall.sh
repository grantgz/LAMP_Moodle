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

# Attempt to update using apt-get
sudo apt-get update

# Check the exit status of apt-get
if [ $? -ne 0 ]; then
    echo "apt-get update failed, switching to yum update on CentOS..."
    
	## Install required packages
	sudo yum update -y
	sudo yum install -y epel-release
	sudo yum install -y httpd php php-mysqlnd php-gd php-intl php-xml php-ldap php-zip php-soap php-mbstring php-sodium clamav git unzip
	sudo systemctl start httpd
	sudo systemctl enable httpd
	sudo yum install -y mariadb-server
	sudo systemctl start mariadb
	sudo systemctl enable mariadb
	sudo dnf install firewalld
	sudo yum install -y certbot python3-certbot-apache
	WEB_SERVER_USER="apache"
    
    
    # Run yum update on CentOS
	# Install firewalld if not already installed
	sudo dnf install firewalld   # Use 'yum' instead of 'dnf' on CentOS 7
	# Start and enable the firewalld service
	sudo systemctl start firewalld
	sudo systemctl enable firewalld
	# Set default policies to deny incoming and allow outgoing traffic
	sudo firewall-cmd --set-default-zone=drop
	sudo firewall-cmd --set-default-zone=public   # For CentOS 7
	# Allow SSH (port 22) for remote access
	# Allow HTTP (port 80) and HTTPS (port 443) for web server
	# Allow MySQL (port 3306) for database access
	sudo firewall-cmd --add-service=ssh --permanent
	sudo firewall-cmd --add-service=http --add-service=https --permanent
	sudo firewall-cmd --add-service=mysql --permanent
	# Reload the firewall settings
	sudo firewall-cmd --reload


	# Daily security updates RedHat
	sudo yum install yum-cron   # Use 'dnf' instead of 'yum' on CentOS 8
	sudo systemctl start yum-cron
	sudo systemctl enable yum-cron
	sudo sed -i -e 's/^update_cmd = .*/update_cmd = security/' \
		-e 's/^update_messages = .*/update_messages = yes/' \
		-e 's/^download_updates = .*/download_updates = yes/' \
		-e 's/^apply_updates = .*/apply_updates = yes/' /etc/yum/yum-cron.conf
	sudo systemctl restart yum-cron
	##Redhat Version	
else
	DEBIAN="y"
    echo "apt-get update succeeded."
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
	sudo apt install certbot python3-certbot-apache
	WEB_SERVER_USER="www-data"
	echo "Step 1 has completed."

	# Step 2 Set up the firewall
	sudo ufw --force enable
	# Set default policies to deny incoming and allow outgoing traffic
	sudo ufw default deny incoming
	sudo ufw default allow outgoing
	# Allow SSH (port 22) for remote access
	# Allow HTTP (port 80) and HTTPS (port 443) for web server 
	# Allow MySQL (port 3306) for database access
	sudo ufw allow ssh
	sudo ufw allow 80
	sudo ufw allow 443
	sudo ufw allow 3306
	sudo ufw reload
	echo "Step 2 has completed."

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
	echo "Step 3 has completed."
   
fi
 
# Step 4 Clone the Moodle repository into /var/www
# Get PHP and MariaDB version version
# Based on chart http://www.syndrega.ch/blog/
php_version=$(php -r 'echo PHP_MAJOR_VERSION,PHP_MINOR_VERSION;')
mariadb_version=$(mysqladmin --version | awk '{print $5}' |  tr -d -c 0-9)
# Remove the dot and convert to integer
mariadb_version_int=$(echo "$mariadb_version" | tr -d '.')
compatible_moodle_versions=""

# Check compatible Moodle versions based on PHP and MariaDB versions
if [[ ( "$mariadb_version_int" -ge 5531  && "$mariadb_version_int" -le 10500 ) && \
      ( "$php_version" -ge 70 && "$php_version" -le 72 ) ]]; then
    compatible_moodle_versions+="MOODLE_35_STABLE "
fi
if [[ ( "$mariadb_version_int" -ge 10000  && "$mariadb_version_int" -le 10500 ) && \
      ( "$php_version" -ge 71 && "$php_version" -le 73 ) ]]; then
    compatible_moodle_versions+="MOODLE_37_STABLE "
fi
if [[ ( "$mariadb_version_int" -ge 10000  && "$mariadb_version_int" -le 10500 ) && \
      ( "$php_version" -ge 71 && "$php_version" -le 74 ) ]]; then
    compatible_moodle_versions+="MOODLE_38_STABLE "
fi
if [[ ( "$mariadb_version_int" -ge 10229  && "$mariadb_version_int" -le 10667 ) && \
      ( "$php_version" -ge 72 && "$php_version" -le 74 ) ]]; then
     compatible_moodle_versions+="MOODLE_39_STABLE MOODLE_310_STABLE "
fi
if [[ ( "$mariadb_version_int" -ge 10229  && "$mariadb_version_int" -le 10667 ) && \
      ( "$php_version" -ge 73 && "$php_version" -le 80 ) ]]; then
     compatible_moodle_versions+="MOODLE_311_STABLE MOODLE_40_STABLE "
fi
if [[ ( "$mariadb_version_int" -ge 10229  && "$mariadb_version_int" -le 10667 ) && \
      ( "$php_version" -ge 74 && "$php_version" -le 81 ) ]]; then
     compatible_moodle_versions+="MOODLE_401_STABLE "
fi
if [[ "$mariadb_version_int" -ge 10667 && ( "$php_version" -ge 80 && "$php_version" -lt 82 ) ]]; then
    compatible_moodle_versions+="MOODLE_402_STABLE "
fi
# List compatible Moodle versions in order
IFS=' ' read -ra moodle_versions <<< "$compatible_moodle_versions"
echo "Moodle releases compatible with this server are:"
for (( i=0; i<${#moodle_versions[@]}; i++ )); do
    echo "$((i+1)). ${moodle_versions[i]}"
done

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
    selected_version="${moodle_versions[$((selection-1))]}"
    echo "Selected Moodle version: $selected_version"
else
    echo "Invalid selection."
fiS
echo "Installing $MoodleVersion based on your selection: $php_version"
echo "Cloning Moodle repository into /opt and copying to /var/www/"
echo "Be patient, this can take several minutes."
cd /var/www
sudo git clone https://github.com/moodle/moodle.git
cd moodle
sudo git checkout -t origin/$MoodleVersion
git config pull.ff only
ORIG_COMMIT=$(git rev-parse HEAD)
LAST_COMMIT=$ORIG_COMMIT
echo "Step 4 has completed."

# Step 5a  Create a user to run backups
# Generate a random password for backupuser
backupuserPW=$(openssl rand -base64 12)
sudo useradd -m -d "/home/backupuser" -s "/bin/bash" "backupuser"
echo "backupuser:$backupuserPW" | sudo chpasswd
sudo usermod -aG mysql "backupuser"
# Create and set permissions for .my.cnf
backupuser_home="/home/backupuser"
mycnf_file="$backupuser_home/.my.cnf"
# Create .my.cnf file with correct permissions
echo "[mysqldump]" | sudo tee "$mycnf_file" > /dev/null
echo "user=backupuser" | sudo tee -a "$mycnf_file" > /dev/null
echo "password=$backupuserPW" | sudo tee -a "$mycnf_file" > /dev/null
sudo chmod 600 "$mycnf_file"
sudo chown backupuser:backupuser "$mycnf_file"
# Securely erase the password from memory


# Step 5  Create a Moodle Virtual Host File and call certbot for https encryption
# Strip the 'http://' or 'https://' part from the web address
FQDN_ADDRESS=$(echo "$WEBSITE_ADDRESS" | sed -e 's#^https\?://##')
# Create a new moodle.conf file
if [[ "$DEBIAN" == "y" ]]; then
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
else
sudo tee /etc/httpd/conf.d/moodle.conf << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@your_moodle_domain
    DocumentRoot /var/www/moodle

    <Directory /var/www/moodle>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    CustomLog /var/log/httpd/access.log combined
    ErrorLog /var/log/httpd/error.log
</VirtualHost>
EOF
sudo systemctl restart httpd
fi
if [ "$FQDN" = "y" ]; then
    if [ ! -d "/etc/letsencrypt" ]; then
        echo "Setting up SSL Certificates for your website"
        sudo ufw allow 'Apache Full'
        sudo ufw delete allow 'Apache'
        sudo certbot --apache
        WEBSITE_ADDRESS="https://${FQDN_ADDRESS#http://}"
    fi
fi
systemctl reload apache2
echo "Step 5 has completed."


# Step 6 Directories, ownership, permissions and php.ini required by 
sudo mkdir -p /var/www/moodledata
sudo chown -R $WEB_SERVER_USER /var/www/moodledata
sudo chmod -R 777 /var/www/moodledata
sudo chmod -R 755 /var/www/moodle
# Determine PHP version
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
if [[ "$DEBIAN" == "y" ]]; then
    PHP_CONFIG_DIR="/etc/php/$PHP_VERSION/apache2"
else
	PHP_CONFIG_DIR="/etc"
fi 
# Update PHP configuration
sudo sed -i 's/.*max_input_vars =.*/max_input_vars = 5000/' "$PHP_CONFIG_DIR/php.ini"
sudo sed -i 's/.*post_max_size =.*/post_max_size = 80M/' "$PHP_CONFIG_DIR/php.ini"
sudo sed -i 's/.*upload_max_filesize =.*/upload_max_filesize = 80M/' "$PHP_CONFIG_DIR/php.ini"
# Restart the web server based on distribution
if [[ "$DEBIAN" == "y" ]]; then
    sudo service apache2 restart
else
    sudo systemctl restart httpd.service
fi
# Install adminer, phpmyadmin alternative
cd /var/www/moodle/local 
sudo wget https://moodle.org/plugins/download.php/28045/local_adminer_moodle42_2021051702.zip
sudo unzip local_adminer_moodle42_2021051702.zip
sudo rm local_adminer_moodle42_2021051702.zip 
echo "Step 6 has completed."

# Step 7 Set up cron job to run every minute 
echo "Cron job added for the WEB_SERVER_USER user."
CRON_JOB="* * * * * /var/www/moodle/admin/cli/cron.php >/dev/null"
echo "$CRON_JOB" > /tmp/moodle_cron
sudo crontab -u $WEB_SERVER_USER /tmp/moodle_cron
sudo rm /tmp/moodle_cron
echo "Step 7 has completed."

# Step 8 Set up a cron job to keep 401 up to date
# Set the URL of the update script in your repository
UPDATE_SCRIPT_URL="https://github.com/steerpike5/LAMP_Moodle/raw/FQDN/security_update.sh"
# Directory where the update script will be placed
# Download the update script and place it in the /opt directory
wget -O "/opt/security_update.sh" "$UPDATE_SCRIPT_URL"
# Add execute permissions to the update script
chmod +x "/opt/security_update.sh"
# Add a cron job to run the update script nightly
CRON_JOB="0 0 * * * /opt/security_update.sh"
# Add the cron job to the user's crontab
(crontab -l ; echo "$CRON_JOB") | crontab 
# Step 8 Finished


#  Step 9 Generate a random password for backupuser
backupuserPW=$(openssl rand -base64 12)
# Create backupuser
sudo useradd -m -d "/home/backupuser" -s "/bin/bash" "backupuser"
# Set password for backupuser
echo "backupuser:$backupuserPW" | sudo chpasswd
# Add backupuser to the mysql group
sudo usermod -aG mysql "backupuser"
# Create and set permissions for .my.cnf
backupuser_home="/home/backupuser"
mycnf_file="$backupuser_home/.my.cnf"
# Create .my.cnf file with correct permissions
echo "[mysqldump]" | sudo tee "$mycnf_file" > /dev/null
echo "user=backupuser" | sudo tee -a "$mycnf_file" > /dev/null
echo "password=$backupuserPW" | sudo tee -a "$mycnf_file" > /dev/null
sudo chmod 600 "$mycnf_file"
sudo chown backupuser:backupuser "$mycnf_file"
# Securely erase the password from memory
sudo unset backupuserPW
echo "Step 9 backupuser finished"
# Step9 Finished



# Step 10 Secure the MySQL service and create the database and user for Moodle
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 6)
MYSQL_MOODLEUSER_PASSWORD=$(openssl rand -base64 6)
MOODLE_ADMIN_PASSWORD=$(openssl rand -base64 6)
# Set the root password using mysqladmin
sudo mysqladmin -u root password "$MYSQL_ROOT_PASSWORD"
# Create the Moodle database and user
echo "Creating the Moodle database and user..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SET GLOBAL innodb_file_format = Barracuda;
CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY '$MYSQL_MOODLEUSER_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, CREATE TEMPORARY TABLES, DROP, INDEX, ALTER ON moodle.* TO 'moodleuser'@'localhost';
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
sudo bash -c "echo 'Original SQL root user password: $MYSQL_ROOT_PASSWORD' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'This SQL root user password will be incorrect if you have changed it in the SQL Security script' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'The following password is used by admin to log on to Moodle' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'Moodle Site Password for admin: $MOODLE_ADMIN_PASSWORD' >> /etc/moodle_installation/info.txt"
cat /etc/moodle_installation/info.txt


echo "Step 10 has completed."

#Step 9 Finish the install 
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
    chmod -R 755 /var/www/moodle
    echo "You can now log on to your new Moodle at $WEBSITE_ADDRESS as admin with $MOODLE_ADMIN_PASSWORD"
else
    echo "Error: Moodle installation encountered an error. Go to $WEBSITE_ADDRESS and follow the prompts to complete the installation."

fi
#Step 9 has finished"

# Secure the databse and display the generated passwords (if needed, for reference)
echo "Now the secure MySQL script is about to run"
echo "Your present SQL root password is $MYSQL_ROOT_PASSWORD"
echo "Enter this password when prompted."
echo "Suggest - enter 'n' for change password, press enter to accept default suggestion for all others"
echo "If you change the SQL root password, WRITE IT DOWN."
read -p "Are you ready to secure the database? (y/n) [Default is 'y']: " answer

# Convert user input to lowercase for comparison
answer=${answer,,}

if [[ "$answer" == "y" ]]; then
    # Run the MySQL secure installation script
    sudo mysql_secure_installation
else
    echo "Database secure installation is not performed."
fi
sudo cat /etc/moodle_installation/info.txt
echo "For better security on web accessible sites, copy the contents of /etc/moodle_installation/info.txt to your password manager and delete the file"












