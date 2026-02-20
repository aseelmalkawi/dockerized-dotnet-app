# Terraform AWS Infrastructure - Complete Guide

This guide provides an in-depth explanation of every Terraform file in this project, what they do, and how they work together.

---

## 📁 File Structure Overview

```
.
├── main.tf                    # Provider configuration and data sources
├── backend.tf                 # Remote state storage configuration
├── backend-config.hcl         # S3 backend values (gitignored)
├── vpc.tf                     # Virtual Private Cloud and networking
├── security.tf                # Security groups and firewall rules
├── iam.tf                     # IAM roles and permissions
├── ec2.tf                     # EC2 instance configuration
├── ecr.tf                     # Elastic Container Registry
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output values after deployment
├── terraform.tfvars           # Your actual values (gitignored)
├── setup-backend.sh           # Script to create S3 backend
└── .gitignore                 # Files to exclude from git
```

---

## 📄 Detailed File Explanations

### 1. `main.tf` - Foundation & Provider Setup

**Purpose:** Defines which cloud provider to use (AWS) and fetches the latest Ubuntu AMI.

**What's inside:**
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```
- **terraform block:** Specifies minimum Terraform version and AWS provider version
- **~> 5.0:** Allows AWS provider versions 5.x (but not 6.0)

```hcl
provider "aws" {
  region = var.aws_region
}
```
- Configures AWS provider to use the region specified in `variables.tf`

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical (Ubuntu official)
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}
```
- **Data source:** Queries AWS to find the latest Ubuntu 24.04 LTS AMI
- **Why?** AMI IDs change by region and are updated regularly. This ensures you always get the latest
- **owners:** Canonical's AWS account ID (ensures official Ubuntu images)

**Key Concepts:**
- **Provider:** The plugin that talks to AWS API
- **Data Source:** Read-only information from AWS (not creating anything)
- **AMI (Amazon Machine Image):** The template for your EC2 instance's operating system

---

### 2. `backend.tf` - Remote State Storage

**Purpose:** Tells Terraform to store its state file in S3 instead of locally.

**What's inside:**
```hcl
terraform {
  backend "s3" {
    # Configuration loaded from backend-config.hcl
  }
}
```

**Why this matters:**
- **Without backend:** State stored locally in `terraform.tfstate` file
- **With S3 backend:** State stored in S3 bucket, enabling:
  - Team collaboration (everyone uses same state)
  - State locking via DynamoDB (prevents concurrent modifications)
  - Version history (can rollback mistakes)
  - Secure storage (encrypted at rest)

**How it works:**
1. When you run `terraform init -backend-config=backend-config.hcl`
2. Terraform reads the S3 bucket details from `backend-config.hcl`
3. All state operations (read/write) go to S3 instead of a local file

**The State File:**
- Contains a JSON representation of your infrastructure
- Maps Terraform config to real AWS resource IDs
- Tracks dependencies between resources
- **Never edit manually!**

---

### 3. `backend-config.hcl` - Backend Configuration Values

**Purpose:** Contains the actual S3 bucket name and settings (this file is gitignored for security).

**What's inside:**
```hcl
bucket         = "your-terraform-state-bucket"
key            = "magic-villa/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
```

**Field explanations:**
- **bucket:** Name of your S3 bucket where state is stored
- **key:** Path within the bucket (like a filename) - use project names to organize
- **region:** AWS region where the S3 bucket exists
- **encrypt:** Enables server-side encryption for the state file
- **dynamodb_table:** Table name for state locking (prevents concurrent updates)

**Why separate from backend.tf?**
- Allows different environments (dev/staging/prod) to use different buckets
- Keeps sensitive bucket names out of version control
- More flexible for CI/CD pipelines

---

### 4. `vpc.tf` - Virtual Private Cloud & Networking

**Purpose:** Creates an isolated network in AWS where your EC2 instance will live.

#### Resource Breakdown:

