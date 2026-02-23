"""
Lambda function to create EC2 instance as GitHub Actions runner

Required Lambda IAM permissions:
- ec2:RunInstances
- ec2:CreateTags
- ec2:DescribeInstances
- iam:CreateInstanceProfile
- iam:AddRoleToInstanceProfile
- iam:GetInstanceProfile
- iam:PassRole

Required: GitHub token stored in Lambda environment variable GITHUB_TOKEN
"""

import boto3
import base64  
import time
import os

def lambda_handler(event, context):
    region = "us-east-1"
    AMI_ID = "ami-0b6c6ebed2801a5cb"
    Instance_Type = "t2.micro"
    SG = ["sg-007617f4dfcbf348a"]
    ec2 = boto3.client("ec2", region_name=region)
    iam = boto3.client('iam', region_name=region)
    user_data_content = """#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting GitHub Actions Runner setup..."

# Create runner directory
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner

# Download runner
curl -o actions-runner-linux-x64-2.331.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.331.0/actions-runner-linux-x64-2.331.0.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-2.331.0.tar.gz

# Set ownership
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Configure runner as ubuntu
sudo -u ubuntu ./config.sh --url https://github.com/aseelmalkawi/dockerized-dotnet-app --token **** --unattended

# Install and start service
./svc.sh install ubuntu
./svc.sh start

echo "GitHub Actions Runner setup complete!"

# Install Ansible
echo "Installing Ansible..."
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Install Terraform
echo "Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y terraform

# Install AWSCLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Docker
echo "Installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker

# Allow ubuntu user to run docker without sudo
sudo usermod -aG docker ubuntu

echo "All installations complete!"
"""

    # Encode to Base64
    encoded_user_data = base64.b64encode(user_data_content.encode('utf-8')).decode('utf-8')

    # Create instance profile for IAM role
    profile_name = 'gh-runner-profile'
    role_name = 'gh-runner-role'  # This role must already exist

    # FIXED: Create profile BEFORE launching instance
    print(f"Setting up IAM instance profile: {profile_name}")
    
    try:
        iam.create_instance_profile(InstanceProfileName=profile_name)
        print(f"Created instance profile: {profile_name}")
        time.sleep(2)
    except iam.exceptions.EntityAlreadyExistsException:
        print(f"Instance profile {profile_name} already exists.")
    except Exception as e:
        print(f"Error creating instance profile: {e}")

    # Add the IAM Role to the Profile
    try:
        iam.add_role_to_instance_profile(
            InstanceProfileName=profile_name,
            RoleName=role_name
        )
        print(f"Added role {role_name} to profile {profile_name}")
        time.sleep(10)
    except iam.exceptions.LimitExceededException:
        print("Role already attached or limit reached.")
    except Exception as e:
        print(f"Error adding role to profile: {e}")

    # Now launch the EC2 instance
    print("Launching EC2 instance...")
    try:
        response = ec2.run_instances(
            ImageId=AMI_ID,
            InstanceType=Instance_Type,
            MinCount=1,
            MaxCount=1,
            KeyName="aseel-cicd",
            SecurityGroupIds=SG,
            UserData=encoded_user_data,
            IamInstanceProfile={
                'Name': profile_name
            },
            TagSpecifications=[
                {
                    'ResourceType': 'instance',
                    'Tags': [
                        {
                            'Key': 'Name',
                            'Value': 'gh-runner'
                        },
                        {
                            'Key': 'Purpose',
                            'Value': 'GitHubActionsRunner'
                        },
                        {
                            'Key': 'ManagedBy',
                            'Value': 'Lambda'
                        }
                    ]
                }
            ]
        )

        instance_id = response["Instances"][0]["InstanceId"]
        print(f"Created EC2 instance: {instance_id}")
        
        return {
            'statusCode': 200,
            'body': {
                'message': 'GitHub Runner instance created successfully',
                'instance_id': instance_id,
                'profile_name': profile_name
            }
        }
        
    except Exception as e:
        print(f"Error launching instance: {e}")
        return {
            'statusCode': 500,
            'body': {
                'error': str(e)
            }
        }
