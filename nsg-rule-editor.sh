#!/bin/bash

export TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
export ENDPOINT="${ENDPOINT:-kubernetes.default.svc.cluster.local}"
export NAMESPACE="${NAMESPACE:-default}"
export CONFIGMAP_NAME="${CONFIGMAP_NAME:-raspberry-ip}"

if [[ -z "${NAMESPACE}" ]] || [[ -z "${CONFIGMAP_NAME}" ]] || [[ -z "${FQDN}" ]] || [[ -z "${NSG_ID}" ]]; then
  echo "Environment Variables NAMESPACE, CONFIGMAP_NAME, FQDN, NSG_ID are required."
fi

echo -e "Monitoring: \t ${FQDN}"
echo -e "OCI NSG ID: \t ${NSG_ID}"
echo -e "K8s Endpoint: \t ${ENDPOINT}"
echo -e "ConfigMap Name: \t ${CONFIGMAP_NAME}"

while sleep 60; do

  OLD_IP_ADDR="$(curl -sk \
      -H "Authorization: Bearer $TOKEN" \
      -H 'Accept: application/json' \
      https://$ENDPOINT/api/v1/namespaces/$NAMESPACE/configmaps/$CONFIGMAP_NAME | jq -r .data.ipaddr)"

  NEW_IP_ADDR=$(dig +short @8.8.8.8 A $FQDN)

  if [[ "${OLD_IP_ADDR}" != "${NEW_IP_ADDR}" ]]; then
    oci network nsg rules list --nsg-id "${NSG_ID}" | jq '.data | walk(if type == "object" then del(."is-valid", ."time-created") else . end) | {securityRules: ., nsgId: "__NSG_ID__"} ' | sed -e "s|__NSG_ID__|${NSG_ID}|g" -e "s|${OLD_IP_ADDR}|${NEW_IP_ADDR}|g" | jq 'walk( if type == "object" then with_entries(select(.value != null)) else . end)' | tee /tmp/update.json && \
    oci network nsg rules update --from-json file:///tmp/update.json && \
    curl -skX PATCH \
      -H "Authorization: Bearer $TOKEN" \
      -H 'Content-Type: application/strategic-merge-patch+json' \
      https://$ENDPOINT/api/v1/namespaces/$NAMESPACE/configmaps/$CONFIGMAP_NAME \
      -d "{\"data\":{\"ipaddr\": \"${NEW_IP_ADDR}\"}}"
  fi
done
