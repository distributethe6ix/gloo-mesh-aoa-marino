#!/bin/bash
set -e

# note that the character '_' is an invalid value if you are replacing the defaults below
cluster1_context="cluster1"

# check to see if defined contexts exist
if [[ $(kubectl config get-contexts | grep ${cluster1_context}) == "" ]] ; then
  echo "Check Failed: ${cluster1_context} contexts does not exist. Please check to see if the cluster is available"
  echo "Run 'kubectl config get-contexts' to see currently available contexts. If the clusters are available, please make sure that they are named correctly."
  exit 1;
fi

# install argocd on ${cluster1_context}
cd bootstrap-argocd
./install-argocd.sh default ${cluster1_context}
cd ..

# wait for argo cluster rollout
./tools/wait-for-rollout.sh deployment argocd-server argocd 20 ${cluster1_context}

# deploy mgmt, cluster1 cluster config aoa
kubectl apply -f platform-owners/cluster1/cluster1-cluster-config.yaml --context ${cluster1_context}

# deploy mgmt, cluster1 environment infra app-of-apps
kubectl apply -f platform-owners/cluster1/cluster1-infra.yaml --context ${cluster1_context}

# wait for completion of istio install
./tools/wait-for-rollout.sh deployment istiod istio-system 10 ${cluster1_context}

# deploy cluster1 environment apps aoa
kubectl apply -f platform-owners/cluster1/cluster1-apps.yaml --context ${cluster1_context}

# wait for completion of bookinfo install
#./tools/wait-for-rollout.sh deployment productpage-v1 default 10 ${cluster1_context}

# deploy cluster1 mesh config aoa
kubectl apply -f platform-owners/cluster1/cluster1-mesh-config.yaml --context ${cluster1_context}

# echo port-forward commands
echo
echo "access argocd dashboard:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443 --context ${cluster1_context}"
echo