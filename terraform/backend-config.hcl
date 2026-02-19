# Backend configuration for S3 state storage
# Copy this to backend-config.hcl and update with your values

bucket         = "aseelmalkawi"
key            = "magic-villa/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
