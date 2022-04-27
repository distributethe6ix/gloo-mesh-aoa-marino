

gloo mesh helm install:
```
helm repo add gloo-mesh-enterprise https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise 
helm repo update
kubectl create ns gloo-mesh 
helm upgrade --install gloo-mesh-enterprise gloo-mesh-enterprise/gloo-mesh-enterprise -f values.yaml \
--namespace gloo-mesh \
--version=2.0.0-beta31

kubectl -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server
```

gloo mesh `values.yaml`
```
licenseKey: "${LICENSE_KEY}"

mgmtClusterName: mgmt

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
    clusterName: cluster1
  network: network1
#  defaultResources:
#    requests:
#      cpu: 10m
#      memory: 128Mi
#    limits:
#      cpu: 100m
#      memory: 128Mi
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
  # Resources for a small pilot install
  resources:
    requests:
      cpu: 500m
      memory: 2048Mi
    limits:
      cpu: 500m
      memory: 2048Mi
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
            memory: "64Mi"
            cpu: "32m"
          limits:
            memory: "256Mi"
            cpu: "64m"
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
            memory: "64Mi"
            cpu: "32m"
          limits:
            memory: "256Mi"
            cpu: "64m"
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
            memory: "128Mi"
            cpu: "64m"
          limits:
            memory: "256Mi"
            cpu: "128m"
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
            memory: "128Mi"
            cpu: "64m"
          limits:
            memory: "256Mi"
            cpu: "128m"
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
            memory: "128Mi"
            cpu: "128m"
          limits:
            memory: "256Mi"
            cpu: "256m"
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

# test TLS

Apply TLS secret:
```
kubectl apply -f tls-secret.yaml -n istio-gateways
```

Update VirtualGateway to use tls-secret:
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
# ---------------- SSL config ---------------------------
      port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        secretName: tls-secret
# -------------------------------------------------------
      allowedRouteTables:
        - host: '*'
EOF
```

# Traffic Policies (still cluster1)

Set fixed delay to `fault_injection: true` label:
```
cat << EOF | kubectl apply -f -
apiVersion: resilience.policy.gloo.solo.io/v2
kind: FaultInjectionPolicy
metadata:
  name: ratings-fault-injection
  namespace: bookinfo-backends
spec:
  applyToRoutes:
  - route:
      labels:
        fault_injection: "true"
  config:
    delay:
      fixedDelay: 2s
      percentage: 100
EOF
```

Now set `fault_injection: true` label on appropriate route table
```
cat << EOF | kubectl apply -f -
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: ratings
  namespace: bookinfo-backends
spec:
  hosts:
    - 'ratings.bookinfo-backends.svc.cluster.local'
  workloadSelectors:
  - selector:
      labels:
        app: reviews
  http:
    - name: ratings
      labels:
        fault_injection: "true"
      matchers:
      - uri:
          prefix: /
      forwardTo:
        destinations:
          - ref:
              name: ratings
              namespace: bookinfo-backends
            port:
              number: 9080
EOF
```

Refresh the bookinfo app in-browser to observe 2 second delay when loading v2 reviews

# configure request timeout
Configure a timeout in conjunction to the delay that we imposed to observe behavior
```
cat << EOF | kubectl apply -f -
apiVersion: resilience.policy.gloo.solo.io/v2
kind: RetryTimeoutPolicy
metadata:
  name: reviews-request-timeout
  namespace: bookinfo-backends
spec:
  applyToRoutes:
  - route:
      labels:
        request_timeout: "0.5s"
  config:
    requestTimeout: 0.5s
EOF
```

Update the reviews route table with the proper label to be selected
```
cat << EOF | kubectl apply -f -
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  hosts:
    - 'reviews.bookinfo-backends.svc.cluster.local'
  workloadSelectors:
  - selector:
      labels:
        app: productpage
  http:
    - name: reviews
      labels:
        request_timeout: "0.5s"
      matchers:
      - uri:
          prefix: /
      forwardTo:
        destinations:
          - ref:
              name: reviews
              namespace: bookinfo-backends
            port:
              number: 9080
            subset:
              version: v2
EOF
```

Remove config:
```
kubectl delete faultinjectionpolicy -n bookinfo-backends ratings-fault-injection
kubectl delete retrytimeoutpolicy reviews-request-timeout -n bookinfo-backends
kubectl delete routetable -n bookinfo-backends reviews 
kubectl delete routetable -n bookinfo-backends ratings
```

# Create Root Trust Policy - IN MGMT CLUSTER
```
cat << EOF | kubectl apply -f -
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust-policy
  namespace: gloo-mesh
spec:
  config:
    mgmtServerCa:
      generated: {}
    autoRestartPods: true
EOF
```

Check to see that the secret in cluster1 and cluster2 have the same Root CA but different intermediate certs
```
kubectl get secret -n istio-system cacerts -o yaml --context ${CLUSTER1}
kubectl get secret -n istio-system cacerts -o yaml --context ${CLUSTER2}
```

# Multi Cluster Traffic - Deploy on Cluster 1 (where workspace root is)
```
cat << EOF | kubectl apply -f -
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  exportTo:
  - name: gateways
  options:
    federation:
      enabled: true
      serviceSelector:
      - workspace: bookinfo
        labels:
          app: reviews
EOF
```

Modify route table to send all traffic to v3 reviews on cluster2 to validate
```
cat << EOF | kubectl apply -f -
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  hosts:
    - 'reviews.bookinfo-backends.svc.cluster.local'
  workloadSelectors:
  - selector:
      labels:
        app: productpage
  http:
    - name: reviews
      matchers:
      - uri:
          prefix: /
      forwardTo:
        destinations:
          - ref:
              name: reviews
              namespace: bookinfo-backends
              cluster: cluster2
            port:
              number: 9080
            subset:
              version: v3
EOF
```

