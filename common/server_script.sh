#!/bin/bash
set -e

echo "Logging into AWS ECR"
aws ecr get-login-password --region "$AWS_REGION" \
| docker login --username AWS --password-stdin "$ECR_URI"

echo "Pulling the Docker image"
docker pull "$ECR_URI/cicd-aseel:$VERSION"

if docker ps -a --format '{{.Names}}' | grep -wq nodeapp; then
  docker stop nodeapp
  docker rm nodeapp
fi

echo "Running new container"
docker run -dp 3000:3000 --name nodeapp "$ECR_URI/cicd-aseel:$VERSION"
