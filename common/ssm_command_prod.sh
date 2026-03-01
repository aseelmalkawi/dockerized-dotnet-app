ECR_URI=$1
BASE_TAG=$2

sudo mv default.conf /etc/nginx/sites-available
sudo ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default || true
sudo systemctl reload nginx

echo "Logging into AWS ECR"
aws ecr get-login-password --region us-east-1 \
| docker login --username AWS --password-stdin $ECR_URI

microk8s kubectl create secret docker-registry ecr-secret \
--docker-server=$ECR_URI \
--docker-username=AWS \
--docker-password=$(aws ecr get-login-password --region us-east-1)

microk8s kubectl get secret ecr-secret

cd k8s
ls 
microk8s kubectl apply -f deployment.yml -f service.yml
microk8s kubectl set image deployment/python-app book-shop=$ECR_URI:$BASE_TAG