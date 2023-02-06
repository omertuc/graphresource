#!/bin/bash

set -euxo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

mv audit "audit_old_$(date -u +%Y-%m-%dT%H:%M:%S%Z)" || true
mkdir -p "$SCRIPT_DIR/audit"
oc adm node-logs "$(oc get nodes -oname)" --path=kube-apiserver/ | grep audit | while read -r log; do oc adm node-logs master1 "--path=kube-apiserver/$log" > "audit/$log"; done

now=$(jq -n 'now | todateiso8601' -r)

cat "$SCRIPT_DIR"/audit/*audit* | jq --arg now "$now" -r --slurp -f create.jq > data.json
cat "$SCRIPT_DIR"/audit/*audit* | jq --slurp -f co.jq > codata.json

jq -s '.[0] + .[1]' codata.json data.json | sponge data.json

rm -f codata.json

AVAILABILITY_DATA="$SCRIPT_DIR/../kube-api-availability/static/data.json"
if [[ -f $AVAILABILITY_DATA ]]; then
	# Merge the AVAILABILITY_DATA JSON array with our data.js JSON array
	jq -s '.[0] + .[1]' "$AVAILABILITY_DATA" data.json | sponge data.json
fi

