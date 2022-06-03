#!/bin/bash

mgmt_context="mgmt"

# newly generated self-signed root/intermediates
#kubectl apply -f ../mgmt/1.1.a.mgmt-root-trust.yaml --context ${mgmt_context}

# leverage existing root cert and generate intermediates from it
kubectl apply -f ../mgmt/1.1.b.mgmt-root-trust-secretref.yaml --context ${mgmt_context}

kubectl apply -f ../mgmt/1.2.a.mgmt-workspace.yaml --context ${mgmt_context}

kubectl apply -f ../mgmt/1.2.b-global-workspace-settings.yaml --context ${mgmt_context}