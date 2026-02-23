# - name: Init Terraform
#   run: terraform init -backend-config=backend-config.hcl

# - name: Export outputs
# run: |
#     echo "PROJECT_NAME=$(terraform output -raw project_name)" >> $GITHUB_ENV
#     echo "ECR_URI=$(terraform output -raw ecr_repository_name)" >> $GITHUB_ENV
cd terraform
terraform init -backend-config=backend-config.hcl
# echo "PROJECT_NAME=$(terraform output -raw project_name)" >> $GITHUB_ENV
echo "ECR_URI=$(terraform output -raw ecr_repository_url)" >> $GITHUB_ENV