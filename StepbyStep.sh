#!/bin/bash
#Prepare by hardcoding IP address
WEBSITE_ADDRESS=http://127.0.0.1

# Step 1 LAMP server installaton
#Update the system and install git, Apache, PHP and modules required by Moodle
sudo apt-get update
sudo apt upgrade -y
sudo apt-get install -y apache2 php7.4 libapache2-mod-php7.4 php7.4-mysql graphviz aspell git 
sudo apt-get install -y clamav php7.4-pspell php7.4-curl php7.4-gd php7.4-intl php7.4-mysql ghostscript
sudo apt-get install -y php7.4-xml php7.4-xmlrpc php7.4-ldap php7.4-zip php7.4-soap php7.4-mbstring
sudo apt-get install -y  ufw unzip
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades
#Install Debian default database MariaDB 
sudo apt-get install -y mariadb-server mariadb-client
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


#Step 3 Set up daily security updates
# Configure unattended-upgrades
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

# Step 4 Clone the Moodle repository into /var/www
# Use MOODLE_401_STABLE branch as Debian 11 ships with php7.4
echo "Cloning Moodle repository into /opt and copying to /var/www/"
echo "Be patient, this can take several minutes."
cd /var/www
sudo git clone https://github.com/moodle/moodle.git
cd moodle
sudo git checkout -t origin/MOODLE_401_STABLE
echo "Step 4 has completed."


# Step 5 Directories, ownership, permissions and php.ini required by 
sudo mkdir -p /var/www/moodledata
sudo chown -R www-data /var/www/moodledata
sudo chmod -R 777 /var/www/moodledata
sudo chmod -R 755 /var/www/moodle
# Change the Apache DocumentRoot using sed so Moodle opens at http://webaddress
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/moodle.conf
sudo sed -i 's|/var/www/html|/var/www/moodle|g' /etc/apache2/sites-available/moodle.conf
sudo a2dissite 000-default.conf
sudo a2ensite moodle.conf
systemctl reload apache2
# Update the php.ini files, required to pass Moodle install check
sudo sed -i 's/.*max_input_vars =.*/max_input_vars = 5000/' /etc/php/7.4/apache2/php.ini
sudo sed -i 's/.*post_max_size =.*/post_max_size = 80M/' /etc/php/7.4/apache2/php.ini
sudo sed -i 's/.*upload_max_filesize =.*/upload_max_filesize = 80M/' /etc/php/7.4/apache2/php.ini
# Restart Apache to allow changes to take place
sudo service apache2 restart
# Install adminer, phpmyadmin alternative
cd /var/www/moodle/local 
sudo wget https://moodle.org/plugins/download.php/28045/local_adminer_moodle42_2021051702.zip
sudo unzip local_adminer_moodle42_2021051702.zip
sudo rm local_adminer_moodle42_2021051702.zip 
echo "Step 5 has completed."

# Step 6 Set up cron job to run every minute 
echo "Cron job added for the www-data user."
CRON_JOB="* * * * * /var/www/moodle/admin/cli/cron.php >/dev/null"
echo "$CRON_JOB" > /tmp/moodle_cron
sudo crontab -u www-data /tmp/moodle_cron
sudo rm /tmp/moodle_cron
echo "Step 6 has completed."

# Step 7 Secure the MySQL service and create the database and user for Moodle
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 6)
MYSQL_MOODLEUSER_PASSWORD=$(openssl rand -base64 6)
MOODLE_ADMIN_PASSWORD=$(openssl rand -base64 6)
# Set the root password using mysqladmin
sudo mysqladmin -u root password "$MYSQL_ROOT_PASSWORD"
# Create the Moodle database and user
echo "Creating the Moodle database and user..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY '$MYSQL_MOODLEUSER_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, CREATE TEMPORARY TABLES, DROP, INDEX, ALTER ON moodle.* TO 'moodleuser'@'localhost';
\q
EOF
sudo chmod -R 777 /var/www/moodle
sudo mkdir /etc/moodle_installation
sudo chmod 700 /etc/moodle_installation
# Create info.txt and add installation details with date and time
sudo bash -c 'echo "Installation script" > /etc/moodle_installation/info.txt'
sudo bash -c 'echo "Date and Time of Installation: $(date)" >> /etc/moodle_installation/info.txt'
sudo bash -c 'echo "Moodle SQL user  password : $MYSQL_MOODLEUSER_PASSWORD" >> /etc/moodle_installation/info.txt'
sudo bash -c 'echo "Moodle root user password: $MYSQL_ROOT_PASSWORD" >> /etc/moodle_installation/info.txt'
sudo bash -c 'echo "The following password is used by admin to log on  to Moodle" >> /etc/moodle_installation/info.txt'
sudo bash -c 'echo "Moodle Site Password for admin : $MOODLE_ADMIN_PASSWORD" >> /etc/moodle_installation/info.txt'

echo "Step 7 has completed."

#Step 8 Finish the install 
echo "The script will now try to finish the installation. If this fails, log on to your site at $WEBSITE_ADDRESS and follow the prompts."
INSTALL_COMMAND="sudo -u www-data /usr/bin/php /var/www/moodle/admin/cli/install.php \
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
# Display the generated passwords (if needed, for reference)
sudo cat /etc/moodle_installation/info.txt
#Step 8 has finished"












