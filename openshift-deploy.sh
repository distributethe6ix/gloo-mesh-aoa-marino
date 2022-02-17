#!/bin/bash
set -e

# note that the character '_' is an invalid value if you are replacing the defaults below
cluster1_context="cluster1"
mgmt_context="mgmt"
gloo_mesh_version="1.2.16"

# add anyuid for every project used by istio
oc --context ${cluster1_context} adm policy add-scc-to-group anyuid system:serviceaccounts:istio-system
oc --context ${cluster1_context} adm policy add-scc-to-group anyuid system:serviceaccounts:istio-operator
oc --context ${cluster1_context} adm policy add-scc-to-group anyuid system:serviceaccounts:bookinfo-v1
#oc --context ${cluster1_context} adm policy add-scc-to-group anyuid system:serviceaccounts:bookinfo-beta

# install argocd on ${mgmt_context}, ${cluster1_context}, and ${cluster2_context}
cd bootstrap-argocd
./install-argocd.sh default ${mgmt_context}
./install-argocd.sh default ${cluster1_context}
cd ..

# wait for argo cluster rollout
./tools/wait-for-rollout.sh deployment argocd-server argocd 20 ${mgmt_context}
./tools/wait-for-rollout.sh deployment argocd-server argocd 20 ${cluster1_context}

# deploy mgmt, cluster1, and cluster2 cluster config aoa
#kubectl apply -f platform-owners/mgmt/mgmt-cluster-config.yaml --context ${mgmt_context}
#kubectl apply -f platform-owners/cluster1/cluster1-cluster-config.yaml --context ${cluster1_context}
#kubectl apply -f platform-owners/cluster2/cluster2-cluster-config.yaml --context ${cluster2_context}

# deploy mgmt, cluster1, and cluster2 environment infra app-of-apps
kubectl apply -f platform-owners/mgmt/mgmt-infra.yaml --context ${mgmt_context}
kubectl apply -f platform-owners/cluster1/cluster1-infra.yaml --context ${cluster1_context}

# wait for completion of istio install
./tools/wait-for-rollout.sh deployment istiod istio-system 10 ${cluster1_context}

# register clusters to gloo mesh
./tools/meshctl-register-helm-argocd-1-cluster-hostname.sh ${mgmt_context} ${cluster1_context} ${gloo_mesh_version}

# deploy cluster1, and cluster2 environment apps aoa
#kubectl apply -f platform-owners/mgmt/mgmt-apps.yaml --context ${mgmt_context}
kubectl apply -f platform-owners/cluster1/cluster1-apps.yaml --context ${cluster1_context}

# wait for completion of bookinfo install
./tools/wait-for-rollout.sh deployment productpage-v1 default 10 ${cluster1_context}
