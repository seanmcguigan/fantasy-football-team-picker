#!/bin/bash

# Create S3 Bucket
aws s3 mb "s3://tf-remote-bucket-gonk" --region "us-east-1"

# Create DynamoDB Table
aws dynamodb create-table \
  --table-name "tf-lock-table" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region "us-east-1"
