#!/usr/bin/env bash

set -e

sudo apt update
sudo apt install -y git curl postgresql postgresql-contrib mysql-server gnupg lsb-release \
    gpg python3 python3-pip openjdk-8-jdk maven golang rabbitmq-server

install_mongodb() {
    echo "installing mongodb..."

    # import mongodb gpg key
    curl -fssl https://pgp.mongodb.com/server-8.0.asc |
        sudo gpg --dearmor --yes -o /usr/share/keyrings/mongodb-server-8.0.gpg

    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" |
        sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null

    # update package list
    sudo apt update

    # install mongodb
    sudo apt install -y mongodb-org

    echo "mongodb installed."
}

install_redis() {
    curl -fsSL https://packages.redis.io/gpg |
        sudo gpg --dearmor --yes -o /usr/share/keyrings/redis-archive-keyring.gpg

    sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb noble main" |
        sudo tee /etc/apt/sources.list.d/redis.list >/dev/null

    sudo apt-get update
    sudo apt-get install -y redis
}

install_npm() {
    echo "installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm use --lts
    echo "installed npm"
}

install_java_maven_go_rabbitmq() {
    echo "checking java..."
    java -version

    echo "checking maven..."
    mvn -version

    echo "checking go..."
    go version

    echo "checking rabbitmq..."
    rabbitmqctl status || true

    echo "installed java 8, maven, go, and rabbitmq"
}

start_services() {
    echo "starting services..."

    services=(
        postgresql
        mysql
        rabbitmq-server
        redis-server
        mongod
    )
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            echo "starting $service..."
            sudo systemctl enable "$service"
            sudo systemctl start "$service"
        else
            echo "$service is not installed, skipping..."
        fi
    done

    echo "all available services started."
}

install_npm
install_redis
install_mongodb
install_java_maven_go_rabbitmq
start_services
