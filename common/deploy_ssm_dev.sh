#!/bin/bash
set -e

ECR_URI=$1
VERSION=$2
INSTANCE_ID=$3

NGINX_CONF=$(base64 -w 0 default.conf)
COMPOSE_CONTENT=$(sed "s|\${IMAGE}|$ECR_URI:$VERSION|g" docker-compose.yaml | base64 -w 0)
DEPLOY_SCRIPT=$(base64 -w 0 common/ssm_command_dev.sh)

cat > /tmp/ssm-input.json << EOF
{
  "DocumentName": "AWS-RunShellScript",
  "InstanceIds": ["$INSTANCE_ID"],
  "TimeoutSeconds": 300,
  "Parameters": {
    "commands": [
      "echo $DEPLOY_SCRIPT | base64 -d > /tmp/deploy.sh && chmod +x /tmp/deploy.sh && /tmp/deploy.sh $ECR_URI $COMPOSE_CONTENT $NGINX_CONF"
    ]
  }
}
EOF

COMMAND_ID=$(aws ssm send-command \
  --cli-input-json file:///tmp/ssm-input.json \
  --query 'Command.CommandId' \
  --output text)

echo "Waiting for deployment..."
aws ssm wait command-executed \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID

STATUS=$(aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID \
  --query 'StatusDetails' \
  --output text)

OUTPUT=$(aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID \
  --query 'StandardOutputContent' \
  --output text)

echo "Output: $OUTPUT"
echo "Status: $STATUS"

[ "$STATUS" = "Success" ] || exit 1