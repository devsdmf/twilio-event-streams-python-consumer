#!/bin/bash

JQ_CHECK=$(which jq)
if [ -z "$JQ_CHECK" ]; then
  echo
  echo "This script requires the jq JSON processor. Please install for your OS from https://stedolan.github.io/jq/download/"
  echo
  exit 1
fi

if [ $# -ne 2 ]; then
  echo
  echo "usage: $0 <stream_name> <shard_count>"
  echo
  exit 1
fi

# Set the stream name
STREAM_NAME=${1:-twilio-events}
SHARD_COUNT=${2:-1}

# Create the initial stream
aws kinesis create-stream --stream-name $STREAM_NAME --shard-count $SHARD_COUNT
if [ $? -ne 0 ]; then
  echo "Kinesis create failed"
  exit 1
fi

# Get the ARN for the Kinesis Stream
KINESIS_ARN=$(aws kinesis describe-stream --stream-name $STREAM_NAME | jq -r .StreamDescription.StreamARN)

# Create the policy for the Kinesis Stream
POLICY_ARN=$(aws iam create-policy --policy-name twilio-events-kinesis-write --policy-document '{
   "Version": "2012-10-17",
   "Statement": [
       {
           "Sid": "Quickstart0",
           "Effect": "Allow",
           "Action": [
               "kinesis:PutRecord",
               "kinesis:PutRecords"
           ],
           "Resource": "'$KINESIS_ARN'"
       },
       {
           "Sid": "Quickstart1",
           "Effect": "Allow",
           "Action": [
               "kinesis:ListShards",
               "kinesis:DescribeLimits"
           ],
           "Resource": "*"
       }
   ]
}' | jq -r .Policy.Arn)

if [ -z "$POLICY_ARN" ]; then
  echo "Failed to create IAM policy"
  exit 1
fi

# Generate a random external ID
EXTERNAL_ID=$(openssl rand -hex 40)
if [ -z "$EXTERNAL_ID" ]; then
  echo "Failed to generate external ID"
  exit 1
fi

# This is the Twilio account that needs permissions to be able to assume the role
TWILIO_ASSUME_ROLE_ACCOUNT=${TWILIO_ASSUME_ROLE_ACCOUNT:-arn:aws:iam::177261743968:root}

# Add the random external ID to the the role ARN
# More information can be found here: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html
ROLE_ARN=$(aws iam create-role --role-name twilio-events-kinesis-write --assume-role-policy-document '{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Principal": {
       "AWS": "'$TWILIO_ASSUME_ROLE_ACCOUNT'"
     },
     "Action": "sts:AssumeRole",
     "Condition": {
       "StringEquals": {
         "sts:ExternalId": "'$EXTERNAL_ID'"
       }
     }
   }
 ]
}' | jq -r .Role.Arn)

if [ -z "$ROLE_ARN" ]; then
  echo "Failed to create IAM role"
  exit 1
fi

# Finally attach the policy and the role
aws iam attach-role-policy --role-name twilio-events-kinesis-write --policy-arn $POLICY_ARN

if [ $? -ne 0 ]; then
  echo "Attaching policy to role failed"
  exit 1
fi

# Print out the values needed for creating the sink in nice JSON
echo "{"
echo '"arn":"'$KINESIS_ARN'",'
echo '"role_arn":"'$ROLE_ARN'",'
echo '"external_id":"'$EXTERNAL_ID'"'
echo "}"