gloo mesh helm install:
```
helm repo add gloo-mesh-enterprise https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise 
helm repo update
kubectl create ns gloo-mesh 
helm upgrade --install gloo-mesh-enterprise gloo-mesh-enterprise/gloo-mesh-enterprise -f values.yaml \
--namespace gloo-mesh \
--version=2.0.0-beta19

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

istiod install:
```
helm upgrade --install istio-base ./istio-1.11.7/manifests/charts/base -n istio-system

helm upgrade --install istio-1.11.7 ./istio-1.11.7/manifests/charts/istio-control/istio-discovery -n istio-system --values - <<EOF
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
EOF
```

istio-ingressgateway install:
```
kubectl label namespace istio-gateways istio.io/rev=1-11

helm upgrade --install istio-ingressgateway ./istio-1.11.7/manifests/charts/gateways/istio-ingress -n istio-gateways --values - <<EOF

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
EOF
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

Deploy bookinfo-frontends
```
kubectl create ns bookinfo-frontends
kubectl label namespace bookinfo-frontends istio.io/rev=1-11 

kubectl apply -n bookinfo-frontends -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    account: productpage
  name: bookinfo-productpage
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: productpage
    service: productpage
    version: v1
  name: productpage
spec:
  ports:
  - name: http
    port: 9080
  selector:
    app: productpage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: productpage
    version: v1
  name: productpage-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productpage
      version: v1
  template:
    metadata:
      labels:
        app: productpage
        version: v1
    spec:
      containers:
      - env:
        - name: DETAILS_HOSTNAME
          value: details.bookinfo-backends.svc.cluster.local
        - name: REVIEWS_HOSTNAME
          value: reviews.bookinfo-backends.svc.cluster.local
        image: docker.io/istio/examples-bookinfo-productpage-v1:1.16.2
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: "32Mi"
            cpu: "100m"
          limits:
            memory: "64Mi"
            cpu: "200m"
        name: productpage
        ports:
        - containerPort: 9080
        securityContext:
          runAsUser: 1000
        volumeMounts:
        - mountPath: /tmp
          name: tmp
      serviceAccountName: bookinfo-productpage
      volumes:
      - emptyDir: {}
        name: tmp
EOF
```

Deploy bookinfo-backends
```
kubectl create ns bookinfo-backends
kubectl label namespace bookinfo-backends istio.io/rev=1-11 

kubectl apply -n bookinfo-backends -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    account: details
  name: bookinfo-details
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    account: ratings
  name: bookinfo-ratings
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    account: reviews
  name: bookinfo-reviews
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: details
    service: details
  name: details
spec:
  ports:
  - name: http
    port: 9080
  selector:
    app: details
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: ratings
    service: ratings
  name: ratings
spec:
  ports:
  - name: http
    port: 9080
  selector:
    app: ratings
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: reviews
    service: reviews
  name: reviews
spec:
  ports:
  - name: http
    port: 9080
  selector:
    app: reviews
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: details
    version: v1
  name: details-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: details
      version: v1
  template:
    metadata:
      labels:
        app: details
        version: v1
    spec:
      containers:
      - image: docker.io/istio/examples-bookinfo-details-v1:1.16.2
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: "32Mi"
            cpu: "100m"
          limits:
            memory: "64Mi"
            cpu: "200m"
        name: details
        ports:
        - containerPort: 9080
        securityContext:
          runAsUser: 1000
      serviceAccountName: bookinfo-details
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: ratings
    version: v1
  name: ratings-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ratings
      version: v1
  template:
    metadata:
      labels:
        app: ratings
        version: v1
    spec:
      containers:
      - image: docker.io/istio/examples-bookinfo-ratings-v1:1.16.2
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: "32Mi"
            cpu: "100m"
          limits:
            memory: "64Mi"
            cpu: "200m"
        name: ratings
        ports:
        - containerPort: 9080
        securityContext:
          runAsUser: 1000
      serviceAccountName: bookinfo-ratings
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: reviews
    version: v1
  name: reviews-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v1
  template:
    metadata:
      labels:
        app: reviews
        version: v1
    spec:
      containers:
      - env:
        - name: LOG_DIR
          value: /tmp/logs
        image: docker.io/istio/examples-bookinfo-reviews-v1:1.16.2
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        name: reviews
        ports:
        - containerPort: 9080
        securityContext:
          runAsUser: 1000
        volumeMounts:
        - mountPath: /tmp
          name: tmp
        - mountPath: /opt/ibm/wlp/output
          name: wlp-output
      serviceAccountName: bookinfo-reviews
      volumes:
      - emptyDir: {}
        name: wlp-output
      - emptyDir: {}
        name: tmp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: reviews
    version: v2
  name: reviews-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v2
  template:
    metadata:
      labels:
        app: reviews
        version: v2
    spec:
      containers:
      - env:
        - name: LOG_DIR
          value: /tmp/logs
        image: docker.io/istio/examples-bookinfo-reviews-v2:1.16.2
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        name: reviews
        ports:
        - containerPort: 9080
        securityContext:
          runAsUser: 1000
        volumeMounts:
        - mountPath: /tmp
          name: tmp
        - mountPath: /opt/ibm/wlp/output
          name: wlp-output
      serviceAccountName: bookinfo-reviews
      volumes:
      - emptyDir: {}
        name: wlp-output
      - emptyDir: {}
        name: tmp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: reviews
    version: v3
  name: reviews-v3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reviews
      version: v3
  template:
    metadata:
      labels:
        app: reviews
        version: v3
    spec:
      containers:
      - env:
        - name: LOG_DIR
          value: /tmp/logs
        image: docker.io/istio/examples-bookinfo-reviews-v3:1.16.2
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        name: reviews
        ports:
        - containerPort: 9080
        securityContext:
          runAsUser: 1000
        volumeMounts:
        - mountPath: /tmp
          name: tmp
        - mountPath: /opt/ibm/wlp/output
          name: wlp-output
      serviceAccountName: bookinfo-reviews
      volumes:
      - emptyDir: {}
        name: wlp-output
      - emptyDir: {}
        name: tmp
EOF
```

