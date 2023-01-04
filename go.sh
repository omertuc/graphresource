#!/bin/bash

set -euxo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

mkdir -p $SCRIPT_DIR/audit
oc adm node-logs $(oc get nodes -oname) --path=kube-apiserver/ | grep audit | while read log; do oc adm node-logs master1 --path=kube-apiserver/$log > audit/$log; done

echo 'function data() { return (' > $SCRIPT_DIR/data.js

now=$(jq -n 'now | todateiso8601' -r)

cat $SCRIPT_DIR/audit/*audit* | jq --arg now "$now" -r --slurp '
. as $root |
[
    ["pods", "deployments", "secrets", "configmaps"][]
    | . as $type
    | {
        "group": $type,
        "data": [
            $root[] 
            | select(
                .verb == "create"
                and .objectRef.resource == $type
                and .responseStatus.code == 201
                and .objectRef.resource != "subjectaccessreviews"
                and .objectRef.resource != "tokenreviews"
                and .objectRef.name != null
            ) 
            | {
                "label": "\(.objectRef.namespace)/\(.objectRef.name)",
                "data": [
                    {
                        "timeRange": [ .requestReceivedTimestamp, $now ],
                        "val": .objectRef.namespace
                    }
                ]
            }
        ]
    }
]
' >> data.js
echo ')}' >> data.js
