#!/usr/bin/env bash

set -e

# Ubuntu version detection

source /etc/os-release

if [[ "$ID" != "ubuntu" ]]; then
    echo "ERROR: This script requires Ubuntu."
    exit 1
fi

UBUNTU_VERSION="$VERSION_ID"
UBUNTU_CODENAME="$VERSION_CODENAME"

echo "Detected Ubuntu $UBUNTU_VERSION ($UBUNTU_CODENAME)"

echo "Installing base packages..."

sudo apt update

sudo apt install -y \
    git \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    postgresql \
    postgresql-contrib \
    mysql-server \
    openjdk-8-jdk \
    maven \
    golang \
    rabbitmq-server

install_mongodb() {
    echo "Installing MongoDB..."

    MONGODB_CODENAME="noble"

    curl -fsSL https://pgp.mongodb.com/server-8.0.asc |
        sudo gpg --dearmor --yes \
            -o /usr/share/keyrings/mongodb-server-8.0.gpg

    sudo chmod 644 /usr/share/keyrings/mongodb-server-8.0.gpg

    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu ${MONGODB_CODENAME}/mongodb-org/8.0 multiverse" |
        sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null

    sudo apt update
    sudo apt install -y mongodb-org

    echo "MongoDB installed."
}

install_redis() {
    echo "Installing Redis..."

    sudo apt update
    sudo apt install -y redis-server

    echo "Redis installed."
}

install_npm() {
    echo "Installing Node.js using NVM..."

    export NVM_DIR="$HOME/.nvm"

    if [[ ! -d "$NVM_DIR" ]]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh |
            bash
    fi

    # Load NVM into the current shell.
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
    else
        echo "ERROR: NVM installation failed."
        exit 1
    fi

    nvm install --lts
    nvm use --lts

    echo "Node.js version:"
    node --version

    echo "npm version:"
    npm --version
}

check_java_maven_go_rabbitmq() {
    echo "Checking Java..."
    java -version

    echo
    echo "Checking Maven..."
    mvn --version

    echo
    echo "Checking Go..."
    go version

    echo
    echo "Checking RabbitMQ..."
    rabbitmqctl status || true

    echo
    echo "Java, Maven, Go, and RabbitMQ installed."
}

start_services() {
    echo "Starting services..."

    services=(
        postgresql
        mysql
        rabbitmq-server
        redis-server
        mongod
    )

    for service in "${services[@]}"; do
        if systemctl list-unit-files --type=service |
            grep -q "^${service}.service"; then

            echo "Starting $service..."

            sudo systemctl enable "$service"
            sudo systemctl start "$service"

        else
            echo "$service is not installed, skipping..."
        fi
    done

    echo
    echo "Available services started."
}

install_npm
install_redis
install_mongodb
check_java_maven_go_rabbitmq
start_services

echo
echo "================================"
echo "Setup completed successfully!"
echo "================================"
