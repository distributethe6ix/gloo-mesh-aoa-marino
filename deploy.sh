#!/bin/bash
set -e

# note that the character '_' is an invalid value if you are replacing the defaults below
cluster1_context="cluster1"
cluster2_context="cluster2"
mgmt_context="mgmt"
gloo_mesh_version="2.0.0-beta31"
revision="1-12"

# check to see if defined contexts exist
if [[ $(kubectl config get-contexts | grep ${mgmt_context}) == "" ]] || [[ $(kubectl config get-contexts | grep ${cluster1_context}) == "" ]] || [[ $(kubectl config get-contexts | grep ${cluster2_context}) == "" ]]; then
  echo "Check Failed: Either mgmt, cluster1, and cluster2 contexts do not exist. Please check to see if you have three clusters available"
  echo "Run 'kubectl config get-contexts' to see currently available contexts. If the clusters are available, please make sure that they are named correctly. Default is mgmt, cluster1, and cluster2"
  exit 1;
fi

# install argocd on ${mgmt_context}, ${cluster1_context}, and ${cluster2_context}
cd bootstrap-argocd
./install-argocd.sh default ${mgmt_context}
./install-argocd.sh default ${cluster1_context}
./install-argocd.sh default ${cluster2_context}
cd ..

# wait for argo cluster rollout
./tools/wait-for-rollout.sh deployment argocd-server argocd 20 ${mgmt_context}
./tools/wait-for-rollout.sh deployment argocd-server argocd 20 ${cluster1_context}
./tools/wait-for-rollout.sh deployment argocd-server argocd 20 ${cluster2_context}

# deploy mgmt, cluster1, and cluster2 cluster config aoa
kubectl apply -f platform-owners/mgmt/mgmt-cluster-config.yaml --context ${mgmt_context}
kubectl apply -f platform-owners/cluster1/cluster1-cluster-config.yaml --context ${cluster1_context}
kubectl apply -f platform-owners/cluster2/cluster2-cluster-config.yaml --context ${cluster2_context}

############## fix this later ####################
#
## manual step because order matters - istio-base must come before istiod
#kubectl apply -f environments/cluster1/infra/active/istio-base.yaml --context ${cluster1_context}
#kubectl apply -f environments/cluster2/infra/active/istio-base.yaml --context ${cluster2_context}
#sleep 15
#
## manual step because order matters - istiod must come before ingressgateway
#kubectl apply -f environments/cluster1/infra/active/istiod-${revision}.yaml --context ${cluster1_context}
#kubectl apply -f environments/cluster2/infra/active/istiod-${revision}.yaml --context ${cluster2_context}
#
## wait for completion of istiod install
#./tools/wait-for-rollout.sh deployment istiod-${revision} istio-system 10 ${cluster1_context}
#./tools/wait-for-rollout.sh deployment istiod-${revision} istio-system 10 ${cluster2_context}
#
## sleep 30
#echo sleeping for 30 seconds
#sleep 30
#
############## fix this later ####################

# this meta app will take over the manual apps above
# deploy mgmt, cluster1, and cluster2 environment infra app-of-apps
kubectl apply -f platform-owners/mgmt/mgmt-infra.yaml --context ${mgmt_context}
kubectl apply -f platform-owners/cluster1/cluster1-infra.yaml --context ${cluster1_context}
kubectl apply -f platform-owners/cluster2/cluster2-infra.yaml --context ${cluster2_context}

# wait for completion of istiod install
./tools/wait-for-rollout.sh deployment istiod-${revision} istio-system 10 ${cluster1_context}
./tools/wait-for-rollout.sh deployment istiod-${revision} istio-system 10 ${cluster2_context}

# wait for completion of gloo-mesh install
./tools/wait-for-rollout.sh deployment gloo-mesh-mgmt-server gloo-mesh 10 ${mgmt_context}

# register clusters to gloo mesh
./tools/meshctl-register-helm-argocd-2-clusters.sh ${mgmt_context} ${cluster1_context} ${cluster2_context} ${gloo_mesh_version}

# deploy cluster1, and cluster2 environment apps aoa
#kubectl apply -f platform-owners/mgmt/mgmt-apps.yaml --context ${mgmt_context}
kubectl apply -f platform-owners/cluster1/cluster1-apps.yaml --context ${cluster1_context}
kubectl apply -f platform-owners/cluster2/cluster2-apps.yaml --context ${cluster2_context}

# wait for completion of bookinfo install
./tools/wait-for-rollout.sh deployment productpage-v1 bookinfo-frontends 10 ${cluster1_context}
./tools/wait-for-rollout.sh deployment productpage-v1 bookinfo-frontends 10 ${cluster2_context}

# deploy mgmt, cluster1, and cluster2 mesh config aoa for 2 cluster demo (cluster1 and cluster2)
kubectl apply -f platform-owners/mgmt/mgmt-mesh-config.yaml --context ${mgmt_context}
#kubectl apply -f platform-owners/cluster1/cluster1-mesh-config.yaml --context ${cluster1_context}
#kubectl apply -f platform-owners/cluster2/cluster2-mesh-config.yaml --context ${cluster2_context}

# (for local deployments on k3d) deploy istio ingressgateways manually
./tools/install-ingressgateways.sh

# echo port-forward commands
echo
echo "access gloo mesh dashboard:"
echo "kubectl port-forward -n gloo-mesh svc/gloo-mesh-ui 8090 --context ${mgmt_context}"
echo 
echo "access argocd dashboard:"
echo "kubectl port-forward svc/argocd-server -n argocd 9999:443 --context ${mgmt_context}"
echo
echo "navigate to demo directory for more examples that you can apply"
echo "cd demo/argo/config/domain/wildcard/v2-workshop/"

