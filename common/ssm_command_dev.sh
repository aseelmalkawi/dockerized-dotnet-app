#!/bin/bash
set -e

ECR_URI=$1
COMPOSE_CONTENT=$2
NGINX_CONF=$3

echo "Logging into ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URI

echo "Writing config files..."
rm -rf /tmp/default.conf /tmp/docker-compose.yml
echo $NGINX_CONF | base64 -d > /tmp/default.conf
echo $COMPOSE_CONTENT | base64 -d > /tmp/docker-compose.yml

echo "Deploying..."
cd /tmp
docker-compose down --rmi all
docker-compose up -d

echo "Deploy complete"