Remove test route table once completed with validation:
```
kubectl delete routetables reviews -n bookinfo-backends
```

# Leverage Virtual Destinations
Update VirtualGateway with a selector instead of directref to expose on both clusters
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
  listeners: 
    - http: {}
      port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        secretName: tls-secret
      allowedRouteTables:
        - host: '*'
EOF
```

Now you can check the istio-ingressgateway at cluster 2
```
kubectl get svc -n istio-gateways --context ${CLUSTER2}
```

Create a Virtual Destination:
```
kubectl apply -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualDestination
metadata:
  name: productpage
  namespace: bookinfo-frontends
  labels:
    workspace.solo.io/exported: "true"
spec:
  hosts:
  - productpage.global
  services:
  - namespace: bookinfo-frontends
    labels:
      app: productpage
  ports:
    - name: http
      number: 9080
      protocol: HTTP
EOF
```

Now update your Route Table to use this virtual destination:
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
            kind: VIRTUAL_DESTINATION
            port:
              number: 9080
EOF
```

Now test both bookinfo examples and you will see that in cluster1 there will be red stars, even though there is no reviews-v3 service in cluster1

# Implement failover and locality rules

Set failover policy:
```
kubectl apply -f - <<EOF
apiVersion: resilience.policy.gloo.solo.io/v2
kind: FailoverPolicy
metadata:
  name: failover
  namespace: bookinfo-frontends
  labels:
    workspace.solo.io/exported: "true"
spec:
  applyToDestinations:
  - kind: VIRTUAL_DESTINATION
    selector:
      labels:
        failover: "true"
  config:
    localityMappings: []
EOF
```

Set an outlier detection policy:
```
kubectl apply -f - <<EOF
apiVersion: resilience.policy.gloo.solo.io/v2
kind: OutlierDetectionPolicy
metadata:
  name: outlier-detection
  namespace: bookinfo-frontends
  labels:
    workspace.solo.io/exported: "true"
spec:
  applyToDestinations:
  - kind: VIRTUAL_DESTINATION
    selector:
      labels:
        failover: "true"
  config:
    consecutiveErrors: 2
    interval: 5s
    baseEjectionTime: 30s
    maxEjectionPercent: 100
EOF
```

# deploy httpbin in-mesh and not-in-mesh for tests

First deploy the not-in-mesh:
```
kubectl create ns httpbin

kubectl apply -n httpbin -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: not-in-mesh
---
apiVersion: v1
kind: Service
metadata:
  name: not-in-mesh
  labels:
    app: not-in-mesh
    service: not-in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: not-in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-in-mesh
spec:
  replicas: 1
  selector:
    matchLabels:
      app: not-in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: not-in-mesh
        version: v1
    spec:
      serviceAccountName: not-in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: not-in-mesh
        ports:
        - containerPort: 80
EOF
```

Then the in-mesh (with annotation):
```
kubectl apply -n httpbin -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-mesh
---
apiVersion: v1
kind: Service
metadata:
  name: in-mesh
  labels:
    app: in-mesh
    service: in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: in-mesh
spec:
  replicas: 1
  selector:
    matchLabels:
      app: in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: in-mesh
        version: v1
        istio.io/rev: 1-11
    spec:
      serviceAccountName: in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: in-mesh
        ports:
        - containerPort: 80
EOF
```

Command to test - note this requires curl containers and ephemeral containers to be supported in the cluster

Service not-in-mesh > in-mesh
```
pod=$(kubectl -n httpbin get pods -l app=not-in-mesh -o jsonpath='{.items[0].metadata.name}')
kubectl -n httpbin debug -i -q ${pod} --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0
```

in-mesh > in-mesh
```
pod=$(kubectl -n httpbin get pods -l app=in-mesh -o jsonpath='{.items[0].metadata.name}')
kubectl -n httpbin debug -i -q ${pod} --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0
```

RL cmd:
```
for i in {1..5}; do curl -I -H "x-type: a" -H "x-number: one" -sk https://k8s-istiogat-istioing-312f9b356d-224313aa2070d861.elb.us-east-1.amazonaws.com/productpage;echo ''; done
```

# Solo Workshop Link
https://workshops.solo.io/gloo-workshops/gloo-mesh-2-0#lab-6
- GEHC Lab clusters have been set up to Lab 6
    - Clusters deployed on solo-poc-solcls1 (mgmt), solo-poc-solcls2 (cluster1), solo-poc-solcls3 (cluster2)
    - Istio deployed on solo-poc-solcls2 and solo-poc-solcls3
    - Bookinfo and httpbin demo applications deployed
    - Gloo Mesh deployed and workers registered
    - Workspaces created

# Set these env variables if starting at Lab 6:
```
export MGMT=solo-poc-solcls1-user@solo-poc-solcls1
export CLUSTER1=solo-poc-solcls2-user@solo-poc-solcls2
export CLUSTER2=solo-poc-solcls3-user@solo-poc-solcls3
```

# Set these endpoint env variables if starting at Lab 6:
```
export ENDPOINT_HTTP_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER1} | cut -d: -f1)

export ENDPOINT_HTTP_GW_CLUSTER2=$(kubectl --context ${CLUSTER2} -n istio-gateways get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER2=$(kubectl --context ${CLUSTER2} -n istio-gateways get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER2} | cut -d: -f1)
```

# expose gloo mesh ui using port-forward at localhost:8090
```
kubectl port-forward -n gloo-mesh svc/gloo-mesh-ui 8090 --context ${MGMT}
```

## Other Notes:
Lab 13 (Keycloak) and Lab 14 (OPA + Keycloak) have been validated on Solo.io environments but has not been completed/tested on GEHC cluster. Was unsure if GEHC uses keycloak internally.