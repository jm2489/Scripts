#!/bin/bash

# # Get the current path for this script
CURRENT_DIR=$(dirname "$(readlink -f "$0")")

# Function to install packages from a file
install_packages() {

    package_file="packageList"

    if [ ! -f "$package_file" ]; then
        echo "Error: Package file packageList not found:"
        exit 1
    fi

    echo "Installing packages from $package_file ..."
    while IFS= read -r package || [[ -n "$package" ]]; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            sudo apt-get install -y "$package"
        else
            echo "$package is already installed."
        fi
    done < "$package_file"
    echo "All packages installed."
}


# Clone repository function
clone_repository() {

    githubRepos="githubRepos"
    
    if [ ! -f "$githubRepos" ]; then
        echo "Error: File githubRepos not found."
        exit 1
    fi

    while IFS= read -r repo_url || [[ -n "$repo_url" ]]; do
        git clone "$repo_url" || {
            echo "Failed to clone $repo_url"
            continue
        }
        echo "$repo_name cloned successfully."
    done < "$githubRepos"
}

# Function to set up MySQL
# The first infinity stone. LOL
setup_mysql() {

    echo "Setting up MySQL ..."

    # if [ -d /var/lib/mysql ]; then
    #     echo "MySQL already installed."
    #     echo "Stopping MySQL..."
    #     sudo systemctl stop mysql
    #     read -p "Would you like to overwrite existing MySQL data? [y/n] " answer
    #     if [[ "$answer" =~ ^[Yy]$ ]]; then
    #         echo "Removing existing MySQL data..."
    #         sudo rm -rf /var/lib/mysql/*
    #         sudo mysqld --initialize --user=mysql --datadir=/var/lib/mysql

    #     fi
    # fi

    # Modify the MySQL bind-address to allow connections from any IP in the /etc/mysql/mysqld.cnf
    echo "Configuring MySQL bind-address..."
    sudo sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

    # Restart MySQL service to apply changes
    echo "Restarting MySQL service..."
    sudo systemctl restart mysql

    if [ -f mysql_setup.sql ]; then
        echo "Running MySQL configuration from mysql_setup.sql..."
        sudo mysql < mysql_setup.sql
    else
        echo "Error: mysql_setup.sql not found."
        exit 1
    fi

    # Run mysql_secure_installation non-interactively with pre loaded answers below.
    # Looks really ugly tbh I might do this just the one time.
    echo "Running mysql_secure_installation..."
    sudo mysql_secure_installation <<EOF
y
2
y
y
y
y
EOF

    echo "MySQL configuration completed successfully."
    echo "Showing databse and tables:"
    mysql --defaults-file=client.cnf -e 'show databases;'
    mysql --defaults-file=client.cnf -e 'show tables;' logindb
    mysql --defaults-file=client.cnf -e 'desc users' logindb
    echo "Login info: User: rabbit Password: rabbitIT490!"
    echo "MySQL setup complete"
}

