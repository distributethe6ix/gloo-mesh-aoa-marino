# gloo-mesh-demo-aoa
This repo leverages the Argo CD app-of-apps pattern to demonstrate a GitOps workflow to deploy and configure a multi-cluster mesh demo
 
Spin up three clusters named `cluster1`, `cluster2`, `cluster3` (optional), and `mgmt`

Run:
```
./deploy-2clusters.sh           # deploys on mgmt, cluster1, cluster2
./deploy-3clusters.sh           # deploys on mgmt, cluster1, cluster2, cluster3
```

Resource Requirements:
- This demo has been tested on 1x `n2-standard-4` (gke), `m5.xlarge` (aws), or `Standard_DS3_v2` (azure) instance for `mgmt` cluster
- This demo has been tested on 2x `n2-standard-4` (gke), `m5.xlarge` (aws), or `Standard_DS3_v2` (azure) instances for `cluster1` and `cluster2` and `cluster3`

Note:
- A temporary (5 day currently) license key is used here for demonstration purposes
- By default, the script expects to deploy into three clusters named `mgmt`, `cluster1`, and `cluster2`. This is configurable by changing the variables in the `deploy.sh`. A check is done to ensure that the defined contexts exist before proceeding with the installation.
- Although you may change the contexts where apps are deployed as describe above, the Istio cluster names will remain stable references `cluster1` and `cluster2`

# App of Apps Explained
Platform owners control the deployment of applications into the cluster with the app-of-apps pattern. The app-of-apps pattern uses a generic Argo Application to sync all manifests in a particular Git directory, rather than directly point to a Kustomize, YAML, or Helm configuration.

By using the app-of-app pattern, a Platform Administrator can provide some self-service capabilities to end users by delivering a synced directory in Git (i.e. infra team controls `infra` directory, app team to `app` directory) while still controlling what is ultimately deployed to the cluster and exposed through standard Kubernetes RBAC and Policy. This way, with the right policy in place, Applications are not deployed unless successfully committed Git and pushed to the correctly scoped team directory/repo
```
platform-owners
├── cluster1
│   ├── cluster1-apps.yaml                  # syncs all apps pushed to environments/cluster1/apps/
│   ├── cluster1-cluster-config.yaml        # syncs all apps pushed to environments/cluster1/cluster-config/
│   ├── cluster1-infra.yaml                 # syncs all apps pushed to environments/cluster1/infra/
│   └── cluster1-mesh-config.yaml           # syncs all apps pushed to environments/cluster1/mesh-config/
├── cluster2
│   ├── cluster2-apps.yaml                  # syncs all apps pushed to environments/cluster2/apps/
│   ├── cluster2-cluster-config.yaml        # syncs all apps pushed to environments/cluster2/cluster-config/
│   ├── cluster2-infra.yaml                 # syncs all apps pushed to environments/cluster2/infra/
│   └── cluster2-mesh-config.yaml           # syncs all apps pushed to environments/cluster2/mesh-config/
└── mgmt
    ├── mgmt-apps.yaml                      # syncs all apps pushed to environments/mgmt/apps/
    ├── mgmt-cluster-config.yaml            # syncs all apps pushed to environments/mgmt/cluster-config/
    ├── mgmt-infra.yaml                     # syncs all apps pushed to environments/mgmt/infra/
    └── mgmt-mesh-config.yaml               # syncs all apps pushed to environments/mgmt/mesh-config/
```

Example environments tree containing 3 clusters described above:
```
environments
├── cluster1
│   ├── apps
│   │   ├── 1.2.a-reviews-v1-v2.yaml
│   │   ├── bookinfo-loadgen-istio-ingressgateway.yaml
│   │   └── non-active
│   │       ├── bookinfo
│   │       │   └── app
│   │       │       ├── 0-no-reviews.yaml
│   │       │       ├── 1.1.a-reviews-v1.yaml
│   │       │       ├── 1.1.b-reviews-v2.yaml
│   │       │       ├── 1.1.c-reviews-v3.yaml
│   │       │       ├── 1.2.a-reviews-v1-v2.yaml
│   │       │       └── 1.3.a-reviews-all.yaml
│   │       └── gloo-mesh
│   │           └── gm-enterprise-agent-cluster1.yaml
│   ├── cluster-config
│   │   └── non-active
│   ├── infra
│   │   ├── gloo-mesh-dataplane-addons.yaml
│   │   ├── gm-istio-workshop-cluster1-1-11-4.yaml
│   │   ├── istio-operator-1-11-4.yaml
│   │   └── non-active
│   └── mesh-config
│       └── non-active
│           └── strict-mtls.yaml
├── cluster2
│   ├── apps
│   │   ├── 1.3.a-reviews-all.yaml
│   │   ├── bookinfo-loadgen-istio-ingressgateway.yaml
│   │   └── non-active
│   │       ├── bookinfo
│   │       │   └── app
│   │       │       ├── 0-no-reviews.yaml
│   │       │       ├── 1.1.a-reviews-v1.yaml
│   │       │       ├── 1.1.b-reviews-v2.yaml
│   │       │       ├── 1.1.c-reviews-v3.yaml
│   │       │       ├── 1.2.a-reviews-v1-v2.yaml
│   │       │       └── 1.3.a-reviews-all.yaml
│   │       └── gloo-mesh
│   │           └── gm-enterprise-agent-cluster2.yaml
│   ├── cluster-config
│   │   └── non-active
│   ├── infra
│   │   ├── gloo-mesh-dataplane-addons.yaml
│   │   ├── gm-istio-workshop-cluster2-1-11-4.yaml
│   │   ├── istio-operator-1-11-4.yaml
│   │   └── non-active
│   └── mesh-config
│       └── non-active
│           └── strict-mtls.yaml
└── mgmt
    ├── apps
    │   └── non-active
    ├── cluster-config
    │   └── non-active
    ├── infra
    │   ├── gloo-mesh-ee-helm.yaml
    │   └── non-active
    └── mesh-config
        ├── 1.1.b-route-cluster2.yaml
        ├── 1.3.a-ratelimit-vhost.yaml
        ├── gloo-mesh-controlplane-config.yaml
        ├── gloo-mesh-virtualmesh-rbac-disabled.yaml
        └── non-active
            ├── 1.1.a-route-cluster1.yaml
            ├── 1.2.a-weighted-multicluster.yaml
            ├── 3.1.a-add-header.yaml
            └── 3.2.a-add-delay.yaml
```