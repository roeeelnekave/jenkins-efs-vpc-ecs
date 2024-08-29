#!/bin/bash

# update the stack name
STACK_NAME="jenkins-efs-ecs"
# update to your desired aws region
AWS_REGION="us-east-1"

# Set or update the repository name
REPOSITORY_NAME="jenkins"

# Set the image tag
IMAGE_TAG="latest"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output --region $AWS_REGION)
# Create the ECR repository
aws ecr describe-repositories --repository-names "${REPOSITORY_NAME}" --region $AWS_REGION > /dev/null 2>&1
if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${REPOSITORY_NAME}" --region $AWS_REGION > /dev/null
fi


# Build the Docker image
docker build -t $REPOSITORY_NAME:$IMAGE_TAG .

# Get the ECR login command
LOGIN_COMMAND=$(aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com)
# Push the image to ECR
docker tag $REPOSITORY_NAME:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG

# Export the image URI as an environment variable
IMAGE_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG

aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://main.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides ImageURL=$IMAGE_URI