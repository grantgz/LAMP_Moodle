#!/bin/bash
# Prompt for the web address
read -p "Enter the web address (leave blank for localhost ): " WEBSITE_ADDRESS

# Check if the input is not empty
if [ -n "$WEBSITE_ADDRESS" ]; then
    # Validate the input as a valid FQDN or IPv4 address
    if ! [[ $WEBSITE_ADDRESS =~ ^((http|https):\/\/)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(\/\S*)?$ || $WEBSITE_ADDRESS =~ ^((http|https):\/\/)?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/\S*)?$ ]]; then
        echo "Invalid web address. Please enter a valid FQDN or IPv4 address (e.g., http://example.com or http://192.168.1.100)."
        exit 1
    fi
else
    # Set the web address to localhost if input is blank
    WEBSITE_ADDRESS="http://127.0.0.1"
fi

# Step 1 LAMP server installation
# Update the system and install required packages
sudo yum update -y
sudo yum install -y epel-release
sudo yum install -y httpd php php-mysqlnd php-gd php-intl php-xml php-ldap php-zip php-soap php-mbstring clamav git unzip
sudo systemctl start httpd
sudo systemctl enable httpd
sudo yum install -y mariadb-server
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo dnf install firewalld


echo "Step 1 has completed."

## Step 2 Set up the firewall
#sudo systemctl enable firewalld
#sudo systemctl start firewalld
## Set default policies to deny incoming and allow outgoing traffic
#sudo firewall-cmd --set-default-zone=drop
## Allow SSH (port 22) for remote access
## Allow HTTP (port 80) and HTTPS (port 443) for web server 
## Allow MySQL (port 3306) for database access
#sudo firewall-cmd --permanent --add-service=ssh
#sudo firewall-cmd --permanent --add-service=http
#sudo firewall-cmd --permanent --add-service=https
#sudo firewall-cmd --permanent --add-service=mysql
#sudo firewall-cmd --reload
#echo "Step 2 has completed."

# Step 3 Set up daily security updates
sudo dnf install -y dnf-automatic
sudo sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
sudo systemctl enable --now dnf-automatic.timer
echo "Step 3 has completed."


# Step 4 Clone the Moodle repository into /var/www
# Use MOODLE_401_STABLE branch as CentOS 8 ships with PHP 7.4
echo "Cloning Moodle repository into /opt and copying to /var/www/"
echo "Be patient, this can take several minutes."
cd /var/www
sudo git clone https://github.com/moodle/moodle.git
cd moodle
sudo git checkout -t origin/MOODLE_401_STABLE
echo "Step 4 has completed."


# Step 5 Directories, ownership, permissions, and php.ini required by Moodle
sudo mkdir -p /var/www/moodledata
sudo chown -R apache:apache /var/www/moodledata
sudo chmod -R 777 /var/www/moodledata
sudo chmod -R 755 /var/www/moodle
# Create the Moodle Apache configuration
echo "Creating Moodle Apache configuration..."
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
echo "Step 5 has completed."

# Update the php.ini files, required to pass the Moodle install check
sudo sed -i 's/.*max_input_vars =.*/max_input_vars = 5000/' /etc/php.ini
sudo sed -i 's/.*post_max_size =.*/post_max_size = 80M/' /etc/php.ini
sudo sed -i 's/.*upload_max_filesize =.*/upload_max_filesize = 80M/' /etc/php.ini
# Restart Apache to allow changes to take place
sudo systemctl restart httpd
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
sudo crontab -u apache /tmp/moodle_cron
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
sudo bash -c "echo 'Installation script' > /etc/moodle_installation/info.txt"
sudo bash -c "echo 'Date and Time of Installation: $(date)' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'Moodle SQL user password: $MYSQL_MOODLEUSER_PASSWORD' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'Moodle root user password: $MYSQL_ROOT_PASSWORD' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'The following password is used by admin to log on to Moodle' >> /etc/moodle_installation/info.txt"
sudo bash -c "echo 'Moodle Site Password for admin: $MOODLE_ADMIN_PASSWORD' >> /etc/moodle_installation/info.txt"
cat /etc/moodle_installation/info.txt


echo "Step 7 has completed."

#Step 8 Finish the install 
echo "The script will now try to finish the installation. If this fails, log on to your site at $WEBSITE_ADDRESS and follow the prompts."
INSTALL_COMMAND="sudo -u apache /usr/bin/php /var/www/moodle/admin/cli/install.php \
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



