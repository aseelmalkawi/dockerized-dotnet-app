NGINX_CONF=$(base64 -w 0 default.conf)
COMPOSE_CONTENT=$(sed "s|\${IMAGE}|${{ env.ECR_URI }}:${{ env.VERSION }}|g" docker-compose.yaml | base64 -w 0)
DEPLOY_SCRIPT=$(base64 -w 0 common/deploy.sh)

cat > /tmp/ssm-input.json << EOF
{
    "DocumentName": "AWS-RunShellScript",
    "InstanceIds": ["${{ env.INSTANCE_ID }}"],
    "TimeoutSeconds": 300,
    "Parameters": {
    "commands": [
        "echo $DEPLOY_SCRIPT | base64 -d > /tmp/deploy.sh && chmod +x /tmp/deploy.sh && /tmp/deploy.sh ${{ env.ECR_URI }} $COMPOSE_CONTENT $NGINX_CONF"
    ]
    }
}
EOF

COMMAND_ID=$(aws ssm send-command \
    --cli-input-json file:///tmp/ssm-input.json \
    --query 'Command.CommandId' \
    --output text)

aws ssm wait command-executed \
    --command-id $COMMAND_ID \
    --instance-id ${{ env.INSTANCE_ID }}

STATUS=$(aws ssm get-command-invocation \
    --command-id $COMMAND_ID \
    --instance-id ${{ env.INSTANCE_ID }} \
    --query 'StatusDetails' \
    --output text)

OUTPUT=$(aws ssm get-command-invocation \
    --command-id $COMMAND_ID \
    --instance-id ${{ env.INSTANCE_ID }} \
    --query 'StandardOutputContent' \
    --output text)

echo "Output: $OUTPUT"
echo "Status: $STATUS"

[ "$STATUS" = "Success" ] || exit 1