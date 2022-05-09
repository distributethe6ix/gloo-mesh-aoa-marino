#!/bin/bash

cluster1_context="solo-poc-solcls2-user@solo-poc-solcls2"

kubectl apply -k ../cluster1/1.3.a-workspace-settings --context ${cluster1_context}

kubectl apply -k ../cluster1/2.1.a-routing-single-upstream --context ${cluster1_context}