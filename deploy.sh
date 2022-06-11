#!/bin/bash
#set -e

# note that the character '_' is an invalid value if you are replacing the defaults below
cluster1_context="cluster1"
gloo_mesh_version="2.0.7"

# check to see if defined contexts exist
if [[ $(kubectl config get-contexts | grep ${cluster1_context}) == "" ]] ; then
  echo "Check Failed: cluster1 context does not exist. Please check to see if you have the cluster available"
  echo "Run 'kubectl config get-contexts' to see currently available contexts. If the clusters are available, please make sure that they are named correctly. Default is cluster1"
  exit 1;
fi

# install argocd on ${mgmt_context} and ${cluster1_context}
cd bootstrap-argocd
./install-argocd.sh default ${cluster1_context}
cd ..

# wait for argo cluster rollout
./tools/wait-for-rollout.sh deployment argocd-server argocd 20 ${cluster1_context}

# deploy mgmt, cluster1 cluster config aoa
kubectl apply -f platform-owners/cluster1/cluster1-cluster-config.yaml --context ${cluster1_context}

# deploy mgmt, cluster1 environment infra app-of-apps
kubectl apply -f platform-owners/cluster1/cluster1-infra.yaml --context ${cluster1_context}

# register clusters to gloo mesh with helm

until [ "${SVC}" != "" ]; do
  SVC=$(kubectl --context ${mgmt_context} -n gloo-mesh get svc gloo-mesh-mgmt-server -o jsonpath='{.status.loadBalancer.ingress[0].*}')
  echo waiting for gloo mesh management server LoadBalancer IP to be detected
  sleep 2
done

kubectl apply --context ${cluster1_context} -f- <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gm-enterprise-agent-${cluster1_context}
  namespace: argocd
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: gloo-mesh
  source:
    repoURL: 'https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-agent'
    targetRevision: ${gloo_mesh_version}
    chart: gloo-mesh-agent
    helm:
      valueFiles:
        - values.yaml
      parameters:
        - name: cluster
          value: '${cluster1_context}'
        - name: relay.serverAddress
          value: '${SVC}:9900'
        - name: relay.authority
          value: 'gloo-mesh-mgmt-server.gloo-mesh'
        - name: relay.clientTlsSecret.name
          value: 'gloo-mesh-agent-cluster1-tls-cert'
        - name: relay.clientTlsSecret.namespace
          value: 'gloo-mesh'
        - name: relay.rootTlsSecret.name
          value: 'relay-root-tls-secret'
        - name: relay.rootTlsSecret.namespace
          value: 'gloo-mesh'
        - name: rate-limiter.enabled
          value: 'false'
        - name: ext-auth-service.enabled
          value: 'false'
        - name: istiodSidecar.createRoleBinding
          value: 'true'
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
    - Replace=true
    - ApplyOutOfSyncOnly=true
  project: default
EOF

# deploy cluster1 environment apps aoa
kubectl apply -f platform-owners/cluster1/cluster1-apps.yaml --context ${cluster1_context}

# wait for completion of bookinfo install
./tools/wait-for-rollout.sh deployment productpage-v1 bookinfo-frontends 10 ${cluster1_context}