# Setup rabbitmq server
# Second infinity stone. Idk which infinity stone to match up to what function. Use your imagination
setup_rabbitmq() {

    echo "Setting up RabbitMQ ..."
    sudo $CURRENT_DIR/rabbitmq.sh
    status=$?
    # status=0 # testing purposes
    if [ "$status" -eq 0 ]; then
        user=$(awk -F: '$3 == 1000 {print $1}' /etc/passwd)
        if [ ! -d NJIT ]; then
            sudo -u $user $0 -git-clone
        else
            echo "Directory NJIT already exists!"
            echo "Skipping git clone..."
        fi
        if [ -d /home/$user/RabbitMQ ]; then
            read -p "Script will overwrite directory /home/$user/RabbitMQ.. Do you want to continue? [y/n] " answer
            if [[ "$answer" =~ ^[Yy]$ ]]; then
                sudo rm -rf /home/$user/RabbitMQ
                sudo -u $user cp -r $CURRENT_DIR/NJIT/IT490/RabbitMQ /home/$user/
                echo "Copied RabbitMQ directory to /home/$user/RabbitMQ"
            else
                echo "Exiting."
                exit 1
            fi
        else
            sudo -u $user cp -r $CURRENT_DIR/NJIT/IT490/RabbitMQ /home/$user/
            echo "Copied RabbitMQ directory to /home/$user/RabbitMQ"
        fi
    else
        echo "Failed to setup RabbitMQ server (exit code: $status)"
    fi
    # After RabbitMQ was successfully configured. Set it up in systemd as a service
    # Very straightforward. Would probably need to do some checks if service of the same name exists and etc. This is fine for now.
    echo "Editing service file..."
    configFile=/home/$user/RabbitMQ/testRabbitMQServer.service
    serviceFile=/etc/systemd/system/testRabbitMQServer.service
    if [ -f $serviceFile ]; then
        echo "Service file already exists. Removing..."
        sudo rm -f $serviceFile
    fi
    sudo sed -i "s|^ExecStart=.*|ExecStart=/usr/bin/php /home/$user/RabbitMQ/testRabbitMQServer.php|" $configFile
    sudo sed -i "s|^User=.*|User=$user|" $configFile
    sudo sed -i "s|^Group=.*|Group=$user|" $configFile
    
    echo "Creating service file in systemd..."
    sudo cp /home/$user/RabbitMQ/testRabbitMQServer.service /etc/systemd/system/
    
    echo "Reloading daemon-service..."
    sudo systemctl daemon-reload
    
    echo "Enabling service..."
    sudo systemctl enable testRabbitMQServer.service
    
    echo "Starting service..."
    sudo systemctl start testRabbitMQServer.service
    
    echo "Checking status..."
    sudo systemctl status testRabbitMQServer.service --no-pager
    
    echo "RabbitMQ daemon service complete"
    echo "Done."
}

# Setup apache2
# Third infinity stone... The kidney stone.
setup_apache2() {
    echo "Setting up apache2"
    sudo ./apache2.sh
    status=$?
    # status=0 # testing purposes
    if [ "$status" -eq 0 ]; then
        user=$(awk -F: '$3 == 1000 {print $1}' /etc/passwd)
        if [ ! -d NJIT ]; then
            sudo -u $user $0 -git-clone
        else
            echo "Directory NJIT already exists!"
            echo "Skipping git clone..."
        fi
        if [ -d /var/www/html ]; then
            read -p "Script will overwrite directory /var/www/html.. Do you want to continue? [y/n] " answer
            if [[ "$answer" =~ ^[Yy]$ ]]; then
                sudo rm -rf /var/www/html
                sudo mkdir /var/www/html
                sudo cp NJIT/IT490/Web/index.html /var/www/html
                sudo cp -r NJIT/IT490/Web/php /var/www/html
                sudo cp -r NJIT/IT490/Web/media /var/www/html
                echo "Copied Web directory to /var/www/html"
                echo "Restarting apache2 services"
                sudo systemctl restart apache2
            else
                echo "Exiting."
                exit 1
            fi
        else
            echo "Directory /var/www/html does not exist."
            echo "Exiting."
            exit 1
        fi
        # # Ask user if they would like to load localhost/index.html now.
        # # Kinda buggy so I left it out for now.
        # read -p "Would you like to load localhost/index.html now? [y/n] " answer
        # if [[ "$answer" =~ ^[Yy]$ ]]; then
        #     sudo -u "$user" xdg-open http://localhost/index.html > /dev/null 2>&1 &
        #     exit 0
        # else
        #     echo "Open http://localhost/index.html in browser to view web page"
        #     exit 0
        # fi
        echo "Open http://localhost/index.html in browser to view web page"
        exit 0
    else
        echo "Failed to setup Apache2 server (exit code: $status)"
    fi
}

# Function to display the details of this wonderfully curated script!
show_details() {
    echo "Script Name: it490.sh"
    echo "Description: This is my infinity gauntlet script to setup the IT490 project from a fresh Ubuntu installation."
    echo "             Because I'm tired of having to be like Thanos and say, 'Fine, I'll do this myself.'"
    echo "Author: Judrianne Mahigne (jm2489@njit.edu)"
    echo "Version: 1.00"
    echo "Last Updated: Oct 17, 2024"
}

