# single cluster istio app of app demo
This branch will bootstrap argocd and deploy upstream istio + bookinfo example

Run:
```
./deploy.sh
```

Resource Requirements:
- This demo has been tested on 1x `n2-standard-4` (gke), `m5.xlarge` (aws), or `Standard_DS3_v2` (azure) instances

Note:
- By default, the script expects to deploy into a context named `cluster1`
- Context parameters can be changed from defaults by changing the variables in the `deploy.sh`. A check is done to ensure that the defined contexts exist before proceeding with the installation. Note that the character `_` is an invalid value if you are replacing default contexts
- Although you may change the contexts where apps are deployed as describe above, the Istio cluster names will remain stable references `cluster1`