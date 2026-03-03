#!/bin/bash
set -e

NGINX_CONF=$(base64 -w 0 default.conf)

cat > /tmp/ssm-input.json << EOF
{
  "DocumentName": "AWS-RunShellScript",
  "InstanceIds": ["$INSTANCE_ID"],
  "TimeoutSeconds": 300,
  "Parameters": {
    "commands": [
      "rm -f /etc/nginx/conf.d/default.conf && echo $NGINX_CONF | base64 -d > /etc/nginx/conf.d/default-prod.conf"
    ]
  }
}
EOF

COMMAND_ID=$(aws ssm send-command \
  --cli-input-json file:///tmp/ssm-input.json \
  --query 'Command.CommandId' \
  --output text)

echo "Waiting for the command to be executed..."
aws ssm wait command-executed \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID

STATUS=$(aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID \
  --query 'StatusDetails' \
  --output text)

echo "Status: $STATUS"

[ "$STATUS" = "Success" ] || exit 1