Deploy Addons on worker clusters
```
kubectl create namespace gloo-mesh-addons
kubectl label namespace gloo-mesh-addons istio.io/rev=1-11

helm upgrade --install gloo-mesh-agent-addons gloo-mesh-agent/gloo-mesh-agent \
  --namespace gloo-mesh-addons \
  --set glooMeshAgent.enabled=false \
  --set rate-limiter.enabled=true \
  --set ext-auth-service.enabled=true \
  --version 2.0.0-beta19
```

# DEPLOY IN MGMT CLUSTER
Create gateways workspace in the management cluster:
```
kubectl apply --context ${MGMT} -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: gateways
  namespace: gloo-mesh
spec:
  workloadClusters:
  - name: cluster1
    namespaces:
    - name: istio-gateways
    - name: gloo-mesh-addons
  - name: cluster2
    namespaces:
    - name: istio-gateways
    - name: gloo-mesh-addons
EOF
```

Create bookinfo workspace in the management cluster:
```
kubectl apply --context ${MGMT} -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: bookinfo
  namespace: gloo-mesh
  labels:
    allow_ingress: "true"
spec:
  workloadClusters:
  - name: cluster1
    namespaces:
    - name: bookinfo-frontends
    - name: bookinfo-backends
  - name: cluster2
    namespaces:
    - name: bookinfo-frontends
    - name: bookinfo-backends
EOF
```

# DEPLOY IN CLUSTER1 CLUSTER

Set cluster1 `istio-gateways` namespace as the root namespace where the gateway team will control objects they want to export
```
kubectl apply -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: gateways
  namespace: istio-gateways
spec:
  imports:
  - selector:
      allow_ingress: "true"
EOF
```

Set cluster1 `bookinfo-frontends` namespace as the root namespace where the bookinfo team will control objects they want to export
```
kubectl apply -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  exportTo:
  - name: gateways
EOF
```

Expose productpage through a gateway
```
kubectl apply -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualGateway
metadata:
  name: north-south-gw
  namespace: istio-gateways
spec:
  workloads:
    - selector:
        labels:
          istio: ingressgateway
        cluster: cluster1
  listeners: 
    - http: {}
      port:
        number: 80
        name: http
        protocol: HTTP
      allowedRouteTables:
        - host: '*'
EOF
```

And then a route table:
```
kubectl apply -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: productpage
  namespace: bookinfo-frontends
  labels:
    workspace.solo.io/exported: "true"
spec:
  hosts:
    - '*'
  virtualGateways:
    - name: north-south-gw
      namespace: istio-gateways
      cluster: cluster1
  workloadSelectors: []
  http:
    - name: productpage
      matchers:
      - uri:
          exact: /productpage
      - uri:
          prefix: /static
      - uri:
          exact: /login
      - uri:
          exact: /logout
      - uri:
          prefix: /api/v1/products
      forwardTo:
        destinations:
          - ref:
              name: productpage
              namespace: bookinfo-frontends
            port:
              number: 9080
EOF
```