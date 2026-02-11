echo "push the latest docker image with test tag..."

# Step 1: fetch the latest tag into a variable
LATEST_TAG=$(aws ecr describe-images \
  --repository-name cicd-aseel \
  --region "$AWS_REGION" \
  --output json \
  | jq -r '
    .imageDetails[]
    | select(.imageTags != null)
    | select([.imageTags[] | contains("test")] | any)
    | {pushedAt: .imagePushedAt, tag: (.imageTags[] | select(contains("test")))}
  ' | jq -s 'sort_by(.pushedAt) | last.tag')

# Step 2: trim quotations (if any)
LATEST_TAG=$(echo "$LATEST_TAG" | tr -d '"')
echo "Latest tag = $LATEST_TAG"
export LATEST_ECR_IMAGE="$ECR_URI/cicd-aseel:$LATEST_TAG"

# Step 3: pull the actual image
echo "Pulling $LATEST_ECR_IMAGE"
docker pull "$LATEST_ECR_IMAGE"

# Step 4: create the base tag without test
BASE_TAG=$(echo "$LATEST_TAG" | cut -d'-' -f1 | tr -d '"')
echo "export BASE_TAG=$BASE_TAG" >> "$GITHUB_ENV"
echo "BASE_TAG=$BASE_TAG"
echo "BASE_TAG=$BASE_TAG" >> "$GITHUB_OUTPUT"

# Step 5: docker tag
docker tag "$ECR_URI/cicd-aseel:$LATEST_TAG" "$ECR_URI/cicd-aseel:$BASE_TAG"

# Step 6: push the promoted image to ECR
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_URI"

docker push "$ECR_URI/cicd-aseel:$BASE_TAG"

