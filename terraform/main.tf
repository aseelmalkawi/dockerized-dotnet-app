terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "local_file" "inventory" {
  filename = "Ansible/inventory.yml"
  content  = yamlencode({
    all = {
      hosts = {
        my_server = {
          ansible_host             = aws_instance.main.public_ip
          ansible_user             = "ubuntu"
          ansible_ssh_private_key_file = "/tmp/deploy_key"
        }
      }
    }
  })

}