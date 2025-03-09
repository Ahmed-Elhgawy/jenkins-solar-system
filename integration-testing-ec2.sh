#! /bin/bash

echo "Integration Testing ..."

aws --version
Data=$(aws ec2 describe-instances)
URL=$(aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | select(.Tags[].Value == "Docker server") | .PublicDnsName')
echo "URL: $URL"

if [[ "$URL" != '' ]]; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://$URL:3000/live)
    if [[ "$http_code" == 200 ]]; then
        echo "Integration Testing Passed"
    else
        echo "Integration Testing Failed, liveness probe failed"
        exit 1;
    fi;
else
    echo "Integration Testing Failed"
    exit 1;
fi;