**VPC (Virtual Private Cloud):**
```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr  # Example: "10.0.0.0/16"
  enable_dns_hostnames = true          # Instances get DNS names
  enable_dns_support   = true          # DNS resolution works
}
```
- **CIDR block:** Defines the IP address range for your network
- `10.0.0.0/16` means: 65,536 possible IP addresses (10.0.0.0 - 10.0.255.255)
- Think of VPC as your own private data center in AWS

**Internet Gateway:**
```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
```
- **Purpose:** Allows resources in your VPC to access the internet
- Without this, your EC2 couldn't download packages or be accessed from outside
- Like the "front door" of your network

**Public Subnet:**
```hcl
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr  # Example: "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true                    # Auto-assign public IPs
}
```
- **Subnet:** A subdivision of your VPC
- `10.0.1.0/24` = 256 IP addresses (10.0.1.0 - 10.0.1.255)
- **Public subnet:** Resources here can be accessed from the internet
- **map_public_ip_on_launch:** EC2 instances automatically get public IPs

**Route Table:**
```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"              # All internet traffic
    gateway_id = aws_internet_gateway.main.id
  }
}
```
- **Purpose:** Defines how network traffic is routed
- `0.0.0.0/0` → Internet Gateway means: "Send all internet-bound traffic through the IGW"
- Like a routing rule: "For any IP not in this VPC, go out the internet gateway"

**Route Table Association:**
```hcl
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```
- **Purpose:** Links the subnet to the route table
- Without this, the subnet wouldn't know how to route traffic

**Networking Analogy:**
- **VPC:** Your private neighborhood
- **Subnet:** A specific street in that neighborhood
- **Internet Gateway:** The main road entrance
- **Route Table:** Street signs showing which way to go

---

### 5. `security.tf` - Security Groups (Firewall Rules)

**Purpose:** Defines what network traffic is allowed to/from your EC2 instance.

