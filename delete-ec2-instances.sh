#!/bin/bash

instances=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "web" "dispatch")

domain_name="lithesh.shop"
hosted_zone_id="Z012785114HGZTDQ8KSQH"

for name in ${instances[@]}; do

echo "Processing $name..."

# Get Instance ID
instance_id=$(aws ec2 describe-instances \
--filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=running,pending,stopped" \
--query 'Reservations[*].Instances[*].InstanceId' \
--output text)

if [ -z "$instance_id" ]; then
    echo "No instance found for $name"
else
    echo "Terminating instance $instance_id for $name"
    aws ec2 terminate-instances --instance-ids $instance_id
fi

# Get IP address to remove from Route53
if [ "$name" == "web" ]; then
    ip=$(aws ec2 describe-instances \
    --instance-ids $instance_id \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
else
    ip=$(aws ec2 describe-instances \
    --instance-ids $instance_id \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)
fi

echo "Deleting Route53 record for $name"

aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch "{
  \"Comment\": \"Deleting record for $name\",
  \"Changes\": [{
    \"Action\": \"DELETE\",
    \"ResourceRecordSet\": {
      \"Name\": \"$name.$domain_name\",
      \"Type\": \"A\",
      \"TTL\": 1,
      \"ResourceRecords\": [{
        \"Value\": \"$ip\"
      }]
    }
  }]
}"

echo "$name cleanup done"
echo "----------------------------------"

done