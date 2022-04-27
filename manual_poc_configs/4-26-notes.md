# cluster 1 ingress gateways

kubectl --context ${CLUSTER1} label namespace istio-gateways istio.io/rev=1-12

helm --kube-context=${CLUSTER1} upgrade --install istio-ingressgateway ./istio-1.12.6/manifests/charts/gateways/istio-ingress -n istio-gateways --values - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
  tag: 1.12.6-solo
gateways:
  istio-ingressgateway:
    name: istio-ingressgateway
    namespace: istio-gateways
    labels:
      istio: ingressgateway
    injectionTemplate: gateway
    ports:
    - name: tcp-status-port
      port: 15021
      targetPort: 15021
    - name: http2
      port: 80
      targetPort: 8080
    - name: https
      port: 443
      targetPort: 8443
    serviceAnnotations:
      meta.helm.sh/release-name: istio-ingressgateway
      meta.helm.sh/release-namespace: istio-gateways
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: TCP
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "15021"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: tcp
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      service.beta.kubernetes.io/aws-load-balancer-scheme: internal
      service.beta.kubernetes.io/aws-load-balancer-type: external
EOF

helm --kube-context=${CLUSTER1} upgrade --install istio-eastwestgateway ./istio-1.12.6/manifests/charts/gateways/istio-ingress -n istio-gateways --values - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
  tag: 1.12.6-solo
gateways:
  istio-ingressgateway:
    name: istio-eastwestgateway
    namespace: istio-gateways
    labels:
      istio: eastwestgateway
      topology.istio.io/network: network1
    injectionTemplate: gateway
    ports:
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
    serviceAnnotations:
      meta.helm.sh/release-name: istio-ingressgateway
      meta.helm.sh/release-namespace: istio-gateways
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: TCP
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "15021"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: tcp
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      service.beta.kubernetes.io/aws-load-balancer-scheme: internal
      service.beta.kubernetes.io/aws-load-balancer-type: external
    env:
      ISTIO_META_ROUTER_MODE: "sni-dnat"
      ISTIO_META_REQUESTED_NETWORK_VIEW: "network1"
EOF


# cluster 2 ingress gateways

kubectl --context ${CLUSTER2} label namespace istio-gateways istio.io/rev=1-12

helm --kube-context=${CLUSTER2} upgrade --install istio-ingressgateway ./istio-1.12.6/manifests/charts/gateways/istio-ingress -n istio-gateways --values - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
  tag: 1.12.6-solo
gateways:
  istio-ingressgateway:
    name: istio-ingressgateway
    namespace: istio-gateways
    labels:
      istio: ingressgateway
    injectionTemplate: gateway
    ports:
    - name: tcp-status-port
      port: 15021
      targetPort: 15021
    - name: http2
      port: 80
      targetPort: 8080
    - name: https
      port: 443
      targetPort: 8443
    serviceAnnotations:
      meta.helm.sh/release-name: istio-ingressgateway
      meta.helm.sh/release-namespace: istio-gateways
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: TCP
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "15021"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: tcp
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      service.beta.kubernetes.io/aws-load-balancer-scheme: internal
      service.beta.kubernetes.io/aws-load-balancer-type: external
EOF

helm --kube-context=${CLUSTER2} upgrade --install istio-eastwestgateway ./istio-1.12.6/manifests/charts/gateways/istio-ingress -n istio-gateways --values - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
  tag: 1.12.6-solo
gateways:
  istio-ingressgateway:
    name: istio-eastwestgateway
    namespace: istio-gateways
    labels:
      istio: eastwestgateway
      topology.istio.io/network: network1
    injectionTemplate: gateway
    ports:
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
    serviceAnnotations:
      meta.helm.sh/release-name: istio-ingressgateway
      meta.helm.sh/release-namespace: istio-gateways
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: TCP
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "15021"
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: tcp
      service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      service.beta.kubernetes.io/aws-load-balancer-scheme: internal
      service.beta.kubernetes.io/aws-load-balancer-type: external
    env:
      ISTIO_META_ROUTER_MODE: "sni-dnat"
      ISTIO_META_REQUESTED_NETWORK_VIEW: "network1"
EOF