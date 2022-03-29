
GLOO_MESH_VERSION=2.0.0-beta19

helm template "gloo-mesh-enterprise" gloo-mesh-enterprise/gloo-mesh-enterprise -f values.yaml -n gloo-mesh --version ${GLOO_MESH_VERSION} > ${GLOO_MESH_VERSION}-ee-out.yaml
