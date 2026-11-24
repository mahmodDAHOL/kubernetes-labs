#!/bin/sh
# Usage (inside the api-client pod):  sh /tmp/call-api.sh <api-path>
# Example:                            sh /tmp/call-api.sh /api/v1/namespaces/dev/pods
SA=/var/run/secrets/kubernetes.io/serviceaccount
TOKEN=$(cat $SA/token)
curl -s --cacert $SA/ca.crt \
     -H "Authorization: Bearer $TOKEN" \
     -o /tmp/out.json -w "HTTP %{http_code}\n" \
     "https://kubernetes.default.svc$1"
# print the first lines of the response so you can see what came back
head -c 400 /tmp/out.json; echo
