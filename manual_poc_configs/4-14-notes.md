# create ns
kubectl create ns istio-system

# install base

helm upgrade --install istio-base istio/base -n istio-system --version 1.12.6

# install istiod

helm upgrade --install istiod-1.12.6 istio/istiod -n istio-system --version 1.12.6 --values - <<EOF
revision: 1-12
global:
  meshID: mesh1
  multiCluster:
    clusterName: cluster1
  network: network1
meshConfig:
  trustDomain: cluster1
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
      GLOO_MESH_CLUSTER_NAME: cluster1
pilot:
  env:
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
EOF

# install gateway

kubectl create ns istio-gateways

helm upgrade --install istio-ingressgateway istio/gateway -n istio-gateways --version 1.12.6 --values - <<EOF
# Name allows overriding the release name. Generally this should not be set
name: ""
# revision declares which revision this gateway is a part of
revision: "1-12"

replicaCount: 1

podAnnotations:
  prometheus.io/port: "15020"
  prometheus.io/scrape: "true"
  prometheus.io/path: "/stats/prometheus"
  inject.istio.io/templates: "gateway"
  sidecar.istio.io/inject: "true"

service:
  # Type of service. Set to "None" to disable the service entirely
  type: LoadBalancer
  ports:
  - name: status-port
    port: 15021
    protocol: TCP
    targetPort: 15021
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
  annotations: {}
  loadBalancerIP: ""
  loadBalancerSourceRanges: []
  externalTrafficPolicy: ""

# Pod environment variables
env: {}

# Labels to apply to all resources
labels:
  istio.io/rev: 1-12
EOF

# uninstall
helm uninstall istio-ingressgateway istio/gateway -n istio-gateways
helm uninstall istiod-1.12.6 istio/istiod -n istio-system
helm uninstall istio-base istio/base -n istio-system