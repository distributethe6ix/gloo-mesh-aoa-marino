#!/bin/bash

cluster1_context="solo-poc-solcls2-user@solo-poc-solcls2"

kubectl delete -k ../cluster1/2.2.a-workspace-settings-federation --context ${cluster1_context}

kubectl delete -k ../cluster1/2.3.b-routing-federation-failover --context ${cluster1_context}