**What's inside:**
```hcl
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id
```
- Security group = virtual firewall around your EC2 instance
- Attached to the VPC (can't use it in another VPC)

**Ingress Rules (Inbound Traffic):**

**SSH (Port 22):**
```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.allowed_ssh_cidr  # Your IP address
  description = "SSH access"
}
```
- Allows SSH connections from specified IP addresses
- **Security best practice:** Set `allowed_ssh_cidr` to your specific IP, not `0.0.0.0/0`

**HTTP (Port 80):**
```hcl
ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # Anyone on the internet
  description = "HTTP access"
}
```
- Allows web traffic from anywhere
- Needed if hosting a website

**HTTPS (Port 443):**
```hcl
ingress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "HTTPS access"
}
```
- Allows secure web traffic

**Egress Rule (Outbound Traffic):**
```hcl
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"              # All protocols
  cidr_blocks = ["0.0.0.0/0"]     # Anywhere
  description = "Allow all outbound"
}
```
- Allows EC2 to initiate connections to anywhere (download packages, API calls, etc.)
- **-1 protocol:** Means all protocols (TCP, UDP, ICMP, etc.)

**Firewall Analogy:**
- **Security Group:** A bouncer at a club
- **Ingress rules:** Who's allowed IN
- **Egress rules:** Who's allowed OUT
- **0.0.0.0/0:** Everyone/anywhere
- **Protocol/Port:** Type of conversation allowed (SSH, HTTP, etc.)

---

### 6. `iam.tf` - IAM Roles & Permissions

**Purpose:** Gives your EC2 instance permissions to interact with other AWS services (like ECR).

#### IAM Concepts:

**IAM Role:**
```hcl
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
```
- **IAM Role:** A set of permissions that can be assumed by AWS services
- **assume_role_policy:** Defines WHO can use this role (in this case, EC2 service)
- Think of it like a security badge that grants access to certain areas

**ECR Access Policy:**
```hcl
resource "aws_iam_role_policy" "ecr_access" {
  name = "${var.project_name}-ecr-access"
  role = aws_iam_role.ec2.id
  
  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",      # Login to ECR
        "ecr:BatchCheckLayerAvailability", # Check if image layers exist
        "ecr:GetDownloadUrlForLayer",      # Get URLs to download layers
        "ecr:BatchGetImage"                # Pull images
      ]
      Resource = "*"
    }]
  })
}
```
- **Purpose:** Allows EC2 to pull Docker images from ECR
- **GetAuthorizationToken:** Required to authenticate with ECR
- **BatchGetImage:** Downloads the actual Docker image

**Managed Policy Attachments:**
```hcl
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
```
- **Managed Policy:** Pre-made AWS policy for common use cases
- **CloudWatchAgentServerPolicy:** Allows sending logs/metrics to CloudWatch

```hcl
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```
- **SSM (Systems Manager):** Allows connecting to EC2 via AWS Console (Session Manager)
- No SSH key needed, all through AWS

**Instance Profile:**
```hcl
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}
```
- **Instance Profile:** Container for the IAM role
- EC2 instances don't use roles directly; they use instance profiles
- Think of it as the "adapter" between EC2 and IAM roles

**IAM Structure:**
```
IAM Role (permissions)
    ↓
Instance Profile (adapter)
    ↓
EC2 Instance (your server)
```

---

### 7. `ec2.tf` - EC2 Instance Configuration

**Purpose:** Creates the actual virtual server that will run your applications.

**Main Configuration:**
```hcl
resource "aws_instance" "main" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = var.key_name
```

**Field breakdown:**
- **ami:** Which operating system image to use (from main.tf data source)
- **instance_type:** Server size (t3.micro, t3.small, etc.)
- **subnet_id:** Which subnet to place the instance in
- **vpc_security_group_ids:** Which firewall rules to apply
- **iam_instance_profile:** What permissions it has
- **key_name:** SSH key for logging in

**Root Volume (Storage):**
```hcl
root_block_device {
  volume_size           = var.root_volume_size  # GB
  volume_type           = "gp3"                 # SSD type
  delete_on_termination = true                  # Delete when instance destroyed
  encrypted             = true                  # Encrypt data at rest
}
```
- **gp3:** Latest generation general-purpose SSD (faster & cheaper than gp2)
- **encrypted:** All data on disk is encrypted

**User Data (Startup Script):**
```hcl
user_data = <<-EOF
  #!/bin/bash
  # Update system
  apt-get update
  apt-get upgrade -y
  
  # Install Docker
  apt-get install -y ca-certificates curl gnupg
  # ... (Docker installation commands)
  
  # Add ubuntu user to docker group
  usermod -aG docker ubuntu
  
  # Install AWS CLI v2
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  # ... (AWS CLI installation)
  
  # Log into ECR
  aws ecr get-login-password --region ${var.aws_region} | \
    docker login --username AWS --password-stdin ${aws_ecr_repository.main.repository_url}
EOF
```

**What user_data does:**
- Runs ONCE when the instance first boots
- Installs Docker and AWS CLI
- Logs Docker into your ECR repository
- By the time you SSH in, everything is ready!

**User Data Gotchas:**
- Only runs on FIRST boot (not on restart)
- Runs as root user
- Logs saved to `/var/log/cloud-init-output.log`
- If it fails, instance still boots (check logs)

**Dependencies:**
```hcl
depends_on = [aws_internet_gateway.main]
```
- Ensures Internet Gateway exists before creating EC2
- Without IGW, user_data scripts can't download packages

**EC2 Instance Types:**
- **t3.micro:** 2 vCPU, 1 GB RAM (~$7.50/month)
- **t3.small:** 2 vCPU, 2 GB RAM (~$15/month)
- **t3.medium:** 2 vCPU, 4 GB RAM (~$30/month)

---

### 8. `ecr.tf` - Elastic Container Registry

**Purpose:** Creates a private Docker registry for your container images.

**Repository:**
```hcl
resource "aws_ecr_repository" "main" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"
```
- **name:** Repository name (must be lowercase, no special chars)
- **MUTABLE:** Image tags can be overwritten (e.g., `latest` tag can be updated)
- **IMMUTABLE:** Once pushed, a tag can't be changed (more secure but less flexible)

**Image Scanning:**
```hcl
image_scanning_configuration {
  scan_on_push = true
}
```
- Automatically scans images for security vulnerabilities when pushed
- Results visible in AWS Console
- Checks for CVEs (Common Vulnerabilities and Exposures)

**Encryption:**
```hcl
encryption_configuration {
  encryption_type = "AES256"
}
```
- Encrypts images at rest in S3
- **AES256:** AWS-managed encryption keys (free, easy)
- Alternative: **KMS** for customer-managed keys (more control, extra cost)

**Lifecycle Policy:**
```hcl
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name
  
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
```

**What this does:**
- Automatically deletes old images
- Keeps only the 10 most recent images
- Prevents storage costs from growing indefinitely
- **tagStatus: "any":** Applies to all images (tagged or not)

**ECR vs Docker Hub:**
- **ECR:** Private by default, integrated with IAM, pay per GB stored
- **Docker Hub:** Public/private, rate limits on pulls, simpler for beginners
- **ECR is better when:** Using AWS, need IAM integration, production workloads

**Using ECR:**
```bash
# Login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Push
docker tag my-app:latest <ecr-url>:latest
docker push <ecr-url>:latest

# Pull (on EC2)
docker pull <ecr-url>:latest
```

---

### 9. `variables.tf` - Input Variable Definitions

**Purpose:** Defines all configurable values with types, defaults, and descriptions.

**Variable Structure:**
```hcl
variable "variable_name" {
  description = "Human-readable explanation"
  type        = string | number | bool | list | map
  default     = "default_value"  # Optional
  validation {                    # Optional
    condition     = <expression>
    error_message = "Error message if validation fails"
  }
}
```

**Example Variables Explained:**

**AWS Region:**
```hcl
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
```
- Where to create resources
- Default saves typing but can be overridden

**Project Name:**
```hcl
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "my-project"
}
```
- Used as prefix for all resource names
- Makes resources easy to identify in AWS Console
- Example: `my-project-vpc`, `my-project-ec2-role`

**CIDR Blocks:**
```hcl
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}
```
- IP address range for your network
- `10.0.0.0/16` = 65,536 addresses
- Should not overlap with other networks you might peer with

**Instance Type:**
```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```
- Size/power of your server
- Change to `t3.small` or `t3.medium` for more resources

**Key Name:**
```hcl
variable "key_name" {
  description = "SSH key pair name for EC2 access"
  type        = string
  default     = ""
}
```
- Name of existing AWS key pair
- Must be created in AWS Console beforehand
- Empty string = no SSH access (use SSM instead)

**Security - SSH CIDR:**
```hcl
variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH into EC2"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Change this!
}
```
- **0.0.0.0/0 = EVERYONE** (bad for security)
- **Best practice:** `["YOUR.IP.ADDRESS/32"]`
- Find your IP: `curl ifconfig.me`

**ECR Repository Name:**
```hcl
variable "ecr_repository_name" {
  description = "Name of the ECR repository (lowercase, hyphens/underscores allowed)"
  type        = string
  default     = "my-app"
  
  validation {
    condition     = can(regex("^(?:[a-z0-9]+(?:[._-][a-z0-9]+)*/)*[a-z0-9]+(?:[._-][a-z0-9]+)*$", var.ecr_repository_name))
    error_message = "ECR repository name must be lowercase and can only contain letters, numbers, hyphens, underscores, and forward slashes."
  }
}
```
- Must be lowercase (ECR requirement)
- Validation block prevents invalid names
- Example valid names: `my-app`, `backend-api`, `web/frontend`

**Variable Types:**
- **string:** Text (`"hello"`)
- **number:** Integer or decimal (`42`, `3.14`)
- **bool:** true or false
- **list(type):** Array (`["a", "b", "c"]`)
- **map(type):** Key-value pairs (`{ key = "value" }`)

---

### 10. `outputs.tf` - Output Values

**Purpose:** Displays important information after Terraform creates resources.

**Why Outputs Matter:**
- Show resource IDs you'll need later
- Can be used by other Terraform modules
- Provide info for scripts/documentation

**Example Outputs:**

**VPC and Network IDs:**
```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
```
- Shows the AWS-generated VPC ID (e.g., `vpc-0a1b2c3d4e5f`)
- Needed if you later want to add resources to this VPC

**EC2 Public IP:**
```hcl
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.main.public_ip
}
```
- The IP address to SSH or browse to
- Changes if instance is stopped/started (use Elastic IP if you need static)

**SSH Command:**
```hcl
output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = var.key_name != "" ? "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.main.public_ip}" : "No key pair specified"
}
```
- **Conditional:** Shows command only if key_name is set
- Copy-paste ready command
- **ubuntu@:** Ubuntu is the default user for Ubuntu AMIs

**ECR Repository URL:**
```hcl
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.main.repository_url
}
```
- Full URL to push/pull images
- Format: `<account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>`

**Viewing Outputs:**
```bash
# After apply
terraform output

# Get specific output
terraform output ec2_public_ip

# Get raw value (no quotes)
terraform output -raw ecr_repository_url

# JSON format (for scripts)
terraform output -json
```

**Using Outputs in Scripts:**
```bash
# Store in variable
PUBLIC_IP=$(terraform output -raw ec2_public_ip)
echo "Connecting to $PUBLIC_IP"
ssh -i key.pem ubuntu@$PUBLIC_IP
```

---

### 11. `terraform.tfvars` - Your Actual Values

**Purpose:** Contains your specific values for variables (gitignored for security).

**Example:**
```hcl
aws_region          = "us-east-1"
project_name        = "magic-villa"
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
availability_zone   = "us-east-1a"
instance_type       = "t3.micro"
key_name            = "my-ssh-key"
root_volume_size    = 20
allowed_ssh_cidr    = ["203.0.113.25/32"]  # Your actual IP
ecr_repository_name = "magic-villa"
```

**Critical Security:**
- **NEVER commit this file to git!**
- Contains IP addresses, project names, potentially sensitive info
- `.gitignore` excludes it by default

**How Terraform Uses It:**
1. Reads `variables.tf` (defines what variables exist)
2. Reads `terraform.tfvars` (your values)
3. Applies your values to the definitions
4. Uses them throughout the configuration

**Variable Precedence (highest to lowest):**
1. Command line: `terraform apply -var="instance_type=t3.small"`
2. `terraform.tfvars` file
3. Environment variables: `TF_VAR_instance_type=t3.small`
4. Default values in `variables.tf`

---

### 12. `.gitignore` - Git Exclusions

**Purpose:** Tells git which files to never commit.

**What's excluded:**
```
# Terraform state files
*.tfstate
*.tfstate.*
```
- State files can contain sensitive data (passwords, private IPs)
- Should only be in S3 backend, never in git

```
# Variable files
*.tfvars
*.tfvars.json
```
- Your actual values (IPs, project names)
- Team members have their own values

```
# Terraform directory
.terraform/
```
- Downloaded provider plugins
- Changes frequently, huge files
- Each person downloads their own

```
# Lock file
.terraform.lock.hcl
```
- Some teams commit this (ensures same provider versions)
- Some gitignore it (allows flexibility)
- **Recommendation:** Commit it for reproducibility

---

### 13. `setup-backend.sh` - Backend Setup Script

**Purpose:** Automates creation of S3 bucket and DynamoDB table for Terraform state.

**What it does:**

**1. Creates S3 Bucket:**
```bash
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION"
```
- Creates the bucket to store state files

**2. Enables Versioning:**
```bash
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled
```
- Keeps history of state file changes
- Can recover from accidental deletions/modifications

**3. Enables Encryption:**
```bash
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '...'
```
- Encrypts state files at rest
- Important because state can contain sensitive data

**4. Blocks Public Access:**
```bash
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration "..."
```
- Prevents accidental public exposure
- Critical security measure

**5. Creates DynamoDB Table:**
```bash
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```
- **Purpose:** State locking
- Prevents two people from running `terraform apply` simultaneously
- **PAY_PER_REQUEST:** Only pay for actual usage (basically free)

**Usage:**
```bash
# With defaults
./setup-backend.sh

# Custom values
./setup-backend.sh my-bucket-name my-lock-table us-west-2
```

---

## 🔄 How All Files Work Together

### Terraform Execution Flow:

```
1. terraform init
   ├── Reads: main.tf (provider requirements)
   ├── Downloads: AWS provider plugin to .terraform/
   ├── Reads: backend.tf + backend-config.hcl
   └── Configures: S3 backend connection

2. terraform plan
   ├── Reads: All .tf files
   ├── Reads: terraform.tfvars (your values)
   ├── Reads: Current state from S3
   ├── Queries: AWS for existing resources
   └── Shows: What will be created/changed/destroyed

3. terraform apply
   ├── Locks: State file in DynamoDB
   ├── Creates: Resources in this order (based on dependencies):
   │   ├── VPC
   │   ├── Internet Gateway
   │   ├── Subnet
   │   ├── Route Table + Association
   │   ├── Security Group
   │   ├── IAM Role + Policies + Instance Profile
   │   ├── ECR Repository + Lifecycle Policy
   │   └── EC2 Instance (last, depends on everything)
   ├── Updates: State file in S3
   ├── Unlocks: DynamoDB lock
   └── Shows: Outputs

4. terraform destroy
   ├── Reads: State file from S3
   ├── Deletes: Resources in reverse dependency order
   └── Updates: State (marks everything as destroyed)
```

### Dependency Graph:

```
VPC
 ├── Internet Gateway
 ├── Subnet
 │    └── EC2 Instance
 └── Security Group
      └── EC2 Instance

IAM Role
 └── Instance Profile
      └── EC2 Instance

ECR Repository
 └── (Referenced in EC2 user_data)

Route Table
 └── Internet Gateway
      └── Route Table Association
```

Terraform automatically figures out the order based on resource references (`aws_vpc.main.id`, etc.)

---

## 🎯 Common Workflows

### Initial Setup (First Time):

```bash
# 1. Create backend infrastructure
./setup-backend.sh my-terraform-state-bucket

# 2. Configure backend
cp backend-config.hcl.example backend-config.hcl
# Edit backend-config.hcl with your bucket name

# 3. Set your values
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# 4. Initialize Terraform
terraform init -backend-config=backend-config.hcl

# 5. Preview changes
terraform plan

# 6. Deploy
terraform apply
```

### Daily Development:

```bash
# Make changes to .tf files

# See what will change
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output
```

### Updating Variables:

```bash
# Edit terraform.tfvars
vim terraform.tfvars

# Apply new values
terraform apply
```

### Destroying Everything:

```bash
# Preview what will be deleted
terraform plan -destroy

# Destroy all resources
terraform destroy
```

### Migrating State to S3 (If You Started Local):

```bash
# Add backend.tf and backend-config.hcl

# Re-initialize with migration
terraform init -migrate-state

# Answer 'yes' when prompted
```

---

## 🔍 Troubleshooting Guide

### State Lock Issues:

**Problem:** "Error acquiring the state lock"

**Solution:**
```bash
# Force unlock using the Lock ID from error message
terraform force-unlock <lock-id>
```

### Permission Errors:

**Problem:** "User is not authorized to perform: X"

**Solution:**
- Check your IAM policy includes the required permissions
- See the comprehensive policy in the main README

### AMI Not Found:

**Problem:** "No matching AMI found"

**Solution:**
- Check if the region supports Ubuntu 24.04
- Try changing `availability_zone` in terraform.tfvars
- Verify the AMI filter in main.tf

### EC2 Won't Start:

**Problem:** Instance state is "pending" forever

**Solution:**
```bash
# Check logs in AWS Console
# Or SSH in and check cloud-init logs
ssh ubuntu@<ip> 'tail -100 /var/log/cloud-init-output.log'
```

### Backend Bucket Doesn't Exist:

**Problem:** "Error loading state: NoSuchBucket"

**Solution:**
```bash
# Create backend infrastructure
./setup-backend.sh <bucket-name>

# Verify bucket exists
aws s3 ls | grep <bucket-name>
```

---

## 📚 Additional Resources

### Terraform Concepts:
- **Resource:** Something you want to create (EC2, VPC, etc.)
- **Data Source:** Query existing resources (AMI, availability zones)
- **Variable:** Input parameter
- **Output:** Value to display/export
- **Provider:** Plugin to interact with cloud platform
- **State:** Current infrastructure mapping
- **Module:** Reusable group of resources

### Best Practices:

1. **Always use remote state (S3)**
   - Enables team collaboration
   - Provides backup and versioning

2. **Lock your provider versions**
   - `~> 5.0` instead of `>= 5.0`
   - Prevents breaking changes

3. **Use meaningful names**
   - Tag everything with project_name
   - Makes AWS Console navigation easy

4. **Never commit sensitive files**
   - terraform.tfvars
   - State files
   - backend-config.hcl

5. **Always run terraform plan first**
   - Preview changes before applying
   - Catch mistakes early

6. **Use variables for everything that might change**
   - Region, instance size, IP ranges
   - Makes code reusable

7. **Document with descriptions**
   - Every variable should have a description
   - Comments for complex logic

### Cost Management:

**Monthly Estimates:**
- t3.micro EC2: ~$7.50
- EBS gp3 20GB: ~$2
- ECR storage: ~$0.10/GB
- Data transfer: Variable
- **Total:** ~$10-15/month

**Cost Optimization:**
- Stop EC2 when not in use (still pay for EBS)
- Use t3.micro for dev/testing
- Clean up old ECR images (lifecycle policy helps)
- Delete unused resources with `terraform destroy`

---

## 🎓 Learning Path

### Beginner:
1. Understand what each .tf file does (this README)
2. Deploy the infrastructure
3. SSH into EC2 and explore
4. Modify variables and re-apply
5. Destroy and recreate

### Intermediate:
1. Add additional resources (RDS database, S3 bucket)
2. Create multiple environments (dev/prod)
3. Use Terraform modules
4. Implement CI/CD with GitHub Actions
5. Add custom user_data scripts

### Advanced:
1. Multi-region deployment
2. Auto-scaling groups
3. Custom VPC peering
4. Terraform workspaces
5. Policy as code (Sentinel, OPA)

---

## ❓ FAQ

**Q: Can I use this in production?**
A: Yes, but add:
- More restrictive security groups
- Backup strategies
- Monitoring/alerting
- High availability (multiple AZs)
- Load balancer

**Q: How do I add more EC2 instances?**
A: Copy the `aws_instance` block and give it a different name, or use `count` parameter.

**Q: Can I change the instance size after creation?**
A: Yes! Change `instance_type` in terraform.tfvars and run `terraform apply`. Instance will be stopped and resized.

**Q: What if I lose my state file?**
A: With S3 backend, it's backed up and versioned. Without S3, you'd need to `terraform import` everything manually (painful).

**Q: Do I need all these files?**
A: You can combine everything into main.tf, but separate files are clearer and more maintainable.

**Q: Can multiple people use this?**
A: Yes! With S3 backend and DynamoDB locking, multiple team members can safely work on the same infrastructure.

---

## 📞 Getting Help

1. Check terraform plan output carefully
2. Read error messages - they're usually specific
3. Check AWS Console to see what was created
4. Use `terraform state list` to see tracked resources
5. Use `terraform state show <resource>` for details
6. Check logs: `/var/log/cloud-init-output.log` on EC2

**Remember:** Terraform is declarative. You describe the end state you want, and Terraform figures out how to get there!