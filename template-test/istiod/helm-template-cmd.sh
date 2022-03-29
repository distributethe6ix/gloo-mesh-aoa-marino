helm template "istiod" istio/istiod -f values.yaml -n istio-system > istio-1.11.7-out.yaml
