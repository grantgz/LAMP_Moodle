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
echo "Step 1 has completed."

# Step 2 Set up the firewall
sudo systemctl enable firewalld
sudo systemctl start firewalld
# Set default policies to deny incoming and allow outgoing traffic
sudo firewall-cmd --set-default-zone=drop
# Allow SSH (port 22) for remote access
# Allow HTTP (port 80) and HTTPS (port 443) for web server 
# Allow MySQL (port 3306) for database access
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=mysql
sudo firewall-cmd --reload
echo "Step 2 has completed."

# Step 3 Set up daily security updates
sudo yum install -y yum-cron
sudo sed -i 's/apply_updates = no/apply_updates = yes/' /etc/yum/yum-cron.conf
sudo systemctl enable yum-cron
sudo systemctl start yum-cron
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

# Continue with the rest of the script (Steps 5 to 8)...