# Setup Wireguard VPN
# Will do later.. Really tired right now....
setup_wireguard() {
    echo "Setting up Wireguard VPN..."
    read -p "Which user are you? mike | warlin | raj | jude : " person
    # Check to see which user is who and assign a number and copy their private keys
    case "$person" in
        mike)
            privatekey=$(cat NJIT/IT490/Wireguard/privkeys/Mike)
            vpn=2
            ;;
        warlin)
            privatekey=$(cat NJIT/IT490/Wireguard/privkeys/Warlin)
            vpn=3
            ;;
        raj)
            privatekey=$(cat NJIT/IT490/Wireguard/privkeys/Raj)
            vpn=4
            ;;
        jude)
            privatekey=$(cat NJIT/IT490/Wireguard/privkeys/Jude)
            vpn=6
            ;;
        *)
            echo "Invalid user. Exiting."
            exit 1
            ;;
    esac

    # Need to make if statements to check if wireguard vpn server is up or there is an existing wg0.conf
    sed -i "s|^PrivateKey.*|PrivateKey = $privatekey|" NJIT/IT490/Wireguard/wg0.conf
    sed -i "s|^Address.*|Address = 10.0.0.$vpn|" NJIT/IT490/Wireguard/wg0.conf
    sudo cp NJIT/IT490/Wireguard/wg0.conf /etc/wireguard/wg0.conf
    sudo chmod 600 /etc/wireguard/wg0.conf
    sudo wg-quick up wg0
    echo "Connecting to wireguard VPN..."
    sleep 3
    sudo wg show
    echo "Wireguard VPN setup complete."
    echo "Use sudo wg-quick down wg0 to disable wireguard"
}

# Setup ufw rules for required apps
setup_ufw() {
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 3306/tcp
    # sudo ufw allow 15672/tcp Rabbitmq web interface
    sudo ufw allow 5672/tcp
    sudo ufw enable
    sudo ufw status
    echo "ufw rules setup complete."
}

# This function is mainly for connection information to each server for troubleshooting
get_info() {
    if [ -z "$2" ]; then
        echo "Second argument is empty."
        exit 0
    else
        case "$2" in
            mysql)
                if [ -z "$3" ]; then
                    echo "+++++ MySQL server connection info +++++"
                    filePath=$(realpath ~/RabbitMQ/dbClient.php)
                    echo "File path: $filePath"
                    cat $filePath | awk 'NR>=3 && NR<=6'
                else
                    if [[ "$3" == "users" ]]; then
                        case "$4" in
                            readable)
                                echo "+++++ MySQL server users table info +++++"
                                mysql --defaults-file=client.cnf -e 'select id, username, password, STR_TO_DATE(last_login, "%Y%m%d%H%i%s") as last_login_readable from users;' logindb
                                exit 0
                                ;;
                            raw)
                                echo "+++++ MySQL server users table info +++++"
                                mysql --defaults-file=client.cnf -e 'select * from users;' logindb
                                exit 0
                                ;;
                            *)
                                echo "Using default query"
                                echo "+++++ MySQL server users table info +++++"
                                mysql --defaults-file=client.cnf -e 'select id, username, password, UNIX_TIMESTAMP(STR_TO_DATE(last_login, "%Y%m%d%H%i%s")) as EPOCH from users;' logindb
                                ;;
                        esac
                    elif [[ "$3" == "sessions" ]]; then
                        case "$4" in
                            readable)
                                echo "+++++ MySQL server sessions table info +++++"
                                mysql --defaults-file=client.cnf -e 'select id, username, session_token, UNIX_TIMESTAMP(STR_TO_DATE(expire_date, "%Y%m%d%H%i%s")) as expire_date_readable from sessions;' logindb
                                exit 0
                                ;;
                            *)
                                echo "Using default query"
                                echo "+++++ MySQL server sessions table info +++++"
                                mysql --defaults-file=client.cnf -e 'select id, username, session_token, expire_date as EPOCH from sessions;' logindb
                                ;;
                        esac
                    else
                        echo "Unknown table '$3' or does not exist! Please ensure correct table name."
                        exit 1
                    fi
                fi
                ;;
            rabbitmq)
                echo "+++++ RabbitMQ server info on this machine +++++"
                rabbitmq_dir=~/RabbitMQ
                filePath1="$rabbitmq_dir/dbClient.php"
                filePath2="$rabbitmq_dir/testRabbitMQ.ini"
                
                echo "File path: $(realpath "$filePath1")"
                awk 'NR>=2 && NR<=10' "$filePath1"
                
                echo
                echo "+++++ RabbitMQ server service file +++++"
                echo "File path: $(realpath "$filePath2")"
                cat "$filePath2"
                ;;
            apache)
                echo "+++++ Apache server connection info +++++"
                filePath=$(realpath /var/www/html/php/testRabbitMQ.ini)
                echo "File path: $filePath"
                sudo cat $filePath
                ;;
            wireguard)
                echo "Getting Wireguard VPN info:"
                vpnInfo=$(sudo wg show)
                if [ -z "$vpnInfo" ]; then
                    echo "Wireguard VPN Disconnected..."
                    echo "Run sudo wg-quick up wg0 to enable"
                else
                    echo "$vpnInfo"
                fi
                ;;
            ufw)
                echo "Getting ufw rules:"
                firewallStatus=$(sudo ufw status)
                echo "$firewallStatus"
                ;;
            *)
                echo "Unknown argument: $2"
                ;;
        esac
    fi
}

