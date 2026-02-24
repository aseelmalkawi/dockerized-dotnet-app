cd terraform
terraform init -backend-config=backend-config.hcl
# echo "PROJECT_NAME=$(terraform output -raw project_name)" >> $GITHUB_ENV
echo "ECR_URI=$(terraform output -raw ecr_repository_url)" >> $GITHUB_ENV
echo "INSTANCE_ID=$(terraform output -raw ec2_instance_id)" >> $GITHUB_ENV