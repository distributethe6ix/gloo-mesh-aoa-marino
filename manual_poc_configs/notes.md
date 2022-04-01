gloo mesh helm install:
```
helm repo add gloo-mesh-enterprise https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise 
helm repo update
kubectl create ns gloo-mesh 
helm upgrade --install gloo-mesh-enterprise gloo-mesh-enterprise/gloo-mesh-enterprise \
--namespace gloo-mesh \
--version=2.0.0-beta19 \
--set glooMeshMgmtServer.ports.healthcheck=8091 \
--set glooMeshUi.serviceType=LoadBalancer \
--set mgmtClusterName=${MGMT} \
--set licenseKey=${LICENSE_KEY}
kubectl -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server
```

gloo mesh `values.yaml`
```
licenseKey: "${LICENSE_KEY}"

mgmtClusterName: gehc-mgmt

glooMeshMgmtServer:
  resources:
    requests:
      cpu: 125m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  ports:
    healthcheck: 8091
    grpc: 9900
  serviceType: LoadBalancer
# Additional settings to add to the load balancer service
  serviceOverrides:
    metadata:
      annotations:
        # AWS-specific annotations
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "9900"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "tcp"
        service.beta.kubernetes.io/aws-load-balancer-type: external
        service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
        service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
        service.beta.kubernetes.io/aws-load-balancer-backend-protocol: TCP
        service.beta.kubernetes.io/aws-load-balancer-name: solo-poc-gloo-mesh-mgmt-server
glooMeshUi:
  resources:
    requests:
      cpu: 125m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Gi

rbac-webhook:
  enabled: false

glooMeshRedis:
  resources:
    requests:
      cpu: 125m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Gi

prometheus:
  enabled: true
  server: 
    resources:
      requests:
        cpu: 125m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Gi
```

istiod helm values:
```
revision: 1-11
global:
  meshID: mesh1
  multiCluster:
    clusterName: ehc-cluster1
  network: network1
#  defaultResources:
#    requests:
#      cpu: 10m
#      memory: 128Mi
#    limits:
#      cpu: 100m
#      memory: 128Mi
meshConfig:
  trustDomain: ehc-cluster1
  accessLogFile: /dev/stdout
  enableAutoMtls: true
  defaultConfig:
    envoyMetricsService:
      address: gloo-mesh-agent.gloo-mesh:9977
    envoyAccessLogService:
      address: gloo-mesh-agent.gloo-mesh:9977
    proxyMetadata:
      ISTIO_META_DNS_CAPTURE: "true"
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      GLOO_MESH_CLUSTER_NAME: gehc-cluster1
pilot:
  # Resources for a small pilot install
  resources:
    requests:
      cpu: 500m
      memory: 2048Mi
    limits:
      cpu: 100m
      memory: 128Mi
  env:
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
```

istio-ingressgateway values:
```
gateways:
  istio-ingressgateway:
    name: istio-ingressgateway
    namespace: istio-gateways
    labels:
      istio: ingressgateway
      topology.istio.io/network: network1
    injectionTemplate: gateway
    ports:
    - name: http2
      port: 80
      targetPort: 8080
    - name: https
      port: 443
      targetPort: 8443
    - name: tcp-status-port
      port: 15021
      targetPort: 15021
    - name: tls
      port: 15443
      targetPort: 15443
    - name: tcp-istiod
      port: 15012
      targetPort: 15012
    - name: tcp-webhook
      port: 15017
      targetPort: 15017
    env:
      ISTIO_META_ROUTER_MODE: "sni-dnat"
      ISTIO_META_REQUESTED_NETWORK_VIEW: "network1"
```

agent install:
```
helm repo add gloo-mesh-agent https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-agent
helm repo update

kubectl apply --context ${MGMT} -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
  name: cluster1
  namespace: gloo-mesh
spec:
  clusterDomain: cluster.local
EOF

kubectl apply --context ${MGMT} -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
  name: cluster2
  namespace: gloo-mesh
spec:
  clusterDomain: cluster.local
EOF


kubectl get secret relay-root-tls-secret -n gloo-mesh --context ${MGMT} -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
kubectl create secret generic relay-root-tls-secret -n gloo-mesh --context ${CLUSTER1} --from-file ca.crt=ca.crt

kubectl get secret relay-identity-token-secret -n gloo-mesh --context ${MGMT} -o jsonpath='{.data.token}' | base64 -d > token
kubectl create secret generic relay-identity-token-secret -n gloo-mesh --context ${CLUSTER1} --from-file token=token

kubectl create secret generic relay-root-tls-secret -n gloo-mesh --context ${CLUSTER2} --from-file ca.crt=ca.crt
rm ca.crt

kubectl create secret generic relay-identity-token-secret -n gloo-mesh --context ${CLUSTER2} --from-file token=token
rm token

helm upgrade --install gloo-mesh-agent gloo-mesh-agent/gloo-mesh-agent \
  --namespace gloo-mesh \
  --kube-context=${CLUSTER1} \
  --set relay.serverAddress=${ENDPOINT_GLOO_MESH} \
  --set relay.authority=gloo-mesh-mgmt-server.gloo-mesh \
  --set rate-limiter.enabled=false \
  --set ext-auth-service.enabled=false \
  --set cluster=cluster1 \
  --version 2.0.0-beta19

helm upgrade --install gloo-mesh-agent gloo-mesh-agent/gloo-mesh-agent \
  --namespace gloo-mesh \
  --kube-context=${CLUSTER2} \
  --set relay.serverAddress=${ENDPOINT_GLOO_MESH} \
  --set relay.authority=gloo-mesh-mgmt-server.gloo-mesh \
  --set rate-limiter.enabled=false \
  --set ext-auth-service.enabled=false \
  --set cluster=cluster2 \
  --version 2.0.0-beta19
```