# Main
case "$1" in
    -details)
        show_details
        ;;
    -git-clone)
        if [ "$EUID" -eq 0 ]; then
            echo "Detected running with sudo privileges."
            echo "Please run this -git-clone as a regular user to avoid issues."
            exit 1
        fi
        clone_repository
        ;;
    -install-packages)
        if [ "$EUID" -ne 0 ]; then
            echo "Need sudo privileges to run -install."
            exit 1
        fi
        sudo -v
        while true; do 
            sudo -n true
            sleep 60
            kill -0 "$$" || exit
        done 2>/dev/null &
        install_packages
        ;;
    -mysql)
        if [ "$EUID" -ne 0 ]; then
            echo "Need sudo privileges to run -mysql."
            exit 1
        fi
        sudo -v
        while true; do 
            sudo -n true
            sleep 60
            kill -0 "$$" || exit
        done 2>/dev/null &
        setup_mysql
        ;;
    -rabbitmq)
        if [ "$EUID" -ne 0 ]; then
            echo "Need sudo privileges to run -rabbitmq."
            exit 1
        fi
        sudo -v
        while true; do 
            sudo -n true
            sleep 60
            kill -0 "$$" || exit
        done 2>/dev/null &
        chmod 755 rabbitmq.sh
        setup_rabbitmq
        ;;
    -apache2)
        if [ "$EUID" -ne 0 ]; then
            echo "Need sudo privileges to run -apache2."
            exit 1
        fi
        sudo -v
        while true; do 
            sudo -n true
            sleep 60
            kill -0 "$$" || exit
        done 2>/dev/null &
        chmod 755 apache2.sh
        setup_apache2
        ;;
    -wireguard)
        if [ "$EUID" -ne 0 ]; then
            echo "Need sudo privileges to run -wireguard."
            exit 1
        fi
        sudo -v
        while true; do 
            sudo -n true
            sleep 60
            kill -0 "$$" || exit
        done 2>/dev/null &
        setup_wireguard
        ;;
    -ufw)
        if [ "$EUID" -ne 0 ]; then
            echo "Need sudo privileges to run -ufw."
            exit 1
        fi
        sudo -v
        while true; do 
            sudo -n true
            sleep 60
            kill -0 "$$" || exit
        done 2>/dev/null &
        setup_ufw
        ;;
    -get)
        get_info $@
        ;;
    -endgame)
        if [ "$EUID" -ne 0 ]; then
            echo "Need sudo privileges to run -endgame"
            exit 1
        fi
        sudo -v
        while true; do 
            sudo -n true
            sleep 60
            kill -0 "$$" || exit
        done 2>/dev/null &
        ./intro.sh
        sudo $0 -install-packages
        sleep 3
        sudo $0 -mysql
        sleep 3
        sudo $0 -rabbitmq
        sleep 3
        sudo $0 -apache2
        sleep 3
        sudo $0 -wireguard
        sleep 3
        sudo $0 -ufw
        ./outro.sh
        ;;
    *)
        cat $CURRENT_DIR/README.md
        ;;
esac
