# Backend configuration for S3 state storage
bucket         = "aseelmalkawi"
key            = "magic-villa/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
