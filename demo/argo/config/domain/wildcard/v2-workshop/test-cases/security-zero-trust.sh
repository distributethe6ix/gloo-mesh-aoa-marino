#!/bin/bash

cluster1_context="cluster1"

# apply route without isolation
echo "applying route without isolation"
kubectl apply -f ../cluster1/1.3.a-workspace-settings.yaml --context ${cluster1_context}
kubectl apply -f ../cluster1/2.1.b-routing-tls-single-upstream.yaml --context ${cluster1_context}

# sleep
echo
echo "sleeping for 10 seconds"
sleep 10

echo
echo "now curling reviews from sleep-not-in-mesh"
echo "using command: kubectl exec -it -n sleep deploy/sleep-not-in-mesh -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0 "
echo
echo "expected output: 200 status code:"
kubectl exec -it -n sleep deploy/sleep-not-in-mesh -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0
echo 
sleep 2

echo
echo "lets look at the existing PeerAuthentication, AuthorizationPolicy, and Sidecar resources that Gloo Mesh created"
echo

echo
echo "using command: kubectl get PeerAuthentication -A --context ${cluster1_context} "
echo "expected output: No resources found"
echo 
echo "output:"
kubectl get PeerAuthentication -A --context ${cluster1_context}
sleep 2

echo
echo "using command: kubectl get AuthorizationPolicy -A --context ${cluster1_context} "
echo "expected output: No resources found"
echo 
echo "output:"
kubectl get AuthorizationPolicy -A --context ${cluster1_context} 
sleep 2

echo
echo "using command: kubectl get Sidecars -A --context ${cluster1_context} "
echo "expected output: No resources found"
echo 
echo "output:"
kubectl get Sidecars -A --context ${cluster1_context}
sleep 2

# applying zero trust
echo
echo "now applying zero-trust in workspace settings"
kubectl apply -f ../cluster1/4.1.a.security-zero-trust.yaml --context ${cluster1_context}

# sleep
echo
echo "sleeping for 10 seconds"
sleep 10

echo
echo "now curling reviews from sleep-not-in-mesh"
echo "using command: kubectl exec -it -n sleep deploy/sleep-not-in-mesh -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0 "
echo
echo "expected output: 000 status code:"
kubectl exec -it -n sleep deploy/sleep-not-in-mesh -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0
sleep 2

echo
echo "lets look at the existing PeerAuthentication, AuthorizationPolicy, and Sidecar resources that Gloo Mesh created"
echo
echo "using command: kubectl get PeerAuthentication -A --context ${cluster1_context} "
echo "expected output: resources mapped to imported/exported bookinfo and gateways workspaces"
echo 
echo "output:"
kubectl get PeerAuthentication -A --context ${cluster1_context}
sleep 2

echo
echo "using command: kubectl get AuthorizationPolicy -A --context ${cluster1_context} "
echo "expected output: resources mapped to imported/exported bookinfo and gateways workspaces"
echo 
echo "output:"
kubectl get AuthorizationPolicy -A --context ${cluster1_context} 
sleep 2

echo
echo "using command: kubectl get Sidecars -A --context ${cluster1_context} "
echo "expected output: resources mapped to imported/exported bookinfo and gateways workspaces"
echo 
echo "output:"
kubectl get Sidecars -A --context ${cluster1_context}
sleep 2

echo
echo "now curling reviews from sleep-not-in-mesh"
echo "using command: kubectl exec -it -n sleep deploy/sleep-not-in-mesh -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0 "
echo
echo "expected output: 503 status code:"
kubectl exec -it -n sleep deploy/sleep-in-mesh -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0
sleep 2

echo
echo "now reverting back to default workspace settings"
echo
kubectl apply -f ../cluster1/1.3.a-workspace-settings.yaml --context ${cluster1_context}
kubectl apply -f ../cluster1/2.1.b-routing-tls-single-upstream.yaml --context ${cluster1_context}
